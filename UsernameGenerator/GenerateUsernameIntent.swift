//
//  GenerateUsernameIntent.swift
//  UsernameGenerator
//
//  Shortcuts, Siri and Spotlight support. Everything runs on device.
//

import AppIntents

extension WordCase: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Capitalization" }
    nonisolated static var caseDisplayRepresentations: [WordCase: DisplayRepresentation] {
        [.lower: "lowercase", .title: "TitleCase", .upper: "UPPERCASE"]
    }
}

extension WordTheme: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Theme" }
    nonisolated static var caseDisplayRepresentations: [WordTheme: DisplayRepresentation] {
        [.any: "Any", .animals: "Animals", .nature: "Nature", .space: "Space", .food: "Food"]
    }
}

/// Separate from `WordSeparator` because its `none` case has an empty raw value.
enum SeparatorChoice: String, AppEnum {
    case none, hyphen, underscore, period

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Separator"
    static let caseDisplayRepresentations: [SeparatorChoice: DisplayRepresentation] = [
        .none: "None", .hyphen: "Hyphen", .underscore: "Underscore", .period: "Period"
    ]

    var separator: WordSeparator {
        switch self {
        case .none: .none
        case .hyphen: .hyphen
        case .underscore: .underscore
        case .period: .period
        }
    }
}

struct GenerateUsernameIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Username"
    static let description = IntentDescription("Creates a random username from words. Nothing leaves your device.")

    @Parameter(title: "Words", default: 2, inclusiveRange: (1, 5))
    var wordCount: Int

    @Parameter(title: "Theme", default: .any)
    var theme: WordTheme

    @Parameter(title: "Separator", default: SeparatorChoice.none)
    var separator: SeparatorChoice

    @Parameter(title: "Capitalization", default: .title)
    var wordCase: WordCase

    @Parameter(title: "Digits", default: 4, inclusiveRange: (0, 6))
    var digits: Int

    @Parameter(title: "Maximum Length", inclusiveRange: (6, 30))
    var maxLength: Int?

    @Parameter(title: "Letters and Numbers Only", default: false)
    var lettersAndDigitsOnly: Bool

    @Parameter(title: "Include Filtered Words", default: false)
    var includeBlockedWords: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$theme) username with \(\.$wordCount) words") {
            \.$separator
            \.$wordCase
            \.$digits
            \.$maxLength
            \.$lettersAndDigitsOnly
            \.$includeBlockedWords
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let options = UsernameOptions(
            wordCount: wordCount,
            separator: separator.separator,
            wordCase: wordCase,
            includeNumber: digits > 0,
            digitCount: max(digits, 1),
            theme: theme,
            limitLength: maxLength != nil,
            maxLength: maxLength ?? UsernameOptions().maxLength,
            lettersAndDigitsOnly: lettersAndDigitsOnly,
            includeBlockedWords: includeBlockedWords
        )
        let username = UsernameGenerator().generate(options: options)
        return .result(value: username, dialog: "\(username)")
    }
}

struct UsernameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateUsernameIntent(),
            phrases: [
                "Generate a username with \(.applicationName)",
                "New username in \(.applicationName)"
            ],
            shortTitle: "Generate Username",
            systemImageName: "person.crop.circle.badge.plus"
        )
    }
}
