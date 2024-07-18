-------------------------------- BAG --------------------------------

function GetInventoryItemCountByName(name)
	local count = 0
	if name then
		name = string.lower(name)
		for b = 0, NUM_BAG_FRAMES do
			local bagSlots = GetContainerNumSlots(b)
			for s = 1, bagSlots do
				local itemLink = GetContainerItemLink(b, s)
				local n = DecodeItemLink(itemLink)
				n = n and string.lower(n)
				if name == n then
					local _, c = GetContainerItemInfo(b, s)
					count = count + c
				end
			end
		end
	end

	return count
end

function DecodeItemLink(link)
	if link then
		local found, _, name = string.find(link, "%[(.*)%]")
		return name
	end
	return nil
end

function GetSoulShardCount()
	return GetInventoryItemCountByName("Soul Shard") or 0
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

function UnitIsPet(unit)
	local u = unit or "target"
	return UnitPlayerControlled(u) and not UnitIsPlayer(u)
end

function UnitGivesXP(unit)
	return UnitIsEnemy(unit) and not UnitIsTrivial(unit) and UnitFactionGroup(unit) ~= UnitFactionGroup("player") and
		not UnitIsPet(unit)
end

function UnitHasBuffOrDebuff(unit, spellName, timeRemaining)
	local _, guid = UnitExists(unit)
	return Cursive.curses:HasCurse(spellName, guid, timeRemaining)
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

function UnitIsTargetingParty(unit)
	unit = unit or "target"
	return UnitIsInParty(unit.."target")
end

function UnitIsInParty(unit)
    if IsInInstance() and UnitAffectingCombat(unit) then
        return true
    end

    if UnitIsUnit("player", unit) or UnitIsUnit("pet", unit) then
        return true
    end

    local max = GetNumPartyMembers()
    for n=1, max do
        if UnitIsUnit("party"..n, unit) or UnitIsUnit("partypet"..n, unit) then
            return true
        end
    end
    return nil
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

-------------------------------- PET --------------------------------

function CastPetSpell(SpellName, unit, ManaNoRanks, ManaPercent, ManaSpellRank1, ManaSpellRank2, ManaSpellRank3, ManaSpellRank4, ManaSpellRank5, ManaSpellRank6, ManaSpellRank7, ManaSpellRank8, ManaSpellRank9)
	unit = unit or "target"
	local m = nil
	if not (UnitHealth("pet") > 0) then
		--print("Your pet is not active or alive to use pet ability: "..SpellName)
		return false
	end
	for i=1, NUM_PET_ACTION_SLOTS, 1 do
		local slotspellname, slotspellsubtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)
		if (slotspellname and slotspellname == SpellName) then
			local start, dur, enable = GetPetActionCooldown(i)
			if ManaNoRanks then
				m = ManaNoRanks
			elseif ManaPercent then
				m = (ManaPercent/100)
			elseif ManaSpellRank1 then
				if string.find(slotspellsubtext, " 1") then
					m = ManaSpellRank1
				elseif ManaSpellRank2 then
					if string.find(slotspellsubtext, " 2") then
						m = ManaSpellRank2
					elseif ManaSpellRank3 then
						if string.find(slotspellsubtext, " 3") then
							m = ManaSpellRank3
						elseif ManaSpellRank4 then
							if string.find(slotspellsubtext, " 4") then
								m = ManaSpellRank4
							elseif ManaSpellRank5 then
								if string.find(slotspellsubtext, " 5") then
									m = ManaSpellRank5
								elseif ManaSpellRank6 then
									if string.find(slotspellsubtext, " 6") then
										m = ManaSpellRank6
									elseif ManaSpellRank7 then
										if string.find(slotspellsubtext, " 7") then
											m = ManaSpellRank7
										elseif ManaSpellRank8 then
											if string.find(slotspellsubtext, " 8") then
												m = ManaSpellRank8
											elseif ManaSpellRank9 then
												if string.find(slotspellsubtext, " 9") then
													m = ManaSpellRank9
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
			if m then
				if ManaPercent then
					if UnitMana("pet") / UnitManaMax("pet") < m then
						--print("Your pet does not have enouph mana for pet ability: "..SpellName..", unable to cast")
						return false
					end
				elseif UnitMana("pet") < m then
					--print("Your pet does not have enouph mana for pet ability: "..SpellName..", unable to cast")
					return false
				end
			end
			if (dur > 0) then
				--print("Cooldown is enabled for pet ability: "..SpellName..", unable to cast")
				return false
			end
			if isActive then
				--print("The pet ability "..SpellName.." is active, unable to cast")
				return false
			end
			CastPetAction(i, unit)
			return true
		end
	end
	--print("Unable to locate pet ability: " .. SpellName)
	return false
