# PRIORITY PLAN — run a real program under real SINTRAN (2026-08-25)

Supersedes the run-a-program half of `PRIORITY-PLAN-2026-08-24-REAL-SINTRAN-DOM.md` (kept as the
evidence record and correction log — read it before re-opening any closed question there).
The cross-core alignment track still belongs to `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md`.

Evidence grades used throughout: **[V]** measured/executed · **[D]** derived, not observed ·
**[OPEN]** unknown. Never upgrade a grade without new evidence.

---

## THE GOAL (unchanged)

Run real ND-500/ND-5000 programs on the emulated CPU, driven by **REAL SINTRAN III on the emulated
ND-100**, with every MON call **FORWARDED over the bus/octobus**.

**A run where our C# `SintranEmulation` answers the MON calls DOES NOT COUNT.** Before believing any
"the program runs" claim, ask **WHO ANSWERED THE MON CALLS?**

The guard is mechanical and must stay: `EmulatedMonPathMarker.Count` must be **0**, and the harness
asserts it. `[V]` — the marker fires on a C#-layer test and is silent on every real run.

---

## WHERE WE ACTUALLY ARE

**CPU-STAT under real SINTRAN reaches its first genuine demand-page fault at its entry
(`pc=0x08000004`, `faultSeq=1`), with the swapper receiving real work orders.** `[V]`
That is further, in the only sense that counts, than anything before it — see the correction below.

### Fixed and verified

| # | Defect | Evidence | Commit |
|---|---|---|---|
| 1 | Swap-file type: pack's file is `:DATA`, monitor defaults to `:SWAP` | harness answers `swap-file:data` | harness-side |
| 2 | Boundary page faults carried `psn=0` (`SetMmuFault` skipped in 2 branches) | real swapper rejected it, Appendix-A 22B | `91f93e7ff` |
| 3 | Retryable traps resumed AFTER the faulting instruction | instruction trace | `f112300aa` |
| 4 | **A stop was answered on the WRONG process's mailbox message** | 78 vs 46 split, 2 lanes | **`3162853bf`** |

Defect 4 is the big one and its shape is worth keeping in mind for anything similar:
`ActiveProcessMessageAddress` was a **single global** claimed by whichever process started/restarted
last. All 124 MON 377B calls were made while process 0 was loaded; the 78 answered on the swapper's
own message succeeded, the 46 answered on the domain's message all failed with 1013B. `[V]`
Fix = one invariant, one helper, both answer sites: **a stop is answered on the RUNNING process's
own message**. Mirrors the microcode (one message per process, MESSBUFF, answered in place).

### The correction that matters most

**"It got further" is not progress if the state is corrupt.** `[V]` Before defect 4 was fixed,
CPU-STAT showed `faultSeq` up to 271 at deeper PCs and that read as progress. It was not: the
misrouted swapper call made SINTRAN write `K=1 / 0x20B` into the DOMAIN's message, and the bridge
applied it to the DOMAIN's registers (`ST.K := 1`, `I1 := 0x20B`). CPU-STAT was being restarted over
and over carrying another process's error code, stuck at one PC with the fault address marching
through a segment it had no business in. The discriminator — `K=1` — was in plain text on the restart
line and was missed twice.

---

## THE FRONTIER — the page-in loop

After the fix, the run ends in a repeating exchange on the domain's message:

```
MICFU=000B X5CPU=1 STOPR=0021 msgByte=0x00420E30
ANSWER N5STA=0003 MICFU=000B STOPR=0021 NUMPA=2400 MCNO=0800 TRAPN=0000 (understood)
```

- `MICFU=0x0B` = **13 OCTAL** = the block-copy function `[V]` (the servicer's own note calls 13B/14B
  "the swapper's image delivery").
- In the copy overlay the `MCNO` slot is **`NRBYT`**: `MCNO=0x0800` = **2048 bytes = exactly one
  ND-500 page** `[V]`. So SINTRAN is delivering one page.
- Only **one** trap was ever posted (`faultSeq=1`) `[V]`, yet the copy repeats with identical
  parameters.

~~**[D] Leading hypothesis: the copy completes but nothing restarts the domain**~~ — **REFUTED
2026-08-25** by the `nd500uc-47` lane, which ran the discriminating measurement (Phase 1.3) directly:

> cpu-stat faults once at `0x08000004`, `psn=11`, `PSTP=0x00035000`, entry at `0x00035016`,
> `raw=0x0000` — **and that entry never becomes non-zero.** `[V]`

**CORRECTED SAME DAY — my first reading of this was wrong.** I wrote that a zero entry "kills the
restart-missing hypothesis and proves the copy landed where the domain cannot see it". It does not.
`nd500uc-47` caught it: **writing PAGE CONTENT and writing the PST ENTRY are two different
operations.** A copy can land perfectly with the entry still unwritten; the entry could be written
while the content went astray. A zero entry says only **"no mapping was ever established"** — a
THIRD state, not evidence for either of the two hypotheses. Chalk this up beside the `0xD -> 6`
wrong turn: a measurement that eliminates nothing can still feel like a verdict.

**What IS decisive, and it is better than the original discriminator `[V]`:** the PST lives in ND-500
physical memory (`PSTP = 0x00035000`), and SINTRAN writes ND-500 memory via **14B ResidentWrite**. So
the PST update, if it happens at all, IS one of the RESIWR copies. The destination list therefore
settles it outright:

- a 14B copy targeting ~`0x35016` that leaves the entry zero → **our copy path drops or mis-addresses
  the write**;
- **no** 14B copy ever targeting the `0x35xxx` region → **SINTRAN never attempted the mapping**, and
  the question moves upstream to why the fault did not produce one.

Measurement caveat that already produced one wrong report: the 16 destinations visible so far were
all `0x0005xxxx` / `0x0006xxxx`, nowhere near `0x35000` — but that was the **first** 16 of a
CUMULATIVE log, capped at the head, which made every phase look identical and nearly produced a
"no page images after load-swapper" finding. The dump now prints the total and the LAST 16.

Related, from the same lane and worth knowing before touching the mapping code: `InstallSwapperMapping`
in `Nd500CpuProcessBridge` is latched (`_swapperMapped`, never reset) AND derives its regions from the
first two page tables in a cumulative `ResiwrLog` — so it can only ever run for the swapper. Extending
it to cpu-stat would special-case the swapper, which Ronny has ruled out. `[V]` reported, unfixed.

---

## PHASES

### PHASE 0 — Make the fix safe (do this before anything else)

The fix touched shared, bus-owned code that ~25 tests assert against, and **the regression suite has
not been run since**. Everything below is worthless if defect 4's fix broke something else.

- [x] **0.1 Run the full regression suite.** `[V]` RUN 2026-08-25, build exit code 0 asserted first.
      Result `Failed: 3, Passed: 2181, Skipped: 13, Total: 2197`, reproduced on a second run.
      After the 0.2 fix below: **`Failed: 2, Passed: 2182, Skipped: 13`**.
