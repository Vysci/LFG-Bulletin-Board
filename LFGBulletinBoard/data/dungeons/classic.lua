local _, addon = ...

-- exists in classic even though no Dungeon Finder.
assert(GetLFGDungeonInfo, _ .. " requires the API `GetLFGDungeonInfo` for parsing dungeon info")

---@enum DungeonTypeID
local DungeonType = {
    Dungeon = 1,
    Raid = 2,
    Battleground = 5,
}

---@alias DungeonID number

---@class DungeonInfo
---@field name string # Game client localized name of the dungeon
---@field minLevel number
---@field maxLevel number
---@field typeID DungeonTypeID -- 1 = dungeon, 2 = raid, 5 = bg
---@field subtypeID number? -- not really neeeded

--see https://wago.tools/db2/LFGDungeons?build=1.15.2.54332
-- NOTE: classic db only has up to 131 in the db
-- this excludes individual SM wings, AQ20, AQ40, and Naxx
-- they are in wotlk client, stopping at 165
local MAX_DUNGEON_ID = 165;

local CLIENT_LOCALE = GetLocale()
local isSoD = C_Seasons and (C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery)

local debug = false
local print = function(...) if debug then print(...) end end

-- see https://wago.tools/db2/LFGDungeons?build=3.4.3.54261 (for Naxx and AQ20/40)
-- Because classic era client db only has up to ID 131, `GetLFGDungeonInfo` will return nil for these. (and 18)
-- (as of 1.15.2.54332, ymmv)
local manualEntries = {
    [159] = {
        name = {
            enUS = "Naxxramas",
            deDE = "Naxxramas",
            esES = "Naxxramas",
            esMX = "Naxxramas",
            frFR = "Naxxramas",
            itIT = "Naxxramas",
            koKR = "낙스라마스",
            ptBR = "Naxxramas",
            ruRU = "Наксрамас",
            zhCN = "纳克萨玛斯",
            zhTW = "納克薩瑪斯",
        },
        minLevel = 60,
        maxLevel = 60,
        typeID = 2,
        subtypeID = 0,
    },
    [160] = {
        name = {
            enUS = "Ahn'Qiraj Ruins",
            deDE = "Ruinen von Ahn'Qiraj",
            esES = "Ruinas de Ahn'Qiraj",
            esMX = "Ruinas de Ahn'Qiraj",
            frFR = "Ruines d’Ahn’Qiraj",
            itIT = "Ahn'Qiraj Ruins",
            koKR = "안퀴라즈 폐허",
            ptBR = "Ruínas de Ahn'Qiraj",
            ruRU = "Руины Ан'Киража",
            zhCN = "安其拉废墟",
            zhTW = "安其拉廢墟",
        },
        minLevel = 60,
        maxLevel = 60,
        typeID = 2,
        subtypeID = 0,
    },
    [161] = {
        name = {
            enUS = "Ahn'Qiraj Temple",
            deDE = "Tempel von Ahn'Qiraj",
            esES = "Templo de Ahn'Qiraj",
            esMX = "Templo de Ahn'Qiraj",
            frFR = "Temple d’Ahn’Qiraj",
            itIT = "Ahn'Qiraj Temple",
            koKR = "안퀴라즈 사원",
            ptBR = "Templo de Ahn'Qiraj",
            ruRU = "Храм Ан'Киража",
            zhCN = "安其拉神殿",
            zhTW = "安其拉神廟",
        },
        minLevel = 60,
        maxLevel = 60,
        typeID = 2,
        subtypeID = 0,
    },
    [18] = {
        name = {
            enUS = "Scarlet Monastery - Graveyard",
            deDE = "Scharlachrotes Kloster - Friedhof",
            esES = "Monasterio Escarlata: Cementerio",
            esMX = "Monasterio Escarlata - Cementerio",
            frFR = "Monastère Écarlate - cimetière",
            itIT = "Scarlet Monastery - Graveyard",
            koKR = "붉은십자군 수도원 - 묘지",
            ptBR = "Monastério Escarlate - Cemitério",
            ruRU = "Монастырь Алого ордена: кладбище",
            zhCN = "血色修道院 - 墓地",
            zhTW = "血色修道院 - 墓園",
        },
        typeID = 1,
        subtypeID = 1,
        maxLevel = 37,
        minLevel = 29,
    },
    [163] = {
        name = {
            enUS = "Scarlet Monastery - Armory",
            deDE = "Scharlachrotes Kloster - Waffenkammer",
            esES = "Monasterio Escarlata: Armería",
            esMX = "Monasterio Escarlata - Arsenal",
            frFR = "Monastère Écarlate - armurerie",
            itIT = "Scarlet Monastery - Armory",
            koKR = "붉은십자군 수도원 - 무기고",
            ptBR = "Monastério Escarlate - Armaria",
            ruRU = "Монастырь Алого ордена: оружейная",
            zhCN = "血色修道院 - 军械库",
            zhTW = "血色修道院 - 軍械庫",
        },
        typeID = 1,
        subtypeID = 1,
        maxLevel = 42,
        minLevel = 34,
    },
    [164] = {
        name = {
            enUS = "Scarlet Monastery - Cathedral",
            deDE = "Scharlachrotes Kloster - Kathedrale",
            esES = "Monasterio Escarlata: Catedral",
            esMX = "Monasterio Escarlata - Catedral",
            frFR = "Monastère Écarlate - cathédrale",
            itIT = "Scarlet Monastery - Cathedral",
            koKR = "붉은십자군 수도원 - 대성당",
            ptBR = "Monastério Escarlate - Catedral",
            ruRU = "Монастырь Алого ордена: собор",
            zhCN = "血色修道院 - 教堂",
            zhTW = "血色修道院 - 教堂",
        },
        typeID = 1,
        subtypeID = 1,
        maxLevel = 45,
        minLevel = 37,
    },
    [165] = {
        name = {
            enUS = "Scarlet Monastery - Library",
            deDE = "Scharlachrotes Kloster - Bibliothek",
            esES = "Monasterio Escarlata: Biblioteca",
            esMX = "Monasterio Escarlata - Biblioteca",
            frFR = "Monastère Écarlate - bibliothèque",
            itIT = "Scarlet Monastery - Library",
            koKR = "붉은십자군 수도원 - 도서관",
            ptBR = "Monastério Escarlate - Biblioteca",
            ruRU = "Монастырь Алого ордена: библиотека",
            zhCN = "血色修道院 - 图书馆",
            zhTW = "血色修道院 - 圖書館",
        },
        maxLevel = 40,
        minLevel = 32,
        typeID = 1,
        subtypeID = 1
    },
    [32] = {
        -- Note: This DungeonID does not exist in classic client
        -- We are hijacking it here to put the base "Dire Maul" entry
        name = {
            enUS = "Dire Maul",
            deDE = "Düsterbruch",
            esES = "La Masacre",
            esMX = "La Masacre",
            frFR = "Haches-Tripes",
            itIT = "Dire Maul",
            koKR = "혈투의 전장",
            ptBR = "Gládio Cruel",
            ruRU = "Забытый город",
            zhCN = "厄运之槌",
            zhTW = "厄運之槌",
        },
        maxLevel = 63,
        minLevel = 55,
        typeID = 1,
        subtypeID = 1,
    },
}

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

