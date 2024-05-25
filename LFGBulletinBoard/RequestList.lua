local TOCNAME, GBB = ...

--ScrollList / Request
------------------------------------------------------------------------------------- 
local lastHeaderCategory = "" -- last category/dungeon header seen when building the scroll list
local lastIsFolded
local requestNil={dungeon="NIL",start=0,last=0,name=""}

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
	-- (table will always & repeatedlybe  accessed by the same set of keys so may as well)
	setmetatable(lookup, {
		__index = function(_, dungeonKey)
			rawset(lookup, dungeonKey, false)
			return false
		end
	})
	return lookup
end)()

-- track catergories/dungeon keys that have had a header created
-- this table is wiped on every `GBB.UpdateList` when the board is re-drawn
local existingHeaders= {}

---@param yy integer The current bottom pos from the top of the scroll frame
---@param dungeon string The dungeons "key" ie DM|MC|BWL|etc
---@return integer yy The updated bottom pos of the scroll frame after adding the header
local function CreateHeader(yy, dungeon)
	local AnchorTop="GroupBulletinBoardFrame_ScrollChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_ScrollChildFrame"
	local ItemFrameName="GBB.Dungeon_"..dungeon

	if GBB.FramesEntries[dungeon]==nil then
		GBB.FramesEntries[dungeon]=CreateFrame("Frame",ItemFrameName , GroupBulletinBoardFrame_ScrollChildFrame, "GroupBulletinBoard_TmpHeader")
		GBB.FramesEntries[dungeon]:SetPoint("RIGHT", _G[AnchorRight], "RIGHT", 0, 0)
		_G[ItemFrameName.."_name"]:SetPoint("RIGHT",GBB.FramesEntries[dungeon], "RIGHT", 0,0)
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

	-- Initialize this value now so we can (un)fold only existing entries later
	-- while still allowing new headers to follow the HeadersStartFolded setting
	if GBB.FoldedDungeons[dungeon]==nil then
		GBB.FoldedDungeons[dungeon]=GBB.DB.HeadersStartFolded
	end

	if lastHeaderCategory~="" and not (lastIsFolded and GBB.FoldedDungeons[dungeon]) then
		yy=yy+10
	end

	if GBB.FoldedDungeons[dungeon]==true then
		colTXT=colTXT.."[+] "
		lastIsFolded=true
	else
		lastIsFolded=false
	end

	_G[ItemFrameName.."_name"]:SetText(colTXT..GBB.dungeonNames[dungeon].." |cFFAAAAAA"..GBB.LevelRange(dungeon).."|r")
	_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)
	GBB.FramesEntries[dungeon]:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 0,-yy)
	GBB.FramesEntries[dungeon]:Show()

	yy=yy+_G[ItemFrameName]:GetHeight()
	lastHeaderCategory = dungeon
	existingHeaders[dungeon] = true
	return yy
end

