//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

public protocol Model: Hashable, Codable { }

struct MeasurementPoint: Model {
    let date: Date
    let value: Double
}

struct Measurements: Model {
    enum Source: Codable {
        case healthKit, peripheral
    }
    
    enum Category: String, Codable {
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
        
        var name: String {
            switch self {
            case .heartRate: return "Heart Rate"
            case .muscleActivity: return "Muscle Activity"
            case .temperature: return "Temperature"
            }
        }
        
        var icon: String {
            switch self {
            case .heartRate: return "heart.fill"
            case .muscleActivity: return "distribute.vertical.fill"
            case .temperature: return "medical.thermometer.fill"
            }
        }
    }
    
    enum Classification: String, Codable {
        case normal = "Normal"
        case high = "High"
        case low = "Low"
    }
    
    let category: Category
    let source: Source
    let classification: Classification
    let data: [MeasurementPoint]
}
