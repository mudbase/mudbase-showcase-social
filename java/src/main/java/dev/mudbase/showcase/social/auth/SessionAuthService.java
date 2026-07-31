package dev.mudbase.showcase.social.auth;

import dev.mudbase.showcase.social.mudbase.AuthResult;
import dev.mudbase.showcase.social.mudbase.MudbaseAuthClient;
import jakarta.servlet.http.HttpSession;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Bridges the Spring {@code HttpSession} to Mudbase auth. The JWT lives here, server-side, for
 * the life of the session - never sent to client JS (rendered pages get plain HTML/CSS only, no
 * token in scope).
 *
 * <p>Ported from {@code mudbase-showcase-ecommerce/java}'s {@code SessionAuthService}, including
 * the already-fixed {@link #recoverFromUnauthorized} - see that method's javadoc for the full
 * bug/fix history and plan/build-plan.md finding #8 for why this app's own profile page (four
 * sequential Mudbase calls from one session snapshot) is exactly the shape that bug required.
 */
@Component
public class SessionAuthService {

  static final String SESSION_KEY = "mudbase.auth";

  private final MudbaseAuthClient authClient;

  public SessionAuthService(MudbaseAuthClient authClient) {
    this.authClient = authClient;
  }

  public Optional<AuthSession> current(HttpSession session) {
    Object attribute = session.getAttribute(SESSION_KEY);
    return attribute instanceof AuthSession auth ? Optional.of(auth) : Optional.empty();
  }

  public Optional<AuthSession> signedInUser(HttpSession session) {
    return current(session).filter(AuthSession::isSignedIn);
  }

  /**
   * A bearer token good enough for public reads (the collections' "authenticated role,
   * read-only" permission): the signed-in user's own token when there is one, otherwise a
   * lazily-created anonymous guest session cached for the rest of this HttpSession - mirrors the
   * reference web app's "anonymous session on first visit" behavior, just held server-side
   * instead of in the browser.
   */
  public String publicReadToken(HttpSession session) {
    Optional<AuthSession> existing = current(session);
    if (existing.isPresent()) {
      return existing.get().getToken();
    }
    AuthResult anonymous = authClient.createAnonymousSession();
    session.setAttribute(
        SESSION_KEY, AuthSession.anonymous(anonymous.getToken(), anonymous.getUserId(), anonymous.getRefreshToken()));
    return anonymous.getToken();
  }

  public void establish(HttpSession session, AuthResult result) {
    session.setAttribute(
        SESSION_KEY,
        new AuthSession(
            result.getToken(),
            result.getUserId(),
            result.getEmail(),
            result.getFirstName(),
            result.getLastName(),
            result.getCustomRole(),
            false,
            result.getRefreshToken()));
  }

  public void logout(HttpSession session) {
    current(session).filter(AuthSession::isSignedIn).ifPresent(auth -> authClient.logout(auth.getToken()));
    session.removeAttribute(SESSION_KEY);
  }

  /**
   * Recovers from a 401 on an ordinary data/collection call by exchanging the stored refresh
   * token for a new access token, once. Called by {@link
   * dev.mudbase.showcase.social.mudbase.MudbaseDataClient} when a request bearing {@code
   * failedToken} comes back unauthorized - covers both a signed-in customer session and the
   * anonymous guest session used for pre-login browsing, since Mudbase issues a refresh token for
   * both.
   *
   * <p><b>Why a token mismatch does not mean "nothing to do."</b> This is the fix the sibling
   * {@code mudbase-showcase-ecommerce/java} port discovered and applied - reused here verbatim
   * rather than rediscovered, per the task's explicit instruction. Several controller methods in
   * this app (most notably {@code ProfileController#userProfile}, which resolves a display name
   * and reads follower count, following count, and post list - four sequential {@link
   * dev.mudbase.showcase.social.mudbase.MudbaseDataClient} calls from one session snapshot) read
   * the signed-in {@link AuthSession} once and pass that same snapshot's access token into
   * multiple calls. If the token was expired, the *first* of those calls lands here, refreshes,
   * and updates the session - but the *second* call still carries the pre-refresh token, so it
   * 401s too and lands here again with a {@code failedToken} that no longer matches {@code
   * current.getToken()} (the first call already moved it forward). Treating that as "someone else
   * already fixed it, give up" discards a perfectly good, just-refreshed session and forces a
   * spurious "session expired" logout on every multi-call page for any viewer whose access token
   * happened to expire mid-request. The correct read of a mismatch is the opposite: the session
   * already holds a token newer than the one that failed, so hand that back for an immediate
   * retry instead of refreshing again. If it turns out to *also* be stale (a real concurrent-
   * request race, or the mismatch reflects a session some other tab already logged out of), the
   * retry simply fails with its own 401 and propagates normally - this never masks a genuine
   * failure, it only avoids inventing one.
   *
   * <p>Returns empty (no retry attempted) only when there is truly nothing left to recover with:
   * no session at all, the token that failed is still the one on file but there is no refresh
   * token to exchange it with, or the refresh call itself was rejected (refresh token
   * invalid/expired/already reused) - the caller is expected to treat the original 401 as final
   * in those cases.
   */
  public Optional<AuthSession> recoverFromUnauthorized(HttpSession session, String failedToken) {
    Optional<AuthSession> currentOpt = current(session);
    if (currentOpt.isEmpty()) {
      return Optional.empty();
    }
    AuthSession current = currentOpt.get();
    if (!current.getToken().equals(failedToken)) {
      // An earlier call in this same request (most often) or a concurrent request (occasionally)
      // already refreshed this session past the token that just failed - hand back the session's
      // current token so the caller retries with it, rather than declaring the request a lost
      // cause. See the method javadoc above for why this is the safe reading of a mismatch.
      return Optional.of(current);
    }
    if (current.getRefreshToken() == null) {
      // The token that failed is still the one on file, but there is nothing to exchange it
      // with (shouldn't happen once establish()/publicReadToken() always store a refresh token,
      // but fail safe rather than throwing here).
      return Optional.empty();
    }
    try {
      AuthResult refreshed = authClient.refresh(current.getRefreshToken());
      AuthSession updated = current.withRefreshedToken(refreshed.getToken(), refreshed.getRefreshToken());
      session.setAttribute(SESSION_KEY, updated);
      return Optional.of(updated);
    } catch (RuntimeException refreshFailure) {
      // The refresh token itself is invalid/expired/reused - nothing left to recover with. Leave
      // the stale session in place; GlobalExceptionHandler's existing 401 handling (logout +
      // redirect to /login) is the correct terminal behavior in that case.
      return Optional.empty();
    }
  }
}
