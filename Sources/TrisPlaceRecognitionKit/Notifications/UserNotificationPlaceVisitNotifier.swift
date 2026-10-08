//
//  UserNotificationPlaceVisitNotifier.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-05.
//

import Foundation
import TrisNotificationKit

struct UserNotificationPlaceVisitNotifier:
    PlaceVisitNotifying {

    func notifyArrival(
        placeName: String
    ) async throws {

        let notificationService =
            LocalNotificationService()

        try await notificationService
            .send(
                title:
                    PlaceL10n.string("place.notification.arrival_title"),
                body:
                    PlaceL10n.format("place.notification.arrival_body", placeName),
                identifier:
                    makeIdentifier()
            )
    }

    func notifyDeparture(
        placeName: String
    ) async throws {

        let notificationService =
            LocalNotificationService()

        try await notificationService
            .send(
                title:
                    PlaceL10n.string("place.notification.departure_title"),
                body:
                    PlaceL10n.format("place.notification.departure_body", placeName),
                identifier:
                    makeIdentifier()
            )
    }

    private func makeIdentifier()
        -> String {

        "TrisPlaceRecognitionKit.visit.\(UUID().uuidString)"
    }
}
