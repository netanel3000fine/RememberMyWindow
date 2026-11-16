//
//  NotchWelcomePillView.swift
//  RememberMyWindows
//
//  Created for the Apple-style glass-line Hello notch notification pill.
//

import SwiftUI
import AppKit

// MARK: - Cursive "hello" Vector Shape

/// Native path adapted from the supplied SwiftUI HelloAnimation reference.
public struct CursiveHelloShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let drawingRect = rect.insetBy(dx: 1.5, dy: 1.5)

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: drawingRect.minX + x * drawingRect.width,
                y: drawingRect.minY + y * drawingRect.height
            )
        }

        var p = Path()

        p.move(to: pt(0.00095, 0.88718))
        p.addCurve(to: pt(0.19536, 0.31015), control1: pt(0.00993, 0.87738), control2: pt(0.16556, 0.56785))
        p.addCurve(to: pt(0.15043, 0.04964), control1: pt(0.22517, 0.05245), control2: pt(0.1859, -0.068))
        p.addCurve(to: pt(0.10028, 0.932), control1: pt(0.11495, 0.16729), control2: pt(0.09792, 1.02023))
        p.addCurve(to: pt(0.18354, 0.47822), control1: pt(0.10265, 0.84376), control2: pt(0.12157, 0.47822))
        p.addCurve(to: pt(0.22327, 0.88718), control1: pt(0.25733, 0.51463), control2: pt(0.19915, 0.81575))
        p.addCurve(to: pt(0.38553, 0.71351), control1: pt(0.2474, 0.95861), control2: pt(0.33586, 0.89978))
        p.addCurve(to: pt(0.35998, 0.45441), control1: pt(0.43519, 0.52724), control2: pt(0.38978, 0.4306))
        p.addCurve(to: pt(0.35478, 0.87317), control1: pt(0.33018, 0.47822), control2: pt(0.27956, 0.71631))
        p.addCurve(to: pt(0.53453, 0.62808), control1: pt(0.42999, 1.03004), control2: pt(0.51892, 0.6939))
        p.addCurve(to: pt(0.57332, 0.00623), control1: pt(0.55014, 0.56225), control2: pt(0.63955, 0.05805))
        p.addCurve(to: pt(0.48723, 0.60146), control1: pt(0.5071, -0.04559), control2: pt(0.48486, 0.50623))
        p.addCurve(to: pt(0.54588, 0.91239), control1: pt(0.48959, 0.6967), control2: pt(0.50378, 0.87597))
        p.addCurve(to: pt(0.70719, 0.51043), control1: pt(0.58798, 0.9488), control2: pt(0.6807, 0.64768))
        p.addCurve(to: pt(0.73273, 0.01323), control1: pt(0.73368, 0.37317), control2: pt(0.76679, 0.03984))
        p.addCurve(to: pt(0.67171, 0.15048), control1: pt(0.69868, -0.01338), control2: pt(0.68259, 0.07205))
        p.addCurve(to: pt(0.69678, 0.92639), control1: pt(0.66083, 0.22892), control2: pt(0.62204, 0.86057))
        p.addCurve(to: pt(0.87275, 0.47822), control1: pt(0.77152, 0.99222), control2: pt(0.78855, 0.42997))
        p.addCurve(to: pt(0.91438, 0.89776), control1: pt(0.9734, 0.51043), control2: pt(0.92329, 0.85998))
        p.addCurve(to: pt(0.79943, 0.69608), control1: pt(0.87047, 1.08403), control2: pt(0.77956, 1.0))
        p.addCurve(to: pt(0.92006, 0.53081), control1: pt(0.81523, 0.45436), control2: pt(0.86282, 0.43277))
        p.addCurve(to: pt(0.99905, 0.432), control1: pt(0.95979, 0.57703), control2: pt(0.98959, 0.4944))

        return p
    }
}

private enum NotchWelcomePillTiming {
    static let drawingDuration: TimeInterval = 4.0
    static let subtitleDwellDuration: TimeInterval = 3.0

    static func nanoseconds(for duration: TimeInterval) -> UInt64 {
        UInt64((duration * 1_000_000_000).rounded())
    }
}

private enum NotchWelcomePillLayout {
    static let referenceHelloWidth: CGFloat = 110
    static let referenceHelloHeight: CGFloat = 34
    static let referenceHelloTopInset: CGFloat = 2
    static let referenceSubtitleSpacing: CGFloat = 3
    static let referenceSubtitleHeight: CGFloat = 12
    static let referenceBottomInset: CGFloat = 6

    static let preferredHelloHeight: CGFloat = 40
    static let subtitleFontSize: CGFloat = 10
    static let subtitleLineHeight: CGFloat = 13
    static let subtitleSpacing: CGFloat = 1
    static let contentBottomInset: CGFloat = 2
}

