<?php

declare(strict_types=1);

use App\Config;
use App\Http\AppContext;
use App\Mudbase\MudbaseClient;

require dirname(__DIR__) . '/vendor/autoload.php';

$rootDir = dirname(__DIR__);
Config::load($rootDir);

session_name(Config::optional('SESSION_NAME', 'mudbase_showcase_social_php'));
session_start();

$mudbaseUrl = rtrim(Config::optional('MUDBASE_URL', 'https://cloud.mudbase.dev'), '/');
$projectId = Config::required('MUDBASE_PROJECT_ID');
$postsCollectionId = Config::required('MUDBASE_POSTS_COLLECTION_ID');
$commentsCollectionId = Config::required('MUDBASE_COMMENTS_COLLECTION_ID');
$likesCollectionId = Config::required('MUDBASE_LIKES_COLLECTION_ID');
$followsCollectionId = Config::required('MUDBASE_FOLLOWS_COLLECTION_ID');

/**
 * On first visit (no token yet), establish an anonymous guest session so feed/post/comment reads
 * — which require the `authenticated` role — work without forcing a signup, mirroring the
 * reference Next.js app's auto-anonymous-login-on-mount behavior. Once a token exists, this app
 * trusts the user snapshot cached in $_SESSION at the time of that auth call rather than
 * re-validating with Mudbase on every single page load (a stateless SPA revalidates once per
 * client mount; a server-rendered app re-mounts on every request, so doing the same here would
 * mean one Mudbase round trip per page view). If a token has actually expired, the first API call
 * that hits it receives a 401, which the front controller (public/index.php) catches, clears the
 * session, and redirects back to the same URL to re-bootstrap as a fresh guest.
 *
 * Deliberately caught broadly here (not just MudbaseApiError): with no live Mudbase project
 * reachable, this call fails at the transport level (DNS/connection), and the app must still boot
 * and render the feed shell rather than fatal-erroring on every request.
 */
if (!isset($_SESSION['mudbase_token'])) {
    try {
        $anonClient = new MudbaseClient($mudbaseUrl, $projectId);
        $session = $anonClient->establishAnonymousSession();
        $_SESSION['mudbase_token'] = $session['token'];
        $_SESSION['mudbase_refresh_token'] = $session['refreshToken'];
        $_SESSION['mudbase_user'] = $session['user'];
    } catch (\Throwable) {
        // No live Mudbase project reachable (e.g. local smoke-testing without credentials) — fall
        // through with no session. Pages that need collection data will surface their own
        // "couldn't load" state instead of a fatal error; that is the intended degraded mode.
        $_SESSION['mudbase_token'] = null;
        $_SESSION['mudbase_user'] = null;
    }
}

$token = $_SESSION['mudbase_token'] ?? null;
$refreshToken = $_SESSION['mudbase_refresh_token'] ?? null;

/**
 * Wired into MudbaseClient so a mid-request 401 (access token expired) can be recovered from
 * silently: MudbaseClient::callApi()/listDocuments() exchange the refresh token for a new pair
 * via POST /api/auth/refresh and retry the failing call once before giving up. This callback is
 * the only thing that persists the refreshed pair back into $_SESSION — MudbaseClient itself has
 * no session dependency, so it stays usable from a CLI script. Only a refresh-token failure
 * (itself expired/revoked) still reaches the front controller's catch(MudbaseApiError) in
 * public/index.php, which clears the session and re-bootstraps as a fresh guest — see that file.
 */
$onTokenRefreshed = static function (string $newToken, ?string $newRefreshToken): void {
    $_SESSION['mudbase_token'] = $newToken;
    $_SESSION['mudbase_refresh_token'] = $newRefreshToken;
};

$mudbase = new MudbaseClient(
    $mudbaseUrl,
    $projectId,
    is_string($token) ? $token : null,
    is_string($refreshToken) ? $refreshToken : null,
    $onTokenRefreshed,
);
$user = is_array($_SESSION['mudbase_user'] ?? null) ? $_SESSION['mudbase_user'] : null;

AppContext::set(new AppContext(
    mudbase: $mudbase,
    user: $user,
    postsCollectionId: $postsCollectionId,
    commentsCollectionId: $commentsCollectionId,
    likesCollectionId: $likesCollectionId,
    followsCollectionId: $followsCollectionId,
    mudbaseUrl: $mudbaseUrl,
));
