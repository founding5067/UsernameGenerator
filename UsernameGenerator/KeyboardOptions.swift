//
//  KeyboardOptions.swift
//  UsernameGenerator
//
//  How the keyboard's three quick choices become generator options. Kept here, away from the
//  keyboard's views, so the unit tests can reach it.
//

import Foundation

nonisolated extension UsernameOptions {
    static let keyboardWordCounts = [1, 2, 3]
    /// 0 means no limit.
    static let keyboardMaxLengths = [0, 12, 15, 20]

    static func keyboard(wordCount: Int, includeNumber: Bool, maxLength: Int) -> UsernameOptions {
        UsernameOptions(
            wordCount: wordCount,
            includeNumber: includeNumber,
            limitLength: maxLength > 0,
            maxLength: maxLength > 0 ? maxLength : UsernameOptions().maxLength
        )
    }
}
