//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Charts
import SwiftUI

//struct ProcessedData: Hashable {
//    let date: Date
//    var range: ClosedRange<Double>?
//    var aboveThresholdRange: ClosedRange<Double>?
//    var belowThresholdRange: ClosedRange<Double>?
//}

struct CountMeasurementData: Hashable {
    let insideCount: Int
    let outsideCount: Int
    let date: Date
    var percentage: Double {
        let dinside = Double(insideCount)
        let doutside = Double(outsideCount)
        return (dinside / (dinside + doutside)) * 100.0
    }
}

struct AggregatedData: Hashable {
    let date: Date
    var min: Double
    var max: Double
    var avg: Double
    var count: Int
}

struct ChartView: View {
    @Environment(MeasurementStore.self) var measurements: MeasurementStore
    @State private var selectedRange: ChartRange = .day
    @State private var startTimeInterval = TimeInterval()

    let measurementType: MeasurementType
    let lowerThreshold = 0.0
    let upperThreshold = 300000.0
    //@State private var processedData = [ProcessedData]()

    @State private var dailyCountData = [CountMeasurementData]()
    @State private var weeklyCountData = [CountMeasurementData]()
    @State private var monthlyCountData = [CountMeasurementData]()
    
    @State private var dailyAggregatedData = [AggregatedData]()
    @State private var weeklyAggregatedData = [AggregatedData]()
    @State private var monthlyAggregatedData = [AggregatedData]()
    
    private var data: [MeasurementData] {
        switch measurementType {
        case .muscleActivityMagnitude:
            measurements.muscleActivityMagnitude
        case .movement:
            measurements.movement
        default:
            []
        }
    }

