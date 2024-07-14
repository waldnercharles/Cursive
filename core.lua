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
Cursive.playerState = { casting = nil, channeling = nil, x = nil, y = nil, moving = nil }

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
end

Cursive.core.disable = function()
	Cursive.core:UnregisterAllEvents()
	Cursive.core.guids = {}
end

Cursive.core:SetScript("OnEvent", function()
	if event == "PLAYER_TARGET_CHANGED" then
		this.add("target")
	else
		-- arg1 is guid
		this.addGuid(arg1)
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

function CompareGuids(guid1, guid2)
	local guid1inRange = CheckInteractDistance(guid1, 4)
	local guid2inRange = CheckInteractDistance(guid2, 4)

	local guid1IsMulticurseTarget = UnitIsMulticurseTarget(guid1)
	local guid2IsMulticurseTarget = UnitIsMulticurseTarget(guid2)

	if guid1inRange and not guid2inRange then
		return true
	elseif guid2inRange and not guid1inRange then
		return false
	elseif guid1IsMulticurseTarget and not guid2IsMulticurseTarget then
		return true
	elseif guid2IsMulticurseTarget and not guid1IsMulticurseTarget then
		return false
	else
		return UnitHealth(guid1) > UnitHealth(guid2)
	end
end
