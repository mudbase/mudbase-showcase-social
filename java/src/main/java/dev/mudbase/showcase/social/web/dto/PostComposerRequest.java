package dev.mudbase.showcase.social.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.hibernate.validator.constraints.URL;

/**
 * Content cap of 500 matches the reference web app's zod schema exactly. `imageUrl` is a pasted
 * URL, not a file upload - see plan/build-plan.md "Known limitations" for why. Blank is allowed
 * (no image); {@code @URL} treats an empty string as valid, so no separate optional-handling is needed.
 */
public class PostComposerRequest {

  @NotBlank(message = "Write something first")
  @Size(max = 500, message = "Keep it under 500 characters")
  private String content = "";

  @URL(message = "Enter a valid image URL")
  private String imageUrl = "";

  public String getContent() {
    return content;
  }

  public void setContent(String content) {
    this.content = content;
  }

  public String getImageUrl() {
    return imageUrl;
  }

  public void setImageUrl(String imageUrl) {
    this.imageUrl = imageUrl;
  }
}
