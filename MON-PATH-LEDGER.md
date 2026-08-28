# MON / MICFU path ledger — who actually answers each message

**Full path:** `E:\Dev\Ronny\ND5000UC\MON-PATH-LEDGER.md`
**Created:** 2026-08-28 · **Recommended:** 2026-08-08 (as R5), rebuilt as R14 after it cost a day.

---

## Why this file exists

Project rule, from `CLAUDE.md`:

> **THE GOAL: run real ND-500/ND-5000 programs under REAL SINTRAN, with MON calls FORWARDED over the
> bus/octobus. A run where our C# `SintranEmulation` answers the MON calls DOES NOT COUNT.**
> Before believing any "the program runs" claim, ask **WHO ANSWERED THE MON CALLS?**

On 2026-08-24 that question was asked in anger — *"i hope we are not running simulated MON calls"* —
and there was no way to answer it except by reading four thousand lines of servicer. This file is
the answer, and the test described in §4 is what stops it going stale.

**The status that matters most is not FAKED. It is CONDITIONAL** — a path that is real when a CPU is
attached and a canned answer when it is not, because *from SINTRAN's side the two are
indistinguishable*. The servicer says so itself, at the 3MONCO arm:

> *"a restart that is DECLINED still gets answered below as though it succeeded, so from SINTRAN's
> side 'resumed' and 'quietly not resumed' look identical — it just sends another one."*

---

## 1. Vocabulary

| status | meaning |
|---|---|
| **REAL** | The servicer performs the hardware's actual work (a real memory copy, a real PST walk). |
| **FORWARDED** | Handed to the attached CPU or to real SINTRAN. This is the status the project goal is written in terms of. |
| **CONDITIONAL** | REAL on one path, canned on another — usually "if `ProcessHost != null` and the CPU accepts". **The dangerous class: indistinguishable from success at the caller.** |
| **DECLINED-BY-DESIGN** | Answers `5ERANSWER(4)`, because the real hardware also refuses. A refusal that matches hardware is correct behaviour, not a gap. |
| **ABSENT** | No arm and/or no enum member. The default arm **throws** rather than answering — deliberate, see §3. |
| **UNVERIFIED** | Listed for completeness; the arm was not read line by line. **Not a status claim.** *(No row carries this any more — all 22 were read on 2026-08-28. Kept in the vocabulary because the honest thing to do with a new MICFU is mark it UNVERIFIED rather than guess.)* |

Generation matters: several arms behave differently for `Nd500Generation.ND500` and the ND-5000, and
a status that is silent about generation is a status that is wrong for one of them.

---

## 2. The ledger

Keyed on **MICFU octal** and **enum member name** — both stable across the `classic → ND500` rename
running in the RetroCore tree, unlike line numbers.

