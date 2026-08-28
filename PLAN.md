# PLAN

**Next:** re-run the CLASSIC-lane LINKAGE-LOAD capture and read the `lastDoubleFault` string that
now exists (#44). The octobus lane cannot answer this one — `nd500uc-47` measured it stalling
earlier, inside recover-domain, so it never reaches the program at all.

---

## Why this file has no date in its name

Because every previous plan did, and that guaranteed the failure it was meant to prevent. Three
dated plans accumulated at this root, each superseding part of the last, and the pointer in
`CLAUDE.md` was stale by one — so "what is the plan?" was asked roughly eight times in three weeks.
**A dated filename means every new plan is a new file and every pointer to it eventually lies.**

This file's name never changes. Point at `PLAN.md` and the pointer cannot go stale.

**It holds OUTSTANDING WORK ONLY.** Finished items get deleted, never ticked off in place and never
counted ("34 of 42 done" is banned). The dated plans below are kept as EVIDENCE RECORDS — what was
measured, what was refuted, and why — not as to-do lists.

---

## THE GOAL

Run real ND-500/ND-5000 programs on the emulated CPU, driven by **REAL SINTRAN III on the emulated
ND-100**, with every MON call **FORWARDED over the bus/octobus**.

**A run where our C# `SintranEmulation` answers the MON calls DOES NOT COUNT.** Before believing any
"the program runs" claim, ask **WHO ANSWERED THE MON CALLS?**

That question now has a file, and it lives in RetroCore beside the code it describes and the test
that enforces it:

```
E:\Dev\Repos\Ronny\RetroCore\Emulated.HW\ND\CPU\ND500\Servicer\MON-PATH-LEDGER.md
```

All 22 MICFU paths, keyed on octal + enum name. Look it up rather than re-reading the servicer.
`TestND500_MonPathLedgerIsComplete` fails if a path has no row, if a row names a member that no
longer exists, or if the servicer has a `case` arm the ledger does not declare. The guard on a live
run is separate and mechanical: `EmulatedMonPathMarker.Count` must be **0**, and the harness asserts
it.

---

## Where the detail lives

| what | where | status |
|---|---|---|
| **Day-to-day outstanding items** | **the task list** (`TaskList`) | the authority — it is what shows the counts Ronny reads |
| Run-a-program track, phases 1-5, with all evidence | `PRIORITY-PLAN-2026-08-25-RUN-A-PROGRAM.md` | current; phases 2-5 still open |
| Earlier run-a-program record + correction log | `PRIORITY-PLAN-2026-08-24-REAL-SINTRAN-DOM.md` | evidence record — read before re-opening anything closed there |
| Cross-core alignment track | `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md` | still owns that track |
| How the sessions keep out of each other's way | `OWNERSHIP.md`, and shared-tree hygiene below | — |

The task list and the phase docs are **not** duplicates: the task list is item-level and current;
the phase docs carry the measurements and the refuted theories, which is what stops a closed
question being re-opened wrongly.

---

## The open phases, in order

Detail and evidence for each is in `PRIORITY-PLAN-2026-08-25-RUN-A-PROGRAM.md`.

1. **Close the page-in loop** — the current blocker (its PHASE 1).
2. **CPU-STAT runs to completion**, with the MON-path assertion intact, then turned into a
   regression test that fails if the C# layer ever answers *or* if progress stops short.
3. **Generalise beyond one program** — LED-FORTRAN-A01, then a third. Note: the LED-FORTRAN harness
   is measured NON-DETERMINISTIC (15 vs 100,514 round-trips on identical runs) `[V]`; root-cause
   that before trusting any single run from it.
4. **The microword / octobus lane** — get `X5ACT` delivered (the microcode polled the activation
   cell 5,860,379 times and never found it set `[V]`; fix direction is a deterministic
   `5FPMAILBOX<<10 + X500DF`, not the `0xFFFF`→0 sniff), then run the same program on both lanes and
   diff, using the microword lane as the oracle.
5. **Guardrails** — every item drawn from a wrong conclusion that actually happened.

---

## Standing rules for this work

- **CARVE, DON'T GUESS** — from the source named in `GROUND-TRUTH.md`, or mark it `[OPEN]`.
- **Read the deep dive first.** `docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md`
  (251 KB, 421 `[V]`) before deriving anything about ND-100↔ND-5000 messaging. The trigger is
  "I wonder", not "I am about to derive". Skipping it cost a full day on 2026-08-25.
- Microcode addresses are **OCTAL**; read ORCON/MARG/SARG/SCAL from the RAW `MICRO-5800-B30.DATA`,
  never the rendered `.md` (it mis-renders the overlay).
- **SINTRAN IS ALWAYS OCTAL**, in and out. A wrong-radix question gets a complete, confident, wrong
  answer; the only tell is the `B` on the echo.
- **Shared-tree hygiene** — stage only exact paths, never `git add -A`; check
  `git diff --cached --name-only` before every commit. Two sessions work in one checkout.
- **No new branches without written permission.** Commit on the checked-out branch.
- **Status headings in this tree have lied before** — check the code before investigating anything
  marked open. More than half the time it is already done.
- **A test never seen red is not evidence.** Run it against the broken code and check WHICH LINE
  fails, not merely that it fails.
- **"Would this assertion still pass if the feature were deleted?"** — the one-question test for
  verification theatre.
