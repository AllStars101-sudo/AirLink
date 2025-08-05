//
//  TrackerLogic.swift
//  AirLink
//
//  Created by Chris on 8/10/25.
//

import Foundation
import CoreGraphics
import Combine

/// Converts Vision rectangle output (person bounding-box in preview
/// coordinates) into pan/tilt angular speeds expected by AirOS.
/// Publishes throttled BLE command strings.
///
/// – previewRect: CGRect of detected human, normalised 0-1 in both axes.
/// – frame: live-preview dimensions.
/// – panSpeed deg/s, tiltSpeed deg/s are clamped ±45 (matches ESP code).
@MainActor
final class TrackerLogic: ObservableObject {
    
    // Public publishers the UI can observe if needed
    @Published private(set) var lastPanSpeed: CGFloat = 0
    @Published private(set) var lastTiltSpeed: CGFloat = 0
    @Published private(set) var isTracking = false
    
    @Published private(set) var detectedPersonRect: CGRect = .zero
    
    // Dependencies
    private weak var bluetooth: BluetoothManager?
    private var cancellables = Set<AnyCancellable>()
    
    // Tunables
    private let maxSpeed: CGFloat = 45          // deg/s
    private let deadZone: CGFloat = 0.08        // 8 % screen centre no-move
    private let easing: CGFloat   = 0.30        // first-order low-pass
    
    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }
    
    // MARK: - Public API
    func processDetection(_ rect: CGRect, in frame: CGRect) {
        self.detectedPersonRect = rect

        guard rect != .zero else {                      // No person
            sendSpeeds(pan: 0, tilt: 0, active: false)
            return
        }
        
        // Normalised centre offset (-0.5…+0.5)
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let dx = (centre.x / frame.width)  - 0.5
        let dy = (centre.y / frame.height) - 0.5   // positive down
        
        // Dead-zone
        let panSpeed  = abs(dx) < deadZone ? 0 : CGFloat(dx) * maxSpeed * 2
        let tiltSpeed = abs(dy) < deadZone ? 0 : CGFloat(dy) * maxSpeed * 2
        
        // First-order easing to smooth sudden jumps
        lastPanSpeed  = lastPanSpeed  * (1 - easing) + panSpeed  * easing
        lastTiltSpeed = lastTiltSpeed * (1 - easing) + tiltSpeed * easing
        
        sendSpeeds(pan: lastPanSpeed, tilt: lastTiltSpeed, active: true)
    }
}

// MARK: - Private helpers
private extension TrackerLogic {
    func sendSpeeds(pan: CGFloat, tilt: CGFloat, active: Bool) {
        self.isTracking = active

        guard let bt = bluetooth, bt.isConnected else { return }
        
        // Send only if tracking OR previously tracking (to stop)
        if active || isTracking {
            let panCmd  = String(format: "track_pan:%.2f",  pan)
            let tiltCmd = String(format: "track_tilt:%.2f", tilt)
            bt.sendCommand(panCmd)
            bt.sendCommand(tiltCmd)
        }
        isTracking = active
    }
}
