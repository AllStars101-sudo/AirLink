//
//  PIDTuningView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI

struct PIDTuningView: View {
    @Environment(AirFrameModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var pitchP: Float = 1.2
    @State private var pitchI: Float = 0.1
    @State private var pitchD: Float = 0.05
    
    @State private var rollP: Float = 1.2
    @State private var rollI: Float = 0.1
    @State private var rollD: Float = 0.05
    
    @State private var yawP: Float = 0.8
    @State private var yawI: Float = 0.05
    @State private var yawD: Float = 0.02
    
    @State private var showingResetAlert = false
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        NavigationStack {
            Form {
                warningSection
                
                pitchSection
                
                rollSection
                
                yawSection
                
                actionSection
            }
            .navigationTitle("PID Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [Color.black, Color.purple.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Show confirmation dialog
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        savePIDValues()
                        dismiss()
                    }
                    .disabled(!appModel.isConnected)
                }
            }
            .alert("Reset to Defaults", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all PID values to their default settings. This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCurrentValues()
        }
    }
    
    @ViewBuilder
    private var warningSection: some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Advanced Feature")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("PID tuning affects gimbal stability. Incorrect values may cause oscillation or poor performance. Only modify if you understand PID control systems.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var pitchSection: some View {
        Section {
            PIDSlider(
                title: "Proportional (P)",
                value: $pitchP,
                range: 0.0...5.0,
                description: "Response strength to pitch errors"
            )
            
            PIDSlider(
                title: "Integral (I)",
                value: $pitchI,
                range: 0.0...1.0,
                description: "Corrects steady-state pitch errors"
            )
            
            PIDSlider(
                title: "Derivative (D)",
                value: $pitchD,
                range: 0.0...0.5,
                description: "Dampens pitch oscillations"
            )
        } header: {
            HStack {
                Image(systemName: "arrow.up.and.down")
                    .foregroundStyle(.blue)
                Text("Pitch Control")
            }
        }
    }
    
    @ViewBuilder
    private var rollSection: some View {
        Section {
            PIDSlider(
                title: "Proportional (P)",
                value: $rollP,
                range: 0.0...5.0,
                description: "Response strength to roll errors"
            )
            
            PIDSlider(
                title: "Integral (I)",
                value: $rollI,
                range: 0.0...1.0,
                description: "Corrects steady-state roll errors"
            )
            
            PIDSlider(
                title: "Derivative (D)",
                value: $rollD,
                range: 0.0...0.5,
                description: "Dampens roll oscillations"
            )
        } header: {
            HStack {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(.green)
                Text("Roll Control")
            }
        }
    }
    
    @ViewBuilder
    private var yawSection: some View {
        Section {
            PIDSlider(
                title: "Proportional (P)",
                value: $yawP,
                range: 0.0...3.0,
                description: "Response strength to yaw errors"
            )
            
            PIDSlider(
                title: "Integral (I)",
                value: $yawI,
                range: 0.0...0.5,
                description: "Corrects steady-state yaw errors"
            )
            
            PIDSlider(
                title: "Derivative (D)",
                value: $yawD,
                range: 0.0...0.2,
                description: "Dampens yaw oscillations"
            )
        } header: {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.purple)
                Text("Yaw Control")
            }
        }
    }
    
    @ViewBuilder
    private var actionSection: some View {
        Section {
            Button("Reset to Defaults") {
                showingResetAlert = true
            }
            .foregroundStyle(.orange)
            
            Button("Test Current Settings") {
                testCurrentSettings()
            }
            .disabled(!appModel.isConnected)
        } footer: {
            Text("Test settings will temporarily apply values for 10 seconds, then revert. Save to make changes permanent.")
        }
    }
    
    private func loadCurrentValues() {
        // In a real implementation, these would be loaded from the gimbal
        // For now, we'll use default values
    }
    
    private func savePIDValues() {
        // Send PID values to gimbal via Bluetooth
        // Implementation would send these via the BluetoothManager
        hasUnsavedChanges = false
    }
    
    private func resetToDefaults() {
        pitchP = 1.2
        pitchI = 0.1
        pitchD = 0.05
        
        rollP = 1.2
        rollI = 0.1
        rollD = 0.05
        
        yawP = 0.8
        yawI = 0.05
        yawD = 0.02
        
        hasUnsavedChanges = true
    }
    
    private func testCurrentSettings() {
        // Temporarily apply settings for testing
        savePIDValues()
        
        // In a real implementation, this would set a timer to revert settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            // Revert to previous settings
        }
    }
}

// MARK: - PID Slider Component
private struct PIDSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.3f", value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            }
            
            Slider(value: $value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(String(format: "%.1f", range.lowerBound))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(String(format: "%.1f", range.upperBound))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .tint(.blue)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PIDTuningView()
        .environment(AirFrameModel())
}