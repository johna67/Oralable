//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    @State private var moreShown = false
    @State private var deviceShown = false
    @Environment(MeasurementStore.self) private var measurements

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
                        if measurements.muscleActivityNormalRange != nil {
                            NavigationLink(value: MeasurementType.muscleActivityMagnitude) {
                                MeasurementView(measurementType: .muscleActivityMagnitude)
                            }
                        } else {
                            MeasurementView(measurementType: .muscleActivityMagnitude)
                        }

                        NavigationLink(value: MeasurementType.movement) {
                            MeasurementView(measurementType: .movement)
                        }
                    }
                }
                .navigationDestination(for: MeasurementType.self) { type in
                    ChartView(measurementType: type)
                }
                Spacer()
            }
            .padding()
            .background(Color.background)
        }
    }
}

#Preview {
    HomeView()
        .environment(MeasurementStore())
        .environment(BluetoothStore())
}
