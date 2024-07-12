local TOCNAME,---@type string
	---@class Addon_LibGPIOptions	
	Addon = ...;

---@alias savedValue string|number|boolean|table<string|number, savedValue>

---@class OptionsBuilderModule
local Options = {}
Addon.OptionsBuilder = Options

--------------------------------------------------------------------------------
-- Locals, Helpers, Privates, etc
--------------------------------------------------------------------------------

local debug = false -- dev override
local print = function(...)
	if (Addon.DB and Addon.DB.OnDebug) or debug then
		_G.print(WrapTextInColorCode(("[%s]:"):format(TOCNAME), NORMAL_FONT_COLOR:GenerateHexColor()), ...);
	end
end

local categoriesByName = { } ---@type table<string, table>
local addToBlizzardSettings = function(frame) -- alternative to the deprecated `InterfaceOptions_AddCategory`
	-- Frames are required to have OnCommit, OnDefault, and OnRefresh functions even if their implementations are empty.
	frame.OnCommit = Options.onCommit
	frame.OnDefault = Options.onDefault
	frame.OnRefresh = Options.onRefresh
	if frame.parent then
		local parent = Settings.GetCategory(frame.parent)
		local subcategory = Settings.RegisterCanvasLayoutSubcategory(parent, frame, frame.name)
		subcategory.ID = frame.name
		Settings.RegisterAddOnCategory(subcategory)
		categoriesByName[frame.name] = subcategory
	else
		local category = Settings.RegisterCanvasLayoutCategory(frame, frame.name)
		category.ID = frame.name
		Settings.RegisterAddOnCategory(category)
		categoriesByName[frame.name] = category
	end
end

---@alias SavedVarHandle.updateHook fun(newValue: savedValue)
---@class SavedVarHandle
local handlePrototype = {
	updateHooks = {}, ---@type {[SavedVarHandle.updateHook]: true?}
	default = nil, ---@type savedValue?
	SetValue = function(handle, value) ---@param value savedValue
		local old = handle.db[handle.var]
		if old == value then return end
		handle.db[handle.var] = value
		print(("Setting Updated - [\"%s\"]|n Previous: %s => Current: %s")
			:format(handle.var, tostring(old), tostring(value)));
		for func in pairs(handle.updateHooks) do func(value) end -- fire update hooks with new value as argument
	end,
	GetValue = function(handle)
		return handle.db[handle.var]
	end,
	SetToDefault = function(handle, nullable)
		if not nullable and handle.default == nil then return end
		handle:SetValue(handle.default)
	end,
	---@param func SavedVarHandle.updateHook called with the updated value, **only called on value changes**
	AddUpdateHook = function(handle, func)
		handle.updateHooks[func] = true
	end,
	RemoveUpdateHook = function(handle, func)
		handle.updateHooks[func] = nil
	end
}
local SavedVarRegistry = {
	tracked = {}, -- [db][var] = handle, how handles to the same variable are shared
	GetHandle = function(self, db, var, default)
		assert(db and var, "SavedVarRegistry:GetHandle(db, var, default) - db and var are required", 
			{ db = db, var = var, default = default }
		);
		local handle ---@type SavedVarHandle
		if not self.tracked[db] or not self.tracked[db][var] then
			self.tracked[db] = self.tracked[db] or {}
			handle = setmetatable({ db = db, var = var, updateHooks = {} }, { __index = handlePrototype })
			self.tracked[db][var] = handle
		elseif self.tracked[db] and self.tracked[db][var] then
			handle = self.tracked[db][var]
		end
		assert(handle, "SavedVarRegistry:GetHandle() - failed to create handle", { db = db, var = var, default = default })
		assert((handle.default == nil or default == nil) or default == handle.default, -- one default value per session
			"SavedVarRegistry:GetHandle() - SavedVar cannot have more than one assigned default",
			{ incoming = default, previous = handle.default }
		)
		if default ~= nil and handle.default == nil then
			handle.default = default
		end
		if db[var] == nil and handle.default ~= nil then -- initialize first time saved vars with default.
			handle:SetToDefault()
		end
		return handle
	end,
}
local registeredFrameHandles = {} ---@type table<Frame, SavedVarHandle>

