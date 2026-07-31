import Foundation
import PhotosUI
import SwiftUI

/// Mirrors `../web/src/components/feed/PostComposer.tsx`. Handles both the real `PhotosPicker`
/// upload attempt and its documented fallback — see `ImageUploadService` and
/// `plan/build-plan.md` "Deviations from the ecommerce Swift port" item 5.
@MainActor
final class PostComposerViewModel: ObservableObject {
    static let maxContentLength = 500

    @Published var content = ""
    @Published var imageUrl = ""
    @Published var selectedPhotoItem: PhotosPickerItem? {
        didSet {
            guard selectedPhotoItem != oldValue else { return }
            // Cancel any in-flight read/upload for a previously-picked photo before starting a
            // new one — without this, picking photo A then quickly picking photo B before A's
            // async work finishes runs both concurrently against the same `@Published` state
            // (`pickedImageData`, `imageUrl`, `errorMessage`), and whichever finishes last "wins"
            // regardless of which photo is actually still selected. `handlePhotoSelection` also
            // re-checks `item == selectedPhotoItem` before writing any result, since `Task.cancel()`
            // is cooperative and `loadTransferable` doesn't necessarily observe it mid-flight.
            photoSelectionTask?.cancel()
            let capturedItem = selectedPhotoItem
            photoSelectionTask = Task { await handlePhotoSelection(for: capturedItem) }
        }
    }
    @Published private(set) var isUploadingImage = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    @Published private(set) var pickedImageData: Data?

    private let postsService: PostsService
    private let imageUploadService: ImageUploadService
    private var onPosted: ((Post) -> Void)?
    private var photoSelectionTask: Task<Void, Never>?

    init(config: AppConfig, onPosted: ((Post) -> Void)? = nil) {
        postsService = PostsService(config: config)
        imageUploadService = ImageUploadService(config: config)
        self.onPosted = onPosted
    }

    var canSubmit: Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isSubmitting && !trimmed.isEmpty && trimmed.count <= Self.maxContentLength
    }

    /// `item` is the value `selectedPhotoItem` had at the moment this task was started —
    /// captured explicitly rather than read fresh from `self` at each step, so a later selection
    /// change (which starts its own task) can never have this stale task overwrite its results.
    /// Every write to `@Published` state below is guarded by `item == selectedPhotoItem`.
    private func handlePhotoSelection(for item: PhotosPickerItem?) async {
        guard let item else {
            pickedImageData = nil
            return
        }
        errorMessage = nil
        infoMessage = nil
        isUploadingImage = true
        defer {
            if item == selectedPhotoItem { isUploadingImage = false }
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                if item == selectedPhotoItem {
                    errorMessage = ImageUploadService.UploadError.couldNotReadImageData.errorDescription
                }
                return
            }
            guard !Task.isCancelled, item == selectedPhotoItem else { return }
            pickedImageData = data
            let uploadedURL = try await imageUploadService.upload(imageData: data)
            guard !Task.isCancelled, item == selectedPhotoItem else { return }
            imageUrl = uploadedURL
            infoMessage = "Photo attached."
        } catch {
            guard item == selectedPhotoItem else { return }
            // A real, expected outcome on this project (see the doc comment on this type) — the
            // manual "Image URL" field below stays available so the post can still carry an
            // image.
            let baseMessage = MudbaseAPIError.map(error)
            if baseMessage.statusCode == 403 {
                errorMessage = "Uploading photos isn't available for this account — paste an image URL below instead."
            } else if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = "\(description) You can paste an image URL below instead."
            } else {
                errorMessage = "\(baseMessage.message) You can paste an image URL below instead."
            }
        }
    }

    func clearPickedPhoto() {
        selectedPhotoItem = nil
        pickedImageData = nil
    }

    @discardableResult
    func submit(currentUser: AppUser) async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedImageUrl = imageUrl.trimmingCharacters(in: .whitespaces)
            let created = try await postsService.create(
                content: trimmedContent,
                imageUrl: trimmedImageUrl.isEmpty ? nil : trimmedImageUrl,
                authorId: currentUser.id,
                authorName: currentUser.displayName
            )
            onPosted?(created)
            content = ""
            imageUrl = ""
            selectedPhotoItem = nil
            pickedImageData = nil
            infoMessage = nil
            return true
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
            return false
        }
    }
}
