local Astrolabe = DongleStub("Astrolabe-0.4")

function WorldforgedItemTracker:CreateWaypoint(itemid, continent, zone, x, y)
	if not WorldforgedDB.waypoints_db[itemid] then
		WorldforgedDB.waypoints_db[itemid] = {
			continent = continent,
			zone = zone,
			x = x,
			y = y,
			waypoint = nil,
		}
	end
	local waypoint = CreateFrame("Button", nil, ItemTrackerOverlay)
	waypoint:SetHeight(12)
	waypoint:SetWidth(12)
	waypoint:RegisterForClicks("RightButtonUp")
	waypoint.icon = waypoint:CreateTexture("ARTWORK")
	waypoint.icon:SetAllPoints()
	waypoint.icon:SetTexture("Interface\\AddOns\\WorldforgedItemTracker\\Images\\GoldGreenDot")

	waypoint.itemid = itemid

	WorldforgedDB.waypoints_db[itemid].waypoint = waypoint

	waypoint:RegisterEvent("WORLD_MAP_UPDATE")
	waypoint:SetScript("OnEvent", World_OnEvent)

	waypoint:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetParent(self)

		GameTooltip:SetFrameStrata("TOOLTIP")
		local link = "item:" .. self.itemid .. ":0:0:0:0:0:0:0"
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end)
	waypoint:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		GameTooltip:SetParent(UIParent)
		GameTooltip:SetFrameStrata("TOOLTIP")
	end)

	waypoint:SetScript("OnClick", function(self)
		WorldforgedItemTracker:SendWaypoint(self.itemid, self.continent, self.zone, self.x, self.y, "PARTY")
	end)

	Astrolabe:PlaceIconOnWorldMap(ItemTrackerOverlay, waypoint, continent, zone, x, y)
end

function WorldforgedItemTracker:DeleteWaypoint(itemid)
	if not itemid or not WorldforgedDB.waypoints_db[itemid] then
		return
	end
	local waypoint = WorldforgedDB.waypoints_db[itemid].waypoint

	WorldforgedDB.waypoints_db[itemid] = nil
	Astrolabe:RemoveIconFromMinimap(waypoint)
end

function WorldforgedItemTracker:GetWaypoint(itemid)
	return WorldforgedDB.waypoints_db[itemid]
end

function WorldforgedItemTracker:InitializeWaypoints()
	WorldforgedDB.waypoints_db = WorldforgedDB.waypoints_db or {}

	if not ItemTrackerOverlay then
		local overlay = CreateFrame("Frame", "ItemTrackerOverlay", WorldMapButton)
		overlay:SetAllPoints(true)
	end

	for itemid, data in pairs(WorldforgedDB.waypoints_db) do
		self:CreateWaypoint(itemid, data.continent, data.zone, data.x, data.y)
	end
end

function WorldforgedItemTracker:AddItem(itemid)
	SetMapToCurrentZone()
	local continent, zone, x, y = GetCurrentMapContinent(), GetCurrentMapZone(), GetPlayerMapPosition("player")

	self:CreateWaypoint(itemid, continent, zone, x, y)
	self:SendWaypoint(itemid, continent, zone, x, y, "PARTY") -- Only send to party for now
end

function World_OnEvent(self, event, ...)
	if event == "WORLD_MAP_UPDATE" then
		local data = WorldforgedItemTracker:GetWaypoint(self.itemid)
		local x, y = Astrolabe:PlaceIconOnWorldMap(ItemTrackerOverlay, self, data.continent, data.zone, data.x, data.y)
		if x and y and (0 < x and x <= 1) and (0 < y and y <= 1) then
			self:Show()
		else
			self:Hide()
		end
	end
end

