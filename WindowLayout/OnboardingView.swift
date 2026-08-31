import SwiftUI
import Carbon

// MARK: - Root

struct OnboardingView: View {
    var onComplete: () -> Void

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var phase: OnboardingPhase = .languagePicker

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            switch phase {
            case .languagePicker:
                OnboardingLanguageView(selectedLanguage: $appLanguage) {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                        phase = .permissions
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .permissions:
                OnboardingPermissionsView(language: appLanguage) {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                        phase = .guide
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
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
        .frame(width: 560, height: 520)
        .environment(\.layoutDirection, appLanguage == .hebrew ? .rightToLeft : .leftToRight)
    }
}

private enum OnboardingPhase { case languagePicker, permissions, guide }

// MARK: - Phase 1: Language Picker

struct OnboardingLanguageView: View {
    @Binding var selectedLanguage: AppLanguage
    var onContinue: () -> Void

    @State private var hoverContinue = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon glow
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .overlay { Circle().stroke(Color.accentColor.opacity(0.22), lineWidth: 1) }
                    .shadow(color: Color.accentColor.opacity(0.22), radius: 22, x: 0, y: 8)

                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.bottom, 14)

            Text("RememberMyWindows")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("Your window manager".localized(selectedLanguage))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            Text("Choose Your Language".localized(selectedLanguage))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            // Sleek Custom Glass Language List Card — works in Dark Mode & RTL cleanly
            VStack(spacing: 6) {
                languageOptionRow(
                    lang: .auto,
                    title: "System Default".localized(selectedLanguage),
                    subtitle: "Follow System Language".localized(selectedLanguage),
                    iconName: "gearshape.fill",
                    iconColor: .blue
                )
                
                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.3)

                languageOptionRow(
                    lang: .english,
                    title: "English",
                    subtitle: "English",
                    iconName: "globe.americas.fill",
                    iconColor: .indigo
                )

                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.3)

