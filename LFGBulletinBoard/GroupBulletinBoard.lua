local TOCNAME,
	---@class Addon_GroupBulletinBoard : Addon_Localization, Addon_CustomFilters, Addon_Dungeons, Addon_Tags, Addon_Options, Addon_Tool
	GBB = ...;

GroupBulletinBoard_Addon=GBB

GBB.Version=GetAddOnMetadata(TOCNAME, "Version") 
GBB.Title=GetAddOnMetadata(TOCNAME, "Title") 
GBB.Icon= "Interface\\Icons\\spell_holy_prayerofshadowprotection"
--"Interface\\FriendsFrame\\Battlenet-Portrait"
GBB.MiniIcon= "Interface\\Icons\\spell_holy_prayerofshadowprotection"
--"Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon"
GBB.FriendIcon="Interface\\LootFrame\\toast-star"
--"Interface\\COMMON\\FavoritesIcon"
GBB.GuildIcon="Interface\\COMMON\\Indicator-Green"
GBB.PastPlayerIcon="Interface\\COMMON\\Indicator-Yellow"
GBB.TxtEscapePicture="|T%s:0|t"
--"Interface\\Calendar\\MeetingIcon"
--"Interface\\Icons\\spell_holy_prayerofshadowprotection"
GBB.NotifySound=1210


local PartyChangeEvent={ "GROUP_JOINED", "GROUP_ROSTER_UPDATE", "RAID_ROSTER_UPDATE","GROUP_LEFT","LOADING_SCREEN_DISABLED","PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD"}

-------------------------------------------------------------------------------------

-- GBB.RequestForPopup

-- GBB.DataBrockerInitalized
GBB.MSGPREFIX="LFG Bulletin Board: "
GBB.TAGBAD="---"
GBB.TAGSEARCH="+++"

GBB.Initalized = false
GBB.ElapsedSinceListUpdate = 0
GBB.ElapsedSinceLfgUpdate = 0
GBB.LFG_Timer=0
GBB.LFG_UPDATETIME=10
GBB.TBCDUNGEONBREAK = 50
GBB.WOTLKDUNGEONBREAK = 81
GBB.DUNGEONBREAK = 28
GBB.COMBINEMSGTIMER=10
GBB.MAXCOMPACTWIDTH=350
GBB.ShouldReset = false

local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
-- Tools
-------------------------------------------------------------------------------------

function GBB.AllowInInstance()
	local inInstance, instanceType = IsInInstance()
	if instanceType=="arena" then
		instanceType="pvp"
	elseif instanceType=="scenario" then
		instanceType="party"
	end
	return GBB.DB["NotfiyIn"..instanceType]
end

function GBB.Split(msg)
	return GBB.Tool.Split( string.gsub(string.lower(msg), "[%p%s%c]", "+") , "+")
end

---Splits a message into multiple parts, removing punctuation and whitespace.
---@param msg string The message to split.
---@return string[] A table of strings, each representing a word from the message.
function GBB.GetMessageWordList(msg)
	local message = string.lower(msg)
	local validatedMessage = string.gsub(message, "[´`]","'")
	validatedMessage =  string.gsub(validatedMessage,"''","'")
	local strippedMessage = GBB.Tool.stripChars(validatedMessage)
	
	local results = GBB.Tool.iMerge( 	
		GBB.Tool.Split( string.gsub(message, "[%p%s%c]", "+") , "+"),
		GBB.Tool.Split( string.gsub(message, "[%p%c]", "") , " "),
		-- GBB.Tool.Split( string.gsub(message, "[%c%s]", "+") , "+"), 
		GBB.Tool.Split( string.gsub(message, "[%p%s%c%d]", "+") , "+"),
		
		GBB.Tool.Split( string.gsub(validatedMessage, "[%p%s%c]", "+") , "+"),
		GBB.Tool.Split( string.gsub(validatedMessage, "[%p%c]", "") , " "),
		-- GBB.Tool.Split( string.gsub(validatedMessage, "[%c%s]", "+") , "+"), 
		GBB.Tool.Split( string.gsub(validatedMessage, "[%p%s%c%d]", "+") , "+"),
		
		GBB.Tool.Split( string.gsub(strippedMessage, "[%p%s%c]", "+") , "+"),
		GBB.Tool.Split( string.gsub(strippedMessage, "[%p%c]", "") , " "),
		-- GBB.Tool.Split( string.gsub(stippedMessage, "[%c%s]", "+") , "+"), 
		GBB.Tool.Split( string.gsub(strippedMessage, "[%p%s%c%d]", "+") , "+")
	);
	local additionalResults = {}
	
	--[[
	local lastTag
	for it,tag in ipairs(GBB.Tool.Split( string.gsub(msg, "[%p%c%s]", "+") , "+")) do
		
		if lastTag~=nil then
			tinsert(additionalResults, lastTag.."X"..tag)
		end
		lastTag=tag
	end
	]]--
	
	-- split words with suffixes and add them to the results
	for _, word in ipairs(results) do
		for _, suffix in ipairs(GBB.suffixTags) do
			local suffixLength = string.len(suffix)
			--trim end of word with the length of current suffix
			local wordEnding = word:sub(-suffixLength)
			if word ~= suffix 
			and wordEnding == suffix 
			then				
				local baseWord = word:sub(1, -suffixLength - 1)
				tinsert(additionalResults, baseWord);
				tinsert(additionalResults, suffix)
			end
		end
	end
	
	results=GBB.Tool.iMerge(results,additionalResults)
	--[[for it,tag in ipairs(result) do
		if string.len(tag)==1 then
			result[it]=nil
		end
	end
	]]--
	
	return results	
