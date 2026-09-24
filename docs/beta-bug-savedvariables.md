# Bug report: addon SavedVariables are written but never loaded

> **Fixed in 1.60.1.70009 (2026-09-24).** The probe below got its table back
> on a fresh launch and on a `/reload` ("run 2: arrived as table, build
> 70009"). Kept for the record.

Paste-ready for the in-game Issue Reporter (F6 / the bug icon). Keep it to the
facts: what was expected, what happened, and the smallest thing that shows it.

---

**Summary:** AddOn SavedVariables are written correctly on logout and /reload
but are not loaded back. `ADDON_LOADED` fires with the addon's saved variable
still `nil`, so every addon starts from scratch every session and then saves
that empty state over the file.

**Build:** 1.60.1.69913 (`wow_classic_beta`), Windows. Also seen on
1.60.1.69893.

**Repro, with a four-line addon:**

1. `Interface/AddOns/SVProbe/SVProbe.toc`

       ## Interface: 16001
       ## Title: SVProbe
       ## SavedVariables: SVProbeDB

       SVProbe.lua

2. `Interface/AddOns/SVProbe/SVProbe.lua`

       local ADDON = ...
       local f = CreateFrame("Frame")
       f:RegisterEvent("ADDON_LOADED")
       f:SetScript("OnEvent", function(_, _, addon)
           if addon ~= ADDON then return end
           local arrived = type(SVProbeDB)
           if type(SVProbeDB) ~= "table" then SVProbeDB = { runs = 0 } end
           SVProbeDB.runs = SVProbeDB.runs + 1
           print(("SVProbe: run %d (arrived as %s)"):format(SVProbeDB.runs, arrived))
       end)

3. Log in, log out, log in again.

**Expected:** run 2, arrived as table.
**Actual:** run 1, arrived as nil, every time. The file on disk is correct
(`WTF/Account/<account>/SavedVariables/SVProbe.lua` holds `["runs"] = 1`), so
the save works and only the load is missing.

**Notes that may narrow it down:**

- On a fresh client launch, no addon gets its saved variables.
- After a `/reload`, some do and some do not, and it has looked like a question
  of position: with four addons enabled, only the alphabetically first one was
  served; earlier, with three, the first was the only one NOT served.
- Not a size limit: a 35-byte file fails the same way a 1.27 MB one does.
- Not the file's contents: a marker table written before the addon's main table
  in the same file does not arrive either, so the file is not being executed
  and abandoned partway - it is not being executed at all.
- Not junctions: an addon folder reached through a directory junction behaves
  exactly like an ordinary one.
- Blizzard's own account-wide saved variables are written to the same folder at
  the same moments.

**Impact:** any addon that remembers anything loses it on every login, and then
overwrites the good file with an empty one. A census addon here lost 1,913
collected characters this way before the cause was found.
