-- General: what belongs to the whole toolkit (Josh 2026-09-19).
--
-- GENERAL, NOT SETTINGS (Josh 2026-09-23). Every tab on the rail is settings
-- now, so this one is named for what is on it: the look of every panel.
-- Nothing that belongs to one utility is here (Josh 2026-09-24): the clock
-- and the census button went to the Dock's page, the target row to the
-- Ledger's, and the typeface is Google Sans, not a choice.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Settings.lua")

local S = {}
BT.Settings = S

local W = BT.Widgets
local rows, extras, panel, stack

function S.Build(parent)
	panel = parent
	rows, extras = {}, {}
	stack = W.Stack(parent)
	S.appearance = {}

	-- HOW MUCH IT CHANGES (Josh 2026-09-25): the question the first login
	-- asks - full, just the dock, or the census and notes - asked again
	local layout = stack:Section("How much it changes")
	local again = W.Row(layout, "Choose again", "everything, just the dock, or the census and your notes · /bt setup")
	local ask = again:SetControl(W.Button(again, "Choose", 70, 20))
	ask:SetScript("OnClick", function()
		if BT.Welcome then
			BT.Welcome.Show()
		end
	end)
	S.chooseButton = ask

	-- WHAT THE TOOLKIT LOOKS LIKE, IN ONE PLACE (Josh 2026-09-21). Every
	-- module reads these; there is nothing to set twice.
	local look = stack:Section("Look")

	-- THE PRESET IS THE DEFAULT, NOT A LOCK (Josh 2026-09-21). "Class" follows
	-- whoever you are logged in as, so a warlock's panels come up violet
	-- without anyone setting anything; picking a colour of your own moves it
	-- to Custom, because otherwise the next login would read the class again
	-- and quietly throw your colour away.
	local presets = W.Row(look, "Colours", "follow your class, the toolkit's green, or pick your own")
	-- one control, three answers: three loose buttons read as three actions
	local seg = presets:SetControl(W.Segmented(presets, {
		{ "class", "Class" }, { "house", "Toolkit" }, { "custom", "Custom" },
	}, function(key)
		BT.Theme.Set("preset", key)
		S.Refresh()
	end))
	for _, b in ipairs(seg.buttons) do
		b.preset = b.key
	end
	presets.seg, presets.buttons = seg, seg.buttons
	S.appearance.presets = presets

	local function swatchRow(which, text, blurb)
		local r = W.Row(look, text, blurb)
		local box = CreateFrame("Button", nil, r)
		box:SetSize(36, 18)
		r:SetControl(box)
		-- NOT A PANEL (Josh 2026-09-21). A swatch drawn with Pill.Panel went
		-- black the moment corner radius went above zero: Panel hides its two
		-- square textures and draws seven rounded ones, and the refresh went
		-- on colouring the two that were now hidden. A swatch is a flat
		-- rectangle of one colour - it has no business being a panel.
		box.rim = box:CreateTexture(nil, "BACKGROUND")
		box.rim:SetAllPoints()
		box.bg = box:CreateTexture(nil, "BORDER")
		box.bg:SetPoint("TOPLEFT", 1, -1)
		box.bg:SetPoint("BOTTOMRIGHT", -1, 1)
		box:SetScript("OnClick", function()
			S.PickColour(which)
		end)
		-- what it holds, in numbers: a near-black swatch on a near-black
		-- panel says little on its own
		r.value = r:CreateFontString(nil, "OVERLAY", "BeebModFontDisableSmall")
		r.value:SetPoint("RIGHT", box, "LEFT", -8, 0)
		r.box, r.which = box, which
		S.appearance[which] = r
		return r
	end
	swatchRow("fill", "Background", "the dark under every panel")
	swatchRow("rim", "Border", "the line around every panel")

	-- no border width or corner radius here any more: the toolkit has one
	-- shape (see Core/Theme.lua)

	stack:Layout()
end

