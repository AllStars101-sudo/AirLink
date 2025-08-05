//
//  MainTabView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        @Bindable var appModel = appModel
        TabView(selection: $appModel.selectedTab) {
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
            
            AerialView()
                .tabItem {
                    Image(systemName: "apple.intelligence")
                    Text("Aerial")
                }
                .tag(Tab.aerial)
            
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


#Preview {
    MainTabView()
        .environment(AirFrameModel())
}