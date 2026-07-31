<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Controllers\AuthController;
use App\Controllers\FeedController;
use App\Controllers\PostController;
use App\Controllers\ProfileController;
use App\Mudbase\MudbaseApiError;
use App\Router;
use App\View;

$router = new Router();

$feed = new FeedController();
$post = new PostController();
$profile = new ProfileController();
$auth = new AuthController();

$router->get('/', [$feed, 'index']);
$router->post('/posts', [$feed, 'create']);

$router->get('/posts/{id}', [$post, 'show']);
$router->post('/posts/{id}/comments', [$post, 'comment']);
$router->post('/posts/{id}/like', [$post, 'toggleLike']);

$router->get('/users/{userId}', [$profile, 'show']);
$router->post('/users/{userId}/follow', [$profile, 'toggleFollow']);
$router->get('/profile', [$profile, 'me']);

$router->get('/login', [$auth, 'loginForm']);
$router->post('/login', [$auth, 'login']);
$router->get('/register', [$auth, 'registerForm']);
$router->post('/register', [$auth, 'register']);
$router->post('/logout', [$auth, 'logout']);
$router->get('/verify-email', [$auth, 'verifyEmail']);

try {
    $router->dispatch((string) $_SERVER['REQUEST_METHOD'], (string) $_SERVER['REQUEST_URI'], function (): void {
        View::render('errors/not_found', [], 404);
    });
} catch (MudbaseApiError $e) {
    if ($e->isUnauthorized()) {
        // Token expired/was revoked mid-session — clear it and re-bootstrap as a fresh guest on
        // the next load rather than showing the visitor a raw auth error.
        unset($_SESSION['mudbase_token'], $_SESSION['mudbase_refresh_token'], $_SESSION['mudbase_user']);
        header('Location: ' . $_SERVER['REQUEST_URI']);
        exit;
    }

    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
} catch (\Throwable $e) {
    View::render('errors/server_error', ['message' => $e->getMessage()], 500);
}
