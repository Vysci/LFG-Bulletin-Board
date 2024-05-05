local _, addon = ...

if WOW_PROJECT_ID ~= WOW_PROJECT_CATACLYSM_CLASSIC then return end
---@alias ExpansionID 0|1|2|3|4|5
assert(GetLFGDungeonInfo, _ .. " requires the API `GetLFGDungeonInfo` for parsing dungeon info")
assert(GetRealZoneText, _ .. " requires the API `GetRealZoneText` for parsing dungeon info")
assert(C_LFGList.GetActivityInfoTable, _ .. " requires the API `C_LFGList.GetActivityInfoTable` for parsing dungeon info")

local print = addon.print

-- intialize here for now, this should be moved to a file thats always grunteed to load first.
---@class AddonEnum
addon.Enum = addon.Enum or { } 
---@enum ExpansionID
addon.Enum.Expansions = {
	Classic = 0,
	BurningCrusade = 1,
	Wrath = 2,
	Cataclysm = 3,
}

-- The keys to this table need to be manually matched to the appropriate dungeonID
-- These same keys are used for identifying the preset tags/keywords for each dungeon. If a tags Key is missing from this table, the tags will not be registered.
-- modifications here should be reflected in the `Tags.lua` file and vice versa.
local LFGDungeonIDs = {
	RBG = 358,	-- 10v10 Rated Battleground
	AQ20 = 160,	-- Ahn'Qiraj Ruins
	AQ40 = 161,	-- Ahn'Qiraj Temple
	ANK = 218,	-- Ahn'kahet: The Old Kingdom
	CRYPTS = 149,	-- Auchenai Crypts
	AZN = 204,	-- Azjol-Nerub
	NULL = 328,	-- Baradin Hold
	BT = 196,	-- Black Temple
	BFD = 10,   -- Blackfathom Deeps
	NULL = 303,	-- Blackrock Caverns
	NULL = 30,  -- Blackrock Depths - Detention Block
	NULL = 276,	-- Blackrock Depths - Upper City
	NULL = 313,	-- Blackwing Descent
	BWL = 50,   -- Blackwing Lair
	BF = 137,	-- Blood Furnace
	BREW = 287,	-- Coren Direbrew
	NULL = 297,	-- Crown Princess Theradras
	DM = 6,     -- Deadmines
	NULL = 36, 	-- Dire Maul - Capital Gardens
	NULL = 38,  -- Dire Maul - Gordok Commons
	NULL = 34,  -- Dire Maul - Warpwood Quarter
	NULL = 447,	-- Dragon Soul
	DTK = 214,	-- Drak'Tharon Keep
	NULL = 435,	-- End Time
	NULL = 417,	-- Fall of Deathwing
	NULL = 361,	-- Firelands
	GNO = 14,   -- Gnomeregan
	NULL = 296,	-- Grand Ambassador Flamelash
	NULL = 304,	-- Grim Batol
	GL = 177,	-- Gruul's Lair
	GD = 216,	-- Gundrak
	HOL = 207,	-- Halls of Lightning
	NULL = 305,	-- Halls of Origination
	HOR = 255,	-- Halls of Reflection
	HOS = 208,	-- Halls of Stone
	RAMPS = 136,-- Hellfire Ramparts
	NULL = 439,	-- Hour of Twilight
	HYJAL = 195,-- Hyjal Past
	ICC = 279,	-- Icecrown Citadel
	NULL = 298,	-- Kai'ju Gahz'rilla
	KARA = 175,	-- Karazhan
	NULL = 312,	-- Lost City of the Tol'vir
	LBRS = 32,  -- Lower Blackrock Spire
	MGT = 198,	-- Magisters' Terrace
	NULL = 176,	-- Magtheridon's Lair
	MT = 148,	-- Mana-Tombs

    -- all these can get put into "MARA"
	NULL = 273,	-- Maraudon - Earth Song Falls
	NULL = 26,  -- Maraudon - Foulspore Cavern
	NULL = 272,	-- Maraudon - The Wicked Grotto

	MC = 48,    -- Molten Core
	NAXX = 159,	-- Naxxramas
	ONY = 46,   -- Onyxia's Lair
	-- BM = 171,	-- Opening of the Dark Portal (See Black Morass in ActivityIDs)
	POS = 253,	-- Pit of Saron
	NULL = 299,	-- Prince Sarsarun
    RFC = 4,    -- Ragefire Chasm
	RFD = 20,   -- Razorfen Downs
	RFK = 16,   -- Razorfen Kraul
	RS = 293,	-- Ruby Sanctum
	SMA = 163,	-- Scarlet Monastery - Armory
	SMC = 164,	-- Scarlet Monastery - Cathedral
	SMG = 18,   -- Scarlet Monastery - Graveyard
	SML = 165,	-- Scarlet Monastery - Library
	SCH = 2,    -- Scholomance
	SSC = 194,	-- Serpentshrine Cavern
	SETH = 150,	-- Sethekk Halls
	SL = 151,	-- Shadow Labyrinth
	SFK = 8,    -- Shadowfang Keep
	SH = 138,	-- Shattered Halls
	SP = 140,	-- Slave Pens
	STK = 12,   -- Stormwind Stockade
	NULL = 40,  -- Stratholme - Main Gate
	NULL = 274,	-- Stratholme - Service Entrance
	ST = 28,    -- Sunken Temple
	EYE = 193,	-- Tempest Keep (The Eye)
	ARC = 174,	-- The Arcatraz
	NULL = 315,	-- The Bastion of Twilight
	BOT = 173,	-- The Botanica
	NULL = 288,	-- The Crown Chemical Co.
	COS = 209,	-- The Culling of Stratholme
	OHB = 170,	-- The Escape From Durnholde (Old Hillsbrad Foothills)
	EOE = 223,	-- The Eye of Eternity
	FOS = 251,	-- The Forge of Souls
	NULL = 286,	-- The Frost Lord Ahune
	NULL = 285,	-- The Headless Horseman
	MECH = 172,	-- The Mechanar
	NEX = 225,	-- The Nexus
	OS = 224,	-- The Obsidian Sanctum
	OCC = 206,	-- The Oculus
	NULL = 416,	-- The Siege of Wyrmrest Temple
	SV = 147,	-- The Steamvault
	NULL = 307,	-- The Stonecore
	SWP = 199,	-- The Sunwell
	NULL = 311,	-- The Vortex Pinnacle
	NULL = 317,	-- Throne of the Four Winds
	NULL = 302,	-- Throne of the Tides
	CHAMP = 245,-- Trial of the Champion
	TOGC = {
        246,	-- Trial of the Crusader
	    247,	-- Trial of the Grand Crusader
    },
	ULD = 22,   -- Uldaman
	ULDAR = 243,-- Ulduar
	UB = 146,	-- Underbog
	UBRS = 330,	-- Upper Blackrock Spire
	UK = 202,	-- Utgarde Keep
	UP = 203,	-- Utgarde Pinnacle
	VOA = 239,	-- Vault of Archavon
	VH = 220,	-- Violet Hold
	WC = 1,     -- Wailing Caverns
	NULL = 437,	-- Well of Eternity
	ZA = 340,	-- Zul'Aman
	ZF = 24,    -- Zul'Farrak
	ZG = 334,	-- Zul'Gurub 
}
local dungeonIDToKey = {}
for key, dungeonID in pairs(LFGDungeonIDs) do
    if type(dungeonID) == "table" then
        for _, id in ipairs(dungeonID) do
            dungeonIDToKey[id] = key
        end
    else
        dungeonIDToKey[dungeonID] = key
    end
