using System.Text.Json.Serialization;

namespace MudbaseShowcase.Social.Models;

/// <summary>
/// Maps a document from the "follows" Mudbase collection. Mirrors web/src/types/follow.ts. Same
/// check-then-act uniqueness guard as likes (see Services/FollowsService.cs) — no compound unique
/// index exists on (followerId, followingId).
/// </summary>
public sealed class FollowDocument
{
    [JsonPropertyName("_id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("followerId")]
    public string FollowerId { get; set; } = string.Empty;

    [JsonPropertyName("followingId")]
    public string FollowingId { get; set; } = string.Empty;

    /// <summary>
    /// Denormalized display name of the followed user, recorded at follow time — this schema has
    /// no `users` collection, so this is one of the few places a display name for a user who has
    /// never posted can be recovered from. See Services/ProfileService.cs.
    /// </summary>
    [JsonPropertyName("followingName")]
    public string? FollowingName { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset UpdatedAt { get; set; }
}