                languageOptionRow(
                    lang: .hebrew,
                    title: "עברית",
                    subtitle: "Hebrew".localized(selectedLanguage),
                    iconName: "globe.europe.africa.fill",
                    iconColor: .orange
                )
            }
            .padding(8)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            )
            .environment(\.layoutDirection, selectedLanguage == .hebrew ? .rightToLeft : .leftToRight)
            .padding(.bottom, 24)

            Button {
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Text(selectedLanguage == .hebrew ? "המשך" : "Continue")
                    Image(systemName: selectedLanguage == .hebrew ? "arrow.left" : "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24).frame(minHeight: 44)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 4)
                .scaleEffect(hoverContinue ? 1.03 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hoverContinue)
            }
            .buttonStyle(.plain)
            .onHover { hoverContinue = $0 }

            Spacer()
        }
        .padding(.horizontal, 60)
    }

    @ViewBuilder
    private func languageOptionRow(lang: AppLanguage, title: String, subtitle: String, iconName: String, iconColor: Color) -> some View {
        let isSelected = selectedLanguage == lang

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedLanguage = lang
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(iconColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Phase 1.5: Accessibility Permissions

struct OnboardingPermissionsView: View {
    let language: AppLanguage
    var onContinue: () -> Void

    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasFinderAutomation = false
    @State private var hoverGrant = false
    @State private var hoverSkip  = false
    @State private var pulseShield = false
    @State private var permissionTimer: Timer?

    private var allGranted: Bool { hasAccessibility && hasFinderAutomation }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Combined shield icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.30), Color.orange.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .overlay { Circle().stroke(Color.orange.opacity(0.25), lineWidth: 1) }
                    .shadow(color: Color.orange.opacity(0.22), radius: 22, x: 0, y: 8)
                    .scaleEffect(pulseShield ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulseShield)

                Image(systemName: allGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(allGranted ? Color.green : Color.orange)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.bottom, 20)

            Text(allGranted
                 ? "Permissions granted".localized(language)
                 : "Permissions Required".localized(language))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(allGranted ? .green : .primary)
                .animation(.easeInOut(duration: 0.3), value: allGranted)

            Text("Two quick permissions let RememberMyWindows do its job properly.".localized(language))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)
                .padding(.top, 8)
                .padding(.bottom, 24)

            // Permission cards
            VStack(spacing: 12) {
                // 1. Finder Automation (first, as user requested)
                permissionCard(
                    icon: "folder.fill",
                    iconColor: .blue,
                    title: "Finder Control".localized(language),
                    description: "Required for the Desktop Toggle — collapses and restores Finder windows.".localized(language),
                    isGranted: hasFinderAutomation,
                    buttonLabel: "Grant Finder Access…".localized(language)
                ) {
                    triggerFinderPermission()
                }

                // 2. Accessibility
                permissionCard(
                    icon: "figure.wave",
                    iconColor: .orange,
                    title: "Accessibility".localized(language),
                    description: "Needed to restore window positions in apps like Chrome, Telegram, etc.".localized(language),
                    isGranted: hasAccessibility,
                    buttonLabel: "Grant Accessibility…".localized(language)
                ) {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    )
                }
            }
            .frame(maxWidth: 440)

            Spacer()

            // Continue / Skip
            if allGranted {
                Button { onContinue() } label: {
                    HStack(spacing: 8) {
                        Text("Continue".localized(language))
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).frame(minHeight: 44)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 4)
                    .scaleEffect(hoverGrant ? 1.03 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hoverGrant)
                }
                .buttonStyle(.plain)
                .onHover { hoverGrant = $0 }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    // If Accessibility not yet granted and it is the missing one, open it
                    if !hasAccessibility {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    } else if !hasFinderAutomation {
                        triggerFinderPermission()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text("Grant Permissions…".localized(language))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).frame(minHeight: 44)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 4)
                    .scaleEffect(hoverGrant ? 1.03 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hoverGrant)
                }
                .buttonStyle(.plain)
                .onHover { hoverGrant = $0 }
            }

            // Skip link
            Button { onContinue() } label: {
                Text("Skip for now".localized(language))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .onHover { hoverSkip = $0 }

            Spacer()
        }
        .padding(.horizontal, 50)
        .onAppear {
            pulseShield = true
            // NOTE: Do NOT call checkFinderPermission here – that would
            // silently fire the macOS Automation dialog before the user sees the UI.
            // Instead, start with false and let the user tap the button.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                let ax = AXIsProcessTrusted()
                if ax != hasAccessibility {
                    withAnimation { hasAccessibility = ax }
                    if ax { closeSystemSettings() }
                }
                // Poll using the SILENT check (no dialog triggered)
                let finder = checkFinderPermissionSilently()
                if finder != hasFinderAutomation {
                    withAnimation { hasFinderAutomation = finder }
                }
            }
        }
        .onDisappear { permissionTimer?.invalidate() }
    }

    // MARK: - Permission Card

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
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(iconColor)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGranted)

            // Text
            VStack(alignment: language == .hebrew ? .trailing : .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isGranted ? .green : .primary)
                    .animation(.easeInOut(duration: 0.2), value: isGranted)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(language == .hebrew ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            // Grant button (custom capsule pill — never truncates with ...)
            if !isGranted {
                Button(action: onTap) {
                    Text(buttonLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(iconColor)
                        .clipShape(Capsule())
                        .shadow(color: iconColor.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isGranted ? Color.green.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Finder Permission Helpers

    /// Triggers the macOS Automation permission dialog for Finder by sending an Apple Event.
    /// Only call this from a user-initiated action (button tap) — it shows the system dialog.
    private func triggerFinderPermission() {
        WindowManager.shared.requestFinderAutomationPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let granted = checkFinderPermissionSilently()
            withAnimation { hasFinderAutomation = granted }
        }
    }

    /// Checks Finder automation permission silently using AEDeterminePermissionToAutomateTarget
    /// with askUserIfNeeded = false.  This NEVER shows the macOS dialog.
    private func checkFinderPermissionSilently() -> Bool {
        guard let finder = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.finder")
                .first else { return false }
        var pid = finder.processIdentifier
        var target = AEAddressDesc()
        let createErr = AECreateDesc(typeKernelProcessID, &pid, MemoryLayout<pid_t>.size, &target)
        guard createErr == noErr else { return false }
        defer { AEDisposeDesc(&target) }
        // askUserIfNeeded = false  →  never prompts, just reads TCC state
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


// MARK: - Phase 2: Guided Tour

struct OnboardingGuideView: View {
    let language: AppLanguage
    var onComplete: () -> Void

    @State private var currentSlide = 0
    @State private var hoverNext = false

    private var slides: [OBSlide] { OBSlide.all(for: language) }
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
                // Dot indicator
                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentSlide ? Color.accentColor : Color.primary.opacity(0.2))
                            .frame(width: i == currentSlide ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSlide)
                    }
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
                        Image(systemName: isLast ? "checkmark" : (language == .hebrew ? "arrow.left" : "arrow.right"))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).frame(minHeight: 44)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 4)
                    .scaleEffect(hoverNext ? 1.03 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hoverNext)
                }
                .buttonStyle(.plain)
                .onHover { hoverNext = $0 }
            }
            .padding(.bottom, 36)
        }
        .environment(\.layoutDirection, language == .hebrew ? .rightToLeft : .leftToRight)
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
                    body: String(format: "Press %@ and every window vanishes — desktop is clean. Press again and they all come back exactly where they were.".localized(lang), HotkeyFormatter.desktopToggleGlyphs),
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
}

