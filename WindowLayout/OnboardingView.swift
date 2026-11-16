import SwiftUI
import AppKit
import Carbon

// MARK: - Root

struct OnboardingView: View {
    var onComplete: () -> Void

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @State private var phase: OnboardingPhase = .setup

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            switch phase {
            case .setup:
                OnboardingSetupView(selectedLanguage: $appLanguage) {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                        phase = .guide
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .guide:
                OnboardingGuideView(language: appLanguage, onComplete: onComplete)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: 760, height: 460)
        .environment(\.layoutDirection, appLanguage.usesHebrew ? .rightToLeft : .leftToRight)
        .appThemeColorScheme(themeColor)
    }
}

private enum OnboardingPhase { case setup, guide }

// MARK: - Phase 1: Permissions & Mode

struct OnboardingSetupView: View {
    @EnvironmentObject private var manager: WindowManager
    @Binding var selectedLanguage: AppLanguage
    var onContinue: () -> Void

    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasFinderAutomation = false
    @State private var permissionTimer: Timer?

    private var allGranted: Bool { hasAccessibility && hasFinderAutomation }

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: 14) {
                modePickerPanel
                permissionsPanel
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 10)

            footer
        }
        .padding(.vertical, 24)
        .onAppear {
            startPermissionMonitoring()
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private var appIconImage: NSImage? {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        if let image = NSImage(contentsOfFile: "/Applications/RememberMyWindows/AppIcon.png") {
            return image
        }
        if let image = NSImage(contentsOfFile: "/Applications/RememberMyWindows/WindowLayout/AppIcon.png") {
            return image
        }
        if let image = NSImage(contentsOfFile: "/Applications/RememberMyWindows/WindowLayout/AppIcon.icns") {
            return image
        }
        if let icon = NSApp?.applicationIconImage {
            return icon
        }
        return NSImage(named: "AppIcon")
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let icon = appIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            } else {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                        .overlay { Circle().stroke(Color.accentColor.opacity(0.22), lineWidth: 1) }
                        .shadow(color: Color.accentColor.opacity(0.22), radius: 18, x: 0, y: 6)

                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 27, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(alignment: selectedLanguage.usesHebrew ? .trailing : .leading, spacing: 2) {
                Text("RememberMyWindows")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Your window manager".localized(selectedLanguage))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: selectedLanguage.usesHebrew ? .trailing : .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
    }

    private var modePickerPanel: some View {
        OBIllustrationModePicker(isWindowServerInitializing: manager.isWindowServerInitializing)
            .frame(width: 360, height: 220)
            .liquidGlass(cornerRadius: 16, style: .card)
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Choose your layout mode".localized(selectedLanguage))
    }

    private var permissionsPanel: some View {
        VStack(alignment: selectedLanguage.usesHebrew ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill((allGranted ? Color.green : Color.orange).opacity(0.14))
                        .frame(width: 30, height: 30)

                    Image(systemName: allGranted ? "checkmark.shield.fill" : "lock.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(allGranted ? Color.green : Color.orange)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: selectedLanguage.usesHebrew ? .trailing : .leading, spacing: 1) {
                    Text(allGranted ? "Permissions granted".localized(selectedLanguage) : "Permissions Required".localized(selectedLanguage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(allGranted ? Color.green : Color.primary)

                    Text("Two quick permissions let RememberMyWindows do its job properly.".localized(selectedLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: selectedLanguage.usesHebrew ? .trailing : .leading)
            }

            permissionCard(
                icon: "folder.fill",
                iconColor: .blue,
                title: "Finder Control".localized(selectedLanguage),
                description: "Required for the Desktop Toggle — collapses and restores Finder windows.".localized(selectedLanguage),
                isGranted: hasFinderAutomation,
                buttonLabel: "Grant Finder Access…".localized(selectedLanguage)
            ) {
                triggerFinderPermission()
            }

            permissionCard(
                icon: "figure.wave",
                iconColor: .orange,
                title: "Accessibility".localized(selectedLanguage),
                description: "Needed to restore window positions in apps like Chrome, Telegram, etc.".localized(selectedLanguage),
                isGranted: hasAccessibility,
                buttonLabel: "Grant Accessibility…".localized(selectedLanguage)
            ) {
                openAccessibilitySettings()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if manager.isWindowServerInitializing {
                WindowServerLoadingStatus(language: selectedLanguage)
                    .transition(.opacity)
            } else {
                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: allGranted
                              ? (selectedLanguage.usesHebrew ? "arrow.left" : "arrow.right")
                              : "lock.open.fill")
                        Text(allGranted
                             ? "Continue".localized(selectedLanguage)
                             : "Grant Permissions…".localized(selectedLanguage))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    // Both status fills are bright in Light Mode; black keeps the
                    // action label readable on either the orange or green state.
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .frame(minWidth: 188, minHeight: 42)
                    .background(allGranted ? Color.green : Color.orange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ColoredActionButtonStyle(
                    tint: allGranted ? Color.green : Color.orange,
                    shape: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                ))
                .transition(.opacity)
            }

            Button(action: onContinue) {
                Text("Skip for now".localized(selectedLanguage))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: manager.isWindowServerInitializing)
    }

    @ViewBuilder
    private func permissionCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isGranted: Bool,
        buttonLabel: String,
        onTap: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 32, height: 32)

                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.system(size: isGranted ? 14 : 15, weight: .semibold))
                    .foregroundStyle(isGranted ? AnyShapeStyle(.green) : AnyShapeStyle(iconColor))
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: selectedLanguage.usesHebrew ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isGranted ? AnyShapeStyle(.green) : AnyShapeStyle(.primary))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !isGranted {
                    Button(action: onTap) {
                        Label(buttonLabel, systemImage: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(iconColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(iconColor.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ColoredActionButtonStyle(
                        tint: iconColor,
                        shape: AnyShape(Capsule())
                    ))
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: selectedLanguage.usesHebrew ? .trailing : .leading)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isGranted ? Color.green.opacity(0.30) : Color.primary.opacity(0.10), lineWidth: 1)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGranted)
    }

    private func primaryAction() {
        if allGranted {
            onContinue()
        } else if !hasAccessibility {
            openAccessibilitySettings()
        } else if !hasFinderAutomation {
            triggerFinderPermission()
        }
    }

    private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func startPermissionMonitoring() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let ax = AXIsProcessTrusted()
            if ax != hasAccessibility {
                withAnimation { hasAccessibility = ax }
                if ax { closeSystemSettings() }
            }

            let finder = checkFinderPermissionSilently()
            if finder != hasFinderAutomation {
                withAnimation { hasFinderAutomation = finder }
            }
        }
    }

    /// Triggers the macOS Automation permission dialog for Finder from a user action.
    private func triggerFinderPermission() {
        WindowManager.shared.requestFinderAutomationPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let granted = checkFinderPermissionSilently()
            withAnimation { hasFinderAutomation = granted }
        }
    }

    /// Reads Finder's Automation permission without prompting for it.
    private func checkFinderPermissionSilently() -> Bool {
        guard let finder = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.finder")
                .first else { return false }
        var pid = finder.processIdentifier
        var target = AEAddressDesc()
        let createErr = AECreateDesc(typeKernelProcessID, &pid, MemoryLayout<pid_t>.size, &target)
        guard createErr == noErr else { return false }
        defer { AEDisposeDesc(&target) }
        let status = AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, false)
        return status == noErr
    }

    private func closeSystemSettings() {
        let targetBundleIDs = ["com.apple.systempreferences"]
        let targetNames = ["System Settings", "System Preferences", "הגדרות המערכת"]
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, targetBundleIDs.contains(bundleID) {
                app.terminate()
            } else if let name = app.localizedName, targetNames.contains(name) {
                app.terminate()
            }
        }
    }
}

/// A compact, app-owned loading state for the short WindowServer startup scan.
/// Keeping it in the existing onboarding file also lets the main window reuse
/// the same visual language without introducing another project resource.
struct WindowServerLoadingStatus: View {
    enum Style {
        case onboarding
        case toolbar
    }

    var language: AppLanguage
    var style: Style = .onboarding

    var body: some View {
        styledStatus
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Preparing window tracking…".localized(language)))
    }

    @ViewBuilder
    private var styledStatus: some View {
        switch style {
        case .onboarding:
            statusContent
                .padding(.horizontal, 22)
                .frame(minWidth: 188, minHeight: 42)
                .background(Color.primary.opacity(0.07), in: Capsule())
        case .toolbar:
            statusContent
        }
    }

    private var statusContent: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.small)
                .tint(.accentColor)

            Text("Preparing window tracking… ".localized(language))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Phase 2: Guided Tour

struct OnboardingGuideView: View {
    let language: AppLanguage
    var onComplete: () -> Void

    @ObservedObject private var desktopToggleManager = DesktopToggleManager.shared
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentSlide = 0
    @State private var hoverPreviousArrow = false
    @State private var hoverNextArrow = false

    private var guideAccent: Color {
        themeColor.color(seed: 0)
    }

    private var guideAccentText: Color {
        if themeColor.isGalaxy {
            return .black
        }
        return themeColor.onAccentColor(for: colorScheme)
    }

    // Personalisation comes immediately after the setup/permissions screen,
    // before the feature walkthrough begins. Keep the settings carousel's
    // regular feature order unchanged by reordering only this tour sequence.
    private var slides: [OBSlide] {
        _ = desktopToggleManager.hotkey
        return OBSlide.onboarding(for: language)
    }
    private var isLast: Bool { currentSlide == slides.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Slide area
            ZStack {
                ForEach(slides.indices, id: \.self) { i in
                    if i == currentSlide {
                        OBSlideView(slide: slides[i], language: language)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .id(currentSlide)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentSlide)

            // Controls
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    navigationArrowButton(isNext: false)

                    HStack(spacing: 8) {
                        ForEach(slides.indices, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    currentSlide = i
                                }
                            } label: {
                                Capsule()
                                    .fill(i == currentSlide ? Color.accentColor : Color.primary.opacity(0.2))
                                    .frame(width: i == currentSlide ? 22 : 8, height: 8)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSlide)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(String(
                                format: "Tour page %d of %d".localized(language),
                                i + 1,
                                slides.count
                            )))
                            .accessibilityAddTraits(i == currentSlide ? .isSelected : [])
                        }
                    }

