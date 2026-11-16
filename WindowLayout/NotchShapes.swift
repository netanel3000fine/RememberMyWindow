//
//  NotchShapes.swift
//  RememberMyWindows
//
//  Hardware-matched notch silhouette with outward-curved top shoulders ("ears")
//  and optional progressive glassy lip at the bottom.
//

import SwiftUI
import AppKit

// MARK: - Notch Shape Layout Constants & Helpers

public enum NotchShapeLayout {
    public static let shoulder: CGFloat = 14.0

    /// Outward flaring curve shoulder width ("ears") for a given notch pill height.
    public static func shoulder(forHeight height: CGFloat) -> CGFloat {
        min(shoulder, max(0, height * 0.19))
    }
}

// MARK: - Notch Hardware Silhouette Shape (Closed for Fill & Mask)

public struct NotchHardwareSilhouetteShape: Shape {
    public var cornerRadius: CGFloat
    public var shoulderWidth: CGFloat?

    public init(cornerRadius: CGFloat = 18, shoulderWidth: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.shoulderWidth = shoulderWidth
    }

    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let s = shoulderWidth ?? NotchShapeLayout.shoulder(forHeight: rect.height)
        let r = min(cornerRadius, rect.height / 2, max(0, (rect.width - s * 2) / 2))
        let tangent: CGFloat = 0.55228475

        var path = Path()

        // 1. Top edge: across from (0, 0) to (W, 0)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))

        // 2. Right shoulder: curve inward/downward to notch right edge
        path.addCurve(
            to: CGPoint(x: rect.width - s, y: s),
            control1: CGPoint(x: rect.width - s * (1 - tangent), y: 0),
            control2: CGPoint(x: rect.width - s, y: s * (1 - tangent))
        )

        // 3. Right vertical edge down
        path.addLine(to: CGPoint(x: rect.width - s, y: rect.height - r))

        // 4. Bottom-right rounded corner
        path.addCurve(
            to: CGPoint(x: rect.width - s - r, y: rect.height),
            control1: CGPoint(x: rect.width - s, y: rect.height - r * (1 - tangent)),
            control2: CGPoint(x: rect.width - s - r * (1 - tangent), y: rect.height)
        )

        // 5. Bottom horizontal edge
        path.addLine(to: CGPoint(x: s + r, y: rect.height))

        // 6. Bottom-left rounded corner
        path.addCurve(
            to: CGPoint(x: s, y: rect.height - r),
            control1: CGPoint(x: s + r * (1 - tangent), y: rect.height),
            control2: CGPoint(x: s, y: rect.height - r * (1 - tangent))
        )

        // 7. Left vertical edge up
        path.addLine(to: CGPoint(x: s, y: s))

        // 8. Left shoulder: curve outward/upward to top-left (0, 0)
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: s, y: s * (1 - tangent)),
            control2: CGPoint(x: s * (1 - tangent), y: 0)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Notch Hardware Outline Shape (Open for Stroke along Ears & Rim)

public struct NotchHardwareOutlineShape: Shape {
    public var cornerRadius: CGFloat
    public var shoulderWidth: CGFloat?
    public var bottomInset: CGFloat

    public init(cornerRadius: CGFloat = 18, shoulderWidth: CGFloat? = nil, bottomInset: CGFloat = 0.5) {
        self.cornerRadius = cornerRadius
        self.shoulderWidth = shoulderWidth
        self.bottomInset = bottomInset
    }

    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let s = shoulderWidth ?? NotchShapeLayout.shoulder(forHeight: rect.height)
        let bottomY = rect.height - bottomInset
        let r = min(cornerRadius, bottomY / 2, max(0, (rect.width - s * 2) / 2))
        let tangent: CGFloat = 0.55228475

        var path = Path()

        // 1. Start at top-left edge flush with screen top
        path.move(to: CGPoint(x: 0, y: 0))

        // 2. Left shoulder: curve inward/downward to notch left edge
        path.addCurve(
            to: CGPoint(x: s, y: s),
            control1: CGPoint(x: s * (1 - tangent), y: 0),
            control2: CGPoint(x: s, y: s * (1 - tangent))
        )

