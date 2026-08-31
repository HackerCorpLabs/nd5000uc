# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns ND-500 / classic 3022.

---

## Next

**1 - make PLACE-DOMAIN complete on the macro round.** It is the single thing standing between us
and a real program running. Everything else on this list is behind it or beside it.

**On the hw-accp round: the mailbox mismatch is SETTLED - use `0x0042890A`.** Standoff section 109.
`X5ACT_carved` is exactly `5FPMAILBOX(2129) x 2048 + 0x10A`, and it falls inside the same window
where the macro round measures 627 real MICFU writes. The "discovered" `0x007FFEF6` is 266 bytes
below **8 MB exactly** - and 266 is `0x10A`, the SAME offset, so the discovery computes the right
offset against the wrong base and hangs the mailbox off the top of memory. Re-read every hw-accp
measurement taken through the discovered address before quoting it; `ext-block X5ACT=0001` in
particular was read off the wrong object. Fix is the deterministic `5FPMAILBOX` address, not the
`0xFFFF -> 0` sniff - already recorded in `MEMORY.md` under `nd5000-timeout-convergence`.

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

## 1 - Make PLACE-DOMAIN complete on the macro round

**Measured state:** `place-domain` prints `> Loading Control Store`, then `> Loading Swapper`, then
STALLS. `> Allocating memory` never appears. The swapper itself is NOT at fault (section 45).

**THE FRAMING HAS BEEN WRONG TWICE. Standoff sections 105 and 114 have the corrections.** What the
CPU actually serviced in the entire run:

```
  262  MICFU=0x01  3RMICV   watchdog heartbeat - "time passed, nothing more"
   13  MICFU=0x19  PHYSWR   physical-write, 4 bytes each
    1  MICFU=0x0A  CACHE    cache-clear
    0  MICFU=0x05  3SWMESS  <- and that is CORRECT
```

**CORRECTED AGAIN - section 122. That census was a SAMPLE, not the census.** The authoritative
`micfu[]` histogram shows FIVE micro-functions, including the two I reported absent:

```
  [after PLACE-DOMAIN]  micfu[1B:162  12B:1  23B:1  24B:1  31B:13]
  startSeen=1 startMicfu=23B startTaken=True   restarts=1/1   swpfu[LNEWSWAP:2]
  ansMON=377B   PC=0x08008255 stopMode=WAIT    THA=0x00000000
```

The swapper **starts, runs, calls MON 377B, is answered and parks** - the designed idle. Place-domain
gets much further than the sample suggested.

**SENTINEL REMOVED - section 124, red-first, 2264 green.** `Registers.DitConfigured` replaces the
`DITBASE == 0` test in all 22 guards; `DeclareDitBase(uint)` declares a base WITHOUT clearing (for a
guest-owned table) while `SetupDIT` keeps clearing (for an emulator-owned one);
`MMUConfiguration.ApplyToCpu` now marks configured. Both new tests were RED first - and the second
one PROVED that `SetupDIT(0)` erases a guest-written table, which would have produced an unchanged
`THA=0` and read as "the fix did nothing" a third time.

**STILL TO DO: nothing on the octobus lane calls `DeclareDitBase` yet.** Deliberately no blanket
default - base 0 is SINTRAN's layout, not universal (NDIX puts `pcbtab` at KVA `0xe0000000`), and
baking one OS's map into a shared path is the same class of error as the sentinel. **place-domain
will not change until the lane declares the base; do not re-measure expecting movement.**

**ROOT CAUSE - section 123. `DITBASE == 0` is the "not configured" sentinel, and 0 is the
CORRECT base for this system.** SINTRAN writes the DIT at ND-500 physical `0x96..0xC7` = PCB base
`0x00`, domain 0; the harness uses `PcbTableBase = 0x00` too. But every DIT reader opens with
`if (regs.DITBASE == 0) return 0;` - **22 such guards** - and nothing on the octobus lane ever sets
`DITBASE` (it appears only as a register accessor on the classic 3022 path). So a correctly
configured DIT at physical 0 is indistinguishable from no DIT, and every read is refused.

One cause, five symptoms: `THA=0`, trap enables never loaded, and BOTH the section-121 and
section-122 fixes measuring no change - they were correct and inert, downstream of a subsystem that
was switched off.

