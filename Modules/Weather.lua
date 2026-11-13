
local weatherapi = {}
weatherapi.__index = weatherapi

function weatherapi.new(config)
    config = config or {}

    local self = setmetatable({}, weatherapi)

    self.players = game:GetService("Players")
    self.http = game:GetService("HttpService")
    self.input = game:GetService("UserInputService")
    self.run = game:GetService("RunService")
    self.tween = game:GetService("TweenService")
    self.stats = game:GetService("Stats")

    self.player = self.players.LocalPlayer
    self.playergui = self.player:WaitForChild("PlayerGui")
    self.request = request or http_request or (syn and syn.request)

    self.config = config
    self.latitude = config.Latitude or 26.3683
    self.longitude = config.Longitude or -80.1289
    self.timezone = config.Timezone or "America/New_York"
    self.unit = config.Unit or "fahrenheit"
    self.wind_unit = config.WindUnit or "mph"
    self.cache = config.Cache or "MirrorDashboardAssets"
    self.base_url = "https://raw.githubusercontent.com/mrdarrengriffin/google-weather-icons/main/sets/set-2/"
    self.refresh_interval = config.RefreshInterval or 300

    self.keybind = config.Keybind or Enum.KeyCode.G
    self.visible = config.Visible ~= false
    self.enabled = config.Enabled ~= false

    self.main_window = config.MainWindow
    self.follow_main = config.FollowMain == true
    self.offset = config.Offset or Vector2.new(340, 0)

    self.location = config.Location or {}
    self.location_display = self.location.Display or "City, State"
    self.city = self.location.City or "Boca Raton"
    self.state = self.location.State or "Florida"
    self.country = self.location.Country or "United States"

    self.theme_config = config.Theme or {}
    self.weather_theme = self.theme_config.Weather or "Sync"
    self.main_theme = self.theme_config.Main or "Sync"

    self.on_main_theme_update = config.OnMainThemeUpdate

    self.icon_cache = {}
    self.forecast_rows = {}
    self.effect_type = nil
    self.effect_folder = nil
    self.current_weather = nil
    self.utc_offset = -18000
    self.fps = 0
    self.frame_count = 0
    self.frame_elapsed = 0
    self.dragging = false
    self.star_loop = false
    self.animating = false
    self.visuals = {}
    self.connections = {}
    self.destroyed = false
    self.started = false

    self.colors = {
        bg = Color3.fromRGB(29, 30, 34),
        panel = Color3.fromRGB(36, 37, 42),
        white = Color3.fromRGB(239, 240, 244),
        muted = Color3.fromRGB(157, 160, 168),
        dim = Color3.fromRGB(112, 115, 123),
        line = Color3.fromRGB(57, 59, 66)
    }

    self.icon_files = {
        "sunny.png",
        "clear_night.png",
        "mostly_sunny.png",
        "mostly_clear_night.png",
        "partly_cloudy.png",
        "partly_cloudy_night.png",
        "mostly_cloudy_day.png",
        "mostly_cloudy_night.png",
        "cloudy.png",
        "haze_fog_dust_smoke.png",
        "drizzle.png",
        "showers_rain.png",
        "heavy_rain.png",
        "sleet_hail.png",
        "flurries.png",
        "heavy_snow.png",
        "snow_showers_snow.png",
        "scattered_showers_day.png",
        "scattered_showers_night.png",
        "isolated_scattered_tstorms_day.png",
        "isolated_scattered_tstorms_night.png",
        "strong_tstorms.png",
        "tornado.png",
        "blizzard.png"
    }

    self.weather_names = {
        [0] = "Clear sky",
        [1] = "Mostly clear",
        [2] = "Partly cloudy",
        [3] = "Overcast",
        [45] = "Fog",
        [48] = "Freezing fog",
        [51] = "Light drizzle",
        [53] = "Drizzle",
        [55] = "Heavy drizzle",
        [56] = "Freezing drizzle",
        [57] = "Freezing drizzle",
        [61] = "Light rain",
        [63] = "Rain",
        [65] = "Heavy rain",
        [66] = "Freezing rain",
        [67] = "Heavy freezing rain",
        [71] = "Light snow",
        [73] = "Snow",
        [75] = "Heavy snow",
        [77] = "Snow grains",
        [80] = "Rain showers",
        [81] = "Heavy showers",
        [82] = "Violent showers",
        [85] = "Snow showers",
        [86] = "Heavy snow showers",
        [95] = "Thunderstorm",
        [96] = "Thunderstorm with hail",
        [99] = "Severe thunderstorm"
    }

    if not self.request or not writefile or not getcustomasset then
        warn("Weather module requires request, writefile, and getcustomasset.")
        return nil
    end

    if makefolder and isfolder and not isfolder(self.cache) then
        pcall(makefolder, self.cache)
    end

    return self
end

function weatherapi:download_icon(filename)
    if self.icon_cache[filename] then
        return self.icon_cache[filename]
    end

    local path = self.cache .. "/" .. filename

    if not isfile or not isfile(path) then
        local response = self.request({
            Url = self.base_url .. filename,
            Method = "GET"
        })

        if not response or response.StatusCode ~= 200 then
            error("Failed to download " .. filename)
        end

        writefile(path, response.Body)
    end

    local asset = getcustomasset(path)
    self.icon_cache[filename] = asset

    return asset
end

function weatherapi:get_icon_file(code, is_day)
    if code == 0 then
        return is_day and "sunny.png" or "clear_night.png"
    elseif code == 1 then
        return is_day and "mostly_sunny.png" or "mostly_clear_night.png"
    elseif code == 2 then
        return is_day and "partly_cloudy.png" or "partly_cloudy_night.png"
    elseif code == 3 then
        return is_day and "mostly_cloudy_day.png" or "mostly_cloudy_night.png"
    elseif code == 45 or code == 48 then
        return "haze_fog_dust_smoke.png"
    elseif code >= 51 and code <= 57 then
        return "drizzle.png"
    elseif code >= 61 and code <= 65 then
        return code == 65 and "heavy_rain.png" or "showers_rain.png"
    elseif code == 66 or code == 67 then
        return "showers_rain.png"
    elseif code == 71 or code == 77 then
        return "flurries.png"
    elseif code == 73 or code == 75 then
        return "heavy_snow.png"
    elseif code >= 80 and code <= 82 then
        return is_day and "scattered_showers_day.png" or "scattered_showers_night.png"
    elseif code == 85 or code == 86 then
        return "snow_showers_snow.png"
    elseif code == 95 then
        return is_day and "isolated_scattered_tstorms_day.png" or "isolated_scattered_tstorms_night.png"
    elseif code == 96 or code == 99 then
        return "strong_tstorms.png"
    end

    return "cloudy.png"
