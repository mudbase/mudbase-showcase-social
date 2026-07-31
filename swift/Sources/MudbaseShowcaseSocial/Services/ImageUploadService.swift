import Foundation
import MudbaseSDK

/// Uploads a `PhotosPicker`-selected image to this project's public bucket. See
/// `plan/build-plan.md` "Deviations from the ecommerce Swift port" item 5: bucket/file creation is
/// gated by `rbacCheck("file","create")`, which only allows the org-level system roles
/// owner/admin/developer — every project end-user (including a real, verified `customer`) is
/// permanently system role `viewer`. Both the web app and the ecommerce Swift port confirmed this
/// 403s live and skip straight to a plain URL text field; this app's task brief explicitly asks
/// for `PhotosPicker`, so this makes the real attempt (discovering this project's public bucket
/// via `BucketsAPI.listBuckets` rather than hardcoding an ID that could be recreated) and lets the
/// caller (`PostComposerViewModel`) fall back to the same manual URL field on failure.
struct ImageUploadService {
    let projectId: String

    init(config: AppConfig) {
        projectId = config.projectId
    }

    enum UploadError: Error, LocalizedError {
        case noBucketAvailable
        case noURLInUploadResponse
        case couldNotReadImageData

        var errorDescription: String? {
            switch self {
            case .noBucketAvailable: return "No storage bucket is configured for this project."
            case .noURLInUploadResponse: return "Upload succeeded but no file URL was returned."
            case .couldNotReadImageData: return "Couldn't read the selected photo."
            }
        }
    }

    /// Writes `imageData` to a scratch temp file (the generated SDK's `uploadFiles` takes local
    /// file `[URL]`s for its multipart body, not raw `Data`) and uploads it. Routed through
    /// `AccessTokenCoordinator` like every other authenticated call in the app, so an access token
    /// that expired mid-session still transparently refreshes and retries once here too.
    func upload(imageData: Data) async throws -> String {
        let bucketId = try await resolvePublicBucketId()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try imageData.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let projectId = self.projectId
        let response = try await AccessTokenCoordinator.shared.perform { () async throws(ErrorResponse) in
            try await FilesAPI.uploadFiles(projectId: projectId, bucketId: bucketId, files: [tempURL])
        }
        guard let url = response.file?.publicUrl ?? response.file?.url else {
            throw UploadError.noURLInUploadResponse
        }
        return url
    }

    private func resolvePublicBucketId() async throws -> String {
        if let cached = await PublicBucketCache.shared.get(projectId: projectId) { return cached }
        let projectId = self.projectId
        let list = try await AccessTokenCoordinator.shared.perform { () async throws(ErrorResponse) in
            try await BucketsAPI.listBuckets(projectId: projectId, limit: 50)
        }
        let buckets = list.buckets ?? []
        guard let bucket = buckets.first(where: { $0.isPublic == true }) ?? buckets.first, let id = bucket.id else {
            throw UploadError.noBucketAvailable
        }
        await PublicBucketCache.shared.set(id, projectId: projectId)
        return id
    }
}

/// Caches the resolved public bucket ID per project — the bucket ID doesn't change during a
/// session, and this avoids one extra round trip per upload attempt after the first. An `actor`
/// (not a plain `static var`, which the original version of this file used) because two
/// overlapping `upload()` calls can legitimately race here: `PostComposerViewModel` cancels a
/// stale photo-selection task on a new pick, but cancellation is cooperative, so two uploads can
/// briefly run concurrently and both read-then-write an unsynchronized static at the same time.
private actor PublicBucketCache {
    static let shared = PublicBucketCache()

    private var idsByProject: [String: String] = [:]

    private init() {}

    func get(projectId: String) -> String? { idsByProject[projectId] }
    func set(_ bucketId: String, projectId: String) { idsByProject[projectId] = bucketId }
}
