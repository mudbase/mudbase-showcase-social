package dev.mudbase.showcase.social.service;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.config.MudbaseProperties;
import dev.mudbase.showcase.social.mudbase.DocumentMapper;
import dev.mudbase.showcase.social.mudbase.MudbaseDataClient;
import jakarta.servlet.http.HttpSession;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the `follows` collection. Same check-then-act uniqueness guard as {@link
 * LikeService} - this collection type also has no compound unique index.
 */
@Service
public class FollowService {

  private static final int MINE_LIMIT = 500;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final SessionAuthService sessionAuthService;

  public FollowService(MudbaseDataClient dataClient, MudbaseProperties properties, SessionAuthService sessionAuthService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.sessionAuthService = sessionAuthService;
  }

  public boolean isFollowedByViewer(HttpSession session, String targetUserId) {
    Optional<AuthSession> viewer = sessionAuthService.signedInUser(session);
    if (viewer.isEmpty()) {
      return false;
    }
    return !existingFollow(viewer.get().getToken(), viewer.get().getUserId(), targetUserId).isEmpty();
  }

  /**
   * Every user id the signed-in viewer already follows, fetched once per feed render and reused
   * by every post card's follow button - avoids one query per rendered post's author. Empty for a
   * guest (no "mine" to query).
   */
  public Set<String> followingIdsForViewer(HttpSession session) {
    Optional<AuthSession> viewer = sessionAuthService.signedInUser(session);
    if (viewer.isEmpty()) {
      return Set.of();
    }
    return dataClient
        .list(
            viewer.get().getToken(),
            properties.getFollowsCollectionId(),
            Map.of("followerId", viewer.get().getUserId()),
            null,
            1,
            MINE_LIMIT)
        .stream()
        .map(doc -> DocumentMapper.getString(doc, "followingId"))
        .collect(Collectors.toSet());
  }

  /** Followers of {@code userId} - readable by anyone, matching the reference app's `useFollowCounts`. */
  public long countFollowers(HttpSession session, String userId) {
    String token = sessionAuthService.publicReadToken(session);
    return dataClient.count(token, properties.getFollowsCollectionId(), Map.of("followingId", userId));
  }

  /** Accounts {@code userId} follows. */
  public long countFollowing(HttpSession session, String userId) {
    String token = sessionAuthService.publicReadToken(session);
    return dataClient.count(token, properties.getFollowsCollectionId(), Map.of("followerId", userId));
  }

  /**
   * The most recent non-blank {@code followingName} recorded by anyone following {@code userId} -
   * used as a fallback source for a display name when that user has never posted (see {@link
   * ProfileService#resolveDisplayName}).
   */
  public Optional<String> mostRecentFollowerRecordedName(HttpSession session, String userId) {
    String token = sessionAuthService.publicReadToken(session);
    List<Map<String, Object>> rows =
        dataClient.list(token, properties.getFollowsCollectionId(), Map.of("followingId", userId), null, 1, 20);
    return rows.stream()
        .map(row -> DocumentMapper.getString(row, "followingName"))
        .filter(name -> name != null && !name.isBlank())
        .findFirst();
  }

  /** Toggles {@code actor}'s follow of {@code targetUserId}; returns the new following state. */
  public boolean toggle(AuthSession actor, String targetUserId, String targetDisplayName) {
    var existing = existingFollow(actor.getToken(), actor.getUserId(), targetUserId);
    if (!existing.isEmpty()) {
      dataClient.delete(actor.getToken(), properties.getFollowsCollectionId(), DocumentMapper.getId(existing.get(0)));
      return false;
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("followerId", actor.getUserId());
    body.put("followingId", targetUserId);
    if (targetDisplayName != null && !targetDisplayName.isBlank()) {
      body.put("followingName", targetDisplayName);
    }
    dataClient.create(actor.getToken(), properties.getFollowsCollectionId(), body);
    return true;
  }

  private List<Map<String, Object>> existingFollow(String token, String followerId, String followingId) {
    return dataClient.list(
        token, properties.getFollowsCollectionId(), Map.of("followerId", followerId, "followingId", followingId), null, 1, 1);
  }
}
