//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation
import HealthKit
import LogKit

protocol HealthKitService: Sendable {
    func readWeight() async -> Double?
    func readHeight() async -> Double?
    func readAge() async -> Int?
}

final class LiveHealthKitService: HealthKitService {
    private let healthKit = HKHealthStore()
    
    func readHeight() async -> Double? {
        await fetchMostRecentSample(for: .quantityType(forIdentifier: .height))
    }
    
    func readWeight() async -> Double? {
        await fetchMostRecentSample(for: .quantityType(forIdentifier: .bodyMass))
    }
    
    func readAge() async -> Int? {
        guard let birthdayComponents = try? healthKit.dateOfBirthComponents() else { return nil }
        print(birthdayComponents)
        guard let birthday = Calendar.current.date(from: birthdayComponents) else { return nil }
        
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
    }
    
    private func fetchMostRecentSample(for type: HKQuantityType?) async -> Double? {
        guard let type else { return nil }
        guard let unit = try? await healthKit.preferredUnits(for: [type]).first?.value else { return nil }
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    Log.error("Error fetching sample: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            healthKit.execute(query)
        }
    }
}

final class MockHealthKitService: HealthKitService {
    func readWeight() async -> Double? {
        78.5
    }
    
    func readHeight() async -> Double? {
        179.5
    }
    
    func readAge() async -> Int? {
        42
    }
}