struct OBSlideView: View {
    let slide: OBSlide
    let language: AppLanguage

    @State private var settingsActiveIndex = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 20) {
            Spacer()

            if slide.id == 7 {
                OBIllustrationSettingsGuide(activeIndex: settingsActiveIndex)
                    .frame(width: 320, height: 200)
                    .liquidGlass(cornerRadius: 20, style: .card)
                    .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
            } else {
                slide.illustration
                    .frame(width: 320, height: 200)
                    .liquidGlass(cornerRadius: 20, style: .card)
                    .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
            }

            VStack(alignment: language == .hebrew ? .trailing : .leading, spacing: 8) {
                Text(slide.headline)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(language == .hebrew ? .trailing : .leading)

                if slide.id == 7 {
                    Text(getSettingsDescription(for: settingsActiveIndex, lang: language))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(language == .hebrew ? .trailing : .leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(settingsActiveIndex)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                } else {
                    Text(slide.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(language == .hebrew ? .trailing : .leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 150, alignment: language == .hebrew ? .trailing : .leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            if slide.id == 7 {
                timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
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

// MARK: - Illustrations

struct OBIllustrationSave: View {
    @State private var saved = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.65))
                .frame(width: 230, height: 134)

            obWin(x: -58, y: -18, w: 95, h: 72, tint: .accentColor, show: saved)
            obWin(x: 58, y: -14, w: 82, h: 62, tint: .blue, show: saved)
            obWin(x: 0, y: 38, w: 104, h: 48, tint: .purple, show: saved)

            if saved {
                VStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                    Text("Saved")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
                .offset(x: 88, y: -52)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
                saved = true
            }
        }
    }

    @ViewBuilder
    func obWin(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, tint: Color, show: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(tint.opacity(show ? 0.6 : 0.18))
            .overlay { RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(tint.opacity(show ? 0.9 : 0.3), lineWidth: 0.75) }
            .frame(width: w, height: h)
            .offset(x: x, y: y)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: show)
    }
}

struct OBIllustrationLive: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.65))
                .frame(width: 210, height: 130)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    obCell(.accentColor, 72, 42)
                    obCell(.blue, 64, 42)
                }
                HStack(spacing: 4) {
                    obCell(.purple, 52, 36)
                    obCell(.orange, 58, 36)
                    obCell(.green, 26, 36)
                }
            }

            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                    .scaleEffect(pulse ? 1.35 : 1.0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                Text("LIVE").font(.system(size: 8, weight: .bold)).foregroundStyle(.green)
            }
            .offset(x: 78, y: -54)
        }
        .onAppear { pulse = true }
    }

    func obCell(_ color: Color, _ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color.opacity(0.38))
            .overlay { RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(color.opacity(0.65), lineWidth: 0.5) }
            .frame(width: w, height: h)
    }
}

