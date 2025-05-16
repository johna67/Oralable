//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Charts
import SwiftUI

struct MuscleActivityChartView: View {
    @Environment(MeasurementStore.self) var measurements: MeasurementStore
    @State private var selectedRange: ChartRange = .hour
    @State private var startTimeInterval = TimeInterval()
    
    @State private var hourlyData = [MeasurementData]()
    @State private var dailyData = [MeasurementData]()
    @State private var weeklyData = [MeasurementData]()
    
    @State private var hourlyThreshold: Double = 0
    @State private var dailyThreshold: Double = 0
    @State private var weeklyThreshold: Double = 0
    
    @State private var showAnnotationSheet = false
    
    @State private var selectedDate: Date?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    let measurementType: MeasurementType
    
    private var data: [MeasurementData] {
        switch measurementType {
        case .muscleActivityMagnitude:
            measurements.muscleActivityMagnitude
        case .movement:
            measurements.movement
        case .emg:
            measurements.emg
        default:
            []
        }
    }
    
    private enum ChartRange: String, CaseIterable, Identifiable {
        case hour = "Hour"
        case day = "Day"
        case week = "Week"
        
        var id: String { rawValue }
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
            .onChange(of: selectedRange) {
                selectedDate = nil
            }
            chart
        }
        .background(Color.background)
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = .background
            UISegmentedControl.appearance().backgroundColor = .surface
            
            let hourlyTouple = aggregateWithWeightedMedian(data, interval: 5)
            hourlyData = hourlyTouple.0
            hourlyThreshold = hourlyTouple.1
            
            let dailyTouple = aggregateWithWeightedMedian(data, interval: 24 * 5)
            dailyData = dailyTouple.0
            dailyThreshold = dailyTouple.1
            
