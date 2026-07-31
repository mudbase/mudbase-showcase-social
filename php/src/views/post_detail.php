<?php
/**
 * @var array<string, mixed>|null $post
 * @var list<array<string, mixed>> $comments
 * @var bool $liked
 * @var bool $followingAuthor
 * @var string|null $error
 * @var \App\Http\AppContext $context
 */

use App\Http\Csrf;
use App\Support\TimeFormat;
use App\View;

$title = 'Post';
?>

<?php if ($post === null): ?>
  <p class="flash flash--error"><?= $error !== null ? View::escape($error) : "This post isn't available." ?></p>
<?php else: ?>
  <?php $linkToDetail = false; ?>
  <?php require __DIR__ . '/partials/post_card.php'; ?>

  <hr class="divider">

  <div class="comments">
    <h2>Comments</h2>

    <form method="post" action="/posts/<?= urlencode((string) $post['_id']) ?>/comments" class="comment-form">
      <?= Csrf::field() ?>
      <textarea
        name="content"
        maxlength="300"
        placeholder="<?= $context->isSignedIn() ? 'Add a comment…' : 'Sign in to comment' ?>"
        <?= $context->isSignedIn() ? '' : 'disabled' ?>
      ></textarea>
      <div style="display:flex;justify-content:flex-end;margin-top:0.5rem">
        <?php if ($context->isSignedIn()): ?>
          <button type="submit" class="btn btn--sm">Comment</button>
        <?php else: ?>
          <a class="btn btn--sm" href="/login?redirect=<?= urlencode('/posts/' . (string) $post['_id']) ?>">Sign in to comment</a>
        <?php endif; ?>
      </div>
    </form>

    <?php if ($comments === []): ?>
      <p class="muted" style="text-align:center;padding:1.5rem 0">No comments yet — start the conversation.</p>
    <?php else: ?>
      <ul class="comment-list">
        <?php foreach ($comments as $comment): ?>
          <?php $commentAuthor = (string) ($comment['authorName'] ?? 'Member'); ?>
          <li class="comment">
            <span class="avatar avatar--sm" aria-hidden="true"><?= View::escape(mb_strtoupper(mb_substr($commentAuthor, 0, 1) ?: '?')) ?></span>
            <div class="comment__body">
              <div class="comment__meta">
                <strong><?= View::escape($commentAuthor) ?></strong>
                <span class="muted"><?= View::escape(TimeFormat::relative((string) ($comment['createdAt'] ?? ''))) ?></span>
              </div>
              <p><?= nl2br(View::escape((string) ($comment['content'] ?? ''))) ?></p>
            </div>
          </li>
        <?php endforeach; ?>
      </ul>
    <?php endif; ?>
  </div>
<?php endif; ?>
