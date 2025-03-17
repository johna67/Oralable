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
    
    private var accelerometerFrames: [AccelerometerFrame]
    private var ppgFrames: [PPGFrame]
        
    private var accelerometerFrameCounter: UInt32 = 26687
    private var ppgFrameCounter: UInt32 = 33318
    
    init() {
        let totalFrames = 40000
        let interval = 0.4
        let startTime = Date()
        
        accelerometerFrames = []
        ppgFrames = []
        
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
            accelerometerFrames.append(AccelerometerFrameModel)
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
            ppgFrames.append(PPGFrameModel)
            ppgFrameCounter += 1
        }
        
        accelerometerFrames.reverse()
        ppgFrames.reverse()
    }
    
    func writePPGFrame(_ frame: PPGFrame) {
            ppgFrames.append(frame)
        }
        
        func readPPGFrames(limit: Int?) -> [PPGFrame] {
            if let limit {
                return Array(ppgFrames.suffix(limit))
            }
            return ppgFrames
        }
        
        func writeAccelerometerFrame(_ frame: AccelerometerFrame) {
            accelerometerFrames.append(frame)
        }
        
        func readAccelerometerFrames(limit: Int?) -> [AccelerometerFrame] {
            if let limit {
                return Array(accelerometerFrames.suffix(limit))
            }
            return accelerometerFrames
        }
}
