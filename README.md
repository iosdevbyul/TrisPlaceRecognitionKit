# TrisPlaceRecognitionKit

A Swift Package for registering places, recognizing them from GPS and Wi-Fi signals, recording arrival/departure visits, and optionally notifying users about place transitions on iOS.

TrisPlaceRecognitionKit separates place registration, foreground recognition, visit tracking, persistence, low-power background place detection, diagnostics, notifications, and UI so consuming apps can use only the pieces they need.

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
- Direct background arrival/departure transitions from monitored region enter/exit events
- Significant-location-change revalidation and candidate refresh through real place recognition
- Prioritize active visits when choosing limited background monitoring candidates
- High-level visit tracking with `PlaceVisitManager`
- Arrival/departure confirmation with configurable timing policies for foreground observations
- Observation-gap handling to reduce false foreground visit transitions
- Persistent visit history and visit events
- Restore active visits after app relaunch
- Recover buffered background region events after relaunch
- Query visits by place and date range
- Fetch the latest visit for a place
- Optional local notifications for persisted `ARRIVED` / `DEPARTED` visit events
- Host-controlled notification permission flow
- Diagnostic event logging and JSONL export support
- SwiftData persistence on iOS 17+
- JSON-backed place storage fallback for older supported iOS versions
- Reusable SwiftUI place-management UI
- Swift Testing coverage and GitHub Actions CI
- Real-device background recognition and notification validation

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
        from: "1.1.0"
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
Foreground Place Recognition
      ↓
PlaceVisitManager
      ↓
Visit Coordination
      ↓
Visit State Machine
      ↓
Visit Storage
```

Background visit tracking uses two different event paths.

Monitored region entry and exit are treated as background visit evidence directly:

```text
System Region Enter / Exit
          ↓
BackgroundRecognitionEventProcessor
          ↓
PlaceVisitCoordinator
          ↓
PlaceVisitStateMachine
          ↓
Visit Storage
          ↓
Optional Notification
```

Significant-location-change events still use real place recognition:

```text
Significant Location Change
          ↓
Real Place Recognition
          ↓
PlaceVisitCoordinator
          ↓
PlaceVisitStateMachine
          ↓
Visit Revalidation
```

Region enter/exit events are system-managed Core Location transitions for a registered place, so the package does not start another Wi-Fi/GPS recognition request before recording that transition.

Significant-location-change events are broader movement signals, so they are not treated as arrival/departure evidence by themselves.

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

These recognition policies are used for foreground recognition and significant-location-change revalidation. A monitored region enter/exit does not start another recognition request.

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
Background Region Monitoring
        +
Optional Notifications
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

## Place Visit Notifications

Local place-visit notifications are opt-in.

They are disabled by default so adding the package does not silently schedule system notifications.

Enable them when creating `PlaceVisitManager`:

```swift
let manager = try PlaceVisitManager(
    recognitionService: recognitionService,
    recognitionPolicy: .wifiFirst,
    placeVisitNotificationsEnabled: true
)
```

The package can then schedule local notifications for persisted visit events:

```text
ARRIVED
→ "Gym에 도착했습니다."

DEPARTED
→ "Home에서 나왔습니다."
```

For monitored region transitions:

```text
System Region Enter / Exit
          ↓
PlaceVisitCoordinator
          ↓
PlaceVisitEvent
          ↓
Visit persistence succeeds
          ↓
Local notification
```

Notifications are never sent merely because a raw callback was received. The visit update must first be accepted by the coordinator and persisted successfully.

Notification delivery is best-effort. Notification scheduling failure does not roll back an already persisted visit update.

### Notification Permission

The package does not request notification permission automatically.

The host app is responsible for requesting permission through `UNUserNotificationCenter`.

```swift
import UserNotifications

let granted = try await UNUserNotificationCenter
    .current()
    .requestAuthorization(
        options: [
            .alert,
            .sound
        ]
    )
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

Stop monitoring with:

```swift
monitor.stop()
```

This monitor is designed for foreground polling. Background recognition is managed separately by `PlaceVisitManager`.

## Background Recognition

`PlaceVisitManager` provides low-power background visit tracking based on system-managed Core Location services.

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

### Background Recognition Strategy

The package does not run continuous GPS tracking.

It does not call `locationUpdates()` for background place recognition and does not use a background timer.

For monitored region transitions, it follows this event-driven flow:

```text
System region event
      ↓
Visit transition processing
      ↓
Visit persistence
      ↓
Optional notification
      ↓
Idle
```

