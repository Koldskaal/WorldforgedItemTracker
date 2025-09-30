local PREFIX = "WFI"
-- LOG LEVELS:
-- 1: INFO - Important events and status changes.
-- 2: DEBUG - Detailed, potentially spammy messages for debugging.
local LOG_LEVEL_NONE = -1
local LOG_LEVEL_INFO = 1
local LOG_LEVEL_DEBUG = 2
local LOG_LEVEL = LOG_LEVEL or LOG_LEVEL_NONE

local wait_start = 0
local wait_timeout = 2

local sync_state = "IDLE" -- or "WAITING","SENDING"
local item_queue = {}
local seen_items = {}
local sync_queue = {}

-- Sync progress tracking
local total_items_to_sync = 0
local items_synced_count = 0

-- Election
local election_active = false
local election_rolls = {}
local election_timer = 0
local election_timeout = 3
local addon_leader = nil

-- ########################
-- Debug utility
-- ########################
local function DebugMsg(msg, color, chat, level)
	level = level or LOG_LEVEL_DEBUG
	if level > LOG_LEVEL then
		return
	end

	color = color or "00ff00" -- default green
	local text = "|cff" .. color .. "[WFI]|r " .. msg
	print(text)

	if chat then
		SendChatMessage("[WFI] " .. msg, chat)
	end
end

-- ########################
-- Group handling
-- ########################
local function IsMyselfLeader()
	return addon_leader == UnitName("player")
end

local function GetPartyMembers()
	local members = {}
	for i = 1, GetNumPartyMembers() do
		local name = UnitName("party" .. i)
		if name then
			table.insert(members, name)
		end
	end

	local name = UnitName("player")
	table.insert(members, name)
	return members
end
-- ########################
-- World Map Progress Display
-- ########################
function WorldforgedItemTracker:EnsureMapProgressText()
	if self.mapSyncText then
		return
	end

	local f = CreateFrame("Frame", nil, WorldMapButton)
	f:SetSize(200, 20)
	f:SetPoint("TOPLEFT", WorldMapButton, "TOPLEFT", 30, -30)
	f:SetFrameStrata("TOOLTIP") -- above everything in map

	local syncText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	syncText:SetAllPoints(f)
	syncText:SetJustifyH("LEFT")
	syncText:SetTextColor(1, 0, 0, 1) -- bright red
	syncText:SetText("SYNC TEST")
	syncText:Show()

	self.mapSyncText = syncText
end
-- Attach on-show hook just once
WorldMapButton:HookScript("OnShow", function()
	WorldforgedItemTracker:EnsureMapProgressText()
	WorldforgedItemTracker:UpdateProgressText()
end)

function WorldforgedItemTracker:UpdateProgressText()
	self:EnsureMapProgressText()

	if total_items_to_sync > 0 then
		self.mapSyncText:SetText(string.format("WFI Sync: %d / %d", items_synced_count, total_items_to_sync))
	else
		self.mapSyncText:SetText("")
	end
end

-- ########################
-- Waypoint handling
-- ########################
function WorldforgedItemTracker:SendWaypoint(itemid, continent, zone, x, y, source, channel, target, high_prio)
	if not WorldforgedDB.sharing_enabled then
		return
	end

	local KEY_STRING = "ITEM"
	if high_prio then
		KEY_STRING = "OTEM"
	end
	local sourceString = string.format("%s|%s", source.type, source.name)
	local msg = string.format("%s:%d;%d;%d;%.4f;%.4f;%s", KEY_STRING, itemid, continent, zone, x, y, sourceString)
	SendAddonMessage(PREFIX, msg, channel, target)
	DebugMsg(
		"Sending ITEM "
			.. itemid
			.. " ("
			.. continent
			.. ","
			.. zone
			.. ","
			.. x
			.. ","
			.. y
			.. ") to "
			.. tostring(channel),
		"ff5500",
		nil,
		LOG_LEVEL_DEBUG
	)
end

function WorldforgedItemTracker:OnWaypointReceived(sender, itemid, continent, zone, x, y, source, high_prio)
	DebugMsg(
		"Received waypoint "
			.. itemid
			.. " from "
			.. sender
			.. string.format(" (c=%d z=%d x=%.2f y=%.2f)", continent, zone, x, y),
		"00ffff",
		nil,
		LOG_LEVEL_DEBUG
	)

	-- Ensure zone table exists
	WorldforgedDB.waypoints_db[zone] = WorldforgedDB.waypoints_db[zone] or {}
	local zoneTable = WorldforgedDB.waypoints_db[zone]

	if not zoneTable[itemid] or high_prio then
		self:CreateWaypoint(itemid, continent, zone, x, y, source)
	end

	-- mark seen per-zone+item
	seen_items[zone] = seen_items[zone] or {}
	seen_items[zone][itemid] = true
end

