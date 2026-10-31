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

/// Respellings applied to the vocabulary itself, so length limits and counts see the final words.
nonisolated enum WordTwist: String, CaseIterable, Identifiable, Sendable, SetStorable {
    case plain
    case leet
    case noVowels

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: "Plain"
        case .leet: "Leetspeak (l33t)"
        case .noVowels: "No vowels (qt)"
        }
    }

    func apply(to word: String) -> String {
        switch self {
        case .plain:
            return word
        case .leet:
            return String(word.map { character -> Character in
                switch character {
                case "a", "A": "4"
                case "e", "E": "3"
                case "i", "I": "1"
                case "o", "O": "0"
                default: character
                }
            })
        case .noVowels:
            // The first letter stays so the word is still recognizable and alliteration still works.
            return String(word.prefix(1)) + word.dropFirst().filter { !"aeiouAEIOU".contains($0) }
        }
    }

    /// The whole pool respelled, without repeats (several words can collapse to one).
    func apply(to pool: [String]) -> [String] {
        guard self != .plain else { return pool }
        var seen = Set<String>()
        return pool.map { apply(to: $0) }.filter { seen.insert($0).inserted }
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

/// Where a pinned word goes in the username.
nonisolated enum PinPosition: String, CaseIterable, Identifiable, Sendable {
    case start
    case end

    var id: String { rawValue }

    var label: String {
        switch self {
        case .start: "Start"
        case .end: "End"
        }
    }
}

/// A word fixed into one end of the username.
nonisolated struct PinnedWord: Equatable, Sendable {
    var word: String
    var position: PinPosition
}

/// A username plus the words it was built from (before capitalization), so one can be kept and rerolled around.
nonisolated struct GeneratedUsername: Equatable, Hashable, Sendable {
    var text: String
    var words: [String]
}

nonisolated struct UsernameOptions: Equatable {
    static let wordCountRange = 1...5
    static let digitCountRange = 1...6
    static let maxLengthRange = 6...30
    static let pinnedWordMaxLength = 20

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
    /// Each username uses one of these, chosen at random.
    var twists: Set<WordTwist> = [.plain]
    /// Adjectives first and a noun last, like BraveBadger.
    var pattern = WordPattern.random
    /// Every word starts with the same letter, like BraveBadger.
    var alliterate = false
    /// A word of your own that takes one of the word slots. Empty means none.
    var pinnedWord = ""
    var pinnedPosition = PinPosition.start
    /// A word kept from a result, so the rest can be rerolled. It sits alongside your own word.
    var keptWord = ""
    var keptPosition = PinPosition.start
    /// Pronounceable invented words instead of real ones. Themes and patterns don't apply to these.
    var madeUpWords = false

    /// What the settings screen does to the saved choices before generating. One word has nothing to
    /// pattern or alliterate, and made-up words have no patterns. The saved choices themselves are kept.
    /// A kept word sits alongside your own word and never replaces it.
    func applyingScreenRules(kept: PinnedWord?) -> UsernameOptions {
        var options = self
        if wordCount <= 1 || madeUpWords { options.pattern = .random }
        if wordCount <= 1 { options.alliterate = false }
        options.keptWord = kept?.word ?? ""
        options.keptPosition = kept?.position ?? .start
        return options
    }

    var effectiveSeparators: [WordSeparator] {
        let separators = WordSeparator.allCases.filter(separators.contains)
        return lettersAndDigitsOnly || separators.isEmpty ? [.none] : separators
    }

    /// In a fixed order so results are reproducible with a seeded generator. Never empty.
    var effectiveCases: [WordCase] {
        let cases = WordCase.allCases.filter(wordCases.contains)
        return cases.isEmpty ? [.title] : cases
    }

    var effectiveTwists: [WordTwist] {
        let twists = WordTwist.allCases.filter(twists.contains)
        return twists.isEmpty ? [.plain] : twists
    }

    /// The pinned word as typed, cleaned up: lowercase ASCII letters and digits, capped in length. Nil if nothing is left.
    var effectivePinnedWord: String? { Self.cleaned(pinnedWord) }

    var effectiveKeptWord: String? { Self.cleaned(keptWord) }

    private static func cleaned(_ text: String) -> String? {
        let cleaned = text.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let word = String(cleaned.prefix(pinnedWordMaxLength))
        return word.isEmpty ? nil : word
    }

    /// Your own word, then the kept one. When there are too many for the words, the earliest go first.
    /// A kept word that matches your own is not added twice.
    var effectivePins: [PinnedWord] {
        var pins: [PinnedWord] = []
        if let word = effectivePinnedWord { pins.append(PinnedWord(word: word, position: pinnedPosition)) }
        if let word = effectiveKeptWord, word != effectivePinnedWord { pins.append(PinnedWord(word: word, position: keptPosition)) }
        return pins
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
    private func plan(options: UsernameOptions, separator: WordSeparator, twist: WordTwist) -> Plan? {
        var wordCount = options.wordCount.clamped(to: UsernameOptions.wordCountRange)
        // Each takes one of the word slots. They are never filtered, since they were chosen on purpose.
        var pins = options.effectivePins.map { PinnedWord(word: twist.apply(to: $0.word), position: $0.position) }
        while pins.count > wordCount { pins.removeFirst() }
        var digitCount = options.includeNumber ? options.digitCount.clamped(to: UsernameOptions.digitCountRange) : 0
        let separator = separator.rawValue

        // Made-up words are one vocabulary for every slot, so there are no themes or patterns.
        let pattern = options.madeUpWords ? WordPattern.random : options.pattern
        // The vocabularies are respelled once. Each distinct source is then filtered once, however many slots share it.
        let anyPool = pattern == .random
            ? twist.apply(to: options.madeUpWords
                ? MadeUpWords.pool
                : words ?? WordTheme.words(for: options.effectiveThemes, includingBlocked: options.includeBlockedWords))
            : []
        let adjectivePool = pattern == .adjectiveNoun ? twist.apply(to: adjectives ?? words ?? WordList.adjectives) : []
        let nounPool = pattern == .adjectiveNoun
            ? twist.apply(to: nouns ?? words ?? WordTheme.nouns(for: options.effectiveThemes, includingBlocked: options.includeBlockedWords))
            : []
        func makePools(for count: Int, _ transform: ([String]) -> [String]) -> [[String]] {
            var pools: [[String]]
            switch pattern {
            case .random:
                pools = Array(repeating: transform(anyPool), count: count)
            case .adjectiveNoun:
                pools = Array(repeating: transform(adjectivePool), count: count - 1) + [transform(nounPool)]
            }
            // Pins at the start fill from the front and pins at the end from the back, in order.
            // With adjective + noun, the start is an adjective slot and the end is the noun slot.
            let starts = pins.filter { $0.position == .start }
            let ends = pins.filter { $0.position == .end }
            for (index, pin) in starts.enumerated() { pools[index] = [pin.word] }
            for (index, pin) in ends.enumerated() { pools[count - ends.count + index] = [pin.word] }
            return pools
        }

        var pools = makePools(for: wordCount) { $0 }
        guard !pools.contains(where: \.isEmpty) else { return nil }

        if options.limitLength {
            let limit = options.maxLength.clamped(to: UsernameOptions.maxLengthRange)
            while true {
                // Digits are joined with the separator too, so they cost one extra separator.
                let separators = wordCount - 1 + (digitCount > 0 ? 1 : 0)
                while pins.count > wordCount { pins.removeFirst() }
                let pinnedLength = pins.reduce(0) { $0 + $1.word.utf8.count }
                let freeSlots = wordCount - pins.count
                let used = digitCount + separator.utf8.count * separators + pinnedLength
                if freeSlots == 0 {
                    // Only pinned words are left. Drop digits, then the earliest pin, then shorten the last word.
                    if used <= limit {
                        pools = makePools(for: wordCount) { $0 }
                        break
                    }
                    if digitCount > 0 {
                        digitCount -= 1
                    } else if pins.count > 1 {
                        pins.removeFirst()
                    } else {
                        pins[0].word = String(pins[0].word.prefix(limit))
                    }
                    continue
                }
                let budget = (limit - used) / freeSlots
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

    private func prepare(options: UsernameOptions, separator: WordSeparator, twist: WordTwist) -> Prepared? {
        guard let plan = plan(options: options, separator: separator, twist: twist) else { return nil }
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

    private func build<R: RandomNumberGenerator>(options: UsernameOptions, prepared: Prepared, using rng: inout R) -> GeneratedUsername {
        var pools = prepared.plan.pools
        if let letter = prepared.letters.randomElement(using: &rng) {
            pools = prepared.buckets.map { $0[letter] ?? [] }
        }

        let wordCase = options.effectiveCases.randomElement(using: &rng)!
        let words = pools.map { $0.randomElement(using: &rng)! }
        var parts = wordCase.apply(to: words)
        if prepared.plan.digitCount > 0 {
            let digits = (0..<prepared.plan.digitCount).map { _ in String(Int.random(in: 0...9, using: &rng)) }
            parts.append(digits.joined())
        }
        return GeneratedUsername(text: parts.joined(separator: prepared.plan.separator), words: words)
    }

    private struct PlanKey: Hashable {
        var separator: WordSeparator
        var twist: WordTwist
    }

    /// Plans are built once per separator and twist and kept in `cache`, so a batch doesn't repeat that work.
    private func generate<R: RandomNumberGenerator>(options: UsernameOptions, cache: inout [PlanKey: Prepared], using rng: inout R) -> GeneratedUsername {
        let key = PlanKey(
            separator: options.effectiveSeparators.randomElement(using: &rng)!,
            twist: options.effectiveTwists.randomElement(using: &rng)!
        )
        if cache[key] == nil {
            cache[key] = prepare(options: options, separator: key.separator, twist: key.twist)
        }
        guard let prepared = cache[key] else { return GeneratedUsername(text: "", words: []) }
        return build(options: options, prepared: prepared, using: &rng)
    }

    /// Builds a username from random words, optionally followed by random digits.
    /// The default random source is the system's cryptographically secure generator.
    func generate<R: RandomNumberGenerator>(options: UsernameOptions, using rng: inout R) -> String {
        var cache: [PlanKey: Prepared] = [:]
        return generate(options: options, cache: &cache, using: &rng).text
    }

    func generate(options: UsernameOptions) -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(options: options, using: &rng)
    }

    func generateBatch(options: UsernameOptions, count: Int) -> [String] {
        var rng = SystemRandomNumberGenerator()
        var cache: [PlanKey: Prepared] = [:]
        return (0..<count).map { _ in generate(options: options, cache: &cache, using: &rng).text }
    }

    /// Like `generateBatch`, but keeps each username's words so one can be kept while the rest are rerolled.
    func generateDetailedBatch(options: UsernameOptions, count: Int) -> [GeneratedUsername] {
        var rng = SystemRandomNumberGenerator()
        var cache: [PlanKey: Prepared] = [:]
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
        for twist in options.effectiveTwists {
            // A lone word or number has nothing to join, so every separator gives the same username.
            var countedUnjoined = false
            // Without a length limit the separator doesn't change the plan, so work out its count once.
            var shared: (count: Double, unjoined: Bool)?
            for separator in options.effectiveSeparators {
                let result: (count: Double, unjoined: Bool)
                if let shared, !options.limitLength {
                    result = shared
                } else {
                    guard let prepared = prepare(options: options, separator: separator, twist: twist) else { return 0 }
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
        }
        return total
    }
}

private extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
