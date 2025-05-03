local TOCNAME,
	---@class Addon_GroupBulletinBoard : Addon_Localization, Addon_CustomFilters, Addon_Dungeons, Addon_Tags, Addon_Options, Addon_Tool
	GBB = ...;

GroupBulletinBoard_Addon=GBB
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

GBB.MSGPREFIX="[LFG Bulletin Board]: "
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
local OptionsUtil = GBB.OptionsBuilder
-- Tools
-------------------------------------------------------------------------------------
local debug = false -- dev override
local print = function(...)
	if (GBB.DB and GBB.DB.OnDebug) or debug then
		_G.print(WrapTextInColorCode(("[%s]:"):format(TOCNAME), NORMAL_FONT_COLOR:GenerateHexColor()), ...);
	end
end

-- Uniquely inserts, if value is already present it is shifted to the end of the table.
---@generic T
---@type fun(tbl: T[], value:any): nil
local insertUnique = function(tbl, value)
	local last = #tbl
	-- reorder value if found
	for i = 1, last do
		if tbl[i] == value and i ~= last then
			for j = i, last do
				if tbl[j + 1] then tbl[j] = tbl[j + 1];
				else
					tbl[j] = value
					break;
				end
			end
			return; -- return after reorder
		end
	end
	-- simply insert if not found
	tbl[last + 1] = value
end

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
end

function GBB.ShowWindow()
	local version, build, date, tocversion = GetBuildInfo()

    -- Check if classic or not
    if string.sub(version, 1, 2) ~= "1." then
		GBB.UpdateGroupList()
    end
	GroupBulletinBoardFrame:Show()
	GBB.ChatRequests.UpdateRequestList(true)
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

local function setBulletinBoardMovableState(isMovable)
    local Header, Footer = GroupBulletinBoardFrameHeaderContainer, GroupBulletinBoardFrameFooterContainer
    local RequestListScroll, LFGToolScroll = GroupBulletinBoardFrame_ScrollFrame, GBB.LfgTool.ScrollContainer
    local isInteractive = GBB.DB.WindowSettings.isInteractive
    local containers = {Header, Footer, RequestListScroll, LFGToolScroll}
    for _, container in ipairs(containers) do
        local isScrollFrame = container == LFGToolScroll or container == RequestListScroll
        local shouldEnableMouse = (not isScrollFrame or isInteractive) and isMovable
        container:EnableMouse(shouldEnableMouse)
        if isMovable then container:RegisterForDrag("LeftButton")
        else container:RegisterForDrag() end
        if not isScrollFrame or isInteractive then
            container:SetScript("OnDragStart", isMovable and function() GroupBulletinBoardFrame:StartMoving() end or nil)
            container:SetScript("OnDragStop", isMovable and function() GroupBulletinBoardFrame:StopMovingAndSaveAnchors() end or nil)
        end
        if container == Header or container == Footer then
            -- Darken the header/footer backgrounds slightly when they handle dragging
            container.Background:SetColorTexture(0, 0, 0, (isMovable and 0.17 or 0))
        end
    end
end
--------------------------------------------------------------------------------
-- Bulletin Board Settings Button Setup
--------------------------------------------------------------------------------

