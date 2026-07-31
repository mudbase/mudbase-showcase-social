<?php
/**
 * @var list<array<string, mixed>> $posts
 * @var int $page
 * @var bool $hasMore
 * @var string|null $error
 * @var list<string> $likedPostIds
 * @var list<string> $followingIds
 * @var \App\Http\AppContext $context
 */

use App\Http\Csrf;
use App\View;

$title = null;
?>

<div style="margin-bottom:1.5rem">
  <h1>Mudbase Social</h1>
  <p class="muted" style="max-width:40rem">
    Every post, comment, like, and follow on this page is served by a real Mudbase project — no
    custom backend. Browse as a guest; sign in to post.
  </p>
</div>

<div class="card post-composer">
  <form method="post" action="/posts">
    <?= Csrf::field() ?>
    <div class="field">
      <label for="content" class="sr-only">What's on your mind?</label>
      <textarea
        id="content"
        name="content"
        maxlength="500"
        placeholder="<?= $context->isSignedIn() ? "What's on your mind?" : 'Sign in to post' ?>"
        <?= $context->isSignedIn() ? '' : 'disabled' ?>
      ></textarea>
    </div>
    <div class="field">
      <label for="imageUrl" class="field-hint">Image URL (optional)</label>
      <input
        type="url"
        id="imageUrl"
        name="imageUrl"
        placeholder="https://example.com/photo.jpg"
        <?= $context->isSignedIn() ? '' : 'disabled' ?>
      >
    </div>
    <div style="display:flex;justify-content:flex-end">
      <?php if ($context->isSignedIn()): ?>
        <button type="submit" class="btn">Post</button>
      <?php else: ?>
        <a class="btn" href="/login">Sign in to post</a>
      <?php endif; ?>
    </div>
  </form>
</div>

<?php if ($error !== null): ?>
  <p class="flash flash--error" style="margin-top:1.5rem"><?= View::escape($error) ?></p>
<?php elseif ($posts === []): ?>
  <div class="empty-state" style="margin-top:1.5rem">
    <p><?= $page > 1 ? 'No more posts.' : 'No posts yet — be the first to share something.' ?></p>
  </div>
<?php else: ?>
  <div class="post-list">
    <?php foreach ($posts as $post): ?>
      <?php
        $liked = in_array((string) $post['_id'], $likedPostIds, true);
        $followingAuthor = in_array((string) ($post['authorId'] ?? ''), $followingIds, true);
        $linkToDetail = true;
        require __DIR__ . '/partials/post_card.php';
      ?>
    <?php endforeach; ?>
  </div>

  <div class="pagination">
    <?php if ($page > 1): ?>
      <a class="btn btn--outline btn--sm" href="/?page=<?= $page - 1 ?>">&larr; Newer</a>
    <?php endif; ?>
    <?php if ($hasMore): ?>
      <a class="btn btn--outline btn--sm" href="/?page=<?= $page + 1 ?>">Older &rarr;</a>
    <?php endif; ?>
  </div>
<?php endif; ?>