end

function GBB.LevelRange(dungeon,short)
	if short then 
		if GBB.dungeonLevel[dungeon][1]>0 then
			return string.format(GBB.L["msgLevelRangeShort"],GBB.dungeonLevel[dungeon][1],GBB.dungeonLevel[dungeon][2])
		end
	elseif GBB.dungeonLevel[dungeon][1]>0 then
		return string.format(GBB.L["msgLevelRange"],GBB.dungeonLevel[dungeon][1],GBB.dungeonLevel[dungeon][2])
	end
	return ""
end

---@return boolean `true` if the dungeon should be tracked on bulletin board, `false` otherwise.
function GBB.FilterDungeon(dungeon, isHeroic, isRaid)
	if dungeon == nil then return false end
	if isHeroic == nil then isHeroic = false end
	if isRaid == nil then isRaid = false end

	-- If the user is within the level range, or if they're max level and it's heroic.
	local inLevelRange = (not isHeroic and GBB.dungeonLevel[dungeon][1] <= GBB.UserLevel and GBB.UserLevel <= GBB.dungeonLevel[dungeon][2]) or (isHeroic and GBB.UserLevel == 80)

	-- return `false` if not checked in preferences
	if not GBB.DBChar["FilterDungeon"..dungeon] then return false end;
	
	-- return `false` if not prefferd difficulty
	local showHeroicOnly = GBB.DBChar["HeroicOnly"] == true
	local showNormalOnly = GBB.DBChar["NormalOnly"] == true
	if showHeroicOnly and isHeroic == false then return false end;
	if showNormalOnly and isHeroic then return false end;

	-- return `false` if not in level range specified
	if GBB.DBChar.FilterLevel and not inLevelRange then return false end;

	-- return `true` otherwise
	return true;
end

function GBB.formatTime(sec) 
	return string.format(GBB.L["msgTimeFormat"],math.floor(sec/60), sec %60)
end

function GBB.PhraseChannelList(...)
	local t={}
	for i=1,select("#", ...),3 do
		t[select(i, ...)]= {name=select(i+1, ...),hidden=select(i+2, ...) }
	end
	t[20]={name=GBB.L.GuildChannel,hidden=true}
	return t
end

local addonLinkStub = "\124Haddon:%s:%s\124h[%s]\124h\124r"
local gotoSettingsArg1 = "GBB_GOTO_CHAT_SETTINGS"
local linkDisplayStr = (function() 
	local str = { -- todo move to Localization.lua
        ["enUS"] = "Click Here to Reorder Chat Channels!",
        ["deDE"] = "Klicken Sie hier, um die Chat-Kanäle neu zu ordnen!",
        ["esES"] = "¡Haz clic aquí para reordenar los canales del chat!",
        ["esMX"] = "¡Haz clic aquí para reordenar los canales de chat!",
        ["frFR"] = "Cliquez ici pour réorganiser les canaux de discussion !",
        ["koKR"] = "여기를 클릭하여 채팅 채널을 재정렬하십시오!",
        ["ptBR"] = "Clique aqui para reordenar os canais de bate-papo!",
        ["ruRU"] = "Щелкните здесь, чтобы изменить порядок каналов чата!",
        ["zhCN"] = "点击此处重新排序聊天频道！",
        ["zhTW"] = "點擊這裡重新排序聊天頻道！",
    }
	return str[GetLocale()] or str["enUS"]
end)()
function GBB.JoinLFG()
	if GBB.Initalized and not GBB.LFG_Successfulljoined then 
		if GBB.L["lfg_channel"] and GBB.L["lfg_channel"] ~= "" then
			local id, _ = GetChannelName(GBB.L["lfg_channel"])
			if id and id > 0 then
				GBB.LFG_Successfulljoined = true
			else
				-- related issue: #247, wait for player to join any game channel before joining lfg channel.
				-- note: this will still join LFG in `/1` if the slot is empty. 
				local general, localDefense = EnumerateServerChannels()
				local generalID = general and GetChannelName(general)
				local tradeOrDefenseID = localDefense and GetChannelName(localDefense) -- trade in main cities.
				if (generalID and generalID > 0) or (tradeOrDefenseID and tradeOrDefenseID > 0) then
					local numChannelsJoined = C_ChatInfo.GetNumActiveChannels() or 0
					local nextAvailableChannelIndex = numChannelsJoined + 1
					for i = 1, numChannelsJoined do
						if not C_ChatInfo.GetChannelInfoFromIdentifier(i) then
							nextAvailableChannelIndex = i
							break
						end
					end
					local _, name 
					if nextAvailableChannelIndex > 1 then 
						_, name = JoinPermanentChannel(GBB.L["lfg_channel"])
					else
						_, name = JoinTemporaryChannel(GBB.L["lfg_channel"]);
					end
					local info = C_ChatInfo.GetChannelInfoFromIdentifier(name or "")
					if info then
						-- notify user that the addon has joined the channel.
						DEFAULT_CHAT_FRAME:AddMessage(
							GBB.MSGPREFIX..CHAT_YOU_JOINED_NOTICE:format(
								info.localID,
								("%d. %s"):format(info.localID, info.name)
							), Chat_GetChannelColor(ChatTypeInfo["CHANNEL"])
						)
					else
						-- notify user that the addon failed to join the channel.
						DEFAULT_CHAT_FRAME:AddMessage(
							GBB.MSGPREFIX..CHAT_INVALID_NAME_NOTICE..": ".. GBB.L["lfg_channel"],
							Chat_GetChannelColor(ChatTypeInfo["CHANNEL"])
						)
					end
					if generalID ~= 1 then -- prompt user to reorder chat channels
						local link = WrapTextInColorCode(
							addonLinkStub:format(TOCNAME, gotoSettingsArg1, linkDisplayStr), 
							CreateColor(Chat_GetChannelColor(ChatTypeInfo["SYSTEM"])):GenerateHexColor()
						)
						DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..link)
					end
				end
			end
		else
			GBB.LFG_Successfulljoined=true
		end
	end
