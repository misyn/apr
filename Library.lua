
local Library = {}
Library.__index = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local WEATHER_URL = "https://raw.githubusercontent.com/misyn/apr/refs/heads/main/Modules/Weather.lua"

local function getEnvironment()
    if typeof(getgenv) == "function" then
        local success, environment = pcall(getgenv)

        if success and environment then
            return environment
        end
    end

    return _G
end

local Environment = getEnvironment()

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

local function cleanupGui(parent, name)
    if not parent then
        return
    end

    local existing = parent:FindFirstChild(name)

    if existing then
        existing:Destroy()
    end
end

function Library.new(config)
    config = config or {}

    if Environment.__APR_LIBRARY_INSTANCE then
        pcall(function()
            Environment.__APR_LIBRARY_INSTANCE:Destroy()
        end)
    end

    cleanupGui(getParent(), "CustomUILibrary")
    cleanupGui(getParent(), "MirrorDashboard")
    cleanupGui(PlayerGui, "CustomUILibrary")
    cleanupGui(PlayerGui, "MirrorDashboard")

    local self = setmetatable({}, Library)

    self.Destroyed = false
    self.Visible = true
    self.Keybind = config.Keybind or Enum.KeyCode.RightControl

    self.Modules = {}
    self.Connections = {}

    self.MainTheme = "Sync"
    self.MainTween = nil
    self.ScaleTween = nil
    self.Animating = false

    self.Gui = create("ScreenGui", {
        Name = "CustomUILibrary",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, getParent())

    self.Main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(500, 550),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(29, 30, 34),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.Gui)

    self.MainScale = create("UIScale", {
        Scale = 1
    }, self.Main)

    self.MainGradient = create("UIGradient", {
        Rotation = 35,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
        }),
        Transparency = NumberSequence.new(0.72)
    }, self.Main)

    create("UICorner", {
        CornerRadius = UDim.new(0, 10)
    }, self.Main)

    self.MainStroke = create("UIStroke", {
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
        Size = UDim2.new(1, -170, 1, 0),
        BackgroundTransparency = 1,
        Text = config.Title or "UI Library",
        TextColor3 = Color3.fromRGB(240, 242, 248),
        TextSize = 15,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left
    }, self.Header)

    self.ThemeLabel = create("TextLabel", {
        Name = "ThemeLabel",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.fromOffset(140, 42),
        BackgroundTransparency = 1,
        Text = "THEME  SYNC",
        TextColor3 = Color3.fromRGB(180, 190, 215),
        TextSize = 10,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Right
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

    Environment.__APR_LIBRARY_INSTANCE = self

    self:ApplyTheme({
        Theme = "Sync",
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
        })
    })

    self.Main.Size = UDim2.fromOffset(500, 0)
    self.MainScale.Scale = 0.96

    self:Animate(true)

    self:LoadWeather(config.Weather or {})

    return self
end

function Library:ApplyTheme(data)
    if self.Destroyed or not self.Main then
        return
    end

    data = data or {}

    local theme = data.Theme or self.MainTheme or "Sync"
    self.MainTheme = theme

    local gradient
    local headerColor
    local strokeColor
    local labelColor

    if theme == "Sync" and data.Color then
        gradient = data.Color

        local keys = gradient.Keypoints
        local first = keys[1].Value
        local middle = keys[math.ceil(#keys / 2)].Value

        headerColor = Color3.fromRGB(27, 30, 39):Lerp(first, 0.24)
        strokeColor = middle:Lerp(Color3.fromRGB(55, 59, 72), 0.55)
        labelColor = first:Lerp(Color3.new(1, 1, 1), 0.65)

        self.ThemeLabel.Text = "THEME  SYNC"
    elseif theme == "Light" then
        gradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 228, 241)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 207, 231)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(157, 180, 214))
        })

        headerColor = Color3.fromRGB(215, 223, 236)
        strokeColor = Color3.fromRGB(145, 163, 190)
        labelColor = Color3.fromRGB(70, 87, 117)

        self.ThemeLabel.Text = "THEME  LIGHT"
    elseif theme == "Dark" or theme == "System" then
        gradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 55, 72)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 36, 51)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 23, 34))
        })

        headerColor = Color3.fromRGB(27, 30, 39)
        strokeColor = Color3.fromRGB(55, 59, 72)
        labelColor = Color3.fromRGB(180, 190, 215)

        self.ThemeLabel.Text = theme == "System" and "THEME  SYSTEM" or "THEME  DARK"
    else
        return
    end

    self.MainGradient.Color = gradient

    TweenService:Create(
        self.Header,
        TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {
            BackgroundColor3 = headerColor
        }
    ):Play()

    TweenService:Create(
        self.MainStroke,
        TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {
            Color = strokeColor
        }
    ):Play()

    TweenService:Create(
        self.ThemeLabel,
        TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {
            TextColor3 = labelColor
        }
    ):Play()
