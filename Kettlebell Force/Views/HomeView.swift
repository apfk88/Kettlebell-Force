//
//  HomeView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI
import MetaWear

struct HomeView: View {
    @ObservedObject var dataStore = DataStore.shared
    @StateObject private var metaMotionManager = MetaMotionManager()
    @State private var bodyMassText: String = ""
    @State private var showingSessionView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Body Mass Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Body Mass")
                        .font(.headline)
                    TextField("Enter body mass (kg)", text: $bodyMassText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .onAppear {
                            bodyMassText = String(format: "%.1f", dataStore.userProfile.bodyMassKg)
                        }
                        .onChange(of: bodyMassText) { oldValue, newValue in
                            if let value = Double(newValue), value > 0 {
                                dataStore.userProfile.bodyMassKg = value
                                dataStore.saveUserProfile()
                            }
                        }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Device Connection Section
                VStack(spacing: 16) {
                    if metaMotionManager.isConnected {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 48))
                            Text("Connected")
                                .font(.headline)
                            if metaMotionManager.device != nil {
                                Text("Connected Device")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        Button("Disconnect") {
                            metaMotionManager.disconnect()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(spacing: 16) {
                            Button(action: {
                                metaMotionManager.scanAndConnect()
                            }) {
                                HStack {
                                    if metaMotionManager.isScanning {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                    }
                                    Text(metaMotionManager.isScanning ? "Scanning..." : "Scan and Connect")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(metaMotionManager.isScanning)
                            
                            if !metaMotionManager.discoveredDevices.isEmpty {
                                Text("Discovered Devices:")
                                    .font(.headline)
                                    .padding(.top)
                                
                                ForEach(0..<metaMotionManager.discoveredDevices.count, id: \.self) { index in
                                    let device = metaMotionManager.discoveredDevices[index]
                                    Button(action: {
                                        metaMotionManager.connect(to: device)
                                    }) {
                                        HStack {
                                            Image(systemName: "sensor.tag.radiowaves.forward")
                                            Text("MetaWear Device")
                                            Spacer()
                                            Text("Device \(index + 1)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                            if let error = metaMotionManager.connectionError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Start Session Button
                Button(action: {
                    showingSessionView = true
                }) {
                    Text("Start Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!metaMotionManager.isConnected)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Kettlebell Force")
            .sheet(isPresented: $showingSessionView) {
                SessionView(metaMotionManager: metaMotionManager)
            }
        }
    }
}

#Preview {
    HomeView()
}

