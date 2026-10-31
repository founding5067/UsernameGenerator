//
//  WordSourceTests.swift
//  UsernameGeneratorTests
//
//  Where the words come from: the themes, the spelling twists and the made-up words.
//

import Testing
@testable import UsernameGenerator

struct WordSourceTests {
    private let generator = UsernameGenerator(words: ["alpha", "bravo", "charlie"])

    // MARK: - Themes

    @Test(arguments: WordTheme.allCases.filter { $0 != .any })
    func themeHasEnoughUniqueWords(theme: WordTheme) {
        let words = theme.words(includingBlocked: true)
        #expect(words.count >= 20, "\(theme) has only \(words.count) words")
        #expect(Set(words).count == words.count, "\(theme) has repeated words")
    }

    @Test(arguments: WordTheme.allCases.filter { $0 != .any })
    func themeWordsAreLowercaseLetters(theme: WordTheme) {
        let bad = theme.words(includingBlocked: true).filter { !$0.allSatisfy { $0.isASCII && $0.isLowercase && $0.isLetter } }
        #expect(bad.isEmpty, "\(bad)")
    }

    @Test func themeLabelsAndNamesAreUnique() {
        #expect(Set(WordTheme.allCases.map(\.label)).count == WordTheme.allCases.count)
        #expect(Set(WordTheme.allCases.map(\.rawValue)).count == WordTheme.allCases.count)
    }

