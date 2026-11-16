// this file used for theme colors, app language, visual effect views, window transparency, animation effects, and other UI customization features plus accessibility features
import SwiftUI
import Combine

enum ThemeColor: String, CaseIterable, Identifiable, Codable {
    case `default` = "Default"
    case black      = "Black"
    case purple    = "Purple"
    case yellow    = "Yellow"
    case red       = "Red"
    case blue      = "Blue"
    case lightBlue = "Light Blue"
    case green     = "Green"
    case orange    = "Orange"
    case mint      = "Mint"
    case galaxy    = "Galaxy"

    var id: String { rawValue }

    /// The single solid accent color for this theme.
    /// Returns `nil` for `.default` (system accent) and `.galaxy` (use `color(seed:)` instead).
    var color: Color? {
        switch self {
        case .default:   return nil
        case .black:     return .black
        case .purple:    return .purple
        case .yellow:    return .yellow
        case .red:       return .red
        case .blue:      return .blue
        case .lightBlue: return .cyan
        case .green:     return .green
        case .orange:    return .orange
        case .mint:      return .mint
        case .galaxy:    return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        if str == "Grey" || str == "grey" {
            self = .black
        } else if str == "Rainbow" || str == "rainbow" {
            // Migrate persisted "Rainbow" to the new Galaxy theme
            self = .galaxy
        } else if let val = ThemeColor(rawValue: str) {
            self = val
        } else {
            self = .default
        }
    }

    /// True when the theme uses the animated galaxy palette.
    var isGalaxy: Bool { self == .galaxy }
    var isRainbow: Bool { isGalaxy }

    /// Deep space / galaxy colour palette — obsidian black (from Black theme), midnight cobalt navy, celestial dark blue, and pure starlight white.
    static let galaxyPalette: [Color] = [
        Color(white: 0.12), // obsidian black (matching Black theme)
        Color(red: 0.03, green: 0.06, blue: 0.16), // deep midnight navy
        Color(red: 0.08, green: 0.18, blue: 0.44), // cosmic cobalt
        Color(red: 0.18, green: 0.38, blue: 0.85), // celestial dark blue
        Color(red: 0.85, green: 0.94, blue: 1.00), // ice starlight blue
        Color(white: 1.00), // pure starlight white
    ]
    static var rainbowPalette: [Color] { galaxyPalette }

    /// Returns the accent colour for a given semantic seed.
    /// For Galaxy theme, callers should use `GalaxyColorManager.shared.color(seed:)` instead
    /// to get the animated variant; this falls back to the static palette.
    func color(seed: Int) -> Color {
        if isGalaxy {
            return GalaxyColorManager.shared.color(seed: seed)
        }
        return color ?? .accentColor
    }

    /// Chooses a readable foreground for content rendered directly on a theme
    /// swatch or accent-colored control. The solid system accent colors used by
    /// this app are bright enough for a dark foreground; the black theme needs
    /// the inverse. Galaxy keeps its starlight treatment in both appearances.
    func onAccentColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .black, .galaxy:
            return .white
        case .default:
            return colorScheme == .dark ? .white : .black
        case .purple, .yellow, .red, .blue, .lightBlue, .green, .orange, .mint:
            return .black
        }
    }
}

// MARK: - Galaxy Color Manager

/// Provides celestial color palettes for the Galaxy theme with zero background overhead.
final class GalaxyColorManager: ObservableObject {
    static let shared = GalaxyColorManager()

    private init() {}

    /// Returns the galaxy color for a semantic seed value.
    func color(seed: Int = 0) -> Color {
        let palette: [Color] = [
            Color(red: 0.38, green: 0.65, blue: 1.00), // Celestial luminous blue (high-contrast primary accent)
            Color(red: 0.55, green: 0.78, blue: 1.00), // Starlight cyan / ice blue
            Color(white: 1.00),                         // Pure starlight white
            Color(red: 0.70, green: 0.55, blue: 1.00), // Radiant cosmic violet
            Color(red: 0.85, green: 0.94, blue: 1.00), // Starlight ice white
        ]
        let index = abs(seed) % palette.count
        return palette[index]
    }
}


enum AppLanguage: String, CaseIterable, Identifiable {
    case auto   = "system"
    case english = "en"
    case hebrew  = "he"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .auto:    return "Auto"
        case .english: return "English"
        case .hebrew:  return "עברית"
        }
    }
}

