// this file used for window preview icon plus full screen preview
import SwiftUI
import AppKit

// MARK: - Window Preview Icon (for list rows)

struct WindowPreviewIcon: View {
    let record: WindowRecord
    let tint: Color

    private let displayW: CGFloat = 52
    private let displayH: CGFloat = 34
    private let cornerR: CGFloat = 4

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ── Screen bezel ──────────────────────────────────
            RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                .fill(Color.primary.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                        .stroke(tint.opacity(0.2), lineWidth: 0.75) // Theme-colored bezel
                }

            // ── Window rectangle ──────────────────────────────
            GeometryReader { geo in
                let screenFrame = record.screenFrame
                    ?? NSScreen.main?.frame
                    ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)

                let canvasW = geo.size.width
                let canvasH = geo.size.height

                let scaleX = canvasW / screenFrame.width
                let scaleY = canvasH / screenFrame.height

                let displayFrame = record.previewDisplayFrame
                let relX = (displayFrame.origin.x - screenFrame.origin.x) * scaleX
                let relY = (screenFrame.height
                            - (displayFrame.origin.y - screenFrame.origin.y)
                            - displayFrame.height) * scaleY
                let winW  = min(canvasW, max(6, displayFrame.width  * scaleX))
                let winH  = min(canvasH, max(5, displayFrame.height * scaleY))
                let isFilled = winW >= canvasW * 0.92 && winH >= canvasH * 0.92
                let winCorner: CGFloat = isFilled ? cornerR : 2

                ZStack(alignment: .topLeading) {
                    // Window body
                    RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                        .fill(tint.opacity(isFilled ? 0.28 : 0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                                .stroke(tint.opacity(0.8), lineWidth: 0.75)
                        }
                    
                    // Abstract Content Blocks
                    VStack(alignment: .leading, spacing: 2) {
                        // Title bar with dots
                        HStack(spacing: 1.5) {
                            Circle().fill(tint.opacity(0.6)).frame(width: 1.5, height: 1.5)
                            Circle().fill(tint.opacity(0.4)).frame(width: 1.5, height: 1.5)
                            Circle().fill(tint.opacity(0.4)).frame(width: 1.5, height: 1.5)
                        }
                        .padding(.leading, 2)
                        .padding(.top, 1)
                        
                        // Body bars
                        if winH > 10 {
                            VStack(alignment: .leading, spacing: 2) {
                                RoundedRectangle(cornerRadius: 0.5).fill(tint.opacity(0.2)).frame(width: winW * 0.6, height: 1.5)
                                RoundedRectangle(cornerRadius: 0.5).fill(tint.opacity(0.15)).frame(width: winW * 0.8, height: 1.5)
                                RoundedRectangle(cornerRadius: 0.5).fill(tint.opacity(0.1)).frame(width: winW * 0.4, height: 1.5)
                            }
                            .padding(.leading, 3)
                            .padding(.top, 1)
                        }
                    }
                }
                .frame(width: winW, height: winH)
                .offset(x: relX, y: relY)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: record.globalFrame)
            }
        }
        // Flexible frame: honours an explicit parent-provided size (e.g. WindowGridCard's 68×44)
        // while defaulting to displayW×displayH when no size is imposed.
        .frame(
            minWidth: displayW, idealWidth: displayW, maxWidth: .infinity,
            minHeight: displayH, idealHeight: displayH, maxHeight: .infinity
        )
    }
}

// MARK: - Full-Screen Window Preview Icon & Glyph

struct MacOSFullScreenGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        guard size > 0 else { return Path() }
        let originX = rect.minX + (rect.width - size) / 2
        let originY = rect.minY + (rect.height - size) / 2
        let r = size * 0.11

        var path = Path()

        // Top-left triangle
        let p0 = CGPoint(x: originX, y: originY)
        let p1 = CGPoint(x: originX + size * 0.72, y: originY)
        let p2 = CGPoint(x: originX, y: originY + size * 0.72)
        path.move(to: CGPoint(x: originX, y: (p2.y + p0.y) / 2))
        path.addArc(tangent1End: p0, tangent2End: p1, radius: r)
        path.addArc(tangent1End: p1, tangent2End: p2, radius: r)
        path.addArc(tangent1End: p2, tangent2End: p0, radius: r)
        path.closeSubpath()

        // Bottom-right triangle
        let q0 = CGPoint(x: originX + size, y: originY + size)
        let q1 = CGPoint(x: originX + size * 0.28, y: originY + size)
        let q2 = CGPoint(x: originX + size, y: originY + size * 0.28)
        path.move(to: CGPoint(x: originX + size, y: (q2.y + q0.y) / 2))
        path.addArc(tangent1End: q0, tangent2End: q1, radius: r)
        path.addArc(tangent1End: q1, tangent2End: q2, radius: r)
        path.addArc(tangent1End: q2, tangent2End: q0, radius: r)
        path.closeSubpath()

        return path
    }
}

struct FullScreenPreviewIcon: View {
    var tint: Color = .green
    private let displayW: CGFloat = 52
    private let displayH: CGFloat = 34

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let actualW = w > 0 ? w : displayW
            let actualH = h > 0 ? h : displayH
            let r: CGFloat = max(2.5, min(actualW, actualH) * 0.12)
            let glyphSize: CGFloat = max(6, min(actualW * 0.34, actualH * 0.44))

            ZStack {
                // Screen bezel — fully filled with green tint
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .stroke(tint.opacity(0.7), lineWidth: 0.75)
                    }

                // Centered macOS native full-screen glyph
                MacOSFullScreenGlyph()
                    .fill(tint.opacity(0.9))
                    .frame(width: glyphSize, height: glyphSize)
            }
            .frame(width: actualW, height: actualH)
        }
        .frame(minWidth: 24, idealWidth: displayW, maxWidth: 82, minHeight: 16, idealHeight: displayH, maxHeight: 52)
    }
}

// MARK: - App Icon Color Cache & Extraction

struct IconTintInfo {
    let color: Color
    let isDark: Bool
}

final class AppIconColorCache {
    static let shared = AppIconColorCache()
    private var cache = [String: IconTintInfo]()
    private var iconCache = [String: NSImage]()
    private let lock = NSLock()
    
    private init() {}
    
    static func appIcon(for bundleID: String, appName: String? = nil) -> NSImage? {
        shared.cachedAppIcon(for: bundleID, appName: appName)
    }

    func cachedAppIcon(for bundleID: String, appName: String? = nil) -> NSImage? {
        let key = "\(bundleID)|\(appName ?? "")"
        lock.lock()
        if let cached = iconCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = resolveAppIcon(for: bundleID, appName: appName)
        if let image {
            lock.lock()
            iconCache[key] = image
            lock.unlock()
        }
        return image
    }

    private func resolveAppIcon(for bundleID: String, appName: String?) -> NSImage? {
        // 1. Standard NSWorkspace lookup — works for .app bundles in /Applications
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // 2. Running-app icon — works for Chrome PWAs, Electron apps, anything currently running
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID || (appName != nil && $0.localizedName == appName)
        }), let icon = runningApp.icon {
            return icon
        }
        // 3. Fallback by app name lookup
        if let appName = appName, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // 4. Common app directories search for WebApps or user apps
        if let appName = appName, !appName.isEmpty {
            let fileManager = FileManager.default
            let searchDirectories = [
                fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
                fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Safari Web Apps", isDirectory: true),
                fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Chrome Apps.localized", isDirectory: true),
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/System/Applications", isDirectory: true)
            ]
            for dir in searchDirectories {
                let appPath = dir.appendingPathComponent("\(appName).app")
                if fileManager.fileExists(atPath: appPath.path) {
                    return NSWorkspace.shared.icon(forFile: appPath.path)
                }
            }
        }
        return nil
    }
    
    func tintInfo(for bundleID: String) -> IconTintInfo? {
        lock.lock()
        if let cached = cache[bundleID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        guard let image = Self.appIcon(for: bundleID) else {
            return nil
        }
        
        let info = extractTintInfo(from: image)
        lock.lock()
        cache[bundleID] = info
        lock.unlock()
        return info
    }
    
    func dominantColor(for bundleID: String) -> Color? {
        return tintInfo(for: bundleID)?.color
    }
    
    private func extractTintInfo(from image: NSImage) -> IconTintInfo {
        let size = CGSize(width: 24, height: 24)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: Int(size.width) * 4,
            bitsPerPixel: 32
        ) else {
            return IconTintInfo(color: Color(white: 0.8), isDark: false)
        }
        
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return IconTintInfo(color: Color(white: 0.8), isDark: false)
        }
        NSGraphicsContext.current = context
        image.draw(
            in: CGRect(origin: .zero, size: size),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()
        
        guard let data = rep.bitmapData else {
            return IconTintInfo(color: Color(white: 0.8), isDark: false)
        }
        
        var bestVibrantColor: Color? = nil
        var highestVibrantScore: CGFloat = 0
        var vibrantPixelCount = 0
        
        var totalWeightedR: CGFloat = 0
        var totalWeightedG: CGFloat = 0
        var totalWeightedB: CGFloat = 0
        var totalWeight: CGFloat = 0
        
        var darkPixelCount = 0
        var lightPixelCount = 0
        
        let totalPixels = Int(size.width) * Int(size.height)
        
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = CGFloat(data[offset]) / 255.0
            let g = CGFloat(data[offset + 1]) / 255.0
            let b = CGFloat(data[offset + 2]) / 255.0
            let a = CGFloat(data[offset + 3]) / 255.0
            
            // Ignore mostly transparent / edge pixels
            guard a > 0.35 else { continue }
            
            let nsColor = NSColor(deviceRed: r, green: g, blue: b, alpha: a)
            var hue: CGFloat = 0
            var sat: CGFloat = 0
            var bri: CGFloat = 0
            var alp: CGFloat = 0
            nsColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alp)
            
            // Accumulate weighted tone
            totalWeightedR += r * a
            totalWeightedG += g * a
            totalWeightedB += b * a
            totalWeight += a
            
            if bri < 0.30 {
                darkPixelCount += 1
            } else if bri > 0.70 {
                lightPixelCount += 1
            }
            
            // Check for vibrant accent (Spotify green, Safari blue, Slack colors, etc.)
            if sat > 0.16 && bri > 0.12 && bri < 0.98 {
                vibrantPixelCount += 1
                let score = sat * 1.8 + (1.0 - abs(bri - 0.55))
                if score > highestVibrantScore {
                    highestVibrantScore = score
                    bestVibrantColor = Color(nsColor: nsColor)
                }
            }
        }
        
        // Tier 1: Vibrant Accent found with high confidence
        if let vibrant = bestVibrantColor, highestVibrantScore > 0.35, vibrantPixelCount >= 4 {
            return IconTintInfo(color: vibrant, isDark: false)
        }
        
        // Tier 2: Abnormal / Neutral tones (Monochrome, Dark, Black, Silver, White)
        guard totalWeight > 0 else {
            return IconTintInfo(color: Color(white: 0.8), isDark: false)
        }
        
        let avgR = totalWeightedR / totalWeight
        let avgG = totalWeightedG / totalWeight
        let avgB = totalWeightedB / totalWeight
        let avgBri = (avgR * 0.299 + avgG * 0.587 + avgB * 0.114)
        
        // Dark / Charcoal / Smoked (Terminal, Cursor, GitHub, Obsidian)
        if avgBri < 0.35 || (darkPixelCount > (lightPixelCount * 2) && darkPixelCount > 30) {
            let darkR = min(0.18, max(0.06, avgR))
            let darkG = min(0.18, max(0.06, avgG))
            let darkB = min(0.20, max(0.07, avgB))
            return IconTintInfo(
                color: Color(red: darkR, green: darkG, blue: darkB),
                isDark: true
            )
        }
        
        // Light / Silver / White (System Settings, Calculator)
        if avgBri >= 0.65 {
            let lightR = max(0.82, min(0.95, avgR))
            let lightG = max(0.82, min(0.95, avgG))
            let lightB = max(0.84, min(0.96, avgB))
            return IconTintInfo(
                color: Color(red: lightR, green: lightG, blue: lightB),
                isDark: false
            )
        }
        
        // Mid-tone slate / graphite
        return IconTintInfo(
            color: Color(red: avgR, green: avgG, blue: avgB),
            isDark: false
        )
    }
}

