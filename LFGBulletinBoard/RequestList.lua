local TOCNAME,
	---@class Addon_RequestList : Addon_Tags, Addon_Tool
	---@field FramesEntries RequestHeader[]
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

---@param playerName string
local function sendWhoRequest(playerName)
	GBB.Tool.RunSlashCmd("/who " .. playerName)
end

---@param playerName string
local function startWhisperChat(playerName)
	ChatFrame_OpenChat("/w " .. playerName .." ")
end

---@param playerName string
local function sendInvite(playerName)
	GBB.Tool.RunSlashCmd("/invite " .. playerName)
end

---@param playerName string
local function ignorePlayer(playerName)
	for ir,req in pairs(GBB.RequestList) do
		if type(req) == "table" and req.name == playerName then
			req.last=0
		end
	end
	GBB.ClearNeeded=true
	C_FriendList.AddIgnore(playerName)
end
---@param request table request data object
local function dismissRequest(request)
	for requestIdx, req in pairs(GBB.RequestList) do
		local match = true
		for _, criteria in ipairs({"name", "dungeon", "startTime"}) do
			if request[criteria] ~= req[criteria] then
				match = false; break;
			end
		end
		if match then tremove(GBB.RequestList, requestIdx); break; end
	end
	GBB.UpdateList()
end

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
--------------------------------------------------------------------------------
-- Request Entry Frame
--------------------------------------------------------------------------------

---@class RequestListEntryFrame: Frame
---@field requestData table? GBB.RequestList data object, expected for `UpdateTextLayout`
local EntryFrameMixin = {}
function EntryFrameMixin:OnLoad()
	self.Name = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	self.Message = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	self.Time = self:CreateFontString(nil, "ARTWORK", "GameFontNormalRight")
	self.Highlight = self:CreateTexture(nil, "HIGHLIGHT")

	-- points not expected to change, see `layoutEntryChildRegions` func for rest.
	self.Name:SetPoint("TOPLEFT")
	self.Time:SetPoint("TOPRIGHT")

	local offset = 2 -- offset padding used compensate text clipping out of its containing frame
	self.Highlight:SetPoint("TOPLEFT", -offset, offset)
	self.Highlight:SetPoint("BOTTOMRIGHT", offset, -offset)
	self.Highlight:SetAtlas("search-highlight")
	self.Highlight:SetDesaturated(true) -- its comes blue by default
	self.Highlight:SetVertexColor(0.7, 0.7, 0.7, 0.4)
	self.Highlight:SetBlendMode("ADD")
	self:SetScript("OnMouseDown", self.OnMouseDown)
	self:SetScript("OnEnter", self.OnEnter)
	self:SetScript("OnLeave", self.OnLeave)
	GBB.Tool.EnableHyperlink(self)
end

---@param entry RequestListEntryFrame
local fillEntryChildRegions = function(entry, request)
	local formattedName = request.name
	local playerLevel = GBB.RealLevel[request.name]
	if playerLevel then formattedName = string.format("%s (%s)", formattedName, playerLevel) end
	local classColor = GBB.DB.ColorByClass and request.class and GBB.Tool.ClassColor[request.class].colorStr
	if classColor then formattedName = WrapTextInColorCode(formattedName, classColor) end

	-- Note: in the future there should be dedicated texture frames for all the following icons
	-- that way we dont have to deal with all the annoying parsing of strings to display them in the rendered text.
	local classIcon = (GBB.DB.ShowClassIcon and request.class)
		and GBB.Tool.GetClassIcon(request.class, GBB.DB.CompactStyle and 12 or 18)
		or ""

	local playerRelationIcon = (
		(request.IsFriend
			and string.format(GBB.TxtEscapePicture, GBB.FriendIcon)
			or "")
		..(request.IsGuildMember
			and string.format(GBB.TxtEscapePicture, GBB.GuildIcon)
			or "")
		..(request.IsPastPlayer
			and string.format(GBB.TxtEscapePicture, GBB.PastPlayerIcon)
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
		if request.IsHeroic == true then
			local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.HeroicDungeonColor.r,GBB.DB.HeroicDungeonColor.g,GBB.DB.HeroicDungeonColor.b)
			-- note colorHex here has no alpha channels
			typePrefix = WrapTextInColorCode(
				("[" .. GBB.L["heroicAbr"] .. "]    "), 'FF'..colorHex
			);
		elseif request.IsRaid == true then
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
			classIcon, formattedName, playerRelationIcon, request.message
		);
		entry.Message:SetIndentedWordWrap(true)
	else
		entry.Name:SetFormattedText("%s%s%s", classIcon, formattedName, playerRelationIcon)
		entry.Message:SetFormattedText("%s %s", typePrefix, request.message)
		entry.Time:SetText(fmtTime)
		entry.Message:SetIndentedWordWrap(false)
	end

	entry.Message:SetTextColor(GBB.DB.EntryColor.r,GBB.DB.EntryColor.g,GBB.DB.EntryColor.b,GBB.DB.EntryColor.a)
	entry.Time:SetTextColor(GBB.DB.TimeColor.r,GBB.DB.TimeColor.g,GBB.DB.TimeColor.b,GBB.DB.TimeColor.a)
