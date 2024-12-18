//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

public protocol Model: Hashable, Codable { }

enum MeasurementType: String, Codable {
    case heartRate
    case muscleActivity
    case temperature
    
    var unit: String {
        switch self {
        case .heartRate: return "bpm"
        case .muscleActivity: return "%"
        case .temperature: return "°C"
        }
    }
}

enum MeasurementSource: Codable {
    case healthKit, peripheral
}

struct Measurement: Model {
    let date: Date
    let value: Double
}

struct MeasurementSeries: Model {
    let type: MeasurementType
    let source: MeasurementSource
    let measurements: [Measurement]
}
