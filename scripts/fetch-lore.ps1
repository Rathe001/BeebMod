<#
scripts/fetch-lore.ps1 (Josh 2026-09-26): the Menagerie's lore, from the
Warcraft Wiki.

    powershell -ExecutionPolicy Bypass -File scripts\fetch-lore.ps1

The game has no description of a creature an addon can read, and the
journal fills itself as you kill, so there is no list of mobs to look up.
What there IS a list of is what mobs are named after: races ("Rockjaw
TROGG"), tribes and clans ("FROSTMANE Troll Whelp"), beast families (a cat
is a Cat) and creature types. So this gathers those, all of them, from the
wiki's own categories, and the addon matches a mob to the most specific one
its name or its family names (Modules/Menagerie/Journal.lua, J.WikiLore).

Every mob already in the journal is looked up by its exact name as well, so a
mob with a page of its own - Hogger - has it. Run it again after playing and
the mobs met since are looked up too: it reads the saved file.

Writes Modules/Menagerie/LoreData.lua. The text is the wiki's, under CC BY-SA
3.0: each entry keeps the title of the page it came from, the addon credits
it where it is shown, and the file says so at its top.
#>
param(
	[string]$Saved = "",
	# build the file again from what was fetched last time, asking the wiki
	# for nothing but the journal's new mobs
	[switch]$Rebuild
)

$ErrorActionPreference = "Stop"
$Api = "https://warcraft.wiki.gg/api.php"
$UA = "BeebMod-Menagerie-lore/1.0 (WoW addon; josh@tummel.io)"
$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "Modules\Menagerie\LoreData.lua"

# the saved file: the one BeebMod writes, wherever the game keeps it
if (-not $Saved) {
	# the ACCOUNT's (WTF\Account\<name>\SavedVariables), where the journal is
	# kept - not a character's, three folders deeper, which has none of it
	$found = Get-ChildItem "C:\Program Files (x86)\World of Warcraft\_classic_beta_\WTF\Account" -Recurse -Filter "BeebMod.lua" -ErrorAction SilentlyContinue |
		Where-Object { $_.Directory.Name -eq "SavedVariables" -and $_.Directory.Parent.Parent.Name -eq "Account" } |
		Select-Object -First 1
	if ($found) { $Saved = $found.FullName }
}

function Invoke-Wiki([hashtable]$Query) {
	$Query["format"] = "json"
	$pairs = foreach ($k in $Query.Keys) { "{0}={1}" -f $k, [uri]::EscapeDataString([string]$Query[$k]) }
	$url = $Api + "?" + ($pairs -join "&")
	# A GUEST ON SOMEONE ELSE'S WIKI: a second between asks, and when the
	# wiki says to slow down, it waits and asks again, longer each time,
	# rather than giving up half way (it said so at four a second)
	$wait = 15
	for ($try = 1; $try -le 6; $try++) {
		Start-Sleep -Milliseconds 1000
		try {
			$r = Invoke-RestMethod -Uri $url -UserAgent $UA
			if ($r.error -and $r.error.code -eq "ratelimited") { throw "ratelimited" }
			return $r
		} catch {
			if ($try -eq 6) { throw }
			Write-Host ("  the wiki asked us to slow down; waiting {0}s" -f $wait)
			Start-Sleep -Seconds $wait
			$wait = $wait * 2
		}
	}
}

# Every page in a category, and in its sub-categories to `depth`. Each item
# of a result is kept one at a time: a one-element list of pages must not
# collapse into the page (see the memory note on pipeline flattening).
function Get-CategoryPages([string]$Category, [int]$Depth) {
	$pages = New-Object System.Collections.Generic.List[string]
	$cont = $null
	do {
		$q = @{ action = "query"; list = "categorymembers"; cmtitle = $Category; cmlimit = "500"; cmtype = "page|subcat" }
		if ($cont) { $q["cmcontinue"] = $cont }
		$r = Invoke-Wiki $q
		foreach ($m in @($r.query.categorymembers)) {
			if ($m.ns -eq 14) {
				if ($Depth -gt 0) {
					foreach ($p in (Get-CategoryPages $m.title ($Depth - 1))) { $pages.Add($p) }
				}
			} elseif ($m.ns -eq 0) {
				$pages.Add($m.title)
			}
		}
		$cont = if ($r.continue) { $r.continue.cmcontinue } else { $null }
	} while ($cont)
	return ,$pages
}

