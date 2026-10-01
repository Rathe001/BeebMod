-- Small shared helpers. Nothing here touches the database or the UI, so the
-- headless tests can load this file on its own.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Util.lua")

local U = {}
BT.Util = U

-- NAMES IN THIS GAME HAVE TWO PARTS (Josh 2026-09-18). "Beeb Bob" is one
-- character, so a name can carry a space, and the realm suffix is no longer
-- "the bit after the hyphen" - it is the bit after the LAST hyphen, which is
-- Blizzard's own convention for a cross-realm name. The key therefore joins
-- on "@", which no name can contain, rather than on a hyphen that now means
-- something else.
--
--   UnitName()  -> "Beeb Bob", "Bob"      (realm in the second return)
--   combat log  -> "Beeb Bob" or "Beeb Bob-OtherRealm"
--   you typed   -> "beeb", "beeb bob", "Beeb-Bob"
local SEP = "@"

-- "Beeb Bob" -> "Beeb", "Bob". A single-word name has no surname.
function U.SplitName(name)
	if type(name) ~= "string" then
		return nil, nil
	end
	local first, last = name:match("^(%S+)%s+(.+)$")
	if first then
		return first, last
	end
	return name, nil
end

-- Does this even look like a character's name? (Josh 2026-09-18)
--
-- The channel-list parser swallowed "[1. General - Teldrassil] [3. LocalDefense
-- - Teldrassil]" and filed it as a person, because it was handed the list of
-- CHANNELS rather than a list of members. Anything read out of free text gets
-- checked here first: one or two words, letters only, the length a name can
-- actually be.
-- AN ACCENT IS A LETTER (Josh 2026-09-30, review). %a knows only the
-- unaccented ones, so "Zoë Ashfall" was junk: dropped from every list it came
-- in on, and swept out of the book at the next schema bump. A byte of a
-- longer letter (128 and up) counts as part of a letter, and lengths are
-- counted in letters: a byte from 128 to 191 carries on the letter before it.
local function letters(s)
	local n = 0
	for i = 1, #s do
		local b = s:byte(i)
		if b < 128 or b >= 192 then
			n = n + 1
		end
	end
	return n
end

function U.LooksLikeName(name)
	if type(name) ~= "string" then
		return false
	end
	name = name:match("^%s*(.-)%s*$")
	if name == "" or letters(name) > 25 then
		return false
	end
	local words = 0
	for word in name:gmatch("%S+") do
		words = words + 1
		if words > 2 then
			return false
		end
		-- letters only: no digits, no punctuation, no brackets
		local n = letters(word)
		if not word:match("^[%a\128-\255][%a'\128-\255]*$") or n < 2 or n > 14 then
			return false
		end
	end
	return words > 0
end

function U.HasSurname(name)
	return select(2, U.SplitName(name)) ~= nil
end

-- Returns key, fullName, realm. The full name keeps whatever spacing and case
-- the client gave us, because that is what the player sees on their portrait.
--
-- THE NAME ALONE, AT HOME (Josh 2026-09-24). A book belongs to one realm, so
-- "@ClassicBetaPvE2" on every one of its keys said the same thing sixteen
-- thousand times - a third of a packed character (Core/Pack.lua). A
-- character of the realm you are on is keyed by name; only a visitor from
-- another realm carries "@Realm".
function U.HomeRealm()
	local home = U.realm or (GetRealmName and GetRealmName())
	return home and (home:gsub("%s+", "")) or nil
end