struct OBIllustrationRestore: View {
    @State private var connected = false
    @State private var flash = false

    var body: some View {
        HStack(spacing: 18) {
            obMonitor(tint: .accentColor, lit: connected)
            Image(systemName: "bolt.fill")
                .font(.system(size: 24))
                .foregroundStyle(flash ? .yellow : Color.primary.opacity(0.25))
                .scaleEffect(flash ? 1.25 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: flash)
            obMonitor(tint: .blue, lit: connected)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7)) { connected = true }
            withAnimation(.easeInOut(duration: 0.22).delay(1.0)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { flash = false }
            }
        }
    }

    @ViewBuilder
    func obMonitor(tint: Color, lit: Bool) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.7))
                .frame(width: 84, height: 58)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint.opacity(lit ? 0.5 : 0.12))
                        .frame(width: 64, height: 38)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(lit ? tint.opacity(0.8) : Color.primary.opacity(0.18), lineWidth: 1)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: lit)
            Image(systemName: "display")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

struct OBIllustrationCustomize: View {
    @State private var sel = 0
    @State private var ticker: Timer?
    let swatches: [Color] = [.accentColor, .purple, .blue, .green, .orange, .pink]

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                ForEach(swatches.indices, id: \.self) { i in
                    Circle()
                        .fill(swatches[i])
                        .frame(width: sel == i ? 30 : 20, height: sel == i ? 30 : 20)
                        .shadow(color: swatches[i].opacity(0.55), radius: sel == i ? 8 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: sel)
                }
            }

            HStack(spacing: 8) {
                ForEach([("EN", true), ("עב", false)], id: \.0) { (label, active) in
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 36, height: 24)
                        .background(active ? Color.accentColor : Color.primary.opacity(0.1))
                        .foregroundStyle(active ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .onAppear {
            ticker = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
                withAnimation { sel = (sel + 1) % swatches.count }
            }
        }
        .onDisappear { ticker?.invalidate() }
    }
}

// MARK: - Menu Bar Illustration

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
                .fill(Color.black.opacity(0.60))
                .frame(width: 260, height: 26)
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
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Circle().fill(.yellow).frame(width: 6, height: 6)
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    .padding(.leading, 10)
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
        .frame(width: 260, height: 180)
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

// MARK: - Desktop Toggle Illustration — Enhanced High-Detail Desktop

