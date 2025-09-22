if not WFIT_ScanTooltip then
	WFIT_ScanTooltip = CreateFrame("GameTooltip", "WFIT_ScanTooltip", nil, "GameTooltipTemplate")
	WFIT_ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function GetPositionFromGUID(guid)
	if not guid then
		return nil
	end
	SetMapToCurrentZone()

	-- Check self
	if UnitGUID("player") == guid then
		return GetCurrentMapContinent(), GetCurrentMapAreaID(), GetPlayerMapPosition("player")
	end

	-- Check party
	for i = 1, GetNumPartyMembers() do
		local unit = "party" .. i
		if UnitGUID(unit) == guid then
			return GetCurrentMapContinent(), GetCurrentMapAreaID(), GetPartyMemberPosition(unit)
		end
	end

	-- Check raid
	for i = 1, GetNumRaidMembers() do
		local unit = "raid" .. i
		if UnitGUID(unit) == guid then
			return GetCurrentMapContinent(), GetCurrentMapAreaID(), GetRaidTargetIndex(unit)
		end
	end

	return nil -- not found in group
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

function WorldforgedItemTracker:OnLoot(itemID, source, continent, zone, x, y, is_container, high_prio)
	local description = GetItemDescription(itemID)
	if not description then
		return
	end

	if description[2] == "Worldforged" then
		WorldforgedItemTracker:AddItem(itemID, source, continent, zone, x, y, high_prio)
	end

	local name = description[1]
	if string.sub(name, 1, 13) == "Mystic Scroll" then
		WorldforgedItemTracker:AddItem(itemID, source, continent, zone, x, y, high_prio)
	end

	-- backup since some items arent WORLDFORGED for some reason
	if is_container and IsItemBoP(description) and GetNumLootItems() == 1 then
		WorldforgedItemTracker:AddItem(itemID, source, continent, zone, x, y, high_prio)
	end
end

function WorldforgedItemTracker:InitializeTracking()
	local lastTooltipName, isContainerSource
	local lastKill = {}

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
	f:RegisterEvent("LOOT_OPENED")

	f:SetScript("OnEvent", function(self, event, msg, ...)
		if event == "LOOT_OPENED" then
			-- This is not perfect. If a corpse is targeted while opening a container, it will be considered a corpse.
			for i = 1, GetNumLootItems() do
				local link = GetLootSlotLink(i)
				if link then
					local itemID = tonumber(link:match("item:(%d+)"))
					if itemID then
						local c, z, x, y = GetPositionFromGUID(UnitGUID("player"))
						local source
						if isContainerSource then
							source = { type = "CONTAINER", name = lastTooltipName }
						else
							source = { type = "CORPSE", name = lastTooltipName }
						end
						WorldforgedItemTracker:OnLoot(itemID, source, c, z, x, y, isContainerSource, true)
					end
				end
			end
		end
	end)

	local fRoll = CreateFrame("Frame")
	fRoll:RegisterEvent("START_LOOT_ROLL")
	fRoll:SetScript("OnEvent", function(_, event, rollID, rollTime)
		if not lastKill then
			return
		end

		local link = GetLootRollItemLink(rollID)
		if link then
			local itemID = tonumber(link:match("item:(%d+)"))
			local c, z, x, y = lastKill.c, lastKill.z, lastKill.x, lastKill.y
			local source = { type = "CORPSE", name = lastKill.mobName or "[Unknown]" }
			WorldforgedItemTracker:OnLoot(itemID, source, c, z, x, y, false)
		end
	end)

	local combat = CreateFrame("Frame")
	combat:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	combat:SetScript(
		"OnEvent",
		function(frame, event, _, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
			if eventType == "PARTY_KILL" then
				local killerGUID = sourceGUID
				local killerName = sourceName

				-- pet kills belong to the owner
				if bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET) > 0 then
					if bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then
						killerGUID = UnitGUID("player")
						killerName = UnitName("player")
					end
				end
				local c, z, x, y = GetPositionFromGUID(killerGUID)

				WorldforgedItemTracker.lastKill = {
					killerGUID = killerGUID,
					killerName = killerName,
					mobGUID = destGUID,
					mobName = destName,
					time = GetTime(),
					c = c,
					z = z,
					x = x,
					y = y,
				}

				-- print("Latest kill:", sourceName, "killed", destName)
			end
		end
	)

	local activeQuest = nil
	local activeNPC = nil

	local fQuest = CreateFrame("Frame")
	fQuest:RegisterEvent("QUEST_COMPLETE")

	fQuest:SetScript("OnEvent", function(_, event, ...)
		activeQuest = GetTitleText()
		activeNPC = UnitName("npc") or "Unknown NPC"
	end)

	-- Last possible trigger.
	local fChat = CreateFrame("Frame")
	fChat:RegisterEvent("CHAT_MSG_LOOT")
	fChat:SetScript("OnEvent", function(_, _, msg, playerName)
		local isQuestReward = activeNPC == UnitName("target")

		if not lastKill and not isQuestReward then
			return
		end

		local itemLink = msg:match("|Hitem:.-|h.-|h")
		if not itemLink then
			return
		end

		local itemID = tonumber(itemLink:match("item:(%d+)"))
		local player_c, player_z, player_x, player_y = GetPositionFromGUID(UnitGUID("player"))

		if isQuestReward then
			local source = { type = "QUEST", name = activeQuest }
			WorldforgedItemTracker:OnLoot(itemID, source, player_c, player_z, player_x, player_y, false)
		else
			local c, z, x, y = lastKill.c, lastKill.z, lastKill.x, lastKill.y
			if player_c ~= c or player_z ~= z then
				return -- ignore if player is not in the same zone
			end
			local source = { type = "CORPSE", name = lastKill.mobName or "[Unknown]" }
			WorldforgedItemTracker:OnLoot(itemID, source, c, z, x, y, false)
		end
	end)
end
