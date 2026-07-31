package dev.mudbase.showcase.social.domain;

import java.util.List;

/**
 * Aggregated view model for {@code GET /users/{userId}} - not a Mudbase document itself, but a
 * composition of several reads ({@link dev.mudbase.showcase.social.service.ProfileService#load}):
 * a best-effort resolved display name (see that method's javadoc - there is no `users`
 * collection), follower/following/post counts, and that user's posts.
 */
public class ProfileView {

  private final String userId;
  private final String displayName;
  private final long followerCount;
  private final long followingCount;
  private final long postCount;
  private final List<Post> posts;

  public ProfileView(
      String userId, String displayName, long followerCount, long followingCount, long postCount, List<Post> posts) {
    this.userId = userId;
    this.displayName = displayName;
    this.followerCount = followerCount;
    this.followingCount = followingCount;
    this.postCount = postCount;
    this.posts = posts;
  }

  public String getUserId() {
    return userId;
  }

  public String getDisplayName() {
    return displayName;
  }

  public long getFollowerCount() {
    return followerCount;
  }

  public long getFollowingCount() {
    return followingCount;
  }

  public long getPostCount() {
    return postCount;
  }

  public List<Post> getPosts() {
    return posts;
  }
}