end

function weatherapi:get(url)
    local response = self.request({
        Url = url,
        Method = "GET"
    })

    if not response or response.StatusCode ~= 200 then
        error("Weather request failed")
    end

    return self.http:JSONDecode(response.Body)
end

function weatherapi:fetch_weather()
    local url = string.format(
        "https://api.open-meteo.com/v1/forecast?latitude=%.5f&longitude=%.5f&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&forecast_days=5&timezone=%s&temperature_unit=%s&wind_speed_unit=%s",
        self.latitude,
        self.longitude,
        self.timezone,
        self.unit,
        self.wind_unit
    )

    local data = self:get(url)

    assert(data.current and data.daily, "Incomplete weather data")
    assert(data.daily.time and #data.daily.time >= 5, "Missing forecast")
    assert(data.daily.sunrise and data.daily.sunset, "Missing solar times")

    return data
end

function weatherapi:scale_position(pos)
    return UDim2.new(
        pos.X.Scale,
        math.floor(pos.X.Offset * (320 / 360)),
        pos.Y.Scale,
        pos.Y.Offset
    )
end

function weatherapi:scale_size(size)
    return UDim2.new(
        size.X.Scale,
        math.floor(size.X.Offset * (320 / 360)),
        size.Y.Scale,
        size.Y.Offset
    )
end

function weatherapi:label(parent, name, pos, size, value, font, text_size, color)
    local object = Instance.new("TextLabel")
    object.Name = name
    object.Position = self:scale_position(pos)
    object.Size = self:scale_size(size)
    object.BackgroundTransparency = 1
    object.BorderSizePixel = 0
    object.Text = value or ""
    object.Font = font or Enum.Font.Gotham
    object.TextSize = text_size or 14
    object.TextColor3 = color or self.colors.white
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.ZIndex = 5
    object.Parent = parent

    return object
end

function weatherapi:image(parent, name, pos, size, image, tint)
    local object = Instance.new("ImageLabel")
    object.Name = name
    object.Position = self:scale_position(pos)
    object.Size = self:scale_size(size)
    object.BackgroundTransparency = 1
    object.BorderSizePixel = 0
    object.ScaleType = Enum.ScaleType.Fit
    object.Image = image or ""
    object.ImageColor3 = tint or self.colors.white
    object.ZIndex = 5
    object.Parent = parent

    return object
end

function weatherapi:divider(parent, name, pos, size)
    local line = Instance.new("Frame")
    line.Name = name
    line.Position = self:scale_position(pos)
    line.Size = self:scale_size(size)
    line.BackgroundColor3 = self.colors.line
    line.BorderSizePixel = 0
    line.ZIndex = 4
    line.Parent = parent

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 59, 66)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(103, 111, 132)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 59, 66))
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 0.35)
    })
    gradient.Parent = line

    return line
end

function weatherapi:panel(parent, name, pos, size, transparency)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Position = self:scale_position(pos)
    frame.Size = self:scale_size(size)
    frame.BackgroundColor3 = self.colors.panel
    frame.BackgroundTransparency = transparency or 0
    frame.BorderSizePixel = 0
    frame.ZIndex = 3
    frame.Parent = parent

    return frame
end

function weatherapi:stat(parent, name, x, title)
    self:label(
        parent,
        name .. "Title",
        UDim2.fromOffset(x, 8),
        UDim2.fromOffset(90, 15),
        title,
        Enum.Font.GothamMedium,
        9,
        self.colors.dim
    )

    return self:label(
        parent,
        name .. "Value",
        UDim2.fromOffset(x, 27),
        UDim2.fromOffset(90, 23),
        "--",
        Enum.Font.GothamMedium,
        15,
        self.colors.white
    )
end

function weatherapi:get_weekday(value)
    local y, m, d = value:match("(%d%d%d%d)-(%d%d)-(%d%d)")
    y, m, d = tonumber(y), tonumber(m), tonumber(d)

    if m < 3 then
        m = m + 12
        y = y - 1
    end

    local k = y % 100
    local j = math.floor(y / 100)

    local h = (
        d
        + math.floor(13 * (m + 1) / 5)
        + k
        + math.floor(k / 4)
        + math.floor(j / 4)
        + 5 * j
    ) % 7

    local days = {
        "Sunday", "Monday", "Tuesday",
        "Wednesday", "Thursday", "Friday", "Saturday"
    }

    return days[((h + 6) % 7) + 1]
end

function weatherapi:format_date(value)
    local months = {
        "January", "February", "March",
        "April", "May", "June",
        "July", "August", "September",
        "October", "November", "December"
    }

    local _, month, day = value:match("(%d%d%d%d)-(%d%d)-(%d%d)")

    return string.format(
        "%s, %s %d",
        self:get_weekday(value),
        months[tonumber(month)],
        tonumber(day)
    )
end

function weatherapi:format_time(value)
    if not value then
        return "--:--"
    end

    local hour, minute = value:match("T(%d%d):(%d%d)")
    if not hour then
        return "--:--"
    end

    hour = tonumber(hour)

    local formatted_hour = hour % 12
    if formatted_hour == 0 then
        formatted_hour = 12
    end

    return string.format(
        "%d:%s %s",
        formatted_hour,
        minute,
        hour >= 12 and "PM" or "AM"
    )
end

function weatherapi:get_local_minute(value)
    local hour, minute = value:match("T(%d%d):(%d%d)")

    if not hour then
        return 720
    end

    return tonumber(hour) * 60 + tonumber(minute)
end

function weatherapi:set_weather_icon(object, code, is_day)
    local filename = self:get_icon_file(code, is_day)
    object.Image = self.icon_cache[filename] or ""
end

function weatherapi:get_location_text()
    local display = self.location_display

    if display == "City" then
        return self.city
    elseif display == "State" then
        return self.state
    elseif display == "Country" then
        return self.country
    elseif display == "City, Country" then
        return self.city .. ", " .. self.country
    end

    return self.city .. ", " .. self.state
end

function weatherapi:set_location_display(display)
    self.location_display = display

    if self.location_label then
        self.location_label.Text = self:get_location_text()
    end
end