local function CreateItem(yy,i,doCompact,req,forceHight)
	local AnchorTop="GroupBulletinBoardFrame_ScrollChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_ScrollChildFrame"
	local ItemFrameName="GBB.Item_"..i

	if GBB.FramesEntries[i]==nil then
		GBB.FramesEntries[i]=CreateFrame("Frame",ItemFrameName , GroupBulletinBoardFrame_ScrollChildFrame, "GroupBulletinBoard_TmpRequest")
		GBB.FramesEntries[i]:SetPoint("RIGHT", _G[AnchorRight], "RIGHT", 0, 0)

		_G[ItemFrameName.."_name"]:SetPoint("TOPLEFT")
		_G[ItemFrameName.."_time"]:SetPoint("TOP",_G[ItemFrameName.."_name"], "TOP",0,0)

		_G[ItemFrameName.."_message"]:SetNonSpaceWrap(false)
		_G[ItemFrameName.."_message"]:SetFontObject(GBB.DB.FontSize)
		_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)
		_G[ItemFrameName.."_time"]:SetFontObject(GBB.DB.FontSize)
		if GBB.DontTrunicate then
			GBB.ClearNeeded=true
		end
		GBB.Tool.EnableHyperlink(GBB.FramesEntries[i])
	end

	GBB.FramesEntries[i]:SetHeight(999)
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

	if req then
		local prefix
		if GBB.DB.ColorByClass and req.class and GBB.Tool.ClassColor[req.class].colorStr then
			prefix="|c"..GBB.Tool.ClassColor[req.class].colorStr
		else
			prefix="|r"
		end
		local ClassIcon=""
		if GBB.DB.ShowClassIcon and req.class and GBB.Tool.IconClass[req.class] then
			if doCompact<1  or GBB.DB.ChatStyle then
				ClassIcon=GBB.Tool.IconClass[req.class]
			else
				ClassIcon=GBB.Tool.IconClassBig[req.class]
			end
		end

		local FriendIcon=(req.IsFriend and string.format(GBB.TxtEscapePicture,GBB.FriendIcon) or "") ..
						 (req.IsGuildMember and string.format(GBB.TxtEscapePicture,GBB.GuildIcon) or "") ..
						 (req.IsPastPlayer and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon) or "")

		local suffix="|r"

		if GBB.RealLevel[req.name] then
			suffix=" ("..GBB.RealLevel[req.name]..")"..suffix
		end

		local ti
		if GBB.DB.ShowTotalTime then
			if (time() - req.start < 0) then -- Quick fix for negative timers that happen as a result of new time calculation.
				ti=GBB.formatTime(0) 
			else
				ti=GBB.formatTime(time()-req.start)
			end
		else
			if (time() - req.last < 0) then
				ti=GBB.formatTime(0)
			else
				ti=GBB.formatTime(time()-req.last)
			end
		end

		local typePrefix = ""
		if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
			-- "heroic" is not a concept in classic era/sod
			if req.IsHeroic == true then
				local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.HeroicDungeonColor.r,GBB.DB.HeroicDungeonColor.g,GBB.DB.HeroicDungeonColor.b)
				typePrefix = "|c00".. colorHex .. "[" .. GBB.L["heroicAbr"] .. "]     "
			elseif req.IsRaid == true then
				typePrefix = "|c00ffff00" .. "[" .. GBB.L["raidAbr"] .. "]     "
			else
				local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.NormalDungeonColor.r,GBB.DB.NormalDungeonColor.g,GBB.DB.NormalDungeonColor.b)
				typePrefix = "|c00".. colorHex .. "[" .. GBB.L["normalAbr"] .. "]    "
			end
		end

		if GBB.DB.ChatStyle then
			_G[ItemFrameName.."_name"]:SetText()
			_G[ItemFrameName.."_message"]:SetText(ClassIcon.."["..prefix ..req.name..suffix.."]"..FriendIcon..": "..req.message)
		else
			_G[ItemFrameName.."_name"]:SetText(ClassIcon..prefix .. req.name .. suffix..FriendIcon)
			_G[ItemFrameName.."_message"]:SetText(typePrefix .. suffix .. req.message)
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

	GBB.FramesEntries[i]:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 10,-yy)
	_G[ItemFrameName.."_message"]:SetHeight(h+10)
	GBB.FramesEntries[i]:SetHeight(h)

	if req then
		GBB.FramesEntries[i]:Show()
	else
		GBB.FramesEntries[i]:Hide()
	end

	return h
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

