<?php
/**
 * @var string $status "success"|"error"
 * @var string|null $message
 */

use App\View;

$title = 'Email verification';
?>

<div style="max-width:24rem;margin:0 auto;text-align:center">
  <h1>Email verification</h1>
  <?php if ($status === 'success'): ?>
    <p class="muted">Your email is verified.</p>
    <a class="btn btn--block" href="/login" style="margin-top:1rem">Sign in now</a>
  <?php else: ?>
    <p class="flash flash--error"><?= View::escape((string) $message) ?></p>
    <a class="btn btn--outline btn--block" href="/register" style="margin-top:1rem">Back to registration</a>
  <?php endif; ?>
</div>
