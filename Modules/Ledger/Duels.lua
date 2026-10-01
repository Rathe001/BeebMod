-- Duel scores (Josh 2026-09-30: "I also like the idea of keeping duel scores
-- vs players").
--
-- The game says how every duel near you ends, in a system line: "Beeb Bob has
-- defeated Hanz Cout in a duel", or "Hanz Cout has fled from Beeb Bob in a
-- duel". Those with you in them are counted on the other player's row in the
-- Ledger's book (Modules/Ledger/Store.lua):
--
--   row.duelsWon    how many you won
--   row.duelsLost   how many you lost, a retreat included
--   row.duelAt      when the last one ended
--
-- The line names them; who they are - their realm, their class, their GUID -
-- comes from the unit you challenged or that challenged you, kept from the
-- moment the duel was asked for, or from one in front of you with that name.
-- Nothing is sent to anyone.
local _, BT = ...
local CreateFrame = BT.Cpu.For("Modules/Ledger/Duels.lua")

local U, N = BT.Util, BT.Notes

local D = {}
BT.LedgerDuels = D

-- a challenge is worth remembering this long: the duel has a count-in, and
-- then however long it lasts
D.PENDING = 900

function D.On()
	return BT.Enabled("ledger") and not (BT.settings and BT.settings.ledgerDuels == false)
end

-- ---------------------------------------------------------------------------
-- Reading the line
-- ---------------------------------------------------------------------------

-- A pattern from one of the client's own lines ("%1$s has defeated %2$s in
-- a duel"), and which name each capture is: the line is the client's, in the
-- client's language, so it is read with the client's own words.
function D.Matcher(fmt)
	if type(fmt) ~= "string" or fmt == "" then
		return nil
	end
	local order, n = {}, 0
	-- the names out of the way first, as markers no line has in it
	local marked = fmt:gsub("%%(%d)%$s", function(i)
		order[#order + 1] = tonumber(i)
		return "\1"
	end):gsub("%%s", function()
		n = n + 1
		order[#order + 1] = n
		return "\1"
	end)
	if #order ~= 2 then
		return nil
	end
	local pat = marked:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", "(.+)")
	return { pattern = "^" .. pat .. "%.?$", order = order }
end

local matchers
local function lines()
	if not matchers then
		matchers = {}
		-- %1$s is the winner in both; the second is the one who lost or fled
		for _, fmt in ipairs({
			_G.DUEL_WINNER_KNOCKOUT or "%1$s has defeated %2$s in a duel",
			_G.DUEL_WINNER_RETREAT or "%2$s has fled from %1$s in a duel",
		}) do
			matchers[#matchers + 1] = D.Matcher(fmt)
		end
	end
	return matchers
end

-- the winner and the loser a line names, or nil for any other line
function D.Parse(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
		return nil
	end
	for _, m in ipairs(lines()) do
		local a, b = text:match(m.pattern)
		if a then
			local got = {}
			got[m.order[1]], got[m.order[2]] = a, b
			return got[1], got[2]
		end
	end
	return nil
end

-- "Beeb Bob-ClassicBetaPvE" and "Beeb Bob" are one name here, and "Beeb"
-- is "Beeb Bob" too: a line may name the given half alone
local function bare(name)
	return (name:gsub("%-[^%-%s]+$", ""))
end

local function same(a, b)
	if not (a and b) then
		return false
	end
	a, b = bare(a), bare(b)
	return a == b or U.SplitName(a) == b or U.SplitName(b) == a
end

-- ---------------------------------------------------------------------------
-- Who it was against
-- ---------------------------------------------------------------------------

-- a player in front of you by that name: your target first
local function unitNamed(name)
	local units = { "target", "focus", "mouseover", "party1", "party2", "party3", "party4" }
	for i = 1, 40 do
		units[#units + 1] = "nameplate" .. i
	end
	for _, unit in ipairs(units) do
		local ok, there = pcall(UnitExists or error, unit)
		if ok and there and UnitIsPlayer and UnitIsPlayer(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
			local full = U.UnitFullName(unit)
			if full and same(full, name) then
				return unit
			end
		end
	end
	return nil
end

-- the duel asked for, by either of you: who, and when
function D.Asked(unitOrName)
	local unit = unitOrName
	if type(unit) == "string" and not (UnitExists and UnitExists(unit)) then
		unit = unitNamed(unitOrName)
	end
	local key, info
	if unit then
		key, info = N.Face(unit)
	end
	local name = info and info.name or (type(unitOrName) == "string" and not unit and unitOrName) or nil
	D.pending = (key or name) and { key = key, info = info, name = name, at = U.Now() } or nil
	return D.pending
end

-- the key and face of the one a duel was against, `name` as the line says it
function D.Opponent(name)
	local p = D.pending
	if p and p.key and U.Now() - p.at <= D.PENDING and same(p.name, name) then
		return p.key, p.info
	end
	local unit = unitNamed(name)
	if unit then
		return N.Face(unit)
	end
	-- the line's own spelling, when it is a whole name
	local plain = bare(name)
	if U.HasSurname(plain) then
		local key, full = U.Key(name)
		return key, { name = full or plain }
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

-- A duel line: counted when you are in it. Returns the row it counted on,
-- and whether you won.
function D.Heard(text, now)
	if not D.On() then
		return nil
	end
	local winner, loser = D.Parse(text)
	if not winner then
		return nil
	end
	local me = U.Me()
	local won
	if same(winner, me) then
		won = true
	elseif same(loser, me) then
		won = false
	else
		return nil -- somebody else's duel
	end
	local key, info = D.Opponent(won and loser or winner)
	local p = key and N.Ensure(key, info)
	if not p then
		return nil
	end
	if won then
		p.duelsWon = (p.duelsWon or 0) + 1
	else
		p.duelsLost = (p.duelsLost or 0) + 1
	end
	p.duelAt = now or U.Now()
	D.pending = nil
	N.Touched(true)
	return p, won
end

-- "Won 3 of 4 duels · last 2 days ago", "Lost a duel · 5 minutes ago", or nil
-- for someone you have never dueled
function D.Line(p, now)
	local won = tonumber(p and p.duelsWon) or 0
	local lost = tonumber(p and p.duelsLost) or 0
	local n = won + lost
	if n < 1 then
		return nil
	end
	if n == 1 then
		return ("%s a duel · %s"):format(won == 1 and "Won" or "Lost", U.Since(p.duelAt, now))
	end
	return ("Won %d of %d duels · last %s"):format(won, n, U.Since(p.duelAt, now))
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

D.events = CreateFrame("Frame")
for _, event in ipairs({ "CHAT_MSG_SYSTEM", "DUEL_REQUESTED" }) do
	pcall(D.events.RegisterEvent, D.events, event)
end
D.events:SetScript("OnEvent", function(_, event, text)
	if not D.On() then
		return
	end
	if event == "DUEL_REQUESTED" then
		-- they asked you: the name is theirs
		D.Asked(text)
	else
		D.Heard(text)
	end
end)

-- you asked them: the unit you asked
if type(hooksecurefunc) == "function" and type(_G.StartDuel) == "function" then
	hooksecurefunc("StartDuel", function(unit)
		if D.On() and type(unit) == "string" then
			D.Asked(unit)
		end
	end)
end
