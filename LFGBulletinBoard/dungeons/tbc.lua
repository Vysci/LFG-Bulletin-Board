local tocName,
    ---@class Addon_DungeonData: Addon_Localization
    addon = ...;

local Expansion = addon.Enum.Expansions

-- only load for TBC clients.
-- todo: add this file + classic.lua setup to the cata->mists pipeline. atm cata.lua redeclares tbc + classic dungeons
if Expansion.Current ~= Expansion.BurningCrusade then return end

-- Required APIs.
assert(C_LFGList.GetActivityInfoTable, tocName .. " requires the API `C_LFGList.GetActivityInfoTable` for parsing dungeon info")

local debug = false
local print = function(...) if debug then print(tocName, ...) end end

local LFGActivityIDs = {
    ARENA = { -- "Arena"
        936, -- "2v2"
        937, -- "3v3"
        938, -- "5v5"
    },
    ARC = { -- "The Arcatraz"
        915, -- "The Arcatraz (Heroic)"
        834, -- "The Arcatraz (Normal)"
    },
    CRYPTS = { -- "Auchenai Crypts"
        903, -- "Auchenai Crypts (Heroic)"
        824, -- "Auchenai Crypts (Normal)"
    },
    MT = { -- "Mana-Tombs"
        904, -- "Mana-Tombs (Heroic)"
        823, -- "Mana-Tombs (Normal)"
    },
    SETH = { -- "Sethekk Halls"
        905, -- "Sethekk Halls (Heroic)"
        825, -- "Sethekk Halls (Normal)"
    },
    SL = { -- "Shadow Labyrinth"
        906, -- "Shadow Labyrinth (Heroic)"
        826, -- "Shadow Labyrinth (Normal)"
    },
    HYJAL = 849, -- "Battle for Mount Hyjal" aka "Hyjal Past"
    BT = 850, -- "Black Temple"
    BF = { -- "Blood Furnace"
        912, -- "Blood Furnace (Heroic)"
        818, -- "Blood Furnace (Normal)"
    },
    BOT = { -- "The Botanica"
        918, -- "The Botanica (Heroic)"
        833, -- "The Botanica (Normal)"
    },
    BM = { -- "The Black Morass" aka "Opening of the Dark Portal"
        907, -- "The Black Morass (Heroic)"
        831, -- "The Black Morass (Normal)"
    },
    OHB = { -- "The Escape From Durnholde" (aka Old Hillsbrad Foothills)
        908, -- "The Escape From Durnholde (Heroic)"
        830, -- "The Escape From Durnholde (Normal)"
    },
    SP = { -- "Slave Pens"
        909, -- "Slave Pens (Heroic)"
        820, -- "Slave Pens (Normal)"
    },
    UB = { -- "Underbog"
        911, -- "Underbog (Heroic)"
        821, -- "Underbog (Normal)"
    },
    GL = 846, -- "Gruul's Lair"
    RAMPS = { -- "Hellfire Ramparts"
        913, -- "Hellfire Ramparts (Heroic)"
        817, -- "Hellfire Ramparts (Normal)"
    },
    SH = { -- "Shattered Halls"
        914, -- "Shattered Halls (Heroic)"
        819, -- "Shattered Halls (Normal)"
    },
    KARA = 844, -- "Karazhan"
    MGT = { -- "Magister's Terrace"
        917, -- "Magister's Terrace (Heroic)"
        835, -- "Magister's Terrace (Normal)"
    },
    MAG = 845, -- "Magtheridon's Lair"
    MECH = { -- "The Mechanar"
        916, -- "The Mechanar (Heroic)"
        832, -- "The Mechanar (Normal)"
    },
    SSC = 848, -- "Serpentshrine Cavern"
    SV = { -- "Steamvault"
        910, -- "Steamvault (Heroic)"
        822, -- "Steamvault (Normal)"
    },
    SWP = 852, -- "Sunwell Plateau"
    EYE = 847, -- "Tempest Keep" aka "The Eye"
    ZA = 851, -- "Zul'Aman"

    -- Battlegrounds
    -- The new classic bg level bracket activityIDs should be appended those from classic.lua
    WSG = 925, -- "Warsong Gulch" (70)
    AV = 933, -- "Alterac Valley" (70)
    AB = 931, -- "Arathi Basin" (70)
    EOTS = { -- "Eye of the Storm"
        934, -- "Eye of the Storm" (61-69)
        935, -- "Eye of the Storm" (70)
    },
}

local infoOverrides = {
    -- GetActivityInfoTable has unique entries for each BG level bracket. We however use a single entry.
    EOTS = { minLevel = 61, maxLevel = 70, expansionID = Expansion.BurningCrusade },
    WSG = { maxLevel = 70, expansionID = Expansion.BurningCrusade },
    AB = { maxLevel = 70, expansionID = Expansion.BurningCrusade },
    AV = { minLevel = 51, maxLevel = 70, expansionID = Expansion.BurningCrusade },
    ARENA = { name = C_LFGList.GetActivityGroupInfo(299)}
}

for key, activityIDs in pairs(LFGActivityIDs) do
   if type(activityIDs) ~= "table" then activityIDs = { activityIDs } end
   addon.Dungeons.queueActivityForInfo(key, activityIDs, {
        appendIDsOnCollision = (key == "AB") or (key == "WSG") or (key == "AV")
   })
end
for key, activityInfo in pairs(infoOverrides) do
    addon.Dungeons.queueActivityInfoOverride(key, activityInfo)
end

