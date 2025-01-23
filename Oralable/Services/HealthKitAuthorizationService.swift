//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import HealthKit

@MainActor
class HealthKitAuthorizationService {
    @Published public var heightAuthorized: Bool?
    @Published public var weightAuthorized: Bool?
    @Published public var dateOfBirthAuthorized: Bool?
    
    private var continuation: CheckedContinuation<Void, Never>?
    private var healthKit = HKHealthStore()
    
    let heightType = HKObjectType.quantityType(forIdentifier: .height)!
    let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
    
    init() {
        applyAuthorizationStatus()
    }
    
    func authorize() async {
        guard heightAuthorized == nil || weightAuthorized == nil || dateOfBirthAuthorized == nil else { return }
        
        try? await healthKit.requestAuthorization(toShare: [], read: [heightType, weightType, dateOfBirthType])
        
    }
    
    private func applyAuthorizationStatus() {
        switch healthKit.authorizationStatus(for: heightType) {
        case .notDetermined:
            heightAuthorized = nil
        case .sharingAuthorized:
            heightAuthorized = true
        default:
            heightAuthorized = false
        }

        switch healthKit.authorizationStatus(for: weightType) {
        case .notDetermined:
            weightAuthorized = nil
        case .sharingAuthorized:
            weightAuthorized = true
        default:
            weightAuthorized = false
        }
        
        switch healthKit.authorizationStatus(for: dateOfBirthType) {
        case .notDetermined:
            dateOfBirthAuthorized = nil
        case .sharingAuthorized:
            dateOfBirthAuthorized = true
        default:
            dateOfBirthAuthorized = false
        }
    }
}
