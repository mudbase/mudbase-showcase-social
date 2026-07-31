# frozen_string_literal: true

require_relative "posts_repo"
require_relative "follows_repo"

module Mudbase
  # There is no `users` collection in this data model (see `plan/build-plan.md` "Data model") -
  # every author/commenter/follower name is denormalized onto the row that references them
  # (`authorName`, `followingName`). `resolve_display_name` best-effort resolves a name for a
  # `/users/:user_id` profile page the same way the reference web app's
  # `useResolvedDisplayName` does: that user's most recent post's `authorName`, falling back to
  # any `followingName` recorded by someone who follows them, falling back to the literal string
  # "Member" if neither exists yet (e.g. a brand-new account that has only ever followed people,
  # never posted, and has no followers).
  module ProfileRepo
    def self.resolve_display_name(access_token:, user_id:)
      recent_posts = Mudbase::PostsRepo.list_by_author(access_token: access_token, author_id: user_id, limit: 1)
      from_post = recent_posts.first&.dig(:authorName)
      return from_post if from_post && !from_post.empty?

      from_follow = Mudbase::FollowsRepo.any_recorded_name(access_token: access_token, user_id: user_id)
      return from_follow if from_follow && !from_follow.empty?

      "Member"
    end
  end
end
