# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here. Measurements and refuted theories live
in the dated evidence records; this is what is left and how to attack it.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns **ND-500 / classic 3022**
(#49, #66, the DOM corpus). Their items are not in this file.

---

## Next

**#56 step 1 is running** — the `5ACTSWAPPER` call-site table, on addresses verified against
`l07-kallsyms.txt`. It decides between the three shapes in A2. Nothing else here should start until
it lands.

---

## THE TARGET

Real ND-500/ND-5000 programs on the emulated CPU, driven by **REAL SINTRAN III on the emulated
ND-100**, with every MON call **FORWARDED over the octobus**. A run our C# `SintranEmulation`
answers **does not count**. Before believing any "it runs" claim: **who answered the MON calls?**
Mechanical guard on a live run: `EmulatedMonPathMarker.Count` must be **0**, and the harness asserts
it. The path table is `RetroCore\Emulated.HW\ND\CPU\ND500\Servicer\MON-PATH-LEDGER.md` — look it up,
do not re-read the servicer.

---

# A. #56 — the octobus swapper is never handed work  (BLOCKS EVERYTHING BELOW)

Every other octobus item is downstream. Do not start B, C or D while A is open.

### A1. What is established, as a causal chain

```
our ND-500 posts NO page-fault trap        (trapsAttempted = 0, measured)
   -> SINTRAN's TRAPDECODER never runs
   -> 5ACTSWAPPER is never called
   -> SWMSG.SWPFU is never set to SWACTIVE  (0 here; 80 on the working lane)
   -> the swapper is never given work
   -> it asks LNEWSWAP forever and parks at PC=0x08008255
   -> place-domain never prints "> Allocating memory" and stalls
```

Every arrow is carved or measured. **The left end is on OUR side of the fence** — the emulator is
not producing the trap; SINTRAN is not refusing to act on one.

### A2. The fork the running table decides

| table shows | meaning | next move |
|---|---|---|
| **some caller fires** | something DOES reach `5ACTSWAPPER`, and it declines or queues | read the outcome pair: `HANDOVER-taken` vs `queued-on-swapwait-fifo`. Queued means the swapper was not at `PSWWAIT` at that instant — a race, not a gate |
| **all four callers zero** | nothing upstream ever asks | the question moves off the swapper entirely, to A3 |
| **INCONSISTENT printed** | the addresses are still wrong | re-pin against kallsyms before reading a single cell. Do NOT quote the table |

### A3. If nothing asks — the real question, and the primary suspect

Then `place-domain` is blocked before any faulting begins and the swapper is idle *correctly*.
Two candidates, in the order to test them:

1. **`BSWSTARTED` is never set.** `TRAPDECODER` bails before it ever reaches `5ACTSWAPPER`:
   ```
   135342   IF 5INITFLAG BIT BRESPLACE OR "N500DF".SYSINITFLAG NBIT BSWSTARTED THEN
   135351      X:=L; CALL 5RRTWT; GO NXTMSG        % restart the ND-100 proc, handle next
   ```
   **The short bring-up deliberately never runs `START-SWAPPER`** (it hangs the monitor — a separate
   known failure). If SINTRAN therefore believes the swapper was never started, EVERY page fault
   takes this bail and none reaches the swapper. Cheapest to test, best fit to the evidence.
   **How:** arm the bail address (`0o135351` + `0o200`) beside the call site. *Reached and bailed*
   and *never reached* are different cells, and the current arming cannot tell them apart.
   **Add it before the next run.**
2. **The monitor is blocked in a MON 60 subfunction that never answers** — in which case nothing
   about the swapper is involved. **How:** capture the last MON 60 subfunction issued before output
   stops; the harness already brackets every monitor command in its crash breadcrumb.

### A4. Fix at the cause, not the symptom

Wherever it lands, the fix belongs at the LEFT end of A1's chain. Resist "make `5ACTSWAPPER` run" —
it and the swapper are behaving correctly at every point measured so far.

### A5. Do NOT redo these

Measured, refuted or done. Evidence: `docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md`.

 - The stall is **not** new (same state recorded 2026-08-27) and **not** bisectable — the history
   does not build; the diff read is the wrong instrument.
 - The swap file is not the variable. Skipping `define-swap-file` gives an identical stall.
 - The harness has not switched to the microword CPU; `AttachNd5000Cpu` still builds a functional
   `CpuND500`.
 - `SWPPING` is ND-100 bookkeeping; our chain walk is right to skip it.
 - `SWPFU=4` (`LALLOPAGE`) is **not** a discriminator — the working lane never asks for it either.
 - MON 377B is not a swapper-activation call, and `SWPST` cannot pick a fork.
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
