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
    
    func readEMG() -> [EMGDataPoint] {
        persistence.readEMGDataPoints(limit: nil)
    }
    
    func readUserEmail() -> String? {
        persistence.readUser()?.email
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
    
    func writeEMGDataPoint(_ dataPoint: EMGDataPoint) {
        persistence.writeEMGDataPoint(dataPoint)
    }
    
    func writeEvent(_ event: Event) {
        persistence.writeEvent(event)
    }
}

enum MeasurementStatus {
    case inactive, calibrating, active
}

@MainActor
protocol MeasurementStoreProtocol: AnyObject {
    var dataLoaded: Bool { get }
    var dataLoadedCallback: (() -> Void)? { get set }
    var status: MeasurementStatus { get }
    var temperature: Double? { get }
    
    var muscleActivityMagnitude: [MeasurementData] { get }
    var movement: [MeasurementData] { get }
    var emg: [MeasurementData] { get }
    var events: [Date: Event] { get }
    
    var muscleActivityThreshold: Double? { get }
    var movementThreshold: Double? { get }
    var emgThreshold: Double? { get }
    var thresholdPercentage: Double { get }
    
    func addEvent(_ event: Event)
}

@MainActor
@Observable final class JSONMeasurementStore: MeasurementStoreProtocol {
    var status = MeasurementStatus.inactive
    
    var temperature: Double?
    
    var muscleActivityMagnitude = [MeasurementData]()
    var movement = [MeasurementData]()
    var emg = [MeasurementData]()
    var events = [Date: Event]()
    
    var muscleActivityThreshold: Double?
    var movementThreshold: Double?
    var emgThreshold: Double?
    var thresholdPercentage: Double {
        didSet {
            UserDefaults.standard.set(thresholdPercentage, forKey: "thresholdPercentage")
        }
    }
    var dataLoadedCallback: (() -> Void)?
    var dataLoaded: Bool = false
    
    init(jsonURL: URL) {
        thresholdPercentage = UserDefaults.standard.double(forKey: "thresholdPercentage")
        if thresholdPercentage == 0 {
            thresholdPercentage = 0.2
        }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadInitialData(jsonURL: jsonURL)
        }
    }
    
    nonisolated private func loadInitialData(jsonURL: URL) async {
        var exportData: ExportData?
        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            exportData = try decoder.decode(ExportData.self, from: data)
        } catch {
            
        }
        
        guard let exportData = exportData else { return }
        
        await MainActor.run {
            self.status = .active
            self.temperature = nil
            
            self.muscleActivityMagnitude.insert(contentsOf: exportData.ppg.map { $0.convert() }, at: 0)
            self.movement.insert(contentsOf: exportData.accelerometer.map { $0.convert() }, at: 0)
            self.events = Dictionary( uniqueKeysWithValues: exportData.events.map { ($0.date, $0) })
            self.emg.insert(contentsOf: exportData.emg.map { $0.convert() }, at: 0)
            
            self.muscleActivityThreshold = exportData.thresholds[.muscleActivityMagnitude] ?? self.muscleActivityMagnitude.averageValue()
            self.movementThreshold = exportData.thresholds[.movement] ?? self.movement.averageValue()
            self.emgThreshold = exportData.thresholds[.emg] ?? self.emg.averageValue()
            
            dataLoaded = true
            if let callback = dataLoadedCallback {
                callback()
            }
        }
    }
    
    func addEvent(_ event: Event) {
        
    }
}

@MainActor
@Observable final class MeasurementStore: MeasurementStoreProtocol {
    var status = MeasurementStatus.inactive
    
    var temperature: Double?
    
    var muscleActivityMagnitude = [MeasurementData]()
    var movement = [MeasurementData]()
    var emg = [MeasurementData]()
    var events = [Date: Event]()
    
    var muscleActivityThreshold: Double?
    var movementThreshold: Double?
    var emgThreshold: Double?
    var thresholdPercentage: Double {
        didSet {
            UserDefaults.standard.set(thresholdPercentage, forKey: "thresholdPercentage")
        }
    }
    
    var userEmail: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var ppgTask: Task<Void, Never>?
    private var emgTask: Task<Void, Never>?
    private var accelerometerTask: Task<Void, Never>?
    private var temperatureTask: Task<Void, Never>?
    
    private var subscribed = [UUID: Bool]()
    private var persistenceWorker = PersistenceWorker()
    
