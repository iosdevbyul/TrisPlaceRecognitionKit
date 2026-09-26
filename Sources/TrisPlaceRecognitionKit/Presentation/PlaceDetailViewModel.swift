//
//  PlaceDetailViewModel.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Combine
import Foundation

@MainActor
public final class PlaceDetailViewModel: ObservableObject {

    @Published
    public private(set) var place: RegisteredPlace

    @Published
    public var name: String

    @Published
    public var recognitionRadius: Double

    @Published
    public private(set) var isWorking = false

    @Published
    public private(set) var didDelete = false

    @Published
    public private(set) var errorMessage: String?

    private let managementService: PlaceManagementService
    private let networkManagementService: PlaceNetworkManagementService

    public init(
        place: RegisteredPlace,
        managementService: PlaceManagementService,
        networkManagementService: PlaceNetworkManagementService
    ) {
        self.place = place
        self.name = place.name.value
        self.recognitionRadius = place.location.recognitionRadius
        self.managementService = managementService
        self.networkManagementService = networkManagementService
    }

    public var canRename: Bool {
        guard !isWorking,
              !didDelete,
              let validated = try? PlaceName(name) else {
            return false
        }

        return validated.value != place.name.value
    }

    public var canUpdateRadius: Bool {
        !isWorking
            && !didDelete
            && recognitionRadius.isFinite
            && recognitionRadius > 0
            && recognitionRadius != place.location.recognitionRadius
    }

    public func rename() async {
        guard !isWorking, !didDelete else {
            return
        }

        let validatedName: PlaceName

        do {
            validatedName = try PlaceName(name)
        } catch {
            errorMessage = "장소 이름은 1~10자로 입력해 주세요."
            return
        }

        let placeID = place.id

        if let updated = await perform({
            try await self.managementService.renamePlace(
                id: placeID,
                to: validatedName.value
            )
        }) {
            name = updated.name.value
        }
    }

    public func updateRadius() async {
        guard canUpdateRadius else {
            return
        }

        let placeID = place.id
        let radius = recognitionRadius

        if let updated = await perform({
            try await self.managementService.updateRecognitionRadius(
                for: placeID,
                to: radius
            )
        }) {
            recognitionRadius = updated.location.recognitionRadius
        }
    }

    public func updateCurrentLocation() async {
        let placeID = place.id

        if let updated = await perform({
            try await self.managementService.updateCurrentLocation(
                for: placeID
            )
        }) {
            recognitionRadius = updated.location.recognitionRadius
        }
    }

    public func addCurrentWiFi() async {
        let placeID = place.id

        _ = await perform({
            try await self.networkManagementService.addCurrentNetwork(
                to: placeID
            )
        })
    }

    public func removeNetwork(
        _ network: PlaceNetworkIdentity
    ) async {
        let placeID = place.id

        _ = await perform({
            try await self.networkManagementService.removeNetwork(
                network,
                from: placeID
            )
        })
    }

    public func deletePlace() async {
        guard !isWorking, !didDelete else {
            return
        }

        isWorking = true
        errorMessage = nil

        defer {
            isWorking = false
        }

        do {
            try await managementService.deletePlace(
                id: place.id
            )

            didDelete = true
        } catch {
            errorMessage = message(for: error)
        }
    }

    public func clearError() {
        errorMessage = nil
    }
}

private extension PlaceDetailViewModel {

    func perform(
        _ operation: @MainActor () async throws -> RegisteredPlace
    ) async -> RegisteredPlace? {
        guard !isWorking, !didDelete else {
            return nil
        }

        isWorking = true
        errorMessage = nil

        defer {
            isWorking = false
        }

        do {
            let updated = try await operation()

            place = updated

            return updated
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func message(for error: Error) -> String {
        if let error = error as? PlaceManagementError {
            switch error {
            case .placeNotFound:
                return "해당 장소를 찾을 수 없습니다."

            case .invalidRecognitionRadius:
                return "올바른 인식 반경을 입력해 주세요."

            case .invalidCurrentLocation:
                return "현재 위치를 정확하게 확인할 수 없습니다."
            }
        }

        if let error = error as? PlaceNetworkManagementError {
            switch error {
            case .placeNotFound:
                return "해당 장소를 찾을 수 없습니다."

            case .currentWiFiUnavailable:
                return "현재 연결된 Wi-Fi를 확인할 수 없습니다."

            case .networkNotRegistered:
                return "이미 제거되었거나 등록되지 않은 Wi-Fi입니다."
            }
        }

        return error.localizedDescription
    }
}
