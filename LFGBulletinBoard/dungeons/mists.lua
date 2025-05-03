if WOW_PROJECT_ID <= WOW_PROJECT_CATACLYSM_CLASSIC then return end
local _, addon = ...;
local DungeonType = addon.Enum.DungeonType
local Expansions = addon.Enum.Expansions

local ActivityIDs = {
    MSV = { -- "Mogu'shan Vaults"
        335, -- "Mogu'shan Vaults (10 Normal)"
        336, -- "Mogu'shan Vaults (10 Heroic)"
        337, -- "Mogu'shan Vaults (25 Normal)"
        338, -- "Mogu'shan Vaults (25 Heroic)"
    },
    NIUZAO_TEMPLE = { -- "Siege of Niuzao Temple"
        159, -- "Siege of Niuzao Temple (Normal)"
        171, -- "Siege of Niuzao Temple (Heroic)"
        1720, -- "Siege of Niuzao Temple (Celestial)"
    },
    SETTING_SUN = { -- "Gate of the Setting Sun"
        160, -- "Gate of the Setting Sun (Normal)"
        167, -- "Gate of the Setting Sun (Heroic)"
        1716, -- "Gate of the Setting Sun (Celestial)"
    },
    SM2 = { -- "Scarlet Monastery"
        169, -- "Scarlet Monastery (Heroic)"
        1718, -- "Scarlet Monastery (Celestial)"
    },
    SCARLET_HALLS = { -- "Scarlet Halls"
        170, -- "Scarlet Halls (Heroic)"
        1719, -- "Scarlet Halls (Celestial)"
    },
    TOT = { -- "Throne of Thunder"
        347, -- "Throne of Thunder (10 Normal)"
        348, -- "Throne of Thunder (10 Heroic)"
        349, -- "Throne of Thunder (25 Heroic)"
        350, -- "Throne of Thunder (25 Normal)"
    },
    MSP = { -- "Mogu'shan Palace"
        158, -- "Mogu'shan Palace (Normal)"
        166, -- "Mogu'shan Palace (Celestial)"
    },
    TOTJS = { -- "Temple of the Jade Serpent"
        155, -- "Temple of the Jade Serpent (Normal)"
        163, -- "Temple of the Jade Serpent (Heroic)"
        1713, -- "Temple of the Jade Serpent (Celestial)"
    },
    SPM = { -- "Shado-Pan Monastery"
        157, -- "Shado-Pan Monastery (Normal)"
        165, -- "Shado-Pan Monastery (Heroic)"
        1715, -- "Shado-Pan Monastery (Celestial)"
    },
    BREWERY = { -- "Stormstout Brewery"
        156, -- "Stormstout Brewery (Normal)"
        164, -- "Stormstout Brewery (Heroic)"
        1714, -- "Stormstout Brewery (Celestial)"
    },
    TERRACE = { -- "Terrace of Endless Spring"
        343, -- "Terrace of Endless Spring (10 Normal)"
        344, -- "Terrace of Endless Spring (10 Heroic)"
        345, -- "Terrace of Endless Spring (25 Normal)"
        346, -- "Terrace of Endless Spring (25 Heroic)"
    },
    HEART_OF_FEAR = { -- "Heart of Fear"
        339, -- "Heart of Fear (10 Normal)"
        340, -- "Heart of Fear (10 Heroic)"
        341, -- "Heart of Fear (25 Normal)"
        342, -- "Heart of Fear (25 Heroic)"
    },
    DS = { -- "Dragon Soul" (for some reason MoP changes the ID's of DS)
        331, -- "Dragon Soul (10 Normal)"
        332, -- "Dragon Soul (10 Heroic)"
        333, -- "Dragon Soul (25 Heroic)"
        334, -- "Dragon Soul (25 Normal)"
    },
    SCH = { -- "Scholomance"
        797, -- "Scholomance"
        168, -- "Scholomance (Heroic)"
        1717, -- "Scholomance (Celestial)"
    },
}
-- The latest bgs aren't in the ActivityID table, so we need to add/spoof them manually
local SpoofedActivityIDs = {
    SSM = 50001, -- Silvershard Mines
    KOTMOGU = 50002, -- Temple of Kotmogu
}

local mistsMaxLevel = GetMaxLevelForExpansionLevel(Expansions.Mists)
local spoofBattleground = function(name)
	return {
		name = name,
		minLevel = mistsMaxLevel,
		maxLevel = mistsMaxLevel,
		typeID = DungeonType.Battleground,
        -- consider bg's part of the current expansion
		expansionID = Expansions.Current,
	}
end

--- Any info that needs to be overridden/spoofed/adjusted for a specific instances should be done here.
--- Useful for overriding properties generated from previous expansions.
local infoOverrides = {
    --- Adjust battlegrounds added in `cata.lua` to have the correct max level
    AV = { maxLevel = mistsMaxLevel },
    AB = { maxLevel = mistsMaxLevel },
    WSG = { maxLevel = mistsMaxLevel },
    EOTS = { maxLevel = mistsMaxLevel },
    SOTA = { maxLevel = mistsMaxLevel },
    IOC = { maxLevel = mistsMaxLevel },
    TP = { maxLevel = mistsMaxLevel },
    BFG = { maxLevel = mistsMaxLevel },
    RBG = {maxLevel = mistsMaxLevel, minLevel = mistsMaxLevel},
    ARENA = {maxLevel = mistsMaxLevel, minLevel = mistsMaxLevel},
    SSM = spoofBattleground(GetRealZoneText(727)),
    KOTMOGU = spoofBattleground(GetRealZoneText(998)),
}

for activityKey, activityIDs in pairs(ActivityIDs) do
    if type(activityIDs) ~= "table" then activityIDs = { activityIDs } end
    addon.Dungeons.queueActivityForInfo(activityKey, activityIDs)
end
for activityKey, spoofedID in pairs(SpoofedActivityIDs) do
    addon.Dungeons.queueActivityForInfo(activityKey, {spoofedID})
end
for activityKey, activityInfo in pairs(infoOverrides) do
    addon.Dungeons.queueActivityInfoOverride(activityKey, activityInfo)
end
