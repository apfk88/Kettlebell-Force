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
    
    // Throttling for UI updates (20 Hz = every 50ms)
    private var pendingCurrentForceN: Double = 0
    private var pendingCurrentForceNorm: Double = 0
    private var pendingPeakForceN: Double = 0
    private var pendingPeakForceNorm: Double = 0
    private var pendingSessionImpulseNs: Double = 0
    private var updateTimer: Timer?
    private let uiUpdateInterval: TimeInterval = 0.05 // 50ms = 20 Hz
    
    init(kettlebellMassKg: Double, bodyMassKg: Double, startTimeEpochMs: UInt64) {
        self.kettlebellMassKg = kettlebellMassKg
        self.bodyMassKg = bodyMassKg
        self.startTimeEpochMs = startTimeEpochMs
        self.repDetector = RepDetector(thresholdNorm: 0.4)
        startUIUpdateTimer()
    }
    
    private func startUIUpdateTimer() {
        // Ensure timer is created on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // scheduledTimer automatically adds to the current run loop (main thread)
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: self.uiUpdateInterval, repeats: true) { [weak self] _ in
                self?.updatePublishedProperties()
            }
        }
    }
    
    private func updatePublishedProperties() {
        // Update published properties with pending values (already on main thread via timer)
        currentForceN = pendingCurrentForceN
        currentForceNorm = pendingCurrentForceNorm
        peakForceN = pendingPeakForceN
        peakForceNorm = pendingPeakForceNorm
        sessionImpulseNs = pendingSessionImpulseNs
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
        
        // Update pending values (these will be published at throttled rate)
        // Use a simple lock-free approach - these are just Double values
        pendingCurrentForceN = forceN
        pendingCurrentForceNorm = forceNorm
        
        // Update peak values immediately if they exceed current peak (not throttled)
        let newPeakForceN = max(pendingPeakForceN, forceN)
        let newPeakForceNorm = max(pendingPeakForceNorm, forceNorm)
        
        if newPeakForceN > pendingPeakForceN || newPeakForceNorm > pendingPeakForceNorm {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.peakForceN = newPeakForceN
                self.peakForceNorm = newPeakForceNorm
            }
        }
        
        pendingPeakForceN = newPeakForceN
        pendingPeakForceNorm = newPeakForceNorm
        pendingSessionImpulseNs += forceN * dtSec
        
        // Rep detection must happen immediately (not throttled) to maintain accuracy
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
        updateTimer?.invalidate()
        updateTimer = nil
        
        currentForceN = 0
        currentForceNorm = 0
        peakForceN = 0
        peakForceNorm = 0
        sessionImpulseNs = 0
        
        pendingCurrentForceN = 0
        pendingCurrentForceNorm = 0
        pendingPeakForceN = 0
        pendingPeakForceNorm = 0
        pendingSessionImpulseNs = 0
        
        reps = []
        lastEpochMs = nil
        repDetector.reset()
        
        startUIUpdateTimer()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

