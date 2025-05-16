//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation

final class MockPersistenceService: PersistenceService {
    func exportAllToJson() throws -> Data {
        Data()
    }
    
    func writeEvent(_ event: Event) {
        
    }
    
    func readEvents(limit: Int?) -> [Event] {
        [
            Event(date: Date().addingTimeInterval(-200 * 60), type: .clenching),
            Event(date: Date().addingTimeInterval(-5 * 60), type: .grinding),
        ]
    }
    
    func readUser() -> User? {
        User(firstName: "John", lastName: "Test", email: "john@test.com", height: 178.5, weight: 81.2)
    }
    
    func writeUser(_ user: User) {
        
    }
    
    private var accelerometerDataPoints: [AccelerometerDataPoint]
    private var ppgDataPoints: [PPGDataPoint]
    private var emgDataPoints: [EMGDataPoint]
    
    private var accelerometerFrameCounter: UInt32 = 26687
    private var ppgFrameCounter: UInt32 = 33318
    
    init() {
        let totalFrames = 40000
        let interval = 0.4
        let startTime = Date()
        
        accelerometerDataPoints = []
        ppgDataPoints = []
        emgDataPoints = []
        
        for i in 0..<totalFrames {
            let timestamp = startTime.addingTimeInterval(-Double(i) * interval)
            
            let isRandomized = Int.random(in: 1...100) > 70
            let sample: AccelerometerSample
            
            if isRandomized {
                sample = AccelerometerSample(
                    x: Int16.random(in: -32000...32000),
                    y: Int16.random(in: -32000...32000),
                    z: Int16.random(in: -32000...32000)
                )
            } else {
                sample = AccelerometerSample(x: 112, y: -2548, z: -16024)
            }
            
            let AccelerometerFrameModel = AccelerometerFrame(
                frameCounter: accelerometerFrameCounter,
                timestamp: timestamp,
                samples: [sample]
            )
            
            accelerometerDataPoints.append(AccelerometerFrameModel.convertToDataPoint())
            emgDataPoints.append(EMGDataPoint(value: AccelerometerFrameModel.convertToDataPoint().convert().value, timestamp: AccelerometerFrameModel.convertToDataPoint().convert().date))
            accelerometerFrameCounter += 1
            
            let isIRRandomized = Int.random(in: 1...100) > 70
            let irValue = isIRRandomized
            ? Int32.random(in: 160000...3_500_000)
            : 160000
            
            let ppgSample = PPGSample(red: 254115, ir: irValue, green: 265105)
            let PPGFrameModel = PPGFrame(
                frameCounter: ppgFrameCounter,
                timestamp: timestamp,
                samples: [ppgSample]
            )
            ppgDataPoints.append(PPGFrameModel.convertToDataPoint())
            
            ppgFrameCounter += 1
        }
        
        accelerometerDataPoints.reverse()
        ppgDataPoints.reverse()
    }
    
    func writePPGDataPoint(_ dataPoint: PPGDataPoint) {
        ppgDataPoints.append(dataPoint)
    }
    
    func readPPGDataPoints(limit: Int?) -> [PPGDataPoint] {
        if let limit {
            return Array(ppgDataPoints.suffix(limit))
        }
        return ppgDataPoints
    }
    
    func writeAccelerometerDataPoint(_ dataPoint: AccelerometerDataPoint) {
        accelerometerDataPoints.append(dataPoint)
    }
    
    func readAccelerometerDataPoints(limit: Int?) -> [AccelerometerDataPoint] {
        if let limit {
            return Array(accelerometerDataPoints.suffix(limit))
        }
        return accelerometerDataPoints
    }
    
    func writeEMGDataPoint(_ dataPoint: EMGDataPoint) {
        emgDataPoints.append(dataPoint)
    }
    
    func readEMGDataPoints(limit: Int?) -> [EMGDataPoint] {
        if let limit {
            return Array(emgDataPoints.suffix(limit))
        }
        return emgDataPoints
    }
}
