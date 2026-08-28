# Priority plan — ND-500(0) alignment

> **ENTRY POINT IS `PLAN.md`** (no date in the name, so the pointer cannot go stale).
> This file is the cross-core alignment track.
> Outstanding work lives in `PLAN.md` and the task list; this file keeps the measurements
> and the refuted theories, which is what stops a closed question being re-opened wrongly.

**Full path:** `E:\Dev\Ronny\ND5000UC\PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md`
**Cleaned:** 2026-08-18 (done work stripped out; only open todos remain).

## DONE means (the bar this whole plan aims at)

1. **MON calls work END TO END through REAL SINTRAN** (Ronny, 2026-08-18): a program running on the
   microword ND-5000 (`CpuND5000`) makes a segment-31 MON call → it travels the mailbox/octobus into
   the **REAL booted ND-100 SINTRAN monitor code** → SINTRAN services it and returns the **correct
   values** → the ND-5000 CPU **resumes and keeps executing** with those values. A no-op / recording
   MON sink in a unit test is NOT this - it only proves the CPU reaches a MON. The acceptance test is
   the integrated boot (real ND-100 + SINTRAN + microword CPU over octobus).
2. **We can load DOM code into a NEW domain** via the `nd-500-mon` path (PST + DIT + capabilities +
   code/data in mapped pages) and run it under real MMS translation - THEN its MON calls satisfy (1).

Nothing is "done" until both hold. CPU-side synthetic-domain milestones (load, run, reach a MON) are
progress and a fast dev harness, NOT the finish line - the finish line has real SINTRAN in the loop.

## Where things stand right now (what already works — don't re-do)

- Boot to `SINTRAN III RUNNING` with the microword ND-5000 attached over octobus; ACCP/mailbox,
  CS-load, STARTMIC, `MSG_START` load-and-run.
- **Swapper runs under real MMS translation.** Fetch-side (caps-via-PS root cause) and data-side
  (all virtual data-access paths) both fixed this session. CPU.ND5000 suite 690 pass / 0 unexpected.
- MON-call seam (`CALLG` seg-31 → `MonitorCallSink` → park → service → resume) + the octobus service
  loop; a real `cpu-stat.dom` loads and marches its MON sequence — but **flat (MMS off)**, not yet in
  a mapped domain.