struct OBIllustrationDesktopToggle: View {
    @State private var showWindows = true
    @State private var keysLit = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            // High-detail macOS Monitor Screen — fits cleanly inside 300x180 card
            ZStack(alignment: .bottom) {
                // macOS Wallpaper Gradient Background
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(nsColor: .systemIndigo).opacity(0.7), Color(nsColor: .systemPurple).opacity(0.5), Color(nsColor: .systemBlue).opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 220, height: 112)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.75)
                    )

                // Wallpaper Desktop Label
                VStack(spacing: 1) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("macOS Desktop")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Windows layer — smooth scale and offset transitions
                ZStack {
                    // Window 1: Safari / Browser (Top Left)
                    macOSWindowView(title: "Safari", color: .accentColor, icon: "compass.drawing")
                        .frame(width: 98, height: 60)
                        .offset(x: -40, y: -22)

                    // Window 2: Notes / App (Top Right)
                    macOSWindowView(title: "Notes", color: .orange, icon: "note.text")
                        .frame(width: 84, height: 52)
                        .offset(x: 44, y: -18)

                    // Window 3: Editor (Bottom Center)
                    macOSWindowView(title: "Editor", color: .purple, icon: "chevron.left.forwardslash.chevron.right")
                        .frame(width: 110, height: 44)
                        .offset(x: 0, y: 18)
                }
                .scaleEffect(showWindows ? 1.0 : 0.45)
                .offset(y: showWindows ? 0 : 60)
                .opacity(showWindows ? 1.0 : 0.0)
                .animation(.spring(response: 0.48, dampingFraction: 0.76), value: showWindows)

                // macOS Dock Bar at the bottom
                HStack(spacing: 5) {
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Circle().fill(Color.purple).frame(width: 6, height: 6)
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)

            // Key Caps: ⌘ + D
            HStack(spacing: 5) {
                keyCap("⌘", lit: keysLit)
                Text("+")
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(.secondary)
                keyCap("D", lit: keysLit)
            }
        }
        .frame(width: 280, height: 160)
        .onAppear { startAnimationLoop() }
        .onDisappear { timer?.invalidate() }
    }

    @ViewBuilder
    private func macOSWindowView(title: String, color: Color, icon: String) -> some View {
        VStack(spacing: 0) {
            // Window Titlebar with Traffic Lights (🔴 🟡 🟢)
            HStack(spacing: 3) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 4.5, height: 4.5)
                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 4.5, height: 4.5)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 4.5, height: 4.5)

                Text(title)
                    .font(.system(size: 6.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.leading, 1)

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 5.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.4))

            // Window Content Body
            ZStack {
                color.opacity(0.35)
                VStack(spacing: 2.5) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.3)).frame(height: 2.5)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.2)).frame(height: 2.5)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.15)).frame(height: 2.5)
                }
                .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(color.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: color.opacity(0.2), radius: 5, x: 0, y: 2)
    }

    private func startAnimationLoop() {
        runCycle()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            runCycle()
        }
    }

    private func runCycle() {
        // Step 1: press the toggle shortcut -> hide windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.15)) { keysLit = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.15)) { keysLit = false }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) { showWindows = false }
        }

        // Step 2: press it again -> restore windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeInOut(duration: 0.15)) { keysLit = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            withAnimation(.easeInOut(duration: 0.15)) { keysLit = false }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) { showWindows = true }
        }
    }

    @ViewBuilder
    private func keyCap(_ label: String, lit: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(lit ? .white : .primary)
            .frame(width: 30, height: 24)
            .background(lit ? Color.accentColor : Color.primary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: lit ? Color.accentColor.opacity(0.55) : .clear, radius: 5, x: 0, y: 2)
            .scaleEffect(lit ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: lit)
    }
}

// MARK: - Cmd+Shift+R Illustration — Sequential Feature Scene Animations

struct OBIllustrationCmdShiftR: View {
    @State private var activeScene: Int = 0 // 0: Safari Reader Mode, 1: Chrome Hard Reload, 2: Video PiP
    @State private var keysLit = false
    @State private var isActionTriggered = false
    @State private var reloadSpin: Double = 0
    @State private var loadProgress: CGFloat = 0
    @State private var timer: Timer?
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private let scenes: [(id: Int, title: String, shortTitle: String, icon: String, color: Color)] = [
        (0, "Reading Mode", "Reader", "book.pages.fill", .blue),
        (1, "Hard Reload", "Reload", "arrow.clockwise",  .orange),
        (2, "Picture-in-Picture", "PiP", "pip", .purple),
    ]

    var body: some View {
        VStack(spacing: 8) {
            // Keys top bar: ⌘ + ⇧ + R
            HStack(spacing: 5) {
                keyCap("⌘", lit: keysLit)
                Text("+").font(.system(size: 10, weight: .light)).foregroundStyle(.secondary)
                keyCap("⇧", lit: keysLit)
                Text("+").font(.system(size: 10, weight: .light)).foregroundStyle(.secondary)
                keyCap("R", lit: keysLit)
            }

            // Main scene container — tall and wide
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.sRGB, red: 0.08, green: 0.08, blue: 0.10, opacity: 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(scenes[activeScene].color.opacity(0.35), lineWidth: 1.2)
                    )

                switch activeScene {
                case 0:
                    safariReaderModeScene
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    chromeHardReloadScene
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                default:
                    videoPipScene
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: 290, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: scenes[activeScene].color.opacity(0.25), radius: 8, x: 0, y: 4)

            // Scene Selector Pills
            HStack(spacing: 6) {
                ForEach(scenes, id: \.id) { sc in
                    HStack(spacing: 4) {
                        Image(systemName: sc.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(sc.shortTitle.localized(appLanguage))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(sc.id == activeScene ? sc.color : Color.primary.opacity(0.1))
                    .foregroundStyle(sc.id == activeScene ? .white : .secondary)
                    .clipShape(Capsule())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeScene)
                }
            }
        }
        .frame(width: 320, height: 220)
        .onAppear { startSceneLoop() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: Scene 1: Safari Reader Mode Transformation

    private var safariReaderModeScene: some View {
        VStack(spacing: 0) {
            // Safari Header Bar
            HStack(spacing: 5) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 6, height: 6)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 6, height: 6)

                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(isActionTriggered ? Color.blue : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: isActionTriggered)
                    Text("safari.com/article")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.45))

