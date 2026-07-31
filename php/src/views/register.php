<?php
/** @var string $redirectTo */

use App\Http\Csrf;
use App\View;

$title = 'Create your account';
?>

<div style="max-width:24rem;margin:0 auto">
  <div style="text-align:center;margin-bottom:1.5rem">
    <h1>Create your account</h1>
    <p class="muted">Post, like, comment, and follow other people.</p>
  </div>

  <form method="post" action="/register">
    <?= Csrf::field() ?>
    <input type="hidden" name="redirectTo" value="<?= View::escape($redirectTo) ?>">
    <div class="grid-2">
      <div class="field">
        <label for="firstName">First name</label>
        <input type="text" id="firstName" name="firstName" autocomplete="given-name" required>
      </div>
      <div class="field">
        <label for="lastName">Last name</label>
        <input type="text" id="lastName" name="lastName" autocomplete="family-name" required>
      </div>
    </div>
    <div class="field">
      <label for="email">Email</label>
      <input type="email" id="email" name="email" autocomplete="email" required>
    </div>
    <div class="field">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" autocomplete="new-password" minlength="8" required>
    </div>
    <div class="field">
      <label class="checkbox-row">
        <input type="checkbox" name="agreedToTerms">
        <span>I agree to the Terms of Service and Privacy Policy.</span>
      </label>
    </div>
    <button type="submit" class="btn btn--block">Create account</button>
  </form>

  <p class="muted" style="text-align:center;margin-top:1rem">
    Already have an account? <a href="/login">Sign in</a>
  </p>
</div>
