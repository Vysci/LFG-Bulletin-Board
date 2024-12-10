
local TOCNAME,
---@class Addon_LFGTool: Addon_GroupBulletinBoard
GBB=...

local MAXGROUP=500
local LastUpdateTime = time()
local requestNil={dungeon="NIL",start=0,last=0,name=""}
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local LFGTool = {
	requestList = {},
	---@type LFGToolScrollFrame|Frame
	ScrollContainer = CreateFrame("Frame", TOCNAME.."LFGToolFrame", GroupBulletinBoardFrame),
	RefreshButton = GroupBulletinBoardFrameRefreshButton, ---@type Button
	StatusText = GroupBulletinBoardFrameStatusText, ---@type FontString
}
---@class LFGToolScrollFrame
local LFGToolScrollContainer = LFGTool.ScrollContainer

local function requestSort_TOP_TOTAL (a,b)
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
local function requestSort_TOP_nTOTAL (a,b)
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
local function requestSort_nTOP_TOTAL (a,b)
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
local function requestSort_nTOP_nTOTAL (a,b)
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
 [1] = function(a, b) return requestSort_TOP_TOTAL(a:GetData().req, b:GetData().req) end,
 [2] = function(a, b) return requestSort_TOP_nTOTAL(a:GetData().req, b:GetData().req) end,
 [3] = function(a, b) return requestSort_nTOP_TOTAL(a:GetData().req, b:GetData().req) end,
 [4] = function(a, b) return requestSort_nTOP_nTOTAL(a:GetData().req, b:GetData().req) end,
}
local getRequestNodeSortFunc = function()
	if GBB.DB.OrderNewTop and GBB.LfgRequestList ~= nil then
		if GBB.DB.ShowTotalTime then
			return requestNodeSortFuncs[1]
		else
			return requestNodeSortFuncs[2]
		end
	elseif  GBB.LfgRequestList ~= nil then
		if GBB.DB.ShowTotalTime then
			return requestNodeSortFuncs[3]
		else
			return requestNodeSortFuncs[4]
		end
	end
end

local function LFGSearch(categoryId)
    local filterVal = 0
    -- if categoryId == 2 then
    --     filterVal = 1
    -- end

	local preferredFilters
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
    C_LFGList.Search(categoryId, filterVal, preferredFilters, languages)
end
hooksecurefunc(C_LFGList, "Search", function(categoryId, filterVal, preferredFilters, languages)
	LastUpdateTime = time()
end)

---@param scrollView ScrollBoxListTreeListViewMixin
---@param requestList LFGToolRequestData[]
local updateScrollViewData = function(scrollView, requestList)
	---@type TreeDataProviderMixin
	local categoryNodes = scrollView.dataProvider
	local requestSortFunc = getRequestNodeSortFunc()
	local incomingMap = {} -- {[dungeonKey]: {[playerName]: request}}
	local shouldUpdate = false
	local numRequests = 0 -- tracks only valid/shown requests
	local userPlayerName = UnitNameUnmodified("player")
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
	if not categoryNodes.node.sortComparator then -- one time setup
		categoryNodes:SetSortComparator(function(a, b)
			return GBB.dungeonSort[a:GetData().dungeon] < GBB.dungeonSort[b:GetData().dungeon]
		end, false, true)
	end
	-- enumerate current nodes, update any existing requests, remove any that are no longer present
	for _, node in categoryNodes:Enumerate(nil, nil, false) do
		---@cast node TreeDataProviderNodeMixin
		local elementData = node:GetData()
		local key = elementData.dungeon or elementData.req.dungeon
		if elementData.isHeader then -- remove stale headers/categories for the incoming request list
			if not incomingMap[key] then
				node.parent:Remove(node, true)
				shouldUpdate = true
			end
			if node.sortComparator ~= requestSortFunc then -- one time setup for headers sort function
				node:SetSortComparator(requestSortFunc, false)
			end
		elseif elementData.isEntry then
			local incoming = incomingMap[key] and incomingMap[key][elementData.req.name] ---@type LFGToolRequestData?
			if not incoming then -- remove stale entries from data-provider too
				node.parent:Remove(node, true)
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
					node.parent:Remove(node, true)
					shouldUpdate = true
				end
			end
		end
	end
	-- insert any remaining new dungeons and request.
	for key, requestsByName in pairs(incomingMap) do
		if next(requestsByName) then
			local anyAdded = false
			local headerNode = categoryNodes:FindElementDataByPredicate(function(node)
				---@cast node TreeDataProviderNodeMixin
				local element = node.data
				return element.isHeader and element.dungeon == key
			end, false)
			if not headerNode then
				headerNode = categoryNodes:Insert({dungeon = key, isHeader = true})
				-- overwrite `InsertNode` with the same `InsetNodeSkipInvalidation` used by the tree parent node.
				headerNode.InsertNode = headerNode.parent.InsertNode
				headerNode:SetSortComparator(requestSortFunc, false, true)
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
		categoryNodes:Sort() -- must be done before invalidation
		categoryNodes:Invalidate() -- triggers UI update
	end
