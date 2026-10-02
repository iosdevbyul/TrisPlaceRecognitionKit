# TrisPlaceRecognitionKit

A Swift Package for registering places, recognizing them from GPS and Wi-Fi signals, and recording confirmed arrival/departure visits on iOS.

TrisPlaceRecognitionKit separates place registration, recognition, visit tracking, persistence, background place recognition, and UI so consuming apps can use only the pieces they need.

## Features

- Register places from the current GPS location
- Register places automatically, with Wi-Fi, or as GPS-only places
- Recognize places using GPS + Wi-Fi constraints
- Wi-Fi-first recognition with GPS fallback for GPS-only places
- Support multiple Wi-Fi identities per place
- Rename, delete, relocate, and update recognition radius
- Detect duplicate or overlapping place registrations
- Foreground recognition monitoring
- Low-power background place recognition
- System region monitoring for registered places
- Significant-location-change candidate refresh only when the registered place set exceeds the region-monitoring budget
- Prioritize active visits when choosing limited background monitoring candidates
- High-level visit tracking with `PlaceVisitManager`
- Arrival/departure confirmation with configurable timing policies
- Verified background enter/exit processing through real place recognition
- Observation-gap handling to reduce false visit transitions
- Persistent visit history and visit events
- Restore active visits after app relaunch
- Recover buffered background region events after relaunch
- Query visits by place and date range
- Fetch the latest visit for a place
- SwiftData persistence on iOS 17+
- JSON-backed place storage fallback for older supported iOS versions
- Reusable SwiftUI place-management UI
- Swift Testing coverage and GitHub Actions CI

## Requirements

- iOS 15+
- Swift 6.0+
- Xcode with Swift Package Manager support

Some persistence features use SwiftData and therefore require iOS 17+.

## Installation

Add TrisPlaceRecognitionKit with Swift Package Manager.

```swift
dependencies: [
    .package(
        url: "https://github.com/iosdevbyul/TrisPlaceRecognitionKit",
        branch: "main"
    )
]
```

Then add the library product to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(
            name: "TrisPlaceRecognitionKit",
            package: "TrisPlaceRecognitionKit"
        )
    ]
)
```

Import the package where needed:

```swift
import TrisPlaceRecognitionKit
```

## Core Concepts

The package is split into focused areas:

```text
Place Registration
      ↓
Place Storage
      ↓
Place Recognition
      ↓
PlaceVisitManager
      ↓
Visit Coordination
      ↓
Visit State Machine
      ↓
Visit Storage
```

Background recognition extends that flow without replacing it:

```text
System Region / Significant-Change Event
                ↓
     Background Recognition
                ↓
      Real Place Recognition
                ↓
       PlaceVisitCoordinator
                ↓
      PlaceVisitStateMachine
                ↓
          Visit Storage
```

A system region event is only a trigger. It is not treated directly as an arrival or departure.

## RegisteredPlace

A registered place contains:

- A stable UUID
- A validated name
- Latitude and longitude
- Recognition radius
- A primary Wi-Fi identity
- Optional additional Wi-Fi identities

```swift
let place = RegisteredPlace(
    name: try PlaceName("Gym"),
    location: PlaceLocation(
        latitude: 37.5665,
        longitude: 126.9780,
        recognitionRadius: 100
    ),
    networkIdentity: PlaceNetworkIdentity(
        ssid: "GYM_WIFI",
        bssid: nil
    )
)
```

## Place Registration

`PlaceRegistrationService` creates places from the current location and optionally the current Wi-Fi network.

The consuming app provides:

- `LocationProviding`
- `WiFiProviding`
- `PlaceStoring`

```swift
let service = PlaceRegistrationService(
    locationProvider: locationProvider,
    wifiProvider: SystemWiFiProvider(),
    placeStore: placeStore
)