end

function VoidwalkerAutoSacrifice(PlayerHealthPercent, PetHealthPercent)
	local PlayerHP = PlayerHealthPercent or 30
	local PetHP = PetHealthPercent or 20
	if UnitCreatureFamily("pet") == "Voidwalker" and UnitHealth("pet") > 0 and (UnitHealth("pet") / UnitHealthMax("pet") <= PetHP / 100 or UnitHealth("player") / UnitHealthMax("player") <= PlayerHP / 100) and not UnitHasBuffOrDebuff("pet", "Banish") then
		return CastPetSpell("Sacrifice")
	end
	return false
end

function PetAttackIfNotPassive(unit)
	unit = unit or "target"
	if UnitExists("pet") and UnitExists(unit) then
		local _,_,_,_,isActive = GetPetActionInfo(10)
		if not isActive then
			TargetUnit(unit)
			PetAttack()
		end
	end
end

function PetAttackToggle()
	if UnitExists("pet") and UnitExists("target") then
		if UnitIsFriend("player","target") then
			AssistUnit("target")
			PetAttack()
		elseif UnitExists("pettarget") and UnitIsUnit("target", "pettarget") then
			PetFollow()
		else
			PetAttack()
		end
	else
		PetFollow()
	end
end

-------------------------------- PLAYER --------------------------------

function IsCasting(spell)
	if not spell then
		return Cursive.playerState.casting and true or false
	else
		return Cursive.playerState.casting == spell
	end
end

function IsChanneling(spell)
	if not spell then
		return Cursive.playerState.channeling and true or false
	else
		return Cursive.playerState.channeling == spell
	end
end

function IsCastingOrChanneling(spell)
	return IsCasting(spell) or IsChanneling(spell)
end

function IsAmplifyCurseActive()
	return UnitHasBuffOrDebuff("player", "Amplify Curse")
end

function IsOffCooldown(spell, book)
	local spellIndex = Cursive_GetSpellId(spell, 0, book)

	local b = book or BOOKTYPE_SPELL
	if spellIndex then
		if GetSpellCooldown(spellIndex, b) == 0 then
			return true
		end
	end
	return false
end

function IsSpellKnown(spell, rank, book)
	if rank then
		return Cursive_GetSpellId(spell, rank, book) and true or false
	else
		return Cursive_GetSpellId(spell, 0, book) and true or false
	end
end

function IsMoving()
	return Cursive.playerState.moving
end

-------------------------------- WARLOCK --------------------------------

function Cast(spell, unit, selfCast, refreshTime, stopCast)
	if not IsSpellKnown(spell) then
		return false
	end

	local _ = nil
	_, unit = UnitExists(unit or "target")

	if not unit or UnitIsDead(unit) then
		_, unit = UnitExists("player")
	end

	if not IsValidTarget(unit, spell, refreshTime) then
		return false
	end

	if stopCast then
		SpellStopCasting()
	end

	local action = Cursive_Button[spell]
	if action and not (IsUsableAction(action) and IsActionInRange(action)) then
		return nil
	end

	CastSpellByName(spell, unit, selfCast)
	return true
end

function CastCoE(unit)
	return Cast("Curse of Exhaustion", unit)
end

function CastCotE(unit)
	return Cast("Curse of the Elements", unit)
end

function CastCoT(unit)
	return Cast("Curse of Tongues", unit)
end

function CastCoD(unit)
	return Cast("Curse of Doom", unit)
end

function CastCoS(unit)
	return Cast("Curse of Shadow", unit)
end

function CastCoR(unit)
	return Cast("Curse of Recklessness", unit)
end

function CastCoW(unit)
	return Cast("Curse of Weakness", unit)
end

function CastCoA(unit)
	return Cast( "Curse of Agony", unit)
end

function PickCurse(unit)
	unit = unit or "target"
	local _, class = UnitClass(unit)

	local c = {
		["WARRIOR"] = "cow",
		["PALADIN"] = "coa",
		["HUNTER"] = "cow",
		["ROGUE"] = "cow",
		["PRIEST"] = "cot",
		["SHAMAN"] = "coa",
		["MAGE"] = "cot",
		["WARLOCK"] = "cot",
		["DRUID"] = "cow",
	}
	return c[class]
