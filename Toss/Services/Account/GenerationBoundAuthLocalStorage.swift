import Foundation
import Supabase

struct SupabaseClientGenerationID: Hashable, Sendable {
    private let value: UUID

    init() {
        value = UUID()
    }

    static let legacy = Self(
        value: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    )

    private init(value: UUID) {
        self.value = value
    }
}

enum SupabaseClientGenerationLifecycle: Equatable, Sendable {
    case active
    case retiring
    case retired
}

enum SupabaseClientGenerationError: Error, Equatable {
    case activeGenerationExists
    case generationNotActive
    case generationNotWritable
    case generationCannotRemove
    case retiredGeneration
    case replacementInProgress
}

final class SupabaseClientGenerationAuthority: @unchecked Sendable {
    private let lock = NSLock()
    private var lifecycles: [SupabaseClientGenerationID: SupabaseClientGenerationLifecycle] = [:]
    private var activeGenerationID: SupabaseClientGenerationID?

    init(initialActiveGenerationID: SupabaseClientGenerationID? = nil) {
        activeGenerationID = initialActiveGenerationID
        if let initialActiveGenerationID {
            lifecycles[initialActiveGenerationID] = .active
        }
    }

    func activate(_ generationID: SupabaseClientGenerationID) throws {
        try lock.withLock {
            if lifecycles[generationID] == .retired {
                throw SupabaseClientGenerationError.retiredGeneration
            }
            guard activeGenerationID == nil else {
                throw SupabaseClientGenerationError.activeGenerationExists
            }
            lifecycles[generationID] = .active
            activeGenerationID = generationID
        }
    }

    func beginRetirement(of generationID: SupabaseClientGenerationID) throws {
        try lock.withLock {
            guard activeGenerationID == generationID,
                  lifecycles[generationID] == .active else {
                throw SupabaseClientGenerationError.generationNotActive
            }
            lifecycles[generationID] = .retiring
            activeGenerationID = nil
        }
    }

    func finishRetirement(of generationID: SupabaseClientGenerationID) throws {
        try lock.withLock {
            guard lifecycles[generationID] == .retiring else {
                throw SupabaseClientGenerationError.generationNotActive
            }
            lifecycles[generationID] = .retired
        }
    }

    func lifecycle(of generationID: SupabaseClientGenerationID) -> SupabaseClientGenerationLifecycle? {
        lock.withLock { lifecycles[generationID] }
    }

    var writableGenerationCount: Int {
        lock.withLock { lifecycles.values.filter { $0 == .active }.count }
    }

    fileprivate func store(
        generationID: SupabaseClientGenerationID,
        operation: () throws -> Void
    ) throws {
        try lock.withLock {
            guard activeGenerationID == generationID,
                  lifecycles[generationID] == .active else {
                throw SupabaseClientGenerationError.generationNotWritable
            }
            try operation()
        }
    }

    fileprivate func remove(
        generationID: SupabaseClientGenerationID,
        operation: () throws -> Void
    ) throws {
        try lock.withLock {
            guard lifecycles[generationID] == .active || lifecycles[generationID] == .retiring else {
                throw SupabaseClientGenerationError.generationCannotRemove
            }
            try operation()
        }
    }

    fileprivate func retrieve<Value>(
        generationID: SupabaseClientGenerationID,
        operation: () throws -> Value
    ) throws -> Value {
        try lock.withLock {
            guard lifecycles[generationID] == .active || lifecycles[generationID] == .retiring else {
                throw SupabaseClientGenerationError.retiredGeneration
            }
            return try operation()
        }
    }
}

final class GenerationBoundAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    let generationID: SupabaseClientGenerationID
    private let backend: any AuthLocalStorage
    private let authority: SupabaseClientGenerationAuthority

    init(
        generationID: SupabaseClientGenerationID,
        backend: any AuthLocalStorage,
        authority: SupabaseClientGenerationAuthority
    ) {
        self.generationID = generationID
        self.backend = backend
        self.authority = authority
    }

    func store(key: String, value: Data) throws {
        try authority.store(generationID: generationID) {
            try backend.store(key: key, value: value)
        }
    }

    func retrieve(key: String) throws -> Data? {
        try authority.retrieve(generationID: generationID) {
            try backend.retrieve(key: key)
        }
    }

    func remove(key: String) throws {
        try authority.remove(generationID: generationID) {
            try backend.remove(key: key)
        }
    }
}
