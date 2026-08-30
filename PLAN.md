# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns ND-500 / classic 3022.

---

## Next

**1 — make PLACE-DOMAIN complete on the macro round.** It is the single thing standing between us
and a real program running. Everything else on this list is behind it or beside it.

---

## THE GOAL, and how each step gets there

> Run a real ND-500/ND-5000 program on the emulated CPU, driven by **REAL SINTRAN III** on the
> emulated ND-100, with every **MON call FORWARDED** over the octobus. A run our C#
> `SintranEmulation` answers DOES NOT COUNT.

The macro round (`CpuND500` + real SINTRAN over octobus) **is the goal configuration** - real
SINTRAN, real MON forwarding (last measured `restarts=1/1`, Seen == Taken, no gap). It is also the
round that gets furthest. So the goal is reached by fixing the macro round, in this order:

```
  1  place-domain completes        -> a domain can be placed
  2  start-swapper posts its start -> the documented ladder works end to end
  =  RUN a .DOM under real SINTRAN with MON forwarded   <-- THE GOAL
  3  CS load works on the real B30 -> the ORACLE round can then VALIDATE all of it
  4..8  correctness work behind the oracle
```

Steps 1 and 2 reach the goal. Step 3 is what proves we did it right rather than by accident.

---

## 1 — Make PLACE-DOMAIN complete on the macro round

**Measured state:** `place-domain` prints `> Loading Control Store`, then `> Loading Swapper`, then
STALLS. `> Allocating memory` never appears. Reproduced on two packs and at two timeout scales.
The swapper itself is NOT at fault - it is handed one message, serves it, correctly finds no more,
and parks at `PC=0x08008255 stopMode=WAIT` (standoff section 45).

**The premise on this item was WRONG and is now corrected (standoff section 73).** It is not
"ours is 3START, never 3SWMESS". Measured on the live writes-only trace (871,514 entries):

```
  writes to 0x428E3C (the cell LNEWSWAP tests):  314
      0x0000  313        <- LNEWSWAP finds ZERO, takes the ELSE, restarts the ND-500 side
      0x0005  1          <- 3SWMESS IS produced... as the LAST write of the run, after the stall
```

So the question is **why only ONE 3SWMESS message was built in the whole run, and so late** - not
"who zeroes it". Our servicer never writes MICFU at all (verified by reading: the microcode answers
with MICFU UNTOUCHED, which is why DECOMESS dispatches on STOPR).

**Do this:**
 - Read the cell-writer report (`RETROCORE_ND5000_CELLWATCH`, default `0x428E3C`) to name the site
   that writes the single `0x0005`. It is NEITHER known stamper: `0o104024` is never entered, and
   `0o062700` writes a RESIDENT record at `0x438A30`, outside the mailbox.
 - **The report's PC is a NEIGHBOURHOOD, not the storing instruction** - corroborate with L.
 - **Red-first**: the stall reproduces every run, so the failing assertion already exists.

**Do NOT** re-investigate the swapper, `LNEWSWAP`, `5ACTSWAPPER` or the swap-wait FIFO - all measured
correct (sections 43/44/45). Do not read a STALL as "never happened" without checking the timeout
actually fired (section 64).

---

## 2 — Make START-SWAPPER post its start

**Measured state:** during `start-swapper`, 53 messages flow but `startSeen=0`, `startTaken=False`,
`swpfu[(none)]`. **`RUNSW` (FUNCS 054, `163621` in `030-S3SM5.dis`) DOES contain the code**:
`163725 SAA 7` loads `MSWSTART` = 7B and `163726 JPL I 170` calls the sender. So the sending code is
correct and execution never reaches it. Ahead of it sits a run of guarded precondition checks with
early error returns (`163621`-`163716`).

**Do this:** run the PC sampler over `start-swapper`, find which check the PC sits in, then fix that
precondition. Same instrument as step 1.

**Do NOT** conclude from `micfu[]` that `3SWMESS` was never sent - that histogram counts only
SINTRAN -> ND-500 messages and is structurally blind to it (section 68).

---

## 3 — Find out what the ACCP command word `0x0006` ACTUALLY is

**DO NOT implement it as a control-store commit. That was tried on 2026-08-30 and RETRACTED.**

**Measured, both ways, 27 s each** (stash only `Nd5000ControlStoreLink.cs`, run
`LoadControlStoreCommand_DrivesTheAddressedWritePath`):

```
  WITHOUT the 0x0006 case:  PASSES   writes 8 -> 9        one write, correct data
  WITH    the 0x0006 case:  FAILS    writes 20972 -> 20974  two writes, first misaligned
```

Two independent refutations of "0x0006 is a second perform":
 - **Routine B** (`0x73F0`) issues the SAME `0x3010`/`0x0006`/`0x0010` triple but shifts NO DATA. A
   commit opcode would commit garbage there every time.
 - **The command encoding.** The family is `<flags><operation>`: `0x0018`/`0x2018` share operation
   `0x18`; `0x2010`/`0x3010`/`0x0010` share `0x10`. **`0x0006` shares its operation byte with
   nothing** - it is a different operation, not a selector variant of the perform.

