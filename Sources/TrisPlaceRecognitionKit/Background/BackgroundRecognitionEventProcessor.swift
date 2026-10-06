//
//  BackgroundRecognitionEventProcessor.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

struct BackgroundRecognitionProcessingResult {

    let recognizedPlaces:
        [RecognizedPlace]

    let visitUpdate:
        PlaceVisitUpdate

    var events:
        [PlaceVisitEvent] {

        visitUpdate.events
    }

    var startedVisits:
        [PlaceVisitRecord] {

        visitUpdate.startedVisits
    }

    var endedVisits:
        [PlaceVisitRecord] {

        visitUpdate.endedVisits
    }
}

@MainActor
final class BackgroundRecognitionEventProcessor {

    private let recognitionService:
        PlaceRecognitionService

    private let coordinator:
        PlaceVisitCoordinator

    private let recognitionPolicy:
        PlaceRecognitionPolicy

    init(
        recognitionService:
            PlaceRecognitionService,
        coordinator:
            PlaceVisitCoordinator,
        recognitionPolicy:
            PlaceRecognitionPolicy
    ) {
        self.recognitionService =
            recognitionService

        self.coordinator =
            coordinator

        self.recognitionPolicy =
            recognitionPolicy
    }

    func handle(
        _ trigger:
            BackgroundRecognitionTrigger,
        at timestamp:
            Date? = nil
    ) async throws
        -> BackgroundRecognitionProcessingResult {

        try Task.checkCancellation()

        let observedAt =
            timestamp ?? Date()

        switch trigger {

        case .monitoredRegionEntered(
            let placeID
        ):

            let registeredPlaces =
                try await recognitionService
                    .fetchRegisteredPlacesForBackgroundMonitoring()

            guard
                let place =
                    registeredPlaces.first(
                        where: {
                            $0.id == placeID
                        }
                    )
            else {

                return BackgroundRecognitionProcessingResult(
                    recognizedPlaces: [],
                    visitUpdate:
                        PlaceVisitUpdate()
                )
            }

            let regionPlace =
                RecognizedPlace(
                    place:
                        place,
                    distanceMeters:
                        nil,
                    evidence:
                        .systemRegion
                )

            let update =
                try await coordinator
                    .processVerifiedBackgroundObservation(
                        [
                            regionPlace
                        ],
                        trigger:
                            trigger,
                        at:
                            observedAt
                    )

            return BackgroundRecognitionProcessingResult(
                recognizedPlaces: [
                    regionPlace
                ],
                visitUpdate:
                    update
            )

        case .monitoredRegionExited(
            let placeID
        ):

            let registeredPlaces =
                try await recognitionService
                    .fetchRegisteredPlacesForBackgroundMonitoring()

            let place =
                registeredPlaces.first {
                    $0.id == placeID
                }

            var recognizedPlaces:
                [RecognizedPlace] = []

            if let place,
               !place.networkIdentities.isEmpty,
               let evidence =
                    await recognitionService
                        .currentWiFiEvidence(
                            for: place
                        ) {

                recognizedPlaces = [
                    RecognizedPlace(
                        place: place,
                        distanceMeters: nil,
                        evidence: evidence
                    )
                ]
            }

            let update =
                try await coordinator
                    .processVerifiedBackgroundObservation(
                        recognizedPlaces,
                        trigger:
                            trigger,
                        at:
                            observedAt
                    )

            return BackgroundRecognitionProcessingResult(
                recognizedPlaces:
                    recognizedPlaces,
                visitUpdate:
                    update
            )

        case .significantLocationChange:

            let recognizedPlaces =
                try await recognitionService
                    .recognizeCurrentPlaces(
                        policy:
                            recognitionPolicy
                    )

            try Task.checkCancellation()

            let completionTime =
                timestamp ?? Date()

            let update =
                try await coordinator
                    .processVerifiedBackgroundObservation(
                        recognizedPlaces,
                        trigger:
                            trigger,
                        at:
                            completionTime
                    )

            return BackgroundRecognitionProcessingResult(
                recognizedPlaces:
                    recognizedPlaces,
                visitUpdate:
                    update
            )
        }
    }
}
