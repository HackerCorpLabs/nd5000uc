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

      > **CORRECTED 2026-08-25 — the claim below that the microcode writes `0o7`/`0o10` is WRONG.
      > The walk was off by two words because I never checked its BASE.** `AM#12` has exactly ONE
      > writer in all 8192 words, `007624`, and its context anchors it:
      > ```
      > 007622  A+B SARG=0o2 B,AL#20 D,AL#20  JSR 007540  ; AL#20 += 2 ; MAR := AL#20
      > 007623  ADIR SARG=0o2 D,AM#20        JSR 007550  ; halfword 2 -> that address
      > 007624  ADIR A,AL#20 D,AM#12         JSR 007544  ; AM#12 := AL#20
      > ```
      > `007623` writing a literal `2` IS the independently documented unconditional
      > `N5STA := WAITING(2)`, and `N5STA` is offset `2`. So **`AM#12` = message base + 2**, and
      > `011271`'s `base + AM#12 + 7` is **base + `0o11` = STOPR**, not `0o7`.
      >
      > Re-walked from `0o11`, every write lands on a field the carve table already names:
      > `0o11` STOPR=2 · `0o12-13` trapping P · `0o14-15` restart P · `0o16` TRAPN ·
      > `0o17-20` fault LA · `0o21` phys seg. **Six independent hits**; a walk off by two would
      > have collided with all six.
      >
      > **Consequences.** The trap writer's MAR STARTS at `0o11` and never touches `0o7`/`0o10` —
      > exactly the range `AnswerTrapStop` already covers. **Our trap-stop path is CORRECT AND
      > COMPLETE**, and "we never write N500A" is not a defect in it, because the real microcode
      > does not write it either. The microword-lane DMA log is NOT worth a boot: it would only
      > re-confirm `0o11..0o23`.
      >
      > The `[D]` on "one ND-100 word per strobe" SURVIVES and is upgraded — the six-offset
      > agreement requires it.
      >
      > **My error, recorded because it is a repeat shape:** I checked SARG values against the raw
      > 18-byte words (guarding the known rendered-listing trap) and then anchored the whole walk
      > on an unverified base register. Precision on one axis masked an unchecked assumption on
      > another. **A walk is only as good as its base — resolve the base register FIRST.**

      **~~The classic microcode DOES write them, and it is the FIRST thing it writes.~~** Carved from
      `E:\Dev\Ronny\ND500UC\docs\MC\CONT-STORE-10611.DATA` (8192 × 18-byte words):
      ```
      011271  A+B SARG=0o7 B,AM#12 D,AL#20 JSR 007540  ; MAR := message base + 7
      011272  SARG=0o2 D,AM#20        JSR 007550       ; halfword 2 -> offset 0o7
      011274  SARG=0o224 D,AM#25      JSR 011527       ; FETCH ND-500 mem [AM#23+0o224] -> AM#20
      011275  SARG=0o3 D,AL#25        JSR 007546       ; 32-bit write -> offset 0o10-0o11
      ```
      ~~So `0o7` gets a literal `2`, and `0o10` gets a value FETCHED from ND-500 memory at
      `AM#23 + 0o224`.~~ **WRONG — see the correction box above.** With `AM#12` = base+2 these are
      `0o11` (STOPR := 2) and `0o12-13` (trapping P, fetched). The fetch is real; the OFFSET was
      off by two. Nothing here writes `0o7`/`0o10`.

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

      ~~**NEXT:** run the microword lane and log every DMA write.~~ **CANCELLED** — it would only
      re-confirm `0o11..0o23`. Do not spend a boot on it.

      **THE REAL REMAINING QUESTION.** Neither the microcode nor our trap path writes `0o7`/`0o10`,
      yet the swapper range-checks `0o10` as a segment number on the page-fault path. **So who
      puts the segment number there?** The one untouched lead is **`5RECE`** — item 1.6 established
      that SINTRAN's `TRAPDECODER` 46B arm reads exactly two things, `TRAPN` and `5RECE`. Carve
      what `5RECE` is and who consumes it on the swapper-decode path, specifically whether anything
      derives the `0o7`/`0o10` pair from it or from the trap record's fault LA at `0o17-20`.
      That is the last unknown between here and a fix. → item **1.9**.

- [ ] **1.9 `5RECE` is a dead end — and `0o7`/`0o10` is `N500A`, a BLOCK-COPY parameter, not a
      segment number.** `[V]` from symbols + NPL source.
      - **`5RECE = 000004`** — message offset 4, the RECEIVER (`SENDE=3` is the sender; offset 4 is
        what the other table calls `X5CPU`). `MP-P2-N500.NPL:437` writes both
        (`5SWPROC; *SENDE@3 STATX; 5RECE@3 STATX`); `TRAPDECODER` @135354 reads it and compares
        against `5SWPROC`. **Nothing derives `0o7`/`0o10` from it.**
      - **`N500A = 000007`**, always `LDDTX`/`STDTX` (DOUBLE) — hence the `0o7`/`0o10` pair.
        `MP-P2-N500.NPL:1705` names it: **`% ND-500 LOGICAL DATA ADDR`**, paired with `N100A`
        (`% ND-100 PHYSICAL ADDR`) and `NRBYT`. It is the block-copy parameter triple.
      - **SINTRAN writes it into the swapper's OWN message under a save/restore bracket.**
        `LDATREADY` @136341 borrows `SWMSG` for a data-memory read: saves into `SWDD1/2/3`
        (136364-136367), writes `N500A` @136404 ("Prepare data-memory read message"), `N100A`
        @136406, `NRBYT := 0o400` @136411, `MICFU := 3RMED` @136422 — then `INLDATREADY` @136431
        restores at 136461-136470 ("Rebuild swmsg message").

      **So the message legitimately holds a leftover COPY ADDRESS at `0o7`/`0o10` during that
      window.** `0x0800` has the shape of an address or length, not a segment id.

      **HYPOTHESIS (not measured):** the swapper is reading the message inside the borrow window,
      or after a restore that never ran. Two checks answerable from EXISTING logs, no boot needed:
      (1) does a `3RMED` MICFU appear on `SWMSG` near the failure? (2) is `INLDATREADY` reached at
      all — 136446 gates on `IF A=SWPPING`, and if that fails `SSWPFREE` is taken instead.

      **Do NOT change the trap record.** Two independent supports now say it is correct and
      complete: the corrected offset walk, and `N500A` being a copy parameter a trap answer has no
      business writing.

- [ ] **1.10 THE ANSWER WAS ALREADY CARVED ON 2026-07-21 — and the peer's MICFU census is the
      measurement it was missing.** `[V]`
      See `E:\Dev\Ronny\NDInsight\SINTRAN\ND500\CARVE-MSWIN-MESSAGE-SENDER-2026-07-21.md`.
      - **The overlay, from symbols:** `SWFUN=000007`, `SWRST=000010`. Same two words as `N500A`;
        which name applies depends on the arm.
      - **SINTRAN writes `0o10` in exactly ONE place**, `SWPDECODER`/`LNEWSWAP`,
        `MP-P2-N500.NPL:975-976`: `*AAX RETP4+1; LDATX` then `X:=CSWPM; *AAX 10; STATX` — gated on
        `MICFU==3SWMESS` **and** `SWFUN ∈ {MSCRS, MSCRENEWVERS}`. `SWRST`'s only other NPL
        reference is a read (`LDATX` @134130).
      - **`3SWME = 000005`, and the peer's whole-boot MICFU census has ZERO occurrences of 5.**
        So that arm never runs, and the only NPL writer of `0o10` never executes.
      - **The carve doc establishes `[V]`** (full-tree grep of every ND-100 NPL file + the complete
        `s3vs-4.symb` build): `SWFUN` is only ever LOADED, never STORED, and `MICFU := 3SWMESS` is
        never written by any ND-100 routine in the tree. The code that stamps `MICFU := 3SWMESS`,
        fills `SWFUN` and writes the ~15-word body is **`S3SM5`** — ND-100 code (per that doc's own
        2026-07-21 correction banner), MSWIN builder at runtime octal **140771..141001**, full body
        builder at **162155..162207**. **Its source is NOT in the repo** (paged segment, carved as
        bytes only) — which is why an earlier grep recorded a scope-limited negative as a true
        absence.
      - That doc's item 4 already concluded, graded `[I]`: *"the fill step is not skippable by any
        ND-100 code — it simply belongs to a sender that did not run."* **The MICFU=5 zero upgrades
        that `[I]` to measured.**

      **CAVEAT TO SETTLE FIRST — two readings predict the same garbage but DIFFERENT fixes.** The
      overlay depends on WHICH message the worker's `b.24` points at. If it is the swapper's own
      `SWMSG`, the field is `SWRST` and it is empty because `S3SM5` never stamped it. If it is the
      trap-answer message, it is `N500A` holding a stale copy parameter. Pin the message identity
      before acting on either.

      **RESOLVED — it is the TRAP-ANSWER message, so 1.10 is REAL BUT OFF-PATH.** Proven at
      content level, not just address: the work block's header reads `X5CPU/5RECE = 0001` (the
      DOMAIN, cpu-stat; the swapper's own is `X5CPU=0` at `0x00420D30`), `MICFU=0015` (3TRACO),
      and `hw12/13 = 0800/0004` = the trapping P **our** `AnswerTrapStop` wrote. So it is the
      `N500A` arm. `S3SM5`'s MSWIN builder is NOT the missing sender here — **do not spend a
      disassembly on `140771..141001`.** The MICFU=5 zero stays as a valid measurement about a
      different message.

