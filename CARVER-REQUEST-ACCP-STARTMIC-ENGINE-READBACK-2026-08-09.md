# CARVER-REQUEST: run the microengine on ARM + expose its result to the ACCP link read-back

**Full path:** `E:\Dev\Ronny\ND5000UC\CARVER-REQUEST-ACCP-STARTMIC-ENGINE-READBACK-2026-08-09.md`
**From:** octobus/ACCP-link session (task #11, P4.1)
**To:** microword-CPU session (owns `CpuND5000` internals)
**Date:** 2026-08-09

## Result / what this asks for

The 68000 ACCP card's **start/stop microprogram selftest** is the last gate before the
card's own bring-up passes. I carved it end to end and wired the ACCP control-store link to a
**real `CpuND5000`** (committed `ed00a037c`, RetroCore, branch `ethernet-ii-controller-fixes`).
The mechanism works; the selftest still fails because **two things inside `CpuND5000` are needed**
and those are your lane:

1. **The engine must RUN when armed.** On the first `Tick()` after `State.Mpc = <arm addr>` it
   throws `Test condition TESTOBJ=29 not implemented yet` (also 30/31 are gaps — the published
   COND tables jump 28 → 32). The firmware arms at address 0 and at `0x3FF0`; those words execute
   as microcode and hit condition 29 immediately.
2. **The link's read-back must return the engine's RESULT, not the stored control-store word.**
   The selftest's ONLY pass condition is `word[6]` of the 8-halfword read-back at `0x001144F0`
   equal to `0x0100`, and that value is **produced by the running microengine**, then shifted back
   in — it is not written by the 68000 anywhere (proven below). The link currently serves read-back
   from `IControlStoreSink.TryReadWord(address)` = the stored CS bits, whose `word[6]` is 0.

## The carve (octo.bin, verified in Ghidra 2026-08-09)

Caller of the test, `0x0000CD64`:
```
cd64  moveq  #0,D0
cd66  jsr    0x7A66          ; START  (arm-worker 0x78CA: issues 0x0017 then 0x0015, latch; sets flag 0x1143AC=1)
cd6c  jsr    0x78B2          ; WAIT   (spin on 0x660000 bit 4 = "microengine done")
cd72  jsr    0x7A84          ; STOP   (0x795A: twiddles 0x330001 latch bits only; clears flag 0x1143AC)
cd78  jsr    0x775A          ; READ-BACK verify: issue 0x2010, then 0x77B6
cd7e  moveq  #12,D0
cd80  lea    0x001144F0,A0
cd86  cmpi.w #0x0100,(0x0,A0,D0)   ; buffer word[6] must be 0x0100  -> beq PASS
```
Read-back worker `0x77B6`: loop 8× { clock pair; `move.w #0x2011,(0x220000)`; `move.w (0x550000),(A3)+` }.
So each of the 8 read-back halfwords is whatever the card presents at `0x550000` after a `0x2011`
shift-in command — on real hardware that is the microengine's output register after it ran and
stopped, **not** the control-store contents.

`START 0x7A66` and `STOP 0x7A84` write no `0x0100` anywhere; confirmed by full disassembly.

## Measured engine behaviour (committed test `Nd5000RealCpuStartTests.cs`)

Boot with the real-CPU sink dumps the firmware's own test words and the ARM outcomes:
```
WRITE @0o0      hi=564051AF4C92BB59 lo=8BB40393542650DD   (CS sample-test pattern)
WRITE @0o37760..64  (sequence-test jump chain, lo halves 3FF0 3FF1 3FF2 3FF3)
WRITE @0o37760  hi=40400001DE028018 lo=0                  (final)
START @0o0      ticks=0 stop='Test condition TESTOBJ=29 not implemented yet'
START @0o37760  ticks=1 stop='Test condition TESTOBJ=29 not implemented yet'
verdict block @0x001144F0: [0]=4040 [1]=0001 [2]=DE02 [3]=8018 [4..7]=0000  ; word[6]=0000, want 0100
```
Raw SHIFT burst before the final commit is exactly `{4040,0001,DE02,8018,0000,0000,0000,0000}` —
so there is **no link-side assembly bug**; the missing `0x0100` is purely engine-side.

## Exactly what I need from `CpuND5000`

- **A.** Implement `Conditions.Evaluate` for TESTOBJ **29, 30, 31** (whatever they are — likely
  instruction-type / AAP; adjudicate from B30 + a real run, the way COS/EXP were settled). Enough
  that the firmware's start/stop test microprogram at address 0 and `0x3FF0` runs to a stop instead
  of throwing.
- **B.** A way for the ACCP link to read the engine's **result register after a run** — the value
  the real card presents at `0x550000` for the `0x2011` shift-in. Cleanest shape: extend
  `IControlStoreSink` with e.g. `bool TryReadEngineResult(out ulong hi, out ulong lo)` that returns
  the post-`StartMicroprogram` MIR / status word (whatever holds `0x0100` at halfword 6 after a
  clean start+stop). I will wire the link's `ReadData` to prefer it after an ARM.

## What is already done on my side (do not redo)

- `IControlStoreSink.StartMicroprogram(address)` is called by the link at the `0x0017` ARM
  (`Nd5000ControlStoreLink.cs` ~line 628).
- `Nd5000RealCpuStartTests.cs` (committed) is the harness: real `CpuND5000` sink, boots the card,
  reports the whole start/stop story, has the SHIFT/COMMIT/VERIFY link trace.
- The link now logs each ungated `SHIFT` halfword (trace-gated), so the burst is inspectable.

## Wrong turns — do not repeat

- **`0x00FF` is a canned EPROM literal**, not a measurement (settled twice already,
  `HANDOFF-ACCP-LINK-SEAM-CONTRACT-2026-08-04.md`). The pass condition is `word[6]==0x0100`, nothing
  else.
- **Do not fabricate the `0x0100`** in the link (the link's own comments warn against this): a faked
  pass hides that no microengine ran.
- The read-back burst is byte-correct out of the link — do not re-hunt an assembly/off-by-one bug
  there.

Related: `nd5000-session-coordination`, `nd5000-load-and-run` (the `MSG_START` context-load +
EXECUTE pattern is the existing run mechanism to reuse for A/B), `HANDOFF-ACCP-LINK-SEAM-CONTRACT-2026-08-04.md`.
