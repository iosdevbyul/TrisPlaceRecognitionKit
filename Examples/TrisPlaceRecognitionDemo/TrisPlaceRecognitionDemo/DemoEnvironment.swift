//
//  DemoEnvironment.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-09-27.
//


import Combine
import Foundation
import TrisLocationKit
import TrisPlaceRecognitionKit

@MainActor
final class DemoEnvironment: ObservableObject {

    @Published private(set) var store: (any PlaceStoring)?
    @Published private(set) var isPreparing = false
    @Published private(set) var errorMessage: String?

    let locationProvider = CoreLocationProvider()

    #if targetEnvironment(simulator)
    let wifiProvider: any WiFiProviding = DemoWiFiProvider()
    #else
    let wifiProvider: any WiFiProviding = SystemWiFiProvider()
    #endif

    func start() async {
        guard store == nil, !isPreparing else {
            return
        }

        isPreparing = true
        errorMessage = nil

        defer {
            isPreparing = false
        }

        let authorization = await locationProvider
            .requestWhenInUseAuthorization()

        switch authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            break

        default:
            errorMessage = "위치 접근 권한이 필요합니다."
            return
        }

        do {
            store = try await PlaceStoreFactory.makeDefaultStore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
