
local Library = {}
Library.__index = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local WEATHER_URL = "https://raw.githubusercontent.com/misyn/apr/refs/heads/main/Modules/Weather.lua"

local MAIN_WIDTH = 600
local MAIN_HEIGHT = 550
local WEATHER_WIDTH = 320
local WEATHER_HEIGHT = 550

local MAIN_SCALE = 0.92
local WEATHER_SCALE = 0.92
local MAIN_GAP = 10

local LIGHT_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 119, 198)),
    ColorSequenceKeypoint.new(0.34, Color3.fromRGB(66, 166, 224)),
    ColorSequenceKeypoint.new(0.68, Color3.fromRGB(125, 204, 235)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 194, 112))
})

local DARK_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 39, 49)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 29, 39)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 19, 27))
})

local DEFAULT_GRADIENT = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 76, 139)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(35, 49, 91)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 28, 53))
})

local ATMOSPHERE_BASE = Color3.fromRGB(35, 119, 198)

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

local function getViewport()
    local camera = workspace.CurrentCamera

    if camera then
        return camera.ViewportSize
    end

    return Vector2.new(1600, 900)
end

-- Both windows use UIScale, so calculate their actual visual dimensions.
local function calculateLayout()
    local viewport = getViewport()

    local mainVisualWidth = MAIN_WIDTH * MAIN_SCALE
    local weatherVisualWidth = WEATHER_WIDTH * WEATHER_SCALE

    local totalWidth = mainVisualWidth + MAIN_GAP + weatherVisualWidth

    -- UIScale scales around the center of each frame.
    local mainX = (viewport.X - totalWidth) / 2
        - ((MAIN_WIDTH - mainVisualWidth) / 2)

    -- The main frame uses AnchorPoint (0, 1).
    -- This places its visual center at the screen's vertical center.
    local mainY = (viewport.Y + MAIN_HEIGHT) / 2

    return Vector2.new(
        math.floor(mainX),
        math.floor(mainY)
    )
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

local function colorToHex(color)
    return string.format(
        "#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function getGradientBrightness(sequence)
    if typeof(sequence) ~= "ColorSequence" then
        return 0.25
    end

    local total = 0
    local count = 0

    for _, point in ipairs(sequence.Keypoints) do
        local color = point.Value

        local brightness =
            color.R * 0.299
            + color.G * 0.587
            + color.B * 0.114

        total = total + brightness
        count = count + 1
    end

    if count == 0 then
        return 0.25
    end

    return total / count
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
    self.ThemeTween = nil

    self.AnimationToken = 0
    self.Dragging = false

    -- The negative offset compensates for the two UIScale objects.
    -- It gives a real visual gap of approximately MAIN_GAP pixels.
    self.WeatherOffset = Vector2.new(
        MAIN_WIDTH * MAIN_SCALE
        - MAIN_WIDTH
        + MAIN_GAP
        + ((WEATHER_WIDTH - WEATHER_WIDTH * WEATHER_SCALE) / 2),
        0
    )

    self.MainPosition = calculateLayout()

    if config.InitialPosition then
        self.MainPosition = Vector2.new(
            config.InitialPosition.X.Offset,
            config.InitialPosition.Y.Offset
        )
    end

    self.Gui = create("ScreenGui", {
        Name = "CustomUILibrary",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, parent)

    self.Main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0, 1),

        Position = UDim2.fromOffset(
            self.MainPosition.X,
            self.MainPosition.Y
        ),

        Size = UDim2.fromOffset(MAIN_WIDTH, 0),

        BackgroundColor3 = Color3.fromRGB(29, 30, 34),
        BackgroundTransparency = 0.05,

        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.Gui)

    self.MainScale = create("UIScale", {
        Scale = MAIN_SCALE
    }, self.Main)

    self.Atmosphere = create("Frame", {
        Name = "AtmosphericLighting",

        Size = UDim2.fromScale(1, 1),

        BackgroundColor3 = ATMOSPHERE_BASE,
        BackgroundTransparency = 0.48,

        BorderSizePixel = 0,
        ZIndex = 1
    }, self.Main)

    self.AtmosphereGradient = create("UIGradient", {
        Rotation = 45,
        Color = DEFAULT_GRADIENT
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
        Theme = self.MainTheme
    })

    -- Dragging

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

    -- Main keybind

    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed or self.Destroyed then
            return
        end

        if input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end))

    -- Weather alignment

    table.insert(self.Connections, self.Main:GetPropertyChangedSignal("Position"):Connect(function()
        if not self.Destroyed then
            self:AlignWeather()
        end
    end))

    table.insert(self.Connections, self.Main:GetPropertyChangedSignal("Size"):Connect(function()
        if not self.Destroyed then
            self:AlignWeather()
        end
    end))

    -- Screen resizing

    local function update_screen_layout()
        if self.Destroyed or self.Dragging then
            return
        end

        local position = calculateLayout()

        self.MainPosition = position

        self.Main.Position = UDim2.fromOffset(
            position.X,
            position.Y
        )

        self:AlignWeather()
    end

    local camera = workspace.CurrentCamera

    if camera then
        table.insert(
            self.Connections,
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(update_screen_layout)
        )
    end

    table.insert(
        self.Connections,
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if self.Destroyed then
                return
            end

            local newCamera = workspace.CurrentCamera

            if newCamera then
                table.insert(
                    self.Connections,
                    newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update_screen_layout)
                )

                update_screen_layout()
            end
        end)
    )

    Environment.__APR_LIBRARY_INSTANCE = self

    task.spawn(function()
        if not self.Destroyed then
            self:Animate(true)
        end
    end)

    self:LoadWeather(config.Weather or {})

    return self
