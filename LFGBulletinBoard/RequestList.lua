local TOCNAME,
	---@class Addon_RequestList : Addon_Tags
	---@field FramesEntries (RequestHeader|RequestEntry)[]
	GBB = ...;

--ScrollList / Request
------------------------------------------------------------------------------------- 
local lastHeaderCategory = "" -- last category/dungeon header seen when building the scroll list
local lastIsFolded
local requestNil={dungeon="NIL",start=0,last=0,name=""}
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

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
	elseif GBB.dungeonSort[a.dungeon] == GBB.dungeonSort[b.dungeon] then
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
local subDungeonParentLookup = (function() 
	local lookup = {}
	for parentDungeon, secondaryKeys in pairs(GBB.dungeonSecondTags) do
		for _, secondaryKey in ipairs(secondaryKeys) do
			lookup[secondaryKey] = parentDungeon
		end
	end
	-- set any unseen keys to false to reduce cache misses on repeated lookups
	-- (table will repeatedly be accessed by the *same* set of keys so may as well)
	setmetatable(lookup, {
		__index = function(_, dungeonKey)
			rawset(lookup, dungeonKey, false)
			return false
		end
	})
	return lookup
end)()

-- track categories/dungeon keys that have had a header created
-- this table is wiped on every `GBB.UpdateList` when the board is re-drawn
local existingHeaders= {}

-- add fontstring highlight on header hover
local highlightForFontSize = {
	GameFontNormal = "GameFontHighlight",
	GameFontNormalSmall = "GameFontHighlightSmall",
	GameFontNormalLarge = "GameFontHighlightLarge",
}
---@param header RequestHeader
local onHeaderMouseEnter = function(header)
	if GBB.DB.ColorOnLevel then
		-- save color escaped text
		header.Name.savedText = header.Name:GetText()
		local name, levels = header.Name.savedText:match("|c%x%x%x%x%x%x%x%x(.+)|r(.+)");
		if name then
			header.Name:SetText(name..(levels or ""))
		end
		header.Name:SetFontObject(highlightForFontSize[GBB.DB.FontSize or "GameFontNormal"])
	end
end
local onHeaderMouseLeave = function(header)
	if GBB.DB.ColorOnLevel then
		-- restore color escaped text
		header.Name:SetText(header.Name.savedText)
	end
	header.Name:SetFontObject(GBB.DB.FontSize or "GameFontNormal")
end
---@param scrollPos integer The current bottom pos from the top of the scroll frame
---@param dungeon string The dungeons "key" ie DM|MC|BWL|etc
---@return integer newScrollPos The updated bottom pos of the scroll frame after adding the header
local function CreateHeader(scrollPos, dungeon)
	local AnchorTop="GroupBulletinBoardFrame_ScrollChildFrame"
	local ItemFrameName="GBB.Dungeon_"..dungeon
	local header = GBB.FramesEntries[dungeon]
	local padY = 4 -- px, vspace around text
	local bottomMargin = 3 -- px, vspace beneath the header
	if not header then
		---@class RequestHeader : Frame
		header = CreateFrame(
			"Frame", ItemFrameName,
			GroupBulletinBoardFrame_ScrollChildFrame, "GroupBulletinBoard_TmpHeader"
		);
		header:SetPoint("RIGHT", GroupBulletinBoardFrame_ScrollChildFrame, "RIGHT")
		header:SetScript("OnMouseDown", GBB.ClickDungeon)
		header:SetHeight(20)
		header.Name = _G[ItemFrameName.."_name"] ---@type FontString
		header.Name:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
		header.Name:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
		header.Name:SetFontObject(GBB.DB.FontSize)
		header.Name:SetJustifyH("LEFT")
		header.Name:SetJustifyV("MIDDLE")

		header:SetScript("OnEnter", onHeaderMouseEnter)
		header:SetScript("OnLeave", onHeaderMouseLeave)

		GBB.FramesEntries[dungeon] = header
	end
	
	local categoryName = GBB.dungeonNames[dungeon]
	local levelRange = WrapTextInColorCode(GBB.LevelRange(dungeon), "FFAAAAAA")
	
	if GBB.FoldedDungeons[dungeon] then
		categoryName = "[+] "..categoryName
	end
	
	if GBB.DB.ColorOnLevel and GBB.dungeonLevel[dungeon][1]
	and GBB.dungeonLevel[dungeon][1] > 0
	then
		categoryName = GBB.Tool.GetDungeonDifficultyColor(dungeon):WrapTextInColorCode(categoryName)
	end

	header.Name:SetText(("%s %s"):format(categoryName, levelRange))
	header.Name:SetFontObject(GBB.DB.FontSize)
	local _, fontHeight = header.Name:GetFontObject():GetFont()
	header:SetHeight(fontHeight + padY)
	header:Show()
	
	header:SetPoint("TOPLEFT", GroupBulletinBoardFrame_ScrollChildFrame, "TOPLEFT", 0, -scrollPos)
	scrollPos = scrollPos + header:GetHeight()
	lastHeaderCategory = dungeon
	existingHeaders[dungeon] = true
	return scrollPos + bottomMargin
end

