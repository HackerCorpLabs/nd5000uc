# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here. Measurements and refuted theories live
in the dated evidence records; this is what is left and how to attack it.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns **ND-500 / classic 3022**
(#49, #66, the DOM corpus). Their items are not in this file.

---

## Next

**Read `Machines.Accp`'s existing tests before touching #78.** The ACCP-to-ND-5000 control-store
link is already carved, modelled and tested there against the firmware's own microcode — so
SINTRAN's failing `LOAD-CONTROL-STORE` is almost certainly NOT that seam, and the harness has been
looking at the wrong end.

---

## THE RULE THAT JUST COST A DAY  (2026-08-30)

> **`ls -d */` in `RetroCore\Nuget` BEFORE building a harness, an attach, or a probe.**
> Ronny: *"dont forget about the fucking machines that are relevant to what we are doing.
> dont duplicate code."*

There is a whole `HackerCorpLabs.Emulation.Machines.Accp` — a real ACCP machine with
`AccpBootTests`, `AccpConsoleTests`, `AccpSelftestStatusTests`, **and**
`Nd5000ControlStoreLinkTests`, `Nd5000CsaFailureTraceTests`, `Nd5000FirmwareLoadTests`,
`Nd5000AttachedMachineTests`. I attached the ACCP by hand inside the octobus boot harness, watched
a boot marker not arrive, and wrote up "the real ACCP stops SINTRAN booting" — while that machine's
own suite prints:

```
CPU model: ND-5900
Communication ACCP-ND100 started. Version: December 5, 1988
ACCP:                       console port took CR: True   ECHOED / RESPONDED: YES
```

**And there is a FAST layer I was not using.** From `Nd5000ControlStoreLinkTests`' own header:
*"They run in milliseconds; booting the real firmware to reach the same code takes about twenty
minutes, so the fast path is where the protocol gets pinned down and the slow boot is kept for
confirming it end to end."* Every measurement this week was a 30-minute boot.

Memory: `check-existing-machines-before-building`.

---

## STANDING RULE — EVERY ROUND RUNS TWICE  (Ronny, 2026-08-29)

> *"you always run one round with macro CPU and then another with microcode and accp with 68k cpu
> to find out what the real hw would do and then try to replicate that in macrocode. dont assume
> shit, go measure, use logging and analytics"*

One switch on ONE test: `RETROCORE_ND5000_ROUND` = `""` | `hw-cpu` | `hw-accp` | `hw`.
**Round 2 is the ORACLE.** Diff the rounds; the difference IS the bug list. Never report a
macro-only conclusion.

**The one exception:** the ND-5000 **MMU walk is HARDWARE** — microwords only SELECT it — so a
page-fault question is settled by neither round alone. Read round 2 with `ND-05.020.01` beside it.

**A harness OUTCOME field is not a result.** `place-domain=returned` was an ERROR path that
returned faster because it failed earlier. Only the console says what the machine did.

---

## THE TARGET

Real ND-500/ND-5000 programs on the emulated CPU, driven by **REAL SINTRAN III on the emulated
ND-100**, with every MON call **FORWARDED over the octobus**. A run our C# `SintranEmulation`
answers **does not count**. Before believing any "it runs" claim: **who answered the MON calls?**
Mechanical guard: `EmulatedMonPathMarker.Count` must be **0**, and the harness asserts it. Path
table: `RetroCore\Emulated.HW\ND\CPU\ND500\Servicer\MON-PATH-LEDGER.md`.

---

# A. The octobus lane — THREE bugs, and the order changed

The two-round rule produced the ordering. One of the three then evaporated on contact with the
existing test suite, which is why this section is rewritten rather than amended.

### A1. #78 — SINTRAN's `LOAD-CONTROL-STORE` fails against the real B30  ← **START HERE**

Measured on `hw-cpu` (real B30 microword CPU, hand-written ACCP), full transcript:

```
> Loading Control Store
Error when loading Control Store.
 *** FATAL SYSTEM ERROR ***     ND-500(0) error: ND-500(0) timeout
MAR 00000000000    MICRO P: 00000177777          <- all ones: the microprogram is not running
```

The functional `CpuND500` sails through the same load, which is why this was invisible while the
macro round was the only round.

**Do this in order, and the first two steps are minutes, not hours:**

 1. Run `Nd5000ControlStoreLinkTests` + `Nd5000AttachedMachineTests` (milliseconds). They pin the
    carved firmware register sequence and prove the windows are mapped where the firmware reaches
    them. `0x660000` bit 0 "control-store operation OK" is **earned** there — set only when a full
    128-bit microword really reached the sink.
 2. Run `Nd5000FirmwareLoadTests` (minutes). It boots real `octo.bin` and compares against the
    **firmware's own** microcode — `LoadSelftestMicrocodeIntoControlStore` @`0xB16E`, a PLANC
    2-D descriptor at `0x13C18`, origo `0x13C30`, 3072 records of 8 x 16-bit = 3072 microwords.
    An oracle that is not my reading of anything.
 3. **Only if those are green** is the defect in OUR octobus lane rather than the ACCP link — i.e.
    in `OctobusND5000Station` / `NDBusOctobus`'s CSLOA path, or in how the harness wires the
    microword CPU in as the control-store sink. Narrow it there, not in a boot run.

### A2. #79 — the macro round is LIVELOCKED

An exactly-repeating **8-write cycle at PIL 2, ~82,000 times**:

```
0x42810C := 0x0000   GETC5+5      (cache-defeating BSET)
0x42890C := 0x00FF   GETC5+7      (X5PRO, ext+0x0C)
0x428820 := 0x00FF   RDDMT+18     (32-bit cell)
```

Geometry: `header=0x00428800 extBlock=0x00428900`. Windows 8-15 of the phase profile are 2.4M
writes of one repeating pattern — 40% of the run.

**`GETC5PROC` is NOT the defect.** It is documented as a read and genuinely writes: two
`*BSET BCM 120 DX; LDATX` pairs commented *"Fool the cache"* (`CC-P2-N500.NPL:657`), touching an
address `0x800` away to force eviction. Our ND-100 records them correctly. **Do not "fix" it.**

**Open: WHO CALLS IT.** Nine call sites across three NPL modules. Instrument built and committed
(`a7de69017`): `CpuND100.DiagCurrentL` carries the `JPL` return address into the write log, and the
dump prints a **caller histogram** keyed on it. No offset arithmetic, no adjacency guessing.

### A3. #81 — NOT a bug. Harness timing.

`RunUntil(marker, 300_000)` counts **host wall-clock milliseconds, not emulated cycles** — its own
comment says so. A 68000 at `instructionsPerClock: 64` exhausts that budget with nothing broken.
Re-measure with the window raised and/or the rate lowered, and **report timing separately from
correctness**. Not a blocker for anything.

### A4. #72 — fix at the cause, blocked on A2

Blocked until the caller is named. Explicit do-nots: do not "make `5ACTSWAPPER` run" (it already
does — measured `callers=1 entry=1 outcomes=1`); do not fix `GETC5PROC`; do not pick its caller by
proximity. The regression test must be **run red first** against deliberately broken code, and the
failing line checked.

### A5. Do NOT redo these

 - `BSWSTARTED` is refuted (`bailed=0`). `5ACTSWAPPER` and the swapper both behave correctly at
   every measured point. The old "the swapper is never handed work" framing is **wrong**.
 - "No page fault is raised" had a **wrong premise**: nothing outside segment 1 was ever
   translated, so the fault path is unreached, not defective.
 - The swap file is not the variable; `SWPPING` is ND-100 bookkeeping; `SWPFU=4` is not a
   discriminator; MON 377B is not a swapper-activation call.
 - The history does not build, so a bisect cannot run.
 - Do not re-measure the stall, and do not carve more microcode for it.

---

# B. The microword oracle — #51 is NOT what its title said

`MacroOracleState.Diff()` **already** compares P, L, R, B, X1-4, A1-4, E1-4, Z, S, C, O. `K` and
`Pia` are excluded **deliberately and documentedly** (carried for seeding/observation; the goldens
never seed them) — that is not a hole.

**What is actually left is register MODELLING, upstream of any diff change:**

 - functional `CpuND500` has **TOS, LL, HL, THA**.
 - microword `CpuND5000` has `IduLl`, `IduHl`, `IduTe`, `IduLimc` — and **no TOS, no THA**.
 - So TOS/THA cannot be diffed until they are modelled on the microword side; and whether
   `IduHl`/`IduLl` **are** the architectural HL/LL is **UNVERIFIED**. Establish that from the
   microcode or the manual FIRST — *a diff between two registers that are not the same register
   manufactures divergences.*

Then #50: per-divergence adjudication of the 246 divergences + 31 trap-bit misses on the widened
diff. Never auto-trust either engine; the B30 store is the reference, not either CPU.

---

# C. #75 — single-float `-0.0` TEST, S=1 vs S=0

**Carved 2026-08-30 from the RAW `MICRO-5800-B30.DATA`:** `TESTF` (0o3000) and `TESTD` (0o3002) are
the **same microcode** — identical words differing only in `ABS_ADDR` (0x0601 vs 0x0603, each
jumping to its own continuation); 0o3001 and 0o3003 are **byte-identical** and both jump to
`0x0679` = **0o3171 = `TESTFD`**. Both carry `DATATYPE = 7 = TYP,DR` — *"data type controlled by
ICA"*.

**So the TEST body has no per-width behaviour for the chip to be faithful to**, which turns the
"self-inconsistent with the double path" suspicion into evidence pointing at our engine.

Left: execute `TESTFD` @0o3171 with the recording-`IMicroMemory` decorator for both widths and
record whether the sign is sampled **before or after** the `ALU,AND A,SRF4` mask (`&0x7FC00000`).
Mind the **one-word condition delay**. Then adjudicate with Ronny — do NOT auto-fix.

---

# D. Deferred, honestly

 - **#74** — the nd100x C ↔ ND-500 core seam. Gated on A; earlier means defining a seam against a
   lane that does not run.

---

## Where the evidence lives

| what | where |
|---|---|
| Item-level status + the counts Ronny reads | the task list (`TaskList`) |
| The octobus investigation, every refuted claim included | `docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md` — §14 on |
| Run-a-program track | `PRIORITY-PLAN-2026-08-25-RUN-A-PROGRAM.md` |
| Cross-core alignment track | `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md` |
| Every existing trace switch | `DIAGNOSTICS.md` — check before building an instrument |
| Who owns which lane | `OWNERSHIP.md` |

---

## Rules that have actually cost time here

- **Check `RetroCore\Nuget` for an existing machine BEFORE building anything.** Newest and most
  expensive; see the box at the top.
- **Never conclude about a component from YOUR ad-hoc wiring of it.** "Did not finish in the
  window" and "does not work" are different claims.
- **CARVE, DON'T GUESS** — from `GROUND-TRUTH.md`, or mark it `[OPEN]`.
- **Read `docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md` first** for anything about
  ND-100↔ND-5000 messaging. The trigger is "I wonder", not "I am about to derive".
- **An NPL listing address is not a linked address, and the offset is PER MODULE.** `MP-P2-N500` is
  **+0o200**; `CC-P2-N500` is **+0o17**. Applied out of habit, the wrong offset lands on a different
  routine that is every bit as plausible. Pin symbols that BRACKET the routine.
- **`l07-kallsyms.txt` is HEX and 1,420 of its addresses carry MORE THAN ONE symbol** (9% of 15,799
  lines). A one-name lookup flips a coin between real aliases. Use `pcsym.py`, which prints all of
  them.
- **A capped log is self-consistent.** A total-vs-total check cannot catch saturation; ask
  separately whether the log hit its cap. Two runs that did DIFFERENT things producing the SAME log
  is the sharpest test that a capture never reached its subject.
- **A count with no denominator can only be believed, not checked.**
- **Ask what a NULL result would tell you before asking for the measurement.**
- Microcode addresses are **OCTAL**; read ORCON/MARG/SARG/SCAL from the RAW `MICRO-5800-B30.DATA`.
- **SINTRAN IS ALWAYS OCTAL**, in and out. The only tell is the `B` on the echo.
- **Shared-tree hygiene** — stage exact paths, never `git add -A`. Two sessions, one checkout.
- **No new branches without written permission.**
- **Status headings in this tree have lied.** Check the code before investigating anything marked
  open; more than half the time it is already done. This applies to a task you are about to CREATE.
- **A test never seen red is not evidence.** Run it against broken code and check WHICH LINE fails.
