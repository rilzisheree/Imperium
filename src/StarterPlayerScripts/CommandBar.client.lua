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

        UI Design (v2 — yellow/black administration theme):
          • Dark/black console aesthetic with yellow accents
          • Smooth slide-down + fade-in entrance animation
          • Autocomplete dropdown with command name coloured in accent yellow
          • Arg hint line below the input shows expected argument labels
          • Player suggestion panel (UI-only placeholder)
          • Right-side command notification that slides in from the edge
          • Feedback toasts appear bottom-right
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes"))
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry"))

-- ─── Configuration ─────────────────────────────────────────────────────────────

local CFG = {
        OPEN_KEY         = Enum.KeyCode.Semicolon,

        -- Bar geometry (slightly larger than v1)
        BAR_WIDTH        = 580,
        BAR_HEIGHT       = 52,
        BAR_Y_OPEN       = 80,
        BAR_Y_CLOSED     = 58,
        BAR_CORNER       = 8,

        -- ── Yellow / Black theme ──────────────────────────────────────────────────
        BG_DARK          = Color3.fromRGB(10, 10, 12),
        BG_BORDER        = Color3.fromRGB(220, 180, 0),
        BG_TRANS_OPEN    = 0.06,
        BG_TRANS_CLOSED  = 1,

        PROMPT_COLOR     = Color3.fromRGB(255, 210, 0),    -- yellow "›"
        CMD_COLOR        = Color3.fromRGB(255, 220, 40),   -- command name highlight
        ARG_COLOR        = Color3.fromRGB(210, 210, 220),  -- arg text
        TEXT_COLOR       = Color3.fromRGB(240, 240, 255),
        PLACEHOLDER_COLOR= Color3.fromRGB(90, 90, 105),
        HINT_COLOR       = Color3.fromRGB(130, 110, 40),

        FONT             = Enum.Font.GothamSemibold,
        FONT_MONO        = Enum.Font.Code,
        TEXT_SIZE        = 15,
        HINT_SIZE        = 12,

        -- Autocomplete dropdown
        AC_MAX_ENTRIES   = 6,
        AC_ROW_HEIGHT    = 34,
        AC_BG            = Color3.fromRGB(12, 12, 14),
        AC_HOVER_BG      = Color3.fromRGB(38, 32, 6),
        AC_BORDER        = Color3.fromRGB(180, 145, 0),
        AC_DESC_COLOR    = Color3.fromRGB(150, 130, 60),

        -- Animation
        ANIM_TIME        = 0.18,

        -- History
        HISTORY_MAX      = 80,

        -- Feedback toast
        TOAST_DURATION   = 3.5,
        TOAST_FADE       = 0.4,

        -- Player suggestion panel
        PS_ROW_HEIGHT    = 36,
        PS_MAX_ENTRIES   = 4,
        PS_BG            = Color3.fromRGB(10, 10, 12),
        PS_HOVER_BG      = Color3.fromRGB(38, 32, 6),
        PS_BORDER        = Color3.fromRGB(180, 145, 0),
        PS_TEXT_COLOR    = Color3.fromRGB(230, 230, 240),

        -- Right-side notification
        NOTIF_WIDTH      = 260,
        NOTIF_HEIGHT     = 52,
        NOTIF_Y          = 120,
        NOTIF_DURATION   = 3.0,
        NOTIF_FADE       = 0.35,
        NOTIF_SLIDE      = 0.28,
}

-- ─── State ─────────────────────────────────────────────────────────────────────

local isOpen        = false
local history       = {}
local historyIndex  = 0
local savedDraft    = ""
local acMatches     = {}
local acIndex       = 1

-- ─── Tween helper ──────────────────────────────────────────────────────────────

local function tw(target, time, props, style, dir)
        style = style or Enum.EasingStyle.Quint
        dir   = dir   or Enum.EasingDirection.Out
        TweenService:Create(target, TweenInfo.new(time, style, dir), props):Play()
end

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
panelStroke.Thickness    = 1.5
panelStroke.Transparency = 1
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Parent       = panel

-- Yellow top accent line
local accentLine = Instance.new("Frame")
accentLine.Name                  = "AccentLine"
accentLine.Size                  = UDim2.new(1, -2, 0, 2)
accentLine.Position              = UDim2.new(0, 1, 0, 0)
accentLine.BackgroundColor3      = CFG.PROMPT_COLOR
accentLine.BackgroundTransparency = 1
accentLine.BorderSizePixel       = 0
accentLine.ZIndex                = 3
accentLine.Parent                = panel

