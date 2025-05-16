//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import AsyncBluetooth
import Combine
import CoreBluetooth
import Foundation
import LogKit

private extension Peripheral {
    func service(_ uuid: CBUUID) -> Service? {
        discoveredServices?.first(where: { $0.uuid == uuid })
    }
}

private extension Service {
    func characteristic(_ uuid: CBUUID) -> Characteristic? {
        discoveredCharacteristics?.first(where: { $0.uuid == uuid })
    }
}

protocol DeviceService {
    var ID: UUID { get }
    var name: String { get }
    var type: DeviceType { get }

    var batteryVoltage: AsyncStream<Int> { get }
    var ppg: AsyncStream<PPGFrame> { get }
    var temperature: AsyncStream<Double> { get }
    var accelerometer: AsyncStream<AccelerometerFrame> { get }
    var emg: AsyncStream<MeasurementData> { get }

    @MainActor
    func start() async throws
}

final class ANRService: DeviceService {
    let type: DeviceType = .anr
    let name = "ANR M40"
    var ID: UUID { return peripheral.identifier }
    
    lazy var emg: AsyncStream<MeasurementData> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.emgCont = continuation
    }
    
    lazy var batteryVoltage: AsyncStream<Int> = AsyncStream(bufferingPolicy: .unbounded) {
        self.batteryCont = $0
        if let lastBattery { $0.yield(lastBattery) }
    }

    lazy var ppg: AsyncStream<PPGFrame>           = .init { _ in }
    lazy var accelerometer: AsyncStream<AccelerometerFrame> = .init { _ in }
    lazy var temperature: AsyncStream<Double>    = .init { _ in }

    struct DeviceInfo: Equatable, Sendable {
        let model, serial, firmware, hardware, software: String
    }

    let deviceInfoPublisher: AnyPublisher<DeviceInfo, Never>
    private let deviceInfoSubject = PassthroughSubject<DeviceInfo, Never>()

    private enum UUIDs {
        // Services
        static let automationIO = CBUUID(string: "1815")
        static let battery = CBUUID(string: "180F")
        static let deviceInfo = CBUUID(string: "180A")

        // Characteristics
        static let analogEMG = CBUUID(string: "2A58")
        static let digitalColor = CBUUID(string: "2A56")
        static let batteryLevel = CBUUID(string: "2A19")

        // Device Information chars
        static let modelNumber = CBUUID(string: "2A24")
        static let serialNumber = CBUUID(string: "2A25")
        static let firmwareRevision = CBUUID(string: "2A26")
        static let hardwareRevision = CBUUID(string: "2A27")
        static let softwareRevision = CBUUID(string: "2A28")
    }

    private let peripheral: Peripheral
    private let colorID: UInt8

    private var analogChar: Characteristic?
    private var digitalChar: Characteristic?
    private var batteryChar: Characteristic?

    private var emgCont: AsyncStream<MeasurementData>.Continuation?
    private var batteryCont: AsyncStream<Int>.Continuation?
    private var lastBattery: Int?

    private var cancellables = Set<AnyCancellable>()

    init(_ peripheral: Peripheral, colorID: UInt8 = 1) {
        precondition((1...24).contains(colorID), "colorID must be 1…24")
        self.peripheral = peripheral
        self.colorID = colorID
        self.deviceInfoPublisher = deviceInfoSubject.eraseToAnyPublisher()
    }
    
    @MainActor
    func start() async throws {
        Log.info("Starting ANR M40 service (colour \(colorID))")

        try await peripheral.discoverServices(nil)

        guard let aioService = peripheral.service(UUIDs.automationIO) else {
            throw BluetoothServiceError(message: "Automation IO service missing")
        }

        let battService = peripheral.service(UUIDs.battery)
        let infoService = peripheral.service(UUIDs.deviceInfo)

        try await peripheral.discoverCharacteristics([UUIDs.analogEMG, UUIDs.digitalColor], for: aioService)

        if let battService {
            try? await peripheral.discoverCharacteristics([UUIDs.batteryLevel], for: battService)
        }
        if let infoService {
            try? await peripheral.discoverCharacteristics([UUIDs.modelNumber, UUIDs.serialNumber, UUIDs.firmwareRevision, UUIDs.hardwareRevision, UUIDs.softwareRevision], for: infoService)
        }

        guard let analogChar  = aioService.characteristic(UUIDs.analogEMG), let digitalChar = aioService.characteristic(UUIDs.digitalColor) else {
            throw BluetoothServiceError(message: "Mandatory characteristics missing")
        }
        self.analogChar  = analogChar
        self.digitalChar = digitalChar

        batteryChar = battService?.characteristic(UUIDs.batteryLevel)

        try await peripheral.writeValue(Data([colorID]), for: digitalChar, type: .withResponse)

        if let infoService {
            try? await readDeviceInfo(from: infoService)
        }

        subscribeValueUpdates()
        try await peripheral.setNotifyValue(true, for: analogChar)
        
        if let batteryChar {
            try? await peripheral.setNotifyValue(true, for: batteryChar)
            if let data = try? await read(for: batteryChar) {
                try? parseBattery(data)
            }
        }

        Log.info("ANR M40 service ready")
    }

    @MainActor
    private func readDeviceInfo(from service: Service) async throws {
        func readString(uuid: CBUUID) async throws -> String {
            guard let ch = service.characteristic(uuid) else {
                throw BluetoothServiceError(message: "Missing \(uuid)")
            }
            guard let data = try await read(for: ch),
                  let s = String(data: data, encoding: .utf8) else {
                throw BluetoothServiceError(message: "Bad string for \(uuid)")
            }
            return s
        }

        let info = try await DeviceInfo(
            model: readString(uuid: UUIDs.modelNumber),
            serial: readString(uuid: UUIDs.serialNumber),
            firmware: readString(uuid: UUIDs.firmwareRevision),
            hardware: readString(uuid: UUIDs.hardwareRevision),
            software: readString(uuid: UUIDs.softwareRevision)
        )
        deviceInfoSubject.send(info)

        Log.debug("DeviceInfo: \(info)")
    }

    private func subscribeValueUpdates() {
        peripheral.characteristicValueUpdatedPublisher
            .sink { [weak self] evt in
                guard let self else { return }
                do {
                    switch evt.characteristic.uuid {
                    case UUIDs.analogEMG:
                        try self.parseEMG(evt.value)
                    case UUIDs.batteryLevel:
                        try self.parseBattery(evt.value)
                    default: break
                    }
                } catch {
                    Log.error("Parse error: \(error)")
                }
            }
            .store(in: &cancellables)
    }

    private func parseEMG(_ data: Data?) throws {
        guard let data, data.count >= 2 else {
            throw BluetoothServiceError(message: "EMG packet too short")
        }
        let value = UInt16(littleEndian: data.withUnsafeBytes { $0.load(as: UInt16.self) })
        emgCont?.yield(MeasurementData(date: Date.now, value: Double(value)))
    }

    private func parseBattery(_ data: Data?) throws {
        guard let data, data.count >= 1 else {
            throw BluetoothServiceError(message: "Battery packet too short")
        }
        let pct = Int(data.withUnsafeBytes { $0.load(as: UInt8.self) })
        lastBattery = pct
        batteryCont?.yield(pct)
    }

    @MainActor
    private func read(for ch: Characteristic?) async throws -> Data? {
        guard let ch else { return nil }
        try await peripheral.readValue(for: ch)
        return ch.value
    }
}

