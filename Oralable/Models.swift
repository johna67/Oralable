//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

public protocol Model: Hashable, Codable, Sendable {}

struct PPGFrame: Model {
    let frameCounter: UInt32
    let timestamp: Date
    let samples: [PPGSample]
}

struct PPGSample: Model {
    let red: Int32
    let ir: Int32
    let green: Int32
}

struct AccelerometerSample: Model {
    let x: Int16
    let y: Int16
    let z: Int16
    
    func magnitude() -> Double {
        sqrt(Double(x) * Double(x) + Double(y) * Double(y) + Double(z) * Double(z))
    }
}

struct AccelerometerFrame: Model {
    let frameCounter: UInt32
    let timestamp: Date
    let samples: [AccelerometerSample]
}

struct MeasurementData: Model {
    let date: Date
    let value: Double
}

struct SummaryData: Model {
    let date: Date
    var value: Int
}

struct Event: Model {
    enum EventType: String, Codable {
        case clenching = "Clenching"
        case grinding = "Grinding"
        case other = "Other"
    }
    let date: Date
    let type: EventType
}

enum MeasurementType: String, Codable {
    case heartRate
    case temperature
    case muscleActivity
    case muscleActivityMagnitude
    case movement
    case emg

    var unit: String {
        switch self {
        case .heartRate: "bpm"
        case .temperature: "°C"
        case .muscleActivity: "%"
        case .muscleActivityMagnitude: ""
        case .movement: ""
        case .emg: ""
        }
    }

    var name: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .temperature: "Temperature"
        case .muscleActivity: "Muscle Activity"
        case .muscleActivityMagnitude: "Muscle Activity Magnitude"
        case .movement: "Movement"
        case .emg: "EMG"
        }
    }

    var icon: String {
        switch self {
        case .heartRate: "heart.fill"
        case .temperature: "medical.thermometer.fill"
        case .muscleActivity: "distribute.vertical.fill"
        case .muscleActivityMagnitude: "waveform.path"
        case .movement: "person.and.arrow.left.and.arrow.right.outward"
        case .emg: "person.and.arrow.left.and.arrow.right.outward"
        }
    }
}

enum MeasurementClassification: String, Codable {
    case normal = "Normal"
    case high = "High"
    case low = "Low"
}

// struct Measurements: Model {
//    let category: Category
//    let source: Source
//    let classification: Classification
//    var data: [MeasurementPoint]
// }

enum DeviceType: String, Codable {
    case tgm = "TGM"
    case anr = "ANR Corp M40"
}

struct DeviceDescriptor: Model {
    let type: DeviceType
    let peripheralId: UUID
    let serviceIds: [UUID]
}

struct User: Model {
    var firstName = ""
    var lastName = ""
    var email: String?
    var height: Double?
    var weight: Double?
    var age: Int?
}
