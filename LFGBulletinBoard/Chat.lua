local TOCNAME,GBB=...

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

	local ChannelsToAdd = { [GBB.L["lfg_channel"]] = 1, [GBB.L["world_channel"]] = 1, }

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

function GBB.SendMessage(ChannelName, Msg)
	local index = GetChannelName(ChannelName) -- It finds General is a channel at index 1
	if (index~=nil) then 
  		SendChatMessage(Msg , "CHANNEL", nil, index); 
	end
end

function GBB.AnnounceInit()
	GroupBulletinBoardFrameAnnounceMsg:SetTextColor(0.6,0.6,0.6)
	GroupBulletinBoardFrameAnnounceMsg:SetText(GBB.L["msgRequestHere"])
	GroupBulletinBoardFrameAnnounce:SetText(GBB.L["BtnPostMsg"])
	GroupBulletinBoardFrameAnnounceMsg:HighlightText(0,0) 
	GroupBulletinBoardFrameAnnounceMsg:SetCursorPosition(0)
	GroupBulletinBoardFrameAnnounce:Disable()

end

function GBB.GetFocus()
	local t= GroupBulletinBoardFrameAnnounceMsg:GetText()
	if t==GBB.L["msgRequestHere"]  then
		GroupBulletinBoardFrameAnnounceMsg:SetTextColor(1,1,1)
		GroupBulletinBoardFrameAnnounceMsg:SetText("")
		
	end
end

function GBB.EditAnnounceMessage_Changed()
	local t= GroupBulletinBoardFrameAnnounceMsg:GetText()
	if t==nil or t=="" or t==GBB.L["msgRequestHere"] then
		GroupBulletinBoardFrameAnnounce:Disable()
	else
		GroupBulletinBoardFrameAnnounce:Enable()
	end	
end

function GBB.Announce()
	local msg = GroupBulletinBoardFrameAnnounceMsg:GetText()
	
	if msg~= nil and msg~="" and msg~=GBB.L["msgRequestHere"]then
		GBB.SendMessage(GBB.DB.AnnounceChannel, msg)
		GroupBulletinBoardFrameAnnounceMsg:ClearFocus()
	end
end

function GBB.CreateChannelPulldown (frame, level, menuList)
	if level~=1 then return end
	local t= GBB.PhraseChannelList(GetChannelList())
	
	local info = UIDropDownMenu_CreateInfo()
 
	
	for i,channel in pairs(t) do
		info.text =  i..". "..channel.name
		info.checked = (channel.name == GBB.DB.AnnounceChannel)
		info.disabled = channel.hidden
		info.arg1 = i
		info.arg2 = channel.name
		info.func = function(self, arg1, arg2, checked)
				GBB.DB.AnnounceChannel=arg2
				GroupBulletinBoardFrameSelectChannel:SetText(arg2)
			end
		UIDropDownMenu_AddButton(info)
	end
end
