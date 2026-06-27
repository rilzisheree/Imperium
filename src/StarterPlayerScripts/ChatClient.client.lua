--[[
	ChatClient.client.lua
	LocalScript — StarterPlayerScripts

	Full custom chat system that replicates the look of the default
	Roblox chat exactly:
	  • Disables the CoreGui default chat
	  • Creates a pixel-accurate chat window (bottom-left)
	  • Scrollable message log with coloured player names
	  • Text input with / shortcut to focus
	  • Messages auto-fade when chat is idle / collapsed
	  • Mobile-compatible (on-screen button to open chat)
--]]

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui     = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local TextService    = game:GetService("TextService")
local RunService     = game:GetService("RunService")

local LocalPlayer    = Players.LocalPlayer
local PlayerGui      = LocalPlayer:WaitForChild("PlayerGui")

local ChatRemotes = require(ReplicatedStorage:WaitForChild("ChatRemotes"))

-- ─── Disable the default Roblox chat UI ───────────────────────────────────────
-- Must run every frame-tick after potential CoreGui resets
local function disableDefaultChat()
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)
	if not ok then
		warn("[ChatClient] Could not disable CoreGui chat:", err)
	end
end
disableDefaultChat()
-- Re-apply once a second in case Roblox re-enables it
task.spawn(function()
	while true do
		task.wait(1)
		disableDefaultChat()
	end
end)

-- ─── Configuration ────────────────────────────────────────────────────────────
local CFG = {
	-- Window dimensions (matches default Roblox chat)
	WINDOW_WIDTH     = 353,
	WINDOW_HEIGHT    = 186,   -- message log height
	INPUT_HEIGHT     = 28,
	TOTAL_HEIGHT     = 186 + 28,

	-- How many messages to keep in history
	MAX_MESSAGES     = 50,

	-- Seconds before idle messages start fading (when chat is collapsed)
	IDLE_FADE_DELAY  = 8,
	-- Seconds the fade animation takes
	FADE_DURATION    = 1.5,

	-- Colours — matching default Roblox chat
	BG_COLOR         = Color3.fromRGB(0, 0, 0),
	BG_TRANSPARENCY  = 0.5,
	INPUT_BG_COLOR   = Color3.fromRGB(0, 0, 0),
	INPUT_BG_TRANS   = 0.5,
	TEXT_COLOR       = Color3.fromRGB(255, 255, 255),
	SYSTEM_COLOR     = Color3.fromRGB(255, 255, 180),
	PLACEHOLDER_COLOR= Color3.fromRGB(178, 178, 178),

	-- Fonts — matching default Roblox chat
	FONT             = Enum.Font.GothamSemibold,
	TEXT_SIZE        = 14,

	-- Padding inside message area
	PADDING_H        = 8,
	PADDING_V        = 4,
}

-- ─── Build the ScreenGui ──────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name              = "CustomChat"
screenGui.DisplayOrder      = 10
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = false
screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
screenGui.Parent            = PlayerGui

-- ── Outer container (positions the chat at bottom-left exactly like Roblox) ──
local chatFrame = Instance.new("Frame")
chatFrame.Name              = "ChatFrame"
chatFrame.Size              = UDim2.new(0, CFG.WINDOW_WIDTH, 0, CFG.TOTAL_HEIGHT)
chatFrame.Position          = UDim2.new(0, 0, 1, -(CFG.TOTAL_HEIGHT + 4))
chatFrame.BackgroundTransparency = 1
chatFrame.BorderSizePixel   = 0
chatFrame.Parent            = screenGui

-- ── Message log background ────────────────────────────────────────────────────
local logBG = Instance.new("Frame")
logBG.Name                  = "LogBackground"
logBG.Size                  = UDim2.new(1, 0, 0, CFG.WINDOW_HEIGHT)
logBG.Position              = UDim2.new(0, 0, 0, 0)
logBG.BackgroundColor3      = CFG.BG_COLOR
logBG.BackgroundTransparency = CFG.BG_TRANSPARENCY
logBG.BorderSizePixel       = 0
logBG.Parent                = chatFrame