**THE FIX IS NOT A ONE-LINER, AND THE OBVIOUS VERSION DESTROYS THE DATA - section 123b.**
`SetupDIT(0)` looks like the way to declare the base; its second half **zeroes every 256-byte PCB**.
On this lane SINTRAN owns that table, so calling it would erase the trap config place-domain just
wrote - and the symptom would be identical to today (`THA=0`), for a different reason.

Three parts:

```
  1  replace the sentinel   21 functional guards test a DitConfigured flag (or nullable base)
                            instead of `regs.DITBASE == 0`. The 22nd (:1008) only picks a log
                            message - leave it.
  2  declare WITHOUT clearing   a separate entry point, or a SetupDIT overload that skips the
                            zeroing. Never zero a table the guest wrote.
  3  octobus attach calls it with base 0 - what SINTRAN uses and what
                            SwapperStartDiagnosticTests already assumes (PcbTableBase = 0x00).
```

**Red-first test:** write a recognisable value into a DIT field at physical 0, declare the base, read
it back. False today for TWO independent reasons - the sentinel refuses the read, and the only
declaration path would have erased the value first. Pin both.

**THE OLD FRAMING, kept because the chain is still the evidence:**

**THE GAP IS `THA=0`.** SINTRAN writes `pcb_tha` during place-domain; the process is started; the
microcode CNTXTLOAD reads DIT fields at start; our `StartProcessFromContextBlock` does not - it reads
ctx `0x00-0x60`, which has no trap-enable slot. So the CPU runs the process with no trap handler and
no enables. **Next change: load the DIT trap config in the PROCESS-START path** (section 121 hooked
it to cross-domain CALL, which is why it was inert). Falsifiable in one line: `THA` should be
non-zero after a completed 3START. Check WHICH fields first - CNTXTLOAD reads four bytes, the
LOADCT_* instruction reads twelve.

**Stop chasing 3SWMESS.** `Nd5800MicfuDispatchTableTests` proves `0o5` routes to `MSG_ILLEG` on the
B30 - the CPU does not implement it. The twelve SWPINFO stamps are the ND-100 driver's own routing
marker and can never become a CPU message.

**Where it really stops:** one cache-clear, then twelve words scattered into ND-500 LOW PHYSICAL
memory, all sourced from the same ND-100 staging cell `0x0000CC00`, then only watchdogs:

```
   0xBC 0xC0 0xC4     three words          bytes 0xBC..0xC7
   0xB6               one word             bytes 0xB6..0xB9   (0xBA..0xBB never written)
   0x96 0x9A 0x9E 0xA2 0xA6 0xAA 0xAE 0xB2  EIGHT CONTIGUOUS  bytes 0x96..0xB5
   0xA6 again         the 5th word rewritten
```

**ANSWERED 2026-08-31 - standoff section 115.** Those twelve words are the **Domain Information
Table (PCB) trap-enable block for domain 0**. Every write lands on a field START:

```
  0x96 ote1   0x9A ote2   0x9E cte1   0xA2 cte2   0xA6 mte1   0xAA mte2
  0xAE temm1  0xB2 temm2  0xB6 tha    0xBC tos    0xC0 ll     0xC4 hl
  (0xBA md, 0xBB ith are the only single-BYTE fields in the span - hence the never-written gap)
  (0xC8 pia is the first byte past the block)
```

So **`place-domain` is installing the trap configuration for the domain it is about to run** -
trap enables, the trap-handler vector, the stack pointer and the memory limits. This was open in
the deep dive since July as "the live blocker".

**FIXED, AND IT CHANGED NOTHING - section 121.** `LoadDomainStateFromDIT` now loads
OTE/CTE/MTE/TEMM as well as TOS/LL/HL/THA. Re-ran place-domain: MICFU census, MON restart counts and
every cell-write bucket are IDENTICAL; only watchdog counts moved with elapsed time. The method is
called only from cross-domain call/return, and place-domain never reaches a domain call - so the fix
is correct and currently INERT. **The "place-domain is quiet because the trap config is ignored"
hypothesis is REFUTED.**

Provenance regraded `[D]`: `LOADCT_*` is reached from `0o001041`, the MACRO-INSTRUCTION dispatch
band, so it is a load-context INSTRUCTION and does not prove a cross-domain CALL loads these. The
layout it gives still stands. The experiment to settle the trigger is named in the code comment.

**ANSWERED - section 116. The engine loaded THA but NOT OTE/MTE; the microcode loads both.**