                    navigationArrowButton(isNext: true)
                }

                Button {
                    if isLast {
                        onComplete()
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            currentSlide += 1
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(isLast
                             ? "Get Started".localized(language)
                             : "Next".localized(language))
                        Image(systemName: isLast ? "checkmark" : (language.usesHebrew ? "arrow.left" : "arrow.right"))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(guideAccentText)
                    .padding(.horizontal, 24).frame(minHeight: 44)
                    .background(guideAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ColoredActionButtonStyle(
                    tint: guideAccent,
                    shape: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                ))
            }
            .padding(.bottom, 36)
        }
        .environment(\.layoutDirection, language.usesHebrew ? .rightToLeft : .leftToRight)
    }

    private func navigationArrowButton(isNext: Bool) -> some View {
        let isEnabled = isNext ? !isLast : currentSlide > 0
        let isHovered = isNext ? hoverNextArrow : hoverPreviousArrow
        let label = (isNext ? "Next tour page" : "Previous tour page").localized(language)
        let symbol = isNext
            ? (language.usesHebrew ? "chevron.left" : "chevron.right")
            : (language.usesHebrew ? "chevron.right" : "chevron.left")

        return Button {
            let destination = currentSlide + (isNext ? 1 : -1)
            guard slides.indices.contains(destination) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                currentSlide = destination
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(isEnabled ? 0.82 : 0.28))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(Color.primary.opacity(isHovered && isEnabled ? 0.10 : 0.045))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            if isNext {
                hoverNextArrow = hovering
            } else {
                hoverPreviousArrow = hovering
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isHovered)
        .help(label)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Slide Model

struct OBSlide: Identifiable {
    let id: Int
    let headline: String
    let body: String
    let illustration: AnyView

    @MainActor
    static func all(for lang: AppLanguage) -> [OBSlide] {
        [
            // 0: Save layout
            OBSlide(id: 0,
                    headline: "Your Windows, Always Where You Left Them".localized(lang),
                    body: "Save your layout once. It'll be there every time you need it.".localized(lang),
                    illustration: AnyView(OBIllustrationSave())),
            // 1: Live preview
            OBSlide(id: 1,
                    headline: "See Everything at Once".localized(lang),
                    body: "A live minimap shows every open window across all your screens — no guessing.".localized(lang),
                    illustration: AnyView(OBIllustrationLive())),
            // 2: Auto-restore
            OBSlide(id: 2,
                    headline: "Plug In, Pick Up Where You Left Off".localized(lang),
                    body: "Reconnect a monitor or launch an app and your windows go right back where they belong.".localized(lang),
                    illustration: AnyView(OBIllustrationRestore())),
            // 3: Menu bar left/right click
            OBSlide(id: 3,
                    headline: "Two Clicks, Two Powers".localized(lang),
                    body: "Left click: restore the current app and open the window list. Right click: restore every app in one shot.".localized(lang),
                    illustration: AnyView(OBIllustrationMenuBar())),
            // 4: desktop toggle
            OBSlide(id: 4,
                    headline: "Hide Everything, Instantly".localized(lang),
                    body: "Press this shortcut to hide all windows and reveal the desktop. Press it again to bring them back.".localized(lang),
                    illustration: AnyView(OBIllustrationDesktopToggle())),
            // 5: Cmd+Shift+R post-restore action
            OBSlide(id: 5,
                    headline: "Do More After Every Restore".localized(lang),
                    body: "After restoring windows, RememberMyWindows can fire ⌘⇧R in your active app — Reading Mode in Safari, Hard Reload in Chrome, or PiP for a video.".localized(lang),
                    illustration: AnyView(OBIllustrationCmdShiftR())),
            // 6: Quick Key Restore
            OBSlide(id: 6,
                    headline: "Hold Fn or Double-Tap ⇪".localized(lang),
                    body: "Restore your layout instantly by holding the Fn / Globe (🌐) key or double-tapping Caps Lock — customizable in Settings.".localized(lang),
                    illustration: AnyView(OBIllustrationQuickKey())),
            // 7: Settings guide
            OBSlide(id: 7,
                    headline: "Fine-Tune How It Works".localized(lang),
                    body: "Tweak auto-restore, the desktop toggle, notch alerts, and more — all in Settings.".localized(lang),
                    illustration: AnyView(OBIllustrationSettingsGuide())),
            // 8: Customise
            OBSlide(id: 8,
                    headline: "Make It Feel Like Home".localized(lang),
                    body: "Pick your accent colour and language in Settings. Small details, big difference.".localized(lang),
                    illustration: AnyView(OBIllustrationCustomize())),
        ]
    }

    @MainActor
    static func onboarding(for lang: AppLanguage) -> [OBSlide] {
        let slides = all(for: lang)
        guard let customize = slides.first(where: { $0.id == 8 }) else {
            return slides
        }

        return [customize] + slides.filter { $0.id != customize.id }
    }
}

struct OBSlideView: View {
    let slide: OBSlide
    let language: AppLanguage

    @State private var settingsActiveIndex = 0
    @State private var timer: Timer?
    @ObservedObject private var desktopMgr = DesktopToggleManager.shared

    var body: some View {
        HStack(spacing: 24) {
            Spacer(minLength: 4)

            // High-detail realistic macOS Sequoia mockup canvas
            ZStack {
                if slide.id == 7 {
                    OBIllustrationSettingsGuide(activeIndex: settingsActiveIndex)
                } else {
                    slide.illustration
                }
            }
            .frame(width: 356, height: 236)
            .clipped()

            // Onboarding explainers keep their supporting copy. The separate
            // Settings Feature Guide carousel controls its own shorter layout.
            VStack(alignment: language.usesHebrew ? .trailing : .leading, spacing: 10) {
                Text(slide.headline)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(language.usesHebrew ? .trailing : .leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if slide.id == 7 {
                    Text(getSettingsDescription(for: settingsActiveIndex, lang: language))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(language.usesHebrew ? .trailing : .leading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(settingsActiveIndex)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                } else if slide.id == 4 {
                    // Keep the localized explanation separate from the editable shortcut.
                    OBDesktopToggleBodyView(
                        language: language,
                        explanation: slide.body,
                        hotkey: $desktopMgr.hotkey
                    )
                } else {
                    Text(slide.body)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(language.usesHebrew ? .trailing : .leading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 200, alignment: language.usesHebrew ? .trailing : .leading)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .onAppear {
            if slide.id == 7 {
                timer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        settingsActiveIndex = (settingsActiveIndex + 1) % 4
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func getSettingsDescription(for index: Int, lang: AppLanguage) -> String {
        switch index {
        case 0:
            return "Restores window layouts automatically when you plug/unplug monitors or open apps.".localized(lang)
        case 1:
            return String(format: "Hit %@ to hide all windows and see your desktop. Hit it again to bring them back.".localized(lang), HotkeyFormatter.desktopToggleGlyphs)
        case 2:
            return "A pill-shaped alert slides out of the notch when layouts restore — subtle but satisfying.".localized(lang)
        case 3:
            return "Control what shows up in the activity log. 'Necessary' keeps it quiet, 'Verbose' tells you everything.".localized(lang)
        default:
            return ""
        }
    }
}

// MARK: - Desktop Toggle slide: localized explanation + shortcut recorder

/// Shows the desktop-toggle explanation above a clearly editable shortcut control.
private struct OBDesktopToggleBodyView: View {
    let language: AppLanguage
    let explanation: String
    @Binding var hotkey: HotkeyConfig

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        OBDesktopToggleShortcutEditor(
                language: language,
                explanation: explanation,
                hotkey: $hotkey,
                isRecording: $isRecording,
                onTap: { startRecording() }
            )
        .onDisappear { stopRecording() }
        .environment(\.layoutDirection, language.usesHebrew ? .rightToLeft : .leftToRight)
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // Escape → cancel
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection([.command, .control, .option, .shift])
            guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
                return nil
            }
            hotkey = HotkeyConfig(keyCode: event.keyCode, rawModifierFlags: flags.rawValue)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        isRecording = false
    }
}

// MARK: - Desktop Toggle shortcut editor

/// Keeps explanatory copy separate from the keycaps, so mixed Hebrew/Latin
/// text stays readable and the keycaps remain in their conventional order.
private struct OBDesktopToggleShortcutEditor: View {
    let language: AppLanguage
    let explanation: String
    @Binding var hotkey: HotkeyConfig
    @Binding var isRecording: Bool
    var onTap: () -> Void

    @State private var isHovered = false
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tokens: [String] {
        var t: [String] = []
        let m = hotkey.modifierFlags
        if m.contains(.control) { t.append("⌃") }
        if m.contains(.option)  { t.append("⌥") }
        if m.contains(.shift)   { t.append("⇧") }
        if m.contains(.command) { t.append("⌘") }
        if !hotkey.isEmpty { t.append(HotkeyFormatter.name(for: hotkey.keyCode)) }
        return t
    }

    // Splits the explanation around the placeholder word so key caps appear between the two halves.
    private func splitExplanation() -> (before: String, after: String) {
        let placeholder = "this shortcut"
        let localizedPlaceholder = placeholder.localized(language)
        let src = explanation
        if let r = src.range(of: localizedPlaceholder) {
            return (String(src[src.startIndex..<r.lowerBound]),
                    String(src[r.upperBound...]))
        }
        return (src, "")
    }

    var body: some View {
        let (before, after) = splitExplanation()

        VStack(alignment: .leading, spacing: 2) {
            // First fragment of the explanation (e.g. "Press ")
            if !before.isEmpty {
                Text(before.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Keycaps — only interactive part
            Button(action: onTap) {
                HStack(spacing: 3) {
                    if isRecording {
                        Text("…")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.orange)
                    } else {
                        ForEach(tokens, id: \.self) { token in
                            keyCap(token)
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help(isRecording
                  ? "Press a key combination — Esc cancels".localized(language)
                  : "Click to record a new shortcut".localized(language))
            .accessibilityLabel(Text("Desktop Toggle shortcut".localized(language)))
            .accessibilityValue(Text(isRecording
                                     ? "Press a key combination — Esc cancels".localized(language)
                                     : HotkeyFormatter.glyphs(for: hotkey)))
            .accessibilityHint(Text(isRecording
                                    ? "Press a key combination — Esc cancels".localized(language)
                                    : "Click to record a new shortcut".localized(language)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isRecording)

            // Second fragment of the explanation (e.g. " to hide all windows…")
            if !after.isEmpty {
                Text(after.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private func keyCap(_ label: String) -> some View {
        let glowing = isPulsing && !isHovered && !isRecording && !reduceMotion
        return Text(label)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(isHovered ? Color.primary : Color.primary.opacity(0.82))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.10 : 0.07))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        Color.accentColor.opacity(isHovered ? 0.55 : (glowing ? 0.65 : 0.18)),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: Color.accentColor.opacity(glowing ? 0.45 : 0.0),
                radius: glowing ? 5 : 0,
                x: 0, y: 0
            )
    }

}




// MARK: - Shared Realistic macOS Tour Components

struct TourDesktopBackground: View {
    var body: some View {
        Color.clear
    }
}

struct RealisticTrafficLights: View {
    var size: CGFloat = 5
    var body: some View {
        HStack(spacing: 3.5) {
            Circle()
                .fill(Color(red: 1.0, green: 0.36, blue: 0.32))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
            Circle()
                .fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
        }
    }
}

struct TourTrafficLights: View {
    var size: CGFloat = 5
    var body: some View {
        RealisticTrafficLights(size: size)
    }
}

// MARK: - Photorealistic Universal App Windows

struct RealisticSafariWindow: View {
    var width: CGFloat = 145
    var height: CGFloat = 85
    var urlText: String = "apple.com/macos"
    var tabTitle: String = "macOS Sequoia"
    var showsText: Bool = true
    var isReaderMode: Bool = false
    var isHighlightBorder: Bool = false
    var highlightColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            tabStripView
            contentBodyView
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHighlightBorder ? highlightColor.opacity(0.85) : Color.white.opacity(0.18), lineWidth: isHighlightBorder ? 1.0 : 0.6)
        )
        .shadow(color: isHighlightBorder ? highlightColor.opacity(0.35) : Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }

    private var toolbarView: some View {
        HStack(spacing: 4) {
            RealisticTrafficLights(size: 4)

            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                Image(systemName: "chevron.right")
                    .font(.system(size: 5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.leading, 1)

            HStack(spacing: 3) {
                Image(systemName: isReaderMode ? "doc.plaintext.fill" : "lock.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(isReaderMode ? .blue : .white.opacity(0.5))
                if showsText {
                    Text(urlText)
                        .font(.system(size: 6, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.32))
                        .frame(height: 2.5)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 4.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))

            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 5.5))
                .foregroundStyle(.white.opacity(0.5))
            Image(systemName: "plus")
                .font(.system(size: 5.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Color(white: 0.16).opacity(0.95))
    }

    private var tabStripView: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(.blue)
                if showsText {
                    Text(tabTitle)
                        .font(.system(size: 5.5, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 26, height: 2.5)
                }
                Image(systemName: "xmark")
                    .font(.system(size: 4.5))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color(white: 0.22), in: RoundedRectangle(cornerRadius: 3))
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(white: 0.12))
    }

    private var contentBodyView: some View {
        ZStack {
            Color(white: 0.08)

            if isReaderMode && showsText {
                VStack(alignment: .leading, spacing: 3) {
                    Text("The Future of macOS")
                        .font(.system(size: 7.5, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text("Streamlined productivity through automated window layouts and dynamic display management.")
                        .font(.system(size: 5.5, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(3)
                        .lineSpacing(1.5)
                    Spacer()
                }
                .padding(6)
                .transition(.opacity)
            } else if isReaderMode {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 72, height: 3)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 120, height: 2)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 92, height: 2)
                    Spacer()
                }
                .padding(6)
                .transition(.opacity)
            } else {
                VStack(spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1.5) {
                            RoundedRectangle(cornerRadius: 1).fill(Color.blue).frame(width: 24, height: 3)
                            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.7)).frame(width: 50, height: 2.5)
                        }
                        Spacer()
                        Circle().fill(Color.purple.opacity(0.6)).frame(width: 12, height: 12)
                    }
                    .padding(4)
                    .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 3))

                    HStack(spacing: 3) {
                        VStack(alignment: .leading, spacing: 1.5) {
                            RoundedRectangle(cornerRadius: 1).fill(Color.orange.opacity(0.7)).frame(height: 10)
                            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.4)).frame(width: 28, height: 2)
                        }
                        .padding(2)
                        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 2))

                        VStack(alignment: .leading, spacing: 1.5) {
                            RoundedRectangle(cornerRadius: 1).fill(Color.green.opacity(0.7)).frame(height: 10)
                            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.4)).frame(width: 28, height: 2)
                        }
                        .padding(2)
                        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 2))
                    }
                }
                .padding(5)
            }
        }
    }
}

