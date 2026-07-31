using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Services;

namespace MudbaseShowcase.Social.Pages;

/// <summary>Completes the emailed verification link. Mirrors web/src/app/verify-email/page.tsx.</summary>
public sealed class VerifyEmailModel : PageModel
{
    private readonly MudbaseAuthService _authService;

    public VerifyEmailModel(MudbaseAuthService authService)
    {
        _authService = authService;
    }

    public bool Succeeded { get; private set; }

    public string? ErrorMessage { get; private set; }

    public async Task OnGetAsync(string? token, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            ErrorMessage = "This verification link is missing its token.";
            return;
        }

        AuthOutcome outcome = await _authService.VerifyEmailAsync(token, cancellationToken);
        if (outcome.Succeeded)
        {
            Succeeded = true;
        }
        else
        {
            ErrorMessage = outcome.ErrorMessage ?? "This verification link is invalid or has expired.";
        }
    }
}
