//
//  UsernameGeneratorApp.swift
//  UsernameGenerator
//
//  Created by Cole Braswell on 10/30/26.
//

import SwiftUI

@main
struct UsernameGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #elseif os(visionOS)
        .defaultSize(width: 560, height: 820)
        #endif
    }
}