function weatherapi:apply_weather(data)
    local current = data.current
    local daily = data.daily

    self.current_weather = data
    self.utc_offset = data.utc_offset_seconds or self.utc_offset

    self.date_label.Text = self:format_date(current.time)
    self.temperature_label.Text = string.format("%.0f°", current.temperature_2m)
    self.weather_label.Text = self.weather_names[current.weather_code] or "Unknown"

    self.feels_label.Text = string.format(
        "Feels like %.0f°",
        current.apparent_temperature
    )

    self.humidity_value.Text = string.format("%d%%", current.relative_humidity_2m)
    self.wind_value.Text = string.format("%.0f mph", current.wind_speed_10m)
    self.feels_value.Text = string.format("%.0f°", current.apparent_temperature)

    self:set_weather_icon(
        self.current_icon,
        current.weather_code,
        current.is_day == 1
    )

    self.sunrise_label.Text = self:format_time(daily.sunrise[1])
    self.sunset_label.Text = self:format_time(daily.sunset[1])

    for i = 1, 4 do
        local index = i + 1
        local row = self.forecast_rows[i]
        local date = daily.time[index]
        local code = daily.weather_code[index]
        local high = daily.temperature_2m_max[index]
        local low = daily.temperature_2m_min[index]

        row.day.Text = self:get_weekday(date)
        row.description.Text = self.weather_names[code] or "Cloudy"
        row.temperature.Text = string.format("%.0f° / %.0f°", high, low)

        self:set_weather_icon(row.icon, code, true)
    end
end

function weatherapi:get_greeting(hour)
    if hour >= 5 and hour < 12 then
        return "Good Morning,"
    elseif hour >= 12 and hour < 17 then
        return "Good Afternoon,"
    end

    return "Good Evening,"
end

function weatherapi:get_regional_time()
    return os.date("!*t", os.time() + self.utc_offset)
end

function weatherapi:get_timezone_name()
    local offset = self.utc_offset
    local hours = math.floor(math.abs(offset) / 3600)
    local minutes = math.floor(math.abs(offset) % 3600 / 60)
    local abbreviation = "UTC"

    local zones = {
        ["America/New_York"] = {
            [-14400] = "EDT",
            [-18000] = "EST"
        },
        ["America/Chicago"] = {
            [-18000] = "CDT",
            [-21600] = "CST"
        },
        ["America/Denver"] = {
            [-21600] = "MDT",
            [-25200] = "MST"
        },
        ["America/Los_Angeles"] = {
            [-25200] = "PDT",
            [-28800] = "PST"
        },
        ["Europe/London"] = {
            [3600] = "BST",
            [0] = "GMT"
        },
        ["Europe/Paris"] = {
            [7200] = "CEST",
            [3600] = "CET"
        },
        ["Asia/Tokyo"] = {
            [32400] = "JST"
        },
        ["Australia/Sydney"] = {
            [39600] = "AEDT",
            [36000] = "AEST"
        }
    }

    abbreviation = zones[self.timezone] and zones[self.timezone][offset] or abbreviation

    local sign = offset >= 0 and "+" or "-"
    local utc_text = string.format(
        "UTC%s%d%s",
        sign,
        hours,
        minutes > 0 and string.format(":%02d", minutes) or ""
    )

    return abbreviation .. " (" .. utc_text .. ")"
end

function weatherapi:update_clock()
    local time = self:get_regional_time()
    local hour = time.hour % 12

    if hour == 0 then
        hour = 12
    end

    self.greeting_label.Text = self:get_greeting(time.hour)

    self.clock_label.Text = string.format(
        "%d:%02d:<font color=\"#92949B\">%02d</font> <font color=\"#B8BAC2\" size=\"14\">%s</font>",
        hour,
        time.min,
        time.sec,
        time.hour >= 12 and "PM" or "AM"
    )

    self.timezone_label.Text = self:get_timezone_name()
end

function weatherapi:get_ping()
    local success, value = pcall(function()
        return self.stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)

    if success and type(value) == "number" then
        return math.floor(value + 0.5)
    end

    local fallback, ping = pcall(function()
        return self.player:GetNetworkPing() * 1000
    end)

    if fallback and type(ping) == "number" then
        return math.floor(ping + 0.5)
    end

    return nil
end

function weatherapi:get_memory()
    local success, value = pcall(function()
        return self.stats:GetTotalMemoryUsageMb()
    end)

    if success and type(value) == "number" then
        return math.floor(value + 0.5)
    end

    return nil
end

function weatherapi:update_monitor()
    local ping = self:get_ping()
    local memory = self:get_memory()

    self.monitor_label.Text = string.format(
        "FPS %s  |  %s ms  |  %s MB",
        tostring(self.fps),
        ping and tostring(ping) or "--",
        memory and tostring(memory) or "--"
    )
end

function weatherapi:create_effect_folder()
    if self.effect_folder then
        self.effect_folder:Destroy()
    end

    self.effect_folder = Instance.new("Folder")
    self.effect_folder.Name = "ActiveWeatherEffects"
    self.effect_folder.Parent = self.effect_layer
end

function weatherapi:make_particle(name, size, color, transparency)
    local particle = Instance.new("Frame")
    particle.Name = name
    particle.Size = size
    particle.BackgroundColor3 = color
    particle.BackgroundTransparency = transparency
    particle.BorderSizePixel = 0
    particle.ZIndex = 2
    particle.Parent = self.effect_folder

    return particle
end

function weatherapi:round(object)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = object
end

function weatherapi:make_cloud(x, y, size, transparency, cloud_color)
    local group = Instance.new("Frame")
    group.Name = "CloudGroup"
    group.Size = UDim2.fromOffset(size, size * 0.48)
    group.Position = UDim2.new(x, 0, y, 0)
    group.BackgroundTransparency = 1
    group.ZIndex = 2
    group.Parent = self.effect_folder

    local function puff(name, px, py, sx, sy, alpha)
        local object = Instance.new("Frame")
        object.Name = name
        object.Position = UDim2.new(px, 0, py, 0)
        object.Size = UDim2.new(sx, 0, sy, 0)
        object.BackgroundColor3 = cloud_color
        object.BackgroundTransparency = alpha
        object.BorderSizePixel = 0
        object.ZIndex = 2
        object.Parent = group

        self:round(object)

        return object
    end

    puff("CloudBase", 0.08, 0.40, 0.82, 0.46, transparency)
    puff("CloudPuffLeft", 0.12, 0.20, 0.36, 0.60, transparency)
    puff("CloudPuffCenter", 0.34, 0.00, 0.42, 0.82, transparency)
    puff("CloudPuffRight", 0.62, 0.24, 0.29, 0.58, transparency)

    return group
end

