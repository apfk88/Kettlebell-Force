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
    
    @State private var kettlebellMassText: String = "24"
    @State private var bodyMassText: String = ""
    @State private var selectedExerciseType: ExerciseType = .swing
    @State private var sessionProcessor: SessionProcessor?
    @State private var isSessionActive = false
    @State private var sessionStartTime: Date?
    @State private var showingExitAlert = false
    
    init(metaMotionManager: MetaMotionManager) {
        self.metaMotionManager = metaMotionManager
    }
    
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
                    Button("Exit") {
                        if isSessionActive {
                            showingExitAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Exit Without Saving?", isPresented: $showingExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Exit", role: .destructive) {
                    stopSession()
                    dismiss()
                }
            } message: {
                Text("Your current session will not be saved.")
            }
        }
    }
    
    private var setupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Device Row
                VStack(alignment: .leading, spacing: 12) {
                    Text("Device")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    NavigationLink(destination: DeviceSelectionView(metaMotionManager: metaMotionManager)) {
                        HStack {
                            Image(systemName: metaMotionManager.isConnected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(metaMotionManager.isConnected ? .green : .secondary)
                            if let device = metaMotionManager.device, let deviceName = device.name, !deviceName.isEmpty {
                                Text(deviceName)
                                    .foregroundColor(.primary)
                            } else {
                                Text("MetaWear Device")
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // Body Mass and Kettlebell Mass Inputs - Side by Side
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weight (KG)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        // Body Mass Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bodyweight")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("KG", text: $bodyMassText)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .frame(minHeight: 50)
                                .contentShape(Rectangle())
                                .onAppear {
                                    let bodyMass = Int(dataStore.userProfile.bodyMassKg)
                                    bodyMassText = bodyMass > 0 ? "\(bodyMass)" : ""
                                }
                                .onChange(of: bodyMassText) { oldValue, newValue in
                                    if let value = Int(newValue), value > 0 {
                                        dataStore.userProfile.bodyMassKg = Double(value)
                                        dataStore.saveUserProfile()
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Kettlebell Mass Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kettlebell")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("KG", text: $kettlebellMassText)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .frame(minHeight: 50)
                                .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                }
                
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
                .disabled(kettlebellMassKg <= 0 || bodyMassKg <= 0 || !metaMotionManager.isConnected)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            // Try to auto-connect to previously connected device
            if !metaMotionManager.isConnected {
                metaMotionManager.tryAutoConnect()
            }
        }
    }
    
    private var activeSessionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let processor = sessionProcessor {
                    ActiveSessionContent(processor: processor)
                } else {
                    Text("No session data")
                        .foregroundColor(.secondary)
                }
                
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
    
    private var bodyMassKg: Double {
        Double(bodyMassText) ?? dataStore.userProfile.bodyMassKg
    }
    
    private func startSession() {
        guard kettlebellMassKg > 0 else { return }
        guard bodyMassKg > 0 else { return }
        guard metaMotionManager.isConnected else { return }
        
        // Save body mass if entered
        if let bodyMass = Int(bodyMassText), bodyMass > 0 {
            dataStore.userProfile.bodyMassKg = Double(bodyMass)
            dataStore.saveUserProfile()
        }
        
        let startEpochMs = UInt64(Date().timeIntervalSince1970 * 1000)
        let processor = SessionProcessor(
            kettlebellMassKg: kettlebellMassKg,
            bodyMassKg: bodyMassKg,
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
        
        // Navigate back to home screen
        dismiss()
    }
}

struct ActiveSessionContent: View {
    @ObservedObject var processor: SessionProcessor
    
    var body: some View {
        VStack(spacing: 16) {
            MetricCard(
                title: "Current Force",
                value: String(format: "%.1f N", processor.currentForceN),
                subtitle: String(format: "%.2f x BW", processor.currentForceNorm)
            )
            
            MetricCard(
                title: "Peak Force",
                value: String(format: "%.1f N", processor.peakForceN),
                subtitle: String(format: "%.2f x BW", processor.peakForceNorm)
            )
            
            MetricCard(
                title: "Session Impulse",
                value: String(format: "%.1f N·s", processor.sessionImpulseNs),
                subtitle: nil
            )
            
            MetricCard(
                title: "Reps",
                value: "\(processor.reps.count)",
                subtitle: nil
            )
        }
        .padding(.horizontal)
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

