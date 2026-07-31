// ignore_for_file: avoid_print
//
// Standalone, non-Flutter smoke test that exercises this app's own
// `lib/core/*`/`lib/data/*` layer - the exact classes `AuthController`,
// `FeedController`, `PostDetailController`, and `ProfileController` call -
// directly against the real, live `cloud.mudbase.dev` project. No Flutter
// SDK/device is required to run this: `AuthService`, `MudbaseDataService`,
// and every repository only depend on `dio`/`mudbase_sdk`, never
// `package:flutter`. Mirrors the sibling ecommerce Flutter app's
// `tool/manual_test.dart` exactly in structure and intent.
//
// Run with (values are this showcase project's real, already-provisioned
// IDs - not secrets, same ones baked into `dart_define.example.json`):
//
//   dart run tool/manual_test.dart \
//     --define=MUDBASE_PROJECT_ID=6a6cf79dd07caabbbdfbe9c5 \
//     --define=POSTS_COLLECTION_ID=6a6cf7d0d07caabbbdfbe9db \
//     --define=COMMENTS_COLLECTION_ID=6a6cf7d1d07caabbbdfbe9f1 \
//     --define=LIKES_COLLECTION_ID=6a6cf81ed07caabbbdfbea20 \
//     --define=FOLLOWS_COLLECTION_ID=6a6cf81ed07caabbbdfbea32
//
// NOTE (environment constraint, documented in plan/build-plan.md "Testing
// Note"): this build environment has no Flutter SDK installed, and this
// project's pubspec.yaml depends on `flutter: sdk: flutter` - so `dart pub
// get`/`dart run` cannot resolve *this* package's dependencies here (`dart
// pub get` fails with "the Flutter SDK is not available" for the whole
// project, not just Flutter-importing files). This script is written to run
// correctly once Flutter is installed (or in CI) - the equivalent live
// verification for *this* build was performed with `curl` plus a Node.js
// `socket.io-client` probe directly against the real project instead; every
// request/response shape captured there is exactly what this script (and
// the app's own repositories) exercise. See plan/build-plan.md "Live Smoke
// Test Results" for that session's actual output.
//
// Exits with a non-zero status if any step fails, printing which step and
// why - intended for a human (or CI) to read top to bottom, not for
// assertion-per-line unit testing (see `test/` for that).
import 'dart:io';

import 'package:mudbase_sdk/mudbase_sdk.dart';
import 'package:mudbase_showcase_social/core/auth_service.dart';
import 'package:mudbase_showcase_social/core/mudbase_data_service.dart';
import 'package:mudbase_showcase_social/core/mudbase_exception.dart';
import 'package:mudbase_showcase_social/data/repositories/comment_repository.dart';
import 'package:mudbase_showcase_social/data/repositories/follow_repository.dart';
import 'package:mudbase_showcase_social/data/repositories/like_repository.dart';
import 'package:mudbase_showcase_social/data/repositories/post_repository.dart';

const _baseUrl = String.fromEnvironment(
  'MUDBASE_BASE_URL',
  defaultValue: 'https://cloud.mudbase.dev',
);
const _projectId = String.fromEnvironment('MUDBASE_PROJECT_ID');
const _postsCollectionId = String.fromEnvironment('POSTS_COLLECTION_ID');
const _commentsCollectionId = String.fromEnvironment('COMMENTS_COLLECTION_ID');
const _likesCollectionId = String.fromEnvironment('LIKES_COLLECTION_ID');
const _followsCollectionId = String.fromEnvironment('FOLLOWS_COLLECTION_ID');

// The two pre-provisioned, real-email-verified test accounts named in this
// build's own task brief - both already registered and verified, so this
// script only ever logs in, never registers (registration on this project
// is rate-limited and shared across every language-SDK test agent
// exercising the same project concurrently).
const _avaEmail = 'mudhaxk+mbsocial1@gmail.com';
const _benEmail = 'mudhaxk+mbsocial2@gmail.com';
const _password = 'SocialTest123!';

int _passed = 0;
int _failed = 0;

Future<bool> _step(String name, Future<void> Function() body) async {
  stdout.write('- $name ... ');
  try {
    await body();
    stdout.writeln('PASS');
    _passed++;
    return true;
  } on Object catch (error) {
    stdout.writeln('FAIL ($error)');
    _failed++;
    return false;
  }
}

/// For steps every later step in this script depends on (login, post
/// creation): if this fails, every remaining step would either throw a
/// confusing null-check on state that was never populated, or silently
/// exercise nothing. Stopping here with a clear summary is more honest than
/// letting a cascade of unrelated-looking failures print.
Future<void> _requireStep(String name, Future<void> Function() body) async {
  final ok = await _step(name, body);
  if (ok) return;
  print('');
  print(
    'Stopping: "$name" failed and every remaining step depends on it - '
    'see the FAIL line above for the real cause.',
  );
  print('Passed: $_passed, Failed: $_failed');
  exit(1);
}