```
  LoadDomainStateFromDIT:   TOS, LL, HL, THA   <- and nothing else
  regs.OTE1/2, regs.MTE1/2: never loaded from the DIT anywhere in the codebase
  microcode CNTXTLOAD 015103/015104: TE := SC4, accumulated at 015075 from DIT byte reads
```

The local-trap-enable gate reads the REGISTERS - correctly, per microcode `011034` - so the gate is
right and nothing fills what it reads.

**RAW DECODE DONE - section 117, and it CORRECTED section 116.** The block reads DIT bytes at DPA
`+0x16 (ote1, address setup only)`, `+0x3B (ith)`, `+0x26 (mte1)`, `+0x48 (pia)` - a third,
genuinely independent confirmation of the layout. But the bytes feeding SC4 are `ith` and `pia`,
single BYTES, **not** the 64-bit OTE/MTE pair, so "TE is loaded from the DIT trap-enable fields" is
NOT established. `TE,ALU,LOAD` is a control strobe and is not the `D,MIC,TE` destination.

**THE ASYMMETRY IS PROBABLY NOT A BUG - section 119.** ND-05.022.1 Table 1 says `THA`, `CTE` and
`TEMM` reside **only in the Domain Information Table**, while `OTE` and `MTE` have REGISTER homes in
gate arrays. So loading THA from the DIT is exactly right, and not loading OTE/MTE from it is
defensible. Second reason not to have patched it.

**A REAL DEFECT THE MANUAL DOES NAME `[M]`:** the same manual says the hardware trap enable is
**`MTE` ALONE when inside a trap handler**, and `MTE | OTE` only outside. Our gate ORs them
unconditionally:

```csharp
    ulong localTrapEnable = ((ulong)regs.OTE2 << 32) | regs.OTE1;
    localTrapEnable |= ((ulong)regs.MTE2 << 32) | regs.MTE1;   // <- no InsideTrapHandler test
```

`pcb.InsideTrapHandler` is right there - the dispatch condition below already uses it. Effect: inside
a handler we would deliver a trap only OTE enables, where hardware withholds it. **Confirm against
microcode `011034` before changing it** - manual loses to microcode in this project.

**NEXT STEP IS TO EXECUTE, NOT DECODE - section 118.** Static decoding has produced one over-claim
and one correction on this question already; the SSKIP precedent says stop decoding at that point.
All the pieces exist: `SwapperStartDiagnosticTests` drives IDLE -> MSG_START -> NEWCNTXT -> EXECUTE
on the microword CPU with a seeded DIT, `MmsUnit.SetDomainPia` shows how to seed a DIT field, and
the CPU models TE in both namespaces (`regs.MicTe`, `regs.IduTe`). Seed distinctive
`OTE1/OTE2/MTE1/MTE2`, run the context load, read TE.

**Byproduct already fixed:** `MmsUnit.PcbChildTrapEnableOffset` was `0xA6`, which is `pcb_mte1`
(MOTHER). Correct address, wrong name - it would have survived any check of the number. Nothing
consumed it, so nothing was miscomputed. Corrected to `0x9E` and the full trap-enable/limit map
added from the verified layout.

It would explain BOTH section 112a's undeliverable ignorable trap AND place-domain going quiet right
after installing a trap configuration the engine then ignores.

**Correction to this file:** it called that block a "write-then-read-back VERIFY". That is right for
`octobus-fullflow` (13 PHYSWR + 12 PHYSRD, 2026-07-28) but NOT for this run - the short bringup is
`NoStartSwapper`, so the verify half legitimately never runs. Do not read the missing PHYSRD as a
regression.

**Still unretired, from the 2026-07-28 file:** whether `addrA` should resolve to ND-500 LOCAL memory
rather than through `Nd500AddressBase` into the MPM window. A self-consistent round-trip hides the
difference, so a passing verify does NOT prove the target is right.

**Do NOT** re-investigate the swapper, `LNEWSWAP`, `5ACTSWAPPER` or the swap-wait FIFO - all
measured correct (sections 43/44/45). Do not read a STALL as "never happened" without checking the
timeout fired (section 64).

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

## 3 — DONE. `0x0006` is ACON WCS, and the control-store model was INVERTED

**Answered 2026-08-31 with Ghidra on octo.bin. Standoff sections 103 and 104.**

