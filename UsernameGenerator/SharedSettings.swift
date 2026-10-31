//
//  SharedSettings.swift
//  UsernameGenerator
//
//  Option choices live in an App Group so the widget sees what you picked in the app.
//  Generated usernames are never stored.
//

import Foundation

nonisolated enum SharedSettings {
    static let appGroupID = "group.com.colebraswell.UsernameGenerator"
    static let widgetKind = "UsernameWidget"

    static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    /// Reads the options saved by the app's `@AppStorage` keys, falling back to the defaults.
    static func loadOptions() -> UsernameOptions {
        let d = defaults
        var options = UsernameOptions()
        if let v = d.object(forKey: "wordCount") as? Int { options.wordCount = v }
        if let v = d.string(forKey: "separator").flatMap(WordSeparator.init(rawValue:)) { options.separator = v }
        if let v = d.string(forKey: "wordCase").flatMap(WordCase.init(rawValue:)) { options.wordCase = v }
        if let v = d.object(forKey: "includeNumber") as? Bool { options.includeNumber = v }
        if let v = d.object(forKey: "digitCount") as? Int { options.digitCount = v }
        if let v = d.string(forKey: "theme").flatMap(WordTheme.init(rawValue:)) { options.theme = v }
        if let v = d.object(forKey: "limitLength") as? Bool { options.limitLength = v }
        if let v = d.object(forKey: "maxLength") as? Int { options.maxLength = v }
        if let v = d.object(forKey: "lettersAndDigitsOnly") as? Bool { options.lettersAndDigitsOnly = v }
        return options
    }
}
