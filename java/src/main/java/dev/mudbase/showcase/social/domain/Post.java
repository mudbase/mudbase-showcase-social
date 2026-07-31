package dev.mudbase.showcase.social.domain;

import dev.mudbase.showcase.social.mudbase.DocumentMapper;
import dev.mudbase.showcase.social.support.Formatting;
import java.util.Map;

/**
 * Mirrors the `posts` collection - see plan/build-plan.md. {@code likedByViewer} and {@code
 * followingAuthor} are never stored on the document itself; they are viewer-relative flags
 * computed per request and attached via the {@code with*} copies below (immutable-update style,
 * per this project's coding-style rules - never mutate a rendered row in place).
 */
public class Post {

  private final String id;
  private final String authorId;
  private final String authorName;
  private final String content;
  private final String imageUrl;
  private final long likesCount;
  private final long commentsCount;
  private final String createdAt;
  private final boolean likedByViewer;
  private final boolean followingAuthor;

  private Post(
      String id,
      String authorId,
      String authorName,
      String content,
      String imageUrl,
      long likesCount,
      long commentsCount,
      String createdAt,
      boolean likedByViewer,
      boolean followingAuthor) {
    this.id = id;
    this.authorId = authorId;
    this.authorName = authorName;
    this.content = content;
    this.imageUrl = imageUrl;
    this.likesCount = likesCount;
    this.commentsCount = commentsCount;
    this.createdAt = createdAt;
    this.likedByViewer = likedByViewer;
    this.followingAuthor = followingAuthor;
  }

  public static Post fromDocument(Map<String, Object> doc) {
    return new Post(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "authorId"),
        DocumentMapper.getString(doc, "authorName", "Member"),
        DocumentMapper.getString(doc, "content"),
        DocumentMapper.getString(doc, "imageUrl"),
        DocumentMapper.getLong(doc, "likesCount", 0),
        DocumentMapper.getLong(doc, "commentsCount", 0),
        DocumentMapper.getString(doc, "createdAt"),
        false,
        false);
  }

  public Post withLikedByViewer(boolean liked) {
    return new Post(id, authorId, authorName, content, imageUrl, likesCount, commentsCount, createdAt, liked, followingAuthor);
  }

  public Post withFollowingAuthor(boolean following) {
    return new Post(id, authorId, authorName, content, imageUrl, likesCount, commentsCount, createdAt, likedByViewer, following);
  }

  public String getId() {
    return id;
  }

  public String getAuthorId() {
    return authorId;
  }

  public String getAuthorName() {
    return authorName;
  }

  public String getContent() {
    return content;
  }

  public String getImageUrl() {
    return imageUrl;
  }

  public boolean isHasImage() {
    return imageUrl != null && !imageUrl.isBlank();
  }

  public long getLikesCount() {
    return likesCount;
  }

  public long getCommentsCount() {
    return commentsCount;
  }

  public String getCreatedAt() {
    return createdAt;
  }

  public String getFormattedCreatedAt() {
    return Formatting.formatDate(createdAt);
  }

  public boolean isLikedByViewer() {
    return likedByViewer;
  }

  public boolean isFollowingAuthor() {
    return followingAuthor;
  }

  public boolean isOwnPost(String viewerUserId) {
    return viewerUserId != null && viewerUserId.equals(authorId);
  }
}
