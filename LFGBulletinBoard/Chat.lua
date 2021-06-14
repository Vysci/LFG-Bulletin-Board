local TOCNAME,GBB=...
local L = setmetatable({}, {__index = function (t, k)  
	if GBB.L and GBB.L[k] then 
		return GBB.L[k]
	elseif GBB.locales.enGB and GBB.locales.enGB[k] then
		return GBB.locales.enGB[k]
	else
		return "["..k.."]"
	end	
end})

function GBB.CreateChatFrame(name, ...)
	local Frame = name and FCF_OpenNewWindow(name, true) or ChatFrame1
	if(...) then
		for index = 1, select('#', ...) do
			ChatFrame_AddMessageGroup(Frame, select(index, ...))
		end
	end
	return Frame
end

local function GetChannels()
	local channelList = {GetChannelList()}
	local channels = {}
	for i = 1, #channelList, 3 do 
		table.insert(channels, {
			id = channelList[i],
			name = channelList[i+1],
			isDisabled = channelList[i+2]
		})
	end

	return channels
end

local function SetChannels(ChanNames, Frame, ShouldRemove)
	ShouldRemove = ShouldRemove or false

	for k, _ in pairs(ChanNames) do
		if ShouldRemove == true and k ~= "" then
			ChatFrame_RemoveChannel(Frame, k)
		elseif  k ~= "" then
			ChatFrame_AddChannel(Frame, k)
		end
	end
end

local function MissingChannels(ChanNames, ChannelsToAdd)
	local missingChannels = {}
	for k, _ in pairs (ChannelsToAdd) do
		if ChanNames[k] == nil and ChanNames[k] ~= "" then
			missingChannels[k] = 1
		end
	end
	return missingChannels
end

function GBB.InsertChat()

	local chatFrameInit = false
	local tabName = "LFG"
	
	-- Don't create a new tab if it already exists
	for i = 1, NUM_CHAT_WINDOWS do
		local tab = _G["ChatFrame"..i.."Tab"]
		local name = tab:GetText()
		local shown =tab:IsShown()
		if name == tabName and shown == true then
			chatFrameInit = true
		end
	end

	if chatFrameInit == true then
		return
	end

	local ChannelsToAdd = { [L["lfg_channel"]] = 1, [L["world_channel"]] = 1, }

	-- Create new chat frame and new tab with no default message groups

	local Frame = GBB.CreateChatFrame(tabName, "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "BATTLEGROUND", "BATTLEGROUND_LEADER", "SYSTEM", "MONSTER_WHISPER", "MONSTER_BOSS_WHISPER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER")
	
	-- Get all channels the player has joined
	local channels = GetChannels()
	local channelNames = {}
	for _, v in pairs(channels) do
		channelNames[v["name"]] = v["isDisabled"]
	end

	-- Figures out what spammy LFG channels ie LookingForGroup the user hasn't joined
	-- if they are missing any channels then join them in the new chat tab
	local missingChannels = MissingChannels(channelNames, ChannelsToAdd)

	for k, _ in pairs(missingChannels) do
		JoinChannelByName(k, nil, Frame:GetID())
		-- since if missingChannels contains any channels that means they would be absent from channelNames
		channelNames[k] = 0
	end

	-- Join every single possible channel including any channels that user was missing before
	SetChannels(channelNames, Frame, false)

	-- Remove all LFG Spammy channels from default chat tab
	SetChannels(ChannelsToAdd, ChatFrame1, true)

	-- Set focus back to default tab and enable chat notifications
	FCF_SelectDockFrame(ChatFrame1)
    GBB.DB["NotifyChat"]=true
    GBB.OptionsUpdate()
end
