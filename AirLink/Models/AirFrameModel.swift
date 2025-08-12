//
//  AirFrameModel.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import Foundation
import CoreBluetooth
import SwiftUI

@MainActor
@Observable
class AirFrameModel: NSObject {
    // MARK: - Connection State
    var isConnected = false
    var isConnecting = false
    var connectionError: String?
    var deviceName = "AirFrame"
    
    // MARK: - Demo Mode
    var isDemoMode: Bool = false
    private var demoTimer: Timer?
    
    // MARK: - Gimbal State
    var currentPitch: Float = 0.0
    var currentRoll: Float = 0.0
    var currentYaw: Float = 0.0
    var currentMode: GimbalMode = .locked
    var isCalibrating = false
    
    // MARK: - Settings
    var hasCompletedOnboarding = false
    var hasCompletedAerialOnboarding = false
    
    // MARK: - UI State
    var selectedTab: Tab = .control
    
    // MARK: - BLE Manager
    private var bluetoothManager: BluetoothManager?
    
    // MARK: - AI Service
    var aerialService: AerialAIService?
    
    var aerial: AerialAIService {
        if aerialService == nil {
            aerialService = AerialAIService(airFrameModel: self)
        }
        return aerialService!
    }
    
    override init() {
        super.init()
        loadUserDefaults()
        setupBluetoothManager()
        setupAerialService()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        // In demo mode, immediately simulate a connection
        if isDemoMode {
            isConnecting = true
            enableDemoMode()
            return
        }
        bluetoothManager?.startScanning()
        isConnecting = true
    }
    
    func stopScanning() {
        bluetoothManager?.stopScanning()
        isConnecting = false
    }
    
    func disconnect() {
        if isDemoMode {
            disableDemoMode()
            return
        }
        bluetoothManager?.disconnect()
    }
    
    func setGimbalMode(_ mode: GimbalMode) {
        currentMode = mode // Update the current mode immediately
        if !isDemoMode {
            bluetoothManager?.setGimbalMode(mode)
        }
        
        // Auto-navigate to Camera tab when Person Tracking is selected
        if mode == .personTracking {
            selectedTab = .camera
        }
    }
    
    func calibrateGimbal() {
        if isDemoMode {
            isCalibrating = true
            // Simulate a short calibration routine
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.isCalibrating = false
            }
            return
        }
        bluetoothManager?.sendCommand("calibrate")
    }
    
    func resetYaw() {
        if isDemoMode {
            currentYaw = 0
            return
        }
        bluetoothManager?.sendCommand("reset_yaw")
    }
    
    func setPitchPID(p: Float, i: Float, d: Float) {
        bluetoothManager?.setPitchPID(p: p, i: i, d: d)
    }
    
    func setRollPID(p: Float, i: Float, d: Float) {
        bluetoothManager?.setRollPID(p: p, i: i, d: d)
    }
    
    func setYawPID(p: Float, i: Float, d: Float) {
        bluetoothManager?.setYawPID(p: p, i: i, d: d)
    }
    
    func saveSettings() {
        bluetoothManager?.sendCommand("save")
    }
    
    func restoreDefaults() {
        bluetoothManager?.sendCommand("defaults")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        saveUserDefaults()
    }
    
    func completeAerialOnboarding() {
        hasCompletedAerialOnboarding = true
        saveUserDefaults()
    }
    
    func resetAerialOnboarding() {
        hasCompletedAerialOnboarding = false
        saveUserDefaults()
    }
    
    // MARK: - Private Methods
    private func setupBluetoothManager() {
        bluetoothManager = BluetoothManager()
        bluetoothManager?.delegate = self
    }
    
    private func setupAerialService() {
        // Initialize the aerial service - it will be created lazily when first accessed
    }
    
    private func loadUserDefaults() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        hasCompletedAerialOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedAerialOnboarding")
        isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
        if isDemoMode {
            enableDemoMode()
        }
    }
    
    private func saveUserDefaults() {
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(hasCompletedAerialOnboarding, forKey: "hasCompletedAerialOnboarding")
        UserDefaults.standard.set(isDemoMode, forKey: "isDemoMode")
    }

    // MARK: - Demo Mode Helpers
    func enableDemoMode() {
        isDemoMode = true
        UserDefaults.standard.set(true, forKey: "isDemoMode")
        connectionError = nil
        deviceName = "AirFrame (Demo)"
        isConnecting = false
        isConnected = true
        startDemoAngles()
    }
    
    func disableDemoMode() {
        isDemoMode = false
        UserDefaults.standard.set(false, forKey: "isDemoMode")
        stopDemoAngles()
        isConnected = false
        isConnecting = false
        connectionError = nil
        deviceName = "AirFrame"
        currentPitch = 0
        currentRoll = 0
        currentYaw = 0
        isCalibrating = false
        currentMode = .locked
    }
    
    private func startDemoAngles() {
        stopDemoAngles()
        let startTime = Date()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let t = Date().timeIntervalSince(startTime)
            // Smooth, bounded motion suitable for charts and UI
            let pitch = Float(10.0 * sin(t * 1.2))
            let roll  = Float(8.0  * sin(t * 0.9 + 0.7))
            let yaw   = Float(5.0  * sin(t * 0.6 + 1.1))
            Task { @MainActor in
                self.currentPitch = pitch
                self.currentRoll = roll
                self.currentYaw = yaw
            }
        }
    }
    
    private func stopDemoAngles() {
        demoTimer?.invalidate()
        demoTimer = nil
    }
}

// MARK: - BluetoothManagerDelegate
extension AirFrameModel: BluetoothManagerDelegate {
    func bluetoothManagerDidUpdateState(_ state: CBManagerState) {
        // Handle Bluetooth state changes
    }
    
    func bluetoothManagerDidConnect() {
        isConnected = true
        isConnecting = false
        connectionError = nil
    }
    
    func bluetoothManagerDidDisconnect(error: Error?) {
        isConnected = false
        isConnecting = false
        if let error = error {
            connectionError = error.localizedDescription
        }
    }
    
    func bluetoothManagerDidReceiveAngleData(pitch: Float, roll: Float, yaw: Float) {
        currentPitch = pitch
        currentRoll = roll
        currentYaw = yaw
    }
    
    func bluetoothManagerDidReceiveStatusUpdate(_ status: GimbalStatus) {
        switch status {
        case .calibrating:
            isCalibrating = true
        case .locked, .panFollow, .fpv, .personTracking:
            isCalibrating = false
        case .inactive:
            isCalibrating = false
        }
    }
}

// MARK: - Supporting Types
enum GimbalMode: UInt8, CaseIterable {
    case inactive = 0
    case locked = 1
    case panFollow = 2
    case fpv = 3
    case personTracking = 4
    
    var displayName: String {
        switch self {
        case .inactive: return "Inactive"
        case .locked: return "Locked"
        case .panFollow: return "Pan Follow"
        case .fpv: return "FPV"
        case .personTracking: return "Person Tracking"
        }
    }
    
    var iconName: String {
        switch self {
        case .inactive: return "power"
        case .locked: return "lock.fill"
        case .panFollow: return "arrow.left.and.right"
        case .fpv: return "camera.fill"
        case .personTracking: return "person.fill"
        }
    }
}

enum GimbalStatus: UInt8 {
    case inactive = 0
    case calibrating = 1
    case locked = 2
    case panFollow = 3
    case fpv = 4
    case personTracking = 5
}

enum Tab: String, CaseIterable {
    case control = "Control"
    case status = "Status"
    case camera = "Camera"
    case aerial = "Aerial"
    case settings = "Settings"
}
