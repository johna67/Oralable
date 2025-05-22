//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import LogKit
import SwiftData

struct ExportData: Codable {
    let ppg: [PPGDataPoint]
    let accelerometer: [AccelerometerDataPoint]
    let emg: [EMGDataPoint]
    let events: [Event]
    let user: User
    let thresholds: [MeasurementType: Double?]
}

protocol PersistenceService {
    func writePPGDataPoint(_ dataPoint: PPGDataPoint)
    func readPPGDataPoints(limit: Int?) -> [PPGDataPoint]
    func writeAccelerometerDataPoint(_ dataPoint: AccelerometerDataPoint)
    func readAccelerometerDataPoints(limit: Int?) -> [AccelerometerDataPoint]
    func writeEMGDataPoint(_ dataPoint: EMGDataPoint)
    func readEMGDataPoints(limit: Int?) -> [EMGDataPoint]
    func readUser() -> User?
    func writeUser(_ user: User)
    func writeEvent(_ event: Event)
    func readEvents(limit: Int?) -> [Event]
    
    @MainActor
    func exportToFile(_ email: String, thresholds: [MeasurementType: Double?]) async -> URL?
}

@Model
final class EventModel: Codable {
    @Attribute var timestamp: Date
    @Attribute var type: Event.EventType
    
    init(timestamp: Date, type: Event.EventType) {
        self.timestamp = timestamp
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case type
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(Event.EventType.self, forKey: .type)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
    }
}

@Model
final class PPGDataPoint: Codable {
    @Attribute var value: Double
    @Attribute var timestamp: Date
    
