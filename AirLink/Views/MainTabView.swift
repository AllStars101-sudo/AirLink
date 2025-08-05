//
//  MainTabView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AirFrameModel.self) private var appModel
    @State private var selectedTab: Tab = .control
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ControlView()
                .tabItem {
                    Image(systemName: "scope")
                    Text("Control")
                }
                .tag(Tab.control)
            
            StatusView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Status")
                }
                .tag(Tab.status)
            
            CameraView()
                .tabItem {
                    Image(systemName: "camera")
                    Text("Camera")
                }
                .tag(Tab.camera)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(.blue)
    }
}

private enum Tab: String, CaseIterable {
    case control = "Control"
    case status = "Status"
    case camera = "Camera"
    case settings = "Settings"
}

#Preview {
    MainTabView()
        .environment(AirFrameModel())
}