---@class BulletinBoardSettingsButton: Button
local SettingsButtonMixin = {}
function SettingsButtonMixin:OnLoad()
	local getSettingsVarHandleTable = function(settingsTable)
		return setmetatable({}, { ---@type table<string, SavedVarHandle>
			__index = function(t, k)
				-- note: make sure the saved vars defaults has been setup before access within this menu
				local value = OptionsUtil.GetSavedVarHandle(settingsTable, k)
				rawset(t, k, value); return value;
			end
		})
	end
	local getSettingValue = function(setting) return setting:GetValue() end
	local getInverseSettingValue = function(setting) return not getSettingValue(setting) end
	local toggleSettingValue = function(setting) setting:SetValue(not getSettingValue(setting)) end
	local accountSettings = getSettingsVarHandleTable(GBB.DB)

	---Helper for older saved variables that use the `Cbox` prefix convention for their associated labels.
	---@param variableName string `GBB.DB[variableName]`
	---@param label string? display text. falls back to `GBB.L["Cbox"..variableName]`
	local getAccountVarCheckBoxArgs = function(variableName, label)
		local setting = accountSettings[variableName]
		return (label or GBB.L["Cbox"..variableName]), getSettingValue, toggleSettingValue, setting
	end

	---@param subDesc RootMenuDescriptionProxy|ElementMenuDescriptionProxy
	local makeSubElementsSmall = function(subDesc)
		for _, desc in subDesc:EnumerateElementDescriptions() do
			desc:AddInitializer(function(frame)
				if frame.fontString then frame.fontString:SetFontObject("GameFontNormalSmall") end
			end)
		end
	end

	---@param clickType "LeftButton"|"RightButton"
	local buildDescriptionForClickType = function(clickType)
		local description = MenuUtil.CreateRootMenuDescription(MenuStyle2Mixin)
		description:CreateButton(FILTERS, function() OptionsUtil.OpenCategoryPanel(2) end)
		if clickType == "RightButton" then
			do -- Notification Settings
				local subDesc = description:CreateButton(COMMUNITIES_NOTIFICATION_SETTINGS, nop)
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("NotifySound")) -- sound
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("NotifyChat")) -- chat
				makeSubElementsSmall(subDesc)
			end
			do -- Request Entry Settings
				local subDesc = description:CreateButton(GBB.L.REQUESTS_SETTINGS, nop)
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("ShowTotalTime")) -- total time vs last updated
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("OrderNewTop")) -- sort by most recent vs oldest
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("EnableShowOnly")) -- limit requests per category
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("RemoveRealm")) -- remove realm from player names
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("DontTrunicate")) -- don't truncate requests
				subDesc:CreateCheckbox(GBB.L["CboxFilterTravel"], -- filter travel requests (character specific setting)
					getSettingValue, toggleSettingValue, OptionsUtil.GetSavedVarHandle(GBB.DBChar, "FilterDungeonTRAVEL")
				)
				subDesc:CreateDivider():SetFinalInitializer(function(frame) frame:SetHeight(5) end)
				subDesc:CreateTitle(GBB.L.LAYOUT_OPTIONS)
				-- "Chat Style" & "Compact Style" layout, respectively.
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("ChatStyle"))
				subDesc:CreateCheckbox(getAccountVarCheckBoxArgs("CompactStyle"))
				makeSubElementsSmall(subDesc)
			end
		end
		do -- Board window/frame settings
			local windowSettings = getSettingsVarHandleTable(GBB.DB.WindowSettings)
			description:CreateDivider()
			description:CreateTitle(GBB.L.WINDOW_SETTINGS)
			description:CreateCheckbox(LOCK_WINDOW, -- Lock window
				getInverseSettingValue, toggleSettingValue, windowSettings.isMovable
			)
			description:CreateCheckbox(MAKE_UNINTERACTABLE, -- Make non-interactive (click-through)
				getInverseSettingValue, toggleSettingValue, windowSettings.isInteractive
			)
			local opacityOptions = description:CreateButton(OPACITY) -- Opacity
			-- todo: add a slider
			local setBoardFrameOpacity = function(opacity)
				windowSettings.opacity:SetValue(opacity)
			end
			local opacityRadioButtonArgs = function(opacity)
				local isSelected = function()
					return floor(GroupBulletinBoardFrame:GetAlpha()*10)/10 == opacity
				end
				local displayText = ("%d%%"):format(opacity * 100)
				return displayText, isSelected, setBoardFrameOpacity, opacity
			end
			for _, opacity in ipairs({1, .8, .6, .5, .4, .2, .1}) do
				opacityOptions:CreateRadio(opacityRadioButtonArgs(opacity)):SetResponse(MenuResponse.Refresh)
			end
			description:CreateDivider()
		end
		description:CreateButton(ALL_SETTINGS, function() OptionsUtil.OpenCategoryPanel(1) end)
		description:CreateButton(GBB.L.BtnCancel, nop):SetResponse(MenuResponse.CloseMenu)
		return description
	end
	self.descriptions = {
		LeftButton = buildDescriptionForClickType("LeftButton"),
		RightButton = buildDescriptionForClickType("RightButton"),
	}
	self.owner = self -- using the button itself for now, but can be moved to any other region if needed.
	self.menuAnchor = AnchorUtil.CreateAnchor("TOPRIGHT", self.owner, "BOTTOMRIGHT")
	self.HandlesGlobalMouseEvent = function() return true end -- prevents clicks on button from closing the menus
	self:SetScript("OnMouseDown", self.OnMouseDown)
	self:SetScript("OnEnter", self.OnEnter)
	self:SetScript("OnLeave", self.OnLeave)
end
function SettingsButtonMixin:OpenMenu(menuDescription)
	local menu = Menu.GetManager():OpenMenu(self.owner, menuDescription, self.menuAnchor)
	menu:SetClosedCallback(function() self.lastDescription = nil end)
	self.lastDescription = menuDescription
	return menu
end
function SettingsButtonMixin:CloseMenu(menu)
	assert(menu, "CloseMenu: menu is nil")
	Menu.GetManager():CloseMenu(menu)
