--!nonstrict
-- Saved player data (DataStoreService): lifetime grandma kills, best wave, victories, revive credits.
-- Match cash and weapons are never saved.
--
-- Safety:
--   * Every DataStore call is wrapped in pcall and retried (Config.Data.Retries, waits 1 s, 2 s, 4 s).
--   * Saves only send what changed (deltas) through UpdateAsync and merge them into the stored value
--     (counts are added, BestWave takes the maximum). A failed load or a second server can never wipe data.
--   * Autosave every Config.Data.AutosaveSeconds, save on leave, save everyone on shutdown (BindToClose).
--   * Developer product receipts are recorded in the same document, so a purchase is granted exactly once.
-- Without DataStore access (unpublished place, or Studio without "Enable Studio Access to API Services")
-- everything still works for the session, nothing is saved, and a warning explains why.
--
-- Replicates player attributes LifetimeKills, BestWave, Victories, Revives and a `leaderstats` folder
-- (Kills, Best Wave, Wins) for the Roblox player list.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local DataService = {}

local DataConfig = Config.Data
local COUNTERS = { "Kills", "Victories", "Revives" } -- summed on save
local LEADERSTATS = { { Name = "Kills", Field = "Kills" }, { Name = "Best Wave", Field = "BestWave" }, { Name = "Wins", Field = "Victories" } }

type Document = { Kills: number, BestWave: number, Victories: number, Revives: number, Receipts: { string } }
type Session = {
	Values: Document, -- what the player sees (stored value + unsaved changes)
	Pending: { [string]: number }, -- unsaved counter changes
	PendingBest: number, -- best wave reached this session (0 = nothing new)
	Saving: boolean,
	Loaded: boolean,
}

local store: DataStore? = nil
local sessions: { [Player]: Session } = {}
local sessionReceipts: { [string]: boolean } = {} -- receipts granted while DataStores are unavailable

local function newDocument(): Document
	return { Kills = 0, BestWave = 0, Victories = 0, Revives = 0, Receipts = {} }
end

-- Fills in missing fields of a stored document (older versions, corrupted values).
local function sanitize(data: any): Document
	local doc = newDocument()
	if type(data) == "table" then
		for _, field in { "Kills", "BestWave", "Victories", "Revives" } do
			if type(data[field]) == "number" and data[field] == data[field] then
				doc[field] = math.max(0, math.floor(data[field]))
			end
		end
		if type(data.Receipts) == "table" then
			for _, id in data.Receipts do
				if type(id) == "string" then
					table.insert(doc.Receipts, id)
				end
			end
		end
	end
	return doc
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

-- Runs a DataStore call with retries. Returns (ok, result).
local function withRetries(label: string, call: () -> any): (boolean, any)
	local waitTime = 1
	local lastError
	for attempt = 1, DataConfig.Retries do
		local ok, result = pcall(call)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < DataConfig.Retries then
			task.wait(waitTime)
			waitTime *= 2
		end
	end
	warn("[DataService] " .. label .. " failed: " .. tostring(lastError))
	return false, nil
end

local function publish(player: Player, session: Session)
	local values = session.Values
	player:SetAttribute("LifetimeKills", values.Kills)
	player:SetAttribute("BestWave", values.BestWave)
	player:SetAttribute("Victories", values.Victories)
	player:SetAttribute("Revives", values.Revives)
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		for _, stat in LEADERSTATS do
			local value = folder:FindFirstChild(stat.Name)
			if value then
				value.Value = values[stat.Field]
			end
		end
	end
end

local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, stat in LEADERSTATS do
		local value = Instance.new("IntValue")
		value.Name = stat.Name
		value.Parent = folder
	end
	folder.Parent = player
end

-- Shows the stored values plus anything not saved yet.
local function applyStored(session: Session, stored: Document)
	local values = session.Values
	for _, field in COUNTERS do
		values[field] = stored[field] + (session.Pending[field] or 0)
	end
	values.BestWave = math.max(stored.BestWave, session.PendingBest)
	values.Receipts = stored.Receipts
end

local function hasChanges(session: Session): boolean
	if session.PendingBest > 0 then
		return true
	end
	for _, amount in session.Pending do
		if amount ~= 0 then
			return true
		end
	end
	return false
end

-- Sends the unsaved changes. Safe to call any time; only one save per player runs at once.
local function save(player: Player, session: Session)
	if not store or session.Saving or not hasChanges(session) then
		return
	end
	session.Saving = true
	local sent = table.clone(session.Pending)
	local sentBest = session.PendingBest
	local ok, stored = withRetries("save " .. player.Name, function()
		return store:UpdateAsync(keyFor(player.UserId), function(old)
			local doc = sanitize(old)
			for field, amount in sent do
				doc[field] = math.max(0, doc[field] + amount)
			end
			doc.BestWave = math.max(doc.BestWave, sentBest)
			return doc
		end)
	end)
	if ok then
		for field, amount in sent do
			session.Pending[field] = (session.Pending[field] or 0) - amount
		end
		if session.PendingBest == sentBest then
			session.PendingBest = 0
		end
		applyStored(session, sanitize(stored))
		if player.Parent == Players then
			publish(player, session)
		end
	end
	session.Saving = false
end

