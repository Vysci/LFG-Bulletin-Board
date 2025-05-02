local TOCNAME,
	---@class Addon_RequestList : Addon_Tags, Addon_Tool
	GBB = ...;

local requestNil={dungeon="NIL",start=0,last=0,name=""}
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

-- Chat based request list module
local ChatRequests = { }
--------------------------------------------------------------------------------
-- local function/helpers
--------------------------------------------------------------------------------

local function SortRequests_NewestByTotalTime (a,b)
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
local function SortRequests_NewestByLastUpdate (a,b)
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
local function SortRequests_OldestByTotalTime (a,b)
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
local function SortRequests_OldestByLastUpdate (a,b)
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
	ChatRequests.clearOnNextUpdate = true
	C_FriendList.AddIgnore(playerName)
end
---@param request ChatRequestData request data object
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
	ChatRequests.UpdateRequestList()
end

--- Used alongside the `GroupBulletinBoardFrameResultsFilter` editbox to filter requests by their message content.
--- An empty editbox assumes no filter is set and all requests should be shown.
---@param message string
---@return boolean
local function doesRequestMatchResultsFilter(message)
	assert(
		GroupBulletinBoardFrameResultsFilter and GroupBulletinBoardFrameResultsFilter.GetFilters,
		"`GroupBulletinBoardFrameResultsFilter:GetFilters` not found. Forgot to call `GBB.Init`?"
	)

	local filters = GroupBulletinBoardFrameResultsFilter:GetFilters()
	for _, filter in ipairs(filters) do
		if not string.find(message:lower(), filter:lower(), nil, true) then
			return false
		end
	end
	return true
end

---Normalize and fuzzy a string based on common variations of dungeon/raid tags and punctuations.
---@type function
local getFuzzyNormalizedWords do
	-- normalizes uses of apostrophes/backticks, mostly useful for frFR.
	-- (e.g. "lf1m: zul`gurub or 2;s." => "lf1m: zul'gurub or 2's.")
	local normalizeApostrophes = function(str) return str:gsub("[´`;]","'"):gsub("'+", "'")  end
	-- concatenate characters separated by a `'` (keeps originals)
	-- (e.g. "lf1m: zul'gurub 2's." => "lfm1: zul'gurub zulgurub 2's 2s.")
	local fuzzyAroundApostrophes = function(str) return str:gsub("(%S)'(%S)", "%1%2 %1'%2") end
	-- replace all punctuation/whitespaces/control characters with single spaces.
	-- (e.g. "lf1m: zul'gurub zulgurub 2's 2s." => "lf1m zul gurub zulgurub 2 s 2s")
	-- NOTE: this makes it so that tags with punctuation in Tag.lua will NEVER match to anything from `getFuzzyNormalizedWords`
	local normalizePunctuation = function(str) return str:gsub("[%p%c]", " "):gsub("%s+", " ") end
	-- create combinations of spacings where characters are near numbers.
	-- (e.g. "lf1m icc25" => "lfm lf m lf1m lfm icc 25 icc25")
	local fuzzyCharactersAroundNumbers = function(str)
		return str
			-- remove numbers between letters
			-- (e.g. "lf1m zul gurub zulgurub 2 s 2s" => "lfm lf m lf1m lfm zul gurub zulgurub 2 s 2s")
			:gsub("(%l+)(%d+)(%l+)", "%1%2%3 %1%3 %1%2 %2%3 %1 %2 %3")
			-- add a space where numbers prefix or post-fix a possible tag. icc10 25icc => icc 10 25 icc
			-- assuming tag is more than 1 character to avoid the common 10m 25m 10h etc.)
			-- (e.g. "10m 25icc bwd25 10hc 9/12h" => "10m 25 icc bwd 25 10 hc 9/12h")
			:gsub(" (%d+)(%l%l+)", " %1 %2 %1%2"):gsub("^(%d+)(%l%l+) ", "%1%2 %1 %2")
			:gsub("(%D%l%l+)(%d+) ", "%1%2 %1 %2 "):gsub("(%D%l%l+)(%d+)$", "%1 %2 %1%2")
	end
	-- Splits words ending in suffixes into base+suffix combinations (e.g. "runs" -> "runs run s")
	local fuzzySuffixes = function(str)
		-- note: this is what catches most of the unintentional plural forms of certain tags
		-- eg: TRAVEL only has the tag "port" and not "ports". This function allows the string-
		-- to be split into "port s" allowing it to match TRAVEL. This happens for alot of other tags as well so we need to account for it.
		for _, suffix in ipairs(GBB.suffixTags) do -- "arena runs" => "arena runs run s"
			assert(suffix ~= "", "Suffixes should not be empty.")
			str, matches = str:gsub((("(%%w%%w+)(%s)$"):format(suffix)), "%1%2 %1 %2") -- end of string suffix
			str = str:gsub((("(%%w%%w+)(%s)%%s"):format(suffix)), "%1%2 %1 %2 ") -- end of substring suffixes
		end
		return str
	end
	local orderedMutations = {
		string.lower,
		normalizeApostrophes,
		fuzzyAroundApostrophes,
		normalizePunctuation,
		fuzzyCharactersAroundNumbers,
		fuzzySuffixes, -- expected to be called after normalizePunctuation
	}
	---Normalize and fuzzify a string based on common variations of dungeon/raid tags.
	---@param msg string
	---@return string[] list of words(ish) in the message
	getFuzzyNormalizedWords = function(msg)
		local fuzzyMessage = msg
		for _, fn in ipairs(orderedMutations) do
			fuzzyMessage = fn(fuzzyMessage)
		end
		local seen = {} ---@type table<string, boolean>
		local words = {} ---@type string[]
		for word in fuzzyMessage:gmatch("(%S+)") do
			if not seen[word] then
				seen[word] = true
				tinsert(words, word)
			end
		end
		if GBB.Tool.isUtf8String(fuzzyMessage) then
			fuzzyMessage = GBB.Tool.stripChars(fuzzyMessage)
			for word in fuzzyMessage:gmatch("(%S+)") do
				if not seen[word] then
					seen[word] = true
					tinsert(words, word)
				end
			end
		end
		return words
	end
