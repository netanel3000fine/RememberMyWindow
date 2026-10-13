//
//  CommandOverlayManager.swift
//  WindowLayout
//

import SwiftUI
import AppKit
import ApplicationServices

/// Manages a transient, non-activating floating overlay panel that animates
/// when the Command+Shift+R keystroke is sent to a target app.
@MainActor
final class CommandOverlayManager {
    static let shared = CommandOverlayManager()
    
    private var currentPanel: NSPanel?
    private var dismissTimer: Timer?
    
    private init() {}
    
    /// Displays a floating animation badge over the target application's active window by bundle ID.
    func showOverlay(bundleID: String) {
        let running = NSWorkspace.shared.runningApplications
        if let app = running.first(where: { $0.bundleIdentifier == bundleID || $0.localizedName == bundleID }) {
            showOverlay(for: app)
        } else if let activeApp = running.first(where: { $0.isActive }) {
            showOverlay(for: activeApp)
        }
    }
    
    /// Displays a floating animation badge over the target application's active window (or screen center).
    /// - Parameter app: The target running application receiving the shortcut.
    func showOverlay(for app: NSRunningApplication) {
        guard !WindowManager.shared.isScreenLocked else { return }
        DispatchQueue.main.async { [self] in
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            
            // Clean up previous panel if still active
            if let existing = self.currentPanel {
                existing.orderOut(nil)
                self.currentPanel = nil
            }
            
            // Create non-activating floating panel — enlarged to 460x460 so vertical radial glow & circles don't clip
            let panelWidth: CGFloat = 460
            let panelHeight: CGFloat = 460
            
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let hostView = NSHostingView(rootView: CommandOverlayView(appName: app.localizedName ?? "App"))
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView = hostView
            
            // Calculate placement
            let targetRect = self.findTargetWindowBounds(for: app)
            let targetCenter = CGPoint(
                x: targetRect.midX - (panelWidth / 2),
                y: targetRect.midY - (panelHeight / 2)
            )
            
            panel.setFrameOrigin(targetCenter)
            panel.alphaValue = 1.0
            panel.orderFrontRegardless()
            self.currentPanel = panel
            
            // Auto dismiss panel after animation completes (1.6s display time)
            let timer = Timer(timeInterval: 1.6, repeats: false) { [weak self] _ in
                // The timer is added to RunLoop.main below, so this fires on the
                // main thread. Its block is @Sendable, which is what the
                // compiler objects to; assuming the isolation states the fact
                // rather than adding a hop that would delay the fade by a turn
                // of the run loop.
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.35
                        self.currentPanel?.animator().alphaValue = 0
                    }, completionHandler: {
                        MainActor.assumeIsolated {
                            self.currentPanel?.orderOut(nil)
                            self.currentPanel = nil
                        }
                    })
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.dismissTimer = timer
        }
    }
    
    /// Helper to find target window bounds using AXUIElement or fallback to main screen center.
    private func findTargetWindowBounds(for app: NSRunningApplication) -> CGRect {
        let appAX = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appAX, 0.15)
        var windowRef: CFTypeRef?
        
        // Try focused window first, then main window
        if AXUIElementCopyAttributeValue(appAX, kAXFocusedWindowAttribute as CFString, &windowRef) == .success ||
           AXUIElementCopyAttributeValue(appAX, kAXMainWindowAttribute as CFString, &windowRef) == .success {
            let windowElement = windowRef as! AXUIElement
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            
            if AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionValue) == .success,
               AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeValue) == .success {
                var pos = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &pos)
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
                
                if size.width > 50 && size.height > 50 {
                    let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 1080
                    let cocoaY = mainScreenHeight - pos.y - size.height
                    return CGRect(x: pos.x, y: cocoaY, width: size.width, height: size.height)
                }
            }
        }
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        return screen?.frame ?? CGRect(x: 100, y: 100, width: 800, height: 600)
    }
}

// MARK: - Floating ⌘⇧R Overlay (Radial Glow, No Box)

