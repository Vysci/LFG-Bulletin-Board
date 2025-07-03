local TOCNAME,
    ---@class Addon_CustomFilters: Addon_LibGPIOptions
    Addon = ...;

-- Note on verbiage: Here im considering the "store" to be a category's entry table in the savedVars 
-- ie `store = GroupBulletBoard.CustomFilters[key]`. Also, a "Category" == a "Filter"   

local HIDDEN_LEVEL_RANGE = { 0, 100 };

local isModuleInitialized = false
local isInitializedOrPanic = function()
    assert(isModuleInitialized, "CustomFilters module not initialized yet, should call `Addon:InitializeCustomFilters()` after saved variables are available")
end
local USER_KEY_BASE = "USER_CATEGORY_%i" 
local USER_KEY_IDX_CAPTURE = "USER_CATEGORY_(%d+)"

-- "Learning this trait will lock you to this path.|nThis can't be undone."" => "|nThis can't be undone."
-- note: remember check for zh the "period". Also, missing newline in deDE so fallback to empty string.
local PERMANENT_ACTION_WARNING = RELIC_FORGE_CONFIRM_TRAIT_FIRST_TIME:match("\124.+[。%.]") or ""
local CONFIRM_REMOVAL = CONFIRM_GLYPH_REMOVAL:gsub("%%s", "\"%%s\"") -- "Are you sure you want to remove \"%s\"?"
---@type "Are you sure you want to remove \"%s\"?|nThis action cannot be undone."
local FILTER_REMOVAL_WARNING = CONFIRM_REMOVAL..PERMANENT_ACTION_WARNING 
local CHARACTER_SPECIFIC_SYMBOL = "\42" -- "*"

local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isCataclysm = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isMists = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
local isSoD = isClassicEra and C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery
local ExpansionEnum  = (Addon.Enum --[[@as AddonEnum]]).Expansions

---@alias Locale "enUS"|"enGB"|"deDE"|"ruRU"|"frFR"|"zhTW"|"zhCN"|"ptBR"|"esES"|"koKR"

---@class CustomFilter
---@field name string
---@field key string
---@field tags table<Locale, string>
---@field levels {[1]: number, [2]: number}
---@field sortIdx number # ties broken by key alphabetically. preset value is relatively arbitrary.
---@field isHidden boolean? # `true` if the filter should be hidden from UI. (used instead of deletion for saved presets)
---@field isDisabled boolean # `true` if the preset should be completely disabled for the current client (used by presets only)
---@field includeItemLinks boolean? # `true` if the filter should parse item links for keys words

---@type {[string]: CustomFilter}
local presets = {
    RDF = { -- Random Dungeon Finder (Wotlk+)
        name = LFG_TYPE_RANDOM_DUNGEON,
        tags = {
            enUS = "rdf random dungeons spam heroics gamma gammas celestial",
            -- deDE = nil,
            -- ruRU = nil,
            -- frFR = nil,
            -- zhTW = nil,
            -- zhCN = nil,
            -- ptBR = nil,
            -- esES = nil,
        },
        key = "RDF",
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isDisabled = ExpansionEnum.Current < ExpansionEnum.Wrath,
        sortIdx = 1,
    },
    CHALLENGE_MODES = { -- Mists Challenge Mode dungeons
        name = CHALLENGE_MODE,
        tags = {
            enUS = "challenge cm",
        },
        key = "CHALLENGE_MODES",
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isDisabled = ExpansionEnum.Current ~= ExpansionEnum.Mists,
        sortIdx = 2,
    },
    BLOOD = { -- Bloodmoon Event (SoD)
        name = "Bloodmoon",
        tags = {
            enUS = "blood bloodmoon bm",
        },
        key = "BLOOD",
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isDisabled = not isSoD,
        sortIdx = 1,
    },
    BRE = { -- Blackrock Eruption (SoD)
        name = "Blackrock Eruption",
        tags = {
            enUS = "eruption bre brm dailys dialies dailies daily",
        },
        key = "BRE",
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isDisabled = not isSoD,
        sortIdx = 1,
    },
    INCUR = { -- Incursion Event (SoD)
        name = "Incursions",
        tags = {
            enUS = "inc incur incursion incursions loops",
        },
        key = "INCUR",
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isDisabled = not isSoD,
        sortIdx = 2,
    },
    BOOSTS = {
        name = "Boosting Services",
        key = "BOOSTS",
        tags = {
            enUS = "boost boosting" ,
        },
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        isDisabled = false,
        sortIdx = 2,
    }, 
}

