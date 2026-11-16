import Foundation

/// Supabase settings, read from Info.plist. The values come from
/// Config/Config.local.xcconfig at build time and are never committed.
struct AppConfig {
    let supabaseURL: URL
    let supabaseKey: String

    /// Nil when Config.local.xcconfig is missing or still has placeholder values.
    static func load(from bundle: Bundle = .main) -> AppConfig? {
        guard
            let host = bundle.object(forInfoDictionaryKey: "SupabaseHost") as? String,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !host.isEmpty, !key.isEmpty,
            !host.hasPrefix("your-"), !key.hasPrefix("your-"),
            let url = URL(string: "https://\(host)")
        else { return nil }
        return AppConfig(supabaseURL: url, supabaseKey: key)
    }
}