end

function CastCurse(unit, curse)
	curse = curse or PickCurse(unit)

	local curseName =
		((curse == "coe" or curse == "e") and "Curse of Exhaustion") or
		((curse == "cote" or curse == "te") and "Curse of the Elements") or
		((curse == "cot" or curse == "cot") and "Curse of Tongues") or
		((curse == "cod" or curse == "d") and "Curse of Doom") or
		((curse == "cos" or curse == "s") and "Curse of Shadow") or
		((curse == "cor" or curse == "r") and "Curse of Recklessness") or
		((curse == "cow" or curse == "w") and "Curse of Weakness") or
		((curse == "coa" or curse == "a") and "Curse of Agony") or "Curse of Agony"

	if not IsSpellKnown(curseName) then
		curseName = "Curse of Agony"
	end

	return Cast(curseName, unit)
end

function CastDrainSoul(unit)
	return not IsMoving() and Cast("Drain Soul", unit)
end

function CastShadowBolt(unit)
	return not IsMoving() and Cast("Shadow Bolt", unit)
end

function CastShadowburn(unit, stopCast)
	return Cast("Shadowburn", unit, nil, nil, stopCast)
end

function CastImmolate(unit)
	return not IsMoving() and Cast("Immolate", unit, nil, 2)
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

function CastDemonArmor()
	local i, x = 1, 0
	while UnitBuff("player",i) do
		if UnitBuff("player",i) == "Interface\\Icons\\Spell_Shadow_RagingScream" then
			return nil
		end
		i = i + 1
	end

	return (IsSpellKnown("Demon Armor") and Cast("Demon Armor", nil, true)) or (IsSpellKnown("Demon Skin") and Cast("Demon Skin", nil, true))
end

function CastDemonArmorOrDarkPactAndLifeTap(tapFirstPlayerHealthPercent, pactFirstPetManaPercent)
	return CastDemonArmor() or CastDarkPactAndLifeTap(tapFirstPlayerHealthPercent, pactFirstPetManaPercent)
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

	if not IsCastingOrChanneling() and not (c and m / mm >= 0.5) then
		if d and mm - m >= 150 and (p == pm or (p / pm >= 0.99 and (h < hm or not l))) and CastDarkPact() then
			return true
		elseif (m / mm >= 0.8 and h / hm >= 0.98) or (m / mm < 0.8 and h / hm >= 0.95) and CastLifeTap() then
			return true
		end
	end
	return false
end

function CastDarkPactAndLifeTap(tapFirstPlayerHealthPercent, pactFirstPetManaPercent)
	local tapFirstPlayerHealthPercent = tapFirstPlayerHealthPercent or 97
	local pactFirstPetManaPercent = pactFirstPetManaPercent or 97
	if not IsSpellKnown("Dark Pact") then
		return CastLifeTap()
	elseif not IsSpellKnown("Life Tap") then
		return CastDarkPact()
	elseif UnitHealthPercent("player") >= tapFirstPlayerHealthPercent and UnitManaPercent("pet") < pactFirstPetManaPercent and CastLifeTap() then
		return true
	elseif CastDarkPact() then
		return true
	end
	return CastLifeTap()
end

function CastDarkPact()
	local m = { 150, 200, 250 } --table of mana loss and cost required for each rank of Dark Pact
	for i = 3, 1, -1 do
		if (UnitManaMax("player") - UnitMana("player") >= m[i]) then
			if (UnitMana("pet") >= m[i] ) then
				if IsSpellKnown("Dark Pact", i) then
					if IsOffCooldown("Dark Pact") then
						Cast("Dark Pact (Rank "..i..")", nil, true)
						return true
					end
					break
				end
			end
		end	
	end
	return false
end

function CastLifeTap()
	return UnitManaMax("player") ~= UnitMana("player") and IsSpellKnown("Life Tap") and IsOffCooldown("Life Tap") and Cast("Life Tap", nil, true)
end

-------------------------------- MAIN --------------------------------

