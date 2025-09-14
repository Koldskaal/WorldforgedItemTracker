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
	self:InitializeCommands()
end

WorldforgedItemTracker:OnInitialize()

function WorldforgedItemTracker:InitializeWaypoints() end

function WorldforgedItemTracker:InitializeTracking() end

function WorldforgedItemTracker:InitializeSharing() end

function WorldforgedItemTracker:InitializeCommands()
	SLASH_WORLDFORGED1 = "/wfit"
	SLASH_WORLDFORGED2 = "/worldforged"

	SlashCmdList["WORLDFORGED"] = function(msg)
		msg = msg:lower()

		if msg == "clear" then
			for id, data in pairs(WorldforgedDB.waypoints_db) do
				self:DeleteWaypoint(id)
			end

			WorldforgedDB.waypoints_db = {}
		elseif msg == "help" or msg == "" then
			print("|cffffd700Worldforged Item Tracker commands:|r")
			print("/wfit help   - show this help text")
			print("/wfit clear  - clear all waypoints")
		else
			print("Unknown command: " .. msg)
		end
	end
end

