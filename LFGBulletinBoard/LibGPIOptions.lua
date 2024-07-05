local TOCNAME,---@type string
	---@class Addon_LibGPIOptions	
	Addon = ...;

---@class OptionsBuilderModule
local Options = {}
Addon.OptionsBuilder = Options

--------------------------------------------------------------------------------
-- Locals, Helpers, Privates, etc
--------------------------------------------------------------------------------

local function EditBox_TooltipHide(self)
	GameTooltip:Hide()
end

local function EditBox_OnFocusGained(self)
	local name=self:GetName().."_suggestion"
	if self.GPI_Options and self.GPI_Options.Vars and self.GPI_Options.Vars[name] then 
		if self:GetText()==self.GPI_Options.Vars[name] then
			self:SetText("")
			self:SetTextColor(1,1,1)				
		end
	end	
end

local function EditBox_OnFocusLost(self)
	local name=self:GetName().."_suggestion"
	if self.GPI_Options and self.GPI_Options.Vars and self.GPI_Options.Vars[name] then 
		if self:GetText()=="" then
			self:SetTextColor(0.6,0.6,0.6)
			self:SetText(self.GPI_Options.Vars[name])
			self:HighlightText(0,0) 
			self:SetCursorPosition(0)
		end
	end	
end

local function EditBox_OnEnterPressed(self)
	self:ClearFocus()
end

local function EditBox_TooltipShow(self)
	local name=self:GetName().."_tooltip"
	if self.GPI_Options and self.GPI_Options.Vars and self.GPI_Options.Vars[name] then 
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0,0	)
		GameTooltip:SetMinimumWidth(self:GetWidth())
		GameTooltip:ClearLines()
		GameTooltip:AddLine(self.GPI_Options.Vars[name],0.9,0.9,0.9,true)
		GameTooltip:Show()
	end		
end

local function CheckBox_OnRightClick(checkbox, func)
	checkbox:SetScript("OnMouseDown",function(button)
		if button == "RightButton" then
			func()
		end
	end)
end

--------------------------------------------------------------------------------
-- Public/Interface
--------------------------------------------------------------------------------

---Initializes the options builder. Clears child widget tables. Accepts, onCommit, onRefresh, and onDefault functions.
---they are once called for each settings category panel.
---@param doOk fun(panel:Frame) function called when the "close" button is clicked
---@param doCancel fun(panel:Frame) function to called when the settings frame will be redrawn
---@param doDefault fun(panel:Frame) function to call when settings should reset to default values
function Options.Init(doOk,doCancel,doDefault)
	Options.Prefix=TOCNAME.."O_"
	Options._DoOk=doOk
	Options._DoCancel=doCancel
	Options._DoDefault=doDefault

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
		
function Options.DoOk()
	for name, cbox in pairs(Options.CheckBoxes) do
		if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
			Options.Vars[name .. "_db"] [Options.Vars[name]] = cbox:GetChecked()
		end
	end
	
	for name,color in pairs(Options.Color) do
		if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
			Options.Vars[name .. "_db"] [Options.Vars[name]].r=color.ColR
			Options.Vars[name .. "_db"] [Options.Vars[name]].g=color.ColG
			Options.Vars[name .. "_db"] [Options.Vars[name]].b=color.ColB
			Options.Vars[name .. "_db"] [Options.Vars[name]].a=color.ColA
		end
	end	
	
	for name,edit in pairs(Options.EditBoxes) do
		if Options.Vars[name .. "_onlynumbers"] then 
			Options.Vars[name .. "_db"][Options.Vars[name]] = edit:GetNumber()
		else
			if Options.Vars[name.."_suggestion"] and Options.Vars[name.."_suggestion"]~="" then
				if edit:GetText()==Options.Vars[name.."_suggestion"] then
					Options.Vars[name .. "_db"] [Options.Vars[name]] = ""
				else
					Options.Vars[name .. "_db"] [Options.Vars[name]] = edit:GetText()
				end
			else
				Options.Vars[name .. "_db"] [Options.Vars[name]] = edit:GetText()
			end
		end
	end
end
	
