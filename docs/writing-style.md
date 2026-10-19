# Writing style

How BeebMod talks: tooltips, settings, notes, toasts, empty states, chat lines,
the journal's descriptions, the README and the changelog. The same style
applies to what Claude writes to Josh: replies, reports and summaries. (Code
comments have their own house style, described at the end.)

## The voice: windowpane prose

George Orwell wrote, in "Why I Write" (1946): "Good prose is like a
windowpane." The reader looks through the words at the thing being described,
and does not notice the glass. If a sentence makes the reader notice the
writer, the wording, or the effort, the glass is dirty.

That is the whole idea. Everything below is a way of keeping the glass clean.

Three writers show how it is done. Each explained hard things to people who
did not know them yet, and each let the subject do the work.

- **Isaac Asimov** chose clarity over every other virtue. In his introduction
  to *Nemesis* (1989) he wrote that he had "made up my mind long ago to follow
  one cardinal rule in all my writing — to be clear", and had given up writing
  "poetically or symbolically or experimentally". What we take: when a choice
  is between clear and clever, choose clear. Plain words in plain order, so
  the reader never has to read a sentence twice.
- **Carlo Rovelli** (*Seven Brief Lessons on Physics*, *The Order of Time*)
  explains quantum gravity to people who have never studied physics. His
  books are short and his chapters shorter. He puts one idea in front of the
  reader at a time and gives it an ordinary picture to stand on. What we take:
  keep it short, take one step at a time, and reach for the everyday picture
  before the technical term.
- **Richard Feynman** (his 1965 Nobel lecture) talks like a person across the
  table. He says what happened in the order it happened, uses everyday words
  for technical things ("bookkeeping variables"), gives a concrete picture
  instead of a general claim, and says plainly what he doesn't know. What we
  take: say what happens, in order, and say it when you don't know.

What they share is that the writer steps out of the way. None of them sells,
decorates or performs. The reader comes away knowing the subject, not
admiring the sentences.

## Orwell's rules

From "Politics and the English Language" (1946), and still the best short
list:

1. Never use a metaphor, simile or other figure of speech which you are used
   to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word or a jargon word if you can
   think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

And his questions for each sentence: What am I trying to say? What words will
express it? What image or idiom will make it clearer? Is this image fresh
enough to have an effect? Could I put it more shortly?

## Rules for BeebMod

1. **Say what happens.** "Each unique kill is worth 1 point." Not
   "Every discovery brings you closer to your next rank."
2. **One thing per sentence.** Don't bundle an instruction, a number and a
   goal into one elegant sentence. Split them, or move the numbers into rows.
3. **Numbers go in rows and labels, not in prose.** A row reads
   `Next rank · Tracker at 50`. Don't bold numbers in the middle of a sentence
   to make them pop.
4. **No reward talk.** Avoid "unlock", "earn your way", "make you a",
   "journey", "progress awaits". A rank is a rank: say what it takes.
5. **No figures of speech for mechanics.** Nothing "opens", "awaits" or "comes
   to life" unless a window really opens. "The journal" is the window; don't
   dress it up as "your field journal" in running text.
6. **Say what's missing and the one thing that fills it.** Empty states are
   one or two plain sentences: "No kills yet. Kill an enemy and it goes in the
   journal."
7. **Say limits plainly.** "The game doesn't give addons your live speed, so
   this is the number from your character sheet." No "unfortunately", no
   "we're working on it".
8. **Name clicks exactly.** "Click: open your bags." "Shift-click: stop
   tracking." Never "interact" or "tap".
9. **Use the player's words.** Enemy, pull, tag, rested, reset, vendor. Not
   entity, encounter unit, engagement. Don't invent a noun for a mechanic:
   "the pace" is not a word players use for the XP rate.
10. **Leave out what doesn't matter now.** A row of zeros, a setting nobody
    changed, a total that equals its only part: leave them out.
11. **A word or two beats an explanation.** "Right-click: reset session",
    not "Right-click: start the pace again". In hints, footers, labels and
    grey lines, try the shortest phrase a player would use first. Click
    hints drop "the" and "it": "Click: open journal", not "Click: open the
    journal"; "Shift-click: untrack", not "stop tracking it".

## Tone: like an addon page

`docs/curseforge.md` is the model for how BeebMod sounds (Josh 2026-10-18:
"This is much better!"). It reads like the pages of popular addons such as
Leatrix Plus, Questie, Bartender4 and Bagnon. That is an addon author talking
plainly to a player. It is neither a manual nor a narrator.

- **Lead with the thing.** "Square minimap with coordinates", not "The
  minimap, square, with your coordinates".
- **Fragments are fine** for labels, grey lines, list items, toasts and
  tooltip rows. Keep full sentences for notes, empty states, chat lines and
  answers.
- **Don't hang descriptors off the end with commas.** "Other addons' minimap
  buttons in one row", not "Other addons' minimap buttons, in a line". "Damage
  meter with per-second numbers", not "The game's own meter, flat, with
  figures per second".
- **One fact per sentence.** See ", and" under Dirty glass.
- **Use the words players use.** DPS, HPS, DoTs, FPS, XP, cooldown, in range,
  out of range. Say "next to", not "beside"; "numbers", not "figures";
  "stats", not "readouts"; "restyled", not "flat" or "drawn to match".
  Enemy, unique kill and NPC still hold (rule 9).
