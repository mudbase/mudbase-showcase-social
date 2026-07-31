package dev.mudbase.showcase.social.web;

import dev.mudbase.showcase.social.auth.AuthSession;
import dev.mudbase.showcase.social.auth.SessionAuthService;
import dev.mudbase.showcase.social.domain.ProfileView;
import dev.mudbase.showcase.social.service.FollowService;
import dev.mudbase.showcase.social.service.ProfileService;
import dev.mudbase.showcase.social.support.RedirectSupport;
import dev.mudbase.showcase.social.support.ViewModelHelper;
import jakarta.servlet.http.HttpSession;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

/** Profile pages (`GET /users/{userId}`, `GET /profile`) and the follow toggle. */
@Controller
public class ProfileController {

  private final ProfileService profileService;
  private final FollowService followService;
  private final ViewModelHelper viewModelHelper;
  private final SessionAuthService sessionAuthService;

  public ProfileController(
      ProfileService profileService, FollowService followService, ViewModelHelper viewModelHelper, SessionAuthService sessionAuthService) {
    this.profileService = profileService;
    this.followService = followService;
    this.viewModelHelper = viewModelHelper;
    this.sessionAuthService = sessionAuthService;
  }

  /** A thin, sign-in-required redirect to the viewer's own profile - see plan/build-plan.md. */
  @GetMapping("/profile")
  public String myProfile(HttpSession session) {
    Optional<AuthSession> viewer = sessionAuthService.signedInUser(session);
    if (viewer.isEmpty()) {
      return "redirect:" + RedirectSupport.loginRedirectTo("/profile");
    }
    return "redirect:/users/" + viewer.get().getUserId();
  }

  @GetMapping("/users/{userId}")
  public String userProfile(@PathVariable String userId, Model model, HttpSession session) {
    AuthSession viewer = viewModelHelper.addLayoutAttributes(model, session);
    ProfileView profile = profileService.load(session, userId);
    boolean isOwnProfile = viewer != null && viewer.getUserId().equals(userId);
    boolean following = viewer != null && !isOwnProfile && followService.isFollowedByViewer(session, userId);
    model.addAttribute("profile", profile);
    model.addAttribute("isOwnProfile", isOwnProfile);
    model.addAttribute("isFollowing", following);
    return "users/profile";
  }

  @PostMapping("/users/{userId}/follow")
  public String toggleFollow(
      @PathVariable String userId, @RequestParam(value = "redirect", required = false) String redirect, HttpSession session) {
    String backTo = RedirectSupport.safe(redirect, "/users/" + userId);
    Optional<AuthSession> viewer = sessionAuthService.signedInUser(session);
    if (viewer.isEmpty()) {
      return "redirect:" + RedirectSupport.loginRedirectTo(backTo);
    }
    if (viewer.get().getUserId().equals(userId)) {
      // Cannot follow yourself - the button is hidden on your own profile, but guard the endpoint
      // directly too rather than trusting only the template not to render it.
      return "redirect:" + backTo;
    }
    String targetDisplayName = profileService.resolveDisplayName(session, userId);
    followService.toggle(viewer.get(), userId, targetDisplayName);
    return "redirect:" + backTo;
  }
}