// MARK: - Main Window Icon Interaction

enum MainWindowSymbolEffect {
    case wiggle
    case wiggleByLayer
    case rotate
    case rotateCounterClockwise
    case flip
    case breathe
    case breathePlain
    case pulse
    case pulseByLayer
    case variableColor
    case variableColorCumulative
}

/// The hover state of the control that owns a symbol. Keeping this in the
/// environment means a symbol can animate when the pointer is over its whole
/// Button, Label, or row instead of only when it is over the glyph itself.
struct MainWindowIconHoverRegion {
    var isDefined = false
    var isHovered = false
}

private struct MainWindowIconHoverRegionKey: EnvironmentKey {
    static let defaultValue = MainWindowIconHoverRegion()
}

extension EnvironmentValues {
    var mainWindowIconHoverRegion: MainWindowIconHoverRegion {
        get { self[MainWindowIconHoverRegionKey.self] }
        set { self[MainWindowIconHoverRegionKey.self] = newValue }
    }
}

private struct MainWindowIconHoverRegionModifier: ViewModifier {
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { hovering in
                guard controlActiveState == .key || !hovering else { return }
                isHovered = hovering
            }
            .onChange(of: controlActiveState) { _, newState in
                if newState != .key {
                    isHovered = false
                }
            }
            .environment(
                \.mainWindowIconHoverRegion,
                MainWindowIconHoverRegion(isDefined: true, isHovered: isHovered)
            )
    }
}

extension View {
    /// Makes the entire view the hover target for descendant main-window
    /// symbols. Apply this to the owning Button, Label, or row.
    func mainWindowSymbolHoverRegion() -> some View {
        modifier(MainWindowIconHoverRegionModifier())
    }
}

/// Applies a semantic native SF Symbol effect to an icon in the main window.
/// The effect plays once when the pointer enters or the icon is clicked,
/// without changing the action owned by the surrounding control or row.
struct MainWindowSymbolAnimation: ViewModifier {
    let effect: MainWindowSymbolEffect
    let capturesClicks: Bool
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.mainWindowIconHoverRegion) private var hoverRegion
    @Environment(\.minimalVisualAnimationsEnabled) private var minimalVisualAnimationsEnabled
    @State private var isHovered = false
    @State private var animationTrigger = 0
    @State private var isFlipping = false

    private var shouldReduceMotion: Bool {
        minimalVisualAnimationsEnabled
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let animated = interactiveContent(animatedContent(content))
        if hoverRegion.isDefined {
            animated
                .onChange(of: hoverRegion.isHovered) { _, hovering in
                    if hovering && controlActiveState == .key {
                        triggerAnimation()
                    }
                }
        } else {
            animated
                .onHover { hovering in
                    guard controlActiveState == .key || !hovering else { return }
                    if hovering && !isHovered {
                        triggerAnimation()
                    }
                    isHovered = hovering
                }
                .onChange(of: controlActiveState) { _, newState in
                    if newState != .key {
                        isHovered = false
                    }
                }
        }
    }

    @ViewBuilder
    private func interactiveContent<V: View>(_ content: V) -> some View {
        if capturesClicks {
            content.simultaneousGesture(
                TapGesture().onEnded {
                    triggerAnimation()
                },
                including: .gesture
            )
        } else {
            content
        }
    }

    @ViewBuilder
    private func animatedContent(_ content: Content) -> some View {
        if shouldReduceMotion {
            content
        } else if #available(macOS 15.0, *) {
            switch effect {
            case .wiggle:
                content.symbolEffect(.wiggle, options: .speed(0.85), value: animationTrigger)
            case .wiggleByLayer:
                content.symbolEffect(.wiggle.byLayer, options: .speed(0.9), value: animationTrigger)
            case .rotate:
                content.symbolEffect(.rotate.clockwise, options: .speed(0.75), value: animationTrigger)
            case .rotateCounterClockwise:
                content.symbolEffect(.rotate.counterClockwise, options: .speed(0.75), value: animationTrigger)
            case .flip:
                flipContent(content)
            case .breathe:
                content.symbolEffect(.breathe.pulse, options: .speed(0.8), value: animationTrigger)
            case .breathePlain:
                content.symbolEffect(.breathe.plain, options: .speed(0.8), value: animationTrigger)
            case .pulse:
                pulseContent(content)
            case .pulseByLayer:
                pulseByLayerContent(content)
            case .variableColor:
                variableColorContent(content)
            case .variableColorCumulative:
                variableColorCumulativeContent(content)
            }
        } else {
            fallbackContent(content)
        }
    }

    @ViewBuilder
    private func fallbackContent(_ content: Content) -> some View {
        switch effect {
        case .pulse, .wiggle, .rotate, .rotateCounterClockwise, .breathe, .breathePlain:
            pulseContent(content)
        case .flip:
            flipContent(content)
        case .pulseByLayer, .wiggleByLayer:
            pulseByLayerContent(content)
        case .variableColor:
            variableColorContent(content)
        case .variableColorCumulative:
            variableColorCumulativeContent(content)
        }
    }

    private func pulseContent(_ content: Content) -> some View {
        content
            .symbolEffect(.pulse, options: .speed(0.9), value: animationTrigger)
    }

    private func triggerAnimation() {
        guard !shouldReduceMotion else { return }

        switch effect {
        case .flip:
            isFlipping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                isFlipping = false
            }
        default:
            animationTrigger &+= 1
        }
    }

    private func flipContent(_ content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isFlipping ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .animation(.smooth(duration: 0.34), value: isFlipping)
    }

    private func pulseByLayerContent(_ content: Content) -> some View {
        content
            .symbolEffect(.pulse.byLayer, options: .speed(0.95), value: animationTrigger)
    }

    private func variableColorContent(_ content: Content) -> some View {
        content
            .symbolEffect(
                .variableColor.iterative.reversing,
                options: .speed(0.85),
                value: animationTrigger
            )
    }

    private func variableColorCumulativeContent(_ content: Content) -> some View {
        content
            .symbolEffect(
                .variableColor.cumulative,
                options: .speed(0.9),
                value: animationTrigger
            )
    }
}

extension View {
    func mainWindowSymbolAnimation(
        _ effect: MainWindowSymbolEffect = .pulse,
        capturesClicks: Bool = true
    ) -> some View {
        modifier(MainWindowSymbolAnimation(effect: effect, capturesClicks: capturesClicks))
    }
}

// MARK: - Layout Preview View (for detail view)

struct AppIconView: View {
    let bundleID: String

    var body: some View {
        let image: NSImage? = AppIconColorCache.appIcon(for: bundleID)
        
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
        }
    }
}

