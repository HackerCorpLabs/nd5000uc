# The octobus swapper standoff — where `> Loading Swapper` actually stops

> ## STATE OF PLAY, 2026-08-30 — READ THIS BEFORE ANY SECTION BELOW
>
> This file is written append-only and **corrects itself repeatedly**. Several sections are
> RETRACTED by later ones but kept verbatim so the wrong version is not re-adopted. Reading it
> front-to-back will hand you refuted conclusions as if they were current. Use this index.
>
> **SECTION NUMBERS ARE NOT UNIQUE.** Two workers appended here concurrently and numbered
> independently, so **21, 22, 33, 34, 35 and 36 each appear TWICE with different content**:
>
> | number | first occurrence | second occurrence |
> |---|---|---|
> | 21 | "the machine is already dead before the first command" | "`5MBBANK`/`5FPMAILBOX` inconsistent" |
> | 22 | "the X5ACT MISMATCH is the diagnostic" | "§21 IS REFUTED, my probe was wrong" |
> | 33 | "those are TEST PATTERNS, not microcode" | "#79 carved to its end: nothing ever FAULTS" |
> | 34 | "LEAD 1: control-cache read falls through" | "#78 reframed: a FEATURE SET the engine lacks" |
> | 35 | "the ORACLE round boots" | "the catalog refutes §34's framing" |
> | 36 | "`Expected` is a FIXED CONSTANT" | "`START-SWAPPER` NEVER RETURNS" |
>
> **Cite sections by TITLE, not by number.** Every reference in the tables below names the title so
> it resolves unambiguously; do the same in anything you add. Renumbering is deliberately NOT done -
> other documents and task descriptions already cite these numbers, and silently shifting them would
> break those links without anyone noticing.
>
> **LIVE — the current account:**
>
> | question | answer | sections |
> |---|---|---|
> | Why do only 8 microwords reach the control store? | **ANSWERED.** The firmware has TWO control-store write routines. We implement `0x7420` (gate + `#$0018`, 1 caller, runs 8 times). The selftest uses `0x73B4` (shift inside + `#$3010`/**`#$0006`**/`#$0010`, 3 loop callers, ~20,964 runs) and `0x0006` is unmodelled, so every one of those writes is silently discarded. | **56**, 51, 52, 54 |
> | Why does the sample test read back a different pattern? | Same root cause — it reads a word whose writes never arrived. Not a transform, not a pairing bug. | 53, 56 |
> | Is the real 68k ACCP implicated? | **No.** The 2x2 shows the CPU axis decides the outcome; the ACCP axis only decides SPEED (8.6x). | **38** |
> | Is the swapper subsystem broken? | **No.** It serves one request and correctly finds no more. Do not "fix" `LNEWSWAP`, `5ACTSWAPPER` or the FIFO. | **45**, 43, 44 |
> | Why does `START-SWAPPER` never return? | **OPEN.** It should ANSWER immediately (`MP-P2-N500.NPL:133747`); a hang is one of six calls before that. `XTER500` is ELIMINATED. | **60**, 62 |
> | Single-float `-0.0` TEST | **MEASURED at 4 operands.** The microword computes S = "sign AND NOT zero"; the functional core returns the RAW SIGN BIT. A semantic difference, not a flag glitch. Adjudication is Ronny's. | **63** |
>
> **RETRACTED — do not act on these:**
>
> | section | claimed | killed by |
> |---|---|---|
> | 32 | `TESTOBJ=29` is the cause; implement it | **33 ("those are TEST PATTERNS")** and 47 |
> | 34b | the write/expected patterns differ by a transform | **36 ("`Expected` is a FIXED CONSTANT")** |
> | 39 | the link mispairs data with address and drops commits | **40**, 54 — the pairing is modelled and correct; `0x0018` fires exactly 8 times |
> | 47 (recommendation) | make the engine TOLERATE unknown fields | **Ronny overruled it** — implement every field, throw and die on anything missing (54). NOTE the second §35 ("the catalog refutes §34's framing") argued FOR tolerance and is also overruled. |
> | 57 | `0x0055DE` is the source of `CSA: 00FFH` | **58**, then **59** found the real site at `0x00CDA8` |
> | 61 | `XTER500` cannot exit because `X5PRO` reads 0 | **62** — that row was the mailbox HEADER, not a CPU block |
>
> **METHOD WARNINGS EARNED HERE:** §64 (a guard you cannot reach is not a guard — a blocking
> `Run()` makes a 300 s cap a 70-minute hang, and `TIMEOUT_SCALE` cannot help); §48 (the def-json's
> `MEMORY` field declares span 10 but width 4 — the only such field; do not decode it by span);
> §58 (before connecting two things seen in the same window, read what is between them).
>

> **READ SECTION 14 FIRST (2026-08-29), THEN 12 AND 12c.** Section 14 shows this exact state was
> already measured and named as this lane's open question on 2026-08-27, two days before sections
> 7-11 re-derived it - so the "regression" framing below is too strong, and the diff read section 13a
> proposes is the wrong next step.
>
> **(ORIGINAL BANNER, kept:)** > **READ SECTIONS 12 AND 12c FIRST (2026-08-29).** This lane HAS REACHED `> Allocating memory` and run a
> domain for 7.5 minutes on 2026-07-31 and again on 2026-08-01. It no longer does. Sections
> 7-11 may therefore be describing a REGRESSION rather than a standing property of the
> octobus lane. CONFIRMED like-for-like in 12d: same test, same pack, same swap file geometry,
> same command, only the code date differs. The
> measurements are sound; the framing is not yet earned.

**Created 2026-08-28.** Full path:
`E:\Dev\Ronny\ND5000UC\docs\OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md`

**Lane:** ND-5000 / octobus. Task #56.

---

## 1. What was believed this morning, and why all of it was wrong

| claim | status |
|---|---|
| "The ACCP is dead at monitor entry — `ACCP was terminated; Microprogram has stopped`" | **REFUTED.** Printed at monitor ENTRY, before `> Loading Control Store`. Neither generation has microcode ROM, so at cold start there genuinely is no microprogram yet. |
| "The octobus bring-up never completes" | **REFUTED.** 128 LCS0, 1 STAMIC0, 1 ENKICK — the documented terminal pair of a SUCCESSFUL bring-up. Confirmed twice, by a command-enum decode and by a raw frame-word histogram, which fail in different directions. |
| "There is no 3START" | **REFUTED.** It is sent, it is in the chain, and it is taken. |
| "The servicer declined the 3START" | **REFUTED.** It was TAKEN. |
| "The run thread is not the variable" | **REFUTED.** It is — see §3. |

Five wrong answers, and every one of them was consistent with the evidence available at the
time. That is the point of §5.

## 2. The chain, measured `[V]`

`ChainWalkReport` (`Nd500MicrocodeServicer`, commit `a0662deea`) logs every node the mailbox walk
visits, with `N5STA`/`MICFU` **read before the node is served**. Steady end state, repeating to the
end of the run:

```
0x0042BE30  N5STA=0  MICFU=0      all-zero header slot, skipped every walk
0x0042C130  N5STA=1  MICFU=0x01   3RMICV watchdog - SERVED, over and over
0x00428D30  N5STA=7  MICFU=0x13   3START,  at PSWWAIT
0x00428E30  N5STA=6  MICFU=0x05   3SWMESS, at SWPPING
```

**`N5STA` 5/6/7 are not ND-500 statuses.** They are SINTRAN's own swapper states, ND-100 only:
`SWPWAIT=5`, `SWPPING=6`, `PSWWAIT=7`, `PSW1WAIT=0o15` `[SYMBOL]`. The ND-500 status space is
`free=0, MSGN500=1, WAITING=2, ANSWER=3, 5ERANSWER=4`. Two writers, two value spaces, one field.

## 3. The run thread IS the variable `[V]`

| | `RUNTHREAD=0` | `RUNTHREAD=1` |
|---|---|---|
| 3START @`0x00428D30` | TAKEN, then `WAITING(2)` on all 21 later walks | answered, reaches `PSWWAIT` |
| 3MONCO | never happens | TAKEN, forwarded to the CPU |
| console | stalls at `> Loading Swapper` | **stalls at `> Loading Swapper`** |
| served-MICFU census | 37×`0x01`, 13×PHYSWR, 1×CACHE | **34×`0x01`, 13×PHYSWR, 1×CACHE** |

With the thread off nothing executes, so a started process can never reach a stop, so its message is
never answered. With it on the swapper runs and makes a monitor call. **Completely different machine
behaviour, and the two instruments everyone had been reading show no difference at all.**

`MonitorCallRestartsSeen=1`, `Taken=1` — no gap. The restart was FORWARDED, not faked.

## 4. Where it actually stops — the protocol, PROVEN

From `N5SWAP-SWMSG-FIELD-DOSSIER-RELAY-2026-08-17.md` §§3-6 (each step marked PROVEN there):

1. `LOAD-SWAPPER` → MON 60 subfn `0o7` → prints `> Loading Swapper`.
2. `START-SWAPPER` → subfn `0o54` → posts `SWFUN=MSWSTART`.
3. `SWMESS` on `MSWSTART`: `SWPPING → N5STA`, `MICFU := 3START`, activate.
4. The ND-500 runs process 0 from P=4 and announces via MON 377B.
5. `DECOMESS` (`MICFU=3START` + `STOPR=MOCALL`) → `SWPDECODER` → `SWPD4: PSWWAIT` — **mark swapper
   free**.
6. `5ACTSWAPPER` hands work ONLY on `PSWWAIT`.

**Steps 1-5 have completed.** The node at `PSWWAIT` carrying `MICFU=3START` is exactly step 5's
output. So the swapper loaded, started, ran, announced, and was marked free.

Step 6 then hands it work, and the node at `SWPPING` carrying `MICFU=3SWMESS` is that work — §5b:
*"if `A/\17777=SWPPING` read MICFU; `3SWMESS` → restart ND-100 proc with ANSWER"*.

**So the stall is not in loading or starting the swapper. It is in the work handoff afterwards.**

## 5. ANSWERED — `SWPPING` is ND-100 bookkeeping, and our walk is right to skip it `[V]`

Carved from `E:\Dev\Ronny\NDInsight\SINTRAN\NPL-SOURCE\NPL\MP-P2-N500.NPL`, which is the ND-100 side
of this conversation. Every writer and every reader, by line:

**`SWPPING` (6) is written in exactly three places, all into a PROCESS's message, never into SWMSG:**

| line | routine | what it means |
|---|---|---|
| `133645` | `SWMESS`, `SWFUN = MSWSTART` | the process that typed START-SWAPPER is now "using the swapper" |
| `134107` | `SWMESS`, `SWFUN = MSWSWAIT` | restart-swapper-and-wait, after an allocate-page |
| `145022` | `5ACTSWAPPER` | `X:=MSGTOSW; SWPPING` — the page-faulting process handed to the swapper |

**`PSWWAIT` (7) is written in exactly ONE place:** `135747` `SWPD4: PSWWAIT; X:=SWMSG; CALL
WN5STATUS  % Mark swapper free`. It is written into `SWMSG` and nothing else. So **SWMSG sitting at
`PSWWAIT` is a receipt that `SWPD4` ran** — the swapper announced its completion and was marked
free. That is not an inference; nothing else in the file can produce that value.

