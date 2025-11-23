//
//  SessionProcessor.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation
import Combine

final class SessionProcessor: ObservableObject {
    let kettlebellMassKg: Double
    let bodyMassKg: Double
    let startTimeEpochMs: UInt64
    
    @Published var currentForceN: Double = 0
    @Published var currentForceNorm: Double = 0
    @Published var peakForceN: Double = 0
    @Published var peakForceNorm: Double = 0
    @Published var sessionImpulseNs: Double = 0
    @Published var reps: [RepSummary] = []
    
    private var lastEpochMs: UInt64?
    private let repDetector: RepDetector
    private let gConst = 9.81
    
    init(kettlebellMassKg: Double, bodyMassKg: Double, startTimeEpochMs: UInt64) {
        self.kettlebellMassKg = kettlebellMassKg
        self.bodyMassKg = bodyMassKg
        self.startTimeEpochMs = startTimeEpochMs
        self.repDetector = RepDetector(thresholdNorm: 0.4)
    }
    
    func processAccelerationSample(cart: (x: Float, y: Float, z: Float), epochMs: UInt64) {
        // Convert to Double
        let ax = Double(cart.x)
        let ay = Double(cart.y)
        let az = Double(cart.z)
        
        // Magnitude in g, includes gravity
        let magG = sqrt(ax * ax + ay * ay + az * az)
        
        // Simple dynamic magnitude, subtract 1 g baseline
        let dynMagG = max(magG - 1.0, 0.0)
        
        // Convert to m/s^2
        let accelMs2 = dynMagG * gConst
        
        // Bell force magnitude
        let forceN = kettlebellMassKg * accelMs2
        
        // Normalized force
        let bodyWeightN = bodyMassKg * gConst
        let forceNorm = bodyWeightN > 0 ? (forceN / bodyWeightN) : 0.0
        
        // Compute dtSec
        let dtSec: Double
        if let last = lastEpochMs {
            dtSec = Double(epochMs - last) / 1000.0
        } else {
            dtSec = 0
        }
        lastEpochMs = epochMs
        
        // Convert epoch to time since session start
        let timeSinceStart = Double(epochMs - startTimeEpochMs) / 1000.0
        
        // Update session metrics
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentForceN = forceN
            self.currentForceNorm = forceNorm
            self.peakForceN = max(self.peakForceN, forceN)
            self.peakForceNorm = max(self.peakForceNorm, forceNorm)
            self.sessionImpulseNs += forceN * dtSec
            
            // Check for rep detection
            if let rep = self.repDetector.handleSample(
                time: timeSinceStart,
                forceN: forceN,
                forceNorm: forceNorm,
                dtSec: dtSec
            ) {
                self.reps.append(rep)
            }
        }
    }
    
    func createSessionSummary(exerciseType: String) -> SessionSummary {
        let endEpochMs = UInt64(Date().timeIntervalSince1970 * 1000)
        let durationSec = Double(endEpochMs - startTimeEpochMs) / 1000.0
        
        // Calculate session impulse from reps if available, otherwise use accumulated
        let sessionImpulse = reps.isEmpty ? sessionImpulseNs : reps.reduce(0) { $0 + $1.impulseNs }
        
        return SessionSummary(
            id: UUID(),
            date: Date(),
            exerciseType: exerciseType,
            kettlebellMassKg: kettlebellMassKg,
            bodyMassKg: bodyMassKg,
            durationSec: durationSec,
            reps: reps,
            sessionPeakForceN: peakForceN,
            sessionPeakForceNorm: peakForceNorm,
            sessionImpulseNs: sessionImpulse
        )
    }
    
    func reset() {
        currentForceN = 0
        currentForceNorm = 0
        peakForceN = 0
        peakForceNorm = 0
        sessionImpulseNs = 0
        reps = []
        lastEpochMs = nil
        repDetector.reset()
    }
}

