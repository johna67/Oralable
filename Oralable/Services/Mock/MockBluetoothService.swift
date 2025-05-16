//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import Combine

final class MockBluetoothService: BluetoothService {
    @Published private var devices: [any DeviceService] = []
    @Published private var pairedDevices: [DeviceDescriptor] = []
    
    var devicesPublisher: AnyPublisher<[any DeviceService], Never> {
        $devices.eraseToAnyPublisher()
    }
    
    var pairedDevicesPublisher: AnyPublisher<[DeviceDescriptor], Never> {
        $pairedDevices.eraseToAnyPublisher()
    }
    
    func start() async throws {
        let mock = MockDeviceService(type: .anr)
        try await mock.start()
        devices = [mock]
        let descriptor = DeviceDescriptor(type: .tgm, peripheralId: UUID(), serviceIds: [])
        pairedDevices = [descriptor]
    }
    
    func detectDevice(type: DeviceType) async throws {
        try await Task.sleep(nanoseconds: 500 * 1_000_000)
    }
    
    func pair(type: DeviceType) async throws {
        let mock = MockDeviceService(type: type)
        try await mock.start()
        devices.append(mock)
        let descriptor = DeviceDescriptor(type: type, peripheralId: UUID(), serviceIds: [])
        pairedDevices.append(descriptor)
    }
    
    func disconnectDevice(descriptor: DeviceDescriptor) async throws {
//        devices.removeAll { $0.peripheralId == descriptor.peripheralId }
        pairedDevices.removeAll { $0.peripheralId == descriptor.peripheralId }
    }
    
    func disconnectAllDevices() async throws {
        devices.removeAll()
        pairedDevices.removeAll()
    }
    
    nonisolated init() {}
}