function weatherapi:start_clouds(is_storm)
    self:create_effect_folder()

    local cloud_color = is_storm
        and Color3.fromRGB(75, 83, 101)
        or Color3.fromRGB(178, 188, 205)

    local transparency = is_storm and 0.48 or 0.83

    local clouds = {
        self:make_cloud(-0.45, 0.12, 155, transparency, cloud_color),
        self:make_cloud(0.35, 0.32, 125, transparency + 0.04, cloud_color),
        self:make_cloud(-0.60, 0.63, 180, transparency + 0.06, cloud_color)
    }

    for _, cloud in ipairs(clouds) do
        task.spawn(function()
            while self.effect_folder and self.effect_folder.Parent
                and (self.effect_type == "Clouds" or self.effect_type == "Rain" or self.effect_type == "Lightning") do

                local tween = self.tween:Create(
                    cloud,
                    TweenInfo.new(math.random(22, 34), Enum.EasingStyle.Linear),
                    {
                        Position = UDim2.new(1.2, 0, cloud.Position.Y.Scale, 0)
                    }
                )

                tween:Play()
                tween.Completed:Wait()

                if not self.effect_folder or (
                    self.effect_type ~= "Clouds"
                    and self.effect_type ~= "Rain"
                    and self.effect_type ~= "Lightning"
                ) then
                    break
                end

                cloud.Position = UDim2.new(-0.5, 0, cloud.Position.Y.Scale, 0)
            end
        end)
    end
end

function weatherapi:start_stars()
    self.star_loop = true

    task.spawn(function()
        while self.star_loop and self.gui and self.gui.Parent do
            local star = Instance.new("Frame")
            star.Name = "SkyStar"
            star.AnchorPoint = Vector2.new(0.5, 0.5)
            star.Position = UDim2.new(
                math.random(3, 97) / 100,
                0,
                math.random(3, 35) / 100,
                0
            )
            star.Size = UDim2.fromOffset(10, 10)
            star.BackgroundTransparency = 1
            star.BorderSizePixel = 0
            star.ZIndex = 2
            star.Parent = self.effect_layer

            local center = Instance.new("Frame")
            center.AnchorPoint = Vector2.new(0.5, 0.5)
            center.Position = UDim2.fromScale(0.5, 0.5)
            center.Size = UDim2.fromOffset(2, 2)
            center.BackgroundColor3 = Color3.fromRGB(235, 240, 255)
            center.BackgroundTransparency = 1
            center.BorderSizePixel = 0
            center.Parent = star

            self:round(center)

            local horizontal = Instance.new("Frame")
            horizontal.AnchorPoint = Vector2.new(0.5, 0.5)
            horizontal.Position = UDim2.fromScale(0.5, 0.5)
            horizontal.Size = UDim2.fromOffset(9, 1)
            horizontal.BackgroundColor3 = Color3.fromRGB(220, 230, 255)
            horizontal.BackgroundTransparency = 1
            horizontal.BorderSizePixel = 0
            horizontal.Parent = star

            local vertical = Instance.new("Frame")
            vertical.AnchorPoint = Vector2.new(0.5, 0.5)
            vertical.Position = UDim2.fromScale(0.5, 0.5)
            vertical.Size = UDim2.fromOffset(1, 9)
            vertical.BackgroundColor3 = Color3.fromRGB(220, 230, 255)
            vertical.BackgroundTransparency = 1
            vertical.BorderSizePixel = 0
            vertical.Parent = star

            local fade_in = math.random(40, 65) / 10
            local hold = math.random(15, 30) / 10
            local fade_out = math.random(45, 75) / 10
            local peak = math.random(35, 60) / 100

            self.tween:Create(center, TweenInfo.new(fade_in), {
                BackgroundTransparency = 0.25
            }):Play()

            self.tween:Create(horizontal, TweenInfo.new(fade_in), {
                BackgroundTransparency = peak
            }):Play()

            self.tween:Create(vertical, TweenInfo.new(fade_in), {
                BackgroundTransparency = peak
            }):Play()

            task.delay(fade_in + hold, function()
                if not star.Parent then
                    return
                end

                local fade = TweenInfo.new(fade_out)

                self.tween:Create(center, fade, {
                    BackgroundTransparency = 1
                }):Play()

                self.tween:Create(horizontal, fade, {
                    BackgroundTransparency = 1
                }):Play()

                self.tween:Create(vertical, fade, {
                    BackgroundTransparency = 1
                }):Play()

                task.delay(fade_out, function()
                    if star.Parent then
                        star:Destroy()
                    end
                end)
            end)

            task.wait(math.random(8, 16) / 10)
        end
    end)
end

function weatherapi:start_rain()
    self:create_effect_folder()

    local code = self.current_weather.current.weather_code
    local heavy = code == 65 or code == 67 or code >= 80
    local amount = heavy and 22 or 13

    local rain_color = (code == 66 or code == 67)
        and Color3.fromRGB(235, 242, 255)
        or Color3.fromRGB(160, 194, 225)

    local clouds = {
        self:make_cloud(-0.45, 0.12, 155, 0.48, Color3.fromRGB(75, 83, 101)),
        self:make_cloud(0.35, 0.32, 125, 0.53, Color3.fromRGB(75, 83, 101)),
        self:make_cloud(-0.60, 0.63, 180, 0.56, Color3.fromRGB(75, 83, 101))
    }

    for _, cloud in ipairs(clouds) do
        task.spawn(function()
            while self.effect_folder and self.effect_folder.Parent
                and (self.effect_type == "Rain" or self.effect_type == "Lightning") do

                local tween = self.tween:Create(
                    cloud,
                    TweenInfo.new(math.random(22, 34), Enum.EasingStyle.Linear),
                    {
                        Position = UDim2.new(1.2, 0, cloud.Position.Y.Scale, 0)
                    }
                )

                tween:Play()
                tween.Completed:Wait()

                if not self.effect_folder or (
                    self.effect_type ~= "Rain" and self.effect_type ~= "Lightning"
                ) then
                    break
                end

                cloud.Position = UDim2.new(-0.5, 0, cloud.Position.Y.Scale, 0)
            end
        end)
    end

    for i = 1, amount do
        local drop = self:make_particle(
            "RainDrop",
            UDim2.fromOffset(1, math.random(7, 14)),
            rain_color,
            0.38
        )

        drop.Rotation = 12
        drop.Position = UDim2.new(math.random(), 0, math.random(), 0)

        task.spawn(function()
            while self.effect_folder and self.effect_folder.Parent
                and (self.effect_type == "Rain" or self.effect_type == "Lightning") do

                local tween = self.tween:Create(
                    drop,
                    TweenInfo.new(math.random(65, 110) / 100, Enum.EasingStyle.Linear),
                    {
                        Position = UDim2.new(
                            drop.Position.X.Scale - 0.06,
                            0,
                            1.1,
                            0
                        )
                    }
                )

                tween:Play()
                tween.Completed:Wait()

                if not self.effect_folder or (
                    self.effect_type ~= "Rain" and self.effect_type ~= "Lightning"
                ) then
                    break
                end

                drop.Position = UDim2.new(math.random(), 0, -0.1, 0)
            end
        end)
    end
