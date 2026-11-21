-- Pet: a hunter's pet, one slim line of the dock under Level (Josh 2026-11-21).
--
-- "On the dock, is it possible to add a new row under the player level for
-- hunter pets? I'd like to show happiness, level, and an experience bar
-- similar to the players." The line has the pet's mood as the game's own
-- face at the left, its name and level, how far through the level it is and
-- its mood in a word at the right, and its experience as the bar.
--
-- ONLY WHILE A HUNTER'S PET IS OUT. HasPetUI says whether the pet is a
-- hunter's; a warlock's minion, a mount you steer and a mind-controlled
-- enemy have a pet bar too, and none of them has a mood or a level to gain.
-- With no such pet the line is not there, and the dock closes up.
--
-- WHAT THE GAME SAYS. Its own pet frame and character window read these:
--   GetPetExperience()            experience into the level, and what it needs
--   C_PetInfo.GetPetHappiness()   1 unhappy, 2 content, 3 happy; the share of
--                                 its damage it deals; whether it gains or
--                                 loses loyalty
--   C_PetInfo.GetPetLoyalty()     its loyalty, in the game's words
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Modules/Pet/Pet.lua")

local U = BT.Util

local M = BT.Module({
	key = "pet",
	feature = "dock",
	title = "Pet",
	-- straight under Level (37), over PvP (37.2)
	order = 37.1,
	-- on the right panel, so it has a tab on the rail
	dock = true,
})

local WORDS = "|cff8a9894%s|r"

-- a mood: its word, the game's face for it, and its colour
M.MOODS = {
	{ word = "Unhappy", atlas = "UI-PetMad", color = { 0.89, 0.38, 0.35 } },
	{ word = "Content", atlas = "UI-PetNeutral", color = { 0.89, 0.66, 0.29 } },
	{ word = "Happy", atlas = "UI-PetHappiness", color = { 0.37, 0.76, 0.55 } },
}

local function plain(v)
	if issecretvalue and issecretvalue(v) then
		return nil
	end
	return v
end

local function ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local got = { pcall(fn, ...) }
	if not got[1] then
		return nil
	end
	return plain(got[2]), plain(got[3]), plain(got[4])
end

