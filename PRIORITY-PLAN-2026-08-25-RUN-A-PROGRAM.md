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
