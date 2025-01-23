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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(MeasurementStore())
                .environment(BluetoothStore())
                .environment(UserStore())
        }
    }
}
