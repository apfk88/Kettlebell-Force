//
//  SessionSummary.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation

struct SessionSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let exerciseType: String      // "snatch", "swing", etc.
    let kettlebellMassKg: Double
    let bodyMassKg: Double
    let durationSec: Double
    let reps: [RepSummary]
    let sessionPeakForceN: Double
    let sessionPeakForceNorm: Double
    let sessionImpulseNs: Double  // sum of rep impulses
    
    init(id: UUID = UUID(), date: Date = Date(), exerciseType: String, kettlebellMassKg: Double, bodyMassKg: Double, durationSec: Double, reps: [RepSummary], sessionPeakForceN: Double, sessionPeakForceNorm: Double, sessionImpulseNs: Double) {
        self.id = id
        self.date = date
        self.exerciseType = exerciseType
        self.kettlebellMassKg = kettlebellMassKg
        self.bodyMassKg = bodyMassKg
        self.durationSec = durationSec
        self.reps = reps
        self.sessionPeakForceN = sessionPeakForceN
        self.sessionPeakForceNorm = sessionPeakForceNorm
        self.sessionImpulseNs = sessionImpulseNs
    }
}