end

function weatherapi:start_snow()
    self:create_effect_folder()

    for i = 1, 13 do
        local flake = self:make_particle(
            "Snowflake",
            UDim2.fromOffset(math.random(3, 6), math.random(3, 6)),
            Color3.fromRGB(235, 241, 255),
            0.2
        )

        self:round(flake)
        flake.Position = UDim2.new(math.random(), 0, math.random(), 0)

        task.spawn(function()
            while self.effect_folder and self.effect_folder.Parent
                and self.effect_type == "Snow" do

                local tween = self.tween:Create(
                    flake,
                    TweenInfo.new(
                        math.random(35, 65) / 10,
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.InOut
                    ),
                    {
                        Position = UDim2.new(
                            flake.Position.X.Scale + math.random(-8, 8) / 100,
                            0,
                            1.1,
                            0
                        )
                    }
                )

                tween:Play()
                tween.Completed:Wait()

                if not self.effect_folder or self.effect_type ~= "Snow" then
                    break
                end

                flake.Position = UDim2.new(math.random(), 0, -0.1, 0)
            end
        end)
    end
end

function weatherapi:start_fog()
    self:create_effect_folder()

    for i = 1, 3 do
        local fog = Instance.new("Frame")
        fog.Name = "FogLayer"
        fog.Size = UDim2.fromScale(1.5, 0.22)
        fog.Position = UDim2.new(-0.3, 0, 0.42 + (i * 0.12), 0)
        fog.BackgroundColor3 = Color3.fromRGB(190, 199, 211)
        fog.BackgroundTransparency = 0.83
        fog.BorderSizePixel = 0
        fog.ZIndex = 2
        fog.Parent = self.effect_folder

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 190, 205)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(215, 224, 232)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 190, 205))
        })
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.1),
            NumberSequenceKeypoint.new(1, 1)
        })
        gradient.Parent = fog

        task.spawn(function()
            while self.effect_folder and self.effect_folder.Parent
                and self.effect_type == "Fog" do

                local tween = self.tween:Create(
                    fog,
                    TweenInfo.new(
                        12 + i * 2,
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.InOut
                    ),
                    {
                        Position = UDim2.new(0.1, 0, fog.Position.Y.Scale, 0)
                    }
                )

                tween:Play()
                tween.Completed:Wait()

                if not self.effect_folder or self.effect_type ~= "Fog" then
                    break
                end

                fog.Position = UDim2.new(-0.3, 0, fog.Position.Y.Scale, 0)
            end
        end)
    end
end

function weatherapi:start_lightning()
    task.spawn(function()
        while self.gui and self.gui.Parent and self.effect_type == "Lightning" do
            task.wait(math.random(7, 16))

            if not self.gui or not self.gui.Parent or self.effect_type ~= "Lightning" then
                break
            end

            for i = 1, math.random(1, 3) do
                self.lightning_flash.BackgroundTransparency = 0.72
                task.wait(0.055)
                self.lightning_flash.BackgroundTransparency = 1
                task.wait(math.random(5, 12) / 100)
            end
        end

        if self.lightning_flash then
            self.lightning_flash.BackgroundTransparency = 1
        end
    end)
end

function weatherapi:get_lighting_preset()
    local data = self.current_weather

    if not data then
        return self.lighting_presets.night
    end

    local minute = self:get_local_minute(data.current.time)
    local sunrise = self:get_local_minute(data.daily.sunrise[1])
    local sunset = self:get_local_minute(data.daily.sunset[1])

    if minute >= sunrise - 45 and minute <= sunrise + 60 then
        return self.lighting_presets.sunrise
    elseif minute >= sunset - 60 and minute <= sunset + 45 then
        return self.lighting_presets.sunset
    elseif minute > sunrise + 60 and minute < sunset - 60 then
        return self.lighting_presets.day
    end

    return self.lighting_presets.night
end

function weatherapi:get_weather_hue(code)
    if code == 95 or code == 96 or code == 99 then
        return self.weather_hues.thunder
    elseif code == 45 or code == 48 then
        return self.weather_hues.fog
    elseif code >= 71 and code <= 86 then
        return self.weather_hues.snow
    elseif code >= 51 and code <= 67 or code >= 80 and code <= 82 then
        return self.weather_hues.rain
    end

    return nil
end

function weatherapi:get_sun_rotation(minute, sunrise, sunset)
    local progress = math.clamp(
        (minute - sunrise) / math.max(1, sunset - sunrise),
        0,
        1
    )

    return 215 - (progress * 250)
end

function weatherapi:get_weather_theme()
    if self.weather_theme == "Light" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 234, 241)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(205, 214, 228)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 192, 213))
        }), 0.18
    elseif self.weather_theme == "Dark" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 39, 49)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 29, 39)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 19, 27))
        }), 0.28
    end

    return nil, nil
end

function weatherapi:update_lighting()
    if not self.current_weather or not self.atmos_gradient then
        return
    end

    local data = self.current_weather
    local minute = self:get_local_minute(data.current.time)
    local sunrise = self:get_local_minute(data.daily.sunrise[1])
    local sunset = self:get_local_minute(data.daily.sunset[1])
    local preset = self:get_lighting_preset()
    local hue = self:get_weather_hue(data.current.weather_code)

    local chosen_color = hue and hue.color or preset.color
    local chosen_transparency = hue and hue.transparency or preset.transparency
    local rotation

    if minute >= sunrise and minute <= sunset then
        rotation = self:get_sun_rotation(minute, sunrise, sunset)
    else
        local night_progress = minute > sunset
            and (minute - sunset) / math.max(1, 1440 - sunset + sunrise)
            or (minute + 1440 - sunset) / math.max(1, 1440 - sunset + sunrise)

        rotation = 35 + (night_progress * 290)
    end

    local override_color, override_transparency = self:get_weather_theme()

    if override_color then
        chosen_color = override_color
        chosen_transparency = override_transparency
    end

    self.atmos_gradient.Color = chosen_color

    self.tween:Create(
        self.atmosphere,
        TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {
            BackgroundTransparency = chosen_transparency
        }
    ):Play()

    self.tween:Create(
        self.atmos_gradient,
        TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {
            Rotation = rotation
        }
    ):Play()

    if self.on_main_theme_update then
        pcall(function()
            self.on_main_theme_update({
                Theme = self.main_theme,
                Preset = preset,
                Color = preset.color,
                Rotation = rotation
            })
        end)
    end
end