struct LayoutPreviewView: View {
    let snapshot: LayoutSnapshot
    let selectedRecordID: UUID?
    let tint: Color
    var enable3DHover: Bool = false
    /// Reveals the classic preview's windows into their saved positions once
    /// when the containing preview appears. Kept opt-in so the main window's
    /// existing preview behavior remains unchanged.
    var animateWindowReveal: Bool = false
    var isMainWindow: Bool = false
    var isMenubarThumbnail: Bool = false
    /// Enables the border treatment only for the main Window Arrangement preview.
    var isWindowArrangementPreview: Bool = false
    var isMinimalVisualAnimations: Bool? = nil
    var triggeringRecordIDs: Set<UUID> = []
    var triggeringBundleIDs: Set<String> = []
    var triggeringAppNames: Set<String> = []
    /// The capture indicator type when shown inside AutoSavePreviewCardView.
    /// `.history` = run full animation for all windows even under minimal animations.
    /// `.addedWindows` / `.sameWindowCount` = show only triggering windows under minimal animations.
    var captureIndicator: AutoLayoutCaptureIndicator? = nil
    var revealTrigger: UUID? = nil
    
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.minimalVisualAnimationsEnabled) private var minimalVisualAnimationsEnabled
    
    @State private var isHovered: Bool = false
    @State private var hoveredRecordID: UUID? = nil
    @State private var cursorHorizontalPosition: CGFloat = 0.5
    /// Tracks which edge the cursor entered the center zone from: true = entered from left, false = entered from right
    @State private var centerEnteredFromLeft: Bool = true
    @State private var isPlayingIntro: Bool = false
    @State private var introTask: Task<Void, Never>? = nil
    @State private var revealedRecordIDs: Set<UUID> = []
    @State private var currentlyPoppingRecordID: UUID? = nil
    @State private var windowRevealTask: Task<Void, Never>? = nil

    private var windowRevealCount: Int {
        max(snapshot.previewRecords.count, 1)
    }

    private var isIsolatedCapture: Bool {
        guard let indicator = captureIndicator else { return false }
        switch indicator {
        case .addedWindows, .sameWindowCount:
            return true
        case .history, .displayConnected, .displayDisconnected:
            return false
        }
    }

    private var effectiveMinimalVisualAnimations: Bool {
        // History and Display Connection/Disconnection captures always use the full animation, even when the
        // global reduced-animations setting is ON.
        if case .history = captureIndicator { return false }
        if case .displayConnected = captureIndicator { return false }
        if case .displayDisconnected = captureIndicator { return false }
        return isMinimalVisualAnimations ?? minimalVisualAnimationsEnabled
    }

    private var usesFlatPreview: Bool {
        // If Minimal Visuals is ON, always use flat 2D canvas
        if isMinimalVisualAnimations ?? minimalVisualAnimationsEnabled {
            return true
        }
        // Isolated captures (green + / blue resize) where only specific windows are highlighted always use flat 2D
        if isIsolatedCapture {
            return true
        }
        // For the main Window Arrangement preview with full windows (and when not browsing earlier captures),
        // activate the rich 3D holographic perspective hover effect.
        if isWindowArrangementPreview && enable3DHover {
            return false
        }
        // Compact thumbnails and history list fallbacks use the flat 2D canvas.
        return true
    }

    private func isTriggeringRecord(_ record: WindowRecord) -> Bool {
        // 1. Exact record-ID match
        if triggeringRecordIDs.contains(record.id) {
            return true
        }

        // 2. Fallback: if exact-ID-matched records are off-canvas or were filtered from previewRecords,
        // match any on-canvas window of the same triggering app.
        if !triggeringRecordIDs.isEmpty {
            let triggeringBundleIDsFromRecords = Set(
                snapshot.records
                    .filter { triggeringRecordIDs.contains($0.id) }
                    .map { $0.windowID.appBundleID }
            )
            if triggeringBundleIDsFromRecords.contains(record.windowID.appBundleID) {
                return true
            }
        }

        // 3. Match by activity app bundle ID or app name
        if !triggeringBundleIDs.isEmpty, triggeringBundleIDs.contains(record.windowID.appBundleID) {
            return true
        }
        if let appName = record.windowID.appName, !appName.isEmpty, triggeringAppNames.contains(appName) {
            return true
        }
        return false
    }

    /// Sequential reveal duration per window (extended to match pacing).
    private var denseRevealWindowDuration: Double {
        0.30
    }

    var body: some View {
        Group {
            if !enable3DHover || usesFlatPreview {
                classic2DBody
            } else {
                interactive3DBody
            }
        }
        .onAppear {
            startWindowReveal()
        }
        .onDisappear {
            windowRevealTask?.cancel()
            windowRevealTask = nil
            revealedRecordIDs.removeAll()
            currentlyPoppingRecordID = nil
        }
        .onChange(of: snapshot.id) { _, _ in
            if animateWindowReveal {
                startWindowReveal()
            }
        }
        .onChange(of: captureIndicator) { _, _ in
            if animateWindowReveal {
                startWindowReveal()
            }
        }
        .onChange(of: usesFlatPreview) { _, _ in
            if animateWindowReveal {
                startWindowReveal()
            }
        }
        .onChange(of: revealTrigger) { _, _ in
            if animateWindowReveal {
                startWindowReveal()
            }
        }
        .onHover { isCardHovered in
            if isCardHovered && animateWindowReveal {
                startWindowReveal()
            }
        }
        .transaction { transaction in
            if animateWindowReveal {
                transaction.disablesAnimations = false
            }
        }
    }

    private func startWindowReveal() {
        windowRevealTask?.cancel()
        windowRevealTask = nil
        revealedRecordIDs.removeAll()
        currentlyPoppingRecordID = nil

        guard animateWindowReveal else {
            revealedRecordIDs = Set(snapshot.previewRecords.map(\.id))
            currentlyPoppingRecordID = nil
            return
        }

        // Both Menubar thumbnail and Window Arrangement use 350ms pacing for a consistent rhythm.
        let useMinimalPop = isMenubarThumbnail
        let stepNanoseconds: UInt64 = 350_000_000
        let initialDelayNanoseconds: UInt64 = isMenubarThumbnail ? 250_000_000 : 0
        let allRecords = backgroundFirstPreviewRecords

        // For isolated captures (addedWindows / sameWindowCount):
        // Always isolate the triggering window(s), regardless of minimalVisualAnimations setting.
        if isIsolatedCapture {
            let triggeringRecords = allRecords.filter { isTriggeringRecord($0) }

            guard !triggeringRecords.isEmpty else {
                revealedRecordIDs = Set(allRecords.map(\.id))
                return
            }

            // Animate only the window(s) of the app that triggered the capture
            windowRevealTask = Task { @MainActor in
                await Task.yield()

                if initialDelayNanoseconds > 0 {
                    do {
                        try await Task.sleep(nanoseconds: initialDelayNanoseconds)
                    } catch {
                        return
                    }
                }
                guard !Task.isCancelled else { return }

                for (idx, record) in triggeringRecords.enumerated() {
                    if idx > 0 {
                        do {
                            try await Task.sleep(nanoseconds: stepNanoseconds)
                        } catch {
                            return
                        }
                    }

                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: useMinimalPop ? 0.25 : denseRevealWindowDuration)) {
                        currentlyPoppingRecordID = record.id
                        revealedRecordIDs.insert(record.id)
                    }
                }

                do {
                    try await Task.sleep(nanoseconds: stepNanoseconds)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: useMinimalPop ? 0.35 : denseRevealWindowDuration)) {
                    currentlyPoppingRecordID = nil
                }
            }
            return
        }

        // When reduced animations is ON for non-isolated layouts (e.g. Saved Sessions):
        if effectiveMinimalVisualAnimations {
            revealedRecordIDs = Set(allRecords.map(\.id))
            currentlyPoppingRecordID = nil
            return
        }

        // Full animations mode (e.g. .history captures or normal motion): sequentially reveal and pop all windows
        windowRevealTask = Task { @MainActor in
            await Task.yield()

            if initialDelayNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: initialDelayNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }

            for (index, record) in allRecords.enumerated() {
                if index > 0 {
                    do {
                        try await Task.sleep(nanoseconds: stepNanoseconds)
                    } catch {
                        return
                    }
                }

                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: useMinimalPop ? 0.25 : denseRevealWindowDuration)) {
                    currentlyPoppingRecordID = record.id
                    revealedRecordIDs.insert(record.id)
                }
            }

            do {
                try await Task.sleep(nanoseconds: stepNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: useMinimalPop ? 0.35 : denseRevealWindowDuration)) {
                currentlyPoppingRecordID = nil
            }
        }
    }

    // MARK: - Classic 2D Preview (Exact restoration from last week for Saved Sessions & Inspector Mini-Map)
    
    private var classic2DBody: some View {
        Group {
            if isMenubarThumbnail {
                classic2DCanvas
                    .padding(10)
            } else {
                classic2DCanvas
                    .padding(10)
                    .liquidGlass(cornerRadius: 14, style: .card)
            }
        }
    }

    private var classic2DCanvas: some View {
        GeometryReader { geo in
            let boundingBox = calculateBoundingBox()
            let scale = calculateScale(for: geo.size, boundingBox: boundingBox)
            let layoutWidth = boundingBox.width * scale
            let layoutHeight = boundingBox.height * scale
            let offsetX = max(0, (geo.size.width - layoutWidth) / 2)
            let offsetY = max(0, (geo.size.height - layoutHeight) / 2)
            let revealEnabled = animateWindowReveal
            let backgroundFirstRecords = backgroundFirstPreviewRecords
            // For addedWindows/sameWindowCount, hide all
            // non-triggering windows entirely — only the triggering app is visible.
            let hidingNonTriggeringWindows = isIsolatedCapture

            ZStack {
                // Screens
                ForEach(Array(getScreenFrames().enumerated()), id: \.offset) { _, frame in
                    classicScreenView(
                        frame: frame,
                        boundingBox: boundingBox,
                        scale: scale,
                        offsetX: offsetX,
                        offsetY: offsetY
                    )
                }

                // Windows
                ForEach(Array(backgroundFirstRecords.enumerated()), id: \.element.id) { revealIndex, record in
                    let isTarget = isTriggeringRecord(record)
                    // Skip non-triggering windows completely when in isolated mode
                    if hidingNonTriggeringWindows && !isTarget { EmptyView() } else {
                        let isWaiting = revealEnabled && (isIsolatedCapture ? (isTarget && !revealedRecordIDs.contains(record.id)) : !revealedRecordIDs.contains(record.id))
                        let isPopping = isIsolatedCapture
                            ? (isTarget && record.id == currentlyPoppingRecordID)
                            : (record.id == currentlyPoppingRecordID)
                        classicWindowView(
                            record: record,
                            boundingBox: boundingBox,
                            scale: scale,
                            offsetX: offsetX,
                            offsetY: offsetY,
                            revealEnabled: revealEnabled,
                            isWaitingToReveal: isWaiting,
                            revealIndex: revealIndex,
                            isCurrentlyPopping: isPopping
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// `zIndex` is captured with 0 as the front-most window. Reveal the
    /// background first so foreground windows do not hide the rest of the
    /// arrangement before the user has had a chance to see it.
    private var backgroundFirstPreviewRecords: [WindowRecord] {
        let records = snapshot.previewRecords
        return records.enumerated().sorted { lhs, rhs in
            let lhsZIndex = lhs.element.zIndex ?? Int.max
            let rhsZIndex = rhs.element.zIndex ?? Int.max
            if lhsZIndex != rhsZIndex {
                return lhsZIndex > rhsZIndex
            }
            // Older snapshots can have no zIndex values. Their records keep
            // capture order (front-to-back), so reverse that order for the
            // background-first reveal as well.
            return lhs.offset > rhs.offset
        }.map(\.element)
    }
    
    private func classicScreenView(
        frame: CGRect,
        boundingBox: CGRect,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let x = offsetX + (frame.origin.x - boundingBox.origin.x) * scale
        let y = offsetY + (boundingBox.height - (frame.origin.y - boundingBox.origin.y + frame.height)) * scale
        let w = frame.width * scale
        let h = frame.height * scale
        
        let cornerR: CGFloat = 10 * scale
        
        return ZStack {
            // Main Panel
            RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                .fill(Color(red: 0.04, green: 0.07, blue: 0.18).opacity(0.85))
            
            // Inner glow / bezel detail
            RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12), Color.white.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .frame(width: w, height: h)
        .position(x: x + w/2, y: y + h/2)
    }
    
    private func classicWindowView(
        record: WindowRecord,
        boundingBox: CGRect,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        revealEnabled: Bool,
        isWaitingToReveal: Bool,
        revealIndex: Int,
        isCurrentlyPopping: Bool = false
    ) -> some View {
        let isSelected = record.id == selectedRecordID
        let isHovered = record.id == hoveredRecordID
        let isHighlighted = isSelected || isHovered
        let isMinimal = isMenubarThumbnail
        let displayFrame = record.previewDisplayFrame
        let x = offsetX + (displayFrame.origin.x - boundingBox.origin.x) * scale
        let y = offsetY + (boundingBox.height - (displayFrame.origin.y - boundingBox.origin.y + displayFrame.height)) * scale
        let w = displayFrame.width * scale
        let h = displayFrame.height * scale
        
        let isFullScreen = record.isFullScreenMode
        // Match Theme Colors (Use high-contrast slate for Black theme so preview window cards remain visible)
        // Full screen windows are rendered green with the centered native macOS symbol
        let baseTint = isFullScreen ? Color.green : ((tint == .black || tint == Color.black) ? Color(white: 0.8) : tint)
        let winCorner: CGFloat = max(4, 8 * scale)
        let baseSize: CGFloat = min(max(w * 0.24, 20.0), 30.0)
        let iconSize: CGFloat = min(baseSize, max(8.0, min(w - 3, h - 3)))
        let revealScale: CGFloat = !isMinimal && isWaitingToReveal ? 0.97 : 1.0
        let revealOffsetY: CGFloat = !isMinimal && isWaitingToReveal ? 6.0 : 0.0
        let foregroundProgress: Double = {
            guard windowRevealCount > 1 else { return 1.0 }
            return Double(revealIndex) / Double(windowRevealCount - 1)
        }()
        let isTarget = isTriggeringRecord(record)
        // Under minimal/reduced animations, non-target windows use a flat, dim
        // border so the foreground-most window (e.g. TV covering the entire screen)
        // doesn't get a nearly-full-opacity theme-tint border that looks highlighted.
        let foregroundBorderOpacity: Double = {
            if isHighlighted { return 1.0 }
            if isIsolatedCapture && !isTarget {
                return 0.45  // quiet baseline — won't look "selected"
            }
            return revealEnabled ? 0.65 + foregroundProgress * 0.35 : 0.65
        }()
        let isPoppingNow = isCurrentlyPopping && !isWaitingToReveal
        let pulsesArrivalBorder = isMinimal || isWindowArrangementPreview
        let windowBorderWidth: CGFloat = {
            if pulsesArrivalBorder && isPoppingNow { return 3.0 }
            if isMinimal { return 0.8 }
            return isHighlighted ? 1.5 : 0.8
        }()
        let revealOpacity: Double = isWaitingToReveal ? 0.0 : 1.0
        let foregroundFadeDuration = denseRevealWindowDuration
        let revealAnimation: Animation? = {
            guard revealEnabled else { return nil }
            if isMinimal {
                return .easeInOut(duration: 0.35)
            }
            return .easeInOut(duration: foregroundFadeDuration)
        }()

        let bodyFillOpacity: Double = {
            if isHighlighted {
                return isMinimal ? 0.65 : 0.45
            }
            if isIsolatedCapture {
                // For isolated captures, only the actively-popping target window
                // gets the bright theme-tint fill.
                if isPoppingNow { return 0.60 }
                return isTarget ? 0.18 : 0.14
            }
            if isPoppingNow { return 0.50 }
            return 0.22
        }()

        let windowVisual = ZStack(alignment: .topLeading) {
            // Window body with theme-colored glass
            RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                .fill(isPoppingNow ? Color(nsColor: .windowBackgroundColor) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                        .fill(baseTint.opacity(bodyFillOpacity))
                }
                .overlay {
                    // Vibrant theme-colored border
                    if pulsesArrivalBorder {
                        RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                            .stroke(baseTint.opacity(foregroundBorderOpacity), lineWidth: windowBorderWidth)
                            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isPoppingNow)
                    } else {
                        RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                            .stroke(baseTint.opacity(foregroundBorderOpacity), lineWidth: windowBorderWidth)
                    }
                }
                .shadow(color: isHighlighted ? baseTint.opacity(0.5) : Color.black.opacity(0.35), radius: isHighlighted ? 6 : 2.5, x: 0, y: 1)
            
            // Centered macOS native full-screen glyph in the middle of the window dimensions
            if isFullScreen {
                let glyphSize = min(max(min(w, h) * 0.26, 9), min(w - 2, h - 2), 30)
                MacOSFullScreenGlyph()
                    .fill(Color.green.opacity(0.85))
                    .frame(width: glyphSize, height: glyphSize)
                    .position(x: max(8, w) / 2, y: max(8, h) / 2)
            }

            // Top-left App Icon badge with inline app name on hover or selection
            if w >= 12 && h >= 10 {
                HStack(spacing: 4) {
                    AppIconView(bundleID: record.windowID.appBundleID)
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: max(2.5, 3.5 * scale), style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: max(2.5, 3.5 * scale), style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)

                    if isHighlighted && w > 52 {
                        Text(record.windowID.appName?.prefix(14) ?? "")
                            .font(.system(size: max(7.5, 9 * scale), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(Color.black.opacity(0.65))
                            }
                            .shadow(color: .black.opacity(0.6), radius: 2)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.leading, 2.5)
                .padding(.top, 1.5)
            }
        }

        return ZStack {
            windowVisual
                .animation(.easeInOut(duration: 0.25), value: isPoppingNow)
                .frame(width: max(8, w), height: max(8, h))
                .opacity(revealOpacity)
                .animation(isMinimal ? .easeInOut(duration: 0.25) : revealAnimation, value: isWaitingToReveal)
        }
        .frame(width: max(8, w), height: max(8, h))
        .position(x: x + w/2, y: y + h/2)
        .scaleEffect(revealScale * (isHighlighted ? 1.04 : 1.0))
        .offset(y: revealOffsetY)
        .onHover { hovering in
            guard !isMinimal else { return }
            if usesFlatPreview {
                hoveredRecordID = hovering ? record.id : nil
            } else {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    hoveredRecordID = hovering ? record.id : nil
                }
            }
        }
        .animation(
            usesFlatPreview ? nil : .spring(response: 0.4, dampingFraction: 0.7),
            value: record.globalFrame
        )
        .animation(
            usesFlatPreview ? nil : .spring(response: 0.3, dampingFraction: 0.6),
            value: isHighlighted
        )
        .animation(
            revealEnabled && !isMinimal
                ? .easeInOut(duration: denseRevealWindowDuration)
                : nil,
            value: isWaitingToReveal
        )
    }
    
    // MARK: - Interactive 3D Preview (For Auto Layout Mode)
    
    private var interactive3DBody: some View {
        GeometryReader { geo in
            let boundingBox = calculateBoundingBox()
            let scale = calculateScale(for: geo.size, boundingBox: boundingBox)
            let is3D = isHovered && enable3DHover
            
            let layoutW = boundingBox.width * scale
            let layoutH = boundingBox.height * scale
            let centerOffsetX = max(0, (geo.size.width - layoutW) / 2)
            let centerOffsetY = max(0, (geo.size.height - layoutH) / 2)
            
            let previewRecords = snapshot.previewRecords
            let totalRecords = max(1, previewRecords.count)
            let isSingleScreen = getScreenFrames().count == 1
            let cursorX = Double(cursorHorizontalPosition)

            // Outer zone progressive activation (< 0.25 or > 0.75)
            let leftOuter = max(0.0, (0.25 - cursorX) / 0.25)
            let rightOuter = max(0.0, (cursorX - 0.75) / 0.25)
            let signedOuterOffset = rightOuter - leftOuter
            let outerDistance = max(leftOuter, rightOuter)

            // Center zone peel-off weight: 1.0 inside [0.25, 0.75], smoothly ramps to 0.0 outside boundaries
            let centerZoneWeight: CGFloat = {
                guard is3D else { return 0.0 }
                if cursorX < 0.25 {
                    return max(0.0, min(1.0, CGFloat((cursorX - 0.22) / 0.03)))
                } else if cursorX > 0.75 {
                    return max(0.0, min(1.0, CGFloat((0.78 - cursorX) / 0.03)))
                } else {
                    return 1.0
                }
            }()

            // In center zone [0.25, 0.75], canvas stays straight-on with resting layer spacing
            let dynamicYaw = is3D ? (-signedOuterOffset * 45.0) : 0

            // In center zone [0.25, 0.75], pitch flattens to 0° flush with the screen board
            let dynamicPitch: Double = is3D ? (Double(1.0 - centerZoneWeight) * 14.0) : 0.0

            // Dynamic Layer Step: in outer zones, windows fan in 3D; in center gap, layer spacing flattens to 0 flush on the board
            let dynamicLayerStep: CGFloat = {
                guard is3D else { return 0.0 }
                let base = 14.0 + CGFloat(outerDistance) * 74.0
                let outerStep: CGFloat = {
                    if totalRecords > 6 {
                        let scaled = (base * 6.0) / CGFloat(totalRecords)
                        let minAtPosition = 12.0 + CGFloat(outerDistance) * 36.0
                        return max(minAtPosition, scaled)
                    }
                    return base
                }()
                return (1.0 - centerZoneWeight) * outerStep
            }()
            let maxExplosion = CGFloat(max(0, totalRecords - 1)) * dynamicLayerStep * 0.9

            // Smooth animated zoom-out: one-screen layouts need extra breathing room
            // for the peeled windows, including the outer hover positions.
            let dynamicScale: CGFloat = {
                guard is3D else { return 1.0 }
                let singleScreenReduction: CGFloat = isSingleScreen ? 0.12 : 0.0
                let outerBaseScale = 0.98 + CGFloat(outerDistance) * 0.12 - singleScreenReduction
                let centerZoomOutScale: CGFloat = 0.82 - singleScreenReduction
                return (1.0 - centerZoneWeight) * outerBaseScale + centerZoneWeight * centerZoomOutScale
            }()

            // Map cursor horizontal drift within center zone [0.25, 0.75] to scrub progress [0.0, 1.0].
            // Direction-aware: progress always goes 0→1 front-to-back regardless of which side was entered.
            let scrubProgress: CGFloat = {
                let inCenter = cursorX >= 0.25 && cursorX <= 0.75
                guard inCenter else {
                    // Outside center zone: clamp to 0 or 1 based on which side
                    return cursorX < 0.25 ? 0.0 : 1.0
                }
                if centerEnteredFromLeft {
                    return min(1.0, max(0.0, CGFloat((cursorX - 0.25) / 0.50)))
                } else {
                    return min(1.0, max(0.0, CGFloat((0.75 - cursorX) / 0.50)))
                }
            }()

            // Sort records strictly by z-order rank: index 0 is front-most, last is background
            let frontToBackRecords = previewRecords.sorted { a, b in
                let za = a.zIndex ?? 0
                let zb = b.zIndex ?? 0
                if za != zb { return za > zb }
                let idxA = previewRecords.firstIndex(where: { $0.id == a.id }) ?? 0
                let idxB = previewRecords.firstIndex(where: { $0.id == b.id }) ?? 0
                return idxA > idxB
            }

            // Compute front-to-back peel data for each window
            let peelDataMap: [UUID: WindowPeelData] = {
                guard centerZoneWeight > 0.001, !frontToBackRecords.isEmpty else { return [:] }
                var map: [UUID: WindowPeelData] = [:]
                
                if frontToBackRecords.count == 1 {
                    let rec = frontToBackRecords[0]
                    let scale = 1.0 + CGFloat(scrubProgress) * 0.80 * centerZoneWeight
                    let lift = scrubProgress * 22.0 * centerZoneWeight
                    map[rec.id] = WindowPeelData(
                        scale: scale,
                        liftY: lift,
                        opacity: 1.0,
                        zIndexBoost: 100.0,
                        isPeeling: scrubProgress > 0.05
                    )
                    return map
                }
                
                let stepInterval = 1.0 / CGFloat(totalRecords)
                let flightDuration = stepInterval * 1.12  // Fluid overlap between peeling windows
                
                for (idx, record) in frontToBackRecords.enumerated() {
                    let isLast = (idx == totalRecords - 1)
                    var targetScale: CGFloat = 1.0
                    var targetLiftY: CGFloat = 0.0
                    var targetOpacity: Double = 1.0
                    var targetZBoost: Double = 0.0
                    var targetIsPeeling: Bool = false
                    
                    if !isLast {
                        let startProgress = CGFloat(idx) * stepInterval
                        let localProgress = (scrubProgress - startProgress) / flightDuration
                        
                        if localProgress <= 0.0 {
                            // At rest in stack
                            targetScale = 1.0
                            targetLiftY = 0.0
                            targetOpacity = 1.0
                            targetZBoost = 0.0
                            targetIsPeeling = false
                        } else if localProgress <= 1.0 {
                            // Popping forward and flying past camera
                            let t = localProgress
                            let easeT = t * t * (3.0 - 2.0 * t)
                            targetScale = 1.0 + easeT * 1.6  // Expands up to 2.6x
                            targetLiftY = easeT * 48.0
                            if t <= 0.65 {
                                targetOpacity = 1.0
                            } else {
                                targetOpacity = max(0.0, Double(1.0 - (t - 0.65) / 0.35))
                            }
                            targetZBoost = Double(1.0 - easeT * 0.4) * 500.0
                            targetIsPeeling = true
                        } else {
                            // Completely flown past camera
                            targetScale = 2.6
                            targetLiftY = 48.0
                            targetOpacity = 0.0
                            targetZBoost = -200.0
                            targetIsPeeling = false
                        }
                    } else {
                        // Last background window: dedicated finale slot with zero squash against previous window
                        let lastStart = CGFloat(totalRecords - 1) * stepInterval
                        let lastT = max(0.0, min(1.0, (scrubProgress - lastStart) / stepInterval))
                        let easeLast = lastT * lastT * (3.0 - 2.0 * lastT)
                        targetScale = 1.0 + easeLast * 0.85
                        targetLiftY = easeLast * 22.0
                        targetOpacity = 1.0
                        targetZBoost = Double(easeLast) * 250.0
                        targetIsPeeling = lastT > 0.05
                    }
                    
                    // Smooth blend with centerZoneWeight for seamless snapback on exit
                    let blendedScale = (1.0 - centerZoneWeight) * 1.0 + centerZoneWeight * targetScale
                    let blendedLiftY = centerZoneWeight * targetLiftY
                    let blendedOpacity = (1.0 - Double(centerZoneWeight)) * 1.0 + Double(centerZoneWeight) * targetOpacity
                    let blendedZBoost = Double(centerZoneWeight) * targetZBoost
                    
                    map[record.id] = WindowPeelData(
                        scale: blendedScale,
                        liftY: blendedLiftY,
                        opacity: blendedOpacity,
                        zIndexBoost: blendedZBoost,
                        isPeeling: targetIsPeeling && centerZoneWeight > 0.5
                    )
                }
                
                return map
            }()

            ZStack(alignment: .topLeading) {
                // Screens (Fixed on 3D plane, side-tilts with canvas)
                ForEach(Array(getScreenFrames().enumerated()), id: \.offset) { _, frame in
                    screenView(frame: frame, boundingBox: boundingBox, scale: scale, offsetX: centerOffsetX, offsetY: centerOffsetY)
                }
                
                // Windows (Single Unified Glass Tablets with dynamic forward layer spacing)
                ForEach(previewRecords) { record in
                    WindowPreviewTileView(
                        record: record,
                        snapshot: snapshot,
                        selectedRecordID: selectedRecordID,
                        hoveredRecordID: $hoveredRecordID,
                        tint: tint,
                        isWindowArrangementPreview: isWindowArrangementPreview,
                        is3D: is3D,
                        layerStep: dynamicLayerStep,
                        layerDirectionX: signedOuterOffset >= 0 ? -1.0 : 1.0,  // Fan right when tilted left, left when tilted right
                        scale: scale,
                        boundingBox: boundingBox,
                        offsetX: centerOffsetX,
                        offsetY: centerOffsetY,
                        peelData: peelDataMap[record.id] ?? WindowPeelData()
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .rotation3DEffect(
                .degrees(dynamicPitch),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(dynamicYaw),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .scaleEffect(dynamicScale)
            .offset(x: is3D ? (maxExplosion * 0.30 * signedOuterOffset) : 0, y: is3D ? (maxExplosion * 0.05 * outerDistance) : 0)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.84), value: cursorHorizontalPosition)
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .liquidGlass(cornerRadius: 16, style: .card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            PreviewCursorTracker { position in
                guard controlActiveState == .key else { return }
                // Hand off to cursor only after intro animation completes
                guard !isPlayingIntro else { return }
                let prev = Double(cursorHorizontalPosition)
                let inCenter = position >= 0.25 && position <= 0.75
                let wasInCenter = prev >= 0.25 && prev <= 0.75
                // Capture entry direction the moment the cursor crosses into the center zone
                if inCenter && !wasInCenter {
                    centerEnteredFromLeft = position < prev ? false : true
                }
                cursorHorizontalPosition = position
            }
        }
        .onHover { hovering in
            guard controlActiveState == .key || !hovering else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                isHovered = hovering
                if !hovering {
                    hoveredRecordID = nil
                    // Only reset position if not mid-animation
                    if !isPlayingIntro {
                        cursorHorizontalPosition = 0.5
                    }
                }
            }
        }
        .onChange(of: controlActiveState) { _, newState in
            if newState != .key {
                introTask?.cancel()
                isPlayingIntro = false
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    isHovered = false
                    hoveredRecordID = nil
                    cursorHorizontalPosition = 0.5
                }
            }
        }
        .onAppear {
            if enable3DHover && controlActiveState == .key {
                playIntroAnimation()
            }
        }
        .onChange(of: enable3DHover) { _, newValue in
            if newValue && controlActiveState == .key {
                playIntroAnimation()
            }
        }
    }
    
    // MARK: - Intro Teaser Animation
    
    /// Full arc teaser: center → right → left → center → flat (~2.0s cinematic sweep).
    private func playIntroAnimation() {
        introTask?.cancel()
        introTask = Task { @MainActor in
            // 1. Settle delay: let the panel fully slide in before animating
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, controlActiveState == .key else { return }

            isPlayingIntro = true
            // Activate 3D mode for the teaser
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                isHovered = true
            }

            // 2. Sweep to max right (0.5s)
            withAnimation(.easeInOut(duration: 0.5)) {
                cursorHorizontalPosition = 1.0
            }
            try? await Task.sleep(nanoseconds: 510_000_000)
            guard !Task.isCancelled, controlActiveState == .key else { isPlayingIntro = false; return }

            // 3. Sweep through center all the way to far left (1.0s — crosses center naturally)
            withAnimation(.easeInOut(duration: 1.0)) {
                cursorHorizontalPosition = 0.0
            }
            try? await Task.sleep(nanoseconds: 1_020_000_000)
            guard !Task.isCancelled, controlActiveState == .key else { isPlayingIntro = false; return }

            // 4. Return back to center (0.5s)
            withAnimation(.easeInOut(duration: 0.5)) {
                cursorHorizontalPosition = 0.5
            }
            try? await Task.sleep(nanoseconds: 520_000_000)
            guard !Task.isCancelled, controlActiveState == .key else { isPlayingIntro = false; return }

            // 5. Collapse back to flat 2D
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                isHovered = false
                hoveredRecordID = nil
            }
            isPlayingIntro = false
        }
    }
    
    private func screenView(frame: CGRect, boundingBox: CGRect, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        let x = offsetX + (frame.origin.x - boundingBox.origin.x) * scale
        let y = offsetY + (boundingBox.height - (frame.origin.y - boundingBox.origin.y + frame.height)) * scale
        let w = frame.width * scale
        let h = frame.height * scale
        
        let cornerR: CGFloat = 10 * scale
        
        return ZStack {
            // Main Panel
            RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                .fill(Color(red: 0.04, green: 0.07, blue: 0.18).opacity(0.85))
            
            // Inner glow / bezel detail
            RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12), Color.white.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .frame(width: w, height: h)
        .offset(x: x, y: y)
    }
    
    private func getScreenFrames() -> [CGRect] {
        var uniqueFrames: [CGRect] = []
        for frame in snapshot.records.compactMap({ $0.screenFrame }) {
            if !uniqueFrames.contains(where: { $0.equalTo(frame) }) {
                uniqueFrames.append(frame)
            }
        }
        let frames = uniqueFrames.sorted { $0.origin.x < $1.origin.x }
        if frames.isEmpty {
            return [NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        }
        return frames
    }
    
    private func calculateBoundingBox() -> CGRect {
        let frames = getScreenFrames()
        guard let first = frames.first else { return .zero }
        return frames.reduce(first) { $0.union($1) }
    }
    
    private func calculateScale(for size: CGSize, boundingBox: CGRect) -> CGFloat {
        guard boundingBox.width > 0, boundingBox.height > 0 else { return 1.0 }
        let horizontalScale = (size.width - 12) / boundingBox.width
        let verticalScale = (size.height - 12) / boundingBox.height
        return min(horizontalScale, verticalScale) * 0.98
    }
}

// MARK: - Preview Cursor Tracking

/// A transparent AppKit tracking surface gives SwiftUI the cursor position
/// inside a view. It deliberately passes clicks through to the window tiles.
private struct PreviewCursorTracker: NSViewRepresentable {
    var onMove: (CGFloat) -> Void

    func makeNSView(context: Context) -> PreviewCursorTrackingNSView {
        PreviewCursorTrackingNSView(onMove: onMove)
    }

    func updateNSView(_ nsView: PreviewCursorTrackingNSView, context: Context) {
        nsView.onMove = onMove
    }
}

private final class PreviewCursorTrackingNSView: NSView {
    var onMove: (CGFloat) -> Void
    private var trackingAreaReference: NSTrackingArea?
    private var lastReportedX: CGFloat = 0.5

    init(onMove: @escaping (CGFloat) -> Void) {
        self.onMove = onMove
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
        super.updateTrackingAreas()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        if let window = self.window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }
    }

    @objc private func windowDidResignKey() {
        lastReportedX = 0.5
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func mouseEntered(with event: NSEvent) { report(event) }
    override func mouseMoved(with event: NSEvent) { report(event) }

    private func report(_ event: NSEvent) {
        guard bounds.width > 0 else { return }
        guard let window = self.window, window.isKeyWindow else { return }
        let point = convert(event.locationInWindow, from: nil)
        let raw = min(1, max(0, point.x / bounds.width))
        // Dead-band threshold: filter out micro hand tremors (0.015)
        if abs(raw - lastReportedX) >= 0.015 {
            lastReportedX = raw
            onMove(raw)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Individual Window 3D Tablet View (Native Precision Dwell & Thick Solid Border)

private struct WindowPeelData: Equatable {
    var scale: CGFloat = 1.0
    var liftY: CGFloat = 0.0
    var opacity: Double = 1.0
    var zIndexBoost: Double = 0.0
    var isPeeling: Bool = false
}

private struct WindowPreviewTileView: View {
    let record: WindowRecord
    let snapshot: LayoutSnapshot
    let selectedRecordID: UUID?
    @Binding var hoveredRecordID: UUID?
    let tint: Color
    let isWindowArrangementPreview: Bool
    let is3D: Bool
    let layerStep: CGFloat
    /// +1.0 = layers fan toward right (left-side view), -1.0 = layers fan toward left (right-side view, default)
    let layerDirectionX: CGFloat
    let scale: CGFloat
    let boundingBox: CGRect
    let offsetX: CGFloat
    let offsetY: CGFloat
    let peelData: WindowPeelData
    
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var dwellTask: Task<Void, Never>? = nil
    
    private var isSelected: Bool { record.id == selectedRecordID }
    private var isFocused: Bool { is3D && hoveredRecordID == record.id }
    private var hasHoverFocus: Bool { is3D && hoveredRecordID != nil }
    private var isPeeling: Bool { is3D && peelData.isPeeling }
    
    private var rank: Int {
        let previewRecords = snapshot.previewRecords
        let sorted = previewRecords.sorted { a, b in
            let za = a.zIndex ?? 0
            let zb = b.zIndex ?? 0
            if za != zb { return za > zb }
            let idxA = previewRecords.firstIndex(where: { $0.id == a.id }) ?? 0
            let idxB = previewRecords.firstIndex(where: { $0.id == b.id }) ?? 0
            return idxA > idxB
        }
        return sorted.firstIndex(where: { $0.id == record.id }) ?? 0
    }
    
    var body: some View {
        let layerOffset = is3D ? (CGFloat(rank) * layerStep) : 0
        let focusLift: CGFloat = isFocused ? 18.0 : 0
        let peelLift: CGFloat = is3D ? peelData.liftY : 0.0
        
        let displayFrame = record.previewDisplayFrame
        let x = offsetX + (displayFrame.origin.x - boundingBox.origin.x) * scale
        let y = offsetY + (boundingBox.height - (displayFrame.origin.y - boundingBox.origin.y + displayFrame.height)) * scale
        let w = max(8, displayFrame.width * scale)
        let h = max(8, displayFrame.height * scale)
        
        // Base resting position in the 3D stack — fan direction flips based on which side we're viewing from
        let baseX = x + (is3D ? layerDirectionX * layerOffset * 0.9 : 0)
        let baseY = y + (is3D ? -layerOffset * 0.12 : 0)
        
        let isFullScreen = record.isFullScreenMode
        let baseTint = isFullScreen ? Color.green : ((tint == .black || tint == Color.black) ? Color(white: 0.8) : tint)
        let tintInfo = AppIconColorCache.shared.tintInfo(for: record.windowID.appBundleID)
        let cardFillColor = isFullScreen ? Color.green : (tintInfo?.color ?? baseTint)
        let isDarkCard = isFullScreen ? false : (tintInfo?.isDark ?? false)
        let winCorner: CGFloat = max(4, 8 * scale)
        
        let fillOpacity: Double = {
            if isSelected { return 0.50 }
            if isFocused { return 0.45 }
            if isPeeling { return min(0.60, 0.26 + Double(peelData.scale - 1.0) * 0.18) }
            if isFullScreen {
                if is3D { return hasHoverFocus ? 0.22 : 0.28 }
                return 0.30
            }
            if isDarkCard {
                // Rich smoked glass: ~35-42% opacity for dark/black apps
                if is3D { return hasHoverFocus ? 0.28 : 0.38 }
                return 0.42
            }
            if is3D { return hasHoverFocus ? 0.08 : 0.14 }
            return 0.22
        }()
        
        let strokeOpacity: Double = {
            if isSelected || isFocused || isPeeling { return 1.0 }
            if is3D { return hasHoverFocus ? 0.35 : 0.50 }
            return 0.60
        }()

        let windowBorderWidth: CGFloat = {
            if isSelected || isFocused { return 2.8 }
            if isPeeling { return 3.0 }
            return 2.2
        }()
        
        let activeScale: CGFloat = {
            let base: CGFloat = is3D ? (1.0 + Double(rank) * 0.01) : 1.0
            let focusFactor: CGFloat = isSelected ? 1.06 : (isFocused ? 1.05 : 1.0)
            return base * (is3D ? peelData.scale : 1.0) * focusFactor
        }()
        
        return ZStack {
            // Visual Tablet (Lifts forward & expands on focus/peel, without displacing hit-test bounds)
            ZStack(alignment: .topLeading) {
                // Single Unified Glass Tablet with Thick Solid Dual-Layer Border (NO offset duplicate!)
                RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                    .fill(cardFillColor.opacity(fillOpacity))
                    .overlay {
                        // Outer solid rim (2.2pt, expands on peel/focus)
                        RoundedRectangle(cornerRadius: winCorner, style: .continuous)
                            .stroke(
                                baseTint.opacity(strokeOpacity),
                                lineWidth: windowBorderWidth
                            )
                            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: windowBorderWidth)
                    }
                    .overlay {
                        // Inner contrast bevel highlight (1.0pt)
                        RoundedRectangle(cornerRadius: max(2, winCorner - 1.5), style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isFocused ? 0.65 : (isDarkCard ? 0.38 : (isPeeling ? 0.50 : 0.25))),
                                        Color.white.opacity(isFocused ? 0.25 : (isDarkCard ? 0.14 : (isPeeling ? 0.20 : 0.08)))
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                            .padding(1.5)
                    }
                    .shadow(
                        color: isSelected ? baseTint.opacity(0.75) : (
                            isFocused ? baseTint.opacity(0.60) : (
                                isPeeling
                                    ? baseTint.opacity(0.60 * peelData.opacity)
                                    : Color.black.opacity(is3D ? (0.20 + Double(rank) * 0.025) : 0.0)
                            )
                        ),
                        radius: isSelected ? 14 : (
                            isFocused ? 18 : (
                                isPeeling
                                    ? (8.0 + (peelData.scale - 1.0) * 14.0)
                                    : (is3D ? (5 + CGFloat(rank) * 1.5) : 0)
                            )
                        ),
                        x: is3D ? (CGFloat(rank) * 1.4) : 0,
                        y: is3D ? (CGFloat(rank) * 2.2 - peelLift * 0.25) : 0
                    )
                
                // Centered macOS native full-screen glyph in the middle of the window dimensions
                if isFullScreen {
                    let glyphSize = min(max(min(w, h) * 0.26, 9), min(w - 2, h - 2), 30)
                    MacOSFullScreenGlyph()
                        .fill(Color.green.opacity(0.85))
                        .frame(width: glyphSize, height: glyphSize)
                        .position(x: max(8, w) / 2, y: max(8, h) / 2)
                }

                // ── Top-left App Icon Badge ─────────────────────────────
                if w >= 14 && h >= 12 {
                    let badgeSize: CGFloat = {
                        let maxBounds = min(w - 4, h - 4)
                        if is3D {
                            let maxTarget: CGFloat = (isFocused || isPeeling) ? 42.0 : 36.0
                            let base = max(28.0, min(w * 0.26, maxTarget))
                            return min(base, max(12.0, maxBounds))
                        }
                        let base = max(22.0, min(w * 0.24, 32.0))
                        return min(base, max(12.0, maxBounds))
                    }()

                    HStack(spacing: 5) {
                        AppIconView(bundleID: record.windowID.appBundleID)
                            .frame(width: badgeSize, height: badgeSize)
                            .clipShape(RoundedRectangle(cornerRadius: max(3.5, badgeSize * 0.22), style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: max(3.5, badgeSize * 0.22), style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 0.75)
                            }
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                            .opacity(isFocused || isSelected || isPeeling ? 1.0 : (hasHoverFocus ? 0.80 : 0.95))

                        if (isFocused || isSelected || isPeeling) && w > 52 {
                            Text(record.windowID.appName?.prefix(14) ?? "")
                                .font(.system(
                                    size: is3D ? max(8, 9 * scale) : max(7, 8 * scale),
                                    weight: .semibold, design: .rounded
                                ))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(Color.black.opacity((isFocused || isPeeling) ? 0.75 : 0.45))
                                }
                                .shadow(color: .black.opacity(0.6), radius: 2)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 4)
                }
            }
            .frame(width: w, height: h)
            .scaleEffect(activeScale)
            .offset(
                x: (is3D && isFocused) ? (-focusLift * 0.9) : 0,
                y: ((is3D && isFocused) ? (-focusLift * 0.15) : 0) - peelLift
            )
            .opacity(is3D ? peelData.opacity : 1.0)
            .allowsHitTesting(false) // Hit-testing is strictly owned by the stationary base container!
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle()) // Strictly anchored to base footprint
        .allowsHitTesting(!is3D || peelData.opacity > 0.3)
        .onHover { hovering in
            guard is3D && controlActiveState == .key else {
                if !hovering {
                    handleHover(false)
                }
                return
            }
            handleHover(hovering)
        }
        .onChange(of: controlActiveState) { _, newState in
            if newState != .key {
                dwellTask?.cancel()
            }
        }
        .offset(x: baseX, y: baseY) // Stationary base position! Never shifts on hover!
        .zIndex(Double(rank) + (isFocused ? 100 : 0) + (isSelected ? 50 : 0) + peelData.zIndexBoost)
        .animation(.spring(response: 0.42, dampingFraction: 0.75), value: record.globalFrame)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: is3D)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: peelData.scale)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: peelData.opacity)
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.84), value: layerStep)
    }
    
    private func handleHover(_ hovering: Bool) {
        dwellTask?.cancel()
        if hovering {
            dwellTask = Task { @MainActor in
                // 150ms dwell debounce
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    hoveredRecordID = record.id
                }
            }
        } else {
            dwellTask?.cancel()
            if hoveredRecordID == record.id {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    hoveredRecordID = nil
                }
            }
        }
    }
}

