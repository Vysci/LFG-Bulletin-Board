local tocName,
---@class Addon_DungeonData: Addon_Localization
addon = ...;
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local Expansion = {
	Classic = 0,
	BurningCrusade = 1,
	Wrath = 2,
	Cataclysm = 3,
	Mists = 4,
}
local ExpansionByProjectID = {
	[WOW_PROJECT_CLASSIC] = Expansion.Classic,
    [WOW_PROJECT_BURNING_CRUSADE_CLASSIC] = Expansion.BurningCrusade,
    [WOW_PROJECT_WRATH_CLASSIC] = Expansion.Wrath,
    [WOW_PROJECT_CATACLYSM_CLASSIC] = Expansion.Cataclysm,
	-- fallback for classic era clients. Remove when blizz adds the mists project ID to globals
    [WOW_PROJECT_MISTS_CLASSIC or 19] = Expansion.Mists,
}
Expansion.Current = ExpansionByProjectID[WOW_PROJECT_ID]

-- These enums are somewhat inline with the TypeID column of https://wago.tools/db2/LFGDungeons
-- todo: unify at some point. This was more important when i was using GetLFGDungeonInfo API.
local DungeonType = isClassicEra and {
	Dungeon = 1,
    Raid = 2,
    None = 4,
    Battleground = 5, -- in classic, 5 is used for BGs
    WorldBoss = 6,
} or {
	Dungeon = 1,
	Raid = 2,
	Zone = 4,
	Random = 6,
	Battleground = 7
}
---@class AddonEnum
addon.Enum = addon.Enum or {}
addon.Enum.Expansions = Expansion
addon.Enum.DungeonType = DungeonType
function addon.GetExpansionEnumForProjectID(projectID)
	assert(projectID, "Invalid projectID passed to GetExpansionEnumForProjectID")
	return ExpansionByProjectID[projectID]
end

-- NOTE: For now only use the following API's to generate the cata/mists dungeon info
-- For classic it can remain self contained in the `classic.lua` file until tbc refactoring
if WOW_PROJECT_ID < WOW_PROJECT_CATACLYSM_CLASSIC then return end

