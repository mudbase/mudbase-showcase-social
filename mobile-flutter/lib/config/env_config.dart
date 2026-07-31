/// Compile-time configuration, supplied via `--dart-define` /
/// `--dart-define-from-file` - this project's Flutter convention (see
/// `flutter/SKILL.md` and the sibling `mudbase-showcase-ecommerce` port),
/// never a runtime `.env` file. Every value below is public (a Mudbase
/// project/collection ID is not a secret, same as the web app's
/// `NEXT_PUBLIC_*` vars) - there is no server-side credential anywhere in
/// this app. See README "Setup" for the full `--dart-define` list.
class EnvConfig {
  const EnvConfig._();

  static const String mudbaseBaseUrl = String.fromEnvironment(
    'MUDBASE_BASE_URL',
    defaultValue: 'https://cloud.mudbase.dev',
  );

  static const String mudbaseProjectId = String.fromEnvironment(
    'MUDBASE_PROJECT_ID',
  );

  static const String postsCollectionId = String.fromEnvironment(
    'POSTS_COLLECTION_ID',
  );

  static const String commentsCollectionId = String.fromEnvironment(
    'COMMENTS_COLLECTION_ID',
  );

  static const String likesCollectionId = String.fromEnvironment(
    'LIKES_COLLECTION_ID',
  );

  static const String followsCollectionId = String.fromEnvironment(
    'FOLLOWS_COLLECTION_ID',
  );

  /// Fails fast at startup (in `main()`) rather than surfacing a confusing
  /// mid-flow 404/401 the first time a screen tries to read an empty
  /// collection ID - mirrors the web app's `requireEnv()` (`src/lib/config.ts`)
  /// and the ecommerce Flutter port's own `assertConfigured()`.
  static void assertConfigured() {
    final missing = <String>[
      if (mudbaseProjectId.isEmpty) 'MUDBASE_PROJECT_ID',
      if (postsCollectionId.isEmpty) 'POSTS_COLLECTION_ID',
      if (commentsCollectionId.isEmpty) 'COMMENTS_COLLECTION_ID',
      if (likesCollectionId.isEmpty) 'LIKES_COLLECTION_ID',
      if (followsCollectionId.isEmpty) 'FOLLOWS_COLLECTION_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required --dart-define values: ${missing.join(', ')}. '
        'See README "Setup" for the full list and how to supply them.',
      );
    }
  }
}
