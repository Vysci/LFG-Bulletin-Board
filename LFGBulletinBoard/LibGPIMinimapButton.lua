local TOCNAME,Addon = ...
Addon.MinimapButton=Addon.MinimapButton or {}
local MinimapButton=Addon.MinimapButton

local function BottomZoom(button)
	local deltaX, deltaY = 0, 0
	if not button.Lib_GPI_MinimapButton.isMouseDown then
		deltaX = 0.05
		deltaY = 0.05
	end
	button.Lib_GPI_MinimapButton.icon:SetTexCoord( deltaX, 1 - deltaX,  deltaY, 1 - deltaY)
end

local function onUpdate(button)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local w=((Minimap:GetWidth() / 2) + 5)
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	local dx,dy= px - mx,py - my
	local dist=math.sqrt(dx*dx+dy*dy)/w
	if button.Lib_GPI_MinimapButton.db.lockDistance then
		dist=1
	else
		if dist<1 then dist=1 elseif dist>2 then dist=2 end
	end
	
	button.Lib_GPI_MinimapButton.db.distance=dist
	button.Lib_GPI_MinimapButton.db.position = math.deg(math.atan2(dy, dx)) % 360	
	button.Lib_GPI_MinimapButton.UpdatePosition()
end

local function onDragStart(button)
	button.Lib_GPI_MinimapButton.isMouseDown = true
	if button.Lib_GPI_MinimapButton.db.lock==false then
		button:LockHighlight()
		BottomZoom(button)
		button:SetScript("OnUpdate", onUpdate)		
		button.Lib_GPI_MinimapButton.isDraggingButton = true
	end
	GameTooltip:Hide()	
end

local function onDragStop(button)
	button:SetScript("OnUpdate", nil)
	button.Lib_GPI_MinimapButton.isMouseDown = false
	BottomZoom(button)
	button:UnlockHighlight()
	button.Lib_GPI_MinimapButton.isDraggingButton = false	
end

local function onEnter(button)
	if button.Lib_GPI_MinimapButton.isDraggingButton or not button.Lib_GPI_MinimapButton.Tooltip then return end
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT", 0,0	)
	GameTooltip:AddLine(button.Lib_GPI_MinimapButton.Tooltip)		
	GameTooltip:Show()
end

local function onLeave(button)
	GameTooltip:Hide()
end

local function onClick(button, b)
	GameTooltip:Hide()
	if button.Lib_GPI_MinimapButton.onClick then
		button.Lib_GPI_MinimapButton.onClick(button.Lib_GPI_MinimapButton, b)
	end		
end

local function onMouseDown(button)
	button.Lib_GPI_MinimapButton.isMouseDown = true
	BottomZoom(button)
end

local function onMouseUp(button)
	button.Lib_GPI_MinimapButton.isMouseDown = false
	BottomZoom(button)
end
		
function MinimapButton.Init(DB,Texture,DoOnClick,Tooltip)
	MinimapButton.db=DB
	MinimapButton.onClick=DoOnClick
	MinimapButton.Tooltip=Tooltip
	MinimapButton.isMinimapButton=true
	
	local button = CreateFrame("Button", "Lib_GPI_Minimap_"..TOCNAME, Minimap)
	
	MinimapButton.button=button
	button.Lib_GPI_MinimapButton=MinimapButton
	
	button:SetFrameStrata("MEDIUM")
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(136477) --"Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture(136430) --"Interface\\Minimap\\MiniMap-TrackingBorder"
	overlay:SetPoint("TOPLEFT")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture(136467) --"Interface\\Minimap\\UI-Minimap-Background"
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(Texture)
	icon:SetPoint("TOPLEFT", 7, -6)
	
	MinimapButton.icon = icon
	MinimapButton.isMouseDown = false
	MinimapButton.isDraggingButton = false
	
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
		
	
	button:SetScript("OnClick", onClick)
		
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)
	
	button:SetScript("OnMouseDown", onMouseDown)
	button:SetScript("OnMouseUp", onMouseUp) 
		
	if MinimapButton.db.position==nil then MinimapButton.db.position=225 end
	if MinimapButton.db.distance==nil then MinimapButton.db.distance=1 end
	if MinimapButton.db.visible==nil then MinimapButton.db.visible=true end
	if MinimapButton.db.lock==nil then MinimapButton.db.lock=false end
	if MinimapButton.db.lockDistance==nil then MinimapButton.db.lockDistance=false end

	
	BottomZoom(button)
	MinimapButton.UpdatePosition()
end


local MinimapShapes = {
	-- quadrant booleans (same order as SetTexCoord)
	-- {upper-left, lower-left, upper-right, lower-right}
	-- true = rounded, false = squared
	["ROUND"] 			= {true, true, true, true},
	["SQUARE"] 			= {false, false, false, false},
	["CORNER-TOPLEFT"] 		= {true, false, false, false},
	["CORNER-TOPRIGHT"] 		= {false, false, true, false},
	["CORNER-BOTTOMLEFT"] 		= {false, true, false, false},
	["CORNER-BOTTOMRIGHT"]	 	= {false, false, false, true},
	["SIDE-LEFT"] 			= {true, true, false, false},
	["SIDE-RIGHT"] 			= {false, false, true, true},
	["SIDE-TOP"] 			= {true, false, true, false},
	["SIDE-BOTTOM"] 		= {false, true, false, true},
	["TRICORNER-TOPLEFT"] 		= {true, true, true, false},
	["TRICORNER-TOPRIGHT"] 		= {true, false, true, true},
	["TRICORNER-BOTTOMLEFT"] 	= {true, true, false, true},
	["TRICORNER-BOTTOMRIGHT"] 	= {false, true, true, true},
}

function MinimapButton.UpdatePosition()
	local w = ((Minimap:GetWidth() / 2) + 10) * MinimapButton.db.distance
	local h = ((Minimap:GetHeight() / 2) + 10) * MinimapButton.db.distance
	--local r=math.rad(MinimapButton.db.position)
	--MinimapButton.button:SetPoint("CENTER", Minimap, "CENTER", w * math.cos(r), h * math.sin(r))
	local rounding=10
	local angle = math.rad(MinimapButton.db.position) -- determine position on your own
	local y = math.sin(angle)
	local x = math.cos(angle)
	local q = 1;
	if x < 0 then
		q = q + 1;	-- lower
	end
	if y > 0 then
		q = q + 2;	-- right
	end
	local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local quadTable = MinimapShapes[minimapShape];
	if quadTable[q] then
		x = x*w;
		y = y*h;
	else
		local diagRadius = math.sqrt(2*(w)^2)-rounding
		x = math.max(-w, math.min(x*diagRadius, w))
		local diagRadius = math.sqrt(2*(h)^2)-rounding
		y = math.max(-h, math.min(y*diagRadius, h))
	end
	MinimapButton.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	
	
	if MinimapButton.db.visible then
		MinimapButton.Show()
	else
		MinimapButton.Hide()
	end		
end

function MinimapButton.Show()
	MinimapButton.db.visible = true
	MinimapButton.button:SetParent(Minimap)
	MinimapButton.button:Show()
end

function MinimapButton.Hide()
	MinimapButton.db.visible = false
	MinimapButton.button:Hide()
	MinimapButton.button:SetParent(nil)
end

function MinimapButton.SetTexture(Texture)
	MinimapButton.icon:SetTexture(Texture)
	MinimapButton.icon:SetPoint("TOPLEFT", 7, -6)
	MinimapButton.icon:SetSize(17, 17)
end

function MinimapButton.SetTooltip(Text)
	MinimapButton.Tooltip=Text
end
