//
//  UsernameGeneratorTests.swift
//  UsernameGeneratorTests
//
//  Created by Cole Braswell on 10/30/26.
//

import AppIntents
import Testing
@testable import UsernameGenerator

struct UsernameGeneratorTests {
    private let generator = UsernameGenerator(words: ["alpha", "bravo", "charlie"])

    @Test func bundledWordListLoads() {
        #expect(WordList.effUnfiltered.count == 7775)
        #expect(WordList.eff.count == WordList.effUnfiltered.count - WordList.blocked.count)
        let allLowercase = WordList.eff.allSatisfy { $0.allSatisfy(\.isLowercase) }
        #expect(allLowercase)
    }

    @Test func blockedWordsAreRemoved() {
        let unfiltered = Set(WordList.effUnfiltered)
        let typos = WordList.blocked.subtracting(unfiltered).sorted()
        let leaked = Set(WordList.eff).intersection(WordList.blocked).sorted()
        #expect(!WordList.blocked.isEmpty)
        #expect(typos.isEmpty, "Blocked words not in the EFF list (typos?): \(typos)")
        #expect(leaked.isEmpty)
    }

    @Test(arguments: UsernameOptions.wordCountRange)
    func wordCountAndSeparator(wordCount: Int) {
        let options = UsernameOptions(wordCount: wordCount, separators: [.hyphen], includeNumber: false)
        let parts = generator.generate(options: options).split(separator: "-")
        #expect(parts.count == wordCount)
    }

    @Test(arguments: UsernameOptions.digitCountRange)
    func digitsAppendedAtEnd(digitCount: Int) {
        let options = UsernameOptions(wordCount: 2, separators: [.underscore], includeNumber: true, digitCount: digitCount)
        let parts = generator.generate(options: options).split(separator: "_")
        #expect(parts.count == 3)
        #expect(parts.last?.count == digitCount)
        let allDigits = parts.last?.allSatisfy(\.isNumber) ?? false
        #expect(allDigits)
    }

    @Test func noDigitsWhenNumbersOff() {
        let options = UsernameOptions(wordCount: 3, includeNumber: false)
        for _ in 0..<50 {
            let hasDigit = generator.generate(options: options).contains(where: \.isNumber)
            #expect(!hasDigit)
        }
    }

    @Test func capitalization() {
        let lower = generator.generate(options: UsernameOptions(separators: [.period], wordCases: [.lower], includeNumber: false))
        #expect(lower == lower.lowercased())

        let upper = generator.generate(options: UsernameOptions(separators: [.period], wordCases: [.upper], includeNumber: false))
        #expect(upper == upper.uppercased())

        let title = generator.generate(options: UsernameOptions(separators: [.period], wordCases: [.title], includeNumber: false))
        for word in title.split(separator: ".") {
            #expect(word.first?.isUppercase == true)
            let restIsLowercase = word.dropFirst().allSatisfy(\.isLowercase)
            #expect(restIsLowercase)
        }
    }

    @Test func noSeparatorJoinsWords() {
        let options = UsernameOptions(wordCount: 2, separators: [.none], wordCases: [.lower], includeNumber: false)
        let name = generator.generate(options: options)
        let startsWithWord = ["alpha", "bravo", "charlie"].contains { name.hasPrefix($0) }
        let hasSeparator = name.contains { "-_.".contains($0) }
        #expect(startsWithWord)
        #expect(!hasSeparator)
    }

    @Test func outOfRangeOptionsAreClamped() {
        let options = UsernameOptions(wordCount: 99, separators: [.hyphen], includeNumber: true, digitCount: 99)
        let parts = generator.generate(options: options).split(separator: "-")
        #expect(parts.count == UsernameOptions.wordCountRange.upperBound + 1)
        #expect(parts.last?.count == UsernameOptions.digitCountRange.upperBound)
    }

    @Test(arguments: WordTheme.allCases.filter { $0 != .any })
    func themesAreCleanSubsetsOfEFF(theme: WordTheme) {
        let words = theme.words
        let eff = Set(WordList.effUnfiltered)
        let notInEFF = words.filter { !eff.contains($0) }
        let blocked = words.filter { WordList.blocked.contains($0) }
        #expect(words.count >= 20)
        #expect(notInEFF.isEmpty, "Not in EFF list: \(notInEFF)")
        #expect(blocked.isEmpty)
    }

    @Test func blockedWordsAreOffByDefaultAndOptIn() {
        #expect(UsernameOptions().includeBlockedWords == false)
        #expect(WordTheme.any.words(includingBlocked: true).count == WordList.effUnfiltered.count)
        #expect(Set(WordTheme.any.words(includingBlocked: false)).isDisjoint(with: WordList.blocked))
        for theme in WordTheme.allCases {
            #expect(Set(theme.words).isSubset(of: Set(theme.words(includingBlocked: true))))
        }
    }

