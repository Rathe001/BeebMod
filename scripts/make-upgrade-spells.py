# Builds Modules/Upgrades/SpellData.lua from the Forever client's own tables,
# as wago.tools serves them (product wowf):
#
#   for t in SpellName Spell SpellEffect SpellMisc SpellDuration SpellLevels \
#            SpellCooldowns SkillLine SkillLineAbility SkillRaceClassInfo \
#            ItemEffect ItemXItemEffect ItemSparse ItemSet ItemSetSpell; do
#     curl -o $t.csv "https://wago.tools/db2/$t/csv?product=wowf"
#   done
#   py -I scripts/make-upgrade-spells.py <the folder they are in> [mangos.sqlite]
#
# (SpellItemEnchantment and SpellAuraOptions too, for what is put on a weapon.)
# (SpellPower too. The second argument is the VMaNGOS database's sqlite file,
# for the threat a tank's abilities add: see scripts/make-dungeon-names.py for
# where it comes from. Without it no ability has threat of its own.)
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
# (a spell's first cost: a finishing move has a second row, for its combo points)
powers = {int(r["SpellID"]): r for r in rows("SpellPower") if r["OrderIndex"] == "0"}
cooldowns = {int(r["SpellID"]): r for r in rows("SpellCooldowns")}

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
    # THE WARRIOR (Josh 2026-11-17: "Warrior sounds good to start. We can just
    # leave healing at 0.0"). Its abilities are priced by one shared sum
    # (Roles.lua, the abilities' engine), so each is an "ability" with what
    # its numbers are and a few plain facts about how it is used, as a last
    # entry in braces:
    #   swing    it goes out with your next swing, in place of it
    #   also     it hits one more enemy beside the first
    #   weapon   your weapon's damage is in it: "norm" as the game evens it
    #            out by weapon kind, "plain" as it is
    #   aoe      it hits every enemy near, up to `cap` where its words say
    #   dot      it is damage over time, said as a total
    #   after    it can only follow something: the enemy's "dodge", or your
    #            own "avoid" (a block, dodge or parry)
    #   tank     it is a tank's: priced for threat only
    #   shield   it needs a shield; blockvalue: your block value is added
    #   part     the part of a fight it can be used in (Execute: the last fifth)
    #   twohand  it needs a two-handed weapon
    # Keys: add (damage on top of a weapon's), hit (its own damage), appct
    # (a percent of your attack power), dot, cap, rage, "-".
    "WARRIOR": {
        "Heroic Strike": ("ability", ["add"], {"swing": True}),
        "Cleave": ("ability", ["add"], {"swing": True, "also": 1}),
        "Mortal Strike": ("ability", ["add", "-"], {"weapon": "norm"}),
        "Bloodthirst": ("ability", ["appct", "add", "-"], {}),
        # (the tables give Slam a shared cooldown it does not have in play)
        "Slam": ("ability", ["add"], {"weapon": "plain", "nocd": True}),
        "Whirlwind": ("ability", ["cap"], {"weapon": "norm", "aoe": True}),
        "Rend": ("ability", ["dot"], {"dot": True}),
        "Thunder Clap": ("ability", ["-", "hit", "cap"], {"aoe": True}),
        "Overpower": ("ability", ["add"], {"weapon": "norm", "after": "dodge"}),
        "Revenge": ("ability", ["hit", "hit"], {"after": "avoid", "tank": True}),
        "Shield Slam": ("ability", ["hit", "-"], {"shield": True, "blockvalue": True, "tank": True}),
        "Execute": ("ability", ["hit"], {"part": 0.2}),
        "Sunder Armor": ("ability", ["-"], {"tank": True}),
        # what gives rage outright: once a fight, or every so many seconds
        "Charge": ("rage", ["rage"], {}),
        "Bloodrage": ("rage", ["rage", "more"], {"every": 60}),
    },
    # THE MAGE (Josh 2026-11-17: "We could do mage next - i do have one of
    # those, but I'd rather use numbers from the game data"). The same sum
    # prices it, with mana for rage and casting time for the time. A spell is
    # an "ability" marked `magic`; its school, its shares of spell power and
    # how long it lasts are taken from the tables. More facts:
    #   over     the damage over time trails a hit, and casting it again
    #            starts it over (Fireball's burn)
    #   channel  it is cast for as long as it lasts
    # Keys: hit (damage at once), dot (a total over time), tick (an amount
    # each second for as long as it lasts), "-".
    # Left out: spells whose cost is a percent of your mana and whose damage
    # is worked out from your level (Arcane Barrage, Living Bomb, Balefire
    # Bolt, Spellfrost Bolt, Frozen Orb, Living Flame, Arcane Surge).
    "MAGE": {
        "Fireball": ("ability", ["hit", "dot"], {"magic": True, "over": True}),
        "Frostbolt": ("ability", ["hit", "hit", "-"], {"magic": True}),
        "Frostfire Bolt": ("ability", ["hit", "-", "dot"], {"magic": True, "over": True}),
        "Fire Blast": ("ability", ["hit"], {"magic": True}),
        "Scorch": ("ability", ["hit"], {"magic": True}),
        "Pyroblast": ("ability", ["hit", "dot"], {"magic": True, "over": True}),
        "Arcane Missiles": ("ability", ["tick"], {"magic": True, "channel": True}),
        "Arcane Blast": ("ability", ["hit", "-", "-"], {"magic": True}),
        "Ice Lance": ("ability", ["hit", "-"], {"magic": True}),
        "Arcane Explosion": ("ability", ["hit"], {"magic": True, "aoe": True}),
        "Flamestrike": ("ability", ["hit", "dot"], {"magic": True, "aoe": True, "over": True}),
        "Blizzard": ("ability", ["dot"], {"magic": True, "aoe": True, "channel": True}),
        "Cone of Cold": ("ability", ["hit", "hit", "-", "-", "-", "-"], ["hit", "hit", "-"], {"magic": True, "aoe": True}),
        "Blast Wave": ("ability", ["hit", "-"], {"magic": True, "aoe": True}),
        "Frost Nova": ("ability", ["hit", "hit"], {"magic": True, "aoe": True}),
        # mana given back: "your mana regeneration is active and increased
        # by 1500%", for as long as it lasts
        "Evocation": ("mana", ["pct"], {}),
    },
    # THE ROGUE (Josh 2026-11-18: "Commit, then start on rogue"). The same sum,
    # with energy for rage. More facts:
    #   energy    the class spends energy, which comes at a set rate
    #   points    it awards a combo point
    #   finisher  it spends combo points: its numbers are one for each count
    #             of points, p1 to p5 (damage), r1 to r5 with t1 to t5 (a
    #             bleed's total and its seconds), or pct with t1 to t5 (attack
    #             speed and its seconds: `speed`)
    #   dagger    it needs a dagger in the main hand
    #   behind    it needs you behind the enemy: not while you fight alone
    #   opener    it needs stealth: once a fight
    #   literal   a number its words say outright, by which one it is, where
    #             the tables do not have it as a value ("plus 290")
    # Keys: pct (a percent of weapon damage), pctdagger (the same with a
    # dagger), add, dot, "-".
    # Left out: poisons, Mutilate, Saber Slash, Shiv, Main Gauche, Between
    # the Eyes, Riposte, Blade Flurry and Adrenaline Rush.
    "ROGUE": {
        "Sinister Strike": ("ability", ["add", "-"], {"weapon": "norm", "points": 1, "energy": True}),
        "Backstab": ("ability", ["pct", "add", "-"],
                     {"weapon": "norm", "points": 1, "energy": True, "dagger": True, "behind": True}),
        "Ambush": ("ability", ["pct", "add", "-"], ["pct", "-"],
                   {"weapon": "norm", "points": 1, "energy": True, "dagger": True, "opener": True, "literal": {1: "add"}}),
        "Garrote": ("ability", ["dot", "-"], {"dot": True, "points": 1, "energy": True, "opener": True}),
        "Hemorrhage": ("ability", ["pct", "pctdagger", "-", "-"], {"weapon": "norm", "points": 1, "energy": True}),
        "Ghostly Strike": ("ability", ["pct", "pctdagger", "-", "-"], {"weapon": "norm", "points": 1, "energy": True}),
        "Eviscerate": ("ability", ["p1", "p1", "p2", "p2", "p3", "p3", "p4", "p4", "p5", "p5"],
                       {"finisher": True, "energy": True}),
        "Rupture": ("ability", ["r1", "t1", "r2", "t2", "r3", "t3", "r4", "t4", "r5", "t5"],
                    {"finisher": True, "energy": True, "bleed": True}),
        "Slice and Dice": ("ability", ["pct", "t1", "t2", "t3", "t4", "t5"], {"finisher": True, "energy": True, "speed": True}),
    },
    # THE HUNTER (Josh 2026-11-18: "Commit and work on hunter"). The same sum,
    # with mana, and its shots in place of swings. More facts:
    #   ranged  the class fights with a ranged weapon: its Auto Shot is what
    #           swings are to the others, and a shot's weapon damage is the
    #           ranged weapon's
    #   lasts   it is damage over time and nothing else: once each time it
    #           runs out (Serpent Sting)
    # A shot that is magic (Arcane Shot) lands and crits as a shot does.
    # Left out: its melee (Raptor Strike, Mongoose Bite), traps, Black Arrow,
    # Chimera Shot, Carve, Flanking Strike, Kill Command and Rapid Fire.
    "HUNTER": {
        "Aimed Shot": ("ability", ["add"], {"weapon": "plain", "ranged": True}),
        "Sniper Shot": ("ability", ["add", "-"], {"weapon": "plain", "ranged": True}),
        "Arcane Shot": ("ability", ["hit"], {"magic": True, "ranged": True}),
        "Multi-Shot": ("ability", ["cap"], {"weapon": "plain", "aoe": True, "ranged": True}),
        "Serpent Sting": ("ability", ["dot"], {"magic": True, "lasts": True, "ranged": True}),
        "Volley": ("ability", ["tick"], {"magic": True, "aoe": True, "channel": True, "ranged": True}),
    },
    # THE WARLOCK (Josh 2026-11-18: "Ok, next class?"). A caster, as the mage
    # is, with damage over time kept up, a pet, and Life Tap. More facts:
    #   period  a `tick` is an amount each so many seconds, from the tables
    #           (Siphon Life: every 3)
    #   pet     the class fights with a pet
    # Life Tap is a "tap": its second number is the mana it gives.
    # Left out: Bane of Doom (one Bane at a time, and Agony is the one
    # priced), Conflagrate (it uses up Immolate), Hellfire, Drain Soul, Death
    # Coil, and Chaos Bolt and Shadowflame, whose damage is worked out from
    # your level.
    "WARLOCK": {
        "Shadow Bolt": ("ability", ["hit"], {"magic": True, "pet": True}),
        "Searing Pain": ("ability", ["hit"], {"magic": True, "pet": True}),
        "Soul Fire": ("ability", ["hit"], {"magic": True, "pet": True}),
        "Shadowburn": ("ability", ["hit"], {"magic": True, "pet": True}),
        "Incinerate": ("ability", ["hit", "-"], {"magic": True, "pet": True}),
        "Immolate": ("ability", ["hit", "dot"], {"magic": True, "lasts": True, "pet": True}),
        "Corruption": ("ability", ["dot"], {"magic": True, "lasts": True, "pet": True}),
        "Bane of Agony": ("ability", ["dot"], {"magic": True, "lasts": True, "pet": True}),
        "Siphon Life": ("ability", ["tick"], {"magic": True, "lasts": True, "period": True, "pet": True}),
        "Drain Life": ("ability", ["tick"], {"magic": True, "channel": True, "period": True, "pet": True}),
        "Rain of Fire": ("ability", ["dot"], {"magic": True, "aoe": True, "channel": True, "pet": True}),
        "Life Tap": ("tap", ["-", "mana"], {}),
    },
    # THE PRIEST (Josh 2026-11-18: "Let's go ahead with that spec work"). A
    # caster, and a healer by the heals' own sum (Roles.lua, R.FightHealing),
    # which any class's "heal:" spells go into.
    # Left out: Renew and the other heals over time, Prayer of Healing,
    # Penance, Starshards, Shadow Word: Death, Mind Spike and Vampiric Touch.
    # TWO WAYS (Josh 2026-11-18, of specs for the classes where they change
    # the answer: "Let's do the 2 classes where it changes the answer"). In
    # Shadowform a priest casts Shadow spells only, so Smite and Holy Fire
    # are marked for the other way. See SPECS.
    "PRIEST": {
        "Smite": ("ability", ["hit"], {"magic": True, "spec": "holy"}),
        "Holy Fire": ("ability", ["hit", "dot"], {"magic": True, "over": True, "spec": "holy"}),
        "Mind Blast": ("ability", ["hit"], {"magic": True}),
        "Shadow Word: Pain": ("ability", ["dot"], {"magic": True, "lasts": True}),
        "Devouring Plague": ("ability", ["dot"], {"magic": True, "lasts": True}),
        "Mind Flay": ("ability", ["dot", "-"], {"magic": True, "channel": True}),
        "Lesser Heal": ("heal:lesserHeal", ["amount"]),
        "Heal": ("heal:heal", ["amount"]),
        "Greater Heal": ("heal:greaterHeal", ["amount"]),
        "Flash Heal": ("heal:flashHeal", ["amount"]),
    },
    # THE SHAMAN, WHICH FIGHTS TWO WAYS (Josh 2026-11-18: "Shaman and druid
    # will be difficult since the player could either have a melee spec or
    # caster. We need to determine which one by which talents they have
    # selected. The rotation formula will be completely different based on
    # that."). An ability marked `spec` is used in that way of fighting
    # only; one with no mark, in every way. The ways themselves are in SPECS,
    # below.
    # The three shocks share a cooldown, so one is priced: Earth Shock.
    # Chain Lightning is counted at full damage on each enemy it reaches;
    # each jump does less.
    # Left out: the weapon imbues (Windfury, Rockbiter, Flametongue), totems,
    # Lightning Shield, Chain Heal (its words change with a talent), Lava
    # Lash and Molten Blast.
    "SHAMAN": {
        "Lightning Bolt": ("ability", ["hit"], {"magic": True, "spec": "caster"}),
        "Chain Lightning": ("ability", ["hit", "cap"], {"magic": True, "aoe": True, "spec": "caster"}),
        "Earth Shock": ("ability", ["hit"], {"magic": True}),
        "Stormstrike": ("ability", ["pct", "-"], {"weapon": "norm", "spec": "melee"}),
        "Healing Wave": ("heal:healingWave", ["amount"]),
        "Lesser Healing Wave": ("heal:lesserHealingWave", ["amount"]),
    },
    # THE DRUID (Josh 2026-11-18: "Start druid"), which fights three ways: a
    # caster, a cat (energy and combo points, as the rogue) and a bear (rage,
    # as the warrior; the tank's way). See SPECS.
    # A cat's or a bear's weapon damage is its paws', which the game gives
    # only while you are in the form: Read.lua keeps it from then.
    # Ferocious Bite's amounts are plain numbers in its words, so each is
    # named by which number it is (`literal`).
    # Left out: Rejuvenation and Regrowth's heal over time, Lacerate,
    # Tiger's Fury, Starsurge, Sunfire, Nourish and Innervate.
    "DRUID": {
        "Wrath": ("ability", ["hit"], {"magic": True, "spec": "caster"}),
        "Starfire": ("ability", ["hit"], {"magic": True, "spec": "caster"}),
        "Moonfire": ("ability", ["hit", "dot"], {"magic": True, "lasts": True, "spec": "caster"}),
        "Insect Swarm": ("ability", ["-", "dot"], {"magic": True, "lasts": True, "spec": "caster"}),
        "Hurricane": ("ability", ["tick", "-"], {"magic": True, "aoe": True, "channel": True, "spec": "caster"}),
        "Claw": ("ability", ["pct", "add", "-"], {"weapon": "plain", "points": 1, "spec": "cat"}),
        "Shred": ("ability", ["pct", "add", "-"], {"weapon": "plain", "points": 1, "behind": True, "spec": "cat"}),
        "Rake": ("ability", ["hit", "dot", "-"], {"points": 1, "lasts": True, "spec": "cat"}),
        "Rip": ("ability", ["r1", "r2", "r3", "r4", "r5"], {"finisher": True, "bleed": True, "spec": "cat"}),
        "Ferocious Bite": ("ability", ["-"], {"finisher": True, "spec": "cat", "literal": {
            2: "p1", 3: "p1", 5: "p2", 6: "p2", 8: "p3", 9: "p3", 11: "p4", 12: "p4", 14: "p5", 15: "p5"}}),
        "Maul": ("ability", ["add"], {"swing": True, "spec": "bear"}),
        # (411128 is the cat's Swipe, "250% weapon damage ... 1 combo point":
        # its two numbers read as how many it reaches and its damage)
        "Swipe": ("ability", ["cap", "hit"], {"aoe": True, "spec": "bear", "except": [411128]}),
        "Enrage": ("rage", ["rage", "more"], {"every": 60}),
        "Healing Touch": ("heal:healingTouch", ["amount"]),
        "Regrowth": ("heal:regrowth", ["amount", "-"]),
    },
}
CLASS_MASK = {"PALADIN": 2, "WARRIOR": 1, "MAGE": 128, "ROGUE": 8, "HUNTER": 4, "WARLOCK": 256, "PRIEST": 16, "SHAMAN": 64,
              "DRUID": 1024}

