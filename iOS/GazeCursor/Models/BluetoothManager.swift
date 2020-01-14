//
//  BluetoothManager.swift
//  GazeCursor
//
//  Created by Sarang Borude on 6/24/19.
//  Copyright © 2019 Sarang Borude. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    // properties
    private let centralManager = CBCentralManager()
    private var peripherals = [CBPeripheral]()
    private var remotePeripheral: CBPeripheral?
    private var txCharacteristic : CBCharacteristic?
    private var rxCharacteristic : CBCharacteristic?
    private var characteristicValue = ""
    private let nc = NotificationCenter.default
    
    //Button state tracking
    var isButtonPressed = false
    
    override init() {
        super.init()
        centralManager.delegate = self
    }
}


// MARK: - Bluetooth Functions
extension BluetoothManager {
    func startScan() {
        peripherals = []
        print("Now Scanning...")
        centralManager.scanForPeripherals(withServices: [BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        //Timer.scheduledTimer(timeInterval: 17, target: self, selector: #selector(stopScan), userInfo: nil, repeats: false)
    }
    
    @objc func stopScan() {
        self.centralManager.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
    }
    
    func disconnectFromDevice () {
        guard let remotePeripheral = remotePeripheral else { return }
        centralManager.cancelPeripheralConnection(remotePeripheral)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            break
        case .resetting:
            break
        case .unsupported:
            break
        case .unauthorized:
            break
        case .poweredOff:
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")
        case .poweredOn:
            startScan()
        @unknown default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        stopScan()
        self.peripherals.append(peripheral)
        centralManager.connect(peripheral, options: nil)
        if remotePeripheral == nil {
            print("We found a new peripheral device with services")
            print("Peripheral name: \(String(describing: peripheral.name))")
            print("**********************************")
            print ("Advertisement Data : \(advertisementData)")
            remotePeripheral = peripheral
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        nc.post(name: .peripheralStateChanged, object: self, userInfo: ["State": true])
        
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(peripheral)")
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral. We got what we came for.
        centralManager.stopScan()
        print("Scan Stopped")
        
        //Discovery callback
        peripheral.delegate = self
        //Only look for services that matches transmit uuid
        peripheral.discoverServices([BLEService_UUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        nc.post(name: .peripheralStateChanged, object: self, userInfo: ["State": false])
        startScan()
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == rxCharacteristic {
            guard let data = characteristic.value else { return }
            guard let value = String(bytes: data, encoding: .utf8) else { return }
            characteristicValue = value
            if value.contains("0") {
                nc.post(name: .buttonStateChanged, object: self, userInfo: ["State": false])
                isButtonPressed = false
            } else {
                if !isButtonPressed {
                    // shoot the bullet
                    nc.post(name: .buttonStateChanged, object: self, userInfo: ["State": true])
                    isButtonPressed = true
                }
                
            }
        }
    }

}

extension Notification.Name {
    static let peripheralStateChanged = Notification.Name("peripheralStateChanged")
    static let buttonStateChanged = Notification.Name("buttonStateChanged")
}