    private enum ChartRange: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }
    }
    
    private var countData: [CountMeasurementData] {
        switch selectedRange {
        case .day:
            dailyCountData
        case .week:
            weeklyCountData
        case .month:
            monthlyCountData
        }
    }
    
    private var aggregatedData: [AggregatedData] {
        switch selectedRange {
        case .day:
            dailyAggregatedData
        case .week:
            weeklyAggregatedData
        case .month:
            monthlyAggregatedData
        }
    }

    private var targetBehavior: ValueAlignedChartScrollTargetBehavior {
        switch selectedRange {
        case .day: .valueAligned(matching: DateComponents(minute: 0), majorAlignment: .matching(DateComponents(minute: 0)))
        case .week: .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(hour: 0)))
        case .month: .valueAligned(matching: DateComponents(weekday: Calendar.current.firstWeekday), majorAlignment: .matching(DateComponents(weekday: Calendar.current.firstWeekday)))
        }
    }

    private var yDomain: ClosedRange<Double> {
        if measurementType == .movement {
            guard let range = aggregatedData.range(by: { a, b in
                a.avg < b.avg
            }) else {
                return 0...0
            }
            return (range.min.avg / 1.1)...(range.max.avg * 1.1)
        } else {
//            guard let range = countData.max(by: { $0.count < $1.count }) else {
//                return 0...0
//            }
//            return 0...Double(range.count) * 1.1
            return 0...100
        }
    }

    private var currentRangeInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let firstDate = data.first?.date ?? now
        
        switch selectedRange {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .hour, value: 25, to: startOfDay)!
            return DateInterval(start: min(firstDate, startOfDay), end: endOfDay)

        case .week:
            let startOfWeek = calendar.startOfWeek(for: now)
            let endOfWeek = calendar.date(byAdding: .day, value: 8, to: startOfWeek)!
            return DateInterval(start: min(firstDate, startOfWeek), end: endOfWeek)

        case .month:
            let startOfMonth = calendar.startOfMonth(for: now)
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return DateInterval(start: min(firstDate, startOfMonth), end: endOfMonth)
        }
    }
    
    private var scrollPosition: Double {
        currentRangeInterval.start.timeIntervalSinceReferenceDate + (currentRangeInterval.end.timeIntervalSinceReferenceDate - currentRangeInterval.start.timeIntervalSinceReferenceDate) / 2.0
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
            chart
                .padding()
        }
        .background(Color.background)
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = .background
            UISegmentedControl.appearance().backgroundColor = .surface

            if measurementType == .muscleActivityMagnitude {
                dailyCountData = countMeasurementsOutsideThreshold(data, granularity: 3600.0)
                weeklyCountData = countMeasurementsOutsideThreshold(data, granularity: 8 * 3600.0)
                monthlyCountData = countMeasurementsOutsideThreshold(data, granularity: 24 * 3600.0)
            } else {
                dailyAggregatedData = minMaxSampling(data, granularity: 10 * 60.0)
                weeklyAggregatedData = minMaxSampling(data, granularity: 3600.0)
                monthlyAggregatedData = minMaxSampling(data, granularity: 4 * 3600.0)
            }
        }
    }

    private var chart: some View {
        Group {
            if measurementType == .movement {
                Chart(aggregatedData, id: \.self) { data in
                    LineMark(x: .value("", data.date), y: .value("", data.avg))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.approve)
                }
            } else {
                Chart {
                    ForEach(countData, id: \.self) { data in
                        BarMark(x: .value("", data.date), y: .value("", data.percentage), width: 24)
                            .foregroundStyle(Color.accent)
                    }
                    .clipShape(.capsule)
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollTargetBehavior(targetBehavior)
        .chartScrollPosition(initialX: scrollPosition)
        .chartYAxis(measurementType == .movement ? .hidden : .visible)
        //.chartYScale(domain: yDomain)
        .chartXScale(domain: currentRangeInterval.start...currentRangeInterval.end, range: .plotDimension(padding: 10))
        .chartXAxis {
            switch selectedRange {
            case .day:
                AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                    if let date = value.as(Date.self) {
                        let hour = Calendar.current.component(.hour, from: date)
                        AxisValueLabel {
                            VStack(alignment: .leading) {
                                Text(date, format: .dateTime.hour())
                                if hour == 0 {
                                    Text(date, format: .dateTime.month().day())
                                        .padding(.top, 2)
                                }
                            }
                        }
                        AxisGridLine()
                        if hour == 0 {
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        }
                    }
                }
            case .week:
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        let weekday = Calendar.current.component(.weekday, from: date)
                        AxisValueLabel {
                            VStack(alignment: .leading) {
                                Text(date, format: .dateTime.weekday())
                                if weekday == Calendar.current.firstWeekday {
                                    Text(date, format: .dateTime.month().day())
                                        .padding(.top, 2)
                                }
                            }
                        }
                        AxisGridLine()
                        if weekday == Calendar.current.firstWeekday {
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        }
                    }
                }
            case .month:
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    if let date = value.as(Date.self) {
                        let week = Calendar.current.component(.weekOfYear, from: date)
                        AxisValueLabel {
                            VStack(alignment: .leading) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                if week == 1 {
                                    Text(date, format: .dateTime.year())
                                        .padding(.top, 2)
                                }
                            }
                        }
                        AxisGridLine()
                        if week == 1 {
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }
                        
//    private func processMeasurementData(_ data: [MeasurementData], granularity: TimeInterval) -> [ProcessedData] {
//        guard !data.isEmpty else { return [] }
//        
//        func extendRange(_ range: ClosedRange<Double>?, with value: Double) -> ClosedRange<Double> {
//            guard let range else {
//                return value...value
//            }
//            return min(range.lowerBound, value)...max(range.upperBound, value)
//        }
//        
//        var results = [ProcessedData]()
//        
//        for measurement in data where measurement.calibrated {
//            let groupDate = Date(timeIntervalSince1970: floor(measurement.date.timeIntervalSince1970 / granularity) * granularity)
//            
//            if let lastResult = results.last, lastResult.date == groupDate {
//                var updatedLastResult = lastResult
//                
//                if measurement.aboveThreshold {
//                    updatedLastResult.aboveThresholdRange = extendRange(updatedLastResult.aboveThresholdRange, with: measurement.value)
//                } else if measurement.belowThreshold {
//                    updatedLastResult.belowThresholdRange = extendRange(updatedLastResult.belowThresholdRange, with: measurement.value)
//                } else {
//                    updatedLastResult.range = extendRange(updatedLastResult.range, with: measurement.value)
//                }
//                
//                results[results.count - 1] = updatedLastResult
//            } else {
//                let measurementRange = (measurement.value...measurement.value)
//                let range = measurement.aboveThreshold || measurement.belowThreshold ? nil : measurementRange
//                let aboveThresholdRange = measurement.aboveThreshold ? measurementRange : nil
//                let belowThresholdRange = measurement.belowThreshold ? measurementRange : nil
//                
//                results.append(.init(date: groupDate, range: range, aboveThresholdRange: aboveThresholdRange, belowThresholdRange: belowThresholdRange))
//            }
//        }
//        
//        return results
//    }
    
    private func countMeasurementsOutsideThreshold(_ data: [MeasurementData], granularity: TimeInterval) -> [CountMeasurementData] {
        guard !data.isEmpty else { return [] }
        guard let threshold = measurements.muscleActivityNormalRange else { return [] }
        
        var result: [CountMeasurementData] = []
        
        for measurement in data {
            let groupDate = Date(timeIntervalSince1970: floor(measurement.date.timeIntervalSince1970 / granularity) * granularity)
            
            if let last = result.last, last.date == groupDate {
                if threshold ~= measurement.value {
                    result[result.count - 1] = .init(insideCount: last.insideCount + 1, outsideCount: last.outsideCount, date: groupDate)
                } else {
                    result[result.count - 1] = .init(insideCount: last.insideCount, outsideCount: last.outsideCount + 1, date: groupDate)
                }
            } else {
                if threshold ~= measurement.value {
                    result.append(.init(insideCount: 1, outsideCount: 0, date: groupDate))
                } else {
                    result.append(.init(insideCount: 0, outsideCount: 1, date: groupDate))
                }
            }
        }
        
        return result
    }
    
    private func minMaxSampling(_ data: [MeasurementData], granularity: TimeInterval) -> [AggregatedData] {
        guard !data.isEmpty else { return [] }
        
        var results: [AggregatedData] = []
        
        for measurement in data {
            let bucketDate = Date(timeIntervalSince1970: floor(measurement.date.timeIntervalSince1970 / granularity) * granularity)
            
            if let lastResult = results.last, lastResult.date == bucketDate {
                var updatedLastResult = lastResult
                updatedLastResult.min = min(lastResult.min, measurement.value)
                updatedLastResult.max = max(lastResult.max, measurement.value)
                updatedLastResult.count += 1
                updatedLastResult.avg = (lastResult.avg * Double(lastResult.count - 1) + measurement.value) / Double(updatedLastResult.count)
                results[results.count - 1] = updatedLastResult
            } else {
                results.append(AggregatedData(
                    date: bucketDate,
                    min: measurement.value,
                    max: measurement.value,
                    avg: measurement.value,
                    count: 1
                ))
            }
        }
        
        return results
    }
}

#Preview {
    ChartView(measurementType: .muscleActivityMagnitude)
        .environment(MeasurementStore())
}