end
hooksecurefunc("SetItemRef", function(link)
	local linkType, addon, arg1 = strsplit(":", link)
	if linkType == "addon" and addon == TOCNAME then
		if arg1 == gotoSettingsArg1 then
			ShowUIPanel(ChatConfigFrame)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
			ChatConfigFrame.ChatTabManager:UpdateSelection(1); -- General tab
			ChatConfigCategoryFrameButton3:Click() -- Channels category
		end
	end
end)

function GBB.BtnSelectChannel()
	if UIDROPDOWNMENU_OPEN_MENU ~=  GBB.FramePullDownChannel then 
		UIDropDownMenu_Initialize( GBB.FramePullDownChannel, GBB.CreateChannelPulldown, "MENU")
	end
	ToggleDropDownMenu(nil, nil,  GBB.FramePullDownChannel, GroupBulletinBoardFrameSelectChannel, 0,0)
end

--gui
-------------------------------------------------------------------------------------

function GBB.SaveAnchors()
	GBB.DB.X = GroupBulletinBoardFrame:GetLeft()
	GBB.DB.Y = GroupBulletinBoardFrame:GetTop()
	GBB.DB.Width = GroupBulletinBoardFrame:GetWidth()
	GBB.DB.Height = GroupBulletinBoardFrame:GetHeight()
end

function GBB.ResetWindow()
	GroupBulletinBoardFrame:ClearAllPoints()
	GroupBulletinBoardFrame:SetPoint("Center", UIParent, "Center", 0, 0)
	GroupBulletinBoardFrame:SetSize(GroupBulletinBoardFrame:GetResizeBounds())
	GBB.SaveAnchors()
	GBB.ResizeFrameList()
end

function GBB.ResizeFrameList()
	local w
	GroupBulletinBoardFrame_ScrollFrame:SetHeight(GroupBulletinBoardFrame:GetHeight() -55-25 )
	w=GroupBulletinBoardFrame:GetWidth() -20-10-10
	GroupBulletinBoardFrame_ScrollFrame:SetWidth( w )
	GroupBulletinBoardFrame_ScrollChildFrame:SetWidth( w )

	GroupBulletinBoardFrame_LfgFrame:SetHeight(GroupBulletinBoardFrame:GetHeight() -55-25 )
	w=GroupBulletinBoardFrame:GetWidth() -20-10-10
	GroupBulletinBoardFrame_LfgFrame:SetWidth( w )
	GroupBulletinBoardFrame_LfgChildFrame:SetWidth( w )
end

function GBB.ShowWindow()
	local version, build, date, tocversion = GetBuildInfo()

    -- Check if classic or not
    if string.sub(version, 1, 2) ~= "1." then
		GBB.UpdateLfgTool()
		GBB.UpdateGroupList()
    end
	GroupBulletinBoardFrame:Show()
	GBB.ClearNeeded=true	 
	GBB.UpdateList()
	GBB.ResizeFrameList()
end

function GBB.HideWindow ()
	GroupBulletinBoardFrame:Hide()
end

function GBB.ToggleWindow()
	if GroupBulletinBoardFrame:IsVisible() then
		GBB.HideWindow()
	else
		GBB.ShowWindow()
	end
end

function GBB.BtnClose()
	GBB.HideWindow()
end

