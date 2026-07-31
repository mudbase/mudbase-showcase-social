package dev.mudbase.showcase.social.domain;

import dev.mudbase.showcase.social.mudbase.DocumentMapper;
import dev.mudbase.showcase.social.support.Formatting;
import java.util.Map;

/** Mirrors the `comments` collection - see plan/build-plan.md. */
public class Comment {

  private final String id;
  private final String postId;
  private final String authorId;
  private final String authorName;
  private final String content;
  private final String createdAt;

  private Comment(String id, String postId, String authorId, String authorName, String content, String createdAt) {
    this.id = id;
    this.postId = postId;
    this.authorId = authorId;
    this.authorName = authorName;
    this.content = content;
    this.createdAt = createdAt;
  }

  public static Comment fromDocument(Map<String, Object> doc) {
    return new Comment(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "postId"),
        DocumentMapper.getString(doc, "authorId"),
        DocumentMapper.getString(doc, "authorName", "Member"),
        DocumentMapper.getString(doc, "content"),
        DocumentMapper.getString(doc, "createdAt"));
  }

  public String getId() {
    return id;
  }

  public String getPostId() {
    return postId;
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

  public String getCreatedAt() {
    return createdAt;
  }

  public String getFormattedCreatedAt() {
    return Formatting.formatDate(createdAt);
  }
}
