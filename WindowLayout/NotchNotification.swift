// this file is in charge of the notch notification and its behavior and appearance plus its logic and its animations 
import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Built-in Screen Detection

/// Width of the hardware notch in points, or 0 on a display without one.
///
/// The two auxiliary areas are the menu-bar strips either side of the notch, so
/// the gap between them is the notch itself. This has to be read rather than
/// hardcoded: it differs between models and scales with the display mode.
private func notchWidth(of screen: NSScreen) -> CGFloat {
    guard let left = screen.auxiliaryTopLeftArea,
          let right = screen.auxiliaryTopRightArea else { return 0 }
    return max(0, right.minX - left.maxX)
}

/// How far the pill must reach beyond the notch on each side.
///
/// Matching the notch exactly is not enough. `auxiliaryTopLeftArea` gives the
/// *layout* boundary either side of the cutout, but the cutout is a physical
/// hole: pixels there are in the framebuffer and behind the camera housing, so
/// they are never seen. A pill exactly notch-wide therefore puts its two
/// vertical strokes where no one can see them, and the notification looks
/// unbordered — which is what a screenshot cannot show you, because the
/// framebuffer has the stroke even when the glass does not.
///
/// There is no API for the physical cutout, so this cannot be derived. It is a
/// knob rather than a guess:
///
///     defaults write com.netanel.remembermywindows notchClearance -float 8
///
/// 6pt each side was confirmed by eye on a 14-inch MacBook Pro on 2026-09-03:
/// the notch measures 185pt there, so the pill becomes 197pt and the stroke
/// lands on visible glass. Verified on the physical screen, because a
/// screenshot shows the stroke either way. Set it to 0 for the old behaviour.
private func notchClearance() -> CGFloat {
    let key = "notchClearance"
    guard UserDefaults.standard.object(forKey: key) != nil else { return 6 }
    return max(0, CGFloat(UserDefaults.standard.double(forKey: key)))
}

private func builtInScreen() -> NSScreen {
    if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
        return notched
    }
    for screen in NSScreen.screens {
        if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let did = CGDirectDisplayID(n.uint32Value)
            if CGDisplayIsBuiltin(did) != 0 {
                return screen
            }
        }
    }
    for screen in NSScreen.screens {
        let name = screen.localizedName.lowercased()
        if name.contains("built-in") || name.contains("retina display")
            || name.contains("liquid retina") || name.contains("color lcd") {
            return screen
        }
    }
    return NSScreen.screens.first ?? NSScreen.main!
}

// MARK: - Notification Data

final class NotificationData: ObservableObject {
    @Published var title: String
    @Published var subtitle: String
    @Published var bundleID: String?
    @Published var appIcon: NSImage?
    
    init(title: String, subtitle: String, bundleID: String? = nil, appIcon: NSImage? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.bundleID = bundleID
        self.appIcon = appIcon
    }
}

// MARK: - Notch Notification Window

final class NotchNotificationWindow: NSPanel {
    let isCompact: Bool
    private let pillWidth: CGFloat
    private let data: NotificationData
    private var dismissTimer: Timer?
    var onDismissCompleted: (() -> Void)?

    static func isAllowedSubtitle(_ subtitle: String) -> Bool {
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "fn" || trimmed.contains("⇪")
    }

