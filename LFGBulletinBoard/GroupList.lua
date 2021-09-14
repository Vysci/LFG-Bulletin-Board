local 	TOCNAME,GBB=...

local MAXGROUP=500
local guildcache={}
local friendcache={}
local pastplayercache={}

GBB.GroupTrans={}

local AllowedInstanceType={"party","scenario","raid"}



function GBB.GetPlayerList()
	local count, prefix
	local ret={}
		
	if IsInRaid() then
		prefix="raid"
		count=MAX_RAID_MEMBERS
	else
		prefix="party"
		count=MAX_PARTY_MEMBERS
	end
	
	
	for index = 1,count do
		local id=prefix..index
		local name=GetUnitName(id)
		local localizedClass, englishClass, classIndex = UnitClass(id)
		
		if name and englishClass and not UnitIsUnit(id,"player") then
			ret[name]={
				["name"]=name,
				["class"]=englishClass,
				["guid"]=UnitGUID(id),
				}
		end
		
	end
	
	return ret
end


function GBB.AddGroupList(entry)
	local note
	if entry.Note then
		note=GBB.Tool.RGBtoEscape(GBB.DB.PlayerNoteColor)..entry.Note.."|r"
		
	else
		note=""
	end
	
	if guildcache[entry.name]==nil then
		guildcache[entry.name]=entry.guid and IsInGuild() and IsGuildMember(entry.guid)
	end
	if friendcache[entry.name]==nil then
		friendcache[entry.name]=entry.guid and C_FriendList.IsFriend(entry.guid)
	end
		
	if pastplayercache[entry.name] == nil then
		pastplayercache[entry.name]=entry.name and GBB.GroupTrans[entry.name]~=nil
	end
	GroupBulletinBoardFrame_GroupFrame:AddMessage(
		"|Hplayer:".. entry.name .."|h"..
		GBB.Tool.IconClass[entry.class]..
		"|c"..GBB.Tool.ClassColor[entry.class].colorStr ..
		entry.name..
		
		(friendcache[entry.name] and "|cffecda90*|r" or "") ..
		(guildcache[entry.name] and "|cffb4fe2c•|r" or "")..
		
		"|r "..note.."|h"		
		)
end

function GBB.UpdateGroupList()
	if not GBB.DB.EnableGroup then
		return
	end
	
	
	local dname, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
	
	if tContains(AllowedInstanceType,instanceType) then
		local group=GBB.GetPlayerList()
		
		for i,member in pairs(group) do
			if GBB.GroupTrans[member.name] then
				local entry=GBB.GroupTrans[member.name]
				entry.lastSeen=GetServerTime()
				if not entry.guid then
					entry.guid=group[entry.name].guid
				end
				entry.dungeon=dname
			else
			
				GBB.GroupTrans[member.name]={
					name=member.name,
					class=member.class,
					lastSeen=GetServerTime(),
					guid=member.guid,
					dungeon=dname,
				}
			
				tinsert(GBB.DBChar.GroupList,GBB.GroupTrans[member.name])
			end
		end
		
		table.sort(GBB.DBChar.GroupList,function(a,b) return a.lastSeen<b.lastSeen end)	
	end
		
	if not GroupBulletinBoardFrame:IsVisible() or GBB.Tool.GetSelectedTab(GroupBulletinBoardFrame)~=2 then
		return
	end
	GBB.EditNote(nil)
		
	GroupBulletinBoardFrame_GroupFrame:Clear()
	for i,entry in ipairs(GBB.DBChar.GroupList) do
		GBB.AddGroupList(entry)		
	end
end

local EditEntry
function GBB.EditNote(entry)
	StaticPopup_Hide("GroupBulletinBoard_AddNote")	
	if entry then 
		EditEntry=entry		
		StaticPopup_Show("GroupBulletinBoard_AddNote", entry.name)
	end
end