private enum NotchWelcomePillTextQueue {
    private static let subtitleFontSize = NotchWelcomePillLayout.subtitleFontSize
    private static let horizontalInset: CGFloat = 12

    static func fit(_ subtitles: [String], toWidth width: CGFloat) -> [String] {
        let availableWidth = max(1, width - horizontalInset * 2)
        return subtitles
            .filter { !$0.isEmpty }
            .flatMap { split($0, toWidth: availableWidth) }
    }

    private static func split(_ text: String, toWidth width: CGFloat) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return [] }

        var items: [String] = []
        var currentItem = ""

        for word in words {
            let candidate = currentItem.isEmpty ? word : "\(currentItem) \(word)"
            if !currentItem.isEmpty, measuredWidth(of: candidate) > width {
                items.append(currentItem)
                currentItem = ""
            }

            let wordItems = splitLongWord(word, toWidth: width)
            items.append(contentsOf: wordItems.dropLast())
            let finalWordItem = wordItems.last ?? word
            currentItem = currentItem.isEmpty ? finalWordItem : "\(currentItem) \(finalWordItem)"
        }

        if !currentItem.isEmpty {
            items.append(currentItem)
        }
        return items
    }

    private static func splitLongWord(_ word: String, toWidth width: CGFloat) -> [String] {
        guard measuredWidth(of: word) > width else { return [word] }

        var items: [String] = []
        var currentItem = ""
        for character in word {
            let candidate = currentItem + String(character)
            if !currentItem.isEmpty && measuredWidth(of: candidate) > width {
                items.append(currentItem)
                currentItem = String(character)
            } else {
                currentItem = candidate
            }
        }
        if !currentItem.isEmpty {
            items.append(currentItem)
        }
        return items.isEmpty ? [word] : items
    }

    private static func measuredWidth(of text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: subtitleFontSize, weight: .medium)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
}

// MARK: - Notch Welcome Pill SwiftUI View

public struct NotchWelcomePillView: View {
    public let subtitle: String           // e.g. "Home · 6/6 windows"
    public let subsequentSubtitles: [String]
    public let notchDepth: CGFloat
    public let pillWidth: CGFloat
    public let pillHeight: CGFloat
    public let onDismiss: () -> Void

    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    
    @State private var appeared = false
    @State private var writeProgress: CGFloat = 0.0
    @State private var showSubtitle = false
    @State private var currentSubtitleIndex = 0
    @State private var subtitleSequenceTask: Task<Void, Never>?
    @State private var isHovered = false

    private var subtitleSequence: [String] {
        ([subtitle] + subsequentSubtitles).filter { !$0.isEmpty }
    }

    private var visibleSubtitle: String? {
        guard subtitleSequence.indices.contains(currentSubtitleIndex) else { return nil }
        return subtitleSequence[currentSubtitleIndex]
    }

    private var appearanceAnimation: Animation {
        .spring(response: 0.40, dampingFraction: 0.78)
    }

    private var accentColor: Color {
        if themeColor == .black {
            return Color(white: 0.90)
        }
        return themeColor.color(seed: 0)
    }

    /// Keep the old visible top edge as the highest position the enlarged script can reach.
    private var currentHelloTopBoundary: CGFloat {
        let contentBelowNotch = max(0, pillHeight - notchDepth)
        let previousContentHeight =
            NotchWelcomePillLayout.referenceHelloHeight
            + NotchWelcomePillLayout.referenceHelloTopInset
            + NotchWelcomePillLayout.referenceSubtitleSpacing
            + NotchWelcomePillLayout.referenceSubtitleHeight
            + NotchWelcomePillLayout.referenceBottomInset
        return notchDepth + max(
            0,
            contentBelowNotch
                - previousContentHeight
                + NotchWelcomePillLayout.referenceHelloTopInset
        )
    }

    private var helloSize: CGSize {
        let availableHeight: CGFloat
        let height: CGFloat
        if showSubtitle {
            let subtitleSpace = NotchWelcomePillLayout.subtitleSpacing
                + NotchWelcomePillLayout.subtitleLineHeight
            availableHeight = max(
                0,
                pillHeight
                    - currentHelloTopBoundary
                    - subtitleSpace
                    - NotchWelcomePillLayout.contentBottomInset
            )
            height = min(NotchWelcomePillLayout.preferredHelloHeight, availableHeight)
        } else {
            availableHeight = max(
                0,
                pillHeight
                    - currentHelloTopBoundary
                    - NotchWelcomePillLayout.contentBottomInset
            )
            height = availableHeight
        }
        let scale = height / NotchWelcomePillLayout.referenceHelloHeight
        let shoulder = NotchShapeLayout.shoulder(forHeight: pillHeight)
        let bodyWidth = max(1, pillWidth - shoulder * 2)
        let width = min(
            NotchWelcomePillLayout.referenceHelloWidth * scale,
            max(1, bodyWidth - 24)
        )
        return CGSize(width: width, height: height)
    }

