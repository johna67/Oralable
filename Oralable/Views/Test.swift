//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import SwiftUI

import Charts

struct RangeBarChartView: View {
    struct BarData: Identifiable {
        let id = UUID()
        let date: Date
        let redRange: ClosedRange<Double>
        let greenRange: ClosedRange<Double>
    }
    
    let data: [BarData] = {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            return BarData(
                date: date,
                redRange: (50.0 + Double(offset) * 10)...(60.0 + Double(offset) * 10),
                greenRange: (30.0 + Double(offset) * 5)...(40.0 + Double(offset) * 5)
            )
        }
    }()
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Date", item.date),
                yStart: .value("Red Range Start", item.redRange.lowerBound),
                yEnd: .value("Red Range End", item.redRange.upperBound)
            )
            .foregroundStyle(.red)

            BarMark(
                x: .value("Date", item.date),
                yStart: .value("Green Range Start", item.greenRange.lowerBound),
                yEnd: .value("Green Range End", item.greenRange.upperBound)
            )
            .foregroundStyle(.green)
        }
        .padding()
    }
}

#Preview {
    RangeBarChartView()
}
