package dev.mudbase.showcase.social.web;

import dev.mudbase.showcase.social.mudbase.MudbaseApiException;
import dev.mudbase.showcase.social.service.AuthService;
import dev.mudbase.showcase.social.support.RedirectSupport;
import dev.mudbase.showcase.social.support.ViewModelHelper;
import dev.mudbase.showcase.social.web.dto.LoginRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

/** Email/password sign-in only - see plan/build-plan.md "Stack Decisions" for why there is no registration UI in this port. */
@Controller
public class AuthController {

  private final AuthService authService;
  private final ViewModelHelper viewModelHelper;

  public AuthController(AuthService authService, ViewModelHelper viewModelHelper) {
    this.authService = authService;
    this.viewModelHelper = viewModelHelper;
  }

  @GetMapping("/login")
  public String loginForm(
      @RequestParam(value = "redirect", required = false) String redirect, Model model, HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    if (!model.containsAttribute("loginRequest")) {
      model.addAttribute("loginRequest", new LoginRequest());
    }
    model.addAttribute("redirectTo", redirect);
    return "auth/login";
  }

  @PostMapping("/login")
  public String login(
      @Valid @ModelAttribute("loginRequest") LoginRequest form,
      BindingResult bindingResult,
      @RequestParam(value = "redirect", required = false) String redirect,
      Model model,
      HttpSession session) {
    viewModelHelper.addLayoutAttributes(model, session);
    if (!bindingResult.hasErrors()) {
      try {
        authService.login(session, form.getEmail(), form.getPassword());
        return "redirect:" + RedirectSupport.safe(redirect, "/");
      } catch (MudbaseApiException e) {
        model.addAttribute("authError", e.getMessage());
      }
    }
    model.addAttribute("redirectTo", redirect);
    return "auth/login";
  }

  @PostMapping("/logout")
  public String logout(HttpSession session) {
    authService.logout(session);
    return "redirect:/";
  }
}
