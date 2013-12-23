require "rubygems"
require "sinatra"
require "data_mapper"
require "pg"
require "dm-postgres-adapter"
require "json"

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_TEAL_URL'] || 'postgres://localhost/leaderboard')

class LeaderboardPost
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :miles, Integer
end

DataMapper.finalize.auto_upgrade!

LeaderboardPost.create(
  :name => "Alex",
  :miles => 200
)

get "/entries.json" do
  content_type :json
  { 1 : LeaderboardPost.get(1).name }.to_json
end

post '/new_entry' do
  new_post = LeaderboardPost.first_or_create(:name => params[:name])
  new_post.miles = params[:miles]
  new_post.save
  # send back the entire list so the sidebar can update the leaderboard! 
end

get "/" do
  "Hello, world!"
end 