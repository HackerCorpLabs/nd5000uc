# ND-5000 microcode replay spec — MEASURED, 2026-08-24

**Full path:** `E:\Dev\Ronny\ND5000UC\docs\ND5000-MICROCODE-REPLAY-SPEC-MEASURED-2026-08-24.md`

**Brief (Ronny, 2026-08-24):** *"you need to measure and log very detailed what the microcode does
when control store and swapper is loaded so we can replay this correct (no guessing, no assumptions,
MEASURED!) in the macro cpu."*

Everything below came out of running the **real `MICRO-5800-B30` control store** one microword per
tick and recording every register delta and every guest memory access. Nothing here is derived from a
manual, a carve note, or a rendered listing. Where a destination is not visible in the recording it
says `[OPEN]` and stays open.

---

## How it was produced

| Piece | Full path |
|---|---|
| Register-delta tracer (existing) | `E:\Dev\Repos\Ronny\RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\src\MicroStateTrace.cs` |
| Memory tracer (**new**) | `E:\Dev\Repos\Ronny\RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\src\TracingMicroMemory.cs` |
| The measurement harness (**new**) | `E:\Dev\Repos\Ronny\RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\tests\MicrocodeReplaySpecMeasurementTests.cs` |

Run it with:

```
dotnet test Nuget\HackerCorpLabs.Emulation.CPU.ND5000\tests\HackerCorpLabs.Emulation.CPU.ND5000.Tests.csproj ^
  /p:UseSharedCompilation=false --filter "FullyQualifiedName~MicrocodeReplaySpecMeasurementTests"
```

### The artifacts it writes

| File | Size | What it is |
|---|---|---|
| `...\tests\bin\Debug\net9.0\measurements\M1-coldstart-to-idle.trace.txt` | 4.4 MB | Every microword that changed anything + every memory access, cold start → IDLE |
| `...\tests\bin\Debug\net9.0\measurements\M1-coldstart-to-idle.summary.txt` | — | Final architectural state after STARTMIC |
| `...\tests\bin\Debug\net9.0\measurements\M2-msgstart-contextload.trace.txt` | 31 KB | Same, for the MSG_START context load |
| `...\tests\bin\Debug\net9.0\measurements\M2-msgstart-contextload.summary.txt` | — | The context-block read-order table + final state |

