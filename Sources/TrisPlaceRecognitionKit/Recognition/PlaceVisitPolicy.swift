//
//  PlaceVisitPolicy.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//


import Foundation

public struct PlaceVisitPolicy: Sendable, Equatable {

    public let arrivalConfirmationInterval: TimeInterval
    public let departureConfirmationInterval: TimeInterval

    public init(
        arrivalConfirmationInterval: TimeInterval = 30,
        departureConfirmationInterval: TimeInterval = 60
    ) {
        self.arrivalConfirmationInterval =
            arrivalConfirmationInterval.isFinite
            && arrivalConfirmationInterval >= 0
            ? arrivalConfirmationInterval
            : 30

        self.departureConfirmationInterval =
            departureConfirmationInterval.isFinite
            && departureConfirmationInterval >= 0
            ? departureConfirmationInterval
            : 60
    }
}
