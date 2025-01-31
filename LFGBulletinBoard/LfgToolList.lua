
local TOCNAME,
---@class Addon_LFGTool: Addon_GroupBulletinBoard, Addon_RequestList
GBB=...

local MAXGROUP=500
local lastUpdateTime = time()
local requestNil={dungeon="NIL",start=0,last=0,name=""}
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local ROLE_ATLASES = { -- for using with Textures
	-- see Interface\AddOns\Blizzard_GroupFinder_VanillaStyle\Blizzard_LFGVanilla_Browse.lua
	TANK = "groupfinder-icon-role-large-tank",
	HEALER = "groupfinder-icon-role-large-heal",
	DAMAGER = "groupfinder-icon-role-large-dps",
	-- Solo Roles
	SOLO_TANK = "groupfinder-icon-role-micro-tank",
	SOLO_HEALER = "groupfinder-icon-role-micro-heal",
	SOLO_DAMAGER = "groupfinder-icon-role-micro-dps",
};
local INLINE_ROLE_ICONS = { -- for inlining in fontstrings/chat
	TANK = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:-1:64:64:0:19:22:41|t";
	HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:-1:64:64:20:39:1:20|t";
	DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:-1:64:64:20:39:22:41|t";
	-- (no circle)
	SOLO_TANK = "|TInterface\\LFGFrame\\LFGROLE.BLP:13:13:0:0:64:16:32:48:0:16|t";
	SOLO_HEALER = "|TInterface\\LFGFrame\\LFGROLE.BLP:13:13:0:0:64:16:48:64:0:16|t";
	SOLO_DAMAGER = "|TInterface\\LFGFrame\\LFGROLE.BLP:13:13:0:0:64:16:16:32:0:16|t";
}
--- see https://wago.tools/db2/GroupFinderCategory?build=1.15.6.58185
local LFGListCategoryEnum = {
	Dungeons = 2;
	Raids = 114;
	QuestsAndZones = 116;
	PvP = 118; -- aka "Battlegrounds"
	Custom = 120;
}

local LFGTool = {
	---@type LFGToolRequestData[]
	requestList = {},
	---@type LFGToolScrollFrame|Frame
	ScrollContainer = CreateFrame("Frame", TOCNAME.."LFGToolFrame", GroupBulletinBoardFrame),
	RefreshButton = GroupBulletinBoardFrameRefreshButton, ---@type Button
	StatusText = GroupBulletinBoardFrameStatusText, ---@type FontString
}

---@param name? string
---@param id number
local getActivityDungeonKey = function(name, id)
	local dungeonKey
	if isClassicEra then
		dungeonKey = GBB.GetDungeonKeyByID({activityID = id})
	end
	if not dungeonKey then
		-- print("Dungeon key not found for activity: " .. name .. id)
		-- DevTool:AddData(C_LFGList.GetActivityInfoTable(id), id)
		dungeonKey = "MISC"
	end
	return dungeonKey
end

---@param categoryID number
local function getFilteredActivitiesForCategory(categoryID)
	local available = C_LFGList.GetAvailableActivities(categoryID)
	local activityIDs = {}
	for _, activityID in ipairs(available) do
		local dungeonKey = getActivityDungeonKey(_, activityID)
		if dungeonKey and GBB.FilterDungeon(dungeonKey) then
			table.insert(activityIDs, activityID)
		end
	end
	if activityIDs[1] == nil then return nil
	else return activityIDs end;
end

LFGTool.CategoryButton = CreateFrame("Frame", nil, LFGTool.ScrollContainer, "Metal2DropdownWithSteppersAndLabelTemplate")
LFGTool.CategoryButton:SetPoint("LEFT", GroupBulletinBoardFrameTitle, "RIGHT", 20, 0)
LFGTool.CategoryButton:SetSize(150, 15)
LFGTool.CategoryButton.Dropdown:SetAllPoints()
LFGTool.CategoryButton.Dropdown.Text:SetFontObject("GameFontNormalSmall")
LFGTool.CategoryButton.IncrementButton:Hide()
LFGTool.CategoryButton.DecrementButton:Hide()

-- only one category can searched at a time with the LFGList tool
local selectedCategoryID = LFGListCategoryEnum.Dungeons -- default to dungeons
--- note: the C_LFGList.Search requires a #hwevent to work.
--- So this function IS ONLY to be used in OnClick/Mouse/keypress event handlers.
local function LFGList_DoCategorySearch(categoryId)
    local filterVal = 0 -- no filters
	local preferredFilters = nil
	local advancedFilters = nil
	local crossFaction = nil
    local languages = C_LFGList.GetLanguageSearchFilter() or {};
	-- include addon set languages
	languages.enUS =languages.enUS or GBB.DB.TagsEnglish
	languages.deDE =languages.deDE or GBB.DB.TagsGerman
	languages.ruRU =languages.ruRU or GBB.DB.TagsRussian
	languages.frFR =languages.frFR or GBB.DB.TagsFrench
	languages.zhTW =languages.zhTW or GBB.DB.TagsZhtw
	languages.zhCN =languages.zhCN or GBB.DB.TagsZhcn
	languages.esES =languages.esES or GBB.DB.TagsSpanish
	languages.esMX =languages.esMX or GBB.DB.TagsSpanish
	languages.ptBR =languages.ptBR or GBB.DB.TagsPortuguese
	local activityIDs = getFilteredActivitiesForCategory(categoryId)
    C_LFGList.Search(categoryId, filterVal, preferredFilters, languages, crossFaction, advancedFilters, activityIDs)
end
do -- Setup category selection dropdown buttons
	local IsSelected = function(buttonID) return buttonID == selectedCategoryID ; end
	local OnSelect = function(buttonID)
		selectedCategoryID = buttonID;
		LFGList_DoCategorySearch(buttonID)
	end
	-- hack: on reloads, the game can have previous search results still. deduce the last selectedCategoryID if so.
	local numResults, results = C_LFGList.GetSearchResults()
	if numResults > 0 then
		local activityID = C_LFGList.GetSearchResultInfo(results[1]).activityIDs[1]
		selectedCategoryID = C_LFGList.GetActivityInfoTable(activityID).categoryID
	end
	-- create dropdown buttons for each LFGlist categoryID (refresh/search on select)
	local menuGenerator = function(_, rootDescription)
		rootDescription:CreateTitle(CATEGORY)
		-- note: api can return empty list early in addon load process
		local lfgCategories = C_LFGList.GetAvailableCategories()
		for i = 1, #lfgCategories do
			local categoryID = lfgCategories[i]
			local categoryName = C_LFGList.GetLfgCategoryInfo(categoryID).name
			rootDescription:CreateRadio(categoryName, IsSelected, OnSelect, categoryID)
		end
	end
	-- (re)build menu options whenever dropdown button shown
	LFGTool.CategoryButton:HookScript('OnShow', function()
		LFGTool.CategoryButton.Dropdown:SetupMenu(menuGenerator)
	end)
