//
//  SettingsAndIntentTests.swift
//  UsernameGeneratorTests
//
//  Saved options, the Shortcuts action and the keyboard's quick options. These are the paths the widget,
//  the Safari extension, Siri and the keyboard use to reach the generator.
//

import AppIntents
import Testing
@testable import UsernameGenerator

struct SettingsAndIntentTests {
    private let generator = UsernameGenerator(words: ["alpha", "bravo", "charlie"])

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }

    // MARK: - Defaults

    @Test func defaultOptionsStayTheSame() {
        // The widget and Safari extension use these before anything is saved, so changing them is a visible change.
        let o = UsernameOptions()
        #expect(o.wordCount == 2)
        #expect(o.separators == [.none])
        #expect(o.wordCases == [.title])
        #expect(o.includeNumber)
        #expect(o.digitCount == 4)
        #expect(o.themes == [.any])
        #expect(!o.limitLength)
        #expect(o.maxLength == 15)
        #expect(!o.lettersAndDigitsOnly)
        #expect(!o.includeBlockedWords)
        #expect(o.twists == [.plain])
        #expect(o.pattern == .random)
        #expect(!o.alliterate)
        #expect(o.pinnedWord.isEmpty)
        #expect(o.pinnedPosition == .start)
        #expect(o.keptWord.isEmpty)
        #expect(o.keptPosition == .start)
        #expect(!o.madeUpWords)
    }

    // MARK: - Saved settings

    @Test func newSettingsKeysLoad() {
        withDefaults { d in
            d.set(WordTwist.encode([.leet, .noVowels]), forKey: "twists")
            d.set("Cole", forKey: "customWord")
            d.set("end", forKey: "customWordPosition")
            d.set(true, forKey: "madeUpWords")

            let expected = UsernameOptions(twists: [.leet, .noVowels], pinnedWord: "Cole", pinnedPosition: .end, madeUpWords: true)
            #expect(SharedSettings.loadOptions(from: d) == expected)
        }
    }

    @Test func invalidNewSettingsFallBackToDefaults() {
        withDefaults { d in
            d.set("bogus", forKey: "twists")
            d.set("sideways", forKey: "customWordPosition")
            d.set("yes", forKey: "madeUpWords")
            d.set("two", forKey: "wordCount")

            let loaded = SharedSettings.loadOptions(from: d)
            #expect(loaded.effectiveTwists == [.plain])
            #expect(loaded.pinnedPosition == .start)
            #expect(!loaded.madeUpWords)
            #expect(loaded.wordCount == UsernameOptions().wordCount)
        }
    }

    @Test func keptWordIsNeverLoadedFromSettings() {
        // A word kept from a result lives only in the open app, so nothing saved can set it.
        withDefaults { d in
            d.set("otter", forKey: "keptWord")
            d.set("end", forKey: "keptPosition")
            let loaded = SharedSettings.loadOptions(from: d)
            #expect(loaded.keptWord.isEmpty)
            #expect(loaded.keptPosition == .start)
        }
    }

    @Test func savedOptionsDriveTheGenerator() {
        withDefaults { d in
            d.set(2, forKey: "wordCount")
            d.set(WordSeparator.encode([.hyphen]), forKey: "separators")
            d.set(WordCase.encode([.lower]), forKey: "wordCases")
            d.set(false, forKey: "includeNumber")
            d.set(WordTwist.encode([.leet]), forKey: "twists")
            d.set("cole", forKey: "customWord")
            d.set("end", forKey: "customWordPosition")

            let g = UsernameGenerator(words: ["alpha"])
            #expect(g.generate(options: SharedSettings.loadOptions(from: d)) == "4lph4-c0l3")
        }
    }

    @Test func savedMadeUpChoiceDrivesTheGenerator() {
        withDefaults { d in
            d.set(1, forKey: "wordCount")
            d.set(false, forKey: "includeNumber")
            d.set(WordCase.encode([.lower]), forKey: "wordCases")
            d.set(true, forKey: "madeUpWords")

            // A few real words happen to fit the made-up grammar, so one name alone could pass by luck.
            let names = UsernameGenerator().generateBatch(options: SharedSettings.loadOptions(from: d), count: 10)
            #expect(names.allSatisfy(MadeUpWords.pool.contains), "\(names)")
        }
    }

    @Test func saveChoicesRoundTripThroughEveryEncoding() {
        withDefaults { d in
            let options = UsernameOptions(
                wordCount: 3, separators: [.hyphen, .tilde], wordCases: [.camel, .upper], includeNumber: true, digitCount: 5,
                themes: [.spooky, .gems], limitLength: true, maxLength: 22, lettersAndDigitsOnly: false,
                includeBlockedWords: true, twists: [.noVowels], pattern: .adjectiveNoun, alliterate: true,
                pinnedWord: "cole", pinnedPosition: .end, madeUpWords: false
            )
            d.set(options.wordCount, forKey: "wordCount")
            d.set(WordSeparator.encode(options.separators), forKey: "separators")
            d.set(WordCase.encode(options.wordCases), forKey: "wordCases")
            d.set(options.includeNumber, forKey: "includeNumber")
            d.set(options.digitCount, forKey: "digitCount")
            d.set(WordTheme.encode(options.themes), forKey: "themes")
            d.set(options.limitLength, forKey: "limitLength")
            d.set(options.maxLength, forKey: "maxLength")
            d.set(options.lettersAndDigitsOnly, forKey: "lettersAndDigitsOnly")
            d.set(options.includeBlockedWords, forKey: "includeBlockedWords")
            d.set(WordTwist.encode(options.twists), forKey: "twists")
            d.set(options.pattern.rawValue, forKey: "pattern")
            d.set(options.alliterate, forKey: "alliterate")
            d.set(options.pinnedWord, forKey: "customWord")
            d.set(options.pinnedPosition.rawValue, forKey: "customWordPosition")
            d.set(options.madeUpWords, forKey: "madeUpWords")
            #expect(SharedSettings.loadOptions(from: d) == options)
        }
    }

    // MARK: - Shortcuts action

    private func makeIntent(words: Int = 1, digits: Int = 0) -> GenerateUsernameIntent {
        let intent = GenerateUsernameIntent()
        intent.wordCount = words
        intent.themes = [.any]
        intent.separators = [.hyphen]
        intent.wordCases = [.lower]
        intent.digits = digits
        intent.maxLength = nil
        intent.lettersAndDigitsOnly = false
        intent.includeBlockedWords = false
        intent.pattern = .random
        intent.alliterate = false
        intent.twists = [.plain]
        intent.yourWord = nil
        intent.yourWordPosition = .start
        intent.madeUpWords = false
        return intent
    }

    @Test func intentPlacesYourWordAtTheStart() async throws {
        let intent = makeIntent(words: 2)
        intent.yourWord = "Cole"
        let value = try await intent.perform().value ?? ""
        #expect(value.hasPrefix("cole-"), "\(value)")
    }

    @Test func intentPlacesYourWordAtTheEnd() async throws {
        let intent = makeIntent(words: 2)
        intent.yourWord = "Cole"
        intent.yourWordPosition = .end
        let value = try await intent.perform().value ?? ""
        #expect(value.hasSuffix("-cole"), "\(value)")
    }

    @Test func intentWithoutYourWordUsesRealWords() async throws {
        let value = try await makeIntent().perform().value ?? ""
        #expect(WordList.eff.contains(value), "\(value)")
    }

    @Test func intentAppliesSpellings() async throws {
        let intent = makeIntent()
        intent.yourWord = "otter"
        intent.twists = [.leet]
        #expect(try await intent.perform().value == "0tt3r")
        intent.twists = [.noVowels]
        #expect(try await intent.perform().value == "ottr")
    }

    @Test func intentUsesMadeUpWords() async throws {
        let intent = makeIntent()
        intent.madeUpWords = true
        for _ in 0..<5 {
            let value = try await intent.perform().value ?? ""
            #expect(MadeUpWords.pool.contains(value), "\(value)")
        }
    }

    @Test func intentHonorsLengthLimitWithYourWord() async throws {
        let intent = makeIntent(words: 3, digits: 4)
        intent.maxLength = 10
        intent.yourWord = "averyverylongname"
        let value = try await intent.perform().value ?? ""
        #expect(value.count <= 10, "\(value)")
    }

    @Test func intentSpokenResultMatchesReturnedValue() async throws {
        let intent = makeIntent(words: 2, digits: 3)
        let result = try await intent.perform()
        let value = result.value ?? ""
        #expect(!value.isEmpty)
        #expect(value.split(separator: "-").count == 3)
    }

    // MARK: - Shortcuts names

    private func namesEveryCase<T: AppEnum>(_ type: T.Type) -> Bool {
        T.allCases.allSatisfy { T.caseDisplayRepresentations[$0] != nil }
    }

    @Test func everyShortcutsChoiceHasADisplayName() {
        // A new case without a name would show up blank in Shortcuts.
        #expect(namesEveryCase(WordTheme.self))
        #expect(namesEveryCase(WordTwist.self))
        #expect(namesEveryCase(PinPosition.self))
        #expect(namesEveryCase(WordCase.self))
        #expect(namesEveryCase(WordPattern.self))
        #expect(namesEveryCase(SeparatorChoice.self))
    }

    @Test func separatorChoicesMapToTheirSeparators() {
        #expect(SeparatorChoice.allCases.count == WordSeparator.allCases.count)
        #expect(Set(SeparatorChoice.allCases.map(\.separator)) == Set(WordSeparator.allCases))
    }

    // MARK: - Keyboard quick options

    @Test func keyboardDefaultsMatchTheApp() {
        #expect(UsernameOptions.keyboard(wordCount: 2, includeNumber: true, maxLength: 0) == UsernameOptions())
    }

    @Test func keyboardZeroMeansNoLimit() {
        let options = UsernameOptions.keyboard(wordCount: 2, includeNumber: true, maxLength: 0)
        #expect(!options.limitLength)
    }

    @Test(arguments: UsernameOptions.keyboardMaxLengths.filter { $0 > 0 })
    func keyboardLengthChoicesSetTheLimit(length: Int) {
        let options = UsernameOptions.keyboard(wordCount: 2, includeNumber: true, maxLength: length)
        #expect(options.limitLength)
        #expect(options.maxLength == length)
        for _ in 0..<50 {
            #expect(UsernameGenerator().generate(options: options).count <= length)
        }
    }

    @Test(arguments: UsernameOptions.keyboardWordCounts)
    func keyboardWordCountChoicesGiveThatManyWords(count: Int) {
        let options = UsernameOptions.keyboard(wordCount: count, includeNumber: false, maxLength: 0)
        for item in generator.generateDetailedBatch(options: options, count: 10) {
            #expect(item.words.count == count)
        }
    }

    @Test func keyboardDigitsToggle() {
        let withDigits = UsernameOptions.keyboard(wordCount: 1, includeNumber: true, maxLength: 0)
        let without = UsernameOptions.keyboard(wordCount: 1, includeNumber: false, maxLength: 0)
        for _ in 0..<20 {
            let a = generator.generate(options: withDigits)
            #expect(a.suffix(4).allSatisfy { $0.isNumber }, "\(a)")
            #expect(!generator.generate(options: without).contains { $0.isNumber })
        }
    }

    @Test func keyboardChoiceListsAreSensible() {
        #expect(UsernameOptions.keyboardMaxLengths.first == 0)
        #expect(UsernameOptions.keyboardMaxLengths == UsernameOptions.keyboardMaxLengths.sorted())
        #expect(UsernameOptions.keyboardWordCounts.allSatisfy(UsernameOptions.wordCountRange.contains))
        #expect(UsernameOptions.keyboardMaxLengths.dropFirst().allSatisfy(UsernameOptions.maxLengthRange.contains))
    }
}
