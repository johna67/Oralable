//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import LogKit
import SwiftData

private struct ExportData: Codable {
    let ppg: [PPGFrame]
    let accelerometer: [AccelerometerFrame]
    let events: [EventModel]
}

protocol PersistenceService {
    func writePPGFrame(_ frame: PPGFrame)
    func readPPGFrames(limit: Int?) -> [PPGFrame]
    func writeAccelerometerFrame(_ frame: AccelerometerFrame)
    func readAccelerometerFrames(limit: Int?) -> [AccelerometerFrame]
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
final class PPGSample: Codable {
    @Attribute var red: Int32
    @Attribute var ir: Int32
    @Attribute var green: Int32

    init(red: Int32, ir: Int32, green: Int32) {
        self.red = red
        self.ir = ir
        self.green = green
    }
    
    enum CodingKeys: String, CodingKey {
        case r, ir, g
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Int32.self, forKey: .r)
        ir = try container.decode(Int32.self, forKey: .ir)
        green = try container.decode(Int32.self, forKey: .g)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .r)
        try container.encode(ir, forKey: .ir)
        try container.encode(green, forKey: .g)
    }
}

@Model
final class PPGFrame: Codable {
    @Attribute var frameCounter: UInt32
    @Attribute var timestamp: Date
    @Relationship var samples: [PPGSample]

    init(frameCounter: UInt32, timestamp: Date, samples: [PPGSample]) {
        self.frameCounter = frameCounter
        self.timestamp = timestamp
        self.samples = samples
    }

    func toPPGFrame() -> PPGFrame {
        PPGFrame(frameCounter: frameCounter, timestamp: timestamp, samples: samples.map { PPGSample(red: $0.red, ir: $0.ir, green: $0.green) })
    }

    convenience init(_ frame: PPGFrame) {
        self.init(frameCounter: frame.frameCounter, timestamp: frame.timestamp, samples: frame.samples.map { PPGSample(red: $0.red, ir: $0.ir, green: $0.green) })
    }
    
    enum CodingKeys: String, CodingKey {
        case f, ts, s
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frameCounter = try container.decode(UInt32.self, forKey: .f)
        timestamp = try container.decode(Date.self, forKey: .ts)
        samples = try container.decode([PPGSample].self, forKey: .s)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frameCounter, forKey: .f)
        try container.encode(timestamp, forKey: .ts)
        try container.encode(samples, forKey: .s)
    }
}

@Model
final class AccelerometerSample: Codable {
    @Attribute var x: Int16
    @Attribute var y: Int16
    @Attribute var z: Int16

    init(x: Int16, y: Int16, z: Int16) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    enum CodingKeys: String, CodingKey {
        case x, y, z
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(Int16.self, forKey: .x)
        y = try container.decode(Int16.self, forKey: .y)
        z = try container.decode(Int16.self, forKey: .z)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }
    
    func magnitude() -> Double {
        sqrt(Double(x) * Double(x) + Double(y) * Double(y) + Double(z) * Double(z))
    }
}

@Model
final class AccelerometerFrame: Codable {
    @Attribute var frameCounter: UInt32
    @Attribute var timestamp: Date
    @Relationship var samples: [AccelerometerSample]

    init(frameCounter: UInt32, timestamp: Date, samples: [AccelerometerSample]) {
        self.frameCounter = frameCounter
        self.timestamp = timestamp
        self.samples = samples
    }

    convenience init(_ frame: AccelerometerFrame) {
        self.init(frameCounter: frame.frameCounter, timestamp: frame.timestamp, samples: frame.samples.map { AccelerometerSample(x: $0.x, y: $0.y, z: $0.z) })
    }

    func toAccelerometerFrame() -> AccelerometerFrame {
        AccelerometerFrame(frameCounter: frameCounter, timestamp: timestamp, samples: samples.map { AccelerometerSample(x: $0.x, y: $0.y, z: $0.z) })
    }
    
    enum CodingKeys: String, CodingKey {
        case frameCounter, timestamp, samples
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frameCounter = try container.decode(UInt32.self, forKey: .frameCounter)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        samples = try container.decode([AccelerometerSample].self, forKey: .samples)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frameCounter, forKey: .frameCounter)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(samples, forKey: .samples)
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
                for: PPGFrame.self,
                AccelerometerFrame.self,
                PPGSample.self,
                AccelerometerSample.self,
                UserModel.self,
                EventModel.self
            )
        } catch {
            Log.error("Failed to initialize persistence: \(error)")
        }
    }

    func writePPGFrame(_ frame: PPGFrame) {
        write(PPGFrame(frame))
    }

    func writeAccelerometerFrame(_ frame: AccelerometerFrame) {
        write(AccelerometerFrame(frame))
    }

    func readPPGFrames(limit: Int? = nil) -> [PPGFrame] {
        let frames: [PPGFrame]
        if let limit {
            frames = readAll(PPGFrame.self, sortBy: SortDescriptor(\.timestamp, order: .reverse), limit: limit).reversed()
        } else {
            frames = readAll(PPGFrame.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        }
        
        //return frames.map { $0.toPPGFrame() }
        return frames
    }

    func readAccelerometerFrames(limit: Int? = nil) -> [AccelerometerFrame] {
        let frames: [AccelerometerFrame]
        if let limit {
            frames = readAll(AccelerometerFrame.self, sortBy: SortDescriptor(\.timestamp, order: .reverse), limit: limit).reversed()
        } else {
            frames = readAll(AccelerometerFrame.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        }
        
        return frames
        //return frames.map { $0.toAccelerometerFrame() }
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
        let ppg = readAll(PPGFrame.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
        let accelerometer = readAll(AccelerometerFrame.self, sortBy: SortDescriptor(\.timestamp, order: .forward))
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