end

---@param entry RequestListEntryFrame
---@param layout "normal" | "two-line" | "chat"
local layoutEntryChildRegions = function(entry, layout)
	local scale = layout == "two-line" and 0.85 or 1
	entry.Name:SetScale(scale)
	entry.Time:SetScale(scale)
	entry.Name:SetFontObject(GBB.DB.FontSize)
	entry.Time:SetFontObject(GBB.DB.FontSize)
	entry.Message:SetFontObject(GBB.DB.FontSize)
	if layout == "normal" then
		entry.Name:Show()
		entry.Time:Show()
		entry.Message:SetPoint("TOPLEFT", entry.Name, "TOPRIGHT", 6, 0)
		entry.Message:SetPoint("TOPRIGHT", entry.Time, "TOPLEFT", -6, 0)
	elseif layout == "two-line" then
		entry.Name:Show()
		entry.Time:Show()
		entry.Message:SetPoint("TOPLEFT", entry.Name, "BOTTOMLEFT", 0, -1)
		entry.Message:SetPoint("TOPRIGHT", entry.Time, "BOTTOMRIGHT", 0, -1)
	elseif layout == "chat" then
		entry.Name:Hide()
		entry.Time:Hide()
		entry.Message:SetPoint("TOPLEFT")
		entry.Message:SetPoint("TOPRIGHT")
	end
	entry.Message:Show()
	-- set name & time widths
	if layout == "normal" or layout == "two-line" then
		-- set name & time to this sessions widest seen frames
		local padX = 10
		-- name
		local stringWidth = entry.Name:GetStringWidth() + padX
		GBB.DB.widthNames = math.max(GBB.DB.widthNames, stringWidth)
		entry.Name:SetWidth(GBB.DB.widthNames)
		-- time
		stringWidth = entry.Time:GetStringWidth() + padX
		GBB.DB.widthTimes = math.max(GBB.DB.widthTimes, stringWidth)
		entry.Time:SetWidth(GBB.DB.widthTimes)
		entry.Time:SetPoint("TOPRIGHT", entry, "TOPRIGHT")
	elseif layout == "chat" then
		-- name and time are hidden
	end

	-- hack: make sure the initial size of the FontString object is big enough
	-- to allow for all possible text when not truncating for `GetStringHeight`
	if GBB.DB.DontTrunicate then entry.Message:SetHeight(999) end

	-- set sub element heights
	local textPadding = 3 -- px
	local messageHeight = GBB.DB.DontTrunicate and entry.Message:GetStringHeight() or entry.Message:GetLineHeight()
	entry.Message:SetHeight(messageHeight + textPadding)
	entry.Name:SetHeight(entry.Name:GetLineHeight() + textPadding)
	entry.Time:SetHeight(entry.Time:GetLineHeight() + textPadding)

	-- finally set the frame height
	if layout == "normal" or layout == "chat" then
		entry:SetHeight(entry.Message:GetHeight())
	elseif layout == "two-line" then
		entry:SetHeight(entry.Name:GetHeight() + entry.Message:GetHeight())
	end
end

