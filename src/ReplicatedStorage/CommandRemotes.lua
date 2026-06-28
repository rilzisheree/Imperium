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
        local function create(name: string): RemoteEvent
                local event = Instance.new("RemoteEvent")
                event.Name   = name
                event.Parent = ReplicatedStorage
                return event
        end

        -- ── Core command pipe ───────────────────────────────────────────────────
        -- Client → Server: player submits a command
        CommandRemotes.CommandExecuted  = create("CmdExecuted")
        -- Server → Client: server sends result feedback (toast)
        CommandRemotes.CommandFeedback  = create("CmdFeedback")

        -- ── Visual effects (Server → Client) ────────────────────────────────────
        -- Blind: args (boolean isBlind)
        CommandRemotes.Blind            = create("CmdBlind")
        -- Server Message (narration): args (string message)
        CommandRemotes.SM               = create("CmdSM")
        -- Individual Message: args (string message)
        CommandRemotes.IM               = create("CmdIM")
        -- Private Message: args (string senderName, string message)
        CommandRemotes.PM               = create("CmdPM")
        -- Notification: args (string senderName, string message)
        CommandRemotes.Notif            = create("CmdNotif")
        -- Countdown: args (number seconds)
        CommandRemotes.Countdown        = create("CmdCountdown")
        -- ESP toggle: args (boolean enabled)
        CommandRemotes.ESP              = create("CmdESP")
        -- Fly toggle: args (boolean enabled)
        CommandRemotes.Fly              = create("CmdFly")
        -- Watch POV: args (string playerName or "" to stop)
        CommandRemotes.Watch            = create("CmdWatch")
        -- Chat logs: args (table logLines)
        CommandRemotes.ChatLogs         = create("CmdChatLogs")
        -- HelpUI state update: args (boolean enabled)
        CommandRemotes.HelpUI           = create("CmdHelpUI")
        -- Receive a help request: args (string senderName, string message)
        CommandRemotes.HelpReceive      = create("CmdHelpReceive")
        -- Music playback: args (number assetId, or 0 to stop)
        CommandRemotes.Music            = create("CmdMusic")
        -- Waypoint: args (string action "set"/"clear", number x, number y, number z, string label)
        CommandRemotes.Waypoint         = create("CmdWaypoint")

        -- ── Client → Server ──────────────────────────────────────────────────────
        -- Client tells server their helpUI toggle state: args (boolean isOn)
        CommandRemotes.HelpUIState      = create("CmdHelpUIState")

else
        local function wait(name: string): RemoteEvent
                return ReplicatedStorage:WaitForChild(name) :: RemoteEvent
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
end

return CommandRemotes
