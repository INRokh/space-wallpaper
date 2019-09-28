require "date"
require_relative "nasa_apod"

class FakeClient
    def load_image(date, file_path)
        if date == Date.parse("2019-09-27")
            raise UnsupportedMediaType 
        elsif date == Date.parse("2019-09-26")
            return "2019-09-26", "fake_title", "fake_explanation"
        end
        return "", "", ""
    end
end

fake_client = FakeClient.new

fake_client.load_image(Date.parse("2019-09-26"), "")

if load_latest_skipping_video(fake_client, Date.parse("2019-09-27"), "") != ["2019-09-26", "fake_title", "fake_explanation"]
    p "Test failed"
else
    p "OK"
end