end
-- LFGList searching spinner
LFGTool.RefreshSpinner = CreateFrame("Frame", nil, LFGTool.RefreshButton, "LoadingSpinnerTemplate")
LFGTool.RefreshSpinner:SetSize(25, 25)
LFGTool.RefreshSpinner:SetPoint("RIGHT", LFGTool.RefreshButton, "LEFT", -2, 0)
LFGTool.RefreshSpinner:Hide()

local onSearchStart = function(categoryID)
	LFGTool.searching = true
	selectedCategoryID = categoryID
	LFGTool.RefreshButton:Disable()
	LFGTool.RefreshSpinner:Show()
	LFGTool.CategoryButton.Dropdown:Disable()
end
local onSearchComplete = function()
	LFGTool.searching = false
    LFGTool.RefreshButton:Enable()
    LFGTool.RefreshSpinner:Hide()
	LFGTool.CategoryButton.Dropdown:Enable()
	LFGTool.CategoryButton.Dropdown:SignalUpdate()
    LFGTool:UpdateBoardListings()
	lastUpdateTime = time()
end
hooksecurefunc(C_LFGList, "Search", onSearchStart) -- keep state up to date, with external/blizz calls to LFGList.Search
GBB.Tool.RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", onSearchComplete)
GBB.Tool.RegisterEvent("LFG_LIST_SEARCH_FAILED", onSearchComplete)

local RefreshButton_OnClick = function()
	LFGList_DoCategorySearch(selectedCategoryID)
end
-- attach refresh button to the lfg frame so that its hidden when the "Tool Requests" tab is hidden.
LFGTool.RefreshButton:SetParent(LFGTool.ScrollContainer)
LFGTool.RefreshButton:SetScript("OnClick", RefreshButton_OnClick)

--------------------------------------------------------------------------------
-- local helpers
--------------------------------------------------------------------------------

local function SortRequests_NewestByTotalTime (a,b)
	if GBB.dungeonSort[a.dungeon] < GBB.dungeonSort[b.dungeon] then
		return true
	elseif GBB.dungeonSort[a.dungeon] == GBB.dungeonSort[b.dungeon]then
		if a.start>b.start then
			return true
		elseif (a.start==b.start and a.name>b.name) then
			return true
		end
	end
	return false
end
local function SortRequests_NewestByLastUpdate (a,b)
	if GBB.dungeonSort[a.dungeon] < GBB.dungeonSort[b.dungeon] then
		return true
	elseif GBB.dungeonSort[a.dungeon] == GBB.dungeonSort[b.dungeon] and (a.start ~= nil and b.start ~= nil and a.name ~= nil and b.name ~= nil) then
		if a.last>b.last then
			return true
		elseif (a.start==b.start and a.name>b.name) then
			return true
		end
	end
	return false
end
local function SortRequests_OldestByTotalTime (a,b)
	if GBB.dungeonSort[a.dungeon] < GBB.dungeonSort[b.dungeon] then
		return true
	elseif GBB.dungeonSort[a.dungeon] == GBB.dungeonSort[b.dungeon] then
		if a.start<b.start then
			return true
		elseif (a.start==b.start and a.name>b.name) then
			return true
		end
	end
	return false
end
local function SortRequests_OldestByLastUpdate (a,b)
	if GBB.dungeonSort[a.dungeon] < GBB.dungeonSort[b.dungeon] then
		return true
	elseif GBB.dungeonSort[a.dungeon] == GBB.dungeonSort[b.dungeon] then
		if a.last<b.last then
			return true
		elseif (a.start==b.start and a.name>b.name) then
			return true
		end
	end
	return false
end

local requestNodeSortFuncs = { -- expected to be used by a TreeDataProvider sortComparator
 [1] = function(a, b) return SortRequests_NewestByTotalTime(a:GetData().req, b:GetData().req) end,
 [2] = function(a, b) return SortRequests_NewestByLastUpdate(a:GetData().req, b:GetData().req) end,
 [3] = function(a, b) return SortRequests_OldestByTotalTime(a:GetData().req, b:GetData().req) end,
 [4] = function(a, b) return SortRequests_OldestByLastUpdate(a:GetData().req, b:GetData().req) end,
}
local getRequestNodeSortFunc = function()
	if GBB.DB.OrderNewTop then -- newest first
		return GBB.DB.ShowTotalTime and requestNodeSortFuncs[1] or requestNodeSortFuncs[2]
	else -- oldest first
		return GBB.DB.ShowTotalTime and requestNodeSortFuncs[3] or requestNodeSortFuncs[4]
	end
end
local CountdownTimer = {
	period = 1,
	timerCb = nil,
	register = {}
}
function CountdownTimer:RegisterFrameMethod(frame, method)
	self.register[frame] = method
	if not self.timerCb then
		self.timerCb = C_Timer.NewTicker(self.period, function()
			if next(CountdownTimer.register) then
				for frame, method in pairs(CountdownTimer.register) do
					frame[method](frame)
				end
			elseif CountdownTimer.timerCb then
				CountdownTimer.timerCb:Cancel()
				CountdownTimer.timerCb = nil
			end
		end)
	end
end;
function CountdownTimer:UnregisterFrame(frame)
	self.register[frame] = nil
end

---@param func function
---@param delay number in seconds
---@return fun(...) debouncedFunc any arguments passed through to func.
local getDebounceHandle = function(func, delay)
	local timer ---@type TimerCallback?
	return function(...)
		local invokeNow = not timer or timer:IsCancelled()
		if not invokeNow and timer then timer:Cancel() end;
		if invokeNow then
			func(...);
			timer = C_Timer.NewTimer(delay, function(self)
				self:Cancel();
			end)
		else
			local args = {...}
			timer = C_Timer.NewTimer(delay, function(self)
				if args[1] then func(unpack(args)) else func() end
				self:Cancel();
				timer = nil
			end)
		end
	end
end

local function WhoRequest(name)
	GBB.Tool.RunSlashCmd("/who " .. name)
end

local function WhisperRequest(name)
	ChatFrame_OpenChat("/w " .. name .." ")
end

local function InviteRequest(name)
	GBB.Tool.RunSlashCmd("/invite " .. name)
end

local function IgnoreRequest(name)
	for ir,req in pairs(GBB.RequestList) do
		if type(req) == "table" and req.name == name then
			req.last=0
		end
	end
	GBB.ClearNeeded=true
	C_FriendList.AddIgnore(name)
end

