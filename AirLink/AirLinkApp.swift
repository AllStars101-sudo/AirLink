//
//  AirLinkApp.swift
//  AirLink
//
//  Created by Chris on 8/1/25.
//

import SwiftUI
import SwiftData

@main
struct AirLinkApp: App {
    @State private var appModel = AirFrameModel()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
    }
}
