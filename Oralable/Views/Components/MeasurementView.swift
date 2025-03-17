//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Charts
import SwiftUI

struct MeasurementView: View {
    let measurementType: MeasurementType

    @Environment(MeasurementStore.self) private var measurements
    @Environment(BluetoothStore.self) private var bluetooth
    
    @State private var chartColor: Color = .accent
    
    private let historySeconds = 30.0

    private var data: [MeasurementData] {
        let now = Date()
        switch measurementType {
        case .muscleActivityMagnitude:
            return Array(measurements.muscleActivityMagnitude.suffix {
                $0.date >= now.addingTimeInterval(-historySeconds)
            })
        case .movement:
            return Array(measurements.movement.suffix {
                $0.date >= now.addingTimeInterval(-historySeconds)
            })
        default:
            return []
        }
    }

    private var measurementHidden: Bool {
        measurementType == .muscleActivityMagnitude || measurementType == .movement || measurementType == .muscleActivity
    }
    
    private var statusText: String {
        guard bluetooth.status == .connected else {
             return "Disconnected"
        }
        switch measurements.status {
        case .active:
            return "Active"
        case .calibrating:
            return "Calibrating"
        case .inactive:
            return "Inactive"
        }
    }
    
    private var indicatorColor: Color {
        guard bluetooth.status == .connected else {
            return Color.gray
        }
        switch measurements.status {
        case .active:
            return Color.approve
        case .calibrating:
            return Color.warning
        case .inactive:
            return Color.warning
        }
    }
    
    private var underThreshold: Bool {
        guard let threshold = measurements.muscleActivityThreshold, let value = data.last?.value else { return true }
        return value < threshold
    }

    private var dateInterval: DateInterval {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
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
        DateInterval(start: Calendar.current.date(byAdding: .second, value: Int(-historySeconds), to: Date())!, end: Date())
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: measurementType.icon)
                    .textStyle(.icon(.accent))
                Text(measurementType.name)
                    .textStyle(.subtitle())
                Spacer()
                Image(systemName: "arrow.right")
                    .textStyle(.icon())
                    .padding(.bottom)
            }
            HStack {
                VStack(alignment: .leading) {
                    if !measurementHidden {
                        HStack(alignment: .lastTextBaseline) {
                            Text(data.last?.value ?? 0, format: .number.precision(.fractionLength(0)))
                                .textStyle(.headline())
                            Text(measurementType.unit)
                                .textStyle(.subtitle())
                                .padding(.trailing, 20)
                        }
                    }
                }
                chart
                    .frame(height: 80)
            }
            HStack {
                ConnectionIndicatorView(connected: bluetooth.status == .connected)
                if bluetooth.status == .connected {
                    Text(statusText)
                        .textStyle(.body(indicatorColor))
                }
                
                Spacer()
            }
            .foregroundStyle(indicatorColor)
        }
        .padding()
        .background(.surface)
        .cornerRadius(6)
    }

    private var chart: some View {
        Chart(data, id: \.date) {
            LineMark(
                x: .value("", $0.date),
                y: .value("", $0.value)
            )
            .interpolationMethod(.monotone)
        }
        .foregroundStyle(underThreshold ? Color.approve : Color.accent)
        .chartXScale(domain: currentRangeInterval.start...currentRangeInterval.end)
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview {
    ScrollView {
        MeasurementView(measurementType: .muscleActivityMagnitude)
            .environment(MeasurementStore())
            .environment(BluetoothStore())
            .padding()
    }
}