-- argument constants used by various methods in the TreeDataProviderNodeMixin
-- here to make the source more readable.
local DataProviderConsts = {
	SkipInvalidation = true,
	DoInvalidation = false,
	AffectChildren = true,
	ExcludeChildren = false,
	IncludeCollapsed = false,
	ExcludeCollapsed = true,
	SkipSort = true,
	DoSort = false,
}
local setAllHeadersCollapsed ---@type function
local toggleHeaderCollapseByKey ---@type function
local function createMenu(DungeonID,req) -- shared right-click menu for headers and requests
	if not GBB.PopupDynamic:Wipe("request"..(DungeonID or "nil")..(req and "request" or "nil")) then
		return
	end
	if req then
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnWho"],req.name),false,WhoRequest,req.name,nil,true)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnWhisper"],req.name),false,WhisperRequest,req.name,nil,true)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnInvite"],req.name),false,InviteRequest,req.name,nil,true)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnIgnore"],req.name),false,IgnoreRequest,req.name,nil,true)
		GBB.PopupDynamic:AddItem("",true)
	end
	if DungeonID then
		GBB.PopupDynamic:AddItem(GBB.L["BtnFold"], false, toggleHeaderCollapseByKey, DungeonID, nil, true)
		GBB.PopupDynamic:AddItem(GBB.L["BtnFoldAll"], false, setAllHeadersCollapsed, true, nil, true)
		GBB.PopupDynamic:AddItem(GBB.L["BtnUnFoldAll"], false, setAllHeadersCollapsed, false, nil, true)
		GBB.PopupDynamic:AddItem("",true)
	end
	GBB.PopupDynamic:AddItem(GBB.L["CboxShowTotalTime"],false,GBB.DB,"ShowTotalTime")
	GBB.PopupDynamic:AddItem(GBB.L["CboxOrderNewTop"],false,GBB.DB,"OrderNewTop")
	GBB.PopupDynamic:AddItem(GBB.L["CboxEnableShowOnly"],false,GBB.DB,"EnableShowOnly")
	GBB.PopupDynamic:AddItem(GBB.L["CboxChatStyle"],false,GBB.DB,"ChatStyle")
	GBB.PopupDynamic:AddItem(GBB.L["CboxCompactStyle"],false,GBB.DB,"CompactStyle")
	GBB.PopupDynamic:AddItem(GBB.L["CboxDontTrunicate"],false,GBB.DB,"DontTrunicate")
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(GBB.L["CboxNotifySound"],false,GBB.DB,"NotifySound")
	GBB.PopupDynamic:AddItem(GBB.L["CboxNotifyChat"],false,GBB.DB,"NotifyChat")
	GBB.PopupDynamic:AddItem(GBB.L["CboxRemoveRealm"],false,GBB.DB,"RemoveRealm")
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(SETTINGS, false, GBB.OptionsBuilder.OpenCategoryPanel, 1)
	GBB.PopupDynamic:AddItem(GBB.L["BtnCancel"], false, nil, nil, nil, true)
	GBB.PopupDynamic:Show()
end
--------------------------------------------------------------------------------
-- Dungeon/Category Header frame setup
--------------------------------------------------------------------------------

---@param self Button|TreeDataProviderNodeMixin
---@param clickType mouseButton
---@param isMouseDown boolean
local dungeonHeaderClickHandler = function(self, clickType, isMouseDown)
	if clickType == "LeftButton" then
		if IsShiftKeyDown() then
			local shouldCollapse = not self:IsCollapsed()
			setAllHeadersCollapsed(shouldCollapse)
		else
			self:ToggleCollapsed(DataProviderConsts.ExcludeChildren, DataProviderConsts.DoInvalidation)
		end
	elseif clickType == "RightButton" then
		createMenu(self:GetData().dungeon)
	end
end
setAllHeadersCollapsed = function(shouldCollapse)
	local scrollView = LFGTool.ScrollContainer.scrollView
	scrollView.dataProvider.node:SetChildrenCollapsed(shouldCollapse,
		DataProviderConsts.ExcludeChildren, DataProviderConsts.SkipInvalidation
	);
	scrollView:ForEachFrame(function(frame, node)
		if node.data.isHeader then ---@cast frame HeaderButton
			frame:UpdateTextLayout()
		end
	end)
	-- hack: force set all seen header keys to account for those not in the dataProvider
	for key, _ in pairs(GBB.FoldedDungeons) do GBB.FoldedDungeons[key] = shouldCollapse end
	scrollView.dataProvider:Invalidate()
end
toggleHeaderCollapseByKey = function(key)
	LFGTool.ScrollContainer.scrollView:ForEachFrame(function(frame, node)
		if node.data.isHeader and node.data.dungeon == key then
			frame:ToggleCollapsed(DataProviderConsts.ExcludeChildren, DataProviderConsts.DoInvalidation);
		end
	end)
end
local elementExtentByData = {}
local function InitializeHeader(header, node)
	---@class HeaderButton: Button, ScrollElementAccessorsMixin
	local header = header
	-- one time inits
	if not header.created then
		header.created = true
		header:RegisterForClicks("AnyDown")
		header.Name = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		header.Name:SetAllPoints()
		header.Name:SetFontObject(GBB.DB.FontSize)
		header.Name:SetJustifyH("LEFT")
		header.Name:SetJustifyV("MIDDLE")
		function header:UpdateTextLayout()
			local node = self:GetElementData()
			local dungeon = node.data.dungeon
			local categoryName = GBB.dungeonNames[dungeon]
			if self:IsCollapsed() then categoryName = "[+] "..categoryName end
			local levelRange = GRAY_FONT_COLOR:WrapTextInColorCode(GBB.LevelRange(dungeon))
			local categoryColor = NORMAL_FONT_COLOR
			if self:IsMouseOver() then categoryColor = HIGHLIGHT_FONT_COLOR
			elseif GBB.DB.ColorOnLevel then
				if GBB.dungeonLevel[dungeon][1] == 0 then
					-- skip
				elseif GBB.dungeonLevel[dungeon][2] < GBB.UserLevel then
					categoryColor = TRIVIAL_DIFFICULTY_COLOR
				elseif GBB.UserLevel<GBB.dungeonLevel[dungeon][1] then
					categoryColor = IMPOSSIBLE_DIFFICULTY_COLOR
				else
					categoryColor = EASY_DIFFICULTY_COLOR
				end
			end
			categoryName = categoryColor:WrapTextInColorCode(categoryName)
			self.Name:SetFontObject(GBB.DB.FontSize)
			self.Name:SetText(("%s %s"):format(categoryName, levelRange))
			local _, fontHeight = self.Name:GetFontObject():GetFont()
			self:SetHeight(fontHeight + 4)
			elementExtentByData[node.data] = self:GetHeight()
		end
		function header:ToggleCollapsed(...)
			header:GetElementData():ToggleCollapsed(...)
			header:UpdateTextLayout()
		end
		-- update highlight color on header hover
		header:SetScript("OnEnter", header.UpdateTextLayout)
		header:SetScript("OnLeave", header.UpdateTextLayout)
		header:HookScript("OnClick", dungeonHeaderClickHandler)
	end
	-- regular inits
	header:UpdateTextLayout()
	header:Show()
