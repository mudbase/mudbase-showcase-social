using System.Text.Json.Serialization;

namespace MudbaseShowcase.Social.Models;

/// <summary>
/// Maps a document from the "likes" Mudbase collection. Mirrors web/src/types/like.ts. One row per
/// (postId, userId) pair — this collection type has no compound unique index, so uniqueness is
/// enforced at the application layer (check-then-act, see Services/LikesService.cs).
/// </summary>
public sealed class LikeDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("postId")]
    public string PostId { get; set; } = string.Empty;

    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}