struct RealisticXcodeWindow: View {
    var width: CGFloat = 145
    var height: CGFloat = 85
    var fileName: String = "WindowLayout.swift"
    var isHighlightBorder: Bool = false
    var highlightColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 0) {
            // Xcode Toolbar
            HStack(spacing: 4) {
                RealisticTrafficLights(size: 4)

                // Scheme pill
                HStack(spacing: 2.5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 4.5))
                        .foregroundStyle(.green)
                    Text("RememberMyWindows")
                        .font(.system(size: 5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 3.5))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Mac")
                        .font(.system(size: 5))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "swift")
                        .font(.system(size: 5))
                        .foregroundStyle(.orange)
                    Text(fileName)
                        .font(.system(size: 5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color(red: 0.13, green: 0.14, blue: 0.17))

            // Editor with Navigator Sidebar & Gutter
            HStack(spacing: 0) {
                // Mini Project Navigator Sidebar
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 2) {
                        Image(systemName: "folder.fill").font(.system(size: 4)).foregroundStyle(.blue)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.4)).frame(width: 14, height: 2)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "swift").font(.system(size: 4)).foregroundStyle(.orange)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.6)).frame(width: 18, height: 2)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "swift").font(.system(size: 4)).foregroundStyle(.orange)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.3)).frame(width: 12, height: 2)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 3)
                .frame(width: 26)
                .background(Color(red: 0.11, green: 0.12, blue: 0.14))

                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5)

                // Code Gutter + Syntax Highlighted Editor
                VStack(alignment: .leading, spacing: 2) {
                    // Line 1: import SwiftUI
                    HStack(spacing: 3) {
                        Text("1").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).frame(width: 6)
                        Text("import").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                        Text("SwiftUI").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(Color(red: 0.38, green: 0.78, blue: 0.92))
                    }
                    // Line 2: struct WindowManager {
                    HStack(spacing: 3) {
                        Text("2").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).frame(width: 6)
                        Text("struct").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                        Text("Layout").font(.system(size: 4.5, weight: .semibold, design: .monospaced)).foregroundStyle(Color(red: 0.96, green: 0.82, blue: 0.44))
                        Text(": View {").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                    }
                    // Line 3: @State var isRestored = true
                    HStack(spacing: 3) {
                        Text("3").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).frame(width: 6)
                        Text("  @State").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(Color(red: 0.88, green: 0.55, blue: 0.28))
                        Text("var").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                        Text("saved").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white)
                        Text("= true").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(Color(red: 0.38, green: 0.78, blue: 0.92))
                    }
                    // Line 4: var body: some View {
                    HStack(spacing: 3) {
                        Text("4").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).frame(width: 6)
                        Text("  var").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                        Text("body:").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.9))
                        Text("some").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.65))
                        Text("View").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(Color(red: 0.38, green: 0.78, blue: 0.92))
                    }
                    // Line 5: restoreWindows()
                    HStack(spacing: 3) {
                        Text("5").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).frame(width: 6)
                        Text("    restoreLayout()").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(Color(red: 0.45, green: 0.75, blue: 0.98))
                    }
                    // Line 6: }
                    HStack(spacing: 3) {
                        Text("6").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).frame(width: 6)
                        Text("  }").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.09, green: 0.10, blue: 0.12))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHighlightBorder ? highlightColor.opacity(0.85) : Color.white.opacity(0.18), lineWidth: isHighlightBorder ? 1.0 : 0.6)
        )
        .shadow(color: isHighlightBorder ? highlightColor.opacity(0.35) : Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

struct RealisticTerminalWindow: View {
    var width: CGFloat = 135
    var height: CGFloat = 75
    var isHighlightBorder: Bool = false
    var highlightColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 0) {
            // Terminal Header
            HStack(spacing: 4) {
                RealisticTrafficLights(size: 4)
                Spacer()
                Text("zsh — 80×24")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(white: 0.14))

            // Terminal Console Body
            VStack(alignment: .leading, spacing: 2.5) {
                // Command line
                HStack(spacing: 3) {
                    Text("~/Projects").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.cyan)
                    Text("(main)").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(Color.yellow)
                    Text("❯").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.green)
                    Text("remember-windows").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white)
                }

                // Output lines
                HStack(spacing: 3) {
                    Circle().fill(Color.green).frame(width: 3, height: 3)
                    Text("Active layout loaded: Studio Display").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
                }

                HStack(spacing: 3) {
                    Text("✓").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.green)
                    Text("3 windows restored in 0.2s").font(.system(size: 4.5, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                }

                HStack(spacing: 2) {
                    Text("❯").font(.system(size: 4.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.green)
                    Rectangle().fill(Color.white).frame(width: 3, height: 6)
                }
                Spacer()
            }
            .padding(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.06))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHighlightBorder ? highlightColor.opacity(0.85) : Color.white.opacity(0.18), lineWidth: isHighlightBorder ? 1.0 : 0.6)
        )
        .shadow(color: isHighlightBorder ? highlightColor.opacity(0.35) : Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

struct RealisticNotesWindow: View {
    var width: CGFloat = 135
    var height: CGFloat = 75
    var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Notes Titlebar
            HStack(spacing: 4) {
                RealisticTrafficLights(size: 4)
                Spacer()
                Image(systemName: "note.text")
                    .font(.system(size: 5.5))
                    .foregroundStyle(.yellow)
                Text("Meeting Notes")
                    .font(.system(size: 5.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color(red: 0.16, green: 0.15, blue: 0.14))

            // Note Content
            VStack(alignment: .leading, spacing: 3) {
                Text("Project Milestones")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(.white)

                Text("Today at 2:30 PM")
                    .font(.system(size: 4.5))
                    .foregroundStyle(.yellow.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 4.5))
                            .foregroundStyle(.yellow)
                        Text("Multi-monitor auto restore")
                            .font(.system(size: 5))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "circle")
                            .font(.system(size: 4.5))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Live coordinate tracking")
                            .font(.system(size: 5))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.11, green: 0.11, blue: 0.10))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDragging ? Color.orange.opacity(0.9) : Color.white.opacity(0.2), lineWidth: isDragging ? 1.2 : 0.6)
        )
        .shadow(color: isDragging ? Color.orange.opacity(0.5) : Color.black.opacity(0.35), radius: isDragging ? 12 : 8, x: 0, y: 4)
    }
}

struct TourKeyCap: View {
    let label: String
    var icon: String? = nil
    var lit: Bool = false
    var width: CGFloat = 34
    var height: CGFloat = 28
    var activeColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(lit ? .white : .primary)
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(
                    colors: lit
                        ? [activeColor, activeColor.opacity(0.85)]
                        : [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(lit ? activeColor.opacity(0.8) : Color.white.opacity(0.25), lineWidth: 0.8)
        )
        .shadow(color: lit ? activeColor.opacity(0.45) : Color.black.opacity(0.15), radius: lit ? 6 : 2, x: 0, y: lit ? 1 : 2)
        .offset(y: lit ? 1.5 : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: lit)
    }
}

// MARK: - macOS Desktop Illustration Components

private struct MacDesktopPlainSurface: View {
    // isCollapsed is kept for API compatibility but the wallpaper itself
    // is always static — it fills the whole frame and never moves.
    // Only the window stack layer animates away in the parent view.
    var isCollapsed = false

    private var wallpaperImage: NSImage? {
        if let url = Bundle.main.url(forResource: "DesktopWallpaper", withExtension: "jpg"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    var body: some View {
        Group {
            if let img = wallpaperImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 356, height: 236)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.28, blue: 0.05),
                        Color(red: 0.30, green: 0.15, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: 356, height: 236)
        .clipped()
    }
}

private struct MacDesktopMenuBar: View {
    static let width: CGFloat = 356
    static let height: CGFloat = 26
    static let topInset: CGFloat = 0

    var showsSystemStatus: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "applelogo")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 6)

            if showsSystemStatus {
                HStack(spacing: 8) {
                    Text("9:41")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    Image(systemName: "wifi")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.55))
                    Image(systemName: "battery.75")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.55))
                }
            } else {
                HStack(spacing: 8) {
                    Text("9:41")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    Image(systemName: "wifi")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: Self.width, height: Self.height)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
        )
        .padding(.top, Self.topInset)
    }
}

private enum MacDesktopFileKind {
    case presentation
    case pdf
    case screenshotsFolder
}

private struct MacDesktopFileIcon: View {
    let title: String
    let kind: MacDesktopFileKind

    var body: some View {
        VStack(spacing: 2.5) {
            iconArtwork

            Text(title)
                .font(.system(size: 5.8, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.80), radius: 1.2, x: 0, y: 0.8)
        }
        .frame(width: 58)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var iconArtwork: some View {
        switch kind {
        case .presentation:
            documentArtwork(accent: Color(red: 0.98, green: 0.48, blue: 0.16))
        case .pdf:
            documentArtwork(accent: Color(red: 0.91, green: 0.24, blue: 0.28))
        case .screenshotsFolder:
            Image(systemName: "folder.fill")
                .font(.system(size: 18, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.cyan)
                .frame(width: 20, height: 22)
                .shadow(color: .black.opacity(0.32), radius: 1.2, x: 0, y: 0.8)
        }
    }

    private func documentArtwork(accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(alignment: .leading, spacing: 1.3) {
                RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent, accent.opacity(0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 8)

                Rectangle()
                    .fill(Color.black.opacity(0.20))
                    .frame(width: 10, height: 0.7)
                Rectangle()
                    .fill(Color.black.opacity(0.13))
                    .frame(width: 13, height: 0.7)
                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: 8, height: 0.7)

                Spacer(minLength: 0)
            }
            .padding(2.2)

            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 5, y: 0))
                path.addLine(to: CGPoint(x: 5, y: 5))
                path.closeSubpath()
            }
            .fill(Color(white: 0.73))
            .frame(width: 5, height: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: 18, height: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .stroke(Color.black.opacity(0.24), lineWidth: 0.45)
        }
        .shadow(color: .black.opacity(0.32), radius: 1.2, x: 0, y: 0.8)
    }
}

private struct MacDesktopDock: View {
    var body: some View {
        HStack(spacing: 0) {
            dockIcon(symbol: "face.smiling", color: Color(red: 0.12, green: 0.66, blue: 0.96), label: "Finder", isRunning: true)
            Spacer(minLength: 0)
            dockIcon(symbol: "safari.fill", color: .cyan, label: "Safari", isRunning: true)
            Spacer(minLength: 0)
            dockIcon(symbol: "message.fill", color: .green, label: "Messages")
            Spacer(minLength: 0)
            dockIcon(symbol: "note.text", color: .orange, label: "Notes", isRunning: true)
            Spacer(minLength: 0)
            dockIcon(symbol: "hammer.fill", color: .purple, label: "Xcode", isRunning: true)
            Spacer(minLength: 7)

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 0.7, height: 18)
                .padding(.horizontal, 4)

            Spacer(minLength: 7)
            dockIcon(symbol: "trash.fill", color: .gray, label: "Trash")
        }
        .frame(width: 210, height: 26)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), Color.white.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.65
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.13))
                .frame(height: 0.5)
                .padding(.horizontal, 12)
                .padding(.top, 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 8, x: 0, y: 3)
    }

    private func dockIcon(symbol: String, color: Color, label: String, isRunning: Bool = false) -> some View {
        VStack(spacing: 1.5) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.96), color.opacity(0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 0.55)
                    }

                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
            }
            .frame(width: 21, height: 21)

            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 1.8, height: 1.8)
                .opacity(isRunning ? 1 : 0)
        }
        .accessibilityLabel(label)
    }
}

private struct MacShortcutBadge: View {
    let isActive: Bool
    @ObservedObject private var manager = DesktopToggleManager.shared

    var body: some View {
        SettingsShortcutRecorder(
            title: "Desktop Toggle shortcut",
            subtitle: "Press any combination with at least one modifier",
            icon: "command",
            hotkey: $manager.hotkey,
            onBeginRecording: { manager.suspendForRecording() },
            onEndRecording: { manager.resumeAfterRecording() },
            compact: true,
            isActive: isActive
        )
    }
}

// MARK: - Slide 0: Save Layout Illustration (Realistic macOS Multi-Window Shutter Snap)

struct OBIllustrationSave: View {
    @State private var isSaved = false
    @State private var shutterFlash = false
    @State private var showNotchPill = false
    @State private var showPolaroid = false
    @State private var polaroidScale: CGFloat = 0.3
    @State private var polaroidOffset: CGSize = .zero
    @State private var cursorX: CGFloat = -90
    @State private var cursorY: CGFloat = 40
    @State private var cursorPressed = false
    @State private var timer: Timer?
    @State private var isMounted = false
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        ZStack {
            TourDesktopBackground()


            // Slim Menu Bar
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    // Save Layout icon button — no text
                    ZStack {
                        Capsule()
                            .fill(cursorPressed ? Color.accentColor : Color.white.opacity(0.15))
                            .frame(width: 26, height: 18)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(cursorPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.18), value: cursorPressed)

                    // Clock & status
                    HStack(spacing: 6) {
                        Text("9:41")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                        Image(systemName: "wifi")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 12)
                .frame(width: 356, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                )
                .padding(.top, 4)

                Spacer()
            }

            // Three app windows on the vivid desktop
            ZStack {
                RealisticSafariWindow(
                    width: 142, height: 80,
                    urlText: "apple.com/macos",
                    tabTitle: "macOS Sequoia",
                    isHighlightBorder: isSaved,
                    highlightColor: .accentColor
                )
                .offset(x: isSaved ? -70 : -85, y: isSaved ? -20 : -10)
                .rotationEffect(.degrees(isSaved ? 0 : -2))

                RealisticXcodeWindow(
                    width: 142, height: 80,
                    fileName: "WindowLayout.swift",
                    isHighlightBorder: isSaved,
                    highlightColor: .accentColor
                )
                .offset(x: isSaved ? 75 : 88, y: isSaved ? -15 : -25)
                .rotationEffect(.degrees(isSaved ? 0 : 2.5))

                RealisticTerminalWindow(
                    width: 138, height: 72,
                    isHighlightBorder: isSaved,
                    highlightColor: .accentColor
                )
                .offset(x: isSaved ? 0 : -15, y: isSaved ? 42 : 52)
                .rotationEffect(.degrees(isSaved ? 0 : -1))
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: isSaved)

            // Camera shutter white flash
            if shutterFlash {
                Color.white.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Polaroid thumbnail flying to top-right corner
            if showPolaroid {
                PolaroidThumbnail()
                    .scaleEffect(polaroidScale)
                    .offset(polaroidOffset)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Minimal pill: just checkmark + count
            if showNotchPill {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                    Text("3")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.88), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
                .shadow(color: Color.accentColor.opacity(0.45), radius: 10, x: 0, y: 3)
                .transition(.move(edge: .top).combined(with: .opacity))
                // Drop below the menu bar so the pill and its shadow stay clear of the card edge.
                .offset(y: -78)
            }

            // Animated cursor
            Image(systemName: "cursorarrow")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 1, y: 1)
                .offset(x: cursorX, y: cursorY)
                .animation(.spring(response: 0.55, dampingFraction: 0.8), value: cursorX)
                .animation(.spring(response: 0.55, dampingFraction: 0.8), value: cursorY)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { triggerSaveSnap() }
        .onAppear { isMounted = true; startAnimationLoop() }
        .onDisappear { isMounted = false; timer?.invalidate() }
    }

    private func startAnimationLoop() {
        runCycle()
        timer = Timer.scheduledTimer(withTimeInterval: 5.2, repeats: true) { _ in runCycle() }
    }

    private func runCycle() {
        withAnimation(.easeInOut(duration: 0.35)) {
            isSaved = false
            showNotchPill = false
            shutterFlash = false
            showPolaroid = false
            polaroidScale = 0.3
            polaroidOffset = .zero
            cursorX = -90
            cursorY = 40
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
                cursorX = 114
                cursorY = -92
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            cursorPressed = true
            triggerSaveSnap()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            cursorPressed = false
            withAnimation(.easeInOut(duration: 0.4)) {
                cursorX = 140
                cursorY = 60
            }
        }
    }

    private func triggerSaveSnap() {
        guard isMounted else { return }

        // 1. Shutter flash
        withAnimation(.easeOut(duration: 0.12)) { shutterFlash = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard isMounted else { return }
            withAnimation(.easeOut(duration: 0.20)) { shutterFlash = false }

            // 2. Windows snap into saved positions
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                isSaved = true
            }

            // 3. Polaroid thumbnail pops into center then flies to top-right
            showPolaroid = true
            polaroidScale = 0.3
            polaroidOffset = .zero
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                polaroidScale = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                guard isMounted else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    polaroidScale = 0.22
                    polaroidOffset = CGSize(width: 148, height: -95)
                }
            }

            // 4. Minimal notification pill
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                guard isMounted else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                    showNotchPill = true
                }
            }
        }
    }
}

