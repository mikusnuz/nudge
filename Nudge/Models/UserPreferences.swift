import Foundation

final class UserPreferences {
    static let shared = UserPreferences()
    private let defaults = UserDefaults.standard

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var dragSnapEnabled: Bool {
        get { defaults.object(forKey: "dragSnapEnabled") == nil ? true : defaults.bool(forKey: "dragSnapEnabled") }
        set { defaults.set(newValue, forKey: "dragSnapEnabled") }
    }

    func customHotkey(for action: SnapAction) -> (modifiers: UInt32, keyCode: UInt32)? {
        guard let dict = defaults.dictionary(forKey: "customShortcuts") as? [String: [String: UInt32]],
              let entry = dict[action.rawValue],
              let modifiers = entry["modifiers"],
              let keyCode = entry["keyCode"] else { return nil }
        return (modifiers, keyCode)
    }

    func setCustomHotkey(for action: SnapAction, modifiers: UInt32, keyCode: UInt32) {
        var dict = defaults.dictionary(forKey: "customShortcuts") as? [String: [String: UInt32]] ?? [:]
        dict[action.rawValue] = ["modifiers": modifiers, "keyCode": keyCode]
        defaults.set(dict, forKey: "customShortcuts")
    }

    func resetHotkey(for action: SnapAction) {
        var dict = defaults.dictionary(forKey: "customShortcuts") as? [String: [String: UInt32]] ?? [:]
        dict.removeValue(forKey: action.rawValue)
        defaults.set(dict, forKey: "customShortcuts")
    }

    func hotkey(for action: SnapAction) -> (modifiers: UInt32, keyCode: UInt32) {
        return customHotkey(for: action) ?? action.defaultHotkey
    }

    // MARK: - Ignored Apps

    var ignoredApps: [String] {
        get { defaults.stringArray(forKey: "ignoredApps") ?? [] }
        set { defaults.set(newValue, forKey: "ignoredApps") }
    }

    func isAppIgnored(_ bundleID: String) -> Bool {
        return ignoredApps.contains(bundleID)
    }

    func addIgnoredApp(_ bundleID: String) {
        var list = ignoredApps
        if !list.contains(bundleID) {
            list.append(bundleID)
            ignoredApps = list
        }
    }

    func removeIgnoredApp(_ bundleID: String) {
        var list = ignoredApps
        list.removeAll { $0 == bundleID }
        ignoredApps = list
    }
}