end
function SettingsButtonMixin:OnMouseDown(clickType)
	local currentOpenMenu = Menu.GetManager():GetOpenMenu()
	-- default to left click description
	local incomingDescription = self.descriptions[clickType] or self.descriptions.LeftButton
	-- Simulate a toggle button: Close menu currently open click menu if it exists
	if currentOpenMenu and incomingDescription == self.lastDescription then
		self:CloseMenu(currentOpenMenu)
		self:OnLeave() -- clear tooltip
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	else  -- open menu when: No menu is currently open, or switching click menus
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self:OpenMenu(incomingDescription)
		self:OnEnter() -- update tooltip
	end
end
function SettingsButtonMixin:OnEnter()
	-- show tooltip after left-clicked, __only__
	if self.lastDescription == self.descriptions.LeftButton then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(SETTINGS, 1, 1, 1)
		GameTooltip:AddLine(GBB.L.RIGHT_CLICK_FOR_MORE_OPTIONS,
			GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, true
		)
		GameTooltip:Show()
	else GameTooltip:Hide() end
end
function SettingsButtonMixin:OnLeave() GameTooltip:Hide() end
--------------------------------------------------------------------------------
-- Tag Lists
--------------------------------------------------------------------------------
local tagCollisions
local shouldUpdateTagKey = function(pattern, current, incoming)
	assert(incoming, "shouldUpdateTagKey: incoming key is nil", pattern, current, incoming)
	if current == incoming then return false end
	if not current then return true end
	local incInfo = GBB.GetDungeonInfo(incoming) or {};
	local curInfo = GBB.GetDungeonInfo(current) or {};
	if incInfo.expansionID ~= curInfo.expansionID then
		return (incInfo.expansionID or -1) >= (curInfo.expansionID or -1)
	end
	if incInfo.typeID ~= curInfo.typeID then
		return (incInfo.typeID or -1) >= (curInfo.typeID or -1)
	end
	if incInfo.maxLevel ~= curInfo.maxLevel then
		return (incInfo.maxLevel or -1) >= (curInfo.maxLevel or -1)
	end
	return incoming >= current
end
---Sets the `GBB.tagList` table with the tags specified by the given locale.
---@param locale string The locale to create the tag list for.
local function setTagListByLocale(locale)
	for _,tag in pairs(GBB.badTagsLoc[locale]) do
		GBB.tagList[tag]=GBB.TAGBAD		
	end
	for _, tag in pairs(GBB.searchTagsLoc[locale]) do
		GBB.tagList[tag]=GBB.TAGSEARCH		
	end
	for _, tag in pairs(GBB.suffixTagsLoc[locale]) do
		insertUnique(GBB.suffixTags, tag)
	end
	for dungeonKey, tagList in pairs(GBB.dungeonTagsLoc[locale]) do
		---@cast tagList string[]
		---@cast dungeonKey string
		for _, tag in pairs(tagList) do
			local existingKey = GBB.tagList[tag] -- check for tag pattern collisions
			if existingKey and existingKey ~= dungeonKey then 
				tagCollisions[tag] = tagCollisions[tag] or { existingKey }
				insertUnique(tagCollisions[tag], dungeonKey) -- track last prio'd key in collision
				if shouldUpdateTagKey(tag, existingKey, dungeonKey) then
					GBB.tagList[tag] = dungeonKey -- update tag-key assignment
				else
					--hack: re-insert existingKey at end of list (for formatting priority in debug output)
					insertUnique(tagCollisions[tag], existingKey) 
				end
			else
				GBB.tagList[tag] = dungeonKey -- init tag key assignment
			end
		end
	end
	for _, tag in pairs(GBB.heroicTagsLoc[locale]) do
		GBB.HeroicKeywords[tag] = 1
	end
end

