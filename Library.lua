
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
        local success, result = pcall(getgenv)
        if success and result then
            return result
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
        local success, result = pcall(function()
            object[property] = value
        end)

        if not success then
            object:Destroy()
            error(
                "Failed setting " .. tostring(property)
                .. " on " .. tostring(class)
                .. ": " .. tostring(result),
                2
            )
        end
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

local function getViewport()
    local camera = workspace.CurrentCamera

    if camera then
        return camera.ViewportSize
    end

    return Vector2.new(1280, 720)
end

function Library.new(config)
    config = config or {}

    if Environment.__APR_LIBRARY_INSTANCE then
        pcall(function()
            Environment.__APR_LIBRARY_INSTANCE:Destroy()
        end)
    end

    local parent = getParent()

    for _, name in ipairs({"CustomUILibrary", "MirrorDashboard"}) do
        local old = parent:FindFirstChild(name)

        if old then
            old:Destroy()
        end

        local playerOld = PlayerGui:FindFirstChild(name)

        if playerOld then
            playerOld:Destroy()
        end
    end

    local self = setmetatable({}, Library)

    self.Destroyed = false
    self.Visible = true
    self.Keybind = config.Keybind or Enum.KeyCode.RightControl
    self.Modules = {}
    self.Connections = {}

    self.MainTheme = (
        config.Weather
        and config.Weather.Theme
        and config.Weather.Theme.Main
    ) or "Sync"

    self.MainTween = nil
    self.ScaleTween = nil
    self.AnimationToken = 0
    self.Dragging = false

    local viewport = getViewport()
    local panelWidth = 320
    local panelHeight = 550
    local gap = 12
    local totalWidth = panelWidth * 2 + gap

    local left = math.max(12, math.floor((viewport.X - totalWidth) / 2))
    local bottom = math.floor((viewport.Y + panelHeight) / 2)

    self.MainPosition = Vector2.new(left, bottom)

    self.Gui = create("ScreenGui", {
        Name = "CustomUILibrary",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, parent)

    self.Main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromOffset(left, bottom),
        Size = UDim2.fromOffset(panelWidth, 0),
        BackgroundColor3 = Color3.fromRGB(29, 30, 34),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.Gui)

    self.MainScale = create("UIScale", {
        Scale = 0.92
    }, self.Main)

    self.Atmosphere = create("Frame", {
        Name = "AtmosphericLighting",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.48,
        BorderSizePixel = 0,
        ZIndex = 1
    }, self.Main)

    self.AtmosphereGradient = create("UIGradient", {
        Rotation = 45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
        })
    }, self.Atmosphere)

    self.Header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3
    }, self.Main)

    self.Title = create("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(23, 10),
        Size = UDim2.new(1, -46, 0, 23),
        BackgroundTransparency = 1,
        Text = config.Title or "APR Library",
        TextColor3 = Color3.fromRGB(239, 240, 244),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    }, self.Header)

    self.ThemeLabel = create("TextLabel", {
        Name = "ThemeLabel",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.fromOffset(115, 42),
        BackgroundTransparency = 1,
        Text = "THEME  " .. string.upper(self.MainTheme),
        TextColor3 = Color3.fromRGB(157, 160, 168),
        TextSize = 9,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4
    }, self.Header)

    self.Content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(14, 56),
        Size = UDim2.new(1, -28, 1, -70),
        BackgroundTransparency = 1,
        ZIndex = 3
    }, self.Main)

    self.FadeObjects = {
        self.Title,
        self.ThemeLabel
    }

    self:ApplyTheme({
        Theme = self.MainTheme,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
        }),
        Transparency = 0.48,
        Rotation = 45
    })

    table.insert(self.Connections, self.Header.InputBegan:Connect(function(input)
        if self.Destroyed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            self.Dragging = true
            self.DragStart = input.Position
            self.StartPosition = self.Main.Position
        end
    end))

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if self.Destroyed or not self.Dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - self.DragStart

            self.Main.Position = UDim2.new(
                self.StartPosition.X.Scale,
                self.StartPosition.X.Offset + delta.X,
                self.StartPosition.Y.Scale,
                self.StartPosition.Y.Offset + delta.Y
            )
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            self.Dragging = false
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

    task.spawn(function()
        if not self.Destroyed then
            self:Animate(true)
        end
    end)

    self:LoadWeather(
        config.Weather or {},
        left + panelWidth + gap,
        bottom
    )

    return self
end

function Library:ApplyTheme(data)
    if self.Destroyed or not self.Main then
        return
    end

    data = data or {}

    local theme = data.Theme or self.MainTheme or "Sync"
    local color = data.Color
    local transparency = data.Transparency or 0.48
    local rotation = data.Rotation or 45

    if theme == "Light" then
        color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 234, 241)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(205, 214, 228)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 192, 213))
        })

        transparency = 0.18

    elseif theme == "Dark" then
        color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 39, 49)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 29, 39)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 19, 27))
        })

        transparency = 0.28

    elseif theme == "System" then
        color = color or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
        })
    end

    if color then
        self.AtmosphereGradient.Color = color
    end

    self.AtmosphereGradient.Rotation = rotation

    TweenService:Create(
        self.Atmosphere,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {
            BackgroundTransparency = transparency
        }
    ):Play()

    self.MainTheme = theme
    self.ThemeLabel.Text = "THEME  " .. string.upper(theme)
