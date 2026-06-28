--[[
        CommandServer.server.lua
        Script — ServerScriptService

        Receives command executions from the client command bar, validates
        permissions, and dispatches to the appropriate handler.

        ─── Adding commands ──────────────────────────────────────────────────────────
        1. Add the command definition to CommandRegistry.lua (ReplicatedStorage)
        2. Add a handler function in the HANDLERS table below
        3. Set the appropriate permission level on the definition

        ─── Permission setup ─────────────────────────────────────────────────────────
        Edit STAFF_CONFIG below. You can whitelist by UserId or by Roblox group rank.
        Tier hierarchy: Helper < Moderator < Admin < Owner.
--]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TeleportService    = game:GetService("TeleportService")
local InsertService      = game:GetService("InsertService")
local ServerStorage      = game:GetService("ServerStorage")
local RunService         = game:GetService("RunService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService   = game:GetService("MessagingService")

local IS_STUDIO = RunService:IsStudio()

local CommandRemotes  = require(ReplicatedStorage:WaitForChild("CommandRemotes")  :: ModuleScript)
local CommandRegistry = require(ReplicatedStorage:WaitForChild("CommandRegistry") :: ModuleScript)

-- ─── Staff configuration ───────────────────────────────────────────────────────

local STAFF_CONFIG = {
        STAFF_IDS = {
                [1872507151] = "Owner",
        },
        GROUP_ID   = 0,
        GROUP_RANKS = {},
}

local TIER_ORDER = { Helper = 1, Moderator = 2, Admin = 3, Owner = 4 }

local function getTier(player: Player): string?
        -- In Studio, grant Owner to everyone for testing
        if IS_STUDIO then return "Owner" end

        -- Game creator always gets Owner
        if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
                return "Owner"
        end

        local directTier = STAFF_CONFIG.STAFF_IDS[player.UserId]
        if directTier then return directTier end
        if STAFF_CONFIG.GROUP_ID > 0 then
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
        return nil
end

local function hasPermission(player: Player, required: string): boolean
        local tier = getTier(player)
        if not tier then return false end
        return (TIER_ORDER[tier] or 0) >= (TIER_ORDER[required] or 99)
end

-- ─── Player resolution ────────────────────────────────────────────────────────

local function resolvePlayer(executor: Player, name: string): Player?
        if name:lower() == "me" then return executor end
        local lower = name:lower()
        for _, p in Players:GetPlayers() do
                if p.Name:lower() == lower or p.DisplayName:lower() == lower then
                        return p
                end
        end
        for _, p in Players:GetPlayers() do
                if p.Name:lower():sub(1, #lower) == lower then
                        return p
                end
        end
        return nil
end

-- ─── Feedback helpers ─────────────────────────────────────────────────────────

local function ok(player: Player, msg: string)
        CommandRemotes.CommandFeedback:FireClient(player, true, msg)
end

local function fail(player: Player, msg: string)
        CommandRemotes.CommandFeedback:FireClient(player, false, msg)
end

-- ─── Shared server state ──────────────────────────────────────────────────────

local helpUIPlayers: { [number]: boolean } = {}   -- UserId → has helpUI on
local blindedPlayers: { [number]: boolean } = {}  -- UserId → is blinded
local ragdolledPlayers: { [number]: boolean } = {}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

-- Join args from index `start` onward into a single string
local function joinArgs(args: { string }, start: number): string
        local parts = {}
        for i = start, #args do
                table.insert(parts, args[i])
        end
        return table.concat(parts, " ")
end

-- Get character HumanoidRootPart or nil
local function getHRP(player: Player): BasePart?
        local char = player.Character
        return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Get Humanoid or nil
local function getHumanoid(player: Player): Humanoid?
        local char = player.Character
        return char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

-- Fire to all players in the helpUI set (for help requests)
local function fireToHelpUIPlayers(...)
        for userId, on in helpUIPlayers do
                if not on then continue end
                local player = Players:GetPlayerByUserId(userId)
                if player then
                        CommandRemotes.HelpReceive:FireClient(player, ...)
                end
        end
end

-- ─── Command Handlers ─────────────────────────────────────────────────────────

local HANDLERS: { [string]: (executor: Player, args: { string }) -> () } = {}

-- ── blind <player> ────────────────────────────────────────────────────────────
HANDLERS["blind"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: blind <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        blindedPlayers[target.UserId] = true
        CommandRemotes.Blind:FireClient(target, true)
        ok(executor, target.DisplayName .. " has been blinded.")
end

-- ── unblind <player> ──────────────────────────────────────────────────────────
HANDLERS["unblind"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: unblind <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        blindedPlayers[target.UserId] = nil
        CommandRemotes.Blind:FireClient(target, false)
        ok(executor, target.DisplayName .. " has been unblinded.")
end

-- ── blindall ──────────────────────────────────────────────────────────────────
HANDLERS["blindall"] = function(executor, _args)
        for _, player in Players:GetPlayers() do
                blindedPlayers[player.UserId] = true
                CommandRemotes.Blind:FireClient(player, true)
        end
        ok(executor, "All players blinded.")
end

-- ── unblindall ────────────────────────────────────────────────────────────────
HANDLERS["unblindall"] = function(executor, _args)
        for _, player in Players:GetPlayers() do
                blindedPlayers[player.UserId] = nil
                CommandRemotes.Blind:FireClient(player, false)
        end
        ok(executor, "All players unblinded.")
end

-- ── bring <player> ────────────────────────────────────────────────────────────
HANDLERS["bring"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: bring <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local myHRP  = getHRP(executor)
        local tgtHRP = getHRP(target)
        if not myHRP  then fail(executor, "You have no character loaded.") return end
        if not tgtHRP then fail(executor, target.DisplayName .. " has no character loaded.") return end

        tgtHRP.CFrame = myHRP.CFrame + myHRP.CFrame.LookVector * 3
        ok(executor, target.DisplayName .. " brought to you.")
end

-- ── kick <player> [reason] ────────────────────────────────────────────────────
HANDLERS["kick"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: kick <player> [reason]") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end
        if target == executor then fail(executor, "You cannot kick yourself.") return end

        local reason = args[2] and joinArgs(args, 2) or "Removed by staff."
        target:Kick("You were kicked: " .. reason)
        ok(executor, target.DisplayName .. " kicked. (" .. reason .. ")")
end

-- ── damage <player> <amount> ──────────────────────────────────────────────────
HANDLERS["damage"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: damage <player> <amount>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local amount = tonumber(args[2])
        if not amount or amount <= 0 then fail(executor, "Amount must be a positive number.") return end

        local hum = getHumanoid(target)
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        hum.Health = math.max(0, hum.Health - amount)
        ok(executor, target.DisplayName .. " dealt " .. amount .. " damage. (" .. math.floor(hum.Health) .. " HP remaining)")
end

-- ── heal <player> ─────────────────────────────────────────────────────────────
HANDLERS["heal"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: heal <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local hum = getHumanoid(target)
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        hum.Health = hum.MaxHealth
        ok(executor, target.DisplayName .. " healed to full.")
end

-- ── respawn <player> ──────────────────────────────────────────────────────────
HANDLERS["respawn"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: respawn <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        target:LoadCharacter()
        ok(executor, target.DisplayName .. " respawned.")
end

-- ── re <player> — refresh and return to position ──────────────────────────────
HANDLERS["re"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: re <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local hrp = getHRP(target)
        if not hrp then fail(executor, target.DisplayName .. " has no character loaded.") return end

        local savedCFrame = hrp.CFrame
        target:LoadCharacter()

        -- Wait for new character to load, then move them back
        task.spawn(function()
                local char = target.CharacterAdded:Wait()
                task.wait(0.1)
                local newHRP = char:WaitForChild("HumanoidRootPart", 5)
                if newHRP then
                        newHRP.CFrame = savedCFrame
                end
        end)

        ok(executor, target.DisplayName .. " refreshed and returned to position.")
end

-- ── ragdoll <player> ──────────────────────────────────────────────────────────
HANDLERS["ragdoll"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: ragdoll <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        -- Freeze the humanoid in Ragdoll state
        hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
        hum.PlatformStand = true

        -- Set all motor joints to MaxFriction = 0 so physics takes over
        for _, desc in char:GetDescendants() do
                if desc:IsA("Motor6D") then
                        desc.Enabled = false
                end
        end

        -- Unset after 4 seconds so they can get up
        task.delay(4, function()
                if target.Character ~= char then return end
                for _, desc in char:GetDescendants() do
                        if desc:IsA("Motor6D") then
                                desc.Enabled = true
                        end
                end
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)

        ok(executor, target.DisplayName .. " ragdolled.")
end

-- ── createcorpse <player> ─────────────────────────────────────────────────────
HANDLERS["createcorpse"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: createcorpse <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        if not char then fail(executor, target.DisplayName .. " has no character loaded.") return end

        -- Clone the character model into workspace as a frozen corpse
        local corpse = char:Clone()
        corpse.Name = target.DisplayName .. "_Corpse"

        -- Disable humanoid so it doesn't stand up
        local hum = corpse:FindFirstChildOfClass("Humanoid")
        if hum then
                hum.Health = 0
                hum:Destroy()
        end

        -- Anchor each BasePart and freeze it
        for _, part in corpse:GetDescendants() do
                if part:IsA("BasePart") then
                        part.Anchored = false
                        part.CanCollide = true
                end
                if part:IsA("Motor6D") then
                        part.Enabled = false
                end
        end

        -- Root it in workspace at the same CFrame
        local hrp = corpse:FindFirstChild("HumanoidRootPart")
        if hrp then
                hrp.Anchored = false
        end

        corpse.Parent = workspace

        -- Auto-clean after 60 seconds
        game:GetService("Debris"):AddItem(corpse, 60)
        ok(executor, "Corpse created for " .. target.DisplayName .. " (auto-clears in 60s).")
end

-- ── clearhats <player> ────────────────────────────────────────────────────────
HANDLERS["clearhats"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: clearhats <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        if not char then fail(executor, target.DisplayName .. " has no character loaded.") return end

        local count = 0
        for _, child in char:GetChildren() do
                if child:IsA("Accessory") then
                        child:Destroy()
                        count += 1
                end
        end
        ok(executor, "Removed " .. count .. " accessory/hat(s) from " .. target.DisplayName .. ".")
end

-- ── hat <player> <assetId> ────────────────────────────────────────────────────
HANDLERS["hat"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: hat <player> <assetId>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local assetId = tonumber(args[2])
        if not assetId then fail(executor, "Asset ID must be a number.") return end

        local char = target.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then fail(executor, target.DisplayName .. " has no character loaded.") return end

        local success, result = pcall(function()
                local asset = InsertService:LoadAsset(assetId)
                local accessory = asset:FindFirstChildOfClass("Accessory")
                if accessory then
                        accessory.Parent = asset
                        hum:AddAccessory(accessory)
                        asset:Destroy()
                else
                        asset:Destroy()
                        error("Asset " .. assetId .. " does not contain an Accessory.")
                end
        end)

        if success then
                ok(executor, "Hat " .. assetId .. " given to " .. target.DisplayName .. ".")
        else
                fail(executor, "Failed to load hat: " .. tostring(result))
        end
end

-- ── removehat <player> <hatName> ─────────────────────────────────────────────
HANDLERS["removehat"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: removehat <player> <hatName>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local char = target.Character
        if not char then fail(executor, target.DisplayName .. " has no character loaded.") return end

        local hatName = args[2]:lower()
        local found   = false
        for _, child in char:GetChildren() do
                if child:IsA("Accessory") and child.Name:lower():find(hatName, 1, true) then
                        child:Destroy()
                        found = true
                        break
                end
        end

        if found then
                ok(executor, 'Removed hat matching "' .. args[2] .. '" from ' .. target.DisplayName .. ".")
        else
                fail(executor, 'No hat matching "' .. args[2] .. '" found on ' .. target.DisplayName .. ".")
        end
end

-- ── giveitem <player> <itemName> ──────────────────────────────────────────────
HANDLERS["giveitem"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: giveitem <player> <itemName>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local itemName = joinArgs(args, 2)
        local tool = ServerStorage:FindFirstChild(itemName, true)
        if not tool or not tool:IsA("Tool") then
                fail(executor, 'No Tool named "' .. itemName .. '" found in ServerStorage.') return
        end

        local clone = tool:Clone()
        clone.Parent = target.Backpack
        ok(executor, '"' .. itemName .. '" given to ' .. target.DisplayName .. ".")
end

-- ── tempitem <player> <itemName> [duration] ───────────────────────────────────
HANDLERS["tempitem"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: tempitem <player> <itemName> [duration]") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        -- Last arg is duration if numeric, otherwise part of name
        local duration = 30
        local nameArgs = {}
        for i = 2, #args do
                local asNum = tonumber(args[i])
                if asNum and i == #args then
                        duration = asNum
                else
                        table.insert(nameArgs, args[i])
                end
        end
        local itemName = table.concat(nameArgs, " ")

        local tool = ServerStorage:FindFirstChild(itemName, true)
        if not tool or not tool:IsA("Tool") then
                fail(executor, 'No Tool named "' .. itemName .. '" found in ServerStorage.') return
        end

        local clone = tool:Clone()
        clone.Parent = target.Backpack
        ok(executor, '"' .. itemName .. '" given temporarily to ' .. target.DisplayName
                .. " (removed in " .. duration .. "s).")

        task.delay(duration, function()
                -- Remove from Backpack or Character
                local bp = clone.Parent
                if clone and clone.Parent then
                        clone:Destroy()
                end
                -- Also remove if equipped
                if target.Character then
                        local equipped = target.Character:FindFirstChild(itemName)
                        if equipped and equipped:IsA("Tool") then
                                equipped:Destroy()
                        end
                end
        end)
end

-- ── removeitem <player> ───────────────────────────────────────────────────────
HANDLERS["removeitem"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: removeitem <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local count = 0
        for _, item in target.Backpack:GetChildren() do
                if item:IsA("Tool") then
                        item:Destroy()
                        count += 1
                end
        end
        -- Also remove equipped tool
        if target.Character then
                local equipped = target.Character:FindFirstChildOfClass("Tool")
                if equipped then
                        equipped.Parent = nil
                        equipped:Destroy()
                        count += 1
                end
        end
        ok(executor, "Removed " .. count .. " item(s) from " .. target.DisplayName .. ".")
end

-- ── tp <from> <to> ────────────────────────────────────────────────────────────
HANDLERS["tp"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: tp <from> <to>") return
        end
        local from = resolvePlayer(executor, args[1])
        local to   = resolvePlayer(executor, args[2])
        if not from then fail(executor, 'No player found: "' .. args[1] .. '"') return end
        if not to   then fail(executor, 'No player found: "' .. args[2] .. '"') return end

        local fromHRP = getHRP(from)
        local toHRP   = getHRP(to)
        if not fromHRP then fail(executor, from.DisplayName .. " has no character.") return end
        if not toHRP   then fail(executor, to.DisplayName .. " has no character.") return end

        fromHRP.CFrame = toHRP.CFrame + Vector3.new(0, 3, 0)
        ok(executor, from.DisplayName .. " → " .. to.DisplayName)
end
HANDLERS["teleport"] = HANDLERS["tp"]

-- ── to <player> ───────────────────────────────────────────────────────────────
HANDLERS["to"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: to <player>") return end
        HANDLERS["tp"](executor, { "me", args[1] })
end

-- ── place <player> <placeId> ──────────────────────────────────────────────────
HANDLERS["place"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: place <player> <placeId>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local placeId = tonumber(args[2])
        if not placeId then fail(executor, "Place ID must be a number.") return end

        local success, err = pcall(function()
                TeleportService:TeleportAsync(placeId, { target })
        end)
        if success then
                ok(executor, target.DisplayName .. " sent to place " .. placeId .. ".")
        else
                fail(executor, "Teleport failed: " .. tostring(err))
        end
end

-- ── serverbring <player> ──────────────────────────────────────────────────────
HANDLERS["serverbring"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: serverbring <player>") return end
        local target = resolvePlayer(executor, args[1])

        -- If the player is already in this server, just bring them normally
        if target then
                HANDLERS["bring"](executor, args)
                return
        end

        -- Cross-server: publish a message requesting the player teleport here
        local targetName = args[1]
        local jobId = game.JobId

        local success, err = pcall(function()
                MessagingService:PublishAsync("ServerbringRequest", {
                        targetName = targetName,
                        jobId      = jobId,
                        placeId    = game.PlaceId,
                })
        end)

        if success then
                ok(executor, 'Serverbring request sent for "' .. targetName
                        .. '". They will be teleported here if found in another server.')
        else
                fail(executor, "Cross-server bring requires MessagingService to be enabled in a published game. Error: " .. tostring(err))
        end
end

-- ── serverjoin <player> ───────────────────────────────────────────────────────
HANDLERS["serverjoin"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: serverjoin <player>") return end
        local target = resolvePlayer(executor, args[1])

        -- If they're in this server just confirm
        if target then
                fail(executor, target.DisplayName .. " is already in this server. Use 'to' to teleport to them.")
                return
        end

        -- Cross-server: look up their server in MemoryStore
        local success, result = pcall(function()
                local map = MemoryStoreService:GetSortedMap("PlayerServers")
                return map:GetAsync(args[1])
        end)

        if success and result and result.jobId then
                local opts = Instance.new("TeleportOptions")
                opts.ServerInstanceId = result.jobId
                local tpSuccess, err = pcall(function()
                        TeleportService:TeleportAsync(game.PlaceId, { executor }, opts)
                end)
                if not tpSuccess then
                        fail(executor, "Teleport failed: " .. tostring(err))
                end
        else
                fail(executor, 'Could not find server for "' .. args[1] .. '". They may be offline or MemoryStore is unavailable.')
        end
end

-- ── privateserver ─────────────────────────────────────────────────────────────
HANDLERS["privateserver"] = function(executor, _args)
        local success, code = pcall(function()
                return TeleportService:ReserveServer(game.PlaceId)
        end)
        if not success then
                fail(executor, "Failed to reserve server: " .. tostring(code)) return
        end

        local opts = Instance.new("TeleportOptions")
        opts.ReservedServerAccessCode = code
        local tpSuccess, err = pcall(function()
                TeleportService:TeleportAsync(game.PlaceId, { executor }, opts)
        end)
        if tpSuccess then
                ok(executor, "Private server reserved. Teleporting you there now. Drag players in to add them.")
        else
                fail(executor, "Teleport to private server failed: " .. tostring(err))
        end
end

-- ── setwaypoint [label] ───────────────────────────────────────────────────────
HANDLERS["setwaypoint"] = function(executor, args)
        local hrp = getHRP(executor)
        if not hrp then fail(executor, "You have no character loaded.") return end

        local label = args[1] and joinArgs(args, 1) or "Waypoint"
        local pos   = hrp.Position

        for _, player in Players:GetPlayers() do
                CommandRemotes.Waypoint:FireClient(player, "set", pos.X, pos.Y, pos.Z, label, executor.DisplayName)
        end
        ok(executor, 'Waypoint "' .. label .. '" placed at your position.')
end

-- ── clearwaypoints ────────────────────────────────────────────────────────────
HANDLERS["clearwaypoints"] = function(executor, _args)
        for _, player in Players:GetPlayers() do
                CommandRemotes.Waypoint:FireClient(player, "clear")
        end
        ok(executor, "All waypoints cleared.")
end

-- ── setworldspawn ─────────────────────────────────────────────────────────────
HANDLERS["setworldspawn"] = function(executor, _args)
        local hrp = getHRP(executor)
        if not hrp then fail(executor, "You have no character loaded.") return end

        local pos = hrp.Position

        -- Move every SpawnLocation, or create a dummy anchor
        local found = false
        for _, obj in workspace:GetDescendants() do
                if obj:IsA("SpawnLocation") then
                        obj.CFrame = CFrame.new(pos)
                        found = true
                end
        end

        if not found then
                -- Create a neutral spawn point
                local spawn = Instance.new("SpawnLocation")
                spawn.Size           = Vector3.new(6, 1, 6)
                spawn.CFrame         = CFrame.new(pos)
                spawn.Neutral        = true
                spawn.Duration       = 0
                spawn.Name           = "WorldSpawn"
                spawn.BrickColor     = BrickColor.new("Medium stone grey")
                spawn.Parent         = workspace
        end

        ok(executor, "World spawn set to " .. math.floor(pos.X) .. ", " .. math.floor(pos.Y) .. ", " .. math.floor(pos.Z) .. ".")
end

-- ── shutdown [delay] ──────────────────────────────────────────────────────────
HANDLERS["shutdown"] = function(executor, args)
        local delayTime = tonumber(args[1]) or 5

        for _, player in Players:GetPlayers() do
                CommandRemotes.CommandFeedback:FireClient(player, false,
                        "⚠ Server shutting down in " .. delayTime .. " seconds…")
        end

        task.delay(delayTime, function()
                for _, player in Players:GetPlayers() do
                        player:Kick("The server has been shut down.")
                end
        end)

        ok(executor, "Shutdown initiated — " .. delayTime .. "s delay.")
        warn("[CommandServer] SHUTDOWN triggered by " .. executor.Name)
end

-- ── invis ─────────────────────────────────────────────────────────────────────
HANDLERS["invis"] = function(executor, _args)
        local char = executor.Character
        if not char then fail(executor, "You have no character loaded.") return end

        for _, part in char:GetDescendants() do
                if part:IsA("BasePart") or part:IsA("Decal") then
                        part.Transparency = 1
                end
        end
        ok(executor, "You are now invisible.")
end

-- ── uninvis ───────────────────────────────────────────────────────────────────
HANDLERS["uninvis"] = function(executor, _args)
        local char = executor.Character
        if not char then fail(executor, "You have no character loaded.") return end

        -- Reload character to restore default transparencies cleanly
        local hrp = getHRP(executor)
        local savedCFrame = hrp and hrp.CFrame
        executor:LoadCharacter()

        if savedCFrame then
                task.spawn(function()
                        local newChar = executor.CharacterAdded:Wait()
                        task.wait(0.1)
                        local newHRP = newChar:WaitForChild("HumanoidRootPart", 5)
                        if newHRP then newHRP.CFrame = savedCFrame end
                end)
        end

        ok(executor, "You are now visible.")
end

-- ── sm <message> ──────────────────────────────────────────────────────────────
HANDLERS["sm"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: sm <message>") return end
        local message = joinArgs(args, 1)

        for _, player in Players:GetPlayers() do
                CommandRemotes.SM:FireClient(player, message)
        end
        ok(executor, "Server message sent.")
end

-- ── im <player> <message> ─────────────────────────────────────────────────────
HANDLERS["im"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: im <player> <message>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local message = joinArgs(args, 2)
        CommandRemotes.IM:FireClient(target, message)
        ok(executor, "Individual message sent to " .. target.DisplayName .. ".")
end

-- ── pm <player> <message> ─────────────────────────────────────────────────────
HANDLERS["pm"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: pm <player> <message>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local message = joinArgs(args, 2)
        CommandRemotes.PM:FireClient(target, executor.DisplayName, message)
        ok(executor, "PM sent to " .. target.DisplayName .. ".")
end

-- ── notif <player> <message> ──────────────────────────────────────────────────
HANDLERS["notif"] = function(executor, args)
        if not args[1] or not args[2] then
                fail(executor, "Usage: notif <player> <message>") return
        end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        local message = joinArgs(args, 2)
        CommandRemotes.Notif:FireClient(target, executor.DisplayName, message)
        ok(executor, "Notification sent to " .. target.DisplayName .. ".")
end

-- ── countdown <seconds> ───────────────────────────────────────────────────────
HANDLERS["countdown"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: countdown <seconds>") return end
        local seconds = tonumber(args[1])
        if not seconds or seconds <= 0 then
                fail(executor, "Seconds must be a positive number.") return
        end
        seconds = math.floor(math.clamp(seconds, 1, 120))

        for _, player in Players:GetPlayers() do
                CommandRemotes.Countdown:FireClient(player, seconds)
        end
        ok(executor, "Countdown started: " .. seconds .. "s.")
end

-- ── music <assetId> ───────────────────────────────────────────────────────────
HANDLERS["music"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: music <assetId>  (use 0 to stop)") return end
        local assetId = tonumber(args[1])
        if not assetId then fail(executor, "Asset ID must be a number.") return end

        for _, player in Players:GetPlayers() do
                CommandRemotes.Music:FireClient(player, assetId)
        end
        if assetId == 0 then
                ok(executor, "Music stopped.")
        else
                ok(executor, "Music playing: rbxassetid://" .. assetId)
        end
end

-- ── esp ───────────────────────────────────────────────────────────────────────
HANDLERS["esp"] = function(executor, _args)
        CommandRemotes.ESP:FireClient(executor, true)   -- client toggles internally
        ok(executor, "ESP toggled.")
end

-- ── fly <player> ──────────────────────────────────────────────────────────────
HANDLERS["fly"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: fly <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        CommandRemotes.Fly:FireClient(target, true)   -- client toggles internally
        ok(executor, "Fly toggled for " .. target.DisplayName .. ". (E to fly, Alt to speed up)")
end

-- ── watch <player> ────────────────────────────────────────────────────────────
HANDLERS["watch"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: watch <player>") return end
        local target = resolvePlayer(executor, args[1])
        if not target then fail(executor, 'No player found: "' .. args[1] .. '"') return end

        CommandRemotes.Watch:FireClient(executor, target.Name)
        ok(executor, "Now watching " .. target.DisplayName .. "'s POV. (Run watch again to stop)")
end

-- ── chatlogs ─────────────────────────────────────────────────────────────────
HANDLERS["chatlogs"] = function(executor, _args)
        local logs = _G.ChatLog or {}
        CommandRemotes.ChatLogs:FireClient(executor, logs)
        ok(executor, "Chat logs opened (" .. #logs .. " entries).")
end

-- ── help <message> ────────────────────────────────────────────────────────────
HANDLERS["help"] = function(executor, args)
        if not args[1] then fail(executor, "Usage: help <message>") return end
        local message = joinArgs(args, 1)

        local staffCount = 0
        for userId, on in helpUIPlayers do
                if on then
                        local player = Players:GetPlayerByUserId(userId)
                        if player and player ~= executor then
                                CommandRemotes.HelpReceive:FireClient(player, executor.DisplayName, message)
                                staffCount += 1
                        end
                end
        end

        ok(executor, "Help request sent to " .. staffCount .. " staff member(s) with helpUI enabled.")
end

-- ── helpui ────────────────────────────────────────────────────────────────────
HANDLERS["helpui"] = function(executor, _args)
        local current = helpUIPlayers[executor.UserId] or false
        local newState = not current
        helpUIPlayers[executor.UserId] = newState

        CommandRemotes.HelpUI:FireClient(executor, newState)
        ok(executor, "Help UI " .. (newState and "enabled" or "disabled") .. ". You will " .. (newState and "now" or "no longer") .. " receive help requests.")
end

-- ─── Client helpUI state sync ─────────────────────────────────────────────────
-- (client can also directly toggle; keep server in sync)
CommandRemotes.HelpUIState.OnServerEvent:Connect(function(player: Player, isOn: boolean)
        if typeof(isOn) ~= "boolean" then return end
        helpUIPlayers[player.UserId] = isOn
end)

-- ─── Track players for cross-server features ──────────────────────────────────
Players.PlayerAdded:Connect(function(player: Player)
        pcall(function()
                local map = MemoryStoreService:GetSortedMap("PlayerServers")
                map:SetAsync(player.Name, { jobId = game.JobId, placeId = game.PlaceId }, 300)
        end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
        helpUIPlayers[player.UserId]  = nil
        blindedPlayers[player.UserId] = nil
        pcall(function()
                local map = MemoryStoreService:GetSortedMap("PlayerServers")
                map:RemoveAsync(player.Name)
        end)
end)

-- ─── Listen for serverbring requests from other servers ───────────────────────
pcall(function()
        MessagingService:SubscribeAsync("ServerbringRequest", function(message)
                local data = message.Data
                if typeof(data) ~= "table" then return end
                local targetName = data.targetName
                local jobId      = data.jobId
                local placeId    = data.placeId

                local target = Players:FindFirstChild(targetName)
                if target then
                        local opts = Instance.new("TeleportOptions")
                        opts.ServerInstanceId = jobId
                        pcall(function()
                                TeleportService:TeleportAsync(placeId, { target }, opts)
                        end)
                end
        end)
end)

-- ─── Incoming remote handler ───────────────────────────────────────────────────

CommandRemotes.CommandExecuted.OnServerEvent:Connect(function(executor: Player, cmdName: string, args: { string })
        if typeof(cmdName) ~= "string" then return end
        if typeof(args) ~= "table" then args = {} end

        cmdName = cmdName:lower():match("^%s*(.-)%s*$") or ""
        if cmdName == "" then return end

        local safeArgs = {}
        for _, v in args do
                if typeof(v) == "string" then
                        table.insert(safeArgs, v)
                end
        end

        local definition = CommandRegistry.COMMANDS[cmdName]
        if not definition then
                -- Check aliases
                for name, entry in CommandRegistry.COMMANDS do
                        for _, alias in entry.aliases or {} do
                                if alias:lower() == cmdName then
                                        definition = entry
                                        cmdName = name
                                        break
                                end
                        end
                        if definition then break end
                end
        end

        if not definition then
                fail(executor, 'Unknown command: "' .. cmdName .. '".')
                return
        end

        if not hasPermission(executor, definition.permission) then
                fail(executor, 'You do not have permission to use "' .. cmdName
                        .. '" (requires ' .. definition.permission .. ').')
                return
        end

        local handler = HANDLERS[cmdName]
        if not handler then
                fail(executor, '"' .. cmdName .. '" has no server handler yet.')
                return
        end

        local success, err = pcall(handler, executor, safeArgs)
        if not success then
                fail(executor, "Command error: " .. tostring(err))
                warn("[CommandServer] ERROR in '" .. cmdName .. "': " .. tostring(err))
        end
end)

local handlerCount = 0
for _ in HANDLERS do handlerCount += 1 end
print("[CommandServer] Staff command system active. " .. handlerCount .. " commands registered.")
