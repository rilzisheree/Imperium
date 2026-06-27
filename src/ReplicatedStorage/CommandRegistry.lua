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

	-- ── Moderation ──────────────────────────────────────────────────────────────
	kick = {
		description = "Kick a player from the server",
		args        = { "player", "reason?" },
		permission  = "Moderator",
		aliases     = {},
	},

	ban = {
		description = "Permanently ban a player",
		args        = { "player", "reason?" },
		permission  = "Admin",
		aliases     = {},
	},

	unban = {
		description = "Unban a previously banned player",
		args        = { "username" },
		permission  = "Admin",
		aliases     = {},
	},

	mute = {
		description = "Mute a player's chat",
		args        = { "player", "duration?" },
		permission  = "Moderator",
		aliases     = {},
	},

	unmute = {
		description = "Remove a player's chat mute",
		args        = { "player" },
		permission  = "Moderator",
		aliases     = {},
	},

	warn = {
		description = "Issue a warning to a player",
		args        = { "player", "reason" },
		permission  = "Helper",
		aliases     = {},
	},

	-- ── Teleportation ───────────────────────────────────────────────────────────
	tp = {
		description = "Teleport a player to another player",
		args        = { "from", "to" },
		permission  = "Moderator",
		aliases     = { "teleport" },
	},

	tpme = {
		description = "Teleport yourself to a player",
		args        = { "player" },
		permission  = "Moderator",
		aliases     = {},
	},

	bring = {
		description = "Bring a player to your location",
		args        = { "player" },
		permission  = "Moderator",
		aliases     = {},
	},

	-- ── Utility ─────────────────────────────────────────────────────────────────
	announce = {
		description = "Send a server-wide announcement",
		args        = { "message" },
		permission  = "Admin",
		aliases     = { "ann" },
	},

	speed = {
		description = "Set a player's walk speed",
		args        = { "player", "value" },
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
		description = "Force respawn a player",
		args        = { "player" },
		permission  = "Moderator",
		aliases     = {},
	},

	spectate = {
		description = "Spectate a player's camera",
		args        = { "player" },
		permission  = "Helper",
		aliases     = {},
	},

	god = {
		description = "Toggle invincibility for a player",
		args        = { "player" },
		permission  = "Admin",
		aliases     = {},
	},

	freeze = {
		description = "Freeze a player in place",
		args        = { "player" },
		permission  = "Moderator",
		aliases     = {},
	},

	unfreeze = {
		description = "Unfreeze a player",
		args        = { "player" },
		permission  = "Moderator",
		aliases     = {},
	},

	-- ── Server ──────────────────────────────────────────────────────────────────
	shutdown = {
		description = "Gracefully shut down the server",
		args        = { "delay?" },
		permission  = "Owner",
		aliases     = {},
	},

	logs = {
		description = "Pull recent moderation logs",
		args        = { "lines?" },
		permission  = "Moderator",
		aliases     = {},
	},

	players = {
		description = "List all players currently in the server",
		args        = {},
		permission  = "Helper",
		aliases     = { "list" },
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
		local matched = name:sub(1, #query) == query
		if not matched then
			for _, alias in entry.aliases or {} do
				if alias:sub(1, #query) == query then
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

	Example:
	  parseArgs('kick "John Doe" "bad behaviour"')
	  → { "kick", "John Doe", "bad behaviour" }
--]]
function CommandRegistry.parseArgs(input: string): { string }
	local args = {}
	local i    = 1
	local len  = #input

	while i <= len do
		-- skip whitespace
		while i <= len and input:sub(i, i):match("%s") do
			i += 1
		end
		if i > len then break end

		if input:sub(i, i) == '"' then
			-- Quoted token — collect until closing quote
			i += 1
			local start = i
			while i <= len and input:sub(i, i) ~= '"' do
				i += 1
			end
			table.insert(args, input:sub(start, i - 1))
			i += 1  -- skip closing "
		else
			-- Unquoted token — collect until whitespace
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