Base directory in full:
`E:\Dev\Repos\Ronny\RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\tests\bin\Debug\net9.0\measurements\`

### Why the instrument can be trusted

`MicroStateTraceTests.Trace_DoesNotChangeExecution` asserts the CPU ends in an **identical** state
traced vs untraced. So the trace measures the machine, not the instrument. **5/5 green.**

### Line format

```
t=320 MEM R w4 @00000900 = 00006000  CS=014751
t=320 CS=014751(CNTXTLOAD0+1) A=A,DATA B=B,SC14 D=D,SC3 SEQ=(none) | SC3:00000000->00006000 EA0:00000900->00000904 ...
```

Memory lines are written as the access happens; the state line only once the word has finished. So a
tick reads as *its memory accesses, then its register deltas*.

---

## THREE WAYS TO MISREAD THIS TRACE — all three have already produced a wrong answer

1. **A delta says WHEN state changed, not always WHICH word changed it.** Pipelined loads commit
   late. Measured: `INIT_SAMSON @014517` issues `D,LC` at t=2 and the `LC` delta appears at **t=5**
   on `CS=000104`, an unrelated word that merely happened to be running when the pipe drained.
2. **The EXUC sneak runs a second body under the same Mpc**, so its register writes *and* its memory
   accesses carry the fetched word's address. Those lines are tagged `[EXUC sneak: ...]`.
3. **Zero lines is not "the microcode did nothing".** Both tests gate on a non-zero line count before
   concluding anything.

---

## M1 — what runs once the control store is loaded

`LOAD-CONTROL-STORE` shifts the image in over the ACCP (LOCSD/LOCSM); `STARTMIC` then releases the
micro clock at **control-store address 0**. There is no microcode ROM, so address 0 is the first
thing the machine ever executes. The image load itself changes no architectural state and needs no
replay — what needs replaying is what runs afterwards.

**MEASURED:**

| | |
|---|---|
| Ticks, reset → IDLE | **62,850** |
| Microwords that changed state | **37,501** |
| Guest memory accesses | **16,390** |
| End address | CS **024670** = IDLE mailbox poll |

**Architectural state at IDLE** — the state the macrocode CPU must present before it can accept a
message. All of WRF is zero **except**:

```
SC5  = 0x00000083     SC11 = 0x00000003     SC12 = 0x00008020
DPA  = 0x00002000     LC   = 0x000000FF
Q    = 0x400005D3     MIB  = 0x00000001
P = L = B = NPC = IRL = 0 ; all main and micro flags clear
```

`SC12 = 0x8020` is the ACCP `EOMB` token, the last thing the CPUPAR frame sent — consistent with the
boot ACCP conversation `BootTests` independently asserts (commands 2, 1, 3, then SOMB `0x8030`, model
byte `0x38`, EOMB `0x8020`).

---

## M2 — what runs when the swapper is started (MSG_START / 0o23)

SINTRAN loads the swapper as process 0 and starts it with mailbox `21B` (3WREG, register image) then
`23B` (3START). The START handler runs `NEWCNTXT → CNTXTLOAD → EXECUTE`.

**Method.** Every 4-byte slot of the context block (`SRF17*256 + 0x800`, here `0x900`) was seeded
with a **distinct marker** `0xC0DE00<offset>`, except `+0x00` which must hold real code for EXECUTE
to fetch. A register ending up with `0xC0DE0010` therefore came from offset `0x10` — no inference.

**MEASURED: 23 reads inside the context block, in this order.**

| # | tick | offset | staged via | final destination |
|---|---|---|---|---|
| 0 | 320 | `+0x00` | SC3 | **P** |
| 1 | 321 | `+0x04` | SC4 | **L** |
| 2 | 322 | `+0x08` | SC5 | **B** |
| 3 | 323 | `+0x0C` | SC6 | **R** |
| 4–7 | 329–332 | `+0x10 +0x14 +0x18 +0x1C` | — | **X1 X2 X3 X4** |
| 8–11 | 333–336 | `+0x20 +0x24 +0x28 +0x2C` | — | **A1 A2 A3 A4** |
| 12–15 | 337–340 | `+0x30 +0x34 +0x38 +0x3C` | — | **E1 E2 E3 E4** |
| 16 | 341 | `+0x40` | SC3→SC13 | **`D,MIC,STS`** at `WRITEST1+3` (015033) — micro status |
| 17 | 342 | `+0x44` | SC4→SC13 | **ALU status** at `WRITEST2` (015037/015040) |
| 18 | 343 | `+0x48` | SC5→SC13 | **`D,MM,PS`** at `NEW_PS_1` (015043) — MMS process status |
| 19 | 375 | `+0x5C` | SC3→SC13, **byte-masked** | **CED** — `015011` calls `NEW_CED` @`015053` |
| 20 | 376 | `+0x60` | SC4→SC13, **byte-masked** | **CAD** — `015012` calls `NEW_CAD` @`015055` |
| 21 | 388 | `+0x6C` | — | **SC1** (stays there) |
| 22 | 389 | `+0x70` | — | **SC2** (stays there) |

**P IS LOADED FIRST.** This is not a detail: an earlier probe that broke out of its loop as soon as
it saw P's marker dropped its own measurement from 14 markers to 3 and reported the result as if it
were the machine's behaviour.

### The staging pattern (measured, and it must be replayed)

The first four words do **not** write P/L/B/R directly. They stage into SC3–SC6 and a later word
commits:

```
t=320 CS=014751(CNTXTLOAD0+1) A=A,DATA B=B,SC14 D=D,SC3 | SC3:00000000->00006000
t=321 CS=014752(CNTXTLOAD0+2) A=A,DATA B=B,SC14 D=D,SC4 | SC4:00000000->C0DE0004
t=322 CS=014753(CNTXTLOAD0+3) A=A,DATA B=B,SC14 D=D,SC5 | SC5:00000000->C0DE0008
t=323 CS=014754(CNTXTLOAD0+4) A=A,DATA B=B,SC14 D=D,SC6 | SC6:0000204E->C0DE000C
t=324 CS=014755(CNTXTLOAD0+5) A=A,SC5 B=B,SC14 D=D,DAC,REG04 | B:00000000->C0DE0008
```

### The segment/PS setup — and why it matters right now

After `+0x48` reaches `D,MM,PS`, the microcode runs `NEW_PS_2` (015045+), reads `A,SPEC,MOD`,
computes `SC12`, writes it to `RF2` (`SRF2012 := 2`) and back to `D,SPEC,MOD`, via `ADR_MOD`
(017355). **That is the machinery that establishes the process's segment mapping.**

This is the same area as the current live blocker on the real-SINTRAN path. On 2026-08-24 the
3022 CPU-STAT run reached `MICFU=0x13` (23B StartProcess) with `P=0x08000004` and then took:

```
TRAP 46B pc=0x08000004  reason=PST entry 11 is ZERO - no mapping exists
                        (segment 1, cap=0x000B, isInstruction=True)
