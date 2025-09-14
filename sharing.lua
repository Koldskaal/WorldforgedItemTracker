local PREFIX = "WFI"

WorldforgedItemTracker.syncState = "IDLE" -- or "WAITING","SENDING"
WorldforgedItemTracker.syncTarget = nil
WorldforgedItemTracker.summaryQueue = {}
WorldforgedItemTracker.requestQueue = {}
WorldforgedItemTracker.itemQueue = {}
WorldforgedItemTracker.sync_queue = {}
WorldforgedItemTracker.sender_items = {}

if RegisterAddonMessagePrefix then
	RegisterAddonMessagePrefix(PREFIX)
end

-- ########################
-- Debug utility
-- ########################
local function DebugMsg(msg, color, chat)
	color = color or "00ff00" -- default green
	local text = "|cff" .. color .. "[WFI]|r " .. msg
	print(text)

	if chat then
		SendChatMessage("[WFI] " .. msg, chat)
	end
end

-- ########################
-- Waypoint handling
-- ########################
function WorldforgedItemTracker:SendWaypoint(itemid, continent, zone, x, y, channel, target)
	print(itemid, continent, zone, x, y, target)
	local msg = string.format("ITEM:%d;%d;%d;%.4f;%.4f", itemid, continent, zone, x, y)
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

function WorldforgedItemTracker:OnWaypointReceived(sender, itemid, continent, zone, x, y)
	DebugMsg(
		"Received waypoint "
			.. itemid
			.. " from "
			.. sender
			.. string.format(" (c=%d z=%d x=%.2f y=%.2f)", continent, zone, x, y),
		"00ffff"
	)

	if not WorldforgedDB.waypoints_db[itemid] then
		if self.CreateWaypoint then
			self:CreateWaypoint(itemid, continent, zone, x, y)
		end
	end
end

-- ########################
-- Utility
-- ########################
local function SplitString(str, sep)
	local results = {}
	for part in string.gmatch(str, "([^" .. sep .. "]+)") do
		table.insert(results, part)
	end
	return results
end

