package dev.mudbase.showcase.social.support;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Guards every user-supplied {@code redirect} query/form parameter against open-redirect abuse.
 * Several routes in this app (login, like toggle, follow toggle) accept a `redirect` value so the
 * user lands back on whichever page they acted from (feed, post detail, or profile) - but that
 * value travels through an ordinary request parameter, so a crafted request could otherwise send
 * a signed-in user to an attacker-controlled origin after a trusted action. Only a same-origin
 * relative path starting with a single {@code /} is accepted; a full URL, a protocol-relative
 * {@code //host/path} (browsers treat that as same-scheme-different-host), or a blank value all
 * fall back to the caller's own default.
 */
public final class RedirectSupport {

  private RedirectSupport() {}

  public static String safe(String candidate, String fallback) {
    if (candidate == null || candidate.isBlank()) {
      return fallback;
    }
    if (!candidate.startsWith("/") || candidate.startsWith("//") || candidate.contains("://")) {
      return fallback;
    }
    return candidate;
  }

  /**
   * Builds a `/login?redirect=...` target with the destination path properly query-encoded - a
   * destination that itself carries a query string (e.g. `/?page=2`) would otherwise produce an
   * ambiguous nested `?`/`&` sequence in the resulting URL.
   */
  public static String loginRedirectTo(String destinationPath) {
    return "/login?redirect=" + URLEncoder.encode(destinationPath, StandardCharsets.UTF_8);
  }
}