function EntryFrameMixin:UpdateTextLayout()
	local request = self.requestData
	assert(request, "No request data found for entry ", self)

	--- Fill out the entry frames children with the request data
	--- note: ran before `layoutEntryChildRegions` to get accurate returns from `GetStringHeight` of fontStrings
	fillEntryChildRegions(self, request)

	--- Adjust frame sizes and positions based on chosen layout
	local layout = (GBB.DB.CompactStyle and "two-line") or (GBB.DB.ChatStyle and "chat") or "normal"
	layoutEntryChildRegions(self, layout)
end
function EntryFrameMixin:UpdateInteractiveState()
	-- When NOT isInteractive, only the Name should handle mouse events
	local isInteractive = GBB.DB.WindowSettings.isInteractive
	self:EnableMouse(isInteractive)
	self.Name:EnableMouse(not isInteractive)
	if not isInteractive then
		self.Name:SetScript("OnMouseDown", function(_, button) self:OnMouseDown(button) end)
		self.Name:SetScript("OnEnter", function() self:OnEnter() end)
		self.Name:SetScript("OnLeave", function() self:OnLeave() end)
		self:SetScript("OnMouseDown", nil)
		self:SetScript("OnEnter", nil)
		self:SetScript("OnLeave", nil)
	else
		self:SetScript("OnMouseDown", self.OnMouseDown)
		self:SetScript("OnEnter", self.OnEnter)
		self:SetScript("OnLeave", self.OnLeave)
		self.Name:SetScript("OnMouseDown", nil)
		self.Name:SetScript("OnEnter", nil)
		self.Name:SetScript("OnLeave", nil)
	end
end
function EntryFrameMixin:OnEnter()
	local request = self.requestData
	if not request then return end

	GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
	if not GBB.DB.EnableGroup then GameTooltip:SetOwner(GroupBulletinBoardFrame, "ANCHOR_BOTTOM", 0,0	)
	else GameTooltip:SetOwner(GroupBulletinBoardFrame, "ANCHOR_BOTTOM", 0,-25) end

	GameTooltip:ClearLines()

	-- add message
	GameTooltip:AddLine(request.message,0.9,0.9,0.9,1)

	-- add time
	if GBB.DB.ChatStyle then
		GameTooltip:AddLine(string.format(GBB.L["msgLastTime"],GBB.formatTime(time()-request.last)).."|n"..string.format(GBB.L["msgTotalTime"],GBB.formatTime(time()-request.start)))
	elseif GBB.DB.ShowTotalTime then
		GameTooltip:AddLine(string.format(GBB.L["msgLastTime"],GBB.formatTime(time()-request.last)))
	else
		GameTooltip:AddLine(string.format(GBB.L["msgTotalTime"],GBB.formatTime(time()-request.start)))
	end

	-- add class icon and historical group info if previously grouped with this player
	if GBB.DB.EnableGroup and GBB.GroupTrans and GBB.GroupTrans[request.name] then
		local playerHistory=GBB.GroupTrans[request.name]

		GameTooltip:AddLine(
			(GBB.Tool.GetClassIcon(playerHistory.class) or "")
			..("|c"..GBB.Tool.ClassColor[playerHistory.class].colorStr)
			..playerHistory.name
		)
		if playerHistory.dungeon then GameTooltip:AddLine(playerHistory.dungeon) end
		if playerHistory.Note then GameTooltip:AddLine(playerHistory.Note) end
		GameTooltip:AddLine(SecondsToTime(GetServerTime()-playerHistory.lastSeen))
	end

	GameTooltip:Show()
end
function EntryFrameMixin:OnLeave() GameTooltip:Hide() end
function EntryFrameMixin:OnMouseDown(button, down)
	local req = self.requestData
	if not req then return end
	if button=="LeftButton" then
		if IsShiftKeyDown() then
			sendWhoRequest(req.name)
		elseif IsAltKeyDown() then
			GBB.SendJoinRequestMessage(req.name, req.dungeon, req.IsHeroic)
		elseif IsControlKeyDown() then
			sendInvite(req.name)
		else
			startWhisperChat(req.name)
		end
	else
		GBB.CreateSharedBoardContextMenu(self, req)
	end
end