// MARK: - Screen Layout Thumbnail (for snapshot list rows)

/// Draws proportional monitor-outline rectangles for each display in a snapshot's screen config.
/// Single display → one rectangle. Two displays side-by-side → two rectangles, etc.
struct ScreenLayoutThumbnail: View {
    enum BadgeStatus: String, Hashable {
        case live = "Live"

        func localizedTitle(for language: AppLanguage) -> String {
            rawValue.localized(language)
        }
    }

    let screenKey: String
    let tint: Color
    let isLive: Bool
    var isHighlighted: Bool = false
    var badgeStatus: BadgeStatus? = nil
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    /// Fixed canvas size for the thumbnail area
    private let canvasW: CGFloat = 34
    private let canvasH: CGFloat = 22

    private var fingerprint: ScreenFingerprint {
        ScreenFingerprint.from(key: screenKey)
    }

    private var displays: [ScreenFingerprint.DisplayID] {
        let d = fingerprint.displays
        // Sort left-to-right by origin so layout order is preserved
        return d.sorted { $0.originX < $1.originX }
    }

    private var boundingBox: CGRect {
        guard let first = displays.first else { return .zero }
        return displays.reduce(CGRect(x: first.originX, y: first.originY,
                                     width: first.width, height: first.height)) { box, d in
            box.union(CGRect(x: d.originX, y: d.originY, width: d.width, height: d.height))
        }
    }