// MARK: - Visual Motion Preferences

/// A user preference for quieter, more predictable visual feedback. This is
/// separate from the system Reduce Motion setting so people can choose a
/// calmer presentation even when the rest of macOS still uses motion.
private struct MinimalVisualAnimationsKey: EnvironmentKey {
    static let defaultValue = true
}

private struct OriginalAnimationTransactionKey: TransactionKey {
    static let defaultValue: Animation? = nil
}

extension EnvironmentValues {
    var minimalVisualAnimationsEnabled: Bool {
        get { self[MinimalVisualAnimationsKey.self] }
        set { self[MinimalVisualAnimationsKey.self] = newValue }
    }
}

struct MinimalVisualAnimationsModifier: ViewModifier {
    @Environment(\.minimalVisualAnimationsEnabled) private var minimalVisualAnimationsEnabled
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var shouldReduceMotion: Bool {
        minimalVisualAnimationsEnabled || accessibilityReduceMotion
    }

    func body(content: Content) -> some View {
        content.transaction { transaction in
            guard shouldReduceMotion else { return }
            transaction[OriginalAnimationTransactionKey.self] =
                transaction[OriginalAnimationTransactionKey.self] ?? transaction.animation
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

/// Keeps a showcase or onboarding experience animated even when the app's
/// optional minimal-animation preference or macOS Reduce Motion is enabled.
struct FullVisualAnimationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.transaction { transaction in
            if let originalAnimation = transaction[OriginalAnimationTransactionKey.self] {
                transaction.animation = originalAnimation
            }
            transaction.disablesAnimations = false
        }
    }
}

/// Galaxy is an intentionally dark app surface, even when macOS itself is in
/// Light Mode. Keep SwiftUI's semantic foregrounds (such as `.primary` and
/// `.secondary`) aligned with that surface without changing the system-wide
/// appearance or the appearance of other themes.
private struct AppThemeColorSchemeModifier: ViewModifier {
    let theme: ThemeColor
    @Environment(\.colorScheme) private var systemColorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, theme.isGalaxy ? .dark : systemColorScheme)
    }
}

extension View {
    /// Applies the app preference and macOS Reduce Motion to the entire view tree.
    func minimalVisualAnimations() -> some View {
        modifier(MinimalVisualAnimationsModifier())
    }

    /// Preserves app-authored animations inside this subtree.
    func fullVisualAnimations() -> some View {
        modifier(FullVisualAnimationsModifier())
    }

    /// Makes semantic text and materials match the selected app theme.
    func appThemeColorScheme(_ theme: ThemeColor) -> some View {
        modifier(AppThemeColorSchemeModifier(theme: theme))
    }
}


struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        // Do not force material rendering for hidden or inactive windows. This app spends
        // most of its life as a menu-bar utility, where an always-active blur keeps the
        // compositor and display link awake even though no UI is visible.
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Zero-size helper that makes its hosting NSWindow transparent so that
/// VisualEffectView with blendingMode .behindWindow can show the desktop blur.
struct WindowTransparencyAccessor: NSViewRepresentable {
    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // The view receives its window after creation. Configure once on the next run-loop
        // turn rather than dispatching work for every SwiftUI update.
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            configure(view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView, coordinator: context.coordinator)
    }

    private func configure(_ view: NSView, coordinator: Coordinator) {
        guard let window = view.window, coordinator.configuredWindow !== window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        coordinator.configuredWindow = window
    }
}

/// Stronger transparency patch for the Settings scene window.
/// SwiftUI's `Settings { }` scene creates a preferences-style NSWindow that
/// overrides isOpaque and backgroundColor after SwiftUI sets them.
/// This patcher observes the window and re-applies the transparent configuration
/// on a short delay to beat SwiftUI's own post-construction styling pass.
struct SettingsWindowTransparencyPatch: NSViewRepresentable {
    final class Coordinator {
        weak var patchedWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            patch(view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        patch(nsView, coordinator: context.coordinator)
    }

    private func patch(_ view: NSView, coordinator: Coordinator) {
        guard let window = view.window, coordinator.patchedWindow !== window else { return }
        coordinator.patchedWindow = window
        // Apply immediately
        applyTransparency(to: window)
        // Re-apply after SwiftUI's own post-build pass (needed for Settings scene)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            applyTransparency(to: window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            applyTransparency(to: window)
        }
    }

