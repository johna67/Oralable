//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation
import CoreBluetooth
import AsyncBluetooth
import Combine
import LogKit
import Factory

struct BluetoothServiceError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

@MainActor
protocol BluetoothService {
    var devicesPublisher: AnyPublisher<[any DeviceService], Never> { get }
    var pairedDevicesPublisher: AnyPublisher<[DeviceDescriptor], Never> { get }
    
    func start() async throws
    func detectDevice(type: DeviceType) async throws
    func pair(type: DeviceType) async throws
    func disconnectDevice(descriptor: DeviceDescriptor) async throws
    func disconnectAllDevices() async throws
}

final class LiveBluetoothService: BluetoothService {
    @Published private var pairedDevices: [DeviceDescriptor] = LiveBluetoothService.getPersistedPairedDevices()
    @Published private var devices: [any DeviceService] = []
    
    var devicesPublisher: AnyPublisher<[any DeviceService], Never> {
        $devices.eraseToAnyPublisher()
    }
    
    var pairedDevicesPublisher: AnyPublisher<[DeviceDescriptor], Never> {
        $pairedDevices.eraseToAnyPublisher()
    }
    
    private var manager: CentralManager?
    private var cancellables = Set<AnyCancellable>()
    
    private var supportedDevices: [DeviceDescriptor] = [
        DeviceDescriptor( type: .tgm, peripheralId: UUID(), serviceIds: [UUID(uuidString: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")!]),
        DeviceDescriptor( type: .anr, peripheralId: UUID(), serviceIds: [])
    ]
    
    private var detectedPeripherals: [DeviceType: Peripheral] = [:]
    private var connections: [UUID: (descriptor: DeviceDescriptor, peripheral: Peripheral, service: any DeviceService)] = [:]
    
    private let connectTimeout = 15.0
    private var restoringState = false
    
    init() {
        pairedDevices = LiveBluetoothService.getPersistedPairedDevices()
    }
    
    func start() async throws {
        Log.info("Starting bluetooth service")
        await initManager()
        Log.info("Bluetooth service started successfully")
    }
    
    func detectDevice(type: DeviceType) async throws {
        Log.info("Attempting to detect device \(type)")
        guard let manager else {
            throw BluetoothServiceError(message: "Bluetooth not initialized")
        }
        guard let descriptor = supportedDevices.first(where: { $0.type == type }) else {
            throw BluetoothServiceError(message: "Device not supported")
        }
        try await withThrowingTimeout(seconds: connectTimeout) {
            try await manager.waitUntilReady()
            let serviceIds = descriptor.serviceIds.map { CBUUID(nsuuid: $0) }
            let scanDataStream = try await manager.scanForPeripherals(withServices: nil) // TODO: filter by serviceIds
            Log.debug("Scanning for peripheral for \(type), with services: \(serviceIds)")
            for await scanData in scanDataStream {
                Log.debug("Detected: \(scanData.peripheral.name ?? "unknown")")
                if scanData.peripheral.name == type.rawValue {
                    detectedPeripherals[type] = scanData.peripheral
                    Log.debug("Found peripheral for \(type): \(scanData.peripheral.identifier)")
                    break
                }
            }
            await manager.stopScan()
        }
    }
    
    func pair(type: DeviceType) async throws {
        Log.info("Attempting to pair device \(type)")
        guard let peripheral = detectedPeripherals[type] else {
            throw BluetoothServiceError(message: "Peripheral not yet detected")
        }
        try await connect(peripheral, type: type, timeout: false)
    }
    
    func disconnectDevice(descriptor: DeviceDescriptor) async throws {
        Log.info("Disconnecting device \(descriptor)")
        guard let entry = connections[descriptor.peripheralId] else {
            throw BluetoothServiceError(message: "Device not connected")
        }
        try await manager?.cancelPeripheralConnection(entry.peripheral)
        removeConnection(descriptor)
    }
    
    func disconnectAllDevices() async throws {
        Log.info("Disconnecting all devices")
        for (_, entry) in connections {
            try await manager?.cancelPeripheralConnection(entry.peripheral)
        }
        connections.removeAll()
        devices.removeAll()
        pairedDevices.removeAll()
        LiveBluetoothService.persistPairedDevices([])
    }
}

private extension LiveBluetoothService {
    private static func persistPairedDevices(_ devices: [DeviceDescriptor]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(devices), forKey: "pairedDevices")
    }
    
    private static func getPersistedPairedDevices() -> [DeviceDescriptor] {
        guard let data = UserDefaults.standard.data(forKey: "pairedDevices") else { return [] }
        return (try? JSONDecoder().decode([DeviceDescriptor].self, from: data)) ?? []
    }
    
    private func initManager() async {
        guard manager == nil else {
            Log.warn("Bluetooth manager already initialized")
            return
        }
        manager = CentralManager(
            dispatchQueue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                CBCentralManagerOptionRestoreIdentifierKey: "OralableCentralManagerRestoreIdentifier"
            ]
        )
        subscribeToEvents()
    }
    
    private func updatePublishers() {
        devices = connections.values.map { $0.service }
        pairedDevices = connections.values.map { $0.descriptor }
        LiveBluetoothService.persistPairedDevices(pairedDevices)
    }
    
    private func removeConnection(_ descriptor: DeviceDescriptor) {
        connections[descriptor.peripheralId] = nil
        updatePublishers()
    }
    
    private func initializeDevice(type: DeviceType, peripheral: Peripheral) async throws {
        let service: any DeviceService
        switch type {
        case .tgm:
            service = TGMService(peripheral)
        case .anr:
            service = ANRService(peripheral)
        }
        try await service.start()
        let deviceDescriptor = DeviceDescriptor(type: type, peripheralId: peripheral.identifier, serviceIds: [])
        connections[peripheral.identifier] = (descriptor: deviceDescriptor, peripheral: peripheral, service: service)
        updatePublishers()
    }
    
    private func connect(_ peripheral: Peripheral, type: DeviceType, timeout: Bool = true) async throws {
        try await manager?.waitUntilReady()
        do {
            try await withThrowingTimeout(seconds: timeout ? connectTimeout : nil) {
                Log.info("Connecting device \(type) \(timeout ? "with" : "without") timeout")
                try await manager?.connect(peripheral)
            }
            try await withThrowingTimeout(seconds: timeout ? connectTimeout : nil) {
                Log.info("Connected: initializing device")
                try await initializeDevice(type: type, peripheral: peripheral)
            }
        } catch {
            Log.error("Connection failed for \(type): \(error)")
            if isUnpaired(error) {
                removeConnection(DeviceDescriptor(type: type, peripheralId: peripheral.identifier, serviceIds: []))
            } else {
                reconnect(peripheral, type: type)
            }
            throw error
        }
    }
    
    private func subscribeToEvents() {
        guard let manager else {
            Log.error("Bluetooth manager not initialized")
            return
        }
        manager.eventPublisher.sink { [weak self] event in
            guard let self = self else { return }
            Log.debug("Bluetooth event: \(event)")
            switch event {
            case let .didUpdateState(state):
                if state == .poweredOn {
                    Task { await self.poweredOn() }
                }
            case let .didDisconnectPeripheral(peripheral, _, error):
                self.handleDisconnect(peripheral: peripheral, error: error)
            case let .willRestoreState(state):
                self.restoringState = true
                Task { await self.handleRestoreState(state) }
            default:
                break
            }
        }.store(in: &cancellables)
    }
    
    private func poweredOn() async {
        guard !restoringState else { return }
        do {
            try await restorePairing()
        } catch {
            Log.error("Restore pairing failed: \(error)")
        }
    }
    
    private func restorePairing() async throws {
        guard let manager else { throw BluetoothError.bluetoothUnavailable(.unknown) }
        let persisted = LiveBluetoothService.getPersistedPairedDevices()
        for descriptor in persisted {
            if let peripheral = manager.retrievePeripherals(withIdentifiers: [descriptor.peripheralId]).first {
                try await connect(peripheral, type: descriptor.type)
            } else {
                Log.error("Could not restore peripheral \(descriptor.peripheralId)")
            }
        }
    }
    
    private func handleDisconnect(peripheral: Peripheral, error: Error?) {
        if let err = error {
            Log.warn("Peripheral \(peripheral) disconnected: \(err)")
            if isUnpaired(err) {
                if let entry = connections[peripheral.identifier] {
                    removeConnection(entry.descriptor)
                }
            } else if let entry = connections[peripheral.identifier] {
                connections[peripheral.identifier] = nil
                updatePublishers()
                reconnect(peripheral, type: entry.descriptor.type)
            }
        } else {
            Log.warn("Peripheral disconnected without error")
            if let entry = connections[peripheral.identifier] {
                removeConnection(entry.descriptor)
            }
        }
    }
    
    private func handleRestoreState(_ state: [String: Any]) async {
        guard let cbPeripherals = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else {
            Log.error("No peripherals to restore")
            return
        }
        for cb in cbPeripherals {
            if let peripheral = manager?.retrievePeripherals(withIdentifiers: [cb.identifier]).first {
                if let descriptor = LiveBluetoothService.getPersistedPairedDevices().first(where: { $0.peripheralId == cb.identifier }) {
                    try? await connect(peripheral, type: descriptor.type)
                } else if let type = deviceType(for: peripheral) {
                    try? await connect(peripheral, type: type)
                }
            }
        }
    }
    
    private func isUnpaired(_ error: Error) -> Bool {
        let underlying = (error as? BluetoothError)?.wrappedError ?? error
        switch underlying {
        case CBATTError.insufficientEncryption,
             CBATTError.insufficientAuthentication,
             CBError.peerRemovedPairingInformation:
            return true
        default:
            return false
        }
    }
    
    private func reconnect(_ peripheral: Peripheral, type: DeviceType) {
        Task {
            do {
                try await connect(peripheral, type: type, timeout: false)
            } catch {
                Log.error("Reconnection failed for \(type): \(error)")
            }
        }
    }
    
    private func deviceType(for peripheral: Peripheral) -> DeviceType? {
        supportedDevices.first { $0.type.rawValue == peripheral.name }?.type
    }
}

private extension BluetoothError {
    var wrappedError: Error? {
        if case let .errorConnectingToPeripheral(err) = self {
            return err
        }
        return nil
    }
}
