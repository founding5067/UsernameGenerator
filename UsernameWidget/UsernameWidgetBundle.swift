//
//  UsernameWidgetBundle.swift
//  UsernameWidget
//
//  Created by Cole Braswell on 10/30/26.
//

import WidgetKit
import SwiftUI

@main
struct UsernameWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsernameWidget()
        #if !os(visionOS)
        CopyUsernameControl()
        #endif
    }
}
