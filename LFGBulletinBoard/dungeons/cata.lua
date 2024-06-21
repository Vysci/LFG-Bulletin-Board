---@diagnostic disable: duplicate-set-field
local tocName, 
    ---@class Addon_DungeonData : Addon_LibGPIOptions
    addon = ...;
if WOW_PROJECT_ID ~= WOW_PROJECT_CATACLYSM_CLASSIC then return end
assert(GetLFGDungeonInfo, tocName .. " requires the API `GetLFGDungeonInfo` for parsing dungeon info")
assert(GetRealZoneText, tocName .. " requires the API `GetRealZoneText` for parsing dungeon info")
assert(C_LFGList.GetActivityInfoTable, tocName .. " requires the API `C_LFGList.GetActivityInfoTable` for parsing dungeon info")

local debug = false
local print = function(...) if debug then addon.print(...) end end

-- initialize here for now, this should be moved to a file thats always grunted to load first.
addon.Enum = addon.Enum or {} 
local Expansions = {
	Classic = 0,
	BurningCrusade = 1,
	Wrath = 2,
	Cataclysm = 3,
}

local DungeonType = {
	Dungeon = 1,
	Raid = 2,
	Zone = 4,
    -- Possible to use 5 for BG's but i want to preserve the ID just incase
	Random = 6,
	Battleground = 7
	-- thinking of using 8 for "Rated" for rbgs and arenas to be sorted after normal bgs. 
}

local cataMaxLevel = GetMaxLevelForExpansionLevel(Expansions.Cataclysm)
local isCataLevel = UnitLevel("player") >= (cataMaxLevel - 2) -- when to show Heroic DM & SFK as part of cata.

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