function Options.DoCancel()
	for name,cbox in pairs(Options.CheckBoxes) do
		if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
			cbox:SetChecked( Options.Vars[name .. "_db"] [Options.Vars[name]] )
		end
	end
	
	for name,color in pairs(Options.Color) do
		if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
			color:GetNormalTexture():SetVertexColor(
				Options.Vars[name .. "_db"] [Options.Vars[name]].r,
				Options.Vars[name .. "_db"] [Options.Vars[name]].g,
				Options.Vars[name .. "_db"] [Options.Vars[name]].b,
				Options.Vars[name .. "_db"] [Options.Vars[name]].a
			)
			color.ColR,color.ColG,color.ColB,color.ColA=Options.Vars[name .. "_db"] [Options.Vars[name]].r, Options.Vars[name .. "_db"] [Options.Vars[name]].g,	Options.Vars[name .. "_db"] [Options.Vars[name]].b,	Options.Vars[name .. "_db"] [Options.Vars[name]].a
		end
	end
	
	
	for name,edit in pairs(Options.EditBoxes) do
		if Options.Vars[name .. "_onlynumbers"] then 
			edit:SetNumber( Options.Vars[name .. "_db"] [Options.Vars[name]] )
		else
			edit:SetText( Options.Vars[name .. "_db"] [Options.Vars[name]] )
			EditBox_OnFocusLost(edit)
		end		
	end
end
	
function Options.DoDefault()
	for name,cbox in pairs(Options.CheckBoxes) do
		if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
			Options.Vars[name .. "_db"] [Options.Vars[name]]= Options.Vars[name .. "_init"]
		end
	end
	
	for name,color in pairs(Options.Color) do
		if Options.Vars[name .. "_db"]~=nil and Options.Vars[name]~=nil then
			Options.Vars[name .. "_db"] [Options.Vars[name]].r = Options.Vars[name .. "_init"].r
			Options.Vars[name .. "_db"] [Options.Vars[name]].g = Options.Vars[name .. "_init"].g
			Options.Vars[name .. "_db"] [Options.Vars[name]].b = Options.Vars[name .. "_init"].b
			Options.Vars[name .. "_db"] [Options.Vars[name]].a = Options.Vars[name .. "_init"].a

		end
	end
	
	
	for name,edit in pairs(Options.EditBoxes) do
		Options.Vars[name .. "_db"] [Options.Vars[name]]= Options.Vars[name .. "_init"]
	end
	Options:DoCancel()
end
	
function Options.SetScale(x)
	Options.scale=x
end

