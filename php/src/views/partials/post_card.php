<?php
/**
 * Shared post card — included from home.php, post_detail.php, and profile.php, mirroring the
 * reference app's reused `PostCard` component (src/components/feed/PostCard.tsx).
 *
 * @var array<string, mixed> $post
 * @var bool $liked
 * @var bool $followingAuthor
 * @var bool $linkToDetail
 * @var \App\Http\AppContext $context
 */

use App\Http\Csrf;
use App\Support\TimeFormat;
use App\View;

$linkToDetail = $linkToDetail ?? true;
$authorId = (string) ($post['authorId'] ?? '');
$authorName = (string) ($post['authorName'] ?? 'Member');
$initial = mb_strtoupper(mb_substr($authorName, 0, 1) ?: '?');
$isOwnPost = $context->isSignedIn() && $context->userId() === $authorId;
// Like/follow both redirect back to wherever the card was rendered (feed, profile, or post
// detail) rather than always jumping to the post - the closest a server-rendered page can get to
// the reference app's in-place optimistic update. See PostController/ProfileController for the
// open-redirect guard this value is checked against on the way back in.
$currentPath = (string) ($_SERVER['REQUEST_URI'] ?? '/');
?>
<article class="card post-card">
  <div class="post-card__header">
    <a href="/users/<?= urlencode($authorId) ?>" class="post-card__author">
      <span class="avatar" aria-hidden="true"><?= View::escape($initial) ?></span>
      <span>
        <span class="post-card__author-name"><?= View::escape($authorName) ?></span>
        <span class="post-card__time"><?= View::escape(TimeFormat::relative((string) ($post['createdAt'] ?? ''))) ?></span>
      </span>
    </a>
    <?php if (!$isOwnPost): ?>
      <form method="post" action="/users/<?= urlencode($authorId) ?>/follow">
        <?= Csrf::field() ?>
        <input type="hidden" name="redirectTo" value="<?= View::escape($currentPath) ?>">
        <button type="submit" class="btn btn--sm <?= $followingAuthor ? 'btn--outline' : '' ?>">
          <?= $followingAuthor ? 'Following' : 'Follow' ?>
        </button>
      </form>
    <?php endif; ?>
  </div>

  <p class="post-card__content"><?= nl2br(View::escape((string) ($post['content'] ?? ''))) ?></p>

  <?php if (!empty($post['imageUrl'])): ?>
    <div class="post-card__image">
      <img src="<?= View::escape((string) $post['imageUrl']) ?>" alt="" loading="lazy">
    </div>
  <?php endif; ?>

  <div class="post-card__actions">
    <form method="post" action="/posts/<?= urlencode((string) $post['_id']) ?>/like">
      <?= Csrf::field() ?>
      <input type="hidden" name="redirectTo" value="<?= View::escape($currentPath) ?>">
      <button type="submit" class="post-card__action <?= $liked ? 'is-active' : '' ?>" aria-pressed="<?= $liked ? 'true' : 'false' ?>">
        <?= $liked ? '♥' : '♡' ?> <?= (int) ($post['likesCount'] ?? 0) ?>
      </button>
    </form>
    <?php if ($linkToDetail): ?>
      <a class="post-card__action" href="/posts/<?= urlencode((string) $post['_id']) ?>">
        💬 <?= (int) ($post['commentsCount'] ?? 0) ?>
      </a>
    <?php else: ?>
      <span class="post-card__action post-card__action--static">
        💬 <?= (int) ($post['commentsCount'] ?? 0) ?>
      </span>
    <?php endif; ?>
  </div>
</article>
