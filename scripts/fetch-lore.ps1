<#
scripts/fetch-lore.ps1 (Josh 2026-09-26): the Expedition's lore, from the
Warcraft Wiki.

    powershell -ExecutionPolicy Bypass -File scripts\fetch-lore.ps1

The game has no description of a creature an addon can read, and the
journal fills itself as you kill, so there is no list of enemies to look up.
What there IS a list of is what enemies are named after: races ("Rockjaw
TROGG"), tribes and clans ("FROSTMANE Troll Whelp"), beast families (a cat
is a Cat) and creature types. So this gathers those, all of them, from the
wiki's own categories, and the addon matches an enemy to the most specific one
its name or its family names (Modules/Expedition/Journal.lua, J.WikiLore).

Every enemy already in the journal is looked up by its exact name as well, so
an enemy with a page of its own - Hogger - has it. Run it again after playing and
the enemies met since are looked up too: it reads the saved file.

Writes Modules/Expedition/LoreData.lua. The text is the wiki's, under CC BY-SA
3.0: each entry keeps the title of the page it came from, the addon credits
it where it is shown, and the file says so at its top. What is written is
the vanilla part of it (the filter near the end): -Rebuild writes it again
from the cache, asking the wiki for nothing but new enemies; -Rebuild -Refetch
asks again for pages kept with fewer sentences than are fetched now.
#>
param(
	[string]$Saved = "",
	# build the file again from what was fetched last time, asking the wiki
	# for nothing but the journal's new enemies
	[switch]$Rebuild,
	# with -Rebuild: ask again for the pages fetched with fewer opening
	# sentences than are asked for now (a full run always does)
	[switch]$Refetch
)

$ErrorActionPreference = "Stop"
$Api = "https://warcraft.wiki.gg/api.php"
# MORE TO CUT FROM (Josh 2026-09-27): a page's first six sentences are
# fetched and kept, and the file takes the first three the vanilla filter
# (below) lets through - so a page that loses a sentence to Outland still
# has something to say
$Sentences = 6
$UA = "BeebMod-Expedition-lore/1.0 (WoW addon; josh@tummel.io)"
$Root = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Root "Modules\Expedition\LoreData.lua"

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