---@param scrollPos number current scroll position
---@param i integer request index
---@param scale number scale factor for the entry item
---@param req table? request info table
---@param forceHeight number? force the height of the entry item
---@return number height The height of the entry item
local function CreateItem(scrollPos,i,scale,req,forceHeight)
	local AnchorTop="GroupBulletinBoardFrame_ScrollChildFrame"
	local ItemFrameName="GBB.Item_"..i
	local entry = GBB.FramesEntries[i]
	-- space between inner-bottom of entry and outer-bottom of message
	local bottomPadding = 4; 
	
	if GBB.FramesEntries[i]==nil then
		---@class RequestEntry : Frame
		entry = CreateFrame("Frame", ItemFrameName,
			GroupBulletinBoardFrame_ScrollChildFrame, "GroupBulletinBoard_TmpRequest"
		);
		entry:SetPoint("RIGHT", GroupBulletinBoardFrame_ScrollChildFrame, "RIGHT", 0, 0)
		entry.Name = _G[ItemFrameName.."_name"] ---@type FontString
		entry.Message = _G[ItemFrameName.."_message"] ---@type FontString
		entry.Time = _G[ItemFrameName.."_time"] ---@type FontString
		
		entry.Name:SetPoint("TOPLEFT", 0,-1.5)
		entry.Name:SetFontObject(GBB.DB.FontSize)
		entry.Time:SetPoint("TOP", entry.Name, "TOP", 0, 0)
		entry.Time:SetFontObject(GBB.DB.FontSize)
		entry.Message:SetNonSpaceWrap(false)
		entry.Message:SetFontObject(GBB.DB.FontSize)
		
		if GBB.DontTrunicate then
			GBB.ClearNeeded=true
		end
		-- add a light hightlight on mouseover, requires we add a texture child		
		-- Draw on "HIGHTLIGHT" layer to use base xml highlighting script
		local hoverTex = entry:CreateTexture(nil, "HIGHLIGHT")
		-- padding used compensate text clipping out of its containing frame
		local pad = 2 
		hoverTex:SetPoint("TOPLEFT", -pad, pad)
		hoverTex:SetPoint("BOTTOMRIGHT", pad, -pad)
		hoverTex:SetAtlas("search-highlight")
		hoverTex:SetDesaturated(true) -- its comes blue by default
		hoverTex:SetVertexColor(0.7, 0.7, 0.7, 0.4)
		hoverTex:SetBlendMode("ADD")
		
		GBB.Tool.EnableHyperlink(entry)
		GBB.FramesEntries[i]=entry
	end

	-- Init entry children frames for request info
	-- request author/sender
	entry.Name:SetFontObject(GBB.DB.FontSize)
	entry.Name:SetPoint("TOPLEFT", 0,-1.5)
	entry.Name:Show() -- incase hidden from being in chat style

	-- time since request was made
	entry.Time:SetFontObject(GBB.DB.FontSize)
	entry.Time:Show()
	
	-- request message
	entry.Message:SetFontObject(GBB.DB.FontSize)
	entry.Message:SetMaxLines(GBB.DB.DontTrunicate and 99 or 1)
	entry.Message:SetJustifyV("MIDDLE")
	entry.Message:ClearAllPoints() -- incase swapped to 2-line mode
	entry.Message:SetText(" ") 
	local lineHeight = entry.Message:GetStringHeight() + 1 -- ui nit +1 offset
	
	if GBB.DontTrunicate then
		-- make sure the initial size of the FontString object is big enough
		-- to allow for all possible text when not truncating
		entry.Message:SetHeight(999)
	end
	
	--- Fill out the entry frames children with the request data
	if req then
		local formattedName = req.name
		if GBB.RealLevel[req.name] then
			formattedName = formattedName.." ("..GBB.RealLevel[req.name]..")"
		end
		if GBB.DB.ColorByClass and req.class and GBB.Tool.ClassColor[req.class].colorStr then
			formattedName = WrapTextInColorCode(formattedName, GBB.Tool.ClassColor[req.class].colorStr)
		end

		local ClassIcon=""
		if GBB.DB.ShowClassIcon and req.class then
			ClassIcon = GBB.Tool.GetClassIcon(req.class, GBB.DB.ChatStyle and 12 or 18) or ""
		end

		local FriendIcon = (
			(req.IsFriend 
			and string.format(GBB.TxtEscapePicture,GBB.FriendIcon) 
			or "") 
			..(req.IsGuildMember 
			and string.format(GBB.TxtEscapePicture,GBB.GuildIcon) 
			or "") 
			..(req.IsPastPlayer 
			and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon) 
			or "")
		);

		local now = time()
		local fmtTime
		if GBB.DB.ShowTotalTime then
			if (now - req.start < 0) then -- Quick fix for negative timers that happen as a result of new time calculation.
				fmtTime=GBB.formatTime(0) 
			else
				fmtTime=GBB.formatTime(now-req.start)
			end
		else
			if (now - req.last < 0) then
				fmtTime=GBB.formatTime(0)
			else
				fmtTime=GBB.formatTime(now-req.last)
			end
		end

		local typePrefix = ""
		if not isClassicEra then -- "heroic" is not a concept in classic era/sod
			if req.IsHeroic == true then
				local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.HeroicDungeonColor.r,GBB.DB.HeroicDungeonColor.g,GBB.DB.HeroicDungeonColor.b)
				-- note colorHex here has no alpha channels
				typePrefix = WrapTextInColorCode(
					("[" .. GBB.L["heroicAbr"] .. "]    "), 'FF'..colorHex
				);
			elseif req.IsRaid == true then
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
			entry.Name:SetText("")
			entry.Message:SetFormattedText("%s\91%s\93%s: %s",
				ClassIcon, formattedName, FriendIcon, req.message
			);
			entry.Message:SetIndentedWordWrap(true)
		else
			entry.Name:SetFormattedText("%s%s%s", ClassIcon, formattedName, FriendIcon)
			entry.Message:SetFormattedText("%s %s", typePrefix, req.message)
			entry.Time:SetText(fmtTime)
			entry.Message:SetIndentedWordWrap(false)
		end

		entry.Message:SetTextColor(GBB.DB.EntryColor.r,GBB.DB.EntryColor.g,GBB.DB.EntryColor.b,GBB.DB.EntryColor.a)
		entry.Time:SetTextColor(GBB.DB.TimeColor.r,GBB.DB.TimeColor.g,GBB.DB.TimeColor.b,GBB.DB.TimeColor.a)
	else
		entry.Name:SetText("Aag ")
		entry.Message:SetText("Aag ")   
		entry.Time:SetText("Aag ")
	end
	entry.requestInfo = req
	
	--- Adjust child frames based on chosen layout
	-- check for compact or Normal styling 	
	entry.Name:SetScale(scale)
	entry.Time:SetScale(scale)
	if scale < 1 then -- aka GBB.DB.CompactStyle
		entry.Message:SetPoint("TOPLEFT",entry.Name, "BOTTOMLEFT", 0, -2)
		entry.Message:SetPoint("RIGHT",entry.Time, "RIGHT", 0,0)
		entry.Message:SetJustifyV("TOP")
	else
		entry.Message:SetPoint("TOPLEFT",entry.Name, "TOPRIGHT", 10)
		entry.Message:SetPoint("RIGHT",entry.Time, "LEFT", -10,0) 
	end
	if GBB.DB.ChatStyle then
		entry.Time:Hide()
		entry.Name:Hide()
		entry.Name:SetWidth(1)
		entry.Time:ClearAllPoints() -- remove time in chat style
		entry.Message:SetPoint("RIGHT", entry, "RIGHT", -4)
	else -- Compact/Normal style
		-- set width & time to this sessions widest seen frames
		local padX = 10
		local w = entry.Name:GetStringWidth() + padX
		GBB.DB.widthNames = math.max(GBB.DB.widthNames, w)
		entry.Name:SetWidth(GBB.DB.widthNames)

		local w = entry.Time:GetStringWidth() + padX
		GBB.DB.widthTimes = math.max(GBB.DB.widthTimes, w)
		entry.Time:SetWidth(GBB.DB.widthTimes)
		entry.Time:SetPoint("TOPRIGHT", entry, "TOPRIGHT")
	end

	-- determine the height of the name/message fields
	local projectedHeight
	if GBB.DB.ChatStyle then
		projectedHeight=entry.Message:GetStringHeight()
	else
		if scale < 1 then
			projectedHeight = entry.Name:GetStringHeight() + entry.Message:GetStringHeight()
		else
			projectedHeight = GBB.DB.DontTrunicate 
				and entry.Message:GetStringHeight()
				or lineHeight;
		end
	end
	if not GBB.DB.DontTrunicate and forceHeight then
		projectedHeight=forceHeight
	end
	
	-- finally set element heights and return container height
	entry.Message:SetHeight(projectedHeight)
	entry.Name:SetHeight(entry.Name:GetStringHeight())
	entry:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 10,-scrollPos)
	entry:SetHeight(projectedHeight + bottomPadding)
	entry:SetShown(req ~= nil)

	return entry:GetHeight() -- final height