end
-- Following have no DungeonID in cata client so use a related ActivityID
local ActivityIDs = {
    ARENA = {
        936,    -- 2v2 Arena
        937,    -- 3v3 Arena
        938     -- 5v5 Arena
    },
	AV = 932,	-- Alterac Valley
	AB = 926,	-- Arathi Basin
	BRD = 811,	-- Blackrock Depths 
	EOTS = 934,	-- Eye of the Storm
	NULL = 1144,	-- Isle of Conquest
	SOTA = 1142,	-- Strand of the Ancients
	STR = 816,	-- Stratholme
	BM = 831,	-- The Black Morass
	WSG = 919,	-- Warsong Gulch
    -- MARA = 809,	-- Maraudon (now split into 3 wings)
	-- STK = 802,	-- Stormwind Stockades (Use "Stormwind Stockade")
	-- UB = 821,	-- Coilfang - Underbog (Just use Underbog)
	-- DME = 813,	-- Dire Maul - East (Depracted in Cata)
	-- DMN = 815,	-- Dire Maul - North (Depracted in Cata)
	-- DMW = 814,	-- Dire Maul - West (Depracted in Cata)
}
local activityIDToKey = {}
for key, activityID in pairs(ActivityIDs) do
    if type(activityID) == "table" then
        for _, id in ipairs(activityID) do
            activityIDToKey[id] = key
        end
    else
        activityIDToKey[activityID] = key
    end
end

local CLIENT_LOCALE = GetLocale()

local debug = true
local print = function(...) if debug then addon.print(...) end end

-- see https://wago.tools/db2/LFGDungeons?build=3.4.3.54261


