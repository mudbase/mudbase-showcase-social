package dev.mudbase.showcase.social.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Comment content cap of 300 matches the reference web app's zod schema exactly. */
public class CommentRequest {

  @NotBlank(message = "Write a comment first")
  @Size(max = 300, message = "Keep it under 300 characters")
  private String content = "";

  public String getContent() {
    return content;
  }

  public void setContent(String content) {
    this.content = content;
  }
}