**`SWPPING` is cleared by the ND-100 too:** `133747` (`X:=5MMESSAGE; ANSWER` — "restart proc. that
started the swapper"), and `136446` in `INLDATREADY` (`IF A=SWPPING THEN ... % Restart process`).

**No ND-500-side actor reads or writes `SWPPING` anywhere.** The value lives in SINTRAN's own
swapper-state space (5, 6, 7, 0o15), which is disjoint from the ND-500 statuses (0-4) the microcode
understands. So the first reading in the old section 5 is the right one:

> **Our chain walk skipping a `SWPPING` node is CORRECT, not a defect.** The missing step is further
> back, and the standoff is a symptom.

The generation gate is settled too, and settled as irrelevant: our servicer declares `3SWMESS` (05)
understood only on the ND500 generation, and the B30 dispatches it to `MSG_ILLEG` — but the walk
never reaches any MICFU dispatch for this node, so that arm has never run here and cannot be the
cause.

### 5a. What this rules IN, and the trap that nearly hid it

> **SUPERSEDED 2026-08-28 by section 7a - the conclusion below is WRONG.** The node reached
> `ANSWER(3)` fourteen times; it is not "a second MSWSTART that never completed". Kept
> because the reasoning is sound and only the evidence was short: it rested on a 400-entry
> ring that could not see the early walks. That is what the uncapped histogram fixed.

Between the `SWPPING` write at `133645` and the `ANSWER` at `133747` sit two guarded calls:

```
133733             X:=SWMSG
133734             CALL SLOCK;   GO FAR N500ERR
133736             CALL XTER500; GO FAR N500ERR      % Stop nd-500
133740             CALL ITO500XQ; CALL SUNLOCK       % Insert swapper-mess. in ex-queue
133742   SWME1:    CALL XACTRDY
133747             X:=5MMESSAGE; ANSWER; GO FAR XEILSTAT   % Restart proc. that started the swapper
```

**`N500ERR` (`134247`) PRINTS NOTHING** — `*IOF; CALL WN5STATUS; CALL XRSTARTALL; ...; GO MONEN`.
A silent exit there leaves the requester parked at `SWPPING` forever with a clean console. So
"nothing was printed after `> Loading Swapper`" is **not** evidence that the tail completed. That is
the RULE #0b shape again: an absent message is a fact about the printer, not about the machine.

But it is ruled OUT by the receipt: `XTER500` is *before* `ITO500XQ`, so an error exit there means
the swapper message never enters the execution queue, the swapper never runs, `SWPD4` never runs,
and `SWMSG` cannot be at `PSWWAIT`. It is. **So the MSWSTART tail did reach `133747` and did write
`ANSWER`.**

Which leaves exactly one account standing: the node we observe at `SWPPING` with `MICFU = 3SWMESS`
is a **later, second** `MSWSTART` that has not completed — the only writer that leaves that pair.
`5ACTSWAPPER` cannot be it (it overwrites `MICFU` with `3MONCO` at `145071`); `MSWSWAIT` cannot be
it (it restores `OLDMI` into `MICFU` at `134100`).

**The measurement that settles it**, and it needs no new instrument: the chain-visit ring already
records `N5STA` before and after every visit. Read the `3SWMESS` node's status history in order and
count how many times it enters `SWPPING`, and whether any of them reaches `ANSWER(3)`.

## 6. The method note, which cost more than any single answer here

Five refuted claims, and the two that survived longest — "the run thread is not the variable" and
"the bring-up never completes" — each came from **two instruments agreeing**.

They were not independent. The console and the served-MICFU census are both fed by *what did we
finish serving*, and `ProcessMessage` returns false for a TAKEN start, so **3START and 3MONCO never
enter that census at all** — the two messages carrying the whole difference are exactly the two it
cannot see.

Contrast the frame check, which was real corroboration: a command-enum decode and a raw word
histogram fail in **different directions**, so their agreement meant something.

**The test before quoting agreement: ask what each instrument CANNOT see. If the answer is the same
for both, it is one instrument wearing two hats.**

## 7. The short bring-up settles it: the stall is NOT about START-SWAPPER `[V]` 2026-08-28

`ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, run against `DOMS-CSFIX.IMG` (the only
pack carrying both the 262144-byte ND-5000 control store and CPU-STAT + SWAP-FILE +
DESCRIPTION-FILE). No `START-SWAPPER`, no `STATUS` — just `define-swap-file` then `place-domain`,
which is the NORMAL path: `ND-60.136.04A` 8.10.10.4 says the swapper load "is done automatically
when the first ND-500 process is initiated by the monitor".

```
ND-5000: place-domain cpu-stat
> Loading Control Store
> Loading Swapper
                       <- stops here, no "> Allocating memory", no prompt
OUTCOME: nd-500=OK place-domain=STALL run=STALL startMessagesSeen=1
```

**So the hypothesis this test was built to check is REFUTED.** Its own comment offered two outcomes;
this is the second one: *"it fails -> the hang is real and independent of START-SWAPPER, and we have
learnt that at the cost of one run instead of a debugging session."* Both paths stop at the same
place, after `> Loading Swapper`.

### 7a. What the ND-500 side actually did — and it did everything asked

The per-node status histogram (uncapped, so it answers "did it EVER", unlike the ring):

```
chain nodes visited: 421, not-answered: 306 (of which TAKEN-pending-stop: 2), served: 115
  @0x0042BE30 lastMICFU=0o0  : free=117                                  <- NEVER CHANGED
  @0x0042C130 lastMICFU=0o1  : ToNd500=100 ANSWER=2                      <- 3RMICV watchdog
  @0x00428D30 lastMICFU=0o23 : ToNd500=2 ANSWER=2 PSWWAIT=83             <- SWMSG, 3START
  @0x00428E30 lastMICFU=0o5  : ToNd500=15 ANSWER=14 SWPWAIT=1 SWPPING=85 <- requester, 3SWMESS
```

**RETRACTS section 5a.** That section argued the node parked at `SWPPING` had to be "a second
MSWSTART that never completed". It reached `ANSWER(3)` **fourteen times**. The `SWMESS` tail runs,
and runs repeatedly; the final `SWPPING` is a park after many successful cycles, not evidence of a
tail that never finished. The reasoning was sound and the conclusion was wrong, because it was built
on a ring that could not see the early walks — which is the whole reason the histogram now exists.

Everything the ND-500 was asked to do, it did: 115 served, `SWMSG` answered twice and marked free,
the requester answered fourteen times.

### 7b. Where it actually stops, stated as narrowly as the evidence allows

On a working lane the next line after `> Loading Swapper` is `> Allocating memory - 7116B pages`.
The allocation runs through `LALLOPAGE`, which sets `PSW1WAIT` into `SWMSG` (`MP-P2-N500.NPL:136513`).

**`SWMSG` never held `PSW1WAIT` — not once in 421 visits.** So the allocation never started. The
swapper is loaded, announced and marked free at `PSWWAIT` (83 observations), and SINTRAN then never
hands it the allocate work.

That is step 6 of the protocol again — `5ACTSWAPPER` hands work ONLY on `PSWWAIT`, and `SWMSG` IS at
`PSWWAIT` — but now reached from the ordinary `place-domain` path with none of the advanced commands
involved. **`[OPEN]`: what 5ACTSWAPPER is waiting for before it posts the allocate.**

### 7c. A blind spot in the new instrument, recorded rather than left to be rediscovered

The histogram records `N5STA` as read BEFORE each node is served. `TAKEN-pending-stop` counted 2, yet
no node ever shows `WAITING(2)` — because a node that is moved to `WAITING` and resolved between two
walks is never OBSERVED in that state. The counts do not contradict each other; they measure
different instants. Anyone reading "no node was ever WAITING" as "no start was ever taken" would be
wrong.

## 8. Both sides are waiting for the other, and neither is wrong `[V]` 2026-08-29

> **PARTLY SUPERSEDED by section 9.** The measurements here stand; the phrase "parked at its
> own wait point" and "stopped asking" do NOT. `0x08008255` is the instruction after a
> `MON 377B`, so the swapper asked and is waiting to be RESTARTED. Read 8a with that
> correction in mind - 9a replaces its open question.

Re-ran the short bring-up with a denominator on the trap counter (see 8a for why that mattered).
Every state line:

```
trapsAttempted=0 trapsPosted=0 lastTRAPN=0B
PC=0x08008255 stopMode=WAIT startSeen=1 startMicfu=23B startTaken=True
swpfu[LNEWSWAP:2]   ansMON=377B
```

Zero `TRAP-STOP` lines in the entire log. So the servicer was **never asked** to post a trap — this
is not a drop, it is an absence.

Put together with the histogram, the whole standoff reads out:

 - The swapper was started (`3START` taken), **ran**, made its `MON 377B` calls with
   `SWPFU = LNEWSWAP` twice, and **stopped**: `PC=0x08008255 stopMode=WAIT`. Same PC in the full
   flow and in the short bring-up, run after run. It is parked at its own wait point.
 - SINTRAN answered by marking it free — `SWMSG` at `PSWWAIT`, 85 observations — and is now waiting
   for something to give the swapper work.
 - `5ACTSWAPPER` has exactly three callers and every one of them needs an event that has not
   happened: a **page fault** (`TRAPDECODER` trap 46), an allocate answer coming back
   (`SWMESS`/`MSWSWAIT`), or a process already queued at `SWPWAIT` (`SWPD4` draining the FIFO).
 - No fault has occurred, because nothing is running to fault. `PLACE-DOMAIN` records metadata only;
   the content arrives by demand paging, and demand paging needs a running process.

**Neither side is stuck in the sense of being broken. Each is idle waiting for the other**, and the
event that should break the tie has not happened.

### 8a. `LNEWSWAP` twice and nothing else is the sharpest clue

`swpfu[LNEWSWAP:2]` — the swapper asked "what is my work?" twice and never asked anything else. On a
lane that gets past this point the console prints `> Allocating memory - NNNN pages`, and the
allocation runs through `LALLOPAGE`, which writes `PSW1WAIT` into `SWMSG`. **`SWMSG` never held
`PSW1WAIT` in 421 visits.**

So the question is no longer "why does SINTRAN not hand out work". It is: **why does our swapper only
ever ask `LNEWSWAP`, and never the allocate function?** That is a question about the swapper program
executing on our CPU, and `PC=0x08008255` is where it decided to stop asking.

`[OPEN]`, and the next step is to disassemble around `0x08008255` and read what the swapper tests
before choosing its `SWPFU`.

### 8b. Why the trap counter needed a denominator before any of this could be said

`TrapStopsPosted` is incremented only on the SUCCESS path of `AnswerTrapStopLocked`. A post that
cannot resolve a message for the running process returns `false` without touching it, and that
routine's own comment says the decline "is invisible from outside".

So `trapsPosted=0` alone could not tell **"the CPU never trapped"** from **"every trap we tried to
report was dropped here"** — opposite investigations behind an identical reading. That is the
unfalsifiable-single-number shape, and the previous section's lead rested entirely on it.

`TrapStopsAttempted` is now incremented before anything can refuse, so `attempted > posted` means
dropped and `attempted = posted = 0` means never raised. It reads 0 and 0, which is what licenses the
paragraph above — and would not have been safe to write from the old counter.

## 9. `0x08008255` is the instruction AFTER a `MON 377B` — section 8 called it the wrong thing `[V]` 2026-08-29

Disassembled. `PC = 0x08008255` is `0o1000101125` in the swapper listing
(`NDInsight\SINTRAN\ND500\swapper\swapper-k01-pseg.asm`, line 10536):

```
1000101077: call $1777777777777000000377,$4,$1000225050,$1000440260,$1000440264,b.24 ; MON 377B
1000101125: 322 010      if -k go $10        <- THE PC WE STOP AT
1000101127: call $1000100674,$0
```

It is the instruction **immediately after a `MON 377B` call**, which is to say the swapper's
**restart address**. On the ND-500 a monitor call IS a stop: the process parks, SINTRAN answers, and
the process resumes at the address after the call. `P` runs ahead of the call for exactly this
reason — the same `P` vs `P1` distinction that already bit this project.

**So section 8 is wrong where it matters.** It said the swapper "is parked at its own wait point" and
had "stopped asking". It has done nothing of the sort: **it asked, and it is waiting to be
restarted.** The observation was right and the interpretation inverted the direction of the wait.

Four independent readings agree that this is that call and not another one:

| what the state line says | what the disassembly says |
|---|---|
| `ansMON=377B` | the call is annotated `MON 377B` |
| `ansArgc=4` | the call passes `$4` arguments |
| `ansP=0x08008255` | the instruction after the call is at `0o1000101125` |
| `ansArg0=0x00000001`, `ansSWPFU=1B` | `SWPFU = LNEWSWAP = 1` |

### 9a. The question that replaces section 8a

Not *"why does our swapper never ask for the allocate"* — it is asking, and the answer it gets is
what decides its next `SWPFU`. The `if -k go` on the very next instruction is the swapper reading the
**K flag** out of SINTRAN's answer, which is the documented restart channel (`KFLIP` -> K,
`FUNCV` -> `X1`).

So: **we answered the MON 377B — `ansMON=377B`, `ansP=0x08008255` — and the CPU did not resume.**

`swpfu[LNEWSWAP:2]` against `restarts=1/1` is the gap to chase: two monitor calls, one restart seen
and taken. `[OPEN]`: for each `MON 377B` answered, was a restart offered, and was it taken? The
servicer already carries `MonitorCallRestartsSeen` against `Taken` for exactly this shape of
question; what is missing is the per-call pairing rather than a run total.

### 9b. Twice in one night, and the same cause both times

Section 5a claimed a node never completed; the histogram showed fourteen completions. Section 8
claimed the swapper stopped asking; the disassembly showed it asking and waiting. Both were
confident readings of a real measurement, and both inverted the direction of the thing measured.

The common cause is not carelessness about the data — it is **naming a state before reading the code
that produces it**. `stopMode=WAIT` at a PC says nothing about WHY until you know what instruction
that PC belongs to, and one grep of the listing settled it. The project rule already says this:
go and read the code, do not derive.

## 10. `posted=2 seen=1 taken=1` — SINTRAN never came back `[V]` 2026-08-29

> **VERDICT SUPERSEDED by section 11.** The counts below are right and the instrument fix was
> worth making. "SINTRAN never came back" is NOT - an unanswered swapper MON 377B at
> `PSWWAIT` is the DESIGNED IDLE state (`LNEWSWAP`, MP-P2-N500.NPL:135470). Read 10a and
> 10b, which stand; ignore the headline.

The measurement section 9a asked for, on the short bring-up against `DOMS-CSFIX.IMG`:

```
----- MON restart path (octobus-shortbringup) ----- posted=2 seen=1 taken=1
   <- SINTRAN NEVER CAME BACK for 1 of the stops we posted: those processes are
      parked on a monitor call that was never restarted. Look at the ND-100 side,
      not at the CPU.
```

Two `MON 377B` stops posted, **one** restart offered, one taken. So the swapper's second monitor call
was never answered, and it is still sitting on it at `PC=0x08008255` — the instruction after the
call, per section 9.

**This localises the remaining work to the ND-100 side.** Everything the ND-500 was asked to do, it
did; the CPU is not refusing anything. `[OPEN]`: why SINTRAN answers the first `MON 377B` and not the
second.

### 10a. The pair that was built to catch this could not see it

`MonitorCallRestartsSeen` against `Taken` exists precisely because a single number "could only be
believed" — it is this project's model instrument, and the MON-path ledger cites it as the way to
tell a forwarded run from a faked one. **It starts counting at the OFFER.** A stop that never got one
is outside its field of view, so it printed

> `no gap - every restart offered was taken by the CPU`

while the swapper sat on an unanswered call. That sentence is true of what it measures. It is also
the reason this took an extra day.

### 10b. Three instruments in one night, one failure mode

| instrument | what it reported | what it could not see |
|---|---|---|
| `TrapStopsPosted` | `0` | a post that was DROPPED — incremented only on success, and the decline path says so in its own comment |
| chain-visit ring | the steady state | the first ~50 of 609 visits — so "did this node ever reach `ANSWER`" was unanswerable. It had, 14 times, refuting section 5a |
| `RestartsSeen`/`Taken` | `no gap` | a stop that never got an offer |

Each was honest about what it measured and silent about what it could not. None was wrong; all three
were unfalsifiable in the direction that mattered. **The question that finds this class before it
costs a day is not "is this number right" but "what would this number look like if the thing I fear
were happening?"** For all three the answer was *identical to what it already showed*.

The fix is the same shape every time: give the number a denominator, or a second count that must
agree with it — `attempted` beside `posted`, an uncapped histogram beside the ring, `posted` beside
`offered`.

## 11. Section 10's VERDICT is wrong — an unanswered swapper call is the designed idle `[V]` 2026-08-29

Carved `LNEWSWAP` (`MP-P2-N500.NPL:135470`) before building anything on section 10, and it refutes
the interpretation there. The numbers in 10 stand; the sentence "SINTRAN NEVER CAME BACK … look at
the ND-100 side" does not.

```
135470   LNEWSWAP:
135470          AD := SWMSG.HSWPI                      % the node the swapper is currently serving
135474          IF D >< 0 THEN                         % anything being served?
...
135575             IF A/\17777=SWPPING THEN            % that node is "using the swapper"
135604                IF 3SWMESS=D THEN                % message to swapper?
135626                   CALL RN5STATUS; A/\160000\/ANSWER
135631                   GO FAR SWPD2                  % yes - restart the ND-100 proc
```

Then `SWPD3`/`SWPD4` mark `SWMSG := PSWWAIT` (free), drain the swap FIFO, and `GO NXTMSG`.

**Nowhere in that path is the SWAPPER's own `MON 377B` answered.** The swapper is deliberately left
parked and marked free; it is woken later by `5ACTSWAPPER`, which sets `MICFU := 3MONCO`
(`145071`) and calls `MCCO` — and THAT is the restart our counter sees.

So `posted=2 seen=1` is **exactly what a healthy idle swapper looks like**: one call restarted with
work, one call parked as "free, waiting for something to do". It is a STATE, not a fault, and
section 10's verdict pointed at the wrong side of the bus.

This also explains the histogram cleanly: the `3SWMESS` node reaching `ANSWER` fourteen times is
`135626` doing its job every round.

### 11a. I put the wrong conclusion INSIDE the instrument, which is worse than putting it in a doc

The harness line did not merely report `posted > seen`. It printed **"SINTRAN NEVER CAME BACK … Look
at the ND-100 side, not at the CPU"** — a verdict, baked into the tool, that would have mis-aimed
every future run and every reader of every future transcript. A wrong sentence in a document is read
once by someone who can see its date; a wrong sentence in an instrument is re-asserted on every run
with the authority of a measurement.

Corrected: the line now reports the count and says explicitly that it is a state, not a verdict,
names the designed idle path with its line numbers, and tells the reader to check WHICH process is
parked before calling it a fault.

**The rule this earns:** an instrument may report what it counted; it must not name a culprit. Every
verdict string is a hypothesis that will outlive the evidence for it.

### 11b. Fourth correction of the night, same cause, and I had already written the rule

9b named it: *naming a state before reading the code that produces it*. Then I did it again, in the
one place where it does the most damage. The carve that settles it is two greps and five minutes,
and it must come BEFORE the wording, not after — the interpretation is the expensive part, not the
number.

**Where this leaves #56, stated with no verdict attached:** the swapper is idle-parked and correct.
`SWMSG` never held `PSW1WAIT` in 421 visits, so `LALLOPAGE` never ran and `> Allocating memory` never
printed. `5ACTSWAPPER`'s three callers all need an event — a page fault, an allocate answer, or a
process queued at `SWPWAIT` — and `trapsAttempted=0` says no trap was ever raised. The open question
is unchanged from section 8 and was never really about the restart: **what should be running that
would fault, and why is nothing running?**

## 12. A REGRESSION: the lane used to reach allocation `[V]` 2026-08-29 (confirmed in 12d)

The swap-file hypothesis from the previous tick is REFUTED, by the discriminator built to test it:
with `define-swap-file` skipped entirely, the run stalls in exactly the same place, after
`> Loading Swapper`. No swap file, same stall. So the swap file is not the variable.

What is the variable is TIME. Two records in `ND500-STATUS-AND-INDEX.md`, both on this lane:

| date | command | domain | result |
|---|---|---|---|
| 2026-07-31 | `RECOVER-DOMAIN` | LINKAGE-LOAD-H02 | `> Allocating memory - 7110B pages` → 5SWAP protect violation at `1 10533B` |
| 2026-08-01 | `ND-5000: LINKAGE-LOADER` | (installed) | same message, same trap, **same address** |

Different commands, different domains, and on 31 July the ND-500 **ran for about seven and a half
minutes** (02:57:12 → 03:04:46) before failing. That is a lane which reaches allocation, runs a
domain, and dies in a *known, carved* way — the 5SWAP `RPHS` protect violation, whose `P` value
`0o1000010533` is already recorded.

**Tonight, 29 August, it does not get that far.** `place-domain`, `recover`-style install, with a
swap file, without a swap file, on the stock pack, on DOMS-CSFIX — every one stalls after
`> Loading Swapper` and never prints `> Allocating memory`.

**So sections 7 through 11 have been characterising a REGRESSION, not the original blocker.**
Everything measured there is true of the machine as it stands today, and none of it was true four
weeks ago. The swapper being idle-parked, `posted=2 seen=1`, `trapsAttempted=0`, `SWMSG` never
reaching `PSW1WAIT` — all of that is the *shape* of the regression, not a standing property of the
octobus lane.

### 12a. What this changes about the next step

The question is no longer "why does nothing fault" or "what does the classic lane do differently".
It is **what changed in this tree between 2026-08-01 and now**, and that is a bisect-shaped question
over RetroCore's octobus, servicer and CPU paths rather than another microcode carve.

`[OPEN]`. Worth noting that August included the ND500/ND5000 rename sweep (95 identifiers) and a
good deal of generation-gating work, both of which touch exactly the code that decides what the
octobus lane does after the swapper loads.

### 12b. The cheap check I did not do for four hours

Every run tonight produced the same three console lines, and the question "has this EVER got
further?" was one grep of the existing records away. It would have cost two minutes at the start and
would have reframed everything after it — the histogram, the trap denominator, the restart triple
and the four self-corrections all happened inside an assumption that this was the normal state of
the lane.

The instruments are worth keeping and the carves are all correct. But the FIRST question about any
stall should be **"is this new?"**, and the records that answer it were already in the repo.


> ## 12c. THE REGRESSION CLAIM IS NOT YET EARNED — I made the same mistake again `[OPEN]` 2026-08-29
>
> I checked the lane (correctly — the July records ARE from
> `Nd100SintranNd5000OctobusBootHarnessTests.cs`, so the octobus lane, not classic) and then
> promptly attributed a four-way difference to time.
>
> The 2026-07-31 record is test **`Nd500SwapFile_CreateAndDefine_Capture`**, with
> `RETROCORE_NLL_FLOPPY=1` and `RETROCORE_ND5000_RUNTHREAD=1`, on **BIGDISK0-L** with a swap file
> **created in session**, using **RECOVER-DOMAIN**. Tonight's runs are
> `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, no floppy, on **DOMS-CSFIX**, using
> **PLACE-DOMAIN**. That is four differences, and "the date" is the only one I have no evidence for.
>
> **So section 12 above is a HYPOTHESIS, not a finding.** It is bannered rather than deleted because
> the underlying observation — this lane HAS reached `> Allocating memory` and run a domain for 7.5
> minutes — is real and important either way.
>
> Worse, that same July document lists as its **blocker #1**: *"`@SET-AVAIL` was never run before
> `@ND-500` — with it, RECOVER-DOMAIN stops stalling at Loading Swapper"*. **Stalling at
> `> Loading Swapper` is the exact symptom that document was written to close.** My runs do issue
> `set-avail`, so it is not simply missing — but a symptom with a known prior cause deserved that
> check before I proposed a bisect.
>
> **The decisive run, now in flight:** the July configuration exactly —
> `Nd500SwapFile_CreateAndDefine_Capture` with `RETROCORE_NLL_FLOPPY=1` and
> `RETROCORE_ND5000_RUNTHREAD=1`, stock pack, on today's code.
>  - reaches `> Allocating memory` → **there is no regression**; tonight's stall is a property of
>    the ShortBringup configuration (pack, command, or the missing floppy), and sections 7-12 are
>    describing that configuration rather than the lane.
>  - stalls after `> Loading Swapper` → the regression claim is earned and the bisect is the right
>    next step.
>
> **The pattern, three times in one night:** wrong pack read as a machine fault; a state named
> before reading the code that produces it; and now a multi-variable difference attributed to the
> one variable I found interesting. Each time the fix was to change ONE thing and re-run, and each
> time it was available immediately.


## 12d. CONFIRMED: it is a regression. Like-for-like, only the code date differs `[V]` 2026-08-29

> **Read 12f with this.** The test named here was first committed 2026-08-02, so the July runs
> came from an uncommitted working tree and the HARNESS has changed too. The guest-visible
> state matched exactly; "the emulator regressed" is not yet isolated from "the harness
> drives it differently now".

Ran the July configuration exactly, on today's code:

| | 2026-07-31 | 2026-08-29 (today) |
|---|---|---|
| test | `Nd500SwapFile_CreateAndDefine_Capture` | same |
| env | `RETROCORE_NLL_FLOPPY=1`, `RETROCORE_ND5000_RUNTHREAD=1` | same |
| pack | stock `BIGDISK0-L`, swap file created in session | same |
| swap file | `(PACK-ONE:SYSTEM)SWAP-FILE-0:SWAP;1`, addr `76110B`, `11610B` pages | **identical, digit for digit** |
| command | `recover-domain (210319H02:FLOPPY-USER)LINKAGE-LOAD-H02` | same |
| result | `> Allocating memory - 7110B pages`, ND-500 runs ~7.5 min, 5SWAP protect violation | **`> Loading Swapper`, then nothing** |

`list-swap-file-info` reporting the same mass-storage address and the same `11610B` free part as the
July transcript is the tightest control available here: the machine, the pack and the swap file are
in the same state, and the command is the same. **The only variable left is the code.**

So section 12's hypothesis is upgraded, and 12c's caution is discharged — by doing the one thing
12c said would settle it, rather than by arguing.

**Sections 7-11 therefore describe a regression introduced between 2026-08-01 and 2026-08-29.** The
measurements stand; they are the shape of the regression. The swapper being idle-parked,
`posted=2 seen=1`, `trapsAttempted=0`, `SWMSG` never reaching `PSW1WAIT` — that is what this bug
looks like, not what the octobus lane is.

### 12e. The next step, and what NOT to do

Bisect over RetroCore between roughly `2026-08-01` and now, running
`Nd500SwapFile_CreateAndDefine_Capture` with `RETROCORE_NLL_FLOPPY=1` and
`RETROCORE_ND5000_RUNTHREAD=1` at each probe, scoring on whether `> Allocating memory` appears.
About 30 minutes per probe, so pick candidates by inspection first rather than bisecting blind.

**Do NOT** carve further microcode for this. Four hours went into characterising the stall's
mechanics, and every one of those answers is correct and none of them is the cause. The cause is a
change in this tree, and the fastest route to it is `git log` over the octobus, servicer and CPU
paths in August.


## 12f. A caveat on 12d, and what it does to the bisect `[V]` 2026-08-29

`Nd500SwapFile_CreateAndDefine_Capture` was **first committed on 2026-08-02** (`ad1d18c16`, "Boot
harness: ND-500 swap file + LINKAGE-LOADER installer tests"). The July document dates its runs
2026-07-31 and names that test — so those runs were made from an **uncommitted working tree**, two
days before the test entered git.

That does not undo 12d, but it narrows what it proves. What is still exactly matched, and it is a
lot: the same machine, the same stock pack, a swap file created in session reporting the **same mass
storage address `76110B` and the same `11610B` free part**, and the same `recover-domain` command.
What is NOT matched is the harness itself — the test file has changed since, including 109 lines
added as recently as `25d7c5e14` (2026-08-28, "Give RouteB its own swap file"), though that commit
touches only the test file and not the servicer or CPU.

**So the honest claim is:** the guest-visible state was identical and the outcome was not, and
*something in this tree* changed it — but "the emulator regressed" is not yet isolated from "the
harness drives it differently now". Both are code, and both changed.

### What this does to the plan

 - **The bisect cannot start before 2026-08-02.** There is no commit where the July test exists and
   the July behaviour can be reproduced, because on 07-31 it existed only in a working tree.
 - **The first probe is `ad1d18c16` itself.** If it reaches `> Allocating memory`, the range is
   `ad1d18c16`..HEAD (a few hundred commits, ~9 probes) and the bisect is well-founded. If it does
   NOT, then the behaviour was never in git and the July result came from uncommitted work — in
   which case bisecting is the wrong tool entirely and the question becomes what that working tree
   had that the commit did not.
 - That second outcome is worth naming in advance, because it is the one that would waste a night of
   30-minute probes if discovered on probe six.

`[OPEN]`.


## 13. The bisect is NOT VIABLE: the history does not build `[V]` 2026-08-29

Two probes in a detached worktree (`git worktree add --detach`, so the shared tree the other session
is working in was never touched):

| probe | commit | result |
|---|---|---|
| the "good" end | `ad1d18c16` 08-02, the commit that first carries the July test | **16 build errors** — the test references `SintranLayer.Mon50Count`, `ND100Machine.FindDiscControllerSmd` and others that do not exist at that commit |
| the midpoint | `5140889ec` 08-18 | **3 build errors** — `XmsgClient.PostMultiCall` signature mismatch, unrelated to ND-500 or octobus |

Both failures are the same shape: a file committed against a version of the library it does not
match. **Commits in this range are not individually buildable**, so a bisect over them cannot run,
and patching each probe enough to compile would change the code under test — which is the one thing
a bisect probe must not do.

This is the outcome 12f named in advance, arriving on probe one instead of probe six. Writing it
down before starting is what made a two-probe stop cheap instead of a six-probe one.

### 13a. What to do instead

The runtime comparison is exhausted for now — sections 7-12 measured the stall thoroughly and
correctly, the swap file is refuted, the CPU-kind explanation is refuted, and the history cannot be
run. What is left is **reading the diff** over the servicer, octobus and ND-100 machine paths
between `ad1d18c16` and HEAD, looking for a behavioural change in what happens after the swapper
loads.

Two candidates worth reading FIRST, both because they change defaults rather than logic and so would
not show up as an obvious bug:

 - `b066f83b2` "Snapshot before the env-var to config migration" — a migration that moves behaviour
   from environment variables into config is exactly the shape that silently changes a default.
 - `8faa83da7` "ND-500: production wiring for attached CpuND500 + config-driven identity" — same
   shape, on the CPU identity.

**Do not** resume microcode carving for this, and do not re-measure the stall. Both are done.

### 13b. Worth saying plainly

The stall was characterised in detail, four wrong interpretations of it were caught and retracted,
three instruments were given the denominators they needed, and the cause is still not found. What
changed is that the question is now small and well-posed - *what in this tree, between 2 August and
now, stops the swapper being given work* - instead of the open-ended "why does the octobus lane not
run a domain" it started as.

## 14. The diff read is the WRONG next step, and a record two days old says why `[V]` 2026-08-29

Before reading 110 commits I looked for the nearest prior record of this lane. It is in this repo's
own `docs\` folder: `DOM-CORPUS-REAL-SINTRAN-RUN-2026-08-27.md`, section 1b, dated **2026-08-27**.

It runs the SAME test, `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, and records:

| | 2026-08-27 (§1b of the corpus doc) | 2026-08-29 (sections 7-11 above) |
|---|---|---|
| `startSeen` | 1 | 1 |
| `startMicfu` | 23B (3START) | 23B |
| `startTaken` | True | True (`taken=1`) |
| page writes | 13 `PHYSWR` | the same copy family |
| MON 377B | one answered, **`ansSWPFU=1B`** | one answered, `SWPFU=1` (LNEWSWAP) |
| where it parks | `PC=0x08008255` | `PC=0x08008255` |
| `place-domain` | did not finish in 300 s | STALL after `> Loading Swapper` |

That is the same state, measured two days apart, and the corpus doc already names it as the lane's
standing open question, verbatim: *"The swapper is parked on a MON 377B that gets no further
restart. That is the next question."*

### 14a. What this does and does not change

 - **12d still stands, narrowly.** July reached `> Allocating memory`; today it does not. That
   comparison was run like-for-like and it is not withdrawn.
 - **12's framing does NOT stand.** It said sections 7-11 "have been characterising a REGRESSION,
   not the original blocker", and that none of it "was true four weeks ago". Two days ago it was
   true, and was written down as the lane's open question. Sections 7-11 re-derived a state that
   was already recorded — with better instruments, which is worth something, but not as new ground.
 - **13a's diff read is therefore misdirected.** Reading the servicer/octobus/ND-100 diff over
   `ad1d18c16`..HEAD looks for a change that made the lane stop working. The lane has been in this
   exact state for at least the last two days of that range, and the question that separates
   working from not-working is a protocol question, not a `git log` question.

### 14b. The question, stated once, from both records

`SWPDECODER` (`MP-P2-N500.NPL:135443`) is a `GOSW` on `SWPFU`, the function the SWAPPER asks the
ND-100 to perform:

```
0 ESWPFATAL   1 LNEWSWAP   2 LSWPAGE   3 LPRSUSPEND   4 LALLOPAGE   5 LDATREADY   6 LCLTSB
```

**The swapper only ever asks `SWPFU=1` — `LNEWSWAP`, "I am free, find me the next process that
wants me".** It never asks `SWPFU=4` (`LALLOPAGE` @136513), which is the arm that sets `PSW1WAIT`
into `SWMSG` — and section 7b measured that `SWMSG` never held `PSW1WAIT`, not once in 421 visits.
The two records agree on this from opposite directions: 08-27 read it off the answer (`ansSWPFU=1B`),
08-29 read it off the status histogram.

So the swapper is not stuck. **It is idle because nothing is queued for it**, and the question is
what puts a process on the swapper's request list on the classic lane and fails to on the octobus
lane. `5ACTSWAPPER` has exactly three callers (135367 `TRAPDECODER` trap 46, 134154 `MSWSWAIT` tail,
136037 `SWPD4` FIFO drain) and that is where to look.

The cheapest discriminator available: the servicer already carries a **SWPFU histogram**
(`Nd500MicrocodeServicer.cs:312`). Run the CLASSIC lane, which does reach allocation, and compare
its SWPFU histogram against the octobus one. If classic shows a `4`, the difference is located in
one number rather than in 110 commits.

### 14c. The lesson, which is 12b's lesson applied one step too shallowly

12b said the first question about any stall should be *"is this new?"*, and it was right. But it was
asked of a July document and stopped there. The **nearest** record was two days old, in this repo,
and it answered the question better: not "is this new" but "has anyone already written this down".
A four-week-old record told me the lane once worked. A two-day-old record told me the lane is in a
known, named, still-open state — which is the more useful fact and the cheaper one to find.

### 14d. `5ACTSWAPPER` has FOUR callers, not three — the fourth is a MON call `[V]` 2026-08-29

Earlier notes in this session (and 14b above) list three callers. `grep -n 5ACTSWAPPER
MP-P2-N500.NPL` gives four:

| line | caller | what hands the swapper work there |
|---|---|---|
| `134154` | `MSWSWAIT` tail | restart-swapper-and-wait, after an allocate-page |
| `135367` | `TRAPDECODER`, trap 46 | a page fault, gated on `5INITFLAG NBIT BRESPLACE` / `SYSINITFLAG NBIT BSWSTARTED` |
| `136037` | `SWPD4` FIFO drain | the queue behind the swapper's own completion |
| **`141765`** | **`SWMC`** | **a MONITOR CALL to the swapper** — missed until now |

`SWMC` (`MP-P2-N500.NPL:2047`, header *"MONITOR CALL TO THE SWAPPER, DRIVER LEVEL"*) is:

```
141753   SWMC:  MSM510 SHZ 10=:D; T:=5MBBANK; *AAX TRAPN; LDATX
141761          A/\377+D; *STATX; AAX -TRAPN
141765          CALL 5ACTSWAPPER; GO NXTMSG
```

**Its MON number is 510B, and the arithmetic pins it two ways.** `MCHANDEL` (`137332`) routes
`L12MIN <= A <= L12MAX` through a `GOSW` on `A - L12MIN`; `SYMBOL L12MIN = 500`, `L12MAX = 523`
(`136764`), and `SWMC` is the **ninth** arm — `500B + 8 = 510B`. The routine's own constant is named
`MSM510`. Anything outside 500B..523B goes to `NORMMC` and is handled by the system monitor, so
**MON 377B — the call our swapper parks on — is NOT a swapper-activation call**; it falls through to
the ordinary monitor.

Why it matters here: it is a fourth, independent way for work to reach the swapper, and it is the
only one that a *user process* can trigger directly rather than by faulting. So "nothing is queued"
now has four possible causes to separate, not three, and one of them is observable as a MON number
we have never seen on this lane.

**How the count came to be wrong:** the three-caller list was assembled from the routines that were
interesting at the time (the swapper's own state machine), not from an exhaustive grep of the
symbol. One `grep -n` settles it, and it is the same shape as every other lost fact in this project
— a correct observation about a subset, recorded as if it were about the whole.

### 14e. 14b's discriminator is REFUTED, and the working lane supplied a better one `[V]` 2026-08-29

`nd500uc-47` added `SwpfuHistogram()` to the classic harness (their commit `a285d75da`) and ran
`Nd500_LinkageLoader_UnderRealSintran_RealCpu_Capture`. Their number, beside mine (mine read out of
this session's own run logs, `swpfu[...]` in `%LOCALAPPDATA%\Temp\fullflow-run.txt`):

| SWPFU arm | classic (reaches `> Allocating memory`) | octobus (stalls) |
|---|---|---|
| 0 `SWACTIVE` / `ESWPFATAL` | **80** | **0** |
| 1 `LNEWSWAP` | 112 | 5 |
| 2 `LSWPAGE` | **84** | **0** |
| 4 `LALLOPAGE` | **0** | **0** |

**14b was wrong.** I proposed "does classic show a 4?" as the one-number discriminator. Classic
shows no 4 either, reaches allocation anyway, and so the ABSENCE of `LALLOPAGE` distinguishes
nothing. Their words, and they are right to have said them rather than let me build on it: *"I'd
rather tell you that than let you build on a difference that isn't there."*

**What the same table gives instead is a POSITIVE control, which is strictly better than the
absence argument sections 7-11 were built on.** Two arms separate the lanes:

 - **Arm 2 `LSWPAGE`: 84 on classic, 0 here.** The classic swapper asks for page work. Mine never does.
 - **Arm 0: 80 on classic, 0 here.** And arm 0 is not what the histogram called it.

### 14f. Arm 0 is `SWACTIVE`, and `SWACTIVE = 0` — the instrument was mislabelling the common case

`SWPFU` has TWO writers using one field in opposite directions:

 - the ND-500 SWAPPER writes its REQUEST code (1 `LNEWSWAP`, 2 `LSWPAGE`, ...) when it calls out;
 - **the ND-100 writes `SWACTIVE` into `SWMSG.SWPFU` when it HANDS WORK OVER** —
   `MP-P2-N500.NPL:145011` inside `5ACTSWAPPER`, and again at `133666` in `SWMESS`.

`SWACTIVE = 0` `[V]` — `N5SWAP-SWMSG-FIELD-DOSSIER-RELAY-2026-08-17.md:66` grades it PROVEN against
L07:3594/3479, and `OCTOBUS-SWAPPER-HANDOFF-2026-07-25.md:2604` gives the same value from L07/K03.

So bucket 0 is dominated by HANDOVERS, not fatals, and the histogram printing `ESWPFATAL:80` invited
exactly the wrong reading — eighty fatal swapper errors on a run that completed the load normally.
The peer spotted the shape without the carve (*"zero-as-both-failure-and-sentinel"*) and asked; the
carve answers it. **Fixed in the shared servicer**, commit `ce809640d`: the label is now
`SWACTIVE-or-ESWPFATAL`, with the two writers and both line numbers in the remarks, and the stale
"4 = allocate page is the one that matters" comment at the feed site is corrected in place.

That is instrument-failure mode #7 in a new dress: a bucket that cannot separate "nothing decided
yet" from "it failed", carrying a name that claimed it could.

### 14g. The question, restated with the positive control

**`SWACTIVE` appears 80 times on the working lane and never on mine.** `SWACTIVE` is written by the
ND-100, at the moment it hands the swapper a job. So this is no longer "the swapper never asks for
work" inferred from an absence — it is **the ND-100 never hands this swapper any work**, measured
against a lane where it hands it work eighty times.

That points at the four `5ACTSWAPPER` callers in 14d rather than at the ND-500 side at all. Next: of
those four, which one fires 80 times on the classic lane. `5ACTSWAPPER` is shared ND-100 code, so
whatever gates it is reachable from both transports and is being gated OFF on one of them.

**Caveat the peer raised, kept because it bounds the claim:** one run, and it is not yet confirmed
whether their histogram is cumulative across two capture passes (the block prints twice with
identical numbers, which suggests per-pass). The 80/84-vs-0 contrast survives any such factor; the
exact counts do not, and nothing above depends on them.

### 14h. The dominant handover route on the working lane looks like `TRAPDECODER`, trap 46 `[D]` 2026-08-29

> **DOWNGRADED FROM `[V]` TO `[D]` BY 14i, SAME DAY.** The heading below was graded `[V]` on a
> correlation the peer has since retracted, and the carve alone does not settle it: `SWPST=0x0A` is
> reachable on BOTH forks. The mechanism described here is `[V]`; the CONCLUSION about which fork
> ran is not. Read 14i before using this.

`nd500uc-47` ran a SWPST census over 40 MON 377B lines on the classic lane (their capture prints its
diagnostic block TWICE — the first 40 lines are byte-identical to the last 40 — so their raw counts
were doubled; these are the corrected ones):

| SWPFU | SWPST | count |
|---|---|---|
| 0x0000 `SWACTIVE` | **0x000A** | **20** |
| 0x0002 `LSWPAGE` | 0x000B | 13 |
| 0x0002 | 0x0010 | 2 |
| 0x0002 | 0x000C | 2 |
| 0x0000 | 0x0018 / 0x000F / 0x000E | 1 each |

They read this as the 3SWMESS message fork, on the grounds that no SWPST equals a trap number.
**That reading is refuted, and the field it rests on cannot discriminate.**

`SWPST` is written by `5ACTSWAPPER` at `145054`, and the fork above it is:

```
145043      *SWFUN@3 LDATX          % MICFU was 3SWMESS - take SWFUN
145045      *AAX TRAPN; LDATX       % otherwise a trap (page fault)
145047      A=:D/\377; *STATX       % TRAPN := its LOW byte only - stripped in place
145052      A:=D SHZ -10            % A := the HIGH byte
145054      X:=SWMSG; *AAX SWPST; STATX
```

and the trap arm reaches it from `TRAPDECODER`:

```
135332   ELSE IF D = 46 THEN                 % PAGE FAULT   (46 OCTAL - NPL default in this file)
135361      MSWPFAULT SHZ 10 + D             % (MSWPFAULT << 8) | trapno  ->  TRAPN
135367      CALL 5ACTSWAPPER
```

So the trap fork puts a **function code**, not a byte of the trap number, into `SWPST` — and
**`MSWPFAULT = 0o12 = 10 decimal = 0x0A`** `[V]` (`ND500-MAILBOX-MESSAGE-CATALOG.md:143`,
`ND500-SWAPPER-ANALYSIS.md:654`, both citing line 135361). Their dominant row, `SWPST=0x000A` 20
times, is exactly and only what `TRAPDECODER` produces. Their own capture confirms it from the other
side: they report `TRAPN=0x0026` on those lines, and `0x26` = 38 decimal = **46 octal**, the trap
number `135332` tests for.

`MSWPFAULT` is itself a member of the `MSW*` namespace (`MSWFI=0`, `MSWSTART=0o7`, `MSWFO=0o10`,
`MSWIP=0o11`, `MSWPFAULT=0o12`, `MSWME=0o13`, `MSWSWAIT=0o24`, `MSWDO=0o34` max), so **"SWPST is a
small value in the SWFUN space" is true on BOTH forks and separates neither.** The field that
separates them is `TRAPN`: the trap fork strips it to its low byte at `145047`, the message fork
never touches it.

Reading of the rest, `[D]` not `[V]`: the other SWPST values (`0o13`, `0o14`, `0o16`, `0o17`, `0o20`,
`0o30`) are the message fork carrying `SWFUN`, so **both forks are live on the working lane**, with
the page-fault one dominant at half the traffic.

**What it buys.** 14d left four call sites as equal candidates. The working lane says the dominant
one is **`135367` — `TRAPDECODER`, trap 46** — which is one of the seven addresses armed in
`ArmSwapperHandoverWatch()`. The run in flight now has a specific prediction to fail against.

**Method note, and it is the second time today.** Their test was well-formed and its premise was
wrong: it asked whether `SWPST` looks like a piece of the trap number, when the packing puts a
function code there. An instrument aimed at the wrong field returns a clean, confident answer — the
same shape as the `SWPFU=4` discriminator I asked them for, which also returned cleanly and meant
nothing. **Ask what a null result would tell you before you ask for the measurement.**

### 14i. 14h was graded `[V]` on a 95%-constant field, and `SWPST=0x0A` cannot pick a fork anyway `[V]` 2026-08-29

`nd500uc-47` retracted the correlation 14h leaned on, and the retraction is right. Read in ORDER
instead of as a census, their 40 lines give:

 - **`TRAPN=0x0026` on 38 of 40 lines — a base rate of 95%.** So "`SWPST=0x0A` pairs with `0x0026`
   in 20 of 20" is what chance produces when the second field barely varies. It reads as a perfect
   correlation and carries almost nothing.
 - **Line 1 already carries `0x0026`**, before any `SWPST=0x0A` line exists. So that `0x0026` cannot
   have come from the packing it was credited to.

Their rule from it, which is the one worth keeping: **before quoting a ratio, ask what the
DENOMINATOR does on its own.** A 20-of-20 against a field that is 95% constant is not a finding.

**And the carve does not rescue the conclusion either — this is my error, not theirs.** I wrote
14h's `[V]` believing the mechanism carried it. It does not:

 - the TRAP fork sets `SWPST` := high byte of `TRAPN` = `MSWPFAULT` = `0o12` = `0x0A`;
 - the MESSAGE fork sets `SWPST` := `SWFUN`, and **`MSWPFAULT` is itself a member of the `MSW*`
   namespace**, so `SWFUN = 0o12` is a legitimate value there too.

`SWPST=0x0A` is therefore consistent with BOTH forks, and no count of it can separate them. That is
the same defect as the peer's original test — I named it in 14h ("small value in the SWFUN space is
true on BOTH forks and separates neither") and then built a `[V]` on top of it two paragraphs later.

**What the mechanism DOES still say, and it is `[V]`:** the trap fork **strips** `TRAPN` to its low
byte at `145047`; the message fork never touches `TRAPN`. So the only tell in the message is `TRAPN`
CHANGING (`0x0A26` -> `0x0026`), and the 377B log line does not sample that window — a point the
peer made against a grep I had proposed one message after warning them about exactly this shape.

**So from the mailbox fields this is UNDECIDABLE, and that is precisely why the instrument in flight
is a CALL-SITE COUNTER and not another field read.** `DiagPcWatch` on `135367` versus the other
three callers answers directly what no amount of `SWPST` census can. The peer's advice to instrument
the call sites before the routine turns out to have been protecting against this too.

### 14j. Two observations of theirs kept as theirs, `[M]`, uninterpreted

 - The `TRAPN=0x0041` (`0o101`) rows are **lines 6 and 7 — consecutive, early, both `SWPFU=0`**. A
   pair, once, then never again. `TRAPDECODER` rejects anything above `0o53` at `135324` and returns
   at `135331` without reaching `5ACTSWAPPER`, so `0o101` did not arrive through the page-fault arm.
 - **The alternation breaks at the tail.** Lines 8-35 are a strict ping-pong of `0x0B` and `0x0A`
   with no repeats; lines 36-40 are five consecutive `SWPFU=0 SWPST=0x0A`, and their run fails
   immediately after. Nowhere else does either value repeat back to back. They explicitly do NOT
   claim this is the failure — their lane is already root-caused elsewhere — and a tail like that is
   at least as likely a consequence as a cause. Recorded because it is invisible in the census and
   only appears when the rows are read in sequence, which is this project's own standing rule met
   the hard way for the second time in one investigation.

## 15. The call-site table came back UNREADABLE, for a reason the instrument documents `[V]` 2026-08-29

The run completed and reproduced the phenomenon exactly — `place-domain cpu-stat` printed
`> Loading Control Store` / `> Loading Swapper` and STALLED, `swpfu[LNEWSWAP:2]`, no `SWACTIVE`,
no `LSWPAGE`. So it is a valid instance. The table it produced is not usable:

```
----- 5ACTSWAPPER call sites (after PLACE-DOMAIN) -----
  call:MSWSWAIT-tail           @0o134154  hits=0
  call:TRAPDECODER-pagefault   @0o135367  hits=17
  call:SWPD4-fifo-drain        @0o136037  hits=0
  call:SWMC-mon510             @0o141765  hits=0
  5ACTSWAPPER-entry            @0o144762  hits=0
  HANDOVER-taken-SWACTIVE      @0o145011  hits=0
  queued-on-swapwait-fifo      @0o145112  hits=232
```

**Two things make this unreadable, and the first proves the second.**

 - **`0o145112` reported 232 hits and every logged one is `PIL=1`**, with `A` counting up `0o210`,
   `0o211`, `0o212` and `D`/`T`/`X`/`B` constant. That is a loop on level 1, not `5ACTSWAPPER` on
   level 12. `CpuND100.DiagPcWatch` matches the **16-bit PC only** — its own comment says so, and
   `DIAGNOSTICS.md` repeats it — so unrelated code at the same address counts as a hit.
 - **A caller shows 17 hits while the routine it calls shows 0.** Those cannot both be true. The
   table therefore contains at least one wrong number and offers no way to say which, so neither
   `TRAPDECODER=17` nor `5ACTSWAPPER-entry=0` can be quoted — and `entry=0` is exactly the cell that
   would have confirmed "the ND-100 never hands this swapper work". **A number that says what you
   expect, in a table that is provably inconsistent, is the easiest kind to publish by mistake.**

### 15a. The failure worth naming: the log cap was eaten by the noise

`DiagPcWatchLogMax` is 60, and the register detail is what distinguishes a real hit from a
same-address impostor. Of those 60 entries, **59 were the `PIL=1` false positive and 1 was a real
`PIL=12` hit.** So the louder the wrong thing is, the less of the right thing the instrument
records — the log degrades in exact proportion to how badly it is needed.

That is not the same as any of the modes in the taxonomy. #7 is a number that cannot be checked; #8
is one that cannot be relevant; #9 is a switch that does nothing. **This is a bounded log whose
budget is spent by whatever fires most, which is systematically the thing you did not want.** The
counters kept counting; only the evidence that could adjudicate them was crowded out.

### 15b. Fixed at the point of measurement, not after it

`CpuND100.DiagPcWatchPil` — count and log only hits at a given interrupt level, `-1` (any) by
default so nothing else in the tree changes, reset by `DiagPcWatchReset()`. The harness sets it to
**12**, the ND-500 driver level, which is where every routine in `MP-P2-N500.NPL` runs.

Filtering at the point of measurement rather than post-hoc is what saves the log budget: a level-1
impostor never consumes an entry, so the 60 slots hold 60 real samples. Post-filtering would have
left the same one usable sample.

**The table above is therefore withdrawn and NOT recorded as a result.** Re-running with the filter.

### 15c. The addresses were wrong: the listing is 0o200 BELOW the linked image `[V]` 2026-08-29

The PIL filter was the right fix for the wrong problem. While the corrected run was in flight I
checked something I had never checked: **is `0o144762` actually where `5ACTSWAPPER` lives in the
image SINTRAN is running?** It is not.

`MP-P2-N500.NPL` prints the assembler's address counter. The linked L07 image sits **0o200 (128
words) higher.** Pinned against `SYMBOLS\L07\l07-kallsyms.txt`, three symbols from this same module:

| symbol | listing | linked | offset |
|---|---|---|---|
| `SPRIO` | `0o141633` | `0xC41B` | **+0o200** |
| `NNT12` | `0o141706` | `0xC446` | **+0o200** |
| `SWMC` | `0o141753` | `0xC46B` | **+0o200** |

The RELATIVE spacing matches exactly — `NNT12` to `SWMC` is `0o45` in both — so it is a base shift,
not a different build. **Every one of the seven armed addresses was 128 words low**, and the 17 and
232 in section 15's table were unrelated code that happens to live there.

**So the PIL filter would NOT have rescued that run.** It would have removed the `PIL=1` noise and
returned a table of clean, level-12, entirely meaningless numbers — and with the noise gone the
invariant might well have read `[consistent]`. **The fix I was proud of would have made the wrong
answer look right.** The run was stopped mid-flight rather than left to produce it.

Corrected in the harness as a single named constant with the evidence beside it
(`ListingToLinked = 0x80`), applied through one `Watch()` helper so no address can be missed. **The
offset is PER MODULE** — it must be re-pinned against kallsyms for any routine in another segment,
never carried across.

### 15d. What actually caught it, and what did not

Not the invariant, and not the PIL filter. **A question about provenance:** where does this number
come from, and is that the same thing as where the machine runs? The listing addresses had been
copied from the NPL all day — in 14d, in 15, in two messages to the peer — and nobody had asked
whether the assembler's counter is the linked address. It reads as an address, so it was used as one.

This is the memory note's own rule arriving from a new direction: **ask who WROTE this value.** An
NPL listing address is written by the assembler about its own output, not by the linker about the
running image. The two agree only when the module happens to load at 0.

The consolation is that the previous table's self-contradiction was a TRUE alarm about a cause
nobody had guessed. `caller=17, callee=0` was not noise on top of a real signal — it was the whole
signal, saying "these addresses are not what you think". An instrument that reports its own
inconsistency earns its keep even when it cannot say what is wrong.

### 15e. The offset re-pinned properly: NINE symbols, spanning the whole armed range `[V]` 2026-08-29

15c pinned `+0o200` from three symbols clustered around `0o1416xx`, then applied it to addresses
from `0o134154` to `0o145112`. That is extrapolation, and the whole point of 15d was that I had
stopped asking where numbers come from. So it was re-pinned across the full range before spending
another hour of run time:

| symbol | listing | linked | offset |
|---|---|---|---|
| `NNC09` | `0o135476` | `0xBBBE` | +0o200 |
| `NNT08` | `0o136557` | `0xBDEF` | +0o200 |
| `NNA04` | `0o136565` | `0xBDF5` | +0o200 |
| `NNJ10` | `0o136622` | `0xBE12` | +0o200 |
| `SPRIO` | `0o141633` | `0xC41B` | +0o200 |
| `NNT12` | `0o141706` | `0xC446` | +0o200 |
| `SWMC` | `0o141753` | `0xC46B` | +0o200 |
| `NNC24` | `0o144771` | `0xCA79` | +0o200 |
| `NNJ11` | `0o145076` | `0xCABE` | +0o200 |

Nine symbols, exact, no drift across ~7500 words. And the two that matter most **bracket
`5ACTSWAPPER` directly**: `NNC24` (`0o144771`) is the `CNVWADR` marker four words inside the
routine and `NNJ11` (`0o145076`) is the marker just before its FIFO arm, so the entry at
`0o144762`, the handover store at `0o145011` and the FIFO arm at `0o145112` all sit between two
independently confirmed points rather than at the end of an extrapolation.

The patch markers (`*NNxnn=*`) turn out to be the right instrument for this: they are dense, they
are spread through the module, and they are in the symbol table precisely because ND needed to patch
against the linked image. They are the only labels in this file that exist in both worlds.

`ListingToLinked = 0x80` in the harness is therefore verified for this module over the range it is
used on, and nowhere else.

---

## 16. The 5MPM write log had NO caller context, and the "existing switch" was on the other card `[V]` 2026-08-29

### 16a. What the log said, and what it could not say

`sintran-octobus-mpm-writes-octobus-shortbringup.txt` (1,000,000 lines, at the cap) over the
harness window `[0x420000..0x460000)`:

| what | count |
|---|---|
| writes carrying zero | 851,796 |
| writes carrying non-zero data | 148,204 |
| of those, inside the single 4 KB page `0x45A000` | 98,194, across **4096 distinct addresses** |

Every address in that one page is rewritten roughly 24-28 times with real content, and the zero
traffic is a linear byte-ascending zero-fill. Read `[D]`: a 4 KB page rewritten two dozen times with
real content is a **buffer being reused**, not an image being laid down — consistent with SINTRAN
reading the swapper file off disc into an ND-100 buffer while the step that pushes it into ND-500
memory never happens.

**But that is where the log stops.** Every line is `W <addr>=<val>`. There is no writer identity in
it, so it can prove a frame was rewritten and cannot name a single writer. This is taxonomy #7 in
plain form: a number that can only be believed.

### 16b. The plan said "enable the existing switch". The switch was not on this card.

The recorded next step was: *enable the caller-context stamping that already exists (commit
`94c81a4c7`, "let a traced RAM stamp caller context on each access") and re-run — one harness switch,
not new code — **CHECK IT IS WIRED before assuming it works**.*

Checked. It is not wired here, for two independent reasons:

 1. `94c81a4c7` touches `Emulated.HW/Memory/MpmAccessTrace.cs` and
    `Emulated.HW/ND/CPU/NDBUS/**NDBusND500IF**.cs`. `NDBusND500IF` is the **3022** card. Nothing in
    that commit goes near `NDBusOctobus`.
 2. `NDBusOctobus.InitializeSharedMemory` allocates a **plain `RAM`**, not a `TracingRam`:
    ```csharp
    _deviceRam = new RAM(startAddress, size, $"Octobus_SharedRAM_{MemoryName}");
    ```
    So `TracingRam.ContextSource` — the field the commit added — has no instance to be set on in this
    lane at all. The octobus log is fed instead from `ND100Memory`'s write path into
    `NDBusOctobus.RecordMpmWrite`, a completely separate mechanism.

**Neither of those is visible from the commit message**, which describes the capability in
card-neutral language. Had the switch simply been flipped, the run would have produced a log
identical to the one before it and the absence of context would have read as "the writer has no PC",
which is a statement about the plumbing wearing the clothes of a statement about SINTRAN. This is
the same shape as §15's filter problem, one layer down.

### 16c. What was built instead

The context stamp now lives on the octobus's own never-evicted `_writeLog`, which is the log that
actually produced the file above:

 - `NDBusOctobus._writeLog` entries are now `(uint Addr, ushort Val, **uint Ctx**)`, where `Ctx`
   packs `CpuND100.DiagCurrentPC` in the low half and `CpuND100.DiagCurrentPIL` in the high half —
   the same shape `NDBusND500IF.Nd100TraceContext` uses, so the two cards report comparably.
 - **The PIL is carried, not just the PC.** SINTRAN runs its disc driver and its swapper on
   different interrupt levels, so the level separates "the program did this" from "a driver did
   this" even when both land in shared code. That distinction is the whole question here.
 - The harness prints `pc=<octal>B pil=<n>` on every line. **Octal, because every SINTRAN symbol
   table and every `l07-kallsyms.txt` address is octal** — a hex PC guarantees a hand conversion as
   the next step, and §15's listing-vs-linked lesson says radix conversions by hand are where this
   investigation loses days.
 - A **writer histogram** keyed on `(pc, pil)` is printed with the top 15 sites, and — the part that
   matters — a line comparing the histogram's total against the log's total:
   ```
   histogram total=<n> log total=<n> [consistent]   (or [MISMATCH - do not trust])
   ```
   Taxonomy #7 again: one count cannot be checked, a count with a denominator that must agree can.

Both accuracy caveats are carried in the source comments: `DiagCurrentPC`/`DiagCurrentPIL` are plain
statics updated by the ND-100 instruction loop, so a cross-thread read can be torn or one
instruction stale. Good enough to answer *which routine*, and explicitly **not** good enough for
exact instruction attribution.

Build green. The result of the re-run belongs in the next section.

### 16d. Reading the histogram: two traps in the symbol lookup itself `[V]` 2026-08-29

The histogram prints PCs. Turning a PC into a routine name has two failure modes here, and the
first attempt hit both:

 1. **`l07-kallsyms.txt` is HEX; the harness prints OCTAL.** The file's lines look like
    `0xCFCD T ENDOP`. Feeding it octal-parsed addresses returns nothing, or worse, returns a
    plausible neighbour.
 2. **1,420 of the addresses in that table carry MORE THAN ONE symbol** — 9% of its 15,799 lines.
    Two runs of a one-name lookup returned `CEESC` and then `MOTRO` for `0o75676`, and `3FFTP` then
    `3FTYP` for `0o147507`. Both pairs are aliases at a single address and the choice between them
    was arbitrary sort order. A name picked that way is not wrong-looking — it is a real symbol at
    the real address — so nothing about the output signals that a coin was flipped.

The octobus skill already says this in as many words: *"DUMP THE SYMBOLS KEEPING ALIASES —
de-duplicating by value discards the informative one."* The resolver at
`$CLAUDE_JOB_DIR/tmp/pcsym.py` now prints every alias joined with `/`, so
`0o75706` resolves as `CEESC/MOTRO+8` and the ambiguity is visible instead of hidden.

**Worked example, from the wrong-pack run** (teardown-dominated, so useful only as a shakedown of
the instrument — NOT as evidence about bring-up):

```
  pc=0o60716 pil=0  writes=262144  T135W+2 @0o60714
  pc=0o60717 pil=0  writes=262144  T135W+3 @0o60714
  pc=0o147703 pil=1 writes=166430  ST0PS+40 @0o147633
  pc=0o75706 pil=11 writes= 92160  CEESC/MOTRO+8 @0o75676
  ...
  histogram total=1000000 log total=1000000 [consistent]
```

Two things are readable at a glance that no previous version of this log could say:

 - `ST0PS` is **`ST0PSYS`, the shutdown path**, and it plus its neighbours account for well over
   200,000 writes. A histogram dominated by teardown says nothing about bring-up.
 - **The log is AT ITS CAP** (`1000000` is the built-in limit, not a coincidence), and the single
   two-instruction loop `T135W+2/+3` at PIL 0 spends **524,288 of the budget — 52%**. This is
   taxonomy #12 exactly: a bounded evidence budget spent by noise.

**Consequence, stated plainly: the earlier `0x45A000` figures in §16a were counted inside a
TRUNCATED window.** "98,194 non-zero writes across all 4096 addresses, every address rewritten
~24 times" is a count over the first million logged writes, not over the run. The `[D]` reading of
it as a reused buffer may still be right, but it is not yet supported — it has to be re-counted on
a log that did not saturate before it means anything.

---

## 17. The write log was measuring the BOOT, not place-domain — proved by two packs agreeing `[V]` 2026-08-29

### 17a. The measurement

Two runs of the same test, differing ONLY in the mounted pack:

| run | pack | how far it got |
|---|---|---|
| A | `BIGDISK0-L.IMG` (harness default) | bailed at `define-swap-file` — `NO SUCH FILE NAME`, the harness's own wrong-pack guard |
| B | `DOMS-CSFIX.IMG` | reached `place-domain cpu-stat`, **STALL**, then `run`, STALL |

These two runs did completely different things. Their write logs:

```
40,463,048 bytes   both        (identical size)
1,000,000 entries  both        (identical count - and this IS the built-in cap)
first divergence   line 575,206 of 1,000,000
PC histogram       IDENTICAL, all 451 sites, every count matching to the digit
```

**575,205 lines — 57.5% of the entire evidence budget — are byte-for-byte the same in a run that
never reached place-domain and a run that stalled inside it.** The remaining 424,795 lines are
dominated by `ST0PSYS` and its neighbours, i.e. teardown, in *both*.

### 17b. What that means, and what it retracts

The log's budget is consumed by boot traffic common to every run, and then by teardown. **It never
had room to record the phase under investigation.** Anything read out of it about `place-domain` is
a statement about SINTRAN's boot wearing the clothes of a statement about `place-domain`.

**This retracts §16a's numbers as evidence.** "98,194 non-zero writes in page `0x45A000`, all 4096
addresses, every one rewritten ~24 times" is a real count over a prefix that ends before the
interesting work starts. The `[D]` reading — a disc-read buffer being reused — is not supported by
it. It is not refuted either; it is simply unmeasured, which is the more dangerous state because the
number looked like an answer.

This is taxonomy #12 (a bounded evidence budget spent by noise) with the sharpest possible
detector: **two runs that did different things producing the same log**. Worth keeping as a
technique — when a capture is suspected of missing its subject, run it against a fixture that fails
EARLIER and diff. If the logs agree, the capture never reached the subject. That question is
answerable without knowing anything about what the right answer would look like.

### 17c. A second defect the same data exposed: the PC cannot name the writer alone

The top entry in the histogram is `pc=0o147703` = `ST0PS+0o50` = listing `0o147503` in
`MP-P2-N500.NPL`, with **166,430 writes** against it. Reading the source there:

```
147500   IF CPUAVAILABLE BIT 5ALIVE AND A/\5CPUTYPE=SAMSON THEN
147507      T:=5MBBANK; X:=MAILINK; *AAX X5CPU; LDATX
147513      IF A-MPACTIVE=0 THEN
```

`0o147503` is inside a **poll loop executing `LDATX` — a READ**. It heads a WRITE log with six
figures of writes attributed to it. One of these is true and they cannot both be:

 - the writes come from another thread while the ND-100 sits in that loop, and the static
   `DiagCurrentPC` is being sampled cross-thread (the caveat already written into the code); or
 - the writes really are the ND-100's and the PC is stale or torn.

**Do not resolve this by reading code.** A grep for a DMA path into `ND100Memory.WriteMemory32W`
came back empty, which is the exact shape of a search that cannot see what it is looking for. It is
settled by measurement: each entry now also carries the **writing thread's managed id**, 8 bits, as
a discriminator. A thread id proves two writers differ but cannot name either; a PC names a routine
but cannot prove the write came from it. **Only the pair answers the question** — which is precisely
the point commit `94c81a4c7` makes about the 3022's trace.

The address arithmetic above is worth noting as a check that PASSED: `MP-P2-N500.NPL` lists
`ST0PSYS` at `0o147433` and `INSMONCO` at `0o147334`; `l07-kallsyms.txt` has them at `0o147633` and
`0o147534`. **Both are exactly `+0o200`**, independently confirming §15's listing-to-linked offset
for this module on two symbols that bracket the region being read.

### 17d. Changes made

 - `WriteLogCap` raised to **8,000,000** in the harness, past the 575k divergence point.
 - Each log entry carries the writing thread's id (bits 20-27 of the packed context; PIL occupies
   16-19, so no collision).
 - The dump prints an **explicit saturation line**. The existing `histogram total == log total`
   check is a *consistency* check and a saturated log passes it happily — saturation is not a
   mismatch. So it is now stated on its own:
   ```
   *** WRITE LOG SATURATED at its N cap - this is a PREFIX of the run.
       Absence of a write here is NOT absence in the run. ***
   ```
   or, when it did not saturate, a line saying so and giving the count against the cap.

---

## 18. Round 1 on an UNSATURATED log: the lane is LIVELOCKED in an 8-write cycle `[V]` 2026-08-29

Round 1 re-run with the fixed instrument, pack `DOMS-CSFIX.IMG`. Outcome unchanged
(`place-domain=STALL run=STALL`), but the log now covers the run:

```
write log did NOT saturate (5,980,734 of 8,000,000) - it covers the whole run.
1856 distinct (pc,pil) sites   [was 451 at the old cap]
histogram total=5980734 log total=5980734 [consistent]
```

**The real run is six times the old 1M cap.** Everything measured before this was a 17% prefix.

### 18a. Every write came from ONE thread

`thr=15` on all 5,980,734 entries — a single distinct thread id in the whole log. No DMA writer, no
ND-5000 thread, nothing else touching the window through this path. So the PC stamps are
same-thread and can be read. That is measured, and it replaces the empty grep for a DMA path, which
proved nothing.

### 18b. The phase profile, read in order

Profiling the log in 300,000-line windows rather than searching it for an expected pattern:

| windows | shape |
|---|---|
| 0-3 | broad address sweep `0x4207FE`..`0x4586CF`, then `ST0PS`-region traffic |
| 4-7 | **first-addr == last-addr == `0x0045D800`** — 600,000 writes to ONE cell |
| 8-15 | eight windows of IDENTICAL shape, 61,440 writes each at `pc=0o45637`, start addresses stepping down by 8 |
| 16-19 | collapses into the mailbox neighbourhood `0x42810C`..`0x428E46` |

Windows 8-15 alone are 2.4M writes — **40% of the run in one repeating pattern**. That is not a
machine making progress.

### 18c. The livelock, decoded byte by byte

Taking a contiguous slice from the middle of the last phase and reading every write in sequence (not
grepping for a suspected pattern) gives an exactly-repeating **8-write cycle**, at PIL 2, ~82,000
times:

```
  W 0x0042810C=0x0000  pc=23654B pil=2 thr=15
  W 0x0042810D=0x0000  pc=23654B pil=2 thr=15
  W 0x0042890C=0x00FF  pc=23656B pil=2 thr=15
  W 0x0042890D=0x00FF  pc=23656B pil=2 thr=15
  W 0x00428820=0x00FF  pc=133062B pil=2 thr=15
  W 0x00428821=0x00FF  pc=133062B pil=2 thr=15
  W 0x00428822=0x00FF  pc=133062B pil=2 thr=15
  W 0x00428823=0x00FF  pc=133062B pil=2 thr=15
```

Counts: `0x42890C` 82,004 writes of `0xFF`; `0x42810C` 82,005 writes of `0x0000`; the 32-bit cell at
`0x428820` 81,884 writes of `0xFF`. The discovered geometry this run is
`header=0x00428800 extBlock=0x00428900`, and the station's own map puts **`X5PRO` at `ext+0x0C`**
(`X5ACT` at `ext+0x0A`) — so `0x42890C` IS X5PRO.

### 18d. `GETC5PROC` writing is CORRECT — do not "fix" it

`pc=0o23654`/`0o23656` resolve to `GETC5+5`/`+7`. `GETC5PROC` is documented *"Subroutine to get
current executing process number"* — a READ — and it sat at the head of a WRITE log. That looked
like an instrument defect. It is not. `CC-P2-N500.NPL:657`:

```
023630   GETC5PROC: T:=5MBBANK; X=:D:=MAILINK; *AAX X5PRO
023634           *BSET BCM 120 DX; LDATX                      % Fool the cache
023636           *BSET BCM 120 DX; LDATX
023640           X:=D; EXIT
```

Two deliberate cache-defeating read-modify-writes before each `LDATX`, and they touch an address
`0x800` away from the cell being read — which is exactly why the cycle shows `0x42810C` and
`0x42890C` together from a single call. **The routine really does write, on purpose, and our ND-100
records it faithfully.** The same reasoning retires the identical worry about `ST0PSYS` in §17c.

So `GETC5PROC` is not the defect. **The defect is whatever calls it ~82,000 times without
progressing.**

### 18e. A THIRD listing-to-linked offset, and it is not `+0o200`

`GETC5PROC` is at listing `0o023630` in `CC-P2-N500.NPL` and at `0o023647` in `l07-kallsyms.txt`:
**`+0o17`**. `ST0PSYS` and `INSMONCO` in `MP-P2-N500.NPL` are both `+0o200`. Same image, two
modules, two different offsets — which is precisely what §15 and taxonomy #13 say, and it is worth
re-stating because a `+0o200` applied out of habit to a `CC-P2-` address lands 129 words away and
still resolves to a real, plausible routine.

### 18f. What this does and does not settle

**Settled:** the lane is livelocked, the loop is on the ND-100 side at PIL 2, and the instrument is
now trustworthy (single thread, unsaturated, self-consistent, writers named).

**NOT settled:** what the loop is waiting for. `GETC5PROC`'s caller has not been identified — the
write log names the callee, not the caller, and guessing from the call-site list in
`MP-P2-N500.NPL` would be exactly the "adjacency is not dispatch" error.

**And per the standing rule this is a MACRO-ROUND result and must not be reported as a conclusion
on its own.** Round 2 (microword B30 + real 68000 ACCP) is running against the same pack; the diff
between the rounds is the next section.

---

## 19. ROUND 2 — the two-round rule earns itself: TWO separate bugs, and one nearly-false "pass" `[V]` 2026-08-29

First run of this lane with the real components attached. `RETROCORE_ND5000_ROUND` gives four
combinations; all four were run against the same pack (`DOMS-CSFIX.IMG`), same test, one switch:

| round | ND-500 CPU | ACCP | boot | `place-domain` |
|---|---|---|---|---|
| 1 (macro) | functional `CpuND500` | hand-written | OK | **STALL** — the §18 livelock, 82,000 cycles |
| `hw-cpu` | **real B30 microword** | hand-written | OK | **returns an ERROR in 2m04** |
| `hw-accp` | functional `CpuND500` | **real 68000 `octo.bin`** | **NEVER BOOTS** | not reached |
| `hw` (both) | real B30 | real 68000 | **NEVER BOOTS** | not reached |

**The difference between the rounds is the bug list, and there are two independent bugs.**

### 19a. `place-domain=returned` is NOT `place-domain=worked`

The `hw-cpu` run reports `Passed`, `place-domain=returned run=returned`, in 2m04 against round 1's
900-second stall. Read off the OUTCOME line alone that is a spectacular result: the real microcode
does in two minutes what the functional CPU cannot do at all.

It is an error path. The console:

```
ND-5000: place-domain cpu-stat
> Loading Control Store
Error when loading Control Store.
 *** FATAL SYSTEM ERROR ***
ND-500(0) error:      ND-500(0) timeout
N100 STATUS 000000
N500 STATUS 000000
MAR 00000000000    MICRO P: 00000177777
FATAL   * 21B:77B * ND-500(0) Monitor Internal / Fatal internrun
NO WELL DEFINED PROGRAM IN MEMORY
```

It returned FASTER because it FAILED EARLIER. `MICRO P: 0o177777` is all-ones — the microprogram is
not running at all.

**This is the single most dangerous line in this whole investigation and it nearly went out as
progress.** "Returned" means a prompt came back. It does not mean the command did its job, and the
OUTCOME line cannot tell the two apart — `startMessagesSeen=0` was the only hint on that line, and a
zero is easy to read as "not measured". The rule this earns: **a status word from a harness is a
claim about CONTROL FLOW; only the console says what the machine did.** Never report an OUTCOME
field without the transcript behind it.

### 19b. Bug one: the real B30 fails the control-store load — #78 confirmed

`Error when loading Control Store` on the `hw-cpu` round independently confirms task #78, which was
opened on a weaker signal, and now has a full transcript behind it. The functional CPU sails through
the same CS load, which is why this was invisible for as long as the macro round was the only round.

### 19c. Bug two: the real ACCP firmware stops SINTRAN booting at all

> **RETRACTED 2026-08-29, same day, before anyone acted on it.** Ronny: *"i have seen it boot."*
> The heading is left standing so the wrong version is not re-adopted; everything below it is
> UNSUPPORTED as a statement about the ACCP.
>
> **What was actually measured:** with the ACCP attached inside THIS harness, the ND-100 did not
> reach `SINTRAN III RUNNING` inside THIS harness's wait window. Two reasons that is not the same
> claim:
>
>  1. `RunUntil(marker, 300_000)` counts **host wall-clock milliseconds, not emulated cycles** - its
>     own comment says *"host wall-clock, not instructions"*. A 68000 at `instructionsPerClock: 64`
>     slows the whole machine in REAL time, so a 300-second budget can expire with nothing broken.
>     *Did not finish in the window* and *does not work* are different claims - the distinction is
>     stated verbatim a few hundred lines up this same file, about `place-domain` at 300s vs 900s,
>     and I made the error anyway.
>  2. A conclusion about a component drawn from MY ad-hoc wiring of it is a conclusion about the
>     wiring.
>
> **And the machine already exists.** `RetroCore\Nuget\HackerCorpLabs.Emulation.Machines.Accp`
> is a complete ACCP machine with `AccpBootTests` (reset vectors, firmware entry point, RAM walk,
> `Boot_RaisesNoUnexpectedException`), `AccpConsoleTests`, `AccpSelftestStatusTests` - and
> `Nd5000ControlStoreLinkTests`, `Nd5000CsaFailureTraceTests`, `Nd5000FirmwareLoadTests`,
> `Nd5000AttachedMachineTests`, which cover the control-store load, i.e. **19b / task #78**. Run
> that suite before forming any opinion about either. See memory
> `check-existing-machines-before-building`.
>
> **What survives:** the `hw-cpu` vs `hw-accp` vs `hw` split is still a real, reproducible
> difference in this harness, and 19a (a harness OUTCOME field is not a result) stands untouched.
> What does not survive is naming the ACCP as the cause.

`hw-accp` isolates it: functional CPU, real `octo.bin`, and the ND-100 never reaches
`SINTRAN III RUNNING` in five minutes. No IO device `Clock()` ever threw (`faults isolated: 0`) and
the servicer moved nothing (`copy-family log: 0 transfers`), so this is not an exception being
swallowed — the boot simply does not complete.

That it is the ACCP and not the CPU is settled by the pair: `hw-cpu` boots fine, `hw-accp` does not,
and `hw` (both) fails the same way `hw-accp` does. **The ACCP failure DOMINATES** — which means any
future full-`hw` round tells you nothing about the CPU until the ACCP boot failure is fixed. Run
`hw-cpu` for CPU questions until then.

### 19d. Ordering

These are independent and both are upstream of §18's livelock:

 1. **`hw-accp` boot failure** — blocks every real-hardware round that includes the ACCP.
 2. **#78, the B30 CS load** — blocks the real-hardware CPU round from getting past `place-domain`.
 3. **§18's macro livelock** — the round-1 symptom, and the only one of the three that can be worked
    on the functional CPU today.

Note what the standing rule bought here. The macro round says "the swapper is never handed work and
place-domain stalls". Taken alone it points at the swapper hand-over path. The hardware rounds say
the control store never loads and the ACCP cannot even boot the machine — both of which sit *before*
anything the swapper does. **A macro-only conclusion would have sent the next session at the wrong
end of the chain**, which is precisely what Ronny's rule exists to prevent.

Artifacts kept out of the shared temp directory before the next run could overwrite them:
 - round 1: `C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\round1-artifacts\`
 - `hw-cpu`: `C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\round2-hwcpu-artifacts\`

---

## 20. RETRACTION: the "livelock" is SINTRAN's histogram sampler counting time `[V]` 2026-08-30

### 20a. What the caller instrument said

`CpuND100.DiagCurrentL` (commit `a7de69017`) carries the `JPL` return address into the write log, so
the log now names the CALLER, not just the callee. Round 1, unsaturated (5,849,918 of an 8M cap),
caller histogram consistent:

```
5MPM CALLER HISTOGRAM: 3476 distinct L values
  caller L=45626B  writes=1315584
  caller L=51450B  writes= 983290
  caller L=2000B   writes= 892840
  ...
  caller histogram total=5849918 log total=5849918 [consistent]
```

Filtered to the cycle that §18 called a livelock:

| write | callers |
|---|---|
| `0x0042890C` (X5PRO, via `GETC5+5/+7`) | **`L=0o133240` x 65,883**, `L=0o145675` x103, two others x2 |
| `0x00428820` (via `pc=0o133062`) | **`L=0o33076` x 65,883** |

One call site accounts for 65,883 of 65,990 calls.

### 20b. Reading the source at that address

`L` is the RETURN address, so the call is the word before it. `MP-P2-N500.NPL`:

```
133212   IF A=2 THEN                               % Process-logg-one
...
133230      MIN "5HIDATA".S1; P+1; MIN X.S0; 0/\0  % Increment total number of samples counter
133235      CALL GETC5PROC
133236      IF A=5LOGPROC THEN                     % Is process to be logged active?
133241         LACTIVE;
133242      ELSE ... LIDLE / LSWPWAIT / LSWPPING / LCPU / LINMCALL
```

And the other writer, `pc=0o133062`, is the same construct in the neighbouring arm:
`MIN "5HIDATA".S5; P+1; MIN X.S4 % Increment number of samples`.

**This is SINTRAN's ND-500 process-logging / histogram sampler.** It runs on a clock at PIL 2,
increments a sample counter, asks which process the ND-500 is currently executing, and classifies
the answer into one of six buckets. Running tens of thousands of times is what it is FOR.

### 20c. So §18's headline is wrong, and this is the third time this shape has caught me

**RETRACTED: "the lane is LIVELOCKED in an 8-write cycle".** The cycle is real, the counts are real,
the decode is real — and the conclusion drawn from them is not. A periodic sampler ticking 82,000
times means **TIME PASSED**. It says the machine sat there; it says nothing about WHY.

The octobus skill states this exact trap in as many words about a different counter:

> *"`3RMICV` (0x01) is the WATCHDOG heartbeat... A burst of 3RMICV means TIME PASSED, nothing more."*

Same shape, different counter, and the warning was already written down. Add it to the taxonomy as
a variant of #8 (a measurement that cannot be RELEVANT): **the dominant term in a volume-ranked
instrument is very often the thing that runs on a CLOCK, not the thing that is broken.** Ranking by
volume ranks by elapsed time.

**What survives from §18:** the instrument work (unsaturated log, single writing thread, named
writers and now named callers), the phase profile, and — importantly — §18d, that `GETC5PROC`'s
writes are deliberate cache-defeating `*BSET BCM 120 DX` read-modify-writes and must not be
"fixed". What does not survive is the word livelock and any inference built on it.

### 20d. What this does to the search

The write log is now KNOWN to be dominated by clock-driven sampler traffic, so **volume is the wrong
sort key for this question** and no amount of extra write-log resolution will fix that. The stall has
to be found by asking what `place-domain` is BLOCKED ON, not by asking who writes most:

 - the sampler itself classifies the ND-500 into `LACTIVE / LIDLE / LSWPWAIT / LSWPPING / LCPU /
   LINMCALL` — **read which bucket it keeps choosing.** That is SINTRAN's own opinion of what the
   ND-500 is doing, computed 65,883 times and thrown away. It is the single most direct answer
   available and it costs one counter.
 - `5HIDATA` is the histogram area; the counters it increments are already in memory.

That is the next measurement, and it is not a bigger log.

---

## 21. THE MACHINE IS ALREADY DEAD BEFORE THE FIRST COMMAND `[V]` 2026-08-30

Four things sitting in a sixty-line transcript I had opened repeatedly and read past. All four are
present on the **MACRO round** — the one I have been calling "works".

### 21a. `N5TIMOUT` fires BEFORE any command is typed

```
@nd-500
ND-500/5000 MONITOR  Version J04 88. 6.16 / 88. 8.17
ND-5000 timeout:      ACCP was terminated; Microprogram has stopped
ND-5000: define-swap-file          <- the FIRST command comes after this
```

I had been reading that line as part of the banner. It is not. It is `N5TIMOUT` — the `3RMICV`
watchdog going unanswered (`RP-P2-N500.NPL:127642`, `N5STA != ANSWER` -> `RSTARTALL`).

**So SINTRAN already considers the microprogram STOPPED before `define-swap-file`, before
`place-domain`, before anything.** Every measurement in sections 14-20 was taken in that state.

This is not new — memory `nd5000-timeout-convergence` records the same chain and its fix direction
(*"mailbox never walked -> 3RMICV unanswered -> J04 monitor fatal -> timeout; fix = deterministic
X5ACT addr `5FPMAILBOX<<10+X500DF`, not the 0xFFFF->0 sniff"*). What is new is realising it is
happening **here, on every run, before the thing under investigation starts.**

And this run says outright it did not resolve: `CARVED mailbox ... X5ACT_carved=0x0043110A vs
self-disc X5ACT=0x0042890A MISMATCH (delta 0x8800)`.

### 21b. A FILE SYSTEM error fires DURING the control-store load — on both rounds

```
> Loading Control Store
INFO    * 0B:6B * 1998-08-29 20:57:01 * BAK01.37603B
          SINTRAN III File System
          Not used
```

Subsystem `0B`, error `6B`, raised while SINTRAN is reading `CONTROL-STORE:DATA` off the pack.
**Present on the macro round too**, where the CS load then "succeeds". Dismissed as noise every
time I looked at a transcript.

### 21c. The failure registers are zero and all-ones

```
N100 STATUS 000000   N500 STATUS 000000
MAR 00000000000      MICRO P: 00000177777
```

`MAR = 0` means **no message address was ever latched**. Per the bus reference MAR holds the
message's ND-100 WORD address; a zero MAR is precisely why no answer arrives and the command times
out. `MICRO P = 0o177777` is all ones — the microprogram is not running.

### 21d. The FATAL record resolves to the FILE SYSTEM, not to the ND-500

`FATAL * 21B:77B * ... * 147421B.12331B` — both halves resolve to exact or near symbols:

| address | symbol | what it is |
|---|---|---|
| `0o147421` | **`CSTCK` / `5CSTC` + 0** (exact hit) | *"CSTCK: FILE SYSTEM CURRENT STACK POINTER"*, `CC-P2-COMMON.NPL:402` |
| `0o12331` | `9FLER+4` | SINTRAN's error logger — `5P-P2-MON60.NPL:324`, *"SUBROUTINE TO CALL ERROR LOGGER ROUTINE 9FLER"* |

So the fatal path runs through the **file system**, and 21b puts a file-system INFO inside the CS
load. That is a coherent thread, and it is emphatically NOT what the checksum-source theory of §19b
predicted — which is consistent with that fix changing nothing.

### 21e. What this does to sections 14-20

**It reframes them rather than refuting them.** The measurements stand; their SETTING was wrong.
I was asking "why does `place-domain` not complete" on a machine SINTRAN had already declared dead
at the prompt. `> Loading Control Store` and `> Loading Swapper` are being driven at a CPU whose
microprogram the monitor believes is stopped and whose MAR was never latched.

**The methodological failure is RULE #0b, exactly as written:** *decode the actual bytes in order
and read what is there; a search can only confirm or deny a thing you already imagined.* I grepped
these transcripts for `Loading`, for `Error`, for `OUTCOME` — never once read the sixty lines
top to bottom. Four findings were sitting in the part between my greps.

### 21f. The order to work them

 1. **The pre-command `N5TIMOUT` / `MAR = 0`.** Nothing downstream can be trusted while the monitor
    thinks the microprogram is stopped. The X5ACT carved-vs-discovered MISMATCH printed by the same
    run is the obvious first suspect and has a recorded fix direction.
 2. **The `0B:6B` file-system INFO during the CS load**, which shares a subsystem with the fatal
    record's `CSTCK`.
 3. Only then the CS-load difference between rounds (#78) and the `place-domain` stall (#79).

---

## 22. §21f's first suspect is DEAD: the X5ACT "MISMATCH" is the diagnostic, not the machine `[V]` 2026-08-30

§21f put the pre-command `N5TIMOUT` first, and named the run's own
`X5ACT_carved=0x0043110A vs self-disc X5ACT=0x0042890A MISMATCH (delta 0x8800)` as the obvious
suspect. **That line is wrong, and it is ours.**

### 22a. The station does not sniff — it reads the control store

`OctobusND5000Station.ConfigureMailboxFromControlStore` says so in its own header, and it is the
"ACTUAL-CORRECT-WAY ... no resident read, no MMU translation, no 0xFFFF->0 sniff":

```
START_MESS = control-store word 0o26, LARG        (SINTRAN patches it with the window offset)
SAMSON_CPU = control-store word 0o25, LARG
header   = mpmStart + START_MESS      = 0x420000 + 0x8800 = 0x428800
extblock = header + SAMSON_CPU*256    = 0x428900
X5ACT    = extblock + 0x0A            = 0x42890A
```

So the value labelled "self-disc" in the dump is **control-store-derived and authoritative**. The
label is misleading too — `_mailboxSelfDiscovered = true` is set only to SUPPRESS the sniff.

### 22b. The harness's "carved" value counts the window offset twice

```
5FPMAILBOX = 0x0851 (page 2129)  ->  fpmail << 11 = 2129 * 2048 = 0x428800
```

`5FPMAILBOX` is a PAGE number, so `fpmail<<11` is already an **absolute physical byte address** —
and it is the SAME `0x428800` the control store gives. The two agree exactly.

Then the diagnostic added `X500DF<<1` = `0x4400*2` = **`0x8800`** — which **IS** `START_MESS`. The
window offset goes in twice, and `0x428800 + 0x8800 + 0x100 + 0x0A = 0x43110A` is precisely the
"carved" number.

**The delta was always exactly `X500DF<<1`.** A delta that is a CONSTANT, equal to a term in the
formula, is the tell that the disagreement is arithmetic rather than machine state — and it was
printed on every run for weeks.

### 22c. Why this matters beyond one line

I promoted this to the top of §21f's list *because the instrument shouted MISMATCH*. A wrong
diagnostic does not merely fail to help; it manufactures priorities. Taxonomy entry, adjacent to
#9 (a switch that reports itself applied and does nothing): **a comparison instrument can disagree
with reality because the COMPARISON is wrong, and it looks exactly like the subject being broken.**
The check that catches it costs nothing — *is the delta constant, and is it equal to one of the
terms?*

Fixed: the `X500DF` term removed, with the reasoning in the code, and the label changed from
"self-disc" to "CS-derived" so the authoritative value stops reading like a guess.

### 22d. What is left of §21f

 1. ~~the X5ACT carved-vs-discovered mismatch~~ — **dead, it was arithmetic.**
 2. The pre-command `N5TIMOUT` itself is STILL REAL and still first: the monitor declares the
    microprogram stopped before any command, on both rounds, and `MAR = 0` says no message address
    was ever latched. The mailbox ADDRESS is now known to be right, so the question sharpens to
    **why nothing answers at an address that is correct** — a different and better question than
    "is the address wrong".
 3. The `0B:6B` file-system INFO during the CS load, sharing a subsystem with the fatal record's
    `CSTCK`.

---

## 23. B1 ROOT-CAUSED: the pre-command `N5TIMOUT` is the DESIGNED "control store not loaded" gate `[V]` 2026-08-30

§21a promoted this to most-upstream-bug and PLAN.md leads with it. **Root-caused, and it is expected
behaviour** — recorded here rather than dismissed, because the standing rule is that no error is
closed as "expected" without a root cause written down.

### 23a. The ordering settles it

From the macro-round capture, with line numbers:

```
29:  @nd-500
31:  ND-500/5000 MONITOR  Version J04 88. 6.16 / 88. 8.17
32:  ND-5000 timeout:      ACCP was terminated; Microprogram has stopped
34:  ND-5000: define-swap-file
37:  ND-5000: place-domain cpu-stat
39:  > Loading Control Store          <- the CS load happens HERE, seven lines LATER
```

**At line 32 no control store has been loaded yet.** Neither ND generation has microcode ROM — the
store is RAM and is empty until `LOAD-CONTROL-STORE`. So there is genuinely no microprogram running,
nothing can answer the probe, and *"Microprogram has stopped"* is a TRUE statement about the machine
at that instant.

And it is the DESIGNED trigger, not a fault report. The bus reference: `RSTA5` bit 9 `5CLOST`
(*"micro clock stopped = CS NOT loaded"*) → `ECSLOAD 2032B` → the monitor prints
*"Loading Control Store"* and auto-loads. **The monitor noticing a stopped microprogram is what
CAUSES the control-store load.** Line 32 and line 39 are cause and effect.

### 23b. The claim that the watchdog goes unanswered is REFUTED by the same run

§21a's mechanism was "`3RMICV` going unanswered". Measured on that very run:

```
----- servicer MICFU trace [MicroVersion=0x2E9A CpuParameter=0x03E1] -----
MICFU=0x01 3RMICV(1) read-micro-version @0x00428E30
MICFU=0x01 3RMICV(1) read-micro-version @0x0042C130      (many more)
MICFU=0x0A CACHE(12B)  cache-clear @0x00428E30  nrbyt=2048
MICFU=0x19 PHYSWR(31B) physical-write @0x00428E30  addrA=0x000000BC nrbyt=4
----- servicer walk: polls=124072 active(x5act==0)=105 -----
----- discovered mailbox: header=0x00428800 extBlock=0x00428900 -----
```

**`3RMICV` is answered, repeatedly**, and the version `0x2E9A` goes back. The mailbox is walked
124,072 times with 105 doorbell activations, and `CACHE` and `PHYSWR` are serviced. So the mailbox
path WORKS after the CS load. The timeout is a one-shot at entry, in the window where the store is
legitimately empty.

### 23c. So §21a's conclusion was too strong

**RETRACTED:** *"SINTRAN already considers the microprogram STOPPED before any command... every
measurement in sections 14-20 was taken in that state."* The first half is true and unremarkable;
the second half is false. The machine is not in that state for the measurements — the CS gets
loaded during `place-domain` and the mailbox answers from then on.

This is the mirror image of §22 and worth naming as a pair: **§22 was an instrument shouting
MISMATCH when the arithmetic was wrong; §23 is a machine printing a real error message that is
correct and expected.** Both produced a top-priority item. The discipline that catches both is the
same — before promoting an error, ask *what would the machine legitimately print here?* — and it is
cheaper than either investigation.

`MAR = 0` (B3) and `N500 STATUS 000000` (B4) are read at the SAME moment, from the same fatal
report, and are very likely the same story. Check their timestamp before treating them as separate
bugs.

### 23d. Revised order

B1 is closed with a root cause. What is genuinely open and upstream is now:

 1. **B9** — `start-swapper` has never been validated (running now; the test used all week
    deliberately skipped it).
 2. **B7** — the macro round loads the control store and reaches `> Loading Swapper`, then never
    reaches `> Allocating memory`.
 3. **B6** — `hw-cpu` fails the CS load where macro succeeds.
 4. **B2** — the `0B:6B` file-system INFO during the CS load, sharing a subsystem with B8's `CSTCK`.

---

## 24. B7 IS THE VERIFY-BLOCK SEAM, and the 3WREG theory is refuted `[V]` 2026-08-30

`nd500uc-47` (classic 3022 lane) proposed that our `> Loading Swapper` -> no `> Allocating memory`
stop is the servicer's deliberate `3WREG` refusal. Checked in one field, and it is not.

### 24a. The gate is real, and unreachable

`Nd500MicrocodeServicer`, `case N5MicroFunction.RegisterWrite` (21B = 3WREG):

```csharp
// ND500-only: MSG_ILLEG in both 5800 listings (B30 @015245, A30 @014261)
// -> the ND-5000 answers 5ERANSWER like the hardware.
if (Generation != Nd500Generation.ND500) { understood = false; break; }
```

and `OctobusND5000Station.cs:665` does construct the servicer with `Nd500Generation.ND5000`, so the
refusal WOULD fire. **But `3WREG` never arrives.** The complete MICFU set for a whole macro run is
three functions and no more:

```
MICFU=0x01 3RMICV(1)      MICFU=0x0A CACHE(12B)      MICFU=0x19 PHYSWR(31B)
```

No 21B, no 23B (`3START`), and no 13B/14B (`RESIRD`/`RESIWR`) — the documented ND-5000
swapper-delivery path. **The refusal is not the blocker; the ABSENCE of the message is.** Note for
whoever touches that gate: it is currently unreachable on the 5000 generation for this reason, so a
test of it would be measuring nothing.

### 24b. What the lane actually does — and it reproduces a question already on file

Every `PHYSWR` in the run, deduplicated, in address order:

```
addrA=0x00000096 addrB=0x0000CC00 nrbyt=4      addrA=0x000000B2 ...
addrA=0x0000009A ...                            addrA=0x000000B6 ...
addrA=0x0000009E ...                            addrA=0x000000BC ...
addrA=0x000000A2 ...                            addrA=0x000000C0 ...
addrA=0x000000A6 ...                            addrA=0x000000C4 ...
addrA=0x000000AA ...   addrA=0x000000AE ...     (28 PHYSWR total, 12 distinct targets)
```

That is, verbatim, the block recorded in `nd5000-octobus-research` /
`OCTOBUS-MAILBOX-MICFU-SEQUENCE-REFERENCE-2026-07-28.md`:

> *"start-swapper performs a write-then-read-back VERIFY of 13 words over ND-500 physical
> `0x96..0xC4`, which COMPLETES AND PASSES - and then SINTRAN issues nothing but watchdogs and never
> sends `3START`, so the CPU stays `PC=0 stopMode=WAIT`. Identifying that block is the open
> question."*

**So B7 is not a new bug. It is that open question, reproduced exactly on the current pack with the
current code.** The verify passes; the next message never comes.

### 24c. The one measurement that would settle it

The classic lane REACHES `> Allocating memory`. So the divergence is a single message: whatever
that lane sends immediately after its equivalent verify block, which ours does not. Asked
`nd500uc-47` for the complete unfiltered message sequence between `> Loading Swapper` and
`> Allocating memory` — MICFU, N5STA, and `addrA`/`addrB`/`nrbyt` for the copy family — plus the
raw bytes written to `0x96..0xC4` so content can be compared, not just addresses.

That is a byte dump in issue order, deliberately not a grep: a grep can only confirm a message one
of us already thought of, and the whole point is that our lane is missing one we have not named.

---

## 21. B1 thread: `5MBBANK` and `5FPMAILBOX` are INCONSISTENT in the live machine `[V]` 2026-08-30

Measured, not inferred. `5MBBANK` is the bank register used for **every** mailbox access in SINTRAN
(`T:=5MBBANK; *AAX X5PRO; LDATX` and ~40 more sites in `5P-P2-MON60.NPL`).

### 21a. What SINTRAN's own arithmetic says

`RP-P2-N500.NPL:737`, inside `XMSINIT`:

```
131133   5FPMAILBOX=:D:=0; AD SH 12; A=:5MBBANK    % MEMORY BANK FOR MESSAGES
```

`D := 5FPMAILBOX`, `A := 0`, shift the AD pair left 12, keep the high half — i.e.
**`5MBBANK = 5FPMAILBOX >> 4`**.

### 21b. What the live machine holds

| cell | address | measured | source |
|---|---|---|---|
| `5MBBANK` | `0o4654` | **`0x0021` = 33** | harness resident probe, both rounds |
| `5FPMAILBOX` | `0o111102` | **2129** (`0x0851`) | harness carved-mailbox probe, both rounds |

`2129 >> 4 = 133`, not 33. Inverting, `33 << 4 = 528`, so `5MBBANK` corresponds to a
`5FPMAILBOX` of about **528-543** — not the 2129 that is in the cell.

**The harness is reading the right cell:** `l07-kallsyms.txt` puts `5MBBA` at `0o4654`, which is
exactly the address probed. So this is not an addressing mistake on our side, and the harness has
been printing `MISMATCH` on this line in every run for as long as the probe has existed.

### 21c. Why this is on B1's thread

`5FPMAILBOX` has exactly two writers, both in the MON60 initialisation path:

```
5P-P2-MON60.NPL:501   A-+5NPAGES=:5NPAGES; 0=:5FPMAILBOX     (zeroes it)
5P-P2-MON60.NPL:640   A=:5FPMAILBOX                           (after CALL 5GBUFF allocates)
```

and `027102 CALL 5GBUFF / 027104 A=:5FPMAILBOX` is the mailbox-page allocation. So the two cells can
only disagree if **`5MBBANK` was derived before `5FPMAILBOX` reached its final value**, or if one of
them is written by something else.

If `5MBBANK` is wrong, every mailbox access goes to the wrong bank, `3RMICV` is never answered, and
`N5TIMOUT` fires — which is exactly B1's symptom, and B1 fires **before any command is typed**.

**This is a hypothesis with a measured foundation, and it is NOT yet the root cause.** Do not act on
it until the next measurement is done.

### 21d. The next measurement, and it is not a guess

`XMSINIT` has **no `CALL` site** — grep finds none; it is dispatched through a table
(`DP-P2-VARIABLES.NPL:97` lists it in `NRPIT,XMSINIT,`). So the call order **cannot be read out of
the source** and must be measured.

Watch the two writes in order, with PCs, using the existing `CpuND100.DiagPcWatchList` /
`DiagPcWatchPil` instrument (the same one that produced the `5ACTSWAPPER` call-site table):

 - **`A=:5MBBANK`** — listing `131133` in `RP-P2-N500`; **`RP-P2-N500`'s offset is `+0o136`**
   (`XMSINIT` listing `131127` vs `l07-kallsyms` `0o131265`), so the linked address is **`0o131271`**.
 - **`A=:5FPMAILBOX`** — listing `027104` in `5P-P2-MON60`; that module's offset is **NOT yet
   pinned**, so pin it first from a bracketing pair before arming anything.

**THREE distinct module offsets are now confirmed in this one image** — `MP-P2-N500` `+0o200`,
`CC-P2-N500` `+0o17`, `RP-P2-N500` `+0o136`. Applying any of them to another module lands on a real,
plausible, wrong routine. Pin per module, every time.

Record the ORDER and the VALUES: if `5MBBANK` is written once, early, from a small `5FPMAILBOX`, and
`5FPMAILBOX` is written again later with nobody recomputing `5MBBANK`, that is the bug. If both are
written together and still disagree, the arithmetic model above is wrong and it is the model that
needs fixing first.

---

## 25. THE OCTOBUS LANE NEVER DELIVERS THE SWAPPER IMAGE AT ALL `[V]` 2026-08-30

`nd500uc-47` dumped its complete PLACE-DOMAIN message sequence in issue order, unfiltered. It
inverts §24c's question and answers something better.

### 25a. Classic lane, complete MICFU run-sequence, `> Loading Control Store` -> `> Allocating memory`

```
 14x  0x0B  ResidentRead        (13B)
 44x  0x0C  ResidentWrite       (14B)
  1x  0x0A  CacheControl        (12B)
  1x  0x11  RegisterWrite       (21B = 3WREG)
  3x  0x0F  DepositRegister     (17B)
  2x  0x13  StartProcess        (23B = 3START)
  1x  0x14  MonitorCallContinue (24B)
  1x  0x13  StartProcess
  6x  0x14  MonitorCallContinue
  1x  0x11  RegisterWrite
  1x  0x19  PhysicalWrite       (31B)     <- ONCE, and AFTER 3START
  1x  0x14  MonitorCallContinue
```

### 25b. Ours, same phase, complete

```
  0x01  3RMICV      (watchdog)
  0x0A  CACHE  12B  (once)
  0x19  PHYSWR 31B  x28, 12 distinct targets, nrbyt=4, ND-500 phys 0x96..0xC4
```

**No 13B. No 14B. No 21B. No 23B.**

### 25c. What that means, and it is not what §24 guessed

§24c asked "what message follows the verify block". Wrong question. **The classic lane delivers the
swapper image with 58 ResidentRead/ResidentWrite messages (13B/14B) and uses `PHYSWR` exactly ONCE,
AFTER `3START`.** Our lane uses `PHYSWR` for 4-byte pokes and never issues a single 13B/14B.

So our lane **never delivers the swapper image at all.** The 12 `PHYSWR` at `0x96..0xC4` are a
verify block, not a load — 4 bytes each, 48 bytes total, against a swapper `PSEG` of 38,161 bytes
and `DSEG` of 218,117 bytes on the pack.

**And this is exactly the split this project already wrote down**, in `CLAUDE.md`, quoting the deep
dive verbatim:

> *"The swapper delivery uses 13B/14B (measured live: 8x13B, **44x14B**); PLACE+RUN uses 30B/31B."*

The peer measured **44x 14B** — the same number, independently, on a different lane today. The
document is right, our lane is on the wrong side of the split, and the fact was on file the whole
time.

### 25d. The corroboration that makes the classic dump trustworthy

The `ResidentWrite` bodies are consecutive and differ in EXACTLY one halfword:

```
#1875057  |08: A000 0021 2400 0800 ...
#1875075  |08: A800 0021 2400 0800 ...
```

`A000 -> A800` = **+0x800 = one 2048-byte page**. That is an image being walked page by page, which
is what a swapper load looks like and what 28 fixed 4-byte pokes do not.

*(Deliberately NOT inheriting the peer's field reading: they declined to say which halfword is
source and which is destination because the catalog's "32-bit address at offsets 7-10B" is
unverified against these bytes. Correct call - that decode is ours to do.)*

### 25e. The question, restated correctly

**Not** "why does the swapper not start" and **not** "what message comes after the verify". It is:

> **Why does SINTRAN choose the `PHYSWR` path instead of `RESIRD`/`RESIWR` for the swapper image on
> the octobus lane?**

The peer's instinct is right that this is answerable in SINTRAN's own code rather than ours. First
carve results:

 - the delivery MICFU is NOT set in the resident modules — every `*MICFU@3 STATX` in
   `MP-P2-N500.NPL` / `CC-P2-N500.NPL` / `RP-P2-N500.NPL` writes `3MONCO`, `3START`, `3RMED`,
   `3RMICV` or `3WMONCO`. None writes 13B/14B or 31B.
 - `WPHSG` is **MON 60 subfunction 110B** (`i_wphsg`: bytecount > 4000B -> `EBIGBUF`, `frusmove`
   from the user buffer, then the common path with function `0110`) — a USER-invoked
   write-into-physical-segment, not a swapper loader.
 - so the choice lives in **S3SM5**, which IS disassembled
   (`030-S3SM5.dis`, 1.53 MB, + the routine map + `FUNCS-BODIES/`). `FUNCS` entries confirmed at
   `142124 -> 166537` (RPHSG) and `142141 -> 167550` (WPHSG).

### 25f. An instrument warning from the peer, worth keeping

`[PSTWATCH]` and `[L1WATCH]` share ONE `MpmTrace` ring, and `ArmL1TableWatchIfRequested`
(`CpuND500.MMU.cs` ~2565) calls `tracing.Trace.Clear()` when it takes over. **Any "no writes were
seen" conclusion from PSTWATCH in a run where L1WATCH also armed is void** — the ring was emptied
underneath it. They nearly published "SINTRAN never fills PST entry 14" off that silence.

Taxonomy: this is #9's cousin — not a switch that does nothing, but **two instruments sharing one
buffer, where arming the second silently destroys the first's evidence**. The tell is a shared ring
with more than one arming path.

---

## 26. `5MBBANK` is CORRECT — the probe's shift was wrong (third diagnostic artefact today) `[V]` 2026-08-30

A `5MBBANK` mismatch was raised as a candidate root cause for the pre-command `N5TIMOUT`: if the
mailbox bank register is wrong, every mailbox access lands in the wrong bank, `3RMICV` is never
answered, and the watchdog fires. Good reasoning from a measured foundation. **The measurement is
the probe's, and the probe is wrong.**

```
measured:  5MBBANK @0o4654 = 33        5FPMAILBOX @0o111102 = 2129
probe:     2129 >> 4 = 133             -> "MISMATCH"
```

**33 is exactly right.** A bank is `0x20000` = 128 KB = 64 pages of 2048 bytes:

```
2129 >> 6 = 33          == the measured value, exactly
2129 * 2048 = 0x428800  == the mailbox header the station discovers from the control store
```

The probe modelled `>>4`; the machine uses `>>6`.

**Behaviour was the check that should have settled it first, and it was already in hand:** the
mailbox WORKS — `3RMICV` answered repeatedly, `polls=124072`, `active(x5act==0)=105`, header found
at `0x428800`. A wrong bank register would break precisely that. **A diagnostic that contradicts
measured behaviour should be suspected before the machine is.**

Fixed, with the reasoning in the code. The NPL line being modelled is
`RP-P2-N500.NPL:737` (`XMSINIT`): `5FPMAILBOX=:D:=0; AD SH 12; A=:5MBBANK` — it is the AD-pair
shift decode that was misread; the corrected constant is pinned to the measured machine.

### 26a. Three in one night, same shape

| § | instrument | what it claimed | truth |
|---|---|---|---|
| 22 | X5ACT carved-vs-derived | `MISMATCH (delta 0x8800)` | the delta WAS `X500DF<<1`, counted twice |
| 20 | 5MPM write-volume ranking | "the lane is LIVELOCKED" | the top writer is a clock-driven sampler |
| 26 | `5MBBANK` recompute | `MISMATCH (33 vs 133)` | wrong shift; 33 is correct |

Every one produced a top-priority investigation. Two shared a tell that costs nothing to check:
**the disagreement was a CONSTANT** (`0x8800`; a fixed `>>4`-vs-`>>6` factor). The third had a
different but equally cheap tell: **it contradicted behaviour the same run had already
demonstrated.**

The rule earned: **before promoting an instrument's disagreement to a bug, ask (a) is the delta
constant, and (b) does any other measurement in the same run contradict it?** Both questions are
free. All three of tonight's artefacts fail one of them.

### 21e. THE 500-vs-5000 GATE: `MUDOM`, and why the 3022 session cannot answer this `[V]` 2026-08-30

Ronny, 2026-08-30: *"but maybe there is a difference in 500 and 5000 in this - so be aware, and test
and validate."* He is right, and it is in this exact routine.

`XMSINIT` initialises the octobus-specific mailbox fields **only inside a generation gate**
(`RP-P2-N500.NPL:757`):

```
131220   IF MSDFCPU.MIFLAG BIT MUDOM THEN
131225      T:=5MBBANK; X:=MSMLINK; *AAX X5STA; STATX      % STATION NUMBER
131245      ...                     *AAX X5ACC; STDTX      % ACCP BUFFERS
131255      ...                     *AAX X5OCT-X5ACC; STDTX % OCTOBUS BUFFERS
131265      ...                     *AAX X5HWB-X5OCT; STDTX % HW BUFFERS
131267   FI
```

**`MUDOM` has exactly ONE writer in the entire source**, `PH-P2-OPPSTART.NPL:3933`:

```
063151   T:=100406; *IOXT; TRA IIC
063154   IF A=0 THEN                      % Octobus present? - (assumes Samson)
063155      DO *IOXT WHILE A NBIT 3 OD    % wait for data ready
063161      ASTATION\/COMD=:5STATION
063170      T:=100405; A\/CMMACLE; *IOXT  % masterclear Samson system
063173      A:=X\/CMACONT; *IOXT          % continue accp
063176      MIFLAG BONE MUDOM=:MIFLAG     <-- the only assignment of MUDOM anywhere
063201      CPUAVAILABLE/\140000\/SAMSON
063205   ELSE  A:=0  FI
```

So `MUDOM` is set **only when the IOX `100406` octobus presence probe returns `A=0`** and bit 3
(data ready) then comes up.

**If `MUDOM` is not set, `X5STA` / `X5ACC` / `X5OCT` / `X5HWB` are never initialised** — the octobus
mailbox extension is unbuilt, messaging cannot work, `3RMICV` is never answered, and `N5TIMOUT`
fires before any command is typed. **That is B1's exact symptom.**

**And this is the generation difference in the flesh:** `MUDOM` is meaningless on the classic 3022
lane, so the ND-500 session can have `.DOM` files running with this defect fully present on ours.
Their `5MBBANK`/`5FPMAILBOX` values would have told us nothing, and adopting them would have been
the `nd500-classic-vs-nd5000-page-table-split` mistake again — sharing a constant across two
generations that divide the work differently.

**NOT YET MEASURED, and this is the next step:** whether `MIFLAG BIT MUDOM` is actually set on our
live machine, and what the IOX `100406` probe returns. The harness already reports
`5MSINIT@0o111100=0x000F ... OK: 4 SAMSON CPU(s), 1 alive`, so SAMSON detection itself works — but
`CPUAVAILABLE`/`SAMSON` is set on the line AFTER `MUDOM` in the same block, so SAMSON being detected
does not prove `MUDOM` was set. **Probe `MIFLAG` directly. Do not infer it from the SAMSON count.**

There is also a spin to be aware of at `063155`: `DO *IOXT WHILE A NBIT 3 OD` waits for bit 3 with
no visible timeout. If our card never raises bit 3 this hangs inside the presence probe rather than
falling through.

---

## 27. `MUDOM` is a real gate, but it is NOT unset here — behaviour refutes it `[V]` 2026-08-30

A candidate root cause for B1 was raised: `XMSINIT` builds the octobus mailbox fields
(`X5STA`/`X5ACC`/`X5OCT`/`X5HWB`) only inside `IF MSDFCPU.MIFLAG BIT MUDOM`, and `MUDOM` has exactly
one writer in the whole source (`PH-P2-OPPSTART.NPL:3933`), set only when the IOX `100406` octobus
presence probe answers `A=0` with bit 3 up. If `MUDOM` were clear the mailbox extension would never
be built, `3RMICV` would go unanswered, and the watchdog would fire before any command.

**The gate is real and worth having on file. Its PREDICTION is contradicted by this run.**

If `MUDOM` were clear, SINTRAN could not post mailbox messages at all. Measured, same run:

```
MICFU=0x01 3RMICV(1) read-micro-version @0x00428E30
MICFU=0x01 3RMICV(1) read-micro-version @0x0042C130     (repeatedly)
MICFU=0x0A CACHE(12B) ... MICFU=0x19 PHYSWR(31B) ...
servicer walk: polls=124072  active(x5act==0)=105
discovered mailbox: header=0x00428800 extBlock=0x00428900
5MSINIT@0o111100=0x000F  5CHALIVE=True 5ALBUF=True -> 4 SAMSON CPU(s), 1 alive
                                                     -> ND-500 subsystem initialised
```

**SINTRAN is posting.** The watchdog is `X:=WATCHDOG; T:=5MBBANK; 3RMICV; *MICFU@3 STATX`
(`RP-P2-N500.NPL:127470`) — it dereferences `5MBBANK` and a `WATCHDOG` buffer pointer that `XMSINIT`
builds. Those messages arrive at sane in-window addresses with a valid MICFU, and 105 doorbell
activations follow. **An unbuilt mailbox extension cannot produce that.**

One caution on the evidence, because it matters which half proves what: our STATION derives the
mailbox from the control store (§22), so the station FINDING the header proves nothing about
SINTRAN's side. What proves SINTRAN's side is SINTRAN POSTING there — which it does.

### 27a. And B1 is already root-caused anyway

§23 closed B1 without needing `MUDOM`: the timeout is at capture line 32, `> Loading Control Store`
at line 39, so at line 32 the store is legitimately empty and *"Microprogram has stopped"* is TRUE.
It is the designed `5CLOST` -> `ECSLOAD` gate that TRIGGERS the auto-load. Two independent lines of
evidence now agree that B1 is not a defect.

### 27b. The pattern, for the fourth time tonight

`5MBBANK` (§26) and `MUDOM` (here) are the same shape: a well-reasoned mechanism, derived from real
source, that predicts a failure the run does not exhibit. Both were caught by the same free question
— **does any measurement in the same run contradict this?** — and in both cases the contradicting
measurement was already sitting in the log.

**Still worth doing, and cheap:** probe `MIFLAG BIT MUDOM` directly rather than inferring it, since
the inference here runs the other way (behaviour implies it is set). And note the flagged hazard
independently of all this: `063155` is `DO *IOXT WHILE A NBIT 3 OD`, a spin on bit 3 with no visible
timeout — if a card never raises bit 3 that hangs INSIDE the presence probe. Our machine plainly
gets past it, so it is a robustness note, not this bug.

---

## 28. CORRECTION to §25, and the real discriminator is `LSWPAGE` `[V]` 2026-08-30

### 28a. §25 was half wrong: `3START` IS sent

§25 said our lane sends "no 21B, no 23B". **The 23B half is wrong.** It was read off the MICFU
*trace listing*, which is capped. The harness state line carries the COMPLETE histogram:

```
micfu[1B:87  12B:1  23B:1  24B:1  31B:13]
startSeen=1  startMicfu=23B  startTaken=True
swpfu[LNEWSWAP:2]  ansMON=377B  ansSWPFU=1B
PC=0x08008255  stopMode=WAIT  restarts=1/1
```

`3START` (23B) is sent AND taken, and `3MONCO` (24B) arrives. **What is genuinely absent is 13B and
14B — zero of each — and 21B.** The "no swapper image delivery" conclusion stands; the "the swapper
never starts" half does not.

**How the error happened, because the shape recurs:** a capped listing and an uncapped counter
disagreed, and I read the listing. Same family as §17 (a capped write log read as a whole run).
**When a trace and a counter disagree, the counter is usually right and the trace is usually
truncated** — check the cap before believing an absence in a listing.

### 28b. The discriminator: `LSWPAGE`

`nd500uc-47`'s SWPFU histogram against ours, same phase:

| | SWACTIVE/ESWPFATAL | LNEWSWAP | **LSWPAGE** |
|---|---|---|---|
| classic (reaches `> Allocating memory`) | 80 | 118 | **84** |
| ours | — | 2 | **0** |

**They drive `LSWPAGE` 84 times. We drive it zero.** `LSWPAGE` (SWPFU=2) is the page-in request —
the actual swapping work.

### 28c. This corrects a note in our own plan

`PLAN.md` recorded: *"`SWPFU=4` (`LALLOPAGE`) is not a discriminator — the working lane never asks
for it either."* The peer's histogram CONFIRMS that (neither lane uses 4). But the whole SWPFU
question was framed around `LALLOPAGE`, and `LSWPAGE=2` — where the lanes actually diverge — was
never looked at. **A correct fact about the wrong field**, which is a quieter failure than a wrong
fact and survived longer for exactly that reason.

### 28d. The picture, now coherent

Our swapper **does** start (3START taken), asks `LNEWSWAP`, is told there is nothing to do, and
parks at `PC=0x08008255 stopMode=WAIT`. That is the DESIGNED idle, not a fault — the harness's own
MON-restart note says so. Nothing ever queues `LSWPAGE` work for it, and nothing ever delivers the
image (no 13B/14B). **Those are plausibly ONE fault, not two:** no page-in requests and no image
delivery are the same absence seen from two ends.

So the question is not "why does the swapper not run" — it runs, correctly, and idles. It is:

> **Why does SINTRAN queue no `LSWPAGE` work and send no 13B/14B on the octobus lane?**

Per §25e the delivery choice lives in S3SM5, which is disassembled. If that turns out to be
generation-dependent in SINTRAN's own code, it explains BOTH lanes at once.

---

## 29. The caller histogram survives the check that killed the peer's PST trace `[V]` 2026-08-30

`nd500uc-47` retracted "SINTRAN never writes PST entry 14": all 52 writes carried NO `pc=`, and in
that tracer a missing pc is a deliberate signal — `NDBusND500IF.Nd100TraceContext` opens with
`if (CpuND500.Nd500PortBDepth > 0) return 0u;` so an ND-500 Port B access cannot be misread as an
ND-100 instruction address. 52 of 52 unstamped means those writes were ND-500 side, not SINTRAN's.
They also flagged that `Nd500PortBDepth` is a **shared static across two threads**, so an ND-100
write landing while the ND-500 thread is inside Port B would be misattributed anyway.

**That caveat applies to our instrument on its face** — `NDBusOctobus.Nd100WriteContext()` has NO
`Nd500PortBDepth` guard. Checked rather than assumed, and it does not need one:

 1. **Structural.** `RecordMpmWrite` has exactly ONE caller in the tree:
    `Emulated.Machines/ND/ND100/ND100Memory.cs:580`, inside the ND-100 write path. `Nd500PortBDepth`
    appears only in `NDBusND500IF.cs` (the 3022 card) and nowhere in the octobus path. **There is no
    code path by which an ND-500 Port B write reaches our log at all** — the ND-500 reaches the same
    DeviceRAM by a different route that never calls `RecordMpmWrite`.
 2. **Behavioural.** All 5,849,918 entries carry `thr=15` — a single managed thread — while the
    ND-5000 CPU runs on its own thread (`startRunThread=True`). If the ND-500 side were reaching
    this log, a second thread id would appear. None does.

Two independent confirmations, one static and one measured, which is why §20's caller histogram
stands where their PST attribution did not. **Not luck: the two instruments have different shapes.**
Theirs is a RAM-level trace that both ports pass through, so it MUST discriminate by port and can be
fooled by a racing static. Ours is fed from one CPU's memory path, so the discrimination is
structural and there is no race to lose.

Worth keeping as a design note: **an instrument placed where only one writer can reach it needs no
attribution logic, and therefore cannot get attribution wrong.** When a trace has to tell writers
apart at runtime, that is a signal to move the probe rather than to add a flag.

### 29a. And do not read their `LSWPAGE:84` as a working growable path

They add: on their lane the growable-segment path reports `calls=25 ok=0 noSlot=25`, ending
*"NO growable segments registered at all"*. So that path is dead on the classic lane too, and their
84 `LSWPAGE` calls come from somewhere else. §28's discriminator stands — they drive `LSWPAGE`, we
do not — but **it is not evidence that their growable-segment path works**, and must not be used to
justify wiring ours to match it.

---

## 30. B9 partial: `START-SWAPPER` issues ZERO ACCP commands — and what that does NOT mean `[V]` 2026-08-30

Ronny, 2026-08-30: *"you need to start-swapper first and then validate with version and some other
commands before testing dom files."* Correct, and it was the one path never exercised — the test run
all week is `ShortBringup_Octobus_**NoStartSwapper**_PlaceAndRun_Capture`, whose own comment says it
is *"deliberately WITHOUT status and WITHOUT start-swapper"*, while the full ladder starts the
swapper but its own comment admits *"D-H (PLACE/RUN...) remain TODO"*. Neither did the ordinary
thing. The ladder now carries a PLACE + RUN tail (added 2026-08-30) so it does.

### 30a. The run DIED, and that is reported as a death, not a result

`dotnet test` exited **127** with the console log ending immediately after test discovery. No
OUTCOME line, no pass/fail. Same shape as the five unexplained testhost deaths already on file, and
as the 2026-08-11 case where the "crash" turned out to be an external kill by a co-tenant session.
**Cause not established. B9 is NOT answered.**

### 30b. What DID survive, and it is a real measurement

Two ACCP-exchange dumps written before the death — `after-status` (01:28) and `after-swapper`
(01:43) — so the ladder reached `START-SWAPPER`. They are **byte-identical**:

```
6281bafb37131b76e89fe7f9d6318daa  sintran-octobus-accp-exchange-after-status.txt
6281bafb37131b76e89fe7f9d6318daa  sintran-octobus-accp-exchange-after-swapper.txt
# commands=147 unanswered=0 accpIdle=False
```

**`START-SWAPPER` issues ZERO ACCP commands.** This reproduces, on the CSFIX pack with current code,
the observation the ShortBringup comment recorded earlier — so that observation is NOT stale, which
was the open question about it.

### 30c. THE LIMIT OF THAT NEGATIVE — do not over-read it

The earlier framing was *"nothing crosses the octobus at all"*. **That is too strong, and the
octobus skill's own trap #2 says why:** *"Before recording a NEGATIVE, check the setup does not make
the positive INVISIBLE."*

The ACCP exchange log records **ACCP-level commands**. The mailbox path does not use them — a
mailbox activation is an `X5ACT` MEMORY WRITE plus a doorbell, which this log is **structurally
blind to**. So a byte-identical ACCP exchange across `START-SWAPPER` says exactly one thing:

> `START-SWAPPER` issued no ACCP commands.

It does NOT say the command did nothing, and it cannot: §28 shows the same lane taking a `3START`
(23B) through the mailbox with `startTaken=True`, which would leave this log untouched. "Did not
happen" and "could not have been observed here" are different, and this instrument can only report
the second.

### 30d. Where B9 stands

 - Reproduced and current: `START-SWAPPER` issues no ACCP-level traffic.
 - Unmeasured: whether it produces MAILBOX traffic. The MICFU histogram and SWPFU counters answer
   that, and they are printed by the same harness — the run just did not survive to print them.
 - Unmeasured: the whole PLACE + RUN tail, which is the point of the new ladder step.

Re-run needed. When it runs, read `micfu[...]` and `swpfu[...]` from the state line — NOT the MICFU
trace listing, which is capped and produced §28a's wrong negative.

---

## 22. §21 IS REFUTED. The machine was right both times; my probe was wrong. `[V]` 2026-08-30

### 22a. `MUDOM` is SET — B1's root-cause candidate is dead

The direct probe (commit `6e0451e81`) answered §21e:

```
CPU0 df@0o52222 CPUAVAILABLE=0x2003 type=3 (SAMSON) alive=True   MIFLAG=0x0003 MUDOM=SET
CPU1 df@0o52270                     type=3 (SAMSON) alive=False  MIFLAG=0x0002 MUDOM=SET
CPU2 df@0o52336                     type=3 (SAMSON) alive=False  MIFLAG=0x0002 MUDOM=SET
CPU3 df@0o52404                     type=3 (SAMSON) alive=False  MIFLAG=0x0002 MUDOM=SET
```

`MUDOM` is set on all four datafields. So the IOX `100406` presence probe DID satisfy SINTRAN, and
`X5STA` / `X5ACC` / `X5OCT` / `X5HWB` **are** initialised. **The gate is not the bug.**

The carve in §21e stays correct and useful — `MUDOM` really is the 500-vs-5000 gate, it really has
one writer, and the two failure shapes really are distinguishable. What is refuted is the guess that
we were on the failing side of it. **B1's root cause is once again UNKNOWN.**

### 22b. `5MBBANK` — the probe used the wrong shift

§21b called `5MBBANK`=33 vs `5FPMAILBOX`=2129 an inconsistency in the live machine, on the reading
that `AD SH 12` keeping the high half means `>> 4`. **Wrong.**

**A bank is `0x20000` = 128 KB = 64 pages of 2048 bytes, so `bank = pages >> 6`.**
`2129 >> 6 = 33` — **exactly** the measured `5MBBANK`. The machine was right; the recompute was
wrong, and it had been printing `MISMATCH` on every run because of it.

Same for the X5ACT line: `X500DF << 1 = 0x8800` **IS** `START_MESS`, so adding it pushed the window
out by exactly that much. Corrected, `X5ACT_carved` = `(5FPMAILBOX << 11) + (1 << 8) + 0x0A` =
`0x0042890A`, which **MATCHES** the discovered address. The `delta 0x8800` I reported was the
constant being added twice.

### 22c. The lesson, and it is a new one

**A harness line that prints `MISMATCH` is making a claim about TWO things: the machine AND the
harness's own recompute. I attributed the error to the machine both times, and both times it was
the recompute.**

That is not taxonomy #7 (a number that cannot be checked) — a MISMATCH line looks like the very
opposite, a number WITH a check. It is closer to #13's amplifier: the comparison is only as good as
the model behind the second operand, and an unverified model produces a confident, specific,
wrong-direction accusation. **Before believing a MISMATCH, derive the expected side independently —
here, from the physical meaning of a bank (128 KB / 2048 = 64 pages) rather than from a re-reading
of the same instruction.**

The `AD SH 12` decode is the trap: reading it as "shift the pair left 12, keep the high half" gives
`>> 4` and is fluent, plausible, and wrong. The units settle it, not the mnemonic.

### 22d. SHARED-TREE NOTE — the tree moved under this measurement

`0efc22cd1` ("5MBBANK: the probe used the wrong shift, the machine was right") and `b023b6ce7`
("Let two MPM watches share the ring instead of taking it from each other") landed **while this
investigation was running**, from the other session in the same checkout. My `MUDOM` run therefore
built against a tree containing a fix I had not made and did not know about — which is why the
carved-mailbox line changed from `MISMATCH (delta 0x8800)` to `MATCH` between two runs I believed
differed only in my own probe.

**When a harness output changes and you did not change it, check `git log` before explaining the
difference.** Two sessions, one checkout.

## 31. THE DISCRIMINATOR RAN: the stall is INDEPENDENT of `START-SWAPPER` `[V]` 2026-08-30

`ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, macro round (`RETROCORE_ND5000_ROUND=''`),
pack `DOMS-CSFIX.IMG`. **Passed, 32.2 minutes.**
Log: `C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\mudom.log` (39 MB).

This test was built (harness comment at `Nd100SintranNd5000OctobusBootHarnessTests.cs:2713-2748`) to
decide between two outcomes. **It landed on outcome 2.**

### What the console actually printed

```
ND-500/5000 MONITOR  Version J04 88. 6.16 / 88. 8.17
ND-5000 timeout:      ACCP was terminated; Microprogram has stopped     <- B1, before any command
ND-5000: define-swap-file / File name: swap-file:data                   <- OK
ND-5000: place-domain cpu-stat
> Loading Control Store
INFO    * 0B:6B * ... SINTRAN III File System / Not used                <- B2, inside the CS load
> Loading Swapper
                                                                        <- STALL. No "> Allocating memory".
OUTCOME(short bring-up): nd-500=OK place-domain=STALL run=STALL startMessagesSeen=1
```

`STATUS` was never typed and `START-SWAPPER` was never typed. The stall is identical. **So
`START-SWAPPER` is exonerated as the cause of the place-domain stall** — removing it entirely from
the sequence changes nothing. Per the harness's own pre-registered reading, that is outcome 2: "the
hang is real and independent of START-SWAPPER".

Scope note, so this is not over-read: this does NOT say `START-SWAPPER`'s own hang (§30) is
harmless, and it does NOT re-open whether `LOAD-SWAPPER` should be typed. It says only that the
place-domain stall reproduces with neither command present.

### Where it stops, precisely

`> Loading Control Store` completes and `> Loading Swapper` is REACHED. The lane does not die at the
control store on this round. It dies between `> Loading Swapper` and `> Allocating memory`.

State line after PLACE-DOMAIN:

```
PC=0x08008255 stopMode=WAIT  startSeen=1 startMicfu=23B startTaken=True
msgs=65  micfu[1B:49 12B:1 23B:1 24B:1 31B:13]  restarts=1/1  swpfu[LNEWSWAP:2]
ansMON=377B ansSWPFU=1B ansArgc=4 ansArg0=0x00000001
PSTP=0x0003A000 CTXBASE=0x0002A000 trapsAttempted=0 trapsPosted=0
```

Read from the STATE LINE, not the capped MICFU listing (§28a). Note `restarts=1/1` — `Seen == Taken`,
so there is **no MON-forwarding gap** here; the ledger's `Seen > Taken` tell does not fire.

### The swapper handover is CONSISTENT, and it is the designed idle

```
call:SWPD4-fifo-drain        @0o136237  hits=1
5ACTSWAPPER-entry            @0o145162  hits=1
HANDOVER-taken-SWACTIVE      @0o145211  hits=1
queued-on-swapwait-fifo      @0o145312  hits=0
bail:NOT-BSWSTARTED          @0o135551  hits=0
INVARIANT callers=1 entry=1 outcomes=1 (bailed=0)  [consistent]
```

SINTRAN activated the swapper exactly once, from the FIFO drain; the handover was taken; nothing
bailed. The swapper then asked `LNEWSWAP` twice, was told there is nothing to do, and parked at
`PC=0x08008255 stopMode=WAIT`. **That is the designed idle, not a fault.**

### So the discriminator is still `LSWPAGE`, and it is now sharper

`swpfu[LNEWSWAP:2]` and **`LSWPAGE` absent**. SINTRAN woke the swapper, the swapper asked for work,
and SINTRAN had none queued. The question is therefore NOT "why does the swapper not run" — it runs,
correctly, and idles correctly. It is:

> **After `> Loading Swapper`, what is supposed to put a page-swap request on the queue for a
> PLACE-DOMAIN, and why does nothing put one there?**

That is a SINTRAN-side read (`MP-P2-N500` / `030-S3SM5`), not another emulator instrument.

### Two instruments that reported honestly, and are worth keeping

- Page faults: `census: page-fault records posted: 0` AND `translate: NOTHING MEASURED - no address
  outside segment 1 was translated in this run, so the shadow-fallback count says nothing either
  way.` The instrument declared its own blind spot instead of letting 0 read as a finding. That is
  taxonomy #8 handled at the point of measurement.
- `PHYSWR source-buffer writes [0x42CBF0..0x42CC40): 5168 total, 0 NON-ZERO`. **Do not read this as
  "the swapper image is all zeros".** The 13 copy-family transfers are 4-byte writes to ND-500
  physical `0x96..0xC4` — the 13-word parameter block, not an image. An image transfer would be
  13B/14B and thousands of bytes, and there is no 13B/14B in `micfu[]` at all.

### Still open from this run

- **B1** reproduces: the `N5TIMOUT` fires at `@nd-500` before any command, twice. §27/§22 killed the
  `MUDOM` explanation; root cause is UNKNOWN again (#82).
- **B2** reproduces: `INFO 0B:6B` lands *between* `> Loading Control Store` and `> Loading Swapper`.
- Round 2 (`hw-cpu`) of this same test is running — the standing two-round rule. A macro-only
  conclusion is not a conclusion.

## 32. `TESTOBJ=29` is unimplemented, and it kills EVERY microprogram start the real ACCP attempts `[V]` 2026-08-30

Ran the EXISTING suites rather than building an instrument (standing rule,
`check-existing-machines-before-building`):
`Nd5000RealCpuStartTests`, `Nd5000RealControlStoreTests`, `Nd5000ControlStoreLinkTests`,
`Nd5000LoadControlStoreCommandTests`, `Nd5000CsaFailureTraceTests` in
`Nuget\HackerCorpLabs.Emulation.Machines.Accp\tests`.
Log: `C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\accp-cs.log`. **23/23 passed, 11 m 1 s.**

### FIRST, THE THING THAT MATTERS MOST: green here does NOT mean the link works

The suite passed 23/23 **while its own console output shows the ACCP selftest failing across the
board.** That is not a contradiction and not a broken test — `Nd5000RealCpuStartTests` says so on its
face: *"this fixture REPORTS what the engine did ... and asserts only what is independently known ...
The pass condition — word[6] of the read-back at 0x001144F0 coming back 0x0100 — becomes an
assertion only once a run has shown it honestly true."*

**So the "Machines.Accp 142/142 green" that closed #81 licenses exactly one claim: THE ACCP BOOTS.**
It never licensed "the control-store link works". Two different claims; only the first was measured.
Anyone re-reading #81 should stop at that line.

Measured this run: `verdict block @0x001144F0: [6]=0000`. The pass condition is `0x0100`. Not met.

### THE DEFECT, and it is ours

```
microwords written: 8 addresses [ 0o0 0o1 0o37760 0o37761 0o37762 0o37763 0o37764 ]
starts: 4
START @0o0     ticks=0 stop='Test condition TESTOBJ=29 not implemented yet' trail=0
START @0o0     ticks=0 stop='Test condition TESTOBJ=29 not implemented yet'
START @0o0     ticks=0 stop='Test condition TESTOBJ=29 not implemented yet'
START @0o37760 ticks=1 stop='Test condition TESTOBJ=29 not implemented yet' trail=37760 0
```

**All four starts die at tick 0 or 1 on the same unimplemented condition.** The engine never runs the
firmware's test microprogram at all. Everything the console then reports downstream is a consequence:

```
Control Store  sample test ab failed      (read-back pattern != written pattern)
Start/stop microprogram test abc failed at CSA: 00FFH
A,MARG D,AIB test  failed    Result: 0000FFFFH  Expected: 00000000H
ALU verify test    failed    Result: 87654321H  Expected: 87654322H   (then AAAAAAAA/55555555,
                                                  Result always 87654321H - the seed, unchanged)
Instruction Cache / Data Cache / Control Cache sample  failed
Selftest  failed. Selftest status: 077CH
```

`87654321H` is the firmware's own seed (the link trace shows `SHIFT 8765` going in). It comes back
unchanged because **no microword ever executed to change it** — not because a read-back path returns
a constant. I nearly wrote the latter; `VERIFY ... lowHalf` is `0xFFFF` at `0x3FF2` and `0x4321` at
`0x3FF0`, so it is not constant. Do not re-adopt the constant-readback story.

### WHY THIS WAS INVISIBLE UNTIL NOW — taxonomy #8, the structurally blind instrument

Swept all 16,384 words of `MICRO-5800-B30.DATA` for TESTOBJ (bits 58..53):

```
TESTOBJ hole codes present in B30: {38: 50}
TESTOBJ=29 count in B30: 0
```

**`TESTOBJ=29` occurs ZERO times in the entire B30 image.** It exists only in the microwords the
**ACCP firmware writes itself** for its selftest (addresses `0o0`, `0o1`, `0o37760`..`0o37764`).
The ~11k-vector differential oracle runs B30 macro instructions, so it can NEVER reach this
condition — its silence about TESTOBJ 29 carries no information whatsoever.

29 sits in the SAME documented hole set as 38 (`Conditions.cs:164` lists the holes: 4-7, 12-15,
22-23, **29-31**, 33, 38-39, 45-47, 50-55, 58; the ND-05.022.1 Appendix A table and
`mnemonics.md` both run straight past them).

### The precedent for resolving it, and why it does NOT transfer

TESTOBJ 38 was settled as a normally-asserted `true` by the differential oracle — 11,242 pass vs
11,202 with `false`, plus a corpus that flipped. **That method is unavailable for 29**: no B30 word
uses it, so there is no differential signal at all.
What IS available is a direct oracle the 38 work never had: the ACCP firmware's selftest is a
PROGRAM WITH A KNOWN PASS CONDITION (`word[6] == 0x0100` at `0x001144F0`). Implement a candidate,
run `Nd5000RealCpuStartTests`, and the firmware itself grades the answer.

### Next, in order

1. Decode the firmware's own selftest microwords at `0o0`/`0o1`/`0o37760..4` from the link trace
   (`WRITE @0o0 hi=564051AF4C92BB59 lo=8BB40393542650DD` etc. are in the log) and read what the
   TESTOBJ-29 word is testing from its ALU/A/B/DEST context — the same static method that worked on
   `TESTFD`.
2. Only then pick a candidate semantic, and let the firmware's `0x0100` verdict grade it.
3. Re-run the `hw-cpu` short bring-up. If `Error when loading Control Store` survives, TESTOBJ 29
   was not the whole of #78 — do not assume it is.

**Unresolved and NOT explained by this:** `MFbus controller has incorrect CPU model setting.
CPU model: ND-5800` is printed by the firmware in the same selftest. It may be independent.

## 33. CORRECTION TO §32: those are TEST PATTERNS, not microcode. Do not implement to them. `[V]` 2026-08-30

§32 said `TESTOBJ=29` is "the named cause" of #78 and that the fix path was to implement it, graded
by the ACCP firmware's selftest verdict. **The grading pass ran and the framing is wrong.** Keeping
§32 above unedited so the wrong version is not re-adopted; this section replaces its conclusion.

### The grading measurement was NULL

Both polarities, `Nd5000RealCpuStartTests`, logs `t29-false.log` / `t29-true.log`:

```
RETROCORE_ND5000_TESTOBJ29=0     RETROCORE_ND5000_TESTOBJ29=1
START @0o0     ticks=0 stop='Operand select A,IDU,DPA not implemented yet'   (both)
START @0o37760 ticks=1 stop='Operand select A,IDU,DPA not implemented yet'   (both)
verdict block @0x001144F0 [6]=0000                                           (both)
```

**Byte-identical.** The engine now gets past the condition and dies on the NEXT unimplemented
feature IN THE SAME WORD, so the firmware's verdict cannot discriminate the polarities at all.
`TESTOBJ 29` stays `[OPEN]` and the knob's default is still an unvalidated guess.

### And it would not have been worth implementing anyway

Decoded the firmware's own written words (`fwdec.py`, from the `WRITE @...` hi/lo in `accp-cs.log`).
**Word `0o0` is not microcode. It is a RAM test pattern.** Four independent confirmations:

1. `hi=564051AF4C92BB59 lo=8BB40393542650DD` is EXACTLY the eight halfwords the console prints as
   the Control Store sample test result: `5640H 51AFH 4C92H BB59H 8BB4H 0393H 5426H 50DDH`.
2. Its decode lights up nearly every field at once with mutually exotic values -
   `AAP1,UCTF` + `AAP2,MULABSA` + `ORA,ALTEN` + `AB,CMBRET` + `IX*8` + `EA2SAVE` + `TBC,PREL` +
   `ABR,NPCREL` + `CSAVE` + `LCDECR` + `TESTOBJ=29` + `STATUS=11`. No hand-written microword looks
   like this. `TESTOBJ=29` is an ARTEFACT OF THE PATTERN, not evidence that 29 means anything.
3. Words `0o37761`..`0o37764` are a textbook walking pattern:
   `3FF0` / `3FF0 3FF1` / `3FF0 3FF1 3FF2` / `3FF0 3FF1 3FF2 3FF3`.
4. Word `0o37760-b` = `40400001DE028018` is exactly the Control Cache sample test's printed result
   `4040H 0001H DE02H 8018H`.

**So implementing `TESTOBJ 29`, or `A,IDU,DPA`, to satisfy these starts is modelling NOISE.** A
random bit pattern cannot teach us what an undocumented field means. This is the mirror image of the
`TESTOBJ 38` precedent: 38 was pinned by ~11k REAL vectors; 29 is reachable only from a pattern.

### What the selftest is actually testing, and the two real leads

The ACCP selftest is a **RAM/link test of the control store**, plus a start/stop test that arms the
engine and reads the CSA back. That splits #78 into two independent questions:

- **LEAD 1 (link, and the better one).** The Control Store sample test writes a pattern and reads a
  DIFFERENT one back:
  `Result: 5640 51AF 4C92 BB59 8BB4 0393 5426 50DD` vs
  `Expected: 7698 B027 0AAA 2C91 0D8C F58B AFBE 6195`.
  That is a link/shift-path mismatch and needs NO microword execution at all. It is much the closer
  fit to SINTRAN's `Error when loading Control Store`, which is also a read-back verify.
  Whether the two patterns are related by a shift is NOT yet established - do not assume it.
- **LEAD 2 (execution).** The start/stop test expects the engine to ARM at an address and advance
  the CSA. Ours throws on unimplemented fields instead. The question is not "implement these
  fields" but "what should the engine do when handed arbitrary bits" - a design call, not a carve.

### Revised statement of #78

Not "TESTOBJ 29 is unimplemented". Rather: **our `CpuND5000` refuses to execute arbitrary control-
store contents, and our control-store link returns a different pattern than the firmware wrote.**
Only the second of those is plausibly what breaks SINTRAN's CS load, and it is where to look next.

### The lesson, for the taxonomy

**A stop message names the first thing that refused, not the thing that is wrong.** Fixing it just
advances the refusal to the next feature in the same word - and if the input is noise, that walk has
no end and every step of it looks like progress. Before implementing anything a trace demands, ask
what WROTE the input: here, one `WRITE @` line in the same log answered it.

---

## 33. #79 CARVED TO ITS END: the swapper is idle because nothing ever FAULTS `[V]` 2026-08-30

Pure SINTRAN-side carve, no new instrument, answering §31's reframed question: *after
`> Loading Swapper`, what is supposed to put a page-swap request on the queue, and why does nothing
put one there?*

### 33a. The dispatch is driven by the ND-500, not by SINTRAN

`SWPDECODER` (`MP-P2-N500.NPL:913`) reads the swap-function **out of the mailbox** and jumps:

```
135443   T:=5MBBANK; *AAX SWPFU; LDATX          % Swap-function
135446   IF A >> SWFMAX GO FAR ESWPFATAL
135451   A GOSW  FAR ESWPFATAL, LNEWSWAP, FAR LSWPAGE, FAR LPRSUSPEND,
135456           FAR LALLOPAGE, FAR LDATREADY, FAR LCLTSB;
```

So `LSWPAGE` (arm 2, *"Disk I/O"*) is **requested by the ND-500 swapper**, not originated by SINTRAN.
`LSWPAGE = 0` therefore does not mean SINTRAN failed to queue anything — it means **the swapper never
asked for a page**, which is the correct behaviour for a swapper with no work.

### 33b. Why `LNEWSWAP` answers "nothing to do" — first two lines of the handler

```
135470   LNEWSWAP:
135470      T:=5MBBANK; X:=SWMSG; *AAX HSWPI; LDDTX   % AD:=X.SWPINFO
135474      IF D><0 THEN                              % Any proc. currently served?
```

It branches on `SWMSG.HSWPI`. **The harness already measures that exact cell:
`HSWPI probe → LastStartSwpInfo=0x00000000`.** Zero → no process being served → fall through → no
work → the answer we observe, and the park at `PC=0x08008255 stopMode=WAIT`.

### 33c. Who sets `HSWPI`, and why it is zero

`5ACTSWAPPER` (`MP-P2-N500.NPL:144762`):

```
144775   SWPWAIT; CALL WN5STATUS              % mark proc waiting for swapper
145001   IF A=PSWWAIT THEN                    % swapper free?
145006      AD:=CMSGTOSW; *AAX HSWPI; STDTX   % HSWPI := the requesting message
145011      SWACTIVE; *AAX SWPFU-HSWPI; STATX % SWPFU := SWACTIVE
```

and it is cleared again at `136057` (`*AAX HSWPI; STZTX`) when the request completes.

Measured on this lane: `5ACTSWAPPER-entry hits=1`, `HANDOVER-taken-SWACTIVE hits=1`, via the SWPD4
FIFO drain, `queued-on-swapwait-fifo hits=0`. **Set once, served, cleared — so zero afterwards is
correct, not corrupt.**

### 33d. The end of the chain, and it points UPSTREAM

`5ACTSWAPPER` has four callers: the MSWSWAIT tail (`134154`), **TRAPDECODER's trap-46 arm**
(`135367`), the SWPD4 FIFO drain (`136037`), and `SWMC` = MON 510B (`141765`). Only the FIFO drain
fired, once. **Trap 46 is the PAGE FAULT arm**, and `trapsPosted=0` was measured.

```
the domain never actually executes
   -> no page fault is ever raised
   -> TRAPDECODER's trap-46 arm is never reached
   -> 5ACTSWAPPER is never called again
   -> HSWPI stays 0, LNEWSWAP keeps answering "nothing to do"
   -> the swapper idles CORRECTLY at PC=0x08008255, forever
```

**Every element of that chain is behaving as designed.** There is no bug anywhere in it. The chain
is a CONSEQUENCE, and its head — "the domain never executes" — is #78: the control store does not
load against the real microword CPU, so no microprogram runs, so nothing can fault.

### 33e. What this closes and what it does NOT

**CLOSES:** the whole "why does the swapper not get work" line of enquiry, which has consumed most
of this document. The answer is that it correctly has none. Do not instrument it further; do not
"fix" `5ACTSWAPPER`, `LNEWSWAP`, `HSWPI` or the FIFO.

**DOES NOT CLOSE:** #78. And it does not by itself explain the MACRO round, where the CS load
*succeeds* and `> Allocating memory` is still never reached — on that round the head of the chain
needs its own answer, because there the microprogram should be running. **Do not assume the macro
stall and the hw-cpu stall have one cause just because they share a downstream chain** — that is the
shape of error §22 and §23 both punished.

## 34. LEAD 1 opened: the control-cache read falls through to the store `[V]`, and the CS sample mismatch has STRUCTURE `[V]` 2026-08-30

Following §33's LEAD 1. Pure analysis of `accp-cs.log`, no runs.

### 34a. The Control Cache sample test - a clean, named modelling gap `[V]`

```
Control Cache  sample test  failed
Result  : 4040H 0001H DE02H 8018H 0000H 0000H 0000H 0000H
Expected: 0000H 0000H 0000H 0000H 0000H 0000H 0000H 0000H
Address :    0000H
```

`40400001DE028018` is EXACTLY the word the same log shows being written moments earlier:
`WRITE @0o37760 hi=40400001DE028018 lo=0000000000000000`.

So the firmware asked the **control cache** for address 0 and got back **the last word written to the
control STORE**. We do not model a separate control cache, so the read falls through. The expected
value is all zeros - an unwritten cache line.
This one needs no pattern theory: it is a missing device, and the firmware named it.

### 34b. The Control Store sample mismatch is NOT random `[V]`, but one pair cannot name the cause

```
Result  : 5640 51AF 4C92 BB59 8BB4 0393 5426 50DD    (what our store returned - and it IS what was
Expected: 7698 B027 0AAA 2C91 0D8C F58B AFBE 6195     written: WRITE @0o0 hi=564051AF4C92BB59 ...)
```

Whole-word tests that FAIL (so do not re-run them): `E` is not `R` rotated or shifted by any of the
127 bit amounts, not a halfword rotation, not halfword-reversed, not bit-reversed per halfword, not
byte-swapped per halfword. Whole-word XOR popcount is 54/128 - superficially random.

**Per halfword it is not random at all.** Across ALL EIGHT halfwords:

```
bits that ALWAYS differ : 0000000000001000     (bit 3, every halfword)
bits that NEVER differ  : 0000000000000111     (bits 0-2, every halfword)
bits 4-15               : unrelated
```

And bits 0-2 of the halfwords read, in order, `0 7 2 1 4 3 6 5` - a PERMUTATION of 0..7, i.e. a
per-halfword positional tag, and it MATCHES between written and expected.

Two things follow, and only two:
 - **Halfword ordering and position are CORRECT.** The positional tag agrees. That rules out a
   halfword shift, rotation or reversal in the link - which is what LEAD 1 was originally guessing at.
 - The remaining difference is one systematically inverted bit per halfword (bit 3) plus twelve
   unrelated bits. Those two facts do not sit together under a single simple cause, so **the honest
   reading is that these are two DIFFERENT words of the firmware's generated sequence** that share
   the positional-tag scheme - i.e. a sequence/address offset in the comparison, not a corrupted word.

**NOT ESTABLISHED, do not adopt either:** that bit 3 is a stuck data lane (bits 4-15 would then have
to match, and they do not); that the patterns are related by a shift (tested, they are not).

**What would settle it, and it is cheap:** more Result/Expected pairs. One pair shows structure; three
or four would show whether `Expected` is a fixed offset along the same generator. The firmware prints
a pair per sample test, and the sample test runs at several addresses.

### Ordering note

34a is a defect we can name and fix; 34b is a lead that still needs data. Do 34a first - and check
afterwards whether it alone changes SINTRAN's `Error when loading Control Store`, since a read-back
verify that consults a cache we do not model would fail for exactly this reason.

## 35. The ORACLE round boots - the earlier "real ACCP" failures were the timeout `[V]` 2026-08-30

`ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, `RETROCORE_ND5000_ROUND=hw`
(microword B30 CPU **and** real 68000 ACCP firmware), `RETROCORE_HARNESS_TIMEOUT_SCALE=8`.
Log `mudom-hw-s8.log`. **Passed, 36 m 28 s.**

At scale 1 this same round failed at 5 m 02 s on `boot reached 'SINTRAN III RUNNING'`. At scale 8 it
reaches `SINTRAN III RUNNING`, logs in, and runs `set-avail` fine. **The boot failure was the
300,000 ms host wall-clock budget, exactly as the harness comment at
`Nd100SintranNd5000OctobusBootHarnessTests.cs:3249-3254` warns.** Ronny was right on 2026-08-29 and
the correction holds: the ACCP boots.
Guest clock shows boot completing at 03.06 against a 02:42 start - roughly 24 minutes of host time
for a boot the macro round does in about 5 seconds.

### THE TEST PASSED AND THE ROUND DID NOT SUCCEED - read the capture name

```
----- `set-avail` (OK) -----
----- @nd-500 (STALL) -----
----- captured console (octobus-shortbringup-no-monitor) -----
```

`@nd-500` produced NO monitor banner, and the harness soft-bails to a `-no-monitor` capture instead
of asserting. So `Passed!` here means "the fixture completed its bail path". **That is the third
green-signal-that-means-less-than-it-looks tonight** (the others: Machines.Accp 142/142 vs the failing
selftest in §32, and `place-domain=returned` being the error path in §31). On this lane, read the
capture name and the OUTCOME line, never the pass/fail.

Scope: the `@nd-500` wait had roughly 12 minutes of the run left. That is long against a macro round
that answers in seconds, but the run ended at its own budget, so "the monitor never comes up" is NOT
yet separable from "not within this window". Do not record it as the former.

### What IS solid: almost nothing crosses the octobus on this round

| measure | macro round (§31) | oracle round `hw` |
|---|---|---|
| station -> ND-100 frames | 896 | **18** |
| `N5STA=1` in mailbox nbhd | 1222 | **16** |
| MicroVersion / CpuParameter | `0x2E9A` / `0x03E1` | empty |
| X5ACT activation candidates | 4096 | **0** |
| discovered mailbox | header+extBlock found | blank |
| servicer copy-family | 13 transfers | **0** |

SINTRAN still reports `1 alive -> ND-500 subsystem initialised`, which again is not evidence that
anything works (§32).

### Still running, and it is the discriminator

`hw-accp` (macro CPU + REAL ACCP) at scale 8. Reading:
 - if `hw-accp` reaches the monitor, the microword CPU is what blocks it;
 - if it stalls at `@nd-500` too, the real ACCP path is, and the microword CPU is not implicated.

## 36. CORRECTION TO §34b: `Expected` is a FIXED CONSTANT, so the write path is the suspect `[V]` 2026-08-30

§34b read the Control Store sample mismatch as "two different words of the firmware's generated
sequence ... a sequence/address offset in the comparison". **Two independent runs refute that.**

`accp-cs.log` (RealCpuSink) and `accp-suite.log` (an earlier run, different sink) print the SAME
expected value:

```
accp-suite.log:  Result  : FFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFF   (address 0 never written)
                 Expected: 7698 B027 0AAA 2C91 0D8C F58B AFBE 6195
accp-cs.log:     Result  : 5640 51AF 4C92 BB59 8BB4 0393 5426 50DD   (what OUR sink stored at 0o0)
                 Expected: 7698 B027 0AAA 2C91 0D8C F58B AFBE 6195   <- IDENTICAL
```

**`Expected` is a fixed constant the firmware always wants at address 0.** It is not per-run and not
a member of a sequence, so the "sequence offset" reading in §34b is dead. The bit-3 / bits-0-2
structure noted there is real but does NOT support that conclusion; ignore the conclusion, keep the
measurement.

That reframes the whole thing: the firmware writes, expects a SPECIFIC pattern back, and our sink
faithfully returns what it stored. **So the corruption - if it is corruption - is on the WRITE path,
not the read-back.** Either the firmware's shifted-in data is being stored wrong, or the store is
expected to TRANSFORM it (the ACCP loads the control store through APR/ASR serial shift loops that
run THROUGH the CPU - see the octobus skill - so a verbatim store may itself be the wrong model).

### Two concrete oddities in the link trace, both `[V]`, neither yet explained

**1. Two different gate values on the same command.** Census of the retained trace in `accp-cs.log`:

```
4x  cmd=0x0018 gate=0x04     <- the console LOAD-CONTROL-STORE path (verbatim, and it round-trips)
1x  cmd=0x0018 gate=0x02     <- the selftest path, adjacent to MICRO-ARM
```

The console path with `gate=0x04` is provably faithful - its SHIFTs and its COMMIT match exactly
(`SHIFT 1122 3344 ... F001` -> `COMMIT ... 112233445566778899AABBCCDDEEF001`, reply `- OK -`).
Whether we treat `gate=0x02` differently from `0x04` is UNCHECKED and is the first thing to read.

**2. Data shifted under one address, committed at another.**

```
SHIFT 3FF1 / ADDR-LATCH 3FF1 / SHIFT 4040 0001 DE02 8018 0000 0000 0000 0000 / ADDR-LATCH 0000 halfwords=7
SHIFT 3FF0 / ADDR-LATCH 3FF0 / MICRO-ARM addr=0x3FF0 started=True
COMMIT  cmd=0x0018 addr=0x3FF0 gate=0x02  40400001DE028018 0000000000000000
```

The eight data halfwords arrive while the latched address is `3FF1`; the commit then lands them at
`3FF0`. That may be correct (a pipelined address/data convention) or an off-by-one in our latch
handling. **NOT ESTABLISHED either way** - it is named here because it is exactly the shape that
would make a write land one word off, and a one-word offset is what a "wrote X, expected Y" sample
test would report.

### Next, in order, and all of it is reading not running

1. Read the `gate` handling in `OctobusND5000Station` / the control-store link: is `0x02` given the
   same path as `0x04`?
2. Read the ADDR-LATCH/COMMIT pairing rule against the ACCP manual's LOCSD/LOCSM description.
3. Only then form a hypothesis about the constant `7698 B027 0AAA 2C91 0D8C F58B AFBE 6195`.

## 37. §36 follow-up: the transform search is EXHAUSTED and empty - stop theorising, capture the trace `[V]` 2026-08-30

### The link already declares the gap - read it before theorising further

`Nuget\HackerCorpLabs.Emulation.Machines.Accp\src\Devices\Nd5000ControlStoreLink.cs:127-133`, in its
own words:

> **MODELLING ASSUMPTION, stated rather than hidden.** The 128-bit microword is taken from the EIGHT
> 16-bit words written to `0x550000` between gate-on and the `0x0018` command, in the order written.
> The clock pairs are counted and checked for phase order but are not modelled bit by bit: the
> firmware emits 8 clock pairs per 16-bit word, which is not one clock per bit, so the exact serial
> mechanism is NOT proven and is deliberately NOT invented here.

So we stage 8 words verbatim where the hardware runs a real serial shift. That is the right shape of
gap for "wrote X, expected Y". It also answers §36's gate question: the two gate bits are DOCUMENTED
and deliberate - `0x741E` uses bit 2 (`0x04`), `0x764E` uses bit 1 (`0x02`), and
`GateBitAlternate` handles both. **`gate=0x02` is not an unhandled case. Drop that suspicion.**

### Transform search: NEGATIVE, and exhaustive enough to record so it is not repeated

Does `E = 7698 B027 0AAA 2C91 0D8C F58B AFBE 6195` come from
`R = 5640 51AF 4C92 BB59 8BB4 0393 5426 50DD` by any plausible serial re-ordering?

Tested and ALL NEGATIVE: all 127 bit rotations and shifts, both directions; halfword rotation;
halfword reversal; per-halfword bit reversal; per-halfword byte swap; per-halfword rotation; full
128-bit reversal; 64-bit half swap then any rotation; complement then any rotation; and
de-interleaving into 2, 4, 8 and 16 lanes with every per-lane rotation.

**The two patterns also share NO halfword value at all**, so `E` is not a word-shifted view of `R`
with new words entering either.

`E` is therefore not a re-ordering of `R`. It is a DIFFERENT pattern.

### What the second run says, and where the inference has to stop

`accp-suite.log` read address 0 as all `FFFF` - the adapter's "nothing was ever written here" -
while expecting the same constant `7698 ...`. If that is taken at face value, the firmware's write
of the expected pattern to address 0 never reached the sink in that run at all.

**I am not building further on that.** Two logs from different harness states, one of them from
00:55 and possibly predating fixes, is exactly the material from which a plausible tower gets built
(RULE #0b). The chain already has three inferential steps and no direct observation of the write.

### The next step is a MEASUREMENT, not another theory

The link trace in `accp-cs.log` is capped - it prints "last 140" entries, which is the `0x3FF0`
window. **The address-0 window is not in it.** Get the full SHIFT / ADDR-LATCH / COMMIT sequence for
the sample test's address-0 write and read it in order: what the firmware shifts, in what order,
under which latched address, and what we commit. That is one diagnostic change (raise or filter the
trace cap), and it replaces every remaining guess above with bytes.

## 38. THE 2x2 IS ANSWERED: the CPU axis decides the outcome, the ACCP axis only decides the SPEED `[V]` 2026-08-30

`ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, pack `DOMS-CSFIX.IMG`, all four round
modes. `hw-accp` at `RETROCORE_HARNESS_TIMEOUT_SCALE=8` finally landed: **passed, 4 h 36 m**
(`mudom-hwaccp-s8.log`).

| round | CPU | ACCP | monitor | how far | wall clock |
|---|---|---|---|---|---|
| `''` | macro | emulated | **OK** | `> Loading Swapper`, then STALL | 32 m |
| `hw-accp` | macro | **real 68k** | **OK** | `> Loading Swapper`, then STALL | **4 h 36 m** |
| `hw-cpu` | **microword B30** | emulated | n/a | **`Error when loading Control Store`** -> fatal | 2.5 m |
| `hw` | **microword B30** | **real 68k** | STALL | never reached the monitor | 36 m, budget-limited |

`hw-accp` is IDENTICAL to the macro round in every outcome field:
`nd-500=OK place-domain=STALL run=STALL startMessagesSeen=1`, 896 station->ND-100 frames,
13 copy-family transfers, `> Loading Control Store` then `> Loading Swapper`.

**So the real 68000 ACCP changes NOTHING about what happens - only how long it takes (8.6x slower,
276 min vs 32 min).** The two macro cells agree completely; the microword cell fails at the control
store. **The CPU axis decides the outcome. #78 is on the microword CPU / control-store side**, which
is where §33 revised it to, and the real-ACCP path is exonerated.

### The `hw` cell is STILL not a clean measurement, and now we know why

At 8.6x slowdown, every step needs 8.6x the macro round's wall clock. The `hw` round spent about 24
of its 36 minutes booting and had roughly 12 left when its budget ended at `@nd-500`. That is not
enough to call "the monitor never comes up" - it is the same host-wall-clock artefact as §35, one
step later. **Do not score the `hw` cell.** If it is ever worth measuring, it needs scale >= 24, i.e.
a budget of hours, and the three clean cells already answer the question without it.

### What this closes and what it does not

CLOSES: "is the real ACCP implicated in the octobus stall?" - **no**. Both macro cells reach exactly
the same place with and without it. Combined with #81 (the card boots) and §32 (the green suite only
ever licensed that claim), the ACCP is not where the remaining work is.

DOES NOT CLOSE: the macro rounds' own stall after `> Loading Swapper` (that is #79, and §31 showed
the swapper is idling CORRECTLY there), nor the microword control-store failure (#78, now pointed at
the serial-shift modelling gap the link declares in §37).

## 39. THE ADDRESS-0 WRITE, READ IN ORDER: the link mispairs data with address and drops most commits `[V]` 2026-08-30

§37 said stop theorising and capture the trace. Done: `Nd5000RealCpuStartTests` now prints a 24-entry
window before every COMMIT instead of the trace tail (the tail only ever showed `0x3FF0`, which is why
this was never seen). Log `trace-window.log`, 8 commit windows out of 233,582 trace entries.

### The address-0 window, verbatim and in order

```
SHIFT      3FF0
ADDR-LATCH 3FF0 halfwords=0          <- address 3FF0 latched
SHIFT      0718 E6A7 2F2A E711 E60C D40B 5C3E 0415     <- 8 data halfwords FOR 3FF0
ADDR-LATCH 0415 halfwords=7          <- the 8TH DATA HALFWORD latched AS AN ADDRESS
SHIFT      3FFB
ADDR-LATCH 3FFB halfwords=0          <- address 3FFB latched
SHIFT      5640 51AF 4C92 BB59 8BB4 0393 5426 50DD     <- 8 data halfwords FOR 3FFB
ADDR-LATCH 10DD halfwords=7          <- again: 50DD masked to 14 bits = 10DD, latched as an address
SHIFT      0000
ADDR-LATCH 0000 halfwords=0
COMMIT     cmd=0x0018 addr=0x0000 gate=0x04 564051AF4C92BB598BB40393542650DD
```

**Three facts, all directly observed:**

1. **The committed data belongs to a different address than the commit.** `5640 51AF ... 50DD` was
   shifted while `3FFB` was latched. It is committed at **`0x0000`**.
   This is the whole of §36's "wrote X, expected Y": address 0 receives 3FFB's word.
2. **The first group is never committed at all.** `0718 E6A7 ... 0415`, shifted under `3FF0`, is
   overwritten in the staging buffer by the next eight shifts. It reaches the control store nowhere.
3. **The 8th data halfword is being latched as an address**, masked to 14 bits:
   `0415` -> `ADDR-LATCH 0415`, and `50DD & 0x3FFF = 0x10DD` -> `ADDR-LATCH 10DD`, both tagged
   `halfwords=7`. `Nd5000ControlStoreLink.cs` says the "address is the NINTH GATED word" model was
   REPLACED by the explicit `0x3010` latch - these `halfwords=7` latches look like a live remnant of
   the retired model.

The second window shows the same shape independently: groups shifted under `0002` and `0003`, then
`ADDR-LATCH 0001`, then `COMMIT addr=0x0001` carrying **`0003`'s** data.

### Why only 8 microwords ever land [D]

The console reported `writes before=8 after=9` and the sink `microwords written: 8 addresses`, across
a run in which the firmware clearly shifted many groups. **We COMMIT only on `cmd=0x0018`**; the
selftest's other writes complete by some other signal, so nearly all of them are dropped, and the few
that do commit carry the wrong group's data. Marked `[D]` - the drop is inferred from the count, the
mispairing is observed.

### What this does and does not establish

ESTABLISHED `[V]`: the link commits data under an address it was not shifted with, drops preceding
groups, and latches data halfwords as addresses. Any control-store image assembled through this path
is wrong in both content and placement - which is a sufficient cause for SINTRAN's
`Error when loading Control Store` on `hw-cpu`, since that command ends in a read-back verify.

NOT ESTABLISHED: the correct pairing rule. The obvious reading - latch an address, shift 8 words,
commit them THERE - is a guess until checked against the ACCP ROM's `0x76E6` address phase and
`0x7776` shift loop. **Do not "fix" it to the obvious rule without that check**; §33's lesson was
exactly this, and the retired ninth-word model shows this protocol has already fooled one carve.

NEXT: read `0x76E6` / `0x7776` / `0x7714` in the ACCP ROM and derive the pairing rule from the
firmware, then make the link obey it and re-run `hw-cpu`.

## 40. RETRACTION of §39's defect claim: the link had already modelled all of it `[V]` 2026-08-30

§39 read the address-0 trace and concluded the link "mispairs data with address, drops most commits,
and latches data halfwords as addresses (a live remnant of the retired ninth-word model)".
**I then read the code that produced the trace, and the defect claim does not survive.**

### What `Nd5000ControlStoreLink.cs` already says, in its own comments

- On `CommandAddressLatch` (`0x3010`, ROM `0x7714`): *"The word most recently written to `0x550000`
  IS the control-store address"*, and then, precisely about what §39 flagged:
  *"This is also what the old 'the address is the NINTH gated word' reading was really seeing: the
  firmware does write it ninth, right after the eight halves. It is the address PHASE doing so, not a
  ninth part of the microword."*
  It sets `_addressIsNewestInRing = true` so a following perform takes the eight words BEFORE it.
  **So `ADDR-LATCH 0415 halfwords=7` is EXPECTED BEHAVIOUR, not a remnant.** §39 point 3 is wrong.
- `Commit()` has three explicitly-reasoned source paths - latch (`_pendingAddress`), staging
  (`_address`), and ring with the address skipped when it is newest - each with a comment saying why.
  The address/data pairing is not an oversight; it is modelled. **§39 point 1 is unsupported.**
- `CommandOperation` (`0x2018`) is deliberately NOT a control-store write - it loads the MIR. The
  comment records that conflating them previously committed to address 0 "several hundred times per
  boot" and produced a retracted claim of 281 loaded microwords. **So the low commit count in §39
  point 2 is the CORRECTED behaviour, not evidence of dropped writes.**

### What still stands from §39

Only the OBSERVATION, which is worth keeping: in the address-0 window the eight halfwords
`5640 51AF 4C92 BB59 8BB4 0393 5426 50DD` are shifted while `3FFB` is latched, and the firmware then
runs a fresh address phase latching `0000` immediately before the `0x0018`. Committing at `0x0000`
FOLLOWS the most recent address phase. That is consistent with the protocol as carved, so it is not
by itself evidence of a fault.

### So the live explanation is the one the link declares itself (§37)

> the firmware emits 8 clock pairs per 16-bit word, which is not one clock per bit, so the exact
> serial mechanism is NOT proven and is deliberately NOT invented here

The firmware writes a pattern and expects a DIFFERENT fixed pattern back. If the address/data pairing
is correct - and the code argues it is - then the transform between them lives in the unmodelled
serial mechanism. That is the open question for #78, and it needs the ROM's `0x7776` shift loop read
bit by bit, not another trace reading.

### THE LESSON, and it is the third instance tonight

**Read the code that produces a trace BEFORE calling anything in that trace a defect.**
Tonight: §32 -> §33 (TESTOBJ 29 was a test pattern), §34b -> §36 (Expected is a fixed constant),
§39 -> §40 (the pairing was already modelled). Each time a trace looked wrong, a claim was written,
and the file that emitted the trace already contained the answer - usually in a comment written by
someone who had made the same mistake first and recorded the retraction.

The control: for any anomaly seen in an instrument's output, open the emitter and search its comments
for the field name BEFORE writing it up. That is one grep, and it would have prevented all three.

## 41. The serial-shift hypothesis is WEAKENED too - the carve already answered it `[V]` 2026-08-30

Applying §40's control (read the existing carve before deriving), `HANDOFF-ACCP-CONTROL-STORE-MODEL-
CORRECTED-2026-08-04.md` already answers the §37/§40 question, from the ROM:

```
778a  lea     0x001144F0,A3      ; buffer start
7790  lea     (0x10,A3),A4       ; END = start + 0x10 = 16 BYTES
779c  move.w  #8,D3              ; 8 clock pairs per halfword
77a0  move.w  (A3),(A2)          ; halfword -> 0x550000
77aa  addq.l  #2,A3
77ac  cmpa.l  A3,A4 / bne 779C
```

> **Neither - the firmware writes all 128 bits.** A3 walks `0x1144F0` to `0x114500` in steps of 2 -
> 16 bytes, eight halfwords, 128 bits. The length is hard-coded, so every path through `0x7776`
> sends eight; there is no four-halfword variant. `0x77B6` (shift in) is identical.

**So the data is fully determined by the eight halfwords written to the port.** The clock pairs are
timing, not a bit-serial data path. The verbatim staging model is therefore RIGHT, and §37's "the
transform lives in the unmodelled serial mechanism" is NOT supported. Weakened, not disproven - the
clock pairs still are not modelled - but nothing points at them carrying data.

The same carve names the off-by-one-word failure it fixed:
> **The shift ring needs NINE slots.** The address travels through the same `0x550000` port right
> after the eight halves, so eight slots evicted the first half and the microword committed one word
> out of step.

**Already in:** `Nd5000ControlStoreLink.cs:330` - `RingSlots = WordsPerMicroword + 1`. Not the bug.

### Incidental, and it reframes the test's pass condition

`0x001144F0` is the shift engine's SOURCE BUFFER **and** `Nd5000RealCpuStartTests.VerdictBlock`.
They are the same memory. So "word[6] comes back `0x0100`" is checking what the read-back path
(`0x2010` / `0x2011` / `0x77B6`) shifted back INTO the firmware's own buffer - not an independent
verdict register. Worth knowing before anyone treats that word as an oracle.

### Where #78 actually stands now

Every mechanism I can check is correct: address/data pairing (§40), gate bits (§37), nine-slot ring
and full-128-bit write (here). The discrepancy is real and unexplained: the firmware writes
`5640 51AF ...` at address 0 by our link's record and expects the fixed `7698 B027 ...`.

**NEXT, and it is an instrument nobody has read yet: the READ-BACK path.** Every commit-window entry
so far is a WRITE (`SHIFT` / `ADDR-LATCH` / `COMMIT`). The verify path issues `0x2010` then `0x2011`
per word through `0x77B6`, and none of that has been traced. Capture which ADDRESS the sample test
reads back and compare it with what was written THERE - the write side has now absorbed four
hypotheses without yielding, which is itself a reason to stop testing it.

## 42. The firmware NEVER writes the pattern it expects - and I am stopping the write-side audit `[V]` 2026-08-30

### Two solid facts

**1. Neither sample-test pattern is a ROM constant.** Scanned all 131,074 bytes of `AccpRom.cs`:
`7698B0270AAA2C910D8CF58BAFBE6195` (expected) - **0 hits**;
`564051AF4C92BB598BB40393542650DD` (written) - **0 hits**; even the single halfwords `7698` and
`5640` - 0 hits. Both are COMPUTED at runtime by a generator on the 68000.

**2. The firmware never writes the expected pattern to the control store at all.** The whole run
commits eight microwords, to `0o0 0o1 0o37760 0o37761 0o37762 0o37763 0o37764`, and the sink logs
each one. **None of them is `7698 B027 ...`.** The firmware expects at address 0 a value it never
stored there.

That reframes #78. The expected value cannot be explained by a prior write we mishandled, so it must
come from hardware behaviour we do not model - the read path returning something derived rather than
stored. Which is the same suspicion as §37 but now on the READ side and with a reason.

`40400001DE028018` IS a ROM constant (offset `0x13b86`) - so §34a's control-cache finding stands and
is strengthened: that is the firmware's own hard-coded test microword, written to the store, and the
cache read returns it because no separate control cache exists.

### The read-back path is ALSO correctly modelled

Checked before instrumenting, per §40's control. `ReadData()` serves from
`_controlStore.TryReadWord(_address, ...)` with the comment *"Read the word that lives AT THE
ADDRESS, not whatever was staged last"*, and `_readbackIndex - 1` correctly compensates for `0x77B6`
issuing `0x2011` BEFORE each word. `CommandVerify` rewinds the cursor. No defect.

### STOPPING THE WRITE-SIDE AUDIT - six mechanisms, no defect, diminishing returns

Audited and CORRECT: address/data pairing (§40), gate bits (§37), nine-slot shift ring (§41),
full-128-bit write (§41), read-back address selection, read-back indexing.
Hypotheses raised and killed: TESTOBJ 29 (§33), address mispairing (§40), unmodelled serial transform
(§41), ROM constants (here).

I also caught myself starting a seventh round: the per-halfword XOR of the never-committed `3FF0`
group against the expected pattern is `7180 5680 2580 CB80 EB80 2180 F380 6580` - **low byte 0x80 in
all eight**, i.e. bits 0-6 match and bit 7 always differs. Striking, and the `3FFB` group has a
different signature (bit 3). **Two data points, two incompatible signatures, and I have no third.**
The simplest account is that the firmware's generator emits values with structured low bits, in which
case both signatures are artefacts of the generator and say nothing about the link. **Not pursued -
this is exactly the RULE #0b shape that has already produced three retractions tonight.**

### What would actually settle it, when someone returns to #78

Instrument the firmware's own generator, not the link: find where the 68000 computes these patterns
and log the seed and the call sequence. Then "wrote P, expected Q" becomes "the generator was
advanced N times between the write and the check", which is answerable. Everything short of that is
curve-fitting on two samples.

## 43. #79 RESTATED: `LSWPAGE` is sent BY the swapper, not queued by SINTRAN `[V]` 2026-08-30

Read from the NPL source, `MP-P2-N500.NPL` (not derived):

```
135443   SWPDECODER:
135443          T:=5MBBANK; *AAX SWPFU; LDATX                % Swap-function
135446          IF A >> SWFMAX GO FAR ESWPFATAL
135451          A GOSW
135451             FAR ESWPFATAL, LNEWSWAP,  FAR LSWPAGE, FAR LPRSUSPEND,
135456             FAR LALLOPAGE, FAR LDATREADY, FAR LCLTSB;
...
136112   LSWPAGE:                                            % Disk I/O
```

`SWPDECODER` reads `SWPFU` **out of the swapper message** and dispatches on it. So `SWPFU` is written
by the ND-500 SWAPPER - the program running on the ND-500 - and `LSWPAGE` is the swapper **asking
SINTRAN for disk I/O**. It is a REQUEST INBOUND to SINTRAN, not work SINTRAN queues.

**So this task's previous title - "SINTRAN queues no LSWPAGE" - was backwards**, and so was the
question it framed. Corrected here.

### The actual gating chain

`LNEWSWAP`'s own comment states its job:

```
135470   % Start message currently being served by the swapper, if any,
135470   % and find next process requesting the swapper.
```

So the swapper asks "who needs me?", and SINTRAN answers from the list of processes REQUESTING the
swapper. §31 measured the swapper asking `LNEWSWAP` twice and being told nothing, then parking. The
`5ACTSWAPPER` call-site table from the same run shows why `[V]`:

```
queued-on-swapwait-fifo      @0o135312  hits=0     <- NOTHING was ever queued
call:TRAPDECODER-pagefault   @0o135567  hits=0     <- no page fault queued anything
call:SWPD4-fifo-drain        @0o136237  hits=1
```

and, from the page-fault instruments in the same capture, `page-fault records posted: 0`.

**Chain `[D]`, each link measured but the linkage inferred:** no page fault -> nothing queued on the
swap-wait FIFO -> `LNEWSWAP` finds no requesting process -> the swapper idles correctly -> it never
has cause to send `LSWPAGE`. The swapper is behaving properly at every step.

### Which makes the real question a different one, and it is upstream

> During `PLACE-DOMAIN`, what is supposed to make the domain request the swapper in the first place?

`PLACE` (`006B SGLOA`) records disc location metadata ONLY and transfers no content
([[nd500-domain-load-and-run-mechanism]]); the content arrives by demand paging. So the first access
to an unmapped page should fault, queue the process, and wake the swapper. **No fault is posted, and
§31's own instrument declared it could not see one because nothing outside segment 1 was translated.**

That points straight back at the question closed as #71 ("why does the ND-500 never raise a page fault
on this lane") - which should be re-opened rather than treated as settled, because the reason it
mattered has now changed.

**Do NOT conclude from this that the swapper or `LNEWSWAP` is broken.** Everything measured on the
swapper side is correct behaviour for an empty request list.

## 44. CORRECTION TO §43: an empty swap-wait FIFO is EXPECTED. The handover DID happen. `[V]` 2026-08-30

§43's chain opened with "nothing queued on the swap-wait FIFO -> `LNEWSWAP` finds no requesting
process". **`5ACTSWAPPER` in `MP-P2-N500.NPL` shows that link is wrong.** It has TWO paths:

```
144762   5ACTSWAPPER: A:=L=:"LREG"                  % Entry: X = message requiring service
144775          SWPWAIT; CALL WN5STATUS             % Mark that proc. is waiting for swapper
144777          X:=SWMSG; CALL RN5STATUS
145001          IF A=PSWWAIT THEN                   % Swapper free?
145006             AD:=CMSGTOSW; *AAX HSWPI; STDTX  %   hand the message straight over
145011             SWACTIVE; *AAX SWPFU-HSWPI; STATX
145054             X:=SWMSG; *AAX SWPST; STATX      %   save reason for activating swapper
145071             3MONCO; *MICFU@3 STATX
145073             CALL MCCO                        %   restart the swapper after the mon call
145111          ELSE
145112             % - Insert in Swap-wait-fifo     %   ONLY when the swapper is BUSY
```

**The FIFO is the BUSY path.** When the swapper is free (`PSWWAIT`) the message goes straight to it
and the FIFO is never touched. So `queued-on-swapwait-fifo hits=0` alongside
`HANDOVER-taken-SWACTIVE hits=1` is **exactly what a free swapper receiving one message looks like**
- it is correct behaviour, not an absence of requests. §43's first link is retracted.

### What that leaves, and it is a genuine tension

The handover HAPPENED, so **a message DID require service from the swapper**. SINTRAN wrote the
message pointer into `HSWPI` (§31 measured `swpInfo=0x00008E30`, non-zero), set `SWPFU := SWACTIVE`,
recorded the reason in `SWPST`, and restarted the swapper with `3MONCO` (§31: `micfu[... 24B:1 ...]`,
`restarts=1/1`).

And `LNEWSWAP` begins by reading exactly that field:

```
135470   LNEWSWAP:
135470          T:=5MBBANK; X:=SWMSG; *AAX HSWPI; LDDTX   % AD:=X.SWPINFO
135474          IF D><0 THEN                              % Any proc. currently served?
```

So `HSWPI` is non-zero and `LNEWSWAP` should take the "a process IS currently served" branch. **Yet
the swapper asked `LNEWSWAP` twice and parked.** Those two facts are in tension, and that tension -
not the FIFO, not `LSWPAGE` - is where #79 actually lives now.

Also carved and worth keeping: `SWPST` records WHY the swapper was activated, discriminating
`MICFU == 3SWMESS` (a message, reason taken from `SWFUN`) from everything else (a TRAP, reason taken
from `TRAPN` - the page-fault case). That field is the direct answer to "what woke the swapper" and
has never been read in a capture.

### Next

Read `SWPST` and `HSWPI` from a live capture at the moment of the handover, and follow `LNEWSWAP`
from `135470` to see which branch it takes with `HSWPI` non-zero. That is a targeted instrument on
two named fields, not another sweep.

### Housekeeping note on this document

This is the fifth correction tonight (§33, §36, §40, §41, §44). Every one moved the picture closer,
and every one came from reading a SOURCE - the microcode, the ROM carve, the emitting C#, the NPL -
rather than from another measurement. The measurements were mostly right; the readings of them were
what needed fixing.

## 45. #79 RESOLVED AS "NOT A DEFECT": the swapper subsystem is consistent end to end `[V]` 2026-08-30

`LNEWSWAP`'s tail, from `MP-P2-N500.NPL`:

```
135764   WHILE A><D                          % More messages in Swap-fifo?
136015      IF A/\160000><0 GO EMPTY         % Do not serve if pf
136027      IF A=SWPWAIT THEN
136037         CALL 5ACTSWAPPER
136044         BREG=:B; GO NXTMSG
136047      FI
136047   OD
136050   EMPTY: A:=0=:D; T:=5MBBANK
136053          X:="N500DF".X500DF; *AAX X5SWO; STDTX
136057          X:=SWMSG; *AAX HSWPI; STZTX  % HSWPI := 0
136062          *AAX SWPIN-HSWPI; STZTX
136065          GO NXTMSG
```

`LNEWSWAP` starts the message currently served (`HSWPI`), then walks the **Swap-FIFO** for the next
process. The FIFO is filled ONLY by `5ACTSWAPPER`'s busy path (§44). Nothing was ever queued there,
so `WHILE A><D` does not execute, control falls to `EMPTY`, which clears `X5SWO`, `HSWPI` and
`SWPIN` and returns.

**Put end to end, every step of the measured run is the designed behaviour:**

| measured (§31) | why it is correct |
|---|---|
| `HANDOVER-taken-SWACTIVE` 1, `queued-on-swapwait-fifo` 0 | swapper was FREE, so the direct path ran and the FIFO is untouched (§44) |
| `restarts=1/1` (`Seen == Taken`) | the `3MONCO` restart at `145071`-`145073` was forwarded, no MON gap |
| `swpfu[LNEWSWAP:2]`, no `LSWPAGE` | the swapper asked for the next process; the FIFO was empty, so `EMPTY` answered and it had no page to fetch |
| `PC=0x08008255 stopMode=WAIT` | the designed idle after `EMPTY` |
| `page-fault records posted: 0` | nothing outside segment 1 was ever translated, because no domain ever ran |

**Nothing in the swapper, `LNEWSWAP`, `5ACTSWAPPER` or the FIFO is faulty.** The subsystem correctly
served exactly one request and then correctly found no more. #79 as originally posed - and as posed
in §43 and §44 - has no defect behind it.

One honest caveat: §31's `swpInfo=0x00008E30` comes from the harness's `LastStartSwpInfo`, which is a
value recorded at start time, not a live read of `HSWPI`. Under this account `EMPTY` will have zeroed
the live field. The two are not in conflict, but the probe does NOT confirm the live value either -
do not cite it as evidence that `HSWPI` stayed non-zero.

### So the blocker moves upstream, and it is a different question

There is only ONE request because the domain never runs, and the domain never runs because
**`place-domain` itself STALLS** - §31 and §38 both measured `place-domain=STALL run=STALL`, with the
console stopping after `> Loading Swapper` and never printing `> Allocating memory`.

**THE LIVE QUESTION IS NOW: what does `PLACE-DOMAIN` do between `> Loading Swapper` and
`> Allocating memory`, and where does it stop?** That is a `nd-500-mon` / `FUNCS` path question
(`006B SGLOA`, bracketed by `055B SPLAC` / `056B EPLAC`), not a swapper question.

Everything above is MACRO-round evidence; per §38 it cannot be confirmed on the oracle round until
#78 clears.

## 46. THERE IS A RECORDED WORKING INSTANCE, and every stall tonight was measured at SCALE 1 `[V]` 2026-08-30

`OCTOBUS-SWAPPER-HANDOFF-2026-07-25.md` section 7.7.9, "THE SWAPPER WORKS (2026-07-29)", console
unedited:

```
ND-5000: status
> Loading Control Store
> Loading Swapper
ZERO 0 / CARRY 0 / SIGN 0 / FLAG 0 / OVERFLOW 0

ND-5000: start-swapper
> Allocating memory - 7110B pages
ND-5000: who-is-on
===>     1 used by SYSTEM           on terminal    1    cpu  1
```

`OUTCOME: ENTER=OK login=OK nd-500=OK status=OK start-swapper=OK list=OK stop-system=STALL`

### Two corrections this forces

**1. `> Allocating memory` belongs to `START-SWAPPER`, not to `PLACE-DOMAIN`.** §45 (and the harness
comment at `Nd100SintranNd5000OctobusBootHarnessTests.cs:2736`) framed it as part of place-domain.
The working transcript splits it: `status` prints the two Loading lines, `start-swapper` prints
`> Allocating memory`. So the SHORT BRING-UP never running start-swapper is a sufficient reason for
it never to appear there - §45's "place-domain stalls before Allocating memory" is the wrong shape.

**2. That same section says, in bold, what tonight repeated:**

> The last two "STALL"s were the harness, not the machine ... Re-running with
> `RETROCORE_HARNESS_TIMEOUT_SCALE=5` turned both OK with no code change - that is the proof, not an
> argument ... every harness timeout is HOST WALL-CLOCK, so a STALL conflates "never happened" with
> "not within N host seconds". A false STALL is first-class misleading evidence.

**Every ladder and short-bring-up run tonight was at SCALE 1.** Only the two real-ACCP rounds got
scale 8. So `status=STALL`, `place-domain=STALL`, `run=STALL`, `list=STALL` are all unproven.

### The measured difference against the working baseline

Full ladder tonight (`ladder2.log`, scale 1):
`OUTCOME: ... status=STALL start-swapper=[prompt=OK started=1] list=STALL stop-system=STALL`,
`Allocating memory` count = **0**, and after start-swapper:
`startSeen=0 startMicfu=0B startTaken=False swpfu[(none)] restarts=0/0 micfu[1B:27 12B:1 30B:12 31B:13]`
- **no 23B, no 24B: `start-swapper` produced no swapper activity at all.**

Short bring-up tonight (§31, scale 1), which does NOT run start-swapper:
`startSeen=1 startMicfu=23B startTaken=True swpfu[LNEWSWAP:2] micfu[1B:49 12B:1 23B:1 24B:1 31B:13]`
- swapper activity DID happen, driven by place-domain's automatic swapper load.

The run WITH `start-swapper` got no swapper activity; the run WITHOUT it got some. That inversion is
the real signal, and in the working baseline `status` COMPLETED (it printed the ZERO/CARRY/SIGN line)
whereas tonight it stalls after `> Loading Swapper`.

### Running now

Full ladder and short bring-up, both macro round, both at `RETROCORE_HARNESS_TIMEOUT_SCALE=8`
(`ladder-s8.log`, `mudom-s8.log`). If the stalls clear, tonight's #79 chain was built on false STALLs
and §31/§43/§44/§45 all need re-reading against the new capture. **That possibility is the reason to
run it before doing anything else on this lane.**

---

## 34. #78 REFRAMED: it is not one hole, it is a FEATURE SET the engine lacks `[V]` 2026-08-30

### 34a. What was actually run

Implemented `TESTOBJ=29` (flippable, env-gated) and re-ran `Nd5000RealCpuStartTests`. The blocker
**moved**, four times, each time to a different unimplemented feature — and **every one of them is a
field of the SAME microword, the ACCP firmware's own word at `0o0`**:

| # | stop message | field of word `0o0` |
|---|---|---|
| 1 | `Test condition TESTOBJ=29 not implemented yet` | `TESTOBJ=29` |
| 2 | `Operand select A,IDU,DPA not implemented yet` | `A_OP=166` |
| 3 | `Status operation STATUS=11 not implemented yet` | `STATUS=11` |
| 4 | `Address B operand AB,CMBRET not implemented yet` | `AB=8` |

And the word sets more that were never reached: `AA,DISP`, `SCAL=IX*8`, `MEMORY=915`, `ABR,NPCREL`,
`TBC,PREL`, `EA2SAVE`, `DEST=D,SPEC,CC`, `ALU_TRUE=21`/`ALU_FALSE=36`, `AAP_CTRL=163`.

**So #78 is not "one unimplemented condition". `CpuND5000` cannot execute the ACCP firmware's
selftest microcode at all** — the gap is a feature set, and one word exercises at least four holes.

### 34b. THE METHOD LIMIT — why I stopped, and why the sequence above is NOT a work list

**The blocker sequence is only trustworthy as far as blocker #1.** Each fill was a GUESS
(`TESTOBJ=29` polarity is undocumented and ungraded; the DPA freshness question is open; `STATUS=11`
was made a conservative no-op). A wrong guess sends execution down a path the real machine never
takes, so blockers #2-#4 may belong to that wrong path. **Stacking guesses to enumerate is
self-invalidating**, and continuing would have produced a longer list with less meaning.

All three speculative edits are **REVERTED**; the tree is clean and `TESTOBJ=29` throws again as
before. Nothing unvalidated was committed.

### 34c. Two of the four are UNDOCUMENTED HOLES, and neither can be graded the usual way

 - **`TESTOBJ=29`** — `mnemonics.md` and ND-05.022.1 App. A both run `28 COND,LCZ` -> `32 COND,ENTER`.
 - **`STATUS=11`** — the same tables run `9 ST,SAVM` -> `12 ST,ACCA`; 10 and 11 have no mnemonic.

A sweep of all 16384 words of `MICRO-5800-B30.DATA` finds **TESTOBJ=29 in zero of them**. Both values
exist only in microwords the ACCP firmware WRITES ITSELF. **So the ~11k-vector differential oracle
that pinned `TESTOBJ=38` cannot reach either, and its silence about them carries no information**
(taxonomy #8, a structurally blind instrument).

Tempting pattern, and it does NOT hold: `SAVA 4 -> ACCA 12` and `SAVF 6 -> ACCF 14` are both `+8`,
which would make `11 -> 3 K,1IFZ`. But `SAVM 9 -> ACCM 13` is `+4`. The rule breaks; deriving 11
from it would be invention.

### 34d. The one fill that IS defensible, and why

`A,IDU,DPA` (166) is *not* a hole — `mnemonics.md:411` documents it as *"A-BUS IS DPA-BUS-REGISTER"*,
and `D,DAC,DPA` (232) is *"DESTINATION IS DAC DPA-REGISTER"*. **One physical DPA**, written via the
DAC and presented on the A-bus by the IDU, so both map to `regs.Dpa`. Giving the read its own
storage would be the "one piece of hardware, two models" defect that the octobus station's duplicate
control store already cost this project once (§ the `_controlStore` / `_realControlStore` split).

Residual `[D]`: `CpuND5000` keeps a one-word-delayed DPA snapshot (`_dpaForEa`) because address
arithmetic must see the PREVIOUS word's DPA. Whether an A-bus read sees fresh or delayed is
**unverified**.

### 34e. What to do instead of guessing

The static decode is the trustworthy instrument here — it needs no execution and therefore cannot be
invalidated by a wrong fill. **Decode every microword the firmware writes (`0o0`, `0o1`,
`0o37760..4` — all in `tmp/accp-cs.log`), list every field value each one uses, and diff that set
against what `CpuND5000` implements.** That yields the complete, guess-free gap list in one pass.

Then the two undocumented holes need a real source, not a pattern: the ND-5000 hardware description
(`ND-05.020.01`) rather than the microprogram guide's mnemonic table, since these values are used by
hardware-level firmware rather than by the macro-instruction store.

## 47. QUANTITATIVE PROOF that the firmware's word `0o0` is noise - stop implementing to it `[V]` 2026-08-30

Guess-free instrument (`fielddiff.py`): for every field, the set of values used anywhere in the
16384-word B30 image, versus the values the ACCP firmware's own written words use. Anything the
firmware uses that B30 never uses is, by construction, invisible to the differential oracle.

**Word `0o0`, ENUM fields only (addresses and immediates excluded as meaningless here):**

| field | value | in B30? |
|---|---|---|
| `ALU_TRUE` | 21 | **never** |
| `ALU_FALSE` | 36 | **never** |
| `AAP_CTRL` | 163 | **never** |
| `A_OP` | 166 (`A,IDU,DPA`) | **never** |
| `STATUS` | 11 | **never** |
| `TESTOBJ` | 29 | **never** |
| ~~`MEMORY`~~ | ~~915~~ | **WRONG - my instrument's error, see section 48** |

**SIX of the seven enum fields take a value the real microcode never uses ONCE in 16384 words.**
(Was written as seven of seven; the `MEMORY` row is my own decoding error - see section 48. The
conclusion is unaffected and was independently confirmed.)

A genuine microword reuses the microcode's own vocabulary. A word in which every single field is an
unprecedented value is not a microword - it is a random bit pattern. This is the fifth independent
confirmation of §33, and the first quantitative one.

### What it settles

**The four-blocker chase is over.** Implementing `TESTOBJ=29`, then `A,IDU,DPA`, then `STATUS=11`,
then `AB,CMBRET` - each revealed by filling the previous - was walking a random pattern, and each
fill was a guess that could send execution down a path the real machine never takes. The walk has no
end and every step looks like progress. **Do not resume it, and do not "complete the gap list" by
decoding these words: there is no gap, the input is noise.**

### What #78 is actually left with

The ACCP selftest fails because **our engine THROWS on unknown field values**. Real hardware does not
refuse a bit pattern - it does *something* with it, harmlessly, and the firmware's start/stop test
then just checks that the CSA advanced. So the honest statement is:

> `CpuND5000` treats "field value I do not model" as a fatal refusal. For executing REAL microcode
> that is correct and valuable - it is how the engine stays honest. For executing an arbitrary
> pattern it is wrong, and it is why the card's selftest can never pass against us.

**That is an ENGINE ERROR-POLICY decision, not a carve** - the same thing §33 named as LEAD 2. It
needs Ronny, because "make the engine tolerate unknown fields" trades away the property that has
caught real bugs all year. It should NOT be decided by whoever happens to be chasing the CS load.

And it may not even be on the path: the CS-load failure on `hw-cpu` is a SINTRAN `LOAD-CONTROL-STORE`
read-back verify (§39/§40), which involves no microword execution at all. The selftest and the CS
load are two different failures that have been read as one.

---

## 35. THE CATALOG REFUTES §34's FRAMING: the requirement is TOLERANCE, not semantics `[V]` 2026-08-30

A read-only catalog of every unimplemented microword feature in `CpuND5000`, cross-referenced
against what the ACCP firmware's own words actually use, plus a B30 occurrence sweep per value.

### 35a. Word `0o0` is a TEST PATTERN, not microcode

§34 treated the four blockers in word `0o0` as a feature gap to implement. That framing is wrong.

 - The firmware's own console prints that word as a **test vector** (`accp-cs.log:53`):
   `Control Store sample test ab failed / Result: 5640H 51AFH 4C92H BB59H ... /
   Expected: 7698H B027H 0AAAH 2C91H 0D8CH F58BH AFBEH 6195H`, immediately followed by
   `Start/stop microprogram test abc failed at CSA: 00FFH / MIR 5640H 51AF...`.
 - The word simultaneously takes **five field values that occur ZERO times in all 16384 B30 words**
   (TESTOBJ 29, STATUS 11, A_OP 166, AAP TYPE 5) — **including reserved bit 36 = 1, which is 0 in
   every single real microword.** Hand-written microcode does not look like that.

**So the requirement is that the CPU must TOLERATE arbitrary field values and still start, stop and
read MIR back — NOT that these values must be given semantics.** Inventing meanings for TESTOBJ 29
and STATUS 11 would be solving a problem that does not exist, and both are undocumented holes that
cannot be derived anyway.

**`TESTOBJ=29` is the ONLY blocker the firmware has ACTUALLY hit** — all four starts stop there, and
word `0o37760` (a plain jump to 0) **executed correctly**. A_OP 166 / STATUS 11 / AB 8 are only what
the same word would hit next; they appeared solely because §34 filled the earlier ones with guesses.
That is the §34b method limit confirmed from the other side.

### 35b. The two upstream bugs that make the verdict unmeasurable

Known bugs before features — the `0x001144F0` word[6]==`0x0100` gate is unreachable until both clear:

 1. **`Loading control store with selftests...` produces ZERO writes.** The log's own summary reads
    `microwords written: 8 addresses [0o0 0o1 0o37760 0o37761 0o37762 0o37763 0o37764]`. Every later
    test — ALU verify, Register test a-d, Instruction Cache, Data Cache — reports
    `Result: 87654321H`, the firmware's own sentinel, i.e. **no answer at all**. The bulk selftest
    microcode never reaches the emulated control store.
 2. **`Control Store sample test ab failed`.** Wrote `5640 51AF 4C92 BB59 8BB4 0393 5426 50DD`,
    expected `7698 B027 0AAA 2C91 0D8C F58B AFBE 6195` on read-back — the CS write/read-back path
    disagrees **before any word executes**. **The clue that makes this tractable: the manual
    `LOAD-CONTROL-STORE 100 1122 ...` round-trip in the SAME log reads back CORRECTLY.** Two paths,
    one works, one does not. The difference between them is the bug.

### 35c. Two measurement corrections worth keeping

 - **`microcode-5000-def.json` has a field-definition defect.** It declares `MEMORY` as bits 41-32
   (10 bits) while `src/Microword.cs:305` shows the real encoding is
   **`MemOp = (bit41 << 3) | bits34-32`**, a 4-bit code; bits 40/39-38/37/36/35 are separate fields
   (AD_ARTI / EA_SAVE / MEMOT / reserved / ADACT) that the 10-bit span swallows. So the alarming
   "MEMORY=915" is `MemOp = 11 = RD,PX`, **which is implemented**. Not a 1009-value hole.
 - **"532 B30 words use `ORA,ALTEN`" is an ALIASING ARTEFACT.** Bits 15-0 are shared with
   `SARG`/`MARG`/`LARG`, so a naive sweep counts constants as field values. Restricted to words that
   actually consume it (`OR_ENABLE=1`, `A_OP=63`): 601 words, distribution `{0: 19, 1: 582}` —
   **`ALTEN` occurs ZERO times**, which independently confirms `Conditions.cs:104`'s claim that ALT
   addressing is absent from this microcode generation.
   **General lesson: never sweep a field whose bits are aliased by an immediate without first
   restricting to the words that consume it.** This is the §22 shape again — an instrument's own
   arithmetic producing a confident wrong number.

### 35d. Real gaps, correctly deprioritised

Documented, oracle-reachable (B30 count > 0), and **not** firmware blockers — so they are ordinary
work, not on the critical path: TESTOBJ 24/48/49; Q_REG 2/6/7; ABR 1 `ABR,NEXT` (20 words) and 3
`ABR,NEXTL` (6); B_OP 26; AB 12-15 (4 words each, all in one block at `0o3014`-`0o3071`); several
`A,SPEC,*` singles.

Two structural absences worth recording separately: **`TIMING` is decoded at `Microword.cs:279` and
read NOWHERE** — cycle time is not modelled at all; and **`TBC` has no dispatch** — only values 1
and 3 act (`CpuND5000.cs:1654-1659`), 0/2/4/6/7 silently do nothing, with no branch-cache model.

## 48. CORRECTION to §47, and a REUSABLE GUARD for every microword decode `[V]` 2026-08-30

§47's table listed `MEMORY=915` as a value with no precedent in B30. **That was my instrument, not
the machine** - the third time tonight a probe's own arithmetic produced a confident wrong number
(cf. §22's `5MBBANK` shift and the `X5ACT` double-count).

`microcode-5000-def.json` declares `MEMORY` as **bits 41..32 - a ten-bit span - while also declaring
`width: 4`.** The two contradict each other. My decoder trusted the span, read ten bits, and got 915.
The real encoding is `MemOp = (bit41 << 3) | bits34..32` = **11 = `RD,PX`, which IS implemented.**

§47's table is annotated in place and its count corrected from seven of seven to **six of six**. The
conclusion is untouched, and was independently confirmed from the other direction: word `0o0` takes
five field values occurring zero times in all 16384 real B30 words, including a reserved bit that is
0 in every real microword.

### The guard, and it is one line

**Any field where `highBit - lowBit + 1 != width` in `microcode-5000-def.json` has an UNRELIABLE
span - do not decode it by span.** Swept the whole file:

```
MEMORY: bits 41..32 span=10 but width=4
total 1
```

**`MEMORY` is the ONLY one.** Every other field and subfield in the definition is self-consistent, so
every other decode in this document - including §75's `TESTF`/`TESTD`/`TESTFD` carve, which used
ALU_TRUE, ALU_FALSE, COND_ALU, DATATYPE, A_OP, B_OP, DEST, STATUS, TESTOBJ, ABS_ADDR and SEQ - is
unaffected. (The `TESTF` stub decode did print `MEMORY=527`; that value is unreliable and nothing was
concluded from it.)

Add this check to any future decoder before trusting a field: it costs one comparison and it caught a
published number tonight.

### Also corrected, from the same catalog

"532 words use `ORA,ALTEN`" was **bit-aliasing** - `ORCON`'s bits 15..0 are shared with `SARG` and
`MARG`, so counting `ORCON` values across all words counts immediates as opcodes. Restricted to words
that actually consume `ORCON`: **zero**. Same shape as the `MEMORY` error and as §22.

### And the sharpest lead of the night, from the same source

`LOAD-CONTROL-STORE` typed at the console round-trips CORRECTLY in the very same log where the
selftest's control-store path does not. **Two paths through the same link, one works and one does
not - that difference is the bug**, and it needs no theory about serial mechanisms or field
semantics. Start there, not at the field gap.

## 49. THE WORKING PATH IS DEGENERATE - it cannot validate the rule the failing path depends on `[V]` 2026-08-30

§48 named the sharpest lead: `LOAD-CONTROL-STORE` typed at the console round-trips correctly in the
same log where the selftest's control-store path does not. Diffed the two, from `accp-cs.log`:

**WORKS - console `LOAD-CONTROL-STORE 100 1122 ... F001`:**
```
SHIFT      0100
ADDR-LATCH 0100 halfwords=0        <- address phase A
SHIFT      1122 3344 5566 7788 99AA BBCC DDEE F001
ADDR-LATCH 3001 halfwords=7        <- junk latch (F001 & 0x3FFF)
SHIFT      0100
ADDR-LATCH 0100 halfwords=0        <- address phase B - SAME ADDRESS
COMMIT     addr=0x0100  112233445566778899AABBCCDDEEF001     -> reply "- OK -"
```

**FAILS - selftest, the address-0 window:**
```
ADDR-LATCH 3FFB halfwords=0        <- address phase A
SHIFT      5640 51AF 4C92 BB59 8BB4 0393 5426 50DD
ADDR-LATCH 10DD halfwords=7        <- junk latch (50DD & 0x3FFF)
SHIFT      0000
ADDR-LATCH 0000 halfwords=0        <- address phase B - DIFFERENT ADDRESS
COMMIT     addr=0x0000  564051AF4C92BB598BB40393542650DD
```

### The structural difference, and it is the whole point

Both paths have the SAME shape: `[address phase A] [8 data halfwords] [junk latch] [address phase B]
[COMMIT]`. There are two possible pairing rules:

 - **R1** - the commit binds to the LAST address phase (B). This is what the code implements.
 - **R2** - the commit binds to the address phase that PRECEDED the data (A).

**In the working path A == B == `0x0100`, so R1 and R2 give the identical answer.** The console
round-trip therefore CANNOT distinguish them, and its `- OK -` is not evidence for either rule. **It
has never validated the pairing rule at all.**

**In the selftest path A = `0x3FFB` and B = `0x0000`.** R1 stores the word at 0; R2 stores it at
`0x3FFB`. This is the ONLY observed case that discriminates, and it is exactly the case that fails.

### What this does and does not establish

ESTABLISHED `[V]`: the one path that works is degenerate for this question, so "the console path
round-trips fine" carries NO information about the rule the failing path depends on. That retires the
"two paths, one works, one doesn't, so compare them" framing as a route to the answer - the working
path has nothing to say.

NOT ESTABLISHED: that R2 is correct. §40 showed the code reasons explicitly about the address being
written ninth (`_addressIsNewestInRing`), so R1 is a considered choice, not an oversight. **Do not
flip it on the strength of this section** - that would be the same "obvious reading" mistake §33 and
§39 already produced.

### What would settle it, and it is small

The ACCP ROM's `0x741E` write path calls the address phase (`0x76E6`) and the shift (`0x7776`) in a
fixed order. Read WHICH of the two `0x3010` latches the `0x0018` at `0x7446` is meant to consume -
that is a handful of instructions and it decides R1 vs R2 outright. `HANDOFF-ACCP-CONTROL-STORE-
MODEL-CORRECTED-2026-08-04.md` already prints the address phase; the caller's ORDER is what is needed.

## 50. R1 vs R2 SETTLED FROM THE ROM: the code's pairing is CORRECT, and a COMMIT is MISSING `[V]`/`[D]` 2026-08-30

§49 said the working path cannot decide the pairing rule and named the small thing that can: the
order of calls inside the `0x741E` write path. Dumped the ROM bytes (`romdump.py` over
`AccpRom.cs`), window `0x7420`-`0x7458`:

```
007420: 4E56 FFE8            link   A6,#-24
007428: 3D40 0014            move.w D0,(0x14,A6)        ; the ADDRESS parameter
00742C: 426E 0016            clr.w  (0x16,A6)
007430: 4EB9 0000 76E6       jsr    $76E6               ; <- ADDRESS PHASE
007436: 08F9 0002 0011 44EE  bset   #2,$001144EE        ; <- GATE ON (bit 2 = 0x04)
00743E: 13F9 0011 44EE 0033 0000   move.b $001144EE,$00330000
007448: 33FC 0018 0022 0000  move.w #$0018,$00220000    ; <- PERFORM
007450: 0839 0000 0066 0000  btst   #0,$00660000        ; <- status test
```

Opcodes `4EB9` (jsr abs.l), `33FC` (move.w #imm,abs.l), `08F9` (bset abs.l) and `0839` (btst abs.l)
are unambiguous, so the CALL ORDER is `[V]`; the operand framing between them is `[D]`.

**There is NO `jsr $7776` between the address phase and the perform.** The shift-out is not called
here at all - the 128 bits must already have been shifted BEFORE this routine ran. (The `jsr $7776`
in the earlier carve belongs to `0x773A`, the MIR path, which ends in `0x2018`, not `0x0018`.)

So the write sequence is: **data shifted -> address phase -> gate -> perform.** The address phase
that binds to a commit is the one AFTER the data. **That is R1 - exactly what the code implements.
R2 is eliminated, and `Nd5000ControlStoreLink`'s pairing is CORRECT.** Do not change it.

Mapping that onto the address-0 window confirms it: `SHIFT 0000 / ADDR-LATCH 0000` is the `0x76E6`
address phase, the `COMMIT` is the `0x0018`, and the eight halfwords before them are the data.
**Address 0 legitimately receives `5640 51AF ...`.**

### And that exposes the actual defect - a MISSING commit

Re-read the same window with the rule now known:

```
ADDR-LATCH 3FF0            <- address phase (for an earlier group)
SHIFT 0718 E6A7 ... 0415   <- group 1
ADDR-LATCH 0415 hw=7       <- junk latch
SHIFT 3FFB
ADDR-LATCH 3FFB hw=0       <- ADDRESS PHASE. Under R1 this binds to group 1.
                              ** NO COMMIT APPEARS HERE **
SHIFT 5640 ... 50DD        <- group 2
ADDR-LATCH 10DD hw=7       <- junk latch
SHIFT 0000
ADDR-LATCH 0000 hw=0       <- address phase, binds to group 2
COMMIT addr=0x0000 564051AF...   <- the only commit
```

**Group 1 had its address phase and never committed.** That is not a pairing error - it is a
`0x0018` we never saw. This is the same defect as P1 (#78, "the bulk selftest microcode never
reaches the control store - only 8 pattern addresses arrive"): **writes are being DROPPED, not
misplaced.**

### Where to look, and it is narrow

`WriteCommand` dispatches on the exact word: `0x0018` commits, `0x2018` loads the MIR, `0x0017` arms,
`0x3010` latches an address, `0x2010`/`0x2011` drive read-back, and **`default:` is "not modelled -
and deliberately not guessed at"**. If the firmware completes most writes with a word that falls into
that `default`, every one of them is silently dropped and the trace shows exactly what it shows here.
**Instrument the `default` arm: count and log the unrecognised command words.** That is a few lines,
it cannot be wrong, and it turns "writes are dropped" into "writes are completed by word 0xNNNN".

## 51. THE DROPPED WRITES HAVE NAMES: 8 unmodelled command words, three of them exactly 89 times `[V]` 2026-08-30

§50 said instrument the `default:` arm of `WriteCommand` and turn "writes are dropped" into "writes
are completed by 0xNNNN". Done - a counter plus a first-sighting-only trace line, bounded by the
number of DISTINCT words so it cannot bury the signal in a 233k-entry trace. Ran
`Nd5000RealCpuStartTests`; log `unkcmd.log`.

```
microwords written: 8 addresses [ 0o0 0o1 0o37760 0o37761 0o37762 0o37763 0o37764 ]
unknown command words: 21263 total, 8 distinct
    0x0006 x20964      <- dominates
    0x300F x89   \
    0x4016 x89    >    <- IDENTICAL counts
    0x8013 x89   /
    0x0005 x20
    0x0007 x4
    0x0001 x5
    0x001A x3
```

**21,263 writes to the command port match no modelled command and are silently discarded.**

### The two things worth acting on

**1. `0x300F` / `0x4016` / `0x8013` occur EXACTLY 89 times each.** Three distinct words with
identical counts is a three-word SEQUENCE repeated 89 times - one per operation, 89 operations, none
of them modelled. Against `microwords written: 8`, that is the shape of the missing bulk load.
`0x8013` is independently interesting: the octobus skill records `0x0F` / `0x8013` as **the MFbus
memory transaction**, so this trio may be a memory-transaction path rather than a control-store one.

**2. `0x0006` at 20,964 is not the modelled clock.** `ClockA = 0x0010` and `ClockB = 0x000F`
(`Nd5000ControlStoreLink.cs:204-207`); `0x0006` is neither, so a fifth of a boot's traffic on this
port is an unrecognised strobe. If it is a clock phase the link does not know about, every shift it
should have driven is uncounted.

`0x0005` and `0x0007` are ACON codes 5 (`RAIBF`) and 7 (`MASKAIBF`) in the octobus skill's table -
worth checking whether the same numbering applies on this port before assuming it does.

### Status of the claim

`[V]` that these words arrive and are discarded - it is a direct count with a denominator.
`[D]` that they are what carries the missing writes. **Do not "implement" any of them yet**: the
89-triple could equally be a path that legitimately does not touch the control store, and §33/§39/§47
are three separate occasions tonight where the obvious reading of a trace was wrong.

**NEXT, and it is small:** find `0x300F`, `0x4016`, `0x8013` and `0x0006` in the ACCP ROM - which
routine writes each, and in what order. That says what the sequence IS before anything is modelled,
and it is the same method that settled R1 vs R2 in §50.

Instrumentation added (uncommitted): `UnknownCommands` + `UnknownCommandCounts` on
`Nd5000ControlStoreLink`, reported by `Nd5000RealCpuStartTests`. Worth keeping either way - a link
that silently discards a fifth of its input traffic should always have said so.

## 52. THE LINK MODELS ONE PROTOCOL; THE ROM SPEAKS AT LEAST THREE `[V]` 2026-08-30

Census of every `move.w #imm,$00220000` in the ACCP ROM (`cmdsites.py` - opcode `33FC`, immediate,
then the literal port address, so there is nothing to interpret). **24 distinct command words:**

