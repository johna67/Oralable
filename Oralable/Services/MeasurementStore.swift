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

// class MeasurementSummarizer {
//    private var currentMinute: SummaryData?
//    private var summary = [SummaryData]()
//    private let range: Range<Double>
//
//    init(range: Range<Double>) {
//        self.range = range
//    }
//
//    func addMeasurement(_ measurement: MeasurementData) -> [SummaryData] {
//        let value = measurement.value
//        let timestamp = measurement.date
//        let currentMinuteStart = floorToMinute(timestamp)
//        if currentMinute == nil {
//            currentMinute = SummaryData(date: currentMinuteStart, value: 0)
//        }
//
//        // Finalize the current minute if it has changed
//        if let current = currentMinute, current.date != currentMinuteStart {
//            summary.append(SummaryData(date: current.date, value: current.value))
//            currentMinute = nil
//        }
//
//        // Add the new measurement to the current minute
//        if !range.contains(value) {
//            currentMinute?.value += 1
//        }
//
//        return summary
//    }
//
//    private func floorToMinute(_ date: Date) -> Date {
//        let calendar = Calendar.current
//        return calendar.dateInterval(of: .minute, for: date)?.start ?? date
//    }
// }

@MainActor
@Observable final class MeasurementStore {
    var muscleActivityMagnitude = [MeasurementData]()
    var movement = [MeasurementData]()

//    var muscleActivityMagnitudeSummary = [SummaryData]()
//    var movementSummary = [SummaryData]()

    private var cancellables = Set<AnyCancellable>()
    private var ppgTask: Task<Void, Never>?
    private var accelerometerTask: Task<Void, Never>?

    private var subscribed = false
    private var persistenceWorker = PersistenceWorker()

    private let maxRawDataCount = 500

//    private var movementSummarizer = MeasurementSummarizer(range: 14000.0..<18000.0)
//    private var muscleActivitySummarizer = MeasurementSummarizer(range: 100000.0..<150000.0)

    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence

    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth

    private let muscleActivityMagnitudeRange: Range<Double> = 100_000.0 ..< 150_000.0
    private let movementRange: Range<Double> = 14000.0 ..< 18000.0

    private var currentMuscleActivityMinute: (date: Date, count: Int)?
    private var currentMovementMinute: (date: Date, count: Int)?

    init() {
        muscleActivityMagnitude = persistence.readPPGFrames(limit: 500).map { convert($0) }
        movement = persistence.readAccelerometerFrames(limit: 500).map { convert($0) }

//        for frames in muscleActivityMagnitude {
//            muscleActivityMagnitudeSummary = muscleActivitySummarizer.addMeasurement(frames)
//        }
//
//        for frames in movement {
//            movementSummary = movementSummarizer.addMeasurement(frames)
//        }

        bluetooth.$device.sink { device in
            if let device {
                self.subscribe(device)
            }
        }.store(in: &cancellables)
    }

    private func appendAndLimit(_ element: MeasurementData, to array: inout [MeasurementData]) {
        array.append(element)
        if array.count > maxRawDataCount {
            array.removeFirst()
        }
    }

    private func subscribe(_ device: DeviceService) {
        guard !subscribed else { return }
        subscribed = true
        ppgTask = Task {
            for await ppg in device.ppg {
                appendAndLimit(convert(ppg), to: &muscleActivityMagnitude)
//                processMeasurement(frame: ppg, range: muscleActivityMagnitudeRange, currentMinute: &currentMuscleActivityMinute, summary: &muscleActivityMagnitudeSummary)
                Task {
                    await persistenceWorker.writePPGFrame(ppg)
                }
            }
        }

        accelerometerTask = Task {
            for await accelerometer in device.accelerometer {
                let measurement = convert(accelerometer)

                appendAndLimit(measurement, to: &movement)
//                movementSummary = movementSummarizer.addMeasurement(measurement)
                // processMeasurement(frame: accelerometer, range: movementRange, currentMinute: &currentMovementMinute, summary: &movementSummary)
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
