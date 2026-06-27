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
        BUBBLE_TEXT_SIZE    = 19,
        BUBBLE_MAX_WIDTH    = 240,   -- px — wraps beyond this
        BUBBLE_PADDING_H    = 20,    -- horizontal inner padding
        BUBBLE_PADDING_V    = 10,    -- vertical inner padding
        BUBBLE_CORNER       = 12,    -- UICorner radius (px)

        -- BillboardGui sizing & offset
        BILLBOARD_SIZE_Y    = 0.5,   -- studs above head (StudsOffsetWorldSpace)
        BILLBOARD_HEAD_OFFSET = 2.4, -- studs above HumanoidRootPart

        -- Timing
        HOLD_DURATION       = 7,     -- seconds bubble stays fully visible
        FADE_IN_TIME        = 0.35,  -- slower fade so it feels smooth
        FADE_OUT_TIME       = 0.8,
        SLIDE_DISTANCE      = 0.5,   -- studs the bubble rises during entrance

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
inputFrame.Position             = UDim2.new(0, 4, 0, 60)   -- just below the Roblox topbar
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
--
-- Each character gets ONE shared BillboardGui with a vertical list inside.
-- Every message adds its own frame to that list and manages its own lifecycle.
-- Messages stack and fade independently — no cancellation of earlier ones.

-- Stores {billboard, listFrame, count} per character name
local characterContainers = {}

local BILLBOARD_MAX_HEIGHT = 130  -- px — tight above head; UIListLayout stacks upward
local BUBBLE_GAP           = 4    -- px gap between stacked bubbles

local function getOrCreateContainer(character: Model, attachPart: BasePart)
        local existing = characterContainers[character.Name]
        if existing and existing.billboard and existing.billboard.Parent == character then
                return existing
        end

        local maxW = CFG.BUBBLE_MAX_WIDTH + CFG.BUBBLE_PADDING_H * 2

        -- One BillboardGui lives above the character's head
        local billboard = Instance.new("BillboardGui")
        billboard.Name              = "ProxChatBubble"
        billboard.AlwaysOnTop       = false
        billboard.MaxDistance       = 0
        billboard.StudsOffset       = Vector3.new(0, 2.2, 0)
        billboard.Size              = UDim2.new(0, maxW, 0, BILLBOARD_MAX_HEIGHT)
        billboard.SizeOffset        = Vector2.new(0, 0)
        billboard.ResetOnSpawn      = false
        billboard.AutoLocalize      = false
        billboard.Adornee           = attachPart
        billboard.Parent            = character

        -- Stack frame: messages pile from the bottom upward
        local listFrame = Instance.new("Frame")
        listFrame.Name              = "Stack"
        listFrame.BackgroundTransparency = 1
        listFrame.Size              = UDim2.new(1, 0, 1, 0)
        listFrame.Position          = UDim2.new(0, 0, 0, 0)
        listFrame.Parent            = billboard

        local layout = Instance.new("UIListLayout")
        layout.FillDirection        = Enum.FillDirection.Vertical
        layout.VerticalAlignment    = Enum.VerticalAlignment.Bottom
        layout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
        layout.SortOrder            = Enum.SortOrder.LayoutOrder
        layout.Padding              = UDim.new(0, BUBBLE_GAP)
        layout.Parent               = listFrame

        local container = { billboard = billboard, listFrame = listFrame, count = 0 }
        characterContainers[character.Name] = container
        return container
end

local messageOrder = 0  -- global incrementing layout order

local function createBubble(character: Model, text: string)
        -- Find attachment point
        local head      = character:FindFirstChild("Head")
        local attachPart = head or character:FindFirstChild("HumanoidRootPart")
        if not attachPart then return end

        local container = getOrCreateContainer(character, attachPart)
        container.count += 1
        messageOrder += 1

        -- ── Measure text → size this bubble to fit ────────────────────────────────
        local measured = TextService:GetTextSize(
                text,
                CFG.BUBBLE_TEXT_SIZE,
                CFG.BUBBLE_FONT,
                Vector2.new(CFG.BUBBLE_MAX_WIDTH, 1000)
        )
        local labelW  = math.min(measured.X, CFG.BUBBLE_MAX_WIDTH)
        local labelH  = measured.Y
        local bubbleW = labelW + CFG.BUBBLE_PADDING_H * 2
        local bubbleH = labelH + CFG.BUBBLE_PADDING_V * 2

        -- ── Bubble frame (sits inside the shared list) ────────────────────────────
        local bubble = Instance.new("Frame")
        bubble.Name                 = "Bubble"
        bubble.LayoutOrder          = messageOrder
        bubble.Size                 = UDim2.new(0, bubbleW, 0, bubbleH)
        bubble.BackgroundColor3     = CFG.BUBBLE_BG_COLOR
        bubble.BackgroundTransparency = 1          -- start invisible
        bubble.BorderSizePixel      = 0
        bubble.Parent               = container.listFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, CFG.BUBBLE_CORNER)
        corner.Parent = bubble

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft   = UDim.new(0, CFG.BUBBLE_PADDING_H)
        pad.PaddingRight  = UDim.new(0, CFG.BUBBLE_PADDING_H)
        pad.PaddingTop    = UDim.new(0, CFG.BUBBLE_PADDING_V)
        pad.PaddingBottom = UDim.new(0, CFG.BUBBLE_PADDING_V)
        pad.Parent = bubble

        local label = Instance.new("TextLabel")
        label.Name                  = "ChatText"
        label.BackgroundTransparency = 1
        label.Size                  = UDim2.new(0, labelW, 0, labelH)
        label.Font                  = CFG.BUBBLE_FONT
        label.TextSize              = CFG.BUBBLE_TEXT_SIZE
        label.TextColor3            = CFG.BUBBLE_TEXT_COLOR
        label.TextXAlignment        = Enum.TextXAlignment.Center
        label.TextYAlignment        = Enum.TextYAlignment.Center
        label.TextWrapped           = true
        label.TextTransparency      = 1           -- start invisible
        label.Text                  = text
        label.Parent                = bubble

        -- ── Slide-up helper: animate a UDim2 position offset ─────────────────────
        local function tween(target, info, props)
                TweenService:Create(target, info, props):Play()
        end

        -- ── Lifecycle: fade-in → hold → fade-out → destroy ───────────────────────
        -- NOTE: bubble.Position must NOT be set manually — UIListLayout owns it.
        -- The entrance effect is a smooth opacity fade only.
        task.spawn(function()
                local inInfo = TweenInfo.new(CFG.FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                tween(bubble, inInfo, { BackgroundTransparency = CFG.BUBBLE_BG_TRANS })
                tween(label,  inInfo, { TextTransparency = 0 })
                task.wait(CFG.FADE_IN_TIME)

                -- Hold
                task.wait(CFG.HOLD_DURATION)

                -- Fade out
                local outInfo = TweenInfo.new(CFG.FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tween(bubble, outInfo, { BackgroundTransparency = 1 })
                tween(label,  outInfo, { TextTransparency = 1 })
                task.wait(CFG.FADE_OUT_TIME)

                -- Remove this bubble from the stack
                bubble:Destroy()
                container.count -= 1

                -- Clean up the shared billboard if no messages remain
                if container.count <= 0 then
                        if container.billboard and container.billboard.Parent then
                                container.billboard:Destroy()
                        end
                        characterContainers[character.Name] = nil
                end
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