-- This mixin provides helpers for interfacing frames with SavedVarHandles
---@class RegisteredFrameMixin
local RegisteredFrameMixin = {
	---@param frame Frame
	Init = function(self, frame)
		self = self ---@class RegisteredFrameMixin
		self.frame = frame
		self.updateFunc = nil ---@type SavedVarHandle.updateHook?
	end,
	SetSavedValue = function(self, value)
		local handle = registeredFrameHandles[self.frame]
		if handle then handle:SetValue(value) end
	end,
	GetSavedValue = function(self)
		local handle = registeredFrameHandles[self.frame]
		if handle then return handle:GetValue() end
	end,
	SetToDefault = function(self)
		local handle = registeredFrameHandles[self.frame]
		if handle then handle:SetToDefault() end
	end,
	---Note: Atm this mixin only allows for one update hook to be registered per frame.
	---Subsequent calls will overwrite the previous hook (including any set by the optionsBuilder methods).
	---Use the raw handle for better control over multiple hooks.
	---@param updateFunc SavedVarHandle.updateHook called with the updated value, **only called on value changes**
	OnSavedVarUpdate = function(self, updateFunc)
		if not updateFunc then return end
		local handle = registeredFrameHandles[self.frame]
		self:ClearUpdateHook()
		self.updateFunc = updateFunc
		if handle then handle:AddUpdateHook(updateFunc) end
	end,
	ClearUpdateHook = function(self)
		local handle = registeredFrameHandles[self.frame]
		if handle and self.updateFunc then handle:RemoveUpdateHook(self.updateFunc) end
		self.updateFunc = nil
	end
}

local function RegisteredFrame_OnShiftRightClick(frame, button)
	if button == "RightButton" and IsShiftKeyDown() then
		if frame.SetToDefault then frame:SetToDefault() end
	end
end

--------------------------------------------------------------------------------
-- Public/Interface
--------------------------------------------------------------------------------

---Registers a frame with a user setting/saved variable. Returns the frame and its saved variable handle
---Frames may only be registered to one saved var atm (todo expand to multiple).
---@generic F
---@param frame F Expects a frame, but accepts any table object.
---@return F|RegisteredFrameMixin, SavedVarHandle
Options.RegisterFrameWithSavedVar = function(frame, db, var, default)
	local varHandle = SavedVarRegistry:GetHandle(db, var, default)
	local prevHandle = registeredFrameHandles[frame]
	if prevHandle and prevHandle ~= varHandle then ---@cast frame RegisteredFrameMixin
		frame:ClearUpdateHook(); -- if previously registered remove any existing update hooks
	else
		-- CreateAndInitFromMixin calls `RegisteredFrameMixin:Init(frame)`
		frame = Mixin(frame, CreateAndInitFromMixin(RegisteredFrameMixin, frame))
	end
	registeredFrameHandles[frame] = varHandle
	return frame, varHandle
end

---Gets or creates a registry handle to a saved variable. given its table and key.
---@type fun(db: table, var: string, default: savedValue?): SavedVarHandle
Options.GetSavedVarHandle = function(db, var, default)
	return SavedVarRegistry:GetHandle(db, var, default) 
end

---Initializes the options builder. Clears child widget tables. Accepts, onCommit, onRefresh, and onDefault functions.
---they are once called for each settings category panel.
---@param onCommit fun(panel:SettingsCategoryPanel) function called when the "close" button is clicked
---@param onRefresh fun(panel:SettingsCategoryPanel) function to called when the settings frame will be redrawn
---@param onDefault fun(panel:SettingsCategoryPanel) function to call when settings should reset to default values
function Options.Init(onCommit,onRefresh,onDefault)
	Options.Prefix=TOCNAME.."Options"
	Options.onCommit=onCommit
	Options.onRefresh=onRefresh
	Options.onDefault=onDefault
	Options.CategoryPanels={}
	Options.Frames={}
	Options.CheckBoxes={}
	Options.Color={}
	Options.Buttons={}
	Options.EditBoxes={}
	Options.Vars={} -- any saved variable tables postfixed with _db
	Options.Index={}
	Options.Frames.count=0
	Options.scale=1
end
		
