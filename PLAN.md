# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns **ND-500 / classic 3022**
(#49, #66, the DOM corpus).

---

## Next

**B9 — validate `start-swapper`.** B1 is CLOSED (root-caused, section 23: it is the designed
"control store not loaded" gate, and `3RMICV` is answered 100+ times once the store is loaded).
The `start-swapper` ladder run is the first thing that has never been measured on this pack.

---

## THE THREE RULES THAT ORDER THIS FILE  (Ronny, 2026-08-30)

> **1. "prioritize fixing known bugs before hunting features. because a feature may never ever
> work because of known bugs."**

A known bug upstream of a feature makes that feature **unmeasurable** — you cannot tell "not
implemented" from "fine, but the bug ate it". So the feature work below does not start while a
known bug sits upstream of it. Known = **measured and reproducible**. A theory is not a bug; it
goes in the investigation list.

> **2. "dont dismiss error as noise."**

Every error line in a transcript is a bug until root-caused. I dismissed
`INFO * 0B:6B * SINTRAN III File System / Not used` as noise on every single read of every single
transcript. It is listed below as B2 and it is not noise.

> **3. "all bugs are to be root caused and fixed, not ignored."**

No bug gets closed as "benign", "expected" or "cosmetic" without a root cause written down.

> **4. "ANALYSE THE DATA. DO NOT GREP FOR WHAT YOU ASSUME IS IN IT."** (RULE #0b, standing)

Reading all 60 lines of one transcript surfaced four bugs that a week of grepping for
`Error when loading Control Store` never found. Dump the whole thing, read every word, say what
each line is.

---

# KNOWN BUGS — root-cause and FIX, in this order

Every one of these is measured and reproducible on `DOMS-CSFIX.IMG`. None may be dismissed.

### B1. `N5TIMOUT` before any command — **CLOSED 2026-08-30, root-caused, NOT a bug**

```
@nd-500
ND-500/5000 MONITOR  Version J04 88. 6.16 / 88. 8.17
ND-5000 timeout:      ACCP was terminated; Microprogram has stopped
```

Fires on entry to the monitor, **before** `define-swap-file`, **before** `place-domain`, in
**every** run — macro, `hw-cpu`, `hw-accp`, and the ones I called working. This is the `3RMICV`
watchdog going unanswered (`MP-P2-N500.NPL:1209` stamps it into the WATCHDOG buffer and arms a
timer; the check is `RP-P2-N500.NPL:127642` → `N5TIMOUT` → `RSTARTALL`).

**ROOT CAUSE (section 23 of the standoff doc), closed rather than dismissed:**

The capture's own line numbers settle it — the timeout is at line 32, `> Loading Control Store` at
line **39**, seven lines later. **At line 32 no control store has been loaded yet.** Neither ND
generation has microcode ROM; the store is RAM and empty until `LOAD-CONTROL-STORE`. So nothing can
answer, and *"Microprogram has stopped"* is TRUE about the machine at that instant.

It is the DESIGNED trigger, not a fault: `RSTA5` bit 9 `5CLOST` (*"micro clock stopped = CS NOT
loaded"*) -> `ECSLOAD 2032B` -> the monitor prints *"Loading Control Store"* and auto-loads. Line 32
CAUSES line 39.

**And the "3RMICV goes unanswered" mechanism is refuted by the same run:** the servicer trace shows
`MICFU=0x01 3RMICV` answered repeatedly with `MicroVersion=0x2E9A`, plus `CACHE` and `PHYSWR`
serviced, `polls=124072`, `active(x5act==0)=105`. The mailbox works after the CS load.

**B3 (`MAR=0`) and B4 (`N500 STATUS 000000`) are read from the SAME fatal report at the SAME moment**
- check their timestamp before treating them as separate bugs.

### B2. File-system error DURING the control-store load — **NOT NOISE**

```
> Loading Control Store
INFO * 0B:6B * ... * BAK01.37603B
      SINTRAN III File System
      Not used
```

Subsystem `0B`, error `6B`, while SINTRAN reads `CONTROL-STORE:DATA` off the pack. Present on
**both** the macro and `hw-cpu` rounds. Root-cause it: what is `0B:6B`, what is `BAK01` doing at
`37603B`, and what is "Not used" reporting. Related thread: the FATAL in B8 runs through the file
system too.

### B3. `MAR 00000000000` — no message address ever latched

The MAR holds the message's ND-100 **word** address; the emulator byte base is
`(MAR & 0xFFFFFF) * 2`. A zero MAR means no message was ever pointed at, which is exactly why the
answer never arrives and it times out. Almost certainly the same root as B1 — prove it or separate
them.

### B4. `N500 STATUS 000000` — status reads all zeros

Nothing set: not busy, not finished, no `5CLOST`, no page-fault bit. The bus reference already flags
this shape: *"Emulator: STATUS reads 0 on reset/idle → bit 9 clear → no download ever attempted."*

### B5. `MICRO P: 00000177777` — micro P all ones, microprogram not running

### B6. `hw-cpu`: `Error when loading Control Store`

Real B30 microword CPU + hand-written ACCP fails the CS load where the macro round succeeds — same
pack, same bytes.

**REFUTED, do not re-derive:** the staging-buffer-vs-real-store checksum theory. I changed the
checksum source (`00ba80ca9`), rebuilt, re-ran — **three identical failures, no change**. That
commit is a defensible tidy-up (one hardware, one model) and is **NOT** the fix.

**Also ruled out by measurement:** the ACCP link (`Machines.Accp` 142/142 green, including
`Nd5000ControlStoreLinkTests`, `Nd5000FirmwareLoadTests`, `Nd5000AttachedMachineTests`); and the
pack image — `(SYSTEM)CONTROL-STORE:DATA` is **byte-identical** to `MICRO-5800-B30.DATA`
(md5 `f8d28677…`), 16384 × 16, version word `0x2E9A`, model word `0x0038` = type 3 / ND-5800. It IS
the ND-5000 microcode.

### B7. macro: `> Allocating memory` is never reached

The macro round DOES load the control store and DOES reach `> Loading Swapper`. It stops between
that and `> Allocating memory`. (Earlier framing of this as "place-domain stalls, nothing works" was
wrong and hid that the first two steps succeed.)

### B8. `FATAL 21B:77B` runs through the FILE SYSTEM

```
FATAL * 21B:77B * ... * 147421B.12331B
       ND-500(0) Monitor Internal
       Fatal internrun
```

`0o147421` resolves at **offset 0** to `CSTCK` / `5CSTC` — *"CSTCK: FILE SYSTEM CURRENT STACK
POINTER"* (`CC-P2-COMMON.NPL:403`). `0o12331` = `9FLER+4`, inside SINTRAN's error logger. Same
file-system thread as B2.

### B9. `start-swapper` has never been seen to produce output

The full-flow capture ends at the command itself. **And the test I ran all week was
`ShortBringup_Octobus_NoStartSwapper_...`, which skips it deliberately.** Run
`FullFlow_Octobus_Login_Nd500_Status_StartSwapper_Capture` on `DOMS-CSFIX.IMG` — the Aug-28 capture
predates both that pack and every change since, so it is stale.

### B10. PROCESS BUG: I committed a fix without testing it

`00ba80ca9` was written on a theory, committed, and only then tested — where it changed nothing.
**Red-first, always:** run the test against the broken state, watch it fail, and check WHICH LINE
fails, before committing a fix.

---

# THE METHOD FOR THE MICROCODE QUESTIONS  (Ronny, 2026-08-30)

> *"analyse microcode. talk to llm for 500, run the compare logic running 5000 microcode cpu,
> then 500 macrocode."*

For anything about what the machine actually DOES: **run the differential oracle** — the microword
`CpuND5000` on the real B30 store, then the functional `CpuND500` macrocode, and diff. The B30 store
is the reference; neither CPU is. Surface both states plus the microcode or manual citation, and
adjudicate per divergence.

Existing machinery: `MacroInstructionOracle.RunBoth`, `MacroOracleState.Diff` /
`DiffSemantic`, `MacroStepTests`, `MailboxOracleRunner`. Technique for a single routine: set
`cpu.State.Mpc` to the entry found by NAME in `MICRO-5800-B30.LABE`, wrap `IMicroMemory` in a
recording decorator, and read the write trace — that IS the answer, no field inference.

**Read RAW `MICRO-5800-B30.DATA` (16 B/word at `octal_address * 16`), never a rendered `.md`** — the
`.md` mis-renders ORCON/MARG. Mind the **one-word condition delay**: a word's `COND,*` tests the
PREVIOUS word's flags, and a naive read comes out shifted by one and still looks plausible.

---

# FEATURES — BLOCKED, and by what

Not started while the bug above them is open.

| feature | blocked by |
|---|---|
| Run a `.DOM` under real SINTRAN over the octobus (**THE GOAL**) | B1, B6, B7, B9 |
| #72 fix-at-the-cause + regression test | B7 (cause not identified) |
| ~~#74 nd100x/nd500x C ↔ ND-500 seam over ndbus/octobus~~ | **OUT OF SCOPE THIS PHASE** — see below |

### #74 IS A LATER PHASE — do not start it, do not "prepare" for it

> **Ronny, 2026-08-30:** *"integrating nd100x and nd500x over ndbus interface or octobus IS NOT to
> be done now. That is a phase AFTER we have validated and tested RetroCore with 500 and 5000 cpu
> thoroughly with nd-500-mon."*

This is not "blocked and waiting" — it is out of scope until the gate below closes.

**THE GATE:** RetroCore's own ND-500 and ND-5000 CPUs validated and tested **thoroughly against
`nd-500-mon`**. That is the present phase, and it is exactly what the known bugs above are.
Defining a seam against a lane that does not yet run means defining it against broken behaviour.
| #50 adjudicate oracle divergences | #51 |

### #51 — register modelling, NOT diff-widening (title was wrong)

`MacroOracleState.Diff()` **already** compares P, L, R, B, X1-4, A1-4, E1-4, Z, S, C, O. `K` and
`Pia` are excluded **deliberately and documentedly** — not a hole. What is actually missing:
functional `CpuND500` has **TOS, LL, HL, THA**; microword `CpuND5000` has `IduLl`/`IduHl`/`IduTe`/
`IduLimc` and **no TOS, no THA**. Model them first, and **verify whether `IduHl`/`IduLl` ARE the
architectural HL/LL** — a diff between two registers that are not the same register manufactures
divergences.

### #75 — single-float `-0.0` TEST, carved 2026-08-30

`TESTF` (0o3000) and `TESTD` (0o3002) are the **same microcode**: identical words differing only in
`ABS_ADDR`, converging on `TESTFD` @0o3171, both `DATATYPE = 7 = TYP,DR` ("controlled by ICA"). So
the TEST body has **no per-width behaviour** for the chip to be faithful to — which points at our
engine. Left: execute `TESTFD` for both widths, record whether the sign is sampled before or after
the `ALU,AND A,SRF4` mask (`&0x7FC00000`), then adjudicate. Do NOT auto-fix.

---

# RETRACTED — do not re-adopt

 - **"The lane is livelocked."** The 82,000-iteration 8-write cycle is SINTRAN's **histogram
   sampler** (`MP-P2-N500.NPL:133230` `MIN "5HIDATA".S1 % Increment total number of samples counter`
   → `133235 CALL GETC5PROC` → classify `LACTIVE/LIDLE/LSWPWAIT/LSWPPING/LCPU/LINMCALL`). A periodic
   sampler ticking means **TIME PASSED**, nothing more. **Ranking an instrument by volume ranks by
   elapsed time**, so the top entry is usually the clock, not the bug.
 - **"The real ACCP stops SINTRAN booting."** It boots; suite 142/142. That was my harness's
   wall-clock window (`RunUntil` counts host milliseconds, not cycles).
 - **"`0x45A000` is a reused buffer."** Measured on a log capped at 17% of the run.
 - **`GETC5PROC`'s writes are a bug.** They are deliberate cache-defeating `*BSET BCM 120 DX`
   read-modify-writes (`CC-P2-N500.NPL:657`, *"Fool the cache"*). Do not "fix" them.
 - **`BSWSTARTED`**, **"the swapper is never handed work"**, **"no page fault is raised"** (nothing
   outside segment 1 was ever translated — the path is unreached, not defective).

---

## Rules that have cost time here

- **Known bugs before features. No error is noise. Root-cause and fix, never ignore.**
- **Check `RetroCore\Nuget` for an existing machine BEFORE building anything.** There is a real
  `Machines.Accp` with a green suite, and a **fast** layer: its own tests say *"they run in
  milliseconds; booting the real firmware takes about twenty minutes"*. I used 30-minute boots for
  everything.
- **Never conclude about a component from YOUR ad-hoc wiring of it.**
- **A harness OUTCOME field is not a result** — `place-domain=returned` was an error path that
  returned faster because it failed earlier. Only the console says what the machine did.
- **An NPL listing address is not a linked address, and the offset is PER MODULE**: `MP-P2-N500`
  **+0o200**, `CC-P2-N500` **+0o17**. Prefer resolving a SYMBOL NAME over doing the arithmetic.
- **`l07-kallsyms.txt` is HEX, and 1,420 of its addresses carry MORE THAN ONE symbol** (9% of
  15,799). Use `pcsym.py`, which prints every alias.
- **A capped log is self-consistent** — a total-vs-total check cannot catch saturation. Two runs
  that did DIFFERENT things producing the SAME log proves a capture never reached its subject.
- **A count with no denominator can only be believed, not checked.**
- Microcode addresses are **OCTAL**; **SINTRAN IS ALWAYS OCTAL** (the only tell is the `B` on the echo).
- **Shared-tree hygiene** — stage exact paths, never `git add -A`. Two sessions, one checkout.
- **No new branches without written permission.**
- **A test never seen red is not evidence.**
