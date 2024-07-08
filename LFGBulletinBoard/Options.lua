local TOCNAME,
	---@class Addon_Options : Addon_Localization, Addon_CustomFilters, Addon_Dungeons, Addon_Tags, Addon_LibGPIOptions
	GBB= ...;
local ChannelIDs
local ChkBox_FilterDungeon
local TbcChkBox_FilterDungeon
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
local PROJECT_EXPANSION_ID = {
	[WOW_PROJECT_CLASSIC] = GBB.Enum.Expansions.Classic,
	[WOW_PROJECT_BURNING_CRUSADE_CLASSIC] = GBB.Enum.Expansions.BurningCrusade,
	[WOW_PROJECT_WRATH_CLASSIC] = GBB.Enum.Expansions.Wrath,
	-- note: global not defined in classic era client
	[WOW_PROJECT_CATACLYSM_CLASSIC or 0] = GBB.Enum.Expansions.Cataclysm,
}
local EXPANSION_PROJECT_ID = tInvert(PROJECT_EXPANSION_ID)
---hack to remove "World of Warcraft: " from classic on esES/esMX clients
local EXPANSION_NAME0 = EXPANSION_NAME0:gsub("World of Warcraft: ", "")
local EXPANSION_FILTER_NAME = {
	[GBB.Enum.Expansions.Classic] = SUBTITLE_FORMAT:format(FILTERS, EXPANSION_NAME0),
	[GBB.Enum.Expansions.BurningCrusade] = SUBTITLE_FORMAT:format(FILTERS, EXPANSION_NAME1),
	[GBB.Enum.Expansions.Wrath] = SUBTITLE_FORMAT:format(FILTERS, EXPANSION_NAME2),
	[GBB.Enum.Expansions.Cataclysm] = SUBTITLE_FORMAT:format(FILTERS, EXPANSION_NAME3),
}
--Options
-------------------------------------------------------------------------------------

local function CheckBox (Var,Init)
	return GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DB,Var,Init,GBB.L["Cbox"..Var])
end
local function CheckBoxChar (Var,Init)
	return GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DBChar,Var,Init,GBB.L["CboxChar"..Var])
end
local function CheckBoxFilter (Dungeon,Init)
	local dungeonName = (GBB.GetDungeonInfo(Dungeon, true) or {}).name
	return GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(
		GBB.DBChar, "FilterDungeon".. Dungeon, 
		Init, 
		((GBB.dungeonNames[Dungeon] 
			or dungeonName or "ERROR"
		).." "..GBB.LevelRange(Dungeon,true))
	)
end
local function CreateEditBoxNumber (Var,Init,width,width2)
	return GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB,Var,Init,GBB.L["Edit"..Var],width,width2,true)
end
local function CreateEditBox (Var,Init,width,width2)
	return GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB,Var,Init,GBB.L["Edit"..Var],width,width2,false)
end

local function CreateEditBoxDungeon(Dungeon,Init,width,width2)
	-- delete old settings
	if GBB.DB["Custom_"..Dungeon] ~=nil then
		GBB.DB.Custom[Dungeon]=GBB.DB["Custom_"..Dungeon]
		GBB.DB["Custom_"..Dungeon]=nil
	end
	local dungeonName = (GBB.GetDungeonInfo(Dungeon, true) or {}).name
	if GBB.dungeonNames[Dungeon] or dungeonName then
		GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB.Custom, Dungeon, Init, 
			((GBB.dungeonNames[Dungeon] or 
				dungeonName).." "..GBB.LevelRange(Dungeon,true)
			),
			width, width2, false, nil, 
			GBB.Tool.Combine(GBB.dungeonTagsLoc["enGB"][Dungeon])
		)
	else
		local txt=""
		if Dungeon=="Search" then
			txt=GBB.Tool.Combine(GBB.searchTagsLoc["enGB"])
		elseif Dungeon=="Bad" then
			txt=GBB.Tool.Combine(GBB.badTagsLoc["enGB"])
		elseif Dungeon=="Suffix" then
			txt=GBB.Tool.Combine(GBB.suffixTagsLoc["enGB"])
		elseif Dungeon=="Heroic" then
			txt=GBB.Tool.Combine(GBB.heroicTagsLoc["enGB"])
		end
		
		GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB.Custom,Dungeon,Init,GBB.L["EditCustom_"..Dungeon],width,width2,false,nil,txt)
	end