function GBB.BtnSettings(button )
	if button == "LeftButton" then
		GBB.OptionsBuilder.OpenCategoryPanel(1)
	else
		GBB.Popup_Minimap("cursor",false)
		--GBB.Options.Open(1)
	end
end

function GBB.BtnRefresh(button)
	GBB.UpdateLfgTool()
end


--Tag Lists
---------------------------------------------------

---Sets the `GBB.tagList` table, specified by locale. 
---@param loc string The locale to create the tag list for.
function GBB.CreateTagListLOC(loc)
	for _,tag in pairs(GBB.badTagsLoc[loc]) do
		if GBB.DB.OnDebug and GBB.tagList[tag]~=nil then
			print(GBB.MSGPREFIX.."DoubleTag:"..tag.." - "..GBB.tagList[tag].." / "..GBB.TAGBAD)
		end	
		GBB.tagList[tag]=GBB.TAGBAD		
	end
	
	for _, tag in pairs(GBB.searchTagsLoc[loc]) do
		if GBB.DB.OnDebug and GBB.tagList[tag]~=nil then
			print(GBB.MSGPREFIX.."DoubleTag:"..tag.." - "..GBB.tagList[tag].." / "..GBB.TAGSEARCH)
		end
		GBB.tagList[tag]=GBB.TAGSEARCH		
	end
	
	for _, tag in pairs(GBB.suffixTagsLoc[loc]) do
		if GBB.DB.OnDebug and tContains(GBB.suffixTags,tag) then
			print(GBB.MSGPREFIX.."DoubleSuffix:"..tag)
		end	
		
		if not tContains(GBB.suffixTags,tag) then 
			tinsert(GBB.suffixTags,tag) 
		end
	end
	
	for dungeonKey, tagList in pairs(GBB.dungeonTagsLoc[loc]) do
		---@cast tagList string[]
		---@cast dungeonKey string
		for _, tag in pairs(tagList) do
			if GBB.DB.OnDebug and GBB.tagList[tag]~=nil then
				print(GBB.MSGPREFIX.."DoubleTag:"..tag.." - "..GBB.tagList[tag].." / "..dungeonKey)
			end
			GBB.tagList[tag] = dungeonKey
		end
	end

	for _, tag in pairs(GBB.heroicTagsLoc[loc]) do
		GBB.HeroicKeywords[tag] = 1
	end
end

function GBB.CreateTagList ()
	GBB.tagList={}
	GBB.suffixTags={}
	GBB.HeroicKeywords={}

	if GBB.DB.TagsEnglish then
		GBB.CreateTagListLOC("enGB")
	end
	if GBB.DB.TagsGerman then
		--German tags need english!
		if GBB.DB.TagsEnglish==false then
			GBB.CreateTagListLOC("enGB")
		end	
		GBB.CreateTagListLOC("deDE")
	end
	if GBB.DB.TagsRussian then
		GBB.CreateTagListLOC("ruRU")
	end
	if GBB.DB.TagsFrench then
		GBB.CreateTagListLOC("frFR")
	end
	if GBB.DB.TagsZhtw then
		GBB.CreateTagListLOC("zhTW")
	end
	if GBB.DB.TagsZhcn then
		GBB.CreateTagListLOC("zhCN")
	end
	if GBB.DB.TagsPortuguese then
		GBB.CreateTagListLOC("ptBR")
	end
	if GBB.DB.TagsSpanish then
		GBB.CreateTagListLOC("esES")
	end
	if GBB.DB.TagsCustom then
		GBB.searchTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Search)
		GBB.badTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Bad)
		GBB.suffixTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Suffix)
		GBB.heroicTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Heroic)
		
		GBB.dungeonTagsLoc["custom"]={}
		for index=1,GBB.WOTLKMAXDUNGEON do
			GBB.dungeonTagsLoc["custom"][GBB.dungeonSort[index]]= GBB.Split(GBB.DB.Custom[GBB.dungeonSort[index]])
		end
		
		GBB.CreateTagListLOC("custom")
	end
end


--Initalize / Event
-------------------------------------------------------------------------------------

local function hooked_createTooltip(self)
	local name, unit = self:GetUnit()
	if (name) and (unit) and UnitIsPlayer(unit) then
	
		if GBB.DB.EnableGuild then
			local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo(unit)
			if guildName and guildRankName then
				self:AddLine(GBB.Tool.RGBtoEscape(GBB.DB.ColorGuild).."< "..guildName.." / "..guildRankName.." >")
			end
		end

		if GBB.DB.EnableGroup and GBB.GroupTrans and GBB.GroupTrans[name] then
			local inInstance, instanceType = IsInInstance()
		
			if instanceType=="none" then
				local entry=GBB.GroupTrans[name] 
				
				self:AddLine(" ")					
				self:AddLine(GBB.L.msgLastSeen)					
				if entry.dungeon then
					self:AddLine(entry.dungeon)
				end
				if entry.Note then
					self:AddLine(entry.Note)
				end
				self:AddLine(SecondsToTime(GetServerTime()-entry.lastSeen))
				self:Show()	
			end
		end
	end