# THE WAYS A CLASS FIGHTS, for one that has more than one (see THE SHAMAN).
# For each: how it is priced (caster: by casting, with no swings; mana: its
# abilities are paid in mana beside its swings), and `marks`, the talents
# only that way takes. The one with the most of its marks known is yours.
# With none known, each is priced and the higher kept, which follows gear.
SPECS = {
    "SHAMAN": {
        "melee": {"mana": True, "marks": ["Stormstrike", "Flurry", "Thundering Strikes", "Two-Handed Axes and Maces",
                                          "Weapon Mastery", "Spirit Weapons"]},
        "caster": {"caster": True, "marks": ["Elemental Fury", "Elemental Focus", "Call of Thunder", "Lightning Mastery",
                                             "Convection", "Concussion"]},
    },
    # (shadow: Shadow spells only, as in Shadowform. holy: everything, which
    # is how a priest with no Shadowform fights.)
    "PRIEST": {
        "holy": {"caster": True, "marks": ["Holy Specialization", "Spiritual Healing", "Divine Fury", "Searing Light",
                                           "Force of Will", "Spirit of Redemption", "Spiritual Guidance", "Improved Healing",
                                           "Improved Renew"]},
        "shadow": {"caster": True, "marks": ["Shadowform", "Darkness", "Shadow Weaving", "Vampiric Embrace", "Shadow Focus",
                                             "Shadow Affinity", "Improved Mind Blast", "Blackout",
                                             "Improved Shadow Word: Pain"]},
    },
    # (`form`: it is fought in a form, whose stats are not yours as you
    # stand. `tank`: the tank's way, priced for threat and survival, and
    # never the DPS number.)
    "DRUID": {
        "caster": {"caster": True, "marks": ["Moonkin Form", "Moonfury", "Improved Wrath", "Improved Starfire", "Vengeance",
                                             "Nature's Grace", "Moonglow", "Improved Moonfire"]},
        "cat": {"energy": True, "form": "cat", "marks": ["Sharpened Claws", "Improved Shred", "Savage Fury", "Feral Aggression",
                                                         "Predatory Strikes", "Blood Frenzy", "Shredding Attacks",
                                                         "Heart of the Wild", "Leader of the Pack"]},
        "bear": {"tank": True, "form": "bear", "marks": []},
    },
}

