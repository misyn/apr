
local Library = {}
Library.__index = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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

function Library.new(config)
    config = config or {}

    local self = setmetatable({}, Library)

    self.Destroyed = false
    self.Visible = true
    self.Keybind = config.Keybind or Enum.KeyCode.RightControl
    self.Modules = {}

    self.Gui = create("ScreenGui", {
        Name = "CustomUILibrary",
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

    self.Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            self._dragging = true
            self._dragStart = input.Position
            self._startPosition = self.Main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not self._dragging then
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
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = false
        end
    end)

    self._inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or self.Destroyed then
            return
        end

        if input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end)

    local weatherConfig = config.Weather or {}

    if weatherConfig.Enabled ~= false then
        local moduleUrl = weatherConfig.ModuleURL

        if moduleUrl and moduleUrl ~= "" then
            local success, result = pcall(function()
                local source = game:HttpGet(moduleUrl)
                local module = loadstring(source)()

                return module.new({
                    Gui = self.Gui,
                    MainWindow = self.Main,
                    FollowMain = weatherConfig.FollowMain ~= false,
                    Offset = weatherConfig.Offset or Vector2.new(340, 0),
                    Visible = weatherConfig.Visible ~= false,
                    Keybind = weatherConfig.Keybind or Enum.KeyCode.G,
                    Location = weatherConfig.Location or {},
                    Theme = weatherConfig.Theme or {}
                })
            end)

            if success then
                self.Weather = result
            else
                warn("Weather module failed to load: " .. tostring(result))
            end
        end
    end

    return self
end

function Library:SetKeybind(key)
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

function Library:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    if self._inputConnection then
        self._inputConnection:Disconnect()
    end

    if self.Weather and self.Weather.Destroy then
        self.Weather:Destroy()
    end

    if self.Gui then
        self.Gui:Destroy()
    end
end

return Library