function weatherapi:update_weather_effects()
    if not self.current_weather then
        return
    end

    local code = self.current_weather.current.weather_code
    local night = self:get_lighting_preset() == self.lighting_presets.night
    local next_effect = "None"

    if code == 95 or code == 96 or code == 99 then
        next_effect = "Lightning"
    elseif code == 66 or code == 67 then
        next_effect = "Rain"
    elseif code >= 71 and code <= 86 then
        next_effect = "Snow"
    elseif code >= 51 and code <= 65 or code >= 80 and code <= 82 then
        next_effect = "Rain"
    elseif code == 45 or code == 48 then
        next_effect = "Fog"
    elseif code == 2 or code == 3 then
        next_effect = "Clouds"
    elseif night then
        next_effect = "Stars"
    end

    if self.effect_type == next_effect then
        return
    end

    self.effect_type = next_effect
    self.star_loop = false

    if self.effect_folder then
        self.effect_folder:Destroy()
        self.effect_folder = nil
    end

    self.lightning_flash.BackgroundTransparency = 1

    if next_effect == "Rain" then
        self:start_rain()
    elseif next_effect == "Snow" then
        self:start_snow()
    elseif next_effect == "Fog" then
        self:start_fog()
    elseif next_effect == "Clouds" then
        self:start_clouds(false)
    elseif next_effect == "Lightning" then
        self:start_rain()
        self.effect_type = "Lightning"
        self:start_lightning()
    elseif next_effect == "Stars" then
        self:start_stars()
    end
end

function weatherapi:create_ui()
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "MirrorDashboard"
    self.gui.ResetOnSpawn = false
    self.gui.IgnoreGuiInset = true
    self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    self.main = Instance.new("Frame")
    self.main.Name = "Dashboard"
    self.main.Size = UDim2.fromOffset(320, 550)
    self.main.AnchorPoint = Vector2.new(1, 1)
    self.main.Position = UDim2.new(1, -75, 0.5, 275)
    self.main.BackgroundColor3 = self.colors.bg
    self.main.BackgroundTransparency = 0.05
    self.main.BorderSizePixel = 0
    self.main.ClipsDescendants = true
    self.main.Parent = self.gui

    self.main_scale = Instance.new("UIScale")
    self.main_scale.Scale = 0.92
    self.main_scale.Parent = self.main

    self.atmosphere = Instance.new("Frame")
    self.atmosphere.Name = "AtmosphericLighting"
    self.atmosphere.Size = UDim2.fromScale(1, 1)
    self.atmosphere.BackgroundColor3 = Color3.new(1, 1, 1)
    self.atmosphere.BackgroundTransparency = 0.78
    self.atmosphere.BorderSizePixel = 0
    self.atmosphere.ZIndex = 1
    self.atmosphere.Parent = self.main

    self.atmos_gradient = Instance.new("UIGradient")
    self.atmos_gradient.Rotation = 45
    self.atmos_gradient.Parent = self.atmosphere

    self.effect_layer = Instance.new("Frame")
    self.effect_layer.Name = "WeatherEffects"
    self.effect_layer.Size = UDim2.fromScale(1, 1)
    self.effect_layer.BackgroundTransparency = 1
    self.effect_layer.ClipsDescendants = true
    self.effect_layer.ZIndex = 2
    self.effect_layer.Parent = self.main

    self.greeting_label = self:label(
        self.main, "Header",
        UDim2.fromOffset(23, 15), UDim2.fromOffset(200, 23),
        "Good Evening,", Enum.Font.GothamBold, 13, self.colors.white
    )

    self.location_label = self:label(
        self.main, "Location",
        UDim2.fromOffset(23, 39), UDim2.fromOffset(200, 18),
        self:get_location_text(), Enum.Font.Gotham, 11, self.colors.muted
    )

    self.date_label = self:label(
        self.main, "Date",
        UDim2.fromOffset(23, 58), UDim2.fromOffset(200, 17),
        "", Enum.Font.Gotham, 10, self.colors.dim
    )

    self.monitor_label = self:label(
        self.main, "SystemMonitor",
        UDim2.fromOffset(174, 16), UDim2.fromOffset(164, 20),
        "FPS --  |  -- ms  |  -- MB",
        Enum.Font.GothamMedium, 8, self.colors.muted
    )

    self.monitor_label.TextXAlignment = Enum.TextXAlignment.Right
    self.monitor_label.TextTruncate = Enum.TextTruncate.AtEnd

    self.clock_label = self:label(
        self.main, "Clock",
        UDim2.fromOffset(21, 87), UDim2.fromOffset(195, 53),
        "", Enum.Font.Gotham, 32, self.colors.white
    )

    self.clock_label.RichText = true

    self.timezone_label = self:label(
        self.main, "Timezone",
        UDim2.fromOffset(23, 137), UDim2.fromOffset(175, 15),
        "", Enum.Font.GothamMedium, 9, self.colors.muted
    )

    self.current_icon = self:image(
        self.main, "CurrentWeatherIcon",
        UDim2.fromOffset(215, 82), UDim2.fromOffset(62, 62), ""
    )

    self.temperature_label = self:label(
        self.main, "Temperature",
        UDim2.fromOffset(275, 88), UDim2.fromOffset(80, 42),
        "", Enum.Font.Gotham, 34, self.colors.white
    )

    self.weather_label = self:label(
        self.main, "Weather",
        UDim2.fromOffset(213, 144), UDim2.fromOffset(140, 18),
        "", Enum.Font.GothamMedium, 10, self.colors.muted
    )

    self.feels_label = self:label(
        self.main, "FeelsLike",
        UDim2.fromOffset(213, 163), UDim2.fromOffset(140, 16),
        "", Enum.Font.Gotham, 9, self.colors.dim
    )

    self:divider(
        self.main, "TopDivider",
        UDim2.fromOffset(20, 190), UDim2.fromOffset(320, 1)
    )

    self.stats_panel = self:panel(
        self.main, "Stats",
        UDim2.fromOffset(20, 204), UDim2.fromOffset(320, 63), 1
    )

    self.humidity_value = self:stat(self.stats_panel, "Humidity", 14, "HUMIDITY")
    self.wind_value = self:stat(self.stats_panel, "Wind", 119, "WIND")
    self.feels_value = self:stat(self.stats_panel, "Feels", 224, "FEELS LIKE")

    self:divider(
        self.main, "SolarDivider",
        UDim2.fromOffset(20, 279), UDim2.fromOffset(320, 1)
    )

    local solar_asset = "rbxassetid://81377035331970"

    self:image(
        self.main, "SunriseIcon",
        UDim2.fromOffset(25, 291), UDim2.fromOffset(30, 30),
        solar_asset, Color3.fromRGB(238, 190, 115)
    )

    self.sunrise_label = self:label(
        self.main, "Sunrise",
        UDim2.fromOffset(62, 288), UDim2.fromOffset(90, 20),
        "--:--", Enum.Font.GothamMedium, 13, self.colors.white
    )

    self:label(
        self.main, "SunriseCaption",
        UDim2.fromOffset(62, 308), UDim2.fromOffset(90, 16),
        "SUNRISE", Enum.Font.GothamMedium, 9, self.colors.dim
    )

    local sunset_icon = self:image(
        self.main, "SunsetIcon",
        UDim2.fromOffset(188, 291), UDim2.fromOffset(30, 30),
        solar_asset, Color3.fromRGB(225, 145, 105)
    )

    sunset_icon.Rotation = 180

    self.sunset_label = self:label(
        self.main, "Sunset",
        UDim2.fromOffset(225, 288), UDim2.fromOffset(90, 20),
        "--:--", Enum.Font.GothamMedium, 13, self.colors.white
    )

    self:label(
        self.main, "SunsetCaption",
        UDim2.fromOffset(225, 308), UDim2.fromOffset(90, 16),
        "SUNSET", Enum.Font.GothamMedium, 9, self.colors.dim
    )

    self:divider(
        self.main, "ForecastDivider",
        UDim2.fromOffset(20, 340), UDim2.fromOffset(320, 1)
    )

    self:label(
        self.main, "ForecastHeader",
        UDim2.fromOffset(23, 351), UDim2.fromOffset(200, 20),
        "UPCOMING FORECAST", Enum.Font.GothamBold, 10, self.colors.muted
    )

    for i = 1, 4 do
        local y = 379 + ((i - 1) * 39)
        local row = {}

        row.day = self:label(
            self.main, "ForecastDay" .. i,
            UDim2.fromOffset(24, y), UDim2.fromOffset(105, 27),
            "", Enum.Font.GothamMedium, 12, self.colors.white
        )

        row.icon = self:image(
            self.main, "ForecastIcon" .. i,
            UDim2.fromOffset(137, y - 2), UDim2.fromOffset(30, 30), ""
        )

        row.description = self:label(
            self.main, "ForecastDescription" .. i,
            UDim2.fromOffset(176, y), UDim2.fromOffset(95, 27),
            "", Enum.Font.Gotham, 10, self.colors.muted
        )

        row.temperature = self:label(
            self.main, "ForecastTemperature" .. i,
            UDim2.fromOffset(270, y), UDim2.fromOffset(68, 27),
            "", Enum.Font.GothamMedium, 11, self.colors.white
        )

        self.forecast_rows[i] = row
    end

    self.lightning_flash = Instance.new("Frame")
    self.lightning_flash.Name = "LightningFlash"
    self.lightning_flash.Size = UDim2.fromScale(1, 1)
    self.lightning_flash.BackgroundColor3 = Color3.fromRGB(205, 220, 255)
    self.lightning_flash.BackgroundTransparency = 1
    self.lightning_flash.BorderSizePixel = 0
    self.lightning_flash.ZIndex = 3
    self.lightning_flash.Parent = self.main

    self.main.Visible = false
    self.main.Size = UDim2.fromOffset(320, 0)
