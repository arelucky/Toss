import Foundation

enum SupabaseConfigurationError: Error, Equatable {
    case missingValue(String)
    case invalidURL
    case prohibitedKey
}

struct SupabaseConfiguration: Equatable {
    let url: URL
    let publishableKey: String

    static func load(from bundle: Bundle) throws -> Self {
        let urlValue = try requiredValue(for: "TossSupabaseURL", in: bundle)
        guard let url = URL(string: urlValue),
              ["http", "https"].contains(url.scheme?.lowercased()),
              url.host != nil else {
            throw SupabaseConfigurationError.invalidURL
        }

        let publishableKey = try requiredValue(
            for: "TossSupabasePublishableKey",
            in: bundle
        )
        guard !isProhibited(publishableKey) else {
            throw SupabaseConfigurationError.prohibitedKey
        }

        return Self(url: url, publishableKey: publishableKey)
    }

    private static func requiredValue(for key: String, in bundle: Bundle) throws -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            throw SupabaseConfigurationError.missingValue(key)
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            throw SupabaseConfigurationError.missingValue(key)
        }
        return trimmedValue
    }

    private static func isProhibited(_ key: String) -> Bool {
        if key.lowercased().hasPrefix("sb_secret_") {
            return true
        }

        let segments = key.split(separator: ".")
        guard segments.count == 3,
              let payload = decodedBase64URL(String(segments[1])),
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let role = object["role"] as? String else {
            return false
        }
        return role == "service_role"
    }

    private static func decodedBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padding))
        return Data(base64Encoded: base64)
    }
}
