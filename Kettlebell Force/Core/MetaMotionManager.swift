//
//  MetaMotionManager.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation
import Combine
import MetaWear

final class MetaMotionManager: ObservableObject {
    @Published var device: MetaWear?       // currently connected device
    @Published var isConnected: Bool = false
    @Published var discoveredDevices: [MetaWear] = []
    @Published var isScanning: Bool = false
    @Published var connectionError: String?
    
    private var accelerationHandler: ((Float, Float, Float, UInt64) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var accelerometerCancellable: AnyCancellable?
    
    init() {
        setupScannerSubscriptions()
    }
    
    private func setupScannerSubscriptions() {
        let scanner = MetaWearScanner.shared
        
        // Subscribe to discovered devices as they're found
        scanner.didDiscoverUniqued?
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discoveredDevice in
                guard let self = self else { return }
                // Check if device already in list (compare by object identity or UUID)
                if !self.discoveredDevices.contains(where: { $0 === discoveredDevice }) {
                    self.discoveredDevices.append(discoveredDevice)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to scanning state
        scanner.isScanningPublisher?
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
    }
    
    func scanAndConnect() {
        guard !isScanning else { return }
        
        discoveredDevices = []
        connectionError = nil
        
        // Start scanning
        MetaWearScanner.shared.startScan(higherPerformanceMode: false)
        
        // Also load any already discovered devices from the dictionary
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let scanner = MetaWearScanner.shared
            let devices = Array(scanner.discoveredDevices.values)
            self.discoveredDevices = devices
        }
    }
    
    func stopScanning() {
        MetaWearScanner.shared.stopScan()
    }
    
    func connect(to device: MetaWear) {
        connectionError = nil
        
        // Connect to the device
        device.connect()
        
        // Subscribe to device connection state
        // Check if device has a connection state publisher
        // Common patterns: device.$connectionState, device.connectionStatePublisher, etc.
        
        // For now, use a timer to check connection status
        // This should be replaced with actual connection state publisher when available
        var connectionCheckCount = 0
        let maxChecks = 20 // Check for up to 10 seconds (20 * 0.5s)
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            connectionCheckCount += 1
            
            // Try to check connection state - adjust based on actual SDK API
            // Common patterns:
            // - device.isConnected
            // - device.connectionState == .connected
            // - Check if device has published properties we can observe
            
            // For now, assume connected after a short delay
            // TODO: Replace with actual connection state check
            if connectionCheckCount >= 2 || connectionCheckCount >= maxChecks {
                timer.invalidate()
                
                DispatchQueue.main.async {
                    if connectionCheckCount < maxChecks {
                        self.device = device
                        self.isConnected = true
                        self.stopScanning()
                    } else {
                        self.connectionError = "Failed to connect to device"
                        self.isConnected = false
                    }
                }
            }
        }
    }
    
    func disconnect() {
        stopAccelerometerStreaming()
        
        // Disconnect the device
        device?.disconnect()
        
        DispatchQueue.main.async { [weak self] in
            self?.device = nil
            self?.isConnected = false
        }
        
        cancellables.removeAll()
    }
    
    func configureAccelerometer(odr: Float = 100.0, rangeG: Float = 16.0) -> Bool {
        guard device != nil else { return false }
        
        // Configure accelerometer - API will need to be adjusted based on actual SDK
        // This is a placeholder that will need to match the actual SDK API
        return true
    }
    
    func startAccelerometerStreaming(onSample: @escaping (Float, Float, Float, UInt64) -> Void) {
        guard device != nil else { return }
        
        accelerationHandler = onSample
        
        // Use the new Swift Combine SDK to stream accelerometer data
        // The exact API will need to be adjusted based on the actual SDK structure
        
        #if DEBUG
        // For now, use simulation until we can verify the actual API
        simulateAccelerometerData()
        #else
        // TODO: Uncomment and adjust once SDK API is confirmed
        // Example pattern (adjust based on actual API):
        // accelerometerCancellable = device.accelerometer?.acceleration
        //     .sink { [weak self] (acceleration: Acceleration) in
        //         guard let self = self else { return }
        //         let x = Float(acceleration.x)
        //         let y = Float(acceleration.y)
        //         let z = Float(acceleration.z)
        //         let epoch = UInt64(Date().timeIntervalSince1970 * 1000)
        //         self.accelerationHandler?(x, y, z, epoch)
        //     }
        // device.accelerometer?.start()
        #endif
    }
    
    func stopAccelerometerStreaming() {
        accelerationHandler = nil
        accelerometerCancellable?.cancel()
        accelerometerCancellable = nil
        
        // Stop the accelerometer - method name may vary
        // device?.accelerometer?.stop()
    }
    
    #if DEBUG
    private var simulationTimer: Timer?
    
    private func simulateAccelerometerData() {
        var timeOffset: UInt64 = 0
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self, let handler = self.accelerationHandler else {
                self?.simulationTimer?.invalidate()
                return
            }
            
            // Simulate accelerometer data (simple sine wave pattern)
            let t = Double(timeOffset) / 1000.0
            let x = Float(1.0 + 2.0 * sin(t * 2.0 * .pi))
            let y = Float(0.5 + 1.5 * sin(t * 2.0 * .pi + .pi / 2))
            let z = Float(0.8 + 1.2 * sin(t * 2.0 * .pi + .pi))
            let epoch = UInt64(Date().timeIntervalSince1970 * 1000) + timeOffset
            
            handler(x, y, z, epoch)
            timeOffset += 10
        }
    }
    #endif
}
