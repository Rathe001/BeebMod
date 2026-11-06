# The Hall of Thanes · WoW: Forever

- **Key in Data.lua:** `hallofthanes`
- **Type:** dungeon, 4 bosses, new in Forever (Alliance, under Ironforge)
- **Sources, read 2026-11-06:**
  - **M**: Method, WoW Forever Hall of Thanes guide (method.gg/wow-forever), updated 15 Oct 2026
  - **W**: Warcraft Tavern, Forever dungeon guide (warcrafttavern.com/forever/guides)
- **Status:** two sources reconciled. Npc ids from the Warcraft Wiki (Forever pages): Faldrim Anvilmar 261306, Magmatus 261316, Plunder 261311, Durgen Dirgehammer 261319.

Icy Veins and Wowhead refuse automated reads (403/404), so neither was used.

Boss order: Faldrim Anvilmar → Magmatus → Plunder → Durgen Dirgehammer.

## 1. Faldrim Anvilmar (Anvilmar's Rest)

| Line | For | Source |
|---|---|---|
| He patrols his tomb with undead around him. Clear the room before you pull him. | everyone | M W |
| Anvilmar's Curse slows your attacks and casts by 20% for 10 minutes. | tank | W |
| Remove Anvilmar's Curse from the tank. | curse | W |
| Mind Blast. Kick it when you can. | kick | W |

## 2. Magmatus

| Line | For | Source |
|---|---|---|
| A Dark Iron Summoner fights with him. Kill the Summoner first. | everyone | M W |
| Fire Nova burns everyone near him. Ranged, stay back. | everyone | M W |
| Drag Magmatus away from the group while they kill the Summoner. | tank | M |
| Melee take Fire Nova too. Expect to heal them as much as the tank. | healer | M W |
| The Summoner's Fireball and its summon. | kick | M W |
| Stun the Summoner when nobody can kick. | stun | M |

## 3. Plunder

| Line | For | Source |
|---|---|---|
| Knock Away is his main ability. Fight him in a corner, away from other packs. | everyone | M W |
| Put your back to a wall so the knock can't send you into trash. | tank | W |
| He charges people near him. Ranged, keep your distance. | dps | W |

## 4. Durgen Dirgehammer (Reliquary of Kings)

| Line | For | Source |
|---|---|---|
| Clear the Dark Iron Looters around his platform before the pull. | everyone | M W |
| He fears everyone for 8 seconds. Feared players can run into other packs. | everyone | M W |
| Guides differ on the kill order. Some kill Durgen first. Others kill the two Lesser Stone Golems first. | everyone | M / W disagree |
| Rend bleeds you every 3 seconds. | tank | M |
| Put Tremor Totem down before the pull. | fear | W |

## Where the sources disagree

- **Kill order.** Method kills Durgen first. Warcraft Tavern kills the two Lesser Stone Golems first. Both are written, as one line.
- **The name.** One guide writes Durgen Dirgehammer, the other Dirgen Dirgehammer. Data.lua matches both (`also`).
- **Plunder's abilities.** Both guides call Knock Away his one ability. The wiki lists Charge and Crush Armor as well, so the line says "his main ability".