end

local function FixFilters()
	for parentKey, secondaryKey in pairs(GBB.dungeonSecondTags) do
		if parentKey ~= "DEADMINES" then
			-- assume main key is false
			GBB.DBChar["FilterDungeon"..parentKey] = false
			for _, altKey in pairs(secondaryKey) do
				-- if any alt dungeon key is true, set main key to true.
				local altTagSetting = GBB.DBChar["FilterDungeon"..altKey]
				if altTagSetting == true then
					GBB.DBChar["FilterDungeon"..parentKey] = true
					break
				end
			end
		end
	end
end

local function ResetFilters()
	if GBB.ShouldReset and (not GBB.DBChar["ResetVersion"] or GBB.DBChar["ResetVersion"] ~= GBB.Version) then
		GBB.DBChar["ResetVersion"] = GBB.Version
		for k, _ in pairs(GBB.dungeonSort) do
			if GBB.DBChar["FilterDungeon"..k] ~= nil then
				GBB.DBChar["FilterDungeon"..k] = nil
			end
		end
	end
end

local isChat=false
function GBB.OptionsUpdate()

	FixFilters()

	if GBB.DB.ChatStyle and GBB.DB.CompactStyle then
		if isChat then
			GBB.DB.ChatStyle=false
		else
			GBB.DB.CompactStyle=false
		end
	end

	if GBB.DB.EnableGroup then
		GBB.Tool.TabShow(GroupBulletinBoardFrame)
	else
		GBB.Tool.SelectTab(GroupBulletinBoardFrame,1)
		GBB.Tool.TabHide(GroupBulletinBoardFrame, 3)
	end
	
	GBB.CreateTagList()
	GBB.MinimapButton.UpdatePosition()
	GBB.ClearNeeded=true
	
	isChat=GBB.DB.ChatStyle 
end

local DoSelectFilter=function(state, ChkBox, Start, Max)
	for index=Start,Max do ---trade -misc
		if ChkBox[index].SetSavedValue then -- new api for managing saved vars. 
			ChkBox[index]:SetSavedValue(state)
		else
			ChkBox[index]:SetChecked(state)
		end
	end	
end
	
local DoRightClick=function(self) 
	DoSelectFilter(false)
	self:SetChecked(true)
end
	
local function SetChatOption()
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderChannel"])
	GBB.OptionsBuilder.Indent(10)	

	ChannelIDs = {}
	for i=1,10 do
		GBB.OptionsBuilder.InLine()
		ChannelIDs[i]	= GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DBChar.channel,i,true,i..". ",125)
		ChannelIDs[i+10]= GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DBChar.channel,i+10,true,(i+10)..". ",125)
		
		GBB.OptionsBuilder.EndInLine()
	end
	GBB.OptionsBuilder.Indent(-10)
end