local function EnterHyperlink(self,link,text)
	local part=GBB.Tool.Split(link,":")
	if part[1]=="player" then
		for i,entry in ipairs(GBB.DBChar.GroupList) do
			if entry.name==part[2] then 
				GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
				GameTooltip:SetOwner(GroupBulletinBoardFrame, "ANCHOR_BOTTOM", 0,-25)
				GameTooltip:ClearLines()
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
				GameTooltip:Show()
				break
			end
		end
	end
end	

local function LeaveHyperlink(self)
	GameTooltip:Hide()
end

local function ClickHyperlink(self,link)
	local part=GBB.Tool.Split(link,":")
	if part[1]=="player" then
		for i,entry in ipairs(GBB.DBChar.GroupList) do
			if entry.name==part[2] then 
				GBB.EditNote(entry)
				break
			end
		end
	end
end

function GBB.InitGroupList()
	if GBB.DBChar.GroupList==nil then
		GBB.DBChar.GroupList={}
	end
	
	StaticPopupDialogs["GroupBulletinBoard_AddNote"] = {
		text = GBB.L.msgAddNote,
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		maxLetters = 48,
		countInvisibleLetters = true,
		editBoxWidth = 350,
		OnAccept = function(self)
			EditEntry.Note=self.editBox:GetText()
			GBB.UpdateGroupList()
		end,
		OnShow = function(self)
			self.editBox:SetText(EditEntry.Note or "");
			self.editBox:SetFocus();
		end,
		OnHide = function(self)
			ChatEdit_FocusActiveWindow();
			self.editBox:SetText("");			
		end,
		EditBoxOnEnterPressed = function(self)
			local parent = self:GetParent();
			EditEntry.Note=parent.editBox:GetText()
			GBB.UpdateGroupList()
			parent:Hide();
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide();
		end,
		timeout = 0,
		exclusive = 1,
		whileDead = 1,
		hideOnEscape = 1
	}
	
	

	GroupBulletinBoardFrame_GroupFrame:SetFading(false);
	GroupBulletinBoardFrame_GroupFrame:SetFontObject(GameFontNormal);
	GroupBulletinBoardFrame_GroupFrame:SetJustifyH("LEFT");
	GroupBulletinBoardFrame_GroupFrame:SetHyperlinksEnabled(true);
	GroupBulletinBoardFrame_GroupFrame:SetScript("OnHyperlinkClick",ClickHyperlink)
	GroupBulletinBoardFrame_GroupFrame:SetScript("OnHyperlinkEnter",EnterHyperlink)
	GroupBulletinBoardFrame_GroupFrame:SetScript("OnHyperlinkLeave",LeaveHyperlink)
	GroupBulletinBoardFrame_GroupFrame:SetTextCopyable(true);
	GroupBulletinBoardFrame_GroupFrame:Clear()
	GroupBulletinBoardFrame_GroupFrame:SetMaxLines(MAXGROUP)
	--GroupBulletinBoardFrame_GroupFrame:SetInsertMode("TOP")
	--[[for i=1,200 do
		GBB.DBChar.GroupList[i]={
			name="rnd"..i,
			class=GBB.Tool.Classes[ random(1,#GBB.Tool.Classes)],
			lastSeen=GetServerTime()-random(1,400000),
		}
	end
	--]]
	
	table.sort(GBB.DBChar.GroupList,function(a,b) return a.lastSeen<b.lastSeen end)	
	while #GBB.DBChar.GroupList>=MAXGROUP do
		tremove(GBB.DBChar.GroupList,1)
	end
	
	for i,entry in ipairs(GBB.DBChar.GroupList) do
		GBB.GroupTrans[entry.name]=entry
	end
	
	GBB.UpdateGroupList()
	
	
end

function GBB.ScrollGroupList(self,delta)
	self:SetScrollOffset(self:GetScrollOffset() + delta*5);
	self:ResetAllFadeTimes()
end
