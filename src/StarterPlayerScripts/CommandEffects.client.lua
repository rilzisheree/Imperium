--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts

        Handles SM and IM message display:
          • SM — large white serif text, 20% down, dark vignette edges, blur background
          • IM — same position but smaller, lighter vignette, less blur
          • Both fade in smoothly and fade out after duration
          • No solid black box behind the text — only edge-to-center vignette
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CommandRemotes = require(ReplicatedStorage:WaitForChild("CommandRemotes"))

-- ─── Tween helper ──────────────────────────────────────────────────────────────
local function tw(target, time, props, style, dir)
        style = style or Enum.EasingStyle.Sine
        dir   = dir   or Enum.EasingDirection.InOut
        TweenService:Create(target, TweenInfo.new(time, style, dir), props):Play()
end

-- ─── Root ScreenGui ────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "CommandEffects"
gui.DisplayOrder    = 60
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.Parent          = PlayerGui

-- ─── Background blur (blurs the 3D world; UI stays sharp) ─────────────────────
local blurEffect = Instance.new("BlurEffect")
blurEffect.Size   = 0
blurEffect.Parent = Lighting

-- ─── Vignette (CanvasGroup lets us tween the whole group opacity) ──────────────
-- Dark edges that fade to transparent in the center — no box, just edge darkening.

local vigCanvas = Instance.new("CanvasGroup")
vigCanvas.Name                 = "Vignette"
vigCanvas.Size                 = UDim2.new(1, 0, 1, 0)
vigCanvas.Position             = UDim2.new(0, 0, 0, 0)
vigCanvas.BackgroundTransparency = 1
vigCanvas.GroupTransparency    = 1          -- starts invisible
vigCanvas.ZIndex               = 5
vigCanvas.Parent               = gui

local function makeVigFrame(size, position, anchorPoint, gradientRotation)
        local f = Instance.new("Frame")
        f.Size                   = size
        f.Position               = position
        f.AnchorPoint            = anchorPoint
        f.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        f.BackgroundTransparency = 0
        f.BorderSizePixel        = 0
        f.Parent                 = vigCanvas

        local g = Instance.new("UIGradient")
        g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),   -- opaque at edge
                NumberSequenceKeypoint.new(0.6, 0.7),
                NumberSequenceKeypoint.new(1, 1),   -- transparent at center
        })
        g.Rotation = gradientRotation
        g.Parent   = f
end

-- Top edge: opaque at top, transparent toward center
makeVigFrame(
        UDim2.new(1, 0, 0.5, 0),
        UDim2.new(0, 0, 0, 0),
        Vector2.new(0, 0),
        90   -- gradient direction: top → bottom
)

-- Bottom edge: opaque at bottom, transparent toward center
makeVigFrame(
        UDim2.new(1, 0, 0.5, 0),
        UDim2.new(0, 0, 1, 0),
        Vector2.new(0, 1),
        -90  -- gradient direction: bottom → top
)

-- Left edge: opaque at left, transparent toward center
makeVigFrame(
        UDim2.new(0.35, 0, 1, 0),
        UDim2.new(0, 0, 0, 0),
        Vector2.new(0, 0),
        0    -- gradient direction: left → right
)

-- Right edge: opaque at right, transparent toward center
makeVigFrame(
        UDim2.new(0.35, 0, 1, 0),
        UDim2.new(1, 0, 0, 0),
        Vector2.new(1, 0),
        180  -- gradient direction: right → left
)

-- ─── Message text label ────────────────────────────────────────────────────────

local msgLabel = Instance.new("TextLabel")
msgLabel.Name                   = "MessageText"
msgLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
-- centered horizontally, 20% down from top
msgLabel.Position               = UDim2.new(0.5, 0, 0.20, 0)
msgLabel.BackgroundTransparency = 1
msgLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
msgLabel.TextTransparency       = 1
msgLabel.TextWrapped            = true
msgLabel.TextXAlignment         = Enum.TextXAlignment.Center
msgLabel.TextYAlignment         = Enum.TextYAlignment.Center
msgLabel.RichText               = false
msgLabel.ZIndex                 = 10
msgLabel.Parent                 = gui