end

-- =========================================
-- WEATHER POSITIONING
-- =========================================

function Library:AlignWeather()
    if self.Destroyed or not self.Main or not self.Weather then
        return
    end

    local weather = self.Weather

    if not weather.main then
        return
    end

    local mainPosition = self.Main.Position
    local mainSize = self.Main.Size

    local targetPosition = UDim2.new(
        mainPosition.X.Scale + mainSize.X.Scale,
        mainPosition.X.Offset + mainSize.X.Offset + self.WeatherOffset.X,

        mainPosition.Y.Scale,
        mainPosition.Y.Offset + self.WeatherOffset.Y
    )

    pcall(function()
        weather.main.AnchorPoint = Vector2.new(0, 1)
        weather.main.Position = targetPosition
    end)

    -- FollowMain is enabled once. Avoid repeatedly reconnecting
    -- the Weather module's position listeners.
    if not self.WeatherFollowing then
        self.WeatherFollowing = true

        if type(weather.SetFollowMain) == "function" then
            pcall(function()
                weather:SetFollowMain(true, self.WeatherOffset)
            end)
        end
    end
end

-- =========================================
-- THEME SYSTEM
-- =========================================

function Library:ApplyTheme(data)
    if self.Destroyed or not self.Main then
        return
    end

    data = data or {}

    local theme = data.Theme or self.MainTheme or "Sync"

    local color = data.Color
    local transparency = data.Transparency
    local rotation = data.Rotation or 45

    if theme == "Light" then
        color = LIGHT_GRADIENT
        transparency = 0.22

    elseif theme == "Dark" then
        color = DARK_GRADIENT
        transparency = 0.28

    elseif theme == "System" then
        color = color or DEFAULT_GRADIENT
        transparency = transparency or 0.48

    else
        -- Sync begins with the nighttime blue-grey gradient.
        -- The real weather preset replaces it once fetched.
        color = color or DEFAULT_GRADIENT
        transparency = transparency or 0.48
    end

    self.Atmosphere.BackgroundColor3 = ATMOSPHERE_BASE

    if color then
        self.AtmosphereGradient.Color = color
    end

    self.AtmosphereGradient.Rotation = rotation

    if self.ThemeTween then
        pcall(function()
            self.ThemeTween:Cancel()
        end)
    end

    self.ThemeTween = TweenService:Create(
        self.Atmosphere,

        TweenInfo.new(
            1.2,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut
        ),

        {
            BackgroundTransparency = transparency
        }
    )

    self.ThemeTween:Play()

    self.MainTheme = theme

    if self.ThemeLabel then
        self.ThemeLabel.Text = "THEME  " .. string.upper(theme)
    end
end

-- =========================================
-- WEATHER TEXT CONTRAST
-- =========================================

function Library:UpdateWeatherTextContrast(weather)
    if not weather or not weather.main then
        return
    end

    local gradient = weather.atmos_gradient

    if not gradient then
        return
    end

    local brightness = getGradientBrightness(gradient.Color)

    -- Light atmospheric colors need darker secondary text.
    -- Dark atmospheric colors need lighter secondary text.
    local muted
    local dim
    local clockMuted
    local clockSecondary

    if brightness >= 0.48 then
        muted = Color3.fromRGB(75, 83, 99)
        dim = Color3.fromRGB(99, 108, 124)

        clockMuted = Color3.fromRGB(85, 94, 111)
        clockSecondary = Color3.fromRGB(105, 114, 130)
    else
        muted = Color3.fromRGB(190, 197, 211)
        dim = Color3.fromRGB(151, 161, 181)

        clockMuted = Color3.fromRGB(169, 179, 199)
        clockSecondary = Color3.fromRGB(194, 202, 218)
    end

    local oldMuted = weather.colors and weather.colors.muted
    local oldDim = weather.colors and weather.colors.dim

    for _, object in ipairs(weather.main:GetDescendants()) do
        if object:IsA("TextLabel") then
            if oldMuted and object.TextColor3 == oldMuted then
                object.TextColor3 = muted

            elseif oldDim and object.TextColor3 == oldDim then
                object.TextColor3 = dim
            end
        end
    end

    -- The clock uses RichText colors, so update those separately.
    if weather.clock_label then
        local currentText = weather.clock_label.Text

        currentText = currentText:gsub(
            'color="#92949B"',
            'color="' .. colorToHex(clockMuted) .. '"'
        )

        currentText = currentText:gsub(
            'color="#B8BAC2"',
            'color="' .. colorToHex(clockSecondary) .. '"'
        )

        weather.clock_label.Text = currentText
    end

    -- Keep the original colors as references so subsequent updates
    -- can identify muted and dim labels reliably.
    if weather.colors then
        weather.colors.muted = muted
        weather.colors.dim = dim
    end
