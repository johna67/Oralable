//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import LogKit
import SwiftData

protocol PersistenceService {
    func writePPGFrame(_ frame: PPGFrame)
    func readPPGFrames(limit: Int?) -> [PPGFrame]
    func writeAccelerometerFrame(_ frame: AccelerometerFrame)
    func readAccelerometerFrames(limit: Int?) -> [AccelerometerFrame]
    func readUser() -> User?
    func writeUser(_ user: User)
    func writeEvent(_ event: Event)
    func readEvents(limit: Int?) -> [Event]
}

@Model
final class EventModel {
    @Attribute var timestamp: Date
    @Attribute var type: Event.EventType
    
    init(timestamp: Date, type: Event.EventType) {
        self.timestamp = timestamp
        self.type = type
    }
}

@Model
final class PPGSampleModel {
    @Attribute var red: Int32
    @Attribute var ir: Int32
    @Attribute var green: Int32

    init(red: Int32, ir: Int32, green: Int32) {
        self.red = red
        self.ir = ir
        self.green = green
    }
}

@Model
final class PPGFrameModel {
    @Attribute var frameCounter: UInt32
    @Attribute var timestamp: Date
    @Relationship var samples: [PPGSampleModel]

    init(frameCounter: UInt32, timestamp: Date, samples: [PPGSampleModel]) {
        self.frameCounter = frameCounter
        self.timestamp = timestamp
        self.samples = samples
    }

    func toPPGFrame() -> PPGFrame {
        PPGFrame(frameCounter: frameCounter, timestamp: timestamp, samples: samples.map { PPGSample(red: $0.red, ir: $0.ir, green: $0.green) } )
    }

    convenience init(_ frame: PPGFrame) {
        self.init(frameCounter: frame.frameCounter, timestamp: frame.timestamp, samples: frame.samples.map { PPGSampleModel(red: $0.red, ir: $0.ir, green: $0.green) })
    }
}

@Model
final class AccelerometerSampleModel {
    @Attribute var x: Int16
    @Attribute var y: Int16
    @Attribute var z: Int16

    init(x: Int16, y: Int16, z: Int16) {
        self.x = x
        self.y = y
        self.z = z
    }
}

@Model
final class AccelerometerFrameModel {
    @Attribute var frameCounter: UInt32
    @Attribute var timestamp: Date
    @Relationship var samples: [AccelerometerSampleModel]

    init(frameCounter: UInt32, timestamp: Date, samples: [AccelerometerSampleModel]) {
        self.frameCounter = frameCounter
        self.timestamp = timestamp
        self.samples = samples
    }

    convenience init(_ frame: AccelerometerFrame) {
        self.init(frameCounter: frame.frameCounter, timestamp: frame.timestamp, samples: frame.samples.map { AccelerometerSampleModel(x: $0.x, y: $0.y, z: $0.z) })
    }

    func toAccelerometerFrame() -> AccelerometerFrame {
        AccelerometerFrame(frameCounter: frameCounter, timestamp: timestamp, samples: samples.map { AccelerometerSample(x: $0.x, y: $0.y, z: $0.z) })
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
                for: PPGFrameModel.self,
                AccelerometerFrameModel.self,
                PPGSampleModel.self,
                AccelerometerSampleModel.self,
                UserModel.self,
                EventModel.self
            )
        } catch {
            Log.error("Failed to initialize persistence: \(error)")
        }
    }

    func writePPGFrame(_ frame: PPGFrame) {
        let model = PPGFrameModel(frame)
        write(model)
    }

    func writeAccelerometerFrame(_ frame: AccelerometerFrame) {
        let model = AccelerometerFrameModel(frame)
        write(model)
    }

    func readPPGFrames(limit: Int? = nil) -> [PPGFrame] {
        let context = ModelContext(container)
        do {
            let frames: [PPGFrameModel]
            if let limit {
                var fetchDescriptor = FetchDescriptor<PPGFrameModel>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                fetchDescriptor.fetchLimit = limit
                frames = try context.fetch(fetchDescriptor).reversed()
            } else {
                let fetchDescriptor = FetchDescriptor<PPGFrameModel>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
                frames = try context.fetch(fetchDescriptor)
            }
            return frames.map { $0.toPPGFrame() }
        } catch {
            Log.error("Could not read PPG frames: \(error)")
            return []
        }
    }

    func readAccelerometerFrames(limit: Int? = nil) -> [AccelerometerFrame] {
        let context = ModelContext(container)
        do {
            let frames: [AccelerometerFrameModel]
            if let limit {
                var fetchDescriptor = FetchDescriptor<AccelerometerFrameModel>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                fetchDescriptor.fetchLimit = limit
                frames = try context.fetch(fetchDescriptor).reversed()
            } else {
                let fetchDescriptor = FetchDescriptor<AccelerometerFrameModel>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
                frames = try context.fetch(fetchDescriptor)
            }
            return frames.map { $0.toAccelerometerFrame() }
        } catch {
            Log.error("Could not read Accelerometer frames: \(error)")
            return []
        }
    }
    
    func writeUser(_ user: User) {
        let model = UserModel(firstName: user.firstName, lastName: user.lastName, email: user.email ?? "")
        write(model)
    }
    
    func readUser() -> User? {
        let context = ModelContext(container)
        do {
            guard let model = try context.fetch(FetchDescriptor<UserModel>()).first else { return nil }
            return User(firstName: model.firstName, lastName: model.lastName, email: model.email)
        } catch {
            Log.error("Could not read User: \(error)")
        }
        
        return nil
    }
    
    func readEvents(limit: Int?) -> [Event] {
        let context = ModelContext(container)
        do {
            let models: [EventModel] = try context.fetch(FetchDescriptor<EventModel>())
            return models.map { .init(date: $0.timestamp, type: $0.type) }
        } catch {
            Log.error("Could not read Events: \(error)")
            return []
        }
    }
    
    func writeEvent(_ event: Event) {
        let model = EventModel(timestamp: event.date, type: event.type)
        write(model)
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