    private func applyTransparency(to window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
    }
}

// MARK: - ThemeColor NSColor Helper

extension ThemeColor {
    func nsColor(seed: Int = 0) -> NSColor {
        switch self {
        case .default:
            return NSColor.controlAccentColor
        case .black:
            return NSColor(white: 0.18, alpha: 1.0)
        case .purple:
            return NSColor.systemPurple
        case .yellow:
            return NSColor.systemYellow
        case .red:
            return NSColor.systemRed
        case .blue:
            return NSColor.systemBlue
        case .lightBlue:
            return NSColor.systemCyan
        case .green:
            return NSColor.systemGreen
        case .orange:
            return NSColor.systemOrange
        case .mint:
            return NSColor.systemMint
        case .galaxy:
            let palette: [NSColor] = [
                NSColor(white: 0.18, alpha: 1.0), // Obsidian black (from Black theme)
                NSColor(red: 0.03, green: 0.06, blue: 0.16, alpha: 1.0),
                NSColor(red: 0.08, green: 0.18, blue: 0.44, alpha: 1.0),
                NSColor(red: 0.18, green: 0.38, blue: 0.85, alpha: 1.0),
                NSColor(red: 0.85, green: 0.94, blue: 1.00, alpha: 1.0),
                NSColor(white: 1.0, alpha: 1.0),
            ]
            let index = abs(seed) % palette.count
            return palette[index]
        }
    }
}

// MARK: - Galaxy Cosmic Background View

struct GalaxyStar: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let maxOpacity: Double
}

struct GalaxyCosmicBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Deterministic pseudo-random starfield distribution
    private static let stars: [GalaxyStar] = {
        var result: [GalaxyStar] = []
        var seed: UInt64 = 133742
        func nextRand() -> Double {
            seed = (seed &* 6364136223846793005 &+ 1442695040888963407)
            return Double((seed >> 16) & 0xFFFFFF) / Double(0xFFFFFF)
        }
        for i in 0..<45 {
            let x = CGFloat(nextRand())
            let y = CGFloat(nextRand())
            let size = CGFloat(1.0 + nextRand() * 2.2)
            let maxOpacity = 0.35 + nextRand() * 0.55
            result.append(GalaxyStar(id: i, x: x, y: y, size: size, maxOpacity: maxOpacity))
        }
        return result
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base deep space obsidian dark tint
                Color(red: 0.02, green: 0.03, blue: 0.09)
                    .opacity(colorScheme == .dark ? 0.65 : 0.28)

                // Nebula 1: Upper-Right Midnight Navy / Cosmic Cobalt Glow
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.22, blue: 0.55).opacity(colorScheme == .dark ? 0.50 : 0.30),
                        Color(red: 0.04, green: 0.09, blue: 0.28).opacity(colorScheme == .dark ? 0.28 : 0.14),
                        .clear
                    ],
                    center: UnitPoint(x: 0.75, y: 0.20),
                    startRadius: 20,
                    endRadius: max(geo.size.width, geo.size.height) * 0.70
                )
                .blur(radius: 35)

                // Nebula 2: Lower-Left Deep Celestial Navy Glow
                RadialGradient(
                    colors: [
                        Color(red: 0.06, green: 0.16, blue: 0.46).opacity(colorScheme == .dark ? 0.45 : 0.25),
                        Color(red: 0.02, green: 0.07, blue: 0.22).opacity(colorScheme == .dark ? 0.22 : 0.10),
                        .clear
                    ],
                    center: UnitPoint(x: 0.20, y: 0.80),
                    startRadius: 25,
                    endRadius: max(geo.size.width, geo.size.height) * 0.75
                )
                .blur(radius: 45)

                // Nebula 3: Center Ambient Starlight Mist
                RadialGradient(
                    colors: [
                        Color(red: 0.15, green: 0.32, blue: 0.70).opacity(colorScheme == .dark ? 0.20 : 0.10),
                        .clear
                    ],
                    center: UnitPoint(x: 0.50, y: 0.50),
                    startRadius: 10,
                    endRadius: max(geo.size.width, geo.size.height) * 0.50
                )
                .blur(radius: 30)

                // Starfield Layer (Static deterministic star positions with subtle starlight glow)
                Canvas { context, size in
                    for star in Self.stars {
                        let starX = star.x * size.width
                        let starY = star.y * size.height
                        let rect = CGRect(x: starX - star.size / 2, y: starY - star.size / 2, width: star.size, height: star.size)

                        if star.size > 2.0 {
                            let glowRect = CGRect(x: starX - star.size * 1.6, y: starY - star.size * 1.6, width: star.size * 3.2, height: star.size * 3.2)
                            context.fill(Path(ellipseIn: glowRect), with: .color(Color(red: 0.75, green: 0.88, blue: 1.0).opacity(star.maxOpacity * 0.25)))
                        }
                        context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.94, green: 0.97, blue: 1.0).opacity(star.maxOpacity)))
                    }
                }
                .allowsHitTesting(false)

                // Window Edge Ambient Luminous Border
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.30 : 0.16),
                                Color(red: 0.28, green: 0.54, blue: 0.95).opacity(0.35),
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.06),
                                Color(red: 0.12, green: 0.28, blue: 0.68).opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Liquid Glass Helper (Matching Frosted Glass Aesthetic with Unified Card Borders)

