import SwiftUI

/// The Auto layout's place in the sidebar.
///
/// A one-button restore of an arrangement nobody saved by hand has to show
/// what it is about to do, or there is no reason to trust it. So the card
/// leads with three facts: when the capture was taken, how many windows it
/// holds, and which display setup it came from.
///
/// Takes plain values rather than reaching into `WindowManager`, so it can be
/// rendered on its own and looked at.
struct AutoLayoutHeroCard: View {

    /// One of the captures behind the newest one.
    struct EarlierCapture: Identifiable {
        let id: UUID
        let capturedAt: Date
        let windowCount: Int
        let matchesCurrentScreens: Bool
    }

    let capturedAt: Date?
    let windowCount: Int
    let screenName: String?
    let matchesCurrentScreens: Bool
    let tint: Color
    let language: AppLanguage
    let onRestore: () -> Void
    /// The rest of the ring, newest first. Empty hides the control entirely.
    var earlier: [EarlierCapture] = []
    var onRestoreEarlier: (UUID) -> Void = { _ in }
    var selectedCaptureID: UUID? = nil
    var onSelectEarlier: ((UUID) -> Void)? = nil
    var isExpanded: Binding<Bool>? = nil
    @State private var internalExpanded: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    private var expandedBinding: Binding<Bool> {
        isExpanded ?? $internalExpanded
    }

    /// How old a capture may be before the card stops looking confident.
    /// Restoring a days-old layout is worse than not restoring, so past this
    /// the card mutes rather than raising a warning nobody asked for.
    static let staleAfter: TimeInterval = 60 * 60 * 12

    /// Injectable so the stale and fresh states can both be rendered.
    var now: Date = Date()

