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
function U.LooksLikeName(name)
	if type(name) ~= "string" then
		return false
	end
	name = name:match("^%s*(.-)%s*$")
	if name == "" or #name > 25 then
		return false
	end
	local words = 0
	for word in name:gmatch("%S+") do
		words = words + 1
		if words > 2 then
			return false
		end
		-- letters only: no digits, no punctuation, no brackets
		if not word:match("^[%a][%a']*$") or #word < 2 or #word > 14 then
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
	-- splits, and a typed "Beeb-Bob" becomes the name "Beeb Bob"
	if not realm then
		local base, tail = name:match("^(.*)%-([^%-%s]+)$")
		if base and base ~= "" then
			if U.realms and U.realms[tail:lower()] then
				name, realm = base, tail
			else
				-- not a realm we know: it was a hyphen standing in for the
				-- space between the two halves of the name
				name = base .. " " .. tail
			end
		end
	end
	if not realm or realm == "" then
		realm = U.realm or (GetRealmName and GetRealmName()) or "?"
	end
	-- Blizzard writes realm names with and without their spaces depending on
	-- where you read them; one spelling, or one character lands under two keys
	realm = realm:gsub("%s+", "")
	return name .. SEP .. realm, name, realm
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

function U.NameFromKey(key)
	if type(key) ~= "string" then
		return nil
	end
	return key:match("^(.*)" .. SEP)
end

-- The realm half of a player GUID ("Player-4372-0002BFB1") is a realm ID, not
-- a name, so it is only useful to tell two realms apart. We keep the ID and
-- resolve the name when we can see the unit.
function U.RealmFromGUID(guid)
	if type(guid) ~= "string" then
		return nil
	end
	return guid:match("^Player%-(%d+)%-")
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
U.STALE = { zone = 1800, guild = 14 * 86400, level = 43200 }

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

-- The zone is the first thing to rot: within the hour it is where they are,
-- after that it is trivia. Returns nil once it has gone off.
function U.ZoneText(p, now)
	if not (p.zone and p.zoneAt) then
		return nil
	end
	if (now or U.Now()) - p.zoneAt > U.STALE.zone then
		return nil
	end
	return p.zone
end

-- A guild holds for weeks, but say how old it is once it is over a day.
function U.GuildText(p, now)
	if not p.guild or p.guild == "" then
		return nil
	end
	local age = p.guildAt and ((now or U.Now()) - p.guildAt) or nil
	if age and age > 86400 then
		return ("%s (as of %s)"):format(p.guild, U.Since(p.guildAt, now))
	end
	return p.guild
end

-- WHICH WAY A PANEL OPENS (Josh 2026-09-19). The bar can be dragged anywhere,
-- so a panel cannot always open upward: against the top of the screen it opened
-- off it. It opens into whichever side has the room, and lines up with the edge
-- of its anchor that leaves it on screen.
--
-- Pure arithmetic in WoW's coordinates, where y counts up from the bottom of
-- the screen. Returns the panel's point, the anchor's point, and the offsets.
function U.Placement(a, panelW, panelH, screenW, screenH)
	local roomAbove = screenH - (a.top or 0)
	local roomBelow = a.bottom or 0
	local up = roomAbove >= panelH or roomAbove >= roomBelow
	local left = ((a.left or 0) + panelW) <= screenW or (a.right or 0) - panelW < 0
	if up then
		return left and "BOTTOMLEFT" or "BOTTOMRIGHT", left and "TOPLEFT" or "TOPRIGHT", 0, 6
	end
	return left and "TOPLEFT" or "TOPRIGHT", left and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, -6
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

function U.FlagByKey(key)
	for _, f in ipairs(BT.AllFlags()) do
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
	return U.Key(me) or me
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

function U.Print(...)
	print("|cff74c0fcBeebMod|r:", ...)
end
