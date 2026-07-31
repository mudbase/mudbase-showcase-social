using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Social.Models;
using MudbaseShowcase.Social.Services;

namespace MudbaseShowcase.Social.Pages;

public sealed class LoginModel : PageModel
{
    private readonly MudbaseAuthService _authService;

    public LoginModel(MudbaseAuthService authService)
    {
        _authService = authService;
    }

    [BindProperty]
    public LoginInput Input { get; set; } = new();

    public string? ErrorMessage { get; private set; }

    /// <summary>Where to send the shopper after a successful sign-in — the composer/comment/like/follow forms pass their own page URL here so signing in doesn't bounce the visitor back to the feed root.</summary>
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        AuthOutcome outcome = await _authService.LoginAsync(Input.Email, Input.Password, cancellationToken);
        if (!outcome.Succeeded)
        {
            ErrorMessage = outcome.ErrorMessage ?? "Login failed";
            return Page();
        }

        if (!string.IsNullOrWhiteSpace(ReturnUrl) && Url.IsLocalUrl(ReturnUrl))
        {
            return LocalRedirect(ReturnUrl);
        }

        return RedirectToPage("/Index");
    }

    public sealed class LoginInput
    {
        [Required(ErrorMessage = "Email is required"), EmailAddress(ErrorMessage = "Enter a valid email address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        public string Password { get; set; } = string.Empty;
    }
}
