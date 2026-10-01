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

        var restoredStates: [UUID: State] = [:]
        var visitIDs = Set<UUID>()

        for record in activeVisits {

            guard record.isActive,
                  record.startedAt.timeIntervalSince1970.isFinite else {
                throw PlaceVisitRestorationError.invalidRecord
            }

            guard visitIDs.insert(record.id).inserted else {
                throw PlaceVisitRestorationError.duplicateVisit
            }

            guard restoredStates[record.placeID] == nil else {
                throw PlaceVisitRestorationError.duplicatePlace
            }

            restoredStates[record.placeID] = .inside(
                record: record
            )
        }

        self.states = restoredStates

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

        var recognizedByID: [UUID: RecognizedPlace] = [:]

        for recognizedPlace in recognizedPlaces {

            let placeID = recognizedPlace.place.id

            if recognizedByID[placeID] == nil {
                recognizedByID[placeID] = recognizedPlace
            }
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

                        let record = makeVisit(
                            for: recognizedPlace,
                            at: timestamp
                        )

                        states[placeID] = .inside(
                            record: record
                        )

                        startedVisits.append(record)

                        events.append(
                            makeEvent(
                                kind: .arrived,
                                record: record,
                                at: timestamp
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

                    let record = makeVisit(
                        for: recognizedPlace,
                        at: timestamp
                    )

                    states[placeID] = .inside(
                        record: record
                    )

                    startedVisits.append(record)

                    events.append(
                        makeEvent(
                            kind: .arrived,
                            record: record,
                            at: timestamp
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
}

private extension PlaceVisitStateMachine {

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