    @Test(arguments: UsernameOptions.maxLengthRange)
    func lengthLimitIsAlwaysRespected(limit: Int) {
        for theme in WordTheme.allCases {
            for wordCount in UsernameOptions.wordCountRange {
                for digitCount in UsernameOptions.digitCountRange {
                    let options = UsernameOptions(
                        wordCount: wordCount, separators: [.hyphen], includeNumber: true, digitCount: digitCount,
                        themes: [theme], limitLength: true, maxLength: limit
                    )
                    for _ in 0..<5 {
                        let name = UsernameGenerator().generate(options: options)
                        #expect(!name.isEmpty)
                        #expect(name.count <= limit, "\(name) exceeds \(limit)")
                    }
                }
            }
        }
    }

    @Test func lettersAndDigitsOnlyHasNoPunctuation() {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], lettersAndDigitsOnly: true)
        for _ in 0..<50 {
            let name = UsernameGenerator().generate(options: options)
            let ok = name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
            #expect(ok, "\(name)")
        }
    }

    @Test func themeControlsVocabulary() {
        let animals = Set(WordTheme.animals.words)
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, themes: [.animals])
        for _ in 0..<50 {
            #expect(animals.contains(UsernameGenerator().generate(options: options)))
        }
    }

    @Test func multipleThemesCombineVocabularies() {
        let combined = Set(WordTheme.animals.words).union(WordTheme.space.words)
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, themes: [.animals, .space])
        var seen = Set<String>()
        for _ in 0..<400 {
            let word = UsernameGenerator().generate(options: options)
            #expect(combined.contains(word))
            seen.insert(word)
        }
        #expect(!seen.isDisjoint(with: WordTheme.animals.words))
        #expect(!seen.isDisjoint(with: WordTheme.space.words))
    }

    @Test func overlappingThemesCountWordsOnce() {
        let all = WordTheme.words(for: [.any, .animals], includingBlocked: false)
        #expect(all.count == Set(all).count)
        #expect(all.count == WordList.eff.count)
        let both = WordTheme.words(for: [.animals, .colors], includingBlocked: false)
        #expect(both.count == Set(WordTheme.animals.words).union(WordTheme.colors.words).count)
    }

    @Test func emptyThemeSetFallsBackToAny() {
        let options = UsernameOptions(wordCount: 1, includeNumber: false, themes: [])
        #expect(options.effectiveThemes == [.any])
        #expect(!UsernameGenerator().generate(options: options).isEmpty)
    }

    @Test func themeSetEncodingRoundTrips() {
        let themes: Set<WordTheme> = [.animals, .music, .fantasy]
        #expect(WordTheme.decode(WordTheme.encode(themes)) == themes)
    }

    @Test func multipleSeparatorsMixButStayWithinSelection() {
        let g = UsernameGenerator(words: ["ant"])
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen, .none, .tilde], wordCases: [.lower], includeNumber: false)
        let results = Set((0..<300).map { _ in g.generate(options: options) })
        #expect(results == ["ant-ant", "antant", "ant~ant"])
    }

    @Test func lettersAndDigitsOnlyOverridesSeparators() {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen, .plus], lettersAndDigitsOnly: true)
        #expect(options.effectiveSeparators == [.none])
    }

    @Test func separatorSetEncodingKeepsNone() {
        for set: Set<WordSeparator> in [[.none], [.none, .hyphen], [.period, .tilde]] {
            #expect(WordSeparator.decode(WordSeparator.encode(set)) == set)
        }
    }

    @Test func lengthLimitHoldsWithMixedSeparators() {
        let options = UsernameOptions(wordCount: 3, separators: [.none, .hyphen, .plus], includeNumber: true,
                                      digitCount: 4, limitLength: true, maxLength: 12)
        for _ in 0..<200 {
            let name = UsernameGenerator().generate(options: options)
            #expect(name.count <= 12, "\(name)")
        }
    }

    @Test func separatorsMultiplyCombinationsOnlyWhenThereIsSomethingToJoin() {
        let g = UsernameGenerator(words: ["ant", "bee", "cat"])
        func count(_ words: Int, digits: Bool) -> Double {
            g.combinationCount(options: UsernameOptions(
                wordCount: words, separators: [.hyphen, .underscore], includeNumber: digits, digitCount: 1))
        }
        #expect(count(2, digits: false) == 18)
        #expect(count(1, digits: false) == 3)
        #expect(count(1, digits: true) == 60)
    }

    @Test func batchHasRequestedCount() {
        #expect(UsernameGenerator().generateBatch(options: UsernameOptions(), count: 5).count == 5)
    }

    @Test func intentReturnsUsername() async throws {
        let intent = GenerateUsernameIntent()
        intent.wordCount = 2
        intent.themes = [.space]
        intent.separators = [.hyphen]
        intent.wordCases = [.lower]
        intent.digits = 0
        intent.maxLength = 12
        intent.lettersAndDigitsOnly = false
        let result = try await intent.perform()
        let value = result.value ?? ""
        #expect(!value.isEmpty)
        #expect(value.count <= 12)
    }

    @Test func patternWordListsAreCleanSubsetsOfEFF() {
        let eff = Set(WordList.effUnfiltered)
        #expect(WordList.adjectives.count >= 100)
        #expect(WordList.nouns.count >= 100)
        for list in [WordList.adjectives, WordList.nouns] {
            let notInEFF = list.filter { !eff.contains($0) }
            #expect(notInEFF.isEmpty, "Not in EFF list: \(notInEFF)")
            #expect(Set(list).isDisjoint(with: WordList.blocked))
        }
    }

    @Test func adjectiveNounPattern() {
        let adjectives = Set(WordList.adjectives)
        let nouns = Set(WordTheme.any.nouns(includingBlocked: false))
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      pattern: .adjectiveNoun)
        for _ in 0..<50 {
            let parts = UsernameGenerator().generate(options: options).split(separator: "-").map(String.init)
            #expect(parts.count == 3)
            #expect(adjectives.contains(parts[0]) && adjectives.contains(parts[1]))
            #expect(nouns.contains(parts[2]))
        }
    }

    @Test(arguments: [false, true])
    func alliterationSharesFirstLetter(limited: Bool) {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      limitLength: limited, maxLength: 20, alliterate: true)
        for _ in 0..<100 {
            let name = UsernameGenerator().generate(options: options)
            #expect(Set(name.split(separator: "-").compactMap(\.first)).count == 1, "\(name)")
            if limited { #expect(name.count <= 20) }
        }
    }

    @Test func extraCaseStyles() {
        let words = ["brave", "badger", "cat"]
        #expect(WordCase.camel.apply(to: words) == ["brave", "Badger", "Cat"])
        #expect(WordCase.sentence.apply(to: words) == ["Brave", "badger", "cat"])
        #expect(WordCase.alternating.apply(to: ["brave", "badger"]) == ["bRaVe", "BaDgEr"])
    }

    @Test func multipleCasesMixButStayWithinSelection() {
        let g = UsernameGenerator(words: ["brave"])
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower, .upper], includeNumber: false)
        let results = Set((0..<100).map { _ in g.generate(options: options) })
        #expect(results == ["brave", "BRAVE"])
    }

    @Test func emptyCaseSetFallsBackToTitle() {
        let g = UsernameGenerator(words: ["brave"])
        let options = UsernameOptions(wordCount: 1, wordCases: [], includeNumber: false)
        #expect(g.generate(options: options) == "Brave")
    }

    @Test func caseSetEncodingRoundTrips() {
        let cases: Set<WordCase> = [.camel, .upper, .alternating]
        #expect(WordCase.decode(WordCase.encode(cases)) == cases)
        #expect(WordCase.decode("bogus").isEmpty)
    }

    @Test func combinationCountsScaleWithDistinctStyles() {
        let g = UsernameGenerator(words: ["ant", "bee", "cat"])
        let base = UsernameOptions(wordCount: 2, includeNumber: false)
        func count(_ cases: Set<WordCase>, words: Int = 2) -> Double {
            var o = base
            o.wordCount = words
            o.wordCases = cases
            return g.combinationCount(options: o)
        }
        #expect(count([.lower, .upper]) == 18)
        // With one word, camel looks like lower, so it adds nothing.
        #expect(count([.lower, .camel], words: 1) == 3)
        #expect(count([.lower, .camel], words: 2) == 18)
    }

    @Test func combinationCounts() {
        let g = UsernameGenerator(words: ["ant", "bee", "cat"], adjectives: ["big", "bad", "cool"], nouns: ["bug", "cow", "cat"])
        #expect(g.combinationCount(options: UsernameOptions(wordCount: 2, digitCount: 2)) == 900)
        #expect(g.combinationCount(options: UsernameOptions(wordCount: 1, includeNumber: false)) == 3)
        // b: 2 adjectives x 1 noun, c: 1 x 2 -> 4 pairs.
        let options = UsernameOptions(wordCount: 2, includeNumber: false, pattern: .adjectiveNoun, alliterate: true)
        #expect(g.combinationCount(options: options) == 4)
        // No shared letter falls back to the full product.
        let none = UsernameGenerator(adjectives: ["big"], nouns: ["cow"])
        #expect(none.combinationCount(options: options) == 1)
    }
}
