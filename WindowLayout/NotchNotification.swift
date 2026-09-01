// this file is in charge of the notch notification and its behavior and appearance plus its logic and its animations 
import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Built-in Screen Detection

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
        self.pillWidth = isCompact ? (finalSubtitle.isEmpty ? 180 : 215) : 280
        self.data = NotificationData(title: title, subtitle: finalSubtitle, bundleID: bundleID, appIcon: appIcon)
        
        let notchDepth = builtInScreen().safeAreaInsets.top > 0 ? builtInScreen().safeAreaInsets.top : 24.0
        let dynamicPillHeight = notchDepth + (isCompact ? 24.0 : 38.0)
        
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
            self?.close()
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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Hardware Notch Body & Border (Extended upwards into bezel with seamless bottom curvature)
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                    .fill(Color.black)
                    .padding(.top, -100)

                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                    .stroke(Color.white.opacity(appeared ? 0.38 : 0.12), lineWidth: 1.0)
                    .padding(.top, -100)
                    .padding(.bottom, 0.5)

                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
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
                    .padding(.top, -100)
                    .padding(.bottom, 0.5)
            }
            .frame(width: pillWidth, height: pillHeight)

            HStack(spacing: isCompact ? 8 : 10) {
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
                            .frame(width: isCompact ? 18 : 22, height: isCompact ? 18 : 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .shadow(color: accentColor.opacity(0.4), radius: 3)
                            .offset(y: iconDrop ? 0 : -35)
                            .scaleEffect(iconDrop ? 1.0 : 0.25, anchor: .topLeading)
                            .opacity(iconDrop ? 1.0 : 0.0)
                            .animation(.spring(response: 0.42, dampingFraction: 0.65), value: iconDrop)
                    } else {
                        ZStack {
                            // Persistent halo. The ripple below fades to zero
                            // opacity at the top of its cycle, so without this
                            // the indicator collapses to a bare dot for part of
                            // every pulse and the notification reads as smaller
                            // than it is. The halo holds the visual weight; the
                            // ripple supplies the motion.
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
                .padding(.leading, isCompact ? 8 : 12)

                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(data.title)
                            .font(.system(size: isCompact ? 11 : 12.5, weight: .bold, design: .rounded))
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

                Spacer(minLength: 4)
            }
            .padding(.horizontal, isCompact ? 8 : 14)
            .padding(.bottom, isCompact ? 4 : 8)
            .frame(height: isCompact ? 26 : 40)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : -6)
        }
        .frame(width: pillWidth, height: pillHeight, alignment: .top)
        .shadow(color: .black.opacity(appeared ? 0.55 : 0), radius: appeared ? 14 : 0, x: 0, y: 5)
        .opacity(appeared ? 1.0 : 0.0)
        .scaleEffect(x: appeared ? 1.0 : 0.88, y: appeared ? 1.0 : 0.01, anchor: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: appeared)
        .onAppear {
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchDismiss"))) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = false
                iconDrop = false
            }
        }
        .onHover { hovering in
            if !isCompact {
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
        }
    }
}

// MARK: - Position HUD (notch-drop pill with Done / Cancel buttons)

/// A persistent notch-style HUD that stays on screen until the user clicks Done or Cancel.
/// Drops from the top of the active screen using the same geometry as NotchNotificationView.
final class NotchPositionHUDWindow: NSPanel {
    var onDone:   (() -> Void)?
    var onCancel: (() -> Void)?
    private let appName:  String
    private let bundleID: String?

    // Fixed pill size (wide enough for all content + both buttons)
    private let pillW: CGFloat = 540
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
        winH  = pillH + 20.0        // extra space for shadow & slide-in animation

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.close() }
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
    @State private var appeared    = false
    @State private var iconDrop    = false
    @State private var hoverDone   = false
    @State private var hoverCancel = false

    private var accentColor: Color { themeColor.color ?? Color(red: 0.18, green: 0.85, blue: 0.5) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ---- Notch-style pill background (Seamless top-anchored geometry) ----
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black)
                    .padding(.top, -100)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(appeared ? 0.38 : 0.12), lineWidth: 1.0)
                    .padding(.top, -100)
                    .padding(.bottom, 0.5)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    .padding(.top, -100)
                    .padding(.bottom, 0.5)
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
                    .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { hoverCancel = h } }

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
                        .shadow(color: Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.4), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { hoverDone = h } }
                }
                .fixedSize()
                .layoutPriority(1)
                .padding(.trailing, 14)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .frame(height: 44)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : -6)
        }
        .frame(width: pillWidth, height: pillHeight, alignment: .top)
        .shadow(color: .black.opacity(appeared ? 0.55 : 0), radius: appeared ? 14 : 0, x: 0, y: 5)
        .opacity(appeared ? 1.0 : 0.0)
        .scaleEffect(x: appeared ? 1.0 : 0.88, y: appeared ? 1.0 : 0.01, anchor: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: appeared)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) { iconDrop = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchPositionHUDDismiss"))) { _ in
            withAnimation(.easeOut(duration: 0.3)) { appeared = false; iconDrop = false }
        }
    }
}
