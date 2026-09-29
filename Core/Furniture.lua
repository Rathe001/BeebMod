-- Dressing the client's own furniture, generically (Josh 2026-09-22).
--
-- The damage meter and the personal resource display are windows of the
-- client's whose frames are not named in any file we have: what is known is
-- what a frame dump shows, and what a dump shows is a tree of textures, font
-- strings and status bars. So this dresses a tree by what each piece IS:
--
--   a big piece of atlas art       a border, a background, a banner: off
--   a small piece of atlas art     a button's glyph: the panel's quiet grey
--   a small file texture           a spec icon, a spell: left exactly as it is
--   a status bar                   its own texture goes flat; its colour stays
--   gold text                      the panel's text colour; any other, left
--   a child called NineSlice etc.  the client's frame: off, whole
--
-- and remembers every change so the whole tree goes back on request. A module
-- makes a dresser, points it at a root, and later calls Undress: a frame it
-- has never touched costs it nothing.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Furniture.lua")

local F = {}
BT.Furniture = F

-- one method of the client's, asked carefully: a frame that has not got it,
-- or refuses it, answers nil rather than taking the pass down. (No closure a
-- call: a tree walk makes thousands of these.)
local function index(o, k)
	return o[k]
end

function F.Call(obj, method, ...)
	if type(obj) ~= "table" then
		return nil
	end
	local okF, fn = pcall(index, obj, method)
	if not (okF and type(fn) == "function") then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, obj, ...)
	if not ok then
		return nil
	end
	return a, b, c, d, e, f, g, h
end
local call = F.Call

function F.KeyOf(parent, child)
	if type(parent) ~= "table" then
		return nil
	end
	for k, v in pairs(parent) do
		if v == child and type(k) == "string" then
			return k
		end
	end
	return nil
end
local keyOf = F.KeyOf

local function N(v, fallback)
	return BT.Pill.Number(v, fallback)
end

local FLAT = "Interface\\Buttons\\WHITE8X8"
F.INK = { 0.62, 0.68, 0.66 }
F.TEXT = { 0.86, 0.88, 0.92 }
F.CHROME = { NineSlice = true, Border = true, Bg = true, Background = true, BackgroundOverlay = true }

local Dresser = {}
Dresser.__index = Dresser