end

----------------------------------------------------
local categoryIdx = 0
local lfgCategories = {
	2, -- Dungeons
	114, -- Raids
	116, -- Quests & Zones
	118, -- PVP (not enabled in cata clients atm)
	120, -- "Custom"
}
function GBB.BtnRefresh(button)
	categoryIdx = math.fmod(categoryIdx, #lfgCategories) + 1
	LFGSearch(lfgCategories[categoryIdx])
end

-- hack: set the refresh button parent to the lfg frame. hides the button when the "Tool Requests" tab is not selected
LFGTool.RefreshButton:SetParent(LFGTool.ScrollContainer)

local function WhoRequest(name)
	--DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX .. string.format(GBB.L["msgStartWho"],name))
	--DEFAULT_CHAT_FRAME.editBox:SetText("/who " .. name)
	--ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox)
	GBB.Tool.RunSlashCmd("/who " .. name)
end

local function WhisperRequest(name)
	ChatFrame_OpenChat("/w " .. name .." ")
end

local function InviteRequest(name)
	GBB.Tool.RunSlashCmd("/invite " .. name)
end

local function InviteRequestWithRole(gbbName,gbbDungeon,gbbHeroic,gbbRaid)
	if not GBB.DB.InviteRole then GBB.DB.InviteRole = "DPS" end
	local gbbDungeonPrefix = ""	
	if gbbHeroic then
		gbbDungeonPrefix = "H "
	elseif not gbbHeroic and not gbbRaid then
		gbbDungeonPrefix = "N "
	end

	-- Not sure if necessary, but Heroic Miscellaneous sounds like a dangerous place.
	if gbbDungeon == "MISC" or gbbDungeon == "TRADE" or gbbDungeon == "TRAVEL" or gbbDungeon == "INCUR" then
		gbbDungeonPrefix = ""
	end

	SendChatMessage(string.format(GBB.L["JOIN_REQUEST_MESSAGE"], gbbDungeonPrefix .. GBB.dungeonNames[gbbDungeon], GBB.DB.InviteRole), "WHISPER", nil, gbbName)
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

local function createMenu(DungeonID,req)
	if not GBB.PopupDynamic:Wipe("request"..(DungeonID or "nil")..(req and "request" or "nil")) then
		return
	end
	if req then
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnWho"],req.name),false,WhoRequest,req.name)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnWhisper"],req.name),false,WhisperRequest,req.name)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnInvite"],req.name),false,InviteRequest,req.name)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnIgnore"],req.name),false,IgnoreRequest,req.name)
		GBB.PopupDynamic:AddItem("",true)
	end
	if DungeonID then
		GBB.PopupDynamic:AddItem(GBB.L["BtnFold"], false,GBB.LfgFoldedDungeons,DungeonID)
		GBB.PopupDynamic:AddItem(GBB.L["BtnFoldAll"], false,GBB.FoldAllDungeon)
		GBB.PopupDynamic:AddItem(GBB.L["BtnUnFoldAll"], false,GBB.UnfoldAllDungeon)
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
	GBB.PopupDynamic:AddItem(GBB.L["BtnCancel"],false)
	GBB.PopupDynamic:Show()
end

function GBB.UpdateLfgTool()
	-- named differently on cata/era
	local LFGListFrame = isCata and _G.LFGListFrame or _G.LFGListingFrame
	if isCata then
		if LFGListFrame and LFGListFrame.CategorySelection.selectedCategory == 120 then return end
		if  LFGListFrame and LFGListFrame.CategorySelection.selectedCategory == nil then
			LFGListFrame.CategorySelection.selectedCategory = 2
		end

		LastUpdateTime = time()
		GBB.LfgRequestList = {}

		local category = 2
		if LFGListFrame and LFGListFrame.CategorySelection.selectedCategory ~= nil then
			category = LFGListFrame.CategorySelection.selectedCategory
		end

		local activities = C_LFGList.GetAvailableActivities(category)
		--C_LFGList.Search(category, activities)
		if LFGListFrame and LFGListFrame.searching then return end
	end

		LFGTool:UpdateBoardListings()
		GBB.LfgRequestList = LFGTool.requestList
		GBB.LfgUpdateList()
