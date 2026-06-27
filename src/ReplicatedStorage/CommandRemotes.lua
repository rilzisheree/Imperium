--[[
	CommandRemotes.lua
	ModuleScript — ReplicatedStorage

	Central module for all RemoteEvents used by the staff command bar.
	Both client and server require this to share the same instances.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommandRemotes = {}

local function getOrCreate(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name   = name
	event.Parent = ReplicatedStorage
	return event
end

-- Client → Server: player submits a command
-- Args: commandName (string), args (table of strings)
CommandRemotes.CommandExecuted = getOrCreate("CmdExecuted")

-- Server → Client: server sends result feedback
-- Args: success (boolean), message (string)
CommandRemotes.CommandFeedback = getOrCreate("CmdFeedback")

return CommandRemotes
