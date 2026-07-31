import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/service_providers.dart';
import 'repositories/comment_repository.dart';
import 'repositories/follow_repository.dart';
import 'repositories/like_repository.dart';
import 'repositories/post_repository.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(mudbaseDataServiceProvider));
});

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository(ref.watch(mudbaseDataServiceProvider));
});

final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  return LikeRepository(ref.watch(mudbaseDataServiceProvider));
});

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(mudbaseDataServiceProvider));
});