```
0001 x9   0002 x1   0005 x4   0006 x2   0007 x5   0008 x3   000F x4   0010 x2
0015 x1   0017 x1   0018 x2   001A x1   2010 x1   2011 x2   2018 x1   300F x4
3010 x2   4009 x1   400A x1   400C x1   400D x1   4016 x1   8013 x2
```

`Nd5000ControlStoreLink` models eight of these (`0x0010`/`0x000F` clock, `0x0018`, `0x2010`,
`0x2011`, `0x2018`, `0x0017`, `0x3010`, `0x0015`). **Sixteen it does not.**

### `0x0006` sits INSIDE the address phase, between the latch and the clock `[V]`

Each `move.w #imm,abs.l` is 8 bytes, so consecutive sites 8 apart are consecutive instructions. Two
near-identical routines:

```
0073CC: move.w #$3010,$220000      007402: move.w #$3010,$220000
0073D4: move.w #$0006,$220000      00740A: move.w #$0006,$220000
0073DC: move.w #$0010,$220000      007412: move.w #$0010,$220000
```

`0x3010` is the ADDRESS LATCH and `0x0010` is CLOCK A - both modelled. **`0x0006` is written between
them and is not.** That is why it dominates the runtime census at **20,964** occurrences: it is part
of a sequence the firmware runs constantly, and the link drops it every time.