-- Subtle drop-shadow/outline for readability without a background box
local textStroke = Instance.new("UIStroke")
textStroke.Color        = Color3.fromRGB(0, 0, 0)
textStroke.Thickness    = 1.5
textStroke.Transparency = 1          -- starts invisible, tweened alongside text
textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
textStroke.Parent       = msgLabel

-- ─── Message configs ───────────────────────────────────────────────────────────

local CONFIG = {
        sm = {
                textSize       = 46,                                       -- big
                fontFace       = Font.new(
                        "rbxasset://fonts/families/Merriweather.json",
                        Enum.FontWeight.Bold
                ),
                labelWidth     = 0.70,                                     -- 70% screen width
                vigTarget      = 0.0,                                      -- fully visible vignette (darker)
                blurTarget     = 7,                                        -- stronger blur
                strokeOpacity  = 0.45,                                     -- subtle outline
        },
        im = {
                textSize       = 27,                                       -- medium/small
                fontFace       = Font.new(
                        "rbxasset://fonts/families/Merriweather.json",
                        Enum.FontWeight.Regular
                ),
                labelWidth     = 0.50,                                     -- 50% screen width (less space)
                vigTarget      = 0.35,                                     -- semi-visible vignette (lighter)
                blurTarget     = 3,                                        -- subtle blur
                strokeOpacity  = 0.55,
        },
}

-- ─── Show / hide logic ─────────────────────────────────────────────────────────

local FADE_IN  = 0.65
local FADE_OUT = 0.70

local activeToken = {}    -- cancels previous message when a new one arrives

local function calcHoldTime(text: string): number
        -- roughly 1 word per 0.4 seconds, minimum 4s, maximum 10s
        local wordCount = select(2, text:gsub("%S+", "")) + 1
        return math.clamp(wordCount * 0.4, 4, 10)
end

local function hideMessage(token)
        if activeToken ~= token then return end

        tw(vigCanvas,  FADE_OUT, { GroupTransparency  = 1 })
        tw(blurEffect, FADE_OUT, { Size               = 0 })
        tw(msgLabel,   FADE_OUT, { TextTransparency   = 1 })
        tw(textStroke, FADE_OUT, { Transparency       = 1 })
end

local function showMessage(text: string, kind: string)
        -- Cancel any current message
        local token = {}
        activeToken = token

        local cfg  = CONFIG[kind] or CONFIG.im
        local hold = calcHoldTime(text)

        -- Apply text styling
        msgLabel.Text     = text
        msgLabel.TextSize = cfg.textSize
        msgLabel.FontFace = cfg.fontFace
        msgLabel.Size     = UDim2.new(cfg.labelWidth, 0, 0, 200)

        -- Snap to invisible before tweening in
        vigCanvas.GroupTransparency = 1
        blurEffect.Size             = 0
        msgLabel.TextTransparency   = 1
        textStroke.Transparency     = 1

        -- Fade in
        tw(vigCanvas,  FADE_IN, { GroupTransparency  = cfg.vigTarget })
        tw(blurEffect, FADE_IN, { Size               = cfg.blurTarget })
        tw(msgLabel,   FADE_IN, { TextTransparency   = 0 })
        tw(textStroke, FADE_IN, { Transparency       = cfg.strokeOpacity })

        -- Auto-hide after hold period
        task.delay(FADE_IN + hold, function()
                hideMessage(token)
        end)
end

-- ─── Remote listeners ──────────────────────────────────────────────────────────

CommandRemotes.SM.OnClientEvent:Connect(function(message: string)
        if typeof(message) ~= "string" or message == "" then return end
        showMessage(message, "sm")
end)

CommandRemotes.IM.OnClientEvent:Connect(function(message: string)
        if typeof(message) ~= "string" or message == "" then return end
        showMessage(message, "im")
end)

print("[CommandEffects] SM/IM display ready.")