--- Initializes and validates saved variable table entries for custom user filters/categories.
function Addon.InitializeCustomFilters()
    assert(GroupBulletinBoardDB, "`GroupBulletinBoardDB` not found in `InitializeCustomFilters()`. Initialize *after* ADDON_LOADED event")
    if not GroupBulletinBoardDB.CustomFilters then GroupBulletinBoardDB.CustomFilters = {} end
    
    -- insert any client *enabled* presets into the `CustomFilters` table
    for key, preset in pairs(presets) do
        local stored = GroupBulletinBoardDB.CustomFilters[key]
        -- hide any saved presets that are disabled for current client
        if stored and preset.isDisabled then
            stored.isHidden = true -- this allows hiding SoD specific presets in Era realms
        end
        if not stored and not preset.isDisabled then
            GroupBulletinBoardDB.CustomFilters[key] = CopyTable(preset)
            GroupBulletinBoardDB.CustomFilters[key].isDisabled = nil
        end
    end

    -- validate saved entries
    local invalidKeys = {}
    for key, entry in pairs(GroupBulletinBoardDB.CustomFilters) do
        if entry.key then
            if not entry.name or entry.name == "" then
                entry.name = (presets[key] and presets[key].name) or key
            end
            if type(entry.tags) ~= "table" then
                entry.tags = (presets[key] and presets[key].tags) or {}
            end
            if type(entry.levels) ~= "table" then
                entry.levels = CopyTable(HIDDEN_LEVEL_RANGE)
            end
            if type(entry.sortIdx) ~= "number" then
                entry.sortIdx = 1
            end
        else
            -- remove entries with missing keys (shouldn't happen, but just in case)
            tinsert(invalidKeys, key)
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

---@param tagListByLoc {[Locale]: {[string]: string[]}} expects the dungeonTagsLoc table
function Addon.SyncCustomFilterTags(tagListByLoc)
    isInitializedOrPanic()
    local customStore = GroupBulletinBoardDB.CustomFilters
    local validKeys = tInvert(Addon.GetCustomFilterKeys())
    for _, entry in pairs(customStore) do
        -- hack: add enGB entries for enUS.(tagListByLoc expects enGB)          
        -- should move away from enGB to enUS at some point. GetLocale never returns enGB
        entry.tags.enGB = entry.tags.enUS 
    end
    for locale, tagList in pairs(tagListByLoc) do
        for tagKey, _ in pairs(tagList) do
            if tagKey:match(USER_KEY_IDX_CAPTURE) 
            or presets[tagKey]
            then -- Update any existing and valid custom categories tags
                local entry = customStore[tagKey]
                -- note: presets aren't deleted just hidden.
                local tagString = (entry and not entry.isHidden) and entry.tags[locale]
                tagListByLoc[locale][tagKey] = tagString and {strsplit(" ", tagString)} or nil
                validKeys[tagKey] = nil
            end
        end
    end
    for key, _ in pairs(validKeys) do -- Add any missing valid custom categories
        local entry = customStore[key]
        for locale, _ in pairs(tagListByLoc) do
            tagListByLoc[locale][key] = entry.tags[locale] and {strsplit(" ", entry.tags[locale])} or nil
        end
    end
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

---@param tagsOnly boolean? If true, skips updating the dungeon Names/Levels and Sort tables (for tag updates)
---@param skipTags boolean? If true, skips updating the dungeonTagsLoc table (for renames/sorting/level changes)
local updateRelatedAddonData = function(tagsOnly, skipTags)
    ---@cast Addon Addon_GroupBulletinBoard
	-- Get localize and Dungeon-Information
	assert(Addon.dungeonNames and Addon.dungeonTagsLoc and Addon.dungeonSort,
        "Verify all addon data is loaded before calling this function"
    );
    if not tagsOnly then  -- tags are done in OnEnterPressed event for the editbox
        -- Add custom categories to `dungeonNames`
        MergeTable(Addon.dungeonNames, Addon:GetCustomFilterNames());
        -- add custom categories to levels table
        MergeTable(Addon.dungeonLevel, Addon:GetAllCustomFilterLevels());
        -- add custom categories to `dungeonSort` (add internally)
        ---@diagnostic disable-next-line: redundant-parameter
        Addon.dungeonSort = Addon.GetDungeonSort(Addon:GetCustomFilterKeys());
    end
    if not skipTags then -- Add tags for custom categories into `dungeonTagsLoc`.
        Addon.SyncCustomFilterTags(Addon.dungeonTagsLoc);
        Addon.CreateTagList()
    end                     
end
local AddNewFilterToStore = function(name)
    local entries = GroupBulletinBoardDB.CustomFilters
    local getNextKey = function()
        local keys = Addon:GetCustomFilterKeys()
        for _, key in ipairs(keys) do
            if not presets[key] then
                local idx = key:match(USER_KEY_IDX_CAPTURE)
                local nextKey 
                repeat
                    idx = (tonumber(idx) or 0) + 1
                    nextKey = (USER_KEY_BASE):format(idx)
                until not GroupBulletinBoardDB.CustomFilters[nextKey]
                return nextKey
            end
        end
        return USER_KEY_BASE:format(1)
    end
    -- insert at the top of the sorted list
    for _, entry in pairs(entries) do
        entry.sortIdx = entry.sortIdx + 1
    end
    local new = {
        name = name,
        tags = {},
        levels = CopyTable(HIDDEN_LEVEL_RANGE),
        key = getNextKey(),
        sortIdx =  1,
    }
    entries[new.key] = new
end
local fixSavedFiltersSorts = function() 
    local savedFilters = GroupBulletinBoardDB.CustomFilters
    local keys = Addon.GetCustomFilterKeys()
    local sortIdx = 1
    for _, key in ipairs(keys) do
        local entry = savedFilters[key]
        entry.sortIdx = sortIdx
        sortIdx = sortIdx + 1
    end
end

---@param direction "up" | "down"
local moveSortPosition = function(key, direction)
    -- "up" means higher prio == lower index
    -- "down" means lower prio == higher index
    local savedFilters = GroupBulletinBoardDB.CustomFilters
    local entry = savedFilters[key]
    -- hack: since fixSavedFiltersSorts re-indexes sort indexes
    -- we only need to increase the sort index of this entry to be above the next
    entry.sortIdx = entry.sortIdx + (direction == "up" and -1.5 or 1.5)
    fixSavedFiltersSorts()
end

local removeFilterFromRequestList = function(key) ---@param key string
    -- Note: Users will get errors if any entries in the current RequestList use a key- 
    -- that is then removed from the dungeonSort table.
    assert(Addon.RequestList, "RequestList dne. Make sure Addon has been initialized.")
    ---@cast Addon Addon_RequestList
    local requestList = {}
    local anyRemoved = false
    for _, req in ipairs(Addon.RequestList) do
        if req.dungeon ~= key then
            tinsert(requestList, req)
        else anyRemoved = true end
    end
    if anyRemoved then
        Addon.RequestList = requestList
        Addon.ChatRequests.UpdateRequestList()
    end
end

local addPresetsToUserStore = function()
    local anyAdded = false
    for key, preset in pairs(presets) do
        local saved = GroupBulletinBoardDB.CustomFilters[key]
        if saved then -- careful with creating duplicates           
            if saved.isHidden and not preset.isDisabled then
            -- saved presets are hidden instead of deleted.
               saved.isHidden = false -- Match addon's preset state.
               -- hack: sorts to top (requires call to `fixSavedFiltersSorts`)
               saved.sortIdx = 0
               anyAdded = true
            end
        elseif not preset.isDisabled then
            GroupBulletinBoardDB.CustomFilters[key] = CopyTable(preset)
            GroupBulletinBoardDB.CustomFilters[key].sortIdx = 0
            GroupBulletinBoardDB.CustomFilters[key].isDisabled = nil
            anyAdded = true
        end
    end
    return anyAdded
end

StaticPopupDialogs["GBB_CREATE_CATEGORY"] = {
    text = ENTER_FILTER_NAME,
    button1 = CREATE,
    button2 = CANCEL,
    OnButton1 = function(self, data)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		local name = strtrim(self.editBox:GetText());
		AddNewFilterToStore(name);
        updateRelatedAddonData(nil, true) -- skips inserting tags (none yet)
        Addon.UpdateAdditionalFiltersPanel(data.panel)
    end,
    EditBoxOnTextChanged = function(self)
		if (strtrim(self:GetText()) == "" ) then
			self:GetParent().button1:Disable();
		else
			self:GetParent().button1:Enable();
		end
	end,
    EditBoxOnEnterPressed = function(self)
		local name = strtrim(self:GetText());
        if name == "" then return end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN);
		AddNewFilterToStore(name);
        updateRelatedAddonData(nil, true)
        Addon.UpdateAdditionalFiltersPanel(self:GetParent().data.panel)
		self:GetParent():Hide();
	end,
    OnShow = function(self)
        self.button1:SetEnabled(false)
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	hideOnEscape = 1,
	hasEditBox = 1,
	maxLetters = 31
}
StaticPopupDialogs["GBB_RENAME_CATEGORY"] = {
    text = ENTER_FILTER_NAME,
    button1 = PET_RENAME,
    button2 = CANCEL,
    OnButton1 = function(self, data)
        ---@cast data {settings: FilterSettingsPool, key: string, options: Frame}
        local entry = GroupBulletinBoardDB.CustomFilters[data.key]
		if not entry then return end
		local name = strtrim(self.editBox:GetText());
        if name == "" then return end
        entry.name = name
        data.settings:UpdateFilterState(data.options, entry)
        updateRelatedAddonData(nil, true) -- skips inserting tags (none changed)
    end,
    EditBoxOnTextChanged = function(self)
		if (strtrim(self:GetText()) == "" ) then
			self:GetParent().button1:Disable();
		else
			self:GetParent().button1:Enable();
		end
	end,
    EditBoxOnEnterPressed = function(self)
		local name = strtrim(self:GetText());
        if name == "" then return end
        ---@type {settings: FilterSettingsPool, key: string, options: Frame}
        local data = self:GetParent().data
        local entry = GroupBulletinBoardDB.CustomFilters[data.key]
        if not entry then return end
        entry.name = name
        data.settings:UpdateFilterState(data.options, entry)
        updateRelatedAddonData(nil, true)
        self:GetParent():Hide();
	end,
    OnShow = function(self)
        self.button1:SetEnabled(false)
        local preset = presets[self.data.key]
        if preset then
            self.editBox:SetText(preset.name)
            self.editBox:HighlightText()
            self.editBox:SetCursorPosition(0)
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	hideOnEscape = true,
	hasEditBox = 1,
	maxLetters = 31
}
StaticPopupDialogs["GBB_DELETE_CATEGORY"] = {
    text = FILTER_REMOVAL_WARNING,
    button1 = ACCEPT,
    button2 = CANCEL,
    OnButton1 = function(self, data)
        local saved = GroupBulletinBoardDB.CustomFilters[data.key]
        if not saved then return end -- nothing to delete
        if presets[data.key] then
            -- reset to base state, and disable
            saved = CopyTable(presets[data.key])
            saved.isHidden = true
            saved.isDisabled = nil
            GroupBulletinBoardDB.CustomFilters[data.key] = saved
        else
            GroupBulletinBoardDB.CustomFilters[data.key] = nil 
        end
        GroupBulletinBoardDBChar["FilterDungeon"..data.key] = nil
        fixSavedFiltersSorts()
        updateRelatedAddonData() -- full update
        removeFilterFromRequestList(data.key)
        Addon.UpdateAdditionalFiltersPanel(data.panel)
    end,
    hideOnEscape = true,
    timeout = 30,
}