# a school's place in the game's list of spell power (GetSpellBonusDamage)
SCHOOL_AT = {2: 2, 4: 3, 8: 4, 16: 5, 32: 6, 64: 7}


def direct_share(spell):
    return max([float(e["EffectBonusCoefficient"]) for e in effects.get(spell, {}).values() if e["Effect"] == "2"] or [0.0])


def magic_bits(spell, rules=None):
    """A spell's school, its two shares of spell power and how long it lasts."""
    m = misc.get(spell)
    mask = int(m["SchoolMask"]) if m else 0
    at = [SCHOOL_AT[b] for b in sorted(SCHOOL_AT) if mask & b]
    bits = ["spell = %d" % at[0]] if at else []
    if len(at) > 1:
        bits.append("spell2 = %d" % at[1])
    secs = durations.get(int(m["DurationIndex"]), 0) / 1000 if m else 0
    over = 0.0
    for e in effects.get(spell, {}).values():
        period = float(e["EffectAuraPeriod"]) / 1000
        if e["Effect"] != "6" or period <= 0 or secs <= 0:
            continue
        ticks = round(secs / period)
        if (rules or {}).get("period") and not any(b.startswith("period") for b in bits):
            bits.append("period = %g" % period)
        # (damage over time, and health taken over time: Siphon Life)
        if e["EffectAura"] in ("3", "53"):
            over += float(e["EffectBonusCoefficient"]) * ticks
        elif e["EffectAura"] == "23" and int(e["EffectTriggerSpell"]) > 0:
            # (each tick casts a spell: Arcane Missiles)
            over += direct_share(int(e["EffectTriggerSpell"])) * ticks
        elif e["EffectAura"] == "226":
            # (each tick is a spell its words name: Blizzard, Flamestrike)
            ref = re.search(r"\$(\d+)[mMsS]1", templates.get(spell, ""))
            if ref:
                over += direct_share(int(ref.group(1))) * ticks
    if direct_share(spell) > 0:
        bits.append("share = %s" % round(direct_share(spell), 4))
    if over > 0:
        bits.append("dshare = %s" % round(over, 4))
    if secs > 0:
        bits.append("secs = %g" % secs)
    return bits