---Creates a new settings category and returns its display frame.
---@param title string
---@param noHeader boolean?
---@param scrollable boolean?
---@return Frame
function Options.AddNewCategoryPanel(title,noHeader,scrollable)
	local c=#Options.CategoryPanels +1
	local FrameName=Options.Prefix.."OptionFrame"..c
		
	Options.CategoryPanels[c] = CreateFrame( "Frame",FrameName , UIParent )
	Options.CategoryPanels[c].name = title
	if c==1 then 
		Options.CategoryPanels[c].okay = Options._DoOk
		Options.CategoryPanels[c].cancel = Options._DoCancel
		Options.CategoryPanels[c].refresh = Options._DoCancel
		Options.CategoryPanels[c].default = Options._DoDefault
	else
		Options.CategoryPanels[c].parent = Options.CategoryPanels[1].name
	end
	
	InterfaceOptions_AddCategory(Options.CategoryPanels[c])
	Options.CurrentPanel=Options.CategoryPanels[c]		
	
	if scrollable then
		
		Options.CategoryPanels["scroll"..c]=CreateFrame("ScrollFrame", FrameName.."Scroll", Options.CurrentPanel,"UIPanelScrollFrameTemplate")
		Options.CategoryPanels["scroll"..c]:SetPoint("TOPLEFT",0, -10) 
		Options.CategoryPanels["scroll"..c]:SetPoint("BOTTOMRIGHT", -30, 10) 
		Options.CategoryPanels["scrollChild"..c] = CreateFrame("Frame",FrameName.."ScrollChild") 
		Options.CategoryPanels["scroll"..c]:SetScrollChild(Options.CategoryPanels["scrollChild"..c])
		
		Options.CategoryPanels["scrollChild"..c]:SetSize(Options.CurrentPanel:GetWidth()-1,100)
		Options.CurrentPanel=Options.CategoryPanels["scrollChild"..c]
	end
	
	
	Options.Frames["title_"..c] = Options.CurrentPanel:CreateFontString(FrameName.."_Title", "OVERLAY", "GameFontNormalLarge")
	if noHeader==true then
		Options.Frames["title_"..c]:SetHeight(1)
	else
		Options.Frames["title_"..c]:SetText(title)
	end
	Options.Frames["title_"..c]:SetPoint("TOPLEFT", 10, -10)
	Options.Frames["title_"..c]:SetScale(Options.scale)
	
	Options.NextRelativ=FrameName.."_Title"
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
	Options.NextRelativ=Options.Prefix.."OptionFrame".. #Options.CategoryPanels .."_Title"
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
---@return CheckButton
function Options.AddCheckBoxToCurrentPanel(dbTable,key,default,labelText,width)
	local c=Options.Frames.count+1
	Options.Frames.count=c	
	local ButtonName=Options.Prefix .."CBOX_"..c
	if default==nil then
		default=false
	end
	Options.Index[c]=ButtonName	
	
	Options.Vars[ButtonName]=key
	Options.Vars[ButtonName.."_init"]=default
	Options.Vars[ButtonName.."_db"]=dbTable
	
	if dbTable~=nil and key~=nil then
		if dbTable[key] == nil then dbTable[key]=default end
	end
	
	Options.CheckBoxes[ButtonName] = CreateFrame("CheckButton", ButtonName, Options.CurrentPanel, "ChatConfigCheckButtonTemplate")
	_G[ButtonName .. "Text"]:SetText(labelText)
	if width then
		_G[ButtonName .. "Text"]:SetWidth(width)
		_G[ButtonName .. "Text"]:SetNonSpaceWrap(false)
		_G[ButtonName .. "Text"]:SetMaxLines(1)
		Options.CheckBoxes[ButtonName]:SetHitRectInsets(0, -width, 0,0)
	else
		Options.CheckBoxes[ButtonName]:SetHitRectInsets(0, -_G[ButtonName.."Text"]:GetStringWidth()-2, 0,0)
	end
	
	Options.CheckBoxes[ButtonName]:ClearAllPoints()
	
	if Options.inLine~=true or Options.LineRelativ ==nil then
		Options.CheckBoxes[ButtonName]:SetPoint("TOPLEFT", Options.NextRelativ,"BOTTOMLEFT", Options.NextRelativX, Options.NextRelativY)
		Options.NextRelativ=ButtonName
		Options.LineRelativ=ButtonName
		Options.NextRelativX=0
		Options.NextRelativY=0
	else
		Options.CheckBoxes[ButtonName]:SetPoint("TOP", Options.LineRelativ,"TOP", 0, 0)
		Options.CheckBoxes[ButtonName]:SetPoint("LEFT", Options.LineRelativ.."Text","RIGHT", 10, 0)			
		Options.LineRelativ=ButtonName
	end
	
	Options.CheckBoxes[ButtonName]:SetScale(Options.scale)
	if dbTable~=nil and key~=nil then 
		Options.CheckBoxes[ButtonName]:SetChecked(dbTable[key])
	else
		Options.CheckBoxes[ButtonName]:Hide()
	end
	
	Options.CheckBoxes[ButtonName].OnRightClick=CheckBox_OnRightClick
	
	return Options.CheckBoxes[ButtonName]
end

