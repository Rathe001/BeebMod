-- One face for everything the toolkit writes, and a choice of which
-- (Josh 2026-09-23).
--
-- WHY OUR OWN FONT OBJECTS. Every FontString used to be made from one of the
-- client's font objects - GameFontHighlightSmall and the rest - and those are
-- shared with the whole interface and every other addon: changing them
-- changes everybody's text. So each one the toolkit uses has a twin here with
-- the same colour and shadow, cut in the chosen face, and the toolkit's code
-- asks for the twin by name. The client's own furniture that the toolkit only
-- restyles - chat, the hotkeys, the bags, the character sheet - keeps the
-- game's face: that text is the client's.
--
-- FACES ARE A LIST, SO TRYING ONE IS A LINE. Fira Code went in first and read
-- like a terminal (monospaced, and wide); Google Sans Flex followed the same
-- evening. To try another: put its two weights in Art/Fonts with its licence,
-- add a line to FACES, and restart the client - it lists an addon's files
-- when it starts, not on /reload. Then pick it on the General page or with
-- /bt font.
--
-- SIZES ARE THE GAME'S SIZES. Every size in the toolkit is written as it would
-- be in the game's own face, and goes through Fonts.Size, which adds the
-- chosen face's `shift`: a face that runs large at the same size (Fira) takes
-- a point off everywhere at once, rather than every file being retuned.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Fonts.lua")

local Fo = {}
BT.Fonts = Fo

-- key, what the page calls it, its name weight and its text weight, and how
-- many points to move every size by. "game" has no files: the twins stay plain
-- copies of the client's objects.
--
-- Both Google faces are published as variable fonts only; these are static
-- cuts of them (weight 600 and 500, optical size as small as each allows),
-- made with fontTools, and Google Sans is trimmed to Latin and punctuation -
-- it carries a dozen scripts and the client loads the whole file.
Fo.FACES = {
	{ key = "google", label = "Google Sans", shift = 0,
		name = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\GoogleSans-SemiBold.ttf",
		text = "Interface\\AddOns\\BeebMod\\Art\\Fonts\\GoogleSans-Medium.ttf" },
	{ key = "game", label = "Game", shift = 0 },
}
Fo.DEFAULT = "google"

-- ours, the game's it stands in for, its size in the game's face, its weight
local TWINS = {
	{ "BeebModFontNormal", "GameFontNormal", 12, "text" },
	{ "BeebModFontHighlight", "GameFontHighlight", 12, "text" },
	{ "BeebModFontHighlightSmall", "GameFontHighlightSmall", 10, "text" },
	{ "BeebModFontDisableSmall", "GameFontDisableSmall", 10, "text" },
	{ "BeebModFontNormalLarge", "GameFontNormalLarge", 15, "name" },
	{ "BeebModFontHighlightLarge", "GameFontHighlightLarge", 15, "name" },
	{ "BeebModNumberFontSmall", "NumberFontNormalSmall", 12, "text" },
}
Fo.TWINS = TWINS

local GAME_FACE = (_G.STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"

local function byKey(key)
	for _, f in ipairs(Fo.FACES) do
		if f.key == key then
			return f
		end
	end
	return nil
end

-- ONE FACE (Josh 2026-09-24: "Font can probably just stick to Google Sans").
-- The choice is gone and a face saved by an older version is not read: Google
-- Sans, or the game's own if its file will not load.
function Fo.Current()
	return byKey(Fo.broken and "game" or Fo.DEFAULT) or byKey("game")
end

-- a size in the game's face, in the face in use
function Fo.Size(n)
	-- below six points it is not type but a spacer (the tooltip draws its
	-- hairlines as lines a few points tall), and a spacer keeps its size
	if type(n) ~= "number" or n < 6 then
		return n
	end
	return math.max(6, n + (Fo.Current().shift or 0))
end

-- the file for a weight ("name" or "text"), or nil for the game's face
function Fo.Face(weight)
	local f = Fo.Current()
	return f[weight == "name" and "name" or "text"]
end

-- Try a file on something, and say whether the client would load it.
local function loads(obj, face, size, flags)
	local ok, loaded = pcall(obj.SetFont, obj, face, size, flags or "")
	return ok and loaded ~= false
end

-- FontStrings the toolkit sets a face on directly (the unit frames), so a new
-- choice reaches them without a reload. Weak: a string thrown away goes.
local direct = setmetatable({}, { __mode = "k" })

-- Put the face in use on a FontString: `weight` "name" or "text", `size` in
-- the game's face. Remembered, and put on again when the choice changes.
function Fo.Set(fs, weight, size, flags)
	direct[fs] = { weight = weight, size = size, flags = flags or "" }
	local face = Fo.Face(weight) or GAME_FACE
	if not loads(fs, face, Fo.Size(size), flags) then
		loads(fs, GAME_FACE, Fo.Size(size), flags)
	end
	return fs
end

local listeners = {}
function Fo.Register(fn)
	listeners[#listeners + 1] = fn
end

-- Cut every twin in the face in use and put it back on everything set directly.
-- A face whose files the client will not load (a restart not yet had) falls
-- back to the game's face for the session, and says so once.
function Fo.Apply()
	if not CreateFont then
		return 0
	end
	local made = 0
	local face = Fo.Current()
	for _, t in ipairs(TWINS) do
		local name, from, size, weight = t[1], t[2], t[3], t[4]
		local obj = _G[name] or CreateFont(name)
		local game = _G[from]
		local flags = ""
		if type(game) == "table" and obj.CopyFontObject then
			pcall(obj.CopyFontObject, obj, game)
			if game.GetFont then
				local _, _, f = game:GetFont()
				flags = f or ""
			end
		end
		local file = face[weight]
		if file then
			if loads(obj, file, Fo.Size(size), flags) then
				made = made + 1
			elseif not Fo.broken then
				Fo.broken = face.key
				if BT.Util and BT.Util.Print then
					BT.Util.Print(("%s would not load. Restart the game, because a /reload does not find new files. Until then, BeebMod uses the game's font.")
						:format(face.label))
				end
				return Fo.Apply()
			end
		else
			-- the game's face at the game's size, flags and all
			local gface, gsize = nil, nil
			if type(game) == "table" and game.GetFont then
				gface, gsize = game:GetFont()
			end
			loads(obj, gface or GAME_FACE, gsize or size, flags)
		end
	end
	for fs, how in pairs(direct) do
		local file = Fo.Face(how.weight) or GAME_FACE
		loads(fs, file, Fo.Size(how.size), how.flags)
		-- A NEW FACE DOES NOT REDRAW WHAT IS ALREADY WRITTEN (Josh 2026-09-23:
		-- the player's and the target's names went blank). The frames are
		-- built and painted, then the settings bind and the face goes on again
		-- - and a string given a face after its text keeps an empty line
		-- until its text changes, which a name never does. The target of
		-- target is repainted four times a second and came back on its own.
		-- So each one is written again, as it was. type() is the one question
		-- that is safe to ask of a secret string.
		if fs.GetText and fs.SetText then
			local ok, text = pcall(fs.GetText, fs)
			if ok and type(text) == "string" then
				pcall(fs.SetText, fs, "")
				pcall(fs.SetText, fs, text)
			end
		end
	end
	for _, fn in ipairs(listeners) do
		pcall(fn)
	end
	return made
end

-- Choose a face by key: saved, and put on everything now.
function Fo.Choose(key)
	local face = byKey(key)
	if not face then
		return false
	end
	BT.EnsureBound()
	BT.settings.font = key
	Fo.broken = nil
	Fo.Apply()
	return true
end

function Fo.Faces() return Fo.FACES end

Fo.Apply()

