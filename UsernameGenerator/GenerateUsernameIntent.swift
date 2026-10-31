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
        [.lower: "lowercase", .title: "TitleCase", .camel: "camelCase", .sentence: "Sentence case",
         .upper: "UPPERCASE", .alternating: "aLtErNaTiNg"]
    }
}

extension WordTheme: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Theme" }
    nonisolated static var caseDisplayRepresentations: [WordTheme: DisplayRepresentation] {
        [.any: "Any", .animals: "Animals", .nature: "Nature", .space: "Space", .food: "Food",
         .ocean: "Ocean", .weather: "Weather", .music: "Music", .colors: "Colors", .fantasy: "Fantasy",
         .sports: "Sports", .spooky: "Spooky", .tech: "Tech", .mythology: "Mythology", .gems: "Gems"]
    }
}

extension WordPattern: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Pattern" }
    nonisolated static var caseDisplayRepresentations: [WordPattern: DisplayRepresentation] {
        [.random: "Any words", .adjectiveNoun: "Adjective + noun"]
    }
}

extension WordTwist: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Spelling" }
    nonisolated static var caseDisplayRepresentations: [WordTwist: DisplayRepresentation] {
        [.plain: "Plain", .leet: "Leetspeak (l33t)", .noVowels: "No vowels (qt)"]
    }
}

/// Separate from `WordSeparator` because its `none` case has an empty raw value.
enum SeparatorChoice: String, AppEnum {
    case none, hyphen, underscore, period, plus, tilde

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Separator"
    static let caseDisplayRepresentations: [SeparatorChoice: DisplayRepresentation] = [
        .none: "None", .hyphen: "Hyphen", .underscore: "Underscore", .period: "Period", .plus: "Plus", .tilde: "Tilde"
    ]

    var separator: WordSeparator {
        switch self {
        case .none: .none
        case .hyphen: .hyphen
        case .underscore: .underscore
        case .period: .period
        case .plus: .plus
        case .tilde: .tilde
        }
    }
}

struct GenerateUsernameIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Username"
    static let description = IntentDescription("Creates a random username from words. Nothing leaves your device.")

    @Parameter(title: "Words", default: 2, inclusiveRange: (1, 5))
    var wordCount: Int

    @Parameter(title: "Themes", default: [.any])
    var themes: [WordTheme]

    @Parameter(title: "Separators", default: [SeparatorChoice.none])
    var separators: [SeparatorChoice]

    @Parameter(title: "Capitalization", default: [.title])
    var wordCases: [WordCase]

    @Parameter(title: "Digits", default: 4, inclusiveRange: (0, 6))
    var digits: Int

    @Parameter(title: "Maximum Length", inclusiveRange: (6, 30))
    var maxLength: Int?

    @Parameter(title: "Letters and Numbers Only", default: false)
    var lettersAndDigitsOnly: Bool

    @Parameter(title: "Include Filtered Words", default: false)
    var includeBlockedWords: Bool

    @Parameter(title: "Spellings", default: [.plain])
    var twists: [WordTwist]

    @Parameter(title: "Pattern", default: .random)
    var pattern: WordPattern

    @Parameter(title: "Alliterate", default: false)
    var alliterate: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$themes) username with \(\.$wordCount) words") {
            \.$separators
            \.$pattern
            \.$alliterate
            \.$wordCases
            \.$twists
            \.$digits
            \.$maxLength
            \.$lettersAndDigitsOnly
            \.$includeBlockedWords
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let options = UsernameOptions(
            wordCount: wordCount,
            separators: Set(separators.map(\.separator)),
            wordCases: Set(wordCases),
            includeNumber: digits > 0,
            digitCount: max(digits, 1),
            themes: Set(themes),
            limitLength: maxLength != nil,
            maxLength: maxLength ?? UsernameOptions().maxLength,
            lettersAndDigitsOnly: lettersAndDigitsOnly,
            includeBlockedWords: includeBlockedWords,
            twists: Set(twists),
            pattern: pattern,
            alliterate: alliterate
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
