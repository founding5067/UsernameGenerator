//
//  UsernameGenerator.swift
//  UsernameGenerator
//

import Foundation

/// Options that can be picked several at a time are stored as comma-separated raw values,
/// so a set fits in one `@AppStorage` string.
nonisolated protocol SetStorable: CaseIterable, Hashable, RawRepresentable where RawValue == String {}

extension SetStorable {
    nonisolated static func encode(_ values: Set<Self>) -> String {
        allCases.filter(values.contains).map(\.rawValue).joined(separator: ",")
    }

    nonisolated static func decode(_ string: String) -> Set<Self> {
        // Empty pieces are kept: `WordSeparator.none` is stored as an empty raw value.
        Set(string.split(separator: ",", omittingEmptySubsequences: false).compactMap { Self(rawValue: String($0)) })
    }
}

nonisolated enum WordSeparator: String, CaseIterable, Codable, Identifiable, Sendable, SetStorable {
    case none = ""
    case hyphen = "-"
    case underscore = "_"
    case period = "."
    case plus = "+"
    case tilde = "~"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .hyphen: "Hyphen ( - )"
        case .underscore: "Underscore ( _ )"
        case .period: "Period ( . )"
        case .plus: "Plus ( + )"
        case .tilde: "Tilde ( ~ )"
        }
    }
}

nonisolated enum WordCase: String, CaseIterable, Codable, Identifiable, Sendable, SetStorable {
    case lower
    case title
    case camel
    case sentence
    case upper
    case alternating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lower: "lowercase"
        case .title: "TitleCase"
        case .camel: "camelCase"
        case .sentence: "Sentence case"
        case .upper: "UPPERCASE"
        case .alternating: "aLtErNaTiNg"
        }
    }

    /// Styles depend on a word's position, so they are applied to all the words at once.
    func apply(to words: [String]) -> [String] {
        func capitalized(_ word: String) -> String {
            word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }
        switch self {
        case .lower: return words.map { $0.lowercased() }
        case .title: return words.map(capitalized)
        case .camel: return words.enumerated().map { $0.offset == 0 ? $0.element.lowercased() : capitalized($0.element) }
        case .sentence: return words.enumerated().map { $0.offset == 0 ? capitalized($0.element) : $0.element.lowercased() }
        case .upper: return words.map { $0.uppercased() }
        case .alternating:
            var index = 0
            return words.map { word in
                String(word.map { character -> Character in
                    defer { if character.isLetter { index += 1 } }
                    let result = index.isMultiple(of: 2) ? character.lowercased() : character.uppercased()
                    return result.first ?? character
                })
            }
        }
    }

}

nonisolated enum WordPattern: String, CaseIterable, Codable, Identifiable, Sendable {
    case random
    case adjectiveNoun

    var id: String { rawValue }

    var label: String {
        switch self {
        case .random: "Any words"
        case .adjectiveNoun: "Adjective + noun"
        }
    }
}

nonisolated struct UsernameOptions: Codable, Equatable {
    static let wordCountRange = 1...5
    static let digitCountRange = 1...6
    static let maxLengthRange = 6...30

    var wordCount = 2
    /// Each username uses one of these, chosen at random.
    var separators: Set<WordSeparator> = [.none]
    /// Each username uses one of these, chosen at random.
    var wordCases: Set<WordCase> = [.title]
    var includeNumber = true
    var digitCount = 4
    /// Words come from all of these themes combined. `.any` is the whole word list.
    var themes: Set<WordTheme> = [.any]
    /// Cap the total length, for sites that limit usernames.
    var limitLength = false
    var maxLength = 15
    /// Sites that reject punctuation. Forces the separator to none.
    var lettersAndDigitsOnly = false
    /// Lets words from blocked_words.txt back into the pool.
    var includeBlockedWords = false
    /// Adjectives first and a noun last, like BraveBadger.
    var pattern = WordPattern.random
    /// Every word starts with the same letter, like BraveBadger.
    var alliterate = false

    var effectiveSeparators: [WordSeparator] {
        let separators = WordSeparator.allCases.filter(separators.contains)
        return lettersAndDigitsOnly || separators.isEmpty ? [.none] : separators
    }

    /// In a fixed order so results are reproducible with a seeded generator. Never empty.
    var effectiveCases: [WordCase] {
        let cases = WordCase.allCases.filter(wordCases.contains)
        return cases.isEmpty ? [.title] : cases
    }

    var effectiveThemes: [WordTheme] {
        let themes = WordTheme.allCases.filter(themes.contains)
        return themes.isEmpty ? [.any] : themes
    }
}

