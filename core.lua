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

	if WorldforgedDB.enchant_tracking == nil then
		WorldforgedDB.enchant_tracking = false
	end

	if WorldforgedDB.sharing_enabled == nil then
		WorldforgedDB.sharing_enabled = true
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
		elseif msg == "sharing" then
			WorldforgedDB.sharing_enabled = not WorldforgedDB.sharing_enabled
			if WorldforgedDB.sharing_enabled then
				print("Waypoint sharing enabled")
			else
				print("Waypoint sharing disabled")
			end
		elseif msg == "enchants" then
			WorldforgedDB.enchant_tracking = not WorldforgedDB.enchant_tracking
			if WorldforgedDB.enchant_tracking then
				print("enchant tracking mode enabled")
			else
				print("enchant tracking mode disabled")
			end
		elseif msg == "help" or msg == "" then
			print("|cffffd700Worldforged Item Tracker commands:|r")
			print("/wfit help   - show this help text")
			print("/wfit sharing - toggle waypoint sharing")
			print("/wfit clear  - clear all waypoints")
		else
			print("Unknown command: " .. msg)
		end
	end
end
