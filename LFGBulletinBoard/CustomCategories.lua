local TOCNAME,
    ---@class Addon_CustomFilters
    Addon = ...;

local HIDDEN_LEVEL_RANGE = { 0, 100 };

local isModuleInitialized = false
local isInitializedOrPanic = function()
    assert(isModuleInitialized, "CustomFilters module not initialized yet, should call `Addon:InitializeCustomFilters()` after saved variables are available")
end

---@alias Locale "enUS"|"enGB"|"deDE"|"ruRU"|"frFR"|"zhTW"|"zhCN"|"ptBR"|"esES"|"koKR"

---@class CustomFilter
---@field name string
---@field key string
---@field tags table<Locale, string>
---@field levels {[1]: number, [2]: number}
---@field sortIdx number
---@field isHidden boolean? # `true` if the preset should be completely hidden from the user

---@type {[string]: CustomFilter}
local presets = {
    ["BOOSTS"] = {
        name = "Boosting Services",
        key = "BOOSTS",
        tags = {
            enUS = "boost boosting" ,
        },
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isHidden = nil,
        sortIdx = 1,
    }
}


function Addon.InitializeCustomFilters()
    assert(GroupBulletinBoardDB, "`GroupBulletinBoardDB` not found in `InitializeCustomFilters()`. Initialize *after* ADDON_LOADED event")
    if not GroupBulletinBoardDB.CustomFilters then
        ---@type {[string]: CustomFilter}
        GroupBulletinBoardDB.CustomFilters = CopyTable(presets)
    end
    -- insert any enabled presets into the `CustomFilters` table
    for key, preset in pairs(presets) do
        local store = GroupBulletinBoardDB.CustomFilters[key]
        if not store and not preset.isHidden then
            GroupBulletinBoardDB.CustomFilters[key] = CopyTable(preset)
        end
    end
    -- use this point to perform any db migrations. Like removing deprecated keys.
    local invalidKeys = {}
    for _, entry in pairs(GroupBulletinBoardDB.CustomFilters) do
        -- invalid entries
        if not entry.name or entry.name == "" then
            if entry.key then entry.name = entry.key
            else tinsert(invalidKeys, entry.key) end
        end
    end
    for _, key in ipairs(invalidKeys) do
        GroupBulletinBoardDB.CustomFilters[key] = nil
    end

    isModuleInitialized = true
end

---@return string[] keys Sorted keys
function Addon.GetCustomFilterKeys()
    isInitializedOrPanic()
    local savedFilters = GroupBulletinBoardDB.CustomFilters
    local keys = {}
    for key, entry in pairs(savedFilters) do
        if not entry.isHidden then 
            table.insert(keys, key) 
        end
    end
    table.sort(keys, function(a, b) 
        a, b = savedFilters[a], savedFilters[b]
        if a.sortIdx == b.sortIdx then
            return a.key < b.key
        else return a.sortIdx < b.sortIdx end
    end)
    return keys
end

---@param tagListByLoc {[Locale]: {[string]: string[]}}
---@return boolean anyAdded `true` if any tags were inserted into the tag list
function Addon.AddCustomFilterTags(tagListByLoc)
    isInitializedOrPanic()
    local filterKeys = Addon.GetCustomFilterKeys()
    local customFiltersDB = GroupBulletinBoardDB.CustomFilters
    local anyAdded = false
    for _, customKey in ipairs(filterKeys) do
        local entry = customFiltersDB[customKey]
        -- hack: add enGB entries for enUS.(tagListByLoc expects enGB)          
        -- should move away from enGB to enUS at some point. GetLocale never returns enGB
        entry.tags.enGB = entry.tags.enUS
        for locale, tagList in pairs(tagListByLoc) do
            if entry.tags[locale] then
                tagList[entry.key] = {strsplit(" ", entry.tags[locale])}
                anyAdded = true
            end
        end
    end
    return anyAdded
end

---@return {[string]: string} nameList map of `[tagKey] => displayName`
function Addon.GetCustomFilterNames()
    local nameList = {}
    isInitializedOrPanic()
    local filterKeys = Addon.GetCustomFilterKeys()
    local customFiltersDB = GroupBulletinBoardDB.CustomFilters
    for _, key in ipairs(filterKeys) do
        local entry = customFiltersDB[key]
        nameList[entry.key] = entry.name
    end
    return nameList
end

function Addon.GetAllCustomFilterLevels()
    isInitializedOrPanic()
    local customFilterDB = GroupBulletinBoardDB.CustomFilters
    local keys = Addon.GetCustomFilterKeys()
    local ranges = {}
    for _, key in ipairs(keys) do
        local entry = customFilterDB[key]
        if entry.levels then
            ranges[key] = entry.levels
        end
    end
    return ranges
end