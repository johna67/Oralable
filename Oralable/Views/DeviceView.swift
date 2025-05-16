//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//
import SwiftUI

struct DeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BluetoothStore.self) private var bluetooth: BluetoothStore
    @Environment(MeasurementStore.self) private var measurements: MeasurementStore
    @State private var showAddDialog: Bool = false
    @State private var addingDevice: Bool = false
    @State private var showLimitAlert: Bool = false
    @State private var limitAlertTitle: String = ""
    @State private var limitAlertMessage: String = ""

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

            if !bluetooth.pairedDevices.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(bluetooth.pairedDevices, id: \.peripheralId) { device in
                            switch device.type {
                            case .tgm:
                                // Existing TGM device view
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(device.type.rawValue)
                                            .textStyle(.subtitle())
                                        Spacer()
                                        let status = bluetooth.statuses[device.peripheralId] ?? .disconnected
                                        Text(status.statusString)
                                            .textStyle(.body(status.statusColor))
                                    }
                                    .padding(.bottom, 4)

                                    HStack {
                                        Text("Battery:")
                                        Spacer()
                                        if let voltage = bluetooth.batteryVoltages[device.peripheralId] {
                                            Text(Measurement(value: Double(voltage), unit: UnitElectricPotentialDifference.millivolts).formatted())
                                        } else {
                                            Text("--")
                                        }
                                    }
                                    .padding(.bottom, 4)

                                    HStack {
                                        Text("Temperature:")
                                        Spacer()
                                        if let temp = measurements.temperature {
                                            Text(Measurement(value: temp, unit: UnitTemperature.celsius).formatted())
                                        } else {
                                            Text("--")
                                        }
                                    }
                                }
                                .padding()
                                .background(.surface)
                                .cornerRadius(6)
                                .textStyle(.smallBody())

                            case .anr:
                                // Existing ANR device view
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(device.type.rawValue)
                                            .textStyle(.subtitle())
                                        Spacer()
                                        let status = bluetooth.statuses[device.peripheralId] ?? .disconnected
                                        Text(status.statusString)
                                            .textStyle(.body(status.statusColor))
                                    }
                                    .padding(.bottom, 4)

                                    HStack {
                                        Text("Battery:")
                                        Spacer()
                                        if let percentage = bluetooth.batteryVoltages[device.peripheralId] {
                                            Text("\(percentage) %")
                                        } else {
                                            Text("--")
                                        }
                                    }
                                    .padding(.bottom, 4)
                                }
                                .padding()
                                .background(.surface)
                                .cornerRadius(6)
                                .textStyle(.smallBody())
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal)
                PrimaryButton(
                    icon: Image(systemName: "plus.circle.fill"),
                    title: "Add Device",
                    disabled: false,
                    progressing: addingDevice,
                    progressingTitle: "Finding device"
                ) {
                    showAddDialog = true
                }
                .padding()
            } else {
                Spacer()
                Text("No devices")
                    .textStyle(.subtitle(.foreground))
                Spacer()
                PrimaryButton(
                    icon: Image(systemName: "plus.circle.fill"),
                    title: "Add Device",
                    disabled: false,
                    progressing: addingDevice,
                    progressingTitle: "Finding device"
                ) {
                    showAddDialog = true
                }
                .padding()
            }
        }
        .padding()
        .background(Color.background)
        // Alert for max device limit
        .alert(limitAlertTitle, isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(limitAlertMessage)
        }
        // Dialog to select device type
        .confirmationDialog("Select Device Type", isPresented: $showAddDialog) {
            Button(DeviceType.anr.rawValue) {
                if bluetooth.pairedDevices.contains(where: { $0.type == .anr }) {
                    limitAlertTitle = "Device Limit Reached"
                    limitAlertMessage = "You can only add one ANR device."
                    showLimitAlert = true
                } else {
                    Task {
                        addingDevice = true
                        await bluetooth.addDevice(.anr)
                        addingDevice = false
                    }
                }
            }
            Button(DeviceType.tgm.rawValue) {
                if bluetooth.pairedDevices.contains(where: { $0.type == .tgm }) {
                    limitAlertTitle = "Device Limit Reached"
                    limitAlertMessage = "You can only add one TGM device."
                    showLimitAlert = true
                } else {
                    Task {
                        addingDevice = true
                        await bluetooth.addDevice(.tgm)
                        addingDevice = false
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
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
