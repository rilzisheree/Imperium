--[[
        CommandEffects.client.lua
        LocalScript — StarterPlayerScripts

        Handles all client-side visual and gameplay effects fired by the server:
          • blind / unblind overlay
          • sm  — server message narration bar (bottom screen, serif font, all players)
          • im  — individual message (same style as sm, targeted)
          • pm  — private message (middle screen, fades in/out)
          • notif — notification with sender name (bottom right)
          • countdown — left-side countdown display
          • esp — ESP overlay (names, health, distance)
          • fly — flight controller (E to toggle, Alt to speed up)
          • watch — camera POV switch
          • chatlogs — scrollable chat log panel
          • helpUI — staff help request panel
          • help — receive incoming help requests
          • music — server-wide music playback
          • waypoints — world-space waypoint markers
--]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

local CommandRemotes = require(ReplicatedStorage:WaitForChild("CommandRemotes"))

-- ─── Tween helper ──────────────────────────────────────────────────────────────
local function tw(target, time, props, style, dir)
        style = style or Enum.EasingStyle.Quint
        dir   = dir   or Enum.EasingDirection.Out
        TweenService:Create(target, TweenInfo.new(time, style, dir), props):Play()
end

-- ─── Root ScreenGui ────────────────────────────────────────────────────────────
local effectsGui = Instance.new("ScreenGui")
effectsGui.Name            = "CommandEffects"
effectsGui.DisplayOrder    = 60
effectsGui.ResetOnSpawn    = false
effectsGui.IgnoreGuiInset  = true
effectsGui.Parent          = PlayerGui

-- ══════════════════════════════════════════════════════════════════════════════
-- BLIND OVERLAY
-- ══════════════════════════════════════════════════════════════════════════════

local blindFrame = Instance.new("Frame")
blindFrame.Name                  = "BlindOverlay"
blindFrame.Size                  = UDim2.new(1, 0, 1, 0)
blindFrame.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
blindFrame.BackgroundTransparency = 1
blindFrame.BorderSizePixel       = 0
blindFrame.ZIndex                = 100
blindFrame.Visible               = false
blindFrame.Parent                = effectsGui

CommandRemotes.Blind.OnClientEvent:Connect(function(isBlind: boolean)
        if isBlind then
                blindFrame.Visible               = true
                blindFrame.BackgroundTransparency = 1
                tw(blindFrame, 0.4, { BackgroundTransparency = 0 })
        else
                tw(blindFrame, 0.4, { BackgroundTransparency = 1 })
                task.delay(0.45, function()
                        blindFrame.Visible = false
                end)
        end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVER MESSAGE (sm) & INDIVIDUAL MESSAGE (im)
-- Bottom of screen — black bar, white serif text, yellow-green accent line
-- ══════════════════════════════════════════════════════════════════════════════

local SM_HOLD   = 5.5   -- seconds to hold before fade-out
local SM_FADE   = 0.7   -- fade duration
local SM_ENTER  = 0.55

-- Outer bar
local smBar = Instance.new("Frame")
smBar.Name                  = "SMBar"
smBar.AnchorPoint           = Vector2.new(0, 1)
smBar.Size                  = UDim2.new(1, 0, 0, 110)
smBar.Position              = UDim2.new(0, 0, 1, 120)  -- starts off-screen
smBar.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
smBar.BackgroundTransparency = 0
smBar.BorderSizePixel       = 0
smBar.ZIndex                = 50
smBar.Visible               = false
smBar.Parent                = effectsGui

-- Yellow-green accent line at very bottom of the bar
local smAccent = Instance.new("Frame")
smAccent.Name                  = "Accent"
smAccent.AnchorPoint           = Vector2.new(0, 1)
smAccent.Size                  = UDim2.new(1, 0, 0, 3)
smAccent.Position              = UDim2.new(0, 0, 1, 0)
smAccent.BackgroundColor3      = Color3.fromRGB(196, 230, 0)   -- yellow-green as in photo
smAccent.BackgroundTransparency = 0
smAccent.BorderSizePixel       = 0
smAccent.ZIndex                = 51
smAccent.Parent                = smBar

-- Message text
local smLabel = Instance.new("TextLabel")
smLabel.Name                  = "SMText"
smLabel.AnchorPoint           = Vector2.new(0.5, 0.5)
smLabel.Size                  = UDim2.new(0.85, 0, 1, -10)
smLabel.Position              = UDim2.new(0.5, 0, 0.5, -4)
smLabel.BackgroundTransparency = 1
smLabel.Font                  = Enum.Font.Merriweather
smLabel.TextSize              = 26
smLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
smLabel.TextTransparency      = 0
smLabel.TextXAlignment        = Enum.TextXAlignment.Center
smLabel.TextYAlignment        = Enum.TextYAlignment.Center
smLabel.TextWrapped           = true
smLabel.RichText              = false
smLabel.ZIndex                = 52
smLabel.Parent                = smBar

local smThread: thread? = nil

local function showSMBar(message: string)
        if smThread then task.cancel(smThread) end

        smLabel.Text                  = message
        smLabel.TextTransparency      = 1
        smBar.BackgroundTransparency  = 1
        smAccent.BackgroundTransparency = 1
        smBar.Visible                 = true
        smBar.Position                = UDim2.new(0, 0, 1, 110)

        -- Slide up + fade in
        tw(smBar,    SM_ENTER, { Position = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        tw(smBar,    SM_ENTER, { BackgroundTransparency = 0 })
        tw(smAccent, SM_ENTER, { BackgroundTransparency = 0 })
        tw(smLabel,  SM_ENTER, { TextTransparency = 0 })

        smThread = task.spawn(function()
                task.wait(SM_ENTER + SM_HOLD)
                tw(smBar,    SM_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(smAccent, SM_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(smLabel,  SM_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.wait(SM_FADE + 0.05)
                smBar.Visible = false
        end)
end

CommandRemotes.SM.OnClientEvent:Connect(function(message: string)
        showSMBar(message)
end)

CommandRemotes.IM.OnClientEvent:Connect(function(message: string)
        showSMBar(message)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- PRIVATE MESSAGE (pm)
-- Middle of screen — semi-transparent pill, fades in and out
-- ══════════════════════════════════════════════════════════════════════════════

local PM_HOLD  = 5
local PM_FADE  = 0.5

local pmFrame = Instance.new("Frame")
pmFrame.Name                  = "PMFrame"
pmFrame.AnchorPoint           = Vector2.new(0.5, 0.5)
pmFrame.Size                  = UDim2.new(0, 480, 0, 64)
pmFrame.Position              = UDim2.new(0.5, 0, 0.48, 0)
pmFrame.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
pmFrame.BackgroundTransparency = 1
pmFrame.BorderSizePixel       = 0
pmFrame.ZIndex                = 55
pmFrame.Visible               = false
pmFrame.Parent                = effectsGui

local pmCorner = Instance.new("UICorner")
pmCorner.CornerRadius = UDim.new(0, 10)
pmCorner.Parent = pmFrame

local pmSender = Instance.new("TextLabel")
pmSender.Name                  = "Sender"
pmSender.Size                  = UDim2.new(1, 0, 0, 18)
pmSender.Position              = UDim2.new(0, 0, 0, 6)
pmSender.BackgroundTransparency = 1
pmSender.Font                  = Enum.Font.GothamBold
pmSender.TextSize              = 11
pmSender.TextColor3            = Color3.fromRGB(180, 180, 200)
pmSender.TextTransparency      = 1
pmSender.TextXAlignment        = Enum.TextXAlignment.Center
pmSender.Text                  = ""
pmSender.ZIndex                = 56
pmSender.Parent                = pmFrame

local pmLabel = Instance.new("TextLabel")
pmLabel.Name                  = "Message"
pmLabel.Size                  = UDim2.new(1, -40, 1, -28)
pmLabel.Position              = UDim2.new(0, 20, 0, 22)
pmLabel.BackgroundTransparency = 1
pmLabel.Font                  = Enum.Font.GothamSemibold
pmLabel.TextSize              = 17
pmLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
pmLabel.TextTransparency      = 1
pmLabel.TextXAlignment        = Enum.TextXAlignment.Center
pmLabel.TextYAlignment        = Enum.TextYAlignment.Center
pmLabel.TextWrapped           = true
pmLabel.ZIndex                = 56
pmLabel.Parent                = pmFrame

local pmThread: thread? = nil

CommandRemotes.PM.OnClientEvent:Connect(function(senderName: string, message: string)
        if pmThread then task.cancel(pmThread) end

        pmSender.Text = "from " .. senderName:upper()
        pmLabel.Text  = message
        pmFrame.Visible = true

        tw(pmFrame,  PM_FADE, { BackgroundTransparency = 0.25 })
        tw(pmSender, PM_FADE, { TextTransparency = 0 })
        tw(pmLabel,  PM_FADE, { TextTransparency = 0 })

        pmThread = task.spawn(function()
                task.wait(PM_FADE + PM_HOLD)
                tw(pmFrame,  PM_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(pmSender, PM_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(pmLabel,  PM_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.wait(PM_FADE + 0.05)
                pmFrame.Visible = false
        end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- NOTIFICATION (notif)
-- Bottom of screen — shows sender name + message, fades in/out
-- ══════════════════════════════════════════════════════════════════════════════

local NOTIF_HOLD = 5
local NOTIF_FADE = 0.45

local notifFrame = Instance.new("Frame")
notifFrame.Name                  = "NotifFrame"
notifFrame.AnchorPoint           = Vector2.new(0.5, 1)
notifFrame.Size                  = UDim2.new(0, 400, 0, 60)
notifFrame.Position              = UDim2.new(0.5, 0, 1, -30)
notifFrame.BackgroundColor3      = Color3.fromRGB(12, 12, 14)
notifFrame.BackgroundTransparency = 1
notifFrame.BorderSizePixel       = 0
notifFrame.ZIndex                = 56
notifFrame.Visible               = false
notifFrame.Parent                = effectsGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 10)
notifCorner.Parent = notifFrame

local notifStroke = Instance.new("UIStroke")
notifStroke.Color        = Color3.fromRGB(90, 90, 110)
notifStroke.Thickness    = 1.5
notifStroke.Transparency = 1
notifStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
notifStroke.Parent = notifFrame

local notifAccentBar = Instance.new("Frame")
notifAccentBar.Name                  = "AccentBar"
notifAccentBar.Size                  = UDim2.new(0, 3, 1, -12)
notifAccentBar.Position              = UDim2.new(0, 8, 0, 6)
notifAccentBar.BackgroundColor3      = Color3.fromRGB(196, 230, 0)
notifAccentBar.BackgroundTransparency = 1
notifAccentBar.BorderSizePixel       = 0
notifAccentBar.ZIndex                = 57
notifAccentBar.Parent                = notifFrame

local notifAccentCorner = Instance.new("UICorner")
notifAccentCorner.CornerRadius = UDim.new(0, 2)
notifAccentCorner.Parent = notifAccentBar

local notifSenderLabel = Instance.new("TextLabel")
notifSenderLabel.Name                  = "Sender"
notifSenderLabel.Size                  = UDim2.new(1, -24, 0, 16)
notifSenderLabel.Position              = UDim2.new(0, 20, 0, 8)
notifSenderLabel.BackgroundTransparency = 1
notifSenderLabel.Font                  = Enum.Font.GothamBold
notifSenderLabel.TextSize              = 10
notifSenderLabel.TextColor3            = Color3.fromRGB(196, 230, 0)
notifSenderLabel.TextTransparency      = 1
notifSenderLabel.TextXAlignment        = Enum.TextXAlignment.Left
notifSenderLabel.Text                  = ""
notifSenderLabel.ZIndex                = 57
notifSenderLabel.Parent                = notifFrame

local notifMsgLabel = Instance.new("TextLabel")
notifMsgLabel.Name                  = "Message"
notifMsgLabel.Size                  = UDim2.new(1, -24, 1, -30)
notifMsgLabel.Position              = UDim2.new(0, 20, 0, 26)
notifMsgLabel.BackgroundTransparency = 1
notifMsgLabel.Font                  = Enum.Font.GothamSemibold
notifMsgLabel.TextSize              = 14
notifMsgLabel.TextColor3            = Color3.fromRGB(230, 230, 240)
notifMsgLabel.TextTransparency      = 1
notifMsgLabel.TextXAlignment        = Enum.TextXAlignment.Left
notifMsgLabel.TextWrapped           = true
notifMsgLabel.Text                  = ""
notifMsgLabel.ZIndex                = 57
notifMsgLabel.Parent                = notifFrame

local notifThread: thread? = nil

CommandRemotes.Notif.OnClientEvent:Connect(function(senderName: string, message: string)
        if notifThread then task.cancel(notifThread) end

        notifSenderLabel.Text = senderName:upper()
        notifMsgLabel.Text    = message
        notifFrame.Visible    = true

        tw(notifFrame,       NOTIF_FADE, { BackgroundTransparency = 0.08 })
        tw(notifStroke,      NOTIF_FADE, { Transparency = 0.2 })
        tw(notifAccentBar,   NOTIF_FADE, { BackgroundTransparency = 0 })
        tw(notifSenderLabel, NOTIF_FADE, { TextTransparency = 0 })
        tw(notifMsgLabel,    NOTIF_FADE, { TextTransparency = 0 })

        notifThread = task.spawn(function()
                task.wait(NOTIF_FADE + NOTIF_HOLD)
                tw(notifFrame,       NOTIF_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(notifStroke,      NOTIF_FADE, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(notifAccentBar,   NOTIF_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(notifSenderLabel, NOTIF_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tw(notifMsgLabel,    NOTIF_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.wait(NOTIF_FADE + 0.05)
                notifFrame.Visible = false
        end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- COUNTDOWN
-- Left side of screen — large countdown number
-- ══════════════════════════════════════════════════════════════════════════════

local cdFrame = Instance.new("Frame")
cdFrame.Name                  = "Countdown"
cdFrame.AnchorPoint           = Vector2.new(0, 0.5)
cdFrame.Size                  = UDim2.new(0, 120, 0, 120)
cdFrame.Position              = UDim2.new(0, 30, 0.5, 0)
cdFrame.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
cdFrame.BackgroundTransparency = 0.4
cdFrame.BorderSizePixel       = 0
cdFrame.ZIndex                = 55
cdFrame.Visible               = false
cdFrame.Parent                = effectsGui

local cdCorner = Instance.new("UICorner")
cdCorner.CornerRadius = UDim.new(0, 16)
cdCorner.Parent = cdFrame

local cdStroke = Instance.new("UIStroke")
cdStroke.Color        = Color3.fromRGB(196, 230, 0)
cdStroke.Thickness    = 2
cdStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
cdStroke.Parent = cdFrame

local cdLabel = Instance.new("TextLabel")
cdLabel.Name                  = "Number"
cdLabel.Size                  = UDim2.new(1, 0, 0.7, 0)
cdLabel.Position              = UDim2.new(0, 0, 0.05, 0)
cdLabel.BackgroundTransparency = 1
cdLabel.Font                  = Enum.Font.GothamBold
cdLabel.TextSize              = 58
cdLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
cdLabel.TextXAlignment        = Enum.TextXAlignment.Center
cdLabel.TextYAlignment        = Enum.TextYAlignment.Center
cdLabel.ZIndex                = 56
cdLabel.Parent                = cdFrame

local cdSubLabel = Instance.new("TextLabel")
cdSubLabel.Name                  = "Sub"
cdSubLabel.Size                  = UDim2.new(1, 0, 0.25, 0)
cdSubLabel.Position              = UDim2.new(0, 0, 0.75, 0)
cdSubLabel.BackgroundTransparency = 1
cdSubLabel.Font                  = Enum.Font.Gotham
cdSubLabel.TextSize              = 11
cdSubLabel.TextColor3            = Color3.fromRGB(160, 160, 170)
cdSubLabel.TextXAlignment        = Enum.TextXAlignment.Center
cdSubLabel.Text                  = "COUNTDOWN"
cdSubLabel.ZIndex                = 56
cdSubLabel.Parent                = cdFrame

local cdThread: thread? = nil

CommandRemotes.Countdown.OnClientEvent:Connect(function(seconds: number)
        if cdThread then task.cancel(cdThread) end

        cdFrame.Visible = true
        tw(cdFrame, 0.3, { BackgroundTransparency = 0.4 })

        cdThread = task.spawn(function()
                for i = seconds, 0, -1 do
                        cdLabel.Text = tostring(i)

                        -- Pulse effect
                        cdLabel.TextSize = 70
                        tw(cdLabel, 0.25, { TextSize = 58 })

                        if i == 0 then
                                cdLabel.TextColor3 = Color3.fromRGB(196, 230, 0)
                                task.wait(1)
                                tw(cdFrame, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                                task.wait(0.6)
                                cdFrame.Visible = false
                                cdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        else
                                task.wait(1)
                        end
                end
        end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ESP — player info overlay (BillboardGui per character)
-- Shows: DisplayName, @Username, health bar, distance
-- ══════════════════════════════════════════════════════════════════════════════

local espEnabled = false
local espBoards: { [string]: BillboardGui } = {}

local function buildESPBoard(player: Player): BillboardGui?
        local char = player.Character
        if not char then return nil end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        -- Remove old board if exists
        if espBoards[player.Name] then
                espBoards[player.Name]:Destroy()
        end

        local board = Instance.new("BillboardGui")
        board.Name            = "ESP_" .. player.Name
        board.Size            = UDim2.new(0, 180, 0, 70)
        board.StudsOffset     = Vector3.new(0, 3.2, 0)
        board.AlwaysOnTop     = true
        board.Adornee         = hrp
        board.Parent          = hrp

        local bg = Instance.new("Frame")
        bg.Size                  = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.45
        bg.BorderSizePixel       = 0
        bg.Parent                = board

        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(0, 6)
        bgCorner.Parent = bg

        local displayLabel = Instance.new("TextLabel")
        displayLabel.Name                  = "DisplayName"
        displayLabel.Size                  = UDim2.new(1, -10, 0, 20)
        displayLabel.Position              = UDim2.new(0, 5, 0, 4)
        displayLabel.BackgroundTransparency = 1
        displayLabel.Font                  = Enum.Font.GothamBold
        displayLabel.TextSize              = 13
        displayLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
        displayLabel.TextXAlignment        = Enum.TextXAlignment.Left
        displayLabel.Text                  = player.DisplayName
        displayLabel.Parent                = bg

        local userLabel = Instance.new("TextLabel")
        userLabel.Name                  = "Username"
        userLabel.Size                  = UDim2.new(1, -10, 0, 14)
        userLabel.Position              = UDim2.new(0, 5, 0, 21)
        userLabel.BackgroundTransparency = 1
        userLabel.Font                  = Enum.Font.Gotham
        userLabel.TextSize              = 10
        userLabel.TextColor3            = Color3.fromRGB(160, 160, 180)
        userLabel.TextXAlignment        = Enum.TextXAlignment.Left
        userLabel.Text                  = "@" .. player.Name
        userLabel.Parent                = bg

        -- Health bar background
        local hpBg = Instance.new("Frame")
        hpBg.Name                  = "HPBg"
        hpBg.Size                  = UDim2.new(1, -10, 0, 6)
        hpBg.Position              = UDim2.new(0, 5, 0, 38)
        hpBg.BackgroundColor3      = Color3.fromRGB(60, 60, 60)
        hpBg.BorderSizePixel       = 0
        hpBg.Parent                = bg

        local hpCorner = Instance.new("UICorner")
        hpCorner.CornerRadius = UDim.new(0, 3)
        hpCorner.Parent = hpBg

        local hpBar = Instance.new("Frame")
        hpBar.Name                  = "HPBar"
        hpBar.Size                  = UDim2.new(1, 0, 1, 0)
        hpBar.BackgroundColor3      = Color3.fromRGB(80, 210, 80)
        hpBar.BorderSizePixel       = 0
        hpBar.Parent                = hpBg

        local hpBarCorner = Instance.new("UICorner")
        hpBarCorner.CornerRadius = UDim.new(0, 3)
        hpBarCorner.Parent = hpBar

        local distLabel = Instance.new("TextLabel")
        distLabel.Name                  = "Distance"
        distLabel.Size                  = UDim2.new(1, -10, 0, 14)
        distLabel.Position              = UDim2.new(0, 5, 0, 48)
        distLabel.BackgroundTransparency = 1
        distLabel.Font                  = Enum.Font.Gotham
        distLabel.TextSize              = 10
        distLabel.TextColor3            = Color3.fromRGB(196, 230, 0)
        distLabel.TextXAlignment        = Enum.TextXAlignment.Left
        distLabel.Text                  = "-- studs"
        distLabel.Parent                = bg

        espBoards[player.Name] = board
        return board
end

local function removeESPBoard(playerName: string)
        local board = espBoards[playerName]
        if board then
                board:Destroy()
                espBoards[playerName] = nil
        end
end

local function clearAllESP()
        for name, board in espBoards do
                board:Destroy()
                espBoards[name] = nil
        end
end

local function refreshESP()
        clearAllESP()
        if not espEnabled then return end
        for _, player in Players:GetPlayers() do
                if player ~= LocalPlayer then
                        buildESPBoard(player)
                end
        end
end

-- Update ESP health bars and distance every 0.2s
local espUpdateAccum = 0
RunService.RenderStepped:Connect(function(dt)
        if not espEnabled then return end
        espUpdateAccum += dt
        if espUpdateAccum < 0.2 then return end
        espUpdateAccum = 0

        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        for playerName, board in espBoards do
                local player = Players:FindFirstChild(playerName)
                if not player or not player.Character then
                        removeESPBoard(playerName)
                        continue
                end
                local char = player.Character
                local hum  = char:FindFirstChildOfClass("Humanoid")
                if not hum then continue end

                local hpBar    = board:FindFirstChild("Frame") and board.Frame:FindFirstChild("HPBg") and board.Frame.HPBg:FindFirstChild("HPBar")
                local distLbl  = board:FindFirstChild("Frame") and board.Frame:FindFirstChild("Distance")

                if hpBar then
                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        hpBar.Size = UDim2.new(ratio, 0, 1, 0)
                        -- Color: green → yellow → red
                        local r = math.floor((1 - ratio) * 255)
                        local g = math.floor(ratio * 210)
                        hpBar.BackgroundColor3 = Color3.fromRGB(r, g, 40)
                end

                if distLbl and myHRP then
                        local tgtHRP = char:FindFirstChild("HumanoidRootPart")
                        if tgtHRP then
                                local dist = math.floor((myHRP.Position - tgtHRP.Position).Magnitude)
                                distLbl.Text = dist .. " studs"
                        end
                end
        end
end)

CommandRemotes.ESP.OnClientEvent:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
                refreshESP()
                Players.PlayerAdded:Connect(function(p)
                        if espEnabled then buildESPBoard(p) end
                end)
                Players.PlayerRemoving:Connect(function(p)
                        removeESPBoard(p.Name)
                end)
        else
                clearAllESP()
        end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- FLY — toggle flight (E to activate, Alt to boost)
-- ══════════════════════════════════════════════════════════════════════════════

local flyEnabled   = false
local flyActive    = false   -- actually airborne right now
local flySpeed     = 40
local flyBoost     = 100
local flyBodyVel: BodyVelocity?  = nil
local flyBodyGyro: BodyGyro?     = nil

local FLY_KEY      = Enum.KeyCode.E
local FLY_BOOST    = Enum.KeyCode.LeftAlt

local function stopFly()
        flyActive = false
        if flyBodyVel  then flyBodyVel:Destroy();  flyBodyVel  = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
end

local flyConnection: RBXScriptConnection?

local function startFlyLoop()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        flyActive = true
        hum.PlatformStand = true

        flyBodyVel = Instance.new("BodyVelocity")
        flyBodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBodyVel.Velocity = Vector3.zero
        flyBodyVel.Parent   = hrp

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBodyGyro.D         = 100
        flyBodyGyro.CFrame    = hrp.CFrame
        flyBodyGyro.Parent    = hrp

        if flyConnection then flyConnection:Disconnect() end
        flyConnection = RunService.RenderStepped:Connect(function()
                if not flyActive or not flyBodyVel or not flyBodyGyro then return end

                local camCF = Camera.CFrame
                local boost = UserInputService:IsKeyDown(FLY_BOOST)
                local spd   = boost and flyBoost or flySpeed

                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end

                flyBodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * spd or Vector3.zero
                flyBodyGyro.CFrame  = camCF
        end)
end

CommandRemotes.Fly.OnClientEvent:Connect(function()
        flyEnabled = not flyEnabled
        if not flyEnabled then
                stopFly()
        end
        -- Flight activates on E key press when enabled
end)

UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not flyEnabled then return end
        if input.KeyCode == FLY_KEY then
                if flyActive then
                        stopFly()
                else
                        startFlyLoop()
                end
        end
end)

-- Clean up on character respawn
LocalPlayer.CharacterAdded:Connect(function()
        flyActive = false
        flyBodyVel  = nil
        flyBodyGyro = nil
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- WATCH — camera POV switch
-- ══════════════════════════════════════════════════════════════════════════════

local watchingPlayer: Player? = nil
local watchConnection: RBXScriptConnection?

local function stopWatch()
        if watchConnection then watchConnection:Disconnect() end
        Camera.CameraType    = Enum.CameraType.Custom
        Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        watchingPlayer       = nil
end

CommandRemotes.Watch.OnClientEvent:Connect(function(playerName: string)
        -- Toggle off if watching the same player
        if watchingPlayer and watchingPlayer.Name == playerName then
                stopWatch()
                return
        end

        local target = Players:FindFirstChild(playerName)
        if not target then return end

        stopWatch()
        watchingPlayer = target

        local function applyWatch()
                local char = target.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                        Camera.CameraType    = Enum.CameraType.Custom
                        Camera.CameraSubject = hum
                end
        end

        applyWatch()
        watchConnection = target.CharacterAdded:Connect(function()
                task.wait(0.2)
                applyWatch()
        end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- CHAT LOGS PANEL
-- ══════════════════════════════════════════════════════════════════════════════

local logsGui = Instance.new("ScreenGui")
logsGui.Name           = "ChatLogs"
logsGui.DisplayOrder   = 65
logsGui.ResetOnSpawn   = false
logsGui.IgnoreGuiInset = true
logsGui.Parent         = PlayerGui

local logsPanel = Instance.new("Frame")
logsPanel.Name                  = "LogsPanel"
logsPanel.AnchorPoint           = Vector2.new(0.5, 0.5)
logsPanel.Size                  = UDim2.new(0, 540, 0, 400)
logsPanel.Position              = UDim2.new(0.5, 0, 0.5, 0)
logsPanel.BackgroundColor3      = Color3.fromRGB(10, 10, 14)
logsPanel.BackgroundTransparency = 0.04
logsPanel.BorderSizePixel       = 0
logsPanel.ZIndex                = 70
logsPanel.Visible               = false
logsPanel.Parent                = logsGui

local logsPanelCorner = Instance.new("UICorner")
logsPanelCorner.CornerRadius = UDim.new(0, 10)
logsPanelCorner.Parent = logsPanel

local logsPanelStroke = Instance.new("UIStroke")
logsPanelStroke.Color        = Color3.fromRGB(75, 75, 95)
logsPanelStroke.Thickness    = 1.5
logsPanelStroke.Transparency = 0.2
logsPanelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
logsPanelStroke.Parent = logsPanel

-- Title bar
local logsTitleBar = Instance.new("Frame")
logsTitleBar.Name             = "TitleBar"
logsTitleBar.Size             = UDim2.new(1, 0, 0, 38)
logsTitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
logsTitleBar.BorderSizePixel  = 0
logsTitleBar.ZIndex           = 71
logsTitleBar.Parent           = logsPanel

local logsTitleCorner = Instance.new("UICorner")
logsTitleCorner.CornerRadius = UDim.new(0, 10)
logsTitleCorner.Parent = logsTitleBar

-- Extend the bottom corners so only the top is rounded
local logsTitleFill = Instance.new("Frame")
logsTitleFill.Size             = UDim2.new(1, 0, 0.5, 0)
logsTitleFill.Position         = UDim2.new(0, 0, 0.5, 0)
logsTitleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
logsTitleFill.BorderSizePixel  = 0
logsTitleFill.ZIndex           = 71
logsTitleFill.Parent           = logsTitleBar

local logsTitleLabel = Instance.new("TextLabel")
logsTitleLabel.Size                  = UDim2.new(1, -50, 1, 0)
logsTitleLabel.Position              = UDim2.new(0, 14, 0, 0)
logsTitleLabel.BackgroundTransparency = 1
logsTitleLabel.Font                  = Enum.Font.GothamBold
logsTitleLabel.TextSize              = 13
logsTitleLabel.TextColor3            = Color3.fromRGB(196, 230, 0)
logsTitleLabel.TextXAlignment        = Enum.TextXAlignment.Left
logsTitleLabel.TextYAlignment        = Enum.TextYAlignment.Center
logsTitleLabel.Text                  = "CHAT LOGS"
logsTitleLabel.ZIndex                = 72
logsTitleLabel.Parent                = logsTitleBar

local logsCloseBtn = Instance.new("TextButton")
logsCloseBtn.Size                  = UDim2.new(0, 30, 0, 30)
logsCloseBtn.Position              = UDim2.new(1, -34, 0, 4)
logsCloseBtn.BackgroundTransparency = 1
logsCloseBtn.Font                  = Enum.Font.GothamBold
logsCloseBtn.TextSize              = 16
logsCloseBtn.TextColor3            = Color3.fromRGB(160, 160, 180)
logsCloseBtn.Text                  = "✕"
logsCloseBtn.ZIndex                = 72
logsCloseBtn.Parent                = logsTitleBar

logsCloseBtn.MouseButton1Click:Connect(function()
        tw(logsPanel, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.25, function() logsPanel.Visible = false end)
end)

-- Scroll frame for log entries
local logsScroll = Instance.new("ScrollingFrame")
logsScroll.Name                  = "LogsScroll"
logsScroll.Size                  = UDim2.new(1, -16, 1, -50)
logsScroll.Position              = UDim2.new(0, 8, 0, 44)
logsScroll.BackgroundTransparency = 1
logsScroll.BorderSizePixel       = 0
logsScroll.ScrollBarThickness    = 4
logsScroll.ScrollBarImageColor3  = Color3.fromRGB(196, 230, 0)
logsScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
logsScroll.ZIndex                = 71
logsScroll.Parent                = logsPanel

local logsLayout = Instance.new("UIListLayout")
logsLayout.FillDirection    = Enum.FillDirection.Vertical
logsLayout.SortOrder        = Enum.SortOrder.LayoutOrder
logsLayout.Padding          = UDim.new(0, 2)
logsLayout.Parent           = logsScroll

logsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        logsScroll.CanvasSize = UDim2.new(0, 0, 0, logsLayout.AbsoluteContentSize.Y + 10)
end)

CommandRemotes.ChatLogs.OnClientEvent:Connect(function(logs: { { text: string, sender: string, time: string } })
        -- Clear old entries
        for _, child in logsScroll:GetChildren() do
                if child:IsA("Frame") or child:IsA("TextLabel") then
                        child:Destroy()
                end
        end

        if #logs == 0 then
                local empty = Instance.new("TextLabel")
                empty.Size                  = UDim2.new(1, 0, 0, 30)
                empty.BackgroundTransparency = 1
                empty.Font                  = Enum.Font.Gotham
                empty.TextSize              = 13
                empty.TextColor3            = Color3.fromRGB(120, 120, 140)
                empty.TextXAlignment        = Enum.TextXAlignment.Center
                empty.Text                  = "No chat logs yet."
                empty.ZIndex                = 72
                empty.LayoutOrder           = 1
                empty.Parent                = logsScroll
        else
                for i, entry in logs do
                        local row = Instance.new("Frame")
                        row.Name                  = "Log" .. i
                        row.LayoutOrder           = i
                        row.Size                  = UDim2.new(1, 0, 0, 28)
                        row.BackgroundColor3      = i % 2 == 0 and Color3.fromRGB(18, 18, 22) or Color3.fromRGB(12, 12, 16)
                        row.BackgroundTransparency = 0
                        row.BorderSizePixel       = 0
                        row.ZIndex                = 72
                        row.Parent                = logsScroll

                        local timeLabel = Instance.new("TextLabel")
                        timeLabel.Size                  = UDim2.new(0, 70, 1, 0)
                        timeLabel.BackgroundTransparency = 1
                        timeLabel.Font                  = Enum.Font.Gotham
                        timeLabel.TextSize              = 10
                        timeLabel.TextColor3            = Color3.fromRGB(100, 100, 120)
                        timeLabel.TextXAlignment        = Enum.TextXAlignment.Center
                        timeLabel.Text                  = entry.time or ""
                        timeLabel.ZIndex                = 73
                        timeLabel.Parent                = row

                        local senderLabel = Instance.new("TextLabel")
                        senderLabel.Size                  = UDim2.new(0, 120, 1, 0)
                        senderLabel.Position              = UDim2.new(0, 70, 0, 0)
                        senderLabel.BackgroundTransparency = 1
                        senderLabel.Font                  = Enum.Font.GothamBold
                        senderLabel.TextSize              = 11
                        senderLabel.TextColor3            = Color3.fromRGB(196, 230, 0)
                        senderLabel.TextXAlignment        = Enum.TextXAlignment.Left
                        senderLabel.Text                  = entry.sender or ""
                        senderLabel.ZIndex                = 73
                        senderLabel.Parent                = row

                        local msgLabel = Instance.new("TextLabel")
                        msgLabel.Size                  = UDim2.new(1, -196, 1, 0)
                        msgLabel.Position              = UDim2.new(0, 196, 0, 0)
                        msgLabel.BackgroundTransparency = 1
                        msgLabel.Font                  = Enum.Font.Gotham
                        msgLabel.TextSize              = 11
                        msgLabel.TextColor3            = Color3.fromRGB(210, 210, 225)
                        msgLabel.TextXAlignment        = Enum.TextXAlignment.Left
                        msgLabel.TextTruncate          = Enum.TextTruncate.AtEnd
                        msgLabel.Text                  = entry.text or ""
                        msgLabel.ZIndex                = 73
                        msgLabel.Parent                = row
                end
        end

        -- Show panel
        logsPanel.BackgroundTransparency = 0.6
        logsPanel.Visible = true
        tw(logsPanel, 0.25, { BackgroundTransparency = 0.04 })

        -- Scroll to bottom
        task.defer(function()
                logsScroll.CanvasPosition = Vector2.new(0, logsLayout.AbsoluteContentSize.Y)
        end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- HELP UI — staff help request panel
-- ══════════════════════════════════════════════════════════════════════════════

local helpEnabled = false

local helpGui = Instance.new("ScreenGui")
helpGui.Name           = "HelpUI"
helpGui.DisplayOrder   = 62
helpGui.ResetOnSpawn   = false
helpGui.IgnoreGuiInset = true
helpGui.Parent         = PlayerGui

-- Status indicator (top-right, small pill)
local helpIndicator = Instance.new("Frame")
helpIndicator.Name                  = "HelpIndicator"
helpIndicator.AnchorPoint           = Vector2.new(1, 0)
helpIndicator.Size                  = UDim2.new(0, 120, 0, 26)
helpIndicator.Position              = UDim2.new(1, -10, 0, 46)
helpIndicator.BackgroundColor3      = Color3.fromRGB(10, 10, 14)
helpIndicator.BackgroundTransparency = 0.1
helpIndicator.BorderSizePixel       = 0
helpIndicator.Visible               = false
helpIndicator.ZIndex                = 63
helpIndicator.Parent                = helpGui

local helpIndCorner = Instance.new("UICorner")
helpIndCorner.CornerRadius = UDim.new(0, 6)
helpIndCorner.Parent = helpIndicator

local helpIndDot = Instance.new("Frame")
helpIndDot.Size                  = UDim2.new(0, 8, 0, 8)
helpIndDot.Position              = UDim2.new(0, 8, 0.5, -4)
helpIndDot.BackgroundColor3      = Color3.fromRGB(80, 210, 80)
helpIndDot.BorderSizePixel       = 0
helpIndDot.ZIndex                = 64
helpIndDot.Parent                = helpIndicator

local helpIndDotCorner = Instance.new("UICorner")
helpIndDotCorner.CornerRadius = UDim.new(1, 0)
helpIndDotCorner.Parent = helpIndDot

local helpIndLabel = Instance.new("TextLabel")
helpIndLabel.Size                  = UDim2.new(1, -24, 1, 0)
helpIndLabel.Position              = UDim2.new(0, 22, 0, 0)
helpIndLabel.BackgroundTransparency = 1
helpIndLabel.Font                  = Enum.Font.GothamBold
helpIndLabel.TextSize              = 10
helpIndLabel.TextColor3            = Color3.fromRGB(200, 200, 210)
helpIndLabel.TextXAlignment        = Enum.TextXAlignment.Left
helpIndLabel.TextYAlignment        = Enum.TextYAlignment.Center
helpIndLabel.Text                  = "HELP UI ON"
helpIndLabel.ZIndex                = 64
helpIndLabel.Parent                = helpIndicator

-- Incoming help request toast (stacking)
local helpQueue: { Frame } = {}

local function showHelpRequest(senderName: string, message: string)
        if not helpEnabled then return end

        local toast = Instance.new("Frame")
        toast.Name                  = "HelpRequest"
        toast.AnchorPoint           = Vector2.new(1, 0)
        toast.Size                  = UDim2.new(0, 300, 0, 62)
        -- Stack above previous
        local yOffset = 80 + #helpQueue * 68
        toast.Position              = UDim2.new(1, 40, 0, yOffset)
        toast.BackgroundColor3      = Color3.fromRGB(12, 12, 18)
        toast.BackgroundTransparency = 0
        toast.BorderSizePixel       = 0
        toast.ZIndex                = 65
        toast.Parent                = helpGui

        local toastCorner = Instance.new("UICorner")
        toastCorner.CornerRadius = UDim.new(0, 8)
        toastCorner.Parent = toast

        local toastAccent = Instance.new("Frame")
        toastAccent.Size                  = UDim2.new(0, 3, 1, -12)
        toastAccent.Position              = UDim2.new(0, 6, 0, 6)
        toastAccent.BackgroundColor3      = Color3.fromRGB(80, 210, 80)
        toastAccent.BorderSizePixel       = 0
        toastAccent.ZIndex                = 66
        toastAccent.Parent                = toast

        local toastAccentCorner = Instance.new("UICorner")
        toastAccentCorner.CornerRadius = UDim.new(0, 2)
        toastAccentCorner.Parent = toastAccent

        local toastHeader = Instance.new("TextLabel")
        toastHeader.Size                  = UDim2.new(1, -20, 0, 18)
        toastHeader.Position              = UDim2.new(0, 18, 0, 8)
        toastHeader.BackgroundTransparency = 1
        toastHeader.Font                  = Enum.Font.GothamBold
        toastHeader.TextSize              = 11
        toastHeader.TextColor3            = Color3.fromRGB(80, 210, 80)
        toastHeader.TextXAlignment        = Enum.TextXAlignment.Left
        toastHeader.Text                  = "HELP REQUEST — " .. senderName:upper()
        toastHeader.ZIndex                = 66
        toastHeader.Parent                = toast

        local toastMsg = Instance.new("TextLabel")
        toastMsg.Size                  = UDim2.new(1, -20, 1, -32)
        toastMsg.Position              = UDim2.new(0, 18, 0, 28)
        toastMsg.BackgroundTransparency = 1
        toastMsg.Font                  = Enum.Font.Gotham
        toastMsg.TextSize              = 12
        toastMsg.TextColor3            = Color3.fromRGB(210, 210, 225)
        toastMsg.TextXAlignment        = Enum.TextXAlignment.Left
        toastMsg.TextWrapped           = true
        toastMsg.Text                  = message
        toastMsg.ZIndex                = 66
        toastMsg.Parent                = toast

        table.insert(helpQueue, toast)

        -- Slide in from right
        tw(toast, 0.3, { Position = UDim2.new(1, -10, 0, yOffset) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        -- Auto-dismiss after 8s
        task.delay(8, function()
                tw(toast, 0.3, { Position = UDim2.new(1, 340, 0, yOffset) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                task.delay(0.35, function()
                        toast:Destroy()
                        local idx = table.find(helpQueue, toast)
                        if idx then table.remove(helpQueue, idx) end
                end)
        end)
end

CommandRemotes.HelpUI.OnClientEvent:Connect(function(isOn: boolean)
        helpEnabled = isOn
        helpIndicator.Visible = isOn
        -- Sync back to server
        CommandRemotes.HelpUIState:FireServer(isOn)
end)

CommandRemotes.HelpReceive.OnClientEvent:Connect(function(senderName: string, message: string)
        showHelpRequest(senderName, message)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- MUSIC — server-wide sound playback
-- ══════════════════════════════════════════════════════════════════════════════

local musicSound: Sound? = nil

CommandRemotes.Music.OnClientEvent:Connect(function(assetId: number)
        if musicSound then
                musicSound:Stop()
                musicSound:Destroy()
                musicSound = nil
        end

        if assetId == 0 then return end

        local sound = Instance.new("Sound")
        sound.Name        = "CommandMusic"
        sound.SoundId     = "rbxassetid://" .. assetId
        sound.Volume      = 0.8
        sound.Looped      = true
        sound.RollOffMaxDistance = 10000
        sound.Parent      = workspace

        sound:Play()
        musicSound = sound
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- WAYPOINTS — world-space markers visible to all players
-- ══════════════════════════════════════════════════════════════════════════════

local waypointBoards: { BillboardGui } = {}

local function clearWaypoints()
        for _, board in waypointBoards do
                board:Destroy()
        end
        waypointBoards = {}
end

local function placeWaypoint(x: number, y: number, z: number, label: string, setterName: string)
        -- Anchor part (invisible)
        local anchor = Instance.new("Part")
        anchor.Name        = "WaypointAnchor"
        anchor.Size        = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position    = Vector3.new(x, y, z)
        anchor.Anchored    = true
        anchor.CanCollide  = false
        anchor.Transparency = 1
        anchor.Parent      = workspace

        local board = Instance.new("BillboardGui")
        board.Name         = "Waypoint"
        board.Size         = UDim2.new(0, 220, 0, 80)
        board.StudsOffset  = Vector3.new(0, 5, 0)
        board.AlwaysOnTop  = true
        board.Adornee      = anchor
        board.Parent       = anchor

        local bg = Instance.new("Frame")
        bg.Size                  = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.3
        bg.BorderSizePixel       = 0
        bg.Parent                = board

        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(0, 8)
        bgCorner.Parent = bg

        local icon = Instance.new("TextLabel")
        icon.Size                  = UDim2.new(1, 0, 0, 28)
        icon.Position              = UDim2.new(0, 0, 0, 4)
        icon.BackgroundTransparency = 1
        icon.Font                  = Enum.Font.GothamBold
        icon.TextSize              = 20
        icon.TextColor3            = Color3.fromRGB(196, 230, 0)
        icon.TextXAlignment        = Enum.TextXAlignment.Center
        icon.Text                  = "◆"
        icon.Parent                = bg

        local labelEl = Instance.new("TextLabel")
        labelEl.Size                  = UDim2.new(1, -10, 0, 22)
        labelEl.Position              = UDim2.new(0, 5, 0, 30)
        labelEl.BackgroundTransparency = 1
        labelEl.Font                  = Enum.Font.GothamBold
        labelEl.TextSize              = 13
        labelEl.TextColor3            = Color3.fromRGB(255, 255, 255)
        labelEl.TextXAlignment        = Enum.TextXAlignment.Center
        labelEl.Text                  = label
        labelEl.Parent                = bg

        local subEl = Instance.new("TextLabel")
        subEl.Size                  = UDim2.new(1, -10, 0, 16)
        subEl.Position              = UDim2.new(0, 5, 0, 52)
        subEl.BackgroundTransparency = 1
        subEl.Font                  = Enum.Font.Gotham
        subEl.TextSize              = 10
        subEl.TextColor3            = Color3.fromRGB(130, 130, 150)
        subEl.TextXAlignment        = Enum.TextXAlignment.Center
        subEl.Text                  = "Set by " .. setterName
        subEl.Parent                = bg

        table.insert(waypointBoards, board)
        return board
end

CommandRemotes.Waypoint.OnClientEvent:Connect(function(action: string, x: number, y: number, z: number, label: string, setter: string)
        if action == "clear" then
                clearWaypoints()
        elseif action == "set" then
                placeWaypoint(x, y, z, label or "Waypoint", setter or "Staff")
        end
end)

print("[CommandEffects] All client effects active.")
