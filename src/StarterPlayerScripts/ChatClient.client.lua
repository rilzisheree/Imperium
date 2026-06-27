--[[
        ChatClient.client.lua
        LocalScript — StarterPlayerScripts

        Proximity chat system — client side:
          • Disables the default Roblox CoreGui chat
          • Minimal top-left input bar (press / or Enter to focus)
          • When a message is received, creates a BillboardGui bubble
            above the sender's character — styled exactly like the
            screenshot (white rounded pill, dark text, smooth fade)
          • Only players within MAX_DISTANCE on the server receive
            the event, so bubbles never appear for out-of-range players
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local TextService       = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local ChatRemotes = require(ReplicatedStorage:WaitForChild("ChatRemotes"))

-- ─── Disable default Roblox chat CoreGui ─────────────────────────────────────
local function disableDefaultChat()
        pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        end)
end
disableDefaultChat()
task.spawn(function()
        while true do
                task.wait(2)
                disableDefaultChat()
        end
end)

-- ─── Configuration ────────────────────────────────────────────────────────────
local CFG = {
        -- Bubble appearance (matches the screenshot)
        BUBBLE_BG_COLOR     = Color3.fromRGB(246, 244, 233), -- warm white/cream
        BUBBLE_BG_TRANS     = 0.08,
        BUBBLE_TEXT_COLOR   = Color3.fromRGB(30, 30, 30),    -- near-black
        BUBBLE_FONT         = Enum.Font.GothamSemibold,
        BUBBLE_TEXT_SIZE    = 14,
        BUBBLE_MAX_WIDTH    = 240,   -- px — wraps beyond this
        BUBBLE_PADDING_H    = 20,    -- horizontal inner padding
        BUBBLE_PADDING_V    = 10,    -- vertical inner padding
        BUBBLE_CORNER       = 12,    -- UICorner radius (px)

        -- BillboardGui sizing & offset
        BILLBOARD_SIZE_Y    = 0.5,   -- studs above head (StudsOffsetWorldSpace)
        BILLBOARD_HEAD_OFFSET = 2.4, -- studs above HumanoidRootPart

        -- Timing
        HOLD_DURATION       = 7,     -- seconds bubble stays fully visible
        FADE_IN_TIME        = 0.15,
        FADE_OUT_TIME       = 0.8,

        -- Input bar
        INPUT_BG_COLOR      = Color3.fromRGB(20, 20, 20),
        INPUT_BG_TRANS      = 0.45,
        INPUT_TEXT_COLOR    = Color3.fromRGB(255, 255, 255),
        INPUT_PLACEHOLDER   = Color3.fromRGB(180, 180, 180),
        INPUT_FONT          = Enum.Font.GothamSemibold,
        INPUT_TEXT_SIZE     = 14,
        INPUT_WIDTH         = 260,
        INPUT_HEIGHT        = 28,
}

-- ─── Input bar (top-left, matches screenshot style) ──────────────────────────
local inputGui = Instance.new("ScreenGui")
inputGui.Name           = "ChatInput"
inputGui.DisplayOrder   = 20
inputGui.ResetOnSpawn   = false
inputGui.IgnoreGuiInset = true   -- bypass the 36px inset so we control exact position
inputGui.Parent         = PlayerGui

local inputFrame = Instance.new("Frame")
inputFrame.Name                 = "InputFrame"
inputFrame.Size                 = UDim2.new(0, CFG.INPUT_WIDTH, 0, CFG.INPUT_HEIGHT)
inputFrame.Position             = UDim2.new(0, 4, 0, 48)   -- just below the Roblox topbar
inputFrame.BackgroundColor3     = CFG.INPUT_BG_COLOR
inputFrame.BackgroundTransparency = CFG.INPUT_BG_TRANS
inputFrame.BorderSizePixel      = 0
inputFrame.Parent               = inputGui

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = inputFrame

local inputBox = Instance.new("TextBox")
inputBox.Name                   = "InputBox"
inputBox.Size                   = UDim2.new(1, -10, 1, 0)
inputBox.Position               = UDim2.new(0, 8, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = true
inputBox.Font                   = CFG.INPUT_FONT
inputBox.TextSize               = CFG.INPUT_TEXT_SIZE
inputBox.TextColor3             = CFG.INPUT_TEXT_COLOR
inputBox.PlaceholderText        = "Press / to chat…"
inputBox.PlaceholderColor3      = CFG.INPUT_PLACEHOLDER
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.TextYAlignment         = Enum.TextYAlignment.Center
inputBox.MultiLine              = false
inputBox.Parent                 = inputFrame

-- Character counter label (right side)
local charCounter = Instance.new("TextLabel")
charCounter.Name                = "CharCounter"
charCounter.Size                = UDim2.new(0, 28, 1, 0)
charCounter.Position            = UDim2.new(1, -30, 0, 0)
charCounter.BackgroundTransparency = 1
charCounter.Font                = Enum.Font.Gotham
charCounter.TextSize            = 11
charCounter.TextColor3          = CFG.INPUT_PLACEHOLDER
charCounter.Text                = ""
charCounter.TextXAlignment      = Enum.TextXAlignment.Right
charCounter.TextYAlignment      = Enum.TextYAlignment.Center
charCounter.Parent              = inputFrame

-- ─── Bubble builder ───────────────────────────────────────────────────────────

-- Active bubble threads per character (keyed by player Name)
local activeBubbles: { [string]: thread } = {}

local function createBubble(character: Model, text: string)
        -- Cancel any existing bubble for this character
        if activeBubbles[character.Name] then
                task.cancel(activeBubbles[character.Name])
                activeBubbles[character.Name] = nil
        end

        -- Remove any stale BillboardGui
        local old = character:FindFirstChild("ProxChatBubble")
        if old then old:Destroy() end

        -- Find attachment point (Head preferred, fallback HumanoidRootPart)
        local head = character:FindFirstChild("Head")
        local attachPart = head or character:FindFirstChild("HumanoidRootPart")
        if not attachPart then return end

        -- ── Measure text so the bubble shrinks to fit ─────────────────────────────
        -- GetTextSize returns the bounding box for the given constraints
        local measured = TextService:GetTextSize(
                text,
                CFG.BUBBLE_TEXT_SIZE,
                CFG.BUBBLE_FONT,
                Vector2.new(CFG.BUBBLE_MAX_WIDTH, 1000)
        )
        -- Clamp: short text uses measured width, long text wraps at MAX_WIDTH
        local labelW   = math.min(measured.X, CFG.BUBBLE_MAX_WIDTH)
        local labelH   = measured.Y  -- height after wrapping
        local bubbleW  = labelW  + CFG.BUBBLE_PADDING_H * 2
        local bubbleH  = labelH  + CFG.BUBBLE_PADDING_V * 2

        -- ── BillboardGui — sized exactly to the bubble content ────────────────────
        local billboard = Instance.new("BillboardGui")
        billboard.Name              = "ProxChatBubble"
        billboard.AlwaysOnTop       = false
        billboard.MaxDistance       = 0
        billboard.StudsOffset       = Vector3.new(0, 2.2, 0)
        -- Size in pixels matching our computed bubble size
        billboard.Size              = UDim2.new(0, bubbleW, 0, bubbleH)
        billboard.SizeOffset        = Vector2.new(0, 0)
        billboard.ResetOnSpawn      = false
        billboard.AutoLocalize      = false
        billboard.Adornee           = attachPart
        billboard.Parent            = character

        -- ── Container frame — fills the billboard exactly ─────────────────────────
        local bubble = Instance.new("Frame")
        bubble.Name                 = "Bubble"
        bubble.AnchorPoint          = Vector2.new(0.5, 0.5)
        bubble.Position             = UDim2.new(0.5, 0, 0.5, 0)
        bubble.Size                 = UDim2.new(1, 0, 1, 0)
        bubble.BackgroundColor3     = CFG.BUBBLE_BG_COLOR
        bubble.BackgroundTransparency = CFG.BUBBLE_BG_TRANS
        bubble.BorderSizePixel      = 0
        bubble.Parent               = billboard

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, CFG.BUBBLE_CORNER)
        corner.Parent = bubble

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft   = UDim.new(0, CFG.BUBBLE_PADDING_H)
        padding.PaddingRight  = UDim.new(0, CFG.BUBBLE_PADDING_H)
        padding.PaddingTop    = UDim.new(0, CFG.BUBBLE_PADDING_V)
        padding.PaddingBottom = UDim.new(0, CFG.BUBBLE_PADDING_V)
        padding.Parent = bubble

        -- ── Text label — sized to match measured bounds ────────────────────────────
        local label = Instance.new("TextLabel")
        label.Name                  = "ChatText"
        label.BackgroundTransparency = 1
        -- Use exact measured size so no extra whitespace appears
        label.Size                  = UDim2.new(0, labelW, 0, labelH)
        label.Font                  = CFG.BUBBLE_FONT
        label.TextSize              = CFG.BUBBLE_TEXT_SIZE
        label.TextColor3            = CFG.BUBBLE_TEXT_COLOR
        label.TextXAlignment        = Enum.TextXAlignment.Center
        label.TextYAlignment        = Enum.TextYAlignment.Center
        label.TextWrapped           = true
        label.Text                  = text
        label.Parent                = bubble

        -- ── Animate: fade in → hold → fade out ───────────────────────────────────
        local function tweenTransparency(target, tweenInfo, props)
                local t = TweenService:Create(target, tweenInfo, props)
                t:Play()
                return t
        end

        -- Start invisible
        bubble.BackgroundTransparency = 1
        label.TextTransparency = 1

        -- Spawn the lifecycle in a new task so we can cancel it
        activeBubbles[character.Name] = task.spawn(function()
                -- Fade in
                local inInfo = TweenInfo.new(CFG.FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                tweenTransparency(bubble, inInfo, { BackgroundTransparency = CFG.BUBBLE_BG_TRANS })
                tweenTransparency(label,  inInfo, { TextTransparency = 0 })
                task.wait(CFG.FADE_IN_TIME)

                -- Hold
                task.wait(CFG.HOLD_DURATION)

                -- Fade out
                local outInfo = TweenInfo.new(CFG.FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tweenTransparency(bubble, outInfo, { BackgroundTransparency = 1 })
                tweenTransparency(label,  outInfo, { TextTransparency = 1 })
                task.wait(CFG.FADE_OUT_TIME)

                -- Clean up
                if billboard and billboard.Parent then
                        billboard:Destroy()
                end
                activeBubbles[character.Name] = nil
        end)
end

-- ─── Receive chat message ─────────────────────────────────────────────────────

local function onMessageReceived(payload: table)
        local senderName = payload.senderName
        if not senderName then return end

        -- Find the sender in the Players list
        local sender = Players:FindFirstChild(senderName)
        if not sender then return end

        local character = sender.Character
        if not character then
                -- Wait briefly in case they just spawned
                character = sender.CharacterAdded:Wait()
        end

        createBubble(character, payload.message)
end

ChatRemotes.MessageReceived.OnClientEvent:Connect(onMessageReceived)

-- ─── Input handling ───────────────────────────────────────────────────────────

local MAX_CHARS = 200

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local len = #inputBox.Text
        if len > 0 then
                charCounter.Text = tostring(math.min(len, MAX_CHARS))
        else
                charCounter.Text = ""
        end
        -- Hard-cap length client-side too
        if len > MAX_CHARS then
                inputBox.Text = inputBox.Text:sub(1, MAX_CHARS)
        end
end)

local function submitMessage()
        local text = inputBox.Text:match("^%s*(.-)%s*$")
        if text ~= "" then
                ChatRemotes.MessageSent:FireServer(text)
        end
        inputBox.Text = ""
        charCounter.Text = ""
        inputBox:ReleaseFocus()
end

inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
                submitMessage()
        end
end)

-- Press / to focus input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Slash then
                inputBox:CaptureFocus()
        elseif input.KeyCode == Enum.KeyCode.Escape then
                inputBox.Text = ""
                charCounter.Text = ""
                inputBox:ReleaseFocus()
        end
end)

print("[ChatClient] Proximity chat bubbles active.")
