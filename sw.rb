require "faraday"
require "date"
require "optparse"
require "colorize"
require_relative "nasa_apod"

# Change wallpaper
def change_OSX_wallpaper(image_path)
    path = File.absolute_path(image_path)
    system("osascript -e 'tell application \"Finder\" to set desktop picture to POSIX file \"#{path}\"'")
    system("Killall Dock")
end

# Hash with retry settings. 
retry_options = {
    max: 3,  # Maximum retries count.
    interval: 1,  # Interval in secund.
    backoff_factor: 2,  # Interval increase function (e.g. 2^retries).
    exceptions: [Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed],  # Exceptions that are retried.
    retry_statuses: [429, 502, 503, 504]  # HTTP codes that are retried.
  }

# Initialize API conecion.
conn = Faraday.new do |conn|
    conn.request :retry, retry_options
    conn.adapter(:net_http)
end

api_key = ""
opts = OptionParser.new 
opts.banner = "Usage: ruby sw.rb [options]"
opts.on("-k", "--api_key API_KEY", "API key.") do |v|
  api_key = v
end
opts.parse!
ARGV.clear
if api_key == ""
    puts opts
    exit
end

# Create a new client.
apod = NasaClient.new(conn, api_key)
puts "Space Wallpaper changes desktop wallpaper using NASA picture of the day.".colorize(:color => :green)
while true
    puts "Commands:".colorize(:color => :light_blue)
    puts " l - latest image"
    puts " r - random image"
    puts " YYYY-MM-DD - image of specific date"
    puts " q - quit"
    print "> " 
    answ = gets.chomp 
    if answ == "q"
        break
    end
    image_name = "image.jpg"
    specific_date = nil
    begin
        if answ != "l" && answ != "r"
            specific_date = Date.parse(answ)
        end
    rescue ArgumentError
        puts "Invalid command, use l - latest image, r - radom image, q - to exit or date in format YYYY-MM-DD."
        next
    end
            
    begin
        date, title, explanation = "", "", ""
        case answ 
        when "l"
            date, title, explanation = load_latest_skipping_video(apod, Date.today - 1, image_name)
        when "r"
            date, title, explanation = load_random_skipping_video(apod, image_name)
        else 
            date, title, explanation = apod.load_image(specific_date, image_name)
        end
        puts "Loading image" 
        puts "Date: ".colorize(:color => :light_blue), date
        puts "Title: ".colorize(:color => :light_blue), title
        puts "Explanation: ".colorize(:color => :light_blue), explanation
        change_OSX_wallpaper(image_name)
    rescue UnsupportedMediaType
        puts "No image for this date." 
        next
    end
end