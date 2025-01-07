//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

public protocol Model: Hashable, Codable { }

struct MeasurementData: Model {
    let date: Date
    let value: Double
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
        case .heartRate: return "bpm"
        case .temperature: return "°C"
        case .muscleActivity: return "%"
        case .muscleActivityMagnitude: return ""
        case .movement: return ""
        }
    }
    
    var name: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .temperature: return "Temperature"
        case .muscleActivity: return "Muscle Activity"
        case .muscleActivityMagnitude: return "Muscle Activity Magnitude"
        case .movement: return "Movement"
        }
    }
    
    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .temperature: return "medical.thermometer.fill"
        case .muscleActivity: return "distribute.vertical.fill"
        case .muscleActivityMagnitude: return "waveform.path"
        case .movement: return "person.and.arrow.left.and.arrow.right.outward"
        }
    }
}

enum MeasurementClassification: String, Codable {
    case normal = "Normal"
    case high = "High"
    case low = "Low"
}

//struct Measurements: Model {
//    let category: Category
//    let source: Source
//    let classification: Classification
//    var data: [MeasurementPoint]
//}

enum DeviceType: String, Codable {
    case tgm = "TGM"
}

struct DeviceDescriptor: Model {
    let type: DeviceType
    let peripheralId: UUID
    let serviceIds: [UUID]
}
