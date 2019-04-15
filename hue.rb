require "rubygems"
require "bundler/setup"

ROOM = "Stuart’s Room"
LATITUDE = 43.156578
LONGITUDE = -77.608849
START_TEMP = 200
END_TEMP = 500
SECONDS = 10

Bundler.require(:default)

class Client
  def initialize
    @client = Hue::Client.new("stuartolivera")
  end

  def room
    @_room ||= @client.groups.find { |room| room.name == ROOM }
  end

  def lights
    room.lights
  end

  def set_temp(target_temp, interval_size = 15)
    first_temp = target_temp - (lights.count / 2 * interval_size)
    lights.each_with_index do |light, index|
      temp = first_temp + (index * interval_size)
      light.set_state({ color_temperature: temp }, 1 * SECONDS)
    end
    target_temp
  end

  def set_daytime_temp(datetime)
    date = datetime.to_date
    rise, transit, set = Solar.passages(date, LONGITUDE, LATITUDE)
    elevation, _ = Solar.position(datetime, LONGITUDE, LATITUDE)
    rise_elevation, _ = Solar.position(rise, LONGITUDE, LATITUDE)
    transit_elevation, _ = Solar.position(transit, LONGITUDE, LATITUDE)
    set_elevation, _ = Solar.position(set, LONGITUDE, LATITUDE)

    if date < transit
      progress = (transit_elevation - elevation) / (transit_elevation - rise_elevation)
    else
      progress = (transit_elevation - elevation) / (transit_elevation - set_elevation)
    end
    target_temp = ((END_TEMP - START_TEMP) * progress) + START_TEMP
    target_temp = target_temp.to_int
    set_temp(target_temp)
  end
end

client = Client.new

time_start = nil
Time.use_zone("America/New_York") do
  time_start = Time.zone.at(Date.today.beginning_of_day) + 6.hours
end

(1..18).each do |step|
  date = time_start + (1.hour * step)
  print "Running at #{date}"
  set_temp = client.set_daytime_temp(date)
  print " set to #{set_temp}"
  puts
  sleep 1
end
