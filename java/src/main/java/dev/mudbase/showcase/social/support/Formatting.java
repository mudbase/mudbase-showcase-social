package dev.mudbase.showcase.social.support;

import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;

/** Formatting helpers shared by domain objects and templates - mirrors src/lib/utils.ts. */
public final class Formatting {

  private static final DateTimeFormatter DISPLAY_DATE =
      DateTimeFormatter.ofPattern("MMM d, yyyy 'at' h:mm a", Locale.US);

  private Formatting() {}

  /**
   * A short relative timestamp ("3m", "5h", "2d") for recent posts/comments, falling back to an
   * absolute date once something is more than a week old - keeps the feed scannable the same way
   * the reference web app's PostCard formats `createdAt`.
   */
  public static String formatDate(String iso) {
    if (iso == null || iso.isBlank()) {
      return "";
    }
    try {
      OffsetDateTime parsed = OffsetDateTime.parse(iso);
      Duration elapsed = Duration.between(parsed.toInstant(), Instant.now());
      if (elapsed.isNegative() || elapsed.toDays() >= 7) {
        return parsed.format(DISPLAY_DATE);
      }
      if (elapsed.toDays() >= 1) {
        return elapsed.toDays() + "d";
      }
      if (elapsed.toHours() >= 1) {
        return elapsed.toHours() + "h";
      }
      if (elapsed.toMinutes() >= 1) {
        return elapsed.toMinutes() + "m";
      }
      return "just now";
    } catch (DateTimeParseException e) {
      return iso;
    }
  }
}
