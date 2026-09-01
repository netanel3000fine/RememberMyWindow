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
        case .experimental: return "Cmd+D Desktop toggle & Cmd+Shift+R triggers"
        case .appearance: return "Theme, Liquid Glass, Notch & Notifications"
        case .permissions: return "Accessibility & Location permissions"
        }
    }
}

// MARK: - Settings View (iOS Navigation Stack Style)

struct SettingsView: View {
    @EnvironmentObject var manager: WindowManager
    @ObservedObject var desktopToggleManager = DesktopToggleManager.shared
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("showNotchNotification") private var showNotchNotification: Bool = true
    @AppStorage("playNotificationSound") private var playNotificationSound: Bool = true
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("restoreFocusedAppOnLeftClick") private var restoreFocusedAppOnLeftClick: Bool = true
    @State private var showingLocationAlert = false
    @State private var isTogglingLocation = false
    @State private var selectedCategory: SettingsCategory? = nil
    @State private var hasFinderPerm = false
    @State private var isNotchEventsExpanded = false
    @State private var isSystemEventsExpanded = false
    @State private var showingOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

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
        .frame(width: 480, height: 620)
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
    }

    // MARK: - Root Categories List View

    private var categoriesListView: some View {
        ScrollView {
            VStack(spacing: 18) {
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
                SettingsFeatureTourSection()
                    .padding(.top, 4)

                // App Version Footer
                VStack(spacing: 4) {
                    Text("Version 1.2.0".localized(appLanguage))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }

    // MARK: - Category Detail Sub-Window View

    @ViewBuilder
    private func categoryDetailView(for category: SettingsCategory) -> some View {
        VStack(spacing: 0) {
            // Top iOS Navigation Bar with Back Button
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedCategory = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: appLanguage == .hebrew ? "chevron.right" : "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Settings".localized(appLanguage))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
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

                Divider().padding(.horizontal, 12)

                // Replay onboarding tour
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.purple.opacity(0.15))
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome Tour & Onboarding".localized(appLanguage))
                            .font(.system(size: 13, weight: .semibold))
                        Text("Replay the onboarding walkthrough and setup guide".localized(appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Replay Tour".localized(appLanguage)) {
                        showingOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .sheet(isPresented: $showingOnboarding) {
                    OnboardingView {
                        showingOnboarding = false
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    // MARK: - 2. Restore Settings Content (Full Restore & Single App Restore)

    private var restoreSettingsContent: some View {
        VStack(spacing: 18) {
            // Subcategory 1: Full Restore
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
                            .foregroundStyle(Color.white)
                            .frame(width: 26, height: 26)
                            .background(Color.accentColor, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Front App".localized(appLanguage))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.8))
                            Text("Pin which app comes to the front after a full restore — tap the layers icon on any app row in a saved session.".localized(appLanguage))
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
            }
        }
    }

    // MARK: - 3. Experimental Content (Cmd+D Desktop Toggle & Active App Command Trigger)

    private var experimentalContent: some View {
        VStack(spacing: 18) {
            // Section 1: Cmd+D Desktop Toggle
            SettingsSection(title: "Desktop Toggle (Cmd+D)".localized(appLanguage), icon: "keyboard") {
                VStack(spacing: 0) {
                    SettingsToggle(
                        title: "Desktop Toggle (Cmd+D)",
                        subtitle: "Quickly hide/show all windows across your desktop (disabled for Safari browser)",
                        icon: "keyboard",
                        isOn: $desktopToggleManager.isEnabled
                    )

                    Divider().padding(.horizontal, 12)

                    SettingsToggle(
                        title: "Restore on Cmd+D unhide",
                        subtitle: "Automatically run full layout restore when showing windows using Cmd+D shortcut",
                        icon: "arrow.uturn.backward",
                        isOn: $desktopToggleManager.restoreOnUnhide
                    )
                    .disabled(!desktopToggleManager.isEnabled)
                    .opacity(desktopToggleManager.isEnabled ? 1.0 : 0.45)
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
                                    .foregroundStyle(Color.green.opacity(0.85))
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
                                .foregroundStyle(.green.opacity(0.75))
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
            }
        }
    }

    // MARK: - 5. Appearance Content

    private var appearanceContent: some View {
        SettingsSection(title: "Appearance & Notifications".localized(appLanguage), icon: "paintpalette.fill") {
            VStack(spacing: 0) {
                // ── Notch Notification ──────────────────────────────────────────
                SettingsToggle(
                    title: "Notch Notification",
                    subtitle: "Show layout restore alerts sliding smoothly down from the MacBook notch",
                    icon: "notch.icon.placeholder",
                    isOn: $showNotchNotification,
                    customIcon: AnyView(NotchIconView(color: .accentColor))
                )

                if showNotchNotification {
                    VStack(spacing: 0) {
                        Divider().padding(.horizontal, 12)

                        // Collapsible trigger for Notch events
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isNotchEventsExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                
                                Text("Configure Notch Events".localized(appLanguage))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(isNotchEventsExpanded ? 90 : 0))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if isNotchEventsExpanded {
                            VStack(spacing: 8) {
                                NotificationEventCheckbox(
                                    title: "Full layout restores",
                                    subtitle: "When all windows are restored to their saved layout",
                                    isOn: Binding(
                                        get: { manager.store.notchNotifyOnFullRestore },
                                        set: { manager.store.notchNotifyOnFullRestore = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.notchSoundOnFullRestore },
                                        set: { manager.store.notchSoundOnFullRestore = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.notchSoundNameFullRestore },
                                        set: { manager.store.notchSoundNameFullRestore = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Single app restores",
                                    subtitle: "When a single frontmost app or auto-restore fires",
                                    isOn: Binding(
                                        get: { manager.store.notchNotifyOnSingleRestore },
                                        set: { manager.store.notchNotifyOnSingleRestore = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.notchSoundOnSingleRestore },
                                        set: { manager.store.notchSoundOnSingleRestore = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.notchSoundNameSingleRestore },
                                        set: { manager.store.notchSoundNameSingleRestore = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Display connections & changes",
                                    subtitle: "When monitors connect, disconnect, or reconnect",
                                    isOn: Binding(
                                        get: { manager.store.notchNotifyOnDisplayChange },
                                        set: { manager.store.notchNotifyOnDisplayChange = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.notchSoundOnDisplayChange },
                                        set: { manager.store.notchSoundOnDisplayChange = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.notchSoundNameDisplayChange },
                                        set: { manager.store.notchSoundNameDisplayChange = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Snapshot & app updates",
                                    subtitle: "When apps or layouts are saved, added, or updated",
                                    isOn: Binding(
                                        get: { manager.store.notchNotifyOnSnapshotUpdate },
                                        set: { manager.store.notchNotifyOnSnapshotUpdate = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.notchSoundOnSnapshotUpdate },
                                        set: { manager.store.notchSoundOnSnapshotUpdate = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.notchSoundNameSnapshotUpdate },
                                        set: { manager.store.notchSoundNameSnapshotUpdate = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Desktop toggle (⌘D)",
                                    subtitle: "When all windows are hidden or restored",
                                    isOn: Binding(
                                        get: { manager.store.notchNotifyOnDesktopToggle },
                                        set: { manager.store.notchNotifyOnDesktopToggle = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.notchSoundOnDesktopToggle },
                                        set: { manager.store.notchSoundOnDesktopToggle = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.notchSoundNameDesktopToggle },
                                        set: { manager.store.notchSoundNameDesktopToggle = $0; manager.persist() }
                                    )
                                )
                            }
                            .padding(.leading, 32)
                            .padding(.trailing, 14)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.03))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider().padding(.horizontal, 12)

                // ── macOS System Notifications ─────────────────────────────────
                SettingsToggle(
                    title: "macOS System Notifications",
                    subtitle: "Deliver standard Notification Center banners for layout and display events",
                    icon: "bell.badge.fill",
                    isOn: Binding(
                        get: { manager.store.showSystemNotification },
                        set: { newValue in
                            manager.store.showSystemNotification = newValue
                            if newValue {
                                manager.requestSystemNotificationPermission()
                            }
                            manager.persist()
                        }
                    )
                )

                if manager.store.showSystemNotification {
                    VStack(spacing: 0) {
                        Divider().padding(.horizontal, 12)

                        // Collapsible trigger for System events
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSystemEventsExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                
                                Text("Configure System Events".localized(appLanguage))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(isSystemEventsExpanded ? 90 : 0))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if isSystemEventsExpanded {
                            VStack(spacing: 8) {
                                NotificationEventCheckbox(
                                    title: "Full layout restores",
                                    subtitle: "When all windows are restored to their saved layout",
                                    isOn: Binding(
                                        get: { manager.store.systemNotifyOnFullRestore },
                                        set: { manager.store.systemNotifyOnFullRestore = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.systemSoundOnFullRestore },
                                        set: { manager.store.systemSoundOnFullRestore = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.systemSoundNameFullRestore },
                                        set: { manager.store.systemSoundNameFullRestore = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Single app restores",
                                    subtitle: "When a single frontmost app or auto-restore fires",
                                    isOn: Binding(
                                        get: { manager.store.systemNotifyOnSingleRestore },
                                        set: { manager.store.systemNotifyOnSingleRestore = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.systemSoundOnSingleRestore },
                                        set: { manager.store.systemSoundOnSingleRestore = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.systemSoundNameSingleRestore },
                                        set: { manager.store.systemSoundNameSingleRestore = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Display connections & changes",
                                    subtitle: "When monitors connect, disconnect, or reconnect",
                                    isOn: Binding(
                                        get: { manager.store.systemNotifyOnDisplayChange },
                                        set: { manager.store.systemNotifyOnDisplayChange = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.systemSoundOnDisplayChange },
                                        set: { manager.store.systemSoundOnDisplayChange = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.systemSoundNameDisplayChange },
                                        set: { manager.store.systemSoundNameDisplayChange = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Snapshot & app updates",
                                    subtitle: "When apps or layouts are saved, added, or updated",
                                    isOn: Binding(
                                        get: { manager.store.systemNotifyOnSnapshotUpdate },
                                        set: { manager.store.systemNotifyOnSnapshotUpdate = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.systemSoundOnSnapshotUpdate },
                                        set: { manager.store.systemSoundOnSnapshotUpdate = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.systemSoundNameSnapshotUpdate },
                                        set: { manager.store.systemSoundNameSnapshotUpdate = $0; manager.persist() }
                                    )
                                )

                                NotificationEventCheckbox(
                                    title: "Desktop toggle (⌘D)",
                                    subtitle: "When all windows are hidden or restored",
                                    isOn: Binding(
                                        get: { manager.store.systemNotifyOnDesktopToggle },
                                        set: { manager.store.systemNotifyOnDesktopToggle = $0; manager.persist() }
                                    ),
                                    soundIsOn: Binding(
                                        get: { manager.store.systemSoundOnDesktopToggle },
                                        set: { manager.store.systemSoundOnDesktopToggle = $0; manager.persist() }
                                    ),
                                    soundName: Binding(
                                        get: { manager.store.systemSoundNameDesktopToggle },
                                        set: { manager.store.systemSoundNameDesktopToggle = $0; manager.persist() }
                                    )
                                )
                            }
                            .padding(.leading, 32)
                            .padding(.trailing, 14)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.03))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider().padding(.horizontal, 12)

                // ── Default Notification Sound ────────────────────────────────
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Sound".localized(appLanguage))
                                .font(.system(size: 13, weight: .medium))
                            Text("Default notification alert sound when not overridden".localized(appLanguage))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 14))
                            .frame(width: 24)
                    }

                    Spacer()

                    Menu {
                        ForEach(SystemSoundCategory.allCases) { category in
                            Section(category.rawValue.localized(appLanguage)) {
                                ForEach(SystemSound.allCases.filter { $0.category == category }) { sound in
                                    Button {
                                        manager.store.defaultNotificationSound = sound.rawValue
                                        manager.persist()
                                        sound.play()
                                    } label: {
                                        HStack {
                                            Text(sound.displayName.localized(appLanguage))
                                            if manager.store.defaultNotificationSound == sound.rawValue {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(manager.store.defaultNotificationSound.localized(appLanguage))
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().padding(.horizontal, 12)

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
                                            .foregroundColor(.white)
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

                // ── Menu Bar Icon Style ─────────────────────────────────────────
                MenuBarIconSettingsSection(appLanguage: appLanguage, themeColor: themeColor)
            }
        }
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

                Text("Required for ⌘D Desktop Toggle to collapse and restore Finder windows.".localized(appLanguage))
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

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
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
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var activeSlideIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var isPaused: Bool = false
    @State private var isHovering: Bool = false

    private var slides: [OBSlide] { OBSlide.all(for: appLanguage) }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            if !isPaused && !isHovering {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    activeSlideIndex = (activeSlideIndex + 1) % slides.count
                }
            }
        }
    }

    private func advanceSlide(by delta: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            let count = slides.count
            activeSlideIndex = (activeSlideIndex + delta + count) % count
        }
        startTimer()
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

                // Slider Control Buttons (Prev / Pause / Next)
                HStack(spacing: 6) {
                    Button {
                        advanceSlide(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(lz("Previous Feature"))

                    Button {
                        isPaused.toggle()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isPaused ? Color.accentColor : .secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isPaused ? lz("Play Carousel") : lz("Pause Carousel"))

                    Button {
                        advanceSlide(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(lz("Next Feature"))
                }

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

            // Keep the compact settings card within its 480-point window.
            // The animation remains the focal point, with concise supporting copy alongside it.
            let slide = slides[activeSlideIndex]
            HStack(spacing: 12) {
                // Illustration Container
                ZStack(alignment: .center) {
                    Group {
                        if slide.id == 7 {
                            OBIllustrationSettingsGuide(activeIndex: 0)
                        } else {
                            slide.illustration
                        }
                    }
                    .scaleEffect(0.70, anchor: .center)
                }
                .frame(width: 230, height: 150)
                .clipped()

                // Supporting text stays smaller than the animation and sits beside it.
                VStack(alignment: appLanguage == .hebrew ? .trailing : .leading, spacing: 6) {
                    Text(slide.headline)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .multilineTextAlignment(appLanguage == .hebrew ? .trailing : .leading)
                    Text(slide.body)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(appLanguage == .hebrew ? .trailing : .leading)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 130, alignment: appLanguage == .hebrew ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .liquidGlass(cornerRadius: 14, style: .card)
            .onHover { hovering in
                isHovering = hovering
            }
            .id(activeSlideIndex)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
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
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                isOn.toggle()
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isOn ? Color.accentColor : .secondary)
                        .font(.system(size: 13))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title.localized(appLanguage))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(subtitle.localized(appLanguage))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let soundBinding = soundIsOn {
                HStack(spacing: 4) {
                    if let nameBinding = soundName, soundBinding.wrappedValue && isOn {
                        Menu {
                            ForEach(SystemSoundCategory.allCases) { category in
                                Section(category.rawValue.localized(appLanguage)) {
                                    ForEach(SystemSound.allCases.filter { $0.category == category }) { sound in
                                        Button {
                                            nameBinding.wrappedValue = sound.rawValue
                                            sound.play()
                                        } label: {
                                            HStack {
                                                Text(sound.displayName.localized(appLanguage))
                                                if nameBinding.wrappedValue == sound.rawValue {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(nameBinding.wrappedValue.localized(appLanguage))
                                    .font(.system(size: 10.5, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
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
                                ? (isOn ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.4))
                                : Color.secondary.opacity(0.4))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(soundBinding.wrappedValue ? "Sound on for this event".localized(appLanguage) : "Sound off for this event".localized(appLanguage))
                    .disabled(!isOn)
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar Icon Style".localized(appLanguage))
                            .font(.system(size: 13, weight: .medium))
                        Text("Choose the resting and active icons shown in the macOS status bar".localized(appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(themeColor.color(seed: 0))
                        .font(.system(size: 14))
                        .frame(width: 24)
                }

                Spacer()

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
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

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
            .padding(.leading, 28)

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
                .padding(.leading, 28)
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
                .padding(.leading, 28)
            }

            // Match Accent Theme Color Toggle
            SettingsToggle(
                title: "Match Accent Theme Color",
                subtitle: "Tint menu bar icon with active app theme instead of native monochrome",
                icon: "paintpalette",
                isOn: $iconManager.matchThemeColor
            )
            .padding(.leading, 28)
        }
        .padding(12)
    }
}

