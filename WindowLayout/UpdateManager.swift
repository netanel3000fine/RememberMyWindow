import AppKit
import Foundation
import SwiftUI

// MARK: - GitHub update configuration

enum AppUpdateConfiguration {
    static let repositoryOwner = "netanel3000fine"
    static let repositoryName = "RememberMyWindow"
    static let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    static let launchCheckDelayNanoseconds: UInt64 = 8 * 1_000_000_000

    static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")!
    }
}

struct AppUpdateRelease: Equatable, Sendable {
    var version: String
    var title: String
    var notes: String
    var releasePageURL: URL
    var downloadURL: URL?
    var downloadFileName: String?
}

enum UpdateManagerError: LocalizedError {
    case invalidResponse
    case invalidUpdateBundle
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid update response."
        case .invalidUpdateBundle:
            return "The downloaded update is not a valid RememberMyWindows app."
        case .extractionFailed(let message):
            return message
        }
    }
}

// MARK: - Update manager

@MainActor
final class UpdateManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = UpdateManager()

    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadError: String?
    @Published private(set) var availableUpdateVersion: String?

    private let defaults = UserDefaults.standard
    private var launchCheckTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    private var updateWindow: NSWindow?
    private var checkingWindow: NSWindow?
    private var promptedVersion: String?
    private var activeCheckID: UUID?
    private var manualCheckRequested = false

    private let automaticChecksKey = "updateChecksEnabled"
    private let lastCheckDateKey = "lastUpdateCheckDate"
    private let skippedVersionKey = "skippedUpdateVersion"
    private let remindLaterDateKey = "updateRemindLaterDate"
    private let availableUpdateVersionKey = "availableUpdateVersion"

    var automaticChecksEnabled: Bool {
        if defaults.object(forKey: automaticChecksKey) == nil {
            return true
        }
        return defaults.bool(forKey: automaticChecksKey)
    }

    var hasAvailableUpdate: Bool {
        guard let availableUpdateVersion,
              AppVersion(availableUpdateVersion) > AppVersion(currentVersion) else {
            return false
        }
        return defaults.string(forKey: skippedVersionKey) != availableUpdateVersion
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private override init() {
        super.init()

        if let cachedVersion = defaults.string(forKey: availableUpdateVersionKey),
           AppVersion(cachedVersion) > AppVersion(currentVersion) {
            availableUpdateVersion = cachedVersion
        } else {
            defaults.removeObject(forKey: availableUpdateVersionKey)
        }
    }

    deinit {
        launchCheckTask?.cancel()
        checkTask?.cancel()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// Starts the delayed launch check and checks again when the app is brought forward.
    /// The persisted date keeps this to at most one automatic request per day.
    func startAutomaticChecks() {
        if activationObserver == nil {
            activationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkIfNeeded()
                }
            }
        }

        launchCheckTask?.cancel()
        launchCheckTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: AppUpdateConfiguration.launchCheckDelayNanoseconds)
            } catch {
                return
            }
            self?.checkIfNeeded()
        }
    }

    func setAutomaticChecksEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: automaticChecksKey)
        launchCheckTask?.cancel()

        if enabled {
            checkIfNeeded()
        }
    }

    func checkIfNeeded() {
        guard automaticChecksEnabled, !isChecking else { return }

        // Do not interrupt first-launch onboarding with an update window.
        guard defaults.bool(forKey: "hasCompletedOnboarding") else { return }

        if let lastCheck = defaults.object(forKey: lastCheckDateKey) as? Date,
           Date().timeIntervalSince(lastCheck) < AppUpdateConfiguration.automaticCheckInterval {
            return
        }

        checkForUpdates(manual: false)
    }

    func checkForUpdates(manual: Bool = true) {
        if isChecking {
            guard manual else { return }
            manualCheckRequested = true
            presentCheckingWindow()
            return
        }

        checkTask?.cancel()
        let checkID = UUID()
        activeCheckID = checkID
        isChecking = true
        manualCheckRequested = manual
        downloadError = nil
        if !manual {
            // Throttle failed/offline automatic attempts too, not just successful requests.
            defaults.set(Date(), forKey: lastCheckDateKey)
        } else {
            presentCheckingWindow()
        }
        checkTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let release = try await self.fetchLatestRelease()
                guard !Task.isCancelled, self.activeCheckID == checkID else { return }
                self.defaults.set(Date(), forKey: self.lastCheckDateKey)
                guard let manualResultRequested = self.finishCheck(checkID: checkID) else { return }
                self.recordAvailableUpdate(release)

                guard let release, AppVersion(release.version) > AppVersion(self.currentVersion) else {
                    if manualResultRequested {
                        self.showUpToDateAlert()
                    }
                    self.dismissCheckingWindow()
                    return
                }

                guard self.shouldPresent(release: release, manual: manualResultRequested) else {
                    self.dismissCheckingWindow()
                    return
                }
                self.dismissCheckingWindow()
                self.presentUpdateWindow(for: release)
            } catch is CancellationError {
                guard self.activeCheckID == checkID else { return }
                _ = self.finishCheck(checkID: checkID)
                self.dismissCheckingWindow()
            } catch {
                guard self.activeCheckID == checkID else { return }
                self.defaults.set(Date(), forKey: self.lastCheckDateKey)
                guard let manualResultRequested = self.finishCheck(checkID: checkID) else { return }
                if manualResultRequested {
                    self.showErrorAlert(error)
                }
                self.dismissCheckingWindow()
            }
        }
    }

    private func finishCheck(checkID: UUID) -> Bool? {
        guard activeCheckID == checkID else { return nil }
        let manualResultRequested = self.manualCheckRequested
        activeCheckID = nil
        checkTask = nil
        isChecking = false
        self.manualCheckRequested = false
        return manualResultRequested
    }

    func cancelCheck() {
        guard activeCheckID != nil else {
            dismissCheckingWindow()
            return
        }

        let task = checkTask
        activeCheckID = nil
        checkTask = nil
        manualCheckRequested = false
        isChecking = false
        dismissCheckingWindow()
        task?.cancel()
    }

    private func presentCheckingWindow() {
        if let checkingWindow {
            activateApplicationForPresentation()
            checkingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(
            rootView: UpdateCheckingView(onCancel: { [weak self] in
                self?.cancelCheck()
            })
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = lz("Software Update")
        window.identifier = NSUserInterfaceItemIdentifier("software-update")
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.delegate = self
        window.center()

        checkingWindow = window
        activateApplicationForPresentation()
        window.makeKeyAndOrderFront(nil)
    }

    private func dismissCheckingWindow() {
        guard let checkingWindow else { return }
        self.checkingWindow = nil
        checkingWindow.close()
    }

    private func activateApplicationForPresentation() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func recordAvailableUpdate(_ release: AppUpdateRelease?) {
        guard let release,
              AppVersion(release.version) > AppVersion(currentVersion) else {
            availableUpdateVersion = nil
            defaults.removeObject(forKey: availableUpdateVersionKey)
            return
        }

        availableUpdateVersion = release.version
        defaults.set(release.version, forKey: availableUpdateVersionKey)
    }

    private func fetchLatestRelease() async throws -> AppUpdateRelease? {
        var request = URLRequest(url: AppUpdateConfiguration.latestReleaseURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("RememberMyWindows/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateManagerError.invalidResponse
        }

        let githubRelease = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        guard !githubRelease.draft, !githubRelease.prerelease else { return nil }

        let package = githubRelease.assets.first {
            $0.name.lowercased().hasSuffix(".zip")
        } ?? githubRelease.assets.first {
            $0.name.lowercased().hasSuffix(".dmg")
        }

        return AppUpdateRelease(
            version: normalizedVersion(githubRelease.tagName),
            title: githubRelease.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? githubRelease.name!
                : "RememberMyWindows \(normalizedVersion(githubRelease.tagName))",
            notes: githubRelease.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            releasePageURL: githubRelease.htmlURL,
            downloadURL: package?.browserDownloadURL,
            downloadFileName: package?.name
        )
    }

    private func shouldPresent(release: AppUpdateRelease, manual: Bool) -> Bool {
        if defaults.string(forKey: skippedVersionKey) == release.version {
            // An explicit manual check can revisit a version the user previously skipped.
            return manual
        }

        if let remindLaterDate = defaults.object(forKey: remindLaterDateKey) as? Date,
           remindLaterDate > Date(), !manual {
            return false
        }

        if !manual, promptedVersion == release.version {
            return false
        }

        return true
    }

    private func presentUpdateWindow(for release: AppUpdateRelease) {
        promptedVersion = release.version
        downloadError = nil

        updateWindow?.close()

        let rootView = UpdatePromptView(
            release: release,
            currentVersion: currentVersion,
            manager: self,
            onInstall: { [weak self] in
                self?.downloadAndInstall(release)
            },
            onSkip: { [weak self] in
                self?.skip(release)
            },
            onRemindLater: { [weak self] in
                self?.remindLater(release)
            },
            onOpenRelease: { [weak self] in
                self?.openReleasePage(release)
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Software Update"
        window.identifier = NSUserInterfaceItemIdentifier("software-update")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.delegate = self
        window.center()
        updateWindow = window
        activateApplicationForPresentation()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        if closingWindow === checkingWindow {
            checkingWindow = nil
            cancelCheck()
            return
        }
        guard closingWindow === updateWindow else { return }

        updateWindow = nil
        if let promptedVersion,
           defaults.string(forKey: skippedVersionKey) != promptedVersion {
            defaults.set(Date().addingTimeInterval(AppUpdateConfiguration.automaticCheckInterval), forKey: remindLaterDateKey)
        }
    }

    func skip(_ release: AppUpdateRelease) {
        defaults.set(release.version, forKey: skippedVersionKey)
        defaults.removeObject(forKey: remindLaterDateKey)
        updateWindow?.close()
    }

    func remindLater(_ release: AppUpdateRelease) {
        defaults.set(Date().addingTimeInterval(AppUpdateConfiguration.automaticCheckInterval), forKey: remindLaterDateKey)
        updateWindow?.close()
    }

    func openReleasePage(_ release: AppUpdateRelease) {
        NSWorkspace.shared.open(release.releasePageURL)
    }

    private func downloadAndInstall(_ release: AppUpdateRelease) {
        guard !isDownloading else { return }

        guard let downloadURL = release.downloadURL else {
            openReleasePage(release)
            return
        }

        guard release.downloadFileName?.lowercased().hasSuffix(".zip") == true else {
            NSWorkspace.shared.open(downloadURL)
            return
        }

        isDownloading = true
        downloadError = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let appURL = try await self.downloadAndExtract(downloadURL, expectedVersion: release.version)
                self.isDownloading = false
                self.launchReplacementApp(appURL)
            } catch is CancellationError {
                self.isDownloading = false
            } catch {
                self.isDownloading = false
                self.downloadError = error.localizedDescription
            }
        }
    }

    private func downloadAndExtract(_ downloadURL: URL, expectedVersion: String) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw UpdateManagerError.invalidResponse
        }

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RememberMyWindows-update-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = rootURL.appendingPathComponent(downloadURL.lastPathComponent)
        let extractedURL = rootURL.appendingPathComponent("extracted", isDirectory: true)

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
        try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)

        let candidateURL = try await Task.detached(priority: .userInitiated) {
            try UpdateArchiveInstaller.extractApp(from: archiveURL, into: extractedURL)
        }.value

        guard let bundle = Bundle(url: candidateURL),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              AppVersion(version) >= AppVersion(expectedVersion) else {
            throw UpdateManagerError.invalidUpdateBundle
        }

        return candidateURL
    }

    private func launchReplacementApp(_ newAppURL: URL) {
        let currentAppURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let applicationDirectory = currentAppURL.deletingLastPathComponent()

        guard currentAppURL.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: applicationDirectory.path) else {
            downloadError = "This copy cannot update itself from its current location. Open the GitHub release to install the ZIP manually."
            return
        }

        let helperURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RememberMyWindows-install-\(UUID().uuidString).sh")

        let script = """
        #!/bin/sh
        set -eu
        old_app="$1"
        new_app="$2"
        app_pid="$3"
        while kill -0 "$app_pid" 2>/dev/null; do
            sleep 0.2
        done
        backup_app="${old_app}.previous-update.${app_pid}"
        rm -rf "$backup_app"
        if [ -e "$old_app" ]; then
            if ! mv "$old_app" "$backup_app"; then
                open "$old_app" || true
                rm -f "$0"
                exit 1
            fi
        fi
        if ! mv "$new_app" "$old_app"; then
            rm -rf "$old_app"
            if [ -e "$backup_app" ]; then
                mv "$backup_app" "$old_app"
            fi
            open "$old_app" || true
            rm -f "$0"
            exit 1
        fi
        rm -rf "$backup_app"
        open "$old_app"
        rm -f "$0"
        """

        do {
            try script.write(to: helperURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)

            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/sh")
            helper.arguments = [helperURL.path, currentAppURL.path, newAppURL.path, String(ProcessInfo.processInfo.processIdentifier)]
            try helper.run()
            NSApp.terminate(nil)
        } catch {
            isDownloading = false
            downloadError = error.localizedDescription
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = lz("You're Up to Date")
        alert.informativeText = String(format: lz("RememberMyWindows %@ is the latest version."), currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: lz("OK"))
        activateApplicationForPresentation()
        alert.runModal()
    }

    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = lz("Unable to Check for Updates")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: lz("OK"))
        activateApplicationForPresentation()
        alert.runModal()
    }

    private func normalizedVersion(_ rawVersion: String) -> String {
        let trimmed = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("v") || trimmed.hasPrefix("V") ? String(trimmed.dropFirst()) : trimmed
    }
}

