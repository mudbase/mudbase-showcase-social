package dev.mudbase.showcase.social.service;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.config.MudbaseProperties;
import dev.mudbase.showcase.social.mudbase.DocumentMapper;
import dev.mudbase.showcase.social.mudbase.MudbaseDataClient;
import jakarta.servlet.http.HttpSession;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `likes` collection. This collection type has no compound unique index, so
 * uniqueness is enforced at the application layer: every toggle re-queries {@code
 * {postId,userId}} immediately before creating/deleting - the same check-then-act guard the
 * reference web app's `useToggleLike` uses, "reasonable, not airtight" against a double-click/
 * double-tab race, per the task's own scope for this demo.
 */
@Service
public class LikeService {

  private static final int MINE_LIMIT = 500;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final SessionAuthService sessionAuthService;
  private final PostService postService;

  public LikeService(
      MudbaseDataClient dataClient, MudbaseProperties properties, SessionAuthService sessionAuthService, PostService postService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.sessionAuthService = sessionAuthService;
    this.postService = postService;
  }

  public boolean isLikedByViewer(AuthSession viewer, String postId) {
    if (viewer == null) {
      return false;
    }
    return !existingLike(viewer.getToken(), postId, viewer.getUserId()).isEmpty();
  }

  /**
   * Every post id the signed-in viewer has liked, fetched once per feed render and reused by
   * every post card - avoids one query per rendered post. Empty for a guest (no "mine" to query).
   */
  public Set<String> likedPostIdsForViewer(HttpSession session) {
    Optional<AuthSession> viewer = sessionAuthService.signedInUser(session);
    if (viewer.isEmpty()) {
      return Set.of();
    }
    return dataClient
        .list(viewer.get().getToken(), properties.getLikesCollectionId(), Map.of("userId", viewer.get().getUserId()), null, 1, MINE_LIMIT)
        .stream()
        .map(doc -> DocumentMapper.getString(doc, "postId"))
        .collect(Collectors.toSet());
  }

  /** Toggles the actor's like on {@code postId}; returns the new liked state. */
  public boolean toggle(AuthSession actor, String postId) {
    var existing = existingLike(actor.getToken(), postId, actor.getUserId());
    if (!existing.isEmpty()) {
      dataClient.delete(actor.getToken(), properties.getLikesCollectionId(), DocumentMapper.getId(existing.get(0)));
      postService.adjustLikesCount(actor, postId, -1);
      return false;
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("postId", postId);
    body.put("userId", actor.getUserId());
    dataClient.create(actor.getToken(), properties.getLikesCollectionId(), body);
    postService.adjustLikesCount(actor, postId, 1);
    return true;
  }

  private java.util.List<Map<String, Object>> existingLike(String token, String postId, String userId) {
    return dataClient.list(token, properties.getLikesCollectionId(), Map.of("postId", postId, "userId", userId), null, 1, 1);
  }
}