- [x] **0.2 Triage by MODEL, not by symptom.** `[V]` Done — the 3 failures were TWO different things:

      **(a) ONE WAS MY FIX, AND THE TEST WAS RIGHT** — `Nd500CpuM2RestartTests.`
      `Restart_ThenNextMonStop_AnswersTheRestartMessage`: `MSG24` came back `Waiting(2)` instead of
      `Answer(3)`. Root cause: `RememberProcessMessage` was called at exactly ONE site
      (`"start-taken"`), so the per-process map held the message a process was FIRST started on, for
      ever. But a process's message legitimately MOVES: `TakeRestartTail` makes the restart message
      "the process's new answer-in-place target". The map went stale and the next stop was answered
      on the old message, leaving the restart message unanswered.
      **Generic fix (not a hack):** fold the per-process recording into `SetActiveProcessMessage`,
      keyed on the message's own `X5CPU` field. EVERY site that moves a process's current message
      already funnels through there — `start-taken`, `restart-tail`, `announce-swapper-alive`,
      `mailbox-link` (the microword lane's `srf[ADR_MESS]`) — and `value == 0` ("cleared by the
      answer") deliberately does NOT erase the binding, since surviving that clear is the map's whole
      purpose. My own doc comment already stated the rule ("moves only when the context does"); the
      code only implemented half of it. **Test now green.**

      **(b) TWO ARE NOT MINE — and they look like a FRONTIER LEAD.** See 0.5.
- [x] **0.3 Tell the ND-500 lane.** `[V]` Done 2026-08-25 — and it turned out to be urgent for a
      reason I had not anticipated: **that lane has independently made the SAME message-routing fix**
      (their words: "52/52 MON 377B on the swapper's own message, all K=0, down from 48 failures").
      Two uncommitted copies of one fix in one file that also renormalises CRLF on staging is a
      merge accident waiting to happen, so they have been asked to diff against `3162853bf` before
      committing, and told about the stale-map half they may not have.

      **SHARED-TREE COST, measured.** That lane lost FOUR of its last five Gate5R runs to me: two
      builds blocked by a testhost my `dotnet test` left holding `Emulated.HW.dll`, one compile error
      from my multi-file edit caught HALF-SAVED (`Trap.cs` 08:57:17 referencing a field added to
      `MMU.cs` 08:57:30), and one crashed run racing my edits. Standing rules adopted: announce
      before a run, `dotnet build-server shutdown` + kill my testhosts after EVERY run, and warn
      before a multi-file edit. A ~9-minute boot harness destroyed by someone else's half-written
      file is the most expensive kind of collision — it looks like a defect in the machine.
- [ ] **0.4 Decide the branch question.** RetroCore's fix sits on `ethernet-ii-controller-fixes`,
      which is unrelated to ND-500 work. Ronny's call whether it moves. Nothing is pushed.

- [x] **0.5 The other two failures — RESOLVED, and a WRONG TURN worth keeping.** `[V]`

      `Nd500CpuT1TrapTests.PageFaultStop_CarriesMmsContextAndPsn_ClassicLayout` and
      `Nd500CommandShapedTests_ControlAndMonCall.Run_Command_TrapStop_AnswerRecord_WhatFprstartReads`
      both seeded `MmuFaultWhere = 0xD` and read back **6** at HW 0o22.

      **Real cause `[V]`: commit `3162853bf` — MINE — swept in a deliberate `0xD -> 6` translation**
      at the HW 0o22 write (`Nd500MicrocodeServicer.cs` ~2244), an "experiment" bundled alongside the
      message-selection fix. The tests were never updated for it.

      **Resolution, on Ronny's rule "align with what the microcode does":** the translation's
      DIRECTION is microcode-correct and carved. Classic writer `011316` writes
      `hw 22 := AM#27 = TRAPINF<<8 | subtype`, bit 6 = instruction side; the subtype constants come
      from the real CONT-STORE-10611 builder at `011140-011145` — data-side 6 / 7 / 10B,
      instruction +100B (and +100B IS bit 6). `[V]` And
      `CARVE-ANSWER-CLASSIC-TRAPWRITER-S2-CONTROL-2026-08-11.md` §2.5 lists this exact slot as a
      genuine **DIVERGE**: B30 puts a 32-bit MMS status at 0o22-0o23, classic puts one composed
      halfword at 0o22 and never writes 0o23. So the tests were asserting the B30 shape in a
      CLASSIC-layout slot. Updated to the carved shape; suite green.
      **Still `[D]`: WHICH of our `0xD/0xE/0xF` maps to which of `6/7/10B`** — the three builder
      words are adjacent and our kinds escalate in the same order, which is suggestive and nothing
      more. Settling it needs the classic 144-bit field definitions we do not have. The tests now pin
      the slot, the one-halfword width, the side bit and the code SET, and mark the mapping `[D]`.

      **WRONG TURN — DO NOT REPEAT.** I first "explained" the 6 as a live-latch clobber:
      `CpuND500.MMU.cs:767` latches `MM_IND_OTHER | MM_INST` = `0x46`, whose nibble is 6, so I
      concluded a walk during trap dispatch was overwriting the fault. I wrote a snapshot fix
      (`TrapMmuFaultWhere` in `RaiseTrap`, mirroring `P1`) across three files. **It was wrong and is
      fully reverted.** Two lessons, both already in Phase 5 and both violated anyway:
      1. `MM_IND_OTHER == 6` was a COINCIDENCE. A plausible mechanism that predicts the observed
         number is not evidence — I never checked what actually writes the slot. RULE #0b: the
         mechanism was found by reasoning about code I assumed was involved, not by reading the
         writer.
      2. I declared "NOT caused by `3162853bf`, verified two independent ways". Both "verifications"
         checked the BRIDGE (hunk offsets, and "selection cannot change a value") — and the change
         was in the SERVICER. **Two checks of the wrong file are not two independent verifications.**
         The one-line check that settles provenance is `git log -S '<the literal>' -- <file>`.

### PHASE 1 — Close the page-in loop (the current blocker)

Goal: the domain's entry page becomes present and CPU-STAT executes past `0x08000004`.

- [ ] **1.1 Read the loop in order, do not grep it.** Dump every message of ONE complete
      fault→copy→(expected restart) cycle, all fields, and say what each one is. RULE #0b: the thing
      that is missing is the thing a search cannot show.
- [ ] **1.2 Decode the 13B copy fully**: source, destination, `NRBYT`, and which address space each
      side is in. Log them — a repeated `PHYSWR` with no operands looks like a livelock and is not.
- [ ] **1.3 Answer the discriminating question: does the copied page ever become PRESENT?**
      Read the PST/page-table entry for the domain's segment before and after the copy. Present but
      no restart → hypothesis A (restart missing). Not present → hypothesis B (copy misplaced).
- [ ] **1.4 Check the restart path for the copy family.** 26B `3WMONCO` is the write-back+copy
      variant; confirm whether a 13B delivery is supposed to be followed by a restart of the FAULTING
      process, and whether we issue it. Grade the answer.

- [x] **1.6 Does SINTRAN branch on the composed subtype at 0o22? NO.** `[V]` from primary source.
      `TRAPDECODER` (`MP-P2-N500.NPL:855-895`, @`135320-135424`) touches exactly **TRAPN and
      `5RECE`** on the 46B arm: range-check, `X >< SWMSG`, receiver check against `5SWPROC`, then
      `MSWPFAULT SHZ 10 + D` stored back into TRAPN and `CALL 5ACTSWAPPER`. It never reads 0o17-0o21
      or 0o22 — not the LA, not the physical segment, not our composed halfword.
      **Consequence:** the `[D]` `0xD->6` mapping is NOT load-bearing for dispatch. Its only proven
      consumer is the ND-500 Monitor's human-readable stop dump (`MON-DEBUG:PROG`, the 200B stop-info
      block = verbatim copy of halfwords 12B..41B). A wrong mapping mis-names a fault in a debug
      print; it cannot make SINTRAN mis-handle the fault. Still `[OPEN]` whether the SWAPPER reads
      0o22 — all evidence says it works from the fault LA (ND-05.017.01:4803, "bits 26-11 from the
      logical address").

- [ ] **1.7 THE CURRENT BEST LEAD — MSWPFAULT does no paging.** `[V]` handler shape, `[D]` diagnosis.
      `swapper-k01-handlers.md` idx 10 == `MSWPFAULT` (entry `0x08008387`, worker `1000042045`):
      PROVEN to read a Table B descriptor, a Table A record and a Table D entry, check state fields
      (`getbf`, compares `0x15`/`0x16`), bump stats `[0x461134]`, and return **`0o2067` / `0o1030` /
      `0o1031` on bad state** — and its call-tree reaches **no paging primitive and no MON 377B**.
      *(That sentence is quoted as the carve doc ORIGINALLY read it. The `getbf`/stats/no-paging
      half is right; the compares and the error-code list are WRONG — see the corrections below.)*
      The real page-in lives in **idx 8** ("connect/page-in a segment", RPHS) and **idx 9**
      ("allocate+link a segment").
      **So "fault posted, swapper works, PST entry never written" is exactly what a correct idx-10
      run followed by NO idx-8/9 request looks like.** The question is not "why is our page-in
      broken" but "why is a page-in never REQUESTED after the notification". First check: log
      idx 10's return value — if it is one of those three error codes, cpu-stat's segment descriptor
      is in a state the swapper rejects, and the defect is upstream at PLACE time, with neither the
      copy path nor the trap record implicated.

      **CONFIRMED BY MEASUREMENT 2026-08-25 (`nd500uc-47`'s Gate5R run), and then SHARPENED by
      decoding the worker.** The predicted shape is exactly what the trace shows:
      `DISP@0x240B8=0x0A` (= idx 10) on one call, and `0o2067` (`0x437`) in the fn cell
      `[0x080240B0]` on the very next — notification dispatched, worker rejected, idx 8/9 never
      invoked, PST entry 11 still zero. Also settled: `PSTP=0x00035000` IS the right table
      (6 live entries, sane modes `0x40xx`/`0x016C`), so this was never a wrong-address bug.

      **Three things in `swapper-k01-handlers.md` idx 10 were WRONG and are now corrected in place
      (correction box in that file) — do not read the trace through the old text:**
      1. **`0x15`/`0x16` is the wrong RADIX.** The `.asm` `$` literals are OCTAL, so the compares are
         `0o15`/`0o16` = **decimal 13/14** (proof in the same worker: `w2 * $144` is the Table A
         stride the doc calls "0o144 = 100").
      2. **The polarity is backwards** — 13/14 are the **REJECTED** states; both compares branch
         AWAY from the error.
      3. **The three codes are not three states of one check.** In this worker `0o1030` has two
         sites (id-range + the 13/14 state test), `0o1031` is **never emitted at all**, and
         **`0o2067` comes from a completely different test.**

      **Therefore the 4-bit state field is NOT the suspect — drop it.** `0o2067` (site
      `1000042275`) fires only when ALL THREE hold: Table-A `+0o14` == 0, **and** Table-A `+5`
      bit `0x40` SET, **and** the request record's `+0o14` != `0o31`. (a)+(b) together are the
      signature of a **half-initialised Table A entry** — flagged in-use, `+0o14` never filled in.
      Note `0o2067` is emitted from **nine** sites PSEG-wide, so it identifies neither the handler
      nor the failure kind; only `DISP@0x240B8` identifies the handler.

      **NEXT MEASUREMENT (small, hands it straight to a cause):** for cpu-stat's segment id, dump
      the Table A entry at `0x08038000 + id*100` (decimal 100) and read the halfword at `+0o14`
      (+12 decimal) and byte `+5` bit `0x40`. Cheapest first: the request record's `+0o14` — if it
      equals `0o31` the whole check passes regardless, ruling the path out in one word.
      **WHO WRITES THE FIELDS — ANSWERED 2026-08-25, and it INVERTS the hypothesis.** `[V]` by
      sweeping every reference in the PSEG:
      - **`+0o14` is the swapper's own "linked" marker**, written by exactly one routine
        (`1000006650`), and only after a `call $1000026217` succeeds — an `ifkret` on that call
        returns early and leaves `+0o14` **zero**. That routine has three callers:
        **idx 9 (allocate+link, worker `1000046242`)**, idx 0 (free/finish), idx 15.
      - **`+5` is never written in this PSEG at all** — all 20 references are reads. Whoever
        builds the Table-A entry owns that flag byte, and it is outside the swapper domain.

      **RETRACTED — the "idx 9 never ran" conclusion was WRONG, killed by a full-run census.**
      `DISP=0x09` IS dispatched (4x), and `+0o14 = 0001` on entries 10/11/12 straight afterwards,
      so `1000006750` and `1000026217` are working. The field-ownership carve above stands; the
      diagnosis built on it does not. Equally retracted: the `0o2067`-comes-from-idx-10 reading —
      at `DISP=0x0A` every entry reads `+0o14 = 0001` and the fault's entry reads `+5 = 0x80`, so
      **both** conditions of site `1000042275` are false and it cannot be the emitter. The
      `+0o14 = 0000` samples that suggested otherwise are all at `DISP=0x18` and recover on the
      next sample — a construction transient.

      **THE REAL NARROWING — 8 remaining sites down to 4, and 3 of those share one guard.**
      Seven of the eight are the SAME id-range test (low `$7`, high `[$1000224124]`), differing
      only in where the id comes from. Mapped to handlers and intersected with the dispatch codes
      the run actually issues (`0x00`, `0x03`, `0x05`, `0x09`, `0x0A`, `0x18`):

      | site | handler | reachable in this run? | guard |
      |---|---|---|---|
      | `1000006170` | **idx 24** (`0x18`) create/define a segment descriptor | **YES** | id from request `+0o20`, range |
      | `1000006231` | **idx 24** (`0x18`) | **YES** | **distinct**: Table-A `+0o136 == 0` AND `+0o142 != 0` |
      | `1000053747` | **idx 0** (`0x00`) free/finish a segment slot | **YES** | id from `r.20`, range |
      | `1000052151` | **idx 1**, also a sub-call of idx 0's worker | **YES via idx 0** | id from `r.20`, range |
      | `1000035103` | idx 19 (`0x13`) | no | range |
      | `1000064576` | idx 21 (`0x15`) | no | range |
      | `1000065010` | idx 14 (`0x0E`) | no | range |
      | `1000065065` | idx 15 (`0x0F`) | no | range |

      **The error line itself reads `DISP=0x00`, which is idx 0's code** — though `0x00` is also
      what a cleared cell reads, so that is a pointer, not proof, and must not be treated as
      attribution (the same overreach as reading `0x0A` off the preceding restart).

      **NEXT MEASUREMENT — one log line settles three of the four:** record the id being passed
      and the bound `[$1000224124]`. In range ⇒ all three range guards are out and the only
      survivor is idx 24's `+0o136`/`+0o142` pair, which is then the thing to dump. Out of range ⇒
      the bug is whoever computed the segment id, and the fault path is entirely innocent.
      Still `[OPEN]`: who sets `+5` (never written in the swapper PSEG). Measured values differ per
      entry — `10:0x40, 11:0x80, 12:0x00` — so whoever writes it distinguishes these three
      segments, and our fault is against the `0x80` one. That is an ND-100-side carve.

- [ ] **1.8 ROOT CAUSE FOUND — we never write message offsets `0o7`/`0o10` (the N500A pair).**
      `[V]` by live PC probe (peer) + `[V]` classic-microcode carve (this session). **This
      supersedes 1.7's candidate list: the emitter is settled.**
      A frame probe armed on all nine `0o2067` emitters caught exactly ONE firing, twice:
      `PC=0x080057E7 = 1000053747`, idx 0's worker, operands `I1=0x0800` vs bound `I2=0x1E0`(480).
      `r.20` is message halfword `0o10` = **N500A_LO**, which the swapper range-checks as a segment
      number. Confirmed twice independently (probe operands + the spine dump): after `run` it holds
      `0x0800`; after `start-swapper` `0x0019`(25, in range); after `place-domain` `0x0000`(<7).
      **Every trap-record field we DO write is correct** (STOPR=2, MSWMC, TRAPN=0o46, LA, phys
      seg=11, MMS) — `AnswerTrapStop` covers `0o11..0o23` and never touches `0o7`/`0o10`.

      **The classic microcode DOES write them, and it is the FIRST thing it writes.** Carved from
      `E:\Dev\Ronny\ND500UC\docs\MC\CONT-STORE-10611.DATA` (8192 × 18-byte words):
      ```
      011271  A+B SARG=0o7 B,AM#12 D,AL#20 JSR 007540  ; MAR := message base + 7
      011272  SARG=0o2 D,AM#20        JSR 007550       ; halfword 2 -> offset 0o7
      011274  SARG=0o224 D,AM#25      JSR 011527       ; FETCH ND-500 mem [AM#23+0o224] -> AM#20
      011275  SARG=0o3 D,AL#25        JSR 007546       ; 32-bit write -> offset 0o10-0o11
      ```
      So `0o7` gets a literal `2`, and **`0o10` gets a value FETCHED from ND-500 memory at
      `AM#23 + 0o224`** — not a constant. Leaving it unwritten is why the swapper range-checks
      stale memory (`0x0800`) as a segment number.

      **The DMA convention, needed to read any microword-lane log** (`[V]` unless noted):
      `007540` = **set MAR** from `AL#20` (TAG `0o201` MOST + `0o001` LS — not a data write);
      `007546` = **32-bit** DMA write of `AM#20` (TAG `0o207` MOST, falls through into `007550`);
      `007550` = **16-bit** DMA write of `AM#20` (TAG `0o007` LS only); `007564` = the shared
      `W,IO` strobe + POPRET. TAG byte = bit 7 (`0o200`) MOST-half select | low 3 bits = TAG-OUT
      code (0 rMAR, 1 wMAR, 6 DMA read, 7 DMA write) — matches the independently carved TAG-OUT
      table, so the decode is cross-checked. **MAR auto-increments one ND-100 word per strobe**
      `[D]`: `011271` loads it once and ~15 writes follow with no reload; `011274`'s subroutine
      `011527` is a FETCH (`MEM,RD4` → `AM#20`, POPRET) and emits no writes, so the walk is clean.
      SARG values spot-checked against the RAW 18-byte words per the project rule (`011271` CS0 low
      half = `0x0007`; `007540` carries no SARG).

      **NEXT:** run the microword lane (it executes this exact writer) and log every DMA write with
      offset+value. Prediction to falsify: first two writes are offset `0o7` (16-bit, value 2) then
      `0o10` (32-bit, fetched). Then make `AnswerTrapStop` write the pair.
- [ ] **1.5 Fix, re-run, and state the result in terms of PROGRESS THAT IS NOT CORRUPT** — PC
      advancing, `K=0` on restarts, `EmulatedMonPathMarker.Count == 0`.

### PHASE 2 — CPU-STAT runs to completion

- [ ] **2.1 Get CPU-STAT to print its identity line** (`RUN marker index = 0`, `'CPU type'`), with
      the MON path assertion intact.
- [ ] **2.2 Verify WHO answered** — `MonPathReport()` shows real round-trips and zero C# answers.
- [ ] **2.3 Turn the run into a REGRESSION TEST** so this cannot silently rot. It must fail if the
      C# MON layer ever answers, and fail if progress stops short.

### PHASE 3 — Generalise beyond one program

One program working can be one program's accidents working.

- [ ] **3.1 LED-FORTRAN-A01 on the same path.** Note: this harness has been measured
      NON-DETERMINISTIC (15 vs 100,514 round-trips on identical runs) `[V]` — **do not draw
      single-run conclusions from it** until that is understood.
- [ ] **3.2 Root-cause the LED-FORTRAN non-determinism** before trusting any result from it.
- [ ] **3.3 A third program** (NC-A06 or LINKER-B01) to show the path is general.

### PHASE 4 — The microword/octobus lane

The real B30 microcode implements `TRAP_SWAP` itself, so demand paging comes for free on this lane —
and a page fault never crosses to the host, unlike the functional lane's four round trips per 2 KB
page `[V]`.

- [ ] **4.1 Get X5ACT delivered.** The microcode polled the activation cell **5,860,379 times** and
      never found it set `[V]`. Recorded fix direction: deterministic `5FPMAILBOX<<10 + X500DF`, NOT
      the `0xFFFF`→0 sniff.
- [ ] **4.2 Re-check the "stuck" claim honestly** — the idle loop (`IDLE → ATRAP_CHK → SCAN_ACCP →
      IDLE_1`) is CORRECT behaviour while waiting. A poll count alone does not separate "waiting
      properly" from "looping wrongly".
- [ ] **4.3 Run the same program on both lanes and diff**, using the microword lane as the oracle.

### PHASE 5 — Guardrails (cheap, prevents repeats)

Every item here comes from a wrong conclusion that actually happened this session.

- [ ] **5.1 Never read an OUT slot without the verdict.** `K` and the write-back decide; the
      parameter block is only data. A plausible value in an OUT slot looks identical whether SINTRAN
      filled it or nobody did. (Cost: five "successful" GSWSP calls that had all failed.)
- [ ] **5.2 Any diagnostic that reads process memory must name the MAPPED PROCESS** and be
      distrusted when that is not the process the address belongs to. `unmapped` is a HEALTHY
      outcome; a plausible number from the wrong process is the dangerous one. (Cost: the whole
      `0x437` cascade theory.)
- [ ] **5.3 A log field must name what ACTUALLY happened**, not a nearby global. (Cost: correctly
      routed calls looked misrouted — fixed in `3162853bf`.)
- [ ] **5.4 Advancing vs repeating** — an advancing address is progress, a repeating one is a hang,
      and identical endpoints at two different time limits rule out wall-clock only, never a budget
      or ring cap.
- [ ] **5.5 Check a `#if` before trusting a log's silence.** The MCNO line was behind
      `DEBUG_DETAIL`; a run would have "measured" nothing. "Did not happen" and "could not be
      observed" look identical.

---

## STANDING RULES FOR THIS TRACK

- **CARVE, DON'T GUESS** — get it from the source named in `GROUND-TRUTH.md`, or mark it `[OPEN]`.
- Microcode addresses are **OCTAL**; read ORCON/MARG/SARG/SCAL from the RAW `MICRO-5800-B30.DATA`
  word, never the rendered `.md` (it mis-renders the overlay).
- **Shared-tree hygiene**: stage only exact paths, never `git add -A`; verify
  `git diff --cached --name-only` before every commit. Both trees carry hundreds of other-session
  files (77 in RetroCore, 878 in ND5000UC as of this writing).
- **No new branches without written permission.** Commit on the checked-out branch.
- Status headings in this tree have lied before — **check the code before investigating anything
  marked open.**