            // Body Area
            ZStack {
                if isActionTriggered {
                    // Clean Reader Mode
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                            Text("Reader Mode")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.blue)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.75)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.55)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.55)).frame(width: 140, height: 6)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.4)).frame(height: 6)
                        }
                    }
                    .padding(14)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    // Cluttered web page with sidebar ads
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.5)).frame(height: 12)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.3)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.3)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(height: 5)
                        }
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.35)).frame(width: 52, height: 20)
                            RoundedRectangle(cornerRadius: 3).fill(Color.pink.opacity(0.3)).frame(width: 52, height: 14)
                            RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.25)).frame(width: 52, height: 14)
                        }
                    }
                    .padding(14)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Scene 2: Chrome Hard Reload

    private var chromeHardReloadScene: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 6, height: 6)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isActionTriggered ? Color.orange : .secondary)
                        .rotationEffect(.degrees(reloadSpin))
                        .animation(.easeInOut(duration: 0.4), value: reloadSpin)

                    HStack(spacing: 0) {
                        Text("chrome://")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.7))
                        Text(isActionTriggered ? "done" : "loading...")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(isActionTriggered ? .orange : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: isActionTriggered)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.45))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 3)
                        Rectangle()
                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: isActionTriggered ? geo.size.width : 0, height: 3)
                            .animation(.easeInOut(duration: 0.65), value: isActionTriggered)
                    }
                }
                .frame(height: 3)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isActionTriggered ? Color.orange.opacity(0.2) : Color.clear)
                            .frame(width: 28, height: 28)
                        Image(systemName: isActionTriggered ? "bolt.fill" : "arrow.clockwise.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(isActionTriggered ? .orange : .secondary)
                    }
                    .animation(.spring(response: 0.3), value: isActionTriggered)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isActionTriggered ? "Cache Cleared!" : "Hard Reload…")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isActionTriggered ? .orange : .primary)
                            .animation(.easeInOut(duration: 0.2), value: isActionTriggered)
                        Text(isActionTriggered ? "Fresh assets loaded from server" : "Bypassing browser cache")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActionTriggered ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.4).delay(0.1), value: isActionTriggered)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActionTriggered ? Color.white.opacity(0.45) : Color.white.opacity(0.15))
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.4).delay(0.2), value: isActionTriggered)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActionTriggered ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 160, height: 6)
                        .animation(.easeInOut(duration: 0.4).delay(0.3), value: isActionTriggered)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Scene 3: Video Picture-in-Picture

    private var videoPipScene: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 6, height: 6)
                    Spacer()
                    Text("Video Player")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.45))

                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.45), Color.indigo.opacity(0.3), Color.blue.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 6) {
                        Image(systemName: isActionTriggered ? "pip.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(isActionTriggered ? 0.35 : 0.7))
                            .animation(.easeInOut(duration: 0.3), value: isActionTriggered)
                        if isActionTriggered {
                            Text("Moved to PiP")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isActionTriggered {
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: "pip.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("PiP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    ZStack {
                        LinearGradient(
                            colors: [Color.purple, Color.indigo],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(6)
                .frame(width: 88, height: 58)
                .background(Color(.sRGB, red: 0.12, green: 0.05, blue: 0.18, opacity: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.purple.opacity(0.7), lineWidth: 1.2)
                )
                .shadow(color: Color.purple.opacity(0.6), radius: 10, x: 0, y: 4)
                .offset(x: 80, y: 38)
                .transition(.scale(scale: 0.5, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
    }

    // MARK: Animation Loop Controller

    private func startSceneLoop() {
        runCycle()
        timer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            runCycle()
        }
    }

    private func runCycle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isActionTriggered = false
            loadProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.15)) { keysLit = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.15)) { keysLit = false }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                isActionTriggered = true
                if activeScene == 1 { reloadSpin += 360 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            withAnimation(.easeInOut(duration: 0.45)) {
                isActionTriggered = false
                activeScene = (activeScene + 1) % 3
            }
        }
    }

    @ViewBuilder
    private func keyCap(_ label: String, lit: Bool) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(lit ? .white : .primary)
            .frame(width: 32, height: 28)
            .background(lit ? scenes[activeScene].color : Color.primary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: lit ? scenes[activeScene].color.opacity(0.5) : .clear, radius: 6)
            .animation(.easeInOut(duration: 0.15), value: lit)
    }
}

