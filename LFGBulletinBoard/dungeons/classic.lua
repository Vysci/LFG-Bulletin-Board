local tocName, 
    ---@class Addon_DungeonData
    addon = ...;
    
if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then return end
---@alias DungeonID number
---@alias ActivityID number

---@class DungeonInfo
---@field name string # Game client localized name of the dungeon
---@field minLevel number
---@field maxLevel number
---@field typeID DungeonTypeID -- 1 = dungeon, 2 = raid, 5 = bg
---@field expansionID ExpansionID
---@field tagKey string # The key used to identify the dungeon in the addon
---@field size number? # The size of the dungeon, only used for raids and battlegrounds
---@field isHoliday boolean? # If the dungeon is a holiday event

-- Required APIs. Exist in classic even though no Dungeon Finder.
assert(GetLFGDungeonInfo, tocName .. " requires the API `GetLFGDungeonInfo` for parsing dungeon info")
assert(C_LFGList.GetActivityInfoTable, tocName .. " requires the API `C_LFGList.GetActivityInfoTable` for parsing dungeon info")

-- initialize here for now, this should be moved to a file thats always guarantied to load first.
---@class AddonEnum
addon.Enum = {} 


---@enum DungeonTypeID # note that the actual value of the enum maybe be different depending on the client version.
local DungeonType = {
    Dungeon = 1,
    Raid = 2,
    None = 4,
    Battleground = 5, -- in classic, 5 is used for BGs
}

---@enum ExpansionID
local Expansions = {
	Classic = 0,
	BurningCrusade = 1,
	Wrath = 2,
	Cataclysm = 3,
}

local isSoD = C_Seasons and (C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery)

local debug = false
local print = function(...) if debug then print(tocName, ...) end end

-- hacky solution to manually tack on the dungeon size.
-- this is only used for the classic era client. since its small enough to hardcode.
-- `nil` is assumed to be 5
local dungeonSizes = {
    -- BGs
    [53] = 10,  -- WSG
    [55] = 15,  -- AB
    [51] = 40,  -- AV
    -- Dungeons
    [31] = 10,  -- LBRS
    [43] = 10,  -- UBRS
    -- Raids
    [41] = 20,  -- ZG
    [160] = 20, -- AQ20
    [47] = 40,  -- MC
    [45] = 40,  -- Ony
    [49] = 40,  -- BWL
    [161] = 40, -- AQ40
    [159] = 40, -- Naxx
}

-- manually associate keys in Tags.lua
--see https://wago.tools/db2/LFGDungeons?build=1.15.2.54332
local LFGDungeonIDs = {
    ["RFC"] = 3,  -- Ragefire Chasm
    ["WC"] = 1,  -- Wailing Caverns
    ["DM"] = 5,  -- Deadmines
    ["SFK"] = 7,  -- Shadowfang Keep
    ["STK"] = 11, -- Stormwind Stockades
    ["BFD"] = 9,  -- Blackfathom Deeps
    ["GNO"] = 13,  -- Gnomeregan
    ["RFK"] = 15,  -- Razorfen Kraul
    ["SM2"] = 17,  -- Scarlet Monastery
    ["RFD"] = 19,  -- Razorfen Downs
    ["ULD"] = 21,  -- Uldaman
    ["ZF"] = 23,  -- Zul'Farrak
    ["MAR"] = 25,  -- Maraudon
    ["ST"] = 27,  -- Sunken Temple
    ["BRD"] = 29,  -- Blackrock Depths
    ["DM2"] = 32,  -- Dire Maul [base]
    ["DME"] = 33,  -- Dire Maul - East
    ["DMN"] = 37,  -- Dire Maul - North
    ["DMW"] = 35,  -- Dire Maul - West
    ["STR"] = 39,  -- Stratholme
    ["SCH"] = 2,  -- Scholomance
    ["LBRS"] = 31,  -- Lower Blackrock Spire
    ["UBRS"] = 43,  -- Upper Blackrock Spire
    ["ZG"] = 41,  -- Zul'Gurub
    ["ONY"] = 45,  -- Onyxia
    ["MC"] = 47,  -- Molten Core
    ["BWL"] = 49,  -- Blackwing Lair
    ["WSG"] = 53,  -- Warsong Gulch
    ["AB"] = 55,  -- Arathi Basin
    ["AV"] = 51,  -- Alterac Valley
    ["DFC"] = isSoD and 830 or nil,  -- Demon Fall Canyon
    ["WB"] = isSoD and 831 or nil,  -- World Bosses
}
-- Note make sure the ID's dont overlap with LFGDungeonIDs
--see https://wago.tools/db2/GroupFinderActivity?build=1.15.2.54332
local LFGActivityIDs = {
    ["AQ20"] = 842,  -- Ahn'Qiraj Ruins
    ["AQ40"] = 843,  -- Ahn'Qiraj Temple
    ["NAXX"] = 841,  -- Naxxramas
    ["SMG"] = 805,  -- Scarlet Monastery - Graveyard
    ["SML"] = 829,  -- Scarlet Monastery - Library
    ["SMA"] = 827,  -- Scarlet Monastery - Armory
    ["SMC"] = 828,  -- Scarlet Monastery - Cathedral
    
}
--see https://wago.tools/db2/GroupFinderCategory?build=1.15.2.54332
local activityCategoryInfo  = {
    [2] = { typeID = DungeonType.Dungeon },
    [114] = { typeID = DungeonType.Raid },
    [118] = { typeID = DungeonType.Battleground },
}

