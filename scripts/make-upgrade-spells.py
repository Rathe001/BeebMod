# Builds Modules/Upgrades/SpellData.lua from the Forever client's own tables,
# as wago.tools serves them (product wowf):
#
#   for t in SpellName Spell SpellEffect SpellMisc SpellDuration SpellLevels \
#            SpellCooldowns SkillLine SkillLineAbility SkillRaceClassInfo \
#            ItemEffect ItemXItemEffect ItemSparse ItemSet ItemSetSpell; do
#     curl -o $t.csv "https://wago.tools/db2/$t/csv?product=wowf"
#   done
#   py -I scripts/make-upgrade-spells.py <the folder they are in>
#
# Run it again after a patch that changes spells. The file it makes is
# shipped: Upgrades finds your spells by id in it, in any language.
#
# What goes in, and why (Josh 2026-11-17: "Anything else we can use from the
# game files? Spell names/ids would be nice", then "Let's proceed with the
# rework"):
#
#   spells  every rank of each spell the model prices, by id: what it is to
#           the model, its share of spell power, and what each number in its
#           description is, in the order the description says them. The live
#           amounts are still read from the description in game, because
#           that is the only place your talents and buffs are counted. The
#           order of its numbers comes from the description's template here,
#           so no word of it has to be understood.
#   stats   every aura that raises a stat by a percent (Blessing of Kings)
#   procs   every weapon's "Chance on hit": its damage, and whether armor
#           takes any of it
import csv
import re
import sys
from datetime import date

csv.field_size_limit(10 ** 8)
folder = sys.argv[1]


def rows(name):
    return csv.DictReader(open(folder + "/" + name + ".csv", encoding="utf-8"))


names = {int(r["ID"]): r["Name_lang"] for r in rows("SpellName")}
templates = {int(r["ID"]): r["Description_lang"] for r in rows("Spell")}
effects = {}
for r in rows("SpellEffect"):
    effects.setdefault(int(r["SpellID"]), {})[int(r["EffectIndex"])] = r
misc = {int(r["SpellID"]): r for r in rows("SpellMisc")}
durations = {int(r["ID"]): float(r["Duration"]) for r in rows("SpellDuration")}
levels = {int(r["SpellID"]): r for r in rows("SpellLevels")}

# ---------------------------------------------------------------- the model
# class -> spell name -> (what it is to the model, what each value in its
# description is, in the template's order; "-" for one the model does not
# use). Durations and plain digits in the words are skipped without being
# listed. A value the game writes as a range ("16 to 23") is one entry here.
# A second list is for a rank whose words say less. A spell of the same name
# whose words fit no list is another spell (the game has several) and is
# left out, with a line printed; a name with no spell left is an error.
MODEL = {
    "PALADIN": {
        "Holy Strike": ("holyStrike", ["percent", "holy"]),
        "Judgement": ("judgement", []),
        # ("The first 4 enemies who enter the area will take an additional...")
        "Consecration": ("consecration", ["first", "cap", "second"]),
        "Righteous Fury": ("righteousFury", ["all", "holy"]),
        "Seal of the Crusader": ("crusader", ["ap", "-", "holy"]),
        "Seal of Command": ("command", ["percent", "judge", "-"]),
        # (its first rank's words say nothing of its Judgement)
        "Seal of Righteousness": ("righteousness", ["low", "high", "judge"], ["low", "high"]),
        "Seal of Fury": ("fury", ["hit", "-", "judge"]),
        "Holy Light": ("heal:holyLight", ["amount"]),
        "Flash of Light": ("heal:flashOfLight", ["amount"]),
    },
}
CLASS_MASK = {"PALADIN": 2}

class_lines = {}
line_names = {int(r["ID"]): r["DisplayName_lang"] for r in rows("SkillLine") if r["CategoryID"] == "7"}
for r in rows("SkillRaceClassInfo"):
    if int(r["SkillID"]) in line_names:
        class_lines.setdefault(int(r["ClassMask"]), set()).add(int(r["SkillID"]))
