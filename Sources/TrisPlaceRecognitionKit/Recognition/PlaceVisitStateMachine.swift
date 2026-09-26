//
//  PlaceVisitStateMachine.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation

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
    // Recognition failures must not be represented
    // as an empty recognizedPlaces array.
    public mutating func process(
        _ recognizedPlaces: [RecognizedPlace],
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        guard timestamp.timeIntervalSince1970.isFinite else {
            return PlaceVisitUpdate()
        }

        // Ignore observations that are older than or
        // equal to the last processed observation.
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

        // Keep only one recognition result per place.
        var recognizedByID: [UUID: RecognizedPlace] = [:]

        for recognizedPlace in recognizedPlaces {

            let placeID = recognizedPlace.place.id

            if recognizedByID[placeID] == nil {
                recognizedByID[placeID] = recognizedPlace
            }
        }

        // Reset pending confirmation periods after
        // a long gap without successful observations.
        //
        // Never discard an already confirmed visit.
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

                    // An existing visit must not generate
                    // another arrival event.
                    continue

                case .some(
                    .departurePending(let record, _)
                ):

                    // Recognition recovered before
                    // departure was confirmed.
                    states[placeID] = .inside(
                        record: record
                    )
                }

            } else {

                switch states[placeID] {

                case nil:

                    continue

                case .some(.arrivalPending):

                    // Arrival confirmation was interrupted.
                    states.removeValue(forKey: placeID)

                case .some(.inside(let record)):

                    if policy.departureConfirmationInterval == 0 {

                        let endedRecord = record.ending(
                            at: timestamp
                        )

                        states.removeValue(forKey: placeID)

                        endedVisits.append(endedRecord)

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

                    states.removeValue(forKey: placeID)

                    endedVisits.append(endedRecord)

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

                // Discard unconfirmed arrival.
                states.removeValue(forKey: placeID)

            case .inside:

                // Preserve confirmed visit.
                break

            case .departurePending(let record, _):

                // Discard the previous missing interval,
                // but keep the existing visit.
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
