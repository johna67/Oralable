//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import LogKit
import SwiftData

private struct ExportData: Codable {
    let ppg: [PPGDataPoint]
    let accelerometer: [AccelerometerDataPoint]
    let events: [EventModel]
}

protocol PersistenceService {
    func writePPGDataPoint(_ dataPoint: PPGDataPoint)
    func readPPGDataPoints(limit: Int?) -> [PPGDataPoint]
    func writeAccelerometerDataPoint(_ dataPoint: AccelerometerDataPoint)
    func readAccelerometerDataPoints(limit: Int?) -> [AccelerometerDataPoint]
    func readUser() -> User?
    func writeUser(_ user: User)
    func writeEvent(_ event: Event)
    func readEvents(limit: Int?) -> [Event]
    func exportAllToJson() throws -> Data
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
final class UserModel {
    @Attribute var firstName: String
    @Attribute var lastName: String
    @Attribute var email: String
    
    init(firstName: String, lastName: String, email: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
    }
}

final class SwiftDataPersistence: PersistenceService {
    private var container: ModelContainer!
    
    init() {
        do {
            container = try ModelContainer(
                for: PPGDataPoint.self,
                AccelerometerDataPoint.self,
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
    
    func exportAllToJson() throws -> Data {
        let ppg = readAll(PPGDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        let accelerometer = readAll(AccelerometerDataPoint.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        let events = readAll(EventModel.self)
        
        let exportData = ExportData(ppg: ppg, accelerometer: accelerometer, events: events)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportData)
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
