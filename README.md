# Kettlebell Force iOS App

## Project Overview

Native iOS app that connects to MbientLab MetaMotionRL sensors mounted on kettlebells to stream IMU data in real-time and compute force metrics for kettlebell exercises (snatches, swings). Built with SwiftUI and Swift Combine.

**Target Platform**: iOS 16+
**Language**: Swift
**UI Framework**: SwiftUI
**Architecture**: MVVM with ObservableObject pattern

## Project Structure

```
Kettlebell Force/
├── Kettlebell Force/
│   ├── Core/
│   │   ├── MetaMotionManager.swift      # Bluetooth device scanning, connection, accelerometer streaming
│   │   ├── SessionProcessor.swift        # Force computation and session metrics
│   │   ├── RepDetector.swift             # Rep detection algorithm
│   │   └── DataStore.swift              # JSON-based persistence layer
│   ├── Models/
│   │   ├── UserProfile.swift            # User body mass data
│   │   ├── ExerciseType.swift           # Exercise type enum (snatch, swing, other)
│   │   ├── RepSummary.swift             # Per-rep metrics
│   │   ├── SessionSummary.swift        # Complete session data
│   │   ├── ForceSample.swift           # Accelerometer sample data
│   │   └── RepAccumulator.swift        # Internal rep tracking structure
│   ├── Views/
│   │   ├── HomeView.swift               # Device connection and body mass input
│   │   ├── SessionView.swift            # Active session with live metrics
│   │   ├── HistoryView.swift            # List of past sessions
│   │   └── SessionDetailView.swift      # Detailed session view with rep breakdown
│   ├── ContentView.swift                # Main TabView navigation
│   └── Kettlebell_ForceApp.swift        # App entry point
```

## Dependencies

### MetaWear Swift Combine SDK
- **Package**: `https://github.com/mbientlab/MetaWear-Swift-Combine-SDK`
- **Products Used**: `MetaWear`, `MetaWearCpp`
- **Purpose**: Bluetooth connectivity and accelerometer data streaming

### Key SDK APIs Used

#### MetaWearScanner
- `MetaWearScanner.shared.startScan(higherPerformanceMode: Bool)` - Starts BLE scanning
- `MetaWearScanner.shared.stopScan()` - Stops scanning
- `MetaWearScanner.shared.discoveredDevices: Dictionary<UUID, MetaWear>` - Dictionary of discovered devices
- `MetaWearScanner.shared.didDiscoverUniqued: AnyPublisher<MetaWear, Never>?` - Publisher emitting discovered devices
- `MetaWearScanner.shared.isScanningPublisher: AnyPublisher<Bool, Never>?` - Publisher for scanning state

#### MetaWear Device
- `device.connect()` - Connects to device (returns void, connection is asynchronous)
- `device.disconnect()` - Disconnects from device
- Device properties: `name`, `mac` (may be optional/nil)

## Core Components

### MetaMotionManager
**File**: `Core/MetaMotionManager.swift`
**Purpose**: Manages Bluetooth scanning, device connection, and accelerometer streaming

**Key Properties**:
- `@Published var device: MetaWear?` - Currently connected device
- `@Published var isConnected: Bool` - Connection state
- `@Published var discoveredDevices: [MetaWear]` - List of discovered devices
- `@Published var isScanning: Bool` - Scanning state
- `@Published var connectionError: String?` - Error messages

**Key Methods**:
- `scanAndConnect()` - Starts scanning and subscribes to discovered devices
- `stopScanning()` - Stops scanning
- `connect(to device: MetaWear)` - Connects to a specific device
- `disconnect()` - Disconnects current device
- `startAccelerometerStreaming(onSample:)` - Starts accelerometer data stream
- `stopAccelerometerStreaming()` - Stops accelerometer stream

**Implementation Notes**:
- Uses Combine publishers for reactive programming
- Subscribes to `didDiscoverUniqued` publisher in `init()` to receive devices as they're discovered
- Subscribes to `isScanningPublisher` to automatically track scanning state
- Currently uses simulation mode in DEBUG builds (see `simulateAccelerometerData()`)
- Accelerometer streaming implementation is incomplete - needs actual SDK API integration