// Polaroid-style layout snapshot thumbnail
private struct PolaroidThumbnail: View {
    var body: some View {
        VStack(spacing: 0) {
            // Mini screenshot area
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.12, blue: 0.26), Color(red: 0.06, green: 0.09, blue: 0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // Tiny window silhouettes
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.55)).frame(width: 28, height: 20)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.25)).frame(width: 24, height: 9)
                        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.18)).frame(width: 24, height: 9)
                    }
                }
            }
            .frame(width: 72, height: 48)

            // White polaroid border strip
            ZStack {
                Color.white
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 72, height: 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.9), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
        .rotationEffect(.degrees(-4))
    }
}

// MARK: - Slide 1: Live Minimap Radar Illustration (with drag gesture)

// MARK: - Slide 1: Live Minimap Radar Illustration (with automated cursor & menu bar popover)

private struct MiniWindowCard: View {
    let title: String
    let icon: String
    let color: Color
    var isHighlighted: Bool = false
    var highlightColor: Color = .accentColor
    var width: CGFloat = 34
    var height: CGFloat = 22

    var body: some View {
        VStack(spacing: 1.5) {
            // Micro titlebar
            HStack(spacing: 1.5) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 1.5, height: 1.5)
                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 1.5, height: 1.5)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 1.5, height: 1.5)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 2.5))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 2)
            .padding(.top, 1.5)

            // Content representation
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(1.5)
        }
        .frame(width: width, height: height)
        .background(Color(white: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .stroke(isHighlighted ? highlightColor : Color.white.opacity(0.2), lineWidth: isHighlighted ? 1.0 : 0.5)
        )
        .shadow(color: isHighlighted ? highlightColor.opacity(0.6) : Color.black.opacity(0.3), radius: isHighlighted ? 4 : 1.5)
    }
}

private struct AuthenticRememberMyWindowsMenu: View {
    let movingOffsetX: CGFloat
    let movingOffsetY: CGFloat
    let isTracking: Bool
    let isSynced: Bool
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    // Scaled coordinates for minimap
    private var miniX: CGFloat { movingOffsetX * 0.32 }
    private var miniY: CGFloat { movingOffsetY * 0.30 }
    private var displayCoordX: Int { Int((movingOffsetX + 70) * 12.5) }
    private var displayCoordY: Int { Int((movingOffsetY + 40) * 11.2) }

    var body: some View {
        VStack(spacing: 0) {
            topArrow

            VStack(alignment: .leading, spacing: 3) {
                openRow
                menuDivider
                autoLayoutHeader
                minimapCard
                latestCaptureRow
                menuDivider
                savedSessionsRow
                menuDivider
                quitRow
            }
            .padding(.vertical, 4)
            .frame(width: 142)
            .background(Color(white: 0.15).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSynced ? Color.green.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 6)
        }
    }

    private var topArrow: some View {
        HStack {
            Spacer()
            Triangle()
                .fill(Color(white: 0.15).opacity(0.96))
                .frame(width: 10, height: 5)
                .padding(.trailing, 22)
        }
    }

    private var openRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 6.5))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 10)
            Text("Open RememberMyWindows".localized(appLanguage))
                .font(.system(size: 6.5, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text("⌘O")
                .font(.system(size: 5.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
    }

    private var autoLayoutHeader: some View {
        Text("Recent Auto Captures".localized(appLanguage).uppercased())
            .font(.system(size: 5, weight: .bold))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 6)
            .padding(.top, 1)
    }

    private var minimapCard: some View {
        VStack(spacing: 3) {
            cardHeader
            minimapCanvas
        }
        .padding(4)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isSynced ? Color.green.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 0.6)
        )
        .padding(.horizontal, 4)
    }

    private var cardHeader: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.green)
                .frame(width: 4, height: 4)
                .shadow(color: Color.green.opacity(0.8), radius: 2)

            Text("Built-in Display · 1920×1080".localized(appLanguage))
                .font(.system(size: 5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            if isTracking || isSynced {
                HStack(spacing: 2) {
                    Image(systemName: "scope")
                        .font(.system(size: 4.5))
                    Text("\(displayCoordX), \(displayCoordY)")
                        .font(.system(size: 4.5, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(isSynced ? Color.green : Color.accentColor)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.4), in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 3)
    }

    private var minimapCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(Color.black.opacity(0.85))

            VStack(spacing: 6) {
                Divider().background(Color.white.opacity(0.06))
                Divider().background(Color.white.opacity(0.06))
            }

            MiniWindowCard(
                title: "Xcode",
                icon: "swift",
                color: .blue,
                isHighlighted: false,
                width: 36,
                height: 22
            )
            .offset(x: -24, y: -2)

            MiniWindowCard(
                title: "Safari",
                icon: "safari.fill",
                color: .purple,
                isHighlighted: isTracking || isSynced,
                highlightColor: isSynced ? .green : .accentColor,
                width: 34,
                height: 22
            )
            .offset(x: 18 + miniX, y: -2 + miniY)
            .animation(.spring(response: 0.55, dampingFraction: 0.8), value: movingOffsetX)
            .animation(.spring(response: 0.55, dampingFraction: 0.8), value: movingOffsetY)
        }
        .frame(width: 126, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 0.5))
    }

    private var latestCaptureRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 6.5))
                .foregroundStyle(Color.accentColor)
                .frame(width: 10)
            Text("Latest (just now) · 2 windows".localized(appLanguage))
                .font(.system(size: 6, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 4.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private var savedSessionsRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder")
                .font(.system(size: 6.5))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 10)
            Text("Saved Sessions".localized(appLanguage))
                .font(.system(size: 6.5, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 4.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
    }

    private var quitRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "power")
                .font(.system(size: 6.5))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 10)
            Text("Quit".localized(appLanguage))
                .font(.system(size: 6.5, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Text("⌘Q")
                .font(.system(size: 5.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }
}

// Simple triangle for popover arrow
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct OBIllustrationLive: View {
    // Window dragging offsets
    @State private var movingWindowX: CGFloat = 36
    @State private var movingWindowY: CGFloat = 12
    @State private var isDragging = false
    @State private var isSyncedFlash = false

    // Menu bar & Popover states
    @State private var showPopover = false
    @State private var menuBarItemActive = false

    // Animated Cursor
    @State private var cursorX: CGFloat = 60
    @State private var cursorY: CGFloat = 40
    @State private var cursorPressed = false
    @State private var cursorVisible = true

    @State private var loopTimer: Timer?
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        ZStack {
            TourDesktopBackground()

            // Desktop Canvas
            ZStack(alignment: .top) {
                // Top macOS Menu Bar Strip
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    // RememberMyWindows App Menu Bar Item
                    HStack(spacing: 3) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(menuBarItemActive ? .white : .white.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(menuBarItemActive ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4))

                    Image(systemName: "wifi")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("9:41")
                        .font(.system(size: 7.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .frame(width: 356, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                )
                .padding(.top, 4)

                // Desktop Workspace Windows
                ZStack {
                    // Left Window: Photorealistic Xcode
                    RealisticXcodeWindow(
                        width: 126,
                        height: 74,
                        fileName: "WindowLayout.swift"
                    )
                    .offset(x: -80, y: 20)

                    // Right Window: Photorealistic Safari (Animated Draggable Window)
                    RealisticSafariWindow(
                        width: 120,
                        height: 70,
                        urlText: "apple.com/macos",
                        tabTitle: "macOS",
                        isHighlightBorder: isDragging || isSyncedFlash,
                        highlightColor: isSyncedFlash ? .green : .accentColor
                    )
                    .scaleEffect(isDragging ? 1.03 : 1.0)
                    .shadow(
                        color: isSyncedFlash ? Color.green.opacity(0.5) : Color.black.opacity(isDragging ? 0.45 : 0.28),
                        radius: isDragging ? 14 : 7,
                        x: 0,
                        y: isDragging ? 8 : 4
                    )
                    .offset(x: movingWindowX, y: movingWindowY)
                    .animation(.spring(response: 0.55, dampingFraction: 0.78), value: movingWindowX)
                    .animation(.spring(response: 0.55, dampingFraction: 0.78), value: movingWindowY)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 14)

                // RememberMyWindows Dropdown Menu from Menu Bar
                if showPopover {
                    AuthenticRememberMyWindowsMenu(
                        movingOffsetX: movingWindowX - 36,
                        movingOffsetY: movingWindowY - 12,
                        isTracking: isDragging,
                        isSynced: isSyncedFlash
                    )
                    // Keep the popover body and its shadow inside the illustration canvas.
                    .offset(x: 98, y: 17)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity)
                    ))
                }

                // Photorealistic macOS Cursor
                if cursorVisible {
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2.5, x: 0.5, y: 1.5)
                        .scaleEffect(cursorPressed ? 0.88 : 1.0)
                        .offset(x: cursorX, y: cursorY)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: cursorX)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: cursorY)
                        .animation(.easeInOut(duration: 0.15), value: cursorPressed)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            startAutomatedStoryLoop()
        }
        .onDisappear {
            loopTimer?.invalidate()
            loopTimer = nil
        }
    }

    private func startAutomatedStoryLoop() {
        runChoreographedCycle()
        loopTimer?.invalidate()
        loopTimer = Timer.scheduledTimer(withTimeInterval: 6.2, repeats: true) { _ in
            runChoreographedCycle()
        }
    }

    private func runChoreographedCycle() {
        // Reset state
        withAnimation(.easeInOut(duration: 0.35)) {
            showPopover = false
            menuBarItemActive = false
            isDragging = false
            isSyncedFlash = false
            cursorPressed = false
            movingWindowX = 36
            movingWindowY = 12
            cursorX = 75
            cursorY = 50
        }

        // 1. Cursor moves to Menu Bar icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cursorX = 138
                cursorY = -98
            }
        }

        // 2. Click Menu Bar Icon & open RememberMyWindows Menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            cursorPressed = true
            menuBarItemActive = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) {
                showPopover = true
            }
        }

        // 3. Release click & move cursor to Safari window titlebar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            cursorPressed = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                cursorX = 36
                cursorY = -16
            }
        }

        // 4. Grab Safari titlebar
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            cursorPressed = true
            withAnimation(.spring(response: 0.25)) {
                isDragging = true
            }
        }

        // 5. Drag Safari window across the desktop (mirrored live in minimap!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.75)) {
                movingWindowX = -20
                movingWindowY = 36
                cursorX = -20
                cursorY = 10
            }
        }

        // 6. Release & Snap into place with synced green ripple
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            cursorPressed = false
            isDragging = false
            withAnimation(.easeInOut(duration: 0.25)) {
                isSyncedFlash = true
            }
            // Move cursor away slightly to showcase aligned windows
            withAnimation(.spring(response: 0.45)) {
                cursorX = 25
                cursorY = 55
            }
        }

        // 7. Shimmer settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                isSyncedFlash = false
            }
        }
    }
}

// MARK: - Live Mac Tour Context Helpers

enum TourLiveContext {
    static var runningAppNames: [String] {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
        return apps.isEmpty ? ["Safari", "Xcode", "Finder", "Notes"] : apps
    }
}

// MARK: - Slide 2: External Display Auto-Restore Illustration

// Mini Realistic macOS Window Components for Slide 2
private struct MiniXcodeWindow: View {
    var width: CGFloat = 68
    var height: CGFloat = 54
    var isRestoredGlow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 2.5) {
                RealisticTrafficLights(size: 2.8)
                Spacer()
                HStack(spacing: 1.5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 3))
                        .foregroundStyle(.green)
                    Text("App")
                        .font(.system(size: 3.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 2.5)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 1.5))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2.5)
            .background(Color(red: 0.13, green: 0.14, blue: 0.17))

            // Body: Sidebar + Code Editor
            HStack(spacing: 0) {
                // Mini Navigator
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 1.5) {
                        Image(systemName: "folder.fill").font(.system(size: 3)).foregroundStyle(.blue)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.4)).frame(width: 8, height: 1.5)
                    }
                    HStack(spacing: 1.5) {
                        Image(systemName: "swift").font(.system(size: 3)).foregroundStyle(.orange)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.6)).frame(width: 10, height: 1.5)
                    }
                    Spacer()
                }
                .padding(2.5)
                .frame(width: 16)
                .background(Color(red: 0.11, green: 0.12, blue: 0.14))

                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5)

                // Code lines
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 0.5).fill(Color(red: 0.95, green: 0.35, blue: 0.65)).frame(width: 10, height: 1.8)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color(red: 0.38, green: 0.78, blue: 0.92)).frame(width: 14, height: 1.8)
                    }
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 0.5).fill(Color(red: 0.88, green: 0.55, blue: 0.28)).frame(width: 8, height: 1.8)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.75)).frame(width: 18, height: 1.8)
                    }
                    RoundedRectangle(cornerRadius: 0.5).fill(Color(red: 0.45, green: 0.75, blue: 0.98)).frame(width: 22, height: 1.8)
                    RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.5)).frame(width: 12, height: 1.8)
                    Spacer()
                }
                .padding(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.09, green: 0.10, blue: 0.12))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isRestoredGlow ? Color.green.opacity(0.9) : Color.white.opacity(0.2), lineWidth: isRestoredGlow ? 1.0 : 0.5)
        )
        .shadow(color: isRestoredGlow ? Color.green.opacity(0.4) : Color.black.opacity(0.4), radius: isRestoredGlow ? 6 : 3, y: 1.5)
    }
}

