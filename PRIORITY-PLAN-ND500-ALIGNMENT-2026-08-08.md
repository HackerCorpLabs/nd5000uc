# Priority plan: aligning every ND-500(0) CPU, the MON emulation, ACCP and the ND-100 hosts

**Full path:** `E:\Dev\Ronny\ND5000UC\PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md`
**Date:** 2026-08-08
**Built from these handoffs (all read in full):**
- `E:\Dev\Repos\Ronny\RetroCore\DOCS\ND500_COMPILE_BYTE_EXACT_HANDOFF_2026-08-04.md`
- `E:\Dev\Ronny\NDInsight\SINTRAN\ND5000\HANDOFF-ACCP-E2-PRIORITY-PLAN-2026-08-04.md`
- `E:\Dev\Repos\Ronny\RetroCore\Nuget\_shared\docs\ND5000-TRANSCENDENTAL-COS-FIXED-EXP-HANDOFF-2026-08-04.md`
- `E:\Dev\Ronny\NDInsight\SINTRAN\ND5000\HANDOFF-ACCP-CONTROL-STORE-MODEL-CORRECTED-2026-08-04.md`

---

## 1. The pieces being aligned

| # | Piece | Where | State |
|---|---|---|---|
| 1 | nd500x C functional CPU + machine + MON | WSL `~/repos/nd500x` (NOT verified on this box yet) | Reference oracle. Compiles+links HELLO. instruction_validation 100% green |
| 2 | Legacy C# `Emulated.HW` ND-500 CPU + MON | `E:\Dev\Repos\Ronny\RetroCore` (legacy tree, branch `ethernet-ii-controller-fixes`) | Compile is byte-exact with nd500x. LINK broken (LINKER-B01, PC 0xB004E762) |
| 3 | RetroCore NuGet functional CpuND500 | `RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND500` (path NOT verified) | Canonical corpus generator per memory. MON state vs legacy NOT measured |
| 4 | Microword CpuND5000 (real B30 microcode) | `RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000` + docs here in ND5000UC | 7 reds: EXP, Entt/Rett, BothEngines/StartThenMonitorCall, lregbl/lcntxt |
| 5 | ACCP high-level emulation | RetroCore octobus path (`NDBusOctobus`, station) | Working: boot to IDLE, mailbox, load-and-run |
| 6 | ACCP low-level, real 68000 + octo.bin | `RetroCore\Nuget\HackerCorpLabs.Emulation.Machines.Accp` | 141/141. Control-store model corrected. StartMicroprogram missing |
| 7 | ND-100 host, C# | RetroCore ND100Machine + octobus | Boots SINTRAN, drives ND-5000 |
| 8 | ND-100 host, C | `E:\Dev\Emulators\ND\nd100x` (verified exists) | Later: integrate with the aligned ND-500 pieces |

**UNVERIFIED (marked per the rules):** rows 1 and 3 paths, and how far the NuGet CpuND500's
MON layer diverges from the legacy one. Phase 0 measures these; nothing later builds on a guess.

## 2. The two big decisions — DECIDED 2026-08-08

- **D1 — canonical home for MON emulation: legacy `Emulated.HW`.** Every MON fix lands there
  first (byte-exact + 1963 green tests + the frame-log rig live there); the NuGet port catches
  up via P3.2 with ported tests, not by hope.
- **D2 — this session starts on the Phase 0 sweep** (all four measurements before anything else).

---

## Phase 0 — Ground truth (cheap, sizes everything, no judgement calls)

Everything here is mechanical measurement. Do it before believing anything below.

