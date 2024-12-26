//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI
import Charts

struct MeasurementView: View {
    let measurementCategory: Measurements.Category
    
    @Environment(MeasurementService.self) private var measurementService: MeasurementService
    
    private var measurement: Measurements? {
        measurementService.measurements.first { $0.category == measurementCategory }
    }
    
    private var data: [MeasurementPoint] {
        measurement?.data.suffix(10) ?? []
    }
    
    private var dateInterval: DateInterval {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay =  Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
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
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: measurement?.category.icon ?? "")
                    .textStyle(.icon(.accent))
                Text(measurementCategory.name)
                    .textStyle(.subtitle())
                Spacer()
                Image(systemName: "arrow.right")
                    .textStyle(.icon())
                    .padding(.bottom)
            }
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(measurement?.data.last?.value ?? 0, format: .number.precision(.fractionLength(0)))
                            .textStyle(.headline())
                        Text(measurement?.category.unit ?? "")
                            .textStyle(.subtitle())
                            .padding(.trailing, 20)
                    }
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .textStyle(.icon(.approve))
                        Text(measurement?.classification.rawValue ?? "N/A")
                            .textStyle(.body())
                    }
                }
                chart
                    .frame(height: 80)
            }
        }
        .padding()
        .background(.surface)
        .cornerRadius(6)
    }
    
    private var chart: some View {
        Chart {
            ForEach(data, id: \.self) { measurement in
                LineMark(
                    x: .value("Date", measurement.date),
                    y: .value("Value", measurement.value)
                )
            }
        }
        .foregroundStyle(.tint)
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview {
    ScrollView {
        MeasurementView(measurementCategory: .temperature)
            .environment(MeasurementService())
            //.frame(height: 150)
            .padding()
    }
}
