local waypoints = {}

function WorldforgedItemTracker:CreateWaypoint(itemid, continent, zone, x, y, source)
	if waypoints[itemid] and waypoints[itemid].Hide then
		waypoints[itemid]:Hide()
	end

	WorldforgedDB.waypoints_db[zone][itemid] = {
		continent = continent,
		zone = zone,
		x = x,
		y = y,
		source = source,
		itemid = itemid,
	}
	local waypoint = CreateFrame("Button", nil, ItemTrackerOverlay)
	waypoint:SetHeight(12)
	waypoint:SetWidth(12)
	waypoint:RegisterForClicks("RightButtonUp")
	waypoint.icon = waypoint:CreateTexture("ARTWORK")
	waypoint.icon:SetAllPoints()
	waypoint.icon:SetTexture("Interface\\AddOns\\WorldforgedItemTracker\\Images\\GoldGreenDot")

	waypoint.itemid = itemid
	waypoint.zoneid = zone

	waypoints[itemid] = waypoint

	waypoint:RegisterEvent("WORLD_MAP_UPDATE")
	waypoint:SetScript("OnEvent", World_OnEvent)

	waypoint:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetParent(self)

		GameTooltip:SetFrameStrata("TOOLTIP")
		local link = "item:" .. self.itemid .. ":0:0:0:0:0:0:0"
		GameTooltip:SetHyperlink(link)
		local data = WorldforgedDB.waypoints_db[self.itemid]
		if data and data.source then
			local sourceText
			if data.source.type == "QUEST" then
				sourceText = "Quest: " .. data.source.name
			elseif data.source.type == "CORPSE" then
				sourceText = "Mob: " .. data.source.name
			elseif data.source.type == "CONTAINER" then
				sourceText = "Container: " .. data.source.name
			else
				sourceText = "Unknown: " .. tostring(data.source)
			end
			GameTooltip:AddLine(sourceText, 1, 0.82, 0, true)
		end
		GameTooltip:Show()
	end)
	waypoint:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		GameTooltip:SetParent(UIParent)
		GameTooltip:SetFrameStrata("TOOLTIP")
	end)

	waypoint:SetScript("OnClick", function(self)
		local data = WorldforgedDB.waypoints_db[self.itemid]
		WorldforgedItemTracker:SendWaypoint(
			self.itemid,
			data.continent,
			data.zone,
			data.x,
			data.y,
			data.source,
			"PARTY"
		)
	end)

	WorldforgedItemTracker:PlaceIconOnWorldMap(ItemTrackerOverlay, waypoint, continent, zone, x, y)
	waypoint:Show()
end

function WorldforgedItemTracker:DeleteWaypoint(itemid)
	if not itemid or not WorldforgedDB.waypoints_db[itemid] then
		return
	end
	local waypoint = WorldforgedDB.waypoints_db[itemid].waypoint
	waypoint:UnregisterEvent("WORLD_MAP_UPDATE")
	waypoint:SetScript("OnEvent", nil)
	waypoint:Hide()

	WorldforgedDB.waypoints_db[itemid] = nil
end

function WorldforgedItemTracker:GetWaypoint(zone, itemid)
	return WorldforgedDB.waypoints_db[zone][itemid]
end

function WorldforgedItemTracker:InitializeWaypoints()
	WorldforgedDB.waypoints_db = WorldforgedDB.waypoints_db or {}

	-- Convert from old flat format if needed
	local needsConversion = false
	for key, value in pairs(WorldforgedDB.waypoints_db) do
		if type(key) == "number" and type(value) == "table" and value.zone then
			needsConversion = true
			break
		end
	end

	if needsConversion then
		local new_db = {}
		for itemid, data in pairs(WorldforgedDB.waypoints_db) do
			local zoneid = data.zone or 0
			new_db[zoneid] = new_db[zoneid] or {}
			new_db[zoneid][itemid] = data
		end
		WorldforgedDB.waypoints_db = new_db
	end

	if not ItemTrackerOverlay then
		local overlay = CreateFrame("Frame", "ItemTrackerOverlay", WorldMapButton)
		overlay:SetAllPoints(true)
	end

	-- Updated iteration: zoneid -> itemid -> data
	for zoneid, items in pairs(WorldforgedDB.waypoints_db) do
		for itemid, data in pairs(items) do
			if type(data.source) == "string" then
				data.source = { type = "CONTAINER", name = data.source }
			end

			self:CreateWaypoint(itemid, data.continent, data.zone, data.x, data.y, data.source)
		end
	end
end

function WorldforgedItemTracker:AddItem(itemid, source, continent, zone, x, y, high_prio)
	if WorldforgedDB.waypoints_db[itemid] then
		return
	end

	self:CreateWaypoint(itemid, continent, zone, x, y, source)
	self:SendWaypoint(itemid, continent, zone, x, y, source, "PARTY", nil, high_prio) -- Only send to party for now
end

function World_OnEvent(self, event, ...)
	if event == "WORLD_MAP_UPDATE" then
		local data = WorldforgedItemTracker:GetWaypoint(self.zoneid, self.itemid)
		local x, y = WorldforgedItemTracker:PlaceIconOnWorldMap(
			ItemTrackerOverlay,
			self,
			data.continent,
			data.zone,
			data.x,
			data.y
		)
		-- if x and y and (0 < x and x <= 1) and (0 < y and y <= 1) then
		-- 	self:Show()
		-- else
		-- 	self:Hide()
		-- end
	end
end