end

function Library:BindWeatherContrast(weather)
    if not weather then
        return
    end

    -- Wrap lighting updates so contrast follows every new preset.
    if type(weather.update_lighting) == "function" then
        local original = weather.update_lighting

        weather.update_lighting = function(module, ...)
            local results = {original(module, ...)}

            if not self.Destroyed then
                self:UpdateWeatherTextContrast(module)
            end

            return table.unpack(results)
        end
    end

    -- The clock refreshes frequently, so reapply the RichText colors
    -- after the Weather module writes its normal clock string.
    if type(weather.update_clock) == "function" then
        local original = weather.update_clock

        weather.update_clock = function(module, ...)
            local results = {original(module, ...)}

            if not self.Destroyed then
                self:UpdateWeatherTextContrast(module)
            end

            return table.unpack(results)
        end
    end

    self:UpdateWeatherTextContrast(weather)
end

-- =========================================
-- WEATHER INITIALIZATION
-- =========================================

function Library:LoadWeather(config)
    if self.Destroyed or config.Enabled == false then
        return
    end

    local moduleUrl = config.ModuleURL or WEATHER_URL
    local weather
    local receivedRealTheme = false

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

            FollowMain = true,
            Offset = self.WeatherOffset,

            InitialPosition = UDim2.fromOffset(
                self.Main.Position.X.Offset
                    + MAIN_WIDTH
                    + self.WeatherOffset.X,

                self.Main.Position.Y.Offset
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
                if self.Destroyed then
                    return
                end

                -- The Weather module sends a temporary DAY preset
                -- before fetching actual weather data. Ignore it.
                if not receivedRealTheme then
                    return
                end

                self:ApplyTheme(data)
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

        -- The initial Weather UI is created with a daytime gradient.
        -- Replace it immediately with the Sync nighttime gradient.
        -- Its real lighting update will take over after weather loads.
        if weather.atmos_gradient and weather.atmosphere then
            local weatherTheme = theme.Weather or "Sync"

            if weatherTheme == "Light" then
                weather.atmos_gradient.Color = LIGHT_GRADIENT
                weather.atmosphere.BackgroundTransparency = 0.22

            elseif weatherTheme == "Dark" then
                weather.atmos_gradient.Color = DARK_GRADIENT
                weather.atmosphere.BackgroundTransparency = 0.28

            else
                weather.atmos_gradient.Color = DEFAULT_GRADIENT
                weather.atmosphere.BackgroundTransparency = 0.48
            end
        end

        -- The initial callback has now been ignored. Subsequent
        -- updates are actual weather/time-based theme changes.
        receivedRealTheme = true

        -- Connect adaptive text contrast to the weather updater.
        self:BindWeatherContrast(weather)

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

    self:AlignWeather()

    return result
end

-- =========================================
-- OPEN / CLOSE ANIMATIONS
-- =========================================

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

        self.Main.Size = UDim2.fromOffset(MAIN_WIDTH, 0)
        self.MainScale.Scale = MAIN_SCALE

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
                Size = UDim2.fromOffset(MAIN_WIDTH, MAIN_HEIGHT)
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
                Scale = MAIN_SCALE
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
                Size = UDim2.fromOffset(MAIN_WIDTH, 0)
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
                Scale = MAIN_SCALE
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

-- =========================================
-- VISIBILITY
-- =========================================

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

    -- Main visibility is intentionally independent from Weather.
    -- Toggling the main window must never reopen or close Weather.
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

-- =========================================
-- WEATHER CONTROLS
-- =========================================

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

    if theme ~= "Sync"
        and theme ~= "System"
        and theme ~= "Light"
        and theme ~= "Dark" then

        return false
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
    self.WeatherOffset = offset or self.WeatherOffset

    if self.Weather then
        if type(self.Weather.SetFollowMain) == "function" then
            self.Weather:SetFollowMain(
                enabled == true,
                self.WeatherOffset
            )
        end

        self.WeatherFollowing = enabled == true

        if enabled then
            self:AlignWeather()
        end
    end
end

-- =========================================
-- DESTROY
-- =========================================

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

    if self.ThemeTween then
        pcall(function()
            self.ThemeTween:Cancel()
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
