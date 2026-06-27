--[[
	CommandBar.client.lua
	LocalScript — StarterPlayerScripts

	Staff command bar — integrates with the existing custom chat system.
	Does NOT use Roblox's default chat, TextChatService, or Player.Chatted.

	Controls:
	  ;         — open the command bar
	  Escape    — close without executing
	  Enter     — execute the current input
	  Up/Down   — cycle through command history
	  Tab       — accept the top autocomplete suggestion
	  Click outside bar — close

	UI Design:
	  • Dark translucent console aesthetic (not chat-like)
	  • Smooth slide-down + fade-in entrance animation
	  • Autocomplete dropdown with command name coloured in accent blue
	  • Arg hint line below the input shows expected argument labels
	  • Feedback toasts appear bottom-right
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes"))
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry"))

-- ─── Configuration ─────────────────────────────────────────────────────────────

local CFG = {
	OPEN_KEY         = Enum.KeyCode.Semicolon,

	-- Bar geometry
	BAR_WIDTH        = 520,
	BAR_HEIGHT       = 44,
	BAR_Y_OPEN       = 72,    -- px from top when open
	BAR_Y_CLOSED     = 52,    -- px from top when closed (slides up slightly)
	BAR_CORNER       = 8,

	-- Colours
	BG_DARK          = Color3.fromRGB(11, 11, 18),
	BG_BORDER        = Color3.fromRGB(60, 65, 100),
	BG_TRANS_OPEN    = 0.08,
	BG_TRANS_CLOSED  = 1,

	PROMPT_COLOR     = Color3.fromRGB(90, 140, 255),   -- accent blue ">"
	CMD_COLOR        = Color3.fromRGB(100, 185, 255),  -- command name highlight
	ARG_COLOR        = Color3.fromRGB(200, 200, 220),  -- arg text
	TEXT_COLOR       = Color3.fromRGB(230, 230, 255),
	PLACEHOLDER_COLOR= Color3.fromRGB(100, 105, 140),
	HINT_COLOR       = Color3.fromRGB(85, 90, 125),

	FONT             = Enum.Font.GothamSemibold,
	FONT_MONO        = Enum.Font.Code,
	TEXT_SIZE        = 15,
	HINT_SIZE        = 12,

	-- Autocomplete dropdown
	AC_MAX_ENTRIES   = 6,
	AC_ROW_HEIGHT    = 32,
	AC_BG            = Color3.fromRGB(14, 14, 22),
	AC_HOVER_BG      = Color3.fromRGB(30, 32, 60),
	AC_BORDER        = Color3.fromRGB(50, 55, 90),
	AC_DESC_COLOR    = Color3.fromRGB(130, 135, 170),

	-- Animation
	ANIM_TIME        = 0.18,

	-- History
	HISTORY_MAX      = 80,

	-- Feedback toast
	TOAST_DURATION   = 3.5,
	TOAST_FADE       = 0.4,
}

-- ─── State ─────────────────────────────────────────────────────────────────────

local isOpen        = false
local history       = {}       -- most-recent-first list of submitted commands
local historyIndex  = 0        -- 0 = not browsing; 1 = most recent, etc.
local savedDraft    = ""       -- input text saved before browsing history
local acMatches     = {}       -- current autocomplete matches { name, entry }
local acIndex       = 1        -- highlighted autocomplete row (1-based)

-- ─── Build the ScreenGui ───────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "StaffCommandBar"
gui.DisplayOrder    = 50
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.Enabled         = true
gui.Parent          = PlayerGui

-- ── Root frame (the console panel) ───────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name                  = "Panel"
panel.AnchorPoint           = Vector2.new(0.5, 0)
panel.Size                  = UDim2.new(0, CFG.BAR_WIDTH, 0, CFG.BAR_HEIGHT)
panel.Position              = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
panel.BackgroundColor3      = CFG.BG_DARK
panel.BackgroundTransparency = 1
panel.BorderSizePixel       = 0
panel.Visible               = false
panel.ClipsDescendants      = false
panel.Parent                = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, CFG.BAR_CORNER)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color        = CFG.BG_BORDER
panelStroke.Thickness    = 1
panelStroke.Transparency = 1
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Parent       = panel

-- Subtle top gradient line (console accent)
local accentLine = Instance.new("Frame")
accentLine.Name                  = "AccentLine"
accentLine.Size                  = UDim2.new(1, -2, 0, 1)
accentLine.Position              = UDim2.new(0, 1, 0, 0)
accentLine.BackgroundColor3      = CFG.PROMPT_COLOR
accentLine.BackgroundTransparency = 1
accentLine.BorderSizePixel       = 0
accentLine.ZIndex                = 3
accentLine.Parent                = panel

local accentLineCorner = Instance.new("UICorner")
accentLineCorner.CornerRadius = UDim.new(0, 2)
accentLineCorner.Parent = accentLine

-- ── Prompt symbol ">" ─────────────────────────────────────────────────────────

local promptLabel = Instance.new("TextLabel")
promptLabel.Name                  = "Prompt"
promptLabel.Size                  = UDim2.new(0, 28, 1, 0)
promptLabel.Position              = UDim2.new(0, 8, 0, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Font                  = CFG.FONT
promptLabel.TextSize              = CFG.TEXT_SIZE
promptLabel.TextColor3            = CFG.PROMPT_COLOR
promptLabel.TextTransparency      = 1
promptLabel.Text                  = "›"
promptLabel.TextXAlignment        = Enum.TextXAlignment.Center
promptLabel.TextYAlignment        = Enum.TextYAlignment.Center
promptLabel.ZIndex                = 3
promptLabel.Parent                = panel

-- ── Input box ─────────────────────────────────────────────────────────────────

local inputBox = Instance.new("TextBox")
inputBox.Name                   = "Input"
inputBox.Size                   = UDim2.new(1, -42, 1, 0)
inputBox.Position               = UDim2.new(0, 36, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.BorderSizePixel        = 0
inputBox.ClearTextOnFocus       = false
inputBox.Font                   = CFG.FONT_MONO
inputBox.TextSize               = CFG.TEXT_SIZE
inputBox.TextColor3             = CFG.TEXT_COLOR
inputBox.TextTransparency       = 1
inputBox.PlaceholderText        = "Enter a command…"
inputBox.PlaceholderColor3      = CFG.PLACEHOLDER_COLOR
inputBox.Text                   = ""
inputBox.TextXAlignment         = Enum.TextXAlignment.Left
inputBox.TextYAlignment         = Enum.TextYAlignment.Center
inputBox.MultiLine              = false
inputBox.ZIndex                 = 3
inputBox.Parent                 = panel

-- ── Arg hint label (shown below panel, inside a sub-frame) ────────────────────

local hintFrame = Instance.new("Frame")
hintFrame.Name                  = "HintFrame"
hintFrame.Size                  = UDim2.new(1, 0, 0, 20)
hintFrame.Position              = UDim2.new(0, 0, 1, 4)
hintFrame.BackgroundTransparency = 1
hintFrame.BorderSizePixel       = 0
hintFrame.Visible               = false
hintFrame.ZIndex                = 3
hintFrame.Parent                = panel

local hintLabel = Instance.new("TextLabel")
hintLabel.Name                  = "Hint"
hintLabel.Size                  = UDim2.new(1, -36, 1, 0)
hintLabel.Position              = UDim2.new(0, 36, 0, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font                  = Enum.Font.Gotham
hintLabel.TextSize              = CFG.HINT_SIZE
hintLabel.TextColor3            = CFG.HINT_COLOR
hintLabel.TextXAlignment        = Enum.TextXAlignment.Left
hintLabel.TextYAlignment        = Enum.TextYAlignment.Center
hintLabel.RichText              = true
hintLabel.Text                  = ""
hintLabel.ZIndex                = 4
hintLabel.Parent                = hintFrame

-- ── Autocomplete dropdown ──────────────────────────────────────────────────────

local dropdown = Instance.new("Frame")
dropdown.Name                  = "Autocomplete"
dropdown.AnchorPoint           = Vector2.new(0, 0)
dropdown.BackgroundColor3      = CFG.AC_BG
dropdown.BackgroundTransparency = 0.06
dropdown.BorderSizePixel       = 0
dropdown.Size                  = UDim2.new(1, 0, 0, 0)
dropdown.Position              = UDim2.new(0, 0, 1, 10)
dropdown.Visible               = false
dropdown.ClipsDescendants      = true
dropdown.ZIndex                = 10
dropdown.Parent                = panel

local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, CFG.BAR_CORNER)
dropdownCorner.Parent = dropdown

local dropdownStroke = Instance.new("UIStroke")
dropdownStroke.Color        = CFG.AC_BORDER
dropdownStroke.Thickness    = 1
dropdownStroke.Transparency = 0.4
dropdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dropdownStroke.Parent       = dropdown

local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.FillDirection    = Enum.FillDirection.Vertical
dropdownLayout.SortOrder        = Enum.SortOrder.LayoutOrder
dropdownLayout.Padding          = UDim.new(0, 0)
dropdownLayout.Parent           = dropdown

-- Click-outside detector (full-screen transparent frame behind everything)
local blocker = Instance.new("ImageButton")
blocker.Name                   = "Blocker"
blocker.Size                   = UDim2.new(1, 0, 1, 0)
blocker.Position               = UDim2.new(0, 0, 0, 0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 2
blocker.Visible                = false
blocker.Parent                 = gui

-- ─── Tween helpers ─────────────────────────────────────────────────────────────

local function tw(target, time, props, style, dir)
	style = style or Enum.EasingStyle.Quint
	dir   = dir   or Enum.EasingDirection.Out
	TweenService:Create(target, TweenInfo.new(time, style, dir), props):Play()
end

-- ─── Autocomplete rendering ────────────────────────────────────────────────────

local acRows = {}  -- reusable row frames

local function clearDropdown()
	for _, row in acRows do
		row.Visible = false
	end
end

local function buildDropdownRow(index: number): Frame
	local row = acRows[index]
	if row then return row end

	row = Instance.new("Frame")
	row.Name                  = "Row" .. index
	row.LayoutOrder           = index
	row.Size                  = UDim2.new(1, 0, 0, CFG.AC_ROW_HEIGHT)
	row.BackgroundColor3      = CFG.AC_HOVER_BG
	row.BackgroundTransparency = 1
	row.BorderSizePixel       = 0
	row.ZIndex                = 10
	row.Parent                = dropdown

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, 36)
	pad.PaddingRight  = UDim.new(0, 12)
	pad.PaddingTop    = UDim.new(0, 0)
	pad.PaddingBottom = UDim.new(0, 0)
	pad.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                  = "CmdName"
	nameLabel.Size                  = UDim2.new(0, 130, 1, 0)
	nameLabel.Position              = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font                  = CFG.FONT_MONO
	nameLabel.TextSize              = CFG.TEXT_SIZE - 1
	nameLabel.TextColor3            = CFG.CMD_COLOR
	nameLabel.TextXAlignment        = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment        = Enum.TextYAlignment.Center
	nameLabel.ZIndex                = 11
	nameLabel.RichText              = true
	nameLabel.Parent                = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name                  = "Desc"
	descLabel.Size                  = UDim2.new(1, -134, 1, 0)
	descLabel.Position              = UDim2.new(0, 134, 0, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Font                  = Enum.Font.Gotham
	descLabel.TextSize              = CFG.HINT_SIZE
	descLabel.TextColor3            = CFG.AC_DESC_COLOR
	descLabel.TextXAlignment        = Enum.TextXAlignment.Left
	descLabel.TextYAlignment        = Enum.TextYAlignment.Center
	descLabel.TextTruncate          = Enum.TextTruncate.AtEnd
	descLabel.ZIndex                = 11
	descLabel.Parent                = row

	-- Divider at bottom of row
	local divider = Instance.new("Frame")
	divider.Name                  = "Divider"
	divider.Size                  = UDim2.new(1, -36, 0, 1)
	divider.Position              = UDim2.new(0, 0, 1, -1)
	divider.BackgroundColor3      = CFG.AC_BORDER
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel       = 0
	divider.ZIndex                = 11
	divider.Parent                = row

	-- Click handler
	local btn = Instance.new("TextButton")
	btn.Name                   = "HitBtn"
	btn.Size                   = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.ZIndex                 = 12
	btn.Parent                 = row

	btn.MouseButton1Click:Connect(function()
		if acMatches[index] then
			inputBox.Text = acMatches[index].name .. " "
			inputBox:CaptureFocus()
			-- Move cursor to end
			inputBox.CursorPosition = #inputBox.Text + 1
		end
	end)

	btn.MouseEnter:Connect(function()
		acIndex = index
		refreshDropdown()
	end)

	acRows[index] = row
	return row
end

function refreshDropdown()
	clearDropdown()

	local count = math.min(#acMatches, CFG.AC_MAX_ENTRIES)
	if count == 0 then
		dropdown.Visible = false
		hintFrame.Visible = false
		return
	end

	dropdown.Size    = UDim2.new(1, 0, 0, count * CFG.AC_ROW_HEIGHT)
	dropdown.Visible = true

	for i = 1, count do
		local match = acMatches[i]
		local row   = buildDropdownRow(i)
		row.Visible  = true

		local nameL = row:FindFirstChild("CmdName")
		local descL = row:FindFirstChild("Desc")
		local isSelected = (i == acIndex)

		-- Highlight the selected row
		tw(row, 0.08, {
			BackgroundTransparency = isSelected and 0.55 or 1,
		})

		-- Colour the command name (bold accent on hover)
		if nameL then
			nameL.TextColor3 = isSelected and Color3.fromRGB(150, 210, 255) or CFG.CMD_COLOR
			nameL.Text       = match.name
		end
		if descL then
			descL.Text = match.entry.description
		end

		-- Hide last row divider
		local div = row:FindFirstChild("Divider")
		if div then div.Visible = (i ~= count) end
	end

	-- Update arg hint for selected match
	local selected = acMatches[acIndex]
	if selected and #selected.entry.args > 0 then
		local parts = {}
		table.insert(parts, '<font color="#5A8CFF">' .. selected.entry.name .. "</font>")
		for _, arg in selected.entry.args do
			local isOptional = arg:sub(-1) == "?"
			local label = isOptional and arg:sub(1, -2) or arg
			local color = isOptional and "#555870" or "#888aaa"
			local wrap  = isOptional and "[" or "<"
			local wrapE = isOptional and "]" or ">"
			table.insert(parts,
				'<font color="' .. color .. '">' .. wrap .. label .. wrapE .. "</font>")
		end
		hintLabel.Text    = table.concat(parts, "  ")
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

-- ─── Autocomplete update (called whenever input changes) ─────────────────────

local function updateAutocomplete()
	local text  = inputBox.Text
	local tokens = CommandRegistry.parseArgs(text)
	local query  = tokens[1] or ""

	-- Only show autocomplete when the user hasn't finished typing the command
	-- (i.e., no space after the first token yet, or text is empty)
	local hasSpace = text:find("%s")
	if hasSpace then
		-- Command already chosen — update hint for chosen command only
		local chosen = CommandRegistry.COMMANDS[query:lower()]
		if chosen then
			acMatches = { { name = query:lower(), entry = chosen } }
			acIndex   = 1
		else
			acMatches = {}
		end
		clearDropdown()
		dropdown.Visible = false

		-- Still show arg hint
		if chosen and #chosen.args > 0 then
			local parts = {}
			for _, arg in chosen.args do
				local isOptional = arg:sub(-1) == "?"
				local label = isOptional and arg:sub(1, -2) or arg
				local color = isOptional and "#555870" or "#888aaa"
				local wrap  = isOptional and "[" or "<"
				local wrapE = isOptional and "]" or ">"
				table.insert(parts,
					'<font color="' .. color .. '">' .. wrap .. label .. wrapE .. "</font>")
			end
			hintLabel.Text    = '<font color="#5A8CFF">' .. query:lower() .. "</font>  " .. table.concat(parts, "  ")
			hintFrame.Visible = true
		else
			hintFrame.Visible = false
		end
		return
	end

	if query == "" then
		acMatches = {}
		refreshDropdown()
		return
	end

	acMatches = CommandRegistry.getMatches(query)
	acIndex   = 1
	refreshDropdown()
end

-- ─── Open / Close logic ────────────────────────────────────────────────────────

local openTInfo  = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local closeTInfo = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local function openBar()
	if isOpen then return end
	isOpen = true
	historyIndex = 0
	savedDraft   = ""

	panel.Visible = true
	blocker.Visible = true

	-- Reset position to slightly above for slide-in effect
	panel.Position = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
	panel.BackgroundTransparency = 1

	TweenService:Create(panel, openTInfo, {
		Position             = UDim2.new(0.5, 0, 0, CFG.BAR_Y_OPEN),
		BackgroundTransparency = CFG.BG_TRANS_OPEN,
	}):Play()

	tw(panelStroke, CFG.ANIM_TIME, { Transparency = 0.15 })
	tw(accentLine,  CFG.ANIM_TIME, { BackgroundTransparency = 0.3 })
	tw(promptLabel, CFG.ANIM_TIME, { TextTransparency = 0 })
	tw(inputBox,    CFG.ANIM_TIME, { TextTransparency = 0 })

	task.delay(CFG.ANIM_TIME * 0.5, function()
		if isOpen then
			inputBox:CaptureFocus()
		end
	end)
end

local function closeBar()
	if not isOpen then return end
	isOpen = false
	historyIndex = 0

	dropdown.Visible  = false
	hintFrame.Visible = false
	blocker.Visible   = false

	TweenService:Create(panel, closeTInfo, {
		Position             = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED),
		BackgroundTransparency = 1,
	}):Play()

	tw(panelStroke, CFG.ANIM_TIME, { Transparency = 1 })
	tw(accentLine,  CFG.ANIM_TIME, { BackgroundTransparency = 1 })
	tw(promptLabel, CFG.ANIM_TIME, { TextTransparency = 1 })
	tw(inputBox,    CFG.ANIM_TIME, { TextTransparency = 1 })

	task.delay(CFG.ANIM_TIME, function()
		if not isOpen then
			panel.Visible   = false
			inputBox.Text   = ""
			acMatches       = {}
		end
	end)

	inputBox:ReleaseFocus()
end

-- ─── Command execution ─────────────────────────────────────────────────────────

local function executeCommand()
	local raw    = inputBox.Text:match("^%s*(.-)%s*$")
	if raw == "" then
		closeBar()
		return
	end

	local tokens = CommandRegistry.parseArgs(raw)
	local cmdName = tokens[1] and tokens[1]:lower() or ""
	local args    = {}
	for i = 2, #tokens do
		table.insert(args, tokens[i])
	end

	-- Save to history (deduplicate immediately adjacent)
	if history[1] ~= raw then
		table.insert(history, 1, raw)
		if #history > CFG.HISTORY_MAX then
			table.remove(history, #history)
		end
	end

	-- Fire to server
	CommandRemotes.CommandExecuted:FireServer(cmdName, args)

	closeBar()
end

-- ─── Feedback toasts ───────────────────────────────────────────────────────────

local toastGui = Instance.new("ScreenGui")
toastGui.Name           = "CmdToasts"
toastGui.DisplayOrder   = 55
toastGui.ResetOnSpawn   = false
toastGui.IgnoreGuiInset = true
toastGui.Parent         = PlayerGui

local toastContainer = Instance.new("Frame")
toastContainer.Name                  = "Container"
toastContainer.AnchorPoint           = Vector2.new(1, 1)
toastContainer.Size                  = UDim2.new(0, 340, 1, -20)
toastContainer.Position              = UDim2.new(1, -16, 1, -20)
toastContainer.BackgroundTransparency = 1
toastContainer.Parent                = toastGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection    = Enum.FillDirection.Vertical
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder        = Enum.SortOrder.LayoutOrder
toastLayout.Padding          = UDim.new(0, 6)
toastLayout.Parent           = toastContainer

local toastOrder = 0

local function showToast(success: boolean, message: string)
	toastOrder += 1
	local order = toastOrder

	local toast = Instance.new("Frame")
	toast.LayoutOrder           = order
	toast.Size                  = UDim2.new(1, 0, 0, 42)
	toast.BackgroundColor3      = success
		and Color3.fromRGB(18, 42, 28)
		or  Color3.fromRGB(42, 14, 14)
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel        = 0
	toast.Parent                 = toastContainer

	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 6)
	tc.Parent = toast

	local ts = Instance.new("UIStroke")
	ts.Color        = success and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(180, 50, 50)
	ts.Thickness    = 1
	ts.Transparency = 0.5
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ts.Parent       = toast

	local icon = Instance.new("TextLabel")
	icon.Size                  = UDim2.new(0, 32, 1, 0)
	icon.Position              = UDim2.new(0, 0, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Font                  = Enum.Font.GothamBold
	icon.TextSize              = 14
	icon.TextColor3            = success
		and Color3.fromRGB(60, 200, 100)
		or  Color3.fromRGB(220, 70, 70)
	icon.Text                  = success and "✓" or "✕"
	icon.TextTransparency      = 1
	icon.Parent                = toast

	local lbl = Instance.new("TextLabel")
	lbl.Size                  = UDim2.new(1, -36, 1, 0)
	lbl.Position              = UDim2.new(0, 36, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font                  = Enum.Font.Gotham
	lbl.TextSize              = 13
	lbl.TextColor3            = Color3.fromRGB(210, 215, 230)
	lbl.TextXAlignment        = Enum.TextXAlignment.Left
	lbl.TextYAlignment        = Enum.TextYAlignment.Center
	lbl.TextWrapped           = true
	lbl.TextTransparency      = 1
	lbl.Text                  = message
	lbl.Parent                = toast

	task.spawn(function()
		local fadeIn = TweenInfo.new(CFG.TOAST_FADE, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		tw(toast, CFG.TOAST_FADE, { BackgroundTransparency = 0.15 })
		tw(icon,  CFG.TOAST_FADE, { TextTransparency = 0 })
		tw(lbl,   CFG.TOAST_FADE, { TextTransparency = 0 })
		task.wait(CFG.TOAST_DURATION)
		tw(toast, CFG.TOAST_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw(icon,  CFG.TOAST_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw(lbl,   CFG.TOAST_FADE, { TextTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(CFG.TOAST_FADE)
		toast:Destroy()
	end)
end

CommandRemotes.CommandFeedback.OnClientEvent:Connect(function(success: boolean, message: string)
	showToast(success, message)
end)

-- ─── Input event handling ──────────────────────────────────────────────────────

-- Track whether the TextBox is currently focused so we can intercept keys
local inputFocused = false

inputBox.Focused:Connect(function()
	inputFocused = true
end)

inputBox.FocusLost:Connect(function(enterPressed)
	inputFocused = false
	if enterPressed then
		executeCommand()
	end
end)

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
	if isOpen then
		updateAutocomplete()
	end
end)

-- Click outside = close
blocker.MouseButton1Click:Connect(function()
	closeBar()
end)

-- Keyboard handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Open key (works even when game has processed input, unless in another textbox)
	if input.KeyCode == CFG.OPEN_KEY and not gameProcessed then
		if isOpen then
			closeBar()
		else
			openBar()
		end
		return
	end

	if not isOpen then return end

	-- Keys that work while bar is open
	if input.KeyCode == Enum.KeyCode.Escape then
		closeBar()
		return
	end

	if not inputFocused then return end

	-- History navigation
	if input.KeyCode == Enum.KeyCode.Up then
		if historyIndex == 0 then
			savedDraft = inputBox.Text
		end
		historyIndex = math.min(historyIndex + 1, #history)
		if history[historyIndex] then
			inputBox.Text = history[historyIndex]
			task.defer(function()
				inputBox.CursorPosition = #inputBox.Text + 1
			end)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Down then
		if historyIndex > 0 then
			historyIndex -= 1
			if historyIndex == 0 then
				inputBox.Text = savedDraft
			else
				inputBox.Text = history[historyIndex]
			end
			task.defer(function()
				inputBox.CursorPosition = #inputBox.Text + 1
			end)
		end
		return
	end

	-- Autocomplete navigation
	if input.KeyCode == Enum.KeyCode.Tab then
		if #acMatches > 0 then
			local match = acMatches[acIndex] or acMatches[1]
			if match then
				inputBox.Text = match.name .. " "
				task.defer(function()
					inputBox.CursorPosition = #inputBox.Text + 1
				end)
			end
		end
		return
	end

	-- Cycle dropdown with Ctrl+N / Ctrl+P (optional bonus)
	if input.KeyCode == Enum.KeyCode.N
		and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		if #acMatches > 0 then
			acIndex = (acIndex % #acMatches) + 1
			refreshDropdown()
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.P
		and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		if #acMatches > 0 then
			acIndex = ((acIndex - 2) % #acMatches) + 1
			refreshDropdown()
		end
		return
	end
end)

print("[CommandBar] Staff command bar active. Press ; to open.")
