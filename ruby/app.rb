# frozen_string_literal: true

require "dotenv/load"
require "set"
require "uri"
require "sinatra/base"

require_relative "lib/mudbase/config"
require_relative "lib/mudbase/client_factory"
require_relative "lib/mudbase/errors"
require_relative "lib/mudbase/auth_service"
require_relative "lib/mudbase/posts_repo"
require_relative "lib/mudbase/comments_repo"
require_relative "lib/mudbase/likes_repo"
require_relative "lib/mudbase/follows_repo"
require_relative "lib/mudbase/profile_repo"
require_relative "lib/session_helpers"
require_relative "lib/view_helpers"

# Field Notes - a realtime-feeling social micro-blog built entirely on Mudbase (auth, database),
# rendered server-side with Sinatra + ERB. This is the Ruby reimplementation of the reference
# Next.js app (see ../web) - same Mudbase project, same 4 collections, same field shapes,
# different stack, following the same Sinatra structure the sibling
# ../../mudbase-showcase-ecommerce/ruby port established.
class App < Sinatra::Base
  configure do
    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, "views")
    set :public_folder, File.join(settings.root, "public")
    set :show_exceptions, false
    set :raise_errors, false

    is_production = ENV.fetch("RACK_ENV", "development") == "production"
    set :session_secret, Mudbase::Config.session_secret
    set :sessions, {
      key: "mudbase_showcase_social.session",
      httponly: true,
      same_site: :lax,
      secure: is_production,
      expire_after: 60 * 60 * 12,
    }
  end

  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  helpers SessionHelpers
  helpers ViewHelpers

  before do
    @flash_notice = pop_flash_notice
    @flash_error = pop_flash_error
    @current_user = current_user
  end

  # `MudbaseSDK::ApiError` is what every generated API call raises on a non-2xx response
  # (invalid input, expired token, permission denial, etc.) - surfaced here as a flash-style
  # error banner instead of a raw 500, matching "never silently swallow errors" while still
  # giving the visitor something actionable.
  error MudbaseSDK::ApiError do
    failure = Mudbase::ApiFailure.from(env["sinatra.error"])
    if failure.status == 401
      clear_auth_session!
      flash_error("Your session expired - please sign in again.")
      redirect "/login"
    else
      flash_error(failure.friendly_message)
      redirect back_or("/")
    end
  end

  error Mudbase::MissingEnvError do
    content_type :text
    status 500
    "Server misconfigured: #{env['sinatra.error'].message}"
  end

  # Raised by `ensure_guest_session!`/`with_read_token` when even establishing a silent
  # anonymous session fails (Mudbase's own auth-endpoint rate limiting, or a real outage) - not
  # a `MudbaseSDK::ApiError` since `AuthService` normalizes it to this app-level error type.
  # Rendered directly (not redirected) since the failure can happen on `/` itself, where a
  # `redirect back_or("/")` could loop.
  error Mudbase::AuthError do
    @flash_error = "Couldn't reach Mudbase right now - please try again in a moment."
    erb :"errors/server_error", layout: :layout
  end

  not_found do
    erb :"errors/not_found", layout: :layout
  end

  error do
    logger.error(env["sinatra.error"]&.full_message) if env["sinatra.error"]
    erb :"errors/server_error", layout: :layout
  end

  helpers do
    def back_or(default_path)
      request.referrer && URI.parse(request.referrer).path != request.path ? request.referrer : default_path
    rescue URI::InvalidURIError
      default_path
    end

    # The signed-in user's own liked-post ids (bounded, see LikesRepo::MINE_LIMIT), fetched at
    # most once per request and reused by every like button rendered on the page - avoids one
    # query per post. Empty for a guest (a guest cannot have liked anything).
    def my_liked_post_ids
      return @my_liked_post_ids if defined?(@my_liked_post_ids)

      @my_liked_post_ids = if logged_in?
        with_access_token { |token| Mudbase::LikesRepo.liked_post_ids(access_token: token, user_id: @current_user[:id]) }
      else
        Set.new
      end
    end

    # Same rationale as `my_liked_post_ids`, for follow buttons.
    def my_following_ids
      return @my_following_ids if defined?(@my_following_ids)

      @my_following_ids = if logged_in?
        with_access_token { |token| Mudbase::FollowsRepo.following_ids(access_token: token, follower_id: @current_user[:id]) }
      else
        Set.new
      end
    end
  end
end

require_relative "app/routes/auth_routes"
require_relative "app/routes/feed_routes"
require_relative "app/routes/posts_routes"
require_relative "app/routes/profile_routes"