let place = try await service.register(
    name: "Gym",
    recognitionRadius: 100,
    method: .automatic
)
```

### Registration Methods

```swift
.automatic
.wifi
.gpsOnly
```

`automatic` uses the current Wi-Fi network when available.

`wifi` requires a usable current Wi-Fi network.

`gpsOnly` intentionally registers the place without Wi-Fi identity information.

## Place Persistence

Use the default place-store factory when the app does not need to control the storage implementation directly.

```swift
let placeStore = try await PlaceStoreFactory.makeDefaultStore()
```

On iOS 17+, the default store uses SwiftData. The package also contains migration support for legacy JSON-backed place data.

## Place Recognition

Create a recognition service from the same dependencies used for place registration.

```swift
let recognitionService = PlaceRecognitionService(
    locationProvider: locationProvider,
    wifiProvider: SystemWiFiProvider(),
    placeStore: placeStore
)
```

Then recognize the current places:

```swift
let places = try await recognitionService.recognizeCurrentPlaces(
    policy: .wifiFirst
)
```

### Recognition Policies

#### `gpsConstrained`

GPS proximity is required. Wi-Fi information is used to strengthen or reject the match depending on the registered place.

#### `wifiFirst`

Wi-Fi matches are preferred and can return without requesting GPS.

If no Wi-Fi match is found, GPS is used only for places registered without Wi-Fi identities.

## High-Level Visit Tracking

`PlaceVisitManager` is the recommended public entry point for visit tracking.

It combines:

```text
PlaceRecognitionMonitor
        +
PlaceVisitCoordinator
        +
PlaceVisitStoring
        +
Background Recognition
```

into a single observable object.

### iOS 17+

When the default SwiftData visit store is acceptable:

```swift
let manager = try PlaceVisitManager(
    recognitionService: recognitionService,
    recognitionPolicy: .wifiFirst
)

try await manager.start()
```

The foreground manager automatically:

1. Restores persisted active visits
2. Starts recognition monitoring
3. Sends successful observations to the visit state machine
4. Persists confirmed arrivals and departures
5. Keeps `activeVisits` synchronized

### Custom Visit Store

A custom `PlaceVisitStoring` implementation can be injected directly.

```swift
let manager = PlaceVisitManager(
    recognitionService: recognitionService,
    visitStore: InMemoryPlaceVisitStore(),
    recognitionPolicy: .wifiFirst
)

try await manager.start()
```

This is also the way to use visit tracking on supported systems where `SwiftDataPlaceVisitStore` is unavailable.

### Observable State

`PlaceVisitManager` exposes:

```swift
manager.recognizedPlaces
manager.activeVisits
manager.isMonitoring
manager.isBackgroundRecognitionEnabled
manager.lastErrorMessage
manager.lastVisitErrorMessage
manager.lastBackgroundErrorMessage
```

Foreground monitoring and background recognition have separate lifecycles.

Stop foreground monitoring with:

```swift
manager.stop()
```

Manual foreground refresh is available with:

```swift
try await manager.refresh()
```

Stopping foreground monitoring does not remove background region monitoring.

## Foreground Monitoring

`PlaceRecognitionMonitor` remains available as a lower-level API when an app wants to manage recognition without the high-level visit manager.

```swift
let monitor = PlaceRecognitionMonitor(
    recognitionService: recognitionService,
    policy: .wifiFirst,
    refreshInterval: 15
)

await monitor.start()
```

Current recognition state is exposed through:

```swift
monitor.recognizedPlaces
monitor.isMonitoring
monitor.lastErrorMessage
monitor.lastVisitErrorMessage
```

Stop monitoring with:

```swift
monitor.stop()
```

This monitor is designed for foreground polling. Background recognition is managed separately by `PlaceVisitManager`.

## Background Recognition

`PlaceVisitManager` provides low-power background recognition based on system-managed location services.

Start it with:

```swift
try await manager.startBackgroundRecognition()
```

Refresh the currently monitored candidate set manually with:

```swift
try await manager.refreshBackgroundRecognition()
```

Stop background recognition with:

```swift
await manager.stopBackgroundRecognition()
```

`stopBackgroundRecognition()` removes the package-owned monitored regions and stops the package-owned significant-location-change service.

### Background Recognition Strategy

The package does not run continuous GPS tracking.

It does not call `locationUpdates()` for background recognition and does not use a background timer.

Instead, it follows this event-driven flow:

```text
System region event
      ↓