### A whole second command region the link never sees `[V]`

`0x70D0`-`0x7260` carries `300F`, `400A`, `400C`, `400D`, `4009`, `4016`, `8013` and one `2011` -
seven of them unmodelled, in a band well away from the write path (`0x7420`) and the address phase
(`0x76E6`). At runtime `300F`/`4016`/`8013` each fire **exactly 89 times**, i.e. 89 passes through
this region, against `microwords written: 8`.

### What this settles

**The link implements ONE write protocol and ONE read-back protocol. The ROM contains at least
three.** "The bulk selftest microcode never reaches the control store" (#78/P1) needs no further
theory: the firmware is driving a path the link does not implement, and the link discards it in
silence. Same for the missing commit in §50.

`[V]`: the words exist in the ROM, at those addresses, in that order, and arrive at runtime in those
counts. `[D]`: that the `0x70D0` band is the bulk loader specifically.

**NEXT:** disassemble `0x70D0`-`0x7260` properly (it is ~400 bytes) and name the routine. The
`0x8013` there matches the octobus skill's note that `0x0F`/`0x8013` is **the MFbus memory
transaction** - if that holds, this band is a memory-transaction path and the bulk load moves through
MFbus rather than the shift port, which would explain every symptom at once. **Check it; do not
assume it** - the skill's numbering is for a different port.

## 53. `0x550000` IS SHARED: microword staging AND MF-bus data-high `[V]` - plus an open conflict 2026-08-30

§52 guessed the `0x70D0` band might be MF-bus. **It is already carved** -
`ACCP-COMPLETE-REFERENCE.md` §2.4 documents the whole thing, so §52's "next: disassemble it" was
work already done:

```
0x00220000  COMMAND/PARAMETER port. High nibble selects a function, low byte carries the value.
            0x300F open/select, 0x400A and 0x400C sub-functions, 0x000F strobe closing each triple.
0x00440000  DATA, LOW half of a 32-bit value
0x00550000  DATA, HIGH half   ("the code does swap D0 between the two writes")
0x00660001  STATUS, bit 4 = transaction complete
```

### THE FINDING: one port, two meanings, and the link only knows one `[V]`

`AccpMachine.cs:889-890` maps BOTH halves to the control-store link:

```csharp
new Nd5000LinkWindow(controlStoreLink, Nd5000WindowRole.DataLow,  0x00440000),
new Nd5000LinkWindow(controlStoreLink, Nd5000WindowRole.DataHigh, 0x00550000)
```

and `Nd5000LinkWindow.cs:158` routes every DataHigh write to `_link.WriteData(word)` - the
microword staging path. **But `0x550000` is ALSO the MF-bus DATA-HIGH register.** So every MF-bus
data word the firmware writes is staged by the control-store link as if it were a microword halfword.

Scale, from the same reference: MF-bus transactions run **20,968 times per boot, 64 clock pairs
each** - and clock pairs are exactly what advances the link's shift ring. This is not a trickle.

**That is a sufficient mechanism for #84**: address 0's committed word can be assembled from MF-bus
traffic rather than the intended microword, which is precisely "wrote `5640 51AF ...`, expected
`7698 B027 ...`" with no transform needed.

### Cross-check that lands, and one that does not `[V]`

My §51 runtime census against the reference's per-boot table:

| word | mine | reference |
|---|---|---|
| `0x0005` | 20 | 20 |
| `0x0007` | 4 | 4 |
| `0x0001` | 5 | 5 |
| `0x001A` | 3 | 3 |
| `0x300F` / `0x4016` / `0x8013` | **89 each** | **1 each** |

**Four match exactly; three are 89x.** That is not a run-length difference - a longer run would
scale everything. Something makes the MF-bus open/select sequence repeat. The reference notes the
completion bit is "polled in a software countdown loop; exhausting it prints the timeout", and the
console does print `MFbus controller has incorrect CPU model setting` - flagged as unexplained in
§32 and now plausibly related. **`[D]`, not established.**

I checked the obvious cause and it is NOT it: `0x660001` bit 0 (MF-bus command done) IS modelled and
deliberately held SET (`AccpMachine.cs:971-972`). So "we never signal completion, so it retries" is
refuted before it was written up.

### THE OPEN CONFLICT - do not resolve it by picking a side

`Nd5000ControlStoreLink`'s `CommandOperation` case says `0x2018` is **the MIR load**, with a comment
recording that treating it as a control-store write was a real bug producing a retracted "281
microwords loaded" claim. `ACCP-COMPLETE-REFERENCE.md` says the `0x2018`-closed 64-pair transactions
are **MF-bus transactions**, 20,968 of them.

Both cannot be the whole truth about the same 20,968 events. Whoever takes this next must settle
which - from the ROM, not from either document - **before** changing how `0x550000` writes are
routed. Getting it wrong re-introduces a bug that has already been fixed once.

## 54. THE COMMAND CENSUS: `0x0018` fires EIGHT times, and that reframes P1 `[V]` 2026-08-30

§53 left a conflict between two tables of `ACCP-COMPLETE-REFERENCE.md` (`0x2018` as 4 per boot vs as
the closer of 20,968 transactions) and the link's own model. Rather than choose, I counted every
write to `0x220000`. Extended the instrument from unknown-only to ALL command words; log
`cmdcensus.log`:

```
0x0010 x1756035   clock A            0x2011 x2320    read-back word
0x000F x1714185   clock B            0x2010 x290     verify start
0x3010 x  41939   address latch      0x2018 x 284    "MIR load" / "MF-bus closer"
0x0015 x  20979   strobe             0x8013 x  89    0x300F x89   0x4016 x89
0x0006 x  20964   *** UNMODELLED ***  0x0005 x20  0x0018 x8  0x0001 x5
                                      0x0007 x4   0x0017 x4   0x001A x3
```

### Three results, all direct counts

**1. `0x2018` fires 284 times. BOTH reference figures are wrong** - not 4, not 20,968. The ~20,970
events that table meant are far better matched by `0x0015` (20,979) and `0x0006` (20,964). So the
reference mis-attributes the closer of its own dominant transaction. Measured, not argued.

**2. The dominant operation is `0x3010` x2, `0x0006`, `0x0015`** - note `0x3010` at 41,939 is almost
exactly TWICE 20,970, which matches the trace shape seen throughout (an address phase AND a junk
latch per operation, §39/§50). **`0x0006` is the one member of that quartet the link does not model.**

**3. `0x0018` fires EXACTLY 8 times - and exactly 8 microwords are written.**
```
0x0018 x8        microwords written: 8 addresses [ 0o0 0o1 0o37760 0o37761 0o37762 0o37763 0o37764 ]
```
**The control-store write path is not dropping anything. It runs eight times and commits eight
words.** §50's "a commit is MISSING" was me reading a gap between two address phases as a lost
commit; the count says every `0x0018` the firmware issued was honoured.

### So P1 (#78) is REFRAMED, for the third time and now on a count

"The bulk selftest microcode never reaches the control store" is TRUE, but **not because we drop
writes**. The firmware never issues `0x0018` for it. Whatever loads the bulk selftest goes through
another path - and the ~20,970-operation sequence built from `0x3010`/`0x0006`/`0x0015` is the only
candidate with the right volume.

`[V]`: the counts. `[D]`: that the 20,970-sequence is the bulk loader.
**Do not implement `0x0006` on that basis alone** - identify the routine that issues it first
(`0x0073D4` and `0x00740A` are its only two ROM sites, §52), exactly as §50 settled R1 vs R2 by
reading the caller rather than guessing from the trace.

### Housekeeping: §47's recommendation was overruled, correctly

§47 concluded the engine should be made to TOLERATE unknown microword fields. **Ronny decided the
opposite and it is now the standing rule (task P3 / #83): implement every field properly; throw, log
and die on anything missing.** Three reasons, recorded so it is not re-argued: tolerance hides real
gaps in the B30 execution path, turning a loud correct halt into silent wrong execution; it is not
what the hardware does, since faithfully executing an arbitrary word REQUIRES a complete field set;
and the throw is a feature - it is how the four blockers in word `0o0` were found at all.

## 55. THE 20,970-OPERATION SEQUENCE IS A SECOND CONTROL-STORE WRITE PATH `[V]` structure, `[D]` role 2026-08-30

§54 said find the routine that issues `0x0006` before implementing anything. Disassembled its only
two ROM sites (`rd2.py` over `AccpRom.cs`). **Two sibling routines, and they are unmistakable:**

```
ROUTINE A @ 0x73B4                        ROUTINE B @ 0x73F0
  link    A6,#-24                           link    A6,#-24
  move.w  D0,(0x14,A6)   ; address          move.w  D0,(0x14,A6)   ; address
  jsr     $76E6          ; ADDRESS PHASE    jsr     $76E6          ; ADDRESS PHASE
  jsr     $7776          ; SHIFT 128 OUT    (no shift)
  move.w  #$3010,$220000 ; latch            move.w  #$3010,$220000 ; latch
  move.w  #$0006,$220000 ; <-- UNMODELLED   move.w  #$0006,$220000 ; <-- UNMODELLED
  move.w  #$0010,$220000 ; clock            move.w  #$0010,$220000 ; clock
  clr.w   $0011314A      ; clear a flag     unlk / rts
  unlk / rts
```

**A takes an address AND shifts a full 128-bit microword; B takes an address and shifts nothing.**
That is the shape of a write/read pair - and neither touches `0x0018`, the gate, or the
`0x660000` status test that the known write path at `0x7420` uses.

### Why this is very likely P1's missing bulk load

| | known write path `0x7420` | routine A `0x73B4` |
|---|---|---|
| address | `jsr $76E6` | `jsr $76E6` |
| data | shifted BEFORE the call (§50) | **`jsr $7776` INSIDE, after the address** |
| gate | `bset #2` on `0x1144EE` | none |
| perform | `move.w #$0018` | `#$3010` / **`#$0006`** / `#$0010` |
| status | `btst #0,$00660000` | none |
| runtime count | **8** | **~20,964** |

`0x0006` sits in the structural position `0x0018` occupies in the known path: after the address, as
the operation. **So `0x0006` is a strong candidate for a second `perform`, and routine A for the
bulk control-store write.** The counts fit: 8 words through the `0x0018` path, ~20,964 through this
one, and `microwords written: 8`.

`[V]`: the two routines, their instruction order, their ROM addresses, and the runtime counts.
`[D]`: that `0x0006` is a perform and routine A is the bulk loader.

### Before anyone implements it

The data ordering DIFFERS from the known path and that matters: `0x7420` has its data shifted
**before** the routine runs (§50, settled from the ROM), whereas routine A shifts **inside**, after
the address phase. A model that assumes the `0x7420` convention here will pair address and data
wrongly - which is the exact failure §39 mistakenly attributed to the existing code.

So the implementation question is not "add a case for `0x0006`". It is: **what does the
`0x3010`/`0x0006`/`0x0010` triple mean, and does the shift that precedes it belong to the address
latched by that `0x3010` or to the earlier `jsr $76E6`?** Routine B - same triple, no data - is the
control that answers it, because whatever the triple does without data is what it does with the
address alone.

`clr.w $0011314A` in A and not in B is a further discriminator worth carving: a flag one path clears
and the other does not.

## 56. P1 ANSWERED: there are TWO control-store write routines and we model the one used 8 times `[V]` 2026-08-30

§55 found routine A at `0x73B4` and said find its callers. It has **three**, all `bsr.w`, and they
are decisive.

**Call site 1 (`0x7556`) - a loop that walks control-store addresses:**
```
007548: cmpi.w #7,D2          ; inner counter - 8 halfwords
00754C: bne.s  (loop back)
00754E: move.w (0x14,A6),D0
007552: add.w  #$3FF0,D0      ; ADDRESS = parameter + 0x3FF0
007556: bsr.w  routineA       ; <- WRITE
00755E: addq.w #1,(0x14,A6)   ; next address
007562: cmpi.w #4,D0
007566: bne.s  (loop)
```
The `+0x3FF0` matches the existing carve's own note that the firmware's address parameter arrives as
`parameter + 0x3FF0` over a 0x4000-word space - and the ND-5000 control store holds exactly 16384
words.

**Call site 3 (`0x762A`) - the start/stop microprogram test, in full:**
```
00761E: move.w (0x14,A6),$001144FE
007626: move.w #$3FF1,D0
00762A: bsr.w  routineA       ; write a microword at 0x3FF1
00762E: move.w #$3FF0,D0
007632: jsr    $00007A66      ; START   (named in Nd5000ControlStoreLink's own carve)
007638: jsr    $000078B2
00763E: jsr    $00007A84      ; STOP    (likewise)
```

### The answer

**The ACCP firmware has TWO control-store write routines:**

| | `0x7420` (modelled) | `0x73B4` routine A (NOT modelled) |
|---|---|---|
| callers | 1 (`0x74BC`) | **3, all in loops** |
| protocol | address phase, gate `bset #2`, `#$0018`, `btst` status | address phase, `jsr $7776` shift, `#$3010` / **`#$0006`** / `#$0010` |
| runtime count | **8** | **~20,964** |
| what the link does | commits a microword | **discards every write - `0x0006` falls into `default:`** |

`microwords written: 8` is therefore not a symptom of dropped commits, a mispaired address, a serial
transform, a missing field, or a broken read-back - **every one of which was investigated tonight.**
It is the exact count of the ONE write path the link implements. **The selftest's own write path was
never implemented, so none of its ~20,964 writes has ever landed.** That is P1 (#78), and it also
supplies §84/P2's mechanism: the sample test reads back a word its writes never reached.

`[V]`: the routines, their callers, the loop structure, the protocol difference, the counts.
`[D]`: nothing load-bearing remains - the only inference is that implementing routine A's protocol
fixes it, which is a prediction to be TESTED, not assumed.

### Implementation notes for whoever takes it (P1/#78)

- The data ordering differs from `0x7420` and this WILL bite: routine A shifts **inside**, after its
  address phase (`jsr $76E6` then `jsr $7776`), where `0x7420` has the data shifted before the call
  (§50). Do not reuse the existing pairing assumption.
- **Routine B (`0x73F0`) is a STATIC control only - it is DEAD CODE.** Verified 2026-08-30: the ROM
  contains NO reference to `0x73F0` at all - no `jsr`/`bsr`, no 32-bit literal, and not even the
  16-bit value anywhere in 131,074 bytes. Routine A ends in `rts` at `0x73EE`, so it is not reached
  by fall-through either. It is still useful for READING what the triple means without a shift, but
  it can never be a runtime control, and **all ~20,964 `0x0006` writes therefore come from routine A
  alone** - which matches A having three loop callers and `0x0006` having exactly two ROM sites.
- `clr.w $0011314A` appears in A and not in B; the flag has four ROM references
  (`0x000E98`, `0x0055D8`, `0x0073E6`, `0x00B188`) and is worth carving alongside.
- Red-first: the ACCP selftest's own verdict block already grades this. It is the regression test.

## 57. The `0x0011314A` flag, carved - and one tempting link left EXPLICITLY OPEN `[V]`/`[OPEN]` 2026-08-30

§56 listed `clr.w $0011314A` as a discriminator between routines A and B. All four ROM references:

```
000E94  move.w #$0001,$0011314A     ; SET, during init (beside move.w #$0001,$001143AA)
0055D6  tst.w  $0011314A            ; TESTED
0055DC  beq.s  +0x20                ;   ... skip if zero
0055DE  move.w #$00FF,D0            ;   ... else D0 := 0x00FF
0055E2  jsr    $00006986            ;   ... and call 0x6986
0073E6  clr.w  $0011314A            ; CLEARED by routine A (the unmodelled CS write)
00B184  move.w #$0001,$0011314A     ; SET, immediately after jsr $7A84 (STOP microprogram)
```

`[V]`: set at init and after STOP; cleared by the control-store write; tested on a path that loads
the constant `0x00FF`. Shape: "the control store has not been written since the microprogram was
stopped".

### The tempting link, and why it is NOT being recorded as a finding

The console prints `Start/stop microprogram test abc failed at CSA: 00FFH`, and here is a path that
loads exactly `0x00FF` when this flag is set. It is very tempting to conclude that the `00FFH` is
**this constant rather than a real control-store-address read-back** - which would matter, because
anyone debugging that message by chasing CSA values would be chasing a literal.

**NOT ESTABLISHED.** The string `failed at CSA` is at ROM `0x11B0F` and `Start/stop` at `0x117CB`,
but I have not traced `0x6986` to either. Tonight has produced five retractions, every one from
exactly this move - a plausible connection between two things seen in the same window, written up
before the intervening code was read (§33, §36, §40, §44, §50).

**What settles it, cheaply:** the census instrument is already in place. Break on the write of
`0x00FF` to whatever `0x6986` formats, or simply follow `0x6986` to its output call. One read, no run.

### Ordering note

This is a side-carve, not a blocker. **P1 (#78) is answered and implementable without it** - §56 has
the routine, the protocol, the callers and the counts. The flag matters when someone wants to know
WHY the selftest reports what it reports, which is a question for after the writes land.

## 58. §57's tempting link is REFUTED - and the real CSA reporter was already in a log we had `[V]` 2026-08-30

§57 flagged, without adopting, that `0x0055DE move.w #$00FF,D0` might be the source of the console's
`failed at CSA: 00FFH`. **It is not.** Checked as §57 said to, and it cost one read.

The message is a linked record in a chain of format strings:

```
0x11AF4  ... 0x0B "completed OK"
0x11B00  -> next 0x00011B0C, len 0x0F, " failed at CSA: "
0x11B0C  -> next 0x00011B28, len 0x12, " failed$$Result  : "
```

**`0x00011B00` - the "failed at CSA" record - is referenced from code at `0x00C0C0`**, not from
`0x6986`. So the `0x55D6` flag test and the CSA message are different paths, and §57's link does not
hold. Recorded as refuted so it is not re-adopted.

### The evidence for the real reporter was sitting in `accp-cs.log` the whole time

That earlier run already carried a trap instrument on this exact address:

```
trap hits at 0xC0FC: 1
  #  0 @ 8,574,088  D0=0x000000FF  A6=0x11008C  (0x20,A6)=0x00FF
```

`0xC0FC` is inside the routine that references the message record at `0x00C0C0`, and the printed
value comes from **`(0x20,A6)`, a stack local** - `0x00FF` was already captured there, with its
instruction count, hours before I started theorising about where the number came from.

So the honest position on `CSA: 00FFH`: it is whatever `(0x20,A6)` holds at `0xC0FC`, and **that is
now a one-hop question** - find what writes that local - rather than a guess between a constant and a
read-back. Still `[OPEN]`, but bounded.

### Why this section exists

Six retractions tonight, five of them from adopting a plausible link before reading the code between
the two ends. This is the first time the check was run BEFORE the write-up, and it took one command.
The general form, now earned twice over:

> **Before connecting two things seen in the same window, read what is between them.** If that is
> expensive, the connection is a hypothesis and must be labelled one. If it is cheap - and here it
> was a single string-reference search - there is no excuse for the label.

## 59. `CSA: 00FFH` IS A HARD-CODED LITERAL, not a control-store address `[V]`/`[D]` 2026-08-30

Closing the `[OPEN]` left by §57/§58. Every literal `0x00FF` store in the ROM was enumerated
(`move.w #$00FF,...` - 73 sites, all but one in the `0x4D00`-`0x6700` console band where `D0 := 0xFF`
is plainly an error-code convention). The exception is in the selftest region:

```
00CCFA: moveq  #10,D0
00CCFC: lea    $001144F0,A0        ; the shift buffer / verdict block
00CD08: jsr    $00007776           ; SHIFT 128 BITS
00CD0E: move.w #$00FF,D0
00CD12: andi.w #$00FF,D0
00CD16: move.w D0,(0x16,A6)
...
00CD9A: move.l A2,(0x14,A1)
00CDA2: moveq  #7,D1
00CDA4: move.l D1,(0x1C,A1)
00CDA8: move.w #$00FF,(0x20,A1)    ; <-- A LITERAL, at OFFSET 0x20
```

And the trap instrument already in `accp-cs.log` reported, at the reporter:

```
trap hits at 0xC0FC: 1
  #  0  D0=0x000000FF  A6=0x11008C  (0x20,A6)=0x00FF
```

**Offset `0x20` on both sides.** `0x00CDA8` stores the constant `0x00FF` into offset `0x20` of a
record; `0xC0FC` prints offset `0x20` of a record. `[V]` that the literal exists at that offset and
that the reporter reads that offset; `[D]` that they are the same record - `A1` there and `A6` here
were not proven to be the same pointer.

### What it means, and it is worth knowing before anyone debugs that message

**`failed at CSA: 00FFH` does not report a control-store address.** The `00FF` is a constant the
firmware stores alongside `moveq #7` into an adjacent field. Chasing "why is the CSA 0xFF" is
chasing a literal - the number carries no information about where the control store actually was.

`0x00CD08` is also the THIRD caller of the shift engine `0x7776` (the others being routine A at
`0x73C6` and the `0x7748` path, §56), so this routine shifts a microword and then records a fixed
failure code. It sits in the same region as the `0x001100AC` transition the earlier log captured -
`# 58 @ 8,570,915 PC 0x00CDA6 0x0011 -> 0x00FF  <== last before the print`.

### Note on how this one went

§57 suspected the `00FF` was a constant but pointed at the wrong site (`0x0055DE`); §58 refuted that
path. The suspicion was right and the mechanism was wrong, and it only became a finding once the
actual store was located. **That is the intended shape** - a hypothesis is allowed to be wrong, but
it is not allowed to be written up as a finding before the site is in hand.

---

## 36. `START-SWAPPER` NEVER RETURNS — and everything before it works `[V]` 2026-08-30

The measurement that had never been taken. Every earlier run this week used
`ShortBringup_Octobus_**NoStartSwapper**_PlaceAndRun_Capture`, whose own comment says it is
*"deliberately WITHOUT status and WITHOUT start-swapper"* — i.e. it skips the very command that
hangs. `FullFlow_Octobus_Login_Nd500_Status_StartSwapper_Capture`, macro round, `DOMS-CSFIX.IMG`:

```
ND-5000: memory-configuration
   ND-500 address zero:  004100  000000  00010200000  00000000000     <- correct
ND-5000: status
   > Loading Control Store
   INFO * 0B:6B * BAK01.37603B   SINTRAN III File System   Not used
   > Loading Swapper
   ZERO 0 / CARRY 0 / SIGN 0 / FLAG 0 / OVERFLOW 0
ND-5000: process-status
   Proc. 1  SYSTEM  idle  0.0 s                                       <- works
ND-5000: start-swapper
                                                                      <- NOTHING. EVER.
```

**`START-SWAPPER` produced no output and did not return.** The run sat there ~70 minutes before being
killed externally — so this is far stronger than the old 900-second-window claim, and the
"did not finish in the window" caveat does not apply.

**It is not pack-specific and not stale:** this reproduces the 2026-08-28 full-flow capture, which
was taken on the *stock DOMs pack*. Two different packs, same behaviour.

### 36a. What this corrects

**The framing "place-domain stalls between `> Loading Swapper` and `> Allocating memory`" was an
artefact of the test I chose.** `START-SWAPPER` is a MANDATORY step of the documented bring-up
ladder —

```
SET-ND-500-UNAVAILABLE -> DEFINE-MEMORY-CONFIGURATION -> GIVE-ND-500-PAGES
   -> LOAD-CONTROL-STORE (037B CSLOA) -> DEFINE-SWAP-FILE (046B)
   -> LOAD-SWAPPER (007B LDSWA) -> START-SWAPPER (054B RUNSW) -> SET-ND-500-AVAILABLE
```

— and it has **never once been observed to complete**. Measuring `place-domain` while skipping it
was measuring the wrong thing, and §33's finding (the swapper correctly idles because nothing ever
faults) is entirely consistent with a swapper that was never started.

### 36b. Where to look, and it is a SINTRAN-side read first

`START-SWAPPER` is MON 60B subfunction **054B `RUNSW`**. Read what it does in `5P-P2-MON60.NPL` and
the disassembled `030-S3SM5` FUNCS entry for 054B, and establish **whether it is waiting on an answer
that never arrives or looping**, before building any instrument. The distinction is visible from the
source and decides which instrument would even be meaningful.

Do NOT re-open the swapper-side chain (§33): `SWPDECODER`, `LNEWSWAP`, `HSWPI` and `5ACTSWAPPER` are
all carved and all behave as designed.

## 60. `START-SWAPPER` should ANSWER IMMEDIATELY - so a hang is one of five calls before it `[V]` 2026-08-30

The `MSWSTART` handler, from `MP-P2-N500.NPL` (source, not derived):

```
133642  IF A=MSWSTART THEN                       % Start swapper
133645     SWPPING; CALL WN5STATUS               %   mark process "using Swapper"
133654     X:=SWMSG; ... *AAX HSWPI; STDTX       %   MMESSAGE =: SWMSG.SWPINFO
133661     3START; *MICFU@3 STATX                %   MICFU := 3START (23B)
133663     5SWPROC; *SENDE@3 STATX; 5RECE@3 STATX
133666     SWACTIVE; *AAX SWPFU; STATX           %   SWPFU := SWACTIVE
133671     A:=300; ...                           %   priority 300
133715     X.PSTAT BZERO SLICE=:X.PSTAT          %   swapper is not timesliced
133732     *IOF
133734     CALL SLOCK;    GO FAR N500ERR         % (1)
133736     CALL XTER500;  GO FAR N500ERR         % (2)  stop nd-500
133740     CALL ITO500XQ; CALL SUNLOCK           % (3)(4) queue swapper message
133742  SWME1:
133742     CALL XACTRDY                          % (5)
133743     CALL LOWACT500; LTTMR=:TMR            % (6) reactivate nd-500
133746     *ION
133747     X:=5MMESSAGE; ANSWER; GO FAR XEILSTAT % <- RESTART THE PROCESS THAT ASKED
```

### Two things this settles

**1. "START-SWAPPER produces no output" is EXPECTED, not a symptom.** Nothing in this handler prints.
`> Allocating memory` comes later, from the swapper actually doing work (§46), not from here. Anyone
treating the silence as the defect is chasing normal behaviour.

**2. The handler does NOT wait for the ND-500.** It sets `MICFU := 3START`, `SWPFU := SWACTIVE`, a
priority and a queue entry, then **answers the caller at `133747`**. So the monitor's `start-swapper`
command is meant to return promptly regardless of what the ND-500 does next.

**Therefore a start-swapper that never returns died BEFORE `133747`**, in one of six calls - and that
is a much smaller question than "start-swapper hangs".

### The candidate that fits this lane, stated as a HYPOTHESIS

`CALL XTER500` (2) is the one to look at first. Its carved behaviour (bus-interface skill): *"read
`RSTA5`; if `5ILOCK`: `TERM5`, poll until clear; timeout -> `5MCST` -> `ESPTIMOUT`"*. **`RSTA5` is a
3022 register.** On the octobus lane there is no 3022, so what the station returns for that IOX
decides whether the poll terminates. A poll that never sees its bit clear is exactly a command that
never returns and prints nothing.

`[D] NOT ESTABLISHED` - it has a documented timeout, and five other calls are equally unexamined.
**The check is cheap and needs no new instrument:** the harness already logs ND-100 PC and PIL, so
capture where the ND-100 is spinning during the hang and resolve it against the listing. That names
the call outright instead of guessing between six.

Ordering note: this is #79/P4. It is downstream of #78/P1 only in the sense that the oracle round
cannot reach it - on the macro round it is directly measurable now.

## 61. `XTER500` IS PATCHED ONTO THE OCTOBUS PATH - it polls `X5PRO`, and `X5PRO` was measured as 0 `[V]`/`[D]` 2026-08-30

§60 guessed `CALL XTER500` hangs polling `RSTA5`. **Refuted - it never reads `RSTA5` on this system.**
The body, `MP-P2-N500.NPL:2923`:

```
145172   XTER500: IF 5CPUSTOPPED><0 THEN EXITA FI   % already stopped -> immediate exit
145202          0=:LOOPCOUNTER
145203   *NNJ12=*
145203          GO TER51                            % <<< PATCH: jump over the 3022 path
145204          T:=HDEV+RSTA5; *IOXT                 %     (skipped) read 3022 status
145210          IF A BIT 5ILOCK THEN ...             %     (skipped) TERM5 + poll 5ILOCK
145230   TER51:
145230          FOR LOOPCOUNTER DO
145230              IDLEKICK; CALL XKICK500          % OCTOBUS kick
145232              CALL GETC5PROC                   % read the running ND-5000 process
145233              IF A=-1 GO OKRET                 % exit ONLY when it answers -1
145236          OD
145240   TER52: ESPTIMOUT                            % fall through = timeout -> error return
```

`*NNJ12=*` is a **patch marker** (the same `*NNxnn=*` convention the project rules describe). The
patched system jumps straight to `TER51`, so **`XTER500` on this lane is an octobus kick loop, not a
3022 status poll.** §60's hypothesis is dead, and so is the "there is no 3022 on this lane" reasoning
built on it - SINTRAN already knows.

### The exit condition, and the measurement that already exists

`GETC5PROC` (`CC-P2-N500.NPL:657`) reads **`X5PRO`** out of the mailbox extension block:

```
023630   GETC5PROC: T:=5MBBANK; X=:D:=MAILINK; *AAX X5PRO
023634           *BSET BCM 120 DX; LDATX      % Fool the cache
023636           *BSET BCM 120 DX; LDATX
023640           X:=D; EXIT
```

So `XTER500` spins until `X5PRO == -1`. And §31's capture already dumped every extension block:

```
extblk[0]@0x00428800: X5BEX=0000,0004 X5ACT=0030 X5PRO=0000   <- NOT -1
extblk[1]@0x00428900: X5BEX=0000,BE30 X5ACT=0001 X5PRO=FFFF   <- -1
extblk[2..4]                                    X5PRO=FFFF    <- -1
```

**`extblk[0]` holds `X5PRO = 0x0000`.** If `MAILINK` resolves to block 0, the exit condition is never
met, and `XTER500` runs its full `LOOPCOUNTER` of octobus kicks before `TER52: ESPTIMOUT`. With
`LOOPCOUNTER` initialised to 0 (i.e. a full wrap), that is a very large number of kick + mailbox-read
iterations - **which is exactly what a command that produces no output and never returns looks
like.**

`[V]`: the patch, the loop, the exit condition, that `GETC5PROC` reads `X5PRO`, and the four measured
`X5PRO` values.
`[D]`: that `MAILINK` points at block 0, and therefore that the loop cannot exit.
**>>> REFUTED THE FOLLOWING TICK - see section 62. `MAILINK` does NOT point at block 0, `X5PRO` reads
-1, and `XTER500` exits normally. Do not act on the paragraphs below this line. <<<**

### The next step is one lookup, not an instrument

Resolve `MAILINK` - which extension block `GETC5PROC` actually reads. If it is block 0, #79 is
explained outright and the fix is upstream: **why is `X5PRO` zero in block 0 when every other block
holds -1?** If it is block 1, this account is wrong and the loop should exit, so the hang is
elsewhere in §60's list of six calls.

Either way this is a far better handle than "start-swapper hangs", and it came from the source, not
another run.

## 62. §61 REFUTED: `MAILINK` is not block 0 - and the harness dump invited the mistake `[V]` 2026-08-30

§61 hypothesised that `XTER500`'s `GETC5PROC` loop cannot exit because `X5PRO` reads 0. **Wrong, and
it took one lookup.**

`MAILINK` is a field of the ND-500 CPU DATAFIELD, one per CPU:
```
5P-P2-MON60.NPL:562   A:=-1=:X.MAIL1LINK=:X.MAILINK        % initialised to -1
MP-P2-N500.NPL:274    IF CPUAVAILABLE BIT 5ALIVE AND MAILINK><-1 THEN   % "Nd-500 cpu present?"
```
So `MAILINK` holds that CPU's **extension-block** address, and `-1` means "no CPU".

§31's own capture states which address that is:
```
----- discovered mailbox ... header=0x00428800 extBlock=0x00428900 -----
```
**`0x00428800` is the mailbox HEADER. The per-CPU extension block is `0x00428900`** - corroborated by
the carved `X5ACT_carved=0x0042890A`, i.e. extBlock + 0x0A.

And `0x00428900` is the block whose dump line reads **`X5PRO=FFFF`** - which IS -1. So `GETC5PROC`
returns -1 and **`XTER500` takes `GO OKRET` immediately. It is not the hang.**

### The trap, and it is ours

The capture prints the header as if it were a CPU block:
```
extblk[0]@0x00428800: X5BEX=0000,0004 X5ACT=0030 X5PRO=0000 QUEUE NON-EMPTY   <- THE HEADER
extblk[1]@0x00428900: X5BEX=0000,BE30 X5ACT=0001 X5PRO=FFFF QUEUE NON-EMPTY   <- CPU 1
```
Labelling the header `extblk[0]` and decoding header bytes through the extension-block field names
produces a plausible, wrong row - and I read `X5PRO=0000` off it and built a theory. **The dump
should start at `extBlock`, or label index 0 as the header.** Worth fixing: it is a one-line change
that removes a live trap from a diagnostic several people read.

### Where #79 stands now

`XTER500` is eliminated. From §60's list, the calls before the `ANSWER` at `133747` that remain
unexamined are `SLOCK`, `ITO500XQ`, `SUNLOCK`, `XACTRDY` and `LOWACT500`.

**Stop guessing between them.** §60 already named the measurement that settles it outright and needs
no new instrument: **capture the ND-100 PC and PIL while the command hangs and resolve it against the
listing.** That is one number and it names the call. Two hypotheses have now been spent guessing
where one measurement would have answered.

## 63. #75 MEASURED at four operands - and it refutes my own `SC3 OR SC4` mechanism `[V]` 2026-08-30

Added `NegZeroScratchDiagTests` (reports, does not assert) and exposed the microword engine from the
oracle so a scratch register can be inspected. Four operands, single-float `TEST`:

```
operand=0x80000000 (-0.0)  micro Z=1 S=0   functional Z=1 S=1    SC1=0x80000000 SC3=0 SC4=0
operand=0x00000000 (+0.0)  micro Z=1 S=0   functional Z=1 S=0    SC1=0x00000000 SC3=0 SC4=0
operand=0xBF800000 (-1.0)  micro Z=0 S=1   functional Z=0 S=1    SC1=0xBF800000 SC3=0 SC4=0
operand=0x3F800000 (+1.0)  micro Z=0 S=0   functional Z=0 S=0    SC1=0x3F800000 SC3=0 SC4=0
```

### The refutation, first

The `TESTF`/`TESTFD` carve concluded: *"the S that reaches macro status comes from `SC3 OR SC4`"*,
because `0o3211` is `ALU,OR A,SC3 B,SC4 -> D,ALU,REG37, ST,SAVA` and neither register is written
inside the instruction's 20 words. **The measurement kills that.** `SC3 = SC4 = 0` in ALL FOUR cases,
so `SC3 OR SC4` is always 0 - yet S is 1 for `-1.0` and 0 for `+1.0`. **A constant cannot explain a
varying output.** So `0o3211`'s `ST,SAVA` is not what decides the macro S, and the mechanism half of
that carve is withdrawn. (Snapshot is post-instruction, so this does not prove the registers were
zero *during* - but a value that is zero at the end and produces two different S values cannot be the
source either way.)

What the carve got RIGHT and is now confirmed live: **`SC1` holds the ORIGINAL operand in every
case** (`0x80000000`, `0x00000000`, `0xBF800000`, `0x3F800000`). The magnitude mask at `0o3001`
really does write nothing - `DEST=D,NONE`, `STATUS=(hold)` - and the sign survives in `SC1`.

### The finding, which is better than the one-point divergence it replaces

Read across the four operands, the two engines implement **different definitions of S**:

| | -0.0 | +0.0 | -1.0 | +1.0 |
|---|---|---|---|---|
| microword | 0 | 0 | 1 | 0 |
| functional | **1** | 0 | 1 | 0 |

**The microword computes S = "sign AND NOT zero" - arithmetically NEGATIVE. The functional core
returns the RAW SIGN BIT.** They agree on every operand except the one where those two definitions
differ, which is exactly `-0.0`. This is not a one-off flag glitch; it is a semantic difference, and
four points show it cleanly where one point could not.

### Which sharpens the adjudication rather than settling it

ND-500 Reference Manual 10.11, quoted in `Test.cs`, says `result.signbit XOR Overflow -> S` - the raw
sign bit, i.e. the FUNCTIONAL answer. The microcode implements the arithmetic answer, and `-0.0` is
not less than zero. The precedent in that same file - the `TEST_BI` carry case, where the B30
microcode was adjudicated OVER manual 10.11 - points at the microword being right.

**Still Ronny's call, and still not decided here.** What this contributes is that the question is now
"which definition of S is correct" rather than "why does one flag differ", and the answer changes
`Test.cs` for BOTH widths, not just the `-0.0` case.

Files: `tests/NegZeroScratchDiagTests.cs` (new, reports only);
`tests/MacroInstructionOracle.cs` gains `LastMicroCpu` so a diagnostic can read scratch registers
without duplicating the 100-line engine setup.

## 64. A TIMEOUT THAT CANNOT BE EVALUATED IS NOT A TIMEOUT - and it invalidates my scale-8 runs `[V]` 2026-08-30

Every wait in this harness has the shape:

```csharp
while (sw.ElapsedMilliseconds < timeoutMs)
{
    Pump();          // -> _machine.Run(...)
    ...
    Thread.Sleep(1);
}
```

**The deadline is only tested BETWEEN `Pump()` calls.** If `_machine.Run(...)` blocks, control never
returns to the comparison and the timeout can never fire. A 300-second cap became a 70-minute hang.

### What this costs, and it is mine

I spent **132 minutes of wall clock** on two `RETROCORE_HARNESS_TIMEOUT_SCALE=8` runs
(`ladder-s8`, `mudom-s8`), on the premise that a bigger window gives a slow command more time to
finish. **If the block is INSIDE one `Run()` call, scaling the window changes nothing** - the loop
never reaches the comparison either way. Both runs were stopped at 132 minutes having printed
nothing, and their premise was unsound from the start.

This is a new entry for the instrument-failure taxonomy, and it is NOT any of the existing ones:

> **A guard you cannot reach is not a guard.** Before trusting a timeout, a retry limit or a
> cancellation check, ask what has to RETURN for the check to be evaluated at all. A cap tested only
> between iterations of a loop that can block inside one iteration is decorative. The tell is a
> bound that is exceeded by orders of magnitude rather than slightly - 70 minutes against a
> 300-second cap is not a slow machine, it is a check that never ran.

It also generalises tonight's earlier lesson rather than replacing it. §35/§38/§46 established that a
STALL conflates "never happened" with "not within N host seconds". This adds a third possibility:
**"the harness never got to ask"** - and only that third one is immune to `TIMEOUT_SCALE`, which is
exactly why raising the scale produced no new information.

### The two instruments now in the harness are complementary, and both are needed

Two lines of work reached this file. The result is not duplicated:

 - **Worst-`Pump()` timing** (a FORK of this session, not another agent - see the attribution note
   below): records the longest single `Run()` call and the PC/PIL it entered at. Answers *is the
   block INSIDE one call* - i.e. can any timeout fire at all.
 - **ND-100 PC/PIL histogram across pumps** (this session, §60): records where the ND-100 is seen
   while a command is outstanding. Answers *WHICH routine* - one hot PC is a spin, a spread is
   progress that never reached the marker.

The first says whether a timeout was ever evaluable; the second names the code. Neither alone
settles #79, and `start-swapper` is now bounded by a hard 300 s that `TIMEOUT_SCALE` deliberately
does NOT scale - a scale factor is for telling slow from dead on commands that DO complete, and this
one never has.

Build asserted before use: `EXITCODE=0`, `Emulated.Tests.dll` stamped 12:15:29, the run started
12:15:41 against it (log `ss.log`).

### ATTRIBUTION CORRECTION, 2026-08-30

I first wrote the worst-`Pump()` work up as a peer session's (`nd500uc-ad`). **It is not.** That
session walked the parent chain of the running testhost and returned it:

```
[89704] testhost.exe  -> [52712] vstest.console -> [36404] dotnet test
      -> [96168] bash.exe -> [50664] claude.exe --session-id 2c5cb8c6-... --fork-session
```

`2c5cb8c6-...` is THIS session, so PID 89704 belongs to a FORK of it - my own long-running subagent -
and `nd500uc-ad` has started nothing and has no result to send. I had been waiting on a session that
could never produce one.

Worth recording as its own small lesson: **a process is not a peer's just because a peer mentioned
it.** The parent chain is the answer and it takes one command - the same rule the project already has
for killing by PID (never by name, prove ownership by walking `ParentProcessId` upward). I applied
that rule correctly for killing and not at all for attributing.

## 65. PLACE-DOMAIN DOES post a start; the explicit START-SWAPPER does not `[V]` 2026-08-30

The fork's ladder measured, during `start-swapper`: 53 messages, `startSeen=0`, `startTaken=False`,
`swpfu[(none)]` - SINTRAN never asks the ND-5000 to start the swapper, and the CPU is parked at
`PC=0` in `WAIT` exactly as designed. Taken alone that reads as "the octobus lane never starts the
swapper". **It is narrower than that.**

The SHORT BRING-UP (§31), which never types `start-swapper`, measured the opposite:
`startSeen=1 startMicfu=23B startTaken=True`, `swpfu[LNEWSWAP:2]`, `restarts=1/1`.

| command | startSeen | startTaken | swpfu |
|---|---|---|---|
| `place-domain` (short bring-up, no start-swapper typed) | **1** | **True** | `LNEWSWAP:2` |
| `start-swapper` (full ladder) | **0** | **False** | `(none)` |

**`PLACE-DOMAIN` posts the 3START. The explicit `START-SWAPPER` command does not.** That is the
defect's actual shape, and it matches the manual: ND-60.136.04A 8.10.10.4 says the swapper load
"is done automatically when the first ND-500 process is initiated by the monitor", and ND-30.003.7
classes explicit `START-SWAPPER` as part of the ADVANCED start (§46).

### Where the sender lives, and why the NPL sources cannot answer it

`MSWSTART = 7B` (`CARVE-ANSWER-N5SWAP-FUNCTION-VOCABULARY-2026-08-17.md:178`). Searching every NPL
source finds `MSWSTART` **exactly once** - at the HANDLER, `MP-P2-N500.NPL:431`. **Nothing in the NPL
sends it.** The sender is `RUNSW`, FUNCS entry `054`, at **`163621` in `030-S3SM5.dis`** - the ND-500
system monitor segment, which is disassembled but has no NPL source. So this question was never
answerable from the NPL tree, and the answer is in the `.dis`.

Its body is raw ND-100 assembly with unresolved `JPL I nn` targets through a literal pool at
`163717`-`163723`. The load-bearing question for it is narrow: **does `RUNSW` ever put `7` in A and
call the message sender?** No `SAA 7` / `SAT 7` appears in `163621`-`163703`; the region uses
`SAA 36`, `SAA 17`, `SAA 20`, `SAA 4`, `SAA 2`. Not conclusive yet - the value could be loaded from
memory rather than as an immediate, and the routine continues past `163703`.

### Also worth keeping from the older carve

`CARVE-RUN-TO-WORK-POSTING-CHAIN-2026-07-20.md` records that `SWPINFO` is written on TWO distinct
occasions - cold-start init (`SWMESS`/`MSWSTART`, `133654`) and per-fault work (`5ACTSWAPPER`) - and
that on the D4/3022 lane in July the swapper WAS `3START`'d and executed, dying instead at
`PC=0x0800913B` on an empty message. **That is a different failure from ours** and is 3022-lane; do
not merge the two. Ours does not start at all on the explicit command, and starts fine via
place-domain.

### Next

Finish `RUNSW` at `163621`: resolve the `JPL I` literal pool and find whether the `7` reaches the
sender. That is a `.dis` read, needs no run, and it is the last unknown in this chain.

## 66. `RUNSW` DOES load `MSWSTART` - so the question is REACHABILITY, and the PC sampler answers it `[V]`/`[D]` 2026-08-30

§65 left one load-bearing question: does `RUNSW` (FUNCS `054`, `163621` in `030-S3SM5.dis`) ever put
`MSWSTART` = `7B` in A and call the message sender? **It does.**

```
163725  170407   SAA 7              ; A := 7 = MSWSTART
163726  135170   JPL I 170          ; -> 164116   the call
163727  124165   JMP 165            ; -> 164114   (error return)
163730  135167   JPL I 167          ; -> 164117
163731  124163   JMP 163            ; -> 164114   (error return)
```

`[V]` - `SAA 7` is unambiguous, and `MSWSTART = 7B` is carved
(`CARVE-ANSWER-N5SWAP-FUNCTION-VOCABULARY-2026-08-17.md:178`).

**So the sending code EXISTS and is correct. The defect is that execution does not reach it** - which
is a completely different question from the one this lane has been chasing, and a much smaller one.

### The shape of the body says where it bails `[D]`

`163621`-`163716` is a run of repeating blocks:

```
170417  SAA 17        \
135051  JPL I 51       >  load a small code, call something, then
144400  RAND 0 0      /   RAND 0 0 (clear A) - and a JMP I to a common exit
```
with `SAA 36`, `SAA 17`, `SAA 20`, `SAA 41`, `SAA 4`, `SAA 2` at different blocks, each followed by a
`JPL I` and paired `JPL I` / `JMP I` returns into the literal pool at `163717`-`163724`. That is the
shape of a SERIES OF GUARDED PRECONDITION CHECKS, each with an early error return, ahead of the
`SAA 7` at `163725`.

**If any one of those checks fails, `RUNSW` returns before the `SAA 7`, no `MSWSTART` is posted, the
ND-5000 is never asked to start, and the command produces no output** - which is exactly
`startSeen=0 startTaken=False swpfu[(none)]` with 53 messages of other traffic. `[D]` - the block
structure is `[V]`, the interpretation as precondition checks is inference.

### This is now a REACHABILITY question, and the instrument for it is already built

Where does the ND-100 get to inside `163621`-`163726`? That is precisely what the PC/PIL histogram
answers - and it is why the sampler mattered. It has NOT yet produced data on this path: it was wired
into `RunNd500Command` only, the fork's run reported `NO SAMPLES`, and the short bring-up drives
commands through `Step500`. **Both paths now sample** (`DumpHangPcHistogram`, shared), and the dump
states explicitly when it collected nothing so an empty histogram is never read as evidence. Built
but not yet re-run - the `Emulated.Tests` lock was held.

**Next, in order:**
 1. Re-run with the corrected sampler and read the PC histogram during `start-swapper`.
 2. Resolve which of `163621`-`163716`'s checks the PC lands in, against the literal pool at
    `163717`-`163724`.
 3. THEN ask why that particular precondition is false on this lane.
Do not skip to 3 - which check it is has not been measured, and guessing between six of them is what
§60 and §61 already cost.

## 67. TENSION: a run with NO MICFU 5 still got a 3START `[V]` - the "no 5, so no start" chain needs settling 2026-08-30

A parallel carve derived a clean chain for why `start-swapper` posts nothing:

 - `SWMESS` (`MP-P2-N500.NPL:133635`) is the ONLY code that posts a start - `133661 3START; *MICFU@3
   STATX` and `133666 SWACTIVE; *AAX SWPFU; STATX`, which are exactly the two effects the ladder
   showed missing (`startSeen=0`, `swpfu[(none)]`).
 - `SWMESS` is arm 05 of a dispatch gated on `D=3SWMESS`, and **`3SWMESS` = MICFU 5**.
 - The ladder's trace shows `micfu[1B:27 12B:1 30B:12 31B:13]` - **no MICFU 5 at all**.
 - Therefore: no 5 -> `SWMESS` never dispatched -> no `3START`.

**The short bring-up contradicts the last step.** From `mudom.log` (§31), the run in which
`place-domain` DOES start the swapper:

```
micfu[1B:49 12B:1 23B:1 24B:1 31B:13]      <- NO MICFU 5 either
startSeen=1  startMicfu=23B  startTaken=True  swpfu[LNEWSWAP:2]
```

**A run with zero MICFU 5 nonetheless produced a `3START`.** So "no MICFU 5" cannot by itself be
sufficient for "no start" - something starts the swapper on the place-domain path without a 5 ever
appearing in the servicer's histogram.

### Do not resolve this by preferring either reading

Both numbers are real and from the same instrument. Possible accounts, none yet tested:
 - the `micfu[]` histogram counts messages in ONE direction, and `3SWMESS` travels the other way, so
   its absence from the histogram says nothing about whether `SWMESS` ran;
 - `place-domain` reaches `3START` through a path that is not `SWMESS` at all;
 - the two runs differ in some third way not yet identified.

There is a THIRD data point that must be reconciled with both: **task #80 recorded `MICFU=0x05`
observed at `SWPPING`** in an earlier run - i.e. a 5 that DID appear. So across three runs we have
"5 present", "5 absent with a start", and "5 absent without a start". Any account has to fit all three.

### Why this matters more than it looks

`Nd500Generation.cs` records that the B30 dispatches MICFU 05 to `MSG_ILLEG` on the ND-5000, and then
warns in its own words: *"THE MICROCODE READING IS SOUND; WHAT SINTRAN SENDS IS NOT SETTLED ... Do NOT
hard-code 05 to illegal until the SINTRAN carve confirms what SINTRAN actually sends."* It also
records that an EARLIER version of that claim was wrong because the grep behind it covered only the
resident nucleus - **a scope-limited negative read as an absence**, which is the same trap twice more
tonight (§37's transform search, §51's raw counts).

So a conclusion here would feed straight into a generation-dependent hard-code that the code has
already been burned by once. **Settle the three-run contradiction first**, and the cheapest way is to
determine what the `micfu[]` histogram actually counts - one read of the servicer, no run.

## 68. §67 RESOLVED: `micfu[]` counts only SINTRAN -> ND-500 messages, so it CANNOT show `3SWMESS` `[V]` 2026-08-30

§67 flagged three irreconcilable data points about MICFU 5. One read of the code that populates the
histogram settles all three.

`Nd500MicrocodeServicer.cs:2085-2092`, inside the mailbox RECEIVE path:

```csharp
// Decoded RECEIVE trace: exactly what nd-500-mon/SINTRAN sent us
host.ServicerLog($"MAILBOX RECV @word 0x{msgBase >> 1:X6}: ...");
host.WriteNd100Word(staAddr, ... N5MessageStatus.Waiting);
ushort micfu = host.ReadNd100Word(msgBase + (uint)(N5MessageOffsets.MICFU * 2));
if (micfu < MicfuHistogramSize)
    _micfuCounts[micfu]++;
```

**`micfu[]` tallies messages the SERVICER RECEIVES - what SINTRAN sends TO the ND-500.** It is a
one-directional census of one message population.

`3SWMESS` is not in that population. `5ACTSWAPPER` (`MP-P2-N500.NPL:145035`) READS `MICFU` out of a
message it is handling and tests it:
```
145035   T:=5MBBANK; *MICFU@3 LDATX; COPY SA DD   % D:=X.MICFUNC
145040   IF 3SWMESS=D THEN                        % Message to swapper?
```
That is SINTRAN inspecting a message on its own side. **So the absence of MICFU 5 from `micfu[]` is
not evidence about whether `SWMESS` ran - the instrument is structurally incapable of showing it.**
Taxonomy #8: a count that cannot be RELEVANT to the question asked of it.

### All three data points now fit, with nothing left over

| observation | explanation |
|---|---|
| ladder: no MICFU 5, no start | 5 would not appear here either way - says nothing |
| short bring-up: no MICFU 5, but `startSeen=1` | consistent; the start came via a path this census does not cover |
| task #80: MICFU 5 OBSERVED | a genuine SINTRAN -> ND-500 message carrying 5, which is a DIFFERENT event from `SWMESS` dispatching on `3SWMESS` |

**So the chain "no MICFU 5 -> `SWMESS` never dispatched -> no `3START`" is NOT supported.** Its first
step rests on an instrument that cannot see the thing it is being asked about. The chain's other
links (that `SWMESS` is the only poster of `3START`, at `133661`/`133666`) stand on the NPL source and
are unaffected.

### The instrument has been caught this way ONCE ALREADY, and says so

The comment immediately above the tally:

> *"tally EVERY message here, at the single point where micfu is known and BEFORE the switch.
> Counting after the switch missed every micro-function whose case returns early - the start path
> does exactly that, so 23B starts were invisible in the tally even though `startSeen` said one had
> arrived."*

So this exact histogram has already produced one confident wrong absence and been fixed for it. That
is a strong prior for treating a zero in it as "not covered" rather than "did not happen", and it is
why §67 was recorded as a tension instead of a finding.

### What still needs answering for #79

Unchanged and now unobstructed: **does the ND-100 reach `RUNSW`'s `SAA 7` at `163725`** (§66)? That
is a PC-reachability question about ND-100 code, and the `micfu[]` census was never going to answer
it. The corrected PC/PIL sampler is the instrument; it is built and a validation run is in flight.

## 69. TASK 1 LOCATED: during `place-domain` the ND-100 is IDLE, and nothing is trying `[V]` 2026-08-30

First PC/PIL histogram this lane has ever had (log `mudom-pc2.log`, short bring-up, passed 32 min):

```
place-domain cpu-stat : 2049 samples, 99 distinct (PC,PIL)
    PC=0x12C3 pil=0 x415 | 0x12C2 x391 | 0x12C4 x376 | 0x12C5 x374 | 0x12C6 x370
run                   : 1852 samples - the SAME five PCs at pil=0
```

**~94% of samples sit in a FIVE-INSTRUCTION window at PIL 0.** Symbol: `0x12C2` = `0o011302` =
**`PENT0+2`**. `PENT0` is where SINTRAN goes at the END of restart - `PH-P2-RESTART.NPL:685`,
`CALL UPPOW  % POWWER UP TO OCTOBUSS ?` then `GO PENT0`. It is the PASSIVE/IDLE entry.

**So `place-domain` is not spinning, not polling, not walking tables. The ND-100 is IDLE and the
command is blocked waiting for something nothing is producing.**

### The remaining 6% is one thing, and it is noise

| sampled PC | linked | listing (-0o200) | what it is |
|---|---|---|---|
| `0xB616` | `0o133026` | `0o132626` | **`500HIST+2`** - the ND-500 histogram sampler |
| `0xB6CD` | `0o133315` | `0o133115` | inside **`500H3:`** - its process-log-ALL branch |
| `0x27AF` | `0o23657` | - | **`GETC5PROC+8`** - called BY that histogram at `133101` |
| `0xB658` | `0o133130` | `0o132730` | the `% Until no more procs to start` loop region |
| `0x7E78`/`0x472A` | | | `CMLTS`, `DACCE` - PIL-1 device work |

`GETC5PROC` appears because the HISTOGRAM calls it, not because `XTER500` is polling - I assumed the
latter for one step and the listing corrected it. This confirms §20: the dominant ND-500-side traffic
is SINTRAN's clock-driven process-logging sampler, and it is not progress.

### What this rules out

A spin, a hardware poll, a table-walk data condition, and a retry storm - the whole family this lane
has been chasing. In particular it refutes the expectation inherited from
`CARVE-S3SM5-CSLOAD-VERIFY-LOOP-2026-07-21.md`, which predicted a data-condition spin in S3SM5 band
`0o150000..0o155323` and named "a live PC histogram" as its `[OPEN] #1`. **The histogram now exists
and the PC is nowhere near that band.**

### Cross-check that validates §44/§45 rather than undermining them

The harness's watch addresses are LINKED; NPL listing addresses are **+0o200** off (memory
`feedback-friction-lessons-nd5000` #13, per-module). Converting:
 - `5ACTSWAPPER-entry @0o145162` -> listing `0o144762` = `5ACTSWAPPER:` **exact**
 - `HANDOVER-taken-SWACTIVE @0o145211` -> listing `0o145011` = `SWACTIVE; *AAX SWPFU-HSWPI; STATX`
 - `queued-on-swapwait-fifo @0o145312` -> listing `0o145112` = `% - Insert in Swap-wait-fifo`
All three labels are correct, so §44/§45's reading (swapper free -> direct handover, FIFO correctly
untouched) stands. I checked because `145211` looked like it fell inside the ELSE branch; it does
not, once the offset is applied.

### NEXT for task 1

The question is now **WHAT THE PLACE-DOMAIN PROCESS IS WAITING ON** - a process-state question. The
ND-500 side already answered everything asked of it (§31: `ansMON=377B`, `restarts=1/1` Seen==Taken,
swapper parked at the designed idle). So the missing wake-up is on the ND-100 side, and the probe is
the SINTRAN RT/process state of the monitor process during the stall, not another PC histogram.

## 70. THE `3SWMESS` STAMPERS FOUND: S3SM5 `062700` and `104076` `[V]` 2026-08-30

§69 established that `LNEWSWAP` wakes the waiting ND-100 process ONLY on `MICFU == 3SWMESS`
(`135604` -> `135631 GO FAR SWPD2`), that our served message carries `3START` instead, and that
**no NPL source ever writes `3SWMESS`** - four occurrences across all NPL sources and symbol tables,
every one a comparison. So the stamper had to be outside the resident driver. It is.

### Values confirmed from the symbol table, not inherited

`SYMBOLS/L07/N500-SYMBOLS.SYMB.TXT` (names truncated to 5 chars):
```
3SWME=000005      <- 3SWMESS = MICFU 5
3STAR=000023      <- 3START  = 23B
MICFU=000006      <- the MICFU field is word offset 6
```

### The two stampers, in `030-S3SM5.dis`

```
SITE 1 @ 062700                    SITE 2 @ 104076
  062700  SAA 5                      104076  SAA 5
  062701  STA ,X 6   ; MICFU := 5    104077  STA ,X 6   ; MICFU := 5   = 3SWMESS
  062702  JPL I 12   ; call          104100  SAA 24
                                     104101  STA ,X 7   ; SWFUN := 24B = MSWSWAIT
                                     104102  SAA 1
                                     104103  STA ,X 2   ; N5STA := 1   = MSGN500
```

Found by scanning every `SAA 5` / `SAT 5` in the segment for a following store at offset 6 - the
constant alone has dozens of sites, so the field offset is what isolates it.

**Site 2 builds a complete message**: `3SWMESS` + `MSWSWAIT` + `MSGN500`. `MSWSWAIT = 24B` is carved
(`CARVE-ANSWER-N5SWAP-FUNCTION-VOCABULARY-2026-08-17.md`), and `MP-P2-N500.NPL:133775` handles exactly
that: `IF A=MSWSWAIT THEN  % Restart Swapper and wait (after allocate page..)`.

### So the chain is now complete end to end

```
S3SM5 062700/104076   stamp MICFU := 3SWMESS into the message
        |
MP-P2-N500 135604     IF 3SWMESS=D  -> 135631 GO FAR SWPD2  = RESTART THE ND-100 WAITER
        |
        else          restart the ND-500 process instead; the ND-100 waiter sleeps on
```
Measured on this lane: the served message carries `3START` (23B), so the ELSE runs and `place-domain`
is never woken - and the ND-100 sits at `PENT0` idle for 94% of the command (§69).

### NEXT - the same reachability question as task 2, and the same instrument

Does our lane ever REACH `062700` or `104076`? Both are ND-100 code in S3SM5, so the PC/PIL sampler
answers it directly - and neither address appeared anywhere in the 2049-sample histogram (which
covered 99 distinct PCs). That is suggestive, NOT conclusive: a site executed once in a 32-minute run
can easily be missed by a sampler, so **absence here is not evidence** (the same trap as §51's raw
counts and §37's search). Use a PC WATCH on those two addresses, which counts every hit, rather than
a sampler.

`DiagPcWatchList` already exists and produced the `5ACTSWAPPER` call-site table with hit counts and
registers - point it at `062700` and `104076`.

## 71. THE TWO `3SWMESS` STAMPERS DISCRIMINATE: one runs, one never does `[V]` 2026-08-30

PC WATCH (counts every hit, unlike the sampler) on the two S3SM5 sites found in §70, PIL filter OFF
because S3SM5 does not run at level 12. Log `swmess-watch.log`:

```
3SWMESS-stamp@0o062700       hits=2            <- IS reached
3SWMESS-stamp@0o104076       hits=0            <- NEVER reached
CONTROL PENT0+2 (must hit)   hits=79,884,820
```

**One of the two stampers runs twice; the other never runs at all.** That `062700` fires also shows
S3SM5-range addresses do hit, so the "displayed address IS the runtime address" assumption for that
segment is not dead on arrival.

Recall what each is (§70): `062700` is a bare `MICFU := 5`; **`104076` is the COMPLETE message build**
- `MICFU := 3SWMESS`, `SWFUN := 24B (MSWSWAIT)`, `N5STA := 1 (MSGN500)`. It is the one that would
produce a well-formed message for `LNEWSWAP` to wake the ND-100 waiter on, and it is the one that
never executes.

### I broke my own evidence, and the file had already warned about it

The control fired **79,884,820** times and flooded the 60-entry register log, so the **PIL of the two
`062700` hits cannot be read**. That matters: this harness documents a 2026-08-29 run where 232 hits
on `0o145112` were ALL PIL=1 - unrelated level-1 code at the same 16-bit address - because the watch
matches on PC alone. So `hits=2` is currently **[V] that the address executed** and **[OPEN] whether
it was S3SM5**.

The per-address COUNTS are separate counters and survived the flood; only the detail was lost. Fixed
by swapping the control to a RARE address - `5ACTSWAPPER-entry` (linked `0xC672`), which hit exactly
ONCE in the same run, so it proves liveness without swamping the log. Re-run in flight
(`swmess-watch2.log`).

**Choosing a control that fires 80 million times is a self-inflicted version of taxonomy #12** (a
bounded evidence log whose budget the noise spends). The rule that follows: **a liveness control must
be rare by construction, not merely known-good.** "It definitely fires" and "it does not destroy the
log" are two requirements, and I only checked the first.

### Where task 1 stands

```
S3SM5 104076  builds the 3SWMESS message   <- NEVER RUNS
      062700  bare MICFU := 5              <- runs twice (PIL unconfirmed)
        |
MP-P2-N500 135604  IF 3SWMESS=D -> 135631 restart the ND-100 waiter
        |
        else       restart the ND-500 side; place-domain sleeps at PENT0 (94% idle, §69)
```

Next: confirm the PIL of the `062700` hits from the re-run, then find what gates `104076` - that is
the routine whose non-execution leaves `place-domain` hanging.


## 72. TASK 3 IMPLEMENTED - and its "next blocker" is noise, checked before chasing it `[V]` 2026-08-30

### The fix

`Nd5000ControlStoreLink` now implements `CommandPerformRoutineA = 0x0006`, the operation word of the
`0x73B4` write routine (3 callers, all loops, ~20,964 executions per boot - against 8 for `0x0018`'s
single caller). Those writes previously fell into `WriteCommand`'s `default:` and were discarded.

```
                          BEFORE      AFTER
  microwords written        8         20,972    (addresses walk 0o0, 0o13, 0o26 ... stride 0o13)
  discarded command words   21,263    299
  START @0o0                ticks=0   ticks=10000
                            'TESTOBJ=29 not implemented'  ->  'budget'
```

**The microprogram now EXECUTES instead of refusing at tick 0.** Build asserted `EXITCODE=0` before
the run, per the project rule.

The one design problem: routine A latches an address TWICE - a genuine address phase, then again
after the data shift where the newest port word is the LAST DATA HALFWORD and the latch is junk
(`ADDR-LATCH 10DD` = `50DD & 0x3FFF`). The link already measures the discriminator
(`_halfwordsBeforeAddressLatch`: 0 = address phase, 7 = post-data), so `0x0006` commits at the
former. Without that, every microword would land at a garbage address.

### SCOPE - this does NOT touch `hw-cpu`

`Nd5000ControlStoreLink` is referenced ONLY inside `Machines.Accp`; `OctobusND5000Station`
references it ZERO times. The `hw-cpu` round loads the control store through the station's EMULATED
ACCP handlers (`CMWWC`) - a different consumer. So this affects `hw`/`hw-accp` and does not by itself
clear SINTRAN's `Error when loading Control Store` on `hw-cpu`.

### And the newly-revealed "blocker" is NOT WORK

Clearing the first stop exposed:
```
START @0o37760 ticks=1 stop='Operand select DEST=29 not implemented yet'
```
Before implementing anything for it, swept the image:

```
B30 words: 16384        DEST=29 count in B30: 0
DEST values present near it: 24:8588  25:4  26:289  31:253  32:64  33:3
```

**`DEST=29` occurs ZERO times in the real microcode.** `0o37760` is one of the RAM TEST PATTERN words
(§33, §47), so this is pattern noise - exactly as `TESTOBJ=29` was, and note BOTH fields read 29 in
that same word, which is what a random pattern looks like.

**So the next blocker is work REMOVED, not work added.** This is the second time the "restrict to
reachable sites before implementing" guard has deleted phantom work (the first: `ABR,NEXT` 20 raw ->
0 reachable). Keep applying it: a stop message names the first thing that refused, and if the input
is noise that walk has no end (§33's lesson, now paid off twice).

### Still owed for task 3

The selftest remains RED - verdict block `0x001144F0` word[6] = `0000`, needs `0x0100`; and
`stop='budget'` means the tick ceiling, not completion. The honest claim is exactly: **the writes
land and the engine runs.** Validation is the `hw` round, which needs `TIMEOUT_SCALE>=8` (§38).


## 73. TASK 1: the premise was WRONG - 3SWMESS IS produced, once, too late `[V]` 2026-08-30

The task said *"LNEWSWAP only wakes the ND-100 waiter on MICFU 3SWMESS, and ours is 3START"*.
The guard run refutes the second half.

### The address chain, pinned two ways

`swpInfo=0x00008E30` is bank-relative in WORDS. Word `0o43430` = `0x4718` -> byte `0x8E30` ->
physical **`0x428E30` = SWPINFO**. Confirmed independently by the `CONTROL 5ACTSWAPPER@0o145162`
hits, which carry `X=0o43430`. LNEWSWAP's `*MICFU@3 LDATX` reads word offset 6 -> byte +0xC ->
**`0x428E3C`**.

### The measurement (a denominator, so it can be CHECKED - not a single number)

From the live writes-only trace (871,514 entries, chronological - NOT a teardown dump; its own
header declares `writes-only log ... mailbox-nbhd[0x428000..0x42D000)=871514`):

```
  writes to 0x428E3C (the cell LNEWSWAP tests):   314
      0x0000  (nothing to do)                     313
      0x0005  (3SWMESS)                             1     <- the LAST write of the run
  last 0x0000 write ...... trace line 294,853
  the single 0x0005 ...... trace line 879,357     (584,504 events later)
```

**So 3SWMESS IS produced. Once, at the very end, after the stall.** On all 313 earlier passes
LNEWSWAP finds ZERO, `IF 3SWMESS=D` is false, it takes the ELSE and restarts the ND-500 side instead
of waking the ND-100 waiter - which IS the observed `place-domain` sleep at `PENT0` (94% idle).

The final burst writes the whole block in ascending order - `FFFF FFFF 0006 0001 0000 0000 0005
0005 003B 0840 0000 0001` - i.e. a complete message finally being BUILT.

### Which stamper did it: NEITHER of the two we knew

```
  routine-entry@0o104024   hits=0     <- the routine is NEVER ENTERED; neither guard is the answer
  EARLY-EXIT-1@0o104036    hits=0
  EARLY-EXIT-2@0o104042    hits=0
  PASSED-BOTH@0o104043     hits=0
  3SWMESS-stamp@0o104076   hits=0
  3SWMESS-stamp@0o062700   hits=2     PIL=1  X=0o141430
  CONTROL 5ACTSWAPPER      hits=2     <- instrument ALIVE, so the zeros above are real
```

`0o104024` never runs, so the whole guarded build is dead code in this run. And `0o062700`'s
`X=0o141430` = byte `0x18A30` -> physical **`0x438A30`**, which is OUTSIDE the mailbox neighbourhood -
a resident SINTRAN record, **not** the cell LNEWSWAP reads. **A THIRD, UNIDENTIFIED SITE wrote the
one `0x428E3C=0x0005`.** Finding it is the next step, and the watch is already built for it.

### Instrument note

`micfu[1B:52 12B:1 23B:1 24B:1 31B:13]` shows no `5` - and that proves NOTHING here. That histogram
counts SINTRAN -> ND-500 messages only and is structurally blind to 3SWMESS (taxonomy #8, section 68).
The writes-only trace is the instrument that can see it.


## 74. THE ND-5800 B30 MICFU LEGALITY TABLE - byte-verified from the RAW image `[V]` 2026-08-30

Carved straight out of `MICRO-5800-B30.DATA` (16 bytes/word, ABS_ADDR = bits 31..16), NOT a
rendered `.md`.

### How the table was located and CALIBRATED

`MICRO-5800-B30.LABE` puts `MSG_ILLEG` at `0o15221`, referenced by ten arms in one consecutive
run. Dispatch base = `0o15224`, index = MICFU. **Two independent calibration points, both exact:**

```
  arm 0o15246 -> 0o15660   and LABE says MSG_STARTP0 = 015660   (index 0o22 = STARTP0)
  arm 0o15247 -> 0o15671   and LABE says MSG_START   = 015671   (index 0o23 = 3START)
```

A THIRD check falls out and was not designed in: **`0o25 3TRACO` targets `0o15671`, the SAME
handler as `0o23 3START`** - which the bus reference states independently ("3START/3TRACO share a
handler"). Three agreements, so the base is not a coincidence.

### The table

```
  LEGAL   0o1 3RMICV  0o10 DMEMRD  0o11 DMEMWR  0o12 CACHE  0o13 RESIRD  0o14 RESIWR
          0o22 STARTP0  0o23 3START  0o24 3MONCO  0o25 3TRACO  0o26 3WMONCO
          0o30 PHYSRD  0o31 PHYSWR  0o34 3MONO  0o35  0o42  0o44  0o45  0o46 33MON  0o47
  ILLEGAL 0o0 0o2 0o3 0o4 **0o5 3SWMESS** 0o6 0o7 0o15 0o16 0o17 0o20 0o21
          **0o27 3FITRNSF** 0o32 0o33 0o36 0o37 0o40 0o41 0o43
```

### What it settles for TASK 1

**MICFU `0o5` (3SWMESS) is ILLEGAL on the ND-5800 - it dispatches to `MSG_ILLEG`.** So 3SWMESS is
never a MICFU the CPU executes.

That RESOLVES the ambiguity section 73 flagged rather than confirming a fear: the `MICFU=5` that
LNEWSWAP reads out of SWPINFO is a **marker for the ND-100 driver's own routing decision** ("is
this a message to the swapper?"), NOT a command sent to the CPU. The two uses of the field are
genuinely different, and this microcode result does **not** contradict LNEWSWAP. Conflating them
would have produced a confident wrong answer in either direction.

### What it exposes in OUR code (actionable, and NOT a blanket widening)

`Nd500MicrocodeServicer` logs an "ND500 DIVERGENCE" when it services a MICFU the classic dispatch
table rejects - but the guard is `Generation == Nd500Generation.ND500`, so it is silent on the
ND-5000 lane. The B30 rejects `0o5` and `0o27` **as well**, so the same divergence exists un-flagged
on our lane.

**But it must NOT be widened wholesale: `0o22 STARTP0` is LEGAL on the 5800 and ILLEGAL on the
classic.** The generations really do differ, which is exactly why the guard was generation-scoped
in the first place. Extend it for `0o5` and `0o27` only.

Honest status: the `micfu[]` histogram shows no `0o5` posted to the CPU in any run so far, so this
is a LATENT gap, not an active bug. Worth closing because a serviced-but-illegal MICFU "fails
quietly, by working" - the servicer's own comment makes that argument.

### Also newly surfaced, for task 4

`0o35`, `0o42`, `0o44`, `0o45`, `0o47` are LEGAL arms with real handlers and NO name in our tables.
They are MICFUs the hardware implements that we may not model at all.


## 75. OUR 22 MICFUs vs THE B30 TABLE - six we service that hardware rejects, four it has that we lack

Cross-reference of `N5MicroFunction` (22 members, `N5MailboxProtocol.cs`) against the byte-verified
table in section 74.

### A FOURTH calibration point, from a source not used to build the table

The five legal-but-unnamed arms resolve in `N500-SYMBOLS.SYMB` (names truncated to 5 chars):
`0o35=3WMEP  0o42=3PRTR  0o44=3RPRE  0o45=3MPCL  0o47=3IDLE`. **`0o44 = 3RPRE = 3RPREG`** - and the
servicer's own comment says the CLASSIC table's `0o44 3RPREG` lands on a word that is literally
`ALU,ADIR A,P D,DP`, a read of the P register. Independent of the LABE, of MSG_START/MSG_STARTP0
and of the 3TRACO agreement. Four confirmations; the indexing is settled.

### MODELLED BY US, ILLEGAL ON THE B30 `[V]` on the arms

```
  0o5  MessageToSwapper   -> MSG_ILLEG      (guard added)
  0o16 ExamineRegister    -> MSG_ILLEG
  0o17 DepositRegister    -> MSG_ILLEG
  0o20 RegisterRead       -> MSG_ILLEG
  0o21 RegisterWrite      -> MSG_ILLEG
  0o27 FileTransfer       -> MSG_ILLEG      (guard added)
```

The four register ones are NOT an alarm, and the reason is `[D]`: **`0o44 3RPREG` IS legal**, so on
the 5800 register access plausibly moved to 3RPREG while the classic generation used `0o20`/`0o21`.
That is self-consistent - SINTRAN's LOOK-AT-REGISTER has to work somehow, and 3RPREG is the arm that
exists. Graded DERIVED: the arm targets are measured, the migration story is inference. Settle it by
finding what FUNCS 000/001 (REGRE/REGWR) actually posts on this lane before changing any behaviour.

### LEGAL ON THE B30, NOT MODELLED AT ALL

```
  0o42 3PRTR    0o45 3MPCL    0o46 33MON    0o47 3IDLE
```

Real handlers in silicon that our enum has no member for. Feeds task 4 - and note the MON-PATH-LEDGER
test enforces a row per member, so adding any of these means adding ledger rows, not just enum values.

### What NOT to do with this

Do NOT mass-refuse the six. The servicer's existing argument applies unchanged: refusing a path
nothing has been observed to take is a speculative behaviour change, and a serviced-but-illegal MICFU
"fails quietly, by working" - so LOG it, and let a run that actually posts one make the case. No run
so far posts any of the six to the CPU.


## 76. DECODING RULE: `SAA n` before a `JPL I` is a HELPER SELECTOR, not a MICFU and not a SWFUN

Nearly published a false fact 2026-08-30 and caught it on the store, so the rule is written down.

`REGRE` (FUNCS 000, @142365) opens:

```
  142365  SAA 16        <- 0o16 is EXACTLY the MICFU value ExamineRegister
  142366  JPL I 45   -> 142433
  ...
  142373  LDA ,X 41     <- the value that actually reaches the message
  142377  LDX ,B -67
  142400  STA ,X 7      <- ...is stored here, from LDA, NOT from the SAA
```

Read carelessly this says "REGRE posts MICFU 0o16", which chains straight into section 75's table
("0o16 is ILLEGAL on the B30") and yields the dramatic conclusion that LOOK-AT-REGISTER cannot work
on a 5800. **That conclusion would have been wrong**, and it would have looked well-sourced: a
measured table, a real listing, and a number that matches on the nose.

**The rule:** in this code `SAA n` immediately before `JPL I <helper>` is the SELECTOR the helper
switches on. The value that lands in the message is whatever a LATER `STA ,X <offset>` stores, and it
usually arrives from an `LDA`. Follow the STORE, never the nearest preceding constant.

Same shape appears in RUNSW (section, task 2): its `SAA 36` / `SAA 17` are helper selectors, while
the SWFUN values 0 / 20B / 41B come from the separate `STA ,X 7` stores. That reading is unaffected.

**Consequence for section 75:** the `[D]` about register access migrating to `0o44 3RPREG` on the
5800 is STILL UNSETTLED. It was not confirmed by this and must not be recorded as if it were. To
settle it, find what REGRE's helper at `142433` does with its selector - that is the routine that
knows whether a MICFU is posted at all.

This is the number-coincidence trap: a value that matches a meaningful constant from a DIFFERENT
namespace. The check is one question - "what actually WROTE the field?" - which is the same question
[[verify-provenance-not-plausibility]] already names.


## 77. CORRECTION TO SECTION 76 - right rule, WRONG STORE. Now genuinely `[OPEN]`

Section 76 declared "`SAA n` before a `JPL I` is a helper selector, NOT a MICFU". **That is not
established, and the reasoning behind it was faulty.**

Reading the shared helper `0o63007` itself - the one BOTH RUNSW and REGRE call - shows it is a
MESSAGE BUILDER:

```
  063012  LDX ,B -67     <- the message block
  063013  STA ,X 6       <- MICFU := A        *** the MICFU store ***
  063014  SAA 1
  063015  STA ,X 2       <- N5STA := 1 (MSGN500)
  063016  LDA ,B -60
  063017  STA ,X 3       <- SENDE
  063020  LDA ,B 0
  063021  STA ,X 4       <- X5CPU
```

### What went wrong, because the shape will recur

Section 76's rule - **follow the STORE, not the nearest preceding constant** - is correct. I then
applied it badly: I followed REGRE's visible `STA ,X 7` at `142400` (offset 7) and concluded the
`SAA` value never reaches the message. But the store that matters for MICFU is at **offset 6**, and
it lives INSIDE the shared helper, off the page I was reading. **Following *a* store is not
following *the* store for the field in question.** Name the field first, then find the store to
THAT offset - across call boundaries if necessary.

### What is actually known now

`[V]` `0o63007` writes MICFU from `A`, and stamps N5STA=1 / SENDE / X5CPU. It builds the message.
`[OPEN]` whether `A` at `063013` is still the caller's `SAA n`. It depends on the return path of the
`JPL I` at `063011` (ND-100 convention: P+1 vs P+2, and the bus reference records SKIP=success /
DIRECT=error), and on what the callee at the `063024` pointer leaves in A. **Not resolved, and I am
not going to flip to the opposite confident answer to tidy this up.**

### Consequences to respect until it IS resolved

 - Section 75's `[D]` about register access moving to `0o44 3RPREG` stays `[D]`. It is now LESS
   comfortable, not more: if REGRE's `SAA 16` does reach MICFU, REGRE posts `0o16`, which section
   74 measured as ILLEGAL on the B30.
 - RUNSW's `SAA 7` at `0o163725` is the same question. `7` would be an ILLEGAL MICFU, whereas
   MSWSTART=7 as a SWFUN in offset 7 is exactly what the ladder expects - and `N5MailboxProtocol`
   documents offset 7 as an OVERLAY ("SWFUN if MICFU=3SWMESS, else N500A"). Both readings are
   live; the overlay is precisely what makes the two hard to tell apart.
 - The task-2 watch is unaffected: its four block arms are branch addresses, which do not depend on
   this at all.

**To settle it:** resolve the `JPL I` return convention at `063011` and read the callee behind the
`063024` pointer. One careful pass, no run needed.


## 78. TASK 3 RETRACTED - and section 55 had already told me not to do it `[V]` 2026-08-30

### The measurement

`LoadControlStoreCommand_DrivesTheAddressedWritePath` (the EXISTING ACCP suite, 141/142 otherwise
green) run both ways, 27 s each, by stashing only `Nd5000ControlStoreLink.cs`:

```
  WITHOUT my 0x0006 case:  PASSED   writes 8 -> 9        one write, correct data
  WITH    my 0x0006 case:  FAILED   writes 20972 -> 20974  two writes, first misaligned
```

**I introduced the regression.** The baseline trace shows the console path completing through
routine B's `0x0018` AFTER the address is re-shifted as the ninth gated word:

```
  11: SHIFT 0100                <- the address AGAIN
  12: ADDR-LATCH 0100 halfwords=0
  13: COMMIT cmd=0x0018 addr=0x0100 112233445566778899AABBCCDDEEF001   <- correct, ONE write
```

My arm commits before that with the address word still inside the 8-halfword window, producing
`0100112233445566778899AABBCCDDEE`, and then the legitimate commit follows.

### THE ARGUMENT THAT SETTLES IT, available with no run at all

Section 55 recorded both routines:

```
  ROUTINE A @0x73B4   address phase, jsr $7776 SHIFT 128 BITS, then #$3010 / #$0006 / #$0010
  ROUTINE B @0x73F0   address phase, NO SHIFT,                 then #$3010 / #$0006 / #$0010
```

**Identical triple; B shifts no data.** If `0x0006` meant "commit the shifted microword", routine B
would commit garbage on every call. It cannot mean that. `0x0006` performs whatever operation the
preceding `0x3010` latch SELECTED - A being the write (data shifted first), B the read-back. That is
the natural reading of a write/read pair sharing one perform opcode.

### The process failure, which is the more useful lesson

Section 55 graded it `[D]`, not `[V]`, and said in its own words:

> *"the implementation question is not 'add a case for `0x0006`'. It is: what does the
> `0x3010`/`0x0006`/`0x0010` triple mean... **Routine B - same triple, no data - is the CONTROL that
> answers it**, because whatever the triple does without data is what it does with the address alone."*

**I added a case for `0x0006`.** The control was named one paragraph from the thing I implemented,
and the grade on the claim was `[D]`. Same shape as the standing memory note: *writing down the
objection is not obeying it.* A `[D]` grade is an instruction to go get evidence, not a licence to
build on it - and the counts (8 vs ~20,964) were seductive precisely because they FIT.

### What survives, and what does not

`[V]` still true: `0x0006` is written ~20,964 times per boot and WAS being discarded by the
`default:` arm. The routine-A/B structure and their ROM addresses stand.
**RETRACTED:** "microwords 8 -> 20,972" as PROGRESS. If `0x0006` is not a per-microword commit, those
were ~20,964 WRONG writes - which independently explains why the selftest verdict word never moved to
`0x0100`. **A count that goes up is not evidence the data is right.**

Tree state: the change is STASHED, tree at HEAD, that test GREEN.

### Next

Carve what the `0x3010` latch value SELECTS (write vs read), then model the triple as
select-then-perform rather than as a second commit opcode. Routine B is the control for every step of
that, exactly as section 55 said.


## 79. THE COMMAND ENCODING REFUTES "0x0006 is a second perform" INDEPENDENTLY `[V]` 2026-08-30

Section 78 killed the claim with routine B (same triple, no data). The command-word ENCODING kills it
a second time, from a different direction - and this evidence was sitting in our own constants.

`Nd5000ControlStoreLink` already names a family of `0x220000` command words:

```
  0x0018  CommandPerform          0x2018  CommandOperation
  0x2010  CommandVerify           0x3010  CommandAddressLatch     0x0010 / 0x000F  clock pair
  0x2011  CommandShiftInWord      0x0017  CommandMicroprogramArm  0x0015  CommandStrobe
```

The shape is `<selector><operation>`: `0x0018`/`0x2018` share operation byte **`0x18`**;
`0x2010`/`0x3010`/`0x0010` share **`0x10`**; `0x2011` is `0x11`.

**`0x0006` shares its operation byte with NOTHING in the family.** It is not a selector variant of
the perform `0x18` - it is a different operation entirely.

### Why I believed otherwise

Section 55's wording: *"`0x0006` sits in the structural position `0x0018` occupies in the known
path: after the address, as the operation."* That is an argument from **POSITION IN A ROUTINE**, and
position is exactly the kind of evidence this project has been burned by before - it is the same
class as "adjacency is not dispatch" (octobus skill trap 7) and the `.LABE` neighbour that produced
two wrong dispatch claims. **The encoding is structural evidence; the position is circumstantial.**
When the two disagree, the encoding wins.

Two independent refutations now agree: routine B (behavioural) and the operation byte (structural).

### Where that leaves the triple

`0x3010` (latch address) -> `0x0006` (operation 06, meaning UNKNOWN) -> `0x0010` (ClockA). Whatever
`0x06` is, it is performed with an address latched and a clock behind it, in BOTH the data-shifted
(A) and no-data (B) routines. Carve `0x06` on its own terms; do not model it as a commit.


## 80. RESOLVED (sections 76/77): `SAA n` DOES reach offset 6 - of a RESIDENT block, NOT the mailbox

Section 76 said "selector, not a MICFU". Section 77 retracted that as unproven and left it `[OPEN]`.
Here is the close, with the two halves separated - because they are different questions and mixing
them is what produced both earlier errors.

### Half 1: does `A` survive to the store? YES `[V]`

```
  063007  STF ,B -54     <- helper entry SAVES the caller's float accumulator (T,A,D) to B-54
  063011  JPL I 13    -> 0o44030
    044031  STA ,B -50   <- callee saves A
    044032  LDA 46       <- ...and clobbers it
    044045  LDA ,B -50   <- restores it
    044051  LDF ,B -54   <- reloads the float accumulator - A comes back from the helper's own save
    044053  EXIT         <- DIRECT return, so control lands on 063012
  063012  LDX ,B -67
  063013  STA ,X 6       <- stores the CALLER'S SAA value
```

So the `SAA n` value really does reach offset 6. Section 76's stated reason was wrong.

### Half 2: is offset 6 of THAT block the mailbox MICFU? NO `[V]` by measurement

The block comes from `,B -67`, and we have a MEASURED address for it. The guard run's
`3SWMESS-stamp@0o062700` hit carries `X=0o141430` -> byte `0x18A30` -> physical **`0x438A30`**, which
is OUTSIDE the mailbox neighbourhood `[0x428000..0x42D000)`. The cell LNEWSWAP reads is `0x428E3C`.

**Different structure, different namespace.** `,B -67` offset 6 is a function code in the RESIDENT
swapper-message record; the mailbox MICFU lives at `0x428E3C`. Section 76's CONCLUSION (different
namespace) was right; its ARGUMENT (the SAA never reaches a store) was wrong.

### The lesson worth keeping

Two questions were being answered as one:
 1. *does this value reach a store?* - answered from the listing.
 2. *is that store the field I care about?* - answered only by an ADDRESS.
Section 76 got 1 wrong and 2 right; section 77 corrected 1 and then doubted 2 along with it. **Ask
which structure a store targets BEFORE arguing about what the value means** - the same "what object
is this?" discipline as taxonomy #19, applied to a memory write instead of an instrument.

### Consequences

 - Section 75's `[D]` on register access is UNAFFECTED and stays `[D]`: REGRE's `SAA 16` goes to the
   resident block, so it is NOT evidence that REGRE posts an illegal mailbox MICFU. The alarming
   reading in section 77 is withdrawn.
 - RUNSW's `SAA 7` likewise sets a resident SWFUN-style code, consistent with MSWSTART=7. The plan's
   reading of the ladder stands.
 - Task 2's watch is unaffected either way - its arms are branch addresses.


## 81. TASK 1 ANSWERED: the single 3SWMESS is written from RESIDENT SINTRAN at 0o11162 `[V]` 2026-08-30

Single-test run (31m57s), pack override confirmed on log line 3, test PASSED.

### The answer

```
  CELLW #5997660  =0x0005  PC=0o11162  PIL=2  thread=15  L=0o12001
```

**One write of 0x0005 in the whole run, from PC 0o11162 at PIL 2, called from 0o12001.**

`0o11162` is a LOW address - S3SM5 starts at `40000B` - so the writer lives in **RESIDENT SINTRAN**,
not in the ND-500 system monitor. That is why neither S3SM5 stamper ever matched: `0o104024` is never
entered and `0o062700` writes a different block. **The search was in the wrong segment all along.**

### Reproducibility - the check the first measurement could not provide

| | guard run (33 min, whole class) | this run (32 min, single test) |
|---|---|---|
| writes to `0x428E3C` | 314 | **314** |
| `0x0000` | 313 | **313** |
| `0x0005` | 1 | **1** |

Two independent runs, identical split. Section 73's numbers are confirmed, not a one-off.

### WHO WRITES THE 313 ZEROS - and a CORRECTION to section 80

```
  66  PC=0o104266      64  PC=0o63013      18  PC=0o133660     15  PC=0o145525
  66  PC=0o104242      44  PC=0o104601     18  PC=0o133625     15  PC=0o135367
```

**`0o63013` is the `STA ,X 6` inside the shared helper** analysed in section 80 - and it writes THIS
cell, at `0x428E3C`, sixty-four times.

Section 80 concluded that the `,B -67` block is a RESIDENT record and therefore never the mailbox. It
based that on ONE measured instance (`0o062700`'s hit carrying `X=0o141430` -> `0x438A30`). **That
generalisation is WRONG.** `,B -67` is a per-context pointer: for some callers it is a resident
record, for others it IS the mailbox message. Both are true, and the address decides which.

So the half-2 answer in section 80 stands only for the instance it measured. **The `SAA n` value CAN
reach the mailbox MICFU** - it just happened to be 0 on all 64 of these calls, which is why every one
of them stores `0x0000`.

**The generalisation error, named:** one address measured, a rule inferred for all callers of the
same instruction. The fix is the same discipline that produced the correct half of section 80 - ask
what object THIS store targets, per call site, not once for the routine.

### What is still open

Identify `0o11162`. No `.dis` in the carve set covers it (`003-S3CP`, `006-S3FS`, `030-S3SM5`,
`045-S3ISYS` are all higher); the resident image is `MACM-1718K-loaded-image.bin`. Once named, the
question becomes why that site runs ONCE, at the very end, instead of whenever the swapper needs work.