end

function weatherapi:setup_presets()
    self.lighting_presets = {
        night = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
            }),
            transparency = 0.48
        },
        sunrise = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 169, 105)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(241, 132, 125)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 113, 161))
            }),
            transparency = 0.48
        },
        day = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 156)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(159, 202, 238)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(103, 159, 213))
            }),
            transparency = 0.70
        },
        sunset = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 151, 91)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(216, 111, 131)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(111, 91, 151))
            }),
            transparency = 0.48
        }
    }

    self.weather_hues = {
        rain = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 139, 181)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(73, 105, 148)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 69, 107))
            }),
            transparency = 0.50
        },
        snow = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(204, 226, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 184, 223)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(111, 139, 184))
            }),
            transparency = 0.54
        },
        fog = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(191, 203, 211)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(144, 161, 178)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(101, 117, 136))
            }),
            transparency = 0.48
        },
        thunder = {
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 104, 151)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(66, 76, 117)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(39, 48, 79))
            }),
            transparency = 0.42
        }
    }
end

function weatherapi:save_visuals()
    self.visuals = {}

    local function save(object)
        local properties = {}

        if object:IsA("TextLabel") or object:IsA("TextButton") then
            properties.TextTransparency = object.TextTransparency
            properties.TextStrokeTransparency = object.TextStrokeTransparency
            properties.BackgroundTransparency = object.BackgroundTransparency
        elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
            properties.ImageTransparency = object.ImageTransparency
            properties.BackgroundTransparency = object.BackgroundTransparency
        elseif object:IsA("Frame") or object:IsA("ScrollingFrame") then
            properties.BackgroundTransparency = object.BackgroundTransparency
        elseif object:IsA("UIStroke") then
            properties.Transparency = object.Transparency
        end

        if next(properties) then
            self.visuals[object] = properties
        end
    end

    save(self.main)

    for _, object in ipairs(self.main:GetDescendants()) do
        save(object)
    end
end

function weatherapi:set_visual_transparency(transparency, duration, direction)
    local info = TweenInfo.new(
        duration,
        Enum.EasingStyle.Quint,
        direction
    )

    for object, properties in pairs(self.visuals) do
        if object and object.Parent then
            local goals = {}

            for property, original in pairs(properties) do
                goals[property] = transparency == 1 and 1 or original
            end

            self.tween:Create(object, info, goals):Play()
        end
    end
end

function weatherapi:get_target_position()
    if self.follow_main and self.main_window and self.main_window.Parent then
        local main_position = self.main_window.AbsolutePosition
        local main_size = self.main_window.AbsoluteSize

        return UDim2.fromOffset(
            main_position.X + main_size.X + self.offset.X,
            main_position.Y + self.offset.Y
        )
    end

    return UDim2.new(1, -75, 0.5, 275)
end

function weatherapi:update_follow_position()
    if not self.follow_main or not self.main_window or not self.main_window.Parent then
        return
    end

    if self.dragging then
        return
    end

    self.main.Position = self:get_target_position()
end

function weatherapi:bind_following()
    if not self.follow_main or not self.main_window then
        return
    end

    table.insert(self.connections, self.main_window:GetPropertyChangedSignal("Position"):Connect(function()
        self:update_follow_position()
    end))

    table.insert(self.connections, self.main_window:GetPropertyChangedSignal("Size"):Connect(function()
        self:update_follow_position()
    end))

    table.insert(self.connections, self.main_window:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        self:update_follow_position()
    end))

    self:update_follow_position()
