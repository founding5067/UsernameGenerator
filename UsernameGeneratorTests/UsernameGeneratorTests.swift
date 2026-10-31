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
        let options = UsernameOptions(wordCount: wordCount, separator: .hyphen, includeNumber: false)
        let parts = generator.generate(options: options).split(separator: "-")
        #expect(parts.count == wordCount)
    }

    @Test(arguments: UsernameOptions.digitCountRange)
    func digitsAppendedAtEnd(digitCount: Int) {
        let options = UsernameOptions(wordCount: 2, separator: .underscore, includeNumber: true, digitCount: digitCount)
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
        let lower = generator.generate(options: UsernameOptions(separator: .period, wordCase: .lower, includeNumber: false))
        #expect(lower == lower.lowercased())

        let upper = generator.generate(options: UsernameOptions(separator: .period, wordCase: .upper, includeNumber: false))
        #expect(upper == upper.uppercased())

        let title = generator.generate(options: UsernameOptions(separator: .period, wordCase: .title, includeNumber: false))
        for word in title.split(separator: ".") {
            #expect(word.first?.isUppercase == true)
            let restIsLowercase = word.dropFirst().allSatisfy(\.isLowercase)
            #expect(restIsLowercase)
        }
    }

    @Test func noSeparatorJoinsWords() {
        let options = UsernameOptions(wordCount: 2, separator: .none, wordCase: .lower, includeNumber: false)
        let name = generator.generate(options: options)
        let startsWithWord = ["alpha", "bravo", "charlie"].contains { name.hasPrefix($0) }
        let hasSeparator = name.contains { "-_.".contains($0) }
        #expect(startsWithWord)
        #expect(!hasSeparator)
    }

    @Test func outOfRangeOptionsAreClamped() {
        let options = UsernameOptions(wordCount: 99, separator: .hyphen, includeNumber: true, digitCount: 99)
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
                        wordCount: wordCount, separator: .hyphen, includeNumber: true, digitCount: digitCount,
                        theme: theme, limitLength: true, maxLength: limit
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
        let options = UsernameOptions(wordCount: 3, separator: .hyphen, lettersAndDigitsOnly: true)
        for _ in 0..<50 {
            let name = UsernameGenerator().generate(options: options)
            let ok = name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
            #expect(ok, "\(name)")
        }
    }

    @Test func themeControlsVocabulary() {
        let animals = Set(WordTheme.animals.words)
        let options = UsernameOptions(wordCount: 1, wordCase: .lower, includeNumber: false, theme: .animals)
        for _ in 0..<50 {
            #expect(animals.contains(UsernameGenerator().generate(options: options)))
        }
    }

    @Test func batchHasRequestedCount() {
        #expect(UsernameGenerator().generateBatch(options: UsernameOptions(), count: 5).count == 5)
    }

    @Test func intentReturnsUsername() async throws {
        let intent = GenerateUsernameIntent()
        intent.wordCount = 2
        intent.theme = .space
        intent.separator = .hyphen
        intent.wordCase = .lower
        intent.digits = 0
        intent.maxLength = 12
        intent.lettersAndDigitsOnly = false
        let result = try await intent.perform()
        let value = result.value ?? ""
        #expect(!value.isEmpty)
        #expect(value.count <= 12)
    }
}
