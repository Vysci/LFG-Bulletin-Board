local TOCNAME,
	---@class Addon_Dungeons : Addon_Tags, Addon_DungeonData
	GBB = ...;

local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isSoD = isClassicEra and C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery

local debug = false
local print = function(...) if debug then print('['..TOCNAME.."] ",...) end end

function GBB.GetDungeonNames()
	local miscCategoryLocalizations = {
		-- note: enUS treated as a fallback when no locale specific key exists
		MISC = { enUS = MISCELLANEOUS }, -- prelocalized globalString
		TRADE = { enUS = TRADE },
		DEBUG = {
			enUS = "DEBUG INFO",
			ruRU = "ИНФОРМАЦИЯ О ОТЛАДКАХ",
		},
		BAD = {
			enUS = "DEBUG BAD WORDS - REJECTED",
			ruRU = "ОТЛАДКА ПЛОХИЕ СЛОВА - ОТКЛОНЕН",
		},
		TRAVEL = {
			enUS = "Travel services - Summons/Portals",
		},
	}
	local clientLocale = GetLocale() 
	if clientLocale == "enGB" then clientLocale = "enUS" end
	local defaultLocalizations = {} -- { [key]: localizedString }
	local dungeonKeys = GBB.GetSortedDungeonKeys()
	for _, key in ipairs(dungeonKeys) do
		defaultLocalizations[key] = GBB.GetDungeonInfo(key).name
	end
	-- note: `GetSortedDungeonKeys` does not include the `SM2` and `DM2` dungeons keys by design.
	-- (because they are not actually dungeons, but rather a combination of dungeons)
	-- so we need to add them manually
	defaultLocalizations["SM2"] = GBB.GetDungeonInfo("SM2").name
	defaultLocalizations["DM2"] = GBB.GetDungeonInfo("DM2").name

	for key, translations in pairs(miscCategoryLocalizations) do
		defaultLocalizations[key] = translations[clientLocale] or translations.enUS
	end
	if GroupBulletinBoardDB and GroupBulletinBoardDB.CustomLocalesDungeon and type(GroupBulletinBoardDB.CustomLocalesDungeon) == "table" then
		for key,value in pairs(GroupBulletinBoardDB.CustomLocalesDungeon) do
			if value~=nil and value ~="" then
				assert(defaultLocalizations[key], "Missing localization information for categoy/dungeon: "..key)
				defaultLocalizations[key.."_org"] = defaultLocalizations[key]
				defaultLocalizations[key] = value
			end
		end
	end
	defaultLocalizations["DEADMINES"]=defaultLocalizations["DM"]
	return setmetatable({}, {__index = defaultLocalizations})
end
----------------------------------------------
-- local/private heplers and data
----------------------------------------------

--- the `Union` function is included in sharexml's TableUtils.lua already as `MergeTable`
-- note: blizz's `MergeTable` **doesnt** return reference to the resulting table
local function mergeTables(...)
	local resulting = {}
	for i = 1, select("#", ...) do
		local nextTbl = select(i, ...)
		assert(type(nextTbl) == "table", "All arguments to `mergeTables` must be tables.")
		MergeTable(resulting, nextTbl) 
	end
	return resulting
end

-- Generated in `/dungeons/{version}.lua` files
local classicDungeonLevels = GBB.GetDungeonLevelRanges(GBB.Enum.Expansions.Classic)

local mistsDungeonKeys = GBB.GetSortedDungeonKeys(
	GBB.Enum.Expansions.Mists,
	{ GBB.Enum.DungeonType.Dungeon, GBB.Enum.DungeonType.Raid }
);
local cataDungeonKeys = GBB.GetSortedDungeonKeys(
	GBB.Enum.Expansions.Cataclysm,
	{ GBB.Enum.DungeonType.Dungeon, GBB.Enum.DungeonType.Raid }
);

local wotlkDungeonNames = GBB.GetSortedDungeonKeys(
	GBB.Enum.Expansions.Wrath,
	{ GBB.Enum.DungeonType.Dungeon, GBB.Enum.DungeonType.Raid }
);

local tbcDungeonNames = GBB.GetSortedDungeonKeys(
	GBB.Enum.Expansions.BurningCrusade,
	{ GBB.Enum.DungeonType.Dungeon, GBB.Enum.DungeonType.Raid }
);

-- not specificying an expansion id gives **all** available dungeons **up to** current game xpac
local pvpNames = GBB.GetSortedDungeonKeys(nil, GBB.Enum.DungeonType.Battleground);

local debugNames = {"DEBUG", "BAD", "NIL"}

local raidNames = GBB.GetSortedDungeonKeys(nil,{ GBB.Enum.DungeonType.Raid, GBB.Enum.DungeonType.WorldBoss });

-- Becasue theyre not actually dungeons and are not parsed by 
-- `/data/dungeons/{version}.lua` we need to add them manually
local miscCatergoriesLevels = {
	["MISC"] = {0,100}, ["TRAVEL"] = {0,100}, ["DEBUG"] = {0,100},
	["BAD"] = {0,100}, ["TRADE"] = {0,100}, ["NIL"] = {0,100},
}

