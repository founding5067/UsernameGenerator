//
//  UsernameGenerator.swift
//  UsernameGenerator
//

import Foundation

nonisolated enum WordSeparator: String, CaseIterable, Codable, Identifiable {
    case none = ""
    case hyphen = "-"
    case underscore = "_"
    case period = "."

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .hyphen: "Hyphen ( - )"
        case .underscore: "Underscore ( _ )"
        case .period: "Period ( . )"
        }
    }
}

nonisolated enum WordCase: String, CaseIterable, Codable, Identifiable, Sendable {
    case lower
    case title
    case upper

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lower: "lowercase"
        case .title: "TitleCase"
        case .upper: "UPPERCASE"
        }
    }

    func apply(to word: String) -> String {
        switch self {
        case .lower: word.lowercased()
        case .title: word.prefix(1).uppercased() + word.dropFirst().lowercased()
        case .upper: word.uppercased()
        }
    }
}

nonisolated struct UsernameOptions: Codable, Equatable {
    static let wordCountRange = 1...5
    static let digitCountRange = 1...6
    static let maxLengthRange = 6...30

    var wordCount = 2
    var separator = WordSeparator.none
    var wordCase = WordCase.title
    var includeNumber = true
    var digitCount = 4
    var theme = WordTheme.any
    /// Cap the total length, for sites that limit usernames.
    var limitLength = false
    var maxLength = 15
    /// Sites that reject punctuation. Forces the separator to none.
    var lettersAndDigitsOnly = false

    var effectiveSeparator: WordSeparator { lettersAndDigitsOnly ? .none : separator }
}

nonisolated struct UsernameGenerator {
    /// Overrides the theme's word list. Used by tests.
    var words: [String]? = nil

    /// Builds a username from random words, optionally followed by random digits.
    /// The default random source is the system's cryptographically secure generator.
    /// With a length limit, digits are dropped first, then words, so a result always fits.
    func generate<R: RandomNumberGenerator>(options: UsernameOptions, using rng: inout R) -> String {
        let source = words ?? options.theme.words
        guard !source.isEmpty else { return "" }

        var wordCount = options.wordCount.clamped(to: UsernameOptions.wordCountRange)
        var digitCount = options.includeNumber ? options.digitCount.clamped(to: UsernameOptions.digitCountRange) : 0
        let separator = options.effectiveSeparator.rawValue

        var pool = source
        if options.limitLength {
            let limit = options.maxLength.clamped(to: UsernameOptions.maxLengthRange)
            while true {
                // Digits are joined with the separator too, so they cost one extra separator.
                let separators = wordCount - 1 + (digitCount > 0 ? 1 : 0)
                let budget = (limit - digitCount - separator.count * separators) / wordCount
                let fitting = source.filter { $0.count <= budget }
                if !fitting.isEmpty {
                    pool = fitting
                    break
                }
                if digitCount > 0 {
                    digitCount -= 1
                } else if wordCount > 1 {
                    wordCount -= 1
                } else {
                    // Nothing in the list is short enough. Use the shortest word available.
                    let shortest = source.map(\.count).min()!
                    pool = source.filter { $0.count == shortest }
                    break
                }
            }
        }

        var parts = (0..<wordCount).map { _ in
            options.wordCase.apply(to: pool.randomElement(using: &rng)!)
        }
        if digitCount > 0 {
            let digits = (0..<digitCount).map { _ in String(Int.random(in: 0...9, using: &rng)) }
            parts.append(digits.joined())
        }
        return parts.joined(separator: separator)
    }

    func generate(options: UsernameOptions) -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(options: options, using: &rng)
    }

    func generateBatch(options: UsernameOptions, count: Int) -> [String] {
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { _ in generate(options: options, using: &rng) }
    }
}

private extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
