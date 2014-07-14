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
  property :extra_unique_id, Integer, :min => 0, :max => 999999999999
  property :city, String
  property :month, String
  property :year, Integer
end

DataMapper.finalize
DataMapper.auto_upgrade!

get "/entries.json" do            # JSON output for the Chrome extensions to consume

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])

  if params[:city] == "Chicago"
    @leaderboard_json, n = [], 1
    @leaderboard.each do |p|
      @leaderboard_json << { n => { :name => p.name, :miles => p.miles, :extra_unique_id => p.extra_unique_id } } 
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

get "/entries/:city/:timeperiod/" do          # HTML output for the static site iframe 

  if params[:city] == "NewYork"
    params_city = "New York"
  else
    params_city = params[:city]
  end

  sinatra_html = '<link rel="stylesheet" href="/assets/main.css">'

  if params[:timeperiod] == "alltime" 

    # Return the all-time highest biking totals.
    # With the Alta website change we need a better way to let users uniquely identify. 

    ranking_hash = {}  # initialize

    leaderboard_by_name = LeaderboardPost.all(city: params_city).group_by { |p| p.name }  
    # Grouping by name in line 76 is dependent on each user-selected name being unique.
    # Unrealistic in the long run, but works for now.
    top_bike_sharers = leaderboard_by_name.keys
    top_bike_sharers.each do |bs|
      this_persons_posts = leaderboard_by_name[bs]
      this_persons_miles = 0  # initialize
      this_persons_posts.each do |p|
        this_persons_miles += p.miles
      end
      ranking_hash[bs] = this_persons_miles
    end

    leaderboard_hash = ranking_hash.sort_by{|key, value| value}.reverse

    n = 1 
    leaderboard_hash.each do |p|
      name = p[0]
      miles = p[1].to_s
      post_html = n.to_s + ". " + name + ": " + miles + "mi<br>"
      sinatra_html += post_html
      n += 1
    end

  end

  if params[:timeperiod] == "monthly"     # Return bike rankings by month

    leaderboard, post_html = [], ""
    month_names =  ["December", "November", "October", "September", "August", "July", "June", "May", "April", "March", "February", "January"] 
    years = [2015, 2014, 2013]
    leaderboard_ranking = []
    years.each do |y|
      month_names.each do |m|
        month_posts = LeaderboardPost.all(city: params_city, month: m, year: y, order: [:miles.desc])
        month_ranking, n = [], 1
        month_posts.each do |p|
          month_ranking << { n => { name: p.name, miles: p.miles } }
          n +=1
        end
        if month_ranking.length > 0
          leaderboard << { "#{m} #{y}" => month_ranking }
        end
      end
    end

    leaderboard.each do |m|
      month_name = m.keys[0]
      month_html = "<h5>" + month_name + "</h5><br/>";
      this_month_rankings = m[month_name]
      this_month_rankings.each do |ranking|
        rank_number = ranking.keys[0]
        rank_holder_deatails = ranking[rank_number]
        name = rank_holder_deatails[:name]
        miles = rank_holder_deatails[:miles]
        month_html += "<h10>" + rank_number.to_s + ". " + name + ": " + miles.to_s + "mi</h10><br/>";
      end
      sinatra_html += month_html
    end

  end 

  sinatra_html

end

post '/new_entry' do

  @leaderboard_post = params[:leaderboard_post]

  # Check to see if anyone has that extra unique ID in the database already
  @already_in_db = false
  LeaderboardPost.all.each do |p|
    if p.extra_unique_id == @leaderboard_post[:extra_unique_id].to_i
      p.miles = @leaderboard_post[:miles]
      if p.save
        @already_in_db = true
      end
    end
  end

  # If nobody's there with that extra unique id, then we know it's a new user!
  if @already_in_db == false
    new_post = LeaderboardPost.create(@leaderboard_post)
    new_post.save
  end

  # Now line up all the leaderboard posts and organize them by milage so we can return a new leaderboard
  
  # TODO: Put NYC and Chicago on the same system for returning leaderboard! 

  if @leaderboard_post[:city] == "Chicago"
    @new_leaderboard = LeaderboardPost.all(order: [:miles.desc], city: "Chicago")
    @leaderboard_ranking, n = [], 1
    @new_leaderboard.each do |p|
      @leaderboard_ranking << { n => { name: p.name, miles: p.miles } } 
      n += 1
    end
    # Pull out the leaderboard entry that's just been submitted as special
    @leaderboard_ranking.each do |p|
      if p[p.keys[0]][:name].strip.upcase == @leaderboard_post[:name].strip.upcase then @my_entry = p end
    end
  else
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
          @leaderboard_ranking << { "#{m} #{y}" => @month_ranking }
        end
      end
    end
    @my_entry = 0
  end

  json :leaderboard => @leaderboard_ranking, :my_entry => @my_entry

end