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
 * Post detail page — mirrors the reference app's `/posts/[id]` (full post, oldest-first comment
 * thread, comment composer, like toggle). Public read, auth-gated write.
 */
final class PostController
{
    private const MAX_COMMENT_LENGTH = 300;
    // Capped at 100 — the generated SDK's DataApi hard-rejects limit > 100 client-side (see
    // MudbaseClient::SDK_MAX_LIMIT); the reference app's own COMMENTS_PAGE_LIMIT-equivalent (200)
    // calls the REST API directly with no such SDK-side ceiling.
    private const COMMENTS_PAGE_LIMIT = 100;

    /** @param array{id: string} $params */
    public function show(array $params): void
    {
        $ctx = AppContext::current();
        $postId = $params['id'];

        $post = null;
        $error = null;
        try {
            $post = $ctx->mudbase->getDocument($ctx->postsCollectionId, $postId);
        } catch (MudbaseApiError $e) {
            $error = $e->isNotFound() ? null : $e->getMessage();
        }

        if ($post === null || $post === []) {
            View::render(
                'post_detail',
                ['post' => null, 'comments' => [], 'liked' => false, 'followingAuthor' => false, 'error' => $error],
                $error !== null ? 502 : 404,
            );
            return;
        }

        $comments = [];
        try {
            $result = $ctx->mudbase->listDocuments($ctx->commentsCollectionId, ['postId' => $postId], 'createdAt', 1, self::COMMENTS_PAGE_LIMIT);
            $comments = $result['data'];
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't load comments: {$e->getMessage()}");
        }

        $liked = false;
        $followingAuthor = false;
        if ($ctx->isSignedIn()) {
            $viewerId = (string) $ctx->userId();
            $liked = in_array($postId, SocialLookups::likedPostIds($ctx, $viewerId), true);
            $followingAuthor = in_array((string) ($post['authorId'] ?? ''), SocialLookups::followingIds($ctx, $viewerId), true);
        }

        View::render('post_detail', [
            'post' => $post,
            'comments' => $comments,
            'liked' => $liked,
            'followingAuthor' => $followingAuthor,
            'error' => null,
        ]);
    }

    /** @param array{id: string} $params */
    public function comment(array $params): void
    {
        $ctx = AppContext::current();
        $postId = $params['id'];
        $this->requireCsrf("/posts/{$postId}");

        if (!$ctx->isSignedIn()) {
            Response::redirect('/login?redirect=' . urlencode("/posts/{$postId}"));
        }

        $content = trim((string) ($_POST['content'] ?? ''));
        if ($content === '') {
            Flash::set('error', 'Write a comment first.');
            Response::redirect("/posts/{$postId}");
        }
        if (mb_strlen($content) > self::MAX_COMMENT_LENGTH) {
            Flash::set('error', 'Keep it under ' . self::MAX_COMMENT_LENGTH . ' characters.');
            Response::redirect("/posts/{$postId}");
        }

        $authorName = $ctx->displayName() ?? 'Member';

        try {
            $ctx->mudbase->createDocument($ctx->commentsCollectionId, [
                'postId' => $postId,
                'authorId' => $ctx->userId(),
                'authorName' => $authorName,
                'content' => $content,
            ]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't post your comment: {$e->getMessage()}");
            Response::redirect("/posts/{$postId}");
        }

        // The comment is already saved at this point regardless of what happens below — unlike
        // the like toggle, a counter-update failure here must never roll back a real comment a
        // user just wrote (deleting their content would be worse than a briefly stale count). See
        // plan/build-plan.md "Multi-step flow consistency".
        try {
            $currentPost = $ctx->mudbase->getDocument($ctx->postsCollectionId, $postId);
            $commentsCount = (int) ($currentPost['commentsCount'] ?? 0) + 1;
            $ctx->mudbase->updateDocument($ctx->postsCollectionId, $postId, ['commentsCount' => $commentsCount]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Your comment was posted, but the comment count couldn't be updated right now: {$e->getMessage()}");
            Response::redirect("/posts/{$postId}");
        }

        Response::redirect("/posts/{$postId}");
    }

    /** @param array{id: string} $params */
    public function toggleLike(array $params): void
    {
        $ctx = AppContext::current();
        $postId = $params['id'];
        $this->requireCsrf("/posts/{$postId}");

        // Like/unlike is rendered on the feed, a profile, and the post detail page - carry
        // wherever the visitor clicked from back through the redirect instead of always jumping
        // to the post (see partials/post_card.php). Validated against open-redirect on the way out.
        $redirectTarget = is_string($_POST['redirectTo'] ?? null) ? $_POST['redirectTo'] : null;

        if (!$ctx->isSignedIn()) {
            Response::redirect('/login?redirect=' . urlencode($redirectTarget ?? "/posts/{$postId}"));
        }

        $userId = (string) $ctx->userId();

        try {
            $post = $ctx->mudbase->getDocument($ctx->postsCollectionId, $postId);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't load that post: {$e->getMessage()}");
            Response::redirectToSafe($redirectTarget, '/');
        }
        if ($post === []) {
            Flash::set('error', 'That post no longer exists.');
            Response::redirectToSafe($redirectTarget, '/');
        }

        try {
            // Check-then-act against the server (not just what's rendered) right before mutating -
            // reasonable protection against a double-click/double-tab race creating two like rows
            // for the same (postId, userId), since this collection type has no compound unique
            // index. Same guard the reference app's useToggleLike applies.
            $existing = $ctx->mudbase->listDocuments($ctx->likesCollectionId, ['postId' => $postId, 'userId' => $userId], '-createdAt', 1, 1);
            $existingLike = $existing['data'][0] ?? null;

            if ($existingLike !== null) {
                // Unlike: delete first, then decrement. If the counter PATCH below fails, there is
                // nothing to roll back — the like row is already correctly gone, and the next page
                // load re-reads the real likesCount from the server rather than trusting a stale
                // client value, so the visible state stays consistent even on that failure path.
                $ctx->mudbase->deleteDocument($ctx->likesCollectionId, $existingLike['_id']);
                $likesCount = max(0, (int) $post['likesCount'] - 1);
                $ctx->mudbase->updateDocument($ctx->postsCollectionId, $postId, ['likesCount' => $likesCount]);
            } else {
                // Like: create first, then increment. If the counter PATCH fails after the like
                // row was already created, roll the like row back before surfacing the error -
                // otherwise the user would have an orphaned like that never counts and no visible
                // explanation why. See plan/build-plan.md "Multi-step flow consistency".
                $created = $ctx->mudbase->createDocument($ctx->likesCollectionId, ['postId' => $postId, 'userId' => $userId]);
                try {
                    $likesCount = (int) $post['likesCount'] + 1;
                    $ctx->mudbase->updateDocument($ctx->postsCollectionId, $postId, ['likesCount' => $likesCount]);
                } catch (MudbaseApiError $e) {
                    try {
                        $ctx->mudbase->deleteDocument($ctx->likesCollectionId, $created['_id']);
                    } catch (MudbaseApiError) {
                        // Best-effort rollback — the original counter-update error below is still
                        // what the user sees; a failed rollback doesn't change that message.
                    }
                    throw $e;
                }
            }
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't update your like: {$e->getMessage()}");
            Response::redirectToSafe($redirectTarget, "/posts/{$postId}");
        }

        Response::redirectToSafe($redirectTarget, "/posts/{$postId}");
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
