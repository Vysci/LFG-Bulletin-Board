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

--- By design queued activityID's for a key are replaced on repeat calls.
--- This allows overridding any stale/changed activityIDs from expansion to expansion.
---@param activityKey string also called the `dungeonKey`. String identifier for the dungeon.
---@param activityIDs number[] List of activityIDs to use for ripping client information about this dungeon.
local queueActivityForInfo =function (activityKey, activityIDs)
    assert(next(activityIDs) and activityKey, "Invalid arguments to cacheActivityInfo: ", activityIDs, activityKey)
    queuedForCache[activityKey] = queuedForCache[activityKey] or {}
    queuedForCache[activityKey].activityIDs = activityIDs
end
--- Can be called multiple times per dungeonKey. Repeat call to replace any previous existing override kvs.
---@param activityKey string
---@param overrides DungeonInfo|table Partial DungeonInfo to override.
local queueActivityInfoOverride = function(activityKey, overrides)
	assert(queuedForCache[activityKey], "No queued activityIDs for tagKey. Queue activity with queueActivityInfo first. ", activityKey)
	if not queuedForCache[activityKey].overrides then
		queuedForCache[activityKey].overrides = overrides
	else
		for key, value in pairs(overrides) do
			queuedForCache[activityKey].overrides[key] = value
		end
	end
end
--- Gets the `DungeonInfo` for all queued activities, applies any overrides, and verifies all the required addon data is present.
---@param activityID number ActivityID (or non colliding spoofed ID)
---@param activityKey string
local function parseAndCacheActivityInfo(activityID, activityKey, overrides)
    local info;
    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if activityInfo then -- spoofed entries will be nil
        local additionalInfo = activityGroupExpansion[activityInfo.groupFinderActivityGroupID]
        local typeID = activityCategoryDungeonType[activityInfo.categoryID]
        assert(typeID == additionalInfo.typeID, "Debug Check failed. Mismatch TypeID needs to be handled for activity", activityID, typeID, additionalInfo.typeID)
        local minLevel, maxLevel = getBestActivityLevelRange(activityKey, activityInfo)
        info = { ---@type DungeonInfo
            name = getBestActivityName(activityInfo, typeID, additionalInfo.expansionID),
            minLevel = minLevel,
            maxLevel = maxLevel,
            expansionID = additionalInfo.expansionID,
            typeID = typeID,
            tagKey = activityKey,
        }
    else info = { tagKey = activityKey } end
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
    infoByTagKey[activityKey] = info
    numDungeons = numDungeons + 1
end
addon.Dungeons = {
    queueActivityForInfo = queueActivityForInfo,
	queueActivityInfoOverride = queueActivityInfoOverride,
    infoByTagKey = infoByTagKey,
    numDungeons = numDungeons,
    activityGroupExpansion = activityGroupExpansion,
    activityCategoryDungeonType = activityCategoryDungeonType,
    -- NOTE: Defer the querying of data until all the files in `/dungeons/` have been loaded
	-- and any overriding `queueActivityForInfo`/`queueActivityInfoOverride` calls have been made.
    ProcessActivityInfo = function()
        for tagKey, queued in pairs(queuedForCache) do
            assert(type(queued.activityIDs) == "table", "Invalid queued activityIDs for tagKey: " .. tagKey, queued.activityIDs)
            for _, activityID in ipairs(queued.activityIDs) do
                if not activityIDToKey[activityID] then
                    activityIDToKey[activityID] = tagKey
                end
                parseAndCacheActivityInfo(activityID, tagKey, queued.overrides)
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