by_line = {}
for r in rows("SkillLineAbility"):
    by_line.setdefault(int(r["SkillLine"]), set()).add(int(r["Spell"]))

TOKEN = re.compile(
    r"(?P<expr>\$\{[^}]*\})"
    r"|(?P<cond>\$\?)"
    r"|(?P<var>\$<[^>]*>)"
    r"|\$(?:/\d+;)?(?P<spell>\d*)(?P<kind>[sSmMdDaAtTxXnNiIuUeEhHrRbBqQoO])(?P<index>\d?)"
    r"|(?P<digits>\d[\d,.]*)"
)


def ranged(spell, index):
    e = effects.get(spell, {}).get(index)
    return e is not None and float(e["Variance"]) > 0


def plan(spell, keys):
    """The description's numbers, in order: a key for each, "-" to skip."""
    text = templates.get(spell, "")
    out, values = [], 0
    for m in TOKEN.finditer(text):
        if m.group("cond") or m.group("var"):
            return None, "a template this cannot plan: " + text[:80]
        if m.group("digits"):
            out.append("-")
            continue
        if m.group("expr"):
            count = 1
        else:
            kind = m.group("kind")
            if kind in "dD":
                out.append("-")
                continue
            if kind not in "sSmM":
                out.append("-")
                continue
            ref = int(m.group("spell") or spell)
            count = 2 if kind in "sS" and ranged(ref, int(m.group("index") or 1) - 1) else 1
        if values >= len(keys):
            return None, "more values than the model lists: " + text[:80]
        out.extend([keys[values]] * count)
        values += 1
    if values != len(keys):
        return None, "%d values, the model lists %d: %s" % (values, len(keys), text[:80])
    return out, None


def share(spell):
    best = 0.0
    for e in effects.get(spell, {}).values():
        best = max(best, float(e["EffectBonusCoefficient"]))
    return round(best, 4)


out = ["-- Made by scripts/make-upgrade-spells.py on %s from the game's tables" % date.today().isoformat(),
       "-- (wago.tools, product wowf). Do not edit by hand: run the script again.",
       "local _, BT = ...", "BT.Upgrades = BT.Upgrades or {}", "BT.Upgrades.SpellData = {",
       "\t-- spell id -> what it is to the model, its share of spell power, and what",
       "\t-- each number in its description is, in the order it says them",
       "\tspells = {"]
problems = 0
count = 0
for cls, model in MODEL.items():
    out.append("\t\t%s = {" % cls)
    ids, planned = set(), set()
    for line in class_lines.get(CLASS_MASK[cls], ()):
        ids |= by_line.get(line, set())
    for spell in sorted(ids, key=lambda i: (names.get(i, ""), i)):
        entry = model.get(names.get(spell))
        if not entry:
            continue
        read, why = None, None
        for keys in entry[1:]:
            read, why = plan(spell, keys)
            if read is not None:
                break
        if read is None:
            print("left out: %s %d: %s" % (names[spell], spell, why))
            continue
        planned.add(names[spell])
        bits = ['is = "%s"' % entry[0]]
        # the level it is learned at: the highest rank you know is the one
        # with the highest, whatever order the spellbook lists them in
        if spell in levels:
            bits.append("lvl = %d" % int(levels[spell]["SpellLevel"]))
        if share(spell) > 0:
            bits.append("share = %s" % share(spell))
        # a heal's own amount before any healing power, and the levels it
        # grows over: what is left of its description's amount is healing
        # power's share, which the game cuts for the lowest ranks
        if entry[0].startswith("heal:"):
            heal = [e for e in effects.get(spell, {}).values() if e["Effect"] == "10"]
            lv = levels.get(spell)
            if heal and lv:
                bits.append("base = %g, per = %g, from = %d, to = %d" % (
                    float(heal[0]["EffectBasePointsF"]), float(heal[0]["EffectRealPointsPerLevel"]),
                    int(lv["BaseLevel"]), int(lv["MaxLevel"])))
        bits.append('read = "%s"' % " ".join(read))
        out.append("\t\t\t[%d] = { %s }, -- %s" % (spell, ", ".join(bits), names[spell]))
        count += 1
    out.append("\t\t},")
    for name in model:
        if name not in planned:
            problems += 1
            print("NOT PLANNED: no spell called %s fits the model" % name)