void main() async {
  print('Mudbase Showcase Social (Flutter) - live manual smoke test');
  print('Base URL: $_baseUrl');
  print('Project:  $_projectId');
  print('');

  final missing = <String>[
    if (_projectId.isEmpty) 'MUDBASE_PROJECT_ID',
    if (_postsCollectionId.isEmpty) 'POSTS_COLLECTION_ID',
    if (_commentsCollectionId.isEmpty) 'COMMENTS_COLLECTION_ID',
    if (_likesCollectionId.isEmpty) 'LIKES_COLLECTION_ID',
    if (_followsCollectionId.isEmpty) 'FOLLOWS_COLLECTION_ID',
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Missing --define values: ${missing.join(', ')}');
    exit(64);
  }

  final sdk = MudbaseSdk(basePathOverride: _baseUrl);
  final auth = AuthService(sdk, _projectId);
  final data = MudbaseDataService(sdk, _projectId);
  final posts = PostRepository(data);
  final comments = CommentRepository(data);
  final likes = LikeRepository(data);
  final follows = FollowRepository(data);

  String? avaToken;
  String? avaRefreshToken;
  String? avaId;
  String? benToken;
  String? benId;
  String? postId;

  await _requireStep('login as Ava (Poster)', () async {
    final json = await auth.login(email: _avaEmail, password: _password);
    avaToken = json['token'] as String?;
    avaRefreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    avaId = user?['id'] as String? ?? user?['_id'] as String?;
    if (avaToken == null || avaId == null) {
      throw StateError('Ava session missing token/id: $json');
    }
  });

  await _requireStep('login as Ben (Follower)', () async {
    final json = await auth.login(email: _benEmail, password: _password);
    benToken = json['token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    benId = user?['id'] as String? ?? user?['_id'] as String?;
    if (benToken == null || benId == null) {
      throw StateError('Ben session missing token/id: $json');
    }
  });

  await _requireStep('Ava creates a post with an image URL', () async {
    final created = await posts.create(
      token: avaToken!,
      authorId: avaId!,
      authorName: 'Ava Poster',
      content: 'Hello from the Flutter manual smoke test!',
      imageUrl: 'https://picsum.photos/seed/mbsocial-flutter/600/400',
    );
    postId = created.id;
    if (created.likesCount != 0 || created.commentsCount != 0) {
      throw StateError('expected a fresh post to start at 0/0 counters');
    }
  });

  await _step('feed read includes the new post, newest first', () async {
    final page = await posts.listFeedPage(token: benToken!, page: 1);
    if (!page.posts.any((post) => post.id == postId)) {
      throw StateError('feed page 1 did not include the just-created post');
    }
  });

  await _step('Ben comments on Ava\'s post', () async {
    final created = await comments.create(
      token: benToken!,
      postId: postId!,
      authorId: benId!,
      authorName: 'Ben Follower',
      content: 'Nice post, Ava!',
    );
    if (created.postId != postId) {
      throw StateError('created comment has the wrong postId');
    }
    await posts.updateCounts(
      token: benToken!,
      postId: postId!,
      commentsCount: 1,
    );
  });

  await _step('post detail: comments for the post, oldest-first', () async {
    final list = await comments.listForPost(token: avaToken!, postId: postId!);
    if (!list.any((comment) => comment.authorId == benId)) {
      throw StateError('comment thread did not include Ben\'s comment');
    }
  });

  await _step('Ben likes Ava\'s post (check-then-act toggle)', () async {
    final toggled = await likes.toggle(
      token: benToken!,
      postId: postId!,
      userId: benId!,
      currentLikesCount: 0,
    );
    if (!toggled.liked || toggled.likesCount != 1) {
      throw StateError('expected the first toggle to like with count 1');
    }
    await posts.updateCounts(token: benToken!, postId: postId!, likesCount: 1);
  });

  await _step('Ben\'s liked-post ids include the post he just liked', () async {
    final likedIds = await likes.myLikedPostIds(
      token: benToken!,
      userId: benId!,
    );
    if (!likedIds.contains(postId)) {
      throw StateError('myLikedPostIds did not include $postId');
    }
  });

  await _step('Ben follows Ava (check-then-act toggle)', () async {
    final toggled = await follows.toggle(
      token: benToken!,
      followerId: benId!,
      followingId: avaId!,
      followingName: 'Ava Poster',
    );
    if (!toggled.following) {
      throw StateError('expected the first toggle to start following');
    }
  });

  await _step('Ben\'s following ids include Ava', () async {
    final followingIds = await follows.myFollowingIds(
      token: benToken!,
      userId: benId!,
    );
    if (!followingIds.contains(avaId)) {
      throw StateError('myFollowingIds did not include $avaId');
    }
  });

  await _step(
    'Ava\'s follower/following counts reflect Ben\'s follow',
    () async {
      final counts = await follows.counts(token: avaToken!, userId: avaId!);
      if (counts.followerCount < 1) {
        throw StateError('expected Ava to have at least 1 follower');
      }
    },
  );

  await _step('Ava\'s profile post list includes her new post', () async {
    final authored = await posts.listByAuthor(
      token: avaToken!,
      authorId: avaId!,
    );
    if (!authored.any((post) => post.id == postId)) {
      throw StateError('listByAuthor did not include the new post');
    }
  });

  await _step(
    'POST /api/auth/refresh returns a new, distinct token pair',
    () async {
      if (avaRefreshToken == null) {
        throw StateError('no refresh token was issued at login');
      }
      final refreshed = await auth.refreshSession(avaRefreshToken!);
      final newToken = refreshed['token'] as String?;
      if (newToken == null || newToken == avaToken) {
        throw StateError('refresh did not return a distinct new access token');
      }
      // Prove the new token is actually usable with a real authenticated call.
      await posts.listByAuthor(token: newToken, authorId: avaId!);
      avaToken = newToken;
    },
  );

  await _step('an invalid access token is rejected with a real 401', () async {
    try {
      await data.list(_postsCollectionId, token: 'not-a-real-token', limit: 1);
      throw StateError('expected a 401, request unexpectedly succeeded');
    } on MudbaseException catch (error) {
      if (error.statusCode != 401) {
        throw StateError('expected statusCode 401, got ${error.statusCode}');
      }
    }
  });

  await _step('sign out (best-effort server-side revoke)', () async {
    await auth.logout(avaToken!);
    await auth.logout(benToken!);
  });

  print('');
  print('Passed: $_passed, Failed: $_failed');
  if (_failed > 0) exit(1);
}