local requestEntryFramePool = CreateObjectPool(function(pool)
	local entry = CreateFrame("Frame", nil, GroupBulletinBoardFrame_ScrollChildFrame);
	Mixin(entry, EntryFrameMixin)
	EntryFrameMixin.OnLoad(entry)
	GBB.Tool.EnableHyperlink(entry)
	return entry
end, Pool_HideAndClearAnchors)

---@param scrollPos number current scroll position
---@param req table request info table
---@param forceHeight number? force the height of the entry item
---@return number height The height of the entry item
local function CreateItem(scrollPos, req, forceHeight)
	local entry = requestEntryFramePool:Acquire() ---@type RequestListEntryFrame
	entry.requestData = req
	entry:UpdateTextLayout()
	entry:UpdateInteractiveState()
	entry:Show()

	-- finally set element heights and return container height
	entry:SetPoint("RIGHT", GroupBulletinBoardFrame_ScrollChildFrame, "RIGHT", 0, 0)
	entry:SetPoint("TOPLEFT", GroupBulletinBoardFrame_ScrollChildFrame, "TOPLEFT", 10, -scrollPos)
	if not GBB.DB.DontTrunicate and forceHeight then entry:SetHeight(forceHeight) end
	return entry:GetHeight() -- final height
end

local function CreateNoFiltersMessage()
	local entry = requestEntryFramePool:Acquire()
	entry.Name:SetWidth(0)
	entry.Name:SetText("")
	entry.Time:SetWidth(0)
	entry.Time:SetText("")
	entry.Message:SetText(GBB.L.NO_FILTERS_SELECTED)
	entry.Message:SetFontObject("GameFontNormalLarge")
	entry.Message:SetJustifyH("CENTER")
	entry.Message:SetMaxLines(2)
	entry.Message:SetTextColor(0.6, 0.6, 0.6, 0.6)
	entry.Message:SetHeight(entry.Message:GetStringHeight())
	entry:SetHeight(entry.Message:GetHeight())
	entry:SetPoint("RIGHT", GroupBulletinBoardFrame_ScrollChildFrame, "RIGHT", 0, 0)
	entry:SetPoint("TOPLEFT", GroupBulletinBoardFrame_ScrollChildFrame, "TOPLEFT", 10, 0)
	entry:SetHeight(entry.Message:GetHeight())

	-- override mouse down to open to the latest xpac filter settings
	function entry:OnMouseDown()
		GBB.OptionsBuilder.OpenCategoryPanel(2)
		entry.OnMouseDown = EntryFrameMixin.OnMouseDown -- restore script
	end
	entry:Show()
end
--------------------------------------------------------------------------------

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

--- generates items for display in the scroll list. headers are stored in `GBB.FramesEntries` and are shown/hidden as needed depending on the data in `GBB.RequestList`.
function GBB.UpdateList()
	GBB.Clear()
	if not GroupBulletinBoardFrame:IsVisible() then return end

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

    local scrollHeight = 0
	local count = 0
	local itemsInCategory = 0
	local ownRequestDungeons = {}
	local itemSpacing = 6
	-- reset the list of existing headers to draw new ones
	existingHeaders = {}

	if GBB.DBChar.DontFilterOwn then
		for i,req in pairs(GBB.RequestList) do
			if type(req) == "table" and req.guid == UnitGUID("player") and req.last + GBB.DB.TimeOut*2 > time()then
				ownRequestDungeons[req.dungeon]=true
			end
		end
	end

	local baseItemHeight = 25

	-- Hide all exisiting scroll frame elements
	for _, f in pairs(GBB.FramesEntries) do f:Hide() end
	requestEntryFramePool:ReleaseAll()

	-- set scroll height slightly bigger than 1 element to account for category headers being taller
	GroupBulletinBoardFrame_ScrollFrame.ScrollBar.scrollStep = baseItemHeight * 1.25

	-- iterate request and generate headers and items for display
	for _, req in pairs(GBB.RequestList) do
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
					scrollHeight = scrollHeight + CreateItem(scrollHeight, req) + itemSpacing
					itemsInCategory = itemsInCategory + 1
				end
			end
		end
	end

	-- Show a help message when users have less than `n` filters selected and 0 requests are shown
	if GBB.GetNumActiveFilters() < 5 and count == 0 then CreateNoFiltersMessage() end

	-- adds a window's worth of padding to the bottom of the scroll frame
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
		and not dungeons["DMN"]
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

