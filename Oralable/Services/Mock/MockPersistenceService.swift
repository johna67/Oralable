//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2025 Gabor Detari. All rights reserved.
//

import Foundation

final class MockPersistenceService: PersistenceService {
    private var accelerometerFrames: [AccelerometerFrame]
    private var ppgFrames: [PPGFrame]
        
    private var accelerometerFrameCounter: UInt32 = 26687
    private var ppgFrameCounter: UInt32 = 33318
    
    init() {
        let totalFrames = 4
        let interval = 0.4
        let startTime = Date()
        
        accelerometerFrames = []
        ppgFrames = []
        
        for i in 0..<totalFrames {
            let timestamp = startTime.addingTimeInterval(-Double(i) * interval)
            
            let isRandomized = Int.random(in: 1...100) > 90
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
            
            let accelerometerFrame = AccelerometerFrame(
                frameCounter: accelerometerFrameCounter,
                timestamp: timestamp,
                maxSample: sample
            )
            accelerometerFrames.append(accelerometerFrame)
            accelerometerFrameCounter += 1
            
            let isIRRandomized = Int.random(in: 1...100) > 90
            let irValue = isIRRandomized
                ? Int32.random(in: 160000...3_500_000)
                : 160000
            
            let ppgSample = PPGSample(red: 254115, ir: irValue, green: 265105)
            let ppgFrame = PPGFrame(
                frameCounter: ppgFrameCounter,
                timestamp: timestamp,
                avgSample: ppgSample
            )
            ppgFrames.append(ppgFrame)
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