end

function GBB.UpdateLfgToolNoSearch()
	if isCata then
		if LFGListFrame.CategorySelection.selectedCategory == 120 then return end
		if  LFGListFrame.CategorySelection.selectedCategory == nil then
			LFGListFrame.CategorySelection.selectedCategory = 2
		end
	end

	if LFGListFrame and LFGListFrame.searching then return end

	LFGTool:UpdateBoardListings()
	GBB.LfgRequestList = LFGTool.requestList
	GBB.LfgUpdateList()
end

function GBB.GetPartyInfo(searchResultId, numMembers)
    local partyInfo = {}
    for i = 1, numMembers do
        local role, class, classLocalized, specLocalized = C_LFGList.GetSearchResultMemberInfo(searchResultId, i);
        partyInfo[i] = {
            ["role"] = role,
            ["class"] = class,
            ["classLocalized"] = classLocalized,
            ["specLocalized"] = specLocalized,
        }
    end
    return partyInfo
end

local function CreateHeader(yy,dungeon)
	local AnchorTop="GroupBulletinBoardFrame_LfgChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_LfgChildFrame"
	local ItemFrameName="GBB.LfgDungeon_"..dungeon

	if GBB.LfgFramesEntries[dungeon]==nil then
		GBB.LfgFramesEntries[dungeon]=CreateFrame("Frame",ItemFrameName , GroupBulletinBoardFrame_LfgChildFrame, "GroupBulletinBoard_LfgTmpHeader")
		GBB.LfgFramesEntries[dungeon]:SetPoint("RIGHT", _G[AnchorRight], "RIGHT", 0, 0)
		_G[ItemFrameName.."_name"]:SetPoint("RIGHT",GBB.LfgFramesEntries[dungeon], "RIGHT", 0,0)
		local fname,h=_G[ItemFrameName.."_name"]:GetFont()
		_G[ItemFrameName.."_name"]:SetHeight(h)
		_G[ItemFrameName]:SetHeight(h+5)
		_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)

	end

	local colTXT
	if GBB.DB.ColorOnLevel then
		if GBB.dungeonLevel[dungeon][1] ==0 then
			colTXT="|r"
		elseif GBB.dungeonLevel[dungeon][2] < GBB.UserLevel then
			colTXT="|cFFAAAAAA"
		elseif GBB.UserLevel<GBB.dungeonLevel[dungeon][1] then
			colTXT="|cffff4040"
		else
			colTXT="|cff00ff00"
		end
	else
		colTXT="|r"
	end

	if LastDungeon~="" and not (lastIsFolded and GBB.LfgFoldedDungeons[dungeon]) then
		yy=yy+10
	end

	if GBB.LfgFoldedDungeons[dungeon]==true then
		colTXT=colTXT.."[+] "
		lastIsFolded=true
	else
		lastIsFolded=false
	end

	_G[ItemFrameName.."_name"]:SetText(colTXT..GBB.dungeonNames[dungeon].." |cFFAAAAAA"..GBB.LevelRange(dungeon).."|r")
	_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)
	GBB.LfgFramesEntries[dungeon]:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 0,-yy)
	GBB.LfgFramesEntries[dungeon]:Show()

	yy=yy+_G[ItemFrameName]:GetHeight()
	LastDungeon = dungeon
	return yy
end