out.append("\t},")

# ---------------------------------------------------------- stat percents
STAT = {-1: "all", 0: "strength", 1: "agility", 2: "stamina", 3: "intellect", 4: "spirit"}
out += ["\t-- aura id -> the stats it raises, by percent (MOD_TOTAL_STAT_PERCENTAGE)", "\tstats = {"]
stat_auras = 0
for spell in sorted(effects):
    found = {}
    for e in effects[spell].values():
        if e["EffectAura"] == "137":
            which, pct = STAT.get(int(e["EffectMiscValue_0"])), float(e["EffectBasePointsF"])
            if which and 0 < pct <= 50:
                found[which] = pct
    if found:
        stat_auras += 1
        out.append("\t\t[%d] = { %s }, -- %s" % (spell, ", ".join("%s = %g" % kv for kv in sorted(found.items())),
                                                 names.get(spell, "?")))
out.append("\t},")

# ------------------------------------------------------------ weapon procs
def proc_damage(spell, depth=0):
    """A spell's direct damage and its damage over time, and whether it is magic."""
    total = 0.0
    m = misc.get(spell)
    seconds = durations.get(int(m["DurationIndex"]), 0) / 1000 if m else 0
    for e in effects.get(spell, {}).values():
        base = float(e["EffectBasePointsF"])
        if e["Effect"] == "2":
            total += base
        elif e["Effect"] == "6" and e["EffectAura"] == "3" and float(e["EffectAuraPeriod"]) > 0:
            total += base * max(1, round(seconds / (float(e["EffectAuraPeriod"]) / 1000)))
        elif e["Effect"] == "64" and depth < 1 and int(e["EffectTriggerSpell"]) > 0:
            total += proc_damage(int(e["EffectTriggerSpell"]), depth + 1)[0]
    magic = m is not None and int(m["SchoolMask"]) != 1
    return total, magic


item_of = {int(r["ItemEffectID"]): int(r["ItemID"]) for r in rows("ItemXItemEffect")}
out += ["\t-- weapon's item id -> { what its \"Chance on hit\" does in damage, whether it is magic }", "\tprocs = {"]
procs = 0
for r in sorted(rows("ItemEffect"), key=lambda r: item_of.get(int(r["ID"]), 0)):
    item = item_of.get(int(r["ID"]))
    if r["TriggerType"] != "2" or not item:
        continue
    damage, magic = proc_damage(int(r["SpellID"]))
    if damage > 0:
        procs += 1
        out.append("\t\t[%d] = { %g, %s }, -- %s" % (item, damage, "true" if magic else "false",
                                                     names.get(int(r["SpellID"]), "?")))
out.append("\t},")

# ------------------------------------------- an item's other effects, as stats
# (Josh 2026-11-17, of effects that counted for nothing: "Let's fix 1-4".)
# An effect that is plainly a stat is turned into the stat, under the name
# C_Item.GetItemStats would give it, so the swap math prices it as it does
# any stat. An effect that is anything else cannot be priced, and its item
# is listed in `partly` so the tooltip can say so.
SCHOOL = {2: "HOLY", 4: "FIRE", 8: "NATURE", 16: "FROST", 32: "SHADOW", 64: "ARCANE"}
PRIMARY = ["STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT"]
# what 1% is in rating (the client's gametables/combatratings.txt, flat)
PERCENT = {"52": ("ITEM_MOD_CRIT_RATING_SHORT", 14), "54": ("ITEM_MOD_HIT_RATING_SHORT", 10),
           "49": ("ITEM_MOD_DODGE_RATING_SHORT", 12), "47": ("ITEM_MOD_PARRY_RATING_SHORT", 15),
           "51": ("ITEM_MOD_BLOCK_RATING_SHORT", 5)}
