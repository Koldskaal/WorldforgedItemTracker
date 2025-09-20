local PREFIX = "WFI"
local LOG_LEVEL = LOG_LEVEL or 1 -- INFO

local wait_start = 0
local wait_timeout = 2

WorldforgedItemTracker.syncState = "IDLE" -- or "WAITING","SENDING"
WorldforgedItemTracker.itemQueue = {}
WorldforgedItemTracker.seen_items = {}
WorldforgedItemTracker.sync_queue = {}

if RegisterAddonMessagePrefix then
	RegisterAddonMessagePrefix(PREFIX)
end

-- ########################
-- Debug utility
-- ########################
local function DebugMsg(msg, color, chat, level)
	color = color or "00ff00" -- default green
	local text = "|cff" .. color .. "[WFI]|r " .. msg
	-- if not level then
	-- 	level = 2
	-- end
	-- if level > LOG_LEVEL then
	-- 	return
	-- end
	print(text)

	if chat then
		SendChatMessage("[WFI] " .. msg, chat)
	end
end

-- ########################
-- Waypoint handling
-- ########################
function WorldforgedItemTracker:SendWaypoint(itemid, continent, zone, x, y, source, channel, target, high_prio)
	local KEY_STRING = "ITEM"
	if high_prio then
		KEY_STRING = "OTEM"
	end
	local msg = string.format("%s:%d;%d;%d;%.4f;%.4f;%s", KEY_STRING, itemid, continent, zone, x, y, source)
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
			.. tostring(target),
		"ff5500"
	)
end

function WorldforgedItemTracker:OnWaypointReceived(sender, itemid, continent, zone, x, y, source, high_prio)
	DebugMsg(
		"Received waypoint "
			.. itemid
			.. " from "
			.. sender
			.. string.format(" (c=%d z=%d x=%.2f y=%.2f)", continent, zone, x, y),
		"00ffff"
	)

	if not WorldforgedDB.waypoints_db[itemid] or high_prio then
		self:CreateWaypoint(itemid, continent, zone, x, y, source)
	end
	self.seen_items[itemid] = true
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
		if prefix ~= PREFIX then
			return
		end

		wait_start = GetTime() -- any ping is fine

		if message == "SYNC_REQUEST" then
			DebugMsg("Got SYNC_REQUEST from " .. sender, "ffff00")
			WorldforgedItemTracker:SendSummary(sender)
		end

		if message:find("^ITEM:") then
			DebugMsg("Got ITEM from " .. sender, "00ff88")
			local itemid, continent, zone, x, y, source =
				message:match("^ITEM:(%d+);(%d+);(%d+);([%d%.]+);([%d%.]+);(%w+)")
			if itemid then
				WorldforgedItemTracker:OnWaypointReceived(
					sender,
					tonumber(itemid),
					tonumber(continent),
					tonumber(zone),
					tonumber(x),
					tonumber(y),
					source
				)
			end
		end

		if message:find("^OTEM:") then
			DebugMsg("Got overwrite ITEM from " .. sender, "00ff88")
			local itemid, continent, zone, x, y, source =
				message:match("^OTEM:(%d+);(%d+);(%d+);([%d%.]+);([%d%.]+);(%w+)")
			if itemid then
				WorldforgedItemTracker:OnWaypointReceived(
					sender,
					tonumber(itemid),
					tonumber(continent),
					tonumber(zone),
					tonumber(x),
					tonumber(y),
					source,
					true
				)
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
		elseif event == "PLAYER_ENTERING_WORLD" then
			WorldforgedItemTracker:OnGroupChanged()
		end
	end)

	party_frame:SetScript("OnUpdate", function(_, elapsed)
		if WorldforgedItemTracker.syncState ~= "IDLE" then
			if WorldforgedItemTracker.syncState == "WAITING" and GetTime() - wait_start > wait_timeout then
				DebugMsg("WAITING timed out", "ff4444")
				WorldforgedItemTracker.syncState = "IDLE"
			end
			return
		end

		if #WorldforgedItemTracker.sync_queue > 0 then
			local target = WorldforgedItemTracker.sync_queue[1]
			DebugMsg("Sending SYNC_REQUEST to " .. target, "ffffff")
			if target == UnitName("player") then
				WorldforgedItemTracker:SendSummary()
			else
				SendAddonMessage(PREFIX, "SYNC_REQUEST", "WHISPER", target)
				WorldforgedItemTracker.syncState = "WAITING"
			end

			table.remove(WorldforgedItemTracker.sync_queue, 1)
			wait_start = GetTime()
		end
	end)
end

-- ########################
-- Summary sending
-- ########################
function WorldforgedItemTracker:SendSummary()
	local ids = {}
	for itemid in pairs(WorldforgedDB.waypoints_db or {}) do
		if not self.seen_items[itemid] then
			table.insert(ids, tostring(itemid))
		end
	end
	self.itemQueue = ids
	self.syncState = "SENDING"
	DebugMsg("Sending " .. #ids .. " ITEMS", "00ffcc")
	self.frame:SetScript("OnUpdate", self.OnItemSending)
end

function WorldforgedItemTracker.OnItemSending(frame, elapsed)
	local self = WorldforgedItemTracker
	self._itemTick = (self._itemTick or 0) + elapsed
	if self._itemTick >= 0.1 then
		self._itemTick = 0
		if self.itemQueue and #self.itemQueue > 0 then
			local itemid = tonumber(self.itemQueue[1])
			if itemid then
				local data = WorldforgedDB.waypoints_db[itemid]
				if data then
					DebugMsg("Sending ITEM " .. itemid, "ff0000")
					self:SendWaypoint(itemid, data.continent, data.zone, data.x, data.y, data.source, "PARTY")
				end
			end
			table.remove(self.itemQueue, 1)
		else
			DebugMsg("Finished ITEM queue", "00cc00")
			self.syncState = "IDLE"
			frame:SetScript("OnUpdate", nil)
		end
	end
end

-- ########################
-- Group handling
-- ########################
local function IsMyselfLeader()
	if GetNumRaidMembers() > 0 then
		return IsRaidLeader()
	elseif GetNumPartyMembers() > 0 then
		return UnitIsPartyLeader("player")
	else
		return true
	end
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

function WorldforgedItemTracker:CancelSync(reason)
	self.syncState = "IDLE"
	self.itemQueue = {}
	self.seen_items = {}
	self.sync_queue = {}
	self.frame:SetScript("OnUpdate", nil)
	DebugMsg("Sync cancelled: " .. (reason or "group changed"), "ff4444")
end

function WorldforgedItemTracker:OnGroupChanged()
	if self.syncState ~= "IDLE" then
		self:CancelSync("group changed")
		return
	end
	print("GetNumPartyMembers", GetNumPartyMembers(), IsMyselfLeader())
	if GetNumPartyMembers() > 0 and IsMyselfLeader() then
		self.sync_queue = GetPartyMembers()
		DebugMsg("Group changed, I am leader, queuing " .. #self.sync_queue .. " members for sync", "ffffaa")
	end
end