---@class SharedBoardContextMenuApiOverrides
local apiOverridesEmpty = { -- table mostly here to give type hints,
	fold = {}, ---@type { isSelected: (fun(key: string): boolean), setSelected: fun(key: string) }?
	foldAll = {}, ---@type { onSelect: fun(key: string) }?
	unfoldAll = {}, ---@type { onSelect: fun(key: string) }?
	dismissRequest = {}, ---@type { onSelect: fun(req: LFGToolRequestData) }?
}

---Generates a context menu for a request entry or dungeon header. (see `data` arg)
---@param parent table|Region? owner frame
---@param data string|{name: string, class: string}? either dungeonKey or request entry info table (name, class)
---@param apiOverrides? SharedBoardContextMenuApiOverrides # used to pass functions from LFGToolList.lua
function GBB.CreateSharedBoardContextMenu(parent, data, apiOverrides)
	if not apiOverrides then apiOverrides = apiOverridesEmpty;
	else for k,v in pairs(apiOverridesEmpty) do apiOverrides[k] = apiOverrides[k] or v end end

	local createThinDivider = function(rootDesc)
		return rootDesc:CreateDivider():SetFinalInitializer(function(frame) frame:SetHeight(3) end)
	end
	---@param rootDesc RootMenuDescriptionProxy
	local menuGenerator = function(_, rootDesc)
		if type(data) == "table" then -- request entry options
			rootDesc:CreateTitle(data.name, GBB.Tool.ClassColor[data.class])
			createThinDivider(rootDesc)
			rootDesc:CreateTitle(UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_INTERACT)
			rootDesc:CreateButton(WHO, function() sendWhoRequest(data.name) end):SetResponse(MenuResponse.Refresh)
			rootDesc:CreateButton(WHISPER, function() startWhisperChat(data.name) end)
			rootDesc:CreateButton(INVITE, function() sendInvite(data.name) end)
			createThinDivider(rootDesc)
			rootDesc:CreateTitle(UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_OTHER)
			local dismissRequest = apiOverrides.dismissRequest.onSelect or dismissRequest
			rootDesc:CreateButton(IGNORE, function()
				ignorePlayer(data.name)
				dismissRequest(data)
			end)
			rootDesc:CreateButton(GBB.L.DISMISS_REQUEST, dismissRequest, data)
		elseif type(data) == "string" then -- dungeon/category header options
			rootDesc:CreateTitle(GBB.dungeonNames[data] or "Header Options")
			local foldApi = {
				isSelected = apiOverrides.fold.isSelected
				or function() return GBB.FoldedDungeons[data] end,
				setSelected = apiOverrides.fold.setSelected
				or function() GBB.FoldedDungeons[data] = (not GBB.FoldedDungeons[data]) end,
				foldAll = apiOverrides.foldAll.onSelect or GBB.FoldAllDungeon,
				unfoldAll = apiOverrides.unfoldAll.onSelect or GBB.UnfoldAllDungeon,
			}
			rootDesc:CreateCheckbox(GBB.L["BtnFold"], foldApi.isSelected, foldApi.setSelected, data)
			local filterSetting = GBB.OptionsBuilder.GetSavedVarHandle(GBB.DBChar, "FilterDungeon"..data)
			createThinDivider(rootDesc)
			rootDesc:CreateButton(GBB.L["BtnFoldAll"], foldApi.foldAll)
			rootDesc:CreateButton(GBB.L["BtnUnFoldAll"], foldApi.unfoldAll)
			createThinDivider(rootDesc)
			rootDesc:CreateTitle(GBB.L.FILTER_OPTIONS)
			rootDesc:CreateButton(DISABLE, function() filterSetting:SetValue(false) end)
		else return end
		createThinDivider(rootDesc)
		-- shared options
		rootDesc:CreateButton(CANCEL, nop)
	end
	MenuUtil.CreateContextMenu(parent, menuGenerator)
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
		GBB.CreateSharedBoardContextMenu(self, id)
	end

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
    for entry in requestEntryFramePool:EnumerateActive() do
		entry:UpdateInteractiveState()
	end
end