---@param parent Frame
---@param direction "Up" | "Down"
local createMoveFilterButton = function(parent, direction)
    local buttonName = "$parentMoveFilter".. direction .. "Button"
    local button = CreateFrame("Button", buttonName, parent);
    button:SetSize(28, 28);
    button:SetScript("OnClick", function(self)
        self.func();
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
    end);
    button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-Scroll]].. direction .. "-Up");
    button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-Scroll]].. direction .. "-Down");
    button:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-Scroll]].. direction .. "-Disabled");
    button:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]], "ADD");
    return button;
end
local createSettingsDropdownButton = function(parent)
    local buttonName = "$parentSettingsDropdownButton"
    local button = CreateFrame("DropdownButton", buttonName, parent);
    button.menuMixin = MenuStyle2Mixin
    Mixin(button, ButtonStateBehaviorMixin)
    button:SetSize(15, 15);
    button:SetScript("OnMouseDown", button.OnMouseDown)
    button:SetScript("OnMouseUp", button.OnMouseUp)
    button:SetScript("OnEnable", button.OnEnable)
    button:SetScript("OnDisable", button.OnDisable)
    button.icon = button:CreateTexture("$parentIcon", "OVERLAY")
    button.icon:SetAtlas("OptionsIcon-Brown")
    button.icon:SetAllPoints()
    button:SetDisplacedRegions(1, -1, button.icon)
    button:SetupMenu(function(_, rootDescription)
        local categoryData = GroupBulletinBoardDB.CustomFilters[button.filterKey]
        if not categoryData then return end
        local isSelected = function() return not categoryData.includeItemLinks end
        local setSelected = function() categoryData.includeItemLinks = isSelected() end
        rootDescription:CreateCheckbox(Addon.L.IGNORE_ITEM_LINKS, isSelected, setSelected)
    end)
    return button;
