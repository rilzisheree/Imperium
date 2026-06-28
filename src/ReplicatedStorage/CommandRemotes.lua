--[[
        CommandRemotes.lua
        ModuleScript — ReplicatedStorage

        Central module for all RemoteEvents used by the staff command bar.
        Uses getOrCreate so the server never makes duplicate RemoteEvents
        when old ones already exist in the place file.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local CommandRemotes = {}

-- Always find-or-create: prevents duplicate instances if the place file
-- already contains a RemoteEvent with the same name from a previous version.
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

if RunService:IsServer() then
        -- Server: create (or reuse) every RemoteEvent so they replicate to clients.
        CommandRemotes.CommandExecuted  = getOrCreate("CmdExecuted")
        CommandRemotes.CommandFeedback  = getOrCreate("CmdFeedback")
        CommandRemotes.Blind            = getOrCreate("CmdBlind")
        CommandRemotes.SM               = getOrCreate("CmdSM")
        CommandRemotes.IM               = getOrCreate("CmdIM")
        CommandRemotes.PM               = getOrCreate("CmdPM")
        CommandRemotes.Notif            = getOrCreate("CmdNotif")
        CommandRemotes.Countdown        = getOrCreate("CmdCountdown")
        CommandRemotes.ESP              = getOrCreate("CmdESP")
        CommandRemotes.Fly              = getOrCreate("CmdFly")
        CommandRemotes.Watch            = getOrCreate("CmdWatch")
        CommandRemotes.ChatLogs         = getOrCreate("CmdChatLogs")
        CommandRemotes.HelpUI           = getOrCreate("CmdHelpUI")
        CommandRemotes.HelpReceive      = getOrCreate("CmdHelpReceive")
        CommandRemotes.Music            = getOrCreate("CmdMusic")
        CommandRemotes.Waypoint         = getOrCreate("CmdWaypoint")
        CommandRemotes.HelpUIState      = getOrCreate("CmdHelpUIState")

        print("[CommandRemotes] All remotes ready on server.")
else
        -- Client: wait for server-created instances (never create them here).
        local function wait(name: string): RemoteEvent
                local result = ReplicatedStorage:WaitForChild(name, 15)
                if not result then
                        warn("[CommandRemotes] Timed out waiting for remote: " .. name)
                end
                return result :: RemoteEvent
        end

        CommandRemotes.CommandExecuted  = wait("CmdExecuted")
        CommandRemotes.CommandFeedback  = wait("CmdFeedback")
        CommandRemotes.Blind            = wait("CmdBlind")
        CommandRemotes.SM               = wait("CmdSM")
        CommandRemotes.IM               = wait("CmdIM")
        CommandRemotes.PM               = wait("CmdPM")
        CommandRemotes.Notif            = wait("CmdNotif")
        CommandRemotes.Countdown        = wait("CmdCountdown")
        CommandRemotes.ESP              = wait("CmdESP")
        CommandRemotes.Fly              = wait("CmdFly")
        CommandRemotes.Watch            = wait("CmdWatch")
        CommandRemotes.ChatLogs         = wait("CmdChatLogs")
        CommandRemotes.HelpUI           = wait("CmdHelpUI")
        CommandRemotes.HelpReceive      = wait("CmdHelpReceive")
        CommandRemotes.Music            = wait("CmdMusic")
        CommandRemotes.Waypoint         = wait("CmdWaypoint")
        CommandRemotes.HelpUIState      = wait("CmdHelpUIState")

        print("[CommandRemotes] All remotes found on client.")
end

return CommandRemotes