function WarlockDotSpam(unit, curse, shards, nodrain)
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
		local soulShardCount = GetSoulShardCount() or 0
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

	if (IsCasting("Immolate") and (UnitHasBuffOrDebuff(unit, "Immolate", 2) or targetIsDying)) or (IsCasting("Corruption") and (UnitHasBuffOrDebuff(unit, "Corruption") or targetIsDying)) then
		SpellStopCasting()
	end

	-- Main Rotation -- Assumes the player has Nightfall and Fel Concentration

	local isDrainLifeInRange = Cursive_Button["Drain Life"]  and IsActionInRange(Cursive_Button["Drain Life"])

	local preferDrainLife = targetIsTargetingPlayer and
		(playerHealthPercent <= 0.8 and playerManaPercent <= 0.2 and isDrainLifeInRange)

	-- Curse of Recklessness
	if (targetIsDying and not targetIsBoss) and not UnitExists(unit.."target") and CastCurse(unit, "cor") then
		return true
	-- Corruption
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and not playerHasAmplifyCurse and CastCorruption(unit) then
		return true
	-- 	-- DPS Amplify Curse
	-- elseif (playerHasAmplifyCurse or (not curse and (not targetIsDying or targetIsBoss) and not UnitHasAnyCurse(unit) and not playerIsCastingOrChanneling)) and ((not targetIsDying and targetIsBoss and not playerHasAmplifyCurse and CastCoD(unit)) or CastCoA(unit)) then
	--  	return true
		-- Regular Curse
	elseif (playerHasAmplifyCurse or ((not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and not UnitHasAnyCurse(unit))) and CastCurse(unit, curse) then
		return true
		-- Siphon Life
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and CastSiphonLife(unit) then
		return true
		-- Life Tap
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and CastAutoTap() then
		return true
		-- Immolate
	elseif (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and not playerHasAmplifyCurse and (nodrain or not IsSpellKnown("Drain Life") or (not (playerHealthPercent <= 0.8 or isDrainLifeInRange))) and CastImmolate(unit) then
		return true
		-- Drain Life
	elseif not nodrain and (not targetIsDying or targetIsBoss) and not playerIsCastingOrChanneling and CastDrainLife(unit) then
		return true
	end

	if not playerIsCastingOrChanneling and not targetIsActive then
		if CastAutoTap() then
			return true
		elseif playerManaPercent >= 0.5 and CastDemonArmor() then
			return true
		end
	end

	return nil
end

function UnitIsMulticurseTarget(guid)
	return UnitExists(guid) and not UnitIsDead(guid) and UnitIsEnemy(guid) and (UnitIsTargetingParty(guid) or Cursive.core.tapped[guid] or UnitIsUnit("target", guid))
end

function MulticurseWarlockDotSpam(curse, shards, nodrain)
	for guid, time in PairsByKeys(Cursive.core.guids, CompareGuids) do
		if UnitIsMulticurseTarget(guid) and WarlockDotSpam(guid, curse, shards, nodrain) then
			TargetUnit(guid)
			return true
		end
	end

	return nil
end

function IsSquishy(unit)
	if not UnitExists(unit) then
		return -1
	end

	local c = {
		["WARRIOR"] = 0,
		["PALADIN"] = 0,
		["HUNTER"] = 1,
		["ROGUE"] = 1,
		["PRIEST"] = 2,
		["SHAMAN"] = 1,
		["MAGE"] = 2,
		["WARLOCK"] = 2,
		["DRUID"] = 0, -- TODO: Check for talent spec?
	}

	local _, class = UnitClass(unit)
	return c[class]
end

function PetTank()
	local orderFunction = function(guid1, guid2)
		local guid1Squishy = IsSquishy(guid1.."target")
		local guid2Squishy = IsSquishy(guid2.."target")

		if guid1Squishy > guid2Squishy then
			if CompareGuids(guid1, guid2) then
				return true
			elseif guid2Squishy > guid1Squishy then
				return false
			end
		else
			return false
		end
	end

	for guid, time in PairsByKeys(Cursive.core.guids, orderFunction) do
		if UnitExists(guid.."target") and IsSquishy(guid.."target") > 0 and UnitIsMulticurseTarget(guid) and CheckInteractDistance(guid, 4) then
			PetAttackIfNotPassive(guid)
			if UnitCreatureFamily("pet") == "Voidwalker" and UnitIsUnit("player", guid.."target") then
				CastPetSpell("Torment", guid)
			end
		elseif not UnitExists("pettarget") and UnitExists("target") then
			PetAttackIfNotPassive("target")
		end
		return
	end
end

function Shoot(unit)
	unit = unit or "target"
	if not UnitExists(unit) then
		return nil
	end

	if Cursive.playerState.autoRepeating then
		return
	else
		CastSpellByName("Shoot", unit)
	end
end
