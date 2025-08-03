//
//  StatusView.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import SwiftUI
import Charts

struct StatusView: View {
    @Environment(AirFrameModel.self) private var appModel
    @State private var attitudeHistory: [AttitudeReading] = []
    @State private var timer: Timer?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 24) {
                        if appModel.isConnected {
                            // Real-time Chart
                            AttitudeChartCard(data: attitudeHistory)
                                .liquidGlassEffect()
                            
                            // Detailed Status
                            DetailedStatusCard()
                                .liquidGlassEffect()
                            
                            // System Health
                            SystemHealthCard()
                                .liquidGlassEffect()
                        } else {
                            NotConnectedCard()
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
                        Color.green.opacity(0.1),
                        Color(uiColor: .systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Status Monitor")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            startDataCollection()
        }
        .onDisappear {
            stopDataCollection()
        }
        .onChange(of: appModel.isConnected) { _, isConnected in
            if isConnected {
                startDataCollection()
            } else {
                stopDataCollection()
                attitudeHistory.removeAll()
            }
        }
    }
    
    private func startDataCollection() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if appModel.isConnected {
                    let reading = AttitudeReading(
                        timestamp: Date(),
                        pitch: appModel.currentPitch,
                        roll: appModel.currentRoll,
                        yaw: appModel.currentYaw
                    )
                    attitudeHistory.append(reading)
                    
                    // Keep only last 100 readings (10 seconds at 10Hz)
                    if attitudeHistory.count > 100 {
                        attitudeHistory.removeFirst()
                    }
                }
            }
        }
    }
    
    private func stopDataCollection() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Attitude Chart Card
private struct AttitudeChartCard: View {
    let data: [AttitudeReading]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Real-time Attitude")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("Collecting data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            } else {
                Chart(data) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Pitch", reading.pitch)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Roll", reading.roll)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Yaw", reading.yaw)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 200)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .stride(by: 45)) { _ in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(.secondary)
                    }
                }
                .chartLegend(position: .bottom) {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            Text("Pitch")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Roll")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.purple)
                                .frame(width: 8, height: 8)
                            Text("Yaw")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detailed Status Card
private struct DetailedStatusCard: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Gimbal Status")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                StatusRow(
                    title: "Current Mode",
                    value: appModel.currentMode.displayName,
                    iconName: appModel.currentMode.iconName,
                    color: .blue
                )
                
                StatusRow(
                    title: "Calibration",
                    value: appModel.isCalibrating ? "In Progress" : "Complete",
                    iconName: appModel.isCalibrating ? "target" : "checkmark.circle.fill",
                    color: appModel.isCalibrating ? .orange : .green
                )
                
                StatusRow(
                    title: "Connection",
                    value: "Bluetooth LE",
                    iconName: "wifi",
                    color: .green
                )
                
                StatusRow(
                    title: "Device",
                    value: appModel.deviceName,
                    iconName: "cpu",
                    color: .purple
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let iconName: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - System Health Card
private struct SystemHealthCard: View {
    @Environment(AirFrameModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("System Health")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                HealthIndicator(
                    title: "Stabilization",
                    status: .good,
                    iconName: "scope"
                )
                
                HealthIndicator(
                    title: "Communication",
                    status: .good,
                    iconName: "antenna.radiowaves.left.and.right"
                )
                
                HealthIndicator(
                    title: "Motors",
                    status: .good,
                    iconName: "gearshape.2.fill"
                )
                
                HealthIndicator(
                    title: "Sensors",
                    status: .good,
                    iconName: "gyroscope"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

private struct HealthIndicator: View {
    let title: String
    let status: HealthStatus
    let iconName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(status.color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(status.color)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemGray6))
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
}

private enum HealthStatus {
    case good, warning, error
    
    var displayName: String {
        switch self {
        case .good: return "Good"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Not Connected Card
private struct NotConnectedCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundStyle(.red.opacity(0.7))
            
            Text("Not Connected")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text("Connect to your AirFrame gimbal to view real-time status information")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Types
struct AttitudeReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let pitch: Float
    let roll: Float
    let yaw: Float
}

#Preview {
    StatusView()
        .environment(AirFrameModel())
}
