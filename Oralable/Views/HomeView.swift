//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    @State private var moreShown = false
    @State private var deviceShown = false
    @Environment(MeasurementStore.self) private var measurements
    @Environment(UserStore.self) private var userStore

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
                Text(greeting)
                    .textStyle(.headline())
                    .minimumScaleFactor(0.5)
                HStack {
                    Text(userStats)
                        .textStyle(.subtitle())
                    Spacer()
                }
                .padding()
                .background(.surface)
                .cornerRadius(6)
                .padding(.bottom)
                Text("Latest Measurements")
                    .textStyle(.subtitle())
                    .padding([.top, .bottom])
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
                        PrimaryButton(title: "Calibrate", progressing: measurements.calibrating, progressingTitle: "Calibrating") {
                            measurements.calibrate()
                        }
                    }
                }
                .navigationDestination(for: MeasurementType.self) { type in
                    ChartView(measurementType: type)
                }
                .edgesIgnoringSafeArea(.bottom)
                Spacer()
            }
            .padding()
            .background(Color.background)
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    private var userStats: String {
        var components: [String] = []

        if let age = userStore.user?.age {
            components.append("\(age) years old")
        }
        
        if let height = userStore.user?.height {
            components.append("\(height) cm")
        }
        
        if let weight = userStore.user?.weight {
            components.append("\(String(format: "%.1f", weight)) kg")
        }
        
        return components.joined(separator: ", ") + "."
    }
    
    private var greeting: String {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let greeting: String

        switch currentHour {
        case 6..<12:
            greeting = "Good morning"
        case 12..<18:
            greeting = "Good afternoon"
        case 18..<24:
            greeting = "Good evening"
        default:
            greeting = "Good night"
        }

        if let firstName = userStore.user?.firstName, !firstName.isEmpty {
            return "\(greeting), \(firstName)"
        } else {
            return greeting
        }
    }
}

#Preview {
    HomeView()
        .environment(MeasurementStore())
        .environment(BluetoothStore())
        .environment(UserStore())
}
