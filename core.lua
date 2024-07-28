if not Cursive.superwow then
	return
end

-- add (1) for first stack of buffs/debuffs
-- other addons already do this, avoid having to parse both formats
AURAADDEDOTHERHELPFUL = "%s gains %s (1)."
AURAADDEDOTHERHARMFUL = "%s is afflicted by %s (1)."
AURAADDEDSELFHARMFUL = "You are afflicted by %s (1)."
AURAADDEDSELFHELPFUL = "You gain %s (1)."

Cursive.core = CreateFrame("Frame", "Cursive", UIParent)
Cursive.core.guids = {}
Cursive.core.tapped = {}
Cursive.playerState = { casting = nil, channeling = nil, attacking = nil, autoRepeating = nil, x = nil, y = nil, moving = nil }

Cursive.registerButtonsTooltip = CreateFrame("GameTooltip", "Cursive_RegisterButtonsTooltip", UIParent, "GameTooltipTemplate")
Cursive.registerButtonsTooltip:Hide()
Cursive.registerButtonsTooltip:SetOwner(Cursive.core, "ANCHOR_NONE")

Cursive.buffTooltip = CreateFrame("GameTooltip", "Cursive_BuffTooltip", UIParent, "GameTooltipTemplate")
Cursive.buffTooltip:Hide()
Cursive.buffTooltip:SetOwner(Cursive.core, "ANCHOR_NONE")

Cursive.core.add = function(unit)
	local _, guid = UnitExists(unit)

	if guid and not UnitIsDead(unit) then
		Cursive.core.guids[guid] = GetTime()
	end
end

Cursive.core.addGuid = function(guid)
	-- check if first two characters are 0x
	if string.sub(guid, 1, 2) ~= "0x" then
		return
	end
	if UnitExists(guid) and not UnitIsDead(guid) then
		Cursive.core.guids[guid] = GetTime()
	end
end

Cursive.core.remove = function(guid)
	Cursive.core.guids[guid] = nil
	Cursive.core.tapped[guid] = nil
end

Cursive.core.enable = function()
	-- unitstr
	Cursive.core:RegisterEvent("PLAYER_TARGET_CHANGED")
	-- arg1
	Cursive.core:RegisterEvent("UNIT_COMBAT") -- this can get called with player/target/raid1 etc
	Cursive.core:RegisterEvent("UNIT_MODEL_CHANGED")

	Cursive.core:RegisterEvent("PLAYER_ENTERING_WORLD")
	Cursive.core:RegisterEvent("ACTIONBAR_HIDEGRID")
	Cursive.core:RegisterEvent("LEARNED_SPELL_IN_TAB")
end

Cursive.core.disable = function()
	Cursive.core:UnregisterAllEvents()
	Cursive.core.guids = {}
end

Cursive.core:SetScript("OnEvent", function()
	if event == "PLAYER_TARGET_CHANGED" then
		this.add("target")
	elseif event == "UNIT_COMBAT" or event == "UNIT_MODEL_CHANGED" then
		-- arg1 is guid
		this.addGuid(arg1)
	elseif event == "ACTIONBAR_HIDEGRID" or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_ENTERING_WORLD" then
		RegisterButtons()
	end
end)

Cursive.core:SetScript("OnUpdate", function()
	local x, y = UnitPosition("player")
	if x == Cursive.playerState.x and y == Cursive.playerState.y then
		Cursive.playerState.moving = nil
	else
		Cursive.playerState.x = x
		Cursive.playerState.y = y
		Cursive.playerState.moving = true
		Cursive.playerState.casting = nil
		Cursive.playerState.channeling = nil
	end
end)

function PairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

function CompareGuids(priority, raidMark)
	priority = priority or "HIGHEST_HP"
	local compareHealth = function (priority, guid1, guid2)
		if UnitHealth(guid1) == UnitHealth(guid2) then
			return nil
		end

		if priority == "LOWEST_HP" then
			return UnitHealth(guid1) < UnitHealth(guid2)
		else
			return UnitHealth(guid1) > UnitHealth(guid2)
		end
	end
	
	return function (guid1, guid2)
		local guid1IsMulticurseTarget = UnitIsMulticurseTarget(guid1)
		local guid2IsMulticurseTarget = UnitIsMulticurseTarget(guid2)
		local guid1RaidPriority = GetRaidTargetIndex(guid1) or 0
		local guid2RaidPriority = GetRaidTargetIndex(guid2) or 0

		if guid1IsMulticurseTarget and not guid2IsMulticurseTarget then
			return true
		elseif guid2IsMulticurseTarget and not guid1IsMulticurseTarget then
			return false
		else
			if raidMark then
				if guid1RaidPriority == guid2RaidPriority then
					return compareHealth(priority, guid1, guid2)
				else
					return guid1RaidPriority > guid2RaidPriority
				end
			else
				return compareHealth(priority, guid1, guid2)
			end
		end
	end
