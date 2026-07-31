# frozen_string_literal: true

# Post detail (comments + like toggle). Reads are public (guest via `with_read_token`);
# commenting and liking require a real signed-in account, same UX-gating-over-real-enforcement
# split as `feed_routes.rb`.
class App < Sinatra::Base
  COMMENT_MAX_LENGTH = 300

  get "/posts/:id" do
    @post = with_read_token { |token| Mudbase::PostsRepo.find(access_token: token, id: params["id"]) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless @post

    @comments = with_read_token { |token| Mudbase::CommentsRepo.list_for_post(access_token: token, post_id: @post[:_id]) }
    @liked = my_liked_post_ids.include?(@post[:_id])
    @comment_content = ""

    erb :"posts/show"
  end

  post "/posts/:id/like" do
    require_login!

    post_id = params["id"]
    post = with_access_token { |token| Mudbase::PostsRepo.find(access_token: token, id: post_id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless post

    user_id = @current_user[:id]
    with_access_token do |token|
      existing = Mudbase::LikesRepo.find_one(access_token: token, post_id: post_id, user_id: user_id)
      if existing
        Mudbase::LikesRepo.delete!(access_token: token, id: existing[:_id])
        new_count = [post[:likesCount].to_i - 1, 0].max
        Mudbase::PostsRepo.update!(access_token: token, id: post_id, attributes: { likesCount: new_count })
      else
        Mudbase::LikesRepo.create!(access_token: token, post_id: post_id, user_id: user_id)
        new_count = post[:likesCount].to_i + 1
        Mudbase::PostsRepo.update!(access_token: token, id: post_id, attributes: { likesCount: new_count })
      end
    end

    redirect back_or("/posts/#{post_id}")
  end

  post "/posts/:id/comments" do
    require_login!

    post_id = params["id"]
    @comment_content = params["content"].to_s.strip

    if @comment_content.empty? || @comment_content.length > COMMENT_MAX_LENGTH
      flash_error(
        @comment_content.empty? ? "Write something before commenting." : "Comments are limited to #{COMMENT_MAX_LENGTH} characters.",
      )
      redirect "/posts/#{post_id}"
    end

    post = with_access_token { |token| Mudbase::PostsRepo.find(access_token: token, id: post_id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless post

    author_name = "#{@current_user[:firstName]} #{@current_user[:lastName]}".strip
    with_access_token do |token|
      Mudbase::CommentsRepo.create!(
        access_token: token,
        attributes: { postId: post_id, authorId: @current_user[:id], authorName: author_name, content: @comment_content },
      )
      Mudbase::PostsRepo.update!(access_token: token, id: post_id, attributes: { commentsCount: post[:commentsCount].to_i + 1 })
    end

    redirect "/posts/#{post_id}"
  end
end