private struct UpdateCheckingView: View {
    var onCancel: () -> Void

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.regular)
                    .accessibilityLabel(Text("Checking for Updates…".localized(appLanguage)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Checking for Updates…".localized(appLanguage))
                        .font(.headline)
                    Text("Connecting to GitHub to check for the latest version.".localized(appLanguage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("Cancel".localized(appLanguage), action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 420)
        .frame(minHeight: 150)
    }
}

// MARK: - Update prompt

private struct UpdatePromptView: View {
    var release: AppUpdateRelease
    var currentVersion: String
    @ObservedObject var manager: UpdateManager
    var onInstall: () -> Void
    var onSkip: () -> Void
    var onRemindLater: () -> Void
    var onOpenRelease: () -> Void

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private var hasZipPackage: Bool {
        release.downloadFileName?.lowercased().hasSuffix(".zip") == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("A new version of RememberMyWindows is available!".localized(appLanguage))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(String(format: "Version %@ is now available—you have %@. Would you like to download it now?".localized(appLanguage), release.version, currentVersion))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(release.title)
                    .font(.system(size: 17, weight: .semibold))

                ScrollView {
                    Text(release.notes.isEmpty ? "No release notes were provided.".localized(appLanguage) : release.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 190)
                .padding(12)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Spacer(minLength: 18)

            if manager.isDownloading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Downloading update…".localized(appLanguage))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)
            } else if let downloadError = manager.downloadError {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(downloadError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Button("Open GitHub Release".localized(appLanguage), action: onOpenRelease)
                        .buttonStyle(.link)
                        .font(.system(size: 12, weight: .medium))
                }
                    .padding(.bottom, 10)
            }

            HStack(spacing: 10) {
                Button("Skip This Version".localized(appLanguage), action: onSkip)
                    .buttonStyle(.bordered)

                Button("Remind Me Later".localized(appLanguage), action: onRemindLater)
                    .buttonStyle(.bordered)

                Spacer()

                if hasZipPackage {
                    Button("Install Update".localized(appLanguage), action: onInstall)
                        .buttonStyle(.borderedProminent)
                        .coloredActionButtonEffect()
                        .disabled(manager.isDownloading)
                } else {
                    Button("View Release".localized(appLanguage), action: onOpenRelease)
                        .buttonStyle(.borderedProminent)
                        .coloredActionButtonEffect()
                }
            }
        }
        .padding(28)
        .frame(minWidth: 650, minHeight: 500)
        .environment(\.layoutDirection, appLanguage == .hebrew ? .rightToLeft : .leftToRight)
    }
}

// MARK: - GitHub API models

private struct GitHubReleaseResponse: Decodable {
    var tagName: String
    var name: String?
    var body: String?
    var htmlURL: URL
    var draft: Bool
    var prerelease: Bool
    var assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubAsset: Decodable {
    var name: String
    var browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private enum UpdateArchiveInstaller {
    static func extractApp(from archiveURL: URL, into destinationURL: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateManagerError.extractionFailed(message?.isEmpty == false ? message! : "The update ZIP could not be opened.")
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: destinationURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw UpdateManagerError.invalidUpdateBundle
        }

        for case let candidateURL as URL in enumerator where candidateURL.pathExtension == "app" {
            return candidateURL
        }

        throw UpdateManagerError.invalidUpdateBundle
    }
}

private struct AppVersion: Comparable, Sendable {
    var components: [Int]

    init(_ rawValue: String) {
        let values = rawValue.split { !$0.isNumber }.compactMap { Int($0) }
        components = values.isEmpty ? [0] : values
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
