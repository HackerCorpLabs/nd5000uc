# Running EVERY ND-500 program — measured baseline and the plan

**2026-08-26.** Grades: `[V]` measured/executed, `[D]` derived, `[OPEN]` unknown.

Goal restated: **run the real ND-500/ND-5000 programs on our emulated CPU, driven by REAL SINTRAN III
on the emulated ND-100, with every MON call FORWARDED over the bus/octobus.** A run our C#
`SintranEmulation` answers does not count.

This plan is built from measurements taken today, not from opinion about which instruction looks
important. Where something is unmeasured it says so and names the command that would measure it.

---

## 1. THE BASELINE — `[V]`, taken 2026-08-26

Every installed program run under `nd500x` (the C reference emulator), 25 s cap, `EXIT` on stdin:

| program | instructions | outcome |
|---|---:|---|
| LED-NEW | 538,729 | full-screen editor draws, `<Exit LED Editor>` |
| LED-FORTRAN-A01 | 186,981 | runs |
| CONVERT-DOM-A03 | 131,084 | runs |
| LINKER-B01 | 107,127 | banner, runs `LINKER:INIT`, enters `NDL(ADV):` |
| NC-A06 | 50,857 | `Norsk Data C - Version: A06` |
| CPU-STAT | 34,518 | full identity report |
| PLANC-500-G00 | 27,541 | `- ND-500 PLANC COMPILER - JUNE 9, 1986 VERSION G` |
| CAT-CAT5-B06 | 13,846 | `CAT-500 - Version B06`, clean `terminated` + timings |
| AUTOMAKE-500-C00 | 13,705 | `Auto:` prompt |
| TEST-REAL | 12,445 | prompts, converts, re-prompts |
| CODE-COVERAGE | 11,017 | full welcome text, `Program language:` prompt |
| FILE-COMPARE | 4,572 | `FCOM:` prompt, `- EXIT -` |
| **BM-FILERE-B02** | **7,866** | **STOPS — unimplemented MON** |

**12 of 13 are fully functional. Every one of the 13 loads and executes.**

> ⚠️ **The first version of this measurement reported 9 of 13 as "not found" — and all nine had run
> perfectly.** The harness fed `EXIT/QUIT/Q/STOP/END` on stdin; those land at the SINTRAN prompt
> *after* the program returns, where they are not commands, so SINTRAN answered `NO SUCH COMMAND OR
> DOMAIN` to each — and a grep over the whole log measured **my own input** and reported it as a
> property of the program. Everything above is now judged only on the region between the program's
> `placed` line and its `program exited` line, and the headline is **instructions executed**, which
> `nd500x` reports directly and which no prompt noise can fake.

**WHAT THIS BASELINE DOES NOT PROVE:** `nd500x` answers the MON calls with its **own C emulation**.
This says the DOMs load and the instructions execute. It says nothing about SINTRAN, the mailbox,
the swapper or the microcode. It is the **instruction-and-loader** baseline and nothing more.

---

## 2. THE CONCLUSION THAT REDIRECTS THE WHOLE EFFORT

**MON coverage is not the gap, and implementing MON calls is not the work.**

On the real lane we **forward everything** — verified by sweep, there are exactly two MON-number
sites on the bridge path and neither answers one. So our MON coverage is not a subset of SINTRAN's;
it is the identity. There is no list of MONs to go and implement, and the corpus's MON census
(now `[V]` for four programs) cannot produce one.

The single MON gap in the whole corpus proves the point rather than contradicting it:

**`BM-FILERE-B02` stops on `MON 347B` (NucleusFunction) — 16 call sites, and ZERO in any other
program.** `nd500x` does not implement it. **On our target architecture it needs nothing from us:
real SINTRAN answers it.** Implementing 347B would only fix the C lane, which is not the goal.

So the work is **not** MON handlers. It is: the loader, the segment model, the swapper, and
instruction/trap fidelity on the real lane.

---

## 3. WHAT THE MEASUREMENT ACTUALLY EXPOSED

### 3a. Multi-segment DOMs are real and only one program has one `[V]`

Twelve programs are one segment, PROG at virtual `0x08000000`. **`BM-FILERE-B02` is not:**

```
DOM Load: Seg[1] DATA: file=0x00007800..0x000B7107 size=719112
DOM Load: Seg[2] PROG: file=0x000B7800..0x000FDBE4 size=287717
   entry 0x1000A2DC        <- segment 2, not segment 1
```

Segment base is `segmentNumber << 27` (`0x08000000` = 1, `0x10000000` = 2). `LINKER-B01`'s entry is
`0xB0013B41` — **segment 22**. So the corpus exercises segment numbers 1, 2 and 22, and any loader
that assumes "PROG is segment 1 at `0x08000000`" works on 12 programs and silently mis-places the
other two. **Whether our RetroCore loader handles this is `[OPEN]` — §4 step 1 measures it.**

### 3b. Entry points are not at the start, and one tool already got that wrong

Entry points measured: `0x08000004` (most), `0x0800065C` (PLANC), `0x08001305` (AUTOMAKE),
`0x08001CA9` (CODE-COVERAGE), `0x0800072F` (FILE-COMPARE), `0x1000A2DC` (BM-FILERE),
`0xB0013B41` (LINKER).

This is not a curiosity — the archived `analysis\*.asm` disassemblies **start at the entry point**,
so for PLANC everything below `0x0800065C` was never disassembled, and a census built on those files
silently misses it. See `ND500-DOM-MON-CENSUS-DISASSEMBLED-2026-08-26.md` §5.

### 3c. Instruction coverage is probably not the blocker `[D]`

