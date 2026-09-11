// this is the activity view it display the activity log and more things 
import SwiftUI

extension EventType {
    var icon: String {
        switch self {
        case .autoSave: return "clock.arrow.circlepath"
        case .manualSave: return "arrow.down.doc.fill"
        case .restore: return "arrow.uturn.backward.circle.fill"
        case .system: return "cpu"
        }
    }

    func color(for theme: ThemeColor) -> Color {
        if theme.isGalaxy {
            switch self {
            case .autoSave: return Color(red: 0.38, green: 0.68, blue: 0.98) // celestial cyan
            case .manualSave: return Color(red: 0.22, green: 0.46, blue: 0.88) // deep cosmic blue
            case .restore: return Color(white: 0.98) // starlight white
            case .system: return Color(red: 0.32, green: 0.58, blue: 0.98) // luminous celestial blue
            }
        }
        switch self {
        case .autoSave: return .orange
        case .manualSave: return .blue
        case .restore: return .green
        case .system: return theme == .black ? Color(white: 0.75) : .purple
        }
    }

    var color: Color {
        color(for: .default)
    }
}

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                // Header - Compact
                HStack {
                    Text("ACTIVITY LOG".localized(appLanguage))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 10) {
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            let text = manager.recentEvents.map { event in
                                var str = "[\(event.timeString)] \(event.type.rawValue.uppercased()): \(event.message)"
                                if let details = event.details {
                                    str += "\n" + details.map { "  • \($0)" }.joined(separator: "\n")
                                }
                                return str
                            }.joined(separator: "\n\n")
                            pasteboard.setString(text, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
                        }
                        .buttonStyle(.plain)
                        .mainWindowSymbolHoverRegion()
                        .help("Copy Full Log".localized(appLanguage))

                        Button(action: { manager.clearEvents() }) {
                            Image(systemName: "trash")
                                .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                        }
                        .buttonStyle(.plain)
                        .mainWindowSymbolHoverRegion()
                        .help("Clear Log".localized(appLanguage))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Activity List
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if manager.recentEvents.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "circle.dotted")
                                    .mainWindowSymbolAnimation(.breathePlain)
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundStyle(.tertiary)
                                Text("History is empty".localized(appLanguage))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .mainWindowSymbolHoverRegion()
                        } else {
                            ForEach(manager.recentEvents.reversed()) { event in
                                eventRow(event)
                                    .id(event.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .onChange(of: manager.recentEvents.first?.id) { _, _ in
                if let newest = manager.recentEvents.first {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(newest.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: TrackingEvent) -> some View {
        let currentThemeColor = themeColor.color(seed: 0)
        let eventColor = event.type.color(for: themeColor)

        return HStack(alignment: .top, spacing: 8) {
            // Compact Icon Block
            ZStack {
                Circle()
                    .fill(eventColor.opacity(themeColor.isGalaxy ? 0.22 : 0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: event.type.icon)
                    .mainWindowSymbolAnimation(.breathe)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(eventColor)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.message)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text(event.timeString)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if let details = event.details {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(details, id: \.self) { detail in
                            // Parse optional status prefix written by the restore engine:
                            // "✓ " = app was running and restored  →  green dot
                            // "✗ " = app was not running (skipped) →  muted red dot
                            let isRestored  = detail.hasPrefix("✓ ")
                            let isSkipped   = detail.hasPrefix("✗ ")
                            let dotColor: Color = isRestored ? (themeColor.isGalaxy ? Color(white: 0.95) : .green)
                                                : isSkipped  ? (themeColor.isGalaxy ? Color.white.opacity(0.35) : .red.opacity(0.55))
                                                : currentThemeColor.opacity(0.5)
                            let displayText = (isRestored || isSkipped)
                                ? String(detail.dropFirst(2))
                                : detail

                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(dotColor)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 5)
                                Text(displayText)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(isSkipped ? .tertiary : .secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlass(cornerRadius: 10, style: .card)
        .mainWindowSymbolHoverRegion()
    }
}