-- A SURNAME IS NOT A REALM (Josh 2026-09-30: "pretty much everyone is
-- showing as belonging to the Olympus guild"). From the evening of
-- 2026-09-30 the game handed back a two-part name split in two, the surname
-- where the realm goes, and 1,163 characters were filed as "Scotty
-- Forever@Forever" in an evening. A realm that is the name's own surname is
-- no realm: the character is home.
function U.SurnameIsRealm(name, realm)
	local surname = type(name) == "string" and select(2, U.SplitName(name))
	return surname ~= nil and type(realm) == "string"
		and surname:gsub("%s+", ""):lower() == realm:gsub("%s+", ""):lower()
end

-- ONE BOOK A REALM, AND NO REALM IN A KEY (Josh 2026-09-30: "There should
-- just be a single realm, and if not, we need to just combine them (keep
-- rulesets separate though)"). Each ruleset is one realm with a book of its
-- own (BT.ScopeKey); inside it a character is keyed by name alone, whatever
-- realm the client names beside them. The realm the client named was wrong
-- three ways in one evening - the realm's other spelling, a number in the
-- GUID, a surname in the realm's place - and every wrong one split the book.
-- A "-Realm" on the end of a name is still taken off; the realm returned is
-- the book's own.
function U.Key(name, realm)
	if type(name) ~= "string" then
		return nil
	end
	name = name:match("^%s*(.-)%s*$")
	if name == "" then
		return nil
	end
	-- a trailing "-Something" is a realm only when we were not handed one and
	-- the tail looks like a realm (one word, no space): "Beeb Bob-Whitemane"
	-- loses it, and a typed "Beeb-Bob" becomes the name "Beeb Bob"
	if not realm then
		local base, tail = name:match("^(.*)%-([^%-%s]+)$")
		if base and base ~= "" then
			if U.realms and U.realms[tail:lower()] then
				name = base
			else
				-- not a realm we know: it was a hyphen standing in for the
				-- space between the two halves of the name
				name = base .. " " .. tail
			end
		end
	end
	return name, name, U.HomeRealm() or "?"
end

-- Remember every realm name we meet, so U.Key can tell "Beeb Bob-Whitemane"
-- (a cross-realm character) from "Beeb-Bob" (a name typed with a hyphen).
function U.LearnRealm(realm)
	if type(realm) ~= "string" or realm == "" then
		return
	end
	U.realms = U.realms or {}
	U.realms[realm:gsub("%s+", ""):lower()] = true
	U.realms[realm:lower()] = true
end

-- 26210 -> "26,210": digits, with commas from a thousand
function U.Commas(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (n < 0 and "-" or "") .. s
end

function U.Now()
	return (time and time()) or os.time()
end

-- 93800 -> "1 day"; the tooltip has room for two words, not a timestamp
function U.Ago(ts, now)
	if type(ts) ~= "number" then
		return "never"
	end
	local d = (now or U.Now()) - ts
	if d < 90 then
		return "just now"
	elseif d < 3600 then
		return math.floor(d / 60) .. " min"
	elseif d < 86400 then
		local h = math.floor(d / 3600)
		return h .. (h == 1 and " hour" or " hours")
	end
	local days = math.floor(d / 86400)
	return days .. (days == 1 and " day" or " days")
end

-- "just now", "20 min ago", "3 days ago", "never": Ago says the span, this
-- says it the way a sentence needs it - "last just now ago" was the first
-- thing Josh saw on a live tooltip (2026-09-18).
function U.Since(ts, now)
	local a = U.Ago(ts, now)
	if a == "just now" or a == "never" then
		return a
	end
	return a .. " ago"
end

-- One write per player per window, so a raid's worth of combat log events
-- costs one table lookup each instead of a database write each.
function U.Throttle(window)
	local seen, last = {}, 0
	return function(key, now)
		now = now or U.Now()
		-- the table only ever grows while you stand in one place; clearing it
		-- on the window boundary keeps it the size of what you can see
		if now - last >= window then
			wipe(seen)
			last = now
		end
		if seen[key] then
			return false
		end
		seen[key] = true
		return true
	end
end

-- How old an answer is allowed to be before we stop repeating it as if it
-- were true. Nothing refreshes these but meeting the character again.
U.STALE = { level = 43200 }

-- A level we saw once only ever goes up, so an old one is a floor: "3+".
function U.LevelText(p, now)
	if not p.level then
		return "?"
	end
	if p.levelAt and (now or U.Now()) - p.levelAt > U.STALE.level then
		return p.level .. "+"
	end
	return tostring(p.level)
end

-- WHAT AN ITEM IS (Josh 2026-09-28: Pick Pocket's best find read "item 5364").
-- This client answers C_Item.GetItemInfo; the old global may not be there.
-- The same answers either way - name, link, quality, level, and on to the
-- vendor price, eleventh - or nothing while the client has not loaded the
-- item. Then it is asked to, and GET_ITEM_INFO_RECEIVED says when it has.
-- (the answers passed on as they came: a table of them would lose any after
-- a nil in the middle, and the price is eleventh)
local function answered(item, ok, ...)
	if ok and (...) ~= nil then
		return ...
	end
	local id = tonumber(item)
	if id and C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, id)
	end
	return nil
end

function U.ItemInfo(item)
	if item == nil then
		return nil
	end
	local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if type(get) ~= "function" then
		return nil
	end
	return answered(item, pcall(get, item))
end

function U.ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	return 0.8, 0.8, 0.8
end

function U.Colorize(text, class)
	local r, g, b = U.ClassColor(class)
	-- floor, not the raw product: a class colour is a fraction, and "%x" of a
	-- fraction is an error rather than a colour
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text or "")
end

-- The FULL name of a unit (Josh 2026-09-18). The ledger filled up with
-- one-word names - "Arch", "Boe", "Night" - beside full ones from chat, which
-- is the same character twice. Whichever of these calls this build answers
-- with both halves, we take: the longest answer wins, and a GUID stitches the
-- halves together anyway (Core/DB.lua).
-- one answer weighed against the best so far (no table of answers: every
-- nameplate and mouseover asks this)
local function longer(best, realm, n, r)
	if type(n) == "string" and n ~= "" and n ~= UNKNOWNOBJECT then
		n = n:match("^([^%-]+)") or n -- GetUnitName can append "-Realm"
		if not best or #n > #best then
			best = n
		end
		realm = realm or r
	end
	return best, realm
end

function U.UnitFullName(unit)
	-- On 1.60.1.69893: GetUnitName -> "Febbys Stormseeker", UnitName and
	-- UnitFullName -> "Febbys". GetUnitName leads for that reason; the others
	-- stay as a fallback, and the longest answer wins if a build changes its
	-- mind (Josh 2026-09-18, /bt names).
	local best, realm
	if GetUnitName then
		best, realm = longer(best, realm, GetUnitName(unit, false))
	end
	if UnitFullName then
		best, realm = longer(best, realm, UnitFullName(unit))
	end
	if UnitName then
		best, realm = longer(best, realm, UnitName(unit))
	end
	-- (and a "realm" that is the surname is none: U.SurnameIsRealm)
	if not (issecretvalue and (issecretvalue(best) or issecretvalue(realm))) and U.SurnameIsRealm(best, realm) then
		realm = nil
	end
	return best, realm
end

-- a tag by its key; nothing when the Ledger, which keeps the tags, is not here
function U.TagByKey(key)
	if not BT.AllTags then
		return nil
	end
	for _, f in ipairs(BT.AllTags()) do
		if f.key == key then
			return f
		end
	end
	return nil
end

-- READABLE ON NEAR-BLACK (Josh 2026-09-19). A tag's colour is chosen to look
-- right inside a tinted pill; the same colour as bare text on the tooltip's
-- own dark panel can be all but invisible. This lifts a colour until its
-- brightest channel is worth reading, keeping the hue it was picked for.
function U.Bright(color, floor)
	if type(color) ~= "table" then
		return 0.85, 0.85, 0.85
	end
	local r, g, b = color[1] or 0.8, color[2] or 0.8, color[3] or 0.8
	local top = math.max(r, g, b)
	local want = floor or 0.82
	if top > 0 and top < want then
		local lift = want / top
		r, g, b = math.min(1, r * lift), math.min(1, g * lift), math.min(1, b * lift)
	end
	return r, g, b
end

-- WHO IS WRITING (Josh 2026-09-19). The book is shared by every character on
-- the realm and the side, so "who said this" is a real question - and the
-- answer reads like a quotation's source, which is what a note is.
-- AND WHICH REALM (Josh 2026-09-22). The settings file is account-wide, and
-- a session or a record filed under the name alone was shared by two
-- characters of that name on two realms. This is the same "Name@Realm" the
-- book keys on, falling back to the bare name if the realm is not knowable.
function U.MeKey()
	local me = U.Me()
	if not me then
		return "?"
	end
	-- always with the realm, unlike a book's key: the settings are
	-- account-wide, so this has to tell two realms apart
	local realm = U.HomeRealm()
	return realm and (me .. SEP .. realm) or me
end

function U.Me()
	if GetUnitName then
		local full = GetUnitName("player", false)
		if full and full ~= "" then
			return full
		end
	end
	if UnitName then
		return (UnitName("player"))
	end
	return nil
end

-- 9/19/26: short, unambiguous next to a name, and the same shape whatever the
-- client's locale does with month names.
function U.ShortDate(when)
	if not (when and date) then
		return nil
	end
	local ok, text = pcall(function()
		return ("%d/%d/%s"):format(tonumber(date("%m", when)), tonumber(date("%d", when)), date("%y", when))
	end)
	return ok and text or nil
end

-- "- Beeb Magus, 9/19/26" - who wrote a note and when, in the one shape it
-- wears everywhere it is shown: the unit tooltip, the note panel, the card.
-- Returns nil when there is nothing to credit.
function U.Credit(p)
	if not p then
		return nil
	end
	local when = U.ShortDate(p.noted)
	local by = p.notedBy
	if by and when then
		return ("- %s, %s"):format(by, when)
	elseif by then
		return "- " .. by
	end
	return when
end

-- THE CHARACTER WINDOW ON ONE OF ITS PAGES (Josh 2026-09-29: "Can the pvp
-- meter click open the pvp tab? and reputation click open the rep tab"). By
-- the game's own ToggleCharacter, so a second click closes it; and if the
-- window came up on another page, that page's side tab is pressed. Not the
-- Character page: its stats hold secret numbers, which the game refuses to
-- work out once an addon has opened the window (the error of 2026-09-29).
-- Nothing in a fight: the game will not let an addon open a window then.
U.CHARACTER_PAGES = {
	reputation = { frame = "ReputationFrame", tab = 2 },
	pvp = { frame = "PVPRankFrame", tab = 4 },
}
function U.OpenCharacter(page)
	local p = U.CHARACTER_PAGES[page]
	if not p or type(ToggleCharacter) ~= "function" then
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		U.Print("BeebMod can't open the character window during a fight.")
		return false
	end
	pcall(ToggleCharacter, p.frame)
	local sheet = _G.CharacterFrame
	local target = _G[p.frame] or (type(sheet) == "table" and sheet[p.frame])
	if type(sheet) == "table" and sheet.IsShown and sheet:IsShown()
		and type(target) == "table" and target.IsShown and not target:IsShown() then
		local tab = _G["CharacterFrameModeTab" .. p.tab]
		local press = tab and tab.GetScript
			and (tab:GetScript("OnClick") or tab:GetScript("OnMouseUp") or tab:GetScript("OnMouseDown"))
		if press then
			pcall(press, tab, "LeftButton")
		end
	end
	return true
end

function U.Print(...)
	print("|cff74c0fcBeebMod|r:", ...)
end
