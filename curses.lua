if not Cursive.superwow then
	return
end

local curses = {
	trackedCurseIds = {},
	trackedCurseNamesToTextures = {},
	guids = {},
	resistSoundGuids = {},
	expiringSoundGuids = {},
	requestedExpiringSoundGuids = {} -- guid added on spellcast, moved to expiringSoundGuids once rendered by ui
}

-- combat events for curses
local afflict_test = "^(.+) is afflicted by (.+) %((%d+)%)" -- for stacks 2-5 will be "Fire Vulnerability (2)".
local gains_test = "^(.+) gains (.+) %((%d+)%)"             -- for stacks 2-5 will be "Fire Vulnerability (2)".
local fades_test = "(.+) fades from (.+)"
local resist_test = "Your (.+) was resisted by (.+)"

local lastGuid = nil

function curses:LoadCurses()
	-- curses to track
	local _, className = UnitClass("player")
	if className == "WARLOCK" then
		curses.trackedCurseIds = getWarlockSpells()
	elseif className == "PRIEST" then
		curses.trackedCurseIds = getPriestSpells()
	elseif className == "MAGE" then
		curses.trackedCurseIds = getMageSpells()
	elseif className == "DRUID" then
		curses.trackedCurseIds = getDruidSpells()
	elseif className == "HUNTER" then
		curses.trackedCurseIds = getHunterSpells()
	elseif className == "ROGUE" then
		curses.trackedCurseIds = getRogueSpells()
	end

	for id, data in pairs(curses.trackedCurseIds) do
		-- get the texture
		local name, rank, texture = SpellInfo(id)
		-- update trackedCurseNamesToTextures
		curses.trackedCurseNamesToTextures[data.name] = texture
		-- update trackedCurseIds
		curses.trackedCurseIds[id].texture = texture
	end
end

function curses:ScanGuidForCurse(guid, curseSpellID, curseSpellName)
	local texture = curses.trackedCurseNamesToTextures[curseSpellName]

	for i = 1, 16 do
		local spellName, _, _, spellID = UnitDebuff(guid, i)
		if spellID and curseSpellID then
			if spellID == curseSpellID then
				return true
			end
		elseif spellName and texture then
			if spellName == texture then
				return true
			end
		else
			break
		end
	end

	for i = 1, 32 do
		local spellName, _, spellID = UnitBuff(guid, i)
		if spellID and curseSpellID then
			if spellID == curseSpellID then
				return true
			end
		elseif spellName and texture then
			if spellName == texture then
				return true
			end
		else
			break
		end
	end

	return nil
end

Cursive:RegisterEvent("UNIT_CASTEVENT", function(casterGuid, targetGuid, event, spellID, castDuration)
	-- immolate will fire both start and cast
	if event == "CAST" then
		if UnitIsUnit(casterGuid, "player") and curses.trackedCurseIds[spellID] then
			lastGuid = targetGuid
			curses:ApplyCurse(spellID, targetGuid, GetTime())
		end
	end

	if UnitIsUnit(casterGuid, "player") then
		local spellName = SpellInfo(spellID)
		if event == "START" then
			Cursive.playerState.casting = spellName
		elseif event == "CHANNEL" then
			Cursive.playerState.channeling = spellName
		elseif event == "CAST" or event == "CHANNEL" or event == "FAIL" then
			Cursive.playerState.casting = nil
			Cursive.playerState.channeling = nil
		end
	end

	if event == "CAST" or event == "CHANNEL" or event == "MAINHAND" or event == "OFFHAND" then
		if not UnitIsTapped(targetGuid) and UnitIsInParty(casterGuid) then
			Cursive.core.tapped[targetGuid] = { casterGuid, event, spellID }
		end
	end
end)

Cursive:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE",
	function(message)
		-- check for resist
		local _, _, spell, target = string.find(message, resist_test)
		if spell and target then
			if curses.trackedCurseNamesToTextures[spell] and lastGuid and not curses:ScanGuidForCurse(lastGuid, nil, spell) then
				curses:RemoveCurse(lastGuid, spell)
				-- check if sound should be played
				if curses:ShouldPlayResistSound(lastGuid) then
					PlaySoundFile("Interface\\AddOns\\Cursive\\Sounds\\resist.mp3")
				end
			end
		end
	end
) -- resists

