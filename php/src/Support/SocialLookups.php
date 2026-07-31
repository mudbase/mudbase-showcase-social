<?php

declare(strict_types=1);

namespace App\Support;

use App\Http\AppContext;
use App\Mudbase\MudbaseApiError;

/**
 * Small read helpers shared by every controller that needs to know "does the current user like
 * this post" / "does the current user follow this author" — mirrors the reference app's
 * `useMyLikedPostIds`/`useMyFollowingIds` (src/hooks/useLikes.ts, src/hooks/useFollows.ts): one
 * bounded query per page load reused for every post rendered, rather than one query per post.
 * Capped at 100 — the generated PHP SDK's `DataApi` hard-rejects any `limit > 100` client-side
 * (see `MudbaseClient::SDK_MAX_LIMIT`), unlike the reference app's own `MINE_LIMIT = 500` which
 * calls the REST API directly with no such SDK-side ceiling. 100 is still functionally unbounded
 * at this demo's scale.
 */
final class SocialLookups
{
    private const MINE_LIMIT = 100;

    /** @return list<string> post ids the given user has liked */
    public static function likedPostIds(AppContext $ctx, string $userId): array
    {
        try {
            $result = $ctx->mudbase->listDocuments($ctx->likesCollectionId, ['userId' => $userId], '-createdAt', 1, self::MINE_LIMIT);
        } catch (MudbaseApiError) {
            return [];
        }
        return array_values(array_map(static fn (array $like): string => (string) $like['postId'], $result['data']));
    }

    /** @return list<string> user ids the given user follows */
    public static function followingIds(AppContext $ctx, string $userId): array
    {
        try {
            $result = $ctx->mudbase->listDocuments($ctx->followsCollectionId, ['followerId' => $userId], '-createdAt', 1, self::MINE_LIMIT);
        } catch (MudbaseApiError) {
            return [];
        }
        return array_values(array_map(static fn (array $follow): string => (string) $follow['followingId'], $result['data']));
    }

    /** Cheap counts via `pagination.total` on a limit:1 query — correct regardless of row count. */
    public static function followerCount(AppContext $ctx, string $userId): int
    {
        try {
            $result = $ctx->mudbase->listDocuments($ctx->followsCollectionId, ['followingId' => $userId], '-createdAt', 1, 1);
        } catch (MudbaseApiError) {
            return 0;
        }
        return $result['pagination']['total'];
    }

    public static function followingCount(AppContext $ctx, string $userId): int
    {
        try {
            $result = $ctx->mudbase->listDocuments($ctx->followsCollectionId, ['followerId' => $userId], '-createdAt', 1, 1);
        } catch (MudbaseApiError) {
            return 0;
        }
        return $result['pagination']['total'];
    }

    /**
     * A profile page has no `users` collection to read a display name from — every author/
     * commenter/follower name in this data model is denormalized onto the row that references
     * them. Resolves the best available name for a given userId: their most recent post's
     * `authorName`, falling back to any `followingName` recorded by someone who follows them,
     * falling back to the literal string "Member" if neither exists yet. Mirrors the reference
     * app's `useResolvedDisplayName` (src/hooks/useProfileStats.ts) exactly.
     */
    public static function resolveDisplayName(AppContext $ctx, string $userId): string
    {
        try {
            $posts = $ctx->mudbase->listDocuments($ctx->postsCollectionId, ['authorId' => $userId], '-createdAt', 1, 1);
            $fromPost = $posts['data'][0]['authorName'] ?? null;
            if (is_string($fromPost) && $fromPost !== '') {
                return $fromPost;
            }
        } catch (MudbaseApiError) {
            // Fall through to the next source.
        }

        try {
            $follows = $ctx->mudbase->listDocuments(
                $ctx->followsCollectionId,
                ['followingId' => $userId, 'followingName' => ['$exists' => true, '$ne' => '']],
                '-createdAt',
                1,
                1,
            );
            $fromFollow = $follows['data'][0]['followingName'] ?? null;
            if (is_string($fromFollow) && $fromFollow !== '') {
                return $fromFollow;
            }
        } catch (MudbaseApiError) {
            // Fall through to the generic fallback.
        }

        return 'Member';
    }

    public static function postCount(AppContext $ctx, string $userId): int
    {
        try {
            $result = $ctx->mudbase->listDocuments($ctx->postsCollectionId, ['authorId' => $userId], '-createdAt', 1, 1);
        } catch (MudbaseApiError) {
            return 0;
        }
        return $result['pagination']['total'];
    }
}