end

--------------------------------------------------------------------------------
-- Request Entry frame setup
--------------------------------------------------------------------------------

local buildPartyInfoTooltipFrame; ---@type fun(request: LFGToolRequestData): Frame, number
local clearPartyInfoTooltipFrame; ---@type fun(): nil
do
	local gridContainer = CreateFrame("Frame", nil, GroupBulletinBoardFrame, "ResizeLayoutFrame")
	local initMemberInfoFrame = function(frame)
		---@class LFGTool_TooltipMemberInfo: Frame
		local frame = frame
		frame.LeaderIcon = frame:CreateTexture(nil, "ARTWORK")
		frame.LeaderIcon:SetSize(12, 12)
		frame.LeaderIcon:SetPoint("LEFT")
		frame.Name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		frame.Name:SetPoint("LEFT", frame.LeaderIcon, "RIGHT", 2, 0)
		frame.Name:SetText(" ")
		frame.Name:SetWidth(70)
		frame.Name:SetMaxLines(1)
		frame.Name:SetJustifyH("LEFT")
		frame.Name:SetJustifyV("MIDDLE")
		frame.Level = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		frame.Level:SetPoint("LEFT", frame.Name, "RIGHT", 2, 0)
		frame.Level:SetJustifyH("CENTER")
		frame.Level:SetJustifyV("MIDDLE")
		frame.Level:SetWidth(26)
		frame.RoleIcon = frame:CreateTexture(nil, "ARTWORK")
		frame.RoleIcon:SetSize(13, 13)
		frame.RoleIcon:SetPoint("LEFT", frame.Level, "RIGHT", 2, 0)
		frame:SetSize(124, 14)
	end
	local memberFramePool = CreateFramePool("Frame", gridContainer, nil, nil, nil, initMemberInfoFrame)
	---@param request LFGToolRequestData
	buildPartyInfoTooltipFrame = function(request)
		local numMembers = 0
		for memberIdx, member in ipairs(request.partyInfo) do
			-- edge case: re-query for player names if missing
			if (not member.name) or member.name == UNKNOWN
			or not (member.level and member.assignedRole )then
				local info = C_LFGList.GetSearchResultPlayerInfo(request.resultId, memberIdx)
				if info then -- resultID can be stale. check if it exists
					info.name = info.name or UNKNOWN
					request.partyInfo[memberIdx] = info
					member = info
				end
			end;
			if member.name and member.level and member.assignedRole then
				---@type LFGTool_TooltipMemberInfo
				local frame = memberFramePool:Acquire()
				frame:Show()
				frame.LeaderIcon:SetTexture(member.isLeader and "Interface/GroupFrame/UI-Group-LeaderIcon" or "")
				local colorText = function(text)
					return GBB.Tool.ClassColor[member.classFilename]:WrapTextInColorCode(text)
				end
				frame.Name:SetText(colorText(member.name))
				frame.Level:SetText(colorText(("(%i)"):format(member.level)))
				frame.RoleIcon:SetAtlas(ROLE_ATLASES[member.assignedRole or "DAMAGER"])
				frame:SetID(memberIdx)
				frame.data = member
				numMembers = numMembers + 1
			end
		end
		local entriesPerCol = 5
		if numMembers > 19 then
			entriesPerCol = 10
		end
		local layout = GridLayoutUtil.CreateStandardGridLayout(entriesPerCol, 1.5, 0, -1, 1, true)
		local frames = {}
		for f, _ in memberFramePool:EnumerateActive() do table.insert(frames, f) end
		--> leader -> (tank -> healer -> dps) -> class (reverse) -> level -> name
		local rolePrio = { TANK = 1, HEALER = 2, DAMAGER = 3 }
		local sortMemberFrames = function(a, b)
			if a.data.isLeader then return true;
			elseif b.data.isLeader then return false end;
			if a.data.assignedRole ~= b.data.assignedRole then
				return rolePrio[a.data.assignedRole] < rolePrio[b.data.assignedRole]
			end;
			if a.data.classFilename ~= b.data.classFilename then
				-- sort reverse alphabetical to get warriors first
				return a.data.classFilename > b.data.classFilename
			end;
			if a.data.level ~= b.data.level then return a.data.level > b.data.level end;
			if a.data.name ~= b.data.name then
				return a.data.name < b.data.name
			end
			return a:GetID() < b:GetID()
		end
		sort(frames, sortMemberFrames)
		GridLayoutUtil.ApplyGridLayout(frames, CreateAnchor("TOPLEFT", gridContainer, "TOPLEFT"), layout)
		gridContainer:Layout()
		gridContainer:Show()
		return gridContainer, numMembers;
	end
	clearPartyInfoTooltipFrame = function()
		memberFramePool:ReleaseAll()
		gridContainer:Hide()
	end
end
---@param self Frame|TreeDataProviderNodeMixin
---@param clickType mouseButton
local requestEntryClickHandler = function(self, clickType)
	local req = self:GetData().req ---@type LFGToolRequestData
	if clickType == "LeftButton" then
		if IsShiftKeyDown() then
			WhoRequest(req.name)
		elseif IsAltKeyDown() then
			GBB.SendJoinRequestMessage(req.name, req.dungeon, req.isHeroic)
		elseif IsControlKeyDown() then
			InviteToGroup(req.name)
		else
            local searchResult = C_LFGList.GetSearchResultInfo(req.resultId) -- get latest info from server
			if searchResult then -- can be `nil` if an entry with a "stale" resultID is click mid C_LFGList.Search
				req.isDelisted = searchResult.isDelisted
				req.numMembers = searchResult.numMembers
			end
            if req.isDelisted == false
			and req.numMembers < (req.maxMembers or 5) -- party is not full
			and C_PartyInfo.RequestInviteFromUnit -- check if api exists (doesnt in classic era)
			then
                C_PartyInfo.RequestInviteFromUnit(req.leaderInfo.name)
            else -- atm for classic just start a whisper
				ChatFrame_SendTell(req.leaderInfo.name)
			end
		end
	else -- on right click
		createMenu(nil, req)
	end
