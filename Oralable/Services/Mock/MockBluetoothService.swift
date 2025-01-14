//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import Combine

final class MockBluetoothService: BluetoothService {
    func detectDevice(type: DeviceType) async throws {
    }
    
    var devicePublisher: AnyPublisher<(any DeviceService)?, Never> {
        $device.eraseToAnyPublisher()
    }
    
    var pairedDevicePublisher: AnyPublisher<DeviceDescriptor?, Never> {
        $pairedDevice.eraseToAnyPublisher()
    }
    
    func start() async throws {
        device = MockDeviceService()
        pairedDevice = DeviceDescriptor(type: .tgm, peripheralId: UUID(), serviceIds: [])
        try await device?.start()
    }
    
    func disconnectDevice() async throws {
        device = nil
    }
    
    func pair(type: DeviceType) async throws {
        
    }
    
    nonisolated init() {
        
    }
    
    @Published var pairedDevice: DeviceDescriptor?
    @Published var device: DeviceService?
}