local function CreateItem(yy,i,doCompact,req,forceHight)
	local AnchorTop="GroupBulletinBoardFrame_LfgChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_LfgChildFrame"
	local ItemFrameName="GBB.LfgItem_"..i

	if GBB.LfgFramesEntries[i]==nil then
		GBB.LfgFramesEntries[i]=CreateFrame("Frame",ItemFrameName , GroupBulletinBoardFrame_LfgChildFrame, "GroupBulletinBoard_LfgTmpRequest")
		GBB.LfgFramesEntries[i]:SetPoint("RIGHT", _G[AnchorRight], "RIGHT", 0, 0)

		_G[ItemFrameName.."_name"]:SetPoint("TOPLEFT")
		_G[ItemFrameName.."_time"]:SetPoint("TOP",_G[ItemFrameName.."_name"], "TOP",0,0)

		_G[ItemFrameName.."_message"]:SetNonSpaceWrap(false)
		_G[ItemFrameName.."_message"]:SetFontObject(GBB.DB.FontSize)
		_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)
		_G[ItemFrameName.."_time"]:SetFontObject(GBB.DB.FontSize)
		if GBB.DontTrunicate then
			GBB.ClearNeeded=true
		end
		GBB.Tool.EnableHyperlink(GBB.LfgFramesEntries[i])
	end

	GBB.LfgFramesEntries[i]:SetHeight(999)
	_G[ItemFrameName.."_message"]:SetHeight(999)

	if GBB.DB.DontTrunicate then
		_G[ItemFrameName.."_message"]:SetMaxLines(99)
		_G[ItemFrameName.."_message"]:SetText(" ")
	else
		_G[ItemFrameName.."_message"]:SetMaxLines(1)
		_G[ItemFrameName.."_message"]:SetText(" ")
	end


	_G[ItemFrameName.."_name"]:SetScale(doCompact)
	_G[ItemFrameName.."_time"]:SetScale(doCompact)

	if doCompact<1 then
		_G[ItemFrameName.."_message"]:SetPoint("TOPLEFT",_G[ItemFrameName.."_name"], "BOTTOMLEFT", 0,0)
		_G[ItemFrameName.."_message"]:SetPoint("RIGHT",_G[ItemFrameName.."_time"], "RIGHT", 0,0)
	else
		_G[ItemFrameName.."_message"]:SetPoint("TOPLEFT",_G[ItemFrameName.."_name"], "TOPRIGHT", 10,0)
		_G[ItemFrameName.."_message"]:SetPoint("RIGHT",_G[ItemFrameName.."_time"], "LEFT", -10,0)
	end

	if req and req.name ~= nil then
		local prefix
		if GBB.DB.ColorByClass and req.class and GBB.Tool.ClassColor[req.class].colorStr then
			prefix="|c"..GBB.Tool.ClassColor[req.class].colorStr
		else
			prefix="|r"
		end
		local ClassIcon=""
		if GBB.DB.ShowClassIcon and req.class then
			if doCompact<1  or GBB.DB.ChatStyle then
				ClassIcon = GBB.Tool.GetClassIcon(req.class) or ""

			else
				ClassIcon = GBB.Tool.GetClassIcon(req.class, 18) or ""
			end
		end


		local FriendIcon=(req.isFriend and string.format(GBB.TxtEscapePicture,GBB.FriendIcon) or "") ..
						 (req.isGuildMember and string.format(GBB.TxtEscapePicture,GBB.GuildIcon) or "") ..
						 (req.isPastPlayer and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon) or "")

		local suffix="|r"

		if GBB.RealLevel[req.name] then
			suffix=" ("..GBB.RealLevel[req.name]..")"..suffix
		end




		local ti
		if GBB.DB.ShowTotalTime then
			ti=GBB.formatTime(time()-req.start)
		else
			ti=GBB.formatTime(time()-req.last)
		end

		local typePrefix
		if req.isHeroic == true then
			local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.HeroicDungeonColor.r,GBB.DB.HeroicDungeonColor.g,GBB.DB.HeroicDungeonColor.b)
			typePrefix = "|c00".. colorHex .. "[" .. GBB.L["heroicAbr"] .. "]     "
		elseif req.isRaid == true then
			typePrefix = "|c00ffff00" .. "[" .. GBB.L["raidAbr"] .. "]     "
		else
			local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.NormalDungeonColor.r,GBB.DB.NormalDungeonColor.g,GBB.DB.NormalDungeonColor.b)
			typePrefix = "|c00".. colorHex .. "[" .. GBB.L["normalAbr"] .. "]    "
		end

        local roles = ""
        
        for _, v in pairs(req.partyInfo) do 
			if (v.classLocalized == "ROGUE" or v.classLocalized == "WARLOCK" or v.classLocalized == "MAGE") then 
				roles = roles..GBB.Tool.RoleIcon["DAMAGER"]
			elseif (v.class == "DAMAGER") then
                roles = roles..GBB.Tool.RoleIcon["DAMAGER"]
            elseif (v.class == "TANK") then
                roles = roles..GBB.Tool.RoleIcon["TANK"]
            elseif (v.class == "HEALER") then
                roles = roles..GBB.Tool.RoleIcon["HEALER"]
            end
        end

		if GBB.DB.ChatStyle then
			_G[ItemFrameName.."_name"]:SetText()
			_G[ItemFrameName.."_message"]:SetText(ClassIcon.."["..prefix ..req.name..suffix.."]"..FriendIcon..": "..req.message)
		else
			_G[ItemFrameName.."_name"]:SetText(ClassIcon..prefix .. req.name .. suffix..FriendIcon)
			_G[ItemFrameName.."_message"]:SetText(typePrefix .. suffix .. roles .. " ".. req.message)
			_G[ItemFrameName.."_time"]:SetText(ti)
		end

		_G[ItemFrameName.."_message"]:SetTextColor(GBB.DB.EntryColor.r,GBB.DB.EntryColor.g,GBB.DB.EntryColor.b,GBB.DB.EntryColor.a)
		_G[ItemFrameName.."_time"]:SetTextColor(GBB.DB.TimeColor.r,GBB.DB.TimeColor.g,GBB.DB.TimeColor.b,GBB.DB.TimeColor.a)

	else
		_G[ItemFrameName.."_name"]:SetText("Aag ")
		_G[ItemFrameName.."_message"]:SetText("Aag ")
		_G[ItemFrameName.."_time"]:SetText("Aag ")
	end


	if GBB.DB.ChatStyle then
		_G[ItemFrameName.."_time"]:Hide()
		_G[ItemFrameName.."_name"]:Hide()

		_G[ItemFrameName.."_name"]:SetWidth(1)
		_G[ItemFrameName.."_time"]:SetPoint("LEFT", _G[AnchorRight], "RIGHT", 0,0)
	else
		_G[ItemFrameName.."_time"]:Show()
		_G[ItemFrameName.."_name"]:Show()
		local w=_G[ItemFrameName.."_name"]:GetStringWidth() +10
		if w>GBB.DB.widthNames then
			GBB.DB.widthNames=w
		end
		_G[ItemFrameName.."_name"]:SetWidth(GBB.DB.widthNames)

		local w=_G[ItemFrameName.."_time"]:GetStringWidth() +10
		if w>GBB.DB.widthTimes then
			GBB.DB.widthTimes=w
		end
		_G[ItemFrameName.."_time"]:SetPoint("LEFT", _G[AnchorRight], "RIGHT", -GBB.DB.widthTimes,0)

	end
	local h
	if GBB.DB.ChatStyle then
		h=_G[ItemFrameName.."_message"]:GetStringHeight()
	else
		if doCompact<1 then
			h=_G[ItemFrameName.."_name"]:GetStringHeight() + _G[ItemFrameName.."_message"]:GetStringHeight()
		elseif GBB.DB.DontTrunicate then
			h=_G[ItemFrameName.."_message"]:GetStringHeight()
		else
			h=_G[ItemFrameName.."_name"]:GetStringHeight()
		end
	end

	if not GBB.DB.DontTrunicate and forceHight then
		h=forceHight
	end

	GBB.LfgFramesEntries[i]:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 10,-yy)
	_G[ItemFrameName.."_message"]:SetHeight(h+10)
	GBB.LfgFramesEntries[i]:SetHeight(h)

	if req then
		GBB.LfgFramesEntries[i]:Show()
	else
		GBB.LfgFramesEntries[i]:Hide()
	end

	return h

