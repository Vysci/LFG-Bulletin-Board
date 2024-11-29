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

-- Required APIs.
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

-- Each key should have corresponding entry in one of the tables in `Tags.lua`
--see https://wago.tools/db2/GroupFinderActivity?build=1.15.5.57638
local LFGActivityIDs = {
    -- Dungeons
    ["RFC"] = 798,  -- Ragefire Chasm
    ["WC"] = 796,  -- Wailing Caverns
    ["DM"] = 799,  -- Deadmines
    ["SFK"] = 800,  -- Shadowfang Keep
    ["BFD"] = not isSoD and 801 or 1604,  -- Blackfathom Deeps
    ["STK"] = 802, -- Stormwind Stockades
    ["GNO"] = not isSoD and 803 or 1605,  -- Gnomeregan
    ["RFK"] = 804,  -- Razorfen Kraul
    ["SM2"] = 5555,  -- Scarlet Monastery (used for the combine dungeons option) *spoofed*
    ["SMG"] = 805,  -- Scarlet Monastery - Graveyard
    ["SML"] = 829,  -- Scarlet Monastery - Library
    ["SMA"] = 827,  -- Scarlet Monastery - Armory
    ["SMC"] = 828,  -- Scarlet Monastery - Cathedral
    ["RFD"] = 806,  -- Razorfen Downs
    ["ULD"] = 807,  -- Uldaman
    ["ZF"] = 808,  -- Zul'Farrak
    ["MAR"] = 809,  -- Maraudon
    ["ST"] = not isSoD and 810 or 1606,  -- Sunken Temple
    ["BRD"] = 811,  -- Blackrock Depths
    ["DM2"] = 6666,  -- Dire Maul (used for the combine dungeons option) *spoofed*
    ["DME"] = 813,  -- Dire Maul - East
    ["DMW"] = 814,  -- Dire Maul - West
    ["DMN"] = 815,  -- Dire Maul - North
    ["STR"] = 816,  -- Stratholme [816|1603]
    ["SCH"] = 797,  -- Scholomance
    ["LBRS"] = 812,  -- Lower Blackrock Spire
    ["UBRS"] = 837,  -- Upper Blackrock Spire
    -- Raids
    ["ONY"] = 838,  -- Onyxia
    ["ZG"] = 836,  -- Zul'Gurub
    ["MC"] = 839,  -- Molten Core
    ["BWL"] = 840,  -- Blackwing Lair
    ["AQ20"] = 842,  -- Ahn'Qiraj Ruins
    ["AQ40"] = 843,  -- Ahn'Qiraj Temple
    ["NAXX"] = 841,  -- Naxxramas
    -- Battlegrounds
    ["WSG"] = 924, -- Warsong Gulch [919-924]
    ["AB"] = 930,  -- Arathi Basin [926-930]
    ["AV"] = 932,  -- Alterac Valley
    -- SoD Specific
    ["DFC"] = isSoD and 1607 or nil, -- Demon Fall Canyon
    ["AZGS"] = isSoD and 1608 or nil, -- Storm Cliffs (Azuregoes)
    ["KAZK"] = isSoD and 1609 or nil, -- Tainted Scar (Kazzak)
    ["CRY"] = isSoD and 1611 or nil, -- Crystal Vale (Thunderaan)
    ["NMG"] = isSoD and 1610 or nil, -- Nightmare Grove (Emerald Dragons)
}
--see https://wago.tools/db2/GroupFinderCategory?build=1.15.2.54332
local activityCategoryTypeID  = {
    [2] = DungeonType.Dungeon ,
    [114] = DungeonType.Raid,
    [118] = DungeonType.Battleground,
}
local idToDungeonKey = tInvert(LFGActivityIDs)

--- Any info that needs to be overridden/spoofed for a specific instances should be done here.
local infoOverrides = {
    -- todo: add the localized boss name, to the parsed dungeon name for the SoD instanced world bosses.
    -- ex: https://wago.tools/db2/DungeonEncounter?build=1.15.5.57638&sort[Name_lang]=asc&filter[ID]=3079
    CRY = isSoD and {
        name = "Crystal Vale - Prince Thunderaan",
    },
    -- Strat is split into "Main"/"Service" Gates between 2 IDs. We use just the plain zone name.
    STR = { name = GetRealZoneText(329) },
    -- GetActivityInfoTable has unique entries for each BG level bracket. We however use a single entry.
    WSG = { minLevel = 10, maxLevel = 60 },
    AB = { minLevel = 20, maxLevel = 60 },
    -- Note: Following entries for are completely spoofed. hardcoded info here.
    SM2 = {
        name = GetRealZoneText(189),
        minLevel = 30, -- SMG min
        maxLevel = 46, -- SMC max
        typeID = DungeonType.Dungeon
    },
    DM2 = {
        name = GetRealZoneText(429),
        minLevel = 54, -- DME min
        maxLevel = 60, -- DMN max
        typeID = DungeonType.Dungeon
    },
}

---@type {[DungeonID]: DungeonInfo}
local dungeonInfoCache = {}
---@type {[string]: DungeonInfo}
local infoByTagKey = {}
local numDungeons = 0
-- begin querying game client for localized dungeon info
local function cacheActivityInfo(key, activityID)
    local cached = {}
    local activityInfo = C_LFGList.GetActivityInfoTable(activityID) or {categoryID = 0}
    cached = {
        name = activityInfo.shortName or activityInfo.fullName,
        minLevel = activityInfo.minLevelSuggestion or activityInfo.minLevel,
        maxLevel = activityInfo.maxLevelSuggestion or activityInfo.maxLevel,
        typeID = activityCategoryTypeID[activityInfo.categoryID],
        tagKey = key,
        expansionID = Expansions.Classic,
    }

    local overrides = infoOverrides[key]
    if overrides then
        for k, v in pairs(overrides) do
            cached[k] = v
        end
    end
    -- Required fields. If asserts failing, please add any missing data to `infoOverrides`.
    assert(cached.name, "Missing name for activityID: " .. activityID)
    assert(cached.typeID, "Missing typeID for activityID: " .. activityID)
    assert(cached.minLevel and cached.maxLevel, "Missing level range for activityID: " .. activityID)

    dungeonInfoCache[activityID] = cached
    infoByTagKey[cached.tagKey] = cached
    numDungeons = numDungeons + 1
end
for key, activityID in pairs(LFGActivityIDs) do
    cacheActivityInfo(key, activityID)
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