local accentLineCorner = Instance.new("UICorner")
accentLineCorner.CornerRadius = UDim.new(0, 2)
accentLineCorner.Parent = accentLine

-- ── Prompt symbol "›" ─────────────────────────────────────────────────────────

local promptLabel = Instance.new("TextLabel")
promptLabel.Name                  = "Prompt"
promptLabel.Size                  = UDim2.new(0, 32, 1, 0)
promptLabel.Position              = UDim2.new(0, 10, 0, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Font                  = CFG.FONT
promptLabel.TextSize              = 18
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
inputBox.Size                   = UDim2.new(1, -48, 1, 0)
inputBox.Position               = UDim2.new(0, 42, 0, 0)
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

-- ── Arg hint label ────────────────────────────────────────────────────────────

local hintFrame = Instance.new("Frame")
hintFrame.Name                  = "HintFrame"
hintFrame.Size                  = UDim2.new(1, 0, 0, 20)
hintFrame.Position              = UDim2.new(0, 0, 1, 5)
hintFrame.BackgroundTransparency = 1
hintFrame.BorderSizePixel       = 0
hintFrame.Visible               = false
hintFrame.ZIndex                = 3
hintFrame.Parent                = panel

local hintLabel = Instance.new("TextLabel")
hintLabel.Name                  = "Hint"
hintLabel.Size                  = UDim2.new(1, -42, 1, 0)
hintLabel.Position              = UDim2.new(0, 42, 0, 0)
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
dropdown.BackgroundTransparency = 0.04
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
dropdownStroke.Transparency = 0.3
dropdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dropdownStroke.Parent       = dropdown

local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.FillDirection    = Enum.FillDirection.Vertical
dropdownLayout.SortOrder        = Enum.SortOrder.LayoutOrder
dropdownLayout.Padding          = UDim.new(0, 0)
dropdownLayout.Parent           = dropdown

-- ── Player suggestion panel ────────────────────────────────────────────────────
-- Shows real server players filtered as you type a player-type argument.
-- Appears below the command bar only when the current arg expects a player.

local playerSuggestPanel = Instance.new("Frame")
playerSuggestPanel.Name                  = "PlayerSuggestions"
playerSuggestPanel.AnchorPoint           = Vector2.new(0.5, 0)
playerSuggestPanel.Size                  = UDim2.new(0, CFG.BAR_WIDTH, 0, CFG.PS_ROW_HEIGHT * CFG.PS_MAX_ENTRIES)
playerSuggestPanel.Position              = UDim2.new(0.5, 0, 1, 10)
playerSuggestPanel.BackgroundColor3      = CFG.PS_BG
playerSuggestPanel.BackgroundTransparency = 0.04
playerSuggestPanel.BorderSizePixel       = 0
playerSuggestPanel.Visible               = false
playerSuggestPanel.ClipsDescendants      = true
playerSuggestPanel.ZIndex                = 9
playerSuggestPanel.Parent                = panel

local pspCorner = Instance.new("UICorner")
pspCorner.CornerRadius = UDim.new(0, CFG.BAR_CORNER)
pspCorner.Parent = playerSuggestPanel

local pspStroke = Instance.new("UIStroke")
pspStroke.Color        = CFG.PS_BORDER
pspStroke.Thickness    = 1
pspStroke.Transparency = 0.3
pspStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pspStroke.Parent = playerSuggestPanel

local pspScroll = Instance.new("ScrollingFrame")
pspScroll.Size                  = UDim2.new(1, 0, 1, 0)
pspScroll.BackgroundTransparency = 1
pspScroll.BorderSizePixel       = 0
pspScroll.ScrollBarThickness    = 3
pspScroll.ScrollBarImageColor3  = CFG.PROMPT_COLOR
pspScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
pspScroll.ZIndex                = 10
pspScroll.Parent                = playerSuggestPanel

local pspScrollLayout = Instance.new("UIListLayout")
pspScrollLayout.FillDirection = Enum.FillDirection.Vertical
pspScrollLayout.SortOrder     = Enum.SortOrder.LayoutOrder
pspScrollLayout.Padding       = UDim.new(0, 0)
pspScrollLayout.Parent        = pspScroll

-- ─── Player suggestion state & helpers ────────────────────────────────────────

local filteredPlayers: { string } = {}   -- current Name list shown
local playerSuggestIndex = 1             -- highlighted row (for Tab)
local psRows: { Frame } = {}             -- reusable row frames

local PLAYER_ARG_LABELS = { player = true, from = true, to = true }

local function isPlayerArg(label: string): boolean
        return PLAYER_ARG_LABELS[label:lower():gsub("%?", "")] == true
end

local function buildPsRow(index: number): Frame
        if psRows[index] then return psRows[index] end

        local row = Instance.new("Frame")
        row.Name                   = "PSRow" .. index
        row.LayoutOrder            = index
        row.Size                   = UDim2.new(1, 0, 0, CFG.PS_ROW_HEIGHT)
        row.BackgroundColor3       = CFG.PS_HOVER_BG
        row.BackgroundTransparency = 1
        row.BorderSizePixel        = 0
        row.ZIndex                 = 10
        row.Parent                 = pspScroll

        local icon = Instance.new("TextLabel")
        icon.Name                   = "Icon"
        icon.Size                   = UDim2.new(0, 36, 1, 0)
        icon.Position               = UDim2.new(0, 0, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Font                   = CFG.FONT
        icon.TextSize               = 13
        icon.TextColor3             = CFG.PROMPT_COLOR
        icon.Text                   = "⬡"
        icon.TextXAlignment         = Enum.TextXAlignment.Center
        icon.TextYAlignment         = Enum.TextYAlignment.Center
        icon.ZIndex                 = 11
        icon.Parent                 = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name                   = "PlayerName"
        nameLabel.Size                   = UDim2.new(1, -44, 1, 0)
        nameLabel.Position               = UDim2.new(0, 44, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font                   = CFG.FONT
        nameLabel.TextSize               = CFG.TEXT_SIZE - 1
        nameLabel.TextColor3             = CFG.PS_TEXT_COLOR
        nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
        nameLabel.TextYAlignment         = Enum.TextYAlignment.Center
        nameLabel.ZIndex                 = 11
        nameLabel.Parent                 = row

        local divider = Instance.new("Frame")
        divider.Name                  = "Divider"
        divider.Size                  = UDim2.new(1, -44, 0, 1)
        divider.Position              = UDim2.new(0, 44, 1, -1)
        divider.BackgroundColor3      = CFG.PS_BORDER
        divider.BackgroundTransparency = 0.6
        divider.BorderSizePixel       = 0
        divider.ZIndex                = 11
        divider.Parent                = row

        local hitBtn = Instance.new("TextButton")
        hitBtn.Size                   = UDim2.new(1, 0, 1, 0)
        hitBtn.BackgroundTransparency = 1
        hitBtn.Text                   = ""
        hitBtn.ZIndex                 = 12
        hitBtn.Parent                 = row

        -- Click: insert player name into the input box
        hitBtn.MouseButton1Click:Connect(function()
                local chosen = filteredPlayers[index]
                if not chosen then return end
                local tokens = CommandRegistry.parseArgs(inputBox.Text)
                -- Replace the last partially-typed token with the chosen name
                local base = tokens[1] and table.concat(tokens, " ", 1, math.max(1, #tokens - 1)) or ""
                local needsSpace = base ~= "" and inputBox.Text:sub(-1) ~= " "
                inputBox.Text = base .. (needsSpace and " " or (base ~= "" and " " or "")) .. chosen .. " "
                inputBox:CaptureFocus()
                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
        end)

        hitBtn.MouseEnter:Connect(function()
                playerSuggestIndex = index
                tw(row, 0.07, { BackgroundTransparency = 0.55 })
                local nl = row:FindFirstChild("PlayerName")
                if nl then tw(nl, 0.07, { TextColor3 = CFG.PROMPT_COLOR }) end
        end)
        hitBtn.MouseLeave:Connect(function()
                if playerSuggestIndex ~= index then
                        tw(row, 0.07, { BackgroundTransparency = 1 })
                        local nl = row:FindFirstChild("PlayerName")
                        if nl then tw(nl, 0.07, { TextColor3 = CFG.PS_TEXT_COLOR }) end
                end
        end)

        psRows[index] = row
        return row
end

local function refreshPlayerSuggestions(filter: string)
        -- Collect and filter players from the server
        local all = Players:GetPlayers()
        local lower = filter:lower()
        local matched: { string } = {}

        for _, p in all do
                if p ~= LocalPlayer then  -- skip self
                        if lower == ""
                                or p.Name:lower():sub(1, #lower) == lower
                                or p.DisplayName:lower():sub(1, #lower) == lower
                        then
                                table.insert(matched, p.Name)
                        end
                end
        end

        -- Also allow "me" to refer to yourself
        if lower == "" or ("me"):sub(1, #lower) == lower then
                table.insert(matched, 1, LocalPlayer.Name .. " (me)")
        end

        filteredPlayers = matched
        playerSuggestIndex = 1

        local count = math.min(#matched, CFG.PS_MAX_ENTRIES)

        if count == 0 then
                playerSuggestPanel.Visible = false
                return
        end

        -- Hide all rows first
        for _, row in psRows do
                row.Visible = false
        end

        -- Show / update rows
        for i = 1, count do
                local row = buildPsRow(i)
                row.Visible = true

                local nl  = row:FindFirstChild("PlayerName")
                local div = row:FindFirstChild("Divider")
                local isSelected = (i == 1)  -- first entry highlighted by default

                tw(row, 0.07, { BackgroundTransparency = isSelected and 0.55 or 1 })
                if nl then
                        nl.Text       = matched[i]
                        nl.TextColor3 = isSelected and CFG.PROMPT_COLOR or CFG.PS_TEXT_COLOR
                end
                if div then div.Visible = (i ~= count) end
        end

        local totalH = count * CFG.PS_ROW_HEIGHT
        playerSuggestPanel.Size     = UDim2.new(0, CFG.BAR_WIDTH, 0, totalH)
        pspScroll.CanvasSize        = UDim2.new(0, 0, 0, totalH)
        playerSuggestPanel.Visible  = true
end

local function hidePlayerSuggestions()
        playerSuggestPanel.Visible = false
        filteredPlayers = {}
end

-- ── Click-outside blocker ──────────────────────────────────────────────────────

local blocker = Instance.new("ImageButton")
blocker.Name                   = "Blocker"
blocker.Size                   = UDim2.new(1, 0, 1, 0)
blocker.Position               = UDim2.new(0, 0, 0, 0)
blocker.BackgroundTransparency = 1
blocker.ZIndex                 = 2
blocker.Visible                = false
blocker.Parent                 = gui

-- ─── Right-side command notification (UI + animation only) ─────────────────────

local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "CmdNotification"
notifGui.DisplayOrder   = 56
notifGui.ResetOnSpawn   = false
notifGui.IgnoreGuiInset = true
notifGui.Parent         = PlayerGui

local notifFrame = Instance.new("Frame")
notifFrame.Name                  = "NotifFrame"
notifFrame.AnchorPoint           = Vector2.new(1, 0)
notifFrame.Size                  = UDim2.new(0, CFG.NOTIF_WIDTH, 0, CFG.NOTIF_HEIGHT)
notifFrame.Position              = UDim2.new(1, CFG.NOTIF_WIDTH + 16, 0, CFG.NOTIF_Y)
notifFrame.BackgroundColor3      = Color3.fromRGB(10, 10, 12)
notifFrame.BackgroundTransparency = 0.08
notifFrame.BorderSizePixel       = 0
notifFrame.Visible               = false
notifFrame.ZIndex                = 20
notifFrame.Parent                = notifGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 10)
notifCorner.Parent = notifFrame

local notifStroke = Instance.new("UIStroke")
notifStroke.Color        = CFG.BG_BORDER
notifStroke.Thickness    = 1.5
notifStroke.Transparency = 0.2
notifStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
notifStroke.Parent = notifFrame

-- Yellow left accent bar
local notifAccent = Instance.new("Frame")
notifAccent.Name                  = "Accent"
notifAccent.Size                  = UDim2.new(0, 3, 1, -12)
notifAccent.Position              = UDim2.new(0, 6, 0, 6)
notifAccent.BackgroundColor3      = CFG.PROMPT_COLOR
notifAccent.BackgroundTransparency = 0
notifAccent.BorderSizePixel       = 0
notifAccent.ZIndex                = 21
notifAccent.Parent                = notifFrame

local notifAccentCorner = Instance.new("UICorner")
notifAccentCorner.CornerRadius = UDim.new(0, 2)
notifAccentCorner.Parent = notifAccent

-- Icon label
local notifIcon = Instance.new("TextLabel")
notifIcon.Name                  = "Icon"
notifIcon.Size                  = UDim2.new(0, 32, 1, 0)
notifIcon.Position              = UDim2.new(0, 16, 0, 0)
notifIcon.BackgroundTransparency = 1
notifIcon.Font                  = Enum.Font.GothamBold
notifIcon.TextSize              = 18
notifIcon.TextColor3            = CFG.PROMPT_COLOR
notifIcon.TextXAlignment        = Enum.TextXAlignment.Center
notifIcon.TextYAlignment        = Enum.TextYAlignment.Center
notifIcon.Text                  = "✓"
notifIcon.ZIndex                = 21
notifIcon.Parent                = notifFrame

-- Message label
local notifLabel = Instance.new("TextLabel")
notifLabel.Name                  = "Label"
notifLabel.Size                  = UDim2.new(1, -56, 1, 0)
notifLabel.Position              = UDim2.new(0, 50, 0, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Font                  = CFG.FONT
notifLabel.TextSize              = 13
notifLabel.TextColor3            = Color3.fromRGB(220, 220, 235)
notifLabel.TextXAlignment        = Enum.TextXAlignment.Left
notifLabel.TextYAlignment        = Enum.TextYAlignment.Center
notifLabel.TextTruncate          = Enum.TextTruncate.AtEnd
notifLabel.Text                  = "Command Executed"
notifLabel.ZIndex                = 21
notifLabel.Parent                = notifFrame

-- Notification slide-in/out function
local notifActive = false
local function showNotification(message: string)
        notifLabel.Text   = message
        notifFrame.Visible = true
        notifActive = true

        -- Slide in from right
        notifFrame.Position = UDim2.new(1, 16, 0, CFG.NOTIF_Y)
        tw(notifFrame, CFG.NOTIF_SLIDE, {
                Position = UDim2.new(1, -(CFG.NOTIF_WIDTH + 16), 0, CFG.NOTIF_Y),
        })

        task.delay(CFG.NOTIF_DURATION, function()
                if not notifActive then return end
                -- Slide back out to the right
                tw(notifFrame, CFG.NOTIF_SLIDE, {
                        Position = UDim2.new(1, 16, 0, CFG.NOTIF_Y),
                }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                task.delay(CFG.NOTIF_SLIDE, function()
                        notifFrame.Visible = false
                        notifActive = false
                end)
        end)
end

-- ─── Autocomplete rows (reusable) ─────────────────────────────────────────────

local acRows = {}

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
        pad.PaddingLeft   = UDim.new(0, 42)
        pad.PaddingRight  = UDim.new(0, 12)
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

        local divider = Instance.new("Frame")
        divider.Name                  = "Divider"
        divider.Size                  = UDim2.new(1, -42, 0, 1)
        divider.Position              = UDim2.new(0, 0, 1, -1)
        divider.BackgroundColor3      = CFG.AC_BORDER
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel       = 0
        divider.ZIndex                = 11
        divider.Parent                = row

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
                        task.defer(function()
                                inputBox.CursorPosition = #inputBox.Text + 1
                        end)
                end
        end)

        btn.MouseEnter:Connect(function()
                acIndex = index
                -- Refresh highlights without a full rebuild
                for i, r in acRows do
                        if r and r.Visible then
                                tw(r, 0.06, { BackgroundTransparency = (i == acIndex) and 0.55 or 1 })
                                local nl = r:FindFirstChild("CmdName")
                                if nl then nl.TextColor3 = (i == acIndex) and Color3.fromRGB(255, 235, 80) or CFG.CMD_COLOR end
                        end
                end
        end)

        acRows[index] = row
        return row
end

function refreshDropdown()
        clearDropdown()

        local count = math.min(#acMatches, CFG.AC_MAX_ENTRIES)
        if count == 0 then
                dropdown.Visible  = false
                hintFrame.Visible = false
                return
        end

        dropdown.Size    = UDim2.new(1, 0, 0, count * CFG.AC_ROW_HEIGHT)
        dropdown.Visible = true

        for i = 1, count do
                local match = acMatches[i]
                local row   = buildDropdownRow(i)
                row.Visible  = true

                local nameL      = row:FindFirstChild("CmdName")
                local descL      = row:FindFirstChild("Desc")
                local isSelected = (i == acIndex)

                tw(row, 0.08, { BackgroundTransparency = isSelected and 0.55 or 1 })

                if nameL then
                        nameL.TextColor3 = isSelected and Color3.fromRGB(255, 235, 80) or CFG.CMD_COLOR
                        nameL.Text       = match.name
                end
                if descL then
                        descL.Text = match.entry.description
                end

                local div = row:FindFirstChild("Divider")
                if div then div.Visible = (i ~= count) end
        end

        -- Update arg hint
        local selected = acMatches[acIndex]
        if selected and #selected.entry.args > 0 then
                local parts = {}
                table.insert(parts, '<font color="#FFD700">' .. selected.entry.name .. "</font>")
                for _, arg in selected.entry.args do
                        local isOptional = arg:sub(-1) == "?"
                        local label = isOptional and arg:sub(1, -2) or arg
                        local color = isOptional and "#806010" or "#a09050"
                        local wrap  = isOptional and "[" or "<"
                        local wrapE = isOptional and "]" or ">"
                        table.insert(parts, '<font color="' .. color .. '">' .. wrap .. label .. wrapE .. "</font>")
                end
                hintLabel.Text    = table.concat(parts, "  ")
                hintFrame.Visible = true
        else
                hintFrame.Visible = false
        end
end

-- ─── Autocomplete update ───────────────────────────────────────────────────────

local function updateAutocomplete()
        local text   = inputBox.Text
        local tokens = CommandRegistry.parseArgs(text)
        local query  = tokens[1] or ""

        local hasSpace = text:find("%s")
        if hasSpace then
                local chosen = CommandRegistry.COMMANDS[query:lower()]
                if chosen then
                        acMatches = { { name = query:lower(), entry = chosen } }
                        acIndex   = 1
                else
                        acMatches = {}
                end
                clearDropdown()
                dropdown.Visible = false

                if chosen and #chosen.args > 0 then
                        -- Build the hint line
                        local parts = {}
                        for _, arg in chosen.args do
                                local isOptional = arg:sub(-1) == "?"
                                local label = isOptional and arg:sub(1, -2) or arg
                                local color = isOptional and "#806010" or "#a09050"
                                local wrap  = isOptional and "[" or "<"
                                local wrapE = isOptional and "]" or ">"
                                table.insert(parts, '<font color="' .. color .. '">' .. wrap .. label .. wrapE .. "</font>")
                        end
                        hintLabel.Text    = '<font color="#FFD700">' .. query:lower() .. "</font>  " .. table.concat(parts, "  ")
                        hintFrame.Visible = true

                        -- Determine which arg slot the user is currently filling
                        -- tokens[1] = command, tokens[2..] = args typed so far
                        local hasTrailingSpace = text:sub(-1) == " "
                        -- argPos: 1-based index into chosen.args
                        local argPos = hasTrailingSpace and (#tokens - 1 + 1) or (#tokens - 1)
                        argPos = math.max(1, argPos)

                        local currentFilter = hasTrailingSpace and "" or (tokens[#tokens] or "")

                        -- Show player suggestions only when the current arg expects a player
                        local argLabel = chosen.args[argPos] or ""
                        if isPlayerArg(argLabel) then
                                refreshPlayerSuggestions(currentFilter)
                        else
                                hidePlayerSuggestions()
                        end
                else
                        hintFrame.Visible = false
                        hidePlayerSuggestions()
                end
                return
        end

        -- Command name still being typed — hide player suggestions
        hidePlayerSuggestions()

        if query == "" then
                acMatches = {}
                refreshDropdown()
                return
        end

        acMatches = CommandRegistry.getMatches(query)
        acIndex   = 1
        refreshDropdown()
end

-- ─── Open / Close ─────────────────────────────────────────────────────────────

local openTInfo  = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local closeTInfo = TweenInfo.new(CFG.ANIM_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local function openBar()
        if isOpen then return end
        isOpen = true
        historyIndex = 0
        savedDraft   = ""

        panel.Visible   = true
        blocker.Visible = true

        panel.Position              = UDim2.new(0.5, 0, 0, CFG.BAR_Y_CLOSED)
        panel.BackgroundTransparency = 1

        TweenService:Create(panel, openTInfo, {
                Position             = UDim2.new(0.5, 0, 0, CFG.BAR_Y_OPEN),
                BackgroundTransparency = CFG.BG_TRANS_OPEN,
        }):Play()

        tw(panelStroke, CFG.ANIM_TIME, { Transparency = 0.1 })
        tw(accentLine,  CFG.ANIM_TIME, { BackgroundTransparency = 0.2 })
        tw(promptLabel, CFG.ANIM_TIME, { TextTransparency = 0 })
        tw(inputBox,    CFG.ANIM_TIME, { TextTransparency = 0 })

        task.delay(CFG.ANIM_TIME * 0.5, function()
                if isOpen then inputBox:CaptureFocus() end
        end)
end

local function closeBar()
        if not isOpen then return end
        isOpen = false
        historyIndex = 0

        dropdown.Visible          = false
        hintFrame.Visible         = false
        blocker.Visible           = false
        playerSuggestPanel.Visible = false

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
                        panel.Visible = false
                        inputBox.Text = ""
                        acMatches     = {}
                end
        end)

        inputBox:ReleaseFocus()
end

-- ─── Command execution ─────────────────────────────────────────────────────────

local function executeCommand()
        local raw = inputBox.Text:match("^%s*(.-)%s*$")
        if raw == "" then
                closeBar()
                return
        end

        local tokens  = CommandRegistry.parseArgs(raw)
        local cmdName = tokens[1] and tokens[1]:lower() or ""
        local args    = {}
        for i = 2, #tokens do
                table.insert(args, tokens[i])
        end

        if history[1] ~= raw then
                table.insert(history, 1, raw)
                if #history > CFG.HISTORY_MAX then
                        table.remove(history, #history)
                end
        end

        CommandRemotes.CommandExecuted:FireServer(cmdName, args)

        -- Show right-side notification (UI-only animation)
        showNotification("Command Executed")

        closeBar()
end

-- ─── Feedback toasts ───────────────────────────────────────────────────────────

local toastGui = Instance.new("ScreenGui")
toastGui.Name           = "CmdToasts"
toastGui.DisplayOrder   = 55
toastGui.ResetOnSpawn   = false
toastGui.IgnoreGuiInset = true
toastGui.Parent         = PlayerGui

local toastHolder = Instance.new("Frame")
toastHolder.Name                  = "ToastHolder"
toastHolder.AnchorPoint           = Vector2.new(1, 1)
toastHolder.Size                  = UDim2.new(0, 320, 1, -20)
toastHolder.Position              = UDim2.new(1, -16, 1, -16)
toastHolder.BackgroundTransparency = 1
toastHolder.BorderSizePixel       = 0
toastHolder.Parent                = toastGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection       = Enum.FillDirection.Vertical
toastLayout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder           = Enum.SortOrder.LayoutOrder
toastLayout.Padding             = UDim.new(0, 6)
toastLayout.Parent              = toastHolder

local toastCounter = 0

local function showToast(success: boolean, message: string)
        toastCounter += 1

        local toast = Instance.new("Frame")
        toast.Name                  = "Toast" .. toastCounter
        toast.LayoutOrder           = -toastCounter
        toast.Size                  = UDim2.new(1, 0, 0, 44)
        toast.BackgroundColor3      = Color3.fromRGB(10, 10, 12)
        toast.BackgroundTransparency = 0.1
        toast.BorderSizePixel       = 0
        toast.ZIndex                = 30
        toast.Parent                = toastHolder

        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, 8)
        tc.Parent = toast

        local ts = Instance.new("UIStroke")
        ts.Color        = success and CFG.BG_BORDER or Color3.fromRGB(180, 50, 50)
        ts.Thickness    = 1
        ts.Transparency = 0.3
        ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        ts.Parent = toast

        -- Left accent bar
        local tAccent = Instance.new("Frame")
        tAccent.Size                  = UDim2.new(0, 3, 1, -10)
        tAccent.Position              = UDim2.new(0, 5, 0, 5)
        tAccent.BackgroundColor3      = success and CFG.PROMPT_COLOR or Color3.fromRGB(220, 60, 60)
        tAccent.BackgroundTransparency = 1
        tAccent.BorderSizePixel       = 0
        tAccent.ZIndex                = 31
        tAccent.Parent                = toast
        Instance.new("UICorner", tAccent).CornerRadius = UDim.new(0, 2)

        local icon = Instance.new("TextLabel")
        icon.Size                  = UDim2.new(0, 32, 1, 0)
        icon.Position              = UDim2.new(0, 14, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Font                  = Enum.Font.GothamBold
        icon.TextSize              = 16
        icon.TextColor3            = success and CFG.PROMPT_COLOR or Color3.fromRGB(220, 80, 80)
        icon.TextTransparency      = 1
        icon.Text                  = success and "✓" or "✕"
        icon.TextXAlignment        = Enum.TextXAlignment.Center
        icon.TextYAlignment        = Enum.TextYAlignment.Center
        icon.ZIndex                = 31
        icon.Parent                = toast

        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, -52, 1, 0)
        lbl.Position              = UDim2.new(0, 48, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font                  = Enum.Font.Gotham
        lbl.TextSize              = 13
        lbl.TextColor3            = Color3.fromRGB(220, 220, 235)
        lbl.TextTransparency      = 1
        lbl.TextWrapped           = true
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.TextYAlignment        = Enum.TextYAlignment.Center
        lbl.Text                  = message
        lbl.ZIndex                = 31
        lbl.Parent                = toast

        task.spawn(function()
                tw(toast,   CFG.TOAST_FADE, { BackgroundTransparency = 0.1 })
                tw(tAccent, CFG.TOAST_FADE, { BackgroundTransparency = 0 })
                tw(icon,    CFG.TOAST_FADE, { TextTransparency = 0 })
                tw(lbl,     CFG.TOAST_FADE, { TextTransparency = 0 })
                task.wait(CFG.TOAST_DURATION)
                tw(toast,   CFG.TOAST_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                tw(tAccent, CFG.TOAST_FADE, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                tw(icon,    CFG.TOAST_FADE, { TextTransparency = 1 },       Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                tw(lbl,     CFG.TOAST_FADE, { TextTransparency = 1 },       Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                task.wait(CFG.TOAST_FADE)
                toast:Destroy()
        end)
end

CommandRemotes.CommandFeedback.OnClientEvent:Connect(function(success: boolean, message: string)
        showToast(success, message)
end)

-- ─── Input event handling ──────────────────────────────────────────────────────

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

blocker.MouseButton1Click:Connect(function()
        closeBar()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == CFG.OPEN_KEY and not gameProcessed then
                if isOpen then
                        closeBar()
                else
                        openBar()
                end
                return
        end

        if not isOpen then return end

        if input.KeyCode == Enum.KeyCode.Escape then
                closeBar()
                return
        end

        if not inputFocused then return end

        -- History navigation
        if input.KeyCode == Enum.KeyCode.Up then
                if historyIndex == 0 then savedDraft = inputBox.Text end
                historyIndex = math.min(historyIndex + 1, #history)
                if history[historyIndex] then
                        inputBox.Text = history[historyIndex]
                        task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                end
                return
        end

        if input.KeyCode == Enum.KeyCode.Down then
                if historyIndex > 0 then
                        historyIndex -= 1
                        inputBox.Text = historyIndex == 0 and savedDraft or history[historyIndex]
                        task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                end
                return
        end

        -- Tab: complete player name if panel visible, otherwise complete command name
        if input.KeyCode == Enum.KeyCode.Tab then
                if playerSuggestPanel.Visible and #filteredPlayers > 0 then
                        -- Complete with the highlighted player name
                        local chosen = filteredPlayers[playerSuggestIndex] or filteredPlayers[1]
                        if chosen then
                                -- Strip the "(me)" suffix if present
                                local name = chosen:gsub(" %(me%)$", "")
                                local tokens = CommandRegistry.parseArgs(inputBox.Text)
                                -- Keep everything up to (but not including) the last arg token
                                local keepCount = math.max(1, #tokens - 1)
                                local base = table.concat(tokens, " ", 1, keepCount)
                                inputBox.Text = base .. " " .. name .. " "
                                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                        end
                elseif #acMatches > 0 then
                        local match = acMatches[acIndex] or acMatches[1]
                        if match then
                                inputBox.Text = match.name .. " "
                                task.defer(function() inputBox.CursorPosition = #inputBox.Text + 1 end)
                        end
                end
                return
        end

        -- Cycle dropdown Ctrl+N / Ctrl+P
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
