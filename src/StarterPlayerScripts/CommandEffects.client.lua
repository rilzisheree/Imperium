--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts

        SM — edge vignette + "[ Server Message ]" header (large) + smaller message text, 20% down
        IM — edge vignette (lighter) + message text, 70% down (20% below centre)
        Vignette fades in/out by tweening BackgroundTransparency on each gradient frame.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CommandRemotes = require(ReplicatedStorage:WaitForChild("CommandRemotes"))

-- ─── Tween helper ──────────────────────────────────────────────────────────────
local function tw(target, time, props)
        TweenService:Create(
                target,
                TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                props
        ):Play()
end

-- ─── Root ScreenGui ────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "CommandEffects"
gui.DisplayOrder    = 60
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.Parent          = PlayerGui

-- ─── Fonts ─────────────────────────────────────────────────────────────────────
local FONT_BOLD = Font.new(
        "rbxasset://fonts/families/Merriweather.json",
        Enum.FontWeight.Bold,
        Enum.FontStyle.Normal
)
local FONT_ITALIC = Font.new(
        "rbxasset://fonts/families/Merriweather.json",
        Enum.FontWeight.Regular,
        Enum.FontStyle.Italic
)
local FONT_REG = Font.new(
        "rbxasset://fonts/families/Merriweather.json",
        Enum.FontWeight.Regular,
        Enum.FontStyle.Normal
)

-- ─── Vignette frames ───────────────────────────────────────────────────────────
-- BackgroundTransparency is tweened 1→target to fade in, target→1 to fade out.
-- UIGradient makes each frame opaque at its edge and transparent toward centre.
-- When BackgroundTransparency=1 the whole frame is invisible; at 0 it is fully dark.

local vigFrames = {}   -- list of all 4 frames so we can tween them together

local function makeVigFrame(size, position, anchor, gradRot)
        local f = Instance.new("Frame")
        f.Size                   = size
        f.Position               = position
        f.AnchorPoint            = anchor
        f.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        f.BackgroundTransparency = 1           -- starts invisible
        f.BorderSizePixel        = 0
        f.ZIndex                 = 4
        f.Parent                 = gui

        local g = Instance.new("UIGradient")
        g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,    0.55),  -- very faint at edge
                NumberSequenceKeypoint.new(0.4,  0.85),
                NumberSequenceKeypoint.new(1,    1),     -- transparent toward centre
        })
        g.Rotation = gradRot
        g.Parent   = f

        table.insert(vigFrames, f)
        return f
end

makeVigFrame(UDim2.new(1, 0, 0.48, 0),  UDim2.new(0, 0, 0, 0), Vector2.new(0, 0),  90)   -- top
makeVigFrame(UDim2.new(1, 0, 0.48, 0),  UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), -90)   -- bottom
makeVigFrame(UDim2.new(0.32, 0, 1, 0),  UDim2.new(0, 0, 0, 0), Vector2.new(0, 0),   0)   -- left
makeVigFrame(UDim2.new(0.32, 0, 1, 0),  UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), 180)   -- right

local function tweenVig(target, time)
        for _, f in vigFrames do
                tw(f, time, { BackgroundTransparency = target })
        end
end

-- ─── SM labels ─────────────────────────────────────────────────────────────────
-- Header is big; message body is smaller underneath it.

local smHeader = Instance.new("TextLabel")
smHeader.Name                   = "SMHeader"
smHeader.AnchorPoint            = Vector2.new(0.5, 1)
smHeader.Position               = UDim2.new(0.5, 0, 0.20, -4)
smHeader.Size                   = UDim2.new(0.75, 0, 0, 38)
smHeader.BackgroundTransparency = 1
smHeader.TextColor3             = Color3.fromRGB(255, 255, 255)
smHeader.TextTransparency       = 1
smHeader.TextSize               = 36              -- bigger header
smHeader.FontFace               = FONT_ITALIC
smHeader.Text                   = "[ Server Message ]"
smHeader.TextXAlignment         = Enum.TextXAlignment.Center
smHeader.TextYAlignment         = Enum.TextYAlignment.Center
smHeader.ZIndex                 = 10
smHeader.Visible                = false
smHeader.Parent                 = gui

