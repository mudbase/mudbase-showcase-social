<?php

declare(strict_types=1);

namespace App\Http;

/**
 * One-shot session flash messages (set on one request, read and discarded on the next) — the
 * server-rendered equivalent of the reference app's inline `role="alert"` error/success text that
 * a client-side form keeps in React state after a fetch. Ported verbatim from the ecommerce PHP
 * port.
 */
final class Flash
{
    private const SESSION_KEY = 'flash';

    public static function set(string $type, string $message): void
    {
        $_SESSION[self::SESSION_KEY] = ['type' => $type, 'message' => $message];
    }

    /** @return array{type: string, message: string}|null */
    public static function consume(): ?array
    {
        $flash = $_SESSION[self::SESSION_KEY] ?? null;
        unset($_SESSION[self::SESSION_KEY]);
        return is_array($flash) ? $flash : null;
    }
}
