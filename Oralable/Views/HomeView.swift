//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    @State private var moreShown = false
    @State private var deviceShown = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Button {
                        moreShown = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .textStyle(.iconLarge(.accent))
                    }
                    .padding(.trailing)
                    .popover(isPresented: $moreShown) {
                        MoreView()
                    }
                    Spacer()
                    Button {
                        deviceShown = true
                    } label: {
                        Image(systemName: "wave.3.right.circle")
                            .textStyle(.iconLarge(.accent))
                    }
                    .padding(.leading)
                    .popover(isPresented: $deviceShown) {
                        DeviceView()
                    }
                }
                .padding(.bottom)
                Text("Hi, John A")
                    .textStyle(.headline())
                    .padding(.bottom)
                Text("Latest Measurements")
                    .textStyle(.subtitle())
                    .padding(.bottom)
                ScrollView {
                    VStack(spacing: 20) {
                        NavigationLink(value: MeasurementType.heartRate) {
                            MeasurementView(icon: "heart.fill", title: "Heart Rate", measurement: "86", unit: "bpm", classification: "Normal")
                        }
                        NavigationLink(value: MeasurementType.muscleActivity) {
                            MeasurementView(icon: "distribute.vertical.fill", title: "Muscle Activity", measurement: "9", unit: "%", classification: "Normal")
                        }
                        NavigationLink(value: MeasurementType.temperature) {
                            MeasurementView(icon: "medical.thermometer.fill", title: "Body Temperature", measurement: "36.7", unit: "°C", classification: "Normal")
                        }
                    }
                }
                .navigationDestination(for: MeasurementType.self) { _ in
                    ChartView()
                }
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    HomeView()
        .environment(MeasurementService())
}
