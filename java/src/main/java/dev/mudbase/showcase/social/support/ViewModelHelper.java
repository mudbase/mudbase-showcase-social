package dev.mudbase.showcase.social.support;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Component;
import org.springframework.ui.Model;

/**
 * Populates the header/nav attributes every Thymeleaf page needs (current user). Deliberately
 * called explicitly per template-rendering controller method rather than wired as a global
 * {@code @ControllerAdvice @ModelAttribute}, matching the sibling ecommerce port's own reasoning:
 * keeps every controller's data needs explicit at the call site.
 */
@Component
public class ViewModelHelper {

  private final SessionAuthService sessionAuthService;

  public ViewModelHelper(SessionAuthService sessionAuthService) {
    this.sessionAuthService = sessionAuthService;
  }

  /** Returns the signed-in {@link AuthSession}, or {@code null} for a guest/anonymous viewer. */
  public AuthSession addLayoutAttributes(Model model, HttpSession session) {
    AuthSession auth = sessionAuthService.current(session).filter(AuthSession::isSignedIn).orElse(null);
    model.addAttribute("currentUser", auth);
    model.addAttribute("isSignedIn", auth != null);
    return auth;
  }
}