nonisolated struct UsernameGenerator {
    /// Overrides the theme's word list. Used by tests.
    var words: [String]? = nil
    /// Override the adjective and noun slots of the adjective + noun pattern. Used by tests.
    var adjectives: [String]? = nil
    var nouns: [String]? = nil

    /// The word pool for each slot, plus how many digits and which separator survive the length limit.
    private struct Plan {
        var pools: [[String]]
        var digitCount: Int
        var separator: String
    }

    /// Everything about a username that isn't random: slot vocabularies and the length budget.
    /// With a length limit, digits are dropped first, then words, so a result always fits.
    private func plan(options: UsernameOptions, separator: WordSeparator) -> Plan? {
        var wordCount = options.wordCount.clamped(to: UsernameOptions.wordCountRange)
        var digitCount = options.includeNumber ? options.digitCount.clamped(to: UsernameOptions.digitCountRange) : 0
        let separator = separator.rawValue

        func sources(for count: Int) -> [[String]] {
            switch options.pattern {
            case .random:
                let source = words ?? WordTheme.words(for: options.effectiveThemes, includingBlocked: options.includeBlockedWords)
                return Array(repeating: source, count: count)
            case .adjectiveNoun:
                let adjectivePool = adjectives ?? words ?? WordList.adjectives
                let nounPool = nouns ?? words ?? WordTheme.nouns(for: options.effectiveThemes, includingBlocked: options.includeBlockedWords)
                return Array(repeating: adjectivePool, count: count - 1) + [nounPool]
            }
        }

        var pools = sources(for: wordCount)
        guard !pools.contains(where: \.isEmpty) else { return nil }

        if options.limitLength {
            let limit = options.maxLength.clamped(to: UsernameOptions.maxLengthRange)
            while true {
                // Digits are joined with the separator too, so they cost one extra separator.
                let separators = wordCount - 1 + (digitCount > 0 ? 1 : 0)
                let budget = (limit - digitCount - separator.count * separators) / wordCount
                let sourcePools = sources(for: wordCount)
                let fitting = sourcePools.map { $0.filter { $0.count <= budget } }
                if !fitting.contains(where: \.isEmpty) {
                    pools = fitting
                    break
                }
                if digitCount > 0 {
                    digitCount -= 1
                } else if wordCount > 1 {
                    wordCount -= 1
                } else {
                    // Nothing in the list is short enough. Use the shortest word available.
                    pools = sourcePools.map { pool in
                        let shortest = pool.map(\.count).min()!
                        return pool.filter { $0.count == shortest }
                    }
                    break
                }
            }
        }
        return Plan(pools: pools, digitCount: digitCount, separator: separator)
    }

    /// First letters that every slot has a word for. Empty means alliteration isn't possible.
    private func sharedLetters(_ pools: [[String]]) -> [Character] {
        let sets = pools.map { Set($0.compactMap(\.first)) }
        guard let first = sets.first else { return [] }
        return sets.dropFirst().reduce(first) { $0.intersection($1) }.sorted()
    }

    /// Builds a username from random words, optionally followed by random digits.
    /// The default random source is the system's cryptographically secure generator.
    func generate<R: RandomNumberGenerator>(options: UsernameOptions, using rng: inout R) -> String {
        let separator = options.effectiveSeparators.randomElement(using: &rng)!
        guard var plan = plan(options: options, separator: separator) else { return "" }

        if options.alliterate, let letter = sharedLetters(plan.pools).randomElement(using: &rng) {
            plan.pools = plan.pools.map { $0.filter { $0.first == letter } }
        }

        let wordCase = options.effectiveCases.randomElement(using: &rng)!
        var parts = wordCase.apply(to: plan.pools.map { $0.randomElement(using: &rng)! })
        if plan.digitCount > 0 {
            let digits = (0..<plan.digitCount).map { _ in String(Int.random(in: 0...9, using: &rng)) }
            parts.append(digits.joined())
        }
        return parts.joined(separator: plan.separator)
    }

    func generate(options: UsernameOptions) -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(options: options, using: &rng)
    }

    func generateBatch(options: UsernameOptions, count: Int) -> [String] {
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { _ in generate(options: options, using: &rng) }
    }

    /// How many different usernames these options can produce. A `Double` because five words
    /// plus six digits is far beyond `UInt64`.
    func combinationCount(options: UsernameOptions) -> Double {
        func product(_ pools: [[String]]) -> Double {
            pools.reduce(1) { $0 * Double($1.count) }
        }
        func count(_ plan: Plan) -> Double {
            // Styles that look identical for this many words (camel and lower with one word) count once.
            let sample = Array(repeating: "ab", count: plan.pools.count)
            let styles = Double(Set(options.effectiveCases.map { $0.apply(to: sample) }).count)
            let digits = pow(10, Double(plan.digitCount)) * styles
            let letters = options.alliterate ? sharedLetters(plan.pools) : []
            guard !letters.isEmpty else { return product(plan.pools) * digits }
            let words = letters.reduce(0.0) { total, letter in
                total + product(plan.pools.map { $0.filter { $0.first == letter } })
            }
            return words * digits
        }

        var total = 0.0
        // A lone word or number has nothing to join, so every separator gives the same username.
        var countedUnjoined = false
        for separator in options.effectiveSeparators {
            guard let plan = plan(options: options, separator: separator) else { return 0 }
            if plan.pools.count + (plan.digitCount > 0 ? 1 : 0) <= 1 {
                if countedUnjoined { continue }
                countedUnjoined = true
            }
            total += count(plan)
        }
        return total
    }
}

private extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
