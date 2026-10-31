//
//  WordList.swift
//  UsernameGenerator
//
//  The EFF Large Wordlist (7,775 words after removing hyphens) by the Electronic Frontier Foundation,
//  used under CC BY 4.0. https://www.eff.org/dice
//

import Foundation

nonisolated enum WordList {
    /// The full bundled EFF large wordlist, exactly as shipped.
    static let effUnfiltered: [String] = load(resource: "eff_large_wordlist")

    /// Words that should never appear in a username (see blocked_words.txt).
    static let blocked: Set<String> = Set(load(resource: "blocked_words"))

    /// The EFF wordlist minus blocked words. This is what the generator uses.
    static let eff: [String] = effUnfiltered.filter { !blocked.contains($0) }

    static func load(resource: String, bundle: Bundle = .main) -> [String] {
        guard let url = bundle.url(forResource: resource, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing word list \(resource).txt in bundle")
            return []
        }
        return contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

/// Optional vocabularies. Each theme file is a hand-picked subset of the EFF list.
nonisolated enum WordTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case any
    case animals
    case nature
    case space
    case food

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any: "Any"
        case .animals: "Animals"
        case .nature: "Nature"
        case .space: "Space"
        case .food: "Food"
        }
    }

    var words: [String] { Self.cache[self] ?? WordList.eff }

    private static let cache: [WordTheme: [String]] = Dictionary(uniqueKeysWithValues: allCases.map { theme in
        let words = theme == .any
            ? WordList.eff
            : WordList.load(resource: theme.rawValue).filter { !WordList.blocked.contains($0) }
        return (theme, words)
    })
}
