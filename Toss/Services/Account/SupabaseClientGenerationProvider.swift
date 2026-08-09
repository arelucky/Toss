import Foundation
import Supabase

typealias SupabaseGenerationClientFactory = (
    _ configuration: SupabaseConfiguration,
    _ storage: any AuthLocalStorage
) -> SupabaseClient

final class SupabaseClientGenerationProvider {
    private let lock = NSLock()
    private let configuration: SupabaseConfiguration
    private let storageBackend: any AuthLocalStorage
    private let storageKey: String
    private let clientFactory: SupabaseGenerationClientFactory
    private let authority: SupabaseClientGenerationAuthority
    private var currentGeneration: SupabaseClientGeneration
    private var replacementReservationID: SupabaseClientGenerationID?

    init(
        configuration: SupabaseConfiguration,
        storageBackend: any AuthLocalStorage,
        storageKey: String = AppEnvironment.authStorageKey,
        clientFactory: @escaping SupabaseGenerationClientFactory = SupabaseClientGenerationProvider.liveClient
    ) {
        self.configuration = configuration
        self.storageBackend = storageBackend
        self.storageKey = storageKey
        self.clientFactory = clientFactory
        let generationID = SupabaseClientGenerationID()
        let authority = SupabaseClientGenerationAuthority(initialActiveGenerationID: generationID)
        self.authority = authority
        let storage = GenerationBoundAuthLocalStorage(
            generationID: generationID,
            backend: storageBackend,
            authority: authority
        )
        let client = clientFactory(configuration, storage)
        currentGeneration = SupabaseClientGeneration(
            id: generationID,
            client: client,
            authStorage: storage,
            authority: authority
        )
    }

    func current() -> SupabaseClientGeneration {
        lock.withLock { currentGeneration }
    }

    func isCurrent(_ generationID: SupabaseClientGenerationID) -> Bool {
        lock.withLock {
            currentGeneration.id == generationID && currentGeneration.lifecycle == .active
        }
    }

    func rotate(replacing expectedID: SupabaseClientGenerationID) throws -> SupabaseClientGeneration {
        let outgoing = try beginRetirement(expectedID: expectedID)
        try outgoing.authStorage.remove(key: storageKey)
        return try finishRetirementAndActivateReplacement(expectedID: expectedID)
    }

    func retireFailedCandidate(
        expectedID: SupabaseClientGenerationID
    ) throws -> SupabaseClientGeneration {
        try rotate(replacing: expectedID)
    }

    func beginRetirement(expectedID: SupabaseClientGenerationID) throws -> SupabaseClientGeneration {
        try lock.withLock {
            guard currentGeneration.id == expectedID else {
                throw SupabaseClientGenerationError.generationNotActive
            }
            if currentGeneration.lifecycle == .retiring {
                return currentGeneration
            }
            try authority.beginRetirement(of: expectedID)
            return currentGeneration
        }
    }

    func finishRetirementAndActivateReplacement(
        expectedID: SupabaseClientGenerationID
    ) throws -> SupabaseClientGeneration {
        guard try storageBackend.retrieve(key: storageKey) == nil else {
            throw AuthSessionStorageError.sessionStillPresent
        }
        let replacementID = try lock.withLock {
            guard currentGeneration.id == expectedID,
                  currentGeneration.lifecycle == .retiring else {
                throw SupabaseClientGenerationError.generationNotActive
            }
            guard replacementReservationID == nil else {
                throw SupabaseClientGenerationError.replacementInProgress
            }
            let replacementID = SupabaseClientGenerationID()
            replacementReservationID = replacementID
            return replacementID
        }
        let replacement = makeGeneration(id: replacementID)
        return try lock.withLock {
            guard currentGeneration.id == expectedID,
                  currentGeneration.lifecycle == .retiring,
                  replacementReservationID == replacementID else {
                throw SupabaseClientGenerationError.generationNotActive
            }
            try authority.finishRetirement(of: expectedID)
            try authority.activate(replacement.id)
            currentGeneration = replacement
            replacementReservationID = nil
            return replacement
        }
    }

    var writableGenerationCount: Int {
        authority.writableGenerationCount
    }

    private static func liveClient(
        configuration: SupabaseConfiguration,
        storage: any AuthLocalStorage
    ) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(storage: storage, storageKey: AppEnvironment.authStorageKey)
            )
        )
    }

    private func makeGeneration(id generationID: SupabaseClientGenerationID) -> SupabaseClientGeneration {
        let storage = GenerationBoundAuthLocalStorage(
            generationID: generationID,
            backend: storageBackend,
            authority: authority
        )
        return SupabaseClientGeneration(
            id: generationID,
            client: clientFactory(configuration, storage),
            authStorage: storage,
            authority: authority
        )
    }
}