function Options.DoOk() -- Hooked to the `OnCommit` handler, called when the `close` button is pressed.
	-- Done with RegisterFrameWithSavedVar now
	-- for name, cbox in pairs(Options.CheckBoxes) do
	-- 	if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]] = cbox:GetChecked()
	-- 	end
	-- end

	-- for name,color in pairs(Options.Color) do
	-- 	if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].r=color.ColR
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].g=color.ColG
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].b=color.ColB
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].a=color.ColA
	-- 	end
	-- end	
	
	-- for name,edit in pairs(Options.EditBoxes) do
	-- 	if Options.Vars[name .. "_onlynumbers"] then 
	-- 		Options.Vars[name .. "_db"][Options.Vars[name]] = edit:GetNumber()
	-- 	else
	-- 		if Options.Vars[name.."_suggestion"] and Options.Vars[name.."_suggestion"]~="" then
	-- 			if edit:GetText()==Options.Vars[name.."_suggestion"] then
	-- 				Options.Vars[name .. "_db"] [Options.Vars[name]] = ""
	-- 			else
	-- 				Options.Vars[name .. "_db"] [Options.Vars[name]] = edit:GetText()
	-- 			end
	-- 		else
	-- 			Options.Vars[name .. "_db"] [Options.Vars[name]] = edit:GetText()
	-- 		end
	-- 	end
	-- end
end

-- `OnCancel` function has been deprecated by blizzard, most changes are committed immediately now.
-- `OnRefresh` is called every time the canvas view is refreshed (swapping categories, opening, etc.)
-- `DoRefresh` is hooked into the `OnRefresh` event in `Options.lua` setup.
function Options.DoRefresh()
	-- for name,cbox in pairs(Options.CheckBoxes) do 
	-- 	if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
	-- 		cbox:SetChecked( Options.Vars[name .. "_db"] [Options.Vars[name]] )
	-- 	end
	-- end
	
	-- for name,color in pairs(Options.Color) do
	-- 	if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
	-- 		color:GetNormalTexture():SetVertexColor(
	-- 			Options.Vars[name .. "_db"] [Options.Vars[name]].r,
	-- 			Options.Vars[name .. "_db"] [Options.Vars[name]].g,
	-- 			Options.Vars[name .. "_db"] [Options.Vars[name]].b,
	-- 			Options.Vars[name .. "_db"] [Options.Vars[name]].a
	-- 		)
	-- 		color.ColR,color.ColG,color.ColB,color.ColA=Options.Vars[name .. "_db"] [Options.Vars[name]].r, Options.Vars[name .. "_db"] [Options.Vars[name]].g,	Options.Vars[name .. "_db"] [Options.Vars[name]].b,	Options.Vars[name .. "_db"] [Options.Vars[name]].a
	-- 	end
	-- end
	
	-- for name,edit in pairs(Options.EditBoxes) do
	-- 	if Options.Vars[name .. "_onlynumbers"] then 
	-- 		edit:SetNumber( Options.Vars[name .. "_db"] [Options.Vars[name]] )
	-- 	else
	-- 		edit:SetText( Options.Vars[name .. "_db"] [Options.Vars[name]] )
	-- 		EditBox_OnFocusLost(edit)
	-- 	end		
	-- end
end
	
-- Hooked to the `OnDefault` handler, called when the `default` button is pressed. 
function Options.DoDefault() -- note: default button does not exist for addons anymore, has to be implemented.
	-- for name,cbox in pairs(Options.CheckBoxes) do
	-- 	if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]]= Options.Vars[name .. "_init"]
	-- 	end
	-- end

	-- for name,color in pairs(Options.Color) do
	-- 	if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].r = Options.Vars[name .. "_init"].r
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].g = Options.Vars[name .. "_init"].g
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].b = Options.Vars[name .. "_init"].b
	-- 		Options.Vars[name .. "_db"] [Options.Vars[name]].a = Options.Vars[name .. "_init"].a

	-- 	end
	-- end
	
	-- for name,edit in pairs(Options.EditBoxes) do
	-- 	Options.Vars[name .. "_db"] [Options.Vars[name]]= Options.Vars[name .. "_init"]
	-- end
	for _, savedVars in pairs(SavedVarRegistry.tracked) do -- will handle any registered saved variables
		for _, handle in pairs(savedVars) do
			handle:SetToDefault()
		end
	end
	Options:DoRefresh()
end
	
function Options.SetScale(x)
	Options.scale=x
end

