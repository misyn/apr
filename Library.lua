
local Library = {}
Library.__index = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local WEATHER_URL = "https://raw.githubusercontent.com/misyn/apr/refs/heads/main/Modules/Weather.lua"

local function getParent()
    if typeof(gethui) == "function" then
        local success, result = pcall(gethui)

        if success and result then
            return result
        end
    end

    return PlayerGui
end

local function create(class, properties, parent)
    local object = Instance.new(class)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

function Library.new(config)
    config = config or {}

    local self = setmetatable({}, Library)

    self.Destroyed = false
    self.Visible = true
    self.Keybind = config.Keybind or Enum.KeyCode.RightControl
    self.Modules = {}
    self.Connections = {}

    self.Gui = create("ScreenGui", {
        Name = config.GuiName or "CustomUILibrary",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, getParent())

    self.Main = create("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(500, 340),
        Position = UDim2.new(0.5, -250, 0.5, -170),
        BackgroundColor3 = Color3.fromRGB(20, 22, 29),
        BorderSizePixel = 0
    }, self.Gui)

    create("UICorner", {
        CornerRadius = UDim.new(0, 10)
    }, self.Main)

    create("UIStroke", {
        Color = Color3.fromRGB(55, 59, 72),
        Transparency = 0.35,
        Thickness = 1
    }, self.Main)

    self.Header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Color3.fromRGB(27, 30, 39),
        BorderSizePixel = 0
    }, self.Main)

    create("UICorner", {
        CornerRadius = UDim.new(0, 10)
    }, self.Header)

    create("Frame", {
        Name = "HeaderCover",
        Position = UDim2.new(0, 0, 1, -10),
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = self.Header.BackgroundColor3,
        BorderSizePixel = 0
    }, self.Header)

    self.Title = create("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -32, 1, 0),
        BackgroundTransparency = 1,
        Text = config.Title or "UI Library",
        TextColor3 = Color3.fromRGB(240, 242, 248),
        TextSize = 15,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left
    }, self.Header)

    self.Content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(14, 56),
        Size = UDim2.new(1, -28, 1, -70),
        BackgroundTransparency = 1
    }, self.Main)

    self._dragging = false
    self._dragStart = nil
    self._startPosition = nil

    table.insert(self.Connections, self.Header.InputBegan:Connect(function(input)
        if self.Destroyed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            self._dragging = true
            self._dragStart = input.Position
            self._startPosition = self.Main.Position
        end
    end))

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if self.Destroyed or not self._dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - self._dragStart

            self.Main.Position = UDim2.new(
                self._startPosition.X.Scale,
                self._startPosition.X.Offset + delta.X,
                self._startPosition.Y.Scale,
                self._startPosition.Y.Offset + delta.Y
            )
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            self._dragging = false
        end
    end))

    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed or self.Destroyed then
            return
        end

        if input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end))

    self:LoadWeather(config.Weather or {})

    return self
end

function Library:LoadWeather(config)
    if self.Destroyed or config.Enabled == false then
        return
    end

    local moduleUrl = config.ModuleURL or WEATHER_URL

    local success, result = pcall(function()
        assert(type(loadstring) == "function", "loadstring is unavailable")

        local source = game:HttpGet(moduleUrl)
        assert(type(source) == "string" and #source > 0, "Weather source is empty")

        local compiled = loadstring(source)
        assert(type(compiled) == "function", "Weather source failed to compile")

        local weatherModule = compiled()

        assert(type(weatherModule) == "table", "Weather module did not return a table")
        assert(type(weatherModule.new) == "function", "Weather module has no constructor")

        local location = config.Location or {}
        local theme = config.Theme or {}

        local weather = weatherModule.new({
            Parent = getParent(),

            MainWindow = self.Main,

            FollowMain = config.FollowMain ~= false,
            Offset = config.Offset or Vector2.new(12, 0),

            Enabled = true,
            Visible = config.Visible ~= false,

            Keybind = config.Keybind or Enum.KeyCode.G,

            Latitude = location.Latitude or 26.3683,
            Longitude = location.Longitude or -80.1289,
            Timezone = location.Timezone or "America/New_York",

            Location = {
                City = location.City or "Boca Raton",
                State = location.State or "Florida",
                Country = location.Country or "United States",
                Display = location.Display or "City, State"
            },

            Theme = {
                Main = theme.Main or "Sync",
                Weather = theme.Weather or "Sync"
            },

            RefreshInterval = config.RefreshInterval or 300,
            Unit = config.Unit or "fahrenheit",
            WindUnit = config.WindUnit or "mph",

            OnMainThemeUpdate = config.OnMainThemeUpdate
        })

        assert(weather, "Weather constructor returned nil. Check executor request, writefile and getcustomasset support.")
        assert(type(weather.start) == "function", "Weather module has no start method")

        local started = weather:start()

        assert(started, "Weather start failed. Check the warnings from the Weather module.")

        return weather
    end)

    if not success then
        warn("[APR] Weather failed: " .. tostring(result))
        return nil
    end

    self.Weather = result
    self.Modules.Weather = result

    return result
end

function Library:SetKeybind(key)
    if self.Destroyed then
        return
    end

    self.Keybind = key
end

function Library:Toggle()
    if self.Destroyed then
        return
    end

    self.Visible = not self.Visible
    self.Main.Visible = self.Visible
end

function Library:Open()
    if self.Destroyed then
        return
    end

    self.Visible = true
    self.Main.Visible = true
end

function Library:Close()
    if self.Destroyed then
        return
    end

    self.Visible = false
    self.Main.Visible = false
end

function Library:ToggleWeather()
    if self.Weather then
        self.Weather:Toggle()
    end
end

function Library:OpenWeather()
    if self.Weather then
        self.Weather:Open()
    end
end

function Library:CloseWeather()
    if self.Weather then
        self.Weather:Close()
    end
end

function Library:SetWeatherVisible(value)
    if self.Weather then
        self.Weather:SetVisible(value)
    end
end

function Library:SetWeatherKeybind(key)
    if self.Weather then
        self.Weather:SetKeybind(key)
    end
end

function Library:SetWeatherTheme(theme)
    if self.Weather then
        return self.Weather:SetWeatherTheme(theme)
    end

    return false
end

function Library:SetMainTheme(theme)
    if self.Weather then
        return self.Weather:SetMainTheme(theme)
    end

    return false
end

function Library:SetWeatherLocationDisplay(display)
    if self.Weather then
        self.Weather:SetLocationDisplay(display)
    end
end

function Library:SetWeatherFollowMain(enabled, offset)
    if self.Weather then
        self.Weather:SetFollowMain(enabled, offset)
    end
end

function Library:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self._dragging = false

    for _, connection in ipairs(self.Connections) do
        disconnect(connection)
    end

    table.clear(self.Connections)

    if self.Weather then
        pcall(function()
            self.Weather:Destroy()
        end)

        self.Weather = nil
    end

    table.clear(self.Modules)

    if self.Gui then
        self.Gui:Destroy()
        self.Gui = nil
    end
end

return Library
