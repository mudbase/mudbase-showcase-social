<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Http\AppContext;
use App\Http\Csrf;
use App\Http\Flash;
use App\Http\Response;
use App\Mudbase\MudbaseApiError;
use App\Support\SocialLookups;
use App\View;

/**
 * Profile page — mirrors the reference app's `/users/[userId]` (resolved display name, follower/
 * following/post counts, that user's posts, follow/unfollow) and its `/profile` self-redirect.
 */
final class ProfileController
{
    private const POSTS_PAGE_LIMIT = 100;

    /** @param array{userId: string} $params */
    public function show(array $params): void
    {
        $ctx = AppContext::current();
        $userId = $params['userId'];

        $displayName = SocialLookups::resolveDisplayName($ctx, $userId);
        $followerCount = SocialLookups::followerCount($ctx, $userId);
        $followingCount = SocialLookups::followingCount($ctx, $userId);
        $postCount = SocialLookups::postCount($ctx, $userId);

        $following = false;
        if ($ctx->isSignedIn()) {
            $following = in_array($userId, SocialLookups::followingIds($ctx, (string) $ctx->userId()), true);
        }

        $posts = [];
        $error = null;
        try {
            $result = $ctx->mudbase->listDocuments($ctx->postsCollectionId, ['authorId' => $userId], '-createdAt', 1, self::POSTS_PAGE_LIMIT);
            $posts = $result['data'];
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load this user's posts: {$e->getMessage()}";
        }

        $likedPostIds = [];
        $followingIds = [];
        if ($ctx->isSignedIn() && $posts !== []) {
            $viewerId = (string) $ctx->userId();
            $likedPostIds = SocialLookups::likedPostIds($ctx, $viewerId);
            $followingIds = SocialLookups::followingIds($ctx, $viewerId);
        }

        View::render('profile', [
            'profileUserId' => $userId,
            'displayName' => $displayName,
            'followerCount' => $followerCount,
            'followingCount' => $followingCount,
            'postCount' => $postCount,
            'following' => $following,
            'posts' => $posts,
            'error' => $error,
            'likedPostIds' => $likedPostIds,
            'followingIds' => $followingIds,
        ]);
    }

    /** @param array<string, string> $params */
    public function me(array $params): void
    {
        $ctx = AppContext::current();
        if (!$ctx->isSignedIn()) {
            Response::redirect('/login?redirect=' . urlencode('/profile'));
        }
        Response::redirect('/users/' . urlencode((string) $ctx->userId()));
    }

    /** @param array{userId: string} $params */
    public function toggleFollow(array $params): void
    {
        $ctx = AppContext::current();
        $targetUserId = $params['userId'];
        $this->requireCsrf("/users/{$targetUserId}");

        // Follow/unfollow is rendered on the feed, a profile, and the post detail page - carry
        // wherever the visitor clicked from back through the redirect (see partials/post_card.php
        // and views/profile.php). Validated against open-redirect on the way out.
        $redirectTarget = is_string($_POST['redirectTo'] ?? null) ? $_POST['redirectTo'] : null;

        if (!$ctx->isSignedIn()) {
            Response::redirect('/login?redirect=' . urlencode($redirectTarget ?? "/users/{$targetUserId}"));
        }

        $currentUserId = (string) $ctx->userId();
        if ($currentUserId === $targetUserId) {
            Flash::set('error', 'You cannot follow yourself.');
            Response::redirectToSafe($redirectTarget, "/users/{$targetUserId}");
        }

        try {
            // Check-then-act against the server, same race-guard rationale as the like toggle.
            // Follow/unfollow has no derived counter to keep in sync (follower/following counts
            // are computed live via pagination.total, not stored) - a single create/delete is the
            // whole write, so there is no multi-step consistency concern here.
            $existing = $ctx->mudbase->listDocuments(
                $ctx->followsCollectionId,
                ['followerId' => $currentUserId, 'followingId' => $targetUserId],
                '-createdAt',
                1,
                1,
            );
            $existingFollow = $existing['data'][0] ?? null;

            if ($existingFollow !== null) {
                $ctx->mudbase->deleteDocument($ctx->followsCollectionId, $existingFollow['_id']);
            } else {
                $targetName = SocialLookups::resolveDisplayName($ctx, $targetUserId);
                $ctx->mudbase->createDocument($ctx->followsCollectionId, [
                    'followerId' => $currentUserId,
                    'followingId' => $targetUserId,
                    'followingName' => $targetName,
                ]);
            }
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't update your follow: {$e->getMessage()}");
            Response::redirectToSafe($redirectTarget, "/users/{$targetUserId}");
        }

        Response::redirectToSafe($redirectTarget, "/users/{$targetUserId}");
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