end
local displayLocales = {"enUS", "deDE", "ruRU", "frFR", "zhTW", "zhCN", "esES", "ptBR"}
local isLocaleUserEnabled = function(locale)
    assert(GroupBulletinBoardDB, "GroupBulletinBoardDB not yet loaded. Call this function after initialization.", locale)
    local enabledLocales = {
        enGB = GroupBulletinBoardDB.TagsEnglish,
        enUS = GroupBulletinBoardDB.TagsEnglish,
        deDE = GroupBulletinBoardDB.TagsGerman,
        ruRU = GroupBulletinBoardDB.TagsRussian,
        frFR = GroupBulletinBoardDB.TagsFrench,
        zhTW = GroupBulletinBoardDB.TagsZhtw,
        zhCN = GroupBulletinBoardDB.TagsZhcn,
        esES = GroupBulletinBoardDB.TagsSpanish,
        esMX = GroupBulletinBoardDB.TagsSpanish,
        ptBR = GroupBulletinBoardDB.TagsPortuguese,
    }
    return enabledLocales[locale]
end
---@class FilterSettingsPool
local FilterSettingsPool = {
    entries = {},
    spacers = {},
    parent = nil, ---@type Frame?
    create = nil,
    legend = nil,
    AddFilterOptions = function(self, key, parent)
        local self = self ---@class FilterSettingsPool
        if not self.parent then self.parent = parent end
        if not self.entries[key] then
            ---@class FilterOptions : Frame, {SetFixedWidth:function, Layout:function}
            local options = CreateFrame("Frame", "$parent"..key, parent, "ResizeLayoutFrame");
            options.header = options:CreateFontString("$parentName", "OVERLAY", "GameFontNormalLarge")
            options.directions = options:CreateFontString("$parentDirections", "OVERLAY", "GameFontNormalTiny")
            ---@type Frame|{SetFixedWidth:function, Layout:function}|{[Locale]: EditBox|{label:FontString}}
            options.patterns = CreateFrame("Frame", "$parentPatterns", options, "ResizeLayoutFrame")
            options.delete = CreateFrame("Button", "$parentDelete", options, "UIPanelButtonTemplate") --[[@as UIPanelButtonTemplate]]
            options.rename = CreateFrame("Button", "$parentRename", options, "UIPanelButtonTemplate") --[[@as UIPanelButtonTemplate]]
            ---@type Frame|{up:Button|{func:function}, down:Button|{func:function}}
            options.sorts = CreateFrame("Frame", "$parentSorts", options, "ResizeLayoutFrame")
            options.sorts.up = createMoveFilterButton(options.sorts, "Up")
            options.sorts.down = createMoveFilterButton(options.sorts, "Down")
            options.sorts.up:SetPoint("TOP")
            options.sorts.down:SetPoint("TOP", options.sorts.up, "BOTTOM", 0, -4)
            ---@type CheckButton|{Text:FontString, func:function, tooltip:string?}
            options.toggle = CreateFrame("CheckButton", "$parentEnable", options, "ChatConfigCheckButtonTemplate")  
            options.toggle.Text:ClearAllPoints()
            options.toggle.Text:SetPoint("RIGHT", options.toggle, "LEFT")
            parent:HookScript("OnShow", function()
                Addon.UpdateAdditionalFiltersPanel(parent)
            end)
            ---@type DropdownButton|{icon: Texture, filterKey: string}
            options.settingsDropdown = createSettingsDropdownButton(options)
            options.settingsDropdown:SetPoint("LEFT", options.header, "RIGHT", 4, 1)
            self.entries[key] = options
        end
        return self:InitFilterOptions(self.entries[key])
    end,
    ---@param options FilterOptions
    InitFilterOptions = function(self, options)
        local padding = 4
        options.header:SetText(" ")
        options.header:SetHeight(options.header:GetStringHeight())
        options.header:SetPoint("TOP", options, "TOP", 0, -padding*2);

        options.directions:SetPoint("BOTTOMLEFT", options.patterns, "TOPLEFT", 0, 2)
        options.directions:SetTextColor(1, 0, 0, 0) -- keep shown but 0 alpha to take up space.
        options.directions:SetText(Addon.L.SAVE_ON_ENTER)
        
        options.patterns:SetPoint("CENTER", options, "CENTER")
        for _, locale in ipairs(displayLocales) do
            local editBox = options.patterns[locale] 
                or CreateFrame("EditBox", "$parent"..locale.."EditBox", options.patterns, "InputBoxTemplate");
            editBox:SetFontObject("GameFontNormal")
            editBox.label = editBox.label or editBox:CreateFontString(
                "$parentLabel", "OVERLAY", "GameFontNormalSmall"
            );
            editBox:SetHeight(16)
            editBox:SetTextColor(1,1,1,1)
            editBox:SetJustifyV("MIDDLE")
            editBox.label:SetHeight(editBox:GetHeight())
            editBox.label:SetJustifyV("MIDDLE")
            editBox:SetAutoFocus(false)
            editBox:Hide() -- hides label
            options.patterns[locale] = editBox
        end

        options.toggle:SetSize(28, 28)
        options.toggle:SetPoint("TOPRIGHT", options, "TOPRIGHT", -padding, -padding)
        options.toggle.Text:SetFormattedText("%s%s", ENABLE, CHARACTER_SPECIFIC_SYMBOL)
        options.sorts:SetPoint("TOP", options.toggle, "BOTTOM")
        
        options.rename:SetText(PET_RENAME) -- "Rename"
        options.rename:FitToText()
        options.rename:SetPoint("LEFT", options.delete, "RIGHT", 10, 0)
        
        options.delete:SetText(DELETE)
        options.delete:FitToText()
        options.delete:SetPoint("TOP", options.patterns, "BOTTOM", -(options.rename:GetWidth()+10)/2, -15)
        return options
    end,
    ---@param options FilterOptions
    ---@param dbEntry CustomFilter # reference to settings store for this category entry
    UpdateFilterState = function(self, options, dbEntry)
        local self = self ---@class FilterSettingsPool
        local EDITBOX_WIDTH = 400
        local LABEL_WIDTH = 75
        local spacing = 6
        local filterEnabled = GroupBulletinBoardDBChar["FilterDungeon"..dbEntry.key] or false
        local hColor = filterEnabled and NORMAL_FONT_COLOR or DISABLED_FONT_COLOR
       
        options.header:SetText(dbEntry.name)
        options.header:SetTextColor(hColor:GetRGBA())
        options.settingsDropdown:SetShown(filterEnabled)
        options.settingsDropdown.filterKey = dbEntry.key
        options.rename:SetScript("OnClick", function()
            StaticPopup_Show("GBB_RENAME_CATEGORY", nil, nil, {
                settings = self,
                key = dbEntry.key,
                options = options,
            })
        end)
        options.toggle:SetChecked(filterEnabled)
        options.patterns:SetFixedWidth(EDITBOX_WIDTH + LABEL_WIDTH*2)
        local nextAnchor = options.patterns 
        for _, locale in pairs(displayLocales) do -- fill out pattern editboxes with tags
            if isLocaleUserEnabled(locale) then
                local tagString = dbEntry.tags[locale]
                ---@type EditBox|{label:FontString}
                local editBox = options.patterns[locale] 
                options.directions:SetPoint("LEFT", editBox, "LEFT")
                editBox:SetText(tagString or "")
                editBox:SetWidth(EDITBOX_WIDTH)
                if filterEnabled then
                    editBox:SetTextColor(WHITE_FONT_COLOR:GetRGBA())
                    editBox:SetEnabled(true)
                else
                    editBox:SetTextColor(DISABLED_FONT_COLOR:GetRGBA())
                    editBox:SetEnabled(false)
                end
                editBox.label:SetText(locale)
                editBox.label:SetTextColor(hColor:GetRGBA())
                editBox.label:SetWidth(LABEL_WIDTH)
                if nextAnchor == options.patterns then
                    editBox.label:SetPoint("TOPLEFT", nextAnchor, "TOPLEFT", 0, -2)
                else
                    editBox.label:SetPoint("TOPLEFT", nextAnchor, "BOTTOMLEFT", 0, -spacing)
                end
                local labelSpacing = 10
                editBox:SetPoint("LEFT", editBox.label, "RIGHT", labelSpacing, 0);
                editBox:SetScript("OnEnterPressed", function()
                    dbEntry.tags[locale] = (editBox:GetText() or ""):lower()
                    updateRelatedAddonData(true) -- skips names/levels/sorts. **only** updates tags
                    editBox:ClearFocus()
                    editBox:SetText(dbEntry.tags[locale])
                end)
                editBox:SetScript("OnEditFocusGained", function()
                    options.directions:SetAlpha(0.75)
                end)
                local resetState = function()
                    options.directions:SetAlpha(0)
                    editBox:SetText(dbEntry.tags[locale] or "")
                    editBox:ClearFocus()
                end
                editBox:SetScript("OnEscapePressed", resetState)
                editBox:SetScript("OnEditFocusLost", resetState)
                Addon.OptionsBuilder.RegisterFrameWithSavedVar( -- register the toggle with the saved vars registry
                    options.toggle, GroupBulletinBoardDBChar, "FilterDungeon" .. dbEntry.key
                );
                ---@cast options {toggle: RegisteredFrameMixin|CheckButton|{func:function}}
                -- hook up the toggle button to variable updates from any source in the registry
                options.toggle:OnSavedVarUpdate(function(updatedValue)
                    options.toggle:SetChecked(updatedValue)
                end);
                --`.func` is defined as part of the ChatConfigBaseCheckButtonTemplate
                options.toggle.func = function(_, isChecked) -- called in the template's "OnClick" handler
                    options.toggle:SetSavedValue(isChecked)
                    self:UpdateFilterState(options, dbEntry)
                end
                editBox:Show()
                nextAnchor = editBox.label
            end
        end
        options.sorts.up.func = function(_self)
            moveSortPosition(dbEntry.key, "up")
            Addon.UpdateAdditionalFiltersPanel(self.parent);
        end
        options.sorts.up:SetEnabled(dbEntry.sortIdx > 1)
        options.sorts.down.func = function()
            moveSortPosition(dbEntry.key, "down");
            Addon.UpdateAdditionalFiltersPanel(self.parent);
        end
        options.delete:SetScript("OnClick", function()
            StaticPopup_Show("GBB_DELETE_CATEGORY", dbEntry.name, nil, 
                { key = dbEntry.key, panel = options:GetParent() }
            );
        end)
        options:Layout()
    end,
    ReleaseAll = function(self) -- Hides all option entries and spacers
        ---@cast self FilterSettingsPool
        for _, container in pairs(self.entries) do
            container:Hide()
            container:ClearAllPoints()
        end
        for _, spacer in pairs(self.spacers) do         
            spacer:Hide()
            spacer:ClearAllPoints()
        end
    end,
    AddSpacer = function(self, relativeTo) -- Spacers between individual filter options
        local self = self ---@class FilterSettingsPool
        local marginTop = 10
        local total = #self.spacers
        local initializeSpacer = function(spacer) ---@param spacer Texture
            spacer:SetHeight(6)
            spacer:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, -marginTop)
            spacer:SetWidth(self.parent:GetWidth())
            spacer:Show()
            return spacer
        end
        for i = 1, total do
            local spacer = self.spacers[i]
            if not spacer:IsShown() then
                return initializeSpacer(spacer)
            end
        end
        local new = self.parent:CreateTexture("$parentSpacer"..(total + 1), "BORDER")
        new:SetTexture([[Interface\Common\UI-TooltipDivider]])
        self.spacers[total + 1] = new
        return initializeSpacer(new)
    end,
    CreateButton = function(self, parent) --- Create new filter button
        local self = self ---@class FilterSettingsPool
        local createBtn = self.create 
            or CreateFrame("Button", "$parentCreateFilter", parent, "UIPanelButtonTemplate");
        ---@cast createBtn UIPanelButtonTemplate
        createBtn:SetText(CREATE or ADD)
        createBtn:FitToText()
        createBtn:SetScript("OnClick", function()
            StaticPopup_Show("GBB_CREATE_CATEGORY", nil, nil, {panel = parent})
        end)
        self.create = createBtn
        return createBtn
    end,
    PresetsButton = function(self, parent) -- Add presets button
        local self = self ---@class FilterSettingsPool
        local addPresetsBtn = self.addPresets 
            or CreateFrame("Button", "$parentRestorePresets", parent, "UIPanelButtonTemplate");   
        ---@cast addPresetsBtn UIPanelButtonTemplate
        addPresetsBtn:SetText(DEFAULTS)
        addPresetsBtn:FitToText()
        addPresetsBtn:SetScript("OnClick", function()
            local anyAdded = addPresetsToUserStore()
            if anyAdded then
                fixSavedFiltersSorts()
                updateRelatedAddonData() -- full update
                PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
                Addon.UpdateAdditionalFiltersPanel(parent)
            end
        end)
        self.addPresets = addPresetsBtn
        return addPresetsBtn
    end,
    AddLegend = function(self, parent)
        local self = self ---@class FilterSettingsPool
        local legend = self.legend or parent:CreateFontString("$parentLegend", "OVERLAY", "GameFontNormalTiny")
        -- "(*) Character Specific Settings"
        legend:SetFormattedText("\40%s\41 %s", CHARACTER_SPECIFIC_SYMBOL, CHARACTER_SPECIFIC_SETTINGS) 
        legend:Show()
        self.legend = legend
        return legend
    end
}
---@param scrollPanel SettingsCategoryPanelScrollChild|Frame Frame that the category settings will be drawn onto
function Addon.UpdateAdditionalFiltersPanel(scrollPanel)
    ---@cast Addon Addon_Options
	local userFilters = GroupBulletinBoardDB.CustomFilters
    local legend = FilterSettingsPool:AddLegend(scrollPanel)
    legend:SetPoint("RIGHT", scrollPanel, "RIGHT", -20)
    legend:SetPoint("TOP", scrollPanel, "TOP")
    -- User Categories (sorted)
    FilterSettingsPool:ReleaseAll()
    local nextAnchor = scrollPanel ---@type Texture|Frame|Region
	for idx, key in pairs(Addon:GetCustomFilterKeys()) do
        local savedData = userFilters[key]
        local filterSettings = FilterSettingsPool:AddFilterOptions(key, scrollPanel)
        FilterSettingsPool:UpdateFilterState(filterSettings, savedData)
        filterSettings:Show()
        local spacer = FilterSettingsPool:AddSpacer(filterSettings)
        if idx == 1 then
            filterSettings:SetPoint("TOPLEFT", nextAnchor, "TOPLEFT", 0, -30)
        else
            filterSettings:SetPoint("TOPLEFT", nextAnchor, "BOTTOMLEFT", 0, -10)
        end
        nextAnchor = spacer
	end

	-- New Filter 
    local createBtn = FilterSettingsPool:CreateButton(scrollPanel)
    if nextAnchor then
        createBtn:ClearAllPoints()
        createBtn:SetPoint("TOPLEFT", nextAnchor, "BOTTOMLEFT", 0, -25)
    end
    FilterSettingsPool:PresetsButton(scrollPanel):SetPoint("LEFT", createBtn, "RIGHT", 10, 0)
    scrollPanel.UpdateScrollLayout(); -- update container scroll layout incase any entries deleted/created
end
