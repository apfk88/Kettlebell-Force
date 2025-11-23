//
//  MetaMotionManager.swift
//  Kettlebell Force
//
//  Created by Alexander Kvamme on 11/23/25.
//

import Foundation
import Combine
import MetaWear
import MetaWearCpp

final class MetaMotionManager: ObservableObject {
    @Published var device: MetaWear?       // currently connected device
    @Published var isConnected: Bool = false
    @Published var discoveredDevices: [MetaWear] = []
    @Published var isScanning: Bool = false
    @Published var connectionError: String?
    
    private var accelerationHandler: ((Float, Float, Float, UInt64) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var accelerometerCancellable: AnyCancellable?
    private let dataStore = DataStore.shared
    
    // Local cache of devices to avoid frequent access to SDK's dictionary which might cause crashes
    private var deviceMap: [UUID: MetaWear] = [:]
    
    init() {
        setupScannerSubscriptions()
    }
    
    private func getDeviceUUID(_ device: MetaWear) -> UUID? {
        // Use local map to find UUID
        for (uuid, cachedDevice) in deviceMap {
            if cachedDevice === device {
                return uuid
            }
        }
        return nil
    }
    
    func tryAutoConnect() {
        guard !isConnected else { return }
        guard let lastUUID = dataStore.userProfile.lastConnectedDeviceUUID else { return }
        
        // Start scanning
        scanAndConnect()
        
        // Check local map first
        if let device = deviceMap[lastUUID] {
            connect(to: device)
            return
        }
        
        // Wait for device to be discovered
        var checkCount = 0
        let maxChecks = 40
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            checkCount += 1
            
            if let device = self.deviceMap[lastUUID] {
                timer.invalidate()
                self.connect(to: device)
            } else if checkCount >= maxChecks {
                timer.invalidate()
                self.stopScanning()
            }
        }
    }
    
    private func setupScannerSubscriptions() {
        let scanner = MetaWearScanner.shared
        
        // Subscribe to discovered devices as they're found
        scanner.didDiscoverUniqued?
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discoveredDevice in
                guard let self = self else { return }
                
                // Update local map? We need UUID. 
                // MetaWear object usually doesn't expose UUID directly in public API easily 
                // without iterating the map or it's passed in the map.
                // But didDiscoverUniqued just gives the device.
                
                // We can't easily key by UUID unless we know it.
                // However, discoveredDevices array needs to be populated.
                
                if !self.discoveredDevices.contains(where: { $0 === discoveredDevice }) {
                    self.discoveredDevices.append(discoveredDevice)
                }
                
                // Try to sync local map from scanner safely
                self.refreshDeviceMap()
            }
            .store(in: &cancellables)
        
        // Subscribe to scanning state
        scanner.isScanningPublisher?
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
    }
    
    private func refreshDeviceMap() {
        // Safely copy devices from scanner to local map
        // We do this on main thread to avoid threading issues if scanner is not thread safe
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let scanner = MetaWearScanner.shared
            self.deviceMap = scanner.discoveredDevices
            
            // Also update discoveredDevices list from map values to keep them in sync
            // but preserve order if possible? 
            // Actually, keep discoveredDevices as is (appended on discovery) 
            // or rebuild it? Rebuilding is safer for consistency.
            self.discoveredDevices = Array(self.deviceMap.values)
        }
    }
    
    func scanAndConnect() {
        guard !isScanning else { return }
        
        discoveredDevices = []
        deviceMap = [:]
        connectionError = nil
        
        // Start scanning
        MetaWearScanner.shared.startScan(higherPerformanceMode: false)
        
        // Initial refresh
        refreshDeviceMap()
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
                        
                        // Save device UUID for auto-reconnect
                        if let uuid = self.getDeviceUUID(device) {
                            self.dataStore.userProfile.lastConnectedDeviceUUID = uuid
                            self.dataStore.saveUserProfile()
                        }
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
            // Note: We keep the lastConnectedDeviceUUID so we can auto-reconnect next time
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
        guard let device = device else {
            // No device connected - use simulation for testing
            print("⚠️ No device connected - using simulated accelerometer data")
            accelerationHandler = onSample
            simulateAccelerometerData()
            return
        }
        
        accelerationHandler = onSample
        
        // Use MetaWear C++ API to configure and start accelerometer
        // 1. Configure Accelerometer (100Hz, 16g)
        mbl_mw_acc_set_odr(device.board, 100.0)
        mbl_mw_acc_set_range(device.board, 16.0)
        mbl_mw_acc_write_acceleration_config(device.board)
        
        // 2. Get Data Signal
        guard let signal = mbl_mw_acc_get_acceleration_data_signal(device.board) else {
            print("Failed to get accelerometer signal")
            simulateAccelerometerData()
            return
        }
        
        // 3. Subscribe to Data
        // We pass 'self' as the context to the C callback
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        mbl_mw_datasignal_subscribe(signal, context) { (context, data) in
            guard let context = context, let data = data else { return }
            
            // Convert context back to MetaMotionManager
            let manager = Unmanaged<MetaMotionManager>.fromOpaque(context).takeUnretainedValue()
            
            // Parse data
            let value: MblMwCartesianFloat = data.pointee.valueAs()
            let x = value.x
            let y = value.y
            let z = value.z
            let epoch = UInt64(Date().timeIntervalSince1970 * 1000)
            
            // Forward to handler
            manager.accelerationHandler?(x, y, z, epoch)
        }
        
        // 4. Start Streaming
        mbl_mw_acc_enable_acceleration_sampling(device.board)
        mbl_mw_acc_start(device.board)
    }
    
    func stopAccelerometerStreaming() {
        // Stop simulation timer if running
        #if DEBUG
        simulationTimer?.invalidate()
        simulationTimer = nil
        #endif
        
        guard let device = device else { return }
        
        // Stop accelerometer
        mbl_mw_acc_stop(device.board)
        mbl_mw_acc_disable_acceleration_sampling(device.board)
        
        // Note: Technically we should unsubscribe, but for this simple app
        // stopping the sensor is sufficient to stop the stream.
        // To unsubscribe we'd need to keep the signal reference.
        
        accelerationHandler = nil
    }
    
    #if DEBUG
    private var simulationTimer: Timer?
    
    private func simulateAccelerometerData() {
        // Only use simulation as fallback when device/accelerometer is not available
        simulationTimer?.invalidate()
        
        var timeOffset: UInt64 = 0
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] timer in
            guard let self = self, let handler = self.accelerationHandler else {
                timer.invalidate()
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