For a region entry:

```text
Registered Place Region Enter
            ↓
ARRIVED
```

For a region exit:

```text
Active Place Region Exit
           ↓
DEPARTED
```

The package intentionally does not perform an additional Wi-Fi/GPS recognition request before these transitions.

This prevents package-added recognition latency after Core Location has already delivered the system region transition.

### Region Transition Timing

The package can react immediately after it receives a Core Location region transition, but it cannot control exactly when iOS decides to deliver that transition.

```text
Physical boundary crossing
      ↓
iOS region-transition detection/delivery
      ↓
TrisPlaceRecognitionKit processes the transition immediately
```

There may still be system-level delay before the callback arrives. The package does not add another recognition wait after receiving it.

### Realistic Travel Flow

A visit does not need to transition directly from one registered place to another.

```text
Home active
    ↓
Home region exit
    ↓
Home DEPARTED
    ↓
No active visit while traveling
    ↓
Gym region enter
    ↓
Gym ARRIVED
```

Leaving Home does not depend on entering Gym or any other registered place.

Likewise, entering Gym does not depend on a previous place still being active.

### Background Arrival Evidence

Visits created from a monitored region entry use:

```swift
.systemRegion
```

as their `PlaceRecognitionEvidence`.

This keeps persisted visit history honest: a background region arrival is not falsely recorded as `.ssid`, `.bssid`, or a GPS-only recognition.

`SwiftDataPlaceVisitStore` persists and restores this evidence value.

### Candidate Selection

Core Location has a limited monitoring budget. `BackgroundRecognitionPolicy` controls how many places this package may select.

```swift
let policy = BackgroundRecognitionPolicy(
    maximumMonitoredPlaces: 20
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

Significant-location-change monitoring is used when needed for candidate refresh or active-visit recovery.

A significant location change is a low-power trigger, not visit evidence by itself.

```text
Significant movement
      ↓
One real recognition request
      ↓
Visit revalidation or candidate synchronization
      ↓
Idle
```

Unlike monitored region enter/exit, significant-location-change handling still uses actual place recognition.

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

The package does not start standard continuous background location updates and does not set `allowsBackgroundLocationUpdates`.

## App Relaunch Contract

Core Location can retain monitored region data across app launches.

If the user has enabled background place recognition, the host app should call:

```swift
try await manager.startBackgroundRecognition()
```

again during launch/relaunch setup after the required dependencies are available.

The package then:

1. Restores persisted active visits
2. Recalculates and synchronizes the monitored candidate set
3. Starts the background event listener
4. Delivers buffered package-owned region events
5. Processes region enter/exit transitions through the same visit coordinator used by foreground recognition
6. Uses real recognition for significant-location-change revalidation

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

## Visit Tracking Internals

The default foreground visit policy is:

```swift
PlaceVisitPolicy(
    arrivalConfirmationInterval: 30,
    departureConfirmationInterval: 60,
    maximumObservationGap: 45
)
```

Foreground observations use these confirmation intervals to prevent a single transient recognition result from immediately creating an arrival or departure.

Background monitored region transitions follow a different rule:

```text
System region enter
→ direct background ARRIVED

System region exit for active place
→ direct background DEPARTED
```

They do not wait for foreground confirmation intervals and do not start another Wi-Fi/GPS recognition request.

Significant-location-change events still use recognition results before visit revalidation.

A visit produces:

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

Only persisted visit events are eligible to produce optional local notifications.

## Observation Gaps

Visit confirmation is interrupted when the time between successful foreground observations becomes too large.

Already confirmed visits are preserved across observation gaps. Pending arrival or departure confirmation periods are restarted.

This policy applies to foreground recognition observations. Monitored background region transitions use the direct transition path described above.

## Persistent Visit Tracking

On iOS 17+, visit records and events can be stored using SwiftData.

```swift
let visitStore = try SwiftDataPlaceVisitStore()
```

Lower-level integrations can still use `PlaceVisitCoordinator` directly:

```swift
let coordinator = PlaceVisitCoordinator(
    store: visitStore
)

try await coordinator.restore()
```

Successful foreground recognition observations can be processed manually:

```swift
_ = try await coordinator.processSuccessfulObservation(
    places,
    at: observedAt
)
```

Recognition failures are not forwarded as successful empty foreground observations, so a recognition error is not automatically interpreted as a foreground departure.

Background monitored region exit follows its own direct departure path.

## Visit Queries

```swift
let visits = try await manager.fetchVisits()

