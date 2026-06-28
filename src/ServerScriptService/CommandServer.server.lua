--[[
        CommandServer.server.lua
        Script — ServerScriptService
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()

local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes")  :: ModuleScript)
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry") :: ModuleScript)

-- ─── Staff configuration ───────────────────────────────────────────────────────

local STAFF_IDS = {
        [1872507151] = "Owner",
}

local TIER_ORDER = { Helper = 1, Moderator = 2, Admin = 3, Owner = 4 }

local function getTier(player: Player): string?
        if IS_STUDIO then return "Owner" end
        if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
                return "Owner"
        end
        return STAFF_IDS[player.UserId]
end

local function hasPermission(player: Player, required: string): boolean
        local tier = getTier(player)
        if not tier then return false end
        return (TIER_ORDER[tier] or 0) >= (TIER_ORDER[required] or 99)
end

-- ─── Feedback helpers ──────────────────────────────────────────────────────────

local function ok(player: Player, msg: string)
        CommandRemotes.CommandFeedback:FireClient(player, true, msg)
end

local function fail(player: Player, msg: string)
        CommandRemotes.CommandFeedback:FireClient(player, false, msg)
end

-- ─── Player resolution ─────────────────────────────────────────────────────────

local function resolvePlayer(executor: Player, name: string): Player?
        if name:lower() == "me" then return executor end
        local lower = name:lower()
        for _, p in Players:GetPlayers() do
                if p.Name:lower() == lower or p.DisplayName:lower() == lower then
                        return p
                end
        end
        for _, p in Players:GetPlayers() do
                if p.Name:lower():sub(1, #lower) == lower then return p end
        end
        return nil
end

local function joinArgs(args: { string }, from: number): string
        local parts = {}
        for i = from, #args do table.insert(parts, args[i]) end
        return table.concat(parts, " ")
end

-- ─── Handlers ─────────────────────────────────────────────────────────────────

local HANDLERS = {}

-- sm <message>
HANDLERS["sm"] = function(executor, args)
        local msg = joinArgs(args, 1)
        if msg == "" then
                fail(executor, "Usage: sm <message>")
                return
        end
        for _, player in Players:GetPlayers() do
                CommandRemotes.SM:FireClient(player, msg)
        end
        ok(executor, 'Server message sent: "' .. msg .. '"')
end

-- im <player> <message>
HANDLERS["im"] = function(executor, args)
        if #args < 2 then
                fail(executor, "Usage: im <player> <message>")
                return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then
                fail(executor, 'Player "' .. args[1] .. '" not found.')
                return
        end
        local msg = joinArgs(args, 2)
        if msg == "" then
                fail(executor, "Usage: im <player> <message>")
                return
        end
        CommandRemotes.IM:FireClient(target, msg)
        ok(executor, 'Individual message sent to ' .. target.DisplayName .. ': "' .. msg .. '"')
end

-- ─── Incoming remote handler ───────────────────────────────────────────────────

CommandRemotes.CommandExecuted.OnServerEvent:Connect(function(executor: Player, cmdName: string, args: { string })
        print(("[CommandServer] Received from %s: cmd=%s"):format(executor.Name, tostring(cmdName)))

        if typeof(cmdName) ~= "string" then return end
        if typeof(args) ~= "table" then args = {} end

        cmdName = cmdName:lower():match("^%s*(.-)%s*$") or ""
        if cmdName == "" then return end

        local safeArgs = {}
        for _, v in args do
                if typeof(v) == "string" then table.insert(safeArgs, v) end
        end

        local definition = CommandRegistry.COMMANDS[cmdName]
        if not definition then
                fail(executor, 'Unknown command: "' .. cmdName .. '".')
                return
        end

        if not hasPermission(executor, definition.permission) then
                fail(executor, 'No permission for "' .. cmdName .. '" (requires ' .. definition.permission .. ').')
                return
        end

        local handler = HANDLERS[cmdName]
        if not handler then
                fail(executor, '"' .. cmdName .. '" has no handler.')
                return
        end

        local success, err = pcall(handler, executor, safeArgs)
        if not success then
                fail(executor, "Error: " .. tostring(err))
                warn("[CommandServer] ERROR in '" .. cmdName .. "': " .. tostring(err))
        end
end)

print("[CommandServer] Active — sm and im commands ready.")