--- Needed for SoD which has changed some dungeons sizes and level ranges
local infoOverrides = {
    -- BFD
    [9] = isSoD and {
        typeID = DungeonType.Raid,
        minLevel = 25,
        maxLevel = 40,
        size = 10,
    },
    -- Gnomer
    [13] = isSoD and {
        typeID = DungeonType.Raid,
        minLevel = 40,
        maxLevel = 50,
        size = 10,
    },
    -- ST
    [27] = isSoD and {
        typeID = DungeonType.Raid,
        minLevel = 50,
        maxLevel = 60,
        size = 20,
    },
}

-- manually associate keys in Tags.lua
-- this is definately not sustainable outside of classic
local dungeonCodeByID = {
    [3] = "RFC",
    [1] = "WC",
    [5] = "DEADMINES",
    [7] = "SFK",
    [11] = "STK", -- Stocks,
    [9] = "BFD",
    [13] = "GNO",
    [15] = "RFK",
    [17] = "SM2",   -- base "Scarelet Monestary"
    [18] = "SMG",   -- GY
    [163] = "SML",  -- Lib
    [164] = "SMA",  -- Arm
    [165] = "SMC",  -- Cath
    [19] = "RFD",
    [21] = "ULD",
    [23] = "ZF",
    [25] = "MAR",
    [27] = "ST",
    [29] = "BRD",
    [33] = "DM2",  -- Base "Dire Maul" DNE
    [34] = "DME",
    [36] = "DMN",
    [38] = "DMW",
    [39] = "STR", -- Strat
    [2] = "SCH",  -- Scholo
    [31] = "LBRS",
    [43] = "UBRS",
    [41] = "ZG",
    [45] = "ONY",
    [160] = "AQ20", -- AQ20
    [47] = "MC",    -- MC
    [49] = "BWL",   -- BWL
    [161] = "AQ40", -- AQ40
    [159] = "NAX",  -- Naxx
    [53] = "WSG",   -- WSG
    [55] = "AB",    -- AB
    [51] = "AV",    -- AV
}

