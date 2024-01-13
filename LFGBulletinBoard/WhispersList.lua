local 	TOCNAME,GBB=...

--ScrollList / Request
-------------------------------------------------------------------------------------
local LastDungeon
local lastIsFolded
local requestNil={dungeon="NIL",start=0,last=0,name=""}

local function requestSort_TOP_TOTAL (a,b)
	--a=a or requestNil
	--b=b or requestNil
    if GBB.whispersSort[a.name] == nil or GBB.whispersSort[b.name] == nil then
        return false
    end
	if GBB.whispersSort[a.name] < GBB.whispersSort[b.name] then
		return true
	elseif GBB.whispersSort[a.name] == GBB.whispersSort[b.name]then
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
    if GBB.whispersSort[a.name] == nil or GBB.whispersSort[b.name] == nil then
        return false
    end
	if GBB.whispersSort[a.name] < GBB.whispersSort[b.name] then
		return true
	elseif GBB.whispersSort[a.name] == GBB.whispersSort[b.name] then
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
    if GBB.whispersSort[a.name] == nil or GBB.whispersSort[b.name] == nil then
        return false
    end
	if GBB.whispersSort[a.name] < GBB.whispersSort[b.name] then
		return true
	elseif GBB.whispersSort[a.name] == GBB.whispersSort[b.name] then
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
    if GBB.whispersSort[a.name] == nil or GBB.whispersSort[b.name] == nil then
        return false
    end
	if GBB.whispersSort[a.name] < GBB.whispersSort[b.name] then
		return true
	elseif GBB.whispersSort[a.name] == GBB.whispersSort[b.name] then
		if a.last<b.last then
			return true
		elseif (a.start==b.start and a.name>b.name) then
			return true
		end
	end
	return false
end

local function CreateHeader(yy,req)
	local AnchorTop="GroupBulletinBoardFrame_WhispersChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_WhispersChildFrame"
	local ItemFrameName="GBB.DungeonWhispers_"..req.name

    local prefix
    if GBB.DB.ColorByClass and req.class and RAID_CLASS_COLORS[req.class].colorStr then
        prefix="|c"..RAID_CLASS_COLORS[req.class].colorStr
    else
        prefix="|r"
    end
    local ClassIcon=""
    if GBB.DB.ShowClassIcon and req.class and GBB.Tool.IconClass[req.class] then
        ClassIcon=GBB.Tool.IconClassBig[req.class]
    end

	if GBB.WhispersFramesEntries[req.name]==nil then
		GBB.WhispersFramesEntries[req.name]=CreateFrame("Frame",ItemFrameName , GroupBulletinBoardFrame_WhispersChildFrame, "GroupBulletinBoard_WhispersTmpHeader")
		GBB.WhispersFramesEntries[req.name]:SetPoint("RIGHT", _G[AnchorRight], "RIGHT", 0, 0)
		_G[ItemFrameName.."_name"]:SetPoint("RIGHT",GBB.WhispersFramesEntries[req.name], "RIGHT", 0,0)
		local fname,h=_G[ItemFrameName.."_name"]:GetFont()
		_G[ItemFrameName.."_name"]:SetHeight(h)
		_G[ItemFrameName]:SetHeight(h+5)
		_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)

	end

	local colTXT
	colTXT="|r"

	if LastDungeon~="" and not (lastIsFolded and GBB.FoldedDungeons[req.name]) then
		yy=yy+10
	end

	if GBB.FoldedDungeons[req.name]==true then
		colTXT=colTXT.."[+] "
		lastIsFolded=true
	else
		lastIsFolded=false
	end

	_G[ItemFrameName.."_name"]:SetText(ClassIcon.."["..prefix ..req.name.."]")
	_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)
	GBB.WhispersFramesEntries[req.name]:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 0,-yy)
	GBB.WhispersFramesEntries[req.name]:Show()

	yy=yy+_G[ItemFrameName]:GetHeight()
	LastDungeon = req.name
	return yy
end

