using Microsoft.Extensions.Options;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Options;

namespace MudbaseShowcase.Social.Services;

/// <summary>Post feed/detail/authoring logic, direct port of web/src/hooks/usePostsFeed.ts's server calls (minus the client-side cache bookkeeping, which a server-rendered page doesn't need).</summary>
public sealed class PostsService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public PostsService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    /// <summary>Newest-first, paginated — mirrors usePostsFeed's `sort: "-createdAt"`.</summary>
    public Task<MudbaseListResult<PostDocument>> ListFeedAsync(int page, int limit, CancellationToken cancellationToken) =>
        _data.ListAsync<PostDocument>(_options.PostsCollectionId, sort: "-createdAt", page: page, limit: limit, cancellationToken: cancellationToken);

    public Task<PostDocument?> GetAsync(string postId, CancellationToken cancellationToken) =>
        _data.GetAsync<PostDocument>(_options.PostsCollectionId, postId, cancellationToken);

    /// <summary>A given author's posts, newest first — used by both the profile page's post list and its post-count header stat.</summary>
    public Task<MudbaseListResult<PostDocument>> ListByAuthorAsync(string authorId, int page, int limit, CancellationToken cancellationToken) =>
        _data.ListAsync<PostDocument>(
            _options.PostsCollectionId,
            new Dictionary<string, object?> { ["authorId"] = authorId },
            sort: "-createdAt", page: page, limit: limit, cancellationToken: cancellationToken);

    public async Task<PostDocument> CreateAsync(string authorId, string authorName, string content, string? imageUrl, CancellationToken cancellationToken)
    {
        var data = new Dictionary<string, object?>
        {
            ["authorId"] = authorId,
            ["authorName"] = authorName,
            ["content"] = content,
            ["likesCount"] = 0,
            ["commentsCount"] = 0,
        };
        if (!string.IsNullOrWhiteSpace(imageUrl))
        {
            data["imageUrl"] = imageUrl;
        }

        return await _data.CreateAsync<PostDocument>(_options.PostsCollectionId, data, cancellationToken);
    }

    public Task<PostDocument> UpdateLikesCountAsync(string postId, int likesCount, CancellationToken cancellationToken) =>
        _data.UpdateAsync<PostDocument>(_options.PostsCollectionId, postId, new Dictionary<string, object?> { ["likesCount"] = likesCount }, cancellationToken);

    public Task<PostDocument> UpdateCommentsCountAsync(string postId, int commentsCount, CancellationToken cancellationToken) =>
        _data.UpdateAsync<PostDocument>(_options.PostsCollectionId, postId, new Dictionary<string, object?> { ["commentsCount"] = commentsCount }, cancellationToken);
}
