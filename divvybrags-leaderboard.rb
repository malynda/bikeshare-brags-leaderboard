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
  "{ 1 : #{LeaderboardPost.get(1).name} }"
end

post '/new_entry' do
  new_post = LeaderboardPost.new
  new_post.name = "Alex"
  new_post.miles = 400
  new_post.save
end

post '/new_entry' do
  new_post = LeaderboardPost.new
  new_post.name = "Alex"
  new_post.miles = 400
  new_post.save
end
