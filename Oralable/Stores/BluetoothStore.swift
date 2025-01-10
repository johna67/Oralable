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

    var status = ConnectionStatus.disconnected
    var pairedDevice: DeviceDescriptor?
    var battery: Int?

    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth
    
    @ObservationIgnored
    @Injected(\.bluetoothAuthorizationService) private var bluetoothAuthorization

    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence

    private var batteryVoltageTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        status = .connecting
        
        Task {
            if bluetoothAuthorization.authorized != true {
                await bluetoothAuthorization.authorize()
            }
            
            bluetooth.$device.sink { device in
                if let device {
                    self.status = .connected
                    self.subscribe(device)
                } else {
                    self.status = .disconnected
                }
            }.store(in: &cancellables)

            bluetooth.$pairedDevice.sink { pairedDevice in
                self.pairedDevice = pairedDevice
            }.store(in: &cancellables)

            do {
                try await bluetooth.start()
            } catch {
                Log.error("Bluetooth error: \(error)")
                status = .disconnected
            }
        }
    }

    func addDevice(_ type: DeviceType) async {
        guard bluetooth.device?.type != type else {
            Log.info("Device already added")
            return
        }

        do {
            status = .connecting
            try await bluetooth.detectDevice(type: type)
            try await bluetooth.pair(type: type)
            status = .connected
        } catch {
            Log.error("Error adding device: \(error)")
            status = .disconnected
        }
    }

    private func subscribe(_ device: DeviceService) {
        batteryVoltageTask = Task {
            for await battery in device.batteryVoltage {
                self.battery = battery
            }
        }
    }
}
