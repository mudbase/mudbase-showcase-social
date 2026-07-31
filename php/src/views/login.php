<?php
/** @var string $redirectTo */

use App\Http\Csrf;
use App\View;

$title = 'Sign in';
?>

<div style="max-width:24rem;margin:0 auto">
  <div style="text-align:center;margin-bottom:1.5rem">
    <h1>Sign in</h1>
    <p class="muted">Welcome back to Mudbase Social.</p>
  </div>

  <form method="post" action="/login">
    <?= Csrf::field() ?>
    <input type="hidden" name="redirectTo" value="<?= View::escape($redirectTo) ?>">
    <div class="field">
      <label for="email">Email</label>
      <input type="email" id="email" name="email" autocomplete="email" required>
    </div>
    <div class="field">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" autocomplete="current-password" required>
    </div>
    <button type="submit" class="btn btn--block">Sign in</button>
  </form>

  <p class="muted" style="text-align:center;margin-top:1rem">
    New here? <a href="/register">Create an account</a>
  </p>
</div>
