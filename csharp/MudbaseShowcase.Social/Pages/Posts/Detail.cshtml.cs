using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Services;

namespace MudbaseShowcase.Social.Pages.Posts;

/// <summary>Single post page: full post, comments oldest-first, comment composer, like toggle. Mirrors web/src/app/posts/[id]/page.tsx.</summary>
public sealed class DetailModel : PageModel
{
    private readonly PostsService _posts;
    private readonly CommentsService _comments;
    private readonly LikesService _likes;
    private readonly FollowsService _follows;
    private readonly MudbaseSessionAccessor _session;

    public DetailModel(PostsService posts, CommentsService comments, LikesService likes, FollowsService follows, MudbaseSessionAccessor session)
    {
        _posts = posts;
        _comments = comments;
        _likes = likes;
        _follows = follows;
        _session = session;
    }

    public PostCardViewModel? Card { get; private set; }

    public IReadOnlyList<CommentDocument> Comments { get; private set; } = Array.Empty<CommentDocument>();

    public bool IsSignedIn { get; private set; }

    public bool IsNotFound { get; private set; }

    public string? LoadError { get; private set; }

    [BindProperty]
    public CommentInput Comment { get; set; } = new();

    [TempData]
    public string? CommentError { get; set; }

    public async Task OnGetAsync(string id, CancellationToken cancellationToken)
    {
        await LoadAsync(id, cancellationToken);
    }

    public async Task<IActionResult> OnPostCommentAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = $"/Posts/Detail/{id}" });
        }

        if (!ModelState.IsValid)
        {
            await LoadAsync(id, cancellationToken);
            return Page();
        }

        try
        {
            await _comments.CreateAsync(id, user.Id, user.DisplayName, Comment.Content, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            CommentError = "Couldn't post your comment. Please try again. (" + ex.Message + ")";
        }

        return RedirectToPage(new { id });
    }

    public async Task<IActionResult> OnPostToggleLikeAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = $"/Posts/Detail/{id}" });
        }

        PostDocument? post = await _posts.GetAsync(id, cancellationToken);
        if (post is not null)
        {
            await _likes.ToggleAsync(post, user.Id, cancellationToken);
        }

        return RedirectToPage(new { id });
    }

    public async Task<IActionResult> OnPostToggleFollowAsync(string id, string targetUserId, string targetUserName, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsSignedIn: true })
        {
            return RedirectToPage("/Login", new { ReturnUrl = $"/Posts/Detail/{id}" });
        }

        if (user.Id != targetUserId)
        {
            await _follows.ToggleAsync(user.Id, targetUserId, targetUserName, cancellationToken);
        }

        return RedirectToPage(new { id });
    }

    private async Task LoadAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        IsSignedIn = user is { IsSignedIn: true };

        PostDocument? post;
        try
        {
            post = await _posts.GetAsync(id, cancellationToken);
        }
        catch (MudbaseApiException ex)
        {
            LoadError = "This post isn't available right now. (" + ex.Message + ")";
            return;
        }

        if (post is null)
        {
            IsNotFound = true;
            return;
        }

        bool liked = false;
        bool followingAuthor = false;
        if (user is { IsSignedIn: true })
        {
            HashSet<string> likedPostIds = await _likes.ListMyLikedPostIdsAsync(user.Id, cancellationToken);
            HashSet<string> followingIds = await _follows.ListMyFollowingIdsAsync(user.Id, cancellationToken);
            liked = likedPostIds.Contains(post.Id);
            followingAuthor = followingIds.Contains(post.AuthorId);
        }

        Card = new PostCardViewModel
        {
            Post = post,
            Liked = liked,
            FollowingAuthor = followingAuthor,
            LinkToDetail = false,
            IsSignedIn = IsSignedIn,
            IsOwnPost = user is { IsSignedIn: true } && user.Id == post.AuthorId,
            ReturnPage = 1,
        };

        MudbaseListResult<CommentDocument> commentsResult = await _comments.ListForPostAsync(id, cancellationToken);
        Comments = commentsResult.Items;
    }

    public sealed class CommentInput
    {
        [Required(ErrorMessage = "Write something first"), StringLength(300, ErrorMessage = "Keep it under 300 characters")]
        public string Content { get; set; } = string.Empty;
    }
}