**TODO**: 
- Implement actual accelerometer API calls (currently simulated)
- Add proper connection state checking (currently uses timer-based approach)
- Configure accelerometer settings (ODR, range) using actual SDK methods

### SessionProcessor
**File**: `Core/SessionProcessor.swift`
**Purpose**: Computes force metrics from accelerometer data and manages session state

**Key Properties**:
- `@Published var currentForceN: Double` - Current force in newtons
- `@Published var currentForceNorm: Double` - Current normalized force (x bodyweight)
- `@Published var peakForceN: Double` - Session peak force
- `@Published var peakForceNorm: Double` - Session peak normalized force
- `@Published var sessionImpulseNs: Double` - Total session impulse
- `@Published var reps: [RepSummary]` - Detected reps

**Key Methods**:
- `processAccelerationSample(cart:epochMs:)` - Processes accelerometer data and computes force
- `createSessionSummary(exerciseType:)` - Creates final session summary
- `reset()` - Resets session state

**Force Computation Algorithm**:
1. Converts accelerometer values (x, y, z in g) to magnitude: `magG = sqrt(ax² + ay² + az²)`
2. Subtracts 1g baseline: `dynMagG = max(magG - 1.0, 0.0)`
3. Converts to m/s²: `accelMs2 = dynMagG * 9.81`
4. Computes force: `forceN = kettlebellMassKg * accelMs2`
5. Normalizes to bodyweight: `forceNorm = forceN / (bodyMassKg * 9.81)`

**Rep Detection**: Delegates to `RepDetector` class

### RepDetector
**File**: `Core/RepDetector.swift`
**Purpose**: Detects individual reps from force data using threshold-based state machine

**Algorithm**:
- State machine with states: `.idle`, `.inRep(RepAccumulator)`
- Threshold: `thresholdNorm` (default 0.4 = 40% bodyweight)
- Enters rep when `forceNorm > thresholdNorm`
- Exits rep when `forceNorm < thresholdNorm * 0.4`
- Accumulates peak force and impulse during rep

**Key Methods**:
- `handleSample(time:forceN:forceNorm:dtSec:) -> RepSummary?` - Processes sample, returns RepSummary when rep completes

### DataStore
**File**: `Core/DataStore.swift`
**Purpose**: JSON-based persistence for user profile and session history

**Storage Locations**:
- User profile: `Documents/userProfile.json`
- Sessions: `Documents/sessions.json`

**Key Methods**:
- `saveUserProfile()` - Saves user profile to disk
- `saveSession(_:)` - Adds and saves a session
- `deleteSession(_:)` - Removes a session

**Note**: Uses `ObservableObject` with `@Published` properties for SwiftUI reactivity

## Data Models

### UserProfile
```swift
struct UserProfile: Codable {
    var bodyMassKg: Double
    static let `default` = UserProfile(bodyMassKg: 70.0)
}
```

### ExerciseType
```swift
enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case snatch = "snatch"
    case swing = "swing"
    case other = "other"
}
```

### RepSummary
```swift
struct RepSummary: Codable, Identifiable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let peakForceN: Double
    let peakForceNorm: Double
    let impulseNs: Double
}
```

### SessionSummary
```swift
struct SessionSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let exerciseType: String
    let kettlebellMassKg: Double
    let bodyMassKg: Double
    let durationSec: Double
    let reps: [RepSummary]
    let sessionPeakForceN: Double
    let sessionPeakForceNorm: Double
    let sessionImpulseNs: Double
}
```

## UI Components

### HomeView
- Body mass input field
- Device scanning/connection UI
- Shows discovered devices list
- "Start Session" button (disabled until connected)

### SessionView
- Kettlebell mass input
- Exercise type picker
- Live metrics display (current force, peak force, impulse, rep count)
- Start/Stop session controls

