//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Charts
import SwiftUI

struct ChartView: View {
    @Environment(MeasurementStore.self) var measurements: MeasurementStore
    @State private var selectedRange: ChartRange = .day
    @State private var startTimeInterval = TimeInterval()
    @State private var data = [MeasurementData]()
    let measurementType: MeasurementType
    let lowerThreshold = 0.0
    let upperThreshold = 300000.0

    private enum ChartRange: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }
    }

    private var targetBehavior: ValueAlignedChartScrollTargetBehavior {
        switch selectedRange {
        case .day: .valueAligned(matching: DateComponents(minute: 0), majorAlignment: .matching(DateComponents(minute: 0)))
        case .week: .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(hour: 0)))
        case .month: .valueAligned(matching: DateComponents(weekday: Calendar.current.firstWeekday), majorAlignment: .matching(DateComponents(weekday: Calendar.current.firstWeekday)))
        }
    }

    private var yDomain: ClosedRange<Double> {
        let min = data.min { point1, point2 in
            point1.value < point2.value
        }

        let max = data.min { point1, point2 in
            point1.value > point2.value
        }

        guard let min, let max else { return 0 ... 0 }
        return min.value ... max.value
    }

    private var currentRangeInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let firstDate = data.first?.date ?? now
        let distance = firstDate.distance(to: Date())
        
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
                .onAppear {
                    data = {
                        switch measurementType {
                        case .muscleActivityMagnitude:
                            measurements.muscleActivityMagnitude
                        case .movement:
                            measurements.movement
                        default:
                            []
                        }
                    }()
                }
        }
    }

    private var chart: some View {
        Chart {
 //           ForEach(data, id: \.self) { measurement in
//                PointMark(
//                    x: .value("Date", measurement.date),
//                    y: .value("Value", measurement.value)
//                )
//                BarMark(
//                    x: .value("Time", measurement.date, unit: .minute), // Use daily bins
//                    y: .value("Out of Range Count", measurement.value < lowerThreshold || measurement.value > upperThreshold ? 1 : 0)
//                    )
                
                ForEach(groupedData, id: \.0) { binStart, count in
                                BarMark(
                                    x: .value("Time Bin", binStart),
                                    y: .value("Out of Range Count", count)
                                )
                                .foregroundStyle(Color.blue)
                            }
    //        }

//             PointPlot(data, x: .value("Date", \.date), y: .value("Value", \.value))
        }
        .foregroundStyle(.tint.opacity(0.2))
        .chartScrollableAxes(.horizontal)
        .chartScrollTargetBehavior(targetBehavior)
        .chartScrollPosition(initialX: scrollPosition)
        //.chartYAxis(.hidden)
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
    
    private var groupedData: [(Date, Int)] {
            let calendar = Calendar.current
            var bins: [Date: Int] = [:]

            for measurement in data {
                // Find the start of the bin (round down to the nearest 10 minutes)
                let binStart = calendar.date(
                    bySetting: .minute,
                    value: (calendar.component(.minute, from: measurement.date) / 10) * 10,
                    of: measurement.date
                ) ?? measurement.date

                // Increment the count if the value is outside the threshold range
                if measurement.value < lowerThreshold || measurement.value > upperThreshold {
                    bins[binStart, default: 0] += 1
                }
            }

            // Convert dictionary to sorted array
            return bins.sorted { $0.key < $1.key }
        }
}

#Preview {
    ChartView(measurementType: .heartRate)
        .environment(MeasurementStore())
}
