import SwiftUI

/// Mirrors `../web/src/components/comments/CommentComposer.tsx`.
struct CommentComposerView: View {
    @ObservedObject var viewModel: PostDetailViewModel
    let isSignedIn: Bool
    let onRequiresSignIn: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(isSignedIn ? "Add a comment…" : "Sign in to comment", text: $viewModel.commentDraft, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .disabled(!isSignedIn)

            HStack {
                Spacer()
                Button {
                    if !isSignedIn {
                        onRequiresSignIn()
                    } else {
                        onSubmit()
                    }
                } label: {
                    if viewModel.isSubmittingComment {
                        ProgressView()
                    } else {
                        Text(isSignedIn ? "Comment" : "Sign in to comment")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isSubmittingComment || (isSignedIn && viewModel.commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
    }
}