end

function GBB.Popup_Minimap(frame,notminimap)
	local txt="nil"
	if type(frame)=="table" then txt=frame:GetName() or "nil" end
	if not GBB.PopupDynamic:Wipe(txt..(notminimap and "notminimap" or "minimap")) then
		return
	end

	GBB.PopupDynamic:AddItem(GBB.L["HeaderSettings"],false, GBB.OptionsBuilder.OpenCategoryPanel, 1)
	
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(GBB.L["CboxFilterTravel"],false,GBB.DBChar,"FilterDungeonTRAVEL")
	
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(GBB.L["CboxNotifyChat"],false,GBB.DB,"NotifyChat")
	GBB.PopupDynamic:AddItem(GBB.L["CboxNotifySound"],false,GBB.DB,"NotifySound")
	
	if notminimap~=false then 
		GBB.PopupDynamic:AddItem("",true)
		GBB.PopupDynamic:AddItem(GBB.L["CboxLockMinimapButton"],false,GBB.DB.MinimapButton,"lock")
		GBB.PopupDynamic:AddItem(GBB.L["CboxLockMinimapButtonDistance"],false,GBB.DB.MinimapButton,"lockDistance")
	end
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(GBB.L["BtnCancel"],false)
		
	GBB.PopupDynamic:Show(frame,0,0)
end