    @Test(arguments: [WordTheme.spooky, .tech, .mythology, .gems])
    func newThemesGenerateOnlyTheirOwnWords(theme: WordTheme) {
        let own = Set(theme.words)
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, themes: [theme])
        for _ in 0..<100 {
            let name = UsernameGenerator().generate(options: options)
            #expect(own.contains(name), "\(name) is not a \(theme) word")
        }
    }

    @Test func newThemesCombineWithEachOther() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, themes: [.spooky, .gems])
        let allowed = Set(WordTheme.spooky.words).union(WordTheme.gems.words)
        let seen = Set((0..<400).map { _ in UsernameGenerator().generate(options: options) })
        #expect(seen.isSubset(of: allowed))
        #expect(!seen.isDisjoint(with: WordTheme.spooky.words) && !seen.isDisjoint(with: WordTheme.gems.words))
    }

    @Test(arguments: WordTheme.allCases)
    func themeNounsAreNeverEmpty(theme: WordTheme) {
        #expect(!theme.nouns(includingBlocked: false).isEmpty)
    }

    // MARK: - Spelling twists

    @Test func leetKeepsCaseAndDigitsAndLeavesOtherLettersAlone() {
        #expect(WordTwist.leet.apply(to: "OTTER") == "0TT3R")
        #expect(WordTwist.leet.apply(to: "abc123") == "4bc123")
        #expect(WordTwist.leet.apply(to: "rhythm") == "rhythm")
        #expect(WordTwist.leet.apply(to: "") == "")
    }

    @Test func noVowelsKeepsTheFirstLetter() {
        #expect(WordTwist.noVowels.apply(to: "OTTER") == "OTTR")
        #expect(WordTwist.noVowels.apply(to: "Quiet") == "Qt")
        #expect(WordTwist.noVowels.apply(to: "a") == "a")
        #expect(WordTwist.noVowels.apply(to: "aeiou") == "a")
        #expect(WordTwist.noVowels.apply(to: "eye") == "ey")
        #expect(WordTwist.noVowels.apply(to: "") == "")
    }

    @Test(arguments: WordTwist.allCases)
    func twistsAreIdempotent(twist: WordTwist) {
        for word in ["otter", "Quiet", "Aardvark", "x", "rhythm", "c0l3"] {
            let once = twist.apply(to: word)
            #expect(twist.apply(to: once) == once, "\(twist) on \(word)")
        }
    }

    @Test(arguments: WordTwist.allCases)
    func twistedPoolsHaveNoEmptyWordsOrRepeats(twist: WordTwist) {
        let pool = twist.apply(to: WordList.eff)
        #expect(!pool.contains(""))
        #expect(Set(pool).count == pool.count)
        #expect(!pool.isEmpty)
    }

    @Test func noVowelsKeepsEveryWordsFirstLetter() {
        for word in WordList.eff {
            #expect(WordTwist.noVowels.apply(to: word).first == word.first, "\(word)")
        }
    }

    @Test func twistLabelsAreUnique() {
        #expect(Set(WordTwist.allCases.map(\.label)).count == WordTwist.allCases.count)
    }

    @Test func twistsWorkWithLettersAndNumbersOnly() {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], includeNumber: true, lettersAndDigitsOnly: true,
                                      twists: [.leet, .noVowels])
        for name in UsernameGenerator().generateBatch(options: options, count: 100) {
            #expect(name.allSatisfy { $0.isLetter || $0.isNumber }, "\(name)")
        }
    }

    @Test func leetWorksWithAlternatingCase() {
        let g = UsernameGenerator(words: ["otter"])
        let options = UsernameOptions(wordCount: 1, wordCases: [.alternating], includeNumber: false, twists: [.leet])
        // Only letters count towards the pattern, so the digits don't shift it.
        #expect(g.generate(options: options) == "0tT3r")
    }

    @Test func twistsWorkWithAdjectiveAndNoun() {
        let g = UsernameGenerator(adjectives: ["brave"], nouns: ["badger"])
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen], wordCases: [.lower], includeNumber: false,
                                      twists: [.noVowels], pattern: .adjectiveNoun)
        #expect(g.generate(options: options) == "brv-bdgr")
    }

    @Test func twistsWorkWithCamelCase() {
        let g = UsernameGenerator(words: ["otter"])
        let options = UsernameOptions(wordCount: 2, wordCases: [.camel], includeNumber: false, twists: [.leet])
        // Digits have no case, so the second word's capital letter has nothing to change.
        #expect(g.generate(options: options) == "0tt3r0tt3r")
    }

    @Test func twistsAreRepeatableWithASeed() {
        let options = UsernameOptions(wordCount: 2, separators: [.hyphen, .period],
                                      wordCases: [.lower, .title], twists: [.plain, .leet, .noVowels])
        var a = SplitMix64(seed: 5)
        var b = SplitMix64(seed: 5)
        for _ in 0..<20 {
            #expect(UsernameGenerator().generate(options: options, using: &a) == UsernameGenerator().generate(options: options, using: &b))
        }
    }

    @Test func everySelectedTwistGetsUsed() {
        let g = UsernameGenerator(words: ["otter"])
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, twists: [.plain, .leet, .noVowels])
        let seen = Set((0..<200).map { _ in g.generate(options: options) })
        #expect(seen == ["otter", "0tt3r", "ottr"])
    }

    @Test func twistCombinationsMultiplyWithSeparators() {
        let g = UsernameGenerator(words: ["ant", "bee"])
        func count(separators: Set<WordSeparator>, twists: Set<WordTwist>) -> Double {
            g.combinationCount(options: UsernameOptions(wordCount: 2, separators: separators, wordCases: [.lower],
                                                        includeNumber: false, twists: twists))
        }
        let base = count(separators: [.none], twists: [.plain])
        #expect(base == 4)
        #expect(count(separators: [.none, .hyphen], twists: [.plain]) == base * 2)
        // Under leet, "ant" and "bee" become two different words ("4nt", "b33"), which adds another 4.
        #expect(count(separators: [.none], twists: [.plain, .leet]) == base * 2)
    }

    @Test func lengthLimitsAreCheckedAgainstTheRespelledWords() {
        // "quickly" is 7 letters, which is over a limit of 6, but only 5 without vowels ("qckly").
        let g = UsernameGenerator(words: ["quickly"])
        func options(_ twists: Set<WordTwist>) -> UsernameOptions {
            UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, limitLength: true, maxLength: 6, twists: twists)
        }
        #expect(g.generate(options: options([.noVowels])) == "qckly")
        // Nothing fits when it isn't respelled, so the shortest word is used anyway.
        #expect(g.generate(options: options([.plain])) == "quickly")
    }

    // MARK: - Made-up words

    private var syllables: Set<String> {
        Set(MadeUpWords.onsets.flatMap { onset in MadeUpWords.vowels.flatMap { vowel in MadeUpWords.codas.map { onset + vowel + $0 } } })
    }

    @Test func madeUpWordsAreTwoSyllables() {
        let syllables = syllables
        let pool = MadeUpWords.pool
        for word in stride(from: 0, to: pool.count, by: 25).map({ pool[$0] }) {
            let splits = (1..<word.count).contains { index in
                syllables.contains(String(word.prefix(index))) && syllables.contains(String(word.dropFirst(index)))
            }
            #expect(splits, "\(word) is not two syllables")
        }
    }

    @Test func madeUpPoolIsDeterministic() {
        #expect(MadeUpWords.build() == MadeUpWords.pool)
    }

    @Test func madeUpPoolNeverHasMoreWordsThanSyllablePairs() {
        #expect(MadeUpWords.pool.count <= syllables.count * syllables.count)
        // Only a small share is filtered out, so the list stays nearly full.
        #expect(MadeUpWords.pool.count > syllables.count * syllables.count * 9 / 10)
    }

    @Test func blockedFragmentsAreLowercaseAndLongEnough() {
        for fragment in MadeUpWords.blockedFragments {
            #expect(fragment.count >= 3)
            #expect(fragment == fragment.lowercased(), "\(fragment)")
        }
    }

    @Test func blockedMadeUpFileIsClean() {
        let lines = WordList.load(resource: "blocked_madeup")
        #expect(!lines.isEmpty)
        #expect(Set(lines).count == lines.count, "Repeated fragments")
        for line in lines {
            #expect(line.count >= 3, "\(line) is too short to filter on")
            #expect(line.allSatisfy { $0.isASCII && $0.isLowercase && $0.isLetter }, "\(line)")
        }
    }

    @Test func fragmentsAreCaughtAnywhereInAWord() {
        let blocked: Set<String> = ["xyz"]
        #expect(MadeUpWords.containsBlockedFragment("xyzab", blocked: blocked, longest: 3))
        #expect(MadeUpWords.containsBlockedFragment("abxyzcd", blocked: blocked, longest: 3))
        #expect(MadeUpWords.containsBlockedFragment("abxyz", blocked: blocked, longest: 3))
        #expect(MadeUpWords.containsBlockedFragment("xyz", blocked: blocked, longest: 3))
        #expect(!MadeUpWords.containsBlockedFragment("abxy", blocked: blocked, longest: 3))
        #expect(!MadeUpWords.containsBlockedFragment("xy", blocked: blocked, longest: 3))
        #expect(!MadeUpWords.containsBlockedFragment("", blocked: blocked, longest: 3))
    }

    @Test func longerFragmentsAreCaughtToo() {
        let blocked: Set<String> = ["abcde"]
        #expect(MadeUpWords.containsBlockedFragment("zzabcdezz", blocked: blocked, longest: 5))
        #expect(!MadeUpWords.containsBlockedFragment("zzabcdzz", blocked: blocked, longest: 5))
    }

    @Test func blockedWordsNeverAppearInsideMadeUpWords() {
        let fragments = MadeUpWords.blockedFragments
        let pool = MadeUpWords.pool
        for word in stride(from: 3, to: pool.count, by: 37).map({ pool[$0] }) {
            #expect(fragments.first { word.contains($0) } == nil, "\(word)")
        }
    }

    @Test func madeUpWordsWorkWithLettersAndNumbersOnly() {
        let options = UsernameOptions(wordCount: 3, separators: [.hyphen], lettersAndDigitsOnly: true, madeUpWords: true)
        for name in UsernameGenerator().generateBatch(options: options, count: 20) {
            #expect(name.allSatisfy { $0.isLetter || $0.isNumber }, "\(name)")
        }
    }

    @Test func madeUpWordsWorkWithNoVowels() {
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, twists: [.noVowels], madeUpWords: true)
        for name in UsernameGenerator().generateBatch(options: options, count: 30) {
            #expect(!name.dropFirst().contains { "aeiou".contains($0) }, "\(name)")
        }
    }

    @Test func madeUpWordCountSquaresWithTwoWords() {
        let one = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, madeUpWords: true)
        let two = UsernameOptions(wordCount: 2, wordCases: [.lower], includeNumber: false, madeUpWords: true)
        let size = Double(MadeUpWords.pool.count)
        #expect(UsernameGenerator().combinationCount(options: one) == size)
        #expect(UsernameGenerator().combinationCount(options: two) == size * size)
    }

    @Test func madeUpWordsFitTheSmallestLengthLimit() {
        let options = UsernameOptions(wordCount: 1, includeNumber: false, limitLength: true,
                                      maxLength: UsernameOptions.maxLengthRange.lowerBound, madeUpWords: true)
        for name in UsernameGenerator().generateBatch(options: options, count: 100) {
            #expect(name.count <= UsernameOptions.maxLengthRange.lowerBound, "\(name)")
        }
    }

    @Test func madeUpWordsRespectCapitalization() {
        let options = UsernameOptions(wordCount: 2, wordCases: [.title], includeNumber: false, madeUpWords: true)
        for name in UsernameGenerator().generateBatch(options: options, count: 20) {
            #expect(name.first?.isUppercase == true, "\(name)")
            #expect(name.filter { $0.isUppercase }.count == 2, "\(name)")
        }
    }

    @Test func madeUpWordsIgnoreTheWordsOverrideUsedByTests() {
        let g = UsernameGenerator(words: ["alpha"])
        let options = UsernameOptions(wordCount: 1, wordCases: [.lower], includeNumber: false, madeUpWords: true)
        let seen = Set((0..<50).map { _ in g.generate(options: options) })
        #expect(!seen.contains("alpha"))
    }
}
