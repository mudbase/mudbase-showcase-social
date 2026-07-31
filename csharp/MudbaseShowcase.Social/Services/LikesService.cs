using Microsoft.Extensions.Options;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Options;

namespace MudbaseShowcase.Social.Services;

/// <summary>Like toggle logic, direct port of web/src/hooks/useLikes.ts.</summary>
public sealed class LikesService
{
    private readonly MudbaseDataService _data;
    private readonly PostsService _posts;
    private readonly MudbaseOptions _options;

    public LikesService(MudbaseDataService data, PostsService posts, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _posts = posts;
        _options = options.Value;
    }

    /// <summary>
    /// The signed-in user's own liked-post ids, fetched once per page render and reused for every
    /// post card rendered on that page — avoids one query per post, same rationale as
    /// useMyLikedPostIds. Demo-scale cap (500), same as the web app's MINE_LIMIT: this app has no
    /// pagination UI for "posts I've liked", so one bounded page covers every like a real account
    /// will create during a demo/smoke test.
    /// </summary>
    public async Task<HashSet<string>> ListMyLikedPostIdsAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<LikeDocument> result = await _data.ListAsync<LikeDocument>(
            _options.LikesCollectionId, new Dictionary<string, object?> { ["userId"] = userId }, limit: 500, cancellationToken: cancellationToken);
        return result.Items.Select(l => l.PostId).ToHashSet();
    }

    /// <summary>
    /// Check-then-act against the server (not just a local cache) right before mutating —
    /// reasonable protection against a double-click/double-submit race creating two like rows for
    /// the same (postId, userId), since this collection type has no compound unique index. Returns
    /// the new liked state and the post's updated likesCount.
    /// </summary>
    public async Task<(bool Liked, int LikesCount)> ToggleAsync(PostDocument post, string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<LikeDocument> existing = await _data.ListAsync<LikeDocument>(
            _options.LikesCollectionId,
            new Dictionary<string, object?> { ["postId"] = post.Id, ["userId"] = userId },
            limit: 1, cancellationToken: cancellationToken);
        LikeDocument? existingLike = existing.Items.FirstOrDefault();

        if (existingLike is not null)
        {
            await _data.DeleteAsync(_options.LikesCollectionId, existingLike.Id, cancellationToken);
            int likesCount = Math.Max(0, post.LikesCount - 1);
            await _posts.UpdateLikesCountAsync(post.Id, likesCount, cancellationToken);
            return (false, likesCount);
        }

        await _data.CreateAsync<LikeDocument>(_options.LikesCollectionId, new Dictionary<string, object?>
        {
            ["postId"] = post.Id,
            ["userId"] = userId,
        }, cancellationToken);
        int newLikesCount = post.LikesCount + 1;
        await _posts.UpdateLikesCountAsync(post.Id, newLikesCount, cancellationToken);
        return (true, newLikesCount);
    }
}