- [ ] **1.11 SINTRAN NEVER CHOOSES fn 0 — fn 0 is what a MISSING `TRAPN` PACK LOOKS LIKE.** `[V]`
      `5ACTSWAPPER` (`MP-P2-N500.NPL:2875-2883`) computes the swapper's work reason:
      ```
      145040  IF 3SWMESS=D THEN *SWFUN@3 LDATX     ; swapper-message arm -> SWFUN (0o7)
      145044  ELSE
      145045     *AAX TRAPN; LDATX                 ; TRAP arm -> TRAPN (0o16)
      145047     A=:D/\377; *STATX                 ; TRAPN := LOW BYTE ONLY
      145052     A:=D SHZ -10                      ; A := packed >> 8  = THE MSW CODE
      145054  FI ; X:=SWMSG; *AAX SWPST; STATX     ; SWMSG.SWPST := A
      ```
      **`SWPST` = high byte of `TRAPN`**, and `MSWFI = 000000` is precisely a zero high byte. The
      measured `SWPST=0x0000` is an ABSENCE, not a selection.
      **Every legitimate caller packs it first** — two independent instances of one idiom:
      `TRAPDECODER` @135361 `MSWPFAULT SHZ 10 + D`, and `SWMC` @141753
      `MSM510 SHZ 10 =: D; A/\377 + D`.

      **A GATE IN `TRAPDECODER` MISSING FROM ITEM 1.6's SUMMARY** (`MP-P2-N500.NPL:871-874`):
      `IF 5INITFLAG BIT BRESPLACE OR SYSINITFLAG NBIT BSWSTARTED THEN CALL 5RRTWT; GO NXTMSG` —
      restarts the ND-100 process and leaves, **no pack and no `5ACTSWAPPER`**. `BRESPLACE` is
      cleared in `RELCPU` (`5P-P2-MON60.NPL:727`).

      **The MSW code is CONSUMED DESTRUCTIVELY** (145047 writes back the low byte only), so a
      message served twice yields fn 0 on the second activation. The strip sits inside the
      `IF A=PSWWAIT` (swapper free) branch, so the swap-wait-FIFO path does NOT strip — the design
      is self-consistent; this is a re-activation hazard, not a SINTRAN defect.

      **THREE CANDIDATES, all predicting `SWPST=0` — settle by measurement, not plausibility:**
      (a) the 135342 early-out fired → **dump `BRESPLACE` and `BSWSTARTED` at the fault**;
      (b) the message reached `5ACTSWAPPER` twice → **count activations of that message**;
      (c) something on our side activates without packing (call sites: 510, 879, 1052, 2050 —
      only 879 and 2050 pack; 1052 relies on the pack surviving the queue).

      **CANDIDATE (a) REFUTED BY MEASUREMENT 2026-08-25.** The run-phase `SWPST` sequence shows
      `0x000A` at #15 — a value only producible by a `TRAPN` whose high byte held `10 = MSWPFAULT`.
      So the pack DID happen and `TRAPDECODER` did NOT take the 135342 early-out. **`BRESPLACE` and
      `BSWSTARTED` are innocent — do not spend a run on them.** (`TRAPN=0x0026` at the fault is
      consistent with BOTH "never packed" and "packed then stripped", so `TRAPN` alone cannot
      separate them; `SWPST` is what does.)

      **TWO CARVE FACTS THAT CLOSE MOST OF THE REST:**
      1. **`SWPST` has EXACTLY ONE WRITER in the whole NPL tree** — `MP-P2-N500.NPL:2883` (145054)
         in `5ACTSWAPPER`; one reader, `:952` (135544) in `LNEWSWAP`. **Nothing zeroes it.** So the
         failing `SWPST=0x0000` was *written* by a real `5ACTSWAPPER` call that computed zero — not
         a clear, not a leftover.
      2. **The swap-wait FIFO drain at 136037 is INSIDE `LNEWSWAP`** (135470..136472, no
         intervening `SUBR`) and **does not pack** — it advances the fetch pointer (`X5SWH`,
         `NHENT`) and calls `5ACTSWAPPER` on the dequeued message. The queue is filled by
         `5ACTSWAPPER`'s own ELSE branch (145111-145144) when the swapper is busy. **The failing
         line carries `SWPFU=0001` = `LNEWSWAP`** — the arm holding the only unpacked call site.

      **"THE REASON COMES BACK" IS NOT RE-PACKING — IT IS DIFFERENT MESSAGES.** `SWPST` lives in
      **`SWMSG`** (one shared cell); `TRAPN` lives in each **requester's** message. The `SWPST`
      column is a sequence of *different requesters* through one slot, which is why `0x0A` appears
      at #15 and again at #23. Independent confirmation that `SWPST` is the reason channel: the
      `SWPST` column **leads** `DISP` by one line throughout (#17→#18, #21→#22, #23→#24).

      **THE READING THAT FITS EVERYTHING:** fault → `TRAPDECODER` packs `TRAPN = 0x0A26` → served
      (#15 `SWPST=0x0A`) → 145047 strips `TRAPN` to `0x0026` → block re-activated via the
      **unpacked** drain at 136037 → trap arm reads high byte 0 → `SWPST := 0` → idx 0 (`MSWFI`)
      dispatched → reads the stale `0o10` → `0o2067`.

      **THE REMAINING GAP, STATED PLAINLY:** why is an already-*served* block sitting on the
      swap-wait FIFO at all? The queue fills only when the swapper was busy at activation time.
      **One countable check:** how many times does that block reach `5ACTSWAPPER`, and does it ever
      pass through 145111-145144 (the FIFO insert) *after* being served? If so, that is the defect
      and it is upstream of everything else.
      **Do NOT "fix" 145047 to stop stripping, nor make the drain re-pack** — both paper over the
      step without explaining the queueing, and one changes real SINTRAN behaviour. (Ronny's
      standing rule: the CPU must behave identically for all programs, or it is an ape hack.)

      **THE DRAIN IS GUARDED — a stale FIFO entry ALONE cannot cause this.** Full loop,
      `MP-P2-N500.NPL:1031-1059`:
      ```
      135747  SWPD4: PSWWAIT; X:=SWMSG; CALL WN5STATUS  ; mark swapper free
      135764  WHILE A><D                                ; X5SWH != X5SWF, entries present
      136015     IF A/\160000><0 GO EMPTY               ; power-fail bits -> refuse, pointer NOT advanced
      136017     *AAX X5SWH ; NHENT; *STATX             ; CONSUME entry (advance fetch ptr)
      136027     IF A=SWPWAIT THEN ... CALL 5ACTSWAPPER ; the unpacked activation
      136047  OD                                        ; not SWPWAIT -> entry dropped, next
      ```
      `SWPWAIT` is stamped only by `5ACTSWAPPER`'s entry (144775); a **served** message is moved to
      `SWPPING` (145022). So an already-served block reads `SWPPING` at the drain and is **skipped,
      not activated**.

      **SHARPER PREDICTION for the per-call `TRAPN` trace:** the failing activation requires our
      block to reach `5ACTSWAPPER` a **second time AND be re-stamped `SWPWAIT`** — not merely to
      leave a stale FIFO slot. If the trace shows the failing activation with **no** second
      `SWPWAIT` stamp, the drain is NOT the route and the step-3 reading is wrong.

      **MEASURED 2026-08-25 — STATE CONSTANTS PINNED, AND TWO OF MY CLAIMS CORRECTED.**
      - **`SWPWA(SWPWAIT) = 5`, `SWPPI(SWPPING) = 6`, `PSWWA(PSWWAIT) = 7`, `PSW1W = 0o15`,
        `SWACT(SWACTIVE) = 0`.** (ND symbols truncate to 5 chars — full spellings miss in greps.)
      - **The `LSWPWAIT=4` / `5ERANSWER=4` overlay collision is NOT REAL.**
        `LIDLE/LSWPWAIT/LSWPPING/...` (`MP-P2-N500.NPL:211-216`) are `SYMBOL`s **local to
        `500HIST`**, a Level-2 histogram routine — performance-sampling bucket indices (all even),
        **not** `N5STA` values. SWPWAIT is **5**; the mailbox arm tops out at 4, so 5/6/7 collide
        with nothing. `swapper-k01-handlers.md` already warns against this exact conflation.
      - **`PSWWAIT=7` is the most informative number in the trace.** It is written in ONE place —
        `135747 SWPD4: ... % Mark swapper free` — and SWPD4 is **immediately followed by the drain
        loop**. So the swapper message flipping `0002 → 0007` at the failure is **direct evidence
        the drain loop ran**, which had only been inferred.
      - **BUT STEP 3 DOES NOT SURVIVE.** At the failure our block reads `N5STA=0002`, not
        `SWPWA=5`, so the `136027 IF A=SWPWAIT` guard would **skip** it. The drain ran; it did not
        activate *our* block. Not reshaping the story to fit.
      - **CORRECTION TO "SWPST HAS EXACTLY ONE WRITER":** true **of the NPL tree only** — I should
        have stated the scope (same shape as the July doc's scope-limited negative). `LNEWSWAP`
        @135544 reads it as *"Error-answer from swapper?"*, so **the ND-500 swapper writes `SWPST`
        too**. The cell is **bidirectional**: SINTRAN writes the activation reason, the swapper
        writes back a status. So `SWPST=0000` at the failure has two readings — a zero reason, or
        the swapper writing `0 = no error` alongside its `SWPFU=0001` request for work. **Given
        `SWPFU=1` is the swapper asking for work, the second is at least as likely**, and it would
        mean `SWPST=0` is not evidence of a missing pack at all.

      **WHAT SINTRAN CAN EVEN WRITE INTO `SWPST` — EXACTLY TWO VALUES.** `[V]` The whole NPL tree
      contains **three** `MSW*` uses and only **one** is a pack: `:431 IF A=MSWSTART` (test),
      `:464 IF A=MSWSWAIT` (test), `:877 MSWPFAULT SHZ 10+D` (**the only pack**), plus `SWMC`
      @141753 packing `MSM510`. So on the trap arm — the only live arm — SINTRAN can produce
      **`0x0A` (`MSWPF=0o12`) or `0x17` (`MSM51=0o27`)**, and nothing else.
      (Unpacked constants for reference: `MSWFI=0`, `MSWST=0o7`, `MSWIN=0o5`, `MSWSW=0o24`,
      `MSWDO=0o34`.)

      **MEASURED COLUMN vs THAT CONSTRAINT — three of six values have NO SINTRAN producer:**
      `0x0A` ✓ possible · **`0x18`(0o30) ✗** · **`0x09`(0o11) ✗** · **`0x0B`(0o13) ✗** ·
      `0x00` ✗ except as a missing pack. **So the swapper demonstrably writes `SWPST`** — the
      bidirectionality is settled by the values alone, without needing the thread id, and my
      earlier "one writer" was wrong more broadly than first admitted: most of that column is not
      SINTRAN at all.

      **THE FORK IS STILL OPEN AND THE VALUES CANNOT CLOSE IT** — both sides can legitimately
      produce zero:
      - swapper-authored `0` = "no error" (`LNEWSWAP` @135550: `IF A><0 THEN % Error-answer from
        swapper?`) → **benign, and the missing-pack theory dies**;
      - SINTRAN-authored `0` → **can only be a missing pack**, since `MSWFI` is never deliberately
        packed.
      **The thread id on that single write is the whole answer.** SINTRAN's thread ⇒ real defect.
      Swapper's thread ⇒ **items 1.11 onward collapse and should be struck.**

      *Caveat on my own claim:* "MICFU=3SWMESS never occurs" rests on a census sampled at MON 377B
      calls; a transient 3SWMESS between calls would let that arm write `SWFUN` values like
      `0o30`/`0o11`/`0o13` and weaken the "not producible" list. MICFU (offset 6) is inside the
      watch window, so this is checkable in the same run rather than assumed.

      **THE WRITE-WATCH ALREADY EXISTS — DO NOT BUILD ONE.** `MpmAccessTrace` + `TracingRam` are
      hooked at the single backing store, so they see ND-100 CPU writes and our servicer's writes
      alike, recording per entry: seq, R/W, physical byte address, value, width, **PC**, **thread
      id**, I/D space. The boot test already arms it (`MpmTrace.SetCapacity(8192)`,
      `CaptureReads=false`, `EnableWindow(...)`) behind `ND500UC_WATCH_MON422=1` — a gate that
      simply was not set. The **thread id** is what separates SINTRAN's ND-100 writes from our
      servicer's, i.e. it answers the `SWPST` reason-vs-status fork directly.

      **WINDOW GEOMETRY — GET THIS RIGHT OR THE RUN PROVES NOTHING.** `SWPST` is **NOT in the
      requester's block**: it is word offset `0o103` in **`SWMSG`**, written as
      `X:=SWMSG; *AAX SWPST; STATX` (145054). Same for `SWPFU=0o101`, `HSWPI=0o104`,
      `SWPIN=0o105`, and the `PSWWAIT` write at `SWPD4`. A window of `0x00420E30 +256` covers
      **our block only** and would see **zero** `SWPST` writes — a scope-limited negative, not a
      result. **Use base `0x00420D30`, length 512**: the two blocks are exactly `0x100` apart, so
      that spans `SWMSG` (`0xD30..0xE2F`) and the requester block (`0xE30..0xF2F`) contiguously,
      with every field well inside (`SWPIN=0o105` = byte 138).
      Covered by our block alone: the `TRAPN` pack (`0o16`), the `SWPWA=5` stamp, the `N5STA`
      transitions. Needs the widened window: the `SWPST` write's PC/thread, the `PSWWAIT=7` write
      at `SWPD4` (turning the drain-loop timing from inference into a PC), and the `SWPFU`
      handshake (`SWACTIVE=0` from SINTRAN @145011 vs `1` from the swapper).

      ~~**NEXT INSTRUMENT: a WRITE-WATCH, not a sample.**~~ (superseded — it exists; see above) A read-based sample at ND-500 call
      boundaries cannot see the pack→strip transition (both happen inside one ND-100 activation
      with no ND-500 call between), and cannot tell which side wrote a cell. Record ND-100 **writes**
      to `TRAPN`, `N5STA` **and `SWPST`** with the writing PC — `SWPST` needs it as much as the
      others, because the reason/status duality is invisible to any read.

      **ALSO CAPTURE: the queued message's RAW, UNMASKED `N5STA`.** Two guards disagree about the
      high bits — `136015` refuses to serve if any of `0o160000` is set (and does **not** advance
      the pointer, so that entry blocks the queue head indefinitely), while `135575` in `LNEWSWAP`
      does `IF A/\17777=SWPPING`, i.e. real SINTRAN *expects* power bits and masks them off. Stray
      high bits from our side would trip `136015` while looking correct to any masked dump.

      **THIS RETIRES THE STALE-`0o10` QUESTION AS PRIMARY.** With the reason packed correctly the
      swapper runs idx 10, which reaches no paging primitive and no MON 377B anyway — consistent
      with zero pages copied. The stale id is what idx 0 reads because **idx 0 should never have
      been dispatched**. Fix the reason and the id stops mattering; fix the id and the handler is
      still wrong.
- [x] **1.13 STRUCK: the missing-pack / zero-reason line (1.11 and its predecessors) is DEAD.**
      `[V]` by write-trail with thread attribution, 606 writes, nothing lost from the ring.
      ```
      TRAPN @0x420E4C  #138/139 [T17] -> 0x0026   our AnswerTrapStop
                       #150/151 [T16] -> 0x0A26   THE PACK, observed directly
                       #164/165 [T16] -> 0x0026   THE STRIP (145047)
      SWPST @0x420DB6  #166/167 [T16] -> 0x000A   SINTRAN writes MSWPFAULT. CORRECT.
                       #398/399 [T17] -> 0x0000   THE ZERO — T17 = THE SWAPPER
      ```
      **SINTRAN packs correctly, strips correctly, and dispatches correctly.** The zero is the
      swapper writing "no error", exactly as `LNEWSWAP` @135550 reads it. **My benign reading was
      right and the missing-pack reading — which I wrote into this plan — is struck, not softened.**
      Bonus: strip (#164/165) precedes reason-store (#166/167), confirming 145047-before-145054
      **instruction-for-instruction by independent measurement.**

- [x] **1.14 STRUCK: `LNEWSWAP` does NOT turn `SWPST` into a work item.** `[V]`
      135544 reads it, then 135550 branches: nonzero → `D=:A % Swpstat, error code` →
      `EMONICO` / `SWPD1`→`SWPD2` (@135717 `A=:SSTAT ... SSTAT; CALL WN5STATUS % Restart nd-100
      proc with error code`); zero → the "Ok answer from the swapper" branch. **Consumed only as a
      status/error code — it never becomes a function code and never reaches the sub-fn-1 OUT
      cell.**

- [ ] **1.15 THE REAL ANOMALY: SINTRAN WROTE `SWPST` EXACTLY ONCE IN 606 WRITES.** `[V]`
      The reason IS delivered through `SWPST` (5ACTSWAPPER @145054) but **only inside the
      `IF A=PSWWAIT` (swapper-free) branch** — the ELSE queues and writes nothing. By thread, the
      column is `#166 [T16] 0x0A` and then **T17 for everything after**. So at the failing
      activation there was never a fresh reason: the cell still held the **swapper's own stale
      `0`** from #398, and `0 = MSWFI = idx 0`. The two directions collide in one cell — but the
      cause is **SINTRAN never writing a second reason**, not `LNEWSWAP` feeding one back.

      **EXACT, COUNTABLE NEXT CHECK (both blocks already in the window):**
      - count T16 writes of `SWACTIVE=0` to `SWPFU` (145011) — one per **serve**; should pair 1:1
        with `SWPST` reason writes;
      - count T16 writes of `PSWWAIT=7` to SWMSG status — one per `SWPD4`, i.e. per completed
        service cycle + drain;
      - **serves = 1 but SWPD4s > 1 ⇒ the swapper completed work it was never freshly dispatched
        for, and that gap is the defect.**

      `[D]` **not** `[V]`: 145057-145062 set `NUMPA:=6`, `FUNCV:=0` with the comment *"Par #2 &
      par #3 will be written into"*, then `MICFU:=3MONCO; CALL MCCO`. Reading "par #2/#3" as the
      OUT fn cell `0x240B0` / message address `0x240B4` would make **`MCCO`** the writer of the fn
      cell. **`MCCO` is NOT carved** — next target if this thread is pulled.

- [ ] **1.16 THE STRONGEST LEAD OF THE DAY — and it is the project's central question.**
      `[V]` on the mechanism; `[HYPOTHESIS]` on our involvement.
      - **`NUMPA` is the MONITOR-CALL WRITE-BACK MASK** — named so in four independent places
        (`MP-P2-N500.NPL:1901,1904,3706`, `XC-P2-N500.NPL:18`). A **bitmask, not a count**. So
        `NUMPA:=6` = bits 1|2 = write back params **#2 and #3**, matching 5ACTSWAPPER's comment
        *"Par #2 & par #3 will be written into"* and the measured OUT cells (fn code `@0x240B0`,
        message address `@0x240B4`).
      - **The two answer paths set OPPOSITE masks:** `5ACTSWAPPER` @145057 `A:=6` → params written;
        `MONICO` @023020 `STZTX` → **`NUMPA:=0`, nothing written**. (`OKMONICO`/`EMONICO` both fall
        into `MONICO`. `MCCO` itself only stamps `H500A:=140300`, `N5STA:=MSGN500`, and marks the
        ND-100 process active — **it delivers no parameters**.)
      - **Neither `FUNCV` nor `KFLIP` discriminates** — both paths leave `FUNCV=0`, `KFLIP=0`. **The
        ONLY difference between "here is work" and "no work" is whether the fn cell was written.**
      - **The empty-queue path DOES NOT ANSWER AT ALL.** `LNEWSWAP`'s drain falls out of `OD`
        (136047) into `EMPTY` (136050): zero `X5SWO`, zero `HSWPI`/`SWPIN`, `SUNLOCK`, `GO NXTMSG`.
        **No `MONICO`, no `OKMONICO`, no `MCCO`.** The swapper's `LNEWSWAP` is left **unanswered**
        and blocks until `5ACTSWAPPER` serves it with real work.

      **CONSEQUENCE:** a swapper that *receives an answer* to `LNEWSWAP` without a fn write-back
      acts on **whatever its fn cell already held**. That is exactly the observed failure — one
      dispatch (idx 10), then later cycles with no fresh fn code.
      **⇒ WHO ANSWERED THAT LAST MON 377B?** If real SINTRAN took the `EMPTY` path it did not
      answer, so any completion the swapper saw came from our side — **the project's top rule,
      hit head-on.** Checkable in the existing trail: an answer with **no preceding T16 write of
      `NUMPA`/fn**, or an `N5STA:=MSGN500` / `3MONCO` stamp no T16 code produced.

- [x] **1.18 MEASURED: the write-back masks behave EXACTLY as carved — and our side did NOT answer.**
      `NUMPA @0x420D44` T16 writes: `#168 = 6` (5ACTSWAPPER, params 2&3 → **fresh fn code**, the
      idx-10 dispatch), `#272 = 0`, `#362 = 0` (MONICO, nothing written). `MICFU` T16 stamps pair
      up 1:1: `(#176 3MONCO, #192 3START)`, `(#274, #282)`, `(#364, #372)`. **Three answers, three
      restart stamps, three mask writes.**
      **My `[HYPOTHESIS]` that our side answered is REFUTED — all of it is T16 (real SINTRAN).**
      *Attribution caveat, stated by the peer and adopted:* T17 is the ND-500 side, which is **both**
      the real swapper **and** our servicer, so thread alone does not separate them. Checked, not
      assumed: our code writes `SWPST`/`SWPFU` **nowhere** (only a comment at
      `Nd500MicrocodeServicer.cs:277` saying nothing here ever writes that word).

- [x] **1.19 STEP 5 IS LEGITIMATE — the zero-mask answers are disc-transfer completions.** `[V]`
      They come from **`5RDTRANSFER` @136245** (*"Return after disc-transfer"*):
      `136261 X:=SWMSG; CALL OKMONICO % Transfer ok` / `136264 ... EMONICO % Error in transfer`.
      That completes the swapper's own `LSWPAGE` (SWPFU=2) requests — #210 and #300. Answering
      "your transfer finished" with a **zero** write-back mask is correct: no work is being handed
      over, so no fn code should be written. **The fn cell is not supposed to change there.**
      (`SSWPFREE`, the other `X:=SWMSG; CALL OKMONICO`, is reachable only from `LDATREADY`
      (SWPFU=5) @136354 or by fall-through from `INLDATREADY`; SWPFU never shows 5, so that path
      did not run.)

- [ ] **1.20 THE END OF THE TRAIL: SINTRAN NEVER RESTARTED THE SWAPPER, AND IT RAN ANYWAY.**
      After `#372` there is **not one further T16 `MICFU` stamp and not one further T16 `NUMPA`
      write.** Yet:
      ```
      #390 [T17] SWPFU=0x0001   swapper asks LNEWSWAP   (last SINTRAN answer was #362/#372)
      #428 [T16] status=0x0007  PSWWAIT -> SWPD4: mark free, drain...
                                ...drain finds nothing -> EMPTY @136050 -> NO answer, no stamp
      #452 [T17] SWPFU=0x0001   the swapper asks AGAIN
      #460 [T17] SWPST=0x0437   reports 0o2067
      ```
      On the real machine that `LNEWSWAP` should have stayed **outstanding** and the swapper should
      have **blocked** until a genuine dispatch arrived. Instead it resumed with a stale fn cell and
      dispatched idx 0.
      **⇒ The "who answered" question survives in a SHARPER form: not who wrote `SWPST`, but WHO
      RESUMED THE ND-500.** Candidate: **`#416/417 [T17] N5STA := 0x0003 (ANSWER)` on SWMSG**,
      sitting between the unanswered request (#390) and the swapper running again (#452). Resuming
      the swapper needs neither `SWPST` nor `SWPFU` — it needs `N5STA` and the activate path, which
      **our servicer does drive**.
      **FREE CHECK (no new window):** in the span #390→#452, is SINTRAN's *only* action the
      `PSWWAIT` at #428? If so, whatever set `N5STA:=ANSWER` at #416 was not SINTRAN.
      ~~`[HYPOTHESIS]` that #416 is our servicer~~ — **REFUTED.** `#416` is the ND-500 **posting its
      own call** (`N5STA:=ANSWER` is the ND-500→ND-100 direction, "I stopped, here is my record")
      and it *precedes* SINTRAN's processing at #418. Also refuted: `OnMonitorCallRestart` — it
      requires a 3MONCO **and** `(stopMode & WAIT) != 0`, so it ran exactly the three times SINTRAN
      stamped and cannot account for cycle 4.

      **THE SPAN, MEASURED, CONFIRMS THE `EMPTY` CARVE INSTRUCTION-FOR-INSTRUCTION:**
      `#428/429` SWMSG status := `0x0007` (PSWWAIT — `SWPD4`), then `#430-#433` **SWMSG `HSWPI:=0`,
      `SWPIN:=0`** — the `STZTX` pair at 136057-136062, and **nothing else in the tree writes that
      pair**. SINTRAN took `EMPTY` and did **not** answer. No `MSGN500`, no `3MONCO`, no `3START`
      anywhere after `#372`.
      **Tally: 3 SINTRAN restart stamps vs 4 swapper run cycles.**

- [ ] **1.21 THE MICROCODE PARK CONTRACT — what cycle 4 violated.** `[V]` from the decoded B30
      (`microcode\MAILBOX-MICROCODE-PSEUDOCODE.md`). Every handler ends at **`MSG_END` @017412**:
      ```
      017417-20  mem_hw[msg+0] = answer          ; N5STA := 3 (ANSWER)
      017421     GIVEINT(0o100401)               ; notify the ND-100
      017422-23  if ((int32)srf[SRF11] < 0) CNTXTSAVE();   <- THE PARK, AND IT IS CONDITIONAL
      017425-26  srf[ADR_MSGME] = 0              ; "message no longer in progress"
      017430-32  if (srf[ADR_PROC0] == 0)
      017433-35     ... IDLE()                   ; nothing runnable -> back to idle
      017436-43  else MSG_NEXTL()                ; service the NEXT CHAINED message
      ```
      **After a MON-call stop the microcode goes IDLE or moves to a DIFFERENT chained message — it
      NEVER continues the stopped process.** The only route back is a fresh activation carrying
      **3MONCO** (`MSG_CONMC`), delivering `FUNCV→X1` (015721) and `KFLIP→K` (015727/015731).
      **So 3 stamps vs 4 cycles is a direct contract violation, not an interpretation.**

      **CHECK THIS FIRST — the one conditional in the whole sequence:** `CNTXTSAVE()` fires **only
      if `srf[SRF11] < 0`** (signed); everything else in `MSG_END` is unconditional. A mismodelled
      `SRF11`, or a skipped gate, yields exactly "the swapper was never parked" **while every
      message field still reads correct** — which matches the symptom set better than anything else
      examined today.
      Two cheaper unconditional probes: `srf[ADR_MSGME] := 0` (017425-26), and the
      `IDLE()`-vs-`MSG_NEXTL()` fork on `srf[ADR_PROC0]` (017430-32) — taking `MSG_NEXTL` where the
      real machine would `IDLE` keeps the CPU executing, i.e. an unparked swapper by another route.

      **OVERLAY CORRECTION (second time this bit us):** offset `0o7`/`0o10` is **TRIPLE**-overloaded
      — `N500A` on a copy, `SWFUN`/`SWRST` on the swapper arm, **and the SAVED P on a MON-call stop**
      (written at 004006; message-offset table line 990). Establish the arm before reading those two
      words.

- [x] **1.22 ROOT CAUSE FOUND AND FIXED (peer) — the trap-continue fast path un-parked the WRONG
      PROCESS.** The bridge resumed whichever process the CPU happened to hold, without checking
      `X5CPU`: SINTRAN's `3TRACO` for the **DOMAIN** (`X5CPU=1`) was resuming the **SWAPPER**
      (`X5CPU=0`). Guarded on `ReadMessageX5Cpu(msg) == _loadedX5Cpu`, falling through to the real
      context switch otherwise.
      **Result: `0o2067` gone entirely (2 → 0), swapper cycles 4 → 128, SINTRAN restart stamps
      12 → 256, regression 0 failed / 2184 passed.**
      This is exactly *"the completion the swapper acted on was not one real SINTRAN gave it"* — the
      project's top rule — and it explains the unparked 4th cycle **without any of the mechanisms
      chased across items 1.7–1.21**. (Peer also caught their own regression on the way:
      `_loadedX5Cpu >= 0` treated **unknown** as **different**, breaking
      `SamsonTrapContinue_OnParkedProcess_ResumesInPlace_NoStaleReload`. Fixed and re-verified.)

- [x] **1.23 RETRACTED — the `CNTXTSAVE` polarity is NOT our defect.** `SRF11` appears **zero
      times** in the classic lane; `SaveProcessContextBlock` is called **unconditionally**; the
      bridge already records CNTXTSAVE-on-stop as an acknowledged gap (R2-5). There is no gate to
      invert. Worth having flagged fast, now closed.
      **The doc contradiction itself resolves 2-vs-1** — see the note in
      `microcode\MAILBOX-MICROCODE-PSEUDOCODE.md` §1.2: five ND5000 test comments agree with §1.2's
      flag reading (negative = no process = nothing to save = **skip**), so the **gate line** is the
      outlier and the real microcode is very likely `if (SRF11 >= 0) CNTXTSAVE()`. `[D]`, not
      executed. *If verifying by execution, watch the **writes**, not the pass — a save over an
      empty context block may be harmless and both polarities would go green.*

- [ ] **1.24 NEXT BLOCKER — and the FRAMING IS WRONG. `RESIWR` cannot see a page-in.** `[V]`
      `LSWPAGE` @136112 (labelled *"Disk I/O"*) — the handler the swapper actually calls — pages by
      **DISC DMA**, not by a mailbox copy:
      ```
      136115  11=:L; SWMSG+"SWPINFO"=:D; T:="XSDUNIT"; *MOVPA  ; 11 params -> the 5swap param array
      136125  A:=XSDUNIT; CALL LOGPH                           ; logical -> physical unit
      136201  T:="QP100".QP5SW                                 ; 500 SWAPPER ELEMENT (disc access queue)
      136215  *LDF I (XABSF; STF ABFUN,X                       ; function block (3 words)
      136217  *LDD I (XABLO; STD ABPA2,X                       ; disc address
      136221  *LDA I (XABLN; STA ABP31,X                       ; length
      136223  CALL M5TRANS; GO BUSR                            ; START THE TRANSFER
      ```
      (non-optimised path: `136242 X:=SWMSG; CALL 5SWACTRT` — "Activate 5swap".)
      The page is moved by the **disc driver** into memory named by parameters the **swapper
      supplied**, straight into shared memory. **No `RESIWR`/`13B`/`14B` mailbox copy is involved,
      so a perfectly healthy page-in leaves `RESIWR` at 44 forever.** "RESIWR unchanged" is
      consistent with paging working AND with paging never happening — **it does not distinguish
      them. Fifth scope-limited zero, and it has been the headline metric all day.**

      **TRANSFERS DEMONSTRABLY COMPLETE.** The two measured `NUMPA:=0` answers were `5RDTRANSFER`
      (*"Return after disc-transfer"*), both taking the `OKMONICO % Transfer ok` arm — **not** the
      `A:=1055 % Error in transfer` arm. So at least two disc transfers ran to success: real paging
      activity `RESIWR` cannot see.

      **THE QUESTION CHANGES SHAPE:** not "why is no page copied in" but **"pages ARE being read —
      do they land where the PST expects, and is the PST entry written afterwards?"** PST entry 11
      staying zero (with six live entries at 0-15) is still unexplained; a page can arrive correctly
      by DMA and be useless if nothing maps it.

      **INSTRUMENTS THAT CAN ACTUALLY SEE IT:** count `5RDTRANSFER` arrivals and which arm each
      takes (ok vs `swderr=1055`); watch writes to the **destination page** (address is in the
      11-word block moved from `SWMSG+SWPINFO`); watch writes to **`PSTP + 11*entry`** — transfers
      completing while the PST entry is never written puts the gap between "page present" and
      "page mapped", a different handler entirely.
      `[D]`: which of the 11 params carries the destination address — `LDF` pulls 3 words from
      `XABSF` into `ABFUN`, conventionally function plus buffer, **word not pinned**.

- [x] **1.25 THE PAGING CHAIN, CLOSED AND BYTE-VERIFIED AT EVERY HOP.** `[V]`
      **`S3SM5` IS DISASSEMBLED** — `030-S3SM5.dis` (1.53 MB) + routine map + `FUNCS-BODIES\`
      (*"ALL FUNCS ROUTINE BODIES DONE (2026-07-15) … ~60 routines, byte-verified, base `40000B`,
      ~11,000 lines"*). **Stop parking questions as "that lives in S3SM5, we can't see it"** — done
      3× today (`MEMNAVAILABLE`, the `SWFUN`/`3SWMESS` stamp, the PST writer).
      - **`073 RPHSG`** @166537 "read from a physical segment" · **`110 WPHSG`** @167550 "write into
        a physical segment" (`FUNCS-dispatch-table.md`; bodies at
        `FUNCS-nameseg-process.ASM:544` / `:1079`).
      - **`WPHSG`'s tail builds the copy-family parameter block, matching the reference's `[V]`
        geometry on all four fields including the PHYS-only 4th word:**
        ```
        167617 LDD ,X 43 → 167621 STD ,X 7   ; msg word 7    := param 43  = addrA (ND-500 side)
        167622 LDD ,B -65→ 167623 STD ,X 11  ; msg word 0o11 := B-65      = addrB (buffer/phys)
        167625 LDA ,X 41 → 167627 STA ,X 14  ; msg word 0o14 := param 41  = PHS segment select
        167631 LDA ,X 47 → 167633 STA ,X 13  ; msg word 0o13 := param 47  = nrbyt
        ```
      **⇒ chain: swapper `RPHS` → MON 60 `RPHSG`(073)/`WPHSG`(110) → MICFU 30B/31B
      (`3PHSR`/`3PHSW`) → `MSG_PHYSRD 0o015561`/`MSG_PHYSWR 0o015600` copy engine.**
      Operand dumps can now be mapped back to the *caller parameter* that was wrong: `nrbyt` ←
      param 47, PHS ← param 41, addrA ← param 43.
      Also explains the reference's "near-1:1 PHYSWR/PHYSRD with small `nrbyt` = write-then-read-back
      **verify**" — both halves are the same FUNCS pair.

- [ ] **1.26 STILL OPEN: who writes the PST ENTRY. `WPHSG` does NOT.** `[V]` withdrawal of my own
      `[D]`: *"write into a physical segment"* means writing **content into** a segment — a memory
      path with a selector, **not** a page-table update. The body validates the address
      (167566-167615, three error exits) then issues the copy; nothing touches a table entry.
      **Third time today a NAME led somewhere the bytes did not** (`LADDR`/"LADDER" and `SWRST` were
      the others).
      Candidates by shape, not asserted: **`SSGTE`/`GSGTE`** (set/get segment table entry) in
      `FUNCS-nameseg-process.ASM` — *table* operations rather than transfers. Carve `SSGTE` next,
      unless the live PST write-watch catches the writer first (a trace beats a carve here).

      **LIVE CATCH (peer, gate5r-41): 40 PST writes, ALL thread T17 (ND-500 side), T16 wrote NONE.**
      So the entry is written from the ND-500 side — consistent with **no dedicated PST-writer
      FUNCS at all**, the swapper writing entries as ordinary content through the `PHYSWR` path.
      **Cheap confirmation:** if any 31B `PHYSWR` carries an `addrB` inside `0x455000`-`0x4551FF`,
      that is the PST written as content and **`SSGTE` is a dead end** — hold the assembly until the
      operand dump says otherwise.

- [ ] **1.27 PST ENTRY FORMAT — entries are FOUR BYTES, so the entry indexing in use is 2× off.**
      `[V]` `ND-05.020.01 ND-5000 Hardware Description`, "PHYSICAL SEGMENT TABLE" (§5318 ff):
      *"The PST contains **four-byte entries** … The **13-bit** physical segment number … points to
      one of the **8192** elements … **Bits 30 and 31** hold information about the access mode."*
      ```
      | 31        |            0 |
      | 2 bits    |      30 bits |
      | access    | physical page number |
      Access = 0 Direct · 1 Single indexing · 2 Double indexing
      ```
      Confirmed by NDIX `kernel\MASTER\machine\pte.h:74-76`: `PS_AZI 0` (direct), `PS_ASI 1`
      (single index), `PS_ADI 2` (double index).
      - **Entry N is at `PSTP + 4N`, NOT `+2N`.** The watch used `+N*2`, so its "entries 11-17" are
        **halfwords** — `0x455016` is byte offset 22, the **low** half of entry **5**; the seven
        addresses span ≈ entries **5-8**. **The original "PST entry 11 is zero" was reading the low
        halfword of entry 5** — recompute before anything rests on it.
      - **The observed `0x4000` is the ACCESS FIELD, not a commit flag.** Bits 31-30 of the entry are
        bits 15-14 of its **high** halfword, so `0x4000` = **access = 1 = Single indexing**. Matches
        the earlier healthy-neighbourhood reading `0x40xx = PS_ASI`, `0x016C = PS_AZI`. The
        "initial → set bit 14 → decrement" shape is therefore likely **low half then high half of
        one entry**, not three writes to one cell.
      **CORRECTED by the peer: the 4-byte format is the ND-5000 arm and does NOT apply here.**
      `ReadPstEntry` is explicit — `ClassicHalfwordTables → ReadPhysical16(PSTP + psn*2)`, else
      `ReadPhysical32(PSTP + psn*4)`. **Classic is stride 2**, so the `11-17` numbering stands and
      "PST entry 11 is zero" really was entry 11. **The bit-14 half survives:** classic decodes
      `mode` in bits 15-14, `page` in bits 13-0, so `0x4000` = access mode 1 = `PS_ASI` — an access
      field, **not** a commit flag. The "two-step commit" reading is withdrawn.

- [ ] **1.28 THE END STATE IS A DEADLOCK — AND THE PARK ITSELF IS NORMAL.** `[V]`
      Measured (gate5r, 25-min budget): `#8466 MON 377B argc=4 X5CPU=0` → `#8467 CONTEXT SAVE
      X5CPU=0 (monitor-call stop)` → **no restart, ever**. 134,748 MPM writes; the last 400 are all
      **T16**, alternating `0x2098`/`0x0480` at `@0x420EFE` = halfword `0o147` **`PLINK`** (backward
      queue link), with `0x2098` as a word address = byte `0x424130` = the **TIMEOUT block**. So
      SINTRAN cycles the process on/off the timeout queue alone while the ND-500 sits parked.
      1053 faults in ~10 min, then **one** in the remaining 18 — stopped, not slow.

      **THERE IS A WATCHDOG RESCUE, AND ITS GATE EXPLAINS THE SILENCE.** `5TMR3`,
      `RP-P2-N500.NPL:353-387`: `IF A=PSW1WAIT THEN … EESWPUSER: X:=SWMSG; A:=0; CALL EMONICO`
      (*restart swapper with error return*) `; CALL ACTRDY`. **Gated on `SWMSG` status =
      `PSW1WAIT` (`PSW1W = 0o15 = 13`).** At the deadlock the status is **`PSWWAIT` (7)** — set by
      `SWPD4` two instructions before the drain. **The watchdog never looks at state 7, deliberately:
      `PSWWAIT` means *free*, not *stuck*.**

      **⇒ THE PARK IS THE MACHINE'S IDLE STATE, NOT A HANG.** `EMPTY` deliberately does not answer;
      `SWPD4` marks the swapper free; the outstanding `LNEWSWAP` is answered later by
      `5ACTSWAPPER`'s serve branch (`SWPST`, `NUMPA:=6`, `MICFU:=3MONCO`, `MCCO`). **So the failure
      is not "nothing wakes the swapper" — it is "no new work ever arrives."**

      **THE MISSING HALF IS THE DOMAIN.** Every quoted event is `X5CPU=0`. If cpu-stat is parked on a
      page fault, that fault reaches `TRAPDECODER` → `5ACTSWAPPER`, and with the swapper `PSWWAIT`
      it takes the **serve** branch immediately — no queue, no drain. Nothing found so far blocks
      that path. So either the domain is **not faulting** (parked on something else) or its fault is
      **not reaching `TRAPDECODER`**.
      **Measure, in this order:** (1) **the last `X5CPU=1` event and its stop reason** — likely ends
      it; (2) `X5SWH`/`X5SWF` — but note equal pointers are **consistent with correct behaviour**
      here, since an arriving fault bypasses the queue via the serve branch, so they cannot
      incriminate alone; (3) confirm the final `SWMSG` status really is `0007` and not `000D` — if
      `000D`, the watchdog *should* have fired and the question becomes why `5TMR3` did not run.

- [ ] **1.30 THE DEADLOCK IS FULLY EXPLAINED: the page-in SUCCEEDS and the requester is never woken.**
      `[V]` end to end. Measured final sequence: `#8458 TRAP 46B psn=11` → `#8461 RESTART SWPST=0x0A
      DISP=0x0A` (5ACTSWAPPER **serve** branch, no queueing — as predicted for a `PSWWAIT` swapper)
      → `#8462 MON 377B SWPFU=0x0002 (LSWPAGE)` for **segment 11, the correct psn** →
      `#8465 RESTART K=0 SWPST=0x000B` (`5RDTRANSFER` "Transfer ok", zero mask) →
      `#8466 LNEWSWAP` → `#8467 CONTEXT SAVE X5CPU=0`. **End of trail. `X5CPU=1` never restarted.**

      **THE WAKE PATH EXISTS AND IS ON THE `SWPST == 0` ARM** — `MP-P2-N500.NPL:980-1006` (@135632),
      commented *"Restart nd-500 proc."*:
      ```
      135636  3TRACO; *MICFU@3 STATX     ; MICFU := 3TRACO (if it was 3START)
      135654  X:=CSWPM; CALL RN5STATUS   ; CSWPM = THE REQUESTER
      135656  A/\160000\/MSGN500
      135660  CALL WN5STATUS             ; requester N5STA := MSGN500(1)
      135661  CALL XACTRDY
      135664  IF A><B THEN … CALL XACT500 … FI
      ```
      **This is the ONLY path in `LNEWSWAP` that wakes an ND-500 requester after its page arrives.**
      `SWPST = 0x000B ≠ 0` ⇒ `135550 IF A><0` takes the **ERROR** arm ⇒ that code never runs.

      **AND THE ERROR ARM CANNOT WAKE A PAGE-FAULT REQUESTER EITHER.** `SPFLA = 0o143` is **a
      continuation ROUTINE ADDRESS, not a flag** — `135165 IF A><0 THEN A=:P FI % GOTO ROUTINE ADDR
      FOUND IN SPFLAG` (set by `LDATREADY` stashing `INLDATREADY` @136416, cleared @136431; same
      idiom at `INCLCK`, `STTDRIV`). So: `SPFLA≠0` → `EMONICO` wakes the **ND-500** requester;
      `SPFLA==0` → `SWPD1`→`SWPD2` → `5RRTWT` restarts the **ND-100** process. A page-fault requester
      has no SINTRAN-side continuation, so `SPFLA==0` and **the domain is never touched.**

      **⇒ THE DEFECT REDUCES TO ONE CELL: why is `SWPST` `0x0B` after a SUCCESSFUL `LSWPAGE`?**
      `0x0B = 11` is **the faulting psn** — the same value in the `LSWPAGE` parameter block
      (`[1] @0x080247AC = 0x0000000B`). The **segment number is sitting where SINTRAN reads an error
      code** (`0` = OK). Note `5RDTRANSFER` answers via `OKMONICO` ⇒ `NUMPA:=0` ⇒ **nothing writes
      `SWPST` on that path**, so whatever was last in it survives.
      **Two readings, not chosen between:** (a) stale scratch surviving a zero-mask answer;
      (b) the swapper genuinely reporting failure code 11.
      **Discriminator, a lookup not a run:** find the write that put `0x0B` into `0x420DB6` and
      compare its seq to `#8462`/`#8465` — before the transfer ⇒ (a), after ⇒ (b).
      **BOTH READINGS REFUTED BY MEASUREMENT — the `0x0B` theory is DEAD.** The swapper writes
      `SWPST := 0x0000` (T17) and **SINTRAN takes the OK arm routinely** — `SWPST` is written `0`
      **60 times** in the ring. The `0x0B` was a one-off, followed by `0x00` before the next
      `LNEWSWAP`. **The wake path at `MP-P2-N500.NPL:980-1006` executes exactly as carved:**
      `#134338 requester MICFU := 0x0015 (3TRACO)` → `#134340 requester N5STA := 0x0001 (MSGN500)`.

- [x] **1.31 The wrong-process resume fix: REAL, but NOT the blocker (peer's own withdrawal).**
      The trap-continue fall-through started from `servicer.LastStartContextAddress` — the block of
      whatever started **last**, not the message's process — and never switched context, so a
      `3TRACO` for `X5CPU=1` while `0` was loaded resumed nothing. Now calls
      `SwitchToProcessIfNeeded` first. Cross-process `0→1` switches **5 → 1040** across 1038 faults,
      suite 0/2184. **But 5-of-1038 could never have been the blocker** — the rest were in-place
      resumes that already worked, and both runs stop identically. Worth keeping on its merits
      (resuming from the last-started block is wrong regardless); "correct but not the blocker" is a
      fine outcome.

- [x] **1.32 The `PLINK` spin at the end is NORMAL IDLE — SINTRAN is content, not stuck.** `[V]`
      `PLINK = 0o147` is the **backward link of the ND-500 Execution/Time queue** (`LINK` forward,
      `PLINK` back). `CC-P2-N500.NPL` @022606-022655 is `ITO500XQ`, the priority insert (fixes the
      previous element's back link @022633, then the inserted element's @022643); its sibling header
      @022664 is *"`Ifm500xq`: Remove message from ND-500 Time queue"*. So an **alternating** `PLINK`
      at one address is a message being removed and re-inserted repeatedly.
      The thing doing that is the watchdog — `5TMR3`, `RP-P2-N500.NPL:384-387`:
      `3RMICV; X:=WATCHDOG; *MICFU@3 STATX` … `MSGN500; CALL WN5STATUS` … **`CALL ITO500XQ; X=:TMRXQ`**
      (re-arms itself on the time queue). The measured `0x2098` = byte `0x424130` **is** that
      WATCHDOG block. Per the message reference, *a burst of `3RMICV` means TIME PASSED, nothing
      more* — and it explicitly warns against reading it as a livelock.
      **⇒ The ND-100 side is out of the search. No timeout is pending; SINTRAN is not blocked on the
      ND-500.**

- [x] **1.33 ANSWERED — the domain is not idle, it is spinning in the Pascal runtime's
      non-local-exit unwinder, and the ND-100 side is fully cleared.** `[V]` (peer's instruction ring
      + my independent decode of the same binary; every address agrees). After the resume at
      `P=0x0800473A` it retires ~61 instructions per cycle, 65 cycles in a 4000-entry ring, over four
      stack frames. Loop body `0x080049F1..0x08004C00`, entered from `0x08004722`. It reaches
      `0x08004B82` (MON 32B MSG) and `0x08004B8D` (MON 0B LEAVE) — **the exit it never takes**.
      Nine MON calls in the domain's whole life; **it never reached its own main and never made a
      single output call.**

- [ ] **1.34 THE REAL DEFECT: the heap grows forever because GETB is never satisfied.** Six
      `MON 422B GSWSP` calls double the heap 128 KB → 2 MB (`0x00020801` … `0x00200801`), the last
      refused with `K=1 FUNCV=0x203`, `K=1` falls through at `0x08003F73` into the runtime-error path,
      and the unwinder starts spinning. Shape: `GETB traps STO → the ENTT handler at 0x0800415A grows
      the heap → RETT → retry → traps again`. **The 1000+ page faults were correct behaviour all
      along** — fault PC `0x08004022` is `w bmove $0xF0F0F0F0,@b.0x14,r1`, the grower poisoning each
      newly granted segment, one fault per 2 KB. Not a symptom.

      Three constraints on the search, from the source and the allocator (`[V]` unless marked):
      - **The program cannot legitimately want 2 MB.** `cpu-stat.pasc` is 104 lines; its entire
        dynamic footprint is a ~20-byte record and `month : array[1..12] of packed array[1..9] of
        char` = 108 bytes, filled in an `initprocedure` that runs before main. So the size being
        ASKED FOR is wrong — check the request before the free lists.
      - **`w1 getb r1` @`0x08004149` takes a buddy ORDER, not a byte count.** The allocator
        @`0x080040F1` computes `n = (size+3)>>2` (words, rounded up; the `shl $0x3E` is a 6-bit
        signed −2, i.e. `>>2`), then `dconv → d4 alog2 → d1 int → d4 comp → +1.0 if inexact →
        d byconv`, and passes that byte to GETB.
      - **REFUTED, mine, withdrawn same round: "our GETB might read the operand as a size."** It does
        not. `Getb.cs` reads `DataType.BY` into `logSize` and calls `AllocateHeapBlock(logSize)`, and
        `Instructionset.BuddySystem.cs` uses MAXL@TOS+0 / STAH@+4 / ENDH@+8 / FLOG[n]@+12+4n — the
        SAME layout the program builds, since it sets `tos := $0x08000C94` (a literal, encoding `CF`,
        not a memory read) and builds its lists at `$0x08000CA0` = TOS+12. **The buddy-layout
        question is closed**; the ND-500 Reference §4.1.5 second-reader offer is moot.
      - **REFUTED before it was ever raised: I/D-space aliasing on the heap descriptor.** This DOM
        has program AND data both at virtual 0, so `0x08000C94` is numerically inside routine
        `0x08000BFE`. If the descriptor were read from I-space, MAXL would be the instruction bytes
        there — `FF C7 00 0C` = `0xFFC7000C` — and that huge MAXL makes `logSize > maxL` never trap
        and sends `AllocateHeapBlock`'s `for (cur = order+1; cur <= maxL; cur++)` into billions of
        reads: a dead hang, not 61 instructions retired per cycle. **Ruled out by computing what it
        would produce, not by assuming it was fine.**
      - **That order is decided in FLOATING POINT, in a family with a live defect.** One ulp in
        `alog2`/`int` gives an order one too small. EXP's final `2^k` scale is still one power of two
        short (`FWRITE_X` @027451, SC2 @025703) and `INTRF_U`'s rounding was fixed only 2026-08-04.
        **Feeding n = 27 words through this by hand and checking it yields order 5 is a five-minute
        test that does not need the live boot** — do that before touching the buddy lists.
      - `[D]` The `0x4040000000000000` addend read as `1.0`: not verified against the ND-500 double
        encoding. Corroborated only by the same literal appearing at `0x080040C8` (`d add2 b.0x1C`)
        where the context is also "step the order by one".

      **RESOLVED BY THE PEER'S HEAP LOG, then re-diagnosed from the microcode.** Four GETBs, ever:
      `#1 pc=0x0800414C want=2^10 TOS=0x08000C94 MAXL=23 -> TRAP-STO no-free-block`, then
      `#2..#4 want=2^10 TOS=0x08001A28 MAXL=0 -> TRAP-STO logSize>MAXL`. **TOS changes between the
      trap and the retry.** GETB #1 runs with TOS where `tos := $0x8000C94` put it and finds a
      well-formed descriptor — `MAXL = 23`, exactly the `0x17` the program's own list-build loop
      counts up to at `0x0800408D`. After the STO trap, the grow, and the RETT, TOS comes back
      `0x08001A28` — the domain's ordinary stack TOS, i.e. the value from BEFORE `tos :=`. At that
      address MAXL reads 0, so every retry trips `logSize > MAXL`, the handler grows again, and that
      is the whole fifteen minutes. **One clobbered register.**

      This also confirms the I/D refutation from the other direction: the descriptor read returned
      **23**, not `0xFFC7000C`.

- [ ] **1.35 THE FIX DIRECTION: on the real machine ENTT/RETT never save or restore TOS at all.**
      `[V]` from the RAW `MICRO-5800-B30.DATA` (extractor calibrated first against both documented
      `.md` render-bug cases: 0o15075 → raw MARG `0x48` ✓, 0o326 → raw ORCON `0o41` ✓).

      **TOS is not a CPU register — it is a PCB/DIT field.** `LOATOS` (`tos :=`) @`0o001020` →
      `LOAD_TOS` @`0o012170`: `T,PUSH → CED_TO_DIT` (DPA := the domain's DIT base), then
      `ADACT AA=2(DPA) AB=1 MARG=0x3C`, then `WR,PHYS`. So `tos := $0x08000C94` stores the value
      **physically into the domain information table at DPA + 0x3C**. `LOAD_THA` @`0o012210` is the
      same shape at **DPA + 0x36**. Corroborated independently by the NDIX real ND-500 Unix
      `struct pcb` field list already in memory: **`+0x3C pcb_tos`**, `+0x3B pcb_ith`.

      **`RETT` restores no TOS.** `RETT2` @`0o014357` is a walking cursor — every word `EA = EA3 + 4`
      with `EA3SAVE`, one register per step: `SC3, SC4, SC5, SC6, LDRES, (skip), X1-X4, A1-A4,
      E1-E4, SC13, SRF10`, then `RETT_NPLBR`: `SC3→P, SC5→L, SC6→DPA, SC3→CLKSP, SC4→P`. Sixteen
      consecutive `+4` steps landing on X1-4/A1-4/E1-4 in order is not a coincidence.

      **RETRACTED, MINE, SAME ROUND — "so delete the save/restore, the real machine has no such
      machinery". WRONG FOR THE CLASSIC LANE, and it would have deleted correct code.** The
      generation caveat I attached was not a small print item, it was the whole answer. For the
      classic ND-500 the architecture manual contradicts the B30 microcode BY NAME:
      **ND-05.009.4 §13.10 ENTT** — *"The register block is stacked as shown in table 5"* — and
      **Table 5 (p.26) lists arg21 = TOS**, between PS (arg20) and LL/HL (arg22/23). With arg1 at
      `B+20` and `argN = B+20+4(N-1)`, **arg21 = B+100**. So our `frame+100` is Table 5 arithmetic,
      not a decimal coincidence borrowed from an EA2 source displacement — and LL at +104 and HL at
      +108 fall out of the same formula and match too. §6.4 confirms the frame is meant to be
      restored from: *"Modification of status bits is done by changing the status word in the saved
      register block… Upon trap handler return, this status word is merged… and loaded into the
      status register."* A frame the handler may EDIT to influence the resume is a frame that gets
      restored from.

      **Both are true, and the difference is generational — write it down as one.** The classic
      ND-500 carries TOS in the trap frame (Table 5 arg21). The ND-5800 moved it into the PCB. That
      is a real architectural split, not a contradiction to resolve away.

      **Second data point on the split, decoded on request** `[V]`: on the B30, TOS is **dual-homed**.
      `LOATOS` @`0o001020` reads the operand into `SC5`, then `LOAD_TOS` copies `SC5` into **`SRF12`**
      (a live register-file cache) *and* writes it physically to **`DPA + 0x3C`** (the PCB copy).
      `STORTOS` (`tos =:`) @`0o001133`-`0o001134` reads **`SRF12`** back — `AA=7 (EA3)`, `AB=0`, no
      displacement, straight to the operand address — so it never re-reads the DIT. The 5800 keeps
      the authoritative copy in the PCB precisely so it survives a context switch by construction;
      the classic engine has no such backstop, which is why the frame carries it.

      For the record, ENTT's B30 save block reads EA2 at displacements 84, 88, 92, 96, 100, 104 and
      writes EA3 at 4, 8, 12, 16, 20, 24. (2) The RETT restore LIST is claimed; where EA3 initially
      points on entry to RETT is not.

- [x] **1.38 ROOT CAUSE, PEER'S: `ENTT` is not restartable in our engine.** `[V]` The probe settled it
      in four lines. ENTT executes **twice** and the second execution snapshots the state the first
      one created: attempt 1 `savedTOS=0x08000C94` (the truth), attempt 2 `savedTOS=0x08001A28` —
      which is not another register but **arithmetic**: `frame 0x08001728 + demand 0x300 = 0x08001A28`,
      i.e. ENTT's own Step 5, `TOS := B + total trap handler stack demand` (Figure 41). `savedB` says
      the same: `0x000001A4`, then `0x08001728` — the frame base attempt 1 wrote into B. ENTT mutates
      B/L/TOS **before** its ~220-byte frame write completes, that write page-faults on a non-resident
      trap data field, the page fault is a During-class trap so the instruction re-executes from the
      top, and the retry captures its own leftovers. **RETT was innocent, and so was the context
      block.** Fix (peer's, building clean, NOT yet regression-verified): capture `PreTrapB/PreTrapL/
      PreTrapTOS` in `InvokeTrapHandler` beside `TrappingPC`/`ResumePC` and have ENTT write those into
      arg3/arg4/arg21 instead of reading live registers. Justified by the trace itself —
      `trappingPC` is identical across both attempts while the registers are not, so
      `InvokeTrapHandler` runs once per trap and the restart re-enters only the instruction.

      **Peer's own retraction, recorded:** "`0x08001A28` is the domain's ordinary stack top, the value
      in every REGS dump" was a real observation with the wrong inference — it is the *trap handler's*
      stack top, and the resemblance cost two rounds of hunting the context block. **A resemblance is
      not a measurement.** Same shape as my own errors today.

- [x] **1.37 `want=2^10` EXPLAINED — my order-5 arithmetic was aimed at the wrong allocation. No
      second defect.** `[V]` The first allocation is not the month array. `0x08002E2C` computes:
      ```
      08002E47  w1 := b.0x14 ; incr        ; recsize = (arg+1)>>1   (shl $0x3F = 6-bit -1)
      08002E55  w1 + $0x3FF                ; +1023
      08002E59  w1 / b.0x50 ; * b.0x50     ; -> smallest multiple of recsize >= 1024
      08002E63  w1 * $0x2                  ; DOUBLE it
      08002E65  call allocator(...)
      ```
      That is a **text-file I/O double buffer**: 1024 rounded up to a whole number of records, times
      two. ~2048 bytes → `n = 512` words → `log2 = 9` exactly → order 9; and **whenever recsize does
      not divide 1024 the round-up exceeds 2048, `log2` is inexact, the `+1.0` arm fires and the
      answer is order 10.** So `2^10` is the CORRECT output of that chain, not evidence of a float
      bug. **My "possible second defect in `dconv/alog2/int/comp/byconv`" is withdrawn** — the number
      it rested on is fully accounted for. (The `shl` negative-count reading is corroborated: `$0x3E`
      = −2 here and `$0x3F` = −1 there, two independent uses both yielding sane sizes.)
      The other three allocator callers are tiny by construction — `0x08004168` is a string-constant
      builder called four times with lengths `0xD, 0x18, 0x8, 0xA`, orders 0-3.

- [ ] **1.39 `savedB = 0x000001A4` on ENTT attempt 1 — UNEXPLAINED, do not hand-wave it.** A frame
      pointer with no segment bits, while the program had been running correctly through many
      routines, so B cannot simply have been garbage. One cheap discriminator settles where to look:
      **compare it against the `B` printed in CONTEXT SAVE `#758`.** If `#758` shows a proper
      `0x0800xxxx` frame pointer while ENTT attempt 1 captured `0x1A4`, the capture POINT is wrong and
      the new `PreTrapB` inherits the same defect; if both say `0x1A4`, B really was that value and the
      question moves upstream to `ENTS`. Until that is run this stays `[OPEN]` — a fix that writes
      `PreTrapB` into arg4 is only as good as `PreTrapB`.

- [ ] **1.41 THE RESTARTABILITY AUDIT — done, and it is a two-instruction problem, not a systemic
      one.** `[V]` on the code shape; `[OPEN]` on whether the second one ever fires. Swept every
      entry/call instruction in `Emulated.HW\ND\CPU\ND500\Instructions\CALL\` for the 1.38 pattern
      ("does it mutate architectural state BEFORE its frame writes finish").

      **Correct — every write first, register commit LAST (so a fault leaves the retry recomputing
      from unchanged state): `ENTS`, `ENTSN`, `ENTB`, `ENTF`, `ENTFN`.** All five end with
      `regs.B = newB; regs.L = returnAddr` after the argument loop. `ENTD`/`CALL`/`CALLG` set only
      `L` with no faultable write after it. So the correct pattern is already the majority — good
      news, and it means 1.38 is a defect, not a house style.

      **`ENTT` — the known one (1.38): `regs.B = trapFrameBase` at `Entt.cs:139`, BEFORE the ~24
      frame writes at 143+.**

      **`ENTM` — a SECOND, previously unrecorded instance of the same class.** `Entm.cs:146` does
      `regs.TOS = bottomOfStack + totalStackDemand` **in the middle of the frame writes** — after
      `OFFSET_SP`/`OFFSET_AUX` at 142/143, but BEFORE `OFFSET_N` at 150 and the argument loop at
      152-156, both of which can fault on a non-resident frame page. On the restart,
      `uint oldTOS = regs.TOS` at line 126 re-reads the **already-advanced** TOS and line 134 writes
      that wrong value to `oldSP`. `bottomOfStack` is an operand (line 97), not derived from TOS, so
      `newB` recomputes correctly — **the corruption is confined to the saved old TOS**, which is
      narrower than the ENTT case but the same mechanism. ENTM is the main-program entry, it runs at
      program start, and its argument loop writes into a fresh frame — exactly the residency
      conditions that made ENTT fault. **Not measured firing; found by structure. Do not report it as
      observed.** Fix shape is the same as 1.38: hoist the `regs.TOS` assignment to after the
      argument loop, beside the `regs.B`/`regs.L` commit.

- [x] **1.42 THE FIX IS VERIFIED AT THE RUN LEVEL — CPU-STAT REACHES MAIN, PRINTS, AND EXITS
      CLEANLY.** `[V]` (peer's before/after on the same boot). After: ENTT attempts 1 and 2 are
      **identical** (`savedTOS=0x08000C94`, `savedB=0x000001A4`) — restartable. RETT hands back the
      truth, and GETB returns `0x10000000` from a real buddy free list
      (`FLOG 10=0x10001000 11=0x10002000 12=0x10004000 13=0x10008000 14=0x10010000`,
      `STAH=0x10000000 ENDH=0x1001FFFF`, `MAXL=23`). **One** MON 422B grow instead of six. Whole-run
      MON traffic: `1×11B, 1×114B, 2×143B, 1×262B` (GetSystemInfo — the first line of the Pascal
      program), `1×122B`, **39×504B** (output, payloads decoding as `"CPU "`, `" (ND"`, `0x0D0A0A`
      = `'CPU number       : '` and `' (ND-100 …'` straight out of `cpu-stat.pasc`), then
      **`1× MON 0B` at `ret=0x080003C1`** — the single MON site in MAIN on the 1.33b band map,
      i.e. normal termination. 900-second spin → **93 seconds ending in MON 0B LEAVE**.
      **`want=2^10` is confirmed correct by this run** (a 4 KB double buffer out of a 128 KB heap,
      FLOG[14] intact), which retro-validates withdrawing the float suspicion.

      **NOT the milestone yet, and not to be reported as one:** only Gate5R has run, not the
      regression suite, and a change to ENTT touches every trap test. The run also used `-v q`, so
      there is MON-level proof of the text but no rendered report; a detailed re-run is capturing the
      actual printed page. **And the CLAUDE.md gate is unanswered in writing: WHO ANSWERED THE MON
      CALLS?** If our C# `SintranEmulation` answered any of those 46, the run does not count toward
      the goal. Get that on the record before anyone calls this "a real program running".

- [x] **1.39 `savedB = 0x000001A4` — resolved to explained-enough by the discriminator in the plan.**
      Both ENTT attempts now agree on it, so by the stated test the capture point is fine and B
      genuinely was `0x1A4` at trap time — not a corrupted snapshot. Two further arguments: RETT
      restores `0x1A4` and the program then runs correctly through the allocator, GetSystemInfo, 39
      output calls and a clean exit, which a bad B would not survive; and `#757 CONTEXT SWITCH` shows
      `B=0x0000003C`, another small segment-less value, so this program legitimately runs with tiny
      B values in that region. Where `0x1A4` comes from is still untraced — recorded as
      explained-enough, **not closed**.

- [ ] **1.43 THE FULL NON-RESTARTABILITY SWEEP — and the test is sharper than "mutate before the
      write".** `[V]` on shapes, `[OPEN]` on firing. Extending 1.41 with INIT, the RET family and the
      heap allocator.

      **The generalised test, which is the real deliverable:** an instruction is unsafe if, on a
      restart, it **re-reads anything through a register it has already mutated**. Three ways that
      happens, in increasing subtlety:
      1. it saves a live register that it has itself already overwritten (**ENTT** — fixed; **ENTM**);
      2. it leaves a partial multi-word structure whose earlier writes are not repeatable
         (**the buddy split**, below);
      3. **it re-evaluates its own OPERAND through the mutated register.** This is the one nothing in
         the codebase currently guards, and it is invisible to a "writes last" review.

      **`INIT` (`Instructions\CONTROL\Init.cs`) — has the shape, low practical risk, worth ordering
      anyway.** `regs.B` @110, `regs.TOS` @113 and `regs.L = 0` @118 all land before the writes at
      116/117/121/126 and the argument loop at 131 — and those writes address through `regs.B`, so
      the instruction *relies* on its own mutation. It is nevertheless idempotent **as long as
      operand 0 is not B-relative**: `bottomOfStack` is an operand (line 83), INIT saves nothing (it
      writes zero sentinels), so a restart recomputes every value. **But `ReadOperandValue` on the
      restart runs with the NEW `B`** — form (3). In practice INIT is a domain's first instruction
      and its operand is the stack bottom, so B is not yet meaningful; the risk is structural, not
      live. Order it anyway: the cost is moving three lines.

      **The RET family is CLEAN.** `Ret`, `Retb`, `Retbk`, `Retk` read the frame first and assign
      `B`/`L` last. `Rett` assigns `L`/`R` @165-166, `TOS` @194, `B` @213 — every frame read before
      `B` is committed uses the OLD `B`, which the instruction has not touched, so a fault re-reads
      the same unchanged frame. Correct by construction.

      **`SplitHeapBlock` / `AllocateHeapBlock` — form (2), and arguably worse than ENTT because it
      corrupts a shared structure rather than one register.** `AllocateHeapBlock` **unlinks** the
      block (`WriteHeapFreeListHead`) and only then splits; `SplitHeapBlock` then writes a buddy next-
      pointer and a FLOG head per halving step. A fault anywhere in that loop leaves the free lists
      **half-rebuilt with the original block already popped**, and the GETB restart re-runs from the
      top against the mutated lists. Not measured firing — and CPU-STAT would not have exposed it,
      since its heap is resident by the time the split runs. `[OPEN]`, and worth a targeted test
      rather than a code change on suspicion.

- [x] **1.44 THE GOAL GATE IS ANSWERED: REAL SINTRAN ANSWERED ALL 46 MON CALLS.** `[V]`, peer's
      attribution. `Nd500UCSintranBootTests.cs:1766` carries the guarantee in writing: *"This gate has
      no SintranEmulation anywhere: attaching the bridge disables it outright."* Gate5R runs
      `ND500UC_BOOT_REALCPU=1` against real SINTRAN booted from `BIGDISK0-L-JULY.IMG`; ND-100 side,
      3022/5015, 5MPM mailbox, swapper, domain load and monitor calls all real — only the ND-500 CPU
      is ours. Independent behavioural confirmation: **the output bytes reached the SINTRAN console**,
      and our servicer does not write the terminal, so something on the ND-100 side executed the 504B
      handler.

- [ ] **1.45 IT DOES NOT PRINT. The next defect is the MON 504B buffer hand-off, and BOTH of us were
      asking the wrong question about it.** Console after `run` is `  d d   nL     " \t  d...` —
      **real bytes, wrong bytes.** (Peer's own correction, recorded: they led with "it prints" while
      holding only MON-level evidence that the right text was in the program's buffer. One defect
      fixed, the next exposed underneath it.)

      **The contract is `[V]` and it has exactly TWO legal paths, chosen by a flag — not by an address
      convention.** `MP-P2-N500.NPL:140656`:
      ```
      140656  IF MIFLAG NBIT WSMC THEN            % IS DATA-BUFFER IN COM-BUFFER? (BY MIC.PROG)
      140661     T:=5MBBANK; 3RMED; *STATX XMICF  % NO, MIC.FUNC=READ DATA MEMORY
      140675     *AAX ABUFA-N500A; LDDTX; AAX N100A-ABUFA; STDTX   % ND-100 PHYSICAL ADDR
      ```
      Symbols (`N500-SYMBOLS.SYMB`): **`WSMC = 0`** (bit 0), **`ABUFA = 140B`** (halfword),
      **`MIFLA = 177770`** = halfword **−8**, i.e. MIFLAG sits BEFORE the message base,
      **`3RMED = 10B`**. Same decision appears at `142301`, `143020`, `143173` and
      `RP-P2-N500.NPL:130437`.
      And `MON 504B = NOUTSTR` **is in the microcode's inline-copy set `{504B, 511B, 512B}`** —
      deep-dive lines 2091/2423, `[V]` raw, `CALL_5XX 004013B → CALL_5_MATCH 013667B`: *"the microcode
      copies the user's buffer into the communication buffer before it stops. The ND-100 then sees
      `MIFLAG` bit `WSMC` set … and skips its own `3RMED` fetch. Buffer maximum 4000B bytes, addressed
      through `ABUFA = 140B`."*

      **So "does SINTRAN get a virtual or a physical address?" has a third answer: on the inline path
      it gets neither — the BYTES are supposed to be in the message.**

      **The peer's negative was a wrong-MICFU search.** They looked for RESIRD/RESIWR (13B/14B) near
      the calls. The fetch is **`3RMED` = 10B = 8 decimal**, which our servicer **does** implement —
      `Nd500MicrocodeServicer.cs:1029`, `N5MicroFunction.DataMemoryRead = 8`. So the absence of 13B/14B
      says nothing at all about this path.

      **My own near-miss, same shape, recorded because it nearly became a finding:** grepping RetroCore
      for `3RMED` returned nothing and I almost reported "not implemented". It is named
      `DataMemoryRead`. RULE #0b — the zero result was about my pattern, not the code.

      **The question that actually decides it, and it is one trace read:** did this run take the
      inline path or the `3RMED` path? `WSMC`/`MIFLAG` appear **nowhere** in `Emulated.HW` /
      `Emulated.Machines` under those names, so our engine most likely never sets the bit and SINTRAN
      took `3RMED` — in which case the garble is in how `DataMemoryRead` resolved arg[2]'s address
      (`0x1000103A`, ND-500 **virtual**, segment 2) rather than in a copy that never happened.
      `[OPEN]` until measured.

      **Generation caveat, stated deliberately after being burned on one today:** `MP-P2-N500.NPL` is
      the SINTRAN-side ND-500 message module and serves BOTH transports, so the WSMC/ABUFA/3RMED
      decision is not 5000-specific. What IS 5000-specific is that the *microcode* performs the inline
      copy. On the classic lane our engine plays the microcode's role — so the obligation to either
      fill ABUFA and set WSMC, or answer 3RMED correctly, is ours either way.

- [ ] **1.46 THE ONE REGRESSION, PREDICTED: `ENTT_InTrapContext_PerSpec` line 1889.** Suite came back
      **1 failed / 2183 passed / 13 skipped** against a 0/2184/13 baseline, name swallowed by `-v q`.
      Prediction `[D]`, from reading both sides:
      `Emulated.Tests.ND500\Instructions\TestND500_SpecBasedTests.cs:1802` asserts
      `arg4 (B+32) == initialB (0x3000)` — but it **never calls `InvokeTrapHandler`**; it fakes the
      trap by hand-setting `pcb.InsideTrapHandler/PendingTrapNumber/TrappingPC` and `regs.B`. Since
      `Entt.cs:114` now reads `savedB = pcb.PreTrapB`, which was never captured on that fresh PCB,
      arg4 comes out 0. **Same weakness as the ENTM argument: the `PreTrap*` triple only exists when
      something dispatched a trap** — the fix depends on a code path instead of on the instruction
      being correct in isolation.

      **The ordering fix clears both, and it was checked rather than assumed:**
      `regs.B = trapFrameBase` at `Entt.cs:139` is the **only** early mutation (`TOS` is Step 5, `L`
      later still), and **every one of the ~40 frame writes addresses `trapFrameBase` directly**
      (lines 143-218 plus the arg41-50 zero loop) — **not one uses `regs.B`**. So move line 139 down
      beside the `TOS`/`L` assignments and read `savedB`/`savedL`/`savedTOS` live again: on a restart
      all three still hold pre-trap values, the instruction is restartable **with no `PreTrap*` at
      all**, the test goes green unchanged, and the same shape fixes ENTM where `PreTrapB` cannot
      reach. Peer's before/after harness proves equivalence in one run.

- [ ] **1.47 WHY IT PRINTS GARBAGE: `DMEMRD` (MICFU 10B = `3RMED`) IS NOT IMPLEMENTED ON THE CLASSIC
      LANE. Our own code says so.** `[V]` `Nd500MicrocodeServicer.cs` ~1088, the `else` arm of the
      `DataMemoryRead`/`PhysicalRead` case:
      ```
      else
      {
          understood = false;   // DMEMRD classic still unmodelled
      }
      ```
      The octobus arm is gated on `Generation != Classic`; the classic arm handles **only**
      `PhysicalRead`. Gate5R runs **Classic** (3022/5015). So when SINTRAN issues `3RMED` to fetch
      cpu-stat's output buffer, we never fill it and SINTRAN prints whatever was already at `ABUFA` —
      **real bytes, wrong bytes**, exactly the symptom. Prediction for the pending uncapped tally:
      **MICFU 8 WILL appear**, and every occurrence is an unserviced message.

      **My own near-miss, third of the day, recorded:** I reported this handler as "implemented,
      `Nd500MicrocodeServicer.cs:1029`" one message earlier because the enum had `DataMemoryRead = 8`
      and a `case` label existed. **A case label is not an implementation.** Read to the closing brace.

      **The parameters are fully carved from SINTRAN's own code** (`MP-P2-N500.NPL:140661-140701`),
      so this is not a guess:
      ```
      140661   3RMED; *STATX XMICF                              % MIC.FUNC=READ DATA MEMORY
      140664   A:=D; *AAX NRBYT; STATX                          % NUMBER OF BYTES TO READ
      140667   *AAX 5DITN-NRBYT; STZTX                          % 5DITN := 0
      140671   *AAX OSTRA-5DITN; LDDTX; AAX N500A-OSTRA; STDTX  % ND-500 LOGICAL DATA ADDR
      140675   *AAX ABUFA-N500A; LDDTX; AAX N100A-ABUFA; STDTX  % ND-100 PHYSICAL ADDR
      140701   "STTDRIV"; *AAX SPFLA-N100A; STATX               % continuation routine in SPFLAG
      ```
      Slots (`N500-SYMBOLS.SYMB`): `N500A=7`, `N100A=11B`, `NRBYT=13B`, `5DITN=14B`, `ABUFA=140B`,
      `SPFLA=143B`, `OSTRA=44B`. **This answers the virtual-vs-physical question outright: the SOURCE
      is an ND-500 LOGICAL address and the DESTINATION is an ND-100 PHYSICAL address — SINTRAN's own
      comments — so the translation obligation is on OUR side, not SINTRAN's.**

      **DMEMRD differs from the already-working classic PHYSRD in exactly two ways** (the slot triple
      is shared, since `STOPR`/`NUMPA` = `N100A` 32-bit and `MCNO` = `NRBYT`):
      1. the source is a **logical** address in `N500A` needing MMU translation, **not** a
         `(MSWMC segment, N500A offset)` pair resolved by the PST walk;
      2. slot `14B` carries **`5DITN = 0`** instead of the physical segment select.
      So the implementation is close to a copy of the PHYSRD arm with the address resolution swapped.
      **Do NOT reuse PHYSRD's field mapping wholesale** — the code's own comment warns about the
      mirror-image mistake ("NOT the 13B/14B raw-physical copy").
      **`5DITN` PINNED, `[V]`, upgraded from `[D]` by carving all seven writers in the NPL tree:**
      every single one is a `STZTX` (store zero) — `136414`, `137175`, `140667`, `142310`, `143057`
      in `MP-P2-N500.NPL` — and `RP-P2-N500.NPL:566` spells it out: **`0=:X.5DITNO  % DEFAULT DIT #0`**.
      So slot `14B` is a **DIT (domain) number**, symbol `5DITNO`, and **SINTRAN always sends 0**.
      What is still genuinely open is only whether "DIT #0" means literally domain 0's tables or
      "default = the message's own process". **That question is decidable at implementation time and
      must not be guessed: read `CED` when the 3RMED arrives. If `CED == 0` the two readings are
      indistinguishable and it does not matter; if `CED != 0`, honour the field.**
      **Worth pinning before implementing** — if our handler translates through the
      current process's tables and SINTRAN means domain 0, that alone reproduces "real bytes, wrong
      bytes".

- [ ] **1.48 MY SWEEP USED THE WRONG TEST. RETRACT 1.41/1.43's RESULTS AND THE ORDERING FIX — the
      correct question is the GUARD question, and the answer is worse.** The ordering change I
      recommended and the peer accepted **regressed Gate5R straight back** (`TOS=0x08001A28` on the
      retry, 355,193 ISE trap-35 events) while the unit test went green — one oracle passing while the
      real lane broke. **Mine: I pushed a measured fix off in favour of a structural argument, and the
      structure I reasoned about was not this engine's.**

      **Why "commit last" is meaningless here, and it is stated in our own source.**
      `CpuND500.Trap.cs:430`: *"**Every mid-instruction memory-access commit must check
      `InstructionAborted` and bail before storing.**"* A fault does **not** unwind — it sets a sticky
      flag; `CpuND500.Memory.cs:173` then makes every subsequent read return `0` and every write a
      silent no-op, **and execution runs on to the end of the method.** So moving a commit later in the
      method changes nothing: the method still reaches it. ENTT does fault on its own writes —
      `#760 TRAP 46B pc=0x0800415A addr=0x08001800` = `trapFrameBase + 216`, the 220-byte trap data
      field straddling a page boundary — and the guard, not the ordering, is what stops the commit.

      **THE CORRECT TEST: does every path that can fault reach a commit without checking
      `InstructionAborted`?** Re-swept on that basis:

      | instruction | guards | verdict |
      |---|---|---|
      | `Ents`, `Entsn`, `Entb`, `Entf`, `Entfn` | 2, correctly placed | **SAFE** |
      | `Call`, `Callg` | 3 | **SAFE** |
      | **`Entm`** | 2 — but `regs.TOS` @146 sits **outside both** | **UNSAFE** |
      | **`Init`** | **0** | **UNSAFE** — B@110, TOS@113, L@118 all commit, no guard anywhere |
      | **`Rett`** | **0** | **UNSAFE** — 4 commits (L@165, R@166, TOS@194, B@213) |
      | **`Retb`, `Retbk`** | **0** | **UNSAFE** — commit B/L after frame reads |
      | `Retk`, `Retd`, `Entd`, `Chain` | 0 | unchecked; `Chain` shows no commits |

      **`Rett` is the alarming one and it is the return half of the pair being fixed.** It READS the
      frame, and a faulted read returns `0` (`Memory.cs:173`), so with no guard a fault mid-restore
      commits **zeros** into L, R, TOS and B. `[V]` on the shape and the return-0 semantics;
      `[OPEN]` on whether it has fired.

      **My 1.41/1.43 "the RET family is CLEAN by construction" is WITHDRAWN.** It was clean only under
      a test that assumes faults unwind. My ENTM finding survives — but for the guard reason, not the
      ordering one: the guard at 169 protects B and L, and `regs.TOS` at 146 is outside it.
      **`SplitHeapBlock`/`AllocateHeapBlock` should now be re-checked against the guard question too**,
      since a no-op write mid-split silently half-rebuilds the free lists.

      **The lesson, and it is the sharper form of today's other three:** I verified the *shape* of the
      code carefully and never verified the *machine model* the shape was supposed to protect against.
      Precision on one axis, an unchecked assumption on the other — the same failure as the `AM#12`
      base walk, and the second time today after the ENTT/Table-5 generation caveat.

- [ ] **1.49 SWEEP FINISHED — the four unchecked instructions, and a SECOND, WORSE fault class:
      a faulted read returns `0`, and in several of these `0` already MEANS something.** Read
      `Retk.cs`, `Retd.cs`, `Entd.cs`, `Chain.cs` to the closing brace. Two are clean; two are not,
      and one of them was never on my list at all.

      | instruction | memory reads | guard | verdict |
      |---|---|---|---|
      | `Retd` | none (`regs.P = regs.L`, that is the whole body) | n/a | **SAFE** |
      | `Entd` | none (reads `PendingCall*`, CPU-side state) | n/a | **SAFE** |
      | **`Retk`** | 2 (`B+0` PREVB, `B+4` RETA) | **0** | **UNSAFE** — 3 commits: P@92, L@93, B@94 |
      | **`Chain`** | 1 **per level, in a loop** @114 | **0** | **UNSAFE** — commits + a spurious trap |

      **`Retk` is the twin of `Ret`, and `Ret` IS ALREADY FIXED.** `Ret.cs:75` carries
      `if (cpu.InstructionAborted) return;` with a comment naming the bug class and citing
      *"nd500x CALL/Ret.c (commit c77a8fd), same bug class as Jumpg/Jumps and the LOOP family"*.
      `Retk` differs from `Ret` **only in setting `K` instead of clearing it** — same two reads, same
      three commits — and never got the guard. This is not a judgement call about whether the guard
      belongs; the identical routine next to it already answers that. `[V]`.

      **THE SECOND CLASS, and it is worse than committing garbage.** `Memory.cs:173` returns `0` on
      an aborted read. In these routines `0` is not a neutral wrong number — it is a **reserved
      sentinel with its own code path**, so a page fault does not merely corrupt state, it is
      **silently reclassified as a different, wrong event**:
      - **`Chain` @117**: a faulted link read gives `0`, which the manual defines as *end of chain* —
        so the walk sets `K`, writes the register, and raises **ILLEGAL OPERAND VALUE** (§15.7). A
        page fault is turned into an IOV trap. **This one matters here specifically:** `CHAIN` is the
        Pascal static-link walker (its own doc comment says so), **CPU-STAT is a Pascal program**, and
        the frames it walks are exactly the pages we have measured faulting.
      - **`Retk` @84**: a faulted `PREVB` read gives `0` → **stack underflow** trap. A faulted `RETA`
        read with `PREVB` intact gives `retAddr = 0` → commits **`P = L = 0`**, a jump to address 0.
      - **`Retb` @73/96**: `logSize` is read from the frame and handed to `FreeHeapBlock`. A faulted
        read frees the block at **order 0** instead of its real order — that is **buddy-heap
        corruption caused by a page fault**, in the same heap whose allocator this session just fixed.

      **So the guard is necessary but not sufficient wherever `0` is a sentinel.** Where the routine
      already branches on `0`, the abort check must come **before that branch**, not merely before the
      commits — otherwise the fault is consumed by the sentinel path and the guard never sees it.
      `[V]` on all four bodies and on the `0`-sentinel semantics; `[OPEN]` on whether any has fired
      live. `Chain` is the cheapest to test and the most likely of the set to be firing in CPU-STAT.

      **Final tally for the whole family — 10 safe, 8 unsafe:**
      SAFE = `Call`, `Callg`, `Ret`, `Ents`, `Entsn`, `Entb`, `Entf`, `Entfn` (guard present);
      `Retd`, `Entd` (no memory access, nothing to guard).
      UNSAFE = `Entt` (being fixed), `Rett`, `Retk`, `Retb`, `Retbk`, `Init`, `Entm`, `Chain`.

      **Lead for the ISE item, peer's, `[D]` and explicitly not measured:** `Entb.cs:169`'s comment —
      *"a fault there leaves L and the interlock untouched and the retried entry instruction still sees
      its CALL. **Without this the retry raises a FALSE ISE — the defect that killed vi through
      ENTS.**"* Same class as the trap-35 spin, with a prior fix to read.

- [ ] **1.40 WRITE UP THE GENERATIONAL SPLIT AS ITS OWN ITEM (peer's suggestion, agreed).** The
      dual-homed `SRF12` + `DPA+0x3C` shape decoded in 1.35 is **exactly the structural backstop that
      would have made 1.38 impossible on the ND-5800**: with the PCB copy authoritative, a park/reload
      mid-instruction cannot lose TOS. The classic engine has to get instruction restartability right
      by hand, and did not. Generalise before writing: **1.38 is unlikely to be the only
      non-restartable instruction** — any instruction that mutates architectural state before a long
      memory write can fault the same way. `ENTS`/`ENTSN`/`ENTB` are the obvious neighbours.

- [ ] **1.36 WHERE IT ACTUALLY POINTS: does TOS survive a page fault taken INSIDE ENTT?** ANSWERED by
      1.38 — neither of the two options I named; the re-snapshot is self-inflicted. Kept for the
      reasoning trail. The MON
      trail shows `0x0800415A` — the ENTT instruction itself — taking **four** context saves before
      completing (`#758/#761/#763/#765`, all `P=0x0800415A`), then `#776 CONTEXT SWITCH X5CPU=0→1`
      with `B=0x08001728`, the pre-ENTT B, proving it had not completed. Unsurprising: ENTT writes
      ~220 bytes into a trap data field that is not resident. So ENTT executes several times and each
      attempt re-snapshots the registers, and the value finally landing in arg21 is whatever survived
      four park/reload round-trips through the process context block. Our context block carries TOS
      at `+0x4C` and `SaveProcessContextBlock` / `StartProcessFromContextBlock` are symmetric on it —
      **but that is code symmetry, not a measurement**, and it says nothing about WHEN the block was
      last refreshed. Peer's probe prints `savedTOS` on every ENTT attempt, which separates "already
      wrong on the first attempt" (the STO dispatch lost it) from "degrades across a fault park" (the
      context round-trip lost it).

      **`want=2^10` stays open as a possible SECOND, separate defect** `[D]`. 1024 words = 4 KB, and
      my arithmetic says the month array is 27 words = order 5 — but this is the FIRST allocation the
      program makes and nobody has established what it is allocating. A 4 KB I/O buffer for `output`
      before main is entirely ordinary. Do not treat order 10 as established; and even at order 10 a
      128 KB heap should have satisfied it on the first retry, so it is not what kills the run.

      **Earlier candidates, both dead:**
      1. The ORDER computation — three float instructions decide a small integer, and `d byconv`
         (double → byte) belongs on the suspect list next to `alog2` and `int`. The log prints
         `want=2^N`, and **N is the whole answer**: for the 108-byte month array n = 27 words, so the
         correct N is **5**. Anything much larger means stop looking at the free lists.
      2. The program's own list build at `0x08004050..0x08004091` genuinely not linking anything —
         which the `FLOG:` dump separates from "grew but still trapped" directly.

- [x] **1.33b The PC → routine → MON lookup table for CPU-STAT.** `[V]`
      `E:\Dev\Ronny\ND5000UC\docs\CPU-STAT-PC-ADDRESS-MAP-2026-08-25.md` (commit `5b16f7f`). All 78
      internal call targets land exactly on a decoded instruction boundary (0 misses), so the
      address→instruction map holds across all 5117 instructions. 43 segment-31 MON call sites,
      28 distinct numbers; five of them (412B, 73B, 262B, 123B, 503B) are named independently
      elsewhere in the tree and agree, which MEASURES the "low halfword of the segment-31 target is
      the MON number" rule instead of citing it. Program text ends at `0x0800532A` — a PC at or
      above `0x0800532B` is not CPU-STAT code at all.

- [x] **1.29 The `0x203` question answered — benign.** cpu-stat probes memory by **doubling** its
      `GSWSP` request: `0x20801`, `0x40801`, `0x80801`, `0x100801` all succeed (segments 2,3,4,5);
      `0x200801` (~2 MB) returns `K=1 FUNCV=0x203`. **The only `K=1` in 8470 exchanges** — a sizing
      probe finding its ceiling, i.e. a program measuring the machine, not failing on it.

- [x] **1.17 The 4-cycles-against-1-reason count is EXPLAINED, no defect.** `SWPFU` is the
      **swapper's own request code** (`SWPDECODER` GOSW: 1=LNEWSWAP, 2=LSWPAGE, 3=LPRSUSPEND,
      4=LALLOPAGE, 5=LDATREADY, 6=LCLTSB). The measured `0x0002,0x0002,0x0001,0x0001` is the
      swapper making two page requests and two next-work requests while servicing the single
      dispatched fault — calls **TO** SINTRAN, not work items **FROM** it. 4:1 is expected.
      Also struck: my predicted serves-vs-SWPD4 gap — measured **1:1**, signature absent.

- [x] **1.12 REFUTED — "Memory not available" is a SIZE limit, not the sharing condition.**
      The ladder result (already in the log): `1000B` and `400B` refused, **`100B` ACCEPTED** —
      `Number of pages available for ND-500(0) processes: 7216B` = **3726 decimal pages, not zero**.
      A smaller rung IS accepted, so the refusal is not categorical, the manual's sharing condition
      does not apply, and the in-repo pool-size hypothesis holds. **Nothing here is upstream of the
      swapper path.** Falsified by the exact test the hypothesis named.
      `[V]` on the constant and the manual cause; **`[HYPOTHESIS]` on the consequence.**
      Gate5R has failed its goal assertion (`Does.Contain("Sintran III")`) identically all day
      (gate5r-35/36/37 byte-identical, **12 × "Memory not available" each**, pre-existing — nothing
      in the swapper work has moved it).
      - **`MEMNAVAILABLE = 2050`** (octal), `5P-P2-MON60.NPL:80`. **Defined but NEVER USED anywhere
        in the NPL tree** — so, like `SWFUN` and `MICFU:=3SWMESS`, it is raised by the paged
        **`S3SM5`** segment that is not in the repo. **Third instance of that same blind spot.**
      - **The manual names a SHARING cause, not a size cause** (ND-60.136.04A, "MEMORY NOT
        AVAILABLE FOR ND-500 SEGMENT"): *"the request could not be satisfied. This occurs when
        segments are shared with ND-100 or RTCOMMON."*

      **THE CHECK IS ALREADY IN THE EXISTING LOG — no new run.** Gate5R walks a descending ladder
      (`Nd500UCSintranBootTests.cs:1842`): `1000B, 400B, 100B, 40B, 10B`, recording `giveAccepted`
      / `acceptedPages`. The in-repo comment hypothesises the ask simply exceeds the ND-100's free
      pool on a 2 MB machine. **That is falsifiable from the log:**
      - some smaller size accepted → pool-size story holds, a tuning matter;
      - **even `10B` (8 pages) refused → NOT pool size.** A machine that cannot spare 8 pages is not
        short of memory — that is the manual's sharing condition, and **the ND-500 then owns zero
        pages.**

      **IF ZERO PAGES: nothing can be paged in, PST entries stay zero, the domain never becomes
      resident — regardless of what the swapper does.** Under that reading the whole of 1.7–1.11
      (reject code, reason byte, stale id, zero `SWPST`) is *downstream* of a machine that was
      never given memory. **Marked hypothesis deliberately** — not repeating today's habit of
      declaring a root cause from a mechanism that merely fits.
      Also: 12 occurrences vs 5 ladder asks ⇒ the message comes from more than the ladder; find
      which other commands emit it.

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
