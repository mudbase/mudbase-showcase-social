package dev.mudbase.showcase.social.service;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.config.MudbaseProperties;
import dev.mudbase.showcase.social.domain.Post;
import dev.mudbase.showcase.social.mudbase.DocumentMapper;
import dev.mudbase.showcase.social.mudbase.MudbaseApiException;
import dev.mudbase.showcase.social.mudbase.MudbaseDataClient;
import dev.mudbase.showcase.social.mudbase.PageResult;
import jakarta.servlet.http.HttpSession;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `posts` collection. Feed/detail/profile browsing needs "some"
 * Mudbase-issued bearer token to satisfy the collection's "authenticated role, read-only"
 * permission even before sign-in - {@link SessionAuthService#publicReadToken} supplies that (the
 * signed-in user's own token, or a lazily-created anonymous guest token). Post creation and
 * counter updates always use the acting user's own JWT, which the `customer` role's `dataScope:
 * "all"` grant allows unconditionally (confirmed live - Ben's PATCH updated Ava's post's
 * `likesCount`, see ../web/plan/build-plan.md "Live smoke test results").
 */
@Service
public class PostService {

  private static final int FEED_PAGE_SIZE = 10;
  private static final int PROFILE_PAGE_SIZE = 50;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final SessionAuthService sessionAuthService;

  public PostService(MudbaseDataClient dataClient, MudbaseProperties properties, SessionAuthService sessionAuthService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.sessionAuthService = sessionAuthService;
  }

  /** Newest first, paginated - mirrors the reference web app's `usePostsFeed`. */
  public PageResult<Post> feed(HttpSession session, int page) {
    String token = sessionAuthService.publicReadToken(session);
    PageResult<Map<String, Object>> raw =
        dataClient.listPage(token, properties.getPostsCollectionId(), Map.of(), "-createdAt", page, FEED_PAGE_SIZE);
    List<Post> posts = raw.items().stream().map(Post::fromDocument).toList();
    return new PageResult<>(posts, raw.page(), raw.limit(), raw.total(), raw.hasMore());
  }

  public Optional<Post> findById(HttpSession session, String id) {
    String token = sessionAuthService.publicReadToken(session);
    try {
      return Optional.of(Post.fromDocument(dataClient.get(token, properties.getPostsCollectionId(), id)));
    } catch (MudbaseApiException e) {
      return Optional.empty();
    }
  }

  /** A user's own posts, newest first - used by the profile page. */
  public List<Post> byAuthor(HttpSession session, String authorId) {
    String token = sessionAuthService.publicReadToken(session);
    return dataClient
        .list(token, properties.getPostsCollectionId(), Map.of("authorId", authorId), "-createdAt", 1, PROFILE_PAGE_SIZE)
        .stream()
        .map(Post::fromDocument)
        .toList();
  }

  public long countByAuthor(HttpSession session, String authorId) {
    String token = sessionAuthService.publicReadToken(session);
    return dataClient.count(token, properties.getPostsCollectionId(), Map.of("authorId", authorId));
  }

  public Post create(AuthSession author, String content, String imageUrl) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("authorId", author.getUserId());
    body.put("authorName", author.getDisplayName());
    body.put("content", content);
    if (imageUrl != null && !imageUrl.isBlank()) {
      body.put("imageUrl", imageUrl);
    }
    body.put("likesCount", 0);
    body.put("commentsCount", 0);
    return Post.fromDocument(dataClient.create(author.getToken(), properties.getPostsCollectionId(), body));
  }

  /**
   * Re-reads the post immediately before writing the adjusted counter - the same check-then-act
   * guard style {@code useToggleLike}/{@code useCreateComment} use in the reference web app, so a
   * burst of concurrent likes/comments doesn't have two writers increment from the same stale
   * count. {@code delta} is clamped so the count never goes negative.
   */
  public Post adjustLikesCount(AuthSession actor, String postId, int delta) {
    Map<String, Object> current = dataClient.get(actor.getToken(), properties.getPostsCollectionId(), postId);
    long updated = Math.max(0, DocumentMapper.getLong(current, "likesCount", 0) + delta);
    Map<String, Object> updatedDoc =
        dataClient.update(actor.getToken(), properties.getPostsCollectionId(), postId, Map.of("likesCount", updated));
    return Post.fromDocument(updatedDoc);
  }

  public Post adjustCommentsCount(AuthSession actor, String postId, int delta) {
    Map<String, Object> current = dataClient.get(actor.getToken(), properties.getPostsCollectionId(), postId);
    long updated = Math.max(0, DocumentMapper.getLong(current, "commentsCount", 0) + delta);
    Map<String, Object> updatedDoc =
        dataClient.update(actor.getToken(), properties.getPostsCollectionId(), postId, Map.of("commentsCount", updated));
    return Post.fromDocument(updatedDoc);
  }
}
