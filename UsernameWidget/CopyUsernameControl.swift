//
//  CopyUsernameControl.swift
//  UsernameWidget
//
//  A Control Center button that copies a fresh username. Nothing is stored.
//

import AppIntents
import SwiftUI
import WidgetKit

// Control Center controls don't exist on visionOS.
#if !os(visionOS)
struct CopyUsernameControl: ControlWidget {
    static let kind = "CopyUsernameControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: CopyUsernameIntent()) {
                Label("New Username", systemImage: "person.crop.circle.badge.plus")
            }
        }
        .displayName("New Username")
        .description("Copies a new random username.")
    }
}
#endif
