--[[
	CommandRemotes.lua
	ModuleScript — ReplicatedStorage

	Central module for all RemoteEvents used by the staff command bar.
	Both client and server require this to share the same instances.

	FIX: RemoteEvents must be created server-side only. The client now uses
	WaitForChild so it always finds the server-created instance instead of
	accidentally creating a local duplicate that the server never sees.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local CommandRemotes = {}

if RunService:IsServer() then
	-- Server: create the RemoteEvents so they replicate to all clients.
	local function create(name: string): RemoteEvent
		local event = Instance.new("RemoteEvent")
		event.Name   = name
		event.Parent = ReplicatedStorage
		return event
	end

	-- Client → Server: player submits a command
	-- Args: commandName (string), args (table of strings)
	CommandRemotes.CommandExecuted = create("CmdExecuted")

	-- Server → Client: server sends result feedback
	-- Args: success (boolean), message (string)
	CommandRemotes.CommandFeedback = create("CmdFeedback")
else
	-- Client: wait for the server-created instances (never create them here).
	CommandRemotes.CommandExecuted = ReplicatedStorage:WaitForChild("CmdExecuted")  :: RemoteEvent
	CommandRemotes.CommandFeedback = ReplicatedStorage:WaitForChild("CmdFeedback")  :: RemoteEvent
end

return CommandRemotes