    public init(
        subtitle: String = "",
        subsequentSubtitles: [String] = [],
        notchDepth: CGFloat,
        pillWidth: CGFloat,
        pillHeight: CGFloat,
        onDismiss: @escaping () -> Void
    ) {
        self.subtitle = subtitle
        self.subsequentSubtitles = subsequentSubtitles
        self.notchDepth = notchDepth
        self.pillWidth = pillWidth
        self.pillHeight = pillHeight
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // MARK: 1. Notch-Anchored Glass Pill Body (Hardware Shoulders & Refractive Glass Lip)
            NotchGlassBackdropView(
                cornerRadius: 18,
                accentColor: accentColor,
                appeared: appeared
            )
            .frame(width: pillWidth, height: pillHeight)
            .scaleEffect(
                x: appeared ? 1.0 : 0.88,
                y: appeared ? 1.0 : 0.01,
                anchor: .top
            )
            .animation(appearanceAnimation, value: appeared)

            // MARK: 2. Content Canvas (Cursive Glass Write + Subtitle)
            VStack(spacing: NotchWelcomePillLayout.subtitleSpacing) {
                // Center Cursive Script
                glassScriptView(shape: CursiveHelloShape())
                    .frame(width: helloSize.width, height: helloSize.height)
                    .clipped()

                // Inserting the subtitle lets it push the script up from the pill's bottom.
                if showSubtitle, let visibleSubtitle {
                    Text(visibleSubtitle)
                        .font(.system(size: NotchWelcomePillLayout.subtitleFontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .padding(.horizontal, 12)
                        .frame(height: NotchWelcomePillLayout.subtitleLineHeight)
                        .id(currentSubtitleIndex)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: currentSubtitleIndex)
                }
            }
            .padding(.bottom, NotchWelcomePillLayout.contentBottomInset)
            .frame(width: pillWidth, height: pillHeight, alignment: .bottom)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : -6)
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: showSubtitle)
        }
        .frame(width: pillWidth, height: pillHeight + 20.0, alignment: .top)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(appearanceAnimation, value: appeared)
        .onAppear {
            // The signature greeting intentionally animates even when macOS Reduce Motion is enabled.
            withAnimation(appearanceAnimation) {
                appeared = true
            }

            // Draw the supplied SwiftUI reference path once before the pill closes.
            withAnimation(.easeInOut(duration: NotchWelcomePillTiming.drawingDuration)) {
                writeProgress = 1.0
            }

            subtitleSequenceTask?.cancel()
            subtitleSequenceTask = Task { @MainActor in
                try? await Task.sleep(
                    nanoseconds: NotchWelcomePillTiming.nanoseconds(for: NotchWelcomePillTiming.drawingDuration)
                )
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    showSubtitle = true
                }

                for index in subtitleSequence.indices.dropFirst() {
                    try? await Task.sleep(
                        nanoseconds: NotchWelcomePillTiming.nanoseconds(for: NotchWelcomePillTiming.subtitleDwellDuration)
                    )
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentSubtitleIndex = index
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchDismiss"))) { _ in
            cancelAnimationTasks()
            withAnimation(.easeOut(duration: 0.28)) {
                appeared = false
            }
        }
        .onDisappear {
            cancelAnimationTasks()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            cancelAnimationTasks()
            onDismiss()
        }
    }

    private func cancelAnimationTasks() {
        subtitleSequenceTask?.cancel()
        subtitleSequenceTask = nil
    }

    // MARK: - Multi-Layered Glass Line Renderer
    @ViewBuilder
    private func glassScriptView<S: Shape>(shape: S) -> some View {
        // Keep the theme-colored aura steady throughout the stroke, including when drawing ends.
        let glowOpacity = 0.62
        let glowLineWidth: CGFloat = 4.25
        let glowBlurRadius: CGFloat = 2.75
        let tubeLineWidth: CGFloat = 2.5
        let coreLineWidth: CGFloat = 1.15

        ZStack {
            // Layer 1: Ambient soft bloom / chromatic aura
            shape
                .trim(from: 0, to: writeProgress)
                .stroke(
                    accentColor.opacity(glowOpacity),
                    style: StrokeStyle(lineWidth: glowLineWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: glowBlurRadius)

            // Layer 2: Glowing frosted glass tube body
            shape
                .trim(from: 0, to: writeProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.95),
                            Color(white: 0.85),
                            Color(white: 0.92),
                            .white.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: tubeLineWidth, lineCap: .round, lineJoin: .round)
                )

            // An accent wash tints the white tube itself without competing with its glow.
            shape
                .trim(from: 0, to: writeProgress)
                .stroke(
                    accentColor.opacity(0.28),
                    style: StrokeStyle(lineWidth: tubeLineWidth, lineCap: .round, lineJoin: .round)
                )

            // Layer 3: Specular crystal core
            shape
                .trim(from: 0, to: writeProgress)
                .stroke(
                    Color.white.opacity(0.92),
                    style: StrokeStyle(lineWidth: coreLineWidth, lineCap: .round, lineJoin: .round)
                )

            // Keep the bright center white-forward while letting the selected theme color show through.
            shape
                .trim(from: 0, to: writeProgress)
                .stroke(
                    accentColor.opacity(0.2),
                    style: StrokeStyle(lineWidth: coreLineWidth, lineCap: .round, lineJoin: .round)
                )
        }
    }
}

