<?php

declare(strict_types=1);

namespace App\Http;

use App\Mudbase\MudbaseClient;

/**
 * Per-request registry handed to every controller and view: the authenticated Mudbase client and
 * the current session user (or null/anonymous) — the server-rendered counterpart of the reference
 * app's React `useMudbase()` context (src/lib/mudbase-provider.tsx). One instance per request;
 * built once in bootstrap.php right after the session/auth handshake.
 */
final class AppContext
{
    private static ?self $instance = null;

    /** @param array<string, mixed>|null $user */
    public function __construct(
        public readonly MudbaseClient $mudbase,
        public readonly ?array $user,
        public readonly string $postsCollectionId,
        public readonly string $commentsCollectionId,
        public readonly string $likesCollectionId,
        public readonly string $followsCollectionId,
        public readonly string $mudbaseUrl,
    ) {
    }

    public static function set(self $context): void
    {
        self::$instance = $context;
    }

    public static function current(): self
    {
        if (self::$instance === null) {
            throw new \RuntimeException('AppContext accessed before bootstrap set it.');
        }
        return self::$instance;
    }

    public function isSignedIn(): bool
    {
        // `GET /api/auth/local/session` (see MudbaseClient::fetchSessionUser()) does not reliably
        // return an `isAnonymous` key at all for anonymous sessions in practice — confirmed against
        // the live API, the key is simply absent from the response body — so a bare
        // `($this->user['isAnonymous'] ?? false) !== true` check treats every anonymous guest as
        // signed in (missing key -> false -> "not anonymous"). `customRole` is the reliable signal
        // instead: Mudbase only ever assigns a customRole ("customer") to a real registered
        // account; anonymous sessions always come back with `customRole: null`. Kept the
        // `isAnonymous` check too as defense in depth for any response shape that does include it.
        // (Same fix, carried forward verbatim, as the ecommerce PHP port's own AppContext.)
        return $this->user !== null
            && ($this->user['isAnonymous'] ?? false) !== true
            && ($this->user['customRole'] ?? null) !== null;
    }

    public function userId(): ?string
    {
        $id = $this->user['id'] ?? $this->user['_id'] ?? null;
        return is_string($id) ? $id : null;
    }

    /** `"{firstName} {lastName}"`, trimmed — the denormalized author/commenter/follower name every write stores. */
    public function displayName(): ?string
    {
        if ($this->user === null) {
            return null;
        }
        $first = is_string($this->user['firstName'] ?? null) ? $this->user['firstName'] : '';
        $last = is_string($this->user['lastName'] ?? null) ? $this->user['lastName'] : '';
        $name = trim("{$first} {$last}");
        return $name !== '' ? $name : null;
    }
}
