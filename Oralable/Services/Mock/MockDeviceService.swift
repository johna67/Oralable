//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation

final class MockDeviceService: DeviceService {
    var name = "Mock Device"
    var type: DeviceType
    var ID = UUID()

    // Continuations for the streams
    private var ppgContinuation: AsyncStream<PPGFrame>.Continuation?
    private var accelerometerContinuation: AsyncStream<AccelerometerFrame>.Continuation?
    private var batteryVoltageContinuation: AsyncStream<Int>.Continuation?
    private var temperatureContinuation: AsyncStream<Double>.Continuation?
    private var emgContinuation: AsyncStream<MeasurementData>.Continuation?

    lazy var ppg: AsyncStream<PPGFrame> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.ppgContinuation = continuation
    }

    lazy var accelerometer: AsyncStream<AccelerometerFrame> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.accelerometerContinuation = continuation
    }

    lazy var batteryVoltage: AsyncStream<Int> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.batteryVoltageContinuation = continuation
    }

    lazy var temperature: AsyncStream<Double> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.temperatureContinuation = continuation
    }
    
    lazy var emg: AsyncStream<MeasurementData> = AsyncStream(bufferingPolicy: .unbounded) { continuation in
        self.emgContinuation = continuation
    }

    private var ppgFrameCounter: UInt32 = 33318
    private var accelerometerFrameCounter: UInt32 = 26687
    private let startTime: Date = Date()
    private var timerTask: Task<Void, Never>?

    init(type: DeviceType) {
        self.type = type
    }
    
    @MainActor
    func start() async throws {
        timerTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                let timestamp = Date()

                // Emit PPG frame
                if let ppgContinuation {
                    let isRandom = Int.random(in: 1...100) > 70 // 10% random IR
                    let irValue = isRandom
                        ? Int32.random(in: 160_000...350_000)
                        : 160000

                    let ppgSample = PPGSample(red: 254115, ir: irValue, green: 265105)
                    let frame = PPGFrame(
                        frameCounter: self.ppgFrameCounter,
                        timestamp: timestamp,
                        samples: [ppgSample]
                    )
                    DispatchQueue.main.async {
                        ppgContinuation.yield(frame)
                    }
                    ppgFrameCounter += 1
                }

                // Emit accelerometer frame
                if let accelerometerContinuation, let emgContinuation {
                    let isRandom = Int.random(in: 1...100) > 90 // 10% random sample
                    let sample: AccelerometerSample

                    if isRandom {
                        sample = AccelerometerSample(
                            x: Int16.random(in: -32000...32000),
                            y: Int16.random(in: -32000...32000),
                            z: Int16.random(in: -32000...32000)
                        )
                    } else {
                        sample = AccelerometerSample(x: 112, y: -2548, z: -16024)
                    }

                    let frame = AccelerometerFrame(
                        frameCounter: self.accelerometerFrameCounter,
                        timestamp: timestamp,
                        samples: [sample]
                    )
                    DispatchQueue.main.async {
                        accelerometerContinuation.yield(frame)
                        emgContinuation.yield(frame.convertToDataPoint().convert())
                    }
                    accelerometerFrameCounter += 1
                }
                
                if let temperatureContinuation {
                    temperatureContinuation.yield(37.0)
                }

                // Sleep for 0.4 seconds
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}
