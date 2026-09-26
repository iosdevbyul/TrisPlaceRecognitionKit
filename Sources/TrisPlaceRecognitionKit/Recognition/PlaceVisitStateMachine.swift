//
//  PlaceVisitStateMachine.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//


import Foundation

public struct PlaceVisitStateMachine: Sendable {

    private enum State: Sendable {
        case arrivalPending(firstSeenAt: Date)
        case inside(record: PlaceVisitRecord)
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

    // Includes visits that are confirmed but not yet ended.
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

    // Call only after a successful recognition request.
    // Recognition errors and monitor suspension must not
    // be represented as an empty recognizedPlaces array.
    public mutating func process(
        _ recognizedPlaces: [RecognizedPlace],
        at timestamp: Date
    ) -> PlaceVisitUpdate {

        // Ignore observations older than an already
        // processed observation.
        if let lastProcessedAt,
           timestamp < lastProcessedAt {
            return PlaceVisitUpdate()
        }

        lastProcessedAt = timestamp

        // Keep the first recognition for each place.
        // The existing recognition service already
        // sorts its results by evidence and distance.
        var recognizedByID: [UUID: RecognizedPlace] = [:]

        for recognizedPlace in recognizedPlaces {
            let placeID = recognizedPlace.place.id

            if recognizedByID[placeID] == nil {
                recognizedByID[placeID] = recognizedPlace
            }
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
                    // A newly recognized place.
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

                case .some(.arrivalPending(let firstSeenAt)):
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
                    // Already inside this place.
                    // Do not emit another arrival event.
                    continue

                case .some(
                    .departurePending(let record, _)
                ):
                    // The place was recognized again before
                    // departure could be confirmed.
                    states[placeID] = .inside(
                        record: record
                    )
                }

            } else {

                switch states[placeID] {

                case nil:
                    continue

                case .some(.arrivalPending):
                    // A pending arrival was interrupted.
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
