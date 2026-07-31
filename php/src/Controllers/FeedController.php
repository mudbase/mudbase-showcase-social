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
 * Feed page — mirrors the reference app's `/` (src/app/page.tsx: `PostComposer` + `FeedList`).
 * Public read (newest-first, paginated via `?page=`), auth-gated write.
 */
final class FeedController
{
    private const PAGE_SIZE = 10;
    private const MAX_CONTENT_LENGTH = 500;

    /** @param array<string, string> $params */
    public function index(array $params): void
    {
        $ctx = AppContext::current();
        $page = max(1, (int) ($_GET['page'] ?? 1));

        $error = null;
        $posts = [];
        $hasMore = false;
        try {
            $result = $ctx->mudbase->listDocuments($ctx->postsCollectionId, null, '-createdAt', $page, self::PAGE_SIZE);
            $posts = $result['data'];
            $hasMore = $result['pagination']['page'] < $result['pagination']['totalPages'];
        } catch (MudbaseApiError $e) {
            $error = "Couldn't load the feed right now: {$e->getMessage()}";
        }

        $likedPostIds = [];
        $followingIds = [];
        if ($ctx->isSignedIn() && $posts !== []) {
            $userId = (string) $ctx->userId();
            $likedPostIds = SocialLookups::likedPostIds($ctx, $userId);
            $followingIds = SocialLookups::followingIds($ctx, $userId);
        }

        View::render('home', [
            'posts' => $posts,
            'page' => $page,
            'hasMore' => $hasMore,
            'error' => $error,
            'likedPostIds' => $likedPostIds,
            'followingIds' => $followingIds,
        ]);
    }

    /** @param array<string, string> $params */
    public function create(array $params): void
    {
        $ctx = AppContext::current();
        $this->requireCsrf('/');

        if (!$ctx->isSignedIn()) {
            Response::redirect('/login?redirect=' . urlencode('/'));
        }

        $content = trim((string) ($_POST['content'] ?? ''));
        $imageUrl = trim((string) ($_POST['imageUrl'] ?? ''));

        if ($content === '') {
            Flash::set('error', 'Write something first.');
            Response::redirect('/');
        }
        if (mb_strlen($content) > self::MAX_CONTENT_LENGTH) {
            Flash::set('error', 'Keep it under ' . self::MAX_CONTENT_LENGTH . ' characters.');
            Response::redirect('/');
        }
        if ($imageUrl !== '' && filter_var($imageUrl, FILTER_VALIDATE_URL) === false) {
            Flash::set('error', 'Enter a valid image URL.');
            Response::redirect('/');
        }

        $authorName = $ctx->displayName() ?? 'Member';

        try {
            $ctx->mudbase->createDocument($ctx->postsCollectionId, [
                'authorId' => $ctx->userId(),
                'authorName' => $authorName,
                'content' => $content,
                ...($imageUrl !== '' ? ['imageUrl' => $imageUrl] : []),
                'likesCount' => 0,
                'commentsCount' => 0,
            ]);
        } catch (MudbaseApiError $e) {
            Flash::set('error', "Couldn't post that: {$e->getMessage()}");
            Response::redirect('/');
        }

        Response::redirect('/');
    }

    private function requireCsrf(string $fallbackRedirect): void
    {
        if (!Csrf::verify($_POST['_csrf'] ?? null)) {
            Flash::set('error', 'Your session expired — please try again.');
            Response::redirect($fallbackRedirect);
        }
    }
}
