import Supabase

final class AppEnvironment {
    let supabaseClient: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        supabaseClient = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }
}
