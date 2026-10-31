//
//  AppIntent.swift
//  UsernameWidget
//

import AppIntents
import WidgetKit

/// Backs the widget's refresh button.
struct RefreshUsernameIntent: AppIntent {
    static let title: LocalizedStringResource = "New Username"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedSettings.widgetKind)
        return .result()
    }
}