    private var age: TimeInterval? { capturedAt.map { now.timeIntervalSince($0) } }
    private var isStale: Bool { (age ?? .infinity) > Self.staleAfter }
    private var hasCapture: Bool { capturedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            if let capturedAt {
                Text(relativeAge)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(isStale ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .accessibilityLabel(Text(String(format: "Captured %@".localized(language),
                                                    age(of: capturedAt))))
                    .padding(.bottom, 10)

                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .mainWindowSymbolAnimation(.wiggleByLayer)
                    Text(windowCount == 1 ? "1 window".localized(language) : "\(windowCount) \("windows".localized(language))")
                    if let screenName {
                        Text("·").foregroundStyle(.tertiary)
                        Text(screenName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .mainWindowSymbolHoverRegion()

                // A stale card mutes its heading and its age, so the button
                // must come down with them. Leaving the loudest element at full
                // strength undoes the point of muting the rest.
                restoreButton
                    .padding(.top, 10)

                // Only the display mismatch gets a line, because that is a
                // fact the card cannot show any other way. Age is carried by
                // the muting alone: a stale card is meant to look stale, not to
                // argue with the user about it.
                if !matchesCurrentScreens {
                    footnote("Captured on a different display setup.", systemImage: "display.trianglebadge.exclamationmark")
                        .padding(.top, 8)
                }

                if !earlier.isEmpty {
                    earlierCaptures
                        .padding(.top, 10)
                }
            } else {
                footnote("Nothing captured yet. Move a window and it will appear here.", systemImage: "macwindow.badge.plus")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var restoreButton: some View {
        // Spelled "Restore" because the card it sits in is headed AUTO LAYOUT TIMELINE,
        // which is the only thing that separates it from the toolbar's Restore.
        // That reads correctly on screen and not at all through accessibility,
        // where both are a button described as "Restore", so the distinction
        // has to be stated there explicitly.
        if #available(macOS 26.0, *) {
            restoreButtonContent
                .glassEffect(
                    .regular.tint(tint.opacity(isStale ? 0.26 : 0.42)).interactive(),
                    in: .rect(cornerRadius: 18)
                )
        } else {
            restoreButtonContent
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(isStale ? 0.24 : 0.35), lineWidth: 1)
                }
        }
    }

    private var restoreButtonContent: some View {
        Button(action: onRestore) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward")
                    .mainWindowSymbolAnimation(.flip, capturesClicks: false)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text("Restore".localized(language))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .mainWindowSymbolHoverRegion()
        .disabled(!matchesCurrentScreens)
        .opacity(matchesCurrentScreens ? 1 : 0.42)
        .accessibilityLabel(Text("Restore the auto layout".localized(language)))
    }

    /// The rest of the ring.
    ///
    /// Five captures are kept precisely so a bad one can be stepped back past,
    /// and by the time the user notices a bad arrangement the auto-save has
    /// usually recorded it into the newest slot already. Keeping four more on
    /// disk with no way to reach them is not a safeguard.
    private var earlierCaptures: some View {
        DisclosureGroup(isExpanded: expandedBinding) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(earlier) { capture in
                    EarlierRow(
                        isSelected: selectedCaptureID == capture.id,
                        age: age(of: capture.capturedAt),
                        windowCount: capture.windowCount,
                        isApplicable: capture.matchesCurrentScreens,
                        tint: tint,
                        language: language,
                        action: {
                            if let onSelect = onSelectEarlier {
                                onSelect(capture.id)
                            } else {
                                onRestoreEarlier(capture.id)
                            }
                        }
                    )
                }
            }
            .padding(.top, 3)
        } label: {
            HStack(spacing: 8) {
                Text(earlier.count == 1 ? "1 earlier capture".localized(language) : "\(earlier.count) \("earlier captures".localized(language))")
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 8)

                Text("\(earlier.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), in: Capsule())
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
            .mainWindowSymbolHoverRegion()
        }
    }

    /// A row that displays or restores one earlier capture.
    private struct EarlierRow: View {
        var isSelected: Bool = false
        let age: String
        let windowCount: Int
        let isApplicable: Bool
        let tint: Color
        let language: AppLanguage
        let action: () -> Void

        @State private var isHovering = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: 7) {
                        Image(systemName: isApplicable
                          ? (isSelected ? "checkmark.circle.fill" : "arrow.uturn.backward")
                          : "display.trianglebadge.exclamationmark")
                        .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isApplicable ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                        .frame(width: 16)

                    Text(age)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(isApplicable ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    Spacer(minLength: 8)

                    Text(windowCount == 1 ? "1 window".localized(language) : "\(windowCount) \("windows".localized(language))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? tint.opacity(0.16) : (tint.opacity(isHovering && isApplicable ? 0.08 : 0)))
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(tint.opacity(0.30), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isApplicable)
            .mainWindowSymbolHoverRegion()
            .onHover { isHovering = $0 }
            .help(isApplicable
                  ? Text("Select and view this capture".localized(language))
                  : Text("Captured on a different display setup.".localized(language)))
            .accessibilityLabel(Text(String(format: "Capture from %@, %d windows".localized(language),
                                            age, windowCount)))
            .accessibilityValue(Text(isSelected ? "Selected".localized(language) : ""))
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .mainWindowSymbolAnimation(.wiggleByLayer)
                .font(.system(size: 14, weight: .semibold))
            Text("AUTO LAYOUT TIMELINE".localized(language))
                .font(.system(size: 13, weight: .bold))
            Spacer()
            if hasCapture && !matchesCurrentScreens {
                Label {
                    Text("OTHER DISPLAYS".localized(language))
                } icon: {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .mainWindowSymbolAnimation(.breathe)
                }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(!hasCapture || isStale ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
        .mainWindowSymbolHoverRegion()
    }

    private func footnote(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text.localized(language))
        } icon: {
            Image(systemName: systemImage)
                .mainWindowSymbolAnimation(.breathePlain)
        }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .mainWindowSymbolHoverRegion()
    }

    /// Spelled out rather than using `Text(_:style:.relative)`, which cannot be
    /// given a reference date and so cannot be rendered for a chosen age.
    private var relativeAge: String {
        guard let capturedAt else { return "" }
        return age(of: capturedAt)
    }

    private func age(of date: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.maximumUnitCount = 1
        f.allowedUnits = seconds < 3600 ? [.minute] : (seconds < 86_400 ? [.hour] : [.day])
        let spelled = f.string(from: max(seconds, 60)) ?? ""
        // The formatter localises the quantity; the suffix has to be localised
        // too, or a Hebrew system reads "5 דקות ago" in the largest text on the
        // card. A format string rather than concatenation, because the suffix
        // does not follow the quantity in every language.
        guard !spelled.isEmpty else { return "just now".localized(language) }
        return String(format: "%@ ago".localized(language), spelled)
    }
}
