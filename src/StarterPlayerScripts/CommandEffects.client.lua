--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts

        SM — "[ Server Message ]" header + message, centered 20% down
        IM — message only, centered 20% below screen centre (70% down)
        Both use edge-darkening vignette + background blur, fade in/out.
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

-- ─── Background blur ───────────────────────────────────────────────────────────
local blurEffect = Instance.new("BlurEffect")
blurEffect.Size   = 0
blurEffect.Parent = Lighting

-- ─── Vignette ──────────────────────────────────────────────────────────────────
-- Starts hidden (Visible=false). Set Visible=true only while a message shows.

local vigCanvas = Instance.new("CanvasGroup")
vigCanvas.Name                 = "Vignette"
vigCanvas.Size                 = UDim2.new(1, 0, 1, 0)
vigCanvas.Position             = UDim2.new(0, 0, 0, 0)
vigCanvas.BackgroundTransparency = 1
vigCanvas.GroupTransparency    = 1
vigCanvas.Visible              = false          -- hidden on spawn
vigCanvas.ZIndex               = 5
vigCanvas.Parent               = gui

local function makeVigFrame(size, position, anchor, rot)
        local f = Instance.new("Frame")
        f.Size                   = size
        f.Position               = position
        f.AnchorPoint            = anchor
        f.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        f.BackgroundTransparency = 0
        f.BorderSizePixel        = 0
        f.Parent                 = vigCanvas
        local g = Instance.new("UIGradient")
        g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,   0),
                NumberSequenceKeypoint.new(0.6, 0.7),
                NumberSequenceKeypoint.new(1,   1),
        })
        g.Rotation = rot
        g.Parent   = f
end

makeVigFrame(UDim2.new(1, 0, 0.5, 0),  UDim2.new(0, 0, 0, 0), Vector2.new(0, 0),  90)   -- top
makeVigFrame(UDim2.new(1, 0, 0.5, 0),  UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), -90)   -- bottom
makeVigFrame(UDim2.new(0.35, 0, 1, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0),   0)   -- left
makeVigFrame(UDim2.new(0.35, 0, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), 180)   -- right

-- ─── SM display (20% from top) ─────────────────────────────────────────────────
-- A container frame so header + body stack naturally

local smContainer = Instance.new("Frame")
smContainer.Name                  = "SMContainer"
smContainer.AnchorPoint           = Vector2.new(0.5, 0.5)
smContainer.Position              = UDim2.new(0.5, 0, 0.20, 0)
smContainer.Size                  = UDim2.new(0.70, 0, 0, 160)
smContainer.BackgroundTransparency = 1
smContainer.BorderSizePixel       = 0
smContainer.ZIndex                = 10
smContainer.Visible               = false
smContainer.Parent                = gui

local smLayout = Instance.new("UIListLayout")
smLayout.FillDirection    = Enum.FillDirection.Vertical
smLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
smLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
smLayout.Padding          = UDim.new(0, 8)
smLayout.SortOrder        = Enum.SortOrder.LayoutOrder
smLayout.Parent           = smContainer

-- Header: "[ Server Message ]"
local smHeader = Instance.new("TextLabel")
smHeader.Name                   = "Header"
smHeader.LayoutOrder            = 1
smHeader.Size                   = UDim2.new(1, 0, 0, 26)
smHeader.BackgroundTransparency = 1
smHeader.TextColor3             = Color3.fromRGB(200, 200, 200)
smHeader.TextTransparency       = 1
smHeader.TextSize               = 16
smHeader.FontFace               = Font.new(
        "rbxasset://fonts/families/Merriweather.json",
        Enum.FontWeight.Regular,
        Enum.FontStyle.Italic
)
smHeader.Text                   = "[ Server Message ]"
smHeader.TextXAlignment         = Enum.TextXAlignment.Center
smHeader.ZIndex                 = 10
smHeader.Parent                 = smContainer

local smHeaderStroke = Instance.new("UIStroke")
smHeaderStroke.Color        = Color3.fromRGB(0, 0, 0)
smHeaderStroke.Thickness    = 1
smHeaderStroke.Transparency = 1
smHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
smHeaderStroke.Parent       = smHeader

-- Body: the actual message
local smBody = Instance.new("TextLabel")
smBody.Name                   = "Body"
smBody.LayoutOrder            = 2
smBody.Size                   = UDim2.new(1, 0, 0, 120)
smBody.BackgroundTransparency = 1
smBody.TextColor3             = Color3.fromRGB(255, 255, 255)
smBody.TextTransparency       = 1
smBody.TextSize               = 46
smBody.FontFace               = Font.new(
        "rbxasset://fonts/families/Merriweather.json",
        Enum.FontWeight.Bold
)
smBody.Text                   = ""
smBody.TextWrapped            = true
smBody.TextXAlignment         = Enum.TextXAlignment.Center
smBody.TextYAlignment         = Enum.TextYAlignment.Center
smBody.ZIndex                 = 10
smBody.Parent                 = smContainer

local smBodyStroke = Instance.new("UIStroke")
smBodyStroke.Color        = Color3.fromRGB(0, 0, 0)
smBodyStroke.Thickness    = 1.5
smBodyStroke.Transparency = 1
smBodyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
smBodyStroke.Parent       = smBody

-- ─── IM display (70% down — 20% below screen centre) ──────────────────────────

