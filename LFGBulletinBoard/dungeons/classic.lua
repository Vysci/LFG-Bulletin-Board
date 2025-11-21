local tocName,
    ---@class Addon_DungeonData: Addon_Localization
    addon = ...;
local Expansions = addon.Enum.Expansions

-- Only load this file in Classic Era and BC clients
if Expansions.Current > Expansions.BurningCrusade then return end

-- Required APIs.
assert(C_LFGList.GetActivityInfoTable, tocName .. " requires the API `C_LFGList.GetActivityInfoTable` for parsing dungeon info")

local DungeonType = addon.Enum.DungeonType

local isSoD = C_Seasons and (C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery)

-- hacky way to get the localization table. rework in the future
-- side-effects:
-- custom users set translatiosn in the `Localization` settings panel will not apply to strings used in this file.
local L = addon.LocalizationInit()

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
    ["STK"] = 802, -- Stormwind Stockades
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
    ["BRD"] = 811,  -- Blackrock Depths
    ["DM2"] = 6666,  -- Dire Maul (used for the combine dungeons option) *spoofed*
    ["DME"] = 813,  -- Dire Maul - East
    ["DMW"] = 814,  -- Dire Maul - West
    ["DMN"] = 815,  -- Dire Maul - North
    ["STR"] = {
        816,  -- Stratholme (Main Gate)
        1603, -- Stratholme (Service Gate)
    },
    ["SCH"] = 797,  -- Scholomance
    ["LBRS"] = 812,  -- Lower Blackrock Spire
    ["UBRS"] = 837,  -- Upper Blackrock Spire
    -- Raids
    ["ZG"] = 836,  -- Zul'Gurub
    ["BWL"] = 840,  -- Blackwing Lair
    ["NAXX"] = 841,  -- Naxxramas
    -- Battlegrounds
    ["WSG"] = { -- Warsong Gulch
        919, -- "Warsong Gulch (10-19)"
        920, -- "Warsong Gulch (20-29)"
        921, -- "Warsong Gulch (30-39)"
        922, -- "Warsong Gulch (40-49)"
        923, -- "Warsong Gulch (50-59)"
        924, -- "Warsong Gulch (60)"
    },
    ["AB"] = { -- Arathi Basin
        926, -- "Arathi Basin (20-29)"
        927, -- "Arathi Basin (30-39)"
        928, -- "Arathi Basin (40-49)"
        929, -- "Arathi Basin (50-59)"
        930, -- "Arathi Basin (60)"
    },
    ["AV"] = 932,  -- Alterac Valley
    -- SoD/Classic augmented
    ["BFD"] = not isSoD and 801 or 1604,  -- Blackfathom Deeps
    ["GNO"] = not isSoD and 803 or 1605,  -- Gnomeregan
    ["ST"] = not isSoD and 810 or 1606,  -- Sunken Temple
    ["ONY"] = not isSoD and 838 or 1612,  -- Onyxia
    ["MC"] = not isSoD and 839 or 1613,  -- Molten Core
    ["AQ20"] = not isSoD and 842 or 1615,  -- Ahn'Qiraj Ruins
    ["AQ40"] = not isSoD and 843 or 1614,  -- Ahn'Qiraj Temple
    -- SoD Specific
    ["DFC"] = isSoD and 1607 or nil, -- Demon Fall Canyon
    ["AZGS"] = isSoD and 1608 or nil, -- Storm Cliffs (Azuregoes)
    ["KAZK"] = isSoD and 1609 or nil, -- Tainted Scar (Kazzak)
    ["CRY"] = isSoD and 1611 or nil, -- Crystal Vale (Thunderaan)
    ["NMG"] = isSoD and 1610 or nil, -- Nightmare Grove (Emerald Dragons)
    ["KARA"] = isSoD and 1693 or nil, -- Karazhan Crypts
    ["ENCLAVE"] = isSoD and 1710 or nil -- Scarlet Enclave
}

--- Any info that needs to be overridden/spoofed for a specific instances should be done here.
local infoOverrides = {
    CRY = isSoD and { name = L.THUNDERAAN, typeID = DungeonType.WorldBoss } or nil,
    AZGS = isSoD and { name = L.AZUREGOS, typeID = DungeonType.WorldBoss } or nil,
    KAZK = isSoD and { name = L.LORD_KAZZAK, typeID = DungeonType.WorldBoss } or nil,
    NMG = isSoD and { typeID = DungeonType.WorldBoss } or nil,
    -- Strat is split into "Main"/"Service" Gates between 2 IDs. We use just the plain zone name.
    STR = { name = GetRealZoneText(329) },
    -- GetActivityInfoTable has unique entries for each BG level bracket. We however use a single entry.
    WSG = { minLevel = 10, maxLevel = 60, expansionID = Expansions.Classic },
    AB = { minLevel = 20, maxLevel = 60, expansionID = Expansions.Classic },
    -- Note: Following entries for are completely spoofed. hardcoded info here.
    SM2 = {
        name = GetRealZoneText(189),
        minLevel = 30, -- SMG min
        maxLevel = 46, -- SMC max
        typeID = DungeonType.Dungeon,
        expansionID = Expansions.Classic,
    },
    DM2 = {
        name = GetRealZoneText(429),
        minLevel = 54, -- DME min
        maxLevel = 60, -- DMN max
        typeID = DungeonType.Dungeon,
        expansionID = Expansions.Classic,
    },
}

for key, activityIDs in pairs(LFGActivityIDs) do
   if type(activityIDs) ~= "table" then activityIDs = { activityIDs } end
   addon.Dungeons.queueActivityForInfo(key, activityIDs)
end
for key, activityInfo in pairs(infoOverrides) do
    addon.Dungeons.queueActivityInfoOverride(key, activityInfo)
end
