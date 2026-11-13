local Themes = {}

Themes.Midnight = {
    Gradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(126, 134, 255)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(88, 101, 242)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(55, 65, 115)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(30, 34, 54)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 19, 29))
    }),

    Base = Color3.fromRGB(18, 20, 29),
    Panel = Color3.fromRGB(29, 32, 46),
    Line = Color3.fromRGB(67, 74, 105),

    Text = Color3.fromRGB(247, 247, 255),
    Muted = Color3.fromRGB(178, 184, 211),
    Dim = Color3.fromRGB(126, 135, 170),

    Accent = Color3.fromRGB(114, 125, 255),
    AccentLight = Color3.fromRGB(157, 164, 255),
    AccentDark = Color3.fromRGB(79, 91, 205),

    Highlight = Color3.fromRGB(184, 164, 255),

    Transparency = 0.75,
    Rotation = 38
}

Themes.Discord = {
    Gradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 101, 242)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(71, 82, 196)),
        ColorSequenceKeypoint.new(0.65, Color3.fromRGB(43, 48, 82)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 25, 38))
    }),

    Base = Color3.fromRGB(30, 31, 36),
    Panel = Color3.fromRGB(43, 45, 52),
    Line = Color3.fromRGB(62, 65, 76),

    Text = Color3.fromRGB(249, 249, 251),
    Muted = Color3.fromRGB(185, 187, 195),
    Dim = Color3.fromRGB(135, 139, 150),

    Accent = Color3.fromRGB(88, 101, 242),
    AccentLight = Color3.fromRGB(121, 132, 255),
    AccentDark = Color3.fromRGB(71, 82, 196),

    Highlight = Color3.fromRGB(163, 171, 255),

    Transparency = 0.75,
    Rotation = 38
}

return Themes
