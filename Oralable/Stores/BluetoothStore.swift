//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import Combine
import Factory
import LogKit

@MainActor
@Observable class BluetoothStore {
    enum ConnectionStatus {
        case connected, connecting, disconnected
    }
    
    var statuses: [UUID: ConnectionStatus] = [:]
    var pairedDevices: [DeviceDescriptor] = []
    var batteryVoltages: [UUID: Int] = [:]
    
    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth
    @ObservationIgnored
    @Injected(\.bluetoothAuthorizationService) private var bluetoothAuthorization
    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence
    
    private var batteryVoltageTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        bluetooth.pairedDevicesPublisher
            .sink { [weak self] descriptors in
                guard let self = self else { return }
                self.pairedDevices = descriptors
                
                for desc in descriptors where self.statuses[desc.peripheralId] == nil {
                    self.statuses[desc.peripheralId] = .connected
                }
            }
            .store(in: &cancellables)
        
        bluetooth.devicesPublisher
            .sink { [weak self] services in
                guard let self = self else { return }
                
                let existingIDs = Set(self.statuses.keys)
                let newIDs = Set(services.map { $0.ID })
                
                for removed in existingIDs.subtracting(newIDs) {
                    self.statuses[removed] = .disconnected
                    self.batteryVoltages.removeValue(forKey: removed)
                    self.batteryVoltageTasks[removed]?.cancel()
                    self.batteryVoltageTasks.removeValue(forKey: removed)
                }
                
                for service in services {
                    let id = service.ID
                    self.statuses[id] = .connected
                    if self.batteryVoltageTasks[id] == nil {
                        self.subscribe(to: service)
                    }
                }
            }
            .store(in: &cancellables)
        
        Task {
            if bluetoothAuthorization.authorized != true {
                await bluetoothAuthorization.authorize()
            }
            do {
                try await bluetooth.start()
            } catch {
                Log.error("Bluetooth error: \(error)")
                for key in statuses.keys {
                    statuses[key] = .disconnected
                }
            }
        }
    }
    
    func addDevice(_ type: DeviceType) async {
        do {
            try await bluetooth.detectDevice(type: type)
            try await bluetooth.pair(type: type)
        } catch {
            Log.error("Error adding device: \(error)")
        }
    }
    
    func removeDevice(_ descriptor: DeviceDescriptor) async {
        do {
            try await bluetooth.disconnectDevice(descriptor: descriptor)
        } catch {
            Log.error("Error removing device: \(error)")
        }
    }
    
    func removeAllDevices() async {
        do {
            try await bluetooth.disconnectAllDevices()
        } catch {
            Log.error("Error removing all devices: \(error)")
        }
    }
    
    private func subscribe(to service: any DeviceService) {
        let id = service.ID
        let task = Task {
            for await voltage in service.batteryVoltage {
                self.batteryVoltages[id] = voltage
            }
        }
        batteryVoltageTasks[id] = task
    }
}