-- opts: glyph (largest atlas piece kept as a glyph), icon (largest file
-- texture kept as an icon), ink, text, chrome, flatBars, ringBars (a rim of
-- ours round every status bar), panelAlpha (the root's fill), skip (a
-- function: true for a frame the module dresses its own way, left out of the
-- walk with everything under it), keep (a function: true for a texture that
-- is the client's to show - a hover light, a tick - left exactly as it is)
function F.New(opts)
	local d = {
		opts = opts or {},
		was = setmetatable({}, { __mode = "k" }),
		roots = setmetatable({}, { __mode = "k" }),
		rings = setmetatable({}, { __mode = "k" }),
	}
	return setmetatable(d, Dresser)
end

function Dresser:Hide(r)
	if not self.was[r] then
		self.was[r] = { alpha = N(call(r, "GetAlpha"), 1) }
	end
	call(r, "SetAlpha", 0)
end

function Dresser:Ink(r)
	if not self.was[r] then
		local vr, vg, vb, va = call(r, "GetVertexColor")
		self.was[r] = {
			vertex = { N(vr, 1), N(vg, 1), N(vb, 1), N(va, 1) },
			desat = call(r, "IsDesaturated") and true or false,
		}
	end
	local ink = self.opts.ink or F.INK
	call(r, "SetDesaturated", true)
	call(r, "SetVertexColor", ink[1], ink[2], ink[3], 1)
end

function Dresser:Retext(fs)
	local r, g, b = call(fs, "GetTextColor")
	-- through N: a nameplate's colours can come back secret, and a secret
	-- number passes type() and then refuses to be compared
	r, g, b = N(r, nil), N(g, nil), N(b, nil)
	if not (r and g and b) then
		return
	end
	-- the client's gold, and nothing else: a class-coloured name is data
	if not (r > 0.85 and g > 0.6 and b < 0.35) then
		return
	end
	if not self.was[fs] then
		self.was[fs] = { text = { r, g, b } }
	end
	local text = self.opts.text or F.TEXT
	call(fs, "SetTextColor", text[1], text[2], text[3])
end

-- what a texture is: a glyph to tint, an icon to keep, or art to take off
function Dresser:Classify(r)
	local glyph, icon = self.opts.glyph or 28, self.opts.icon or 40
	local atlas = call(r, "GetAtlas")
	local w, h = N(call(r, "GetWidth"), 0), N(call(r, "GetHeight"), 0)
	if type(atlas) == "string" and atlas ~= "" then
		if w > 0 and h > 0 and w <= glyph and h <= glyph then
			return "glyph"
		end
		return "art"
	end
	local file = call(r, "GetTexture")
	if (type(file) == "number" or (type(file) == "string" and file ~= ""))
		and w > 0 and h > 0 and w <= icon and h <= icon then
		return "icon"
	end
	return "art"
end

function Dresser:DressRegion(r)
	if r.beebs or r.beebsKeep then
		return
	end
	-- A CONTROL'S OWN MARK, WHATEVER SIZE IT IS DRAWN AT (Josh 2026-09-24).
	-- The meter's type arrow is 27x26, a pixel inside the glyph size, and
	-- drawn bigger for a moment (a hover state) a pass took it for art and
	-- put it away for good. A module pins the marks its controls are; one
	-- already taken off is given back first.
	if self.opts.keep and self.opts.keep(r) then
		return
	end
	if r.beebsGlyph then
		local w = self.was[r]
		if w and w.alpha then
			call(r, "SetAlpha", w.alpha)
			self.was[r] = nil
		end
		self:Ink(r)
		return
	end
	local kind = call(r, "GetObjectType")
	if kind == "Texture" then
		local what = self:Classify(r)
		if what == "glyph" then
			self:Ink(r)
		elseif what == "art" then
			self:Hide(r)
		end
	elseif kind == "FontString" then
		self:Retext(r)
	end
end

-- a bar goes flat and keeps its colour. Its own texture is one of its regions
-- - a file texture the art pass would take for a background - so it is marked
-- as kept before the regions are walked (learnt on the damage meter's rows)
function Dresser:DressBar(bar)
	local t = call(bar, "GetStatusBarTexture")
	if t then
		t.beebsKeep = true
		if self.opts.flatBars ~= false then
			if not self.was[bar] then
				local atlas = call(t, "GetAtlas")
				local file = call(t, "GetTexture")
				self.was[bar] = { bar = {
					atlas = (type(atlas) == "string" and atlas ~= "") and atlas or nil,
					file = (type(file) == "number" or type(file) == "string") and file or nil,
				} }
			end
			call(bar, "SetStatusBarTexture", FLAT)
		end
	end
	if self.opts.ringBars and bar.CreateTexture then
		local ring = self.rings[bar]
		if not ring then
			ring = BT.Pill.Ring(bar, "OVERLAY", 7)
			self.rings[bar] = ring
		end
		BT.Pill.PlaceRing(ring, bar, -1, 1, 0)
		BT.Pill.PaintRing(ring, BT.Widgets.RIM)
	end
end

function Dresser:DressTree(f, depth, parent)
	if type(f) ~= "table" or f.beebs or (depth or 0) > 10 then
		return 0
	end
	if self.opts.skip and (depth or 0) > 0 and self.opts.skip(f, parent) then
		return 0
	end
	local n = 0
	local key = keyOf(parent, f)
	if key and (self.opts.chrome or F.CHROME)[key] then
		self:Hide(f)
		return 1
	end
	if call(f, "GetObjectType") == "StatusBar" then
		self:DressBar(f)
		n = n + 1
	end
	local okR, regions = pcall(function() return { f:GetRegions() } end)
	for _, r in ipairs(okR and regions or {}) do
		self:DressRegion(r)
		n = n + 1
	end
	local okC, kids = pcall(function() return { f:GetChildren() } end)
	for _, kid in ipairs(okC and kids or {}) do
		n = n + self:DressTree(kid, (depth or 0) + 1, f)
	end
	return n
end

-- a window: our surface and shadow on the root, then the tree. `surface`,
-- when given, is a frame of ours the surface is drawn on instead - for a root
-- nothing may be made on (a menu the client is composing: Modules/Dropdowns)
function Dresser:DressRoot(root, surface)
	local host = surface or root
	self.roots[host] = true
	local fill = BT.Widgets.FILL
	BT.Widgets.Panel(host, { fill[1], fill[2], fill[3], self.opts.panelAlpha or 0.96 }, BT.Widgets.RIM)
	BT.Pill.ShowSurface(BT.Pill.Panels()[host], true)
	BT.Widgets.Shadow(host)
	BT.Widgets.ShowShadow(host, true)
	return self:DressTree(root, 0, nil)
end

function Dresser:Undress()
	local n = 0
	for r, w in pairs(self.was) do
		if w.alpha then
			call(r, "SetAlpha", w.alpha)
		elseif w.vertex then
			call(r, "SetVertexColor", w.vertex[1], w.vertex[2], w.vertex[3], w.vertex[4])
			call(r, "SetDesaturated", w.desat)
		elseif w.text then
			call(r, "SetTextColor", w.text[1], w.text[2], w.text[3])
		elseif w.bar then
			if w.bar.atlas then
				call(call(r, "GetStatusBarTexture"), "SetAtlas", w.bar.atlas)
			elseif w.bar.file then
				call(r, "SetStatusBarTexture", w.bar.file)
			end
		end
		self.was[r] = nil
		n = n + 1
	end
	for _, ring in pairs(self.rings) do
		BT.Pill.HideRing(ring)
	end
	for root in pairs(self.roots) do
		local h = BT.Pill.Panels()[root]
		if h then
			BT.Pill.ShowSurface(h, false)
		end
		BT.Widgets.ShowShadow(root, false)
	end
	return n
end

-- what a frame or region is, in one line, for a dump
-- SECRET NUMBERS (Josh 2026-09-22). A nameplate's measurements come back as
-- secret values on this client: type() says number, arithmetic throws. Every
-- number here goes through N, which answers the fallback for a secret one.
function F.Describe(f)
	local bits = { tostring(call(f, "GetObjectType") or type(f)) }
	local w, h = N(call(f, "GetWidth"), nil), N(call(f, "GetHeight"), nil)
	if w and h then
		bits[#bits + 1] = ("%dx%d"):format(math.floor(w), math.floor(h))
	elseif type(call(f, "GetWidth")) == "number" then
		bits[#bits + 1] = "size=secret"
	end
	local atlas = call(f, "GetAtlas")
	if type(atlas) == "string" and atlas ~= "" then
		bits[#bits + 1] = "atlas=" .. atlas
	end
	local file = call(f, "GetTexture")
	if type(file) == "string" or type(file) == "number" then
		bits[#bits + 1] = "tex=" .. tostring(file)
	end
	local text = call(f, "GetText")
	if issecretvalue and issecretvalue(text) then
		bits[#bits + 1] = "text=secret"
	elseif type(text) == "string" then
		local ok, short = pcall(string.sub, text, 1, 40)
		if ok and type(short) == "string" and short ~= "" then
			bits[#bits + 1] = ("text=%q"):format(short)
		elseif not ok then
			bits[#bits + 1] = "text=secret"
		end
	end
	if call(f, "IsShown") == false then
		bits[#bits + 1] = "hidden"
	end
	local a = N(call(f, "GetAlpha"), nil)
	if a and a < 1 then
		bits[#bits + 1] = ("alpha=%.2f"):format(a)
	end
	return table.concat(bits, " ")
end

-- the whole tree under each root, one line a piece, for the saved file
function F.Dump(rootsList, limit)
	local lines, seen = {}, {}
	local LIMIT = limit or 4000
	local function add(line)
		if #lines < LIMIT then
			lines[#lines + 1] = line
		end
	end
	local function walk(f, path, depth)
		if seen[f] or depth > 10 or #lines >= LIMIT then
			return
		end
		seen[f] = true
		add(path .. " | " .. F.Describe(f))
		local okR, regions = pcall(function() return { f:GetRegions() } end)
		for i, r in ipairs(okR and regions or {}) do
			local label = call(r, "GetName") or keyOf(f, r) or ("#r" .. i)
			add(path .. "." .. tostring(label) .. " | " .. F.Describe(r))
		end
		local okC, kids = pcall(function() return { f:GetChildren() } end)
		for i, kid in ipairs(okC and kids or {}) do
			local label = call(kid, "GetName") or keyOf(f, kid) or ("#c" .. i)
			walk(kid, path .. "." .. tostring(label), depth + 1)
		end
	end
	for _, root in ipairs(rootsList or {}) do
		walk(root, tostring(call(root, "GetName") or keyOf(UIParent, root) or "?"), 0)
	end
	return lines
end