    private let ppgCalibrationFrameCount = 25
    private var ppgFrameReceivedSinceCalibrate = 0
    private let temperatureThreshold = 24.0
    
    var dataLoadedCallback: (() -> Void)?
    var dataLoaded: Bool = false
    
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
        emgThreshold = UserDefaults.standard.double(forKey: "emgThreshold")
        
        status = .calibrating
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadInitialData()
        }
        
        bluetooth.devicesPublisher.sink { devices in
            for device in devices {
                self.subscribe(device)
            }
        }.store(in: &cancellables)
    }
    
    nonisolated private func loadInitialData() async {
        async let ppgPoints = reader.readPPG()
        async let accPoints = reader.readAccelerometer()
        async let evtArray = reader.readEvents()
        async let emgPoints = reader.readEMG()
        async let readEmail = reader.readUserEmail()
        
        let (ppg, acc, evts, emgStore, email) = await (ppgPoints, accPoints, evtArray, emgPoints, readEmail)
        
        await MainActor.run {
            self.muscleActivityMagnitude.insert(contentsOf: ppg.map { $0.convert() }, at: 0)
            self.movement.insert(contentsOf: acc.map { $0.convert() }, at: 0)
            self.events = Dictionary( uniqueKeysWithValues: evts.map { ($0.date, $0) })
            self.emg.insert(contentsOf: emgStore.map { $0.convert() }, at: 0)
            self.userEmail = email ?? UUID().uuidString
            
            if temperature ?? 0 >= temperatureThreshold {
                status = .active
            } else {
                status = .inactive
            }
            
            dataLoaded = true
            if let callback = dataLoadedCallback {
                callback()
            }
        }
    }
    
    func exportToFile() async -> URL? {
        guard let email = userEmail else { return nil }
        return await persistence.exportToFile(email, thresholds: [.emg: emgThreshold, .movement: movementThreshold, .muscleActivityMagnitude: muscleActivityThreshold])
    }
    
    func addEvent(_ event: Event) {
        persistence.writeEvent(event)
        events[event.date] = event
    }
    
    private func processPPG(_ ppg: PPGFrame) {
        guard status == .active else { return }
        
        let dataPoint = ppg.convertToDataPoint()
        muscleActivityMagnitude.append(dataPoint.convert())
        
        recalibrateMuscleActivityWith(dataPoint)
        
        Task {
            await persistenceWorker.writePPGDataPoint(dataPoint)
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
        guard status == .active else { return }
        
        let dataPoint = accelerometer.convertToDataPoint()
        movement.append(dataPoint.convert())
        
        recalibrateMovementWith(dataPoint)
        
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
            if status == .active {
                status = .inactive
            }
        }
        self.temperature = temperature
    }
    
    private func processEMG(_ dataPoint: MeasurementData) {
        emg.append(dataPoint)
        
        recalibrateEMGWith(dataPoint)
        
        Task {
            await persistenceWorker.writeEMGDataPoint(EMGDataPoint(value: dataPoint.value, timestamp: dataPoint.date))
        }
    }
    
    private func recalibrateEMGWith(_ dataPoint: MeasurementData) {
        let count = emg.count
        if let oldAvg = emgThreshold {
            emgThreshold = oldAvg + (dataPoint.value - oldAvg) / Double(count)
        } else {
            emgThreshold = dataPoint.value
        }
        UserDefaults.standard.set(emgThreshold, forKey: "emgThreshold")
    }
    
    private func subscribe(_ device: DeviceService) {
        guard !(subscribed[device.ID] ?? false) else { return }
        subscribed[device.ID] = true
        
        ppgTask = Task {
            for await ppg in device.ppg {
                processPPG(ppg)
            }
        }
        
        emgTask = Task {
            for await emg in device.emg {
                processEMG(emg)
            }
        }
        
        accelerometerTask = Task {
            for await accelerometer in device.accelerometer {
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

extension EMGDataPoint: MeasurementConvertible {
    
}

extension PPGFrame {
    func convertToDataPoint() -> PPGDataPoint {
        PPGDataPoint(value: samples.map { Double($0.ir) }.reduce(0, +) / Double(samples.count), timestamp: timestamp)
    }
}

extension AccelerometerFrame {
    func convertToDataPoint() -> AccelerometerDataPoint {
        AccelerometerDataPoint(value: samples.map { $0.magnitude() }.reduce(0, +) / Double(samples.count), timestamp: timestamp)
    }
}