--- Populates tag related tables `tagList`, `suffixTags`, and `HeroicKeywords` with tags from all enabled locales.
-- also populates from any set custom tags.
function GBB.CreateTagList ()
	GBB.tagList={}
	GBB.suffixTags={}
	GBB.HeroicKeywords={}
	tagCollisions = {}

	if GBB.DB.TagsEnglish then setTagListByLocale("enGB") end
	if GBB.DB.TagsGerman then
		--German tags need english!
		if GBB.DB.TagsEnglish==false then
			setTagListByLocale("enGB")
		end	
		setTagListByLocale("deDE")
	end
	if GBB.DB.TagsRussian then setTagListByLocale("ruRU") end
	if GBB.DB.TagsFrench then setTagListByLocale("frFR") end
	if GBB.DB.TagsZhtw then setTagListByLocale("zhTW") end
	if GBB.DB.TagsZhcn then setTagListByLocale("zhCN") end
	if GBB.DB.TagsPortuguese then setTagListByLocale("ptBR") end
	if GBB.DB.TagsSpanish then setTagListByLocale("esES") end
	if GBB.DB.TagsCustom then
		GBB.searchTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Search)
		GBB.badTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Bad)
		GBB.suffixTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Suffix)
		GBB.heroicTagsLoc["custom"]=GBB.Split(GBB.DB.Custom.Heroic)

		local sortedDungeonKeys = GBB.GetSortedDungeonKeys( -- dungeons & raids for all expansions
			nil, {GBB.Enum.DungeonType.Dungeon, GBB.Enum.DungeonType.Raid, GBB.Enum.DungeonType.WorldBoss}
		)
		-- insert a "custom" locale to `dungeonTagsLoc` for custom tags (before calling `setTagListByLocale`).
		GBB.dungeonTagsLoc["custom"]={}
		for _, key in ipairs(sortedDungeonKeys) do
			GBB.dungeonTagsLoc['custom'][key] = GBB.Split(GBB.DB.Custom[key])
		end
		setTagListByLocale("custom")
	end

	if GBB.DB.OnDebug and next(tagCollisions) then
		print("Tag pattern collisions found:")
		for tag, collisions in pairs(tagCollisions) do
			local numCollisions = #collisions
			if numCollisions > 1 then -- not a collision if only one key
				for i = 1, numCollisions do
					collisions[i] = ("(%s) %s"):format(
						collisions[i],
						WrapTextInColorCode(GBB.dungeonNames[collisions[i]], 'FFFFC56D')
					)
				end
				print(WrapTextInColorCode(("'%s'"):format(tag), 'FFFF1B1B'),'=>', table.concat(collisions, ' | '))
			end
		end
		print("Messages with these keywords may not be categorized as expected. Priority given to the last in list.")
	end
end
--------------------------------------------------------------------------------
-- Minimap button context Menu setup
--------------------------------------------------------------------------------

local minimapMenuGeneratorCache = {}
local function getMinimapMenuDescriptionGenerator(showMinimapOptions)
	local settings = {
		notifySound = OptionsUtil.GetSavedVarHandle(GBB.DB, "NotifySound"),
		notifyChat = OptionsUtil.GetSavedVarHandle(GBB.DB, "NotifyChat"),
		minimapLock = OptionsUtil.GetSavedVarHandle(GBB.DB.MinimapButton, "lock"),
		minimapLockDistance = OptionsUtil.GetSavedVarHandle(GBB.DB.MinimapButton, "lockDistance"),
	}
	local GetSettingValue = function(setting) return setting:GetValue() end
	local ToggleSettingValue = function(setting) setting:SetValue(not GetSettingValue(setting)) end
	local getSettingsCheckboxArgs = function(label, setting)
		return label, GetSettingValue, ToggleSettingValue, setting
	end
	local function makeElementsSmall(subDesc)
		if not subDesc:HasElements() then return end
		for _, desc in subDesc:EnumerateElementDescriptions() do
			desc:AddInitializer(function(frame)
				if frame.fontString then frame.fontString:SetFontObject("GameFontNormalSmall") end
			end)
			makeElementsSmall(desc)
		end
	end
	local createThinDivider = function(rootDesc)
		rootDesc:CreateDivider():SetFinalInitializer(function(frame) frame:SetHeight(4) end)
	end
	return function(_, rootDesc) ---@param rootDesc RootMenuDescriptionProxy
		rootDesc:CreateTitle(GBB.Metadata.Title)
		rootDesc:CreateButton(SETTINGS, OptionsUtil.OpenCategoryPanel, 1) -- open main settings
		do -- Notification Settings
			local subDesc = rootDesc:CreateButton(COMMUNITIES_NOTIFICATION_SETTINGS, nop)
			subDesc:CreateCheckbox(getSettingsCheckboxArgs(GBB.L["CboxNotifySound"], settings.notifySound))
			subDesc:CreateCheckbox(getSettingsCheckboxArgs(GBB.L["CboxNotifyChat"], settings.notifyChat))
		end
		createThinDivider(rootDesc)
		if showMinimapOptions ~= false then -- Minimap Button Settings
			rootDesc:CreateCheckbox(getSettingsCheckboxArgs(GBB.L["CboxLockMinimapButton"], settings.minimapLock))
			if GBB.MinimapButton.isLibDBIconAvailable and GBB.DB.MinimapButton.UseLibDBIcon then
				-- disable distance lock toggle whenever the minimap is using LibDBIcon
				rootDesc:CreateCheckbox(GBB.L["CboxLockMinimapButtonDistance"], function() return true end, nop)
					:SetEnabled(false)
			else
				rootDesc:CreateCheckbox(
					getSettingsCheckboxArgs(GBB.L["CboxLockMinimapButtonDistance"], settings.minimapLockDistance)
				)
			end
			createThinDivider(rootDesc)
		end
		rootDesc:CreateButton(CANCEL, nop):SetResponse(MenuResponse.CloseMenu)
		makeElementsSmall(rootDesc)
	end