private struct MiniSafariWindow: View {
    var width: CGFloat = 68
    var height: CGFloat = 54
    var isRestoredGlow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Safari Header
            HStack(spacing: 2.5) {
                RealisticTrafficLights(size: 2.8)
                // URL bar
                HStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 2.5))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("design.apple.com")
                        .font(.system(size: 3.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2.5)
            .background(Color(white: 0.16))

            // Web Content Layout
            VStack(spacing: 2.5) {
                // Hero card
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.blue).frame(width: 14, height: 2)
                        RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(0.6)).frame(width: 26, height: 1.5)
                    }
                    Spacer()
                    Circle().fill(Color.purple.opacity(0.7)).frame(width: 8, height: 8)
                }
                .padding(2.5)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 2))

                // Dual mini cards
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.orange.opacity(0.65)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.green.opacity(0.65)).frame(height: 12)
                }
                Spacer()
            }
            .padding(3)
            .background(Color(white: 0.08))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isRestoredGlow ? Color.green.opacity(0.9) : Color.white.opacity(0.2), lineWidth: isRestoredGlow ? 1.0 : 0.5)
        )
        .shadow(color: isRestoredGlow ? Color.green.opacity(0.4) : Color.black.opacity(0.4), radius: isRestoredGlow ? 6 : 3, y: 1.5)
    }
}

// MARK: - MacBook Pro 14" M4 Space Black — Front Elevation Model

private struct RealisticMacBookMockup: View {
    let windowsAreRestored: Bool
    let windowNamespace: Namespace.ID
    /// 0 = closed flat, 1 = fully open front-facing (0°)
    let lidOpenFraction: CGFloat

    // ── Dimensions Matching Reference Image ──────────────────────────────────
    private let lidWidth: CGFloat = 118
    private let lidHeight: CGFloat = 78
    private let baseWidth: CGFloat = 136  // Extends ~9pt beyond lid on each side
    private let baseHeight: CGFloat = 7.5

    // ── Colors — Space Black anodized aluminum ────────────────────────────
    private let sbHighlight = Color(red: 0.32, green: 0.32, blue: 0.35)
    private let sbMid       = Color(red: 0.20, green: 0.20, blue: 0.22)
    private let sbDark      = Color(red: 0.11, green: 0.11, blue: 0.13)
    private let sbChassis   = Color(red: 0.15, green: 0.15, blue: 0.17)

    // The lid rotates from upright front-facing (0°) to folded flat (-85°)
    private var lidAngle: Double {
        let open: Double = 0.0
        let closed: Double = -85.0
        return closed + (open - closed) * Double(lidOpenFraction)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Base (Unibody Front Lip with Thumb Scoop & Rubber Feet) ────
            macBookBase
                .frame(width: baseWidth, height: baseHeight + 2)

            // ── Lid pivots right at the rear hinge seam ───────────────────
            macBookLid
                .frame(width: lidWidth, height: lidHeight)
                .rotation3DEffect(
                    .degrees(lidAngle),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    anchorZ: 0,
                    perspective: 0.30
                )
                .offset(y: -baseHeight + 1.0)
                .shadow(
                    color: .black.opacity(0.35 * Double(lidOpenFraction)),
                    radius: 6,
                    x: 0,
                    y: 4
                )
        }
        .frame(width: baseWidth, height: lidHeight + baseHeight + 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MacBook Pro")
    }

    // MARK: - Lid (Display & Clamshell Top)

    private var macBookLid: some View {
        ZStack {
            // Outer Space Black lid shell (fades in when closing / closed)
            lidOuterShell
                .opacity(Double(max(0, min(1, (0.35 - lidOpenFraction) / 0.18))))

            // Inner Display Assembly (active when open, dims as lid comes down)
            displayAssembly
                .opacity(Double(max(0, min(1, (lidOpenFraction - 0.20) / 0.30))))
        }
    }

    private var lidOuterShell: some View {
        ZStack {
            // Aluminum unibody back
            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                .fill(LinearGradient(
                    colors: [sbHighlight, sbMid, sbDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // Unibody chamfer highlight
            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.55
                )

            // Polished Apple logo on outer lid
            Image(systemName: "applelogo")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(white: 0.40), Color(white: 0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(180))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
        }
    }

    private var displayAssembly: some View {
        ZStack {
            // Edge-to-edge optical black glass (Liquid Retina XDR)
            UnevenRoundedRectangle(
                topLeadingRadius: 5.5,
                bottomLeadingRadius: 1.0,
                bottomTrailingRadius: 1.0,
                topTrailingRadius: 5.5,
                style: .continuous
            )
            .fill(Color(white: 0.015))

            // Razor-thin Space Black perimeter rim
            UnevenRoundedRectangle(
                topLeadingRadius: 5.5,
                bottomLeadingRadius: 1.0,
                bottomTrailingRadius: 1.0,
                topTrailingRadius: 5.5,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.55
            )

            // Active display panel inside ultra-thin uniform black border
            // Top: 2.0pt, Sides: 2.0pt, Bottom chin: 4.5pt (matches reference image)
            displayContents
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4.0,
                        bottomLeadingRadius: 0.5,
                        bottomTrailingRadius: 0.5,
                        topTrailingRadius: 4.0,
                        style: .continuous
                    )
                )
                .padding(EdgeInsets(top: 2.0, leading: 2.0, bottom: 4.5, trailing: 2.0))

            // Centered Display Notch (flush with top black border)
            displayNotch
        }
    }

    private var displayNotch: some View {
        VStack {
            ZStack {
                // Notch housing
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 1.8,
                    bottomTrailingRadius: 1.8,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                .frame(width: 13.5, height: 3.6)

                // FaceTime camera lens
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.16, green: 0.24, blue: 0.38), Color(white: 0.08)],
                            center: .center,
                            startRadius: 0.2,
                            endRadius: 0.7
                        )
                    )
                    .frame(width: 1.0, height: 1.0)
            }
            Spacer()
        }
        .padding(.top, 2.0)
    }

    private var displayContents: some View {
        ZStack(alignment: .top) {
            // macOS Sequoia / Sonoma wallpaper gradient
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.14, blue: 0.32),
                    Color(red: 0.05, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // macOS Menu Bar
            HStack(spacing: 2.6) {
                Image(systemName: "applelogo")
                    .font(.system(size: 2.8))
                Text("Finder").fontWeight(.semibold)
                Text("File").foregroundStyle(.white.opacity(0.65))
                Text("Edit").foregroundStyle(.white.opacity(0.65))
                Spacer()
                Image(systemName: "wifi").font(.system(size: 2.6))
                Image(systemName: "battery.75").font(.system(size: 2.6))
                Text("9:41").font(.system(size: 2.8, weight: .medium, design: .rounded))
            }
            .font(.system(size: 2.8, weight: .regular))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 3.2)
            .padding(.vertical, 1.6)
            .background(Color.black.opacity(0.35))

            // Open application windows on laptop screen
            if !windowsAreRestored {
                ZStack {
                    MiniXcodeWindow(width: 44, height: 33)
                        .offset(x: -11, y: 5)
                        .matchedGeometryEffect(id: "restored-xcode-window", in: windowNamespace)
                        .zIndex(1)

                    MiniSafariWindow(width: 45, height: 34)
                        .offset(x: 11, y: 10)
                        .matchedGeometryEffect(id: "restored-safari-window", in: windowNamespace)
                        .zIndex(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 2.5)
            }

            // Glass screen reflection overlay
            LinearGradient(
                colors: [Color.white.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .allowsHitTesting(false)
        }
    }

    // MARK: - Base (Unibody Front Lip from Reference Image)

    private var macBookBase: some View {
        ZStack(alignment: .bottom) {
            // Contact shadow under laptop
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: baseWidth - 8, height: 1.8)
                .blur(radius: 1.0)
                .offset(y: 1.0)

            // Rubber feet peeking underneath
            HStack {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 6, height: 1.5)
                Spacer()
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 6, height: 1.5)
            }
            .padding(.horizontal, 14)
            .offset(y: 0.5)

            // Main Unibody Front Lip
            ZStack(alignment: .top) {
                // Aluminum unibody bar
                RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                    .fill(LinearGradient(
                        colors: [sbHighlight, sbMid, sbDark],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: baseWidth, height: baseHeight)

                // Top chamfer highlight line
                RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                    .frame(width: baseWidth, height: baseHeight)

                // Centered Thumb Scoop (Opening Notch)
                thumbScoop
            }

            // Thunderbolt port indicator on the right edge
            thunderboltPortSlot
        }
    }

    private var thumbScoop: some View {
        ZStack {
            // Darker recessed cavity
            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .fill(Color(white: 0.08))
                .frame(width: 22, height: 2.0)

            // Curved metallic bottom edge highlight
            Capsule()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 18, height: 0.6)
                .offset(y: 0.7)
        }
        .frame(width: baseWidth, alignment: .center)
    }

    private var thunderboltPortSlot: some View {
        // Right flank USB-C / Thunderbolt port slot
        RoundedRectangle(cornerRadius: 0.5, style: .continuous)
            .fill(Color(white: 0.06))
            .frame(width: 1.2, height: 2.6)
            .overlay(
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.25)
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 1.2)
            .padding(.bottom, 2.5)
    }
}



private struct RealisticStudioDisplayMockup: View {
    let isAwake: Bool
    let windowsAreRestored: Bool
    let isRestoredGlow: Bool
    let windowNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            // Main Display Enclosure
            ZStack(alignment: .top) {
                // Precision Aluminum Unibody Shell
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(white: 0.26), Color(white: 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .stroke(
                                isAwake ? Color.white.opacity(0.32) : Color.white.opacity(0.16),
                                lineWidth: 0.75
                            )
                    )

                // Screen Panel
                ZStack(alignment: .top) {
                    ZStack(alignment: .top) {
                        Color(white: 0.045)

                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.14, blue: 0.38),
                                Color(red: 0.10, green: 0.13, blue: 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(isAwake ? 1 : 0)

                        if !isAwake {
                            ZStack {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.04), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                Circle()
                                    .fill(Color.white.opacity(0.35))
                                    .frame(width: 2.5, height: 2.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                    .padding(6)
                            }
                            .transition(.opacity)
                        }

                        if isAwake {
                            HStack(spacing: 3) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 3.5))
                                Text("Finder").fontWeight(.semibold)
                                Text("File").foregroundStyle(.white.opacity(0.68))
                                Text("Edit").foregroundStyle(.white.opacity(0.68))
                                Spacer(minLength: 3)
                                Image(systemName: "wifi")
                                Image(systemName: "battery.75")
                                Text("9:41").font(.system(size: 3.5, weight: .medium, design: .rounded))
                            }
                            .font(.system(size: 3.5, weight: .regular))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.35))
                            .transition(.opacity)

                            if windowsAreRestored {
                                HStack(spacing: 6) {
                                    MiniXcodeWindow(width: 68, height: 56, isRestoredGlow: isRestoredGlow)
                                        .matchedGeometryEffect(id: "restored-xcode-window", in: windowNamespace)
                                        .zIndex(1)

                                    MiniSafariWindow(width: 68, height: 56, isRestoredGlow: isRestoredGlow)
                                        .matchedGeometryEffect(id: "restored-safari-window", in: windowNamespace)
                                        .zIndex(1)
                                }
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .padding(2.5)
            }
            .frame(width: 168, height: 104)
            .shadow(
                color: isAwake ? Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.28) : Color.black.opacity(0.3),
                radius: isAwake ? 9 : 6,
                y: 4
            )

            // Aluminum Stand Neck with Cable Pass-Through Hole
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.42), Color(white: 0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 16, height: 18)

                // Circular cable pass-through hole
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .offset(y: 1)
            }

            // Weighted Aluminum Foot Plate
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [Color(white: 0.40), Color(white: 0.26)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 52, height: 3.5)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, y: 2)
        }
    }
}

private struct RealisticThunderboltCable: View {
    let isConnected: Bool
    let isPulseActive: Bool
    let pulseProgress: CGFloat

    private var plugOffset: CGFloat { isConnected ? 0 : 9 }
    private var cableSag: CGFloat { isConnected ? 4.2 : 8 }
    private var cableShape: ThunderboltCableShape {
        ThunderboltCableShape(sag: cableSag, plugOffset: plugOffset)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                cableShape
                    .stroke(Color.black.opacity(0.76), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))