let visitsForPlace = try await manager.fetchVisits(
    for: place.id
)

let visitsInRange = try await manager.fetchVisits(
    from: startDate,
    to: endDate
)

let latestVisit = try await manager.fetchLatestVisit(
    for: place.id
)

let events = try await manager.fetchEvents()
```

Invalid date ranges throw:

```swift
PlaceVisitQueryError.invalidDateRange
```

## Visit Storage

Available implementations include:

```text
InMemoryPlaceVisitStore
SwiftDataPlaceVisitStore
```

Visit updates are persisted atomically through:

```swift
apply(_ update: PlaceVisitUpdate)
```

## Diagnostics

`PlaceVisitManager` exposes diagnostic event access for real-device validation and troubleshooting.

```swift
let events = try await manager.fetchDiagnosticEvents()
```

Clear stored diagnostic events with:

```swift
try await manager.clearDiagnosticEvents()
```

Diagnostics cover areas such as:

```text
lifecycle
authorization
region synchronization
region events
recognition
visit updates
errors
```

The diagnostic flow intentionally avoids storing raw latitude/longitude values.

## Place Management

`PlaceManagementService` supports:

- Fetching registered places
- Renaming a place
- Updating recognition radius
- Updating the place to the current location
- Deleting a place

`PlaceNetworkManagementService` supports adding the current Wi-Fi network to a registered place and removing registered network identities.

## SwiftUI Place Management

```swift
PlaceManagementView(
    placeStore: placeStore,
    locationProvider: locationProvider,
    wifiProvider: SystemWiFiProvider()
)
```

The view provides place listing, registration, editing, deletion, duplicate warnings, and Wi-Fi management.

## Architecture

The monitored region background flow is:

```text
Core Location Region Event
        ↓
BackgroundRegionMonitoring
        ↓
BackgroundRecognitionEventProcessor
        ↓
PlaceVisitCoordinator
        ↓
PlaceVisitStateMachine
        ↓
Visit Persistence
        ↓
Optional Notification
```

The significant-location-change flow is:

```text
Core Location Significant Change
        ↓
BackgroundRecognitionEventProcessor
        ↓
PlaceRecognitionService
        ↓
PlaceVisitCoordinator
        ↓
PlaceVisitStateMachine
        ↓
Visit Revalidation / Candidate Refresh
```

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

## Testing

The project uses Swift Testing and runs tests against an iOS Simulator.

```bash
xcodebuild \
  -scheme TrisPlaceRecognitionKit \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The test suite covers:

- Foreground recognition
- Visit persistence
- `systemRegion` evidence persistence
- Background region synchronization
- Direct background enter/exit transitions without a second recognition request
- Significant-location-change recognition and revalidation
- Background lifecycle failure handling
- Relaunch recovery
- Arrival/departure notification dispatch
- Travel-gap transitions such as `Home → no active visit → Gym`

Background delivery and notification behavior should also be validated on physical devices because system location delivery depends on device capabilities and runtime conditions.

## Release

Current stable release:

```text
1.0.0
```

The current development branch contains an updated background region-transition policy intended for the next release.

Because the change adds the public `PlaceRecognitionEvidence.systemRegion` case, the next release should be treated as a minor semantic-version update rather than a patch release.

Planned next release:

```text
1.1.0
```

Swift Package Manager consumers should depend on a semantic version rather than the `main` branch for stable integration.

## Current Limitations

- `SwiftDataPlaceVisitStore` requires iOS 17+.
- Visit queries currently load persisted records through `PlaceVisitStoring` and filter them in `PlaceVisitManager`; storage-native filtered queries are not implemented yet.
- Core Location monitoring capacity is shared at the app level. Other location features in the consuming app can reduce the region capacity available to this package.
- The iOS 15-compatible region backend uses `CLLocationManager` region monitoring.
- Core Location controls when monitored region transitions are delivered. TrisPlaceRecognitionKit processes a received region transition immediately, but cannot guarantee zero delay between the physical boundary crossing and the system callback.
- Background recognition is intentionally limited to place arrival/departure detection and candidate refresh. It is not a general background route-tracking system.
- Background delivery remains subject to Core Location runtime behavior and should be validated on physical devices.

## Roadmap

- Evaluate a newer Core Location condition-monitoring backend while preserving the supported deployment strategy
- Storage-native visit query optimization
- Visit-history UI improvements in the demo app
- Public API documentation cleanup
