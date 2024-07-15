local TOCNAME,
	---@class Addon_Tool	
	Addon = ...;

---@class ToolBox
local Tool = {}
Addon.Tool = Tool

Tool.IconClassTexture="Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
Tool.IconClassTextureWithoutBorder="Interface\\WorldStateFrame\\ICONS-CLASSES"

---@param classFile string
---@param size number?
function Tool.GetClassIcon(classFile, size)
	assert(type(classFile) == "string", "Usage: Tool.GetClassIcon(class: string, size: number?)", classFile)
	local coords = CLASS_ICON_TCOORDS[classFile:upper()];
	local size = size or 14;
	if coords then
		local icon = CreateTextureMarkup(
			"Interface\\WorldStateFrame\\ICONS-CLASSES",
			256, 256, -- og size
			size, size, -- new size
			coords[1], coords[2], coords[3], coords[4], -- texCoords
			0, 1 -- x, y offsets
		);
		return icon;
	end
end
  
Tool.RaidIconNames=ICON_TAG_LIST
Tool.RaidIcon={
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t", -- [1]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t", -- [2]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t", -- [3]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t", -- [4]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t", -- [5]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t", -- [6]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t", -- [7]
	"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t", -- [8]
}

Tool.RoleIcon = {
	["DAMAGER"]=	"|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:%d:64:64:20:39:22:41|t",
	["HEALER"] =	"|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:%d:64:64:20:39:1:20|t",
	["TANK"] =	"|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:%d:64:64:0:19:22:41|t",
}
  
Tool.Classes=CLASS_SORT_ORDER
Tool.ClassName=LOCALIZED_CLASS_NAMES_MALE
Tool.ClassColor = CopyTable(RAID_CLASS_COLORS)
-- support for CUSTOM_CLASS_COLORS
if CUSTOM_CLASS_COLORS then
	for k, v in pairs(CUSTOM_CLASS_COLORS) do
		---@cast v ColorMixin
		if not v.colorStr then
			v.colorStr = v:GenerateHexColor();
		end
		Tool.ClassColor[k] = v;
	end
end

Tool.NameToClass={}
for eng,name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	Tool.NameToClass[name]=eng
	Tool.NameToClass[eng]=eng
end
for eng,name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
	Tool.NameToClass[name]=eng
end

local transliterations = {
    ["À"] = "A", ["Á"] = "A", ["Â"] = "A", ["Ã"] = "A", ["Ä"] = "Ae", ["Å"] = "A",
	["Æ"] = "AE", ["Ç"] = "C", ["È"] = "E", ["É"] = "E", ["Ê"] = "E", ["Ë"] = "E", 
	["Ì"] = "I", ["Í"] = "I", ["Î"] = "I", ["Ï"] = "I", ["Ð"] = "D", ["Ñ"] = "N", 
	["Ò"] = "O", ["Ó"] = "O", ["Ô"] = "O", ["Õ"] = "O", ["Ö"] = "Oe", ["Ø"] = "O", 
	["Ù"] = "U", ["Ú"] = "U", ["Û"] = "U", ["Ü"] = "Ue", ["Ý"] = "Y", ["Þ"] = "P", 
	["ẞ"] = "s", ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "ae", 
	["å"] = "a", ["æ"] = "ae", ["ç"] = "c", ["è"] = "e", ["é"] = "e", ["ê"] = "e", 
	["ë"] = "e", ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i", ["ð"] = "eth", 
	["ñ"] = "n", ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "oe", 
	["ø"] = "o", ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "ue", ["ý"] = "y", 
	["þ"] = "p", ["ÿ"] = "y", ["ß"] = "ss",
}
-- Hyperlink

local function EnterHyperlink(self,link,text)
	--print(link,text)
	local part=Tool.Split(link,":")
	if part[1]=="spell" or part[1]=="unit" 
	or part[1]=="item" or part[1]=="enchant"
	or part[1]=="player"or part[1]=="quest"
	or part[1]=="trade"
	then
		local tooltip = ItemRefTooltip  -- or GameTooltip
		GameTooltip_SetDefaultAnchor(tooltip, UIParent)
		tooltip:SetOwner(UIParent,"ANCHOR_PRESERVE")
		tooltip:ClearLines()
		tooltip:SetHyperlink(link)
		tooltip:Show()
	end
