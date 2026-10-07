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
    
    @Published
    public private(set) var duplicateWarnings: [PlaceDuplicateWarning] = []

    @Published
    public private(set) var duplicateWarningErrorMessage: String?

    private let duplicateCheckService: PlaceDuplicateCheckService

    private var warningRevision: UInt64 = 0

    private let managementService: PlaceManagementService
    private let networkManagementService: PlaceNetworkManagementService

    public init(
        place: RegisteredPlace,
        managementService: PlaceManagementService,
        networkManagementService: PlaceNetworkManagementService,
        duplicateCheckService: PlaceDuplicateCheckService
    ) {
        self.place = place
        self.name = place.name.value
        self.recognitionRadius = place.location?.recognitionRadius ?? PlaceRegistrationService.defaultRecognitionRadius
        self.managementService = managementService
        self.networkManagementService = networkManagementService
        self.duplicateCheckService = duplicateCheckService
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
            && place.location != nil
            && recognitionRadius != place.location?.recognitionRadius
    }

    public func rename() async {
        guard !isWorking, !didDelete else {
            return
        }

        let validatedName: PlaceName

        do {
            validatedName = try PlaceName(name)
        } catch {
            errorMessage = PlaceL10n.string("place.error.name_length")
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
            recognitionRadius = updated.location?.recognitionRadius ?? PlaceRegistrationService.defaultRecognitionRadius
        }
    }

    public func updateCurrentLocation() async {
        let placeID = place.id

        if let updated = await perform({
            try await self.managementService.updateCurrentLocation(
                for: placeID
            )
        }) {
            recognitionRadius =
                updated.location?.recognitionRadius
                ?? PlaceRegistrationService.defaultRecognitionRadius
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
            
            warningRevision &+= 1

            duplicateWarnings = []
            duplicateWarningErrorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    public func clearError() {
        errorMessage = nil
    }
    
    public func refreshDuplicateWarnings() async {
        guard !didDelete else {
            return
        }

        warningRevision &+= 1

        let revision = warningRevision
        let currentPlace = place

        do {
            let warnings = try await duplicateCheckService.check(
                candidate: currentPlace
            )

            guard revision == warningRevision,
                  currentPlace == place,
                  !didDelete else {
                return
            }

            duplicateWarnings = warnings
            duplicateWarningErrorMessage = nil
        } catch {
            guard revision == warningRevision,
                  currentPlace == place,
                  !didDelete else {
                return
            }

            duplicateWarnings = []
            duplicateWarningErrorMessage = error.localizedDescription
        }
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

            await refreshDuplicateWarnings()

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
                return PlaceL10n.string("place.error.not_found")

            case .invalidRecognitionRadius:
                return PlaceL10n.string("place.error.radius")

            case .invalidCurrentLocation:
                return PlaceL10n.string("place.error.invalid_location")
            }
        }

        if let error = error as? PlaceNetworkManagementError {
            switch error {
            case .placeNotFound:
                return PlaceL10n.string("place.error.not_found")

            case .currentWiFiUnavailable:
                return PlaceL10n.string("place.error.wifi_unavailable")

            case .networkNotRegistered:
                return PlaceL10n.string("place.error.network_not_registered")
            }
        }

        return error.localizedDescription
    }
}