function GBB.Init()
	GroupBulletinBoardFrame:SetResizeBounds(400,170)	
	GroupBulletinBoardFrame:SetClampedToScreen(true)
	GBB.UserLevel=UnitLevel("player")
	GBB.UserName=(UnitFullName("player"))
	GBB.ServerName=GetRealmName()

	-- Initalize options
	if not GroupBulletinBoardDB then GroupBulletinBoardDB = {} end -- fresh DB
	if not GroupBulletinBoardDBChar then GroupBulletinBoardDBChar = {} end -- fresh DB
	
	GBB.DB=GroupBulletinBoardDB
	GBB.DBChar=GroupBulletinBoardDBChar
	
	-- Needed for the people who it got initialized as a table not a string
	if (type(GBB.DB.FontSize) == "table") then
    		GBB.DB.FontSize = nil
	end
	
	if not GBB.DBChar.channel then GBB.DBChar.channel = {} end
	if not GBB.DB.MinimapButton then GBB.DB.MinimapButton={} end
	if not GBB.DB.Custom then GBB.DB.Custom={} end
	if not GBB.DB.CustomLocales then GBB.DB.CustomLocales={} end
	if not GBB.DB.CustomLocalesDungeon then GBB.DB.CustomLocalesDungeon={} end
	if not GBB.DB.FontSize then GBB.DB.FontSize = "GameFontNormal" end
	if not GBB.DB.DisplayLFG then GBB.DB.DisplayLFG = false end
	GBB.DB.Server=nil -- old settings
	
	if GBB.DB.OnDebug == nil then GBB.DB.OnDebug=false end
	GBB.DB.widthNames=93 
	GBB.DB.widthTimes=50 
	GBB.DBChar["FilterDungeonDEBUG"]=true -- Fake Option
	GBB.DBChar["FilterDungeonBAD"]=true -- Fake Option
	
	--delete outdated
	GBB.DB.showminimapbutton=nil
	GBB.DB.minimapPos=nil
	
	GBB.InitializeCustomFilters();
	
	-- Get localize and Dungeon-Information
	GBB.L = GBB.LocalizationInit()	
	GBB.dungeonNames = GBB.GetDungeonNames()
	-- Add custom categories to `dungeonNames`
	MergeTable(GBB.dungeonNames, GBB.GetCustomFilterNames());
	-- add custom categories to levels table
	MergeTable(GBB.dungeonLevel, GBB.GetAllCustomFilterLevels());
	-- add custom categories to `dungeonSort` (adds internally)
	local additionalCategories = GBB.GetCustomFilterKeys();
	GBB.dungeonSort = GBB.GetDungeonSort(additionalCategories);
	GBB.RaidList = GBB.GetRaids()

	-- Add tags for custom categories into `dungeonTagsLoc`. 
	-- Must do before the call to `GBB.CreateTagList()` below
	GBB.SyncCustomFilterTags(GBB.dungeonTagsLoc);

	-- Reset Request-List
	GBB.RequestList={}
	GBB.LfgRequestList={}
	GBB.FramesEntries={}
	GBB.LfgFramesEntries = {}

	GBB.FoldedDungeons={}
	GBB.LfgFoldedDungeons = {}
	
	-- Timer-Stuff
	GBB.MAXTIME=time() +60*60*24*365 --add a year!
	
	GBB.ClearNeeded=true
	GBB.ClearTimer=GBB.MAXTIME	
	
	GBB.LFG_Timer=time()+GBB.LFG_UPDATETIME
	GBB.LFG_Successfulljoined=false
	
	GBB.AnnounceInit()
	if GBB.DB.DisplayLFG == false then
		GroupBulletinBoardFrameAnnounce:Hide()
		GroupBulletinBoardFrameAnnounceMsg:Hide()
		GroupBulletinBoardFrameSelectChannel:Hide()
	end

	local x, y, w, h = GBB.DB.X, GBB.DB.Y, GBB.DB.Width, GBB.DB.Height
	if not x or not y or not w or not h then
		GBB.SaveAnchors()
	else
		GroupBulletinBoardFrame:ClearAllPoints()
		GroupBulletinBoardFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		GroupBulletinBoardFrame:SetWidth(w)
		GroupBulletinBoardFrame:SetHeight(h)		

	end
		
	-- slash command
	local function doDBSet(DB,var,value)
		if value==nil then
			DB[var]= not DB[var]
		elseif tContains({"true","1","enable"},value) then
			DB[var]=true
		elseif tContains({"false","0","disable"},value) then
			DB[var]=false
		end
		DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX.."Set "..var.." to "..tostring(DB[var]))
		GBB.OptionsUpdate()
	end
	
	GBB.Tool.SlashCommand({"/gbb", "/groupbulletinboard"},{
		{"notify","",{
				{"chat","",{
						{"%",GBB.L["CboxNotifyChat"],doDBSet,GBB.DB,"NotifyChat"}
					}
				},
					
				{"sound","",{
						{"%",GBB.L["CboxNotifySound"],doDBSet,GBB.DB,"NotifySound"}
					}
				},
			},
		},
		{"debug","",{
				{"%",GBB.L["CboxOnDebug"],doDBSet,GBB.DB,"OnDebug"}
			},
		},
		{"reset",GBB.L["SlashReset"],function()
				GBB.ResetWindow()
				GBB.ShowWindow()
			end},
		{{"config","setup","options"},GBB.L["SlashConfig"],GBB.OptionsBuilder.OpenCategoryPanel,1},
		{"about",GBB.L["SlashAbout"],GBB.OptionsBuilder.OpenCategoryPanel,7},
		{"",GBB.L["SlashDefault"],GBB.ToggleWindow},
		{"chat","",{
			{{"organize", "clean"},GBB.L["SlashChatOrganizer"],function()
				GBB.InsertChat()
			end},
		},
	},
		})
		
	-- Create options and initalize!
	GBB.OptionsInit()
		
	GBB.CreateTagList()		

	GBB.MinimapButton.Init(GBB.DB.MinimapButton, GBB.Icon,
		function(self,button) --onclick
			if button=="LeftButton" then 
				GBB.ToggleWindow()
			else
				GBB.Popup_Minimap(self.button,true)
				--GBB.Options.Open(2)
			end
		end,
		GBB.Title
	)	
	
	GBB.FramePullDownChannel=CreateFrame("Frame", "GBB.PullDownMenu", UIParent, "UIDropDownMenuTemplate")
	GroupBulletinBoardFrameTitle:SetFontObject(GBB.DB.FontSize)
	if GBB.DB.AnnounceChannel == nil then
		if GBB.L["lfg_channel"] ~= "" then
			GBB.DB.AnnounceChannel = GBB.L["lfg_channel"]
		else
			_, GBB.DB.AnnounceChannel = GetChannelList()
		end
	end
	
	---@type EditBox # making this local isnt required, just here for the luals linter
	local GroupBulletinBoardFrameResultsFilter = _G["GroupBulletinBoardFrameResultsFilter"];
	GroupBulletinBoardFrameResultsFilter.filterPatterns = { };
	GroupBulletinBoardFrameResultsFilter:SetFontObject(GBB.DB.FontSize);
	GroupBulletinBoardFrameResultsFilter:SetTextColor(1, 1, 1, 1);
	GroupBulletinBoardFrameResultsFilter:HookScript("OnTextChanged", function(self) 
		GBB.UpdateList()
		-- cache filters early
		self.filterPatterns = { };
		local filterText = self:GetText()
		if filterText == "" or not filterText then return end -- filter is off
		
		for pattern in string.gmatch(filterText, "([^, ]+)") do
			table.insert(self.filterPatterns, pattern);
		end
		-- i think its possible to increase performance a bit more by caching the lists associated with the last N searches to reduce calls to string.gmatch (specially when deleting text).
	end);
	
	---@return string[] # returns empty table if no text is set in editbox
	function GroupBulletinBoardFrameResultsFilter:GetFilters() 
		return self.filterPatterns
	end

	GroupBulletinBoardFrameSelectChannel:SetText(GBB.DB.AnnounceChannel)

	GBB.ResizeFrameList()
	
	if GBB.DB.EscapeQuit then 
		tinsert(UISpecialFrames, GroupBulletinBoardFrame:GetName()) --enable ESC-Key to close
	end
	
	GBB.Tool.EnableSize(GroupBulletinBoardFrame,8,nil,function()	
		GBB.ResizeFrameList()
		GBB.SaveAnchors()
		GBB.UpdateList()
		end
	)
	GBB.Tool.EnableMoving(GroupBulletinBoardFrame,GBB.SaveAnchors)
	
	GBB.PatternWho1=GBB.Tool.CreatePattern(WHO_LIST_FORMAT )
	GBB.PatternWho2=GBB.Tool.CreatePattern(WHO_LIST_GUILD_FORMAT )
	GBB.PatternOnline=GBB.Tool.CreatePattern(ERR_FRIEND_ONLINE_SS)
	GBB.RealLevel={}
	GBB.RealLevel[GBB.UserName]=GBB.UserLevel
	
	GroupBulletinBoardFrameTitle:SetText(string.format(GBB.TxtEscapePicture,GBB.MiniIcon).." ".. GBB.Title)
	
	GBB.Initalized=true
	
	GBB.PopupDynamic=GBB.Tool.CreatePopup(GBB.OptionsUpdate)
	GBB.InitGroupList()

	if isClassicEra then
		GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabRequest, GroupBulletinBoardFrame_ScrollFrame);
		
		-- GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabGroup, GroupBulletinBoardFrame_GroupFrame);
		GroupBulletinBoardFrame_GroupFrame:Hide()
		
		-- Group Finder doesnt exist in classic era
		GroupBulletinBoardFrame_LfgFrame:Hide()
	else -- cata client
		-- Hide all tabs except requests for the time being
		
		GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabRequest, GroupBulletinBoardFrame_ScrollFrame);

		-- GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabGroup, GroupBulletinBoardFrame_GroupFrame);
		GroupBulletinBoardFrame_GroupFrame:Hide()
		
		-- GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabLfg, GroupBulletinBoardFrame_LfgFrame);
		GroupBulletinBoardFrame_LfgFrame:Hide()
	end
	GBB.Tool.SelectTab(GroupBulletinBoardFrame,1)
	local enableGroupVar = GBB.OptionsBuilder.GetSavedVarHandle(GBB.DB, "EnableGroup")
	local refreshGroupTab = function(isEnabled) -- previously done in `GBB.OptionsUpdate()`
		if isEnabled then
			-- Shows all active tabs.
			GBB.Tool.TabShow(GroupBulletinBoardFrame)
		else -- note: only the request-list tab is currently active on cata & era.
			GBB.Tool.SelectTab(GroupBulletinBoardFrame, 1)
			-- hide the "Remember past group members" aka "EnableGroup" tab should be the last tab
			GBB.Tool.TabHide(GroupBulletinBoardFrame, isClassicEra and 2 or 3)
		end
	end
	enableGroupVar:AddUpdateHook(refreshGroupTab)
	refreshGroupTab(enableGroupVar:GetValue()) -- run once to match the set state.
	
	GBB.Tool.TabOnSelect(GroupBulletinBoardFrame,3,GBB.UpdateGroupList)
	GBB.Tool.TabOnSelect(GroupBulletinBoardFrame,2,GBB.UpdateLfgTool)
	
	GameTooltip:HookScript("OnTooltipSetUnit", hooked_createTooltip)
		
	print("|cFFFF1C1C Loaded: "..GetAddOnMetadata(TOCNAME, "Title") .." ".. GetAddOnMetadata(TOCNAME, "Version") .." by "..GetAddOnMetadata(TOCNAME, "Author"))
