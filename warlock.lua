-------------------------------- BAG --------------------------------

function GetInventoryItemCountByName(name)
	local count = 0
	if name then
		name = string.lower(name)
		for b = 0, NUM_BAG_FRAMES do
			local bagSlots = GetContainerNumSlots(b)
			for s = 1, bagSlots do
				local itemLink = GetContainerItemLink(b, s)
				local n, _ = DecodeItemLink(itemLink)
				if name == n then
					local _, c = GetContainerItemInfo(b, s)
					count = count + c
				end
			end
		end
	end
end

function DecodeItemLink(link)
	if link then
		local found, _, id, name = string.find(link, "item:(%d+):.*%[(.*)%]")
		if found then
			id = tonumber(id)
			return name, id
		end
	end
	return nil
end

function GetSoulShardCount()
	return CountInventoryItemByName("Soul Shard")
end

-------------------------------- UNIT --------------------------------

function UnitHealthPercent(unit)
	return UnitHealth(unit) / UnitHealthMax(unit)
end

function UnitManaPercent(unit)
	return UnitMana(unit) / UnitManaMax(unit)
end

function UnitIsEnemy(unit)
	return UnitCanAttack("player", unit) and not UnitIsCivilian(unit)
end

function UnitIsActive(unit)
	return UnitAffectingCombat(unit)
end

function UnitIsEnemyPlayer(unit)
	return UnitIsEnemy(unit) and UnitIsPlayer(unit)
end

function UnitIsActiveEnemy(unit)
	return UnitIsEnemy(unit) and UnitIsActive(unit)
end

function UnitGivesXP(unit)
	return UnitIsEnemy(unit) and not UnitIsTrivial(unit) and UnitFactionGroup(unit) ~= UnitFactionGroup("player") and
		not UnitIsPet(unit)
end

function UnitHasBuffOrDebuff(unit, spellName, spellId)
	local _, guid = UnitExists(unit)
	return Cursive.curses:ScanGuidForCurse(guid, spellId, spellName)
end

function UnitHasAnyCurse(unit)
	return UnitHasBuffOrDebuff(unit, "Curse of Agony") or
		UnitHasBuffOrDebuff(unit, "Curse of Weakness") or
		UnitHasBuffOrDebuff(unit, "Curse of Tongues") or
		UnitHasBuffOrDebuff(unit, "Curse of Doom") or
		UnitHasBuffOrDebuff(unit, "Curse of the Elements") or
		UnitHasBuffOrDebuff(unit, "Curse of Shadow") or
		UnitHasBuffOrDebuff(unit, "Curse of Recklessness")
end

function IsValidTarget(guid, spell, refreshTime)
	return UnitExists(guid) and not UnitIsDead(guid) and not Cursive.curses:HasCurse(spell, guid, refreshTime) and
		not IsUnitCrowdControlled(guid)
end

-------------------------------- SPELL --------------------------------

function IsNightfallActive()
	return UnitHasBuffOrDebuff("player", "Shadow Trance")
end

function IsShadowburnActive(unit)
	return UnitHasBuffOrDebuff(unit, "Shadowburn")
end

-------------------------------- PLAYER --------------------------------

function IsCasting(spell)
	return (not spell and Cursive.playerState.casting) or Cursive.playerState.casting == spell
end

function IsChanneling(spell)
	return (not spell and Cursive.playerState.channeling) or Cursive.playerState.channeling == spell
end

function IsCastingOrChanneling(spell)
	return IsCasting(spell) or IsChanneling(spell)
end

function IsAmplifyCurseActive()
	return UnitHasBuffOrDebuff("player", "Amplify Curse")
end

function GetSpellId(spell, rank, book)
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

function IsSpellKnown(spell, rank, book)
	if rank then
		return GetSpellId(spell, rank, book) and true or false
	else
		return GetSpellId(spell, 0, book) and true or false
	end
end

function IsMoving()
	return false
end

-------------------------------- WARLOCK --------------------------------

