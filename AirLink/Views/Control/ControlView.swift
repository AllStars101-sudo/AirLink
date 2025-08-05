//
//  ControlView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI
import CoreHaptics

private struct HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

struct ControlView: View {
    @Environment(AirFrameModel.self) private var appModel
    @State private var showingConnectionSheet = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Connection Status Card
                        ConnectionStatusCard()
                            .liquidGlassEffect()
                        
                        // Gimbal Attitude Display
                        if appModel.isConnected {
                            GimbalAttitudeCard()
                                .liquidGlassEffect()
                        }
                        
                        // Mode Selection
                        if appModel.isConnected {
                            ModeSelectionCard()
                                .liquidGlassEffect()
                        }
                        
                        // Quick Actions
                        if appModel.isConnected {
                            QuickActionsCard()
                                .liquidGlassEffect()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color.blue.opacity(0.1),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("AirFrame Control")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionButton()
                }
            }
            .sheet(isPresented: $showingConnectionSheet) {
                ConnectionView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if !appModel.isConnected && !appModel.isConnecting {
                appModel.startScanning()
            }
        }
    }
}

// MARK: - Connection Status Card
private struct ConnectionStatusCard: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                connectionStatusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionStatusTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(connectionStatusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if appModel.isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                }
            }
            
            if let error = appModel.connectionError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .onAppear { HapticManager.notification(.error) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
    
    private var connectionStatusIcon: some View {
        Image(systemName: appModel.isConnected ? "wifi" : "wifi.slash")
            .font(.title2)
            .foregroundStyle(appModel.isConnected ? .green : .red)
            .frame(width: 32, height: 32)
    }
    
    private var connectionStatusTitle: String {
        if appModel.isConnected {
            return "Connected to \(appModel.deviceName)"
        } else if appModel.isConnecting {
            return "Connecting..."
        } else {
            return "Not Connected"
        }
    }
    
    private var connectionStatusSubtitle: String {
        if appModel.isConnected {
            return "Ready for control"
        } else if appModel.isConnecting {
            return "Searching for AirFrame gimbal"
        } else {
            return "Tap to connect to your gimbal"
        }
    }
}

// MARK: - Gimbal Attitude Card
private struct GimbalAttitudeCard: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Gimbal Attitude")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 24) {
                AttitudeIndicator(
                    title: "Pitch",
                    value: appModel.currentPitch,
                    color: .blue,
                    iconName: "arrow.up.and.down"
                )
                
                AttitudeIndicator(
                    title: "Roll",
                    value: appModel.currentRoll,
                    color: .green,
                    iconName: "arrow.left.and.right"
                )
                
                AttitudeIndicator(
                    title: "Yaw",
                    value: appModel.currentYaw,
                    color: .purple,
                    iconName: "arrow.clockwise"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

private struct AttitudeIndicator: View {
    let title: String
    let value: Float
    let color: Color
    let iconName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text("\(value, specifier: "%.1f")°")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mode Selection Card
private struct ModeSelectionCard: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Gimbal Mode")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(GimbalMode.allCases.filter { $0 != .inactive }, id: \.self) { mode in
                    ModeButton(mode: mode, isSelected: appModel.currentMode == mode) {
                        appModel.setGimbalMode(mode)
                        HapticManager.impact(.medium)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

private struct ModeButton: View {
    let mode: GimbalMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                
                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .primary : Color(uiColor: .systemGray5))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Quick Actions Card
private struct QuickActionsCard: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Calibrate",
                    iconName: "target",
                    color: .orange
                ) {
                    appModel.calibrateGimbal()
                }
                
                QuickActionButton(
                    title: "Reset Yaw",
                    iconName: "arrow.clockwise",
                    color: .blue
                ) {
                    appModel.resetYaw()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

private struct QuickActionButton: View {
    let title: String
    let iconName: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
            HapticManager.impact(.light)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Connection Button
private struct ConnectionButton: View {
    @Environment(AirFrameModel.self) private var appModel
    @State private var showingConnectionSheet = false
    
    var body: some View {
        Button {
            showingConnectionSheet = true
            HapticManager.impact(.medium)
        } label: {
            Image(systemName: appModel.isConnected ? "wifi" : "wifi.slash")
                .foregroundStyle(appModel.isConnected ? .green : .red)
        }
        .sheet(isPresented: $showingConnectionSheet) {
            ConnectionView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Liquid Glass Effect Modifier
private struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func liquidGlassEffect() -> some View {
        modifier(LiquidGlassModifier())
    }
}

#Preview {
    ControlView()
        .environment(AirFrameModel())
}