`0x00220000` is the **ACON decoder** (ND-05.020.01 p.113, table 9). `0x0006` is command `6h`,
**WCS - "write control store"**. All 23 distinct literals the firmware writes to that port decode
as ACON commands with the encoding's unused bits 11..5 zero in every one.

The bigger finding is that the two routines were the wrong way round:

```
  0x73B2  WRITE  24 callers  address phase + shift 8 words OUT (0x7776) + WCS.  NO GATE.
  0x741E  READ   17 callers  address phase + gate + AMIRCK (0x0018) + shift 8 words IN
  0x73EE  DEAD    0 callers  WCS with no shift - this was section 78's "control", and it never runs
```

`Nd5000ControlStoreLink` committed on `0x0018`, so **every read of the control store also wrote
it**, and the address was latched on `0x3010` (issued twice per write) instead of on ARMA `0x0015`
(issued once). Fixed, red-first:

```
  before:  COMMIT cmd=0x0006 ... + COMMIT cmd=0x0018 ...   writes 20972 -> 20974   FAIL
  after:   COMMIT cmd=0x0006 ... + CS-READ addr=0x0100     writes 20964 -> 20965   PASS
```

Held by `Nd5000ControlStoreWritePathTests` (replays ROM `0x73B2` and `0x741E` instruction for
instruction) and `AconDecoderTableTests` (sweeps the shipped ROM against table 9).

**What is left of this item:** re-measure the real CS load end to end. `gateOpens` moved 13 -> 1502
on the same command, so the card's behaviour changed substantially and that has not been
characterised yet.

## 4 - Implement every microword field properly

Throw, log and die on anything missing. Never tolerate. **Progress is measured in fields
IMPLEMENTED, never in halts removed.**

**THE WORK LIST, enumerated 2026-08-31** (it used to live only on the task, which is exactly what
this file is for). 25 throw sites in `CPU.ND5000/src`, and they are NOT 25 gaps - they split:

**Real field gaps - each is parameterised by mnemonic, so one site covers many field values:**

```
  CpuND5000.cs:1146   Memory operation {mnemonic}
  CpuND5000.cs:1260   IDU fetch control {getMnemonic}          (P5)
  CpuND5000.cs:1732   Conditional fetch with ABR value {Abr}
  CpuND5000.cs:3473   Status operation {mnemonic}
  CpuND5000.cs:3752   Address B operand {mnemonic}
  CpuND5000.cs:3864   Post-index scale for data type {dataType}
  CpuND5000.cs:3885   Data type {dataType} memory access
  CpuND5000.cs:4193   Operand specifier 0x{b0}                  (P5 slice)
  CpuND5000.cs:4383   ORCON.A value {orconA} (ALTEN/none)
  CpuND5000.cs:4447   ORCON.D value {orconD} (ALTEN)
  Conditions.cs:264   Test condition {mnemonic}
```

**Correct guards - NOT gaps, do not "fix" these by removing the throw:**

```
  1806 CALL argument not a memory operand      1957 opcode has no dispatch entry
  1863 CALL to segment 31 (the MON trampoline) 2032 ENTER/RETURN frame-op guard
  2376 did not retire within N microwords      3798 SCAL value undefined
  3859 post-indexed TYP,BI (deliberate, documented)
  4427 ORD,OP with a constant operand          4445 ORD,OP1 with no stored first operand
  4454 memory op with no memory attached
  2495 / 4352 / 4399 / OperandRouter:100  "no register-in-instruction metadata"
```

**BEFORE IMPLEMENTING ANY ENTRY, RESTRICT ITS B30 COUNT TO REACHABLE SITES.** Raw sweeps have twice
invented work that did not exist: `ABR,NEXT` 20 raw -> 0 reachable; `ORA,ALTEN` 532 raw -> 0. Note
two of the eleven above are the ALTEN pair, which is exactly the case that swept to zero - so start
by re-checking whether they are reachable at all before writing anything.

## 5 — DONE. Single-float `-0.0` TEST follows the microcode

Ronny adjudicated the microcode over manual 10.11, scoped to SINGLE only. `Test.cs` now computes
S = "sign bit AND the SRF4-masked value is non-zero", so `-0.0` tests as non-negative. The DOUBLE
branch deliberately keeps the raw sign bit - its flags come from a C#-side recompute, so applying
the rule there would create a divergence rather than remove one. 13/13 green.

## 6 - Model TOS/THA on the microword CPU

Not modelled at all.

