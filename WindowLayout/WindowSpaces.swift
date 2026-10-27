import Foundation
import CoreGraphics
import AppKit

/// Which Space does a window belong to?
///
/// Neither of the two APIs the capture already uses can answer that.
/// `CGWindowListCopyWindowInfo` reports every window on every Space but says
/// nothing about which. The accessibility tree returns **success with an empty
/// window list** for an app whose windows are parked on a Space that is not the
/// current one, so reading AX alone makes a live window indistinguishable from
/// a leftover the window server has not reaped.
///
/// That distinction is not cosmetic. It decides whether a record is worth
/// saving, whether the collapse guard is measuring anything, and whether a
/// restore can honestly claim to have finished.
///
/// The only source that knows is `CGSCopySpacesForWindows`, which is private.
/// It is resolved here at runtime with `dlsym`, so nothing links against a
/// private symbol and a macOS release that renames or withdraws one leaves
/// `isAvailable` false. Every caller must keep working in that case, with the
/// behaviour it had before this file existed.
enum WindowSpaces {

    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias SpacesForWindowsFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias ManagedSpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias GetActiveSpaceFn = @convention(c) (Int32) -> UInt64
    private typealias GetSpaceTypeFn = @convention(c) (Int32, UInt64) -> Int32

    /// `kCGSAllSpacesMask` — the current Space, the others, and full-screen ones.
    /// Asking for a narrower set would make a window on another Space look like
    /// a window on none, which is the exact confusion this file exists to end.
    private static let allSpacesSelector: Int32 = 0x7
    private static let fullScreenSpaceTypes: Set<Int> = [2, 4]

    private struct Resolved {
        let connection: Int32
        let lookup: SpacesForWindowsFn
    }

    /// Resolved once. `dlopen(nil, …)` hands back a handle to the running
    /// image, and CoreGraphics is already linked by way of AppKit, so the
    /// symbols are reachable without naming a framework path that could move.
    private static let resolved: Resolved? = {
        guard let handle = dlopen(nil, RTLD_NOW) else { return nil }
        guard let connectionPtr = dlsym(handle, "CGSMainConnectionID"),
              let lookupPtr = dlsym(handle, "CGSCopySpacesForWindows") else { return nil }
        let connection = unsafeBitCast(connectionPtr, to: MainConnectionFn.self)()
        guard connection != 0 else { return nil }
        return Resolved(connection: connection,
                        lookup: unsafeBitCast(lookupPtr, to: SpacesForWindowsFn.self))
    }()

    /// False when the private symbols could not be resolved. Callers fall back
    /// to their previous behaviour rather than treating every window as a
    /// leftover, which would empty the layout.
    static var isAvailable: Bool { resolved != nil }