PLAIN = {"99": "ITEM_MOD_ATTACK_POWER_SHORT", "135": "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
         "161": "ITEM_MOD_HEALTH_REGEN_SHORT", "34": "ITEM_MOD_HEALTH_SHORT",
         "158": "ITEM_MOD_BLOCK_VALUE_SHORT"}


def as_stats(spell):
    """A spell's effects as stats, and whether that is all of what it does."""
    found, whole = {}, True
    rows_ = list(effects.get(spell, {}).values())
    if not rows_:
        return {}, False

    def add(key, amount):
        found[key] = found.get(key, 0) + amount

    for e in rows_:
        aura, base, which = e["EffectAura"], float(e["EffectBasePointsF"]), int(e["EffectMiscValue_0"])
        if e["Effect"] == "0":
            continue
        if e["Effect"] != "6" or base <= 0:
            whole = False
        elif aura == "29" and -1 <= which <= 4:
            for i in (range(5) if which == -1 else [which]):
                add("ITEM_MOD_%s_SHORT" % PRIMARY[i], base)
        elif aura in PLAIN:
            add(PLAIN[aura], base)
        elif aura in PERCENT:
            add(PERCENT[aura][0], base * PERCENT[aura][1])
        elif aura == "13" and which == 126:
            add("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", base)
        elif aura == "13" and which in SCHOOL:
            add("ITEM_MOD_%s_DAMAGE_DONE_SHORT" % SCHOOL[which], base)
        elif aura == "30" and which == 95:
            # "Increased Defense +7": skill line 95. Not among an item's
            # stats as the game lists them, so it has a name of our own.
            add("UPGRADES_DEFENSE", base)
        elif aura == "22" and which == 1:
            add("RESISTANCE0_NAME", base)
        elif aura == "22":
            # a resistance to magic, by school, as UnitResistance numbers them
            for bit, school in ((4, 2), (8, 3), (16, 4), (32, 5), (64, 6)):
                if which & bit:
                    add("RESISTANCE%d_NAME" % school, base)
        elif aura == "102":
            # attack power against one kind of enemy: its share is worked
            # out in the swap math (M.ENEMY_KINDS)
            add("UPGRADES_ATTACK_POWER_VS", base)
        elif aura == "131":
            pass  # the same for ranged attacks: not a paladin's
        elif aura == "85" and which == 0:
            add("ITEM_MOD_MANA_REGENERATION_SHORT", base)
        elif aura == "35" and which == 0:
            add("ITEM_MOD_MANA_SHORT", base)
        elif aura == "189":
            mask, key = which, None
            if mask & (1 << 2):
                key = "ITEM_MOD_DODGE_RATING_SHORT"
            elif mask & (1 << 3):
                key = "ITEM_MOD_PARRY_RATING_SHORT"
            elif mask & (1 << 4):
                key = "ITEM_MOD_BLOCK_RATING_SHORT"
            elif mask & (7 << 5):
                key = "ITEM_MOD_HIT_RATING_SHORT"
            elif mask & (7 << 8):
                key = "ITEM_MOD_CRIT_RATING_SHORT"
            elif mask & (7 << 17):
                key = "ITEM_MOD_HASTE_RATING_SHORT"
            if key:
                add(key, base)
            else:
                whole = False
        else:
            whole = False
    return found, whole


def lua_stats(stats):
    return "{ %s }" % ", ".join("%s = %g" % (k, round(v, 2)) for k, v in sorted(stats.items()))


