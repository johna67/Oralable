//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Foundation
import Factory

extension Container {
    var bluetoothService: Factory<BluetoothService> {
        Factory(self) { @MainActor in BluetoothService() }
            .singleton
    }
    
    var persistenceService: Factory<PersistenceService> {
        Factory(self) { @MainActor in SwiftDataPersistence() }
            .singleton
    }
}
