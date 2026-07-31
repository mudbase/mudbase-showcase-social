using Microsoft.Extensions.Options;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Options;

namespace MudbaseShowcase.Social.Services;

/// <summary>Comment thread logic, direct port of web/src/hooks/useComments.ts.</summary>
public sealed class CommentsService
{
    private readonly MudbaseDataService _data;
    private readonly PostsService _posts;
    private readonly MudbaseOptions _options;

    public CommentsService(MudbaseDataService data, PostsService posts, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _posts = posts;
        _options = options.Value;
    }

    /// <summary>Oldest first, like a normal comment thread — newest replies land at the bottom.</summary>
    public Task<MudbaseListResult<CommentDocument>> ListForPostAsync(string postId, CancellationToken cancellationToken) =>
        _data.ListAsync<CommentDocument>(
            _options.CommentsCollectionId,
            new Dictionary<string, object?> { ["postId"] = postId },
            sort: "createdAt", limit: 200, cancellationToken: cancellationToken);

    /// <summary>
    /// Creates the comment, then re-reads the post immediately before incrementing
    /// `commentsCount` — same check-then-act guard as the web app's useCreateComment, so a burst
    /// of concurrent comments doesn't have both writers increment from the same stale count.
    /// </summary>
    public async Task<CommentDocument> CreateAsync(string postId, string authorId, string authorName, string content, CancellationToken cancellationToken)
    {
        CommentDocument created = await _data.CreateAsync<CommentDocument>(_options.CommentsCollectionId, new Dictionary<string, object?>
        {
            ["postId"] = postId,
            ["authorId"] = authorId,
            ["authorName"] = authorName,
            ["content"] = content,
        }, cancellationToken);

        PostDocument? currentPost = await _posts.GetAsync(postId, cancellationToken);
        if (currentPost is not null)
        {
            await _posts.UpdateCommentsCountAsync(postId, currentPost.CommentsCount + 1, cancellationToken);
        }

        return created;
    }
}
