//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI
import Charts

struct ChartView: View {
    @Environment(MeasurementService.self) var measurementService: MeasurementService
    @State private var selectedRange: ChartRange = .day
    @State private var startTimeInterval = TimeInterval()
    let measurementCategory: Measurements.Category
    
    private enum ChartRange: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
    private var chartScrollMatching: DateComponents {
        switch selectedRange {
        case .day:
            return DateComponents(hour: 6)
        case .week:
            return DateComponents(weekday: 0)
        case .month:
            return DateComponents(day: 1)
        }
    }
    
    private var visibleDomainLength: Double {
        switch selectedRange {
        case .day:
            return 3600 * 24
        case .week:
            return 3600 * 24 * 7
        case .month:
            return 3600 * 24 * 30
        }
    }
    
    private var targetBehavior: ValueAlignedChartScrollTargetBehavior {
        switch selectedRange {
        case .day:
            return .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(hour: 0)))
        case .week:
            return .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(weekday: 1)))
        case .month:
            return .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(day: 1)))
        }
    }
    private var yDomain: ClosedRange<Double> {
        let min = data.min { point1, point2 in
            point1.value < point2.value
        }
        
        let max = data.min { point1, point2 in
            point1.value > point2.value
        }
        
        guard let min, let max else { return 0...0 }
        return min.value...max.value
    }
    
//    private var currentRangeInterval: DateInterval {
//        let calendar = Calendar.current
//        let now = Date()
//        
//        switch selectedRange {
//        case .day:
//            let startOfDay = calendar.startOfDay(for: now)
//            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
//            return DateInterval(start: startOfDay, end: endOfDay)
//            
//        case .week:
//            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
//                let startOfWeek = calendar.startOfDay(for: now)
//                let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
//                return DateInterval(start: startOfWeek, end: endOfWeek)
//            }
//            return weekInterval
//            
//        case .month:
//            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
//                let startOfMonth = calendar.startOfDay(for: now)
//                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
//                return DateInterval(start: startOfMonth, end: endOfMonth)
//            }
//            return monthInterval
//        }
//    }
    
    private var data: [MeasurementPoint] {
        measurementService.measurements.first { $0.category == measurementCategory }?.data ?? []
    }
    
    private var dateFormatForXAxis: Date.FormatStyle {
        switch selectedRange {
        case .day:
            return .dateTime.hour()
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.weekday(.abbreviated).day()
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
            chart
                .padding()
        }
    }
    
    private var chart: some View {
        Chart {
            ForEach(data, id: \.self) { measurement in
                LineMark(
                    x: .value("Date", measurement.date),
                    y: .value("Value", measurement.value)
                )

                PointMark(
                    x: .value("Date", measurement.date),
                    y: .value("Value", measurement.value)
                )
                .symbol(Circle())
            }
        }
        .foregroundStyle(.tint)
        .chartScrollableAxes(.horizontal)
        .chartXScale(range: .plotDimension(padding: 10))
        .chartYScale(domain: yDomain)
        //.chartXScale(domain: currentRangeInterval.start...currentRangeInterval.end)
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartXAxis {
            switch selectedRange {
            case .day:
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
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
                                if weekday == 1 {
                                    Text(date, format: .dateTime.month().day())
                                        .padding(.top, 2)
                                }
                            }
                        }
                        AxisGridLine()
                        if weekday == 1 {
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
        //.chartScrollTargetBehavior(.paging)
        .chartScrollTargetBehavior(targetBehavior)
//        .chartScrollPosition(x: $startTimeInterval)
        .chartScrollPosition(initialX: Calendar.current.startOfDay(for: Date()).timeIntervalSinceReferenceDate)
    }
}

#Preview {
    ChartView(measurementCategory: .heartRate)
        .environment(MeasurementService())
}
