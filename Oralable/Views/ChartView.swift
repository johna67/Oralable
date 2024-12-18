//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI
import Charts

struct ChartView: View {
    @Environment(MeasurementService.self) var measurementService: MeasurementService
    @State private var selectedRange: ChartRange = .day
    
    private enum ChartRange: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
    private var currentRangeInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedRange {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return DateInterval(start: startOfDay, end: endOfDay)
            
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                let startOfWeek = calendar.startOfDay(for: now)
                let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
                return DateInterval(start: startOfWeek, end: endOfWeek)
            }
            return weekInterval
            
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
                let startOfMonth = calendar.startOfDay(for: now)
                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
                return DateInterval(start: startOfMonth, end: endOfMonth)
            }
            return monthInterval
        }
    }
    
    private var filteredData: [Measurement] {
        guard let series = measurementService.measurements.first else {
            return []
        }
        return series.measurements
            .filter { $0.date >= currentRangeInterval.start && $0.date < currentRangeInterval.end }
            .sorted { $0.date < $1.date }
    }
    
    private var dateFormatForXAxis: Date.FormatStyle {
        switch selectedRange {
        case .day:
            return .dateTime.hour().minute()
        case .week:
            return .dateTime.weekday(.short)
        case .month:
            return .dateTime.weekday(.short).day()
        }
    }
    
    var body: some View {
        VStack {
            Picker("Range", selection: $selectedRange) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Chart {
                ForEach(filteredData, id: \.self) { measurement in
                    LineMark(
                        x: .value("Date", measurement.date),
                        y: .value("Value", measurement.value)
                    )
                    .foregroundStyle(.blue)
                    
                    PointMark(
                        x: .value("Date", measurement.date),
                        y: .value("Value", measurement.value)
                    )
                    .symbol(Circle())
                    .foregroundStyle(.blue)
                }
            }
            .chartXScale(domain: currentRangeInterval.start...currentRangeInterval.end)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: dateFormatForXAxis)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                }
            }
            .padding()
        }
    }
}

#Preview {
    ChartView()
}