# The sub-categories under a category, to `depth`: their titles alone
function Get-Subcats([string]$Category, [int]$Depth) {
	$cats = New-Object System.Collections.Generic.List[string]
	$cont = $null
	do {
		$q = @{ action = "query"; list = "categorymembers"; cmtitle = $Category; cmlimit = "500"; cmtype = "subcat" }
		if ($cont) { $q["cmcontinue"] = $cont }
		$r = Invoke-Wiki $q
		foreach ($m in @($r.query.categorymembers)) {
			$cats.Add($m.title)
			if ($Depth -gt 1) {
				foreach ($c in (Get-Subcats $m.title ($Depth - 1))) { $cats.Add($c) }
			}
		}
		$cont = if ($r.continue) { $r.continue.cmcontinue } else { $null }
	} while ($cont)
	return ,$cats
}

# EVERY CLASSIC MOB, NOT ONLY THE ONES MET (Josh 2026-09-26: "Darkshore
# thresher doesn't show the proper lore. Is there a way we can make sure
# we're matching the mob properly"). It was matched as well as it could be:
# its page had never been fetched, since it was killed after the last run.
# The wiki files mobs by where they are - "Darkshore mobs", with "Removed
# Darkshore mobs" under it for the ones Cataclysm took away, the Thresher
# among them - so every Classic zone's, dungeon's and raid's is gathered
# ahead of the kill. Named as the wiki names them, less "The".
$ClassicPlaces = @("Ashenvale", "Azshara", "Darkshore", "Desolace", "Durotar", "Dustwallow Marsh", "Felwood",
	"Feralas", "Moonglade", "Mulgore", "Silithus", "Stonetalon Mountains", "Tanaris", "Teldrassil", "Barrens",
	"Northern Barrens", "Southern Barrens", "Thousand Needles", "Un'Goro Crater", "Winterspring",
	"Alterac Mountains", "Arathi Highlands", "Badlands", "Blasted Lands", "Burning Steppes", "Deadwind Pass",
	"Dun Morogh", "Duskwood", "Eastern Plaguelands", "Elwynn Forest", "Hillsbrad Foothills", "Loch Modan",
	"Redridge Mountains", "Searing Gorge", "Silverpine Forest", "Stranglethorn Vale", "Northern Stranglethorn",
	"Cape of Stranglethorn", "Swamp of Sorrows", "Hinterlands", "Tirisfal Glades", "Western Plaguelands",
	"Westfall", "Wetlands", "Blackrock Mountain", "Alterac Valley", "Stormwind City", "Ironforge", "Darnassus",
	"Orgrimmar", "Thunder Bluff", "Undercity", "Deeprun Tram", "Ahn'Qiraj: The Fallen Kingdom",
	"Ragefire Chasm", "Wailing Caverns", "Deadmines", "Shadowfang Keep", "Blackfathom Deeps", "Stockade",
	"Stormwind Stockade", "Gnomeregan", "Razorfen Kraul", "Scarlet Monastery", "Razorfen Downs", "Uldaman",
	"Zul'Farrak", "Maraudon", "Sunken Temple", "Temple of Atal'Hakkar", "Blackrock Depths", "Blackrock Spire",
	"Lower Blackrock Spire", "Upper Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance", "Molten Core",
	"Onyxia's Lair", "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Naxxramas",
	"Warsong Gulch", "Arathi Basin")
function PlaceKey([string]$s) {
	return ($s -replace '^Category:', '' -replace ' mobs$', '' -replace '^The ', '').ToLowerInvariant()
}

