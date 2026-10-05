//
//  PlaceVisitStateMachine.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation

public enum PlaceVisitRestorationError: Error, Sendable, Equatable {
    case invalidRecord
    case duplicateVisit
    case duplicatePlace
}

public struct PlaceVisitStateMachine: Sendable {

    private enum State: Sendable {

        case arrivalPending(
            firstSeenAt: Date
        )

        case inside(
            record: PlaceVisitRecord
        )

        case departurePending(
            record: PlaceVisitRecord,
            firstMissingAt: Date
        )
    }

    private let policy: PlaceVisitPolicy

    private var states: [UUID: State] = [:]

    private var lastProcessedAt: Date?

    public init(
        policy: PlaceVisitPolicy = .init()
    ) {
        self.policy = policy
    }

    // Restore only confirmed, active visits.
    // Pending confirmation periods are intentionally
    // not restored after an application restart.
    public init(
        policy: PlaceVisitPolicy = .init(),
        restoring activeVisits: [PlaceVisitRecord]
    ) throws {

        self.policy = policy

        var visitIDs = Set<UUID>()
        var placeIDs = Set<UUID>()

        for record in activeVisits {

            guard record.isActive,
                  record.startedAt.timeIntervalSince1970.isFinite else {
                throw PlaceVisitRestorationError.invalidRecord
            }

            guard visitIDs.insert(record.id).inserted else {
                throw PlaceVisitRestorationError.duplicateVisit
            }

            guard placeIDs.insert(record.placeID).inserted else {
                throw PlaceVisitRestorationError.duplicatePlace
            }
        }

        if let mostRecentVisit =
            activeVisits.max(
                by: {
                    if $0.startedAt == $1.startedAt {
                        return $0.id.uuidString
                            < $1.id.uuidString
                    }

                    return $0.startedAt
                        < $1.startedAt
                }
            ) {

            self.states = [
                mostRecentVisit.placeID:
                    .inside(
                        record:
                            mostRecentVisit
                    )
            ]

        } else {

            self.states = [:]
        }

        // Prevent restored visits from processing an
        // observation older than their start times.
        self.lastProcessedAt = activeVisits
            .map(\.startedAt)
            .max()
    }

    public var activeVisits: [PlaceVisitRecord] {

        states.values.compactMap { state in

            switch state {

            case .inside(let record):
                return record

            case .departurePending(let record, _):
                return record

            case .arrivalPending:
                return nil
            }
        }
        .sorted {
            $0.placeID.uuidString < $1.placeID.uuidString
        }
    }

