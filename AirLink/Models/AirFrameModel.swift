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
    var deviceName = "AirOS Gimbal"
    
    // MARK: - Gimbal State
    var currentPitch: Float = 0.0
    var currentRoll: Float = 0.0
    var currentYaw: Float = 0.0
    var currentMode: GimbalMode = .locked
    var isCalibrating = false
    
    // MARK: - Settings
    var hasCompletedOnboarding = false
    
    // MARK: - UI State
    var selectedTab: Tab = .control
    
    // MARK: - BLE Manager
    private var bluetoothManager: BluetoothManager?
    
    override init() {
        super.init()
        loadUserDefaults()
        setupBluetoothManager()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        bluetoothManager?.startScanning()
        isConnecting = true
    }
    
    func stopScanning() {
        bluetoothManager?.stopScanning()
        isConnecting = false
    }
    
    func disconnect() {
        bluetoothManager?.disconnect()
    }
    
    func setGimbalMode(_ mode: GimbalMode) {
        currentMode = mode // Update the current mode immediately
        bluetoothManager?.setGimbalMode(mode)
        
        // Auto-navigate to Camera tab when Person Tracking is selected
        if mode == .personTracking {
            selectedTab = .camera
        }
    }
    
    func calibrateGimbal() {
        bluetoothManager?.sendCommand("calibrate")
    }
    
    func resetYaw() {
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
    
    // MARK: - Private Methods
    private func setupBluetoothManager() {
        bluetoothManager = BluetoothManager()
        bluetoothManager?.delegate = self
    }
    
    private func loadUserDefaults() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    private func saveUserDefaults() {
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
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
    case settings = "Settings"
}