end

function Library:LoadWeather(config)
    if self.Destroyed or config.Enabled == false then
        return
    end

    local moduleUrl = config.ModuleURL or WEATHER_URL

    local success, result = pcall(function()
        local source = game:HttpGet(moduleUrl)

        assert(type(source) == "string" and #source > 0, "Weather source is empty")

        local compiled = loadstring(source)

        assert(type(compiled) == "function", "Weather module failed to compile")

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

            OnMainThemeUpdate = function(data)
                self:ApplyTheme(data)
            end
        })

        assert(weather, "Weather constructor returned nil")
        assert(type(weather.start) == "function", "Weather module has no start method")

        local started = weather:start()

        assert(started, "Weather failed to start")

        return weather
    end)

    if not success then
        warn("[APR] Weather failed: " .. tostring(result))
        return nil
    end

    if self.Destroyed then
        pcall(function()
            result:Destroy()
        end)

        return nil
    end

    self.Weather = result
    self.Modules.Weather = result

    return result
end

function Library:Animate(open)
    if self.Destroyed or not self.Main then
        return
    end

    if self.MainTween then
        self.MainTween:Cancel()
        self.MainTween = nil
    end

    if self.ScaleTween then
        self.ScaleTween:Cancel()
        self.ScaleTween = nil
    end

    self.Animating = true

    if open then
        self.Main.Visible = true

        self.MainTween = TweenService:Create(
            self.Main,
            TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {
                Size = UDim2.fromOffset(500, 550)
            }
        )

        self.ScaleTween = TweenService:Create(
            self.MainScale,
            TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {
                Scale = 1
            }
        )
    else
        self.MainTween = TweenService:Create(
            self.Main,
            TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {
                Size = UDim2.fromOffset(500, 0)
            }
        )

        self.ScaleTween = TweenService:Create(
            self.MainScale,
            TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {
                Scale = 0.96
            }
        )
    end

    self.MainTween:Play()
    self.ScaleTween:Play()

    local completed = self.MainTween.Completed:Wait()

    if self.Destroyed then
        return
    end

    if not open then
        self.Main.Visible = false
    end

    self.Animating = false
end

function Library:SetVisible(value)
    if self.Destroyed then
        return
    end

    value = value == true

    if self.Visible == value then
        return
    end

    self.Visible = value

    task.spawn(function()
        self:Animate(value)
    end)

    if self.Weather then
        task.spawn(function()
            if value then
                self.Weather:Open()
            else
                self.Weather:Close()
            end
        end)
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

    self:SetVisible(not self.Visible)
end

function Library:Open()
    self:SetVisible(true)
end

function Library:Close()
    self:SetVisible(false)
end

function Library:ToggleWeather()
    if self.Weather then
        self.Weather:Toggle()
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

    if self.MainTween then
        pcall(function()
            self.MainTween:Cancel()
        end)
    end

    if self.ScaleTween then
        pcall(function()
            self.ScaleTween:Cancel()
        end)
    end

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

    if Environment.__APR_LIBRARY_INSTANCE == self then
        Environment.__APR_LIBRARY_INSTANCE = nil
    end
end

return Library