end

function Library:LoadWeather(config, weatherRight, bottom)
    if self.Destroyed or config.Enabled == false then
        return
    end

    local moduleUrl = config.ModuleURL or WEATHER_URL
    local weather

    local success, result = xpcall(function()
        local source = game:HttpGet(moduleUrl)

        assert(
            type(source) == "string" and #source > 0,
            "Weather source is empty"
        )

        local compiled = loadstring(source)

        assert(
            type(compiled) == "function",
            "Weather module failed to compile"
        )

        local weatherModule = compiled()

        assert(
            type(weatherModule) == "table",
            "Weather module did not return a table"
        )

        assert(
            type(weatherModule.new) == "function",
            "Weather module has no constructor"
        )

        local location = config.Location or {}
        local theme = config.Theme or {}

        weather = weatherModule.new({
            Parent = getParent(),
            MainWindow = self.Main,

            FollowMain = config.FollowMain == true,
            Offset = config.Offset or Vector2.new(12, 0),
            InitialPosition = UDim2.fromOffset(
                weatherRight + 320,
                bottom
            ),

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
                Main = theme.Main or self.MainTheme or "Sync",
                Weather = theme.Weather or "Sync"
            },

            RefreshInterval = config.RefreshInterval or 300,
            Unit = config.Unit or "fahrenheit",
            WindUnit = config.WindUnit or "mph",

            OnMainThemeUpdate = function(data)
                if not self.Destroyed then
                    self:ApplyTheme(data)
                end
            end
        })

        assert(weather, "Weather constructor returned nil")

        assert(
            type(weather.start) == "function",
            "Weather module has no start method"
        )

        local started = weather:start()

        if started == false then
            error("Weather start returned false")
        end

        return weather
    end, function(err)
        return debug.traceback(tostring(err), 2)
    end)

    if not success then
        if weather then
            pcall(function()
                if type(weather.Destroy) == "function" then
                    weather:Destroy()
                end
            end)
        end

        warn("[APR] Weather initialization failed:\n" .. tostring(result))
        return nil
    end

    if self.Destroyed then
        pcall(function()
            if type(result.Destroy) == "function" then
                result:Destroy()
            end
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

    self.AnimationToken = self.AnimationToken + 1
    local token = self.AnimationToken

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

    if open then
        self.Main.Visible = true
        self.Main.Size = UDim2.fromOffset(320, 0)
        self.MainScale.Scale = 0.92

        for _, object in ipairs(self.FadeObjects) do
            object.TextTransparency = 1
        end

        self.MainTween = TweenService:Create(
            self.Main,
            TweenInfo.new(
                0.55,
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out
            ),
            {
                Size = UDim2.fromOffset(320, 550)
            }
        )

        self.ScaleTween = TweenService:Create(
            self.MainScale,
            TweenInfo.new(
                0.55,
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out
            ),
            {
                Scale = 0.92
            }
        )

        self.MainTween:Play()
        self.ScaleTween:Play()

        for _, object in ipairs(self.FadeObjects) do
            TweenService:Create(
                object,
                TweenInfo.new(
                    0.42,
                    Enum.EasingStyle.Quint,
                    Enum.EasingDirection.Out
                ),
                {
                    TextTransparency = 0
                }
            ):Play()
        end
    else
        self.MainTween = TweenService:Create(
            self.Main,
            TweenInfo.new(
                0.7,
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.In
            ),
            {
                Size = UDim2.fromOffset(320, 0)
            }
        )

        self.ScaleTween = TweenService:Create(
            self.MainScale,
            TweenInfo.new(
                0.7,
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.In
            ),
            {
                Scale = 0.92
            }
        )

        self.MainTween:Play()
        self.ScaleTween:Play()
    end

    self.MainTween.Completed:Wait()

    if self.Destroyed or token ~= self.AnimationToken then
        return
    end

    if not open then
        self.Main.Visible = false
    end
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
            if not self.Destroyed and self.Weather then
                self.Weather:SetVisible(value)
            end
        end)
    end
end

function Library:Toggle()
    self:SetVisible(not self.Visible)
end

function Library:Open()
    self:SetVisible(true)
end

function Library:Close()
    self:SetVisible(false)
end

function Library:SetKeybind(key)
    self.Keybind = key
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

    self.MainTheme = theme
    self:ApplyTheme({
        Theme = theme
    })

    return true
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
    self.AnimationToken = self.AnimationToken + 1
    self.Dragging = false

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
