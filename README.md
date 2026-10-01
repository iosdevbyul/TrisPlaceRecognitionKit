# TrisPlaceRecognitionKit

A Swift Package for registering places, recognizing them from GPS and Wi-Fi signals, and recording confirmed arrival/departure visits on iOS.

TrisPlaceRecognitionKit separates place registration, recognition, visit tracking, persistence, and UI so consuming apps can use only the pieces they need.

## Features

- Register places from the current GPS location
- Register places automatically, with Wi-Fi, or as GPS-only places
- Recognize places using GPS + Wi-Fi constraints
- Wi-Fi-first recognition with GPS fallback for GPS-only places
- Support multiple Wi-Fi identities per place
- Rename, delete, relocate, and update recognition radius
- Detect duplicate or overlapping place registrations
- Foreground recognition monitoring
- High-level visit tracking with `PlaceVisitManager`
- Arrival/departure confirmation with configurable timing policies
- Observation-gap handling to reduce false visit transitions
- Persistent visit history and visit events
- Restore active visits after app relaunch
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

The package is split into a few focused areas:

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

The manager automatically:

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
manager.lastErrorMessage
manager.lastVisitErrorMessage
```

Stop monitoring with:

```swift
manager.stop()
```

Manual refresh is also available:

```swift
try await manager.refresh()
```

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

The current monitor is designed for foreground polling. Background place recognition is not yet provided by the package.

## Visit Tracking Internals

Place visits are confirmed through `PlaceVisitStateMachine`.

The default visit policy is:

```swift
PlaceVisitPolicy(
    arrivalConfirmationInterval: 30,
    departureConfirmationInterval: 60,
    maximumObservationGap: 45
)
```

This prevents a single transient recognition result from immediately creating an arrival or departure.

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

Visit confirmation is interrupted when the time between successful observations becomes too large.

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

The package keeps recognition logic, persistence, and presentation separate.

```text
Presentation
    ↓
Registration / Management / Recognition
    ↓
Protocols
    ↓
Storage / Wi-Fi / Location dependencies
```

The recommended visit-tracking flow is:

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

Apps that need lower-level control can use the underlying components directly.

## Testing

The project uses Swift Testing and runs tests against an iOS Simulator.

Example:

```bash
xcodebuild \
  -scheme TrisPlaceRecognitionKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The CI workflow also selects an available iOS Simulator dynamically.

## Current Limitations

- Recognition monitoring currently uses foreground polling.
- Background region/significant-location-change monitoring is not implemented yet.
- `SwiftDataPlaceVisitStore` requires iOS 17+.
- Visit queries currently load persisted records through `PlaceVisitStoring` and filter them in `PlaceVisitManager`; storage-native filtered queries are not implemented yet.

## Roadmap

- Background recognition
- Additional visit-recovery and idempotency hardening
- Storage-native visit query optimization
- Visit-history UI in the demo app
- Public API documentation cleanup
- 1.0.0 release preparation