end

local ownRequestDungeons={}
function GBB.LfgUpdateList()

	GBB.Clear()

	if not GroupBulletinBoardFrame:IsVisible()  then
		return
	end

	GBB.UserLevel=UnitLevel("player")

	if GBB.DB.OrderNewTop and GBB.LfgRequestList ~= nil then
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.LfgRequestList, requestSort_TOP_TOTAL)
		else
			table.sort(GBB.LfgRequestList, requestSort_TOP_nTOTAL)
		end
	elseif  GBB.LfgRequestList ~= nil then
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.LfgRequestList, requestSort_nTOP_TOTAL)
		else
			table.sort(GBB.LfgRequestList, requestSort_nTOP_nTOTAL)
		end
	end




	for i, f in pairs(GBB.LfgFramesEntries) do
		f:Hide()
	end

	local AnchorTop="GroupBulletinBoardFrame_LfgChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_LfgChildFrame"
    local yy=0
	LastDungeon=""
	local count=0
	local doCompact=1
	local cEntrys=0

	local w=GroupBulletinBoardFrame:GetWidth() -20-10-10
	if GBB.DB.CompactStyle and not GBB.DB.ChatStyle then
		doCompact=0.85
	end

	lastIsFolded=false

	wipe(ownRequestDungeons)
	if GBB.DBChar.DontFilterOwn then

		local playername=(UnitFullName("player"))

		for i,req in pairs(GBB.LfgRequestList) do
			if type(req) == "table" and req.name==playername and req.last + GBB.DB.TimeOut*2 > time()then
				ownRequestDungeons[req.dungeon]=true
			end
		end
	end

    if not GroupBulletinBoardFrame:IsVisible() or GBB.Tool.GetSelectedTab(GroupBulletinBoardFrame)~=2 then
		return
	end

	local itemHight=CreateItem(yy,0,doCompact,nil)

	GroupBulletinBoardFrame_LfgFrame.ScrollBar.scrollStep=itemHight*2

	if #GBB.LfgFramesEntries<100 then
		for i=1,100 do
			CreateItem(yy,i,doCompact,nil)
		end
	end

	for i,req in pairs(GBB.LfgRequestList) do
		if type(req) == "table" then

			if (ownRequestDungeons[req.dungeon]==true or GBB.FilterDungeon(req.dungeon, req.isHeroic, req.isRaid)) then

				count= count + 1

				--header
				if LastDungeon ~= req.dungeon then
					local hi
					if GBB.DB.EnableShowOnly then
						hi=GBB.dungeonSort[LastDungeon] or 0
				    else
						hi=GBB.dungeonSort[req.dungeon]-1
					end
					while hi<GBB.dungeonSort[req.dungeon] do
						if LastDungeon~="" and GBB.LfgFoldedDungeons[GBB.dungeonSort[hi]]~=true and GBB.DB.EnableShowOnly then
							yy=yy+ itemHight*(GBB.DB.ShowOnlyNb-cEntrys)
						end
						hi=hi+1

						if (ownRequestDungeons[GBB.dungeonSort[hi]]==true or GBB.FilterDungeon(GBB.dungeonSort[hi], req.isHeroic, req.isRaid)) then
							yy=CreateHeader(yy,GBB.dungeonSort[hi])
							cEntrys=0
						else
							cEntrys=GBB.DB.ShowOnlyNb
						end
					end
				end

				--entry
				if GBB.LfgFoldedDungeons[req.dungeon]~=true and (not GBB.DB.EnableShowOnly or cEntrys<GBB.DB.ShowOnlyNb) then
					yy=yy+ CreateItem(yy,i,doCompact,req,itemHight)+3
					cEntrys=cEntrys+1
				end
			end
		end
	end

    if GBB.DB.EnableShowOnly then
		local hi=GBB.dungeonSort[LastDungeon] or 0
		while hi<GBB.WOTLKMAXDUNGEON do
			if LastDungeon~="" and GBB.LfgFoldedDungeons[LastDungeon]~=true and GBB.DB.EnableShowOnly then
				yy=yy+ itemHight*(GBB.DB.ShowOnlyNb-cEntrys)
			end
			hi=hi+1
			if (ownRequestDungeons[GBB.dungeonSort[hi]]==true or GBB.FilterDungeon(GBB.dungeonSort[hi], false, false)) then
				yy=CreateHeader(yy,GBB.dungeonSort[hi])
				cEntrys=0
			else
				cEntrys=GBB.DB.ShowOnlyNb
			end
		end

	end

	yy=yy+GroupBulletinBoardFrame_LfgFrame:GetHeight()-20

	GroupBulletinBoardFrame_LfgChildFrame:SetHeight(yy)
	GroupBulletinBoardFrameStatusText:SetText(string.format(GBB.L["msgLfgRequest"], SecondsToTime(time()-LastUpdateTime), count))

    
