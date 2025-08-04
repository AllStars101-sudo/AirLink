//
//  BluetoothManager.swift
//  AirLink
//
//  Created by Chris on 8/3/25.
//

import Foundation
import CoreBluetooth

protocol BluetoothManagerDelegate: AnyObject {
    func bluetoothManagerDidUpdateState(_ state: CBManagerState)
    func bluetoothManagerDidConnect()
    func bluetoothManagerDidDisconnect(error: Error?)
    func bluetoothManagerDidReceiveAngleData(pitch: Float, roll: Float, yaw: Float)
    func bluetoothManagerDidReceiveStatusUpdate(_ status: GimbalStatus)
}

@MainActor
class BluetoothManager: NSObject {
    weak var delegate: BluetoothManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var gimbalPeripheral: CBPeripheral?
    
    // BLE UUIDs from AirOS.ino
    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    
    // READ-ONLY Characteristics
    private let pitchAngleCharUUID = CBUUID(string: "a1e8f36e-685b-4869-9828-c107a6729938")
    private let rollAngleCharUUID = CBUUID(string: "43a85368-8422-4573-a554-411a4a6e87f1")
    private let yawAngleCharUUID = CBUUID(string: "e974ac4a-8182-4458-9419-4ac9c6c5184e")
    private let gimbalStatusCharUUID = CBUUID(string: "c8a4a58b-1579-4451-b016-1f38e3115a3a")
    
    // READ-WRITE Characteristics
    private let gimbalModeCharUUID = CBUUID(string: "2a79d494-436f-45b6-890f-563534ab2c84")
    private let gimbalControlCharUUID = CBUUID(string: "f7a7a5a8-5e58-4c8d-9b6e-3aa5d6c5b768")
    
    // PID Characteristics (from AirOS sample)
    private let pitchPIDCharUUID = CBUUID(string: "b16b472c-88a4-4734-9f85-01458e08d669")
    private let rollPIDCharUUID = CBUUID(string: "8184457e-85a8-4217-a9a3-a7d57947a612")
    private let yawPIDCharUUID = CBUUID(string: "5d9b73b3-81e0-4368-910a-e322359b8676")
    private let kalmanParamsCharUUID = CBUUID(string: "6e13e51a-f3c2-46a4-b203-92147395c5d0")
    
    // Characteristics references
    private var pitchAngleCharacteristic: CBCharacteristic?
    private var rollAngleCharacteristic: CBCharacteristic?
    private var yawAngleCharacteristic: CBCharacteristic?
    private var gimbalStatusCharacteristic: CBCharacteristic?
    private var gimbalModeCharacteristic: CBCharacteristic?
    private var gimbalControlCharacteristic: CBCharacteristic?
    
    // PID Characteristics references
    private var pitchPIDCharacteristic: CBCharacteristic?
    private var rollPIDCharacteristic: CBCharacteristic?
    private var yawPIDCharacteristic: CBCharacteristic?
    private var kalmanParamsCharacteristic: CBCharacteristic?
    
    // Angle data tracking
    private var lastPitch: Float = 0.0
    private var lastRoll: Float = 0.0
    private var lastYaw: Float = 0.0
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func disconnect() {
        guard let peripheral = gimbalPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func setGimbalMode(_ mode: GimbalMode) {
        guard let characteristic = gimbalModeCharacteristic,
              let peripheral = gimbalPeripheral else { return }
        
        let data = Data([mode.rawValue])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func sendCommand(_ command: String) {
        guard let characteristic = gimbalControlCharacteristic,
              let peripheral = gimbalPeripheral else { return }
        
        guard let data = command.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // MARK: - PID Tuning Methods
    func setPitchPID(p: Float, i: Float, d: Float) {
        guard let characteristic = pitchPIDCharacteristic,
              let peripheral = gimbalPeripheral else { return }
        
        var pidData = PIDSettings(p: p, i: i, d: d)
        let data = Data(bytes: &pidData, count: MemoryLayout<PIDSettings>.size)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func setRollPID(p: Float, i: Float, d: Float) {
        guard let characteristic = rollPIDCharacteristic,
              let peripheral = gimbalPeripheral else { return }
        
        var pidData = PIDSettings(p: p, i: i, d: d)
        let data = Data(bytes: &pidData, count: MemoryLayout<PIDSettings>.size)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func setYawPID(p: Float, i: Float, d: Float) {
        guard let characteristic = yawPIDCharacteristic,
              let peripheral = gimbalPeripheral else { return }
        
        var pidData = PIDSettings(p: p, i: i, d: d)
        let data = Data(bytes: &pidData, count: MemoryLayout<PIDSettings>.size)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.bluetoothManagerDidUpdateState(central.state)
        
        if central.state == .poweredOn {
            startScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if this is the AirOS Gimbal device
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        
        if deviceName == "AirOS Gimbal" {
            print("📱 Found AirOS Gimbal: \(deviceName)")
            gimbalPeripheral = peripheral
            gimbalPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            centralManager.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
        delegate?.bluetoothManagerDidConnect()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        gimbalPeripheral = nil
        delegate?.bluetoothManagerDidDisconnect(error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManagerDidDisconnect(error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([
                    // Read-only characteristics
                    pitchAngleCharUUID, rollAngleCharUUID, yawAngleCharUUID, gimbalStatusCharUUID,
                    // Read-write characteristics
                    gimbalModeCharUUID, gimbalControlCharUUID,
                    // PID characteristics
                    pitchPIDCharUUID, rollPIDCharUUID, yawPIDCharUUID, kalmanParamsCharUUID
                ], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case pitchAngleCharUUID:
                pitchAngleCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case rollAngleCharUUID:
                rollAngleCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case yawAngleCharUUID:
                yawAngleCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case gimbalStatusCharUUID:
                gimbalStatusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case gimbalModeCharUUID:
                gimbalModeCharacteristic = characteristic
            case gimbalControlCharUUID:
                gimbalControlCharacteristic = characteristic
            case pitchPIDCharUUID:
                pitchPIDCharacteristic = characteristic
            case rollPIDCharUUID:
                rollPIDCharacteristic = characteristic
            case yawPIDCharUUID:
                yawPIDCharacteristic = characteristic
            case kalmanParamsCharUUID:
                kalmanParamsCharacteristic = characteristic
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case pitchAngleCharUUID:
            if data.count >= 4 {
                let pitch = data.withUnsafeBytes { $0.load(as: Float.self) }
                updateAngleData(pitch: pitch)
            }
        case rollAngleCharUUID:
            if data.count >= 4 {
                let roll = data.withUnsafeBytes { $0.load(as: Float.self) }
                updateAngleData(roll: roll)
            }
        case yawAngleCharUUID:
            if data.count >= 4 {
                let yaw = data.withUnsafeBytes { $0.load(as: Float.self) }
                updateAngleData(yaw: yaw)
            }
        case gimbalStatusCharUUID:
            if let statusValue = data.first,
               let status = GimbalStatus(rawValue: statusValue) {
                delegate?.bluetoothManagerDidReceiveStatusUpdate(status)
            }
        default:
            break
        }
    }
    
    private func updateAngleData(pitch: Float? = nil, roll: Float? = nil, yaw: Float? = nil) {
        if let pitch = pitch { lastPitch = pitch }
        if let roll = roll { lastRoll = roll }
        if let yaw = yaw { lastYaw = yaw }
        
        delegate?.bluetoothManagerDidReceiveAngleData(pitch: lastPitch, roll: lastRoll, yaw: lastYaw)
    }
}

// MARK: - Supporting Types
struct PIDSettings {
    let p: Float
    let i: Float
    let d: Float
}