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
-- 30. The second batch, at the end of the list, has the rest.
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

	-- THE SECOND BATCH (Josh 2026-11-07: "let's finish the remaining
	-- dungeons"). Every dungeon from level 32 up that the original game had.
	-- Method has no guide for these yet, so the sources are Warcraft Tavern's
	-- Forever guides and the Warcraft Wiki's boss pages. Npc ids from VMaNGOS.
	-- Rares and the bosses only a quest summons (Tier 0.5, the class mounts)
	-- are left out, as in the first batch. The five dungeons new in Forever
	-- (The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold,
	-- Shaper's Terrace) have none: no guide has seen inside them yet.

	-- Warcraft Tavern and the Warcraft Wiki
	scarletmonasteryarmory = {
		name = "Scarlet Monastery Armory",
		instance = "scarletmonastery",
		bosses = {
			{ name = "Herod", npc = { 3975 }, lines = {
				{ "Whirlwind hits everyone near him. He takes no damage while it spins. Step away." },
				{ "When he dies, a large pack of trainees rushes into his room." },
				{ "Step out of Whirlwind. When he dies, wait at his door to gather the pack.", role = "tank" },
				{ "Let the tank gather the pack before you use area damage.", role = "dps" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	scarletmonasterycathedral = {
		name = "Scarlet Monastery Cathedral",
		instance = "scarletmonastery",
		bosses = {
			{ name = "High Inquisitor Fairbanks", npc = { 4542 }, place = "a side room", lines = {
				{ "He heals himself when low. His other spells can be kicked too." },
				{ "He dispels the tank's buffs often.", role = "tank" },
				{ "Keep everyone topped up. His spells can sleep or fear players.", role = "healer" },
				{ "His Heal.", need = "kick" },
			} },
			{ name = "Scarlet Commander Mograine", npc = { 3976, 3977 }, also = { "High Inquisitor Whitemane" },
				place = "then Whitemane", lines = {
				{ "Whitemane joins once Mograine falls." },
				{ "At half health she sleeps everyone and raises Mograine at full health." },
				{ "After she raises him, many groups kill Whitemane first." },
				{ "She can mind control a player if the fight runs long." },
				{ "Be ready to take Whitemane as soon as she joins.", role = "tank" },
				{ "Two fights in one. Pace your mana.", role = "healer" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	razorfendowns = {
		name = "Razorfen Downs",
		bosses = {
			{ name = "Tuten'kash", npc = { 7355 }, place = "the gong", lines = {
				{ "Ring the gong three times. Two waves of spiders come first, then Tuten'kash." },
				{ "Face him away from the group. Web Spray hits in front of him.", role = "tank" },
				{ "Stand behind him, out of Web Spray.", role = "dps" },
				{ "Curse of Tuten'kash, on healers and casters first.", need = "curse" },
			} },
			{ name = "Plaguemaw the Rotting", npc = { 7356 }, optional = true, place = "Belnistrasz's escort", lines = {
				{ "Guard Belnistrasz while he works. Waves of enemies come at him. He can't be healed." },
				{ "Plaguemaw comes last. He is the easy part." },
				{ "Pick up each wave away from Belnistrasz and the healer.", role = "tank" },
				{ "Hold what you can during the waves.", need = "cc" },
			} },
			{ name = "Mordresh Fire Eye", npc = { 7357 }, lines = {
				{ "Weak skeletons stand round him. Kill them with area damage, then Mordresh." },
				{ "Wait for the tank to hold the skeletons before you heal.", role = "healer" },
				{ "His Fireball.", need = "kick" },
			} },
			{ name = "Glutton", npc = { 8567 }, lines = {
				{ "Stay out of his Disease Cloud." },
				{ "Face him away from the group.", role = "tank" },
				{ "Heal the tank hard while he is enraged.", role = "healer" },
			} },
			{ name = "Amnennar the Coldbringer", npc = { 7358 }, lines = {
				{ "He calls Frost Spectres. They die when he dies." },
				{ "Guides differ. Some ignore the spectres and burn Amnennar. Others kill them from range first." },
				{ "Amnennar's Wrath knocks back. Face him away from the group.", role = "tank" },
				{ "Watch for players the spectres hit.", role = "healer" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	uldaman = {
		name = "Uldaman",
		bosses = {
			{ name = "The Lost Dwarves", npc = { 6906, 6907, 6908 }, also = { "Baelog", "Eric \"The Swift\"", "Olaf" },
				lines = {
				{ "Three dwarves fight together. Kill Eric first, then Olaf, then Baelog." },
				{ "Hold Olaf so his charge lands on you. Pick up Eric early.", role = "tank" },
				{ "Charges can land on anyone. Stand back and use shields and heals over time.", role = "healer" },
				{ "Baelog while you kill the other two.", need = "cc" },
			} },
			{ name = "Revelosh", npc = { 6910 }, lines = {
				{ "Two weak troggs fight with him. Kill them first." },
				{ "Spread out. Chain Lightning jumps between players." },
				{ "His Chain Lightning.", need = "kick" },
			} },
			{ name = "Ironaya", npc = { 7228 }, place = "the Map Chamber", lines = {
				{ "She takes no damage over time. Don't use those spells." },
				{ "War Stomp stuns everyone near her for 4 seconds. Ranged, spread out behind her." },
				{ "Arcing Smash hits everyone in front of her. Face her away.", role = "tank" },
			} },
			{ name = "Obsidian Sentinel", npc = { 7023 }, lines = {
				{ "He splits off Obsidian Shards as he loses health. Kill each one, then go back to him." },
				{ "The shards can reflect spells." },
				{ "Pick up each shard as it appears.", role = "tank" },
			} },
			{ name = "Ancient Stone Keeper", npc = { 7206 }, lines = {
				{ "He takes no damage over time." },
				{ "Sand Storms slow and silence players near them. Stay at range.", role = "healer" },
				{ "Ranged, stay far back from the Sand Storms.", role = "dps" },
			} },
			{ name = "Galgann Firehammer", npc = { 7291 }, lines = {
				{ "Two Shadowforge Geologists fight with him. Kill them first. They run when nearly dead." },
				{ "A second player should hold one Geologist away from him.", role = "tank" },
				{ "A heavy healing fight. Use shields and heals over time on both tanks.", role = "healer" },
				{ "Amplify Flames on the tank.", need = "magic" },
				{ "The Geologists' Flame Spike.", need = "kick" },
			} },
			{ name = "Grimlok", npc = { 4854 }, lines = {
				{ "A basilisk and two troggs fight with him. Hold the helpers and kill Grimlok." },
				{ "Without enough crowd control, kill the basilisk first." },
				{ "Tank Grimlok and anything loose against a wall.", role = "tank" },
				{ "His Lightning Bolt and Chain Bolt.", need = "kick" },
				{ "Shrink lowers Strength and Stamina.", need = "curse" },
			} },
			{ name = "Archaedas", npc = { 2748 }, place = "the last chamber", lines = {
				{ "He wakes stone helpers during the fight. They die when he dies." },
				{ "At 20% health four elite helpers join him." },
				{ "Kill his helpers as they wake, then Archaedas." },
				{ "Ground Tremor stuns everyone near him. Spread out." },
				{ "Many tanks drag him back to the room with columns, away from the group.", role = "tank" },
				{ "A long fight. Pace your mana.", role = "healer" },
			} },
		},
	},

	-- Warcraft Tavern; the Warcraft Wiki refused the reads
	zulfarrak = {
		name = "Zul'Farrak",
		bosses = {
			{ name = "Antu'sul", npc = { 8127 }, lines = {
				{ "He calls basilisks during the fight. Kill them with area damage." },
				{ "Pull him out of his cave to the group.", role = "tank" },
				{ "Melee, kill his totems.", role = "dps" },
				{ "Both of his heals.", need = "kick" },
			} },
			{ name = "Theka the Martyr", npc = { 7272 }, lines = {
				{ "At low health he turns immune to physical and shadow damage for 30 seconds." },
				{ "Stun him as his health gets low to stop the change.", need = "stun" },
				{ "Fevered Plague.", need = "disease" },
			} },
			{ name = "Witch Doctor Zum'rah", npc = { 7271 }, lines = {
				{ "He turns hostile as you cross into his room. Zombies keep rising during the fight." },
				{ "Kill the zombies first, then him." },
				{ "Kill his totems fast.", role = "dps" },
				{ "Heal from the top of the stairs, out of the zombies' reach.", role = "healer" },
				{ "His Shadow Bolt.", need = "kick" },
			} },
			{ name = "Shadowpriest Sezz'ziz", npc = { 7275, 7796 }, also = { "Nekrum Gutchewer" },
				place = "the stairs event", lines = {
				{ "Free Bly's group to start waves of trolls up the stairs. Sezz'ziz and Nekrum come last." },
				{ "Kill Nekrum first, then Sezz'ziz." },
				{ "Stay far from Sezz'ziz. Psychic Scream fears those near him.", role = "healer" },
				{ "Sezz'ziz's heals.", need = "kick" },
			} },
			{ name = "Sergeant Bly", npc = { 7604 }, lines = {
				{ "Talk to Weegli before Bly so Weegli blows the door. If not, the way to Chief Ukorz stays shut." },
				{ "Kill Murta first, then Oro, then Raven, then Bly." },
				{ "Hold the others. Keep Bly for last.", role = "tank" },
			} },
			{ name = "Chief Ukorz Sandscalp", npc = { 7267, 7797 }, also = { "Ruuzlu" }, place = "with Ruuzlu", lines = {
				{ "Ruuzlu fights with him. Kill Ruuzlu first." },
				{ "Face him to the wall. Cleave hits those in front.", role = "tank" },
				{ "Melee, don't stand in front of either troll.", role = "dps" },
			} },
			{ name = "Hydromancer Velratha", npc = { 7795 }, optional = true, lines = {
				{ "She stands round a corner by the entrance. She is easy to pull by mistake." },
				{ "Kill her totems." },
				{ "Her spells.", need = "kick" },
			} },
			{ name = "Gahz'rilla", npc = { 7273 }, optional = true, place = "the Mallet of Zul'Farrak", lines = {
				{ "Gahz'rilla Slam throws everyone in the air. The fall hurts." },
				{ "Fight in the pool. Landing in water cuts the fall damage." },
				{ "Keep everyone topped up for the falls.", role = "healer" },
			} },
		},
	},

	-- Warcraft Tavern; the Warcraft Wiki refused the reads
	maraudon = {
		name = "Maraudon",
		bosses = {
			{ name = "Noxxion", npc = { 13282 }, place = "orange side", lines = {
				{ "He splits into small copies. Kill them one at a time, then go back to him." },
				{ "Pull him out of the water onto land.", role = "tank" },
			} },
			{ name = "Razorlash", npc = { 12258 }, place = "orange side", lines = {
				{ "Face him away from the group. Cleave hits those in front.", role = "tank" },
				{ "Puncture is a 10 second bleed. Heal whoever has it.", role = "healer" },
			} },
			{ name = "Lord Vyletongue", npc = { 12236 }, place = "purple side", lines = {
				{ "Two elite helpers fight with him. Kill Vyletongue first, then them." },
				{ "Smoke Bomb stuns the group for a few seconds. When he blinks away, gather on him again." },
				{ "Stand close to the tank so he can't use Multi-Shot.", role = "dps" },
				{ "His two helpers.", need = "cc" },
			} },
			{ name = "Celebras the Cursed", npc = { 12225 }, place = "Poison Falls", lines = {
				{ "Don't kill his helpers. Each one killed brings a new one. Burn Celebras." },
				{ "Watch for Entangling Roots. Spread heals during Twisted Tranquility.", role = "healer" },
				{ "His spells.", need = "kick" },
			} },
			{ name = "Landslide", npc = { 12203 }, lines = {
				{ "He calls Theradrim Shardlings. Ignore them. They die when he dies." },
				{ "Fight with your back to a wall. He knocks back.", role = "tank" },
				{ "Stay at max range. He knocks back and stuns.", role = "healer" },
			} },
			{ name = "Tinkerer Gizlock", npc = { 13601 }, lines = {
				{ "Stand behind him in melee range. He shoots players who stand off." },
				{ "His bombs hit the rest of the group." },
				{ "Face him away from the group.", role = "tank" },
			} },
			{ name = "Rotgrip", npc = { 13596 }, place = "the pool", lines = {
				{ "Clear the hydras in the pool first." },
				{ "Warlocks and shamans, give the group water breathing." },
				{ "Pull him up to the surface. He hits hard. Use cooldowns when Fatal Bite lands.", role = "tank" },
			} },
			{ name = "Princess Theradras", npc = { 12201 }, lines = {
				{ "Dust Field pushes everyone near her back. Ranged and healers, stay at max range." },
				{ "She throws boulders round the platform." },
				{ "Tank her at the back of her platform so the group can spread out.", role = "tank" },
				{ "Repulsive Gaze fears players.", need = "fear" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. The zone is "The Temple of
	-- Atal'Hakkar"; the instance may call itself Sunken Temple.
	templeofatalhakkar = {
		name = "Temple of Atal'Hakkar",
		bosses = {
			{ name = "Atal'alarion", npc = { 8580 }, optional = true, place = "the Pit of Refuse", lines = {
				{ "Press the statues in order to call him. South, north, southwest, southeast, northwest, northeast." },
				{ "Sweeping Slam throws players in front of him. Face him to a wall.", role = "tank" },
				{ "Each throw wipes threat. Wait for the tank after one.", role = "dps" },
			} },
			{ name = "The six trolls", npc = { 5713, 5715, 5714, 5717, 5712, 5716 },
				also = { "Gasher", "Hukku", "Loro", "Mijan", "Zolo", "Zul'Lor" }, place = "the balconies", lines = {
				{ "Kill all six on the balconies to open the way to Jammal'an." },
				{ "Hukku calls demons. Zolo raises skeletons. Mijan drops a healing totem. Kill it." },
				{ "They can be stunned.", need = "stun" },
				{ "Their spells.", need = "kick" },
			} },
			{ name = "Spawn of Hakkar", npc = { 5708 }, optional = true, lines = {
				{ "Acid of Hakkar burns whoever it hits. Heal them.", role = "healer" },
			} },
			{ name = "Jammal'an the Prophet", npc = { 5710, 5711 }, also = { "Ogom the Wretched" }, place = "with Ogom", lines = {
				{ "Clear the whole room first, or it joins the fight." },
				{ "Guides differ. One kills Ogom first. The other kills Jammal'an first, as he turns a player against you." },
				{ "Spread out. Flamestrike and the hexed player hurt groups standing together." },
				{ "Curse of Weakness on the tank and melee.", need = "curse" },
				{ "Shadow Word: Pain.", need = "magic" },
			} },
			{ name = "Dreamscythe", npc = { 5721, 5720 }, also = { "Weaver" }, place = "and Weaver", lines = {
				{ "Both drakes appear when Jammal'an dies. Pull one at a time." },
				{ "Stay away from its front." },
				{ "Pull each into the hallway. Tank it against a wall, facing away.", role = "tank" },
			} },
			{ name = "Morphaz", npc = { 5719, 5722 }, also = { "Hazzas" }, place = "and Hazzas", lines = {
				{ "Both come together when the first two drakes die. You fight both at once." },
				{ "Stay away from their fronts." },
				{ "Tank both against a wall in the hallway, facing away.", role = "tank" },
			} },
			{ name = "Avatar of Hakkar", npc = { 8443 }, optional = true, place = "needs the Egg of Hakkar", lines = {
				{ "Kill the Hakkari Bloodkeepers as they come. Use their blood to put out the four braziers." },
				{ "Before the last brazier, stand against the wall to drop out of combat and rest." },
				{ "Cause Insanity takes over a player.", need = "cc" },
				{ "Curse of Tongues on casters.", need = "curse" },
			} },
			{ name = "Shade of Eranikus", npc = { 5709 }, lines = {
				{ "Clear all the dragonkin first, or they join him." },
				{ "Deep Slumber sleeps the top threat for 8 seconds. He then turns on the next player." },
				{ "Grounding Totem stops Deep Slumber." },
				{ "Have a second tank or a melee player ready to take him during Deep Slumber.", role = "tank" },
				{ "A long fight. Pace your mana.", role = "healer" },
				{ "Ranged, stay away from his front and from War Stomp.", role = "dps" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	blackrockdepths = {
		name = "Blackrock Depths",
		bosses = {
			{ name = "High Interrogator Gerstahn", npc = { 9018 }, place = "the Detention Block", lines = {
				{ "Two elites and three hounds come with her. Clear the hallway and pull her out to it." },
				{ "Her Mana Burn.", need = "kick" },
				{ "Psychic Scream fears.", need = "fear" },
				{ "Shadow Word: Pain.", need = "magic" },
			} },
			{ name = "Lord Roccor", npc = { 9025 }, lines = {
				{ "Ground Tremor stops everyone near him for 2 seconds and cuts off casts." },
				{ "Heal from out of his reach.", role = "healer" },
			} },
			{ name = "Houndmaster Grebmar", npc = { 9319 }, lines = {
				{ "Two packs of dogs walk with him. Kill the dogs first." },
				{ "He runs at 15% health. Finish him fast." },
			} },
			{ name = "Ring of Law", npc = { 9032, 9027, 9031, 9030, 9028, 9029, 16059 },
				also = { "Hedrum the Creeper", "Gorosh the Dervish", "Anub'shiah", "Ok'thor the Breaker", "Grizzle",
					"Eviscerator", "Theldren" }, place = "one boss at random", lines = {
				{ "Waves of enemies come first, then one boss at random." },
				{ "Gorosh spins in Whirlwind. Melee, step out." },
				{ "Eviscerator blocks magic for 6 seconds at a time. Casters, wait it out." },
				{ "With the Banner of Provocation, Theldren comes with four gladiators. They ignore taunts." },
				{ "Grizzle frenzies at half health. Heal the tank hard then.", role = "healer" },
				{ "Hedrum's poison.", need = "poison" },
				{ "Anub'shiah's Curse of Tongues.", need = "curse" },
				{ "Ok'thor's Polymorph.", need = "magic" },
			} },
			{ name = "Bael'Gar", npc = { 9016 }, lines = {
				{ "He calls Spawn of Bael'Gar. Kill each one, then go back to him." },
				{ "Face him to the wall. Taunt his spawn off the group.", role = "tank" },
				{ "Stand behind him, out of Magma Splash.", role = "dps" },
			} },
			{ name = "Lord Incendius", npc = { 9017 }, place = "the Black Anvil", lines = {
				{ "He knocks players back on a ledge over lava. Fight in the middle, away from the edges." },
				{ "Everyone takes fire damage. Keep the group topped up.", role = "healer" },
				{ "Curse of the Elemental Lord, before it stacks.", need = "curse" },
			} },
			{ name = "Fineous Darkvire", npc = { 9056 }, lines = {
				{ "Clear one end of the ramp and wait for him there." },
				{ "He hits hard. Use defensive cooldowns.", role = "tank" },
				{ "His Holy Light.", need = "kick" },
			} },
			{ name = "Warder Stilgiss", npc = { 9041, 9042 }, also = { "Verek" }, place = "with Verek", lines = {
				{ "Kill Stilgiss first, then his hound Verek." },
				{ "Frost Ward absorbs frost damage. Use other spells on him.", role = "dps" },
				{ "His Frostbolt.", need = "kick" },
			} },
			{ name = "Watchman Doomgrip", npc = { 9476 }, optional = true, place = "after the vaults", lines = {
				{ "Opening all twelve vaults wakes stone guardians, then Doomgrip." },
				{ "Kill the guardians one at a time. Doomgrip is a plain fight after." },
			} },
			{ name = "Pyromancer Loregrain", npc = { 9024 }, lines = {
				{ "Kill his Scorching Totem when it appears." },
				{ "Fire Ward absorbs fire damage. Fire mages and warlocks, use other spells.", role = "dps" },
				{ "His Molten Blast.", need = "kick" },
			} },
			{ name = "General Angerforge", npc = { 9033 }, lines = {
				{ "Pull him up the ramp with a ranged attack. He comes alone." },
				{ "At low health he calls reservists and medics. Kill them with area damage." },
				{ "If he is nearly dead when they come, finish him first." },
				{ "The medics' heals.", need = "kick" },
			} },
			{ name = "Golem Lord Argelmach", npc = { 8983 }, lines = {
				{ "Clear the room first. He calls the golems and workers nearby." },
				{ "Two golems fight with him. Kill them first." },
				{ "His Lightning Shield hurts whoever hits him." },
			} },
			{ name = "Hurley Blackbreath", npc = { 9537 }, optional = true, place = "break three kegs", lines = {
				{ "Break the three Thunderbrew kegs to call him. Fight in a corner away from the door." },
				{ "Guides differ. Some kill Hurley first. Others kill his helpers first." },
				{ "His helpers.", need = "cc" },
			} },
			{ name = "Ribbly Screwspigot", npc = { 9543 }, optional = true, lines = {
				{ "Threaten him in talk to start the fight. Three friends join him." },
				{ "Kill Ribbly first, then his friends." },
			} },
			{ name = "Phalanx", npc = { 9502 }, place = "the Grim Guzzler", lines = {
				{ "Give Private Rocknot ale until Phalanx wakes and comes for you." },
				{ "Don't hit the bar's drinkers with area damage. They join the fight." },
				{ "Thunderclap slows those near him. Fireball Volley hits everyone." },
			} },
			{ name = "Plugger Spazzring", npc = { 9499 }, optional = true, lines = {
				{ "Attacking him turns the whole bar hostile." },
				{ "He can't be kicked or stunned." },
				{ "Curse of Tongues.", need = "curse" },
				{ "Immolate.", need = "magic" },
			} },
			{ name = "Ambassador Flamelash", npc = { 9156 }, lines = {
				{ "Burning Spirits walk to him from the runes and make him stronger. Kill them before they reach him." },
				{ "Save defensive cooldowns for the end, when he hits hardest.", role = "tank" },
			} },
			{ name = "The Seven", npc = { 9035, 9038, 9040, 9037, 9036, 9034, 9039 },
				also = { "Anger'rel", "Seeth'rel", "Dope'rel", "Gloom'rel", "Vile'rel", "Hate'rel", "Doom'rel" }, lines = {
				{ "Seven ghosts come one at a time on a timer. Talking to Doom'rel starts it." },
				{ "Doom'rel calls Voidwalkers. Kill him, then them." },
				{ "Pull each ghost to the middle of the room.", role = "tank" },
				{ "Drink between ghosts.", role = "healer" },
				{ "Their spells.", need = "kick" },
			} },
			{ name = "Magmus", npc = { 9938 }, lines = {
				{ "Light both braziers in the Lyceum to open his hall." },
				{ "Statues breathe fire across the room. Stay out of the fire rows." },
				{ "War Stomp stuns and knocks back those near him." },
				{ "Pull him to the right and tank him in a corner.", role = "tank" },
			} },
			{ name = "Emperor Dagran Thaurissan", npc = { 9019, 8929 }, also = { "Princess Moira Bronzebeard" },
				place = "with Moira", lines = {
				{ "Kill Moira first, then the Emperor. To save her, kill the Emperor while one player holds her." },
				{ "Avatar of Flame makes him immune to magic for 10 seconds." },
				{ "If you kill Moira, use your healing cooldowns early.", role = "healer" },
				{ "Moira's heals.", need = "kick" },
				{ "Sap or trap Moira. Polymorph doesn't work on her.", need = "cc" },
			} },
		},
	},

	-- Warcraft Tavern; the Warcraft Wiki refused the reads
	lowerblackrockspire = {
		name = "Lower Blackrock Spire",
		bosses = {
			{ name = "Highlord Omokk", npc = { 9196 }, lines = {
				{ "Two ogres fight with him. Kill the free one, then Omokk." },
				{ "He hits harder when enraged." },
				{ "Knock Away throws the tank. Put your back to a wall.", role = "tank" },
				{ "One or both of his ogres.", need = "cc" },
			} },
			{ name = "Shadow Hunter Vosh'gajin", npc = { 9236 }, lines = {
				{ "Two shadow priests fight beside Vosh'gajin. With one crowd control, kill the free priest first." },
				{ "Hex can hit several players at once." },
				{ "Both priests.", need = "cc" },
				{ "Curse of Blood.", need = "curse" },
			} },
			{ name = "War Master Voone", npc = { 9237 }, lines = {
				{ "No helpers, but he hits very hard. Put your back to a wall, away from the group.", role = "tank" },
				{ "Don't stand in front. Don't pull him off the tank.", role = "dps" },
			} },
			{ name = "Mother Smolderweb", npc = { 10596 }, lines = {
				{ "Crystallize stuns the tank now and then. Build a big threat lead.", role = "tank" },
				{ "Stand behind her, at max range.", role = "dps" },
				{ "Mother's Milk.", need = "poison" },
			} },
			{ name = "Urok Doomhowl", npc = { 10584 }, optional = true, place = "the Tribute Pile", lines = {
				{ "Waves of elite ogres come first. Use the Roughshod Pike every 30 seconds to kill one." },
				{ "Ogres as they come in.", need = "cc" },
				{ "His Intimidating Roar.", need = "magic" },
			} },
			{ name = "Quartermaster Zigris", npc = { 9736 }, lines = {
				{ "Spread out. Stun Bomb hits players standing together." },
			} },
			{ name = "Halycon", npc = { 10220 }, lines = {
				{ "Kill the worg pups first, then Halycon." },
				{ "Gizrul runs in right after Halycon dies. Eat and drink fast." },
				{ "The pups hit the group early. Use heals over time and shields.", role = "healer" },
			} },
			{ name = "Gizrul the Slavener", npc = { 10268 }, lines = {
				{ "Use defensive cooldowns when he enrages.", role = "tank" },
				{ "Infected Bite keeps hurting the tank. Heal through it.", role = "healer" },
			} },
			{ name = "Overlord Wyrmthalak", npc = { 9568 }, lines = {
				{ "At half health he calls two helpers. Hold them and finish him first." },
				{ "Back to the wall behind his spot. Cleave and Sweeping Slam hit around him.", role = "tank" },
				{ "Wait a moment for the tank when the helpers arrive.", role = "healer" },
				{ "Stand behind him at max range.", role = "dps" },
				{ "His two helpers.", need = "cc" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. A 10-player raid on Forever.
	upperblackrockspire = {
		name = "Upper Blackrock Spire",
		bosses = {
			{ name = "Pyroguard Emberseer", npc = { 9816 }, lines = {
				{ "Kill the waves of Incarcerators with area damage. Then Emberseer wakes." },
				{ "Fire Nova burns everyone near him. Ranged, stay away." },
				{ "Fight him away from the ranged group.", role = "tank" },
			} },
			{ name = "Solakar Flamewreath", npc = { 10264 }, optional = true, place = "the Father Flame event", lines = {
				{ "Five waves of dragonkin come before him. Kill the Rookery Hatchers first." },
				{ "Eggs hatch as players come near. Keep the group together." },
				{ "Stand back from his War Stomp." },
			} },
			{ name = "Goraluk Anvilcrack", npc = { 10899 }, optional = true, lines = {
				{ "Backhand stuns the tank for 2 seconds. A second tank should taunt then.", role = "tank" },
			} },
			{ name = "Warchief Rend Blackhand", npc = { 10429, 10339 }, also = { "Gyth" }, place = "on Gyth", lines = {
				{ "Waves of drakes and dragonkin come first. Then Rend rides in on Gyth." },
				{ "Kill Gyth first, then Rend." },
				{ "One tank takes Gyth. The other takes Rend when they split.", role = "tank" },
				{ "Stand behind Gyth, out of its breath. Melee, step out of Rend's Whirlwind.", role = "dps" },
			} },
			{ name = "The Beast", npc = { 10430 }, lines = {
				{ "Clear the room first. Stealthed assassins may be about." },
				{ "He charges a player, then goes back to the tank." },
				{ "Flamebreak knocks back. Put your back to a wall.", role = "tank" },
				{ "Ranged, stay far back to avoid Fear and Flamebreak.", role = "dps" },
			} },
			{ name = "General Drakkisath", npc = { 10363 }, lines = {
				{ "Two Chromatic Elite Guards fight with him. Kill the main tank's guard, then the other, then him." },
				{ "One tank per guard. The off tank taunts when Conflagration hits the main tank.", role = "tank" },
				{ "Don't heal the player kiting him.", role = "healer" },
				{ "Stand behind him. Flame Breath and Cleave hit the front.", role = "dps" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. The game may call every wing Dire
	-- Maul, so the wing is the one whose boss is seen.
	diremauleast = {
		name = "Dire Maul East",
		instance = "diremaul",
		bosses = {
			{ name = "Pusillin", npc = { 14354 }, place = "chase him", lines = {
				{ "Talk to him and chase him through the wing. He drops the Crescent Key." },
				{ "He calls four imps when the fight starts. Kill the imps." },
				{ "He reflects half of all spells back. Casters, take care." },
				{ "His Fireball and Blast Wave.", need = "kick" },
			} },
			{ name = "Lethtendris", npc = { 14327 }, lines = {
				{ "Kill her imp Pimgib first." },
				{ "Void Bolt first, then Shadow Bolt Volley.", need = "kick" },
				{ "Her curses.", need = "curse" },
				{ "Immolate.", need = "magic" },
			} },
			{ name = "Hydrospawn", npc = { 13280 }, lines = {
				{ "He calls Hydrolings. Kill them with area damage, or burn him with single-target damage." },
			} },
			{ name = "Zevrim Thornhoof", npc = { 11490 }, lines = {
				{ "He sacrifices a player on his altar. Heal them hard." },
				{ "Ranged, stand far back from Intense Pain.", role = "dps" },
				{ "Intense Pain.", need = "magic" },
			} },
			{ name = "Alzzin the Wildshaper", npc = { 11492 }, lines = {
				{ "He drops threat each time he changes form. Wait for the tank after each change." },
				{ "At 35% helpers join. Kill them with area damage, then him." },
				{ "His wolf form hits the tank hardest.", role = "healer" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki
	diremaulwest = {
		name = "Dire Maul West",
		instance = "diremaul",
		bosses = {
			{ name = "Tendris Warpwood", npc = { 11489 }, lines = {
				{ "Kill the Ancients walking the courtyard first. He calls them all when the fight starts." },
				{ "Trample knocks down everyone in melee. Entangle can't be dispelled." },
				{ "Keep him away from ranged and healers.", role = "tank" },
			} },
			{ name = "Magister Kalendris", npc = { 11487 }, lines = {
				{ "Use Shadow Protection or Shadow Resistance Aura.", role = "healer" },
				{ "His Mind Blast and Mind Flay.", need = "kick" },
				{ "A player taken by Dominate Mind.", need = "cc" },
				{ "Shadow Word: Pain.", need = "magic" },
			} },
			{ name = "Illyanna Ravenoak", npc = { 11488 }, place = "with Ferra", lines = {
				{ "Fight in melee range. Her ranged attacks then stop." },
				{ "Kill Illyanna, then her bear Ferra." },
				{ "Hibernate Ferra.", need = "cc" },
			} },
			{ name = "Immol'thar", npc = { 11496 }, lines = {
				{ "Shut down all five crystal pylons to open his prison." },
				{ "He enrages at half health." },
				{ "He teleports a player and wipes their threat. If it's the tank, stop until the tank has him back." },
				{ "Kill the Eyes of Immol'thar as they appear. Give one player the job." },
			} },
			{ name = "Prince Tortheldrin", npc = { 11486 }, lines = {
				{ "Arcane Blast knocks back and wipes threat. Wait for the tank after each one." },
				{ "Tank him in a corner.", role = "tank" },
			} },
		},
	},

	-- Warcraft Tavern. A tribute run leaves the guards alive and kills only
	-- the King, so they are optional here.
	diremaulnorth = {
		name = "Dire Maul North",
		instance = "diremaul",
		bosses = {
			{ name = "Guard Mol'dar", npc = { 14326 }, optional = true, lines = {
				{ "Leave him alive for a tribute run. He holds the inner door key." },
				{ "Back to a wall against Knock Away. Use cooldowns when he enrages.", role = "tank" },
			} },
			{ name = "Stomper Kreeg", npc = { 14322 }, optional = true, lines = {
				{ "He falls asleep drunk. Wait and walk past him." },
				{ "Whirlwind and War Stomp hit melee. Ranged, stay back." },
			} },
			{ name = "Guard Fengus", npc = { 14321 }, optional = true, lines = {
				{ "Leave him alive for a tribute run. Lure him from his chest to take the key." },
				{ "Back to a wall against Knock Away.", role = "tank" },
			} },
			{ name = "Guard Slip'kik", npc = { 14323 }, optional = true, lines = {
				{ "For a tribute run, fix the Broken Trap on his path with Frost Oil and a Thorium Widget. He freezes." },
				{ "Back to a wall against Knock Away.", role = "tank" },
			} },
			{ name = "Captain Kromcrush", npc = { 14325 }, optional = true, lines = {
				{ "For a tribute run, wear the Gordok Ogre Suit and talk to him. He walks off." },
				{ "Stand behind him, out of Mortal Cleave.", role = "dps" },
				{ "The Gordok Reavers he calls at half health.", need = "cc" },
			} },
			{ name = "King Gordok", npc = { 11501, 14324 }, also = { "Cho'Rush the Observer" }, place = "with Cho'Rush", lines = {
				{ "Kill Cho'Rush first. On a tribute run leave Cho'Rush alive and kill Gordok fast." },
				{ "Stay far from Cho'Rush to avoid the fear.", role = "healer" },
				{ "Cho'Rush's Healing Wave first, then his Mind Blast.", need = "kick" },
				{ "Psychic Scream fears the tank.", need = "fear" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. One instance with two sides.
	stratholmeliving = {
		name = "Stratholme Living",
		instance = "stratholme",
		bosses = {
			{ name = "The Unforgiven", npc = { 10516 }, lines = {
				{ "Weak helpers appear when the fight starts. Kill them first." },
			} },
			{ name = "Postmaster Malown", npc = { 11143 }, optional = true, place = "the third postbox", lines = {
				{ "Opening the third postbox calls him with three Undead Postmen." },
				{ "Kill the postmen you can't hold, then the Postmaster." },
				{ "Turn Undead or Shackle Undead on the postmen.", need = "cc" },
				{ "His Fear on the tank.", need = "magic" },
				{ "Curses on the group.", need = "curse" },
			} },
			{ name = "Timmy the Cruel", npc = { 10808 }, lines = {
				{ "He comes out once the courtyard is clear." },
				{ "Heal the tank hard while he is enraged.", role = "healer" },
			} },
			{ name = "Cannon Master Willey", npc = { 10997 }, lines = {
				{ "He calls riflemen. Hold them, or fire the room's cannons at them." },
				{ "Stand behind a cannon, out of the riflemen's reach.", role = "healer" },
				{ "His riflemen.", need = "cc" },
			} },
			{ name = "Archivist Galford", npc = { 10811 }, lines = {
				{ "Spread out. His fire hits several players." },
				{ "Burning Winds can pull him off you. Take him back when it ends.", role = "tank" },
			} },
			{ name = "Balnazzar", npc = { 10812, 10813 }, also = { "Grand Crusader Dathrohan" }, place = "Dathrohan first", lines = {
				{ "At 40% health Dathrohan turns into Balnazzar at full health. He keeps his threat." },
				{ "Stand back from his stun. Psychic Scream fears those near him." },
				{ "Undead pour in outside the room when he dies." },
				{ "Face him to the back wall, away from the group.", role = "tank" },
				{ "Sleep on players.", need = "magic" },
			} },
		},
	},

	-- Warcraft Tavern; the Warcraft Wiki refused the reads
	stratholmeundead = {
		name = "Stratholme Undead",
		instance = "stratholme",
		bosses = {
			{ name = "Magistrate Barthilas", npc = { 10435 }, lines = {
				{ "Face him to a wall. Mighty Blow can knock you into other enemies.", role = "tank" },
			} },
			{ name = "Nerub'enkan", npc = { 10437 }, lines = {
				{ "He calls scarabs. They are weak. Kill them with area damage." },
				{ "Tank him at the top of the ramp.", role = "tank" },
			} },
			{ name = "Baroness Anastari", npc = { 10436 }, lines = {
				{ "She possesses a player. Bring them to half health to free them." },
				{ "Heal the freed player back up.", role = "healer" },
				{ "Banshee Curse.", need = "curse" },
			} },
			{ name = "Maleki the Pallid", npc = { 10438 }, lines = {
				{ "Ice Tomb freezes the tank for 6 seconds. He turns on the next player meanwhile." },
				{ "Taunt him back as soon as you are free.", role = "tank" },
				{ "His Frostbolt and Drain Life.", need = "kick" },
			} },
			{ name = "Ramstein the Gorger", npc = { 10439 }, lines = {
				{ "Knockout drops the tank. He turns on the second player on threat." },
				{ "A big wave of undead pours out after he dies." },
				{ "Have a taunt ready for Knockout.", role = "tank" },
			} },
			{ name = "Baron Rivendare", npc = { 10440 }, lines = {
				{ "Unholy Aura burns everyone close to him. Ranged and healers, stand left at max range." },
				{ "Take him to the back right of the room. Back to a wall.", role = "tank" },
				{ "Mortal Strike cuts healing on the tank. Use cooldowns then.", role = "healer" },
				{ "Melee, kill the skeletons first. Stand behind the Baron.", role = "dps" },
			} },
		},
	},

	-- Warcraft Tavern and the Warcraft Wiki. Marduk Blackpool and Vectus
	-- need a long quest first and are left out.
	scholomance = {
		name = "Scholomance",
		bosses = {
			{ name = "Kirtonos the Herald", npc = { 10506 }, optional = true, place = "the porch", lines = {
				{ "Call him with the Blood of Innocents on the porch." },
				{ "Tank him against a wall. Wing Flap knocks back. Swoop stuns.", role = "tank" },
				{ "Stay out from in front of him in gargoyle form.", role = "dps" },
				{ "The curses he casts in human form.", need = "curse" },
			} },
			{ name = "Jandice Barov", npc = { 10503 }, optional = true, lines = {
				{ "She makes copies of herself. Hold back until you find the real one." },
				{ "Mark her before the copies appear.", role = "tank" },
				{ "Curse of Blood.", need = "curse" },
				{ "Dark Plague.", need = "disease" },
			} },
			{ name = "Rattlegore", npc = { 11622 }, lines = {
				{ "Kill his one helper first, then Rattlegore." },
				{ "War Stomp hits those near him. Ranged, keep away." },
				{ "Back to a wall. Knock Away throws the tank.", role = "tank" },
			} },
			{ name = "Ras Frostwhisper", npc = { 10508 }, lines = {
				{ "Clear the room first. Tank him near the back with nothing blocking sight." },
				{ "Chill Nova hits those near him. Stay at max range." },
				{ "His spells.", need = "kick" },
				{ "His Fear.", need = "magic" },
			} },
			{ name = "Instructor Malicia", npc = { 10505 }, lines = {
				{ "She casts often. Clear the enemies before her first." },
				{ "As many of her spells as you can.", need = "kick" },
			} },
			{ name = "Doctor Theolen Krastinov", npc = { 11261 }, lines = {
				{ "He enrages at half health and can kill a cloth player in a hit or two. Don't pull him off the tank." },
				{ "Save your cooldowns for the end.", role = "tank" },
				{ "Stay well away from him.", role = "healer" },
			} },
			{ name = "Lorekeeper Polkelt", npc = { 10901 }, lines = {
				{ "Zombies come with him and explode when they die. Step away from dying zombies." },
			} },
			{ name = "The Ravenian", npc = { 10507 }, lines = {
				{ "Clear his room. Knock Away can throw players into other enemies." },
			} },
			{ name = "Lord Alexei Barov", npc = { 10504 }, lines = {
				{ "Two helpers come with him. Hold them, burn Barov, then finish them." },
				{ "Unholy Aura hurts the whole group.", role = "healer" },
				{ "Shackle Undead on one helper.", need = "cc" },
				{ "Veil of Shadow.", need = "curse" },
			} },
			{ name = "Lady Illucia Barov", npc = { 10502 }, lines = {
				{ "A player taken by Dominate Mind.", need = "cc" },
				{ "Her spells.", need = "kick" },
			} },
			{ name = "Darkmaster Gandling", npc = { 1853 }, place = "after the six", lines = {
				{ "He appears when the six room bosses are dead." },
				{ "Shadow Portal sends a player to a side room with a few enemies. Kill them to get out." },
				{ "Ranged, stand on the stairs at max range.", role = "dps" },
				{ "Curse of the Darkmaster.", need = "curse" },
			} },
		},
	},
}
