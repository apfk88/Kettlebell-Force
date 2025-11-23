//
//  SessionView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI

struct SessionView: View {
    @ObservedObject var metaMotionManager: MetaMotionManager
    @ObservedObject var dataStore = DataStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var kettlebellMassText: String = "24.0"
    @State private var selectedExerciseType: ExerciseType = .swing
    @State private var sessionProcessor: SessionProcessor?
    @State private var isSessionActive = false
    @State private var sessionStartTime: Date?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isSessionActive {
                    // Active Session View
                    activeSessionView
                } else {
                    // Setup View
                    setupView
                }
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        stopSession()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var setupView: some View {
        VStack(spacing: 24) {
            // Kettlebell Mass Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Kettlebell Mass")
                    .font(.headline)
                TextField("Enter kettlebell mass (kg)", text: $kettlebellMassText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal)
            
            // Exercise Type Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Exercise Type")
                    .font(.headline)
                Picker("Exercise Type", selection: $selectedExerciseType) {
                    ForEach(ExerciseType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Start Session Button
            Button(action: {
                startSession()
            }) {
                Text("Start Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(kettlebellMassKg <= 0)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var activeSessionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Metrics
                VStack(spacing: 16) {
                    MetricCard(
                        title: "Current Force",
                        value: String(format: "%.1f N", sessionProcessor?.currentForceN ?? 0),
                        subtitle: String(format: "%.2f x BW", sessionProcessor?.currentForceNorm ?? 0)
                    )
                    
                    MetricCard(
                        title: "Peak Force",
                        value: String(format: "%.1f N", sessionProcessor?.peakForceN ?? 0),
                        subtitle: String(format: "%.2f x BW", sessionProcessor?.peakForceNorm ?? 0)
                    )
                    
                    MetricCard(
                        title: "Session Impulse",
                        value: String(format: "%.1f N·s", sessionProcessor?.sessionImpulseNs ?? 0),
                        subtitle: nil
                    )
                    
                    MetricCard(
                        title: "Reps",
                        value: "\(sessionProcessor?.reps.count ?? 0)",
                        subtitle: nil
                    )
                }
                .padding(.horizontal)
                
                // Stop Session Button
                Button(action: {
                    stopSession()
                }) {
                    Text("Stop Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    private var kettlebellMassKg: Double {
        Double(kettlebellMassText) ?? 0
    }
    
    private func startSession() {
        guard kettlebellMassKg > 0 else { return }
        guard metaMotionManager.isConnected else { return }
        
        let startEpochMs = UInt64(Date().timeIntervalSince1970 * 1000)
        let processor = SessionProcessor(
            kettlebellMassKg: kettlebellMassKg,
            bodyMassKg: dataStore.userProfile.bodyMassKg,
            startTimeEpochMs: startEpochMs
        )
        
        sessionProcessor = processor
        sessionStartTime = Date()
        isSessionActive = true
        
        // Configure and start accelerometer
        _ = metaMotionManager.configureAccelerometer()
        metaMotionManager.startAccelerometerStreaming { [weak processor] x, y, z, epoch in
            processor?.processAccelerationSample(cart: (x: x, y: y, z: z), epochMs: epoch)
        }
    }
    
    private func stopSession() {
        guard isSessionActive else { return }
        
        metaMotionManager.stopAccelerometerStreaming()
        
        if let processor = sessionProcessor {
            let session = processor.createSessionSummary(exerciseType: selectedExerciseType.rawValue)
            dataStore.saveSession(session)
        }
        
        isSessionActive = false
        sessionProcessor = nil
        sessionStartTime = nil
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    SessionView(metaMotionManager: MetaMotionManager())
}