end


-- 1"text", 2"playerName", 3"languageName", 4"channelName", 5"playerName2", 6"specialFlags", 7zoneChannelID, 8channelIndex, 9"channelBaseName", 10unused, 11lineID, 12"guid", 13bnSenderID, 14isMobile, 15isSubtitle, 16hideSenderInLetterbox, 17supressRaidIcons

local function Event_CHAT_MSG_SYSTEM(arg1)
	if not GBB.Initalized then return end

	local d,name,level,a1,a2,a3 = string.match(arg1,GBB.PatternWho2)
	if tonumber(a2)~=nil then level=a2 end
	if not name or not level then
		d,name,level,a1,a2,a3 = string.match(arg1,GBB.PatternWho1)
		if tonumber(a2)~=nil then level=a2 end
	end
	if name and level then
		level=tonumber(level) or 0
		GBB.RealLevel[name]=level
	else
		d,name=string.match(arg1,GBB.PatternOnline)
	end
	
	if GBB.DB.AdditionalInfo and name then	
		local class
		local info=""
		local symbol=""
		if not level then
			info=" "
		end

		local friend=C_FriendList.GetFriendInfo(name)
		if friend then
			level=friend.level or level
			if friend.className and GBB.Tool.NameToClass[friend.className] then
				class=GBB.Tool.NameToClass[friend.className]
			end
			if friend.notes then
				info=" - "..friend.notes	
			end
			symbol="|cffecda90*|r"			
		end
		
		if GBB.DB.EnableGroup and GBB.GroupTrans and GBB.GroupTrans[name] then
			local entry=GBB.GroupTrans[name]
			class=entry.class
			
			if entry.dungeon then
				info=info.." - "..entry.dungeon
			end
			info=info.." - "..SecondsToTime(GetServerTime()-entry.lastSeen)
						
			if entry.Note then
				info=info.." - "..entry.Note
			end
		end
		
		local index=GBB.Tool.GuildNameToIndex(name)
		if index then 
			local gname, rankName, rankIndex, glevel, classDisplayName, zone, publicNote, officerNote, isOnline, status, gclass, achievementPoints, achievementRank, isMobile, canSoR, repStanding, GUID = GetGuildRosterInfo(index)
			class=gclass
			level=glevel
			symbol=symbol.."|cffb4fe2c•|r"
			info=" |cffb4fe2c<"..rankName..">|r"..info
			if publicNote and publicNote~="" then
				info=info.." - "..publicNote
			end
			if officerNote and officerNote~="" then
				info=info.." - "..officerNote
			end
		end
		
		if info~="" then
			local txt
			if class and class~="" then 
				txt="|Hplayer:"..name.."|h"
					..(GBB.Tool.GetClassIcon(class) or "")
					.."|c"..GBB.Tool.ClassColor[class].colorStr .. name.."|r"
					..symbol.."|h";
			else
				txt="|Hplayer:"..name.."|h"..name..symbol.."|h"
			end
						
			if level then
				txt=txt.." ("..level..")"
			end
			
			DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..txt..info,GBB.DB.PlayerNoteColor.r,GBB.DB.PlayerNoteColor.g,GBB.DB.PlayerNoteColor.b)		
		end
	end	