# THREAT AN ABILITY ADDS OUTRIGHT, from the VMaNGOS world database's
# spell_threat table (https://github.com/vmangos/core, GPL-2.0), where its
# sqlite file is given as a second argument. The client's tables have no
# such list. It is the original game's, and Forever's may differ.
threat = {}
if len(sys.argv) > 2:
    import sqlite3
    for entry, amount, mult in sqlite3.connect(sys.argv[2]).execute("select entry, threat, multiplier from spell_threat"):
        threat[entry] = (amount, mult)

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
    r"|\$(?:[/*]\d+;)?(?P<spell>\d*)(?P<kind>[sSmMdDaAtTxXnNiIuUeEhHrRbBqQoOfF])(?P<index>\d?)"
    r"|(?P<digits>\d[\d,.]*)"
)


def ranged(spell, index):
    e = effects.get(spell, {}).get(index)
    return e is not None and float(e["Variance"]) > 0


def plan(spell, keys, literal=None):
    """The description's numbers, in order: a key for each, "-" to skip."""
    text = templates.get(spell, "")
    out, values, said, ended = [], 0, 0, -1
    for m in TOKEN.finditer(text):
        if m.group("cond") or m.group("var"):
            return None, "a template this cannot plan: " + text[:80]
        was, ended = ended, m.end()
        if m.group("digits"):
            # (digits after a point that follows a value are the rest of
            # that one number as the game writes it: "${$m2/100}.1" is "2.1")
            if was == m.start() - 1 and text[was] == ".":
                continue
            said += 1
            out.append((literal or {}).get(said, "-"))
            continue
        if m.group("expr"):
            count = 1
        else:
            kind = m.group("kind")
            if kind in "dD":
                out.append("-")
                continue
            # (what a spell says outright: its amounts, its total over time,
            # how many it reaches. Anything else is a number of no use here.)
            if kind not in "sSmMoOiIxX":
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
        rules = {}
        for keys in entry[1:]:
            if isinstance(keys, dict):
                rules = keys
        # (another spell of the same name whose words happen to fit)
        if spell in rules.get("except", ()):
            continue
        for keys in entry[1:]:
            if isinstance(keys, dict):
                continue
            read, why = plan(spell, keys, rules.get("literal"))
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
        if share(spell) > 0 and entry[0] not in ("ability", "rage", "mana", "tap"):
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
        if entry[0] == "mana":
            m = misc.get(spell)
            bits.append("secs = %g" % (durations.get(int(m["DurationIndex"]), 0) / 1000 if m else 0))
        if entry[0] in ("ability", "rage", "mana", "tap"):
            # every rank of an ability under one name; its cost and cooldown
            # as the tables have them, for where the game will not say
            bits.append('key = "%s"' % re.sub(r"[^a-z]", "", names[spell].lower()))
            p = powers.get(spell)
            if p and float(p["ManaCost"]) > 0:
                bits.append("cost = %g" % (float(p["ManaCost"]) / (10 if p["PowerType"] == "1" else 1)))
            c = cooldowns.get(spell)
            if c:
                cd = max(float(c["RecoveryTime"]), float(c["CategoryRecoveryTime"])) / 1000
                if cd > 0 and not rules.get("nocd"):
                    bits.append("cd = %g" % cd)
            if rules.get("dot") or ((rules.get("lasts") or rules.get("bleed")) and not rules.get("magic")):
                m = misc.get(spell)
                bits.append("secs = %g" % (durations.get(int(m["DurationIndex"]), 0) / 1000 if m else 0))
            if spell in threat and not rules.get("magic"):
                bits.append("threat = %g, tmult = %g" % threat[spell])
            if rules.get("magic"):
                bits += magic_bits(spell, rules)
            for k, v in sorted(rules.items()):
                if k in ("nocd", "magic", "literal", "period", "except"):
                    continue
                bits.append("%s = %s" % (k, "true" if v is True else ('"%s"' % v if isinstance(v, str) else "%g" % v)))
        bits.append('read = "%s"' % " ".join(read))
        out.append("\t\t\t[%d] = { %s }, -- %s" % (spell, ", ".join(bits), names[spell]))
        count += 1
    out.append("\t\t},")
    for name in model:
        if name not in planned:
            problems += 1
            print("NOT PLANNED: no spell called %s fits the model" % name)
