-- Notes for each boss, by dungeon (Josh 2026-11-06: "crucial role specific
-- notes", the way TrueParse has them).
--
-- WHERE THEY COME FROM. Two guides per dungeon where two exist, read and
-- reconciled in docs/encounters/<dungeon>.md: what each says, where they
-- agree, and where they don't. A line one trusted guide gives and nothing
-- contradicts is kept. Where the guides disagree the line is left out, or
-- both answers are written (Josh 2026-11-06). The player never sees a
-- source; the research files keep them. The sources: Warcraft Tavern and
-- Method for each dungeon they cover, and the Warcraft Wiki
-- (warcraft.wiki.gg) for the abilities and the rest.
--
-- THE FIRST BATCH (Josh 2026-11-06): every dungeon that starts below level
-- 30. The rest come in later releases.
--
-- THE SHAPE. Keyed by the dungeon's name as a zone key (BT.Quests.ZoneKey:
-- "The Deadmines" is "deadmines"). Each boss, in the order a run meets them:
--   name      as the game writes it
--   npc       its npc ids: how a nameplate or a target is matched. The
--             Classic bosses' are VMaNGOS's, the new Forever bosses' the
--             Warcraft Wiki's. A boss with none is matched by name.
--   also      other names that are this fight (Sneed is the Shredder's)
--   optional  a boss a run can skip
--   place     a word on where, or what comes with it
--   lines     { text } for everyone, { text, role = "tank" | "healer" |
--             "dps" }, or { text, need = a skill in BT.Encounter.SKILLS }
-- A WING (Scarlet Monastery) names its instance in `instance`: the game
-- may call every wing by the monastery's name, and the wing is then the
-- one whose boss is seen (BT.Encounter.Here).
local _, BT = ...

BT.EncounterNotes = {
	-- Warcraft Tavern, Method and the Warcraft Wiki
	ragefirechasm = {
		name = "Ragefire Chasm",
		bosses = {
			{ name = "Oggleflint", npc = { 11517 }, lines = {
				{ "Troggs stand around him. Pull some of them before the boss." },
				{ "Kill his two adds first." },
				{ "He cleaves. Face him away from the group.", role = "tank" },
			} },
			{ name = "Taragaman the Hungerer", npc = { 11520 }, lines = {
				{ "Pull the patrols before you pull him." },
				{ "Fire Nova burns everyone in melee range." },
				{ "Uppercut knocks you back. Tank him in the middle of his platform, away from the lava.", role = "tank" },
			} },
			{ name = "Jergosh the Invoker", npc = { 11518 }, lines = {
				{ "Clear the cultists around him first." },
				{ "Guides differ on the kill order. Some kill his two adds first. Others kill Jergosh first." },
				{ "He hits the group hard. Watch your mana.", role = "healer" },
				{ "Immolate. Kick it to spare the tank.", need = "kick" },
				{ "Remove Curse of Weakness from the tank.", need = "curse" },
			} },
			{ name = "Bazzalan", npc = { 11519 }, lines = {
				{ "Two Searing Blade Cultists stand in front of him. Pull him without them if you can." },
				{ "He swings fast and hits hard with Sinister Strike.", role = "tank" },
				{ "Remove his poison from the tank.", need = "poison" },
			} },
		},
	},

	-- Method (updated 15 Oct 2026), Warcraft Tavern and the Warcraft Wiki
	hallofthanes = {
		name = "The Hall of Thanes",
		bosses = {
			{ name = "Faldrim Anvilmar", npc = { 261306 }, place = "Anvilmar's Rest", lines = {
				{ "He patrols his tomb with undead around him. Clear the room before you pull him." },
				{ "Anvilmar's Curse slows your attacks and casts by 20% for 10 minutes.", role = "tank" },
				{ "Remove Anvilmar's Curse from the tank.", need = "curse" },
				{ "Mind Blast. Kick it when you can.", need = "kick" },
			} },
			{ name = "Magmatus", npc = { 261316 }, lines = {
				{ "A Dark Iron Summoner fights with him. Kill the Summoner first." },
				{ "Fire Nova burns everyone near him. Ranged, stay back." },
				{ "Drag Magmatus away from the group while they kill the Summoner.", role = "tank" },
				{ "Melee take Fire Nova too. Expect to heal them as much as the tank.", role = "healer" },
				{ "The Summoner's Fireball and its summon.", need = "kick" },
				{ "Stun the Summoner when nobody can kick.", need = "stun" },
			} },
			{ name = "Plunder", npc = { 261311 }, lines = {
				{ "Knock Away is his main ability. Fight him in a corner, away from other packs." },
				{ "Put your back to a wall so the knock can't send you into trash.", role = "tank" },
				{ "He charges people near him. Ranged, keep your distance.", role = "dps" },
			} },
			{ name = "Durgen Dirgehammer", npc = { 261319 }, also = { "Dirgen Dirgehammer" }, place = "Reliquary of Kings", lines = {
				{ "Clear the Dark Iron Looters around his platform before the pull." },
				{ "He fears everyone for 8 seconds. Feared players can run into other packs." },
				{ "Guides differ on the kill order. Some kill Durgen first. Others kill the two Lesser Stone Golems first." },
				{ "Rend bleeds you every 3 seconds.", role = "tank" },
				{ "Put Tremor Totem down before the pull.", need = "fear" },
			} },
		},
	},

	-- Warcraft Tavern, Method and the Warcraft Wiki. Two paths, one for each
	-- side; the bosses are the same.
	ruinsoflordaeron = {
		name = "Ruins of Lordaeron",
		bosses = {
			{ name = "Witherfang", npc = { 250483 }, lines = {
				{ "She patrols Kings Alley. Clear her path and pull her on her own." },
				{ "Guides differ on the kill order. Some kill her Broodlings first. Others kill Witherfang first." },
				{ "Cure Leech Poison on the tank if you can.", need = "poison" },
			} },
			{ name = "The Baron", npc = { 250660 }, lines = {
				{ "Trample hits everyone in melee range." },
				{ "While the tank is stunned he turns to the next player. Ranged, spread out." },
				{ "Keep your back to a wall. Knockout knocks you back and stuns you.", role = "tank" },
				{ "Knockout takes nearly half the tank's health. Keep the tank near full.", role = "healer" },
				{ "He can be stunned.", need = "stun" },
			} },
			{ name = "Viktor the Vile", npc = { 256035 }, optional = true, place = "fireplace event", lines = {
				{ "Click the fireplace in the burned house to start. Five waves of adds come before him." },
				{ "Start with full mana. There is little time between waves." },
				{ "Cure Leech Poison on the tank if you can.", need = "poison" },
			} },
			{ name = "The Abandoned", npc = { 250631 }, place = "statue event", lines = {
				{ "Walk up to the statue in Market Square to start. Three waves of adds come before him." },
				{ "Frost Nova roots everyone near him. Melee who hit him are chilled." },
				{ "Life Drain.", need = "kick" },
				{ "Stun him as he starts Life Drain.", need = "stun" },
			} },
			{ name = "Bjork", npc = { 256097 }, lines = {
				{ "He patrols the middle of the ruins. Don't pull the ghouls with him." },
				{ "Anti-Magic Shield makes him immune to spells for a few seconds. Use physical attacks or wait.", role = "dps" },
			} },
			{ name = "Rath'mael", npc = { 250657 }, place = "the graveyard", lines = {
				{ "Flamestrike lands on the tank. Stand away from the tank." },
				{ "Move him out of the fire after each Flamestrike.", role = "tank" },
				{ "Stun him to stop a Flamestrike.", need = "stun" },
			} },
		},
	},

	-- Warcraft Tavern, Method and the Warcraft Wiki. Kresh wanders, so a run
	-- may meet him first.
	wailingcaverns = {
		name = "Wailing Caverns",
		bosses = {
			{ name = "Lady Anacondra", npc = { 3671 }, lines = {
				{ "She patrols the first area. Pull her away from the other druids." },
				{ "Thorns Aura hurts anyone who hits her in melee.", role = "dps" },
				{ "Druid's Slumber first, then Healing Touch and Lightning Bolt.", need = "kick" },
			} },
			{ name = "Kresh", npc = { 3653 }, optional = true, place = "wanders the stream", lines = {
				{ "Crushing Bite lowers your armor. Face him away from the group.", role = "tank" },
				{ "His armor is high. Spells do more than weapons here.", role = "dps" },
			} },
			{ name = "Lord Cobrahn", npc = { 3669 }, lines = {
				{ "Three Deviate Pythons come with him. AoE them down first." },
				{ "Below half health he turns into a snake and hits harder." },
				{ "Keep your HoTs on the tank in case Druid's Slumber puts you to sleep.", role = "healer" },
				{ "Druid's Slumber first. It can sleep your healer.", need = "kick" },
			} },
			{ name = "Lord Pythas", npc = { 3670 }, lines = {
				{ "A Druid of the Fang and a Deviate Shambler fight with him. Kill or crowd-control them first." },
				{ "Thunderclap slows your attacks and movement.", role = "tank" },
				{ "Druid's Slumber, Healing Touch and Lightning Bolt, from him and his druid.", need = "kick" },
			} },
			{ name = "Skum", npc = { 3674 }, lines = {
				{ "Chained Bolt jumps between players. Spread out." },
				{ "Face him away from the group.", role = "tank" },
				{ "He is immune to nature damage.", role = "dps" },
				{ "Chained Bolt.", need = "kick" },
			} },
			{ name = "Lord Serpentis", npc = { 3673 }, lines = {
				{ "Kill the Druids of the Fang around him before the pull." },
				{ "Sleep and Healing Touch.", need = "kick" },
			} },
			{ name = "Verdan the Everliving", npc = { 5775 }, lines = {
				{ "Grasping Vines knocks down and roots everyone within 10 yards. Ranged, stay back." },
				{ "He hits the tank very hard. Use shields and HoTs while the tank is knocked down.", role = "healer" },
			} },
			{ name = "Mutanus the Devourer", npc = { 3654 }, place = "the Naralex escort", lines = {
				{ "After the four Fang lords die, escort the Disciple of Naralex. Clear the way before you start." },
				{ "Waves of adds come before Mutanus. Keep them off the Disciple." },
				{ "Tank him away from the Disciple.", role = "tank" },
				{ "Terrify fears one player for 4 seconds.", need = "fear" },
				{ "Naralex's Nightmare puts a player to sleep.", need = "kick" },
			} },
		},
	},

	-- Method, Warcraft Tavern and the Warcraft Wiki. Npc ids from VMaNGOS.
	deadmines = {
		name = "The Deadmines",
		bosses = {
			{ name = "Rhahk'Zor", npc = { 644 }, lines = {
				{ "Two Defias Watchmen shoot from range. Kill them first." },
				{ "Rhahk'Zor Slam hits hard and stuns you for 3 seconds.", role = "tank" },
				{ "Polymorph one Watchman if both come with him.", need = "cc" },
			} },
			{ name = "Sneed's Shredder", npc = { 642, 643 }, also = { "Sneed" }, place = "then Sneed", lines = {
				{ "Clear the Goblin Woodcarvers first. The Shredder's Terrify can fear players into them." },
				{ "Sneed jumps out when the Shredder dies. Kill him too." },
				{ "Sneed starts with no threat on you. Taunt him. He disarms you.", role = "tank" },
				{ "Don't pull the Shredder off the tank. Distracting Pain goes on whoever it hits.", role = "dps" },
			} },
			{ name = "Gilnid", npc = { 1763 }, lines = {
				{ "The room is full of Craftsmen and Engineers. Clear at least one side first." },
				{ "Molten Metal on you cuts your threat while it lasts.", role = "tank" },
				{ "Ease off while Molten Metal is on the tank.", role = "dps" },
			} },
			{ name = "Mr. Smite", npc = { 646 }, lines = {
				{ "Two stealthed Blackguards stand by him. Kill them first." },
				{ "Each Smite Stomp stuns everyone and changes his weapons. With two, he hits much harder." },
				{ "Save your defensives for the two-weapon phase.", role = "tank" },
				{ "Save your mana for the two-weapon phase.", role = "healer" },
			} },
			{ name = "Cookie", npc = { 645 }, optional = true, place = "lower deck", lines = {
				{ "Acid Splash burns the tank over time." },
				{ "Cookie's Cooking heals him.", need = "kick" },
			} },
			{ name = "Captain Greenskin", npc = { 647 }, lines = {
				{ "He is easy to pull together with VanCleef. Pull Greenskin on his own." },
				{ "Kill the Defias Companion first. It has little health." },
				{ "Then guides differ. Some kill Greenskin next. Others kill his two other adds." },
				{ "Poisoned Harpoon and Cleave hit you.", role = "tank" },
			} },
			{ name = "Edwin VanCleef", npc = { 639 }, place = "the ship", lines = {
				{ "At half health he calls two more Blackguards." },
				{ "Kill the first two adds. Crowd-control or ignore the new ones. Burn VanCleef." },
				{ "He hits hard. Hold the first two adds on you.", role = "tank" },
				{ "A long fight. Pace your mana.", role = "healer" },
				{ "Stun him as he reaches half health. He then calls no more Blackguards.", need = "stun" },
			} },
		},
	},

	-- Warcraft Tavern, Method and the Warcraft Wiki
	shadowfangkeep = {
		name = "Shadowfang Keep",
		bosses = {
			{ name = "Rethilgore", npc = { 3914 }, lines = {
				{ "Two Bleak Worgs and a Shadowfang Whitescalp fight with him. Kill them first." },
				{ "Soul Drain roots a player and drains their health.", role = "healer" },
				{ "Stun his adds to kill them faster.", need = "stun" },
			} },
			{ name = "Razorclaw the Butcher", npc = { 3886 }, lines = {
				{ "A patrol walks outside his room. Kill it before you pull him." },
				{ "Kill his adds first." },
				{ "He uses Butcher Drain on you over and over.", role = "tank" },
			} },
			{ name = "Baron Silverlaine", npc = { 3887 }, lines = {
				{ "Clear the room of adds before you pull him." },
				{ "Veil of Shadow cuts healing on the tank by 75%.", role = "healer" },
				{ "Remove Veil of Shadow from the tank.", need = "curse" },
				{ "Veil of Shadow.", need = "kick" },
			} },
			{ name = "Commander Springvale", npc = { 4278 }, lines = {
				{ "His room is full of adds. Pull them in small groups." },
				{ "Kill the Wailing Guardsman first. Its Screams of the Past silences." },
				{ "Hammer of Justice stuns you.", role = "tank" },
				{ "Holy Light, above all after his Divine Shield at 30% health.", need = "kick" },
			} },
			{ name = "Odo the Blindwatcher", npc = { 4279 }, lines = {
				{ "Two Vile Bats fight with him. Kill them first." },
				{ "Howling Rage makes him hit harder as his health drops." },
				{ "The bats cleave and disarm. Face them away from the group.", role = "tank" },
				{ "Damage grows through the fight. Save mana for the end.", role = "healer" },
			} },
			{ name = "Fenrus the Devourer", npc = { 4274 }, lines = {
				{ "He hits hard. Use your defensive cooldowns.", role = "tank" },
				{ "Toxic Saliva. Cure it.", need = "poison" },
			} },
			{ name = "Wolf Master Nandos", npc = { 3927 }, lines = {
				{ "Four wolves guard him. He joins the fight when they die." },
				{ "He calls more wolves during the fight. Kill each one as it comes." },
				{ "His wolves hit hard. Watch your mana.", role = "healer" },
			} },
			{ name = "Archmage Arugal", npc = { 4275 }, lines = {
				{ "Three worgen stand in his room. Kill them first." },
				{ "He teleports around the room." },
				{ "Void Bolt hits hard. Step out of his sight when he casts it.", role = "tank" },
				{ "Arugal's Curse can't be removed. Heal the damage it does.", role = "healer" },
				{ "Arugal's Curse turns a player against the group for 10 seconds. Crowd-control them.", need = "cc" },
			} },
		},
	},

	-- Method, Warcraft Tavern and the Warcraft Wiki
	stockade = {
		name = "The Stockade",
		bosses = {
			{ name = "Targorr the Dread", npc = { 1696 }, lines = {
				{ "He can be in any cell of the first hallway. Look before you pull." },
				{ "Kill the prisoners with him first." },
				{ "He enrages at 20% health.", role = "tank" },
			} },
			{ name = "Dextren Ward", npc = { 1663 }, lines = {
				{ "Intimidating Shout fears everyone near him. Pull him where nobody can run into other cells." },
				{ "Put Tremor Totem down for his fear.", need = "fear" },
			} },
			{ name = "Kam Deepfury", npc = { 1666 }, lines = {
				{ "Shield Slam stuns you for 2 seconds. Build threat early.", role = "tank" },
				{ "Expect the tank's health to drop fast while it is stunned.", role = "healer" },
			} },
			{ name = "Hamhock", npc = { 1717 }, lines = {
				{ "Two Defias stand with him. Kill them first." },
				{ "Chain Lightning.", need = "kick" },
				{ "Remove Bloodlust from him and his adds.", need = "purge" },
				{ "Stun him to stop his damage.", need = "stun" },
			} },
			{ name = "Bazil Thredd", npc = { 1716 }, lines = {
				{ "Clear the room before you pull him." },
				{ "Smoke Bomb stuns everyone near him for 4 seconds. Ranged, stay away." },
				{ "When the tank is stunned he turns to the next player. Be ready to move." },
				{ "He wields two swords and hits hard.", role = "tank" },
			} },
		},
	},

	-- Warcraft Tavern, Method and the Warcraft Wiki. Lorgus Jett and Baron
	-- Aquanis are left out: quest kills with nothing to say.
	blackfathomdeeps = {
		name = "Blackfathom Deeps",
		bosses = {
			{ name = "Ghamoo-ra", npc = { 4887 }, lines = {
				{ "Trample hits everyone near him." },
				{ "Face him away from the group.", role = "tank" },
				{ "His armor is high. Spells do more than weapons. Sunder Armor and Faerie Fire help.", role = "dps" },
			} },
			{ name = "Lady Sarevess", npc = { 4831 }, lines = {
				{ "Two naga fight with her. Crowd-control one and kill the other first." },
				{ "Spread out. Forked Lightning chains between players." },
				{ "Forked Lightning hits a cone in front of her. Face her away from the group.", role = "tank" },
				{ "Forked Lightning. She casts Frost Nova when you kick it.", need = "kick" },
			} },
			{ name = "Gelihast", npc = { 6243 }, optional = true, lines = {
				{ "Pull the murlocs in his room a few at a time. Then pull him alone." },
				{ "Net roots a player." },
				{ "Click the stone behind him after the kill for Blessing of Blackfathom." },
			} },
			{ name = "Old Serra'kis", npc = { 4830 }, optional = true, place = "underwater", lines = {
				{ "You fight him underwater. Watch your breath." },
				{ "He heals himself as he hits. Kill him quickly." },
				{ "A shaman's Water Breathing or a warlock's Unending Breath helps." },
			} },
			{ name = "Twilight Lord Kelris", npc = { 4832 }, lines = {
				{ "Clear the adds in his room first. Pull the casters behind the wall at the entrance." },
				{ "Sleep puts players near him to sleep. Mind Blast hits the tank." },
				{ "If the tank is asleep, he turns to the next player." },
				{ "Dispel Sleep from the tank first.", need = "magic" },
			} },
			{ name = "Aku'mai", npc = { 4829 }, lines = {
				{ "Light the four braziers one at a time. Each one calls a wave of adds." },
				{ "Poison Cloud hurts everyone in it. Move out." },
				{ "Frenzied Rage makes her attack 75% faster for 5 seconds. Use a defensive cooldown.", role = "tank" },
				{ "Save your stuns for her Frenzied Rage.", need = "stun" },
			} },
		},
	},

	-- Warcraft Tavern, Method and the Warcraft Wiki
	excavationsitewetlands = {
		name = "Excavation Site: Wetlands",
		bosses = {
			{ name = "Saltspine", npc = { 260322 }, lines = {
				{ "He patrols the crocolisk lake. Clear a dry spot before you pull him." },
				{ "Dust Storm hits everyone within 10 yards and makes attacks miss. Ranged and healers, stay back." },
				{ "Dust Storm lowers your threat. Keep building it.", role = "tank" },
			} },
			{ name = "Shadetooth", npc = { 260325 }, lines = {
				{ "Raptors hide in the tall grass. Clear them before you pull him." },
				{ "Terrifying Roar fears everyone, often into the grass." },
				{ "Rend bleeds you. He enrages at 20% health.", role = "tank" },
				{ "Tremor Totem stops his fear. So does Fear Ward on the tank.", need = "fear" },
			} },
			{ name = "Highland Horror", npc = { 260808 }, optional = true, place = "Alliance quest", lines = {
				{ "Slimes surround him. Pull him away from them." },
				{ "Entangling Roots holds everyone near him for a long time. Stand where you want to be first." },
				{ "Wild Regeneration.", need = "kick" },
			} },
			{ name = "Relic Guardian", npc = { 260326 }, lines = {
				{ "Use the panel next to him to wake him. He is level 31, so expect more misses." },
				{ "War Stomp knocks back and stuns everyone near him. Ranged, stay back." },
				{ "Arcing Smash hits a cone in front of him. Face him away from the group.", role = "tank" },
				{ "Keep away from edges. Knock Away throws you back.", role = "tank" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	gnomeregan = {
		name = "Gnomeregan",
		bosses = {
			{ name = "Grubbis", npc = { 7361 }, also = { "Chomper" }, place = "Emi's event", lines = {
				{ "Talk to Blastmaster Emi Shortfuse to start the event. Grubbis comes at the end." },
				{ "Kill his pet Chomper first." },
				{ "Both can be stunned or feared." },
			} },
			{ name = "Viscous Fallout", npc = { 7079 }, lines = {
				{ "Toxic Volley poisons everyone near it." },
				{ "It is immune to frost damage.", role = "dps" },
			} },
			{ name = "Electrocutioner 6000", npc = { 6235 }, lines = {
				{ "Chain Bolt jumps between players. Spread out." },
				{ "It drops the Workshop Key, a way back in." },
				{ "Megavolt hits a cone in front of it. Face it away from the group.", role = "tank" },
			} },
			{ name = "Crowd Pummeler 9-60", npc = { 6229 }, lines = {
				{ "Crowd Pummel and Trample hit everyone near it. Casters, stay at range." },
				{ "Put your back to a wall, away from the healer. Arcing Smash hits in front of it.", role = "tank" },
			} },
			{ name = "Mekgineer Thermaplugg", npc = { 7800 }, lines = {
				{ "He calls Walking Bombs from the machines. Kill them before they reach the group." },
				{ "Below half health the bombs come faster. Faster again below 20%." },
				{ "Tank him in the middle of the room so the bombs walk farther.", role = "tank" },
				{ "Knock Away wipes his threat. Taunt him back at once.", role = "tank" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. The rare bosses are left out.
	scarletmonasterygraveyard = {
		name = "Scarlet Monastery Graveyard",
		instance = "scarletmonastery",
		bosses = {
			{ name = "Interrogator Vishas", npc = { 3983 }, lines = {
				{ "Scarlet Crusade members stand with him. Kill them first." },
				{ "Dispel his Immolate and Shadow Word: Pain.", need = "magic" },
			} },
			{ name = "Bloodmage Thalnos", npc = { 4543 }, place = "bottom of the crypt", lines = {
				{ "Clear the whole crypt to reach him." },
				{ "Flame Spike burns the ground under players. Move out." },
				{ "Fire Nova burns everyone near him." },
				{ "Stand far from him. Flame Spike lands where players stand.", role = "healer" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	scarletmonasterylibrary = {
		name = "Scarlet Monastery Library",
		instance = "scarletmonastery",
		bosses = {
			{ name = "Houndmaster Loksey", npc = { 3974 }, lines = {
				{ "Three Scarlet Tracking Hounds fight with him. Kill them first." },
				{ "With Bloodlust up they hit very hard. Use defensive cooldowns.", role = "tank" },
				{ "Remove Bloodlust from him and his hounds.", need = "purge" },
			} },
			{ name = "Arcanist Doan", npc = { 6487 }, lines = {
				{ "At half health he casts Detonation. Run out of his room and hide by the wall outside." },
				{ "Silence hits everyone within 10 yards. Casters, stay back." },
				{ "Dispel Polymorph.", need = "magic" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. The rare bosses are left out.
	razorfenkraul = {
		name = "Razorfen Kraul",
		bosses = {
			{ name = "Roogug", npc = { 6168 }, lines = {
				{ "A Death's Head Seer and a Stone Rumbler fight with him. Kill the Seer first." },
				{ "Lightning Bolt.", need = "kick" },
			} },
			{ name = "Aggem Thorncurse", npc = { 4424 }, lines = {
				{ "He keeps calling boar spirits. Kill each one quickly. They have little health." },
				{ "If a boar spirit hits you, run to the tank.", role = "healer" },
				{ "Chain Heal.", need = "kick" },
			} },
			{ name = "Death Speaker Jargba", npc = { 4428 }, lines = {
				{ "Kill the Death's Head Acolyte first, then the Razorfen Groundshaker, then Jargba." },
				{ "Stay in melee range. He casts Shadow Bolt when nobody is.", role = "tank" },
				{ "Stay away from Jargba and the Groundshaker. One controls minds, the other stuns.", role = "healer" },
				{ "The Acolyte's Mana Burn.", need = "kick" },
				{ "Dominate Mind takes control of a player. Dispel it.", need = "magic" },
			} },
			{ name = "Overlord Ramtusk", npc = { 4420 }, lines = {
				{ "Two Razorfen Spearhides guard him. Crowd-control them, or kill them first." },
				{ "Melee, step away when the Spearhides spin. Whirling Barrage hits everyone near them." },
				{ "Thunderclap slows your attacks.", role = "tank" },
			} },
			{ name = "Agathelos the Raging", npc = { 4422 }, lines = {
				{ "Kill the Death's Head Seer and the two Ward Guardians to free him." },
				{ "Stay in melee range, casters too. Rushing Charge hits anyone farther away." },
				{ "If he falls before his health runs out, he is faking. Keep hitting him." },
				{ "He hits very hard. Keep a potion or healthstone ready.", role = "tank" },
			} },
			{ name = "Charlga Razorflank", npc = { 4421 }, lines = {
				{ "Chain Bolt jumps between players. Spread out." },
				{ "Tank her in the middle of the ramp outside her hut. She teleports back to it.", role = "tank" },
				{ "Skip DoTs. Purity removes them and makes her immune for a moment.", role = "dps" },
				{ "She is immune to shadow damage.", role = "dps" },
			} },
		},
	},

	-- Warcraft Tavern, Method and the Warcraft Wiki. The guides give the
	-- bosses in different orders; this is Warcraft Tavern's.
	cityofdalaran = {
		name = "City of Dalaran",
		bosses = {
			{ name = "Atrexis the Grave Knight", npc = { 247126 }, place = "the sewers", lines = {
				{ "Kill the necromancers around him without pulling him." },
				{ "He disarms you and keeps raising skeletons. Pick them up.", role = "tank" },
				{ "Unholy Frenzy makes him hit the tank much harder.", role = "healer" },
				{ "Remove Unholy Frenzy from him.", need = "purge" },
			} },
			{ name = "Lyn the Ignored", npc = { 247032 }, optional = true, place = "Tome of Dalaran", lines = {
				{ "Use the Tome of Dalaran in the square room by the sewer exit to call him." },
				{ "He raises skeletons. Shadow Bolt Volley hits everyone." },
				{ "Remove Curse of Thorns from the tank.", need = "curse" },
			} },
			{ name = "Mana Devourer", npc = { 246008 }, place = "the Violet Hold", lines = {
				{ "Clear the whole room first. Anything left joins the fight." },
				{ "Debilitate hits everyone and drains mana." },
				{ "Drain Vitality burns the tank over time. Heal through it.", role = "healer" },
			} },
			{ name = "Arcane Anomaly", npc = { 245999 }, lines = {
				{ "Focal Blast sweeps a beam around it. Stand right behind it and walk with the beam." },
				{ "Arcane Bolt hits you hard.", role = "tank" },
			} },
			{ name = "Fel Ancient", npc = { 246003 }, place = "Runeweaver Square", lines = {
				{ "Talk to Grindle Firespark to take down the barriers around it." },
				{ "Entangle roots players. Fel Timbers puts a green pool under them. Get out of it fast." },
				{ "Blessing of Freedom removes the roots." },
			} },
			{ name = "Arcanic Enigma", npc = { 246016 }, lines = {
				{ "Two Mana Phantoms fight with it. Kill them first." },
				{ "It silences everyone near it. Ranged, stay back." },
				{ "It calls Manalings during the fight." },
				{ "The Mana Phantoms' Mana Burn.", need = "kick" },
				{ "Dispel Manamorph from a player.", need = "magic" },
			} },
			{ name = "Unstable Sentinel", npc = { 246017 }, also = { "Unstable Sentry" }, lines = {
				{ "Malfunction hits everyone within 25 yards. Move away when it casts." },
				{ "Arcing Smash hits a cone in front of it. Face it away from the group.", role = "tank" },
				{ "Stun it before Malfunction to stop the cast.", need = "stun" },
			} },
			{ name = "Shade of the Archmage", npc = { 246020 }, place = "the Violet Citadel", lines = {
				{ "Talk to Archmage Modera on the citadel steps for the portal." },
				{ "Bounding Mana sends a sphere out and back. Stay out of its path." },
				{ "Arcane Explosion hits everyone within 20 yards after the sphere returns." },
				{ "At 0 mana he casts Mass Polymorph, then Evocation. The fight starts over." },
				{ "The room is small. Ranged, spread out." },
			} },
		},
	},
}
