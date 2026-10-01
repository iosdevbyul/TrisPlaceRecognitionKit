# TrisPlaceRecognitionKit

A Swift Package for registering places, recognizing them from GPS and Wi-Fi signals, and recording confirmed arrival/departure visits on iOS.

TrisPlaceRecognitionKit separates place registration, recognition, visit state management, persistence, and UI so consuming apps can use only the pieces they need.

## Features

- Register places from the current GPS location
- Register places automatically, with Wi-Fi, or as GPS-only places
- Recognize places using GPS + Wi-Fi constraints
- Wi-Fi-first recognition with GPS fallback for GPS-only places
- Support multiple Wi-Fi identities per place
- Rename, delete, relocate, and update recognition radius
- Detect duplicate or overlapping place registrations
- Foreground recognition monitoring
- Arrival/departure confirmation with configurable timing policies
- Observation-gap handling to reduce false visit transitions
- Persistent visit history and visit events
- Restore active visits after app relaunch
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
Recognition Monitor
      ↓
Visit State Machine
      ↓
Visit Coordinator
      ↓
Visit Storage
```

### RegisteredPlace

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

## Foreground Monitoring

`PlaceRecognitionMonitor` repeatedly performs recognition while monitoring is active.

```swift
let monitor = PlaceRecognitionMonitor(
    recognitionService: recognitionService,
    policy: .wifiFirst,
    refreshInterval: 15
)

await monitor.start()
```

Current recognized places are exposed through:

```swift
monitor.recognizedPlaces
monitor.isMonitoring
monitor.lastErrorMessage
```

Stop monitoring with:

```swift
monitor.stop()
```

The current monitor is designed for foreground polling. Background place recognition is not yet provided by the package.

## Visit Tracking

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

## Persistent Visit Tracking

On iOS 17+, visit records and events can be stored using SwiftData.

```swift
let visitStore = try SwiftDataPlaceVisitStore()
```

`PlaceVisitCoordinator` connects persisted active visits to the visit state machine.

Restore persisted visits before sending new recognition observations:

```swift
let coordinator = PlaceVisitCoordinator(
    store: visitStore
)

try await coordinator.restore()
```

Then connect successful recognition observations from the monitor:

```swift
monitor.onSuccessfulRecognition = {
    [coordinator] places, observedAt in

    _ = try await coordinator.processSuccessfulObservation(
        places,
        at: observedAt
    )
}
```

Start monitoring only after restoration:

```swift
await monitor.start()
```

This allows an active visit to retain its original visit ID across app relaunches.

Recognition failures are not forwarded to the visit coordinator as empty observations, so a recognition error is not automatically interpreted as a departure.

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

Visit tracking follows a separate flow:

```text
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

This allows storage, location, and Wi-Fi implementations to be replaced without coupling them to the UI.

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
- Visit query APIs are currently storage-oriented (`fetchAll`, `fetchActiveVisits`, `fetchEvents`) rather than date/place-specific.
- The public visit-tracking setup still requires explicitly wiring the monitor, coordinator, and visit store.

## Roadmap

- Higher-level public visit-tracking API
- Visit queries by place and date range
- Background recognition
- Additional visit-recovery and idempotency hardening
- Visit-history UI in the demo app
- Public API documentation and 1.0.0 release preparation
