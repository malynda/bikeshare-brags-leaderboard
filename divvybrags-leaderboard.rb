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
  property :city, String
  property :month, String
  property :year, Integer
  property :flag, Boolean
end

DataMapper.finalize
DataMapper.auto_upgrade!

get "/entries.json" do            # JSON output for the Chrome extensions to consume

  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])
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

get "/entries/:city/:timeperiod/" do          # HTML output for the static site iframe 

  params[:city] == "NewYork" ? (params_city = "New York") : (params_city = params[:city])

  sinatra_html = '<link rel="stylesheet" href="/assets/main.css">'
  month_names =  ["December", "November", "October", "September", "August", "July", "June", "May", "April", "March", "February", "January"] 
  years = [2015, 2014, 2013]
  @leaderboard = LeaderboardPost.all(:order => [:miles.desc], city: params[:city])
  alltime_leaderboard, q = {}, 1

  years.each do |y|
    month_names.each do |m|
      if params[:timeperiod] == "monthly" 
        month_html = "<h5>" + m + "</h5><br/>"
        month_posts = @leaderboard.all(month: m, year: y, order: [:miles.desc])
        month_ranking, n = "", 1
        if month_posts.length > 0
          sinatra_html += "<h5>" + m + " " + y.to_s + "</h5><br/>"
          month_posts.each do |p|
            month_ranking += "<h10>" + n.to_s + ". " + p.name.to_s + ": " + p.miles.to_s + "mi</h10><br/>"
            n += 1
          end
          sinatra_html += month_ranking
        end
      elsif params[:timeperiod] == "alltime"
        month_posts = @leaderboard.all(month: m, year: y, order: [:miles.desc])
        .group_by { |p| p.name }
        .map { |key, value| value.max { |b| b.miles } }  # Weeding out any duplicates
        .map { |p| { p.name => p.miles } }
        .each do |month_post|
          name = month_post.keys[0]
          additional_miles = month_post[name]
          if alltime_leaderboard.keys.include? name
            alltime_leaderboard[name] += additional_miles
          else
            alltime_leaderboard[name] = additional_miles
          end
        end
      end
    end
  end
  
  alltime_leaderboard.each do |key, value|
    sinatra_html += "<h10>" + q.to_s + ". " + key.to_s + ": " + value.to_s + "mi</h10><br/>"
    q += 1
  end

  sinatra_html

end

post '/new_entry' do
    
  new_post = LeaderboardPost.new(params[:leaderboard_post])
  
  if new_post.flag == false
    new_post.save
  else
    post_to_update = LeaderboardPost.first(name: new_post.name, month: new_post.month, year: new_post.year)
    post_to_update.miles = new_post.miles
    post_to_update.save
  end

  # Now line up all the leaderboard posts and organize them by milage so we can return a new leaderboard
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

  json :leaderboard => @leaderboard_ranking, :my_entry => @my_entry

end