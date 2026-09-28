-- EXPORT THE EXPEDITION'S DESCRIPTIONS FOR REVIEW (Josh 2026-09-28, the lore
-- rewrite, rules in docs/lore-rules.md). Reads the generated
-- Modules/Menagerie/LoreData.lua and writes every page, with the lookup keys
-- that reach it, to batch files in scripts/lore-work/export: the broad pages
-- (group, beast, race, family, type) as broad-NN.json, the mob pages as
-- npc-NN.json. Run from the repo root: lua scripts/export-lore.lua
local BROAD_SIZE, NPC_SIZE = 115, 150
local OUT = "scripts/lore-work/export/"

local f = assert(io.open("Modules/Menagerie/LoreData.lua", "rb"))
local src = f:read("*a")
f:close()
-- P is local in the file; make it a global so it can be read back
src = src:gsub("\nlocal P = {", "\nLORE_P = {", 1):gsub("P%[(%d+)%]", "LORE_P[%1]")
local BT = {}
assert(load(src, "LoreData"))(nil, BT)
local P, keys = LORE_P, {}
for key, entry in pairs(BT.MenagerieLoreData) do
	keys[entry] = keys[entry] or {}
	table.insert(keys[entry], key)
end

local function str(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
		elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t" end
		return string.format("\\u%04x", c:byte())
	end) .. '"'
end

local broad, npc = {}, {}
for _, e in ipairs(P) do
	local k = keys[e] or {}
	table.sort(k)
	local ks = {}
	for i, key in ipairs(k) do ks[i] = str(key) end
	local line = string.format('{"title":%s,"kind":%s,"keys":[%s],"text":%s}',
		str(e[2]), str(e[1]), table.concat(ks, ","), str(e[3]))
	table.insert(e[1] == "npc" and npc or broad, line)
end

os.execute(package.config:sub(1, 1) == "\\" and 'mkdir "scripts\\lore-work\\export" 2>nul'
	or "mkdir -p " .. OUT)
local function write(list, prefix, size)
	local n = 0
	for i = 1, #list, size do
		n = n + 1
		local chunk = {}
		for j = i, math.min(i + size - 1, #list) do chunk[#chunk + 1] = list[j] end
		local out = assert(io.open(string.format("%s%s-%02d.json", OUT, prefix, n), "wb"))
		out:write("[\n", table.concat(chunk, ",\n"), "\n]\n")
		out:close()
	end
	print(string.format("%s: %d pages in %d files", prefix, #list, n))
end
-- `lua scripts/export-lore.lua npc` writes the mob pages only, so the broad
-- batches already rewritten stay as they were
if arg[1] ~= "npc" then write(broad, "broad", BROAD_SIZE) end
write(npc, "npc", NPC_SIZE)