out.append("\t},")

# ------------------------------------------------------------------ specs
out += ["\t-- class -> way of fighting -> how it is priced, and the talents that mark it", "\tspecs = {"]
for cls, ways in SPECS.items():
    ids = set()
    for line in class_lines.get(CLASS_MASK[cls], ()):
        ids |= by_line.get(line, set())
    out.append("\t\t%s = {" % cls)
    for way, facts in ways.items():
        marks = sorted(i for i in ids if names.get(i) in facts["marks"])
        missing = [m for m in facts["marks"] if not any(names.get(i) == m for i in ids)]
        if missing:
            problems += 1
            print("NO SUCH TALENT for %s %s: %s" % (cls, way, ", ".join(missing)))
        flags = ", ".join(('%s = "%s"' % (k, facts[k])) if isinstance(facts[k], str) else "%s = true" % k
                          for k in sorted(facts) if k != "marks")
        out.append("\t\t\t%s = { %s%smarks = { %s } }," % (way, flags, ", " if flags else "",
                                                          ", ".join("[%d] = true" % i for i in marks)))
    out.append("\t\t},")
out.append("\t},")

# ------------------------------------------------------------ crit talents
# (Josh 2026-11-18, asked whether talents are counted, then: "Let's do the
# crit".) A passive that raises the crit chance of some spells (Critical
# Mass) or the damage their crits add (Ice Shards, Impale) is in the tables
# with the exact spells it touches: its effect has a mask, and each spell
# says which bits of its class's mask it is. The game's own totals do not
# show these, since they are not on you but on the spell. So each is listed
# here with the abilities of the model it touches:
#   crit   percent added to the spell's crit chance
#   more   percent added to what a crit adds (100: a spell crit is double)
#   after  percent of a crit's whole damage dealt again over time (Ignite,
#          by name: the tables have it as an effect with no meaning of its
#          own, so its spells are taken to be every Fire spell, as it says)
#   of     the talent's name, where each rank is a spell of its own: the
#          highest you know is the one counted
options = {int(r["SpellID"]): r for r in rows("SpellClassOptions")}
AFTER_CRIT = {"Ignite": 4}
# A FORM THAT DOES WHAT A CRIT TALENT DOES, and is not a passive: it counts
# for the way of fighting that is in it (`spec`). Shadowform: "increasing
# the critical strike damage bonus of your Shadow spells by 100%".
IN_FORM = {"Shadowform": "shadow"}


