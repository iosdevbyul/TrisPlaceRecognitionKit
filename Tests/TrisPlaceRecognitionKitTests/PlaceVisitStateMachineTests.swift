//
//  PlaceVisitStateMachineTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceVisitStateMachineTests {

    // MARK: - Arrival

    @Test
    func confirmsArrivalAfterConfirmationInterval() throws {

        let gym = try makePlace(name: "Gym")
        let recognizedGym = recognize(gym)

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 30,
                departureConfirmationInterval: 60
            )
        )

        let first = machine.process(
            [recognizedGym],
            at: time(0)
        )

        #expect(first.events.isEmpty)
        #expect(first.startedVisits.isEmpty)

        let second = machine.process(
            [recognizedGym],
            at: time(15)
        )

        #expect(second.events.isEmpty)

        let confirmed = machine.process(
            [recognizedGym],
            at: time(30)
        )

        #expect(confirmed.events.count == 1)
        #expect(confirmed.events.first?.kind == .arrived)
        #expect(confirmed.events.first?.placeID == gym.id)

        #expect(confirmed.startedVisits.count == 1)
        #expect(
            confirmed.startedVisits.first?.startedAt == time(30)
        )
        #expect(
            confirmed.startedVisits.first?.isActive == true
        )

        #expect(machine.activeVisits.count == 1)
    }

    @Test
    func doesNotEmitDuplicateArrival() throws {

        let gym = try makePlace(name: "Gym")
        let recognizedGym = recognize(gym)

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        let arrival = machine.process(
            [recognizedGym],
            at: time(0)
        )

        let second = machine.process(
            [recognizedGym],
            at: time(15)
        )

        let third = machine.process(
            [recognizedGym],
            at: time(30)
        )

        #expect(arrival.events.count == 1)
        #expect(arrival.events.first?.kind == .arrived)

        #expect(second.events.isEmpty)
        #expect(third.events.isEmpty)

        #expect(machine.activeVisits.count == 1)
    }

    @Test
    func cancelsArrivalWhenRecognitionIsInterrupted() throws {

        let gym = try makePlace(name: "Gym")
        let recognizedGym = recognize(gym)

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 30
            )
        )

        _ = machine.process(
            [recognizedGym],
            at: time(0)
        )

        let interrupted = machine.process(
            [],
            at: time(15)
        )

        #expect(interrupted.events.isEmpty)

        _ = machine.process(
            [recognizedGym],
            at: time(30)
        )

        let tooEarly = machine.process(
            [recognizedGym],
            at: time(45)
        )

        #expect(tooEarly.events.isEmpty)

        let confirmed = machine.process(
            [recognizedGym],
            at: time(60)
        )

        #expect(
            confirmed.events.first?.kind == .arrived
        )

        #expect(
            confirmed.startedVisits.first?.startedAt == time(60)
        )
    }

    // MARK: - Departure

    @Test
    func confirmsDepartureAndPreservesVisitID() throws {

        let gym = try makePlace(name: "Gym")
        let recognizedGym = recognize(gym)

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 60
            )
        )

        let arrival = machine.process(
            [recognizedGym],
            at: time(0)
        )

        let visitID = try #require(
            arrival.startedVisits.first?.id
        )

        let missing = machine.process(
            [],
            at: time(15)
        )

        #expect(missing.events.isEmpty)
        #expect(machine.activeVisits.count == 1)

        let stillMissing = machine.process(
            [],
            at: time(45)
        )

        #expect(stillMissing.events.isEmpty)

        let departure = machine.process(
            [],
            at: time(75)
        )

        #expect(departure.events.count == 1)
        #expect(
            departure.events.first?.kind == .departed
        )
        #expect(
            departure.events.first?.visitID == visitID
        )

        #expect(departure.endedVisits.count == 1)
        #expect(
            departure.endedVisits.first?.id == visitID
        )
        #expect(
            departure.endedVisits.first?.startedAt == time(0)
        )
        #expect(
            departure.endedVisits.first?.endedAt == time(75)
        )
        #expect(
            departure.endedVisits.first?.duration == 75
        )

        #expect(machine.activeVisits.isEmpty)
    }

    @Test
    func cancelsDepartureWhenPlaceIsRecognizedAgain() throws {

        let gym = try makePlace(name: "Gym")
        let recognizedGym = recognize(gym)

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 60
            )
        )

        let arrival = machine.process(
            [recognizedGym],
            at: time(0)
        )

        let originalID = try #require(
            arrival.startedVisits.first?.id
        )

        _ = machine.process(
            [],
            at: time(15)
        )

        let recovered = machine.process(
            [recognizedGym],
            at: time(30)
        )

        #expect(recovered.events.isEmpty)
        #expect(
            machine.activeVisits.first?.id == originalID
        )

        let repeated = machine.process(
            [recognizedGym],
            at: time(45)
        )

        #expect(repeated.events.isEmpty)
        #expect(machine.activeVisits.count == 1)
    }

    // MARK: - Multiple Places

    @Test
    func managesMultiplePlacesIndependently() throws {

        let gym = try makePlace(name: "Gym")
        let home = try makePlace(name: "Home")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        let arrivals = machine.process(
            [
                recognize(gym),
                recognize(home)
            ],
            at: time(0)
        )

        #expect(arrivals.events.count == 2)
        #expect(arrivals.startedVisits.count == 2)
        #expect(machine.activeVisits.count == 2)

        let update = machine.process(
            [recognize(home)],
            at: time(30)
        )

        #expect(update.events.count == 1)
        #expect(
            update.events.first?.kind == .departed
        )
        #expect(
            update.events.first?.placeID == gym.id
        )

        #expect(machine.activeVisits.count == 1)
        #expect(
            machine.activeVisits.first?.placeID == home.id
        )
    }

    // MARK: - Duplicate Observations

    @Test
    func ignoresDuplicateRecognitionInOneSnapshot() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        let update = machine.process(
            [
                recognize(gym),
                recognize(gym)
            ],
            at: time(0)
        )

        #expect(update.events.count == 1)
        #expect(update.startedVisits.count == 1)
        #expect(machine.activeVisits.count == 1)
    }

    @Test
    func ignoresOutOfOrderObservations() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        _ = machine.process(
            [recognize(gym)],
            at: time(60)
        )

        let oldObservation = machine.process(
            [],
            at: time(30)
        )

        #expect(oldObservation.events.isEmpty)
        #expect(machine.activeVisits.count == 1)
    }

    // MARK: - Revisit

    @Test
    func recognizesNewVisitAfterCompletedDeparture() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        let firstArrival = machine.process(
            [recognize(gym)],
            at: time(0)
        )

        let firstVisitID = try #require(
            firstArrival.startedVisits.first?.id
        )

        let departure = machine.process(
            [],
            at: time(30)
        )

        #expect(
            departure.events.first?.kind == .departed
        )

        let secondArrival = machine.process(
            [recognize(gym)],
            at: time(60)
        )

        let secondVisitID = try #require(
            secondArrival.startedVisits.first?.id
        )

        #expect(secondVisitID != firstVisitID)

        #expect(
            secondArrival.events.first?.kind == .arrived
        )
    }

    // MARK: - Observation Gap

    @Test
    func resetsPendingArrivalAfterObservationGap() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 30,
                departureConfirmationInterval: 60,
                maximumObservationGap: 45
            )
        )

        _ = machine.process(
            [recognize(gym)],
            at: time(0)
        )

        _ = machine.process(
            [recognize(gym)],
            at: time(15)
        )

        let afterGap = machine.process(
            [recognize(gym)],
            at: time(120)
        )

        #expect(afterGap.events.isEmpty)
        #expect(machine.activeVisits.isEmpty)

        let confirmed = machine.process(
            [recognize(gym)],
            at: time(150)
        )

        #expect(confirmed.events.count == 1)

        #expect(
            confirmed.events.first?.kind == .arrived
        )

        #expect(
            confirmed.startedVisits.first?.startedAt
                == time(150)
        )
    }

    @Test
    func resetsPendingDepartureAfterObservationGap() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 60,
                maximumObservationGap: 45
            )
        )

        let arrival = machine.process(
            [recognize(gym)],
            at: time(0)
        )

        let visitID = try #require(
            arrival.startedVisits.first?.id
        )

        _ = machine.process(
            [],
            at: time(15)
        )

        let afterGap = machine.process(
            [],
            at: time(120)
        )

        #expect(afterGap.events.isEmpty)

        #expect(
            machine.activeVisits.first?.id == visitID
        )

        let stillPending = machine.process(
            [],
            at: time(150)
        )

        #expect(stillPending.events.isEmpty)

        _ = machine.process(
            [],
            at: time(165)
        )

        let departure = machine.process(
            [],
            at: time(180)
        )

        #expect(departure.events.count == 1)

        #expect(
            departure.events.first?.kind == .departed
        )

        #expect(
            departure.events.first?.visitID == visitID
        )
    }

    @Test
    func ignoresConflictingObservationsAtSameTimestamp() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        let arrival = machine.process(
            [recognize(gym)],
            at: time(0)
        )

        let duplicate = machine.process(
            [],
            at: time(0)
        )

        #expect(arrival.events.count == 1)
        #expect(duplicate.events.isEmpty)
        #expect(machine.activeVisits.count == 1)
    }

    @Test
    func acceptsObservationAtMaximumGapBoundary() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 45,
                departureConfirmationInterval: 60,
                maximumObservationGap: 45
            )
        )

        _ = machine.process(
            [recognize(gym)],
            at: time(0)
        )

        let confirmed = machine.process(
            [recognize(gym)],
            at: time(45)
        )

        #expect(confirmed.events.count == 1)

        #expect(
            confirmed.events.first?.kind == .arrived
        )
    }

    @Test
    func doesNotEmitDuplicateArrivalAfterLongGap() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 60,
                maximumObservationGap: 45
            )
        )

        let arrival = machine.process(
            [recognize(gym)],
            at: time(0)
        )

        let visitID = try #require(
            arrival.startedVisits.first?.id
        )

        let afterGap = machine.process(
            [recognize(gym)],
            at: time(3600)
        )

        #expect(afterGap.events.isEmpty)
        #expect(afterGap.startedVisits.isEmpty)

        #expect(machine.activeVisits.count == 1)

        #expect(
            machine.activeVisits.first?.id == visitID
        )
    }

    @Test
    func rejectsNonFiniteObservationTimestamp() throws {

        let gym = try makePlace(name: "Gym")

        var machine = PlaceVisitStateMachine(
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        let invalidTimestamp = Date(
            timeIntervalSince1970: .infinity
        )

        let result = machine.process(
            [recognize(gym)],
            at: invalidTimestamp
        )

        #expect(result.events.isEmpty)
        #expect(machine.activeVisits.isEmpty)
    }
}

private extension PlaceVisitStateMachineTests {

    func time(
        _ seconds: TimeInterval
    ) -> Date {

        Date(
            timeIntervalSince1970: 1_000_000 + seconds
        )
    }

    func makePlace(
        name: String
    ) throws -> RegisteredPlace {

        RegisteredPlace(
            name: try PlaceName(name),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )
    }

    func recognize(
        _ place: RegisteredPlace
    ) -> RecognizedPlace {

        RecognizedPlace(
            place: place,
            distanceMeters: nil,
            evidence: .gpsOnlyNoWiFiConfigured
        )
    }
}
