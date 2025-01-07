//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI
import Charts

struct MeasurementView: View {
    let measurementType: MeasurementType
    
    @Environment(MeasurementService.self) private var measurementService
    
    private var data: [MeasurementData] {
        switch measurementType {
        case .muscleActivityMagnitude:
            return measurementService.muscleActivityMagnitude.suffix(60)
        case .movement:
            return measurementService.movement.suffix(60)
        default:
            return []
        }
    }
    
    private var measurementHidden: Bool {
        measurementType == .muscleActivityMagnitude || measurementType == .movement
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
                    //Spacer()
                }
                chart
                    .frame(height: 80)
            }
            HStack {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .textStyle(.icon(.approve))
                    //TODO: this classification should be done by MeasurementService
                    Text("Normal")
                        .textStyle(.body())
                    Spacer()
                }
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
//            RectangleMark(
//                xStart: .value("Date", data[data.count - 20].date),
//                xEnd: .value("Date", data[data.count - 5].date),
//                yStart: .value("Value", 0),
//                yEnd: .value("Value", 1000000)
//            )
//            .foregroundStyle(.blue.opacity(0.1))
        }
        .foregroundStyle(.tint)
        .chartXVisibleDomain(length: 60)
        //.chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview {
    ScrollView {
        MeasurementView(measurementType: .temperature)
            .environment(MeasurementService())
            //.frame(height: 150)
            .padding()
    }
}
