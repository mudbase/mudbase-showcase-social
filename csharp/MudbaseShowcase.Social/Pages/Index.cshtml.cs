using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Services;

namespace MudbaseShowcase.Social.Pages;

/// <summary>Feed: post composer + paginated post list. Mirrors web/src/app/page.tsx (PostComposer + FeedList).</summary>
public sealed class IndexModel : PageModel
{
    private const int PageSize = 10;

    private readonly PostsService _posts;
    private readonly LikesService _likes;
    private readonly FollowsService _follows;
    private readonly MudbaseSessionAccessor _session;

    public IndexModel(PostsService posts, LikesService likes, FollowsService follows, MudbaseSessionAccessor session)
    {
        _posts = posts;
        _likes = likes;
        _follows = follows;
        _session = session;
    }

    public IReadOnlyList<PostCardViewModel> Posts { get; private set; } = Array.Empty<PostCardViewModel>();

    public int CurrentPage { get; private set; } = 1;

    public bool HasMore { get; private set; }

    public bool IsSignedIn { get; private set; }

    public string? LoadError { get; private set; }

    [BindProperty]
    public ComposerInput Composer { get; set; } = new();

    [TempData]
    public string? ComposeError { get; set; }

    // NOTE: the query/route parameter is deliberately "pg", not "page" - Razor Pages reserves the
    // route-value key "page" internally (it stores the current page's own path for ambient
    // self-redirects like `RedirectToPage(new { ... })` with no explicit page name). Reusing "page"
    // for pagination silently corrupts that ambient value and makes RedirectToPage throw
    // "No page named '' matches the supplied values." - verified live during this build's smoke test.
    public async Task OnGetAsync(int? pg, CancellationToken cancellationToken)
    {
        CurrentPage = pg is > 0 ? pg.Value : 1;
        await LoadFeedAsync(cancellationToken);
    }

    public async Task<IActionResult> OnPostCreateAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = "/" });
        }

        if (!ModelState.IsValid)
        {
            CurrentPage = 1;
            await LoadFeedAsync(cancellationToken);
            return Page();
        }

        try
        {
            await _posts.CreateAsync(user.Id, user.DisplayName, Composer.Content, Composer.ImageUrl, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            ComposeError = "Couldn't publish your post. Please try again. (" + ex.Message + ")";
        }

        return RedirectToPage(new { pg = 1 });
    }

    public async Task<IActionResult> OnPostToggleLikeAsync(string postId, int pg, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = "/" });
        }

        PostDocument? post = await _posts.GetAsync(postId, cancellationToken);
        if (post is not null)
        {
            await _likes.ToggleAsync(post, user.Id, cancellationToken);
        }

        return RedirectToPage(new { pg });
    }

    public async Task<IActionResult> OnPostToggleFollowAsync(string targetUserId, string targetUserName, int pg, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = "/" });
        }

        if (user.Id != targetUserId)
        {
            await _follows.ToggleAsync(user.Id, targetUserId, targetUserName, cancellationToken);
        }

        return RedirectToPage(new { pg });
    }

    private async Task LoadFeedAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        IsSignedIn = user is { IsSignedIn: true };

        try
        {
            MudbaseListResult<PostDocument> result = await _posts.ListFeedAsync(CurrentPage, PageSize, cancellationToken);
            HasMore = CurrentPage < result.TotalPages;

            HashSet<string> likedPostIds = user is { IsSignedIn: true }
                ? await _likes.ListMyLikedPostIdsAsync(user.Id, cancellationToken)
                : new HashSet<string>();
            HashSet<string> followingIds = user is { IsSignedIn: true }
                ? await _follows.ListMyFollowingIdsAsync(user.Id, cancellationToken)
                : new HashSet<string>();

            Posts = result.Items.Select(post => new PostCardViewModel
            {
                Post = post,
                Liked = likedPostIds.Contains(post.Id),
                FollowingAuthor = followingIds.Contains(post.AuthorId),
                LinkToDetail = true,
                IsSignedIn = user is { IsSignedIn: true },
                IsOwnPost = user is { IsSignedIn: true } && user.Id == post.AuthorId,
                ReturnPage = CurrentPage,
            }).ToList();
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "Couldn't load the feed right now. Try refreshing. (" + ex.Message + ")";
        }
    }

    public sealed class ComposerInput
    {
        [Required(ErrorMessage = "Say something first"), StringLength(500, ErrorMessage = "Keep it under 500 characters")]
        public string Content { get; set; } = string.Empty;

        [StringLength(2048, ErrorMessage = "That URL is too long")]
        public string? ImageUrl { get; set; }
    }
}
