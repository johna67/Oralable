//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation

@Observable class MeasurementService {
    var data = [MeasurementSeries]()
    
    init() {
            let calendar = Calendar.current
            let now = Date()

            let totalDays = 120
            let measurementArray: [Measurement] = (0..<(totalDays * 4)).map { offset in
                let date = calendar.date(byAdding: .hour, value: -offset * 6, to: now)!
                return Measurement(date: date, value: Double.random(in: 5...50))
            }
            
            let series = MeasurementSeries(
                type: .heartRate,
                source: .healthKit,
                measurements: measurementArray
            )
            
            self.data = [series]
        }
}
