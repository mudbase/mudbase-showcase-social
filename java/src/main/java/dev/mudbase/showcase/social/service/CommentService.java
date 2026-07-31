package dev.mudbase.showcase.social.service;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.config.MudbaseProperties;
import dev.mudbase.showcase.social.domain.Comment;
import dev.mudbase.showcase.social.mudbase.MudbaseDataClient;
import jakarta.servlet.http.HttpSession;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Service;

/** Reads and writes the `comments` collection, and keeps the parent post's `commentsCount` in sync. */
@Service
public class CommentService {

  private static final int THREAD_PAGE_SIZE = 200;

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;
  private final SessionAuthService sessionAuthService;
  private final PostService postService;

  public CommentService(
      MudbaseDataClient dataClient, MudbaseProperties properties, SessionAuthService sessionAuthService, PostService postService) {
    this.dataClient = dataClient;
    this.properties = properties;
    this.sessionAuthService = sessionAuthService;
    this.postService = postService;
  }

  /** Oldest first, like a normal comment thread - mirrors the reference web app's `useComments`. */
  public java.util.List<Comment> listForPost(HttpSession session, String postId) {
    String token = sessionAuthService.publicReadToken(session);
    return dataClient
        .list(token, properties.getCommentsCollectionId(), Map.of("postId", postId), "createdAt", 1, THREAD_PAGE_SIZE)
        .stream()
        .map(Comment::fromDocument)
        .toList();
  }

  public Comment create(AuthSession author, String postId, String content) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("postId", postId);
    body.put("authorId", author.getUserId());
    body.put("authorName", author.getDisplayName());
    body.put("content", content);
    Comment created = Comment.fromDocument(dataClient.create(author.getToken(), properties.getCommentsCollectionId(), body));
    postService.adjustCommentsCount(author, postId, 1);
    return created;
  }
}