---Generates and options panels with check box filters for the given expansion.
---if the expansion is the current game client expansion, it will also include misc filters.
---@param expansionID ExpansionID
local function GenerateExpansionPanel(expansionID)
	local panel = GBB.OptionsBuilder.AddNewCategoryPanel(EXPANSION_FILTER_NAME[expansionID], false, true)
	-- hack: save changes anytime the panel is hidden (issues: 200, 147, 57)
	panel:HookScript("OnHide", GBB.OptionsBuilder.onCommit)
	
	local isCurrentXpac = expansionID == PROJECT_EXPANSION_ID[WOW_PROJECT_ID];
	local filters = {} ---@type CheckButton[]
	local dungeons = GBB.GetSortedDungeonKeys(
		expansionID, GBB.Enum.DungeonType.Dungeon
	);
	local raids = GBB.GetSortedDungeonKeys(
		expansionID, GBB.Enum.DungeonType.Raid
	);
	local bgs = GBB.GetSortedDungeonKeys(
		expansionID, GBB.Enum.DungeonType.Battleground
	);
	
	-- Dungeons 		
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(DUNGEONS)
	GBB.OptionsBuilder.Indent(10)
	for _, key in pairs(dungeons) do
		tinsert(filters, CheckBoxFilter(key, false))
	end

	-- different layout for classic era clients
	if not isCurrentXpac or isClassicEra then
		GBB.OptionsBuilder.SetRightSide()
	end

	-- Raids
	GBB.OptionsBuilder.Indent(-10)
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(RAIDS)
	GBB.OptionsBuilder.Indent(10)
	for _, key in pairs(raids) do
		tinsert(filters, CheckBoxFilter(key, false))
	end

	-- Battlegrounds (bg are all consider part of latest expansion atm)
	if #bgs > 0 then
		if isCurrentXpac and not isClassicEra then
			GBB.OptionsBuilder.SetRightSide()
		end --else keep on same column as raid for classic era

		GBB.OptionsBuilder.Indent(-10)
		GBB.OptionsBuilder.AddHeaderToCurrentPanel(BATTLEGROUNDS)
		GBB.OptionsBuilder.Indent(10)
		for _, key in pairs(bgs) do
			tinsert(filters, CheckBoxFilter(key, false))
		end
	end

	-- dont include misc filters in the "select all" buttons
	local resetLimitIdx = #filters 

	-- Extra Categories (only show for current xpac)
	if isCurrentXpac then
		
		-- Add any Custom user filters 
		local customCategories = GBB.GetCustomFilterKeys()
		if next(customCategories) then
			GBB.OptionsBuilder.Indent(-10)
			GBB.OptionsBuilder.AddHeaderToCurrentPanel(ADDITIONAL_FILTERS)
			GBB.OptionsBuilder.Indent(10)
			for _, key in ipairs(customCategories) do
				tinsert(filters, CheckBoxFilter(key, false))
			end
		end

		-- Add `GBB.Misc` defined categories
		GBB.OptionsBuilder.Indent(-10)
		GBB.OptionsBuilder.AddHeaderToCurrentPanel(OTHER)
		GBB.OptionsBuilder.Indent(10)		
		for _, key in pairs(GBB.Misc) do
			tinsert(filters, CheckBoxFilter(key, false))
		end
		
	else
		-- add space to make up for no "other" category
		GBB.OptionsBuilder.AddSpacerToPanel() 
	end
	
	if not isClassicEra then
		CheckBoxChar("HeroicOnly", false)
		CheckBoxChar("NormalOnly", false)
	end
	CheckBoxChar("FilterLevel",false)
	CheckBoxChar("DontFilterOwn",false)

	-- Select/Unselect All Filters Buttons
	GBB.OptionsBuilder.InLine()
	GBB.OptionsBuilder.AddButtonToCurrentPanel(GBB.L["BtnSelectAll"],function()
		DoSelectFilter(true, filters, 1, resetLimitIdx)
	end)
	GBB.OptionsBuilder.AddButtonToCurrentPanel(GBB.L["BtnUnselectAll"],function()
		DoSelectFilter(false, filters,1, resetLimitIdx)
	end)

	-- Role Filters
	GBB.OptionsBuilder.AddDropdownToCurrentPanel(GBB.DB,"InviteRole", "DPS", {"DPS", "Tank", "Healer"})
	GBB.OptionsBuilder.EndInLine()
	
	-- Chat Channel Filters (only show for current xpac)
	if isCurrentXpac then
		GBB.OptionsBuilder.Indent(-10)
		SetChatOption()
	end
end