    // Only process successful recognition observations.
    // Recognition failures and monitor suspension
    // must never be passed as an empty snapshot.
    public mutating func process(
        _ recognizedPlaces: [RecognizedPlace],
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        guard timestamp.timeIntervalSince1970.isFinite else {
            return PlaceVisitUpdate()
        }

        if let lastProcessedAt,
           timestamp <= lastProcessedAt {
            return PlaceVisitUpdate()
        }

        let hasObservationGap: Bool

        if let lastProcessedAt {

            let elapsed = timestamp.timeIntervalSince(
                lastProcessedAt
            )

            hasObservationGap =
                elapsed > policy.maximumObservationGap

        } else {

            hasObservationGap = false
        }

        lastProcessedAt = timestamp

        var recognizedByID:
            [UUID: RecognizedPlace] = [:]

        if let recognizedPlace =
            recognizedPlaces.first {

            recognizedByID[
                recognizedPlace.place.id
            ] =
                recognizedPlace
        }

        if hasObservationGap {
            resetPendingStates()
        }

        let allPlaceIDs = Set(states.keys)
            .union(recognizedByID.keys)
            .sorted {
                $0.uuidString < $1.uuidString
            }

        var events: [PlaceVisitEvent] = []
        var startedVisits: [PlaceVisitRecord] = []
        var endedVisits: [PlaceVisitRecord] = []

        for placeID in allPlaceIDs {

            if let recognizedPlace = recognizedByID[placeID] {

                switch states[placeID] {

                case nil:

                    if policy.arrivalConfirmationInterval == 0 {

                        let previousVisitUpdate =
                            finishOtherActiveVisits(
                                except:
                                    placeID,
                                at:
                                    timestamp
                            )

                        events.append(
                            contentsOf:
                                previousVisitUpdate.events
                        )

                        endedVisits.append(
                            contentsOf:
                                previousVisitUpdate
                                    .endedVisits
                        )

                        let record =
                            makeVisit(
                                for:
                                    recognizedPlace,
                                at:
                                    timestamp
                            )

                        states[placeID] =
                            .inside(
                                record:
                                    record
                            )

                        startedVisits.append(
                            record
                        )

                        events.append(
                            makeEvent(
                                kind:
                                    .arrived,
                                record:
                                    record,
                                at:
                                    timestamp
                            )
                        )

                    } else {

                        states[placeID] = .arrivalPending(
                            firstSeenAt: timestamp
                        )
                    }

                case .some(
                    .arrivalPending(let firstSeenAt)
                ):

                    let elapsed = timestamp.timeIntervalSince(
                        firstSeenAt
                    )

                    guard elapsed >=
                            policy.arrivalConfirmationInterval else {
                        continue
                    }

                    let previousVisitUpdate =
                        finishOtherActiveVisits(
                            except:
                                placeID,
                            at:
                                timestamp
                        )

                    events.append(
                        contentsOf:
                            previousVisitUpdate.events
                    )

                    endedVisits.append(
                        contentsOf:
                            previousVisitUpdate
                                .endedVisits
                    )

                    let record =
                        makeVisit(
                            for:
                                recognizedPlace,
                            at:
                                timestamp
                        )

                    states[placeID] =
                        .inside(
                            record:
                                record
                        )

                    startedVisits.append(
                        record
                    )

                    events.append(
                        makeEvent(
                            kind:
                                .arrived,
                            record:
                                record,
                            at:
                                timestamp
                        )
                    )

                case .some(.inside):

                    // The visit has already been confirmed.
                    // Never emit another arrival event.
                    continue

                case .some(
                    .departurePending(let record, _)
                ):

                    // The place was recognized again.
                    // Preserve the original visit ID.
                    states[placeID] = .inside(
                        record: record
                    )
                }

            } else {

                switch states[placeID] {

                case nil:

                    continue

                case .some(.arrivalPending):

                    states.removeValue(
                        forKey: placeID
                    )

                case .some(.inside(let record)):

                    if policy.departureConfirmationInterval == 0 {

                        let endedRecord = record.ending(
                            at: timestamp
                        )

                        states.removeValue(
                            forKey: placeID
                        )

                        endedVisits.append(
                            endedRecord
                        )

                        events.append(
                            makeEvent(
                                kind: .departed,
                                record: endedRecord,
                                at: timestamp
                            )
                        )

                    } else {

                        states[placeID] = .departurePending(
                            record: record,
                            firstMissingAt: timestamp
                        )
                    }

                case .some(
                    .departurePending(
                        let record,
                        let firstMissingAt
                    )
                ):

                    let elapsed = timestamp.timeIntervalSince(
                        firstMissingAt
                    )

                    guard elapsed >=
                            policy.departureConfirmationInterval else {
                        continue
                    }

                    let endedRecord = record.ending(
                        at: timestamp
                    )

                    states.removeValue(
                        forKey: placeID
                    )

                    endedVisits.append(
                        endedRecord
                    )

                    events.append(
                        makeEvent(
                            kind: .departed,
                            record: endedRecord,
                            at: timestamp
                        )
                    )
                }
            }
        }

        return PlaceVisitUpdate(
            events: events,
            startedVisits: startedVisits,
            endedVisits: endedVisits
        )
    }