    var body: some View {
        let bb = boundingBox
        guard bb.width > 0, bb.height > 0 else { return AnyView(EmptyView()) }

        let scaleX = canvasW / bb.width
        let scaleY = canvasH / bb.height
        let scale  = min(scaleX, scaleY)

        // Center the layout within the canvas
        let layoutW = bb.width  * scale
        let layoutH = bb.height * scale
        let offsetX = (canvasW - layoutW) / 2
        let offsetY = (canvasH - layoutH) / 2

        let active = isLive || isHighlighted
        let neutralColor: Color = colorScheme == .dark ? .white : .black

        return AnyView(
            ZStack(alignment: .topLeading) {
                // Screens
                ForEach(Array(displays.enumerated()), id: \.offset) { _, d in
                    let x = CGFloat(d.originX - Int(bb.minX)) * scale + offsetX
                    // Invert Y: macOS is Y-up, SwiftUI is Y-down.
                    // Calculate distance from the TOP of the bounding box to the TOP of this display.
                    let y = CGFloat(Int(bb.maxY) - (d.originY + d.height)) * scale + offsetY
                    let w = max(6, CGFloat(d.width)  * scale)
                    let h = max(4, CGFloat(d.height) * scale)

                    let screenFill = active
                        ? (tint == .black ? neutralColor.opacity(0.35) : tint.opacity(0.45))
                        : neutralColor.opacity(0.14)
                    let screenStroke = active
                        ? (tint == .black ? neutralColor : tint)
                        : neutralColor.opacity(0.68)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(screenFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(screenStroke, lineWidth: active ? 1.5 : 1.0)
                        }
                        .shadow(color: active ? screenStroke.opacity(0.70) : neutralColor.opacity(0.35), radius: active ? 3.0 : 1.5, x: 0, y: 1)
                        .frame(width: w, height: h)
                        .offset(x: x, y: y)
                }

            }
            .frame(width: canvasW, height: canvasH)
            .overlay(alignment: .topTrailing) {
                if let badgeStatus {
                    statusBadge(for: badgeStatus)
                        // Hang the badge ~3pt above the thumbnail's top edge
                        .offset(x: 2, y: -3)
                }
            }
        )
    }

