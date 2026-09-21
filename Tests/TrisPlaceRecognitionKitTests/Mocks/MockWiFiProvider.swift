//
//  MockWiFiProvider.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

@testable import TrisPlaceRecognitionKit

final class MockWiFiProvider: WiFiProviding,
                              @unchecked Sendable {

    var network: WiFiNetwork?
    private(set) var currentNetworkCallCount = 0

    init(
        network: WiFiNetwork? = nil
    ) {
        self.network = network
    }

    func currentNetwork() async -> WiFiNetwork? {
        currentNetworkCallCount += 1
        return network
    }
}
