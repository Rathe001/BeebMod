# Builds Modules/Tooltips/ClassSpellData.lua: the id of every spell in every
# class's skill lines, from the Forever client's own tables as wago.tools
# serves them (product wowf).
#
#   curl -o SkillLine.csv "https://wago.tools/db2/SkillLine/csv?product=wowf"
#   curl -o SkillLineAbility.csv "https://wago.tools/db2/SkillLineAbility/csv?product=wowf"
#   curl -o SkillRaceClassInfo.csv "https://wago.tools/db2/SkillRaceClassInfo/csv?product=wowf"
#   py -I scripts/make-class-spells.py <the folder they are in>
#
# The file it makes is not kept in the repository or shipped: add
# Modules\Tooltips\ClassSpellData.lua to BeebMod.toc, above Tooltips.lua, while
# a check is run, and take both out after it.
#
# Only the ids are kept. The game has each spell's name and description, and
# the Testing page's Record asks it for them (Modules/Tooltips/Tooltips.lua,
# M.ClassesRead), so what the spell card reads from each can be checked for
# every class from one character (Josh 2026-11-16: "Was this only paladin?
# What about all the other classes?").
import collections
import csv
import sys
from datetime import date

folder = sys.argv[1]
CLASSES = {1: "Warrior", 2: "Paladin", 4: "Hunter", 8: "Rogue", 16: "Priest", 64: "Shaman", 128: "Mage",
           256: "Warlock", 1024: "Druid"}
SKIP = {"Mounts", "Companions"}


def rows(name):
    return csv.DictReader(open(folder + "/" + name + ".csv", encoding="utf-8"))


lines = {int(r["ID"]): r["DisplayName_lang"] for r in rows("SkillLine")
         if r["CategoryID"] == "7" and r["DisplayName_lang"] not in SKIP}
masks = {int(r["SkillID"]): int(r["ClassMask"]) for r in rows("SkillRaceClassInfo")}
spells = collections.defaultdict(set)
for r in rows("SkillLineAbility"):
    if int(r["SkillLine"]) in lines:
        spells[int(r["SkillLine"])].add(int(r["Spell"]))

out = ["-- Made by scripts/make-class-spells.py on %s. Do not edit by hand." % date.today().isoformat(),
       "-- Every class's spells, by skill line: ids only. For the Testing page's",
       "-- Record (Modules/Tooltips/Tooltips.lua, M.ClassesRead).",
       "local _, BT = ...", "BT.ClassSpells = {"]
total = 0
for line in sorted(spells, key=lambda k: (CLASSES.get(masks.get(k, -1), "~"), lines[k], k)):
    label = lines[line]
    who = CLASSES.get(masks.get(line, -1))
    if who:
        label = who + ": " + label
    ids = sorted(spells[line])
    total += len(ids)
    out.append('\t{ "%s", { %s } },' % (label, ", ".join(map(str, ids))))
out.append("}")
open("Modules/Tooltips/ClassSpellData.lua", "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(len(spells), "skill lines,", total, "spells")
