//
//  SettingsView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AirFrameModel.self) private var appModel
    @State private var showingAbout = false
    @State private var showingPIDTuning = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Connection Section
                Section {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        
                        Text("Connection")
                        
                        Spacer()
                        
                        Text(appModel.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(appModel.isConnected ? .green.opacity(0.2) : .red.opacity(0.2))
                            )
                            .foregroundStyle(appModel.isConnected ? .green : .red)
                    }
                    
                    if appModel.isConnected {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.purple)
                                .frame(width: 24)
                            
                            Text("Device")
                            
                            Spacer()
                            
                            Text(appModel.deviceName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Device")
                }
                
                // Gimbal Section
                if appModel.isConnected {
                    Section {
                        HStack {
                            Image(systemName: "scope")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            Text("Current Mode")
                            
                            Spacer()
                            
                            Text(appModel.currentMode.displayName)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            appModel.calibrateGimbal()
                        } label: {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                                
                                Text("Calibrate Gimbal")
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if appModel.isCalibrating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.7)
                                }
                            }
                        }
                        .disabled(appModel.isCalibrating)
                        
                        Button {
                            appModel.resetYaw()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                
                                Text("Reset Yaw")
                                    .foregroundStyle(.primary)
                            }
                        }
                    } header: {
                        Text("Gimbal Controls")
                    } footer: {
                        Text("Calibration ensures optimal stabilization performance. Reset yaw to recenter the horizontal axis.")
                    }
                    
                    // Advanced Section
                    Section {
                        Button {
                            showingPIDTuning = true
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)
                                
                                Text("PID Tuning")
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Advanced")
                    } footer: {
                        Text("PID tuning allows fine adjustment of stabilization parameters. Only recommended for experienced users.")
                    }
                }
                
                // App Section
                Section {
                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            Text("About AirLink")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/yourusername/airframe")!) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            
                            Text("Visit GitHub")
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button {
                        resetOnboarding()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            
                            Text("Reset Onboarding")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("App")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.purple.opacity(0.1),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPIDTuning) {
            PIDTuningView()
                .presentationDetents([.large])
        }
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        appModel.hasCompletedOnboarding = false
    }
}

// MARK: - About View
private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Title
                    VStack(spacing: 16) {
                        Image(systemName: "scope")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("AirLink")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    // Description
                    VStack(spacing: 16) {
                        Text("Professional Gimbal Control")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Text("AirLink connects your iPhone to the AirFrame 3-axis gimbal system, providing real-time control and monitoring for professional stabilization. Perfect for filmmakers, content creators, and photography enthusiasts.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        FeatureRow(
                            iconName: "wifi",
                            title: "Wireless Control",
                            description: "Bluetooth LE connectivity for seamless control"
                        )
                        
                        FeatureRow(
                            iconName: "chart.line.uptrend.xyaxis",
                            title: "Real-time Monitoring",
                            description: "Live attitude data and system status"
                        )
                        
                        FeatureRow(
                            iconName: "gearshape.2.fill",
                            title: "Multiple Modes",
                            description: "Lock, Pan Follow, FPV, and Person Tracking"
                        )
                        
                        FeatureRow(
                            iconName: "slider.horizontal.3",
                            title: "Advanced Tuning",
                            description: "PID parameter adjustment for experts"
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black, Color.blue.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct FeatureRow: View {
    let iconName: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(nil)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AirFrameModel())
}