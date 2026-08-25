# PRIORITY PLAN 2026-08-24 — run REAL programs under REAL SINTRAN

**Full path:** `E:\Dev\Ronny\ND5000UC\PRIORITY-PLAN-2026-08-24-REAL-SINTRAN-DOM.md`
**Supersedes as the working plan:** `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md` (still valid for
the cross-core alignment track; this one owns the run-a-program track).

---

# THE GOAL — read this before every session

> **Run real ND-500 / ND-5000 programs on the emulated CPU, driven by REAL SINTRAN III running on
> the emulated ND-100, with every MON call FORWARDED over the bus/octobus to that real SINTRAN.**

**A run does NOT count if the MON calls are answered by our C# `SintranEmulation`.** That layer is a
standalone convenience. It proves the DOM decodes and the byte layouts are right; it proves nothing
about SINTRAN, the bus, the mailbox, the swapper or the microcode. On 2026-08-24 a CPU-STAT run on
that layer was reported as progress toward this goal. It was not. **This is the single easiest way
to fake success on this project — check the MON path before believing any "program runs" claim.**

**How to tell in one look:**

| | fake (does NOT count) | real (counts) |
|---|---|---|
| who answers MON | `cpu.SintranEmulation` (C#) | real SINTRAN via mailbox |
| ND-100 present | no | yes, booted |
| console output from | `CapturingConsoleIO` StringBuilder | the SINTRAN terminal |
| test lives in | `Emulated.Tests.ND500\Sintran\TestMON_*` | `Emulated.Tests\ND100\Nd100Sintran*BootHarness*` |

The forwarding chain that MUST be in play:
`CpuND500/CpuND5000 stops on MON` → `Nd5000CpuProcessBridge` → `Nd500MicrocodeServicer` → mailbox in
5MPM → **real SINTRAN on the ND-100** → answer → `OnMonitorCallRestart` (24B 3MONCO) /
`OnWaitMonitorCallRestart` (26B 3WMONCO) → FUNCV→X1, KFLIP→K → CPU resumes.

**Then, and only then**, the longer arc: multiple processes, scheduling/task-switch, and replaying
the microcode's behaviour on the macrocode CPU byte-identically.

---

## PHASE 0 — Stop fooling ourselves (do FIRST, half a day)

- [ ] **0.1 Label every ND-500 test by what it actually exercises.** Add a one-line banner to each
      fixture: `MON PATH: C# emulation` or `MON PATH: real SINTRAN over bus/octobus`. No exceptions.
- [ ] **0.2 Make the fake path announce itself.** `SintranEmulation` logs one line at first MON:
      `*** MON answered by C# EMULATION - this is NOT real SINTRAN ***`. It must be impossible to
      read a transcript and not know.
- [ ] **0.3 One status table** in `DIAGNOSTICS.md`: for each program (CPU-STAT, CONVERT-DOM, NC,
      LINKER, PLANC) x each path (C# MON / real-SINTRAN-3022 / real-SINTRAN-octobus / microword),
      record works / blocked-on-what / never tried.
- [ ] **0.4 Kill the ambiguity in the word "PCB".** Two 256-byte structures wear that name: the
      CONTEXT BLOCK (`SRF17*256 + 0x800`, = 4000B, holds registers) and the PCB/DIT (CED-indexed,
      holds capabilities/limits/PIA). Rename in code and comments: `ContextBlock` vs `Dit`.

## PHASE 1 — CPU-STAT under real SINTRAN (the milestone)

Target harness: `Emulated.Tests\ND100\Nd100SintranNd500BootHarnessTests.cs`
(`Nd500_D4_RunDomain_RealCpu_Capture` already does boot → login → PLACE-DOMAIN → RUN on the real CPU).

- [ ] **1.1 Get CPU-STAT.DOM onto the SINTRAN disk image.** The real path loads from the ND disk, not
      the host filesystem. Use `ndtool.exe` ([[ndfs-disk-tool]]). Verify by `@LIST-FILES` on the
      booted machine, not by asserting it worked.
- [ ] **1.2 Boot → login → `@ND-500` → `PLACE-DOMAIN CPU-STAT` → `RUN`.** Capture the console.
- [ ] **1.3 Assert the MON calls actually crossed the bus** — count `3MONCO`/`3WMONCO` round-trips in
      the servicer. Zero round-trips with output present = the C# layer answered; FAIL the test.
- [ ] **1.4 Expected blockers** (all found 2026-08-24, all documented): the swapper stall, PIA never
      set at 3START, seg-1 data-MMS off. A real failure here is the deliverable — it names the next
      fix. Do NOT fall back to the C# MON path to get a green result.

## PHASE 1 STATUS — 2026-08-24 evening

CPU-STAT runs on the real path. `answeredByCsharpEmulation=0` throughout; MON round-trips
2 → 208. It does NOT print yet. Blockers cleared, in the order they were hit:

1. **`SWAPPING SPACE NOT AVAILABLE`** — the pack's swap file is `:DATA`, the monitor defaults to
   `:SWAP`. Answer `swap-file:data` at DEFINE-SWAP-FILE. (Harness fix.)
2. **Boundary page faults carried `psn=0`** — the two boundary branches in `TranslateThroughPst`
   skipped `SetMmuFault`. The real swapper rejected the malformed message with Appendix-A 22B
   PAGE_FAULT "Illegal physical segment number". Fixed, committed `91f93e7ff`.
3. **Retryable traps resumed AFTER the faulting instruction** — skipping CPU-STAT's entry CALL, so
   its frame was never built and a B-relative store hit segment 0. Fixed in two places (context
   save AND live `regs.PC`), committed `f112300aa`.

### THE CURRENT BLOCKER [MEASURED, not yet diagnosed]

The domain issues **MON 422B (GSWSP** — get scratch segment, `size=0x00020801`, `LogSegmentNo=0`
= "system picks", output param should return the chosen segment). SINTRAN hands off to the swapper
(correct — GSWSP reserves swap-file space), then answers the domain:

```
CONTEXT SWITCH X5CPU=0 -> 1 (P=0x0800473A)
RESTART write-back: (empty)
RESTART K=1 FUNCV=0x0000020B
```

**K=1 is the error flag**, and `0x20B` = **1013B** = *"Illegal monitor call number"*
(ND-05.017.01 error table). The domain then stops progressing — final state
`PC=0x08004A69 stopMode=NONE`, i.e. RUNNING but not advancing, and SINTRAN falls back to 3RMICV
watchdog polling after ~20s.

**It is STUCK, not slow** — proven by doubling the RUN window: 300s and 600s produce the identical
endpoint (208 round-trips, same last fault `0x08004BD1`).

> **CAVEAT 2026-08-25 - that proof has a hole. Check it before relying on it.**
> Identical endpoints at 300s and 600s prove the run is NOT wall-clock-bound. They do NOT prove the
> guest is stuck: an instruction budget, a message cap or a log-ring limit would ALSO produce byte-
> identical endpoints at both durations. Those two cases look the same from the outside, and the
> distinguishing evidence is cheap: **is the last fault address REPEATING or ADVANCING?** A repeat
> is a hang; an advance (one 2 KB page per fault) is progress being cut off. The ND-500-CPU lane hit
> exactly this and found progress where it had assumed a hang. Read the tail of the log in order and
> find what ENDS the run before diagnosing why it stopped.

### THE FORK — resolved to (a), 2026-08-24

**(b) "our MCNO is wrong" is REFUTED.** Both MON numbers travel the identical path and only one
fails:

```
MON 377B (swapper)  K=0 success           x88
MON 422B (domain)   K=1 FUNCV=0x0000020B  = 1013B illegal monitor call number
                    K=1 FUNCV=0x00000203  = 1003B error in monitor call        x2
```

If `MCNO` were mangled nothing would succeed. (Counts are indicative only - `MonCallLog` is a
400-line ring and 209 calls were forwarded, so roughly the last 138 are visible.)

**The call number is right too** - `cpu-stat.asm` names `MON 422B` at 2 sites, so the CALLG decode
is not inventing it. GSWSP is also documented for ND-500 (ND MON Calls overview marks both the
`100` and `500` columns).

**Careful with the sources here.** `Monitor Calls.md` line 30554 shows "GSWSP | 266" - that is a
PAGE-NUMBER INDEX, not a call number. Reading it as one would send you hunting a call that does not
exist; this is the same trap recorded in the global rules for 2026-08-18.

### NEXT STEP

CPU-STAT's runtime init calls GSWSP FIRST, so the program never reaches its own logic (the fake-path
run made 48 calls starting 11B/114B/143B; on the real path only 422B is ever issued).

> **RETRACTED SAME DAY 2026-08-25 - the "REFUTED" banner below was WRONG. See the WITHDRAWAL note
> after it. The original finding (422B fails on this image) STANDS.** The block is kept, struck
> through, because the mistake in it is instructive and must not be made again.
>
> ~~**CORRECTION 2026-08-25 - "this image does not implement 422B" is REFUTED. Do not re-adopt it.**~~
>
> The ND-500-CPU-lane session reported five successful GSWSP calls against real SINTRAN, each
> returning an allocated segment number in the OUT parameter (slot [2] = 0, 2, 3, 4, 5), with the
> program then doubling the requested size and retrying:
>
> ```
> [0] size            [1] LogSegNo   [2] SelectedSegNo (OUT)
> 0x00020801          0              0
> 0x00040801          0              2
> 0x00080801          0              3
> 0x00100801          0              4
> 0x00200801          0              5
> ```
>
> So 422B IS dispatched and IS answered by this SINTRAN. Two consequences:
>
> 1. The **empty vector slot** reading was wrong. `030-S3SM5` slot
>    `0x60 + 2*0o422 = 0x0284 = 0x0000` is real (byte-verified, and independently found by
>    `NDInsight\...\mon-oracle-for-NC\tier3-422B-GSWSP_256B_41B_50B.md`), but that doc's reading -
>    *"GSWSP is NOT dispatched through that vector table, it reaches its worker by a different path
>    in the System Monitor"* - is the CORRECT one. An empty slot in that table does NOT mean
>    unimplemented. The missing `GSWSP` SYMBOL means nothing either: `GSWSP` is the ND-500
>    loader-monitor's short name; SINTRAN's own name for it is `GetScratchSegment`.
> 2. `[1] = 0` on every call is the DOCUMENTED "system picks the segment" input, not a marshalling
>    failure, and `[2]` running 0,2,3,4,5 is the allocator working - not a counter.
>
> **THE REAL OPEN QUESTION (this is now the valuable one).** Both runs are positive measurements of
> the SAME call with the SAME parameters - first GSWSP is `size=0x00020801, LogSegNo=0` in both -
> and they disagree:
>
> | lane | result |
> |---|---|
> | this doc's run | `K=1  FUNCV=0x0000020B` = 1013B illegal monitor call number |
> | ND-500-CPU-lane run | `K=0`, segment 0 returned, then 4 doubling retries |
>
> Two positive results cannot both describe the same configuration, so **the CONFIGURATIONS differ**
> and finding that difference is the next step - NOT more carving of `MCHANDLE`. Candidates to
> check first, cheapest first: which SINTRAN pack/image is mounted; which CPU lane and bridge is
> attached; and which uncommitted fixes are present in each tree (this tree still carries the
> per-process message fallback, the subtype translation and `ND500_NO_RESTART_P1` - all uncommitted
> and some never exercised).

> ### WITHDRAWAL 2026-08-25 - there was never a disagreement. Both runs measured the SAME FAILURE.
>
> The "five successful calls" reading is wrong, and the ND-500-CPU lane's OWN log disproves it:
>
> ```
> MON 422B argc=3 ret=0x08003F73
>   RESTART write-back: (empty)
>   RESTART K=1 FUNCV=0x00000203
> ```
>
> **`K=1` is the ERROR flag** - `[V]` from the manual via
> `NDInsight\...\mon-oracle-for-NC\tier3-422B-GSWSP_256B_41B_50B.md`: *"on error the K-register is
> set and the standard error code is in W1; `IF K GO ERROR`"*. And `0x203` = **1003B = "Error in
> monitor call"**. Same error family this doc measured (`0x20B` = 1013B, plus `0x203` x2). So both
> lanes saw 422B FAIL. There is no configuration difference to hunt.
>
> **THE READING ERROR, because it is worth not repeating.** Slot `[2]` is an OUT parameter. SINTRAN
> returns an OUT parameter **through the RESTART write-back** - and the write-back is EMPTY, so
> SINTRAN wrote nothing. The `0, 2, 3, 4, 5` was read out of CPU-STAT's parameter block in ND-500
> memory, which is the program's own data, not SINTRAN's answer. Whatever those values are (a
> program-side retry index, or stale memory - note the sequence SKIPS 1, which a first-free-slot
> allocator would not do), they are not allocated segment numbers.
>
> **The general trap:** a plausible value sitting in an OUT slot looks EXACTLY the same whether the
> callee filled it or nobody did. The parameter block is DATA; `K` and the write-back are the
> VERDICT. Never read the OUT slot without checking the verdict first - this is the same shape as
> "did not happen and could not be observed look identical in a log".
>
> **Still genuinely open** (do not paper over it): why the SAME call returns `1013B` ("illegal
> monitor call NUMBER") on some stops and `1003B` ("error IN monitor call") on others. Those are
> different failures. Nobody has explained that split, and it is the real lead - `1015B` ("wrong
> number of parameters") notably does NOT appear, so argc=3 is being accepted.

### THE REAL DAMAGE IS MON 377B, NOT 422B - 2026-08-25 (ND-500-CPU lane, pairing each call with its answer)

Pairing every forwarded call with the K flag and FUNCV that came back reverses the target:

| call | K | FUNCV | count |
|---|---|---|---|
| MON 377B argc=4 | 1 | `0x20B` = 1013B illegal monitor call number | **48** |
| MON 377B argc=4 | 0 | - | 40 |
| MON 377B argc=7 | 0 | - | 18 |
| MON 422B argc=3 | 0 | - | 8 |
| MON 422B argc=3 | 1 | `0x203` = 1003B | 2 |

GSWSP mostly SUCCEEDS (8/10). **The swapper's own MON 377B argc=4 fails 48 of 88.** Same MON
number, same argc, succeeding 40x and failing 48x - so it is not a wrong call number in the plain
sense, it is a rejected SUB-FUNCTION.

**The discriminator, measured:** every SUCCESS has `[1] @0x080240B0 == 0`; 46 of the 48 failures
have it non-zero (`0x437` x38, `0x217` x8). On failures `[1]` and `[3]` hold the SAME value; on
successes `[1]` is 0 while `[3]` varies freely.

**WHAT `0x080240B0` IS - carved, do not re-derive [V].** `swapper-k01-handlers.md` §2.1:
the swapper's dispatch function code *"arrives as the OUT result of the swapper's MON 377B
**sub-function 1** call, is stored at DSEG `0x240B0`, then copied to `0x240B8`"*:

```
1000101171  w1 := $1000440260      ; w1 := [0x240B0]  (sub-fn-1 result)
1000101177  w1 =: $1000440270      ; [0x240B8] := w1  (dispatch index)
```

Arithmetic: `0o440260` = 4*32768 + 4*4096 + 128 + 48 = 147632 = `0x240B0`; +`0x08000000` =
`0x080240B0`. EXACT match with the write-back address.

So that cell is **the swapper's WORK-ORDER INBOX** and our write-back to it is correct IN
PRINCIPLE - SINTRAN is supposed to answer "what do I do next" by writing a function code there.
The bound is **0 <= fn <= 0o34 (28)**, and a good value looks like the `0x0A` seen in a healthy
write-back: **10 = `MSWPFAULT`**, the page-fault work order. `0x437` (1079) and `0x217` (535) are
not function codes at all.

**Therefore the bug is the VALUE, not the address.** "Our write-back dirties a slot the swapper
trips over" is the WRONG framing - the slot is ours to write. Something is putting a non-work-order
into the work-order slot. Different bug, different fix.

**NAMESPACE TRAP - do not conflate these two function-code spaces:**

| space | direction | range | where it lives |
|---|---|---|---|
| swapper dispatch fn | SINTRAN -> swapper | 0..28 (`0o34`) | DSEG `0x240B0` -> `0x240B8` |
| `SWPFU` | swapper -> SINTRAN | 0..~6 (`SWFMAX`) | a field in the MAILBOX MESSAGE |

`SWPDECODER` (MP-P2-N500.NPL:135451) is a 7-arm `GOSW` on `SWPFU`
(`0 ESWPFATAL, 1 LNEWSWAP, 2 LSWPAGE, 3 LPRSUSPEND, 4 LALLOPAGE, 5 LDATREADY, 6 LCLTSB`,
`IF A >> SWFMAX GO FAR ESWPFATAL`). **`SWPFU` is what SINTRAN rejects on** - not the value at
`0x240B0`. Checking one against the other's bound will send you the wrong way.

**NEXT MEASUREMENT (specific target):** log every write to `0x080240B0` with the WRITER's identity
and its position in the sequence (our write-back path / the swapper's own code / SINTRAN), **and
log `SWPFU` on each outgoing 377B alongside it**, since `SWPFU` is the field the 1013B rejection
actually keys on. One run names the culprit.

#### THE FIRST FAILURE IS CALL #14, AND IT IS INVISIBLE IN WHAT WE LOG [ND-500-CPU lane, 2026-08-25]

Sequenced, the failures split cleanly:

```
13  ok    [0]=1 | [1] @0x080240B0=0x00000000 | [2] @0x080240B4=0x00210718 | [3] @0x0802428C=0x0000000C
14  FAIL  [0]=1 | [1] @0x080240B0=0x00000000 | [2] @0x080240B4=0x00210718 | [3] @0x0802428C=0x0000000C
15  FAIL  [1] @0x080240B0=0x00000437     <- error value now in the fn cell
16..21 FAIL  ... = 0x00000437
```

**#13 and #14 are byte-identical in every parameter we record**, yet one is accepted and the next
rejected. The discriminator is a field we do NOT log - which is exactly `SWPFU` (in the mailbox
message, not in these by-reference args). We have been reading the wrong four values.

The `ifkret` mechanism is carved (correction paragraph in `swapper-k01-handlers.md`, PROVEN bytes):
*"ifkret PROPAGATES K up every caller - so a K=1 reply unwinds the worker into `1000101241` (which
writes W1 into the fn cell `[0x240B0]`, clrk, returns to the stub)"*. That explains where the
values come from.

**THE ERROR VALUES ARE CARVED - do not mark them unknown [V]:**

| seen | octal | identity |
|---|---|---|
| `0x437` = 1079 | `0o2067` | **PROVEN** `swapper-k01-handlers.md` §4: workers reject ids `<7` or `>[0x128E4]` with `0o2067` (recurs idx 10/14/15/19/21) |
| `0x217` = 535 | `0o1027` | PROBABLE - not in the carve, but adjacent to idx 10's documented `0o1030`/`0o1031` bad-state codes. `[OPEN]` |

Arithmetic: `0o2067` = 1024+48+7 = 1079 = `0x437`; `0o1027` = 512+16+7 = 535 = `0x217`. Both are
swapper-internal ERROR codes sitting in a function-code cell - consistent with `ifkret`.

**CAUTION - the cascade explains the VALUES but NOT the REJECTIONS. Two readings are still open
and they lead to OPPOSITE fixes:**

1. **Cascade** - #14 is the root and the dirty fn cell drives the later rejections. This REQUIRES
   `0x240B0` to be IN/OUT, or `SWPFU` to be derived from it. Neither is established.
2. **Common cause** - #14 and the later 46 fail for the SAME reason and `0o2067` is a side effect
   that causes nothing. "One bug, not 48" would then be right about the COUNT, wrong about the
   MECHANISM.

Evidence currently AGAINST reading 1: **call #14 failed with the fn cell CLEAN (`=0`)**, so a dirty
fn cell is demonstrably NOT NECESSARY for a 1013B; and `0x240B0` is documented as the sub-function-1
**OUT** slot, where a stale value should not affect the next call's legality.

**The `SWPFU` log separates them in ONE run:** `SWPFU` bad only after #14 -> cascade;
`SWPFU` bad on #14 AND the later failures -> common cause. Log the fn cell and `SWPFU` TOGETHER,
per call, so they can be compared rather than argued about.

**Method note worth keeping:** the `[1]==[3]` correlation was dropped rather than hardened, and that
is what surfaced #14 - the two failures with `[1]=0` that BROKE the correlation were the signal.
Second time this session that the anomalies breaking a pattern mattered more than the pattern.

#### ANSWERED 2026-08-25 - NEITHER CASCADE NOR COMMON CAUSE. WE ANSWER THE SWAPPER ON THE WRONG MESSAGE. [V]

`SWPFU` + both swapper cells logged together (`Nd500CpuProcessBridge`, built clean, CPU-STAT harness
re-run 12m42s, 33122 lines). The pairing is a PERFECT correlation over 124 MON 377B calls.

> **CONFIRMED INDEPENDENTLY 2026-08-25** by the ND-500-CPU lane, which reproduced the same split
> from its own run. Two separately-instrumented lanes measuring the same correlation is a stronger
> result than either run alone - and it rules out the one thing a single lane could not: that the
> split was an artifact of THIS harness's instrumentation rather than a property of the system.

| message | X5CPU | 377B calls | outcome |
|---|---|---|---|
| `0x00420D30` | **0** = the SWAPPER | 78 | **78 x K=0 - every one succeeds** |
| `0x00420E30` | **1** = CPU-STAT | 46 | **every one fails, `K=1 FUNCV=0x20B` = 1013B** |

Restart tally agrees exactly: `78 x K=0 X5CPU=0`, `48 x K=1 FUNCV=0x20B X5CPU=1`,
`2 x K=1 FUNCV=0x203 X5CPU=1` (the two failed 422B), `8 x K=0 X5CPU=1` (the eight good 422B).

**Both 377B calls come from the SAME caller** - `ret=0x08008255`, swapper code (it is the `P` in
`CONTEXT SWITCH X5CPU=1 -> 0 (P=0x08008255)`). Same code, two different messages, opposite answers.

**MON 377B is N5SWAP - the SWAPPER'S PRIVATE call** ("MON.CALL USED BY THE SWAPPER",
MP-P2-N500.NPL:1273). Issued on process 1's message, SINTRAN sees a non-swapper process making the
swapper's call and answers "illegal monitor call number". **SINTRAN IS CORRECT. The defect is ours:
the swapper's MON stop is answered against CPU-STAT's mailbox message.**

**THE `0x437` WAS AN ARTIFACT OF THE DIAGNOSTIC ITSELF. Retract the cascade story entirely.**
`0x240B0` is the swapper's fn cell ONLY WHILE THE SWAPPER IS MAPPED. On the X5CPU=1 lines the read
returns CPU-STAT's memory at that virtual address - a different cell. Whenever the swapper IS mapped
its cells are healthy on every single call:

```
X5CPU=0  SWPFU=0x0000 SWPST=0x000A | FN@0x240B0=0x00000000  DISP@0x240B8=0x0000000A   <- MSWPFAULT, valid
X5CPU=1  SWPFU=0x0001 SWPST=0x0437 | FN@0x240B0=0x00000437  DISP@0x240B8=0x00000000   <- CPU-STAT's memory
```

There was never an error code in the function-code cell. `0o2067`/`0o1027` were correctly identified
as swapper error codes, but they were never IN that cell - the read was in the wrong address space.
Likewise `SWPFU=0x0801` is a garbage read of a word that means something else in CPU-STAT's message;
on the swapper's own message `SWPFU` is only ever `0x0000` or `0x0002`, both in range.

**LESSON (the third time this shape has bitten this session):** a diagnostic that reads process
memory must state WHICH PROCESS IS MAPPED, and be distrusted whenever that is not the process the
address belongs to. The caveat was written into `AppendSwapperFnCells`' own doc comment before the
run and still nearly produced a wrong conclusion - because a plausible value came back instead of a
fault. `unmapped` in that log is a HEALTHY outcome; a plausible number from the wrong process is the
dangerous one.

**THE FIX - already in this tree, uncommitted and never exercised.** `Nd500MicrocodeServicer` has
`_processMessageByX5Cpu[64]` + `RememberProcessMessage` + `GetProcessMessageAddress`: a per-process
message map, which is exactly the replacement for the single global `ActiveProcessMessageAddress`
this bug is made of. Wire the MON-stop answer path to route by the CALLING process's X5CPU instead
of the global, then re-run and expect the 46 X5CPU=1 377B calls to disappear.

#### APPLIED + VERIFIED 2026-08-25. THE MISROUTING WAS ALSO CORRUPTING THE DOMAIN. [V]

Both preconditions measured before touching code:
- map populated for BOTH processes: `X5CPU=0->0x00420D30  X5CPU=1->0x00420E30`;
- across ALL 124 MON 377B calls the loaded process was **0** every time (78 answered on D30 -> all
  K=0; 46 answered on E30 -> all K=1). So selecting by loaded process routes all 124 correctly.
- pointer trail names the mechanism: **46x `ACTIVE-MSG 0 -> 0x420E30 (start-taken)`** - a start of
  the DOMAIN claimed the global while the SWAPPER was the process actually stopping.

Fix = one invariant, one helper (`ResolveMessageForRunningProcess`), used by BOTH the monitor-call
and trap answers: **a stop is answered on the RUNNING process's own message**, global only when the
process identity is unknown. Post-fix run: **zero K=1**, `MSG-SELECT` lines show the divergence
being corrected, and SINTRAN now issues REAL in-range work orders (`FN@0x240B0` = 5, 3, 0o30=24,
9 - the allocation handlers) instead of the swapper thrashing on rejections.

**THE SECOND HALF OF THE DAMAGE, missed until Ronny pushed back on a "regression" claim.**
Post-fix, CPU-STAT takes ONE fault (`pc=0x08000004`, `faultSeq=1`) where before it showed 52 trap
lines up to `faultSeq=271` at deeper PCs. That looks like a regression and **IS NOT**. The
before-fix log ring STARTS at `faultSeq=192` - it was a late steady state, and the steady state was:

```
CONTEXT SWITCH X5CPU=0 -> 1 (P=0x0800467F)
RESTART K=1 FUNCV=0x0000020B          <- CPU-STAT restarted WITH THE 1013B ERROR
TRAP 46B pc=0x0800467F addr=0x0001D000  faultSeq=192
   ... swapper 377B, one good one misrouted ...
RESTART K=1 FUNCV=0x0000020B          <- again
TRAP 46B pc=0x0800467F addr=0x0001D800  faultSeq=195
```

The swapper's misrouted call landed on CPU-STAT's message, SINTRAN answered THAT message with
`K=1/0x20B`, and the bridge applied it to CPU-STAT (`cpu.regs.ST.K = kFlag`, `cpu.regs.I1 = funcv`).
**The domain was being restarted repeatedly with another process's error code injected into its
registers**, stuck at one PC with the fault address marching through `0x1C000..0x1E000` in a segment
(psn=13) it had no business in. That was never progress - it was one program running corrupted
because another program's failed call was written into its mailbox.

**LESSON: "it got further" is not progress if the state is corrupt.** A higher PC and a bigger fault
count read as advancement and were the opposite. The discriminator was sitting in plain text on the
restart line - `K=1` - the same flag that had already been missed once on the 422B calls.

**CURRENT FRONTIER (new, never reached before):** CPU-STAT starts clean, faults once at its true
entry `0x08000004`, and SINTRAN repeats `MICFU=000B X5CPU=1 STOPR=0021` on `0x420E30` - a copy
operation, i.e. it is genuinely trying to deliver the page. The demand-page-in loop not completing
is the next blocker. It is NOT something the fix broke.

**Diagnostic defect fixed in the same pass:** the MON-call log's `SWMSG@` field printed
`ActiveProcessMessageAddress` (the stale global) rather than the message the answer actually used,
which made two correctly-routed post-fix calls look misrouted. It now prints the RESOLVED target and
notes the global separately. Any earlier conclusion drawn from that field needs re-reading.

**Correction of record:** the earlier "the swapper is working, the run is just cut short" reading
was wrong. The page-fault walk underneath it advances cleanly, which is what made it look healthy -
but the `K=1` on the MON answers sitting directly above it went unread. Always check `K` before
reading anything else out of a restart record.

If that comparison does NOT explain it, only then carve `MCHANDLE` in this image and read its
supported MON range. `MCHANDLE` is a real symbol but its address is version-specific and must come
from THIS image's symbol table (Operations/SINTRAN/ND500-MONITOR-CALL-ARCHITECTURE.md warns against
any address quoted in a document). That is carving work, not a lookup.

Then the open question becomes what CPU-STAT should do with the error - it currently stops
progressing (`PC=0x08004A69 stopMode=NONE`, running but not advancing) rather than reporting it.

**DO NOT "fix" this by answering 422B from the C# SintranEmulation layer.** That is the fake path
and it would make the test lie.

## THE CURRENT BLOCKER, restated after LED-FORTRAN — 2026-08-24 late

Switching program removed the GSWSP problem and exposed an EARLIER one, on machinery every
program needs. LED-FORTRAN installs and PLACE-DOMAINs cleanly, then RUN dies before the domain
executes anything (15 MON calls forwarded, ALL the swapper's, none the domain's).

**SINTRAN creates the PROGRAM segment's PST entry but never the DATA segment's.** Measured on
both programs:

| segment | psn | capability | PST entry |
|---|---|---|---|
| program, seg 1 | 11 | `0x000B` (no PC_IND/PC_OMC - normal direct) | **created** (`0x0FF9`, later upgraded to indexed `0x4FF8`) |
| data, seg 1 | 12 | `0xC00C` = `DC_WRP\|DC_PAC` = SG_URW, user read/write | **never created** |

Both capabilities decode correctly - the top two bits mean different things on the data side
(`DC_WRP`/`DC_PAC`) than the program side (`PC_IND`/`PC_OMC`), and psn 12 is right. So this is not
us misreading the capability.

Consequence: every data access page-faults with `MM_PFZPST` ("PST entry 12 is ZERO"), the address
creeping forward ONE BYTE per fault, until the swapper gives up with "Illegal physical segment"
(Appendix-A 22B).

### ROOT CAUSE, from the MICROCODE — 2026-08-24 (Ronny: "why don't you analyse the microcode")

> **SCOPE CORRECTION 2026-08-25 - the heading below overstates the consequence.**
> What is `[V]` here is only that the REAL MICROCODE has a `TRAP_SWAP` step we do not model.
> It is NOT true that "the swapper is never asked to page anything in": the ND-500-CPU-lane
> session measured demand paging working end-to-end on the functional lane -
> `TRAP 46B pc=0x0800467F` with the fault address advancing `0x1C000 -> 0x1C800 -> 0x1D000 -> ...`,
> exactly one 2 KB page per fault, monotonically. **An ADVANCING fault address is progress; only a
> REPEATING one would be a hang.** Each fault completes a full round trip (trap-stop on the domain
> -> context switch to swapper -> MICFU 14/15 -> restart the domain). So the servicer's stand-in
> path does wake the swapper; it just does not do it the way the microcode does.
>
> The real difference `TRAP_SWAP` makes is COST, and it is worth knowing: the microcode builds the
> swapper message ON-CPU at `START_MESS`, so on real hardware a page fault never crosses to the
> host. Our functional lane pays **four mailbox round trips per 2 KB page** instead - ~4000 messages
> for the 2 MB scratch segment CPU-STAT ends up asking for. That is an artifact of the servicer
> standing in for microcode, NOT something the real machine paid, and it is the likeliest reason a
> functional-lane run looks "stuck" when it is actually grinding.

**We never ask the swapper to page anything in.** On a page fault the real microcode does TWO
things (`TRAP_PGF0/1` @013430):

1. `TRAP_GEN4` — stop the process with the trap record. **We do this.**
2. **`TRAP_SWAP` @013453 — build a message to the swapper in the `START_MESS` area (0o20000)
   and re-enter the message chain. We DO NOT DO THIS AT ALL.**

`MAILBOX-MICROCODE-PSEUDOCODE.md` calls step 2 *"the microcode side of demand paging: the fault
stops to the ND-100 AND/OR wakes the swapper"* `[V flow]`. There is no `TRAP_SWAP`, no
`START_MESS` and no 0o20000 handling anywhere in `Nd500MicrocodeServicer`.

It is a genuinely separate signal, not a side effect of answering: `TRAP_SWAP` rings the doorbell
with `(x & 0o037400) | 0o100102` (025005-06) where a normal answer uses `0o100401`.

**This corrects the previous entry's framing.** "SINTRAN creates the program segment's PST entry
but never the data segment's" is right about the symptom and WRONG about the cause - SINTRAN was
never asked. The program segment's entry gets created by the PLACE/RUN path, not by demand paging,
which is why only the data side looks broken.

Two smaller gaps found alongside it, same source:
- `TRAP_END` sets `N5STA = run ? 3 : 4` (ANSWER / 5ERANSWER). `AnswerActiveProcessMessage` always
  writes 3 and has no path for 4. The carve note is explicit: SINTRAN's DECOERRMESS special-cases
  trap-shaped `N5STA=4` - `TRAPN=0o46` + legal MICFU routes to ITRAPDECODER (the swapper) - *"The
  emulator MUST reproduce this conditional."*
- **The SINTRAN-side discriminator is `TRAPN` + `MICFU`, NOT `STOPR`.** Our trap path writes STOPR
  and TRAPN and never touches MICFU.

**Next step - measure, do not guess the layout.** The exact fields `TRAP_SWAP` writes are not in
the pseudocode. Get them from the machine with `MicroStateTrace` + `TracingMicroMemory`.

**ATTEMPT 1 (M3_Measure_TrapSwap_SwapperRequestMessage) - NULL RESULT, cause known.** Entering
`TRAP_SWAP` @0o24734 COLD does not reproduce it. Measured, with `Verbose` on:

```
t=1 CS=024734(TRAP_SWAP) A=A,BM00 B=B,X1 D=D,NONE SEQ=(none) ->000104
t=2 CS=000104(DUMMY_2)
t=3 CS=000105(DUMMY_1) ->000000        <- MASTER_CLEAR
```

Zero writes. `TRAP_SWAP` is a SUBROUTINE (CALLed from 013453 per the .LABE), so on a cold entry
the sequencer stack is empty and it falls through the DUMMY delay slots into master clear. It has
to be reached through a REAL page fault - which means seeding MMS state so a translation actually
fails, then letting `TRAP_PGF0` @013430 route into it.

Two lessons kept in the test:
- **Turn `Verbose` ON when entering a routine cold.** The words that decide whether a routine
  proceeds usually change no register, so deltas-only mode prints nothing and the first visible
  line was `MASTER_CLEAR` at t=4 - which looked like the entry address had been ignored.
- **Gate on the right counter.** The test asserted `trace.Lines > 0`, which passed while
  `writes == 0`. For a "what does it write" question the meaningful gate is the WRITE count; a
  state-line count can be non-zero for a routine that declined immediately.

### THE MICROWORD LANE, measured 2026-08-25 (Ronny: "test microcode 5000 cpu and see what it logs")

**The real B30 microcode drives the whole ND-500 monitor bring-up with NO unmapped instruction.**
732,429,400 microword ticks, `stopped=0`, zero throws, through:

```
[after @nd-500 (entered)] [after status (ok)] [after memory-configuration (ok)]
[after load-swapper (prompt back)] [after START-SWAPPER (pre-give) (no prompt)]
[after give-n500-pages (no prompt)] [after SET-ND-500-AVAILABLE (STALL/no prompt)]
```

**It is not stuck - it is IDLING correctly.** The per-microword stall trace (500 words, labelled)
shows the documented idle mailbox poll, 13 full cycles in 500 ticks:

```
024670(IDLE) -> 016572(ATRAP_CHK) -> 017377(ADR_ATRAP) -> 000104/000105(DUMMY_2/1)
   -> 016573(ATRAP_CHK+1) -> 016556..016564(SCAN_ACCP..SCAN_ACCP3) -> 024702..024707(IDLE_1..+5) -> repeat
```

`Mpc=0o24670` = IDLE, `P=0` = no process ever loaded, `distinctP=1`.

**What it is waiting for: `noX5act = 5,860,379`.** The microcode polled the X5ACT activation cell
5.86 MILLION times and never found it set. SINTRAN never activates the ND-5000 - which is why no
prompt ever comes back. See [[nd5000-timeout-convergence]] for the recorded fix direction
(deterministic X5ACT address `5FPMAILBOX<<10 + X500DF`, not the `0xFFFF`->0 sniff).

**Why this lane matters for the TRAP_SWAP problem:** the microcode implements `TRAP_SWAP` itself, so
demand paging comes for free here - no reimplementation in `Nd500MicrocodeServicer`. Getting X5ACT
delivered is the gate.

**Instrumentation added:** `MicroStateTrace` is now wired into the harness's stall block (500 words,
Verbose on), and `MICRO-5800-B30.LABE` is linked next to the test in the csproj. Without the .LABE
the trace prints bare octal and there is no way to see that `024670` IS the IDLE poll - measured, it
came out unreadable the first time.

