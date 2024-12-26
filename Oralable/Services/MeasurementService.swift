//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

@Observable class MeasurementService {
    var measurements = [Measurements]()
    
    init() {
        let calendar = Calendar.current
        let now = Date()

        let totalDays = 120
        
        var measurementArray: [MeasurementPoint] = (0..<(totalDays * 4)).map { offset in
            let date = calendar.date(byAdding: .hour, value: -offset * 6, to: now)!
            return MeasurementPoint(date: date, value: Double.random(in: 50...100))
        }
        
        measurements.append(Measurements(category: .heartRate, source: .healthKit, classification: .normal, data: measurementArray))
        
        measurementArray = (0..<(totalDays * 4)).map { offset in
            let date = calendar.date(byAdding: .hour, value: -offset * 6, to: now)!
            return MeasurementPoint(date: date, value: Double.random(in: 36.5...37.2))
        }
        
        measurements.append(Measurements(category: .temperature, source: .healthKit, classification: .normal, data: measurementArray))
        
        measurementArray = (0..<(totalDays * 4)).map { offset in
            let date = calendar.date(byAdding: .hour, value: -offset * 6, to: now)!
            return MeasurementPoint(date: date, value: Double.random(in: 0...100))
        }
        
        measurements.append(Measurements(category: .muscleActivity, source: .healthKit, classification: .normal, data: measurementArray))
    }
}
