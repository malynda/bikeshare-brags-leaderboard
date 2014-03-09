require "rubygems"
require "sinatra"
require "data_mapper"
require "pg"
require "dm-postgres-adapter"
require "sinatra/json"

disable :protection             # This was messing with the iframing

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_TEAL_URL'] || 'postgres://localhost/leaderboard')

class LeaderboardPost
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :miles, Integer
  property :extra_unique_id, Integer
  property :city, String
  property :month, String
end

DataMapper.finalize
DataMapper.auto_upgrade!

get "/entries.json" do            # JSON output for the Chrome extensions to consume

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])
  @leaderboard_json = []
  n = 1

  @leaderboard.each do |p|
    @leaderboard_json << { n => { :name => p.name, :miles => p.miles, :extra_unique_id => p.extra_unique_id } } 
    n += 1
  end

  json @leaderboard_json

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

  # Check to see if anyone has that extra unique ID in the database already
  @already_in_db = false
  LeaderboardPost.all.each do |p|
    if p.extra_unique_id == params[:extra_unique_id].to_i
      p.miles = params[:miles]
      if p.save
        @already_in_db = true
      end
    end
  end

  # If nobody's there with that extra unique id, then we know it's a new user!
  if @already_in_db == false
    new_post = LeaderboardPost.create(name: params[:name], miles: params[:miles], extra_unique_id: params[:extra_unique_id], city: params[:city], month: params[:month])
    new_post.save
  end

  json :my_entry => new_post

  # # Now line up all the leaderboard posts and organize them by milage so we can return a new leaderboard
  # @leaderboard = LeaderboardPost.all(:order => [:miles.desc])
  # @leaderboard_ranking = []
  # n = 1
  # @leaderboard.each do |p|
  #   @leaderboard_ranking << { n => { name: p.name, miles: p.miles } } 
  #   n += 1
  # end

  # # Pull out the leaderboard entry that's just been submitted as special
  # @leaderboard_ranking.each do |p|
  #   if p[p.keys[0]][:name].strip.upcase == params[:name].strip.upcase then @my_entry = p end
  # end
  # json :leaderboard => @leaderboard_ranking, :my_entry => @my_entry

end