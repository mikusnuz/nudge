import Foundation
import CoreGraphics

// MARK: - SkyLight Private API Bridge (runtime loaded)
// Loads SkyLight.framework at runtime via dlopen/dlsym to avoid linker dependency.
// Used as fallback for apps that don't expose AX window attributes (e.g., Claude, some Electron apps).

private let skylight: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
}()

private typealias SLSMainConnectionIDFunc = @convention(c) () -> Int32
private typealias SLSMoveWindowFunc = @convention(c) (Int32, UInt32, UnsafePointer<CGPoint>) -> CGError
private typealias SLSGetWindowBoundsFunc = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> CGError

private let _SLSMainConnectionID: SLSMainConnectionIDFunc? = {
    guard let handle = skylight, let sym = dlsym(handle, "SLSMainConnectionID") else { return nil }
    return unsafeBitCast(sym, to: SLSMainConnectionIDFunc.self)
}()

private let _SLSMoveWindow: SLSMoveWindowFunc? = {
    guard let handle = skylight, let sym = dlsym(handle, "SLSMoveWindow") else { return nil }
    return unsafeBitCast(sym, to: SLSMoveWindowFunc.self)
}()

private let _SLSGetWindowBounds: SLSGetWindowBoundsFunc? = {
    guard let handle = skylight, let sym = dlsym(handle, "SLSGetWindowBounds") else { return nil }
    return unsafeBitCast(sym, to: SLSGetWindowBoundsFunc.self)
}()

enum SkyLight {
    private static let cid: Int32 = _SLSMainConnectionID?() ?? 0

    static var isAvailable: Bool { skylight != nil && cid != 0 }

    static func getBounds(windowID: UInt32) -> CGRect? {
        guard let fn = _SLSGetWindowBounds else { return nil }
        var bounds = CGRect.zero
        let err = fn(cid, windowID, &bounds)
        return err == .success ? bounds : nil
    }

    static func moveWindow(windowID: UInt32, to point: CGPoint) -> Bool {
        guard let fn = _SLSMoveWindow else { return false }
        var p = point
        return fn(cid, windowID, &p) == .success
    }

    /// Find the main window for a PID, returning both ID and bounds
    static func findMainWindowWithBounds(pid: pid_t) -> (wid: UInt32, bounds: CGRect)? {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        var best: (wid: UInt32, bounds: CGRect)?
        var bestArea: CGFloat = 0

        for info in windows {
            guard let wPid = info[kCGWindowOwnerPID as String] as? pid_t, wPid == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let widNum = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let w = bounds["Width"] ?? 0
            let h = bounds["Height"] ?? 0
            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let area = w * h
            if w > 50 && h > 50 && area > bestArea {
                bestArea = area
                best = (wid: UInt32(widNum), bounds: CGRect(x: x, y: y, width: w, height: h))
            }
        }
        return best
    }

    /// Find the main window ID for a PID using CGWindowList (including off-screen/non-standard windows)
    static func findMainWindow(pid: pid_t) -> UInt32? {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        var bestWid: UInt32?
        var bestArea: CGFloat = 0

        for info in windows {
            guard let wPid = info[kCGWindowOwnerPID as String] as? pid_t, wPid == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let widNum = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let wid = UInt32(widNum)
            let w = bounds["Width"] ?? 0
            let h = bounds["Height"] ?? 0
            let area = w * h
            if w > 50 && h > 50 && area > bestArea {
                bestArea = area
                bestWid = wid
            }
        }
        return bestWid
    }
}
