package dev.mudbase.showcase.social.service;

import dev.mudbase.showcase.social.domain.Post;
import dev.mudbase.showcase.social.domain.ProfileView;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.springframework.stereotype.Service;

/**
 * Aggregates {@code GET /users/{userId}}'s several reads into one {@link ProfileView}. This is
 * the exact multi-call-from-one-session-snapshot shape that required the fix in {@link
 * dev.mudbase.showcase.social.auth.SessionAuthService#recoverFromUnauthorized} - see that method's
 * javadoc and plan/build-plan.md finding #8.
 */
@Service
public class ProfileService {

  private final PostService postService;
  private final FollowService followService;

  public ProfileService(PostService postService, FollowService followService) {
    this.postService = postService;
    this.followService = followService;
  }

  public ProfileView load(HttpSession session, String userId) {
    // Fetched once and reused for both the visible post list and display-name resolution below -
    // avoids a duplicate round trip to the same query.
    List<Post> posts = postService.byAuthor(session, userId);
    String displayName = resolveDisplayNameFromPosts(session, userId, posts);
    long followerCount = followService.countFollowers(session, userId);
    long followingCount = followService.countFollowing(session, userId);
    long postCount = postService.countByAuthor(session, userId);
    return new ProfileView(userId, displayName, followerCount, followingCount, postCount, posts);
  }

  /**
   * Standalone display-name lookup for callers (e.g. {@code ProfileController#toggleFollow},
   * which needs a name to denormalize onto the new `follows` row) that don't need the full {@link
   * ProfileView} aggregate - cheaper than {@link #load} since it skips the follower/following/post
   * count queries.
   */
  public String resolveDisplayName(HttpSession session, String userId) {
    return resolveDisplayNameFromPosts(session, userId, postService.byAuthor(session, userId));
  }

  /**
   * There is no `users` collection, so a profile has no server-side source of truth for a display
   * name - every author/commenter/follower name in this data model is denormalized onto the row
   * that references them. Mirrors the reference web app's `useResolvedDisplayName` exactly: the
   * user's most recent post's `authorName` (posts are already sorted `-createdAt`, so the first
   * entry is the most recent), else the first non-blank `followingName` recorded by anyone who
   * follows them, else the literal string "Member".
   */
  private String resolveDisplayNameFromPosts(HttpSession session, String userId, List<Post> postsByAuthorNewestFirst) {
    if (!postsByAuthorNewestFirst.isEmpty()) {
      String fromPost = postsByAuthorNewestFirst.get(0).getAuthorName();
      if (fromPost != null && !fromPost.isBlank()) {
        return fromPost;
      }
    }
    return followService.mostRecentFollowerRecordedName(session, userId).orElse("Member");
  }
}
