local waypoints = {}

function WorldforgedItemTracker:CreateWaypoint(itemid, continent, zone, x, y, source)
	if waypoints[zone] and waypoints[zone][itemid] then
		waypoints[zone][itemid]:Hide()
	end

	WorldforgedDB.waypoints_db[zone] = WorldforgedDB.waypoints_db[zone] or {}
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
	waypoint:RegisterForClicks("RightButtonUp", "LeftButtonUp")
	waypoint.icon = waypoint:CreateTexture("ARTWORK")
	waypoint.icon:SetAllPoints()
	waypoint.icon:SetTexture("Interface\\AddOns\\WorldforgedItemTracker\\Images\\GoldGreenDot")

	waypoint.itemid = itemid
	waypoint.zoneid = zone

	waypoints[zone] = waypoints[zone] or {}
	waypoints[zone][itemid] = waypoint

	waypoint:RegisterEvent("WORLD_MAP_UPDATE")
	waypoint:SetScript("OnEvent", World_OnEvent)

	waypoint:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetParent(self)

		GameTooltip:SetFrameStrata("TOOLTIP")
		local link = "item:" .. self.itemid .. ":0:0:0:0:0:0:0"
		GameTooltip:SetHyperlink(link)
		local data = WorldforgedDB.waypoints_db[self.zoneid][self.itemid]
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

	waypoint:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			StaticPopup_Show("WFI_DELETE_WAYPOINT", nil, nil, { zoneid = self.zoneid, itemid = self.itemid })
		else
			WorldforgedDBPerChar[self.zoneid] = WorldforgedDBPerChar[self.zoneid] or {}
			-- Assume left click = track/untrack pickup
			WorldforgedDBPerChar[self.zoneid][self.itemid] = not WorldforgedDBPerChar[self.zoneid][self.itemid]
			self.icon:SetDesaturated(WorldforgedDBPerChar[self.zoneid][self.itemid])
		end
	end)

	WorldforgedItemTracker:PlaceIconOnWorldMap(ItemTrackerOverlay, waypoint, continent, zone, x, y)
	waypoint:Show()
end

function WorldforgedItemTracker:DeleteWaypoint(zoneid, itemid)
	if not itemid or not zoneid then
		return
	end
	if not WorldforgedDB.waypoints_db[zoneid] then
		return
	end
	if not WorldforgedDB.waypoints_db[zoneid][itemid] then
		return
	end

	local waypoint = waypoints[zoneid] and waypoints[zoneid][itemid]
	if waypoint then
		waypoint:UnregisterEvent("WORLD_MAP_UPDATE")
		waypoint:SetScript("OnEvent", nil)
		waypoint:Hide()
		waypoints[zoneid][itemid] = nil
	end

	WorldforgedDB.waypoints_db[zoneid][itemid] = nil
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
	if WorldforgedDB.waypoints_db[zone][itemid] then
		return
	end

	self:CreateWaypoint(itemid, continent, zone, x, y, source)
	self:SendWaypoint(itemid, continent, zone, x, y, source, "PARTY", nil, high_prio) -- Only send to party for now
end

function World_OnEvent(self, event, ...)
	if event == "WORLD_MAP_UPDATE" then
		if WorldforgedItemTracker:IsMysticScroll(self.itemid) and not WorldforgedDB.enchant_tracking then
			self:Hide()
			return
		end

		local data = WorldforgedItemTracker:GetWaypoint(self.zoneid, self.itemid)
		local x, y = WorldforgedItemTracker:PlaceIconOnWorldMap(
			ItemTrackerOverlay,
			self,
			data.continent,
			data.zone,
			data.x,
			data.y
		)

		if not WorldforgedDBPerChar[self.zoneid] then
			return
		end
		if WorldforgedDBPerChar[self.zoneid][self.itemid] then
			self.icon:SetDesaturated(true)
		else
			self.icon:SetDesaturated(false)
		end
	end
end

StaticPopupDialogs["WFI_DELETE_WAYPOINT"] = {
	text = "Do you really want to remove this waypoint?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function(self, data)
		-- data is our itemid passed from Show()
		if data then
			WorldforgedItemTracker:DeleteWaypoint(data.zoneid, data.itemid)
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3, -- avoid tainting other popups
}
