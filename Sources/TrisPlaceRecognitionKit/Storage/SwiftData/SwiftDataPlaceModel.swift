//
//  SwiftDataPlaceModel.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SwiftDataPlaceModel {

    @Attribute(.unique)
    var id: UUID

    var name: String

    var latitude: Double
    var longitude: Double
    var recognitionRadius: Double

    var ssid: String?
    var bssid: String?

    init(
        id: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        recognitionRadius: Double,
        ssid: String?,
        bssid: String?
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.recognitionRadius = recognitionRadius
        self.ssid = ssid
        self.bssid = bssid
    }
}
