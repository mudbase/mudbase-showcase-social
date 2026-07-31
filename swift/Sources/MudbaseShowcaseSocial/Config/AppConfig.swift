import Foundation
import SwiftUI

/// Reads deployment configuration from `Config.plist` in the app bundle (copy it from
/// `Config.example.plist` at the repo root and add it as a resource in your Xcode run target —
/// see README "Configuration"). Deliberately NOT declared as an SPM `resources:` entry: that would
/// make `swift build` fail whenever `Config.plist` hasn't been created yet, and this repo's own
/// verification step (`swift build`) must succeed out of the box with no local secrets present.
/// The cost is that config is only checked at runtime, not at compile time — `AppConfig` surfaces
/// that as a typed, recoverable state (`ConfigurationState`) rather than crashing, so the app can
/// show a real "Configuration Required" screen instead of dying at launch. Ported verbatim from
/// `../../mudbase-showcase-ecommerce/swift/Sources/.../Config/AppConfig.swift`, with this app's
/// own four collection IDs in place of that app's three.
struct AppConfig: Sendable, Equatable {
    let projectId: String
    let baseURL: URL
    let postsCollectionId: String
    let commentsCollectionId: String
    let likesCollectionId: String
    let followsCollectionId: String

    private static let defaultBaseURLString = "https://cloud.mudbase.dev"

    /// Loads from `Config.plist` in the main bundle first, then falls back to process environment
    /// variables (handy for `swift run` / scheme-level env vars during development).
    static func load(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) -> Result<AppConfig, ConfigurationError> {
        let plistValues = readPlist(bundle: bundle)

        func value(_ plistKey: String, envKey: String) -> String? {
            let fromPlist = plistValues[plistKey]
            if let fromPlist, !fromPlist.isEmpty { return fromPlist }
            let fromEnv = environment[envKey]
            if let fromEnv, !fromEnv.isEmpty { return fromEnv }
            return nil
        }

        guard let projectId = value("MudbaseProjectId", envKey: "MUDBASE_PROJECT_ID") else {
            return .failure(.missingKey("MudbaseProjectId"))
        }
        guard let postsCollectionId = value("PostsCollectionId", envKey: "MUDBASE_POSTS_COLLECTION_ID") else {
            return .failure(.missingKey("PostsCollectionId"))
        }
        guard let commentsCollectionId = value("CommentsCollectionId", envKey: "MUDBASE_COMMENTS_COLLECTION_ID") else {
            return .failure(.missingKey("CommentsCollectionId"))
        }
        guard let likesCollectionId = value("LikesCollectionId", envKey: "MUDBASE_LIKES_COLLECTION_ID") else {
            return .failure(.missingKey("LikesCollectionId"))
        }
        guard let followsCollectionId = value("FollowsCollectionId", envKey: "MUDBASE_FOLLOWS_COLLECTION_ID") else {
            return .failure(.missingKey("FollowsCollectionId"))
        }
        let baseURLString = value("MudbaseBaseURL", envKey: "MUDBASE_BASE_URL") ?? defaultBaseURLString

        guard let baseURL = URL(string: baseURLString) else {
            return .failure(.invalidURL("MudbaseBaseURL", baseURLString))
        }

        return .success(
            AppConfig(
                projectId: projectId,
                baseURL: baseURL,
                postsCollectionId: postsCollectionId,
                commentsCollectionId: commentsCollectionId,
                likesCollectionId: likesCollectionId,
                followsCollectionId: followsCollectionId
            )
        )
    }

    private static func readPlist(bundle: Bundle) -> [String: String] {
        guard let url = bundle.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let raw = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            return [:]
        }
        return raw.compactMapValues { $0 as? String }
    }
}

enum ConfigurationError: Error, Equatable, CustomStringConvertible {
    case missingKey(String)
    case invalidURL(String, String)

    var description: String {
        switch self {
        case .missingKey(let key):
            return "Missing required configuration key \"\(key)\". Copy Config.example.plist to Config.plist (it already has this showcase's real project/collection IDs filled in) and add it as a resource of your Xcode run target."
        case .invalidURL(let key, let value):
            return "Configuration key \"\(key)\" is not a valid URL: \"\(value)\"."
        }
    }
}

/// Lets any view reach the resolved `AppConfig` via `@Environment(\.appConfig)` without threading
/// it through every intermediate view's init.
private struct AppConfigKey: EnvironmentKey {
    static let defaultValue: AppConfig? = nil
}

extension EnvironmentValues {
    var appConfig: AppConfig? {
        get { self[AppConfigKey.self] }
        set { self[AppConfigKey.self] = newValue }
    }
}