**The `IduHl`/`IduLl` "do the names cross?" question is HALF ANSWERED - the DIT side does NOT
cross.** Raw decode (`ContextLoad_TrapConfigRoutines_RawDecodeDump`, standoff section 120):

```
  LOADCT_TOS 0o11163  reads DPA+0x3C -> PCB 0xBC pcb_tos
  LOADCT_LL  0o11164  reads DPA+0x40 -> PCB 0xC0 pcb_ll
  LOADCT_HL  0o11165  reads DPA+0x44 -> PCB 0xC4 pcb_hl
```

`MmsUnit`'s `PcbTopOfStackOffset=0xBC`, `PcbLowLimitOffset=0xC0`, `PcbHighLimitOffset=0xC4` all
match. So the suspicion that `MmsUnit`'s constants are mislabelled was RIGHT IN GENERAL - one was,
`PcbChildTrapEnableOffset` sat on `pcb_mte1`, fixed in section 118 - but NOT for the limit fields.

**Still open: the REGISTER side.** Both `LOADCT_LL` and `LOADCT_HL` write `Dest=22` and converge on
the same tail at `0o11211`, differing only in `ORCON` (`0x00` vs `0x04`) - so the destination is
selected by the OR-control field, not by the Dest field, and which of `A,IDU,HL` (161) /
`A,IDU,LL` (162) each one lands on is NOT readable from the Dest column. **Settle it by execution as
this item always said:** seed distinct values at PCB `0xBC`/`0xC0`/`0xC4`, context-load, read
`regs.IduHl`/`regs.IduLl` back. Do not infer it from ORCON arithmetic.

## 7 - Adjudicate the remaining engine divergences

**SSKIP: DONE 2026-08-31.** The real B30 sets `Z=1` on EVERY non-trap termination - it does not
distinguish "source empty" from "different element found". Manual 14.14 says otherwise and the
microcode overrules it, as it did for the BI TEST carry and the single-float TEST sign. `CpuND500`
was implementing the manual faithfully and was wrong on two of three cases; fixed in
`Emulated.HW\ND\CPU\ND500\Instructions\STRING\Sskip.cs`, both engines now agree on all three
vectors with `I1` still 3/4/0. Standoff section 107.

**SCHPAR: still open, blocker named.** The vector does not retire on the microword - parked at CS
`0o10357`, which the `.LABE` shows is the `M01`/`M02` per-element scan loop under `SCHPAR_MODE`
@`010352`. The harness is not supplying what the mode dispatch needs. Fix the SETUP before reading
anything into SCHPAR's flags, and note that `0o10364 -> 0o10361` is the shared EXIT of four arms,
not a loop back into a loop body.

**Method that made SSKIP work, and is worth reusing:** one vector could only be believed, never
checked - and the obvious patch from it (invert one arm) would have been wrong. Three vectors
covering all three terminating conditions showed the whole branch was wrong. Then, because the
answer came back constant, `I1` was added as the discriminator: a flag that reads 1 for every input
is indistinguishable from an instrument that never ran.

## 8 — Lock every fix with a red-first regression test

Prove it RED before the fix and GREEN after. A test never seen red is not evidence.

Done for item 3: `Nd5000ControlStoreWritePathTests.WcsWrite_LandsOneMicrowordAtTheAddressedLocation`
was red ("Expected: 1, But was: 0") before the WCS commit existed and green after. Still owed for
items 1, 2 and 4.

**One honest caveat on that fixture.** Its sibling `AmirckRead_DoesNotWriteTheControlStore` passed
BEFORE the fix as well - not because the model was right, but because the isolated sequence never
staged eight words, so the old commit path bailed out. It is a valid guard now; it was not evidence
then. A test that is green for the wrong reason proves nothing.

## 9 - Finish the ND-500 conformance corpus triage

**RUN IT LIKE THIS.** The fixture is `[Explicit]` ON PURPOSE (16 MB machine per case, no failure
limit, exceeds the CI blame-hang timeout), so a default `dotnet test` SKIPS it and a green ND-500
suite says nothing about these rows. Comment the attribute out, build, **restore the source
immediately**, then run `--no-build` - the binary keeps the gate off and the tree is never left
edited. A rebuild of `Emulated.Tests.ND500` mid-run silently re-arms the gate and the run just stops
finding cases, which looks like success: **read `Loaded 40082` before quoting any failure number.**

**State after 2026-08-31** (was 266):

