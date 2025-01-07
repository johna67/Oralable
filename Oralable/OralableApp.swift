//
//  OralableApp.swift
//  Oralable
//
//  Created by John A Cogan on 10/09/2024.
//

import SwiftUI
import LogKit

@main
struct OralableApp: App {
    @State private var bluetooth = BluetoothStore()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(MeasurementService())
                .environment(bluetooth)
        }
    }
}
