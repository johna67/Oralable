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
    
    private enum ChartRange: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
    private var chartScrollMatching: DateComponents {
        switch selectedRange {
        case .day:
            return DateComponents(hour: 0)
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
    
    private var filteredData: [Measurement] {
        measurementService.data.first?.measurements ?? []
//        guard let series = measurementService.data.first else {
//            return []
//        }
//        return series.measurements
//            .filter { $0.date >= currentRangeInterval.start && $0.date < currentRangeInterval.end }
//            .sorted { $0.date < $1.date }
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
            
            if startTimeInterval != 0 {
                Text(Date(timeIntervalSinceReferenceDate: startTimeInterval), format: .dateTime.year().month().day().hour().minute())
                    .textStyle(.body())
            }
        
            chart
                .padding()
                .padding()
                .onAppear {
                    startTimeInterval = Calendar.current.startOfDay(for: Date()).timeIntervalSinceReferenceDate
                }
        }
    }
    
    private var chart: some View {
        Chart {
            ForEach(filteredData, id: \.self) { measurement in
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
        //.chartXScale(domain: currentRangeInterval.start...currentRangeInterval.end)
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartXAxis {
            switch selectedRange {
            case .day:
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel(format: .dateTime.hour())
                    AxisGridLine()
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                }
            case .week:
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: dateFormatForXAxis)
                }
            case .month:
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: dateFormatForXAxis)
                }
            }
        }
        .chartScrollTargetBehavior(.paging)
//            .chartScrollTargetBehavior(.valueAligned(
//                matching: chartScrollMatching,
//                majorAlignment: .matching(DateComponents(day: 1))
//            ))
        .chartScrollPosition(x: $startTimeInterval)
    }
}

#Preview {
    ChartView()
        .environment(MeasurementService())
}
