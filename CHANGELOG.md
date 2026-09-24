# Changelog

BeebMod is built against the WoW: Forever beta client, and is a beta itself
until that client is released. Versions are `MAJOR.MINOR.PATCH-beta.N`: the
beta number goes up with each build handed to anyone, and the rest once the
game and the addon settle.

## Unreleased

- **Saved variables load the ordinary way.** Build 1.60.1.70009 fixed the
  beta bug that kept the client from reading saved variables back, so the
  `Data\Live` workaround is gone: the TOC no longer loads the last save as an
  addon file, and anyone else installing the addon no longer gets an error
  for a file only this machine had. The book is unchanged - it was already in
  the client's own saved file.
- Dropdown menus are dressed once the client has built them (a menu dressed
  during its build raised "Use of function 'CreateTexture' is disallowed").

## 0.1.0-beta.1

The first version kept in git: everything up to here, in one.

- **The dock** - the panel at the side of the screen: the minimap and other
  addons' buttons, experience and reputation, a grid of readouts (gold, bags,
  durability, item level, pick-pocket takings, speed, performance), the quest
  tracker under its zones, the micro menu, and a header with the clock and the
  census.
- **Combat** - unit frames for you and your group, the raid, main tanks,
  target, focus and bosses, with auras drawn by the client's own containers;
  a buff tray; the personal resource display with combo points; the damage
  meter restyled, with amounts a second and the fight's length.
- **Windows** - the action bars, bag window, character sheet, chat, game
  menu, dropdown menus and tooltips, in the toolkit's look; every button still
  the game's.
- **People** - the Ledger (notes and tags on the people you meet) and the
  Census (the realm's charts), from a book of every character seen.
- **Settings** - one window, its rail in four groups (Dock, Combat, Windows,
  People), a switch per module and finer settings on each page.
