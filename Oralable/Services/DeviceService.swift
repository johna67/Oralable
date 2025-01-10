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

    func start() async throws
}

struct PPGSample {
    let red: Int32
    let ir: Int32
    let green: Int32
}

struct PPGFrame {
    let frameCounter: UInt32
    let timestamp: Date
    let avgSample: PPGSample
}

struct AccelerometerSample {
    let x: Int16
    let y: Int16
    let z: Int16

    func magnitude() -> Double {
        sqrt(Double(x) * Double(x) + Double(y) * Double(y) + Double(z) * Double(z))
    }
}

struct AccelerometerFrame {
    let frameCounter: UInt32
    let timestamp: Date
    let maxSample: AccelerometerSample
}

class TGMService: DeviceService {
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
                try await peripheral.setNotifyValue(true, for: characteristic)
            case batteryId:
                batteryCharacteristic = characteristic
                try await peripheral.setNotifyValue(true, for: characteristic)
            default:
                Log.info("Skipping characteristic \(characteristic.uuid)")
            }
        }

        Log.info("Testing if data can be read from TGM")

        try await parseBatteryData(readData(for: batteryCharacteristic))

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
        guard let data, data.count > 4 else {
            throw BluetoothServiceError(message: "Cannot read PPG data")
        }

        let frameCounter = data[0 ..< 4].withUnsafeBytes { $0.load(as: UInt32.self) }
        let sampleSize = 12
        var sampleCount: Int32 = 0

        var offset = 4
        var totalRed: Int32 = 0
        var totalIr: Int32 = 0
        var totalGreen: Int32 = 0

        // Start reading samples after the frame counter (byte 4 onward)
        while offset + sampleSize <= data.count {
            totalRed += data[offset ..< (offset + 4)].withUnsafeBytes { $0.load(as: Int32.self) }
            totalIr += data[(offset + 4) ..< (offset + 8)].withUnsafeBytes { $0.load(as: Int32.self) }
            totalGreen += data[(offset + 8) ..< (offset + 12)].withUnsafeBytes { $0.load(as: Int32.self) }

            offset += sampleSize
            sampleCount += 1
        }

        guard sampleCount > 0 else { return }

        let avgSample = PPGSample(red: totalRed / sampleCount, ir: totalIr / sampleCount, green: totalGreen / sampleCount)
        let frame = PPGFrame(frameCounter: frameCounter, timestamp: Date(), avgSample: avgSample)

        ppgContinuation?.yield(frame)
    }

    private func parseAccelerometerData(_ data: Data?) throws {
        guard let data, data.count > 4 else {
            throw BluetoothServiceError(message: "Cannot read accelerometer data")
        }

        let frameCounter = data[0 ..< 4].withUnsafeBytes { $0.load(as: UInt32.self) }
        let sampleSize = 6
        var sampleCount = 0

//        var totalX: Int = 0
//        var totalY: Int = 0
//        var totalZ: Int = 0
        var maxMagnitude = 0.0
        var maxVector: (x: Int16, y: Int16, z: Int16) = (0, 0, 0)

        // Start reading samples after the frame counter (byte 4 onward)
        var offset = 4
        while offset + sampleSize <= data.count {
            let x = Int16(littleEndian: data[offset ..< (offset + 2)].withUnsafeBytes { $0.load(as: Int16.self) })
            let y = Int16(littleEndian: data[(offset + 2) ..< (offset + 4)].withUnsafeBytes { $0.load(as: Int16.self) })
            let z = Int16(littleEndian: data[(offset + 4) ..< (offset + 6)].withUnsafeBytes { $0.load(as: Int16.self) })

            let magnitude = sqrt(Double(x) * Double(x) + Double(y) * Double(y) + Double(z) * Double(z))

            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                maxVector = (x, y, z)
            }

            offset += sampleSize
            sampleCount += 1
        }

        guard sampleCount > 0 else { return }

        let maxSample = AccelerometerSample(x: maxVector.x, y: maxVector.y, z: maxVector.z)
        let frame = AccelerometerFrame(frameCounter: frameCounter, timestamp: Date(), maxSample: maxSample)

        accelerometerContinuation?.yield(frame)
    }

    private func parseTemperatureData(_ data: Data?) throws {
        guard let data else {
            throw BluetoothServiceError(message: "Cannot read temperature data")
        }
    }

    private func parseBatteryData(_ data: Data?) throws {
        guard let data else {
            throw BluetoothServiceError(message: "Cannot read battery data")
        }

        let battery = Int(data.withUnsafeBytes {
            $0.load(as: UInt16.self)
        })

        lastBatteryVoltage = battery
        batteryVoltageContinuation?.yield(battery)

        Log.debug("Battery: \(battery)")
    }

    private func readData(for characteristic: Characteristic?) async throws -> Data? {
        guard let characteristic else {
            throw BluetoothServiceError(message: "Cannot read data, characteristic not found")
        }

        try await peripheral.readValue(for: characteristic)
        return characteristic.value
    }
}