end

function GBB.ScrollLfgList(self,delta)
	self:SetScrollOffset(self:GetScrollOffset() + delta*5);
	self:ResetAllFadeTimes()
end

function GBB.LfgClickDungeon(self,button)
	local id=string.match(self:GetName(), "GBB.LfgDungeon_(.+)")
	if id==nil or id==0 then return end

	if button=="LeftButton" then
		if GBB.LfgFoldedDungeons[id] then
			GBB.LfgFoldedDungeons[id]=false
		else
			GBB.LfgFoldedDungeons[id]=true
		end
		GBB.UpdateLfgTool()
	else
		createMenu(id)
	end

end

function GBB.LfgClickRequest(self,button)
	local id = string.match(self:GetName(), "GBB.LfgItem_(.+)")
	if id==nil or id==0 then return end
	local req=GBB.LfgRequestList[tonumber(id)]
	if button=="LeftButton" then
		if IsShiftKeyDown() then
			WhoRequest(req.name)
			--SendWho( req.name )
		elseif IsAltKeyDown() then
			-- Leaving this here for a message without the automatic invite request
			-- as it obviously doesn't affect overall functionality. 
			InviteRequestWithRole(req.name,req.dungeon,req.isHeroic,req.isRaid)
		elseif IsControlKeyDown() then
			InviteRequest(req.name)
		else
            local searchResult = C_LFGList.GetSearchResultInfo(req.resultId)
            if UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) or searchResult.numMembers == 1 then
                InviteRequest(req.name)
            elseif searchResult.isDelisted == false and searchResult.numMembers ~= 5 then 
				InviteRequestWithRole(req.name,req.dungeon,req.isHeroic,req.isRaid) -- sends message telling leader your role
                RequestInviteFromUnit(searchResult.leaderName) -- requests the actual invite. 
            end
		end
	else
		createMenu(nil,req)
	end

