//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Combine
import Factory
import Foundation
import LogKit

private actor PersistenceReader {
    @Injected(\.persistenceService) private var persistence
    
    func readPPG() -> [PPGDataPoint] {
        persistence.readPPGDataPoints(limit: nil)
    }
    
    func readAccelerometer() -> [AccelerometerDataPoint] {
        persistence.readAccelerometerDataPoints(limit: nil)
    }
    
    func readEvents() -> [Event] {
        persistence.readEvents(limit: nil)
    }
}

private actor PersistenceWorker {
    @ObservationIgnored
    @Injected(\.persistenceService) private var persistence
    
    func writeAccelerometerDataPoint(_ dataPoint: AccelerometerDataPoint) {
        persistence.writeAccelerometerDataPoint(dataPoint)
    }
    
    func writePPGDataPoint(_ dataPoint: PPGDataPoint) {
        persistence.writePPGDataPoint(dataPoint)
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
    var status = Status.inactive
    
    var temperature: Double?
    
    var muscleActivityMagnitude = [MeasurementData]()
    var movement = [MeasurementData]()
    var events = [Date: Event]()
    
    var muscleActivityThreshold: Double?
    var movementThreshold: Double?
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
    private let reader = PersistenceReader()
    
    @ObservationIgnored
    @Injected(\.bluetoothService) private var bluetooth
    
    init() {
        thresholdPercentage = UserDefaults.standard.double(forKey: "thresholdPercentage")
        if thresholdPercentage == 0 {
            thresholdPercentage = 0.2
        }
        muscleActivityThreshold = UserDefaults.standard.double(forKey: "muscleActivityThreshold")
        movementThreshold = UserDefaults.standard.double(forKey: "movementThreshold")
        
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadInitialData()
        }
        
        bluetooth.devicePublisher.sink { device in
            if let device {
                self.subscribe(device)
            }
        }.store(in: &cancellables)
    }
    
    nonisolated private func loadInitialData() async {
        async let ppgPoints = reader.readPPG()
        async let accPoints = reader.readAccelerometer()
        async let evtArray  = reader.readEvents()
        
        let (ppg, acc, evts) = await (ppgPoints, accPoints, evtArray)
        
        await MainActor.run {
            self.muscleActivityMagnitude = ppg.map { $0.convert() }
            self.movement = acc.map { $0.convert() }
            self.events = Dictionary( uniqueKeysWithValues: evts.map { ($0.date, $0) }
            )
        }
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
    
    private func processPPG(_ ppg: PPGFrame) {
        let dataPoint = ppg.convertToDataPoint()
        muscleActivityMagnitude.append(dataPoint.convert())
        
        recalibrateMuscleActivityWith(dataPoint)
        
        if status == .active {
            Task {
                await persistenceWorker.writePPGDataPoint(dataPoint)
            }
        }
    }
    
    private func recalibrateMuscleActivityWith(_ dataPoint: PPGDataPoint) {
        let count = muscleActivityMagnitude.count
        if let oldAvg = muscleActivityThreshold {
            muscleActivityThreshold = oldAvg + (dataPoint.value - oldAvg) / Double(count)
        } else {
            muscleActivityThreshold = dataPoint.value
        }
        UserDefaults.standard.set(muscleActivityThreshold, forKey: "muscleActivityThreshold")
    }
    
    private func processAccelerometer(_ accelerometer: AccelerometerFrame) {
        let dataPoint = accelerometer.convertToDataPoint()
        movement.append(dataPoint.convert())
        
        recalibrateMovementWith(dataPoint)
        
        guard status == .active else { return }
        Task {
            await persistenceWorker.writeAccelerometerDataPoint(dataPoint)
        }
    }
    
    private func recalibrateMovementWith(_ dataPoint: AccelerometerDataPoint) {
        let count = movement.count
        if let oldAvg = movementThreshold {
            movementThreshold = oldAvg + (dataPoint.value - oldAvg) / Double(count)
        } else {
            movementThreshold = dataPoint.value
        }
        UserDefaults.standard.set(movementThreshold, forKey: "movementThreshold")
    }
    
    private func processTemperature(_ temperature: Double) {
        if temperature >= temperatureThreshold {
            if status == .inactive {
                status = .active
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

extension PPGDataPoint: MeasurementConvertible {
    
}

extension AccelerometerDataPoint: MeasurementConvertible {
    
}

extension PPGFrame{
    func convertToDataPoint() -> PPGDataPoint {
        PPGDataPoint(value: samples.map { Double($0.ir) }.reduce(0, +) / Double(samples.count), timestamp: timestamp)
    }
}

extension AccelerometerFrame{
    func convertToDataPoint() -> AccelerometerDataPoint {
        AccelerometerDataPoint(value: samples.map { $0.magnitude() }.reduce(0, +) / Double(samples.count), timestamp: timestamp)
    }
}