-- The keys to this table need to be manually matched to the appropriate dungeonID
-- These same keys are used for identifying the preset tags/keywords for each dungeon. 
-- If a tag's Key is missing from here or the ActivityIDs table, the tags will not be registered.
-- Modifications to keys in these tables should be reflected in the `Tags.lua` file and vice versa.
local LFGDungeonIDs = {
	RBG = 358,	-- 10v10 Rated Battleground (RBG)
	AQ20 = 160,	-- Ahn'Qiraj Ruins
	AQ40 = 161,	-- Ahn'Qiraj Temple
	ANK = 218,	-- Ahn'kahet: The Old Kingdom
	CRYPTS = 149,	-- Auchenai Crypts
	AZN = 204,	-- Azjol-Nerub
	BH = 328,	-- Baradin Hold
	BT = 196,	-- Black Temple
	BFD = 10,   -- Blackfathom Deeps
	BRC = 303,	-- Blackrock Caverns
	
	-- These get put into "BRD"
	NULL = 30,  -- Blackrock Depths - Detention Block
	NULL = 276,	-- Blackrock Depths - Upper City
	
	BWD = 313,	-- Blackwing Descent
	BWL = 50,   -- Blackwing Lair
	BF = 137,	-- Blood Furnace
	DM = 6,     -- Deadmines

	DM2 = 33,   -- Base Dire Maul (Spoofed entry see infoOverrides)
	DME = 34,	-- Dire Maul - East (Renamed in Cata)
	DMN = 38,	-- Dire Maul - North (Renamed in Cata)
	DMW = 36,	-- Dire Maul - West (Renamed in Cata)
	-- DS = 447,	-- Dragon Soul
	DTK = 214,	-- Drak'Tharon Keep
	-- END_TIME = 435,	-- End Time
	NULL = 417,	-- Fall of Deathwing (LFR)
	-- FL = 361,	-- Firelands
	GNO = 14,   -- Gnomeregan
	GB = 304,	-- Grim Batol
	GL = 177,	-- Gruul's Lair
	GD = 216,	-- Gundrak
	HOL = 207,	-- Halls of Lightning
	HOO = 305,	-- Halls of Origination
	HOR = 255,	-- Halls of Reflection
	HOS = 208,	-- Halls of Stone
	RAMPS = 136,-- Hellfire Ramparts
	-- HOT = 439,	-- Hour of Twilight
	HYJAL = 195,-- Hyjal Past
	ICC = 279,	-- Icecrown Citadel
	KARA = 175,	-- Karazhan
	TOLVIR = 312,	-- Lost City of the Tol'vir
	LBRS = 32,  -- Lower Blackrock Spire
	MGT = 198,	-- Magisters' Terrace
	MAG = 176,	-- Magtheridon's Lair
	MT = 148,	-- Mana-Tombs
	
    -- all these can get put into "MAR" or split into MAR1, MAR2, MAR3
	-- NULL = 273,	-- Maraudon - Earth Song Falls
	-- NULL = 26,  -- Maraudon - Foulspore Cavern
	-- NULL = 272,	-- Maraudon - The Wicked Grotto
	MAR = { 273, 26, 272 },
	
	MC = 48,    -- Molten Core
	NAXX = 159,	-- Naxxramas
	ONY = 46,   -- Onyxia's Lair
	BM = 171,	-- Opening of the Dark Portal (See Black Morass in ActivityIDs)
	POS = 253,	-- Pit of Saron
    RFC = 4,    -- Ragefire Chasm
	RFD = 20,   -- Razorfen Downs
	RFK = 16,   -- Razorfen Kraul
	RS = 293,	-- Ruby Sanctum
	
	-- base Scarlet Monastery not a real LFGDungeonEntry (spoofed in infoOverrides)
	SM2 = 17,  	
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

	-- These can get group in "STR"
	NULL = 40,  -- Stratholme - Main Gate
	NULL = 274,	-- Stratholme - Service Entrance

	ST = 28,    -- Sunken Temple
	EYE = 193,	-- Tempest Keep (The Eye)
	ARC = 174,	-- The Arcatraz
	BOT2 = 315,	-- The Bastion of Twilight
	BOT = 173,	-- The Botanica
	COS = 209,	-- The Culling of Stratholme
	OHB = 170,	-- The Escape From Durnholde (Old Hillsbrad Foothills)
	EOE = 223,	-- The Eye of Eternity
	FOS = 251,	-- The Forge of Souls
	MECH = 172,	-- The Mechanar
	NEX = 225,	-- The Nexus
	OS = 224,	-- The Obsidian Sanctum
	OCC = 206,	-- The Oculus
	NULL = 416,	-- The Siege of Wyrmrest Temple (LFR)
	SV = 147,	-- The Steamvault
	TSC = 307,	-- The Stonecore
	SWP = 199,	-- The Sunwell
	VP = 311,	-- The Vortex Pinnacle
	TOFW = 317,	-- Throne of the Four Winds
	TOTT = 302,	-- Throne of the Tides
	CHAMP = 245,-- Trial of the Champion
	TOTC = {
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

	-- Seasonal
	BREW = 287,	-- Coren Direbrew (Brewfest)
	LOVE = 288,	-- The Crown Chemical Co. (Love is in the Air)
	SUMMER = 286,	-- The Frost Lord Ahune (Midsummer)
	HOLLOW = 285,	-- The Headless Horseman (Hallow's End)

	-- Cata prepatch bosses (unused for cata rerelease)
	-- EARTH_PORTAL = 297,	-- Crown Princess Theradras
	-- FIRE_PORTAL = 296,	-- Grand Ambassador Flamelash
	-- WATER_PORTAL = 298,	-- Kai'ju Gahz'rilla
	-- AIR_PORTAL = 299,	-- Prince Sarsarun
}

-- hack: add cata versions of sfk and deadmines at max level
if isCataLevel then
	LFGDungeonIDs.DM = 326
	LFGDungeonIDs.SFK = 327
end

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
-- For those that are neither in the LFGDungeonIDs nor the GroupFinderActivity tables
-- we can use a non colliding fake ID and spoof the data by other means. 
-- https://wago.tools/db2/GroupFinderActivity?build=4.4.0.54525
-- Note: this API seems to missing levels as of 4.40.5901. Manually enter in infoOverrides.
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
	SOTA = 1142,-- Strand of the Ancients
	STR = 816,	-- Stratholme
	WSG = 919,	-- Warsong Gulch
	WG = 1117, 	-- Wintergrasp
	IOC = 1144, -- Isle of Conquest 
	TB = 939, 	-- Battle for Tol Barad (Spoofed in infoOverrides)
	TP = 940, 	-- Twin Peaks missing (Spoofed)
	BFG = 941, 	-- Battle for Gilneas missing (Spoofed)
	-- BM = 831,	-- The Black Morass (only used in overrides)
    -- MARA = 809,	-- Maraudon (now split into 3 wings)
	-- STK = 802,	-- Stormwind Stockades (Use "Stormwind Stockade")
	-- UB = 821,	-- Coilfang - Underbog (Just use Underbog)
	-- DME = 813,	-- Dire Maul - East (Renamed in Cata)
	-- DMN = 815,	-- Dire Maul - North (Renamed in Cata)
	-- DMW = 814,	-- Dire Maul - West (Renamed in Cata)
}
---@param name string
---@param minLevel? number
---@param maxLevel? number
---@return DungeonInfo
local spoofBattleground = function(name, minLevel, maxLevel, typeID, expansionID)
	return {
		name = name,
		minLevel = minLevel or cataMaxLevel,
		maxLevel = maxLevel or cataMaxLevel,
		typeID = typeID or DungeonType.Battleground,
		expansionID = expansionID or Expansions.Cataclysm,
	}
end	
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

-- C_LFGList.GetActivityInfoTable doesnt have expansionID so we need to set it based on activityGroupID
-- https://wago.tools/db2/GroupFinderActivityGrp?build=4.4.0.54525
local groupIDAdditionalInfo = {
	[285] = { -- Classic Dungeons
		expansionID = Expansions.Classic, 
		typeID = DungeonType.Dungeon,
	},
	[290] = { -- Classic Raids
		expansionID = Expansions.Classic, 
		typeID = DungeonType.Raid,
	},
	[286] = { -- Burning Crusade Dungeons
		expansionID = Expansions.BurningCrusade,
		typeID = DungeonType.Dungeon,
	},
	[291] = { -- Burning Crusade Raids
		expansionID = Expansions.BurningCrusade, 
		typeID = DungeonType.Raid,
	}, 
	[287] = { -- Lich King Dungeons
		expansionID = Expansions.Wrath,
		typeID = DungeonType.Dungeon,
	},
	[292] = {-- Lich King Raids
		expansionID = Expansions.Wrath, 
		typeID = DungeonType.Raid,
	},

	-- note: no Cataclysm Dungeons entry in the db table
	[364] = { -- Cataclysm Raids
		expansionID = Expansions.Cataclysm,
		typeID = DungeonType.Raid,
	}, 
	-- Arena & Battlegrounds (map to latest expansion)
	[299] = {
		expansionID = Expansions.Cataclysm,
		typeID = DungeonType.Battleground,
	}
}
do -- map IDs to ones that share expansion and type data
	local groupIdMap = {
		[288] = 286, -- Burning Crusade Heroic Dungeons
		[289] = 287, -- Lich King Heroic Dungeons
		[293] = 292, -- Lich King Normal Raids (25)
		[320] = 292, -- Lich King Heroic Raids (10)
		[321] = 292, -- Lich King Heroic Raids (25)
		[300] = 299, -- Battlegrounds
		[301] = 299, -- World PvP Events
	}
	for link, source in pairs(groupIdMap) do
		groupIDAdditionalInfo[link] = groupIDAdditionalInfo[source]
	end
end

-- For any data that isnt available in either api, we can manually override it here.
-- Either manually hardcoded or by using a different api to get the data.
-- key by dungeonKey, `nil`/missing info entries will be ignored.
local infoOverrides = {
	-- Most People know this dungeon as "black morass" but its officially called "Opening of the Dark Portal" in lfgdungeoninfo
	BM = { name = DUNGEON_FLOOR_COTTHEBLACKMORASS1 },
	-- Following dungeons have been splint into multiple wings in the cata client
	-- take the min level from the first wing and max level from the second wing.
	-- the ActivityInfo api also doesnt supply the dungeon type so we'll just hardcode it here.
	SM2 = { 
		name = GetRealZoneText(189), 
		minLevel = 26, maxLevel = 45,
		expansionID = Expansions.Classic,
		typeID = DungeonType.Dungeon 
	},
	BRD = { minLevel = 49, maxLevel = 61 },
	STR = { minLevel = 42, maxLevel = 56},
	MAR = { 
		name = GetRealZoneText(349), 
		minLevel = 32, maxLevel = 44, 
		typeID = DungeonType.Dungeon, 
	},
	DM2 = { 
		name = GetRealZoneText(429), 
		minLevel = 36, maxLevel = 52,
		expansionID = Expansions.Classic,
		typeID = DungeonType.Dungeon 
	},
	-- DME = { minLevel = 36, maxLevel = 46 },
	-- DMW = { minLevel = 39, maxLevel = 49 },
	-- DMN = { minLevel = 42, maxLevel = 52 },
	-- The pvp dungeons arent in th LFGDungeons table in the cata client atm. (except for RBG)
	-- and the GetActivityInfoTable API is returning `0` for min/max level so we'll just hardcode it here.
	ARENA = { 
		minLevel = cataMaxLevel, maxLevel = cataMaxLevel,
		name = C_LFGList.GetActivityGroupInfo(299), -- this is the only localized reference to "Arenas" i could find
	}, 
	WSG = { minLevel = 10, maxLevel = cataMaxLevel },
	AB = { minLevel = 10, maxLevel = cataMaxLevel },
	EOTS = { minLevel = 35, maxLevel = cataMaxLevel },
	AV = { minLevel = 45, maxLevel = cataMaxLevel },
	SOTA = { minLevel = 65, maxLevel = cataMaxLevel },
	WG = { minLevel = 71, maxLevel = cataMaxLevel },
	RBG = { typeID = DungeonType.Battleground }, -- GetLFGDungeonInfo considers it a raid for some reason.
	IOC = { minLevel = 71, maxLevel = cataMaxLevel },
	-- Completely spoofed entries, missing in both LFGDungeons and GroupFinderActivity
	TB = spoofBattleground(GetRealZoneText(732)),
	TP = spoofBattleground(GetRealZoneText(726)),
	BFG = spoofBattleground(GetRealZoneText(761)),
	-- DM and SFK only "Heroic" @ max level
	DM = isCataLevel and {
		name = DUNGEON_NAME_WITH_DIFFICULTY:format(
			DUNGEON_FLOOR_THEDEADMINES1, DUNGEON_DIFFICULTY2)
	} or nil,
	SFK = isCataLevel and { 
		name = DUNGEON_NAME_WITH_DIFFICULTY:format(
			GetRealZoneText(33), DUNGEON_DIFFICULTY2)
	} or nil,
	-- Consider Holiday dungeons as part of latest expansion (like bgs)
	-- Related issue: 253
	BREW = { expansionID = Expansions.Cataclysm },
	LOVE = { expansionID = Expansions.Cataclysm },
	SUMMER = { expansionID = Expansions.Cataclysm },
	HOLLOW = { expansionID = Expansions.Cataclysm },
}

---@type {[DungeonID]: DungeonInfo}
local dungeonInfoCache = {}
local infoByTagKey = {}
local numDungeons = 0
do
    local function cacheActivityInfo(activityID)
        local cached = {}
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
		if activityInfo then -- spoofied entries will be nil
			local additionalInfo = groupIDAdditionalInfo[activityInfo.groupFinderActivityGroupID]
			cached = {
				name = activityInfo.shortName or activityInfo.fullName,
				minLevel = activityInfo.minLevel,
				maxLevel = activityInfo.maxLevel,
				expansionID = additionalInfo.expansionID,
				typeID = additionalInfo.typeID,
				tagKey = activityIDToKey[activityID]
			}
		else cached.tagKey = activityIDToKey[activityID] end

		local overrides = infoOverrides[cached.tagKey]
		if overrides then
			for key, value in pairs(overrides) do
				cached[key] = value
			end
		end
		-- this is is here verify no overlap in ID's between LFGDungeonIDs and ActivityIDs
        assert(not dungeonInfoCache[activityID], "Duplicate ID found for activity ID: " .. activityID, "Use a different dungeonID for this dungeon or different activityID", activityInfo)

		assert(cached.name, "Failed to get name for activityID: " .. activityID, activityInfo)
		assert(cached.minLevel and cached.maxLevel, "Failed to get level range for activityID: " .. activityID, activityInfo)
		assert(cached.expansionID, "Failed to get expansionID for activityID: " .. activityID, activityInfo)
		assert(cached.typeID, "Failed to get typeID for activityID: " .. activityID, activityInfo)

        dungeonInfoCache[activityID] = cached
		infoByTagKey[cached.tagKey] = cached
        numDungeons = numDungeons + 1
    end
    local function cacheLFGDungeonInfo(dungeonID)
        local cached = {}
		-- https://warcraft.wiki.gg/wiki/API_GetLFGDungeonInfo
        local dungeonInfo = {GetLFGDungeonInfo(dungeonID)}
        local name, typeID, minLevel, maxLevel = 
			dungeonInfo[1], dungeonInfo[2], dungeonInfo[4], dungeonInfo[5];
        local expansionID, isHoliday = 
			dungeonInfo[9], dungeonInfo[15];

        cached = {
            name = name,
            minLevel = minLevel,
            maxLevel = maxLevel,
            typeID = typeID,
            tagKey = dungeonIDToKey[dungeonID],
			isHoliday = isHoliday,
            expansionID = expansionID,
        }
		local overrides = infoOverrides[cached.tagKey]
		if overrides then
			for key, value in pairs(overrides) do
				cached[key] = value
			end
		end
		assert(not dungeonInfoCache[dungeonID], "Duplicate ID found for dungeon ID: " .. dungeonID, "Use a different dungeonID for this dungeon or different dungeonID", dungeonInfo)

		assert(cached.name, "Failed to get name for dungeonID: " .. dungeonID, dungeonInfo)
		assert(cached.minLevel and cached.maxLevel, "Failed to get level range for dungeonID: " .. dungeonID, dungeonInfo)
		assert(cached.expansionID, "Failed to get expansionID for dungeonID: " .. dungeonID, dungeonInfo)
		assert(cached.typeID, "Failed to get typeID for dungeonID: " .. dungeonID, dungeonInfo)

        dungeonInfoCache[dungeonID] = cached
        infoByTagKey[cached.tagKey] = cached
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

addon.cataRawDungeonInfo = dungeonInfoCache
addon.Enum.Expansions = Expansions
addon.Enum.DungeonType = DungeonType