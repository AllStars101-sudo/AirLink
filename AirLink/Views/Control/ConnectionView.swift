//
//  ConnectionView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct ConnectionView: View {
    @Environment(AirFrameModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wifi.router")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Connect to AirFrame")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("Make sure your AirFrame gimbal is powered on and nearby")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Connection Status
                connectionStatusSection
                
                Spacer()
                
                // Actions
                actionButtons
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color.blue.opacity(0.2)],
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
    }
    
    @ViewBuilder
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            if appModel.isConnected {
                // Connected State
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text(appModel.deviceName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.green.opacity(0.2))
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
                
            } else if appModel.isConnecting {
                // Connecting State
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Searching...")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("Looking for AirFrame gimbal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue.opacity(0.2))
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
                
            } else {
                // Disconnected State
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.title)
                        .foregroundStyle(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Connected")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("Tap 'Scan' to search for devices")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.red.opacity(0.2))
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
                
                if let error = appModel.connectionError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.orange.opacity(0.2))
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if appModel.isConnected {
                Button("Disconnect") {
                    appModel.disconnect()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else if appModel.isConnecting {
                Button("Stop Scanning") {
                    appModel.stopScanning()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("Scan for AirFrame") {
                    appModel.startScanning()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Button Styles
private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .systemGray5))
                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ConnectionView()
        .environment(AirFrameModel())
}