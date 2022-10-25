local 	TOCNAME,GBB=...

local MAXGROUP=500
local LastUpdateTime = time()

local function requestSort_TOP_TOTAL (a,b)
	--a=a or requestNil
	--b=b or requestNil
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
	--a=a or requestNil
	--b=b or requestNil
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
	--a=a or requestNil
	--b=b or requestNil
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
	--a=a or requestNil
	--b=b or requestNil
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

local function InviteRequestWithRole(name,dungeon)
	if not GBB.DB.InviteRole then GBB.DB.InviteRole = "DPS" end
	if dungeon == "Miscellaneous" then dungeon = "party" end
	SendChatMessage(string.format(GBB.L["msgLeaderOutbound"], dungeon, GBB.DB.InviteRole), "WHISPER", nil, name)
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
	GBB.PopupDynamic:AddItem("",true)
	GBB.PopupDynamic:AddItem(GBB.L["HeaderSettings"],false, GBB.Options.Open, 1)

	GBB.PopupDynamic:AddItem(GBB.L["WotlkPanelFilter"], false, GBB.Options.Open, 2)

	GBB.PopupDynamic:AddItem(GBB.L["PanelAbout"], false, GBB.Options.Open, 7)
	GBB.PopupDynamic:AddItem(GBB.L["BtnCancel"],false)
	GBB.PopupDynamic:Show()
end


function GBB.GetLfgList()

	local totalResultsFound, results = C_LFGList.GetSearchResults()

	for _, v in pairs(results) do
		local dungeonTXT=""

        local searchResultData = C_LFGList.GetSearchResultInfo(v)

        if searchResultData.isDelisted == false then
            local requestTime=time() -  searchResultData.age

            local msg = ""
            if searchResultData.comment ~= nil and string.len(searchResultData.comment) > 2 then
                msg = searchResultData.comment
            end

                for _, activityID in pairs(searchResultData.activityIDs) do
                    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
                    local activityGroupName, _ = C_LFGList.GetActivityGroupInfo(activityInfo.groupFinderActivityGroupID)
                    local combinedMsg = activityInfo.fullName .. " " .. activityGroupName
                    local dungeonList, _, _, _, isHeroic = GBB.GetDungeons(combinedMsg, searchResultData.leaderName)

                    for dungeon, id in pairs(dungeonList) do
                        local index=0
                        if id== true and dungeon~=nil then
            
                            for ir,req in pairs(GBB.LfgRequestList) do
                                if type(req) == "table" and req.name == searchResultData.leaderName and req.dungeon == dungeon then
                                    index=ir
                                    break
                                end
                            end

                            local isRaid = GBB.RaidList[dungeon] ~= nil
            
                            if index==0 then
                                local role, class, classLocalized, specLocalized = C_LFGList.GetSearchResultMemberInfo(searchResultData.searchResultID, 1);
                                local partyInfo = GBB.GetPartyInfo(searchResultData.searchResultID, searchResultData.numMembers)
                                index=#GBB.LfgRequestList +1
                                GBB.LfgRequestList[index]={}
                                GBB.LfgRequestList[index].class=classLocalized
                                GBB.LfgRequestList[index].partyInfo=partyInfo
                                GBB.LfgRequestList[index].start=requestTime
                                GBB.LfgRequestList[index].dungeon=dungeon

                                GBB.LfgRequestList[index].IsGuildMember=false
                                GBB.LfgRequestList[index].IsFriend=false
                                GBB.LfgRequestList[index].IsPastPlayer=GBB.GroupTrans[searchResultData.leaderName]~=nil
            
                                if GBB.FilterDungeon(dungeon, isHeroic, isRaid) and GBB.LfgFoldedDungeons[dungeon]~= true then
                                    if dungeonTXT=="" then
                                        dungeonTXT=GBB.dungeonNames[dungeon]
                                    else
                                        dungeonTXT=GBB.dungeonNames[dungeon]..", "..dungeonTXT
                                    end
                                end
                            end

                            GBB.LfgRequestList[index].name=searchResultData.leaderName
                            GBB.LfgRequestList[index].message= msg
                            GBB.LfgRequestList[index].IsHeroic = isHeroic
                            GBB.LfgRequestList[index].IsRaid = isRaid
                            GBB.LfgRequestList[index].last= requestTime
                            GBB.LfgRequestList[index].IsLfgTool = true
                            GBB.LfgRequestList[index].IsDelisted = searchResultData.isDelisted
                            GBB.LfgRequestList[index].resultId = searchResultData.searchResultID
                        end
                    end
                end
        end
    end
end

function GBB.UpdateLfgTool()
    if LFGBrowseFrame.CategoryDropDown.selectedValue == 120 then return end
    if  LFGBrowseFrame.CategoryDropDown.selectedValue == nil then  
        LFGBrowseFrame.CategoryDropDown.selectedValue = 2
    end

    LastUpdateTime = time()
    GBB.LfgRequestList = {}
    
    local category = 2
    if LFGBrowseFrame.CategoryDropDown.selectedValue ~= nil then 
        category = LFGBrowseFrame.CategoryDropDown.selectedValue
    end

	local activities = C_LFGList.GetAvailableActivities(category)
	--C_LFGList.Search(category, activities)
    if LFGBrowseFrame.searching then return end

	GBB.GetLfgList()
    GBB.LfgUpdateList()
end

function GBB.UpdateLfgToolNoSearch()
    if LFGBrowseFrame.CategoryDropDown.selectedValue == 120 then return end
    if  LFGBrowseFrame.CategoryDropDown.selectedValue == nil then  
        LFGBrowseFrame.CategoryDropDown.selectedValue = 2
    end

if LFGBrowseFrame.searching then return end

    GBB.LfgRequestList = {}
    GBB.GetLfgList()
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
		if GBB.DB.ColorByClass and req.class and RAID_CLASS_COLORS[req.class].colorStr then
			prefix="|c"..RAID_CLASS_COLORS[req.class].colorStr
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
			ti=GBB.formatTime(time()-req.start)
		else
			ti=GBB.formatTime(time()-req.last)
		end

		local typePrefix
		if req.IsHeroic == true then
			local colorHex = GBB.Tool.RGBPercToHex(GBB.DB.HeroicDungeonColor.r,GBB.DB.HeroicDungeonColor.g,GBB.DB.HeroicDungeonColor.b)
			typePrefix = "|c00".. colorHex .. "[" .. GBB.L["heroicAbr"] .. "]     "
		elseif req.IsRaid == true then
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

			if (ownRequestDungeons[req.dungeon]==true or GBB.FilterDungeon(req.dungeon, req.IsHeroic, req.IsRaid)) then

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

						if (ownRequestDungeons[GBB.dungeonSort[hi]]==true or GBB.FilterDungeon(GBB.dungeonSort[hi], req.IsHeroic, req.IsRaid)) then
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
			InviteRequestWithRole(req.name,req.dungeon) 
		elseif IsControlKeyDown() then
			InviteRequest(req.name)
		else
            local searchResult = C_LFGList.GetSearchResultInfo(req.resultId)
            if UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) or searchResult.numMembers == 1 then
                InviteRequest(req.name)
            elseif searchResult.isDelisted == false and searchResult.numMembers ~= 5 then 
				InviteRequestWithRole(req.name,req.dungeon) -- sends message telling leader your role
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

function GBB.LfgRequestHideTooltip(self)
	GameTooltip:Hide()
end