function GBB.OptionsInit ()
	GBB.OptionsBuilder.Init(
		function(panelFrame) -- called when "close" button is pressed	
			GBB.OptionsBuilder.DoOk() -- saves any widget states to the DB
			if GBB.DB.TimeOut< 60 then GBB.DB.TimeOut = 60 end
			GBB.OptionsUpdate()	
		end,
		function(panelFrame) -- called whenever the canvas view is refreshed (swapping categories, on open, etc.)
			local t= GBB.PhraseChannelList(GetChannelList())
			for i=1,20 do
				if i<20 then 
					_G[ChannelIDs[i]:GetName().."Text"]:SetText(i..". "..(t[i] and t[i].name or ""))
				else
					_G[ChannelIDs[i]:GetName().."Text"]:SetText((t[i] and t[i].name or ""))
				end
			end
			GBB.OptionsBuilder.DoRefresh() -- syncs widgets to DB state
		end, 
		function(panelFrame) -- called when the default button is pressed (not implemented for addon panels)
			GBB.OptionsBuilder.DoDefault() -- reset widgets to default state.
			GBB.DB.MinimapButton.position=40			
			GBB.ResetWindow()		
			GBB.OptionsUpdate()	
		end
		)
	
	
	
	GBB.OptionsBuilder.SetScale(0.85)
	
	
	-- First panel - Settings
	GBB.OptionsBuilder.AddNewCategoryPanel(GBB.Title,false,true)
		
	--GBB.OptionsBuilder.AddVersion('|cff00c0ff' .. GBB.Version .. '|r')
	
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderSettings"])
	GBB.OptionsBuilder.Indent(10)
	
	GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DB.MinimapButton,"visible",true,GBB.L["Cboxshowminimapbutton"])
	GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DB.MinimapButton,"lock",false,GBB.L["CboxLockMinimapButton"])
	GBB.OptionsBuilder.AddCheckBoxToCurrentPanel(GBB.DB.MinimapButton,"lockDistance",true,GBB.L["CboxLockMinimapButtonDistance"])
	GBB.OptionsBuilder.AddSpacerToPanel()
	CheckBox("ShowTotalTime",false)
	CheckBox("OrderNewTop",true)
	CheckBox("HeadersStartFolded",false)
	GBB.OptionsBuilder.AddSpacerToPanel()
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["msgFontSize"],-20)
	GBB.OptionsBuilder.AddDropdownToCurrentPanel(GBB.DB,"FontSize", "GameFontNormal", {"GameFontNormalSmall", "GameFontNormal", "GameFontNormalLarge"}) 

	CheckBox("CombineSubDungeons",false)
	CheckBox("IsolateTravelServices",true)
	GBB.OptionsBuilder.AddSpacerToPanel()
	CheckBox("NotifySound",false)
	CheckBox("NotifyChat",false)
	GBB.OptionsBuilder.Indent(20)
	CheckBox("NotfiyInnone",true)
	CheckBox("NotfiyInpvp",false)
	CheckBox("NotfiyInparty",true)
	CheckBox("NotfiyInraid",false)
	CheckBox("OneLineNotification",false)
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"NotifyColor",{r=1,g=1,b=1,a=1},GBB.L["BtnNotifyColor"])
	GBB.OptionsBuilder.Indent(-20)	
	GBB.OptionsBuilder.AddSpacerToPanel()
	CheckBox("ColorOnLevel",true)
	CheckBox("UseAllInLFG",true)
	CheckBox("EscapeQuit",true)
	CheckBox("DisplayLFG",false)
	GBB.OptionsBuilder.AddSpacerToPanel()
	GBB.OptionsBuilder.InLine()
	CheckBox("ColorByClass",true)
	CheckBox("ShowClassIcon",true)
	GBB.OptionsBuilder.EndInLine()
	CheckBox("RemoveRaidSymbols",true)	
	CheckBox("RemoveRealm",false)
	CheckBox("ChatStyle",false)
	CheckBox("CompactStyle",false)
	CheckBox("DontTrunicate",false)
	CheckBox("EnableShowOnly",false)		
	GBB.OptionsBuilder.Indent(30)
	CreateEditBoxNumber("ShowOnlyNb",4,50)	
	GBB.OptionsBuilder.Indent(-30)
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"EntryColor",{r=1,g=1,b=1,a=1},GBB.L["BtnEntryColor"])
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"HeroicDungeonColor",{r=1,g=0,b=0,a=1},GBB.L["BtnHeroicDungeonColor"])
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"NormalDungeonColor",{r=0,g=1,b=0,a=1},GBB.L["BtnNormalDungeonColor"])
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"TimeColor",{r=1,g=1,b=1,a=1},GBB.L["BtnTimeColor"])
	GBB.OptionsBuilder.AddSpacerToPanel()
	CreateEditBoxNumber("TimeOut",150,50)	
		
	GBB.OptionsBuilder.AddSpacerToPanel()
	CheckBox("AdditionalInfo",false)
	CheckBox("EnableGroup",false)
	GBB.OptionsBuilder.Indent(30)
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"PlayerNoteColor",{r=1,g=0.8,b=0.2,a=1},GBB.L["BtnPlayerNoteColor"])
	GBB.OptionsBuilder.Indent(-30)
	GBB.OptionsBuilder.AddSpacerToPanel()
	
	CheckBox("EnableGuild",false)
	GBB.OptionsBuilder.Indent(30)
	GBB.OptionsBuilder.AddColorSwatchToCurrentPanel(GBB.DB,"ColorGuild",{a=1,r=.2,g=1,b=.2},GBB.L["BtnColorGuild"])
	GBB.OptionsBuilder.Indent(-30)
	GBB.OptionsBuilder.AddSpacerToPanel()
	CheckBox("OnDebug",false)

	GBB.OptionsBuilder.AddSpacerToPanel()
	-- a global framexml string that's pre translated by blizzard called RESET_POSITION
	GBB.OptionsBuilder.AddButtonToCurrentPanel(RESET_POSITION,GBB.ResetWindow)
	GBB.OptionsBuilder.AddSpacerToPanel()
	----------------------------------------------------------
	-- Expansion specific filters
	----------------------------------------------------------
	if not isClassicEra then 
		--- Cata Filters
		GenerateExpansionPanel(GBB.Enum.Expansions.Cataclysm)
		--- Wrath Filters
		GenerateExpansionPanel(GBB.Enum.Expansions.Wrath)
		--- TBC Filters
		GenerateExpansionPanel(GBB.Enum.Expansions.BurningCrusade)
	end
	-- Vanilla Filters
	GenerateExpansionPanel(GBB.Enum.Expansions.Classic)
		
	----------------------------------------------------------
	-- Custom Filters/Categories
	----------------------------------------------------------
	local customCategoriesFrame = GBB.OptionsBuilder.AddNewCategoryPanel(ADDITIONAL_FILTERS, false, true);
	customCategoriesFrame:SetWidth(
		InterfaceOptionsFramePanelContainer:GetWidth() - customCategoriesFrame:GetParent().ScrollBar:GetWidth()
	);
	-- defer Update call until after language "Tags" saved vars are initialized bellow
	----------------------------------------------------------
	-- Language Tags and Search Patterns
	----------------------------------------------------------
	GBB.OptionsBuilder.AddNewCategoryPanel(GBB.L["PanelTags"],false,true)
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(LANGUAGES_LABEL)
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.InLine()
	local locale = GetLocale()
	CheckBox("TagsEnglish", locale == "enUS" or locale == "enGB")
	CheckBox("TagsGerman", locale == "deDE")
	CheckBox("TagsRussian", locale == "ruRU")
	CheckBox("TagsFrench", locale == "frFR")
	CheckBox("TagsZhtw",locale == "zhTW")
	CheckBox("TagsZhcn",locale == "zhCN")
	GBB.OptionsBuilder.EndInLine()
	GBB.OptionsBuilder.InLine()
	-- hack: add ptBR, and esES/esMX checkboxes
	CheckBox("TagsSpanish", locale == "esES" or locale == "esMX")
	CheckBox("TagsPortuguese", locale == "ptBR")
	CheckBox("TagsCustom",true)
	GBB.OptionsBuilder.EndInLine()
	GBB.OptionsBuilder.Indent(-10)
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderTagsCustom"])
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["msgCustomList"],450+200)
	GBB.OptionsBuilder.AddSpacerToPanel()
	CreateEditBoxDungeon("Search","",450,200)
	CreateEditBoxDungeon("Bad","",450,200)
	CreateEditBoxDungeon("Suffix","",450,200)
	CreateEditBoxDungeon("Heroic","",450,200)
	
	
	GBB.OptionsBuilder.AddSpacerToPanel()	
	for index=1,GBB.ENDINGDUNGEONEND do
		CreateEditBoxDungeon(GBB.dungeonSort[index],"",445,200)
	end
	GBB.OptionsBuilder.AddSpacerToPanel()
	CreateEditBoxDungeon("SM2","",445,200)
	CreateEditBoxDungeon("DM2","",445,200)	
	CreateEditBoxDungeon("DEADMINES","",445,200)
	GBB.OptionsBuilder.Indent(-10)

	GBB.UpdateAdditionalFiltersPanel(customCategoriesFrame); -- update the custom filters panel now.
	----------------------------------------------------------	
	-- localization
	----------------------------------------------------------
	GBB.OptionsBuilder.AddNewCategoryPanel(GBB.L["PanelLocales"],false,true)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["msgLocalRestart"])
	GBB.OptionsBuilder.AddSpacerToPanel()
	local locales= GBB.locales.enGB
	local t={}
	for key, _ in pairs(locales) do 
		table.insert(t,key)
	end
	table.sort(t)
	for _,key in ipairs(t) do 
		
		local col=GBB.L[key]~=nil and "|cffffffff" or "|cffff4040"
		local txt=GBB.L[key.."_org"]~="["..key.."_org]" and GBB.L[key.."_org"] or GBB.L[key]
				
		GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB.CustomLocales,key,"",col.."["..key.."]",450,200,false,locales[key],txt)
		
	end
	--locales dungeons
	GBB.OptionsBuilder.AddSpacerToPanel()
	locales=getmetatable(GBB.dungeonNames).__index
	for i=1,GBB.MAXDUNGEON do

		local key=GBB.dungeonSort[i]
		
		local col=GBB.dungeonNames[key]~=locales[key] and "|cffffffff" or "|cffff4040"
		
		local txt=GBB.dungeonNames[key.."_org"]~=nil and GBB.dungeonNames[key.."_org"] or GBB.dungeonNames[key]

		GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB.CustomLocalesDungeon,key,"",col..locales[key],450,200,false,locales[key],txt)
	end
	
	for i=GBB.TBCDUNGEONSTART,GBB.WOTLKMAXDUNGEON do

		local key=GBB.dungeonSort[i]
		
		local col=GBB.dungeonNames[key]~=locales[key] and "|cffffffff" or "|cffff4040"
		
		local txt=GBB.dungeonNames[key.."_org"]~=nil and GBB.dungeonNames[key.."_org"] or GBB.dungeonNames[key]

		GBB.OptionsBuilder.AddEditBoxToCurrentPanel(GBB.DB.CustomLocalesDungeon,key,"",col..locales[key],450,200,false,locales[key],txt)
	end
	
	----------------------------------------------------------
	-- About
	----------------------------------------------------------
	local function SlashText(txt)
		GBB.OptionsBuilder.AddTextToCurrentPanel(txt)
	end
	
	GBB.OptionsBuilder.AddNewCategoryPanel(GBB.L["PanelAbout"])

	GBB.OptionsBuilder.AddHeaderToCurrentPanel("|cFFFF1C1C"..GetAddOnMetadata(TOCNAME, "Title") .." ".. GetAddOnMetadata(TOCNAME, "Version") .." by "..GetAddOnMetadata(TOCNAME, "Author"))
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GetAddOnMetadata(TOCNAME, "Notes"))		
	GBB.OptionsBuilder.Indent(-10)
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderInfo"])
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["AboutInfo"],-20)
	GBB.OptionsBuilder.Indent(-10)
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderUsage"])
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["AboutUsage"],-20)
	GBB.OptionsBuilder.Indent(-10)
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderSlashCommand"])
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["AboutSlashCommand"],-20)
	GBB.Tool.PrintSlashCommand(nil,nil,SlashText)
	GBB.OptionsBuilder.Indent(-10)
	
	GBB.OptionsBuilder.AddHeaderToCurrentPanel(GBB.L["HeaderCredits"])
	GBB.OptionsBuilder.Indent(10)
	GBB.OptionsBuilder.AddTextToCurrentPanel(GBB.L["AboutCredits"],-20)
	GBB.OptionsBuilder.Indent(-10)
	
	FixFilters()
end