local wait_start = 0
local wait_timeout = 5

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
			local itemid, continent, zone, x, y = message:match("^ITEM:(%d+);(%d+);(%d+);([%d%.]+);([%d%.]+)")
			if itemid then
				WorldforgedItemTracker:OnWaypointReceived(
					sender,
					tonumber(itemid),
					tonumber(continent),
					tonumber(zone),
					tonumber(x),
					tonumber(y)
				)
			end
		end

		if message:find("^IDS:") then
			DebugMsg("Got IDS chunk from " .. sender, "aaaaaa")
			local ids = message:match("^IDS:(.+)")
			if ids then
				for _, id in ipairs(SplitString(ids, ",")) do
					id = tonumber(id)
					if id then
						WorldforgedItemTracker.sender_items[sender] = WorldforgedItemTracker.sender_items[sender] or {}
						table.insert(WorldforgedItemTracker.sender_items[sender], id)
						if not WorldforgedDB.waypoints_db[id] then
							table.insert(WorldforgedItemTracker.requestQueue, tostring(id))
						end
					end
				end
			end
		end

		if message:find("^REQ:") then
			DebugMsg("Got REQ from " .. sender, "ff8800")
			local ids = message:match("^REQ:(.+)")
			WorldforgedItemTracker.syncState = "IDLE"
			if ids then
				for _, id in ipairs(SplitString(ids, ",")) do
					id = tonumber(id)
					if id then
						if WorldforgedDB.waypoints_db[id] then
							table.insert(WorldforgedItemTracker.itemQueue, id)
						end
					end
				end
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
		elseif event == "PARTY_LEADER_CHANGED" then
			WorldforgedItemTracker:OnLeaderChanged()
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

		if #WorldforgedItemTracker.requestQueue > 0 then
			DebugMsg("QueueRequest with " .. #WorldforgedItemTracker.requestQueue .. " ids", "00ffcc")
			WorldforgedItemTracker.syncState = "SENDING"
			WorldforgedItemTracker:QueueRequest()
		end

		if #WorldforgedItemTracker.itemQueue > 0 then
			DebugMsg("QueueItemSending with " .. #WorldforgedItemTracker.itemQueue .. " items", "ffcc00")
			WorldforgedItemTracker.syncState = "SENDING"
			WorldforgedItemTracker:QueueItemSending()
		end

		if #WorldforgedItemTracker.sync_queue > 0 then
			local target = WorldforgedItemTracker.sync_queue[1]
			DebugMsg("Sending SYNC_REQUEST to " .. target, "ffffff")
			SendAddonMessage(PREFIX, "SYNC_REQUEST", "WHISPER", target)
			WorldforgedItemTracker.syncState = "WAITING"
			WorldforgedItemTracker.syncTarget = target
			table.remove(WorldforgedItemTracker.sync_queue, 1)
			wait_start = GetTime()
		end

		if #WorldforgedItemTracker.sender_items > 0 then
			local function contains(tbl, val)
				for i = 1, #tbl do
					if tonumber(tbl[i]) == tonumber(val) then
						return true
					end
				end
				return false
			end
			for itemid, _ in pairs(WorldforgedDB.waypoints_db) do
				for sender, _ in pairs(WorldforgedItemTracker.sender_items) do
					if contains(WorldforgedItemTracker.sender_items[sender], itemid) then
						print("SKIP")
					else
						table.insert(WorldforgedItemTracker.sender_items[sender], itemid)
					end
				end
			end
		end
	end)
end

-- ########################
-- Summary sending
-- ########################
function WorldforgedItemTracker:SendSummary(target)
	local ids = {}
	for itemid in pairs(WorldforgedDB.waypoints_db or {}) do
		table.insert(ids, tostring(itemid))
	end
	self.summaryQueue = ids
	self.syncTarget = target
	DebugMsg("Sending SUMMARY to " .. target .. " with " .. #ids .. " ids", "00ffcc")
	self.frame:SetScript("OnUpdate", self.SummaryOnUpdate)
end

function WorldforgedItemTracker.SummaryOnUpdate(frame, elapsed)
	local self = WorldforgedItemTracker
	self._sumTick = (self._sumTick or 0) + elapsed
	if self._sumTick >= 0.1 then
		self._sumTick = 0
		if self.summaryQueue and #self.summaryQueue > 0 then
			local buffer, chunkSize = "", 200
			for i = #self.summaryQueue, 1, -1 do
				local key = self.summaryQueue[i]
				if #buffer + #key + 1 > chunkSize then
					break
				end
				buffer = (buffer == "") and key or (buffer .. "," .. key)
				table.remove(self.summaryQueue, i)
			end
			if #buffer > 0 then
				DebugMsg("Sending IDS chunk to " .. tostring(self.syncTarget) .. " (" .. #buffer .. " chars)", "cccccc")
				SendAddonMessage(PREFIX, "IDS:" .. buffer, "WHISPER", self.syncTarget)
			end
		else
			DebugMsg("Finished sending SUMMARY", "00ff00")
			frame:SetScript("OnUpdate", nil)
		end
	end
end

-- ########################
-- Request sending
-- ########################
function WorldforgedItemTracker:QueueRequest()
	self.frame:SetScript("OnUpdate", self.OnRequestUpdate)
end

function WorldforgedItemTracker.OnRequestUpdate(frame, elapsed)
	local self = WorldforgedItemTracker
	self._reqTick = (self._reqTick or 0) + elapsed
	if self._reqTick >= 0.1 then
		self._reqTick = 0
		if self.requestQueue and #self.requestQueue > 0 then
			local buffer, chunkSize = "", 200
			for i = #self.requestQueue, 1, -1 do
				local key = self.requestQueue[i]
				if #buffer + #key + 1 > chunkSize then
					break
				end
				buffer = (buffer == "") and key or (buffer .. "," .. key)
				table.remove(self.requestQueue, i)
			end
			DebugMsg("Sending REQ chunk for " .. buffer, "ff00ff")
			SendAddonMessage(PREFIX, "REQ:" .. buffer, "WHISPER", self.syncTarget)
		else
			self.syncState = "WAITING"
			DebugMsg("Finished REQ queue, now WAITING", "aaaaaa")
			frame:SetScript("OnUpdate", nil)
		end
	end
end

-- ########################
-- Item sending
-- ########################
function WorldforgedItemTracker:QueueItemSending()
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
					DebugMsg("Sending ITEM " .. itemid .. " to " .. tostring(self.syncTarget), "ff0000")
					self:SendWaypoint(itemid, data.continent, data.zone, data.x, data.y, "WHISPER", self.syncTarget)
				end
			end
			table.remove(self.itemQueue, 1)
		else
			DebugMsg("Finished ITEM queue", "00cc00")
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
	return members
end

function WorldforgedItemTracker:CancelSync(reason)
	self.syncState = "IDLE"
	self.syncTarget = nil
	self.summaryQueue = {}
	self.requestQueue = {}
	self.itemQueue = {}
	self.sync_queue = {}
	self.frame:SetScript("OnUpdate", nil)
	DebugMsg("Sync cancelled: " .. (reason or "group changed"), "ff4444")
end

function WorldforgedItemTracker:OnGroupChanged()
	if self.syncState ~= "IDLE" then
		self:CancelSync("group changed")
		return
	end
	if GetNumPartyMembers() > 0 and IsMyselfLeader() then
		self.sync_queue = GetPartyMembers()
		DebugMsg("Group changed, I am leader, queuing " .. #self.sync_queue .. " members for sync", "ffffaa")
	end
end

function WorldforgedItemTracker:OnLeaderChanged()
	if self.syncState ~= "IDLE" then
		self:CancelSync("leader changed")
		return
	end
	if GetNumPartyMembers() > 0 and IsMyselfLeader() then
		self.sync_queue = GetPartyMembers()
		DebugMsg("Leader changed, I am leader, queuing " .. #self.sync_queue .. " members for sync", "ffffaa")
	end
end