    private func statusBadge(for status: BadgeStatus) -> some View {
        let label = status.localizedTitle(for: appLanguage)
        return Text(label)
        .font(.system(size: 7.25, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(.primary)
        .padding(.horizontal, 3)
        .padding(.vertical, 1.5)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(tint.opacity(0.55), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }

    private static var thumbnailCache: [String: NSImage] = [:]

    /// Renders the layout thumbnail as a compact, crisp NSImage properly dimensioned for native NSMenuItems (20x14 pt).
    @MainActor
    static func renderImage(
        screenKey: String,
        tint: Color,
        isLive: Bool = false,
        badgeStatus: BadgeStatus? = nil,
        language: AppLanguage = .auto
    ) -> NSImage? {
        let appearanceName = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let appearanceKey = appearanceName == .darkAqua ? "dark" : "light"
        let badgeLabel = badgeStatus?.localizedTitle(for: language)
        let badgeColor = badgeLabel == nil ? nil : resolvedBadgeColor(for: tint)
        let tintKey = badgeColor.map { colorCacheKey(for: $0) } ?? ""
        let cacheKey = [
            screenKey,
            isLive ? "live" : "idle",
            badgeStatus?.rawValue ?? "none",
            badgeLabel ?? "",
            tintKey,
            appearanceKey
        ].joined(separator: "|")
        if let cached = thumbnailCache[cacheKey] {
            return cached
        }

        let displays = ScreenFingerprint.from(key: screenKey).displays.sorted { $0.originX < $1.originX }
        guard let first = displays.first else { return nil }
        let boundingBox = displays.reduce(CGRect(x: first.originX, y: first.originY, width: first.width, height: first.height)) { box, d in
            box.union(CGRect(x: d.originX, y: d.originY, width: d.width, height: d.height))
        }
        guard boundingBox.width > 0, boundingBox.height > 0 else { return nil }

        let canvasW: CGFloat = 20
        let canvasH: CGFloat = 14
        let scaleX = (canvasW - 2) / boundingBox.width
        let scaleY = (canvasH - 2) / boundingBox.height
        let scale = min(scaleX, scaleY)
        let layoutW = boundingBox.width * scale
        let layoutH = boundingBox.height * scale
        let offsetX = (canvasW - layoutW) / 2
        let offsetY = (canvasH - layoutH) / 2

        let image = NSImage(size: NSSize(width: canvasW, height: canvasH), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let neutralColor = NSColor.labelColor
            for d in displays {
                let x = CGFloat(d.originX - Int(boundingBox.minX)) * scale + offsetX
                let y = CGFloat(d.originY - Int(boundingBox.minY)) * scale + offsetY
                let w = max(4.5, CGFloat(d.width) * scale)
                let h = max(3.5, CGFloat(d.height) * scale)
                let r = CGRect(x: x, y: y, width: w, height: h)
                let path = CGPath(roundedRect: r, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)

                let fillColor = isLive
                    ? neutralColor.withAlphaComponent(0.40)
                    : neutralColor.withAlphaComponent(0.14)
                let strokeColor = isLive
                    ? neutralColor
                    : neutralColor.withAlphaComponent(0.68)

                ctx.addPath(path)
                ctx.setFillColor(fillColor.cgColor)
                ctx.fillPath()

                ctx.addPath(path)
                ctx.setStrokeColor(strokeColor.cgColor)
                ctx.setLineWidth(isLive ? 1.25 : 0.90)
                ctx.strokePath()
            }

            if let badgeLabel, let badgeColor {
                drawStatusBadge(
                    label: badgeLabel,
                    color: badgeColor,
                    canvasW: canvasW,
                    canvasH: canvasH,
                    language: language,
                    in: ctx
                )
            }

            return true
        }
        image.isTemplate = false
        thumbnailCache[cacheKey] = image
        return image
    }

    private static func resolvedBadgeColor(for tint: Color) -> NSColor {
        let color = NSColor(tint)
        if let appearance = NSApp?.effectiveAppearance {
            var resolvedColor = color
            appearance.performAsCurrentDrawingAppearance {
                resolvedColor = color.usingColorSpace(.deviceRGB) ?? color
            }
            return resolvedColor
        }
        return color.usingColorSpace(.deviceRGB) ?? color
    }

    private static func colorCacheKey(for color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return color.description
        }

        return String(
            format: "%.3f-%.3f-%.3f-%.3f",
            rgbColor.redComponent,
            rgbColor.greenComponent,
            rgbColor.blueComponent,
            rgbColor.alphaComponent
        )
    }

    private static func drawStatusBadge(
        label: String,
        color: NSColor,
        canvasW: CGFloat,
        canvasH: CGFloat,
        language: AppLanguage,
        in context: CGContext
    ) {
        let dotSize: CGFloat = 1.5
        let textGap: CGFloat = 1.0
        let horizontalInset: CGFloat = 1.6
        let maxBadgeWidth = canvasW - 1
        let maxTextWidth = maxBadgeWidth - (horizontalInset * 2) - dotSize - textGap
        var fontSize: CGFloat = 4.5
        var font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        var textSize = (label as NSString).size(withAttributes: [.font: font])

        while textSize.width > maxTextWidth && fontSize > 2.4 {
            fontSize -= 0.2
            font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            textSize = (label as NSString).size(withAttributes: [.font: font])
        }

        let badgeWidth = min(
            maxBadgeWidth,
            textSize.width + (horizontalInset * 2) + dotSize + textGap
        )
        let badgeHeight = max(6.8, textSize.height + 2.2)
        let isRightToLeft = language.usesHebrew
        let badgeX = isRightToLeft ? 0.5 : canvasW - badgeWidth - 0.5
        let badgeRect = CGRect(
            x: badgeX,
            y: canvasH - badgeHeight - 0.5,
            width: badgeWidth,
            height: badgeHeight
        )
        let badgePath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: badgeHeight / 2,
            cornerHeight: badgeHeight / 2,
            transform: nil
        )

        context.addPath(badgePath)
        context.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor)
        context.fillPath()

        context.addPath(badgePath)
        context.setStrokeColor(color.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(0.45)
        context.strokePath()

        let dotX = isRightToLeft
            ? badgeRect.maxX - horizontalInset - dotSize
            : badgeRect.minX + horizontalInset
        let dotRect = CGRect(
            x: dotX,
            y: badgeRect.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: dotRect)

        let textX = isRightToLeft
            ? badgeRect.minX + horizontalInset
            : dotX + dotSize + textGap
        let textRect = CGRect(
            x: textX,
            y: badgeRect.minY + (badgeRect.height - textSize.height) / 2,
            width: min(textSize.width, maxTextWidth),
            height: textSize.height
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping
        NSAttributedString(
            string: label,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        ).draw(in: textRect)
    }
}

// MARK: - Command Badge View
struct CommandBadgeView: View {
    let isActive: Bool
    let isHovered: Bool
    let themeColor: Color
    
    @State private var offsetX: CGFloat = 100
    @State private var opacity: Double = 0.0
    @State private var glowRadius: CGFloat = 1.5
    @State private var glowOpacity: Double = 0.15
    @State private var strokeOpacity: Double = 0.3

    var body: some View {
        if isActive {
            Text("⌘⇧R")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? Color.white : Color.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? Color.white.opacity(0.2) : themeColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHovered ? Color.white.opacity(0.6) : themeColor.opacity(strokeOpacity), lineWidth: 0.8)
                )
                .shadow(color: isHovered ? Color.white.opacity(0.5) : themeColor.opacity(glowOpacity), radius: glowRadius)
                .offset(x: offsetX)
                .opacity(opacity)
                .onAppear {
                    // Step 1: Slide in from far right (100 -> 0) slowly and fade in with glow
                    withAnimation(.spring(response: 0.75, dampingFraction: 0.7)) {
                        offsetX = 0
                        opacity = 1.0
                        glowRadius = 14
                        glowOpacity = 0.85
                        strokeOpacity = 0.85
                    }
                    // Step 2: Settle glow back to resting state
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_150_000_000)
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                            glowRadius = 2.0
                            glowOpacity = 0.3
                            strokeOpacity = 0.35
                        }
                    }
                }
        } else {
            // Non-active rows: show ⌘⇧R dimly instead of the plain ⌘ icon
            Text("⌘⇧R")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? Color.white.opacity(0.9) : Color.secondary.opacity(0.6))
        }
    }
}

