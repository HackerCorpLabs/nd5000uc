# HANDOFF — the octobus swapper standoff, located: a `3SWMESS` parked at `SWPPING(6)` that nothing consumes

**Full path:** `E:\Dev\Ronny\ND5000UC\docs\handoffs\HANDOFF-OCTOBUS-SWAPPER-SWPPING-DEADLOCK-2026-09-01.md`

Evidence record: `E:\Dev\Ronny\ND5000UC\docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md` §177–189.
Plan: `E:\Dev\Ronny\ND5000UC\PLAN.md`.
Harness: `E:\Dev\Repos\Ronny\RetroCore\Emulated.Tests\ND100\Nd100SintranNd5000OctobusBootHarnessTests.cs` (RetroCore commit `d6d093111`).

---

## RESULT

The `place-domain` stall is **located to one instruction and named**.

`CHSWS` (the auto-load ladder step that runs inside `place-domain`) calls `0o163637` exactly once.
That routine runs its **entire** length — four arms and a loop that terminates normally, every
internal call returning by its **success** door — to `0o164101`, where it calls `0o62662`. That
routine **builds a 5MPM message** (`N5STA:=1`, `X5CPU:=(,B 72)`, `MICFU:=5`) and waits.
**MICFU 5 is `3SWMESS`** (`3SWME=000005` in `N500-SYMBOLS.SYMB`) — the swapper message. It never
returns.

Meanwhile the `X5BEX` queue holds a node at `0x00428E30` carrying `MICFU=0x0005` at
**`N5STA=SWPPING(6)`**, stable across 112 consecutive queue dumps, never serviced.

This also answers an older hunt: commit `ffdfe99` went looking for *"the 3SWMESS writer in resident
SINTRAN"*. **It is `0o62662`, reached from `0o164101`.**

**The deadlock shape — three measured facts that must be held together:**

1. **Work is waiting** — a `3SWMESS` parked at `SWPPING(6)`.
2. **A worker is waiting** — the swapper is started (`3START` **is** sent), runs, takes **one**
   monitor call, and parks; plausibly its designed `PSWWAIT` idle.
3. **The wake path ran** — `5ACTSWAPPER` executed **twice**, in every table since §179.

**Something between "a SWPPING message exists" and "the swapper is woken to consume it" does not
connect.** Which of three bugs that is remains `[OPEN]` — see the last section.

---

## THE BUGS — and the non-bugs, which cost more

**Not a bug: our servicer is RIGHT to ignore the message.** The real B30's mailbox scan requires
`N5STA == MSGN500(1)`. `0o15143` carries the immediate `1`, verified in the **raw**
`MICRO-5800-B30.DATA` (its neighbours carry `0x0000`, so the constant is specific to that word). A
node at `SWPPING(6)` is skipped by the hardware too. `SWPWA=5 / SWPPI=6 / PSWWA=7` are **ND-100-side
swapper states** — a different namespace from the ND-500 `free/MSGN500/WAITING/ANSWER/5ERANSWER`
lifecycle, which is why values above 4 appeared undocumented at first.

**A fix that was one step away and would have been worthless.** The
`case N5MicroFunction.MessageToSwapper` arm in `Nd500MicrocodeServicer.cs` is **unreachable on this
lane** — not because of the `Generation` test inside it, but because a `3SWMESS` never arrives with
`N5STA=1` for the chain walk to hand over in the first place. Making that arm "answer 3SWMESS" would
have changed nothing observable and left a file that *looks* like it handles the case. What stopped
it was recording a contradiction as `[OPEN]` instead of explaining it away.

