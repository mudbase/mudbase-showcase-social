# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `comments`. Read oldest-first (normal thread order, matching
  # `web/src/hooks/useComments.ts`'s `sort: "createdAt"`), bounded to 100 per post - the
  # generated SDK's `DataApi#list_data` client-side-validates `limit <= 100` (a hard platform
  # cap, confirmed live: passing 200 raises `ArgumentError` before any request is even sent), so
  # this is the real ceiling, not just a demo-scale choice.
  module CommentsRepo
    LIST_LIMIT = 100

    def self.list_for_post(access_token:, post_id:)
      opts = { filter: { postId: post_id }.to_json, sort: "createdAt", limit: LIST_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.comments_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.comments_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end
  end
end