local idToDungeonKey = tInvert(LFGDungeonIDs)
for key, id in pairs(LFGActivityIDs) do
    idToDungeonKey[id] = key
end

--- Any info that needs to be overridden for a specific dungeon should be done here.
local infoOverrides = {
    -- BFD
    BFD = isSoD and {
        typeID = DungeonType.Raid,
        minLevel = 25,
        maxLevel = 40,
        size = 10,
    },
    -- Gnomer
    GNO = isSoD and {
        typeID = DungeonType.Raid,
        minLevel = 40,
        maxLevel = 50,
        size = 10,
    },
    -- Sunken Temple
    ST = isSoD and {
        typeID = DungeonType.Raid,
        minLevel = 50,
        maxLevel = 60,
        size = 20,
    },
    -- Demon Fall Canyon (completely spoofed for SoD since its not added into the LFGDungeon db2 table)
    DFC = isSoD and {
        name = GetRealZoneText(2784),
        minLevel = 60,
        maxLevel = 60,
        typeID = DungeonType.Dungeon,
    },
    WB = isSoD and {
        name = "World Bosses",
        minLevel = 60,
        maxLevel = 60,
        typeID = DungeonType.Raid,
    },
    -- UBRS is colloquially considered a dungeon. (in LFGDungeon table its a raid)
    UBRS = { typeID = DungeonType.Dungeon },
    
    -- For the spoofed LFGDungeonID for "Dire Maul"
    -- note: 32 is not a real entry in the LFGDungeon table for 1.15.xx.
    DM2 = { 
        name = GetRealZoneText(429),
        minLevel = 54, 
        maxLevel = 61, 
        typeID = DungeonType.Dungeon
    },

    -- Since GetActivityInfoTable returns 0 for these values, set them manually.
    AQ20 = { minLevel = 60, maxLevel = 60, typeID = DungeonType.Raid },
    AQ40 = { minLevel = 60, maxLevel = 60, typeID = DungeonType.Raid },
    NAXX = { minLevel = 60, maxLevel = 60, typeID = DungeonType.Raid },
    SMG = { minLevel = 29, maxLevel = 37, typeID = DungeonType.Dungeon },
    SML = { minLevel = 32, maxLevel = 38, typeID = DungeonType.Dungeon },
    SMA = { minLevel = 36, maxLevel = 40, typeID = DungeonType.Dungeon },
    SMC = { minLevel = 39, maxLevel = 45, typeID = DungeonType.Dungeon },
}


