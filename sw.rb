require "faraday"
require "json"
require "date"
require 'optparse'
require "colorize"

# Creat own custom exceptions, subclass of StandardError.
class UnsupportedMediaType < StandardError
end

class NasaClient
    APOD_URL = "https://api.nasa.gov/planetary/apod" 
    def initialize(conn, api_key)
        @conn = conn
        @api_key = api_key

        # Initial request to check connection and API key.
        url = "#{APOD_URL}?api_key=#{@api_key}"
        response = @conn.get(url)  
        h = JSON.parse(response.body)
        if h.key?("error") and h["error"]["code"] == "API_KEY_INVALID"
            raise ArgumentError, "Invalid API key."
        end
    end

    # Download image. 
    def load_image(date, file_path)
        url = "#{APOD_URL}?api_key=#{@api_key}&hd=True&date=#{date}"
        response = @conn.get(url)  
        h = JSON.parse(response.body)
        if h.key?("error") and h["error"]["code"] == "API_KEY_INVALID"
            raise ArgumentError, "Invalid API key."
        end
        if h["media_type"] != "image"
            raise UnsupportedMediaType
        end
        if h["hdurl"].nil?
            raise ArgumentError, "Image URL not found in APOD response."
        end
        image_response = @conn.get(h["hdurl"])
        File.open(file_path, 'wb') {|fp| fp.write(image_response.body)}
        return h["date"], h["title"], h["explanation"]
    end
end

# Change wallpaper
def change_OSX_wallpaper(image_path)
    path = File.absolute_path(image_path)
    system("osascript -e 'tell application \"Finder\" to set desktop picture to POSIX file \"#{path}\"'")
    system("Killall Dock")
end

# Return random date from range
def random_picture
    date_from = Time.new(1995,6,22)
    random_date = Time.at(date_from + rand * (Time.now.to_f - date_from.to_f)).strftime("%Y-%m-%d")
    return random_date
end

# Parse user's input date
def parse_date(str)
    return DateTime.parse(str).strftime("%Y-%m-%d")
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
    date = ""
    begin
        if answ == "l"
            date = ""
        elsif answ == "r"
            date = random_picture()  
        else
            date = parse_date(answ)  
        end
    rescue ArgumentError
        puts "Invalid command, use l - latest image, r - radom image, q - to exit or date in format YYYY-MM-DD."
        next
    end
    image_name = "image.jpg"
    puts "Loading image" 
    begin
        date, title, explanation = apod.load_image(date, image_name)
        puts "Date: ".colorize(:color => :light_blue), date
        puts "Title: ".colorize(:color => :light_blue), title
        puts "Explanation: ".colorize(:color => :light_blue), explanation
        change_OSX_wallpaper(image_name)
    rescue UnsupportedMediaType
        puts "No image for this date." 
        next
    end
end