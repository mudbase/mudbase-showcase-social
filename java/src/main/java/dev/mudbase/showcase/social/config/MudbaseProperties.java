package dev.mudbase.showcase.social.config;

import jakarta.annotation.PostConstruct;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Every ID this app needs to talk to a provisioned Mudbase project. See java/.env.example for the
 * full list and where each value comes from.
 */
@ConfigurationProperties(prefix = "mudbase")
public class MudbaseProperties {

  private String baseUrl;
  private String projectId;
  private String postsCollectionId;
  private String commentsCollectionId;
  private String likesCollectionId;
  private String followsCollectionId;

  @PostConstruct
  void validate() {
    requireNonBlank(projectId, "mudbase.project-id (MUDBASE_PROJECT_ID)");
    requireNonBlank(postsCollectionId, "mudbase.posts-collection-id (MUDBASE_POSTS_COLLECTION_ID)");
    requireNonBlank(commentsCollectionId, "mudbase.comments-collection-id (MUDBASE_COMMENTS_COLLECTION_ID)");
    requireNonBlank(likesCollectionId, "mudbase.likes-collection-id (MUDBASE_LIKES_COLLECTION_ID)");
    requireNonBlank(followsCollectionId, "mudbase.follows-collection-id (MUDBASE_FOLLOWS_COLLECTION_ID)");
  }

  private static void requireNonBlank(String value, String name) {
    if (value == null || value.isBlank()) {
      throw new IllegalStateException("Missing required configuration value: " + name);
    }
  }

  public String getBaseUrl() {
    return baseUrl;
  }

  public void setBaseUrl(String baseUrl) {
    this.baseUrl = baseUrl;
  }

  public String getProjectId() {
    return projectId;
  }

  public void setProjectId(String projectId) {
    this.projectId = projectId;
  }

  public String getPostsCollectionId() {
    return postsCollectionId;
  }

  public void setPostsCollectionId(String postsCollectionId) {
    this.postsCollectionId = postsCollectionId;
  }

  public String getCommentsCollectionId() {
    return commentsCollectionId;
  }

  public void setCommentsCollectionId(String commentsCollectionId) {
    this.commentsCollectionId = commentsCollectionId;
  }

  public String getLikesCollectionId() {
    return likesCollectionId;
  }

  public void setLikesCollectionId(String likesCollectionId) {
    this.likesCollectionId = likesCollectionId;
  }

  public String getFollowsCollectionId() {
    return followsCollectionId;
  }

  public void setFollowsCollectionId(String followsCollectionId) {
    this.followsCollectionId = followsCollectionId;
  }
}