# A KIND OF CREATURE (the same day): "Darkshore Threshers are threshadons",
# and Threshadon is a page - but not in the Beasts category itself, two
# levels under it (Beasts, Dinosaurs, Threshadons). Each kind's category is
# named for the kind, so the name is the page to ask for; the wiki's
# redirect takes "Threshadons" to "Threshadon". Lists of individuals and
# the like are not kinds.
$NotAKind = '( by |named|characters|mobs|npcs|pets|mounts|companions|battle pet|images|quest|lists?$|stubs)'
# English plurals, the common ones, as the addon's own J.Singular reads them
function Singular([string]$s) {
	if ($s -match 'ies$') { return $s -replace 'ies$', 'y' }
	if ($s -match '(wolves|elves|dwarves|halves)$') { return $s -replace 'ves$', 'f' }
	if ($s -match '(ches|shes|sses|xes)$') { return $s -replace 'es$', '' }
	if ($s -match '[^s]s$') { return $s -replace 's$', '' }
	return $s
}

# title -> kind, the most specific kind winning: a mob's own page, then a
# tribe or clan, a race, an animal, a beast family, a creature type
$Rank = @{ npc = 6; group = 5; race = 4; beast = 3; family = 2; type = 1 }
$want = @{}
function Want([string]$Title, [string]$Kind) {
	if (-not $Title) { return }
	if (-not $want.ContainsKey($Title) -or $Rank[$Kind] -gt $Rank[$want[$Title]]) {
		$want[$Title] = $Kind
	}
}

$Types = @("Beast", "Humanoid", "Undead", "Demon", "Dragonkin", "Elemental", "Giant", "Mechanical", "Critter")
$Cache = Join-Path $PSScriptRoot "lore-cache.json"

