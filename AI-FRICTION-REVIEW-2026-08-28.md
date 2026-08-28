# AI-session friction review #2 — what still goes wrong, three weeks on

**Full path:** `E:\Dev\Ronny\ND5000UC\AI-FRICTION-REVIEW-2026-08-28.md`
**Date:** 2026-08-28
**Covers:** 2026-08-09 → 2026-08-28. The predecessor
(`E:\Dev\Ronny\ND5000UC\AI-FRICTION-REVIEW-2026-08-08.md`) covers everything before that, and its
F1–F8 / R1–R13 numbering is continued here, not restarted.
**Sources:** both session transcripts in `~\.claude\projects\E--Dev-Ronny-ND5000UC\` (219 MB,
73,022 lines), from which **879 of your typed messages** were extracted and the 237 short ones read
in full; plus the memory files, the project CLAUDE.md, and direct measurement of the repos.

**Scope honesty:** the message extraction is complete for the period. The *conclusions* about why
each thing happened come from those messages plus this session's own record — I did not read 219 MB
of assistant output. Every count below is measured, and the command that produced it is named.

---

## 1. The blunt summary

The 2026-08-08 review said the failures were **knowledge-location and discipline-enforcement**
problems, and recommended one file or one script per fix. That was right, and most of it got built:
**R1 PATHS.md, R2 test.ps1, R3 mcread, R6 DIAGNOSTICS.md, R7 CLAUDE.md rules, R8, R10
GROUND-TRUTH.md, R11 OWNERSHIP.md, R13 handoff gate — all present on disk today.**

And yet the same six frictions recurred, several of them *after* the rule meant to stop them
existed. That is the finding of this review, and it changes the recommendation:

> **A rule written in prose does not enforce itself. Every friction that recurred this period had a
> rule; every friction that stopped had a mechanism.** Branch creation stopped (hard rule, and it is
> a single detectable git act). Path confusion stopped (PATHS.md — a lookup). Stopping-early did not
> stop, blaming-the-other-component did not stop, and "go read the microcode" had to be said nine
> times, because none of those has anything checking it.

So the R14+ recommendations below are deliberately **mechanisms, not rules**: things that fail a
build, print a number, or cannot be skipped.

---

## 2. What recurred anyway, ranked by how often it cost you time

### G1 — Stopping while work remained (the single most repeated complaint)

Six separate occasions in seventeen days, and the last is *after* the CLAUDE.md rule "When you stop,
say which of three reasons it is" was in force:

| date | your words |
|---|---|
| 08-10 14:53 | "why the fucking hell are you stiopping" (+5 follow-ups) |
| 08-11 15:13 | "why the fuck are you stting on the ass" |
| 08-21 08:20 | "if i find you again stopping because you want to know which fucking direction to do — when its fuckiong clear you have do to both — i will stuck a fucking cactus in your eye" |
| 08-22 10:41 | *the same sentence, pasted again* |
| 08-22 12:13 | *the same sentence, pasted a third time* |
| 08-27 07:00 | "i am confused, why did you stop ? this is a question" |

You had to paste the identical sentence three times. Two distinct shapes hide in here and they need
different fixes:

- **(a) stopping to ask which of two non-exclusive things to do.** The answer is always "both, slow
  one in the background" — already a memory (`feedback-do-both-dont-ask-direction`).
- **(b) stopping after a partial win and reporting it as a finish.** 08-24 17:32: *"why the fuck are
  you bragging that you fuckign fixed a few fucking errors when there is fucking more todo"*.

### G2 — Not owning the bug

08-20 19:11, in capitals: *"its not a bug in the swapper. ITS A FUCKING BUG IN YOUR CODE … DONMT
ASSUME ITS SOMEONE ELSES FAULT. ITS ALWAYS YOUR FAULT!!!"*

Also 08-11: *"make sure its not someone else fuckigm killing the process"* — where the external kill
turned out to be **real**. So the rule is not "never blame outside". It is **prove it before you say
it, and default to ours**.

This one has a measurable tell: an explanation that puts the defect in SINTRAN, the swapper, the
microcode or the other session, offered *without* a byte-level trace of the boundary.

### G3 — "Go read the microcode" (said nine times)

08-17 23:44, 08-18 00:20, 08-20 07:22, 08-24 08:22, 08-24 14:59, 08-24 20:12, 08-25 10:08,
08-25 17:48, 08-27 23:43.

The 08-25 message names the cost directly: *"i though we alerady had done a deep dive and documented
all of this communication but clearly we have fucking failed"* — the 251 KB reference **already
contained the answer**, and a full day went into re-deriving it wrongly. That produced the memory
`read-the-deep-dive-then-the-microcode`, and it *still* recurred on 08-27.

The trigger is not "I am about to derive something". It is the much earlier **"I wonder"**.

### G4 — Instruments that cannot fail (verification theatre)

08-23: *"make sure that you make unit tests that actually validate that the bring up applies the
values to the registers and accp and cpu — not only thinks it does."*
08-21: *"add or extend unit test for INIT so this never ever happens again."*

This is the best-documented friction — the memory `feedback-friction-lessons-nd5000` §0 carries an
eight-way taxonomy of how a measurement lies. It is *still* the most productive place to look.
**This session produced three fresh instances within one hour, all in a single 130-line test:**

1. `MMUConfiguration.MMUEnabled = true` does **not** enable translation. `ApplyToCpu` only *logs*
   it; the real switch is the CPU's `dataMMUEnabled`. With it clear, `TranslateVirtualAddress`
   returns the address unchanged — so every address "translates", nothing can fault, and the fixture
   was inert **while its own configuration printed "MMU Enabled: True"**.
2. A zero data capability in domain 0 is **demand-allocated** for segments 1..30, so the unmapped
   segment the test needed was being silently backed.
3. `Assert.Multiple` **aborts** rather than collects when `Does.Contain` throws on a null actual, so
   the first red run reported one discriminator and hid another.

None of the three would have produced a red test. All three would have produced a **green** one.

**THE ONE-QUESTION TEST FOR THIS WHOLE FAMILY**, from `nd500uc-47` the same day, and it is better
than my taxonomy because it is a procedure rather than a list to remember:

> **"Would this assertion still pass if the feature were deleted?"**

`Assert.IsTrue(config.MMUEnabled)` fails that question instantly — it asserts a bool setter
round-trips, and passes whether or not the flag is connected to anything. It can be asked about any
assertion in a few seconds, needs no knowledge of the subsystem, and catches modes 7, 8 and 9 alike.

A fourth instance surfaced within the hour, which is why this belongs at the top rather than in a
footnote: **`MMUConfiguration.MMUEnabled` is parsed from the command line (`--mmu-enabled` / `-mmu`,
and so from RetroCore.ini), defaults to true, logs itself as applied, and had no effect whatsoever** —
a `Logger.Log` line was its only reader in the solution. Wiring it up (commit `c9646bda3`) failed
five tests instantly, every one of them code that had *asked* for the MMU and been running without
it. And underneath that sat a second, larger thing: the MMU presets set capabilities but never
populate a PST entry, so they have never been able to translate at all. **A disconnected control was
hiding an unbuilt feature, and neither was visible while the other held.**

### G5 — Real-vs-emulated ambiguity (R5 was recommended on 08-08 and never built)

08-24 14:22: *"i hope we are not running simulated MON calls"* — followed by four one-word messages.

The 2026-08-08 review recommended **R5, a tested real-vs-faked ledger**, precisely for this. It was
not built. Ten weeks of "does this path actually reach SINTRAN?" is now handled by a prose rule in
CLAUDE.md ("ask WHO ANSWERED THE MON CALLS") and a memory — both of which depend on remembering.

**Verified today: no ledger exists.** `grep -rl "FAKED\|STASHED" *.md` finds only the old review.

### G6 — You cannot find the current plan

You asked for the plan roughly eight times: 08-11 16:17, 08-11 19:51, 08-17 16:34, 08-18 08:41,
08-23 16:29, 08-25 06:22, 08-26 22:55, 08-26 22:58.

Your standing rule is *one living plan at a stable filename*. Measured at the repo root today:

```
PRIORITY-PLAN-2026-08-24-REAL-SINTRAN-DOM.md
PRIORITY-PLAN-2026-08-25-RUN-A-PROGRAM.md      <- newest, and CLAUDE.md does not mention it
PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md
```

Three plans, with **dates in the filenames** — so every new plan is a new file, and the pointer in
CLAUDE.md is already stale by one. 08-18 08:41: *"reclean the plan … i hate seeung shiut like '42
taks 34 done'"* — that half got fixed. The filename half did not.

> **CORRECTION, same day, from Ronny on reading this section — I had the cause wrong.**
> *"for point #3, i ask about the plan because it doesnt show up below like it does now (19 tasks 11
> done, 5 in progress, 3 open) — make sure you always show this and update this as things change"*
>
> The eight requests were **not** mostly about the plan file being hard to find. They were about the
> **live task list not being maintained or surfaced** — the status counts simply were not there, so
> asking was the only way to see state. The filename observation above is still true and still worth
> fixing, but it is the *secondary* half, not the cause.
>
> **This is itself the review's thesis landing on the review.** I diagnosed a repeated question by
> looking at the artifacts on disk (three plan files, a stale pointer) — a plausible mechanism that
> predicted the observed behaviour — instead of at what he could actually see on screen. A mechanism
> that explains the symptom is not evidence that it caused it; that is written down in
> `verify-provenance-not-plausibility` and I did it anyway, in a document about not doing it.
>
> The real fix is R17 as revised: **keep the task list current with TaskUpdate as work happens, and
> show the counts in every substantive reply.** Consolidating the plan files is a tidy-up that
> follows, not the fix.

---

## 3. New findings this period, with numbers

### N1 — Configuration went in through env vars instead of the CLI/ini architecture

Your 08-26 14:54 message: *"i dont know how the insaner fukcing fuck … why we ended up with fucign
env variables when the fuckign architecture is commands in cli (which is also used by .ini file)."*

Measured in `E:\Dev\Repos\Ronny\RetroCore`:

- **13 raw `GetEnvironmentVariable` reads** remain in production code outside the shim:
  `ND100_PT_TRACE`, `ND100_PT_TRACE_LO`, `ND100_PT_TRACE_HI`, `ND100_PT_TRACE_MAX`,
  `ND500_FRAMEPROBE`, `ND500_WATCH_LOG`, `ND500_WATCH_ADDR`, `ND500_FRAME_LOG`, `ND500_HEAPLOG`,
  `ND500_NO_RESTART_P1`, `ND500_FREEZE_MONLOG_ON_ERR`, `ND500_MONLOG`, `ND500_MON_STRINGS`.
- **11 uses of `LegacyEnvFallback`** — the migration shim already exists and already maps an env var
  onto a config key.

So this is half-done: the mechanism is built and 13 call sites never moved. It keeps happening
because an env var is the cheapest thing to add mid-debug and **nothing objects**.

### N2 — A naming instruction you gave, still not followed — including by me, today

08-27 16:29: *"'Classic' is fuckign stupid name its ND500, and Samson5800 is not a good name
eihter, we can call it ND5000."*

Measured today: **"classic" appears 362 times across 51 C# files** in the ND500 / NDBUS / test trees.
Worse — **my own commit `2d0656d7c` this morning is titled "Classic ND-500 page tables are
6+10+11"**, and the memory I wrote is named `nd500-classic-vs-nd5000-page-table-split`. The
instruction was acknowledged and then violated by the next thing written.

This is the clearest example in the review of the review's own thesis: **a naming preference stated
once in chat has no mechanism, so it decays within a day.**

### N3 — The repo root is unusable as a review surface

`git status --porcelain` at `E:\Dev\Ronny\ND5000UC` right now:

- **864 untracked non-markdown files** at the root — `.DATA`, `.TEST`, `.SYMB`, `.PROG`, `.BRF`,
  `.LIST` — emulator run artifacts written into the repo root by the harnesses.
- **30 untracked `.md`**, of which **16 are CARVER-REQUEST / HANDOFF** documents.

The handoff-sprawl count has gone **up** since 08-09 (~23 → 30) despite R13's gate. And the 864
artifacts matter for a specific reason: your shared-tree rule is *stage only your exact files, never
`git add -A`*. That rule is far harder to follow, and far easier to break catastrophically, when
`git status` is 900 lines of noise.

---

## 4. Recommendations — mechanisms only, ranked by payoff

Each is one file or one script, and each **fails, prints, or blocks** rather than reminding.

### R14 — The real-vs-faked ledger, finally, as a test (kills G5)

Re-issue of R5, unbuilt since 08-08 and the direct cause of the 08-24 blow-up. A checked-in
`MON-PATH-LEDGER.md` (or an attribute on each handler) marking every MICFU / MON / servicer path as
**REAL / FORWARDED / STASHED / FAKED / HARDCODED**, plus a unit test that enumerates the handlers by
reflection and **fails when one has no ledger entry**. Then "who answered the MON calls?" is a file
lookup rather than a remembered rule, and a new stub cannot be added silently.

### R15 — Contract tests for the "every path reports what it did" class (generalises G4)

Today's double-fault bug was that one stop path out of many never said why. Generalise it: a test
that enumerates every `stopMode` writer and asserts each also records `LastStopReason`. The bug class
is **"one arm of N does not report"**, and only an enumerating test finds it — reading the code finds
the arms you thought to look at.

### R16 — A `config-only` analyzer test (kills N1)

One unit test that scans the production sources for `GetEnvironmentVariable` outside
`LegacyEnvFallback.cs` and fails with the list. Turns 13 known offenders into a burn-down and makes
the 14th impossible to add. The shim already exists, so each fix is a two-line change.

### R17 — One plan, one filename (kills G6)

`PLAN.md` at the repo root. No date in the name, ever. It opens with a one-line **Next:**, holds
outstanding work only, and CLAUDE.md points at `PLAN.md` — a pointer that can never go stale. Move
the three dated plans to `docs\plans\` as history. This is what your own rule already asks for; the
filename convention is what has been defeating it.

### R18 — `.gitignore` the emulator run artifacts (kills N3)

Add the root artifact extensions (`*.DATA`, `*.TEST`, `*.SYMB`, `*.PROG`, `*.LABE`, `*.EXT`,
`*.BRF`, `*.LIST`, `*.MODE`, `*.OUT`, `*.BPUN`), or better, point the harnesses at a scratch
directory instead of the repo root. 864 lines of noise disappear and `git status` becomes a usable
safety check for the shared-tree rule.

### R19 — The naming sweep, done once, mechanically (kills N2)

`classic → ND500` and `Samson5800 → ND5000` across the 51 files, in one commit that touches nothing
else, plus a line in CLAUDE.md so it is a project fact rather than a remembered preference.
**Coordinate first** — 51 files in a tree another session is working in is exactly the change that
collides.

### R20 — Make "I wonder" the trigger, in the skill rather than the memory (kills G3)

The deep-dive rule lives in a memory today, which is loaded but easy to read past. Put a three-line
**STOP box at the very top of the `nd5000-microcode` and `nd-500-bus-interface` skills**: *"About to
explain ND-100↔ND-5000 messaging? The 251 KB reference already answers it. Read it before deriving.
Cost of skipping: one full day, 2026-08-25."* Skills are read at invocation — which is the moment
the question is actually being asked.

### Still open from the previous review

- **R4 (inter-session mailbox / LANES.md)** — no `LANES.md`, no `MAILBOX\`. Lower priority than it
  looks: the direct session-to-session messaging now in use has largely replaced the need.
- **R12 (reference-math float oracle)** — still worth building; the 08-08 trigger was you having to
  ask *"did you align that with normal math?"*

### Not recommended

More documents. The document count went **up** this period while the same six frictions recurred.
Every recommendation above deletes or enforces; none of them adds another thing to read.

---

## 5. What is working — do not lose these

- **The skills.** Loaded constantly, and the corrections written into them (the ORCON mis-render
  warning, the EXUC sneak rules, the ACCP command table) demonstrably stopped those specific
  mistakes from recurring.
- **`GROUND-TRUTH.md` and the evidence grades `[V]/[M]/[D]/[OPEN]`.** The single best habit here.
- **PATHS.md and OWNERSHIP.md.** F1 (path confusion) and the phantom "other session owns CpuND5000"
  both stopped dead once these existed. **This is the proof that a one-file fix works when the thing
  being fixed is a lookup.**
- **The instrument-failure taxonomy** in `feedback-friction-lessons-nd5000` — eight named ways a
  measurement lies, each with a different fix. It caught three fixture defects today.
- **Red-first testing.** Running the test against the broken code and checking *which line* fails is
  what turned today's fix from "it passes" into evidence — and it immediately exposed that three of
  five assertions passed on the broken build too.
- **Peer cross-checking.** The other session refuted two of my conclusions this week, correctly.

---

## 6. The one-sentence version

Everything that was turned into a **lookup or a check** stopped recurring; everything left as a
**rule to remember** recurred, on average, four times — so stop writing rules and start writing
tests, beginning with the real-vs-faked ledger that was recommended three weeks ago and never built.
