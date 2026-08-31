import AppKit
import Carbon.HIToolbox

/// A single global keyboard shortcut, stored as a key code plus the raw
/// `NSEvent.ModifierFlags` bits so it survives a round trip through JSON.
struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var rawModifierFlags: UInt

    static let empty = HotkeyConfig(keyCode: 0, rawModifierFlags: 0)
    var isEmpty: Bool { keyCode == 0 && rawModifierFlags == 0 }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: rawModifierFlags)
            .intersection(.deviceIndependentFlagsMask)
    }

    /// Control+option+D for a fresh install. The mnemonic survives, and the
    /// combination is clear of the ones macOS and its apps already use for D:
    /// command+D is Duplicate in Finder, Bookmark in Safari and Don't Save in
    /// every save dialog; command+option+D toggles Dock hiding; and
    /// command+control+D is Look Up.
    static let defaultDesktopToggle = HotkeyConfig(
        keyCode: UInt16(kVK_ANSI_D),
        rawModifierFlags: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    /// What the shortcut was before it became configurable. Existing installs
    /// are seeded with this so an upgrade changes nothing until the user says
    /// otherwise.
    static let legacyDesktopToggle = HotkeyConfig(
        keyCode: UInt16(kVK_ANSI_D),
        rawModifierFlags: NSEvent.ModifierFlags([.command]).rawValue
    )

}

/// UserDefaults key names in one place so the settings UI and the loader
/// cannot drift apart.
enum HotkeyKeys {
    static let desktopToggle = "RememberMyWindows.hotkey.desktopToggle"
    /// Set once the user has been shown the notice explaining that the
    /// desktop-toggle shortcut is now theirs to choose.
    static let acknowledgedShortcutChange = "RememberMyWindows.didAcknowledgeShortcutChange"
}

extension HotkeyConfig {
    static func load(_ key: String, fallback: HotkeyConfig) -> HotkeyConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cfg = try? JSONDecoder().decode(HotkeyConfig.self, from: data)
        else { return fallback }
        return cfg
    }

    func save(_ key: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Display

enum HotkeyFormatter {
    /// Modifier glyphs in the order macOS shows them in a menu, then the key.
    static func glyphs(for cfg: HotkeyConfig) -> String {
        if cfg.isEmpty { return "—" }
        var s = ""
        let m = cfg.modifierFlags
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option)  { s += "⌥" }
        if m.contains(.shift)   { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        return s + name(for: cfg.keyCode)
    }

    static func name(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 118: "F4", 120: "F2", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[keyCode] ?? "?\(keyCode)"
    }
}

// MARK: - Registration

/// Registers global hotkeys through Carbon's `RegisterEventHotKey`.
///
/// This replaces a `CGEvent.tapCreate` session tap. The tap saw every
/// keystroke on the machine, needed Accessibility before it would install
/// at all, and returned `nil` to consume the key it matched. Carbon needs
/// no permission, is told only about the exact combination asked for, and
/// cannot swallow anything else.
final class HotkeyManager {

    enum Slot: UInt32 {
        case desktopToggle = 1
    }

    private struct Registered {
        let ref: EventHotKeyRef
        let handler: () -> Void
    }
    private var slots: [Slot: Registered] = [:]
    private var eventHandler: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        if let h = eventHandler { RemoveEventHandler(h) }
        for (_, r) in slots { UnregisterEventHotKey(r.ref) }
    }

    /// Install `cfg` for `slot`, replacing any prior binding on that slot.
    /// Passing `.empty` removes the binding and registers nothing.
    @discardableResult
    func register(_ cfg: HotkeyConfig, slot: Slot, handler: @escaping () -> Void) -> Bool {
        if let prev = slots.removeValue(forKey: slot) {
            UnregisterEventHotKey(prev.ref)
        }
        guard !cfg.isEmpty else { return true }

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x524D5721), id: slot.rawValue)  // 'RMW!'
        let status = RegisterEventHotKey(UInt32(cfg.keyCode),
                                         carbonModifiers(from: cfg.modifierFlags),
                                         id,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let ref else { return false }
        slots[slot] = Registered(ref: ref, handler: handler)
        return true
    }

    func unregister(slot: Slot) {
        if let prev = slots.removeValue(forKey: slot) {
            UnregisterEventHotKey(prev.ref)
        }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(),
                            { (_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) in
                                guard let event, let userData else { return noErr }
                                let me = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                                var hkID = EventHotKeyID()
                                GetEventParameter(event,
                                                  EventParamName(kEventParamDirectObject),
                                                  EventParamType(typeEventHotKeyID),
                                                  nil,
                                                  MemoryLayout<EventHotKeyID>.size,
                                                  nil,
                                                  &hkID)
                                if let slot = Slot(rawValue: hkID.id), let reg = me.slots[slot] {
                                    DispatchQueue.main.async { reg.handler() }
                                }
                                return noErr
                            },
                            1,
                            &spec,
                            context,
                            &eventHandler)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }
}