            let weeklyTouple = aggregateWithWeightedMedian(data, interval: 7 * 24 * 5)
            weeklyData = weeklyTouple.0
            weeklyThreshold = weeklyTouple.1
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAnnotationSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .textStyle(.iconLarge(.accent))
                }
                .opacity(selectedDate == nil ? 0 : 1)
            }
        }
        .confirmationDialog(selectedDate?.formatted() ?? "", isPresented: $showAnnotationSheet, titleVisibility: .visible) {
            Button("Grinding") {
                measurements.addEvent(Event(date: selectedDate ?? Date(), type: .grinding))
                selectedDate = nil
            }
            Button("Clenching") {
                measurements.addEvent(Event(date: selectedDate ?? Date(), type: .clenching))
                selectedDate = nil
            }
            Button("Other") {
                measurements.addEvent(Event(date: selectedDate ?? Date(), type: .other))
                selectedDate = nil
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var chart: some View {
        Chart {
            ForEach(Array(measurements.events.values), id: \.self) { event in
                RuleMark(x: .value("", event.date))
                    .foregroundStyle(Color.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .annotation(position: .top) {
                        Text(event.type.rawValue)
                            .textStyle(.smallBody(.background))
                            .padding(6)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
            }
            ForEach(aggregatedData, id: \.self) { data in
                LineMark(x: .value("", data.date), y: .value("", data.value == -1 ? Double.nan : data.value))
                //.interpolationMethod(.monotone)
                    .foregroundStyle(gradient)
                
                if let selectedDate {
                    RuleMark(x: .value("", selectedDate))
                        .annotation(position: .bottom, overflowResolution: .init(x: .disabled, y: .fit)) {
                            Text(selectedDate.formatted())
                                .padding(6)
                                .textStyle(.smallBody())
                                .background(Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .offset(y: -36)
                        }
                        .foregroundStyle(Color.gray)
                }
            }
        }
        .chartPlotStyle {
            $0
                .padding(.top, 30)
                .padding(.horizontal, 30)
        }
        //.chartXSelection(value: $selectedDate)
        .chartGesture { chartProxy in
            SpatialTapGesture().onEnded { value in
                selectedDate = chartProxy.value(atX: value.location.x, as: Date.self)
            }
            .simultaneously(with: MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    scale *= delta
                    scale = max(0.5, min(scale, 5)) // Clamp scale between 0.5x and 5x
                }
                .onEnded { _ in
                    lastScale = 1.0
                })
        }
        .chartScrollableAxes(.horizontal)
        //.chartScrollTargetBehavior(targetBehavior)
        .chartScrollPosition(initialX: scrollPosition)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartXVisibleDomain(length: visibleDomainLength)
        //.chartXScale(domain: currentRangeInterval.start...currentRangeInterval.end, range: .plotDimension(padding: 20))
        
        .chartXAxis {
            switch selectedRange {
            case .hour:
                AxisMarks(values: dateMarks) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            case .day:
                AxisMarks(values: dateMarks) { value in
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
                AxisMarks(values: dateMarks) { value in
                    if let date = value.as(Date.self) {
                        let weekday = Calendar.current.component(.weekday, from: date)
                        AxisValueLabel {
                            VStack(alignment: .leading) {
                                Text(date, format: .dateTime.weekday())
                                //                                if weekday == Calendar.current.firstWeekday {
                                Text(date, format: .dateTime.month().day())
                                    .padding(.top, 2)
                                //                                }
                            }
                        }
                        AxisGridLine()
                        if weekday == Calendar.current.firstWeekday {
                            AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }
}

extension MuscleActivityChartView {
    private var gradient: LinearGradient {
        var threshold: Double
        switch selectedRange {
        case .hour:
            threshold = hourlyThreshold
        case .day:
            threshold = dailyThreshold
        case .week:
            threshold = weeklyThreshold
        }
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.approve, location: 0.0),
                .init(color: Color.approve, location: threshold),
                .init(color: Color.accent, location: threshold),
                .init(color: Color.accent, location: 1.0)
            ]),
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    private var aggregatedData: [MeasurementData] {
        switch selectedRange {
        case .hour:
            hourlyData
        case .day:
            dailyData
        case .week:
            weeklyData
        }
    }
    
    private var targetBehavior: ValueAlignedChartScrollTargetBehavior {
        switch selectedRange {
        case .hour: .valueAligned(matching: DateComponents(second: 0), majorAlignment: .matching(DateComponents(second: 0)))
        case .day: .valueAligned(matching: DateComponents(minute: 0), majorAlignment: .matching(DateComponents(minute: 0)))
        case .week: .valueAligned(matching: DateComponents(hour: 0), majorAlignment: .matching(DateComponents(hour: 0)))
        }
    }
    
    private var yDomain: ClosedRange<Double> {
        return -0.1...1.1
    }
    
    private var scrollPosition: Double {
        aggregatedData.last?.date.timeIntervalSinceReferenceDate ?? Date().timeIntervalSinceReferenceDate
    }
    
    private var dateMarks: [Date] {
        guard let start = aggregatedData.first?.date, let end = aggregatedData.last?.date else { return [] }
        let calendar = Calendar.current
        
        switch selectedRange {
        case .hour:
            return stride(from: calendar.lowerBound(of: start, minutes: 15), through: calendar.upperBound(of: end, minutes: 15), by: 15 * 60).map { $0 }
            
        case .day:
            return stride(from: calendar.startOfDay(for: start), through: calendar.endOfDay(for: end), by: 2 * 60 * 60).map { $0 }
            
        case .week:
            return stride(from: calendar.startOfWeek(for: start), through: calendar.endOfWeek(for: end), by: 24 * 60 * 60).map { $0 }
        }
    }
    
    private var visibleDomainLength: TimeInterval {
        let baseLength: TimeInterval
        switch selectedRange {
        case .hour:
            baseLength = 500
        case .day:
            baseLength = 24 * 500
        case .week:
            baseLength = 7 * 24 * 500
        }
        return baseLength / Double(scale)
    }
    
    private func weightedMedian(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let totalWeight = values.reduce(0.0, +)
        var cumulativeWeight = 0.0
        
        for value in values {
            cumulativeWeight += value
            if cumulativeWeight >= totalWeight / 2 {
                return value
            }
        }
        
        return 0
    }
        
    private func aggregateWithWeightedMedian(_ data: [MeasurementData], interval: TimeInterval = 5.0) -> ([MeasurementData], Double) {
        guard !data.isEmpty else { return ([], 0) }
        
        var result: [MeasurementData] = []
        var window: [Double] = []
        var startTime = data.first!.date
        
        for entry in data {
            if entry.date.timeIntervalSince(startTime) > interval {
                if !window.isEmpty {
                    let aggregatedValue = weightedMedian(window)
                    result.append(MeasurementData(date: startTime, value: aggregatedValue))
                }
                startTime = entry.date
                window = []
            }
            window.append(entry.value)
        }
        
        // Process last window
        if !window.isEmpty {
            let aggregatedValue = weightedMedian(window)
            result.append(MeasurementData(date: startTime, value: aggregatedValue))
        }
        
        let normalized = normalize(data)
        
        return (fillMissingIntervals(normalized.0, interval: interval), normalized.1)
    }
    
    func normalize(_ data: [MeasurementData]) -> ([MeasurementData], Double) {
        guard let minValue = data.map({ $0.value }).min(),
              let maxValue = data.map({ $0.value }).max(),
              minValue != maxValue else {
            
            return (data.map { MeasurementData(date: $0.date, value: 0.0) }, 0)
        }
        let normalized = data.map { measurement in
            let normalizedValue = (measurement.value - minValue) / (maxValue - minValue)
            return MeasurementData(date: measurement.date, value: normalizedValue)
        }
        
        var threshold = measurements.thresholdPercentage
        switch measurementType {
        case .muscleActivityMagnitude:
            if let thresholdValue = measurements.muscleActivityThreshold {
                threshold = (thresholdValue - minValue) / (maxValue - minValue) * (1 + measurements.thresholdPercentage)
            }
        case .movement:
            if let thresholdValue = measurements.movementThreshold {
                threshold = (thresholdValue - minValue) / (maxValue - minValue) * (1 + measurements.thresholdPercentage)
            }
        case .emg:
            if let thresholdValue = measurements.emgThreshold {
                threshold = (thresholdValue - minValue) / (maxValue - minValue) * (1 + measurements.thresholdPercentage)
            }
        default:
            break
        }
        
        return (normalized, threshold)
    }
    
    func fillMissingIntervals(_ data: [MeasurementData], interval: TimeInterval = 5.0) -> [MeasurementData] {
        guard !data.isEmpty else { return [] }

        let sorted = data.sorted { $0.date < $1.date }

        let firstDate = sorted.first!.date
        let lastDate  = sorted.last!.date
        let lastIdx   = Int(round(lastDate.timeIntervalSince(firstDate) / interval))

        var bucketDict: [Int: MeasurementData] = [:]
        for m in sorted {
            let idx = Int(round(m.date.timeIntervalSince(firstDate) / interval))
            bucketDict[idx] = m
        }

        var filled: [MeasurementData] = []
        filled.reserveCapacity(lastIdx + 1)

        for idx in 0...lastIdx {
            if let m = bucketDict[idx] {
                filled.append(m)
            } else {
                let bucketDate = firstDate.addingTimeInterval(Double(idx) * interval)
                filled.append(MeasurementData(date: bucketDate, value: -1))
            }
        }

        return filled
    }
}

#Preview {
    NavigationStack {
        MuscleActivityChartView(measurementType: .muscleActivityMagnitude)
            .environment(MeasurementStore())
    }
}