end

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

---@param leaderName string
---@param dungeonKey string
---@param isHeroic boolean?
function GBB.SendJoinRequestMessage(leaderName, dungeonKey, isHeroic)
	if not GBB.DB.EnableJoinRequestMessage then return end
	local dungeon = GBB.dungeonNames[dungeonKey] or dungeonKey
	local msg = GBB.DB.JoinRequestMessage
	local replacements = {
		-- note: the '%' in '%key' needs to be lua escaped with another '%' for the `gsub` function.
		-- (they DO NOT need to be escaped in the actual `JoinRequestMessage`strings tho).
		["%%level"] = UnitLevel("player"),
		["%%class"] = UnitClass("player"),
		["%%role"] = GBB.DB.InviteRole or "DPS",
		["%%dungeon"] = isHeroic and ("%s %s"):format(GBB.L["heroicAbr"], dungeon) or dungeon,
	}
	for key, value in pairs(replacements) do
		msg = msg:gsub(key, value)
	end
	SendChatMessage(msg, "WHISPER", nil, leaderName)
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

local function showNoFiltersMessage()
	local idx = 1
	CreateItem(0, idx, 1.25, nil, 30)
	local entry = GBB.FramesEntries[idx]
	entry.Name:SetWidth(0)
	entry.Name:SetText("")
	entry.Time:SetWidth(0)
	entry.Time:SetText("")
	entry.Message:SetText(GBB.L.NO_FILTERS_SELECTED)
	entry.Message:SetFontObject("GameFontNormalLarge")
	entry.Message:SetJustifyH("CENTER")
	entry.Message:SetMaxLines(2)
	entry.Message:SetTextColor(0.6, 0.6, 0.6, 0.6)
	-- hack: used as an override to open the filter settings, called from `ClickRequest`
	function entry.__custom_on_click()
		GBB.OptionsBuilder.OpenCategoryPanel(2) -- opens to the latest xpac filters.
		entry.__custom_on_click = nil;
	end
	entry:Show()
