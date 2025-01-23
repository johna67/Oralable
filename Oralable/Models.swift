//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

public protocol Model: Hashable, Codable, Sendable {}

struct MeasurementData: Model {
    let date: Date
    let value: Double
    let belowThreshold: Bool
    let aboveThreshold: Bool
    let calibrated: Bool
}

struct SummaryData: Model {
    let date: Date
    var value: Int
}

enum MeasurementType: String, Codable {
    case heartRate
    case temperature
    case muscleActivity
    case muscleActivityMagnitude
    case movement

    var unit: String {
        switch self {
        case .heartRate: "bpm"
        case .temperature: "°C"
        case .muscleActivity: "%"
        case .muscleActivityMagnitude: ""
        case .movement: ""
        }
    }

    var name: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .temperature: "Temperature"
        case .muscleActivity: "Muscle Activity"
        case .muscleActivityMagnitude: "Muscle Activity Magnitude"
        case .movement: "Movement"
        }
    }

    var icon: String {
        switch self {
        case .heartRate: "heart.fill"
        case .temperature: "medical.thermometer.fill"
        case .muscleActivity: "distribute.vertical.fill"
        case .muscleActivityMagnitude: "waveform.path"
        case .movement: "person.and.arrow.left.and.arrow.right.outward"
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
