# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `posts` (public read for any authenticated-or-guest token; `customer`
  # role create/update, ownership enforced by the app - Mudbase's collection permissions grant
  # `dataScope: "all"`, so this app's own routes are what keep an update scoped to the post's
  # actual author, e.g. only ever patching `likesCount`/`commentsCount`, never someone else's
  # post body). All calls force `debug_return_type: "Object"` (see ClientFactory) so every real
  # document field survives - the generated `DataListResponseDataInner` model only types
  # `_id`/`created_at`/`updated_at`.
  module PostsRepo
    DEFAULT_PAGE_SIZE = 10

    # @return [Hash] `{ posts: [Hash], pagination: Hash }` - `pagination` carries
    #   `page`/`limit`/`total`/`totalPages`/`hasMore` exactly as the wire response does.
    def self.feed(access_token:, page: 1, limit: DEFAULT_PAGE_SIZE)
      opts = { sort: "-createdAt", page: page, limit: limit }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.posts_collection_id,
        opts,
      )
      { posts: data[:data] || [], pagination: data[:pagination] || {} }
    end

    def self.list_by_author(access_token:, author_id:, limit: 100)
      opts = { filter: { authorId: author_id }.to_json, sort: "-createdAt", limit: limit }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.posts_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.posts_collection_id,
        id,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    rescue MudbaseSDK::ApiError => e
      raise e unless Mudbase::ApiFailure.from(e).status == 404

      nil
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.posts_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.posts_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end
  end
end
