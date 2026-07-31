using System.Text.Json.Serialization;

namespace MudbaseShowcase.Social.Models;

/// <summary>
/// Maps a document from the "posts" Mudbase collection. Field names mirror the reference Next.js
/// implementation's `posts` schema exactly (see web/src/types/post.ts) so this is a faithful port,
/// not a reinterpretation.
/// </summary>
public sealed class PostDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("authorId")]
    public string AuthorId { get; set; } = string.Empty;

    [JsonPropertyName("authorName")]
    public string AuthorName { get; set; } = string.Empty;

    [JsonPropertyName("content")]
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// A pasted image URL, not an uploaded file — see README "Known limitations" for why (file
    /// upload requires an org-level system role no project end-user ever carries).
    /// </summary>
    [JsonPropertyName("imageUrl")]
    public string? ImageUrl { get; set; }

    [JsonPropertyName("likesCount")]
    public int LikesCount { get; set; }

    [JsonPropertyName("commentsCount")]
    public int CommentsCount { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}