def bits_of(row, prefix):
    return [int(row[prefix + str(i)]) & 0xFFFFFFFF for i in range(4)]


out += ["\t-- a passive's id -> what it does to the crits of which abilities", "\ttalents = {"]
talents = 0
for cls, model in MODEL.items():
    ids = set()
    for line in class_lines.get(CLASS_MASK[cls], ()):
        ids |= by_line.get(line, set())
    priced = {i: re.sub(r"[^a-z]", "", names[i].lower()) for i in ids
              if names.get(i) in model and model[names[i]][0] == "ability"}
    found = []
    for spell in sorted(ids):
        m = misc.get(spell)
        if not m or not (int(m["Attributes_0"]) & 0x40 or names.get(spell) in IN_FORM):
            continue
        for e in effects.get(spell, {}).values():
            what, keys = None, set()
            if e["EffectAura"] == "107" and e["EffectMiscValue_0"] == "7":
                what = "crit"
            elif e["EffectAura"] == "108" and e["EffectMiscValue_0"] == "15":
                what = "more"
            elif names.get(spell) in AFTER_CRIT and e["EffectIndex"] == "0":
                what = "after"
                keys = {k for i, k in priced.items() if misc.get(i) and int(misc[i]["SchoolMask"]) & AFTER_CRIT[names[spell]]}
            if what in ("crit", "more"):
                mask = bits_of(e, "EffectSpellClassMask_")
                for i, k in priced.items():
                    o = options.get(i)
                    if o and any(a & b for a, b in zip(mask, bits_of(o, "SpellClassMask_"))):
                        keys.add(k)
            amount = float(e["EffectBasePointsF"])
            if what and keys and amount > 0:
                # which number of its description the amount is, so the game's
                # own words can say it where your points in the talent change it
                nth, at = 0, 0
                for t in TOKEN.finditer(templates.get(spell, "")):
                    at += 1
                    if t.group("kind") and t.group("kind") in "sSmM" and not t.group("spell") \
                            and int(t.group("index") or 1) - 1 == int(e["EffectIndex"]):
                        nth = at
                        break
                way = IN_FORM.get(names[spell])
                found.append('\t\t\t[%d] = { %s = %g, nth = %d, of = "%s", %skeys = { %s } }, -- %s' % (
                    spell, what, amount, nth, re.sub(r"[^a-z]", "", names[spell].lower()),
                    'spec = "%s", ' % way if way else "",
                    ", ".join("%s = true" % k for k in sorted(keys)), names[spell]))
    if found:
        talents += len(found)
        out += ["\t\t%s = {" % cls] + found + ["\t\t},"]
