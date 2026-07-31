<?php
/**
 * @var \App\Http\AppContext $context
 * @var array{type: string, message: string}|null $flash
 * @var string $content
 * @var string|null $title
 */

use App\View;

$pageTitle = isset($title) && $title !== '' ? "{$title} — Mudbase Social" : 'Mudbase Social';
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= View::escape($pageTitle) ?></title>
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>
  <header class="site-header">
    <div class="container site-header__row">
      <a href="/" class="site-header__brand">Mudbase Social</a>
      <nav class="site-header__nav">
        <?php if ($context->isSignedIn()): ?>
          <a class="btn btn--ghost btn--sm" href="/users/<?= urlencode((string) $context->userId()) ?>">Profile</a>
          <form method="post" action="/logout" style="display:inline">
            <?= \App\Http\Csrf::field() ?>
            <button type="submit" class="btn btn--outline btn--sm">Sign out</button>
          </form>
        <?php else: ?>
          <a class="btn btn--ghost btn--sm" href="/login">Sign in</a>
          <a class="btn btn--sm" href="/register">Sign up</a>
        <?php endif; ?>
      </nav>
    </div>
  </header>

  <main class="container">
    <?php if ($flash !== null): ?>
      <div class="flash flash--<?= View::escape($flash['type']) ?>" role="alert">
        <?= View::escape($flash['message']) ?>
      </div>
    <?php endif; ?>

    <?= $content ?>
  </main>

  <footer class="site-footer">
    <div class="container">
      Every post, comment, like, and follow on this page is served by a real Mudbase project via the
      generated PHP SDK — no custom backend beyond this thin routing/view layer.
    </div>
  </footer>
</body>
</html>