### RULED OUT by A/B experiment, do not re-chase

The restart-at-P1 change is **NOT** the cause of the one-byte-per-fault pattern. Running
LED-FORTRAN with `ND500_NO_RESTART_P1=1` (the diagnostic switch added for exactly this) produced an
IDENTICAL result - same 17 traps, same addresses, same 15/14 MON counts.

That also establishes something worth knowing: **a fault DURING an instruction resumes it
mid-execution rather than restarting it.** With the fix `PC` is forced to `0x08000004`, without it
`PC` stays `0x08000011`, and the outcome is the same either way - so this path never re-fetches
from `PC`. The restart-P1 fix governs faults on an instruction FETCH (which is what CPU-STAT's
skipped CALL was, and it genuinely fixed that), not faults inside one. Whether mid-instruction
resume is architecturally correct is a separate, open question.

## PHASE 2 — Clear the swapper blockers (what Phase 1 will hit)

- [ ] **2.1 Wire the DIT load into 3START.** `StartProcessFromRegisterImage` never loads DIT state,
      so PIA and the limits stay unset → first privileged instruction ILLEG-traps → `Mpc=0o103`.
      The readers already exist (`ReadDIT_TOS/_LL/_HL/_THA/_PrivilegedAllowed`,
      `LoadDomainStateFromDIT`) but are wired only to domain CALL/RETURN
      (`CpuND500.Domain.cs:692`,`:774`). Addressing is settled: **physical `CED*256 + 0x80`, no base**
      (`RD,PHYS`). See [[nd5000-context-load-contract]].