local function CreateItem(yy,i,doCompact,req,forceHight)
	local AnchorTop="GroupBulletinBoardFrame_WhispersChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_WhispersChildFrame"
	local ItemFrameName="GBB.ItemWhisper_"..i

    
	if GBB.WhispersFramesEntries[i]==nil then
		GBB.WhispersFramesEntries[i]=CreateFrame("Frame",ItemFrameName , GroupBulletinBoardFrame_WhispersChildFrame, "GroupBulletinBoard_WhispersTmpRequest")
		GBB.WhispersFramesEntries[i]:SetPoint("RIGHT", _G[AnchorRight], "RIGHT", 0, 0)

		_G[ItemFrameName.."_name"]:SetPoint("TOPLEFT")
		_G[ItemFrameName.."_time"]:SetPoint("TOP",_G[ItemFrameName.."_name"], "TOP",0,0)

		_G[ItemFrameName.."_message"]:SetNonSpaceWrap(false)
		_G[ItemFrameName.."_message"]:SetFontObject(GBB.DB.FontSize)
		_G[ItemFrameName.."_name"]:SetFontObject(GBB.DB.FontSize)
		_G[ItemFrameName.."_time"]:SetFontObject(GBB.DB.FontSize)
		if GBB.DontTrunicate then
			GBB.ClearNeeded=true
		end
		GBB.Tool.EnableHyperlink(GBB.WhispersFramesEntries[i])
	end

	GBB.WhispersFramesEntries[i]:SetHeight(999)
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

        _G[ItemFrameName.."_name"]:SetText(ClassIcon..prefix .. req.name .. suffix..FriendIcon)
			_G[ItemFrameName.."_message"]:SetText(typePrefix .. suffix .. req.message)

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

	GBB.WhispersFramesEntries[i]:SetPoint("TOPLEFT",_G[AnchorTop], "TOPLEFT", 10,-yy)
	_G[ItemFrameName.."_message"]:SetHeight(h+10)
	GBB.WhispersFramesEntries[i]:SetHeight(h)

	if req then
		GBB.WhispersFramesEntries[i]:Show()
	else
		GBB.WhispersFramesEntries[i]:Hide()
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
	if gbbDungeon == "MISC" or gbbDungeon == "TRADE" then
		gbbDungeonPrefix = ""
	end

	SendChatMessage(string.format(GBB.L["msgLeaderOutbound"], gbbDungeonPrefix .. GBB.dungeonNames[gbbDungeon], GBB.DB.InviteRole), "WHISPER", nil, gbbName)
end

local function IgnoreRequest(name)
	for ir,req in pairs(GBB.WhispersList) do
		if type(req) == "table" and req.name == name then
			req.last=0
		end
	end
	GBB.ClearNeeded=true
	C_FriendList.AddIgnore(name)
end