---@type {[DungeonID]: DungeonInfo}
local dungeonInfoCache = {}
do
    -- only cache dungeons, raids, and battlegrounds
    local trackedDungeonTypes = {
        [DungeonType.Dungeon] = true,
        [DungeonType.Raid] = true,
        [DungeonType.Battleground] = true,
    }
    local function cacheDungeonInfo(dungeonID)
        local info = {}
        do
            local name, typeID, subtypeID, minLevel, maxLevel = GetLFGDungeonInfo(dungeonID);
            info = {
                name = name,
                minLevel = minLevel,
                maxLevel = maxLevel,
                typeID = typeID,
                subtypeID = subtypeID,
                tagKey = dungeonCodeByID[dungeonID],
            }
        end
        if not info.name then
            local manualEntry = manualEntries[dungeonID]
            if manualEntry then
                info = {
                    -- default to enUS if locale is missing
                    name = manualEntry.name[CLIENT_LOCALE] or manualEntry.name.enUS,
                    typeID = manualEntry.typeID,
                    subtypeID = manualEntry.subtypeID,
                    minLevel = manualEntry.minLevel,
                    maxLevel = manualEntry.maxLevel,
                }
            else
                print(_ .. ": Failed to get dungeon info for ID: " .. dungeonID)
                return;
            end
        end
        local override = infoOverrides[dungeonID]
        if override then
            for k, v in pairs(override) do
                info[k] = v
            end
        end
        if info.typeID and trackedDungeonTypes[info.typeID] then
            dungeonInfoCache[dungeonID] = info
        else
            print(_ .. ": Skipping dunegeon " .. info.name .. " dungeonID: " .. dungeonID .. " typeID: " .. info.typeID)
        end
    end
    for dungeonID = 1, MAX_DUNGEON_ID do
        cacheDungeonInfo(dungeonID)
    end
end



local localizedNames -- cache to save some iteration cycles.
---@return {[DungeonID]: string} # Table mapping `dungeonID` to it's localized name.
--- Because of holes in the `dungeonID` range, use `pairs` to iterate table.
function addon.GetClassicLocalizedDungeonNames()
    if not localizedNames then
        localizedNames = {}
        for dungeonID, info in pairs(dungeonInfoCache) do
            assert(info.name, "Missing name for dungeonID: " .. dungeonID)
            localizedNames[dungeonID] = info.name
        end
    end
    return localizedNames
end

local raidCache
---@return {[DungeonID]: DungeonInfo} # Table mapping `dungeonID` to it's info.
--- Because of holes in the `dungeonID` range, use `pairs` to iterate table.
function addon.GetClassicRaids()
    if not raidCache then
        raidCache = {}
        for dungeonID, info in pairs(dungeonInfoCache) do
            if info.typeID == DungeonType.Raid then
                raidCache[dungeonID] = CopyTable(info)
                raidCache[dungeonID].size = dungeonSizes[dungeonID]
            end
        end
    end
    return raidCache
end

addon.localizedDungeonIfno = dungeonInfoCache
