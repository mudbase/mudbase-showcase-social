namespace MudbaseShowcase.Social.Models;

/// <summary>
/// Everything the `_PostCard` partial needs to render one post, on both the feed and the post
/// detail page — mirrors the props of web/src/components/feed/PostCard.tsx (`post`, `liked`,
/// `followingAuthor`, `linkToDetail`), plus the auth-gating flags a server-rendered form needs
/// that the client-side version reads from a hook instead (`IsSignedIn`, `IsOwnPost`).
/// </summary>
public sealed class PostCardViewModel
{
    public required PostDocument Post { get; init; }
    public required bool Liked { get; init; }
    public required bool FollowingAuthor { get; init; }
    public bool LinkToDetail { get; init; } = true;
    public required bool IsSignedIn { get; init; }
    public required bool IsOwnPost { get; init; }

    /// <summary>Preserved across a like/follow toggle POST so the redirect lands back on the same feed page.</summary>
    public int ReturnPage { get; init; } = 1;
}
