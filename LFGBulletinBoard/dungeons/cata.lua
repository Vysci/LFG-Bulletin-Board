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

-- Use GetActivityInfoTable to get dungeon data based on db2 table
-- https://wago.tools/db2/GroupFinderActivity?build=4.4.2.59185
-- Note: this API seems to missing levels (see `hardcodedDungeonLevels` table)
local ActivityIDs = {
	ARENA = {
    	936, -- 2v2 Arena
		937, -- 3v3 Arena
        938, -- 5v5 Arena
    },
	AQ20 = 842, -- "Ahn'Qiraj Ruins"
	AQ40 = 843, -- "Ahn'Qiraj Temple"
	ANK = { -- "Ahn'kahet: The Old Kingdom"
		1072, -- "Ahn'kahet: The Old Kingdom (Normal)"
		1131, -- "Ahn'kahet: The Old Kingdom (Heroic)"
		1198, -- "Ahn'kahet: The Old Kingdom (Titan Rune Alpha)"
		1220, -- "Ahn'kahet: The Old Kingdom (Titan Rune Beta)"
		1234, -- "Ahn'kahet: The Old Kingdom (Titan Rune Gamma)"
	},
	CRYPTS = { -- "Auchenai Crypts"
		824, -- "Auchenai Crypts (Normal)"
		903, -- "Auchenai Crypts (Heroic)"
	},
	AZN = { -- "Azjol-Nerub"
		1066, -- "Azjol-Nerub (Normal)"
		1121, -- "Azjol-Nerub (Heroic)"
		1208, -- "Azjol-Nerub (Titan Rune Alpha)"
		1219, -- "Azjol-Nerub (Titan Rune Beta)"
		1233, -- "Azjol-Nerub (Titan Rune Gamma)"
	},
	BH = { -- "Baradin Hold"
		1517, -- "Baradin Hold (10 Normal)"
		1522, -- "Baradin Hold (25 Normal)"
	},
	BT = 850, -- "Black Temple"
	BFD = 801, -- "Blackfathom Deeps"
	BRC = { -- "Blackrock Caverns"
		134, -- "Blackrock Caverns (Normal)"
		144, -- "Blackrock Caverns (Heroic)"
		1598, -- "Blackrock Caverns (Elemental Rune Inferno)"
		1692, -- "Blackrock Caverns (Elemental Rune Twilight)"
	},
	BRD = 811, -- "Blackrock Depths"
	BWD = { -- "Blackwing Descent"
		1523, -- "Blackwing Descent (10 Normal)"
		1524, -- "Blackwing Descent (25 Normal)"
		1525, -- "Blackwing Descent (10 Heroic)"
		1526, -- "Blackwing Descent (25 Heroic)"
	},
	BWL = 840, -- "Blackwing Lair"
	BF = { -- "Blood Furnace"
		818, -- "Blood Furnace (Normal)"
		912, -- "Blood Furnace (Heroic)"
	},
	DM = { -- "Deadmines"
		148, -- "Deadmines (Heroic)"
		799, -- "Deadmines"
		1597, -- "Deadmines (Elemental Rune Inferno)"
		1691, -- "Deadmines (Elemental Rune Twilight)"
	},
	DME = 813, -- "Dire Maul East"
	DMN = 815, -- "Dire Maul North"
	DMW = 814, -- "Dire Maul West"
	-- DS = 0000, -- "Dragon Soul"
	DTK = { -- "Drak'Tharon Keep"
		1070, -- "Drak'Tharon Keep (Normal)"
		1129, -- "Drak'Tharon Keep (Heroic)"
		1200, -- "Drak'Tharon Keep (Titan Rune Alpha)"
		1218, -- "Drak'Tharon Keep (Titan Rune Beta)"
		1232, -- "Drak'Tharon Keep (Titan Rune Gamma)"
	},
	ENDTIME = 152, -- "End Time"
	FL = { -- "Firelands"
		1586, -- "Firelands (10 Normal)"
		1587, -- "Firelands (25 Normal)"
		1588, -- "Firelands (10 Heroic)"
		1589, -- "Firelands (25 Heroic)"
	},
	GNO = 803, -- "Gnomeregan"
	GB = { -- "Grim Batol"
		135, -- "Grim Batol (Normal)"
		143, -- "Grim Batol (Heroic)"
		1596, -- "Grim Batol (Elemental Rune Inferno)"
		1690, -- "Grim Batol (Elemental Rune Twilight)"
	},
	GL = 846, -- "Gruul's Lair"
	GD = { -- "Gundrak"
		1071, -- "Gundrak (Normal)"
		1130, -- "Gundrak (Heroic)"
		1199, -- "Gundrak (Titan Rune Alpha)"
		1217, -- "Gundrak (Titan Rune Beta)"
		1231, -- "Gundrak (Titan Rune Gamma)"
	},
	HOL = { -- "Halls of Lightning"
		1068, -- "Halls of Lightning (Normal)"
		1127, -- "Halls of Lightning (Heroic)"
		1202, -- "Halls of Lightning (Titan Rune Alpha)"
		1216, -- "Halls of Lightning (Titan Rune Beta)"
		1230, -- "Halls of Lightning (Titan Rune Gamma)"
	},
	HOO = { -- "Halls of Origination"
		136, -- "Halls of Origination (Normal)"
		142, -- "Halls of Origination (Heroic)"
		1595, -- "Halls of Origination (Elemental Rune Inferno)"
		1689, -- "Halls of Origination (Elemental Rune Twilight)"
	},
	HOR = { -- "Halls of Reflection"
		1080, -- "Halls of Reflection (Normal)"
		1136, -- "Halls of Reflection (Heroic)"
		1242, -- "Halls of Reflection (Titan Rune Gamma)"
	},
	HOS = { -- "Halls of Stone"
		1069, -- "Halls of Stone (Normal)"
		1128, -- "Halls of Stone (Heroic)"
		1201, -- "Halls of Stone (Titan Rune Alpha)"
		1215, -- "Halls of Stone (Titan Rune Beta)"
		1229, -- "Halls of Stone (Titan Rune Gamma)"
	},
	RAMPS = { -- "Hellfire Ramparts"
		817, -- "Hellfire Ramparts (Normal)"
		913, -- "Hellfire Ramparts (Heroic)"
	},
	HOT = 154, -- "Hour of Twilight"
	HYJAL = 849, -- "Hyjal Past"
	ICC = { -- "Icecrown Citadel"
		1110, -- "Icecrown Citadel (10 Normal)"
		1111, -- "Icecrown Citadel (25 Normal)"
		1255, -- "Icecrown Citadel (10 Heroic)"
		1264, -- "Icecrown Citadel (25 Heroic)"
	},
	KARA = 844, -- "Karazhan"
	TOLVIR = { -- "Lost City of the Tol'vir"
		139, -- "Lost City of the Tol'vir (Normal)"
		147, -- "Lost City of the Tol'vir (Heroic)"
		1594, -- "Lost City of the Tol'vir (Elemental Rune Inferno)"
		1688, -- "Lost City of the Tol'vir (Elemental Rune Twilight)"
	},
	LBRS = 812, -- "Lower Blackrock Spire"
	MGT = { -- "Magisters' Terrace"
		835, -- "Magisters' Terrace (Normal)"
		917, -- "Magisters' Terrace (Heroic)"
	},
	MAG = 845, -- "Magtheridon's Lair"
	MT = { -- "Mana-Tombs"
		823, -- "Mana-Tombs (Normal)"
		904, -- "Mana-Tombs (Heroic)"
	},
	MAR = 809, -- "Maraudon"
	MC = 839, -- "Molten Core"
	NAXX = { -- "Naxxramas"
		841, -- "Naxxramas (10 Normal)"
		1098, -- "Naxxramas (25 Normal)"
		1263, -- "Naxxramas (10 Heroic)"
		1270, -- "Naxxramas (25 Heroic)"
	},
	ONY = { -- "Onyxia's Lair"
		1099, -- "Onyxia's Lair (25 Normal)"
		1156, -- "Onyxia's Lair (10 Normal)"
		1254, -- "Onyxia's Lair (10 Heroic)"
		1269, -- "Onyxia's Lair (25 Heroic)"
	},
	POS = { -- "Pit of Saron"
		1079, -- "Pit of Saron (Normal)"
		1135, -- "Pit of Saron (Heroic)"
		1241, -- "Pit of Saron (Titan Rune Gamma)"
	},
	RFC = 798, -- "Ragefire Chasm"
	RFD = 806, -- "Razorfen Downs"
	RFK = 804, -- "Razorfen Kraul"
	RS = { -- "Ruby Sanctum"
		1108, -- "Ruby Sanctum (10 Normal)"
		1109, -- "Ruby Sanctum (25 Normal)"
		1256, -- "Ruby Sanctum (10 Heroic)"
		1265, -- "Ruby Sanctum (25 Heroic)"
	},
	SMA = 827, -- "Scarlet Armory"
	SMC = 828, -- "Scarlet Cathedral"
	SMG = 805, -- "Scarlet Graveyard"
	SML = 829, -- "Scarlet Library"
	SCH = 797, -- "Scholomance"
	SSC = 848, -- "Serpentshrine Cavern"
	SETH = { -- "Sethekk Halls"
		825, -- "Sethekk Halls (Normal)"
		905, -- "Sethekk Halls (Heroic)"
	},
	SL = { -- "Shadow Labyrinth"
		826, -- "Shadow Labyrinth (Normal)"
		906, -- "Shadow Labyrinth (Heroic)"
	},
	SFK = { -- "Shadowfang Keep"
		149, -- "Shadowfang Keep (Heroic)"
		800, -- "Shadowfang Keep"
		1593, -- "Shadowfang Keep (Elemental Rune Inferno)"
		1687, -- "Shadowfang Keep (Elemental Rune Twilight)"
	},
	SH = { -- "Shattered Halls"
		819, -- "Shattered Halls (Normal)"
		914, -- "Shattered Halls (Heroic)"
	},
	SP = { -- "Slave Pens"
		820, -- "Slave Pens (Normal)"
		909, -- "Slave Pens (Heroic)"
	},
	STK = 802, -- "Stormwind Stockades"
	SOTA = { -- "Strand of the Ancients"
		1142, -- "Strand of the Ancients"
		1143, -- "Strand of the Ancients"
	},
	STR = 816, -- "Stratholme"
	ST = 810, -- "Sunken Temple"
	EYE = 847, -- "Tempest Keep" (aka The Eye)
	ARC = { -- "The Arcatraz"
		834, -- "The Arcatraz (Normal)"
		915, -- "The Arcatraz (Heroic)"
	},
	BOT2 = { -- "The Bastion of Twilight"
		1527, -- "The Bastion of Twilight (10 Normal)"
		1528, -- "The Bastion of Twilight (25 Normal)"
		1529, -- "The Bastion of Twilight (10 Heroic)"
		1530, -- "The Bastion of Twilight (25 Heroic)"
	},
	BM = { -- "The Black Morass" (aka Opening of the Dark Portal)
		831, -- "The Black Morass (Normal)"
		907, -- "The Black Morass (Heroic)"
	},
	BOT = { -- "The Botanica"
		833, -- "The Botanica (Normal)"
		918, -- "The Botanica (Heroic)"
	},
	COS = { -- "The Culling of Stratholme"
		1065, -- "The Culling of Stratholme (Normal)"
		1126, -- "The Culling of Stratholme (Heroic)"
		1203, -- "The Culling of Stratholme (Titan Rune Alpha)"
		1214, -- "The Culling of Stratholme (Titan Rune Beta)"
		1228, -- "The Culling of Stratholme (Titan Rune Gamma)"
	},
	OHB = { -- "The Escape From Durnholde" (aka Old Hillsbrad Foothills)
		830, -- "The Escape From Durnholde (Normal)"
		908, -- "The Escape From Durnholde (Heroic)"
	},
	EOE = { -- "The Eye of Eternity"
		1094, -- "The Eye of Eternity (25 Normal)"
		1102, -- "The Eye of Eternity (10 Normal)"
		1259, -- "The Eye of Eternity (10 Heroic)"
		1273, -- "The Eye of Eternity (25 Heroic)"
	},
	FOS = { -- "The Forge of Souls"
		1078, -- "The Forge of Souls (Normal)"
		1134, -- "The Forge of Souls (Heroic)"
		1240, -- "The Forge of Souls (Titan Rune Gamma)"
	},
	MECH = { -- "The Mechanar"
		832, -- "The Mechanar (Normal)"
		916, -- "The Mechanar (Heroic)"
	},
	NEX = { -- "The Nexus"
		1077, -- "The Nexus (Normal)"
		1132, -- "The Nexus (Heroic)"
		1197, -- "The Nexus (Titan Rune Alpha)"
		1213, -- "The Nexus (Titan Rune Beta)"
		1227, -- "The Nexus (Titan Rune Gamma)"
	},
	OS = { -- "The Obsidian Sanctum"
		1097, -- "The Obsidian Sanctum (25 Normal)"
		1101, -- "The Obsidian Sanctum (10 Normal)"
		1260, -- "The Obsidian Sanctum (10 Heroic)"
		1271, -- "The Obsidian Sanctum (25 Heroic)"
	},
	OCC = { -- "The Oculus"
		1067, -- "The Oculus (Normal)"
		1124, -- "The Oculus (Heroic)"
		1205, -- "The Oculus (Titan Rune Alpha)"
		1212, -- "The Oculus (Titan Rune Beta)"
		1226, -- "The Oculus (Titan Rune Gamma)"
	},
	SV = { -- "The Steamvault"
		822, -- "The Steamvault (Normal)"
		910, -- "The Steamvault (Heroic)"
	},
	TSC = { -- "The Stonecore"
		137, -- "The Stonecore (Normal)"
		141, -- "The Stonecore (Heroic)"
		1592, -- "The Stonecore (Elemental Rune Inferno)"
		1686, -- "The Stonecore (Elemental Rune Twilight)"
	},
	SWP = 852, -- "The Sunwell"
	VP = { -- "The Vortex Pinnacle"
		138, -- "The Vortex Pinnacle (Normal)"
		140, -- "The Vortex Pinnacle (Heroic)"
		1591, -- "The Vortex Pinnacle (Elemental Rune Inferno)"
		1685, -- "The Vortex Pinnacle (Elemental Rune Twilight)"
	},
	TOFW = { -- "Throne of the Four Winds"
		1531, -- "Throne of the Four Winds (10 Normal)"
		1532, -- "Throne of the Four Winds (25 Normal)"
		1533, -- "Throne of the Four Winds (10 Heroicl)"
		1534, -- "Throne of the Four Winds (25 Heroic)"
	},
	TOTT = { -- "Throne of the Tides"
		146, -- "Throne of the Tides (Heroic)"
		1590, -- "Throne of the Tides (Elemental Rune Inferno)"
		1684, -- "Throne of the Tides (Elemental Rune Twilight)"
	},
	CHAMP = { -- "Trial of the Champion"
		1076, -- "Trial of the Champion (Normal)"
		1133, -- "Trial of the Champion (Heroic)"
		1238, -- "Trial of the Champion (Titan Rune Beta)"
		1239, -- "Trial of the Champion (Titan Rune Gamma)"
	},
	TOTC = { -- "Trial of the Crusader"
		1100, -- "Trial of the Crusader (10 Normal)"
		1104, -- "Trial of the Crusader (25 Normal)"
		1261, -- "Trial of the Crusader (10 Heroic)"
		1268, -- "Trial of the Crusader (25 Heroic)"
		1103, -- "Trial of the Grand Crusader (10 Normal)"
		1105, -- "Trial of the Grand Crusader (25 Normal)"
		1258, -- "Trial of the Grand Crusader (10 Heroic)"
		1267, -- "Trial of the Grand Crusader (25 Heroic)"
	},
	ULD = 807, -- "Uldaman"
	ULDAR = { -- "Ulduar"
		1106, -- "Ulduar (10 Normal)"
		1107, -- "Ulduar (25 Normal)"
		1257, -- "Ulduar (10 Heroic)"
		1266, -- "Ulduar (25 Heroic)"
	},
	UB = { -- "Underbog"
		821, -- "Coilfang - Underbog (Normal)"
		911, -- "Underbog (Heroic)"
	},
	UBRS = 837, -- "Upper Blackrock Spire"
	UK = { -- "Utgarde Keep"
		1074, -- "Utgarde Keep (Normal)"
		1122, -- "Utgarde Keep (Heroic)"
		1207, -- "Utgarde Keep (Titan Rune Alpha)"
		1211, -- "Utgarde Keep (Titan Rune Beta)"
		1225, -- "Utgarde Keep (Titan Rune Gamma)"
	},
	UP = { -- "Utgarde Pinnacle"
		1075, -- "Utgarde Pinnacle (Normal)"
		1125, -- "Utgarde Pinnacle (Heroic)"
		1204, -- "Utgarde Pinnacle (Titan Rune Alpha)"
		1210, -- "Utgarde Pinnacle (Titan Rune Beta)"
		1224, -- "Utgarde Pinnacle (Titan Rune Gamma)"
	},
	VOA = { -- "Vault of Archavon"
		1095, -- "Vault of Archavon (10 Normal)"
		1096, -- "Vault of Archavon (25 Normal)"
		1262, -- "Vault of Archavon (10 Heroic)"
		1272, -- "Vault of Archavon (25 Heroic)"
	},
	VH = { -- "Violet Hold"
		1073, -- "Violet Hold (Normal)"
		1123, -- "Violet Hold (Heroic)"
		1206, -- "Violet Hold (Titan Rune Alpha)"
		1209, -- "Violet Hold (Titan Rune Beta)"
		1223, -- "Violet Hold (Titan Rune Gamma)"
	},
	WC = 796, -- "Wailing Caverns"
	WOE = 153, -- "Well of Eternity"
	ZA = 151, -- "Zul'Aman"
	ZF = 808, -- "Zul'Farrak"
	ZG = 150, -- "Zul'Gurub"

	-- Battlegrounds (diff activities per level brackets)
	AV = { 932, 933, 1140, 1141 }, -- "Alterac Valley"
	AB = { 926, 927, 928, 929, 930, 931, 1138 }, -- "Arathi Basin"
	EOTS = { 934, 935, 1139 }, -- "Eye of the Storm"
	IOC = { 1144, 1145 }, -- "Isle of Conquest"
	WSG = { 919, 920, 921, 922, 923, 924, 925, 1137 }, -- "Warsong Gulch"
	WG = { 1117, 1155 },-- "Wintergrasp"

	-- Seasonal dungeons
	BREW = 1083, -- "Coren Direbrew" (Brewfest)
	LOVE = 1084, -- "The Crown Chemical Co." (Love is in the Air)
	SUMMER = 1082, -- "The Frost Lord Ahune" (Midsummer)
	HOLLOW = 1081, -- "The Headless Horseman" (Hallow's End)
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

-- For entries with no ActivityID, we can also use GetLFGDungeonInfo api
-- https://wago.tools/db2/LFGDungeons?build=4.4.2.59185
local LFGDungeonIDs = {
	RBG = 358, -- "10v10 Rated Battleground"
	DS = 447, -- "Dragon Soul" (untill activiyID is known)
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
--- For entries with neither, use non colliding ids and spoof the info using other APIs
--  dungeon info expected to be supplied in `infoOverrides`
local SpoofedActivityIDs = {
	TB = 4001, -- "Battle for Tol Barad"
	TP = 4002, -- "Twin Peaks"
	BFG = 4003, -- "Battle for Gilneas"
	DM2 = 4004,   -- Base "Dire Maul"
	SM2 = 4005,   -- Base "Scarlet Monastery"
}
for key, id in pairs(SpoofedActivityIDs) do
	activityIDToKey[id] = key
end

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

-- C_LFGList.GetActivityInfoTable doesnt have expansionID so we need to set it based on activityGroupID
-- https://wago.tools/db2/GroupFinderActivityGrp?build=4.4.0.54525
local groupIDAdditionalInfo = {
	-- Classic Dungeons
	[285] = { expansionID = Expansions.Classic, typeID = DungeonType.Dungeon },
	-- Classic Raids
	[290] = { expansionID = Expansions.Classic, typeID = DungeonType.Raid },
	-- Burning Crusade Dungeons
	[286] = { expansionID = Expansions.BurningCrusade, typeID = DungeonType.Dungeon },
	-- Burning Crusade Raids
	[291] = { expansionID = Expansions.BurningCrusade, typeID = DungeonType.Raid },
	-- Lich King Dungeons
	[287] = { expansionID = Expansions.Wrath, typeID = DungeonType.Dungeon },
	-- Lich King Raids
	[292] = { expansionID = Expansions.Wrath, typeID = DungeonType.Raid },
	-- Cataclysm Raids
	[364] = { expansionID = Expansions.Cataclysm, typeID = DungeonType.Raid },
	-- Cataclysm Dungeons
	[368] = { expansionID = Expansions.Cataclysm, typeID = DungeonType.Dungeon },
	-- Holiday Dungeons (treat as latest xpac dungeon)
	[294] = { expansionID = Expansions.Cataclysm, typeID = DungeonType.Dungeon },
	-- Arena & Battlegrounds (map to latest expansion)
	[299] = { expansionID = Expansions.Cataclysm, typeID = DungeonType.Battleground }
}
do -- link groupIDs to ones that share expansionID and typeID values
	local groupIdMap = {
		[288] = 286, -- Burning Crusade Heroic Dungeons
		[289] = 287, -- Lich King Heroic Dungeons
		[311] = 287, --- Titan Rune Alpha
		[312] = 287, --- Titan Rune Beta
		[314] = 287, --- Titan Rune Gamma
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
	}
	for link, source in pairs(groupIdMap) do
		groupIDAdditionalInfo[link] = groupIDAdditionalInfo[source]
	end
end

-- Because the GetActivityInfoTable API is returning `0` for min/max level we'll hardcode data here.
-- Remove once blizzard fixes the min/max level values in the db2 tables for GroupFinderActivity
local hardcodedDungeonLevels = {
	OS = { minLevel = 80, maxLevel = 83 },
	TOTT = { minLevel = 80, maxLevel = 85 },
	ARENA = { minLevel = 85, maxLevel = 85 },
	HOLLOW = { minLevel = 84, maxLevel = 85 },
	IOC = { minLevel = 71, maxLevel = 85 },
	RFC = { minLevel = 15, maxLevel = 20 },
	MC = { minLevel = 60, maxLevel = 60 },
	TOFW = { minLevel = 85, maxLevel = 85 },
	ICC = { minLevel = 80, maxLevel = 83 },
	HOS = { minLevel = 76, maxLevel = 80 },
	FOS = { minLevel = 80, maxLevel = 80 },
	WC = { minLevel = 17, maxLevel = 25 },
	CHAMP = { minLevel = 78, maxLevel = 80 },
	KARA = { minLevel = 70, maxLevel = 70 },
	WG = { minLevel = 71, maxLevel = 85 },
	UK = { minLevel = 68, maxLevel = 78 },
	ZF = { minLevel = 44, maxLevel = 54 },
	SSC = { minLevel = 70, maxLevel = 70 },
	UBRS = { minLevel = 58, maxLevel = 65 },
	SP = { minLevel = 62, maxLevel = 69 },
	SETH = { minLevel = 67, maxLevel = 73 },
	FL = { minLevel = 85, maxLevel = 85 },
	VP = { minLevel = 81, maxLevel = 85 },
	POS = { minLevel = 80, maxLevel = 80 },
	UP = { minLevel = 78, maxLevel = 80 },
	OCC = { minLevel = 78, maxLevel = 80 },
	TSC = { minLevel = 81, maxLevel = 85 },
	BH = { minLevel = 85, maxLevel = 85 },
	DTK = { minLevel = 73, maxLevel = 80 },
	HYJAL = { minLevel = 70, maxLevel = 70 },
	BT = { minLevel = 70, maxLevel = 70 },
	VH = { minLevel = 74, maxLevel = 80 },
	TOTC = { minLevel = 80, maxLevel = 83 },
	MT = { minLevel = 64, maxLevel = 71 },
	WSG = { minLevel = 10, maxLevel = 85 },
	ULDAR = { minLevel = 80, maxLevel = 83 },
	SWP = { minLevel = 70, maxLevel = 70 },
	DME = { minLevel = 36, maxLevel = 46 },
	DMW = { minLevel = 39, maxLevel = 49 },
	UB = { minLevel = 63, maxLevel = 70 },
	COS = { minLevel = 78, maxLevel = 80 },
	RS = { minLevel = 80, maxLevel = 83 },
	BRD = { minLevel = 49, maxLevel = 61 },
	EOE = { minLevel = 80, maxLevel = 83 },
	SH = { minLevel = 69, maxLevel = 75 },
	NEX = { minLevel = 70, maxLevel = 79 },
	OHB = { minLevel = 66, maxLevel = 73 },
	SUMMER = { minLevel = 84, maxLevel = 85 },
	NAXX = { minLevel = 80, maxLevel = 83 },
	ST = { minLevel = 50, maxLevel = 60 },
	MGT = { minLevel = 68, maxLevel = 75 },
	VOA = { minLevel = 80, maxLevel = 83 },
	DM = { minLevel = 17, maxLevel = 21 },
	AQ40 = { minLevel = 60, maxLevel = 60 },
	BM = { minLevel = 69, maxLevel = 75 },
	MECH = { minLevel = 70, maxLevel = 75 },
	SV = { minLevel = 69, maxLevel = 75 },
	BFD = { minLevel = 20, maxLevel = 30 },
	TOLVIR = { minLevel = 84, maxLevel = 85 },
	SL = { minLevel = 69, maxLevel = 75 },
	HOL = { minLevel = 78, maxLevel = 80 },
	GNO = { minLevel = 24, maxLevel = 34 },
	AQ20 = { minLevel = 60, maxLevel = 60 },
	BWD = { minLevel = 85, maxLevel = 85 },
	LOVE = { minLevel = 84, maxLevel = 85 },
	ONY = { minLevel = 80, maxLevel = 83 },
	SFK = { minLevel = 18, maxLevel = 26 },
	BWL = { minLevel = 60, maxLevel = 60 },
	ZA = { minLevel = 85, maxLevel = 85 },
	EYE = { minLevel = 70, maxLevel = 70 },
	RAMPS = { minLevel = 59, maxLevel = 67 },
	BF = { minLevel = 61, maxLevel = 68 },
	SCH = { minLevel = 38, maxLevel = 48 },
	STK = { minLevel = 22, maxLevel = 30 },
	GL = { minLevel = 70, maxLevel = 70 },
	MAR = { minLevel = 32, maxLevel = 44 },
	AB = { minLevel = 10, maxLevel = 85 },
	BRC = { minLevel = 80, maxLevel = 85 },
	ULD = { minLevel = 37, maxLevel = 45 },
	BOT2 = { minLevel = 85, maxLevel = 85 },
	ANK = { minLevel = 72, maxLevel = 80 },
	STR = { minLevel = 42, maxLevel = 56 },
	GB = { minLevel = 84, maxLevel = 85 },
	SML = { minLevel = 29, maxLevel = 39 },
	EOTS = { minLevel = 35, maxLevel = 85 },
	RFD = { minLevel = 40, maxLevel = 50 },
	AZN = { minLevel = 72, maxLevel = 80 },
	CRYPTS = { minLevel = 65, maxLevel = 72 },
	ARC = { minLevel = 70, maxLevel = 75 },
	MAG = { minLevel = 70, maxLevel = 70 },
	SMA = { minLevel = 34, maxLevel = 42 },
	LBRS = { minLevel = 57, maxLevel = 65 },
	HOO = { minLevel = 84, maxLevel = 85 },
	AV = { minLevel = 45, maxLevel = 85 },
	RFK = { minLevel = 30, maxLevel = 40 },
	SMG = { minLevel = 26, maxLevel = 36 },
	ZG = { minLevel = 85, maxLevel = 85 },
	BOT = { minLevel = 70, maxLevel = 75 },
	NULL = { minLevel = 85, maxLevel = 85 },
	DMN = { minLevel = 42, maxLevel = 52 },
	SOTA = { minLevel = 65, maxLevel = 85 },
	HOR = { minLevel = 80, maxLevel = 80 },
	BREW = { minLevel = 84, maxLevel = 85 },
	SMC = { minLevel = 37, maxLevel = 45 },
	GD = { minLevel = 75, maxLevel = 80 },
}
-- For any data that isnt available in either api, we can manually override it here.
-- Either manually hardcoded or by using a different api to get the data.
-- key by dungeonKey, `nil`/missing info entries will be ignored.
local infoOverrides = {
	SM2 = { -- spoofed
		name = GetRealZoneText(189),
		minLevel = 26, maxLevel = 45,
		expansionID = Expansions.Classic,
		typeID = DungeonType.Dungeon
	},
	DM2 = { -- spoofed
		name = GetRealZoneText(429),
		minLevel = 36, maxLevel = 52,
		expansionID = Expansions.Classic,
		typeID = DungeonType.Dungeon
	},
	TB = spoofBattleground(GetRealZoneText(732)),
	TP = spoofBattleground(GetRealZoneText(726)),
	BFG = spoofBattleground(GetRealZoneText(761)),
	ARENA = { name = C_LFGList.GetActivityGroupInfo(299) }, -- localized "Arenas" string
	RBG = { typeID = DungeonType.Battleground }, -- GetLFGDungeonInfo considers it a raid for some reason.
	-- DM and SFK only "Heroic" @ max level
	DM = isCataLevel and {
		name = DUNGEON_NAME_WITH_DIFFICULTY:format(DUNGEON_FLOOR_THEDEADMINES1, DUNGEON_DIFFICULTY2),
		minLevel = cataMaxLevel, maxLevel = cataMaxLevel,
	} or nil,
	SFK = isCataLevel and {
		name = DUNGEON_NAME_WITH_DIFFICULTY:format(GetRealZoneText(33), DUNGEON_DIFFICULTY2),
		minLevel = cataMaxLevel, maxLevel = cataMaxLevel,
	} or nil,
	-- Consider Holiday dungeons as part of latest expansion (like bgs). Related issue: #253
	BREW = { expansionID = Expansions.Cataclysm, isHoliday = true },
	LOVE = { expansionID = Expansions.Cataclysm, isHoliday = true },
	SUMMER = { expansionID = Expansions.Cataclysm, isHoliday = true },
	HOLLOW = { expansionID = Expansions.Cataclysm, isHoliday = true },
}

local getBestActivityName = function(activityInfo, typeID, expansionID)
	if typeID == DungeonType.Battleground -- battlegrounds and pre-Wotlk raids use fullname for tranlsations
	or ((expansionID and expansionID < Expansions.Wrath) and typeID == DungeonType.Raid) then
		return (activityInfo.fullName and activityInfo.fullName ~= "" and activityInfo.fullName)
			or activityInfo.shortName
	end
	return (activityInfo.shortName and activityInfo.shortName ~= "" and activityInfo.shortName)
		or activityInfo.fullName
end
local getBestActivityLevelRange = function(tagKey, activityInfo)
	local override = hardcodedDungeonLevels[tagKey]
	local min = (override and override.minLevel) or activityInfo.minLevelSuggestion or activityInfo.minLevel
	local max = (override and override.maxLevel) or activityInfo.maxLevelSuggestion or activityInfo.maxLevel
	if min == 0 then min = max end
	return min, Clamp(max, 0, cataMaxLevel)
end

---@type {[DungeonID]: DungeonInfo}
local dungeonInfoCache = {}
local infoByTagKey = {}
local numDungeons = 0
do
    local function cacheActivityInfo(activityID)
        local cached = {}
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
		if activityInfo then -- spoofied entries will be nil
			local tagKey = activityIDToKey[activityID]
			local additionalInfo = groupIDAdditionalInfo[activityInfo.groupFinderActivityGroupID]
			local minLevel, maxLevel = getBestActivityLevelRange(tagKey, activityInfo)
			cached = {
				name = getBestActivityName(activityInfo, additionalInfo.typeID, additionalInfo.expansionID),
				minLevel = minLevel,
				maxLevel = maxLevel,
				expansionID = additionalInfo.expansionID,
				typeID = additionalInfo.typeID,
				tagKey = tagKey,
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

		assert(cached.name and cached.name ~= "", "Failed to get name for activityID: " .. activityID, activityInfo)
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
	for activityKey in pairs (SpoofedActivityIDs) do
		cacheActivityInfo(SpoofedActivityIDs[activityKey])
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

---@param opts {activityID: number}
function addon.GetDungeonKeyByID(opts)
    local key = activityIDToKey[opts.activityID]
    if key ~= nil then return key end;
    -- if no key, fallback to a name match
    local activityInfo = C_LFGList.GetActivityInfoTable(opts.activityID)
    if not activityInfo then return end
	local auxInfo = groupIDAdditionalInfo[activityInfo.groupFinderActivityGroupID] or {}
	local name = getBestActivityName(activityInfo, auxInfo.typeID, auxInfo.expansionID)
    for key, cacheInfo in pairs(infoByTagKey) do
        if cacheInfo.name == name then return key; end
    end
end
addon.cataRawDungeonInfo = dungeonInfoCache
addon.Enum.Expansions = Expansions
addon.Enum.DungeonType = DungeonType