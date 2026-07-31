import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_service.dart';
import '../../core/mudbase_exception.dart';
import '../../core/mudbase_socket_service.dart';
import '../../core/secure_token_storage.dart';
import '../../core/service_providers.dart';
import '../../models/mudbase_user.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, MudbaseUser?>(AuthController.new);

/// Owns the current session: bootstraps it from secure storage on cold
/// start, and drives login/register/logout. `state.value == null` means
/// "signed out" - the router's redirect logic (see `router/app_router.dart`)
/// reads this directly to gate every screen behind auth (this app, unlike
/// the web reference, has no anonymous-guest read path - see
/// `plan/build-plan.md` "Stack Decisions").
///
/// Also drives the realtime socket's connect/disconnect lifecycle alongside
/// the session it manages - a stale, now-invalid session must not stay
/// connected after logout (mirrors the web app's `useAuth.logout` disconnect
/// call).
///
/// The access token itself is intentionally kept out of Riverpod state (it
/// would have no UI reason to trigger a rebuild, and every rebuild
/// dependent on this provider would otherwise re-run whenever the token
/// rotates). It lives in a private field and in [SecureTokenStorage];
/// repositories read it via [callAuthorized]. Ported from the sibling
/// ecommerce Flutter app's `features/auth/auth_controller.dart`.
class AuthController extends AsyncNotifier<MudbaseUser?> {
  String? _token;

  // Refresh tokens rotate on every use (single-use, platform-enforced) - if
  // two calls both hit a 401 at once, only the first refresh call can
  // succeed since the second would present an already-rotated-away token.
  // This lets concurrent callers await the same in-flight refresh instead of
  // racing each other into failure - confirmed live in this build's own
  // smoke test that `POST /api/auth/refresh` returns a genuinely new,
  // distinct token pair (see `plan/build-plan.md`).
  Future<String?>? _refreshInFlight;

  AuthService get _authService => ref.read(authServiceProvider);
  SecureTokenStorage get _tokenStorage => ref.read(secureTokenStorageProvider);
  MudbaseSocketService get _socketService =>
      ref.read(mudbaseSocketServiceProvider);

  @override
  Future<MudbaseUser?> build() async {
    final storedToken = await _tokenStorage.readToken();
    if (storedToken == null) return null;
    try {
      final json = await _authService.getSession(storedToken);
      final userJson = json['user'] as Map<String, dynamic>?;
      final authenticated = json['authenticated'] as bool? ?? true;
      if (!authenticated || userJson == null) {
        await _tokenStorage.clear();
        return null;
      }
      _token = storedToken;
      _socketService.connect(storedToken);
      return MudbaseUser.fromJson(userJson);
    } on Exception {
      // An expired/revoked token, or the server being briefly unreachable,
      // both resolve to "signed out" rather than a hard startup crash - the
      // login screen is always a safe fallback.
      await _tokenStorage.clear();
      return null;
    }
  }

  String requireToken() {
    final token = _token;
    if (token == null) {
      throw StateError('requireToken() called with no active session.');
    }
    return token;
  }

  /// Runs [action] with the current access token and, if it fails because
  /// the token expired or was revoked (a 401 from any Mudbase endpoint),
  /// transparently refreshes the session via the stored refresh token and
  /// retries [action] exactly once with the new token - instead of letting a
  /// raw 401 surface to the screen calling this. Mirrors the web app's
  /// `MudbaseClient.request`'s `retriedAfterRefresh` handling
  /// (`web/src/lib/mudbase.ts`), ported via the ecommerce Flutter app.
  ///
  /// If the refresh itself fails (refresh token missing, expired, or already
  /// rotated away), the session is torn down exactly like [logout]'s local
  /// half and the *original* 401 is rethrown, so the caller's existing error
  /// handling (a snackbar, an inline message) still fires - the router's
  /// `authControllerProvider` redirect then sends the user back to the login
  /// screen on the next rebuild because `state` is now `AsyncData(null)`.
  Future<T> callAuthorized<T>(Future<T> Function(String token) action) async {
    final token = requireToken();
    try {
      return await action(token);
    } on MudbaseException catch (error) {
      if (error.statusCode != 401) rethrow;
      final refreshed = await _refreshAccessToken();
      if (refreshed == null) {
        await _clearSessionLocally();
        rethrow;
      }
      return action(refreshed);
    }
  }

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final json = await _authService.refreshSession(refreshToken);
      final newToken = json['token'] as String?;
      if (newToken == null) return null;
      final newRefreshToken = json['refreshToken'] as String?;
      _token = newToken;
      await _tokenStorage.saveSession(
        token: newToken,
        refreshToken: newRefreshToken,
      );
      _socketService.connect(newToken);
      return newToken;
    } on Exception {
      // Refresh token expired/revoked/already rotated away, or the server
      // was briefly unreachable - either way there is no new token to hand
      // back, so the caller in [callAuthorized] tears the session down.
      return null;
    }
  }

  Future<void> _clearSessionLocally() async {
    _token = null;
    await _tokenStorage.clear();
    _socketService.disconnect();
    state = const AsyncData(null);
  }

  Future<void> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required bool agreedToTerms,
  }) async {
    final json = await _authService.registerWithRole(
      role: 'customer',
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      agreedToTerms: agreedToTerms,
    );
    // The signup validator requires email verification on this project
    // (confirmed live by the web reference app - `requireVerification: true`,
    // no `token` in the response) - a successful call here usually means
    // "account created, not yet signed in", so only apply a session if a
    // token actually came back rather than assuming one.
    final token = json['token'] as String?;
    if (token == null) return;
    await _applySession(json);
  }

  Future<void> login({required String email, required String password}) async {
    final json = await _authService.login(email: email, password: password);
    await _applySession(json);
  }

  Future<void> logout() async {
    final token = _token;
    if (token != null) {
      // Best-effort - AuthService.logout() already swallows a 401 (already
      // revoked), and the local sign-out below must happen regardless of
      // whether the server revoke succeeds.
      try {
        await _authService.logout(token);
      } on Exception {
        // Ignored - see comment above.
      }
    }
    await _clearSessionLocally();
  }

  Future<void> _applySession(Map<String, dynamic> json) async {
    final token = json['token'] as String?;
    final userJson = json['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw const FormatException(
        'The server did not return a session for this account.',
      );
    }
    _token = token;
    await _tokenStorage.saveSession(
      token: token,
      refreshToken: json['refreshToken'] as String?,
    );
    _socketService.connect(token);
    state = AsyncData(MudbaseUser.fromJson(userJson));
  }
}
