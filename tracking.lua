if not WFIT_ScanTooltip then
	WFIT_ScanTooltip = CreateFrame("GameTooltip", "WFIT_ScanTooltip", nil, "GameTooltipTemplate")
	WFIT_ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function IsItemBoP(description)
	if not description then
		return false
	end

	-- Scan each line of the tooltip
	for i = 1, #description do
		local text = description[i]
		if text == ITEM_BIND_ON_PICKUP then
			return true
		end
	end
	return false
end

local function GetItemDescription(itemID)
	if not itemID then
		return nil
	end

	WFIT_ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	WFIT_ScanTooltip:ClearLines()
	WFIT_ScanTooltip:SetHyperlink("item:" .. itemID .. ":0:0:0:0:0:0:0")

	local description = {}
	for i = 1, WFIT_ScanTooltip:NumLines() do
		local left = _G["WFIT_ScanTooltipTextLeft" .. i]
		if left then
			local text = left:GetText()
			if text and text ~= "" then
				table.insert(description, text)
			end
		end
	end

	return description -- returns a table of lines
end

function WorldforgedItemTracker:OnLoot(itemID, source, is_container)
	local description = GetItemDescription(itemID)
	if not description then
		return
	end

	if description[2] == "Worldforged" then
		WorldforgedItemTracker:AddItem(itemID, source)
	end

	if is_container then -- not working atm
		local name = description[1]
		if string.sub(name, 1, 13) == "Mystic Scroll" then
			WorldforgedItemTracker:AddItem(itemID, source)
		end
	end

	-- backup since some items arent WORLDFORGED for some reason
	if is_container and IsItemBoP(description) and GetNumLootItems() == 1 then
		WorldforgedItemTracker:AddItem(itemID, source)
	end
end

function WorldforgedItemTracker:InitializeTracking()
	local lastTooltipName, isContainerSource

	GameTooltip:HookScript("OnTooltipSetUnit", function(self)
		local name, unit = self:GetUnit()
		if name then
			lastTooltipName = name
			isContainerSource = false -- it's a unit (corpse or NPC)
		end
	end)

	-- Fallback for containers
	GameTooltip:HookScript("OnShow", function(self)
		local name, unit = self:GetUnit()
		if not unit then
			local text = _G[self:GetName() .. "TextLeft1"]:GetText()
			if text then
				lastTooltipName = text
				isContainerSource = true -- it's NOT a unit, so container/gameobject
			end
		end
	end)
	local f = CreateFrame("Frame")
	f:RegisterEvent("CHAT_MSG_LOOT")
	f:RegisterEvent("LOOT_OPENED")

	f:SetScript("OnEvent", function(self, event, msg, ...)
		if event == "LOOT_OPENED" then
			-- This is not perfect. If a corpse is targeted while opening a container, it will be considered a corpse.
			for i = 1, GetNumLootItems() do
				local link = GetLootSlotLink(i)
				if link then
					local itemID = tonumber(link:match("item:(%d+)"))
					if itemID then
						WorldforgedItemTracker:OnLoot(itemID, lastTooltipName, isContainerSource)
					end
				end
			end
		end

		if event == "CHAT_MSG_LOOT" then
			local itemLink = nil -- fix later

			if itemLink then
				-- print("You looted:", itemLink)

				-- Example: Extract item ID
				local itemID = itemLink:match("item:(%d+)")
				if itemID then
					-- print("Item ID:", itemID)
				end
			end
		end
	end)
end