The earlier "microwords 8 -> 20,972" is **not progress**: if `0x0006` is not a per-microword commit
those were ~20,964 WRONG writes, which independently explains why the selftest verdict word never
moved to `0x0100`. **A count that goes up is not evidence the data is right.**

**Do this:** carve what the `0x3010` latch SELECTS (write vs read-back), then model the triple as
select-then-perform. Routine B is the control for every step - it is the same triple with the data
removed. Standoff sections 78, 79.

**Tree state:** the change is STASHED, tree at HEAD, that test GREEN.

## 4 — Implement every microword field properly

Throw, log and die on anything missing. Never tolerate. **Progress is measured in fields
IMPLEMENTED, never in halts removed.** Before implementing any entry, RESTRICT its B30 count to
reachable sites - raw sweeps have twice invented work that did not exist (`ABR,NEXT` 20 raw -> 0
reachable; `ORA,ALTEN` 532 raw -> 0). Full work list on the task.

## 5 — Adjudicate the single-float `-0.0` TEST

Measured at four operands: the microword computes S = "sign AND NOT zero" (arithmetically negative);
the functional core returns the raw sign bit. They agree everywhere except `-0.0`. Manual 10.11 says
raw sign bit; the `TEST_BI` precedent adjudicated the microcode OVER 10.11. **Ronny's call**, and it
changes `Test.cs` for both widths.

## 6 — Model TOS/THA on the microword CPU

Not modelled at all. Also settle the `IduHl`/`IduLl` to PCB mapping BY EXECUTION (seed distinct
values at `+0x3C`/`+0x40`/`+0x44`, context-load, read back) - the static decode suggests the names
cross, and `MmsUnit`'s constants may be mislabelled.

## 7 — Adjudicate the remaining engine divergences

Once the register set is complete.

## 8 — Lock the fix with a red-first regression test

Prove it RED before the fix and GREEN after. A test never seen red is not evidence.

---

## NOT THIS LANE / DEFERRED

 - ND-500 classic 3022, the DOM corpus, NLL work — `nd500uc-47`.
 - nd100x/nd500x integration over ndbus — **deferred by Ronny**, gated on RetroCore's own ND-500 and
   ND-5000 CPUs being validated against `nd-500-mon` first. Do not start it, do not design the seam.

---

## HOW TO RUN THE OCTOBUS HARNESS - copy this, do not retype it

**BOTH environment variables are required. Dropping the pack override does not fail loudly - the
test goes INCONCLUSIVE and prints four zero-writes that look exactly like a real measurement.**
Cost of learning that: one wasted run, 2026-08-30.

```bash
cd E:/Dev/Repos/Ronny/RetroCore
export RETROCORE_ND5000_WATCH=swmess     # or runsw, for the START-SWAPPER blocks
export RETROCORE_ND5000_PACK='C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\DOMS-CSFIX.IMG'
dotnet test Emulated.Tests/Emulated.Tests.csproj -nodeReuse:false -p:UseSharedCompilation=false \
  --no-build --filter "FullyQualifiedName~ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture"
```

 - **FILTER TO ONE TEST.** `~Nd100SintranNd5000OctobusBootHarnessTests` matches the WHOLE CLASS and
   spends over an hour on `NllInstaller_RunFiveModules`, `NllFloppy` and `FullFlow` before reaching
   the one you want. One test is ~2-4 min; the class is 33-75 min.
 - **`DOMS-CSFIX.IMG` is the only pack** carrying `SWAP-FILE:DATA`, `CPU-STAT:DOM`,
   `DESCRIPTION-FILE:DESC` AND the 262144-byte ND-5000 `CONTROL-STORE:DATA`. A stock DOMs pack has
   the domains but the CLASSIC 147456-byte store and answers "Wrong microprogram".
 - **Check line ~3 of the log says `----- pack override: ...DOMS-CSFIX.IMG -----` before reading
   anything else.** If it is absent, the run measured nothing.
 - Output is BUFFERED until each test ends, so a log that has not grown for 30 minutes is NOT
   evidence of a hang. Check CPU delta per wall second instead (a live run sits at ~90-95% of a core).
 - Every run restores a virgin pack (`EnsureWorkingCopy` ends in an unconditional `File.Copy`), so
   killing a run cannot corrupt the fixture and no test can inherit another's swap file.

---

## STANDING RULES THAT ORDER THIS FILE

 - **Known bugs before features.** A bug upstream of a feature makes the feature unmeasurable.
 - **Every error line is a bug until root-caused.** No dismissing anything as noise.
 - **Both rounds.** Macro CPU, then microword B30 + real 68k ACCP. A macro-only conclusion is not a
   conclusion. (Step 3 is what makes the second round possible at all.)
 - **/loop re-arm: 2 minutes max while iterating.** Longer only with a named run in flight.
 - Full evidence trail: `docs/OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md` — **read its top index first**;
   it corrects itself repeatedly and six section numbers are duplicated.