struct LiquidGlassModifier: ViewModifier {
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.colorScheme) private var colorScheme
    
    var cornerRadius: CGFloat = 12
    var isSelected: Bool = false
    var prominent: Bool = false
    var tint: Color? = nil
    var isHovered: Bool = false
    var style: GlassStyle = .row

    @ViewBuilder
    func body(content: Content) -> some View {
        let isGalaxy = themeColor == .galaxy
        let isDefault = themeColor == .default
        let cardBorderColor = isGalaxy
            ? (isHovered ? Color.white.opacity(0.38) : Color.white.opacity(0.22))
            : (colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10))
        let cardShadowColor = isGalaxy
            ? Color.black.opacity(0.45)
            : Color.black.opacity(colorScheme == .dark ? 0.30 : 0.06)

        if style == .card {
            let cardShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let clippedContent = content.clipShape(cardShape)

            if isGalaxy {
                // Dramatic Deep Obsidian Galaxy Card
                clippedContent
                    .background {
                        ZStack {
                            cardShape
                                .fill(Color(red: 0.04, green: 0.07, blue: 0.16).opacity(0.82))

                            cardShape
                                .fill(.ultraThinMaterial)

                            if isHovered {
                                cardShape
                                    .fill(Color(red: 0.18, green: 0.38, blue: 0.85).opacity(0.16))
                            }
                        }
                        .clipShape(cardShape)
                    }
                    .overlay {
                        cardShape
                            .stroke(cardBorderColor, lineWidth: 1.0)
                    }
                    .shadow(
                        color: cardShadowColor,
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            } else if isDefault {
                clippedContent
                    .background {
                        ZStack {
                            cardShape
                                .fill(.ultraThinMaterial)

                            if colorScheme == .light {
                                cardShape
                                    .fill(Color.white.opacity(0.25))
                            }

                            if isHovered {
                                cardShape
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.08))
                            }
                        }
                        .clipShape(cardShape)
                    }
                    .overlay {
                        cardShape
                            .stroke(cardBorderColor, lineWidth: 1.0)
                    }
                    .shadow(
                        color: cardShadowColor,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            } else {
                let accent = tint ?? themeColor.color ?? .accentColor
                clippedContent
                    .background {
                        ZStack {
                            cardShape
                                .fill(.ultraThinMaterial)

                            if isSelected {
                                cardShape
                                    .fill(accent.opacity(0.15))
                            } else if isHovered {
                                cardShape
                                    .fill(Color.primary.opacity(0.05))
                            }
                        }
                        .clipShape(cardShape)
                    }
                    .overlay {
                        cardShape
                            .stroke(cardBorderColor, lineWidth: 1.0)
                    }
                    .shadow(
                        color: cardShadowColor,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
        } else if isGalaxy {
            // Galaxy Row & Prominent Styling
            if prominent {
                content
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(red: 0.08, green: 0.16, blue: 0.38).opacity(isHovered ? 0.45 : 0.25))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(isHovered ? 0.35 : 0.20), lineWidth: 1.0)
                    }
            } else {
                content
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color(red: 0.12, green: 0.28, blue: 0.68).opacity(0.40))
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                    }
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.50), lineWidth: 1.2)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                        }
                    }
            }
        } else if isDefault {
            if prominent {
                content
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(isHovered ? 0.12 : 0.06))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1.0)
                    }
            } else {
                content
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.primary.opacity(0.14))
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        }
                    }
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.primary.opacity(0.30), lineWidth: 1.0)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(
                                    colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08),
                                    lineWidth: 0.8
                                )
                        }
                    }
            }
        } else {
            // Solid Accent Themes (Purple, Yellow, Red, Blue, Light Blue, Green, Orange, Mint, Black)
            let accent = tint ?? themeColor.color ?? .accentColor
            content
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(accent.opacity(0.15))
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(accent.opacity(0.4), lineWidth: 1.0)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08),
                                lineWidth: 0.8
                            )
                    }
                }
        }
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 12, isSelected: Bool = false, prominent: Bool = false, tint: Color? = nil, isHovered: Bool = false, style: GlassStyle = .row) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, isSelected: isSelected, prominent: prominent, tint: tint, isHovered: isHovered, style: style))
    }
}