end

function weatherapi:animate_open()
    if self.animating or not self.main or self.destroyed then
        return
    end

    self.animating = true
    self.visible = true

    self.main.Visible = true
    self.main.ClipsDescendants = true
    self.main.Size = UDim2.fromOffset(320, 0)
    self.main_scale.Scale = 0.92

    self:set_visual_transparency(1, 0, Enum.EasingDirection.Out)

    local opening = self.tween:Create(
        self.main,
        TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {
            Size = UDim2.fromOffset(320, 550)
        }
    )

    local scaling = self.tween:Create(
        self.main_scale,
        TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {
            Scale = 0.92
        }
    )

    opening:Play()
    scaling:Play()

    self:set_visual_transparency(0, 0.42, Enum.EasingDirection.Out)

    opening.Completed:Wait()

    if self.main and self.main.Parent then
        self.main.Size = UDim2.fromOffset(320, 550)
    end

    self.animating = false
end

function weatherapi:animate_close()
    if self.animating or not self.main or not self.main.Visible then
        return
    end

    self.animating = true
    self.visible = false

    local closing = self.tween:Create(
        self.main,
        TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {
            Size = UDim2.fromOffset(320, 0)
        }
    )

    closing:Play()
    closing.Completed:Wait()

    if self.main and self.main.Parent then
        self.main.Visible = false
        self.main.Size = UDim2.fromOffset(320, 0)
    end

    self.animating = false
end

function weatherapi:toggle()
    if self.animating or self.destroyed then
        return
    end

    if self.visible then
        self:animate_close()
    else
        self:animate_open()
    end
end

function weatherapi:Toggle()
    return self:toggle()
end

function weatherapi:Open()
    if not self.visible then
        return self:animate_open()
    end
end

function weatherapi:Close()
    if self.visible then
        return self:animate_close()
    end
end

function weatherapi:SetVisible(value)
    if value then
        self:Open()
    else
        self:Close()
    end
end

function weatherapi:SetKeybind(key)
    self.keybind = key
end

function weatherapi:SetLocationDisplay(display)
    self:set_location_display(display)
end

function weatherapi:SetWeatherTheme(theme)
    if theme ~= "Sync" and theme ~= "Light" and theme ~= "Dark" then
        return false
    end

    self.weather_theme = theme
    self:update_lighting()

    return true
end

function weatherapi:SetMainTheme(theme)
    if theme ~= "Sync" and theme ~= "System" and theme ~= "Light" and theme ~= "Dark" then
        return false
    end

    self.main_theme = theme
    self:update_lighting()

    return true
end

function weatherapi:SetFollowMain(enabled, offset)
    self.follow_main = enabled == true

    if offset then
        self.offset = offset
    end

    if self.follow_main then
        self:update_follow_position()
    end
end

function weatherapi:bind_toggle()
    table.insert(self.connections, self.input.InputBegan:Connect(function(input, processed)
        if processed or self.destroyed then
            return
        end

        if input.KeyCode == self.keybind then
            self:toggle()
        end
    end))
end

function weatherapi:bind_dragging()
    table.insert(self.connections, self.main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            self.dragging = true
            self.drag_start = input.Position
            self.start_position = self.main.Position

            local ended
            ended = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    self.dragging = false

                    if ended then
                        ended:Disconnect()
                    end
                end
            end)
        end
    end))

    table.insert(self.connections, self.input.InputChanged:Connect(function(input)
        if self.dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - self.drag_start

            self.main.Position = UDim2.new(
                self.start_position.X.Scale,
                self.start_position.X.Offset + delta.X,
                self.start_position.Y.Scale,
                self.start_position.Y.Offset + delta.Y
            )
        end
    end))
end

function weatherapi:bind_updates()
    table.insert(self.connections, self.run.RenderStepped:Connect(function(delta)
        if self.destroyed then
            return
        end

        self.frame_count = self.frame_count + 1
        self.frame_elapsed = self.frame_elapsed + delta

        if self.frame_elapsed >= 1 then
            self.fps = math.floor(self.frame_count / self.frame_elapsed + 0.5)
            self.frame_count = 0
            self.frame_elapsed = 0
        end
    end))

    task.spawn(function()
        while not self.destroyed and self.gui and self.gui.Parent do
            self:update_clock()
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        while not self.destroyed and self.gui and self.gui.Parent do
            self:update_monitor()
            task.wait(1)
        end
    end)

    task.spawn(function()
        while not self.destroyed and self.gui and self.gui.Parent do
            self:update_lighting()
            self:update_weather_effects()
            task.wait(10)
        end
    end)

    task.spawn(function()
        while not self.destroyed and self.gui and self.gui.Parent do
            task.wait(self.refresh_interval)

            if self.destroyed or not self.gui or not self.gui.Parent then
                break
            end

            local fetched, data = pcall(function()
                return self:fetch_weather()
            end)

            if fetched then
                pcall(function()
                    self:apply_weather(data)
                    self:update_lighting()
                    self:update_weather_effects()
                end)
            end
        end
    end)
end

function weatherapi:start()
    if self.started or self.destroyed then
        return self
    end

    self.started = true

    local success, result = pcall(function()
        for _, filename in ipairs(self.icon_files) do
            self:download_icon(filename)
        end

        return self:fetch_weather()
    end)

    if not success then
        warn("Weather dashboard failed to initialize: " .. tostring(result))
        self.started = false
        return nil
    end

    self.initial_weather = result
    self.current_weather = self.initial_weather
    self.utc_offset = self.initial_weather.utc_offset_seconds or -18000

    self:setup_presets()
    self:create_ui()
    self:apply_weather(self.initial_weather)
    self:update_clock()
    self:update_monitor()
    self:update_lighting()
    self:update_weather_effects()
    self:save_visuals()

    self.gui.Parent = self.config.Parent or self.playergui

    self:bind_dragging()
    self:bind_toggle()
    self:bind_following()
    self:bind_updates()

    if self.visible then
        self:animate_open()
    else
        self.main.Visible = false
        self.main.Size = UDim2.fromOffset(320, 0)
    end

    return self
end

function weatherapi:destroy()
    if self.destroyed then
        return
    end

    self.destroyed = true
    self.star_loop = false
    self.effect_type = nil

    for _, connection in ipairs(self.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(self.connections)

    if self.effect_folder then
        self.effect_folder:Destroy()
        self.effect_folder = nil
    end

    if self.gui then
        self.gui:Destroy()
        self.gui = nil
    end
end

function weatherapi:Destroy()
    return self:destroy()
end

return weatherapi
