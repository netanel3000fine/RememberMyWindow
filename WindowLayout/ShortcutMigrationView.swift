import SwiftUI

/// One-time notice shown on the first launch after upgrading from a build
/// where the desktop toggle was hardcoded to command+D.
///
/// The upgrade itself changes nothing: the binding has already been seeded
/// with command+D, so a user who dismisses this without touching anything
/// keeps exactly the shortcut they had. What this sheet does is tell them the
/// choice now exists, and be honest about the one behaviour that did change.
struct ShortcutMigrationView: View {
    let language: AppLanguage
    @ObservedObject var manager: DesktopToggleManager
    var onDismiss: () -> Void

    @State private var hoverDone = false

    private var isKeepingLegacy: Bool { manager.hotkey == .legacyDesktopToggle }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .overlay { Circle().stroke(Color.accentColor.opacity(0.25), lineWidth: 1) }
                    .shadow(color: Color.accentColor.opacity(0.22), radius: 20, x: 0, y: 8)

                Image(systemName: "command")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 32)
            .padding(.bottom, 18)

            Text("The Desktop Toggle shortcut is now yours to choose".localized(language))
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)

            Text("It was fixed at ⌘D before. Your shortcut has been kept as ⌘D, so nothing has changed unless you want it to.".localized(language))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
                .padding(.top, 10)

            // The one genuine regression, stated plainly rather than buried.
            if isKeepingLegacy {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text("One change to note: ⌘D now works in Safari too, where it used to be left alone for Add Bookmark.".localized(language))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: 420, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                .padding(.top, 14)
            }

            // Someone who turned the toggle off because ⌘D was stealing keys is
            // exactly who this notice is for, so the sheet still appears. But
            // choosing a shortcut for a switched-off feature does nothing, and
            // saying so beats letting them find out by pressing it.
            if !manager.isEnabled {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .foregroundStyle(.orange)
                        .font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Desktop Toggle is switched off".localized(language))
                            .font(.system(size: 13, weight: .medium))
                        Text("Turn it on to use the shortcut".localized(language))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $manager.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                .padding(10)
                .frame(maxWidth: 420)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))
                .padding(.top, 16)
            }

            VStack(spacing: 8) {
                choiceRow(title: "Keep ⌘D",
                          subtitle: "The shortcut you already have",
                          config: .legacyDesktopToggle)
                choiceRow(title: "Switch to ⌃⌥D",
                          subtitle: "Leaves ⌘D to Finder, Safari and save dialogs",
                          config: .defaultDesktopToggle)
            }
            .frame(maxWidth: 420)
            .padding(.top, 18)

            SettingsShortcutRecorder(
                title: "Or pick your own",
                subtitle: "Press any combination with at least one modifier",
                icon: "keyboard",
                hotkey: $manager.hotkey,
                onBeginRecording: { manager.suspendForRecording() },
                onEndRecording: { manager.resumeAfterRecording() }
            )
            .frame(maxWidth: 420)

            Spacer(minLength: 12)

            Button { onDismiss() } label: {
                Text("Done".localized(language))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 42)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 4)
                    .scaleEffect(hoverDone ? 1.03 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hoverDone)
            }
            .buttonStyle(.plain)
            .onHover { hoverDone = $0 }
            .padding(.bottom, 26)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
        .environment(\.layoutDirection, language == .hebrew ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func choiceRow(title: String, subtitle: String, config: HotkeyConfig) -> some View {
        let isSelected = manager.hotkey == config
        Button { manager.hotkey = config } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.localized(language))
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle.localized(language))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.04))
            }
        }
        .buttonStyle(.plain)
    }
}