out.append("\t},")
print("%d crit talents" % talents)

# ------------------------------------------------- what is put on a weapon
# (Josh 2026-11-18, of what was left: "proceed". A rogue's poison and a
# shaman's imbue change what a weapon is worth: a fast one lands a poison
# more often, and Windfury swings a slow one again.) Both are a temporary
# enchantment on the weapon, and the game says which one is on by its id.
# For each that does damage:
#   hit       a chance on each hit to do so much (Instant Poison)
#   dot       a chance on each hit to put on damage over time that stacks
#             (Deadly Poison): so much every `period` seconds for `secs`
#   windfury  a chance on each hit for extra swings with more attack power.
#             Its numbers are in the rank of Windfury Weapon that puts it on,
#             found by its number: "Windfury 2" is the second rank.
#   flame     damage on every hit, by the weapon's speed: `low` at a speed
#             of 1.3 and `high` at 4.0, as Flametongue Weapon's words work
#             them out (its number over 77, and over 25).
aura_options = {int(r["SpellID"]): r for r in rows("SpellAuraOptions")}


def ranks_of(name):
    """The ranks of an imbue a shaman casts, lowest first."""
    found = [i for i, n in names.items() if n == name and "Imbue the Shaman" in templates.get(i, "") and i in levels]
    return sorted(found, key=lambda i: int(levels[i]["SpellLevel"]))


