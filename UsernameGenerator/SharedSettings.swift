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

    /// UI tests launch the app with this argument to get a clean, separate store.
    static let uiTestingArgument = "-uiTesting"

    static let defaults: UserDefaults = {
        if ProcessInfo.processInfo.arguments.contains(uiTestingArgument) {
            let suite = "UsernameGenerator.UITests"
            UserDefaults.standard.removePersistentDomain(forName: suite)
            if let defaults = UserDefaults(suiteName: suite) {
                defaults.removePersistentDomain(forName: suite)
                return defaults
            }
        }
        return UserDefaults(suiteName: appGroupID) ?? .standard
    }()

    /// Separator, capitalization and theme were single choices before they became sets. Carries the old choice over.
    static func migrateLegacyKeys(in d: UserDefaults = defaults) {
        if d.string(forKey: "separators") == nil, let v = d.string(forKey: "separator").flatMap(WordSeparator.init(rawValue:)) {
            d.set(WordSeparator.encode([v]), forKey: "separators")
        }
        if d.string(forKey: "wordCases") == nil, let v = d.string(forKey: "wordCase").flatMap(WordCase.init(rawValue:)) {
            d.set(WordCase.encode([v]), forKey: "wordCases")
        }
        if d.string(forKey: "themes") == nil, let v = d.string(forKey: "theme").flatMap(WordTheme.init(rawValue:)) {
            d.set(WordTheme.encode([v]), forKey: "themes")
        }
    }

    /// Reads the options saved by the app's `@AppStorage` keys, falling back to the defaults.
    static func loadOptions(from d: UserDefaults = defaults) -> UsernameOptions {
        var options = UsernameOptions()
        if let v = d.object(forKey: "wordCount") as? Int { options.wordCount = v }
        if let v = d.string(forKey: "separators") {
            options.separators = WordSeparator.decode(v)
        } else if let v = d.string(forKey: "separator").flatMap(WordSeparator.init(rawValue:)) {
            // Saved before multiple separators could be chosen.
            options.separators = [v]
        }
        if let v = d.string(forKey: "wordCases") {
            options.wordCases = WordCase.decode(v)
        } else if let v = d.string(forKey: "wordCase").flatMap(WordCase.init(rawValue:)) {
            // Saved before multiple styles could be chosen.
            options.wordCases = [v]
        }
        if let v = d.object(forKey: "includeNumber") as? Bool { options.includeNumber = v }
        if let v = d.object(forKey: "digitCount") as? Int { options.digitCount = v }
        if let v = d.string(forKey: "themes") {
            options.themes = WordTheme.decode(v)
        } else if let v = d.string(forKey: "theme").flatMap(WordTheme.init(rawValue:)) {
            // Saved before multiple themes could be chosen.
            options.themes = [v]
        }
        if let v = d.object(forKey: "limitLength") as? Bool { options.limitLength = v }
        if let v = d.object(forKey: "maxLength") as? Int { options.maxLength = v }
        if let v = d.object(forKey: "lettersAndDigitsOnly") as? Bool { options.lettersAndDigitsOnly = v }
        if let v = d.object(forKey: "includeBlockedWords") as? Bool { options.includeBlockedWords = v }
        if let v = d.string(forKey: "twists") { options.twists = WordTwist.decode(v) }
        if let v = d.string(forKey: "pattern").flatMap(WordPattern.init(rawValue:)) { options.pattern = v }
        if let v = d.object(forKey: "alliterate") as? Bool { options.alliterate = v }
        return options
    }
}