-- ── Scrolling frame for messages ──────────────────────────────────────────────
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                    = "ScrollFrame"
scrollFrame.Size                    = UDim2.new(1, 0, 1, 0)
scrollFrame.Position                = UDim2.new(0, 0, 0, 0)
scrollFrame.BackgroundTransparency  = 1
scrollFrame.BorderSizePixel         = 0
scrollFrame.ScrollBarThickness      = 4
scrollFrame.ScrollBarImageColor3    = Color3.fromRGB(160, 160, 160)
scrollFrame.CanvasSize              = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize     = Enum.AutomaticSize.Y
scrollFrame.ScrollingDirection      = Enum.ScrollingDirection.Y
scrollFrame.VerticalScrollBarInset  = Enum.ScrollBarInset.ScrollBar
scrollFrame.ElasticBehavior         = Enum.ElasticBehavior.Never
scrollFrame.Parent                  = logBG

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection            = Enum.FillDirection.Vertical
listLayout.SortOrder               = Enum.SortOrder.LayoutOrder
listLayout.VerticalAlignment       = Enum.VerticalAlignment.Bottom
listLayout.Padding                  = UDim.new(0, 1)
listLayout.Parent                   = scrollFrame

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingLeft           = UDim.new(0, CFG.PADDING_H)
scrollPadding.PaddingRight          = UDim.new(0, CFG.PADDING_H)
scrollPadding.PaddingTop            = UDim.new(0, CFG.PADDING_V)
scrollPadding.PaddingBottom         = UDim.new(0, CFG.PADDING_V)
scrollPadding.Parent                = scrollFrame

-- ── Input bar ─────────────────────────────────────────────────────────────────
local inputFrame = Instance.new("Frame")
inputFrame.Name                 = "InputFrame"
inputFrame.Size                 = UDim2.new(1, 0, 0, CFG.INPUT_HEIGHT)
inputFrame.Position             = UDim2.new(0, 0, 0, CFG.WINDOW_HEIGHT)
inputFrame.BackgroundColor3     = CFG.INPUT_BG_COLOR
inputFrame.BackgroundTransparency = CFG.INPUT_BG_TRANS
inputFrame.BorderSizePixel      = 0
inputFrame.Parent               = chatFrame

local inputBox = Instance.new("TextBox")
inputBox.Name                   = "InputBox"
inputBox.Size                   = UDim2.new(1, -8, 1, -6)
inputBox.Position               = UDim2.new(0, 4, 0, 3)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = true
inputBox.Font                   = CFG.FONT
inputBox.TextSize               = CFG.TEXT_SIZE
inputBox.TextColor3             = CFG.TEXT_COLOR
inputBox.PlaceholderText        = "To Everyone"
inputBox.PlaceholderColor3      = CFG.PLACEHOLDER_COLOR
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.TextYAlignment         = Enum.TextYAlignment.Center
inputBox.MultiLine              = false
inputBox.Parent                 = inputFrame

-- ─── State ────────────────────────────────────────────────────────────────────
local chatOpen      = true   -- whether the log+input are visible
local lastActivity  = tick() -- timestamp of last received message
local messageCount  = 0
local messageLabels = {}     -- ordered list of {frame, fadeThread}
local isFading      = false

-- ─── Helpers ──────────────────────────────────────────────────────────────────

-- Scroll to the very bottom of the message log
local function scrollToBottom()
	-- Defer one frame so AutomaticCanvasSize has time to update
	task.defer(function()
		scrollFrame.CanvasPosition = Vector2.new(0, math.huge)
	end)
end

-- Make the chat window fully opaque (un-fade)
local function showChat()
	lastActivity = tick()
	isFading     = false

	logBG.BackgroundTransparency = CFG.BG_TRANSPARENCY
	inputFrame.BackgroundTransparency = CFG.INPUT_BG_TRANS
	inputBox.TextTransparency = 0
	inputBox.PlaceholderColor3 = CFG.PLACEHOLDER_COLOR

	for _, entry in messageLabels do
		if entry.label then
			entry.label.TextTransparency = 0
		end
	end
end