// MARK: - Notch Welcome Window (NSPanel)

public final class NotchWelcomeWindow: NSPanel {
    private let pillWidth: CGFloat
    private let dynamicPillHeight: CGFloat
    private let subsequentSubtitles: [String]
    private var dismissTimer: Timer?
    public var onDismissCompleted: (() -> Void)?

    public init(subtitle: String, subsequentSubtitles: [String] = []) {
        self.subsequentSubtitles = subsequentSubtitles
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        let notchWidth: CGFloat = {
            guard let left = screen.auxiliaryTopLeftArea,
                  let right = screen.auxiliaryTopRightArea else { return 0 }
            return max(0, right.minX - left.maxX)
        }()
        let clearance: CGFloat = {
            let key = "notchClearance"
            guard UserDefaults.standard.object(forKey: key) != nil else { return 6 }
            return max(0, CGFloat(UserDefaults.standard.double(forKey: key)))
        }()

        let intrinsicWidth: CGFloat = 285.0
        let minimumWidth = notchWidth > 0 ? notchWidth + clearance * 2 : 0
        let bodyWidth = max(intrinsicWidth, minimumWidth)
        
        let notchDepth = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 24.0
        // Leave room below the notch for the complete script, its stroke, and the subtitle.
        self.dynamicPillHeight = notchDepth + 60.0
        let shoulder = NotchShapeLayout.shoulder(forHeight: self.dynamicPillHeight)
        self.pillWidth = bodyWidth + shoulder * 2

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: self.pillWidth, height: self.dynamicPillHeight + 20.0),
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

    public var isScreenLocked: Bool = false

    public func show(subtitle: String) {
        guard !isScreenLocked else { return }
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.frame
        let notchDepth = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 24.0
        let windowHeight = dynamicPillHeight + 20.0
        let visibleY  = sf.maxY - windowHeight
        let originX   = sf.midX - self.pillWidth / 2

        setFrame(NSRect(x: originX, y: visibleY, width: self.pillWidth, height: windowHeight), display: true)
        self.alphaValue = 1.0

        let shoulder = NotchShapeLayout.shoulder(forHeight: dynamicPillHeight)
        let bodyWidth = max(1, self.pillWidth - shoulder * 2)
        let queuedSubtitles = NotchWelcomePillTextQueue.fit(
            [subtitle] + subsequentSubtitles,
            toWidth: bodyWidth
        )
        let rootView = NotchWelcomePillView(
            subtitle: queuedSubtitles.first ?? "",
            subsequentSubtitles: Array(queuedSubtitles.dropFirst()),
            notchDepth: notchDepth,
            pillWidth: self.pillWidth,
            pillHeight: dynamicPillHeight,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(x: 0, y: 0, width: self.pillWidth, height: windowHeight)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        orderFrontRegardless()
        resetDismissTimer(visibleSubtitleCount: queuedSubtitles.count)
    }

    private func resetDismissTimer(visibleSubtitleCount: Int) {
        dismissTimer?.invalidate()
        // Match each queue advance so the final item remains visible for a full read.
        let interval: TimeInterval = visibleSubtitleCount == 0
            ? NotchWelcomePillTiming.drawingDuration + 0.3
            : NotchWelcomePillTiming.drawingDuration
                + Double(visibleSubtitleCount) * NotchWelcomePillTiming.subtitleDwellDuration
        dismissTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        NotificationCenter.default.post(name: NSNotification.Name("NotchDismiss"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            let callback = self?.onDismissCompleted
            self?.close()
            self?.contentView = nil
            callback?()
        }
    }
}
