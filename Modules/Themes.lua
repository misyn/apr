local Themes = {}

Themes.Midnight = {
    Gradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 105, 132)),
        ColorSequenceKeypoint.new(0.38, Color3.fromRGB(52, 61, 79)),
        ColorSequenceKeypoint.new(0.72, Color3.fromRGB(31, 36, 49)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 19, 26))
    }),

    Base = Color3.fromRGB(19, 21, 28),
    Panel = Color3.fromRGB(28, 32, 42),
    Line = Color3.fromRGB(57, 65, 82),

    Text = Color3.fromRGB(244, 246, 251),
    Muted = Color3.fromRGB(174, 183, 201),
    Dim = Color3.fromRGB(125, 137, 159),

    Transparency = 0.75,
    Rotation = 38
}

return Themes