end

function GBB.Clear()
	if GBB.ClearNeeded or GBB.ClearTimer<time() then
		local newRequest={}
		GBB.ClearTimer=GBB.MAXTIME

		for i,req in pairs(GBB.RequestList) do
			if type(req) == "table" then
				if req.last + GBB.DB.TimeOut * 3 > time() then
					if req.last < GBB.ClearTimer then
						GBB.ClearTimer=req.last
					end
					newRequest[#newRequest+1]=req

				end
			end
		end
		GBB.RequestList=newRequest
		GBB.ClearTimer=GBB.ClearTimer+GBB.DB.TimeOut * 3
		GBB.ClearNeeded=false
	end
end

--- Used alongside the `GroupBulletinBoardFrameResultsFilter` editbox to filter requests by their message content.
--- An empty editbox assumes no filter is set and all requests should be shown.
---@param message string
---@return boolean
local function doesRequestMatchResultsFilter(message)
	assert(
		GroupBulletinBoardFrameResultsFilter and GroupBulletinBoardFrameResultsFilter.GetFilters, 
		"`GroupBulletinBoardFrameResultsFilter` frame should be defined and initialized with a call to `GBB.Init` before calling `doesRequestMatchResultsFilter`."
	)

	local filters = GroupBulletinBoardFrameResultsFilter:GetFilters()
	for _, filter in ipairs(filters) do
		if not string.find(message:lower(), filter:lower(), nil, true) then
			return false
		end
	end
	return true
end

local ownRequestDungeons={}
--- generates 100 elements(items) for display in the scroll list. These are stored in `GBB.FramesEntries` and are shown/hidden as needed depending on the data in `GBB.RequestList`.
function GBB.UpdateList()

	GBB.Clear()

	if not GroupBulletinBoardFrame:IsVisible()  then
		return
	end

	GBB.UserLevel=UnitLevel("player")

	if GBB.DB.OrderNewTop then
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.RequestList, requestSort_TOP_TOTAL)
		else
			table.sort(GBB.RequestList, requestSort_TOP_nTOTAL)
		end
	else
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.RequestList, requestSort_nTOP_TOTAL)
		else
			table.sort(GBB.RequestList, requestSort_nTOP_nTOTAL)
		end
	end

	-- Hide all exisiting scroll frame elements
	for _, f in pairs(GBB.FramesEntries) do
		f:Hide()
	end

	local AnchorTop="GroupBulletinBoardFrame_ScrollChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_ScrollChildFrame"
    local scrollHeight = 0
	local count = 0
	local itemScale = 1
	local itemsInCategory = 0
	local MAX_NUM_ITEMS = 100
	local allItemsInitialized = not (#GBB.FramesEntries < MAX_NUM_ITEMS)
	lastHeaderCategory= "" -- still used for managing padding between folded categorties in `CreateHeader`
	local lastCategory

	local itemWidth = GroupBulletinBoardFrame:GetWidth() -20-10-10
	if GBB.DB.CompactStyle and not GBB.DB.ChatStyle then
		itemScale=0.85
	end

	lastIsFolded=false
	wipe(ownRequestDungeons)
	-- reset the list of existing headers to draw new ones
	existingHeaders = {} 

	if GBB.DBChar.DontFilterOwn then
		for i,req in pairs(GBB.RequestList) do
			if type(req) == "table" and req.guid == UnitGUID("player") and req.last + GBB.DB.TimeOut*2 > time()then
				ownRequestDungeons[req.dungeon]=true
			end
		end
	end

	local baseItemHeight = CreateItem(scrollHeight, 0, itemScale, nil)
	
	-- set scroll height slightly bigger than 1 element to account for category headers being taller
	GroupBulletinBoardFrame_ScrollFrame.ScrollBar.scrollStep = baseItemHeight * 1.25 

	if not allItemsInitialized then
		for i = 1, MAX_NUM_ITEMS do
			CreateItem(scrollHeight,i,itemScale,nil)
		end
	end
	-- iterate request and generate headers and items for display
	for requestIdx, req in pairs(GBB.RequestList) do
		if type(req) == "table" then

			if (req.last + GBB.DB.TimeOut > time()) -- not timed out
				and (ownRequestDungeons[req.dungeon] == true  -- own request
					-- dungeons set to show in options 
					or GBB.FilterDungeon(req.dungeon, req.IsHeroic, req.IsRaid))
				and doesRequestMatchResultsFilter(req.message) -- matches global results filter
			then
				count = count + 1
				local requestDungeon = req.dungeon

				-- Since RequestList is already sorted in order of dungeons
				-- and dungeons have already been filtered/combined at this point
				-- create header (if needed)
				if not existingHeaders[requestDungeon] then
					scrollHeight = CreateHeader(scrollHeight, requestDungeon)
					itemsInCategory = 0; -- reset count on new category
				end
				
				-- add entry
				if GBB.FoldedDungeons[requestDungeon] ~= true -- not folded
					and (not GBB.DB.EnableShowOnly -- no limit
						or itemsInCategory < GBB.DB.ShowOnlyNb) -- or limit not reached
				then
					scrollHeight= scrollHeight + CreateItem(scrollHeight,requestIdx,itemScale,req) + 3 -- why add 3? 
					itemsInCategory = itemsInCategory + 1
				end
			end
		end
	end

	-- Show a help message when users have less than `n` filters selected and 0 requests are shown
	if GBB.GetNumActiveFilters() < 5 and count == 0 then showNoFiltersMessage() end

	-- adds a window's woth of padding to the bottom of the scroll frame
	scrollHeight=scrollHeight+GroupBulletinBoardFrame_ScrollFrame:GetHeight()-20

	GroupBulletinBoardFrame_ScrollChildFrame:SetHeight(scrollHeight)
	GroupBulletinBoardFrameFooterContainer.StatusText:SetText(string.format(GBB.L["msgNbRequest"], count))
	GBB.UpdateRequestListInteractiveState()
end

function GBB.GetDungeons(msg,name)
	if msg==nil then return {} end
	---Maps dungeonKey to boolean, `true` if the dungeon is asociated with message
	---@type table<string, boolean?> 
	local dungeons={}

	local isBad=false
	local isGood=false
	local isHeroic=false

	local runrequired=false
	local hasrun=false
	local runDungeon=""
	local hasTag=false
	local wordcount=0

	if GBB.DB.TagsZhcn then
		for key, v in pairs(GBB.tagList) do
			if strfind(msg:lower(), key) then
				if v==GBB.TAGSEARCH then
					isGood=true
				elseif v==GBB.TAGBAD then
					break
				elseif v~=nil then
					dungeons[v]=true
				end
			end
		end
		for key, v in pairs(GBB.HeroicKeywords) do
			if strfind(msg:lower(), key) then
				isHeroic = true
			end
		end
		wordcount = string.len(msg)
	elseif GBB.DB.TagsZhtw then
		for key, v in pairs(GBB.tagList) do
			if strfind(msg:lower(), key) then
				if v==GBB.TAGSEARCH then
					isGood=true
				elseif v==GBB.TAGBAD then
					break
				elseif v~=nil then
					dungeons[v]=true
				end
			end
		end
		for key, v in pairs(GBB.HeroicKeywords) do
			if strfind(msg:lower(), key) then
				isHeroic = true
			end
		end
		wordcount = string.len(msg)
	else
		local parts = GBB.GetMessageWordList(msg)
		for _, word in pairs(parts) do
			if word == "run" or word=="runs" then
				hasrun=true
			end

			local x = GBB.tagList[word]

			if GBB.HeroicKeywords[word] ~= nil then
				isHeroic = true
			end

			if x==nil then
				if GBB.tagList[word.."run"]~=nil then
					runDungeon=GBB.tagList[word.."run"]
					runrequired=true
				end
			elseif x==GBB.TAGBAD then
				isBad=true
				break
			elseif x==GBB.TAGSEARCH then
				hasTag=true
				isGood=true
			else
				local skip = false
				if dungeons.TRADE and x ~= "TRADE" then
					-- if a trade keyword and dungeon keyword are both present
					-- disambiguate between items and dungeons.

					-- useful for dungeons with more general search patterns
					-- like "Throne of Four Winds"

					local itemPattern =  "|hitem.*|h%[.*"..word..".*%]"
					if msg:lower():find(itemPattern) then
						-- keyword was part of a linked item not a dungeon request
						skip = true
					end
				end
				dungeons[x]= not skip
			end
		end
		wordcount = #(parts)
	end

	if runrequired and hasrun and runDungeon and isBad==false then
		dungeons[runDungeon]=true
	end

	local nameLevel= 0
	if name~=nil then
		if  GBB.RealLevel[name] then
			nameLevel= GBB.RealLevel[name]
		else
			for dungeon,id in pairs(dungeons) do
				if GBB.dungeonLevel[dungeon][1]>0 and nameLevel<GBB.dungeonLevel[dungeon][1] then

					nameLevel=GBB.dungeonLevel[dungeon][1]
				end
			end
		end
	end

	if dungeons["DEADMINES"] 
		and not dungeons["DMW"] 
		and not dungeons["DME"] 
		and not dungeons["DME"] 
		and name ~= nil 
	then
		if nameLevel>0 and nameLevel<40 then
			dungeons["DM"]=true
			dungeons["DM2"]=false
		else
			dungeons["DM"]=false
			dungeons["DM2"]=true
		end
	end

	if isBad then
		--dungeons={}
	elseif isGood then
		for parentKey, secondKeys in pairs(GBB.dungeonSecondTags) do
			local anySecondaryFound = false
			if dungeons[parentKey] == true then
				for _, altKey in ipairs(secondKeys) do
					-- check if altKey is negative & get base dungeon key
					if altKey:sub(1,1) == "-" then
						altKey = altKey:sub(2) 
					end

					if dungeons[altKey] == true then
						anySecondaryFound=true
					end
				end
				if not anySecondaryFound then
					for _, altKey in ipairs(secondKeys) do
						if altKey:sub(1, 1) ~= "-" then
							-- force enable all alt keys if none were found in message
							dungeons[altKey]= true
						end
					end
				end
			end
		end

		if next(dungeons) == nil then
			dungeons["MISC"]=true
		end
	elseif dungeons["TRADE"] then
		isGood=true
	end

	-- remove all primary dungeon keys
	for dungeonKey, _ in pairs(GBB.dungeonSecondTags) do
		if dungeons[dungeonKey] == true then
			-- this removes "DEADMINES" and keeps either DM or DM2
			dungeons[dungeonKey] = nil
		end
	end

	if GBB.DB.CombineSubDungeons then
		for parentKey, secondaryKeys in pairs(GBB.dungeonSecondTags) do
			-- ignore DEADMINES
			-- its doesnt actually have sub dungeons
			if parentKey ~= "DEADMINES" then
				for _, altKey in pairs(secondaryKeys) do
					if dungeons[altKey] then
						dungeons[parentKey] = true
						dungeons[altKey] = nil
					end
				end
			end
		end
	end

	-- isolate travel services so they don't show up in groups
	if GBB.DB.IsolateTravelServices then
		if dungeons["TRAVEL"] then
			for ip,p in pairs(dungeons) do
				if ip~="TRAVEL" and hasTag==false then
					dungeons[ip]=false
				end
			end
		end
	end

	return dungeons, isGood, isBad, wordcount, isHeroic
end

local fullNameByGUID = {} ---@type table<string, string> 
function GBB.ParseMessage(msg,sender,guid,channel)
	if GBB.Initalized==false or sender==nil or sender=="" or msg==nil or msg=="" or string.len(msg)<4 then
		return
	end

	local appendTime = tonumber("0." .. math.random(100,999)) -- Append a random "millisecond" value. 
	local requestTime=tonumber(time() + appendTime)

	local doUpdate=false

	local locClass,engClass,locRace,engRace,Gender,gName,gRealm = GetPlayerInfoByGUID(guid)

	-- track server name by player guid (sometimes no server is seen on initial messages)
	local name, server = strsplit("-", sender)
	if server then
		fullNameByGUID[guid] = sender
	end
	if not GBB.DB.RemoveRealm then
		sender = fullNameByGUID[guid] or sender
		-- "mail" shows all realms
		-- "none" shows realm only when different realm
		-- "guild" like "none", but doesnt show guild realms names.
		name = Ambiguate(sender, "none")
	end

	if GBB.DB.RemoveRaidSymbols then
		msg=string.gsub(msg,"{.-}","*")
	else
		msg=string.gsub(msg,"{.-}",GBB.Tool.GetRaidIcon)
	end

	local updated=false
	for ir,req in pairs(GBB.RequestList) do
		if type(req) == "table" and req.guid == guid and req.last+GBB.COMBINEMSGTIMER>=requestTime then
			if req.dungeon=="TRADE" then
				updated=true
				if msg~=req.message then
					req.message=req.message .. "|n" .. msg
				end
			elseif req.dungeon~="DEBUG" and req.dungeon~="BAD" then
				if msg~=req.message then
					msg=req.message .. "|n" .. msg
				end
				break
			end
		end
	end
	if updated==true then
		return
	end
	--flm RFD need healer and 3 dps
	local dungeonList, isGood, isBad, wordcount, isHeroic = GBB.GetDungeons(msg,name)

	if type(dungeonList) ~= "table" then return end

	local dungeonTXT=""

	if GBB.DB.UseAllInLFG and isBad==false and isGood==false and string.lower(GBB.L["lfg_channel"])==string.lower(channel) then
		isGood=true
		if next(dungeonList) == nil then
			dungeonList["MISC"]=true
		end
	elseif isGood==false or isBad==true then
		dungeonList={}
	end

	if wordcount>1 then
		for dungeon,id in pairs(dungeonList) do
			local index=0
			if id== true and dungeon~=nil then

				if dungeon~="TRADE" then
					for ir,req in pairs(GBB.RequestList) do
						if type(req) == "table" and req.guid == guid and req.dungeon == dungeon then
							index=ir
							break
						end
					end
				end

				local isRaid = GBB.RaidList[dungeon] ~= nil

				if index==0 then
					index=#GBB.RequestList +1
					GBB.RequestList[index]={}
					GBB.RequestList[index].guid=guid
					GBB.RequestList[index].class=engClass
					GBB.RequestList[index].start=requestTime
					GBB.RequestList[index].dungeon=dungeon
					GBB.RequestList[index].IsGuildMember=IsInGuild() and IsGuildMember(guid)
					GBB.RequestList[index].IsFriend=C_FriendList.IsFriend(guid)
					GBB.RequestList[index].IsPastPlayer=GBB.GroupTrans[name]~=nil

					if GBB.FilterDungeon(dungeon, isHeroic, isRaid) and dungeon~="TRADE" and dungeon~="MISC" and GBB.FoldedDungeons[dungeon]~= true then
						if dungeonTXT=="" then
							dungeonTXT=GBB.dungeonNames[dungeon]
						else
							dungeonTXT=GBB.dungeonNames[dungeon]..", "..dungeonTXT
						end
					end
				end

				GBB.RequestList[index].name=name --update name incase realm found
				GBB.RequestList[index].message=msg
				GBB.RequestList[index].IsHeroic = isHeroic
				GBB.RequestList[index].IsRaid = isRaid
				GBB.RequestList[index].last=requestTime
				doUpdate=true
			end
		end
	end

	if dungeonTXT~="" and GBB.AllowInInstance() then
		if GBB.DB.NotifyChat then
			local FriendIcon=(C_FriendList.IsFriend(guid) and string.format(GBB.TxtEscapePicture,GBB.FriendIcon) or "") ..
						 ((IsInGuild() and IsGuildMember(guid)) and string.format(GBB.TxtEscapePicture,GBB.GuildIcon) or "") ..
						 (GBB.GroupTrans[name]~=nil and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon) or "" )
			local linkname=	"|Hplayer:"..name.."|h[|c"..GBB.Tool.ClassColor[engClass].colorStr ..name.."|r]|h"
			if GBB.DB.OneLineNotification then
				DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..linkname..FriendIcon..": "..msg,GBB.DB.NotifyColor.r,GBB.DB.NotifyColor.g,GBB.DB.NotifyColor.b)
			else
				DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..string.format(GBB.L["msgNewRequest"],linkname..FriendIcon,dungeonTXT),GBB.DB.NotifyColor.r*.8,GBB.DB.NotifyColor.g*.8,GBB.DB.NotifyColor.b*.8)
				DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..msg,GBB.DB.NotifyColor.r,GBB.DB.NotifyColor.g,GBB.DB.NotifyColor.b)
			end
		end
		if GBB.DB.NotifySound then
			PlaySound(GBB.NotifySound, GBB.DB.NotifySoundChannel)
		end
	end


	if doUpdate then
		for i,req in pairs(GBB.RequestList) do
			if type(req) == "table" then
				if req.guid == guid and req.last ~= requestTime then
					GBB.RequestList[i]=nil
					GBB.ClearNeeded=true
				end
			end
		end

	elseif GBB.DB.OnDebug then

		local index=#GBB.RequestList +1
		GBB.RequestList[index]={}
		GBB.RequestList[index].name=name
		GBB.RequestList[index].guid=guid
		GBB.RequestList[index].class=engClass
		GBB.RequestList[index].start=requestTime
		if isBad then
			GBB.RequestList[index].dungeon="BAD"
		else
			GBB.RequestList[index].dungeon="DEBUG"
		end

		GBB.RequestList[index].message=msg
		GBB.RequestList[index].IsHeroic = isHeroic
		GBB.RequestList[index].last=requestTime
	end

