//
//  RepAccumulator.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation

struct RepAccumulator {
    var startTime: TimeInterval
    var endTime: TimeInterval
    var peakForceN: Double
    var peakForceNorm: Double
    var impulseNs: Double
    
    init(startTime: TimeInterval, endTime: TimeInterval, peakForceN: Double, peakForceNorm: Double, impulseNs: Double) {
        self.startTime = startTime
        self.endTime = endTime
        self.peakForceN = peakForceN
        self.peakForceNorm = peakForceNorm
        self.impulseNs = impulseNs
    }
}

