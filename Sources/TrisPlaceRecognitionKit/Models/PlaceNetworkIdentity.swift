//
//  PlaceNetworkIdentity.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

public struct PlaceNetworkIdentity: Sendable,
                                    Equatable,
                                    Hashable {

    public let ssid: String?
    public let bssid: String?

    public init(
        ssid: String?,
        bssid: String?
    ) {
        self.ssid = ssid
        self.bssid = bssid
    }
}
