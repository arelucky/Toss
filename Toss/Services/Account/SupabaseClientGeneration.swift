import Supabase

final class SupabaseClientGeneration {
    let id: SupabaseClientGenerationID
    let client: SupabaseClient
    let authStorage: GenerationBoundAuthLocalStorage
    private let authority: SupabaseClientGenerationAuthority

    init(
        id: SupabaseClientGenerationID,
        client: SupabaseClient,
        authStorage: GenerationBoundAuthLocalStorage,
        authority: SupabaseClientGenerationAuthority
    ) {
        self.id = id
        self.client = client
        self.authStorage = authStorage
        self.authority = authority
    }

    var lifecycle: SupabaseClientGenerationLifecycle? {
        authority.lifecycle(of: id)
    }
}
