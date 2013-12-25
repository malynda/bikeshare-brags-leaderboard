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

post '/new_entry' do
  
  new_post = LeaderboardPost.first_or_create(:name => params[:name])
  new_post.miles = params[:miles]
  new_post.save

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc])
  @leaderboard_json = []
  n = 1

  @leaderboard.each do |p|
    @leaderboard_json << { n => { :name => p.name, :miles => p.miles } } 
    n += 1
  end

  json @leaderboard_json
  
end