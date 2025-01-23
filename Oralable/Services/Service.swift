//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//

import Factory
import Foundation

extension Container {
    var bluetoothService: Factory<BluetoothService> {
        Factory(self) { @MainActor in LiveBluetoothService() }
            .singleton
    }
    
    var bluetoothAuthorizationService: Factory<BluetoothAuthorizationService> {
        Factory(self) { @MainActor in BluetoothAuthorizationService() }
            .singleton
    }

    var persistenceService: Factory<PersistenceService> {
        Factory(self) { @MainActor in SwiftDataPersistence() }
            .singleton
    }
    
    var authService: Factory<AuthenticationService> {
        Factory(self) { @MainActor in LiveAuthenticationService() }
            .singleton
    }
    
    var healthKitService: Factory<HealthKitService> {
        Factory(self) { @MainActor in LiveHealthKitService()}
    }
}

extension Container: @retroactive AutoRegistering {
    public func autoRegister() {
        persistenceService.context(.preview, .simulator) {
            MockPersistenceService()
        }
        
        bluetoothService.context(.preview, .simulator) {
            MockBluetoothService()
        }
        
        healthKitService.context(.preview, .simulator) {
            MockHealthKitService()
        }
     }
}