| MICFU | enum member | ND-500 | ND-5000 | status | who answers |
|---|---|---|---|---|---|
| `01` | `ReadMicroVersion` | yes | yes | **REAL** | servicer — answers version + CPU-parameter halfword. The watchdog heartbeat; a burst of these means time passed, nothing more. |
| `05` | `MessageToSwapper` | — | — | **DECLINED-BY-DESIGN** | answers `5ERANSWER`, matching the real microcode (dispatches to `MSG_ILLEG`). |
| `10` | `DataMemoryRead` | NOT MODELLED | REAL | **CONDITIONAL (generation)** | ND-5000: `PerformOctobusBlockCopy`, real bytes moved. **ND500: not handled** — the arm's ND500 branch covers only `PhysicalRead`, so 10B falls through to `understood = false` and answers `5ERANSWER`. In-source comment: *"IMEMRD and friends still unmodelled on classic"* — so this is a GAP, not a refusal that matches hardware. Verified 2026-08-28. |
| `11` | `DataMemoryWrite` | NOT MODELLED | REAL | **CONDITIONAL (generation)** | mirror of `10` — ND-5000 real block copy; ND500 unmodelled, answers `5ERANSWER`. Verified 2026-08-28. |
| `12` | `CacheControl` | yes | yes | **REAL** | servicer — answered; the hardware's cache op has no emulated state to change. |
| `13` | `ResidentRead` | yes | yes | **REAL** | servicer. |
| `14` | `ResidentWrite` | yes | yes | **REAL** | servicer. Previously DROPPED silently as an unknown MICFU — a fixed gap, kept here as the reason the default arm now throws. |
| `16` | `ExamineRegister` | yes | ERANSWER | **CONDITIONAL (generation)** | ND-500 answers; ND-5000 declines, matching hardware. |
| `17` | `DepositRegister` | yes | ERANSWER | **CONDITIONAL (generation)** | as above. |
| `20` | `RegisterRead` | — | — | **DECLINED-BY-DESIGN** | `5ERANSWER`, matching microcode A30 @014261. |
| `21` | `RegisterWrite` | — | — | **DECLINED-BY-DESIGN** | as above. |
| `22` | `StartProcessZero` | yes | yes | **REAL** | servicer. |
| `23` | `StartProcess` | yes | yes | **FORWARDED** | loads the process context into the attached CPU and runs it. Shares its arm with `TrapContinue`. |
| `24` | `MonitorCallContinue` | yes | yes | **CONDITIONAL** ⚠ | **`ProcessHost != null` AND `OnMonitorCallRestart` accepts → FORWARDED** (message stays WAITING, answered at the next stop, returns false). **Otherwise → `understood = true`, an immediate canned answer** marked in-source as `// pre-CPU placeholder`. Counters `MonitorCallRestartsSeen` / `MonitorCallRestartsTaken` exist precisely so the two can be told apart — **read both; `Seen > Taken` means restarts are being answered without running.** |
| `25` | `TrapContinue` | yes | yes | **FORWARDED** | shares the `StartProcess` arm `[V]`. |
| `26` | `WaitMonitorCall` | yes | yes | **CONDITIONAL** ⚠ | the 3MONCO restart plus a bounded block copy of answer data into process memory before EXECUTE. Same placeholder fallback as `24`, same indistinguishability. |
| `27` | `FileTransfer` | — | — | **DECLINED-BY-DESIGN** | `5ERANSWER`, matching hardware. |
| `30` | `PhysicalRead` | REAL | REAL | **REAL** | ND-500: real PST walk (microcode `011433B`, shares `TryResolvePhysicalSegmentAddress` with PHYSWR). ND-5000: `PerformOctobusBlockCopy`. |
| `31` | `PhysicalWrite` | REAL | REAL | **REAL** | mirror of `30` (microcode `011453B`). |
| `34` | `Mono` | ANSWER-ONLY | **REAL** | **CONDITIONAL (generation)** ⚠ | **A NAMESPACE COLLISION, verified 2026-08-28.** `3MONO` = 0o34 on the ND500 *and* `IMEMRD` = 0o34 in the B30 octobus copy family. ND-5000: dispatches to a real direction-fixed block copy (`PerformOctobusBlockCopy`, addrA -> addrB), proven byte-exact by the microword CPU's IMEMWR/IMEMRD round-trip. **ND500: `understood = true` and NOTHING ELSE — answered without any work done.** |
| `35` | `InstructionMemoryWrite` | not modelled | REAL | **CONDITIONAL (generation)** | ND-5000 real copy; ND-500 arm explicitly `understood = false` — *"IMEMRD and friends still unmodelled on classic"*. |
| `44` | `ReadPRegister` | stub | stub | **FAKED** ⚠ | **Verified 2026-08-28: the entire arm is `understood = true; break;`.** It is named "read the P register" and it reads nothing, returns nothing, and touches no message field — it just answers ANSWER(3). Any caller asking the ND-500 for its P register is told the request succeeded and gets whatever was already in the slot. This is the clearest FAKED path in the table. |
| — | *(no `InstructionMemoryRead` member)* | — | — | **not a hole** | **CORRECTION 2026-08-28.** An earlier version of this table claimed "36B IMEMRD is ABSENT and would throw". That was wrong twice over: IMEMRD is **0o34**, which IS handled — as the `Mono` member, above — and decimal 36 is `ReadPRegister` (0o44). I had read a decimal enum value as an octal MICFU. There is no missing instruction-memory-read path. |

### The two entries to check first when asking "who answered the MON calls?"

`24` **`MonitorCallContinue`** and `26` **`WaitMonitorCall`**. Everything else is either really doing
the work or really refusing. These two are the only paths that can *look* like a serviced MON call
while nothing ran — and they are exactly the MON-restart path the project goal is about.

**The check is already instrumented, so use it instead of reasoning:** `MonitorCallRestartsSeen`
versus `MonitorCallRestartsTaken`. Equal means every restart reached a CPU. `Seen > Taken` means the
difference was answered by us. That is a denominator, which is what
`feedback-friction-lessons-nd5000` §0 #7 says a single count always lacks.

---

## 3. Why the default arm throws instead of answering

Ronny, 2026-07-27: **FAIL LOUDLY.** An unknown MICFU answered with `5ERANSWER` is not a quiet gap —
SINTRAN retries it, so it becomes an infinite retry loop that burns a whole run and announces itself
as something else entirely. `ResidentWrite` (14B) was silently dropped that way once. The throw is
deliberate; do not "fix" it into an answer.

---

## 4. The test that keeps this file honest (to be written — task #62)

Lives in `Emulated.Tests.ND500`. **Deferred only because `nd500uc-47` currently owns the RetroCore
tree for the naming sweep; the design is settled.**

1. **Completeness.** Enumerate `N5MicroFunction` by reflection; **fail** for any member with no row
   in this table. A new MICFU cannot be added without declaring who answers it.
2. **No orphan rows.** Fail for any row naming a member that no longer exists — catches this file
   rotting after a rename.
3. **Claim agreement.** Parse the servicer source for `case N5MicroFunction.<name>` and fail where a
   row says a path is handled and no arm exists, or vice versa.
4. **No silent skip.** If the servicer source cannot be located, the test **fails**. It must never
   skip: a skipped NUnit run still prints *"Test Run Successful"*, which is indistinguishable from a
   pass at the exact place a reader stops reading (`nd500uc-47`, 2026-08-28).

What the test deliberately does **not** do is verify that a status is *correct* — it cannot know
that a REAL is truly real. It verifies that **every path has a declared answer and that the declaration matches
the code's shape.** Correctness of a status stays a human carve, graded as everywhere else.