    init(value: Double, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
    
    func toPPGDataPoint() -> PPGDataPoint {
        PPGDataPoint(value: value, timestamp: timestamp)
    }
    
    convenience init(_ dataPoint: PPGDataPoint) {
        self.init(value: dataPoint.value, timestamp: dataPoint.timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case value, timestamp
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Double.self, forKey: .value)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

@Model
final class EMGDataPoint: Codable {
    @Attribute var value: Double
    @Attribute var timestamp: Date
    
    init(value: Double, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
    
    func toEMGDataPoint() -> EMGDataPoint {
        EMGDataPoint(value: value, timestamp: timestamp)
    }
    
    convenience init(_ dataPoint: EMGDataPoint) {
        self.init(value: dataPoint.value, timestamp: dataPoint.timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case value, timestamp
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Double.self, forKey: .value)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

@Model
final class AccelerometerDataPoint: Codable {
    @Attribute var value: Double
    @Attribute var timestamp: Date
    
    init(value: Double, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
    
    convenience init(_ dataPoint: AccelerometerDataPoint) {
        self.init(value: dataPoint.value, timestamp: dataPoint.timestamp)
    }
    
    func toAccelerometerDataPoint() -> AccelerometerDataPoint {
        AccelerometerDataPoint(value: value, timestamp: timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case value, timestamp
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Double.self, forKey: .value)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

@Model
final class UserModel: Codable {
    @Attribute var firstName: String
    @Attribute var lastName: String
    @Attribute var email: String
    
    init(firstName: String, lastName: String, email: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
    }
    
    enum CodingKeys: String, CodingKey {
        case firstName, lastName, email
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        email = try container.decode(String.self, forKey: .email)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(email, forKey: .email)
    }
}

final class SwiftDataPersistence: PersistenceService {
    private var container: ModelContainer!
    
    init() {
        do {
            container = try ModelContainer(
                for: PPGDataPoint.self,
                AccelerometerDataPoint.self,
                EMGDataPoint.self,
                UserModel.self,
                EventModel.self
            )
        } catch {
            Log.error("Failed to initialize persistence: \(error)")
        }
    }
    
    func writePPGDataPoint(_ dataPoint: PPGDataPoint) {
        write(PPGDataPoint(dataPoint))
    }
    
    func writeAccelerometerDataPoint(_ dataPoint: AccelerometerDataPoint) {
        write(AccelerometerDataPoint(dataPoint))
    }
    
    func writeEMGDataPoint(_ dataPoint: EMGDataPoint) {
        write(EMGDataPoint(dataPoint))
    }
    
    func readPPGDataPoints(limit: Int? = nil) -> [PPGDataPoint] {
        let frames: [PPGDataPoint]
        if let limit {
            frames = readAll(PPGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .reverse), limit: limit).reversed()
        } else {
            frames = readAll(PPGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        }
        
        return frames
    }
    
    func readAccelerometerDataPoints(limit: Int? = nil) -> [AccelerometerDataPoint] {
        let frames: [AccelerometerDataPoint]
        if let limit {
            frames = readAll(AccelerometerDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .reverse), limit: limit).reversed()
        } else {
            frames = readAll(AccelerometerDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        }
        
        return frames
    }
    
    func readEMGDataPoints(limit: Int? = nil) -> [EMGDataPoint] {
        let frames: [EMGDataPoint]
        if let limit {
            frames = readAll(EMGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .reverse), limit: limit).reversed()
        } else {
            frames = readAll(EMGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        }
        
        return frames
    }
    
    func writeUser(_ user: User) {
        write(UserModel(firstName: user.firstName, lastName: user.lastName, email: user.email ?? ""))
    }
    
    func readUser() -> User? {
        guard let model = read(UserModel.self) else { return nil }
        return User(firstName: model.firstName, lastName: model.lastName, email: model.email)
    }
    
    func readEvents(limit: Int?) -> [Event] {
        readAll(EventModel.self).map {
            Event(date: $0.timestamp, type: $0.type)
        }
    }
    
    func writeEvent(_ event: Event) {
        write(EventModel(timestamp: event.date, type: event.type))
    }
    
    func exportToFile(_ email: String, thresholds: [MeasurementType: Double?]) async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let jsonData = try self.exportAllToJson(thresholds: thresholds)
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent("\(email)_Oralable.json")
                    
                    if let jsonData = jsonData {
                        try jsonData.write(to: fileURL)
                        continuation.resume(returning: fileURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func exportAllToJson(thresholds: [MeasurementType: Double?]) throws -> Data? {
        if let user = readUser() {
            let ppg = readAll(PPGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
            let accelerometer = readAll(AccelerometerDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
            let emg = readAll(EMGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
            
            let events = readEvents(limit: nil)
            
            let exportData = ExportData(ppg: ppg, accelerometer: accelerometer, emg: emg, events: events, user: user, thresholds: thresholds)
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        }
        
        return nil
    }
    
    private func read<T: PersistentModel>(_ type: T.Type) -> T? {
        let context = ModelContext(container)
        do {
            return try context.fetch(FetchDescriptor<T>()).first
        } catch {
            Log.error("Could not read \(String(describing: T.self)): \(error)")
            return nil
        }
    }
    
    private func readAll<T: PersistentModel>(_ type: T.Type, sortBy: SortDescriptor<T>? = nil, limit: Int? = nil) -> [T] {
        let context = ModelContext(container)
        do {
            var fetchDescriptor = FetchDescriptor<T>()
            
            if let sortBy = sortBy {
                fetchDescriptor.sortBy = [sortBy]
            }
            
            if let limit = limit {
                fetchDescriptor.fetchLimit = limit
            }
            return try context.fetch(fetchDescriptor)
        } catch {
            Log.error("Could not read \(String(describing: T.self)): \(error)")
            return []
        }
    }
    
    private func write(_ model: any PersistentModel) {
        let context = ModelContext(container)
        context.insert(model)
        do {
            try context.save()
        } catch {
            Log.error("Could not save model: \(model) error: \(error)")
        }
    }
}

extension PPGDataPoint: @unchecked Sendable {}
extension AccelerometerDataPoint: @unchecked Sendable {}
extension EventModel: @unchecked Sendable {}
extension EMGDataPoint: @unchecked Sendable {}