local function onPlayerAdded(player: Player)
	local session: Session = { Values = newDocument(), Pending = {}, PendingBest = 0, Saving = false, Loaded = false }
	sessions[player] = session
	createLeaderstats(player)
	publish(player, session)
	if not store then
		return
	end
	local ok, data = withRetries("load " .. player.Name, function()
		return store:GetAsync(keyFor(player.UserId))
	end)
	if sessions[player] ~= session then
		return -- left while loading
	end
	if ok then
		session.Loaded = true
		applyStored(session, sanitize(data))
		publish(player, session)
	end
	-- a failed load is fine: changes are still saved as deltas and merged into whatever is stored
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	-- wait for a running save, then send the rest
	local deadline = os.clock() + 15
	while session.Saving and os.clock() < deadline do
		task.wait(0.2)
	end
	save(player, session)
	sessions[player] = nil
end

-- public -------------------------------------------------------------------

function DataService.AddKill(player: Player)
	local session = sessions[player]
	if session then
		session.Pending.Kills = (session.Pending.Kills or 0) + 1
		session.Values.Kills += 1
		publish(player, session)
	end
end

function DataService.AddVictory(player: Player)
	local session = sessions[player]
	if session then
		session.Pending.Victories = (session.Pending.Victories or 0) + 1
		session.Values.Victories += 1
		publish(player, session)
	end
end

-- Records waves survived; returns the player's best wave.
function DataService.RecordWave(player: Player, wavesSurvived: number): number
	local session = sessions[player]
	if not session then
		return wavesSurvived
	end
	if wavesSurvived > session.Values.BestWave then
		session.Values.BestWave = wavesSurvived
		session.PendingBest = math.max(session.PendingBest, wavesSurvived)
		publish(player, session)
	end
	return session.Values.BestWave
end

function DataService.GetRevives(player: Player): number
	local session = sessions[player]
	return if session then session.Values.Revives else 0
end

-- Spends one revive credit. Returns false if the player has none.
function DataService.TakeRevive(player: Player): boolean
	local session = sessions[player]
	if not session or session.Values.Revives <= 0 then
		return false
	end
	session.Pending.Revives = (session.Pending.Revives or 0) - 1
	session.Values.Revives -= 1
	publish(player, session)
	task.spawn(save, player, session) -- save spent credits right away
	return true
end

-- Grants a developer product purchase exactly once (`field` += `amount`, e.g. Revives + 1).
-- Returns true when the grant is stored (or was already stored earlier): then the receipt may be
-- reported as PurchaseGranted. Returns false if it could not be saved (Roblox retries the receipt later).
function DataService.GrantReceipt(userId: number, purchaseId: string, field: string, amount: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	local session = player and sessions[player]
	if not store then
		-- no DataStores (Studio test purchase): grant for this session only
		if not sessionReceipts[purchaseId] then
			sessionReceipts[purchaseId] = true
			if session then
				session.Values[field] += amount
				publish(player, session)
			end
		end
		return true
	end
	-- one write per player at a time, so a save and a receipt never overwrite each other's result
	if session then
		local deadline = os.clock() + 15
		while session.Saving and os.clock() < deadline do
			task.wait(0.2)
		end
		session.Saving = true
	end
	local ok, stored = withRetries("receipt " .. purchaseId, function()
		return store:UpdateAsync(keyFor(userId), function(old)
			local doc = sanitize(old)
			if table.find(doc.Receipts, purchaseId) then
				return nil -- already granted: keep the stored value unchanged
			end
			doc[field] = math.max(0, doc[field] + amount)
			table.insert(doc.Receipts, purchaseId)
			while #doc.Receipts > DataConfig.MaxStoredReceipts do
				table.remove(doc.Receipts, 1)
			end
			return doc
		end)
	end)
	if not ok then
		if session then
			session.Saving = false
		end
		return false
	end
	if player and session and player.Parent == Players then
		if stored ~= nil then
			applyStored(session, sanitize(stored))
		else
			-- UpdateAsync returns nil when the transform returned nil (already granted): re-read to stay in sync
			local readOk, data = withRetries("reload " .. player.Name, function()
				return store:GetAsync(keyFor(userId))
			end)
			if readOk then
				applyStored(session, sanitize(data))
			end
		end
		publish(player, session)
	end
	if session then
		session.Saving = false
	end
	return true
end

function DataService.IsEnabled(): boolean
	return store ~= nil
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.StoreName)
	end)
	if ok and RunService:IsStudio() then
		-- in Studio the store object exists even without API access; one test read tells
		ok, result = pcall(function()
			result:GetAsync("access_check")
			return result
		end)
	end
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, stats are NOT saved this session (" .. tostring(result) .. ")."
			.. " Publish the place and enable Game Settings > Security > Enable Studio Access to API Services.")
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveSeconds)
			for player, session in sessions do
				task.spawn(save, player, session)
			end
		end
	end)

	game:BindToClose(function()
		local running = 0
		for player, session in sessions do
			running += 1
			task.spawn(function()
				local deadline = os.clock() + 10
				while session.Saving and os.clock() < deadline do
					task.wait(0.2)
				end
				save(player, session)
				running -= 1
			end)
		end
		local deadline = os.clock() + 25
		while running > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