enum GlassStyle {
    case row
    case card
}

/// Shared glass feedback for app-authored, color-filled action buttons.
/// The caller supplies the button's existing tint and silhouette; this style
/// only layers interaction feedback over the existing label.
struct ColoredActionButtonStyle: ButtonStyle {
    var tint: Color
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

    func makeBody(configuration: Configuration) -> some View {
        ColoredActionButtonSurface(
            content: configuration.label,
            tint: tint,
            shape: shape,
            isPressed: configuration.isPressed,
            usesNativeButtonStyle: false
        )
    }
}

private struct ColoredActionButtonEffectModifier: ViewModifier {
    var tint: Color?
    var shape: AnyShape

    func body(content: Content) -> some View {
        ColoredActionButtonSurface(
            content: content,
            tint: tint ?? .accentColor,
            shape: shape,
            isPressed: false,
            usesNativeButtonStyle: true
        )
    }
}

private struct ColoredActionButtonSurface<Content: View>: View {
    let content: Content
    let tint: Color
    let shape: AnyShape
    let isPressed: Bool
    let usesNativeButtonStyle: Bool

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.minimalVisualAnimationsEnabled) private var minimalVisualAnimationsEnabled
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var isInteractionAnimated: Bool {
        !minimalVisualAnimationsEnabled && !accessibilityReduceMotion
    }

    private var isActivelyHovered: Bool {
        isEnabled && isHovered
    }

    private var glassTintOpacity: Double {
        guard isEnabled else { return 0.22 }
        if isPressed { return 0.50 }
        return isActivelyHovered ? 0.48 : 0.38
    }

    @ViewBuilder
    private var materialSurface: some View {
        if #available(macOS 26.0, *), !usesNativeButtonStyle {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(glassTintOpacity)).interactive(),
                    in: shape
                )
        } else if #available(macOS 26.0, *), usesNativeButtonStyle {
            // Native prominent controls already adopt Liquid Glass and their
            // own pressed feedback on macOS 26; avoid stacking a second glass
            // surface over the system control.
            content
        } else {
            content
                .overlay {
                    shape
                        .fill(.ultraThinMaterial)
                        .opacity(isEnabled ? (isActivelyHovered ? 0.15 : 0.09) : 0.04)
                        .allowsHitTesting(false)
                }
        }
    }

    var body: some View {
        materialSurface
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActivelyHovered ? 0.16 : 0.10),
                                Color.white.opacity(0.025),
                                Color.black.opacity(isPressed ? 0.055 : 0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .stroke(
                        Color.white.opacity(isActivelyHovered ? 0.30 : 0.18),
                        lineWidth: 0.8
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                if isPressed && !usesNativeButtonStyle {
                    shape
                        .fill(Color.black.opacity(0.045))
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: tint.opacity(isActivelyHovered ? 0.26 : 0.14),
                radius: isActivelyHovered ? 8 : 5,
                x: 0,
                y: 2
            )
            .contentShape(shape)
            .onHover { isHovered = isEnabled && $0 }
            .animation(isInteractionAnimated ? .easeOut(duration: 0.15) : nil, value: isActivelyHovered)
            .animation(isInteractionAnimated ? .easeOut(duration: 0.09) : nil, value: isPressed)
    }
}

extension View {
    /// Adds the shared glass/rim treatment without replacing a native button style.
    func coloredActionButtonEffect(
        tint: Color? = nil,
        shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    ) -> some View {
        modifier(ColoredActionButtonEffectModifier(tint: tint, shape: shape))
    }
}