    init(title: String, subtitle: String, isCompact: Bool = false, bundleID: String? = nil, appIcon: NSImage? = nil) {
        let finalSubtitle: String
        if isCompact {
            finalSubtitle = Self.isAllowedSubtitle(subtitle) ? subtitle : ""
        } else {
            finalSubtitle = subtitle
        }
        self.isCompact = isCompact
        // Never narrower than the notch. A pill that is means the hardware
        // cutout shows as black shoulders either side of it, and the
        // notification reads as a stub sitting inside the notch instead of
        // hanging from it. Only the compact-without-subtitle case was affected,
        // at 180pt against a notch measured at 185, and isAllowedSubtitle
        // strips the subtitle from all but a couple of notifications, so that
        // was the common case rather than an edge one.
        let intrinsicWidth: CGFloat = isCompact ? (finalSubtitle.isEmpty ? 180 : 215) : 280
        // Clear the notch rather than merely match it — see notchClearance().
        let notch = notchWidth(of: builtInScreen())
        let minimumWidth = notch > 0 ? notch + notchClearance() * 2 : 0
        let bodyWidth = max(intrinsicWidth, minimumWidth)
        self.data = NotificationData(title: title, subtitle: finalSubtitle, bundleID: bundleID, appIcon: appIcon)
        
        let notchDepth = builtInScreen().safeAreaInsets.top > 0 ? builtInScreen().safeAreaInsets.top : 24.0
        let dynamicPillHeight = notchDepth + (isCompact ? 24.0 : 38.0)
        let shoulder = NotchShapeLayout.shoulder(forHeight: dynamicPillHeight)
        self.pillWidth = bodyWidth + shoulder * 2
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: self.pillWidth, height: dynamicPillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level              = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func update(title: String, subtitle: String, bundleID: String? = nil, appIcon: NSImage? = nil) {
        let finalSubtitle: String
        if isCompact {
            finalSubtitle = Self.isAllowedSubtitle(subtitle) ? subtitle : ""
        } else {
            finalSubtitle = subtitle
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            data.title = title
            data.subtitle = finalSubtitle
            data.bundleID = bundleID
            if let icon = appIcon { data.appIcon = icon }
        }
        resetDismissTimer()
    }

    func show() {
        guard !WindowManager.shared.isScreenLocked else { return }
        let screen = builtInScreen()
        let sf = screen.frame
        let notchDepth = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 24.0
        let dynamicPillHeight = notchDepth + (isCompact ? 24.0 : 38.0)
        let windowHeight = dynamicPillHeight + 20.0
        let visibleY  = sf.maxY - windowHeight
        let originX   = sf.midX - self.pillWidth / 2

        setFrame(NSRect(x: originX, y: visibleY, width: self.pillWidth, height: windowHeight), display: true)
        self.alphaValue = 1.0

        let rootView = NotchNotificationView(
            data: data,
            notchDepth: notchDepth,
            pillWidth: self.pillWidth,
            pillHeight: dynamicPillHeight,
            isCompact: isCompact,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(x: 0, y: 0, width: self.pillWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        orderFrontRegardless()
        resetDismissTimer()
    }

    private func resetDismissTimer() {
        dismissTimer?.invalidate()
        let duration: TimeInterval = isCompact ? 2.2 : 5.0
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        NotificationCenter.default.post(name: NSNotification.Name("NotchDismiss"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            let callback = self?.onDismissCompleted
            self?.close()
            // Release the SwiftUI view with the window's contents. WindowManager
            // keeps this window in `notchWindow` after it closes, so without this
            // the view stays alive and its repeatForever `dotPulse` keeps running
            // off screen: a Core Animation commit every frame for WindowServer to
            // composite, for as long as the app runs.
            self?.contentView = nil
            callback?()
        }
    }
}

// MARK: - SwiftUI View

struct NotchNotificationView: View {
    @ObservedObject var data: NotificationData
    let notchDepth: CGFloat
    let pillWidth: CGFloat
    let pillHeight: CGFloat
    let isCompact: Bool
    let onDismiss: () -> Void

    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var appeared  = false
    @State private var isHovered = false
    @State private var dotPulse  = false
    @State private var iconDrop  = false

    private var accentColor: Color {
        if themeColor == .black {
            return Color(white: 0.88)
        }
        return themeColor.color ?? Color(red: 0.2, green: 0.9, blue: 0.5)
    }

    private var shouldReduceMotion: Bool {
        false
    }

    // MARK: - Layout metrics
    //
    // Named once, and read by both the layout below and the fit test under them.
    // A second copy of these numbers is what let the fit test drift away from the
    // layout it was supposed to describe.
    private var edgeInset: CGFloat { isCompact ? 8 : 14 }
    private var rowGap: CGFloat { isCompact ? 8 : 10 }
    private var badgeGap: CGFloat { 6 }
    private var iconSide: CGFloat { isCompact ? 18 : 22 }
    private var iconInset: CGFloat { isCompact ? 8 : 12 }
    private var titleSize: CGFloat { isCompact ? 11 : 12.5 }

    /// The face `.system(size:weight:design:)` resolves to, so a string can be
    /// measured with the one that will draw it.
    private static func systemFont(size: CGFloat, design: NSFontDescriptor.SystemDesign) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .bold)
        guard let descriptor = base.fontDescriptor.withDesign(design),
              let font = NSFont(descriptor: descriptor, size: size) else { return base }
        return font
    }

    private static func drawnWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// What the subtitle badge takes out of the row it shares with the title.
    private var badgeWidth: CGFloat {
        guard isCompact, !data.subtitle.isEmpty,
              NotchNotificationWindow.isAllowedSubtitle(data.subtitle) else { return 0 }
        let isSymbol = data.subtitle.contains("⇪")
        let font = Self.systemFont(size: isSymbol ? 13 : 9.5,
                                   design: isSymbol ? .default : .monospaced)
        return badgeGap + Self.drawnWidth(data.subtitle, font: font) + (isSymbol ? 6 : 5.5) * 2
    }

    /// Width left for the title once the centred layout has taken its share.
    ///
    /// The centred layout is `icon | Spacer | text | Spacer | balance space`. The
    /// balance space matches the leading icon so the title sits in the middle of
    /// the pill, and it plus the two extra gaps cost the title 38pt at compact
    /// size that the left-aligned layout would have given it.
    private var centredTitleWidth: CGFloat {
        let shoulder = NotchShapeLayout.shoulder(forHeight: pillHeight)
        let bodyWidth = max(1, pillWidth - shoulder * 2)
        return bodyWidth
            - edgeInset * 2
            - (iconInset + iconSide)    // the leading icon
            - rowGap * 4                // icon | Spacer | text | Spacer | balance
            - (iconSide + iconInset)    // the balance space
            - badgeWidth
    }

    /// True when the title really fits the centred layout.
    ///
    /// This was `data.title.count <= 18`. A character count cannot answer the
    /// question, because the centred layout is the narrower of the two: on a
    /// 180pt pill it runs out at 15 lowercase "n" or at 9 capital "W", and the
    /// count allowed 18 of either. So the titles needing the most room were the
    /// ones sent to the branch with the least.
    ///
    /// Reported by Netanel on a MacBook Air 15-inch, 2026-09-04, and measured
    /// here: "Telegram Restored" is 17 characters, draws at 103pt, and was given
    /// 100pt. It was cut to "Telegram Resto…" with the right of the pill empty.
    private var isShortText: Bool {
        guard isCompact else { return false }
        return Self.drawnWidth(data.title,
                               font: Self.systemFont(size: titleSize, design: .rounded))
            <= centredTitleWidth
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            let cornerRadius: CGFloat = isCompact ? 14 : 18
            let silhouette = NotchHardwareSilhouetteShape(cornerRadius: cornerRadius)
            let outline = NotchHardwareOutlineShape(cornerRadius: cornerRadius)

            // Main Hardware Notch Body & Border (Hardware shoulders flare into top bezel)
            ZStack {
                silhouette
                    .fill(Color.black)

                outline
                    .stroke(Color.white.opacity(appeared ? 0.38 : 0.12), lineWidth: 1.0)

                outline
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(appeared ? 0.3 : 0.1),
                                accentColor.opacity(appeared ? 0.5 : 0.15),
                                .white.opacity(appeared ? 0.3 : 0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.0
                    )
            }
            .frame(width: pillWidth, height: pillHeight)

            HStack(spacing: rowGap) {
                // Far-Left Icon/Dot dropping down from top-left
                Group {
                    if let icon = data.appIcon ?? (data.bundleID.flatMap { bID in
                        NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bID })?.icon
                            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bID).map { NSWorkspace.shared.icon(forFile: $0.path) }
                    }) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .frame(width: iconSide, height: iconSide)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .shadow(color: accentColor.opacity(0.4), radius: 3)
                            .offset(y: iconDrop ? 0 : -35)
                            .scaleEffect(iconDrop ? 1.0 : 0.25, anchor: .topLeading)
                            .opacity(iconDrop ? 1.0 : 0.0)
                            .animation(.spring(response: 0.42, dampingFraction: 0.65), value: iconDrop)
                    } else {
                        ZStack {
                            // Persistent halo.
                            Circle()
                                .fill(accentColor.opacity(0.22))
                                .frame(width: isCompact ? 18 : 26, height: isCompact ? 18 : 26)

                            // Pulsing outer ripple ring
                            Circle()
                                .stroke(accentColor, lineWidth: 1.5)
                                .frame(width: isCompact ? 18 : 26, height: isCompact ? 18 : 26)
                                .scaleEffect(dotPulse ? 1.55 : 0.55)
                                .opacity(dotPulse ? 0.0 : 0.85)

                            // Glowing solid center dot
                            Circle()
                                .fill(accentColor)
                                .frame(width: isCompact ? 6 : 9, height: isCompact ? 6 : 9)
                                .shadow(color: accentColor.opacity(0.85), radius: 4, x: 0, y: 0)
                        }
                        .offset(y: iconDrop ? 0 : -35)
                        .scaleEffect(iconDrop ? 1.0 : 0.25, anchor: .topLeading)
                        .opacity(iconDrop ? 1.0 : 0.0)
                        .animation(.spring(response: 0.42, dampingFraction: 0.65), value: iconDrop)
                    }
                }
                .padding(.leading, iconInset)