- **Leave out how the game works** unless the player needs it to understand a
  limit. "Casts you should interrupt", not "a cast the game says to
  interrupt". "The game's own" only where it tells two things apart.
- **Answer a yes-or-no question with "Yes." or "No." first.**
- **"Please" is fine** when you ask the player to do something, such as report
  a bug. Once.
- Still no pitch, no cheering, no jokes and no role-play.

## Writing to Josh

Replies, reports and summaries follow the same voice.

- Lead with what happened or what was decided, then the detail that supports
  it. No preamble, no restating the question.
- Say what was done and what wasn't, plainly. If something failed or was
  skipped, say so in the sentence where it matters, not at the bottom.
- Short paragraphs, one subject each. Lists only for things that really are
  lists.
- Name files and commands exactly, as they are typed.
- Say what you don't know or couldn't check, once, where it applies.
- End when the content ends. No summing up, no offer of more help unless a
  real decision is waiting.

## Conventions

So every screen reads the same:

- **Names and labels** (a page, a section, a switch, a row, a button, a
  tooltip's name) are sentence case, no full stop: "Dock size", "Fade in
  combat", "Open the journal".
- **Small headings** in capitals (tooltip sections, the journal's rows) are
  written in sentence case in the code; the widget capitalises them.
- **The grey line under a label** says what the setting does, as a short
  sentence in sentence case. One sentence: no full stop. Two sentences: full
  stops on both. "Drag it by anything in it when it's unlocked", not "no drag
  moves it · off, drag it by anything in it".
- **Notes, empty states and chat lines** are full sentences with full stops.
- **The middle dot (·)** separates pieces of data on one line ("Level 35 ·
  Rare elite · Duskwood"). It is not punctuation for prose; don't use it to
  join clauses.
- **Numbers**: digits, with commas from 1,000; "1 point", "2 points"; units
  as the game writes them (ms, %, XP, g s c).
- **Commands** are written as typed: /bt, /reload. Say what they do in
  words first: "Type /bt to open settings."
- **Address the player as "you"**, and the addon as BeebMod (never "we",
  never "the toolkit").
- **Chat lines** start with what they're about: "Expedition: ...",
  "Ledger: ...". A report from a button on the Testing page can be terse,
  but still plain words, not variable names.
- **Debug tools** are buttons and switches on the Testing page, not /bt
  commands. BeebMod has no commands after /bt, which opens the window.
  Everything else is a click.

## Dirty glass

These are the smudges that make a reader notice the writing. Most of them show
up constantly in generated text. Don't use them:

- Two facts joined into one sentence with ", and": "BeebMod changes the
  interface, and you set it all in one window." "It has five features, and
  each has one switch." Write two sentences, or drop the weaker half (Josh
  2026-10-18: "it sounds very AI").
- Asides set off with dashes: "Your gear — all of it — is fine."
- "Not X, but Y": "It's not a list, it's a story."
- A colon that sets up a reveal: "One thing matters: your rank."
- Tidy groups of three: "fast, simple and powerful".
- Words like: seamless, effortless, powerful, robust, elevate, dive in,
  journey, unlock, simply, just, truly, whole new, at a glance, empower.
- Rhetorical questions in UI text: "Want to know your rank?"
- Exclamation marks, except where the game itself would use one (a mastery
  toast can say "Gold mastery!").
- Scare quotes around words we invented.
- Summing up at the end: "In short, ...", "That's it!"
- Worn figures of speech: "under the hood", "the heavy lifting", "a deep
  dive", "moving parts".

## Examples

| Dirty glass | Clear |
|---|---|
| Kill any enemy to open your field journal. Each new kind is worth a point, and **50 points** make you a **Tracker**. | No kills yet. Each unique kill is worth 1 point. *(row)* Next rank · Tracker at 50 |
| As the character sheet last showed it. The game keeps the live figure to itself. | From your character sheet. The game doesn't give addons your live speed. |
| Home is chat and the auction house. World is combat and other players: over 150 ms, casts and hits feel late. | Home latency is chat and the auction house. World latency is combat. Above about 150 ms, casts and swings feel late. |
| Everything you need, right in the dock. | *(say nothing; show it)* |
| Your notes, beautifully organized. | Notes you wrote, newest first. |
| Great news — the rewrite is done, and it's a big improvement! | The rewrite is done. Every page was read, and 2,005 were left out. |
| Right-click: start the pace again | Right-click: reset session |
| The minimap, square, with your coordinates | Square minimap with coordinates |
| Flat bags, quality rings, and bag slots along the bottom | All bags in one window, with bag slots along the bottom |
| A cast the game says to interrupt has a red rim, and your damage over time shows above the plate. | Red rim on casts you should interrupt. Your DoTs above each nameplate. |
| BeebMod changes the game's interface for WoW: Forever, and you set it all in one window. | BeebMod is a UI addon for WoW: Forever. |

## Before you ship a line

- Read it aloud. Would a person say it to a friend at the table?
- Does the reader see the subject, or the sentence?
- Is there one idea per sentence?
- Could you cut a word and lose nothing? Cut it.
- Is there a shorter word that means the same? Use it.
- Does it promise, pitch or cheer? Rewrite it as a fact.

## Code comments

Comments keep their own established style: a short heading in capitals,
Josh's words and the date where a decision came from him, then plain prose on
why the code does what it does. The windowpane rule and the rules above about
plain words and no selling apply there too.
