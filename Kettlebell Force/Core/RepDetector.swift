//
//  RepDetector.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation

final class RepDetector {
    enum State {
        case idle
        case inRep(RepAccumulator)
    }
    
    var state: State = .idle
    private let thresholdNorm: Double
    
    init(thresholdNorm: Double = 0.4) {
        self.thresholdNorm = thresholdNorm
    }
    
    func handleSample(time: TimeInterval,
                      forceN: Double,
                      forceNorm: Double,
                      dtSec: Double) -> RepSummary? {
        switch state {
        case .idle:
            if forceNorm > thresholdNorm {
                let acc = RepAccumulator(
                    startTime: time,
                    endTime: time,
                    peakForceN: forceN,
                    peakForceNorm: forceNorm,
                    impulseNs: 0
                )
                state = .inRep(acc)
            }
            return nil
            
        case .inRep(var acc):
            acc.endTime = time
            acc.peakForceN = max(acc.peakForceN, forceN)
            acc.peakForceNorm = max(acc.peakForceNorm, forceNorm)
            acc.impulseNs += forceN * dtSec
            
            if forceNorm < thresholdNorm * 0.4 {
                // rep finished
                state = .idle
                return RepSummary(
                    id: UUID(),
                    startTime: acc.startTime,
                    endTime: acc.endTime,
                    peakForceN: acc.peakForceN,
                    peakForceNorm: acc.peakForceNorm,
                    impulseNs: acc.impulseNs
                )
            } else {
                state = .inRep(acc)
                return nil
            }
        }
    }
    
    func reset() {
        state = .idle
    }
}