# title -> kind, the most specific kind winning: an enemy's own page, then a
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
	# AS UTF-8 (Josh 2026-09-27: a naga's lore came out as a wall of
	# A-tildes). Windows PowerShell reads a file without a byte-order mark in
	# the ANSI code page, so every rebuild read the UTF-8 cache wrong and wrote
	# it back a layer worse: a pronunciation, a dash, an accent grew into it.
	$json = Get-Content -Raw -Encoding UTF8 -LiteralPath $Cache | ConvertFrom-Json
	foreach ($p in $json.PSObject.Properties) {
		# how many sentences it was fetched with: none written means three,
		# from before there was a choice
		$n = if ($p.Value.sentences) { [int]$p.Value.sentences } else { 3 }
		$lore[$p.Name] = @{ title = $p.Value.title; text = $p.Value.text; kind = $p.Value.kind; sentences = $n }
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
	$read = Get-Content -Raw -Encoding UTF8 -LiteralPath $Missing | ConvertFrom-Json
	Add-Nothing $read
}
if ($Rebuild) {
	if ($lore.Count -gt 0) {
	} elseif (Test-Path $Out) {
		foreach ($line in (Get-Content -Encoding UTF8 -LiteralPath $Out)) {
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

# every enemy in the journal, by its exact name
if ($Saved -and (Test-Path $Saved)) {
	Write-Host "reading the journal's enemies from $Saved"
	$text = Get-Content -Raw -Encoding UTF8 -LiteralPath $Saved
	$m = [regex]::Match($text, '\["(expedition|menagerie)"\]\s*=\s*\{')
	if ($m.Success) {
		$names = [regex]::Matches($text.Substring($m.Index), '\["name"\]\s*=\s*"((?:[^"\\]|\\.)*)"')
		foreach ($n in $names) { Want $n.Groups[1].Value "npc" }
	}
}

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
# and a page fetched with fewer sentences than are asked for now, asked
# again - only the ones the file would use: a group's members never are
$short = @()
if (-not $Rebuild -or $Refetch) {
	$short = @($lore.Keys | Where-Object {
		$e = $lore[$_]
		(-not $e.sentences -or $e.sentences -lt $Sentences) -and ($e.kind -ne "group" -or (IsGroupTitle $e.title))
	})
}
if ($short.Count -gt 0) { $titles = @($titles) + @($short) }
Write-Host ("{0} pages to read ({1} of them again, for more sentences)" -f $titles.Count, $short.Count)
for ($i = 0; $i -lt $titles.Count; $i += 20) {
	$batch = $titles[$i..([Math]::Min($i + 19, $titles.Count - 1))]
	$r = Invoke-Wiki @{ action = "query"; prop = "extracts"; exintro = "1"; explaintext = "1"; exsentences = [string]$Sentences;
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
		# asked again, a page keeps the kind it had when nothing wants it now
		$kind = if ($want[$asked]) { $want[$asked] } elseif ($lore.ContainsKey($asked)) { $lore[$asked].kind } else { $null }
		$lore[$asked] = @{ title = $page.title; text = ($page.extract -replace '\s+', ' ').Trim(); kind = $kind; sentences = $Sentences }
		$got[$asked] = $true
	}
	# a page asked again that says nothing this time keeps what it said before
	foreach ($t in $batch) { if (-not $got.ContainsKey($t) -and -not $lore.ContainsKey($t)) { $nothing[$t] = $true } }
	Write-Host ("  {0} of {1}" -f [Math]::Min($i + 20, $titles.Count), $titles.Count)
	# kept as it goes: a run stopped half way keeps what it had
	if (($i / 20) % 25 -eq 24) { Save-Cache }
}
Save-Cache

# the key a page is found by: its title in lower case, without "(pet family)"
# and the like; a tribe or clan also by its name alone ("frostmane"), and a
# people of a race by theirs ("bloodfeather")
# A GROUP'S NAME ONLY (Josh 2026-09-27: "This is definitely not a cursed
# centaur"). "Cursed Centaur" is one creature, and taking its first word as a
# people's name made "cursed" its key: any mob with "cursed" in its name or
# its page was a centaur. Only a tribe, a clan or a people named in the
# plural ("Bloodfeather harpies") is found by its name alone.
$RacePeople = '^(\S+) (harpies|trolls|troggs|gnolls|kobolds|murlocs|ogres|quilboar|centaurs|satyrs|furbolgs|naga|dwarves|goblins|orcs|humans|elves|tauren|draenei|arakkoa|ethereals|nerubians|trogs|wolvar|gorlocs|jinyu|hozen|mogu|saurok|sethrak|vulpera|tortollans)$'
function Keys([string]$Title, [string]$Kind) {
	$k = ($Title -replace '\s*\([^)]*\)\s*$', '').ToLowerInvariant().Trim()
	$out = @($k)
	if ($Kind -eq "group") {
		$bare = $k -replace '\s+(tribe|tribes|clan|clans|pack|brood|gang|cartel|family|order|legion|kingdom|horde)$', ''
		if ($bare -ne $k) { $out += $bare }
		$people = [regex]::Match($k, $RacePeople)
		if ($people.Success) { $out += $people.Groups[1].Value }
	}
	return ,$out
}

# TEXT MADE READABLE AGAIN, AND KEPT THAT WAY. A text the old reads garbled
# is decoded back, a layer at a time, for as long as that makes it cleaner;
# what cannot be brought back (the ANSI page has holes, and a byte that fell
# in one is gone) is dropped rather than shown. A pronunciation - "(/.../)" -
# goes too: the game's fonts have no letters for it. (The characters are
# written as \u escapes: this file has no byte-order mark either.)
$Enc1252 = [Text.Encoding]::GetEncoding(1252)
$Garbled = '(\u00C3.|\u00C2.|\u00E2\u20AC.|\u00C6.|\uFFFD)'
function Clean-Text([string]$s) {
	for ($i = 0; $i -lt 8 -and $s -match $Garbled; $i++) {
		$back = [Text.Encoding]::UTF8.GetString($Enc1252.GetBytes($s))
		if (([regex]::Matches($back, $Garbled)).Count -ge ([regex]::Matches($s, $Garbled)).Count) { break }
		$s = $back
	}
	# whatever is still garbled, and the brackets it leaves empty
	$s = [regex]::Replace($s, '[\u00C3\u00C2\u00E2\u20AC\u00C6\uFFFD][^\s,.;:()]*', '')
	$s = [regex]::Replace($s, '\s*\((?:/[^)]*|[^\w)]*)\)', '')
	$s = [regex]::Replace($s, '\s*\([^)]*/[^)]*/[^)]*\)', '')
	return ($s -replace '\s{2,}', ' ' -replace '\s+([,.;:])', '$1').Trim()
}
foreach ($k in @($lore.Keys)) {
	$lore[$k].text = Clean-Text $lore[$k].text
}
Save-Cache

# VANILLA, NOT SINCE (Josh 2026-09-27: "We are in vanilla WoW, so we
# shouldn't have lore content for outland or any other expansion"). The wiki
# writes about Azeroth as it is now: tallstriders "in Terokkar Forest on
# Outland", Cookie's extra boss "in Heroic mode". The places, peoples and
# things of the game that came after vanilla are listed here, and a sentence
# that reaches one is cut at the comma or "and" before it - "found in the
# Swamp of Sorrows, on Darkmoon Island, and in Terokkar Forest" keeps the
# Swamp - or, with nothing before it worth keeping, dropped. A page whose
# first sentence goes is about something vanilla never had, and goes with it.
# The cache keeps the wiki's words whole; this is done to what is written out,
# so a word added here takes effect on the next -Rebuild.
#
# Only words vanilla does not use for something of its own: the Burning
# Legion, the black dragonflight, Dalaran, Draenor (the orcs' home), the
# Emerald Dream, the earthen of Uldaman and the Zandalar tribe all stay.
$LaterWords = @(
	# the expansions, by name
	"Burning Crusade", "Wrath of the Lich King", "Cataclysm", "Mists of Pandaria", "Warlords of Draenor",
	"Battle for Azeroth", "Shadowlands", "War Within", "Legion invasion", "Legion expansion",
	"(?<!(?i:black|red|blue|green|bronze|infinite|twilight|chromatic|nether|netherwing) )Dragonflight",
	# Outland, and the Draenor of the past
	"Outland", "alternate Draenor", "alternate universe", "Terokkar", "Nagrand", "Shattrath", "Netherstorm",
	"Hellfire (?:Peninsula|Citadel|Ramparts)", "Zangarmarsh", "Blade's Edge", "Shadowmoon Valley", "Tanaan",
	"Frostfire Ridge", "Gorgrond", "Spires of Arak", "Talador", "Ashran",
	# the lands added to the old continents
	"Quel'Danas", "Eversong", "Ghostlands", "Silvermoon", "Azuremyst", "Bloodmyst", "Exodar", "Gilneas City",
	"invasion of Gilneas", "Kezan", "Lost Isles", "Vashj'ir", "Kelp'thar", "Abyssal Depths", "Shimmering Expanse",
	"Deepholm", "Uldum", "Twilight Highlands", "Tol Barad", "Firelands", "Molten Front", "Darkmoon Island",
	"Wandering Isle", "Broken Isles", "Broken Shore",
	# Northrend
	"Northrend", "Icecrown", "Dragonblight", "Howling Fjord", "Borean Tundra", "Grizzly Hills", "Sholazar",
	"Storm Peaks", "Zul'Drak", "Wintergrasp", "Crystalsong", "Violet Citadel", "Underbelly",
	# Pandaria and everything after it
	"Pandaria", "Jade Forest", "Kun-Lai", "Townlong", "Vale of Eternal Blossoms", "Krasarang",
	"Valley of the Four Winds", "Dread Wastes", "Timeless Isle", "Isle of Thunder", "Suramar", "Stormheim",
	"Highmountain", "Val'sharah", "Azsuna", "Argus", "Zandalar(?! [Tt]ribe)", "Zuldazar", "Nazmir", "Vol'dun",
	"Kul Tiras", "Kul Tiran", "Tiragarde", "Drustvar", "Stormsong", "Nazjatar", "Mechagon", "Ardenweald",
	"Revendreth", "Maldraxxus", "Kyrian", "Oribos", "the Maw", "Zereth Mortis", "Korthia", "Dragon Isles",
	"Ohn'ahran", "Waking Shores", "Azure Span", "Thaldraszus", "Zaralek", "Khaz Algar", "Isle of Dorn",
	"Ringing Deeps", "Hallowfall", "Azj-Kahet", "Undermine", "Siren Isle", "K'aresh",
	# peoples, and people, who came later
	"draenei", "Draenei", "blood elf", "blood elves", "Blood elf", "Blood elves", "Sin'dorei", "Illidari",
	"Allied race", "void elf", "void elves", "Void elf", "Void elves", "Nightborne", "Lightforged", "Mag'har",
	"Vulpera", "vulpera", "Mechagnome", "mechagnomes?", "vrykul", "Vrykul", "Curse of Flesh", "Dracthyr", "Garrosh", "Fourth War", "War of Thorns",
	"Maruuk", "Exile's Reach", "(?i:haranir)", "Bastion", "Sunstrider Isle", "Strand of the Ancients",
	"Isle of Conquest", "Eye of the Storm", "Twin Peaks", "Battle for Gilneas", "Silvershard", "Temple of Kotmogu",
	"Deepwind", "Seething Shore", "Bilgewater", "Kor'kron",
	# Draenor the orcs' home stays; Draenor the place to find a beast, beside
	# Azeroth, is Outland's
	"(?<=\b(?:Azeroth|Kalimdor|Kingdoms|Outland)(?:,| and| or| as well as) )Draenor"
)
# THE GAME SINCE: not a place a sentence can be cut short of - "captured by
# engaging it in a pet battle" cut is "captured by engaging it" - so a
# sentence that reaches one of these goes whole
$ThingWords = @(
	"Heroic", "(?i:heroic (?:mode|difficulty|dungeon))", "Mythic", "Timewalking", "(?i:pet battles?|battle pets?)",
	"(?i:garrisons?)", "Order Hall", "(?i:world quests?)", "Warfront", "Island Expedition", "Torghast",
	"Warcraft Rumble", "Hearthstone", "Heroes of the Storm", "(?i:arena (?:battlemaster|organizer|team|vendor|master))",
	"\[\d+-\d+\]", "\[(?:6[1-9]|[7-9]\d|1\d\d)[A-Z]*\]","(?i:patch (?:[2-9]|1\d)\.\d)", "Plunderstorm", "Remix", "Dungeon Journal", "Adventure Guide",
	"Raid Finder", "Trading Post", "(?i:scenario)", "Warcraft: Legion",
	# THE SEASONS ARE NOT VANILLA (Josh 2026-09-27: Ragnaros was "the final
	# boss in the Season of Discovery Molten Core raid")
	"Season of Discovery", "(?i:Season of Mastery)", "(?i:Hardcore realms?)",
	# THE EVENTS SINCE (Josh 2026-09-28: a Sickly Deer lived "in Olsen's
	# Farthing during the Heritage of Lordaeron"): each is named for itself,
	# so a sentence that names one is about the game since
	"Heritage of (?:the )?[A-Z][a-z']+", "Lion's Heritage", "War of the Thorns", "Battle for (?:Darkshore|Stromgarde|the Undercity|Andorhal)",
	"Nightmare Incursions?", "Radiant Echoes", "Un'Goro Madness", "(?i:micro-holiday)", "Elemental Unrest", "Legion Invasions?",
	"Operation: Gnomeregan", "Brewfest", "Classic Hardcore", "Undermarket", "Anniversary event", "Call to Arms",
	"Blackrock Eruption", "Tarren Mill vs\.? Southshore", "Old Hillsbrad", "Stormwind Harbor",
	# and quests of the old world written since, named often enough to list
	"In Darkest Night", "Tracking Tipoff", "Dark Ranger Round-Up", "Death Rising",
	"Dark Portal Opens", "Zombie Infestation", "Silithus: The Wound", "Valaar.s Berth",
	# an item, not a creature, in several versions that each take the key
	# when the last one is left out
	"Signet Ring of the Bronze Dragonflight"
)
# a page written for one of them, by the qualifier on its title. A LATER
# VERSION BY ITS NAME TOO (Josh 2026-09-28, the lore review): when the
# review left out "Shattered Hand clan (alternate universe)", its "(film
# universe)" page took the key next; a qualifier that names a later game,
# universe or event marks the whole page as later
$SeasonTitle = '\((?:[^()]*\b(?:Season of Discovery|Season of Mastery|Plunderstorm|Hardcore|Remix|SoD|alternate universe|film universe|BC Classic|Wrath Classic|Cataclysm Classic|Mists Classic|Anniversary|Battle for Azeroth|Legion|Death Rising|War of the Thorns|Zalazane''s Fall|Dark Portal Opens|Darkspear Rebellion|Battle for Stromgarde)\b[^()]*)\)'
# each word a whole word, where it starts or ends with a letter
function WordsRegex($words) {
	return [regex]::new((($words | ForEach-Object {
		$w = $_
		if ($w -match '^[A-Za-z]') { $w = '\b' + $w }
		if ($w -match '[A-Za-z]$') { $w = $w + '\b' }
		$w
	}) -join '|'))
}
$Later = WordsRegex (@($LaterWords) + @($ThingWords))
$Thing = WordsRegex $ThingWords

# where a sentence ends: not after "St." or "Mr."
$SentenceEnd = [regex]::new('(?<=[.!?]["''\u201D)]?)(?<!\b(?:St|Mr|Mrs|Ms|Dr|Lt|Sgt|Jr|Sr|vs|Mt|Capt|Gen|Col|Cpl|Pvt|No|Ft|Co|Inc|Ltd|Bros)\.)\s+(?=["''(\[\u201C]?[A-Z0-9])')
# where a sentence can be cut: a comma, a semicolon, a joining word
$ClauseBreak = [regex]::new('(?:,|;|\s(?:and|or|but|though|although|while|whereas|including|as well as|such as))\s')
# a later place's own word, "in", "on" or "at" - not "of": "the continent
# of Northrend" is not a place with the name taken off
$Near = [regex]::new('\s+(?:in|on|at)(?:\s+(?:the|a|an))?$')
# a place's verb, left without its place
$Where = [regex]::new('\s+(?:(?:that|which|who) (?:are |is )?)?(?:found|located|seen|situated|living|residing|dwelling|native|that live|who live|which live|available|available only|only)$')
# a sentence that starts on a clause of another
$Subordinate = [regex]::new('^(?:After|When|While|Although|Though|Because|Since|Before|Following|During|Like|Unlike|As|If|Once|Upon|Until|Whereas|With)\b')
# what a cut leaves hanging at its end
$Dangling = [regex]::new('(?:\s*[,;:\-]|\s+(?:and|or|but|though|although|while|whereas|including|as well as|such as|in|on|at|of|from|to|with|by|the|a|an|as|also|both|either|mainly|mostly|primarily|especially))+$')

# the zones Cataclysm split, by their vanilla names
function Vanilla-Places([string]$s) {
	$s = [regex]::Replace($s, '\b([Tt]he )?(?:Northern|Southern) Barrens\b', { param($m) $(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { "the " }) + "Barrens" })
	$s = [regex]::Replace($s, '\b(?:[Tt]he )?(?:Northern Stranglethorn|Cape of Stranglethorn)\b', 'Stranglethorn Vale')
	# THE WIKI'S OWN HABITS (Josh 2026-09-28, the lore review): "found here
	# prior to the Shattering" is vanilla described from later, so the phrase
	# goes and the fact stays; "a rare mob murloc" is the game's "a rare murloc"
	$s = [regex]::Replace($s, ',?\s+(?:prior to|before) the Shattering\b', '')
	$s = [regex]::Replace($s, '\brare mob (?=[a-z])(?!(?:found|located|that|which|who|in|on|at|of|and|with|spawns?|spawning)\b)', 'rare ')
	return $s
}

# a quest's level, as the wiki tags it: "[14] The Principal Source" is
# "The Principal Source" in the game (a quest past level 60 is later, and is
# cut before this: $ThingWords)
function No-QuestLevels([string]$s) {
	return [regex]::Replace($s, '\[\d+[A-Z]*\]\s+', '')
}

# one sentence as vanilla would have it, or nothing
function Vanilla-Sentence([string]$s) {
	# an aside about later things goes whole: "(also found in Northrend)"
	$s = [regex]::Replace($s, '\s*\([^()]*\)', { param($m) $(if ($Later.IsMatch($m.Value)) { "" } else { $m.Value }) })
	$m = $Later.Match($s)
	if (-not $m.Success) { return $s }
	if ($Thing.Match($s).Index -eq $m.Index -and $Thing.IsMatch($s)) { return $null }
	# the breaks are looked for before the trim: "Azeroth and " ends on one
	$whole = $s.Substring(0, $m.Index)
	$head = $whole.TrimEnd()
	# "Azjol-Nerub in Northrend": the later place is only where it is, and
	# goes with the word that leads to it. Otherwise the cut is at the last
	# comma or "and" before it - "appears to be from Helheim and have also
	# leaked into Stormheim" is not cut at "into"
	if ($Near.IsMatch($head)) {
		$kept = $Near.Replace($head, "")
	} else {
		$breaks = $ClauseBreak.Matches($whole)
		if ($breaks.Count -eq 0) { return $null }
		$kept = $whole.Substring(0, $breaks[$breaks.Count - 1].Index)
	}
	for ($i = 0; $i -lt 4; $i++) { $kept = $Dangling.Replace($kept.TrimEnd(), "") }
	# "creatures found in Bastion" is "creatures", not "creatures found"
	$kept = $Where.Replace($kept, "").Trim()
	# a clause cut from the sentence it hung on says nothing: "After meeting
	# his demise at the hands of adventurers"
	if ($Subordinate.IsMatch($kept) -and $kept -notmatch ',') { return $null }
	# what is left of a list is joined again: "the Eastern Kingdoms, Kalimdor"
	# is "the Eastern Kingdoms and Kalimdor" - only a list, cut at one of its
	# commas or its "and" ("mushan beasts, are reptilian beasts" is not one)
	if ($head -match '(?:,|\s(?:and|or|as well as))(?:\s+(?:in|on|at))?(?:\s+(?:the|a|an))?$') {
		$kept = [regex]::Replace($kept, ', ((?:[^,\s]+ ){0,3}[^,\s]+)$', ' and $1')
	}
	# "both in Azeroth" is "in Azeroth"
	$kept = [regex]::Replace($kept, '\bboth ((?:(?:in|on|to) )?[^,]*)$', { param($x) $(if ($x.Groups[1].Value -match '\band\b') { $x.Value } else { $x.Groups[1].Value }) })
	# long enough to say something, and no bracket or quote left open
	if ($kept.Length -lt 40) { return $null }
	if (([regex]::Matches($kept, '\(')).Count -ne ([regex]::Matches($kept, '\)')).Count) { return $null }
	if ((([regex]::Matches($kept, '"')).Count % 2) -ne 0) { return $null }
	return $kept + "."
}

# the note a page opens with about other pages: "This page is about trolls
# in general. For the playable races, see..."
# MORE OF THE WIKI TALKING ABOUT ITSELF (Josh 2026-09-28, on the Snake page:
# "The redirect sentence here is weird"): '"Cobra" and "viper" redirect
# here', "This section concerns content related to Legion", "This article
# concerns the original ... encounter", "This page is a list of ..."
$Hatnote = [regex]::new('^(?:This (?:page|article) is (?:about|a list)|This (?:page|article|section) concerns|For [^.]*\bsee\b|For other uses|Not to be confused|See also|"[^"]+"(?:,? (?:and|or) "[^"]+")* redirects? here)')

# a page's text as vanilla would have it: its first three sentences that
# survive, or nothing when its first does not
function Vanilla-Text([string]$s) {
	$out = @()
	$first = $true
	foreach ($sentence in $SentenceEnd.Split((Vanilla-Places $s))) {
		$sentence = $sentence.Trim()
		if (-not $sentence -or $Hatnote.IsMatch($sentence)) { continue }
		$v = Vanilla-Sentence $sentence
		if ($first -and -not $v) { return "" }
		$first = $false
		if ($v) { $out += $v }
		if ($out.Count -ge 3) { break }
	}
	return (($out -join " ") -replace '\s{2,}', ' ' -replace '\s+([,.;:])', '$1').Trim()
}

# THE PAGES READ BY HAND (Josh 2026-09-28, the lore rewrite): every page was
# read against docs/lore-rules.md, and scripts/lore-curated.json says, by page
# title, what became of it. "drop" leaves the page out, "rewrite" puts the
# plain text written for it in place of the wiki's, "keep" lets the filter's
# text stand. It is applied after the filter, so a later fetch never
# overwrites what was written by hand.
$CuratedFile = Join-Path $PSScriptRoot "lore-curated.json"
$curated = @{}
if (Test-Path $CuratedFile) {
	$c = Get-Content $CuratedFile -Raw -Encoding UTF8 | ConvertFrom-Json
	foreach ($p in $c.PSObject.Properties) { $curated[$p.Name] = $p.Value }
}
# PAGES WRITTEN WHOLE (Josh 2026-09-28: a card is its own page, then what its
# model is, and a satyr's model had no Satyr page to point at). A page the
# cache never held, or held as something it is not ("Satyr" is filed with the
# organizations, and a group that is not a tribe is dropped below), is
# written in scripts/lore-curated.json with a "kind", and comes in here as if
# it had been fetched.
foreach ($t in @($curated.Keys)) {
	$h = $curated[$t]
	if ($h.kind -and $h.status -eq "rewrite" -and $h.text) {
		if ($lore.ContainsKey($t)) {
			$lore[$t].kind = $h.kind
		} else {
			$lore[$t] = @{ title = $t; kind = $h.kind; text = $h.text; sentences = 3 }
		}
	}
}
$handDropped = 0
$handWritten = 0

# every page as it is written out: the vanilla part of it, and the pages with
# nothing vanilla to say left out
$shown = @{}
$wentLater = 0
$dropped = 0
foreach ($asked in $lore.Keys) {
	$e = $lore[$asked]
	if ($e.kind -eq "group" -and -not (IsGroupTitle $e.title)) {
		$dropped++
		continue
	}
	# A SEASON'S OWN PAGE (Josh 2026-09-27): "Ragnaros (Season of Discovery)"
	# is that season's Ragnaros, whatever its words say, and it filled the key
	# the Molten Core's own page should have
	if ($asked -match $SeasonTitle -or $e.title -match $SeasonTitle) {
		$wentLater++
		continue
	}
	$text = Vanilla-Text $e.text
	$hand = $curated[$e.title]
	if ($hand -and $hand.status -eq "drop") {
		$handDropped++
		continue
	}
	if ($hand -and $hand.status -eq "rewrite" -and $hand.text) {
		$text = $hand.text
		$handWritten++
	}
	$text = No-QuestLevels $text
	if ($text) {
		$shown[$asked] = @{ title = $e.title; kind = $e.kind; text = $text }
	} else {
		$wentLater++
	}
}

function LuaString([string]$s) {
	return '"' + ($s -replace '\\', '\\' -replace '"', '\"' -replace "`r", '' -replace "`n", '\n') + '"'
}

$entries = @{}
# THE SAME PAGE EVERY TIME (Josh 2026-09-28: "Add the fix"): a hashtable
# hands its keys back in no set order, and when two pages tie for a key -
# "Azuregos (Anniversary)" and "Azuregos (tactics)" - the one seen first
# took it, so a rebuild could swap them and lose a page written by hand in
# scripts/lore-curated.json. Both loops go in sorted order.
$askedInOrder = @($shown.Keys | Sort-Object)
foreach ($asked in $askedInOrder) {
	$e = $shown[$asked]
	# A TITLE WITH A QUALIFIER IS A SECOND CHOICE (Josh 2026-09-27): "Beast
	# (Rumble)" is Warcraft Rumble's beast, and read as "beast" it outranked
	# the creature type's own page. Written "Name (something)", a page only
	# fills a key nothing else has (below).
	if ($asked -match '\(') { continue }
	foreach ($k in (Keys $asked $e.kind)) {
		if (-not $entries.ContainsKey($k) -or $Rank[$e.kind] -gt $Rank[$entries[$k].kind]) {
			$entries[$k] = $e
		}
	}
}
# and by the page the wiki led to, or a title with a qualifier, where nothing
# has that name already: "threshadons" was asked, "Threshadon" is the page,
# and a mob's page says "threshadon" as often as "threshadons"
foreach ($asked in $askedInOrder) {
	$e = $shown[$asked]
	# two loops, not one list: joining two of these with + nests them (the
	# memory note on pipeline flattening), and a list became a key
	foreach ($k in (Keys $asked $e.kind)) {
		if (-not $entries.ContainsKey($k)) { $entries[$k] = $e }
	}
	foreach ($k in (Keys $e.title $e.kind)) {
		if (-not $entries.ContainsKey($k)) { $entries[$k] = $e }
	}
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- The Expedition's lore: the opening lines of the Warcraft Wiki's pages on")
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
[void]$sb.AppendLine("BT.ExpeditionLoreData = {")
foreach ($k in ($entries.Keys | Sort-Object)) {
	$e = $entries[$k]
	[void]$sb.AppendLine(("	[{0}] = P[{1}]," -f (LuaString $k), $index[$e.kind + "`t" + $e.title + "`t" + $e.text]))
}
[void]$sb.AppendLine("}")
[IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("wrote {0}: {1} keys to {2} pages, from {3} fetched ({4} members of groups left out, {5} pages with nothing vanilla to say)" -f $Out, $entries.Count, $n, $lore.Count, $dropped, $wentLater)
Write-Host ("by hand (lore-curated.json): {0} rewritten, {1} dropped (counted once for each title the wiki was asked)" -f $handWritten, $handDropped)