end
local function LeaveHyperlink(self)
	GameTooltip:Hide()
end
	

function Tool.EnableHyperlink(frame)
	frame:SetHyperlinksEnabled(true);
	frame:SetScript("OnHyperlinkClick",EnterHyperlink)
	-- frame:SetScript("OnHyperlinkLeave",LeaveHyperlink)	
end
	
-- EventHandler
local eventFrame

local function EventHandler(self,event,...)
	for i,Entry in pairs(self._GPIPRIVAT_events) do 
		if Entry[1]==event then
			Entry[2](...)
		end
	end
end
local function UpdateHandler(self,...)
	for i,Entry in pairs(self._GPIPRIVAT_updates) do 
		Entry(...)
	end
end


function Tool.RegisterEvent(event,func)
	if eventFrame==nil then
		eventFrame=CreateFrame("Frame")	
	end
	if eventFrame._GPIPRIVAT_events==nil then 
		eventFrame._GPIPRIVAT_events={}
		eventFrame:SetScript("OnEvent",EventHandler)
	end
	tinsert(eventFrame._GPIPRIVAT_events,{event,func})
	eventFrame:RegisterEvent(event)	
end

function Tool.OnUpdate(func)
	if eventFrame==nil then
		eventFrame=CreateFrame("Frame")	
	end
	if eventFrame._GPIPRIVAT_updates==nil then 
		eventFrame._GPIPRIVAT_updates={}
		eventFrame:SetScript("OnUpdate",UpdateHandler)
	end
	tinsert(eventFrame._GPIPRIVAT_updates,func)
end

-- move frame

local function MovingStart(self)
	self:StartMoving()
end

local function MovingStop(self)
	self:StopMovingOrSizing()
	if self._GPIPRIVAT_MovingStopCallback then
		self._GPIPRIVAT_MovingStopCallback(self)
	end
end

function Tool.EnableMoving(frame,callback)
	frame:SetMovable(true)	
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart",MovingStart)
	frame:SetScript("OnDragStop",MovingStop)
	frame._GPIPRIVAT_MovingStopCallback=callback
end

-- misc tools

function Tool.GuildNameToIndex(name, searchOffline)
	name = string.lower(name)
	for i = 1,GetNumGuildMembers(searchOffline) do
		if string.lower( string.match((GetGuildRosterInfo(i)),"(.-)-")) == name then
			return i
		end
	end
end

function Tool.RunSlashCmd(cmd)
	DEFAULT_CHAT_FRAME.editBox:SetText(cmd) ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
end 

function Tool.RGBtoEscape(r, g, b,a)
	if type(r)=="table" then
		a=r.a
		g=r.g
		b=r.b
		r=r.r
	end
	
	r = r~=nil and r <= 1 and r >= 0 and r or 1
	g = g~=nil and g <= 1 and g >= 0 and g or 1
	b = b~=nil and b <= 1 and b >= 0 and b or 1
	a = a~=nil and a <= 1 and a >= 0 and a or 1
	return string.format("|c%02x%02x%02x%02x", a*255, r*255, g*255, b*255)
end

function Tool.RGBPercToHex(r, g, b)
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

function Tool.GetRaidIcon(name)
	local x=string.gsub(string.lower(name),"[%{%}]","")
	return  ICON_TAG_LIST[x] and Tool.RaidIcon[ICON_TAG_LIST[x]] or name
end