    // A background region event is not enough by itself
    // to change visit state.
    //
    // The caller must first complete a successful
    // PlaceRecognitionService request caused by the region
    // event, then pass that successful observation here.
    //
    // Region transition + successful recognition is treated
    // as verified evidence, so foreground confirmation
    // intervals aren't required for the targeted place.
    mutating func processVerifiedBackgroundObservation(
        _ recognizedPlaces: [RecognizedPlace],
        trigger: BackgroundRecognitionTrigger,
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        guard timestamp.timeIntervalSince1970.isFinite else {
            return PlaceVisitUpdate()
        }

        if let lastProcessedAt,
           timestamp <= lastProcessedAt {
            return PlaceVisitUpdate()
        }

        let hasObservationGap: Bool

        if let lastProcessedAt {

            let elapsed = timestamp.timeIntervalSince(
                lastProcessedAt
            )

            hasObservationGap =
                elapsed > policy.maximumObservationGap

        } else {

            hasObservationGap = false
        }

        lastProcessedAt = timestamp

        if hasObservationGap {
            resetPendingStates()
        }

        switch trigger {

        case .monitoredRegionEntered(let placeID):

            return processVerifiedEntry(
                placeID: placeID,
                recognizedPlaces: recognizedPlaces,
                at: timestamp
            )

        case .monitoredRegionExited(let placeID):

            return processVerifiedExit(
                placeID: placeID,
                recognizedPlaces: recognizedPlaces,
                at: timestamp
            )

        case .significantLocationChange:
            return processVerifiedSignificantLocationChange(
                    recognizedPlaces:
                        recognizedPlaces,
                    at:
                        timestamp
                )
        }
    }
}

private extension PlaceVisitStateMachine {

    mutating func processVerifiedEntry(
        placeID: UUID,
        recognizedPlaces: [RecognizedPlace],
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        guard
            let recognizedPlace =
                recognizedPlaces.first(
                    where: {
                        $0.place.id
                            == placeID
                    }
                )
        else {

            // The system reported entry, but actual
            // recognition didn't confirm this place.
            return PlaceVisitUpdate()
        }

        switch states[placeID] {

        case nil,
             .some(.arrivalPending):

            let previousVisitUpdate =
                finishOtherActiveVisits(
                    except:
                        placeID,
                    at:
                        timestamp
                )

            let record =
                makeVisit(
                    for:
                        recognizedPlace,
                    at:
                        timestamp
                )

            states[placeID] =
                .inside(
                    record:
                        record
                )

            let arrivalEvent =
                makeEvent(
                    kind:
                        .arrived,
                    record:
                        record,
                    at:
                        timestamp
                )

            return PlaceVisitUpdate(
                events:
                    previousVisitUpdate.events
                    + [
                        arrivalEvent
                    ],
                startedVisits: [
                    record
                ],
                endedVisits:
                    previousVisitUpdate
                        .endedVisits
            )

        case .some(.inside):

            return PlaceVisitUpdate()

        case .some(
            .departurePending(
                let record,
                _
            )
        ):

            // Actual recognition disproved the pending
            // departure. Keep the original visit.
            states[placeID] =
                .inside(
                    record:
                        record
                )

            return PlaceVisitUpdate()
        }
    }

    mutating func processVerifiedExit(
        placeID: UUID,
        recognizedPlaces: [RecognizedPlace],
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        let stillRecognized =
            recognizedPlaces.contains {
                $0.place.id == placeID
            }

        if stillRecognized {

            if case .some(
                .departurePending(let record, _)
            ) = states[placeID] {

                states[placeID] = .inside(
                    record: record
                )
            }

            // The system reported exit, but actual
            // recognition still confirms the place.
            return PlaceVisitUpdate()
        }

        switch states[placeID] {

        case nil:

            return PlaceVisitUpdate()

        case .some(.arrivalPending):

            states.removeValue(
                forKey: placeID
            )

            return PlaceVisitUpdate()

        case .some(.inside(let record)):

            return finishVerifiedVisit(
                record,
                at: timestamp
            )

        case .some(
            .departurePending(let record, _)
        ):

            return finishVerifiedVisit(
                record,
                at: timestamp
            )
        }
    }