local smBody = Instance.new("TextLabel")
smBody.Name                   = "SMBody"
smBody.AnchorPoint            = Vector2.new(0.5, 0)
smBody.Position               = UDim2.new(0.5, 0, 0.20, 4)
smBody.Size                   = UDim2.new(0.70, 0, 0, 110)
smBody.BackgroundTransparency = 1
smBody.TextColor3             = Color3.fromRGB(255, 255, 255)
smBody.TextTransparency       = 1
smBody.TextSize               = 28              -- smaller body text
smBody.FontFace               = FONT_REG
smBody.Text                   = ""
smBody.TextWrapped            = true
smBody.TextScaled             = false
smBody.TextXAlignment         = Enum.TextXAlignment.Center
smBody.TextYAlignment         = Enum.TextYAlignment.Top
smBody.ZIndex                 = 10
smBody.Visible                = false
smBody.Parent                 = gui

-- ─── IM label ──────────────────────────────────────────────────────────────────

local imLabel = Instance.new("TextLabel")
imLabel.Name                   = "IMLabel"
imLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
imLabel.Position               = UDim2.new(0.5, 0, 0.70, 0)
imLabel.Size                   = UDim2.new(0.50, 0, 0, 100)
imLabel.BackgroundTransparency = 1
imLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
imLabel.TextTransparency       = 1
imLabel.TextSize               = 27
imLabel.FontFace               = FONT_REG
imLabel.Text                   = ""
imLabel.TextWrapped            = true
imLabel.TextXAlignment         = Enum.TextXAlignment.Center
imLabel.TextYAlignment         = Enum.TextYAlignment.Center
imLabel.ZIndex                 = 10
imLabel.Visible                = false
imLabel.Parent                 = gui

-- ─── Timing & hold ─────────────────────────────────────────────────────────────

local FADE_IN  = 0.60
local FADE_OUT = 0.65

local function calcHold(text: string): number
        local words = select(2, text:gsub("%S+", "")) + 1
        return math.clamp(words * 0.45, 4, 10)
end

-- ─── Cancellation ──────────────────────────────────────────────────────────────

local activeToken = {}

local function cancelAll()
        activeToken = {}
        -- snap everything invisible immediately
        for _, f in vigFrames do f.BackgroundTransparency = 1 end
        smHeader.Visible          = false
        smHeader.TextTransparency = 1
        smBody.Visible            = false
        smBody.TextTransparency   = 1
        imLabel.Visible           = false
        imLabel.TextTransparency  = 1
end

-- ─── SM ────────────────────────────────────────────────────────────────────────

local function showSM(text: string)
        cancelAll()
        local token = {}
        activeToken = token

        smBody.Text = text
        smHeader.Visible          = true
        smHeader.TextTransparency = 1
        smBody.Visible            = true
        smBody.TextTransparency   = 1

        -- vignette SM: barely-there edge (target 0.82)
        tweenVig(0.82, FADE_IN)
        tw(smHeader, FADE_IN, { TextTransparency = 0.10 })
        tw(smBody,   FADE_IN, { TextTransparency = 0    })

        task.delay(FADE_IN + calcHold(text), function()
                if activeToken ~= token then return end
                tweenVig(1, FADE_OUT)
                tw(smHeader, FADE_OUT, { TextTransparency = 1 })
                tw(smBody,   FADE_OUT, { TextTransparency = 1 })
                task.delay(FADE_OUT + 0.05, function()
                        if activeToken ~= token then return end
                        smHeader.Visible = false
                        smBody.Visible   = false
                end)
        end)
end

-- ─── IM ────────────────────────────────────────────────────────────────────────

local function showIM(text: string)
        cancelAll()
        local token = {}
        activeToken = token

        imLabel.Text             = text
        imLabel.Visible          = true
        imLabel.TextTransparency = 1

        -- vignette IM: barely-there edge (target 0.90)
        tweenVig(0.90, FADE_IN)
        tw(imLabel, FADE_IN, { TextTransparency = 0 })

        task.delay(FADE_IN + calcHold(text), function()
                if activeToken ~= token then return end
                tweenVig(1, FADE_OUT)
                tw(imLabel, FADE_OUT, { TextTransparency = 1 })
                task.delay(FADE_OUT + 0.05, function()
                        if activeToken ~= token then return end
                        imLabel.Visible = false
                end)
        end)
end

-- ─── Remote listeners ──────────────────────────────────────────────────────────

CommandRemotes.SM.OnClientEvent:Connect(function(message: string)
        if typeof(message) ~= "string" or message == "" then return end
        showSM(message)
end)

CommandRemotes.IM.OnClientEvent:Connect(function(message: string)
        if typeof(message) ~= "string" or message == "" then return end
        showIM(message)
end)

print("[CommandEffects] Ready.")
