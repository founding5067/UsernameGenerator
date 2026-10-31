//
//  ContentView.swift
//  UsernameGenerator
//
//  Created by Cole Braswell on 10/30/26.
//

import SwiftUI
import WidgetKit
#if os(macOS)
import SafariServices
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    // Only the option choices are remembered. Generated usernames are never stored.
    @AppStorage("wordCount", store: SharedSettings.defaults) private var wordCount = UsernameOptions().wordCount
    @AppStorage("separators", store: SharedSettings.defaults) private var separatorsRaw = WordSeparator.encode(UsernameOptions().separators)
    @AppStorage("wordCases", store: SharedSettings.defaults) private var wordCasesRaw = WordCase.encode(UsernameOptions().wordCases)
    @AppStorage("includeNumber", store: SharedSettings.defaults) private var includeNumber = UsernameOptions().includeNumber
    @AppStorage("digitCount", store: SharedSettings.defaults) private var digitCount = UsernameOptions().digitCount
    @AppStorage("themes", store: SharedSettings.defaults) private var themesRaw = WordTheme.encode(UsernameOptions().themes)
    @AppStorage("limitLength", store: SharedSettings.defaults) private var limitLength = UsernameOptions().limitLength
    @AppStorage("maxLength", store: SharedSettings.defaults) private var maxLength = UsernameOptions().maxLength
    @AppStorage("lettersAndDigitsOnly", store: SharedSettings.defaults) private var lettersAndDigitsOnly = UsernameOptions().lettersAndDigitsOnly
    @AppStorage("includeBlockedWords", store: SharedSettings.defaults) private var includeBlockedWords = UsernameOptions().includeBlockedWords

    @AppStorage("twists", store: SharedSettings.defaults) private var twistsRaw = WordTwist.encode(UsernameOptions().twists)
    @AppStorage("pattern", store: SharedSettings.defaults) private var pattern = UsernameOptions().pattern
    @AppStorage("alliterate", store: SharedSettings.defaults) private var alliterate = UsernameOptions().alliterate

    // Your own word is an option, so it is remembered like the others.
    @AppStorage("customWord", store: SharedSettings.defaults) private var customWord = UsernameOptions().pinnedWord
    @AppStorage("customWordPosition", store: SharedSettings.defaults) private var customWordPosition = UsernameOptions().pinnedPosition

    @AppStorage("madeUpWords", store: SharedSettings.defaults) private var madeUpWords = UsernameOptions().madeUpWords

    @State private var usernames: [GeneratedUsername] = []
    /// A word kept from a result while the rest are rerolled. Lives only until you clear it or close the app.
    @State private var keptWord: KeptWord?
    @State private var copied: String?
    /// Worked out when the options change, not on every redraw.
    @State private var combinations = 0.0
    @Environment(\.scenePhase) private var scenePhase

    private static let batchSize = 5
    private let generator = UsernameGenerator()

    private var options: UsernameOptions {
        UsernameOptions(
            wordCount: wordCount,
            separators: separators,
            wordCases: wordCases,
            includeNumber: includeNumber,
            digitCount: digitCount,
            themes: themes,
            limitLength: limitLength,
            maxLength: maxLength,
            lettersAndDigitsOnly: lettersAndDigitsOnly,
            includeBlockedWords: includeBlockedWords,
            twists: twists,
            // With one word there is nothing to pattern or alliterate. The saved choices are kept.
            pattern: wordCount > 1 && !madeUpWords ? pattern : .random,
            alliterate: wordCount > 1 && alliterate,
            pinnedWord: customWord,
            pinnedPosition: customWordPosition,
            keptWord: keptWord?.word ?? "",
            keptPosition: keptWord?.position ?? .start,
            madeUpWords: madeUpWords
        )
    }

    private var separators: Set<WordSeparator> {
        let separators = WordSeparator.decode(separatorsRaw)
        return separators.isEmpty ? [.none] : separators
    }

    private var wordCases: Set<WordCase> {
        let cases = WordCase.decode(wordCasesRaw)
        return cases.isEmpty ? [.title] : cases
    }

    private var twists: Set<WordTwist> {
        let twists = WordTwist.decode(twistsRaw)
        return twists.isEmpty ? [.plain] : twists
    }

    private var themes: Set<WordTheme> {
        let themes = WordTheme.decode(themesRaw)
        return themes.isEmpty ? [.any] : themes
    }

    init() {
        SharedSettings.migrateLegacyKeys()
    }

    private var strengthText: String {
        let count = combinations
        let formatted = count >= 1e15
            ? "10^\(Int(log10(count)))"
            : count.formatted(.number.notation(.compactName).precision(.significantDigits(2)))
        return "About \(formatted) possible usernames"
    }

    private var strengthColor: Color {
        combinations < 1e6 ? .orange : .green
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let keptWord {
                        HStack {
                            Label("Keeping “\(keptWord.word)”", systemImage: "pin.fill")
                            Spacer()
                            Button {
                                self.keptWord = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Stop keeping “\(keptWord.word)”")
                            .accessibilityIdentifier("clearKept")
                        }
                        .accessibilityIdentifier("keptWord")
                    }

                    ForEach(usernames, id: \.text) { generated in
                        let name = generated.text
                        Button {
                            copy(name)
                        } label: {
                            HStack {
                                Text(name)
                                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                                    // One line that shrinks to fit, so wrapping never adds a misleading hyphen.
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                                Spacer()
                                Image(systemName: copied == name ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundStyle(copied == name ? Color.green : Color.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                        .accessibilityValue(copied == name ? "Copied" : "")
                        .accessibilityHint("Copies to the clipboard")
                        .accessibilityIdentifier("username")
                        .contextMenu {
                            // One word has nothing left to reroll.
                            if generated.words.count > 1 {
                                ForEach(Array(generated.words.enumerated()), id: \.offset) { index, word in
                                    Button("Keep “\(word)”") {
                                        keptWord = KeptWord(word: word, position: index == 0 ? .start : .end)
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        generate(animated: true)
                    } label: {
                        Text("Generate")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityIdentifier("generate")
                } header: {
                    Text("Tap a username to copy it")
                } footer: {
                    Label(strengthText, systemImage: "gauge.with.dots.needle.50percent")
                        .foregroundStyle(strengthColor)
                        .accessibilityIdentifier("strength")
                }

                Section {
                    NumberStepper(title: "Number of words", value: $wordCount,
                                  range: UsernameOptions.wordCountRange, id: "wordCount")
                    Picker("Vocabulary", selection: $madeUpWords) {
                        Text("Real words").tag(false)
                        Text("Made-up").tag(true)
                    }
                    .accessibilityIdentifier("madeUp")
                    MultiSelectMenu(
                        id: "themeMenu", title: "Theme", plural: "themes", label: \.label,
                        selection: Binding { themes } set: { themesRaw = WordTheme.encode($0) }
                    )
                    .disabled(madeUpWords)
                    // Like Alliterate, a pattern needs at least two words. The saved choice is kept.
                    // A disabled Picker can still open its menu, so show plain text instead.
                    if wordCount > 1 && !madeUpWords {
                        Picker("Pattern", selection: $pattern) {
                            ForEach(WordPattern.allCases) { Text($0.label).tag($0) }
                        }
                        .accessibilityIdentifier("pattern")
                    } else {
                        LabeledContent("Pattern", value: WordPattern.random.label)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("patternFixed")
                    }
                    // One word has nothing to match. The saved choice is kept for when there are more.
                    Toggle("Alliterate", isOn: wordCount > 1 ? $alliterate : .constant(false))
                        .disabled(wordCount == 1)
                        .accessibilityIdentifier("alliterate")
                    MultiSelectMenu(
                        id: "separatorMenu", title: "Separator", plural: "separators", label: \.label,
                        selection: Binding { separators } set: { separatorsRaw = WordSeparator.encode($0) }
                    )
                    .disabled(lettersAndDigitsOnly)
                    MultiSelectMenu(
                        id: "capitalizationMenu", title: "Capitalization", plural: "styles", label: \.label,
                        selection: Binding { wordCases } set: { wordCasesRaw = WordCase.encode($0) }
                    )
                    TextField("Your word", text: $customWord)
                        .accessibilityIdentifier("customWord")
                        #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        #endif
                        .autocorrectionDisabled()
                    if !customWord.isEmpty {
                        Picker("Your word goes at the", selection: $customWordPosition) {
                            ForEach(PinPosition.allCases) { Text($0.label).tag($0) }
                        }
                        .accessibilityIdentifier("customWordPosition")
                    }
                    MultiSelectMenu(
                        id: "twistMenu", title: "Spelling", plural: "spellings", label: \.label,
                        selection: Binding { twists } set: { twistsRaw = WordTwist.encode($0) }
                    )
                } header: {
                    Text("Words")
                } footer: {
                    Text("Your word takes one of the word slots and can be letters and numbers. Press and hold (or right-click) a username to keep one of its words and reroll the rest.")
                }

                Section("Numbers") {
                    Toggle("Add numbers", isOn: $includeNumber)
                        .accessibilityIdentifier("addNumbers")
                    if includeNumber {
                        NumberStepper(title: "Digits", value: $digitCount,
                                      range: UsernameOptions.digitCountRange, id: "digitCount")
                    }
                }

                Section {
                    Toggle("Limit length", isOn: $limitLength)
                        .accessibilityIdentifier("limitLength")
                    if limitLength {
                        NumberStepper(title: "Maximum characters", value: $maxLength,
                                      range: UsernameOptions.maxLengthRange, id: "maxLength")
                    }
                    Toggle("Letters and numbers only", isOn: $lettersAndDigitsOnly)
                        .accessibilityIdentifier("lettersOnly")
                } header: {
                    Text("Site rules")
                } footer: {
                    Text("Some sites cap username length or reject punctuation. If a limit is tight, digits and then words are dropped so every result fits.")
                }

                Section {
                    Toggle("Include filtered words", isOn: $includeBlockedWords)
                } header: {
                    Text("Word filter")
                } footer: {
                    Text("Some words are left out by default because they're crude, violent or otherwise unsuitable. Turn this on to allow them.")
                }

                Section {
                    #if os(macOS)
                    Button("Turn On in Safari…") {
                        SFSafariApplication.showPreferencesForExtension(
                            withIdentifier: "com.colebraswell.UsernameGenerator.UsernameSafariExtension")
                    }
                    #else
                    Text("Turn it on in Settings → Apps → Safari → Extensions.")
                    #endif
                } header: {
                    Text("Safari")
                } footer: {
                    Text("The Safari extension shows usernames from here and fills the field you're typing in. It can only see a page after you click it.")
                }

                Section {
                    Label("Runs entirely on this device. No accounts, no ads, no tracking, no network.",
                          systemImage: "lock.shield")
                    Link(destination: URL(string: "https://tangled.org/colebraswell.com/UsernameGenerator")!) {
                        Label("View the Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Text("Words from the EFF Large Wordlist by the Electronic Frontier Foundation, used under CC BY 4.0, with some words filtered out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                } footer: {
                    Text("The whole app is open source, so you can check these privacy claims yourself.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Username Generator")
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 640)
        #endif
        .onAppear {
            combinations = generator.combinationCount(options: options)
            generate()
        }
        .onChange(of: wordCount) {
            // One word has nothing left to reroll around.
            if wordCount == 1 { keptWord = nil }
        }
        .onChange(of: options) {
            combinations = generator.combinationCount(options: options)
            generate()
        }
        // The widget isn't visible while the app is open, so refresh it once when leaving.
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                WidgetCenter.shared.reloadTimelines(ofKind: SharedSettings.widgetKind)
            }
        }
        .task(priority: .utility) {
            // Load the theme lists now instead of on the first tap that needs them.
            await Task.detached {
                for theme in WordTheme.allCases {
                    _ = theme.words(includingBlocked: true)
                    _ = theme.words(includingBlocked: false)
                }
                _ = MadeUpWords.pool
                _ = WordList.adjectives
                _ = WordList.nouns
            }.value
        }
    }

    /// Only the Generate button animates the swap. Option changes happen while a menu or stepper is
    /// animating, and a second animation on the same rows triggers UIKit's "Decomposition" warning.
    private func generate(animated: Bool = false) {
        let batch = generator.generateDetailedBatch(options: options, count: Self.batchSize)
        var transaction = Transaction(animation: animated ? .snappy : nil)
        transaction.disablesAnimations = !animated
        withTransaction(transaction) {
            usernames = batch
            copied = nil
        }
    }

    private func copy(_ name: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = name
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)
        #endif
        withAnimation { copied = name }
    }
}

private struct KeptWord: Equatable {
    var word: String
    var position: PinPosition
}

/// A row that opens a menu of checkmarks. At least one choice always stays selected.
private struct MultiSelectMenu<Value: SetStorable & Identifiable>: View {
    let id: String
    let title: String
    /// Used in the row's summary when several are selected, like "3 themes".
    let plural: String
    let label: (Value) -> String
    @Binding var selection: Set<Value>

    private var summary: String {
        selection.count == 1 ? label(selection.first!) : "\(selection.count) \(plural)"
    }

    var body: some View {
        LabeledContent(title) {
            Menu {
                ForEach(Array(Value.allCases)) { value in
                    Toggle(label(value), isOn: Binding {
                        selection.contains(value)
                    } set: { isOn in
                        var updated = selection
                        if isOn { updated.insert(value) } else { updated.remove(value) }
                        if !updated.isEmpty { selection = updated }
                    })
                    .disabled(selection == [value])
                }
            } label: {
                Text(summary)
            }
            .fixedSize()
            .accessibilityIdentifier(id)
            #if os(iOS) || os(visionOS)
            .menuActionDismissBehavior(.disabled)
            #endif
        }
    }
}

/// A row with the title on the left and the value beside the stepper arrows on the right.
private struct NumberStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let id: String

    var body: some View {
        LabeledContent(title) {
            Stepper(value: $value, in: range) {
                Text("\(value)").monospacedDigit()
            }
            .accessibilityIdentifier(id)
        }
    }
}

#Preview {
    ContentView()
}
