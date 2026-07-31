namespace MudbaseShowcase.Social.Options;

/// <summary>
/// Every config value this app needs to talk to a provisioned Mudbase project. Bound from the
/// "Mudbase" section of appsettings.json / environment variables — see appsettings.Example.json
/// at the repo root for the full list with descriptions.
/// </summary>
public sealed class MudbaseOptions
{
    public const string SectionName = "Mudbase";

    /// <summary>Mudbase API base URL. Defaults to the public cloud endpoint.</summary>
    public string BaseUrl { get; set; } = "https://cloud.mudbase.dev";

    /// <summary>The Mudbase project ID this app is provisioned against.</summary>
    public string ProjectId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "posts" collection.</summary>
    public string PostsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "comments" collection.</summary>
    public string CommentsCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "likes" collection.</summary>
    public string LikesCollectionId { get; set; } = string.Empty;

    /// <summary>Collection ID for the "follows" collection.</summary>
    public string FollowsCollectionId { get; set; } = string.Empty;

    /// <summary>
    /// Throws with a clear, specific message if any required value was left unset, so a
    /// misconfigured deployment fails at startup instead of surfacing confusing errors deep
    /// inside a request handler.
    /// </summary>
    public void Validate()
    {
        var missing = new List<string>();

        if (string.IsNullOrWhiteSpace(BaseUrl)) missing.Add(nameof(BaseUrl));
        if (string.IsNullOrWhiteSpace(ProjectId)) missing.Add(nameof(ProjectId));
        if (string.IsNullOrWhiteSpace(PostsCollectionId)) missing.Add(nameof(PostsCollectionId));
        if (string.IsNullOrWhiteSpace(CommentsCollectionId)) missing.Add(nameof(CommentsCollectionId));
        if (string.IsNullOrWhiteSpace(LikesCollectionId)) missing.Add(nameof(LikesCollectionId));
        if (string.IsNullOrWhiteSpace(FollowsCollectionId)) missing.Add(nameof(FollowsCollectionId));

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                $"Missing required Mudbase configuration values: {string.Join(", ", missing)}. " +
                "Set them under the \"Mudbase\" section of appsettings.json, appsettings.Development.json, " +
                "or the corresponding Mudbase__<Key> environment variables. See appsettings.Example.json.");
        }
    }
}