// MARK: - Quick Key Restore Illustration (Fn Long-Press & Double-Tap Caps Lock)

// MARK: - Quick Key Restore Illustration (Fn Long-Press & Double-Tap Caps Lock)

struct OBIllustrationQuickKey: View {
    @State private var mode: Int = 0 // 0: Fn Hold, 1: Caps Lock Double-Tap
    @State private var isHolding = false
    @State private var holdProgress: CGFloat = 0.0
    @State private var isDoubleTapping = false
    @State private var isRestored = false
    @State private var showPill = false
    @State private var timer: Timer?
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        VStack(spacing: 10) {
            // Monitor / Window Screen Display
            ZStack(alignment: .center) {
                // Background Desktop Canvas
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(nsColor: .systemTeal).opacity(0.6), Color(nsColor: .systemBlue).opacity(0.5), Color(nsColor: .systemIndigo).opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 220, height: 106)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.75)
                    )

                // Background Outline of Target Window Slot
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(width: 120, height: 72)

                // Moving Window
                macOSWindowView(title: "Safari", color: .accentColor, icon: "compass.drawing")
                    .frame(width: 120, height: 72)
                    .offset(x: isRestored ? 0 : -35, y: isRestored ? 0 : 25)
                    .scaleEffect(isRestored ? 1.0 : 0.88)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: isRestored)

                // Notch Restore Notification Pill
                if showPill {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                        Text("Front App Restored".localized(appLanguage))
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .offset(y: -42)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)

            // Realistic 3D Apple Keycap & Progress
            VStack(spacing: 5) {
                if mode == 0 {
                    // Fn Keycap
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 9, weight: .medium))
                        Text("fn")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isHolding ? Color.accentColor : Color.primary.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.primary.opacity(isHolding ? 0.18 : 0.10), Color.primary.opacity(isHolding ? 0.24 : 0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isHolding ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: isHolding ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.12), radius: isHolding ? 4 : 2, x: 0, y: isHolding ? 0.5 : 2)
                    .offset(y: isHolding ? 1.5 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHolding)

                    // Linear Hold Progress Bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 58, height: 3.5)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(0, 58 * holdProgress), height: 3.5)
                            .animation(.linear(duration: 0.1), value: holdProgress)
                    }
                    .opacity(isHolding || holdProgress > 0 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHolding)

                    // Centered Status Text
                    Text(isRestored ? "Restored ✓".localized(appLanguage) : (isHolding ? "Holding...".localized(appLanguage) : "Hold Fn to restore".localized(appLanguage)))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(isRestored ? Color.green : .secondary)

                } else {
                    // Caps Lock Keycap
                    HStack(spacing: 4) {
                        Image(systemName: "capslock.fill")
                            .font(.system(size: 9, weight: .medium))
                        Text("caps lock")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isDoubleTapping ? Color.orange : Color.primary.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.primary.opacity(isDoubleTapping ? 0.2 : 0.10), Color.primary.opacity(isDoubleTapping ? 0.26 : 0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isDoubleTapping ? Color.orange.opacity(0.8) : Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: isDoubleTapping ? Color.orange.opacity(0.3) : Color.black.opacity(0.12), radius: isDoubleTapping ? 4 : 2, x: 0, y: isDoubleTapping ? 0.5 : 2)
                    .offset(y: isDoubleTapping ? 1.5 : 0)
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isDoubleTapping)

                    // Spacer matching height of progress bar to keep layout vertically locked
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 58, height: 3.5)

                    // Centered Status Text
                    Text(isRestored ? "Restored ✓".localized(appLanguage) : (isDoubleTapping ? "Double Tap".localized(appLanguage) : "Double-tap ⇪ to restore".localized(appLanguage)))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(isRestored ? Color.green : .secondary)
                }
            }
        }
        .frame(width: 280, height: 175)
        .onAppear { startAnimationLoop() }
        .onDisappear { timer?.invalidate() }
    }


    @ViewBuilder
    private func macOSWindowView(title: String, color: Color, icon: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 4.5, height: 4.5)
                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 4.5, height: 4.5)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 4.5, height: 4.5)
                Text(title)
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.leading, 1)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 6))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.4))

            ZStack {
                color.opacity(0.35)
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.35)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.2)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.15)).frame(height: 3)
                }
                .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(color.opacity(0.6), lineWidth: 0.75)
        )
        .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    private func startAnimationLoop() {
        runCycle()
        timer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            runCycle()
        }
    }

    private func runCycle() {
        // Reset
        withAnimation {
            isRestored = false
            showPill = false
            holdProgress = 0.0
            isHolding = false
            isDoubleTapping = false
        }

        if mode == 0 {
            // Fn Hold Sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.15)) { isHolding = true }
                withAnimation(.linear(duration: 1.0)) { holdProgress = 1.0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.65)) {
                    isRestored = true
                    showPill = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.2)) { isHolding = false }
            }
        } else {
            // Caps Lock Double-Tap Sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.1)) { isDoubleTapping = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.easeInOut(duration: 0.1)) { isDoubleTapping = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.1)) { isDoubleTapping = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(.easeInOut(duration: 0.1)) { isDoubleTapping = false }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.65)) {
                    isRestored = true
                    showPill = true
                }
            }
        }

        // Toggle mode for next iteration
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            mode = (mode + 1) % 2
        }
    }
}

