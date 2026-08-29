# PLAN

**Next (this session owns the ND-5000 / OCTOBUS lane):** #56 - read the `5ACTSWAPPER` call-site
table from the run now in flight, on addresses VERIFIED against `l07-kallsyms.txt` (listing + 0o200;
the first two runs were armed 128 words low and their tables are withdrawn). The question is which
of the four callers - `MSWSWAIT` tail, `TRAPDECODER` trap 46, `SWPD4` FIFO drain, `SWMC` (MON 510B) -
fires on the classic lane and never here. It is the ND-100 that never hands this swapper work:
`SWACTIVE` appears 80 times on the working lane and zero times on ours. Evidence, and the eight
claims refuted along the way: `docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md` (read section 14 first,
then 15).

**LANE SPLIT, 2026-08-28 (Ronny):** this session is the **ND-5000 / octobus** session — RouteB, the
swap-file question, #56, #59, #68, and the microword oracle (#50/#51). `nd500uc-47` is the
**ND-500 / classic 3022** session — #49, #66, the DOM corpus. We spent a day running each other's
lanes; the two harness filenames differ by four characters in the middle and the shorter is a strict
prefix of the longer, so a filename mix-up maps directly onto a lane mix-up.

**Landed 2026-08-28:**
 - LINKAGE-LOAD-H02 runs to its own `Nll:` prompt under real SINTRAN (classic lane), MON path
   `forwarded=95 realRoundTrips=93 answeredByCsharpEmulation=0`.
 - The octobus swapper LOADS, STARTS, RUNS, ANNOUNCES and is marked free — steps 1-5 of the PROVEN
   protocol. The stall is in the work handoff afterwards, not in the bring-up.
 - The octobus lane finally records WHO answered its monitor calls: `seen=1 taken=1`, forwarded to
   the CPU. `MonPathReport()` had existed for weeks with no caller.
 - **`SWPPING` is ND-100 bookkeeping and our chain walk is RIGHT to skip it.** Three writers, all
   into a process message, none on the ND-500 side; `PSWWAIT` has exactly one writer (`SWPD4`) and
   is therefore a receipt that the swapper announced. The `3SWMESS` generation gate never runs here
   and is not the cause.
 - **#68: the ND-5000 context save now leaves `ctx+0x48..0x58` alone.** Swept all 16384 microwords:
   **0 writes, 5 reads** of those slots through the context base. They are inputs the microcode
   CONSUMES (`CNTXTLOAD` at `0o14777`; `MSG_UNIX5RE` and `MSG_UNIX5REL` read the `0x54`/`0x58`
   pair), not status it reports — which retracts this project's own earlier `TRAP_GEN1` account.
   Writing `0x54` had also been blinding the slot-22 report built to read it.

## Still open on the ND-5000 lane

 - **#68 leftovers, both deliberate.** `ctx+0x6C` and `0x70`: CNTXTSAVE writes them and we write
   nothing — uncarved, and inventing a value is worse than leaving a slot untouched. And the CLASSIC
   store diverges too (skips slot 22 at `010410`, saves THA at `0x58` at `010411`), left unchanged
   because the peer is mid-run on that lane.
 - **#59** — the SHORT octobus bring-up, skipping START-SWAPPER entirely.
 - **#50 / #51** — microword oracle divergences and the sweep diff extension.

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
