//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import AsyncBluetooth
import Combine
import CoreBluetooth
import Foundation
import LogKit

protocol DeviceService {
    var name: String { get }
    var type: DeviceType { get }

    var batteryVoltage: AsyncStream<Int> { get }
    var ppg: AsyncStream<PPGFrame> { get }
    var temperature: AsyncStream<Double> { get }
    var accelerometer: AsyncStream<AccelerometerFrame> { get }

    @MainActor
    func start() async throws
}

final class TGMService: DeviceService {
    let type: DeviceType = .tgm
    let name = "TGM"

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
        guard let service = peripheral.discoveredServices?.first(where: { $0.uuid == serviceId }) else {
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