// MARK: - Settings Guide Illustration

struct OBIllustrationSettingsGuide: View {

    var activeIndex: Int = 0
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        VStack(spacing: 5) {
            obSettingRow(
                icon: "bolt.fill",
                color: .orange,
                title: "Auto-Restore".localized(appLanguage),
                subtitle: "Triggers on display connect or app open".localized(appLanguage),
                isActive: activeIndex == 0
            )

            obSettingRow(
                icon: "keyboard",
                color: .purple,
                title: "Desktop Toggle".localized(appLanguage),
                subtitle: String(format: "%@ to hide or show all windows".localized(appLanguage), HotkeyFormatter.desktopToggleGlyphs),
                isActive: activeIndex == 1
            )

            obSettingRow(
                icon: "laptopcomputer",
                color: .pink,
                title: "Notch Alerts".localized(appLanguage),
                subtitle: "Pill notifications for layout events".localized(appLanguage),
                isActive: activeIndex == 2
            )

            obSettingRow(
                icon: "list.bullet.rectangle.portrait",
                color: .blue,
                title: "Activity Log Level".localized(appLanguage),
                subtitle: "Filter which events appear in the log".localized(appLanguage),
                isActive: activeIndex == 3
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    func obSettingRow(icon: String, color: Color, title: String, subtitle: String, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
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
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Capsule()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 22, height: 12)
                    .overlay(alignment: isActive ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .padding(1)
                            .shadow(radius: 0.5)
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            }
        }
        .scaleEffect(isActive ? 1.02 : 1.0)
    }
}