    private static func managedDisplaySpaces() -> [[String: Any]]? {
        guard let r = resolved,
              let handle = dlopen(nil, RTLD_NOW),
              let ptr = dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return nil }
        let fn = unsafeBitCast(ptr, to: ManagedSpacesFn.self)
        return fn(r.connection)?.takeRetainedValue() as? [[String: Any]]
    }

    /// The WindowServer type for each known Space ID: 0 is a desktop, 2/4 are
    /// full-screen app Spaces, and other values are other system Spaces.
    static func spaceTypesByID() -> [Int: Int]? {
        guard let displays = managedDisplaySpaces() else { return nil }
        var types: [Int: Int] = [:]

        func addType(from space: [String: Any]) {
            guard let id = space["ManagedSpaceID"] as? Int,
                  let type = space["type"] as? Int else { return }
            types[id] = type
        }

        for display in displays {
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                addType(from: space)
            }
            if let current = display["Current Space"] as? [String: Any] {
                addType(from: current)
            }
        }
        return types.isEmpty ? nil : types
    }

    /// Returns nil when Space-type metadata is unavailable, preserving the
    /// geometric full-screen fallback used by the capture path.
    static func fullScreenSpaceIDs() -> Set<Int>? {
        guard let types = spaceTypesByID() else { return nil }
        return Set(types.compactMap { id, type in
            fullScreenSpaceTypes.contains(type) ? id : nil
        })
    }

    /// The Spaces one window belongs to. Empty means none: it is a leftover.
    ///
    /// The call takes an array but returns the *union* of Spaces across it, not
    /// a mapping, so one window per call is the only way to get an answer per
    /// window. Measured at well under a millisecond each, against the tens of
    /// milliseconds of accessibility IPC the same capture already pays.
    static func spaces(of windowID: CGWindowID) -> [Int] {
        guard let r = resolved else { return [] }
        let ids = [NSNumber(value: windowID)] as CFArray
        guard let result = r.lookup(r.connection, allSpacesSelector, ids)?.takeRetainedValue(),
              let numbers = result as? [NSNumber] else { return [] }
        return numbers.map { $0.intValue }
    }

    /// The Spaces for a batch of windows, keyed by window id.
    static func spaces(of windowIDs: [CGWindowID]) -> [CGWindowID: [Int]] {
        guard isAvailable else { return [:] }
        var out: [CGWindowID: [Int]] = [:]
        out.reserveCapacity(windowIDs.count)
        for id in windowIDs {
            out[id] = spaces(of: id)
        }
        return out
    }

    /// The Spaces that are active right now, one per display.
    ///
    /// Needed to tell two kinds of window apart, both of which have no
    /// accessibility frame to match against: one parked on another Space, which
    /// is real, and one on the Space in front of the user that the accessibility
    /// tree declined to report, which is not.
    static func currentSpaces() -> Set<Int> {
        guard let displays = managedDisplaySpaces() else { return [] }
        var out = Set<Int>()
        for display in displays {
            if let current = display["Current Space"] as? [String: Any],
               let id = current["ManagedSpaceID"] as? Int {
                out.insert(id)
            }
        }
        return out
    }

    /// The subset that belongs to at least one Space, i.e. the windows that
    /// really exist. Returns every id unchanged when the lookup is unavailable,
    /// so a caller filtering on this set is a no-op rather than a purge.
    static func onAnySpace(_ windowIDs: [CGWindowID]) -> Set<CGWindowID> {
        guard isAvailable else { return Set(windowIDs) }
        var out = Set<CGWindowID>()
        for id in windowIDs where !spaces(of: id).isEmpty {
            out.insert(id)
        }
        return out
    }

    /// Returns true if the active space is a standard desktop space (type == 0),
    /// and false if it is a full-screen app space (type 4/2) or another non-desktop space.
    static func isCurrentSpaceDesktop() -> Bool {
        // Prefer the active Space itself. A frontmost app can own a full-screen
        // window parked elsewhere while the user is back on a desktop Space.
        if let displays = managedDisplaySpaces() {
            let currentTypes = displays.compactMap { display -> Int? in
                (display["Current Space"] as? [String: Any])?["type"] as? Int
            }
            if currentTypes.contains(where: { $0 != 0 }) { return false }
            if !currentTypes.isEmpty { return true }
        }

        // Fallback to WindowServer's active-space type when managed display
        // metadata does not expose a current type.
        if let type = activeSpaceType() {
            return type == 0
        }

        // Last fallback: an AX full-screen window counts only if that exact
        // window is on screen now, not merely because the app has one elsewhere.
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           hasOnScreenFullScreenAXWindow(for: frontApp) {
            return false
        }
        return true
    }

    private static func activeSpaceType() -> Int? {
        guard let r = resolved,
              let handle = dlopen(nil, RTLD_NOW),
              let activePtr = dlsym(handle, "CGSGetActiveSpace"),
              let typePtr = dlsym(handle, "CGSSpaceGetType") else { return nil }
        let getActive = unsafeBitCast(activePtr, to: GetActiveSpaceFn.self)
        let getType = unsafeBitCast(typePtr, to: GetSpaceTypeFn.self)
        return Int(getType(r.connection, getActive(r.connection)))
    }

    private static func hasOnScreenFullScreenAXWindow(for app: NSRunningApplication) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        let onScreenWindowIDs = Set(windowList.compactMap { entry -> CGWindowID? in
            guard (entry[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  (entry[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            return entry[kCGWindowNumber as String] as? CGWindowID
        })
        guard !onScreenWindowIDs.isEmpty else { return false }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.10)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return false }

        for window in windows {
            var isFullScreen: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &isFullScreen) == .success,
                  let isFullScreen = isFullScreen as? Bool,
                  isFullScreen,
                  let windowID = WindowManager.windowNumber(of: window),
                  onScreenWindowIDs.contains(windowID) else { continue }
            return true
        }
        return false
    }

}
