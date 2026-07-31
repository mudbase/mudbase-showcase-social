# frozen_string_literal: true

require "json"
require "set"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `follows` - one row per (followerId, followingId) pair, same
  # application-layer uniqueness guard as `LikesRepo` (no compound unique index on this
  # collection type either). `followingName` is denormalized at write time (see
  # `plan/build-plan.md` "Data model" - there is no `users` collection to look a name up from
  # later).
  module FollowsRepo
    # The generated SDK's `DataApi#list_data` client-side-validates `limit <= 100` (a hard
    # platform cap, confirmed live) - this is the real ceiling on how many of a user's own
    # follows can be fetched in one page, not just a demo-scale choice.
    MINE_LIMIT = 100

    def self.find_one(access_token:, follower_id:, following_id:)
      opts = { filter: { followerId: follower_id, followingId: following_id }.to_json, limit: 1 }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        opts,
      )
      (data[:data] || []).first
    end

    # @return [Set<String>] followingIds for the given follower - used to render every
    #   FollowButton on a feed/profile page with one query, mirroring
    #   `web/src/hooks/useFollows.ts#useMyFollowingIds`.
    def self.following_ids(access_token:, follower_id:)
      opts = { filter: { followerId: follower_id }.to_json, limit: MINE_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        opts,
      )
      (data[:data] || []).filter_map { |follow| follow[:followingId] }.to_set
    end

    def self.create!(access_token:, follower_id:, following_id:, following_name:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        { followerId: follower_id, followingId: following_id, followingName: following_name },
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.delete!(access_token:, id:)
      Mudbase::ClientFactory.data_api(access_token: access_token).delete_data(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        id,
      )
    end

    # Counts read via `pagination.total` on a `limit: 1` query rather than pulling every row -
    # cheap, correct regardless of how many rows exist. Mirrors
    # `web/src/hooks/useProfileStats.ts#useFollowCounts`.
    def self.follower_count(access_token:, user_id:)
      opts = { filter: { followingId: user_id }.to_json, limit: 1 }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        opts,
      )
      (data[:pagination] || {})[:total] || 0
    end

    def self.following_count(access_token:, user_id:)
      opts = { filter: { followerId: user_id }.to_json, limit: 1 }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        opts,
      )
      (data[:pagination] || {})[:total] || 0
    end

    # Any `followingName` recorded by someone who follows this user - a fallback source of
    # display name when the user has never posted (see `ProfileRepo.resolve_display_name`).
    def self.any_recorded_name(access_token:, user_id:)
      opts = { filter: { followingId: user_id, followingName: { "$exists" => true, "$ne" => "" } }.to_json, limit: 1 }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.follows_collection_id,
        opts,
      )
      (data[:data] || []).first&.dig(:followingName)
    end
  end
end
