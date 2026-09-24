-- Sessions: what the dock's lines count as "this session" (Josh 2026-09-24).
--
-- Currency, Experience, Reputation and Pick Pocket each kept a session, and
-- each wrote out the same thirty lines to do it: where this character's is
-- kept, whether this load carries the last one on, starting one a frame after
-- the loading screen and again when switched on mid-way, the pace an hour and
-- how long something will take. Four copies had already drifted - Currency's
-- times read "12 min" where the others read "12m" - so they live here once.
--
-- Nothing here touches a frame except the one timer in OnWorld, so the
-- headless tests load it as it is.
local _, BT = ...
local CreateFrame, C_Timer = BT.Cpu.For("Core/Session.lua")

local U = BT.Util
local S = {}
BT.Session = S

-- how long a session runs before its pace means anything: one piece of loot
-- in the first ten seconds is not a thousand gold an hour
S.SETTLE = 60
-- when the client does not say whether this load is a reload, a session
-- touched this recently is taken to be the same one
S.CARRY = 120

-- This character's entry in `all`, keyed by name and realm. One an older
-- version filed under the name alone comes across first.
function S.Mine(all)
	local who = (U.MeKey and U.MeKey()) or (U.Me and U.Me()) or "?"
	local bare = U.Me and U.Me()
	if bare and bare ~= who and all[bare] and not all[who] then
		all[who], all[bare] = all[bare], nil
	end
	return all[who], who
end

-- A new session on a login, the same one on a reload - which is what the
-- loading screen's own arguments say. Without them (switched on mid-way), a
-- session touched in the last two minutes carries on.
function S.CarriesOn(s, initial, reloading, now)
	if type(s) ~= "table" then
		return false
	end
	if reloading then
		return true
	end
	return reloading == nil and not initial and (now or U.Now()) - (s.last or 0) < S.CARRY
end

-- This character's session in `all`: the one there, carried on, or
-- `fresh(now)` in its place.
function S.Open(all, initial, reloading, fresh)
	local s, who = S.Mine(all)
	local now = U.Now()
	if not S.CarriesOn(s, initial, reloading, now) then
		s = fresh(now)
		all[who] = s
	end
	s.last = now
	return s
end

-- The loading screen's half, for a module whose M.Start(initial, reloading)
-- begins or carries on its session: a frame later, once the book and its
-- settings are bound, and only if nothing began one in between.
function S.OnWorld(M, initial, reloading)
	if M.session then
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if not M.session then
				M.Start(initial, reloading)
			end
		end)
	else
		M.Start(initial, reloading)
	end
end

-- SWITCHED ON MID-SESSION (Josh 2026-09-22). The session only ever began from
-- PLAYER_ENTERING_WORLD, and that handler steps aside while its module is
-- off - so a module switched on after login had no session, and nothing to
-- show, until the next login.
function S.Ensure(M)
	if not M.session then
		M.Start(nil, nil)
	end
	return M.session
end

-- so much an hour since `since`, or nil while that is too recent to say
function S.Rate(amount, since, now)
	local secs = (now or U.Now()) - (since or 0)
	if secs < S.SETTLE then
		return nil
	end
	return (amount or 0) * 3600 / secs
end

-- "<1m", "25m", "2h 05m"
function S.Duration(secs)
	local mins = math.floor((secs or 0) / 60 + 0.5)
	if mins < 1 then
		return "<1m"
	elseif mins < 60 then
		return ("%dm"):format(mins)
	end
	return ("%dh %02dm"):format(math.floor(mins / 60), mins % 60)
end