- 3-core instruction oracle (nd500x C == NuGet C# == microword) green on integer + float except the
  known divergences in P3 below.

---

## P1 — Swapper green under MMS  ← CURRENT

The swapper is the first program the machine runs; getting it to its steady state proves fetch +
data + MON all work under translation.

- [ ] **1.0** CAP THE BOOT PROBE. With the data-path fix the swapper runs far more real code per
  bounded pump, so the full boot now runs 2h+ and holds the CPU/HW DLLs locked (blocking all other
  builds). Add a tick/pump cap + a "how far did P get" report so a confirming boot TERMINATES and is
  usable. (The uncapped boot was killed 2026-08-18; the fix is unit-validated, so this is about making
  the integration check practical, not re-finding the fix.)
- [ ] **1.1** Confirm (via the capped boot) the swapper advances past the old `Mpc=0o220 / P=0x080081B2`
  OOB. Fix already unit-validated (690 pass) + the killed boot ran ~2h with NO early throw (a crash
  throws + logs fast), which is positive evidence; the capped boot makes it a clean confirmation.
- [ ] **1.2** If a new boundary appears: reproduce it in the **synthetic domain** (seconds), route that
  path through `TranslateData`, re-run the unit suite, then re-boot.
- [ ] **1.3** Swapper reaches steady state: its self-announce **MON 377B** is serviced end-to-end and
  it settles into its idle/service loop instead of stalling.

## P2 — MON round-trip through REAL SINTRAN  ← THE DONE BAR

The acceptance test has real ND-100 SINTRAN in the loop. The CPU-side pieces (2.a/2.b) are a fast
harness that proves the machine reaches a MON; the bar (2.c/2.d) is SINTRAN servicing that MON and the
CPU resuming with correct values.

- [x] **2.a (CPU-side, DONE 2026-08-18)** `SyntheticDomain` boot-free harness: multi-page ASI mapping +
  load a real `cpu-stat.dom` into a MAPPED domain (PSEG→code, DSEG→data via caps) and run under MMS to
  its first MON (011B), parked by a stub sink. Proves load+run+reach-MON on the microword CPU. NOT the
  round-trip - the sink is a stub. (`SyntheticDomainEndToEndTests`; suite 692 pass / 0 unexpected.)
- [ ] **2.b** `MSG_START`/context-load path into a mapped domain (plan 6.3): build the context block +
  drive `MSG_START` so a domain starts the way `nd-500-mon` starts it, not via direct latch-poking.
- [ ] **2.c ← THE BAR: real SINTRAN services the MON.** In the integrated boot (real ND-100 + SINTRAN,
  microword CPU over octobus), a program's segment-31 MON call is delivered by mailbox to SINTRAN's
  ND-500 monitor, SINTRAN runs the REAL handler, writes the answer, re-activates the CPU, and the
  microword CPU RESUMES with correct values. First target = the swapper's **MON 377B** (P1.3); then a
  user DOM's MON sequence. This needs the **capped boot (P1.0)** to be iterable.
- [ ] **2.d (NLL-P3/P4/P5)** Load + run a real user program (NLL, then cpu-stat) to correct output
  under that booted SINTRAN; NLL + swapper together; consolidate into an integration test + commit.

## P3 — Instruction-oracle divergences (parallel lane, alignment backbone)

- [ ] **3.1** Work the ~246 remaining 3-way divergences + 31 trap-bit misses: float trap bits
  (FO/FU/IVO on MULAD paths), packed-decimal Z flag (both functional cores wrong), DIVF longpath
  100/10. Use real-hardware datapoints where the datapoint requests already flag it.
- [ ] **3.2** Extend the sweep diff to `B/R/L/TOS/HL/LL/THA` (coordinated baseline move so it doesn't
  churn the corpus).
- Rule: microword-on-real-B30 is the authority unless a real-hardware datapoint says otherwise; fix
  the functional cores (C **and** C#) to match.

## P4 — MON functional-lane small deltas (parallel lane)

- [ ] **4.1** Segment>31 rejection (C rejects, C# doesn't — `TODO(segment-range)`) and the 412B
  already-mapped error code (`TODO(error-code)`). Ship each with a ported test + frame-log parity.

## P5 — ND-100 host C integration (only AFTER P2 is green)

- [ ] **5.1** Define the nd100x C ↔ ND-500/5000 core seam. Premature before the C# path proves the
  protocol; candidates exist (nd500x already has the machine model).

## P6 — Full-contract test suite ("seed every input, assert every output")

Motivation: EVERY frame-op bug found 2026-08-21 (INIT-B not set, ENTM-TOS not set, ENTS/ENTM
StackOverflow trap not raised, IFKRET broken by an un-seeded K flag) was the SAME shape — a partial
implementation of a fully-documented instruction contract, hidden by a test that checked only a
SUBSET of the outputs (X/A/E banks + Z/C/S/O, never B/R/L/TOS/K/traps). The fix is to test the FULL
contract, sourced from the manual (the functional core's `Instructions\CALL\*.cs` / `CONTROL\Init.cs`
transcribe ND-500 Ref ch.13 and cite the section). Method note: memory `method-full-contract-testing`.

### What a "frame-contract test" IS (so it needs no guessing on arrival)

A frame-contract test runs ONE frame macro-instruction on the microword `CpuND5000` from a fully
seeded state and asserts EVERY output the manual's "Operation:" block names — the frame-base `B`, the
link `L`, the top-of-stack `TOS`, the K flag, and the frame-header memory cells the instruction writes
(`PREVB`=B+0, `RETA`=B+4, `SP`=B+8, `AUX`=B+12, `N`=B+16, args=B+20+). Not a subset. The harness is in
`CPU.ND5000\tests\FrameContractTests.cs`:

```
CpuND5000 cpu = NewCpu(out mem);           // loads real MICRO-5800-B30.DATA, Mpc = NoopEntry (130)
cpu.Regs.P = pc; cpu.Regs.B = oldB;         // seed the documented INPUTS
cpu.Regs.Srf[10] = tos;                     // TOS home on the microword is SRF[10] (no TOS register)
cpu.Regs.PendingCallReturn = ret;           // an ENT* requires a preceding CALL (else it ISEs)
cpu.Regs.PendingCallArgCount = n; cpu.Regs.PendingCallArgAddresses[i] = ...;
mem.Write(oldB + 8, 4, newB);               // old B.SP -> becomes newB for ENTS/ENTSN
LayCode(mem, pc, new byte[]{ opcode, ... }); // + NOOP(0x03) at any RET/branch TARGET so its prefetch is clean
cpu.StepOneMacroInstruction();  // prime (fetch)
cpu.StepOneMacroInstruction();  // retire
// then Assert.That every documented output.
```

Seed VALUES come from the passing conformance vectors (resolve the corpus via
`Nd500xCorpusSweepTests.CorpusPath()`; e.g. `ENTS_StackDemand_0x20`, `ret_To2000`, `Ifkret_KeySet`).
Contract SOURCE is the functional core file, which cites the Ref section:

| instr | opcode | file (Instructions\...) | Ref | contract (documented outputs) |
|---|---|---|---|---|
| INIT | 0xDC | CONTROL\Init.cs | 13.9 | B=bottom; TOS=bottom+total; [B+8]SP=bottom+main; [B+0]PREVB=0; [B+4]RETA=0; L=0 |
| ENTS | 0xB8 | CALL\Ents.cs | 13.10 | newB=[oldB+8]; PREVB=oldB; RETA=ret; SP=newB+demand; AUX=0; N=argc; B=newB; L=ret; **STO if newB+demand>=TOS** |
| ENTSN | 0xBA | CALL\Entsn.cs | 13.10 | as ENTS but **N=min(actual,max)**; only first N args copied |
| ENTM | 0xDF | CALL\Entm.cs | 13.10 | B=bottom; PREVB=oldB; RETA=ret; SP=bottom+main; AUX=0; N=argc; L=ret; **TOS=bottom+total**; saves old TOS at [oldB+8]; **STO if main>=total** |
| RET | 0x80 | CALL\Ret.cs | 13.11 | B=[oldB+0]PREVB; L=[oldB+4]RETA; P=RETA; **K:=0** |
| RETK | 0x81 | CALL\Retk.cs | 13.11 | same restore; **K:=1** |
| RETD | 0x82 | CALL\Retd.cs | 13.11 | P:=L; B UNCHANGED (leaf, no frame) |
| IFKRET | 0x9D | CALL\Ifkret.cs | 13.11 | if K=1: RET restore but K STAYS 1; if K=0: nothing (B unchanged) |
| CALL | 0xC3 | CALL\Call.cs | 13 | L:=return addr; arm PendingCallReturn; P:=target; **B UNCHANGED** |

- [x] **6.1** Frame lifecycle contract-locked in `FrameContractTests.cs` — 9 passing full-contract
  regression locks (`Ents_FullFrameContract`, `Entsn_ArgCap_Contract`, `Entm_FullFrameContract`,
  `Ret_FullContract`, `Retk_FullContract`, `Retd_FullContract`, `Ifkret_KeySet_TakesReturn`,
  `Ifkret_KeyClear_NoReturn`, `Call_LeavesBUnchanged_ArmsReturn`; INIT already locked in
  `SwapperInstructionDiagTests.Init_ConsumesInlineAddressOperand_NoDesync`) + 2 `[Explicit]` known-gap
  DETECTORS that fail-as-designed (`Ents_StackOverflow_Trap_KnownGap`, `Entm_SetsTos_KnownGap`). Full
  ND5000 suite 702/2 green (the 2 red = the pre-existing Entt/Rett trap-frame, unrelated).
- [x] **6.2a** ENTM `TOS := bottom+total` — **DONE 2026-08-21**. The microword's TOS home is `SRF[10]`;
  the ENTM stand-in now writes it, strictly improving oracle alignment (the functional golden already
  carries this value). Detector `Entm_SetsTos_KnownGap` → renamed `Entm_SetsTos_Contract`, now `[Test]`
  (green). Sweep baseline unchanged (match=23957 / diverge=1424 — no regression).
- [ ] **6.2b** ENTS/ENTM StackOverflow (STO) trap when `newB+demand >= TOS` — **BLOCKED on the corpus
  emitting per-vector TOS (see 6.4).** The sweep replays the microword with `SRF[10]=0` on all but the
  ~12 tos-carrying vectors, so a gate keyed on `newB+demand >= TOS` would fire on EVERY unseeded ENTS
  vector, take the no-frame early return, and diverge B/L/RAM from the golden (whose functional TOS was
  seeded high). A `skip-STO-when-SRF[10]==0` guard is a plausible-WRONG hack (TOS=0 is a legitimate
  limit) and is rejected. Detector `Ents_StackOverflow_Trap_KnownGap` stays `[Explicit]` and now carries
  the full blocked-reason in its doc comment; it seeds SRF[10] explicitly so it is the right home to
  validate the gate once the sweep can carry TOS.
- [~] **6.3** Extend the same full-contract treatment to the remaining ENT/RET variants and CALLG.
  - **DONE 2026-08-21**: `Retb_FullContract` + `Retbk_FullContract` (two-byte opcodes 0xFE1C/0xFE1D) —
    lock the buddy-block return linkage (B:=PREVB, L:=RETA) and the RET-vs-RETK-style K polarity.
    FrameContractTests now 12 green + 1 [Explicit] STO detector.
  - **Already covered**: ENTT/RETT carry the known-red hard-fail detectors
    (`Entt_TrapFrame_CannotBeDriven_HardFail`, `Rett_TrapReturn_CannotBeDriven_HardFail`) — the microword
    cannot drive a trap frame yet; these are the gap markers.
  - **Remaining**: ENTB, ENTF, ENTFN (not in the microword's TryHandleFrameOp switch — need gap
    detectors sourced from functional Entb/Entf/Entfn.cs) and CALLG.
- [ ] **6.4** Layer-1 multiplier — make the differential oracle compare the FULL architectural state so
  gaps surface automatically: the sweep now seeds K and diffs B/R/L/TOS/HL/LL/THA (#51/6 done), so
  finish by extending `MacroOracleState` to TOS/HL/LL/THA and making the nd500x generator emit the
  complete final state per vector (today only 206/40082 carry `b`, 12 carry `tos` — the corpus itself
  is under-specified). NOTE: B/R/L/TOS divergences on TAKEN-BRANCH vectors are prefetch artifacts, not
  bugs — see memory `nd5000-sweep-shared-memory-pollution`.

## Deferred by design — real gaps, do NOT fake

- **Entt / Rett trap-frame** (the two known-red tests): need the 50-arg trap-register frame designed
  from in-trap-handler context. Honestly red; not on the critical path.
- **ACCP `0x03` byte / `0x330000` gate / `0x330001` bits**: need the Octobus Driver Programming Guide
  (DVT 15 Oct 1986) or a second card's ROM. Parked; becomes top priority if either turns up.

---

## Standing rules (apply everywhere)

- Build/test SINGLE projects with `/p:UseSharedCompilation=false` (full-solution builds OOM); assert
  the build exit code before believing any test number (stale-DLL trap); finish with
  `dotnet build-server shutdown`. A running boot holds the CPU/HW DLLs locked — don't rebuild them
  mid-boot.
- Frame-log diff first; full instruction trace only range-gated around the divergence.
- A probe that cannot tell its two hypotheses apart is not evidence; a green suite proves the outcome,
  not the reason. Delete diagnostics after use.
- Microcode addresses are OCTAL; read raw `MICRO-5800-B30.DATA` for SARG/MARG/ORCON/SCAL, never the
  rendered `.md`.

## Reference (not todos)

- **MMU / domain setup recipe** (PST/PSTE modes, capabilities-on-the-process-segment, DIT layout,
  translation, context block, enable latches, and every refuted theory): memory note
  `nd500x-mmu-translation-model.md` + `CPU.ND5000\docs\MMU-REGISTER-CROSSCHECK.md` §4.
- **Synthetic-domain harness** (the fast inner loop): `CPU.ND5000\tests\SyntheticDomainEndToEndTests.cs`
  (`SyntheticDomain` builder + fetch and data-side end-to-end tests).
