<?php
/**
 * @var string $profileUserId
 * @var string $displayName
 * @var int $followerCount
 * @var int $followingCount
 * @var int $postCount
 * @var bool $following
 * @var list<array<string, mixed>> $posts
 * @var string|null $error
 * @var list<string> $likedPostIds
 * @var list<string> $followingIds
 * @var \App\Http\AppContext $context
 */

use App\Http\Csrf;
use App\View;

$title = $displayName;
$initial = mb_strtoupper(mb_substr($displayName, 0, 1) ?: '?');
$isOwnProfile = $context->isSignedIn() && $context->userId() === $profileUserId;
$currentPath = (string) ($_SERVER['REQUEST_URI'] ?? '/');
?>

<div class="profile-header">
  <div class="profile-header__identity">
    <span class="avatar avatar--lg" aria-hidden="true"><?= View::escape($initial) ?></span>
    <div>
      <h1><?= View::escape($displayName) ?></h1>
      <div class="profile-header__stats">
        <span><strong><?= $postCount ?></strong> posts</span>
        <span><strong><?= $followerCount ?></strong> followers</span>
        <span><strong><?= $followingCount ?></strong> following</span>
      </div>
    </div>
  </div>
  <?php if (!$isOwnProfile): ?>
    <form method="post" action="/users/<?= urlencode($profileUserId) ?>/follow">
      <?= Csrf::field() ?>
      <input type="hidden" name="redirectTo" value="<?= View::escape($currentPath) ?>">
      <button type="submit" class="btn <?= $following ? 'btn--outline' : '' ?>">
        <?= $following ? 'Following' : 'Follow' ?>
      </button>
    </form>
  <?php endif; ?>
</div>

<?php if ($error !== null): ?>
  <p class="flash flash--error" style="margin-top:1.5rem"><?= View::escape($error) ?></p>
<?php elseif ($posts === []): ?>
  <div class="empty-state" style="margin-top:1.5rem">
    <p>No posts yet.</p>
  </div>
<?php else: ?>
  <div class="post-list" style="margin-top:1.5rem">
    <?php foreach ($posts as $post): ?>
      <?php
        $liked = in_array((string) $post['_id'], $likedPostIds, true);
        $followingAuthor = in_array((string) ($post['authorId'] ?? ''), $followingIds, true);
        $linkToDetail = true;
        require __DIR__ . '/partials/post_card.php';
      ?>
    <?php endforeach; ?>
  </div>
<?php endif; ?>
