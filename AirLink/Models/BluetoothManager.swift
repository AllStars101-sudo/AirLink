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
    
    // Characteristics references
    private var pitchAngleCharacteristic: CBCharacteristic?
    private var rollAngleCharacteristic: CBCharacteristic?
    private var yawAngleCharacteristic: CBCharacteristic?
    private var gimbalStatusCharacteristic: CBCharacteristic?
    private var gimbalModeCharacteristic: CBCharacteristic?
    private var gimbalControlCharacteristic: CBCharacteristic?
    
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
        // Found the AirOS Gimbal
        gimbalPeripheral = peripheral
        gimbalPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
        centralManager.stopScan()
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
                    pitchAngleCharUUID, rollAngleCharUUID, yawAngleCharUUID, gimbalStatusCharUUID,
                    gimbalModeCharUUID, gimbalControlCharUUID
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