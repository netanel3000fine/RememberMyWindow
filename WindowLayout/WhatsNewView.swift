import SwiftUI
import AppKit

// MARK: - Standalone What's New View for Existing Users

struct WhatsNewView: View {
    var onDismiss: () -> Void

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { themeColor.color(seed: 0) }
    private var accentText: Color {
        themeColor.isGalaxy ? .black : themeColor.onAccentColor(for: colorScheme)
    }
    private var alignment: HorizontalAlignment { appLanguage.usesHebrew ? .trailing : .leading }
    private var sections: [WhatsNewSection] { WhatsNewContent.sections(for: appLanguage) }

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: alignment, spacing: 18) {
                        ForEach(sections) { section in
                            VStack(alignment: alignment, spacing: 7) {
                                Text(section.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: appLanguage.usesHebrew ? .trailing : .leading)

                                ForEach(section.bullets.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 9) {
                                        Circle()
                                            .fill(accent)
                                            .frame(width: 5, height: 5)
                                            .padding(.top, 6)

                                        Text(section.bullets[index])
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: appLanguage.usesHebrew ? .trailing : .leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: appLanguage.usesHebrew ? .trailing : .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: appLanguage.usesHebrew ? .trailing : .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: appLanguage.usesHebrew ? .trailing : .leading)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footerButton
            }
            .padding(.top, 22)
        }
        .frame(width: 760, height: 490)
        .environment(\.layoutDirection, appLanguage.usesHebrew ? .rightToLeft : .leftToRight)
        .appThemeColorScheme(themeColor)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(accent)

            VStack(alignment: alignment, spacing: 3) {
                Text("What's New in v15.5".localized(appLanguage))
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Smooth Springs & Space-Safe Things — The Polish Edition".localized(appLanguage))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.usesHebrew ? .trailing : .leading)
        .padding(.horizontal, 34)
        .padding(.bottom, 12)
    }

    private var footerButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 8) {
                Text("Continue".localized(appLanguage))
                Image(systemName: appLanguage.usesHebrew ? "arrow.left" : "arrow.right")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(accentText)
            .padding(.horizontal, 28)
            .frame(minWidth: 196, minHeight: 42)
            .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(ColoredActionButtonStyle(
            tint: accent,
            shape: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        ))
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(Text("Continue".localized(appLanguage)))
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}

// MARK: - Release Notes Content Models

struct WhatsNewSection: Identifiable {
    let title: String
    let bullets: [String]

    var id: String { title }
}

enum WhatsNewContent {
    static func sections(for language: AppLanguage) -> [WhatsNewSection] {
        let localized: (String) -> String = { $0.localized(language) }
        return [
            WhatsNewSection(
                title: localized("Menu Bar Recent Auto Captures"),
                bullets: [
                    localized("Live captures at your fingertips — Access and browse your recent Auto Layout captures directly from the menu bar dropdown without opening the main window."),
                    localized("Color-coded change badges — Every capture tells its story with colored status badges: green +N for added windows, blue resize arrows for window rearrangements, and orange clock icons for history baselines."),
                    localized("Submenu preview cards — Hover any capture in the menu to inspect a live arrangement preview card and restore it instantly with one click.")
                ]
            ),
            WhatsNewSection(
                title: localized("Native Fullscreen Styling & Intelligence"),
                bullets: [
                    localized("Authentic full-screen thumbnails — Full-screen applications now render with macOS-authentic green accents, featuring the centered native diagonal glyph across arrangement previews, menubar submenus, and session grids."),
                    localized("No more movie interruptions — Auto Layout detects full-screen apps and quietly suppresses transient layout captures while watching videos or presenting.")
                ]
            ),
            WhatsNewSection(
                title: localized("Geometry-Smart Deduplication"),
                bullets: [
                    localized("Zero duplicate spam — Merely clicking between windows or shuffling focus order (z-index) no longer floods your history with duplicate captures. True geometry is verified with sub-pixel tolerance."),
                    localized("Cleaner timeline — Only actual changes (windows opened, closed, moved, or resized) create a new capture in your Auto Layout history.")
                ]
            ),
            WhatsNewSection(
                title: localized("Visual Timeline & Badges"),
                bullets: [
                    localized("Change indicators at a glance — Capture cards in the hero timeline feature color-coded indicators: Green badge for added windows (+N), Blue badge for moved or resized windows, and Orange badge for baseline history."),
                    localized("App icons tell the story — Each capture card displays mini icons of the exact applications involved in that change.")
                ]
            ),
            WhatsNewSection(
                title: localized("Fluid Accordion History Banner"),
                bullets: [
                    localized("Smooth spring reveal — Selecting an earlier capture expands an elegant banner with fluid spring physics, gracefully sliding down and pushing content down."),
                    localized("Symmetric return — Tapping 'Return to Latest' collapses the banner vertically back into zero height with smooth opacity fade."),
                    localized("Visual symphony highlight — Hovering window lists activates a calm, synchronized highlight sweep across previews.")
                ]
            ),
            WhatsNewSection(
                title: localized("A Warmer Welcome in the Notch"),
                bullets: [
                    localized("Polished typography & proportions — Refined script proportions and subtitle spacing ensure the Welcome Notch Pill looks crisp and balanced under every Mac notch."),
                    localized("Theme-aware ambient glow — The pill's subtle glow now dynamically matches your selected theme accent color.")
                ]
            ),
            WhatsNewSection(
                title: localized("Under-the-Hood Polish"),
                bullets: [
                    localized("Standalone What's New for existing users — Updates greet returning users directly with this standalone changelog window, completely removed from first-run onboarding."),
                    localized("Xcode 27 & Swift 6 compatibility — Build fixes, explicit strong-capture closures, and strict type-checks keep the engine humming smoothly.")
                ]
            )
        ]
    }
}