RetroCore's `Instructionset.Init.cs` registers **1048 opcodes / 241 distinct mnemonics**, and there
are **zero `NotImplementedException`s** in `Instructions\`. There is one catch-all path —
`CpuND500.Execute.cs:581`, *"the instruction is defined but not implemented"* — which stops the CPU
and prints the mnemonic and opcode. **That path is the instrument for step 2 and it already exists.**

Graded `[D]`, not `[V]`: "registered" is not "correct", and the sweep oracle still carries 246
divergences (task #50). Coverage of *presence* says nothing about coverage of *behaviour*.

---

## 4. THE PLAN

Each step's exit criterion is a **measurement**, and each names the command. No step is "done" on a
reading of the code.

### Step 1 — RetroCore standalone baseline `[OPEN]`, this is the missing number

Run the same 13 DOMs on RetroCore's `CpuND500` and produce the same table: instructions executed,
output, stop reason. Until this exists we do not know whether our own CPU is at 13/13 or 3/13, and
every later priority is guesswork.

The harness already exists (`Emulated.Tests.ND500\Sintran\TestMON_RealProgramRun.cs`,
`TestDOMExecution_MonitorCalls.cs`). What is missing is that it runs **one** program, not the corpus.

**Exit criterion:** a committed table, same shape as §1, for all 13 DOMs + the 4 PSEG/DSEG pairs.
**This is the single highest-value thing to do next** — it converts "get all programs working" from
a slogan into a ranked list, because every program that stops names its own blocker.

### Step 2 — Rank the stops, do not guess at them

Every RetroCore stop from step 1 falls into exactly one bucket, and the bucket decides the fix:

| stop | fix | note |
|---|---|---|
| `instruction ... has no Execute handler` | implement that instruction | the message names opcode + mnemonic |
| wrong result, no stop | oracle divergence | feeds tasks #50/#51, needs the microword CPU as judge |
| loader / segment placement | §3a multi-segment | only BM-FILERE and LINKER exercise it |
| trap taken that should not be | trap fidelity | `P` vs `P1` — a trap PC is not the faulting instruction |
| MON answered by our C# layer | **STOP — this is the fake lane** | ask who answered before believing anything |

Order by **how many programs each unblocks**, taken from step 1's table. One instruction that blocks
five programs beats five that block one each.

### Step 3 — Move the corpus onto the real-SINTRAN lane, one program at a time

Known state on that lane: **CPU-STAT `[V]`** (full report, every MON forwarded) and **LED-FORTRAN-A01
`[V]`** (interactive, after the classic `DMEMRD` fix). Everything else is `[OPEN]`.

Next in order, and the reason is measured rather than chosen:

1. **CONVERT-DOM-A03** — 69 MON sites, 43 distinct, **`513B` ×14**, the heaviest user of the callg
   family in the corpus. It is the strongest test of the classic `DMEMRD`/`DMEMWR` work.
2. **CAT-CAT5-B06** — 45 sites, 31 distinct, **zero callg**, no `511B/512B/513B/514B` at all. The
   *control*: it exercises the copy path without the XMSG family, so if it passes and CONVERT fails,
   the fault is in the callg family and nowhere else.
3. **PLANC-500-G00 / NC-A06 / LINKER-B01** — the compile→link→run chain, which has byte-exact
   oracles already recorded, so success is checkable by hash rather than by eye.
4. **BM-FILERE-B02** — last, because it is the only multi-segment DOM and the only `347B` user, so
   it tests two new things at once and a failure would be ambiguous.

### Step 4 — The PSEG/DSEG pairs

`SWAPPER-K01`, `LINKAGE-LOAD-H02`, `LED-B03`, `LED-DEBUGGER-B03`. These are **not** DOMs — they are
raw program/data segment pairs with no domain header, so they need the segment base and entry
supplied rather than read. `SWAPPER-K01` is already the subject of its own long-running track.
**Do not fold these into the DOM work** — different loader, different problem.

---

## 5. WHAT IS DELIBERATELY NOT ON THE PLAN

- **Implementing MON handlers.** §2. Forwarding covers the corpus. The only tempting one is `347B`
  for BM-FILERE, and it would fix the C lane only.
- **Implementing the microcode assist families** (`500B/501B/502B/600B`, `270B/271B/333B/335B`,
  `201B`). Measured zero users across the corpus. Now instrumented instead: any sighting is logged
  loudly (`Nd500MonMicrocodeRole.cs`, commit `a9dd40021`), and one sighting is the evidence that
  would justify writing the code. Until then, writing it is code that fails by working.
- **Adding `513B` to the inline-copy set** because it is adjacent to `512B` and heavily used.
  Sharing a SINTRAN handler is not sharing a microcode obligation.

---

## 6. TOOLS BUILT FOR THIS, ALL REUSABLE

`E:\Dev\Ronny\ND5000UC\tools\mon-census\` — POSIX shell, run under WSL:

| script | does |
|---|---|
| `dis-dom.sh <DOM> <proglen> <out>` | full PROG-segment disassembly, chunked around nd500x's 16 KB buffer |
| `rawscan.sh <DOM> <progoff> <proglen>` | raw byte scan for both MON call encodings |
| `crosscheck.sh <raw> <asm>` | diffs the two address sets and names every disagreement |
| `mon-census2.sh <asm>` | per-MON counts, direct call sites vs indirect reach |
| `baseline-run.sh <outdir> <timeout>` | §1 — runs the whole corpus and reports instructions executed |

**Read the PROG file offset from nd500x's own load line; it differs per program** (`0x1000`,
`0x1800`, `0x4000`, `0xB7800` all occur). Assuming one produced 11 hits on LED, none of them real.