--see https://wago.tools/db2/GroupFinderCategory?build=5.5.0.61208
local activityCategoryDungeonType  = {
    [2] = DungeonType.Dungeon ,
    [114] = DungeonType.Raid,
    [118] = DungeonType.Battleground,
}
local activityGroupExpansion = {
	-- Classic Dungeons
	[285] = { expansionID = Expansion.Classic, typeID = DungeonType.Dungeon },
	-- Classic Raids
	[290] = { expansionID = Expansion.Classic, typeID = DungeonType.Raid },
	-- Burning Crusade Dungeons
	[286] = { expansionID = Expansion.BurningCrusade, typeID = DungeonType.Dungeon },
	-- Burning Crusade Raids
	[291] = { expansionID = Expansion.BurningCrusade, typeID = DungeonType.Raid },
	-- Lich King Dungeons
	[287] = { expansionID = Expansion.Wrath, typeID = DungeonType.Dungeon },
	-- Lich King Raids
	[292] = { expansionID = Expansion.Wrath, typeID = DungeonType.Raid },
	-- Cataclysm Raids
	[364] = { expansionID = Expansion.Cataclysm, typeID = DungeonType.Raid },
	-- Cataclysm Dungeons
	[368] = { expansionID = Expansion.Cataclysm, typeID = DungeonType.Dungeon },
	-- Mists of Pandaria Dungeons
	[389] = { expansionID = Expansion.Mists, typeID = DungeonType.Dungeon },
	-- Mists of Pandaria Raids
	[385] = { expansionID = Expansion.Mists, typeID = DungeonType.Raid },
	-- Holiday Dungeons (treat as latest xpac dungeons, Related issue: #253)
	[294] = { expansionID = Expansion.Current, typeID = DungeonType.Dungeon },
	-- Arena & Battlegrounds (map to latest expansion)
	[299] = { expansionID = Expansion.Current, typeID = DungeonType.Battleground }
}
do -- link groupIDs to ones that share expansion and dungeon types
	local groupIdMap = {
		[288] = 286, -- Burning Crusade Heroic Dungeons
		[289] = 287, -- Lich King Heroic Dungeons
		[311] = 287, -- Titan Rune Alpha
		[312] = 287, -- Titan Rune Beta
		[314] = 287, -- Titan Rune Gamma
		[293] = 292, -- Lich King Normal Raids (25)
		[320] = 292, -- Lich King Heroic Raids (10)
		[321] = 292, -- Lich King Heroic Raids (25)
		[300] = 299, -- Battlegrounds
		[301] = 299, -- World PvP Events
		[365] = 364, -- Cataclysm Heroic Raids (10)
		[366] = 364, -- Cataclysm Normal Raids (25)
		[367] = 364, -- Cataclysm Heroic Raids (25)
		[369] = 368, -- Cataclysm Heroic Dungeons
		[376] = 368, -- Elemental Rune Inferno
		[379] = 368, -- Elemental Rune Twilight
		[383] = 389, -- Celestial Dungeons
		[390] = 389, -- Mists of Pandaria Heroic Dungeons
		[384] = 385, -- Celestial Fear
		[386] = 385, -- Pandaria Heroic Raids (10)
		[387] = 385, -- Pandaria Normal Raids (25)
		[388] = 385, -- Pandaria Heroic Raids (25)
	}
	for link, source in pairs(groupIdMap) do
		activityGroupExpansion[link] = activityGroupExpansion[source]
	end
end

local currentMaxLevel = GetMaxPlayerLevel()
local getBestActivityLevelRange = function(tagKey, activityInfo)
	local min = activityInfo.minLevelSuggestion or activityInfo.minLevel
	local max = activityInfo.maxLevelSuggestion or activityInfo.maxLevel
	if min == 0 then min = max end
	return min, Clamp(max, 0, currentMaxLevel)
end
local getBestActivityName = function(activityInfo, typeID, expansionID)
	if typeID == DungeonType.Battleground -- battlegrounds and pre-Wotlk raids use fullname for tranlsations
	or ((expansionID and expansionID < Expansion.Wrath) and typeID == DungeonType.Raid) then
		return (activityInfo.fullName and activityInfo.fullName ~= "" and activityInfo.fullName)
			or activityInfo.shortName
	end
	return (activityInfo.shortName and activityInfo.shortName ~= "" and activityInfo.shortName)
    or activityInfo.fullName
end
local uniqueIdInfoCache = {}
--- note: multiple activityID's can map to the same dungeon/tag key.
--- This table only tracks the state for the last ID passed to `cacheActivityInfo`
local infoByTagKey = {}
local activityIDToKey = {}
local numDungeons = 0
local queuedForCache = {}

local queueActivityInfo =function (activityIDs, tagKey, overrides)
    assert(next(activityIDs) and tagKey, "Invalid arguments to cacheActivityInfo: ", activityIDs, tagKey)
    queuedForCache[tagKey] = queuedForCache[tagKey] or {}
    queuedForCache[tagKey].activityIDs = activityIDs
    if overrides then
        if not queuedForCache[tagKey].overrides then
            queuedForCache[tagKey].overrides = overrides
        else
            for key, value in pairs(overrides) do
                queuedForCache[tagKey].overrides[key] = value
            end
        end
    end
end
---@param activityID number ActivityID (or non colliding spoofed ID)
---@param tagKey string
local function cacheActivityInfo(activityID, tagKey, overrides)
    local info = { tagKey = tagKey }
    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if activityInfo then -- spoofed entries will be nil
        local additionalInfo = activityGroupExpansion[activityInfo.groupFinderActivityGroupID]
        local typeID = activityCategoryDungeonType[activityInfo.categoryID]
        assert(typeID == additionalInfo.typeID, "Debug Check failed. Mismatch TypeID needs to be handled for activity", activityID, typeID, additionalInfo.typeID)
        local minLevel, maxLevel = getBestActivityLevelRange(tagKey, activityInfo)
        info = {
            name = getBestActivityName(activityInfo, typeID, additionalInfo.expansionID),
            minLevel = minLevel,
            maxLevel = maxLevel,
            expansionID = additionalInfo.expansionID,
            typeID = typeID,
            tagKey = tagKey,
        }
    end
    if overrides then
        for key, value in pairs(overrides) do
            info[key] = value
        end
    end
    -- this is is here verify no overlap in ID's between LFGDungeonIDs and ActivityIDs
    assert(not uniqueIdInfoCache[activityID], "Duplicate ID found for activity ID: " .. activityID, "Use a different dungeonID for this dungeon or different activityID", activityInfo)

    assert(info.name and info.name ~= "", "Failed to get name for activityID: " .. activityID, activityInfo)
    assert(info.minLevel and info.maxLevel, "Failed to get level range for activityID: " .. activityID, activityInfo)
    assert(info.expansionID, "Failed to get expansionID for activityID: " .. activityID, activityInfo)
    assert(info.typeID, "Failed to get typeID for activityID: " .. activityID, activityInfo)

    uniqueIdInfoCache[activityID] = info
    infoByTagKey[tagKey] = info
    numDungeons = numDungeons + 1
end
addon.Dungeons = {
    queueActivityInfo = queueActivityInfo,
    infoByTagKey = infoByTagKey,
    numDungeons = numDungeons,
    activityGroupExpansion = activityGroupExpansion,
    activityCategoryDungeonType = activityCategoryDungeonType,
    -- Hack, defer the querying of data until all the valid expansion data files have settled
    -- this ensure they've gotten the chance to override any changed activityIDs
    ProcessActivityInfo = function()
        for tagKey, queued in pairs(queuedForCache) do
            assert(type(queued.activityIDs) == "table", "Invalid queued activityIDs for tagKey: " .. tagKey, queued.activityIDs)
            for _, activityID in ipairs(queued.activityIDs) do
                if not activityIDToKey[activityID] then
                    activityIDToKey[activityID] = tagKey
                end
                cacheActivityInfo(activityID, tagKey, queued.overrides)
            end
        end
    end
}
---@param dungeonKey string
---@return (DungeonInfo|table<DungeonID, DungeonInfo>)? 
function addon.GetDungeonInfo(dungeonKey, useRef)
    if dungeonKey then
        local info = infoByTagKey[dungeonKey]
        if info then
            return useRef and info or CopyTable(info)
        end
    end
end

local isHolidayActive = function(key)
	local seasonal = {
		["BREW"] = { start = "09/20", stop = "10/06"},
		["HOLLOW"] = { start = "10/18", stop = "11/01"},
		["LOVE"] = {start = "02/03", stop = "02/17"},
		["SUMMER"] = {start = "06/21", stop = "07/05"},
	}
	if not seasonal[key] then return false end
	local active = addon.Tool.InDateRange(seasonal[key].start, seasonal[key].stop)
	if not active -- hack: disable filtering for any inactive holiday dungeons
	and GroupBulletinBoardDBChar -- should only modify after savedVars is loaded
	and GroupBulletinBoardDBChar["FilterDungeon"..key]
	then -- previously done in `FixFilters()`
		GroupBulletinBoardDBChar["FilterDungeon"..key] = nil
	end
	return active
end

--Optionally filter by expansionID and/or typeID
---@param expansionID ExpansionID?
---@param typeID DungeonTypeID|DungeonTypeID[]?
---@return string[]
function addon.GetSortedDungeonKeys(expansionID, typeID)
	local keys = {}
	for tagKey, info in pairs(infoByTagKey) do
		if (not expansionID or info.expansionID == expansionID) 
		and (not typeID 
			or (type(typeID) == "number" and info.typeID == typeID)
			or (type(typeID) == "table" and tContains(typeID, info.typeID)))
		and (not info.isHoliday or isHolidayActive(tagKey))
		-- not actually dungeons
		and (tagKey ~= "DM2" and tagKey ~= "SM2" and tagKey ~= "NULL")
		then
			tinsert(keys, tagKey)
		end
	end
	local isRated = { -- move this to a trait on the info table
		RBG = true,
		ARENA = true
	}
	table.sort(keys, function(keyA, keyB)
		local infoA = infoByTagKey[keyA];
        local infoB = infoByTagKey[keyB];
        if infoA.typeID == infoB.typeID then
            if infoA.minLevel == infoB.minLevel then
                if infoA.maxLevel == infoB.maxLevel then
					-- Edge case: Sort RBGS and ARENAS *after* normal bgs.
					if not isRated[keyA] and isRated[keyB] then
						return true
					elseif isRated[keyA] and not isRated[keyB] then
						return false
					end

                    if infoA.name == infoB.name then
                        return keyA < keyB
                    else return infoA.name < infoB.name end
                else return infoA.maxLevel < infoB.maxLevel end
            else return infoA.minLevel < infoB.minLevel end
        else return infoA.typeID < infoB.typeID end
	end)
	return keys
end

---Optionally filter by expansionID and/or typeID
---@param expansionID ExpansionID?
---@param typeID DungeonTypeID?
function addon.GetDungeonLevelRanges(expansionID, typeID)
	local ranges = {}
	for tagKey, info in pairs(infoByTagKey) do
		if (not expansionID or info.expansionID == expansionID) 
		and (not typeID or info.typeID == typeID) 
		-- ignore NULL entries. But they really should be rectified at somepoint
		and tagKey ~= "NULL"
		then
			ranges[tagKey] = {info.minLevel, info.maxLevel}
		end
	end
	return ranges
end

---@param opts {activityID: number}
function addon.GetDungeonKeyByID(opts)
    local key = activityIDToKey[opts.activityID]
    if key ~= nil then return key end;
    -- if no key, fallback to a name match
    local activityInfo = C_LFGList.GetActivityInfoTable(opts.activityID)
    if not activityInfo then return end
	local auxInfo = activityGroupExpansion[activityInfo.groupFinderActivityGroupID] or {}
	local name = getBestActivityName(activityInfo, auxInfo.typeID, auxInfo.expansionID)
    for key, cacheInfo in pairs(infoByTagKey) do
        if cacheInfo.name == name then return key; end
    end
end