final class TGMService: DeviceService {
    let type: DeviceType = .tgm
    let name = "TGM"
    var ID: UUID { return peripheral.identifier }
    
    lazy var batteryVoltage: AsyncStream<Int> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.batteryVoltageContinuation = continuation
        if let lastBatteryVoltage {
            continuation.yield(lastBatteryVoltage)
        }
    }

    lazy var ppg: AsyncStream<PPGFrame> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.ppgContinuation = continuation
    }

    lazy var accelerometer: AsyncStream<AccelerometerFrame> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.accelerometerContinuation = continuation
    }

    lazy var temperature: AsyncStream<Double> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.temperatureContinuation = continuation
    }
    
    var emg: AsyncStream<MeasurementData> = AsyncStream<MeasurementData> { _ in }

    private let peripheral: Peripheral

    private let serviceId = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")

    private let ppgId = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
    private let accelerometerId = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
    private let temperatureId = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
    private let batteryId = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")

    private var ppgCharacteristic: Characteristic?
    private var accelerometerCharacteristic: Characteristic?
    private var temperatureCharacteristic: Characteristic?
    private var batteryCharacteristic: Characteristic?

    private var batteryVoltageContinuation: AsyncStream<Int>.Continuation?
    private var ppgContinuation: AsyncStream<PPGFrame>.Continuation?
    private var accelerometerContinuation: AsyncStream<AccelerometerFrame>.Continuation?
    private var temperatureContinuation: AsyncStream<Double>.Continuation?

    private var lastBatteryVoltage: Int?

    private var cancellables = Set<AnyCancellable>()

    init(_ peripheral: Peripheral) {
        self.peripheral = peripheral
    }

    func start() async throws {
        Log.info("Starting TGM device")

        try await peripheral.discoverServices([serviceId])
        guard let service = peripheral.service(serviceId) else {
            throw BluetoothServiceError(message: "Primary service \(serviceId) not found")
        }

        Log.info("Successfully discovered primary service: \(service.uuid)")

        try await peripheral.discoverCharacteristics(nil, for: service)
        guard let characteristics = service.discoveredCharacteristics else {
            throw BluetoothServiceError(message: "Characteristics not found")
        }

        Log.info("Successfully discovered characteristics.")

        subscribe()

        for characteristic in characteristics {
            switch characteristic.uuid {
            case ppgId:
                ppgCharacteristic = characteristic
                try await peripheral.setNotifyValue(true, for: characteristic)
            case accelerometerId:
                accelerometerCharacteristic = characteristic
                try await peripheral.setNotifyValue(true, for: characteristic)
            case temperatureId:
                temperatureCharacteristic = characteristic
                do {
                    let tempData = try await readData(for: temperatureCharacteristic)
                    try parseTemperatureData(tempData)
                } catch {
                    Log.warn("Failed to read temperature: \(error)")
                }
                
                try await peripheral.setNotifyValue(true, for: characteristic)
            case batteryId:
                batteryCharacteristic = characteristic
                do {
                    let batteryData = try await readData(for: batteryCharacteristic)
                    try parseBatteryData(batteryData)
                } catch {
                    Log.warn("Failed to read battery: \(error)")
                }
                try await peripheral.setNotifyValue(true, for: characteristic)
            default:
                Log.info("Skipping characteristic \(characteristic.uuid)")
            }
        }

        Log.info("Started TGM device successfully.")
    }

    private func subscribe() {
        peripheral.characteristicValueUpdatedPublisher.sink { eventData in
            do {
                switch eventData.characteristic.uuid {
                case self.ppgId:
                    try self.parsePPGData(eventData.value)
                case self.accelerometerId:
                    try self.parseAccelerometerData(eventData.value)
                case self.temperatureId:
                    try self.parseTemperatureData(eventData.value)
                case self.batteryId:
                    try self.parseBatteryData(eventData.value)
                default:
                    Log.error("Unknown characteristic")
                }
            } catch {
                Log.error(String(describing: error))
            }
        }.store(in: &cancellables)
    }

    private func parsePPGData(_ data: Data?) throws {
        guard let data, data.count >= 4 else {
            throw BluetoothServiceError(message: "Incomplete PPG data")
        }

        let frameCounter = data[0 ..< 4].withUnsafeBytes { $0.load(as: UInt32.self) }
        let sampleSize = 12

        var offset = 4
        var samples = [PPGSample]()

        // Start reading samples after the frame counter (byte 4 onward)
        while offset + sampleSize <= data.count {
            let red = data[offset ..< (offset + 4)].withUnsafeBytes { $0.load(as: Int32.self) }
            let ir = data[(offset + 4) ..< (offset + 8)].withUnsafeBytes { $0.load(as: Int32.self) }
            let green = data[(offset + 8) ..< (offset + 12)].withUnsafeBytes { $0.load(as: Int32.self) }
            
            samples.append(PPGSample(red: red, ir: ir, green: green))

            offset += sampleSize
        }

        let frame = PPGFrame(frameCounter: frameCounter, timestamp: Date(), samples: samples)

        ppgContinuation?.yield(frame)
    }

    private func parseAccelerometerData(_ data: Data?) throws {
        guard let data, data.count >= 4 else {
            throw BluetoothServiceError(message: "Incomplete accelerometer data")
        }

        let frameCounter = data[0 ..< 4].withUnsafeBytes { $0.load(as: UInt32.self) }
        let sampleSize = 6
        var samples = [AccelerometerSample]()
        
        var offset = 4
        
        // Start reading samples after the frame counter (byte 4 onward)
        while offset + sampleSize <= data.count {
            let x = Int16(littleEndian: data[offset ..< (offset + 2)].withUnsafeBytes { $0.load(as: Int16.self) })
            let y = Int16(littleEndian: data[(offset + 2) ..< (offset + 4)].withUnsafeBytes { $0.load(as: Int16.self) })
            let z = Int16(littleEndian: data[(offset + 4) ..< (offset + 6)].withUnsafeBytes { $0.load(as: Int16.self) })
            
            samples.append(AccelerometerSample(x: x, y: y, z: z))

            offset += sampleSize
        }

        let frame = AccelerometerFrame(frameCounter: frameCounter, timestamp: Date(), samples: samples)

        accelerometerContinuation?.yield(frame)
    }

    private func parseTemperatureData(_ data: Data?) throws {
        guard let data, data.count >= 6 else {
            throw BluetoothServiceError(message: "Incomplete temperature data")
        }
        
        let temp = Int(data[4..<6].withUnsafeBytes {
            $0.load(as: Int16.self)
        })
        
        temperatureContinuation?.yield(Double(temp) / 100.0)
    }

    private func parseBatteryData(_ data: Data?) throws {
        guard let data else {
            throw BluetoothServiceError(message: "Incomplete battery data")
        }

        let battery = Int(data.withUnsafeBytes {
            $0.load(as: UInt16.self)
        })

        lastBatteryVoltage = battery
        batteryVoltageContinuation?.yield(battery)

        Log.debug("Battery: \(battery)")
    }

    @MainActor
    private func readData(for characteristic: Characteristic?) async throws -> Data? {
        guard let characteristic else {
            throw BluetoothServiceError(message: "Cannot read data, characteristic not found")
        }

        try await peripheral.readValue(for: characteristic)
        return characteristic.value
    }
}
