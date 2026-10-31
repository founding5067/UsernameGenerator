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

    @AppStorage("pattern", store: SharedSettings.defaults) private var pattern = UsernameOptions().pattern
    @AppStorage("alliterate", store: SharedSettings.defaults) private var alliterate = UsernameOptions().alliterate

    @State private var usernames: [String] = []
    @State private var copied: String?

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
            pattern: pattern,
            alliterate: alliterate
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

    private var themes: Set<WordTheme> {
        let themes = WordTheme.decode(themesRaw)
        return themes.isEmpty ? [.any] : themes
    }

    init() {
        SharedSettings.migrateLegacyKeys()
    }

    private var strengthText: String {
        let count = generator.combinationCount(options: options)
        let formatted = count >= 1e15
            ? "10^\(Int(log10(count)))"
            : count.formatted(.number.notation(.compactName).precision(.significantDigits(2)))
        return "About \(formatted) possible usernames"
    }

    private var strengthColor: Color {
        generator.combinationCount(options: options) < 1e6 ? .orange : .green
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(usernames, id: \.self) { name in
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
                        .accessibilityHint("Copies to the clipboard")
                    }

                    Button {
                        generate()
                    } label: {
                        Text("Generate")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("r", modifiers: .command)
                } header: {
                    Text("Tap a username to copy it")
                } footer: {
                    Label(strengthText, systemImage: "gauge.with.dots.needle.50percent")
                        .foregroundStyle(strengthColor)
                }

                Section("Words") {
                    Stepper(value: $wordCount, in: UsernameOptions.wordCountRange) {
                        LabeledContent("Number of words", value: "\(wordCount)")
                    }
                    MultiSelectMenu(
                        title: "Theme", plural: "themes", label: \.label,
                        selection: Binding { themes } set: { themesRaw = WordTheme.encode($0) }
                    )
                    Picker("Pattern", selection: $pattern) {
                        ForEach(WordPattern.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Alliterate", isOn: $alliterate)
                    MultiSelectMenu(
                        title: "Separator", plural: "separators", label: \.label,
                        selection: Binding { separators } set: { separatorsRaw = WordSeparator.encode($0) }
                    )
                    .disabled(lettersAndDigitsOnly)
                    MultiSelectMenu(
                        title: "Capitalization", plural: "styles", label: \.label,
                        selection: Binding { wordCases } set: { wordCasesRaw = WordCase.encode($0) }
                    )
                }

                Section("Numbers") {
                    Toggle("Add numbers", isOn: $includeNumber)
                    if includeNumber {
                        Stepper(value: $digitCount, in: UsernameOptions.digitCountRange) {
                            LabeledContent("Digits", value: "\(digitCount)")
                        }
                    }
                }

                Section {
                    Toggle("Limit length", isOn: $limitLength)
                    if limitLength {
                        Stepper(value: $maxLength, in: UsernameOptions.maxLengthRange) {
                            LabeledContent("Maximum characters", value: "\(maxLength)")
                        }
                    }
                    Toggle("Letters and numbers only", isOn: $lettersAndDigitsOnly)
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

                Section("About") {
                    Label("Runs entirely on this device. No accounts, no ads, no tracking, no network.",
                          systemImage: "lock.shield")
                    Text("Words from the EFF Large Wordlist by the Electronic Frontier Foundation, used under CC BY 4.0, with some words filtered out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Username Generator")
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 640)
        #endif
        .onAppear(perform: generate)
        .onChange(of: options) {
            generate()
            WidgetCenter.shared.reloadTimelines(ofKind: SharedSettings.widgetKind)
        }
    }

    private func generate() {
        withAnimation(.snappy) {
            usernames = generator.generateBatch(options: options, count: Self.batchSize)
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

/// A row that opens a menu of checkmarks. At least one choice always stays selected.
private struct MultiSelectMenu<Value: SetStorable & Identifiable>: View {
    let title: String
    /// Used in the row's summary when several are selected, like "3 themes".
    let plural: String
    let label: (Value) -> String
    @Binding var selection: Set<Value>

    private var summary: String {
        selection.count == 1 ? label(selection.first!) : "\(selection.count) \(plural)"
    }

    var body: some View {
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
            LabeledContent(title, value: summary)
        }
        #if os(iOS)
        .menuActionDismissBehavior(.disabled)
        #endif
    }
}

#Preview {
    ContentView()
}