-- The hunter's pet that is out: { name, level, cur, max, progress, mood,
-- damage, loyalty, rate, family }, or nil with none.
function M.Read()
	-- A MADE-UP PET, FROM THE TESTING PAGE (Josh 2026-11-21: "I dont have a
	-- hunter"): 1 to 3 its mood, 4 a happy pet at your own level, which gains
	-- no experience. Nothing is saved, and a reload puts it away.
	local made = BT.Dock and BT.Dock.preview and BT.Dock.preview.pet
	if made then
		return M.MadeUp(made)
	end
	local hasUI, hunters = ask(rawget(_G, "HasPetUI"))
	if not (hasUI and hunters) then
		return nil
	end
	if not ask(rawget(_G, "UnitExists"), "pet") then
		return nil
	end
	local info = rawget(_G, "C_PetInfo")
	local p = {}
	p.name = ask(rawget(_G, "UnitName"), "pet")
	p.level = tonumber(ask(rawget(_G, "UnitLevel"), "pet")) or 0
	p.family = ask(rawget(_G, "UnitCreatureFamily"), "pet")
	local cur, max = ask(rawget(_G, "GetPetExperience"))
	p.cur, p.max = tonumber(cur) or 0, tonumber(max) or 0
	p.progress = p.max > 0 and math.max(0, math.min(1, p.cur / p.max)) or 0
	local mood, damage, rate = ask((info and info.GetPetHappiness) or rawget(_G, "GetPetHappiness"))
	p.mood = M.MOODS[tonumber(mood) or 0] and tonumber(mood) or nil
	p.damage, p.rate = tonumber(damage), tonumber(rate)
	p.loyalty = ask((info and info.GetPetLoyalty) or rawget(_G, "GetPetLoyalty"))
	if type(p.loyalty) ~= "string" or p.loyalty == "" then
		p.loyalty = nil
	end
	return p
end

-- what each made-up mood does, as the game has it: the share of its damage
-- a pet deals, and whether it gains loyalty or loses it
M.MADE = {
	{ damage = 75, rate = -1, loyalty = "(Loyalty Level 2) Unruly" },
	{ damage = 100, rate = 0, loyalty = "(Loyalty Level 3) Submissive" },
	{ damage = 125, rate = 1, loyalty = "(Loyalty Level 4) Dependable" },
}
function M.MadeUp(which)
	local capped = which == 4
	local mood = capped and 3 or math.max(1, math.min(3, tonumber(which) or 3))
	local made = M.MADE[mood]
	local level = capped and (tonumber(ask(rawget(_G, "UnitLevel"), "player")) or 60) or 23
	local p = { name = "Humar", family = "Cat", level = level, mood = mood, damage = made.damage, rate = made.rate,
		loyalty = made.loyalty, cur = capped and 0 or 6200, max = capped and 0 or 10000 }
	p.progress = p.max > 0 and p.cur / p.max or 0
	return p
end

-- the line's two ends: "Humar · Level 23" and "62% · Happy"
function M.Lines(p)
	local name = (type(p.name) == "string" and p.name ~= "") and p.name or "Pet"
	local left = ("%s %s Level %d"):format(name, WORDS:format("·"), p.level)
	local parts = {}
	-- a pet at your own level gains nothing, and the game says it needs none
	if p.max > 0 then
		parts[#parts + 1] = ("%d%%"):format(math.floor(p.progress * 100))
	end
	local mood = p.mood and M.MOODS[p.mood]
	if mood then
		local c = mood.color
		parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, mood.word)
	end
	return left, table.concat(parts, " " .. WORDS:format("·") .. " ")
end

function M.Update()
	if not M.frame then
		return
	end
	local p = M.Read()
	local want = p ~= nil and BT.Enabled("pet")
	if want ~= M.shownFor then
		M.shownFor = want
		M.frame:SetShown(want)
		BT.Dock.Relayout()
	end
	if not p then
		return
	end
	local left, right = M.Lines(p)
	M.text:SetText(left)
	M.eta:SetText(right)
	-- the game's own face for the mood; the dock's shield in the mood's
	-- colour where the game has no such picture
	local mood = p.mood and M.MOODS[p.mood] or nil
	local faced = false
	if mood and M.face.SetAtlas then
		faced = pcall(M.face.SetAtlas, M.face, mood.atlas) and true or false
	end
	M.face:SetShown(faced)
	for _, layer in ipairs({ M.shield.field, M.shield.rim }) do
		layer:SetShown(not faced)
	end
	local c = (mood and mood.color) or BT.TEXT.quiet
	M.shield.field:SetVertexColor(c[1], c[2], c[3])

	local w = BT.Dock.LineBarWidth(M.frame)
	if w <= 0 then
		return
	end
	local a = BT.Widgets.ACCENT
	M.track:SetColorTexture(1, 1, 1, 0.07)
	M.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
	-- a texture of no width is drawn as a whole one, so an empty bar is hidden
	M.fill:SetShown(p.progress > 0)
	M.fill:SetWidth(math.max(1, w * p.progress))
end

-- its level and experience, then what its mood does
function M.Tip()
	local p = M.Read()
	if not (p and BT.Tip) then
		return
	end
	BT.Tip.Show(M.frame, { build = function(t)
		local mood = p.mood and M.MOODS[p.mood] or nil
		local sub = ("Level %d%s"):format(p.level, type(p.family) == "string" and (" " .. p.family) or "")
		t:Header({ name = p.name or "Pet", sub = sub, pill = mood and mood.word or nil,
			pillState = p.mood == 3 and "good" or (p.mood == 1 and "bad" or "warn") })
		t:Section("Experience")
		if p.max > 0 then
			t:Row("This level", ("%s / %s"):format(U.Commas(p.cur), U.Commas(p.max)))
			t:Row("To go", U.Commas(math.max(0, p.max - p.cur)))
		else
			t:Note("Your pet gains no experience at your level.")
		end
		if mood then
			t:Section("Mood")
			if p.damage then
				t:Row("Damage dealt", ("%d%%"):format(p.damage), p.damage >= 100 and (p.damage > 100 and "good" or nil) or "bad")
			end
			if p.rate and p.rate ~= 0 then
				t:Row("Loyalty", p.rate > 0 and "Gaining" or "Losing", p.rate > 0 and "good" or "bad")
			end
			if p.loyalty then
				t:Row("Loyalty level", p.loyalty)
			end
			if p.mood < 3 then
				t:Note("Feed your pet to make it happy.", "warn")
			end
		end
	end })
end

function M.Build()
	if M.frame then
		return M.frame
	end
	M.frame = BT.Dock.Section("pet", 7)
	-- a slim line under Level (BT.Dock.SlimLine), as PvP's is
	M.shield = BT.Dock.LineShield(M.frame)
	M.face = M.frame:CreateTexture(nil, "ARTWORK", nil, 4)
	M.face:SetSize(BT.Dock.LINE_ICON_W, BT.Dock.LINE_ICON_W)
	M.face:SetPoint("CENTER", M.shield.icon, "CENTER", 0, 0)
	M.face:Hide()
	M.text, M.eta, M.track, M.fill = BT.Dock.SlimLine(M.frame, M.shield.icon)
	M.frame:SetScript("OnSizeChanged", function()
		M.Update()
	end)
	M.frame:EnableMouse(true)
	M.frame:SetScript("OnEnter", M.Tip)
	M.frame:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	return M.frame
end

M.events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_PET", "UNIT_PET_EXPERIENCE", "UNIT_HAPPINESS", "PET_UI_UPDATE",
	"PET_BAR_UPDATE", "UNIT_LEVEL", "UNIT_NAME_UPDATE" }) do
	pcall(M.events.RegisterEvent, M.events, event)
end
M.events:SetScript("OnEvent", function(_, event, unit)
	if not BT.Enabled("pet") then
		return
	end
	if (event == "UNIT_LEVEL" or event == "UNIT_NAME_UPDATE") and unit ~= "pet" then
		return
	end
	if event == "UNIT_PET" and unit ~= "player" then
		return
	end
	M.Update()
	-- a pet just called is not all there yet: its name and mood a moment later
	if (event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD") and C_Timer and C_Timer.After then
		C_Timer.After(1, function()
			if BT.Enabled("pet") then
				M.Update()
			end
		end)
	end
end)

function M.Show(on)
	local frame = M.Build()
	if on then
		M.shownFor = nil
		M.Update()
	else
		M.shownFor = false
		frame:Hide()
	end
	BT.Dock.Relayout()
end

function M:OnEnable()
	M.Show(true)
end

function M:OnBind()
	M.Show(true)
end

function M:OnDisable()
	M.Show(false)
end
