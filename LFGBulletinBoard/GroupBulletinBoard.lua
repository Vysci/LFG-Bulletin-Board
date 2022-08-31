local TOCNAME,GBB=...

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
GBB.MSGPREFIX="GBB: "
GBB.TAGBAD="---"
GBB.TAGSEARCH="+++"

GBB.Initalized = false
GBB.ElapsedSinceListUpdate = 0
GBB.LFG_Timer=0
GBB.LFG_UPDATETIME=10
GBB.TBCDUNGEONBREAK = 57
GBB.DUNGEONBREAK = 25
GBB.COMBINEMSGTIMER=10
GBB.MAXCOMPACTWIDTH=350

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
function GBB.SplitNoNb(msg)
	local msgOrg=string.lower(msg)
	msg=string.gsub(string.lower(msg), "[´`]","'")
	msg=string.gsub(msg,"''","'")
	local msg2=GBB.Tool.stripChars(msg)
	
	local result= GBB.Tool.iMerge( 	
								GBB.Tool.Split( string.gsub(msgOrg, "[%p%s%c]", "+") , "+"),
								GBB.Tool.Split( string.gsub(msgOrg, "[%p%c]", "") , " "),
								-- GBB.Tool.Split( string.gsub(msgOrg, "[%c%s]", "+") , "+"), 
								GBB.Tool.Split( string.gsub(msgOrg, "[%p%s%c%d]", "+") , "+"),
								
								GBB.Tool.Split( string.gsub(msg, "[%p%s%c]", "+") , "+"),
								GBB.Tool.Split( string.gsub(msg, "[%p%c]", "") , " "),
								-- GBB.Tool.Split( string.gsub(msg, "[%c%s]", "+") , "+"), 
								GBB.Tool.Split( string.gsub(msg, "[%p%s%c%d]", "+") , "+"),
								
								GBB.Tool.Split( string.gsub(msg2, "[%p%s%c]", "+") , "+"),
								GBB.Tool.Split( string.gsub(msg2, "[%p%c]", "") , " "),
								-- GBB.Tool.Split( string.gsub(msg2, "[%c%s]", "+") , "+"), 
								GBB.Tool.Split( string.gsub(msg2, "[%p%s%c%d]", "+") , "+")
								
								)
	local add={}
	
	--[[
	local lastTag
	for it,tag in ipairs(GBB.Tool.Split( string.gsub(msg, "[%p%c%s]", "+") , "+")) do
		
		if lastTag~=nil then
			tinsert(add,lastTag.."X"..tag)
		end
		lastTag=tag
	end
	]]--
	
	for it,tag in ipairs(result) do		
		-- lastTag=tag
		for is,suffix in ipairs(GBB.suffixTags) do
			if tag~=suffix and string.sub(tag,-string.len(suffix))==suffix then				
				tinsert(add,string.sub(tag,1,-string.len(suffix)-1))
				tinsert(add,suffix)
			end
		end
	end
	
	result=GBB.Tool.iMerge(result,add)
	--[[for it,tag in ipairs(result) do
		if string.len(tag)==1 then
			result[it]=nil
		end
	end
	]]--
	
	return result	
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

function GBB.FilterDungeon(dungeon, isHeroic, isRaid)
	if dungeon == nil then return false end
	if isHeroic == nil then isHeroic = false end
	if isRaid == nil then isRaid = false end

	-- If the user is within the level range, or if they're max level and it's heroic.
	local inLevelRange = (not isHeroic and GBB.dungeonLevel[dungeon][1] <= GBB.UserLevel and GBB.UserLevel <= GBB.dungeonLevel[dungeon][2]) or (isHeroic and GBB.UserLevel == 70)
	
	return GBB.DBChar["FilterDungeon"..dungeon] and 
		(isRaid or ((GBB.DBChar["HeroicOnly"] == false or isHeroic) and (GBB.DBChar["NormalOnly"] == false or isHeroic == false))) and
		(GBB.DBChar.FilterLevel == false or inLevelRange)
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

function GBB.JoinLFG()
	if GBB.Initalized==true and GBB.LFG_Successfulljoined==false then 
		if GBB.L["lfg_channel"]~=nil and GBB.L["lfg_channel"]~="" then 
			local id,name=GetChannelName(GBB.L["lfg_channel"])
			if  id~=nil and id >0  then 
				--DEFAULT_CHAT_FRAME:AddMessage("Success join lfg-channel")
				GBB.LFG_Successfulljoined=true
			else
				--DEFAULT_CHAT_FRAME:AddMessage("try join lfg-channel")
				JoinChannelByName(GBB.L["lfg_channel"])
			end	
		else
			-- missing localization
			GBB.LFG_Successfulljoined=true
			--DEFAULT_CHAT_FRAME:AddMessage("Channel not definied for "..GetLocale())
		end
	end
end

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
	GroupBulletinBoardFrame:SetWidth(300)
	GroupBulletinBoardFrame:SetHeight(170)
	GBB.SaveAnchors()
	GBB.ResizeFrameList()
end

