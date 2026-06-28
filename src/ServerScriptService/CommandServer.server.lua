--[[
        CommandServer.server.lua
        Script — ServerScriptService

        Receives command executions from the client command bar, validates
        permissions, and dispatches to the appropriate handler.

        Does NOT use Roblox's default chat, TextChatService, or Player.Chatted.

        ─── Adding commands ──────────────────────────────────────────────────────────
        1. Add the command definition to CommandRegistry.lua (ReplicatedStorage)
        2. Add a handler function in the HANDLERS table below
        3. Set the appropriate permission level on the definition

        ─── Permission setup ─────────────────────────────────────────────────────────
        Edit STAFF_CONFIG below.  You can whitelist by UserId, or by Roblox group
        rank.  The tier hierarchy is: Helper < Moderator < Admin < Owner.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- FIX (TypeError 1012): Cast WaitForChild to ModuleScript so Luau's type-checker
-- can resolve each require and know the module's exported type.
local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes")  :: ModuleScript)
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry") :: ModuleScript)
-- FIX (TypeError 1012 line 255): Moved ChatRemotes to the top-level require instead
-- of being lazily required inside the announce handler, which also silences the
-- unknown-require error and avoids re-requiring every time announce is called.
local ChatRemotes     = require(ReplicatedStorage:WaitForChild("ChatRemotes")     :: ModuleScript)

-- ─── Staff configuration ───────────────────────────────────────────────────────
--
-- Tier order (lowest → highest): Helper, Moderator, Admin, Owner
--
-- STAFF_IDS: map of UserId → tier string
-- STAFF_GROUP: optional Roblox group-rank gating (set GROUP_ID to 0 to disable)
-- OWNER_IDS: always granted Owner tier regardless of group

local STAFF_CONFIG = {
        -- Direct UserId → tier overrides (add your own UserId here for testing)
        STAFF_IDS = {
                [1872507151] = "Owner",
                -- [987654321] = "Admin",
        },

        -- Roblox group-based permissions (set GROUP_ID = 0 to disable)
        GROUP_ID = 0,
        GROUP_RANKS = {
                -- Minimum group rank needed for each tier
                -- These values depend on your group's rank configuration
                -- [254] = "Owner",
                -- [200] = "Admin",
                -- [100] = "Moderator",
                -- [50]  = "Helper",
        },
}

local TIER_ORDER = { Helper = 1, Moderator = 2, Admin = 3, Owner = 4 }

local function getTier(player: Player): string?
        -- Check direct UserId override first
        local directTier = STAFF_CONFIG.STAFF_IDS[player.UserId]
        if directTier then return directTier end

        -- Check group ranks
        if STAFF_CONFIG.GROUP_ID > 0 then
                -- FIX (DeprecatedApi): GetRankInGroup is deprecated; use GroupService:GetGroupsAsync
                -- to retrieve the player's rank without relying on the deprecated Player method.
                local GroupService = game:GetService("GroupService")
                local success, groups = pcall(function()
                        return GroupService:GetGroupsAsync(player.UserId)
                end)
                if success and groups then
                        local rank = 0
                        for _, groupInfo in groups do
                                if groupInfo.Id == STAFF_CONFIG.GROUP_ID then
                                        rank = groupInfo.Rank
                                        break
                                end
                        end
                        if rank > 0 then
                                local bestTier = nil
                                local bestRank = 0
                                for minRank, tier in STAFF_CONFIG.GROUP_RANKS do
                                        if rank >= minRank and minRank > bestRank then
                                                bestRank = minRank
                                                bestTier = tier
                                        end
                                end
                                if bestTier then return bestTier end
                        end
                end
        end

        return nil  -- not staff
end

local function hasPermission(player: Player, required: string): boolean
        local tier = getTier(player)
        if not tier then return false end
        return (TIER_ORDER[tier] or 0) >= (TIER_ORDER[required] or 99)
end

-- ─── Player resolution helper ──────────────────────────────────────────────────
-- Matches partial player name case-insensitively.  "me" resolves to the executor.

local function resolvePlayer(executor: Player, name: string): Player?
        if name:lower() == "me" then return executor end
        local lower = name:lower()
        for _, p in Players:GetPlayers() do
                if p.Name:lower() == lower or p.DisplayName:lower() == lower then
                        return p
                end
        end
        -- Partial match fallback
        for _, p in Players:GetPlayers() do
                if p.Name:lower():sub(1, #lower) == lower then
                        return p
                end
        end
        return nil
end

-- ─── Feedback helpers ──────────────────────────────────────────────────────────

local function ok(player: Player, msg: string)
        CommandRemotes.CommandFeedback:FireClient(player, true, msg)
end

local function fail(player: Player, msg: string)
        CommandRemotes.CommandFeedback:FireClient(player, false, msg)
end

-- ─── Muted players (in-memory; extend to DataStore if you need persistence) ───

local mutedPlayers: { [number]: boolean } = {}
local frozenPlayers: { [number]: boolean } = {}

-- Enforce mute on the chat server by checking this table.
-- ChatServer.server.lua should call CommandServer.isMuted(player) before broadcasting.
-- We expose it on a shared module if needed; for now it's enforced here on message receipt.
-- (Wire up in ChatServer.server.lua: require this module and check _G.CmdMuted)
_G.CmdMuted   = mutedPlayers
_G.CmdFrozen  = frozenPlayers

-- ─── Command handlers ──────────────────────────────────────────────────────────
--
-- Each handler receives:
--   executor  (Player)          — the staff member who ran the command
--   args      (table of strings) — ordered arguments from the command bar
--
-- FIX (ImplicitReturn): All early exits now use the pattern `fail(...) return`
-- instead of `return fail(...)`.  The latter leaves an implicit nil-return path
-- visible to the type-checker; the former adds an explicit bare `return` so
-- every branch is clearly accounted for.

local HANDLERS: { [string]: (executor: Player, args: { string }) -> () } = {}

-- kick <player> [reason]
HANDLERS["kick"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: kick <player> [reason]") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end
        if target == executor then fail(executor, "You cannot kick yourself.") return end

        local reason = args[2] or "Removed by staff."
        target:Kick("You were kicked: " .. reason)
        ok(executor, target.DisplayName .. " has been kicked. (" .. reason .. ")")
end

-- ban <player> [reason]
HANDLERS["ban"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: ban <player> [reason]") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end
        if target == executor then fail(executor, "You cannot ban yourself.") return end

        local reason = args[2] or "Banned by staff."
        -- TODO: persist ban to DataStore here
        target:Kick("You have been banned: " .. reason)
        ok(executor, target.DisplayName .. " has been banned. (" .. reason .. ")")
        warn("[CommandServer] BAN: " .. executor.Name .. " banned " .. target.Name .. " — " .. reason)
end

-- unban <username>
HANDLERS["unban"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: unban <username>") return end
        -- TODO: remove from ban DataStore
        ok(executor, '"' .. args[1] .. '" unbanned. (Implement DataStore persistence.)')
end

-- mute <player> [duration]
HANDLERS["mute"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: mute <player> [duration]") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        mutedPlayers[target.UserId] = true
        ok(executor, target.DisplayName .. " has been muted.")

        local duration = tonumber(args[2])
        if duration then
                task.delay(duration, function()
                        mutedPlayers[target.UserId] = nil
                end)
        end
end

-- unmute <player>
HANDLERS["unmute"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: unmute <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        mutedPlayers[target.UserId] = nil
        ok(executor, target.DisplayName .. " has been unmuted.")
end

-- warn <player> <reason>
HANDLERS["warn"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: warn <player> <reason>")
                return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local reason = args[2]
        -- Notify the warned player via system message
        CommandRemotes.CommandFeedback:FireClient(target, false,
                "⚠ Warning from staff: " .. reason)
        ok(executor, "Warning issued to " .. target.DisplayName .. ": " .. reason)
        warn("[CommandServer] WARN: " .. executor.Name .. " warned " .. target.Name .. " — " .. reason)
end

-- tp <from> <to>
HANDLERS["tp"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: tp <from> <to>")
                return
        end
        local from = resolvePlayer(executor, args[1])
        local to   = resolvePlayer(executor, args[2])
        if not from then fail(executor, 'No player found: "' .. args[1] .. '"') return end
        if not to   then fail(executor, 'No player found: "' .. args[2] .. '"') return end

        local toChar = to.Character
        local hrp    = toChar and toChar:FindFirstChild("HumanoidRootPart")
        if not hrp then fail(executor, to.DisplayName .. " has no character loaded.") return end

        local fromChar = from.Character
        local fromHrp  = fromChar and fromChar:FindFirstChild("HumanoidRootPart")
        if not fromHrp then fail(executor, from.DisplayName .. " has no character loaded.") return end

        fromHrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
        ok(executor, from.DisplayName .. " → " .. to.DisplayName)
end
HANDLERS["teleport"] = HANDLERS["tp"]

-- tpme <player>
HANDLERS["tpme"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: tpme <player>") return end
        HANDLERS["tp"](executor, { "me", args[1] })
end

-- bring <player>
HANDLERS["bring"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: bring <player>") return end
        HANDLERS["tp"](executor, { args[1], "me" })
end

-- announce <message>
-- FIX: ChatRemotes is now a top-level require; no lazy require needed here.
HANDLERS["announce"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: announce <message>") return end
        local message = table.concat(args, " ")

        for _, player in Players:GetPlayers() do
                ChatRemotes.SystemMessage:FireClient(player, {
                        message = "📢 " .. message,
                        sender  = executor.DisplayName,
                })
                -- Also show as a feedback toast to everyone
                CommandRemotes.CommandFeedback:FireClient(player, true,
                        "[Announcement] " .. message)
        end
        ok(executor, "Announcement sent.")
end
HANDLERS["ann"] = HANDLERS["announce"]

-- speed <player> <value>
HANDLERS["speed"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: speed <player> <value>")
                return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local value = tonumber(args[2])
        if not value then fail(executor, "Speed must be a number.") return end
        value = math.clamp(value, 0, 500)

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        hum.WalkSpeed = value
        ok(executor, target.DisplayName .. "'s walk speed set to " .. value .. ".")
end

-- heal <player>
HANDLERS["heal"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: heal <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        hum.Health = hum.MaxHealth
        ok(executor, target.DisplayName .. " healed to full health.")
end

-- respawn <player>
HANDLERS["respawn"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: respawn <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        target:LoadCharacter()
        ok(executor, target.DisplayName .. " has been respawned.")
end

-- god <player>
HANDLERS["god"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: god <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        if hum.MaxHealth == math.huge then
                hum.MaxHealth = 100
                hum.Health    = 100
                ok(executor, target.DisplayName .. " — invincibility removed.")
        else
                hum.MaxHealth = math.huge
                hum.Health    = math.huge
                ok(executor, target.DisplayName .. " — invincibility enabled.")
        end
end

-- freeze <player>
HANDLERS["freeze"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: freeze <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        frozenPlayers[target.UserId] = true
        hum.WalkSpeed  = 0
        hum.JumpHeight = 0
        ok(executor, target.DisplayName .. " has been frozen.")
end

-- unfreeze <player>
HANDLERS["unfreeze"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: unfreeze <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        frozenPlayers[target.UserId] = nil
        hum.WalkSpeed  = 16
        hum.JumpHeight = 7.2
        ok(executor, target.DisplayName .. " has been unfrozen.")
end

-- shutdown [delay]
HANDLERS["shutdown"] = function(executor, args)
        local delayTime = tonumber(args[1]) or 5

        for _, player in Players:GetPlayers() do
                CommandRemotes.CommandFeedback:FireClient(player, false,
                        "Server shutting down in " .. delayTime .. " seconds…")
        end

        task.delay(delayTime, function()
                for _, player in Players:GetPlayers() do
                        player:Kick("Server shutdown.")
                end
        end)

        ok(executor, "Shutdown initiated — " .. delayTime .. "s delay.")
        warn("[CommandServer] SHUTDOWN triggered by " .. executor.Name)
end

-- players / list
HANDLERS["players"] = function(executor, _args)
        local list = {}
        for _, p in Players:GetPlayers() do
                table.insert(list, p.DisplayName .. " (" .. p.Name .. ")")
        end
        ok(executor, #list .. " online: " .. table.concat(list, ", "))
end
HANDLERS["list"] = HANDLERS["players"]

-- logs [lines]
HANDLERS["logs"] = function(executor, _args)
        ok(executor, "Log retrieval: connect to a DataStore-backed log system here.")
end

-- whoami  (debug: shows your UserId and tier)
HANDLERS["whoami"] = function(executor, _args)
        local tier = getTier(executor)
        ok(executor, "UserId: " .. executor.UserId .. " | Tier: " .. (tier or "none (not staff)"))
end

-- spectate <player>  (client-side only — server acknowledges)
HANDLERS["spectate"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: spectate <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end
        -- The actual camera switch is client-side; here we just confirm validity
        ok(executor, "Spectating " .. target.DisplayName .. ". (Implement camera switch client-side.)")
end

-- ─── Incoming remote handler ───────────────────────────────────────────────────

CommandRemotes.CommandExecuted.OnServerEvent:Connect(function(executor: Player, cmdName: string, args: { string })
        -- Basic type safety
        if typeof(cmdName) ~= "string" then return end
        if typeof(args) ~= "table" then args = {} end

        -- FIX (TypeError 1000): string:match() returns string?, not string.
        -- Adding `or ""` guarantees cmdName stays a string after the trim.
        cmdName = cmdName:lower():match("^%s*(.-)%s*$") or ""
        if cmdName == "" then return end

        -- Sanitize args
        local safeArgs = {}
        for _, v in args do
                if typeof(v) == "string" then
                        table.insert(safeArgs, v)
                end
        end

        -- Look up the command definition
        local definition = CommandRegistry.COMMANDS[cmdName]
        if not definition then
                fail(executor, 'Unknown command: "' .. cmdName .. '". Type a command name to see suggestions.')
                return
        end

        -- Check permission
        if not hasPermission(executor, definition.permission) then
                fail(executor, 'You do not have permission to use "' .. cmdName .. '" (requires ' .. definition.permission .. ').')
                warn("[CommandServer] DENIED: " .. executor.Name .. " tried to run '" .. cmdName .. "' without permission.")
                return
        end

        -- Dispatch
        local handler = HANDLERS[cmdName]
        if not handler then
                fail(executor, '"' .. cmdName .. '" is defined but has no server handler yet.')
                return
        end

        local success, err = pcall(handler, executor, safeArgs)
        if not success then
                fail(executor, "Command error: " .. tostring(err))
                warn("[CommandServer] ERROR in '" .. cmdName .. "': " .. tostring(err))
        end
end)

-- FIX (TableOperations): HANDLERS uses string keys, so `#HANDLERS` is always 0.
-- Count entries manually with a loop instead.
local handlerCount = 0
for _ in HANDLERS do handlerCount += 1 end
print("[CommandServer] Staff command system active. " .. handlerCount .. " commands registered.")
