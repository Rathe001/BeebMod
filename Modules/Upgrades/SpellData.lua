-- Made by scripts/make-upgrade-spells.py on 2026-11-18 from the game's tables
-- (wago.tools, product wowf). Do not edit by hand: run the script again.
local _, BT = ...
BT.Upgrades = BT.Upgrades or {}
BT.Upgrades.SpellData = {
	-- spell id -> what it is to the model, its share of spell power, and what
	-- each number in its description is, in the order it says them
	spells = {
		PALADIN = {
			[20116] = { is = "consecration", lvl = 30, read = "first - cap second -" }, -- Consecration
			[20922] = { is = "consecration", lvl = 40, read = "first - cap second -" }, -- Consecration
			[20923] = { is = "consecration", lvl = 50, read = "first - cap second -" }, -- Consecration
			[20924] = { is = "consecration", lvl = 60, read = "first - cap second -" }, -- Consecration
			[26573] = { is = "consecration", lvl = 20, read = "first - cap second -" }, -- Consecration
			[19750] = { is = "heal:flashOfLight", lvl = 20, share = 0.429, base = 46, per = 1, from = 20, to = 25, read = "amount amount" }, -- Flash of Light
			[19939] = { is = "heal:flashOfLight", lvl = 26, share = 0.429, base = 66, per = 1.3, from = 26, to = 31, read = "amount amount" }, -- Flash of Light
			[19940] = { is = "heal:flashOfLight", lvl = 34, share = 0.429, base = 101, per = 1.6, from = 34, to = 39, read = "amount amount" }, -- Flash of Light
			[19941] = { is = "heal:flashOfLight", lvl = 42, share = 0.429, base = 151, per = 1.9, from = 42, to = 47, read = "amount amount" }, -- Flash of Light
			[19942] = { is = "heal:flashOfLight", lvl = 50, share = 0.429, base = 223, per = 2.2, from = 50, to = 55, read = "amount amount" }, -- Flash of Light
			[19943] = { is = "heal:flashOfLight", lvl = 58, share = 0.429, base = 303, per = 2.6, from = 58, to = 63, read = "amount amount" }, -- Flash of Light
			[19993] = { is = "heal:flashOfLight", lvl = 20, share = 0.429, base = 1, per = 0, from = 20, to = 25, read = "amount" }, -- Flash of Light
			[1313342] = { is = "heal:flashOfLight", lvl = 26, share = 0.429, base = 1, per = 0, from = 26, to = 31, read = "amount" }, -- Flash of Light
			[1313343] = { is = "heal:flashOfLight", lvl = 34, share = 0.429, base = 1, per = 0, from = 34, to = 39, read = "amount" }, -- Flash of Light
			[1313344] = { is = "heal:flashOfLight", lvl = 42, share = 0.429, base = 1, per = 0, from = 42, to = 47, read = "amount" }, -- Flash of Light
			[1313345] = { is = "heal:flashOfLight", lvl = 50, share = 0.429, base = 1, per = 0, from = 50, to = 55, read = "amount" }, -- Flash of Light
			[1313346] = { is = "heal:flashOfLight", lvl = 58, share = 0.429, base = 1, per = 0, from = 58, to = 63, read = "amount" }, -- Flash of Light
			[635] = { is = "heal:holyLight", lvl = 1, share = 0.714, base = 43, per = 0.8, from = 1, to = 5, read = "amount amount" }, -- Holy Light
			[639] = { is = "heal:holyLight", lvl = 6, share = 0.714, base = 83, per = 1.1, from = 6, to = 11, read = "amount amount" }, -- Holy Light
			[647] = { is = "heal:holyLight", lvl = 14, share = 0.714, base = 155, per = 1.7, from = 14, to = 19, read = "amount amount" }, -- Holy Light
			[1026] = { is = "heal:holyLight", lvl = 22, share = 0.714, base = 287, per = 2.4, from = 22, to = 27, read = "amount amount" }, -- Holy Light
			[1042] = { is = "heal:holyLight", lvl = 30, share = 0.714, base = 452, per = 3.1, from = 30, to = 35, read = "amount amount" }, -- Holy Light
			[3472] = { is = "heal:holyLight", lvl = 38, share = 0.714, base = 646, per = 3.8, from = 38, to = 43, read = "amount amount" }, -- Holy Light
			[10328] = { is = "heal:holyLight", lvl = 46, share = 0.714, base = 899, per = 4.6, from = 46, to = 51, read = "amount amount" }, -- Holy Light
			[10329] = { is = "heal:holyLight", lvl = 54, share = 0.714, base = 1217, per = 5.2, from = 54, to = 59, read = "amount amount" }, -- Holy Light
			[19968] = { is = "heal:holyLight", lvl = 22, share = 0.714, base = 1, per = 0, from = 22, to = 27, read = "amount" }, -- Holy Light
			[19980] = { is = "heal:holyLight", lvl = 14, share = 0.714, base = 1, per = 0, from = 14, to = 19, read = "amount" }, -- Holy Light
			[19981] = { is = "heal:holyLight", lvl = 6, share = 0.714, base = 1, per = 0, from = 6, to = 13, read = "amount" }, -- Holy Light
			[19982] = { is = "heal:holyLight", lvl = 1, share = 0.714, base = 1, per = 0, from = 1, to = 5, read = "amount" }, -- Holy Light
			[25292] = { is = "heal:holyLight", lvl = 60, share = 0.714, base = 1580, per = 5.8, from = 60, to = 65, read = "amount amount" }, -- Holy Light
			[1313348] = { is = "heal:holyLight", lvl = 30, share = 0.714, base = 1, per = 0, from = 30, to = 35, read = "amount" }, -- Holy Light
			[1313349] = { is = "heal:holyLight", lvl = 38, share = 0.714, base = 1, per = 0, from = 38, to = 43, read = "amount" }, -- Holy Light
			[1313350] = { is = "heal:holyLight", lvl = 46, share = 0.714, base = 1, per = 0, from = 46, to = 51, read = "amount" }, -- Holy Light
			[1313351] = { is = "heal:holyLight", lvl = 54, share = 0.714, base = 1, per = 0, from = 54, to = 59, read = "amount" }, -- Holy Light
			[1313352] = { is = "heal:holyLight", lvl = 50, share = 0.714, base = 1, per = 0, from = 60, to = 65, read = "amount" }, -- Holy Light
			[678] = { is = "holyStrike", lvl = 12, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[679] = { is = "holyStrike", lvl = 6, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[680] = { is = "holyStrike", lvl = 28, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[1866] = { is = "holyStrike", lvl = 20, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[2495] = { is = "holyStrike", lvl = 36, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[5569] = { is = "holyStrike", lvl = 44, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[10332] = { is = "holyStrike", lvl = 52, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[10333] = { is = "holyStrike", lvl = 60, share = 0.429, read = "percent holy holy" }, -- Holy Strike
			[20271] = { is = "judgement", lvl = 4, read = "" }, -- Judgement
			[25780] = { is = "righteousFury", lvl = 10, share = 1.0, read = "all holy -" }, -- Righteous Fury
			[20375] = { is = "command", lvl = 20, read = "percent - judge judge - -" }, -- Seal of Command
			[20915] = { is = "command", lvl = 30, read = "percent - judge judge - -" }, -- Seal of Command
			[20918] = { is = "command", lvl = 40, read = "percent - judge judge - -" }, -- Seal of Command
			[20919] = { is = "command", lvl = 50, read = "percent - judge judge - -" }, -- Seal of Command
			[20920] = { is = "command", lvl = 60, read = "percent - judge judge - -" }, -- Seal of Command
			[20163] = { is = "fury", lvl = 26, share = 0.09, read = "- hit - judge judge -" }, -- Seal of Fury
			[20419] = { is = "fury", lvl = 34, share = 0.9, read = "- hit - judge judge -" }, -- Seal of Fury
			[20421] = { is = "fury", lvl = 42, share = 0.09, read = "- hit - judge judge -" }, -- Seal of Fury
			[20422] = { is = "fury", lvl = 50, share = 0.09, read = "- hit - judge judge -" }, -- Seal of Fury
			[20423] = { is = "fury", lvl = 58, read = "- hit - judge judge -" }, -- Seal of Fury
			[1311649] = { is = "fury", lvl = 10, share = 0.09, read = "- hit - judge judge -" }, -- Seal of Fury
			[1311656] = { is = "fury", lvl = 18, share = 0.09, read = "- hit - judge judge -" }, -- Seal of Fury
			[20154] = { is = "righteousness", lvl = 1, share = 0.1, read = "- low high" }, -- Seal of Righteousness
			[20287] = { is = "righteousness", lvl = 10, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20288] = { is = "righteousness", lvl = 18, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20289] = { is = "righteousness", lvl = 26, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20290] = { is = "righteousness", lvl = 34, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20291] = { is = "righteousness", lvl = 42, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20292] = { is = "righteousness", lvl = 50, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20293] = { is = "righteousness", lvl = 58, read = "- low high judge judge" }, -- Seal of Righteousness
			[21084] = { is = "righteousness", lvl = 1, share = 0.1, read = "- low high judge judge" }, -- Seal of Righteousness
			[20162] = { is = "crusader", lvl = 12, read = "- ap - - holy" }, -- Seal of the Crusader
			[20305] = { is = "crusader", lvl = 22, read = "- ap - - holy" }, -- Seal of the Crusader
			[20306] = { is = "crusader", lvl = 32, read = "- ap - - holy" }, -- Seal of the Crusader
			[20307] = { is = "crusader", lvl = 42, read = "- ap - - holy" }, -- Seal of the Crusader
			[20308] = { is = "crusader", lvl = 52, read = "- ap - - holy" }, -- Seal of the Crusader
			[21082] = { is = "crusader", lvl = 6, read = "- ap - - holy" }, -- Seal of the Crusader
		},
		WARRIOR = {
			[2687] = { is = "rage", lvl = 10, key = "bloodrage", cd = 60, every = 60, read = "rage more -" }, -- Bloodrage
			[23881] = { is = "ability", lvl = 40, key = "bloodthirst", cost = 30, cd = 6, read = "appct add - -" }, -- Bloodthirst
			[23892] = { is = "ability", lvl = 48, key = "bloodthirst", cost = 30, cd = 6, read = "appct add - -" }, -- Bloodthirst
			[23893] = { is = "ability", lvl = 54, key = "bloodthirst", cost = 30, cd = 6, read = "appct add - -" }, -- Bloodthirst
			[23894] = { is = "ability", lvl = 60, key = "bloodthirst", cost = 30, cd = 6, read = "appct add - -" }, -- Bloodthirst
			[100] = { is = "rage", lvl = 4, key = "charge", cd = 15, read = "rage -" }, -- Charge
			[6178] = { is = "rage", lvl = 26, key = "charge", cd = 15, read = "rage -" }, -- Charge
			[11578] = { is = "rage", lvl = 46, key = "charge", cd = 15, read = "rage -" }, -- Charge
			[845] = { is = "ability", lvl = 20, key = "cleave", cost = 20, threat = 10, tmult = 1, also = 1, swing = true, read = "add" }, -- Cleave
			[7369] = { is = "ability", lvl = 30, key = "cleave", cost = 20, threat = 40, tmult = 1, also = 1, swing = true, read = "add" }, -- Cleave
			[11608] = { is = "ability", lvl = 40, key = "cleave", cost = 20, threat = 60, tmult = 1, also = 1, swing = true, read = "add" }, -- Cleave
			[11609] = { is = "ability", lvl = 50, key = "cleave", cost = 20, threat = 70, tmult = 1, also = 1, swing = true, read = "add" }, -- Cleave
			[20569] = { is = "ability", lvl = 60, key = "cleave", cost = 20, threat = 100, tmult = 1, also = 1, swing = true, read = "add" }, -- Cleave
			[5308] = { is = "ability", lvl = 24, key = "execute", cost = 15, part = 0.2, read = "hit - -" }, -- Execute
			[20658] = { is = "ability", lvl = 32, key = "execute", cost = 15, part = 0.2, read = "hit - -" }, -- Execute
			[20660] = { is = "ability", lvl = 40, key = "execute", cost = 15, part = 0.2, read = "hit - -" }, -- Execute
			[20661] = { is = "ability", lvl = 48, key = "execute", cost = 15, part = 0.2, read = "hit - -" }, -- Execute
			[20662] = { is = "ability", lvl = 56, key = "execute", cost = 15, part = 0.2, read = "hit - -" }, -- Execute
			[78] = { is = "ability", lvl = 1, key = "heroicstrike", cost = 15, threat = 20, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[284] = { is = "ability", lvl = 8, key = "heroicstrike", cost = 15, threat = 39, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[285] = { is = "ability", lvl = 16, key = "heroicstrike", cost = 15, threat = 59, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[1608] = { is = "ability", lvl = 24, key = "heroicstrike", cost = 15, threat = 78, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[11564] = { is = "ability", lvl = 32, key = "heroicstrike", cost = 15, threat = 98, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[11565] = { is = "ability", lvl = 40, key = "heroicstrike", cost = 15, threat = 118, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[11566] = { is = "ability", lvl = 48, key = "heroicstrike", cost = 15, threat = 137, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[11567] = { is = "ability", lvl = 56, key = "heroicstrike", cost = 15, threat = 145, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[25286] = { is = "ability", lvl = 60, key = "heroicstrike", cost = 15, threat = 175, tmult = 1, swing = true, read = "add" }, -- Heroic Strike
			[12294] = { is = "ability", lvl = 40, key = "mortalstrike", cost = 30, cd = 6, weapon = "norm", read = "add - -" }, -- Mortal Strike
			[21551] = { is = "ability", lvl = 48, key = "mortalstrike", cost = 30, cd = 6, weapon = "norm", read = "add - -" }, -- Mortal Strike
			[21552] = { is = "ability", lvl = 54, key = "mortalstrike", cost = 30, cd = 6, weapon = "norm", read = "add - -" }, -- Mortal Strike
			[21553] = { is = "ability", lvl = 60, key = "mortalstrike", cost = 30, cd = 6, weapon = "norm", read = "add - -" }, -- Mortal Strike
			[7384] = { is = "ability", lvl = 12, key = "overpower", cost = 5, cd = 5, threat = 0, tmult = 0.75, after = "dodge", weapon = "norm", read = "add" }, -- Overpower
			[7887] = { is = "ability", lvl = 28, key = "overpower", cost = 5, cd = 5, after = "dodge", weapon = "norm", read = "add" }, -- Overpower
			[11584] = { is = "ability", lvl = 44, key = "overpower", cost = 5, cd = 5, after = "dodge", weapon = "norm", read = "add" }, -- Overpower
			[11585] = { is = "ability", lvl = 60, key = "overpower", cost = 5, cd = 5, after = "dodge", weapon = "norm", read = "add" }, -- Overpower
			[772] = { is = "ability", lvl = 4, key = "rend", cost = 10, secs = 9, dot = true, read = "dot -" }, -- Rend
			[6546] = { is = "ability", lvl = 10, key = "rend", cost = 10, secs = 12, dot = true, read = "dot -" }, -- Rend
			[6547] = { is = "ability", lvl = 20, key = "rend", cost = 10, secs = 15, dot = true, read = "dot -" }, -- Rend
			[6548] = { is = "ability", lvl = 30, key = "rend", cost = 10, secs = 18, dot = true, read = "dot -" }, -- Rend
			[11572] = { is = "ability", lvl = 40, key = "rend", cost = 10, secs = 21, dot = true, read = "dot -" }, -- Rend
			[11573] = { is = "ability", lvl = 50, key = "rend", cost = 10, secs = 21, dot = true, read = "dot -" }, -- Rend
			[11574] = { is = "ability", lvl = 60, key = "rend", cost = 10, secs = 21, dot = true, read = "dot -" }, -- Rend
			[6572] = { is = "ability", lvl = 14, key = "revenge", cost = 5, cd = 5, threat = 63, tmult = 2.25, after = "avoid", tank = true, read = "hit hit" }, -- Revenge
			[6574] = { is = "ability", lvl = 24, key = "revenge", cost = 5, cd = 5, threat = 108, tmult = 2.25, after = "avoid", tank = true, read = "hit hit" }, -- Revenge
			[7379] = { is = "ability", lvl = 34, key = "revenge", cost = 5, cd = 5, threat = 153, tmult = 2.25, after = "avoid", tank = true, read = "hit hit" }, -- Revenge
			[11600] = { is = "ability", lvl = 44, key = "revenge", cost = 5, cd = 5, threat = 198, tmult = 2.25, after = "avoid", tank = true, read = "hit hit" }, -- Revenge
			[11601] = { is = "ability", lvl = 54, key = "revenge", cost = 5, cd = 5, threat = 243, tmult = 2.25, after = "avoid", tank = true, read = "hit hit" }, -- Revenge
			[25288] = { is = "ability", lvl = 60, key = "revenge", cost = 5, cd = 5, threat = 270, tmult = 2.25, after = "avoid", tank = true, read = "hit hit" }, -- Revenge
			[23922] = { is = "ability", lvl = 40, key = "shieldslam", cost = 20, cd = 6, threat = 178, tmult = 1, blockvalue = true, shield = true, tank = true, read = "hit hit - -" }, -- Shield Slam
			[23923] = { is = "ability", lvl = 48, key = "shieldslam", cost = 20, cd = 6, threat = 203, tmult = 1, blockvalue = true, shield = true, tank = true, read = "hit hit - -" }, -- Shield Slam
			[23924] = { is = "ability", lvl = 54, key = "shieldslam", cost = 20, cd = 6, threat = 229, tmult = 1, blockvalue = true, shield = true, tank = true, read = "hit hit - -" }, -- Shield Slam
			[23925] = { is = "ability", lvl = 60, key = "shieldslam", cost = 20, cd = 6, threat = 254, tmult = 1, blockvalue = true, shield = true, tank = true, read = "hit hit - -" }, -- Shield Slam
			[1464] = { is = "ability", lvl = 30, key = "slam", cost = 15, weapon = "plain", read = "add" }, -- Slam
			[8820] = { is = "ability", lvl = 38, key = "slam", cost = 15, weapon = "plain", read = "add" }, -- Slam
			[11604] = { is = "ability", lvl = 46, key = "slam", cost = 15, weapon = "plain", read = "add" }, -- Slam
			[11605] = { is = "ability", lvl = 54, key = "slam", cost = 15, weapon = "plain", read = "add" }, -- Slam
			[1240193] = { is = "ability", lvl = 20, key = "slam", cost = 15, weapon = "plain", read = "add" }, -- Slam
			[7386] = { is = "ability", lvl = 10, key = "sunderarmor", cost = 15, threat = 45, tmult = 1, tank = true, read = "- - -" }, -- Sunder Armor
			[7405] = { is = "ability", lvl = 22, key = "sunderarmor", cost = 15, threat = 99, tmult = 1, tank = true, read = "- - -" }, -- Sunder Armor
			[8380] = { is = "ability", lvl = 34, key = "sunderarmor", cost = 15, threat = 153, tmult = 1, tank = true, read = "- - -" }, -- Sunder Armor
			[11596] = { is = "ability", lvl = 46, key = "sunderarmor", cost = 15, threat = 207, tmult = 1, tank = true, read = "- - -" }, -- Sunder Armor
			[11597] = { is = "ability", lvl = 58, key = "sunderarmor", cost = 15, threat = 261, tmult = 1, tank = true, read = "- - -" }, -- Sunder Armor
			[6343] = { is = "ability", lvl = 6, key = "thunderclap", cost = 20, cd = 6, threat = 0, tmult = 2.5, aoe = true, read = "- - hit cap" }, -- Thunder Clap
			[8198] = { is = "ability", lvl = 18, key = "thunderclap", cost = 20, cd = 6, aoe = true, read = "- - hit cap" }, -- Thunder Clap
			[8204] = { is = "ability", lvl = 28, key = "thunderclap", cost = 20, cd = 6, aoe = true, read = "- - hit cap" }, -- Thunder Clap
			[8205] = { is = "ability", lvl = 38, key = "thunderclap", cost = 20, cd = 6, aoe = true, read = "- - hit cap" }, -- Thunder Clap
			[11580] = { is = "ability", lvl = 48, key = "thunderclap", cost = 20, cd = 6, aoe = true, read = "- - hit cap" }, -- Thunder Clap
			[11581] = { is = "ability", lvl = 58, key = "thunderclap", cost = 20, cd = 6, aoe = true, read = "- - hit cap" }, -- Thunder Clap
			[1680] = { is = "ability", lvl = 36, key = "whirlwind", cost = 25, cd = 10, aoe = true, weapon = "norm", read = "cap -" }, -- Whirlwind
		},
		MAGE = {
			[400574] = { is = "ability", lvl = 20, key = "arcaneblast", spell = 7, share = 0.429, read = "hit hit - - - -" }, -- Arcane Blast
			[1239696] = { is = "ability", lvl = 30, key = "arcaneblast", spell = 7, share = 0.429, read = "hit hit - - - -" }, -- Arcane Blast
			[1239697] = { is = "ability", lvl = 40, key = "arcaneblast", spell = 7, share = 0.429, read = "hit hit - - - -" }, -- Arcane Blast
			[1239699] = { is = "ability", lvl = 50, key = "arcaneblast", spell = 7, share = 0.429, read = "hit hit - - - -" }, -- Arcane Blast
			[1239700] = { is = "ability", lvl = 60, key = "arcaneblast", spell = 7, share = 0.429, read = "hit hit - - - -" }, -- Arcane Blast
			[1449] = { is = "ability", lvl = 14, key = "arcaneexplosion", cost = 75, spell = 7, share = 0.143, aoe = true, read = "hit hit -" }, -- Arcane Explosion
			[8437] = { is = "ability", lvl = 22, key = "arcaneexplosion", cost = 120, spell = 7, share = 0.143, aoe = true, read = "hit hit -" }, -- Arcane Explosion
			[8438] = { is = "ability", lvl = 30, key = "arcaneexplosion", cost = 185, spell = 7, share = 0.143, aoe = true, read = "hit hit -" }, -- Arcane Explosion
			[8439] = { is = "ability", lvl = 38, key = "arcaneexplosion", cost = 250, spell = 7, share = 0.143, aoe = true, read = "hit hit -" }, -- Arcane Explosion
			[10201] = { is = "ability", lvl = 46, key = "arcaneexplosion", cost = 315, spell = 7, share = 0.143, aoe = true, read = "hit hit -" }, -- Arcane Explosion
			[10202] = { is = "ability", lvl = 54, key = "arcaneexplosion", cost = 390, spell = 7, share = 0.143, aoe = true, read = "hit hit -" }, -- Arcane Explosion
			[5143] = { is = "ability", lvl = 8, key = "arcanemissiles", cost = 85, spell = 7, dshare = 0.858, secs = 3, channel = true, read = "tick -" }, -- Arcane Missiles
			[5144] = { is = "ability", lvl = 16, key = "arcanemissiles", cost = 140, spell = 7, dshare = 1.144, secs = 4, channel = true, read = "tick -" }, -- Arcane Missiles
			[5145] = { is = "ability", lvl = 24, key = "arcanemissiles", cost = 235, spell = 7, dshare = 1.43, secs = 5, channel = true, read = "tick -" }, -- Arcane Missiles
			[8416] = { is = "ability", lvl = 32, key = "arcanemissiles", cost = 320, spell = 7, dshare = 1.43, secs = 5, channel = true, read = "tick -" }, -- Arcane Missiles
			[8417] = { is = "ability", lvl = 40, key = "arcanemissiles", cost = 410, spell = 7, dshare = 1.43, secs = 5, channel = true, read = "tick -" }, -- Arcane Missiles
			[10211] = { is = "ability", lvl = 48, key = "arcanemissiles", cost = 500, spell = 7, dshare = 1.43, secs = 5, channel = true, read = "tick -" }, -- Arcane Missiles
			[10212] = { is = "ability", lvl = 56, key = "arcanemissiles", cost = 595, spell = 7, dshare = 1.43, secs = 5, channel = true, read = "tick -" }, -- Arcane Missiles
			[25345] = { is = "ability", lvl = 56, key = "arcanemissiles", cost = 655, spell = 7, dshare = 1.43, secs = 5, channel = true, read = "tick -" }, -- Arcane Missiles
			[11113] = { is = "ability", lvl = 30, key = "blastwave", cost = 215, cd = 45, spell = 3, share = 0.129, secs = 6, aoe = true, read = "hit hit - -" }, -- Blast Wave
			[13018] = { is = "ability", lvl = 36, key = "blastwave", cost = 270, cd = 45, spell = 3, share = 0.129, secs = 6, aoe = true, read = "hit hit - -" }, -- Blast Wave
			[13019] = { is = "ability", lvl = 44, key = "blastwave", cost = 355, cd = 45, spell = 3, share = 0.129, secs = 6, aoe = true, read = "hit hit - -" }, -- Blast Wave
			[13020] = { is = "ability", lvl = 52, key = "blastwave", cost = 450, cd = 45, spell = 3, share = 0.129, secs = 6, aoe = true, read = "hit hit - -" }, -- Blast Wave
			[13021] = { is = "ability", lvl = 60, key = "blastwave", cost = 545, cd = 45, spell = 3, share = 0.129, secs = 6, aoe = true, read = "hit hit - -" }, -- Blast Wave
			[10] = { is = "ability", lvl = 20, key = "blizzard", cost = 320, spell = 5, dshare = 0.336, secs = 8, aoe = true, channel = true, read = "dot -" }, -- Blizzard
			[6141] = { is = "ability", lvl = 28, key = "blizzard", cost = 520, spell = 5, dshare = 0.336, secs = 8, aoe = true, channel = true, read = "dot -" }, -- Blizzard
			[8427] = { is = "ability", lvl = 36, key = "blizzard", cost = 720, spell = 5, dshare = 0.336, secs = 8, aoe = true, channel = true, read = "dot -" }, -- Blizzard
			[10185] = { is = "ability", lvl = 44, key = "blizzard", cost = 935, spell = 5, dshare = 0.336, secs = 8, aoe = true, channel = true, read = "dot -" }, -- Blizzard
			[10186] = { is = "ability", lvl = 52, key = "blizzard", cost = 1160, spell = 5, dshare = 0.336, secs = 8, aoe = true, channel = true, read = "dot -" }, -- Blizzard
			[10187] = { is = "ability", lvl = 60, key = "blizzard", cost = 1400, spell = 5, dshare = 0.336, secs = 8, aoe = true, channel = true, read = "dot -" }, -- Blizzard
			[120] = { is = "ability", lvl = 26, key = "coneofcold", cost = 210, cd = 10, spell = 5, share = 0.129, secs = 6, aoe = true, read = "hit hit - - - - -" }, -- Cone of Cold
			[8492] = { is = "ability", lvl = 34, key = "coneofcold", cost = 290, cd = 10, spell = 5, share = 0.129, secs = 6, aoe = true, read = "hit hit - - - - -" }, -- Cone of Cold
			[10159] = { is = "ability", lvl = 42, key = "coneofcold", cost = 380, cd = 10, spell = 5, share = 0.129, secs = 6, aoe = true, read = "hit hit - - - - -" }, -- Cone of Cold
			[10160] = { is = "ability", lvl = 50, key = "coneofcold", cost = 465, cd = 10, spell = 5, share = 0.129, secs = 6, aoe = true, read = "hit hit - - - - -" }, -- Cone of Cold
			[10161] = { is = "ability", lvl = 58, key = "coneofcold", cost = 555, cd = 10, spell = 5, share = 0.129, secs = 6, aoe = true, read = "hit hit - - - - -" }, -- Cone of Cold
			[12051] = { is = "mana", lvl = 20, secs = 8, key = "evocation", cd = 480, threat = 20, tmult = 0, read = "pct -" }, -- Evocation
			[2136] = { is = "ability", lvl = 6, key = "fireblast", cost = 40, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[2137] = { is = "ability", lvl = 14, key = "fireblast", cost = 75, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[2138] = { is = "ability", lvl = 22, key = "fireblast", cost = 115, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[8412] = { is = "ability", lvl = 30, key = "fireblast", cost = 165, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[8413] = { is = "ability", lvl = 38, key = "fireblast", cost = 220, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[10197] = { is = "ability", lvl = 46, key = "fireblast", cost = 280, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[10199] = { is = "ability", lvl = 54, key = "fireblast", cost = 340, cd = 8, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[400616] = { is = "ability", lvl = 22, key = "fireblast", cost = 115, cd = 15, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[400618] = { is = "ability", lvl = 6, key = "fireblast", cost = 40, cd = 15, spell = 3, share = 0.204, read = "hit hit" }, -- Fire Blast
			[400619] = { is = "ability", lvl = 14, key = "fireblast", cost = 75, cd = 15, spell = 3, share = 0.332, read = "hit hit" }, -- Fire Blast
			[400620] = { is = "ability", lvl = 30, key = "fireblast", cost = 165, cd = 15, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[400621] = { is = "ability", lvl = 38, key = "fireblast", cost = 220, cd = 15, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[400622] = { is = "ability", lvl = 46, key = "fireblast", cost = 280, cd = 15, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[400623] = { is = "ability", lvl = 54, key = "fireblast", cost = 340, cd = 15, spell = 3, share = 0.429, read = "hit hit" }, -- Fire Blast
			[133] = { is = "ability", lvl = 1, key = "fireball", cost = 30, spell = 3, share = 0.429, secs = 4, over = true, read = "hit hit dot -" }, -- Fireball
			[143] = { is = "ability", lvl = 6, key = "fireball", cost = 45, spell = 3, share = 0.571, secs = 6, over = true, read = "hit hit dot -" }, -- Fireball
			[145] = { is = "ability", lvl = 12, key = "fireball", cost = 65, spell = 3, share = 0.714, secs = 6, over = true, read = "hit hit dot -" }, -- Fireball
			[3140] = { is = "ability", lvl = 18, key = "fireball", cost = 95, spell = 3, share = 0.857, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[8400] = { is = "ability", lvl = 24, key = "fireball", cost = 140, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[8401] = { is = "ability", lvl = 30, key = "fireball", cost = 185, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[8402] = { is = "ability", lvl = 36, key = "fireball", cost = 220, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[10148] = { is = "ability", lvl = 42, key = "fireball", cost = 260, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[10149] = { is = "ability", lvl = 48, key = "fireball", cost = 305, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[10150] = { is = "ability", lvl = 54, key = "fireball", cost = 350, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[10151] = { is = "ability", lvl = 60, key = "fireball", cost = 395, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[25306] = { is = "ability", lvl = 60, key = "fireball", cost = 410, spell = 3, share = 1.0, secs = 8, over = true, read = "hit hit dot -" }, -- Fireball
			[2120] = { is = "ability", lvl = 16, key = "flamestrike", cost = 195, spell = 3, share = 0.157, dshare = 0.128, secs = 8, aoe = true, over = true, read = "hit hit dot -" }, -- Flamestrike
			[2121] = { is = "ability", lvl = 24, key = "flamestrike", cost = 330, spell = 3, share = 0.157, dshare = 0.128, secs = 8, aoe = true, over = true, read = "hit hit dot -" }, -- Flamestrike
			[8422] = { is = "ability", lvl = 32, key = "flamestrike", cost = 490, spell = 3, share = 0.157, dshare = 0.128, secs = 8, aoe = true, over = true, read = "hit hit dot -" }, -- Flamestrike
			[8423] = { is = "ability", lvl = 40, key = "flamestrike", cost = 650, spell = 3, share = 0.157, dshare = 0.128, secs = 8, aoe = true, over = true, read = "hit hit dot -" }, -- Flamestrike
			[10215] = { is = "ability", lvl = 48, key = "flamestrike", cost = 815, spell = 3, share = 0.157, dshare = 0.128, secs = 8, aoe = true, over = true, read = "hit hit dot -" }, -- Flamestrike
			[10216] = { is = "ability", lvl = 56, key = "flamestrike", cost = 990, spell = 3, share = 0.157, dshare = 0.128, secs = 8, aoe = true, over = true, read = "hit hit dot -" }, -- Flamestrike
			[122] = { is = "ability", lvl = 10, key = "frostnova", cost = 55, cd = 25, spell = 5, share = 0.029, secs = 8, aoe = true, read = "hit hit -" }, -- Frost Nova
			[865] = { is = "ability", lvl = 26, key = "frostnova", cost = 85, cd = 25, spell = 5, share = 0.029, secs = 8, aoe = true, read = "hit hit -" }, -- Frost Nova
			[6131] = { is = "ability", lvl = 40, key = "frostnova", cost = 115, cd = 25, spell = 5, share = 0.029, secs = 8, aoe = true, read = "hit hit -" }, -- Frost Nova
			[10230] = { is = "ability", lvl = 54, key = "frostnova", cost = 145, cd = 25, spell = 5, share = 0.029, secs = 8, aoe = true, read = "hit hit -" }, -- Frost Nova
			[116] = { is = "ability", lvl = 4, key = "frostbolt", cost = 25, spell = 5, share = 0.407, secs = 5, read = "hit hit - -" }, -- Frostbolt
			[205] = { is = "ability", lvl = 8, key = "frostbolt", cost = 35, spell = 5, share = 0.489, secs = 6, read = "hit hit - -" }, -- Frostbolt
			[837] = { is = "ability", lvl = 14, key = "frostbolt", cost = 50, spell = 5, share = 0.597, secs = 6, read = "hit hit - -" }, -- Frostbolt
			[7322] = { is = "ability", lvl = 20, key = "frostbolt", cost = 65, spell = 5, share = 0.706, secs = 7, read = "hit hit - -" }, -- Frostbolt
			[8406] = { is = "ability", lvl = 26, key = "frostbolt", cost = 100, spell = 5, share = 0.814, secs = 7, read = "hit hit - -" }, -- Frostbolt
			[8407] = { is = "ability", lvl = 32, key = "frostbolt", cost = 130, spell = 5, share = 0.814, secs = 8, read = "hit hit - -" }, -- Frostbolt
			[8408] = { is = "ability", lvl = 38, key = "frostbolt", cost = 160, spell = 5, share = 0.814, secs = 8, read = "hit hit - -" }, -- Frostbolt
			[10179] = { is = "ability", lvl = 44, key = "frostbolt", cost = 195, spell = 5, share = 0.814, secs = 9, read = "hit hit - -" }, -- Frostbolt
			[10180] = { is = "ability", lvl = 50, key = "frostbolt", cost = 225, spell = 5, share = 0.814, secs = 9, read = "hit hit - -" }, -- Frostbolt
			[10181] = { is = "ability", lvl = 56, key = "frostbolt", cost = 260, spell = 5, share = 0.814, secs = 9, read = "hit hit - -" }, -- Frostbolt
			[25304] = { is = "ability", lvl = 60, key = "frostbolt", cost = 290, spell = 5, share = 0.814, secs = 9, read = "hit hit - -" }, -- Frostbolt
			[401502] = { is = "ability", lvl = 40, key = "frostfirebolt", cost = 205, spell = 3, spell2 = 5, share = 0.814, secs = 9, over = true, read = "hit hit - dot -" }, -- Frostfire Bolt
			[1237312] = { is = "ability", lvl = 50, key = "frostfirebolt", cost = 285, spell = 3, spell2 = 5, share = 0.814, secs = 9, over = true, read = "hit hit - dot -" }, -- Frostfire Bolt
			[1237313] = { is = "ability", lvl = 60, key = "frostfirebolt", cost = 370, spell = 3, spell2 = 5, share = 0.814, secs = 9, over = true, read = "hit hit - dot -" }, -- Frostfire Bolt
			[400640] = { is = "ability", lvl = 28, key = "icelance", cost = 55, cd = 8, spell = 5, read = "hit hit -" }, -- Ice Lance
			[1240044] = { is = "ability", lvl = 34, key = "icelance", cost = 70, cd = 8, spell = 5, read = "hit hit -" }, -- Ice Lance
			[1240045] = { is = "ability", lvl = 42, key = "icelance", cost = 105, cd = 8, spell = 5, read = "hit hit -" }, -- Ice Lance
			[1240046] = { is = "ability", lvl = 48, key = "icelance", cost = 120, cd = 8, spell = 5, read = "hit hit -" }, -- Ice Lance
			[1240047] = { is = "ability", lvl = 56, key = "icelance", cost = 160, cd = 8, spell = 5, read = "hit hit -" }, -- Ice Lance
			[1312002] = { is = "ability", lvl = 20, key = "icelance", cost = 45, cd = 8, spell = 5, read = "hit hit -" }, -- Ice Lance
			[11366] = { is = "ability", lvl = 20, key = "pyroblast", cost = 125, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[12505] = { is = "ability", lvl = 24, key = "pyroblast", cost = 150, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[12522] = { is = "ability", lvl = 30, key = "pyroblast", cost = 195, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[12523] = { is = "ability", lvl = 36, key = "pyroblast", cost = 240, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[12524] = { is = "ability", lvl = 42, key = "pyroblast", cost = 285, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[12525] = { is = "ability", lvl = 48, key = "pyroblast", cost = 335, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[12526] = { is = "ability", lvl = 54, key = "pyroblast", cost = 385, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[18809] = { is = "ability", lvl = 60, key = "pyroblast", cost = 440, spell = 3, share = 1.0, dshare = 0.6, secs = 12, over = true, read = "hit hit dot -" }, -- Pyroblast
			[2948] = { is = "ability", lvl = 22, key = "scorch", cost = 50, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
			[8444] = { is = "ability", lvl = 28, key = "scorch", cost = 65, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
			[8445] = { is = "ability", lvl = 34, key = "scorch", cost = 80, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
			[8446] = { is = "ability", lvl = 40, key = "scorch", cost = 100, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
			[10205] = { is = "ability", lvl = 46, key = "scorch", cost = 115, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
			[10206] = { is = "ability", lvl = 52, key = "scorch", cost = 135, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
			[10207] = { is = "ability", lvl = 58, key = "scorch", cost = 150, spell = 3, share = 0.429, read = "hit hit" }, -- Scorch
		},
		ROGUE = {
			[8676] = { is = "ability", lvl = 18, key = "ambush", cost = 60, dagger = true, energy = true, opener = true, points = 1, weapon = "norm", read = "pct add -" }, -- Ambush
			[8724] = { is = "ability", lvl = 26, key = "ambush", cost = 60, dagger = true, energy = true, opener = true, points = 1, weapon = "norm", read = "pct add -" }, -- Ambush
			[8725] = { is = "ability", lvl = 34, key = "ambush", cost = 60, dagger = true, energy = true, opener = true, points = 1, weapon = "norm", read = "pct add -" }, -- Ambush
			[11267] = { is = "ability", lvl = 42, key = "ambush", cost = 60, dagger = true, energy = true, opener = true, points = 1, weapon = "norm", read = "pct add -" }, -- Ambush
			[11268] = { is = "ability", lvl = 50, key = "ambush", cost = 60, dagger = true, energy = true, opener = true, points = 1, weapon = "norm", read = "pct add -" }, -- Ambush
			[11269] = { is = "ability", lvl = 58, key = "ambush", cost = 60, dagger = true, energy = true, opener = true, points = 1, weapon = "norm", read = "pct add -" }, -- Ambush
			[53] = { is = "ability", lvl = 4, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[2589] = { is = "ability", lvl = 12, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[2590] = { is = "ability", lvl = 20, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[2591] = { is = "ability", lvl = 28, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[8721] = { is = "ability", lvl = 36, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[11279] = { is = "ability", lvl = 44, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[11280] = { is = "ability", lvl = 52, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[11281] = { is = "ability", lvl = 60, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[25300] = { is = "ability", lvl = 60, key = "backstab", cost = 60, behind = true, dagger = true, energy = true, points = 1, weapon = "norm", read = "pct add -" }, -- Backstab
			[2098] = { is = "ability", lvl = 1, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[6760] = { is = "ability", lvl = 8, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[6761] = { is = "ability", lvl = 16, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[6762] = { is = "ability", lvl = 24, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[8623] = { is = "ability", lvl = 32, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[8624] = { is = "ability", lvl = 40, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[11299] = { is = "ability", lvl = 48, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[11300] = { is = "ability", lvl = 56, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[31016] = { is = "ability", lvl = 60, key = "eviscerate", cost = 35, energy = true, finisher = true, read = "- p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Eviscerate
			[703] = { is = "ability", lvl = 14, key = "garrote", cost = 50, secs = 18, dot = true, energy = true, opener = true, points = 1, read = "dot - -" }, -- Garrote
			[8631] = { is = "ability", lvl = 22, key = "garrote", cost = 50, secs = 18, dot = true, energy = true, opener = true, points = 1, read = "dot - -" }, -- Garrote
			[8632] = { is = "ability", lvl = 30, key = "garrote", cost = 50, secs = 18, dot = true, energy = true, opener = true, points = 1, read = "dot - -" }, -- Garrote
			[8633] = { is = "ability", lvl = 38, key = "garrote", cost = 50, secs = 18, dot = true, energy = true, opener = true, points = 1, read = "dot - -" }, -- Garrote
			[11289] = { is = "ability", lvl = 46, key = "garrote", cost = 50, secs = 18, dot = true, energy = true, opener = true, points = 1, read = "dot - -" }, -- Garrote
			[11290] = { is = "ability", lvl = 54, key = "garrote", cost = 50, secs = 18, dot = true, energy = true, opener = true, points = 1, read = "dot - -" }, -- Garrote
			[14278] = { is = "ability", key = "ghostlystrike", cost = 40, cd = 20, energy = true, points = 1, weapon = "norm", read = "pct pctdagger - - - -" }, -- Ghostly Strike
			[16511] = { is = "ability", lvl = 30, key = "hemorrhage", cost = 35, energy = true, points = 1, weapon = "norm", read = "pct pctdagger - - -" }, -- Hemorrhage
			[1943] = { is = "ability", lvl = 20, key = "rupture", cost = 25, secs = 6, bleed = true, energy = true, finisher = true, read = "- r1 t1 - r2 t2 - r3 t3 - r4 t4 - r5 t5" }, -- Rupture
			[8639] = { is = "ability", lvl = 28, key = "rupture", cost = 25, secs = 6, bleed = true, energy = true, finisher = true, read = "- r1 t1 - r2 t2 - r3 t3 - r4 t4 - r5 t5" }, -- Rupture
			[8640] = { is = "ability", lvl = 36, key = "rupture", cost = 25, secs = 6, bleed = true, energy = true, finisher = true, read = "- r1 t1 - r2 t2 - r3 t3 - r4 t4 - r5 t5" }, -- Rupture
			[11273] = { is = "ability", lvl = 44, key = "rupture", cost = 25, secs = 6, bleed = true, energy = true, finisher = true, read = "- r1 t1 - r2 t2 - r3 t3 - r4 t4 - r5 t5" }, -- Rupture
			[11274] = { is = "ability", lvl = 52, key = "rupture", cost = 25, secs = 6, bleed = true, energy = true, finisher = true, read = "- r1 t1 - r2 t2 - r3 t3 - r4 t4 - r5 t5" }, -- Rupture
			[11275] = { is = "ability", lvl = 60, key = "rupture", cost = 25, secs = 6, bleed = true, energy = true, finisher = true, read = "- r1 t1 - r2 t2 - r3 t3 - r4 t4 - r5 t5" }, -- Rupture
			[1752] = { is = "ability", lvl = 1, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[1757] = { is = "ability", lvl = 6, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[1758] = { is = "ability", lvl = 14, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[1759] = { is = "ability", lvl = 22, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[1760] = { is = "ability", lvl = 30, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[8621] = { is = "ability", lvl = 38, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[11293] = { is = "ability", lvl = 46, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[11294] = { is = "ability", lvl = 54, key = "sinisterstrike", cost = 45, energy = true, points = 1, weapon = "norm", read = "add -" }, -- Sinister Strike
			[5171] = { is = "ability", lvl = 10, key = "sliceanddice", cost = 25, energy = true, finisher = true, speed = true, read = "pct - t1 - t2 - t3 - t4 - t5" }, -- Slice and Dice
			[6774] = { is = "ability", lvl = 42, key = "sliceanddice", cost = 25, energy = true, finisher = true, speed = true, read = "pct - t1 - t2 - t3 - t4 - t5" }, -- Slice and Dice
		},
		HUNTER = {
			[19434] = { is = "ability", lvl = 20, key = "aimedshot", cost = 75, cd = 6, ranged = true, weapon = "plain", read = "add" }, -- Aimed Shot
			[20900] = { is = "ability", lvl = 28, key = "aimedshot", cost = 115, cd = 6, ranged = true, weapon = "plain", read = "add" }, -- Aimed Shot
			[20901] = { is = "ability", lvl = 36, key = "aimedshot", cost = 160, cd = 6, ranged = true, weapon = "plain", read = "add" }, -- Aimed Shot
			[20902] = { is = "ability", lvl = 44, key = "aimedshot", cost = 210, cd = 6, ranged = true, weapon = "plain", read = "add" }, -- Aimed Shot
			[20903] = { is = "ability", lvl = 52, key = "aimedshot", cost = 260, cd = 6, ranged = true, weapon = "plain", read = "add" }, -- Aimed Shot
			[20904] = { is = "ability", lvl = 60, key = "aimedshot", cost = 310, cd = 6, ranged = true, weapon = "plain", read = "add" }, -- Aimed Shot
			[3044] = { is = "ability", lvl = 6, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14281] = { is = "ability", lvl = 12, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14282] = { is = "ability", lvl = 20, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14283] = { is = "ability", lvl = 28, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14284] = { is = "ability", lvl = 36, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14285] = { is = "ability", lvl = 44, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14286] = { is = "ability", lvl = 52, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[14287] = { is = "ability", lvl = 60, key = "arcaneshot", cd = 6, spell = 7, ranged = true, read = "hit" }, -- Arcane Shot
			[2643] = { is = "ability", lvl = 18, key = "multishot", cd = 6, aoe = true, ranged = true, weapon = "plain", read = "cap" }, -- Multi-Shot
			[1978] = { is = "ability", lvl = 4, key = "serpentsting", cost = 15, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13549] = { is = "ability", lvl = 10, key = "serpentsting", cost = 30, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13550] = { is = "ability", lvl = 18, key = "serpentsting", cost = 50, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13551] = { is = "ability", lvl = 26, key = "serpentsting", cost = 80, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13552] = { is = "ability", lvl = 34, key = "serpentsting", cost = 115, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13553] = { is = "ability", lvl = 42, key = "serpentsting", cost = 150, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13554] = { is = "ability", lvl = 50, key = "serpentsting", cost = 190, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[13555] = { is = "ability", lvl = 58, key = "serpentsting", cost = 230, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[25295] = { is = "ability", lvl = 60, key = "serpentsting", cost = 250, spell = 4, secs = 15, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425728] = { is = "ability", lvl = 4, key = "serpentsting", spell = 4, dshare = 0.32, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425729] = { is = "ability", lvl = 10, key = "serpentsting", spell = 4, dshare = 0.5, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425730] = { is = "ability", lvl = 18, key = "serpentsting", spell = 4, dshare = 0.74, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425732] = { is = "ability", lvl = 26, key = "serpentsting", spell = 4, dshare = 0.8, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425733] = { is = "ability", lvl = 34, key = "serpentsting", spell = 4, dshare = 0.8, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425734] = { is = "ability", lvl = 42, key = "serpentsting", spell = 4, dshare = 0.8, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425735] = { is = "ability", lvl = 50, key = "serpentsting", spell = 4, dshare = 0.8, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425736] = { is = "ability", lvl = 58, key = "serpentsting", spell = 4, dshare = 0.8, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[425737] = { is = "ability", lvl = 60, key = "serpentsting", spell = 4, dshare = 0.8, secs = 12, lasts = true, ranged = true, read = "dot -" }, -- Serpent Sting
			[1310687] = { is = "ability", lvl = 40, key = "snipershot", cost = 365, cd = 15, ranged = true, weapon = "plain", read = "add - - -" }, -- Sniper Shot
			[1310785] = { is = "ability", lvl = 48, key = "snipershot", cost = 365, cd = 15, ranged = true, weapon = "plain", read = "add - - -" }, -- Sniper Shot
			[1310786] = { is = "ability", lvl = 58, key = "snipershot", cost = 365, cd = 15, ranged = true, weapon = "plain", read = "add - - -" }, -- Sniper Shot
			[1510] = { is = "ability", lvl = 40, key = "volley", cost = 350, spell = 7, secs = 6, aoe = true, channel = true, ranged = true, read = "tick - - -" }, -- Volley
			[14294] = { is = "ability", lvl = 50, key = "volley", cost = 420, spell = 7, secs = 6, aoe = true, channel = true, ranged = true, read = "tick - - -" }, -- Volley
			[14295] = { is = "ability", lvl = 58, key = "volley", cost = 490, spell = 7, secs = 6, aoe = true, channel = true, ranged = true, read = "tick - - -" }, -- Volley
		},
		WARLOCK = {
			[980] = { is = "ability", lvl = 8, key = "baneofagony", cost = 25, spell = 6, dshare = 1.596, secs = 24, lasts = true, pet = true, read = "dot -" }, -- Bane of Agony
			[1014] = { is = "ability", lvl = 18, key = "baneofagony", cost = 50, spell = 6, dshare = 1.596, secs = 24, lasts = true, pet = true, read = "dot -" }, -- Bane of Agony
			[6217] = { is = "ability", lvl = 28, key = "baneofagony", cost = 90, spell = 6, dshare = 1.596, secs = 24, lasts = true, pet = true, read = "dot -" }, -- Bane of Agony
			[11711] = { is = "ability", lvl = 38, key = "baneofagony", cost = 130, spell = 6, dshare = 1.596, secs = 24, lasts = true, pet = true, read = "dot -" }, -- Bane of Agony
			[11712] = { is = "ability", lvl = 48, key = "baneofagony", cost = 170, spell = 6, dshare = 1.596, secs = 24, lasts = true, pet = true, read = "dot -" }, -- Bane of Agony
			[11713] = { is = "ability", lvl = 58, key = "baneofagony", cost = 215, spell = 6, dshare = 1.596, secs = 24, lasts = true, pet = true, read = "dot -" }, -- Bane of Agony
			[172] = { is = "ability", lvl = 4, key = "corruption", cost = 35, spell = 6, dshare = 0.8, secs = 12, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[6222] = { is = "ability", lvl = 14, key = "corruption", cost = 55, spell = 6, dshare = 1.0, secs = 15, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[6223] = { is = "ability", lvl = 24, key = "corruption", cost = 100, spell = 6, dshare = 1.2, secs = 18, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[7648] = { is = "ability", lvl = 34, key = "corruption", cost = 160, spell = 6, dshare = 1.2, secs = 18, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[11671] = { is = "ability", lvl = 44, key = "corruption", cost = 225, spell = 6, dshare = 1.2, secs = 18, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[11672] = { is = "ability", lvl = 54, key = "corruption", cost = 290, spell = 6, dshare = 1.2, secs = 18, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[25311] = { is = "ability", lvl = 60, key = "corruption", cost = 340, spell = 6, dshare = 1.2, secs = 18, lasts = true, pet = true, read = "dot -" }, -- Corruption
			[689] = { is = "ability", lvl = 14, key = "drainlife", cost = 55, spell = 6, period = 1, dshare = 0.5, secs = 5, channel = true, pet = true, read = "tick - -" }, -- Drain Life
			[699] = { is = "ability", lvl = 22, key = "drainlife", cost = 85, spell = 6, period = 1, dshare = 0.5, secs = 5, channel = true, pet = true, read = "tick - -" }, -- Drain Life
			[709] = { is = "ability", lvl = 30, key = "drainlife", cost = 135, spell = 6, period = 1, dshare = 0.5, secs = 5, channel = true, pet = true, read = "tick - -" }, -- Drain Life
			[7651] = { is = "ability", lvl = 38, key = "drainlife", cost = 185, spell = 6, period = 1, dshare = 0.5, secs = 5, channel = true, pet = true, read = "tick - -" }, -- Drain Life
			[11699] = { is = "ability", lvl = 46, key = "drainlife", cost = 240, spell = 6, period = 1, dshare = 0.5, secs = 5, channel = true, pet = true, read = "tick - -" }, -- Drain Life
			[11700] = { is = "ability", lvl = 54, key = "drainlife", cost = 300, spell = 6, period = 1, dshare = 0.5, secs = 5, channel = true, pet = true, read = "tick - -" }, -- Drain Life
			[403677] = { is = "ability", lvl = 14, key = "drainlife", cost = 110, cd = 15, spell = 6, period = 1, dshare = 1.17, secs = 15, channel = true, pet = true, read = "tick -" }, -- Drain Life
			[403685] = { is = "ability", lvl = 22, key = "drainlife", cost = 170, cd = 15, spell = 6, period = 1, dshare = 1.5, secs = 15, channel = true, pet = true, read = "tick -" }, -- Drain Life
			[403686] = { is = "ability", lvl = 30, key = "drainlife", cost = 270, cd = 15, spell = 6, period = 1, dshare = 1.5, secs = 15, channel = true, pet = true, read = "tick -" }, -- Drain Life
			[403687] = { is = "ability", lvl = 38, key = "drainlife", cost = 370, cd = 15, spell = 6, period = 1, dshare = 1.5, secs = 15, channel = true, pet = true, read = "tick -" }, -- Drain Life
			[403688] = { is = "ability", lvl = 46, key = "drainlife", cost = 480, cd = 15, spell = 6, period = 1, dshare = 1.5, secs = 15, channel = true, pet = true, read = "tick -" }, -- Drain Life
			[403689] = { is = "ability", lvl = 54, key = "drainlife", cost = 600, cd = 15, spell = 6, period = 1, dshare = 1.5, secs = 15, channel = true, pet = true, read = "tick -" }, -- Drain Life
			[348] = { is = "ability", lvl = 1, key = "immolate", cost = 25, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[707] = { is = "ability", lvl = 10, key = "immolate", cost = 45, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[1094] = { is = "ability", lvl = 20, key = "immolate", cost = 90, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[2941] = { is = "ability", lvl = 30, key = "immolate", cost = 155, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[11665] = { is = "ability", lvl = 40, key = "immolate", cost = 220, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[11667] = { is = "ability", lvl = 50, key = "immolate", cost = 295, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[11668] = { is = "ability", lvl = 60, key = "immolate", cost = 370, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[25309] = { is = "ability", lvl = 60, key = "immolate", cost = 380, spell = 3, share = 0.2, dshare = 0.65, secs = 15, lasts = true, pet = true, read = "hit dot -" }, -- Immolate
			[412758] = { is = "ability", lvl = 40, key = "incinerate", cost = 205, spell = 3, share = 0.714, pet = true, read = "hit hit -" }, -- Incinerate
			[1293812] = { is = "ability", lvl = 50, key = "incinerate", cost = 265, spell = 3, share = 0.714, pet = true, read = "hit hit -" }, -- Incinerate
			[1293813] = { is = "ability", lvl = 60, key = "incinerate", cost = 325, spell = 3, share = 0.714, pet = true, read = "hit hit -" }, -- Incinerate
			[1454] = { is = "tap", lvl = 6, key = "lifetap", read = "- mana" }, -- Life Tap
			[1455] = { is = "tap", lvl = 16, key = "lifetap", read = "- mana" }, -- Life Tap
			[1456] = { is = "tap", lvl = 26, key = "lifetap", read = "- mana" }, -- Life Tap
			[11687] = { is = "tap", lvl = 36, key = "lifetap", read = "- mana" }, -- Life Tap
			[11688] = { is = "tap", lvl = 46, key = "lifetap", read = "- mana" }, -- Life Tap
			[11689] = { is = "tap", lvl = 56, key = "lifetap", read = "- mana" }, -- Life Tap
			[5740] = { is = "ability", lvl = 20, key = "rainoffire", cost = 295, spell = 3, dshare = 0.332, secs = 8, aoe = true, channel = true, pet = true, read = "dot -" }, -- Rain of Fire
			[6219] = { is = "ability", lvl = 34, key = "rainoffire", cost = 605, spell = 3, dshare = 0.332, secs = 8, aoe = true, channel = true, pet = true, read = "dot -" }, -- Rain of Fire
			[11677] = { is = "ability", lvl = 46, key = "rainoffire", cost = 885, spell = 3, dshare = 0.332, secs = 8, aoe = true, channel = true, pet = true, read = "dot -" }, -- Rain of Fire
			[11678] = { is = "ability", lvl = 58, key = "rainoffire", cost = 1185, spell = 3, dshare = 0.332, secs = 8, aoe = true, channel = true, pet = true, read = "dot -" }, -- Rain of Fire
			[5676] = { is = "ability", lvl = 18, key = "searingpain", cost = 45, spell = 3, share = 0.429, pet = true, read = "hit hit" }, -- Searing Pain
			[17919] = { is = "ability", lvl = 26, key = "searingpain", cost = 68, spell = 3, share = 0.429, pet = true, read = "hit hit" }, -- Searing Pain
			[17920] = { is = "ability", lvl = 34, key = "searingpain", cost = 91, spell = 3, share = 0.429, pet = true, read = "hit hit" }, -- Searing Pain
			[17921] = { is = "ability", lvl = 42, key = "searingpain", cost = 118, spell = 3, share = 0.429, pet = true, read = "hit hit" }, -- Searing Pain
			[17922] = { is = "ability", lvl = 50, key = "searingpain", cost = 141, spell = 3, share = 0.429, pet = true, read = "hit hit" }, -- Searing Pain
			[17923] = { is = "ability", lvl = 58, key = "searingpain", cost = 168, spell = 3, share = 0.429, pet = true, read = "hit hit" }, -- Searing Pain
			[686] = { is = "ability", lvl = 1, key = "shadowbolt", cost = 25, spell = 6, share = 0.486, pet = true, read = "hit hit" }, -- Shadow Bolt
			[695] = { is = "ability", lvl = 6, key = "shadowbolt", cost = 40, spell = 6, share = 0.629, pet = true, read = "hit hit" }, -- Shadow Bolt
			[705] = { is = "ability", lvl = 12, key = "shadowbolt", cost = 70, spell = 6, share = 0.8, pet = true, read = "hit hit" }, -- Shadow Bolt
			[1088] = { is = "ability", lvl = 20, key = "shadowbolt", cost = 110, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[1106] = { is = "ability", lvl = 28, key = "shadowbolt", cost = 160, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[7641] = { is = "ability", lvl = 36, key = "shadowbolt", cost = 210, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[11659] = { is = "ability", lvl = 44, key = "shadowbolt", cost = 265, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[11660] = { is = "ability", lvl = 52, key = "shadowbolt", cost = 315, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[11661] = { is = "ability", lvl = 60, key = "shadowbolt", cost = 370, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[25307] = { is = "ability", lvl = 60, key = "shadowbolt", cost = 380, spell = 6, share = 0.857, pet = true, read = "hit hit" }, -- Shadow Bolt
			[17877] = { is = "ability", lvl = 20, key = "shadowburn", cost = 105, cd = 15, spell = 6, share = 0.429, secs = 8, pet = true, read = "hit hit -" }, -- Shadowburn
			[18867] = { is = "ability", lvl = 24, key = "shadowburn", cost = 130, cd = 15, spell = 6, share = 0.429, secs = 8, pet = true, read = "hit hit -" }, -- Shadowburn
			[18868] = { is = "ability", lvl = 32, key = "shadowburn", cost = 190, cd = 15, spell = 6, share = 0.429, secs = 8, pet = true, read = "hit hit -" }, -- Shadowburn
			[18869] = { is = "ability", lvl = 40, key = "shadowburn", cost = 245, cd = 15, spell = 6, share = 0.429, secs = 8, pet = true, read = "hit hit -" }, -- Shadowburn
			[18870] = { is = "ability", lvl = 48, key = "shadowburn", cost = 305, cd = 15, spell = 6, share = 0.429, secs = 8, pet = true, read = "hit hit -" }, -- Shadowburn
			[18871] = { is = "ability", lvl = 56, key = "shadowburn", cost = 365, cd = 15, spell = 6, share = 0.429, secs = 8, pet = true, read = "hit hit -" }, -- Shadowburn
			[18265] = { is = "ability", lvl = 30, key = "siphonlife", cost = 150, spell = 6, period = 3, dshare = 0.5, secs = 30, lasts = true, pet = true, read = "tick - -" }, -- Siphon Life
			[18879] = { is = "ability", lvl = 38, key = "siphonlife", cost = 205, spell = 6, period = 3, dshare = 0.5, secs = 30, lasts = true, pet = true, read = "tick - -" }, -- Siphon Life
			[18880] = { is = "ability", lvl = 48, key = "siphonlife", cost = 285, spell = 6, period = 3, dshare = 0.5, secs = 30, lasts = true, pet = true, read = "tick - -" }, -- Siphon Life
			[18881] = { is = "ability", lvl = 58, key = "siphonlife", cost = 365, spell = 6, period = 3, dshare = 0.5, secs = 30, lasts = true, pet = true, read = "tick - -" }, -- Siphon Life
			[6353] = { is = "ability", lvl = 48, key = "soulfire", cost = 305, cd = 60, spell = 3, share = 1.0, pet = true, read = "hit hit" }, -- Soul Fire
			[17924] = { is = "ability", lvl = 56, key = "soulfire", cost = 335, cd = 60, spell = 3, share = 1.0, pet = true, read = "hit hit" }, -- Soul Fire
		},
		PRIEST = {
			[2944] = { is = "ability", lvl = 20, key = "devouringplague", cost = 215, cd = 24, spell = 6, dshare = 0.8, secs = 24, lasts = true, read = "dot -" }, -- Devouring Plague
			[19276] = { is = "ability", lvl = 28, key = "devouringplague", cost = 350, cd = 24, spell = 6, dshare = 0.8, secs = 24, lasts = true, read = "dot -" }, -- Devouring Plague
			[19277] = { is = "ability", lvl = 36, key = "devouringplague", cost = 495, cd = 24, spell = 6, dshare = 0.8, secs = 24, lasts = true, read = "dot -" }, -- Devouring Plague
			[19278] = { is = "ability", lvl = 44, key = "devouringplague", cost = 645, cd = 24, spell = 6, dshare = 0.8, secs = 24, lasts = true, read = "dot -" }, -- Devouring Plague
			[19279] = { is = "ability", lvl = 52, key = "devouringplague", cost = 810, cd = 24, spell = 6, dshare = 0.8, secs = 24, lasts = true, read = "dot -" }, -- Devouring Plague
			[19280] = { is = "ability", lvl = 60, key = "devouringplague", cost = 985, cd = 24, spell = 6, dshare = 0.8, secs = 24, lasts = true, read = "dot -" }, -- Devouring Plague
			[2061] = { is = "heal:flashHeal", lvl = 20, share = 0.429, base = 194, per = 1.9, from = 20, to = 25, read = "amount amount" }, -- Flash Heal
			[9472] = { is = "heal:flashHeal", lvl = 26, share = 0.429, base = 249, per = 2.2, from = 26, to = 31, read = "amount amount" }, -- Flash Heal
			[9473] = { is = "heal:flashHeal", lvl = 32, share = 0.429, base = 312, per = 2.5, from = 32, to = 37, read = "amount amount" }, -- Flash Heal
			[9474] = { is = "heal:flashHeal", lvl = 38, share = 0.429, base = 383, per = 2.8, from = 38, to = 43, read = "amount amount" }, -- Flash Heal
			[10915] = { is = "heal:flashHeal", lvl = 44, share = 0.429, base = 507, per = 3.3, from = 44, to = 49, read = "amount amount" }, -- Flash Heal
			[10916] = { is = "heal:flashHeal", lvl = 50, share = 0.429, base = 644, per = 3.7, from = 50, to = 55, read = "amount amount" }, -- Flash Heal
			[10917] = { is = "heal:flashHeal", lvl = 56, share = 0.429, base = 825, per = 4.2, from = 56, to = 61, read = "amount amount" }, -- Flash Heal
			[2060] = { is = "heal:greaterHeal", lvl = 40, share = 0.857, base = 844, per = 5.1, from = 40, to = 45, read = "amount amount" }, -- Greater Heal
			[10963] = { is = "heal:greaterHeal", lvl = 46, share = 0.857, base = 1099, per = 5.8, from = 46, to = 51, read = "amount amount" }, -- Greater Heal
			[10964] = { is = "heal:greaterHeal", lvl = 52, share = 0.857, base = 1403, per = 6.6, from = 52, to = 57, read = "amount amount" }, -- Greater Heal
			[10965] = { is = "heal:greaterHeal", lvl = 58, share = 0.857, base = 1782, per = 7.5, from = 58, to = 63, read = "amount amount" }, -- Greater Heal
			[25314] = { is = "heal:greaterHeal", lvl = 60, share = 0.857, base = 1960, per = 8.1, from = 60, to = 65, read = "amount amount" }, -- Greater Heal
			[2054] = { is = "heal:heal", lvl = 16, share = 0.857, base = 270, per = 2, from = 16, to = 21, read = "amount amount" }, -- Heal
			[2055] = { is = "heal:heal", lvl = 22, share = 0.857, base = 375, per = 2.9, from = 22, to = 27, read = "amount amount" }, -- Heal
			[6063] = { is = "heal:heal", lvl = 28, share = 0.857, base = 523, per = 4, from = 28, to = 33, read = "amount amount" }, -- Heal
			[6064] = { is = "heal:heal", lvl = 34, share = 0.857, base = 651, per = 4.5, from = 34, to = 39, read = "amount amount" }, -- Heal
			[14914] = { is = "ability", lvl = 20, key = "holyfire", cost = 85, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15261] = { is = "ability", lvl = 60, key = "holyfire", cost = 255, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15262] = { is = "ability", lvl = 24, key = "holyfire", cost = 95, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15263] = { is = "ability", lvl = 30, key = "holyfire", cost = 125, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15264] = { is = "ability", lvl = 36, key = "holyfire", cost = 145, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15265] = { is = "ability", lvl = 42, key = "holyfire", cost = 170, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15266] = { is = "ability", lvl = 48, key = "holyfire", cost = 200, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[15267] = { is = "ability", lvl = 54, key = "holyfire", cost = 230, spell = 2, share = 0.75, dshare = 0.25, secs = 10, over = true, spec = "holy", read = "hit hit dot -" }, -- Holy Fire
			[2050] = { is = "heal:lesserHeal", lvl = 1, share = 0.429, base = 51, per = 0.3, from = 1, to = 3, read = "amount amount" }, -- Lesser Heal
			[2052] = { is = "heal:lesserHeal", lvl = 4, share = 0.571, base = 94, per = 0.7, from = 4, to = 9, read = "amount amount" }, -- Lesser Heal
			[2053] = { is = "heal:lesserHeal", lvl = 10, share = 0.714, base = 163, per = 1.2, from = 10, to = 15, read = "amount amount" }, -- Lesser Heal
			[8092] = { is = "ability", lvl = 10, key = "mindblast", cost = 50, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[8102] = { is = "ability", lvl = 16, key = "mindblast", cost = 80, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[8103] = { is = "ability", lvl = 22, key = "mindblast", cost = 110, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[8104] = { is = "ability", lvl = 28, key = "mindblast", cost = 150, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[8105] = { is = "ability", lvl = 34, key = "mindblast", cost = 185, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[8106] = { is = "ability", lvl = 40, key = "mindblast", cost = 225, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[10945] = { is = "ability", lvl = 46, key = "mindblast", cost = 265, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[10946] = { is = "ability", lvl = 52, key = "mindblast", cost = 310, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[10947] = { is = "ability", lvl = 58, key = "mindblast", cost = 350, cd = 8, spell = 6, share = 0.429, read = "hit hit" }, -- Mind Blast
			[15407] = { is = "ability", lvl = 20, key = "mindflay", cost = 45, spell = 6, dshare = 0.501, secs = 3, channel = true, read = "dot - -" }, -- Mind Flay
			[17311] = { is = "ability", lvl = 28, key = "mindflay", cost = 70, spell = 6, dshare = 0.501, secs = 3, channel = true, read = "dot - -" }, -- Mind Flay
			[17312] = { is = "ability", lvl = 36, key = "mindflay", cost = 100, spell = 6, dshare = 0.501, secs = 3, channel = true, read = "dot - -" }, -- Mind Flay
			[17313] = { is = "ability", lvl = 44, key = "mindflay", cost = 135, spell = 6, dshare = 0.501, secs = 3, channel = true, read = "dot - -" }, -- Mind Flay
			[17314] = { is = "ability", lvl = 52, key = "mindflay", cost = 165, spell = 6, dshare = 0.501, secs = 3, channel = true, read = "dot - -" }, -- Mind Flay
			[18807] = { is = "ability", lvl = 60, key = "mindflay", cost = 205, spell = 6, dshare = 0.501, secs = 3, channel = true, read = "dot - -" }, -- Mind Flay
			[589] = { is = "ability", lvl = 4, key = "shadowwordpain", cost = 25, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[594] = { is = "ability", lvl = 10, key = "shadowwordpain", cost = 50, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[970] = { is = "ability", lvl = 18, key = "shadowwordpain", cost = 95, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[992] = { is = "ability", lvl = 26, key = "shadowwordpain", cost = 155, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[2767] = { is = "ability", lvl = 34, key = "shadowwordpain", cost = 230, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[10892] = { is = "ability", lvl = 42, key = "shadowwordpain", cost = 305, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[10893] = { is = "ability", lvl = 50, key = "shadowwordpain", cost = 385, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[10894] = { is = "ability", lvl = 58, key = "shadowwordpain", cost = 470, spell = 6, dshare = 1.2, secs = 18, lasts = true, read = "dot -" }, -- Shadow Word: Pain
			[585] = { is = "ability", lvl = 1, key = "smite", cost = 20, spell = 2, share = 0.429, spec = "holy", read = "hit hit" }, -- Smite
			[591] = { is = "ability", lvl = 6, key = "smite", cost = 30, spell = 2, share = 0.571, spec = "holy", read = "hit hit" }, -- Smite
			[598] = { is = "ability", lvl = 14, key = "smite", cost = 60, spell = 2, share = 0.714, spec = "holy", read = "hit hit" }, -- Smite
			[984] = { is = "ability", lvl = 22, key = "smite", cost = 95, spell = 2, share = 0.714, spec = "holy", read = "hit hit" }, -- Smite
			[1004] = { is = "ability", lvl = 30, key = "smite", cost = 140, spell = 2, share = 0.714, spec = "holy", read = "hit hit" }, -- Smite
			[6060] = { is = "ability", lvl = 38, key = "smite", cost = 185, spell = 2, share = 0.714, spec = "holy", read = "hit hit" }, -- Smite
			[10933] = { is = "ability", lvl = 46, key = "smite", cost = 230, spell = 2, share = 0.714, spec = "holy", read = "hit hit" }, -- Smite
			[10934] = { is = "ability", lvl = 54, key = "smite", cost = 280, spell = 2, share = 0.714, spec = "holy", read = "hit hit" }, -- Smite
		},
		SHAMAN = {
			[408479] = { is = "ability", lvl = 32, key = "chainlightning", spell = 4, share = 0.357, aoe = true, spec = "caster", read = "hit hit - cap" }, -- Chain Lightning
			[408481] = { is = "ability", lvl = 40, key = "chainlightning", spell = 4, share = 0.357, aoe = true, spec = "caster", read = "hit hit - cap" }, -- Chain Lightning
			[408482] = { is = "ability", lvl = 48, key = "chainlightning", spell = 4, share = 0.357, aoe = true, spec = "caster", read = "hit hit - cap" }, -- Chain Lightning
			[408484] = { is = "ability", lvl = 56, key = "chainlightning", spell = 4, share = 0.357, aoe = true, spec = "caster", read = "hit hit - cap" }, -- Chain Lightning
			[8042] = { is = "ability", lvl = 4, key = "earthshock", cost = 30, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[8044] = { is = "ability", lvl = 8, key = "earthshock", cost = 50, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[8045] = { is = "ability", lvl = 14, key = "earthshock", cost = 85, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[8046] = { is = "ability", lvl = 24, key = "earthshock", cost = 145, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[10412] = { is = "ability", lvl = 36, key = "earthshock", cost = 240, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[10413] = { is = "ability", lvl = 48, key = "earthshock", cost = 345, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[10414] = { is = "ability", lvl = 60, key = "earthshock", cost = 450, cd = 6, spell = 4, share = 0.386, secs = 2, read = "hit hit -" }, -- Earth Shock
			[331] = { is = "heal:healingWave", lvl = 1, share = 0.429, base = 39, per = 0.7, from = 1, to = 5, read = "amount amount" }, -- Healing Wave
			[332] = { is = "heal:healingWave", lvl = 6, share = 0.571, base = 71, per = 1, from = 6, to = 11, read = "amount amount" }, -- Healing Wave
			[547] = { is = "heal:healingWave", lvl = 12, share = 0.714, base = 131, per = 1.5, from = 12, to = 17, read = "amount amount" }, -- Healing Wave
			[913] = { is = "heal:healingWave", lvl = 18, share = 0.857, base = 256, per = 2.3, from = 18, to = 23, read = "amount amount" }, -- Healing Wave
			[939] = { is = "heal:healingWave", lvl = 24, share = 0.857, base = 342, per = 2.7, from = 24, to = 29, read = "amount amount" }, -- Healing Wave
			[959] = { is = "heal:healingWave", lvl = 32, share = 0.857, base = 484, per = 3.3, from = 32, to = 37, read = "amount amount" }, -- Healing Wave
			[8005] = { is = "heal:healingWave", lvl = 40, share = 0.857, base = 685, per = 3.9, from = 40, to = 45, read = "amount amount" }, -- Healing Wave
			[10395] = { is = "heal:healingWave", lvl = 48, share = 0.857, base = 972, per = 4.7, from = 48, to = 53, read = "amount amount" }, -- Healing Wave
			[10396] = { is = "heal:healingWave", lvl = 56, share = 0.857, base = 1344, per = 5.5, from = 56, to = 61, read = "amount amount" }, -- Healing Wave
			[25357] = { is = "heal:healingWave", lvl = 60, share = 0.857, base = 1615, per = 5.5, from = 60, to = 65, read = "amount amount" }, -- Healing Wave
			[8004] = { is = "heal:lesserHealingWave", lvl = 20, share = 0.429, base = 153, per = 1.7, from = 20, to = 25, read = "amount amount" }, -- Lesser Healing Wave
			[8008] = { is = "heal:lesserHealingWave", lvl = 28, share = 0.429, base = 224, per = 2.1, from = 28, to = 33, read = "amount amount" }, -- Lesser Healing Wave
			[8010] = { is = "heal:lesserHealingWave", lvl = 36, share = 0.429, base = 304, per = 2.5, from = 36, to = 41, read = "amount amount" }, -- Lesser Healing Wave
			[10466] = { is = "heal:lesserHealingWave", lvl = 44, share = 0.429, base = 426, per = 3, from = 44, to = 49, read = "amount amount" }, -- Lesser Healing Wave
			[10467] = { is = "heal:lesserHealingWave", lvl = 52, share = 0.429, base = 608, per = 3.6, from = 52, to = 57, read = "amount amount" }, -- Lesser Healing Wave
			[10468] = { is = "heal:lesserHealingWave", lvl = 60, share = 0.429, base = 820, per = 4.2, from = 60, to = 65, read = "amount amount" }, -- Lesser Healing Wave
			[403] = { is = "ability", lvl = 1, key = "lightningbolt", cost = 15, spell = 4, share = 0.429, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[529] = { is = "ability", lvl = 8, key = "lightningbolt", cost = 30, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[548] = { is = "ability", lvl = 14, key = "lightningbolt", cost = 45, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[915] = { is = "ability", lvl = 20, key = "lightningbolt", cost = 60, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[943] = { is = "ability", lvl = 26, key = "lightningbolt", cost = 85, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[6041] = { is = "ability", lvl = 32, key = "lightningbolt", cost = 110, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[10391] = { is = "ability", lvl = 38, key = "lightningbolt", cost = 135, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[10392] = { is = "ability", lvl = 44, key = "lightningbolt", cost = 160, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[15207] = { is = "ability", lvl = 50, key = "lightningbolt", cost = 190, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[15208] = { is = "ability", lvl = 56, key = "lightningbolt", cost = 220, spell = 4, share = 0.714, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408439] = { is = "ability", lvl = 1, key = "lightningbolt", spell = 4, share = 0.2145, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408440] = { is = "ability", lvl = 8, key = "lightningbolt", spell = 4, share = 0.2855, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408441] = { is = "ability", lvl = 14, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408442] = { is = "ability", lvl = 20, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408443] = { is = "ability", lvl = 26, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408472] = { is = "ability", lvl = 32, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408473] = { is = "ability", lvl = 38, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408474] = { is = "ability", lvl = 44, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408475] = { is = "ability", lvl = 50, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[408477] = { is = "ability", lvl = 56, key = "lightningbolt", spell = 4, share = 0.357, spec = "caster", read = "hit hit" }, -- Lightning Bolt
			[17364] = { is = "ability", lvl = 40, key = "stormstrike", cd = 8, spec = "melee", weapon = "norm", read = "pct - -" }, -- Stormstrike
		},
		DRUID = {
			[1082] = { is = "ability", lvl = 20, key = "claw", cost = 45, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Claw
			[3029] = { is = "ability", lvl = 28, key = "claw", cost = 45, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Claw
			[5201] = { is = "ability", lvl = 38, key = "claw", cost = 45, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Claw
			[9849] = { is = "ability", lvl = 48, key = "claw", cost = 45, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Claw
			[9850] = { is = "ability", lvl = 58, key = "claw", cost = 45, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Claw
			[5229] = { is = "rage", lvl = 12, key = "enrage", cd = 60, every = 60, read = "rage more - - -" }, -- Enrage
			[22568] = { is = "ability", lvl = 32, key = "ferociousbite", cost = 35, finisher = true, spec = "cat", read = "- - p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Ferocious Bite
			[22827] = { is = "ability", lvl = 40, key = "ferociousbite", cost = 35, finisher = true, spec = "cat", read = "- - p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Ferocious Bite
			[22828] = { is = "ability", lvl = 48, key = "ferociousbite", cost = 35, finisher = true, spec = "cat", read = "- - p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Ferocious Bite
			[22829] = { is = "ability", lvl = 56, key = "ferociousbite", cost = 35, finisher = true, spec = "cat", read = "- - p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Ferocious Bite
			[31018] = { is = "ability", lvl = 60, key = "ferociousbite", cost = 35, finisher = true, spec = "cat", read = "- - p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Ferocious Bite
			[1328618] = { is = "ability", lvl = 24, key = "ferociousbite", cost = 35, finisher = true, spec = "cat", read = "- - p1 p1 - p2 p2 - p3 p3 - p4 p4 - p5 p5" }, -- Ferocious Bite
			[5185] = { is = "heal:healingTouch", lvl = 1, share = 0.429, base = 44, per = 0.8, from = 1, to = 5, read = "amount amount" }, -- Healing Touch
			[5186] = { is = "heal:healingTouch", lvl = 8, share = 0.571, base = 100, per = 1.3, from = 8, to = 13, read = "amount amount" }, -- Healing Touch
			[5187] = { is = "heal:healingTouch", lvl = 14, share = 0.714, base = 201, per = 1.9, from = 14, to = 19, read = "amount amount" }, -- Healing Touch
			[5188] = { is = "heal:healingTouch", lvl = 20, share = 0.857, base = 362, per = 2.7, from = 20, to = 25, read = "amount amount" }, -- Healing Touch
			[5189] = { is = "heal:healingTouch", lvl = 26, share = 1.0, base = 546, per = 3.5, from = 26, to = 31, read = "amount amount" }, -- Healing Touch
			[6778] = { is = "heal:healingTouch", lvl = 32, share = 1.0, base = 707, per = 4, from = 32, to = 37, read = "amount amount" }, -- Healing Touch
			[8903] = { is = "heal:healingTouch", lvl = 38, share = 1.0, base = 898, per = 4.5, from = 38, to = 43, read = "amount amount" }, -- Healing Touch
			[9758] = { is = "heal:healingTouch", lvl = 44, share = 1.0, base = 1173, per = 5.2, from = 44, to = 49, read = "amount amount" }, -- Healing Touch
			[9888] = { is = "heal:healingTouch", lvl = 50, share = 1.0, base = 1516, per = 5.9, from = 50, to = 55, read = "amount amount" }, -- Healing Touch
			[9889] = { is = "heal:healingTouch", lvl = 56, share = 1.0, base = 1920, per = 6.6, from = 56, to = 61, read = "amount amount" }, -- Healing Touch
			[25297] = { is = "heal:healingTouch", lvl = 60, share = 1.0, base = 2332, per = 7.3, from = 60, to = 65, read = "amount amount" }, -- Healing Touch
			[16914] = { is = "ability", lvl = 40, key = "hurricane", cost = 880, spell = 4, dshare = 0.3, secs = 10, aoe = true, channel = true, spec = "caster", read = "tick - - -" }, -- Hurricane
			[17401] = { is = "ability", lvl = 50, key = "hurricane", cost = 1180, spell = 4, dshare = 0.3, secs = 10, aoe = true, channel = true, spec = "caster", read = "tick - - -" }, -- Hurricane
			[17402] = { is = "ability", lvl = 60, key = "hurricane", cost = 1495, spell = 4, dshare = 0.3, secs = 10, aoe = true, channel = true, spec = "caster", read = "tick - - -" }, -- Hurricane
			[5570] = { is = "ability", lvl = 20, key = "insectswarm", cost = 45, spell = 4, dshare = 0.948, secs = 12, lasts = true, spec = "caster", read = "- dot -" }, -- Insect Swarm
			[24974] = { is = "ability", lvl = 30, key = "insectswarm", cost = 85, spell = 4, dshare = 0.948, secs = 12, lasts = true, spec = "caster", read = "- dot -" }, -- Insect Swarm
			[24975] = { is = "ability", lvl = 40, key = "insectswarm", cost = 100, spell = 4, dshare = 0.948, secs = 12, lasts = true, spec = "caster", read = "- dot -" }, -- Insect Swarm
			[24976] = { is = "ability", lvl = 50, key = "insectswarm", cost = 140, spell = 4, dshare = 0.948, secs = 12, lasts = true, spec = "caster", read = "- dot -" }, -- Insect Swarm
			[24977] = { is = "ability", lvl = 60, key = "insectswarm", cost = 160, spell = 4, dshare = 0.948, secs = 12, lasts = true, spec = "caster", read = "- dot -" }, -- Insect Swarm
			[6807] = { is = "ability", lvl = 10, key = "maul", cost = 15, threat = 0, tmult = 1.75, spec = "bear", swing = true, read = "add" }, -- Maul
			[6808] = { is = "ability", lvl = 18, key = "maul", cost = 15, spec = "bear", swing = true, read = "add" }, -- Maul
			[6809] = { is = "ability", lvl = 26, key = "maul", cost = 15, spec = "bear", swing = true, read = "add" }, -- Maul
			[8972] = { is = "ability", lvl = 34, key = "maul", cost = 15, spec = "bear", swing = true, read = "add" }, -- Maul
			[9745] = { is = "ability", lvl = 42, key = "maul", cost = 15, spec = "bear", swing = true, read = "add" }, -- Maul
			[9880] = { is = "ability", lvl = 50, key = "maul", cost = 15, spec = "bear", swing = true, read = "add" }, -- Maul
			[9881] = { is = "ability", lvl = 58, key = "maul", cost = 15, spec = "bear", swing = true, read = "add" }, -- Maul
			[8921] = { is = "ability", lvl = 4, key = "moonfire", cost = 25, spell = 7, share = 0.15, dshare = 0.39, secs = 9, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[8924] = { is = "ability", lvl = 10, key = "moonfire", cost = 50, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[8925] = { is = "ability", lvl = 16, key = "moonfire", cost = 75, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[8926] = { is = "ability", lvl = 22, key = "moonfire", cost = 105, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[8927] = { is = "ability", lvl = 28, key = "moonfire", cost = 150, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[8928] = { is = "ability", lvl = 34, key = "moonfire", cost = 190, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[8929] = { is = "ability", lvl = 40, key = "moonfire", cost = 235, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[9833] = { is = "ability", lvl = 46, key = "moonfire", cost = 280, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[9834] = { is = "ability", lvl = 52, key = "moonfire", cost = 325, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[9835] = { is = "ability", lvl = 58, key = "moonfire", cost = 375, spell = 7, share = 0.15, dshare = 0.52, secs = 12, lasts = true, spec = "caster", read = "hit hit dot -" }, -- Moonfire
			[1822] = { is = "ability", lvl = 24, key = "rake", cost = 40, secs = 9, lasts = true, points = 1, spec = "cat", read = "hit dot - -" }, -- Rake
			[1823] = { is = "ability", lvl = 34, key = "rake", cost = 40, secs = 9, lasts = true, points = 1, spec = "cat", read = "hit dot - -" }, -- Rake
			[1824] = { is = "ability", lvl = 44, key = "rake", cost = 40, secs = 9, lasts = true, points = 1, spec = "cat", read = "hit dot - -" }, -- Rake
			[9904] = { is = "ability", lvl = 54, key = "rake", cost = 40, secs = 9, lasts = true, points = 1, spec = "cat", read = "hit dot - -" }, -- Rake
			[8936] = { is = "heal:regrowth", lvl = 12, share = 0.286, base = 87, per = 1.8, from = 12, to = 17, read = "amount amount - -" }, -- Regrowth
			[8938] = { is = "heal:regrowth", lvl = 18, share = 0.286, base = 164, per = 2.5, from = 18, to = 23, read = "amount amount - -" }, -- Regrowth
			[8939] = { is = "heal:regrowth", lvl = 24, share = 0.286, base = 235, per = 3.1, from = 24, to = 29, read = "amount amount - -" }, -- Regrowth
			[8940] = { is = "heal:regrowth", lvl = 30, share = 0.286, base = 311, per = 3.6, from = 30, to = 35, read = "amount amount - -" }, -- Regrowth
			[8941] = { is = "heal:regrowth", lvl = 36, share = 0.286, base = 394, per = 4.1, from = 36, to = 41, read = "amount amount - -" }, -- Regrowth
			[9750] = { is = "heal:regrowth", lvl = 42, share = 0.286, base = 504, per = 4.7, from = 42, to = 47, read = "amount amount - -" }, -- Regrowth
			[9856] = { is = "heal:regrowth", lvl = 48, share = 0.286, base = 645, per = 5.3, from = 48, to = 53, read = "amount amount - -" }, -- Regrowth
			[9857] = { is = "heal:regrowth", lvl = 54, share = 0.286, base = 817, per = 6, from = 54, to = 59, read = "amount amount - -" }, -- Regrowth
			[9858] = { is = "heal:regrowth", lvl = 60, share = 0.286, base = 1021, per = 6.8, from = 60, to = 65, read = "amount amount - -" }, -- Regrowth
			[1079] = { is = "ability", lvl = 20, key = "rip", cost = 30, secs = 12, bleed = true, finisher = true, spec = "cat", read = "- r1 - - r2 - - r3 - - r4 - - r5 -" }, -- Rip
			[9492] = { is = "ability", lvl = 28, key = "rip", cost = 30, secs = 12, bleed = true, finisher = true, spec = "cat", read = "- r1 - - r2 - - r3 - - r4 - - r5 -" }, -- Rip
			[9493] = { is = "ability", lvl = 36, key = "rip", cost = 30, secs = 12, bleed = true, finisher = true, spec = "cat", read = "- r1 - - r2 - - r3 - - r4 - - r5 -" }, -- Rip
			[9752] = { is = "ability", lvl = 44, key = "rip", cost = 30, secs = 12, bleed = true, finisher = true, spec = "cat", read = "- r1 - - r2 - - r3 - - r4 - - r5 -" }, -- Rip
			[9894] = { is = "ability", lvl = 52, key = "rip", cost = 30, secs = 12, bleed = true, finisher = true, spec = "cat", read = "- r1 - - r2 - - r3 - - r4 - - r5 -" }, -- Rip
			[9896] = { is = "ability", lvl = 60, key = "rip", cost = 30, secs = 12, bleed = true, finisher = true, spec = "cat", read = "- r1 - - r2 - - r3 - - r4 - - r5 -" }, -- Rip
			[5221] = { is = "ability", lvl = 20, key = "shred", cost = 60, behind = true, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Shred
			[6800] = { is = "ability", lvl = 30, key = "shred", cost = 60, behind = true, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Shred
			[8992] = { is = "ability", lvl = 38, key = "shred", cost = 60, behind = true, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Shred
			[9829] = { is = "ability", lvl = 46, key = "shred", cost = 60, behind = true, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Shred
			[9830] = { is = "ability", lvl = 54, key = "shred", cost = 60, behind = true, points = 1, spec = "cat", weapon = "plain", read = "pct add -" }, -- Shred
			[2912] = { is = "ability", lvl = 20, key = "starfire", cost = 95, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[8949] = { is = "ability", lvl = 26, key = "starfire", cost = 135, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[8950] = { is = "ability", lvl = 34, key = "starfire", cost = 180, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[8951] = { is = "ability", lvl = 42, key = "starfire", cost = 230, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[9875] = { is = "ability", lvl = 50, key = "starfire", cost = 275, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[9876] = { is = "ability", lvl = 58, key = "starfire", cost = 315, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[25298] = { is = "ability", lvl = 60, key = "starfire", cost = 340, spell = 7, share = 1.0, spec = "caster", read = "hit hit" }, -- Starfire
			[769] = { is = "ability", lvl = 34, key = "swipe", cost = 20, aoe = true, spec = "bear", read = "cap hit" }, -- Swipe
			[779] = { is = "ability", lvl = 16, key = "swipe", cost = 20, threat = 0, tmult = 1.75, aoe = true, spec = "bear", read = "cap hit" }, -- Swipe
			[780] = { is = "ability", lvl = 24, key = "swipe", cost = 20, aoe = true, spec = "bear", read = "cap hit" }, -- Swipe
			[9754] = { is = "ability", lvl = 44, key = "swipe", cost = 20, aoe = true, spec = "bear", read = "cap hit" }, -- Swipe
			[9908] = { is = "ability", lvl = 54, key = "swipe", cost = 20, aoe = true, spec = "bear", read = "cap hit" }, -- Swipe
			[5176] = { is = "ability", lvl = 1, key = "wrath", cost = 10, spell = 4, share = 0.429, spec = "caster", read = "hit hit" }, -- Wrath
			[5177] = { is = "ability", lvl = 6, key = "wrath", cost = 20, spell = 4, share = 0.486, spec = "caster", read = "hit hit" }, -- Wrath
			[5178] = { is = "ability", lvl = 14, key = "wrath", cost = 40, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Wrath
			[5179] = { is = "ability", lvl = 22, key = "wrath", cost = 50, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Wrath
			[5180] = { is = "ability", lvl = 30, key = "wrath", cost = 70, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Wrath
			[6780] = { is = "ability", lvl = 38, key = "wrath", cost = 80, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Wrath
			[8905] = { is = "ability", lvl = 46, key = "wrath", cost = 100, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Wrath
			[9912] = { is = "ability", lvl = 54, key = "wrath", cost = 120, spell = 4, share = 0.571, spec = "caster", read = "hit hit" }, -- Wrath
		},
	},
	-- class -> way of fighting -> how it is priced, and the talents that mark it
	specs = {
		SHAMAN = {
			melee = { mana = true, marks = { [16255] = true, [16256] = true, [16268] = true, [16269] = true, [17364] = true, [29082] = true, [29084] = true, [29086] = true, [29087] = true, [29088] = true } },
			caster = { caster = true, marks = { [16035] = true, [16039] = true, [16089] = true, [16120] = true, [16164] = true, [16166] = true, [16579] = true, [16580] = true, [16581] = true, [16582] = true } },
		},
		PRIEST = {
			holy = { caster = true, marks = { [14889] = true, [14898] = true, [14901] = true, [14908] = true, [14909] = true, [14912] = true, [18530] = true, [18544] = true, [18547] = true, [18548] = true, [18549] = true, [18550] = true, [20711] = true } },
			shadow = { caster = true, marks = { [15257] = true, [15259] = true, [15260] = true, [15268] = true, [15273] = true, [15275] = true, [15286] = true, [15318] = true, [15323] = true, [15324] = true, [15325] = true, [15326] = true, [15473] = true } },
		},
		DRUID = {
			caster = { caster = true, marks = { [16814] = true, [16821] = true, [16845] = true, [16850] = true, [16880] = true, [16896] = true, [16909] = true, [24858] = true } },
			cat = { energy = true, form = "cat", marks = { [16858] = true, [16859] = true, [16860] = true, [16861] = true, [16862] = true, [16942] = true, [16958] = true, [16966] = true, [16968] = true, [16972] = true, [16998] = true, [17003] = true, [17007] = true } },
			bear = { form = "bear", tank = true, marks = {  } },
		},
	},
	-- a passive's id -> what it does to the crits of which abilities
	talents = {
		WARRIOR = {
			[12290] = { crit = 25, nth = 1, of = "improvedoverpower", keys = { overpower = true } }, -- Improved Overpower
			[12963] = { crit = 50, nth = 1, of = "improvedoverpower", keys = { overpower = true } }, -- Improved Overpower
			[16493] = { more = 10, nth = 1, of = "impale", keys = { bloodthirst = true, cleave = true, execute = true, heroicstrike = true, mortalstrike = true, overpower = true, rend = true, revenge = true, shieldslam = true, slam = true, sunderarmor = true, thunderclap = true, whirlwind = true } }, -- Impale
		},
		MAGE = {
			[11108] = { crit = 15, nth = 1, of = "improvedflamestrike", keys = { flamestrike = true } }, -- Improved Flamestrike
			[11115] = { crit = 2, nth = 1, of = "criticalmass", keys = { blastwave = true, fireball = true, fireblast = true, flamestrike = true, frostfirebolt = true, pyroblast = true, scorch = true } }, -- Critical Mass
			[11119] = { after = 40, nth = 1, of = "ignite", keys = { blastwave = true, fireball = true, fireblast = true, flamestrike = true, frostfirebolt = true, pyroblast = true, scorch = true } }, -- Ignite
			[11207] = { more = 100, nth = 1, of = "iceshards", keys = { blizzard = true, coneofcold = true, frostbolt = true, frostfirebolt = true, frostnova = true, icelance = true } }, -- Ice Shards
			[11232] = { more = 100, nth = 2, of = "arcanemind", keys = { arcaneblast = true, arcaneexplosion = true } }, -- Arcane Mind
			[11242] = { crit = 6, nth = 1, of = "arcaneimpact", keys = { arcaneblast = true, arcaneexplosion = true } }, -- Arcane Impact
			[18459] = { crit = 6, nth = 1, of = "incineration", keys = { arcaneblast = true, fireblast = true, icelance = true, scorch = true } }, -- Incineration
		},
		ROGUE = {
			[14079] = { crit = 45, nth = 1, of = "improvedambush", keys = { ambush = true } }, -- Improved Ambush
			[14128] = { more = 6, nth = 1, of = "lethality", keys = { backstab = true, ghostlystrike = true, hemorrhage = true, sinisterstrike = true } }, -- Lethality
			[1224716] = { crit = 30, nth = 1, of = "puncturingwounds", keys = { backstab = true } }, -- Puncturing Wounds
		},
		HUNTER = {
			[19485] = { more = 30, nth = 1, of = "mortalshots", keys = { aimedshot = true, arcaneshot = true, multishot = true, serpentsting = true, snipershot = true, volley = true } }, -- Mortal Shots
		},
		WARLOCK = {
			[17927] = { crit = 10, nth = 1, of = "agonizingflames", keys = { searingpain = true } }, -- Agonizing Flames
			[17959] = { more = 100, nth = 1, of = "ruin", keys = { immolate = true, incinerate = true, rainoffire = true, searingpain = true, shadowbolt = true, shadowburn = true, soulfire = true } }, -- Ruin
			[18130] = { crit = 5, nth = 1, of = "devastation", keys = { immolate = true, incinerate = true, rainoffire = true, searingpain = true, shadowbolt = true, shadowburn = true, soulfire = true } }, -- Devastation
		},
		PRIEST = {
			[14889] = { crit = 1, nth = 1, of = "holyspecialization", keys = { holyfire = true, smite = true } }, -- Holy Specialization
			[15473] = { more = 100, nth = 3, of = "shadowform", spec = "shadow", keys = { devouringplague = true, mindblast = true, mindflay = true, shadowwordpain = true } }, -- Shadowform
			[18544] = { crit = 1, nth = 2, of = "forceofwill", keys = { holyfire = true, mindblast = true, smite = true } }, -- Force of Will
			[18547] = { crit = 2, nth = 2, of = "forceofwill", keys = { holyfire = true, mindblast = true, smite = true } }, -- Force of Will
			[18548] = { crit = 3, nth = 2, of = "forceofwill", keys = { holyfire = true, mindblast = true, smite = true } }, -- Force of Will
			[18549] = { crit = 4, nth = 2, of = "forceofwill", keys = { holyfire = true, mindblast = true, smite = true } }, -- Force of Will
			[18550] = { crit = 5, nth = 1, of = "forceofwill", keys = { holyfire = true, mindblast = true, smite = true } }, -- Force of Will
		},
		SHAMAN = {
			[16089] = { more = 100, nth = 1, of = "elementalfury", keys = { chainlightning = true, earthshock = true, lightningbolt = true } }, -- Elemental Fury
			[16120] = { crit = 5, nth = 1, of = "callofthunder", keys = { chainlightning = true, lightningbolt = true } }, -- Call of Thunder
		},
		DRUID = {
			[16821] = { crit = 2, nth = 1, of = "improvedmoonfire", keys = { moonfire = true } }, -- Improved Moonfire
			[16909] = { more = 20, nth = 1, of = "vengeance", keys = { hurricane = true, insectswarm = true, moonfire = true, starfire = true, wrath = true } }, -- Vengeance
		},
	},
	-- aura id -> the stats it raises, by percent (MOD_TOTAL_STAT_PERCENTAGE)
	stats = {
		[11232] = { strength = 10 }, -- Arcane Mind
		[16252] = { strength = 2 }, -- Toughness
		[17003] = { strength = 10 }, -- Heart of the Wild
		[17485] = { strength = 10 }, -- Ancestral Knowledge
		[18551] = { strength = 15 }, -- Mental Strength
		[18697] = { strength = 15 }, -- Demonic Embrace
		[19168] = { strength = 15 }, -- Lightning Reflexes
		[20217] = { all = 10 }, -- Blessing of Kings
		[20257] = { strength = 2 }, -- Divine Intellect
		[20262] = { strength = 2 }, -- Divine Strength
		[20598] = { spirit = 10 }, -- The Human Spirit
		[24425] = { all = 15 }, -- Spirit of Zandalar
		[25898] = { all = 10 }, -- Greater Blessing of Kings
		[29140] = { stamina = 10 }, -- Vitality
		[355365] = { all = 15 }, -- Spirit of Zandalar
		[370552] = { all = 5 }, -- Skeletal Artifact
		[409580] = { all = 10 }, -- Heart of the Lion
		[409583] = { all = 10 }, -- Heart of the Lion
		[429836] = { spirit = 5 }, -- Anointed By Light
		[430420] = { intellect = 5 }, -- Anointed By Elune
		[430421] = { stamina = 5 }, -- Anointed By The Loa
		[439734] = { strength = 25 }, -- Tree of Life (Passive)
		[446695] = { all = 8 }, -- Fervor of the Temple Explorer
		[446698] = { all = 8 }, -- Fervor of the Temple Explorer
		[459610] = { all = 15 }, -- Wanderer's Resolve
		[459611] = { all = 15 }, -- Astral Victory
		[473403] = { stamina = 15 }, -- Blessing of Neptulon
		[473476] = { all = 15 }, -- Dreams of Zandalar
		[1213408] = { all = 10 }, -- Blessing of Kings
		[1230098] = { all = 8 }, -- Boosted Stats
		[1248751] = { strength = 5 }, -- Increased Spirit
		[1286254] = { all = 10 }, -- (DNT) Blessing of Kings - TEST RAID SPELL
		[1304753] = { stamina = 15 }, -- Mol'dar's Moxie
		[1309631] = { strength = 15 }, -- Living Spirit
		[1326168] = { strength = 15 }, -- Dark Inspiration
	},
	-- weapon's item id -> { what its "Chance on hit" does in damage, whether it is magic }
	procs = {
		[754] = { 30, true }, -- Holy Smite
		[809] = { 155, false }, -- Rend
		[810] = { 50, true }, -- Frostbolt
		[811] = { 126, true }, -- Wrath
		[870] = { 322, true }, -- Fireball
		[899] = { 15, true }, -- Poison
		[937] = { 125, true }, -- Shadow Bolt
		[1263] = { 250, false }, -- Brain Hacker
		[1265] = { 65, true }, -- Poison
		[1318] = { 84, true }, -- Shadow Bolt
		[1387] = { 100, true }, -- Shadow Bolt
		[1481] = { 42, true }, -- Shadow Bolt
		[1482] = { 42, true }, -- Shadow Bolt
		[1726] = { 150, true }, -- Poison
		[1728] = { 140, true }, -- Firebolt
		[1982] = { 231, true }, -- Shadow Bolt
		[1986] = { 102, false }, -- Wound
		[2000] = { 85, true }, -- Arcane Blast
		[2099] = { 49, true }, -- Flaming Cannonball
		[2163] = { 125, true }, -- Shadow Bolt
		[2164] = { 105, false }, -- Wound
		[2205] = { 98, true }, -- Shadow Bolt
		[2256] = { 30, true }, -- Shadow Bolt
		[2263] = { 35, true }, -- Lightning Bolt
		[2291] = { 500, false }, -- Rend
		[2299] = { 116, true }, -- Fireball
		[2825] = { 28, true }, -- Searing Arrow
		[2912] = { 35, true }, -- Shadow Bolt
		[2915] = { 400, true }, -- Fireball
		[2942] = { 25, false }, -- Pummel
		[3078] = { 42, false }, -- Pierce Heart
		[3194] = { 70, true }, -- Shadow Bolt
		[3278] = { 84, true }, -- Gahz'rilla Fang
		[3336] = { 30, false }, -- Rend
		[3687] = { 460, true }, -- Blight
		[3687] = { 60, true }, -- Firebolt
		[3687] = { 63, true }, -- Fireball
		[3822] = { 35, true }, -- Shadow Bolt
		[3854] = { 50, true }, -- Frostbolt
		[4446] = { 25, true }, -- Poison
		[4449] = { 30, true }, -- Poison
		[4985] = { 24, true }, -- Shock
		[5182] = { 50, true }, -- Frost Blast
		[5426] = { 45, true }, -- Poison
		[5616] = { 77, false }, -- Rend
		[5752] = { 30, true }, -- Poison
		[5756] = { 63, true }, -- Frost Blast
		[5815] = { 75, true }, -- Frost Blast
		[6220] = { 42, true }, -- Firebolt
		[6469] = { 28, true }, -- Venom Shot
		[6472] = { 28, true }, -- Poison
		[6681] = { 45, false }, -- Thornspike
		[6738] = { 85, false }, -- Rend
		[6831] = { 77, true }, -- Shadow Bolt
		[6904] = { 42, true }, -- Poison
		[6909] = { 28, true }, -- Corrosive Poison
		[6953] = { 49, true }, -- Holy Forgefire
		[7710] = { 91, false }, -- Tough Love
		[7730] = { 133, true }, -- Frost Blast
		[7753] = { 250, false }, -- Rend
		[7959] = { 460, true }, -- Blight
		[8006] = { 15, true }, -- Lightning Bolt
		[8190] = { 75, false }, -- Wound
		[8224] = { 85, false }, -- Rend
		[8225] = { 63, true }, -- Corruption
		[8708] = { 112, false }, -- Forging Strike
		[9372] = { 318, true }, -- Rage of Sul'thraze
		[9386] = { 63, true }, -- Fireball
		[9412] = { 28, true }, -- Fire Blast
		[9418] = { 196, false }, -- Strength of Stone
		[9425] = { 311, false }, -- Fatal Wound
		[9446] = { 28, true }, -- Lightning Bolt
		[9453] = { 56, true }, -- Poison Cloud
		[9467] = { 84, true }, -- Gahz'rilla Fang
		[9475] = { 174, false }, -- Fatal Wound
		[9477] = { 294, false }, -- Farraki Enforcement
		[9478] = { 70, false }, -- Wound
		[9486] = { 105, true }, -- Lightning Bolt
		[9511] = { 77, false }, -- Wound
		[9639] = { 42, true }, -- Thunder Clap
		[9651] = { 91, true }, -- Lightning Bolt
		[10567] = { 33, true }, -- Quill Shot
		[10623] = { 50, true }, -- Frostbolt
		[10627] = { 126, false }, -- Bludgeon
		[10628] = { 159, false }, -- Fatal Wound
		[10758] = { 42, true }, -- Holy Cleaver
		[10761] = { 42, true }, -- Frostbolt
		[10772] = { 70, false }, -- Rend
		[10797] = { 91, true }, -- Fireball
		[10803] = { 90, true }, -- Corruption
		[11121] = { 28, true }, -- Shadow Bolt
		[11603] = { 225, false }, -- Wound
		[11635] = { 91, true }, -- Corrosive Poison
		[11744] = { 35, false }, -- Wound
		[11803] = { 182, true }, -- Firebolt
		[11809] = { 154, true }, -- Flame Wrath
		[11816] = { 109, false }, -- Slaughter
		[11902] = { 98, true }, -- Lightning Bolt
		[12243] = { 189, true }, -- Fireball
		[12250] = { 30, true }, -- Shadow Bolt
		[12463] = { 161, false }, -- Rend
		[12531] = { 56, true }, -- Searing Blast
		[12582] = { 100, true }, -- Numbing Pain
		[12583] = { 448, false }, -- Fatal Wound
		[12777] = { 200, true }, -- Blaze
		[12791] = { 98, false }, -- Rend
		[12792] = { 264, true }, -- Fireball
		[12794] = { 125, true }, -- Chain Lightning
		[12795] = { 100, false }, -- Rend
		[12969] = { 255, true }, -- Seeping Willow
		[12974] = { 40, true }, -- Shadow Bolt
		[12992] = { 98, true }, -- Fireball
		[13016] = { 100, false }, -- Rend
		[13032] = { 30, true }, -- Corruption
		[13035] = { 80, true }, -- Poison
		[13051] = { 150, true }, -- Shadow Bolt
		[13053] = { 231, true }, -- Shadow Bolt
		[13054] = { 130, false }, -- Wound
		[13057] = { 98, false }, -- Rend
		[13060] = { 75, false }, -- Wound
		[13146] = { 38.5, true }, -- Flaming Shell
		[13148] = { 205, true }, -- Frost Blast
		[13183] = { 105, true }, -- Poison
		[13262] = { 700, true }, -- Firebolt
		[13285] = { 230, false }, -- Wound
		[13348] = { 252, true }, -- Shadow Bolt
		[13361] = { 210, true }, -- Skullforge Brand
		[13399] = { 140, false }, -- Rend
		[13408] = { 100, true }, -- Soul Breaker
		[13952] = { 105, true }, -- Frostbolt
		[13983] = { 168, true }, -- Creeping Mold
		[13984] = { 105, true }, -- Frost Blast
		[14487] = { 105, true }, -- Frost Blast
		[14531] = { 105, true }, -- Weakening Disease
		[14541] = { 245, true }, -- Siphon Health
		[14555] = { 105, true }, -- Firebolt
		[14576] = { 84, true }, -- Corruption
		[15418] = { 252, true }, -- Lightning Bolt
		[15814] = { 80, false }, -- Rend
		[15853] = { 105, true }, -- Windreaper
		[16004] = { 26, true }, -- Shadow Shot
		[17002] = { 80, true }, -- Poison
		[17054] = { 84, true }, -- Arcane Blast
		[17068] = { 140, true }, -- Shadow Bolt
		[17071] = { 75, true }, -- Gutgore Ripper
		[17075] = { 236, false }, -- Fatal Wound
		[17182] = { 378, true }, -- Fireball
		[17193] = { 108, true }, -- Fireball
		[17223] = { 200, true }, -- Chain Lightning
		[17704] = { 30, true }, -- Frost Blast
		[17730] = { 210, false }, -- Rend
		[17738] = { 91, true }, -- Poison
		[17752] = { 70, true }, -- Shadow Bolt
		[17753] = { 28, true }, -- Keeper's Sting
		[17766] = { 168, false }, -- Wound
		[17802] = { 300, true }, -- Thunderfury
		[18202] = { 105, false }, -- Eskhandar's Rake
		[18324] = { 70, true }, -- Waveslicer
		[18388] = { 49, false }, -- Stoneshatter
		[18498] = { 42, true }, -- Hedgecutter
		[18538] = { 175, true }, -- Treant Slayer
		[18671] = { 90, true }, -- Firebolt
		[18755] = { 42, true }, -- Xorothian Fire
		[18816] = { 48, true }, -- Firebolt
		[18881] = { 378, true }, -- Fireball
		[19019] = { 300, true }, -- Thunderfury
		[19099] = { 45, true }, -- Frost Blast
		[19100] = { 45, true }, -- Lightning Bolt
		[19158] = { 378, true }, -- Fireball
		[19170] = { 231, true }, -- Shadow Bolt
		[19324] = { 250, true }, -- Brain Damage
		[19353] = { 240, false }, -- Fatal Wound
		[19901] = { 84, true }, -- Zulian Slice
		[19908] = { 78, true }, -- Serpent's Hiss
		[19910] = { 70, true }, -- Shadow Bolt
		[19918] = { 210, false }, -- Jeklik's Crushing Blow
		[20578] = { 96, true }, -- Acid Blast
		[21679] = { 258, true }, -- Shock
		[204807] = { 50, true }, -- Fathomblast
		[209436] = { 42, true }, -- Poison
		[209525] = { 30, true }, -- Shadow Bolt
		[209526] = { 30, true }, -- Shadow Bolt
		[209562] = { 120, true }, -- Ancient Corrosive Poison
		[209579] = { 15, true }, -- Crashing Thunder
		[209580] = { 15, true }, -- Gusting Wind
		[211944] = { 212, true }, -- Blast Wave
		[213286] = { 30, true }, -- Electrocutioner's Shock
		[213291] = { 90, true }, -- Poison Cloud
		[213296] = { 90, true }, -- Lightning Bolt
		[213409] = { 30, true }, -- Mekkatorque's Arcano-Shredder
		[220566] = { 189, true }, -- Fireball
		[220583] = { 90, true }, -- Corruption
		[220584] = { 91, true }, -- Fireball
		[220589] = { 50, true }, -- Sting of the Serpent
		[223526] = { 275, true }, -- Sul'thraze
		[223527] = { 84, true }, -- Gahz'rilla Fang
		[224409] = { 50, true }, -- Sting of the Serpent
		[227683] = { 378, true }, -- Purged by Fire
		[227684] = { 108, true }, -- Fireball
		[227842] = { 231, true }, -- Shadow Bolt
		[227886] = { 125, true }, -- Chain Lightning
		[227887] = { 30, true }, -- Frost Nova
		[227934] = { 150, true }, -- Flame Wrath
		[227993] = { 84, true }, -- Corruption
		[227994] = { 105, true }, -- Weakening Disease
		[227997] = { 245, true }, -- Siphon Health
		[228029] = { 168, true }, -- Creeping Mold
		[228139] = { 70, true }, -- Fire Blast
		[228267] = { 150, true }, -- Gutgore Ripper
		[228273] = { 250, true }, -- Chain Lightning
		[228296] = { 110, true }, -- Firebolt
		[228349] = { 105, false }, -- Eskhandar's Rake
		[228511] = { 110, true }, -- Firebolt
		[228542] = { 210, true }, -- Skullforge Brand
		[228573] = { 105, true }, -- Poison
		[228586] = { 205, true }, -- Frost Blast
		[228603] = { 448, false }, -- Fatal Wound
		[228666] = { 255, true }, -- Seeping Willow
		[229372] = { 150, true }, -- Gutgore Ripper
		[229374] = { 70, true }, -- Fire Blast
		[229381] = { 250, true }, -- Chain Lightning
		[230224] = { 300, true }, -- Thunderfury
		[230271] = { 300, false }, -- Fatal Wound
		[230911] = { 210, false }, -- Jeklik's Crushing Blow
		[230930] = { 84, true }, -- Zulian Slice
		[230934] = { 100, true }, -- Shadow Bolt
		[231016] = { 200, false }, -- Fish Terminator
		[231848] = { 200, false }, -- Fish Terminator
		[231851] = { 100, true }, -- Shadow Bolt
		[231861] = { 210, false }, -- Jeklik's Crushing Blow
		[231876] = { 84, true }, -- Zulian Slice
		[231887] = { 100, false }, -- Rend
		[232562] = { 300, false }, -- Fatal Wound
		[233621] = { 358, true }, -- Shock
		[233797] = { 125, true }, -- Chain Lightning
		[234172] = { 96, true }, -- Acid Blast
		[234981] = { 358, true }, -- Shock
		[241082] = { 700, true }, -- Firebolt
		[241121] = { 110, true }, -- Firebolt
		[241123] = { 110, true }, -- Firebolt
		[260186] = { 140, true }, -- Shadow Bolt
		[267369] = { 49, true }, -- Blazewind Blast
		[272999] = { 14, false }, -- Wound
		[273819] = { 70, false }, -- Wound
		[273841] = { 70, true }, -- Lightning Bolt
		[274265] = { 63, true }, -- Grass Killer
		[274270] = { 126, true }, -- Grass Killer
		[274271] = { 63, true }, -- Grass Killer
		[274293] = { 36, false }, -- Spellsever
		[274484] = { 168, false }, -- Wound
		[274952] = { 98, false }, -- Bolder'ok Boulder
		[274963] = { 168, true }, -- Rot
		[275439] = { 56, true }, -- Blunderflame
		[275441] = { 56, true }, -- Cremate
		[276419] = { 105, true }, -- Smite
		[278217] = { 126, true }, -- Rotcleaver
		[278219] = { 105, true }, -- Storm Shot
		[278224] = { 84, true }, -- Yjn'raathma, Sword of the Still Wind
		[278461] = { 61, true }, -- Skyshatter
		[278665] = { 70, true }, -- Riftbite
		[278957] = { 54, true }, -- Buriza-Do Spike
		[279480] = { 140, false }, -- Bigger Rock to the Face
		[279852] = { 70, false }, -- Rock to the Face
		[279876] = { 20, true }, -- Poison
		[279895] = { 42, true }, -- Firebolt
		[280206] = { 168, true }, -- Light in the Dark
		[280207] = { 70, true }, -- Split
		[281665] = { 51, true }, -- Forge Blast
		[282551] = { 85, false }, -- Wound
		[282561] = { 21, true }, -- Burning Shell
		[282632] = { 70, true }, -- Fire Blast
		[282700] = { 33, true }, -- Shadow Bolt Volley
		[282703] = { 21, false }, -- Puncture
		[284050] = { 81, true }, -- Poison Sting
		[284386] = { 84, true }, -- Fire Blast
		[284667] = { 165, true }, -- Immolate
		[285102] = { 24, true }, -- Poison
		[285332] = { 90, false }, -- Puncture
		[286430] = { 42, false }, -- Toofbreak
		[286537] = { 23, true }, -- Thunderstomp
		[286650] = { 90, true }, -- Ablaze
		[287005] = { 670, false }, -- Dismember
		[288907] = { 75, true }, -- Gutgore Ripper
		[288909] = { 48, true }, -- Firebolt
		[289294] = { 300, true }, -- Thunderfury
		[289295] = { 378, true }, -- Fireball
	},
	-- item id -> what its "Use:" gives, as stats, for the share of the time it can be up
	uses = {
		[1912] = { ITEM_MOD_INTELLECT_SHORT = 2 },
		[18820] = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 29.17, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 29.17 },
		[20636] = { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 58.33 },
		[23042] = { RESISTANCE2_NAME = 6.67, RESISTANCE3_NAME = 6.67, RESISTANCE4_NAME = 6.67, RESISTANCE5_NAME = 6.67, RESISTANCE6_NAME = 6.67 },
		[23046] = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 21.67, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 21.67 },
		[23047] = { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 112.5 },
		[270226] = { ITEM_MOD_AGILITY_SHORT = 0.8, ITEM_MOD_INTELLECT_SHORT = 0.8, ITEM_MOD_SPIRIT_SHORT = 0.8, ITEM_MOD_STAMINA_SHORT = 0.8, ITEM_MOD_STRENGTH_SHORT = 0.8 },
		[272439] = { ITEM_MOD_SPIRIT_SHORT = 3 },
		[272440] = { ITEM_MOD_BLOCK_RATING_SHORT = 1.67 },
		[274386] = { ITEM_MOD_DODGE_RATING_SHORT = 2.4 },
	},
	-- item id -> the Defense its "Equip:" gives
	defense = {
	},
	-- items with an effect that is not counted: the tooltip says so
	partly = {
		[744]=1, [941]=1, [996]=1, [997]=1, [1122]=1, [1123]=1, [1124]=1, [1125]=1, [1131]=1, [1184]=1, [1186]=1, [1258]=1,
		[1350]=1, [1403]=1, [1444]=1, [1472]=1, [1544]=1, [1622]=1, [1700]=1, [1854]=1, [1914]=1, [2012]=1, [2478]=1, [2803]=1,
		[2804]=1, [2808]=1, [2820]=1, [2826]=1, [2948]=1, [3015]=1, [4130]=1, [4248]=1, [4262]=1, [4264]=1, [4328]=1, [4381]=1,
		[4396]=1, [4397]=1, [4491]=1, [4704]=1, [4750]=1, [4760]=1, [4762]=1, [4956]=1, [4984]=1, [5079]=1, [5230]=1, [5231]=1,
		[5323]=1, [5408]=1, [5409]=1, [5613]=1, [6182]=1, [6698]=1, [6707]=1, [6708]=1, [6711]=1, [6724]=1, [6728]=1, [6898]=1,
		[6972]=1, [7052]=1, [7133]=1, [7148]=1, [7189]=1, [7284]=1, [7297]=1, [7344]=1, [7375]=1, [7391]=1, [7506]=1, [7507]=1,
		[7508]=1, [7515]=1, [7936]=1, [7939]=1, [7953]=1, [7954]=1, [7960]=1, [7961]=1, [8197]=1, [8345]=1, [8346]=1, [8348]=1,
		[8367]=1, [8688]=1, [8703]=1, [9380]=1, [9978]=1, [10030]=1, [10036]=1, [10418]=1, [10501]=1, [10506]=1, [10515]=1, [10518]=1,
		[10543]=1, [10576]=1, [10577]=1, [10587]=1, [10588]=1, [10645]=1, [10696]=1, [10697]=1, [10698]=1, [10716]=1, [10720]=1, [10721]=1,
		[10724]=1, [10725]=1, [10726]=1, [10727]=1, [11170]=1, [11522]=1, [11607]=1, [11608]=1, [11861]=1, [11905]=1, [12185]=1, [12443]=1,
		[12631]=1, [12632]=1, [12639]=1, [12641]=1, [12769]=1, [12781]=1, [12790]=1, [12796]=1, [12797]=1, [12798]=1, [12802]=1, [12805]=1,
		[12846]=1, [13164]=1, [13289]=1, [13347]=1, [13503]=1, [14134]=1, [14152]=1, [14153]=1, [14154]=1, [15107]=1, [15108]=1, [15138]=1,
		[15866]=1, [16009]=1, [16022]=1, [16391]=1, [16392]=1, [16397]=1, [16403]=1, [16406]=1, [16410]=1, [16440]=1, [16446]=1, [16448]=1,
		[16463]=1, [16471]=1, [16484]=1, [16487]=1, [16496]=1, [16498]=1, [16510]=1, [16518]=1, [16530]=1, [16540]=1, [16548]=1, [16555]=1,
		[16558]=1, [16571]=1, [16573]=1, [16768]=1, [16787]=1, [17073]=1, [17111]=1, [17142]=1, [17182]=1, [17223]=1, [17564]=1, [17577]=1,
		[17584]=1, [17588]=1, [17596]=1, [17608]=1, [17617]=1, [17620]=1, [17690]=1, [17691]=1, [17733]=1, [17759]=1, [17782]=1, [17783]=1,
		[17900]=1, [17901]=1, [17902]=1, [17903]=1, [17904]=1, [17905]=1, [17906]=1, [17907]=1, [17908]=1, [17909]=1, [18161]=1, [18162]=1,
		[18163]=1, [18164]=1, [18165]=1, [18168]=1, [18355]=1, [18406]=1, [18582]=1, [18583]=1, [18587]=1, [18608]=1, [18609]=1, [18634]=1,
		[18637]=1, [18638]=1, [18639]=1, [18646]=1, [18706]=1, [18801]=1, [18815]=1, [18825]=1, [18826]=1, [18834]=1, [18845]=1, [18846]=1,
		[18849]=1, [18850]=1, [18851]=1, [18852]=1, [18853]=1, [18854]=1, [18856]=1, [18857]=1, [18858]=1, [18859]=1, [18862]=1, [18863]=1,
		[18864]=1, [18881]=1, [18882]=1, [18951]=1, [18971]=1, [19024]=1, [19120]=1, [19141]=1, [19158]=1, [19166]=1, [19169]=1, [19287]=1,
		[19288]=1, [19289]=1, [19290]=1, [19323]=1, [19336]=1, [19337]=1, [19339]=1, [19340]=1, [19341]=1, [19342]=1, [19343]=1, [19344]=1,
		[19345]=1, [19577]=1, [19588]=1, [19594]=1, [19601]=1, [19605]=1, [19609]=1, [19613]=1, [19617]=1, [19621]=1, [19948]=1, [19949]=1,
		[19950]=1, [19951]=1, [19952]=1, [19953]=1, [19954]=1, [19955]=1, [19956]=1, [19957]=1, [19958]=1, [19959]=1, [19979]=1, [19986]=1,
		[19998]=1, [20005]=1, [20048]=1, [20049]=1, [20050]=1, [20051]=1, [20052]=1, [20053]=1, [20054]=1, [20071]=1, [20072]=1, [20084]=1,
		[20091]=1, [20092]=1, [20093]=1, [20094]=1, [20095]=1, [20096]=1, [20100]=1, [20101]=1, [20102]=1, [20109]=1, [20110]=1, [20111]=1,
		[20112]=1, [20113]=1, [20114]=1, [20121]=1, [20122]=1, [20123]=1, [20127]=1, [20128]=1, [20129]=1, [20154]=1, [20155]=1, [20156]=1,
		[20157]=1, [20159]=1, [20160]=1, [20161]=1, [20162]=1, [20167]=1, [20168]=1, [20169]=1, [20170]=1, [20181]=1, [20182]=1, [20183]=1,
		[20185]=1, [20186]=1, [20187]=1, [20188]=1, [20189]=1, [20199]=1, [20200]=1, [20201]=1, [20202]=1, [20208]=1, [20209]=1, [20210]=1,
		[20211]=1, [20422]=1, [20451]=1, [20525]=1, [21115]=1, [21116]=1, [21117]=1, [21118]=1, [21119]=1, [21120]=1, [21134]=1, [21180]=1,
		[21181]=1, [21190]=1, [21326]=1, [21473]=1, [21488]=1, [21517]=1, [21526]=1, [21565]=1, [21566]=1, [21579]=1, [21625]=1, [21647]=1,
		[21670]=1, [21685]=1, [21891]=1, [22003]=1, [22013]=1, [22015]=1, [22060]=1, [22061]=1, [22191]=1, [22194]=1, [22196]=1, [22198]=1,
		[22206]=1, [22396]=1, [22399]=1, [22402]=1, [22589]=1, [22630]=1, [22631]=1, [22632]=1, [22678]=1, [22856]=1, [22857]=1, [22862]=1,
		[22863]=1, [22865]=1, [22868]=1, [22869]=1, [22870]=1, [22954]=1, [23001]=1, [23004]=1, [23005]=1, [23006]=1, [23027]=1, [23040]=1,
		[23041]=1, [23197]=1, [23199]=1, [23203]=1, [23274]=1, [23279]=1, [23280]=1, [23282]=1, [23285]=1, [23286]=1, [23288]=1, [23290]=1,
		[23558]=1, [23570]=1, [23714]=1, [23716]=1, [191312]=1, [202256]=1, [205218]=1, [205420]=1, [206376]=1, [206381]=1, [206382]=1, [206383]=1,
		[206384]=1, [206385]=1, [206386]=1, [206387]=1, [206388]=1, [206389]=1, [206390]=1, [206391]=1, [206954]=1, [208222]=1, [208414]=1, [208689]=1,
		[208849]=1, [208851]=1, [209611]=1, [209612]=1, [209613]=1, [209614]=1, [209615]=1, [209616]=1, [209617]=1, [209618]=1, [209619]=1, [209620]=1,
		[209621]=1, [209622]=1, [209623]=1, [209624]=1, [209625]=1, [209626]=1, [210195]=1, [210534]=1, [211472]=1, [211940]=1, [211941]=1, [213105]=1,
		[213513]=1, [213594]=1, [219345]=1, [220606]=1, [220915]=1, [225838]=1, [226546]=1, [227444]=1, [228175]=1, [228176]=1, [231877]=1, [249396]=1,
		[249397]=1, [249398]=1, [249441]=1, [249442]=1, [249443]=1, [249469]=1, [249470]=1, [249473]=1, [259846]=1, [259890]=1, [260205]=1, [260802]=1,
		[260806]=1, [260810]=1, [260819]=1, [260820]=1, [260821]=1, [260824]=1, [260828]=1, [260829]=1, [263411]=1, [263412]=1, [263435]=1, [263436]=1,
		[268484]=1, [268873]=1, [269741]=1, [270275]=1, [272427]=1, [272428]=1, [272429]=1, [272430]=1, [272431]=1, [272432]=1, [272433]=1, [272434]=1,
		[272435]=1, [272436]=1, [272437]=1, [272438]=1, [272455]=1, [272464]=1, [272478]=1, [272484]=1, [272495]=1, [272505]=1, [272513]=1, [272520]=1,
		[272523]=1, [272536]=1, [272538]=1, [272553]=1, [272556]=1, [272569]=1, [272572]=1, [272591]=1, [272608]=1, [272609]=1, [272614]=1, [272619]=1,
		[272703]=1, [272704]=1, [272709]=1, [272715]=1, [272717]=1, [272719]=1, [272749]=1, [272755]=1, [272757]=1, [272772]=1, [272780]=1, [272793]=1,
		[272796]=1, [272808]=1, [272812]=1, [272824]=1, [272838]=1, [273329]=1, [273336]=1, [273344]=1, [273355]=1, [273363]=1, [273368]=1, [273377]=1,
		[273382]=1, [273391]=1, [273399]=1, [273411]=1, [273419]=1, [273427]=1, [273431]=1, [273445]=1, [274176]=1, [274183]=1, [274192]=1, [274198]=1,
		[274206]=1, [274217]=1, [274227]=1, [274236]=1, [274250]=1, [274256]=1, [274444]=1, [274445]=1, [274747]=1, [274759]=1, [274760]=1, [274761]=1,
		[275347]=1, [275630]=1, [275645]=1, [275647]=1, [275649]=1, [275671]=1, [275729]=1, [275833]=1, [276274]=1, [276337]=1, [276782]=1, [276895]=1,
		[277518]=1, [277844]=1, [277910]=1, [277950]=1, [279247]=1, [279248]=1, [279249]=1, [279250]=1, [279251]=1, [280310]=1, [280311]=1, [280312]=1,
		[280313]=1, [280604]=1, [280605]=1, [280607]=1, [280766]=1, [281060]=1, [282080]=1, [285275]=1, [285276]=1, [285277]=1, [285278]=1, [285280]=1,
		[285281]=1, [288900]=1, [289295]=1, [289296]=1, [289297]=1,
	},
	-- set id -> each bonus: { pieces needed, its stats or false where it is not a stat }
	sets = {
		[1] = { { 2, false }, { 3, false }, { 4, false }, { 5, false } },
		[41] = { { 2, false } },
		[65] = { { 2, false } },
		[81] = { { 2, false }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 5, false } },
		[121] = { { 3, false }, { 3, false }, { 4, { RESISTANCE2_NAME = 5, RESISTANCE3_NAME = 5, RESISTANCE4_NAME = 5, RESISTANCE5_NAME = 5, RESISTANCE6_NAME = 5 } }, { 5, false } },
		[122] = { { 2, { ITEM_MOD_HIT_RATING_SHORT = 5 } }, { 3, false }, { 4, { RESISTANCE2_NAME = 5, RESISTANCE3_NAME = 5, RESISTANCE4_NAME = 5, RESISTANCE5_NAME = 5, RESISTANCE6_NAME = 5 } }, { 5, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[123] = { { 2, false }, { 3, false }, { 4, { RESISTANCE2_NAME = 5, RESISTANCE3_NAME = 5, RESISTANCE4_NAME = 5, RESISTANCE5_NAME = 5, RESISTANCE6_NAME = 5 } }, { 5, { ITEM_MOD_CRIT_RATING_SHORT = 21 } } },
		[124] = { { 2, { UPGRADES_DEFENSE = 3 } }, { 3, false }, { 4, { RESISTANCE2_NAME = 5, RESISTANCE3_NAME = 5, RESISTANCE4_NAME = 5, RESISTANCE5_NAME = 5, RESISTANCE6_NAME = 5 } }, { 5, false } },
		[141] = { { 3, false } },
		[142] = { { 2, false }, { 3, false }, { 4, false } },
		[143] = { { 2, false } },
		[144] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 20, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20 } } },
		[161] = { { 2, { RESISTANCE6_NAME = 5 } }, { 3, { UPGRADES_ATTACK_POWER_VS = 15 } }, { 4, false }, { 5, false } },
		[162] = { { 2, { ITEM_MOD_INTELLECT_SHORT = 10 } }, { 3, false }, { 4, false }, { 5, false } },
		[163] = { { 2, { RESISTANCE5_NAME = 10 } }, { 3, { UPGRADES_ATTACK_POWER_VS = 30 } }, { 4, false }, { 5, false }, { 6, false } },
		[181] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[182] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[183] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[184] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, false }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_HEALTH_REGEN_SHORT = 15 } } },
		[185] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 3, false }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[186] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, false }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[187] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[188] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } } },
		[189] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_STRENGTH_SHORT = 15 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_HEALTH_REGEN_SHORT = 15 } } },
		[201] = { { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 5, false }, { 8, false } },
		[202] = { { 3, false }, { 5, false }, { 8, false } },
		[203] = { { 3, false }, { 5, false }, { 8, false } },
		[204] = { { 3, false }, { 5, false }, { 8, false } },
		[205] = { { 3, false }, { 5, false }, { 8, false } },
		[206] = { { 3, false }, { 5, false }, { 8, false } },
		[207] = { { 3, false }, { 5, false }, { 8, false } },
		[208] = { { 3, false }, { 5, false }, { 5, { ITEM_MOD_CRIT_RATING_SHORT = 14 } }, { 8, false } },
		[209] = { { 3, false }, { 5, false }, { 8, false } },
		[210] = { { 3, false }, { 5, false }, { 8, false } },
		[211] = { { 3, false }, { 5, false }, { 8, false } },
		[212] = { { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 5, false }, { 8, false } },
		[213] = { { 3, false }, { 5, false }, { 8, false } },
		[214] = { { 3, false }, { 5, false }, { 8, false } },
		[215] = { { 3, false }, { 5, false }, { 8, false } },
		[216] = { { 3, false }, { 5, false }, { 8, false } },
		[217] = { { 3, false }, { 5, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 47, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 47 } }, { 8, false } },
		[218] = { { 3, false }, { 5, false }, { 8, false } },
		[221] = { { 6, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[241] = { { 2, { RESISTANCE2_NAME = 10, RESISTANCE3_NAME = 10, RESISTANCE4_NAME = 10, RESISTANCE5_NAME = 10, RESISTANCE6_NAME = 10 } }, { 2, false } },
		[261] = { { 2, { UPGRADES_ATTACK_POWER_VS = 30 } }, { 3, false }, { 4, false } },
		[281] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[282] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[301] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[321] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 3, false }, { 4, false }, { 5, { ITEM_MOD_STRENGTH_SHORT = 20 } }, { 6, false } },
		[341] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 15 } } },
		[342] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 15 } } },
		[343] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[344] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[345] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[346] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[347] = { { 2, { ITEM_MOD_PARRY_RATING_SHORT = 15 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 15 } } },
		[348] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[361] = { { 2, { ITEM_MOD_AGILITY_SHORT = 20 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[362] = { { 2, { ITEM_MOD_AGILITY_SHORT = 20 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[381] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[382] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[383] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[384] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[386] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[387] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[388] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[389] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[390] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[391] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[392] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[393] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[394] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[395] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_AGILITY_SHORT = 20 } } },
		[396] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_AGILITY_SHORT = 20 } } },
		[397] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[398] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[401] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[402] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[421] = { { 3, false } },
		[441] = { { 3, false } },
		[442] = { { 2, { ITEM_MOD_CRIT_RATING_SHORT = 14 } }, { 2, false } },
		[443] = { { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 12 } } },
		[444] = { { 3, { UPGRADES_DEFENSE = 20 } } },
		[461] = { { 2, false } },
		[462] = { { 2, false }, { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 6, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 6 } } },
		[463] = { { 2, false } },
		[464] = { { 2, { ITEM_MOD_DODGE_RATING_SHORT = 12 } } },
		[465] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[466] = { { 2, false } },
		[467] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[468] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[469] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[470] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, false } },
		[471] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[472] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, false } },
		[473] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, false } },
		[474] = { { 2, { ITEM_MOD_BLOCK_RATING_SHORT = 10 } }, { 3, false }, { 5, false } },
		[475] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } }, { 3, false }, { 5, false } },
		[476] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } }, { 3, false }, { 5, false } },
		[477] = { { 2, false }, { 3, false }, { 5, false } },
		[478] = { { 2, false }, { 3, false }, { 5, false } },
		[479] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } }, { 3, false }, { 5, false } },
		[480] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } }, { 3, false }, { 5, false } },
		[481] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false }, { 5, false } },
		[482] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false }, { 5, false } },
		[483] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[484] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[485] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, false } },
		[486] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[487] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 14 } } },
		[488] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, false } },
		[489] = { { 2, false }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 28 } } },
		[490] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 3 } }, { 3, false } },
		[491] = { { 2, { RESISTANCE2_NAME = 4, RESISTANCE3_NAME = 4, RESISTANCE4_NAME = 4, RESISTANCE5_NAME = 4, RESISTANCE6_NAME = 4 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 28, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 28 } } },
		[492] = { { 3, false } },
		[493] = { { 3, { UPGRADES_DEFENSE = 15 } }, { 3, false }, { 5, false } },
		[494] = { { 3, false } },
		[495] = { { 3, false } },
		[496] = { { 3, false }, { 5, false } },
		[497] = { { 3, false }, { 5, false } },
		[498] = { { 3, false } },
		[499] = { { 3, false }, { 5, false } },
		[500] = { { 3, false } },
		[501] = { { 3, false }, { 5, false } },
		[502] = { { 3, false } },
		[503] = { { 3, false }, { 5, false } },
		[504] = { { 3, false } },
		[505] = { { 3, false }, { 5, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 71, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 71 } } },
		[506] = { { 3, false } },
		[507] = { { 3, false }, { 5, false } },
		[508] = { { 3, false } },
		[509] = { { 3, false }, { 5, false } },
		[510] = { { 3, false } },
		[511] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, false }, { 8, false } },
		[512] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, false }, { 8, false } },
		[513] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 15 } }, { 6, false }, { 8, false } },
		[514] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 8, false } },
		[515] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, false }, { 8, false } },
		[516] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, false }, { 8, false } },
		[517] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 8, false } },
		[518] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 8, false } },
		[519] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 4, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 8, false } },
		[520] = { { 2, false }, { 3, false }, { 4, false }, { 5, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 6, false } },
		[521] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[522] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[523] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[524] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[525] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[526] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[527] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[528] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[529] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[530] = { { 2, false }, { 4, false }, { 6, false }, { 8, false } },
		[533] = { { 3, false } },
		[534] = { { 3, false } },
		[535] = { { 3, false } },
		[536] = { { 3, false } },
		[537] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[538] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[539] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[540] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[541] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[542] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[543] = { { 2, { ITEM_MOD_AGILITY_SHORT = 20 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[544] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[545] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[546] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[547] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[548] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[549] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[550] = { { 2, { ITEM_MOD_AGILITY_SHORT = 20 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[551] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1570] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 9, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 9 } }, { 3, false } },
		[1571] = { { 3, false }, { 5, false }, { 8, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 47, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 47 } } },
		[1577] = { { 2, false }, { 3, false } },
		[1578] = { { 2, false }, { 3, false } },
		[1579] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false } },
		[1584] = { { 2, false }, { 2, false }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 11, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 11 } } },
		[1585] = { { 2, false }, { 3, { ITEM_MOD_ATTACK_POWER_SHORT = 20 } }, { 3, false } },
		[1586] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 16, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 16 } }, { 3, false } },
		[1587] = { { 2, false }, { 2, false }, { 3, false } },
		[1588] = { { 2, { ITEM_MOD_SPIRIT_SHORT = 14 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 7 } } },
		[1589] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 2, false }, { 3, false } },
		[1590] = { { 2, false }, { 3, false } },
		[1591] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false } },
		[1592] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false } },
		[1618] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1619] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1620] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1621] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } } },
		[1622] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1623] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } } },
		[1624] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1625] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1626] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1627] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1628] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1629] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1630] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1631] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } } },
		[1632] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } } },
		[1633] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } } },
		[1634] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } } },
		[1635] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1636] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1637] = { { 2, false }, { 3, false } },
		[1638] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } }, { 3, false } },
		[1639] = { { 2, false }, { 3, false } },
		[1640] = { { 2, { ITEM_MOD_STRENGTH_SHORT = 10 } }, { 3, false }, { 3, false } },
		[1641] = { { 2, false }, { 3, false } },
		[1642] = { { 2, false }, { 3, false } },
		[1643] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } }, { 3, false } },
		[1644] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } }, { 3, false } },
		[1645] = { { 2, false }, { 3, false } },
		[1646] = { { 2, false }, { 3, false }, { 3, false } },
		[1647] = { { 2, false }, { 3, false }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 28 } } },
		[1648] = { { 2, false }, { 3, false } },
		[1649] = { { 2, false }, { 3, false } },
		[1650] = { { 2, false }, { 3, false } },
		[1651] = { { 2, false } },
		[1652] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, false } },
		[1653] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } } },
		[1654] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, false } },
		[1655] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } } },
		[1656] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } } },
		[1657] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, false } },
		[1658] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } } },
		[1659] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } } },
		[1660] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } } },
		[1661] = { { 3, { ITEM_MOD_STAMINA_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } } },
		[1665] = { { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 6, false } },
		[1666] = { { 2, false }, { 4, false }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1667] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1668] = { { 2, false }, { 4, false }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1669] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, false } },
		[1670] = { { 2, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1671] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1672] = { { 2, false }, { 4, false }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1673] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1674] = { { 2, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1675] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1676] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_HEALTH_REGEN_SHORT = 15 } }, { 4, false }, { 5, false }, { 6, false } },
		[1677] = { { 2, false }, { 4, false }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1678] = { { 2, false }, { 4, false }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1679] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1680] = { { 2, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1681] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1682] = { { 2, false }, { 4, false }, { 6, false }, { 8, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } } },
		[1698] = { { 2, false }, { 4, false }, { 6, false } },
		[1699] = { { 2, false }, { 4, false }, { 6, false } },
		[1700] = { { 2, false }, { 4, false }, { 6, false } },
		[1701] = { { 2, false }, { 4, false }, { 6, false } },
		[1702] = { { 2, false }, { 4, false }, { 6, false } },
		[1703] = { { 2, false }, { 4, false }, { 6, false } },
		[1704] = { { 2, false }, { 4, false }, { 6, false } },
		[1705] = { { 2, false }, { 4, false }, { 6, false } },
		[1706] = { { 2, false }, { 4, false }, { 6, false } },
		[1707] = { { 2, false }, { 4, false }, { 6, false } },
		[1708] = { { 2, false }, { 4, false }, { 6, false } },
		[1709] = { { 2, false }, { 4, false }, { 6, false } },
		[1710] = { { 2, false }, { 4, false }, { 6, false } },
		[1711] = { { 2, false }, { 4, false }, { 6, false } },
		[1712] = { { 2, false }, { 4, false }, { 6, false } },
		[1713] = { { 2, false }, { 4, false }, { 6, false } },
		[1714] = { { 2, false }, { 4, false }, { 6, false } },
		[1715] = { { 2, false }, { 4, false }, { 6, false } },
		[1716] = { { 2, false }, { 4, false }, { 6, false } },
		[1717] = { { 2, false }, { 4, false }, { 6, false } },
		[1718] = { { 2, false }, { 4, false }, { 6, false } },
		[1719] = { { 2, false }, { 4, false }, { 6, false } },
		[1720] = { { 2, false }, { 4, false }, { 6, false } },
		[1721] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1722] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1723] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1724] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[1725] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_AGILITY_SHORT = 20 } } },
		[1726] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1727] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1728] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1729] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[1730] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1731] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1732] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1733] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[1734] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1735] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1736] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[1737] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1738] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1739] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_AGILITY_SHORT = 20 } } },
		[1740] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1741] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1742] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[1743] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1744] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1745] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[1746] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1747] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[1748] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1749] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1750] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1751] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1752] = { { 2, { ITEM_MOD_AGILITY_SHORT = 20 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1753] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1754] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1755] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1756] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1757] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1758] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1759] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1760] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1761] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1762] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1763] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1764] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1765] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1766] = { { 2, { ITEM_MOD_AGILITY_SHORT = 20 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1767] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1768] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1769] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1770] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1774] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1775] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1776] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1777] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[1778] = { { 2, { RESISTANCE2_NAME = 8, RESISTANCE3_NAME = 8, RESISTANCE4_NAME = 8, RESISTANCE5_NAME = 8, RESISTANCE6_NAME = 8 } }, { 3, { ITEM_MOD_HEALTH_REGEN_SHORT = 15 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_STRENGTH_SHORT = 20 } } },
		[1779] = { { 2, false }, { 3, false } },
		[1780] = { { 2, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 55 } }, { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 29 } }, { 2, false } },
		[1781] = { { 2, false }, { 3, false }, { 4, false } },
		[1782] = { { 2, false }, { 3, { RESISTANCE2_NAME = 10 } }, { 3, { RESISTANCE6_NAME = 10 } }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 5, false }, { 5, { ITEM_MOD_INTELLECT_SHORT = 10 } } },
		[1783] = { { 2, false }, { 2, { UPGRADES_DEFENSE = 7 } } },
		[1784] = { { 2, false } },
		[1785] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1786] = { { 2, { UPGRADES_DEFENSE = 3 } }, { 3, false }, { 4, { RESISTANCE2_NAME = 15, RESISTANCE3_NAME = 15, RESISTANCE4_NAME = 15, RESISTANCE5_NAME = 15, RESISTANCE6_NAME = 15 } }, { 5, { ITEM_MOD_PARRY_RATING_SHORT = 15 } } },
		[1787] = { { 2, { ITEM_MOD_STAMINA_SHORT = 5 } }, { 3, { ITEM_MOD_INTELLECT_SHORT = 5 } }, { 4, { RESISTANCE2_NAME = 15, RESISTANCE3_NAME = 15, RESISTANCE4_NAME = 15, RESISTANCE5_NAME = 15, RESISTANCE6_NAME = 15 } }, { 5, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[1788] = { { 2, { UPGRADES_DEFENSE = 3 } }, { 3, false }, { 4, { RESISTANCE2_NAME = 15, RESISTANCE3_NAME = 15, RESISTANCE4_NAME = 15, RESISTANCE5_NAME = 15, RESISTANCE6_NAME = 15 } }, { 5, { ITEM_MOD_PARRY_RATING_SHORT = 15 } } },
		[1789] = { { 2, { RESISTANCE2_NAME = 10 } }, { 3, false } },
		[1790] = { { 2, { RESISTANCE2_NAME = 4, RESISTANCE3_NAME = 4, RESISTANCE4_NAME = 4, RESISTANCE5_NAME = 4, RESISTANCE6_NAME = 4 } }, { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 28, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 28 } } },
		[1791] = { { 2, { ITEM_MOD_MANA_REGENERATION_SHORT = 3 } }, { 3, false } },
		[1792] = { { 2, false }, { 3, false }, { 4, { RESISTANCE2_NAME = 10 } } },
		[1793] = { { 2, { RESISTANCE2_NAME = 10 } }, { 2, false } },
		[1795] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 6, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 6 } }, { 2, false } },
		[1796] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 11, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 33 } } },
		[1797] = { { 2, false } },
		[1798] = { { 2, false } },
		[1799] = { { 2, { UPGRADES_DEFENSE = 8 } } },
		[1800] = { { 2, false }, { 2, false } },
		[1801] = { { 2, false }, { 4, false }, { 6, false } },
		[1802] = { { 2, false }, { 4, false }, { 6, false } },
		[1803] = { { 2, false }, { 4, false }, { 6, false } },
		[1804] = { { 2, false }, { 4, false }, { 6, false } },
		[1805] = { { 2, false }, { 4, false }, { 6, false } },
		[1806] = { { 2, false }, { 4, false }, { 6, false } },
		[1807] = { { 2, false }, { 4, false }, { 6, false } },
		[1808] = { { 2, false }, { 4, false }, { 6, false } },
		[1809] = { { 2, false }, { 4, false }, { 6, false } },
		[1810] = { { 2, false }, { 4, false }, { 6, false } },
		[1811] = { { 2, false }, { 4, false }, { 6, false } },
		[1812] = { { 2, false }, { 4, false }, { 6, false } },
		[1813] = { { 2, false }, { 4, false }, { 6, false } },
		[1814] = { { 2, false }, { 4, false }, { 6, false } },
		[1815] = { { 2, false }, { 4, false }, { 6, false } },
		[1816] = { { 2, false }, { 4, false }, { 6, false } },
		[1817] = { { 2, false }, { 4, false }, { 6, false } },
		[1818] = { { 2, false }, { 4, false }, { 6, false } },
		[1819] = { { 2, false }, { 4, false }, { 6, false } },
		[1820] = { { 2, false }, { 4, false }, { 6, false } },
		[1821] = { { 2, false }, { 4, false }, { 6, false } },
		[1822] = { { 2, false }, { 4, false }, { 6, false } },
		[1823] = { { 2, false }, { 4, false }, { 6, false } },
		[1824] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false }, { 5, false } },
		[1825] = { { 2, false }, { 3, false }, { 5, false } },
		[1826] = { { 2, { ITEM_MOD_FROST_DAMAGE_DONE_SHORT = 14 } }, { 3, false }, { 5, false } },
		[1827] = { { 2, { ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = 14 } }, { 3, false }, { 5, false } },
		[1828] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 7, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } }, { 3, false }, { 5, false } },
		[1829] = { { 2, false }, { 3, { ITEM_MOD_CRIT_RATING_SHORT = 70 } }, { 5, false } },
		[1830] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 3, { ITEM_MOD_BLOCK_RATING_SHORT = 50 } }, { 5, false } },
		[1831] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } }, { 3, false }, { 5, false } },
		[1832] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 3, false }, { 5, false } },
		[1835] = { { 2, false }, { 4, false } },
		[1836] = { { 2, false }, { 4, false } },
		[1837] = { { 2, false }, { 4, false } },
		[1838] = { { 2, false }, { 4, false } },
		[1839] = { { 2, false }, { 4, false } },
		[1840] = { { 2, false }, { 4, false } },
		[1841] = { { 2, false }, { 4, false } },
		[1842] = { { 2, false }, { 4, false } },
		[1843] = { { 2, false }, { 4, false } },
		[1844] = { { 2, false }, { 4, false } },
		[1845] = { { 2, false }, { 4, false } },
		[1846] = { { 2, false }, { 4, false } },
		[1847] = { { 2, false }, { 4, false } },
		[1848] = { { 2, false }, { 4, false } },
		[1849] = { { 2, false }, { 4, false } },
		[1850] = { { 2, false }, { 4, false } },
		[1851] = { { 2, false }, { 4, false } },
		[1852] = { { 2, false }, { 4, false } },
		[1853] = { { 2, false }, { 4, false } },
		[1854] = { { 2, false }, { 4, false } },
		[1855] = { { 2, false }, { 4, false } },
		[1856] = { { 2, false }, { 4, false } },
		[1857] = { { 2, false }, { 4, false } },
		[1858] = { { 3, false } },
		[1859] = { { 3, false } },
		[1860] = { { 3, false } },
		[1861] = { { 3, false } },
		[1862] = { { 3, false } },
		[1863] = { { 3, false } },
		[1864] = { { 3, false } },
		[1865] = { { 3, false } },
		[1866] = { { 3, false } },
		[1881] = { { 2, false } },
		[1882] = { { 2, false }, { 4, false }, { 6, false } },
		[1883] = { { 2, false }, { 4, false }, { 6, false } },
		[1884] = { { 2, false }, { 4, false }, { 6, false } },
		[1885] = { { 2, false }, { 4, false }, { 6, false } },
		[1886] = { { 2, false }, { 4, false }, { 6, false } },
		[1887] = { { 2, false }, { 4, false }, { 6, false } },
		[1888] = { { 2, false }, { 4, false }, { 6, false } },
		[1889] = { { 2, false }, { 4, false }, { 6, false } },
		[1890] = { { 2, false }, { 4, false }, { 6, false } },
		[1891] = { { 2, false }, { 4, false }, { 6, false } },
		[1892] = { { 2, false }, { 4, false }, { 6, false } },
		[1893] = { { 2, false }, { 4, false }, { 6, false } },
		[1894] = { { 2, false }, { 4, false }, { 6, false } },
		[1895] = { { 2, false }, { 4, false }, { 6, false } },
		[1896] = { { 2, false }, { 4, false }, { 6, false } },
		[1897] = { { 2, false }, { 4, false }, { 6, false } },
		[1898] = { { 2, false }, { 4, false }, { 6, false } },
		[1899] = { { 2, false }, { 4, false }, { 6, false } },
		[1900] = { { 2, false }, { 4, false }, { 6, false } },
		[1901] = { { 2, false }, { 4, false }, { 6, false } },
		[1902] = { { 2, false }, { 4, false }, { 6, false } },
		[1903] = { { 2, false }, { 4, false }, { 6, false } },
		[1904] = { { 2, false }, { 4, false }, { 6, false } },
		[1905] = { { 3, false } },
		[1906] = { { 3, false } },
		[1907] = { { 3, false } },
		[1908] = { { 3, false } },
		[1909] = { { 3, false } },
		[1910] = { { 3, false } },
		[1911] = { { 3, false } },
		[1912] = { { 3, false } },
		[1913] = { { 3, false } },
		[1914] = { { 2, false } },
		[1915] = { { 2, false } },
		[1916] = { { 2, false } },
		[1917] = { { 3, false } },
		[1918] = { { 3, false } },
		[1932] = { { 2, false }, { 4, false }, { 6, false } },
		[1933] = { { 2, false }, { 4, false }, { 6, false } },
		[1934] = { { 2, false }, { 4, false }, { 6, false } },
		[1935] = { { 2, false }, { 4, false }, { 6, false } },
		[1936] = { { 2, false }, { 4, false }, { 6, false } },
		[1937] = { { 2, false }, { 4, false }, { 6, false } },
		[1938] = { { 2, false }, { 4, false }, { 6, false } },
		[1939] = { { 2, false }, { 4, false }, { 6, false } },
		[1940] = { { 2, false }, { 4, false }, { 6, false } },
		[1941] = { { 2, false }, { 4, false }, { 6, false } },
		[1942] = { { 2, false }, { 4, false }, { 6, false } },
		[1943] = { { 2, false }, { 4, false }, { 6, false } },
		[1944] = { { 2, false }, { 4, false }, { 6, false } },
		[1945] = { { 2, false }, { 4, false }, { 6, false } },
		[1946] = { { 2, false }, { 4, false }, { 6, false } },
		[1947] = { { 2, false }, { 4, false }, { 6, false } },
		[1948] = { { 2, false }, { 4, false }, { 6, false } },
		[1949] = { { 2, false }, { 4, false }, { 6, false } },
		[1950] = { { 2, false }, { 4, false }, { 6, false } },
		[1951] = { { 2, false }, { 4, false }, { 6, false } },
		[1952] = { { 2, false }, { 4, false }, { 6, false } },
		[1953] = { { 2, false }, { 4, false }, { 6, false } },
		[1954] = { { 2, false }, { 4, false }, { 6, false } },
		[1955] = { { 2, false } },
		[1956] = { { 2, false } },
		[1959] = { { 2, false } },
		[1963] = { { 2, false }, { 4, false }, { 6, false } },
		[1968] = { { 2, { RESISTANCE5_NAME = 10 } }, { 3, { ITEM_MOD_STRENGTH_SHORT = 20 } }, { 4, false }, { 5, false }, { 6, { ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = 29 } } },
		[1972] = { { 3, { ITEM_MOD_SPIRIT_SHORT = 10 } }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 8, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22 } } },
		[2071] = { { 2, false } },
		[2072] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2073] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2074] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2075] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2076] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2077] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2078] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[2079] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[2080] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2081] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2082] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2083] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2084] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2085] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[2086] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2087] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[2088] = { { 2, false }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2089] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, false } },
		[2090] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2091] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2092] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2093] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44 } } },
		[2094] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2095] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[2096] = { { 2, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } }, { 4, false }, { 6, { ITEM_MOD_STAMINA_SHORT = 20 } } },
		[2097] = { { 2, { ITEM_MOD_STAMINA_SHORT = 20 } }, { 3, false }, { 6, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 23, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 23 } } },
		[2098] = { { 2, false }, { 3, false }, { 4, false }, { 5, false } },
		[2099] = { { 2, false }, { 3, false }, { 4, { UPGRADES_ATTACK_POWER_VS = 36 } }, { 5, false } },
		[2100] = { { 2, false }, { 3, false }, { 4, false }, { 5, false } },
		[2101] = { { 2, false }, { 3, false }, { 4, { UPGRADES_ATTACK_POWER_VS = 36 } }, { 5, false } },
		[2102] = { { 2, false }, { 3, false }, { 4, { UPGRADES_ATTACK_POWER_VS = 36 } }, { 5, false } },
		[2103] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 3, false }, { 4, false }, { 5, false } },
		[2104] = { { 2, { ITEM_MOD_SPIRIT_SHORT = 10 } }, { 3, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 9, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 26 } }, { 5, false } },
		[2105] = { { 2, false }, { 3, false }, { 4, false }, { 5, false } },
		[2106] = { { 2, false }, { 3, false }, { 4, { UPGRADES_ATTACK_POWER_VS = 36 } }, { 5, false } },
		[2107] = { { 2, { ITEM_MOD_SPIRIT_SHORT = 10 } }, { 3, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 9, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 26 } }, { 5, false } },
		[2108] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 3, false }, { 4, false }, { 5, false } },
		[2109] = { { 2, { ITEM_MOD_SPIRIT_SHORT = 10 } }, { 3, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 9, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 26 } }, { 5, false } },
		[2110] = { { 2, false }, { 3, false }, { 4, { UPGRADES_ATTACK_POWER_VS = 36 } }, { 5, false } },
		[2111] = { { 2, false }, { 3, false }, { 4, false }, { 5, false } },
		[2112] = { { 2, { ITEM_MOD_SPIRIT_SHORT = 10 } }, { 3, false }, { 4, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 9, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 26 } }, { 5, false } },
		[2113] = { { 2, { UPGRADES_DEFENSE = 7 } }, { 3, false }, { 4, false }, { 5, false } },
		[2114] = { { 2, false }, { 3, false }, { 4, false }, { 5, false } },
		[2115] = { { 2, false }, { 3, false }, { 4, { UPGRADES_ATTACK_POWER_VS = 36 } }, { 5, false } },
		[2130] = { { 2, false }, { 3, false } },
		[2131] = { { 2, false }, { 2, { ITEM_MOD_STRENGTH_SHORT = 22 } } },
		[2132] = { { 2, false } },
		[2133] = { { 2, { RESISTANCE5_NAME = 5 } }, { 3, { ITEM_MOD_INTELLECT_SHORT = 10 } }, { 4, false }, { 5, false } },
		[2134] = { { 2, { RESISTANCE6_NAME = 5 } }, { 3, { ITEM_MOD_SPIRIT_SHORT = 10 } }, { 4, false }, { 5, false } },
		[2135] = { { 2, false }, { 3, { UPGRADES_DEFENSE = 5 } }, { 4, false }, { 5, false } },
		[2136] = { { 2, { RESISTANCE2_NAME = 10 } }, { 3, { ITEM_MOD_STAMINA_SHORT = 15 } }, { 4, false }, { 5, false } },
		[2138] = { { 3, { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 18, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 18 } }, { 5, false }, { 8, false } },
		[2139] = { { 3, false }, { 5, false }, { 8, false } },
		[2140] = { { 3, false }, { 5, false }, { 8, false } },
		[2141] = { { 3, false }, { 5, false }, { 8, false } },
		[2142] = { { 3, false }, { 5, false }, { 8, false } },
		[2143] = { { 3, false }, { 5, false }, { 8, false } },
		[2144] = { { 3, false }, { 5, false }, { 8, false } },
		[2145] = { { 3, false }, { 5, false }, { 5, { ITEM_MOD_CRIT_RATING_SHORT = 14 } }, { 8, false } },
		[2146] = { { 3, false }, { 5, false }, { 8, false } },
	},
	-- item id -> the set it belongs to
	setOf = {
		[6473]=162, [7948]=221, [7949]=221, [7950]=221, [7951]=221, [7952]=221, [7953]=221, [10010]=1972,
		[10011]=1972, [10020]=1972, [10032]=1972, [10038]=1972, [10039]=1972, [10328]=163, [10329]=163, [10330]=163,
		[10331]=163, [10332]=163, [10333]=163, [10399]=161, [10400]=161, [10401]=161, [10402]=161, [10403]=161,
		[10410]=162, [10411]=162, [10412]=162, [10413]=162, [11726]=1, [11728]=1, [11729]=1, [11730]=1,
		[11731]=1, [12422]=321, [12424]=321, [12425]=321, [12426]=321, [12427]=321, [12428]=321, [12429]=321,
		[12939]=41, [12940]=41, [13183]=65, [13218]=65, [13388]=81, [13389]=81, [13390]=81, [13391]=81,
		[13392]=81, [14611]=123, [14612]=123, [14614]=123, [14615]=123, [14616]=123, [14620]=124, [14621]=124,
		[14622]=124, [14623]=124, [14624]=124, [14626]=122, [14629]=122, [14631]=122, [14632]=122, [14633]=122,
		[14636]=121, [14637]=121, [14638]=121, [14640]=121, [14641]=121, [15045]=490, [15046]=490, [15048]=491,
		[15049]=491, [15050]=489, [15051]=489, [15052]=489, [15053]=141, [15054]=141, [15055]=141, [15056]=142,
		[15057]=142, [15058]=142, [15062]=143, [15063]=143, [15066]=144, [15067]=144, [16485]=341, [16487]=341,
		[16489]=341, [16490]=341, [16491]=341, [16492]=341, [16498]=347, [16499]=347, [16505]=347, [16506]=347,
		[16507]=347, [16508]=347, [16666]=187, [16667]=187, [16668]=187, [16669]=187, [16670]=187, [16671]=187,
		[16672]=187, [16673]=187, [16674]=186, [16675]=186, [16676]=186, [16677]=186, [16678]=186, [16679]=186,
		[16680]=186, [16681]=186, [16682]=181, [16683]=181, [16684]=181, [16685]=181, [16686]=181, [16687]=181,
		[16688]=181, [16689]=181, [16690]=182, [16691]=182, [16692]=182, [16693]=182, [16694]=182, [16695]=182,
		[16696]=182, [16697]=182, [16698]=183, [16699]=183, [16700]=183, [16701]=183, [16702]=183, [16703]=183,
		[16704]=183, [16705]=183, [16706]=185, [16707]=184, [16708]=184, [16709]=184, [16710]=184, [16711]=184,
		[16712]=184, [16713]=184, [16714]=185, [16715]=185, [16716]=185, [16717]=185, [16718]=185, [16719]=185,
		[16720]=185, [16721]=184, [16722]=188, [16723]=188, [16724]=188, [16725]=188, [16726]=188, [16727]=188,
		[16728]=188, [16729]=188, [16730]=189, [16731]=189, [16732]=189, [16733]=189, [16734]=189, [16735]=189,
		[16736]=189, [16737]=189, [16795]=201, [16796]=201, [16797]=201, [16798]=201, [16799]=201, [16800]=201,
		[16801]=201, [16802]=201, [16803]=203, [16804]=203, [16805]=203, [16806]=203, [16807]=203, [16808]=203,
		[16809]=203, [16810]=203, [16811]=202, [16812]=202, [16813]=202, [16814]=202, [16815]=202, [16816]=202,
		[16817]=202, [16818]=210, [16819]=202, [16820]=204, [16821]=204, [16822]=204, [16823]=204, [16824]=204,
		[16825]=204, [16826]=204, [16827]=204, [16828]=205, [16829]=205, [16830]=205, [16831]=205, [16832]=213,
		[16833]=205, [16834]=205, [16835]=205, [16836]=205, [16837]=207, [16838]=207, [16839]=207, [16840]=207,
		[16841]=207, [16842]=207, [16843]=207, [16844]=207, [16845]=206, [16846]=206, [16847]=206, [16848]=206,
		[16849]=206, [16850]=206, [16851]=206, [16852]=206, [16853]=208, [16854]=208, [16855]=208, [16856]=208,
		[16857]=208, [16858]=208, [16859]=208, [16860]=208, [16861]=209, [16862]=209, [16863]=209, [16864]=209,
		[16865]=209, [16866]=209, [16867]=209, [16868]=209, [16897]=214, [16898]=214, [16899]=214, [16900]=214,
		[16901]=214, [16902]=214, [16903]=214, [16904]=214, [16905]=213, [16906]=213, [16907]=213, [16908]=213,
		[16909]=213, [16910]=213, [16911]=213, [16912]=210, [16913]=210, [16914]=210, [16915]=210, [16916]=210,
		[16917]=210, [16918]=210, [16919]=211, [16920]=211, [16921]=211, [16922]=211, [16923]=211, [16924]=211,
		[16925]=211, [16926]=211, [16927]=212, [16928]=212, [16929]=212, [16930]=212, [16931]=212, [16932]=212,
		[16933]=212, [16934]=212, [16935]=215, [16936]=215, [16937]=215, [16938]=215, [16939]=215, [16940]=215,
		[16941]=215, [16942]=215, [16943]=216, [16944]=216, [16945]=216, [16946]=216, [16947]=216, [16948]=216,
		[16949]=216, [16950]=216, [16951]=217, [16952]=217, [16953]=217, [16954]=217, [16955]=217, [16956]=217,
		[16957]=217, [16958]=217, [16959]=218, [16960]=218, [16961]=218, [16962]=218, [16963]=218, [16964]=218,
		[16965]=218, [16966]=218, [17064]=241, [17610]=342, [17611]=342, [17612]=342, [17613]=342, [17616]=342,
		[17617]=342, [18202]=261, [18203]=261, [18204]=261, [18205]=261, [19577]=474, [19588]=475, [19594]=480,
		[19601]=482, [19605]=481, [19609]=476, [19613]=479, [19617]=478, [19621]=477, [19682]=421, [19683]=421,
		[19684]=421, [19685]=441, [19686]=441, [19687]=441, [19688]=442, [19689]=442, [19690]=443, [19691]=443,
		[19692]=443, [19693]=444, [19694]=444, [19695]=444, [19822]=474, [19823]=474, [19824]=474, [19825]=475,
		[19826]=475, [19827]=475, [19828]=476, [19829]=476, [19830]=476, [19831]=477, [19832]=477, [19833]=477,
		[19834]=478, [19835]=478, [19836]=478, [19838]=479, [19839]=479, [19840]=479, [19841]=480, [19842]=480,
		[19843]=480, [19845]=482, [19846]=482, [19848]=481, [19849]=481, [19863]=465, [19865]=461, [19866]=461,
		[19873]=464, [19893]=462, [19896]=463, [19898]=466, [19905]=462, [19910]=463, [19912]=464, [19920]=465,
		[19925]=466, [19951]=474, [19952]=475, [19953]=477, [19954]=478, [19955]=479, [19956]=476, [19957]=481,
		[19958]=480, [19959]=482, [20033]=481, [20034]=482, [20041]=467, [20042]=468, [20043]=469, [20044]=470,
		[20045]=471, [20046]=472, [20047]=473, [20048]=467, [20049]=468, [20050]=469, [20051]=470, [20052]=471,
		[20053]=472, [20054]=473, [20055]=469, [20056]=470, [20057]=467, [20058]=468, [20059]=471, [20060]=472,
		[20061]=473, [20150]=483, [20154]=483, [20158]=483, [20159]=485, [20163]=485, [20167]=488, [20171]=488,
		[20175]=488, [20176]=485, [20186]=486, [20190]=486, [20194]=486, [20195]=484, [20199]=484, [20203]=484,
		[20204]=487, [20208]=487, [20212]=487, [20295]=491, [20296]=490, [20406]=492, [20407]=492, [20408]=492,
		[21278]=142, [21326]=2071, [21329]=496, [21330]=496, [21331]=496, [21332]=496, [21333]=496, [21334]=499,
		[21335]=499, [21336]=499, [21337]=499, [21338]=499, [21343]=503, [21344]=503, [21345]=503, [21346]=503,
		[21347]=503, [21348]=507, [21349]=507, [21350]=507, [21351]=507, [21352]=507, [21353]=493, [21354]=493,
		[21355]=493, [21356]=493, [21357]=493, [21359]=497, [21360]=497, [21361]=497, [21362]=497, [21364]=497,
		[21365]=509, [21366]=509, [21367]=509, [21368]=509, [21370]=509, [21372]=501, [21373]=501, [21374]=501,
		[21375]=501, [21376]=501, [21387]=505, [21388]=505, [21389]=505, [21390]=505, [21391]=505, [21392]=495,
		[21393]=495, [21394]=495, [21395]=506, [21396]=506, [21397]=506, [21398]=502, [21399]=502, [21400]=502,
		[21401]=510, [21402]=510, [21403]=510, [21404]=498, [21405]=498, [21406]=498, [21407]=494, [21408]=494,
		[21409]=494, [21410]=508, [21411]=508, [21412]=508, [21413]=504, [21414]=504, [21415]=504, [21416]=500,
		[21417]=500, [21418]=500, [21994]=511, [21995]=511, [21996]=511, [21997]=511, [21998]=511, [21999]=511,
		[22000]=511, [22001]=511, [22002]=512, [22003]=512, [22004]=512, [22005]=512, [22006]=512, [22007]=512,
		[22008]=512, [22009]=512, [22010]=515, [22011]=515, [22013]=515, [22015]=515, [22016]=515, [22017]=515,
		[22060]=515, [22061]=515, [22062]=517, [22063]=517, [22064]=517, [22065]=517, [22066]=517, [22067]=517,
		[22068]=517, [22069]=517, [22070]=518, [22071]=518, [22072]=518, [22073]=518, [22074]=518, [22075]=518,
		[22076]=518, [22077]=518, [22078]=514, [22079]=514, [22080]=514, [22081]=514, [22082]=514, [22083]=514,
		[22084]=514, [22085]=514, [22086]=516, [22087]=516, [22088]=516, [22089]=516, [22090]=516, [22091]=516,
		[22092]=516, [22093]=516, [22095]=519, [22096]=519, [22097]=519, [22098]=519, [22099]=519, [22100]=519,
		[22101]=519, [22102]=519, [22106]=513, [22107]=513, [22108]=513, [22109]=513, [22110]=513, [22111]=513,
		[22112]=513, [22113]=513, [22301]=520, [22302]=520, [22303]=520, [22304]=520, [22305]=520, [22306]=520,
		[22311]=520, [22313]=520, [22416]=523, [22417]=523, [22418]=523, [22419]=523, [22420]=523, [22421]=523,
		[22422]=523, [22423]=523, [22424]=528, [22425]=528, [22426]=528, [22427]=528, [22428]=528, [22429]=528,
		[22430]=528, [22431]=528, [22436]=530, [22437]=530, [22438]=530, [22439]=530, [22440]=530, [22441]=530,
		[22442]=530, [22443]=530, [22464]=527, [22465]=527, [22466]=527, [22467]=527, [22468]=527, [22469]=527,
		[22470]=527, [22471]=527, [22476]=524, [22477]=524, [22478]=524, [22479]=524, [22480]=524, [22481]=524,
		[22482]=524, [22483]=524, [22488]=521, [22489]=521, [22490]=521, [22491]=521, [22492]=521, [22493]=521,
		[22494]=521, [22495]=521, [22496]=526, [22497]=526, [22498]=526, [22499]=526, [22500]=526, [22501]=526,
		[22502]=526, [22503]=526, [22504]=529, [22505]=529, [22506]=529, [22507]=529, [22508]=529, [22509]=529,
		[22510]=529, [22511]=529, [22512]=525, [22513]=525, [22514]=525, [22515]=525, [22516]=525, [22517]=525,
		[22518]=525, [22519]=525, [22843]=543, [22855]=541, [22857]=538, [22858]=537, [22859]=540, [22860]=542,
		[22862]=543, [22865]=541, [22867]=538, [22868]=537, [22869]=540, [22870]=542, [22872]=537, [22873]=537,
		[22874]=543, [22875]=543, [22876]=538, [22881]=541, [22882]=540, [22883]=542, [22884]=541, [22885]=540,
		[22886]=542, [22887]=538, [23059]=523, [23060]=524, [23061]=525, [23062]=526, [23063]=529, [23064]=521,
		[23065]=527, [23066]=528, [23067]=530, [23078]=533, [23081]=534, [23082]=535, [23084]=536, [23085]=536,
		[23087]=533, [23088]=535, [23089]=534, [23090]=533, [23091]=536, [23092]=535, [23093]=534, [23243]=537,
		[23244]=537, [23251]=543, [23252]=543, [23255]=541, [23256]=541, [23259]=538, [23260]=538, [23261]=540,
		[23262]=540, [23263]=542, [23264]=542, [23272]=544, [23273]=544, [23274]=544, [23275]=544, [23276]=544,
		[23277]=544, [23278]=550, [23279]=550, [23282]=547, [23283]=547, [23284]=548, [23285]=548, [23286]=545,
		[23287]=545, [23292]=550, [23293]=550, [23296]=547, [23297]=547, [23298]=548, [23299]=548, [23300]=545,
		[23301]=545, [23306]=550, [23307]=550, [23310]=547, [23311]=547, [23312]=548, [23313]=548, [23314]=545,
		[23315]=545, [209669]=1570, [209671]=1570, [209683]=1570, [211263]=1571, [211504]=1577, [211505]=1577, [211506]=1577,
		[211507]=1579, [211508]=1579, [211509]=1579, [211510]=1578, [211511]=1578, [211512]=1578, [213310]=1588, [213311]=1587,
		[213312]=1586, [213313]=1585, [213314]=1590, [213315]=1591, [213316]=1589, [213328]=1588, [213329]=1587, [213330]=1589,
		[213331]=1586, [213332]=1585, [213333]=1590, [213334]=1591, [213335]=1589, [213336]=1587, [213337]=1588, [213338]=1591,
		[213339]=1590, [213341]=1585, [213342]=1586, [215377]=1584, [215378]=1584, [215379]=1584, [216484]=1592, [216485]=1592,
		[216486]=1592, [216918]=1718, [216919]=1718, [216920]=1718, [216921]=1718, [216922]=1718, [216923]=1718, [216924]=1718,
		[216925]=1718, [220588]=1651, [220589]=1651, [220642]=1650, [220643]=1650, [220648]=1650, [220650]=1648, [220651]=1648,
		[220652]=1648, [220653]=1649, [220654]=1649, [220656]=1649, [220657]=1645, [220658]=1645, [220659]=1645, [220660]=1646,
		[220661]=1646, [220662]=1646, [220663]=1644, [220664]=1644, [220665]=1644, [220666]=1647, [220667]=1647, [220668]=1647,
		[220669]=1643, [220670]=1643, [220671]=1643, [220672]=1642, [220673]=1642, [220675]=1642, [220676]=1641, [220677]=1641,
		[220678]=1641, [220679]=1639, [220680]=1639, [220681]=1639, [220683]=1638, [220684]=1638, [220685]=1638, [220778]=1640,
		[220779]=1640, [220780]=1640, [220781]=1637, [220783]=1637, [220784]=1637, [220794]=1619, [220795]=1619, [220796]=1618,
		[220797]=1619, [220798]=1618, [220799]=1619, [220800]=1618, [220801]=1618, [220803]=1618, [220804]=1619, [220806]=1619,
		[220807]=1618, [220808]=1620, [220809]=1620, [220810]=1620, [220811]=1620, [220812]=1620, [220813]=1620, [220814]=1621,
		[220815]=1621, [220816]=1621, [220817]=1621, [220818]=1621, [220819]=1621, [220820]=1622, [220821]=1625, [220822]=1626,
		[220823]=1622, [220824]=1625, [220825]=1626, [220826]=1622, [220827]=1625, [220828]=1626, [220829]=1626, [220830]=1625,
		[220831]=1622, [220832]=1626, [220833]=1625, [220834]=1622, [220835]=1622, [220836]=1625, [220837]=1626, [220838]=1624,
		[220839]=1624, [220840]=1624, [220841]=1624, [220842]=1624, [220843]=1624, [220844]=1623, [220845]=1623, [220846]=1623,
		[220847]=1623, [220848]=1623, [220849]=1623, [220850]=1628, [220851]=1627, [220852]=1628, [220853]=1627, [220854]=1628,
		[220855]=1627, [220856]=1628, [220857]=1627, [220858]=1628, [220859]=1627, [220860]=1628, [220861]=1627, [220862]=1632,
		[220863]=1631, [220864]=1632, [220865]=1631, [220866]=1632, [220867]=1631, [220868]=1632, [220869]=1631, [220870]=1632,
		[220871]=1631, [220872]=1632, [220873]=1631, [220874]=1630, [220875]=1629, [220876]=1630, [220877]=1629, [220878]=1630,
		[220879]=1629, [220880]=1630, [220881]=1629, [220882]=1630, [220883]=1629, [220884]=1630, [220885]=1629, [220886]=1634,
		[220887]=1634, [220888]=1634, [220889]=1634, [220890]=1634, [220891]=1634, [220892]=1636, [220893]=1636, [220894]=1636,
		[220895]=1636, [220896]=1636, [220897]=1636, [220898]=1635, [220899]=1635, [220900]=1635, [220901]=1635, [220902]=1635,
		[220903]=1635, [220904]=1633, [220905]=1633, [220906]=1633, [220907]=1633, [220908]=1633, [220909]=1633, [221376]=1652,
		[221377]=1652, [221378]=1652, [221379]=1652, [221380]=1652, [221381]=1652, [221382]=1653, [221383]=1653, [221384]=1653,
		[221385]=1653, [221386]=1653, [221387]=1653, [221388]=1654, [221389]=1654, [221390]=1654, [221391]=1654, [221392]=1654,
		[221393]=1654, [221394]=1655, [221395]=1655, [221396]=1655, [221397]=1655, [221398]=1655, [221399]=1655, [221400]=1656,
		[221401]=1656, [221402]=1656, [221403]=1656, [221404]=1656, [221405]=1656, [221406]=1657, [221407]=1657, [221408]=1657,
		[221409]=1657, [221410]=1657, [221411]=1657, [221412]=1658, [221413]=1658, [221414]=1658, [221415]=1658, [221416]=1658,
		[221417]=1658, [221419]=1659, [221420]=1659, [221421]=1659, [221422]=1659, [221423]=1659, [221424]=1659, [221425]=1660,
		[221426]=1660, [221427]=1660, [221429]=1660, [221430]=1660, [221431]=1660, [221432]=1661, [221434]=1661, [221435]=1661,
		[221436]=1661, [221437]=1661, [221438]=1661, [221783]=1707, [221785]=1700, [223073]=1665, [223074]=1665, [223075]=1665,
		[223076]=1665, [223077]=1665, [223078]=1665, [226440]=1711, [226441]=1711, [226442]=1711, [226443]=1711, [226444]=1711,
		[226445]=1711, [226446]=1711, [226447]=1711, [226473]=1712, [226474]=1712, [226475]=1712, [226476]=1712, [226477]=1712,
		[226478]=1712, [226479]=1712, [226480]=1712, [226484]=1719, [226485]=1719, [226486]=1719, [226487]=1719, [226488]=1719,
		[226489]=1719, [226490]=1719, [226491]=1719, [226492]=1720, [226493]=1720, [226494]=1720, [226495]=1720, [226496]=1720,
		[226497]=1720, [226498]=1720, [226499]=1720, [226527]=1702, [226528]=1702, [226529]=1702, [226530]=1702, [226531]=1702,
		[226532]=1702, [226533]=1702, [226534]=1702, [226535]=1703, [226536]=1703, [226537]=1703, [226538]=1703, [226540]=1703,
		[226541]=1703, [226542]=1703, [226543]=1703, [226547]=1717, [226548]=1717, [226549]=1717, [226550]=1717, [226551]=1717,
		[226552]=1717, [226553]=1717, [226554]=1717, [226555]=1704, [226556]=1704, [226557]=1704, [226558]=1704, [226559]=1704,
		[226560]=1704, [226561]=1704, [226562]=1704, [226563]=1705, [226564]=1705, [226565]=1705, [226566]=1705, [226567]=1705,
		[226568]=1705, [226569]=1705, [226570]=1705, [226571]=1709, [226572]=1709, [226573]=1709, [226574]=1709, [226575]=1709,
		[226576]=1709, [226577]=1709, [226578]=1709, [226579]=1710, [226580]=1710, [226581]=1710, [226582]=1710, [226583]=1710,
		[226584]=1710, [226585]=1710, [226586]=1710, [226588]=1706, [226589]=1706, [226590]=1706, [226591]=1706, [226592]=1706,
		[226593]=1706, [226594]=1706, [226595]=1708, [226596]=1707, [226597]=1707, [226598]=1707, [226599]=1707, [226600]=1707,
		[226601]=1707, [226602]=1707, [226603]=1708, [226604]=1708, [226605]=1708, [226606]=1708, [226607]=1708, [226608]=1708,
		[226609]=1708, [226610]=1706, [226611]=1713, [226612]=1713, [226613]=1713, [226614]=1713, [226615]=1713, [226616]=1713,
		[226617]=1713, [226618]=1713, [226619]=1714, [226620]=1714, [226621]=1714, [226622]=1714, [226623]=1714, [226624]=1714,
		[226625]=1714, [226626]=1714, [226627]=1716, [226628]=1716, [226629]=1716, [226630]=1716, [226631]=1716, [226632]=1716,
		[226633]=1716, [226634]=1716, [226635]=1715, [226636]=1715, [226637]=1715, [226638]=1715, [226639]=1715, [226640]=1715,
		[226641]=1715, [226642]=1715, [226644]=1700, [226645]=1700, [226646]=1700, [226647]=1700, [226648]=1700, [226649]=1700,
		[226650]=1700, [226651]=1698, [226652]=1698, [226653]=1698, [226654]=1698, [226655]=1698, [226656]=1698, [226657]=1698,
		[226658]=1698, [226659]=1699, [226660]=1699, [226661]=1699, [226662]=1699, [226663]=1699, [226664]=1699, [226665]=1699,
		[226666]=1699, [226667]=1701, [226668]=1701, [226669]=1701, [226670]=1701, [226671]=1701, [226673]=1701, [226674]=1701,
		[226675]=1701, [226700]=1677, [226701]=1677, [226702]=1677, [226703]=1677, [226704]=1677, [226705]=1677, [226706]=1677,
		[226707]=1677, [226708]=1666, [226709]=1666, [226710]=1666, [226711]=1666, [226712]=1666, [226713]=1666, [226714]=1666,
		[226715]=1666, [226716]=1668, [226717]=1668, [226718]=1668, [226719]=1668, [226720]=1668, [226721]=1668, [226722]=1668,
		[226723]=1668, [226724]=1670, [226725]=1670, [226726]=1670, [226727]=1670, [226728]=1670, [226729]=1670, [226730]=1670,
		[226731]=1670, [226732]=1672, [226733]=1672, [226734]=1672, [226735]=1672, [226736]=1672, [226737]=1672, [226738]=1672,
		[226739]=1672, [226740]=1674, [226741]=1674, [226742]=1674, [226743]=1674, [226744]=1674, [226745]=1674, [226746]=1674,
		[226747]=1674, [226748]=1678, [226749]=1678, [226750]=1678, [226751]=1678, [226752]=1678, [226753]=1678, [226754]=1678,
		[226755]=1678, [226756]=1680, [226757]=1680, [226758]=1680, [226759]=1680, [226760]=1680, [226761]=1680, [226762]=1680,
		[226763]=1680, [226764]=1682, [226765]=1682, [226766]=1682, [226767]=1682, [226768]=1682, [226769]=1682, [226770]=1682,
		[226771]=1682, [226815]=1667, [226816]=1667, [226817]=1667, [226818]=1667, [226819]=1667, [226820]=1667, [226821]=1667,
		[226822]=1667, [226845]=1676, [226846]=1676, [226847]=1676, [226848]=1676, [226849]=1676, [226850]=1676, [226851]=1676,
		[226852]=1676, [226873]=1778, [226874]=1778, [226875]=1778, [226876]=1778, [226877]=1778, [226878]=1778, [226879]=1778,
		[226880]=1778, [226897]=1669, [226898]=1669, [226899]=1669, [226900]=1669, [226901]=1669, [226902]=1669, [226903]=1669,
		[226904]=1669, [226921]=1681, [226922]=1681, [226923]=1681, [226924]=1681, [226925]=1681, [226926]=1681, [226927]=1681,
		[226928]=1681, [226937]=1671, [226938]=1671, [226939]=1671, [226940]=1671, [226941]=1671, [226942]=1671, [226943]=1671,
		[226944]=1671, [226961]=1675, [226962]=1675, [226963]=1675, [226964]=1675, [226965]=1675, [226966]=1675, [226967]=1675,
		[226968]=1675, [226993]=1673, [226994]=1673, [226995]=1673, [226996]=1673, [226997]=1673, [226998]=1673, [226999]=1673,
		[227000]=1673, [227033]=1679, [227034]=1679, [227035]=1679, [227036]=1679, [227037]=1679, [227038]=1679, [227039]=1679,
		[227040]=1679, [227042]=1761, [227043]=1761, [227044]=1775, [227045]=1775, [227046]=1775, [227047]=1775, [227048]=1761,
		[227049]=1761, [227050]=1761, [227051]=1761, [227052]=1775, [227053]=1775, [227054]=1770, [227055]=1770, [227056]=1756,
		[227057]=1756, [227058]=1770, [227059]=1756, [227060]=1756, [227061]=1770, [227062]=1756, [227063]=1756, [227064]=1770,
		[227065]=1770, [227066]=1766, [227067]=1752, [227068]=1766, [227069]=1752, [227070]=1766, [227071]=1752, [227072]=1766,
		[227073]=1752, [227074]=1752, [227075]=1752, [227076]=1766, [227077]=1766, [227078]=1751, [227079]=1751, [227080]=1751,
		[227081]=1751, [227082]=1751, [227083]=1751, [227084]=1765, [227085]=1765, [227086]=1765, [227087]=1765, [227088]=1765,
		[227089]=1765, [227090]=1760, [227091]=1774, [227092]=1760, [227093]=1774, [227094]=1760, [227095]=1774, [227096]=1774,
		[227097]=1760, [227098]=1760, [227099]=1760, [227100]=1774, [227101]=1774, [227102]=1767, [227103]=1767, [227104]=1753,
		[227105]=1753, [227106]=1753, [227107]=1753, [227108]=1767, [227109]=1767, [227110]=1753, [227112]=1767, [227116]=1767,
		[227117]=1753, [227118]=1755, [227119]=1769, [227120]=1755, [227121]=1769, [227122]=1769, [227123]=1755, [227124]=1755,
		[227125]=1769, [227126]=1755, [227127]=1755, [227128]=1769, [227129]=1769, [227130]=1754, [227131]=1754, [227132]=1754,
		[227133]=1754, [227134]=1754, [227135]=1754, [227136]=1768, [227137]=1768, [227138]=1768, [227139]=1768, [227140]=1768,
		[227141]=1768, [227142]=1777, [227143]=1777, [227144]=1777, [227145]=1777, [227146]=1777, [227147]=1777, [227148]=1776,
		[227149]=1776, [227150]=1776, [227151]=1776, [227152]=1776, [227153]=1776, [227154]=1759, [227155]=1759, [227156]=1759,
		[227157]=1759, [227158]=1759, [227159]=1759, [227160]=1757, [227161]=1757, [227162]=1757, [227163]=1757, [227164]=1757,
		[227165]=1757, [227166]=1758, [227167]=1758, [227168]=1758, [227169]=1758, [227170]=1758, [227171]=1758, [227172]=1764,
		[227173]=1764, [227174]=1750, [227175]=1750, [227176]=1764, [227177]=1750, [227178]=1764, [227179]=1750, [227180]=1750,
		[227181]=1750, [227182]=1764, [227183]=1764, [227184]=1748, [227185]=1748, [227186]=1748, [227187]=1748, [227188]=1748,
		[227189]=1748, [227190]=1762, [227191]=1762, [227192]=1762, [227193]=1762, [227194]=1762, [227195]=1762, [227196]=1763,
		[227197]=1763, [227198]=1763, [227199]=1763, [227200]=1763, [227201]=1763, [227202]=1749, [227203]=1749, [227204]=1749,
		[227205]=1749, [227206]=1749, [227207]=1749, [227829]=1792, [227847]=1793, [227848]=1793, [227851]=1792, [227852]=1792,
		[227853]=1792, [227866]=1789, [227867]=1789, [227868]=1789, [227873]=1790, [227874]=1790, [227875]=1790, [227877]=1791,
		[227878]=1791, [227879]=1791, [227998]=1788, [227999]=1786, [228000]=1786, [228002]=1786, [228003]=1788, [228006]=1786,
		[228008]=1786, [228009]=1787, [228010]=1787, [228011]=1787, [228012]=1788, [228013]=1787, [228014]=1788, [228018]=1787,
		[228020]=1788, [228038]=1785, [228066]=1785, [228145]=1779, [228146]=1779, [228147]=1779, [228297]=1780, [228298]=1780,
		[228349]=1781, [228350]=1781, [228360]=1781, [228524]=1782, [228525]=1782, [228527]=1782, [228528]=1782, [228529]=1782,
		[228547]=1785, [228573]=1783, [228592]=1783, [228596]=1785, [228597]=1785, [228598]=1785, [228652]=1784, [228653]=1784,
		[228681]=1785, [228700]=1785, [228759]=1781, [230867]=1795, [230915]=1796, [230921]=1797, [230925]=1798, [230929]=1797,
		[230934]=1798, [230943]=1799, [230992]=1800, [230999]=1799, [231000]=1796, [231001]=1795, [231023]=1822, [231024]=1822,
		[231025]=1822, [231026]=1822, [231027]=1822, [231028]=1822, [231029]=1822, [231030]=1822, [231031]=1823, [231032]=1823,
		[231033]=1823, [231034]=1823, [231035]=1823, [231036]=1823, [231037]=1823, [231038]=1823, [231039]=1814, [231040]=1814,
		[231041]=1814, [231042]=1814, [231043]=1814, [231044]=1814, [231045]=1814, [231046]=1814, [231047]=1815, [231048]=1815,
		[231049]=1815, [231050]=1815, [231051]=1815, [231052]=1815, [231053]=1815, [231054]=1815, [231055]=1805, [231056]=1805,
		[231057]=1805, [231058]=1805, [231059]=1805, [231060]=1805, [231061]=1805, [231062]=1805, [231063]=1806, [231065]=1806,
		[231066]=1806, [231067]=1806, [231068]=1806, [231069]=1806, [231070]=1806, [231071]=1806, [231072]=1820, [231073]=1820,
		[231074]=1820, [231075]=1820, [231076]=1820, [231077]=1820, [231078]=1820, [231079]=1820, [231090]=1821, [231091]=1821,
		[231092]=1821, [231093]=1821, [231095]=1821, [231096]=1821, [231097]=1821, [231098]=1821, [231100]=1807, [231101]=1807,
		[231102]=1807, [231103]=1807, [231104]=1807, [231105]=1807, [231106]=1807, [231107]=1807, [231108]=1808, [231109]=1808,
		[231110]=1808, [231111]=1808, [231112]=1808, [231113]=1808, [231114]=1808, [231115]=1808, [231155]=1812, [231156]=1812,
		[231157]=1812, [231158]=1812, [231159]=1812, [231160]=1812, [231161]=1812, [231162]=1812, [231165]=1813, [231166]=1813,
		[231167]=1813, [231168]=1813, [231169]=1813, [231170]=1813, [231171]=1813, [231172]=1813, [231174]=1810, [231175]=1810,
		[231176]=1810, [231177]=1810, [231178]=1810, [231179]=1810, [231180]=1810, [231181]=1810, [231182]=1811, [231183]=1811,
		[231184]=1811, [231185]=1811, [231186]=1811, [231187]=1811, [231188]=1811, [231189]=1811, [231190]=1809, [231191]=1809,
		[231192]=1809, [231193]=1809, [231194]=1809, [231195]=1809, [231196]=1809, [231197]=1809, [231198]=1816, [231199]=1816,
		[231200]=1816, [231201]=1816, [231202]=1816, [231203]=1816, [231204]=1816, [231205]=1816, [231206]=1819, [231207]=1819,
		[231208]=1819, [231209]=1819, [231210]=1819, [231211]=1819, [231212]=1819, [231213]=1819, [231214]=1817, [231215]=1817,
		[231216]=1817, [231217]=1817, [231218]=1817, [231219]=1817, [231220]=1817, [231221]=1817, [231222]=1818, [231223]=1818,
		[231224]=1818, [231225]=1818, [231226]=1818, [231227]=1818, [231228]=1818, [231229]=1818, [231230]=1802, [231231]=1802,
		[231232]=1802, [231233]=1802, [231234]=1802, [231235]=1802, [231236]=1802, [231237]=1802, [231238]=1804, [231239]=1804,
		[231240]=1804, [231241]=1804, [231242]=1804, [231243]=1804, [231244]=1804, [231245]=1804, [231246]=1801, [231247]=1801,
		[231248]=1801, [231249]=1801, [231250]=1801, [231251]=1801, [231252]=1801, [231253]=1801, [231254]=1803, [231255]=1803,
		[231256]=1803, [231257]=1803, [231258]=1803, [231259]=1803, [231260]=1803, [231261]=1803, [231280]=1824, [231281]=1830,
		[231282]=1826, [231283]=1828, [231284]=1831, [231285]=1827, [231286]=1832, [231287]=1829, [231288]=1825, [231309]=1800,
		[231316]=1824, [231317]=1824, [231318]=1824, [231319]=1824, [231320]=1825, [231321]=1825, [231322]=1825, [231323]=1825,
		[231324]=1826, [231325]=1826, [231326]=1826, [231327]=1826, [231328]=1827, [231329]=1827, [231330]=1827, [231331]=1827,
		[231332]=1828, [231333]=1828, [231334]=1828, [231335]=1828, [231336]=1829, [231337]=1829, [231338]=1829, [231339]=1829,
		[231340]=1830, [231341]=1830, [231342]=1830, [231343]=1830, [231346]=1831, [231347]=1831, [231348]=1831, [231349]=1831,
		[231350]=1832, [231351]=1832, [231352]=1832, [231353]=1832, [231530]=1721, [231531]=1721, [231532]=1721, [231533]=1721,
		[231534]=1721, [231535]=1721, [231536]=1747, [231537]=1747, [231538]=1747, [231539]=1747, [231540]=1747, [231541]=1747,
		[231543]=1743, [231544]=1743, [231545]=1743, [231546]=1743, [231547]=1743, [231548]=1743, [231549]=1730, [231551]=1730,
		[231552]=1730, [231553]=1730, [231554]=1730, [231555]=1730, [231557]=1738, [231558]=1738, [231560]=1738, [231561]=1738,
		[231562]=1738, [231563]=1738, [231564]=1726, [231565]=1726, [231566]=1726, [231567]=1726, [231568]=1726, [231569]=1726,
		[231570]=1725, [231571]=1725, [231572]=1725, [231573]=1725, [231574]=1725, [231575]=1725, [231576]=1739, [231577]=1739,
		[231578]=1739, [231579]=1739, [231580]=1739, [231581]=1739, [231582]=1746, [231583]=1746, [231584]=1746, [231585]=1746,
		[231586]=1746, [231587]=1746, [231588]=1734, [231589]=1734, [231590]=1734, [231591]=1734, [231592]=1734, [231593]=1734,
		[231594]=1727, [231595]=1727, [231596]=1727, [231597]=1727, [231598]=1727, [231601]=1727, [231602]=1740, [231603]=1740,
		[231604]=1740, [231605]=1740, [231606]=1740, [231607]=1740, [231610]=1728, [231611]=1728, [231612]=1728, [231613]=1728,
		[231614]=1728, [231615]=1728, [231616]=1741, [231617]=1741, [231618]=1741, [231619]=1741, [231620]=1741, [231621]=1741,
		[231622]=1742, [231623]=1742, [231624]=1742, [231626]=1742, [231627]=1742, [231628]=1742, [231630]=1729, [231631]=1729,
		[231632]=1729, [231633]=1729, [231634]=1729, [231635]=1729, [231639]=1745, [231640]=1745, [231641]=1745, [231643]=1745,
		[231645]=1745, [231646]=1745, [231647]=1744, [231648]=1744, [231649]=1744, [231650]=1744, [231651]=1744, [231652]=1744,
		[231653]=1731, [231654]=1731, [231655]=1731, [231656]=1731, [231657]=1731, [231658]=1731, [231659]=1732, [231660]=1732,
		[231661]=1732, [231662]=1732, [231663]=1732, [231664]=1732, [231665]=1733, [231666]=1733, [231667]=1733, [231668]=1733,
		[231669]=1733, [231670]=1733, [231671]=1724, [231672]=1724, [231673]=1724, [231674]=1724, [231675]=1724, [231676]=1724,
		[231677]=1723, [231678]=1723, [231679]=1723, [231680]=1723, [231681]=1723, [231682]=1723, [231683]=1722, [231684]=1722,
		[231685]=1722, [231686]=1722, [231687]=1722, [231688]=1722, [231689]=1737, [231690]=1737, [231691]=1737, [231692]=1737,
		[231693]=1737, [231694]=1737, [231695]=1735, [231696]=1735, [231697]=1735, [231698]=1735, [231699]=1735, [231700]=1735,
		[231701]=1736, [231702]=1736, [231703]=1736, [231704]=1736, [231705]=1736, [231706]=1736, [233372]=1857, [233373]=1857,
		[233374]=1857, [233375]=1857, [233376]=1857, [233377]=1854, [233378]=1854, [233379]=1854, [233380]=1854, [233381]=1854,
		[233382]=1850, [233383]=1850, [233384]=1850, [233385]=1850, [233386]=1850, [233387]=1848, [233388]=1848, [233389]=1848,
		[233390]=1848, [233391]=1848, [233392]=1847, [233393]=1847, [233394]=1847, [233395]=1847, [233396]=1847, [233397]=1845,
		[233398]=1845, [233399]=1845, [233400]=1845, [233401]=1845, [233402]=1841, [233403]=1841, [233404]=1841, [233405]=1841,
		[233406]=1841, [233407]=1839, [233408]=1839, [233409]=1839, [233410]=1839, [233411]=1839, [233412]=1837, [233413]=1837,
		[233414]=1837, [233415]=1837, [233416]=1837, [233417]=1858, [233418]=1858, [233419]=1858, [233420]=1859, [233421]=1859,
		[233422]=1859, [233423]=1860, [233424]=1860, [233425]=1860, [233426]=1861, [233427]=1861, [233428]=1861, [233429]=1862,
		[233430]=1862, [233431]=1862, [233432]=1863, [233433]=1863, [233434]=1863, [233435]=1864, [233436]=1864, [233437]=1864,
		[233438]=1865, [233439]=1865, [233440]=1865, [233441]=1866, [233442]=1866, [233443]=1866, [233651]=1856, [233652]=1856,
		[233653]=1856, [233654]=1856, [233658]=1856, [233659]=1849, [233660]=1849, [233661]=1849, [233662]=1849, [233663]=1849,
		[233664]=1840, [233665]=1840, [233666]=1840, [233667]=1840, [233668]=1840, [233669]=1855, [233670]=1855, [233671]=1855,
		[233672]=1855, [233673]=1855, [233674]=1842, [233675]=1842, [233676]=1842, [233677]=1842, [233678]=1842, [233679]=1846,
		[233680]=1846, [233681]=1846, [233682]=1846, [233683]=1846, [233684]=1843, [233685]=1843, [233686]=1843, [233687]=1843,
		[233688]=1843, [233689]=1844, [233690]=1844, [233691]=1844, [233692]=1844, [233693]=1844, [233694]=1852, [233695]=1852,
		[233696]=1852, [233697]=1852, [233698]=1852, [233699]=1853, [233700]=1853, [233701]=1853, [233702]=1853, [233703]=1853,
		[233704]=1851, [233705]=1851, [233706]=1851, [233707]=1851, [233708]=1851, [233709]=1838, [233710]=1838, [233711]=1838,
		[233712]=1838, [233713]=1838, [233714]=1836, [233715]=1836, [233716]=1836, [233717]=1836, [233718]=1836, [233719]=1835,
		[233720]=1835, [233721]=1835, [233722]=1835, [233723]=1835, [235893]=1881, [235894]=1881, [236005]=1882, [236006]=1882,
		[236007]=1882, [236008]=1882, [236009]=1882, [236010]=1882, [236011]=1882, [236012]=1882, [236013]=1882, [236014]=1883,
		[236015]=1883, [236016]=1883, [236017]=1883, [236018]=1883, [236019]=1883, [236020]=1883, [236021]=1883, [236022]=1883,
		[236023]=1891, [236024]=1891, [236025]=1891, [236026]=1891, [236027]=1891, [236028]=1891, [236029]=1891, [236030]=1891,
		[236031]=1891, [236032]=1890, [236033]=1890, [236034]=1890, [236035]=1890, [236036]=1890, [236037]=1890, [236038]=1890,
		[236039]=1890, [236040]=1890, [236041]=1899, [236042]=1899, [236043]=1899, [236044]=1899, [236045]=1899, [236046]=1899,
		[236047]=1899, [236048]=1899, [236049]=1899, [236050]=1900, [236051]=1900, [236052]=1900, [236053]=1900, [236054]=1900,
		[236055]=1900, [236056]=1900, [236057]=1900, [236058]=1900, [236059]=1885, [236060]=1885, [236061]=1885, [236062]=1885,
		[236063]=1885, [236064]=1885, [236065]=1885, [236066]=1885, [236067]=1885, [236068]=1884, [236069]=1884, [236070]=1884,
		[236071]=1884, [236072]=1884, [236073]=1884, [236074]=1884, [236075]=1884, [236076]=1884, [236077]=1898, [236078]=1898,
		[236079]=1898, [236080]=1898, [236081]=1898, [236082]=1898, [236083]=1898, [236084]=1898, [236085]=1898, [236087]=1897,
		[236088]=1897, [236089]=1897, [236090]=1897, [236091]=1897, [236092]=1897, [236093]=1897, [236094]=1897, [236095]=1897,
		[236097]=1892, [236098]=1892, [236099]=1892, [236100]=1892, [236101]=1892, [236102]=1892, [236103]=1892, [236104]=1892,
		[236105]=1892, [236106]=1893, [236107]=1893, [236108]=1893, [236109]=1893, [236110]=1893, [236111]=1893, [236112]=1893,
		[236113]=1893, [236114]=1893, [236115]=1895, [236116]=1895, [236117]=1895, [236118]=1895, [236119]=1895, [236120]=1895,
		[236121]=1895, [236122]=1895, [236123]=1895, [236124]=1896, [236125]=1896, [236126]=1896, [236127]=1896, [236128]=1896,
		[236129]=1896, [236130]=1896, [236131]=1896, [236132]=1896, [236133]=1894, [236134]=1894, [236135]=1894, [236136]=1894,
		[236137]=1894, [236138]=1894, [236139]=1894, [236140]=1894, [236141]=1894, [236142]=1887, [236143]=1887, [236144]=1887,
		[236145]=1887, [236146]=1887, [236147]=1887, [236148]=1887, [236149]=1887, [236150]=1887, [236151]=1889, [236152]=1889,
		[236153]=1889, [236154]=1889, [236155]=1889, [236156]=1889, [236157]=1889, [236158]=1889, [236159]=1889, [236160]=1886,
		[236162]=1886, [236163]=1886, [236164]=1886, [236165]=1886, [236166]=1886, [236167]=1886, [236168]=1886, [236169]=1886,
		[236170]=1888, [236171]=1888, [236172]=1888, [236173]=1888, [236174]=1888, [236175]=1888, [236176]=1888, [236177]=1888,
		[236179]=1888, [236182]=1902, [236183]=1902, [236184]=1902, [236185]=1902, [236186]=1902, [236187]=1902, [236188]=1902,
		[236189]=1902, [236190]=1902, [236192]=1904, [236193]=1904, [236194]=1904, [236195]=1904, [236196]=1904, [236197]=1904,
		[236198]=1904, [236199]=1904, [236200]=1904, [236201]=1901, [236202]=1901, [236203]=1901, [236204]=1901, [236205]=1901,
		[236206]=1901, [236207]=1901, [236208]=1901, [236209]=1901, [236210]=1903, [236211]=1903, [236212]=1903, [236213]=1903,
		[236214]=1903, [236215]=1903, [236216]=1903, [236217]=1903, [236218]=1903, [236343]=1955, [236707]=1905, [236708]=1907,
		[236709]=1906, [236710]=1906, [236711]=1905, [236712]=1907, [236713]=1905, [236714]=1907, [236715]=1906, [236716]=1908,
		[236717]=1908, [236718]=1908, [236719]=1917, [236720]=1917, [236721]=1917, [236722]=1918, [236723]=1918, [236724]=1918,
		[236725]=1914, [236726]=1914, [236727]=1914, [236728]=1915, [236729]=1915, [236730]=1915, [236731]=1916, [236732]=1916,
		[236733]=1916, [236734]=1911, [236735]=1911, [236736]=1911, [236737]=1912, [236738]=1912, [236739]=1912, [236740]=1913,
		[236741]=1913, [236742]=1913, [236743]=1910, [236744]=1910, [236745]=1910, [236746]=1909, [236747]=1909, [236748]=1909,
		[239512]=1932, [239513]=1932, [239514]=1932, [239515]=1932, [239516]=1932, [239517]=1932, [239518]=1932, [239519]=1932,
		[239520]=1933, [239521]=1933, [239522]=1933, [239523]=1933, [239524]=1933, [239525]=1933, [239526]=1933, [239527]=1933,
		[239529]=1936, [239530]=1936, [239531]=1936, [239532]=1936, [239533]=1936, [239534]=1936, [239535]=1936, [239536]=1936,
		[239537]=1937, [239538]=1937, [239539]=1937, [239540]=1937, [239541]=1937, [239542]=1937, [239543]=1937, [239544]=1937,
		[239547]=1935, [239548]=1935, [239549]=1935, [239550]=1935, [239551]=1935, [239552]=1935, [239553]=1935, [239554]=1935,
		[239555]=1934, [239556]=1934, [239557]=1934, [239558]=1934, [239559]=1934, [239560]=1934, [239561]=1934, [239562]=1934,
		[239565]=1938, [239572]=1938, [239574]=1938, [239575]=1938, [239577]=1938, [239581]=1938, [239582]=1938, [239583]=1938,
		[239584]=1939, [239585]=1939, [239586]=1939, [239587]=1939, [239588]=1939, [239589]=1939, [239590]=1939, [239591]=1939,
		[240020]=1941, [240021]=1941, [240022]=1941, [240023]=1940, [240024]=1940, [240025]=1940, [240026]=1940, [240027]=1940,
		[240028]=1940, [240029]=1940, [240030]=1940, [240031]=1942, [240032]=1942, [240033]=1942, [240034]=1942, [240035]=1942,
		[240036]=1942, [240037]=1942, [240038]=1942, [240039]=1941, [240040]=1941, [240041]=1941, [240042]=1941, [240043]=1941,
		[240044]=1944, [240045]=1944, [240046]=1944, [240047]=1944, [240048]=1944, [240049]=1944, [240050]=1944, [240051]=1944,
		[240052]=1943, [240053]=1943, [240054]=1943, [240055]=1943, [240056]=1943, [240057]=1943, [240058]=1943, [240059]=1943,
		[240060]=1945, [240061]=1945, [240062]=1945, [240063]=1945, [240064]=1945, [240065]=1945, [240066]=1945, [240067]=1945,
		[240068]=1946, [240069]=1946, [240070]=1946, [240071]=1946, [240072]=1946, [240073]=1946, [240074]=1946, [240075]=1946,
		[240076]=1948, [240077]=1948, [240078]=1948, [240079]=1948, [240080]=1948, [240081]=1948, [240082]=1948, [240083]=1948,
		[240084]=1947, [240085]=1947, [240086]=1947, [240087]=1947, [240088]=1947, [240089]=1947, [240090]=1947, [240091]=1947,
		[240092]=1950, [240093]=1950, [240095]=1950, [240096]=1950, [240097]=1950, [240098]=1950, [240099]=1950, [240100]=1950,
		[240101]=1949, [240102]=1949, [240103]=1949, [240104]=1949, [240105]=1949, [240106]=1949, [240107]=1949, [240108]=1949,
		[240109]=1952, [240110]=1952, [240122]=1952, [240123]=1952, [240124]=1952, [240125]=1952, [240126]=1952, [240127]=1952,
		[240128]=1951, [240129]=1951, [240130]=1951, [240131]=1951, [240134]=1951, [240135]=1951, [240136]=1951, [240137]=1951,
		[240138]=1954, [240139]=1954, [240140]=1954, [240141]=1954, [240142]=1954, [240143]=1954, [240144]=1954, [240145]=1954,
		[240146]=1953, [240147]=1953, [240148]=1953, [240149]=1953, [240150]=1953, [240151]=1953, [240152]=1953, [240153]=1953,
		[240852]=1959, [240853]=1955, [240854]=1959, [240922]=1956, [240923]=1956, [246055]=1963, [246056]=1963, [246057]=1963,
		[246058]=1963, [246059]=1963, [246060]=1963, [246061]=1963, [246062]=1963, [250586]=1968, [250587]=1968, [250588]=1968,
		[250589]=321, [250590]=1968, [250591]=1968, [250592]=1968, [250593]=1968, [250594]=1968, [268873]=2071, [271207]=2133,
		[271214]=2133, [272453]=546, [272455]=546, [272457]=546, [272458]=546, [272459]=546, [272462]=382, [272464]=539,
		[272467]=522, [272469]=382, [272470]=382, [272471]=382, [272472]=382, [272473]=522, [272474]=522, [272475]=522,
		[272476]=522, [272477]=281, [272478]=281, [272479]=281, [272480]=281, [272481]=281, [272484]=2094, [272485]=301,
		[272486]=2094, [272487]=2094, [272488]=301, [272489]=301, [272490]=361, [272491]=361, [272492]=361, [272495]=361,
		[272496]=361, [272498]=387, [272499]=387, [272500]=387, [272501]=387, [272504]=387, [272505]=387, [272506]=383,
		[272507]=383, [272508]=383, [272509]=383, [272510]=383, [272513]=383, [272514]=398, [272515]=398, [272516]=398,
		[272517]=398, [272519]=398, [272520]=398, [272523]=393, [272525]=393, [272526]=393, [272527]=393, [272528]=393,
		[272529]=393, [272530]=396, [272531]=396, [272532]=396, [272533]=396, [272534]=396, [272536]=396, [272538]=386,
		[272539]=386, [272542]=386, [272543]=386, [272544]=386, [272545]=386, [272548]=345, [272549]=345, [272552]=345,
		[272553]=345, [272554]=391, [272556]=391, [272558]=391, [272559]=391, [272560]=391, [272561]=391, [272562]=549,
		[272563]=549, [272564]=549, [272565]=549, [272568]=549, [272569]=549, [272570]=390, [272572]=390, [272574]=390,
		[272575]=390, [272576]=390, [272577]=390, [272606]=539, [272608]=522, [272609]=301, [272611]=2072, [272614]=382,
		[272617]=2094, [272619]=2072, [272625]=301, [272626]=539, [272627]=539, [272630]=345, [272634]=2072, [272636]=2094,
		[272637]=281, [272640]=361, [272641]=539, [272642]=539, [272643]=345, [272647]=301, [272648]=2094, [272649]=2072,
		[272650]=2072, [272656]=2081, [272657]=346, [272663]=2072, [272669]=2081, [272670]=2081, [272671]=346, [272677]=2075,
		[272678]=2075, [272680]=546, [272701]=343, [272703]=343, [272704]=348, [272705]=381, [272708]=348, [272709]=381,
		[272713]=362, [272715]=362, [272716]=282, [272717]=282, [272718]=2086, [272719]=2086, [272722]=343, [272723]=343,
		[272724]=343, [272725]=343, [272726]=348, [272727]=348, [272728]=348, [272729]=348, [272730]=381, [272731]=381,
		[272732]=381, [272733]=381, [272734]=362, [272735]=362, [272736]=362, [272737]=362, [272738]=282, [272739]=282,
		[272740]=282, [272741]=282, [272742]=2086, [272743]=2086, [272744]=2086, [272745]=2086, [272746]=388, [272749]=388,
		[272750]=388, [272751]=388, [272752]=388, [272753]=388, [272755]=394, [272757]=397, [272758]=397, [272759]=397,
		[272760]=397, [272761]=397, [272762]=394, [272763]=394, [272764]=394, [272765]=394, [272766]=394, [272768]=397,
		[272771]=395, [272772]=395, [272774]=395, [272775]=395, [272776]=395, [272777]=395, [272780]=2087, [272781]=2087,
		[272782]=2087, [272783]=2087, [272784]=2087, [272785]=2087, [272786]=384, [272787]=384, [272788]=384, [272789]=384,
		[272792]=384, [272793]=384, [272794]=346, [272796]=346, [272800]=346, [272801]=346, [272802]=392, [272803]=392,
		[272804]=392, [272805]=392, [272807]=392, [272808]=392, [272810]=344, [272812]=344, [272814]=344, [272815]=344,
		[272816]=344, [272817]=344, [272818]=389, [272819]=389, [272820]=389, [272821]=389, [272823]=389, [272824]=389,
		[272852]=401, [272853]=401, [272854]=401, [272855]=401, [273044]=2134, [273051]=2134, [273329]=402, [273330]=402,
		[273331]=402, [273332]=402, [273333]=402, [273334]=402, [273336]=2095, [273337]=2095, [273340]=2095, [273341]=2095,
		[273342]=2095, [273343]=2095, [273344]=2091, [273345]=2091, [273348]=2091, [273349]=2091, [273350]=2091, [273351]=2091,
		[273355]=2090, [273356]=2090, [273357]=2090, [273358]=2090, [273359]=2090, [273360]=2090, [273363]=401, [273365]=401,
		[273368]=2081, [273370]=2081, [273371]=2081, [273373]=551, [273374]=551, [273375]=551, [273377]=551, [273379]=551,
		[273380]=551, [273382]=2080, [273383]=2080, [273384]=2080, [273385]=2080, [273386]=2080, [273387]=2080, [273391]=2078,
		[273392]=2078, [273393]=2078, [273394]=2078, [273395]=2078, [273396]=2078, [273399]=2077, [273400]=2077, [273401]=2077,
		[273402]=2077, [273403]=2077, [273404]=2077, [273405]=2079, [273406]=2079, [273407]=2079, [273408]=2079, [273410]=2079,
		[273411]=2079, [273413]=2076, [273414]=2076, [273415]=2076, [273416]=2076, [273418]=2076, [273419]=2076, [273421]=2074,
		[273422]=2074, [273423]=2074, [273424]=2074, [273426]=2074, [273427]=2074, [273429]=2073, [273431]=2073, [273433]=2073,
		[273434]=2073, [273435]=2073, [273436]=2073, [273443]=2075, [273445]=2075, [273447]=2075, [273448]=2075, [274176]=2096,
		[274177]=2088, [274178]=2096, [274179]=2096, [274180]=2088, [274181]=2088, [274183]=2089, [274184]=2089, [274187]=2089,
		[274188]=2089, [274189]=2089, [274190]=2089, [274192]=2088, [274193]=2096, [274194]=2088, [274195]=2096, [274196]=2088,
		[274197]=2096, [274198]=2097, [274199]=2097, [274202]=2097, [274203]=2097, [274204]=2097, [274205]=2097, [274206]=2093,
		[274207]=2093, [274210]=2093, [274211]=2093, [274212]=2093, [274213]=2093, [274217]=2092, [274218]=2092, [274219]=2092,
		[274220]=2092, [274221]=2092, [274222]=2092, [274226]=2084, [274227]=2084, [274230]=2084, [274231]=2084, [274232]=2084,
		[274233]=2084, [274236]=2085, [274237]=2085, [274238]=2085, [274239]=2085, [274240]=2085, [274241]=2085, [274244]=2082,
		[274245]=2082, [274246]=2082, [274247]=2082, [274250]=2083, [274251]=2083, [274252]=2083, [274253]=2083, [274254]=2083,
		[274255]=2083, [274256]=2082, [274258]=2082, [275005]=2135, [275006]=2135, [276741]=2136, [276746]=2136, [277117]=1,
		[278476]=241, [280450]=2098, [280451]=2098, [280452]=2098, [280453]=2098, [280454]=2098, [280455]=2098, [280872]=2099,
		[280875]=2099, [280876]=2099, [280877]=2099, [280878]=2099, [280879]=2099, [280882]=2100, [280883]=2100, [280886]=2100,
		[280887]=2100, [280888]=2100, [280889]=2100, [280893]=2101, [280894]=2101, [280895]=2101, [280896]=2101, [280897]=2101,
		[280898]=2101, [280899]=2102, [280900]=2102, [280901]=2102, [280902]=2102, [280903]=2102, [280904]=2102, [280905]=2103,
		[280906]=2103, [280907]=2103, [280908]=2103, [280909]=2103, [280910]=2103, [280912]=2104, [280913]=2104, [280914]=2104,
		[280915]=2104, [280917]=2104, [280918]=2104, [280919]=2105, [280920]=2105, [280921]=2105, [280922]=2105, [280923]=2105,
		[280924]=2105, [280925]=2106, [280926]=2106, [280927]=2106, [280928]=2106, [280929]=2106, [280930]=2106, [280931]=2107,
		[280932]=2107, [280933]=2107, [280934]=2107, [280935]=2107, [280936]=2107, [280937]=2108, [280938]=2108, [280939]=2108,
		[280940]=2108, [280941]=2108, [280942]=2108, [280944]=2109, [280945]=2109, [280947]=2109, [280949]=2109, [280950]=2109,
		[280951]=2109, [280952]=2110, [280953]=2110, [280954]=2110, [280955]=2110, [280956]=2110, [280957]=2110, [280958]=2111,
		[280959]=2111, [280960]=2111, [280961]=2111, [280962]=2111, [280963]=2111, [280965]=2112, [280967]=2112, [280971]=2112,
		[280974]=2112, [280976]=2112, [280977]=2112, [280986]=2113, [280987]=2113, [280988]=2113, [280989]=2113, [280990]=2113,
		[280991]=2113, [280992]=2115, [280993]=2115, [280994]=2115, [280995]=2115, [280996]=2115, [280997]=2115, [280998]=2114,
		[280999]=2114, [281000]=2114, [281001]=2114, [281002]=2114, [281003]=2114, [284100]=2130, [284101]=2130, [284102]=2130,
		[284715]=2131, [284716]=2131, [285329]=2132, [285330]=2132, [285331]=2132, [286978]=2133, [286979]=2133, [286980]=2133,
		[286987]=2134, [286988]=2134, [286989]=2134, [287012]=2135, [287013]=2135, [287014]=2135, [287019]=2136, [287020]=2136,
		[287021]=2136, [288823]=2138, [288824]=2138, [288825]=2138, [288826]=2138, [288827]=2138, [288828]=2138, [288829]=2138,
		[288830]=2138, [288831]=2139, [288832]=2139, [288833]=2139, [288834]=2139, [288835]=2139, [288836]=2139, [288837]=2139,
		[288838]=2139, [288839]=2140, [288840]=2140, [288841]=2140, [288842]=2140, [288843]=2140, [288844]=2140, [288845]=2140,
		[288846]=2140, [288847]=2141, [288848]=2141, [288849]=2141, [288850]=2141, [288851]=2141, [288852]=2141, [288853]=2141,
		[288854]=2141, [288855]=2142, [288856]=2142, [288857]=2142, [288858]=2142, [288859]=2142, [288860]=2142, [288861]=2142,
		[288862]=2142, [288863]=2143, [288864]=2143, [288865]=2143, [288866]=2143, [288867]=2143, [288868]=2143, [288869]=2143,
		[288870]=2143, [288871]=2144, [288872]=2144, [288873]=2144, [288874]=2144, [288875]=2144, [288876]=2144, [288877]=2144,
		[288878]=2144, [288879]=2145, [288880]=2145, [288881]=2145, [288882]=2145, [288883]=2145, [288884]=2145, [288885]=2145,
		[288886]=2145, [288887]=2146, [288888]=2146, [288889]=2146, [288890]=2146, [288891]=2146, [288892]=2146, [288893]=2146,
		[288894]=2146,
	},
}