def base_of(spell, index):
    e = effects.get(spell, {}).get(index)
    return float(e["EffectBasePointsF"]) if e else None


out += ["\t-- a weapon's temporary enchantment -> the damage it adds (see the script)", "\tenchants = {"]
enchants = 0
windfury, flametongue = ranks_of("Windfury Weapon"), ranks_of("Flametongue Weapon")
for r in sorted(rows("SpellItemEnchantment"), key=lambda r: int(r["ID"])):
    name, line = r["Name_lang"], None
    numbered = re.match(r"^(Windfury|Flametongue) (\d+)$", name)
    if numbered and numbered.group(1) == "Windfury" and int(numbered.group(2)) <= len(windfury):
        text = templates[windfury[int(numbered.group(2)) - 1]]
        said = re.search(r"\$(\d+)s2 extra .*?\$(\d+)s1 extra", text)
        chance = re.search(r"(\d+)% chance", text)
        if said and chance:
            attacks, ap = base_of(int(said.group(1)), 1), base_of(int(said.group(2)), 0)
            if attacks and ap:
                line = 'kind = "windfury", chance = %s, attacks = %g, ap = %g' % (chance.group(1), attacks, ap)
        if not line:
            problems += 1
            print("NO NUMBERS for " + name)
    elif numbered and int(numbered.group(2)) <= len(flametongue):
        text = templates[flametongue[int(numbered.group(2)) - 1]]
        said = re.search(r"\$\{\$(\d+)m1/77-1\+\(\$(\d+)m1\)\} to \$\{\$(\d+)m1/25\+\(\$(\d+)m1\)\}", text)
        if said:
            per, more = base_of(int(said.group(1)), 0), base_of(int(said.group(2)), 0)
            if per is not None and more is not None:
                line = 'kind = "flame", low = %g, high = %g' % (round(per / 77 - 1 + more, 2), round(per / 25 + more, 2))
        if not line:
            problems += 1
            print("NO NUMBERS for " + name)
    elif r["Effect_0"] == "1" and int(r["EffectArg_0"]) in effects and float(r["EffectPointsMin_0"]) > 0:
        spell = int(r["EffectArg_0"])
        m = misc.get(spell)
        for e in effects[spell].values():
            base = float(e["EffectBasePointsF"])
            if e["Effect"] == "2" and base > 0:
                line = 'kind = "hit", chance = %g, hit = %g' % (float(r["EffectPointsMin_0"]), base)
            elif e["Effect"] == "6" and e["EffectAura"] == "3" and base > 0 and float(e["EffectAuraPeriod"]) > 0 and m:
                o = aura_options.get(spell)
                line = 'kind = "dot", chance = %g, tick = %g, period = %g, secs = %g, stacks = %d' % (
                    float(r["EffectPointsMin_0"]), base, float(e["EffectAuraPeriod"]) / 1000,
                    durations.get(int(m["DurationIndex"]), 0) / 1000, max(1, int(o["CumulativeAura"]) if o else 1))
            if line:
                break
    if line:
        enchants += 1
        out.append("\t\t[%s] = { %s }, -- %s" % (r["ID"], line, name))
out.append("\t},")
print("%d weapon enchantments" % enchants)

# ---------------------------------------------------------- stat percents
STAT = {-1: "all", 0: "strength", 1: "agility", 2: "stamina", 3: "intellect", 4: "spirit"}
out += ["\t-- aura id -> the stats it raises, by percent (MOD_TOTAL_STAT_PERCENTAGE)", "\tstats = {"]
stat_auras = 0
for spell in sorted(effects):
    found = {}
    for e in effects[spell].values():
        if e["EffectAura"] == "137":
            # WHICH STATS: the second number is a bit for each (1 strength,
            # 2 agility, 4 stamina, 8 intellect, 16 spirit), and it is the
            # one to go by. The first is 0 for Divine Intellect and Divine
            # Strength alike, which made every such talent strength.
            pct, bits = float(e["EffectBasePointsF"]), int(e["EffectMiscValue_1"])
            if not 0 < pct <= 50:
                continue
            if bits & 31 == 31:
                found["all"] = pct
            elif bits & 31:
                for i in range(5):
                    if bits & (1 << i):
                        found[STAT[i]] = pct
            elif STAT.get(int(e["EffectMiscValue_0"])):
                found[STAT[int(e["EffectMiscValue_0"])]] = pct
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
