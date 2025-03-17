//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import SwiftUI

struct DeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BluetoothStore.self) private var bluetooth: BluetoothStore
    @Environment(MeasurementStore.self) private var measurements: MeasurementStore
    @State private var addingDevice: Bool = false

    private var statusString: String {
        switch bluetooth.status {
        case .connected:
            "Connected"
        case .connecting:
            "Connecting..."
        case .disconnected:
            "Disconnected"
        }
    }

    private var statusColor: Color {
        switch bluetooth.status {
        case .connected:
            Color.approve
        case .connecting:
            .blue
        case .disconnected:
            .red
        }
    }

    var body: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .textStyle(.iconLarge(.accent))
                        .padding(.top)
                }
                Spacer()
            }
            HStack {
                Text("Devices")
                    .textStyle(.headline())
                    .padding(.top)
                Spacer()
            }
            if let device = bluetooth.pairedDevice {
                ScrollView {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(device.type.rawValue)
                                .textStyle(.subtitle())
                            Spacer()
                            Text(statusString)
                                .textStyle(.body(statusColor))
                        }
                        .padding(.bottom)
                        HStack {
                            Spacer()
                            Text("Battery:")
                            Text(Measurement(value: Double(bluetooth.battery ?? 0), unit: UnitElectricPotentialDifference.millivolts).formatted())
                        }
                        .padding(.bottom)
                        HStack {
                            Spacer()
                            Text("Temperature:")
                            Text(Measurement(value: Double(measurements.temperature ?? 0), unit: UnitTemperature.celsius).formatted())
                        }
                        .padding(.bottom)
                    }
                    .padding()
                    .background(.surface)
                    .cornerRadius(6)
                    .textStyle(.smallBody())
                }
            } else {
                Spacer()
                Text("No devices")
                    .textStyle(.subtitle(.foreground))
                Spacer()
                PrimaryButton(icon: Image(systemName: "plus.circle.fill"), title: "Add device", disabled: false, progressing: addingDevice, progressingTitle: "Finding device") {
                    Task {
                        addingDevice = true
                        await bluetooth.addDevice(.tgm)
                        addingDevice = false
                    }
                }
                .padding()
            }
        }
        .padding()
        .background(Color.background)
    }
}

extension BluetoothStore.ConnectionStatus {
    var statusString: String {
        switch self {
        case .connected:
            "Connected"
        case .connecting:
            "Connecting..."
        case .disconnected:
            "Disconnected"
        }
    }

    var statusColor: Color {
        switch self {
        case .connected:
            Color.approve
        case .connecting:
            .blue
        case .disconnected:
            .red
        }
    }
}

#Preview {
    DeviceView()
        .environment(BluetoothStore())
        .environment(MeasurementStore())
}