function CastCoE(unit)
	Cast(unit, "Drain Soul")
end

function CastCotE(unit)
	Cast(unit, "Drain Soul")
end

function CastCoT(unit)
	Cast(unit, "Drain Soul")
end

function CastCoD(unit)
	Cast(unit, "Drain Soul")
end

function CastCoS(unit)
	Cast(unit, "Drain Soul")
end

function CastCoR(unit)
	Cast(unit, "Drain Soul")
end

function CastCoW(unit)
	Cast(unit, "Drain Soul")
end

function CastCoA(unit)
	Cast(unit, "Drain Soul")
end

function CastCurse(unit, curse)
	return ((curse == "coe" or curse == "e") and CastCoE(unit)) or
		((curse == "cote" or curse == "te") and CastCotE(unit)) or
		((curse == "cot" or curse == "cot") and CastCoT(unit)) or
		((curse == "cod" or curse == "d") and CastCoD(unit)) or
		((curse == "cos" or curse == "s") and CastCoS(unit)) or
		((curse == "cor" or curse == "r") and CastCoR(unit)) or
		((curse == "cow" or curse == "w") and CastCoW(unit)) or
		((curse == "coa" or curse == "a") and CastCoA(unit))
end

function Cast(spell, unit, refreshTime, stopCast)
	if not IsSpellKnown(spell) then
		return false
	end

	if not IsValidTarget(unit, spell, refreshTime) then
		return false
	end

	if stopCast then
		SpellStopCasting()
	end

	CastSpellByName(spell, unit)
	return true
end

function CastDrainSoul(unit)
	return not IsMoving() and Cast("Drain Soul", unit)
end

function CastShadowBolt(unit)
	return not IsMoving() and Cast("Shadow Bolt", unit)
end

function CastShadowburn(unit, stopCast)
	return Cast("Shadowburn", unit, nil, stopCast)
end

function CastImmolate(unit)
	return not IsMoving() and Cast("Immolate", unit, 2)
end

function CastCorruption(unit)
	return Cast("Corruption", unit)
end

function CastDrainLife(unit)
	return not IsMoving() and Cast("Drain Life", unit)
end

function CastSiphonLife(unit)
	return Cast("Siphon Life", unit)
end

function CastDarkPact()
	return Cast("Dark Pact")
end

function CastLifeTap()
	return Cast("Life Tap")
end

function CastDemonArmor()
	return Cast("Demon Armor") or Cast("Demon Skin")
end

function CastAutoTap()
	local c = UnitAffectingCombat("player")
	local m = UnitMana("player")
	local mm = UnitManaMax("player")
	local p = UnitMana("pet")
	local pm = UnitManaMax("pet")
	local h = UnitHealth("player")
	local hm = UnitHealthMax("player")
	local d = IsSpellKnown("Dark Pact")
	local l = IsSpellKnown("Life Tap")

	if not IsCastingOrChanneling() and not (c and m / mm >= 0.9) then
		if d and mm - m >= 150 and (p == pm or (p / pm >= 0.99 and (h < hm or not l))) and CastDarkPact() then
			return true
		elseif ((h / hm) - (m / mm)) > 0.2 and h / hm > 0.66 and CastLifeTap() then
			return true
		end
	end
	return false
end

-------------------------------- MAIN --------------------------------