- [ ] **2.2 Fix the four-field divergence.** `CpuND500.ProcessControl.cs:480-483` reads
      `TOS@+0x4C, LL@+0x50, HL@+0x54, THA@+0x58` from context-block slots **nothing ever writes**.
      All four are DIT fields: `tos@0xBC, ll@0xC0, hl@0xC4, tha@0xB6`. Invisible today (all read
      zero), so it needs a test that populates the DIT and proves the values arrive.
- [ ] **2.3 Root-cause the seg-1 data-MMS being off** (`dataCap[seg1]=0x0000`, translate returns
      identity). Blocks every seg-1 read the swapper makes.
- [ ] **2.4 Fix `MmsUnit.cs:183`** — `PcbChildTrapEnableOffset = 0xA6` is `pcb_mte1` (MOTHER), not
      cte1; cte1 is `0x9E`. Add the missing `tha@0xB6`, `cte1@0x9E`, `mte*`, `temm*` constants.

## PHASE 3 — More programs, same real path

- [ ] **3.1 CONVERT-DOM-A03**, **3.2 NC-A06 compile**, **3.3 LINKER-B01**, **3.4 PLANC-500**.
      Each on the real path only. `nd500-apps` skill has install/run conventions.
- [ ] **3.5 Byte-compare** compile/link output against the nd500x oracle
      (`ND500_COMPILE_BYTE_EXACT_HANDOFF_2026-08-04.md` has the frame-log diff technique).

