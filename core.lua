-- WorldforgedItemTracker/core.lua

WorldforgedItemTracker = {}

function WorldforgedItemTracker:OnInitialize()
	-- Create the main frame
	self.frame = CreateFrame("Frame", "WorldforgedItemTrackerFrame")
	self.frame:RegisterEvent("ADDON_LOADED")
	self.frame:SetScript("OnEvent", function(self, event, ...)
		if event == "ADDON_LOADED" and ... == "WorldforgedItemTracker" then
			WorldforgedItemTracker:OnAddonLoaded()
		end
	end)
end

function WorldforgedItemTracker:OnAddonLoaded()
	if not WorldforgedDB then
		WorldforgedDB = {}
	end
	print("WorldforgedItemTracker loaded!")
	self:InitializeWaypoints()
	self:InitializeTracking()
	self:InitializeSharing()
end

WorldforgedItemTracker:OnInitialize()

function WorldforgedItemTracker:InitializeWaypoints() end

function WorldforgedItemTracker:InitializeTracking() end

function WorldforgedItemTracker:InitializeSharing() end

