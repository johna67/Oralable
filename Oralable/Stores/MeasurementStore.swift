//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Combine
import Factory
import Foundation
import LogKit

private actor PersistenceWorker {
    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence

    func writeAccelerometerFrame(_ frame: AccelerometerFrame) {
        persistence.writeAccelerometerFrame(frame)
    }

    func writePPGFrame(_ frame: PPGFrame) {
        persistence.writePPGFrame(frame)
    }
}

@MainActor
@Observable final class MeasurementStore {
    var muscleActivityMagnitude = [MeasurementData]()
    var movement = [MeasurementData]()
    
    var muscleActivityNormalRange: ClosedRange<Double>?
    
    var calibrating: Bool {
        muscleActivityNormalRange == nil
    }
    
    var thresholdPercentage: Double {
        didSet {
            UserDefaults.standard.set(thresholdPercentage, forKey: "thresholdPercentage")
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var ppgTask: Task<Void, Never>?
    private var accelerometerTask: Task<Void, Never>?

    private var subscribed = false
    private var persistenceWorker = PersistenceWorker()

    private let ppgCalibrationFrameCount = 50
    private var ppgFrameReceivedSinceCalibrate = 0

    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence

    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth

    private var currentMuscleActivityMinute: (date: Date, count: Int)?
    private var currentMovementMinute: (date: Date, count: Int)?

    init() {
        thresholdPercentage = UserDefaults.standard.double(forKey: "thresholdPercentage")
        if thresholdPercentage == 0 {
            thresholdPercentage = 0.2
        }
        
        muscleActivityMagnitude = persistence.readPPGFrames(limit: nil).map { convert($0) }
        movement = persistence.readAccelerometerFrames(limit: nil).map { convert($0) }
        
        bluetooth.devicePublisher.sink { device in
            if let device {
                self.subscribe(device)
            }
        }.store(in: &cancellables)
    }
    
    func exportToFile() -> URL? {
        do {
            let combinedData: [String: [MeasurementData]] = [
                "muscleActivityMagnitude": muscleActivityMagnitude,
                "movement": movement
            ]
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(combinedData)
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Oralable.json")
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            Log.error("Error saving combined data to file: \(error)")
            return nil
        }
    }
    
    func calibrate() {
        muscleActivityNormalRange = nil
        ppgFrameReceivedSinceCalibrate = 0
    }

    private func subscribe(_ device: DeviceService) {
        guard !subscribed else { return }
        subscribed = true
        ppgTask = Task {
            for await ppg in device.ppg {
                let measurement = convert(ppg, threshold: muscleActivityNormalRange)
                muscleActivityMagnitude.append(measurement)
                
                ppgFrameReceivedSinceCalibrate += 1
                if calibrating, ppgFrameReceivedSinceCalibrate >= ppgCalibrationFrameCount,
                    let range = muscleActivityMagnitude.suffix(ppgCalibrationFrameCount).range(by: { a, b in
                        a.value < b.value
                    }) {
                    muscleActivityNormalRange = (range.min.value / 1 + thresholdPercentage)...(range.max.value * (1 + thresholdPercentage))
                    }
                Task {
                    if !calibrating {
                        await persistenceWorker.writePPGFrame(ppg)
                    }
                }
            }
        }

        accelerometerTask = Task {
            for await accelerometer in device.accelerometer {
                let measurement = convert(accelerometer)
                movement.append(measurement)
                Task {
                    await persistenceWorker.writeAccelerometerFrame(accelerometer)
                }
            }
        }
    }

    private func processMeasurement(frame: some MeasurementConvertible, range: Range<Double>, currentMinute: inout (date: Date, count: Int)?, summary: inout [SummaryData]) {
        let value = frame.value
        let currentMinuteStart = floorToMinute(frame.timestamp)

        if !range.contains(value) {
            if let current = currentMinute {
                if current.date == currentMinuteStart {
                    currentMinute?.count += 1
                } else {
                    summary.append(SummaryData(date: current.date, value: current.count))
                    currentMinute = (date: currentMinuteStart, count: 1)
                }
            } else {
                currentMinute = (date: currentMinuteStart, count: 1)
            }
        }
    }

    private func floorToMinute(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .minute, for: date)?.start ?? date
    }

    private func convert(_ frame: some MeasurementConvertible, threshold: ClosedRange<Double>? = nil) -> MeasurementData {
        if let threshold {
            return .init(date: frame.timestamp, value: frame.value, belowThreshold: frame.value < threshold.lowerBound, aboveThreshold: frame.value > threshold.upperBound, calibrated: true)
        }
        return .init(date: frame.timestamp, value: frame.value, belowThreshold: false, aboveThreshold: false, calibrated: false)
    }
}

protocol MeasurementConvertible {
    var timestamp: Date { get }
    var value: Double { get }
}

extension PPGFrame: MeasurementConvertible {
    var value: Double {
        Double(avgSample.ir)
    }
}

extension AccelerometerFrame: MeasurementConvertible {
    var value: Double {
        maxSample.magnitude()
    }
}