                if isShortText {
                    Spacer(minLength: 0)
                }

                HStack(spacing: badgeGap) {
                    VStack(alignment: isShortText ? .center : .leading, spacing: 1) {
                        Text(data.title)
                            .font(.system(size: titleSize, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .id(data.title)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.9)),
                                removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 1.1))
                            ))
                        
                        if !isCompact && !data.subtitle.isEmpty {
                            Text(data.subtitle)
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .id(data.subtitle)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.9)),
                                    removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 1.1))
                                ))
                        }
                    }
                    
                    if isCompact && !data.subtitle.isEmpty && NotchNotificationWindow.isAllowedSubtitle(data.subtitle) {
                        let isSymbol = data.subtitle.contains("⇪")
                        Text(data.subtitle)
                            .font(.system(size: isSymbol ? 13 : 9.5, weight: .bold, design: isSymbol ? .default : .monospaced))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, isSymbol ? 6 : 5.5)
                            .padding(.vertical, isSymbol ? 1 : 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.white.opacity(0.16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.white.opacity(0.28), lineWidth: 0.5)
                                    )
                            )
                            .id(data.subtitle)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: data.title)

                if isShortText {
                    Spacer(minLength: 0)

                    // Symmetrical balance space matching the leading icon + padding
                    Color.clear
                        .frame(width: iconSide, height: iconSide)
                        .padding(.trailing, iconInset)
                } else {
                    Spacer(minLength: 4)
                }
            }
            .padding(.horizontal, edgeInset + NotchShapeLayout.shoulder(forHeight: pillHeight))
            .padding(.bottom, isCompact ? 4 : 8)
            .frame(height: isCompact ? 26 : 40)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : -6)
        }
        .frame(width: pillWidth, height: pillHeight, alignment: .top)
        // No drop shadow. The pill hangs off the top of the screen, so a blur has
        // nowhere to land except around the two bottom corners, where it compounds
        // from the bottom edge and the side edge at once and reads as a dirty
        // corner rather than as depth. The pill is meant to look like the notch,
        // and hardware does not float.
        .opacity(appeared ? 1.0 : 0.0)
        .scaleEffect(x: appeared ? 1.0 : 0.88, y: appeared ? 1.0 : 0.01, anchor: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: appeared)
        .onAppear {
            if shouldReduceMotion {
                appeared = true
                iconDrop = true
                dotPulse = false
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    appeared = true
                }
                withAnimation(.easeOut(duration: 0.85).repeatForever(autoreverses: false)) {
                    dotPulse = true
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.65).delay(0.04)) {
                    iconDrop = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchDismiss"))) { _ in
            if shouldReduceMotion {
                appeared = false
                iconDrop = false
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    appeared = false
                    iconDrop = false
                }
            }
        }
        .onHover { hovering in
            if !isCompact {
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
        }
        .transaction { transaction in
            transaction.disablesAnimations = false
        }
    }
}

