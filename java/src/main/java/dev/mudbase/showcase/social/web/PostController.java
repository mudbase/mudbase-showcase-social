package dev.mudbase.showcase.social.web;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.domain.Post;
import dev.mudbase.showcase.social.service.CommentService;
import dev.mudbase.showcase.social.service.FollowService;
import dev.mudbase.showcase.social.service.LikeService;
import dev.mudbase.showcase.social.service.PostService;
import dev.mudbase.showcase.social.support.RedirectSupport;
import dev.mudbase.showcase.social.support.ViewModelHelper;
import dev.mudbase.showcase.social.web.dto.CommentRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

/** Post detail (`GET /posts/{id}`), comments, and the like toggle - public read, auth-gated write. */
@Controller
@RequestMapping("/posts/{id}")
public class PostController {

  private final PostService postService;
  private final CommentService commentService;
  private final LikeService likeService;
  private final FollowService followService;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public PostController(
      PostService postService,
      CommentService commentService,
      LikeService likeService,
      FollowService followService,
      ViewModelHelper viewModelHelper,
      SessionAuthService sessionAuthService) {
    this.postService = postService;
    this.commentService = commentService;
    this.likeService = likeService;
    this.followService = followService;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  @GetMapping
  public String detail(@PathVariable String id, Model model, HttpSession session) {
    AuthSession viewer = viewModelHelper.addLayoutAttributes(model, session);
    Optional<Post> postOpt = postService.findById(session, id);
    if (postOpt.isEmpty()) {
      model.addAttribute("errorMessage", "This post is no longer available.");
      return "posts/not-found";
    }
    if (!model.containsAttribute("commentRequest")) {
      model.addAttribute("commentRequest", new CommentRequest());
    }
    populatePostModel(model, session, viewer, postOpt.get());
    return "posts/detail";
  }

  @PostMapping("/comments")
  public String addComment(
      @PathVariable String id,
      @Valid @ModelAttribute("commentRequest") CommentRequest form,
      BindingResult bindingResult,
      Model model,
      HttpSession session) {
    AuthSession viewer = viewModelHelper.addLayoutAttributes(model, session);
    if (viewer == null) {
      return "redirect:" + RedirectSupport.loginRedirectTo("/posts/" + id);
    }
    if (!bindingResult.hasErrors()) {
      commentService.create(viewer, id, form.getContent());
      return "redirect:/posts/" + id;
    }
    Optional<Post> postOpt = postService.findById(session, id);
    if (postOpt.isEmpty()) {
      model.addAttribute("errorMessage", "This post is no longer available.");
      return "posts/not-found";
    }
    populatePostModel(model, session, viewer, postOpt.get());
    return "posts/detail";
  }

  @PostMapping("/like")
  public String toggleLike(
      @PathVariable String id, @RequestParam(value = "redirect", required = false) String redirect, HttpSession session) {
    String backTo = RedirectSupport.safe(redirect, "/posts/" + id);
    Optional<AuthSession> viewer = sessionAuthService.signedInUser(session);
    if (viewer.isEmpty()) {
      return "redirect:" + RedirectSupport.loginRedirectTo(backTo);
    }
    likeService.toggle(viewer.get(), id);
    return "redirect:" + backTo;
  }

  private void populatePostModel(Model model, HttpSession session, AuthSession viewer, Post post) {
    boolean liked = likeService.isLikedByViewer(viewer, post.getId());
    boolean followingAuthor = viewer != null && followService.isFollowedByViewer(session, post.getAuthorId());
    model.addAttribute("post", post.withLikedByViewer(liked).withFollowingAuthor(followingAuthor));
    model.addAttribute("comments", commentService.listForPost(session, post.getId()));
  }
}
