local filter = require "Transcriptor-Filter"
local cliArgs = require "ArgParser"

local unpack = unpack or table.unpack -- Lua 5.1 compat

local function logInfo(str, ...)
	if select("#", ...) > 0 then
		str = str:format(...)
	end
	io.stderr:write(str, "\n")
end

local function usage()
	logInfo("Usage: lua ParseTranscriptor.lua --transcriptor <path to SavedVariables/Transcriptor.lua> [--entry \"[YYYY-MM-DD]@[HH:MM:SS]\" --start <log offset> --end <log offset> --player <player who logged this> --noheader]")
	os.exit(1)
end

local args = cliArgs:Parse(...)

if not args.transcriptor then
	usage()
end

local playerName = args.player
local playerGuid

local function loadTranscriptorLuaString(code)
	local env = {}
	if _VERSION == "Lua 5.1" then
		print("Lua 5.1 can choke on huge Transcriptor logs, try using a newer version of Lua if you get errors about the constant limit")
		local f, err = loadstring(code)
		if not f then error(err) end
		setfenv(f, env)
		f()
	else
		---@diagnostic disable-next-line: redundant-parameter -- project setup as Lua 5.1 because I want to stay 5.1 compatible
		local f, err = load(code, nil, nil, env)
		if not f then error(err) end
		f()
	end
	return env.TranscriptDB
end

