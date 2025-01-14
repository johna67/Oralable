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

    private var cancellables = Set<AnyCancellable>()
    private var ppgTask: Task<Void, Never>?
    private var accelerometerTask: Task<Void, Never>?

    private var subscribed = false
    private var persistenceWorker = PersistenceWorker()

    private let maxRawDataCount = 500

    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence

    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth

    private let muscleActivityMagnitudeRange: Range<Double> = 100_000.0 ..< 150_000.0
    private let movementRange: Range<Double> = 14000.0 ..< 18000.0

    private var currentMuscleActivityMinute: (date: Date, count: Int)?
    private var currentMovementMinute: (date: Date, count: Int)?

    init() {
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

    private func subscribe(_ device: DeviceService) {
        guard !subscribed else { return }
        subscribed = true
        ppgTask = Task {
            for await ppg in device.ppg {
                let measurement = convert(ppg)
                muscleActivityMagnitude.append(measurement)
                Task {
                    await persistenceWorker.writePPGFrame(ppg)
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

    private func convert(_ frame: some MeasurementConvertible) -> MeasurementData {
        .init(date: frame.timestamp, value: frame.value)
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