```
  Loaded 40082  Executed 36427  Passed 36185  Failed 242  NegativeOK 3655   99.34%
  36185 + 242 + 3655 = 40082    <- always reconcile this before quoting anything
```

**196 of the 242 (81%) are the corpus being WRONG, not the engine** - 184 divide-by-zero plus 12
SFILLN. Divide-by-zero: the corpus expects the
destination unchanged; the real B30 SATURATES to the dividend's sign, confirming the 2026-07-26
adjudication. Standoff section 110. **Do NOT regenerate those rows** - the corpus is a shared fixture
with nd500x and regenerating it from `CpuND500` would bake our answer in and destroy the only
independent source that disagrees. The genuinely open question is whether real HARDWARE suppresses
the destination write on a precise trap; neither engine can see that, and if it does, both of ours
are wrong together.

**16 more are the "documented overflow" rows** - `add2 MAX+1`, `mul2 MIN*2`, `div2`/`div3`/`/`
`MIN/-1` - which expect an `IntegerOverflow` trap to be DELIVERED. Integer overflow is an
**IGNORABLE** trap by our own trap table, delivered only when `TE` bit 9 is set, and every one of
those vectors starts `st: 0` with no trap-enable. **RAN IT - now `[V]`, sections 112 and 112a.** The
overflow IS detected and the trap IS raised; delivery needs FOUR conditions
(`dispatch AND enable AND THA != 0 AND not-in-handler`), and the corpus register model has none of
`OTE/MTE/THA` - its own generator says so. So no corpus row of this shape can ever be right.
Test: `TestND500_IgnorableTrapDelivery`.

**STILL `[OPEN]`:** whether we WOULD deliver given a fully configured domain. Setting `OTE1` bit 9
plus a raw `THA` did not dispatch, for an unidentified reason - `GetTrapHandlerAddress` resolves
through the domain/DIT and a translated vector read. Closing it needs a DIT-backed domain with a
real Start Address Vector.

```
  184  divide-by-zero    corpus wrong                    [V]
   12  SFILLN H and W    corpus wrong                    [V]
   16  overflow traps    corpus CANNOT express delivery  [V]
  ----
  212  of 242 accounted for; 30 rows still uncharacterised
```

**The rest of the tail, triaged 2026-08-31 (standoff section 113):**

```
  184  divide-by-zero        corpus wrong, B30 verified                [V]  s110
   12  SFILLN H and W        corpus wrong, copies of the BY row        [V]  s111
   16  overflow traps        corpus CANNOT express delivery            [V]  s112/112a
    9  privileged SYSTEM     corpus does not grant PIA (but COULD)     [V]  s113
    2  TSET register operand generator artefact                        [D]  s113
    1  Test_F_NegZero        DELIBERATE divergence - KEEP IT RED       [V]  s113
  ----
  224  of 242 = 93% accounted for
   18  left: Chain 4, Div4 4, Riom 2, Scopt 2, Sspan 2, Sscan 1, Schpar 1, +2
```

**`Test_F_NegZero` MUST STAY RED.** It expects `ST=0xA0` (Z+S); we give `0x20` (Z only) because of
the single-float `-0.0` rule Ronny adjudicated in item 5 - the B30 computes S as "sign AND the
SRF4-masked value is non-zero". It looks like a trivial one-row float fix and it is not: fixing it
reverts a microcode-adjudicated decision.

**The 9 privileged rows are the ONE cluster the corpus could fix itself** - PIA is ST1 bit 1 and the
`st` field can carry it. The trap-enable rows cannot be fixed that way: `OTE`/`MTE`/`THA` have no
slot in the corpus register model at all.

**The method that made this tractable, do not skip it:** ask the microcode, with a vector chosen so
the competing hypotheses predict DIFFERENT numbers, and keep any non-discriminating vector visibly
labelled so it is never counted as confirmation. Divide-by-zero needed dividend `0x64` for exactly
that reason, and `0x7F` is in the probe marked inert.

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
   the one you want.
 - **BUDGET ~31 MINUTES for the one test, not "2-4 min".** Measured 2026-08-31:
   `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture` took **30 m 46 s** and passed. The old
   "2-4 min" note in this file was wrong and made a healthy run look hung. To tell a live run from a
   dead one, read the CPU time of the testhost process (it sat at ~1226 s of CPU after 20 minutes) -
   never the log, which is buffered until the test ends.
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