                cableShape
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.48), Color(white: 0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )

                if isPulseActive {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 3.8, height: 3.8)
                        .shadow(color: Color.yellow.opacity(0.85), radius: 3)
                        .position(pulsePoint(in: geometry.size))
                }

                connector
                    .position(x: 6.65 + plugOffset, y: geometry.size.height * 0.57)
            }
        }
        .frame(width: 52, height: 28)
        .accessibilityHidden(true)
    }

    private var connector: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 0.55, style: .continuous)
                .fill(Color(white: 0.72))
                .frame(width: 2.6, height: 3.5)

            RoundedRectangle(cornerRadius: 1.3, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.48), Color(white: 0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: 1.3, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.45)
                }
                .frame(width: 8.8, height: 5.1)

            RoundedRectangle(cornerRadius: 0.85, style: .continuous)
                .fill(Color(white: 0.22))
                .frame(width: 2.1, height: 3.6)
        }
    }

    private func pulsePoint(in size: CGSize) -> CGPoint {
        let progress = min(max(pulseProgress, 0), 1)
        let start = CGPoint(x: 13.5, y: size.height * 0.57)
        let end = CGPoint(x: size.width, y: size.height * 0.72)
        let control = CGPoint(x: size.width * 0.6, y: min(size.height - 1, start.y + cableSag))
        let inverse = 1 - progress

        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * progress * control.x + progress * progress * end.x,
            y: inverse * inverse * start.y + 2 * inverse * progress * control.y + progress * progress * end.y
        )
    }
}

private struct ThunderboltCableShape: Shape {
    var sag: CGFloat
    var plugOffset: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sag, plugOffset) }
        set {
            sag = newValue.first
            plugOffset = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: 13.5 + plugOffset, y: rect.height * 0.57)
        let end = CGPoint(x: rect.width, y: rect.height * 0.72)
        let control = CGPoint(x: rect.width * 0.6, y: min(rect.height - 1, start.y + sag))
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

private enum RestoreAnimationPhase: Equatable {
    case lidClosed          // MacBook lid fully shut
    case lidOpening         // lid is animating open
    case disconnected       // lid open, cable not connected
    case connecting
    case displayWaking
    case restoringWindows
    case restored
    case settled
    case returningWindows
    case displaySleeping
    case lidClosing         // lid animating back shut

    var cableIsConnected: Bool {
        switch self {
        case .disconnected, .lidClosed, .lidOpening, .lidClosing:
            return false
        default:
            return true
        }
    }

    var displayIsAwake: Bool {
        switch self {
        case .displayWaking, .restoringWindows, .restored, .settled, .returningWindows:
            return true
        default:
            return false
        }
    }

    var windowsAreRestored: Bool {
        switch self {
        case .restoringWindows, .restored, .settled:
            return true
        default:
            return false
        }
    }

    var showsRestoreGlow: Bool { self == .restored }

    /// 0 = fully closed, 1 = fully open
    var lidOpenFraction: CGFloat {
        switch self {
        case .lidClosed:    return 0
        case .lidOpening:   return 1   // animated via withAnimation
        case .lidClosing:   return 0   // animated via withAnimation
        default:            return 1
        }
    }
}

struct OBIllustrationRestore: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @Namespace private var windowNamespace
    @State private var phase: RestoreAnimationPhase = .lidClosed
    @State private var lidOpenFraction: CGFloat = 0
    @State private var pulseIsActive = false
    @State private var pulseProgress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            TourDesktopBackground()

            HStack(alignment: .bottom, spacing: 0) {
                RealisticMacBookMockup(
                    windowsAreRestored: phase.windowsAreRestored,
                    windowNamespace: windowNamespace,
                    lidOpenFraction: lidOpenFraction
                )

                RealisticThunderboltCable(
                    isConnected: phase.cableIsConnected,
                    isPulseActive: pulseIsActive,
                    pulseProgress: pulseProgress
                )

                RealisticStudioDisplayMockup(
                    isAwake: phase.displayIsAwake,
                    windowsAreRestored: phase.windowsAreRestored,
                    isRestoredGlow: phase.showsRestoreGlow,
                    windowNamespace: windowNamespace
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: replayAnimation)
        .onAppear(perform: startAnimationLoop)
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plug In, Pick Up Where You Left Off".localized(appLanguage))
        .accessibilityHint("Replay Tour".localized(appLanguage))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Replay Tour".localized(appLanguage))) {
            replayAnimation()
        }
    }

    @MainActor
    private func startAnimationLoop() {
        animationTask?.cancel()
        phase = .lidClosed
        lidOpenFraction = 0
        pulseIsActive = false
        pulseProgress = 0

        animationTask = Task { @MainActor in
            guard await wait(for: 0.5) else { return }

            while !Task.isCancelled {
                await lidOpenSequence()
                guard !Task.isCancelled else { return }

                await connectSequence()
                guard !Task.isCancelled else { return }
                guard await wait(for: 2.4) else { return }

                await disconnectSequence()
                guard !Task.isCancelled else { return }

                await lidCloseSequence()
                guard !Task.isCancelled else { return }
                guard await wait(for: 1.0) else { return }
            }
        }
    }

    @MainActor
    private func replayAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            // Close lid first if open
            if lidOpenFraction > 0 {
                await disconnectSequence()
                await lidCloseSequence()
                guard !Task.isCancelled else { return }
                guard await wait(for: 0.35) else { return }
            }

            await lidOpenSequence()
            guard !Task.isCancelled else { return }

            await connectSequence()
            guard !Task.isCancelled else { return }
            guard await wait(for: 2.4) else { return }

            await disconnectSequence()
            guard !Task.isCancelled else { return }

            await lidCloseSequence()
            guard !Task.isCancelled else { return }
            startAnimationLoop()
        }
    }

    // MARK: Lid open — controlled hinge motion without bouncing past the stop
    @MainActor
    private func lidOpenSequence() async {
        phase = .lidOpening
        withAnimation(.easeInOut(duration: 0.78)) {
            lidOpenFraction = 1
        }
        guard await wait(for: 0.86) else { return }
        phase = .disconnected
    }

    // MARK: Lid close
    @MainActor
    private func lidCloseSequence() async {
        phase = .lidClosing
        withAnimation(.easeInOut(duration: 0.68)) {
            lidOpenFraction = 0
        }
        guard await wait(for: 0.74) else { return }
        phase = .lidClosed
    }

    @MainActor
    private func connectSequence() async {
        withAnimation(.spring(response: 0.46, dampingFraction: 0.8)) {
            phase = .connecting
        }

        guard await wait(for: 0.22) else { return }
        pulseProgress = 0
        pulseIsActive = true
        withAnimation(.easeInOut(duration: 0.72)) {
            pulseProgress = 1
        }

        guard await wait(for: 0.72) else { return }
        withAnimation(.easeOut(duration: 0.56)) {
            pulseIsActive = false
            phase = .displayWaking
        }

        guard await wait(for: 0.4) else { return }
        withAnimation(.spring(response: 0.74, dampingFraction: 0.84)) {
            phase = .restoringWindows
        }

        guard await wait(for: 0.76) else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            phase = .restored
        }

        guard await wait(for: 0.45) else { return }
        withAnimation(.easeOut(duration: 0.32)) {
            phase = .settled
        }
    }

    @MainActor
    private func disconnectSequence() async {
        withAnimation(.spring(response: 0.72, dampingFraction: 0.86)) {
            phase = .returningWindows
        }

        guard await wait(for: 0.72) else { return }
        withAnimation(.easeInOut(duration: 0.58)) {
            phase = .displaySleeping
        }

        guard await wait(for: 0.58) else { return }
        withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
            phase = .disconnected
            pulseIsActive = false
        }
    }

    private func wait(for seconds: Double) async -> Bool {
        do {
            let milliseconds = Int64(seconds * 1_000)
            try await Task.sleep(for: .milliseconds(milliseconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

// MARK: - Slide 3: Menu Bar Two Powers Illustration

struct OBIllustrationMenuBar: View {
    @State private var phase: Int = 0
    @State private var cursorX: CGFloat = -60
    @State private var cursorY: CGFloat = 20
    @State private var buttonFlash: Bool = false
    @State private var showLeftCallout: Bool = false
    @State private var showRightCallout: Bool = false
    @State private var ticker: Timer?
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        ZStack(alignment: .top) {
            // Mock menu bar strip
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                )
                .frame(width: 356, height: 26)
                .overlay(alignment: .trailing) {
                    HStack(spacing: 8) {
                        Text("9:41")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Image(systemName: "wifi")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                        Image(systemName: "battery.75")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.trailing, 10)
                }
                .overlay(alignment: .leading) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.leading, 12)
                }
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(buttonFlash
                                  ? Color.accentColor.opacity(0.75)
                                  : Color.white.opacity(0.10))
                            .frame(width: 26, height: 20)
                            .animation(.easeOut(duration: 0.12), value: buttonFlash)

                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(buttonFlash ? .white : .white.opacity(0.80))
                            .animation(.easeOut(duration: 0.12), value: buttonFlash)
                    }
                }
                .offset(y: -54)

            // Left-click callout
            if showLeftCallout {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "cursorarrow.click")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("Left Click".localized(appLanguage))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Text("Restores this app\n& opens the list".localized(appLanguage))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: Color.accentColor.opacity(0.18), radius: 8, x: 0, y: 3)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .offset(y: -26)
            }

            // Right-click callout
            if showRightCallout {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "computermouse.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("Right Click".localized(appLanguage))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Text("Restores all apps\nat once".localized(appLanguage))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: Color.orange.opacity(0.18), radius: 8, x: 0, y: 3)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .offset(y: -26)
            }

            // Animated cursor
            Image(systemName: "cursorarrow")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 1)
                .offset(x: cursorX, y: cursorY)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: cursorX)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: cursorY)

            // Mini mouse diagram
            mouseDiagram
                .offset(y: 65)
        }
        .frame(width: 356, height: 180)
        .onAppear { startAnimation() }
        .onDisappear { ticker?.invalidate() }
    }

    private var mouseDiagram: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 30, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.primary.opacity(0.22), lineWidth: 0.75)
                }

            UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(Color.accentColor.opacity(showLeftCallout ? 0.65 : 0))
                .frame(width: 14, height: 22)
                .offset(x: -8, y: -11)
                .animation(.easeInOut(duration: 0.18), value: showLeftCallout)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 9)
                .fill(Color.orange.opacity(showRightCallout ? 0.65 : 0))
                .frame(width: 14, height: 22)
                .offset(x: 8, y: -11)
                .animation(.easeInOut(duration: 0.18), value: showRightCallout)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 30, height: 0.5)
                .offset(y: -2)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 0.5, height: 20)
                .offset(y: -12)

            Capsule()
                .fill(Color.primary.opacity(0.28))
                .frame(width: 4, height: 10)
                .offset(y: -7)
        }
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { runCycle() }

        ticker = Timer.scheduledTimer(withTimeInterval: 3.8, repeats: true) { _ in
            runCycle()
        }
    }

    private func runCycle() {
        let showLeft = (phase % 2 == 0)
        phase += 1

        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            cursorX = showLeft ? -4 : 4
            cursorY = -44
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { buttonFlash = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                buttonFlash = false
                if showLeft { showLeftCallout = true } else { showRightCallout = true }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showLeftCallout = false
                showRightCallout = false
                cursorX = showLeft ? -60 : 60
                cursorY = 20
            }
        }
    }
}

// MARK: - Slide 4: Desktop Toggle Illustration (Editable Shortcut Hide & Restore)

struct OBIllustrationDesktopToggle: View {
    @State private var showWindows = true
    @State private var timer: Timer?
    @State private var isMounted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            MacDesktopPlainSurface(isCollapsed: !showWindows)

            // A quiet, authentic menu bar anchors the desktop and makes the scene
            // immediately read as macOS instead of a generic dark canvas.
            MacDesktopMenuBar(showsSystemStatus: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)


            // Desktop files sit in the trailing column, as they do on a real Mac.
            VStack(alignment: .center, spacing: 6) {
                MacDesktopFileIcon(
                    title: "Client Project",
                    kind: .presentation
                )
                MacDesktopFileIcon(
                    title: "Pitch Deck",
                    kind: .pdf
                )
                MacDesktopFileIcon(
                    title: "Screenshots",
                    kind: .screenshotsFolder
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 30)
            .padding(.trailing, 9)

            // Real windows remain square to the desktop and use a clear front-to-back
            // stack, which is how macOS communicates focus and depth.
            ZStack {
                RealisticSafariWindow(
                    width: 162,
                    height: 84,
                    urlText: "apple.com",
                    tabTitle: "Apple"
                )
                .offset(x: -42, y: -24)

                RealisticXcodeWindow(width: 150, height: 74, fileName: "App.swift")
                    .offset(x: 24, y: 30)
            }
            .scaleEffect(showWindows ? 1.0 : 0.96)
            .offset(y: showWindows ? 0 : 9)
            .opacity(showWindows ? 1.0 : 0.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.34), value: showWindows)

            MacDesktopDock()
                .scaleEffect(0.78, anchor: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 7)

            // Shortcut badge removed — the animation alone is sufficient.
        }
        .frame(width: 356, height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Desktop toggle demonstration")
        .onAppear {
            isMounted = true
            startLoop()
        }
        .onDisappear {
            isMounted = false
            timer?.invalidate()
            timer = nil
        }
    }

    private func startLoop() {
        runCycle()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            runCycle()
        }
    }

    private func runCycle() {
        guard isMounted else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard isMounted else { return }
            triggerToggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard isMounted else { return }
            triggerToggle()
        }
    }

    private func triggerToggle() {
        guard isMounted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard isMounted else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.74)) {
                showWindows.toggle()
            }
        }
    }
}

private struct CmdShiftRBrowserWindow: View {
    let activeScene: Int
    let phase: Int
    let reloadSpin: Double
    let sceneColor: Color

