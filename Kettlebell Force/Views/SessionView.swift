//
//  SessionView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI
import MetaWear

struct SessionView: View {
    @ObservedObject var metaMotionManager: MetaMotionManager
    @ObservedObject var dataStore = DataStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var kettlebellMassKg: Int = 24
    @State private var bodyMassKg: Int = 0
    @State private var selectedExerciseType: ExerciseType = .swing
    @State private var sessionProcessor: SessionProcessor?
    @State private var isSessionActive = false
    @State private var sessionStartTime: Date?
    @State private var showingExitAlert = false
    @State private var showingBodyMassPicker = false
    @State private var showingKettlebellMassPicker = false
    
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
                            if let deviceName = metaMotionManager.deviceName, !deviceName.isEmpty {
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
                
                // Body Mass Input Row
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weight (KG)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingBodyMassPicker = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bodyweight")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(bodyMassKg > 0 ? "\(bodyMassKg) KG" : "Not set")
                                    .font(.title3)
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
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    // Kettlebell Mass Input Row
                    Button(action: {
                        showingKettlebellMassPicker = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kettlebell")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(kettlebellMassKg) KG")
                                    .font(.title3)
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
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .sheet(isPresented: $showingBodyMassPicker) {
                    WeightPickerSheet(
                        title: "Bodyweight",
                        selectedValue: $bodyMassKg,
                        range: 30...200,
                        unit: "KG",
                        isPresented: $showingBodyMassPicker
                    )
                }
                .sheet(isPresented: $showingKettlebellMassPicker) {
                    WeightPickerSheet(
                        title: "Kettlebell Weight",
                        selectedValue: $kettlebellMassKg,
                        range: 4...80,
                        unit: "KG",
                        isPresented: $showingKettlebellMassPicker
                    )
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
            // Initialize body mass from user profile
            let savedBodyMass = Int(dataStore.userProfile.bodyMassKg)
            if savedBodyMass > 0 {
                bodyMassKg = savedBodyMass
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
    
    private var kettlebellMassKgDouble: Double {
        Double(kettlebellMassKg)
    }
    
    private var bodyMassKgDouble: Double {
        Double(bodyMassKg)
    }
    
    private func startSession() {
        guard kettlebellMassKg > 0 else { return }
        guard bodyMassKg > 0 else { return }
        guard metaMotionManager.isConnected else { return }
        
        // Save body mass to user profile
        dataStore.userProfile.bodyMassKg = Double(bodyMassKg)
        dataStore.saveUserProfile()
        
        let startEpochMs = UInt64(Date().timeIntervalSince1970 * 1000)
        let processor = SessionProcessor(
            kettlebellMassKg: kettlebellMassKgDouble,
            bodyMassKg: bodyMassKgDouble,
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

struct WeightPickerSheet: View {
    let title: String
    @Binding var selectedValue: Int
    let range: ClosedRange<Int>
    let unit: String
    @Binding var isPresented: Bool
    
    // Local state to avoid updating binding during scrolling
    @State private var localValue: Int
    
    init(title: String, selectedValue: Binding<Int>, range: ClosedRange<Int>, unit: String, isPresented: Binding<Bool>) {
        self.title = title
        self._selectedValue = selectedValue
        self.range = range
        self.unit = unit
        self._isPresented = isPresented
        // Initialize local value from binding
        self._localValue = State(initialValue: selectedValue.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker(title, selection: $localValue) {
                    ForEach(Array(range), id: \.self) { value in
                        Text("\(value) \(unit)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 200)
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Only update binding when Done is tapped
                        selectedValue = localValue
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    SessionView(metaMotionManager: MetaMotionManager())
}