struct CommandOverlayView: View {
    let appName: String
    
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    
    // Entrance state
    @State private var appeared = false
    @State private var globalScale: CGFloat = 0.6
    @State private var globalOpacity: Double = 0.0
    
    // Keycap staggered slide-in
    @State private var key1Y: CGFloat = 28
    @State private var key2Y: CGFloat = 28
    @State private var key3Y: CGFloat = 28
    @State private var key1Opacity: Double = 0
    @State private var key2Opacity: Double = 0
    @State private var key3Opacity: Double = 0
    
    // Continuous float bob on keycaps
    @State private var bobOffset: CGFloat = 0
    
    // Shimmer streaks
    @State private var shimmer: CGFloat = -1.5
    
    // Radial glow breathe
    @State private var glowScale: CGFloat = 0.7
    @State private var glowOpacity: Double = 0.0
    
    // Shockwave rings
    @State private var wave1Scale: CGFloat = 0.2
    @State private var wave1Opacity: Double = 0.9
    @State private var wave2Scale: CGFloat = 0.2
    @State private var wave2Opacity: Double = 0.85
    @State private var wave3Scale: CGFloat = 0.2
    @State private var wave3Opacity: Double = 0.8
    
    // Text
    @State private var textScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    private var accentColor: Color {
        themeColor.color(seed: 1)
    }

    var body: some View {
        ZStack {
            // ── Background effects: Radial glow + expanding shockwave rings with dissolve mask ──
            ZStack {
                // Radial glow: accent colour at centre, fully clear at edges
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: accentColor.opacity(0.55), location: 0.0),
                        .init(color: accentColor.opacity(0.30), location: 0.30),
                        .init(color: accentColor.opacity(0.10), location: 0.60),
                        .init(color: .clear,                    location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 190
                )
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .blur(radius: 8)
                
                // Three expanding shockwave rings with multi-layered deep contrast shadows & contour lines
                ForEach([
                    (wave1Scale, wave1Opacity, 0.0),
                    (wave2Scale, wave2Opacity, 1.8),
                    (wave3Scale, wave3Opacity, 3.5)
                ], id: \.2) { scale, opacity, _ in
                    ZStack {
                        // Deep ambient occlusion dark shadow beneath each ring
                        Circle()
                            .stroke(Color.black.opacity(opacity * 0.75), lineWidth: 3.5)
                            .scaleEffect(scale)
                            .blur(radius: 4.5)
                            .shadow(color: Color.black.opacity(opacity * 0.85), radius: 10, x: 0, y: 3)

                        // White shadow backdrop glow for crisp separation
                        Circle()
                            .stroke(Color.white.opacity(opacity * 0.55), lineWidth: 2.4)
                            .scaleEffect(scale)
                            .blur(radius: 2.5)
                            .shadow(color: .white.opacity(opacity * 0.7), radius: 6, x: 0, y: 0)

                        // Inner dark contour line for ultra-crisp edge definition
                        Circle()
                            .stroke(Color.black.opacity(opacity * 0.65), lineWidth: 1.2)
                            .scaleEffect(scale * 0.990)
                            .blur(radius: 0.3)

                        // Foreground vibrant accent ring
                        Circle()
                            .stroke(accentColor.opacity(opacity), lineWidth: 1.8)
                            .scaleEffect(scale)
                            .blur(radius: 0.6)
                            .shadow(color: accentColor.opacity(opacity * 0.9), radius: 8, x: 0, y: 0)

                        // Outer sharp dark edge definition
                        Circle()
                            .stroke(Color.black.opacity(opacity * 0.65), lineWidth: 1.2)
                            .scaleEffect(scale * 1.010)
                            .blur(radius: 0.3)
                    }
                }
            }
            .mask(
                // Smooth radial dissolve mask so rings & glow fade seamlessly towards square bounds
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black,                     location: 0.0),
                        .init(color: .black,                     location: 0.50),
                        .init(color: .black.opacity(0.85),       location: 0.68),
                        .init(color: .black.opacity(0.35),       location: 0.85),
                        .init(color: .clear,                     location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 225
                )
            )
            