end
function GBB.UnfoldAllDungeon()
	for k,v in pairs(GBB.FoldedDungeons) do
		GBB.FoldedDungeons[k]=false
	end
	GBB.UpdateList()
end
function GBB.FoldAllDungeon()
	for k,v in pairs(GBB.FoldedDungeons) do
		GBB.FoldedDungeons[k]=true
	end
	GBB.UpdateList()
end

local function createMenu(DungeonID,req)
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
		GBB.PopupDynamic:AddItem(GBB.L["BtnFold"], false,GBB.FoldedDungeons,DungeonID, nil, true)
		GBB.PopupDynamic:AddItem(GBB.L["BtnFoldAll"], false,GBB.FoldAllDungeon, nil, true)
		GBB.PopupDynamic:AddItem(GBB.L["BtnUnFoldAll"], false,GBB.UnfoldAllDungeon, nil, true)
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
	GBB.PopupDynamic:AddItem(GBB.L["CboxRemoveRealm"],false,GBB.DB,"RemoveRealm")
	GBB.PopupDynamic:AddItem(GBB.L["CboxNotifyChat"],false,GBB.DB,"NotifyChat")
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(SETTINGS, false, GBB.OptionsBuilder.OpenCategoryPanel, 1)
	-- todo: Open to filter settings to expac related to DungeonID
	GBB.PopupDynamic:AddItem(FILTERS, false, GBB.OptionsBuilder.OpenCategoryPanel, 2)
	GBB.PopupDynamic:AddItem(GBB.L["BtnCancel"], false, nil, nil, nil, true)
	GBB.PopupDynamic:Show()