-- Gradually fade out idle messages (matches default Roblox behaviour)
local function startFade()
	if isFading then return end
	isFading = true

	local tweenInfo = TweenInfo.new(CFG.FADE_DURATION, Enum.EasingStyle.Linear)

	-- Fade the backgrounds
	TweenService:Create(logBG,     tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(inputFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(inputBox,  tweenInfo, {TextTransparency = 1}):Play()

	-- Fade every message label
	for _, entry in messageLabels do
		if entry.label then
			TweenService:Create(entry.label, tweenInfo, {TextTransparency = 1}):Play()
		end
	end
end

-- Poll for idle → trigger fade (only when input is not focused)
task.spawn(function()
	while true do
		task.wait(0.5)
		if not inputBox:IsFocused() then
			local idleFor = tick() - lastActivity
			if idleFor >= CFG.IDLE_FADE_DELAY then
				startFade()
			end
		end
	end
end)

-- Remove oldest message when the log is full
local function pruneMessages()
	while #messageLabels >= CFG.MAX_MESSAGES do
		local oldest = table.remove(messageLabels, 1)
		if oldest and oldest.frame then
			oldest.frame:Destroy()
		end
	end
end

-- ─── Add a message entry to the log ──────────────────────────────────────────
local function addMessage(payload: table)
	pruneMessages()
	showChat()

	messageCount += 1
	local order = messageCount

	-- Container frame (auto-sizes vertically)
	local msgFrame = Instance.new("Frame")
	msgFrame.Name                   = "Message_" .. order
	msgFrame.BackgroundTransparency = 1
	msgFrame.Size                   = UDim2.new(1, 0, 0, 0)
	msgFrame.AutomaticSize          = Enum.AutomaticSize.Y
	msgFrame.LayoutOrder            = order
	msgFrame.BorderSizePixel        = 0
	msgFrame.Parent                 = scrollFrame

	local isSystem = payload.isSystem == true

	-- Build the rich-text string.
	-- For player messages: coloured bold name + colon + white message text.
	-- For system messages: just render the text in a warm yellow.
	local displayText
	if isSystem then
		displayText = "<font color='rgb(255,255,180)'>" .. payload.message .. "</font>"
	else
		local nr = math.floor((payload.nameColorR or 1) * 255)
		local ng = math.floor((payload.nameColorG or 1) * 255)
		local nb = math.floor((payload.nameColorB or 1) * 255)
		local hexColor = string.format("#%02X%02X%02X", nr, ng, nb)
		local safeName = payload.playerName or payload.userName or "Unknown"
		displayText = string.format(
			"<font color='%s'><b>%s</b></font><font color='rgb(255,255,255)'>: %s</font>",
			hexColor,
			safeName,
			payload.message
		)
	end

	local label = Instance.new("TextLabel")
	label.Name                  = "Label"
	label.BackgroundTransparency= 1
	label.Size                  = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize         = Enum.AutomaticSize.Y
	label.Font                  = CFG.FONT
	label.TextSize              = CFG.TEXT_SIZE
	label.TextColor3            = CFG.TEXT_COLOR
	label.TextXAlignment        = Enum.TextXAlignment.Left
	label.TextYAlignment        = Enum.TextYAlignment.Top
	label.TextWrapped           = true
	label.RichText              = true
	label.Text                  = displayText
	label.Parent                = msgFrame

	table.insert(messageLabels, { frame = msgFrame, label = label })
	scrollToBottom()
end

-- ─── Input handling ───────────────────────────────────────────────────────────

-- Submit the message
local function submitMessage()
	local text = inputBox.Text
	local trimmed = text:match("^%s*(.-)%s*$")
	if trimmed ~= "" then
		ChatRemotes.MessageSent:FireServer(trimmed)
	end
	inputBox.Text = ""
	inputBox:ReleaseFocus()
	lastActivity = tick() -- keep chat visible after sending
end

inputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitMessage()
	end
	-- After losing focus, reset the idle timer so fade starts fresh
	lastActivity = tick()
end)

-- Re-show chat when player focuses the input
inputBox.Focused:Connect(function()
	showChat()
end)

-- Press / to open chat (keyboard)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Slash then
		showChat()
		inputBox:CaptureFocus()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if inputBox:IsFocused() then
			inputBox.Text = ""
			inputBox:ReleaseFocus()
		end
	end
end)

-- ─── Remote listeners ─────────────────────────────────────────────────────────

ChatRemotes.MessageReceived.OnClientEvent:Connect(function(payload)
	addMessage(payload)
end)

ChatRemotes.SystemMessage.OnClientEvent:Connect(function(payload)
	addMessage(payload)
end)

-- ─── Initial state ────────────────────────────────────────────────────────────

-- Warm greeting so the player knows chat is working
task.delay(0.5, function()
	addMessage({
		isSystem = true,
		message  = "Welcome to Imperium! Press / or click the input to chat.",
	})
end)

print("[ChatClient] Custom chat system loaded.")