---@type {[DungeonID]: DungeonInfo}
local dungeonInfoCache = {}
local numDungeons = 0
do
    -- only cache dungeons, raids, and battlegrounds
    local function cacheActivityInfo(activityID)
        local cacheInfo = {}
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        cacheInfo = {
            name = activityInfo.shortName or activityInfo.fullName,
            minLevel = activityInfo.minLevel,
            maxLevel = activityInfo.maxLevel,
            tagKey = activityIDToKey[activityID],
            -- mapID = activityInfo.mapID,
        }
        if not cacheInfo.name then
            print(_ .. ": Failed to get dungeon info for ID: " .. activityID)
            return;
        end
        assert(not dungeonInfoCache[activityID], "Duplicate ID found for activity ID: " .. activityID, "Use a different dungeonID for this dungeon or different activityID", activityInfo)
        dungeonInfoCache[activityID] = cacheInfo
        numDungeons = numDungeons + 1
    end
    local function cacheLFGDungeonInfo(dungeonID)
        local info = {}
		-- https://warcraft.wiki.gg/wiki/API_GetLFGDungeonInfo
        local dungeonInfo = {GetLFGDungeonInfo(dungeonID)}
        local name, typeID, subtypeID, minLevel, maxLevel = 
            dungeonInfo[1], dungeonInfo[2], dungeonInfo[3], dungeonInfo[4], dungeonInfo[5];
        local expansionID, isHoliday = dungeonInfo[9], dungeonInfo[15]
        -- local mapID = dungeonInfo[22]
        assert(name, "Failed to get dungeon info for ID: " .. dungeonID..". Valid dungeonIDs require for addon to function.")
        assert(typeID and minLevel and maxLevel and expansionID, "Failed to get level range or type for dungeonID: " .. dungeonID, name, typeID, minLevel, maxLevel, expansionID)
        info = {
            name = name,
            minLevel = minLevel,
            maxLevel = maxLevel,
            typeID = typeID,
            subtypeID = subtypeID,
            tagKey = dungeonIDToKey[dungeonID],
			isHoliday = isHoliday,
            expansionID = expansionID,
        } --[[@as DungeonInfo]]
        assert(not dungeonInfoCache[dungeonID], "Duplicate ID found for dungeon ID: " .. dungeonID, "Use a different dungeonID for this dungeon or different dungeonID", dungeonInfo)
        dungeonInfoCache[dungeonID] = info
        numDungeons = numDungeons + 1
        -- print(_ .. ": Skipping dunegeon " .. info.name .. " dungeonID: " .. dungeonID .. " typeID: " .. info.typeID)
    end
    for dungeonKey in pairs(LFGDungeonIDs) do
        local dungeonID = LFGDungeonIDs[dungeonKey]
        if type(dungeonID) == "table" then
            for _, id in ipairs(dungeonID) do
                cacheLFGDungeonInfo(id)
            end
        else
            cacheLFGDungeonInfo(dungeonID)
        end
    end
    for activityKey in pairs(ActivityIDs) do
        local activityID = ActivityIDs[activityKey]
        if type(activityID) == "table" then
            for _, id in ipairs(activityID) do
                cacheActivityInfo(id)
            end
        else
            cacheActivityInfo(activityID)
        end
    end
end

local localizedNames -- cache to save some iteration cycles.
---@return {[DungeonID]: string} # Table mapping `dungeonID` to it's localized name.
--- Because of holes in the `dungeonID` range, use `pairs` to iterate table.
function addon.GetCataLocalizedDungeonNames()
    if not localizedNames then
        localizedNames = {}
        for dungeonID, info in pairs(dungeonInfoCache) do
            assert(info.name, "Missing name for dungeonID: " .. dungeonID)
            localizedNames[dungeonID] = info.name
        end
    end
    return localizedNames
end

---@return {[string]: DungeonID} # Table mapping `dungeonCode` to it's `dungeonID` if it's a valid dungeon
local allKeys = {}
function addon.GetCataDungeonKeys()
    for dungeonID, key in pairs(dungeonIDToKey) do
        allKeys[key] = dungeonID
    end
    for activityID, key in pairs(activityIDToKey) do
        allKeys[key] = activityID
    end
    allKeys.NULL = nil
    return allKeys
end

function addon.GetNumCataDungeons()
    return numDungeons
end

---Returns **all** dungeon info if `dungeonID` is nil; Otherwise, returns info for the specificed `dungeonID` or `nil` if it doesn't exist.
---@param dungeonID DungeonID?
---@return (DungeonInfo|table<DungeonID, DungeonInfo>)? 
function addon.GetCataDungeonInfo(dungeonID)
    -- CopyTable isnt neccessary, but its probably best to prevent someone from breaking the addon by messing with out internal table if we return a reference here.
    if dungeonID then
        local info = dungeonInfoCache[dungeonID]
        if info then
            return CopyTable(dungeonInfoCache[dungeonID])
        end
    else
        return CopyTable(dungeonInfoCache)
    end
end

addon.cataDungeonInfo = dungeonInfoCache