end

function GBB.ClickFrame(self,button)
	if button=="LeftButton" then
	else
		createMenu()
	end
end

function GBB.ClickDungeon(self,button)
	local id=string.match(self:GetName(), "GBB.Dungeon_(.+)")
	if id==nil or id==0 then return end

	-- Shift + Left-Click
	if button=="LeftButton" and IsShiftKeyDown() then
		if GBB.FoldedDungeons[id] then
			GBB.UnfoldAllDungeon()
		else
			GBB.FoldAllDungeon()
		end
	-- Left-Click
	elseif button=="LeftButton" then
		if GBB.FoldedDungeons[id] then
			GBB.FoldedDungeons[id]=false
		else
			GBB.FoldedDungeons[id]=true
		end
		GBB.UpdateList()
	-- Any other mouse click
	else
		createMenu(id)
	end

end

---@param entry RequestEntry
function GBB.ClickRequest(entry, button)
	local req = entry.requestInfo
	if entry.__custom_on_click then entry.__custom_on_click(); return end
	if not req then return end
	if button=="LeftButton" then
		if IsShiftKeyDown() then
			WhoRequest(req.name)
			--SendWho( req.name )
		elseif IsAltKeyDown() then
			GBB.SendJoinRequestMessage(req.name, req.dungeon, req.IsHeroic)
		elseif IsControlKeyDown() then
			InviteRequest(req.name)
		else
			WhisperRequest(req.name)
		end
	else
		createMenu(nil,req)
	end

