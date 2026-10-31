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
        #endif
    }
}