function GBB.ClearWhispers()
	if GBB.ClearNeeded or GBB.ClearTimer<time() then
		local newRequest={}
		GBB.ClearTimer=GBB.MAXTIME

		for i,req in pairs(GBB.WhispersList) do
			if type(req) == "table" then
				if req.last + GBB.DB.TimeOut * 3 > time() then
					if req.last < GBB.ClearTimer then
						GBB.ClearTimer=req.last
					end
					newRequest[#newRequest+1]=req

				end
			end
		end
		GBB.WhispersList=newRequest
		GBB.ClearTimer=GBB.ClearTimer+GBB.DB.TimeOut * 3
		GBB.ClearNeeded=false
	end
end

local ownRequestDungeons={}
local ownRequestWhispers={}
local autoinc = 1
function GBB.UpdateWhispersList()

	GBB.ClearWhispers()

	if not GroupBulletinBoardFrame:IsVisible()  then
		return
	end

	GBB.UserLevel=UnitLevel("player")

	if GBB.DB.OrderNewTop then
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.WhispersList, requestSort_TOP_TOTAL)
		else
			table.sort(GBB.WhispersList, requestSort_TOP_nTOTAL)
		end
	else
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.WhispersList, requestSort_nTOP_TOTAL)
		else
			table.sort(GBB.WhispersList, requestSort_nTOP_nTOTAL)
		end
	end

	for i, f in pairs(GBB.WhispersFramesEntries) do
		f:Hide()
	end

	local AnchorTop="GroupBulletinBoardFrame_WhispersChildFrame"
	local AnchorRight="GroupBulletinBoardFrame_WhispersChildFrame"
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
    wipe(ownRequestWhispers)
	if GBB.DBChar.DontFilterOwn then

		local playername=(UnitFullName("player"))

		for i,req in pairs(GBB.WhispersList) do
			if type(req) == "table" and req.name==playername and req.last + GBB.DB.TimeOut*2 > time()then
				ownRequestWhispers[req.name]=true
			end
		end
	end

	local itemHight=CreateItem(yy,0,doCompact,nil)

	GroupBulletinBoardFrame_ScrollFrame.ScrollBar.scrollStep=itemHight*2

	if #GBB.WhispersFramesEntries<100 then
		for i=1,100 do
			CreateItem(yy,i,doCompact,nil)
		end
	end

	for i,req in pairs(GBB.WhispersList) do
		if type(req) == "table" then
                if GBB.whispersSort[req.name] == nil then
                    GBB.whispersSort[req.name] = autoinc
                    autoinc = autoinc + 1
                end

                if LastDungeon ~= req.name then
					local hi
					hi=GBB.whispersSort[req.name]-1
					while hi<GBB.whispersSort[req.name] do
						if LastDungeon~="" then
							yy=yy+ itemHight*(GBB.DB.ShowOnlyNb-cEntrys)
						end
						hi=hi+1

							yy=CreateHeader(yy,req)
							cEntrys=0
					end
				end
			--if req.last + GBB.DB.TimeOut > time() then

				count= count + 1

				--header
           
				--entry GBB.FoldedDungeons[req.dungeon]~=true and (
				--if not GBB.DB.EnableShowOnly or cEntrys<GBB.DB.ShowOnlyNb then
					yy=yy+ CreateItem(yy,i,doCompact,req,itemHight)+3
					cEntrys=cEntrys+1
				--end
			--end
		end
	end

    --[[
	if GBB.DB.EnableShowOnly then
		local hi=GBB.whispersSort[LastDungeon] or 0
		while hi<GBB.WOTLKMAXDUNGEON do
			if LastDungeon~="" and GBB.FoldedDungeons[LastDungeon]~=true and GBB.DB.EnableShowOnly then
				yy=yy+ itemHight*(GBB.DB.ShowOnlyNb-cEntrys)
			end
			hi=hi+1
			if (ownRequestDungeons[GBB.whispersSort[hi]-]==true or GBB.FilterDungeon(GBB.whispersSort[hi], false, false)) then
				yy=CreateHeader(yy,GBB.whispersSort[hi])
				cEntrys=0
			else
				cEntrys=GBB.DB.ShowOnlyNb
			end
		end

	end
    ]]

	yy=yy+GroupBulletinBoardFrame_ScrollFrame:GetHeight()-20

	GroupBulletinBoardFrame_WhispersChildFrame:SetHeight(yy)
	GroupBulletinBoardFrameStatusText:SetText(string.format(GBB.L["msgNbRequest"], count))
end

function GBB.GetDungeonsWhispers(msg,name)
	if msg==nil then return {} end
	local dungeons={}

	local isBad=false
	local isGood=false
	local isHeroic=false

	local runrequired=false
	local hasrun=false
	local runDungeon=""

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
		local parts =GBB.SplitNoNb(msg)
		for ip, p in pairs(parts) do
			if p=="run" or p=="runs" then
				hasrun=true
			end

			local x=GBB.tagList[p]

			if GBB.HeroicKeywords[p] ~= nil then
				isHeroic = true
			end

			if x==nil then
				if GBB.tagList[p.."run"]~=nil then
					runDungeon=GBB.tagList[p.."run"]
					runrequired=true
				end
			elseif x==GBB.TAGBAD then
				isBad=true
				break
			elseif x==GBB.TAGSEARCH then
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

	if dungeons["DEADMINES"] and not dungeons["DMW"] and not dungeons["DME"] and not dungeons["DME"] and name~=nil then
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
		for ip,p in pairs(GBB.dungeonSecondTags) do
			local ok=false
			if dungeons[ip]== true then
				for it,t in ipairs(p) do
					if string.sub(t,1,1)=="-" then
						if dungeons[string.sub(t,2)]== true then
							ok=true
						end
					elseif dungeons[t]== true then
						ok=true
					end
				end
				if ok==false then
					for it,t in ipairs(p) do
						if string.sub(t,1,1)~="-" then
							dungeons[t]= true
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

	-- remove all secondtags-dungeons
	for ip,p in pairs(GBB.dungeonSecondTags) do
		if dungeons[ip]== true then
			dungeons[ip]=nil
		end
	end

	if GBB.DB.CombineSubDungeons then
		for ip,p in pairs(GBB.dungeonSecondTags) do
			if ip~="DEATHMINES" then
				for is,subDungeon in pairs(p) do
					if dungeons[subDungeon] then
						dungeons[ip]=true
						dungeons[subDungeon]=nil
					end
				end
			end
		end
	end

	return dungeons, isGood, isBad, wordcount, isHeroic
end

function GBB.ParseMessageWhisper(msg,name,guid,channel)
	if GBB.Initalized==false or name==nil or name=="" or msg==nil or msg=="" or string.len(msg)<0 then
		return
	end

	local appendTime = tonumber("0." .. math.random(100,999)) -- Append a random "millisecond" value. 
	local requestTime=tonumber(time() + appendTime)

	local doUpdate=false

	local locClass,engClass,locRace,engRace,Gender,gName,gRealm = GetPlayerInfoByGUID(guid)

    index=#GBB.WhispersList +1
    GBB.WhispersList[index]={}
    GBB.WhispersList[index].name=name
    GBB.WhispersList[index].class=engClass
    GBB.WhispersList[index].start=requestTime
    --GBB.WhispersList[index].dungeon=dungeon
    GBB.WhispersList[index].IsGuildMember=IsInGuild() and IsGuildMember(guid)
    GBB.WhispersList[index].IsFriend=C_FriendList.IsFriend(guid)
    GBB.WhispersList[index].IsPastPlayer=GBB.GroupTrans[name]~=nil
    GBB.WhispersList[index].last=requestTime
    GBB.WhispersList[index].message=msg


    if GBB.DB.NotifyChat then
        local FriendIcon=(C_FriendList.IsFriend(guid) and string.format(GBB.TxtEscapePicture,GBB.FriendIcon) or "") ..
                        ((IsInGuild() and IsGuildMember(guid)) and string.format(GBB.TxtEscapePicture,GBB.GuildIcon) or "") ..
                        (GBB.GroupTrans[name]~=nil and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon) or "" )
        local linkname=	"|Hplayer:"..name.."|h[|c"..RAID_CLASS_COLORS[engClass].colorStr ..name.."|r]|h"
        if GBB.DB.OneLineNotification then
            DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..linkname..FriendIcon..": "..msg,GBB.DB.NotifyColor.r,GBB.DB.NotifyColor.g,GBB.DB.NotifyColor.b)
        else
            DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..string.format(GBB.L["msgNewRequest"],linkname..FriendIcon,"dungeonTXT"),GBB.DB.NotifyColor.r*.8,GBB.DB.NotifyColor.g*.8,GBB.DB.NotifyColor.b*.8)
            DEFAULT_CHAT_FRAME:AddMessage(GBB.MSGPREFIX..msg,GBB.DB.NotifyColor.r,GBB.DB.NotifyColor.g,GBB.DB.NotifyColor.b)
        end
    end
    if GBB.DB.NotifySound then
        PlaySound(GBB.NotifySound)
    end

    --[[

    

	-- Add server name to player name by commenting out the split
	-- name=GBB.Tool.Split(name, "-")[1] -- remove GBB.ServerName

	if GBB.DB.RemoveRaidSymbols then
		msg=string.gsub(msg,"{.-}","*")
	else
		msg=string.gsub(msg,"{.-}",GBB.Tool.GetRaidIcon)
	end

	local updated=false
	for ir,req in pairs(GBB.WhispersList) do
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
	local dungeonList, isGood, isBad, wordcount, isHeroic = GBB.GetDungeonsWhispers(msg,name)

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
					for ir,req in pairs(GBB.WhispersList) do
						if type(req) == "table" and req.name == name and req.dungeon == dungeon then
							index=ir
							break
						end
					end
				end

				local isRaid = GBB.RaidList[dungeon] ~= nil

				if index==0 then
					index=#GBB.WhispersList +1
					GBB.WhispersList[index]={}
					GBB.WhispersList[index].name=name
					GBB.WhispersList[index].class=engClass
					GBB.WhispersList[index].start=requestTime
					GBB.WhispersList[index].dungeon=dungeon
					GBB.WhispersList[index].IsGuildMember=IsInGuild() and IsGuildMember(guid)
					GBB.WhispersList[index].IsFriend=C_FriendList.IsFriend(guid)
					GBB.WhispersList[index].IsPastPlayer=GBB.GroupTrans[name]~=nil

					if GBB.FilterDungeon(dungeon, isHeroic, isRaid) and dungeon~="TRADE" and dungeon~="MISC" and GBB.FoldedDungeons[dungeon]~= true then
						if dungeonTXT=="" then
							dungeonTXT=GBB.dungeonNames[dungeon]
						else
							dungeonTXT=GBB.dungeonNames[dungeon]..", "..dungeonTXT
						end
					end
				end

				GBB.WhispersList[index].message=msg
				GBB.WhispersList[index].IsHeroic = isHeroic
				GBB.WhispersList[index].IsRaid = isRaid
				GBB.WhispersList[index].last=requestTime
				doUpdate=true
			end
		end
	end

	if dungeonTXT~="" and GBB.AllowInInstance() then
		if GBB.DB.NotifyChat then
			local FriendIcon=(C_FriendList.IsFriend(guid) and string.format(GBB.TxtEscapePicture,GBB.FriendIcon) or "") ..
						 ((IsInGuild() and IsGuildMember(guid)) and string.format(GBB.TxtEscapePicture,GBB.GuildIcon) or "") ..
						 (GBB.GroupTrans[name]~=nil and string.format(GBB.TxtEscapePicture,GBB.PastPlayerIcon) or "" )
			local linkname=	"|Hplayer:"..name.."|h[|c"..RAID_CLASS_COLORS[engClass].colorStr ..name.."|r]|h"
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
		for i,req in pairs(GBB.WhispersList) do
			if type(req) == "table" then
				if req.name == name and req.last ~= requestTime and req.dungeon~="TRADE" then
					GBB.WhispersList[i]=nil
					GBB.ClearNeeded=true
				end
			end
		end

	elseif GBB.DB.OnDebug then

		local index=#GBB.WhispersList +1
		GBB.WhispersList[index]={}
		GBB.WhispersList[index].name=name
		GBB.WhispersList[index].class=engClass
		GBB.WhispersList[index].start=requestTime
		if isBad then
			GBB.WhispersList[index].dungeon="BAD"
		else
			GBB.WhispersList[index].dungeon="DEBUG"
		end

		GBB.WhispersList[index].message=msg
		GBB.WhispersList[index].IsHeroic = isHeroic
		GBB.WhispersList[index].last=requestTime
	end
    ]]
