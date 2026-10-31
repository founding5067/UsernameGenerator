//
//  PropertySweepTests.swift
//  UsernameGeneratorTests
//
//  Draws hundreds of random option combinations and checks the rules that must hold for every one of them.
//  The draws are seeded, so a failure names its seed and can be repeated exactly.
//

import Testing
@testable import UsernameGenerator

struct PropertySweepTests {
    private static let pinnedChoices = ["", "", "cole", "42", "a-b", "supercalifragilistic"]
    private static let keptChoices = ["", "", "otter"]

    private func subset<T: CaseIterable & Hashable>(_ type: T.Type, using rng: inout SplitMix64) -> Set<T> {
        var chosen = Set<T>()
        for value in T.allCases where Bool.random(using: &rng) { chosen.insert(value) }
        return chosen
    }

    /// Any mix of options, including odd ones: no separators picked, a word that is only digits, one word with alliteration on.
    private func randomOptions(using rng: inout SplitMix64) -> UsernameOptions {
        var o = UsernameOptions()
        o.wordCount = Int.random(in: UsernameOptions.wordCountRange, using: &rng)
        o.separators = subset(WordSeparator.self, using: &rng)
        o.wordCases = subset(WordCase.self, using: &rng)
        o.includeNumber = Bool.random(using: &rng)
        o.digitCount = Int.random(in: UsernameOptions.digitCountRange, using: &rng)
        o.themes = subset(WordTheme.self, using: &rng)
        o.limitLength = Bool.random(using: &rng)
        o.maxLength = Int.random(in: UsernameOptions.maxLengthRange, using: &rng)
        o.lettersAndDigitsOnly = Bool.random(using: &rng)
        o.includeBlockedWords = Bool.random(using: &rng)
        o.twists = subset(WordTwist.self, using: &rng)
        o.pattern = WordPattern.allCases.randomElement(using: &rng)!
        o.alliterate = Bool.random(using: &rng)
        o.pinnedWord = Self.pinnedChoices.randomElement(using: &rng)!
        o.pinnedPosition = PinPosition.allCases.randomElement(using: &rng)!
        o.keptWord = Self.keptChoices.randomElement(using: &rng)!
        o.keptPosition = PinPosition.allCases.randomElement(using: &rng)!
        // The made-up list is large, so it only comes up now and then to keep the sweep quick.
        o.madeUpWords = Int.random(in: 0..<20, using: &rng) == 0
        return o
    }

    @Test func everyRandomOptionSetGivesValidUsernames() {
        for seed in 0..<400 {
            var rng = SplitMix64(seed: UInt64(seed))
            let o = randomOptions(using: &rng)
            let context = Comment(rawValue: "seed \(seed): \(o)")

            for _ in 0..<(o.madeUpWords ? 1 : 3) {
                let name = UsernameGenerator().generate(options: o, using: &rng)

                #expect(!name.isEmpty, context)
                if o.limitLength {
                    #expect(name.count <= o.maxLength, context)
                }
                if o.lettersAndDigitsOnly {
                    #expect(name.allSatisfy { $0.isLetter || $0.isNumber }, context)
                }
                let allowed = Set(o.effectiveSeparators.flatMap { Array($0.rawValue) })
                let punctuation = name.filter { !($0.isLetter || $0.isNumber) }
                #expect(punctuation.allSatisfy(allowed.contains), context)

                // Every pinned word shows up, as long as it can't be dropped or shortened to make room.
                if !o.limitLength, o.effectivePins.count <= o.wordCount {
                    for pin in o.effectivePins {
                        let spellings = o.effectiveTwists.map { $0.apply(to: pin.word) }
                        #expect(spellings.contains { name.lowercased().contains($0) }, context)
                    }
                }

                // Nothing else puts a digit in a username when numbers are off and nothing was respelled.
                let canHaveDigits = o.includeNumber || o.effectiveTwists != [.plain]
                    || o.effectivePins.contains { $0.word.contains(where: \.isNumber) }
                if !canHaveDigits {
                    #expect(!name.contains { $0.isNumber }, context)
                }
            }

            // Counting made-up options plans every separator and spelling over the whole list, which is slow.
            if !o.madeUpWords {
                #expect(UsernameGenerator().combinationCount(options: o) >= 1, context)
            }
        }
    }

    @Test func everyRandomBatchHasTheRequestedCount() {
        for seed in 1000..<1100 {
            var rng = SplitMix64(seed: UInt64(seed))
            var o = randomOptions(using: &rng)
            o.madeUpWords = false
            let count = Int.random(in: 0...8, using: &rng)
            let context = Comment(rawValue: "seed \(seed)")
            #expect(UsernameGenerator().generateBatch(options: o, count: count).count == count, context)
            #expect(UsernameGenerator().generateDetailedBatch(options: o, count: count).count == count, context)
        }
    }

    @Test func combinationCountNeverShrinksWhenAWordIsAdded() {
        for seed in 2000..<2100 {
            var rng = SplitMix64(seed: UInt64(seed))
            var o = randomOptions(using: &rng)
            o.madeUpWords = false
            o.limitLength = false
            o.pinnedWord = ""
            o.keptWord = ""
            o.alliterate = false
            o.wordCount = Int.random(in: 1...4, using: &rng)
            let fewer = UsernameGenerator().combinationCount(options: o)
            o.wordCount += 1
            let more = UsernameGenerator().combinationCount(options: o)
            #expect(more >= fewer, Comment(rawValue: "seed \(seed): \(fewer) then \(more)"))
        }
    }

    @Test func sameSeedAlwaysGivesTheSameUsernames() {
        for seed in 3000..<3050 {
            var setup = SplitMix64(seed: UInt64(seed))
            var o = randomOptions(using: &setup)
            o.madeUpWords = false
            var a = SplitMix64(seed: 99)
            var b = SplitMix64(seed: 99)
            #expect(UsernameGenerator().generate(options: o, using: &a) == UsernameGenerator().generate(options: o, using: &b),
                    Comment(rawValue: "seed \(seed)"))
        }
    }

    @Test func screenRulesNeverChangeWhatIsPinned() {
        for seed in 4000..<4100 {
            var rng = SplitMix64(seed: UInt64(seed))
            let o = randomOptions(using: &rng)
            let kept = o.effectiveKeptWord.map { PinnedWord(word: $0, position: o.keptPosition) }
            let applied = o.applyingScreenRules(kept: kept)
            let context = Comment(rawValue: "seed \(seed)")
            #expect(applied.pinnedWord == o.pinnedWord, context)
            #expect(applied.pinnedPosition == o.pinnedPosition, context)
            #expect(applied.effectiveKeptWord == o.effectiveKeptWord, context)
            #expect(applied.wordCount == o.wordCount, context)
            #expect(applied.madeUpWords == o.madeUpWords, context)
        }
    }
}
