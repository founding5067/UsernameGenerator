//
//  CopyUsernameIntent.swift
//  UsernameGenerator
//
//  Backs the Control Center button. Shared by the app and the widget extension.
//

import AppIntents
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CopyUsernameIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy New Username"
    static let isDiscoverable = false
    #if os(iOS)
    // iOS blocks clipboard writes from the background, so the app opens and runs this intent.
    static let openAppWhenRun = true
    #endif

    func perform() async throws -> some IntentResult {
        let username = UsernameGenerator().generate(options: SharedSettings.loadOptions())
        #if canImport(UIKit)
        UIPasteboard.general.string = username
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(username, forType: .string)
        #endif
        return .result()
    }
}
