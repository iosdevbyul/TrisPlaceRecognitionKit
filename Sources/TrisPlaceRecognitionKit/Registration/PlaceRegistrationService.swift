//
//  PlaceRegistrationService.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import TrisLocationKit

@MainActor
public final class PlaceRegistrationService {

    public static let defaultRecognitionRadius: Double = 100

    private let locationProvider: any LocationProviding
    private let wifiProvider: any WiFiProviding
    private let placeStore: any PlaceStoring
    
    public init(
        locationProvider: any LocationProviding,
        wifiProvider: any WiFiProviding,
        placeStore: any PlaceStoring
    ) {
        self.locationProvider = locationProvider
        self.wifiProvider = wifiProvider
        self.placeStore = placeStore
    }

    public func register(
        name: String,
        recognitionRadius: Double = defaultRecognitionRadius
    ) async throws -> RegisteredPlace {
        let placeName = try PlaceName(name)

        let locationPoint = try await locationProvider.requestCurrentLocation()
        let network = await wifiProvider.currentNetwork()

        let location = PlaceLocation(
            latitude: locationPoint.latitude,
            longitude: locationPoint.longitude,
            recognitionRadius: recognitionRadius
        )

        let networkIdentity = PlaceNetworkIdentity(
            ssid: network?.ssid,
            bssid: network?.bssid
        )

        let place = RegisteredPlace(
            name: placeName,
            location: location,
            networkIdentity: networkIdentity
        )

        try await placeStore.save(place)

        return place
    }
}