end
function GBB.CreateMinimapContextMenu(frame, showMinimapOptions)
	local menuDescription = minimapMenuGeneratorCache[showMinimapOptions]
	if not menuDescription then
		menuDescription = getMinimapMenuDescriptionGenerator(showMinimapOptions)
		minimapMenuGeneratorCache[showMinimapOptions] = menuDescription
	end
	MenuUtil.CreateContextMenu(frame, menuDescription)
end
--------------------------------------------------------------------------------
-- Initialize / Event
--------------------------------------------------------------------------------

local function hooked_createTooltip(self)
	local name, unit = self:GetUnit()
	if (name) and (unit) and UnitIsPlayer(unit) then
	
		if GBB.DB.EnableGuild then
			local guildName, guildRank = GetGuildInfo(unit)
			if guildName then
				self:AddLine(Mixin(ColorMixin, GBB.DB.ColorGuild):WrapTextInColorCode(
					(GBB.DB.EnableGuildRank and guildRank)
						and ("<%s> - %s"):format(guildName, guildRank)
						or ("<%s>"):format(guildName)
				));
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

function GBB.Init()
    ---@class BulletinBoardFrame: Frame
    local GroupBulletinBoardFrame = GroupBulletinBoardFrame
	GroupBulletinBoardFrame:SetResizeBounds(400,170)
	GroupBulletinBoardFrame:SetClampedToScreen(true)
	GBB.UserLevel = UnitLevel("player")
	GBB.Tool.RegisterEvent("PLAYER_LEVEL_UP", function() GBB.UserLevel = UnitLevel("player") end)
	GBB.UserName=(UnitFullName("player"))
	GBB.ServerName=GetRealmName()
	GBB.RealLevel = {} -- recently seen player levels
	GBB.RealLevel[GBB.UserName] = GBB.UserLevel

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
    if not GBB.DB.WindowSettings then GBB.DB.WindowSettings = {} end

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

	--- Track state for a headers collapsed between both the chat and tool request tabs.
	GBB.FoldedDungeons = setmetatable({}, {
		-- default to `GBB.DB.HeadersStartFolded` instead of nil when key first seen
		__index = function(self, key)
			rawset(self, key, GBB.DB.HeadersStartFolded)
			return GBB.DB.HeadersStartFolded
		end
	});

	-- Load LFGList tool module
	GBB.LfgTool:Load()
	-- Load Chat Request List module
	GBB.ChatRequests:Load()

	GBB.LFG_Timer=time()+GBB.LFG_UPDATETIME
	GBB.LFG_Successfulljoined=false

    local HeaderContainer = GroupBulletinBoardFrameHeaderContainer
    do -- setup the header "Title"/"Close"/ "Settings" buttons
        HeaderContainer.Title:SetText(string.format(GBB.TxtEscapePicture,GBB.MiniIcon).." ".. GBB.Metadata.Title)
        HeaderContainer.CloseButton:SetScript("OnClick", GBB.HideWindow)
		Mixin(HeaderContainer.SettingsButton, SettingsButtonMixin)
		SettingsButtonMixin.OnLoad(HeaderContainer.SettingsButton)
        -- HeaderContainerRefreshButton setup in LFGToolList.lua (only because its loaded after xml)
    end

    local FooterContainer = GroupBulletinBoardFrameFooterContainer
    do -- setup the Footers "Announcement" box for sending messages to a channel
        local ChannelSelectDropdown = FooterContainer.AnnounceChannelSelect
        local AnnounceButton = FooterContainer.AnnounceButton
        local AnnounceInput = FooterContainer.AnnounceInput
        --- Announcement Target Channel Selection Dropdown
        ChannelSelectDropdown:SetNormalFontObject(GBB.DB.FontSize)
        ChannelSelectDropdown:SetSelectionTranslator(function(selection) return selection.data end)
        local defaultChannel = GBB.L["lfg_channel"] ~= "" and GBB.L["lfg_channel"] or select(2, GetChannelList())
        local channelSelectSetting = OptionsUtil.GetSavedVarHandle(GBB.DB, "AnnounceChannel", defaultChannel);
        ChannelSelectDropdown:SetupMenu(function(frame, rootDescription)
            ---@cast rootDescription RootMenuDescriptionProxy
            local channelInfo = GBB.PhraseChannelList(GetChannelList())
            local isSelected = function(channel) return channel == channelSelectSetting:GetValue() end
            local setSelected = function(channel) channelSelectSetting:SetValue(channel) end
            for i, channel in pairs(channelInfo) do
                local button = rootDescription:CreateRadio(i..". "..channel.name, isSelected, setSelected, channel.name)
                button:SetEnabled(not channel.hidden)
            end
        end)
        ChannelSelectDropdown:HookScript("OnShow", function(self)
            -- hack: early in addon loading process `GetChannelList` can return nil; so re-generate the menu in these cases.
            if not self:GetText() then self:GenerateMenu() end
        end)
        --- Announce Message Input Box
        AnnounceInput:SetTextColor(0.6, 0.6, 0.6)
        AnnounceInput:SetText(GBB.L["msgRequestHere"])
        AnnounceInput:HighlightText(0, 0)
        AnnounceInput:SetCursorPosition(0)
        AnnounceInput:SetScript("OnEditFocusGained", function()
            local text = AnnounceInput:GetText()
            if text == GBB.L["msgRequestHere"] then -- clear default text if set
                AnnounceInput:SetTextColor(1, 1, 1)
                AnnounceInput:SetText("")
            end
        end)
        AnnounceInput:SetScript("OnTextChanged", function()
            local text = AnnounceInput:GetText()
            AnnounceButton:SetEnabled(text and text ~= "" and text ~= GBB.L["msgRequestHere"])
        end)
        --- Announcement Send Message Button
        AnnounceButton:SetNormalFontObject(GBB.DB.FontSize)
        AnnounceButton:SetText(GBB.L["BtnPostMsg"])
        AnnounceButton:Disable()
        AnnounceButton:SetScript("OnClick", function()
            local message = AnnounceInput:GetText()
            if message ~= nil and message ~= "" and message ~= GBB.L["msgRequestHere"] then
                GBB.SendMessage(GBB.DB.AnnounceChannel, message)
                AnnounceInput:ClearFocus()
            end
        end)

        -- Hide the announcement barUI if the option is disabled
        local displaySetting = OptionsUtil.GetSavedVarHandle(GBB.DB, "DisplayLFG")
        local updateVisibility = function(isVisible)
            AnnounceButton:SetShown(isVisible)
            AnnounceInput:SetShown(isVisible)
            ChannelSelectDropdown:SetShown(isVisible)
            FooterContainer:SetHeight(isVisible and 44 or 30)
        end
        displaySetting:AddUpdateHook(updateVisibility)
        updateVisibility(displaySetting:GetValue()) -- initial update
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
		{{"config","setup","options"},GBB.L["SlashConfig"],OptionsUtil.OpenCategoryPanel,1},
		{"about",GBB.L["SlashAbout"],OptionsUtil.OpenCategoryPanel, 6},
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
				GBB.CreateMinimapContextMenu(self.button, true)
			end
		end,
		GBB.Metadata.Title
	)

	---@type EditBox # making this local isnt required, just here for the luals linter
	local GroupBulletinBoardFrameResultsFilter = _G["GroupBulletinBoardFrameResultsFilter"];
	GroupBulletinBoardFrameResultsFilter:SetParent(GroupBulletinBoardFrame_ScrollFrame)
	GroupBulletinBoardFrameResultsFilter.filterPatterns = { };
	GroupBulletinBoardFrameResultsFilter:SetFontObject(GBB.DB.FontSize);
	GroupBulletinBoardFrameResultsFilter:SetTextColor(1, 1, 1, 1);
	GroupBulletinBoardFrameResultsFilter:HookScript("OnTextChanged", function(self) 
		GBB.ChatRequests.UpdateRequestList()
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
	GBB.ResizeFrameList()
	
	if GBB.DB.EscapeQuit then 
		tinsert(UISpecialFrames, GroupBulletinBoardFrame:GetName()) --enable ESC-Key to close
	end
	
	local setBorderResizingEnabled = GBB.Tool.EnableSize(GroupBulletinBoardFrame,8,nil,function()
		GBB.ResizeFrameList()
		GBB.SaveAnchors()
		GBB.ChatRequests.UpdateRequestList()
		GBB.LfgTool.OnFrameResized()
		end
	)

    function GroupBulletinBoardFrame:StopMovingAndSaveAnchors()
        GroupBulletinBoardFrame:StopMovingOrSizing()
        GBB.SaveAnchors()
    end

    do --- Setup Bulletin Board Window Mouse Interactions
        local windowSettings = {
            --- `true` if the board can be dragged around (aka not locked); default=`true`
            isMovable = OptionsUtil.GetSavedVarHandle(GBB.DB.WindowSettings, "isMovable", true),
            --- `false` if the board is **not** interactive (aka click-through); default=`true`
            isInteractive = OptionsUtil.GetSavedVarHandle(GBB.DB.WindowSettings, "isInteractive", true),
			--- `1` if the board is fully opaque; `0` if the board is fully transparent; default=`1`
			opacity = OptionsUtil.GetSavedVarHandle(GBB.DB.WindowSettings, "opacity", 1),
        }
		-- Handle updates to isMovable
		local setMovableStates = function(isMovable)
			setBulletinBoardMovableState(isMovable)
			setBorderResizingEnabled(isMovable)
		end
        windowSettings.isMovable:AddUpdateHook(setMovableStates)
        setMovableStates(windowSettings.isMovable:GetValue())
		-- Handle updates to isInteractive
        local setInteractiveStates = function(isInteractive)
            GBB.ChatRequests.UpdateInteractiveState()
            GBB.LfgTool:UpdateInteractiveState()
            GroupBulletinBoardFrame:EnableMouse(isInteractive and windowSettings.isMovable:GetValue())
        end
        windowSettings.isInteractive:AddUpdateHook(setInteractiveStates)
        setInteractiveStates(windowSettings.isInteractive:GetValue())
		-- Handle updates to opacity
		local setBulletinBoardOpacity = function(opacity)
			GroupBulletinBoardFrame:SetAlpha(opacity)
		end
		windowSettings.opacity:AddUpdateHook(setBulletinBoardOpacity)
		setBulletinBoardOpacity(windowSettings.opacity:GetValue())
    end

	GBB.PatternWho1=GBB.Tool.CreatePattern(WHO_LIST_FORMAT )
	GBB.PatternWho2=GBB.Tool.CreatePattern(WHO_LIST_GUILD_FORMAT )
	GBB.PatternOnline=GBB.Tool.CreatePattern(ERR_FRIEND_ONLINE_SS)
	
	GBB.Initalized=true
	
	GBB.InitGroupList()

	local TabEnum; ---@type {ChatRequests: number?, RecentPlayers: number?, LFGTool: number?}
	if isClassicEra then -- setup tabs
		local serverType = C_Seasons.GetActiveSeason()
		-- Note: tool currently only active in anniversary/fresh servers and SoD
		local useToolRequestTab = (serverType == Enum.SeasonID.SeasonOfDiscovery)
			or (serverType == Enum.SeasonID.Fresh)
			or (serverType == Enum.SeasonID.FreshHardcore);

		TabEnum = {
			-- Normal requests tab
			ChatRequests = GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabRequest, GroupBulletinBoardFrame_ScrollFrame),
			-- LFG Tool requests
			LFGTool = useToolRequestTab and GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabLfg, GBB.LfgTool.ScrollContainer) or nil,
			-- Past group members tab. (Inactive and broken)
			-- RecentPlayers = GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabGroup, GroupBulletinBoardFrame_GroupFrame);
		}
	else
		-- cata client for Hide all tabs except requests for the time being
		TabEnum = {
			ChatRequests = GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabRequest, GroupBulletinBoardFrame_ScrollFrame);
			LFGTool = GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabLfg, GBB.LfgTool.ScrollContainer);
			-- RecentPlayers = GBB.Tool.AddTab(GroupBulletinBoardFrame, GBB.L.TabGroup, GroupBulletinBoardFrame_GroupFrame);
		}
	end
	GBB.Tool.SelectTab(GroupBulletinBoardFrame, TabEnum.ChatRequests) -- default to requests tab

	if TabEnum.LFGTool then
		GBB.Tool.TabOnSelect(GroupBulletinBoardFrame, TabEnum.LFGTool, function()
			GBB.LfgTool.RefreshButton:GetScript("OnClick")() -- refresh search results
		end, true)
		-- only enable the tool tab whenever the player gains access to blizz LFGTool
		local isTabEnabledYet = false
		local trySetEnabled = function()
			if not isTabEnabledYet then
				local shouldEnable = C_LFGInfo.CanPlayerUsePremadeGroup();
				GBB.Tool.SetTabEnabled(GroupBulletinBoardFrame, TabEnum.LFGTool, shouldEnable)
				isTabEnabledYet = shouldEnable
			end
		end
		GroupBulletinBoardFrame:HookScript("OnShow", trySetEnabled);
		GBB.Tool.RegisterEvent("PLAYER_LEVEL_CHANGED", trySetEnabled);
	else GBB.LfgTool.ScrollContainer:Hide() end;

	if TabEnum.RecentPlayers then
		GBB.Tool.TabOnSelect(GroupBulletinBoardFrame, TabEnum.RecentPlayers, GBB.UpdateGroupList)
		-- update visibilty of recent player tab based on addon option.
		local setting = OptionsUtil.GetSavedVarHandle(GBB.DB, "EnableGroup")
		local manageTabVisibility = function(isSettingEnabled)
			if isSettingEnabled then -- Reshow all active tabs.
				GBB.Tool.TabShow(GroupBulletinBoardFrame)
			else -- hide the "EnableGroup" tab
				GBB.Tool.TabHide(GroupBulletinBoardFrame, TabEnum.RecentPlayers)
				GBB.Tool.SelectTab(GroupBulletinBoardFrame, TabEnum.ChatRequests)
			end
		end
		setting:AddUpdateHook(manageTabVisibility)
		manageTabVisibility(setting:GetValue()) -- run once to match the setting state.
	else GroupBulletinBoardFrame_GroupFrame:Hide() end;

    -- Modifications to the tab buttons
	-- 1. Allow the tabs to be able to reposition the bulletin board
	-- 2. Add a context menu to tabs that with option to:
	--   - lock/unlock the bulletin board
	--   - move tabs to top or bottom of the owner frame
	do
		local windowMovable = OptionsUtil.GetSavedVarHandle(GBB.DB.WindowSettings, "isMovable")
		local tabPosition = OptionsUtil.GetSavedVarHandle(GBB.DB.WindowSettings, "tabPosition", "bottom")
		for _, tabId in pairs(TabEnum) do
			local tab = GroupBulletinBoardFrame.Tabs[tabId]
			tab:HookScript("OnClick", function(self, clickType)
				if clickType == "RightButton" then
					MenuUtil.CreateContextMenu(tab, function(_, rootDesc)
						-- Lock/Unlock the bulletin board
						rootDesc:CreateButton(
							windowMovable:GetValue() and LOCK_WINDOW or UNLOCK_WINDOW,
							function() windowMovable:SetValue(not windowMovable:GetValue()) end -- onSelected
						):AddInitializer(function(frame)
							frame.fontString:SetFontObject("GameFontHighlightSmall")
						end)
						-- Move tabs to top or bottom of the owner frame
						local buttonText = GBB.L.MOVE_TABS_TO_TOP
						if tabPosition:GetValue() == "top" then
							buttonText = GBB.L.MOVE_TABS_TO_BOTTOM
						end
						rootDesc:CreateButton(buttonText, function()
							local newPosition = (tab.position == "top") and "bottom" or "top"
							tabPosition:SetValue(newPosition)
						end):AddInitializer(function(frame)
							frame.fontString:SetFontObject("GameFontHighlightSmall")
						end)
					end)
				end
			end)
			tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			tab:HookScript("OnDragStart", function() GroupBulletinBoardFrame:StartMoving() end)
			tab:HookScript("OnDragStop", function() GroupBulletinBoardFrame:StopMovingAndSaveAnchors() end)
		end
		local onWindowMovableUpdate = function(isMovable)
			local tabs = GroupBulletinBoardFrame.Tabs
			for _, tab in pairs(tabs) do
				if isMovable then tab:RegisterForDrag("LeftButton")
				else tab:RegisterForDrag() end
			end
		end
		windowMovable:AddUpdateHook(onWindowMovableUpdate)
		onWindowMovableUpdate(windowMovable:GetValue())
		tabPosition:AddUpdateHook(function(newPosition)
			GBB.Tool.ChangeTabPositions(GroupBulletinBoardFrame, newPosition)
		end)
		GBB.Tool.ChangeTabPositions(GroupBulletinBoardFrame, tabPosition:GetValue())
	end
	---@class AddonEnum
	local Enum = GBB.Enum; Enum.Tabs = TabEnum

	GameTooltip:HookScript("OnTooltipSetUnit", hooked_createTooltip)
	print(("|cFFFF1C1C Loaded: %s %s by %s"):format(GBB.Metadata.Title, GBB.Metadata.Version, GBB.Metadata.Author))
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
				GBB.CreateMinimapContextMenu(clickedframe, false)
			end
		end
	)
end

function GBB.OnLoad()	
	GBB.Tool.RegisterEvent("ADDON_LOADED",Event_ADDON_LOADED)
	GBB.Tool.RegisterEvent("CHAT_MSG_SYSTEM",Event_CHAT_MSG_SYSTEM)
	
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

---@return integer tabID
function GBB.GetSelectedTab()
	return GBB.Tool.GetSelectedTab(GroupBulletinBoardFrame);
end

function GBB.OnUpdate(elapsed)
	if GBB.Initalized==true then
		if GBB.LFG_Timer<time() and GBB.LFG_Successfulljoined==false then
			GBB.JoinLFG()
			GBB.LFG_Timer=time()+GBB.LFG_UPDATETIME
		end

		if GBB.ElapsedSinceListUpdate > 1 then
			if GBB.GetSelectedTab() == GBB.Enum.Tabs.ChatRequests then
				GBB.ChatRequests.UpdateRequestList()
			end
			GBB.ElapsedSinceListUpdate = 0;
		else
			GBB.ElapsedSinceListUpdate = GBB.ElapsedSinceListUpdate + elapsed;
		end;
	end
end