---Creates a new settings category and returns its display frame.
---@param title string
---@param noHeader boolean?
---@param scrollable boolean?
---@return SettingsCategoryPanel|Frame
function Options.AddNewCategoryPanel(title, noHeader, scrollable)
	local categoryIdx = #Options.CategoryPanels + 1
	local frameName = Options.Prefix.."Category"..categoryIdx
	---@class SettingsCategoryPanel: Frame
	local panelFrame = CreateFrame("Frame", frameName, UIParent)
	Options.CategoryPanels[categoryIdx] = panelFrame
	Options.CurrentPanel = panelFrame
	panelFrame.name = title
	if categoryIdx > 1 then
		panelFrame.parent = Options.CategoryPanels[1].name
	end
	addToBlizzardSettings(panelFrame)
	if scrollable then
		-- Create the scrolling parent frame and size it to fit the settins panel
		local scrollFrame = CreateFrame("ScrollFrame", frameName.."ScrollFrame", Options.CurrentPanel, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 4, -4) 
		scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4) 

		-- Create the scrolling child frame, set its width to fit, and give it an arbitrary minimum height
		local scrollChild = CreateFrame("Frame", frameName.."ScrollChild", scrollFrame) 
		scrollFrame:SetScrollChild(scrollChild)
		scrollChild:SetSize((InterfaceOptionsFramePanelContainer:GetWidth()), 100)

		Options.CategoryPanels["scroll"..categoryIdx] = scrollFrame
		Options.CategoryPanels["scrollChild"..categoryIdx] = scrollChild
		Options.CurrentPanel = scrollChild --[[@as Frame]]
		panelFrame.ScrollChild = scrollChild
	end
	local panelHeader = Options.CurrentPanel:CreateFontString(frameName.."Title", "OVERLAY", "GameFontNormalLarge");
	if noHeader==true then
		panelHeader:SetHeight(1)
	else
		panelHeader:SetText(title)
	end
	panelHeader:SetPoint("TOPLEFT", 10, -10)
	panelHeader:SetScale(Options.scale)
	Options.NextRelativ=frameName.."Title"
	Options.NextRelativX=25
	Options.NextRelativY=0
	
	return Options.CurrentPanel
end

---@param width number? Defaults to 10.
function Options.Indent(width)
	if width==nil then width=10 end
	Options.NextRelativX = Options.NextRelativX + width
end
	
function Options.InLine()
	Options.inLine=true
	Options.LineRelativ=nil
end

function Options.EndInLine()
	Options.inLine=false
	Options.LineRelativ=nil
end	
	
---@param width number? Defaults to 310. 
function Options.SetRightSide(width)
	Options.NextRelativ=Options.Prefix.."Category".. #Options.CategoryPanels .."Title"
	Options.NextRelativX= (width or 310) / Options.scale
	Options.NextRelativY=0
end
	
