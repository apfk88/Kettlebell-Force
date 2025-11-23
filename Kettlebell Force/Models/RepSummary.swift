//
//  RepSummary.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation

struct RepSummary: Codable, Identifiable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let peakForceN: Double
    let peakForceNorm: Double     // normalized to bodyweight
    let impulseNs: Double         // N·s over this rep
    
    init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, peakForceN: Double, peakForceNorm: Double, impulseNs: Double) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.peakForceN = peakForceN
        self.peakForceNorm = peakForceNorm
        self.impulseNs = impulseNs
    }
}

