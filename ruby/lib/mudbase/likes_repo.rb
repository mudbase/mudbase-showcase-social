# frozen_string_literal: true

require "json"
require "set"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `likes` - one row per (postId, userId) pair. This collection type has
  # no compound unique index, so uniqueness is enforced at the application layer: every toggle
  # re-queries `{postId, userId}` immediately before creating/deleting (see
  # `PostsController#toggle_like` in app/routes/posts_routes.rb), a reasonable (not airtight)
  # guard against a double-click/double-tab race - the exact same check-then-act pattern as the
  # reference web app's `useToggleLike`.
  module LikesRepo
    # The generated SDK's `DataApi#list_data` client-side-validates `limit <= 100` (a hard
    # platform cap, confirmed live) - this is the real ceiling on how many of a user's own likes
    # can be fetched in one page, not just a demo-scale choice.
    MINE_LIMIT = 100

    def self.find_one(access_token:, post_id:, user_id:)
      opts = { filter: { postId: post_id, userId: user_id }.to_json, limit: 1 }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.likes_collection_id,
        opts,
      )
      (data[:data] || []).first
    end

    # @return [Set<String>] postIds the given user has liked, bounded to `MINE_LIMIT` - used to
    #   render the like button's initial state across a whole feed page with one query instead
    #   of one per post, mirroring `web/src/hooks/useLikes.ts#useMyLikedPostIds`.
    def self.liked_post_ids(access_token:, user_id:)
      opts = { filter: { userId: user_id }.to_json, limit: MINE_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.likes_collection_id,
        opts,
      )
      (data[:data] || []).filter_map { |like| like[:postId] }.to_set
    end

    def self.create!(access_token:, post_id:, user_id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.likes_collection_id,
        { postId: post_id, userId: user_id },
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.delete!(access_token:, id:)
      Mudbase::ClientFactory.data_api(access_token: access_token).delete_data(
        Mudbase::Config.project_id,
        Mudbase::Config.likes_collection_id,
        id,
      )
    end
  end
end