function WarlockDotSpam(unit, curse, shards)
	if curse == 0 then
		curse = nil
	end
	if shards == 0 then
		shards = nil
	end

	if curse then
		curse = string.lower(curse)
		if curse ~= "coe" and curse ~= "cote" and curse ~= "cot" and curse ~= "cod" and curse ~= "cos" and curse ~= "cor" and curse ~= "cow" and curse ~= "coa" and curse ~= "e" and curse ~= "te" and curse ~= "t" and curse ~= "d" and curse ~= "s" and curse ~= "r" and curse ~= "w" and curse ~= "a" then
			curse = nil
		end
	end

	local _ = nil
	unit = unit or "target"
	_, unit = UnitExists(unit)

	local targetIsEnemyPlayer = UnitIsEnemyPlayer(unit)
	if targetIsEnemyPlayer then
		return true
	end

	local targetHealthPercent = UnitHealthPercent(unit)
	local targetIsDying = targetHealthPercent <= 0.2
	local targetClassification = UnitClassification(unit) or ""
	local targetIsBoss = string.find(string.lower(targetClassification), "boss")
	local targetGivesXp = UnitGivesXP(unit)
	local targetIsActive = UnitIsActiveEnemy(unit)
	local targetIsTargetingPlayer = UnitExists(unit .. "target") and UnitIsUnit(unit .. "target", "player")

	local playerHasNightfall = IsNightfallActive()
	local playerHasAmplifyCurse = IsAmplifyCurseActive()

	local playerIsCastingOrChanneling = IsCastingOrChanneling()
	local playerHealthPercent = UnitHealthPercent("player")
	local playerManaPercent = UnitManaPercent("player")

	if targetGivesXp then
		local soulShardCount = GetSoulShardCount()
		local soulShardBagSize = 4
		if not targetIsBoss and targetIsDying and not IsShadowburnActive(unit) and soulShardCount < soulShardBagSize then
			CastDrainSoul(unit)
			return true
		elseif not IsChanneling() and ((targetIsBoss and targetIsDying) or (not targetIsBoss and targetHealthPercent <= 0.3)) and soulShardCount >= 1 and ((playerHasNightfall and CastShadowBolt(unit)) or CastShadowburn(unit, true)) then
			return true
		end
	end

	if not targetIsActive and not IsChanneling() then
		-- TODO: Check immunity
		if CastImmolate(unit) then
			return true
			-- Cast Shadow Bolt if FireImmune
		elseif CastShadowBolt(unit) then
			return true
		end
	end

	if not playerHasAmplifyCurse and playerHasNightfall and CastShadowBolt(unit) then
		return true
	end

	if not playerIsCastingOrChanneling and not targetIsActive then
		if CastAutoTap() then
			return true
		elseif playerManaPercent >= 0.5 and CastDemonArmor() then
			return true
		end
	end

	if (IsCasting("Immolate") and (UnitHasBuffOrDebuff(unit, "Immolate") or targetIsDying)) or (IsCasting("Corruption") and (UnitHasBuffOrDebuff(unit, "Corruption") or targetIsDying)) then
		SpellStopCasting()
	end

	-- Main Rotation -- Assumes the player has Nightfall and Fel Concentration

	local isDrainLifeInRange = false


	local preferDrainLife = targetIsTargetingPlayer and
		(playerHealthPercent <= 0.8 and playerManaPercent <= 0.2 and isDrainLifeInRange)

	-- Corruption
	if (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and not playerHasAmplifyCurse and CastCorruption(unit) then
		return true
		-- DPS Amplify Curse
	elseif (playerHasAmplifyCurse or (not curse and (not targetIsDying or targetIsBoss) and not UnitHasAnyCurse(unit) and not playerIsCastingOrChanneling)) and ((not targetIsDying and targetIsBoss and not playerHasAmplifyCurse and CastCoD(unit)) or CastCoA(unit)) then
		return true
		-- Regular Curse
	elseif curse and (not targetIsDying or targetIsBoss) and not UnitHasAnyCurse(unit) and not playerIsCastingOrChanneling and CastCurse(unit, curse) then
		return true
		-- Siphon Life
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and CastSiphonLife(unit) then
		return true
		-- Immolate
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and not playerHasAmplifyCurse and (not (playerHealthPercent <= 0.8 or playerManaPercent <= 0.2 or isDrainLifeInRange)) and CastImmolate(unit) then
		return true
		-- Life Tap
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and (not targetIsTargetingPlayer or isDrainLifeInRange) and (playerManaPercent < 0.8 and playerHealthPercent >= 0.95) and CastLifeTap() then
		return true
		-- Drain Life
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and CastDrainLife(unit) then
		return true
	end

	return false
end
