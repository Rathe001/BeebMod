-- WHAT THE GAME DOES, DONE HERE TOO (2026-10-17, audit). The tests run on Lua
-- 5.4 and the game runs Lua 5.1 with secret values, and the two part ways in
-- three places that matter:
--
--   string.format("%s", nil) writes "nil" here and raises an error in game;
--   string.format("%d", 2.5) raises an error here and writes 2 in game;
--   a secret value (UnitHealth and the rest) was a plain number in the stubs,
--   so a sum or a comparison on one never failed here as it does in game.
--
-- Both test files run this first, before any addon file is loaded, so the
-- files' own `local type = type` and `string.format` see these.
--
--   local S = dofile("tests/strict.lua")
--   S.Secret(v)      a value that raises an error the way the client's
--                    secrets do; type() says what v is, issecretvalue says yes
--   S.IsSecret(v)    true for one of those
--   S.Reveal(v)      what a secret hides (a test's own look at it); v otherwise
--   S.Scan51(path)   what in a file Lua 5.1 does not have, as a list of lines
--                    (or in the source given after the path)
--
-- What a table cannot trap, so a misuse of these goes unseen here: testing one
-- in an `if` (a table is always true), comparing one with a number or a
-- string with == or ~= (Lua only asks __eq when both sides are tables), and
-- using one as a table key.
local S = {}
local rawtype, realFormat, realToNumber = type, string.format, tonumber
local unpack = table.unpack or unpack

-- ---------------------------------------------------------------------------
-- Secrets
-- ---------------------------------------------------------------------------

local hidden = setmetatable({}, { __mode = "k" })

local function refuse(what)
	return function()
		error("attempt to " .. what, 2)
	end
end

local arithmetic, compare = refuse("perform arithmetic on a secret value"), refuse("compare a secret value")
local SECRET = {
	__name = "secret",
	__add = arithmetic, __sub = arithmetic, __mul = arithmetic, __div = arithmetic, __mod = arithmetic,
	__pow = arithmetic, __unm = arithmetic, __idiv = arithmetic, __band = arithmetic, __bor = arithmetic,
	__bxor = arithmetic, __shl = arithmetic, __shr = arithmetic, __bnot = arithmetic,
	__lt = compare, __le = compare, __eq = compare,
	__concat = refuse("concatenate a secret value"), __len = refuse("get the length of a secret value"),
	__index = refuse("index a secret value"), __newindex = refuse("index a secret value"),
	__call = refuse("call a secret value"), __tostring = refuse("convert a secret value to text"),
}

function S.Secret(v)
	local s = setmetatable({}, SECRET)
	if v == nil then
		v = 0
	end
	hidden[s] = v
	return s
end

function S.IsSecret(v)
	return rawtype(v) == "table" and hidden[v] ~= nil
end

function S.Reveal(v)
	if rawtype(v) == "table" and hidden[v] ~= nil then
		return hidden[v]
	end
	return v
end

-- the client's type() says a secret number is a number
_G.type = function(v)
	local t = rawtype(v)
	if t == "table" and hidden[v] ~= nil then
		return rawtype(hidden[v])
	end
	return t
end
-- and tonumber of one is the same secret, not a quiet nil
_G.tonumber = function(v, ...)
	if rawtype(v) == "table" and hidden[v] ~= nil then
		return v
	end
	return realToNumber(v, ...)
end
_G.issecretvalue = S.IsSecret

-- ---------------------------------------------------------------------------
-- string.format as Lua 5.1 does it
-- ---------------------------------------------------------------------------

-- the conversions 5.1 has; 5.4 adds %a, %A and %F
local INTEGER = { d = true, i = true, c = true, o = true, u = true, x = true, X = true }
local FLOAT = { e = true, E = true, f = true, g = true, G = true }

-- the call site is the line that called string.format (level 3 from here)
local function refused(n, want, v, conv)
	error(("bad argument #%d to 'format' (%s expected, got %s): Lua 5.1 raises an error on %%%s of a %s")
		:format(n, want, rawtype(v), conv, rawtype(v)), 3)
end

local function format51(fmt, ...)
	if rawtype(fmt) ~= "string" or not fmt:find("%", 1, true) then
		return realFormat(fmt, ...)
	end
	local n = select("#", ...)
	local args = { ... }
	local i, anySecret = 0, false
	for conv in fmt:gmatch("%%[-+ #0]*%d*%.?%d*([%a%%])") do
		if conv ~= "%" then
			i = i + 1
			local v = args[i]
			if rawtype(v) == "table" and hidden[v] ~= nil then
				-- the client formats a secret, and what comes back is one too
				anySecret = true
				v = hidden[v]
				args[i] = v
			end
			local t = rawtype(v)
			if conv == "s" or conv == "q" then
				if t == "number" then
					-- 5.1 writes a number as %.14g: 5, not 5.0
					args[i] = realFormat("%.14g", v)
				elseif t ~= "string" then
					refused(i + 1, "string", v, conv)
				end
			elseif INTEGER[conv] or FLOAT[conv] then
				if t == "string" then
					v = realToNumber(v)
				end
				if rawtype(v) ~= "number" then
					refused(i + 1, "number", args[i], conv)
				end
				-- 5.1 casts to an integer, toward zero; 5.4 refuses a fraction
				if INTEGER[conv] and v ~= math.floor(v) and v == v and v ~= math.huge and v ~= -math.huge then
					v = v >= 0 and math.floor(v) or math.ceil(v)
				end
				args[i] = v
			else
				error(("invalid option '%%%s' to 'format': Lua 5.1 has no such conversion"):format(conv), 2)
			end
		end
	end
	local out = realFormat(fmt, unpack(args, 1, n))
	if anySecret then
		return S.Secret(out)
	end
	return out
end
string.format = format51
S.format = format51
S.realFormat = realFormat

-- ---------------------------------------------------------------------------
-- What Lua 5.1 does not have, found by reading the source
-- ---------------------------------------------------------------------------

-- the source as tokens, with strings and comments set aside: three lists, of
-- each token's kind, text and line (a table a token made the scan of three
-- megabytes slow); a string's escapes are checked as it is read
local function lex(src, hits)
	local K, T, L, nt = {}, {}, {}, 0
	local function push(kind, text, at)
		nt = nt + 1
		K[nt], T[nt], L[nt] = kind, text, at
	end
	local i, n, line = 1, #src, 1
	local function hit(at, what)
		hits[#hits + 1] = { at, what }
	end
	local function longBracket(at)
		local eqs = src:match("^%[(=*)%[", at)
		if not eqs then
			return nil
		end
		local close = "]" .. eqs .. "]"
		local j = src:find(close, at, true)
		local stop = j and (j + #close - 1) or n
		for _ in src:sub(at, stop):gmatch("\n") do
			line = line + 1
		end
		return stop + 1
	end
	-- (what ends a short string, or needs a look inside one, by its quote)
	local STOP = { ['"'] = '[\\"\n]', ["'"] = "[\\'\n]" }
	while i <= n do
		local c = src:sub(i, i)
		local blank = src:match("^[ \t\r\f\v]+", i)
		if blank then
			i = i + #blank
		elseif c == "\n" then
			line = line + 1
			i = i + 1
		elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
			local after = longBracket(i + 2)
			if after then
				i = after
			else
				i = src:find("\n", i, true) or n + 1
			end
		elseif c == "[" and src:match("^%[=*%[", i) then
			local at = line
			i = longBracket(i)
			push("str", "", at)
		elseif c == '"' or c == "'" then
			local at, j = line, i + 1
			while true do
				j = src:find(STOP[c], j)
				if not j then
					j = n + 1
					break
				end
				local d = src:sub(j, j)
				if d ~= "\\" then
					break
				end
				local e = src:sub(j + 1, j + 1)
				if e == "x" then
					hit(line, "the \\x escape (Lua 5.2)")
				elseif e == "u" then
					hit(line, "the \\u{} escape (Lua 5.3)")
				elseif e == "\n" then
					line = line + 1
				end
				j = j + 2
				if e == "z" then
					hit(line, "the \\z escape (Lua 5.2)")
					-- it skips the white space after it, line ends too
					while j <= n and src:sub(j, j):match("%s") do
						if src:sub(j, j) == "\n" then
							line = line + 1
						end
						j = j + 1
					end
				end
			end
			push("str", "", at)
			-- (a string cut off by a line end leaves the line end to be counted)
			i = src:sub(j, j) == c and j + 1 or j
		elseif c:match("%d") or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
			local j = i
			local hex = src:match("^0[xX]", i) ~= nil
			while j <= n do
				local d = src:sub(j, j)
				if d:match("[%w%.]") then
					j = j + 1
				elseif (d == "+" or d == "-") and src:sub(j - 1, j - 1):match(hex and "[pP]" or "[eE]") then
					j = j + 1
				else
					break
				end
			end
			local num = src:sub(i, j - 1)
			if hex and num:find("[%.pP]") then
				hit(line, "a hexadecimal fraction or exponent (Lua 5.2): " .. num)
			end
			push("num", num, line)
			i = j
		else
			local w = src:match("^[%a_][%w_]*", i)
			if w then
				push("name", w, line)
				i = i + #w
			else
				local op = src:sub(i, i + 2)
				if op ~= "..." then
					op = src:sub(i, i + 1)
					if not (op == "//" or op == "::" or op == "<<" or op == ">>" or op == "==" or op == "~="
						or op == "<=" or op == ">=" or op == "..") then
						op = c
					end
				end
				push("op", op, line)
				i = i + #op
			end
		end
	end
	return K, T, L, nt
end

local SYNTAX = {
	["//"] = "floor division // (Lua 5.3)", ["<<"] = "the shift operator << (Lua 5.3)",
	[">>"] = "the shift operator >> (Lua 5.3)", ["&"] = "the bitwise operator & (Lua 5.3)",
	["|"] = "the bitwise operator | (Lua 5.3)", ["~"] = "the bitwise operator ~ (Lua 5.3)",
	["::"] = "a goto label (Lua 5.2)",
}
-- library names 5.1 does not have; the words after are where they came in
local LIBRARY = {
	["table.unpack"] = "5.2", ["table.pack"] = "5.2", ["table.move"] = "5.3",
	["math.tointeger"] = "5.3", ["math.type"] = "5.3", ["math.ult"] = "5.3",
	["math.maxinteger"] = "5.3", ["math.mininteger"] = "5.3",
	["string.pack"] = "5.3", ["string.unpack"] = "5.3", ["string.packsize"] = "5.3",
	["coroutine.isyieldable"] = "5.3", ["coroutine.close"] = "5.4",
}
-- globals 5.1 has not got, found only when called
local CALLS = { rawlen = "5.2", warn = "5.4" }
-- metamethods 5.1 never asks a table for
local META = { __pairs = "5.2", __ipairs = "5.2", __len = "5.2 (for a table)", __close = "5.4",
	__idiv = "5.3", __band = "5.3", __bor = "5.3", __bxor = "5.3", __shl = "5.3", __shr = "5.3",
	__bnot = "5.3", __gc = "5.2 (for a table)" }
-- an operand of these is a fallback, as in `unpack or table.unpack`
local GUARD_BEFORE = { ["or"] = true, ["and"] = true, ["not"] = true, ["if"] = true }
local GUARD_AFTER = { ["or"] = true, ["and"] = true, ["then"] = true }

function S.Scan51(path, src)
	if not src then
		local f = io.open(path, "rb")
		if not f then
			return { path .. ": cannot be read" }
		end
		src = f:read("*a")
		f:close()
	end
	local raw = {}
	local K, T, L, nt = lex(src, raw)
	local hits = {}
	for _, h in ipairs(raw) do
		hits[#hits + 1] = ("%s:%d: %s"):format(path, h[1], h[2])
	end
	local function add(k, what)
		hits[#hits + 1] = ("%s:%d: %s"):format(path, L[k], what)
	end
	-- a file that says `local unpack = unpack or table.unpack` may call it bare
	local ownUnpack = false
	for k = 1, nt do
		if T[k] == "local" and T[k + 1] == "unpack" then
			ownUnpack = true
		end
	end
	for k = 1, nt do
		local kind, w, prev, nx = K[k], T[k], T[k - 1], T[k + 1]
		local field = K[k - 1] == "op" and (prev == "." or prev == ":")
		if kind == "op" and SYNTAX[w] then
			add(k, SYNTAX[w])
		elseif kind == "name" and not field then
			if w == "goto" then
				add(k, "goto (Lua 5.2)")
			elseif w == "local" then
				-- local x <const>, local f <close>
				local j = k + 1
				while j <= nt and (K[j] == "name" or T[j] == ",") do
					if K[j] == "name" and T[j + 1] == "<" and K[j + 2] == "name" and T[j + 3] == ">" then
						add(k, ("a <%s> attribute (Lua 5.4)"):format(T[j + 2]))
					end
					j = j + 1
				end
			elseif META[w] then
				add(k, ("the %s metamethod, which Lua 5.1 never calls (Lua %s)"):format(w, META[w]))
			elseif CALLS[w] and nx == "(" then
				add(k, ("%s() (Lua %s)"):format(w, CALLS[w]))
			elseif w == "load" and nx == "(" and K[k + 2] == "str" then
				add(k, "load() of a string; Lua 5.1's load takes a function (use loadstring)")
			elseif w == "utf8" and nx == "." then
				add(k, "the utf8 library (Lua 5.3)")
			elseif nx == "." and K[k + 2] == "name" then
				local q = w .. "." .. T[k + 2]
				if LIBRARY[q] and not GUARD_BEFORE[prev or ""] and not GUARD_AFTER[T[k + 3] or ""] then
					add(k, ("%s (Lua %s), with no `or` to fall back on"):format(q, LIBRARY[q]))
				end
			elseif w == "unpack" and not ownUnpack and prev ~= "or" and nx ~= "or" then
				add(k, "a bare global unpack: fine in game, but Lua 5.4 has none, so no test reaches this line"
					.. " (add `local unpack = unpack or table.unpack`)")
			end
		end
	end
	return hits
end

return S