function Options.AddVersion(version)
	local i="version_"..#Options.CategoryPanels
	Options.Frames[i] = Options.CurrentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	Options.Frames[i]:SetText(version)
	Options.Frames[i]:SetPoint("BOTTOMRIGHT", -10, 10)
	Options.Frames[i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
	return Options.Frames[i]
end

---@param text string
---@return FontString
function Options.AddHeaderToCurrentPanel(text)
	local c=Options.Frames.count+1
	Options.Frames.count=c		
	local CatName=Options.Prefix .. "Cat" .. c
	Options.Frames[CatName] = Options.CurrentPanel:CreateFontString(CatName, "OVERLAY", "GameFontNormal")
	Options.Frames[CatName]:SetText('|cffffffff' .. text .. '|r')
	Options.Frames[CatName]:SetPoint("TOPLEFT",Options.NextRelativ,"BOTTOMLEFT", Options.NextRelativX, Options.NextRelativY-10)
	Options.Frames[CatName]:SetFontObject("GameFontNormalLarge")
	Options.Frames[CatName]:SetScale(Options.scale)
	Options.NextRelativ=CatName
	Options.NextRelativX=0
	Options.NextRelativY=0
	return Options.Frames[CatName]
end

---@param header FontString
---@param text string
function Options.EditHeaderText(header, text)
	local c=Options.Frames.count+1
	header:SetText('|cffffffff' .. text .. '|r')	
end

---@param text string
---@param onClick fun()?
---@return Button
function Options.AddButtonToCurrentPanel(text, onClick)
	local c=Options.Frames.count+1
	Options.Frames.count=c	
	local ButtonName=Options.Prefix .."BUTTON_"..c
			
	Options.Buttons[ButtonName] = CreateFrame("Button", ButtonName, Options.CurrentPanel, "UIPanelButtonTemplate")
	Options.Buttons[ButtonName]:ClearAllPoints()
	
	if Options.inLine~=true or Options.LineRelativ ==nil then
		Options.Buttons[ButtonName]:SetPoint("TOPLEFT", Options.NextRelativ,"BOTTOMLEFT", Options.NextRelativX, Options.NextRelativY)
		Options.NextRelativ=ButtonName
		Options.LineRelativ=ButtonName
		Options.NextRelativX=0
		Options.NextRelativY=0
	else
		Options.Buttons[ButtonName]:SetPoint("TOP", Options.LineRelativ,"TOP", 0, 0)
		Options.Buttons[ButtonName]:SetPoint("LEFT", Options.LineRelativ.."Text","RIGHT", 10, 0)
		Options.LineRelativ=ButtonName
	end
	
	Options.Buttons[ButtonName]:SetScale(Options.scale)
	Options.Buttons[ButtonName]:SetScript("OnClick", onClick)
	Options.Buttons[ButtonName]:SetText(text)
	Options.Buttons[ButtonName]:SetWidth( Options.Buttons[ButtonName]:GetTextWidth()+20 )
	Options.Buttons[ButtonName]:SetHeight(25)
	return Options.Buttons[ButtonName]
end

---@param dbTable table expects either character or account SavedVars table
---@param key string variables key in the SavedVars table
---@param default boolean default db value if key is not set
---@param labelText string label text for the checkbox
---@param width number?
---@return CheckButton|RegisteredFrameMixin
function Options.AddCheckBoxToCurrentPanel(dbTable,key,default,labelText,width)
	local frameIdx=Options.Frames.count+1
	Options.Frames.count=frameIdx	
	local buttonName=Options.Prefix .."CheckBox"..frameIdx
	default = not not default -- ensure init is a boolean

	---@type CheckButton|{Text: FontString, func: function} -- Create checkbox frame
	local checkButton = CreateFrame("CheckButton", buttonName, Options.CurrentPanel, "ChatConfigCheckButtonTemplate")
	checkButton:ClearAllPoints()
	checkButton:SetScale(Options.scale)
	checkButton.Text:SetText(labelText)
	if dbTable ~= nil and key ~= nil then
		-- note: RegisterFrameWithSavedVar has been set up to also initialize first time saved vars.
		if dbTable[key] == nil then dbTable[key] = default end
		checkButton = Options.RegisterFrameWithSavedVar(checkButton, dbTable, key, default)
		checkButton:SetChecked(checkButton:GetSavedValue())
		--`.func` is called in the `OnClick` handler for the template.
		-- see https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/FrameXML/ChatConfigFrame.xml#L177
		checkButton.func = function(self, isChecked)
			checkButton:SetSavedValue(isChecked)
		end
		checkButton:OnSavedVarUpdate(function(newValue)
			checkButton:SetChecked(newValue)
		end)
		checkButton:SetScript("OnMouseDown", RegisteredFrame_OnShiftRightClick)
	end
	if width then
		checkButton.Text:SetWidth(width)
		checkButton.Text:SetNonSpaceWrap(false)
		checkButton.Text:SetMaxLines(1)
		checkButton:SetHitRectInsets(0, -width, 0,0)
	else
		checkButton:SetHitRectInsets(0, -(checkButton.Text:GetStringWidth() - 2), 0, 0)
	end
	if not Options.inLine or not Options.LineRelativ then
		checkButton:SetPoint('TOPLEFT', Options.NextRelativ, 'BOTTOMLEFT', Options.NextRelativX, Options.NextRelativY)
		Options.NextRelativ = buttonName
		Options.LineRelativ = buttonName
		Options.NextRelativX = 0
		Options.NextRelativY = 0
	else
		checkButton:SetPoint('TOP', Options.LineRelativ, 'TOP', 0, 0)
		checkButton:SetPoint('LEFT', Options.LineRelativ..'Text', 'RIGHT', 10, 0)
		Options.LineRelativ = buttonName
	end
	if dbTable == nil and key == nil then 
		checkButton:Hide()
	end
	return checkButton
end

---@param dbTable table expects either character or account SavedVars table
---@param key string variables key in the SavedVars table
---@param default {r: number, g: number, b: number, a: number} default color values. falls-back to white.
---@param labelText string label text for the color button
---@param width number?
---@return SwatchButton
function Options.AddColorSwatchToCurrentPanel(dbTable,key,default,labelText,width)
	local frameIdx=Options.Frames.count+1
	Options.Frames.count=frameIdx
	local textFrame = Options.AddTextToCurrentPanel(labelText, width, true) ---@type FontString
	textFrame:SetTextColor(1, 1, 1)
	local size = 16;
	textFrame:AdjustPointsOffset(0, textFrame:GetHeight() - size) -- move text down a bit for bigger swatch buttons
	local swatchButtonName = Options.Prefix..'ColorSwatch'..frameIdx
	-- Initialize Button
	local swatchButton = CreateFrame('Button', swatchButtonName, Options.CurrentPanel)
	swatchButton:SetNormalTexture('Interface\\ChatFrame\\ChatFrameColorSwatch')
	swatchButton.Bg = swatchButton:GetNormalTexture()
	swatchButton:SetWidth(size)
	swatchButton:SetHeight(size)
	swatchButton:ClearAllPoints()
	swatchButton:SetPoint('LEFT', Options.NextRelativ, 'RIGHT', 5, 0)
	swatchButton:SetScale(Options.scale)
	swatchButton.Highlight = swatchButton:CreateTexture(swatchButtonName..'Background', 'BACKGROUND')
	swatchButton.Highlight:SetPoint('CENTER')
	swatchButton.Highlight:SetWidth(size - 2)
	swatchButton.Highlight:SetHeight(size - 2)
	swatchButton.Highlight:SetColorTexture(1, 1, 1, 1)
	swatchButton:SetScript("OnEnter", function()
		swatchButton.Highlight:SetVertexColor(1.0, 0.82, 0.0)
	end)
	swatchButton:SetScript("OnLeave", function()
		swatchButton.Highlight:SetVertexColor(1.0, 1.0, 1.0)
	end)
	-- note: first time initialization could also be done by `GetHandle` inside of `RegisterFrameWithSavedVar
	default = default or {r = 1, g = 1, b = 1, a = 1}
	if dbTable ~= nil and key ~= nil and dbTable[key] == nil
	then dbTable[key] = CopyTable(default) end
	
	-- Register button with saved var handler
	---@class SwatchButton:RegisteredFrameMixin, Button
	swatchButton = Options.RegisterFrameWithSavedVar(swatchButton, dbTable, key, default)
	local syncWithSavedVar = function()
		local color = swatchButton:GetSavedValue() -- method from RegisterFrameWithSavedVar
		swatchButton.Bg:SetVertexColor(color.r, color.g, color.b, color.a)
	end
	swatchButton:OnSavedVarUpdate(syncWithSavedVar);
	syncWithSavedVar() -- run once to set the initial color
	local onSwatchColorChange = function() -- passed to ColorPickerFrame handlers.
		local a = 1.0 - OpacitySliderFrame:GetValue()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		swatchButton:SetSavedValue({r=r, g=g, b=b, a=a})
	end
	swatchButton:SetScript("OnMouseDown", RegisteredFrame_OnShiftRightClick)
	-- Connect to ColorPickerFrame
	swatchButton:SetScript("OnClick", function(self)
		local original = swatchButton:GetSavedValue()
		ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, 1.0 - original.a
		ColorPickerFrame.swatchFunc = onSwatchColorChange
		ColorPickerFrame.opacityFunc = onSwatchColorChange
		ColorPickerFrame.cancelFunc = function()
			swatchButton:SetSavedValue(original)
		end
		ColorPickerFrame:SetColorRGB(original.r, original.g, original.b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)
	return swatchButton
end

---@param dbTable table
---@param key string
---@param default any 
---@param MenuItems table<any, string>
function Options.AddDropdownToCurrentPanel(dbTable,key,default,MenuItems) 
	local c=Options.Frames.count+1
	Options.Frames.count=c	
	local ButtonName=Options.Prefix .."BUTTON_"..c
	Options.Vars[ButtonName]=key
	Options.Vars[ButtonName.."_init"]=default
	Options.Vars[ButtonName.."_db"]=dbTable
	
	if dbTable~=nil and key~=nil then
		if dbTable[key] == nil then dbTable[key]=default end
	end

	Options.Buttons[ButtonName] = CreateFrame("Frame", ButtonName , Options.CurrentPanel, "UIDropDownMenuTemplate")
	if Options.inLine~=true or Options.LineRelativ ==nil then
		Options.Buttons[ButtonName]:SetPoint("TOPLEFT", Options.NextRelativ,"BOTTOMLEFT", Options.NextRelativX, Options.NextRelativY)
		Options.NextRelativ=ButtonName
		Options.LineRelativ=ButtonName
		Options.NextRelativX=0
		Options.NextRelativY=0
	else
		Options.Buttons[ButtonName]:SetPoint("TOP", Options.LineRelativ,"TOP", 0, 0)
		Options.Buttons[ButtonName]:SetPoint("LEFT", Options.LineRelativ.."Text","RIGHT", 0, 3)
		Options.LineRelativ=ButtonName
	end

	local dropdown_width = 0
    local dd_title = Options.Buttons[ButtonName]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	for _, item in pairs(MenuItems) do -- Sets the dropdown width to the largest item string width.
        dd_title:SetText(item)
        local text_width = dd_title:GetStringWidth() + 20
        if text_width > dropdown_width then
            dropdown_width = text_width
        end
    end
	UIDropDownMenu_SetWidth(Options.Buttons[ButtonName], dropdown_width)
	UIDropDownMenu_SetText(Options.Buttons[ButtonName], dbTable[key])
	
	-- Create and bind the initialization function to the dropdown menu
	UIDropDownMenu_Initialize(Options.Buttons[ButtonName], function(self, level, menuList)
	 local info = UIDropDownMenu_CreateInfo()
	 for k, v in pairs(MenuItems) do
		info.text = v
		info.func = function(b)
			UIDropDownMenu_SetText(Options.Buttons[ButtonName], b.value)
			dbTable[key] = b.value
			default = b.value
		end
		UIDropDownMenu_AddButton(info)
	   end
	end)
end

---@param checkBox CheckButton|{Text: FontString, func: function}
---@param dbTable table expects either character or account SavedVars table
---@param key string
---@param value boolean? new isChecked value
---@param labelText string new label text for the checkbox
---@param width number?
function Options.EditCheckBox(checkBox,dbTable,key,value,labelText,width)
	value = not not value -- cast to boolean	
	if dbTable~=nil and key~=nil then
		if dbTable[key] == nil then dbTable[key]=value end
		checkBox = Options.RegisterFrameWithSavedVar(checkBox, dbTable, key, value)
		checkBox.func = function(self, isChecked)
			checkBox:SetSavedValue(isChecked)
		end
		checkBox:Show()
	end
	checkBox.Text:SetText(labelText)
	if width then
		checkBox.Text:SetWidth(width)
		checkBox.Text:SetNonSpaceWrap(false)
		checkBox.Text:SetMaxLines(1)
		checkBox:SetHitRectInsets(0, -width, 0,0)
	else
		checkBox:SetHitRectInsets(0, -(checkBox.Text:GetStringWidth()-2), 0,0)
	end
	if dbTable == nil and key == nil then
		checkBox:Hide()
	end
end

---@param text string
---@param width number?
---@param center boolean? if false text topleft justified
---@return FontString
function Options.AddTextToCurrentPanel(text,width,center)
	local textbox = Options.CurrentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textbox:SetText(text)
	textbox:SetPoint("TOPLEFT",Options.NextRelativ,"BOTTOMLEFT", Options.NextRelativX, Options.NextRelativY-2)
	textbox:SetScale(Options.scale)

	if width==nil or width==0 then 
		textbox:SetWidth(textbox:GetStringWidth())
	elseif width<0 then
		if string.sub(Options.CurrentPanel:GetName(),  -11)== "ScrollChild" then
			textbox:SetPoint("RIGHT",Options.CurrentPanel:GetParent():GetParent(),"RIGHT",width,0)
		else
			textbox:SetPoint("RIGHT",width,0)
		end
		if not center then 
			textbox:SetJustifyH("LEFT")
			textbox:SetJustifyV("TOP")
		end
	else
		textbox:SetWidth(width)
		if not center then 
			textbox:SetJustifyH("LEFT")
			textbox:SetJustifyV("TOP")
		end
	end
	Options.NextRelativ=textbox
	Options.NextRelativX=0
	Options.NextRelativY=0
	return textbox
end

---@param textFrame FontString
---@param text string
---@param width number?
---@param center boolean?
function Options.EditText(textFrame,text,width,center)
	textFrame:SetText(text)
	if width==nil or width==0 then 
		textFrame:SetWidth(textFrame:GetStringWidth())
	elseif width<0 then
		textFrame:SetPoint("RIGHT",width,0)
		if not center then 
			textFrame:SetJustifyH("LEFT")
			textFrame:SetJustifyV("TOP")
		end
	else
		textFrame:SetWidth(width)
		if not center then 
			textFrame:SetJustifyH("LEFT")
			textFrame:SetJustifyV("TOP")
		end
	end
end

---@param dbTable table
---@param key string
---@param default string default db value if key is not set
---@param labelText string label text displayed to the left of the edit box
---@param width number?
---@param labelWidth number?
---@param isNumeric boolean?
---@param tooltip string? text to display in a tooltip when the mouse hovers over the edit box
---@param sampleText string? text to display in the edit box when it is empty
---@return EditBox|RegisteredFrameMixin
function Options.AddEditBoxToCurrentPanel(dbTable,key,default,labelText,width,labelWidth,isNumeric,tooltip,sampleText)
	width = width or 200
	local frameIdx = Options.Frames.count + 1
	local editBoxName = Options.Prefix..'EditBox'..frameIdx..key
	local labelName = editBoxName..'Text'
	Options.Frames.count = frameIdx
	-- Set up the label
	local label = Options.CurrentPanel:CreateFontString(labelName, 'OVERLAY', 'GameFontNormal')
	label:SetText(labelText)
	label:SetTextColor(1, 1, 1, 1)
	label:SetPoint('TOPLEFT', Options.NextRelativ, 'BOTTOMLEFT', Options.NextRelativX, Options.NextRelativY - 2)
	label:SetScale(Options.scale)
	if labelWidth == nil or labelWidth == 0 then
		label:SetWidth(label:GetStringWidth())
	else
		label:SetWidth(labelWidth)
		label:SetJustifyH('LEFT')
		label:SetJustifyV('TOP')
	end
	---@type EditBox|{Instructions: FontString} # Create the edit box
	local editBox = CreateFrame('EditBox', editBoxName, Options.CurrentPanel, 'InputBoxInstructionsTemplate')
	editBox:SetPoint('TOPLEFT', label, 'TOPRIGHT', 5, 5)
	editBox:SetScale(Options.scale)
	editBox:SetWidth(width)
	editBox:SetHeight(20)
	label:SetHeight(editBox:GetHeight() - 10)
	editBox:SetNumeric(isNumeric)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject('ChatFontNormal') -- matches InputBoxTemplate font
	editBox.Instructions:SetFontObject('ChatFontNormal')
	editBox.Instructions:SetText(sampleText or '')
	-- Register the edit box with the saved variable
	if dbTable[key] == nil then dbTable[key] = default end
	local cleanupText = function(text)
		-- edge case for custom-tag editboxes; lowercase and remove extra inner spaces
		if dbTable == GroupBulletinBoardDB.Custom then
			text = text:lower():gsub('%s+', ' ')
		end
		return text:trim()
	end
	editBox = Options.RegisterFrameWithSavedVar(editBox, dbTable, key, default)
	-- Better to just update the saved var OnEnterPressed only.
	editBox:SetScript('OnEnterPressed', function()
		local isNumeric = editBox:IsNumeric()
		local input = not isNumeric and cleanupText(editBox:GetText()) or editBox:GetNumber();
		assert(not isNumeric or type(input) == 'number',
			'EditBox_OnEnterPressed() - failed to get number from edit box',
			{input = input, isNumeric = isNumeric, text = editBox:GetText()}
		);
		editBox:SetSavedValue(input)
		editBox:ClearFocus() -- utilize OnEditFocusLost to sync with saved var
	end)
	local syncWithSavedVar = function()
		editBox:SetText(editBox:GetSavedValue())
	end
	editBox:SetScript('OnEditFocusLost', syncWithSavedVar);
	syncWithSavedVar();       -- run once to sync with initial value
	editBox:SetCursorPosition(0) -- reset cursor incase saved text was added
	-- Set tooltip if provided
	if tooltip and tooltip ~= '' then
		editBox:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_TOP', 0, 0)
			GameTooltip:SetMinimumWidth(self:GetWidth())
			GameTooltip:ClearLines()
			GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
			GameTooltip:Show()
		end)
		editBox:SetScript('OnLeave', GameTooltip_Hide)
	end
	Options.NextRelativ=labelName
	Options.NextRelativX=0
	Options.NextRelativY=-10
	return editBox
end

---@parm factor number? Defaults to 1. Negative values move the spacer up.
function Options.AddSpacerToPanel(factor)
	Options.NextRelativY=Options.NextRelativY-20*(factor or 1)
end

---@param panel number? Unused. Defaults to panel 1 (main addons panel)
function Options.OpenCategoryPanel(panel)
	Settings.OpenToCategory(Options.CategoryPanels[1].name)
	-- if panel > 1 then
	-- 	-- there is currently no way to open to a specific subcategory without tainting the ui
	-- 	-- see https://github.com/Stanzilla/WoWUIBugs/issues/285 for more info
	-- 	SettingsPanel:SelectCategory(categoriesByName[Options.CategoryPanels[panel].name]) 
	-- end
end

