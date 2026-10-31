//
//  PinnedWordTests.swift
//  UsernameGeneratorTests
//
//  Your own word, a word kept from a result, and the rules the settings screen applies to both.
//

import Testing
@testable import UsernameGenerator

struct PinnedWordTests {
    private let generator = UsernameGenerator(words: ["alpha", "bravo", "charlie"])

    // MARK: - Your own word

    @Test func allDigitWordIsAccepted() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: false, pinnedWord: "2024")
        #expect(generator.generate(options: options).hasPrefix("2024-"))
    }

    @Test func blockedWordTypedOnPurposeIsKept() {
        let word = WordList.blocked.sorted().first!
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, pinnedWord: word)
        #expect(UsernameGenerator(words: ["alpha"]).generate(options: options) == word)
    }

    @Test func wordThatFitsTheLimitExactlyIsNotShortened() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false,
                                      limitLength: true, maxLength: 8, pinnedWord: "abcdefgh")
        #expect(generator.generate(options: options) == "abcdefgh")
    }

    @Test func wordOneOverTheLimitIsShortenedByOne() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false,
                                      limitLength: true, maxLength: 8, pinnedWord: "abcdefghi")
        #expect(generator.generate(options: options) == "abcdefgh")
    }

    @Test func oneWordPlusDigits() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: true, digitCount: 4, pinnedWord: "cole")
        for _ in 0..<20 {
            let name = generator.generate(options: options)
            #expect(name.hasPrefix("cole") && name.count == 8, "\(name)")
            #expect(name.dropFirst(4).allSatisfy { $0.isNumber }, "\(name)")
        }
    }

    @Test func periodSeparatorJoinsTheWord() {
        let options = UsernameOptions(wordCount: 2, separators: [.period], wordCases: [.lower], includeNumber: false,
                                      pinnedWord: "cole", pinnedPosition: .end)
        #expect(generator.generate(options: options).hasSuffix(".cole"))
    }

    @Test func separatorGoesBetweenWordAndDigits() {
        let options = UsernameOptions(wordCount: 1, separators: [.underscore], wordCases: [.lower], includeNumber: true,
                                      digitCount: 3, pinnedWord: "cole")
        let parts = generator.generate(options: options).split(separator: "_")
        #expect(parts.count == 2 && parts[0] == "cole" && parts[1].count == 3)
    }

    @Test func wordIsCappedAtTwentyCharacters() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false,
                                      pinnedWord: String(repeating: "a", count: 30))
        #expect(generator.generate(options: options) == String(repeating: "a", count: UsernameOptions.pinnedWordMaxLength))
    }

    @Test func wordWithOnlyPunctuationIsIgnored() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, pinnedWord: "!?-_ ")
        #expect(["alpha", "bravo", "charlie"].contains(generator.generate(options: options)))
    }

    @Test func fiveWordsStillMakeRoomForTheWord() {
        let options = UsernameOptions(wordCount: 5, separators: [.hyphen], wordCases: [.lower], includeNumber: false, pinnedWord: "cole")
        for _ in 0..<20 {
            let parts = generator.generate(options: options).split(separator: "-")
            #expect(parts.count == 5 && parts.first == "cole")
        }
    }

    @Test func alliterationFallsBackWhenTheWordStartsWithADigit() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      alliterate: true, pinnedWord: "42")
        for _ in 0..<20 {
            let parts = generator.generate(options: options).split(separator: "-")
            #expect(parts.count == 2 && parts[0] == "42")
        }
    }

    @Test func alliterationUsesTheWordsLetterEvenWhenOtherWordsAreRare() {
        // Only "charlie" starts with c, so every other slot has to be it.
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      alliterate: true, pinnedWord: "cole")
        for _ in 0..<20 {
            #expect(generator.generate(options: options) == "cole-charlie-charlie")
        }
    }

    @Test func pinnedWordIsRepeatableWithASeed() {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen, .period], pinnedWord: "cole", keptWord: "otter", keptPosition: .end)
        var a = SplitMix64(seed: 11)
        var b = SplitMix64(seed: 11)
        for _ in 0..<20 {
            #expect(generator.generate(options: options, using: &a) == generator.generate(options: options, using: &b))
        }
    }

    @Test func differentWordsGiveDifferentUsernames() {
        let a = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, pinnedWord: "cole")
        let b = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, pinnedWord: "otter")
        #expect(generator.generate(options: a) == "cole")
        #expect(generator.generate(options: b) == "otter")
    }

    // MARK: - Kept word

    @Test func keptWordAlone() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      keptWord: "otter", keptPosition: .end)
        for _ in 0..<20 {
            #expect(generator.generate(options: options).hasSuffix("-otter"))
        }
    }

    @Test func keptWordIsCleanedUp() {
        #expect(UsernameOptions(keptWord: "Ot-ter!").effectiveKeptWord == "otter")
        #expect(UsernameOptions(keptWord: "").effectiveKeptWord == nil)
        #expect(UsernameOptions(keptWord: "?!").effectiveKeptWord == nil)
    }

    @Test func bothAtTheStartKeepTheirOrder() {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      pinnedWord: "cole", pinnedPosition: .start, keptWord: "otter", keptPosition: .start)
        for _ in 0..<20 {
            #expect(generator.generate(options: options).hasPrefix("cole-otter-"))
        }
    }

    @Test func bothFillingEverySlotLeavesNoRandomWord() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      pinnedWord: "cole", pinnedPosition: .start, keptWord: "otter", keptPosition: .end)
        #expect(generator.generate(options: options) == "cole-otter")
    }

    @Test func bothAtTheSameEndWithTwoSlotsKeepOrder() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      pinnedWord: "cole", pinnedPosition: .end, keptWord: "otter", keptPosition: .end)
        #expect(generator.generate(options: options) == "cole-otter")
    }

    @Test func effectivePinsListOwnWordFirst() {
        let options = UsernameOptions(pinnedWord: "Cole", pinnedPosition: .end, keptWord: "otter", keptPosition: .start)
        #expect(options.effectivePins == [PinnedWord(word: "cole", position: .end), PinnedWord(word: "otter", position: .start)])
    }

    @Test func effectivePinsAreEmptyByDefault() {
        #expect(UsernameOptions().effectivePins.isEmpty)
        #expect(UsernameOptions(keptWord: "otter").effectivePins == [PinnedWord(word: "otter", position: .start)])
        #expect(UsernameOptions(pinnedWord: "cole").effectivePins == [PinnedWord(word: "cole", position: .start)])
    }

    @Test func keepingTheSameWordTwiceUsesOneSlot() {
        let options = UsernameOptions(pinnedWord: "Cole", keptWord: "cole!")
        #expect(options.effectivePins.count == 1)
    }

    @Test func twoPinsFixTwoSlotsInTheCombinationCount() {
        let g = UsernameGenerator(words: ["ant", "bee", "cat"])
        func count(words: Int) -> Double {
            g.combinationCount(options: UsernameOptions(wordCount: words, wordCases: [.lower], includeNumber: false,
                                                        pinnedWord: "zed", keptWord: "yak", keptPosition: .end))
        }
        #expect(count(words: 2) == 1)
        #expect(count(words: 3) == 3)
        #expect(count(words: 4) == 9)
    }

    @Test(arguments: UsernameOptions.wordCountRange)
    func detailedWordsAreTheRawWordsBeforeCapitalization(wordCount: Int) {
        let options = UsernameOptions(wordCount: wordCount, separators: [.hyphen], wordCases: [.upper], includeNumber: false)
        for item in generator.generateDetailedBatch(options: options, count: 10) {
            #expect(item.words.count == wordCount)
            #expect(item.words.allSatisfy { $0 == $0.lowercased() })
            #expect(item.text == item.words.joined(separator: "-").uppercased())
        }
    }

    @Test func detailedBatchHasTheRequestedCount() {
        #expect(generator.generateDetailedBatch(options: UsernameOptions(), count: 7).count == 7)
        #expect(generator.generateDetailedBatch(options: UsernameOptions(), count: 0).isEmpty)
        #expect(generator.generateBatch(options: UsernameOptions(), count: 0).isEmpty)
    }

    @Test func detailedAndPlainBatchesAgreeOnShape() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: true, digitCount: 3)
        for item in generator.generateDetailedBatch(options: options, count: 20) {
            #expect(item.text.hasPrefix(item.words.joined(separator: "-")))
            #expect(item.text.count == item.words.joined(separator: "-").count + 4)
        }
    }

    @Test func keptWordFromTheMiddleOfAResultGoesToTheEnd() {
        // The screen puts a first-slot word at the start and any other at the end.
        let kept = PinnedWord(word: "bravo", position: .end)
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], wordCases: [.lower], includeNumber: false)
            .applyingScreenRules(kept: kept)
        for _ in 0..<20 {
            #expect(generator.generate(options: options).hasSuffix("-bravo"))
        }
    }

    // MARK: - Screen rules

    @Test func oneWordForcesRandomPatternAndNoAlliteration() {
        let saved = UsernameOptions(wordCount: 1, pattern: .adjectiveNoun, alliterate: true)
        let applied = saved.applyingScreenRules(kept: nil)
        #expect(applied.pattern == .random)
        #expect(!applied.alliterate)
    }

    @Test func moreWordsKeepPatternAndAlliteration() {
        let saved = UsernameOptions(wordCount: 2, pattern: .adjectiveNoun, alliterate: true)
        let applied = saved.applyingScreenRules(kept: nil)
        #expect(applied.pattern == .adjectiveNoun)
        #expect(applied.alliterate)
    }

    @Test func madeUpWordsForceRandomPatternButKeepAlliteration() {
        let saved = UsernameOptions(wordCount: 3, pattern: .adjectiveNoun, alliterate: true, madeUpWords: true)
        let applied = saved.applyingScreenRules(kept: nil)
        #expect(applied.pattern == .random)
        #expect(applied.alliterate)
    }

    @Test func screenRulesDoNotChangeTheSavedChoices() {
        let saved = UsernameOptions(wordCount: 1, pattern: .adjectiveNoun, alliterate: true)
        _ = saved.applyingScreenRules(kept: PinnedWord(word: "otter", position: .end))
        #expect(saved.pattern == .adjectiveNoun)
        #expect(saved.alliterate)
        #expect(saved.keptWord.isEmpty)
    }

    /// Regression: keeping a word from a result used to replace the word typed into "Your word".
    @Test func keepingAWordNeverReplacesYourOwn() {
        let saved = UsernameOptions(pinnedWord: "cole", pinnedPosition: .start)
        let applied = saved.applyingScreenRules(kept: PinnedWord(word: "otter", position: .end))
        #expect(applied.pinnedWord == "cole")
        #expect(applied.pinnedPosition == .start)
        #expect(applied.keptWord == "otter")
        #expect(applied.keptPosition == .end)
        #expect(applied.effectivePins.map(\.word) == ["cole", "otter"])
    }

    @Test func clearingTheKeptWordLeavesYourOwn() {
        let saved = UsernameOptions(pinnedWord: "cole", keptWord: "otter", keptPosition: .end)
        let applied = saved.applyingScreenRules(kept: nil)
        #expect(applied.keptWord.isEmpty)
        #expect(applied.keptPosition == .start)
        #expect(applied.effectivePins.map(\.word) == ["cole"])
    }

    @Test func keepingAWordThenGeneratingKeepsBothWords() {
        let saved = UsernameOptions(wordCount: 3, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                    pinnedWord: "cole", pinnedPosition: .start)
        let applied = saved.applyingScreenRules(kept: PinnedWord(word: "otter", position: .end))
        for item in generator.generateDetailedBatch(options: applied, count: 20) {
            #expect(item.words.first == "cole" && item.words.last == "otter" && item.words.count == 3, "\(item.words)")
        }
    }

    @Test func keptWordWithMoreSlotsThanWordsStillWins() {
        let applied = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, pinnedWord: "cole")
            .applyingScreenRules(kept: PinnedWord(word: "otter", position: .start))
        #expect(generator.generate(options: applied) == "otter")
    }

    @Test func pinPositionHasLabelsAndIds() {
        #expect(PinPosition.allCases == [.start, .end])
        #expect(PinPosition.allCases.map(\.label) == ["Start", "End"])
        #expect(Set(PinPosition.allCases.map(\.id)).count == 2)
    }
}
