package dev.mudbase.showcase.social.mudbase;

import java.util.List;

/**
 * One page of a Mudbase collection list call, carrying the pagination metadata the feed's
 * "load more" link and the profile page's follower/following/post counts both need -
 * {@code total} in particular, read from a {@code limit:1} query rather than pulling every row
 * (see {@code MudbaseDataClient#count}, mirroring the reference web app's own
 * {@code useFollowCounts}/{@code useProfileStats} approach of reading {@code pagination.total}).
 */
public record PageResult<T>(List<T> items, int page, int limit, long total, boolean hasMore) {

  public static <T> PageResult<T> empty(int page, int limit) {
    return new PageResult<>(List.of(), page, limit, 0, false);
  }
}
