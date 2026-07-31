using Microsoft.Extensions.Options;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Options;

namespace MudbaseShowcase.Social.Services;

/// <summary>Follow toggle + count logic, direct port of web/src/hooks/useFollows.ts and useFollowCounts (web/src/hooks/useProfileStats.ts).</summary>
public sealed class FollowsService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public FollowsService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    /// <summary>The signed-in user's own "who am I following" ids — same demo-scale cap rationale as LikesService.ListMyLikedPostIdsAsync.</summary>
    public async Task<HashSet<string>> ListMyFollowingIdsAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<FollowDocument> result = await _data.ListAsync<FollowDocument>(
            _options.FollowsCollectionId, new Dictionary<string, object?> { ["followerId"] = userId }, limit: 500, cancellationToken: cancellationToken);
        return result.Items.Select(f => f.FollowingId).ToHashSet();
    }

    /// <summary>Counts are read via `pagination.total` on a limit:1 query rather than pulling every row — cheap, and correct regardless of how many follow rows exist.</summary>
    public async Task<int> GetFollowerCountAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<FollowDocument> result = await _data.ListAsync<FollowDocument>(
            _options.FollowsCollectionId, new Dictionary<string, object?> { ["followingId"] = userId }, limit: 1, cancellationToken: cancellationToken);
        return result.Total;
    }

    public async Task<int> GetFollowingCountAsync(string userId, CancellationToken cancellationToken)
    {
        MudbaseListResult<FollowDocument> result = await _data.ListAsync<FollowDocument>(
            _options.FollowsCollectionId, new Dictionary<string, object?> { ["followerId"] = userId }, limit: 1, cancellationToken: cancellationToken);
        return result.Total;
    }

    /// <summary>Check-then-act against the server, same race-guard rationale as LikesService.ToggleAsync. Returns the new following state.</summary>
    public async Task<bool> ToggleAsync(string currentUserId, string targetUserId, string targetUserName, CancellationToken cancellationToken)
    {
        if (currentUserId == targetUserId)
        {
            throw new InvalidOperationException("Cannot follow yourself");
        }

        MudbaseListResult<FollowDocument> existing = await _data.ListAsync<FollowDocument>(
            _options.FollowsCollectionId,
            new Dictionary<string, object?> { ["followerId"] = currentUserId, ["followingId"] = targetUserId },
            limit: 1, cancellationToken: cancellationToken);
        FollowDocument? existingFollow = existing.Items.FirstOrDefault();

        if (existingFollow is not null)
        {
            await _data.DeleteAsync(_options.FollowsCollectionId, existingFollow.Id, cancellationToken);
            return false;
        }

        await _data.CreateAsync<FollowDocument>(_options.FollowsCollectionId, new Dictionary<string, object?>
        {
            ["followerId"] = currentUserId,
            ["followingId"] = targetUserId,
            ["followingName"] = targetUserName,
        }, cancellationToken);
        return true;
    }
}
