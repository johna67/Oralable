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
    @Injected(\.persistenceService) private var persistence
    
    private var batteryVoltageTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        status = .connecting
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
        
        Task {
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

@MainActor
class BluetoothService: NSObject {
    @Published public var pairedDevice: DeviceDescriptor?
    @Published public var device: DeviceService?
    public var authorized: Bool?
    
    private var manager: CentralManager?
    private var cancellables = Set<AnyCancellable>()
    private var peripheral: Peripheral?
    private var restoreDeviceContinuation: CheckedContinuation<Void, Error>?
    private let connectTimeout = 10.0
    private var connecting = false
    private var restoringState = false
    private var supportedDevices: [DeviceDescriptor] = [DeviceDescriptor(type: .tgm, peripheralId: UUID(), serviceIds: [UUID(uuidString: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")!])]
    
    override init() {
        pairedDevice = BluetoothService.getPersistedPairedDevice()
    }
    
    private static func persistPairedDevice(_ device: DeviceDescriptor?) {
        UserDefaults.standard.set(try? JSONEncoder().encode(device), forKey: "pairedDevice")
    }
    
    private static func getPersistedPairedDevice() -> DeviceDescriptor? {
        guard let json = UserDefaults.standard.object(forKey: "pairedDevice") as? Data else { return nil }
        return try? JSONDecoder().decode(DeviceDescriptor.self, from: json)
    }
    
    private func initializeDevice(type: DeviceType, peripheral: Peripheral) async throws {
        switch type {
        case .tgm:
            device = TGMService(peripheral)
        }
        
        try await device?.start()
        let deviceDescriptor = DeviceDescriptor(type: type, peripheralId: peripheral.identifier, serviceIds: [])
        BluetoothService.persistPairedDevice(deviceDescriptor)
        pairedDevice = deviceDescriptor
    }
    
    private func applyAuthorizationStatus() {
        switch CBManager.authorization {
        case .notDetermined:
            authorized = nil
        case .allowedAlways:
            authorized = true
        default:
            authorized = false
        }
    }
    
    private func subscribeToEvents() {
        guard let manager else {
            Log.error("Cannot subscribe to events, bluetooth manager not initialized")
            return
        }

        manager.eventPublisher.sink { event in
            Log.debug("Received bluetooth event: \(event)")
            switch event {
            case let .didUpdateState(state: state):
                Log.info("Bluetooth state changed to: \(state)")

                self.applyAuthorizationStatus()

                switch state {
                case .poweredOn:
                    Task {
                        await self.poweredOn()
                    }
                default:
                    self.restoreDeviceContinuation?.resume(throwing: BluetoothServiceError(message: "Bluetooth status: \(state)"))
                    self.restoreDeviceContinuation = nil
                }
            case let .didDisconnectPeripheral(peripheral, _, error):
                self.didDisconnect(peripheral: peripheral, error: error)
            case let .willRestoreState(state: state):
                self.restoringState = true

                Task {
                    await self.willRestoreState(state)
                }
            case let .didConnectPeripheral(peripheral: peripheral):
                Log.info("Connected to \(String(describing: peripheral.name))")
            default: break
            }
        }.store(in: &cancellables)
    }
    
    private func restorePairing() async throws {
        guard let manager else {
            throw BluetoothError.bluetoothUnavailable(.unknown)
        }

        guard !restoringState else {
//            restoreDeviceContinuation?.resume()
//            restoreDeviceContinuation = nil
            Log.info("Already restoring device with Bluetooth state restore")
            return
        }

        Log.warn("Did not receive state restore, trying to restore device from persisted state")

        var type: DeviceType?

        if let paired = BluetoothService.getPersistedPairedDevice() {
            type = paired.type
            peripheral = manager.retrievePeripherals(withIdentifiers: [paired.peripheralId]).first
        }

        guard let peripheral, let type else {
            unpair()
            throw BluetoothServiceError(message: "Could not restore device")
        }
        Log.info("\(String(describing: peripheral.name)) (\(peripheral.state)), \(type) restored - trying to connect")
        try await connect(peripheral, type: type)

        restoreDeviceContinuation?.resume()
        restoreDeviceContinuation = nil
    }

    private func initManager() async {
        guard manager == nil else {
            Log.warn("Bluetooth manager already initialized")
            return
        }
        manager = CentralManager(dispatchQueue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: "OralableCentralManagerRestoreIdentifier"
        ])

        do {
            try await withCheckedThrowingContinuation { continuation in
                restoreDeviceContinuation = continuation
                subscribeToEvents()
            }
        } catch {
            Log.info("Failed to restore device")
            device = nil
        }
    }
    
    private func poweredOn() async {
        do {
            try await restorePairing()
        } catch {
            Log.error("Restore pairing failed: \(String(describing: error))")
            if isUnpaired(error) {
                unpair()
            }
            restoreDeviceContinuation?.resume(throwing: error)
            restoreDeviceContinuation = nil
        }
    }

    private func didDisconnect(peripheral: Peripheral, error: Error?) {
        guard let error else {
            Log.warn("Device disconnected with empty error - unpair")
            unpair()
            return
        }

        Log.warn("Peripheral \(peripheral) disconnected, \(String(describing: error))")

        if isUnpaired(error) {
            unpair()
            return
        }

        guard let type = BluetoothService.getPersistedPairedDevice()?.type else {
            Log.error("No device type found")
            return
        }

        device = nil

        reconnect(peripheral, type: type)
    }

    private func willRestoreState(_ state: [String: Any]) async {
        Log.info("Will restore state received, with \(state)")

        guard let cbperipheral = (state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first, let peripheral = manager?.retrievePeripherals(withIdentifiers: [cbperipheral.identifier]).first else {
            Log.error("Could not get peripheral from state")
            unpair()
            return
        }

        self.peripheral = peripheral

        do {
            if let paired = BluetoothService.getPersistedPairedDevice() {
                Log.info("Found persisted device \(paired), connecting")
                try await connect(peripheral, type: paired.type)
            } else {
                Log.warn("Persisted device not found, trying to determine type based on discovered services")
                if let type = deviceType(for: peripheral) {
                    pairedDevice = DeviceDescriptor(type: type, peripheralId: peripheral.identifier, serviceIds: [])
                    try await connect(peripheral, type: type)
                } else {
                    Log.error("Could not restore device")
                    unpair()
                }
            }
            restoreDeviceContinuation?.resume()
        } catch {
            Log.error("Cannot restore state: \(String(describing: error))")
            restoreDeviceContinuation?.resume(throwing: error)
        }
        restoreDeviceContinuation = nil
    }

    private func unpair() {
        Log.warn("Device unpaired, removing from preferences")
        BluetoothService.persistPairedDevice(nil)
        pairedDevice = nil
        device = nil
    }
    
    private func connect(_ peripheral: Peripheral, type: DeviceType, timeout: Bool = true) async throws {
        guard !connecting else {
            Log.warn("Peripheral already connecting")
            return
        }

        connecting = true
        defer { connecting = false }

        try await manager?.waitUntilReady()
        do {
            try await withThrowingTimeout(seconds: timeout ? connectTimeout : nil) {
                Log.info("Connecting device \(type), \(timeout ? "with" : "without") timeout")
                try await self.manager?.connect(peripheral)
            }
            try await withThrowingTimeout(seconds: timeout ? connectTimeout : nil) {
                Log.info("Successfully connected, initializing device")
                try await self.initializeDevice(type: type, peripheral: peripheral)
            }
        } catch {
            Log.error("Could not connect device: \(String(describing: error))")
            if isUnpaired(error) {
                unpair()
            } else {
                reconnect(peripheral, type: type)
            }
            throw error
        }
    }

    private func isUnpaired(_ error: Error) -> Bool {
        let underlyingError = (error as? BluetoothError)?.wrappedError ?? error
        switch underlyingError {
        case CBATTError.insufficientEncryption,
             CBATTError.insufficientAuthentication,
             CBError.peerRemovedPairingInformation:
            return true
        default:
            return false
        }
    }

    private func reconnect(_ peripheral: Peripheral, type: DeviceType) {
        Log.info("Reconnecting to device...")
        Task {
            do {
                try await connect(peripheral, type: type, timeout: false)
            } catch {
                Log.error("Failed to reconnect \(type) device: \(String(describing: error))")
            }
        }
    }

    private func deviceType(for peripheral: Peripheral) -> DeviceType? {
        guard let services = peripheral.discoveredServices else {
            Log.error("No discovered services on device, cannot determine type")
            return nil
        }

        return supportedDevices.first { $0.type.rawValue == peripheral.name }?.type //TODO: this should be based on advertised service not name
    }
    
    func detectDevice(type: DeviceType) async throws {
        Log.info("Attempting to detect device \(type)")
        guard let manager else {
            throw BluetoothServiceError(message: "Bluetooth not initialized")
        }

        guard let device = supportedDevices.first(where: { $0.type == type }) else {
            throw BluetoothServiceError(message: "Device not supported")
        }

        try await withThrowingTimeout(seconds: connectTimeout) {
            try await manager.waitUntilReady()
            let serviceIds = device.serviceIds.map { CBUUID(nsuuid: $0) }
            //let scanDataStream = try await manager.scanForPeripherals(withServices: serviceIds)
            let scanDataStream = try await manager.scanForPeripherals(withServices: nil) //TODO: this should be done based on advertised service
            Log.debug("Will scan for peripheral for \(type) device, with services: \(serviceIds)")
            
            for await scanData in scanDataStream {
                //try await scanData.peripheral.discoverServices(nil)
                if scanData.peripheral.name == type.rawValue {
                    self.peripheral = scanData.peripheral
                    Log.debug("Found peripheral for \(type) device, \(scanData.peripheral.name ?? "") identifier: \(scanData.peripheral.identifier)")
                    break
                }
            }
            await manager.stopScan()
        }
    }

    func pair(type: DeviceType) async throws {
        Log.info("Attempting to pair device \(type)")

        guard let peripheral else {
            throw BluetoothServiceError(message: "Peripheral not yet detected")
        }

        try await connect(peripheral, type: type, timeout: false)
    }

    func disconnectDevice() async throws {
        Log.info("Disconnecting device")
        if let peripheral {
            try await manager?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil

        unpair()
    }
    
    func start() async throws {
        Log.info("Starting bluetooth service")

        applyAuthorizationStatus()

        //if authorized == true {
            Log.info("Bluetooth permissions authorized")
            await initManager()
        //}

        Log.info("Bluetooth service started successfully")
    }
}

private extension BluetoothError {
    var wrappedError: Error? {
        switch self {
        case let .errorConnectingToPeripheral(error):
            return error
        default:
            return nil
        }
    }
}
