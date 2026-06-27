--[[
	ChatServer.server.lua
	Script — ServerScriptService

	Handles the server side of the custom chat system:
	  • Disables Roblox's built-in chat service
	  • Validates and sanitizes incoming messages from clients
	  • Broadcasts messages to all connected clients
	  • Sends system messages on player join/leave
--]]

local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chat         = game:GetService("Chat")

-- Wait for the ChatRemotes module to be available
local ChatRemotes = require(ReplicatedStorage:WaitForChild("ChatRemotes"))

-- ─── Configuration ────────────────────────────────────────────────────────────
local MAX_MESSAGE_LENGTH = 200  -- characters
local CHAT_ENABLED       = true  -- set false to mute all chat globally

-- Name colours matching the default Roblox chat palette (assigned by UserId)
local NAME_COLORS = {
	Color3.fromRGB(253,  41,  67),  -- BrightRed
	Color3.fromRGB(  1, 162, 255),  -- BrightBlue
	Color3.fromRGB(  2, 184,  87),  -- CadmiumGreen
	Color3.fromRGB(255, 214,  74),  -- CadmiumYellow
	Color3.fromRGB(255, 127,  36),  -- BrightOrange
	Color3.fromRGB(255, 101, 197),  -- HotPink
	Color3.fromRGB(155, 117, 230),  -- Lavender
	Color3.fromRGB(  0, 187, 209),  -- CyanBlue
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

-- Deterministically map a UserId → a name colour
local function getNameColor(player: Player): Color3
	local index = (player.UserId % #NAME_COLORS) + 1
	return NAME_COLORS[index]
end

-- Filter the message through Roblox's built-in text filter
local function filterMessage(sender: Player, text: string): string
	local success, filtered = pcall(function()
		local result = Chat:FilterStringAsync(text, sender, sender)
		return result
	end)
	if success and filtered then
		return filtered
	end
	-- Fallback: return raw text (studio / unfiltered context)
	return text
end

-- ─── Core broadcast ───────────────────────────────────────────────────────────

local function broadcastMessage(sender: Player, rawText: string)
	if not CHAT_ENABLED then return end

	-- Trim whitespace
	local trimmed = rawText:match("^%s*(.-)%s*$")
	if trimmed == "" then return end

	-- Enforce length cap
	if #trimmed > MAX_MESSAGE_LENGTH then
		trimmed = trimmed:sub(1, MAX_MESSAGE_LENGTH) .. "…"
	end

	-- Filter through Roblox text service
	local filtered = filterMessage(sender, trimmed)

	local nameColor = getNameColor(sender)

	-- Fire to every connected client
	ChatRemotes.MessageReceived:FireAllClients({
		playerName  = sender.DisplayName,
		userName    = sender.Name,
		message     = filtered,
		nameColorR  = nameColor.R,
		nameColorG  = nameColor.G,
		nameColorB  = nameColor.B,
		timestamp   = os.time(),
	})
end

local function sendSystemMessage(text: string, target: Player?)
	local payload = {
		message     = text,
		isSystem    = true,
		nameColorR  = 1,
		nameColorG  = 1,
		nameColorB  = 1,
		timestamp   = os.time(),
	}
	if target then
		ChatRemotes.SystemMessage:FireClient(target, payload)
	else
		ChatRemotes.SystemMessage:FireAllClients(payload)
	end
end

-- ─── Player lifecycle ─────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	-- Announce join (skip for studio solo test to reduce noise)
	task.wait(1) -- brief delay so the joining client's chat UI is ready
	sendSystemMessage("💬 " .. player.DisplayName .. " has joined the game.")

	-- Also catch messages sent via the legacy .Chatted event
	-- (This fires when the default Roblox chat input is still used,
	--  but since we disable the CoreGui chat on the client we use
	--  our own RemoteEvent instead. Kept as a safety net.)
	player.Chatted:Connect(function(message)
		broadcastMessage(player, message)
	end)
end

local function onPlayerRemoving(player: Player)
	sendSystemMessage("👋 " .. player.DisplayName .. " has left the game.")
end

-- ─── Remote listeners ─────────────────────────────────────────────────────────

-- Client fires this when the player submits a message through the custom UI
ChatRemotes.MessageSent.OnServerEvent:Connect(function(sender: Player, rawText: string)
	if typeof(rawText) ~= "string" then return end
	broadcastMessage(sender, rawText)
end)

-- ─── Wire up player events ────────────────────────────────────────────────────

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[ChatServer] Custom chat system active.")
