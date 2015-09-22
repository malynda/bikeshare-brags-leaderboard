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
  # property :year, Integer
  property :flag, Boolean
end

DataMapper.finalize
DataMapper.auto_upgrade!

get "/entries.json" do            # JSON output for the Chrome extensions to consume

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])

  if params[:city] == "DC"
    @leaderboard_json, n = [], 1
    @leaderboard.each do |p|
      @leaderboard_json << { n => { :name => p.name, :miles => p.miles} }
      n += 1
    end
    json @leaderboard_json
  elsif params[:city] == "New York"
    @leaderboard_json = []
    month_names =  ["December", "November", "October", "September", "August", "July", "June", "May", "April", "March", "February", "January"]
    years = [2015, 2014, 2013]
    @leaderboard_ranking = []
    years.each do |y|
      month_names.each do |m|
        @month_posts = LeaderboardPost.all(month: m, year: y, order: [:miles.desc])
        @month_ranking, n = [], 1
        @month_posts.each do |p|
          @month_ranking << { n => { name: p.name, miles: p.miles } }
          n +=1
        end
        if @month_ranking.length > 0
          @leaderboard_json << { "#{m} #{y}" => @month_ranking }
        end
      end
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

  if new_post.flag == false
    new_post.save
  else
    post_to_update = LeaderboardPost.first(name: new_post.name)
    post_to_update.miles = new_post.miles
    post_to_update.save
  end
  render_leaderboard_json

####################################
  # @leaderboard_post = params[:leaderboard_post]
  #
  # # Check to see if anyone has that extra unique ID in the database already
  # @already_in_db = false
  # LeaderboardPost.all.each do |p|
  #   if p.extra_unique_id == @leaderboard_post[:extra_unique_id].to_i
  #     p.miles = @leaderboard_post[:miles]
  #     if p.save
  #       @already_in_db = true
  #     end
  #   end
  # end
  #
  # # If nobody's there with that extra unique id, then we know it's a new user!
  # if @already_in_db == false
  #   new_post = LeaderboardPost.create(@leaderboard_post)
  #   new_post.save
  # end

  # Now line up all the leaderboard posts and organize them by milage so we can return a new leaderboard
  # if @leaderboard_post[:city] == "DC"
  #   @new_leaderboard = LeaderboardPost.all(order: [:miles.desc], city: "DC")
  #   @leaderboard_ranking, n = [], 1
  #   @new_leaderboard.each do |p|
  #     @leaderboard_ranking << { n => { name: p.name, miles: p.miles } }
  #     n += 1
  #   end
  #   # Pull out the leaderboard entry that's just been submitted as special
  #   @leaderboard_ranking.each do |p|
  #     if p[p.keys[0]][:name].strip.upcase == @leaderboard_post[:name].strip.upcase then @my_entry = p end
  #   end
  # else
  #   month_names =  ["December", "November", "October", "September", "August", "July", "June", "May", "April", "March", "February", "January"]
  #   years = [2015, 2014, 2013]
  #   @leaderboard_ranking = []
  #   years.each do |y|
  #     month_names.each do |m|
  #       @month_posts = LeaderboardPost.all(month: m, year: y, order: [:miles.desc])
  #       @month_ranking, n = [], 1
  #       @month_posts.each do |p|
  #         @month_ranking << { n => { name: p.name, miles: p.miles } }
  #         n +=1
  #       end
  #       if @month_ranking.length > 0
  #         @leaderboard_ranking << { "#{m} #{y}" => @month_ranking }
  #       end
  #     end
  #   end
  #   @my_entry = 0
  # end
  #
  # json :leaderboard => @leaderboard_ranking, :my_entry => @my_entry

end

def render_leaderboard_json

  leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])
  leaderboard_json = []
  # month_names =  ["December", "November", "October", "September", "August", "July", "June", "May", "April", "March", "February", "January"]
  # years = [2015, 2014, 2013]
  # leaderboard_ranking = []
  # years.each do |y|
  #   month_names.each do |m|
  #     month_posts = LeaderboardPost.all(month: m, year: y, order: [:miles.desc])
  #     sorted_posts = weed_out_duplicates_and_resort(month_posts)
  #     month_ranking, n = [], 1
  #     sorted_posts.each do |p|
  #       month_ranking << { n => { name: p.name, miles: p.miles } }
  #       n +=1
  #     end
  #     if month_ranking.length > 0
  #       leaderboard_json << { "#{m} #{y}" => month_ranking }
  #     end
  #   end
  # end
  the_posts = weed_out_duplicates_and_resort(leaderboard)
  n = 1
  the_posts.each do |p|
    leaderboard_json << { n => { name: p.name, miles: p.miles } }
    n += 1
  end
  # json leaderboard_json
  json the_posts
end

def weed_out_duplicates_and_resort(posts)
  posts.group_by { |p| p.name }
    .sort_by { |name, posts| posts.max {|a,b| a.miles } }              # Sort any duplicate legacy posts for highest milage
    .map { |name, posts| posts[0] }                                    # Select highest milage post, weeding out duplicates
    .sort_by { |post| post.miles }.reverse                             # Resort
end