-- ########################
-- Main Init
-- ########################
function WorldforgedItemTracker:InitializeSharing()
	self.frame = CreateFrame("Frame", nil, UIParent)

	-- Addon communication
	local f = CreateFrame("Frame")
	f:RegisterEvent("CHAT_MSG_ADDON")
	f:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
		if not WorldforgedDB.sharing_enabled or prefix ~= PREFIX then
			return
		end

		if message:find("^LEADER:") then
			if addon_leader then
				return
			end
			addon_leader = message:match("^LEADER:(.+)")
			self.frame:SetScript("OnUpdate", nil) -- always cancel election
			if GetNumPartyMembers() > 0 and IsMyselfLeader() then
				sync_queue = GetPartyMembers()
				DebugMsg("I am leader, queuing " .. #sync_queue .. " members for sync", "ffffaa", nil, LOG_LEVEL_INFO)
			end
			return
		end

		if sender == UnitName("player") then
			return
		end

		wait_start = GetTime() -- any ping is fine

		if message == "SYNC_REQUEST" then
			DebugMsg("Got SYNC_REQUEST from " .. sender, "ffff00", nil, LOG_LEVEL_DEBUG)
			WorldforgedItemTracker:SendSummary()
		elseif message:find("^SYNC_START:") then
			local count = tonumber(message:match("^SYNC_START:(%d+)"))
			if count then
				total_items_to_sync = count
				items_synced_count = 0
				DebugMsg("Receiving " .. count .. " waypoints from " .. sender, "00ff00", nil, LOG_LEVEL_INFO)
				if count == 0 then
					DebugMsg("Sync with " .. sender .. " complete: 0 items.", "00ff00", nil, LOG_LEVEL_INFO)
				end
			end
		elseif message:find("^ITEM:") then
			DebugMsg("Got ITEM from " .. sender, "00ff88", nil, LOG_LEVEL_DEBUG)
			local itemid, continent, zone, x, y, source =
				message:match("^ITEM:(%d+);(%d+);(%d+);([%d%.]+);([%d%.]+);(.+)")
			if itemid then
				if sync_state == "WAITING" then
					items_synced_count = items_synced_count + 1
					self:UpdateProgressText()
					DebugMsg(
						"Sync progress: " .. items_synced_count .. "/" .. total_items_to_sync .. " from " .. sender,
						"00ff00",
						nil,
						LOG_LEVEL_DEBUG
					)
					if items_synced_count >= total_items_to_sync then
						DebugMsg("Sync with " .. sender .. " complete.", "00ff00", nil, LOG_LEVEL_INFO)
						sync_state = "IDLE"
						total_items_to_sync = 0
						self:UpdateProgressText()
					end
				end

				local sourceType, sourceName = source:match("([^,]+)|(.+)")
				local sourceObj = { type = sourceType, name = sourceName }
				WorldforgedItemTracker:OnWaypointReceived(
					sender,
					tonumber(itemid),
					tonumber(continent),
					tonumber(zone),
					tonumber(x),
					tonumber(y),
					sourceObj
				)
			end
		elseif message:find("^OTEM:") then
			DebugMsg("Got overwrite ITEM from " .. sender, "00ff88", nil, LOG_LEVEL_DEBUG)
			local itemid, continent, zone, x, y, source =
				message:match("^OTEM:(%d+);(%d+);(%d+);([%d%.]+);([%d%.]+);(.+)")
			if itemid then
				local sourceType, sourceName = source:match("([^,]+)|(.+)")
				local sourceObj = { type = sourceType, name = sourceName }
				WorldforgedItemTracker:OnWaypointReceived(
					sender,
					tonumber(itemid),
					tonumber(continent),
					tonumber(zone),
					tonumber(x),
					tonumber(y),
					sourceObj,
					true
				)
			end
		elseif message:find("^ELECT:") then
			local roll = tonumber(message:match("^ELECT:(%d+)"))
			if roll then
				election_rolls[sender] = roll
				DebugMsg("Received roll " .. roll .. " from " .. sender, "aaaa00", nil, LOG_LEVEL_INFO)
			end
		end
	end)

	local party_frame = CreateFrame("Frame")
	party_frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	party_frame:RegisterEvent("PARTY_LEADER_CHANGED")
	party_frame:RegisterEvent("RAID_ROSTER_UPDATE")
	party_frame:RegisterEvent("PLAYER_ENTERING_WORLD")

	party_frame:SetScript("OnEvent", function(_, event)
		if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
			WorldforgedItemTracker:OnGroupChanged()
			-- elseif event == "PLAYER_ENTERING_WORLD" then
			-- 	WorldforgedItemTracker:OnGroupChanged()
		end
	end)

	party_frame:SetScript("OnUpdate", function(_, elapsed)
		if not WorldforgedDB.sharing_enabled then
			return
		end

		if sync_state ~= "IDLE" then
			if sync_state == "WAITING" and GetTime() - wait_start > wait_timeout then
				DebugMsg("WAITING timed out", "ff4444", nil, LOG_LEVEL_INFO)
				sync_state = "IDLE"
			end
			return
		end

		if #sync_queue > 0 then
			local target = sync_queue[1]
			DebugMsg("Sending SYNC_REQUEST to " .. target, "ffffff", nil, LOG_LEVEL_DEBUG)
			if target == UnitName("player") then
				WorldforgedItemTracker:SendSummary()
			else
				SendAddonMessage(PREFIX, "SYNC_REQUEST", "WHISPER", target)
				sync_state = "WAITING"
			end

			table.remove(sync_queue, 1)
			wait_start = GetTime()
		end
	end)