### HistoryView
- List of past sessions
- Shows date, exercise type, KB weight, peak normalized force, rep count
- Tap to view details

### SessionDetailView
- Complete session summary
- List of all reps with individual metrics

## Important Implementation Details

### Force Computation Constants
- `gConst = 9.81` m/s² (gravity constant)
- Force normalization: `forceNorm = forceN / (bodyMassKg * gConst)`

### Time Handling
- Accelerometer epochs are in milliseconds (UInt64)
- Session times are in seconds (TimeInterval)
- Conversion: `timeSinceStart = Double(epochMs - startTimeEpochMs) / 1000.0`

### Rep Detection Thresholds
- Default threshold: 0.4 (40% bodyweight)
- Exit threshold: threshold * 0.4 (16% bodyweight)
- These values may need tuning based on exercise type

### Simulation Mode
- Enabled in DEBUG builds
- Generates sine wave pattern accelerometer data
- Allows UI testing without physical hardware

## Known Issues / TODOs

1. **Accelerometer Streaming**: Not fully implemented - currently uses simulation mode. Need to:
   - Find correct SDK API for accelerometer access (likely `device.accelerometer` property)
   - Subscribe to accelerometer data publisher
   - Configure accelerometer settings (ODR, range)

2. **Connection State**: Uses timer-based approach instead of proper connection state publisher. Need to:
   - Find device connection state property/publisher
   - Subscribe to connection state changes

3. **Device Identification**: MetaWear devices don't have reliable `name` or `mac` properties. Currently shows generic labels.

4. **Error Handling**: Limited error handling for connection failures, accelerometer configuration failures.

5. **Orientation Handling**: Current force computation doesn't account for sensor orientation. Uses simple magnitude subtraction which may not be accurate for all orientations.

## Extension Points

### Adding New Exercise Types
1. Add case to `ExerciseType` enum in `Models/ExerciseType.swift`
2. UI will automatically update (uses `CaseIterable`)

### Adjusting Rep Detection
- Modify `RepDetector.thresholdNorm` default value
- Adjust exit threshold multiplier (currently 0.4)
- Consider exercise-specific thresholds

### Adding New Metrics
1. Add property to `SessionProcessor`
2. Update `processAccelerationSample()` to compute metric
3. Add to `SessionSummary` model
4. Update UI to display metric

### Changing Persistence
- Currently uses JSON files
- To switch to Core Data: modify `DataStore` class
- Core Data model exists but unused (`Kettlebell_Force.xcdatamodeld`)

## Code Patterns

### ObservableObject Pattern
- All managers use `ObservableObject` protocol
- Properties marked `@Published` trigger SwiftUI updates
- Use `@ObservedObject` or `@StateObject` in views

### Combine Publishers
- MetaWear SDK uses Combine publishers extensively
- Always store subscriptions in `Set<AnyCancellable>`
- Use `.receive(on: DispatchQueue.main)` for UI updates

### Error Handling
- Connection errors stored in `connectionError` published property
- UI displays errors when present
- No fatal errors - graceful degradation

## Build Configuration

- **Minimum iOS**: 16.0
- **Swift Version**: 5.0
- **Deployment Target**: iOS 16+
- **Bluetooth Permissions**: Required (configured in Info.plist)

## Info.plist Requirements

- `NSBluetoothAlwaysUsageDescription` - Required for BLE scanning
- `NSBluetoothPeripheralUsageDescription` - Required for BLE scanning
- `UIBackgroundModes` - Includes `bluetooth-central` for background scanning

## Testing

- Simulation mode available in DEBUG builds
- No unit tests currently implemented
- Manual testing with physical MetaMotionRL sensor required for full functionality

## Future Enhancements

1. Orientation-based gravity removal for more accurate force computation
2. Gyroscope integration for rotational metrics
3. Data export (CSV/JSON)
4. Cloud sync for sessions
5. Exercise-specific rep detection algorithms
6. Real-time visualization/graphs
7. Workout templates and programs

