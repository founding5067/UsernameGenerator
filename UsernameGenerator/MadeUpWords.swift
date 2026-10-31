//
//  MadeUpWords.swift
//  UsernameGenerator
//
//  Pronounceable words that aren't in any dictionary, like "vorak" or "telum".
//  Built on device from syllables, so there is no list to ship and nothing to look up.
//

import Foundation

nonisolated enum MadeUpWords {
    static let onsets = ["b", "d", "f", "g", "k", "l", "m", "n", "p", "r", "s", "t", "v", "z", "tr"]
    static let vowels = ["a", "e", "i", "o", "u"]
    static let codas = ["", "n", "r", "l", "s"]

    /// Every word is two syllables of 2 to 4 letters each, so 4 to 8 letters. The order is fixed, so a seeded generator is reproducible.
    static let pool: [String] = build()

    /// Parts of words that must not show up anywhere in a made-up word: every blocked word of three or
    /// more letters, plus the fragments in blocked_madeup.txt.
    static let blockedFragments: Set<String> = {
        let extra = WordList.load(resource: "blocked_madeup")
        return Set(WordList.blocked.union(extra).filter { $0.count >= 3 })
    }()

    static func build() -> [String] {
        let syllables = onsets.flatMap { onset in vowels.flatMap { vowel in codas.map { onset + vowel + $0 } } }
        let blocked = blockedFragments
        let longest = blocked.map(\.count).max() ?? 3
        var words: [String] = []
        words.reserveCapacity(syllables.count * syllables.count)
        for first in syllables {
            for second in syllables {
                let word = first + second
                if !containsBlockedFragment(word, blocked: blocked, longest: longest) { words.append(word) }
            }
        }
        return words
    }

    static func containsBlockedFragment(_ word: String, blocked: Set<String>, longest: Int) -> Bool {
        let letters = Array(word)
        for start in letters.indices {
            for length in 3...max(3, longest) where start + length <= letters.count {
                if blocked.contains(String(letters[start..<start + length])) { return true }
            }
        }
        return false
    }
}