end


function GBB.RequestShowTooltip(self)
	for id in string.gmatch(self:GetName(), "GBB.Item_(.+)") do
		local n=_G[self:GetName().."_message"]
		local req=GBB.RequestList[tonumber(id)]
		if not req then
			return
		end
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

function GBB.RequestHideTooltip(self)
	GameTooltip:Hide()
end

-- Function to update interactive state of all clickable elements
function GBB.UpdateRequestListInteractiveState()
    local isInteractive = GBB.DB.WindowSettings.isInteractive
	local isMovable = GBB.DB.WindowSettings.isMovable
	-- Register scroll parent for dragging when isInteractive and isMovable
	if isInteractive and isMovable then
		GroupBulletinBoardFrame_ScrollFrame:EnableMouse(true)
		GroupBulletinBoardFrame_ScrollFrame:RegisterForDrag("LeftButton")
		GroupBulletinBoardFrame_ScrollFrame:SetScript("OnDragStart", function() GroupBulletinBoardFrame:StartMoving() end)
		GroupBulletinBoardFrame_ScrollFrame:SetScript("OnDragStop", function() GroupBulletinBoardFrame:StopMovingAndSaveAnchors() end)
	else
		GroupBulletinBoardFrame_ScrollFrame:EnableMouse(false)
		GroupBulletinBoardFrame_ScrollFrame:RegisterForDrag()
		GroupBulletinBoardFrame_ScrollFrame:SetScript("OnDragStart", nil)
		GroupBulletinBoardFrame_ScrollFrame:SetScript("OnDragStop", nil)
	end
    -- When NOT isInteractive, only the Name should handle mouse events
    for _, header in pairs(GBB.FramesEntries) do
        if header:GetName() and header:GetName():match("^GBB%.Dungeon_") then
            header:EnableMouse(isInteractive)
			header:SetScript("OnMouseDown", isInteractive and GBB.ClickDungeon or nil)
			header:SetScript("OnEnter", isInteractive and onHeaderMouseEnter or nil)
			header:SetScript("OnLeave", isInteractive and onHeaderMouseLeave or nil)
			header.Name:EnableMouse(not isInteractive)
			header.Name:SetScript("OnMouseDown", not isInteractive and function(_, button)
				GBB.ClickDungeon(header, button)
			end or nil)
			header.Name:SetScript("OnEnter", not isInteractive and GenerateClosure(onHeaderMouseEnter, header) or nil)
			header.Name:SetScript("OnLeave", not isInteractive and GenerateClosure(onHeaderMouseLeave, header) or nil)
        end
    end
    -- When NOT isInteractive, only the Name should handle mouse events
    for _, entry in pairs(GBB.FramesEntries) do
        if entry:GetName() and entry:GetName():match("^GBB%.Item_") then
            entry:EnableMouse(isInteractive)
            entry.Name:EnableMouse(not isInteractive)
            if not isInteractive then
                entry.Name:SetScript("OnMouseDown", function(self, button) GBB.ClickRequest(entry, button) end)
                entry.Name:SetScript("OnEnter", function(self) GBB.RequestShowTooltip(entry) end)
                entry.Name:SetScript("OnLeave", function(self) GBB.RequestHideTooltip(entry) end)
				entry:SetScript("OnMouseDown", nil)
				entry:SetScript("OnEnter", nil)
				entry:SetScript("OnLeave", nil)
            else
				entry.Name:SetScript("OnMouseDown", nil)
				entry.Name:SetScript("OnEnter", nil)
				entry.Name:SetScript("OnLeave", nil)
				entry:SetScript("OnMouseDown", GBB.ClickRequest)
				entry:SetScript("OnEnter", GBB.RequestShowTooltip)
				entry:SetScript("OnLeave", GBB.RequestHideTooltip)
            end
        end
    end
end