## PHASE 4 — Multiple processes and scheduling

- [ ] **4.1 Two DOMs resident**, **4.2 task switch**, **4.3 demand paging via the swapper**,
      **4.4 PSEG/DSEG loading for a second process**.

## PHASE 5 — Macrocode replay of the microcode (the long arc)

- [ ] **5.1** Capture the microword CPU's full behaviour with `MicroStateTrace` for: startup, each
      message type, context load, MON stop/restart.
- [ ] **5.2** Make the macrocode CPU reproduce it, comparing state after every step.
- [ ] **5.3** A macrocode swapper that reports **byte-identical** to the microword one.
- [ ] **5.4** Swap back and forth until identical.

## PHASE 6 — SEMICS microtests (deferred by Ronny; end of plan)

- [ ] **6.1** Resolve the TPE checkpoint STOP question (does TPE issue CONTMIC, or does nothing
      report the STOP back to the ACCP?). Harness already works.

---

## RULES THAT KEEP THIS HONEST

1. **Never report a program as "running" without naming which MON path answered.**
2. **A real failure on the real path beats a green test on the fake one.** Never switch paths to get
   a pass.
3. **Raw microwords only** for ORCON/MARG/SARG/SCAL — the rendered `.md` mis-renders them, and did so
   twice on 2026-08-24 inside one routine.
4. **A counter that never incremented is not a measurement.** Compute "how many did I actually read"
   and refuse to conclude at zero.
5. **Check `DIAGNOSTICS.md` and grep the tests before building an instrument** — one already existed
   on 2026-08-24 and was nearly rebuilt.
6. **Verify paths/topology before acting** — nd500x is in WSL `~/repos/nd500x`; the ND-500 code is
   written to SHARED MEMORY, not copied over the octobus; the swapper is ALWAYS loaded by nd-500-mon.
