// Dev-only debug log window.
// Opened by triple-clicking the "ACTIVITY LOG" header in ActivityView.
// Never shown in production; no menu item, no keyboard shortcut.
import AppKit
import SwiftUI

// MARK: - Window Host

@MainActor
final class DebugLogWindow: NSObject, NSWindowDelegate {

    static let shared = DebugLogWindow()

    private var window: NSPanel?

    func toggle() {
        if let w = window, w.isVisible {
            w.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 740, height: 540),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "🛠 Debug Log"
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.minSize = NSSize(width: 500, height: 360)
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: DebugLogView()
                .environmentObject(WindowManager.shared))
            panel.center()
            self.window = panel
        }
        window?.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - Root View

struct DebugLogView: View {
    var body: some View {
        HStack(spacing: 0) {
            EngineLogPanel()
                .frame(minWidth: 240, maxWidth: .infinity)

            Divider()

            CaptureListPanel()
                .frame(minWidth: 240, maxWidth: .infinity)
        }
        .frame(minWidth: 500, minHeight: 360)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Engine Log Panel

struct EngineLogPanel: View {
    @EnvironmentObject var manager: WindowManager
    @State private var copied = false

    private var debugEvents: [TrackingEvent] {
        manager.recentEvents.filter { $0.type == .debug || $0.type == .autoSave }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Label("Engine", systemImage: "gearshape.2")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm:ss.SSS"
                    let lines = debugEvents.reversed().map { event in
                        "\(f.string(from: event.date)) [\(event.type.rawValue)] \(event.message)"
                    }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lines, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy engine log to clipboard")

                Button {
                    manager.clearDebugEvents()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Clear debug events")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(debugEvents) { event in
                            EngineEventRow(event: event)
                                .id(event.id)
                        }
                        if debugEvents.isEmpty {
                            Text("No engine events yet.\nMove a window to trigger auto-save.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: debugEvents.first?.id) { _, _ in
                    if let newest = debugEvents.first {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(newest.id, anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

struct EngineEventRow: View {
    let event: TrackingEvent

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: event.date)
    }

    private var rowColor: Color {
        event.type == .debug ? Color(red: 0.7, green: 0.4, blue: 1.0) : .orange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(timeString)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize()
            Text(event.message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(rowColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
}

// MARK: - Capture List Panel

struct CaptureListPanel: View {
    @EnvironmentObject var manager: WindowManager
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Label("Capture List", systemImage: "list.bullet.below.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(manager.currentFingerprint.readableName)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Button {
                    let screenKey = manager.currentFingerprint.key
                    let entries = manager.autoSaveStore?.visibleEntries ?? []
                    let presentations = AutoLayoutCapturePresentation.make(
                        from: entries,
                        displayScreenKey: screenKey,
                        currentScreenKey: screenKey
                    )
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm:ss"
                    let lines = presentations.enumerated().map { idx, p in
                        let badge: String
                        switch p.changeIndicator {
                        case .addedWindows(let n): badge = "🟢 added(\(n))"
                        case .sameWindowCount:     badge = "🔵 moved"
                        case .history:             badge = "🟠 history"
                        case .displayConnected:    badge = "🟣 conn"
                        case .displayDisconnected: badge = "🟣 disc"
                        }
                        let apps = p.entry.records.map { r in
                            let name = r.windowID.appName ?? r.windowID.appBundleID
                            return "\(name) [\(Int(r.globalFrame.origin.x)), \(Int(r.globalFrame.origin.y)), \(Int(r.globalFrame.width)), \(Int(r.globalFrame.height))]"
                        }.joined(separator: ", ")
                        return "[\(idx)] \(badge) (\(p.entry.windowCount)w) \(f.string(from: p.entry.capturedAt)): \(apps)"
                    }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lines, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy capture list to clipboard")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Refresh every 2s via TimelineView, and immediately on new entries.
            TimelineView(.periodic(from: .now, by: 2)) { context in
                CaptureListContent(now: context.date)
            }
        }
    }
}

struct CaptureListContent: View {
    @EnvironmentObject var manager: WindowManager
    let now: Date

    private var presentations: [AutoLayoutCapturePresentation] {
        let screenKey = manager.currentFingerprint.key
        let entries = manager.autoSaveStore?.visibleEntries ?? []
        return AutoLayoutCapturePresentation.make(
            from: entries,
            displayScreenKey: screenKey,
            currentScreenKey: screenKey
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if presentations.isEmpty {
                    Text("No captures for current display setup.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(Array(presentations.enumerated()), id: \.element.id) { index, p in
                        CapturePresentationRow(index: index, presentation: p, now: now)
                    }
                }
            }
            .padding(8)
        }
    }
}

struct CapturePresentationRow: View {
    let index: Int
    let presentation: AutoLayoutCapturePresentation
    let now: Date

    private var badgeEmoji: String {
        switch presentation.changeIndicator {
        case .addedWindows:                 return "🟢"
        case .sameWindowCount:              return "🔵"
        case .history:                      return "🟠"
        case .displayConnected:             return "🟣"
        case .displayDisconnected:          return "🟣"
        }
    }

    private var badgeName: String {
        switch presentation.changeIndicator {
        case .addedWindows(let n):          return "added(\(n))"
        case .sameWindowCount:              return "moved"
        case .history:                      return "history"
        case .displayConnected:             return "conn"
        case .displayDisconnected:          return "disc"
        }
    }

    private var ageString: String {
        let secs = Int(now.timeIntervalSince(presentation.entry.capturedAt))
        if secs < 60 { return "\(secs)s ago" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private var triggerApps: String {
        let names = presentation.activityApps.compactMap { $0.appName }
        guard !names.isEmpty else { return "—" }
        return names.prefix(3).joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(badgeEmoji)")
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("#\(index)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(badgeName)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(presentation.changeIndicator.color)
                    Spacer()
                    Text(ageString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Text("\(presentation.entry.windowCount)w")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(triggerApps)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(index == 0 ? Color.primary.opacity(0.05) : .clear)
        .cornerRadius(4)
    }
}