- **0.1** Verify nd500x location + that both frame-log oracles still run (C: `ND500X_FRAMELOG`,
  C#: `ND500_FRAME_LOG`). One HELLO compile each, diff, expect only the 73 benign RET hunks.
- **0.2** Rebuild the ACCP runtime counters against a **verified-good build** — the quoted
  numbers came from a stale DLL (build had failed on `DfToD`). Reconfirm 8 addressed writes,
  0/0/8 latch/staging/ring.
- **0.3** ACCP E2-P1: read the 46 `cmpi.b #imm,D0` immediates → the full command-byte map.
  Re-checks the 16 named from the ND-100 carve; turns "~30 unknown" into a named list.
- **0.4** Measure the MON gap: list which MON handlers exist in legacy `Emulated.HW` vs the
  NuGet CpuND500 vs nd500x's ndmonlib. Specifically: do 412B FSCNT auto-assign and 73B
  SMAX-at-CLOSE exist outside legacy? This is the input to decision D1.

## Phase 1 — Microword CPU: close the closable reds

Owner: microcode track (this repo + `HackerCorpLabs.Emulation.CPU.ND5000`).

- **1.1** EXP 1.0. Defect contained in `EXPF` @025702–025717 + `FWRITE_X` @027451. The
  same-word IMUL(84) override was tried and REVERTED — do not repeat it. Trace where the
  IMUL product is delivered (which later AAPSYNC word reads it) between @025703 and the
  @025710 `D,SRF16`, or confirm `k+1` from @025702 `CRYF,ONE` feeds the IMUL operand. Method:
  execute on the real B30 store and trace, raw microwords from `MICRO-5800-B30.DATA` (never
  the .md for SARG/MARG/ORCON/SCAL).
- **1.2** lregbl / lcntxt: get verified IMAP metadata for those opcodes.
- **1.3** Entt / Rett stay honestly red until the 50-arg trap-register frame is designed.
  Not on the critical path; do not fake it.

## Phase 2 — The instruction oracle (the alignment backbone)

This is what "align all the CPUs" concretely means: one corpus, three cores, zero unexplained
divergences.

- **2.1** Wire the functional-swapper oracle: functional CpuND500 vs microword CpuND5000,
  register+flag compare per instruction. This directly turns the BothEngines /
  StartThenMonitorCall reds green and gives every future microword fix a safety net.
- **2.2** Fold the microword core into the nd500x instruction_validation corpus as the third
  column (nd500x C == NuGet C# already 0/46643).
- **2.3** Work the known 3-way divergences with real-hardware datapoints where needed:
  packed-decimal Z flag (BOTH functional cores wrong — microword may be right), DIVF
  longpath 100/10, float FO/FU threshold (datapoint request already written).
- **2.4** Per-divergence tie-breaker rule: microword-on-real-B30 is the authority unless a
  real-hardware datapoint says otherwise; fix the functional cores to match, both C and C#.

## Phase 3 — MON alignment + the LINK (functional-emulator lane)

Blocked on D1 only for where fixes land, not for starting.

- **3.1** Fix the LINK: LINKER-B01 never banners, runs away at PC 0xB004E762 (segment 22).
  Use exactly the compile method: `ND500_FRAME_LOG` both sides, strip CRLF, diff to first
  divergence, then range-gated trace. First unmeasured suspect: the `:JOB` auto-files.
  Oracle: `HELLO:DOM` md5 `9ebe3f6ee899b4fa8bbb545020cdad50`, 5,810,117 instructions in C.
- **3.2** Port the two proven MON fixes (412B auto-assign, 73B SMAX-at-CLOSE) to whichever
  siblings phase 0.4 shows lack them — with the existing tests ported alongside.
- **3.3** Align the small deltas: segment>31 rejection (C rejects, C# doesn't —
  `TODO(segment-range)`), the 412B already-mapped error code (`TODO(error-code)`).
- **3.4** Standing rule: every future MON change ships with the same frame-log parity check
  against nd500x, so byte-exact never silently regresses.

## Phase 4 — ACCP: make the real 68000 card drive the shared microword CPU

The HLE-vs-lowlevel alignment. Owner: octobus/ACCP lane.

- **4.1** Implement `IControlStoreSink.StartMicroprogram` against the shared CpuND5000.
  Explicit goal from the handoff: it is the ONLY thing between here and the card passing its
  own start/stop selftest (pass = word[6] of `0x001144F0` reads `0x0100`).
- **4.2** ONE model for microprogram start: `0x0017` (68000 path) and octobus STARTMIC/ARMA
  (HLE path) must drive the same mechanism — two models of one register is exactly the defect
  the control-store correction was about.
- **4.3** E2-P2: carve the unnamed handlers, ordered by what SINTRAN actually sends (capture
  real command traffic from a boot first; no numeric sweep). **No estimate exists for this on
  purpose — do not invent one.**
- **4.4** E2-P3: lock each carved name in `AccpCommandChannelTests` as you go, per handler.
- **4.5** E2-P4: dated carve doc into `NDInsight\SINTRAN\ND5000\`; do NOT edit
  `ACCP-COMPLETE-REFERENCE.md` (another agent's live file).
- **4.6** Parked, not forgotten: the `0x03` byte (needs the Octobus Driver Programming Guide
  DVT 15 Oct 1986 or a second card's ROM — becomes top priority if either turns up), what the
  `0x330000` gate selects, the `0x330001` bits.

## Phase 5 — End-to-end: the ND-100 hosts

- **5.1** C# end-to-end gate: RetroCore ND100Machine boots SINTRAN, ND-500 monitor loads and
  runs a real program on the **microword** CpuND5000 over octobus — first with HLE ACCP, then
  the same run with the real 68000 card doing control-store load + start (4.1/4.2 output).
  Same program, same result, is the HLE==lowlevel proof.
- **5.2** nd100x C integration: define the seam (how the C ND-100 talks to an ND-500/5000
  core) only AFTER 5.1 is green. Candidates exist (nd500x already has the machine model);
  choosing is premature before the C# path proves the protocol.

## Dependencies in one picture

```
Phase 0 (measure)  ──┬─→ Phase 1 (microword reds) ──┐
                     ├─→ Phase 2 (oracle) ←─────────┘  (2 wants 1.1 but can start now)
                     ├─→ Phase 3 (MON + LINK)          (independent lane)
                     └─→ Phase 4 (ACCP)                (independent lane)
Phase 2 + 4 ─→ Phase 5.1 (C# end-to-end) ─→ Phase 5.2 (nd100x)
```

Phases 1+2, 3, and 4 are three parallel lanes (matches the existing session-lane setup).
Phase 5.1 is the convergence gate; 5.2 waits for it.

## Standing rules carried over from the handoffs (apply everywhere)

- Frame-log diff first, full trace only range-gated around the divergence.
- Assert the build succeeded before believing any test number (stale-DLL trap, twice now).
- A probe that cannot tell its two hypotheses apart is not evidence.
- A green suite proves the outcome, not the reason — counters that name the path do.
- Check for a hard-coded immediate before believing a printed number was computed.
- Delete diagnostics after use.
- On this box: build/test single projects with `/p:UseSharedCompilation=false` (full-solution
  builds OOM), and finish with `dotnet build-server shutdown`.
