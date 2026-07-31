package dev.mudbase.showcase.social.auth;

import java.io.Serializable;

/**
 * The signed-in user's Mudbase identity, held server-side in the Spring {@code HttpSession} -
 * the JWT never reaches client JS. One instance covers both a real `customer` account and the
 * lazily-created anonymous guest session used only to satisfy the collections' "authenticated
 * role, read-only" permission while browsing before sign-in.
 */
public class AuthSession implements Serializable {

  private static final long serialVersionUID = 1L;

  private final String token;
  private final String userId;
  private final String email;
  private final String firstName;
  private final String lastName;
  private final String customRole;
  private final boolean anonymous;
  private final String refreshToken;

  public AuthSession(
      String token,
      String userId,
      String email,
      String firstName,
      String lastName,
      String customRole,
      boolean anonymous,
      String refreshToken) {
    this.token = token;
    this.userId = userId;
    this.email = email;
    this.firstName = firstName;
    this.lastName = lastName;
    this.customRole = customRole;
    this.anonymous = anonymous;
    this.refreshToken = refreshToken;
  }

  public static AuthSession anonymous(String token, String userId, String refreshToken) {
    return new AuthSession(token, userId, null, null, null, null, true, refreshToken);
  }

  /**
   * Immutable copy carrying a rotated access/refresh token pair after a successful {@code
   * POST /api/auth/refresh} - every other field (identity, role, anonymous flag) is preserved
   * since a token refresh never changes who the caller is.
   */
  public AuthSession withRefreshedToken(String newToken, String newRefreshToken) {
    return new AuthSession(newToken, userId, email, firstName, lastName, customRole, anonymous, newRefreshToken);
  }

  public String getToken() {
    return token;
  }

  public String getUserId() {
    return userId;
  }

  public String getEmail() {
    return email;
  }

  public String getFirstName() {
    return firstName;
  }

  public String getLastName() {
    return lastName;
  }

  /** `${firstName} ${lastName}`.trim(), matching the reference web app's own authorName/display logic. */
  public String getDisplayName() {
    if (firstName == null && lastName == null) {
      return email != null ? email : "Guest";
    }
    String joined = String.join(" ", firstName != null ? firstName : "", lastName != null ? lastName : "").trim();
    return joined.isBlank() ? (email != null ? email : "Guest") : joined;
  }

  public String getCustomRole() {
    return customRole;
  }

  public boolean isAnonymous() {
    return anonymous;
  }

  public String getRefreshToken() {
    return refreshToken;
  }

  public boolean isSignedIn() {
    return !anonymous && userId != null;
  }
}