local imLabel = Instance.new("TextLabel")
imLabel.Name                   = "IMText"
imLabel.AnchorPoint            = Vector2.new(0.5, 0.5)
imLabel.Position               = UDim2.new(0.5, 0, 0.70, 0)
imLabel.Size                   = UDim2.new(0.50, 0, 0, 100)
imLabel.BackgroundTransparency = 1
imLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
imLabel.TextTransparency       = 1
imLabel.TextSize               = 27
imLabel.FontFace               = Font.new(
        "rbxasset://fonts/families/Merriweather.json",
        Enum.FontWeight.Regular
)
imLabel.Text                   = ""
imLabel.TextWrapped            = true
imLabel.TextXAlignment         = Enum.TextXAlignment.Center
imLabel.TextYAlignment         = Enum.TextYAlignment.Center
imLabel.ZIndex                 = 10
imLabel.Visible                = false
imLabel.Parent                 = gui

local imStroke = Instance.new("UIStroke")
imStroke.Color        = Color3.fromRGB(0, 0, 0)
imStroke.Thickness    = 1
imStroke.Transparency = 1
imStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
imStroke.Parent       = imLabel

-- ─── Shared fade logic ─────────────────────────────────────────────────────────

local FADE_IN  = 0.65
local FADE_OUT = 0.70

local activeToken = {}

local function calcHold(text: string): number
        local words = select(2, text:gsub("%S+", "")) + 1
        return math.clamp(words * 0.4, 4, 10)
end

-- ─── SM show/hide ──────────────────────────────────────────────────────────────

local function showSM(text: string)
        local token = {}
        activeToken = token

        smBody.Text = text
        smContainer.Visible = true
        smContainer.GroupTransparency = 1    -- CanvasGroup not used here; use label transparency

        -- reset
        smHeader.TextTransparency  = 1
        smBody.TextTransparency    = 1
        smHeaderStroke.Transparency = 1
        smBodyStroke.Transparency  = 1
        vigCanvas.GroupTransparency = 1
        vigCanvas.Visible           = true
        blurEffect.Size             = 0

        -- fade in
        tw(vigCanvas,         FADE_IN, { GroupTransparency  = 0 })
        tw(blurEffect,        FADE_IN, { Size               = 7 })
        tw(smHeader,          FADE_IN, { TextTransparency   = 0.15 })
        tw(smBody,            FADE_IN, { TextTransparency   = 0 })
        tw(smHeaderStroke,    FADE_IN, { Transparency       = 0.55 })
        tw(smBodyStroke,      FADE_IN, { Transparency       = 0.45 })

        task.delay(FADE_IN + calcHold(text), function()
                if activeToken ~= token then return end

                tw(vigCanvas,      FADE_OUT, { GroupTransparency  = 1 })
                tw(blurEffect,     FADE_OUT, { Size               = 0 })
                tw(smHeader,       FADE_OUT, { TextTransparency   = 1 })
                tw(smBody,         FADE_OUT, { TextTransparency   = 1 })
                tw(smHeaderStroke, FADE_OUT, { Transparency       = 1 })
                tw(smBodyStroke,   FADE_OUT, { Transparency       = 1 })

                task.delay(FADE_OUT + 0.05, function()
                        if activeToken ~= token then return end
                        vigCanvas.Visible   = false
                        smContainer.Visible = false
                end)
        end)
end

-- ─── IM show/hide ──────────────────────────────────────────────────────────────

local function showIM(text: string)
        local token = {}
        activeToken = token

        imLabel.Text    = text
        imLabel.Visible = true
        imLabel.TextTransparency = 1
        imStroke.Transparency    = 1
        vigCanvas.GroupTransparency = 1
        vigCanvas.Visible           = true
        blurEffect.Size             = 0

        tw(vigCanvas,  FADE_IN, { GroupTransparency = 0.35 })
        tw(blurEffect, FADE_IN, { Size              = 3 })
        tw(imLabel,    FADE_IN, { TextTransparency  = 0 })
        tw(imStroke,   FADE_IN, { Transparency      = 0.55 })

        task.delay(FADE_IN + calcHold(text), function()
                if activeToken ~= token then return end

                tw(vigCanvas,  FADE_OUT, { GroupTransparency = 1 })
                tw(blurEffect, FADE_OUT, { Size              = 0 })
                tw(imLabel,    FADE_OUT, { TextTransparency  = 1 })
                tw(imStroke,   FADE_OUT, { Transparency      = 1 })

                task.delay(FADE_OUT + 0.05, function()
                        if activeToken ~= token then return end
                        vigCanvas.Visible = false
                        imLabel.Visible   = false
                end)
        end)
end

-- ─── Cancels the current display when a new message arrives ───────────────────
local function cancelCurrent()
        -- Overwrite the token so any pending delay becomes a no-op.
        -- Also immediately snap everything invisible so the new message
        -- starts from a clean state.
        activeToken = {}
        vigCanvas.GroupTransparency = 1
        vigCanvas.Visible           = false
        blurEffect.Size             = 0
        smContainer.Visible         = false
        smHeader.TextTransparency   = 1
        smBody.TextTransparency     = 1
        smHeaderStroke.Transparency = 1
        smBodyStroke.Transparency   = 1
        imLabel.Visible             = false
        imLabel.TextTransparency    = 1
        imStroke.Transparency       = 1
end

-- ─── Remote listeners ──────────────────────────────────────────────────────────

CommandRemotes.SM.OnClientEvent:Connect(function(message: string)
        if typeof(message) ~= "string" or message == "" then return end
        cancelCurrent()
        showSM(message)
end)

CommandRemotes.IM.OnClientEvent:Connect(function(message: string)
        if typeof(message) ~= "string" or message == "" then return end
        cancelCurrent()
        showIM(message)
end)

print("[CommandEffects] SM/IM display ready.")