end

function OnPlayerEnterOrLeaveCombat()
	Cursive.playerState.attacking = event == "PLAYER_ENTER_COMBAT"
end

Cursive:RegisterEvent("PLAYER_ENTER_COMBAT", OnPlayerEnterOrLeaveCombat)
Cursive:RegisterEvent("PLAYER_LEAVE_COMBAT", OnPlayerEnterOrLeaveCombat)

function OnPlayerAutorepeatSpell()
	Cursive.playerState.autoRepeating = event == "START_AUTOREPEAT_SPELL"
end
Cursive:RegisterEvent("START_AUTOREPEAT_SPELL", OnPlayerAutorepeatSpell)
Cursive:RegisterEvent("STOP_AUTOREPEAT_SPELL", OnPlayerAutorepeatSpell)

function Cursive_GetSpellId(spell, rank, book)
	local B = book or BOOKTYPE_SPELL
	local SpellID = nil
	if spell then
		local SpellCount = 0
		local ReturnName = nil
		local ReturnRank = nil
		while spell ~= ReturnName do
			SpellCount = SpellCount + 1
			ReturnName, ReturnRank = GetSpellName(SpellCount, B)
			if not ReturnName then
				break
			end
		end
		while spell == ReturnName do
			if rank then
				if rank == 0 then
					return SpellCount
				elseif ReturnRank and ReturnRank ~= "" then
					local found, _, Rank = string.find(ReturnRank, "(%d+)")
					if found then
						ReturnRank = tonumber(Rank)
					else
						ReturnRank = 1
					end
				else
					ReturnRank = 1
				end
				if rank == ReturnRank then
					return SpellCount
				end
			else
				SpellID = SpellCount
			end
			SpellCount = SpellCount + 1
			ReturnName, ReturnRank = GetSpellName(SpellCount, B)
		end
	end
	return SpellID
end

function Cursive_GetSpellRank(SpellName, Book)
	local B = Book or BOOKTYPE_SPELL
	local rslt = 0
	if SpellName then
		local spell, rank
		local i = Cursive_GetSpellId(SpellName, nil, B)
		if i then
			spell, rank = GetSpellName(i, B)
			rslt = rank
			if rslt and rslt ~= "" then
				local found, _, Rank = string.find(rslt, "(%d+)")
				if found then
					rslt = tonumber(Rank)
				else
					rslt = 1
				end
			else
				rslt = 1
			end
		end
	end
	return rslt
end

Cursive_Button = {}
function RegisterButtons()
	Cursive_Button = {}
	for i = 1, 120 do
		local SpellName, SpellRank, RankName, text = GetActionButtonToolTipFirstLineInfo(i)
		if SpellName then
			Cursive_Button[SpellName] = i
		end
	end
end

function GetActionButtonToolTipFirstLineInfo(slot)
	if slot and HasAction(slot) then
		local text = GetActionText(slot)
		-- if text then
		-- 	return nil, nil, nil, text
		-- end
		local lt = nil
		local SpellName = nil
		local rt = nil
		local RankName = nil
		local SpellRank = nil
		Cursive.registerButtonsTooltip:SetAction(slot)
		local Lines = Cursive.registerButtonsTooltip:NumLines()
		local tooltipName = Cursive.registerButtonsTooltip:GetName()

		if Lines and Lines > 0 then
			lt = getglobal(tooltipName.."TextLeft1")
			if lt:IsShown() then
				SpellName = lt:GetText()
				if SpellName == "" then
					SpellName = nil
				end
			end
			
		end
		if SpellName then
			rt = getglobal(tooltipName.."TextRight1")
			if rt:IsShown() then
				RankName = rt:GetText()
				if RankName == "" then
					RankName = nil
				end
			end
			if RankName then
				local found, _, rank = string.find(RankName, "(%d+)")
				if found then
					SpellRank = tonumber(rank)
					RankName = "("..RankName..")"
				else
					RankName = ""
					SpellRank = 1
				end
			else
				RankName = ""
				SpellRank = 1
			end
		end
		
		return SpellName, SpellRank, RankName, text
	end	
end