# what was fetched before: from the cache, or (the first time there is none)
# from the data file itself, one entry per page
$lore = @{}
# THE CACHE IS KEPT EITHER WAY: a full run asks the wiki only for pages it
# has never been asked for, so gathering every Classic mob is a long first
# run and a short one after
if (Test-Path $Cache) {
	$json = Get-Content -Raw -LiteralPath $Cache | ConvertFrom-Json
	foreach ($p in $json.PSObject.Properties) {
		$lore[$p.Name] = @{ title = $p.Value.title; text = $p.Value.text; kind = $p.Value.kind }
	}
}
# the pages asked for that the wiki had nothing for, so they are not asked again
$Missing = Join-Path $PSScriptRoot "lore-missing.json"
$nothing = @{}
# PowerShell 5 hands a JSON array back as ONE object, so @(... | ConvertFrom-Json)
# is a list of one list (the memory note on pipeline flattening): taken into
# a variable first, and any list inside it - an earlier run's mistake - opened
function Add-Nothing($v) {
	if ($v -is [array]) { foreach ($x in $v) { Add-Nothing $x } } elseif ($v) { $nothing[[string]$v] = $true }
}
if (Test-Path $Missing) {
	$read = Get-Content -Raw -LiteralPath $Missing | ConvertFrom-Json
	Add-Nothing $read
}
if ($Rebuild) {
	if ($lore.Count -gt 0) {
	} elseif (Test-Path $Out) {
		foreach ($line in (Get-Content -LiteralPath $Out)) {
			$m = [regex]::Match($line, '^\s*\["(?:[^"\\]|\\.)*"\] = \{ "([a-z]+)", "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)" \},$')
			if ($m.Success) {
				$title = $m.Groups[2].Value -replace '\\"', '"' -replace '\\\\', '\'
				if (-not $lore.ContainsKey($title)) {
					$lore[$title] = @{ title = $title; kind = $m.Groups[1].Value
						text = ($m.Groups[3].Value -replace '\\n', "`n" -replace '\\"', '"' -replace '\\\\', '\') }
				}
			}
		}
	}
	Write-Host ("rebuilding from {0} pages fetched before" -f $lore.Count)
} else {
	Write-Host "gathering races..."
	foreach ($t in (Get-CategoryPages "Category:Races" 0)) { Want $t "race" }
	Write-Host "gathering tribes, clans and organizations..."
	foreach ($c in @("Category:Organizations by race", "Category:Tribes", "Category:Clans")) {
		foreach ($t in (Get-CategoryPages $c 2)) { Want $t "group" }
	}
	Write-Host "gathering animals..."
	foreach ($t in (Get-CategoryPages "Category:Beasts" 0)) { Want $t "beast" }
	# the beast families the client names (UnitCreatureFamily), each by its own name
	$families = @("Bat", "Bear", "Beetle", "Bird of prey", "Boar", "Carrion bird", "Cat", "Chimaera", "Core hound",
		"Crab", "Crane", "Crocolisk", "Devilsaur", "Direhorn", "Dog", "Dragonhawk", "Fox", "Goat", "Gorilla", "Gruffhorn",
		"Hydra", "Hyena", "Lizard", "Monkey", "Moth", "Nether ray", "Owl", "Porcupine", "Raptor", "Ravager", "Rodent",
		"Scorpid", "Serpent", "Shale spider", "Spider", "Spirit beast", "Sporebat", "Stag", "Tallstrider", "Toad",
		"Turtle", "Warp stalker", "Wasp", "Water strider", "Wind serpent", "Wolf", "Worm", "Gryphon", "Hippogryph", "Silithid")
	foreach ($f in $families) { Want $f "family" }
	Write-Host "gathering the kinds of animal..."
	foreach ($c in (Get-Subcats "Category:Beasts" 2)) {
		$name = $c -replace '^Category:', ''
		# the category is plural and the page is not ("Threshadons" has no
		# page, "Threshadon" has), and the wiki does not redirect between them
		if ($name -notmatch $NotAKind) { Want (Singular $name) "beast" }
	}
	Write-Host "gathering every Classic zone's, dungeon's and raid's mobs..."
	$places = @{}
	foreach ($p in $ClassicPlaces) { $places[(PlaceKey $p)] = $true }
	$matched = @{}
	foreach ($index in @("Category:Mobs by zone", "Category:Mobs by instance")) {
		foreach ($c in (Get-Subcats $index 1)) {
			$k = PlaceKey $c
			if ($places.ContainsKey($k)) {
				$matched[$k] = $true
				# depth 1: "Removed Darkshore mobs" is under "Darkshore mobs"
				foreach ($t in (Get-CategoryPages $c 1)) { Want $t "npc" }
			}
		}
	}
	$unmatched = @($ClassicPlaces | Where-Object { -not $matched.ContainsKey((PlaceKey $_)) })
	if ($unmatched.Count -gt 0) { Write-Host ("  no category for: " + ($unmatched -join ", ")) }
	foreach ($t in (Get-CategoryPages "Category:Classic NPCs" 0)) { Want $t "npc" }
}
# A TYPE IS A TYPE (Josh 2026-09-26): "Beast" is in the wiki's Beasts category
# as well, and filed as an animal it outranked a mob's own family - Prideclaw
# was "most standard animals are beasts" before it was a cat
foreach ($t in $Types) { $want[$t] = "type" }
foreach ($t in $Types) { if ($lore.ContainsKey($t)) { $lore[$t].kind = "type" } }

# every mob in the journal, by its exact name
if ($Saved -and (Test-Path $Saved)) {
	Write-Host "reading the journal's mobs from $Saved"
	$text = Get-Content -Raw -LiteralPath $Saved
	$m = [regex]::Match($text, '\["menagerie"\]\s*=\s*\{')
	if ($m.Success) {
		$names = [regex]::Matches($text.Substring($m.Index), '\["name"\]\s*=\s*"((?:[^"\\]|\\.)*)"')
		foreach ($n in $names) { Want $n.Groups[1].Value "npc" }
	}
}

function Save-Cache {
	$keep = @{}
	foreach ($k in $lore.Keys) { $keep[$k] = $lore[$k] }
	[IO.File]::WriteAllText($Cache, ($keep | ConvertTo-Json -Depth 4 -Compress), (New-Object System.Text.UTF8Encoding($false)))
	$none = @($nothing.Keys | Sort-Object)
	[IO.File]::WriteAllText($Missing, (ConvertTo-Json -InputObject $none -Compress), (New-Object System.Text.UTF8Encoding($false)))
}

# the pages' opening sentences, twenty at a time; a title that redirects or
# is written differently comes back under its own name, so follow the trail.
# On a rebuild, only what has never been asked.
$titles = @($want.Keys | Where-Object { -not $lore.ContainsKey($_) -and -not $nothing.ContainsKey($_) -and -not ($Rebuild -and $want[$_] -ne "npc") })
# a page fetched before under a lesser kind takes the kind it is wanted as now
foreach ($t in $want.Keys) {
	if ($lore.ContainsKey($t) -and $Rank[$want[$t]] -gt $Rank[$lore[$t].kind]) { $lore[$t].kind = $want[$t] }
}
Write-Host ("{0} pages to read" -f $titles.Count)
for ($i = 0; $i -lt $titles.Count; $i += 20) {
	$batch = $titles[$i..([Math]::Min($i + 19, $titles.Count - 1))]
	$r = Invoke-Wiki @{ action = "query"; prop = "extracts"; exintro = "1"; explaintext = "1"; exsentences = "3";
		exlimit = "20"; redirects = "1"; titles = ($batch -join "|") }
	$from = @{}
	foreach ($t in $batch) { $from[$t] = $t }
	foreach ($n in @($r.query.normalized)) { if ($n) { $from[$n.to] = $from[$n.from] } }
	foreach ($d in @($r.query.redirects)) { if ($d) { $from[$d.to] = $(if ($from[$d.from]) { $from[$d.from] } else { $d.from }) } }
	$got = @{}
	foreach ($p in $r.query.pages.PSObject.Properties) {
		$page = $p.Value
		if ($page.missing -ne $null -or -not $page.extract) { continue }
		$asked = if ($from[$page.title]) { $from[$page.title] } else { $page.title }
		$lore[$asked] = @{ title = $page.title; text = ($page.extract -replace '\s+', ' ').Trim(); kind = $want[$asked] }
		$got[$asked] = $true
	}
	foreach ($t in $batch) { if (-not $got.ContainsKey($t)) { $nothing[$t] = $true } }
	Write-Host ("  {0} of {1}" -f [Math]::Min($i + 20, $titles.Count), $titles.Count)
	# kept as it goes: a run stopped half way keeps what it had
	if (($i / 20) % 25 -eq 24) { Save-Cache }
}
Save-Cache

# A GROUP IS A GROUP (Josh 2026-09-26: "Living Lightning" was "a gryphon
# located at the sea base of Highbank"). The organization categories hold
# their MEMBERS as well - people, mounts, ships - so a page from them is kept
# only when its title reads as a group: a tribe, a clan, a brotherhood...
# or "Bloodfeather harpies", a people of a race.
$OrgWord = '\b(tribe|tribes|clan|clans|pack|brood|brotherhood|syndicate|cult|order|legion|expedition|company|crusade|covenant|gang|kingdom|horde|league|society|council|circle|conclave|cartel|dragonflight|flight|remnant|remnants|army|band|coven|family|guild|faction|alliance|dynasty|empire)$'
$RacePlural = '^(\S+) (harpies|harpy|trolls|troll|troggs|trogg|gnolls|gnoll|kobolds|kobold|murlocs|murloc|ogres|ogre|quilboar|centaurs|centaur|satyrs|satyr|furbolgs|furbolg|naga|dwarves|dwarf|goblins|goblin|orcs|orc|humans|human|elves|elf|tauren|draenei|arakkoa|ethereals|ethereal|nerubians|nerubian|trogs|wolvar|gorlocs|gorloc|jinyu|hozen|mogu|saurok|sethrak|vulpera|tortollans|tortollan|kobalds)$'
function IsGroupTitle([string]$Title) {
	$t = ($Title -replace '\s*\([^)]*\)\s*$', '').ToLowerInvariant().Trim()
	return ($t -match $OrgWord) -or ($t -match $RacePlural)
}

# the key a page is found by: its title in lower case, without "(pet family)"
# and the like; a tribe or clan also by its name alone ("frostmane"), and a
# people of a race by theirs ("bloodfeather")
function Keys([string]$Title) {
	$k = ($Title -replace '\s*\([^)]*\)\s*$', '').ToLowerInvariant().Trim()
	$out = @($k)
	$bare = $k -replace '\s+(tribe|tribes|clan|clans|pack|brood|gang|cartel|family|order|legion|kingdom|horde)$', ''
	if ($bare -ne $k) { $out += $bare }
	$people = [regex]::Match($k, $RacePlural)
	if ($people.Success) { $out += $people.Groups[1].Value }
	return ,$out
}

function LuaString([string]$s) {
	return '"' + ($s -replace '\\', '\\' -replace '"', '\"' -replace "`r", '' -replace "`n", '\n') + '"'
}

$entries = @{}
$dropped = 0
foreach ($asked in $lore.Keys) {
	$e = $lore[$asked]
	if ($e.kind -eq "group" -and -not (IsGroupTitle $e.title)) {
		$dropped++
		continue
	}
	foreach ($k in (Keys $asked)) {
		if (-not $entries.ContainsKey($k) -or $Rank[$e.kind] -gt $Rank[$entries[$k].kind]) {
			$entries[$k] = $e
		}
	}
}
# and by the page the wiki led to, where nothing has that name already:
# "threshadons" was asked, "Threshadon" is the page, and a mob's page says
# "threshadon" as often as "threshadons"
foreach ($asked in $lore.Keys) {
	$e = $lore[$asked]
	if ($e.kind -eq "group" -and -not (IsGroupTitle $e.title)) { continue }
	foreach ($k in (Keys $e.title)) {
		if (-not $entries.ContainsKey($k)) { $entries[$k] = $e }
	}
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- The Menagerie's lore: the opening lines of the Warcraft Wiki's pages on")
[void]$sb.AppendLine("-- the races, tribes, clans, animals, beast families and creature types mobs")
[void]$sb.AppendLine("-- are named after. GENERATED by scripts/fetch-lore.ps1 on " + (Get-Date -Format "yyyy-MM-dd") + "; do not edit.")
[void]$sb.AppendLine("--")
[void]$sb.AppendLine("-- Text from the Warcraft Wiki (https://warcraft.wiki.gg), available under")
[void]$sb.AppendLine("-- CC BY-SA 3.0 (https://creativecommons.org/licenses/by-sa/3.0/). Each entry")
[void]$sb.AppendLine("-- names the page it came from, and the addon credits it where it is shown.")
[void]$sb.AppendLine("--   P[n] = { kind, page title, text }; key = P[n]")
# EACH PAGE ONCE (Josh 2026-09-26: "Do all these lore strings inflate the
# addon size too much?"). A page is found by several keys - "harpy",
# "harpies", each harpy tribe - and was written out whole for each; now it is
# written once and every key names it, the same table in the game.
[void]$sb.AppendLine("local _, BT = ...")
[void]$sb.AppendLine("local P = {")
$index = @{}
$n = 0
foreach ($k in ($entries.Keys | Sort-Object)) {
	$e = $entries[$k]
	$id = $e.kind + "`t" + $e.title + "`t" + $e.text
	if (-not $index.ContainsKey($id)) {
		$n++
		$index[$id] = $n
		[void]$sb.AppendLine(("	{{ {0}, {1}, {2} }}," -f (LuaString $e.kind), (LuaString $e.title), (LuaString $e.text)))
	}
}
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("BT.MenagerieLoreData = {")
foreach ($k in ($entries.Keys | Sort-Object)) {
	$e = $entries[$k]
	[void]$sb.AppendLine(("	[{0}] = P[{1}]," -f (LuaString $k), $index[$e.kind + "`t" + $e.title + "`t" + $e.text]))
}
[void]$sb.AppendLine("}")
[IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("wrote {0}: {1} keys to {2} pages, from {3} fetched ({4} members of groups left out)" -f $Out, $entries.Count, $n, $lore.Count, $dropped)