Cursive:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER", function(message)
	-- check if spell that faded is relevant
	local _, _, spell, target = string.find(message, fades_test)
	if spell and target then
		if curses.trackedCurseNamesToTextures[spell] then
			-- loop through targets with active curses
			for guid, data in pairs(curses.guids) do
				for curseName, curseData in pairs(data) do
					if curseName == spell then
						-- see if target still has that curse
						if not curses:ScanGuidForCurse(guid, curseData.spellID) then
							-- remove curse
							curses:RemoveCurse(guid, curseName)
						end
					end
				end
			end
		end
	end
end
)

function curses:TimeRemaining(curseData)
	return math.ceil(curseData.duration - (GetTime() - curseData.start))
end

function curses:EnableResistSound(guid)
	curses.resistSoundGuids[guid] = true
end

function curses:EnableExpiringSound(spellNameNoRank, guid)
	if curses.requestedExpiringSoundGuids[guid] and curses.requestedExpiringSoundGuids[guid][spellNameNoRank] then
		curses.requestedExpiringSoundGuids[guid][spellNameNoRank] = nil
	end

	if not curses.expiringSoundGuids[guid] then
		curses.expiringSoundGuids[guid] = {}
	end
	curses.expiringSoundGuids[guid][spellNameNoRank] = true
end

function curses:RequestExpiringSound(spellNameNoRank, guid)
	if not curses.requestedExpiringSoundGuids[guid] then
		curses.requestedExpiringSoundGuids[guid] = {}
	end
	curses.requestedExpiringSoundGuids[guid][spellNameNoRank] = true
end

function curses:HasRequestedExpiringSound(spellNameNoRank, guid)
	return curses.requestedExpiringSoundGuids[guid] and curses.requestedExpiringSoundGuids[guid][spellNameNoRank]
end

function curses:ShouldPlayExpiringSound(spellNameNoRank, guid)
	if curses.expiringSoundGuids[guid] and curses.expiringSoundGuids[guid][spellNameNoRank] then
		curses.expiringSoundGuids[guid][spellNameNoRank] = nil -- remove entry to avoid playing sound multiple times
		return true
	end

	return false
end

function curses:ShouldPlayResistSound(guid)
	if curses.resistSoundGuids[guid] then
		curses.resistSoundGuids[guid] = nil -- remove entry to avoid playing sound multiple times
		return true
	end

	return false
end

function curses:HasAnyCurse(guid)
	if curses.guids[guid] and next(curses.guids[guid]) then
		return true
	end
	return nil
end

function curses:HasCurse(spellName, targetGuid, minRemaining)
	if not minRemaining then
		minRemaining = 0 -- default to 0
	end

	if curses.guids[targetGuid] and curses.guids[targetGuid][spellName] then
		local remaining = Cursive.curses:TimeRemaining(curses.guids[targetGuid][spellName])
		if remaining > minRemaining then
			return true
		end
	end
	return nil
end

function curses:ApplyCurse(spellID, targetGuid, startTime)
	local name = curses.trackedCurseIds[spellID].name
	local rank = curses.trackedCurseIds[spellID].rank
	local duration = curses.trackedCurseIds[spellID].duration

	if not curses.guids[targetGuid] then
		curses.guids[targetGuid] = {}
	end

	curses.guids[targetGuid][name] = {
		rank = rank,
		duration = duration,
		start = startTime,
		spellID = spellID,
	}
end

function curses:RemoveCurse(guid, curseName)
	if curses.guids[guid] and curses.guids[guid][curseName] then
		curses.guids[guid][curseName] = nil
	end
	if curses.expiringSoundGuids[guid] and curses.expiringSoundGuids[guid][curseName] then
		curses.expiringSoundGuids[guid][curseName] = nil
	end
end

function curses:RemoveGuid(guid)
	curses.guids[guid] = nil
	curses.resistSoundGuids[guid] = nil
	curses.expiringSoundGuids[guid] = nil
	curses.requestedExpiringSoundGuids[guid] = nil
end

Cursive.curses = curses
