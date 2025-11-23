//
//  DeviceSelectionView.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import SwiftUI
import MetaWear

struct DeviceSelectionView: View {
    @ObservedObject var metaMotionManager: MetaMotionManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            if metaMotionManager.isScanning {
                HStack {
                    ProgressView()
                    Text("Scanning for devices...")
                        .foregroundColor(.secondary)
                }
            }
            
            if metaMotionManager.discoveredDevices.isEmpty && !metaMotionManager.isScanning {
                Text("No devices found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
            
            ForEach(0..<metaMotionManager.discoveredDevices.count, id: \.self) { index in
                let device = metaMotionManager.discoveredDevices[index]
                Button(action: {
                    metaMotionManager.connect(to: device)
                    // Wait a moment for connection, then pop back
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if metaMotionManager.isConnected {
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "sensor.tag.radiowaves.forward")
                            .foregroundColor(.blue)
                        Text("MetaWear Device")
                        Spacer()
                        if metaMotionManager.device === device && metaMotionManager.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            
            if let error = metaMotionManager.connectionError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .navigationTitle("Select Device")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Automatically start scanning when view appears
            if !metaMotionManager.isScanning && !metaMotionManager.isConnected {
                metaMotionManager.scanAndConnect()
            }
        }
        .onDisappear {
            // Stop scanning when leaving the view
            metaMotionManager.stopScanning()
        }
    }
}

#Preview {
    DeviceSelectionView(metaMotionManager: MetaMotionManager())
}