end


function GBB.LfgRequestShowTooltip(self)
	for id in string.gmatch(self:GetName(), "GBB.LfgItem_(.+)") do
		local n=_G[self:GetName().."_message"]
		local req=GBB.LfgRequestList[tonumber(id)]
        if req == nil then return end
		GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
		if not GBB.DB.EnableGroup then
			GameTooltip:SetOwner(GroupBulletinBoardFrame, "ANCHOR_BOTTOM", 0,0	)
		else
			GameTooltip:SetOwner(GroupBulletinBoardFrame, "ANCHOR_BOTTOM", 0,-25)
		end
		GameTooltip:ClearLines()
		local tip=""
		if n:IsTruncated() then
			GameTooltip:AddLine(req.message,0.9,0.9,0.9,1)
		end

		if GBB.DB.ChatStyle then
			GameTooltip:AddLine(string.format(GBB.L["msgLastTime"],GBB.formatTime(time()-req.last)).."|n"..string.format(GBB.L["msgTotalTime"],GBB.formatTime(time()-req.start)))
		elseif GBB.DB.ShowTotalTime then
			GameTooltip:AddLine(string.format(GBB.L["msgLastTime"],GBB.formatTime(time()-req.last)))
		else
			GameTooltip:AddLine(string.format(GBB.L["msgTotalTime"],GBB.formatTime(time()-req.start)))
		end

		if GBB.DB.EnableGroup and GBB.GroupTrans and GBB.GroupTrans[req.name] then
			local entry=GBB.GroupTrans[req.name]

			GameTooltip:AddLine((GBB.Tool.GetClassIcon(entry.class) or "")..
				"|c"..GBB.Tool.ClassColor[entry.class].colorStr ..
				entry.name)
			if entry.dungeon then
				GameTooltip:AddLine(entry.dungeon)
			end
			if entry.Note then
				GameTooltip:AddLine(entry.Note)
			end
			GameTooltip:AddLine(SecondsToTime(GetServerTime()-entry.lastSeen))
		end

    -- Integration with LogTracker addon (if addon is present and loaded)
    if LogTracker then
      LogTracker:AddPlayerInfoToTooltip(req.name);
    end

		GameTooltip:Show()
	end
end

function GBB.LfgRequestHideTooltip(self)
	GameTooltip:Hide()
end