    var body: some View {
        VStack(spacing: 0) {
            browserToolbar
            browserTabBar

            Rectangle()
                .fill(sceneColor.opacity(phase == 2 ? 0.95 : 0.45))
                .frame(height: 1.5)
                .scaleEffect(x: phase == 0 ? 0.28 : (phase == 1 ? 0.68 : 1.0), y: 1, anchor: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.45), value: phase)

            ZStack {
                switch activeScene {
                case 0:
                    readerBody
                case 1:
                    reloadBody
                default:
                    videoBody
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(activeScene)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.28), value: activeScene)
        }
        .frame(width: 300, height: 140)
        .background(Color(red: 0.09, green: 0.10, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    phase == 2 ? sceneColor.opacity(0.72) : Color.white.opacity(0.16),
                    lineWidth: phase == 2 ? 1.1 : 0.7
                )
        }
        .shadow(color: .black.opacity(0.42), radius: 13, x: 0, y: 7)
        .shadow(color: phase == 2 ? sceneColor.opacity(0.26) : .clear, radius: 12, x: 0, y: 0)
    }

    private var browserToolbar: some View {
        HStack(spacing: 5) {
            RealisticTrafficLights(size: 5)

            Image(systemName: "chevron.left")
                .font(.system(size: 6, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
            Image(systemName: "chevron.right")
                .font(.system(size: 6, weight: .semibold))
                .foregroundStyle(.white.opacity(0.22))

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 5.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))

                Text(activeScene == 1 ? "dashboard.example.com" : "apple.com/news")
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundStyle(activeScene == 1 && phase > 0 ? sceneColor : .white.opacity(0.48))
                    .rotationEffect(.degrees(activeScene == 1 ? reloadSpin : 0))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.55)
            }

            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 6.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Image(systemName: "plus")
                .font(.system(size: 6.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(red: 0.15, green: 0.16, blue: 0.19))
    }

    private var browserTabBar: some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 5.5))
                    .foregroundStyle(.blue)

                Text(activeScene == 2 ? "Weekend video" : (activeScene == 1 ? "Project dashboard" : "Apple News"))
                    .font(.system(size: 6, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .font(.system(size: 4.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

            Spacer(minLength: 0)

            Image(systemName: "plus")
                .font(.system(size: 6, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
    }

    private var readerBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("APPLE NEWS")
                .font(.system(size: 6, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.blue)

            Text(phase == 2 ? "The future of focused work" : "Preparing Reader Mode…")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.14))
                .lineLimit(2)

            if phase == 2 {
                Text("A calmer way to keep every window exactly where you need it.")
                    .font(.system(size: 6.5, weight: .regular, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .lineLimit(2)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 126, height: 3)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                Text(phase == 2 ? "Reader Mode" : "Apple News")
                    .font(.system(size: 5.5, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.52))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
    }

    private var reloadBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow.opacity(0.80)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: phase == 2 ? "bolt.fill" : "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(phase == 2 ? 0 : reloadSpin))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Project dashboard")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                    Text(phase == 2 ? "Hard reload complete" : "Refreshing the latest data…")
                        .font(.system(size: 6))
                        .foregroundStyle(.white.opacity(0.54))
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                dashboardMetric(title: "WINDOWS", value: "3")
                dashboardMetric(title: "RESTORED", value: phase == 2 ? "100%" : "—")
                dashboardMetric(title: "SYNC", value: phase == 2 ? "LIVE" : "…")
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(phase == 2 ? 0.36 : 0.16))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange.opacity(0.90))
                        .frame(width: phase == 2 ? 206 : 92, height: 3)
                }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.10, green: 0.12, blue: 0.16))
    }

    private func dashboardMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 4.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.40))
            Text(value)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var videoBody: some View {
        ZStack {
            alpineVideoArtwork

            LinearGradient(
                colors: [.black.opacity(0.14), .clear, .black.opacity(0.36)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("FIELD NOTES")
                    .font(.system(size: 5.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.62))
                Text("A weekend in the Alps")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: phase == 2 ? "pip.fill" : "play.fill")
                        .font(.system(size: 7, weight: .bold))
                    Text(phase == 2 ? "Picture-in-Picture" : "Ready to play")
                        .font(.system(size: 5.5, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.74))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            pictureInPictureWindow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 9)
                .padding(.bottom, 7)
                .scaleEffect(phase == 2 ? 1.0 : 0.72, anchor: .bottomTrailing)
                .opacity(phase == 2 ? 1.0 : 0.0)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: phase)
        }
    }

    private var pictureInPictureWindow: some View {
        ZStack {
            alpineVideoArtwork

            LinearGradient(
                colors: [.black.opacity(0.08), .clear, .black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )

            Image(systemName: phase == 2 ? "pause.fill" : "play.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.black.opacity(0.42), in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.34), lineWidth: 0.6)
                }

            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Text("FIELD NOTES")
                        .font(.system(size: 4.5, weight: .bold, design: .rounded))
                        .tracking(0.45)
                        .foregroundStyle(.white.opacity(0.96))

                    Spacer(minLength: 0)

                    Image(systemName: "pip.exit")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(.black.opacity(0.38), in: Circle())
                }

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    Text("1:24")
                        .font(.system(size: 4.7, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.94))

                    GeometryReader { geometry in
                        Capsule()
                            .fill(.white.opacity(0.40))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(.white)
                                    .frame(width: geometry.size.width * 0.38)
                            }
                    }
                    .frame(height: 2)

                    Text("4:32")
                        .font(.system(size: 4.7, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.78))

                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
        }
        .frame(width: 128, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.44), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.48), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Picture-in-Picture video preview: A weekend in the Alps")
        .accessibilityHidden(phase != 2)
    }

    private var alpineVideoArtwork: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.34, green: 0.61, blue: 0.77),
                        Color(red: 0.82, green: 0.76, blue: 0.68)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color(red: 1.0, green: 0.88, blue: 0.67).opacity(0.86))
                    .frame(width: height * 0.34, height: height * 0.34)
                    .position(x: width * 0.76, y: height * 0.26)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.73))
                    path.addLine(to: CGPoint(x: width * 0.18, y: height * 0.43))
                    path.addLine(to: CGPoint(x: width * 0.31, y: height * 0.59))
                    path.addLine(to: CGPoint(x: width * 0.49, y: height * 0.18))
                    path.addLine(to: CGPoint(x: width * 0.67, y: height * 0.58))
                    path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.38))
                    path.addLine(to: CGPoint(x: width, y: height * 0.65))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.38, green: 0.52, blue: 0.62))

                Path { path in
                    path.move(to: CGPoint(x: width * 0.49, y: height * 0.18))
                    path.addLine(to: CGPoint(x: width * 0.42, y: height * 0.34))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.31))
                    path.addLine(to: CGPoint(x: width * 0.52, y: height * 0.38))
                    path.addLine(to: CGPoint(x: width * 0.55, y: height * 0.32))
                    path.closeSubpath()

                    path.move(to: CGPoint(x: width * 0.82, y: height * 0.38))
                    path.addLine(to: CGPoint(x: width * 0.77, y: height * 0.48))
                    path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.45))
                    path.addLine(to: CGPoint(x: width * 0.87, y: height * 0.50))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.88))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.88))
                    path.addLine(to: CGPoint(x: width * 0.23, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width * 0.40, y: height * 0.75))
                    path.addLine(to: CGPoint(x: width * 0.61, y: height * 0.45))
                    path.addLine(to: CGPoint(x: width * 0.80, y: height * 0.69))
                    path.addLine(to: CGPoint(x: width, y: height * 0.55))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color(red: 0.27, green: 0.45, blue: 0.47), Color(red: 0.16, green: 0.34, blue: 0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.88))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.79),
                        control1: CGPoint(x: width * 0.30, y: height * 0.74),
                        control2: CGPoint(x: width * 0.69, y: height * 0.93)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color(red: 0.12, green: 0.30, blue: 0.29), Color(red: 0.06, green: 0.21, blue: 0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

                ForEach(0..<5, id: \.self) { index in
                    let treePositions: [CGFloat] = [0.04, 0.13, 0.24, 0.87, 0.96]
                    let treeHeight = height * (index == 2 ? 0.38 : 0.31)

                    AlpineTreeSilhouette()
                        .fill(Color(red: 0.05, green: 0.18, blue: 0.19).opacity(0.92))
                        .frame(width: treeHeight * 0.48, height: treeHeight)
                        .position(x: width * treePositions[index], y: height * 0.88)
                }
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

private struct AlpineTreeSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let top = rect.minY
        let height = rect.height
        let halfWidth = rect.width * 0.5

        return Path { path in
            path.move(to: CGPoint(x: centerX, y: top))
            path.addLine(to: CGPoint(x: centerX - rect.width * 0.28, y: top + height * 0.38))
            path.addLine(to: CGPoint(x: centerX - rect.width * 0.13, y: top + height * 0.38))
            path.addLine(to: CGPoint(x: centerX - halfWidth, y: top + height * 0.72))
            path.addLine(to: CGPoint(x: centerX - rect.width * 0.21, y: top + height * 0.70))
            path.addLine(to: CGPoint(x: rect.minX, y: top + height * 0.98))
            path.addLine(to: CGPoint(x: rect.maxX, y: top + height * 0.98))
            path.addLine(to: CGPoint(x: centerX + rect.width * 0.21, y: top + height * 0.70))
            path.addLine(to: CGPoint(x: centerX + halfWidth, y: top + height * 0.72))
            path.addLine(to: CGPoint(x: centerX + rect.width * 0.13, y: top + height * 0.38))
            path.addLine(to: CGPoint(x: centerX + rect.width * 0.28, y: top + height * 0.38))
            path.closeSubpath()
        }
    }
}

// MARK: - Slide 5: ⌘⇧R Post-Restore Action — Automatic Hands-Free Showcase

struct OBIllustrationCmdShiftR: View {
    @State private var phase: Int = 0
    @State private var activeScene: Int = 0
    @State private var reloadSpin: Double = 0
    @State private var timer: Timer?
    @State private var isMounted = false
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private let scenes: [(id: Int, title: String, icon: String, color: Color)] = [
        (0, "Reader Mode", "book.pages.fill", .blue),
        (1, "Hard Reload", "arrow.clockwise", .orange),
        (2, "Picture-in-Picture", "pip.fill", .purple)
    ]

    private var sceneColor: Color { scenes[activeScene].color }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 5) {
                CmdShiftRBrowserWindow(
                    activeScene: activeScene,
                    phase: phase,
                    reloadSpin: reloadSpin,
                    sceneColor: sceneColor
                )

                // Interactive scene tabs
                HStack(spacing: 7) {
                    ForEach(scenes, id: \.id) { sc in
                        Button {
                            withAnimation(.spring(response: 0.35)) { activeScene = sc.id }
                            runAutoSequence()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: sc.icon)
                                    .font(.system(size: 7.5, weight: .bold))
                                Text(sc.title.localized(appLanguage))
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(activeScene == sc.id ? sc.color : Color.white.opacity(0.1), in: Capsule())
                            .foregroundStyle(activeScene == sc.id ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(sc.title.localized(appLanguage)))
                    }
                }
            }
            .padding(.bottom, 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { if isMounted { runAutoSequence() } }
        .onAppear { isMounted = true; startLoop() }
        .onDisappear {
            isMounted = false
            timer?.invalidate()
            timer = nil
        }
    }

    private func startLoop() {
        runAutoSequence()
        timer = Timer.scheduledTimer(withTimeInterval: 5.5, repeats: true) { _ in
            activeScene = (activeScene + 1) % 3
            runAutoSequence()
        }
    }

    private func runAutoSequence() {
        guard isMounted else { return }
        withAnimation(.easeInOut(duration: 0.2)) { phase = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard isMounted else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { phase = 0 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard isMounted else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                phase = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard isMounted else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                phase = 2
                if activeScene == 1 { reloadSpin += 360 }
            }
        }
    }
}

// MARK: - Slide 6: Quick Key Restore (Fn Long-Press & Caps Lock Double-Tap)

struct OBIllustrationQuickKey: View {
    @State private var currentFrame: Int = 0
    @State private var timer: Timer?
    @State private var isMounted = false