One real recognition request
      ↓
Verified place observation
      ↓
PlaceVisitCoordinator
      ↓
Arrival / departure update
      ↓
Idle
```

For a region entry:

```text
Region Enter
    +
Successful recognition confirms the same place
    ↓
ARRIVED
```

For a region exit:

```text
Region Exit
    +
Successful recognition no longer confirms that place
    ↓
DEPARTED
```

A recognition failure is not converted into an empty result and therefore is not treated as a departure.

### Candidate Selection

Core Location has a limited monitoring budget. `BackgroundRecognitionPolicy` controls how many places this package may select.

```swift
let policy = BackgroundRecognitionPolicy(
    maximumMonitoredPlaces: 20
)

let manager = PlaceVisitManager(
    recognitionService: recognitionService,
    visitStore: visitStore,
    recognitionPolicy: .wifiFirst,
    backgroundRecognitionPolicy: policy
)
```

Candidate selection follows these priorities:

```text
Active visit places
      ↓
Nearest registered places
      ↓
Deterministic identifier ordering
```

Active visits are prioritized so a currently active place is not discarded simply because another registered place is geographically closer.

### Significant-Location-Change Refresh

If every registered place fits inside the configured monitoring limit, the package does not enable significant-location-change monitoring.

```text
Registered places <= monitored candidate limit
→ Region monitoring only
→ Significant-location-change monitoring OFF
```

If there are more registered places than the package can monitor simultaneously:

```text
Registered places > monitored candidate limit
→ Monitor the selected candidate set
→ Significant-location-change monitoring ON
```

A significant location change is used only as a trigger to recalculate candidates.

```text
Significant movement
      ↓
One current-location snapshot
      ↓
Recalculate nearby candidates
      ↓
Synchronize monitored regions
      ↓
Idle
```

It is not treated as visit evidence and does not create an arrival or departure by itself.

## Background Authorization

Background recognition intentionally requires Always location authorization.

The consuming app should include these privacy usage descriptions in its app target:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Explain why the app uses location while in use.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Explain why the app needs location-based place recognition in the background.</string>
```

The final text must describe the app's actual user-facing reason for location access.

A recommended authorization flow is:

```text
Request When In Use authorization
        ↓
User grants When In Use
        ↓
Call startBackgroundRecognition()
        ↓
Package requests Always authorization when needed
        ↓
BackgroundRecognitionManagerError.alwaysAuthorizationRequired
        ↓
Wait for the authorization state to change
        ↓
Call startBackgroundRecognition() again after authorizedAlways
```

`startBackgroundRecognition()` can surface:

```swift
BackgroundRecognitionManagerError.alwaysAuthorizationRequired
BackgroundRecognitionManagerError.authorizationDenied
BackgroundRecognitionManagerError.authorizationRestricted
BackgroundRecognitionManagerError.authorizationUnknown
BackgroundRecognitionManagerError.unacceptableLocationSnapshot
```

The package does not start standard continuous background location updates and does not set `allowsBackgroundLocationUpdates`.

If the consuming app separately implements continuous workout route tracking or another continuous background-location feature, that feature must configure its own background-location requirements independently.

## App Relaunch Contract

Core Location can retain monitored region data across app launches.

The consuming app is responsible for recreating its location dependencies and `PlaceVisitManager` when the app is relaunched.

If the user has enabled background place recognition, the app should call:

```swift
try await manager.startBackgroundRecognition()
```

again during launch/relaunch setup after the required dependencies are available.

The package then:

1. Restores persisted active visits
2. Recalculates and synchronizes the monitored candidate set
3. Starts the background event listener
4. Delivers buffered package-owned region events
5. Processes verified arrivals or departures through the same visit coordinator used by foreground recognition