function Tool.UnitDistanceSquared(uId)
	--partly copied from DBM
	--    * Paul Emmerich (Tandanu @ EU-Aegwynn) (DBM-Core)
	--    * Martin Verges (Nitram @ EU-Azshara) (DBM-GUI)
	
	local range
	if UnitIsUnit(uId, "player") then
		range=0
	else
		local distanceSquared, checkedDistance = UnitDistanceSquared(uId)
		if checkedDistance then
			range=distanceSquared
		elseif  C_Map.GetBestMapForUnit(uId)~= C_Map.GetBestMapForUnit("player") then
			range = 1000000
		elseif IsItemInRange(8149, uId) then 
			range = 64 -- 8 --Voodoo Charm
		elseif CheckInteractDistance(uId, 3) then 
			range = 100 --10
		elseif CheckInteractDistance(uId, 2) then 
			range = 121 --11
		elseif IsItemInRange(14530, uId) then 
			range = 324 --18--Heavy Runecloth Bandage. (despite popular sites saying it's 15 yards, it's actually 18 yards verified by UnitDistanceSquared
		elseif IsItemInRange(21519, uId) then 
			range = 529 --23--Item says 20, returns true until 23.
		elseif IsItemInRange(1180, uId) then 
			range = 1089 --33--Scroll of Stamina
		elseif UnitInRange(uId) then 
			range = 1849--43 item scheck of 34471 also good for 43
		else 
			range = 10000 
		end
	end
	return range
end
	
function Tool.Merge(t1,...)
	for index=1 , select("#",...) do
		for i,v in pairs(select(index,...)) do 
			t1[i]=v
		end
	end
	return t1
end

function Tool.iMerge(t1,...)
	for index=1 , select("#",...) do 
		local var=select(index,...)
		if type(var)=="table" then 
			for i,v in ipairs(var) do 
				if tContains(t1,v)==false then
					tinsert(t1,v)
				end
			end
		else
			tinsert(t1,var)
		end
	end
	return t1
end

---Replaces special characters and characters with accents from a given string.
---@param str string
---@return string, number
function Tool.stripChars(str)
	return string.gsub(str,"[%z\1-\127\194-\244][\128-\191]*", transliterations)
end

function Tool.CreatePattern(pattern,maximize)		
	pattern = string.gsub(pattern, "[%(%)%-%+%[%]]", "%%%1")
	if not maximize then 
		pattern = string.gsub(pattern, "%%s", "(.-)")
	else
		pattern = string.gsub(pattern, "%%s", "(.+)")
	end
	pattern = string.gsub(pattern, "%%d", "%(%%d-%)")
	if not maximize then 
		pattern = string.gsub(pattern, "%%%d%$s", "(.-)")
	else
		pattern = string.gsub(pattern, "%%%d%$s", "(.+)")
	end
	pattern = string.gsub(pattern, "%%%d$d", "%(%%d-%)")		
	--pattern = string.gsub(pattern, "%[", "%|H%(%.%-%)%[")
	--pattern = string.gsub(pattern, "%]", "%]%|h")
	return pattern
	
end

function Tool.Combine(t,sep,first,last)
	if type(t)~="table" then return "" end
	sep=sep or " "
	first=first or 1
	last= last or #t
	
	local ret=""
	for i=first,last do
		ret=ret..sep..tostring(t[i])
	end
	return string.sub(ret,string.len(sep)+1)
end

function Tool.iSplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		if tContains(t, str)==false then
			table.insert(t,tonumber(str))
		end
	end
	return t
end

function Tool.Split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		if tContains(t, str)==false then
			table.insert(t, str)
		end
	end
	return t
end

-- Size 

local ResizeCursor
local SizingStop=function(self,button)
	self:GetParent():StopMovingOrSizing()
	if self.GPI_DoStop then self.GPI_DoStop(self:GetParent()) end
end

local SizingStart=function(self,button)
	self:GetParent():StartSizing(self.GPI_SIZETYPE)
	if self.GPI_DoStart then self.GPI_DoStart(self:GetParent()) end
end

local SizingEnter=function(self)
	if not (GetCursorInfo()) then
		ResizeCursor:Show()
		ResizeCursor.Texture:SetTexture(self.GPI_Cursor)
		ResizeCursor.Texture:SetRotation(
			math.rad(self.GPI_Rotation), 
			{x = 0.5, y = 0.5} -- center point
		);
	end
end

local SizingLeave=function(self,button)
	ResizeCursor:Hide()
end

local sizecount=0
local CreateSizeBorder=function(frame,name,a1,x1,y1,a2,x2,y2,cursor,rot,OnStart,OnStop) 
	local FrameSizeBorder
	sizecount=sizecount+1
	FrameSizeBorder=CreateFrame("Frame",(frame:GetName() or TOCNAME..sizecount).."_size_"..name,frame)
	FrameSizeBorder:SetPoint("TOPLEFT", frame, a1, x1, y1)
	FrameSizeBorder:SetPoint("BOTTOMRIGHT", frame, a2, x2,y2 )
	FrameSizeBorder.GPI_SIZETYPE=name
	FrameSizeBorder.GPI_Cursor = cursor
	FrameSizeBorder.GPI_Rotation = rot
	FrameSizeBorder.GPI_DoStart=OnStart
	FrameSizeBorder.GPI_DoStop=OnStop
	FrameSizeBorder:SetScript("OnMouseDown", SizingStart)
	FrameSizeBorder:SetScript("OnMouseUp", SizingStop)
	FrameSizeBorder:SetScript("OnEnter", SizingEnter)
	FrameSizeBorder:SetScript("OnLeave", SizingLeave)	
	return FrameSizeBorder
end

local ResizeCursor_Update=function(self)
	local X, Y = GetCursorPosition()
	local Scale = self:GetEffectiveScale()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", X / Scale, Y / Scale)
end

function Tool.EnableSize(frame,border,OnStart,OnStop)
	if not ResizeCursor then 
		ResizeCursor = CreateFrame("Frame", nil, UIParent)
		ResizeCursor:Hide()
		ResizeCursor:SetWidth(24)
		ResizeCursor:SetHeight(24)
		ResizeCursor:SetFrameStrata("TOOLTIP")
		ResizeCursor.Texture = ResizeCursor:CreateTexture()
		ResizeCursor.Texture:SetAllPoints()
		ResizeCursor:SetScript("OnUpdate", ResizeCursor_Update)
	end
	border=border or 8
	
	
	frame:EnableMouse(true)
	frame:SetResizable(true)	
	
	-- path= "Interface\\AddOns\\".. TOCNAME .. "\\Resize\\"
	
	CreateSizeBorder(frame,"BOTTOM","BOTTOMLEFT", border, border, "BOTTOMRIGHT", -border, 0,"Interface\\CURSOR\\UI-Cursor-SizeLeft",45,OnStart,OnStop)
	CreateSizeBorder(frame,"TOP","TOPLEFT", border, 0, "TOPRIGHT", -border, -border,"Interface\\CURSOR\\UI-Cursor-SizeLeft",45,OnStart,OnStop)
	CreateSizeBorder(frame,"LEFT","TOPLEFT", 0,-border, "BOTTOMLEFT", border, border,"Interface\\CURSOR\\UI-Cursor-SizeRight",45,OnStart,OnStop)
	CreateSizeBorder(frame,"RIGHT","TOPRIGHT",-border,-border, "BOTTOMRIGHT", 0, border,"Interface\\CURSOR\\UI-Cursor-SizeRight",45,OnStart,OnStop)
	
	CreateSizeBorder(frame,"TOPLEFT","TOPLEFT", 0,0, "TOPLEFT", border, -border,"Interface\\CURSOR\\UI-Cursor-SizeRight",0,OnStart,OnStop)
	CreateSizeBorder(frame,"BOTTOMLEFT","BOTTOMLEFT", 0,0, "BOTTOMLEFT", border, border, "Interface\\CURSOR\\UI-Cursor-SizeLeft",0,OnStart,OnStop)
	CreateSizeBorder(frame,"TOPRIGHT","TOPRIGHT", 0,0, "TOPRIGHT", -border, -border, "Interface\\CURSOR\\UI-Cursor-SizeLeft",0,OnStart,OnStop)
	CreateSizeBorder(frame,"BOTTOMRIGHT","BOTTOMRIGHT", 0,0, "BOTTOMRIGHT", -border, border, "Interface\\CURSOR\\UI-Cursor-SizeRight",0,OnStart,OnStop)
	
end

--------------------------------------------------------------------------------
-- Dynamic Popup Menu
--------------------------------------------------------------------------------

local PopupDepth
local function PopupClick(self, arg1, arg2, checked)
	if type(self.value)=="table" then		
		local handle = Addon.OptionsBuilder.GetSavedVarHandle(self.value, arg1)
		if handle then
			handle:SetValue(not handle:GetValue())
		else
			self.value[arg1] = not self.value[arg1]
			self.checked = self.value[arg1]
		end
		if arg2 then
			-- passes old value of `checked`
			arg2(self.value,arg1,checked)		
		end
				
	elseif type(self.value)=="function" then		
		self.value(arg1,arg2)		
	end		
end

---@param text string
---@param disabled boolean
---@param value table|function savedVar db or onclick function
---@param arg1 any? If value is a table, arg1 is the key, else arg1 is the 1st arg for `value`
---@param arg2 any? If value is a function arg2 is the 2nd arg
local function PopupAddItem(self,text,disabled,value,arg1,arg2)
	local c=self._Frame._GPIPRIVAT_Items.count+1
	self._Frame._GPIPRIVAT_Items.count=c
	
	if not self._Frame._GPIPRIVAT_Items[c] then
		self._Frame._GPIPRIVAT_Items[c]={}
	end
	local t=self._Frame._GPIPRIVAT_Items[c]
	t.text=text or ""
	t.disabled=disabled or false
	t.value=value
	t.arg1=arg1
	t.arg2=arg2
	t.MenuDepth=PopupDepth
end

local function PopupAddSubMenu(self,text,value)
	if text~=nil and text~="" then
		PopupAddItem(self,text,"MENU",value)
		PopupDepth=value
	else
		PopupDepth=nil
	end
end

local PopupLastWipeName
local function PopupWipe(self,WipeName)
	self._Frame._GPIPRIVAT_Items.count=0
	PopupDepth=nil	
	if UIDROPDOWNMENU_OPEN_MENU == self._Frame then
		ToggleDropDownMenu(nil, nil, self._Frame, self._where, self._x, self._y)
		if WipeName == PopupLastWipeName then
			return false
		end
	end
	PopupLastWipeName=WipeName	
	return true
end

local function PopupCreate(frame, level, menuList)
	if level==nil then return end
	local info = UIDropDownMenu_CreateInfo()

	for i=1,frame._GPIPRIVAT_Items.count do
		local val=frame._GPIPRIVAT_Items[i]		
		if val.MenuDepth==menuList then
			if val.disabled=="MENU" then
				info.text=val.text
				info.notCheckable = true
				info.disabled=false
				info.value=nil
				info.arg1=nil
				info.arg2=nil
				info.func=nil
				info.hasArrow=true
				info.menuList=val.value
				--info.isNotRadio=true
			else
				info.text=val.text
				if type(val.value)=="table" then
					info.checked=val.value[val.arg1] or false
					info.notCheckable = false
				else
					info.notCheckable = true
				end
				info.disabled=(val.disabled==true or val.text=="" )
				info.keepShownOnClick=(val.disabled=="keep")				
				info.value=val.value
				info.arg1=val.arg1
				if type(val.value)=="table" then			
					info.arg2=frame._GPIPRIVAT_TableCallback
				elseif type(val.value)=="function" then
					info.arg2=val.arg2
				end		
				info.func=PopupClick
				info.hasArrow=false
				info.menuList=nil
				--info.isNotRadio=true
			end
			UIDropDownMenu_AddButton(info,level)
		end
	end
end

local function PopupShow(self,where,x,y)
	where=where or "cursor" 
	if UIDROPDOWNMENU_OPEN_MENU ~= self._Frame then 
		UIDropDownMenu_Initialize(self._Frame, PopupCreate, "MENU")
	end
	ToggleDropDownMenu(nil, nil, self._Frame, where, x,y)
	self._where=where
	self._x=x
	self._y=y
end

function Tool.CreatePopup(TableCallback)
	local popup={}
	popup._Frame=CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
	popup._Frame._GPIPRIVAT_TableCallback=TableCallback
	popup._Frame._GPIPRIVAT_Items={}
	popup._Frame._GPIPRIVAT_Items.count=0
	popup.AddItem=PopupAddItem
	popup.SubMenu=PopupAddSubMenu
	popup.Show=PopupShow
	popup.Wipe=PopupWipe
	return popup
end	

--------------------------------------------------------------------------------
-- TAB

local function SelectTab(self)
	if not self._gpi_combatlock or not InCombatLockdown() then 
		local parent=self:GetParent()
		PanelTemplates_SetTab(parent,self:GetID())
		for i=1, parent.numTabs do
			parent.Tabs[i].content:Hide()
		end
		self.content:Show()	
	
		if parent.Tabs[self:GetID()].OnSelect then
			parent.Tabs[self:GetID()].OnSelect(self)
		end
	end
end

function Tool.TabHide(frame,id)
	if id and frame.Tabs and frame.Tabs[id] then
		frame.Tabs[id]:Hide()
	elseif not id and frame.Tabs then
		for i=1, frame.numTabs do
			frame.Tabs[i]:Hide()
		end
	end
end

function Tool.TabShow(frame,id)
	if id and frame.Tabs and frame.Tabs[id] then
		frame.Tabs[id]:Show()
	elseif not id and frame.Tabs then
		for i=1, frame.numTabs do
			frame.Tabs[i]:Show()
		end
	end
end

function Tool.SelectTab(frame,id)
	if id and frame.Tabs and frame.Tabs[id] then
		SelectTab(frame.Tabs[id])
	end
end	

function Tool.TabOnSelect(frame,id,func)
	if id and frame.Tabs and frame.Tabs[id] then
		frame.Tabs[id].OnSelect=func
	end
end	
	
function Tool.GetSelectedTab(frame)
	if frame.Tabs then 
		for i=1, frame.numTabs do
			if frame.Tabs[i].content:IsShown() then
				return i
			end					
		end
	end
	return 0
end
	
function Tool.AddTab(frame,name,tabFrame,combatlockdown)
	local frameName
	
	if type(frame)=="string" then
		frameName=frame
		frame=_G[frameName]
	else
		frameName=frame:GetName()
	end
	if type(tabFrame)=="string" then
		tabFrame=_G[tabFrame]
	end
	
	frame.numTabs=frame.numTabs and frame.numTabs+1 or 1
	if frame.Tabs==nil then frame.Tabs={} end
	
	frame.Tabs[frame.numTabs]=CreateFrame("Button",frameName.."Tab"..frame.numTabs, frame, "CharacterFrameTabButtonTemplate")
	frame.Tabs[frame.numTabs]:SetID(frame.numTabs)
	frame.Tabs[frame.numTabs]:SetText(name)
	frame.Tabs[frame.numTabs]:SetScript("OnClick",SelectTab)	
	frame.Tabs[frame.numTabs]._gpi_combatlock=combatlockdown
	frame.Tabs[frame.numTabs].content=tabFrame
	tabFrame:Hide()
	
	if frame.numTabs==1 then
		frame.Tabs[frame.numTabs]:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",5,4)
	else
		frame.Tabs[frame.numTabs]:SetPoint("TOPLEFT",frame.Tabs[frame.numTabs-1],"TOPRIGHT",-14,0)
	end
	
	SelectTab(frame.Tabs[frame.numTabs])
	SelectTab(frame.Tabs[1])
	return frame.numTabs
end


-- DataBrocker
local DataBrocker=false
function Tool.AddDataBrocker(icon,onClick,onTooltipShow,text)
	if LibStub ~= nil and DataBrocker ~= true then 
		local Launcher = LibStub('LibDataBroker-1.1',true)
		if Launcher ~= nil then	
			DataBrocker=true
			Launcher:NewDataObject(TOCNAME, {
				type = "launcher",
				icon = icon,
				OnClick = onClick,
				OnTooltipShow = onTooltipShow,
				tocname = TOCNAME,
				label = text or GetAddOnMetadata(TOCNAME, "Title"),
			})
		end
	end	
end
	
-- Slashcommands
		
local slash,slashCmd
local function slashUnpack(t,sep)
	local ret=""
	if sep==nil then sep=", " end
	for i=1,#t do
		if i~=1 then ret=ret..sep end
		ret=ret.. t[i]
	end
	return ret
end

function Tool.PrintSlashCommand(prefix,subSlash,p)
	p=p or print
	prefix=prefix or ""
	subSlash=subSlash or slash
	
	local colCmd="|cFFFF9C00"
	
	for i,subcmd in ipairs(subSlash) do
		local words= (type(subcmd[1])=="table") and "|r("..colCmd..slashUnpack(subcmd[1],"|r/"..colCmd).."|r)"..colCmd or subcmd[1]
		if words=="%" then words="<value>" end
		
		if subcmd[2]~=nil and subcmd[2]~="" then 
			p(colCmd.. ((type(slashCmd)=="table" ) and slashCmd[1] or slashCmd).. " ".. prefix .. words .."|r: "..subcmd[2])
		end
		if type(subcmd[3])=="table" then
			
			Tool.PrintSlashCommand(prefix..words.." ",subcmd[3],p)
		end
		
	end
end
local function DoSlash(deep,msg,subSlash)
	for i,subcmd in ipairs(subSlash) do
		local ok=(type(subcmd[1])=="table") and tContains(subcmd[1],msg[deep]) or 
					(subcmd[1]==msg[deep] or (subcmd[1]=="" and msg[deep]==nil))
		if subcmd[1]=="%" then
			local para=Tool.iMerge( {unpack(subcmd,4)},{unpack(msg,deep)})
			return subcmd[3](unpack( para ) )
		end
		if ok then
			if type(subcmd[3])=="function" then
				return subcmd[3](unpack(subcmd,4))
			elseif type(subcmd[3])=="table" then
				return DoSlash(deep+1,msg,subcmd[3])
			end
		end
	end
	Tool.PrintSlashCommand(Tool.Combine(msg," ",1,deep-1).." ",subSlash)
	return nil
end


local function mySlashs(msg)
	if msg=="help" then
		local colCmd="|cFFFF9C00"
		print("|cFFFF1C1C"..GetAddOnMetadata(TOCNAME, "Title") .." ".. GetAddOnMetadata(TOCNAME, "Version") .." by "..GetAddOnMetadata(TOCNAME, "Author"))
		print(GetAddOnMetadata(TOCNAME, "Notes"))		
		if type(slashCmd)=="table" then
			print("SlashCommand:",colCmd,slashUnpack(slashCmd,"|r, "..colCmd),"|r")
		end
		
		Tool.PrintSlashCommand()

		
	else
		DoSlash(1,Tool.Split(msg," "),slash)
	end
end
	
function Tool.SlashCommand(cmds,subcommand)
	slash=subcommand
	slashCmd=cmds
	if type(cmds)=="table" then
		for i,cmd in ipairs(cmds) do
			_G["SLASH_"..TOCNAME..i]= cmd
		end
	else
		_G["SLASH_"..TOCNAME.."1"]= cmds
	end
	
	SlashCmdList[TOCNAME]=mySlashs
end

function Tool.InDateRange(startDate, endDate)
	local currentMonth, currentDay = date("%m/%d"):match("(%d+)/(%d+)")
	local startMonth, startDay = startDate:match("(%d+)/(%d+)")
	local endMonth, endDay = endDate:match("(%d+)/(%d+)")

	if (startMonth <= currentMonth and currentMonth <= endMonth) and 
	((currentMonth == startMonth and currentDay >= startDay) or (currentMonth == endMonth and currentDay < endDay)) then --Current month is between starting month and end month if same month as end month check to see if it hasn't ended
		return true
	else 
		return false
	end
end