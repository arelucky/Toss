import Supabase

final class AppEnvironment {
    static let authStorageKey = "com.zhaoheng.Toss.supabase.auth.session"

    let supabaseClient: SupabaseClient
    let authStorage: KeychainAuthLocalStorage

    init(configuration: SupabaseConfiguration) {
        let authStorage = KeychainAuthLocalStorage()
        self.authStorage = authStorage
        supabaseClient = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: authStorage,
                    storageKey: Self.authStorageKey
                )
            )
        )
    }
}
