package dev.mudbase.showcase.social.web;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.domain.Post;
import dev.mudbase.showcase.social.mudbase.PageResult;
import dev.mudbase.showcase.social.service.FollowService;
import dev.mudbase.showcase.social.service.LikeService;
import dev.mudbase.showcase.social.service.PostService;
import dev.mudbase.showcase.social.support.RedirectSupport;
import dev.mudbase.showcase.social.support.ViewModelHelper;
import dev.mudbase.showcase.social.web.dto.PostComposerRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

/** The public feed (`GET /`) and post creation (`POST /posts`) - public read, auth-gated write. */
@Controller
public class FeedController {

  private final PostService postService;
  private final LikeService likeService;
  private final FollowService followService;
  private final ViewModelHelper viewModelHelper;

  public FeedController(
      PostService postService, LikeService likeService, FollowService followService, ViewModelHelper viewModelHelper) {
    this.postService = postService;
    this.likeService = likeService;
    this.followService = followService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/")
  public String feed(@RequestParam(value = "page", defaultValue = "1") int page, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    populateFeedModel(model, session, Math.max(1, page));
    if (!model.containsAttribute("postComposerRequest")) {
      model.addAttribute("postComposerRequest", new PostComposerRequest());
    }
    return "index";
  }

  @PostMapping("/posts")
  public String createPost(
      @Valid @ModelAttribute("postComposerRequest") PostComposerRequest form, BindingResult bindingResult, Model model, HttpSession session) {
    AuthSession viewer = viewModelHelper.addLayoutAttributes(model, session);
    if (viewer == null) {
      return "redirect:" + RedirectSupport.loginRedirectTo("/");
    }
    if (!bindingResult.hasErrors()) {
      String imageUrl = form.getImageUrl();
      postService.create(viewer, form.getContent(), imageUrl == null || imageUrl.isBlank() ? null : imageUrl);
      return "redirect:/";
    }
    // Re-render the feed with the composer's validation errors still visible, rather than a
    // redirect-and-flash round trip - matches this port's other forms (AuthController#login).
    populateFeedModel(model, session, 1);
    return "index";
  }

  private void populateFeedModel(Model model, HttpSession session, int page) {
    PageResult<Post> result = postService.feed(session, page);
    Set<String> likedPostIds = likeService.likedPostIdsForViewer(session);
    Set<String> followingIds = followService.followingIdsForViewer(session);
    List<Post> posts =
        result.items().stream()
            .map(p -> p.withLikedByViewer(likedPostIds.contains(p.getId())).withFollowingAuthor(followingIds.contains(p.getAuthorId())))
            .toList();
    model.addAttribute("posts", posts);
    model.addAttribute("page", result.page());
    model.addAttribute("hasMore", result.hasMore());
    model.addAttribute("nextPage", result.page() + 1);
  }
}
