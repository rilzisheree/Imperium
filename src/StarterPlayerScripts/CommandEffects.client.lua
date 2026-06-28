--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts

        SM — "[ Server Message ]" header line + message below it, 20% down, centred
        IM — message only, 70% down (20% below centre), centred
        Both: white serif text, fade in → hold → fade out. No background box. No vignette.
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

-- ─── Shared serif font ─────────────────────────────────────────────────────────
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

-- ─── SM — header label ────────────────────────────────────────────────────────
-- Sits slightly above the message body (15% down)

local smHeader = Instance.new("TextLabel")
smHeader.Name                   = "SMHeader"
smHeader.AnchorPoint            = Vector2.new(0.5, 1)      -- anchor bottom-centre
smHeader.Position               = UDim2.new(0.5, 0, 0.20, -6)  -- just above body
smHeader.Size                   = UDim2.new(0.70, 0, 0, 24)
smHeader.BackgroundTransparency = 1
smHeader.TextColor3             = Color3.fromRGB(210, 210, 210)
smHeader.TextTransparency       = 1
smHeader.TextSize               = 15
smHeader.FontFace               = FONT_ITALIC
smHeader.Text                   = "[ Server Message ]"
smHeader.TextXAlignment         = Enum.TextXAlignment.Center
smHeader.TextYAlignment         = Enum.TextYAlignment.Center
smHeader.ZIndex                 = 10
smHeader.Visible                = false
smHeader.Parent                 = gui

-- ─── SM — body label ──────────────────────────────────────────────────────────

local smBody = Instance.new("TextLabel")
smBody.Name                   = "SMBody"
smBody.AnchorPoint            = Vector2.new(0.5, 0)        -- anchor top-centre
smBody.Position               = UDim2.new(0.5, 0, 0.20, 6) -- just below header
smBody.Size                   = UDim2.new(0.70, 0, 0, 130)
smBody.BackgroundTransparency = 1
smBody.TextColor3             = Color3.fromRGB(255, 255, 255)
smBody.TextTransparency       = 1
smBody.TextSize               = 44
smBody.FontFace               = FONT_BOLD
smBody.Text                   = ""
smBody.TextWrapped            = true
smBody.TextScaled             = false
smBody.TextXAlignment         = Enum.TextXAlignment.Center
smBody.TextYAlignment         = Enum.TextYAlignment.Top
smBody.ZIndex                 = 10
smBody.Visible                = false
smBody.Parent                 = gui

-- ─── IM — single label ────────────────────────────────────────────────────────
-- 70% down = 20% below centre

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
imLabel.TextScaled             = false
imLabel.TextXAlignment         = Enum.TextXAlignment.Center
imLabel.TextYAlignment         = Enum.TextYAlignment.Center
imLabel.ZIndex                 = 10
imLabel.Visible                = false
imLabel.Parent                 = gui

-- ─── Timing ────────────────────────────────────────────────────────────────────

local FADE_IN  = 0.60
local FADE_OUT = 0.65

local function calcHold(text: string): number
        local words = select(2, text:gsub("%S+", "")) + 1
        return math.clamp(words * 0.45, 4, 10)
end

-- ─── Cancellation token ────────────────────────────────────────────────────────
-- Replaced by a new table reference on each new message so old delays no-op.

local activeToken = {}

local function cancelAll()
        activeToken = {}
        smHeader.Visible         = false
        smHeader.TextTransparency = 1
        smBody.Visible           = false
        smBody.TextTransparency  = 1
        imLabel.Visible          = false
        imLabel.TextTransparency = 1
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

        tw(smHeader, FADE_IN, { TextTransparency = 0.15 })
        tw(smBody,   FADE_IN, { TextTransparency = 0    })

        task.delay(FADE_IN + calcHold(text), function()
                if activeToken ~= token then return end
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

        tw(imLabel, FADE_IN, { TextTransparency = 0 })

        task.delay(FADE_IN + calcHold(text), function()
                if activeToken ~= token then return end
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