    mutating func finishOtherActiveVisits(
        except retainedPlaceID: UUID,
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        let otherPlaceIDs =
            states.keys
                .filter {
                    $0 != retainedPlaceID
                }
                .sorted {
                    $0.uuidString
                        < $1.uuidString
                }

        var events:
            [PlaceVisitEvent] = []

        var endedVisits:
            [PlaceVisitRecord] = []

        for placeID in otherPlaceIDs {

            guard
                let state =
                    states[placeID]
            else {
                continue
            }

            switch state {

            case .arrivalPending:

                // A verified entry supersedes any pending
                // arrival for another place.
                states.removeValue(
                    forKey:
                        placeID
                )

            case .inside(
                let record
            ),
            .departurePending(
                let record,
                _
            ):

                let endedRecord =
                    record.ending(
                        at:
                            timestamp
                    )

                states.removeValue(
                    forKey:
                        placeID
                )

                endedVisits.append(
                    endedRecord
                )

                events.append(
                    makeEvent(
                        kind:
                            .departed,
                        record:
                            endedRecord,
                        at:
                            timestamp
                    )
                )
            }
        }

        return PlaceVisitUpdate(
            events:
                events,
            endedVisits:
                endedVisits
        )
    }
    
    mutating func processVerifiedSignificantLocationChange(
        recognizedPlaces: [RecognizedPlace],
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        let recognizedPlaceIDs =
            Set(
                recognizedPlaces.map {
                    $0.place.id
                }
            )

        let placeIDs =
            states.keys
                .sorted {
                    $0.uuidString
                        < $1.uuidString
                }

        var events:
            [PlaceVisitEvent] = []

        var endedVisits:
            [PlaceVisitRecord] = []

        for placeID in placeIDs {

            guard
                let state =
                    states[placeID]
            else {
                continue
            }

            switch state {

            case .arrivalPending:

                // Significant movement must never confirm
                // an arrival by itself.
                continue

            case .inside(
                let record
            ):

                guard
                    !recognizedPlaceIDs.contains(
                        placeID
                    )
                else {
                    continue
                }

                let endedRecord =
                    record.ending(
                        at:
                            timestamp
                    )

                states.removeValue(
                    forKey:
                        placeID
                )

                endedVisits.append(
                    endedRecord
                )

                events.append(
                    makeEvent(
                        kind:
                            .departed,
                        record:
                            endedRecord,
                        at:
                            timestamp
                    )
                )

            case .departurePending(
                let record,
                _
            ):

                if recognizedPlaceIDs.contains(
                    placeID
                ) {

                    // Movement occurred, but recognition
                    // still confirms the place.
                    states[placeID] =
                        .inside(
                            record:
                                record
                        )

                    continue
                }

                let endedRecord =
                    record.ending(
                        at:
                            timestamp
                    )

                states.removeValue(
                    forKey:
                        placeID
                )

                endedVisits.append(
                    endedRecord
                )

                events.append(
                    makeEvent(
                        kind:
                            .departed,
                        record:
                            endedRecord,
                        at:
                            timestamp
                    )
                )
            }
        }

        return PlaceVisitUpdate(
            events:
                events,
            endedVisits:
                endedVisits
        )
    }
    
    mutating func finishVerifiedVisit(
        _ record: PlaceVisitRecord,
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        let endedRecord = record.ending(
            at: timestamp
        )

        states.removeValue(
            forKey: record.placeID
        )

        let event = makeEvent(
            kind: .departed,
            record: endedRecord,
            at: timestamp
        )

        return PlaceVisitUpdate(
            events: [
                event
            ],
            endedVisits: [
                endedRecord
            ]
        )
    }

    mutating func resetPendingStates() {

        let placeIDs = Array(states.keys)

        for placeID in placeIDs {

            guard let state = states[placeID] else {
                continue
            }

            switch state {

            case .arrivalPending:

                states.removeValue(
                    forKey: placeID
                )

            case .inside:

                // Preserve the confirmed visit.
                break

            case .departurePending(let record, _):

                // The missing interval is no longer
                // reliable after a long observation gap.
                states[placeID] = .inside(
                    record: record
                )
            }
        }
    }

    func makeVisit(
        for recognizedPlace: RecognizedPlace,
        at timestamp: Date
    ) -> PlaceVisitRecord {

        PlaceVisitRecord(
            placeID: recognizedPlace.place.id,
            startedAt: timestamp,
            arrivalEvidence: recognizedPlace.evidence
        )
    }

    func makeEvent(
        kind: PlaceVisitEvent.Kind,
        record: PlaceVisitRecord,
        at timestamp: Date
    ) -> PlaceVisitEvent {

        PlaceVisitEvent(
            visitID: record.id,
            placeID: record.placeID,
            kind: kind,
            occurredAt: timestamp
        )
    }
}