end
---@param entry RequestEntryFrame|ScrollElementAccessorsMixin
---@param isMouseOver boolean
local function onEntryMouseover(entry, isMouseOver)
	if isMouseOver then
		GameTooltip:SetOwner(GroupBulletinBoardFrame, 'ANCHOR_BOTTOM', 0, -25)
		GameTooltip:ClearLines()
		local request = entry:GetData().req ---@type LFGToolRequestData
		GameTooltip:AddLine(request.message, 0.9, 0.9, 0.9, 1)
		if GBB.DB.ShowTotalTime then
			GameTooltip:AddLine(string.format(GBB.L['msgLastTime'], GBB.formatTime(time() - request.last)))
		else
			GameTooltip:AddLine(string.format(GBB.L['msgTotalTime'], GBB.formatTime(time() - request.start)))
		end
		if request.isGroupLeader then
			local frame, numMembers = buildPartyInfoTooltipFrame(request)
			local counts = request.memberRoleCounts;
			GameTooltip:AddLine(LFG_LIST_TOOLTIP_MEMBERS:format(
				numMembers, counts.TANK, counts.HEALER, counts.DAMAGER)
			);
			GameTooltip_InsertFrame(GameTooltip, frame)
		end
		if GBB.DB.EnableGroup and GBB.GroupTrans and GBB.GroupTrans[request.name] then
			local history=GBB.GroupTrans[request.name]
			GameTooltip:AddLine((GBB.Tool.GetClassIcon(history.class) or "")..
				"|c"..GBB.Tool.ClassColor[history.class].colorStr ..
				history.name)
			if history.dungeon then
				GameTooltip:AddLine(history.dungeon)
			end
			if history.Note then
				GameTooltip:AddLine(history.Note)
			end
			GameTooltip:AddLine(SecondsToTime(GetServerTime()-history.lastSeen))
		end
		GameTooltip:Show()
	else
		GameTooltip:Hide()
		clearPartyInfoTooltipFrame()
	end
end
local function InitializeEntryItem(entry, node)
	---@class RequestEntryFrame: Frame, ScrollElementAccessorsMixin
	local entry = entry
	-- space between inner-bottom of entry and outer-bottom of message
	local bottomPadding = 4;
	if not entry.created then -- one time inits
		entry.Name = entry:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		entry.Message = entry:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		entry.Time = entry:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		entry.Time:SetPoint("TOP", entry.Name, "TOP", 0, 0)
		entry:SetMouseMotionEnabled(true)
		entry.Name:SetJustifyH("LEFT")
		entry.Name:SetJustifyV("TOP")
		entry.Message:SetJustifyH("LEFT")
		entry.Message:SetNonSpaceWrap(false)
		if GBB.DontTrunicate then GBB.ClearNeeded=true end
		-- add highlight hover tex. Draw on "HIGHTLIGHT" layer to use base xml highlighting script
		local hoverTex = entry:CreateTexture(nil, "HIGHLIGHT")
		-- padding used compensate text clipping out of its containing frame
		local pad = 1.5
		hoverTex:SetPoint("TOPLEFT", -pad, pad)
		hoverTex:SetPoint("BOTTOMRIGHT", pad, -pad)
		hoverTex:SetAtlas("search-highlight")
		hoverTex:SetDesaturated(true) -- its comes blue by default
		hoverTex:SetVertexColor(0.7, 0.7, 0.7, 0.4)
		hoverTex:SetBlendMode("ADD")
		entry:HookScript("OnMouseDown", requestEntryClickHandler)
		entry:HookScript("OnEnter", function(self) onEntryMouseover(self, true) end)
		entry:HookScript("OnLeave", function(self) onEntryMouseover(self, false) end)

		--- responsible for making sure everything is in its right place
		function entry:UpdateTextLayout()
			local node = self:GetElementData();
			local request = node.data.req ---@type LFGToolRequestData
			local scale = (GBB.DB.CompactStyle and not GBB.DB.ChatStyle) and 0.85 or 1

			-- request player name
			self.Name:SetFontObject(GBB.DB.FontSize)
			self.Name:SetPoint("TOPLEFT", 0,-1.5)
			self.Name:Show() -- incase hidden from being in chat style

			-- time since request was made
			self.Time:SetFontObject(GBB.DB.FontSize)
			self.Time:Show()

			-- request message
			self.Message:SetFontObject(GBB.DB.FontSize)
			self.Message:SetMaxLines(GBB.DB.DontTrunicate and 99 or 1)
			self.Message:SetWordWrap(GBB.DB.DontTrunicate and true or false)
			self.Message:SetJustifyV("MIDDLE")
			self.Message:ClearAllPoints() -- incase swapped to 2-line mode
			-- dummy text to calculate normalized line height (icons are the biggest characters in any message)
			self.Message:SetText(INLINE_ROLE_ICONS.DAMAGER)
			local lineHeight = self.Message:GetStringHeight()

			-- hack: make sure the initial size of the FontString object is big enough
			-- to allow for all possible text when not truncating
			if GBB.DontTrunicate then self.Message:SetHeight(999) end

			--- Fill out the entry frames children with the request data
			local formattedName = request.name
			local playerLevel = GBB.RealLevel[request.name] or request.leaderInfo.level
				if playerLevel then
				formattedName = string.format("%s (%s)", formattedName, playerLevel)
			end
			if GBB.DB.ColorByClass and request.class and GBB.Tool.ClassColor[request.class].colorStr then
				formattedName = WrapTextInColorCode(formattedName, GBB.Tool.ClassColor[request.class].colorStr)
			end

			-- Note: in the future there should be dedicated texture frames for all the following icons (and roles)
			-- that way we dont have to deal with all the annoying parsing of strings to display them in the rendered text.
			local classIcon = (GBB.DB.ShowClassIcon and request.class)
				and GBB.Tool.GetClassIcon(request.class, GBB.DB.ChatStyle and 12 or 18)
				or ""

			local playerRelationIcon = (
				(request.isFriend
				and string.format(GBB.TxtEscapePicture,GBB.FriendIcon)
				or "")
				..(request.isGuildMember
				and string.format(GBB.TxtEscapePicture,GBB.GuildIcon)
				or "")
				..(request.isPastPlayer
				and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon)
				or "")
				..(request.isGroupLeader
				and string.format(GBB.TxtEscapePicture, "Interface/GroupFrame/UI-Group-LeaderIcon")
				or "")
			);
			local roles = ""
			if not request.isGroupLeader then
				-- show players roles
				if request.roles.tank then
					roles = INLINE_ROLE_ICONS.SOLO_TANK
				end
				if request.roles.healer then
					roles = roles..INLINE_ROLE_ICONS.SOLO_HEALER
				end
				if request.roles.dps then
					roles = roles..INLINE_ROLE_ICONS.SOLO_DAMAGER
				end
			else
				-- show role/count of group
				local damageCount = request.memberRoleCounts.DAMAGER
				local tankCount = request.memberRoleCounts.TANK
				local healerCount = request.memberRoleCounts.HEALER
				roles = string.format("%s%d  %s%d  %s%d",
					INLINE_ROLE_ICONS.TANK, tankCount,
					INLINE_ROLE_ICONS.HEALER, healerCount,
					INLINE_ROLE_ICONS.DAMAGER, damageCount
				)
			end
			local now = time()
			local fmtTime
			if GBB.DB.ShowTotalTime then
				if (now - request.start < 0) then -- Quick fix for negative timers that happen as a result of new time calculation.
					fmtTime=GBB.formatTime(0)
				else
					fmtTime=GBB.formatTime(now-request.start)
				end
			else
				if (now - request.last < 0) then
					fmtTime=GBB.formatTime(0)
				else
					fmtTime=GBB.formatTime(now-request.last)
				end
			end

			local typePrefix = ""
			if not isClassicEra then -- "heroic" is not a concept in classic era/sod
				if request.isHeroic == true then
					local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.HeroicDungeonColor.r,GBB.DB.HeroicDungeonColor.g,GBB.DB.HeroicDungeonColor.b)
					-- note colorHex here has no alpha channels
					typePrefix = WrapTextInColorCode(
						("[" .. GBB.L["heroicAbr"] .. "]    "), 'FF'..colorHex
					);
				elseif request.isRaid == true then
					typePrefix = WrapTextInColorCode(
						("[" .. GBB.L["raidAbr"] .. "]    "), "FF00FF00"
					);
				else
					local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.NormalDungeonColor.r,GBB.DB.NormalDungeonColor.g,GBB.DB.NormalDungeonColor.b)
					typePrefix = WrapTextInColorCode(
						("[" .. GBB.L["normalAbr"] .. "]    "), 'FF'..colorHex
					)
				end
			end
			local displayMessage = request.message
			if roles ~= "" then
				if displayMessage == "" then
					displayMessage = roles
				else
					displayMessage = roles.." -- "..request.message
				end
			end
			if GBB.DB.ChatStyle then
				self.Name:SetText("")
				self.Message:SetFormattedText("%s\91%s\93%s: %s",
					classIcon, formattedName, playerRelationIcon, displayMessage
				);
				self.Message:SetIndentedWordWrap(true)
			else
				self.Name:SetFormattedText("%s%s %s", classIcon, formattedName, playerRelationIcon)
				self.Message:SetFormattedText("%s %s", typePrefix, displayMessage)
				self.Time:SetText(fmtTime)
				self.Message:SetIndentedWordWrap(false)
			end

			self.Message:SetTextColor(GBB.DB.EntryColor.r,GBB.DB.EntryColor.g,GBB.DB.EntryColor.b,GBB.DB.EntryColor.a)
			self.Time:SetTextColor(GBB.DB.TimeColor.r,GBB.DB.TimeColor.g,GBB.DB.TimeColor.b,GBB.DB.TimeColor.a)

			--- Adjust child frames based on chosen layout
			-- check for compact or Normal styling
			self.Name:SetScale(scale)
			self.Time:SetScale(scale)
			if scale < 1 then -- aka GBB.DB.CompactStyle
				self.Message:SetPoint("TOPLEFT",self.Name, "BOTTOMLEFT", 0, -2)
				self.Message:SetPoint("RIGHT",self.Time, "RIGHT", 0,0)
				self.Message:SetJustifyV("TOP")
			else
				self.Message:SetPoint("TOPLEFT",self.Name, "TOPRIGHT", 10)
				self.Message:SetPoint("RIGHT",self.Time, "LEFT", -10,0)
			end
			if GBB.DB.ChatStyle then
				self.Time:Hide()
				self.Name:Hide()
				self.Name:SetWidth(1)
				self.Time:ClearAllPoints() -- remove time in chat style
				self.Message:SetPoint("RIGHT", self, "RIGHT", -4)
			else -- Compact/Normal style
				-- set width & time to this sessions widest seen frames
				local padX = 10
				local w = self.Name:GetStringWidth() + padX
				GBB.DB.widthNames = math.max(GBB.DB.widthNames, w)
				self.Name:SetWidth(GBB.DB.widthNames)

				local w = self.Time:GetStringWidth() + padX
				GBB.DB.widthTimes = math.max(GBB.DB.widthTimes, w)
				self.Time:SetWidth(GBB.DB.widthTimes)
				self.Time:SetPoint("TOPRIGHT", self, "TOPRIGHT")
			end

			-- determine the height of the name/message fields
			local projectedHeight
			if GBB.DB.ChatStyle then projectedHeight = self.Message:GetStringHeight();
			else
				if scale < 1 then
					projectedHeight = self.Name:GetStringHeight() + self.Message:GetStringHeight()
				else
					projectedHeight = GBB.DB.DontTrunicate
						and math.max(lineHeight, self.Message:GetStringHeight())
						or lineHeight;
				end
			end

			-- finally set element heights and save total entry container height.
			self.Message:SetHeight(projectedHeight)
			self.Name:SetHeight(self.Name:GetStringHeight())
			self:SetHeight(projectedHeight + bottomPadding)
			self:SetShown(request ~= nil)
			elementExtentByData[node.data] = self:GetHeight()
		end
		function entry:UpdateTime()
			if not self:IsVisible() then return end;
			self.Time:SetText(GBB.formatTime(time() - self:GetData().req.last))
		end
		entry.created = true
	end
	-- regular inits, called when frame is acquired by the scroll view
	entry:UpdateTextLayout()
	CountdownTimer:RegisterFrameMethod(entry, "UpdateTime")