---@param name string
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
local elementExtentByData = {}
local function InitializeHeader(header, node)
	---@class HeaderButton: Button, ScrollElementAccessorsMixin
	local header = header
	-- one time inits
	if not header.created then
		header.created = true
		-- header:SetHeight(20)
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
		-- update highlight color on header hover
		header:SetScript("OnEnter", header.UpdateTextLayout)
		header:SetScript("OnLeave", header.UpdateTextLayout)
	end
	-- regular inits
	header:UpdateTextLayout()
	header:Show()
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
		local pad = 2
		hoverTex:SetPoint("TOPLEFT", -pad, pad)
		hoverTex:SetPoint("BOTTOMRIGHT", pad, -pad)
		hoverTex:SetAtlas("search-highlight")
		hoverTex:SetDesaturated(true) -- its comes blue by default
		hoverTex:SetVertexColor(0.7, 0.7, 0.7, 0.4)
		hoverTex:SetBlendMode("ADD")

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
			self.Message:SetJustifyV("MIDDLE")
			self.Message:ClearAllPoints() -- incase swapped to 2-line mode
			self.Message:SetText(" ")
			local lineHeight = self.Message:GetStringHeight() + 1 -- ui nit +1 offset

			-- hack: make sure the initial size of the FontString object is big enough
			-- to allow for all possible text when not truncating
			if GBB.DontTrunicate then self.Message:SetHeight(999) end

			--- Fill out the entry frames children with the request data
			if request then
				local formattedName = request.name
				if GBB.RealLevel[request.name] then
					formattedName = formattedName.." ("..GBB.RealLevel[request.name]..")"
				end
				if GBB.DB.ColorByClass and request.class and GBB.Tool.ClassColor[request.class].colorStr then
					formattedName = WrapTextInColorCode(formattedName, GBB.Tool.ClassColor[request.class].colorStr)
				end

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
				);

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
				if GBB.DB.ChatStyle then
					self.Name:SetText("")
					self.Message:SetFormattedText("%s\91%s\93%s: %s",
						classIcon, formattedName, playerRelationIcon, request.message
					);
					self.Message:SetIndentedWordWrap(true)
				else
					self.Name:SetFormattedText("%s%s%s", classIcon, formattedName, playerRelationIcon)
					self.Message:SetFormattedText("%s %s", typePrefix, request.message)
					self.Time:SetText(fmtTime)
					self.Message:SetIndentedWordWrap(false)
				end

				self.Message:SetTextColor(GBB.DB.EntryColor.r,GBB.DB.EntryColor.g,GBB.DB.EntryColor.b,GBB.DB.EntryColor.a)
				self.Time:SetTextColor(GBB.DB.TimeColor.r,GBB.DB.TimeColor.g,GBB.DB.TimeColor.b,GBB.DB.TimeColor.a)
			end

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
						and self.Message:GetStringHeight()
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
		entry.created = true
	end
	-- regular inits, called when frame is acquired by the scroll view
	entry:UpdateTextLayout()
end
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
		return preCalculated or 12
	end)
	self.scrollView:SetElementFactory(function(factory, node)
		local elementData = node:GetData()
		if elementData.isHeader then
			factory("Button", InitializeHeader)
		elseif elementData.isEntry then
			factory("Frame", InitializeEntryItem)
		end
	end)
	self.scrollBox = CreateFrame("Frame", nil, self, "WoWScrollBoxList")
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
	self.scrollView.dataProvider.node.InsertNode = InsertNodeSkipInvalidation
end
--------------------------------------------------------------------------------
-- Module public functions
--------------------------------------------------------------------------------
function LFGTool:UpdateRequestList()
	self.requestList = {} -- reset for now
	local _, results = C_LFGList.GetSearchResults()
	for _, resultID in ipairs(results) do
        local searchResultData = C_LFGList.GetSearchResultInfo(resultID)
		local leaderInfo = C_LFGList.GetSearchResultLeaderInfo(resultID)
        if not searchResultData.isDelisted and leaderInfo then
			local isSolo = searchResultData.numMembers == 1
			local isSelf = leaderInfo.name == UnitNameUnmodified("player")
            local listingTimestamp = time() - searchResultData.age
            local message = ""
            if searchResultData.comment ~= nil and string.len(searchResultData.comment) > 2 then
                message = searchResultData.comment
            end
			for _, activityID in pairs(searchResultData.activityIDs) do
				local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
				-- DevTool:AddData(activityInfo, resultID)
				local dungeonKey = getActivityDungeonKey(activityInfo.fullName, activityID)
				if dungeonKey == "MISC" then message = message .. " " .. activityInfo.fullName end
				local partyInfo = {};
				if not isSolo then for i = 1, searchResultData.numMembers do
					local memberInfo = C_LFGList.GetSearchResultPlayerInfo(searchResultData.searchResultID, i);
					partyInfo[i] = {
						['role'] = memberInfo.assignedRole,
						['class'] = memberInfo.classFilename,
						['classLocalized'] = memberInfo.className,
						['specLocalized'] = memberInfo.specName,
						full = memberInfo
					}
				end; end
				local _bnetFriends, charFriends, guildMembers = C_LFGList.GetSearchResultFriends(resultID)
				---@class LFGToolRequestData todo: cleanup unnecessary fields
				local entry = {
					-- fields copied from previous request gathering method
					name = searchResultData.leaderName or UNKNOWN,
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
function LFGTool:UpdateBoardListings()
	if not LFGTool.ScrollContainer:IsVisible() then return; end
	self:UpdateRequestList()
	updateScrollViewData(self.ScrollContainer.scrollView, self.requestList)
	self.StatusText:SetText(string.format(GBB.L["msgLfgRequest"], SecondsToTime(time()-LastUpdateTime), self.numRequests))
end
function LFGTool:Load()
	self.requestList = {}
	self.numRequests = 0
	self.ScrollContainer:OnLoad()
end
GBB.LfgTool = LFGTool