require "json"
require "date"

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
        url = "#{APOD_URL}?api_key=#{@api_key}&hd=True&date=#{date.strftime("%Y-%m-%d")}"
        # Send HTTP get request.
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

# Loads latest image and skips videos.
def load_latest_skipping_video(client, date, file_path)
    for e in 0..2
        begin
            return client.load_image(date, file_path)
        rescue UnsupportedMediaType
            date = date - 1
        end
    end
    raise UnsupportedMediaType 
end

# Loads random image and skips videos.
def load_random_skipping_video(client, file_path)
    date = random_picture
    for e in 0..2
        begin
            return client.load_image(date, file_path)
        rescue UnsupportedMediaType
            date = random_picture
        end
    end
    raise UnsupportedMediaType 
end

# Return random date from range
def random_picture
    date_from = Time.new(1995,6,22)
    random_date = Time.at(date_from + rand * (Time.now.to_f - date_from.to_f))
    return random_date
end