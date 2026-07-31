# frozen_string_literal: true

# Profile page: resolved display name (see `lib/mudbase/profile_repo.rb` - there is no `users`
# collection), follower/following counts, that user's posts, and a follow/unfollow button
# (hidden on your own profile). Reads are public; following requires a real signed-in account.
class App < Sinatra::Base
  get "/profile" do
    require_login!
    redirect "/users/#{@current_user[:id]}"
  end

  get "/users/:user_id" do
    @profile_user_id = params["user_id"]

    @display_name = with_read_token { |token| Mudbase::ProfileRepo.resolve_display_name(access_token: token, user_id: @profile_user_id) }
    @posts = with_read_token { |token| Mudbase::PostsRepo.list_by_author(access_token: token, author_id: @profile_user_id) }
    @follower_count = with_read_token { |token| Mudbase::FollowsRepo.follower_count(access_token: token, user_id: @profile_user_id) }
    @following_count = with_read_token { |token| Mudbase::FollowsRepo.following_count(access_token: token, user_id: @profile_user_id) }
    @is_own_profile = logged_in? && @current_user[:id] == @profile_user_id
    @is_following = my_following_ids.include?(@profile_user_id)

    erb :"profile/show"
  end

  post "/users/:user_id/follow" do
    require_login!

    target_id = params["user_id"]
    current_id = @current_user[:id]
    halt 400, erb(:"errors/server_error", layout: :layout) if target_id == current_id

    target_name = with_access_token { |token| Mudbase::ProfileRepo.resolve_display_name(access_token: token, user_id: target_id) }

    with_access_token do |token|
      existing = Mudbase::FollowsRepo.find_one(access_token: token, follower_id: current_id, following_id: target_id)
      if existing
        Mudbase::FollowsRepo.delete!(access_token: token, id: existing[:_id])
      else
        Mudbase::FollowsRepo.create!(access_token: token, follower_id: current_id, following_id: target_id, following_name: target_name)
      end
    end

    redirect "/users/#{target_id}"
  end
end