The package does not persist the user's preference for whether background recognition should be enabled.

The consuming app should persist that preference and use it to decide whether `startBackgroundRecognition()` should be called after a later launch.

### Relaunch Safety

A package-owned region event that arrives before the background event stream is attached is buffered by the Core Location adapter.

Active visits are restored before buffered events are processed.

This prevents an exit event after relaunch from being evaluated against an empty visit state.

## Foreground and Background Independence

Foreground polling and background recognition are intentionally separate.

```text
manager.start()
→ Starts foreground polling

manager.stop()
→ Stops foreground polling only

manager.startBackgroundRecognition()
→ Starts low-power background place recognition

manager.stopBackgroundRecognition()
→ Stops background place recognition only
```

This allows an app to stop foreground polling when its UI is no longer active while leaving system-managed background place detection enabled.

## Visit Tracking Internals

Place visits are confirmed through `PlaceVisitStateMachine`.

The default foreground visit policy is:

```swift
PlaceVisitPolicy(
    arrivalConfirmationInterval: 30,
    departureConfirmationInterval: 60,
    maximumObservationGap: 45
)
```

Foreground observations use these confirmation intervals to prevent a single transient recognition result from immediately creating an arrival or departure.

Verified background region transitions follow a different rule:

```text
System region transition
        +
Successful real recognition
        ↓
Verified transition
```

The targeted place can then be confirmed without waiting for foreground polling intervals.

A confirmed visit produces:

```swift
PlaceVisitRecord
PlaceVisitEvent
PlaceVisitUpdate
```

Visit events are either:

```swift
.arrived
.departed
```

## Observation Gaps

Visit confirmation is interrupted when the time between successful foreground observations becomes too large.

This prevents an old partial confirmation period from being reused after monitoring was suspended or observations were unavailable.

Already confirmed visits are preserved across observation gaps.

Pending arrival or departure confirmation periods are restarted.

## Persistent Visit Tracking

On iOS 17+, visit records and events can be stored using SwiftData.

```swift
let visitStore = try SwiftDataPlaceVisitStore()
```

`PlaceVisitManager` uses this store automatically through its iOS 17 convenience initializer.

Lower-level integrations can still use `PlaceVisitCoordinator` directly:

```swift
let coordinator = PlaceVisitCoordinator(
    store: visitStore
)

try await coordinator.restore()
```

Then successful recognition observations can be processed manually:

```swift
_ = try await coordinator.processSuccessfulObservation(
    places,
    at: observedAt
)
```

This allows an active visit to retain its original visit ID across app relaunches.

Recognition failures are not forwarded as successful empty observations, so a recognition error is not automatically interpreted as a departure.

## Visit Queries

`PlaceVisitManager` provides high-level visit-history queries.

### All Visits

```swift
let visits = try await manager.fetchVisits()
```

### Visits for a Place

```swift
let visits = try await manager.fetchVisits(
    for: place.id
)
```

### Visits Overlapping a Date Range

```swift
let visits = try await manager.fetchVisits(
    from: startDate,
    to: endDate
)
```

A visit is included when any portion of the visit overlaps the requested closed date range.

Active visits are treated as continuing beyond their start time.

### Visits for a Place Within a Date Range

```swift
let visits = try await manager.fetchVisits(
    for: place.id,
    from: startDate,
    to: endDate
)
```

### Latest Visit for a Place

```swift
let latestVisit = try await manager.fetchLatestVisit(
    for: place.id
)
```

### Visit Events

```swift
let events = try await manager.fetchEvents()
```

Invalid date ranges throw:

```swift
PlaceVisitQueryError.invalidDateRange
```

## Visit Storage

`PlaceVisitStoring` defines the visit persistence contract.

Available implementations include:

```text
InMemoryPlaceVisitStore
SwiftDataPlaceVisitStore
```

The store exposes:

```swift
fetchAll()
fetchActiveVisits()
fetchEvents()
```

Visit updates are persisted atomically through:

```swift
apply(_ update: PlaceVisitUpdate)
```