-- Needed because Lua sucks, Blizzard switch to Python please
-- Takes in a list of dungeon lists, it will then concatenate the lists into a single list
-- it will put the dungeons in an order and give them a value incremental value that can be used for sorting later
-- ie one list "Foo" which contains "Bar" and "FooBar" and a second list "BarFoo" which contains "BarBar"
-- the output would be single list with "Bar" = 1, "FooBar" = 2, "BarFoo" = 3, "BarBar" = 4
local function ConcatenateLists(Names)
	local result = {}
	local index = 1
	for k, nameLists in pairs (Names) do
		for _, v in pairs(nameLists) do
			result[v] = index
			index = index + 1
		end
	end
	return result, index
end
----------------------------------------------
-- Global functions/data
----------------------------------------------

---Used in GBB.RaidList to determine if an incomming request is for a raid or regular dungeon.
---@return {[string]: 1} # a table, with the keys being the `tagKey`s for all available raids
function GBB.GetRaids()
	local arr = {}
	for _, v in pairs (raidNames) do
		arr[v] = 1
	end
	return arr
end

-- used in Tags.lua for determining which tags are safe for game version
-- used in Options.lua for determining adding filter boxes
local vanillaDungeonKeys = GBB.GetSortedDungeonKeys(
	GBB.Enum.Expansions.Classic,
	{ GBB.Enum.DungeonType.Dungeon, GBB.Enum.DungeonType.Raid, GBB.Enum.DungeonType.WorldBoss }
);

-- clear unused dungeons in classic to not generate options/checkboxes with the-
-- new data pipeline api these tables should already empty anyways when in classic client
if isClassicEra then
	tbcDungeonNames = {}
	wotlkDungeonNames = {}
end

---@param additonalCategories (string[]|string[][])?
function GBB.GetDungeonSort(additonalCategories)
	if additonalCategories then
		if additonalCategories[1]  
		and type(additonalCategories[1]) == "table"
		then -- flatten if 2d array provided
			---@cast additonalCategories string[][]
			local seen = {}
			for _, categoryTable in ipairs(additonalCategories) do
				for _, category in ipairs(categoryTable) do
					seen[category] = true
				end
			end
			additonalCategories = GetKeysArray(seen) --[[@as string[] ]]
		end
	else
		additonalCategories = {} --[[@as string[] ]]
	end
	local dungeonOrder = {
		vanillaDungeonKeys, tbcDungeonNames, wotlkDungeonNames, cataDungeonKeys, mistsDungeonKeys,
		pvpNames, additonalCategories, GBB.Misc, debugNames
	}

	local vanillaDungeonSize = #vanillaDungeonKeys
	local tbcDungeonSize = #tbcDungeonNames
	local wotlkDungeonSize = #wotlkDungeonNames
	local cataDungeonSize = #cataDungeonKeys
	local mistsDungeonSize = #mistsDungeonKeys
	local debugSize = #debugNames

	local tmp_dsort, concatenatedSize = ConcatenateLists(dungeonOrder)
	local dungeonSort = {}
	-- todo: these global constants need to be refactored (removed). Theres only a few places left that reference them.
	GBB.TBCDUNGEONSTART = vanillaDungeonSize + 1
	GBB.MAXDUNGEON = vanillaDungeonSize
	GBB.TBCMAXDUNGEON = vanillaDungeonSize  + tbcDungeonSize
	GBB.WOTLKDUNGEONSTART = GBB.TBCMAXDUNGEON + 1
	GBB.WOTLKMAXDUNGEON = wotlkDungeonSize + GBB.TBCMAXDUNGEON + cataDungeonSize + mistsDungeonSize
	GBB.ENDINGDUNGEONSTART = GBB.WOTLKMAXDUNGEON + 1

	-- used in Options.lua for drawing dungeon editboxes for search patterns
	GBB.ENDINGDUNGEONEND = concatenatedSize - debugSize - 1

	for dungeon,nb in pairs(tmp_dsort) do
		dungeonSort[nb]=dungeon
		dungeonSort[dungeon]=nb
	end

	-- Need to do this because I don't know I am too lazy to debug the use of SM2, DM2, and DEADMINES
	dungeonSort["SM2"] = 10.5
	dungeonSort["DM2"] = 19.5

	-- add reverse link for the SM2 and DM2 for the Combine option 
	dungeonSort[dungeonSort["SM2"]] = "SM2"
	dungeonSort[dungeonSort["DM2"]] = "DM2"

	-- This is set to a high index with no reverse link because we dont ever want to show this in `ChatRequests.UpdateRequestList()` (might not be relevant anymore)
	-- Ideally the "DEADMINES" key should never make it to the `req.dungeon` field as it should be converted to either-
	-- "DM" or "DM2"/"DMW"/"DME"/"DMN" in `getRequestMessageCategories()`
	-- keeping this shim here until i fully understand what it even doing, though i suspect it's a relic of old code.
	dungeonSort["DEADMINES"] = GBB.ENDINGDUNGEONEND + 20

	return dungeonSort
end

if isClassicEra then
	GBB.dungeonLevel = mergeTables(classicDungeonLevels, miscCatergoriesLevels)
else
	GBB.dungeonLevel = mergeTables(
		GBB.GetDungeonLevelRanges(), -- all dungeon types, all expansions
		miscCatergoriesLevels
	)
end

-- needed because Option.lua hardcodes a checkbox for "DEADMINES"
GBB.dungeonLevel["DEADMINES"] = GBB.dungeonLevel["DM"]