        // 3. Left vertical edge down
        path.addLine(to: CGPoint(x: s, y: bottomY - r))

        // 4. Bottom-left rounded corner
        path.addCurve(
            to: CGPoint(x: s + r, y: bottomY),
            control1: CGPoint(x: s, y: bottomY - r * (1 - tangent)),
            control2: CGPoint(x: s + r * (1 - tangent), y: bottomY)
        )

        // 5. Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.width - s - r, y: bottomY))

        // 6. Bottom-right rounded corner
        path.addCurve(
            to: CGPoint(x: rect.width - s, y: bottomY - r),
            control1: CGPoint(x: rect.width - s - r * (1 - tangent), y: bottomY),
            control2: CGPoint(x: rect.width - s, y: bottomY - r * (1 - tangent))
        )

        // 7. Right vertical edge up
        path.addLine(to: CGPoint(x: rect.width - s, y: s))

        // 8. Right shoulder: curve outward/upward to top-right screen edge
        path.addCurve(
            to: CGPoint(x: rect.width, y: 0),
            control1: CGPoint(x: rect.width - s, y: s * (1 - tangent)),
            control2: CGPoint(x: rect.width - s * (1 - tangent), y: 0)
        )

        return path
    }
}

// MARK: - Glass Backdrop View for Hello Notch Pill

public struct NotchGlassBackdropView: View {
    public let cornerRadius: CGFloat
    public let shoulderWidth: CGFloat?
    public let glassStartRatio: CGFloat
    public let accentColor: Color
    public let appeared: Bool

    public init(
        cornerRadius: CGFloat = 18,
        shoulderWidth: CGFloat? = nil,
        glassStartRatio: CGFloat = 0.5,
        accentColor: Color,
        appeared: Bool
    ) {
        self.cornerRadius = cornerRadius
        self.shoulderWidth = shoulderWidth
        self.glassStartRatio = glassStartRatio
        self.accentColor = accentColor
        self.appeared = appeared
    }

    private var silhouette: NotchHardwareSilhouetteShape {
        NotchHardwareSilhouetteShape(cornerRadius: cornerRadius, shoulderWidth: shoulderWidth)
    }

    private var outline: NotchHardwareOutlineShape {
        NotchHardwareOutlineShape(cornerRadius: cornerRadius, shoulderWidth: shoulderWidth)
    }

    public var body: some View {
        ZStack {
            // 1. Frosted Material Blur Backing clipped to the notch silhouette
            Rectangle()
                .fill(.ultraThinMaterial)
                .clipShape(silhouette)

            // 2. Translucent Shading Gradient (adapted from vorssaint-utils NotchTranslucentTint):
            // Pitch black over top half (camera housing), then smoothstep easing into the glassy refractive lip
            LinearGradient(
                stops: (0...48).map { index in
                    let t = Double(index) / 48.0
                    let opacity: Double
                    let threshold = Double(glassStartRatio)
                    if t <= threshold {
                        opacity = 1.0
                    } else {
                        let ramp = (t - threshold) / (1.0 - threshold)
                        // Smooth cubic Hermite easing matching vorssaint-utils NotchTranslucentTint: ramp * ramp * (3 - 2 * ramp)
                        let eased = ramp * ramp * (3.0 - 2.0 * ramp)
                        let maxGlassReduction = 0.62
                        opacity = 1.0 - (appeared ? maxGlassReduction : 0.0) * eased
                    }
                    return Gradient.Stop(color: Color.black.opacity(opacity), location: t)
                },
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(silhouette)

            // 3. Specular Outer Boundary Stroke along ears & lower rim
            outline
                .stroke(Color.white.opacity(appeared ? 0.38 : 0.12), lineWidth: 1.0)

            // 4. Iridescent Accent Edge Rim Stroke
            outline
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(appeared ? 0.35 : 0.1),
                            accentColor.opacity(appeared ? 0.6 : 0.15),
                            .white.opacity(appeared ? 0.35 : 0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.0
                )
        }
    }
}

