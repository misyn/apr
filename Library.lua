
local Library = {}
Library.__index = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

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

    self._inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or self.Destroyed then
            return
        end

        if input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end)

    table.insert(self.Connections, self._inputConnection)

    self:LoadModules(config)

    return self
end

function Library:LoadModules(config)
    config = config or {}

    local weatherConfig = config.Weather or {}

    if weatherConfig.Enabled == false then
        return
    end

    local moduleUrl = weatherConfig.ModuleURL

    if not moduleUrl or moduleUrl == "" then
        return
    end

    local success, result = pcall(function()
        local source = game:HttpGet(moduleUrl)
        local loadModule = loadstring(source)

        assert(type(loadModule) == "function", "Weather module could not be compiled")

        local weatherModule = loadModule()

        assert(type(weatherModule) == "table", "Weather module did not return a table")
        assert(type(weatherModule.new) == "function", "Weather module is missing new()")

        local location = weatherConfig.Location or {}
        local theme = weatherConfig.Theme or {}

        local weather = weatherModule.new({
            Parent = getParent(),

            MainWindow = self.Main,

            FollowMain = weatherConfig.FollowMain ~= false,
            Offset = weatherConfig.Offset or Vector2.new(340, 0),

            Enabled = true,
            Visible = weatherConfig.Visible ~= false,

            Keybind = weatherConfig.Keybind or Enum.KeyCode.G,

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

            RefreshInterval = weatherConfig.RefreshInterval or 300,
            Unit = weatherConfig.Unit or "fahrenheit",
            WindUnit = weatherConfig.WindUnit or "mph",

            OnMainThemeUpdate = weatherConfig.OnMainThemeUpdate
        })

        assert(weather, "Weather constructor returned nil")
        assert(type(weather.start) == "function", "Weather module is missing start()")

        local started = weather:start()

        assert(started, "Weather dashboard failed to start")

        return weather
    end)

    if success then
        self.Weather = result
        self.Modules.Weather = result
    else
        warn("Weather module failed to load: " .. tostring(result))
    end
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

function Library:SetWeatherVisible(value)
    if self.Destroyed or not self.Weather then
        return
    end

    self.Weather:SetVisible(value)
end

function Library:ToggleWeather()
    if self.Destroyed or not self.Weather then
        return
    end

    self.Weather:Toggle()
end

function Library:SetWeatherKeybind(key)
    if self.Destroyed or not self.Weather then
        return
    end

    self.Weather:SetKeybind(key)
end

function Library:SetWeatherTheme(theme)
    if self.Destroyed or not self.Weather then
        return false
    end

    return self.Weather:SetWeatherTheme(theme)
end

function Library:SetMainTheme(theme)
    if self.Destroyed or not self.Weather then
        return false
    end

    return self.Weather:SetMainTheme(theme)
end

function Library:SetWeatherLocationDisplay(display)
    if self.Destroyed or not self.Weather then
        return
    end

    self.Weather:SetLocationDisplay(display)
end

function Library:SetWeatherFollowMain(enabled, offset)
    if self.Destroyed or not self.Weather then
        return
    end

    self.Weather:SetFollowMain(enabled, offset)
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
