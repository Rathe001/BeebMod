# The Deadmines · WoW: Forever

- **Key in Data.lua:** `deadmines`
- **Type:** dungeon, 6 bosses and 1 optional, Classic
- **Sources:** W (Warcraft Tavern, which says The Deadmines is unchanged from Classic) and M (Method, whose page appeared after the first read). Abilities are checked against V (the VMaNGOS world database, through `Modules/Expedition/AbilityData.lua`), which gives no advice.
- **Npc ids** (V): Rhahk'Zor 644, Sneed's Shredder 642, Sneed 643, Gilnid 1763, Mr. Smite 646, Cookie 645, Captain Greenskin 647, Edwin VanCleef 639.
- **Status:** two sources reconciled.

Boss order: Rhahk'Zor → Sneed's Shredder and Sneed → Gilnid → Mr. Smite → Cookie (optional) → Captain Greenskin → Edwin VanCleef.

## Disagreements

- **Captain Greenskin's kill order.** W kills his two adds first, then Greenskin. M kills the Defias Companion first, then Greenskin, then the other two. Both agree on the Companion first. What comes next is written as a disagreement.
- **Gilnid.** W says Molten Metal cuts the tank's threat. M says it slows. Both can be true. W's line is kept.
- **Left out:** Miner Johnson (rare).

## Lines

| Boss | Line | For | Source |
|---|---|---|---|
| Rhahk'Zor | Two Defias Watchmen shoot from range. Kill them first. | all | W M |
| | Rhahk'Zor Slam hits hard and stuns you for 3 seconds. | tank | W M V |
| | Polymorph one Watchman if both come with him. | cc | M |
| Sneed's Shredder | Clear the Goblin Woodcarvers first. The Shredder's Terrify can fear players into them. | all | W M |
| | Sneed jumps out when the Shredder dies. Kill him too. | all | W M V |
| | Sneed starts with no threat on you. Taunt him. He disarms you. | tank | W M V |
| | Don't pull the Shredder off the tank. Distracting Pain goes on whoever it hits. | dps | W M V |
| Gilnid | The room is full of Craftsmen and Engineers. Clear at least one side first. | all | W |
| | Molten Metal on you cuts your threat while it lasts. | tank | W V |
| | Ease off while Molten Metal is on the tank. | dps | W |
| Mr. Smite | Two stealthed Blackguards stand by him. Kill them first. | all | W M |
| | Each Smite Stomp stuns everyone and changes his weapons. With two, he hits much harder. | all | W M V |
| | Save your defensives for the two-weapon phase. | tank | W |
| | Save your mana for the two-weapon phase. | healer | W |
| Cookie | Acid Splash burns the tank over time. | all | M V |
| | Cookie's Cooking heals him. | kick | W M V |
| Greenskin | He is easy to pull together with VanCleef. Pull Greenskin on his own. | all | W |
| | Kill the Defias Companion first. It has little health. | all | M |
| | Then guides differ. Some kill Greenskin next. Others kill his two other adds. | all | W / M |
| | Poisoned Harpoon and Cleave hit you. | tank | M |
| VanCleef | At half health he calls two more Blackguards. | all | W M V |
| | Kill the first two adds. Crowd-control or ignore the new ones. Burn VanCleef. | all | W M |
| | He hits hard. Hold the first two adds on you. | tank | W |
| | A long fight. Pace your mana. | healer | W |
| | Stun him as he reaches half health. He then calls no more Blackguards. | stun | M |