end

--------------------------------------------------------------------------------
-- LfgTool Tab scroll frame setup
--------------------------------------------------------------------------------

---@class LFGToolScrollFrame: Frame
local LFGToolScrollContainer = LFGTool.ScrollContainer

---@param scrollView ScrollBoxListTreeListViewMixin
---@param requestList LFGToolRequestData[]
local updateScrollViewData = function(scrollView, requestList)
	---@type TreeDataProviderMixin
	local dataProvider = scrollView.dataProvider
	local requestSortFunc = getRequestNodeSortFunc()
	local incomingMap = {} -- {[dungeonKey]: {[playerName]: request}}
	local shouldUpdate = false
	local numRequests = 0 -- tracks only valid/shown requests
	local userPlayerName = UnitNameUnmodified("player")
	local sessionCollapsedHeaders = GBB.FoldedDungeons
	local shouldShowRequest = function(request) ---@param request LFGToolRequestData
		local hasFilterEnabled = GBB.FilterDungeon(request.dungeon, request.isHeroic, request.isRaid)
		-- the `DontFilterOwn` option == "always show own requests". The var name is very confusing.
		if not hasFilterEnabled and GBB.DBChar.DontFilterOwn then
			return request.name == userPlayerName
		end
		return hasFilterEnabled
	end
	for _, req in ipairs(requestList) do
		---@cast req LFGToolRequestData
		if shouldShowRequest(req) then
			local dungeonKey = req.dungeon
			if not incomingMap[dungeonKey] then
				incomingMap[dungeonKey] = {}
			end
			numRequests = numRequests + 1
			incomingMap[dungeonKey][req.name] = req
		end
	end
	LFGTool.numRequests = numRequests
	if not dataProvider.node.sortComparator then -- one time setup
		dataProvider:SetSortComparator(function(a, b)
			return GBB.dungeonSort[a:GetData().dungeon] < GBB.dungeonSort[b:GetData().dungeon]
		end, false, true)
	end
	-- enumerate current nodes, update any existing requests, remove any that are no longer present
	for _, node in dataProvider:Enumerate(nil, nil, DataProviderConsts.IncludeCollapsed) do
		---@cast node TreeDataProviderNodeMixin
		local elementData = node:GetData()
		local key = elementData.dungeon or elementData.req.dungeon
		if elementData.isHeader then -- remove stale headers/categories for the incoming request list
			if not incomingMap[key] then
				node.parent:Remove(node, DataProviderConsts.SkipInvalidation)
				shouldUpdate = true
			end
			if node:IsCollapsed() ~= sessionCollapsedHeaders[key] then -- update collapsed state
				node:ToggleCollapsed(DataProviderConsts.ExcludeChildren, DataProviderConsts.SkipInvalidation);
				-- if the frame for this header is in view, update its text as well.
				local header = scrollView:FindFrame(node); if header then header:UpdateTextLayout() end
				shouldUpdate = true
			end
			if node.sortComparator ~= requestSortFunc then -- one time setup for headers sort function
				node:SetSortComparator(requestSortFunc, DataProviderConsts.ExcludeChildren)
			end
		elseif elementData.isEntry then
			local incoming = incomingMap[key] and incomingMap[key][elementData.req.name] ---@type LFGToolRequestData?
			if not incoming then -- remove stale entries from data-provider too
				node.parent:Remove(node, DataProviderConsts.SkipInvalidation)
				-- print("listing removed for", elementData.req.name, elementData.req.dungeon)
				shouldUpdate = true
			else
				-- if entry unchanged, remove from the todo/incoming list
				if incoming.last == elementData.req.last
				and incoming.resultId == elementData.req.resultId
				and incoming.numMembers == elementData.req.numMembers
				and incoming.message == elementData.req.message
				then
					incomingMap[key][elementData.req.name] = nil
				else -- remove request node from dataProvider (will be in next re-added step)
					node.parent:Remove(node, DataProviderConsts.SkipInvalidation)
					shouldUpdate = true
				end
			end
		end
	end
	-- insert any remaining new dungeons and request.
	for key, requestsByName in pairs(incomingMap) do
		if next(requestsByName) then
			local anyAdded = false
			local headerNode = dataProvider:FindElementDataByPredicate(function(node)
				---@cast node TreeDataProviderNodeMixin
				local element = node.data
				return element.isHeader and element.dungeon == key
			end, false)
			if not headerNode then
				headerNode = dataProvider:Insert({dungeon = key, isHeader = true})
				-- overwrite `InsertNode` with the same `InsetNodeSkipInvalidation` used by the tree parent node.
				headerNode.InsertNode = scrollView.dataProvider.node.InsertNode
				headerNode:SetSortComparator(requestSortFunc,
					DataProviderConsts.ExcludeChildren, DataProviderConsts.SkipSort
				);
				headerNode:SetCollapsed(sessionCollapsedHeaders[key],
					DataProviderConsts.ExcludeChildren, DataProviderConsts.SkipInvalidation
				);
				hooksecurefunc(headerNode, "SetCollapsed", function(self) -- updates cached collapsed state when node is toggled
					sessionCollapsedHeaders[self:GetData().dungeon] = self:IsCollapsed()
				end)
				shouldUpdate = true
			end
			for _, req in pairs(requestsByName) do
				headerNode:Insert({req = req, isEntry = true})
				shouldUpdate = true
				anyAdded = true
			end
			if anyAdded then
				headerNode:Sort()
			end
		end
	end
	-- sort and invalidate if any changes were made
	if shouldUpdate then
		dataProvider:Sort() -- must be done before invalidation
		dataProvider:Invalidate() -- triggers UI update
	end
