require "rubygems"
require "sinatra"
require "data_mapper"
require "pg"
require "dm-postgres-adapter"
require "sinatra/json"

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_TEAL_URL'] || 'postgres://localhost/leaderboard')

class LeaderboardPost
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :miles, Integer
end

DataMapper.finalize.auto_upgrade!

get "/entries.json" do

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc])
  @leaderboard_json = []
  n = 1

  @leaderboard.each do |p|
    @leaderboard_json << { n => { :name => p.name, :miles => p.miles } } 
    n += 1
  end

  json @leaderboard_json

end

get "/entries" do

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc])
  n = 1
  sinatra_html = ''
  @leaderboard.each do |p|
    post_html = n.to_s + ". " + p.name + ": " + p.miles.to_s + "<br>"
    sinatra_html += post_html
    n += 1
  end

  sinatra_html

end

post '/new_entry' do

  # Check to see if anyone has a similar name in the database already. 
  
  @already_in_db = false

  LeaderboardPost.all.each do |p|
    if p.name.strip.upcase == params[:name].strip.upcase
      p.miles = params[:miles]
      if p.save
        @already_in_db = true
      end
    end
  end

  # If nobody's taken that name yet, make a new entry in the database

  if @already_in_db == false
    new_post = LeaderboardPost.create(:name => params[:name], :miles => params[:miles])
    new_post.save
  end

  # Now line up all the leaderboard posts and organize them by milage so we can return a new leaderboard

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc])
  @leaderboard_ranking = []
  n = 1

  @leaderboard.each do |p|
    @leaderboard_ranking << { n => { :name => p.name, :miles => p.miles } } 
    n += 1
  end

  # Pull out the leaderboard entry that's just been submitted as special

  @leaderboard_ranking.each do |p|
    if p[p.keys[0]][:name].strip.upcase == params[:name].strip.upcase then @my_entry = p end
  end

  json :leaderboard => @leaderboard_ranking, :my_entry => @my_entry

end