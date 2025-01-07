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
    let measurementType: MeasurementType
    
    private enum ChartRange: String, CaseIterable, Identifiable {
//        case minute = "Minute"
//        case hour = "Hour"
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
//    private var chartScrollMatching: DateComponents {
//        return switch selectedRange {
//        case .minute: DateComponents(minute: 0)
//        case .hour: DateComponents(minute: 15)
//        case .day: DateComponents(hour: 6)
//        case .week: DateComponents(weekday: 0)
//        case .month: DateComponents(day: 1)
//        }
//    }
    
    private var visibleDomainLength: Double {
        return switch selectedRange {
//        case .minute: 60
//        case .hour: 3600
        case .day: 3600 * 24
        case .week: 3600 * 24 * 7
        case .month: 3600 * 24 * 30
        }
    }
    
    private var targetBehavior: ValueAlignedChartScrollTargetBehavior {
        return switch selectedRange {
//        case .minute: .valueAligned(matching: DateComponents(minute: 0), majorAlignment: .matching(DateComponents(minute: 0)))
//        case .hour: .valueAligned(matching: DateComponents(minute: 0), majorAlignment: .matching(DateComponents(hour: 0)))
        case .day: .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(hour: 0)))
        case .week: .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(weekday: 1)))
        case .month: .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(day: 1)))
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
    
    private var data: [MeasurementData] {
        switch measurementType {
        case .muscleActivityMagnitude:
            return measurementService.muscleActivityMagnitude
        case .movement:
            return measurementService.movement
        default:
            return []
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
//                LineMark(
//                    x: .value("Date", measurement.date),
//                    y: .value("Value", measurement.value)
//                )

                PointMark(
                    x: .value("Date", measurement.date),
                    y: .value("Value", measurement.value)
                )
            }
            
            //PointPlot(data, x: .value("Date", \.date), y: .value("Value", \.value))
        }
        .foregroundStyle(.tint.opacity(0.2))
        .chartScrollableAxes(.horizontal)
        //.chartXScale(range: .plotDimension(padding: 10))
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
    ChartView(measurementType: .heartRate)
        .environment(MeasurementService())
}