    // Load bundled or local frame images (1 to 6)
    private static let frameImages: [NSImage?] = {
        (1...6).map { index in
            let name = "QuickKeyFrame\(index)"
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                return img
            }
            if let img = NSImage(contentsOfFile: "WindowLayout/\(name).png") {
                return img
            }
            return NSImage(contentsOfFile: "/Applications/RememberMyWindows/WindowLayout/\(name).png")
        }
    }()

    @State private var isDoubleTapPhase = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                if let nsImage = Self.frameImages[index] {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(currentFrame == index ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: isDoubleTapPhase ? 0.06 : 0.20), value: currentFrame)
                }
            }
        }
        .frame(width: 380, height: 236)
        .contentShape(Rectangle())
        .onTapGesture {
            replayAnimation()
        }
        .onAppear {
            isMounted = true
            startAnimationLoop()
        }
        .onDisappear {
            isMounted = false
            stopAnimationLoop()
        }
    }

    private func startAnimationLoop() {
        stopAnimationLoop()
        scheduleCycle()
    }

    private func stopAnimationLoop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleCycle() {
        guard isMounted else { return }

        runFullAlternatingSequence()

        timer?.invalidate()
        // Total alternating sequence takes 8.2s
        timer = Timer.scheduledTimer(withTimeInterval: 8.2, repeats: true) { [self] _ in
            guard isMounted else { return }
            runFullAlternatingSequence()
        }
    }

    private func runFullAlternatingSequence() {
        guard isMounted else { return }

        isDoubleTapPhase = false

        // --- Sequence A: Fn Hold Restore ---
        withAnimation(.easeInOut(duration: 0.20)) {
            currentFrame = 0 // QuickKeyFrame1 (Idle)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [self] in
            guard isMounted else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                currentFrame = 1 // QuickKeyFrame2 (Fn Hold)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { [self] in
            guard isMounted else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                currentFrame = 2 // QuickKeyFrame3 (Restored)
            }
        }

        // --- Sequence B: Caps Lock Double-Tap Restore ---
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { [self] in
            guard isMounted else { return }
            isDoubleTapPhase = false
            withAnimation(.easeInOut(duration: 0.20)) {
                currentFrame = 0 // QuickKeyFrame1 (Idle)
            }
        }

        // Tap 1: Caps Lock illuminated
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.9) { [self] in
            guard isMounted else { return }
            isDoubleTapPhase = true
            withAnimation(.easeInOut(duration: 0.06)) {
                currentFrame = 3 // QuickKeyFrame4 (Caps Lock Tap 1)
            }
        }

        // Tactile Separator: Key released back to Idle for 0.35s
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.15) { [self] in
            guard isMounted else { return }
            withAnimation(.easeInOut(duration: 0.06)) {
                currentFrame = 0 // QuickKeyFrame1 (Separator between Tap 1 & Tap 2)
            }
        }

        // Tap 2: Caps Lock double-tap pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.50) { [self] in
            guard isMounted else { return }
            withAnimation(.easeInOut(duration: 0.06)) {
                currentFrame = 4 // QuickKeyFrame5 (Caps Lock Tap 2 Pulse)
            }
        }

        // Windows Restored
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.85) { [self] in
            guard isMounted else { return }
            isDoubleTapPhase = false
            withAnimation(.easeInOut(duration: 0.24)) {
                currentFrame = 5 // QuickKeyFrame6 (Restored)
            }
        }
    }

    private func replayAnimation() {
        guard isMounted else { return }
        stopAnimationLoop()
        runFullAlternatingSequence()
        timer = Timer.scheduledTimer(withTimeInterval: 8.2, repeats: true) { [self] _ in
            guard isMounted else { return }
            runFullAlternatingSequence()
        }
    }
}

// MARK: - Slide 7: Settings Guide Illustration (Authentic macOS Settings Panel)

struct OBIllustrationSettingsGuide: View {
    var activeIndex: Int = 0
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @Environment(\.colorScheme) private var colorScheme

    private var notchPreviewData: NotificationData {
        let snapshotName = "\u{2068}\("Home".localized(appLanguage))\u{2069}"
        let restoredCount = "\u{2066}5\u{2069}"
        let totalCount = "\u{2066}5\u{2069}"
        let subtitle = String(
            format: "Preview · %@ · %@/%@ windows".localized(appLanguage),
            snapshotName,
            restoredCount,
            totalCount
        )

        return NotificationData(
            title: "Layout Restored".localized(appLanguage),
            subtitle: subtitle
        )
    }

    var body: some View {
        ZStack {
            TourDesktopBackground()

            // Reuse the production view so the guide shows the real notch-attached
            // shape, theme accent, indicator, and entrance animation.
            if activeIndex == 2 {
                NotchNotificationView(
                    data: notchPreviewData,
                    notchDepth: 10,
                    pillWidth: 280,
                    pillHeight: 48,
                    isCompact: false,
                    onDismiss: {}
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityHidden(true)
                .zIndex(1)
            }

            VStack(spacing: 4) {
                settingRow(icon: "bolt.fill", color: .orange, title: "Auto-Restore".localized(appLanguage), subtitle: "Triggers on display connect or app launch".localized(appLanguage), isActive: activeIndex == 0)
                settingRow(icon: "keyboard", color: .purple, title: "Desktop Toggle".localized(appLanguage), subtitle: String(format: "%@ to hide or show all windows".localized(appLanguage), HotkeyFormatter.desktopToggleGlyphs), isActive: activeIndex == 1)
                settingRow(icon: "laptopcomputer", color: .pink, title: "Notch Alerts".localized(appLanguage), subtitle: "Pill notifications for layout events".localized(appLanguage), isActive: activeIndex == 2)
                settingRow(icon: "list.bullet.rectangle.portrait", color: .blue, title: "Activity Log Level".localized(appLanguage), subtitle: "Filter which events appear in the log".localized(appLanguage), isActive: activeIndex == 3)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.12),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .offset(y: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func settingRow(icon: String, color: Color, title: String, subtitle: String, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if icon == "list.bullet.rectangle.portrait" {
                Text(isActive ? "Verbose".localized(appLanguage) : "Necessary".localized(appLanguage))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isActive ? .white : .secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(isActive ? Color.blue : Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            } else {
                Capsule()
                    .fill(isActive ? color : Color.secondary.opacity(0.3))
                    .frame(width: 24, height: 13)
                    .overlay(alignment: isActive ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 11, height: 11)
                            .padding(1)
                            .shadow(radius: 0.5)
                    }
                    .animation(.spring(response: 0.28), value: isActive)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5.5)
        .background(isActive ? color.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? color.opacity(0.3) : Color.clear, lineWidth: 1))
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.spring(response: 0.35), value: isActive)
    }
}

// MARK: - Slide 8: Interactive Theme & Language Workshop

struct OBIllustrationCustomize: View {
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @Environment(\.colorScheme) private var colorScheme

    private var activeAccent: Color {
        themeColor.color(seed: 0)
    }

    private var accentTextColor: Color {
        // Galaxy's preview accent is a bright celestial blue in Light Mode,
        // even though the full app uses a dark cosmic background there.
        if themeColor.isGalaxy {
            return .black
        }
        return themeColor.onAccentColor(for: colorScheme)
    }

    private var activeThemeBadgeBackground: Color {
        themeColor.isGalaxy ? activeAccent : activeAccent.opacity(0.22)
    }

    var body: some View {
        ZStack {
            TourDesktopBackground()

            VStack(spacing: 8) {
                // Frosted glass Theme Studio card
                VStack(spacing: 16) {
                    // 1. Header
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(activeAccent.opacity(0.18))
                                .frame(width: 24, height: 24)
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(activeAccent)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Theme & Language".localized(appLanguage))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Affects the entire app live".localized(appLanguage))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Active Theme Indicator Badge
                        HStack(spacing: 4.5) {
                            if themeColor.isGalaxy {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(accentTextColor)
                            } else if themeColor == .default {
                                Image(systemName: "circle.slash")
                                    .font(.system(size: 8))
                                    .foregroundStyle(accentTextColor.opacity(0.8))
                            } else {
                                Circle()
                                    .fill(activeAccent)
                                    .frame(width: 6, height: 6)
                            }

                            Text(themeColor.rawValue.localized(appLanguage))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(accentTextColor)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(activeThemeBadgeBackground, in: Capsule())
                        .overlay(Capsule().stroke(activeAccent.opacity(0.6), lineWidth: 0.8))
                        .shadow(color: activeAccent.opacity(0.3), radius: 5)
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: themeColor)
                    }

                    // 2. All 11 Color Swatches — larger, with breathing room
                    HStack(spacing: 5) {
                        ForEach(ThemeColor.allCases) { theme in
                            let isSelected = themeColor == theme
                            let swatchColor = theme.color ?? Color.accentColor
                            let isDefault = theme == .default

                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    themeColor = theme
                                }
                            } label: {
                                ZStack {
                                    if theme.isGalaxy {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.03, green: 0.07, blue: 0.20),
                                                            Color(red: 0.10, green: 0.24, blue: 0.58),
                                                            Color(red: 0.82, green: 0.92, blue: 1.00)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 24, height: 24)

                                            Image(systemName: "sparkle")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .shadow(color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.8), radius: 2)
                                        }
                                    } else if isDefault {
                                        ZStack {
                                            Circle()
                                                .fill(Color.primary.opacity(0.10))
                                                .frame(width: 24, height: 24)
                                            Image(systemName: "circle.slash")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                        }
                                    } else {
                                        Circle()
                                            .fill(swatchColor)
                                            .frame(width: 24, height: 24)
                                    }

                                    if isSelected && !isDefault && !theme.isGalaxy {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(theme.onAccentColor(for: colorScheme))
                                            .shadow(color: .black.opacity(0.5), radius: 1)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            isSelected
                                                ? (theme.isGalaxy
                                                    ? AnyShapeStyle(
                                                        LinearGradient(
                                                            colors: [Color.white, Color(red: 0.35, green: 0.65, blue: 1.0)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                      )
                                                : isDefault
                                                        ? AnyShapeStyle(Color.primary.opacity(0.8))
                                                        : AnyShapeStyle(swatchColor))
                                                : AnyShapeStyle(Color.primary.opacity(0.15)),
                                            lineWidth: isSelected ? 2.5 : 0.8
                                        )
                                        .padding(-3)
                                        .opacity(isSelected ? 1 : 0.5)
                                )
                                .scaleEffect(isSelected ? 1.18 : 1.0)
                                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
                            }
                            .buttonStyle(.plain)
                            .help(theme.rawValue)
                        }
                    }

                    // 3. Thin divider
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 0.5)
                        .padding(.horizontal, 4)

                    // 4. Language Selection Strip
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(activeAccent)

                        Text("Language")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 5) {
                            languageButton(title: "System", lang: .auto)
                            languageButton(title: "English", lang: .english)
                            languageButton(title: "עברית", lang: .hebrew)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(activeAccent.opacity(0.4), lineWidth: 1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activeAccent)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
            }
            .padding(.horizontal, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func languageButton(title: String, lang: AppLanguage) -> some View {
        let isSelected = appLanguage == lang
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                appLanguage = lang
            }
        } label: {
            Text(title)
                .font(.system(size: 8.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? accentTextColor : Color.secondary)
                .padding(.horizontal, 6.5)
                .padding(.vertical, 3)
                .background {
                    if isSelected {
                        Capsule().fill(activeAccent)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layout Mode Picker

struct OBIllustrationModePicker: View {
    let isWindowServerInitializing: Bool
    @State private var selectedMode: Bool? = nil // nil = nothing chosen yet; true = autoSave; false = sessions
    @State private var glowPulse = false
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private var manager: WindowManager { WindowManager.shared }

    var body: some View {
        ZStack {
            TourDesktopBackground()

            VStack(spacing: 12) {
                // Keep both modes visible as a balanced pair while the setup
                // screen is also showing its startup loading status.
                HStack(spacing: 12) {
                    modeCard(
                        isAutoLayout: true,
                        icon: "clock.arrow.circlepath",
                        title: "Auto Layout",
                        accentColor: Color(red: 0.18, green: 0.62, blue: 1.0),
                        bullets: [
                            ("wand.and.sparkles", "Records your layout automatically"),
                            ("display.2", "Restores after sleep, quit or reboot"),
                            ("chart.bar.fill", "Timeline of all your positions"),
                        ]
                    )
                    .frame(width: 158)

                    modeCard(
                        isAutoLayout: false,
                        icon: "folder.badge.gearshape",
                        title: "Saved Sessions",
                        accentColor: Color(red: 0.55, green: 0.38, blue: 1.0),
                        bullets: [
                            ("camera.viewfinder", "You save snapshots when you want"),
                            ("tag.fill", "Named layouts for different setups"),
                            ("keyboard", "Restore with Fn or ⇪ shortcut"),
                        ]
                    )
                    .frame(width: 158)
                }
                .frame(maxWidth: .infinity)

                if selectedMode == nil && !isWindowServerInitializing {
                    Text("Tap a card to activate your preferred mode")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            // Hold both choices in the same neutral state until startup has
            // finished resolving the live window server state.
            selectedMode = isWindowServerInitializing ? nil : manager.store.autoSaveEnabled
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .onChange(of: isWindowServerInitializing) { _, isInitializing in
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedMode = isInitializing ? nil : manager.store.autoSaveEnabled
            }
        }
    }

    private func modeCard(
        isAutoLayout: Bool,
        icon: String,
        title: String,
        accentColor: Color,
        bullets: [(String, String)]
    ) -> some View {
        let isSelected = selectedMode == isAutoLayout
        let idleStrokeOpacity = isWindowServerInitializing ? 0.26 : 0.12
        let idleStrokeWidth: CGFloat = isWindowServerInitializing ? 1 : 0.75
        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                selectedMode = isAutoLayout
            }
            manager.setAutoSaveEnabled(isAutoLayout)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Icon + title row
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(isSelected ? 0.25 : 0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(title.localized(appLanguage))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if isSelected {
                            Text("Active")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(accentColor)
                                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        }
                    }
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Checkmark when selected
                        ZStack {
                            Circle()
                                .fill(isSelected ? accentColor : Color.primary.opacity(0.08))
                                .frame(width: 18, height: 18)
                            if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.black)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }

                // Bullet points
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(bullets, id: \.1) { bullet in
                        HStack(spacing: 6) {
                            Image(systemName: bullet.0)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(isSelected ? accentColor : Color.secondary)
                                .frame(width: 13)

                            Text(bullet.1.localized(appLanguage))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? Color.primary.opacity(0.85) : Color.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                        }
                    }
                }
                .padding(.leading, 2)

                // Select button at bottom
                Text(isSelected ? "Selected ✓" : "Select")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(isSelected ? accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(
                            isSelected ? accentColor.opacity(0.7) : Color.primary.opacity(0.12),
                            lineWidth: 0.8
                        )
                    )
            }
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isSelected ? accentColor.opacity(glowPulse ? 0.85 : 0.5) : Color.primary.opacity(idleStrokeOpacity),
                        lineWidth: isSelected ? 1.5 : idleStrokeWidth
                    )
            )
            .shadow(
                color: isSelected ? accentColor.opacity(0.35) : .black.opacity(0.15),
                radius: isSelected ? 12 : 6,
                x: 0, y: 3
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
