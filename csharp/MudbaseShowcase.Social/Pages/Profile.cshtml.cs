using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Services;

namespace MudbaseShowcase.Social.Pages;

/// <summary>Thin redirect to /Users/Detail/{currentUserId}, mirroring web/src/app/profile/page.tsx.</summary>
public sealed class ProfileModel : PageModel
{
    private readonly MudbaseSessionAccessor _session;

    public ProfileModel(MudbaseSessionAccessor session)
    {
        _session = session;
    }

    public IActionResult OnGet()
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        return user is { IsSignedIn: true }
            ? RedirectToPage("/Users/Detail", new { userId = user.Id })
            : RedirectToPage("/Login", new { ReturnUrl = "/Profile" });
    }
}
