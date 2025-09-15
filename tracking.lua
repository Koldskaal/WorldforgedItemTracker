if not WFIT_ScanTooltip then
	WFIT_ScanTooltip = CreateFrame("GameTooltip", "WFIT_ScanTooltip", nil, "GameTooltipTemplate")
	WFIT_ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

local is_container = false

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

function WorldforgedItemTracker:OnLoot(itemID)
	local description = GetItemDescription(itemID)
	if not description then
		return
	end

	if description[2] == "Worldforged" then
		WorldforgedItemTracker:AddItem(itemID)
	end

	if is_container then
		local name = description[1]
		if string.sub(name, 1, 13) == "Mystic Scroll" then
			WorldforgedItemTracker:AddItem(itemID)
		end
	end
end

function WorldforgedItemTracker:InitializeTracking()
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
						WorldforgedItemTracker:OnLoot(itemID)
					end
				end
			end
		end

		if event == "CHAT_MSG_LOOT" then
			local itemLink = nil -- fix later

			if itemLink then
				print("You looted:", itemLink)

				-- Example: Extract item ID
				local itemID = itemLink:match("item:(%d+)")
				if itemID then
					print("Item ID:", itemID)
				end
			end
			print("LOOT", msg, ...)
		end
	end)
end