end
--- Get the best dungeon/raid categories associated with a request message and player.
---@param msg string? The message to parse
---@param sender string? Message author/sender name
---@param fromLFGChannel boolean? true if the message is from server the LFG channel
---@return {[string]: boolean?} categories Categories associated with the message
---@return boolean? hasHeroicTag Whether the message contains keywords for the Heroic tag
---@return boolean? hasBlacklistTag Whether the message contains a blacklisted aka TAGBAD keyword
local function getRequestMessageCategories(msg, sender, fromLFGChannel)
	if msg==nil then return {} end
	---Maps a [tagKey] => boolean. `true` if the dungeon/category is associated with message
	local dungeons = {} ---@type table<string, boolean?>
	local hasBlacklistTag = false
	local hasHeroicTag = false
	local hasRunTag = false
	local hasSearchTag = false
	local runDungeonKey = nil

	if GBB.DB.TagsZhcn then
		for key, v in pairs(GBB.tagList) do
			if strfind(msg:lower(), key) then
				if v==GBB.TAGSEARCH then
					hasSearchTag=true
				elseif v==GBB.TAGBAD then
					break
				elseif v~=nil then
					dungeons[v]=true
				end
			end
		end
		for key, v in pairs(GBB.HeroicKeywords) do
			if strfind(msg:lower(), key) then
				hasHeroicTag = true
			end
		end
	elseif GBB.DB.TagsZhtw then
		for key, v in pairs(GBB.tagList) do
			if strfind(msg:lower(), key) then
				if v==GBB.TAGSEARCH then
					hasSearchTag=true
				elseif v==GBB.TAGBAD then
					break
				elseif v~=nil then
					dungeons[v]=true
				end
			end
		end
		for key, v in pairs(GBB.HeroicKeywords) do
			if strfind(msg:lower(), key) then
				hasHeroicTag = true
			end
		end
	else
		local wordList = getFuzzyNormalizedWords(msg)
		for _, word in ipairs(wordList) do
			if word == "run" or word == "runs" then hasRunTag = true end

			local categoryTagKey = GBB.tagList[word]

			if GBB.HeroicKeywords[word] ~= nil then hasHeroicTag = true end

			if categoryTagKey == nil then
				if GBB.tagList[word.."run"] ~= nil then
					runDungeonKey = GBB.tagList[word.."run"]
				end
			elseif categoryTagKey == GBB.TAGBAD then
				hasBlacklistTag = true
				break;
			elseif categoryTagKey == GBB.TAGSEARCH then
				hasSearchTag = true
			else
				local skip = false
				if dungeons.TRADE and categoryTagKey ~= "TRADE"
				then
					local customCategory = GBB.DB.CustomFilters[categoryTagKey] ---@type CustomFilter?
					-- only check custom categories if they are set to NOT includes item links
					-- all other categories are still checked for item links
					if not customCategory or not customCategory.includeItemLinks then
						-- if a trade keyword and dungeon keyword are both present, disambiguate between items and dungeons.
						-- useful for dungeons with more general search patterns like "Throne of Four Winds"
						local itemPattern =  "|hitem.*|h%[.*"..word..".*%]"
						if msg:lower():find(itemPattern) then skip = true end
					end
				end
				dungeons[categoryTagKey] = not skip
			end
		end
	end

	if hasRunTag and runDungeonKey and hasBlacklistTag == false then
		dungeons[runDungeonKey] = true
	end

	local authorPlayerLevel = 0
	if sender ~= nil then
		if GBB.RealLevel[sender] then
			authorPlayerLevel = GBB.RealLevel[sender]
		else
			for categoryKey, _ in pairs(dungeons) do
				if GBB.dungeonLevel[categoryKey][1] > 0 and authorPlayerLevel < GBB.dungeonLevel[categoryKey][1] then
					authorPlayerLevel = GBB.dungeonLevel[categoryKey][1]
				end
			end
		end
	end

	-- disambiguate between "Deadmines" and "Diremaul" based on authors level
	if dungeons["DEADMINES"]
	and not dungeons["DMW"]
	and not dungeons["DME"]
	and not dungeons["DMN"]
	and authorPlayerLevel > 0
	then
		if (authorPlayerLevel > 0) and (authorPlayerLevel < 40) then
			dungeons["DM"]=true
			dungeons["DM2"]=false
		else
			dungeons["DM"]=false
			dungeons["DM2"]=true
		end
	end

	local isValidRequest do
		-- anything with TAGSEARCH is always valid
		if hasSearchTag then isValidRequest = true end
		-- otherwise, anything with TRADE is always valid
		if dungeons.TRADE then isValidRequest = true end
		-- when UseAllInLFG option set, anything from LFG channel is always valid
		if GBB.DB.UseAllInLFG and fromLFGChannel then isValidRequest = true end
	end

	local validCategories = {}
	if isValidRequest and not hasBlacklistTag then
		-- check for the case of isolating travel services without the "lfg" tags
		if GBB.DB.IsolateTravelServices and dungeons.TRAVEL and not hasSearchTag then
			dungeons = { TRAVEL = true }
		else
			-- otherwise fix dungeons for messages with categories that have secondary keys
			for parentKey, secondaryKeys in pairs(GBB.dungeonSecondTags) do
				local messageHasSecondaryTags = false
				if dungeons[parentKey] == true then
					-- check if any secondary categories are present in the message
					for _, secondKey in ipairs(secondaryKeys) do
						-- check if secondary key is negative & get base key from it
						-- eg ["DEADMINES"] = { "DM", "-DMW", "-DME", "-DMN" }
						-- if secondKey is "-DMW" then the base dungeon key is "DMW"
						if secondKey:sub(1, 1) == "-" then secondKey = secondKey:sub(2) end
						if dungeons[secondKey] == true then
							messageHasSecondaryTags = true
							break;
						end
					end
					-- if no secondary keys were found active, then force include all non-negative secondary key categories
					-- eg for DEADMINES, it would only include "DM"
					if not messageHasSecondaryTags then
						for _, secondKey in ipairs(secondaryKeys) do
							if secondKey:sub(1, 1) ~= "-" then dungeons[secondKey] = true end
						end
					end
				end
			end
			if not GBB.DB.CombineSubDungeons then -- default behavior
				-- remove all parent categories who have secondary keys
				-- eg: this removes "DM2" and "SM2" "DEADMINES"
				for dungeonKey, _ in pairs(GBB.dungeonSecondTags) do
					if dungeons[dungeonKey] == true then dungeons[dungeonKey] = nil end
				end
			else -- otherwise, all secondary keys and include their parent keys
				for parentKey, secondaryKeys in pairs(GBB.dungeonSecondTags) do
					-- ignore DEADMINES it doesnt actually have sub dungeons
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
			-- if no dungeon categories were found in message, add the misc category.
			if next(dungeons) == nil then dungeons["MISC"] = true end
		end
		-- build the list of valid categories
		for categoryKey, include in pairs(dungeons) do
			if include == true then table.insert(validCategories, categoryKey) end
		end
	end

	return validCategories, hasHeroicTag, hasBlacklistTag