WORN = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 23, 25, 26, 28}
sparse = {int(r["ID"]): r for r in rows("ItemSparse")}
cooldowns = {int(r["SpellID"]): r for r in rows("SpellCooldowns")}
uses, partly, equips = {}, set(), {}
for r in rows("ItemEffect"):
    item = item_of.get(int(r["ID"]))
    it = sparse.get(item)
    if not it or int(it["InventoryType"]) not in WORN:
        continue
    spell, trigger = int(r["SpellID"]), r["TriggerType"]
    if trigger == "0":
        # "Use:": its stats for as much of the time as it can be up
        stats, whole = as_stats(spell)
        m = misc.get(spell)
        lasts = durations.get(int(m["DurationIndex"]), 0) if m else 0
        cd = max(float(r["CoolDownMSec"]), float(r["CategoryCoolDownMSec"]))
        if cd <= 0 and spell in cooldowns:
            cd = max(float(cooldowns[spell]["RecoveryTime"]), float(cooldowns[spell]["CategoryRecoveryTime"]))
        if stats and whole and lasts > 0 and cd > 0:
            share_up = min(1.0, lasts / cd)
            into = uses.setdefault(item, {})
            for k, v in stats.items():
                into[k] = into.get(k, 0) + v * share_up
        else:
            partly.add(item)
    elif trigger == "1":
        # "Equip:": a stat is among the item's own stats already; anything
        # else is not counted
        stats, whole = as_stats(spell)
        if not whole:
            partly.add(item)
        # Defense is the one stat an "Equip:" gives that the game's list of
        # the item's stats leaves out
        if stats.get("UPGRADES_DEFENSE"):
            equips[item] = equips.get(item, 0) + stats["UPGRADES_DEFENSE"]
    elif trigger == "2":
        if proc_damage(spell)[0] <= 0:
            partly.add(item)

out += ["\t-- item id -> what its \"Use:\" gives, as stats, for the share of the time it can be up", "\tuses = {"]
for item in sorted(uses):
    out.append("\t\t[%d] = %s," % (item, lua_stats(uses[item])))
out += ["\t},", "\t-- item id -> the Defense its \"Equip:\" gives", "\tdefense = {"]
ids = sorted(equips)
for i in range(0, len(ids), 10):
    out.append("\t\t" + " ".join("[%d]=%g," % (x, equips[x]) for x in ids[i:i + 10]))
out += ["\t},", "\t-- items with an effect that is not counted: the tooltip says so", "\tpartly = {"]
ids = sorted(partly)
for i in range(0, len(ids), 12):
    out.append("\t\t" + " ".join("[%d]=1," % x for x in ids[i:i + 12]))
out.append("\t},")

# ------------------------------------------------------------------- sets
bonuses = {}
for r in rows("ItemSetSpell"):
    stats, whole = as_stats(int(r["SpellID"]))
    # (a bonus that is all resistance to magic is priced, at nothing)
    bonuses.setdefault(int(r["ItemSetID"]), []).append((int(r["Threshold"]), stats if whole else None))
# (a set's pieces from the set's own row: an item's row does not always name its set)
set_of = {}
for r in rows("ItemSet"):
    if int(r["ID"]) in bonuses:
        for k in range(17):
            piece = int(r.get("ItemID_%d" % k) or 0)
            if piece > 0:
                set_of[piece] = int(r["ID"])
used = set(set_of.values())
out += ["\t-- set id -> each bonus: { pieces needed, its stats or false where it is not a stat }", "\tsets = {"]
for s_id in sorted(used):
    parts = ["{ %d, %s }" % (need, lua_stats(stats) if stats is not None else "false")
             for need, stats in sorted(bonuses[s_id], key=lambda b: b[0])]
    out.append("\t\t[%d] = { %s }," % (s_id, ", ".join(parts)))
out += ["\t},", "\t-- item id -> the set it belongs to", "\tsetOf = {"]
ids = sorted(set_of)
for i in range(0, len(ids), 8):
    out.append("\t\t" + " ".join("[%d]=%d," % (x, set_of[x]) for x in ids[i:i + 8]))
out += ["\t},", "}"]
print(len(equips), "items with Defense,", len(uses), "use effects priced,", len(partly), "items partly priced,", len(used), "sets,", len(set_of), "set pieces")

if problems:
    sys.exit("%d of the model's spells could not be planned; nothing written" % problems)
open("Modules/Upgrades/SpellData.lua", "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(count, "spells,", stat_auras, "stat auras,", procs, "weapon procs")