            // ── Main content: keycaps + app label ──
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    FloatingKeyCapView(
                        symbol: "⌘",
                        accentColor: accentColor,
                        shimmer: shimmer,
                        yOffset: key1Y - bobOffset * 1.0,
                        opacity: key1Opacity
                    )
                    FloatingKeyCapView(
                        symbol: "⇧",
                        accentColor: accentColor,
                        shimmer: shimmer,
                        yOffset: key2Y - bobOffset * 0.7,
                        opacity: key2Opacity
                    )
                    FloatingKeyCapView(
                        symbol: "R",
                        accentColor: accentColor,
                        shimmer: shimmer,
                        yOffset: key3Y - bobOffset * 1.2,
                        opacity: key3Opacity
                    )
                }
                
                // Elegant, transparent floating App Name label
                Text(appName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 2)
                    .shadow(color: accentColor.opacity(0.8), radius: 8, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .scaleEffect(textScale)
                    .opacity(textOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(globalScale)
        .opacity(globalOpacity)
        .onAppear {
            // 1. Global fade + pop in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                globalScale   = 1.0
                globalOpacity = 1.0
                textScale     = 1.0
                textOpacity   = 1.0
            }
            
            // 2. Radial glow breathes in immediately, then pulses
            withAnimation(.easeOut(duration: 0.45)) {
                glowScale   = 1.0
                glowOpacity = 1.0
            }
            // Pulse breathe
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    glowScale   = 1.08
                    glowOpacity = 0.75
                }
            }
            
            // 3. Shockwave rings (staggered)
            withAnimation(.easeOut(duration: 1.1)) {
                wave1Scale = 2.2; wave1Opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeOut(duration: 1.1)) {
                    wave2Scale = 2.2; wave2Opacity = 0.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                withAnimation(.easeOut(duration: 1.1)) {
                    wave3Scale = 2.2; wave3Opacity = 0.0
                }
            }
            
            // 4. Keycaps entrance (all keycaps enter together smoothly so 'R' is never skipped)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.65)) {
                key1Y = 0; key1Opacity = 1.0
                key2Y = 0; key2Opacity = 1.0
                key3Y = 0; key3Opacity = 1.0
            }
            
            // 5. Continuous keycap bob (starts after entrance)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    bobOffset = 5
                }
            }
            
            // 6. Shimmer sweep
            withAnimation(.easeInOut(duration: 0.9).delay(0.15)) {
                shimmer = 1.5
            }
            
            // 7. App name scales in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    textScale = 1.0; textOpacity = 1.0
                }
            }
        }
        // The transient HUD intentionally keeps its animation regardless of
        // app and macOS Reduce Motion settings.
        .fullVisualAnimations()
    }
}

// MARK: - Floating KeyCap (no box background — transparent, glass-only)

private struct FloatingKeyCapView: View {
    let symbol: String
    let accentColor: Color
    let shimmer: CGFloat
    let yOffset: CGFloat
    let opacity: Double
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: Color.black.opacity(0.8), radius: 3, x: 0, y: 1)
            .shadow(color: accentColor.opacity(0.9), radius: 10, x: 0, y: 0)
            .shadow(color: .white.opacity(0.8), radius: 4, x: 0, y: 0)
            .frame(width: 46, height: 46)
            .background(
                ZStack {
                    // Dark high-contrast glass base
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.08).opacity(0.55))

                    // Translucent glass fill with theme tint
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.28),
                                    accentColor.opacity(0.24),
                                    .white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // Shimmer
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.60), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .offset(x: shimmer * 42)
                        .clipped()
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.75), .white.opacity(0.30), accentColor.opacity(0.60)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            // Multi-layered deep contrast shadows
            .shadow(color: Color.black.opacity(0.55), radius: 14, x: 0, y: 8) // Deep ambient drop shadow
            .shadow(color: Color.black.opacity(0.40), radius: 5, x: 0, y: 2)  // Crisp contact shadow
            .shadow(color: accentColor.opacity(0.50), radius: 8, x: 0, y: 3)  // Vibrant theme aura
            .offset(y: yOffset)
            .opacity(opacity)
    }
}

// MARK: - NSVisualEffectView Wrapper

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