local function InviteRequestWithRole(gbbName,gbbDungeon,gbbHeroic,gbbRaid)
	if not GBB.DB.InviteRole then GBB.DB.InviteRole = "DPS" end
	local gbbDungeonPrefix = ""	
	if gbbHeroic then
		gbbDungeonPrefix = "H "
	elseif not gbbHeroic and not gbbRaid then
		gbbDungeonPrefix = "N "
	end

	-- Not sure if necessary, but Heroic Miscellaneous sounds like a dangerous place.
	if gbbDungeon == "MISC" or gbbDungeon == "TRADE" or gbbDungeon == "TRAVEL" then
		gbbDungeonPrefix = ""
	end

	SendChatMessage(string.format(GBB.L["msgLeaderOutbound"], gbbDungeonPrefix .. GBB.dungeonNames[gbbDungeon], GBB.DB.InviteRole), "WHISPER", nil, gbbName)
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
		local playername=(UnitFullName("player"))

		for i,req in pairs(GBB.RequestList) do
			if type(req) == "table" and req.name==playername and req.last + GBB.DB.TimeOut*2 > time()then
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
			then
				count = count + 1
				local requestDungeon = req.dungeon

				-- previously having this option enabled would create a header.
				-- for *all* filtered dungeons (even i not requests existed).
				-- This is opposed to only creating headers for categories with existing requests.
				-- Which is the default behaviour without this option enabled.
				-- Bug or feature here it is reimplemented
				-- The following conditional black could can removed safely if the behaviour is unwanted.
				if GBB.DB.EnableShowOnly 
					-- only run once, right before the first request is processed
					and requestIdx == 1 
				then
					local firstRequestSortIdx = GBB.dungeonSort[requestDungeon]
					if firstRequestSortIdx and firstRequestSortIdx > 1 then
						-- note: a 0.5 step is used to work around DM2 and SM2 having fractional sort indexes in the dungeonSort table (See Dungeons.lua)
						for dungeonSortIdx = 1, firstRequestSortIdx - 1, 0.5 do
							local categoryDungeon = GBB.dungeonSort[dungeonSortIdx]
							if categoryDungeon then
								if GBB.DB.CombineSubDungeons 
								-- ignore "DEADMINES" mapped entries
								-- see GBB.dungeonSecondTags
								and categoryDungeon ~= "DM"
								then
									local parent = subDungeonParentLookup[categoryDungeon]
									if parent then
										categoryDungeon = parent
									end
								end
								if not existingHeaders[categoryDungeon] -- header not created
								and (ownRequestDungeons[categoryDungeon] -- is own request
									or GBB.FilterDungeon(categoryDungeon, req.IsHeroic, req.IsRaid))-- category is tracked in filter options

								then
									scrollHeight = CreateHeader(scrollHeight, categoryDungeon)
									if not GBB.FoldedDungeons[categoryDungeon] then
										-- add space for missing requests 
										scrollHeight = scrollHeight + baseItemHeight*GBB.DB.ShowOnlyNb
									end
								end
							end
						end
					end
				end
				
				-- Since RequestList is already sorted in order of dungeons
				-- and dungeons have already been filtered/combined at this point
				-- create header (if needed)
				if not existingHeaders[requestDungeon] then
					
					-- retaining old behvaiour of adding space for missing requests
					-- once weve moved on to the next header's category/dungeon in `RequestList`
					if GBB.DB.EnableShowOnly -- this behaviour only occured with this option enabled
						and lastCategory and (requestDungeon ~= lastCategory) 
						and not GBB.FoldedDungeons[lastCategory] -- dont add space to folded categories
					then
						local reserved = baseItemHeight*(GBB.DB.ShowOnlyNb - itemsInCategory)
						scrollHeight = scrollHeight + reserved
					end

					scrollHeight = CreateHeader(scrollHeight, requestDungeon)
					lastCategory = requestDungeon
					itemsInCategory = 0; -- reset count on new category
				end
				-- add entry
				if GBB.FoldedDungeons[requestDungeon] ~= true -- not folded
					and (not GBB.DB.EnableShowOnly -- no limit
						or itemsInCategory < GBB.DB.ShowOnlyNb) -- or limit not reached
					and doesRequestMatchResultsFilter(req.message) -- matches global results filter
				then
					scrollHeight= scrollHeight + CreateItem(scrollHeight,requestIdx,itemScale,req,baseItemHeight) + 3 -- why add 3? 
					itemsInCategory = itemsInCategory + 1
				end
			end
		end
	end

	if GBB.DB.EnableShowOnly then
		-- add space for missing requests in the last category
		if lastCategory and not GBB.FoldedDungeons[lastCategory] then
			local reserved = baseItemHeight*(GBB.DB.ShowOnlyNb - itemsInCategory)
			scrollHeight = scrollHeight + reserved
		end

		-- Originally, this option also added all the other tracked dungeon headers
		-- that functionality has been removed.
	end

	-- adds a window's woth of padding to the bottom of the scroll frame
	scrollHeight=scrollHeight+GroupBulletinBoardFrame_ScrollFrame:GetHeight()-20

	GroupBulletinBoardFrame_ScrollChildFrame:SetHeight(scrollHeight)
	GroupBulletinBoardFrameStatusText:SetText(string.format(GBB.L["msgNbRequest"], count))
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
				dungeons[x]=true
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