end

-- ########################
-- Summary sending
-- ########################
function WorldforgedItemTracker:SendSummary()
	local ids = {}

	for zoneid, items in pairs(WorldforgedDB.waypoints_db or {}) do
		for itemid in pairs(items) do
			if not (seen_items[zoneid] and seen_items[zoneid][itemid]) then
				table.insert(ids, { zoneid = zoneid, itemid = itemid })
			end
		end
	end

	item_queue = ids
	sync_state = "SENDING"

	local count = #item_queue
	SendAddonMessage(PREFIX, "SYNC_START:" .. count, "PARTY")
	total_items_to_sync = count

	DebugMsg("Sending " .. count .. " ITEMS to party", "00ffcc", nil, LOG_LEVEL_INFO)
	self.frame:SetScript("OnUpdate", self.OnItemSending)
end

function WorldforgedItemTracker.OnItemSending(frame, elapsed)
	local self = WorldforgedItemTracker
	self._itemTick = (self._itemTick or 0) + elapsed
	if self._itemTick >= 0.1 then
		self._itemTick = 0
		if item_queue and #item_queue > 0 then
			local entry = item_queue[1]
			local itemid = tonumber(entry.itemid)
			local zoneid = tonumber(entry.zoneid)

			if itemid and zoneid then
				local zoneTable = WorldforgedDB.waypoints_db[zoneid]
				local data = zoneTable and zoneTable[itemid]
				if data then
					DebugMsg("Sending ITEM " .. itemid .. " (zone " .. zoneid .. ")", "ff0000", nil, LOG_LEVEL_DEBUG)
					self:SendWaypoint(itemid, data.continent, zoneid, data.x, data.y, data.source, "PARTY")
				end
			end
			table.remove(item_queue, 1)
		else
			DebugMsg("Finished ITEM queue", "00cc00", nil, LOG_LEVEL_INFO)
			sync_state = "IDLE"
			frame:SetScript("OnUpdate", nil)
		end
		items_synced_count = total_items_to_sync - #item_queue
		self:UpdateProgressText()
		if items_synced_count == total_items_to_sync then
			total_items_to_sync = 0
		end
	end
end

function WorldforgedItemTracker:CancelSync(reason)
	sync_state = "IDLE"
	item_queue = {}
	seen_items = {}
	sync_queue = {}
	total_items_to_sync = 0
	items_synced_count = 0
	self.frame:SetScript("OnUpdate", nil)
	DebugMsg("Sync cancelled: " .. (reason or "group changed"), "ff4444", nil, LOG_LEVEL_INFO)
end

function WorldforgedItemTracker:OnGroupChanged()
	if not WorldforgedDB.sharing_enabled then
		return
	end

	if sync_state ~= "IDLE" then
		self:CancelSync("group changed")
		return
	end

	addon_leader = nil

	-- Reset candidate rolls
	election_active = true
	election_rolls = {}
	election_timer = 0
	local myRoll = math.random(1, 10000)
	election_rolls[UnitName("player")] = myRoll
	SendAddonMessage(PREFIX, "ELECT:" .. myRoll, "PARTY")

	DebugMsg("Starting election with roll " .. myRoll, "ffffaa", nil, LOG_LEVEL_INFO)

	-- Frame timer
	self.frame:SetScript("OnUpdate", self.OnElectionUpdate)

	DebugMsg(
		"Group members: " .. GetNumPartyMembers() .. ", Is leader: " .. tostring(IsMyselfLeader()),
		nil,
		nil,
		LOG_LEVEL_DEBUG
	)
end

-- Election
function WorldforgedItemTracker.OnElectionUpdate(_, elapsed)
	if not election_active then
		return
	end

	election_timer = election_timer + elapsed
	if election_timer >= election_timeout then
		election_active = false
		WorldforgedItemTracker.frame:SetScript("OnUpdate", nil)

		local winner, bestRoll = "", -1
		for name, roll in pairs(election_rolls) do
			if roll > bestRoll or (roll == bestRoll and name < winner) then
				winner = name
				bestRoll = roll
			end
		end

		if winner then
			DebugMsg("Election complete. Leader = " .. winner .. " (roll=" .. bestRoll .. ")", "00ffcc")
			SendAddonMessage(PREFIX, "LEADER:" .. winner, "PARTY")
		else
			DebugMsg("Election failed, no rolls received.", "ff0000")
		end
	end
end