```

So the macrocode CPU is starting the process without the segment state the microcode's
`NEW_PS_1`/`NEW_PS_2` establishes here. The M2 trace is the specification for fixing that.

---

### CED and CAD are BYTE transfers — closed 2026-08-24, was `[OPEN]`

The two staged offsets were run down in the trace itself:

```
t=375 CS=015007(CNTXTLOAD1+24) A=A,DATA D=D,SC3  | SC3:C0DE0040->C0DE005C
t=377 CS=015011(CNTXTLOAD1+26) A=A,SC3  D=D,SC13 ->015053 | SC13:C0DE0048->0000005C
t=376 CS=015010(CNTXTLOAD1+25) A=A,DATA D=D,SC4  | SC4:C0DE0044->C0DE0060
t=382 CS=015012(CNTXTLOAD1+27) A=A,SC4  D=D,SC13 ->015055 | SC13:0000005C->00000060
```

`MICRO-5800-B30.LABE` names both targets, and its call-site lists contain the exact words above:

```
NEW_CED  015053*  011167 011171 015011 016053 016706
NEW_CAD  015055*  011170 011172 011574 015012 016054 016707
```

**So `+0x5C` → CED and `+0x60` → CAD, and both are MASKED TO A BYTE** — `0xC0DE005C` becomes
`0x0000005C` on the way into SC13. That independently confirms the existing carve comment in
`CpuND500.ProcessControl.cs` (`regs.CED = ReadPhysical32(ctx + 0x5C) & 0xFF;`, "CED/CAD are BYTE
transfers in the microcode (NEW_CED/NEW_CAD [V])") — two sources, arrived at separately. `[V]`

---

---

## SIDE RESULT — a real MMU bug the real swapper diagnosed for us (2026-08-24)

Working the same blocker from the macro-CPU side, on the REAL-SINTRAN CPU-STAT path
(`Nd500_CpuStat_UnderRealSintran_RealCpu_Capture`), the emulated ND-500 took two page faults:

```
TRAP 46B addr=0x08000004  mms=0x8000004D  psn=11    <- well-formed; SINTRAN SERVICED it
TRAP 46B addr=0x0800453A  mms=0x0000      psn=0     <- malformed
```

After the first, **`PST[11]` appeared** (`0x0FF9`) — the first evidence in this project that the
swap-in path works end to end. Execution advanced from offset `0x4` to `0x453A`, past the end of a
single 2 KB direct page, and the second fault went out carrying `psn=0`. The **real swapper, running
on our CPU**, rejected it and SINTRAN printed:

```
ND-500(0) error:      Illegal physical segment
```

= **ND-05.017.01 Appendix A, "Error Codes from Swapper", code 22B PAGE_FAULT**, *"Illegal physical
segment number in a page fault."* `psn=0` is exactly the illegal number it means. The swapper was
right; the malformed message was ours.

**Cause:** `CpuND500.MMU.cs` — every fault path in the `TranslateThroughPst` switch calls
`SetMmuFault(code, isWrite, psn)` before `TriggerPageFault`, and that call is what puts the fault
code and the PSN into the MMS status the message carries. The two **boundary** branches (PS_AZI with
L1/L2 nonzero, PS_ASI with L1 nonzero) called `TriggerPageFault` directly and skipped it, so they
emitted a fault naming segment zero.

**Fix:** both branches now `SetMmuFault(MM_INDEXERR | (isInstruction ? MM_INST : 0), isWrite, psn)`
first — `MM_INDEXERR` being the constant the same file already uses for the sibling "PSN out of
range" condition. The PS_ASI branch is fixed by symmetry and has **NOT** been observed live. `[V]`
for PS_AZI, `[D]` for PS_ASI.

**Confirmed by three independent signals** after the fix:

| | before | after |
|---|---|---|
| second fault message | `mms=0x0000 psn=0` | `mms=0x80000043 psn=11` |
| swapper error | `Illegal physical segment` | **gone** |
| `PST[11]` | `0x0FF9` — mode 0, direct, ONE 2 KB page | **`0x4FF8` — mode 1, single-INDEXED** |

That third row is the machine agreeing: given a well-formed boundary fault, SINTRAN **converted the
segment from direct to indexed**, i.e. grew it past one page. Exactly the right response, and it
could not have happened while the message said segment 0.

**No unit test could have caught this** — the fault was structurally valid and semantically empty.
It took a real swapper reading the message.

---

## What is still OPEN
- `IduSts` ends `0x00CE0044` while the value read at `+0x44` was `0xC0DE0044`. That is a field
  extraction, not a straight copy, and the mask is **not** `& 0x00FFFFFF` (that would give
  `0x00DE0044`). Not guessed. `[OPEN]`
- Context-block indexes above `+0x70` were **not observed being read**. That is a statement about
  this run, not proof they are never read — a different message type may touch them.
- M1's 37,501 state lines are recorded but not yet reduced to a per-phase story (SRF clear,
  constants, page-table bases, CPU_READ handshake, IDLE). The raw trace has all of it.

---

## Related

`[[nd5000-microword-state-trace]]`, `[[nd5000-context-load-contract]]`,
`[[goal-real-sintran-not-emulated-mon]]`, and the plan
`E:\Dev\Ronny\ND5000UC\PRIORITY-PLAN-2026-08-24-REAL-SINTRAN-DOM.md` (this is Phase 5.1, done for
the two events; Phase 2.3 is the seg-1 MMS blocker the M2 trace now specifies).