function GBB.ParseMessage(msg,name,guid,channel)
	if GBB.Initalized==false or name==nil or name=="" or msg==nil or msg=="" or string.len(msg)<4 then
		return
	end

	local appendTime = tonumber("0." .. math.random(100,999)) -- Append a random "millisecond" value. 
	local requestTime=tonumber(time() + appendTime)

	local doUpdate=false

	local locClass,engClass,locRace,engRace,Gender,gName,gRealm = GetPlayerInfoByGUID(guid)

	-- Add server name to player name by commenting out the split
	if GBB.DB.RemoveRealm then
		name=GBB.Tool.Split(name, "-")[1] -- remove GBB.ServerName
	end

	if GBB.DB.RemoveRaidSymbols then
		msg=string.gsub(msg,"{.-}","*")
	else
		msg=string.gsub(msg,"{.-}",GBB.Tool.GetRaidIcon)
	end

	local updated=false
	for ir,req in pairs(GBB.RequestList) do
		if type(req) == "table" and req.name == name and req.last+GBB.COMBINEMSGTIMER>=requestTime then
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
						if type(req) == "table" and req.name == name and req.dungeon == dungeon then
							index=ir
							break
						end
					end
				end

				local isRaid = GBB.RaidList[dungeon] ~= nil

				if index==0 then
					index=#GBB.RequestList +1
					GBB.RequestList[index]={}
					GBB.RequestList[index].name=name
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
			PlaySound(GBB.NotifySound)
		end
	end


	if doUpdate then
		for i,req in pairs(GBB.RequestList) do
			if type(req) == "table" then
				if req.name == name and req.last ~= requestTime then
					GBB.RequestList[i]=nil
					GBB.ClearNeeded=true
				end
			end
		end

	elseif GBB.DB.OnDebug then

		local index=#GBB.RequestList +1
		GBB.RequestList[index]={}
		GBB.RequestList[index].name=name
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
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnWho"],req.name),false,WhoRequest,req.name)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnWhisper"],req.name),false,WhisperRequest,req.name)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnInvite"],req.name),false,InviteRequest,req.name)
		GBB.PopupDynamic:AddItem(string.format(GBB.L["BtnIgnore"],req.name),false,IgnoreRequest,req.name)
		GBB.PopupDynamic:AddItem("",true)
	end
	if DungeonID then
		GBB.PopupDynamic:AddItem(GBB.L["BtnFold"], false,GBB.FoldedDungeons,DungeonID)
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
	GBB.PopupDynamic:AddItem(GBB.L["CboxRemoveRealm"],false,GBB.DB,"RemoveRealm")
	GBB.PopupDynamic:AddItem(GBB.L["CboxNotifyChat"],false,GBB.DB,"NotifyChat")
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(GBB.L["HeaderSettings"],false, GBB.Options.Open, 1)

	GBB.PopupDynamic:AddItem(GBB.L["PanelFilter"], false, GBB.Options.Open, 2)

	GBB.PopupDynamic:AddItem(GBB.L["PanelAbout"], false, GBB.Options.Open, 3)
	GBB.PopupDynamic:AddItem(GBB.L["BtnCancel"],false)
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

function GBB.ClickRequest(self,button)
	local id = string.match(self:GetName(), "GBB.Item_(.+)")
	if id==nil or id==0 then return end

	local req=GBB.RequestList[tonumber(id)]
	if button=="LeftButton" then
		if IsShiftKeyDown() then
			WhoRequest(req.name)
			--SendWho( req.name )
		elseif IsAltKeyDown() then
			InviteRequestWithRole(req.name,req.dungeon,req.IsHeroic,req.IsRaid)
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

			GameTooltip:AddLine(GBB.Tool.IconClass[entry.class]..
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
