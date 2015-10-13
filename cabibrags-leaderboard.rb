require "rubygems"
require "sinatra"
require "data_mapper"
require "pg"
require "dm-postgres-adapter"
require "sinatra/json"

disable :protection             # This was messing with the iframing

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_PURPLE_URL'] || 'postgres://localhost/leaderboard')

class LeaderboardPost
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :miles, Integer
  property :city, String
  property :flag, Boolean
end

DataMapper.finalize
DataMapper.auto_upgrade!

def weed_out_duplicates_and_resort(posts)
  posts.group_by { |p| p.name }
    .sort_by { |name, posts| posts.max {|a,b| a.miles } }              # Sort any duplicate legacy posts for highest milage
    .map { |name, posts| posts[0] }                                    # Select highest milage post, weeding out duplicates
    .sort_by { |post| post.miles }.reverse                             # Resort
end

def render_leaderboard_json
  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])
  print @leaderboard
  @leaderboard_json, n = [], 1
  the_posts = weed_out_duplicates_and_resort(@leaderboard)
  the_posts.each do |p|
    @leaderboard_json << { n => { name: p.name, miles: p.miles } }
    n += 1
  end
  json @leaderboard_json
end

get "/entries.json" do            # JSON output for the Chrome extensions to consume

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])

  if params[:city] == "DC"
    @leaderboard_json, n = [], 1
    @leaderboard.each do |p|
      @leaderboard_json << { n => { :name => p.name, :miles => p.miles} }
      n += 1
    end
    json @leaderboard_json
  end
end


get "/entries/:city/" do          # HTML output for the static site iframe

  @leaderboard = LeaderboardPost.all(order: [:miles.desc], city: params[:city])  # Return leaderboard for the right city
  n = 1
  sinatra_html = '<link rel="stylesheet" href="/assets/main.css">'
  @leaderboard.each do |p|
    post_html = n.to_s + ". " + p.name + ": " + p.miles.to_s + "mi<br>"
    sinatra_html += post_html
    n += 1
  end
  sinatra_html

end

post '/new_entry' do

  new_post = LeaderboardPost.new(params[:leaderboard_post])

  if new_post.flag == true
    new_post.save
  else
    post_to_update = LeaderboardPost.first(name: new_post.name)
    post_to_update.miles = new_post.miles
    post_to_update.save
  end
  render_leaderboard_json
end
