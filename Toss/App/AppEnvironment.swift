import Foundation
import Supabase

final class AppEnvironment {
    static let authStorageKey = "com.zhaoheng.Toss.supabase.auth.session"

    let authStorage: KeychainAuthLocalStorage
    let generationProvider: SupabaseClientGenerationProvider
    let supabaseBaseURL: URL

    var supabaseClient: SupabaseClient { generationProvider.current().client }

    init(configuration: SupabaseConfiguration) {
        let authStorage = KeychainAuthLocalStorage()
        self.authStorage = authStorage
        supabaseBaseURL = configuration.url
        generationProvider = SupabaseClientGenerationProvider(
            configuration: configuration,
            storageBackend: authStorage,
            storageKey: Self.authStorageKey
        )
    }
}