end

local fullNameByGUID = {} ---@type table<string, string>

--- Parse and incoming chat message, check if it can be categorized & update GBB.RequestList if so.
---@param msg string chat message to parse
---@param sender string message sender name
---@param senderGUID string message sender guid
---@param channel string message channel name
local function parseMessageForRequestList(msg, sender, senderGUID, channel)
	if GBB.Initalized==false or sender==nil or sender=="" or msg==nil or msg=="" or string.len(msg)<4 then
		return
	end

	local appendTime = tonumber("0." .. math.random(100,999)) -- Append a random "millisecond" value.
	local requestTime=tonumber(time() + appendTime)
	local _, classFile, _, _, _, _, _ = GetPlayerInfoByGUID(senderGUID)

	-- track server name by player guid (sometimes no server is seen on initial messages)
	local name, server = strsplit("-", sender)
	if server then fullNameByGUID[senderGUID] = sender end
	if not GBB.DB.RemoveRealm then
		sender = fullNameByGUID[senderGUID] or sender
		-- "mail" shows all realms
		-- "none" shows realm only when different realm
		-- "guild" like "none", but doesnt show guild realms names.
		name = Ambiguate(sender, "none")
	end

	if GBB.DB.RemoveRaidSymbols then msg = string.gsub(msg, "{.-}", "*")
	else msg = string.gsub(msg, "{.-}", GBB.Tool.GetRaidIcon) end

	local skipRequestListUpdate = false
	-- iterate over all requests in the list and check if a request from the same sender exists
	-- and append the message to the existing request if it exists
	for _, req in pairs(GBB.RequestList) do
		if type(req) == "table" and req.guid == senderGUID and req.last+GBB.COMBINEMSGTIMER>=requestTime then
			-- if the last request seen was for `TRADE`, then skip updating the request list
			if req.dungeon=="TRADE" then
				skipRequestListUpdate=true
				if msg ~= req.message then req.message = req.message.."|n"..msg end
			elseif req.dungeon ~= "DEBUG" and req.dungeon ~= "BAD" then
				if msg ~= req.message then msg = req.message.."|n"..msg end
				break;
			end
		end
	end
	if skipRequestListUpdate==true then return end

	local isLFGChannel = string.lower(GBB.L["lfg_channel"]) == string.lower(channel)
	local validCategories, isHeroic, isBlacklisted = getRequestMessageCategories(msg, name, isLFGChannel)

	if #validCategories == 0 then -- add to debug list and exit early if no valid categories
		if GBB.DB.OnDebug then
			local index = #GBB.RequestList + 1
			GBB.RequestList[index] = {}
			GBB.RequestList[index].name = name
			GBB.RequestList[index].guid = senderGUID
			GBB.RequestList[index].class = classFile
			GBB.RequestList[index].start = requestTime
			GBB.RequestList[index].dungeon = isBlacklisted and "BAD" or "DEBUG"
			GBB.RequestList[index].message = msg
			GBB.RequestList[index].IsHeroic = isHeroic
			GBB.RequestList[index].last = requestTime
		end
		return;
	end

	local isFriend = C_FriendList.IsFriend(senderGUID)
	local isGuildMember = IsInGuild() and IsGuildMember(senderGUID)
	local isPastPlayer = GBB.GroupTrans[name] ~= nil
	local notifyCategories = {}
	for _, categoryKey in ipairs(validCategories) do
		-- look for a pre-existing request (if the incoming request is not a trade request)
		local existingRequestIndex
		if categoryKey ~= "TRADE" then
			for requestIdx, req in pairs(GBB.RequestList) do
				if type(req) == "table" and req.guid == senderGUID and req.dungeon == categoryKey then
					existingRequestIndex = requestIdx
					break;
				end
			end
		end
		local isRaid = GBB.RaidList[categoryKey] ~= nil
		-- if no pre-existing request was found, create a new one
		---@class ChatRequestData
		local requestData = existingRequestIndex and GBB.RequestList[existingRequestIndex] or {}
		if not existingRequestIndex then
			GBB.RequestList[#GBB.RequestList + 1] = requestData
			requestData.guid = senderGUID
			requestData.class = classFile
			requestData.start = requestTime
			requestData.dungeon = categoryKey
			-- only append non-new trade/misc categories to the notification text
			if GBB.FilterDungeon(categoryKey, isHeroic, isRaid)
			and categoryKey ~= "TRADE" and categoryKey ~= "MISC" and GBB.FoldedDungeons[categoryKey] ~= true
			then
				table.insert(notifyCategories, GBB.dungeonNames[categoryKey])
			end
		end
		requestData.name = name -- update name incase realm found
		requestData.IsGuildMember = isGuildMember
		requestData.IsFriend = isFriend
		requestData.IsPastPlayer = isPastPlayer
		requestData.message = msg
		requestData.IsHeroic = isHeroic
		requestData.IsRaid = isRaid
		requestData.last = requestTime
	end

	if #notifyCategories > 0 and GBB.AllowInInstance() then
		if GBB.DB.NotifyChat then
			local relationIcon = (
				(isFriend
					and string.format(GBB.TxtEscapePicture, GBB.FriendIcon)
					or "")
				..(isGuildMember
					and string.format(GBB.TxtEscapePicture, GBB.GuildIcon)
					or "")
				..(isPastPlayer
					and string.format(GBB.TxtEscapePicture, GBB.PastPlayerIcon)
					or "")
			);
			local playerLink = "|Hplayer:"..name.."|h[|c"..GBB.Tool.ClassColor[classFile].colorStr..name.."|r]|h"

			if GBB.DB.OneLineNotification then -- short text notification
				DEFAULT_CHAT_FRAME:AddMessage(
					("%s%s%s: %s"):format(GBB.MSGPREFIX, playerLink, relationIcon, msg),
					GBB.DB.NotifyColor.r, GBB.DB.NotifyColor.g, GBB.DB.NotifyColor.b
				)
			else -- full text notification
				local categories = notifyCategories[2] and table.concat(notifyCategories, ", ") or notifyCategories[1]
				DEFAULT_CHAT_FRAME:AddMessage(
					GBB.MSGPREFIX..string.format(GBB.L["msgNewRequest"], playerLink..relationIcon, categories),
					GBB.DB.NotifyColor.r, GBB.DB.NotifyColor.g, GBB.DB.NotifyColor.b, 0.8
				)
				DEFAULT_CHAT_FRAME:AddMessage(("%s: %s"):format(playerLink..relationIcon, msg),
					GBB.DB.NotifyColor.r, GBB.DB.NotifyColor.g, GBB.DB.NotifyColor.b
				)
			end
		end
		if GBB.DB.NotifySound then
			PlaySound(GBB.NotifySound, GBB.DB.NotifySoundChannel)
		end
	end

	-- clear any existing sender requests that were not generated from the request message
	for requestIdx, req in pairs(GBB.RequestList) do
		if type(req) == "table" then
			if req.guid == senderGUID and req.last ~= requestTime then
				GBB.RequestList[requestIdx] = nil
				ChatRequests.clearOnNextUpdate = true
			end
		end
	end
end
--------------------------------------------------------------------------------
-- Header Frame
--------------------------------------------------------------------------------

---@class RequestListHeaderFrame : Frame
---@field categoryKey string Aka `dungeonKey`, identifies the dungeon/raid/category this header represents
local HeaderFrameMixin = {}
function HeaderFrameMixin:OnLoad()
	self:SetPoint("RIGHT", GroupBulletinBoardFrame_ScrollChildFrame, "RIGHT")
	self:SetHeight(20)
	self.Name = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	self.Name:SetAllPoints()
	self.Name:SetJustifyV("MIDDLE")

	self:SetScript("OnMouseDown", self.OnMouseDown)
	self:SetScript("OnEnter", self.OnEnter)
	self:SetScript("OnLeave", self.OnLeave)
end

---@param header RequestListHeaderFrame
local updateHeaderTextColor = function(header)
	local categoryKey = header.categoryKey
	assert(categoryKey, "No category/dungeon key found for header", header)
	local textColor = NORMAL_FONT_COLOR
	if header:IsMouseOver() then textColor = HIGHLIGHT_FONT_COLOR
	elseif GBB.DB.ColorOnLevel
		and GBB.dungeonLevel[categoryKey][1] and GBB.dungeonLevel[categoryKey][1] > 0
	then textColor = GBB.Tool.GetDungeonDifficultyColor(categoryKey) end
	header.Name:SetTextColor(textColor:GetRGBA())
end
function HeaderFrameMixin:UpdateTextLayout()
	local dungeon = self.categoryKey
	local categoryName = GBB.dungeonNames[dungeon]
	if GBB.FoldedDungeons[dungeon] then categoryName = "[+] "..categoryName end
	local levelRange = GRAY_FONT_COLOR:WrapTextInColorCode(GBB.LevelRange(dungeon))

	updateHeaderTextColor(self)

	self.Name:SetText(("%s %s"):format(categoryName, levelRange))
	self.Name:SetFontObject(GBB.DB.FontSize)
	local lineHeight = self.Name:GetLineHeight()
	local textPadding = 4 -- px, vspace around text
	self.Name:SetHeight(lineHeight)
	self:SetHeight(lineHeight + textPadding)
end

function HeaderFrameMixin:UpdateInteractiveState()
	-- When NOT isInteractive, only the Name should handle mouse events
	local isInteractive = GBB.DB.WindowSettings.isInteractive
	self:EnableMouse(isInteractive)
	self.Name:EnableMouse(not isInteractive)
	self.Name:ClearAllPoints()
	if not isInteractive then
		self:SetScript("OnMouseDown", nil)
		self:SetScript("OnEnter", nil)
		self:SetScript("OnLeave", nil)
		self.Name:SetScript("OnMouseDown", function(_, button) self:OnMouseDown(button) end)
		self.Name:SetScript("OnEnter", function() self:OnEnter() end)
		self.Name:SetScript("OnLeave", function() self:OnLeave() end)
		self.Name:SetPoint("TOPLEFT")
	else
		self:SetScript("OnMouseDown", self.OnMouseDown)
		self:SetScript("OnEnter", self.OnEnter)
		self:SetScript("OnLeave", self.OnLeave)
		self.Name:SetScript("OnMouseDown", nil)
		self.Name:SetScript("OnEnter", nil)
		self.Name:SetScript("OnLeave", nil)
		self.Name:SetAllPoints()
	end
end
function HeaderFrameMixin:OnEnter() updateHeaderTextColor(self) end
function HeaderFrameMixin:OnLeave() updateHeaderTextColor(self) end

local unfoldAllHeaders = function()
	for k, v in pairs(GBB.FoldedDungeons) do
		GBB.FoldedDungeons[k] = false
	end
	ChatRequests.UpdateRequestList()
end
local foldAllHeaders = function()
	for k, v in pairs(GBB.FoldedDungeons) do
		GBB.FoldedDungeons[k] = true
	end
	ChatRequests.UpdateRequestList()
end
function HeaderFrameMixin:OnMouseDown(button)
	if not self.categoryKey then return end
	-- Shift + Left-Click
	if button=="LeftButton" and IsShiftKeyDown() then
		if GBB.FoldedDungeons[self.categoryKey] then
			unfoldAllHeaders()
		else
			foldAllHeaders()
		end
	-- Left-Click
	elseif button=="LeftButton" then
		GBB.FoldedDungeons[self.categoryKey] = not GBB.FoldedDungeons[self.categoryKey]
		ChatRequests.UpdateRequestList()
	-- Any other mouse click
	else
		GBB.CreateSharedBoardContextMenu(self, self.categoryKey)
	end
end

local headerFramePool = CreateObjectPool(function(pool)
	local header = CreateFrame("Frame", nil, GroupBulletinBoardFrame_ScrollChildFrame)
	Mixin(header, HeaderFrameMixin)
	HeaderFrameMixin.OnLoad(header)
	return header
end, Pool_HideAndClearAnchors)

---@param scrollPos integer The current bottom pos from the top of the scroll frame
---@param dungeon string The dungeons "key" ie DM|MC|BWL|etc
---@return integer newScrollPos The updated bottom pos of the scroll frame after adding the header
local function CreateHeader(scrollPos, dungeon)
	local header = headerFramePool:Acquire() ---@type RequestListHeaderFrame
	local bottomMargin = 3 -- px, vspace beneath the header
	header.categoryKey = dungeon
	header:UpdateTextLayout()
	header:UpdateInteractiveState()
	header:Show()
	header:SetPoint("RIGHT", GroupBulletinBoardFrame_ScrollChildFrame, "RIGHT")
	header:SetPoint("TOPLEFT", GroupBulletinBoardFrame_ScrollChildFrame, "TOPLEFT", 0, -scrollPos)
	scrollPos = scrollPos + header:GetHeight()
	return scrollPos + bottomMargin
end
--------------------------------------------------------------------------------
-- Request Entry Frame
--------------------------------------------------------------------------------

---@class RequestListEntryFrame: Frame
---@field requestData ChatRequestData? GBB.RequestList data object, expected for `UpdateTextLayout`
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

---@param entry RequestListEntryFrame]
---@param request ChatRequestData
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
-- Public API
--------------------------------------------------------------------------------