---@type {[DungeonID]: DungeonInfo}
local dungeonInfoCache = {}
---@type {[string]: DungeonInfo}
local infoByTagKey = {}
local numDungeons = 0
do -- begin querying game client for localized dungeon info
    local function cacheDungeonInfo(key, dungeonID)
        local cached = {}
        do
            local name, typeID, _, minLevel, maxLevel = GetLFGDungeonInfo(dungeonID);
            cached = {
                name = name,
                minLevel = minLevel,
                maxLevel = maxLevel,
                typeID = typeID,
                tagKey = key,
                expansionID = Expansions.Classic,
            }
        end

        local overrides = infoOverrides[key]
        if overrides then
            for k, v in pairs(overrides) do
                cached[k] = v
            end
        end

        -- please add any missing data to info overrides
        assert(cached.name, "Missing name for dungeonID: " .. dungeonID)
        assert(cached.typeID, "Missing typeID for dungeonID: " .. dungeonID)
        assert(cached.minLevel and cached.maxLevel, "Missing level range for dungeonID: " .. dungeonID)
        
        dungeonInfoCache[dungeonID] = cached
        infoByTagKey[cached.tagKey] = cached
        numDungeons = numDungeons + 1
    end
    local function cacheActivityInfo(key, activityID)
        local cached = {}
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        local categoryInfo = activityCategoryInfo[activityInfo.categoryID]
        cached = {
            name = activityInfo.shortName or activityInfo.fullName,
            minLevel = activityInfo.minLevel,
            maxLevel = activityInfo.maxLevel,
			typeID = categoryInfo.typeID,
            tagKey = key,
			expansionID = Expansions.Classic,
        }
        
        local overrides = infoOverrides[key]
        if overrides then
            for k, v in pairs(overrides) do
                cached[k] = v
            end
        end

        -- please add any missing data to info overrides
        assert(cached.name, "Missing name for activityID: " .. activityID)
        assert(cached.typeID, "Missing typeID for activityID: " .. activityID)
        assert(cached.minLevel and cached.maxLevel, "Missing level range for activityID: " .. activityID)

        dungeonInfoCache[activityID] = cached
        infoByTagKey[cached.tagKey] = cached
        numDungeons = numDungeons + 1
    end
    for key, dungeonID in pairs(LFGDungeonIDs) do
        cacheDungeonInfo(key, dungeonID)
    end
    for key, activityID in pairs(LFGActivityIDs) do
        cacheActivityInfo(key, activityID)
    end
end

---Returns info table for the specified dungeon key or `nil` if it doesn't exist.
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

---Optionally filter by expansionID and/or typeID
---Sorted by min level, ties broken on min max level, then by dungeonID
-- note: the new dungeons are sorted slightly differently,
-- plan is to add  a custom sort index that users can-
-- change in the config so that dungeons sorted to their preference.
---@param expansionID ExpansionID?
---@param typeID DungeonTypeID|DungeonTypeID[]?
function addon.GetSortedDungeonKeys(expansionID, typeID)
	local keys = {}
	for dungeonID, info in pairs(dungeonInfoCache) do
        local tagKey = idToDungeonKey[dungeonID]
		if (not expansionID or info.expansionID == expansionID) 
		and (not typeID -- only include set typeIDs
			or (type(typeID) == "number" and info.typeID == typeID)
			or (type(typeID) == "table" and tContains(typeID, info.typeID)))  
        and (tagKey ~= "DM2" and tagKey ~= "SM2") -- not actually dungeons
		then
			tinsert(keys, tagKey)
		end
	end
	table.sort(keys, function(keyA, keyB)
		local infoA = infoByTagKey[keyA];
        local infoB = infoByTagKey[keyB];
        if infoA.typeID == infoB.typeID then
            if infoA.minLevel == infoB.minLevel then
                if infoA.maxLevel == infoB.maxLevel then
                    if infoA.name == infoB.name then
                        return keyA < keyB
                    else return infoA.name < infoB.name end
                else return infoA.maxLevel < infoB.maxLevel end
            else return infoA.minLevel < infoB.minLevel end
        else return infoA.typeID < infoB.typeID end
	end)
	return keys
end

local cachedLevelRanges
function addon.GetDungeonLevelRanges()
    if cachedLevelRanges then return cachedLevelRanges end
    cachedLevelRanges = {}
    for key, info in pairs(infoByTagKey) do
        cachedLevelRanges[key] = {info.minLevel, info.maxLevel}
    end
    return cachedLevelRanges
end

addon.rawClassicDungeonInfo = infoByTagKey
addon.Enum.DungeonType = DungeonType
addon.Enum.Expansions = Expansions
