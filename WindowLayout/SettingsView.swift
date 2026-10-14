import SwiftUI

// MARK: - Settings Categories

enum SettingsCategory: String, CaseIterable, Identifiable {
    case automation = "General"
    case restoreSettings = "Restore Settings"
    case experimental = "Experimental"
    case appearance = "Appearance & Notifications"
    case permissions = "System Permissions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .automation: return "bolt.fill"
        case .restoreSettings: return "arrow.triangle.2.circlepath.circle.fill"
        case .experimental: return "flask.fill"
        case .appearance: return "paintpalette.fill"
        case .permissions: return "shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .automation: return .orange
        case .restoreSettings: return .blue
        case .experimental: return .green
        case .appearance: return .pink
        case .permissions: return .red
        }
    }

    var subtitle: String {
        switch self {
        case .automation: return "Startup option, logging & language"
        case .restoreSettings: return "Full restore, single app & Quick Key controls"
        case .experimental: return "Desktop toggle & Cmd+Shift+R triggers"
        case .appearance: return "Theme, Liquid Glass, Notch & Notifications"
        case .permissions: return "Accessibility & Location permissions"
        }
    }
}

// MARK: - Notification Channel

enum NotificationChannel: String, CaseIterable, Identifiable {
    case notch = "Notch Notification"
    case system = "macOS Notification Center"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notch: return "iphone.gen2"
        case .system: return "bell.badge.fill"
        }
    }

    var color: Color {
        switch self {
        case .notch: return Color(red: 0.4, green: 0.3, blue: 1.0)
        case .system: return .pink
        }
    }

    var subtitle: String {
        switch self {
        case .notch: return "Slide-down alerts from the MacBook notch"
        case .system: return "Standard macOS Notification Center banners"
        }
    }
}

enum NotificationCardTarget: Hashable {
    case fullRestore
    case welcomePill
    case singleRestore
    case displayChange
    case snapshotUpdate
    case desktopToggle
    case permissionWarning

    static func event(for eventType: WindowManager.NotificationEventType) -> Self {
        switch eventType {
        case .fullRestore: return .fullRestore
        case .singleRestore: return .singleRestore
        case .displayChange: return .displayChange
        case .snapshotUpdate: return .snapshotUpdate
        case .desktopToggle: return .desktopToggle
        case .permissionWarning: return .permissionWarning
        }
    }
}

struct NotificationCardFocusRequest: Identifiable {
    let id: UUID
    let channel: NotificationChannel
    let target: NotificationCardTarget
}

// MARK: - Settings View (iOS Navigation Stack Style)

struct SettingsView: View {
    @EnvironmentObject var manager: WindowManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var desktopToggleManager = DesktopToggleManager.shared
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("minimalVisualAnimations") private var minimalVisualAnimations: Bool = true
    @AppStorage("showNotchNotification") private var showNotchNotification: Bool = true
    @AppStorage("playNotificationSound") private var playNotificationSound: Bool = true
    @AppStorage("masterNotificationsEnabled") private var masterNotificationsEnabled: Bool = true
    @AppStorage("masterSoundEnabled") private var masterSoundEnabled: Bool = true
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("updateChecksEnabled") private var updateChecksEnabled: Bool = true
    @AppStorage("restoreFocusedAppOnLeftClick") private var restoreFocusedAppOnLeftClick: Bool = true
    @State private var showingLocationAlert = false
    @State private var isTogglingLocation = false
    @State private var selectedCategory: SettingsCategory? = nil
    @State private var selectedNotificationChannel: NotificationChannel? = nil
    @State private var notificationCardFocusRequest: NotificationCardFocusRequest? = nil
    @State private var showMenuBarIconStyle: Bool = false
    @State private var hasFinderPerm = false
    @State private var showingOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    private var notificationsToggleBinding: Binding<Bool> {
        Binding(
            get: { masterNotificationsEnabled },
            set: { isEnabled in
                masterNotificationsEnabled = isEnabled
            }
        )
    }

