require "rubygems"
require "sinatra"
require "data_mapper"

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

class LeaderboardPost
  include DataMapper::Resource
  property :id,    Serial
  property :name, String
  property :miles, Integer
end

get "/entries.json" do
  # check to see if sinatra has some built-in json tools you should use
  "{ 1 : #{LeaderboardPost.get(1).name} }"
end

post '/new_entry' do
  new_post = LeaderboardPost.new
  # check first to see if the name is already in the database. if so, update miles.
  new_post.name = params[:name]
  new_post.miles = params[:miles]
  new_post.save
  # send back the entire list so the sidebar can update the leaderboard! 
end