function GBB.ResizeFrameList()
	local w
	GroupBulletinBoardFrame_ScrollFrame:SetHeight(GroupBulletinBoardFrame:GetHeight() -55-25 )
	w=GroupBulletinBoardFrame:GetWidth() -20-10-10
	GroupBulletinBoardFrame_ScrollFrame:SetWidth( w )
	GroupBulletinBoardFrame_ScrollChildFrame:SetWidth( w )
end

function GBB.ShowWindow()
	GroupBulletinBoardFrame:Show()
	GBB.ClearNeeded=true	 
	GBB.UpdateList()
	GBB.UpdateGroupList()
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
		GBB.Options.Open(2)
	else
		GBB.Popup_Minimap("cursor",false)
		--GBB.Options.Open(1)
	end
end


--Tag Lists
-------------------------------------------------------------------------------------
function GBB.CreateTagListLOC(loc)
	for id,tag in pairs(GBB.badTagsLoc[loc]) do
		if GBB.DB.OnDebug and GBB.tagList[tag]~=nil then
			print(GBB.MSGPREFIX.."DoubleTag:"..tag.." - "..GBB.tagList[tag].." / "..GBB.TAGBAD)
		end		
		GBB.tagList[tag]=GBB.TAGBAD		
	end
	
	for id,tag in pairs(GBB.searchTagsLoc[loc]) do
		if GBB.DB.OnDebug and GBB.tagList[tag]~=nil then
			print(GBB.MSGPREFIX.."DoubleTag:"..tag.." - "..GBB.tagList[tag].." / "..GBB.TAGSEARCH)
		end
		GBB.tagList[tag]=GBB.TAGSEARCH		
	end
	
	for id,tag in pairs(GBB.suffixTagsLoc[loc]) do
		if GBB.DB.OnDebug and tContains(GBB.suffixTags,tag) then
			print(GBB.MSGPREFIX.."DoubleSuffix:"..tag)
		end	
		if tContains(GBB.suffixTags,tag)==false then tinsert(GBB.suffixTags,tag) end
	end
	
	for dungeon,tags in pairs(GBB.dungeonTagsLoc[loc]) do
		for id,tag in pairs(tags) do
			if GBB.DB.OnDebug and GBB.tagList[tag]~=nil then
				print(GBB.MSGPREFIX.."DoubleTag:"..tag.." - "..GBB.tagList[tag].." / "..dungeon)
			end
			GBB.tagList[tag]=dungeon
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
	if GBB.DB.TagsCustom then
		GBB.searchTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Search)
		GBB.badTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Bad)
		GBB.suffixTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Suffix)
		GBB.heroicTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Heroic)
		
		GBB.dungeonTagsLoc["custom"]={}
		for index=1,GBB.TBCMAXDUNGEON do
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

	GBB.PopupDynamic:AddItem(GBB.L["HeaderSettings"],false, GBB.Options.Open, 1)

	GBB.PopupDynamic:AddItem(GBB.L["TBCPanelFilter"], false, GBB.Options.Open, 2)


	GBB.PopupDynamic:AddItem(GBB.L["PanelAbout"], false, GBB.Options.Open, 6)
	
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
	GroupBulletinBoardFrame:SetMinResize(300,170)	
	
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
	
	-- Get localize and Dungeon-Information
	GBB.L = GBB.LocalizationInit()	
	GBB.dungeonNames = GBB.GetDungeonNames()
	GBB.RaidList = GBB.GetRaids()
	--GBB.dungeonLevel
	GBB.dungeonSort = GBB.GetDungeonSort()	

	-- Reset Request-List
	GBB.RequestList={}
	GBB.FramesEntries={}

	GBB.FoldedDungeons={}
	
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
		{{"config","setup","options"},GBB.L["SlashConfig"],GBB.Options.Open,1},
		{"about",GBB.L["SlashAbout"],GBB.Options.Open,6},
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
	GBB.Tool.AddTab(GroupBulletinBoardFrame,GBB.L.TabRequest,GroupBulletinBoardFrame_ScrollFrame)
	GBB.Tool.AddTab(GroupBulletinBoardFrame,GBB.L.TabGroup,GroupBulletinBoardFrame_GroupFrame)
	GBB.Tool.SelectTab(GroupBulletinBoardFrame,1)
	if GBB.DB.EnableGroup then
		GBB.Tool.TabShow(GroupBulletinBoardFrame)
	else		
		GBB.Tool.TabHide(GroupBulletinBoardFrame)
	end
	
	GBB.Tool.TabOnSelect(GroupBulletinBoardFrame,2,GBB.UpdateGroupList)
	
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
				txt="|Hplayer:"..name.."|h"..GBB.Tool.IconClass[class]..
				"|c"..GBB.Tool.ClassColor[class].colorStr ..
				name.."|r"..symbol.."|h"
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

		if GBB.ElapsedSinceListUpdate > 0.5 then
			if GroupBulletinBoardFrame:IsVisible() then
				GBB.UpdateList()
			end
			GBB.ElapsedSinceListUpdate = 0;
		else
			GBB.ElapsedSinceListUpdate = GBB.ElapsedSinceListUpdate + elapsed;
		end;
	end
end