// MARK: - Position HUD (notch-drop pill with Done / Cancel buttons)

/// A persistent notch-style HUD that stays on screen until the user clicks Done or Cancel.
/// Drops from the top of the active screen using the same geometry as NotchNotificationView.
final class NotchPositionHUDWindow: NSPanel {
    var onDone:   (() -> Void)?
    var onCancel: (() -> Void)?
    var onDismissCompleted: (() -> Void)?
    private let appName:  String
    private let bundleID: String?

    // Fixed body size (wide enough for all content + both buttons)
    private let bodyW: CGFloat = 540
    private var pillW: CGFloat = 540
    // pillH will be set in show() based on notch depth
    private var pillH: CGFloat = 70
    private var winH:  CGFloat = 90

    init(appName: String, bundleID: String? = nil) {
        self.appName  = appName
        self.bundleID = bundleID
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level              = .screenSaver
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func show() {
        guard !WindowManager.shared.isScreenLocked else { return }
        // Use the screen containing the mouse — correct on any monitor setup
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let sf         = screen.frame
        let notchDepth = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 24.0
        pillH = notchDepth + 52.0   // notch area + content row
        winH  = pillH + 20.0        // extra space for the slide-in animation
        let shoulder = NotchShapeLayout.shoulder(forHeight: pillH)
        pillW = bodyW + shoulder * 2

        // Centre horizontally, clamped to screen bounds
        let x = max(sf.minX, min(sf.midX - pillW / 2, sf.maxX - pillW))
        let y = sf.maxY - winH

        setFrame(NSRect(x: x, y: y, width: pillW, height: winH), display: true)
        alphaValue = 1.0

        let rootView = NotchPositionHUDView(
            appName:    appName,
            bundleID:   bundleID,
            notchDepth: notchDepth,
            pillWidth:  pillW,
            pillHeight: pillH,
            onDone:     { [weak self] in self?.handleDone() },
            onCancel:   { [weak self] in self?.handleCancel() }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(x: 0, y: 0, width: pillW, height: winH)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
        orderFrontRegardless()
    }

    private func handleDone()   { onDone?();   dismissHUD() }
    private func handleCancel() { onCancel?(); dismissHUD() }

    private func dismissHUD() {
        NotificationCenter.default.post(name: NSNotification.Name("NotchPositionHUDDismiss"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            let callback = self?.onDismissCompleted
            self?.close()
            callback?()
        }
    }
}

// MARK: - Position HUD SwiftUI View

struct NotchPositionHUDView: View {
    let appName:    String
    let bundleID:   String?
    let notchDepth: CGFloat
    let pillWidth:  CGFloat
    let pillHeight: CGFloat
    let onDone:     () -> Void
    let onCancel:   () -> Void

    @AppStorage("themeColor")  private var themeColor:  ThemeColor  = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var appeared    = false
    @State private var iconDrop    = false
    @State private var hoverCancel = false

    private var accentColor: Color { themeColor.color ?? Color(red: 0.18, green: 0.85, blue: 0.5) }

    private var shouldReduceMotion: Bool {
        false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            let silhouette = NotchHardwareSilhouetteShape(cornerRadius: 18)
            let outline = NotchHardwareOutlineShape(cornerRadius: 18)

            // ---- Notch-style pill background (Hardware shoulders flare into top bezel) ----
            ZStack {
                silhouette
                    .fill(Color.black)

                outline
                    .stroke(Color.white.opacity(appeared ? 0.38 : 0.12), lineWidth: 1.0)

                outline
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(appeared ? 0.3 : 0.1),
                                accentColor.opacity(appeared ? 0.5 : 0.15),
                                .white.opacity(appeared ? 0.3 : 0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.0
                    )
            }
            .frame(width: pillWidth, height: pillHeight)

            // ---- Content row ----
            HStack(spacing: 10) {
                // App icon
                Group {
                    if let bID = bundleID {
                        AppIconView(bundleID: bID)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .shadow(color: accentColor.opacity(0.4), radius: 3)
                            .offset(y: iconDrop ? 0 : -45)
                            .scaleEffect(iconDrop ? 1.0 : 0.25, anchor: .topLeading)
                            .opacity(iconDrop ? 1.0 : 0.0)
                            .animation(.spring(response: 0.42, dampingFraction: 0.65), value: iconDrop)
                    }
                }
                .padding(.leading, 12)

                // Labels
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "Position \"%@\"", appName))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Resize & move the window, then tap Done".localized(appLanguage))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // ---- Action Buttons Group (Guaranteed high priority rendering) ----
                HStack(spacing: 8) {
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel".localized(appLanguage))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(hoverCancel ? 0.12 : 0.0))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        if shouldReduceMotion {
                            hoverCancel = h
                        } else {
                            withAnimation(.easeInOut(duration: 0.12)) { hoverCancel = h }
                        }
                    }

                    // Done button (Vivid Neon Green Fill with Black Text - GUARANTEED 100% VISIBLE)
                    Button(action: onDone) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Done".localized(appLanguage))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.2, green: 0.9, blue: 0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ColoredActionButtonStyle(
                        tint: Color(red: 0.2, green: 0.9, blue: 0.5),
                        shape: AnyShape(Capsule())
                    ))
                }
                .fixedSize()
                .layoutPriority(1)
                .padding(.trailing, 14)
            }
            .padding(.horizontal, 4 + NotchShapeLayout.shoulder(forHeight: pillHeight))
            .padding(.bottom, 8)
            .frame(height: 44)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : -6)
        }
        .frame(width: pillWidth, height: pillHeight, alignment: .top)
        .opacity(appeared ? 1.0 : 0.0)
        .scaleEffect(x: appeared ? 1.0 : 0.88, y: appeared ? 1.0 : 0.01, anchor: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: appeared)
        .onAppear {
            if shouldReduceMotion {
                appeared = true
                iconDrop = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { appeared = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) { iconDrop = true }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchPositionHUDDismiss"))) { _ in
            if shouldReduceMotion {
                appeared = false
                iconDrop = false
            } else {
                withAnimation(.easeOut(duration: 0.3)) { appeared = false; iconDrop = false }
            }
        }
        .transaction { transaction in
            transaction.disablesAnimations = false
        }
    }
}
