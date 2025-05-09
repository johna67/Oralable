//
//  OralableApp.swift
//  Oralable
//
//  Created by John A Cogan on 10/09/2024.
//

import LogKit
import SwiftUI

@main
struct OralableApp: App {
    private let measurementStore = MeasurementStore()
    private let bluetoothStore = BluetoothStore()
    private let userStore = UserStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(measurementStore)
                .environment(bluetoothStore)
                .environment(userStore)
        }
    }
}