end

-- perf: needed to skip invalidation/sorting on every insert to the dataprovider
local InsertNodeSkipInvalidation = function(self, node)
	table.insert(self.nodes, node)
	return node
end
LFGToolScrollContainer:SetSize(400, 400)
LFGToolScrollContainer:SetPoint("LEFT")
LFGToolScrollContainer:SetPoint("RIGHT")
LFGToolScrollContainer:SetPoint("TOP", 0, -30)
LFGToolScrollContainer:SetPoint("BOTTOM", 0, 45)

function LFGToolScrollContainer:OnLoad()
	---@type ScrollBoxListTreeListViewMixin
	self.scrollView = CreateScrollBoxListTreeListView(nil, 0, 80, 0, 0, 3);
	self.scrollView:SetElementExtentCalculator(function(idx, node)
		local elementData = node:GetData()
		local preCalculated = elementExtentByData[elementData]
		return preCalculated or 15
	end)
	self.scrollView:SetElementFactory(function(factory, node)
		local elementData = node:GetData()
		if elementData.isHeader then
			factory("Button", InitializeHeader)
		elseif elementData.isEntry then
			factory("Frame", InitializeEntryItem)
		end
	end)
	self.scrollView:SetElementResetter(function(frame, node)
		if node.data.isEntry then CountdownTimer:UnregisterFrame(frame) end
	end)
	self.scrollBox = CreateFrame("Frame", nil, self, "WowScrollBoxList")
	local anchorsWithScrollBar = {
		CreateAnchor("TOPLEFT", LFGToolScrollContainer, "TOPLEFT", 10, 0),
		CreateAnchor("BOTTOMRIGHT", LFGToolScrollContainer, "BOTTOMRIGHT", -24, 0),
	}
	local anchorsWithoutScrollBar = {
		anchorsWithScrollBar[1],
		CreateAnchor("BOTTOMRIGHT", LFGToolScrollContainer, "BOTTOMRIGHT", -10, 0),
	}
    self.scrollBar = CreateFrame("EventFrame", nil, self, "MinimalScrollBar");
    self.scrollBar:SetPoint("TOPLEFT", self.scrollBox, "TOPRIGHT", 8, 0);
    self.scrollBar:SetPoint("BOTTOMLEFT", self.scrollBox, "BOTTOMRIGHT", 8, 0);
    ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, self.scrollView);
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.scrollBox, self.scrollBar, anchorsWithScrollBar, anchorsWithoutScrollBar);

	self.scrollView:SetDataProvider(CreateTreeDataProvider());
	-- prevent invalidation from happening on every `Sort` call
	self.scrollView.dataProvider:UnregisterCallback(DataProviderMixin.Event.OnSort, self.scrollView);
	-- prevent invalidation from happening on every `Insert` call
	self.scrollView.dataProvider.node.InsertNode = InsertNodeSkipInvalidation
	--- hack: update the layout anytime the scrollbox is updated.
	-- fixes an issue with scroll elements initializing with incorrect extents
	self.scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, self.scrollBox.Layout, self.scrollBox)