// MARK: - Menu Window List View (for Menu Bar)

struct MenuWindowListView: View {
    let snapshot: LayoutSnapshot
    let activeBundleID: String?
    var limitToActiveApp: Bool = false
    var specificRecords: [WindowRecord]? = nil
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("minimalVisualAnimations") private var minimalVisualAnimations: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredRecordID: UUID? = nil
    @State private var isAppeared = false

    // Opacities that need boosting in light mode
    private var badgeBgOpacity: Double { colorScheme == .dark ? 0.1 : 0.18 }
    private var activeBgOpacity: Double { colorScheme == .dark ? 0.06 : 0.12 }
    private var activeBadgeBgOpacity: Double { colorScheme == .dark ? 0.15 : 0.22 }

    var body: some View {
        VStack(spacing: 2) {
            if let customList = specificRecords {
                ForEach(customList.deduplicatedByApp) { record in
                    appRow(record, isFirstOfApp: true)
                        .scaleEffect(isAppeared ? 1.0 : 0.96)
                        .offset(y: isAppeared ? 0 : 4)
                        .opacity(isAppeared ? 1.0 : 0.0)
                }
            } else {
                let frontmostBundleID = activeBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                let baseRecords = snapshot.previewRecords.deduplicatedByApp
                let activeRecords = baseRecords.filter { $0.windowID.appBundleID == frontmostBundleID }
                let otherRecords = limitToActiveApp ? [] : baseRecords.filter { $0.windowID.appBundleID != frontmostBundleID }
                let displayedActiveRecords = (!activeRecords.isEmpty || !limitToActiveApp) ? activeRecords : [baseRecords.first].compactMap { $0 }

                if !displayedActiveRecords.isEmpty {
                    ForEach(Array(displayedActiveRecords.enumerated()), id: \.element.id) { index, record in
                        appRow(record, isFirstOfApp: index == 0)
                            .scaleEffect(isAppeared ? 1.0 : 0.96)
                            .offset(y: isAppeared ? 0 : 4)
                            .opacity(isAppeared ? 1.0 : 0.0)
                    }
                    if !otherRecords.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 14)
                    }
                }
                ForEach(otherRecords) { record in
                    appRow(record, isFirstOfApp: false)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .onAppear {
            if minimalVisualAnimations {
                isAppeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isAppeared = true
                }
            }
        }
        .minimalVisualAnimations()
        .environment(\.minimalVisualAnimationsEnabled, minimalVisualAnimations)
    }