---@param dbTable table expects either character or account SavedVars table
---@param key string variables key in the SavedVars table
---@param default {r: number, g: number, b: number, a: number} default color values. falls-back to white.
---@param labelText string label text for the color button
---@param width number?
---@return Button
function Options.AddColorSwatchToCurrentPanel(dbTable,key,default,labelText,width)
	local c=Options.Frames.count+1
	
	local textFrame=Options.AddTextToCurrentPanel(labelText,width)
	textFrame:SetTextColor(1,1,1)
	local h=textFrame:GetHeight()
	
	Options.Frames.count=c	
	local ButtonName=Options.Prefix .."COLOR_"..c
	
	if default==nil then
		default={r=1,g=1,b=1,a=1}
	end
	
	Options.Index[c]=ButtonName	
	
	Options.Vars[ButtonName]=key
	Options.Vars[ButtonName.."_init"]=default
	Options.Vars[ButtonName.."_db"]=dbTable
	
	if dbTable~=nil and key~=nil then
		if dbTable[key] == nil then 
			dbTable[key]={}
			dbTable[key].r=default.r 
			dbTable[key].g=default.g 
			dbTable[key].b=default.b 
			dbTable[key].a=default.a 
		end
	end
	
	Options.Color[ButtonName] = CreateFrame("Button", ButtonName, Options.CurrentPanel)
	
	local but=Options.Color[ButtonName]
	
	but:SetWidth(h)
	but:SetHeight(h)
	but.ColTex=but:CreateTexture(ButtonName.."Background","BACKGROUND")
	but.ColTex:SetPoint("CENTER")
	but.ColTex:SetWidth(h-2)
	but.ColTex:SetHeight(h-2)
	but.ColTex:SetColorTexture(1,1,1,1)
	but:SetScript("OnEnter",
		function (self)
			_G[self:GetName() .. "Background"]:SetVertexColor(1.0, 0.82, 0.0)
		end
	)
	but:SetScript("OnLeave",
		function (self)
			_G[self:GetName() .. "Background"]:SetVertexColor(1.0, 1.0, 1.0)
		end
	)
	but:SetNormalTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
	
	
	but:ClearAllPoints()
	
	but:SetPoint("TOPLEFT", Options.NextRelativ,"TOPRIGHT", 5, 0)
	
	but:SetScale(Options.scale)
	
	but:GetNormalTexture():SetVertexColor(dbTable[key].r,dbTable[key].g,dbTable[key].b,dbTable[key].a)
	but.ColR,but.ColG,but.ColB,but.ColA=dbTable[key].r,dbTable[key].g,dbTable[key].b,dbTable[key].a
		
	local function callback(previousValues)
		local newR, newG, newB, newA

		if previousValues then
			newR, newG, newB, newA = unpack(previousValues)
		else
			newA, newR, newG, newB = 1.0 - OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB()
		end
		but:GetNormalTexture():SetVertexColor(newR, newG, newB, newA)
		but.ColR,but.ColG,but.ColB,but.ColA=newR, newG, newB, newA		
	end
	
	but:SetScript(
		"OnClick",
		function(self)
			local r, g, b, a = but.ColR,but.ColG,but.ColB,but.ColA
			ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, 1.0 - a
			ColorPickerFrame.previousValues = {r, g, b, a}
			ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = callback, callback, callback
			ColorPickerFrame:SetColorRGB(r, g, b)
			ColorPickerFrame:Hide()
			ColorPickerFrame:Show()
		end
	)
	
	return but
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