end

local function Event_CHAT_MSG_CHANNEL(msg,name,_3,_4,_5,_6,_7,channelID,channel,_10,_11,guid)
	if not GBB.Initalized then return end
	--print("channel:"..tostring(channelID))
	if GBB.DBChar and GBB.DBChar.channel and GBB.DBChar.channel[channelID] then
		GBB.ParseMessage(msg,name,guid,channel)
	end
end

local function Event_GuildMessage(msg,name,_3,_4,_5,_6,_7,channelID,channel,_10,_11,guid)
	Event_CHAT_MSG_CHANNEL(msg,name,_3,_4,_5,_6,_7,20,GBB.L.GuildChannel,_10,_11,guid)
end


local function Event_ADDON_LOADED(arg1)
	if arg1 == TOCNAME then
		GBB.Init()
	end
	GBB.Tool.AddDataBrocker(
		GBB.MiniIcon,
		function(clickedframe, button)
			if button=="LeftButton" then 
				GBB.ToggleWindow()
			else
				GBB.Popup_Minimap(clickedframe,false)
				--GBB.Options.Open(2)
			end
		end
	)
end

function GBB.OnLoad()	
	GBB.Tool.RegisterEvent("ADDON_LOADED",Event_ADDON_LOADED)
	GBB.Tool.RegisterEvent("CHAT_MSG_SYSTEM",Event_CHAT_MSG_SYSTEM)
	GBB.Tool.RegisterEvent("CHAT_MSG_CHANNEL",Event_CHAT_MSG_CHANNEL)
	GBB.Tool.RegisterEvent("CHAT_MSG_GUILD",Event_GuildMessage)
	GBB.Tool.RegisterEvent("CHAT_MSG_OFFICER",Event_GuildMessage)
	
	for i,event in ipairs(PartyChangeEvent) do
		GBB.Tool.RegisterEvent(event,GBB.UpdateGroupList)
	end
	
	GBB.Tool.OnUpdate(GBB.OnUpdate)
end

function GBB.OnSizeChanged()
	if GBB.Initalized==true then
		GBB.ResizeFrameList()
	end
end

function GBB.OnUpdate(elapsed)
	if GBB.Initalized==true then
		if GBB.LFG_Timer<time() and GBB.LFG_Successfulljoined==false then
			GBB.JoinLFG()
			GBB.LFG_Timer=time()+GBB.LFG_UPDATETIME
		end

		if GBB.ElapsedSinceListUpdate > 1 then
			if GBB.Tool.GetSelectedTab(GroupBulletinBoardFrame)==1 then
				GBB.UpdateList()
			elseif  GBB.Tool.GetSelectedTab(GroupBulletinBoardFrame)==2 then
				GBB.UpdateLfgToolNoSearch()
			end
				
			GBB.ElapsedSinceListUpdate = 0;
		else
			GBB.ElapsedSinceListUpdate = GBB.ElapsedSinceListUpdate + elapsed;
		end;

		if GBB.ElapsedSinceLfgUpdate > 18 and GBB.Tool.GetSelectedTab(GroupBulletinBoardFrame)==2 and GroupBulletinBoardFrame:IsVisible() then
			-- LFGListFrame.SearchPanel.RefreshButton:Click() -- hwevent protected
			GBB.UpdateLfgTool()
			GBB.ElapsedSinceLfgUpdate = 0
		else
			GBB.ElapsedSinceLfgUpdate = GBB.ElapsedSinceLfgUpdate + elapsed
		end
	end
end