end
function GBB.UnfoldAllDungeonWhispers()
	wipe(GBB.FoldedDungeons)
	--GBB.UpdateList()
    GBB.UpdateWhispersList()
end
function GBB.FoldAllDungeonWhispers()
	for i=1,GBB.WOTLKMAXDUNGEON do
		GBB.FoldedDungeons[GBB.whispersSort[i]]=true
	end
	--GBB.UpdateList()
    GBB.UpdateWhispersList()
    
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
		GBB.PopupDynamic:AddItem(GBB.L["BtnFoldAll"], false,GBB.FoldAllDungeonWhispers)
		GBB.PopupDynamic:AddItem(GBB.L["BtnUnFoldAll"], false,GBB.UnfoldAllDungeonWhispers)
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

function GBB.ClickFrameWhispers(self,button)
	if button=="LeftButton" then
	else
		createMenu()
	end
end

function GBB.ClickDungeonWhispers(self,button)
	local id=string.match(self:GetName(), "GBB.Dungeon_(.+)")
	if id==nil or id==0 then return end

	if button=="LeftButton" then
		if GBB.FoldedDungeons[id] then
			GBB.FoldedDungeons[id]=false
		else
			GBB.FoldedDungeons[id]=true
		end
		--GBB.UpdateList()
		GBB.UpdateWhispersList()
	else
		createMenu(id)
	end

end

function GBB.ClickRequestWhispers(self,button)
	local id = string.match(self:GetName(), "GBB.ItemWhisper_(.+)")
	if id==nil or id==0 then return end

	local req=GBB.WhispersList[tonumber(id)]
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


function GBB.RequestShowTooltipWhispers(self)
	for id in string.gmatch(self:GetName(), "GBB.ItemWhisper_(.+)") do
		local n=_G[self:GetName().."_message"]
		local req=GBB.WhispersList[tonumber(id)]

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

function GBB.RequestHideTooltipWhispers(self)
	GameTooltip:Hide()
end
