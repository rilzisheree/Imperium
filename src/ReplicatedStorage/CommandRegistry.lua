--[[
        CommandRegistry.lua
        ModuleScript — ReplicatedStorage

        Shared command definitions used by both the client (autocomplete)
        and the server (execution + permission checks).

        To add a command:
          1. Add an entry to COMMANDS below.
          2. Add the handler function in CommandServer.server.lua.

        Permission tiers (checked server-side):
          "Helper"     — lowest staff rank
          "Moderator"  — mid-level staff
          "Admin"      — senior staff
          "Owner"      — full access
--]]

local CommandRegistry = {}

--[[
        COMMANDS table — each key is the canonical command name.

        Fields:
          description  (string)   — shown in the autocomplete dropdown
          args         (table)    — ordered list of arg labels for the hint line
          permission   (string)   — minimum rank required
          aliases      (table)    — optional alternative names
--]]
CommandRegistry.COMMANDS = {

        -- ── Blind ────────────────────────────────────────────────────────────────
        blind = {
                description = "Blind a player with a black screen overlay",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        unblind = {
                description = "Remove the blind effect from a player",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        blindAll = {
                description = "Blind every player in the server",
                args        = {},
                permission  = "Admin",
                aliases     = {},
        },

        unblindAll = {
                description = "Unblind every player in the server",
                args        = {},
                permission  = "Admin",
                aliases     = {},
        },

        -- ── Player Management ─────────────────────────────────────────────────────
        bring = {
                description = "Bring a player to your location",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        kick = {
                description = "Kick a player from the server",
                args        = { "player", "reason?" },
                permission  = "Moderator",
                aliases     = {},
        },

        damage = {
                description = "Deal damage to a player",
                args        = { "player", "amount" },
                permission  = "Moderator",
                aliases     = {},
        },

        heal = {
                description = "Restore a player's health to full",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        respawn = {
                description = "Respawn a player at world spawn",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        re = {
                description = "Refresh a player and return them to their position",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        ragdoll = {
                description = "Ragdoll a player in place",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        createcorpse = {
                description = "Create a frozen corpse at a player's position",
                args        = { "player" },
                permission  = "Admin",
                aliases     = {},
        },

        -- ── Hats & Accessories ────────────────────────────────────────────────────
        clearhats = {
                description = "Remove all accessories/hats from a player",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        hat = {
                description = "Give a player a hat by catalog asset ID",
                args        = { "player", "assetId" },
                permission  = "Admin",
                aliases     = {},
        },

        removehat = {
                description = "Remove a specific hat from a player by name",
                args        = { "player", "hatName" },
                permission  = "Moderator",
                aliases     = {},
        },

        -- ── Items ─────────────────────────────────────────────────────────────────
        giveitem = {
                description = "Permanently give a player a tool from ServerStorage",
                args        = { "player", "itemName" },
                permission  = "Admin",
                aliases     = {},
        },

        tempitem = {
                description = "Temporarily give a player a tool (removed after duration)",
                args        = { "player", "itemName", "duration?" },
                permission  = "Admin",
                aliases     = {},
        },

        removeitem = {
                description = "Remove all tools from a player's backpack",
                args        = { "player" },
                permission  = "Admin",
                aliases     = {},
        },

        -- ── Teleportation ─────────────────────────────────────────────────────────
        tp = {
                description = "Teleport player 1 to player 2",
                args        = { "from", "to" },
                permission  = "Moderator",
                aliases     = { "teleport" },
        },

        to = {
                description = "Teleport yourself to a player",
                args        = { "player" },
                permission  = "Moderator",
                aliases     = {},
        },

        place = {
                description = "Teleport a player to a different place ID",
                args        = { "player", "placeId" },
                permission  = "Admin",
                aliases     = {},
        },

        serverbring = {
                description = "Pull a player from another server into yours",
                args        = { "player" },
                permission  = "Admin",
                aliases     = {},
        },

        serverjoin = {
                description = "Join the server that a player is currently in",
                args        = { "player" },
                permission  = "Admin",
                aliases     = {},
        },

        privateserver = {
                description = "Reserve a private server instance and teleport there",
                args        = {},
                permission  = "Owner",
                aliases     = {},
        },

        -- ── Waypoints ─────────────────────────────────────────────────────────────
        setwaypoint = {
                description = "Place a world waypoint visible to all players",
                args        = { "label?" },
                permission  = "Moderator",
                aliases     = {},
        },

        clearwaypoints = {
                description = "Clear all active waypoints for everyone",
                args        = {},
                permission  = "Moderator",
                aliases     = {},
        },

        -- ── Server & World ────────────────────────────────────────────────────────
        setworldspawn = {
                description = "Set the world spawn to your current position",
                args        = {},
                permission  = "Admin",
                aliases     = {},
        },

        shutdown = {
                description = "Shut down the server after an optional delay",
                args        = { "delay?" },
                permission  = "Owner",
                aliases     = {},
        },

        -- ── Visibility ────────────────────────────────────────────────────────────
        invis = {
                description = "Make yourself invisible",
                args        = {},
                permission  = "Admin",
                aliases     = {},
        },

        uninvis = {
                description = "Make yourself visible again",
                args        = {},
                permission  = "Admin",
                aliases     = {},
        },

        -- ── Narration & Messaging ─────────────────────────────────────────────────
        sm = {
                description = "Server message for narration — bottom screen, all players",
                args        = { "message" },
                permission  = "Moderator",
                aliases     = {},
        },

        im = {
                description = "Individual message — bottom screen, one player",
                args        = { "player", "message" },
                permission  = "Moderator",
                aliases     = {},
        },

        pm = {
                description = "Private message — fades in/out on the target's middle screen",
                args        = { "player", "message" },
                permission  = "Moderator",
                aliases     = {},
        },

        notif = {
                description = "Notification PM — shows your name at the bottom of their screen",
                args        = { "player", "message" },
                permission  = "Moderator",
                aliases     = {},
        },

        -- ── Countdown ─────────────────────────────────────────────────────────────
        countdown = {
                description = "Show a countdown on the left side of the screen for everyone",
                args        = { "seconds" },
                permission  = "Moderator",
                aliases     = {},
        },

        -- ── Music ─────────────────────────────────────────────────────────────────
        music = {
                description = "Play a music asset ID server-wide (0 to stop)",
                args        = { "assetId" },
                permission  = "Moderator",
                aliases     = {},
        },

        -- ── Staff Tools ───────────────────────────────────────────────────────────
        esp = {
                description = "Toggle ESP overlay — names, username, health, distance",
                args        = {},
                permission  = "Helper",
                aliases     = {},
        },

        fly = {
                description = "Toggle flight for a player (E to fly, Alt to speed up)",
                args        = { "player" },
                permission  = "Admin",
                aliases     = {},
        },

        watch = {
                description = "Watch another player's point of view",
                args        = { "player" },
                permission  = "Helper",
                aliases     = {},
        },

        chatlogs = {
                description = "Open the recent chat log panel",
                args        = {},
                permission  = "Helper",
                aliases     = {},
        },

        help = {
                description = "Send a help request to all staff with helpUI enabled",
                args        = { "message" },
                permission  = "Helper",
                aliases     = {},
        },

        helpUI = {
                description = "Toggle the help request UI panel (required to receive help calls)",
                args        = {},
                permission  = "Helper",
                aliases     = {},
        },
}

--[[
        CommandRegistry.getMatches(query)
        Returns an ordered table of { name, entry } for all commands whose name or
        alias starts with `query` (case-insensitive). Sorted alphabetically.
--]]
function CommandRegistry.getMatches(query: string): { { name: string, entry: table } }
        query = query:lower()
        local results = {}

        for name, entry in CommandRegistry.COMMANDS do
                local matched = name:lower():sub(1, #query) == query
                if not matched then
                        for _, alias in entry.aliases or {} do
                                if alias:lower():sub(1, #query) == query then
                                        matched = true
                                        break
                                end
                        end
                end
                if matched then
                        table.insert(results, { name = name, entry = entry })
                end
        end

        table.sort(results, function(a, b) return a.name < b.name end)
        return results
end

--[[
        CommandRegistry.parseArgs(input)
        Splits an argument string on whitespace, respecting "quoted strings".
        Returns an ordered table of strings.
--]]
function CommandRegistry.parseArgs(input: string): { string }
        local args = {}
        local i    = 1
        local len  = #input

        while i <= len do
                while i <= len and input:sub(i, i):match("%s") do
                        i += 1
                end
                if i > len then break end

                if input:sub(i, i) == '"' then
                        i += 1
                        local start = i
                        while i <= len and input:sub(i, i) ~= '"' do
                                i += 1
                        end
                        table.insert(args, input:sub(start, i - 1))
                        i += 1
                else
                        local start = i
                        while i <= len and not input:sub(i, i):match("%s") do
                                i += 1
                        end
                        table.insert(args, input:sub(start, i - 1))
                end
        end

        return args
end

return CommandRegistry