--- initialize the chat request list module. ran on addon load.
function ChatRequests:Load()
	GBB.RequestList = {}
	-- set up chat event handlers for parsing messages for the request list
	local onChatEvent = function(msg,name,_,_,_,_,_,channelID,channel,_,_,guid)
		if not GBB.Initalized then return end
		if GBB.DBChar and GBB.DBChar.channel and GBB.DBChar.channel[channelID] then
			parseMessageForRequestList(msg,name,guid,channel)
		end
	end
	local onGuildChatEvent = function(...)
		local args = { ... }
		args[8] = 20; args[9] = GBB.L.GuildChannel;
		onChatEvent(unpack(args))
	end
	GBB.Tool.RegisterEvent("CHAT_MSG_CHANNEL", onChatEvent)
	GBB.Tool.RegisterEvent("CHAT_MSG_GUILD", onGuildChatEvent)
	GBB.Tool.RegisterEvent("CHAT_MSG_OFFICER", onGuildChatEvent)

	-- Timer-Stuff
	self.clearOnNextUpdate = true -- clear out expired requests from the request list on next UpdateRequestList call
	self.nextClearTime = math.huge -- next _scheduled_ time to clear out expired requests from the request list
end

--- generates items for display in the scroll list.
---@param clearNeeded boolean? if true, clear out expired requests from the request list
function ChatRequests.UpdateRequestList(clearNeeded)
	-- Filter out stale/expired requests from the request list
	local currentTime = time()
	if (clearNeeded or ChatRequests.clearOnNextUpdate)
	or (ChatRequests.nextClearTime < currentTime)
	then
		local validRequests = {}
		-- allow triple the time before requests are removed from the underlying data completely
		local maxRequestAge = GBB.DB.TimeOut * 3
		ChatRequests.nextClearTime = math.huge
		for _, req in pairs(GBB.RequestList) do
			if type(req) == "table" then
				local isExpired = currentTime > req.last + maxRequestAge
				if not isExpired then
					-- schedule next clear based on the oldest valid request
					if req.last < ChatRequests.nextClearTime then ChatRequests.nextClearTime = req.last end
					validRequests[#validRequests + 1] = req
				end
			end
		end
		GBB.RequestList = validRequests
		ChatRequests.nextClearTime = ChatRequests.nextClearTime + maxRequestAge
		ChatRequests.clearOnNextUpdate = false
	end

	if not GroupBulletinBoardFrame:IsVisible() then return end

	-- sort requests
	if GBB.DB.OrderNewTop then
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.RequestList, SortRequests_NewestByTotalTime)
		else
			table.sort(GBB.RequestList, SortRequests_NewestByLastUpdate)
		end
	else
		if GBB.DB.ShowTotalTime then
			table.sort(GBB.RequestList, SortRequests_OldestByTotalTime)
		else
			table.sort(GBB.RequestList, SortRequests_OldestByLastUpdate)
		end
	end

    local scrollHeight = 0
	local count = 0
	local itemsInCategory = 0
	local ownRequestDungeons = {}
	local itemSpacing = 6
	local existingHeaders = {}

	if GBB.DBChar.DontFilterOwn then -- force include own requests
		for _, req in pairs(GBB.RequestList) do
			local timeOutMod = 2 -- allow double the time before own requests are considered expired
			if type(req) == "table" and req.guid == UnitGUID("player") 
				and currentTime <= req.last + (GBB.DB.TimeOut * timeOutMod) then
				ownRequestDungeons[req.dungeon]=true
			end
		end
	end

	local baseItemHeight = 25

	-- Hide all exisiting scroll frame elements
	headerFramePool:ReleaseAll()
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
					existingHeaders[requestDungeon] = true
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
end

-- Update interactive state of all elements based on .isInteractive and .isMovable settings
function ChatRequests.UpdateInteractiveState()
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
    for header in headerFramePool:EnumerateActive() do
		header:UpdateInteractiveState()
    end
    for entry in requestEntryFramePool:EnumerateActive() do
		entry:UpdateInteractiveState()
	end
end

GBB.ChatRequests = ChatRequests

--- Sends a pre formatted join request message (`DB.JoinRequestMessage`) to a player.
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

---@class SharedBoardContextMenuApiOverrides
local ctxMenuEmptyOverrides = { -- table mostly here to give type hints,
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
	if not apiOverrides then apiOverrides = ctxMenuEmptyOverrides;
	else for k,v in pairs(ctxMenuEmptyOverrides) do apiOverrides[k] = apiOverrides[k] or v end end

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
				foldAll = apiOverrides.foldAll.onSelect or foldAllHeaders,
				unfoldAll = apiOverrides.unfoldAll.onSelect or unfoldAllHeaders,
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