**A stale `[V]`, corrected in place** (NDInsight commit `f8ac5029`). The octobus MICFU reference said
*"no activation (`3START`, MICFU `0x13`) is ever sent, so the swapper is never started."* It **is**
sent now. Annotated with a banner rather than an edit, because the true half ("waits forever with
nothing but watchdogs") and the false half sit in **one sentence** — so the accurate half lends its
credibility to the stale one, and a reader would hunt for a missing `3START` that is present.

**Answered on the way:** `0x96..0xC4` (13 words) is the **start-swapper verify block** — written
immediately before `3START`, and it completes and passes. That was an explicit `OPEN` question in the
MICFU reference.

---

## THE TECHNIQUE

**Arm an address together with its REQUIRED PREDECESSOR, in the SAME table.** Not the next run — the
same table, so both numbers come from one instrument under one set of conditions and no argument
about run-comparability can rescue a bad one. This caught two separate lies:

- `0o163637` reported an entry count of **3** while `0o163641` — straight-line two words later, with
  nothing branching in — reported **1**. Five arms said one, one said three. The count was wrong.
- `0o43660` reported "STACK OVERFLOW hits=2" and `0o164110` reported "reached the last call". Both
  were **aliased foreign code**, exposed only because per-hit `PIL`/`B`/`L` print beside the count
  (`PIL=0`, `B=221o` against this path's `PIL=1`, `B=176200o`).

**Read hot/cold, not values, when the question is "where did it stop".** A monotone ladder is robust
to over-counting; a value is not.

**Bisect, don't walk.** The routine is ~280 words; walking arm-by-arm at ~15 min/run was ~10 runs.
Eight arms spread across the tail bracketed the stop in **one**.

**Generate each arm's label from its octal address by script.** Every arm-placement error in this
investigation came from a hand conversion. A generated label cannot disagree with the value armed.

**Ask the microcode.** It is on disk and executable. When a claim decides between two opposite fixes,
read the RAW `MICRO-5800-B30.DATA` word — never a rendered `.md`.

**Decode in order; do not count.** The `3START` question was settled by reading the message sequence
in arrival order. The totals alone say `3START` occurred once and say nothing about whether anything
blocked before it.

---

## WRONG TURNS — DO NOT REPEAT

1. **Do not conclude "the call never returned" without reading what the callee IS.** `0o74411` looked
   like a semantic call; it is the compiler's frame push. `JPL I <pointer>` renders identically
   whether the callee is chosen code or compiler plumbing. **Read the pointer word before arming its
   landing site** — one `grep`, no build.
2. **But do not then let "what it is" answer "did it complete".** Having identified the prologue, I
   dropped the `0o74412` arm as pointless. Wrong: the question that arm answers is *did the stack
   overflow*, and the push's failure exit `0o43660` is `IOF`/`TRA PGC` — a trap handler that never
   returns. **Knowing what code is FOR is not knowing that it FINISHED.**
3. **Never build a deduction chain on an unchecked count.** From "entered 3 times with identical
   parameters" came: identical parameters ⇒ a retry not progress; `L` is loaded only by `JPL`; `L`
   unchanged ⇒ the re-entry was not a call ⇒ the known retry loop is *excluded by measurement*. Every
   step valid, the premise false, the conclusion confident, specific and wrong. **Good reasoning on a
   bad number is more persuasive, not safer.**
4. **Identical registers across N hits is not evidence of repetition** — it is exactly what one event
   sampled N times looks like. Check a neighbouring arm before calling it a retry.
5. **Do not merge two log formats.** `MICFU=0x0005` (4-digit) is a **queue node's contents**;
   `MICFU=0x05` (2-digit) is a **serviced call**. `grep -c "MICFU=0x0*5"` returns 113 and reads as
   "the swapper message was serviced 113 times" — the exact opposite of the truth, which is one
   unserviced node re-observed on every dump.
6. **Do not filter tests on the class name.** `FullyQualifiedName~Nd100SintranNd5000OctobusBootHarnessTests`
   runs the long full-ladder fixtures first — 33 minutes burned. Filter on the **test** name.
7. **`utf-8-sig` writes a BOM even when the file had none.** A patch script silently added one to a
   shared source file. Read with `utf-8-sig` if you must; **write with `utf-8`.**
8. **Git Bash mangles `/p:`** into a path (`MSB1008: Only one project can be specified`). Use
   `-p:UseSharedCompilation=false`.

---

## WHAT IS OPEN

- **[OPEN — the live question] Which of three bugs the deadlock is.** Whether `5ACTSWAPPER`'s two
  executions concerned this message at all; whether waking requires the ND-100 to move the node out
  of `SWPPING` first; or whether the swapper woke and looked somewhere other than where `CHSWS`
  parked it. **These demand different fixes — do not pick by plausibility.**
  **The measurement that separates them: the IDENTITY of the node the swapper examines when
  `5ACTSWAPPER` runs** — specifically whether it is `0x00428E30`. Counts will not answer it.
- **[OPEN]** Why the `0o163637` entry arm over-counts 3-vs-1. `0o74407` is also an `STF ,B -54` and
  measured 1, so "a multi-word store sampled once per memory cycle" does not hold. The retraction
  stands regardless of the cause; the cause does not.
- **[OPEN — §173]** The MON 60 counts balance, but the arrival order forbids that reading: one
  gateway hit with no return, another with both. Counts `[V]`, meaning `[OPEN]`.
- **[OPEN]** No sweep of all 16384 microwords for *any* `SWPPING` reader was done. §188 verified the
  **mailbox scan** only — that is the mechanism that mattered, not the general case.

**Deliberately closed as non-findings** (do not reopen without new evidence):
`N500DF@0o51767 = 0x0000` — it is loaded into `X` and used as a **base address**, and the code never
reads `,X 0`, so the word at it was never an operand of this path. And the never-terminating-loop
candidate — `0o164000`=2, `0o164022`=1, so the loop ran two iterations and exited normally.

---

## HOW TO RE-RUN

```
cd E:\Dev\Repos\Ronny\RetroCore
dotnet build Emulated.Tests\Emulated.Tests.csproj -c Debug -nodeReuse:false -p:UseSharedCompilation=false

set RETROCORE_ND5000_WATCH=chswstail
set RETROCORE_ND5000_PACK=D:\DOMS-CSFIX.IMG
set RETROCORE_HARNESS_TIMEOUT_SCALE=0.5

dotnet test Emulated.Tests\Emulated.Tests.csproj -c Debug --no-build -nodeReuse:false ^
  --filter FullyQualifiedName~ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture
```

**Assert the build exit code before believing any table.** ~15 min/run, ~1M lines of log.

Six watch modes were added this session, each with an XML `<remarks>` block stating what its table
means **before** it is read: `chswsexit`, `chswsladder`, `chswscallee`, `chswsprologue`, `chswsarm2`,
`chswstail`. The PC watch is one global 8-slot table, so the modes are mutually exclusive by design.