    private func appRow(_ record: WindowRecord, isFirstOfApp: Bool = true) -> some View {
        let isForeground = record.windowID.appBundleID == snapshot.foregroundBundleID
        let rowTint = record.isFullScreenMode ? Color.green : themeColor.color(seed: 6)
        let isHovered = hoveredRecordID == record.id
        let itemTint = isHovered ? Color.white : rowTint
        // Active badge shown only on the first (topmost) window of the frontmost app
        let isActive = isFirstOfApp && record.windowID.appBundleID == (activeBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        
        return HStack(spacing: 12) {
            if record.isFullScreenMode {
                FullScreenPreviewIcon(tint: itemTint)
                    .frame(width: 32, height: 21)
            } else {
                WindowPreviewIcon(record: record, tint: itemTint)
                    .frame(width: 32, height: 21)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(record.windowID.appName ?? record.windowID.appBundleID)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(isHovered ? Color(NSColor.selectedMenuItemTextColor) : Color.primary)
                        .lineLimit(1)
                    
                    if isActive {
                        Text("Active".localized(appLanguage))
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isHovered ? Color.white.opacity(0.25) : Color.green.opacity(activeBadgeBgOpacity))
                            .foregroundStyle(isHovered ? Color.white : Color.primary)
                            .clipShape(Capsule())
                            .scaleEffect(isAppeared ? 1.0 : 0.8)
                    }
                    
                    if isForeground {
                        Image(systemName: "square.3.layers.3d.top.filled")
                            .mainWindowSymbolAnimation(.breathePlain, capturesClicks: false)
                            .font(.system(size: 8))
                            .foregroundStyle(isHovered ? Color.white : themeColor.color(seed: 5))
                    }
                    
                    // ⌘ badge: visible when Command+Shift+R will be sent to this app.
                    // Shows only when the global trigger is on AND the app is not excluded.
                    let willReceiveCommand = (manager.store.refreshFrontmostOnFullRestore || manager.store.refreshFrontmostOnSingleRestore)
                        && snapshot.commandExcludedBundleIDs.contains(record.windowID.appBundleID)
                    if willReceiveCommand {
                        CommandBadgeView(
                            isActive: isActive,
                            isHovered: isHovered,
                            themeColor: themeColor.color(seed: 5)
                        )
                    }
                }
                
                HStack(spacing: 4) {
                    if let screenName = record.screenName {
                        Text(lz(screenName))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isHovered ? Color.white.opacity(0.2) : rowTint.opacity(badgeBgOpacity))
                            .foregroundStyle(isHovered ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    
                    if !record.windowID.windowTitle.isEmpty {
                        Text(record.windowID.windowTitle)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(isHovered ? Color(NSColor.selectedMenuItemTextColor).opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            
            if isHovered {
                Text("Restore".localized(appLanguage))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
                
                if isActive && !isHovered {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(rowTint.opacity(activeBgOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(rowTint.opacity(isAppeared ? 0.35 : 0.0), lineWidth: 1.2)
                                .animation(.easeOut(duration: 0.45), value: isAppeared)
                        )
                        .overlay(
                            GeometryReader { geo in
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.clear,
                                        rowTint.opacity(0.4),
                                        Color.white.opacity(0.25),
                                        rowTint.opacity(0.4),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(width: geo.size.width * 0.4)
                                .offset(x: isAppeared ? geo.size.width * 1.3 : -geo.size.width * 0.5)
                                .animation(.easeOut(duration: 0.95).delay(0.1), value: isAppeared)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        )
                }
            }
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .mainWindowSymbolHoverRegion()
        .onHover { hovering in
            hoveredRecordID = hovering ? record.id : nil
        }
        .onTapGesture {
            manager.restore(snapshot: snapshot, specificAppBundleID: record.windowID.appBundleID)
            NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
        }
    }
}

// MARK: - Auto Save Hover Preview

struct AutoSavePreviewCardView: View {
    let snapshot: LayoutSnapshot
    let menuWidth: CGFloat
    var indicator: AutoLayoutCaptureIndicator = .sameWindowCount
    let activityApps: [AutoLayoutCaptureAppIcon]
    var triggeringRecordIDs: Set<UUID> = []
    let tint: Color
    let language: AppLanguage
    let onRestore: () -> Void
    @AppStorage("minimalVisualAnimations") private var minimalVisualAnimations: Bool = true

    private var triggeringBundleIDs: Set<String> {
        guard indicator != .history && indicator != .displayConnected && indicator != .displayDisconnected else { return [] }
        return Set(activityApps.map(\.bundleID).filter { !$0.isEmpty })
    }

    private var triggeringAppNames: Set<String> {
        guard indicator != .history && indicator != .displayConnected && indicator != .displayDisconnected else { return [] }
        return Set(activityApps.compactMap(\.appName).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The restore action belongs in the title row so the preview has no
            // second button competing with the thumbnail.
            Button(action: onRestore) {
                HStack(spacing: 6) {
                    Image(systemName: indicator == .displayConnected ? "display.2" : (indicator == .displayDisconnected ? "laptopcomputer" : "clock.arrow.circlepath"))
                        .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 11, weight: indicator == .displayDisconnected ? .regular : .semibold))
                        .foregroundStyle(
                            indicator == .displayDisconnected
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(tint)
                        )
                    Text("Restore this layout".localized(language))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if case .addedWindows = indicator, !activityApps.isEmpty {
                        HStack(spacing: 4) {
                            Text("+")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.green)

                            ForEach(activityApps.prefix(4)) { app in
                                Image(nsImage: app.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                            }

                            if activityApps.count > 4 {
                                Text("+\(activityApps.count - 4)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else if case .sameWindowCount = indicator, !activityApps.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.and.arrow.up.right.and.arrow.down.left")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.blue)

                            ForEach(activityApps.prefix(4)) { app in
                                Image(nsImage: app.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                            }

                            if activityApps.count > 4 {
                                Text("+\(activityApps.count - 4)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Text(snapshot.previewRecords.count == 1 ? "1 window".localized(language) : "\(snapshot.previewRecords.count) \("windows".localized(language))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .mainWindowSymbolHoverRegion()
            .accessibilityLabel(Text("Restore this layout".localized(language)))

            // Visual monitor & window layout
            LayoutPreviewView(
                snapshot: snapshot,
                selectedRecordID: nil,
                tint: tint,
                animateWindowReveal: true,
                isMenubarThumbnail: true,
                isMinimalVisualAnimations: minimalVisualAnimations,
                triggeringRecordIDs: triggeringRecordIDs,
                triggeringBundleIDs: triggeringBundleIDs,
                triggeringAppNames: triggeringAppNames,
                captureIndicator: indicator
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .padding(8)
        .frame(width: menuWidth, height: 210)
        .environment(\.minimalVisualAnimationsEnabled, minimalVisualAnimations)
    }
}
