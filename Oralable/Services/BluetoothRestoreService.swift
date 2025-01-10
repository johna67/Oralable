//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import CoreBluetooth
import LogKit

class BluetoothRestoreService: NSObject {
    private var peripheral: CBPeripheral?

    private var centralManager: CBCentralManager?
    private var restoreDeviceContinuation: CheckedContinuation<Void, Error>?
    private var restoringState = false

    init(centralManager: CBCentralManager) {
        self.centralManager = centralManager
    }
    
    func restorePeripheral() async -> CBPeripheral? {
        do {
            try await withCheckedThrowingContinuation { continuation in
                centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "OralableCentralManagerRestoreIdentifier"])
                restoreDeviceContinuation = continuation
            }
            return peripheral
        } catch {
            Log.info("Failed to restore device: \(error)")
            return nil
        }
    }
    
    func forgetPeripheral() {
        persistPairedDevice(nil)
        peripheral = nil
    }
    
    private func persistPairedDevice(_ device: DeviceDescriptor?) {
        UserDefaults.standard.set(try? JSONEncoder().encode(device), forKey: "pairedDevice")
    }

    private func getPersistedPairedDevice() -> DeviceDescriptor? {
        guard let json = UserDefaults.standard.object(forKey: "pairedDevice") as? Data else { return nil }
        return try? JSONDecoder().decode(DeviceDescriptor.self, from: json)
    }

    private func restorePairing() async throws {
        Log.warn("Did not receive state restore, trying to restore device from persisted state")

        var type: DeviceType?

        if let paired = getPersistedPairedDevice() {
            type = paired.type
            peripheral = centralManager?.retrievePeripherals(withIdentifiers: [paired.peripheralId]).first
        }

        guard let peripheral, let type else {
            unpair()
            throw BluetoothServiceError(message: "Could not restore device")
        }
        Log.info("\(String(describing: peripheral.name)) (\(peripheral.state)), \(type)")
    }

    private func willRestoreState(_ state: [String: Any]) async throws {
        Log.info("Will restore state received, with \(state)")

        guard let cbperipheral = (state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first, let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [cbperipheral.identifier]).first else {
            Log.error("Could not get peripheral from state")
            unpair()
            throw BluetoothServiceError(message: "Could not restore device state: \(state)")
        }

        self.peripheral = peripheral
    }

    private func unpair() {
        Log.warn("Device unpaired, removing from preferences")
        persistPairedDevice(nil)
        peripheral = nil
    }
}

extension BluetoothRestoreService: @preconcurrency CBCentralManagerDelegate {
    @MainActor
    func centralManagerDidUpdateState(_ centralManager: CBCentralManager) {
        switch centralManager.state {
        case .poweredOn:
            Task {
                guard !restoringState else {
                    Log.info("Already restoring device with Bluetooth state restore")
                    return
                }
                do {
                    try await restorePairing()
                    restoreDeviceContinuation?.resume()
                } catch {
                    restoreDeviceContinuation?.resume(throwing: error)
                }
                
                restoreDeviceContinuation = nil
            }
        default:
            self.restoreDeviceContinuation?.resume(throwing: BluetoothServiceError(message: "Bluetooth status: \(centralManager.state)"))
            self.restoreDeviceContinuation = nil
        }
    }
    
    @MainActor
    func centralManager(_ central: CBCentralManager, willRestoreState state: [String: Any]) {
        restoringState = true
        Task {
            do {
                try await self.willRestoreState(state)
                restoreDeviceContinuation?.resume()
            } catch {
                restoreDeviceContinuation?.resume(throwing: error)
            }
            restoreDeviceContinuation = nil
        }
    }
}