## Place Management

`PlaceManagementService` supports:

- Fetching registered places
- Renaming a place
- Updating recognition radius
- Updating the place to the current location
- Deleting a place

`PlaceNetworkManagementService` supports adding the current Wi-Fi network to a registered place and removing registered network identities.

## Duplicate Detection

Before saving a candidate place, the package can check for duplicate or overlapping registrations.

```swift
let candidate = try await registrationService.prepareRegistration(
    name: "Gym"
)

let duplicateCheckService = PlaceDuplicateCheckService(
    placeStore: placeStore
)

let warnings = try await duplicateCheckService.check(
    candidate: candidate
)

if warnings.isEmpty {
    try await registrationService.savePrepared(candidate)
}
```

## SwiftUI Place Management

The package includes a reusable place-management UI.

```swift
PlaceManagementView(
    placeStore: placeStore,
    locationProvider: locationProvider,
    wifiProvider: SystemWiFiProvider()
)
```

The view provides place listing, registration, editing, deletion, duplicate warnings, and Wi-Fi management.

## Architecture

The package keeps recognition logic, persistence, background system adapters, and presentation separate.

```text
Presentation
    ↓
Registration / Management / Recognition
    ↓
Visit Manager / Background Recognition
    ↓
Protocols
    ↓
Storage / Wi-Fi / Location dependencies
```

The recommended foreground visit-tracking flow is:

```text
PlaceVisitManager
        ↓
PlaceRecognitionMonitor
        ↓
PlaceVisitCoordinator
        ↓
PlaceVisitStateMachine
        ↓
PlaceVisitStoring
        ↓
InMemory / SwiftData
```

The background flow is:

```text
Core Location system event
        ↓
BackgroundRegionMonitoring
        ↓
BackgroundRecognitionEventProcessor
        ↓
PlaceRecognitionService
        ↓
PlaceVisitCoordinator
        ↓
PlaceVisitStateMachine
```

Apps that need lower-level foreground control can use the underlying public components directly.

## Power and Scope

Background recognition is intentionally event-driven.

The package does not provide:

- Continuous route recording
- Workout distance tracking
- Speed or pace tracking
- Elevation tracking
- Background polling timers
- Continuous standard GPS updates

Those responsibilities belong to a dedicated workout/location-tracking component.

For example, a workout module may independently own continuous location updates while an active workout is running. TrisPlaceRecognitionKit does not start a second continuous GPS stream for background place recognition.

## Testing

The project uses Swift Testing and runs tests against an iOS Simulator.

Example:

```bash
xcodebuild \
  -scheme TrisPlaceRecognitionKit \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The test suite covers foreground recognition, visit persistence, background region synchronization, verified enter/exit processing, significant-location-change candidate reselection, background lifecycle failure handling, and relaunch recovery.

The CI workflow also selects an available iOS Simulator dynamically.

Background delivery behavior should also be validated on physical devices before release because system location delivery depends on device capabilities and runtime conditions.

## Current Limitations

- `SwiftDataPlaceVisitStore` requires iOS 17+.
- Visit queries currently load persisted records through `PlaceVisitStoring` and filter them in `PlaceVisitManager`; storage-native filtered queries are not implemented yet.
- Core Location monitoring capacity is shared at the app level. Other location features in the consuming app can reduce the region capacity available to this package.
- The iOS 15-compatible region backend uses `CLLocationManager` region monitoring. Newer SDKs provide newer condition-monitoring APIs, but the package currently preserves iOS 15 deployment compatibility.
- Background recognition is intentionally limited to place arrival/departure detection and candidate refresh. It is not a general background route-tracking system.
- Real background/relaunch behavior must be validated on physical devices in addition to simulator unit tests.

## Roadmap

- Evaluate a newer Core Location condition-monitoring backend while preserving the supported deployment strategy
- Storage-native visit query optimization
- Visit-history UI in the demo app
- Public API documentation cleanup
- Real-device background recognition verification
- 1.0.0 release preparation
