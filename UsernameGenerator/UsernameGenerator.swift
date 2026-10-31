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

nonisolated enum WordSeparator: String, CaseIterable, Identifiable, Sendable, SetStorable {
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

nonisolated enum WordCase: String, CaseIterable, Identifiable, Sendable, SetStorable {
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

nonisolated enum WordPattern: String, CaseIterable, Identifiable, Sendable {
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

nonisolated struct UsernameOptions: Equatable {
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

        // Each distinct source is filtered once, however many slots share it.
        func makePools(for count: Int, _ transform: ([String]) -> [String]) -> [[String]] {
            switch options.pattern {
            case .random:
                let source = words ?? WordTheme.words(for: options.effectiveThemes, includingBlocked: options.includeBlockedWords)
                return Array(repeating: transform(source), count: count)
            case .adjectiveNoun:
                let adjectivePool = adjectives ?? words ?? WordList.adjectives
                let nounPool = nouns ?? words ?? WordTheme.nouns(for: options.effectiveThemes, includingBlocked: options.includeBlockedWords)
                return Array(repeating: transform(adjectivePool), count: count - 1) + [transform(nounPool)]
            }
        }

        var pools = makePools(for: wordCount) { $0 }
        guard !pools.contains(where: \.isEmpty) else { return nil }

        if options.limitLength {
            let limit = options.maxLength.clamped(to: UsernameOptions.maxLengthRange)
            while true {
                // Digits are joined with the separator too, so they cost one extra separator.
                let separators = wordCount - 1 + (digitCount > 0 ? 1 : 0)
                let budget = (limit - digitCount - separator.utf8.count * separators) / wordCount
                // The word lists are ASCII, so UTF-8 length is the character count and much cheaper to read.
                let fitting = makePools(for: wordCount) { $0.filter { $0.utf8.count <= budget } }
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
                    pools = makePools(for: wordCount) { pool in
                        let shortest = pool.map(\.utf8.count).min()!
                        return pool.filter { $0.utf8.count == shortest }
                    }
                    break
                }
            }
        }
        return Plan(pools: pools, digitCount: digitCount, separator: separator)
    }

    /// A plan plus, when alliterating, each slot's words grouped by first letter.
    private struct Prepared {
        var plan: Plan
        var buckets: [[Character: [String]]] = []
        /// First letters that every slot has a word for. Empty means alliteration isn't possible.
        var letters: [Character] = []
    }

    private func prepare(options: UsernameOptions, separator: WordSeparator) -> Prepared? {
        guard let plan = plan(options: options, separator: separator) else { return nil }
        guard options.alliterate else { return Prepared(plan: plan) }
        // Slots that share a pool (the same array buffer) are grouped once.
        var buckets: [[Character: [String]]] = []
        for (index, pool) in plan.pools.enumerated() {
            if index > 0, pool == plan.pools[index - 1] {
                buckets.append(buckets[index - 1])
            } else {
                buckets.append(Dictionary(grouping: pool) { $0.first! })
            }
        }
        let keySets = buckets.map { Set($0.keys) }
        let shared = keySets.dropFirst().reduce(keySets.first ?? []) { $0.intersection($1) }
        return Prepared(plan: plan, buckets: buckets, letters: shared.sorted())
    }

    private func build<R: RandomNumberGenerator>(options: UsernameOptions, prepared: Prepared, using rng: inout R) -> String {
        var pools = prepared.plan.pools
        if let letter = prepared.letters.randomElement(using: &rng) {
            pools = prepared.buckets.map { $0[letter] ?? [] }
        }

        let wordCase = options.effectiveCases.randomElement(using: &rng)!
        var parts = wordCase.apply(to: pools.map { $0.randomElement(using: &rng)! })
        if prepared.plan.digitCount > 0 {
            let digits = (0..<prepared.plan.digitCount).map { _ in String(Int.random(in: 0...9, using: &rng)) }
            parts.append(digits.joined())
        }
        return parts.joined(separator: prepared.plan.separator)
    }

    /// Plans are built once per separator and kept in `cache`, so a batch doesn't repeat that work.
    private func generate<R: RandomNumberGenerator>(options: UsernameOptions, cache: inout [WordSeparator: Prepared], using rng: inout R) -> String {
        let separator = options.effectiveSeparators.randomElement(using: &rng)!
        if cache[separator] == nil {
            cache[separator] = prepare(options: options, separator: separator)
        }
        guard let prepared = cache[separator] else { return "" }
        return build(options: options, prepared: prepared, using: &rng)
    }

    /// Builds a username from random words, optionally followed by random digits.
    /// The default random source is the system's cryptographically secure generator.
    func generate<R: RandomNumberGenerator>(options: UsernameOptions, using rng: inout R) -> String {
        var cache: [WordSeparator: Prepared] = [:]
        return generate(options: options, cache: &cache, using: &rng)
    }

    func generate(options: UsernameOptions) -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(options: options, using: &rng)
    }

    func generateBatch(options: UsernameOptions, count: Int) -> [String] {
        var rng = SystemRandomNumberGenerator()
        var cache: [WordSeparator: Prepared] = [:]
        return (0..<count).map { _ in generate(options: options, cache: &cache, using: &rng) }
    }

    /// How many different usernames these options can produce. A `Double` because five words
    /// plus six digits is far beyond `UInt64`.
    func combinationCount(options: UsernameOptions) -> Double {
        func product(_ pools: [[String]]) -> Double {
            pools.reduce(1) { $0 * Double($1.count) }
        }
        func count(_ prepared: Prepared) -> Double {
            let plan = prepared.plan
            // Styles that look identical for this many words (camel and lower with one word) count once.
            let sample = Array(repeating: "ab", count: plan.pools.count)
            let styles = Double(Set(options.effectiveCases.map { $0.apply(to: sample) }).count)
            let digits = pow(10, Double(plan.digitCount)) * styles
            guard !prepared.letters.isEmpty else { return product(plan.pools) * digits }
            let words = prepared.letters.reduce(0.0) { total, letter in
                total + prepared.buckets.reduce(1.0) { $0 * Double($1[letter]?.count ?? 0) }
            }
            return words * digits
        }

        var total = 0.0
        // A lone word or number has nothing to join, so every separator gives the same username.
        var countedUnjoined = false
        // Without a length limit the separator doesn't change the plan, so work out its count once.
        var shared: (count: Double, unjoined: Bool)?
        for separator in options.effectiveSeparators {
            let result: (count: Double, unjoined: Bool)
            if let shared, !options.limitLength {
                result = shared
            } else {
                guard let prepared = prepare(options: options, separator: separator) else { return 0 }
                let plan = prepared.plan
                result = (count(prepared), plan.pools.count + (plan.digitCount > 0 ? 1 : 0) <= 1)
                shared = result
            }
            if result.unjoined {
                if countedUnjoined { continue }
                countedUnjoined = true
            }
            total += result.count
        }
        return total
    }
}

private extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
