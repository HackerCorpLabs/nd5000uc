# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here. Measurements and refuted theories live
in the dated evidence records; this is what is left and how to attack it.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns **ND-500 / classic 3022**
(#49, #66, the DOM corpus). Their items are not in this file.

---

## Next

**A3 — why does the ND-500 never raise a page fault on this lane?** That is the blocker, and it is
on our side of the fence. First job is #77: make the round-2 harness (microword B30 + real 68k ACCP)
runnable, because the standing rule below says no conclusion is reported from the macro round alone.

---

## STANDING RULE — EVERY ROUND RUNS TWICE  (Ronny, 2026-08-29)

> *"you always run one round with macro CPU and then another with microcode and accp with 68k cpu
> to find out what the real hw would do and then try to replicate that in macrocode. dont assume
> shit, go measure, use logging and analytics"*

 - **Round 1, macro:** functional `CpuND500` (`AttachNd5000Cpu`). The target — what has to end up
   correct.
 - **Round 2, real hardware:** microword `CpuND5000` on the real `MICRO-5800-B30`
   (`AttachNd5000CpuOfKind(Nd5000CpuKind.Microword, …)`) **together with the real 68000 ACCP
   firmware** (`AttachAccpFirmware`, `octo.bin`).

**Round 2 is the ORACLE.** Diff the rounds; the difference IS the bug list. Then replicate the
hardware's behaviour in macrocode. **Never report a macro-only conclusion.** Same test, one switch —
two tests that drifted apart do not make a measurement.

**Verified 2026-08-29:** the octobus boot harness calls `AttachNd5000Cpu` and never calls
`AttachAccpFirmware`, so neither real component has ever been in this lane. Both seams are wired and
unused.

**The one exception, and it is not permission to skip round 2:** the ND-5000 **MMU walk is done by
HARDWARE** — microwords only SELECT it — so a page-fault question is settled by neither round on its
own; the MMS model is ours on both paths. Read round 2 with `ND-05.020.01` beside it. The classic
ND-500 is the opposite: its microcode DOES walk.

---

## THE TARGET

Real ND-500/ND-5000 programs on the emulated CPU, driven by **REAL SINTRAN III on the emulated
ND-100**, with every MON call **FORWARDED over the octobus**. A run our C# `SintranEmulation`
answers **does not count**. Before believing any "it runs" claim: **who answered the MON calls?**
Mechanical guard on a live run: `EmulatedMonPathMarker.Count` must be **0**, and the harness asserts
it. The path table is `RetroCore\Emulated.HW\ND\CPU\ND500\Servicer\MON-PATH-LEDGER.md` — look it up,
do not re-read the servicer.

---

# A. #56 — no page fault is ever raised on the octobus lane  (BLOCKS EVERYTHING BELOW)

Every other octobus item is downstream. Do not start B, C or D while A is open.

### A1. MEASURED 2026-08-29 — macro round, table self-consistent

```
INVARIANT callers=1 entry=1 outcomes=1 (bailed=0)  [consistent]

  call:MSWSWAIT-tail           @0o134354  hits=0
  bail:NOT-BSWSTARTED          @0o135551  hits=0
  call:TRAPDECODER-pagefault   @0o135567  hits=0
  call:SWPD4-fifo-drain        @0o136237  hits=1     <- the only caller
  call:SWMC-mon510             @0o142165  hits=0
  5ACTSWAPPER-entry            @0o145162  hits=1
  HANDOVER-taken-SWACTIVE      @0o145211  hits=1     <- it DID hand over, once
  queued-on-swapwait-fifo      @0o145312  hits=0
```

All hits `PIL=12`, link registers chain correctly, addresses verified against `l07-kallsyms.txt`.

**This corrects the chain this section used to state.** It is NOT "the swapper is never handed
work". `5ACTSWAPPER` runs, the swapper is seen free, and `SWACTIVE` IS written — once, via the
`SWPD4` FIFO drain. What never happens is the route that keeps feeding it:

```
our ND-500 raises NO page fault      (trapsAttempted = 0; TRAPDECODER call site AND its bail both 0)
   -> TRAPDECODER's trap-46 arm is never REACHED
   -> the only handovers are the one-off FIFO drain
   -> the swapper asks LNEWSWAP and parks at PC=0x08008255
   -> place-domain never prints "> Allocating memory"
```

The working classic lane hands over ~80 times. **The left end is ours: the emulator is not raising
the fault. SINTRAN is not refusing to act on one.**

### A2. Refuted by that table

 - **`BSWSTARTED` is NOT the blocker** (`bailed=0`). It was the primary suspect and the best fit to
   the evidence available; it is wrong. There was nothing to bail on, because the arm is never
   reached.
 - **`5ACTSWAPPER` is not broken**, and neither is the swapper. Both behave correctly at every
   measured point.

### A3. THE QUESTION — why is no page fault raised?

Why does our ND-500 never fault here when the classic lane faults constantly?

 - **Run BOTH rounds** (standing rule above). Note the exception: the ND-5000 MMU walk is HARDWARE,
   so round 2 does not answer this on its own — the MMS model is ours on both paths. Read round 2
   with `ND-05.020.01` beside it.
 - **Measure, do not reason.** Instrument the MMS translate path and count translations, hits,
   misses and faults RAISED. **A fault never raised and a fault raised-then-swallowed look identical
   from outside**, so a single counter cannot separate them — give it the pair.
 - Compare the same counters against the classic lane, which faults. A difference in translation
   COUNT is a different bug from a difference in fault-raise RATE.

### A4. Fix at the cause, not the symptom

The fix belongs at the left end of A1's chain. Resist "make `5ACTSWAPPER` run" — it already does.

### A5. Do NOT redo these

Measured, refuted or done. Evidence: `docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md`.

 - The stall is **not** new (same state recorded 2026-08-27) and **not** bisectable — the history
   does not build; the diff read is the wrong instrument.
 - "It is a regression" is **NOT established.** The last run that reached `> Allocating memory` was
   2026-08-01 from an UNCOMMITTED working tree, and the harness has changed since — so a code
   regression is not separated from a harness change. I claimed it this morning and had to narrow it.
 - The swap file is not the variable. Skipping `define-swap-file` gives an identical stall.
 - `SWPPING` is ND-100 bookkeeping; our chain walk is right to skip it.
 - `SWPFU=4` (`LALLOPAGE`) is **not** a discriminator — the working lane never asks for it either.
 - MON 377B is not a swapper-activation call, and `SWPST` cannot pick a fork.
 - `BSWSTARTED` — refuted above.
 - Do not carve more microcode for this, and do not re-measure the stall.

---

# B. #50 / #51 — the microword oracle  (independent of A; work it while A waits on a run)

The microword `CpuND5000` runs the real B30 store and is the only thing that can adjudicate the
functional `CpuND500`. Until its divergences are closed it cannot serve as an oracle — which is
exactly what A's eventual fix will need for validation.

 - **#51 FIRST** — extend the sweep diff to `B`/`R`/`L`/`TOS`/`HL`/`LL`/`THA`. It compares too few
   registers today, so #50's count is a lower bound wearing the clothes of a total. Widening the
   diff is what makes #50 trustworthy.
 - **#50** — then the 246 divergences + 31 trap-bit misses, re-counted on the widened diff.

**Method:** per-divergence adjudication, never auto-trusting either engine. Surface both states plus
the microcode or manual citation. Neither CPU is the reference; the B30 store is.

---

# C. #68 leftovers — two context slots, uncarved

`ctx+0x6C` and `ctx+0x70`: `CNTXTSAVE` writes them and we write nothing. **Uncarved — inventing a
value is worse than leaving a slot untouched.** Carve from the RAW `MICRO-5800-B30.DATA` word, or
leave it `[OPEN]`. The classic-store divergence at `010410`/`010411` is the peer's lane, not ours.

---

# D. Deferred, and honestly deferred

 - **#53** — the nd100x C ↔ ND-500 core seam. Gated on A being green; earlier means defining a seam
   against a lane that does not run.
 - **#54** — single-float `-0.0` `TEST` `S=1`. One instruction, no dependants. The DOUBLE half is
   closed; this is the single-precision tie-break and needs a trace before anything is touched.

---

## Where the evidence lives

| what | where |
|---|---|
| Item-level status + the counts Ronny reads | the task list (`TaskList`) |
| #56, all of it, with every refuted claim | `docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md` — §14 first, then §15 |
| Run-a-program track | `PRIORITY-PLAN-2026-08-25-RUN-A-PROGRAM.md` |
| Cross-core alignment track | `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md` |
| Every existing trace switch | `DIAGNOSTICS.md` — check before building an instrument |
| Who owns which lane | `OWNERSHIP.md` |

---

## Rules that have actually cost time here

- **CARVE, DON'T GUESS** — from `GROUND-TRUTH.md`, or mark it `[OPEN]`.
- **Read `docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md` first** for anything about
  ND-100↔ND-5000 messaging. The trigger is "I wonder", not "I am about to derive".
- **An NPL listing address is not a linked address.** This module is **listing + `0o200`**, verified
  against `l07-kallsyms.txt`. The offset is PER MODULE; convert via the `*NNxnn=*` patch markers,
  which exist in both the listing and the symbol table. **Pin symbols that BRACKET the routine**, not
  ones merely near it.
- **A better instrument on an unverified input is more dangerous than a noisy one** — it strips the
  noise that was the only sign anything was wrong. Verify the input before polishing the instrument.
- **Ask what a NULL result would tell you before asking for the measurement**, and check the
  discriminator against the MECHANISM: if you cannot say what the test would SEE were the hypothesis
  true, it cannot support a negative.
- **Before quoting a ratio, ask what the denominator does on its own.** A 20-of-20 against a
  95%-constant field is not a finding.
- Microcode addresses are **OCTAL**; read ORCON/MARG/SARG/SCAL from the RAW `MICRO-5800-B30.DATA`.
- **SINTRAN IS ALWAYS OCTAL**, in and out. The only tell is the `B` on the echo.
- **Shared-tree hygiene** — stage exact paths, never `git add -A`; check
  `git diff --cached --name-only` before every commit. Two sessions, one checkout.
- **No new branches without written permission.**
- **Status headings in this tree have lied.** Check the code before investigating anything marked
  open; more than half the time it is already done.
- **A test never seen red is not evidence.** Run it against broken code and check WHICH LINE fails.
- **"Would this assertion still pass if the feature were deleted?"**
