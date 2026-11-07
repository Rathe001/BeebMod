# Encounter notes research

One file per dungeon, behind `Modules/Encounter/Data.lua`. Each lists its
sources, the order of the bosses, where the guides disagree, and which
source gives each line.

Source letters:

- **W**: Warcraft Tavern, WoW Forever dungeon guides (warcrafttavern.com/forever/guides)
- **M**: Method, WoW Forever dungeon guides (method.gg/wow-forever/dungeons)
- **K**: the Warcraft Wiki (warcraft.wiki.gg), boss pages: abilities and strategy
- **V**: the VMaNGOS world database, for the Classic bosses' npc ids

Rules (Josh 2026-11-06): a line one trusted guide gives and nothing
contradicts is kept. Where guides disagree, the line is left out or both
answers are written. Generic advice ("focus your healing on the tank") is
left out.

The first batch was read on 2026-11-06. The second, from level 32 up, on 2026-11-07, when Method had no guide for it and the wiki refused many reads (HTTP 429). Icy Veins and Wowhead refuse automated reads, so
neither was used. Several Warcraft Wiki pages describe a later version of a
boss (Cataclysm's Shadowfang Keep, Warlords' Razorfen Kraul). Those parts
were not used. The "(Classic)" pages were read instead where they exist.
