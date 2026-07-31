package dev.mudbase.showcase.social.service;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.mudbase.AuthResult;
import dev.mudbase.showcase.social.mudbase.MudbaseAuthClient;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Service;

/** Login/logout only - see plan/build-plan.md "Stack Decisions" for why this port has no registration UI. */
@Service
public class AuthService {

  private final MudbaseAuthClient authClient;
  private final SessionAuthService sessionAuthService;

  public AuthService(MudbaseAuthClient authClient, SessionAuthService sessionAuthService) {
    this.authClient = authClient;
    this.sessionAuthService = sessionAuthService;
  }

  public AuthSession login(HttpSession session, String email, String password) {
    AuthResult result = authClient.login(email, password);
    sessionAuthService.establish(session, result);
    return sessionAuthService.current(session).orElseThrow();
  }

  public void logout(HttpSession session) {
    sessionAuthService.logout(session);
  }
}
