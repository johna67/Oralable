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
    
    func writeEvent(_ event: Event) {
        persistence.writeEvent(event)
    }
}

@MainActor
@Observable final class MeasurementStore {
    enum Status {
        case inactive, calibrating, active
    }
    var muscleActivityMagnitude = [MeasurementData]()
    var movement = [MeasurementData]()
    var status = Status.inactive
    
    var events = [Date: Event]()
    
    var muscleActivityThreshold: Double?
    var temperature: Double?
//    var measuring = false // whether the device is on the user's body
    
//    var calibrating: Bool {
//        measuring && muscleActivityThreshold == nil
//    }
    
    var thresholdPercentage: Double {
        didSet {
            UserDefaults.standard.set(thresholdPercentage, forKey: "thresholdPercentage")
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var ppgTask: Task<Void, Never>?
    private var accelerometerTask: Task<Void, Never>?
    private var temperatureTask: Task<Void, Never>?

    private var subscribed = false
    private var persistenceWorker = PersistenceWorker()

    private let ppgCalibrationFrameCount = 25
    private var ppgFrameReceivedSinceCalibrate = 0
    private let temperatureThreshold = 32.0

    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence

    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth

    init() {
        thresholdPercentage = UserDefaults.standard.double(forKey: "thresholdPercentage")
        if thresholdPercentage == 0 {
            thresholdPercentage = 0.2
        }
        
        muscleActivityThreshold = UserDefaults.standard.double(forKey: "muscleActivityThreshold")
        
        muscleActivityMagnitude = persistence.readPPGFrames(limit: nil).map { $0.convert() }
        movement = persistence.readAccelerometerFrames(limit: nil).map { $0.convert() }
        
        events = Dictionary(uniqueKeysWithValues: persistence.readEvents(limit: nil).map { ($0.date, $0) })
        
        bluetooth.devicePublisher.sink { device in
            if let device {
                self.subscribe(device)
            }
        }.store(in: &cancellables)
    }
    
    func exportToFile() -> URL? {
        do {
            let jsonData = try persistence.exportAllToJson()
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Oralable.json")
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            Log.error("Error saving combined data to file: \(error)")
            return nil
        }
    }
    
    func addEvent(_ event: Event) {
        persistence.writeEvent(event)
        events[event.date] = event
    }
    
    private func processFrameForCalibration() {
        ppgFrameReceivedSinceCalibrate += 1
        if ppgFrameReceivedSinceCalibrate >= ppgCalibrationFrameCount,
           let maxValue = muscleActivityMagnitude.suffix(ppgCalibrationFrameCount).max(by: { a, b in
               a.value < b.value
           }) {
            muscleActivityThreshold = maxValue.value * (1 + thresholdPercentage)
            UserDefaults.standard.set(muscleActivityThreshold, forKey: "muscleActivityThreshold")
            
            status = .active
        }
    }
    
    private func processPPG(_ ppg: PPGFrame) {
        let measurement = ppg.convert()
        muscleActivityMagnitude.append(measurement)
        
        if status == .calibrating {
            processFrameForCalibration()
        }
        
        if status == .active {
            Task {
                await persistenceWorker.writePPGFrame(ppg)
            }
        }
    }
    
    private func processAccelerometer(_ accelerometer: AccelerometerFrame) {
        guard status == .active else { return }
        Task {
            await persistenceWorker.writeAccelerometerFrame(accelerometer)
        }
    }
    
    private func processTemperature(_ temperature: Double) {
        if temperature >= temperatureThreshold {
            if status == .inactive {
                status = .calibrating
            }
        } else {
            status = .inactive
        }
        self.temperature = temperature
    }

    private func subscribe(_ device: DeviceService) {
        guard !subscribed else { return }
        subscribed = true
        ppgTask = Task {
            for await ppg in device.ppg {
                guard status != .inactive else {
                    ppgFrameReceivedSinceCalibrate = 0
                    continue
                }
                processPPG(ppg)
            }
        }

        accelerometerTask = Task {
            for await accelerometer in device.accelerometer {
                guard status != .inactive else { continue }
                processAccelerometer(accelerometer)
            }
        }
        
        temperatureTask = Task {
            for await temperature in device.temperature {
                processTemperature(temperature)
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
}

protocol MeasurementConvertible {
    var timestamp: Date { get }
    var value: Double { get }
    func convert() -> MeasurementData
}

extension MeasurementConvertible {
    func convert() -> MeasurementData {
        .init(date: timestamp, value: value)
    }
}

extension PPGFrame: MeasurementConvertible {
    var value: Double {
//        guard !samples.isEmpty else { return 0 }
//        return samples.map { Double($0.ir) }.reduce(0, +) / Double(samples.count)
        Double(samples.first?.ir ?? 0)
    }
}

extension AccelerometerFrame: MeasurementConvertible {
    var value: Double {
//        samples.map { $0.magnitude() }.max() ?? 0.0
        samples.first?.magnitude() ?? 0
    }
}
