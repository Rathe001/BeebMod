-- The ornate border an elite or a rare wears (Josh 2026-09-23).
--
-- The client has always said what a mob is with a dragon round its portrait -
-- gold for an elite, silver for a rare - and players read it before the name.
-- The toolkit says it with an Art Deco border, because it stays crisp at the
-- sizes these frames are drawn at where a filigree would smudge: a corner
-- piece (a stepped notch, a double line, a diamond at the point) mirrored at
-- each corner, the double line run between them, and a crest on the top edge
-- for the elites. White art (Art/Rank, drawn by scripts/make-rank.py), tinted
-- gold or silver. Wholly outside what it borders.
--
-- One border for everything that shows what a mob is: the unit frames (the
-- target, its target, the focus, the bosses) and the unit tooltip.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("UI/Ornament.lua")

local O = {}
BT.Ornament = O

local GOLD, SILVER = { 1.00, 0.82, 0.40 }, { 0.84, 0.88, 0.95 }

-- the client's classifications: the border's colour, and whether it wears
-- the crest
O.RANK = {
	worldboss = { colour = GOLD, crest = true },
	elite = { colour = GOLD, crest = true },
	rareelite = { colour = SILVER, crest = true },
	rare = { colour = SILVER, crest = false },
}

-- The art, and where it sits: the corner piece's own pixel (0, 0) is EDGE
-- units out from the frame's corner, and its lines run OUTER and INNER out
-- from the frame's edge (scripts/make-rank.py draws them there).
O.CORNER = "Interface\\AddOns\\BeebMod\\Art\\Rank\\corner"
O.CREST = "Interface\\AddOns\\BeebMod\\Art\\Rank\\crest"
O.EDGE, O.OUTER, O.INNER = 8, 5, 2
-- THE BORDER'S ROOM (Josh 2026-09-23: "will it interfere with auras at all?"
-- - it did). What hangs under or beside something that may wear a border
-- starts this far out, always: past the border and two units clear of it.
O.ROOM = O.EDGE + 2

-- The border round `frame`, made once, hidden until painted. `level` is how
-- far above the frame it draws.
function O.Build(frame, level)
	local r = CreateFrame("Frame", nil, frame)
	r:SetAllPoints(frame)
	r:SetFrameLevel((frame:GetFrameLevel() or 1) + (level or 6))
	r.art = {}
	local E = O.EDGE
	-- the corners: one piece, mirrored
	for _, c in ipairs({
		{ "TOPLEFT", -E, E, 0, 1, 0, 1 }, { "TOPRIGHT", E, E, 1, 0, 0, 1 },
		{ "BOTTOMLEFT", -E, -E, 0, 1, 1, 0 }, { "BOTTOMRIGHT", E, -E, 1, 0, 1, 0 },
	}) do
		local t = r:CreateTexture(nil, "OVERLAY")
		t:SetTexture(O.CORNER)
		t:SetSize(32, 32)
		t:SetPoint(c[1], frame, c[1], c[2], c[3])
		t:SetTexCoord(c[4], c[5], c[6], c[7])
		r.art[#r.art + 1] = t
	end
	-- the double line between them, meeting the lines in the corner piece
	r.lines = {}
	local span = 32 - E
	for _, off in ipairs({ O.OUTER, O.INNER }) do
		for _, side in ipairs({
			{ "TOPLEFT", span, off, "TOPRIGHT", -span, off, "h" },
			{ "BOTTOMLEFT", span, -off, "BOTTOMRIGHT", -span, -off, "h" },
			{ "TOPLEFT", -off, -span, "BOTTOMLEFT", -off, span, "v" },
			{ "TOPRIGHT", off, -span, "BOTTOMRIGHT", off, span, "v" },
		}) do
			local t = r:CreateTexture(nil, "OVERLAY")
			t:SetPoint(side[1], frame, side[1], side[2], side[3])
			t:SetPoint(side[4], frame, side[4], side[5], side[6])
			if side[7] == "h" then t:SetHeight(1) else t:SetWidth(1) end
			r.lines[#r.lines + 1] = t
		end
	end
	-- the crest, centred on the outer line along the top
	r.crest = r:CreateTexture(nil, "OVERLAY", nil, 1)
	r.crest:SetTexture(O.CREST)
	r.crest:SetSize(32, 16)
	r.crest:SetPoint("TOP", frame, "TOP", 0, O.OUTER + 7)
	r.crest:Hide()
	r:Hide()
	return r
end

-- Put on the border for a classification ("elite", "rare", ...), or take it
-- off for anything else. Returns the classification it is wearing, or nil.
-- `colour` paints it in something other than the rank's gold or silver (the
-- game menu wears it in the theme's border colour).
function O.Paint(r, classification, colour)
	if not r then
		return nil
	end
	local style = O.RANK[classification or ""]
	if not style then
		r.style = nil
		r:Hide()
		return nil
	end
	local c = colour or style.colour
	for _, t in ipairs(r.art) do
		t:SetVertexColor(c[1], c[2], c[3], 1)
	end
	for _, t in ipairs(r.lines) do
		t:SetColorTexture(c[1], c[2], c[3], 1)
	end
	r.crest:SetVertexColor(c[1], c[2], c[3], 1)
	r.crest:SetShown(style.crest and true or false)
	r.style = classification
	r:Show()
	return classification
end
