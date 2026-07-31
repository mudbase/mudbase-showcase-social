using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Services;

namespace MudbaseShowcase.Social.Pages.Users;

/// <summary>Profile page: resolved display name, follower/following/post counts, that user's posts, follow/unfollow. Mirrors web/src/app/users/[userId]/page.tsx.</summary>
public sealed class DetailModel : PageModel
{
    private const int PageSize = 10;

    private readonly ProfileService _profile;
    private readonly PostsService _posts;
    private readonly FollowsService _follows;
    private readonly LikesService _likes;
    private readonly MudbaseSessionAccessor _session;

    public DetailModel(ProfileService profile, PostsService posts, FollowsService follows, LikesService likes, MudbaseSessionAccessor session)
    {
        _profile = profile;
        _posts = posts;
        _follows = follows;
        _likes = likes;
        _session = session;
    }

    public string UserId { get; private set; } = string.Empty;

    public string DisplayName { get; private set; } = "Member";

    public int FollowerCount { get; private set; }

    public int FollowingCount { get; private set; }

    public int PostCount { get; private set; }

    public bool Following { get; private set; }

    public bool IsOwnProfile { get; private set; }

    public bool IsSignedIn { get; private set; }

    public int CurrentPage { get; private set; } = 1;

    public bool HasMore { get; private set; }

    public IReadOnlyList<PostCardViewModel> Posts { get; private set; } = Array.Empty<PostCardViewModel>();

    public string? LoadError { get; private set; }

    // NOTE: "pg", not "page" - see Index.cshtml.cs's OnGetAsync doc comment. Razor Pages reserves
    // the route-value key "page" internally for ambient self-redirects; reusing it here corrupts
    // RedirectToPage's page-name resolution (verified live during this build's smoke test).
    public async Task OnGetAsync(string userId, int? pg, CancellationToken cancellationToken)
    {
        CurrentPage = pg is > 0 ? pg.Value : 1;
        await LoadAsync(userId, cancellationToken);
    }

    public async Task<IActionResult> OnPostToggleFollowAsync(string userId, string targetUserName, int pg, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = $"/Users/Detail/{userId}" });
        }

        if (user.Id != userId)
        {
            await _follows.ToggleAsync(user.Id, userId, targetUserName, cancellationToken);
        }

        return RedirectToPage(new { userId, pg });
    }

    /// <summary>
    /// Handles a like toggle on one of this profile's own posts — the `_PostCard` partial reused
    /// here (see Pages/Shared/_PostCard.cshtml) posts to whichever page rendered it, so this page
    /// needs its own copy of the same handler Index.cshtml.cs defines.
    /// </summary>
    public async Task<IActionResult> OnPostToggleLikeAsync(string userId, string postId, int pg, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = $"/Users/Detail/{userId}" });
        }

        PostDocument? post = await _posts.GetAsync(postId, cancellationToken);
        if (post is not null)
        {
            await _likes.ToggleAsync(post, user.Id, cancellationToken);
        }

        return RedirectToPage(new { userId, pg });
    }

    private async Task LoadAsync(string userId, CancellationToken cancellationToken)
    {
        UserId = userId;
        MudbaseSessionUser? user = _session.CurrentUser;
        IsSignedIn = user is { IsSignedIn: true };
        IsOwnProfile = IsSignedIn && user!.Id == userId;

        try
        {
            DisplayName = await _profile.ResolveDisplayNameAsync(userId, cancellationToken);
            FollowerCount = await _follows.GetFollowerCountAsync(userId, cancellationToken);
            FollowingCount = await _follows.GetFollowingCountAsync(userId, cancellationToken);
            PostCount = await _profile.GetPostCountAsync(userId, cancellationToken);

            if (IsSignedIn && !IsOwnProfile)
            {
                HashSet<string> followingIds = await _follows.ListMyFollowingIdsAsync(user!.Id, cancellationToken);
                Following = followingIds.Contains(userId);
            }

            MudbaseListResult<PostDocument> result = await _posts.ListByAuthorAsync(userId, CurrentPage, PageSize, cancellationToken);
            HasMore = CurrentPage < result.TotalPages;

            HashSet<string> likedPostIds = IsSignedIn
                ? await _likes.ListMyLikedPostIdsAsync(user!.Id, cancellationToken)
                : new HashSet<string>();

            // Every post on this page is authored by `userId` (the profile being viewed), so the
            // follow/own-post state is identical for every card — no per-post lookup needed here.
            Posts = result.Items.Select(post => new PostCardViewModel
            {
                Post = post,
                Liked = likedPostIds.Contains(post.Id),
                FollowingAuthor = Following,
                LinkToDetail = true,
                IsSignedIn = IsSignedIn,
                IsOwnPost = IsOwnProfile,
                ReturnPage = CurrentPage,
            }).ToList();
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load this profile right now. (" + ex.Message + ")";
        }
    }
}
