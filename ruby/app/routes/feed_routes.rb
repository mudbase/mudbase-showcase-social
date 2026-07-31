# frozen_string_literal: true

# The public feed: paginated, readable by anyone (a guest gets a silent anonymous session via
# `with_read_token` - see `lib/session_helpers.rb`). Posting requires a real signed-in account;
# Mudbase's own collection permissions (customer-only create) are the actual security boundary,
# this route's `require_login!` is UX gating that avoids a guest ever seeing a raw 403.
class App < Sinatra::Base
  CONTENT_MAX_LENGTH = 500

  get "/" do
    @page = [params["page"].to_i, 1].max
    result = with_read_token { |token| Mudbase::PostsRepo.feed(access_token: token, page: @page) }
    @posts = result[:posts]
    @pagination = result[:pagination]
    @content = ""
    @image_url = ""

    erb :"feed/index"
  end

  post "/posts" do
    require_login!

    @content = params["content"].to_s.strip
    @image_url = params["image_url"].to_s.strip
    @page = 1

    errors = validate_post(@content, @image_url)
    if errors.any?
      show_error_now(errors.join(" "))
      result = with_read_token { |token| Mudbase::PostsRepo.feed(access_token: token, page: 1) }
      @posts = result[:posts]
      @pagination = result[:pagination]
      halt erb(:"feed/index")
    end

    author_name = "#{@current_user[:firstName]} #{@current_user[:lastName]}".strip
    attributes = {
      authorId: @current_user[:id],
      authorName: author_name,
      content: @content,
      likesCount: 0,
      commentsCount: 0,
    }
    attributes[:imageUrl] = @image_url unless @image_url.empty?

    with_access_token { |token| Mudbase::PostsRepo.create!(access_token: token, attributes: attributes) }
    flash_notice("Posted!")
    redirect "/"
  end

  helpers do
    def validate_post(content, image_url)
      errors = []
      errors << "Write something before posting." if content.empty?
      errors << "Posts are limited to #{CONTENT_MAX_LENGTH} characters." if content.length > CONTENT_MAX_LENGTH
      errors << "That doesn't look like a valid image URL." unless image_url.empty? || image_url.match?(%r{\Ahttps?://})
      errors
    end
  end
end