    private var soundToggleBinding: Binding<Bool> {
        Binding(
            get: { masterNotificationsEnabled && masterSoundEnabled },
            set: { isEnabled in
                guard masterNotificationsEnabled else { return }
                masterSoundEnabled = isEnabled
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let category = selectedCategory {
                // Detail Sub-Window View
                categoryDetailView(for: category)
                    .transition(.asymmetric(
                        insertion: .move(edge: appLanguage == .hebrew ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: appLanguage == .hebrew ? .leading : .trailing).combined(with: .opacity)
                    ))
            } else {
                // Root Categories List View
                categoriesListView
                    .transition(.asymmetric(
                        insertion: .move(edge: appLanguage == .hebrew ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: appLanguage == .hebrew ? .trailing : .leading).combined(with: .opacity)
                    ))
            }
        }
        .frame(width: 480, height: 650)
        .background {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
        .background {
            if themeColor.isGalaxy {
                GalaxyCosmicBackgroundView()
            }
        }
        .background(SettingsWindowTransparencyPatch())
        .onChange(of: appLanguage) { oldValue, newValue in
            if newValue == .english {
                UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            } else if newValue == .hebrew {
                UserDefaults.standard.set(["he"], forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
        }
        .alert("Location Privacy & Safety".localized(appLanguage), isPresented: $showingLocationAlert) {
            Button("Turn On".localized(appLanguage)) {
                manager.store.saveLocationEnabled = true
                manager.requestLocationPermission()
            }
            Button("Cancel".localized(appLanguage), role: .cancel) {
                // remains false
            }
        } message: {
            Text("Your location is used to tag your saved window layouts so you can easily identify where they were saved. To turn the coordinates into a street address, they are sent to Apple once per saved layout. Nothing is sent to the developer.".localized(appLanguage))
        }
        .minimalVisualAnimations()
        .environment(\.minimalVisualAnimationsEnabled, minimalVisualAnimations)
        .appThemeColorScheme(themeColor)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(showsV15ReleaseNotes: false) {
                showingOnboarding = false
                hasCompletedOnboarding = true
            }
            .fullVisualAnimations()
        }
    }

    // MARK: - Root Categories List View

    private var categoriesListView: some View {
        VStack(spacing: 16) {
            // iOS-Style Category Cards Group
            VStack(spacing: 8) {
                ForEach(SettingsCategory.allCases) { category in
                    SettingsCategoryRow(category: category) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedCategory = category
                        }
                    }
                }
            }

            // Feature Tour Animated Section
            SettingsFeatureTourSection(showingOnboarding: $showingOnboarding)
                .padding(.top, 2)
                .fullVisualAnimations()

            // App Version & GitHub Link Footer
            HStack(spacing: 8) {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "13.2"
                let displayVersion = version.hasPrefix("v") ? version : "v\(version)"
                
                Text("\("Version".localized(appLanguage)) \(displayVersion)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.8))

                Text("•")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.4))

                Button {
                    if let url = URL(string: "https://github.com/netanel3000fine/RememberMyWindow") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("GitHub".localized(appLanguage))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .help("Open RememberMyWindows on GitHub".localized(appLanguage))
            }
            .padding(.top, -6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category Detail Sub-Window View

    @ViewBuilder
    private func categoryDetailView(for category: SettingsCategory) -> some View {
        if category == .appearance, let channel = selectedNotificationChannel {
            // Third-level: Notification channel detail (pushes from Appearance)
            NotificationChannelDetailView(
                channel: channel,
                manager: manager,
                appLanguage: appLanguage,
                focusRequest: notificationCardFocusRequest,
                onFocusRequestConsumed: { requestID in
                    guard notificationCardFocusRequest?.id == requestID else { return }
                    notificationCardFocusRequest = nil
                },
                onNavigateToCard: { targetChannel, target in
                    let request = NotificationCardFocusRequest(
                        id: UUID(),
                        channel: targetChannel,
                        target: target
                    )
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedNotificationChannel = targetChannel
                        notificationCardFocusRequest = request
                    }
                }
            ) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectedNotificationChannel = nil
                    notificationCardFocusRequest = nil
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: appLanguage == .hebrew ? .leading : .trailing).combined(with: .opacity),
                removal: .move(edge: appLanguage == .hebrew ? .leading : .trailing).combined(with: .opacity)
            ))
        } else if category == .appearance, showMenuBarIconStyle {
            // Third-level: Menu Bar Icon Style detail (pushes from Appearance)
            MenuBarIconDetailView(
                appLanguage: appLanguage,
                themeColor: themeColor
            ) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showMenuBarIconStyle = false
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: appLanguage == .hebrew ? .leading : .trailing).combined(with: .opacity),
                removal: .move(edge: appLanguage == .hebrew ? .leading : .trailing).combined(with: .opacity)
            ))
        } else {
            VStack(spacing: 0) {
                // Top iOS Navigation Bar with Back Button
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedNotificationChannel = nil
                            showMenuBarIconStyle = false
                            selectedCategory = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: appLanguage == .hebrew ? "chevron.right" : "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                            Text("Settings".localized(appLanguage))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlass(cornerRadius: 16, style: .card)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                            .font(.system(size: 15, weight: .semibold))
                        Text(category.rawValue.localized(appLanguage))
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // Sub-page Content
                ScrollView {
                    VStack(spacing: 20) {
                        categoryContent(for: category)
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Category Content Router

    @ViewBuilder
    private func categoryContent(for category: SettingsCategory) -> some View {
        switch category {
        case .automation:
            automationContent
        case .restoreSettings:
            restoreSettingsContent
        case .experimental:
            experimentalContent
        case .appearance:
            appearanceContent
        case .permissions:
            permissionsContent
        }
    }

    // MARK: - 1. Automation Content

    private var automationContent: some View {
        SettingsSection(title: "General".localized(appLanguage), icon: "bolt.fill") {
            VStack(spacing: 0) {
                SettingsToggle(
                    title: "Launch at login",
                    subtitle: "Start RememberMyWindows automatically in the background whenever you log into macOS",
                    icon: "arrow.right.square.fill",
                    isOn: $manager.launchAtLogin
                )

                Divider().padding(.horizontal, 12)

                SettingsToggle(
                    title: "Check for Updates Automatically",
                    subtitle: "Checks for new GitHub releases once daily when the app starts",
                    icon: "arrow.down.circle.fill",
                    isOn: Binding(
                        get: { updateChecksEnabled },
                        set: {
                            updateChecksEnabled = $0
                            UpdateManager.shared.setAutomaticChecksEnabled($0)
                        }
                    )
                )

                Divider().padding(.horizontal, 12)

                SettingsPicker(
                    title: "Activity Log Level",
                    subtitle: "Filter which events appear in the real-time activity log",
                    icon: "list.bullet.rectangle.portrait",
                    selection: Binding(
                        get: { manager.store.logLevel },
                        set: { manager.store.logLevel = $0 }
                    )
                )

                Divider().padding(.horizontal, 12)

                SettingsToggle(
                    title: "Use polling mode (legacy)",
                    subtitle: "Checks window positions after 5 s, then backs off while idle instead of event notifications",
                    icon: "timer",
                    isOn: Binding(
                        get: { manager.store.usePollingMode },
                        set: { newValue in
                            manager.store.usePollingMode = newValue
                            manager.restartTracking()
                        }
                    )
                )

                if manager.store.usePollingMode {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Higher energy usage".localized(appLanguage))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text("Polling checks less often while idle, but event-driven mode uses the least power.".localized(appLanguage))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.07))
                }

                Divider().padding(.horizontal, 12)

                SettingsToggle(
                    title: "Save location with layouts",
                    subtitle: "Tags saved layout sessions with your current GPS coordinates to easily identify locations",
                    icon: "location.fill",
                    isOn: Binding(
                        get: { manager.store.saveLocationEnabled },
                        set: { newValue in
                            if newValue {
                                showingLocationAlert = true
                            } else {
                                isTogglingLocation = true
                                Task { @MainActor in
                                    manager.store.saveLocationEnabled = false
                                    try? await Task.sleep(nanoseconds: 200_000_000)
                                    isTogglingLocation = false
                                }
                            }
                        }
                    ),
                    isLoading: isTogglingLocation
                )
                .autoLayoutDisabled(manager.store.autoSaveEnabled, appLanguage: appLanguage)

                Divider().padding(.horizontal, 12)

                SettingsToggle(
                    title: "Group other apps in submenu",
                    subtitle: "Keep the menu bar dropdown compact by placing background apps in a submenu",
                    icon: "filemenu.and.selection",
                    isOn: Binding(
                        get: { manager.store.groupOtherAppsInSubmenu },
                        set: { newValue in
                            manager.store.groupOtherAppsInSubmenu = newValue
                            manager.persist()
                        }
                    )
                )
                .autoLayoutDisabled(manager.store.autoSaveEnabled, appLanguage: appLanguage)

                Divider().padding(.horizontal, 12)

                SettingsLanguagePicker(
                    title: "App Language",
                    subtitle: "Override the system language",
                    icon: "globe",
                    selection: $appLanguage
                )

                Text("Restart app to apply to system menus".localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)

            }
        }
    }

    // MARK: - 2. Restore Settings Content (Full Restore & Single App Restore)

    @ViewBuilder
    private var restoreSettingsContent: some View {
        let isAutoLayoutActive = manager.store.autoSaveEnabled

        VStack(spacing: 18) {
            // Subcategory 1: Full Restore
            SettingsSection(title: "Auto Layout".localized(appLanguage), icon: "clock.arrow.circlepath") {
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Auto Layout Mode",
                        subtitle: "Records your arrangement to its own file as you work, so it survives a quit, a sleep or a reboot. Your saved sessions are never written to, but while this is on, automatic restores prefer the newer Auto layout over them. Switching it off stops the recording and leaves the file in place.",
                        icon: "clock.arrow.circlepath",
                        isOn: Binding(
                            get: { manager.store.autoSaveEnabled },
                            set: { manager.setAutoSaveEnabled($0) }
                        )
                    )
                }
            }

            SettingsSection(title: "Full Restore".localized(appLanguage), icon: "display.2") {
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Full restore on connect",
                        subtitle: "Restores all saved windows to their exact positions automatically when displays reconnect",
                        icon: "display.2",
                        isOn: Binding(
                            get: { manager.store.autoRestoreEnabled },
                            set: { manager.store.autoRestoreEnabled = $0 }
                        )
                    )

                    HStack(spacing: 10) {
                        Image(systemName: "square.3.layers.3d.top.filled")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(
                                themeColor.isGalaxy
                                    ? Color.black
                                    : themeColor.onAccentColor(for: colorScheme)
                            )
                            .frame(width: 26, height: 26)
                            .background(themeColor.color(seed: 0), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Front App".localized(appLanguage))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.8))
                            Text((isAutoLayoutActive
                                  ? "Pin which app comes to the front after a full restore — tap the layers icon on any app row in captured windows."
                                  : "Pin which app comes to the front after a full restore — tap the layers icon on any app row in a saved session."
                                 ).localized(appLanguage))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Animate restoration",
                        subtitle: "Smoothly slide and animate windows to their target spots during restoration",
                        icon: "wand.and.stars",
                        isOn: Binding(
                            get: { manager.store.restoreAnimated },
                            set: { manager.store.restoreAnimated = $0 }
                        )
                    )

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Launch closed apps on full restore",
                        subtitle: "Automatically launch closed applications saved in your layout session sequentially before restoring",
                        icon: "arrow.triangle.2.circlepath",
                        isOn: Binding(
                            get: { manager.store.launchMissingAppsOnRestore },
                            set: { manager.store.launchMissingAppsOnRestore = $0 }
                        )
                    )
                }
            }

            // Subcategory 2: Single App Restore
            SettingsSection(title: "Single App Restore".localized(appLanguage), icon: "app.badge.checkmark") {
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Auto-restore on app open",
                        subtitle: "Restores an app's saved window position automatically whenever it is launched",
                        icon: "app.badge.checkmark",
                        isOn: Binding(
                            get: { manager.store.autoRestoreOnAppOpen },
                            set: { manager.store.autoRestoreOnAppOpen = $0 }
                        )
                    )

                    if manager.store.autoRestoreOnAppOpen {
                        Divider().padding(.horizontal, 12)

                        SettingsStepper(
                            title: "App launch restore delay",
                            subtitle: "Delay before auto-restoring window position when an app opens",
                            icon: "timer",
                            value: Binding(
                                get: { manager.store.singleAppRestoreDelay },
                                set: { manager.store.singleAppRestoreDelay = max(0.0, $0); manager.persist() }
                            ),
                            range: 0.0...10.0,
                            step: 0.5,
                            unit: "s"
                        )
                    }

                    Divider().padding(.horizontal, 12)

                    VStack(spacing: 0) {
                        SettingsToggle(
                            title: "Restore focused app on left click",
                            subtitle: "Left-clicking the menu bar icon restores the window position of the frontmost app",
                            icon: "cursorarrow.click",
                            isOn: $restoreFocusedAppOnLeftClick
                        )

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("When either trigger fires, **Trigger Command on Single Restore** in Experimental also applies.".localized(appLanguage))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .autoLayoutDisabled(isAutoLayoutActive, appLanguage: appLanguage)
                }
            }

            // Subcategory 3: Quick Key Restore (Fn Long-Press / Double-Tap Caps Lock)
            SettingsSection(title: "Quick Key Restore".localized(appLanguage), icon: "keyboard.fill") {
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Quick key restore",
                        subtitle: "Trigger window restoration using Fn long-press or double-tap Caps Lock",
                        icon: "keyboard.fill",
                        isOn: Binding(
                            get: { manager.store.quickKeyRestoreEnabled },
                            set: { newValue in
                                manager.store.quickKeyRestoreEnabled = newValue
                                manager.persist()
                                NotificationCenter.default.post(name: .quickKeyRestoreSettingChanged, object: nil)
                            }
                        )
                    )

                    if manager.store.quickKeyRestoreEnabled {
                        Divider().padding(.horizontal, 12)

                        // Trigger Gesture Picker (Fn Long-Press vs Double-Tap Caps Lock vs Both)
                        HStack(spacing: 12) {
                            Image(systemName: manager.store.quickKeyTrigger == .fnLongPress ? "globe" : (manager.store.quickKeyTrigger == .capsLockDoubleTap ? "capslock.fill" : "keyboard.fill"))
                                .foregroundStyle(Color.accentColor)
                                .font(.system(size: 14))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trigger shortcut".localized(appLanguage))
                                    .font(.system(size: 13, weight: .medium))
                                Text(manager.store.quickKeyTrigger == .fnLongPress
                                     ? "Hold Fn / Globe (🌐) key to restore".localized(appLanguage)
                                     : (manager.store.quickKeyTrigger == .capsLockDoubleTap
                                        ? "Double-tap ⇪ Caps Lock key to restore".localized(appLanguage)
                                        : "Hold Fn (🌐) or double-tap ⇪ Caps Lock to restore".localized(appLanguage)))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { manager.store.quickKeyTrigger },
                                set: { manager.store.quickKeyTrigger = $0; manager.persist() }
                            )) {
                                ForEach(QuickKeyTrigger.allCases, id: \.self) { trigger in
                                    Text(trigger.rawValue.localized(appLanguage)).tag(trigger)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(width: 175)
                        }
                        .padding(12)

                        if manager.store.quickKeyTrigger == .fnLongPress || manager.store.quickKeyTrigger == .both {
                            Divider().padding(.horizontal, 12)

                            // Hold Duration Stepper (for Fn Long-Press & Both)
                            SettingsStepper(
                                title: "Hold duration",
                                subtitle: "How long to hold Fn before the restore fires",
                                icon: "timer",
                                value: Binding(
                                    get: { manager.store.quickKeyHoldDuration },
                                    set: { manager.store.quickKeyHoldDuration = max(0.5, min(3.0, $0)); manager.persist() }
                                ),
                                range: 0.5...3.0,
                                step: 0.1,
                                unit: "s"
                            )
                        }

                        Divider().padding(.horizontal, 12)

                        // Restore Mode Picker (Front App Restore vs Full Restore)
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.accentColor)
                                .font(.system(size: 14))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Restore mode".localized(appLanguage))
                                    .font(.system(size: 13, weight: .medium))
                                Text("Choose what gets restored when the shortcut fires".localized(appLanguage))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { manager.store.quickKeyRestoreMode },
                                set: { manager.store.quickKeyRestoreMode = $0; manager.persist() }
                            )) {
                                ForEach(QuickKeyRestoreMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue.localized(appLanguage)).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(width: 140)
                        }
                        .padding(12)

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text(manager.store.quickKeyTrigger == .fnLongPress
                                 ? "Short taps on Fn work normally. Only holding it for the duration triggers restore.".localized(appLanguage)
                                 : (manager.store.quickKeyTrigger == .capsLockDoubleTap
                                    ? "Single taps on Caps Lock work normally. Double-tapping restores and turns off Caps Lock.".localized(appLanguage)
                                    : "Hold Fn (🌐) for the set duration, or double-tap ⇪ Caps Lock anytime to restore instantly.".localized(appLanguage)))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .autoLayoutDisabled(isAutoLayoutActive, appLanguage: appLanguage)
            }
        }
    }

    // MARK: - 3. Experimental Content (Desktop Toggle & Active App Command Trigger)

    private var experimentalContent: some View {
        VStack(spacing: 18) {
            // Section 1: Desktop Toggle
            SettingsSection(title: "Desktop Toggle".localized(appLanguage), icon: "keyboard") {
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Desktop Toggle",
                        subtitle: "Quickly hide/show all windows across your desktop",
                        icon: "keyboard",
                        isOn: $desktopToggleManager.isEnabled
                    )

                    Divider().padding(.horizontal, 12)

                    VStack(spacing: 0) {
                        SettingsShortcutRecorder(
                            title: "Desktop Toggle shortcut",
                            subtitle: "Press any combination with at least one modifier",
                            icon: "command",
                            hotkey: $desktopToggleManager.hotkey,
                            onBeginRecording: { desktopToggleManager.suspendForRecording() },
                            onEndRecording: { desktopToggleManager.resumeAfterRecording() }
                        )

                        Divider().padding(.horizontal, 12)

                        SettingsToggle(
                            title: "Restore layout on unhide",
                            subtitle: "Automatically run a full layout restore when the windows come back",
                            icon: "arrow.uturn.backward",
                            isOn: $desktopToggleManager.restoreOnUnhide
                        )
                        .autoLayoutDisabled(manager.store.autoSaveEnabled, appLanguage: appLanguage)
                    }
                    .settingsDisabled(
                        !desktopToggleManager.isEnabled,
                        reason: "Enable Desktop Toggle first",
                        appLanguage: appLanguage,
                        showsReason: true
                    )
                }
            }

            // Section 2: Active App Command Trigger (⌘⇧R)
            SettingsSection(title: "Active App Command Trigger (⌘⇧R)".localized(appLanguage), icon: "command") {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(spacing: 5) {
                            ZStack {
                                Text("⌘⇧R")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(width: 32, height: 22)
                            .background(Color.secondary.opacity(0.08), in: Capsule())
                            Text("Cmd+⇧+R")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 5) {
                            ZStack(alignment: .topTrailing) {
                                Text("⌘⇧R")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 5.5, weight: .black))
                                    .foregroundStyle(Color.white)
                                    .padding(1.0)
                                    .background(Color.green, in: Circle())
                                    .offset(x: 2, y: -2)
                            }
                            .frame(height: 22)
                            .frame(minWidth: 32)
                            .background(Color.green.opacity(0.1), in: Capsule())
                            Text("Enabled".localized(appLanguage))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Text("Tap the ⌘⇧R button on any app row in a saved session".localized(appLanguage))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 130)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Trigger Command on Full Restore",
                        subtitle: "Sends Cmd+Shift+R key shortcut to the front app after restoring all windows",
                        icon: "command.circle",
                        isOn: Binding(
                            get: { manager.store.refreshFrontmostOnFullRestore },
                            set: { manager.store.refreshFrontmostOnFullRestore = $0; manager.persist() }
                        )
                    )

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Trigger Command on Single Restore",
                        subtitle: "Sends Cmd+Shift+R key shortcut when a single app is restored or launched",
                        icon: "command.circle.fill",
                        isOn: Binding(
                            get: { manager.store.refreshFrontmostOnSingleRestore },
                            set: { manager.store.refreshFrontmostOnSingleRestore = $0; manager.persist() }
                        )
                    )

                    if manager.store.refreshFrontmostOnSingleRestore {
                        Divider().padding(.horizontal, 12)

                        SettingsStepper(
                            title: "Command delay on single restore",
                            subtitle: "Delay before sending command shortcut on single app restore",
                            icon: "clock.badge.checkmark",
                            value: Binding(
                                get: { manager.store.singleAppCommandDelay },
                                set: { manager.store.singleAppCommandDelay = max(0.0, $0); manager.persist() }
                            ),
                            range: 0.0...10.0,
                            step: 0.5,
                            unit: "s"
                        )

                        if manager.store.singleAppCommandDelay < 4.3 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.orange)
                                Text("Delays below 4.3s may send shortcut before the app gains focus.".localized(appLanguage))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider().padding(.horizontal, 12)

                        SettingsStepper(
                            title: "Additional delay for web apps",
                            subtitle: "Extra wait time for web apps, PWAs, and browsers on launch before sending ⌘⇧R",
                            icon: "globe",
                            value: Binding(
                                get: { manager.store.webAppLaunchCommandDelay },
                                set: { manager.store.webAppLaunchCommandDelay = max(0.0, $0); manager.persist() }
                            ),
                            range: 0.0...10.0,
                            step: 0.5,
                            unit: "s"
                        )

                        CustomWebAppsManagementView(manager: manager, appLanguage: appLanguage)
                    }

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Only when external monitor is active",
                        subtitle: "Restricts sending command shortcut to times when at least two displays are connected",
                        icon: "desktopcomputer",
                        isOn: Binding(
                            get: { manager.store.refreshFrontmostOnlyOnExternalDisplay },
                            set: { manager.store.refreshFrontmostOnlyOnExternalDisplay = $0; manager.persist() }
                        )
                    )

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Animate Command+Shift+R overlay",
                        subtitle: "Displays a floating visual HUD badge over the target window when the command is triggered",
                        icon: "sparkles.tv",
                        isOn: Binding(
                            get: { manager.store.showCommandOverlayAnimation },
                            set: { manager.store.showCommandOverlayAnimation = $0; manager.persist() }
                        )
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Label("How it works".localized(appLanguage), systemImage: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("After restoring windows, the app sends **⌘⇧R** to the frontmost application. Open each saved session and tap the **⌘⇧R button** on any app row to exclude that app from receiving the keystroke.".localized(appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .autoLayoutDisabled(manager.store.autoSaveEnabled, appLanguage: appLanguage)
            }
        }
    }

    // MARK: - 5. Appearance Content

    private var appearanceContent: some View {
        VStack(spacing: 18) {

        // ── Notifications Section ───────────────────────────────────────────────
        SettingsSection(title: "Notifications".localized(appLanguage), icon: "bell.fill") {
            VStack(spacing: 0) {

                // Keep the two master controls together so their dependency is
                // visible. Sounds stay off and disabled while notifications are off.
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Notifications",
                        subtitle: "Enable all app alerts and sounds",
                        icon: "bell.fill",
                        isOn: notificationsToggleBinding
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Notification Sounds",
                        subtitle: "Play sounds for alerts",
                        icon: "speaker.wave.2.fill",
                        isOn: soundToggleBinding
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(!masterNotificationsEnabled)
                    .opacity(masterNotificationsEnabled ? 1 : 0.55)
                }

                Divider().padding(.horizontal, 12)

                if masterNotificationsEnabled {
                    // ── Notch Notification Nav Row ──────────────────────────────
                    let displayChangeSuppressed = manager.store.welcomeNotchPillEnabled
                    let notchActiveCount = (manager.store.notchNotifyOnFullRestore ? 1 : 0) +
                                          (manager.store.notchNotifyOnSingleRestore ? 1 : 0) +
                                          (manager.store.notchNotifyOnDisplayChange && !displayChangeSuppressed ? 1 : 0) +
                                          (manager.store.notchNotifyOnSnapshotUpdate ? 1 : 0) +
                                          (manager.store.notchNotifyOnDesktopToggle ? 1 : 0)
                    NotificationChannelNavRow(
                        channel: .notch,
                        isEnabled: showNotchNotification,
                        activeCount: notchActiveCount,
                        appLanguage: appLanguage
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedNotificationChannel = .notch
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // ── System Notification Nav Row ──────────────────────────────
                    let sysActiveCount = (manager.store.systemNotifyOnFullRestore ? 1 : 0) +
                                        (manager.store.systemNotifyOnSingleRestore ? 1 : 0) +
                                        (manager.store.systemNotifyOnDisplayChange && !displayChangeSuppressed ? 1 : 0) +
                                        (manager.store.systemNotifyOnSnapshotUpdate ? 1 : 0) +
                                        (manager.store.systemNotifyOnDesktopToggle ? 1 : 0)
                    NotificationChannelNavRow(
                        channel: .system,
                        isEnabled: manager.store.showSystemNotification,
                        activeCount: sysActiveCount,
                        appLanguage: appLanguage
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedNotificationChannel = .system
                        }
                    }
                }
            }
        }

        // ── Appearance Section ──────────────────────────────────────────────────
        SettingsSection(title: "Appearance".localized(appLanguage), icon: "paintpalette.fill") {
            VStack(spacing: 0) {

                // ── Theme Color ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme Color".localized(appLanguage))
                                .font(.system(size: 13, weight: .medium))
                            Text("Primary accent color highlights across the app interface".localized(appLanguage))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(themeColor.color(seed: 0))
                            .font(.system(size: 14))
                            .frame(width: 24)
                    }

                    // Horizontal colour swatch strip
                    HStack(spacing: 8) {
                        ForEach(ThemeColor.allCases) { theme in
                            let isSelected = themeColor == theme
                            let swatchColor = theme.color ?? Color.accentColor
                            let isDefault = theme == .default

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    themeColor = theme
                                }
                            } label: {
                                ZStack {
                                    if theme.isGalaxy {
                                        // Deep midnight-blue to star-white gradient swatch with starlight glint
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
                                                .frame(width: 26, height: 26)

                                            Image(systemName: "sparkle")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .shadow(color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.8), radius: 2)
                                        }
                                    } else if isDefault {
                                        ZStack {
                                            Circle()
                                                .fill(Color.primary.opacity(0.06))
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "circle.slash")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(isSelected ? .primary : .secondary)
                                        }
                                    } else {
                                        Circle()
                                            .fill(swatchColor)
                                            .frame(width: 26, height: 26)
                                    }

                                    if isSelected && !isDefault {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(theme.onAccentColor(for: colorScheme))
                                            .shadow(color: .black.opacity(0.4), radius: 1)
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
                                            lineWidth: isSelected ? 2.5 : 1
                                        )
                                        .padding(-3)
                                        .opacity(isSelected ? 1 : 0.6)
                                )
                                .scaleEffect(isSelected ? 1.12 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                            }
                            .buttonStyle(.plain)
                            .help(theme.rawValue)
                        }
                    }
                    .padding(.leading, 28) // align under the label text
                }
                .padding(12)

                Divider().padding(.horizontal, 12)

                SettingsCheckbox(
                    title: "Minimal Visual Animations",
                    subtitle: "Use simple transitions for controls and layout previews",
                    isOn: $minimalVisualAnimations
                )

                Divider().padding(.horizontal, 12)

                // ── Menu Bar Icon Style Nav Row ──────────────────────────────
                MenuBarIconNavRow(appLanguage: appLanguage, themeColor: themeColor) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showMenuBarIconStyle = true
                    }
                }

            }
        }

        } // end VStack
    }

    // MARK: - 6. Permissions Content

    private var permissionsContent: some View {
        SettingsSection(title: "System Permissions".localized(appLanguage), icon: "shield.fill") {
            VStack(alignment: .leading, spacing: 12) {

                // ── Finder Automation ──────────────────────────────────────────
                HStack(spacing: 12) {
                    Circle()
                        .fill(hasFinderPerm ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: (hasFinderPerm ? Color.green : Color.orange).opacity(0.5), radius: 4)

                    Text(hasFinderPerm
                         ? "Finder Control granted".localized(appLanguage)
                         : "Finder Control required".localized(appLanguage))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    if !hasFinderPerm {
                        Button("Grant Permission…".localized(appLanguage)) {
                            manager.requestFinderAutomationPermission()
                            // Instantly re-check after brief delay when clicked
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                hasFinderPerm = manager.hasFinderAutomationPermission
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .onAppear {
                    hasFinderPerm = manager.hasFinderAutomationPermission
                }
                .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                    let updated = manager.hasFinderAutomationPermission
                    if updated != hasFinderPerm {
                        hasFinderPerm = updated
                    }
                }

                Text("Required for the Desktop Toggle to collapse and restore Finder windows.".localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
                    )
                } label: {
                    HStack {
                        Text("Open Automation Settings…".localized(appLanguage))
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Divider().padding(.vertical, 4)

                // ── Accessibility ─────────────────────────────────────────────
                HStack(spacing: 12) {
                    Circle()
                        .fill(manager.hasAccessibilityPermission ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: (manager.hasAccessibilityPermission ? Color.green : Color.orange).opacity(0.5), radius: 4)

                    Text(manager.hasAccessibilityPermission
                         ? "Accessibility access granted".localized(appLanguage)
                         : "Accessibility access required".localized(appLanguage))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    if !manager.hasAccessibilityPermission {
                        HStack(spacing: 6) {
                            Button("Re-check Status".localized(appLanguage)) {
                                manager.checkAccessibilityPermissionManually()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Grant Permission…".localized(appLanguage)) {
                                manager.requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                Text("RememberMyWindows needs Accessibility permission to restore window positions in other apps like Telegram, Chrome, etc.".localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !manager.hasAccessibilityPermission {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                            .padding(.top, 2)
                        Text("If RememberMyWindows is already turned ON in System Settings, the macOS permission cache may be out of sync. Toggle the switch OFF and ON to refresh it.".localized(appLanguage))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    manager.openAccessibilitySettings()
                } label: {
                    HStack {
                        Text("Open System Settings…".localized(appLanguage))
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Divider().padding(.vertical, 8)

                HStack(spacing: 12) {
                    let locStatus = manager.locationAuthorizationStatus
                    let statusColor: Color = {
                        switch locStatus {
                        case .authorizedWhenInUse, .authorizedAlways: return .green
                        case .denied, .restricted: return .red
                        case .notDetermined: return .orange
                        @unknown default: return .gray
                        }
                    }()
                    let statusText: String = {
                        switch locStatus {
                        case .authorizedWhenInUse, .authorizedAlways: return "Location access granted"
                        case .denied: return "Location access denied"
                        case .restricted: return "Location access restricted"
                        case .notDetermined: return "Location access required"
                        @unknown default: return "Location status unknown"
                        }
                    }()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.5), radius: 4)

                    Text(statusText.localized(appLanguage))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    if locStatus == .notDetermined {
                        Button("Grant Permission…".localized(appLanguage)) {
                            manager.requestLocationPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                Text("To revoke location permission, it must be disabled manually in System Settings -> Privacy & Security -> Location Services.".localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
                    )
                } label: {
                    HStack {
                        Text("Open Location Settings…".localized(appLanguage))
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
            .padding(16)
        }
    }

}


private struct DisabledSettingModifier: ViewModifier {
    let isDisabled: Bool
    let reason: String
    let appLanguage: AppLanguage
    let showsReason: Bool

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.24 : 1.0)
                .grayscale(isDisabled ? 1.0 : 0.0)

            if isDisabled && showsReason {
                Label(reason.localized(appLanguage), systemImage: "info.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isDisabled {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
        }
    }
}

private extension View {
    func settingsDisabled(
        _ isDisabled: Bool,
        reason: String,
        appLanguage: AppLanguage,
        showsReason: Bool = true
    ) -> some View {
        modifier(DisabledSettingModifier(
            isDisabled: isDisabled,
            reason: reason,
            appLanguage: appLanguage,
            showsReason: showsReason
        ))
    }

    func autoLayoutDisabled(
        _ isDisabled: Bool,
        appLanguage: AppLanguage,
        showsReason: Bool = true
    ) -> some View {
        settingsDisabled(
            isDisabled,
            reason: "Unavailable while Auto Layout is on",
            appLanguage: appLanguage,
            showsReason: showsReason
        )
    }
}


// MARK: - Category Row Component

struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let action: () -> Void

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(category.color.opacity(0.18))
                    Image(systemName: category.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(category.color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue.localized(appLanguage))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(category.subtitle.localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: appLanguage == .hebrew ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .liquidGlass(cornerRadius: 14, isHovered: isHovered, style: .card)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Component Helpers

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(style: .card)
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    var isLoading: Bool = false
    var customIcon: AnyView? = nil

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            if let customIcon {
                customIcon
                    .frame(width: 24)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle.localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityLabel(Text(title.localized(appLanguage)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .padding(4)
            }
        }
    }
}

struct SettingsCheckbox: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isHovered = false

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle.localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(Text(title.localized(appLanguage)))
        .accessibilityHint(Text(subtitle.localized(appLanguage)))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .padding(4)
            }
        }
    }
}

struct SettingsPicker: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var selection: LogLevel

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle.localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $selection) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.rawValue.localized(appLanguage)).tag(level)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 100)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .padding(4)
            }
        }
    }
}

struct SettingsLanguagePicker: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var selection: AppLanguage

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle.localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button { selection = .english } label: {
                    Text("English")
                        .font(.system(size: 11, weight: selection == .english ? .bold : .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selection == .english ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if selection == .english {
                                Capsule().fill(Color.primary.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)

                Button { selection = .hebrew } label: {
                    Text("עברית")
                        .font(.system(size: 11, weight: selection == .hebrew ? .bold : .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selection == .hebrew ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if selection == .hebrew {
                                Capsule().fill(Color.primary.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)

                Button { selection = .auto } label: {
                    Text("System".localized(appLanguage))
                        .font(.system(size: 11, weight: selection == .auto ? .bold : .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selection == .auto ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if selection == .auto {
                                Capsule().fill(Color.primary.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .padding(4)
            }
        }
    }
}

struct SettingsStepper: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle.localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(String(format: "%.1f%@", value, unit))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 42, alignment: .trailing)

                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .padding(4)
            }
        }
    }
}

// MARK: - Feature Tour Animated Carousel Component

struct SettingsFeatureTourSection: View {
    @Binding var showingOnboarding: Bool
    @ObservedObject private var desktopToggleManager = DesktopToggleManager.shared
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var activeSlideIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var isHovering: Bool = false

    private var slides: [OBSlide] {
        _ = desktopToggleManager.hotkey
        return OBSlide.all(for: appLanguage).filter { $0.id != 7 && $0.id != 8 }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            if !isHovering {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    activeSlideIndex = (activeSlideIndex + 1) % slides.count
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with dot indicator & controls
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.yellow)

                Text("Feature Guide".localized(appLanguage))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Replay Tour Button (styled like control buttons)
                Button {
                    showingOnboarding = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Replay Tour".localized(appLanguage))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Replay the onboarding walkthrough and setup guide".localized(appLanguage))

                // Dot indicators
                HStack(spacing: 4) {
                    ForEach(0..<slides.count, id: \.self) { idx in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                activeSlideIndex = idx
                            }
                            startTimer()
                        } label: {
                            Circle()
                                .fill(idx == activeSlideIndex ? Color.accentColor : Color.primary.opacity(0.25))
                                .frame(width: idx == activeSlideIndex ? 7 : 5, height: idx == activeSlideIndex ? 7 : 5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 4)

            // Vertical mini-card: illustration on top, text centered below
            ZStack {
                let slide = slides[activeSlideIndex]
                VStack(spacing: 0) {
                    // Illustration canvas
                    ZStack {
                        slide.illustration
                    }
                    .padding(.top, 6)
                    .scaleEffect(slide.id == 0 ? 0.74 : (slide.id == 6 ? 0.80 : 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 194)
                    .clipped()

                    // Keep the caption distinct when animated content moves near it.
                    VStack(spacing: 0) {
                        Text(slide.headline)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .liquidGlass(cornerRadius: 14, style: .card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onHover { hovering in
                    isHovering = hovering
                }
                .id(activeSlideIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
            .clipped()
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Notch Icon

/// A small Canvas-drawn icon that depicts the MacBook notch:
/// a screen outline with a rounded rectangular cutout at the top centre.
struct NotchIconView: View {
    var color: Color = .accentColor

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height

            // Screen body outline
            let screenRect = CGRect(x: 1, y: 2, width: w - 2, height: h - 4)
            let screenPath = Path(roundedRect: screenRect, cornerRadius: 2.5)
            ctx.stroke(screenPath, with: .color(color), style: StrokeStyle(lineWidth: 1.5))

            // Notch fill — small pill sitting at the top centre of the screen
            let notchW: CGFloat = w * 0.42
            let notchH: CGFloat = 4.5
            let notchRect = CGRect(
                x: (w - notchW) / 2,
                y: 2,
                width: notchW,
                height: notchH
            )
            let notchPath = Path(roundedRect: notchRect, cornerRadius: 2)
            ctx.fill(notchPath, with: .color(color))
        }
        .frame(width: 22, height: 15)
    }
}

// MARK: - Notification Event Checkbox

struct NotificationEventCheckbox: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var soundIsOn: Binding<Bool>? = nil
    var soundName: Binding<String>? = nil
    var quietBinding: Binding<Bool>? = nil
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Checkbox + Title & Subtitle spanning full width
            Button {
                isOn.toggle()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isOn ? Color.accentColor : .secondary)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.localized(appLanguage))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(subtitle.localized(appLanguage))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Row 2: Sound Controls & Sub-options when event is enabled
            if isOn {
                VStack(alignment: .leading, spacing: 6) {
                    if let soundBinding = soundIsOn {
                        HStack(spacing: 8) {
                            Text("Sound".localized(appLanguage))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.secondary)

                            if let nameBinding = soundName, soundBinding.wrappedValue {
                                SoundPickerButton(
                                    selectedSoundName: nameBinding,
                                    appLanguage: appLanguage,
                                    fontSize: 10.5,
                                    horizontalPadding: 6,
                                    verticalPadding: 3,
                                    cornerRadius: 5
                                )
                                .help("Select Sound".localized(appLanguage))
                            }

                            Button {
                                soundBinding.wrappedValue.toggle()
                                if soundBinding.wrappedValue, let nameBinding = soundName {
                                    WindowManager.shared.previewSound(named: nameBinding.wrappedValue)
                                }
                            } label: {
                                Image(systemName: soundBinding.wrappedValue ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(soundBinding.wrappedValue
                                        ? Color.accentColor.opacity(0.85)
                                        : Color.secondary.opacity(0.4))
                                    .frame(width: 22, height: 22)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(soundBinding.wrappedValue ? "Sound on for this event".localized(appLanguage) : "Sound off for this event".localized(appLanguage))

                            Spacer(minLength: 0)
                        }
                    }

                    if let quiet = quietBinding {
                        Button {
                            quiet.wrappedValue.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: quiet.wrappedValue ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(quiet.wrappedValue ? Color.accentColor : .secondary)
                                    .font(.system(size: 11))
                                Text("Quiet when already in place".localized(appLanguage))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Silent banner without sound when window is already in position".localized(appLanguage))
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, 24)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Custom Web Apps Management View

struct CustomWebAppsManagementView: View {
    @ObservedObject var manager: WindowManager
    let appLanguage: AppLanguage
    @State private var customBundleIDInput: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PWAs (Chrome, Safari Web Apps), Electron apps (Slack, Discord, Notion), and Web Browsers are detected automatically. You can also designate specific apps as web apps below.".localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Add from running apps
                    let runningApps = NSWorkspace.shared.runningApplications
                        .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
                        .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

                    if !runningApps.isEmpty {
                        Menu {
                            ForEach(runningApps, id: \.processIdentifier) { app in
                                if let bID = app.bundleIdentifier {
                                    let isCustom = manager.store.customWebAppBundleIDs.contains(bID)
                                    let isAuto = WebAppDetector.shared.isWebApp(app)
                                    Button {
                                        manager.toggleCustomWebApp(bundleID: bID)
                                    } label: {
                                        HStack {
                                            Text(app.localizedName ?? bID)
                                            if isCustom || isAuto {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.app")
                                Text("Add Running App".localized(appLanguage))
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .padding(.vertical, 2)
                    }

                    // Textfield to add manual bundle ID
                    HStack(spacing: 6) {
                        TextField("Enter bundle identifier (e.g. com.example.app)".localized(appLanguage), text: $customBundleIDInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onSubmit {
                                addManualBundleID()
                            }

                        Button("Add".localized(appLanguage)) {
                            addManualBundleID()
                        }
                        .controlSize(.small)
                        .disabled(customBundleIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // List of custom web apps
                    if manager.store.customWebAppBundleIDs.isEmpty {
                        Text("No custom web apps added yet".localized(appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 2)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(Array(manager.store.customWebAppBundleIDs).sorted(), id: \.self) { bID in
                                HStack(spacing: 8) {
                                    AppIconView(bundleID: bID)
                                        .frame(width: 16, height: 16)

                                    let appName: String = {
                                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bID) {
                                            return FileManager.default.displayName(atPath: url.path)
                                        }
                                        return bID
                                    }()

                                    Text(appName)
                                        .font(.system(size: 11, weight: .medium))

                                    Text("(\(bID))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button {
                                        manager.toggleCustomWebApp(bundleID: bID)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Custom Web Apps".localized(appLanguage))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    if !manager.store.customWebAppBundleIDs.isEmpty {
                        Text("\(manager.store.customWebAppBundleIDs.count)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func addManualBundleID() {
        let trimmed = customBundleIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        manager.toggleCustomWebApp(bundleID: trimmed)
        customBundleIDInput = ""
    }
}

// MARK: - Menu Bar Icon Settings Section

struct MenuBarIconSettingsSection: View {
    let appLanguage: AppLanguage
    let themeColor: ThemeColor
    @ObservedObject private var iconManager = MenuBarIconManager.shared

    var body: some View {
        SettingsSection(title: "Menu Bar Icon Style".localized(appLanguage), icon: "menubar.rectangle") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Choose the resting and active icons shown in the macOS status bar".localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    // Test dynamic animation button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            iconManager.triggerActionState(minDuration: 1.0)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: iconManager.isActionActive ? "sparkles" : "play.fill")
                                .font(.system(size: 10))
                            Text("Test Dynamic Action".localized(appLanguage))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

            // Presets Grid
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(MenuBarIconPreset.allCases) { preset in
                    let isSelected = iconManager.selectedPreset == preset
                    let displayColor = iconManager.matchThemeColor ? (themeColor.color(seed: 0)) : Color.primary

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            if preset == .customImage && iconManager.customImagePath.isEmpty {
                                iconManager.pickCustomImage()
                            } else {
                                iconManager.selectedPreset = preset
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            // Dual Icon Preview Area
                            HStack(spacing: 8) {
                                // Resting icon preview
                                VStack(spacing: 2) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.primary.opacity(0.04))
                                            .frame(width: 28, height: 24)

                                        if preset == .customImage, !iconManager.customImagePath.isEmpty,
                                           let img = NSImage(contentsOfFile: iconManager.customImagePath) {
                                            Image(nsImage: img)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: preset == .customSymbol ? (iconManager.customRestingSymbol.isEmpty ? preset.defaultRestingSymbol : iconManager.customRestingSymbol) : preset.defaultRestingSymbol)
                                                .font(.system(size: 13))
                                                .foregroundStyle(displayColor)
                                        }
                                    }
                                    Text("Resting".localized(appLanguage))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }

                                // Action icon preview
                                VStack(spacing: 2) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(iconManager.isActionActive && isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                            .frame(width: 28, height: 24)

                                        if preset == .customImage, !iconManager.customImagePath.isEmpty,
                                           let img = NSImage(contentsOfFile: iconManager.customImagePath) {
                                            Image(nsImage: img)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: preset == .customSymbol ? (iconManager.customActionSymbol.isEmpty ? preset.defaultActionSymbol : iconManager.customActionSymbol) : preset.defaultActionSymbol)
                                                .font(.system(size: 13))
                                                .foregroundStyle(displayColor)
                                                .scaleEffect(iconManager.isActionActive && isSelected ? 1.15 : 1.0)
                                        }
                                    }
                                    Text("Action".localized(appLanguage))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 4)

                            Text(preset.displayName.localized(appLanguage))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)

            // Custom Symbol Configuration (when customSymbol is selected)
            if iconManager.selectedPreset == .customSymbol {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resting SF Symbol".localized(appLanguage))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                TextField("macwindow.on.rectangle", text: $iconManager.customRestingSymbol)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                                if let _ = NSImage(systemSymbolName: iconManager.customRestingSymbol, accessibilityDescription: nil) {
                                    Image(systemName: iconManager.customRestingSymbol)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Action SF Symbol".localized(appLanguage))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                TextField("macwindow.fill", text: $iconManager.customActionSymbol)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                                if let _ = NSImage(systemSymbolName: iconManager.customActionSymbol, accessibilityDescription: nil) {
                                    Image(systemName: iconManager.customActionSymbol)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            }

            // Custom Image Configuration (when customImage is selected)
            if iconManager.selectedPreset == .customImage {
                HStack(spacing: 12) {
                    Button {
                        iconManager.pickCustomImage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                            Text("Choose Image File…".localized(appLanguage))
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .controlSize(.small)

                    if !iconManager.customImagePath.isEmpty {
                        Text(URL(fileURLWithPath: iconManager.customImagePath).lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Clear Image".localized(appLanguage)) {
                            iconManager.customImagePath = ""
                            iconManager.selectedPreset = .macWindow
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // Match Accent Theme Color Toggle
            SettingsToggle(
                title: "Match Accent Theme Color",
                subtitle: "Tint menu bar icon with active app theme instead of native monochrome",
                icon: "paintpalette",
                isOn: $iconManager.matchThemeColor
            )
        }
        .padding(14)
        }
    }
}

// MARK: - Menu Bar Icon Nav Row (inside Appearance card)

struct MenuBarIconNavRow: View {
    let appLanguage: AppLanguage
    let themeColor: ThemeColor
    let action: () -> Void

    @ObservedObject private var iconManager = MenuBarIconManager.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {

                // Icon: tinted square matching the notification channel row style
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 32, height: 32)

                // Label + subtitle (currently selected preset name)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar Icon Style".localized(appLanguage))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(iconManager.selectedPreset.displayName.localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Mini resting + action icon preview
                let displayColor = iconManager.matchThemeColor
                    ? themeColor.color(seed: 0)
                    : Color.primary

                HStack(spacing: 4) {
                    ForEach([
                        (iconManager.selectedPreset.defaultRestingSymbol, false),
                        (iconManager.selectedPreset.defaultActionSymbol,  true)
                    ], id: \.0) { symbolName, isAction in
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(isAction ? 0.07 : 0.04))
                                .frame(width: 22, height: 18)
                            Image(systemName: symbolName)
                                .font(.system(size: 10))
                                .foregroundStyle(displayColor)
                        }
                    }
                }

                Image(systemName: appLanguage == .hebrew ? "chevron.left" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Menu Bar Icon Detail View (third-level push panel)

struct MenuBarIconDetailView: View {
    let appLanguage: AppLanguage
    let themeColor: ThemeColor
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack(spacing: 12) {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: appLanguage == .hebrew ? "chevron.right" : "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Appearance".localized(appLanguage))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 16, style: .card)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Menu Bar Icon Style".localized(appLanguage))
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    MenuBarIconSettingsSection(appLanguage: appLanguage, themeColor: themeColor)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Sound Picker Components

struct SoundPickerButton: View {
    @Binding var selectedSoundName: String
    let appLanguage: AppLanguage
    var fontSize: CGFloat = 12
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    var cornerRadius: CGFloat = 6
    var onSelected: ((SystemSound) -> Void)? = nil

    private func stepSound(delta: Int) {
        let all = SystemSound.allCases
        guard !all.isEmpty else { return }
        let currentIndex = all.firstIndex(where: { $0.rawValue == selectedSoundName }) ?? 0
        let newIndex = (currentIndex + delta + all.count) % all.count
        let nextSound = all[newIndex]
        selectedSoundName = nextSound.rawValue
        onSelected?(nextSound)
        nextSound.play()
    }

    var body: some View {
        HStack(spacing: 4) {
            // Previous Sound Stepper
            Button {
                stepSound(delta: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: max(8, fontSize - 3), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: fontSize + 4, height: fontSize + 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Previous sound (‹)".localized(appLanguage))

            // Main Sound Selector & Dropdown Menu
            Menu {
                ForEach(SystemSoundCategory.allCases) { category in
                    Section(category.rawValue.localized(appLanguage)) {
                        ForEach(SystemSound.allCases.filter { $0.category == category }) { sound in
                            Button {
                                selectedSoundName = sound.rawValue
                                onSelected?(sound)
                                sound.play()
                            } label: {
                                HStack {
                                    Text(sound.displayName.localized(appLanguage))
                                    if selectedSoundName == sound.rawValue {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: max(8, fontSize - 3), weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    let display = (SystemSound(rawValue: selectedSoundName)?.displayName ?? selectedSoundName).localized(appLanguage)
                    Text(display)
                        .font(.system(size: fontSize, weight: .medium))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: max(7.5, fontSize - 3.5), weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(width: 165)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 165)

            // Next Sound Stepper
            Button {
                stepSound(delta: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: max(8, fontSize - 3), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: fontSize + 4, height: fontSize + 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Next sound (›)".localized(appLanguage))
        }
        .frame(width: 215, alignment: .trailing)
    }
}

/// Inline shortcut recorder. Shows the live binding and, while recording,
/// captures the next combination that carries at least one modifier.
///
/// The Carbon hotkey is released for the duration via `onBeginRecording`,
/// because a registered hotkey fires ahead of any `NSEvent` monitor — without
/// that, pressing the current shortcut to re-record it would toggle the desktop
/// instead of being captured.
struct SettingsShortcutRecorder: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var hotkey: HotkeyConfig
    var onBeginRecording: () -> Void
    var onEndRecording: () -> Void
    var compact = false
    var isActive = false

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var isHovered = false

    var body: some View {
        Group {
            if compact {
                compactControl
            } else {
                settingsRow
            }
        }
        .onDisappear { stopRecording() }
    }

    private var compactControl: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            HStack(spacing: 5) {
                Text(isRecording ? "…" : HotkeyFormatter.glyphs(for: hotkey))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                if !isRecording {
                    Text("Change…".localized(appLanguage))
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }
            .foregroundStyle(isRecording ? Color.orange : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 58, minHeight: 24)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isRecording
                            ? Color.orange.opacity(0.16)
                            : (isActive ? Color.accentColor.opacity(0.22) : Color.black.opacity(0.30))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isRecording
                            ? Color.orange.opacity(0.9)
                            : (isActive ? Color.accentColor.opacity(0.85) : Color.white.opacity(isHovered ? 0.32 : 0.18)),
                        lineWidth: 0.7
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(
            (isRecording ? "Press a shortcut, or Escape to cancel" : "Change…")
                .localized(appLanguage)
        )
        .accessibilityLabel(Text(title.localized(appLanguage)))
        .accessibilityValue(Text(isRecording ? "Recording" : HotkeyFormatter.glyphs(for: hotkey)))
        .accessibilityHint(
            Text((isRecording ? "Press a shortcut, or Escape to cancel" : "Change…").localized(appLanguage))
        )
        .animation(.easeInOut(duration: 0.15), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    private var settingsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Text((isRecording ? "Press a shortcut, or Escape to cancel" : subtitle).localized(appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(isRecording ? Color.orange : Color.secondary)
            }

            Spacer()

            Text(isRecording ? "…" : HotkeyFormatter.glyphs(for: hotkey))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)))

            Button(isRecording ? "Cancel".localized(appLanguage) : "Change…".localized(appLanguage)) {
                isRecording ? stopRecording() : startRecording()
            }
            .font(.caption)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .padding(4)
            }
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        onBeginRecording()
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {            // Escape cancels, binding untouched
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection([.command, .control, .option, .shift])
            // A bare key would be unusable as a global shortcut, so ignore it
            // and keep listening rather than binding something unreachable.
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
        guard isRecording else { return }
        isRecording = false
        onEndRecording()
    }
}

// MARK: - Notification Channel Nav Row

struct NotificationChannelNavRow: View {
    let channel: NotificationChannel
    let isEnabled: Bool
    let activeCount: Int
    let appLanguage: AppLanguage
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(channel.color.opacity(0.18))
                    if channel == .notch {
                        NotchIconView(color: channel.color)
                    } else {
                        Image(systemName: channel.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(channel.color)
                    }
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.rawValue.localized(appLanguage))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(channel.subtitle.localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Status pill
                HStack(spacing: 4) {
                    if isEnabled {
                        Text("\(activeCount)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(activeCount > 0 ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill((activeCount > 0 ? Color.accentColor : Color.secondary).opacity(0.12))
                            )
                        Text("Active".localized(appLanguage))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Off".localized(appLanguage))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }
                }

                Image(systemName: appLanguage == .hebrew ? "chevron.left" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Notification Channel Detail View

struct NotificationChannelDetailView: View {
    let channel: NotificationChannel
    @ObservedObject var manager: WindowManager
    let appLanguage: AppLanguage
    let focusRequest: NotificationCardFocusRequest?
    let onFocusRequestConsumed: (UUID) -> Void
    let onNavigateToCard: (NotificationChannel, NotificationCardTarget) -> Void
    let onBack: () -> Void

    @AppStorage("showNotchNotification") private var showNotchNotification: Bool = true
    @State private var highlightedCardTarget: NotificationCardTarget? = nil
    @State private var highlightedCardFocusRequestID: UUID? = nil
    @State private var highlightClearTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack(spacing: 12) {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: appLanguage == .hebrew ? "chevron.right" : "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Appearance & Notifications".localized(appLanguage))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 16, style: .card)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    if channel == .notch {
                        NotchIconView(color: channel.color)
                    } else {
                        Image(systemName: channel.icon)
                            .foregroundStyle(channel.color)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(channel.rawValue.localized(appLanguage))
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        // Events Section: distinct interactive cards
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("Events".localized(appLanguage))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                if manager.store.autoSaveEnabled {
                                    eventCard(
                                        icon: "clock.arrow.circlepath",
                                        title: "Auto Layout Restore",
                                        subtitle: "When windows are restored from an auto layout snapshot",
                                        eventType: .fullRestore,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnFullRestore : manager.store.systemNotifyOnFullRestore },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnFullRestore = v) : (manager.store.systemNotifyOnFullRestore = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnFullRestore : manager.store.systemSoundOnFullRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnFullRestore = v) : (manager.store.systemSoundOnFullRestore = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameFullRestore : manager.store.systemSoundNameFullRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameFullRestore = v) : (manager.store.systemSoundNameFullRestore = v); manager.persist() }
                                        )
                                    )

                                    welcomePillSettingsCard

                                    eventCard(
                                        icon: "app.badge.checkmark",
                                        title: "Single App Restore",
                                        subtitle: "When an app is launched or auto-restored",
                                        eventType: .singleRestore,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnSingleRestore : manager.store.systemNotifyOnSingleRestore },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnSingleRestore = v) : (manager.store.systemNotifyOnSingleRestore = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnSingleRestore : manager.store.systemSoundOnSingleRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnSingleRestore = v) : (manager.store.systemSoundOnSingleRestore = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameSingleRestore : manager.store.systemSoundNameSingleRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameSingleRestore = v) : (manager.store.systemSoundNameSingleRestore = v); manager.persist() }
                                        ),
                                        quietBinding: channel == .notch ? Binding(
                                            get: { manager.store.quietSingleRestoreWhenInPlace },
                                            set: { manager.store.quietSingleRestoreWhenInPlace = $0; manager.persist() }
                                        ) : nil
                                    )

                                    eventCard(
                                        icon: "display.2",
                                        title: "Display Connection & Change",
                                        subtitle: "When monitors connect, disconnect, or reconnect",
                                        eventType: .displayChange,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnDisplayChange : manager.store.systemNotifyOnDisplayChange },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnDisplayChange = v) : (manager.store.systemNotifyOnDisplayChange = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnDisplayChange : manager.store.systemSoundOnDisplayChange },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnDisplayChange = v) : (manager.store.systemSoundOnDisplayChange = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameDisplayChange : manager.store.systemSoundNameDisplayChange },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameDisplayChange = v) : (manager.store.systemSoundNameDisplayChange = v); manager.persist() }
                                        )
                                    )

                                    eventCard(
                                        icon: "camera.viewfinder",
                                        title: "Snapshot & App Update",
                                        subtitle: "When apps or layouts are saved, added, or updated",
                                        eventType: .snapshotUpdate,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnSnapshotUpdate : manager.store.systemNotifyOnSnapshotUpdate },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnSnapshotUpdate = v) : (manager.store.systemNotifyOnSnapshotUpdate = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnSnapshotUpdate : manager.store.systemSoundOnSnapshotUpdate },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnSnapshotUpdate = v) : (manager.store.systemSoundOnSnapshotUpdate = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameSnapshotUpdate : manager.store.systemSoundNameSnapshotUpdate },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameSnapshotUpdate = v) : (manager.store.systemSoundNameSnapshotUpdate = v); manager.persist() }
                                        ),
                                        isDisabled: true,
                                        disabledReason: "Unavailable while Auto Layout is on"
                                    )

                                    eventCard(
                                        icon: "keyboard.badge.eye",
                                        title: "Desktop Toggle (⌘D)",
                                        subtitle: "When all windows are hidden or shown via Cmd+D",
                                        eventType: .desktopToggle,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnDesktopToggle : manager.store.systemNotifyOnDesktopToggle },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnDesktopToggle = v) : (manager.store.systemNotifyOnDesktopToggle = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnDesktopToggle : manager.store.systemSoundOnDesktopToggle },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnDesktopToggle = v) : (manager.store.systemSoundOnDesktopToggle = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameDesktopToggle : manager.store.systemSoundNameDesktopToggle },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameDesktopToggle = v) : (manager.store.systemSoundNameDesktopToggle = v); manager.persist() }
                                        )
                                    )
                                } else {
                                    eventCard(
                                        icon: "display.2",
                                        title: "Full Layout Restore",
                                        subtitle: "When all windows are restored to their saved layout",
                                        eventType: .fullRestore,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnFullRestore : manager.store.systemNotifyOnFullRestore },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnFullRestore = v) : (manager.store.systemNotifyOnFullRestore = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnFullRestore : manager.store.systemSoundOnFullRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnFullRestore = v) : (manager.store.systemSoundOnFullRestore = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameFullRestore : manager.store.systemSoundNameFullRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameFullRestore = v) : (manager.store.systemSoundNameFullRestore = v); manager.persist() }
                                        )
                                    )

                                    welcomePillSettingsCard

                                    eventCard(
                                        icon: "app.badge.checkmark",
                                        title: "Single App Restore",
                                        subtitle: "When a single frontmost app or auto-restore fires",
                                        eventType: .singleRestore,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnSingleRestore : manager.store.systemNotifyOnSingleRestore },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnSingleRestore = v) : (manager.store.systemNotifyOnSingleRestore = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnSingleRestore : manager.store.systemSoundOnSingleRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnSingleRestore = v) : (manager.store.systemSoundOnSingleRestore = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameSingleRestore : manager.store.systemSoundNameSingleRestore },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameSingleRestore = v) : (manager.store.systemSoundNameSingleRestore = v); manager.persist() }
                                        ),
                                        quietBinding: channel == .notch ? Binding(
                                            get: { manager.store.quietSingleRestoreWhenInPlace },
                                            set: { manager.store.quietSingleRestoreWhenInPlace = $0; manager.persist() }
                                        ) : nil
                                    )

                                    eventCard(
                                        icon: "display.2",
                                        title: "Display Connection & Change",
                                        subtitle: "When monitors connect, disconnect, or reconnect",
                                        eventType: .displayChange,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnDisplayChange : manager.store.systemNotifyOnDisplayChange },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnDisplayChange = v) : (manager.store.systemNotifyOnDisplayChange = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnDisplayChange : manager.store.systemSoundOnDisplayChange },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnDisplayChange = v) : (manager.store.systemSoundOnDisplayChange = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameDisplayChange : manager.store.systemSoundNameDisplayChange },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameDisplayChange = v) : (manager.store.systemSoundNameDisplayChange = v); manager.persist() }
                                        )
                                    )

                                    eventCard(
                                        icon: "camera.viewfinder",
                                        title: "Snapshot & App Update",
                                        subtitle: "When apps or layouts are saved, added, or updated",
                                        eventType: .snapshotUpdate,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnSnapshotUpdate : manager.store.systemNotifyOnSnapshotUpdate },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnSnapshotUpdate = v) : (manager.store.systemNotifyOnSnapshotUpdate = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnSnapshotUpdate : manager.store.systemSoundOnSnapshotUpdate },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnSnapshotUpdate = v) : (manager.store.systemSoundOnSnapshotUpdate = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameSnapshotUpdate : manager.store.systemSoundNameSnapshotUpdate },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameSnapshotUpdate = v) : (manager.store.systemSoundNameSnapshotUpdate = v); manager.persist() }
                                        )
                                    )

                                    eventCard(
                                        icon: "keyboard.badge.eye",
                                        title: "Desktop Toggle (⌘D)",
                                        subtitle: "When all windows are hidden or shown via Cmd+D",
                                        eventType: .desktopToggle,
                                        isOn: Binding(
                                            get: { channel == .notch ? manager.store.notchNotifyOnDesktopToggle : manager.store.systemNotifyOnDesktopToggle },
                                            set: { v in channel == .notch ? (manager.store.notchNotifyOnDesktopToggle = v) : (manager.store.systemNotifyOnDesktopToggle = v); manager.persist() }
                                        ),
                                        soundIsOn: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundOnDesktopToggle : manager.store.systemSoundOnDesktopToggle },
                                            set: { v in channel == .notch ? (manager.store.notchSoundOnDesktopToggle = v) : (manager.store.systemSoundOnDesktopToggle = v); manager.persist() }
                                        ),
                                        soundName: Binding(
                                            get: { channel == .notch ? manager.store.notchSoundNameDesktopToggle : manager.store.systemSoundNameDesktopToggle },
                                            set: { v in channel == .notch ? (manager.store.notchSoundNameDesktopToggle = v) : (manager.store.systemSoundNameDesktopToggle = v); manager.persist() }
                                        )
                                    )
                                }
                            }
                        }

                        // ── Sound Volume + Library Card (below Events) ───────
                        VStack(alignment: .leading, spacing: 0) {
                            Label("Sound Volume".localized(appLanguage), systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 4)

                            let isAutoVolume: Bool = channel == .notch ? manager.store.notchAutoVolumeBelowSystem : manager.store.systemAutoVolumeBelowSystem
                            VStack(spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { channel == .notch ? manager.store.notchAutoVolumeBelowSystem : manager.store.systemAutoVolumeBelowSystem },
                                    set: { newVal in
                                        if channel == .notch {
                                            manager.store.notchAutoVolumeBelowSystem = newVal
                                        } else {
                                            manager.store.systemAutoVolumeBelowSystem = newVal
                                        }
                                        manager.persist()
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Auto: 20% below system".localized(appLanguage))
                                            .font(.system(size: 13, weight: .medium))
                                        Text("Automatically sets volume to 80% of system level (-20%)".localized(appLanguage))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)
                                .tint(channel.color)

                                if isAutoVolume {
                                    HStack(spacing: 12) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(channel.color)
                                            Text("Fixed at 80% (-20% from macOS master volume)".localized(appLanguage))
                                                .font(.system(size: 11.5, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            let testSound = channel == .notch ? manager.store.notchSoundNameSingleRestore : manager.store.systemSoundNameSingleRestore
                                            let vol = channel == .notch ? manager.effectiveNotchSoundVolume : manager.effectiveSystemSoundVolume
                                            manager.previewSound(named: testSound, volume: vol)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10))
                                                Text("Test".localized(appLanguage))
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(channel.color.opacity(0.12))
                                            )
                                            .foregroundStyle(.primary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Preview volume with current sound".localized(appLanguage))
                                    }
                                    .padding(.top, 2)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                } else {
                                    HStack(spacing: 12) {
                                        let currentVolume: Double = channel == .notch ? manager.store.notchSoundVolume : manager.store.systemSoundVolume
                                        let speakerIcon: String = currentVolume <= 0.01 ? "speaker.slash.fill" : (currentVolume < 0.35 ? "speaker.wave.1.fill" : (currentVolume < 0.7 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"))

                                        Image(systemName: speakerIcon)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(channel.color)
                                            .frame(width: 24)
                                            .animation(.easeInOut(duration: 0.2), value: currentVolume)

                                        Slider(
                                            value: Binding(
                                                get: { channel == .notch ? manager.store.notchSoundVolume : manager.store.systemSoundVolume },
                                                set: { newVal in
                                                    if channel == .notch {
                                                        manager.store.notchSoundVolume = newVal
                                                    } else {
                                                        manager.store.systemSoundVolume = newVal
                                                    }
                                                    manager.persist()
                                                }
                                            ),
                                            in: 0.0...1.0
                                        )
                                        .tint(channel.color)

                                        Text("\(Int(round(currentVolume * 100)))%")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 44, alignment: .trailing)

                                        Button {
                                            let testSound = channel == .notch ? manager.store.notchSoundNameSingleRestore : manager.store.systemSoundNameSingleRestore
                                            let vol = Float(currentVolume)
                                            manager.previewSound(named: testSound, volume: vol)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10))
                                                Text("Test".localized(appLanguage))
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(channel.color.opacity(0.12))
                                            )
                                            .foregroundStyle(.primary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Preview volume with current sound".localized(appLanguage))
                                    }
                                    .padding(.top, 2)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                            .padding(12)
                            .animation(.easeInOut(duration: 0.25), value: isAutoVolume)

                            Divider()
                                .padding(.horizontal, 12)

                            InlineSoundLibraryView(appLanguage: appLanguage)
                                .padding(12)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(style: .card)
                    }
                    .padding(20)
                }
                .onChange(of: focusRequest?.id, initial: true) { _, _ in
                    handleFocusRequest(using: proxy)
                }
                .onDisappear {
                    highlightClearTask?.cancel()
                    highlightClearTask = nil
                }
            }
        }
    }

    private func handleFocusRequest(using proxy: ScrollViewProxy) {
        guard let request = focusRequest, request.channel == channel else { return }

        DispatchQueue.main.async {
            guard focusRequest?.id == request.id else { return }

            highlightClearTask?.cancel()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                proxy.scrollTo(request.target, anchor: .center)
                highlightedCardTarget = request.target
            }
            highlightedCardFocusRequestID = request.id

            onFocusRequestConsumed(request.id)
            highlightClearTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    highlightedCardTarget = nil
                }
                highlightClearTask = nil
            }
        }
    }

    @ViewBuilder
    private var welcomePillSettingsCard: some View {
        if channel == .notch && manager.store.notchNotifyOnFullRestore {
            eventCard(
                icon: "sparkles",
                title: "Welcome Notch Pill",
                subtitle: "Shows on the first eligible restore after launch, for a layout not among the last two completed restores, or when 8 hours have passed since the pill last appeared.",
                eventType: .fullRestore,
                isWelcomeNotchPill: true,
                isOn: Binding(
                    get: { manager.store.welcomeNotchPillEnabled },
                    set: { isEnabled in
                        manager.setWelcomeNotchPillEnabled(isEnabled)
                    }
                ),
                soundIsOn: Binding(
                    get: { manager.store.welcomeNotchPillSoundEnabled },
                    set: { isEnabled in
                        manager.store.welcomeNotchPillSoundEnabled = isEnabled
                        manager.persist()
                    }
                ),
                soundName: Binding(
                    get: { manager.store.welcomeNotchPillSoundName },
                    set: { soundName in
                        manager.store.welcomeNotchPillSoundName = soundName
                        manager.persist()
                    }
                ),
                previewAction: {
                    manager.showWelcomeNotchPillDirect(
                        subtitle: "",
                        playSound: true
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func eventCard(
        icon: String,
        title: String,
        subtitle: String,
        eventType: WindowManager.NotificationEventType,
        isWelcomeNotchPill: Bool = false,
        isOn: Binding<Bool>,
        soundIsOn: Binding<Bool>,
        soundName: Binding<String>,
        previewAction: (() -> Void)? = nil,
        quietBinding: Binding<Bool>? = nil,
        isDisabled: Bool = false,
        disabledReason: String? = nil
    ) -> some View {
        let cardTarget = isWelcomeNotchPill
            ? NotificationCardTarget.welcomePill
            : NotificationCardTarget.event(for: eventType)

        EventCardView(
            icon: icon,
            title: title,
            subtitle: subtitle,
            eventType: eventType,
            isWelcomeNotchPill: isWelcomeNotchPill,
            cardTarget: cardTarget,
            isHighlighted: highlightedCardTarget == cardTarget,
            focusAnimationRequestID: highlightedCardTarget == cardTarget ? highlightedCardFocusRequestID : nil,
            channel: channel,
            manager: manager,
            appLanguage: appLanguage,
            isOn: isOn,
            soundIsOn: soundIsOn,
            soundName: soundName,
            previewAction: previewAction,
            onNavigateToCard: onNavigateToCard,
            quietBinding: quietBinding,
            isDisabled: isDisabled,
            disabledReason: disabledReason
        )
        .id(cardTarget)
    }
}

// MARK: - Event Card View (with hover preview & clean sound management)

private struct EventCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let eventType: WindowManager.NotificationEventType
    let isWelcomeNotchPill: Bool
    let cardTarget: NotificationCardTarget
    let isHighlighted: Bool
    let focusAnimationRequestID: UUID?
    let channel: NotificationChannel
    @ObservedObject var manager: WindowManager
    let appLanguage: AppLanguage
    @Binding var isOn: Bool
    @Binding var soundIsOn: Bool
    @Binding var soundName: String
    let previewAction: (() -> Void)?
    let onNavigateToCard: (NotificationChannel, NotificationCardTarget) -> Void
    var quietBinding: Binding<Bool>?
    let isDisabled: Bool
    let disabledReason: String?

    @AppStorage("masterNotificationsEnabled") private var masterNotificationsEnabled: Bool = true
    @AppStorage("showNotchNotification") private var showNotchNotification: Bool = true

    @State private var isHovered = false
    @State private var hoverWorkItem: DispatchWorkItem?
    @State private var attemptedConflictingSound = false
    @State private var focusFlipAngle: Double = 0
    @State private var focusFlipTask: Task<Void, Never>?

    // Event-specific accent color for distinct visual differentiation
    private var eventAccentColor: Color {
        switch eventType {
        case .fullRestore:     return Color.indigo
        case .singleRestore:   return Color.teal
        case .displayChange:   return Color.orange
        case .snapshotUpdate:  return Color.purple
        case .desktopToggle:   return Color.pink
        case .permissionWarning: return Color.red
        }
    }

    private var activeColor: Color {
        channel == .notch ? eventAccentColor : channel.color
    }

    private var otherChannel: NotificationChannel {
        channel == .notch ? .system : .notch
    }

    private func channelNotificationsAreEnabled(_ channel: NotificationChannel) -> Bool {
        channel == .notch ? showNotchNotification : manager.store.showSystemNotification
    }

    private func eventNotificationsAreEnabled(in channel: NotificationChannel) -> Bool {
        switch eventType {
        case .fullRestore:
            return channel == .notch
                ? manager.store.notchNotifyOnFullRestore
                : manager.store.systemNotifyOnFullRestore
        case .singleRestore:
            return channel == .notch
                ? manager.store.notchNotifyOnSingleRestore
                : manager.store.systemNotifyOnSingleRestore
        case .displayChange:
            return channel == .notch
                ? manager.store.notchNotifyOnDisplayChange
                : manager.store.systemNotifyOnDisplayChange
        case .snapshotUpdate:
            return channel == .notch
                ? manager.store.notchNotifyOnSnapshotUpdate
                : manager.store.systemNotifyOnSnapshotUpdate
        case .desktopToggle:
            return channel == .notch
                ? manager.store.notchNotifyOnDesktopToggle
                : manager.store.systemNotifyOnDesktopToggle
        case .permissionWarning:
            return false
        }
    }

    private var currentNotificationRouteIsActive: Bool {
        guard masterNotificationsEnabled,
              channelNotificationsAreEnabled(channel),
              isOn else {
            return false
        }

        if isWelcomeNotchPill {
            return channel == .notch && eventNotificationsAreEnabled(in: .notch)
        }

        return eventNotificationsAreEnabled(in: channel)
    }

    private var currentNotificationRouteWillBeActiveWhenEnabled: Bool {
        guard !isDisabled,
              masterNotificationsEnabled,
              channelNotificationsAreEnabled(channel) else {
            return false
        }

        if isWelcomeNotchPill {
            return channel == .notch && eventNotificationsAreEnabled(in: .notch)
        }

        return true
    }

    private var otherChannelRouteIsActive: Bool {
        masterNotificationsEnabled &&
            channelNotificationsAreEnabled(otherChannel) &&
            eventNotificationsAreEnabled(in: otherChannel)
    }

    private func soundPreferenceIsEnabled(in channel: NotificationChannel) -> Bool {
        switch eventType {
        case .fullRestore:
            if channel == .notch {
                return manager.store.notchSoundOnFullRestore ||
                    (manager.store.welcomeNotchPillEnabled && manager.store.welcomeNotchPillSoundEnabled)
            }
            return manager.store.systemSoundOnFullRestore
        case .singleRestore:
            return channel == .notch
                ? manager.store.notchSoundOnSingleRestore
                : manager.store.systemSoundOnSingleRestore
        case .displayChange:
            return channel == .notch
                ? manager.store.notchSoundOnDisplayChange
                : manager.store.systemSoundOnDisplayChange
        case .snapshotUpdate:
            return channel == .notch
                ? manager.store.notchSoundOnSnapshotUpdate
                : manager.store.systemSoundOnSnapshotUpdate
        case .desktopToggle:
            return channel == .notch
                ? manager.store.notchSoundOnDesktopToggle
                : manager.store.systemSoundOnDesktopToggle
        case .permissionWarning:
            return false
        }
    }

    private var currentRouteSoundPreferenceIsEnabled: Bool {
        if isWelcomeNotchPill {
            return soundIsOn
        }

        return soundPreferenceIsEnabled(in: channel)
    }

    private var welcomePillDisablesDisplayChange: Bool {
        eventType == .displayChange && manager.store.welcomeNotchPillEnabled
    }

    private var isEffectivelyDisabled: Bool {
        isDisabled || welcomePillDisablesDisplayChange
    }

    private var effectiveDisabledReason: String? {
        if isDisabled { return disabledReason }
        return welcomePillDisablesDisplayChange
            ? "Unavailable while Welcome Notch Pill is on"
            : nil
    }

    private var currentRouteHasSound: Bool {
        currentNotificationRouteIsActive && soundIsOn
    }

    private var otherChannelSoundIsOn: Bool {
        otherChannelRouteIsActive && soundPreferenceIsEnabled(in: otherChannel)
    }

    private var eventToggleBinding: Binding<Bool> {
        Binding(
            get: { self.isOn },
            set: { isEnabled in
                guard isEnabled != self.isOn else { return }

                guard isEnabled else {
                    self.isOn = false
                    self.attemptedConflictingSound = false
                    return
                }

                let createsSoundConflict = self.currentNotificationRouteWillBeActiveWhenEnabled &&
                    self.otherChannelSoundIsOn &&
                    self.currentRouteSoundPreferenceIsEnabled

                self.isOn = true

                if createsSoundConflict {
                    self.muteCurrentRouteSoundPreferences()
                    self.attemptedConflictingSound = true
                } else {
                    self.attemptedConflictingSound = false
                }
            }
        )
    }

    private func muteCurrentRouteSoundPreferences() {
        soundIsOn = false

        // The welcome pill can also sound on full restores, so it belongs to
        // the same notch-side route when that route is being activated.
        if !isWelcomeNotchPill,
           eventType == .fullRestore,
           channel == .notch,
           manager.store.welcomeNotchPillEnabled,
           manager.store.welcomeNotchPillSoundEnabled {
            manager.store.welcomeNotchPillSoundEnabled = false
            manager.persist()
        }
    }

    private var otherChannelName: String {
        return otherChannel.rawValue.localized(appLanguage)
    }

    private var conflictingCardTarget: NotificationCardTarget {
        if otherChannel == .notch,
           manager.store.welcomeNotchPillEnabled,
           manager.store.welcomeNotchPillSoundEnabled,
           !manager.store.notchSoundOnFullRestore,
           case .fullRestore = eventType {
            return .welcomePill
        }

        return NotificationCardTarget.event(for: eventType)
    }

    private var conflictActionTitle: String {
        let isolatedChannelName = "\u{2068}\(otherChannelName)\u{2069}"
        return String(
            format: "Go to %@ settings…".localized(appLanguage),
            isolatedChannelName
        )
    }

    private func animateFocusFlipFlop() {
        focusFlipTask?.cancel()
        focusFlipTask = Task { @MainActor in
            var resetTransaction = Transaction(animation: nil)
            resetTransaction.disablesAnimations = true
            withTransaction(resetTransaction) {
                focusFlipAngle = 0
            }

            await Task.yield()
            guard !Task.isCancelled else { return }

            withAnimation(.smooth(duration: 0.34)) {
                focusFlipAngle = 180
            }
            try? await Task.sleep(nanoseconds: 360_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.smooth(duration: 0.34)) {
                focusFlipAngle = 0
            }
        }
    }

    private var shouldShowSoundConflictWarning: Bool {
        !isEffectivelyDisabled &&
            currentNotificationRouteIsActive &&
            otherChannelSoundIsOn &&
            (currentRouteHasSound || attemptedConflictingSound)
    }

    private var soundConflictMessage: String {
        let isolatedChannelName = "\u{2068}\(otherChannelName)\u{2069}"
        return String(
            format: "This event already has sound enabled for %@. Turn it off there to use sound here.".localized(appLanguage),
            isolatedChannelName
        )
    }

    // The card's border and shadow, typed. Inline in `body` as nested ternaries of untyped
    // literals, Swift 6.4 (Xcode 27) could not type-check `body` in reasonable time.
    private var isLifted: Bool { isHovered && isOn && !isEffectivelyDisabled }

    private var borderColor: Color {
        if isHighlighted { return Color.orange.opacity(0.9) }
        if isEffectivelyDisabled { return Color.black.opacity(0.15) }
        if isHovered && isOn { return activeColor.opacity(0.4) }
        return isOn ? activeColor.opacity(0.15) : Color.primary.opacity(0.06)
    }

    private var borderWidth: CGFloat {
        if isHighlighted { return 1.8 }
        return isLifted ? 1.4 : 1.0
    }

    private var shadowColor: Color {
        if isHighlighted { return Color.orange.opacity(0.38) }
        return isLifted ? activeColor.opacity(0.16) : Color.black.opacity(isEffectivelyDisabled ? 0.0 : 0.03)
    }

    private var shadowRadius: CGFloat {
        if isHighlighted { return 15 }
        return isLifted ? 8 : 2
    }

    private var shadowY: CGFloat {
        if isHighlighted { return 2 }
        return isLifted ? 3 : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: icon + title + subtitle + toggle
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(activeColor.opacity(isOn ? (isHovered ? 0.22 : 0.16) : 0.07))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOn ? activeColor : Color.secondary.opacity(0.5))
                        .shadow(color: (isHovered && isOn) ? activeColor.opacity(0.4) : .clear, radius: 4)
                }
                .frame(width: 32, height: 32)
                .scaleEffect(isHovered && isOn ? 1.05 : 1.0)
                .animation(.spring(response: 0.25), value: isHovered)
                .animation(.spring(response: 0.25), value: isOn)
                .opacity(isEffectivelyDisabled ? 0.24 : 1.0)
                .grayscale(isEffectivelyDisabled ? 1.0 : 0.0)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title.localized(appLanguage))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOn ? .primary : .secondary)

                        // Live preview hint badge (shows on hover)
                        if isHovered && isOn {
                            HStack(spacing: 3) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Live Preview".localized(appLanguage))
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(activeColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(activeColor.opacity(0.12))
                            )
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                    .opacity(isEffectivelyDisabled ? 0.24 : 1.0)
                    .grayscale(isEffectivelyDisabled ? 1.0 : 0.0)

                    Text(subtitle.localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(isEffectivelyDisabled ? 0.24 : 1.0)
                        .grayscale(isEffectivelyDisabled ? 1.0 : 0.0)

                    if isEffectivelyDisabled, let effectiveDisabledReason {
                        Label(effectiveDisabledReason.localized(appLanguage), systemImage: "info.circle")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(Text(effectiveDisabledReason.localized(appLanguage)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isOn)

                Spacer(minLength: 8)

                Toggle("", isOn: eventToggleBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .accessibilityLabel(Text(title.localized(appLanguage)))
                    .accessibilityHint(Text(subtitle.localized(appLanguage)))
                    .disabled(isEffectivelyDisabled)
                    .opacity(isEffectivelyDisabled ? 0.24 : 1.0)
                    .grayscale(isEffectivelyDisabled ? 1.0 : 0.0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Sleek grouped sound controls container (when event is enabled)
            if isOn {
                VStack(spacing: 8) {
                    // Sound picker row
                    HStack(spacing: 10) {
                        Button {
                            if !soundIsOn && currentNotificationRouteIsActive && otherChannelSoundIsOn {
                                withAnimation(.spring(response: 0.25)) {
                                    attemptedConflictingSound = true
                                }
                                return
                            }

                            withAnimation(.spring(response: 0.25)) {
                                soundIsOn.toggle()
                                attemptedConflictingSound = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: soundIsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(soundIsOn ? "Sound".localized(appLanguage) : "Muted".localized(appLanguage))
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundStyle(soundIsOn ? activeColor : Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(soundIsOn ? activeColor.opacity(0.12) : Color.primary.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                        .help(soundIsOn ? "Sound on for this event".localized(appLanguage) : "Sound off for this event".localized(appLanguage))

                        Spacer()

                        if soundIsOn {
                            HStack(spacing: 6) {
                                SoundPickerButton(
                                    selectedSoundName: $soundName,
                                    appLanguage: appLanguage,
                                    fontSize: 11.5,
                                    horizontalPadding: 8,
                                    verticalPadding: 4,
                                    cornerRadius: 6
                                )

                                // Quick sound test button right in the row
                                Button {
                                    let vol = channel == .notch ? manager.effectiveNotchSoundVolume : manager.effectiveSystemSoundVolume
                                    manager.previewSound(named: soundName, volume: vol)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(activeColor)
                                }
                                .buttonStyle(.plain)
                                .help("Test sound".localized(appLanguage))
                            }
                        }
                    }

                    if shouldShowSoundConflictWarning {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.orange)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(soundConflictMessage)
                                    .font(.system(size: 10.5))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    onNavigateToCard(otherChannel, conflictingCardTarget)
                                } label: {
                                    Text(conflictActionTitle)
                                        .underline()
                                        .foregroundStyle(Color.orange)
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 10.5, weight: .semibold))
                                .accessibilityHint(Text("Jumps to and highlights the conflicting sound setting.".localized(appLanguage)))
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .foregroundStyle(Color.orange)
                        .padding(.top, 1)
                    }

                    // Quiet when already in place option
                    if let quiet = quietBinding {
                        Divider().opacity(0.2)

                        Button {
                            quiet.wrappedValue.toggle()
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: quiet.wrappedValue ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(quiet.wrappedValue ? activeColor : .secondary)
                                    .font(.system(size: 13))
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Quiet when already in place".localized(appLanguage))
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("Silent banner without sound when window is already in position".localized(appLanguage))
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .disabled(isEffectivelyDisabled)
                .opacity(isEffectivelyDisabled ? 0.24 : 1.0)
                .grayscale(isEffectivelyDisabled ? 1.0 : 0.0)
            }
        }
        .disabled(isEffectivelyDisabled)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isEffectivelyDisabled ? 0.35 : (isHovered ? 0.85 : 0.65)))
                if isEffectivelyDisabled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        .offset(y: (isHovered && isOn && !isEffectivelyDisabled) ? -1.5 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOn)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: soundIsOn)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .onChange(of: focusAnimationRequestID, initial: true) { _, requestID in
            guard requestID != nil else {
                focusFlipTask?.cancel()
                focusFlipTask = nil
                var resetTransaction = Transaction(animation: nil)
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    focusFlipAngle = 0
                }
                return
            }
            animateFocusFlipFlop()
        }
        .onHover { hovering in
            guard !isEffectivelyDisabled else {
                isHovered = false
                hoverWorkItem?.cancel()
                return
            }

            isHovered = hovering
            hoverWorkItem?.cancel()
            guard hovering && isOn else { return }
            // Wait for a short hover before showing the card's live preview.
            let work = DispatchWorkItem {
                if let previewAction {
                    previewAction()
                } else {
                    manager.previewChannelNotification(channel: channel, eventType: eventType)
                }
            }
            hoverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
        .onChange(of: isEffectivelyDisabled) { _, disabled in
            guard disabled else { return }
            isHovered = false
            hoverWorkItem?.cancel()
            hoverWorkItem = nil
        }
        .onDisappear {
            focusFlipTask?.cancel()
            focusFlipTask = nil
        }
        .modifier(FocusCardFlipModifier(angle: focusFlipAngle))
    }
}

private struct FocusCardFlipModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .minimalVisualAnimations()
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .fullVisualAnimations()
    }
}

// MARK: - Inline Sound Library Section (used inside each channel detail view)

struct InlineSoundLibraryView: View {
    let appLanguage: AppLanguage

    @State private var selectedCategory: SystemSoundCategory? = nil
    @State private var activePlayingSound: String? = nil
    @State private var playingTimer: Timer? = nil

    private var filteredSounds: [SystemSound] {
        let categories: [SystemSoundCategory]
        if let selectedCategory {
            categories = [selectedCategory]
        } else {
            categories = [.meme] + SystemSoundCategory.allCases.filter { $0 != .meme }
        }

        return categories.flatMap { category in
            SystemSound.allCases.filter { $0.category == category }
        }
    }

    private func playSound(_ sound: SystemSound) {
        activePlayingSound = sound.rawValue
        sound.play()
        playingTimer?.invalidate()
        playingTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { _ in
            DispatchQueue.main.async {
                if activePlayingSound == sound.rawValue {
                    activePlayingSound = nil
                }
            }
        }
    }

    private func playRandomSound() {
        let pool = filteredSounds.isEmpty ? SystemSound.allCases : filteredSounds
        if let random = pool.randomElement() { playSound(random) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Sound Library".localized(appLanguage))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Shuffle button in header
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { playRandomSound() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Random".localized(appLanguage))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Play a random sound (🎲)".localized(appLanguage))
            }
            .padding(.horizontal, 4)

            // Now-playing equalizer indicator
            if activePlayingSound != nil {
                HStack(spacing: 6) {
                    SoundEqualizerWaveView()
                    Text("Playing...".localized(appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: activePlayingSound)
                .padding(.horizontal, 4)
            }

            // Category filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CategoryPill(
                        title: "All Sounds".localized(appLanguage) + " (\(SystemSound.allCases.count))",
                        icon: "sparkles",
                        isSelected: selectedCategory == nil,
                        color: .accentColor
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { selectedCategory = nil }
                    }

                    ForEach(SystemSoundCategory.allCases) { cat in
                        let count = SystemSound.allCases.filter { $0.category == cat }.count
                        let (icon, color): (String, Color) = {
                            switch cat {
                            case .meme: return ("theatermasks.fill", .orange)
                            case .melodic: return ("wand.and.stars", .purple)
                            case .encore: return ("music.quarternote.3", .blue)
                            case .classic: return ("bell.fill", .green)
                            }
                        }()
                        CategoryPill(
                            title: "\(cat.rawValue.localized(appLanguage)) (\(count))",
                            icon: icon,
                            isSelected: selectedCategory == cat,
                            color: color
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { selectedCategory = cat }
                        }
                    }
                }
            }

            // Sound tiles grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(filteredSounds) { sound in
                    SoundboardTile(
                        sound: sound,
                        isPlaying: activePlayingSound == sound.rawValue,
                        appLanguage: appLanguage
                    ) {
                        playSound(sound)
                    }
                }
            }
        }
    }
}

// MARK: - Sound Equalizer Wave View

struct SoundEqualizerWaveView: View {
    @State private var phase: CGFloat = 0.0

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [
            phase > 0.5 ? 14 : 5,
            phase > 0.5 ? 7 : 13,
            phase > 0.5 ? 12 : 6,
            phase > 0.5 ? 6 : 14
        ]
        return pattern[index % pattern.count]
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Soundboard Tile

struct SoundboardTile: View {
    let sound: SystemSound
    let isPlaying: Bool
    let appLanguage: AppLanguage
    let onPlay: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                // Sound Emoji / Icon badge
                ZStack {
                    Circle()
                        .fill(isPlaying ? Color.accentColor : Color.primary.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Text(sound.emoji)
                        .font(.system(size: 16))
                }
                .scaleEffect(isPlaying ? 1.15 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isPlaying)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.displayName.localized(appLanguage))
                        .font(.system(size: 11.5, weight: isPlaying ? .bold : .medium))
                        .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(sound.category.rawValue.localized(appLanguage))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isPlaying {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isPlaying ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.025)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isPlaying ? Color.accentColor.opacity(0.4) : (isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05)), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