end

-- update board when container is shown (ie tabbing into the lfg tool, or re-opening the board)
LFGToolScrollContainer:HookScript("OnShow", function()
	LFGTool.UpdateBoardListings()
	LFGTool.StatusText:UpdateText()
end)
--------------------------------------------------------------------------------
-- Module public functions
--------------------------------------------------------------------------------

function LFGTool:UpdateRequestList()
	self.requestList = {} -- reset for now
	local _, results = C_LFGList.GetSearchResults()
	for _, resultID in ipairs(results) do
        local searchResultData = C_LFGList.GetSearchResultInfo(resultID)
		local leaderInfo = C_LFGList.GetSearchResultLeaderInfo(resultID)
        if not searchResultData.isDelisted and leaderInfo and leaderInfo.name then
			local isSolo = searchResultData.numMembers == 1
			local isSelf = leaderInfo.name == UnitNameUnmodified("player")
            local listingTimestamp = time() - searchResultData.age
            local message = ""
            if searchResultData.comment ~= nil and string.len(searchResultData.comment) > 2 then
                message = searchResultData.comment
            end
			GBB.RealLevel[leaderInfo.name] = leaderInfo.level
			for _, activityID in pairs(searchResultData.activityIDs) do
				local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
				-- DevTool:AddData(activityInfo, resultID)
				local dungeonKey = getActivityDungeonKey(activityInfo.fullName, activityID)
				if dungeonKey == "MISC" then message = message .. " " .. activityInfo.fullName end
				local partyInfo = {};
				for i = 1, searchResultData.numMembers do
					partyInfo[i] = C_LFGList.GetSearchResultPlayerInfo(searchResultData.searchResultID, i);
				end;
				local _bnetFriends, charFriends, guildMembers = C_LFGList.GetSearchResultFriends(resultID)
				---@class LFGToolRequestData todo: cleanup unnecessary fields
				local entry = {
					-- fields copied from previous request gathering method
					name = leaderInfo.name,
					message = message,
					class = leaderInfo.classFilename,
					start = listingTimestamp,
					dungeon = dungeonKey,
					partyInfo = partyInfo,
					isGuildMember = not isSelf and tContains(guildMembers, searchResultData.leaderName),
					isFriend = not isSelf and tContains(charFriends, searchResultData.leaderName),
					isPastPlayer = GBB.GroupTrans[searchResultData.leaderName] ~= nil,
					isHeroic = activityInfo.isHeroicActivity,
					isRaid = false,
					last = listingTimestamp,
					isLfgTool = true,
					isDelisted = searchResultData.isDelisted,
					resultId = searchResultData.searchResultID,
					-- new fields
					leaderInfo = leaderInfo,
					listingTimestamp = listingTimestamp,
					isOwnRequest = searchResultData.hasSelf,
					isGroupLeader = not isSolo,
					numMembers = searchResultData.numMembers,
					maxMembers =  activityInfo.maxNumPlayers,
					roles = leaderInfo.lfgRoles,
					activityID = activityID,
					memberRoleCounts = C_LFGList.GetSearchResultMemberCounts(resultID),
				}
				table.insert(self.requestList, entry)
			end
		end
    end
	return self.requestList
end
---Populates `requestList` with search results and updates the bulletin board view container
LFGTool.UpdateBoardListings = getDebounceHandle(function()
	if not LFGTool.ScrollContainer:IsVisible() then return end

	if LFGTool.searching then -- use existing requests if update called mid search
		if not LFGTool.requestList[1] then return; end
	else LFGTool:UpdateRequestList() end -- otherwise, update the request list

	updateScrollViewData(LFGTool.ScrollContainer.scrollView, LFGTool.requestList)
end, 0.5 --[[bucket updates within 0.5 seconds]])

function LFGTool.OnFrameResized()
	if not LFGToolScrollContainer:IsVisible() then return end;
	-- iterate visible frames and update text layouts
	LFGToolScrollContainer.scrollView:ForEachFrame(function(frame, node)
		---@cast frame HeaderButton|RequestEntryFrame
		frame:UpdateTextLayout()
	end)
	-- Update scrollbox so that extents are set to match any new frame sizes
	local immediately = false
	LFGToolScrollContainer.scrollBox:FullUpdate(immediately)
end

function LFGTool:Load()
	self.requestList = {}
	self.numRequests = 0
	self.ScrollContainer:OnLoad()
	self:UpdateRequestList()

	-- register hooks to update the view whenever a relevant dungeon filter setting changes
	for _, filterKey in ipairs(GBB.GetSortedDungeonKeys()) do
		local setting = GBB.OptionsBuilder.GetSavedVarHandle(GBB.DBChar, "FilterDungeon"..filterKey)
		setting:AddUpdateHook(function()
			for _, request in ipairs(self.requestList) do
				if filterKey == request.dungeon then
					updateScrollViewData(self.ScrollContainer.scrollView, self.requestList)
					return;
				end
			end
		end)
	end
end
function GBB.UpdateLfgTool()
	-- named differently on cata/era
	local LFGListFrame = isCata and _G.LFGListFrame or _G.LFGBrowseFrame
	if LFGListFrame and LFGListFrame.searching then return end
	if isCata then -- todo, revise cataclysm support
		if LFGListFrame and LFGListFrame.CategorySelection.selectedCategory == 120 then return end
		if  LFGListFrame and LFGListFrame.CategorySelection.selectedCategory == nil then
			LFGListFrame.CategorySelection.selectedCategory = 2
		end

		lastUpdateTime = time()

		local category = 2
		if LFGListFrame and LFGListFrame.CategorySelection.selectedCategory ~= nil then
			category = LFGListFrame.CategorySelection.selectedCategory
		end

		local activities = C_LFGList.GetAvailableActivities(category)
	end
	LFGTool:UpdateBoardListings()
end

-- Do full update of the view on each LFG_LIST_SEARCH_RESULT_UPDATED
-- todo: this event has the searchResultID as the payload, we could use that to update only the changed entry
-- and save full reset for when the refresh button is explicitly clicked.
GBB.Tool.RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", GBB.UpdateLfgTool);

-- attach status text to the timer since full Update no longer called every second
function LFGTool.StatusText:UpdateText()
	if not LFGTool.ScrollContainer:IsVisible() then return end
	self:SetText(string.format(GBB.L['msgLfgRequest'], SecondsToTime(time() - lastUpdateTime), LFGTool.numRequests))
end
CountdownTimer:RegisterFrameMethod(LFGTool.StatusText, "UpdateText")

GBB.LfgTool = LFGTool