---@param checkBox CheckButton|{Text: FontString}
---@param dbTable table expects either character or account SavedVars table
---@param key string
---@param value boolean? new isChecked value
---@param labelText string new label text for the checkbox
---@param width number?
function Options.EditCheckBox(checkBox,dbTable,key,value,labelText,width)
	local ButtonName=checkBox:GetName()
	if value==nil then
		value=false
	end
	Options.Vars[ButtonName]=key
	Options.Vars[ButtonName.."_init"]=value
	Options.Vars[ButtonName.."_db"]=dbTable
	
	if dbTable~=nil and key~=nil then
		if dbTable[key] == nil then dbTable[key]=value end
	end
	
	_G[ButtonName .. "Text"]:SetText(labelText)
	if width then
		_G[ButtonName .. "Text"]:SetWidth(width)
		_G[ButtonName .. "Text"]:SetNonSpaceWrap(false)
		_G[ButtonName .. "Text"]:SetMaxLines(1)
		Options.CheckBoxes[ButtonName]:SetHitRectInsets(0, -width, 0,0)
	else
		Options.CheckBoxes[ButtonName]:SetHitRectInsets(0, -_G[ButtonName.."Text"]:GetStringWidth()-2, 0,0)
	end
	
	if dbTable~=nil and key~=nil then 
		Options.CheckBoxes[ButtonName]:SetChecked(dbTable[key])
		Options.CheckBoxes[ButtonName]:Show()
	else
		Options.CheckBoxes[ButtonName]:Hide()
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
---@param instructions string? text to display in the edit box when it is empty
---@return EditBox
function Options.AddEditBoxToCurrentPanel(dbTable,key,default,labelText,width,labelWidth,isNumeric,tooltip,instructions)
	if width==nil then width=200 end
	local c=Options.Frames.count+1
	Options.Frames.count=c	

	local ButtonName= Options.Prefix .."Edit_"..c.. key
	local CatName = ButtonName.."_Text"
			
	Options.Frames[CatName] = Options.CurrentPanel:CreateFontString(CatName, "OVERLAY", "GameFontNormal")
	Options.Frames[CatName]:SetText('|cffffffff' .. labelText .. '|r')
	Options.Frames[CatName]:SetPoint("TOPLEFT",Options.NextRelativ,"BOTTOMLEFT", Options.NextRelativX, Options.NextRelativY-2)
	Options.Frames[CatName]:SetScale(Options.scale)
	if labelWidth==nil or labelWidth==0 then 
		Options.Frames[CatName]:SetWidth(Options.Frames[CatName]:GetStringWidth())
	else
		Options.Frames[CatName]:SetWidth(labelWidth)
		Options.Frames[CatName]:SetJustifyH("LEFT")
		Options.Frames[CatName]:SetJustifyV("TOP")
	end
	
	
	
	Options.Vars[ButtonName]=key
	Options.Vars[ButtonName.."_db"]=dbTable
	Options.Vars[ButtonName.."_init"]=default
	Options.Vars[ButtonName.."_onlynumbers"]=isNumeric
	
	
	if dbTable[key] == nil then dbTable[key]=default end

	Options.EditBoxes[ButtonName] = CreateFrame("EditBox", ButtonName, Options.CurrentPanel, "InputBoxTemplate")
	Options.EditBoxes[ButtonName]:SetPoint("TOPLEFT", Options.Frames[CatName],"TOPRIGHT",5 ,5)
	Options.EditBoxes[ButtonName]:SetScale(Options.scale)
	Options.EditBoxes[ButtonName]:SetWidth(width)
	Options.EditBoxes[ButtonName]:SetHeight(20)
	
	Options.EditBoxes[ButtonName]:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
	
	Options.EditBoxes[ButtonName].GPI_Options=Options
			
	if isNumeric then
		Options.EditBoxes[ButtonName]:SetNumeric(true)
		Options.EditBoxes[ButtonName]:SetNumber(dbTable[key])
	else
		Options.EditBoxes[ButtonName]:SetText(dbTable[key])
	end
	
	Options.EditBoxes[ButtonName]:SetCursorPosition(0)
	Options.EditBoxes[ButtonName]:HighlightText(0,0) 
	Options.EditBoxes[ButtonName]:SetAutoFocus(false)
	Options.EditBoxes[ButtonName]:ClearFocus() 
	if tooltip and tooltip~="" then 
		Options.EditBoxes[ButtonName]:SetScript("OnEnter", EditBox_TooltipShow)
		Options.EditBoxes[ButtonName]:SetScript("onLeave", EditBox_TooltipHide)
		Options.Vars[ButtonName.."_tooltip"] = tooltip
	end
	if instructions and instructions~="" then 
		Options.EditBoxes[ButtonName]:SetScript("OnEditFocusGained", EditBox_OnFocusGained)
		Options.EditBoxes[ButtonName]:SetScript("OnEditFocusLost", EditBox_OnFocusLost)
		Options.Vars[ButtonName.."_suggestion"]=instructions			
	end
	
	Options.Frames[CatName]:SetHeight(Options.EditBoxes[ButtonName]:GetHeight()-10)
	
	Options.NextRelativ=CatName
	Options.NextRelativX=0
	Options.NextRelativY=-10
	
	return Options.EditBoxes[ButtonName]
end

---@parm factor number? Defaults to 1. Negative values move the spacer up.
function Options.AddSpacerToPanel(factor)
	Options.NextRelativY=Options.NextRelativY-20*(factor or 1)
end

---@param panel number? defaults to panel 1 (main panel)
function Options.OpenCategoryPanel(panel)
	if panel==nil or panel > #Options.CategoryPanels then panel = 1 end
	InterfaceOptionsFrame_OpenToCategory(Options.CategoryPanels[#Options.CategoryPanels])
	InterfaceOptionsFrame_OpenToCategory(Options.CategoryPanels[#Options.CategoryPanels])
	InterfaceOptionsFrame_OpenToCategory(Options.CategoryPanels[panel])
end

