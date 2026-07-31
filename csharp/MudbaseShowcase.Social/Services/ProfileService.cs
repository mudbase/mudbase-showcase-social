using Microsoft.Extensions.Options;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Options;

namespace MudbaseShowcase.Social.Services;

/// <summary>
/// Profile display-name resolution and post-count lookup, direct port of
/// web/src/hooks/useProfileStats.ts's useResolvedDisplayName. There is no `users` collection in
/// this schema (see plan/build-plan.md "Known limitations"), so a display name for a given userId
/// is best-effort: their most recent post's authorName, else the followingName recorded by
/// anyone who follows them, else the literal fallback "Member".
/// </summary>
public sealed class ProfileService
{
    private readonly MudbaseDataService _data;
    private readonly PostsService _posts;
    private readonly MudbaseOptions _options;

    public ProfileService(MudbaseDataService data, PostsService posts, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _posts = posts;
        _options = options.Value;
    }

    public async Task<string> ResolveDisplayNameAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<PostDocument> posts = await _posts.ListByAuthorAsync(userId, page: 1, limit: 1, cancellationToken);
        string? fromPost = posts.Items.FirstOrDefault()?.AuthorName;
        if (!string.IsNullOrWhiteSpace(fromPost))
        {
            return fromPost;
        }

        MudbaseListResult<FollowDocument> follows = await _data.ListAsync<FollowDocument>(
            _options.FollowsCollectionId, new Dictionary<string, object?> { ["followingId"] = userId },
            limit: 20, cancellationToken: cancellationToken);
        string? fromFollow = follows.Items
            .Select(f => f.FollowingName)
            .FirstOrDefault(name => !string.IsNullOrWhiteSpace(name));
        if (!string.IsNullOrWhiteSpace(fromFollow))
        {
            return fromFollow;
        }

        return "Member";
    }

    public async Task<int> GetPostCountAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<PostDocument> result = await _posts.ListByAuthorAsync(userId, page: 1, limit: 1, cancellationToken);
        return result.Total;
    }
}
