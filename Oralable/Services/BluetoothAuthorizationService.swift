//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import CoreBluetooth

@MainActor
class BluetoothAuthorizationService: NSObject {
    @Published public var authorized: Bool?
    
    private var continuation: CheckedContinuation<Void, Never>?
    private var centralManager: CBCentralManager?
    
    override init() {
        super.init()
        
        applyAuthorizationStatus()
    }
    
    func authorize() async {
        guard authorized == nil else { return }
        
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
    }
    
    private func applyAuthorizationStatus() {
        switch CBManager.authorization {
        case .notDetermined:
            authorized = nil
        case .allowedAlways:
            authorized = true
        default:
            authorized = false
        }
    }
}

extension BluetoothAuthorizationService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ centralManager: CBCentralManager) {
        applyAuthorizationStatus()
        continuation?.resume()
        continuation = nil
    }
}
