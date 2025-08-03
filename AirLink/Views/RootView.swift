//
//  RootView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct RootView: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        Group {
            if appModel.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.8), value: appModel.hasCompletedOnboarding)
    }
}

#Preview {
    RootView()
        .environment(AirFrameModel())
}