local function jsonToLua(json)
	-- The secret TWW logs are split with some weird tool that outputs json
	-- So far this code doesn't have any dependencies, I don't feel like pulling in one just to read json, so this hack is the best I can do
	local lines = {}
	for line in json:gmatch("([^\n]*)\n?") do
		line = line:gsub("^(%s*)\"(.-)\": [%[{]%s*$", "%1[\"%2\"] = {")
		line = line:gsub("^(%s*)\"([^\"]+)\":", "%1[\"%2\"] = ")
		line = line:gsub("^(%s*)],?(%s*)$", "%1},%2")
		-- FIXME: properly support \u escapes, but what is this even? UTF-16? raw unicode codepoints (but why are they all 16 bit?)
		line = line:gsub("\\u(%x%x%x)", "U%1")
		lines[#lines + 1] = line
	end
	return "TranscriptDB = {jsonLog = " .. table.concat(lines, "\n") .. "}"
end

local function loadTranscriptorDB(fileName)
	local file, err = io.open(fileName, "rb")
	if not file then error(err) end
	local code = file:read("*a")
	if fileName:match(".json$") then
		code = jsonToLua(code)
	end
	return loadTranscriptorLuaString(code)
end

local transcriptorDB = loadTranscriptorDB(args.transcriptor)
local logName = nil
local log = nil

for k, v in pairs(transcriptorDB) do
	if not args.entry or k:sub(1, #args.entry) == args.entry then
		if log then
			print("Multiple logs found in file, use --entry to select one of the following. A unique prefix is sufficient. ")
			for entry in pairs(transcriptorDB) do
				print(entry)
			end
			os.exit(1)
		end
		log = v
		logName = k
	end
end

if not log or not logName then
	print("Could not find specified log")
	os.exit(1)
end

local firstLog = tonumber(args.start)
local lastLog = tonumber(args["end"])

local function parseEncounterEvent(line)
	local id, name, difficulty, groupSize, success = line:match("%[ENCOUNTER_[SE][TN][AD]%w*%] (%d+)#([^#]+)#(%d+)#(%d+)#?(%d*)")
	if not id then return end
	id, difficulty, groupSize = tonumber(id), tonumber(difficulty), tonumber(groupSize)
	success = success == "1"
	return id, name, difficulty, groupSize, success, line:match("%[ENCOUNTER_START%]")
end

local encounterStarts = {}
local encounterEnds = {}
local bossKills = {}
local lastEncounterIsInProgressEnd
for i, v in ipairs(log.total) do
	local id, name, difficulty, groupSize, success, isStart = parseEncounterEvent(v)
	if id then
		local entry = {offset = i, id = id, name = name, difficulty = difficulty, groupSize = groupSize, success = success}
		if isStart then
			encounterStarts[#encounterStarts + 1] = entry
		else
			encounterEnds[#encounterEnds + 1] = entry
		end
	end
	if v:find("%[IsEncounterInProgress%(%)%] false") then
		lastEncounterIsInProgressEnd = i
	end
	if v:find("%[BOSS_KILL%]") then
		bossKills[#bossKills + 1] = {offset = i, name = v:match("%d#([^#]+)#")}
	end
end

logInfo("ENCOUNTER_START events:")
for _, v in ipairs(encounterStarts) do
	logInfo("%d: %s (%d), difficulty = %d, groupSize = %d", v.offset, v.name, v.id, v.difficulty, v.groupSize)
end
logInfo("ENCOUNTER_END events:")
for _, v in ipairs(encounterEnds) do
	logInfo("%d: %s (%d) (%s), difficulty = %d, groupSize = %d", v.offset, v.name, v.id, v.success and "Kill" or "Wipe", v.difficulty, v.groupSize)
end

local function findFrameBoundaries(offset)
	-- There is sometimes relevant stuff that is triggered by ENCOUNTER_START which is not guaranteed to be after this log entry
	-- So we include the whole frame, note that timestamps across a frame are guaranteed to be identical
	local frameTimestamp = log.total[offset]:match("^(<[%d*.]*) ")
	local firstEntry, lastEntry
	for i = 1, #log.total do
		local prevLastEntry = lastEntry
		if log.total[i]:sub(1, #frameTimestamp) == frameTimestamp then
			if not firstEntry then
				firstEntry = i
			end
			lastEntry = i
		end
		if lastEntry and prevLastEntry == lastEntry then
			return firstEntry, lastEntry
		end
	end
end

if not firstLog then
	if #encounterStarts == 1 then
		-- There is sometimes relevant stuff that is triggered by ENCOUNTER_START which may be logged before the actual event
		-- So we just include the whole frame
		firstLog = findFrameBoundaries(encounterStarts[1].offset)
	elseif #encounterStarts == 0 then
		logInfo("Log has no ENCOUNTER_START, starting at offset 1, use --start to override")
		firstLog = 1
	else
		logInfo("Log contains more than one ENCOUNTER_START")
		local encounterStartHelp = {}
		for i, v in ipairs(encounterStarts) do
			encounterStartHelp[i] = v.offset .. " (" .. v.name .. ")"
		end
		print("ENCOUNTER_START at: " .. table.concat(encounterStartHelp, ", "))
		print("Use --start to select offset explicitly")
		os.exit(1)
	end
end

if not lastLog then
	if #encounterEnds == 1 then
		lastLog = encounterEnds[1].offset
		-- BOSS_KILL often triggers after ENCOUNTER_END, we want to include both to test that we don't trigger end multiple times
		local lastBossKill = #bossKills > 0 and bossKills[#bossKills].offset
		if lastBossKill and lastBossKill < lastLog + 100 then
			lastLog = math.max(lastLog, lastBossKill)
		end
		-- Same as above, include the whole frame
		lastLog = select(2, findFrameBoundaries(lastLog))
	elseif #encounterEnds == 0 then
		if lastEncounterIsInProgressEnd then
			logInfo("Log has no ENCOUNTER_END, using last IsEncounterInProgress() = false which is at %d (%d entries after this)", lastEncounterIsInProgressEnd, #log.total - lastEncounterIsInProgressEnd)
			lastLog = select(2, findFrameBoundaries(lastEncounterIsInProgressEnd))
		else
			logInfo("Log has no ENCOUNTER_END and no IsEncounterInProgress() = false, using entire log file, use --end to override")
			lastLog = #log.total
		end
	else
		logInfo("Log contains more than one ENCOUNTER_END")
		local encounterEndHelp = {}
		for i, v in ipairs(encounterEnds) do
			encounterEndHelp[i] = v.offset .. " (" .. v.name .. ")"
		end
		print("ENCOUNTER_END at: " .. table.concat(encounterEndHelp, ", "))
		print("Use --end to select offset explicitly")
		os.exit(1)
	end
end

local function guessType(str)
	if str == "nil" then
		return nil
	end
	if str == "true" then
		return true
	end
	if str == "false" then
		return false
	end
	if tostring(tonumber(str)) == str then
		return tonumber(str)
	end
	return str
end

local function guessTypes(...)
	if select("#", ...) == 1 then
		return guessType(...)
	else
		return guessType(...), guessTypes(select(2, ...))
	end
end

local hexMetatable = {
	__tostring = function(self)
		return "0x" .. ("%x"):format(self.value)
	end
}
local function hex(num)
	return setmetatable({value = num}, hexMetatable)
end

local function literal(lit)
	if type(lit) == "string" then
		return ("%q"):format(lit)
	else
		return tostring(lit)
	end
end

local function literals(...)
	if select("#", ...) == 1 then
		return literal(...)
	else
		return literal(...), literals(select(2, ...))
	end
end

local function literalsTable(...)
	local tbl = {...}
	for i = 1, select("#", ...) do
		tbl[i] = literal(select(i, ...))
	end
	return tbl
end

---@param info DBMInstanceInfo
local function getInstanceInfo(info)
	return ("{name = %s, instanceType = %s, difficultyID = %s, difficultyName = %s, difficultyModifier = %s, maxPlayers = %s, dynamicDifficulty = %s, isDynamic = %s, instanceID = %s, instanceGroupSize = %s, lfgDungeonID = %s}"):format(
		literals(info.name, info.instanceType, info.difficultyID, info.difficultyName, info.difficultyModifier, info.maxPlayers, info.dynamicDifficulty, info.isDynamic, info.instanceID, info.instanceGroupSize, info.lfgDungeonID)
	)
end

local function stripHealthInfo(name)
	return name:gsub("%([^)]+%%%)$", "")
end

local function transcribeUnitSpellEvent(event, params)
	if params:match("^PLAYER_SPELL") then
		return
	end
	-- Transcriptor has some useful extra data that we can use to reconstruct unit targets, health and power
	local unitName, unitHp, unitPower, unitTarget, unit, guid, spellId = params:match("(.*)%(([%d.]*)%%%-([%d.]*)%%%){Target:([^}]*)} .* %[%[([^:]+):([^:]+):([^%]]+)%]%]")
	unitHp = tonumber(unitHp) or 0
	unitPower = tonumber(unitPower) or 0
	return literalsTable(event, unit, guid, tonumber(spellId), unitName, unitHp, unitPower, unitTarget)
end

-- Rough attempt at flag reconstruction, not 100% correct, we could be a bit more smart here about REACTION by tracking a GUID across multiple events
-- Or using sourceFlags from a previous event to build destFlags if source flags are logged
local function reconstructFlags(name, isPlayer, isPet, isNpc)
	local flags = 0
	if isPlayer then
		if name == playerName then
			flags = flags + 0x1 -- AFFILIATION_MINE
		else
			flags = flags + 0x2 -- AFFILIATION_PARTY -- don't distinguish party vs raid
		end
		flags = flags + 0x0010  -- REACTION_FRIENDLY
		flags = flags + 0x0100  -- CONTROL_PLAYER
		flags = flags + 0x0400  -- TYPE_PLAYER
	elseif isPet then
		flags = flags + 0x0002  -- AFFILIATION_PARTY
		flags = flags + 0x0010  -- REACTION_FRIENDLY -- all pets are friendly for now
		flags = flags + 0x0100  -- CONTROL_PLAYER
		flags = flags + 0x1000  -- TYPE_PET
	elseif isNpc then
		flags = flags + 0x0008  -- AFFILIATION_OUTSIDER
		flags = flags + 0x0040  -- REACTION_HOSTILE -- all NPCs are hostile for now
		flags = flags + 0x0200  -- CONTROL_NPC
		flags = flags + 0x0800  -- TYPE_NPC
	end
	return flags
end

local flagWarningShown
local seenFriendlyCids = {}

local function transcribeCleu(rawParams)
	local params = {}
	local i = 1 -- to handle nil
	for param in rawParams:gmatch("([^#]*)") do
		params[i] = guessType(param)
		i = i + 1
	end
	local event, sourceFlags, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraArg1, extraArg2
	if params[1]:match("%[CONDENSED%]") then
		local _
		event, sourceGUID, sourceName, _, spellId, spellName = unpack(params, 1, i - 1)
		destGUID = ""
	else
		if type(params[2]) == "number" then
			event, sourceFlags, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraArg1, extraArg2 = unpack(params, 1, i - 1)
			-- clear special flags to make flags look more uniform across events
			-- deliberately doing this in a bit ugly way to not pull in a dependency on bit.* for Lua 5.1
			-- TODO: target/focus could be used to reconstruct targets, but in practice logs won't contain this info
			if sourceFlags >= 0x80000000 then -- NONE
				sourceFlags = sourceFlags - 0x80000000
			end
			if sourceFlags >= 0x80000 then -- MAINASSIST
				sourceFlags = sourceFlags - 0x80000
			end
			if sourceFlags >= 0x40000 then -- MAINTANK
				sourceFlags = sourceFlags - 0x80000
			end
			if sourceFlags >= 0x20000 then -- FOCUS
				sourceFlags = sourceFlags - 0x20000
			end
			if sourceFlags >= 0x10000 then -- TARGET
				sourceFlags = sourceFlags - 0x10000
			end
		else
			if not flagWarningShown and params[1] == "SPELL_CAST_START" then -- not all entries are logged with flags
				logInfo("Note: log doesn't contain flags, /getspells logflags to log flags in Transcriptor. Results for mods relying heavily on flags may be inaccurate, but usually this is not a problem.")
				flagWarningShown = true
			end
			event, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraArg1, extraArg2 = unpack(params, 1, i - 1)
		end
	end
	if spellId and filter.ignoredSpellIds[spellId] then
		return
	end
	local sourceCid = sourceGUID and tonumber(sourceGUID:match("Creature%-0%-%d*%-%d*%-%d*%-(%d+)") or tonumber(sourceGUID:match("GameObject%-0%-%d*%-%d*%-%d*%-(%d+)")))
	local destCid = destGUID and tonumber(destGUID:match("Creature%-0%-%d*%-%d*%-%d*%-(%d+)") or destGUID:match("GameObject%-0%-%d*%-%d*%-%d*%-(%d+)"))
	if sourceCid and filter.ignoredCreatureIds[sourceCid] or destCid and filter.ignoredCreatureIds[destCid] then
		return
	end
	local destIsPlayer = destGUID and destGUID:match("^Player%-")
	local srcIsPlayer = sourceGUID and sourceGUID:match("^Player%-")
	local destIsPet = destGUID and destGUID:match("^Pet%-")
	local srcIsPet = sourceGUID and sourceGUID:match("^Pet%-")
	local destIsPlayerOrPet = destIsPlayer or destIsPet
	local srcIsPlayerOrPet = srcIsPlayer or srcIsPet
	local destIsNpc = destGUID and (destGUID:match("^Creature-") or destGUID:match("^Vehicle-"))
	local srcIsNpc = sourceGUID and (sourceGUID:match("^Creature-") or sourceGUID:match("^Vehicle-"))
	if event == "SPELL_DAMAGE[CONDENSED]" then event = "SPELL_DAMAGE" end
	if event == "SPELL_PERIODIC_DAMAGE[CONDENSED]" then event = "SPELL_PERIODIC_DAMAGE" end
	if event == "SPELL_SUMMON" and srcIsPlayerOrPet then
		return
	end
	-- FIXME: use sourceFlags if available to filter healing and attacks of friendly totems
	if (event:match("_ENERGIZE$") or event:match("_HEAL$")) and destIsPlayerOrPet then
		return
	end
	if event:match("_HEAL$") and srcIsPlayer and destIsNpc then -- Likely healing summons, opportunity to learn summon creature IDs not yet ignored
		if destCid then
			seenFriendlyCids[destCid] = destName
		end
		return
	end

	if (event:match("^SPELL_CAST") or event == "SPELL_EXTRA_ATTACKS") and srcIsPlayerOrPet then
		return
	end
	if (event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_PERIODIC_MISSED" or event == "SPELL_MISSED" or event == "DAMAGE_SHIELD" or event == "SWING_DAMAGE" or event == "DAMAGE_SHIELD_MISSED") and srcIsPlayerOrPet then
		return
	end
	if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_APPLIED_DOSE" or event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REMOVED_DOSE" or event == "SPELL_AURA_REFRESH" then
		-- Filter buffs by non-NPCs on players (some bosses case buffs on players, e.g., purgable mind controls)
		if extraArg1 == "BUFF" and destIsPlayerOrPet and not srcIsNpc then
			return
		end
		-- Filter debuffs on NPCs cast by non-NPCs
		if extraArg1 == "DEBUFF" and destIsNpc and not srcIsNpc then
			return
		end
	end
	if srcIsNpc then
		sourceName = stripHealthInfo(sourceName)
	end
	if destIsNpc then
		destName = stripHealthInfo(destName)
	end
	if srcIsNpc then
		sourceName = stripHealthInfo(sourceName)
	end
	if destIsNpc then
		destName = stripHealthInfo(destName)
	end
	sourceFlags = sourceFlags or reconstructFlags(sourceName, srcIsPlayer, srcIsPet, srcIsNpc)
	local destFlags = reconstructFlags(destName, destIsPlayer, destIsPet, destIsNpc)
	return literalsTable(
		"COMBAT_LOG_EVENT_UNFILTERED", event,				-- skipping timestamp and hideCaster
		sourceGUID, sourceName, hex(sourceFlags), hex(0),	-- 0x0 == sourceRaidFlags, not logged
		destGUID, destName, hex(destFlags), hex(0),			-- 0x0 == destRaidFlags, not logged
		spellId, spellName, hex(0),							-- 0x0 == spellSchool, not logged
		extraArg1, extraArg2
	)
end

local function transcribeEvent(event, params)
	if event:match("^DBM_") or event:match("^NAME_PLATE_UNIT_") or event:match("BigWigs_") or event == "Echo_Log" or event == "ARENA_OPPONENT_UPDATE" then
		return
	end
	if event:match("^UNIT_SPELL") then
		return transcribeUnitSpellEvent(event, params)
	end
	if event == "PLAYER_TARGET_CHANGED" then
		-- TODO: do we ever care about player targets? typically used in filters and we don't want to filter
		return
	end
	if event == "CLEU" then
		return transcribeCleu(params)
	end
	-- Generic event
	local result = {literal(event)}
	for param in params:gmatch("([^#]*)") do
		result[#result + 1] = literal(guessType(param))
	end
	return result
end

-- TODO: this relies a lot on DBM debug logs -- we could try to make some educated guesses if we don't have these
local function getMetadataFromLog()
	local player
	local instanceInfo = {} ---@type DBMInstanceInfo
	local encounterInfo = {}
	for i, line in ipairs(log.total) do
		-- Only grab instance and encounter info from within relevant log area
		if i >= firstLog and i <= lastLog then
			if line:match("GetInstanceInfo%(%) =") then
				---@diagnostic disable-next-line: assign-type-mismatch
				instanceInfo.name, instanceInfo.instanceType, instanceInfo.difficultyID, instanceInfo.difficultyName, instanceInfo.maxPlayers, instanceInfo.dynamicDifficulty, instanceInfo.isDynamic, instanceInfo.instanceID, instanceInfo.instanceGroupSize, instanceInfo.lfgDungeonID
				= guessTypes(line:match(
					"%[DBM_Debug%] GetInstanceInfo%(%) = ([^,]+), ([^,]+), ([^,]+), ([^,]+), ([^,]+), ([^,]+), ([^,]+), ([^,]+), ([^#]+)"
				))
			elseif line:match("DBM:GetCurrentInstanceDifficulty%(%) = normal20, 20 Player%+ %(%d%)") then -- SoD/Molten Core heat levels
				local modifier = line:match("%((%d)%)")
				instanceInfo.difficultyModifier = tonumber(modifier) or 0
			elseif line:match("%[ENCOUNTER_[SE][TN][AD]") then
				local id, name, difficulty, _, success, isStart = parseEncounterEvent(line)
				if not encounterInfo.id or id == encounterInfo.id then -- multiple different encounters in one log? you'll have to do something by hand
					encounterInfo.id = id
					encounterInfo.name = name
					encounterInfo.difficulty = difficulty
					if not isStart then
						encounterInfo.kill = success
					end
				end
			end
		end
		-- But we can grab the player id from anywhere
		if not player then
			player = line:match("%[UNIT_SPELLCAST_SUCCEEDED%] PLAYER_SPELL{([^}]+)} %-.*%- %[%[player:Cast%-")
		end
	end
	return player, instanceInfo, encounterInfo, logName:match("Version: 1%.") and "SeasonOfDiscovery" or "Retail" -- FIXME: distinguish SoD and Era somehow (but the field is unused right now anyways)
end

local deducedPlayer, instanceInfo, encounterInfo, gameVersion = getMetadataFromLog()
playerName = playerName or deducedPlayer

local function buildAnonTable()
	-- TODO: actually build the anonymization table here, currently this is just used to get info about the logging player
	for i = firstLog, lastLog do -- do we want to use the entire log or just the segment we are looking at? probably saver to restrict to the segment
		local line = log.total[i]
		local guid, name = line:match("^<[%d.]+ [^>]+> %[CLEU%] SPELL_[^#]+##?%d*#?(Player%-[^#]+)#([^#]+)")
		-- grab GUID of logging player, easer to do here than in getMetadataFromLog above because above we grab it from UCS which doesn't have GUIDs
		if name == playerName then
			playerGuid = guid
		end
	end
end

local function getLog()
	local result = {}
	local timeOffset
	local totalTime = 0
	local logContainsLoggingPlayer = false
	buildAnonTable()
	for i = firstLog, lastLog do
		local line = log.total[i]
		local time, event, params = line:match("^<([%d.]+) [^>]+> %[([^%]]*)%] (.*)")
		time = tonumber(time) or error("unparseable timestamp in " .. line)
		totalTime = time
		if not tonumber(time) or not event or not params then
			error("unparseable line" .. line)
		end
		timeOffset = timeOffset or time
		time = time - timeOffset
		local testEvent = transcribeEvent(event, params)
		if not logContainsLoggingPlayer and playerGuid and testEvent and event == "CLEU" then
			local quotedPlayerGuid = "\"" .. playerGuid .. "\""
			if testEvent[3] == quotedPlayerGuid  or testEvent[7] == quotedPlayerGuid then
				logContainsLoggingPlayer = true
			end
		end
		if testEvent then
			result[#result + 1] = ("{%.2f, %s},"):format(time, table.concat(testEvent, ", "))
		end
	end
	logInfo("Parsed %d lines into %d lines (%.1f%% filtered)", lastLog - firstLog + 1, #result, (1 - #result / (lastLog - firstLog + 1)) * 100)
	logInfo("%.1f seconds total, %.0f entries/second", totalTime, #result / totalTime)
	local resultStr = ""
	if playerName ~= deducedPlayer then
		resultStr = "-- Warning: log was created by player " .. deducedPlayer .. ", but player " .. playerName .. " was given on the CLI for reconstructions, this can potentially cause problems (but is usually fine)\n\t"
	end
	-- Ugly hack to prevent problems where the logging player is not in any of the filtered events
	if not logContainsLoggingPlayer then
		if not playerGuid then
			error("log does not seem to contain logging player " .. playerName)
		end
		table.insert(result, 1,
			"{0.00, \"COMBAT_LOG_EVENT_UNFILTERED\", \"SPELL_CAST_SUCCESS\", \"" .. playerGuid .. "\", \"" .. playerName .. "\", 0x511, 0x0, \"" .. playerGuid .. "\", \"" .. playerName .. "\", 0x511, 0x0, 0, \"Fake spell to ensure logging player has at least one entry, this is added if the logging player would not show up otherwise, please ignore this entry\", 0x0, nil, nil},"
		)
	end
	resultStr = resultStr .. "log = {\n\t\t"
	resultStr = resultStr ..  table.concat(result, "\n\t\t")
	resultStr = resultStr ..  "\n\t}"
	return resultStr
end

local template = [[
DBM.Test:DefineTest{
	name = %s,
	gameVersion = %s,
	addon = %s,
	mod = %s,
	instanceInfo = %s,
	%s,
}]]

local function guessMod()
	if not encounterInfo.name then return "" end
	return encounterInfo.name:gsub("%s*", ""):gsub("'", "")
end

-- TODO: all of these guessing functions could be much smarter, but I'm adding stuff as I go
local function guessTestName()
	if not encounterInfo.name then return "" end
	local difficulty = ""
	if instanceInfo.instanceID == 409 and instanceInfo.difficultyModifier then -- MC heat levels
		difficulty = "Heat-" .. instanceInfo.difficultyModifier .. "/"
	end
	local name = guessMod() .. "/" .. difficulty .. (encounterInfo.kill and "Kill" or "Wipe")
	if args.prefix then
		return args.prefix:gsub("/$", "") .. "/" .. name
	else
		logInfo("Use --prefix to provide a prefix for test name")
		return name
	end
end

local function guessAddon()
	if gameVersion == "SeasonOfDiscovery" then
		if instanceInfo.instanceType == "raid" then
			-- Onyxia and the outdoor bosses are for 40 players, but luckily Onyxia uses a different difficulty ID
			return instanceInfo.maxPlayers == 40 and instanceInfo.difficultyID == 9 and "DBM-Azeroth"
				or "DBM-Raids-Vanilla"
		elseif instanceInfo.instanceType == "party" then -- UBRS & co also return party here
			return "DBM-Party-Vanilla"
		end
	end
	return ""
end

local function generateTest()
	local str = template:format(
		literal(guessTestName()), literal(gameVersion), literal(guessAddon()), literal(guessMod()),
		getInstanceInfo(instanceInfo),
		getLog()
	)
	return str
end

local function generateLogOnly()
	return ("\t%s\n}\n"):format(getLog())
end

if args.noheader then
	print(generateLogOnly())
else
	print(generateTest())
end

if next(seenFriendlyCids) then
	logInfo("Potentially ignoreable creature IDs (healed by players):")
	for cid, name in pairs(seenFriendlyCids) do
		logInfo(cid .. ", -- " .. name)
	end
end