-- THE CLIENT OWNS THE COLOUR PICKER (Josh 2026-09-21). Its API was rewritten
-- between builds - a table of callbacks on one, loose fields on another - so
-- both shapes are tried and neither is allowed to throw.
function S.PickColour(which)
	if not ColorPickerFrame then
		return false
	end
	local was = which == "fill" and BT.Theme.Fill() or BT.Theme.Rim()
	-- CANCEL PUTS THE PRESET BACK, NOT THE COLOUR (Josh 2026-09-22). Handing
	-- the old numbers back through Set(which) marks the theme "custom", so
	-- opening the picker on a class preset and pressing Cancel froze that
	-- class's colours onto every character. The preset is remembered instead.
	local preset = BT.Theme.Preset_Name()
	local function keep(r, g, b, a)
		BT.Theme.Set(which, { r, g, b, a or was[4] })
		S.Refresh()
	end
	-- ONCE, WHEN THE MOUSE IS LET GO (Josh 2026-09-23: "Color picker severely
	-- lags the game. Maybe we shouldnt apply a color until the user release
	-- the mouse button?"). The picker says every step of a drag across its
	-- wheel, and each colour repainted every surface in the addon - dozens of
	-- times a second. While the button is held the colour is only noted; it
	-- is applied the frame it is let go. A click, a typed code and Okay all
	-- end with the button up, so they apply at once. The picker's own swatch
	-- shows the colour meanwhile.
	local watch = S.colourWatch or CreateFrame("Frame")
	S.colourWatch = watch
	local function held()
		return type(IsMouseButtonDown) == "function" and IsMouseButtonDown("LeftButton") and true or false
	end
	local function queue(r, g, b, a)
		watch.pending = { r, g, b, a }
		watch:SetScript("OnUpdate", function(self)
			if held() then
				return
			end
			self:SetScript("OnUpdate", nil)
			local p = self.pending
			self.pending = nil
			if p then
				keep(p[1], p[2], p[3], p[4])
			end
		end)
	end
	local function cancel()
		watch.pending = nil
		watch:SetScript("OnUpdate", nil)
		if preset ~= "custom" then
			BT.Theme.Set("preset", preset)
		else
			BT.Theme.Set(which, { was[1], was[2], was[3], was[4] })
		end
		S.Refresh()
	end
	-- the old picker has no GetColorAlpha: its slider reads the other way up
	local function alpha()
		if ColorPickerFrame.GetColorAlpha then
			return ColorPickerFrame:GetColorAlpha()
		end
		local slider = _G.OpacitySliderFrame
		if slider and slider.GetValue then
			return 1 - slider:GetValue()
		end
		return nil
	end
	local info = {
		r = was[1], g = was[2], b = was[3],
		hasOpacity = true, opacity = was[4] or 1,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			queue(r, g, b, alpha())
		end,
		opacityFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			queue(r, g, b, alpha())
		end,
		cancelFunc = cancel,
	}
	if ColorPickerFrame.SetupColorPickerAndShow then
		return pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
	end
	for k, v in pairs(info) do
		ColorPickerFrame[k] = v
	end
	-- the old picker's opacity is a transparency: 88% opaque opens at 12%
	ColorPickerFrame.opacity = 1 - (was[4] or 1)
	ColorPickerFrame.func = info.swatchFunc
	if ColorPickerFrame.SetColorRGB then
		pcall(ColorPickerFrame.SetColorRGB, ColorPickerFrame, was[1], was[2], was[3])
	end
	return pcall(ColorPickerFrame.Show, ColorPickerFrame)
end

local function refreshAppearance()
	local a = S.appearance
	if not a then
		return
	end
	-- A BUTTON IS NOT A PILL (Josh 2026-09-21). Pressed is the state a button
	-- already has for "this is the one you are on".
	a.presets.seg:Select(BT.Theme.Preset_Name())
	for _, which in ipairs({ "fill", "rim" }) do
		local c = which == "fill" and BT.Theme.Fill() or BT.Theme.Rim()
		local box = a[which].box
		-- A FIXED OUTLINE, NOT A DARKER COPY (Josh 2026-09-21). Drawing the
		-- swatch's own colour at half strength gives a near-black background
		-- a near-black outline, so the swatch and the panel behind it are the
		-- same thing and there is nothing to click. The outline has to
		-- contrast with the PANEL, not with the colour it is holding.
		box.bg:SetColorTexture(c[1], c[2], c[3], 1)
		box.rim:SetColorTexture(0.45, 0.50, 0.48, 1)
		a[which].value:SetText(("#%02X%02X%02X · %d%%"):format(
			math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5),
			math.floor((c[4] or 1) * 100 + 0.5)))
	end
end

function S.Refresh()
	refreshAppearance()
	for _, r in ipairs(extras or {}) do
		r.switch:SetOn(r.get())
	end
end

-- the tests want the rows without going through frames
function S.Appearance() return S.appearance end
function S.Rows() return rows end
function S.Extras() return extras end
