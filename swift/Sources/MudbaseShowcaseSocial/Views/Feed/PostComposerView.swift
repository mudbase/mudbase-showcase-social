import PhotosUI
import SwiftUI

/// Mirrors `../web/src/components/feed/PostComposer.tsx`, plus the real `PhotosPicker` attempt —
/// see `PostComposerViewModel` and `plan/build-plan.md` "Deviations from the ecommerce Swift port"
/// item 5.
struct PostComposerView: View {
    @StateObject private var viewModel: PostComposerViewModel
    let currentUser: AppUser

    init(config: AppConfig, currentUser: AppUser, onPosted: ((Post) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: PostComposerViewModel(config: config, onPosted: onPosted))
        self.currentUser = currentUser
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage = viewModel.errorMessage {
                InlineBanner(message: errorMessage)
            } else if let infoMessage = viewModel.infoMessage {
                InlineBanner(message: infoMessage, style: .info)
            }

            ZStack(alignment: .topLeading) {
                if viewModel.content.isEmpty {
                    Text("What's on your mind?")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $viewModel.content)
                    .frame(minHeight: 70, maxHeight: 130)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Text("\(viewModel.content.count)/\(PostComposerViewModel.maxContentLength)")
                    .font(.caption)
                    .foregroundStyle(viewModel.content.count > PostComposerViewModel.maxContentLength ? .red : .secondary)
            }

            if let pickedImageData = viewModel.pickedImageData, let platformImage = PlatformImage(data: pickedImageData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            viewModel.clearPickedPhoto()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding(6)
                    }
            }

            HStack(spacing: 12) {
                // The label text is precomputed into a plain `String` before the `PhotosPicker`
                // call — its label builder closure is `@Sendable` in this SDK, and a `String`
                // capture is Sendable where a direct read of the (main-actor-isolated)
                // `viewModel` property inside that closure is not.
                let photoButtonTitle = viewModel.isUploadingImage ? "Uploading…" : "Add Photo"
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    Label(photoButtonTitle, systemImage: "photo")
                        .font(.footnote.weight(.medium))
                }
                .disabled(viewModel.isUploadingImage)
                Spacer()
            }

            TextField("Image URL (optional)", text: $viewModel.imageUrl)
                .textFieldStyle(.roundedBorder)
                .urlKeyboard()
                .autocorrectionDisabled()

            HStack {
                Spacer()
                Button {
                    Task { await viewModel.submit(currentUser: currentUser) }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Post")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.secondary.opacity(0.15)))
    }
}
