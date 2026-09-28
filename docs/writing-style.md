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

1. **Say what happens.** "Each new kind of mob you kill is worth 1 point." Not
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
   one or two plain sentences: "No kills yet. Kill a mob and it goes in the
   journal."
7. **Say limits plainly.** "The game doesn't give addons your live speed, so
   this is the number from your character sheet." No "unfortunately", no
   "we're working on it".
8. **Name clicks exactly.** "Click: open your bags." "Shift-click: stop
   tracking." Never "interact" or "tap".
9. **Use the player's words.** Mob, pull, tag, rested, reset, vendor. Not
   entity, encounter unit, engagement.
10. **Leave out what doesn't matter now.** A row of zeros, a setting nobody
    changed, a total that equals its only part: leave them out.

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
  Rare Elite · Duskwood"). It is not punctuation for prose; don't use it to
  join clauses.
- **Numbers**: digits, with commas from 1,000; "1 point", "2 points"; units
  as the game writes them (ms, %, XP, g s c).
- **Commands** are written as typed: /bt demo. Say what they do in words
  first: "Type /bt demo to show made-up data."
- **Address the player as "you"**, and the addon as BeebMod (never "we",
  never "the toolkit").
- **Chat lines** start with what they're about: "Expedition: ...",
  "Ledger: ...". Debug output behind a /bt command can be terse, but still
  plain words, not variable names.

## Dirty glass

These are the smudges that make a reader notice the writing. Most of them show
up constantly in generated text. Don't use them:

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
| Kill any mob to open your field journal. Each new kind is worth a point, and **50 points** make you a **Tracker**. | No kills yet. Each new kind of mob you kill is worth 1 point. *(row)* Next rank · Tracker at 50 |
| As the character sheet last showed it. The game keeps the live figure to itself. | From your character sheet. The game doesn't give addons your live speed. |
| Home is chat and the auction house. World is combat and other players: over 150 ms, casts and hits feel late. | Home latency is chat and the auction house. World latency is combat. Above about 150 ms, casts and swings feel late. |
| Everything you need, right in the dock. | *(say nothing; show it)* |
| Your notes, beautifully organized. | Notes you wrote, newest first. |
| Great news — the rewrite is done, and it's a big improvement! | The rewrite is done. Every page was read, and 2,005 were left out. |

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
