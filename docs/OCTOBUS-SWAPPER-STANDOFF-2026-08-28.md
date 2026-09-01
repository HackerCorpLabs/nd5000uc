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

> **CORRECTED 2026-08-31 (see section 146): "known, carved" must NOT be read as "understood engine
> defect".** The classic lane retracted exactly that framing today — the 5SWAP protect violation is
> **no longer reproducible**, and its two causes were both OUTSIDE the emulator: the harness attached
> no ND-500 CPU before PLACE-DOMAIN, and a `DEFINE-SWAP-FILE` **definition does not survive a cold
> start** (the pack carried the swap FILE; the DEFINITION was what was missing). The address and the
> trap are still correctly measured; what is wrong is treating them as a property of the engine.

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


## 82. THE -0.0 FLOAT TEST IS OUR BUG, BYTE-PROVEN: the microcode has NO width-specific sign path

Ronny adjudicated 2026-08-30: investigate as our bug, change nothing. The trace confirms it in one
step, and the evidence is byte-level rather than inferential.

### The entry stubs are the same code

```
  TESTF   0o3000: 4000001E7E0085000000020F06010004
  TESTD   0o3002: 4000001E7E0085000000020F06030004
                                          ^^^^  differs ONLY in the jump target word
  TESTF+1 0o3001: 20000001288180000000000006790000
  TESTD+1 0o3003: 20000001288180000000000006790000   BIT-IDENTICAL
```

Both fall into the SAME shared body, `TESTFD` @ `0o3171` (the LABE confirms: `TESTFD 003171*
003001 003003`). **There is no width-specific sign handling anywhere in the B30 float-TEST path.**

### Therefore the chip is not the source of the disagreement

Our engine reports single `-0.0` S=0 and double `-0.0` S=1. Identical microcode cannot produce that
split by itself - and it does not, because **the double answer never comes from the microcode**. It
comes from a C#-side net-effect recompute scoped to `Mpc 003171` + `InstrDt 5`, which
`DoubleTestFlagTests` documents in its own words. So:

```
  single -0.0  ->  runs the REAL microcode      ->  S=0
  double -0.0  ->  runs OUR C# recompute        ->  S=1
```

**The asymmetry is ours.** `FloatTestFlagTests` already suspected this ("SELF-INCONSISTENT with the
double path ... tilts it toward an OUR-engine bug"); this is the proof, and it also matches the
precedent in the same file, where the double `Z` case turned out to be a plain C# bug against the
cited reference rather than a microcode tie-break.

### The near-miss worth recording

I first asked Ronny to adjudicate this as a principled microcode rule, "S = sign AND NOT zero", and
he approved that framing. **It was wrong, and applying it to both widths would have CREATED a
divergence on the double path that currently agrees** (functional S=0 vs microword S=1). The
existing tests said so plainly; I had not read them before asking. An approval obtained on a bad
framing is not a mandate - re-asking with the corrected evidence cost one message and avoided
writing a self-inflicted defect into `Test.cs`.

### What to do next

Do NOT change `Test.cs`. The question is now narrow: what does the shared `TESTFD` body actually
compute for the sign, and is the C# recompute at `Mpc 003171` masking a fault in that path rather
than fixing one? Remove or bypass the recompute and see what the microcode gives for double `-0.0` -
if it also gives S=0, the two widths agree again and the whole divergence collapses into one
question about `TESTFD`'s sign source.

Also check what `0x7FC00000` really selects: it is NOT an IEEE-754 single magnitude mask (`0x7FFFFFFF`
would be), and the ND-500 float format is not IEEE - so "magnitude mask" may itself be a
mis-description carried forward in the comments.


## 83. CORRECTION TO 82: the -0.0 divergence DOES NOT EXIST any more. It was fixed; only the comments lie

Ran the suites instead of reading their prose. **`FloatTestFlagTests` + `DoubleTestFlagTests`: 12/12
PASS.**

`FloatTest_NegZero_KnownDivergence` asserts:

```csharp
  Assert.That(r.Micro.Sgn, Is.EqualTo(1),                  "float -0.0: S=1 ... microword measures 0");
  Assert.That(r.Micro.Sgn, Is.EqualTo(r.Functional.Sgn),   "S must match functional (microword diverges here)");
```

**Both pass.** So the microword reports **S=1** for single `-0.0` and it EQUALS the functional core.
The double suite passes on the same basis. There is no divergence to adjudicate.

### Everything that was built on the stale text

 - **Task 5's premise** ("microword says sign AND NOT zero, functional says raw sign bit") - FALSE today.
 - **My section 82 framing** ("our engine reports single S=0, double S=1") - FALSE today. Its
   byte-level facts survive (TESTF/TESTD stubs differ only in the jump target, both entering TESTFD
   @0o3171 - that is measured and still true), but the DIVERGENCE those facts were explaining is gone.
 - **`FloatTestFlagTests`' own mechanism note** - independently wrong on its face: it says the sign is
   read off the value masked with `0x7FC00000`, but that mask CLEARS BIT 31, so every negative float
   would report S=0. The suite's own `-1.0` case (`0xBF800000`) expects and gets **S=1**. The stated
   mechanism cannot be what the microcode does.
 - **The question I put to Ronny twice** was built on all of the above.

### The rule this cost, again

*Status headings in this tree have lied; check the CODE before investigating anything marked open -
more than half the time it is already done.* That is written in the octobus skill, it is in memory,
and I still spent this stretch reasoning from a test's COMMENTS and NAME rather than running it. **A
test named `..._KnownDivergence` whose assertions demand AGREEMENT is a fixed bug wearing its old
label.** Read the assertions, not the name; and run it before theorising about it - this one takes
394 ms.

### What is actually left here

Nothing blocking. Two clean-ups, both cosmetic-but-load-bearing because they mislead:

 1. Rename `FloatTest_NegZero_KnownDivergence` / `DoubleTest_NegZero_KnownDivergence` - they now PIN
    correct behaviour, so the names invert their meaning - and delete the stale mechanism paragraph
    that the `-1.0` case refutes.
 2. The DOUBLE flags still come from the C# recompute at `Mpc 003171` + `InstrDt 5` rather than from
    the microcode. That is a real design note (our code, not the chip, produces the double answer),
    but it is NOT a divergence and NOT urgent. Its own comment documents the reason: the two-word
    float-test path loads only one 32-bit half into SC1, so the high half never reaches the flag
    logic.


## 84. SECTION 83 IS WRONG - the -0.0 divergence IS real. My green suite EXCLUDED the deciding test

Section 83 claimed the divergence no longer exists, on the strength of "12/12 PASS". **Retracted.**

### The measurement that settles it

Run the test directly, filtered by its exact `FullyQualifiedName`:

```
  FloatTest_NegZero_KnownDivergence   FAILED  [304 ms]
    float -0.0: S=1 (sign bit set) - microword measures 0
    Expected: 1   But was: 0
```

**Microword S=0, functional S=1 for single `-0.0`. The divergence is real**, exactly as the task
originally said.

### How the green suite lied, and it is a NEW instrument failure worth naming

I ran both suites with a CLASS-level filter and read "Passed: 12, Skipped: 0". But the two files hold
**5 + 8 = 13** cases. The thirteenth is `FloatTest_NegZero_KnownDivergence`, marked **`[Explicit]`** -
which NUnit does not run under a class filter **and does not report as skipped**. It simply is not in
the totals.

So the suite reported a clean 12/12 while silently omitting the ONE case the whole question turned on.
Every number in that report was true. The report was still worthless for the question I asked of it.

**Taxonomy entry: A PASS TOTAL THAT SILENTLY OMITS CASES.** Distinct from the earlier entries -
this is not a number that cannot be checked (#7) or one that cannot be relevant (#8); it is a number
whose DENOMINATOR is quietly smaller than you think, and "Skipped: 0" actively reinforces the wrong
reading. **The check: reconcile the expected case count against the reported total, and grep for
`[Explicit]`/`[Ignore]` before believing any green suite.** 13 expected, 12 reported - one line of
arithmetic would have caught it, and I did that arithmetic only because the `[Explicit]` attribute
caught my eye afterwards.

### What survives from sections 82 and 83

 - `[V]` **The byte-level facts stand.** `TESTF 0o3000` and `TESTD 0o3002` differ ONLY in the
   jump-target word; `TESTF+1` and `TESTD+1` are bit-identical; both enter `TESTFD @0o3171`. There is
   no width-specific sign path in the microcode.
 - `[V]` **The double path passes only via OUR C# recompute** (`Mpc 003171` + `InstrDt 5`), which never
   uses the microcode's flags. That asymmetry remains the prime suspect for why the two widths behave
   differently in our engine.
 - `[V]` **The mechanism note in `FloatTestFlagTests` is still wrong on its own terms**, independently
   of all the above: it says the sign is read off the value masked with `0x7FC00000`, but that mask
   CLEARS BIT 31, so every negative float would report S=0 - and the suite's own `-1.0` case
   (`0xBF800000`) expects and gets S=1. Whatever yields S=0 for `-0.0`, it is not "the sign read after
   that mask".

### Standing instruction, unchanged and now correctly based

Ronny: investigate as OUR bug, change nothing. `Test.cs` stays as committed. The next step is to trace
`TESTFD` and find where the sign actually comes from for a 32-bit operand - and why `-0.0` differs
from `-1.0` on that path.


## 85. Identifying 0o11162 is BLOCKED on a base address - and the check that caught it

Section 81 found the single 3SWMESS write at `PC=0o11162 PIL=2 L=0o12001`, in RESIDENT SINTRAN. The
obvious next move is to disassemble it. **That is blocked, and the reason matters more than the block.**

No `.dis` in the carve set covers that range (`003-S3CP`, `006-S3FS`, `030-S3SM5`, `045-S3ISYS` all sit
higher). The only resident artefact is `MACM-1718K-loaded-image.bin` (31,352 bytes = 15,676 words).
Reading word `0o11162` out of it at face value gives `146056`, which looks like a plausible ND-100
register operation - so a decode would have "worked".

**The falsification came from the OTHER address.** `L=0o12001` is a RETURN ADDRESS, so it must point at
code. Dumped as ASCII, `0o11770..0o12015` reads:

```
  ===..== M A C M - 1 7 1 8 - K ==..========
```

`0o12001` is inside the image's own **version banner**. A return address cannot point into a text
string, so **this image's word offsets do not correspond to the running PC address space** - it needs a
load base that is not yet established.

Had I decoded only `0o11162`, nothing would have contradicted me and the identification would have gone
into the record as fact. This is [[verify-provenance-not-plausibility]] and taxonomy #13 (a listing
address is not a linked address) in the same shape as the `+0o200` MP-P2-N500 offset.

**The technique worth reusing: when you have TWO addresses from one measurement, check the one whose
TYPE constrains it.** A PC can point at anything that decodes; a RETURN address must point at code. The
constrained one is the calibration, and here it cost one ASCII dump.

### To unblock

Establish the load base of the resident image (or find the module that owns `0o11162`), then re-read
both addresses. Until then `0o11162` stays `[OPEN]` - the MEASUREMENT of where the write comes from is
solid, only the NAME of the routine is missing.


## 86. TASK 1: the 3SWMESS is MOVED into the mailbox, not stamped there. Resident routine 0o11144 `[V]`

Section 85 was blocked on a load base. Unblocked: the right artefact is
`versions\L-VSX-500
esident\SINTRAN-DATA_commoncode.bin` (resident "Common Code Restart/Start",
**seg addr 0B, base 0x0000**, 64512 words), which the carver documents in
`EXTRACTING-RESIDENT-CODE.md` - and it ships a disassembly, `SINTRAN-DATA_commoncode.dis`.
`MACM-1718K-loaded-image.bin` was simply the wrong file (the MACM area is based at **30000B**).

**Calibration re-run on the constrained address:** at this base `0o12001` decodes as `LDD I 22`
among plausible instructions, no longer landing inside a text banner. Base accepted.

### The code

```
  011144                                  <- routine entry (see call site below)
  011150..011156   compare / JMP -6       <- a SEARCH LOOP over a list
  011157  144075   SWAP SX DA             ; swap X and A
  011160  052000   LDT ,X 0               ; T := mem[X]
  011161  002000   STZ ,X 0               ; mem[X] := 0        <- writes a ZERO
  011162  144075   SWAP SX DA             <- THE RECORDED PC
  011163  012000   STT ,X 0               ; mem[X] := T        <- writes the VALUE
  011164  054357   LDX -21
  011165  146142   EXIT
```

**Call site confirmed, and it reconciles the whole measurement:** `0o12000 JPL I 20` resolves through
the pointer word at `012020`, which holds **`011144`** - the routine entry. It returns to `0o12001`,
**exactly the `L` the cell report recorded**. PC, L and the call chain all agree.

### What it means

This is an **exchange / dequeue primitive: move a word from one cell to another and ZERO the source.**
The `0x0005` attributed to `0o11162` was actually stored by `STT ,X 0` at `011163` - precisely the
"PC names a neighbourhood, not the storing instruction" caveat, now vindicated rather than merely
warned about.

**So this routine did not DECIDE to send 3SWMESS - it MOVED it.** The value was stamped into a staging
cell somewhere else and transferred into the mailbox MICFU by a generic word-mover. That explains every
dead end in sections 73 and 81 at once: no S3SM5 "stamper" was ever going to match the mailbox write,
because the mailbox write is a MOVE, not a stamp.

It also explains the zero census. The same primitive writes `0` at `011161` on every pass (it clears
the source), which is exactly the shape of "313 zeros and one value" - most passes move nothing
interesting, and the zeroing half is what the trace mostly sees.

### Next

The question moves UPSTREAM and gets sharper: **which staging cell feeds this exchange, and who stamps
`3SWMESS` into it?** The search loop at `011150..011156` walks a list to pick the entry - find what
list, and the sender is the thing that queued onto it. That is a much better question than "which
stamper writes the mailbox", which was unanswerable because nothing does.


## 87. CAVEAT on section 86: the single `0x0005` may be a LINK VALUE, not 3SWMESS

Reading `0o11144` in full changes what its write MEANS, and the earlier reading must not stand
unqualified.

```
  011144  STX -1              ; save X
  011145  RADD CLD SX DT      ; T := X            (the item to find)
  011146  LDX 20              ; X := mem[0o20]    <- LIST HEAD
  011147  RADD CM1 CLD 0 DD   ; D := -1           <- the queue SENTINEL
  011150  SKP IF DX UEQ SD    ; end of list?
  011152  LDA ,X 0            ; A := the LINK FIELD at offset 0
  011153  SKP IF DA UEQ ST    ; is this the node we want?
  011155  RADD CLD SA DX      ; advance to next
  011156  JMP -6              ; loop
  011157..011163              ; the exchange, writing mem[X+0]
```

**It is a linked-list UNLINK: head at `mem[0o20]`, sentinel `-1`, link field at OFFSET 0.** The `-1`
sentinel matches the documented mailbox "queue sentinel -1", so this is very likely the message-queue
chain.

### The problem this creates for section 81's reading

The primitive reads and writes **offset 0 of a NODE** - the LINK. Our observed write landed at
`0x428E3C`, which is MICFU only if the node base is `0x428E30`. If instead the node base IS
`0x428E3C`, then the word written is a **link/index**, and the value `5` is a NODE NUMBER that merely
COINCIDES with `3SWMESS = 5`.

That is exactly the number-coincidence trap recorded in sections 76 and 79 - a value matching a
meaningful constant from a DIFFERENT namespace. I have now hit that shape three times tonight, and it
is the one that survives every check except asking what the field IS.

### Both readings are still live

 - **MICFU reading:** `MP-P2-N500` genuinely reads MICFU at SWPINFO+6 and compares it to `3SWMESS`.
   That code is real and quoted. A message whose MICFU is 5 is a real thing.
 - **LINK reading:** this primitive genuinely writes offset 0 of a chain node, and message designs of
   this era commonly REUSE a field as the queue link while the message sits on a free/pending chain -
   `N5MailboxProtocol` already documents offset 7 as an overlay, so overlaying is the house style here.

### What settles it, cheaply

 1. Read `mem[0o20]` (the list head) during a run and see whether the chain nodes are message bases
    (`0x428E30`-style) or the `+0xC` cells.
 2. Instrument the OTHER cells of that message at the same trace index (`#5997660`) - if `N5STA`,
    `X5CPU` and the rest were written around it, it is a message being built; if only that one word
    moved, it is a link.
 3. The cell-writer report already supports this: point `RETROCORE_ND5000_CELLWATCH` at `0x428E30`
    (the message base) and re-run - the write pattern around the same trace index answers it.

**Until then, section 81's "3SWMESS IS produced, once" is `[D]`, not `[V]`.** The 314/313/1 split and
the writer's identity remain `[V]` - it is only the MEANING of the 5 that is now open.


## 88. THE HEADLINE WAS WRONG: 3SWMESS is posted **11 times**, not once. My watch read the wrong half

Sections 73, 81 and 86 all rest on "314 writes to `0x428E3C` = 313 zeros + exactly ONE `0x0005`".
**That measurement was blind to most of the traffic.**

### What the trace actually holds

```
  MICFU set to 5:    1  via a 16-bit write to 0x428E3C
                    11  via BYTE writes to 0x428E3D      <- my watch never saw these
```

And the byte-write census at `0x428E3D` is where the REAL MICFU traffic lives:

```
  176 x 0x0C  (0o14 RESIWR)      9 x 0x0F        4 x 0x00
   91 x 0x19  (0o31 PHYSWR)      7 x 0x0A        3 x 0x11
   11 x 0x05  (3SWMESS)          7 x 0x01 (3RMICV)   5 x 0x1E
```

313 byte writes to the odd half, against 314 sixteen-bit writes to the even half. **The 16-bit writes
are mostly ZEROING; the byte writes carry the function codes.** So "313 zeros and one 3SWMESS" was a
true statement about half of a word and a false one about the machine.

### The instrument failure, named

**WATCHING AN ADDRESS INSTEAD OF A FIELD.** The cell-writer report matches `wl[i].Addr == cellWatch`
exactly. A 16-bit field can be written as one word write at the even address OR as byte writes to
either half, and an exact-address match sees only the first kind. Nothing about the output hints at
the gap: 314 samples looks like plenty of data, and the split was stable across two independent runs -
**reproducibility confirmed the wrong number twice.**

This is the same family as taxonomy #8 (a count that cannot be relevant) and #21 (a denominator quietly
smaller than you think), but the mechanism is new and worth its own name: the FIELD and the ADDRESS are
not the same object, and a watch keyed on one measures the other.

**The fix, in the instrument:** match the whole field - `(addr & ~1u) == (cellWatch & ~1u)` - and print
which half each write touched, so a byte-vs-word split can never again read as a single clean series.

### What this does to task 1

 - **RETRACTED:** "3SWMESS IS produced, once, at the very end, after the stall." It is produced
   **eleven** times.
 - **RETRACTED:** the whole "LNEWSWAP finds zero on 313 of 314 passes" framing, which was built on the
   zeroing half.
 - **STILL `[V]`:** the final 12-word block build at `0x428E30..0x428E46` IS a message being
   constructed (that is what settled section 87 in favour of the MICFU reading over the link reading).
 - **STILL `[V]`:** routine `0o11144` is a list-unlink/exchange primitive, and its call chain
   reconciles PC and L exactly.

The question returns to something honest and open: **with 3SWMESS posted eleven times, why does
place-domain still stall?** That is a different investigation from the one I have been running, and it
starts from a corrected instrument.


## 89. With the corrected reading: a COMPLETE swapper message is built, and N5STA takes UNDOCUMENTED values

Section 88 forced a re-read of the trace with byte writes included. Decoding the first 3SWMESS burst
IN ORDER (rule: decode the bytes, do not grep for what you expect):

```
  0x428E34/35 = 0x0003     N5STA := 3 (ANSWER)      - the previous message is answered
  0x428E3E/3F = 0x0007     offset 7 := 7            - SWFUN = MSWSTART
  0x428E34/35 = 0x0001     N5STA := 1 (MSGN500)     - message TO the ND-500
  0x428E3C/3D = 0x0005     MICFU := 5               - 3SWMESS
  ...
  0x428E3C/3D = 0x0005     MICFU := 5 again
  0x428E3E/3F = 0x0007     SWFUN := 7 again
  0x428E34/35 = 0x0006     N5STA := 6               - ???
```

**A COMPLETE swapper message is being built**: `MICFU=3SWMESS` with `SWFUN=MSWSTART(7)` and
`N5STA=MSGN500`. That is the message the ladder is supposed to produce - so the earlier framing
("3SWMESS never reaches the mailbox") is dead twice over.

### The anomaly: N5STA values that do not exist

Full census on this one block, BOTH halves:

```
  0x0001 MSGN500  (posted)     99
  0x0003 ANSWER   (answered)   34      <- 65 posts with no answer
  0x0005                        5      <- NOT a documented status
  0x0006                        3      <- NOT a documented status
  0x0000 free                 148
```

`N5MessageStatus` documents free=0, MSGN500=1, WAITING=2, ANSWER=3, 5ERANSWER=4. **5 and 6 are outside
that set**, and the servicer services only `N5STA == 1`. A message parked at a status nothing services
would stall exactly the way place-domain does.

### Grading this honestly

`[V]` the counts and the byte sequence above - they come from the never-evicted writes-only trace.
`[V]` the field mapping: `swpInfo=0x8E30` -> base `0x428E30`; N5STA at word 2 = byte +4 = `0x428E34`;
MICFU at word 6 = byte +12 = `0x428E3C`. Both consistent with every earlier pin.
`[D]` that N5STA 5/6 is a DEFECT. It is equally possible that these are legitimate values our
`N5MessageStatus` enum simply does not model - the same shape as section 74's four legal MICFUs with no
enum member. **An undocumented value is evidence our MODEL is incomplete before it is evidence the
machine is wrong.**

### The checks, in order, before anyone calls this a root cause

 1. Search the microcode and `N500-SYMBOLS` for status constants 5 and 6 - if they have names, our enum
    is the thing that is wrong.
 2. Establish WHO writes 5 and 6 (the corrected cell watch, pointed at `0x428E34`, now reports both
    halves and the writing PC).
 3. Only then ask whether the servicer should handle them. The 65 unanswered posts are the symptom to
    explain; the status values are a candidate explanation, not yet the explanation.


### 89.1 Check 1 result: the status family STOPS at 4 in SINTRAN's own symbols

`N500-SYMBOLS.SYMB` (names truncated to 5 chars):

```
  MSGN5=000001   WAITI=000002   ANSWE=000003   5ERAN=000004
  N5STA=000002   <- the FIELD OFFSET (word 2), not a status value
```

There is **no symbol for status 5 or 6**. So `N5MessageStatus` is COMPLETE with respect to the symbol
table, and the "our model is merely incomplete" explanation is weaker than section 89 allowed - though
still not excluded, since a generation-specific value need not appear in the L07 table.

Grade unchanged: `[V]` that 5 and 6 are written and unnamed; `[D]` that this is the stall's cause.

**Check 2 is the discriminator and needs one run:** point `RETROCORE_ND5000_CELLWATCH` at `0x428E34`
(the corrected watch now covers both halves and prints the writing PC). If the 5/6 writes come from the
SAME resident exchange primitive at `0o11144` that section 86 identified, then they are a LINK value
landing in the status field - a structural aliasing bug, not a status at all. If they come from
message-building code, they are real statuses. **Those two answers point in opposite directions, which
is what makes the run worth spending.**


### 89.2 WITHDRAWN: "N5STA takes undocumented values 5 and 6" - I applied the WRONG STRUCT to this block

Caught before it hardened. The harness reports **two** blocks:

```
  swpInfo = 0x00008E30   ->  physical 0x428E30   <- the block I have been decoding
  swMsg   = 0x00428D30                            <- a DIFFERENT block
```

`0x428E30` is **SWPINFO**, and SWPINFO is NOT the mailbox message. `N5MailboxProtocol` gives it its own
layout (`SWPFU` at 101B, `SWPST` at 103B), and `MP-P2-N500`'s LNEWSWAP reads its status through a
SEPARATE accessor - `CALL RN5STATUS` - not from word 2. **Word 2 of SWPINFO is not N5STA**, so
"N5STA = 5 / 6" was the message struct applied to the wrong block.

The 12-word build reinforces it: read as a message it gives `SENDE=1`, `X5CPU=0` and `0xFFFF 0xFFFF` in
words 0-1 - which is not a clean message, but IS exactly a 32-bit `-1`, i.e. the queue sentinel this
family uses for a link field.

**What survives:** MICFU at word 6 is pinned independently and repeatedly - `LNEWSWAP` reads
`*MICFU@3 LDATX` at that offset, and section 81's address chain confirmed it two ways. So the
**3SWMESS counts stand** (11 byte-writes + 1 word-write). It is only the STATUS reading that is
withdrawn.

**Third time tonight for this exact shape** - section 76/77 (SAA value vs which struct), section 87
(link vs MICFU), and now this. The recurring lesson is one question, asked before any decode:
**WHICH STRUCT IS THIS BLOCK?** Offsets are meaningless until that is answered, and a wrong struct
produces field values that look like real data every time.

**Correct next step:** get SWPINFO's actual layout (`SWPFU=101B`, `SWPST=103B` are the only pins we
have) before decoding anything else at `0x428E30`, and point the corrected cell watch at the fields
those symbols name rather than at message offsets.


## 90. TASK 5 MECHANISM FOUND: `TESTFD` FORCES the ALU output to zero, and saves the sign FROM that

Decoded from the authoritative `microcode-5000-def.json` field split, not from guesswork. The ALU
fields are **4-bit op + 2-bit carry** (`ALU_TRUE` = 127..124 op, 123..122 carry), so a raw 6-bit value
is `op<<2 | carry` - which is why the 16-entry mnemonic table looked like it did not cover values
16/20/24/28.

### The flag-saving word

```
  0o3171   TESTOBJ = 9  -> COND,MZRO    "Z FROM ALU OPERATION"
           COND_ALU = 1 -> conditional ALU
             TRUE  branch: op 0  = ALU,FZRO   FORCE ZERO ALU OUTPUT
             FALSE branch: op 5  = XOR        of A,SC1 and B,SC14
           DEST = D,NONE      STATUS = 5 -> ST,SAVC  "SAVE STATUS FROM ALU IN COMPARE"
```

**With the documented ONE-WORD CONDITION DELAY, `COND,MZRO` tests the flags left by the PREVIOUS
word.** So the word behaves as:

```
  previous ALU result was ZERO  ->  force the ALU output to 0, save status from THAT   ->  S = 0
  previous ALU result non-zero  ->  XOR(SC1, SC14), save status from the real result    ->  S = sign
```

### It explains both measured cases, which the old story could not

 - `-0.0` (`0x80000000`): the preceding operation yields zero, `MZRO` is true, the output is FORCED to
   zero, and the sign saved off a zero is **0**. Matches the measured `Micro.Sgn = 0`.
 - `-1.0` (`0xBF800000`): non-zero, so the XOR branch runs and the sign survives. Matches the passing
   `-1.0` case.

The `FloatTestFlagTests` comment claimed the sign is read off a value masked with `0x7FC00000`. That was
refuted independently (the mask clears bit 31, so EVERY negative float would give S=0). Its INTUITION -
"the operand becomes zero and the sign comes off the zeroed value" - was directionally right; the
mechanism is `ALU,FZRO` on a zero condition, not a mask.

### What this does to the adjudication

**It weakens "our bug" and strengthens "the chip really does this".** The forced-zero is a deliberate
structure in the microcode, executed by the real B30 store - not an artifact of our decoding. On this
reading the microword's `S=0` for `-0.0` is FAITHFUL, and the functional core (S=1, raw sign bit) is
the divergent side.

Grades, kept honest:
`[V]` the field decode of `0o3171` - op split from the def-json, mnemonics from the generated table.
`[V]` the one-word condition delay - already documented and used to settle the AFLAG dispatch.
`[D]` that for `-0.0` specifically the PRECEDING word yields zero. That is the last link, and it is
inference from the two measured outcomes rather than from tracing the preceding word's operands.

**To close it:** trace the word before `0o3171` on a `-0.0` operand and confirm its ALU result is zero.
That converts the last `[D]` into `[V]` and settles whether Ronny's tie-break should stand as
"microcode is right, change the functional core" - the OPPOSITE of where the stale comments pointed.
Do not change any code until that trace is done; the standing instruction is unchanged.


## 91. TASK 5 CLOSED `[V]`: the microcode is FAITHFUL - S=0 for single -0.0 is real chip behaviour

The last `[D]` from section 90 is now verified. The word executed immediately before `0o3171` is the
entry stub's second word:

```
  0o3001   ALU,AND   A,SRF4   B,SC1  ->  D,NONE      (no status save - it only sets the micro-flags)
  0o3171   COND,MZRO tests those flags (one-word delay)
             TRUE  -> ALU,FZRO  -> ST,SAVC saves status from a ZERO output
             FALSE -> XOR(SC1,SC14) -> status from the real result
```

`A_OP 148 = A,SRF4` and `B_OP 8 = B,SC1` - decoded from `microcode-5000-def.json`. **SRF4 is exactly
the mask the old comment named (`0x7FC00000`)**, and the chain checks out on BOTH measured operands:

```
  -0.0 = 0x80000000 AND 0x7FC00000 = 0          -> MZRO true  -> ALU,FZRO -> S = 0   (measured S=0)
  -1.0 = 0xBF800000 AND 0x7FC00000 = 0x3F800000 -> MZRO false -> XOR      -> S = 1   (measured S=1)
```

Two independent operands, both predicted correctly. That is a 2-point calibration of the whole chain.

### The old comment was HALF right, and the half it got wrong is what misled everyone

It named the mask correctly (`ALU,AND A,SRF4 = &0x7FC00000`) but described the sign as being "read off
that zeroed result instead of the original bit 31". Read literally that is refutable in one line -
the mask clears bit 31, so every negative float would give S=0, and `-1.0` does not. The real
mechanism is a CONDITIONAL ALU that FORCES the output to zero when the masked value is zero. Same
intuition, different machine.

**A partially-correct explanation is more dangerous than a missing one**: it survives casual checking
because part of it verifies, and it discourages anyone from re-deriving the rest. This one stood long
enough to be quoted into a task, a plan and two questions to Ronny.

### The verdict, which is the OPPOSITE of the stale framing

The forced-zero is deliberate structure in the real B30 store. **The microword's S=0 for single `-0.0`
is FAITHFUL**, and the functional `CpuND500` (raw sign bit, S=1) is the divergent side. Section 82's
"our engine is at fault" reading is withdrawn; section 90's tentative version is now confirmed.

Also settled: the double path never runs this microcode at all - our C# recompute at `Mpc 003171` +
`InstrDt 5` supplies its flags - which is why the two widths disagree in our engine while the
microcode has no width-specific sign path (section 82's byte-level facts, still true).

**Remaining decision is Ronny's, and it is now on correct evidence:** make the functional core match the
microcode, or keep manual 10.11's raw sign bit and record the microword as intentionally divergent.


## 92. TASK 2 REFUTED: RUNSW DOES reach `SAA 7`, the start IS posted, seen and taken `[V]` 2026-08-31

Full octobus ladder with `RETROCORE_ND5000_WATCH=runsw`, 1 h 20 m, test PASSED, pack override
confirmed on log line 3.

### Every arm hit - including the one the plan said was unreachable

```
  RUNSW blk1@0o163642           hits=1
  RUNSW blk2@0o163647           hits=1
  RUNSW blk3@0o163664           hits=1
  RUNSW blk4@0o163702           hits=1
  RUNSW all-passed@0o163717     hits=1
  RUNSW SAA7 MSWSTART@0o163725  hits=1     <-- REACHED
  RUNSW sender R2@0o104236      hits=80
  CONTROL 5ACTSWAPPER           hits=2     <-- instrument alive
```

**All four precondition blocks pass and `SAA 7` (MSWSTART) executes.** PLAN.md item 2 said *"the
sending code is correct and execution never reaches it"* and listed the guarded checks at
`163621`-`163716` as the thing to find. **That is refuted:** the checks all pass.

### And the servicer SEES the start

```
  [at START-SWAPPER verdict]  startSeen=1  startMicfu=23B  startTaken=True
                              restarts=1/1  swpfu[LNEWSWAP:2]
                              promptReturned=FALSE
```

The earlier "`startSeen=0 startTaken=False swpfu[(none)]`" figures that framed this task come from
snapshots taken BEFORE start-swapper runs - the run holds 4 such early snapshots and 11 later ones
reading `startSeen=1`. **Reading a pre-command snapshot as the command's result is what created this
task's premise.**

### What is actually wrong

Not "the start is never posted". The start is posted, seen and taken - and then
**`promptReturned=False`: the monitor never returns its prompt.** That is a HANG AFTER a successful
post, which is a different investigation from the one this task described.

Note the MICFU profile also changed against the short bring-up: `micfu[1B:42 12B:1 23B:1 24B:1
30B:12 31B:13]` - `30B` (PHYSRD) x12 now appears, so real work follows the start.

### Why this run can be believed

The four block arms DISCRIMINATE (a run where one blocked would show the later arms at 0), the
control hit, and the sender arm's 80 hits are consistent with it being the SHARED FUNCS sender rather
than RUNSW's alone - which is exactly why the block arms, not the sender, carry the evidence. That
distinction was written into the watch before the run.


## 93. THE ND-500 CONFORMANCE CORPUS WAS THREE WEEKS STALE, AND NOTHING COULD SEE IT `[V]` 2026-08-31

Ronny asked for the big JSON suite to be tested and updated after the single-float TEST change. Doing
that surfaced a larger problem than the change itself.

### The suite could not be run by the documented command

`TestComprehensiveExportAndRun` is `[Explicit]` at CLASS level. `dotnet test --filter` **cannot select
explicit tests**, so:

```
  --filter "FullyQualifiedName~RunConformanceCorpus"                      -> No test matches. EXIT 0.
  --filter "FullyQualifiedName=<fully.qualified.name>"                    -> No test matches. EXIT 0.
```

**Both reported success while running nothing.** A first, broader run reported `689 passed, 4 skipped`
and exit 0 with the corpus never touched. The fixture's own comment documents this and even warns that
`nd500x/docs/SYNC-FLOAT-NATIVE-REBASE.md` still instructs people to run a filter that selects nothing.
The documented workaround - comment the attribute out, run, restore - is what was used here.

### What it found once it could run

```
  40,082 cases loaded and executed
   3,922 FAILED on the UNMODIFIED engine (baseline)
   3,923 FAILED with the single-float change  ->  exactly ONE case moved
```

The one case is **`Test_F_NegZero`** (index 19013), the single-float TEST of `-0.0` - precisely the
adjudicated change. `Test_D_NegZero` (19018) still passes, confirming the single-only scoping.

### The 3,922 are a STALE FIXTURE, not engine bugs

```
  corpus in bin/ generated : 2026-08-10 13:18
  engine changes since     : through 2026-08-30, including
       a4e788463  "a divide-by-zero that says where the zero came from"
       e856a1148  "integer divide: adjudicate + fix two edge-case findings"
       5fe5eaa6e  "ND500 Conformance Corpus: exact trap bits ... and the trap fixes behind them"
```

The failing family is `Div_DivByZero_TRAP_*` with `I1 mismatch: expected 0x64, got 0x7F` - exactly what
those commits changed. The corpus is a BUILD ARTEFACT (not source-controlled), so the copy in `bin`
predates three weeks of deliberate, adjudicated engine fixes.

**The trap I avoided:** regenerating blindly would have rewritten all 40,082 goldens from the current
engine and made 3,922 mismatches VANISH with no record. Checking the corpus timestamp against the
engine's commit history BEFORE regenerating is what distinguished "stale fixture" from "3,922 new
bugs" - and those two look identical in the failure count.

### Why this matters beyond tonight

`nd500-conformance.json` is the **shared** fixture: nd500x reads the same file under the same name.
A guard rail that (a) cannot be selected by the documented command, (b) is a build artefact nobody
regenerates, and (c) is not listed in `DOCS/Known-Test-Failures.md`, is a guard rail that silently
stops guarding. It went three weeks and ~3,900 divergences without anyone seeing a red light.


## 94. RETRACTION of section 93's diagnosis: the 3,920 are NOT a stale fixture. They are REAL mismatches

Section 93 concluded "the 3,922 are a STALE FIXTURE, not engine bugs" from a timestamp
(corpus 2026-08-10) correlated with commit TITLES about divide-by-zero fixes. **I tested it by
regenerating, and it failed.**

```
  baseline, engine unmodified   : 3922 failed / 36160 passed
  with the single-float change  : 3923 failed / 36159 passed
  after FULL regeneration       : 3920 failed / 36162 passed
```

**Regeneration removed only THREE failures.** The `Div_DivByZero_TRAP_*` cases survive it with
**identical** values - `I1 mismatch: expected 0x00000064, got 0x0000007F`. If their expectations were
produced by executing the current `CpuND500`, regeneration would have overwritten them and they could
not still disagree. **They are therefore SPEC-DERIVED**, and the ~3,920 are real
engine-versus-specification mismatches.

### What the 3-case delta does tell us

One of the three is `Test_F_NegZero` - my adjudicated change, whose golden regeneration correctly
updated. So the generator DOES bake some expectations from the engine and others from a spec; the
corpus is a MIXTURE. That is worth knowing before anyone reasons about it again.

### The error, and why it was seductive

The stale-fixture story explained every fact I had: a three-week-old artefact, engine commits whose
titles named the exact failing family, and a plausible mechanism. **It was circumstantial and I graded
it `[V]`.** A timestamp plus a commit title is a CORRELATION; the regeneration was the experiment, and
it takes 7 minutes.

This is the same shape as the `0x0006` retraction earlier tonight: a story that fits all the evidence
is not the same as a tested claim. The tell both times was that I had not run the one cheap experiment
that could FALSIFY it.

### Corrected standing state

`[V]` 40,082 cases execute; **3,920 fail on the current engine with a freshly regenerated corpus**.
`[V]` My single-float change contributes ZERO of them (3922 -> 3923 -> 3920, with the +1 being
`Test_F_NegZero`, now regenerated and passing).
`[V]` `Test_D_NegZero` passes throughout, confirming the single-only scoping.
`[OPEN]` What the ~3,920 mismatches ARE. They are not stale goldens. `DOCS/Known-Test-Failures.md`
does not mention them, and the fixture cannot be run by the documented command, so they have gone
unseen. **This is a real, unreported ~10% conformance gap in the ND-500 macro CPU and it deserves its
own investigation.**


## 95. THE REAL ANSWER: the ND-500 corpus runner ignores TWO markers the sibling sweep honours

Third and final correction to the "conformance gap" number. Sections 93 and 94 both overstated it.

### The breakdown, measured from the full failure list (which was in the log the whole time)

```
  3,920 reported failures
  3,654  are isNegativeTest cases   <- a mismatch is the CORRECT outcome for these
    266  are not
      of which the bulk are Div_DivByZero_*_TRAP - expectedTrap cases
```

The corpus MARKS them. Every negative vector carries:

```
  isNegativeTest            : true
  negativeTestType          : wrong_flag
  expectedValidationFailure : st:Z
```

`ND500TestModels.cs` even declares those properties - but
`TestComprehensiveExportAndRun.ExecuteTestsFromJson` never reads them. It compares negative vectors
like ordinary ones and counts the intended mismatch as a failure.

### The sibling harness already solved BOTH halves, and says so

`Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/Nd500xCorpusSweepTests.cs`:

> *"Negative tests (`isNegativeTest: true`, ~3.6k cases): the corpus DELIBERATELY ships a wrong
> `final` ... For those a DIVERGE is the correct outcome and a MATCH means the engine reproduces the
> injected wrong behaviour - tallied separately so they can never masquerade as real divergences
> (**the first run of this sweep counted all 3.6k as diverges**)."*

> *"`expectedTrap` cases: the C runner skips register/memory validation for trap tests ... the
> corpus's `final.regs` for these are **stale prose nothing validates** (they still show the
> pre-2026-07-26 dest-unchanged div-by-zero convention, while ALL THREE cores saturate per the
> manual). First run of this sweep treated them as golden and **manufactured a ~184-case false
> cluster**."*

**Both of my wrong numbers tonight are named in that file as mistakes already made and fixed** - the
3.6k negative-test miscount, and the div-by-zero trap cluster. The second even explains the exact
`I1 mismatch: expected 0x64, got 0x7F` signature: the corpus's stale regs encode the OLD
dest-unchanged convention while all three cores now saturate.

### The corrected state

`[V]` The ND-500 runner `ExecuteTestsFromJson` lacks BOTH refinements the ND-5000 sweep has.
`[V]` My single-float change contributes ZERO failures (3922 -> 3923 -> 3920, the +1 being
`Test_F_NegZero`, regenerated and passing).
**RETRACTED (twice now):** "~3,920 real failures" and "a ~10% conformance gap". Neither survives.

### The lesson, which is the standing rule I did not follow

**CHECK THE EXISTING MACHINES BEFORE BUILDING AN OPINION.** One `grep isNegativeTest` across the repo
- the same command that eventually answered it - would have found the sibling sweep and both
explanations in the first minute, before three sections of escalating wrong headlines. I ran that grep
only after exhausting my own theories.

### What is actually worth doing

Teach `ExecuteTestsFromJson` the two rules the sibling already implements (reuse its logic, do not
re-derive it), so the corpus reports a number that means something. Until then its failure count is
dominated by cases that are behaving exactly as designed.


## 96. TASK 2 LOCATED: during start-swapper the ND-100 sits in the IDLE LOOP, waiting for an answer `[V]`

Section 92 established that RUNSW reaches `SAA 7`, the start is posted, `startSeen=1
startMicfu=23B startTaken=True`, and yet `promptReturned=False`. The same run's PC histogram says
where the ND-100 actually is:

```
  ND-100 PC during start-swapper: 597 samples, 29 distinct (PC,PIL)
     PC=0x000012C4 pil=0  x117           PC=0x000012C3 pil=0  x116       |  573 of 597 samples = 96%
     PC=0x000012C5 pil=0  x114       |  five CONSECUTIVE addresses
     PC=0x000012C2 pil=0  x113       |
     PC=0x000012C6 pil=0  x113      /
     ...everything else x1 (PIL 1/2/13 - the clock-driven sampler noise, section 73)
```

`0x12C2` = **`0o11302`**, in the resident common code - the same segment as the `0o11144` exchange
primitive from section 86. Disassembled:

```
  011300  150412  PION              ; enable the interrupt system
  011301  150015  TRA PEA
  011302  146167  RADD CLD ST DX
  011303  132400  JNC 0     -> 011303
  011304  146401  RADD AD1 0 DD     ; D := D+1   <- an idle-time COUNTER
  011305  147155  RADD ADC CLD SA DA
  011306  124374  JMP -4    -> 011302
```

**That is SINTRAN's IDLE LOOP.** `PION` then a tight counting loop at PIL 0. The console slice agrees:
`1 SYSTEM idle 0.0 s`.

### What it means

The ND-100 is **not** spinning in the monitor and **not** stuck in RUNSW. It has nothing to run: the
monitor process is BLOCKED and the machine went idle. So:

```
  start posted  ->  seen (startSeen=1, MICFU 23B)  ->  taken (startTaken=True)
       ->  ND-100 blocks waiting for completion  ->  IDLE  ->  the answer never arrives
```

**The hang is on the ANSWER path, not the send path.** That is a different half of the protocol from
where this task has been looking, and it retires the "which precondition blocks the send" question
entirely.

### Next

Find what the ND-100 is waiting ON, then why the ND-5000 side never satisfies it. The swapper CPU
state at the verdict was `PC=0x08008255 stopMode=WAIT`, `ansMON=377B ansSWPFU=1B ansSWPSTAT=0B`,
`restarts=1/1`, `swpfu[LNEWSWAP:2]` - so the ND-500 side ALSO parked. **Both sides are waiting.**
Establish which one owes the other a message; a mutual wait means one of them is wrong about whose
turn it is.


## 97. THE CORPUS FIX LANDED, and it surfaced TWO REAL ENGINE BUGS that 3,654 miscounts were hiding

`ExecuteTestsFromJson` now honours `isNegativeTest`. Before and after, same engine, same corpus:

```
                       BEFORE          AFTER
  Failed               3,920            268
  NegativeOK               -           3,654
  Pass Rate                -          99.26%
  NEGATIVE TEST MATCHED    -               2   <- REAL FINDINGS, previously invisible
```

### The two real findings

```
  [36600] Schpar_BY_ClearParity_NegativeTest_WrongZFlag   BY1 schpar $0x2000, $0
  [36609] Sskip_BY_Skip3_NegativeTest_WrongZFlag          BY  sskip  0x2000, $65
```

Both `wrong_flag / st:Z` on BYTE-width string instructions. **A negative test that MATCHES means the
engine reproduced the DELIBERATELY WRONG final** - so `CpuND500`'s Z flag for `schpar` and `sskip` at
byte width is genuinely wrong. This is exactly what negative tests are for, and both were buried
inside 3,654 cases the runner was miscounting.

### What the remaining 268 are

```
  196  Div_DivByZero*        \  208 = the expectedTrap family whose final.regs are STALE PROSE
   12  Div_DivZeroByZero     /   (the C runner skips reg/mem validation for these - see section 95)
   12  Sfilln_{W,H}_Fill4At2
    4  Div4_0_3E8      4  Chain      4  /_W_documented_minDividedByMinusOne
    3  pmon/pmof/pctsb_Default       2  mul2_{W,H}_documented_minTimesTwo
```

Strip the expectedTrap div family and roughly **60 genuine cases** remain, in a handful of named
families. That is a triage list a person can actually work, which "3,920 failures" was not.

### The arc of this number tonight, as a caution

```
  "3,922 real failures"          -> wrong (never checked what they were)
  "stale fixture, not bugs"      -> wrong (regeneration refuted it: 3922 -> 3920)
  "a ~10% conformance gap"       -> wrong (93% were negative tests behaving correctly)
  268 failures + 2 real findings -> measured, with the families named
```

Three wrong headlines, each plausible, each published before running the cheap experiment that could
falsify it. The thing that finally worked was reading the full failure list - **which had been sitting
in the log the entire time** (7,931 lines after `=== Failures ===`) - and grepping the repo for the
marker, which found the sibling sweep that had solved both halves already.


## 98. TASK 10 FRAMED: two DELIBERATE assertions in our own repo contradict each other on SSKIP's Z

The two `NEGATIVE TEST MATCHED` findings from section 97 are not a simple engine bug. Both sides are
things WE wrote, and they disagree on purpose.

### The disagreement, exactly

`Sskip_BY_Skip3`: string at `0x2100` is `A A A B C D E F`, test value `A`, so the skip stops at index
3 on the `B`. Both sides agree `i1=3`. They differ ONLY on Z:

```
  corpus generator (ComprehensiveStringGenerator.cs ~line 890):
      ExpectedFlags = FlagCalculator.ST_ZERO,   // Found non-matching element
      ...and ST_ZERO = 0x20 = bit 5 = the Z FLAG.  So: differing element -> Z=1.

  Sskip.cs header + code:
      "Terminating conditions: different element: K=0 Z=0 I1 := differing element"
      ...and the code sets regs.ST.Z = false on that path.  So: differing element -> Z=0.
```

`Schpar` is the mirror: the corpus expects `st=0` and the engine gives `32`.

**Neither is external authority.** One is a generator comment, the other an instruction-header comment,
and tonight has already shown twice that a confident header comment in this tree can be wrong for weeks
(the `-0.0` mask story; the `..._KnownDivergence` test name that pinned agreement).

`Sskip.cs`'s header is additionally SELF-inconsistent: its Operation section says the result goes to
**S** ("if S(I1) >> <test> then 0 -> S else 1 -> S", "The S bit is set to 1 if the end of the string is
reached") while its Terminating-conditions section talks about **Z**. A comment that cannot agree with
itself about which flag carries the result cannot adjudicate this.

### The authority, located and decodable

`SCHPAR` @ `0o1351`, `SSKIP` @ `0o1325`. SCHPAR's termination region is FOUR near-identical blocks each
ending in **`ST,SAVA`** - "SAVE STATUS FROM ALU OPERATION", so **the flags are COMPUTED from the ALU
result, not hand-set**:

```
  0o10361..0o10364   cond word 0o10363: COND_ALU=1  ALU_T=17  ALU_F=16   then ST,SAVA
  0o10365..0o10373   cond word 0o10372:             ALU_T=16  ALU_F=17   <- polarity swapped
  0o10374..0o10402   cond word 0o10401:             ALU_T=16  ALU_F=17
  0o10403..0o10411   cond word 0o10410:             ALU_T=17  ALU_F=16
```

`ALU_T`/`ALU_F` are `op<<2|carry`, so 16 and 17 are both op 4 = `ALU,A` differing only in CARRY-IN.
Four blocks with differing polarity = the four documented terminating conditions, one per outcome.

**This is decidable with no run.** Decode `A_OP=32` and the condition on those four words (applying the
one-word condition delay), and the flag each termination produces falls out. Then whichever of our two
assertions disagrees with the silicon is the one to change - along with its comment.


## 99. TASK 10 ADJUDICATED: a SPLIT verdict - the engine is wrong for SSKIP, the CORPUS is wrong for SCHPAR

Both instructions save their terminating status the same way, and it is the **forced-zero** trick
already verified for `TESTFD` in section 91:

```
  SCHPAR terminations  0o10364 / 0o10373 / 0o10402 / 0o10411
  SSKIP  terminations  0o10110 / 0o10111
      all of them:   ALU,FZRO / ALU,FZRO    D=D,NONE    ST,SAVA
```

`ALU,FZRO` forces the ALU output to ZERO on both the true and false paths, and `ST,SAVA` is
"SAVE STATUS FROM ALU OPERATION" - so the status is taken FROM a zero result. **Z=1 at every one of
these terminations, for both instructions.**

### The verdict, which is SPLIT

```
                corpus      microcode     engine        who is wrong
  sskip         Z=1         Z=1           Z=0           THE ENGINE
  schpar        Z=0         Z=1           Z=1           THE CORPUS
```

**This is why the disagreement had to be adjudicated rather than reconciled.** Changing the engine to
match the corpus - the obvious "make the tests pass" move - would have FIXED sskip and BROKEN schpar.
Two failures that looked like one bug are two bugs pointing in opposite directions.

### Grading, honestly

`[V]` the microword fields: both instructions' status-save words are `ALU,FZRO` + `ST,SAVA`, decoded
from the raw image via the def-json field split.
`[V]` the mechanism itself - the identical FZRO-then-SAVA pairing was verified end to end for TESTFD
(section 91), where it predicted both measured float operands correctly.
`[D]` that this yields exactly `Z=1` and that no later word overwrites it before the instruction
retires. The pairing only makes sense if `ST,SAVA` takes the CURRENT word's ALU result (otherwise
forcing zero would be pointless), which is the same reading TESTFD confirmed.

**Surprising enough to flag:** if every termination saves Z=1, Z carries no discrimination between the
outcomes - the distinguishing information must live in K or in which branch was taken. The two SSKIP
saves differ in TESTOBJ (`COND,MCRY` at 0o10110 vs `COND,MSEXO` at 0o10111), i.e. in the CONDITION
tested, not in the ALU result. That is consistent, but it deserves a second look before the fix lands.

### The falsifiable plan

Fix `Sskip.cs` to set Z=1 on the differing-element path. Prediction: the positive `Sskip_BY_Skip3`
vector PASSES and its negative twin returns to `NegativeOK`, while **`Schpar` stays failing** until the
CORPUS generator is corrected (`ComprehensiveStringGenerator.cs` sets `ExpectedFlags =
FlagCalculator.ST_ZERO` with the comment "Found non-matching element"; per the microcode that
expectation is inverted). If schpar changes state too, this reading is wrong.


## 100. WITHDRAWN: section 99's split verdict. My own flagged caveat refuted it within the hour

Section 99 concluded "Z=1 at every termination" from `ALU,FZRO` + `ST,SAVA`, and flagged a caveat:
*"if every termination saves Z=1, Z carries no discrimination between the outcomes"*. **That caveat is
the refutation, and there is positive evidence for it.**

`Schpar.cs` sets Z from the DATA:

```
  line 98:   regs.ST.Z = true;   // Set Z if any byte has incorrect parity
  header  :  "string checked: K=0  Z := parity check result,  I1 := next element"
```

**SCHPAR's whole purpose is to report a parity result in Z.** If the microcode's terminations forced
Z=1 unconditionally, the instruction could not do its job. So "FZRO + SAVA => Z=1" is wrong.

### The likely explanation, and the one question that decides it

The status save probably LAGS BY ONE WORD, exactly as the CONDITION provably does on this machine. Then
the `ALU,FZRO` word saves the PREVIOUS word's ALU result - for SCHPAR that is the parity
`ALU,AND A,DATA B,SC12` at `0o10362` - which is data-dependent, as required. The `FZRO` would then be
there precisely so the current word's ALU does not disturb the status being saved.

**The governing question, still `[OPEN]`:** does `ST,SAVA`/`ST,SAVC` save the CURRENT word's ALU result
or the PREVIOUS word's? `microcode-5000-def.json` says only "SAVE STATUS FROM ALU OPERATION" and gives
no timing. The authority is ND-05.022.1 (ND-5000 Microprogram Guide), in-repo under
`Reference-Manualsŀ\`. **Answer that before anything else here.**

### What this does and does NOT invalidate

**WITHDRAWN:** section 99's verdict ("engine wrong for sskip, corpus wrong for schpar"). Both halves
rested on Z=1-always. Task 10 returns to `[OPEN]` with the disagreement itself still `[V]` (the corpus
and the engine really do differ, and the positive+negative vector pairs prove it is a real divergence).

**NOT INVALIDATED - and this distinction is the important one:** the committed `Test.cs` change for
single-float `-0.0`. Section 91 explained it via the same FZRO mechanism, and that EXPLANATION is now
uncertain - but the change itself rests on MEASUREMENT, not on the explanation. The microword
`CpuND5000` executes the real B30 and OUTPUTS S=0 for `-0.0`; that was measured directly
(`FloatTest_NegZero`, 304 ms) before any mechanism was proposed, and 13/13 tests now confirm both
engines agree. **A wrong story about why does not unmake a measured what.**

The reverse of tonight's recurring error, and worth keeping: elsewhere I published derivations as
measurements. Here a derivation is failing while the measurement underneath it stands.


## 101. SECTION 100 OVER-CORRECTED. The manual answers the timing question, and section 99's verdict is RESTORED

Section 100 withdrew the split verdict because `Schpar.cs` reports Z from the parity result, which
seemed incompatible with "Z=1 always". **I treated our own comment as evidence about the hardware -
the exact error class this document has recorded three times tonight.**

### The manual settles the governing question `[V]`

ND-05.022.1 (ND-5000 Microprogram Guide), the `H ADD2` worked example:

```
        ALU,A+B ORA B,SC5 TYP,OR D,SC5 ST,SAVA
```

**ONE microword performs `ALU,A+B` AND `ST,SAVA`.** For an ADD2 the status saved must be that
addition's, so **`ST,SAVA` saves the CURRENT word's ALU result. There is no one-word lag on the status
save** - unlike the CONDITION, which does lag. Those are two different pipeline behaviours and I had
been assuming they matched.

### Therefore section 99 is restored

`ALU,FZRO` + `ST,SAVA` in the same word saves status from a FORCED ZERO, so Z=1 at the SCHPAR and
SSKIP terminations, and the split verdict stands:

```
                corpus      microcode     engine        who is wrong
  sskip         Z=1         Z=1           Z=0           THE ENGINE
  schpar        Z=0         Z=1           Z=1           THE CORPUS
```

### Why section 100's refutation failed

It rested on `Schpar.cs`'s header and code claiming `Z := parity check result`. That is OUR
implementation asserting what the hardware does - not evidence about the hardware. And the schpar
vector cannot discriminate anyway: our parity-dependent Z happens to produce Z=1 for this data, and
"Z=1 always" also produces Z=1. **A test case that both hypotheses pass cannot refute either.** I
should have noticed that before withdrawing.

### Three flips on one question - why this one is better grounded

99 (verdict) -> 100 (withdrawn) -> 101 (restored). The difference is the KIND of evidence:

```
  99   inferred the timing from the FZRO+SAVA pairing        (derivation)
  100  refuted it with OUR OWN comment                       (unreliable witness)
  101  the MANUAL shows one word doing both ALU and SAVA     (external authority)
```

Only 101 rests on something outside our own code. The lesson is not "stop revising" - it is that a
revision is only worth making when the new evidence is of a BETTER KIND than the old, and our own
comments rank below the manual and below the raw microcode every time.

### Still owed before the fix lands

The `[D]` from section 99 remains: that no later word overwrites the status before the instruction
retires. Decode forward from each termination to the instruction boundary (`G,OOPS`) and confirm no
second `ST,SAV*` runs. That is the last gap, and it is decodable with no run.


## 102. STRUCTURAL CORRECTION: those are not four "terminations" - `0o10364` LOOPS BACK. Stop here and trace properly

Following the sequencer instead of reading linearly:

```
  0o10364  ST,SAVA   ->  ABS = 0o10361     <== JUMPS BACK INTO ITS OWN BLOCK. It is a LOOP BODY.
  0o10373  ST,SAVA   ->  ABS = 0o10361     same target
  0o10110  ST,SAVA   ->  ABS = 0o10112     falls into ST=K,1IFZ  (writes K, not Z)
  0o10111  ST,SAVA   ->  ABS = 0o3117      leaves the region
```

**Section 99 called these "four termination blocks". That characterisation is wrong** - at least the
SCHPAR ones are a loop that re-enters at `0o10361`, so the `FZRO`+`SAVA` executes once PER ELEMENT, not
once at exit.

That does not immediately overturn "Z=1 at exit" (a forced zero saved every iteration still leaves Z=1
at the end), but it means the reasoning behind it was about the wrong control-flow shape, and the
SCHPAR parity result must be produced somewhere I have not yet identified. **The two facts cannot both
be casually true, and I am not going to resolve that by asserting one of them again.**

Note `0o10112` is `ST=K,1IFZ` - "SET K TO 1 IF ALU OPERATION IS 0" - so K is written separately from Z
right after the SSKIP save. That is consistent with the instruction contracts, which describe K and Z
carrying different parts of the outcome.

### Where this leaves task 10

`[V]` and unchanged: the corpus and the engine really disagree, and both the positive and negative
vectors fail for each instruction. `ST,SAVA` saves the CURRENT word's ALU (manual, section 101). The
microword addresses are correct.

`[OPEN]` again: what Z actually is at exit, because the control flow is a loop and I characterised it
as straight-line terminations.

**The honest next step is a TRACE, not more static reading.** The microword `CpuND5000` executes the
real B30 - run SCHPAR and SSKIP on the two corpus vectors and record the status at retire, the way the
`-0.0` question was ultimately settled (measure first, explain after). That converts this from a
derivation I have now revised four times into a measurement.

**Four revisions on one question is the signal to stop deriving.** 99 verdict -> 100 withdrawn -> 101
restored -> 102 structural premise wrong. Each revision was evidence-driven, but the pattern says the
static-decode approach is at the edge of what it can settle reliably here.

## 103. ANSWERED - `0x0006` is ACON command `6h` WCS, "write control store" `[V]` 2026-08-31

Item 3 asked what the ACCP command word `0x0006` actually is. It is documented, and has been all
along: **`0x00220000` is the ACON decoder** - the "ACCP Control Decoder" of ND-05.020.01 page 113,
Table 9 - and `0x0006` is its command `6h`, **WCS, "Write control store"**, polarity 0.

### How it was settled: enumerate the port's literals, then apply the key

RULE #0b, done properly. I did not grep for what I expected; I enumerated **every immediate written
to that port anywhere in `octo.bin`**, in ROM order, in both encodings:

 - `33FC <imm> 00220000` - `MOVE.W #imm,(0x00220000).L`
 - `30BC | reg<<9` - `MOVE.W #imm,(An)` with `A0 = 0x220000` (loaded at `0x76F2`)

The second encoding matters: my first sweep used `30FC` and returned **ZERO hits**, which would have
read as "there are no register-indirect command writes". `MOVE.W #imm,(An)` is `0x30BC`, not
`0x30FC`. A wrong opcode returns a confident empty set - the exact shape the octobus skill's trap 8
warns about.

55 sites, 23 distinct literals. Then apply Table 9's key:

```
  bit 15 AEDRL   enable MPC(31-0) to DB(31-0)
  bit 14 EAOB    enable AOB(15-0) to DB(15-0)
  bit 13 MODE    force MODE of the SSRs (MIR/MISR, APR/ASR) to 1
  bit 12 ASDI    force serial data input of the SSRs to 1
  bits 4-0       the command code
```

### The falsifiable check, and it passed

Bits 11..5 are unused in the ACON encoding. **All 23 literals have bits 11..5 zero**, and 22 of 23
carry a command code that is in Table 9. The one exception is `0x0008`, already on record as the
undocumented ACON code `8h` that ENKICK issues. A decode key that fits 23 out of 23 on its unused
field and 22 of 23 on its used field is not a coincidence.

```
  0x0001 TRIG        0x0002 CLRALIVE     0x0005 RAIBF       0x0006 WCS  <-- THE ANSWER
  0x0007 MASKAIBF    0x0008 (undocumented, ENKICK)          0x000F ADCLK
  0x0010 MDCLK       0x0015 ARMA         0x0017 ARMI        0x0018 AMIRCK   0x001A ARAL
  0x2010 MODE+MDCLK  0x2011 MODE+CAPR    0x2018 MODE+AMIRCK
  0x300F MODE+ASDI+ADCLK                 0x3010 MODE+ASDI+MDCLK
  0x4009 EAOB+CAIB   0x400A EAOB+ALWAD   0x400C EAOB+ADWRQ  0x400D EAOB+ADRRQ
  0x4016 EAOB+ARIA   0x8013 AEDRL+CAPRAIB
```

### What this does to the "triple"

Section 79 left it as `0x3010` (latch address) -> `0x0006` (unknown) -> `0x0010` (ClockA). Read with
the key, it is not a latch-command-clock at all:

```
  0x3010  MODE+ASDI+MDCLK   force SSR mode and serial-data-in, clock MISR
  0x0006  WCS               WRITE CONTROL STORE
  0x0010  MDCLK             clock MISR
```

The `0x30xx` / `0x00xx` pairing is a **bracket**: the same command code issued first with
MODE+ASDI asserted and then with them released. The ROM uses that bracket four more times with
`0x0F` (`0x300F` ... `0x000F`) around `ALWAD`/`ADWRQ`/`ADRRQ`/`ARIA` - the MFbus memory
transactions. So the shape is generic, and it appears a third time in the address phase at
`0x76E6`, where the bracketed command is `0x0015` ARMA (reclock MAR) rather than WCS:

```
  7714  move.w #0x3010,(A0)   MODE+ASDI+MDCLK
  7728  move.w #0x0015,(A0)   ARMA - reclock MAR
  7736  move.w D4,(A0)        D4 = 0x0010, MDCLK
```

**`0x0006` occupies exactly the slot `0x0015` occupies.** Position was never going to answer this;
the decoder key did.

### The correction this forces on `Nd5000ControlStoreLink`

The constants there are position-derived names, and Table 9 overrules them:

| constant | value | the name we invented | what ACON says it is |
|---|---|---|---|
| `CommandPerform` | `0x0018` | "performs the staged operation" | `AMIRCK` - reclock MIR **without** ECMIR |
| `CommandOperation` | `0x2018` | "the operation at 0x774C" | MODE + `AMIRCK` |
| `CommandVerify` | `0x2010` | "before a read-back verify" | MODE + `MDCLK` |
| `CommandShiftInWord` | `0x2011` | "per word during shift-in" | MODE + `CAPR` (PCLK to APR) |
| `CommandAddressLatch` | `0x3010` | "latches the address" | MODE + ASDI + `MDCLK` |
| `ClockA` / `ClockB` | `0x0010` / `0x000F` | "the clock pair" | `MDCLK` / `ADCLK` - **two different clocks**, to MISR and to ASR, not two phases of one |
| `CommandMicroprogramArm` | `0x0017` | "arm the microprogram" | `ARMI` - reclock MIR **with** ECMIR |
| `CommandStrobe` | `0x0015` | "a generic strobe" | `ARMA` - ACCP reclock MAR |

The most load-bearing of these: **`ClockA`/`ClockB` are not a two-phase clock pair.** `MDCLK`
clocks the MISR (the microinstruction serial register) and `ADCLK` clocks the ASR (the AOB serial
register). They are clocks to **different shift registers**. The model's "shift direction is
distinguished only by the phase order of the pair" is therefore built on a wrong premise, even
though it reproduces the observed order.

And **the only "write control store" strobe in the whole ROM is `0x0006`, at exactly two sites**
(`0x73D2` and `0x7408`). `0x0018`/`0x2018`, which the model treats as the commit, are MIR reclocks.

### What is NOT settled

Section 78's measurement stands and is not contradicted: adding a `0x0006` case as a per-microword
commit made the test go from `writes 8 -> 9` (correct) to `writes 20972 -> 20974` (first one
misaligned). Knowing `0x0006` is WCS does not by itself say what data WCS commits or from where -
that depends on what the MISR/MIR hold at that instant, which is the serial-shift mechanism the
model deliberately does not simulate bit by bit. **Do not re-apply the retracted change on the
strength of the name.** The next step is to model the two clocks as separate registers (MISR vs
ASR) and only then ask what WCS writes.

## 104. The control-store model is INVERTED, and section 78 argued from DEAD CODE `[V]` 2026-08-31

Ghidra came back up and octo.bin is loaded there with call graph and xrefs. Twenty minutes of that
answered item 3 completely - and overturned section 78, section 79's closing paragraph, and my own
section 103's cautious ending.

### The two routines, from the disassembly and the call graph

```
  0x73B2  ControlStoreWriteWord (WCS)          24 callers
            jsr 0x76E6      address phase
            jsr 0x7776      shift the 8 words at 0x1144F0 OUT to the CPU
            ACON 0x3010 / 0x0006 / 0x0010      <-- WCS, "write control store"
            clr.w (0x11314A)

  0x741E  ControlStoreReadWord (AMIRCK)        17 callers
            jsr 0x76E6      address phase
            gate on (bit 2 of the 0x1144EE shadow -> 0x330000)
            ACON 0x0018     AMIRCK - "ACCP reclock MIR without ECMIR": load MIR FROM the word
            test 0x660000 bit 0
            gate off
            jsr 0x775A -> ACON 0x2010, then 0x77B6 shifts the 8 words IN to 0x1144F0
```

`0x7776` and `0x77B6` are the two shift halves and they are unambiguous in the disassembly. Both
walk the same 8-word buffer at `0x1144F0`:

```
  0x7776  OUT:  word -> (0x550000), then 8x [ MDCLK 0x0010 ; ADCLK 0x000F ]
  0x77B6  IN :  8x [ ADCLK 0x000F ; MDCLK 0x0010 ], then 0x2011 (MODE+CAPR), then (0x550000) -> word
```

`CAPR` is "PCLK to APR" - the parallel capture that makes the shifted-in value readable. It appears
only in the IN direction. That is the mechanism the model said was "NOT proven and deliberately not
invented"; it is proven now.

### The caller that settles it beyond argument

`0x8CE0`:

```
  0x8CE4  jsr 0x73B2                 write the word
  0x8CEA  tst.w (0x0011313C) ; beq   retry while the flag says so
  0x8CF8  jsr 0x741E                 read it back
  0x8D14  compare the 8 words at 0x1144F0 against the caller's source
  0x8D1E  on mismatch, print (0x1182C) / (0x117E6)
```

A routine you call to **read back and compare against what you just wrote** is a read. There is no
reading of that loop in which `0x741E` writes anything.

A second, independent caller pair says the same: `0x74A6` calls `0x741E` for CS `0x3FF0..0x3FF4`
and **saves** the result to `0x114500`; `0x756C` **restores** that save through `0x73B2`. Save with
one, restore with the other.

### So `Nd5000ControlStoreLink` commits on the wrong strobe

The model treats `0x0018` as "perform the staged control-store operation" - the microword commit -
and treats `0x2010` + `0x77B6` as a verify tail of the write. In the firmware, `0x0018` is the
**read** strobe and `0x2010`/`0x77B6` are the **read's** shift-in. The actual write commit, WCS
`0x0006`, is not modelled at all.

**And that is exactly what section 78 measured.** Adding a `0x0006` case gave
`writes 20972 -> 20974: two writes, first misaligned`. Two writes per word, the first one wrong, is
precisely what you get when you keep committing on `0x0018` and then ALSO commit on `0x0006`. The
measurement was right; the diagnosis drawn from it was backwards. **The fix is to MOVE the commit
from `0x0018` to `0x0006`, not to add it.**

### Section 78's central argument was made from dead code

Section 78 refuted "0x0006 is a commit" with: *"Routine B (0x73F0) issues the SAME 0x3010/0x0006/
0x0010 triple but shifts NO DATA. A commit opcode would commit garbage there every time."*

`0x73EE` (section 78 called it `0x73F0`, which is two bytes into its LINK) really is that routine.
But:

 - it has **zero callers** in the call graph, and
 - the 32-bit constant `0x000073EE` **appears nowhere in the 131072-byte image**, so it is not
   reached through a pointer table either.

It is dead code. The live twin, `0x73B2`, is the same routine WITH `jsr 0x7776` in front of the
triple - it shifts a full 128-bit microword out and then strobes WCS. The "same triple with the
data removed" was never a control; it was an orphan.

**The rule this is an instance of.** A near-twin routine is only a control if it RUNS. Checking
that costs one xref query. I did not have Ghidra when I wrote 78 and did not say so - I presented a
call-graph claim ("routine B issues...") that I had no call graph to support, and it read as
evidence for two days. Section 79 then stacked a second argument on top of it and the pair felt
conclusive because they came from different directions - but one of the two directions was empty.

### What survives from 103

The ACON identification. `0x00220000` is the ACON decoder, every literal decodes as one, and
`0x0006` is WCS. Section 103's decode table stands unchanged; only its closing paragraph - "do not
re-apply the retracted change on the strength of the name" - is now too weak. Re-apply it, but as a
MOVE rather than an addition, and prove it red-first.

### The `+0x3FF0` note in the model is also wrong

`Nd5000ControlStoreLink` reads the firmware's `parameter + 0x3FF0` as "implying a space of about
0x4000 units", offered as corroboration that the model targets the right thing. It is not a space
size. `0x3FF0..0x3FF4` are the **top five words of the 16384-word store** - the scratch microwords
that `0x74A6` saves and `0x756C` restores around a patch. The conclusion happened to be right; the
reasoning was not.

## 105. The 3SWMESS cell: 627 writes, 3SWMESS built TWELVE times, and both "never entered" stampers ARE entered `[V]` 2026-08-31

Re-ran `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture` with the cell watch corrected to
match the FIELD (`addr AND NOT 1`) rather than the even address. Pack override confirmed on line 3
of the log, test PASSED, 30 m 46 s.

```
  field 0x00428E3C..0x00428E3D, writes = 627   (was reported as 314)

    313  [word/lo] = 0x0000     the zeroing LNEWSWAP keeps finding
      1  [word/lo] = 0x0005
    176  [BYTE-hi] = 0x000C     MICFU 0o14  RESIWR
     91  [BYTE-hi] = 0x0019     MICFU 0o31  PHYSWR
     11  [BYTE-hi] = 0x0005     MICFU 0o5   3SWMESS
      9  [BYTE-hi] = 0x000F        0o17
      7  [BYTE-hi] = 0x000A        0o12  CACHE
      7  [BYTE-hi] = 0x0001        0o1   3RMICV
      5  [BYTE-hi] = 0x001E        0o36
      4  [BYTE-hi] = 0x0000
      3  [BYTE-hi] = 0x0011        0o21
```

### Item 1's premise is dead, and so is section 73's

The plan said: *"why only ONE 3SWMESS message was built in the whole run, and so late"*. There are
**twelve**, spread through the run, and the late word-write is the twelfth, not the only one.

Section 73's headline - "313 zeros and exactly one 0x0005" - described the even half of a 16-bit
field. The MICFU codes live in the LOW byte, which on this big-endian layout is the ODD address, so
the old watch saw the zeroing and almost none of the setting. **It was reproducible, and it was
reproducibly half the data.**

### Both "known stampers" ARE entered - the opposite of what was recorded

The plan states: *"It is NEITHER known stamper: `0o104024` is never entered, and `0o062700` writes
a RESIDENT record at `0x438A30`, outside the mailbox."* The twelve writes name their sites:

```
  CELLW @0x428E3D =0x0005  PC=0o62701   PIL=1   thread=15  L=0o62665     x2
  CELLW @0x428E3D =0x0005  PC=0o104242  PIL=1   thread=15  L=0o104241    x2
  CELLW @0x428E3D =0x0005  PC=0o104266  PIL=1   thread=15  L=0o104241    x2
  CELLW @0x428E3D =0x0005  PC=0o133625  PIL=2   thread=15  L=0o133556    x2
  CELLW @0x428E3D =0x0005  PC=0o133660  PIL=2   thread=15  L=0o133556/45 x2
  CELLW @0x428E3D =0x0005  PC=0o145236  PIL=12  thread=15  L=0o145225
  CELLW @0x428E3C =0x0005  PC=0o11303   PIL=0   thread=15  L=0o34320
```

`0o62701` is one instruction past `0o62700`, and `0o104242`/`0o104266` are inside the routine at
`0o104024`. Both are stamping this cell. The "never entered / outside the mailbox" finding was an
artifact of watching the wrong half - a negative recorded from an instrument that could not have
seen the positive, which is the failure mode this document already has a name for.

The writes arrive in **two identical bursts** (#5383093-#5383115 and #5383315-#5383339, same five
PCs in the same order), then one at PIL 12, then the last one at PIL 0 from `0o11303` - which is the
IDLE LOOP address section 84 identified. The last 3SWMESS is written from the idle loop.

### And the cell is dominated by traffic nobody was looking at

176 RESIWR and 91 PHYSWR. `MEMORY.md` records that the user-domain page-in counter is MICFU
30B/31B (`0x18`/`0x19`) - so `0x19` ninety-one times is ninety-one page writes. Whatever else is
wrong, paging traffic IS moving through this cell.

**Do not restate "3SWMESS is produced once, late" anywhere.** It is produced twelve times, from six
distinct sites, at three different PILs.

## 106. Four fixtures each carried their own copy of the invented sequence `[V]` 2026-08-31

Fixing the model (section 104) broke **17 of 148** ACCP tests, all the same way: `Expected: 1, But
was: 0`. Every one of them drove the READ strobe and asserted a write.

That is not 17 unrelated tests. **Four fixtures each held a private copy of "how a microword is
written", and all four copies were the same invention** - gate on, shift eight words, issue
`0x0018`, gate off, with the address as a "ninth gated word":

```
  Nd5000ControlStoreLinkTests.WriteOneMicroword
  Nd5000LinkWindowTests            (inline, x4)
  Nd5000RealControlStoreTests      (inline, x3)
  Nd5000AttachedMachineTests       (inline, x3)
```

So the model was fitted to the invention four separate times, and the fixtures agreed with each
other while all four disagreed with the ROM. A single shared helper would have made the sequence a
thing you correct once; instead it was a thing you had to notice four times.

Now in one place, `tests/AccpControlStoreSequences.cs`, expressed against delegates so the link
tests and the bus-window tests use the SAME sequence through different transports.

### Three findings that fell out of the rework

**The "ninth gated word is the address" model was already retracted in the source and still live in
a test name.** `Nd5000ControlStoreLink`'s own comments say it "was an artifact of the two latch
bytes being folded" - dated 2026-08-04 - while
`NinthGatedWord_IsTheAddress_NotMicrowordContent` went on asserting it for four weeks. The guard it
provides is real (the address must not become word 0) and is kept; the name is now
`AddressPhaseWord_DoesNotBecomeMicrowordWordZero`.

**A clock pair really is lost at the phase boundary, and it is the ROM's doing.** `ClockPairs`
dropped 80 to 79. ROM `0x7736` ends the address phase with a LONE MDCLK (`move.w D4,(A0)`,
D4 = `0x0010`) with no ADCLK after it; the first MDCLK of the shift-out arrives as a same-phase
repeat and is not a pair. The invented sequence had no trailing MDCLK to strand, which is the only
reason it came to a round 80. **The expectation is now `16 + 8*8 - 1` with that written down - do
not "restore" 80.**

**One of my own new tests was green for the wrong reason.**
`AmirckRead_DoesNotWriteTheControlStore` passed BEFORE the fix as well, because its isolated
sequence never staged eight words, so the old commit path bailed out on a short buffer rather than
on the strobe being a read. It is a valid guard now. It was not evidence then, and I nearly
reported it as one half of a red-first pair.

## 107. SSKIP: the real B30 sets Z=1 in EVERY termination, and the functional core follows the manual instead `[V]` 2026-08-31

The schpar/sskip Z question was stuck after four failed attempts to settle it by static decoding.
Executing it answered the SSKIP half in one run.

Four probes through `MacroInstructionOracle.RunBoth` (microword B30 and functional `CpuND500` on
the same vector), covering the manual's three non-trap terminating conditions:

```
  vector                        expected           MICROWORD B30        FUNCTIONAL CpuND500
  corpus 36356, skip 3          I1=3  Z=1  [corpus]  I1=3 K=0  Z=1        I1=3 K=0  Z=0
  all elements match            I1=4  Z=1  [manual]  I1=4 K=0  Z=1        I1=4 K=0  Z=1
  first element differs         I1=0  Z=0  [manual]  I1=0 K=0  Z=1        I1=0 K=0  Z=0
```

**The real B30 answers Z=1 in all three.** The functional core answers 0 / 1 / 0 - which is exactly
the manual's terminating-condition table, implemented faithfully. So `CpuND500` is the one to fix,
and this is the same shape as the `TEST_BI` carry and the single-float `-0.0` sign: the microcode
overrules ND-500 Reference Manual chapter 14.14 for this generation.

The corpus agrees with the microword, which matters because it is an independent source - if the
corpus had been generated from `CpuND500` it would have said Z=0.

### I nearly published this off ONE vector, and it would have been the wrong fix

The first run had only the corpus vector: microword Z=1, functional Z=0. The obvious patch is
"invert the different-element arm". With the other two probes the answer is not one arm at all -
Z does not encode the outcome here, so **the whole three-way branch is wrong, not one third of it.**

### And the constant answer had to be checked before it could be believed

Z coming back 1 for all three inputs has two readings, and they look identical in a log: the flag
genuinely does not depend on the outcome, or **the microword never ran the scan and 1 is a
leftover**. That is the "structurally blind instrument" case, and no amount of re-running settles
it - the same wrong number just arrives again.

What settles it is a value that MUST differ between the vectors. `I1` came back **3, 4 and 0**,
correct on both engines, so the scan really executed and stopped in the right place each time. The
diagnostic now prints `I1` and `K` beside the flags for exactly that reason, with the reason
written next to it.

### Scope, stated narrowly

Three of the manual's four terminating conditions. The fourth - "outside source", which raises a
DR trap - is NOT tested here, so this says nothing about it. `K` was 0 in all three.

### SCHPAR is still open, and its blocker is named

The SCHPAR vector still does not retire: parked at CS `0o10357` after 4096 microwords.
`MICRO-5800-B30.LABE` gives the shape - `SCHPAR_MODE` @`010352` dispatches four arms (`M00` @`010356`,
`M10` @`010365`, `M20` @`010374`, `M30` @`010403`) which all converge on `SCHPAR_END` @`010361`.
`SCHPAR_M01` @`010357` is referenced from `010363` and `SCHPAR_M02` @`010362` from `010360`, so
`M01`/`M02` is the per-element scan loop and the machine is going round it without ever reaching
the exit. **My earlier "premise broken: 0o10364 jumps to 0o10361, so it is a LOOP body" was reading
the shared EXIT as a loop.** The harness is not supplying whatever the mode dispatch needs. Fix the
setup before reading anything into SCHPAR's flags.

## 108. hw-accp round: `@nd-500` stalls before any command, and I have NO baseline to attribute it to `[V]` 2026-08-31

First run of the oracle round after the control-store fix:
`RETROCORE_ND5000_ROUND=hw-accp` (real 68000 ACCP firmware, functional `CpuND500`), same pack,
same test. **Passed in 5 m 36 s** - against 30 m 46 s for the macro round.

That speed is the first thing to distrust, and the log says why: the test is tagged
`octobus-shortbringup-no-monitor` and the ladder reads

```
  @set-avail   (OK)
  @nd-500      (STALL)
```

`@nd-500` never reaches the monitor. Nothing after it ran, which is why the run was quick and why
the test still "passed" - it took the no-monitor path. **A green result that measured nothing.**

### What I will NOT claim

**I have no pre-change `hw-accp` baseline**, so I cannot say whether this stall is old, new, or
changed by the control-store fix. Saying "the fix did not help the hw round" would be an
attribution I have not earned. What I can say:

 - the fix is proven at unit level: 148/148 ACCP tests, and the live `LOAD-CONTROL-STORE` trace now
   matches ROM `0x73B2` / `0x741E` instruction for instruction;
 - the MACRO round cannot be affected by it, because it uses the emulated ACCP handlers in
   `OctobusND5000Station`, not `Nd5000ControlStoreLink`;
 - `@nd-500` stalling is upstream of any control-store activity - no command was issued at all.

### What the run does say, and it is not nothing

```
  5MSINIT@0o111100=0x0008  5CHALIVE=True 5ALBUF=False
      -> OK: 4 SAMSON CPU(s), 1 alive -> ND-500 subsystem initialised.
  servicer MICFU trace [MicroVersion=0x2E9A CpuParameter=0x03E1]      (EMPTY - no MICFU processed)
  MON answer delivery  answers=0 inserted=0                           (upstream of this instrument)
  MON restart path     posted=0 seen=0 taken=0
  ext-block@0x007FFFF6: X5BEX=0000,0000 X5ACT=0001 X5PRO=0000
```

SINTRAN believes the subsystem initialised - one alive SAMSON CPU - and then not one MICFU is ever
processed. So the stall sits between "subsystem initialised" and "first message".

**The sharpest single line in the log is a mailbox address mismatch:**

```
  discovered mailbox   header=0x007FFEF6  extBlock=0x007FFFF6
  CARVED mailbox       5FPMAILBOX=0x0851(page 2129) 5NPMAILBOX=8 X500DF=0xFFFF
                       -> X5ACT_carved=0x0042890A   vs CS-derived X5ACT=0x00800000
                       MISMATCH (delta 0x3D76F6)
  5MBBANK PROBE        5MBBANK@0o4654=0x0000 (0) | 5FPMAILBOX=2129
                       -> XMSINIT recompute=0x0021 (33)  MISMATCH
```

`0x00800000` is exactly 8 MB and the "discovered" mailbox sits just under it, while the CARVED
address from SINTRAN's own `5FPMAILBOX` is `0x0042890A`. A discovery that lands on the top of the
address space is the shape of a scan that found the end of memory rather than a mailbox.

`MEMORY.md` already warns that ADRZERO moves with ND-100 memory size and says to check it before
believing any bring-up result. `ADRZERO@0o52047` reads `0x0000` on the first probe and `0x0840`
(2112, the expected value) on the later one - so the early probe ran before it was set, and the two
readings are a sequencing artifact rather than a contradiction. Worth not misreading as one.

### Next on this round, stated so it is not re-derived

Settle which mailbox address is right BEFORE instrumenting anything further. The carved value comes
from SINTRAN's own resident cells; the discovered one comes from our scan. They cannot both be the
mailbox, and every measurement downstream of the wrong one is measuring the wrong object -
failure-taxonomy #19, "correct about the wrong object", which survives every check that verifies
the value.

## 109. The mailbox mismatch is settled by arithmetic: the OFFSET is right and the BASE is wrong `[V]` 2026-08-31

Section 108 left two candidate mailbox addresses and said to settle which before instrumenting
anything else on the hw-accp round. No run needed - the numbers already in that log do it.

### The carved address is consistent, to the byte

```
  5FPMAILBOX = 0x0851 = 2129            ND-100 page number, read from SINTRAN's own resident cell
  ADRZERO    = 0x0840 = 2112            the ND-100 page that IS ND-500 physical 0
                                        -> the mailbox sits 17 pages above ND-500 physical 0

  an ND-100 page is 1024 words x 2 bytes = 2048 bytes
  2129 x 2048                     = 0x00428800     the mailbox page base
  X5ACT_carved                    = 0x0042890A
  offset into the page            = 0x10A = 266 bytes
```

2048 bytes per page is the only one of the three plausible page sizes that lands anywhere near:
1024 leaves a remainder of `0x21450A` and 4096 overshoots into negative. So the carved value is
`5FPMAILBOX x 2048 + 0x10A`, exactly.

### And it lands where the macro round measures real traffic

The harness's own mailbox-neighbourhood window is `[0x00428000, 0x0042D000)`:

```
  X5ACT_carved            0x0042890A   INSIDE
  macro-round cell watch  0x00428E3C   INSIDE     (627 real MICFU writes measured, section 105)
  discovered header       0x007FFEF6   outside
  discovered extBlock     0x007FFFF6   outside
  CS-derived X5ACT        0x00800000   outside
```

`0x00800000` is **8 MB exactly** - the top of ND-100 memory, not a mailbox.

### The tell, and it is not subtle once seen

```
  0x00800000 - 0x007FFEF6 = 0x10A = 266
  carved offset into its page       = 0x10A = 266
```

**The same 266.** The discovery computes the right offset and applies it to the wrong base, hanging
the mailbox off the top of memory instead of off `5FPMAILBOX`. That is why the result looks
structured rather than random, and why it survived: the internal spacing is right
(`extBlock - header = 0x100`), every field decodes, and nothing about the VALUES looks wrong.

Failure-taxonomy **#19, correct about the wrong object** - the value and the read are both right and
only the identity of the thing is wrong, so it passes every check that verifies the number.

### What this means for the hw-accp round

`ext-block@0x007FFFF6: X5ACT=0001` in section 108 was read off the wrong object, so it says nothing
about whether an activation is pending. Every measurement taken through the discovered address on
that round has to be re-read against `0x0042890A` before it means anything.

Note this does NOT explain the `@nd-500` stall by itself - SINTRAN writes its own mailbox from its
own cells and does not consult our discovery. It explains why our INSTRUMENTS on that round report
what they report.

**The fix is already named in `MEMORY.md`** (`nd5000-timeout-convergence`): use the deterministic
`5FPMAILBOX`-derived address, not the `0xFFFF -> 0` sniff. That note was written on a different
occasion and is being re-learned here, which is its own small lesson.

## 110. The corpus's divide-by-zero rows are WRONG, and only 24 of the 208 were our bug `[V]` 2026-08-31

The full corpus finally ran. Denominator first, because a failure count is not quotable without one:

```
  Loaded 40082   Executed 36427   Passed 36161   Failed 266   NegativeOK 3655
  36161 + 266 + 3655 = 40082   <- reconciles exactly, nothing silently dropped
  Pass rate 99.27%
```

The gate is `[Explicit]` on the whole `TestComprehensiveExportAndRun` fixture and it is DELIBERATE -
the comment says `RunConformanceCorpus` news a 16 MB machine per case with no failure limit and
exceeds the CI blame-hang timeout. A default `dotnet test` skips it, which is why a green ND-500
suite says nothing about these rows.

### 266 failures, one family

```
  Div      208    every one a divide-by-zero        78% of the whole gap
  Sfilln    12
  Div4 / div3 / div2 / mul2 / add2   ~17
  long tail  1-4 each
```

### The trap I nearly walked into

All 208 fail the same way: the corpus expects the destination UNCHANGED (`i1` keeps the dividend)
with `st=0x1000`; we write a saturated quotient with `st=0x1080`, the extra bit being S. The obvious
move is to stop writing the destination.

**`Divide.cs` saturates deliberately, and its comment cites the microcode** - the divide-by-zero
path branches on dividend sign at `@024133`, positive to `@024134` (max positive, S=0), negative to
`INTDN @024136` (most negative, S=1), traced `-12/0 -> X1=0x80000000 S=1` and `+5/0 -> X1=0x7FFFFFFF
S=0`, adjudicated 2026-07-26. So this was a prior microcode adjudication against a corpus
expectation, and patching either to satisfy the other is guessing.

As the peer put it precisely: the corpus constrains what the destination should CONTAIN; the
architectural claim is that the instruction never writes it at all. **Those are different
propositions, and a clamp that satisfies the first can still be wrong about the second.**

### Asked the B30, with vectors chosen so the two answers cannot be confused

`DivideByZeroOracleDiagTests`, byte width, divisor 0:

```
  dividend    microword B30      CpuND500 (before)   corpus expects
  0x00        0x00   S=0         0x7F  S=0           0x00  <- corpus and B30 AGREE, we were wrong
  0x64        0x7F   S=0         0x7F  S=0           0x64  <- corpus alone, and it is wrong
  0xAA        0x80   S=1         0x80  S=1           0xAA  <- corpus alone, and it is wrong
  0xFF        0x80   S=1         0x80  S=1           0xFF  <- corpus alone, and it is wrong
  0x7F        0x7F   S=0         0x7F  S=0           0x7F  <- CANNOT DISCRIMINATE, labelled as such
```

**The real B30 saturates.** The 2026-07-26 adjudication holds and the corpus is wrong for those
rows. `0x64` is the load-bearing vector precisely because it is not a saturation value at any width,
so "unchanged" and "saturated" are different numbers there; `0x7F` is kept in the probe and labelled
inert, because it predicts the same answer under both hypotheses and must never be counted as
confirmation.

### But one subset discriminates the OTHER way, and that one was ours

A **zero dividend** is not saturated - it stays 0, and S stays clear. The recurrence says why: the
non-restoring algorithm builds the quotient by shifting the dividend left, so with a zero dividend
nothing ever becomes non-zero. We were saturating unconditionally and turning `0/0` into `0x7F`.

Here the corpus and the microcode AGREE against us - two independent sources - which is what makes
it the safe fix. Split of the 208:

```
   24  corpus expects 0, we gave 0x7F     OUR BUG      fixed
  176  corpus expects the unchanged dividend, B30 says saturate    THE CORPUS IS WRONG
```

Fixed in `Divide.cs`; both engines now agree on all five vectors.

### What is NOT settled, and must not be quietly assumed

Whether real HARDWARE suppresses the destination write when the trap fires. The microword CPU
executes the real microcode and the microcode writes the register, so "the microcode writes it" is
solid - but write-suppression on a precise trap would live in hardware, outside the microcode, and
nothing here can see that. If it does suppress, the corpus is right and both our engines are wrong
together, which is exactly the case two agreeing engines cannot detect.

**So do NOT mass-regenerate those 176 corpus rows.** The corpus is a shared fixture with nd500x, and
regenerating it from `CpuND500` would bake our answer in and destroy the only independent source
that currently disagrees.

## 111. SFILLN: the H and W corpus rows are COPIES of the BY row `[V]` 2026-08-31

Second cluster in the corpus tail, 12 rows. It needed no oracle to spot and the oracle confirmed it.

`Sfilln_BY_Fill4At2`, `Sfilln_H_Fill4At2` and `Sfilln_W_Fill4At2` assemble three DIFFERENT
instructions - a byte, halfword and word fill of 4 elements from index 2 - and carry
**byte-identical expected final memory**:

```
  all three widths:   DE DE 42 42 42 42 DE DE      at 0x2100..0x2107
```

Four elements of width 1, 2 and 4 cannot all touch the same four bytes. The generator varied the
INSTRUCTION and not the EXPECTATION.

Which row is right settles itself: **BY passes, H and W fail** - 4 H rows and 8 W rows, exactly the
12. The BY expectation is correct and the other two inherited it.

### The oracle confirms it

`StringFillOracleDiagTests` runs all three vectors through the microword B30 and the functional
`CpuND500`, comparing registers, flags and all EIGHT buffer bytes:

```
  Sfilln BY   I2=6 both   ENGINES AGREE
  Sfilln H    I2=6 both   ENGINES AGREE
  Sfilln W    I2=6 both   ENGINES AGREE
```

The whole buffer is checked, not just the bytes expected to move - a fill at the wrong offset shows
up only in the bytes nobody thought to look at.

### What the corpus CANNOT answer here, and why

Two questions remain genuinely open, and the reason is worth stating: **the only row that passes is
the one width where they are indistinguishable.**

 - is the start index in ELEMENTS or in BYTES? At BY width those are the same number.
 - is the fill value written element-wide, so an H fill of `0x0042` lays down `0x00 0x42`?

Our core answers "elements" and "element-wide", and the B30 agrees with it, which is the standard
this project uses. But no VECTOR in the corpus discriminates them, so the corpus can neither confirm
nor refute those two choices - it can only be wrong about H and W, which it is.

### Running total of the corpus tail

```
  184  divide-by-zero   corpus wrong (section 110)
   12  SFILLN H and W   corpus wrong (this section)
  ---
  196  of 242 = 81% of the remaining failures are DEFECTS IN THE FIXTURE, not the engine
```

**Still do not regenerate.** The corpus is shared with nd500x and regenerating from `CpuND500` would
bake our answers in - including the two undiscriminated choices above, which would then look
confirmed while nothing had ever tested them.

## 112. The 16 "documented overflow" rows expect an IGNORABLE trap that nothing enables `[D]` 2026-08-31

Third cluster in the corpus tail. Sixteen rows, all failing on exactly one line -
`Expected trap 'IntegerOverflow' but no trap occurred` - and nothing else:

```
  4  /_W_documented_minDividedByMinusOne          MIN / -1
  3  add2_{BY,H,W}_documented_maxplus1            MAX + 1
  3  div2_{BY,H,W}_documented_minDividedByMinusOne
  3  div3_{BY,H,W}_documented_minDividedByMinusOne
  3  mul2_{BY,H,W}_documented_minTimesTwo         MIN x 2
```

These are genuine overflow conditions and the engine does compute them: `Add2.cs` calls
`cpu.TrapIntegerOverflow` on overflow, and every sibling does the same. So the question is not
whether we notice the overflow - it is whether the trap is DELIVERED.

### Integer overflow is an IGNORABLE trap, by our own trap table

`CpuND500.Trap.cs` classifies it verbatim: *"Integer Overflow (Bit 9) - Ignorable"*, and the header
defines the class as *"May be disabled, no effect on program execution"*. Delivery runs through the
local-trap-enable gate carved from the control store at `011034-011037`:

```
  011034  AL#21 := TE                  the LOCAL TRAP ENABLE REG
  011035  AL#21 |= 0xC0000000          bits 31,30 forced always-enabled
  011036  AL#21 &= 0xFFFFFE00          bits 8..0 forced NEVER local
  011037  AL#21 &= S1                  AND with the PENDING trap bits
  011064  zero -> report to the ND-100 ; non-zero -> dispatch to the handler
```

Bit 9 survives the `0xFFFFFE00` mask, so integer overflow CAN be locally enabled - and is delivered
only if `TE` bit 9 is set. **Every one of these sixteen vectors starts with `st: 0` and establishes
no trap-enable at all.** So they ask for delivery of an ignorable trap that nothing enabled.

### What I have NOT shown, and the experiment that would settle it

Graded `[D]`, not `[V]`, on purpose. I have shown the corpus expectation is inconsistent with the
vectors' own initial state. I have NOT shown that our engine SUPPRESSES at the enable gate rather
than failing to deliver for some unrelated reason - and those two look identical from a corpus row.
If ignorable traps are never deliverable at all, that is a real defect and this cluster is hiding it.

**The decisive experiment is one line:** set `TE` bit 9 and re-run a single `add2_BY_maxplus1`
vector. Trap fires -> the gate works, the engine is right, the corpus is wrong. Trap still absent ->
the engine cannot deliver ignorable traps and 16 rows are the symptom, not the noise.

This is memory #11b applied: **ask the trap's CLASS before instrumenting it.** For an Ignorable
trap, absence proves nothing on its own - which is exactly why this cluster cannot be closed by
looking harder at the corpus.

### Running total of the corpus tail

```
  184  divide-by-zero    corpus wrong                    [V]  section 110
   12  SFILLN H and W    corpus wrong                    [V]  section 111
   16  overflow traps    corpus inconsistent with itself [D]  this section, experiment named
  ----
  212  of 242 = 88% accounted for; 30 rows still uncharacterised
```

### 112a. The overflow experiment ran, and the guard I built into it caught my own mistake `[V]` 2026-08-31

Section 112 named a one-line experiment. It took three attempts and each failure was instructive.

**Attempt 1 - the instruction was not the instruction.** I hand-assembled `BY ADD2 I1,I2` as
`FD 10 C1 C2`. Both runs came back silent, which is precisely the "ignorable traps are
undeliverable" answer I was testing for. It was wrong: the paired detection assertion showed
**O clear in both runs** - nothing had overflowed, because nothing had executed as intended. The real
bytes are `FC 17 D0 D1`, read out of the corpus row.

**That guard was the whole value of the test.** Silence for the right reason and silence because
nothing ran are the same observation in the delivery result. Asserting detection SEPARATELY and
FIRST is what separated them - and without it I would have published a fabricated defect.

**Attempt 2 - the enable is not sufficient.** With the real bytes, O is set and the trap IS raised
(`LastTrapReason` = "ADD2 integer overflow"), but setting `OTE1` bit 9 changed nothing. Reading the
gate explains why - delivery needs FOUR conditions, not one:

```
  TrapDispatchEnabled  AND  locallyEnabled  AND  regs.THA != 0  AND  NOT pcb.InsideTrapHandler
```

`THA` was 0, so there was no vector table to dispatch through. "The enable changed nothing" was true
and meant nothing.

**Attempt 3 - a raw THA is still not enough, and here I stopped.** Installing `THA` plus a non-zero
handler slot for trap 9 still did not dispatch. `GetTrapHandlerAddress` resolves through the
domain/DIT and a TRANSLATED vector read, which a bare instruction harness does not set up.

### What is established, and what is not

**Established `[V]`:** the overflow is detected, the trap is raised, and it is correctly withheld
when nothing enables it. So "no trap occurred" is RIGHT for all sixteen corpus rows.

And they cannot be otherwise: the corpus register model contains no `OTE1/OTE2/MTE1/MTE2` - its own
generator says so - and no `THA` either. **A corpus row is structurally incapable of setting up
delivery, so it can never legitimately assert that an ignorable trap was delivered.** That is a
stronger statement than "these 16 rows are wrong": no row of this shape can ever be right.

**NOT established `[OPEN]`:** whether this engine would deliver given a fully configured domain.
Attempt 3 failed for an unidentified reason. The test says so in its own remarks rather than
implying coverage it does not have - it is named
`OverflowTrap_IsRaised_ButNotDeliveredWithoutEnableAndHandler`, which is exactly what it checks.
Closing it needs a DIT-backed domain with a real Start Address Vector.

### Corpus tail after this

```
  184  divide-by-zero    corpus wrong                     [V]  section 110
   12  SFILLN H and W    corpus wrong                     [V]  section 111
   16  overflow traps    corpus CANNOT express delivery   [V]  section 112 + this
  ----
  212  of 242 = 88%; 30 rows still uncharacterised
```

## 113. The rest of the corpus tail: privilege, a deliberate divergence, and what is actually left `[V]` 2026-08-31

### 9 rows: privileged instructions run without privilege

`cpgu cwip dcc dctsb dmof dmon pctsb pmof pmon` all fail with **`PC` still at `0x1000`** - the
instruction never advanced. They are not missing: every one has an implementation under
`Instructions/SYSTEM/`, and every one opens with

```csharp
    if (!regs.ST.PIA) { cpu.TrapIllegalInstruction(regs.PC, "PMON requires privileged mode"); }
```

Every vector starts `st: 0`, so PIA is clear and the refusal is correct. `dcc` makes it explicit -
its row reports *"Unexpected trap occurred: 'IllegalInstruction'"*, which is our correct refusal
being read as a surprise.

**This one differs from the trap-enable cluster in a way worth keeping straight.** PIA is ST1 bit 1,
so the corpus CAN express it through the `st` field - unlike `OTE`/`THA`, which have no slot at all.
So these rows are not structurally impossible, merely wrong: they ask an unprivileged program to
execute privileged instructions. Fixable by seeding `st` with PIA; not fixable for the trap rows.

### 2 rows: TSET with a register operand

`BY TSET I1` - our core raises `TrapIllegalOperand` ("TSET with register/constant operand (memory
operand required)"). Test-and-set is a memory lock primitive, so a register operand looks like a
generator artefact rather than a real encoding. `[OPEN]`: whether the real machine advances PC on an
illegal-operand trap is a separate question this does not answer.

### 1 row: Test_F_NegZero fails BY DESIGN - do not "fix" it

```
  Test_F_NegZero: F TEST A1
     ST mismatch: expected 0x00000000000000A0, got 0x0000000000000020
```

`0xA0` is Z (bit 5) + S (bit 7); we give Z only. **That is exactly the change Ronny adjudicated on
2026-08-30** (plan item 5): for SINGLE float, the real B30 computes S as "sign AND the SRF4-masked
value is non-zero", so `-0.0` tests as non-negative and S stays clear. Manual 10.11 says the raw
sign bit, and the microcode overrules it.

**So this corpus row is a KNOWN, DELIBERATE divergence and must stay red until the corpus is
regenerated.** Anyone triaging the tail later will find a one-row float failure that looks trivially
fixable; reverting it would undo a decision made from the microcode with the user's adjudication.

### Where the corpus tail stands

```
  184  divide-by-zero        corpus wrong, B30 verified                [V]  s110
   12  SFILLN H and W        corpus wrong, copies of the BY row        [V]  s111
   16  overflow traps        corpus CANNOT express delivery            [V]  s112/112a
    9  privileged SYSTEM     corpus does not grant PIA (but could)     [V]  this section
    2  TSET register operand generator artefact, PC question [OPEN]    [D]  this section
    1  Test_F_NegZero        DELIBERATE divergence, keep it red        [V]  this section
  ----
  224  of 242 = 93% accounted for
   18  genuinely uncharacterised: Chain 4, Div4 4, Riom 2, Scopt 2, Sspan 2, Sscan 1,
                                  Schpar 1, and 2 others
```

**The headline for item 9 has not moved and is worth repeating: almost none of this is engine bugs.**
Of 266 failures at the start of the day, exactly 24 were ours - the zero-dividend divide - and they
are fixed. The rest is a fixture that disagrees with the microcode, cannot express the machine state
its own expectations require, or contains rows copied between widths.

## 114. Item 1's framing was wrong AGAIN - 3SWMESS is not supposed to reach the CPU at all `[V]` 2026-08-31

Section 105 corrected item 1 from "one 3SWMESS, late" to "twelve, from six sites". The plan then
asked why twelve postings produce no progress. **That question is also misdirected**, and the
servicer trace from the same run says so in one line.

### What the CPU actually serviced in the whole place-domain run

```
  262  MICFU=0x01  3RMICV   read-micro-version
   13  MICFU=0x19  PHYSWR   physical-write, 4 bytes each
    1  MICFU=0x0A  CACHE    cache-clear
  ---
    0  MICFU=0x05  3SWMESS
```

**Three distinct micro-functions, and 3SWMESS is not one of them - which is CORRECT.**
`Nd5800MicfuDispatchTableTests` proves `0o5` routes to `MSG_ILLEG` on this generation: the B30 does
not implement 3SWMESS. So the twelve stamps in SWPINFO are the ND-100 driver's OWN routing marker
and were never going to become a CPU message. Looking for their effect on the ND-500 was looking in
a place the architecture forbids them to reach.

`MEMORY.md` records exactly this under the dispatch-table entry - *"the MICFU=5 that LNEWSWAP reads
out of SWPINFO is a marker for the ND-100 driver's own routing, not a command to the CPU"* - written
when I carved the table earlier the same day, and not applied to item 1 until now.

And the 262 3RMICV are not activity: the octobus skill states plainly that 3RMICV is the WATCHDOG
heartbeat and *"a burst of 3RMICV means TIME PASSED, nothing more"*.

### So what place-domain really does, and where it really stops

One cache-clear, then twelve words scattered into ND-500 LOW PHYSICAL memory, then nothing but
watchdogs. The twelve, in issue order, all sourced from the same ND-100 staging cell `0x0000CC00`:

```
    1-3   0xBC 0xC0 0xC4        three words, bytes 0xBC..0xC7
    4     0xB6                  one word,    bytes 0xB6..0xB9      (0xBA..0xBB never written)
    5-12  0x96 0x9A 0x9E 0xA2 0xA6 0xAA 0xAE 0xB2
                                EIGHT CONTIGUOUS words, bytes 0x96..0xB5
    13    0xA6 again            the 5th word of the run, REWRITTEN
```

Twelve distinct addresses, thirteen writes. The eight-word contiguous run is the shape to chase -
low ND-500 physical memory is where the register block and PST live, per the MEMORY-CONFIGURATION
command's own description.

### One thing the plan says that this run does NOT show

The plan states that this block is a *"write-then-read-back VERIFY"*. **There is not a single
PHYSRD in this run** - the census above is the whole trace. Either the verify belongs to
`start-swapper` and not `place-domain` (they are different commands and that is the likely answer),
or the plan's claim needs re-sourcing. Do not repeat "the verify completes and passes" about
place-domain on the strength of this run.

### The real question for item 1, third and hopefully final formulation

Not "who writes 3SWMESS" (section 73, wrong). Not "why do twelve postings make no progress"
(section 105, wrong - they were never meant to reach the CPU). It is:

**what are the twelve words SINTRAN scatters into ND-500 physical `0x96..0xC7`, and what does it
wait for after writing them?** Everything after that point is watchdog.

### Method note

Three formulations, three corrections, and each correction came from an instrument that was already
in the run - the cell watch for the first, the servicer census for this one. The census was printed
in every capture for weeks. **Read the whole report before forming the question, not just the
section the current theory points at.**

## 115. ANSWERED - ND-500 physical `0x96..0xC7` is the DOMAIN INFORMATION TABLE's trap-enable block `[V]` 2026-08-31

The deep-dive reference lists this as open item 7 and calls it *"the live blocker, not a protocol
gap"*; the 2026-07-28 MICFU reference ends on it under a heading that says **do NOT guess it**. It
has been open since July. It is answerable from data already in the repo.

### The twelve words are PCB fields, and every one lands on a field START

`struct pcb` in the real ND-500 Unix kernel (`E:\Dev\Ronny\NDIX-C\kernel\MASTER\machine\pcb.h`,
`MAXSEG 32`) laid out packed:

```
  written   field        written   field
  0x96      pcb_ote1     0xB2      pcb_temm2
  0x9A      pcb_ote2     0xB6      pcb_tha
  0x9E      pcb_cte1     ----      (0xBA pcb_md, 0xBB pcb_ith - see below)
  0xA2      pcb_cte2     0xBC      pcb_tos
  0xA6      pcb_mte1     0xC0      pcb_ll
  0xAA      pcb_mte2     0xC4      pcb_hl
  0xAE      pcb_temm1    0xC8      pcb_pia   <- FIRST byte after the block ends at 0xC7
```

**Twelve writes, twelve field starts.** So the block is:

> **Own / Child / Mother Trap Enable, the Trap Enable Modification Mask, the Trap Handler Address,
> and the Top-of-Stack and Low/High Limit registers - i.e. the trap-enable and domain-limit section
> of the Domain Information Table for domain 0.**

The DIT is 256 bytes per domain and KDOM is domain 0, so domain 0's table sits at physical
`0x00..0xFF` and these offsets are absolute addresses.

### The GAP is the sharpest evidence, and it was free

`0xBA..0xBB` is never written. Those two bytes are `pcb_md` and `pcb_ith` - **the only two
single-BYTE fields anywhere in the written span.** A 4-byte `PHYSWR` cannot express them, so
SINTRAN skips them. A layout guess would have to explain that hole; this one predicts it.

### Three sources, and one of them is genuinely independent

 1. the `pcb.h` struct, laid out by hand;
 2. our own `CpuND500.Domain.cs` constants - `DIT_OTE1_OFFSET = 150 (0x96)`,
    `DIT_MTE1_OFFSET = 166 (0xA6)`, `DIT_THA_OFFSET = 182 (0xB6)`, `DIT_TOS = 188 (0xBC)`,
    `DIT_LL = 192 (0xC0)`, `DIT_HL = 196 (0xC4)`, `DIT_PIA = 200 (0xC8)` - every one matching;
 3. **the live capture itself**, which is the independent one. (1) and (2) share ancestry -
    our constants were surely derived from that header - so they corroborate each other only
    weakly. The July write pattern was recorded before any of this was asked and matches both.

### What it means, and the convergence nobody was looking for

`place-domain` is **installing the trap configuration for the domain it is about to run** - trap
enables, the trap-handler vector, the stack pointer and the memory limits.

And those are the SAME three registers this session spent the afternoon on from the other end.
Section 112a could not make an ignorable trap deliver because `OTE`/`MTE`/`THA` were unset and
`GetTrapHandlerAddress` resolves through the domain/DIT; the corpus cannot express them at all.
**Here is SINTRAN writing exactly those fields into exactly that table.** The corpus question and
the place-domain blocker are the same question approached from opposite directions.

### The next question, which is now a specific one

Not "what is this block". It is: **after SINTRAN writes the DIT trap configuration, what does it
wait for - and does our engine LOAD `OTE`/`MTE`/`THA` from the DIT when the domain is entered?**
If it does not, the configuration SINTRAN just installed is inert, which would explain both the
place-domain silence and the undeliverable ignorable trap.

### Caveat carried forward from the 2026-07-28 file, still unretired

Whether `addrA` on the copy family should resolve to ND-500 LOCAL memory rather than through
`Nd500AddressBase` into the MPM window. **A self-consistent round-trip hides the difference, so the
passing verify does NOT prove the target is right.** Knowing what the block IS does not settle
where it landed.

## 116. The microcode DOES load TE from the DIT on context load - and our engine does not `[V]` 2026-08-31

Section 115 ended on a specific question: does the engine load `OTE`/`MTE`/`THA` from the DIT when a
domain is entered? Both halves now have answers, and they differ.

### Our engine: THA yes, OTE/MTE no

`CpuND500.Domain.cs`, `LoadDomainStateFromDIT`:

```csharp
    regs.TOS = ReadDIT_TOS(domain);
    regs.LL  = ReadDIT_LL(domain);
    regs.HL  = ReadDIT_HL(domain);
    regs.THA = ReadDIT_THA(domain);
    // and nothing else
```

Four of the five hardware-relevant fields. **`regs.OTE1/OTE2/MTE1/MTE2` are never loaded from the
DIT anywhere in the codebase** - the only assignments are the `.DOM` file header
(`CpuND500.Loader.cs:2059-2062`), the debug register API, and the process register block.
`ReadDIT_OTE` and `ReadDIT_MTE` exist and are used by the propagation logic, but never to populate
the registers.

That matters because the local-trap-enable gate reads the REGISTERS, deliberately and correctly -
its own comment cites microcode `011034` taking TE from `'A,XD,TE`, a register, and records that a
DIT read placed in that gate faulted and swallowed a trap. So the gate is right; nothing fills what
it reads.

### The microcode: TE IS loaded, in CNTXTLOAD, from DIT reads

The context-load tail, right after the PIA re-derivation that `MEMORY.md` already describes:

```
  015075   ALU,OR  A,DATA B,SC4 D,SC4   TE,ALU,LOAD   RD,PHYS ADACT   (DPA-relative byte read)
  015076   ALU,XOR TYP,BY A,DATA B,SC14 D,SC7          RD,PHYS
  015077-015102   derive MIC,STS - the PIA bit-1 overwrite
  015103   ALU,XOR A,SC4 B,SC14 D,IDU,TE
  015104   ALU,XOR A,SC4 B,SC14 D,MIC,TE
```

`XOR` against `SC14` is this microcode's MOVE idiom, so `015103/015104` are **TE := SC4**, and SC4
was accumulated at `015075` by OR-ing in bytes read from the domain table. **Context load populates
the TE register from the DIT.**

### Two method notes, both about searches that lie

**`D,TE` found ZERO writes.** The mnemonic is `D,MIC,TE` and `D,IDU,TE` - TE is written through two
destination namespaces. A wrong pattern returned a confident empty set that read as "the microcode
never writes TE", which is the exact shape that cost this session an hour on `MOVE.W #imm,(An)`
earlier. What caught it was enumerating the FORMS (`grep -oE ... | sort | uniq -c`) instead of
testing one guess.

**The other four TE writes are CLEARS, not loads** - `014607`, `014610`, `017744`, `017745` all use
`ALU,FZRO` (force zero). Only the CNTXTLOAD pair carries a value. Counting "6 writes to TE" and
stopping would have found the right number and the wrong meaning.

### Scope, stated narrowly

Read from the RENDERED `MICRO-5800-B30.md`, which is reliable for MNEMONICS and **is not** for
`ORCON`/`MARG` - the file's own inline annotation on `015075` says so, flagging its `IX*2 ORCON=0x08`
as a mis-split of raw `MARG=0x48`. So: *that* TE is loaded from DIT reads is `[V]`; exactly WHICH
DIT offsets feed SC4 is `[OPEN]` and needs a raw decode.

### The candidate defect, not yet applied

`LoadDomainStateFromDIT` should probably also load `OTE1/OTE2/MTE1/MTE2`. **Not changed yet, on
purpose:** the exact source offsets need the raw decode above, and trap-enable affects delivery
everywhere, so this is not a one-line patch to make on a rendered listing. But it is now a specific
hypothesis with a named experiment rather than an open question - and it would explain BOTH
section 112a's undeliverable ignorable trap and place-domain going quiet after installing a trap
configuration the engine then ignores.

## 117. RAW decode confirms the DIT layout a third time - and corrects my own section 116 `[V]` 2026-08-31

Section 116 was read off the RENDERED `MICRO-5800-B30.md`, which the project rules say never to
trust for `ORCON`/`MARG`. Ran the raw decode instead - and the test for it already existed,
`MicrowordDecodeTests.Dit_AddressingPath_RawDecodeDump`, named in the `.md`'s own inline annotation.
**"Check the existing machines before building anything" applied to a decoder I was about to
write.**

### The raw MARG values, and what they address

`DPA = pcb_base + CED*256 + 0x80`, so a DPA-relative `MARG` is `base + 0x80 + MARG`:

```
   word     MARG   absolute   field       note
  0o15072   0x16     0x96     pcb_ote1    address setup, MemOp=0 (no read)
  0o15073   0x3B     0xBB     pcb_ith     read
  0o15074   0x26     0xA6     pcb_mte1    read
  0o15075   0x48     0xC8     pcb_pia     read
```

**All four land on PCB fields.** This is a THIRD confirmation of section 115's layout, and the first
from raw microcode rather than a C struct - genuinely independent of both `pcb.h` and our own
`DIT_*_OFFSET` constants.

It also demonstrates the render bug in place: `0o15075` prints as `IX*2 ORCON=0x08` in the `.md`,
and raw it is `MARG=0x48` - `DPA+0x48`, the PIA byte, exactly as the file's annotation warns.

### The correction to section 116

Section 116 said the CNTXTLOAD tail loads TE "from a value accumulated out of DIT reads", which
reads as *the trap-enable mask is loaded from the DIT*. **The raw decode does not support that
reading.** The bytes actually read into SC4 in this block are `pcb_ith` and `pcb_pia` - single
BYTES, not the 64-bit `OTE`/`MTE` pair. `pcb_ote1` at `0o15072` is an ADDRESS SETUP with `MemOp=0`;
no read happens on that word.

So, precisely:

 - `[V]` this block reads DIT bytes at DPA `+0x16`, `+0x3B`, `+0x26`, `+0x48`;
 - `[V]` `0o15103`/`0o15104` write the TE register (IDU and MIC namespaces);
 - `[OPEN]` **what value TE receives.** The visible reads feeding SC4 are ITH and PIA bytes, which
   is not what a trap-enable mask should be made of. `TE,ALU,LOAD` at `0o15075` is a CONTROL-field
   strobe and is NOT the same thing as the `D,MIC,TE` destination - conflating them is what made
   116 sound settled.

### What survives, and what the next step actually is

The **asymmetry in our engine still stands and is still a real candidate defect**: THA is loaded
from the DIT, `OTE`/`MTE` are never loaded from anywhere but a `.DOM` header, and the local gate
reads registers nothing fills. That is independent of how the microcode composes TE.

But **do not "fix" it by copying `ReadDIT_OTE` into `LoadDomainStateFromDIT` on the strength of
this.** The microcode may compose TE from something other than a straight copy of `pcb_ote1/2`, and
guessing would install a plausible wrong answer in the one place that gates every trap in the
machine. Trace SC4 backwards from `0o15103` first.

### Method note - the same trap, twice in one session, from opposite directions

Earlier today a wrong opcode (`30FC` for `30BC`) returned a confident EMPTY set. Here a rendered
listing returned a confident WRONG value. Both are "the instrument answered fluently and the answer
was about something else". The defence that worked both times was the same: go to the raw bytes, and
prefer an existing verified decoder over one written in the moment.

## 118. A mislabelled PCB constant, found by the layout - correct address, wrong name `[V]` 2026-08-31

Looking for somewhere to run the TE experiment turned up a latent error that section 115's layout
catches on sight. `MmsUnit.cs` had:

```csharp
    /// <summary>pcb_cte1 - child trap enable (microcode DPA+0x26).</summary>
    public const uint PcbChildTrapEnableOffset = 0xA6;
```

`0xA6` is `pcb_mte1` - the **MOTHER** trap enable. Child (`pcb_cte1`) is at `0x9E`. The struct order
is `ote1 ote2 cte1 cte2 mte1 mte2 temm1 temm2`, four bytes each from `0x96`.

**The ADDRESS is right** - `DPA+0x26` really is what the microcode reads there, and the raw decode in
section 117 confirms it. **Only the NAME is wrong.** So it would have survived every check that
verified the number: failure-taxonomy #19 exactly.

Nothing consumed the constant yet, so nothing was ever miscomputed - but it is declared for the
benefit of whoever wires trap-enable loading, which is the open candidate fix from section 116/117.
That person would have read "child" and got "mother".

Fixed, and the map completed from the verified layout while the evidence was in hand: `ote2`,
`cte1`, `cte2`, `mte1`, `mte2`, `temm1`, `temm2`, `tha`, `md` all added with their DPA-relative
offsets and a comment naming the three sources.

**Worth noting how it was found.** Not by auditing that file - by needing a place to run an
experiment and reading what was already there. A verified layout is a lens: once section 115 existed,
the error was visible in the first constant block anyone opened.

### Where the TE thread stands

The executable experiment is set up but NOT yet run. The pieces exist:
`SwapperStartDiagnosticTests` already drives IDLE -> MSG_START -> NEWCNTXT -> EXECUTE on the
microword CPU with a seeded DIT, `MmsUnit.SetDomainPia` shows how to seed a DIT field, and the CPU
models the TE register in both namespaces (`regs.MicTe`, `regs.IduTe`, `OperandRouter` cases 160 and
the MIC equivalent).

**The experiment:** seed the DIT with distinctive `OTE1/OTE2/MTE1/MTE2` values, run the context
load, read `MicTe`/`IduTe` after. If TE picks up the seeded trap-enable fields, our
`LoadDomainStateFromDIT` should load them too. If it picks up something else, section 116's reading
is dead and the composition is whatever the register shows.

**This is the right instrument for it.** Static decoding has now produced one over-claim (116) and
one correction (117) on this question; the SSKIP precedent says the next step after that pattern is
to execute, not to decode harder.

## 119. The manual reframes the whole TE question - and names a defect in the enable mask `[M]` 2026-08-31

Before propagating the section-118 rename into a second file, I checked the manual that file's
comment cites. It answers a bigger question than the naming one. ND-05.022.1 §3.1, Table 1
"Context Registers for a Process in the ND-5000":

```
  TOS, LL, HL                      per-domain registers
  THA        Trap handler address        (Domain info. table)
  OTE1+OTE2  Own trap enable             (Different gate array)
  MTE1+MTE2  Mother trap enable          (Different gate array)
  CTE1+CTE2  Child trap enable           (Domain info. table)
  TEMM1+TEMM2 Trap modification mask     (Domain info. table)
```

and the prose beneath it:

> *"Hardware trap enable register is either **MTE when inside trap handler** or **MTE OR'ed with OTE
> when outside trap handler**. ... The trap handler (THA), the child trap enable (CTE1 and CTE2) and
> the trap enable modification mask (TEMM1 and TEMM2) registers will reside **only in the Domain
> Information Table**."*

### What this settles about our engine's asymmetry

**It is not obviously a bug.** `THA` resides ONLY in the DIT, so loading it from there - which
`LoadDomainStateFromDIT` does - is exactly right. `OTE`/`MTE` have REGISTER homes in gate arrays, so
they are not DIT-resident in the same sense; the PCB copy is per-domain backing store. That makes
"we never load OTE/MTE from the DIT" a defensible position rather than the clear defect section 116
implied, and is a second reason not to have patched it.

It does NOT settle whether context load copies the DIT copy into the registers - if it never did,
the registers could not hold per-domain values at all. That still wants the execution experiment.

### The defect the manual DOES name, and it is in code I read three times

Our local-trap-enable gate composes:

```csharp
    ulong localTrapEnable = ((ulong)regs.OTE2 << 32) | regs.OTE1;
    localTrapEnable |= ((ulong)regs.MTE2 << 32) | regs.MTE1;     // <- unconditional
```

**It always ORs OTE with MTE.** The manual says the hardware register is `MTE` ALONE when inside a
trap handler, and `MTE | OTE` only outside it. `pcb.InsideTrapHandler` is available - the dispatch
condition a few lines below already tests it - and the mask composition ignores it.

Effect: while inside a trap handler, a trap that only OTE enables would be delivered, where the
hardware would withhold it. Graded `[M]` - manual, not yet confirmed against the microcode, and this
project's rule is that the microcode wins. **Confirm at `011034` before changing it**; the words are
already dumped in section 112's citation.

### And a caution on my own section 118 rename

The rename (`0xA6` is `pcb_mte1`, not `pcb_cte1`) rests on `pcb.h` DECLARATION ORDER from `0x96`,
which is solid for offsets. But note the manual says CTE resides ONLY in the DIT while MTE has a
register home - so a microcode READ of `DPA+0x26` is, on its face, more what you would expect of a
DIT-only value like CTE. The offsets say `mte1`; the residency hint leans `cte`. **The offsets win**
- declaration order in a real OS header is hard evidence and residency is an inference - but this is
recorded because it is the one place the sources pull in different directions, and a later reader
deserves to know that rather than find the rename unexplained.

## 120. SETTLED by the microcode's own routine names: eight LOADCT_* routines, we implement four `[V]` 2026-08-31

Going to confirm the manual's `MTE`-alone rule at the address our own source cites, I found that
`0o011034` is not the trap gate at all. It is a **guarded context-load dispatcher**, and it named
everything this thread has been circling. From `MICRO-5800-B30.LABE`:

```
  LOADCT_TOS  011162     LOADCT_OTE  011175
  LOADCT_LL   011164     LOADCT_CTE  011200
  LOADCT_HL   011165     LOADCT_MTE  011203
  LOADCT_THA  011166     LOADCT_TEMM 011206
```

**Eight routines. `CpuND500.LoadDomainStateFromDIT` implements the first FOUR.**

### Raw decode: all twelve reads land on a field, zero misses

`ContextLoad_TrapConfigRoutines_RawDecodeDump` (new), `DPA = PcbBase + domain*256 + 0x80`:

```
  LOADCT_TOS  011163  MARG 0x3C -> 0xBC pcb_tos     LOADCT_OTE  011175  0x16 -> 0x96 pcb_ote1
  LOADCT_LL   011164       0x40 -> 0xC0 pcb_ll                  011177  0x1A -> 0x9A pcb_ote2
  LOADCT_HL   011165       0x44 -> 0xC4 pcb_hl      LOADCT_CTE  011200  0x1E -> 0x9E pcb_cte1
  LOADCT_THA  011166       0x36 -> 0xB6 pcb_tha                 011202  0x22 -> 0xA2 pcb_cte2
                                                    LOADCT_MTE  011203  0x26 -> 0xA6 pcb_mte1
                                                                011205  0x2A -> 0xAA pcb_mte2
                                                    LOADCT_TEMM 011206  0x2E -> 0xAE pcb_temm1
                                                                011210  0x32 -> 0xB2 pcb_temm2
```

**Twelve for twelve.** Each routine reads its low half then its high half, four bytes apart.

### This settles two things I had wrong

**1. Section 118's rename is confirmed by the microcode's own naming.** `LOADCT_CTE` reads
`0x1E/0x22` and `LOADCT_MTE` reads `0x26/0x2A`. So `0xA6` **is** `pcb_mte1`, and the old
"child trap enable = 0xA6" label was wrong. Section 119 flagged a tension between the offsets and
the manual's residency hint and said "the offsets win" - they do, and this is the proof. That
tension is now closed, not merely adjudicated.

**2. Section 119's "the asymmetry is probably not a bug" is REFUTED.** The microcode explicitly
loads OTE, CTE, MTE and TEMM on context load, from exactly these DIT offsets. Our engine loads
TOS/LL/HL/THA and stops. **It is a gap.**

I over-read the manual. It said where those registers RESIDE - "different gate array" - and I took
that to mean they are not loaded per-domain from the table. Residency is about where the live copy
lives; it says nothing about who fills it. **Third time this thread that a source answered a
slightly different question than the one I asked** (the rendered listing in 116, the residency note
in 119, and before them the `D,TE` mnemonic). The pattern is consistent enough to name: when a
source seems to settle a question it was not written to answer, it is probably answering the
neighbouring one.

### And the C# comment's microcode citation does not match this image

`CpuND500.Trap.cs` describes the enable gate as:

```
  011034  AL#21 := TE          011036  AL#21 &= 0xFFFFFE00
  011035  AL#21 |= 0xC0000000  011037  AL#21 &= S1
```

The actual words at `011034-011037` in `MICRO-5800-B30.DATA` are the LOADCT dispatch chain -
`011034` is `ALU,AND A,LARG(0o3600000000) B,SC3`, a bit test. **The cited addresses are wrong for
this control store.** The gate LOGIC may still be right - it is not contradicted here, only its
citation is - but the addresses should not be quoted again until the real ones are found. Recorded
rather than corrected, because finding the true gate is its own carve.

### The fix is now fully evidenced

`LoadDomainStateFromDIT` should also load `OTE1/OTE2`, `CTE1/CTE2`, `MTE1/MTE2`, `TEMM1/TEMM2` from
the offsets above. Two things to check before writing it: whether `Registers` even has `CTE`/`TEMM`
fields (it has OTE/MTE), and what the interleaved `MARG=0x04` words at `011176`/`011201`/`011204`/
`011207` do - they read a different place and are part of each routine.

## 121. The trap-config fix changed NOTHING in place-domain - a clean negative `[V]` 2026-08-31

Re-ran `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture` with `LoadDomainStateFromDIT` now
loading OTE/CTE/MTE/TEMM. Pack override confirmed, passed, 30 m 39 s.

```
                       BEFORE (cell5)      AFTER (cell6)
  3RMICV watchdog          262                 319      <- elapsed time only
  PHYSWR                    13                  13
  CACHE                      1                   1
  MON restart      posted=2 seen=1 taken=1   IDENTICAL
  cell writes      313/176/91/11            IDENTICAL, every bucket
```

**Nothing moved.** The only differences are watchdog-driven counts, which track wall time and are
explicitly "time passed, nothing more". Sections 115/116 raised the possibility that place-domain
goes quiet because the trap configuration it installs is ignored. **It does not.**

Why: `LoadDomainStateFromDIT` is called only from cross-domain call/return
(`CpuND500.Domain.cs:692` and `:774`). Place-domain never reaches a domain call - the ND-500 is
never started - so the new code never executes. The fix is correct and currently INERT.

### And a provenance correction to section 120, made in the code as well as here

`LOADCT_1` is referenced from `0o001041`, which is the MACRO-INSTRUCTION dispatch band. So the
LOADCT_* family implements a **load-context INSTRUCTION**, not automatic domain entry. It proves the
DIT holds those fields and gives their exact offsets - that part stands, and the layout is
confirmed - but it does **not** prove a cross-domain CALL loads them, which is the event the method
I changed actually serves.

What supports that trigger is the CNTXTLOAD tail (section 116: reads DPA+0x16/+0x26/+0x3B/+0x48,
writes TE at `0o15103`/`0o15104`) plus the architecture - the registers are per-domain, so entering
a domain must establish them from somewhere and the DIT is the only per-domain store. **That is
reasoning, not a carve.** The change is kept and regraded `[D]`, with the experiment named in the
comment: seed distinct values in two domains' DIT entries, execute a cross-domain CALL on the
microword CPU, read the registers back.

The change is retained rather than reverted because the alternative - carrying the previous
domain's trap enables across a domain switch - is definitely wrong, and the ND-500 suite is green
either way (2262 passed, 0 failed).

### The pattern, now four for four on this thread

A source answers the question NEXT to the one asked, and reads as settling it:

```
  116  rendered listing        gave a value for a field it mis-renders
  119  manual residency note   said where registers LIVE, read as who FILLS them
  120  LOADCT_* routines       an INSTRUCTION's loader, read as domain entry
  ---  D,TE mnemonic           wrong form, returned a confident empty set
```

**Three of the four were caught by going one level more raw.** The fourth - this one - was caught by
asking who CALLS the routine, which is the same move: stop reading what a thing is named and look at
what reaches it. On this thread that check is worth doing BEFORE writing the comment, not after.

### Where item 1 actually stands

Unchanged and now better bounded: place-domain issues one CACHE and twelve DIT writes, then only
watchdogs. The DIT block is identified (section 115) and the write is not being ignored by anything
we control. **The open question is what SINTRAN waits for after installing it** - and since our side
never receives another message, the answer is on the ND-100 side, not in the CPU.

## 122. CORRECTION to section 114, and a five-point chain that names the real gap `[V]` 2026-08-31

### First, my own error

Section 114 said place-domain services "three distinct MICFUs" and built a conclusion on it. That
came from grepping the `servicer MICFU trace` SECTION, which does not list every message. The
authoritative count is the `micfu[]` histogram on the status line:

```
  [after PLACE-DOMAIN]  micfu[1B:162  12B:1  23B:1  24B:1  31B:13]
```

**Five, not three.** `23B` is 3START and `24B` is 3MONCO - the two that matter most, and exactly the
two I reported absent. Same failure as everything else on this thread: a partial view read as the
whole. The census section is a sample; the histogram is the census.

### What place-domain actually achieves

```
  startSeen=1  startMicfu=23B  startTaken=True     the 3START WAS posted and taken
  restarts=1/1                                     a MON round-trip completed
  ansMON=377B  ansSWPFU=1B  swpfu[LNEWSWAP:2]      the swapper ran and called MON 377B
  PC=0x08008255  stopMode=WAIT                     parked after that call (section 9)
  PSTP=0x0003A000  CTXBASE=0x0002A000              context established
  THA=0x00000000                                   <- and this is the finding
```

So the swapper **starts, runs, makes a monitor call, is answered, and parks** - section 11's
"designed idle", not a failure. Place-domain gets far further than section 114 claimed.

### `THA=0` is the gap, and five measured facts converge on it

```
  1  SINTRAN WRITES the trap config    twelve PHYSWR into DIT 0x96..0xC7, pcb_tha at 0xB6   s115
  2  the process IS started            startSeen=1 startMicfu=23B startTaken=True           this run
  3  the microcode LOADS it at start   CNTXTLOAD tail reads DPA+0x16/0x26/0x3B/0x48,
                                       writes TE at 0o15103/0o15104                         s116
  4  our start path does NOT           StartProcessFromContextBlock reads ctx 0x00-0x60 and
                                       "there is no trap-enable slot in it" - our own source
  5  the CPU shows THA=0               after a completed 3START                             this run
```

**SINTRAN installs a trap configuration and our CPU starts the process without it.** With `THA=0`
the delivery gate can never fire - it requires `regs.THA != 0` - so no trap this process raises can
ever reach a handler.

### Which makes section 121's negative make sense, and points at the fix

Section 121 fixed `LoadDomainStateFromDIT` and measured no change. Now it is clear why: that method
is called on cross-domain CALL/RETURN, and the event that matters here is **PROCESS START**. The
microcode's own equivalent is CNTXTLOAD, which section 116 already showed reading DIT fields.

**So the load is hooked to the wrong event.** The next change is to load the DIT trap configuration
in the process-start path as well - and this time the hypothesis is falsifiable in one line:
**`THA` should be non-zero after a completed 3START.** That is a value this run already prints, so
the before/after is a single grep rather than a 30-minute interpretation.

Note it is still worth checking WHICH fields the start path should take: CNTXTLOAD reads four bytes
(`+0x16 +0x26 +0x3B +0x48`), not the full twelve the LOADCT_* instruction reads. Do not assume the
two paths load the same set.

## 123. ROOT CAUSE: `DITBASE == 0` is the "not configured" sentinel, and 0 is the CORRECT base `[V]` 2026-08-31

The section-122 prediction was **falsified**. After hooking the DIT trap-config load into the
process-start path, place-domain still reports `THA=0x00000000`. Passed, 30 m 39 s, pack confirmed.

That is a good failure - the prediction was one value, and it said no.

### Why neither fix fired

The load is guarded `if (regs.THA == 0 && regs.DITBASE != 0)`, and every DIT reader opens with

```csharp
    if (regs.DITBASE == 0)
        return 0;
```

**22 of those guards in `CpuND500.Domain.cs`.** So the whole DIT subsystem is a no-op unless
`DITBASE` is non-zero. Two facts finish it:

 1. **Nothing on the octobus lane ever sets `DITBASE`.** Grepping `Emulated.HW/ND/CPU/NDBUS` and
    `Emulated.Machines/ND` finds it only as a register accessor on the CLASSIC 3022 path
    (`NDBusND500IF.cs:1775/1851`). The octobus attach never assigns it. The status line prints
    `PSTP` and `CTXBASE` and not `DITBASE`, which is its own small tell.

 2. **The correct value for this system IS ZERO.** SINTRAN writes the DIT at ND-500 physical
    `0x96..0xC7` (section 115) - that is PCB base `0x00`, domain 0. The harness agrees:
    `SwapperStartDiagnosticTests` uses `PcbTableBase = 0x00` with the note "harness: physical 0;
    NDIX: pcbtab @ KVA 0xe0000000".

**So the sentinel collides with the only valid value this system uses.** A correctly configured DIT
at physical 0 is indistinguishable from no DIT at all, and every read is refused.

### Why this is the root, not another layer

It explains the whole thread at once, with no extra assumptions:

```
  THA = 0 after a completed 3START            DIT read refused
  OTE/MTE/CTE/TEMM never loaded               DIT reads refused
  section 121's fix measured no change        DIT reads refused
  section 122's fix measured no change        guarded on DITBASE != 0, refused
  no trap can ever be delivered               gate needs THA != 0
```

Five symptoms, one cause. And it is the reason both fixes were *correct and inert* - they were
downstream of a subsystem that was switched off.

### The fix, and why it is NOT a one-liner

Do **not** just set `DITBASE = 0x00` somewhere - that changes nothing, because 0 is what the guards
reject. The sentinel itself has to go: add an explicit `DitConfigured` flag (or make the base
nullable) and change all 22 guards to test THAT, then have the octobus attach declare the base the
same way the harness does.

Touching 22 guards on the trap path deserves its own red-first test: assert that a DIT written at
physical 0 is readable, which is false today and would have caught this the moment the sentinel was
introduced.

### The method note, and it is the cheapest lesson here

A prediction stated as ONE VALUE - "THA must be non-zero after a completed 3START" - failed in a way
that pointed straight at the cause. Had I predicted "place-domain will get further", the same run
would have been unreadable: nothing got further, and I would have had no idea which of five layers
was responsible. **Predict a value, not an outcome.**

### 123a. A second silent-discard mechanism, on the path I am using `[V]` 2026-08-31

`nd500uc-d4` flagged `SintranLayer.TraceMonitorCall` (:604): it drops everything that is not
`DataCommunication` before logging. MON 60B already needed its OWN separate recorder purely because
this filter hid it - the comment at :500 says so.

**That lands on this lane.** The swapper's call is **MON 377B**, and `ansMON=377B` is one of the few
signals that the swapper actually ran and was answered. It is not DataCommunication. So reaching for
`TraceMonitorCall` to see it would have produced an EMPTY trace, and "no MON call happened" is the
natural - and wrong - reading.

Same shape as section 123's own root cause, which makes two in one session:

```
  DITBASE == 0 sentinel        a configured DIT at physical 0 reads as "no DIT"
  TraceMonitorCall filter      a real MON 377B reads as "no MON call"
```

Both silently discard the real case and return a confident nothing. Neither errors, neither logs a
skip. **When an instrument returns emptiness, ask what it FILTERS before believing the emptiness** -
the absence may be manufactured upstream of anything the machine did.

### 123b. The obvious fix would have ERASED the data it was meant to read `[V]` 2026-08-31

Section 123 ended with "have the octobus attach declare the base". The natural way to do that is
`SetupDIT(0)`. **Do not.** Its second half:

```csharp
    public void SetupDIT(uint ditBaseAddress)
    {
        regs.DITBASE = ditBaseAddress;
        for (int domain = 0; domain < MAX_DOMAINS; domain++)
            for (int off = 0; off < DIT_ENTRY_SIZE; off += 4)
                WriteMemory32(entryAddr + (uint)off, 0);      // zeroes every 256-byte PCB
    }
```

On the octobus lane **SINTRAN owns that table** - it writes the twelve trap-config words during
place-domain (section 115). Calling `SetupDIT` after that wipes exactly the configuration this whole
thread is trying to deliver, and the symptom would be identical to today's: `THA=0`. The fix would
have looked like it changed nothing, for a completely different reason.

`SetupDIT` is right for a lane where WE own the table and wrong for one where the guest does.

### The corrected fix, in three parts

```
  1  replace the sentinel      21 functional guards test a DitConfigured flag (or a nullable
                               base) instead of `regs.DITBASE == 0`. The 22nd, at :1008 in
                               InitializeDomainSystem, is only choosing a log message - leave it.
  2  declare the base WITHOUT clearing   a separate entry point, or a SetupDIT overload that skips
                               the zeroing. Never zero a table the guest wrote.
  3  octobus attach calls it   with base 0, matching what SINTRAN actually uses and what
                               SwapperStartDiagnosticTests already assumes (PcbTableBase = 0x00).
```

**Red-first test:** write a recognisable value into a DIT field at physical 0, declare the base, and
read it back. False today for two independent reasons - the sentinel refuses the read, and the only
available declaration path would have erased the value first. A test that pins BOTH is worth more
than one that pins either.

### Why this was found before it was written, and not after

Only because the guard enumeration listed `InitializeDomainSystem` among the 22 and I read the
setter next to it rather than assuming what it did. **The count was the reason to look**: 22 guards
is a mechanical conversion, and mechanical conversions are exactly where you stop reading and start
substituting.

## 124. The `DITBASE` sentinel is REMOVED - red-first, 2264 green `[V]` 2026-08-31

Section 123 found it, 123b found the trap in the obvious fix. Both are now closed in code.

### Red first, and the second test earned its place immediately

`TestND500_DitBaseZeroIsAValidBase`, driving the REAL path (`StartProcessFromContextBlock`, the
public entry the octobus lane uses and the one whose measured `THA=0` started this):

```
  BEFORE  DitAtPhysicalZero_IsReadable...          Expected 134223400  But was 0
  BEFORE  DeclaringTheBase_DoesNotErase...         Expected 134223400  But was 0
  AFTER   both PASS
  FULL SUITE  2264 passed, 0 failed  (was 2262 - the two new tests, no regressions)
```

**The second test failing is the important one.** It proves `SetupDIT(0)` really does erase a
guest-written table - section 123b called that hazard from reading the code, and this made it a
measurement rather than a worry. Had I not written it, the "fix" would have zeroed SINTRAN's trap
config and produced an unchanged `THA=0`, reading as "the fix did nothing" for the THIRD time.

### What changed

```
  Registers.DitConfigured          new flag; expresses "base 0, configured", which no value of
                                   DITBASE could. Reset with DITBASE, copied with it.
  22 guards                        `regs.DITBASE == 0` -> `!regs.DitConfigured`
  DeclareDitBase(uint)             NEW - declares the base and touches nothing else.
                                   For lanes where the GUEST owns the table.
  SetupDIT(uint)                   unchanged behaviour, still clears. For lanes where WE own it.
                                   Two entry points rather than one with a boolean argument that
                                   nobody reads at the call site.
  MMUConfiguration.ApplyToCpu      now sets DitConfigured - an explicit configuration must count
                                   as configured whatever address it names. That was the same bug
                                   in miniature: configuring a DIT at 0 configured nothing.
```

### Still outstanding on this chain, stated so it is not assumed done

**Nothing on the octobus lane calls `DeclareDitBase` yet.** The sentinel is gone and the mechanism
works, but the lane must still declare base 0. I have NOT added a blanket default, because base 0 is
SINTRAN's layout and not universal - NDIX puts `pcbtab` at KVA `0xe0000000`. Defaulting would bake
one OS's memory map into a shared path, which is the same class of error as the sentinel.

So the honest status: **the blocker is removed, the wiring is not done, and place-domain will not
change until it is.** Do not re-measure expecting movement.

### 124a. A fifth in the family, and one that only a BASE RATE could catch `[V]` 2026-08-31

Four mechanisms found in one day that return a confident answer about the wrong thing:

```
  DITBASE == 0 sentinel     a configured DIT at physical 0 reads as "no DIT"        s123
  TraceMonitorCall filter   a real MON 377B reads as "no MON call"                  s123a
  corpus register model     no OTE/MTE/THA slot, so no row can assert a delivered
                            ignorable trap - the rows are not wrong, they are
                            UNEXPRESSIBLE                                           s112a
  -p:BaseOutputPath         a clean build, 0 errors, and nothing written anywhere -
                            a build that SUCCEEDS AT DOING NOTHING, after which you
                            test a stale binary                                     peer, this date
```

None errors. None logs a skip.

### The fifth is a different shape, and the sharpest of them

`nd500uc-d4`, chasing a linkage-loader failure, found `SCRATCH-SEG-01:LINK` reporting a byte count
of exactly **2^32 with zero pages**. That is a beautiful corrupt-size explanation: a wrapped length,
an empty file, an obvious root cause.

**Every `:LINK` file on both floppies is identical, including the loader's own, which works.** The
striking value was the NORM. Only counting the other files could say so.

That is not "an instrument lying" - the read was correct and the value was real. It is a **base-rate
failure**: a value looks diagnostic because it is unusual, and nobody checked whether it is unusual.
The defence is one query - how many other things look like this? - and it is cheap enough that not
running it is the mistake.

Related to failure-taxonomy #14 ("an authoritative NEVER makes an ORDINARY observation look like a
finding") but distinct: #14 is a framing arriving after the data, this is a missing denominator. The
real root cause turned out to be a MISSING FILE - the loader asks for
`SEGMENT-D002-S01`, the floppy carries `SCRATCH-SEG-01` - which the corrupt-size story would have
hidden behind a plausible answer.

## 125. CORRECTION to section 115: those are SEGMENT OFFSETS, not physical addresses `[V]` 2026-08-31

Declaring the DIT base at physical 0 did not work either - `THA=0x00000000` again, second
falsification, 30 m 51 s, pack confirmed. The declaration DID run (the harness calls
`AttachNd5000Cpu` at line 368), so this is not another inert fix. The base is simply wrong.

### What I misread

`PHYSRD`/`PHYSWR` (30B/31B) are **SEGMENT-RELATIVE**. The servicer says so in its own comment -
*"PHYSRD is SEGMENT-RELATIVE and walks the physical segment table"* - and
`TryResolvePhysicalSegmentAddress` does the walk the microcode does:

```
    entry = PST[segment]            halfword entries, index*2, microcode 011460 -> 007771
    physicalByteAddress = (entry AND 0x3FFF) * 2048 + offsetInSegment
```

The message carries the SEGMENT in `MSWMC` and the OFFSET in `N500A`/`N500A_LO`. And the harness
line I built section 115 on prints the raw operand, with a comment that says exactly what it is:

```
    // Operands are ND-500-side byte offsets; absolute = Nd500AddressBase + off
    extra = $"  addrA=0x{aAddr:X8} addrB=0x{bAddr:X8} nrbyt={n}";
```

**So `addrA = 0x96..0xC4` are OFFSETS INSIDE A PHYSICAL SEGMENT.** I read them as ND-500 physical
addresses and concluded the DIT is at physical 0.

### What SURVIVES, and it is most of it

The layout identification is untouched:

 - the twelve offsets land exactly on `struct pcb` field starts, and the never-written `0xBA/0xBB`
   are the only two single-BYTE fields in the span - a hole the layout PREDICTS;
 - the raw decode of the eight `LOADCT_*` routines gives **DPA-relative** offsets, and
   `DPA = PcbBase + domain*256 + 0x80` - that constrains the LAYOUT and says nothing about where
   `PcbBase` is, so it is unaffected by this correction;
 - our own `DIT_*_OFFSET` constants and `pcb.h` are likewise layout-only.

**Section 115 conflated LAYOUT with BASE.** The layout is confirmed four ways and stands. The base
was inferred from one reading of one log field, and that reading was wrong.

Since the PCB fields sit at segment offsets `0x96..0xC7`, the PCB starts at the SEGMENT BASE, so:

```
    DIT base = PST[segment] page * 2048        NOT 0
```

### Failure-taxonomy #19 again, and this time it survived four cross-checks

Correct about the wrong object: the twelve VALUES were right, the field identification was right,
and only what kind of address they are was wrong. Every check I ran verified the values against a
layout - none asked what address space the numbers were in. **The one question that would have
caught it is the one I did not ask: "an offset from what?"**

### Next, and it needs one run

The segment number is in the message (`MSWMC`) and the servicer already prints it -
`PHYSWR seg=... off=... -> ND500 phys 0x...` - but that NoteMessage does not reach the capture the
harness writes. Surface it, read the segment, resolve `PST[seg]`, and declare THAT base. The
prediction stays a single value: `THA` non-zero after a completed 3START.

**Do not declare base 0 again**; `ND100Machine.ND5000.cs` currently does, and it is wrong.

## 126. THE PACK IS INSTALLED WRONG - and that outranks most of sections 115-125 `[V]` 2026-08-31

`nd500uc-d4` carved it to bytes on the pack we boot. `(PACK-ONE:SYSTEM)DESCRIPTION-FILE:DESC` is
22528 bytes - the same size as the LED distribution FLOPPY's - and every stored name still carries
the floppy directory:

```
  @0x00800  (211160B03-XX-01D:FLOPPY-USER)'L
  @0x04004  (211160B03-XX-01D:FLOPPY-USER)SCRATCH-SEG-01'
  @0x040C4  (211160B03-XX-01D:FLOPPY-USER)LED-B03'
```

I confirmed the same content independently on the loose copy in this repo before their message
arrived - same five names, same prefix - though THEIRS is the check that counts, because it is the
DESC inside the pack that is actually booted rather than a file with the same name lying next to it.

ND-30.003.007:4607 states the rule: *"The description file still contains the definitions valid for
the user the domain is copied from. This must be corrected."* `COPY-DOMAIN` rewrites those names;
`@COPY-FILE` cannot. The pack was built with the latter.

### Why this matters more than the trap configuration

ND-60.136.04A ch.11: the segment entry stores `(directory:user)filename` and **the prefix is not
consulted until the `:PSEG`/`:DSEG` are opened.** So a file-copied domain RESOLVES and then fails
LATER, at file-open time.

That is the exact shape of what I have been measuring for a day:

```
  place-domain gets far      swapper starts, MON 377B asked and answered, parks - all correct
  then SINTRAN goes quiet    nothing but watchdogs; "> Allocating memory" never appears
```

If the domain's segment files cannot be opened, there is nothing to page in and nothing further to
ask the CPU of. **The stall is very likely the install, not the CPU.**

### What this does to sections 115-125

**Still stands, because none of it depends on the pack:**

 - the PCB/DIT layout - `pcb.h`, our own constants, and the raw `LOADCT_*` decode;
 - `DITBASE == 0` as a sentinel colliding with a legal base - a real defect, and its red-first test
   is a unit test with no pack in it;
 - the microcode loads OTE/CTE/MTE/TEMM on context load, which we did not;
 - everything in the ACCP, SSKIP, divide-by-zero and corpus work, all pack-independent.

**Does NOT stand:**

 - **"`THA=0` is the gap that stops place-domain."** It may simply be that a domain whose files
   cannot be opened never gets a properly populated context. I asserted a causal role for a symptom
   I had only ever seen on a broken pack.
 - section 125's next step - hunting the real DIT base through `PST[seg]` - is PREMATURE. Measuring
   it on a pack that cannot open its own segments would tell me about the failure, not the machine.

**So: re-measure on a correctly installed pack BEFORE drawing anything further from place-domain.**

### The near-miss that belongs at the top of the taxonomy

They found ND-60.136.04A:2987 - *"If a NO SUCH PAGE condition occurs at execution time, the Monitor
will zero fill the page in memory"* - and nearly implemented it in the MMU. Real text, naming our
exact error. It is section 6.9.2 LOW-ADDRESS and concerns a HOLE INSIDE AN EXISTING segment file;
an explicit search found nothing tying NO SUCH PAGE to a MISSING file.

**Implementing it would have made the symptom vanish, made the lane green, and permanently hidden a
broken install behind genuine-looking manual backing.** A citation that fits the error text and not
the situation is worse than no citation, because it survives review.

The same trap is live on my side: I have been changing CPU trap-config code to chase a symptom that
a bad install may fully explain. My changes are defensible on their own evidence and I am keeping
them - but not one of them should be described as fixing place-domain.

## 127. Item 4's ALTEN pair: one phantom, one bounded to the BLOCK-MOVE family `[V]` 2026-08-31

The plan's standing rule is to restrict a field's B30 count to REACHABLE sites before implementing,
because raw sweeps have twice invented work that did not exist. Done for the ALTEN pair
(`MicrowordDecodeTests.AltenArms_HowManyB30WordsCouldReachThem`), and it splits them cleanly:

```
  words with OR_ENABLE set                                1079
  ORCON.A == 3  raw 532   guarded (OrEnable AND AOp==63)     0   PHANTOM
  ORCON.D == 3  raw 395   guarded (OrEnable)                48   REAL
```

Guards taken from the call sites, not guessed: `orconA = (Orcon >> 2) AND 3` is reached only when
`OrEnable != 0 AND AOp == 63` (`CpuND5000.cs:2465`); `orconD = Orcon AND 3` (`:3158`).

**The raw numbers suggest ~900 words of work. The truth is 0 and 48.** `ORCON.A` ALTEN is confirmed
a phantom for the second time - the plan already recorded "532 raw -> 0 reachable" and this
reproduces it independently.

### The 48 are one family, not scattered work

Every one carries `ORCON=0x03` exactly, and they occupy a single contiguous band,
`0o5717..0o10054`. The labels in that band name it:

```
  MBR_*       move block REVERSE      MBR_ALOOP, MBR_W, MBRWLOOP, MBR_B, MBR_BLOOP ...
  MBF_*       move block FORWARD      MBF_ALOOP, MBF_W, MBFWLOOP, MBF_B, MBF_BLOOP ...
  BMOVEBY_*   block move BYTE         BMOVEBY_FR/_F/_FAL/_FW/_FWL/_FB/_FBL ...
  BMOVEHW_*   block move HALFWORD
```

**The BLOCK-MOVE / string-move family** - which is exactly what ALTEN is for: ND-05.022.1 defines
`ORD,ALTEN` (561) as *"OR destination from string DEST. operand"*, with `G,OPSTRD` (539) fetching
the second string-operand specifier.

Two shapes among the 48: `Dest=18/19, AOp=56 (A,DATA), MemOp=15, Adact=1` - the memory-moving
words - and `Dest=8/24/26, MemOp=0` - the register/address bookkeeping around them.

### Why this matters beyond item 4

The nd5000-microcode skill records that the microword lane **fails every one of the 168
`STRING_sfill` golden vectors**, and lists `G,OPSTRD` and "ALT-prefix/ORCON ALTEN itself" among the
throwing features. This puts a number and a location on that: the string/block-move destination path
is 48 microwords in one band, and `ORCON.D` ALTEN is the arm they all need.

So item 4's next entry is not "implement ALTEN" in the abstract - it is **model the string
destination operand for the block-move family**, with a bounded site list and an existing failing
corpus to measure against.

### The caveat that keeps 48 honest

**48 is an UPPER BOUND.** The sweep models `OrEnable` because that is the gate visible at the call
site; the destination path may carry further guards this does not express. The number is small
enough to read, which is the point - a bounded list can be checked, a raw count can only be
believed.

## 128. `G,OPSTRD` is not missing - it is FLATTENED, and its own [OPEN] predicted this exact failure `[V]` 2026-08-31

I went to implement `ORCON.D` ALTEN and found the dependency runs the other way.

**The four OR-destination arms are symmetric**, which is what makes the missing one legible:

```
  ORD,IN    (0)  destination = register named in the instruction code   Regs.InstrRin
  ORD,OP    (1)  destination = the CURRENT operand                      OcaKind/OcaReg/OcaEa
  ORD,OP1   (2)  destination = the FIRST operand                        Op1Kind/Op1Reg/Op1Ea
  ORD,ALTEN (3)  destination = the STRING DEST operand                  <- needs an ALT triple
```

So ALTEN needs an alternate-operand triple that something has to populate. That something is
`G,OPSTRD` - ND-05.022.1 (539), *"get second operand specifier for string instr"*.

### It is implemented, and the skill note saying it throws is stale

`CpuND5000.cs:1188`, case 13, is real code: `G,OPSTRD` is flattened onto `G,OPS` - "bring in the
next operand specifier" - graded `[D]` with its evidence (every SMOVE-family member is the same
two-word pair over `0o1235..0o1252`, and word 2's only effect is the operand advance). It does not
throw.

**And it carries an [OPEN] that reads as a prediction:**

> *"the real hardware distinction is presumably string DESCRIPTOR handling (a string operand is a
> descriptor, not a scalar). Nothing on the swapper path exercises that yet. **If a string
> instruction ever reads the wrong operand, revisit here first.**"*

### The prediction came true, and it is already measured

The SFILL remark in `MicrowordDecodeTests`:

> *"the microword lane fails every one of the 168 `STRING_sfill` golden vectors, and on the live
> swapper it executed a fill of the right LENGTH at the wrong ADDRESS - it used the descriptor's
> element count as the base. **So the descriptor is not reaching the fill loop.**"*

Right length, wrong address, element count used as base - that is exactly what a flattened
`G,OPSTRD` produces: the operand stream advances, the DESCRIPTOR is lost, and the fill takes a
scalar where a (count, address) pair belonged.

### So item 4's entry is ordered, and ALTEN is not first

```
  1  G,OPSTRD must deliver the string DESCRIPTOR, not just advance the operand stream
  2  an ALT operand triple then exists for ORCON.D ALTEN's 48 block-move sites to route to
  3  the 168 STRING_sfill vectors are the measure, and they are already failing
```

Implementing ALTEN first would have had nothing to read: the destination it routes to is produced
by the step above it.

### Third time today that our own comment named the failure before we measured it

`Divide.cs` cited the microcode against the corpus rows; `Nd5000ControlStoreLink` recorded the
address-latch correction; and here an `[OPEN]` said which line to revisit and under exactly what
symptom. **The notes are load-bearing and they are being read too late.** The cheap habit is to grep
the `[OPEN]` markers for the subsystem BEFORE forming a plan for it, not after the measurement
arrives.

## 129. CORRECTION to 127/128: `STRING_sfill` is 168/168. The premise was a STALE STATUS NOTE `[V]` 2026-08-31

Sections 127 and 128 both close on "the 168 `STRING_sfill` golden vectors are the measure, already
failing". **They are not failing.** Measured directly:

```
  ND5000_DIFF_FILE=STRING_sfill  Sweep_DumpOneFileDiffs
    === STRING_sfill.json: diverging cases (microword vs functional golden) ===
    --- match=168  diverge=0  unsupported=0 ---

  whole sweep: match=23933 diverge=1424   (baseline floor 22248 / ceiling 1638) - ABOVE baseline
```

The claim came from the `nd5000-microcode` skill's "still open" list. `JsonVectorSweepTests`'
own history records the fix in a comment - *"four gained - **STRING_sfill 0->168**"* - and the skill
was never updated.

**The octobus skill warns about exactly this, as its FIRST trap:** *"STATUS HEADERS IN THIS TREE
LIE. Check the code, not the heading... Before investigating any 'open' item, grep the code and the
tests for it. More than half the time it is done."* I did not, and built two sections on it.

### What survives 127/128

Everything that was MEASURED rather than inherited:

 - the ALTEN reachability split - `ORCON.A` 532 raw / **0** reachable, `ORCON.D` 395 raw / **48**;
 - those 48 being one contiguous band, `0o5717..0o10054`, the `MBR_*`/`MBF_*`/`BMOVEBY_*`/
   `BMOVEHW_*` block-move family;
 - the four OR-destination arms being symmetric, so ALTEN needs an ALT operand triple;
 - `G,OPSTRD` being FLATTENED onto `G,OPS` rather than missing, graded `[D]`, with its own `[OPEN]`.

### What is FALSE, and what it changes

"The string family is broken and ALTEN is the blocker" is false. SFILL passes completely. So **item
4's ALTEN entry has no failing measure behind it**, and its priority drops accordingly - it is real
unimplemented hardware, not a live defect.

### The question that replaces it, and it is a sharper one

If `ORCON.D` ALTEN throws, and 48 words in the image reach it, **why does nothing fail?**

Two candidates, and they are distinguishable: either no corpus vector ever executes those 48 words,
or the block-move family has no golden coverage at all. That is the same raw-vs-reachable distinction
one level further out - **reachable IN THE IMAGE is not the same as executed BY ANY TEST** - and it
decides whether ALTEN is untested-but-needed or genuinely dormant.

### Method note - the rule I wrote one section earlier

Section 128 ended: *"grep the `[OPEN]` markers for the subsystem BEFORE forming a plan for it."* I
did that this tick and it worked - two markers, both saying descriptor branches are unmodelled. But
I applied it only to the CODE and not to the CLAIM, and the false part came from a skill file. **The
same check has to cover the status notes, which are the thing most likely to be stale**, because
code gets fixed and prose does not.

## 130. The install findings, and the two my own memory already held `[V]` 2026-08-31

`nd500uc-d4`'s full write-up is `E:\Dev\Ronny\ND500UC\docs\ND500-DOMAIN-INSTALL-2026-08-31.md`
(commit cb34551). The parts that bear on this lane:

**Domains belong on DOMAIN-USER, not SYSTEM.** Five product sheets plus the vendor cold-start file
agree. Our pack has everything on SYSTEM, whose quota is exhausted TO THE PAGE - reserved 21713,
used 21713 - while DOMAIN-USER sits at 1000 reserved and 0 used. There are 16419 free pages on the
volume. **So `NO SPACE IN DEFAULT DIRECTORIES` is the QUOTA, not the disk.**

**Having the file is not having the registration.** `LIST-DOMAIN` returns two domains,
`SCRATCH-DOMAIN` and `LED-B03`, while the same pack carries a dozen `:DOM` files including
`CPU-STAT` and `PLANC-500-G00`. The file list and the domain list are different objects.

**The reusable tell:** a file-copied domain fails LATE. The stored name carries its directory and
the prefix is not read until the `:PSEG`/`:DSEG` are OPENED, so everything that merely RESOLVES a
name works and only opening breaks. **If something works right up to its last step, suspect the
description file before the machine.**

### Two of these were already in my own memory, from 2026-08-26

`nd500-domain-registration-not-file-copy` records, measured five days ago:

 - registration is a separate step from copying files - `place-domain LINKAGE-LOAD-H02` answers
   `NO SUCH DOMAIN` though the pack carries every one of its files;
 - **`NO SPACE IN DEFAULT DIRECTORIES` is SINTRAN saying "not in your defaults", NOT "disk full"**;
 - the DOMS pack's DESC holds exactly `LED-B03, SCRATCH-DOMAIN, SCRATCH-SEG-01` and **no NLL** -
   the same three names I re-read out of the file today;
 - and that both tables are the same 22528-byte fixed size, so **equal size proves nothing about
   equal content** - which is the same caution the peer's byte-proof rests on.

The peer's quota numbers SHARPEN the second one from "not in your defaults" to a specific
exhausted-to-the-page reservation, which is better than what I had. But I had the shape and did not
bring it to this lane.

### One datapoint that may save them a cycle

They list `SYSTEM/LINKAGE-LOAD-H02` having `:PSEG`/`:DSEG`/`:UTIL` but **no `:LINK`** as a finding,
citing ND-60.136.04A:1105 that a segment is a PSEG/DSEG/LINK trio. My memory note records that
exact hypothesis being TESTED and REFUTED on 2026-08-26:

> *"the absent `:LINK` file is the blocker - the installer spec does list four files
> (`:PSEG :DSEG :LINK :DESC`) and the pack had three. Added `:LINK` to a copy; **still**
> `NO SUCH DOMAIN`."*

So the missing `:LINK` is real but **not sufficient** - adding it does not make the domain placeable.
Registration is still the gate. Sent to them.

### The pattern, again

That memory note's own closing lesson is *"explaining a disagreement instead of decoding the thing
that settles it"*. Today's version is narrower and worse: I had already decoded the thing that
settles it, wrote it down, and then spent a day on the CPU without re-reading it. **Fourth time this
session that a note we already own named the answer before we measured it.**

## 131. Item 7 triaged: 56% of the microword divergence is ONE family, and it is already characterised `[V]` 2026-08-31

Ran the golden-vector landscape (`Sweep_AllGoldenVectors_Report`, 125 files) to give item 7 the same
treatment that worked on the ND-500 corpus.

```
  files=125   match=21729   diverge=1408   unsupported=1140

  PACKED DECIMAL - 8 files, diverge=792 = 56% of ALL divergence
     ARITHMETIC_pmpy    match=160  diverge=200      ARITHMETIC_ppack   match=0    diverge=36
     ARITHMETIC_pmpyr   match=160  diverge=200      ARITHMETIC_ppackr  match=0    diverge=36
     ARITHMETIC_padd    match=200  diverge=160      ARITHMETIC_psub    match=360  diverge=0
     ARITHMETIC_paddr   match=200  diverge=160      ARITHMETIC_psubr   match=360  diverge=0

  TOP NON-PACKED
     ARITHMETIC_rem     match=0    diverge=200  unsupported=280   <- entirely broken
     ARITHMETIC__div_   match=607  diverge=60
     ARITHMETIC__mul_   match=583  diverge=41
     FLOAT_MATH acos/alog2/alog10/alog          40 / 36 / 32 / 24
```

`psub` and `psubr` at 360 match / 0 diverge are the discriminator: the packed-decimal ENGINE is not
broken, or subtract would fail too.

### And the repo already had the answer - read BEFORE theorising this time

`ND5000-PACKED-DECIMAL-Z-FLAG-BOTH-CORES-WRONG-2026-07-28.md` records, with an experiment:

 - the 216-diverge `padd` table was **DEGENERATE** - unseeded operands, every case `0+0=0` - and the
   generator was fixed (commit `77620f6f3`);
 - **the microword's packed VALUE result is 100% correct** - zero value diffs across all six
   360-case files - and `psub`/`psubr` went to `diverge=0`, exactly what this sweep still shows;
 - **the remaining diverges are Z/S-FLAG-ONLY**;
 - the `ST,LOAD`/`AluSts` root-cause hypothesis was **experimentally refuted**;
 - and its 2026-08-08 update records the same shape for the float `-0` store, with the verdict
   *"corpus wrong on these 8 rows - microword + manual beat the two-functional-core consensus"*,
   citing ND-05.020.01 §9.5 (MZRO compares all 32/16/8 bits; there is no float-magnitude carve-out).

**So item 7's largest block is values-correct, flags-only, and the documented verdict on the
analogous case is that the CORPUS is wrong.** That is the same conclusion reached independently for
the ND-500 conformance corpus, where 196 of 242 remaining failures are fixture defects. Two corpora,
two independent triages, the same answer: most of what is left is the measure, not the machine.

### What is actually open here

 - **packed decimal**: needs a REAL-HARDWARE datapoint to close the flag question; the doc says so
   and lists the synthetic `-0` store as worth including in a request. Not closable by more analysis.
 - **`ARITHMETIC_rem`**: `match=0, diverge=200, unsupported=280` - the one genuinely unimplemented
   thing in the top list, and MODULO is already noted elsewhere as reachable only via two-byte
   opcodes. This is the best-value item-7 target that does not need a datapoint.
 - transcendentals: ~132 combined, and `cos`/`exp` already have a carved handoff.

### Method note, and this one is positive

Four times today a note we already owned named an answer we then re-derived. This tick I checked the
repo for a packed-decimal document BEFORE forming a theory about the 792, and it had the corpus
degeneracy, the refuted hypothesis and the verdict. **The habit works; the cost is one grep.**

## 132. `NOT KNOWN TRAP` is NOT my DIT finding - our tree refutes the flattering match `[V]` 2026-08-31

`nd500uc-d4` drove `place-domain` with a directory-prefixed name and got one line past my stall:

```
  N500: place-domain (210319H02-XX-01D:FLOPPY-USER)LINKAGE-LOAD-H02
  > Loading Control Store
  > Loading Swapper
  FATAL * 21B:77B * ... ND-500(0) Monitor Internal / Fatal intern
  ND-500(0) error: The Swapper stopped
   NOT KNOWN TRAP        at program address:  0    0B
```

They noted it *"is the shape your DIT work would predict - no trap handler configured, so the trap
number resolves to nothing and the restart address is zero"*, and explicitly did not claim it.

**Our own tree refutes that reading, and I would rather record the refutation than accept the
match.**

```
  Nd500UCSintranBootTests.cs:2516   "NOT KNOWN TRAP is ND-500-MON's fall-through when the trap
                                     number it is handed has no entry in its OWN message table"
                                     - the MONITOR failing to NAME a number, not the CPU failing
                                     to DISPATCH one.

  Nd500MicrocodeServicer.cs:3306    "place-domain prints NOT KNOWN TRAP at program address 5 400B
                                     while our CPU posts NO trap at all (TRAPS posted=0), so the
                                     trap number ND-500-MON renders must come out of the ANSWER
                                     MESSAGE."

  Nd500MicrocodeServicer.cs:1602    answering 5ERANSWER to a PHYSWR "made SINTRAN print NOT KNOWN
                                     TRAP and never send a 3START for the domain".
```

**`TRAPS posted=0` is what kills it.** A trap that was never posted cannot have failed to find a
handler. My DIT/THA work predicts a trap that IS RAISED and cannot be DELIVERED; this is a trap
number appearing in a message with no trap behind it. Different failure.

And there is a mechanism that fits better without touching the CPU: `TryResolvePhysicalSegmentAddress`
declines with `PHYSWR seg=... DECLINED - no PST entry`, `understood=false`, which becomes
5ERANSWER - route 3 above. A domain loaded from a FLOPPY directory is a plausible reason for a
segment to have no PST entry, which would tie this back to the install rather than to a CPU defect.

### Why this one was worth stopping for

It is the most attractive kind of wrong answer: a peer independently offering evidence that MY
open finding explains THEIR new symptom. Two days of DIT work, and a symptom shaped like a missing
trap handler. Accepting it would have felt like convergence.

**The check that refuted it took one grep of our own source** - the same habit that has now paid
twice in three ticks, against four earlier failures to use it. `TRAPS posted=0` was written down by
whoever hit this on the 3022 lane, precisely so the next person would not read the string as a
dispatch failure.

Discriminators sent for their re-run: whether the servicer log shows the DECLINED line, what the
gate prints for TRAPS posted, and the answer-message fields (a reference PHYSWR answer is
`N5STA=0003 MICFU=0019 STOPR=0021 NUMPA=2800 MCNO=0002 TRAPN=0000`, so a non-zero `TRAPN` there names
the field feeding the render). Also noted: their address is `0 0B` and the recorded precedent is
`5 400B`, so they may not be the same event.

## 133. My half of the split: the monitor's trap table starts at bit 5, so "0" is not a trap number `[V]` 2026-08-31

Ronny split the `NOT KNOWN TRAP` investigation: `nd500uc-d4` takes the ANSWER MESSAGE (what we
write), this lane takes the MICROCODE and the MONITOR'S TABLE (what the monitor reads). Neither
writes engine code until we agree a root cause.

### First, a correction to the framing

The peer asked whether their `0 0B` and "my" `5 400B` are the same event. **The `5 400B` is not
mine.** This lane has never printed `NOT KNOWN TRAP` - zero occurrences across all four
place-domain captures (cell5-cell8); the octobus stall is SILENT, and the only "FATAL" in the log
is the word inside an instrument's own explanatory text. `5 400B` is a COMMENT in
`Nd500UCSintranBootTests.cs` - the peer's own lane's test file - recording a historical 3022
observation. I quoted it without saying it was a note rather than a run, which is what created the
false symmetry.

### The trap-name table, carved

`nd-500-mon-j04.prog`, `BANK2::22c4` onward, backslash-separated:

```
  ZERO  CARRY  SIGN  FLAG  OVERFLOW
  INVALID-OPERATION  DIVIDE-BY-ZERO  FLOATING-UNDERFLOW  FLOATING-OVERFLOW  BCD-OVERFLOW
  ILLEGAL-OPERAND-VALUE  SINGLE-INSTRUCTION-TRAP  BRANCH-TRAP  CALL-TRAP
  BREAK-POINT-INSTRUCTION-TRAP  ADDRESS-TRAP-FETCH  ADDRESS-TRAP-READ  ADDRESS-TRAP-WRITE
  ...  STACK-UNDERFLOW  PROGRAMMED-TRAP  DISABLE-PROCESS-SWITCH-TIMEOUT
  PROTECT-VIOLATION  TRAP-HANDLER-MISSING
```

That order matches our own `TrapCondition` numbering from bit 5 up: Z=5, C=6, S=7, K=8, O=9, then
IVO=11, DZ=12, FU=13, FO=14, BO=15, IOV=16, SIT=17, BT=18, CT=19, BPT=20, ATF=21, ATR=22, ATW=23.

**The table STARTS at ZERO, which is bit 5. Nothing exists below it.** So a rendered trap number of
`0` is not a real trap with a missing entry - it is below the first entry, and the only way to get
there is to hand the monitor a field that was never set. That is the "untouched field" branch, and
it agrees with the recorded `TRAPS posted=0`. **CORRECTED 2026-08-31 (section 136): that phrase is
NOT a measurement of the failing capture.** It is a source comment in `Nd500MicrocodeServicer.cs:3306`
plus a gate line from MY OWN octobus run; the peer's build had no trap counters when their capture
was taken. The conclusion below stands on the table bytes alone and never needed it.

**Confidence, stated narrowly:** the ORDER and the absence of anything below ZERO are solid from the
bytes. The exact index arithmetic is NOT pinned - the list is broken into groups by `00` bytes,
there is a `(length, pointer)` descriptor array elsewhere in BANK2 I have not tied to it, and our
numbering has a gap at bit 10 that a dense array would not have. So *"0 falls through"* is firm;
*"trap N renders name N-5"* is not.

### A second table, and it belongs to the other half

`BANK2::4f1c` is a DIFFERENT list - *Memory error / Memory timeout / Indirect capability to other
machine / Zero in the capability / **Zero in PST** / Zero in last level index entry for process
segment*. Those are page-fault CAUSE strings, and "Zero in PST" is the same condition this lane's
own instrument prints as `0xD PFZPST(no PST entry)`. **If the decline is a missing PST entry, that
is the table that would name it - not the trap table.**

### A string that nearly became the answer

`NOT-KNOWN\` at `BANK2::4265` looks like the obvious match for "NOT KNOWN TRAP". It is in a table of
DATA-TYPE names - `BYTE\ HALF-WORD\ WORD\ FLOAT...` - with a width array `1,2,4,4,4,4` above it. It
means "unknown data type". The console text has spaces and the string has a hyphen, which is the
tell. **Grepping for the string nearly produced a confident wrong table**; what settled it was
reading what sits AROUND the hit rather than the hit itself.

## 134. The microcode half: `PHYSWR` has NO error exit - it cannot answer `5ERANSWER` `[V]` 2026-08-31

The peer's half of the split asked me two things about the real B30. Both are now answered from the
microcode, and the answers are sharper than expected because the routine has no error path at all.

### `SC10` is the answer status, and `MSG_END` is the single exit that writes it

`MSG_END` @`017412` is the common tail every message handler falls into. Its body:

```
    017417   ADACT AA=2 AB=1 ORCON=0x04           set up the message address
    017420   ALU,A TYP,HW A,SC10 ... WR,POF        <-- STORE SC10 AS A HALFWORD INTO THE MESSAGE
    017421   ALU,A TYP,HW A,SARG SARG=100401 ... [ADDR=GIVEINT]   ring the ND-100
```

So `SC10` carries the status code, one halfword is written back, and then the interrupt is raised.
**That halfword is the ONLY thing `MSG_END` writes into the message** - no data, no byte count, no
error code beside it.

### `BMnn` is an OCTAL BIT POSITION, which fixes the two constants

Not inferred - our own `AccessModule.cs` carve says it verbatim: `BM11` (octal) = bit 9 = AOBF,
`BM12` = bit 10 = AIBF, `BM05` = bit 5 = ATRAP, `BM13` = bit 11, `BM14` = bit 12. So `BMnn` is
`1 << nn` with `nn` read as octal:

```
    BM02             = 4      = 5ERANSWER
    BM01 + CRY,ONE   = 2 + 1  = 3   = ANSWER
```

Both readings corroborate each other: `MSG_ILLEG` @`015221` does `ALU,A A,BM02 ... D,SC10` - the
decline is literally "status := 4" - and an unrelated site @`001064` does `ALU,A-1 A,BM02 ... D,SC10`,
i.e. 4-1 = 3 = ANSWER. Two independent sites agree on the same constant.

### `MSG_PHYSWR` writes ANSWER on every exit, and has no other exit

`MSG_31` @`015255` dispatches to `MSG_PHYSWR` @`015600`. The routine has exactly **two** exits, and
both set the same status:

```
    015613   ALU,A CRY,ONE A,BM01 B,X1 D,SC10  ... [ADDR=MSG_END]    word loop finished  -> SC10 = 3
    015616   ALU,A CRY,ONE A,BM01 B,X1 D,SC10  ... [ADDR=MSG_END]    byte tail finished  -> SC10 = 3
```

There is no third exit, no branch to `MSG_ILLEG`, and no other write to `SC10` anywhere in the body.
**On this path the microcode is structurally incapable of answering `5ERANSWER`.**

The label file agrees independently. `MSG_ILLEG` is referenced from `015217`, `015224`, `015226`,
`015227`, `015230`, `015231`, `015232`, `015233`, `015241`, `015242`, `015243` - all of them WORDS OF
THE MICFU DISPATCH TABLE itself (`MSG_00`, `MSG_02`..`MSG_07`, `MSG_15`..`MSG_17`). `015254`
(`MSG_30`) and `015255` (`MSG_31`) are NOT in that list. So `5ERANSWER` on a copy-family MICFU means
one thing only: **the MICFU code was never implemented**, decided by table lookup before any handler
runs. It is not something a serviceable `PHYSWR` can decide to return.

### What a serviceable `PHYSWR` actually does, in order

```
    015600-015604   read 4 operands out of the message at ORCON 0x0E, 0x12, 0x16, 0x18
    015610          D,MM,PHS   <- load the physical-segment register from SC5
    015611-015616   word loop, then a 0..3 byte tail (SARG=000003 masks the low 2 bits of the count)
    015621 / 015625 WR,PHYS    <- the actual guest-memory writes, byte and word
    -> MSG_END      one status halfword back, then GIVEINT SARG=100401
```

`D,MM,PHS` at `015610` is the segment latch, and it is loaded from a message operand - which is the
same fact section 125 arrived at from the other direction: these transfers are SEGMENT-RELATIVE, and
the segment travels in the message.

### What this hands the other half

If our side declines a `PHYSWR` with `5ERANSWER`, **the real machine would never have produced that
answer for that MICFU**, so any ND-100 behaviour that follows is behaviour SINTRAN only ever sees
when a MICFU is missing entirely. And if the ND-100 side is waiting on any answer field other than
the status halfword, it is waiting for something the microcode does not write.

### Method note

This cost about twenty minutes and needed no run: the `.LABE` cross-reference gave the dispatch
table's reference list, which answered "can this path reach the decline" before any word was decoded.
**A label file's REFERENCE column is a call graph** - section 78's mistake was making a call-graph
claim without consulting one.

## 135. The trap-table index arithmetic is PINNED: `index = trapBit - 5`, dense `[V]` 2026-08-31

Section 133 left this unpinned and named the reason: the string list looked like it was "broken into
groups by `00` bytes", I could not tie a `(length, pointer)` descriptor array to it, and our own
numbering has a gap at bit 10 that a dense array would not have. All three of those objections
dissolve on reading the bytes in order. **The arithmetic is now verified end to end.**

### The `00` bytes are WORD-ALIGNMENT PADDING, not separators

This is an ND-100 program: 16 bits per word, two characters per word. Every string whose length is
ODD is padded to the word boundary with one `00`. Every string whose length is EVEN has no pad:

```
    4546  5a 45 52 4f 5c 00        "ZERO\"    5 chars -> 1 pad byte
    454c  43 41 52 52 59 5c        "CARRY\"   6 chars -> no pad
    4552  53 49 47 4e 5c 00        "SIGN\"    5 chars -> 1 pad byte
```

Read as separators, those pads carve the list into meaningless groups and make the array look
irregular. They are not separators; `\` (0x5C) is the terminator, exactly as section 133 recorded.
**There is no descriptor array, and there does not need to be one** - the list is scanned forward
N terminators, which a dense variable-length array is exactly what you would use.

### The gap at bit 10 IS IN THE TABLE, as a one-space placeholder

This was my strongest argument against the arithmetic and it is the strongest evidence FOR it:

```
    455e  4f 56 45 52 46 4c 4f 57 5c 00     "OVERFLOW\"          index 4 -> bit 9
    4568  20 00                             " "                  index 5 -> bit 10   <-- BLANK
    456a  49 4e 56 41 4c 49 44 ...          "INVALID-OPERATION\" index 6 -> bit 11
```

Bit 10 is unassigned in our `TrapCondition` and in NDIX `trap.h`. The monitor keeps a blank entry in
its place so the array stays dense and indexable. **The hole is real, the table knows about it, and
that is why plain subtraction works.**

### Verified against TWO independent sources, all 34 entries

`index = trapBit - 5`, checked name by name against our `CpuND500.Trap.cs` enum AND against the real
ND-500 Unix `E:\Dev\Ronny\NDIX-C\kernel\MASTER\machine\trap.h`:

```
    0 ZERO(5)  1 CARRY(6)  2 SIGN(7)  3 FLAG(8)  4 OVERFLOW(9)  5 " "(10 unassigned)
    6 INVALID-OPERATION(11 IVO)      7 DIVIDE-BY-ZERO(12 DZ)    8 FLOATING-UNDERFLOW(13 FU)
    9 FLOATING-OVERFLOW(14 FO)      10 BCD-OVERFLOW(15 BO)     11 ILLEGAL-OPERAND-VALUE(16 IOV)
   12 SINGLE-INSTRUCTION-TRAP(17)   13 BRANCH-TRAP(18)         14 CALL-TRAP(19)
   15 BREAK-POINT-INSTRUCTION-TRAP(20)                         16 ADDRESS-TRAP-FETCH(21)
   17 ADDRESS-TRAP-READ(22)         18 ADDRESS-TRAP-WRITE(23)  19 ADDRESS-ZERO-ACCESS(24)
   20 DESCRIPTOR-RANGE(25 DR)       21 ILLEGAL-INDEX(26 IX)    22 STACK-OVERFLOW(27 STO)
   23 STACK-UNDERFLOW(28 STU)       24 PROGRAMMED-TRAP(29 PRT)
   25 DISABLE-PROCESS-SWITCH-TIMEOUT(30 DT)   26 DISABLE-PROCESS-SWITCH-ERROR(31 DE)
   27 INDEX-SCALING-ERROR(32 XSE)   28 ILLEGAL-INSTRUCTION-CODE(33 IIC)
   29 ILLEGAL-OPERAND-SPECIFIER(34 IOS)       30 INSTRUCTION-SEQUENCE-ERROR(35 ISE)
   31 PROTECT-VIOLATION(36 PV)      32 TRAP-HANDLER-MISSING(37 THM)  33 PAGE-FAULT(38 PGF)
```

Every one agrees. Our engine's trap numbering is correct against the monitor's own table.

### So section 133's conclusion is now VERIFIED, not just firm

The array starts at `ZERO` = bit 5 (BANK2 byte `0x4546`, word `0x22a3` - not `0x22c4`, which lands
mid-`DIVIDE-BY-ZERO`). What precedes it is the banner `"ND-500/5000 MONITOR  Version J04"` and two
formatting fragments `" "` and `" / "`, not table entries. With `index = bit - 5` pinned, **a
rendered trap number of 0 indexes -5. It is below the table and cannot name anything.** It is a field
the monitor was handed that nobody ever set. (An earlier draft said this "is what `TRAPS posted=0`
already said" - **struck, see section 136**: that counter was never measured in the capture at issue.
The claim rests on the table bytes, which is stronger anyway.)

### Two corrections to my own section 133

 - I listed `DISABLE-PROCESS-SWITCH-TIMEOUT` and skipped `INDEX-SCALING-ERROR`,
   `ILLEGAL-INSTRUCTION-CODE`, `ILLEGAL-OPERAND-SPECIFIER` and `INSTRUCTION-SEQUENCE-ERROR`. **Both**
   DISABLE-PROCESS-SWITCH entries exist - TIMEOUT at bit 30 and ERROR at bit 31.
 - The table base was quoted as `22c4`. It is `22a3`.

### The near-miss, and it is a new shape worth naming

Mapping the tail by name against our enum, I got a clean **one-bit shift from bit 31 upward** - our
`XSE`/`IIC`/`IOS`/`ISE`/`PV`/`THM` each one higher than the monitor's position, with a spurious `DE`
we appeared to have invented. It looked like a real engine defect and it was completely wrong.

**Cause: I read two NON-ADJACENT hexdumps as if they were continuous.** The first ended at `0x46c0`
on `"DISABLE-PROCESS-"`; the second began at `0x46e0` on `"DISABLE-PROCESS-"`. Those are two
DIFFERENT strings - TIMEOUT and ERROR - and the 32 bytes between them were never dumped. One entry
missing from the middle shifts everything after it by exactly one, which is indistinguishable from an
off-by-one bug in the thing being measured.

This is not the "wrong object" failure (#19) - the object was right and the values were right. It is
a **gap in the sampled range read as continuity**. The tell is available for free and I did not use
it: two consecutive dumps whose addresses do not touch. NDIX `trap.h` settled it in one grep, and
dumping the 32-byte hole confirmed both strings are present. **When a table decode produces an
off-by-N, suspect the READ before the subject** - and check that the ranges actually abut.

## 136. ROOT CAUSE (peer's lane): the fixture never attached a CPU before place-domain `[V]` 2026-08-31

The `NOT KNOWN TRAP` split is closed, and neither half's leading hypothesis was the cause. The peer
found it in their own TEST FIXTURE. Recorded here because both of my carves (sections 134, 135)
turned out to describe branches that never execute in this failure - which is exactly the outcome
that has to be written down, or the carves get remembered as "the fix".

### The census that refuted my mechanism and theirs together

Full history of the servicer's messages - 116 entries against a 400-entry ring, so nothing wrapped:

```
    116 answers, EVERY one N5STA=0003 "understood"
      0 answers with 5ERANSWER
      0 DECLINED markers
      0 PHYSWR / PHYSRD messages - MICFU=0019 was never sent at all
```

So `TryResolvePhysicalSegmentAddress` and the `5ERANSWER` decline are **not involved**. Section 132's
suggestion that a floppy-directory domain might produce a segment with no PST entry is refuted by the
same capture that was meant to confirm it - there is no PHYSWR to decline.

### The mechanism, and it lands where sections 133/135 said it would

The last message before the crash is `MICFU=0013` (23B `3START`, the swapper start), answered
immediately with `STOPR=0000 NUMPA=0000 MCNO=0000 TRAPN=0000`. In `Nd500MicrocodeServicer`, a start
TAKEN by a `ProcessHost` returns `false` and writes NO answer - the message stays `WAITING` and the
process's later stop answers it. An answer line therefore proves `startTaken` was **false**: nothing
took the start, and it fell through to the generic answer carrying an **all-zero stop record**.

`nd-500-mon` reads that as a stopped process with trap number 0. By the arithmetic pinned in section
135, `index = 0 - 5 = -5` - below the first entry - so it renders the fall-through text.
**A field nobody ever set, exactly as predicted, and now with the writer identified.**

### Why nothing took the start

`AttachRealCpuNow()` installs the ProcessHost bridge, and the harness called it only just before RUN,
on the documented assumption that the real engine is *"only needed from RUN onward"*. That assumption
is FALSE for place-domain: the monitor loads and STARTS the swapper as part of placement, so a CPU
has to be present to take the start. Their install fixture never called it. Every other fixture does
- which is why the ordinary linkage-loader capture runs the swapper fine **on the same pack**, and
why this reproduced deterministically three times. Structural, not a race, and nothing to do with the
DIT work.

### The classic-lane check, which is a real finding even though it is not this bug

The peer checked `CONT-STORE-10611` against my B30 result and it agrees. PHYSWR at `011453B`:
`011460` does segment+segment then `JSR 7771` (PST base + index); `011461` reads the entry via
`JSR 12026`; `011462`'s `COND,LCZ` is the **loop-counter** test, not a test of the entry's value.
There is no test of the entry anywhere and no branch to an error handler. PHYSRD ends `011452 / JMP
10537` and PHYSWR ends `011472 / JMP 10537` - one common tail, the same shape as `MSG_END`.

**So neither generation's microcode has a PHYSWR error exit, and our zero-entry "not present" decline
is our own invention on BOTH lanes.** Worth keeping.

### Correction to my own message, which the peer caught

I wrote that the conclusion "is what `TRAPS posted=0` already said". **They never reported that** -
the trap counters did not exist in the build that produced their capture. The phrase is a source
comment in `Nd500MicrocodeServicer.cs:3306` and a gate line from MY OWN octobus run, and I carried it
into their context as though it were their measurement. Annotated in place at sections 133 and 135.

Failure-taxonomy note: this is **#19, correct about the wrong object** - the string exists, the
number is real, and only WHOSE RUN it came from is wrong. It survives every check that verifies the
value.

### The peer's mirror of my near-miss, and it is the better statement of the rule

They nearly made the same mistake in the opposite direction: `RunDomainUnderRealSintran` dumps the
servicer log, but their standalone fixture never called it, so their first repeat run **could not
have answered the question it was launched to answer**. Their words, and they generalise my section
135 note better than mine did:

> An instrument that exists in a SIBLING path is not an instrument you have.

Same shape as reading two non-adjacent hexdumps as continuous: **the defect was in the READ, not in
the subject.** Both belong in taxonomy §0 as the "structurally blind instrument" (#8) - one blind
because it was never wired into this path, one blind because the sampled range had a hole in it.

### Status

Verification run in flight on their side; they are explicitly not claiming a fix until they have read
the console. Nothing here needs engine code, and neither side wrote any.

## 137. Item 7's "best target" was a degenerate corpus - and under it, one real defect `[V]` 2026-08-31

`ARITHMETIC_rem.json` was picked as item 7's next target on the strength of being the worst file in
the sweep: **0 match, 200 diverge, 280 unsupported**. Reading the corpus before believing the metric
changed the question, and then one diagnostic run found a real defect that the metric was hiding.

### The corpus cannot measure REM

```
    480 vectors,  ALL of them REM BY ZERO
    480 of 480 expect final ST = 0x1000 (bit 12, DZ) and nothing else
    224 distinct inputs -> 256 EXACT DUPLICATES (same bytes, same seed, same RAM, same name)
    one input is repeated 35 times
    280 are F REM (0xFE 0x58)   -> exactly the Unsupported count
    200 are D REM (0xFE 0x5C)   -> exactly the Diverge count
```

**No vector computes an actual remainder.** Fixing this file would turn 480 rows green while proving
ONE behaviour, and leave REM itself entirely unmeasured. Same generator defect as the SFILLN case in
section 129 - the generator varied the instruction and not the expectation.

There is a second, quieter problem: `MacroOracleState` carries `Zro/Sgn/Cry/Ovfl/K` and **no DZ
flag**, so the one thing the corpus asserts is not even in the oracle's comparison set. The file
cannot adjudicate itself from either side.

### But the engine failure under it is real, and it is not a missing opcode

Both opcodes ARE in the generated dispatch map, from the label file:

```
    map[65112] = new DispatchEntry(1115, 0, 1);   // 0xFE58  F1 REM  [labe]
    map[65116] = new DispatchEntry(1118, 0, 5);   // 0xFE5C  D1 REM  [labe]
```

So the routine is reached and something inside it dies. `RemOracleDiagTests` (new) asks it directly:

```
    F REM  -> THREW: Operand select D,ALU,REG37 not implemented yet [DEST=31 (0o37)]
    D REM  -> MICROWORD Z=1   FUNCTIONAL Z=0      (engines differ on Z alone)
```

### The instrument lied first, and fixing it flipped the diagnosis

The original message said only `Operand select D,ALU,REG37 not implemented yet`. Read literally that
means the REG37 destination is unimplemented - which **cannot** be true: 253 microwords use
`D,ALU,REG37`, and `LOADT`, `LOADD`, `STORE` and `STORED` are among them and work today. I was about
to record "REG37 destination missing", which would have been a confident wrong finding.

Adding the raw select to the message settled it in one run: `[DEST=31 (0o37)]`. **31 IS the ordinary
macro REG37 port.** It is normally INTERCEPTED UPSTREAM in `CpuND5000`'s dest-bank routing, and for
F REM it is not intercepted, so it falls through to `OperandRouter`, which has no case 31 because it
is never supposed to see one.

**So the defect is a MISSING INTERCEPT UPSTREAM, not a missing case in the router** - and the
"obvious" fix of adding `case 31:` to the router would be actively wrong: it would write some bank
and stop dying, converting a loud correct failure into silent wrong behaviour. That is precisely the
trap in the standing rule (*implement the microword, throw and log and die - progress is fields
IMPLEMENTED, never halts removed*).

Change made: `NotImplemented` in `OperandRouter.cs` now emits
`[{field}={value} (0o<octal>)]` alongside the mnemonic, with the reasoning in an XML remark.
**A mnemonic is not an identifier** - several selects render the same text, and the one case where
that ambiguity mattered is the one case that mattered.

### Correction to my own comment, same session

The first version of that remark said "a different select was the one that failed". The re-run
refuted it: the select is 31, the same one the working instructions use. The ambiguity was never
about WHICH SELECT - it was about WHICH LAYER was supposed to handle it. Comment corrected in place
rather than left to read plausibly and wrong.

### What item 7 should actually say

`ARITHMETIC_rem` is not a divergence to chase; it is a corpus to regenerate, sitting on top of one
genuine engine defect (the missing F REM dest-bank intercept) and one single-flag divergence (D REM,
Z only). The 280/200 split is a property of the FILE, not a measure of how broken REM is.

### 137a. Baseline check on the 4 red tests - NOT caused by the message change `[V]` 2026-08-31

The ND-5000 suite runs **755 passed / 4 failed / 3 skipped of 762** with the `NotImplemented` message
change in. Since that change edits an exception STRING, a test asserting on the text was the obvious
suspect, so it was checked rather than assumed:

```
    Entt_TrapFrame_CannotBeDriven_HardFail
    Rett_TrapReturn_CannotBeDriven_HardFail
    Trace_OfRealColdBoot_RecordsAddressesLabelsAndRegisterDeltas
    BothEngines_ProduceTheSameMonitorCall
```

`git stash push` on `OperandRouter.cs` alone, then re-running exactly those four: **4 failed, 0
passed** on the untouched tree as well. They are pre-existing and unrelated. Change restored.

Two of the names read like they assert a hard-fail message, which is what made the check necessary -
`grep` for the literal `"not implemented yet"` across the test folder finds it only in COMMENTS, in
three files, never in an assertion.

## 138. The peer's fix is VERIFIED, and it closes the trap thread `[V]` 2026-08-31

Their verification run landed: **Passed, 11m28s. "Swapper stopped" 18 -> 0. "NOT KNOWN TRAP" 3 -> 0.**
So the root cause in section 136 - the fixture never attaching a CPU before place-domain - is
confirmed by the fix, not merely by the story.

### The trap counters are now measured on their lane, by their instrument

`attempted=0 posted=0 lastTrapNumber=0`. This is the honest version of the number I mis-attributed in
sections 133/135 and corrected in 136: it is now a real reading from the lane in question rather than
a source comment plus my own run. **Sections 133/135 are confirmed from the other side** - the
rendered 0 could not have come from a trap, because none was ever raised.

### The console value our plan item 1B.3 was waiting for

```
    > Loading Control Store
    > Loading Swapper
    > Allocating memory - 7116B pages
    SWAPPING SPACE NOT AVAILABLE
```

`> Allocating memory` DOES appear, with **7116B pages**. That was an open value on our side and is
now measured.

### What remains, and it is install state, not engine

`SWAPPING SPACE NOT AVAILABLE` on the prefixed place-domain, and `NO SUCH DOMAIN` on the unprefixed
one - the latter genuinely unregistered in the transplanted description file. Both are consistent
with the bad-install finding in section 126, and neither points at the servicer or the microcode.

### One item deliberately left OPEN by both sides

Our zero-PST-entry decline in `TryResolvePhysicalSegmentAddress`. Section 134 (B30) and the peer's
`CONT-STORE-10611` check agree that **neither generation's microcode has a PHYSWR error exit**, so
that decline is our invention and will bite whenever a PST entry legitimately reads zero. It is not
this bug and not urgent, and it is engine behaviour, so it stays OPEN pending agreement rather than
being fixed unilaterally. Recorded on their side as plan item 1B.0a.

**No engine code was written by either side on this thread.**

### 138a. The OPEN PST item, stated properly `[OPEN]` 2026-08-31

Recording this here because it was sharpened in a message between lanes and a fact that lives only in
a message is a fact on its way to being lost.

**The wrong framing:** "neither microcode has a PHYSWR error exit, so our zero-PST-entry decline is
wrong - remove it."

**The right one:** *no error exit tells us the microcode does not DECLINE; it does not tell us what
it COMPUTES instead.* Both lanes agree on the negative and neither has measured the positive:

 - B30 (section 134): `MSG_PHYSWR` reaches `MSG_END` on both exits, always `ANSWER`. No test of the
   PST entry's value anywhere in the body.
 - classic `CONT-STORE-10611` (peer): `011460` does `JSR 7771` (PST base + index) and `011461` reads
   the entry via `JSR 12026` - **it reads the entry and then never tests it**. `011462`'s `COND,LCZ`
   is the loop counter.

So on a zero entry the hardware forms SOME address and writes there. `TryResolvePhysicalSegmentAddress`
computes `(entry AND 0x3FFF) * 2048 + offset`, which for a zero entry is `0 * 2048 + offset` - a write
low in physical memory. Whether that is what the hardware does is **unmeasured**.

**The open question is WHAT ADDRESS the hardware forms from a zero entry**, and it is answerable on
the microword CPU without touching engine code: seed a PST whose entry is zero, run a `PHYSWR`
through `MSG_31`, and record where `WR,PHYS` lands.

**Do not delete the decline before that is answered.** Removing it without knowing the computed
address trades a loud wrong behaviour for a silent one, which is strictly worse - the same shape as
the NO SUCH PAGE zero-fill near-miss and the `case 31:` near-miss in section 137. Neither lane edits
this alone. Peer's plan item 1B.0a.

## 139. Two of the four red ND-5000 tests were FALSE REDS, both fixed `[V]` 2026-08-31

Suite went **755 passed / 4 failed -> 757 passed / 2 failed** of 762. Neither fix touched engine
code; both tests were failing for reasons unrelated to their own subject, which is the worst kind of
red because it teaches the reader to distrust the subject.

### `Trace_OfRealColdBoot_...` asserted a label that does not exist

It required the trace to contain **`INIT_ND5000`**. There is no such label in
`MICRO-5800-B30.LABE`. The file has `INIT`, `INIT_1..3`, `INIT_ADRP`, `INIT_CLRSTS`, `INIT_FROM17`,
`INIT_REG`, **`INIT_SAMSON`** and `INIT_SAM_1`. `INIT_SAMSON` is the cold-boot entry on the label
file's own evidence - **defined at `014517`, referenced from `000000`** - and the trace the test
prints reaches it on tick 2:

```
    t=1 CS=000000(MASTER_CLEAR) ... ->014517
    t=2 CS=014517(INIT_SAMSON)  ...
    t=3 CS=014520(INIT_SAMSON+1) ...
```

**The `.LABE` parse this test exists to prove was working the whole time** - `MASTER_CLEAR`,
`INIT_SAMSON` and `INIT_SAMSON+1` all resolved. Only the expected NAME was wrong. Now asserts
`INIT_SAMSON`, with the address/reference evidence in the comment so the name is not "corrected"
back by someone who remembers the old string.

### `BothEngines_ProduceTheSameMonitorCall` compared DECORATION, not the call

It asserted whole-string equality on a bridge log line. The engines **agree on every field that
describes the call**:

```
    MON 377B argc=4 ret=0x08008255
    [0] @0x08012A28=0x00000001 | [1] @0x080240B0=0x00000000
    [2] @0x080240B4=0x00000000 | [3] @0x0802428C=0x00000000
```

The functional line simply carries 518 more characters of DIAGNOSTICS around them - `UCODE-ROLE`,
the first-sighting citation, `SWMSG/SWPFU/SWPST`, `FIFO-SCAN`, `DOORBELL`, `TABLE-A` - because that
lane runs through the servicer host where those probes are wired; the microword lane has no such
state and renders bare. 146 characters against 664, and **not one of the extra 518 is a property of
the MON call.**

Fixed by extracting the semantic fields (`SemanticCall`) - the `MON nnnB argc= ret=` head plus every
`[k] @0x...=0x...` operand matched by SHAPE rather than position - and comparing those. Both lanes
now produce byte-identical semantic strings, so **the two engines really do agree**, which is what
the test was always trying to say.

**The failure message was the expensive part.** It read *"a difference here is a real divergence
between the two engines, not a test artefact"*. It was exactly a test artefact, and the message
argued against looking for one. An assertion that swallows a diagnostic string also makes every
future diagnostic an API change.

### The remaining 2 are DELIBERATE and are not mine to change

`Entt_TrapFrame_CannotBeDriven_HardFail` and `Rett_TrapReturn_CannotBeDriven_HardFail` fail on
purpose - *"HARD-FAIL per audit - not skipped"*. ENTT (0xBC) and RETT (0x83) need in-trap-handler
context (`pcb.InsideTrapHandler` + `PendingTrapNumber`/`TrappingPC`/`ResumePC` + `THA`) that only a
real trap dispatch sets and the oracle cannot seed. Someone chose a permanent red over a skip so the
gap stays visible.

That is defensible, and it has a cost: **a suite that can never be green cannot signal a NEW
failure** - which is exactly what happened here, since two genuine false reds sat beside them
unnoticed. Reversing a deliberate audit decision is not mine to make alone, so it goes to Ronny.

## 140. Trap fixture step 1: the microcode named its own seed set - and NOTHING is unimplemented `[V]` 2026-08-31

Ronny chose "build the trap fixture" over skipping the two `*_CannotBeDriven_HardFail` tests. Step 1
was to ask the real B30 what `ENTT` and `RETT` actually consult, rather than seeding the microword
engine from the FUNCTIONAL engine's requirement list. `EnttReadTraceDiagTests` (new) drives each
routine from its `.LABE` entry with nothing seeded, so every address it touches is a dependency it
revealed rather than a value we chose.

### Headline: both routines EXECUTE. There is no missing microword.

```
    ENTT  from CS 0o673   ran 400 ticks, budget exhausted        (no exception)
    RETT  from CS 0o710   ran 194 ticks, ended "Opcode 0 at P=00000000 has no entry"
```

RETT's stop is the expected end - it completed the return and then tried to execute at the unseeded
`P=0`. **Neither routine hit an unimplemented field.** So the microword side needs no new
implementation for item 6b, only seeding. That is a much smaller job than the hard-fail messages
implied.

### RETT writes exactly the `struct pcb` trap fields - independent confirmation of the layout

```
    CS 14436: [000000BB] w1 := 0      pcb_ith    <- CLEARS THE IN-TRAP-HANDLER FLAG
    CS 14447: [000000BC] w4 := 0      pcb_tos
    CS 14450: [000000C0] w4 := 0      pcb_ll
    CS 14451: [000000C4] w4 := 0      pcb_hl
    CS 14452: [000000B6] w4 := 0      pcb_tha
    CS 14457: [000000A6] w4 := 0      pcb_mte1
    CS 14460: [000000AA] w4 := 0      pcb_mte2
```

Every one is a field start in the layout carved in sections 116/125, and `[0xBB] := 0` is the manual's
*"clears the trap bit"* (Ref 6.4/13.11) happening in front of us. **This is the layout confirmed from
a completely different direction** - previously from `pcb.h`, the `LOADCT_*` routines and the
place-domain write addresses; now from RETT's own stores.

Before those writes, RETT READS a contiguous block at `0x14, 0x18, 0x1C, 0x20, 0x24, 0x28, 0x2C,
0x30, 0x34, 0x38, 0x3C, 0x40 ...` - the saved register block it restores, one word each.

### ENTT reads the flag the functional engine keeps in a property

```
    CS 13742: [000000BB] r1     pcb_ith    the in-trap-handler flag
    CS 13744: [000000BA] r1     pcb_md
    CS 13762: [0000009A] r4     pcb_ote2
```

**This is why the microcode was asked first.** The hard-fail messages list the context as
`pcb.InsideTrapHandler + PendingTrapNumber/TrappingPC/ResumePC + THA`, which is the FUNCTIONAL
engine's model - C# properties. The microword engine has no such properties; it reads bytes out of
the PCB in memory. Seeding it from the functional list would have been seeding one engine from the
other engine's model, and `pcb_md` (0xBA) - which ENTT reads and the functional list does not mention
at all - would have been missed.

### The measured seed set for step 2

 - a PCB at a known base, with `pcb_ith` (0xBB) SET, plus `pcb_md` (0xBA) and `pcb_ote2` (0x9A);
 - `pcb_tha` (0xB6), since RETT restores through it;
 - a populated saved-register frame at `0x14` upward;
 - on the functional side the same state expressed as `pcb.InsideTrapHandler`,
   `pcb.PendingTrapNumber`, `pcb.TrappingPC`, `pcb.ResumePC`, `regs.THA`.

The two sides must be seeded to the SAME machine state through two different doors. That is the real
content of step 2, and it is now specified by measurement rather than by reading one implementation.

### Honest gap

ENTT exhausted its 400-tick budget rather than terminating, so with a zero PCB it does not complete.
Whether that is a loop or simply a long routine is **not established** - the budget was a guard
against a hang, and a guard that fires tells you it fired, not why. Step 2 seeds it properly and
will answer that as a side effect; until then, no claim either way.

## 141. Trap fixture step 2: the oracle can now seed trap context - ENTT still refuses `[V]`/`[OPEN]` 2026-08-31

`MacroInstructionOracle.TrapSeed` added, and both `*_CannotBeDriven_HardFail` tests are gone,
replaced by `Entt_EstablishesTrapFrame_BothEnginesAgree` and `Rett_TrapReturn_BothEnginesAgree`
which actually EXECUTE the instructions. **Both are still red, but they are now red with a
measurement instead of red with a refusal**, which is the whole point of the change.

### What the seed does

One `TrapSeed` describes the state once and reaches each engine through the door it actually uses:
 - MICROWORD: PCB bytes into memory - `pcb_ith` (0xBB) := 1, `pcb_md` (0xBA), `pcb_ote2` (0x9A),
   `pcb_tha` (0xB6), `pcb_mte1` (0xA6) - because that is literally where it reads them (section 140).
 - FUNCTIONAL: `GetPCB(0).InsideTrapHandler/PendingTrapNumber/TrappingPC/ResumePC` + `regs.THA`.

`pcb_md` is in the seed ONLY because the microcode read it; it appears nowhere in the functional
engine's model, and a fixture written from `Entt.cs` would have left it zero silently.

### RETT: it RUNS. The failure is the harness, not the instruction.

```
    Opcode 0 (octal) at P=00000000 has no entry in the reconstructed dispatch map
```

RETT executed, restored from the frame, and returned to `P=0` because the saved-register block was
never seeded - then the harness tried to fetch there. The fix is to seed the frame at `0x14` upward
(the block the read trace showed RETT restoring) with a resume PC pointing at a decodable NOOP.
**Nothing here suggests a defect in RETT.**

### ENTT: parks in the idle loop, and the likely cause is a POLARITY I have not verified

```
    macro instruction did not retire within 4096 microwords (parked at CS 16555)
```

Parking in DUMMY is the microcode's "this is not valid here" path, so ENTT rejected the seeded
context. The seed is at the right addresses - the unseeded trace read `0x9A/0xBA/0xBB` absolute,
which is PCB base 0, and that is where the cells are written.

**Leading candidate, explicitly NOT yet verified: `pcb_ith` polarity.** `Entt.cs` requires
`pcb.InsideTrapHandler` to be TRUE before ENTT will build a frame. The microcode may want the
opposite - `ith` clear meaning "not yet in a handler, so entering one is legal", with ENTT itself
being what SETS it. RETT clearing `ith` to 0 on the way out (section 140) is consistent with either
reading, so it does not settle it.

This is exactly the shape the project rules warn about - an `INVSEQ`-style polarity that reads
fluently both ways. **It is one bit and it is measurable**: re-run the read trace with `ith` seeded
1 and then 0, and see which one leaves the DUMMY loop. Do that before touching anything else; do not
pick the polarity that makes the test pass and call it verified.

### State

Suite: **757 passed / 2 failed / 3 skipped of 762** - the same 2 count as before, now attached to
tests that execute real instructions. Steps 1 and 2 of item 6b are done; step 3 is the frame seed
plus the polarity measurement.

## 142. ENTT: three candidate gates REFUTED, and the git history names the real mechanism `[V]`/`[OPEN]` 2026-08-31

Ronny's steer - *"talk to the 500 LLM about this, i think he changed entt"* - was right, and the
repository history says so. Recording the refutations first because they cost the most.

### The measurement: a 2x2x2 matrix, all eight cells IDENTICAL

ENTT driven as a REAL instruction (opcode bytes at P, normal fetch from the NoopEntry prologue) on
the microword CPU:

```
    bytes   BC CF 00 00 00 40 CF 00 00 01 00
    inputs  pcb_ith in {1,0} x pcb_pia in {absent,set} x pending-call interlock in {absent,armed}

    ALL EIGHT:  48 writes,  ZERO writes into the trap frame at THA+256,
                parked at CS 0o17461 (ith=1) / 0o17453 (ith=0), never retires in 4096 microwords
```

Only `ith` changes the park ADDRESS; nothing changes the OUTCOME. **So none of the three is the
gate.** A probe that returns the same answer for every input has not measured the input - and the
constant 48 writes across all eight suggests ENTT is not reaching its frame-building path at all.

What it does instead is build a trap record:

```
    CS 13237: [00000894] w4 := 0000700B     P just past the 11-byte ENTT
    CS 13241: [00000898] w4 := 00000002
    CS 13202: [0000089C] w4 := 00000023     0x23 = 35 = ISE (Instruction Sequence Error)
```

The MICROCODE agrees with `Entt.cs`, which documents "ISE if not in trap handler context".

### The mechanism, from the history rather than from more guessing

`fa0864920` *"ND500: keep the CALL/ENT* sequence interlock across a trap-and-restart"* says it
outright:

 - **"The save now happens in ENTT"** - ENTT is part of the CALL/ENT* sequence-interlock machinery,
   saving into a CPU-wide ring keyed on the trap frame address (THA+256).
 - the ENT* instructions committing after a fault meant **"the retry then raised a false ISE"** -
   the same 0x23 this probe records.
 - and it cites the terminal microwords that invalidate the sequence flag:
   `ENTS_END @004206` and `ENTSN_3 @004254 ... C,SEQ ... F,RETURN INVSEQ`.

So ENTT's legality is gated by the **sequence interlock**, exactly as ENTSN's was - and ENTSN only
became drivable when the oracle gained `pendingCallReturn`. That is why no amount of PCB seeding
helps: the gate was never a PCB field.

**But arming the PENDING-CALL form of the interlock did not satisfy it either** (cells 5-8 above).
So ENTT wants the interlock in the state a **trap dispatch** leaves, which is not the same as the
state a CALL leaves, and I do not yet know how to express that without running a real trap.

### Two instrument corrections from this round, both mine

 - My first probe entered at the microcode entry (CS 0o673) with no instruction in memory, so ENTT
   got operands no real fetch would produce. **Both polarities came back with the same idle loop**,
   which I nearly read as "polarity refuted" when it actually meant "the probe is not measuring".
 - I printed the trap number by READING `[0x89C]` after the run and got `0x0`. The write log shows
   `:= 00000023` and then `:= 00000000` later in the same run - **the microcode clears it**. Reading
   a latch after its consumer cleared it, which is taxonomy #19 for the third time this week. The
   write log is the truth; a post-hoc read of a transient cell is not.

### Status and what is asked of the other lane

Asked `nd500uc-d4` directly whether they changed ENTT, the ISE path, or the trap-context gate -
they own the commits above. If the contract moved, my seed set is built against the old one and no
seeding will satisfy it. **Not touching engine code pending their answer.**

Item 6b step 3 is therefore blocked on a question, not on effort. RETT remains the easy half: it
executes correctly and only needs its saved register block seeded.

## 143. The ENTT gate is an INTERNAL condition, confirmed on B30 - and section 142 made a category error `[V]` 2026-08-31

### CORRECTION to 142 first

Section 142 said the git history "names the real mechanism" and pointed at `fa0864920`, a change to
the FUNCTIONAL `CpuND500`. **That reasoning is a category error**: the measurement was made on the
MICROWORD engine running the real B30, and the microcode wrote the `0x23` itself. No edit to
`Entt.cs` can move what the microcode does. The peer holds no ENTT edits this session either, so
Ronny's recollection of an ENTT change is real but belongs to the functional side and is a red
herring for this fixture.

The interlock IDEA in 142 was right; the provenance was wrong. Corroboration between the two engines
is not a shared gate that someone could have moved.

### The gate, carved on B30 - `COND,SAVC1`, and it is not addressable from memory

```
    000673  ENTT       A,ALU,REG37 ... G,OPS READ ADACT ORCON=04      fetch operand 1
    000674             A,ALU,REG37 ... READ ADACT ORCON=04            fetch operand 2
    000675             ALU,A+B A,BM10 B,SC7 D,DAC,DPA -> ENTT1        DPA := SC7 + 256
    014042  ENTT1      ... C,SEQ T,JMP COND,SAVC1 -> ENTT2            THE GATE
    014043             ... -> TRAP_ISE                                 the refusal
    014044  ENTT2      ... proceeds (ENTT_REGS @014046 -> SAVEREG)
```

`ENTT1` tests **`COND,SAVC1`**. True goes to `ENTT2` and the body; false falls through one word to
**`TRAP_ISE`** - which is the `0x23` = 35 = ISE the probe recorded. `SAVC1` is an INTERNAL saved
condition, not a PCB field and not a memory cell, so **no seeding of `pcb_ith`, `pcb_pia` or the
pending-call state can ever set it.** That is exactly why all eight matrix cells came back identical:
a gate you cannot address from memory looks precisely like a gate you have not found.

### It matches the classic store, in a different encoding

The peer carved `CONT-STORE-10611` independently and found the same shape: ENTT at `000330B` tests
**`AM#37`**, branching to the body at `011640B` or to `002353B` which ORs a bit into S2 and jumps to
the trap-entry PROM at `000627B`. `AM#37` is likewise internal - zeroed by the microcode at
`002346B` beside the CALL bookkeeping. **Our own memory note already said it**: *"AM#37 = the
CALL-in-flight interlock ... 0 = CALL in flight"*. Another instance of a note we owned naming the
answer before we measured it.

So both generations gate ENTT on "did I ARRIVE here from a CALL/trap entry sequence", not on any
stored flag.

### The frame base agrees three ways

B30 `000675` computes `DPA := SC7 + BM10`, and by the octal-bit-position rule `BM10` = bit 8 = 256,
so the frame is at `SC7 + 256`. The classic body's first word is `AL#7 + BM#10` with `AL#7` the
trap-vector base - the same `THA + 256`. **The instrument was pointed at the right address**; only
the gate was wrong. Worth stating plainly, because "no writes at the right address" is easy to
misfile as "wrong address".

### What this makes step 3

ENTT cannot be seeded into legality; it must be ARRIVED at. The fixture has to drive an instruction
that genuinely traps, let the microcode take its trap entry and set the condition, and execute ENTT
as the handler's first instruction. That is a bigger fixture than a seed, and it is the only honest
one - a `SAVC1` forced from outside would prove nothing about the path SINTRAN actually takes.

RETT is unaffected and remains the easy half.

## 144. RETT drives, and the fixture immediately found ONE real divergence `[V]` 2026-08-31

`Rett_TrapReturn_BothEnginesAgree` now executes RETT on BOTH engines from a seeded trap frame. It is
red on exactly one difference, which is what a working oracle looks like.

### First, the base had to be measured - both candidates were zero

The original read trace showed RETT restoring from 0x14, 0x18, 0x1C ... and it was tempting to read
that as "B+20 onward", matching the ENTT layout comment. **But that trace ran with B = 0 AND
THA = 0**, so "B-relative" and "THA+256-relative" predict identical addresses. Re-run with
B = 0x2000 and THA = 0x5000:

```
    CS 14360: [00002014] r4      CS 14361: [00002018] r4      CS 14362: [0000201C] r4
    ... contiguous to [0000205C]
```

**B-relative, decisively.** Seeding the frame at THA+256 would have made RETT restore zeros, and
that would have read as a RETT defect rather than a fixture mistake.

### Then two "divergences" that were MY INSTRUMENT, not the engines

The first run reported three differences, including:

```
    mem[BB]=00000001!=00000000        pcb_ith
    mem[B6]=00005000!=00000000        pcb_tha
```

which reads as "the functional engine fails to clear the trap bit". **It does clear it - in its
object.** The two engines store this state in different places: the microword engine in the PCB in
memory, the functional engine in a `ProcessControlBlock` field. After RETT, memory 0xBB holds the
microword engine's REAL state and only the functional engine's STALE SEED.

**Only a cell BOTH engines write for the same reason can be compared**, and PCB fields are not that.
Removed from `memCheck` with the reasoning recorded at the call site. This is the dual-storage
version of the same lesson as the MON-call decoration in section 139: an assertion that compares
things the two lanes express differently manufactures divergences.

### What is left is ONE genuine divergence, in a register both engines have

```
    RETT micro B = 0x00002000        (unchanged - did NOT restore B from the frame)
    RETT functional B = 0x00000000   (restored B from the frame slot, which is zero)
```

Ref 6.4 / 13.11 describes RETT as restoring the saved block with `arg2 -> P, arg3 -> L, arg4 -> B`,
which is what the FUNCTIONAL engine did. The microword engine left B alone.

**Not adjudicated, and deliberately not guessed.** The project authority rule puts the real B30 above
the manual, so "the manual says arg4 -> B" does not settle it. The next step is to carve RETT's
microwords from `000710` and find whether any of them has a B destination at all - if none does, the
microword behaviour is correct-by-construction and the functional engine is over-restoring.

P differs by one (0x6001 vs 0x6000) and is EXCLUDED from the semantic diff - that is the known
prefetch/step-boundary artefact, not a finding.

### Status

Suite: **757 passed / 2 failed / 3 skipped of 762**. The two reds are now
`Entt_EstablishesTrapFrame_BothEnginesAgree` (blocked on the `SAVC1` gate - must be ARRIVED at, see
section 143) and `Rett_TrapReturn_BothEnginesAgree` (this one real divergence). Both are red for
reasons that are understood and written down, which the original hard-fails never were.

## 145. RETT does NOT restore B on the real B30 - carved exhaustively `[V]` 2026-08-31

Section 144 left one divergence: the microword RETT leaves `B` alone, the functional RETT restores it
from the frame. Ref 6.4 / 13.11 says `arg4 -> B`, which favours the functional engine - but the
project authority rule puts the real B30 above the manual, so the microcode was asked.

### The question is decidable because B has exactly ONE write port

`OperandRouter.cs` already carries the carve, from the 2026-07-23 B-maintenance fix:

> B is written ONLY through dest 228 (`D,DAC,REG04`) in the whole B30 image (**8 words**);
> `D,DAC,B` (226) and `D,DAC,SUMB` (227) are NEVER used.

So "does RETT restore B?" reduces to "is any of those 8 words in RETT, or reachable from it?" - a
question with a finite, checkable answer rather than a judgement.

### All eight B-writers, and where they live

```
    LOADB           the LOADB instruction
    000772          LOAD_L path
    004366          RET_2
    004407          RET_2
    004452          RET path
    LOADCT_B  011135   <- referenced only from 011066, the CNTXTLOAD chain
    LOADRB_B  011540   <- referenced only from 011425, the LREGBL register-block chain
    014755          CNTXTLOAD
```

**RETT occupies `014347` (RETT1) through `014514` (RETT_END). Not one of the eight is in that range**,
and the two register-block loaders that could plausibly have been called are each referenced from
exactly one site, neither of them in RETT.

### Two independent confirmations, which is the point

 - **CARVED:** no B write port is executed on the RETT path.
 - **MEASURED:** in the live oracle run the microword engine's `B` stayed at the seeded `0x2000`
   while the functional engine's became `0`.

The carve explains the measurement rather than merely agreeing with it, which is the difference
between corroboration and coincidence.

### So the divergence is real and it is the FUNCTIONAL engine that moves

`CpuND500`'s RETT restores B from the frame slot; the real B30 does not restore B at all. The manual
text `arg4 -> B` describes the saved BLOCK's layout, and section 140's read trace confirms RETT does
READ that whole block (`B+0x14` through `B+0x5C`) - it just does not route the B slot to the B
register. **Reading a slot and installing it are different acts, and the manual sentence does not
distinguish them.**

### NOT fixed - this is an adjudication, not a bug report

The project rule for a cross-engine divergence is explicit: surface both states with the citation and
let Ronny call it; do NOT auto-trust either CPU. Both engines are under development and "the
microcode is authoritative" does not by itself mean the functional engine's behaviour is unwanted -
it may be deliberately modelling what SINTRAN or NDIX needs. Asked rather than changed.

### 145a. Adjudicated: microword right, functional engine changed `[V]` 2026-08-31

Ronny called it - the real B30 is authoritative, so `Rett.cs` no longer assigns `regs.B = savedB`.
The READ of `savedB` stays (it is logged, and reading the slot is faithful to the microcode); only
the assignment is gone, with the eight-writer enumeration recorded at the site so nobody restores it
from the manual sentence.

**Baseline taken BEFORE the edit, deliberately:** `Emulated.Tests.ND500` was
**2264 passed / 0 failed / 13 skipped of 2277** - fully green. Any red after the edit is therefore
attributable, which is the whole reason to measure first rather than after.

**A near-miss worth recording:** the first attempt to apply this patch silently did nothing - the
file is CRLF and the patch text was LF, so `str.replace` matched nothing. The test run that followed
reported **the same 2264 passed**, and I nearly read that as "the change is safe". It was the
BASELINE run a second time, against unmodified code. That is memory note #10 exactly - measuring code
you are not running - and the only thing that caught it was the patch script asserting its own match
count and printing the failure. **An edit that reports success without asserting it landed is not an
edit.** `git diff --stat` afterwards (29 insertions, 2 deletions) is the confirmation that the second
attempt was real.

## 146. The classic lane RUNS - and its two causes do NOT transfer to the octobus lane `[V]` 2026-08-31

The classic lane reports the linkage loader running for real:

```
    N500: place-domain (210319H02-XX-01D:FLOPPY-USER)LINKAGE-LOAD-H02
    > Loading Control Store / > Loading Swapper / > Allocating memory - 7116B pages
    N500: run
    ND-Linkage-Loader -  H.02   3. March 1988
    Nll:
```

with trap counters `attempted=62 posted=62 lastTrapNumber=38` (page fault), 2092 messages and 64
starts - a system servicing real faults, not the all-zero placeholder of this morning.

### Their two causes, and I CHECKED rather than assumed

 1. the harness attached no ND-500 CPU before PLACE-DOMAIN (placement loads AND STARTS the swapper);
 2. a `DEFINE-SWAP-FILE` **definition does not survive a cold start** - the pack carried the swap
    FILE, the DEFINITION was what was missing, and their harness cold-starts every run.

**Neither applies to the octobus lane, verified in our own harness rather than reasoned about:**

 - `Nd100SintranNd5000OctobusBootHarnessTests.cs:368` calls `AttachNd5000Cpu` in SETUP, and the boot
   to `SINTRAN III RUNNING` is at line 1534 - the CPU is attached long before any command.
 - `define-swap-file` and `place-domain` already run in ONE monitor session here (the comment at
   line 2157 records the earlier shape that exited between them, and why it was changed).

So **their fix does not explain our `> Loading Swapper` stall**, and it must not be filed as though
it does. The temptation to adopt a neighbouring lane's root cause is exactly the shape that produced
the `NOT KNOWN TRAP` false convergence in section 132.

### A retraction that touches our record

Their install document had called the 5SWAP protect violation *"a pre-existing emulator-side
defect"*. It is **no longer reproducible**, and both causes were outside the emulator. Our own table
at line 526 describes that trap as dying in a *"known, carved way"*, which a later reader would take
as an understood ENGINE defect. **Annotated in place** with the correction: the address and the trap
are still correctly measured; treating them as a property of the engine is what was wrong.

### Their negative-result correction, which is our taxonomy in someone else's words

The `nd500-apps` skill asserted *"No vendor install sheet exists for the linkage loader (210319) -
all 290 Installation-Description sheets searched."* Both halves honest, conclusion false: the search
covered ONE SET, and *"not in that set"* hardened into *"does not exist"*. The install document
exists, and so does the installer program on the floppy - one `@LIST-FILES` of the media would have
shown it. **A recorded negative must name the sets it searched.** Same family as RULE #0b's "a search
that finds nothing is evidence about your pattern".

### Two instrument traps from their day, both worth carrying

 - **`LIST-DOMAIN` at the `Nll:` prompt describes the description file THE LOADER IS USING** - the
   floppy it was placed from - not the pack being repaired. It printed byte-identical lists before
   and after `COPY-DOMAIN` in two runs, and nearly became "the copy registered it". Reading the
   exported image with `ndfs` settled it. This is failure #19 again: right value, wrong object.
 - **A probe placed BEFORE its own preconditions measures the setup, not the subject.** Theirs ran
   with no CPU and no swap file and faithfully reproduced two known defects while looking exactly
   like a fact about the pack.

Nothing here needs action from this lane, and the PST zero-entry item stays open and untouched.

### 145b. PROCESS FAILURE: shared engine code changed while a peer had a run in flight `[V]` 2026-08-31

`Rett.cs` lives in `Emulated.HW`, which BOTH lanes execute. It was edited at 16:35; the classic lane
built at 16:53 and was told at ~17:05. **The warning went out after the change had already been
picked up, and the correct order was to ask BEFORE touching it.**

Cost: their in-flight run was meant to be a clean repaired-pack comparison against the morning's
baseline, and it now carries an engine change that had never executed on that lane. A real cost to
someone else's measurement, not a hypothetical one.

**What was applied and what was missed.** Shared-tree hygiene here has two halves - stage only your
own files, and coordinate before touching shared code. The staging half was applied; the
coordination half, which is the one that matters when a peer has a run going, was not. Adjudication
by Ronny covered WHETHER to make the change, not WHEN.

**Asymmetry the confound creates, worth stating because it decides how to read the result:** if their
run still reaches `Nll:`, that IS good evidence - 62 posted traps with `lastTrapNumber=38` is a real
fault-servicing workload on the other engine, worth more than one hand-built frame. If it REGRESSES,
the result is ambiguous, because the repaired pack and the engine change moved together. **A pass is
informative; a fail is not**, and a fail must not be read as "RETT broke it" without an isolation
run. Reverting the single assignment is a one-line experiment and stands offered.

### And an instrument note against this session

The background suite runs `... | Select-String ... | Select-Object -Last 12`, which **buffers the
entire output until the process exits**. The log file is therefore empty for the whole run, and
"still working" is indistinguishable from "hung" by looking at it. Not a wrong measurement - a
progress instrument with no progress in it, which cannot report until it no longer needs to. Four
reads of an empty file is the tell.

## 147. The RETT change is RED - the carve holds and the change still broke 12 tests `[V]` 2026-08-31

```
    BEFORE   Emulated.Tests.ND500   2264 passed / 0 failed / 13 skipped of 2277
    AFTER    (regs.B = savedB removed)  2252 passed / 12 FAILED / 13 skipped
```

Attributable, because the baseline was taken BEFORE the edit. **Reverted** - known-bad code in a
shared tree outranks a diagnostic run - and the change is parked as a patch rather than discarded.

### The carve was INDEPENDENTLY RE-DERIVED and it survives

The classic lane enumerated `D,B` writers on `CONT-STORE-10611`: **twelve**, not eight - a different
image, a different encoding, a different count, no shared prior carve. RETT there is dispatch entry
`000337B` with its body at `011737`, and the nearest writer `011730` is SEVEN WORDS EARLIER, in a
block that ends `011736/ JMP 2255`. They read `011737-011775` word by word: the body swaps
`AL#17/AM#14..AM#17` into `AM#30..AM#34` and straight back, and contains no `D,B` at all.

**So on both generations the hardware has no path to restore B in RETT.** That claim stands.

### Two facts that only matter together

The carve is right AND the change broke twelve tests. That kills two of my four candidates
(the enumeration is not wrong; "not in RETT's range" is not wrong) and leaves the fourth:

> **the functional engine's B restore is COMPENSATING for something genuinely missing elsewhere.**

Which would make the carve correct and the change **premature** - a different repair from reverting
and forgetting. The twelve failures would then be pointing at the missing thing, not at RETT. The
first name to surface was `Ents_PendingCall_SurvivesPageFaultTrapAndRett`, which is about the
CALL/ENT sequence interlock surviving a page-fault trap - the same interlock as `fa0864920`. That is
a lead, not a finding: **the run that produced it straddled the revert, so I cannot say which tree it
built against, and it has been stopped rather than quoted.**

### A NEW taxonomy entry, and it is not one of the nine

The peer's words, and they are the sharpest thing produced today:

> **Agreement is only worth something when the two sources have DIFFERENT blind spots. Mine had
> yours.**

Their re-derivation checked the link I was MOST confident about - the address-range step - and left
untouched the three I had listed as suspect: the provenance of the eight-writer count, whether B30's
RETT leaves its `.LABE` span, and "implausible" standing in for "enumerated". **Two confirmations of
one step is not two confirmations.** Every existing taxonomy entry is about one instrument lying;
this is about two instruments agreeing for a reason unrelated to the truth of the claim.

And their `011730` point is the concrete warning: seven words before the entry is close enough that
an address-range argument flips on a small error in the span. My B30 argument rested on exactly that
comparison. **Read the words, do not compare the ranges.**

### The line worth keeping

*A structural argument feels decisive in a way an agreeing run does not, and that is precisely what
made me stop looking.* The arguments that END a search are the ones that most need a second,
differently-blind measurement.

### Process

Two coordination failures today, in opposite directions, both mine to avoid next time: shared code
edited while a peer had a run in flight, and then reverted while their reply saying "do not revert"
was in transit. The peer killed their run (it also held `D:\rc-bin\out` and would have blocked a
clean rebuild). Tree is at HEAD; **no further `Emulated.HW` edits until their clean run lands.**

## 148. Why removing RETT's B restore breaks things: the hardware restores B via LREGBL, not RETT `[D]` 2026-08-31

Found read-only, while waiting for the coordination window - no shared-tree access needed. Graded
`[D]` because the account is assembled from three sources that each check out, but the twelve names
are not yet captured.

### The one confirmed failing test is NOT a "manual says arg4 -> B" test

`TestND500_EntsPendingCallSurvivesTrap.cs` (3 tests). Its subject is the CALL/ENT* sequence
interlock surviving a trap, and its own header states the microcode oracle plainly:

> the interlock is REAL hardware (microword `C,SEQ` / `INVSEQ`; CALL @000646 + CALLG @000652 set it;
> ENTD @000660 -> `INS_SEQ_ERR` @003141 reads `IDU,STS`) so the check must NOT be deleted.

It seeds `regs.B = OldB`, runs CALL -> ENTS -> page fault -> trap -> handler -> RETT -> retried ENTS,
and asserts `regs.B == NewB` - *"ENTS must have switched B to the new frame"*. **B must be correct
after the trap return for the retried ENTS to build the right frame.**

So this falls on the peer's stronger branch, not the weak one: it depends on B being right AFTER a
trap return, rather than asserting `arg4 -> B` directly. Twelve tests of that shape would be twelve
dependencies, not one belief counted twelve times. (Still to confirm across all twelve names.)

### And the missing restore path was in the enumeration all along

Of the eight B-writers on B30, one is **`LOADRB_B` @011540, referenced from `011425` - the LREGBL
register-block-load chain.** I had dismissed that as "not reachable from RETT", which is TRUE and
beside the point.

`fa0864920`'s own text says where the real trap return goes:

> under NDIX the restore never runs at all: `machine/locore.c` trapex ends every kernel trap handler
> with **`lregbl $CNTXMASK,r3`**, not RETT.

**That is the answer.** On real hardware the handler restores the register block - B included - with
an explicit `LREGBL`, which HAS a B write port. RETT does not need one and does not have one. The
two facts fit together instead of contradicting:

```
    RETT      restores P, L, status, trap flag ... and NOT B   (no write port - carved, twice)
    LREGBL    restores the register block INCLUDING B          (LOADRB_B @011540)
```

### So the change was CORRECT ABOUT RETT AND PREMATURE AS A CHANGE

Our functional engine's tests return through RETT alone and never model a handler doing an `LREGBL`.
Removing RETT's B assignment therefore leaves B unrestored on the only path those tests have. The
assignment was **compensating for an unmodelled `LREGBL` restore** - which is the fourth hypothesis,
now with a named mechanism rather than a shrug.

### What this makes the actual repair

Not "put the assignment back and forget", and not "remove it and fix twelve tests". The question is
whether our trap-return path should model the handler's register-block load. Until it does, RETT's B
assignment is load-bearing scaffolding and **must stay** - with a comment saying so, because the next
person to carve the microcode will reach exactly the same "RETT has no B port" conclusion and remove
it again.

**That comment is the deliverable from this whole episode**, more than the code change either way.

### 148a. Corroborated on the classic image, and THIS time on a different link `[V]`/`[D]` 2026-08-31

On `CONT-STORE-10611`, B's write port at `010425` is not a standalone instruction. It sits inside a
computed-index REGISTER-WRITE DISPATCH TABLE entered by `JMPREL`:

```
    010421/ JMPREL ;                                    <- relative jump on a computed index
    010423/ ALU,ADIR A,AM#20 D,DP   JMP 10460 ;
    010424/ ALU,ADIR A,AM#20 D,L    POPRET ;
    010425/ ALU,ADIR A,AM#20 D,B    POPRET ;            <- B
    010426/ ALU,ADIR A,AM#20 D,R    POPRET ;
    010427/ ALU,ADIR A,AM#20 D,X#0  POPRET ;
    010430/ ALU,ADIR A,AM#20 D,X#1  POPRET ;
```

with `010412/010413/010416/010417` doing the same for `AM#15`, `AM#14`, `AM#11`, `AL#11`.

**`[V]`**: a contiguous run of single-word "write `AM#20` into register N, then `POPRET`" entries
covering L, B, R, X0, X1, entered by `JMPREL`.
**`[D]`**: that this table is what a register-block restore drives, indexed by register number. No
caller has been traced from a classic trap handler, so the mechanism is strongly indicated rather
than carved end to end.

**Why this corroboration counts and the previous one did not.** The earlier classic-side check
re-derived the ADDRESS-RANGE step - the link this lane was most confident about - and was recorded as
independent when it was not. This one checks a DIFFERENT question: whether B has a generic
register-load path distinct from RETT. Different image, different link, genuinely different blind
spot.

### The comment that is the actual deliverable

The peer's wording, adopted, because it names the correct-but-insufficient argument explicitly:

> **DO NOT DELETE** on the strength of *"RETT has no B write port"* - that is TRUE and NOT
> SUFFICIENT. Real hardware restores B via `LREGBL` in the handler, which our tests do not model, so
> this assignment stands in for that until they do.

A comment that only asserts the conclusion gets deleted by the next person who proves the premise.
A comment that names the premise AND says why it is insufficient is the only kind that survives
someone who has just proved it - and two of us proved it independently within hours today.

### Counting caution to apply to the names

Three of the twelve failures live in one file. **Count FILES as well as tests** before treating
twelve as twelve independent pieces of evidence - clustered failures are one dependency observed
repeatedly, which is the same shape as "one belief counted twelve times" in a different disguise.

## 149. All twelve names, and they refute the weak reading `[V]` 2026-08-31

Window taken and closed. **Provenance checked as agreed: `Rett.cs` 17:02:18, `Emulated.HW.dll`
17:03:00** - the binary was built AFTER the source edit, so this run measured the patched code. Both
of us had already been burned once by a binary that did not contain what its source did.

```
    Ents_PendingCall_SurvivesPageFaultTrapAndRett
    Test_NCA06_Exit_Command            Test_NCA06_Help_Command
    CompileHelloMode_ProducesTheSameNrfAsTheCEmulator
    LinkHelloMode_ProducesTheSameDomAsTheCEmulator
    CpuStat_DecodesOurMachineIdentityCorrectly
    SystemTool_CPU_STAT   SystemTool_CAT_500   SystemTool_NC_CCompiler
    NC_LoadAndShowPrompt  NC_SendHelpCommand   NC_SendHelpCommandTwice
```

### FIVE files, not one - the counting caution mattered

```
    TestND500_EntsPendingCallSurvivesTrap.cs   1
    TestDOMExecution_MonitorCalls.cs           3
    TestMON_CompilePath.cs                     2
    TestMON_RealProgramRun.cs                  3
    TestNC_InteractiveInput.cs                 3
```

**Only ONE is a trap-semantics test. The other eleven are REAL PROGRAM EXECUTION** - the NC-A06 C
compiler failing to reach its prompt or answer HELP, CPU-STAT, CAT-500, and the byte-exact compile
AND link against the C emulator (3m42s and 4m12s runs). **Not one asserts `arg4 -> B`.**

So the "one belief counted twelve times" alternative is REFUTED rather than merely unlikely. They
break because after a trap return B is wrong and the retried ENTS builds the wrong frame - exactly
what an unmodelled `LREGBL` predicts, which turns section 148 from `[D]` to strongly evidenced.

### What is in the tree

`regs.B = savedB;` restored at line 248 with a 37-line comment above it. **Behaviour identical to
HEAD**; the build is green. The comment leads with the trigger rather than the conclusion:

> *DO NOT DELETE THIS ON THE STRENGTH OF "RETT HAS NO B WRITE PORT" - that statement is TRUE, and it
> is NOT SUFFICIENT.*

then carries both enumerations (8 writers on B30 with RETT's span, 12 on classic with the body read
word by word), the `trapex`/`lregbl` quote, the classic `JMPREL` register-write table, the
2264 -> 2252/12 measurement with the five-file breakdown, and the actual repair: **model the
handler's register-block load, and only then remove this.**

### Two taxonomy rows from today, both where every individual step was correct

 - **AGREEMENT WITHOUT INDEPENDENT BLIND SPOTS.** Two sources confirming the same LINK is one
   confirmation. The classic-lane re-derivation checked the address-range step - the one this lane
   was most confident about - and was nearly recorded as independent corroboration of the whole
   chain.
 - **RIGHT ANSWER, WRONG QUESTION.** *"Can RETT reach `LOADRB_B`?"* - no, correctly - terminated a
   search whose real question was *"what restores B on the trap-return path?"* - `LREGBL`, in the
   handler. **A correct answer to the wrong question is more dangerous than a wrong answer, because
   it closes the file.**

And the line this episode turned on: *a structural argument feels decisive in a way an agreeing run
does not, and that is precisely what made me stop looking.*

### 149a. Two qualifiers worth more than the finding `[V]` 2026-08-31

**The tell for RIGHT ANSWER, WRONG QUESTION is that the answer arrives CLEANLY AND EARLY.** A messy
answer keeps you looking; a clean one closes the file. Both of today's instances fit: *"can RETT reach
LOADRB_B"* answered no immediately, and the classic lane's *"does the repaired pack resolve the
loader"* returned a clean `NOT KNOWN TRAP` from a probe sitting upstream of its own preconditions -
answering a different question perfectly. **Suspicion should rise, not fall, when a hard question
resolves quickly.**

**The counting caution was REFUTED, and the asymmetry is the lesson.** The warning was that three
tests in one file might mean fewer independent failures than twelve. It came out five files with
eleven end-to-end program runs - stronger than the raw number, not weaker. **Counting files was cheap
and could only improve the answer whichever way it fell.** That is the profile of a check worth
running by default: near-zero cost, and informative in both directions.

**Why the comment had to name the premise.** Two agents, two images, independently proved *"RETT has
no B write port"* within hours - both correctly - and BOTH concluded the assignment should go. A
comment asserting only the conclusion would be read by the next person as something they had just
disproved. **We are the evidence that a competent reader will be right about the wrong thing here.**

**Scope note for the eleven:** they are the classic lane's vendor-program path - NC-A06, CPU-STAT,
CAT-500, byte-exact compile and link. Had the removal gone in quietly, those failures would have
surfaced later alongside a repaired pack and a fresh install, and the install would have taken the
blame. The near-miss cost was not this lane's.

---

## 150. ENTT was refused by EVERY path, and the cause was two fields that answered instead of throwing `[V]` 2026-08-31

**Result: ENTT now builds the trap-handler frame when arrived at through a real trap. ND-5000 suite
765 passed / 0 failed (was 757 with 2 permanently red).**

### What was measured, in the order it was measured

Section 143 established that ENTT's gate is `COND,SAVC1` at `ENTT1` @`014042` and that no PCB seed
can set it. What it did NOT establish is *what does*. A microword PATH trace answered that in one
run - and note the shape, because the write trace could never have: a refusal writes a trap record
and nothing else, so the addresses it touches are identical whatever refused. **The branch ADDRESS
is the only thing that names the gate, and it names it by construction.**

```
    673 -> 674 -> 675 -> 14042 -> 14043 -> 12666 (TRAP_ISE)      SavedCond1 = 0
```

which is exactly what the raw listing predicts:

```
  014042 ENTT1  ALU,A+B A,BM10 B,SC6 D,DAC,DPA C,SEQ T,JMP COND,SAVC1 TBC,NEXT -> ENTT2 014044
  014043         ALU,XOR A,BM00 B,X1 T,JMP COND,MSEXO TBC,NEXT -> TRAP_ISE
  014044 ENTT2  ALU,XOR EXUC ... TBC,NEXT (no T,JMP - falls to 014045; ADDR=DUMMY is the SNEAK)
  014045         ALU,A A,IAC,L B,X1 T,JMP -> ENTT_REGS 014046      the frame build
```

**An ENTT outside a trap handler raising ISE is CORRECT.** The opcode-dispatch entry at `000673`
exists to catch exactly that. The legal path is a different one.

### The legal path, and it was in the .LABE the whole time

`TRAP_START` @`014031`, reached from `014016`:

```
  014031 TRAP_START  read pcb_tha
  014032              READ the handler entry            <- reads THA + trapNumber*4
  014033              D,IAC,P  + test          -> zero entry falls out to TRAP_ERR 014017
  014034 -> DIS_IC 014657
  014035
  014036              G,TOOPS -> ENA_IC 014656          <- LOOK at the handler's 1st instruction
  014037              C,SEQ T,JMP F,RETURN COND,ENTT
  014040              T,JMP CSAVE COND,ENTT             <- THE ONLY CSAVE OF THE ENTT CONDITION
  014041              G,COOPS -> (dispatch) -> ENTT 000673 -> 674 -> 675 -> ENTT1 014042
```

So the gate is armed by the trap machinery LOOKING at the handler's first instruction and saving
"yes, it is an ENTT". Seeding was never going to work; arriving was always the only route.

### Defect 1 - four conditions that answered `false`

`Conditions.cs` had `COND,CALL` (60), `COND,ENTM` (61), `COND,ENTT` (62) and `COND,JUMPG` (63)
falling through to a shared `return false`. All four are one-line manual entries, ND-05.022.1
chapter 8 (echoed by `manual/mnemonics.md`):

```
  470 COND,CALL    MACROINSTR. IS CALL      0xC3
  471 COND,ENTM    MACROINSTR. IS ENTM      0xDF
  472 COND,ENTT    MACROINSTR. IS ENTT      0xBC
  473 COND,JUMPG   MACROINSTR. IS JUMPG     0xB4
```

and ND-05.020.01:2432 says how the hardware answers them: *"G,TOOPS is used to test if the target
instruction is ENTT, ENTM, etc., and it only needs IMAP information."* A decode of the instruction
register, not a latch. New field `Registers.InstrOpcode`, published in `FetchAndDispatch` beside
`InstrRin`/`InstrDt`.

`COND,ENTER` (32) is DELIBERATELY still false and is the one place a guess would be worse than the
gap: `manual/MICROCODE-FIELDS.md` says "ENTF/ENTM/ENTT instruction", ND-05.022.1 says "CHECK FOR
ENT- INSTRUCTIONS", and the two readings disagree about ENTS/ENTSN/ENTB/ENTD. Its four siblings
could be implemented precisely because each of their manual lines names ONE instruction. `[OPEN]`

### Defect 2 - G,TOOPS dispatched to the instruction it was only supposed to look at

`CpuND5000.cs` had `case 14: // G,TOOPS ... [D: same]` sharing `instructionFetch = true` with
`G,OOPS`. With that, `014036` jumped straight into `000673` and **skipped `014037` and `014040`
entirely** - so the CSAVE never ran and the gate could not be armed even with `COND,ENTT`
implemented. Fixed with `PeekInstructionForTest()`: publish the opcode, do NOT dispatch, do NOT
advance P. P must not advance because `014041`'s `G,COOPS` re-fetches the SAME instruction for real
- that is how control reaches ENTT's own entry with `SAVC1` already saved.

Path after both fixes:

```
  14031 -> 14032 -> 14033 -> 14034 -> 14657 -> 14035 -> 14036 -> 14656 -> 14037 -> 14040
        -> 14041 -> 673 -> 674 -> 675 -> 14042 -> 14044 -> 14045 -> 14046 ENTT_REGS -> ...
```

### Three facts the machine handed over on the way

 1. **`pcb_tha` (0xB6) points at a TABLE, not at a handler.** `TRAP_START` reads
    `THA + trapNumber*4` - measured `CS 14032: [0000508C]` with THA `0x5000` and ISE trap `0x23`.
    A zero entry drops to `TRAP_ERR`. That is ND-05.020.01:3222's *"THM, trap handler missing ...
    when no ENTT instruction, or an ENTT instruction with bad operands, is found as a trap handler
    entry"*, seen from the microcode side.
 2. **`pcb_ote1` 0x96 / `pcb_ote2` 0x9A are the own-trap-enable words**, and the search picks the
    word by trap number (ISE = 35 read `0x9A`). With them zero the trap is routed to the
    ACCP/mailbox region instead - "no local handler, tell the ND-100" - which is why TRAP_START was
    never reached and looked unreachable.
 3. The handler's first instruction must BE an ENTT, because that is literally what `014036`
    through `014040` test and save.

### The method note, and it is the transferable part

**An unimplemented field that returns a PLAUSIBLE answer is invisible to a throw-site inventory.**
Section 4's 25-site list is an inventory of code that ADMITS it is missing. A `return false` and an
`[D: same]` alias admit nothing: they answer, execution continues, and the feature silently does not
work. Every ENTT in the image was refused and **no throw, no failing test and no sweep divergence
said so** - the sweep could not, because ENTT is unreachable from the corpus, which is exactly the
condition that hides this class.

The tell that started it was not an error. It was a path trace showing a branch take the same arm
regardless of input - the same signature as the 2x2x2 matrix in section 143 returning eight
identical results. **A probe that gives one answer for every input has not measured the input**;
what section 143 could not say is whether that meant "none of these three is the gate" or "the gate
is not reachable from here at all". It was the second.

### Tests

 - `EnttReadTraceDiagTests.Entt_WhichMicrowordRefuses_PathTrace` - the refusing word names itself.
 - `EnttReadTraceDiagTests.TrapFind_DoesItEverReachTrapStart` - the arrival requirements, measured.
 - `CallManualCoverageTests.Entt_ArrivesThroughTheTrapPath_AndBuildsTheFrame` - replaces the
   seed-and-compare version, which could never pass. Asserts exactly ONE TRAP_ISE (a second means
   the handler's own ENTT was refused and the trap re-entered itself), that `ENTT_REGS` is reached,
   and that `SavedCond1 == 1`.
 - `CallManualCoverageTests.Rett_TrapReturn_BothEnginesAgree` - now pins the section 149 divergence
   to its exact shape (`Diff == "B=00000000!=00002000"`) instead of failing on it, so it fires when
   either engine's B behaviour changes, including when `LREGBL` lands.

**A CONSTANT-ANSWER SWEEP IS THE OBVIOUS NEXT PASS** and is not scheduled: grep `Conditions.cs` and
the GET/DEST switches for arms that fall through to a literal or to another arm, and check each
against its manual line. Five in one pass here.

## 151. The constant-answer sweep, done: three reclock strobes were writing the bus into P/SP/NPC `[V]` 2026-08-31

Section 150 ended by naming a sweep and not scheduling it. This is that sweep, run to the end.

**The DEST switch was the dirty one.** `Conditions.cs` came out clean; `OperandRouter.cs` had five
destinations carrying "treated as a plain X load `[D]`", each of which wrote the microword's own
data-bus value into a register. ND-05.022.1 ch.8 gives every one of them a FIXED SOURCE instead:

```
  197 D,IAC,SUML     SUM IS TRANSFERRED TO IAC Y REGISTER    0 sites  -> left as-is, [OPEN]
  205 D,IAC,CLKNPC   LA -> NPC                               0 sites
  206 D,IAC,CLKP     NPC -> P                                1 site   0o4465
  207 D,IAC,CLKSP    P -> SP                                 2 sites  0o11535, 0o14407
  227 D,DAC,SUMB     SUM IS TRANSFERRED TO DAC B REGISTER    0 sites  -> left as-is
```

**COUNT FIRST. It halved the work.** Three of the five never occur in the B30 image at all - the
manual line alone would have had us implement all five, and three of those implementations would
have been unfalsifiable forever. Sweep:
`MicrowordDecodeTests.ConstantAnswerDestinations_HowManyB30WordsUseThem`.

**What proves the manual right at the two live sites is the MICROCODE, not the manual.** 0o11535
decodes as `ALU,XOR A,BM00 B,X1 D,IAC,CLKSP`, and `XOR BM00,X1` is this project's own documented
NO-OP FILLER - the word that exists only to time the one-word condition delay. A word whose ALU
result is timing filler cannot be storing that result, so the destination must ignore the bus. We
were writing filler into SP. 0o4465 says the same thing independently: `XOR A,IAC,L B,SC14` into P,
and an XOR of L with SC14 is not a program counter.

**Both live sites sit in code the open RETT/B divergence depends on** - 0o11535 is inside the
`LREGBL` register-block loader (beside `LOADRB_P` / `LOAD_NEW_P` / `LOADRB_L` / `LOADRB_B`) and
0o14407 is inside RETT just past `RETT_NPLBR` - so this was measured, not assumed:

| suite | before | after |
|---|---|---|
| `CPU.ND5000` | 765 / 0 | **766 / 0** |
| `Emulated.Tests.ND500` | 2264 / 0 (13 skipped) | **2264 / 0 (13 skipped)**, 4 m 29 s |

Baseline held exactly on both, so the change is a strict improvement and the RETT/B divergence is
NOT explained by these strobes. That is a real narrowing: `LREGBL` remains the candidate, but its
CLKSP is now correct and still does not move B.

**Free corroboration.** `D,DAC,SUMB` and `D,DAC,B` BOTH having zero sites is a third independent
confirmation of section 145 - B's only live write port on this image is destination 228.

**THE CLASS IS NOW CLOSED, and the negative is the point.** A grep for `[D: same]` over
`CPU.ND5000/src` returns only the two lines that DOCUMENT the G,OOPS/G,TOOPS pair, and
`ReadA`/`ReadB`/`Conditions.cs`/`Alu.cs`/`Sequencer.cs` hold no bare `return 0` arm standing in for
an unimplemented select. Every remaining unimplemented field THROWS - so a throw-site inventory is
once again a true inventory of them, which it demonstrably was not before this sweep.

**The method note, which is the transferable part.** The tell that started this was never a throw
and never a red test: it was a microword PATH TRACE showing a branch take the SAME arm regardless
of its input. An unimplemented field that returns a plausible answer is invisible to every
instrument we own except that one. Both section 150 defects and all three strobes here have the
identical shape, and none of the five would have been found by counting throws.

## 152. Why `place-domain` says NO SUCH DOMAIN: the DESCRIPTION-FILE and the pack list DIFFERENT domains `[V]` 2026-08-31

Item 1 was written up as *"the pack is installed wrong - `DESCRIPTION-FILE:DESC` is LED's floppy file
copied unchanged"*. That is the right neighbourhood and the wrong object. Decoded from the bytes.

**Provenance first.** The file read here is `E:\Dev\Ronny\ND5000UC\DESCRIPTION-FILE.DESC`, and it is
byte-identical to the copy inside the pack - both sha256
`e6a58724b763a8644180bf4432f071058dc051c55ca481a45b6db92216b59c9a`, the second extracted from
`D:\DOMS-CSFIX.IMG` for the comparison. So this is the live file, not a stale export.

**Three tables, 22528 bytes, and almost all of it empty:**

```
0x0000  header, 0x0001 then 0xFF filler
0x0100  DOMAIN table, 56-byte entries          - exactly TWO entries
0x0800  file/device table, 0x800 stride        - three slots, only the first named
0x4000  SEGMENT table, 192-byte entries        - exactly TWO entries
```

**The domain table is HEALTHY.** Both entries are well formed, apostrophe-terminated, and the
LED-B03 one is not a floppy path at all:

```
0x0100  0000 4000  "SCRATCH-DOMAIN'"   ... +0x26 = 0800 0004
0x0138  0000 40C0  "LED-B03'"          ... +0x1E = 0800 0004 , +0x26 = 0806 011C
```

Entry layout `[V]` by the two entries agreeing field for field: +0x00 zero, +0x02 flags, +0x04..+0x19
name (22 bytes), +0x1A = 0xFF, +0x1C = 0x4000, then 8-byte descriptor slots at +0x1E and +0x26, and
0x0002 at +0x32/+0x36. That the two slots are PSEG and DSEG is `[D]` - inferred from SCRATCH-DOMAIN
having only the +0x26 slot filled while LED-B03 has both.

**The SEGMENT table at 0x4000 is where the floppy actually is**, and it carries a fully qualified
SINTRAN reference, `(USER)FILE`:

```
0x4000  (211160B03-XX-01D:FLOPPY-USER)SCRATCH-SEG-01'
0x40C0  (211160B03-XX-01D:FLOPPY-USER)LED-B03'
```

**THE ACTUAL DEFECT, and it is sharper than "installed wrong":** the DESCRIPTION-FILE registers two
domains whose segments live on a floppy user that is not on this pack - and the eight domains whose
files ARE on the pack are **not registered at all**. Set the two lists side by side:

| registered in DESCRIPTION-FILE | has a `:DOM` file on the pack |
|---|---|
| `SCRATCH-DOMAIN` -> `(...FLOPPY-USER)SCRATCH-SEG-01` | no |
| `LED-B03` -> `(...FLOPPY-USER)LED-B03` | no |
| — | `(SYSTEM)CPU-STAT:DOM`, `NC-A06`, `PLANC-500-G00`, `CAT-CAT5-B06`, `CONVERT-DOM-A03`, `LED-FORTRAN-A01`, `CODE-COVERAGE`, `AUTOMAKE-500-C00` |

**The intersection is EMPTY.** Every domain SINTRAN knows about is missing its files; every domain
whose files are present is invisible to SINTRAN. That is exactly the recipe document's observation
that a pack "answers `NO SUCH DOMAIN` for a domain whose segments are plainly present", now with a
cause instead of a symptom - and it means `place-domain CPU-STAT` cannot work on this pack no matter
what the octobus lane does.

**What this rules OUT, which is the useful half.** The blocker is not the octobus transport, not the
microcode, not the swapper and not `place-domain` itself. It is one file's contents. Anything
measured against `place-domain` on this pack before the registration is fixed is measuring the
registration.

**Next, and NOT yet done:** register a present domain. The proper route is SINTRAN's own
`ENTER-DIRECTORY` / `COPY-DOMAIN` / `DEFINE-STANDARD-DOMAIN`, driven on the live machine - writing
these tables by hand would be guessing at the `[D]` descriptor fields, and section 145's lesson
applies: a hand-built structure that merely looks right is the thing that survives every check.

### 152a. CORRECTION to 152 — the empty intersection is real, the conclusion drawn from it is NOT `[V]` 2026-08-31

Section 152 ended: *"it means `place-domain CPU-STAT` cannot work on this pack no matter what the
octobus lane does"*. **That is wrong, and a run on the very pack the bytes were read from says so.**

Measured, `D:\DOMS-CSFIX.IMG`, `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`, passing:

```
place-domain cpu-stat
> Loading Control Store
> Loading Swapper
[after PLACE-DOMAIN] startSeen=1 startMicfu=23B startTaken=True ansMON=377B
                     PC=0x08008255 stopMode=WAIT  micfu[1B:73 12B:1 23B:1 24B:1 31B:13]
```

`place-domain cpu-stat` does **not** answer `NO SUCH DOMAIN`. It loads the control store, loads the
swapper, the swapper STARTS and answers a MON 377B, and the ND-5000 then sits in `WAIT`. The whole
command runs. Nothing in the transcript refuses the name.

**What survives from 152 and what does not.** The BYTES are unchanged and still `[V]`: the domain
table holds exactly `SCRATCH-DOMAIN` and `LED-B03`, the segment table carries the
`(211160B03-XX-01D:FLOPPY-USER)` prefix, the pack's eight `:DOM` files appear in neither, and the
file read was sha256-identical to the pack's own copy. **What was wrong was the INFERENCE**: that
absence from that table is what produces `NO SUCH DOMAIN`. It is not - or at least not on its own.

**This is the "correct about the wrong object" shape.** Every check I ran verified the VALUE (the
decode is right, it reproduces, it matches the pack by hash) and none of them tested what the value
GOVERNS. A byte-exact reading of a structure says nothing about which code consults it, and the
question "what reads this?" is the one I skipped - the same miss as reading a mailbox header as
`extblk[0]`.

**And it lines up with what PLAN.md already said, which I should have weighed first.**
ND-60.136.04A ch.11: the `(directory:user)` prefix is *not consulted until the `:PSEG`/`:DSEG` are
opened*, so a file-copied domain RESOLVES and fails LATER at file open. The observed run is exactly
that - full resolution, swapper started, then quiet with nothing to page in. The document predicted
the behaviour I then contradicted.

**Still open, and now stated as a question rather than an answer:** what actually gates
`NO SUCH DOMAIN`, and where do the eight present `:DOM` files get resolved from if not this table.
Answer it by finding the reader, not by re-reading the bytes.

### 152b. SECOND CORRECTION — "the intersection is empty" was a GREP ARTEFACT, and the original PLAN.md text was right `[V]` 2026-08-31

152 claimed the DESCRIPTION-FILE's two registered domains have no files on the pack. **They have all
four of their files.** Measured on `D:\DOMS-CSFIX.IMG`:

```
  [0071] (SYSTEM)LED-B03:PSEG;1            223695 bytes   110 pages
  [0072] (SYSTEM)LED-B03:DSEG;1            394525 bytes   193 pages
  [0073] (SYSTEM)SCRATCH-SEG-01:PSEG;1          5 bytes     1 pages
  [0074] (SYSTEM)SCRATCH-SEG-01:DSEG;1       1029 bytes     1 pages
```

`SCRATCH-DOMAIN -> SCRATCH-SEG-01` and `LED-B03 -> LED-B03` both resolve to files that are present.
The intersection is not empty; it is complete.

**How the false finding was manufactured, because the mechanism matters more than the fact.** I
listed the pack filtering on `:DOM`, saw neither name, and wrote "registered but no files". A domain
does not have to be a `:DOM` file - a `:PSEG`/`:DSEG` pair is the other, older form, and it is the
form these two use. **RULE #0b exactly: a search that finds nothing is evidence about the PATTERN,
not about the data.** The pattern came from an assumption ("a domain means a .DOM"), so the zero
result proved nothing at all - and it read as a crisp, tabulated finding.

**Consequence: the ORIGINAL PLAN.md text was right and my "sharpening" made it worse.** The defect
is what it always said - ND-30.003.007:4607, the stored segment names still carry
`(211160B03-XX-01D:FLOPPY-USER)` while the files actually live under `(SYSTEM)` on this pack, so they
resolve to a user that is not there, and only at `:PSEG`/`:DSEG` OPEN time (ND-60.136.04A ch.11).
`COPY-DOMAIN` rewrites those names; `@COPY-FILE` does not. The observed run agrees: full resolution,
swapper started, then quiet with nothing to page in.

**What is left standing from 152:** the table offsets and entry layout, the two domain names, the two
segment names, the floppy prefix, and the sha256 match to the pack's own copy. All still `[V]`.
Everything I concluded ON TOP of those bytes has now been wrong twice.

**The pattern across 152 / 152a / 152b, worth more than the finding.** Same bytes, three readings,
two wrong. Both errors were inferences about what the data MEANS, never about what it SAYS, and both
survived re-reading the bytes because re-reading confirms the part that was already right. The two
questions that would have caught them are not "is this value correct" but **"what reads this?"**
(152a) and **"what else could this thing be called?"** (152b). Neither is answerable by looking at
the structure again, which is the only check I kept running.

## 153. `COPY-DOMAIN is needed` vs `COPY-DOMAIN is not needed` - the tree asserts both `[V]` 2026-08-31

Chasing item 1's fix, two settled-sounding statements turned up that cannot both be the whole truth.
Neither is a guess; both are written as conclusions, in the tree, by earlier work.

**Claim A - `PLAN.md`, item 1 "Next":** the pack is installed wrong; the stored names still carry
`(211160B03-XX-01D:FLOPPY-USER)`; ND-30.003.007:4607 says *"The description file still contains the
definitions valid for the user the domain is copied from. This must be corrected."*
**"`COPY-DOMAIN` rewrites those names; `@COPY-FILE` cannot."**

**Claim B - `Nd100SintranNd5000OctobusBootHarnessTests.cs:2630`, marked MEASURED 2026-08-01:** after
four plain `@COPY-FILE`s, `LIST-DOMAIN` answers

```
    Domain no.   0: SCRATCH-DOMAIN
    Domain no.   1: LINKAGE-LOAD-H02.......................SA:   26000006721
```

*"The monitor reads the copied description file on its NEW user and reports the domain WITH a start
address, so the floppy's description file does not hard-code its own directory the way the earlier
note feared. **COPY-DOMAIN is not needed.**"*

**They are not actually about the same event, and the harness comment says so four lines earlier:**
*"LIST-DOMAIN reads the description file only ... Starting it is the stronger proof but needs the
swapper, so a stall here is expected on this pack and is NOT evidence against the copy."*

So what B establishes is that the DESCRIPTION FILE **PARSES** on a new user and enumerates a domain
with a start address. What A is about is the `:PSEG`/`:DSEG` **OPEN**, which ND-60.136.04A ch.11 puts
strictly later - the `(directory:user)` prefix is *not consulted until the segments are opened*. B
never reached that point, because reaching it needs a working swapper, which that pack did not have.

**Therefore: B does not refute A, and A does not predict B's failure.** The reconciled position is
that both are true of their own stage, and **the question A actually raises has never been measured
on any pack** - nobody has yet watched a file-copied domain get as far as opening its segments.

**Two process notes, because this cost a tick to untangle:**

 - **A conclusion sentence outlived its own qualifier.** "COPY-DOMAIN is not needed" is four lines
   below "starting it is the stronger proof", by the same author in the same commit. The qualifier
   is the load-bearing half and it is the half that does not get quoted. This is the octobus skill's
   trap 1 (status headers in this tree lie) in its most benign form - nobody was careless, the
   summary line just travels better than the caveat.
 - **`COPY-DOMAIN` is a LINKAGE-LOADER command, not a SINTRAN or ND-500-monitor one** -
   `@LINKAGE-LOADER / COPY-DOMAIN <source with (dir:user)> "<dest>" / EXIT`
   (`Nd100SintranNd500BootHarnessTests.cs:1421`). That is why it is absent from
   `SINTRAN-Commands.md`, which is complete for the commands it covers. Do not record the reference
   as having a hole. And `DEFINE-STANDARD-DOMAIN` is **not** a registration mechanism at all - it
   populates the reentrant subsystem table so a name resolves without the monitor, and it requires
   *"an already loaded domain"*. Item 1's proposed
   `ENTER-DIRECTORY`/`COPY-DOMAIN`/`DEFINE-STANDARD-DOMAIN` fixture names three commands doing three
   unrelated jobs.

**A fixture already exists and should be reused, not rebuilt:** the octobus harness has COPY-DOMAIN
call sites at lines 2057, 2346 and a full manual-copy ladder ending at 2650, including
`define-swap-file`, `list-domain` and `define-standard-domain`. Starting from scratch here would
have repeated all of it.

## 154. The stall is UPSTREAM of the domain: correct names and stale names give a bit-identical result `[V]` 2026-08-31

Section 153 established that nobody had ever watched a domain with stale `(dir:user)` segment names
get as far as OPENING those segments. `D:\DOMS-CSFIX.IMG` can reach the stage and carries the exact
specimen, so the experiment was run directly - same test, same pack, same windows, only the domain
name changed (via the new `RETROCORE_ND5000_DOMAIN` knob).

**The two domains, chosen to differ in precisely the property under test:**

| domain | DESCRIPTION-FILE segment names | files on pack |
|---|---|---|
| `cpu-stat` | not registered | `(SYSTEM)CPU-STAT:DOM`, 19 pages |
| `LED-B03` | `(211160B03-XX-01D:FLOPPY-USER)LED-B03` - STALE | `(SYSTEM)LED-B03:PSEG` 110 pg + `:DSEG` 193 pg |

**Result - the machine cannot tell them apart:**

```
cpu-stat : PC=0x08008255 stopMode=WAIT startSeen=1 startMicfu=23B startTaken=True ansMON=377B THA=0
LED-B03  : PC=0x08008255 stopMode=WAIT startSeen=1 startMicfu=23B startTaken=True ansMON=377B THA=0
```

Identical PC, identical stop mode, identical swapper handover, identical MON answer, identical
`THA`. The only differing field is the watchdog tally (`micfu[1B:73` vs `1B:30`), which counts
elapsed time and nothing else - the windows differed. Both consoles end the same way, with no error
of any kind:

```
ND-5000: place-domain <name>
> Loading Control Store
> Loading Swapper
<silence>
```

No `NO SUCH DOMAIN`, no file-open error, no trap. The stale prefix produces no observable effect
whatsoever.

**CONCLUSION, and it redirects item 1.** The stall is strictly UPSTREAM of anything domain-specific:
the bring-up never reaches the stage at which a segment name could matter. The stale
`(211160B03-XX-01D:FLOPPY-USER)` records may well be a real defect - ND-30.003.007:4607 says they
are - but **they cannot be what is blocking us now**, and correcting them would not change this
outcome. Item 1's standing framing ("THE PACK IS INSTALLED WRONG. Fix that before measuring
place-domain again") has the order backwards.

**Why this is a real measurement and not another null result.** The instrument DISCRIMINATES on the
thing it is supposed to discriminate on - two domains that differ in exactly one property - and
returns the same answer for both. That is the same tell that found the ENTT bugs in section 150: a
branch taking the same arm regardless of its input. Here it is the desired outcome rather than a
defect, because it localises the fault upstream of the branch.

**What the transcript points at instead, sitting above every command in both runs:**

```
ND-5000: (first line after @nd-500, before any command is typed)
ND-5000 timeout:      ACCP was terminated; Microprogram has stopped
```

That is the known upstream bug, and it is present in the runs that were called working. Per the
standing rule - fix known bugs before hunting features, because a feature may never work while a bug
upstream of it eats the result - **that line is the next thing to work, not the DESCRIPTION-FILE.**

## 155. The ACCP termination message fires BEFORE the control store is loaded, once, and never again `[V]` 2026-08-31

Section 154 named `ND-5000 timeout: ACCP was terminated; Microprogram has stopped` as the next thing
to work. Before instrumenting anything, the emitting condition was read from the NPL source and the
message's position in the transcript measured. Both say the same thing, and it is not what the
standing note assumes.

**The emitting condition, `RP-P2-N500.NPL` @127642 - read, not derived:**

```
127642   IF X:=WATCHDOG=TMRXQ THEN
127646      CALL RN5STATUS
127647      IF A><ANSWER THEN
127652         T:=5MBBANK; X:=MAILINK; *AAX X5BRK; LDATX   % Microprogram break?
127656         IF A><0 GO 5TMRA
127657         0=:TMR
127660  N5ABORT:  N5TIMOUT
127663         CALL RSTARTALL; GO TMRET
```

So it prints when the outstanding WATCHDOG message's `N5STA` is not `ANSWER` **and** `X5BRK` is zero
(a non-zero `X5BRK` is a microprogram BREAK and routes elsewhere, to `5TMRA`). It is a statement
about one unanswered watchdog, nothing more.

**Where it lands, measured in the console dump:**

```
  line 30   @nd-500
  line 33   ND-5000 timeout:  ACCP was terminated; Microprogram has stopped
  line 35   ND-5000: define-swap-file
  line 38   ND-5000: place-domain LED-B03
  line 40   > Loading Control Store
  line 45   > Loading Swapper
```

**ONE occurrence, and it precedes the control-store download.** It never recurs afterwards, and the
watchdog is answered normally from then on - the same run records `answers=70 inserted=70
skipped[notInit=0 full=0 noHeader=0]` and thirty-odd `3RMICV` round trips.

**Reading: at the moment it prints, the statement is TRUE.** No microprogram had been loaded yet -
the store is downloaded later, by `place-domain` - so there was nothing to answer the watchdog, and
`X5BRK` was legitimately zero. SINTRAN detected a stopped microprogram, said so, and called
`RSTARTALL`. The classic ND-500 lane reaches the same place by a different route: `RSTA5` bit 9
`5CLOST` -> `ECSLOAD 2032B` -> "Loading Control Store".

**Therefore the standing framing needs qualifying.** This line has been carried as a known bug
stepped over in every run including the working ones. It is better described as **a true report at
monitor entry that self-clears**, and it is NOT evidence of a defect on its own. What would be a
defect is the same message appearing AFTER a successful control-store load, or recurring - neither
happens here.

**What is NOT established, and must not be glossed:** whether real ND hardware also prints this on
entering `@ND-500` before any store is loaded. Nothing measured here says it does; the argument is
only that our machine's message is consistent with its own state and with the NPL condition. Until
a real-machine transcript settles it, treat "this message is normal at entry" as `[D]`, not `[V]`.

**Consequence for 154's conclusion.** 154 correctly showed the stall is upstream of the domain, and
correctly pointed here next. But this line is not the upstream fault - it is a symptom of the
ordering (monitor entered before any store exists), and it clears. The stall after
`> Loading Swapper` remains unexplained, and the search for it should NOT start from this message.

## 156. The hang has ONE location and it is the same for both domains - identifying it is [OPEN] `[V] location, [OPEN] identity`

The harness samples ND-100 `(PC,PIL)` while a monitor command is outstanding, precisely so a command
that never returns can be named rather than guessed at. Both runs from section 154 agree:

```
place-domain cpu-stat : 2759 samples, 104 distinct   place-domain LED-B03 : 1006 samples, 72 distinct
  PC=0x000012C2 pil=0  x543                            PC=0x000012C5 pil=0  x199
  PC=0x000012C3 pil=0  x520                            PC=0x000012C6 pil=0  x191
  PC=0x000012C4 pil=0  x500                            PC=0x000012C4 pil=0  x187
  PC=0x000012C5 pil=0  x526                            PC=0x000012C3 pil=0  x177
  PC=0x000012C6 pil=0  x516                            PC=0x000012C2 pil=0  x174
  (next entry: PC=0x00004726 pil=1 x4)                 (next entry: PC=0x00007E79 pil=1 x4)
```

**`[V]` FACTS.** Five CONSECUTIVE words, `0x12C2..0x12C6` (octal `011302..011306`), at **PIL 0**,
holding ~92-94% of all samples in both runs, with roughly EQUAL counts across the five - the
signature of a straight-line body executed over and over, branching back at the end. Everything else
is PIL 1 noise at 2-4 samples. The location is identical for both domains, which is independent
corroboration of 154: whatever this is, it does not depend on which domain was asked for.

**`[OPEN]` WHAT IT IS. A wrong identification was nearly published here - recording the wrong turn.**
`0o11302` resolves in `nd-500-mon-j04.prog.asm` (the ND-500 monitor program, which does run at PIL 0,
so the hypothesis was reasonable) to:

```
011302  170544   SAA 144
011303  144151   SWAP CLD SA DD
011304  050151   LDT 151
011305  032011   STF ,X 11
011306  024150   LDD 150
```

**That is floating-point straight-line code with NO backward branch, so those five words cannot be a
spin loop.** The disassembly is `-b 0`, i.e. listing addresses, and a listing address is not a linked
address - the same trap as taxonomy #13. Either the program's load base is not 0, or the hot loop is
not in this program at all. **Do not record `011302` as the hang site.**

**How to close it, cheapest first:**

 1. Get the LOAD BASE of the running image and re-resolve `0x12C2`; a base-relative match to real
    loop-shaped code (a compare and a backward jump) is the confirmation to insist on.
 2. Failing that, dump the ND-100 words at `0x12C2..0x12C6` from the live run and disassemble THOSE.
    That needs no base and no listing - it is the actual executing code.
 3. The shape to expect is a poll: load a cell, test it, branch back. Whatever cell it loads is the
    thing that never changes, and THAT is the real question.

**Accept nothing that does not disassemble to a loop.** The one check that catches a wrong base is
free: the code at a spin site must contain a backward branch. The FP sequence above fails it on
sight, which is the only reason this is an `[OPEN]` and not a published answer.

## 157. The hang loop READS NOTHING - it cannot be polling for the answer `[V] code, [D] reading`

Section 156 refused to name the hang site from a listing address and specified the fix: dump the
LIVE ND-100 words, which needs no load base. `DumpHangPcHistogram` now does that. Result, straight
out of `_machine.mem.ReadMemory32W` while `place-domain` was outstanding:

```
    0x12C1  0xD00D
    0x12C2  0xCC77   <- hottest   = 0o146167   RADD CLD ST DX
    0x12C3  0xB500               = 0o132400   JNC 0            (X:=X+1, jump to SELF while X negative)
    0x12C4  0xCD01               = 0o146401   RADD AD1 0 DD    (D := D + 1)
    0x12C5  0xCE6D               = 0o147155   RADD ADC CLD SA DA
    0x12C6  0xA8FC               = 0o124374   JMP -4   -> 0x12C2
    0x12C7  0x0000
```

**156's own falsification test PASSES: there IS a backward branch.** `0o124374` renders as `JMP -4`
in the project's existing disassembly (`115205 124374 JMP -4 ; -> 115201`), and `-4` from `0x12C6`
lands exactly on `0x12C2`, the hottest sample. Every opcode above is decoded from how the real
disassembler renders that same octal word elsewhere in the corpus, not from recollection: `0o132400`
appears four times as `JNC 0`, `0o146401` as `RADD AD1 0 DD`.

So the five equal-count samples are one 5-word loop, and the equality is explained: the inner
`JNC 0` falls straight through (X non-negative), so each of the five words executes about once per
pass. A `JNC` spinning on X would have dominated the histogram instead - it does not.

**THE FINDING `[V]`: the body is REGISTER-ONLY.** Three `RADD` register-to-register operations, one
`JNC` (which touches only X), one `JMP`. **No memory reference. No IOX. Nothing is read.**

**THE READING `[D]`: a loop that reads nothing cannot observe anything.** It cannot be polling the
mailbox, a status word, or a device - there is no load to poll with. Its only possible exits are the
`JNC` condition on X and an **interrupt**. Since it never exits, either the counter never reaches its
limit, or the interrupt never arrives. The shape - an X-counted inner delay inside a D-counted outer
one - is a two-level DELAY loop, which on this architecture is what code runs while waiting to be
interrupted.

**That makes the next measurement sharp, and it is NOT "why does place-domain hang".** The ND-500
answer path and the interrupt are separate things: the microcode writes the answer AND raises level
12. This run shows the answer side working - `MON answer delivery: answers=70 inserted=70
skipped[notInit=0 full=0 noHeader=0]`, `startTaken=True`, `ansMON=377B`. **What has never been
checked is whether the corresponding level-12 interrupt is actually raised to the ND-100.** An answer
written with no interrupt would produce exactly this: a satisfied mailbox, and an ND-100 spinning in
a delay loop that reads nothing and is never woken.

**Do not treat that as established.** It is the leading hypothesis and it fits every number in hand;
it has not been measured. The check is to count level-12 interrupt raises on the octobus path against
the 70 delivered answers, and the two numbers must be compared - a single count would be
unfalsifiable on its own (taxonomy #7).

## 158. REFUTED: interrupts ARE delivered throughout the hang - and the PC sampler was showing the idle loop `[V]`

Section 157 proposed that the ND-100 sits in a register-only delay loop because the level-13
interrupt announcing an answer never arrives. **Measured, and it is wrong.**

Counters were snapshotted at command entry so the delta covers the STALLED WINDOW ONLY:

```
DURING `place-domain cpu-stat` :  raises=1599  delivered=286  whileDisabled=733
DURING `run`                   :  raises=0     delivered=0    whileDisabled=0
run-cumulative (uninterpretable): raises=1645  delivered=294  whileDisabled=754
```

**286 interrupts were delivered to the ND-100 while the command was hung.** The interrupt path is
alive and busy for the whole stall, roughly 1.4 deliveries a second. The ND-100 is being woken
constantly, servicing each one, and returning. 157's account is dead.

**A free corroboration in the second row.** `run` shows `raises=0 delivered=0` - literally no octobus
activity at all. That independently confirms the earlier reading that `run=STALL` is an ARTEFACT:
`place-domain` never returned a prompt, so `run` was typed into a monitor that was not listening and
no command was ever processed. Two instruments, same conclusion, arrived at separately.

**THE INSTRUMENT LESSON, which is the valuable part.** The five-word loop at `0x12C2..0x12C6` ends in
an UNCONDITIONAL `JMP -4` and reads nothing, so it has no exit at all - and yet the machine is
demonstrably alive and servicing 286 interrupts. A loop with no exit, at PIL 0, in a live system, is
**the idle loop**: SINTRAN has no runnable process, so it idles; interrupts fire, get serviced, and
return to it because the thing that would run next is still blocked.

If that reading holds, the PC histogram never pointed at the bug. Its own comment says *"a hung
monitor command is a SINTRAN routine that never returns, and the only question worth asking is WHICH
one"* - but when the monitor program is BLOCKED rather than SPINNING, the sampler catches the idle
loop and names nothing. It reports a location with total confidence and ~93% of samples either way,
so nothing about the output distinguishes the two cases. **A sampler that cannot tell "spinning here"
from "idle because something else is blocked" is answering a different question than the one asked
of it** - and unlike a wrong number, this one looks exactly like a right one.

**THE DISCRIMINATING TEST, cheap and not yet run:** print the histogram for a SUCCESSFUL command as
well as a stalled one. If `0x12C2` is equally hot while commands are completing normally, it is the
idle loop and every conclusion drawn from its address is void. If it is hot ONLY during the stall,
it is a real spin and the address means something. The histogram currently prints only on stall
(`if (done >= 0) return;`), which is exactly why this was never visible.

**Status of the hang: OPEN, and further from an answer than section 156 suggested.** What is now
established is narrower but solid: the ND-100 is ALIVE and interrupted throughout; the answer path
delivers (`answers=74 inserted=74`); the swapper started and answered MON 377B; the ND-5000 sits in
`WAIT`. Nobody is failing to signal anybody. Something is waiting for work that is never queued.

## 159. CONFIRMED: `0x12C2..0x12C6` is the IDLE LOOP. Sections 156/157 localised nothing `[V]`

The control case from 158 was run - the histogram now prints for COMPLETED commands too:

```
`set-avail`      [COMPLETED - control case]:   1 sample    PC=0x000012C3 pil=0
`swap-file:data` [COMPLETED - control case]:   1 sample    PC=0x000012C3 pil=0
`place-domain cpu-stat`  [STALLED]:  889 samples, 70 distinct   0x12C2..0x12C6 pil=0 ~=93%
`run`                    [STALLED]:  918 samples, 46 distinct   0x12C2..0x12C6 pil=0 ~=93%
```

Commands that COMPLETE sample into the same loop. On its own that is weak - one sample each, because
those commands finish almost immediately.

**The decisive row is `run`, and it needs no new measurement.** Section 158 established from the
interrupt counters that `run` saw `raises=0 delivered=0` - literally no octobus activity - because
`place-domain` never returned a prompt and `run` was typed into a monitor that was not listening. So
during `run` **nothing was asked of the machine at all**. And its histogram is the same five words at
the same ~93% concentration as `place-domain`'s.

**A window in which demonstrably nothing was happening produces a profile identical to the "hang".**
Therefore the profile is what the machine looks like when IDLE, not a signature of anything being
stuck. `0x12C2..0x12C6` is SINTRAN's idle loop, which is also why it is a five-word register-only
sequence ending in an unconditional `JMP -4` with no exit and no load - exactly what an idle loop is.

**What this VOIDS, stated plainly:**

 - **156** - "the hang has ONE location, identical for both domains". True and meaningless: the
   location is where the ND-100 always is when it has nothing to run.
 - **157** - the decode is right (the words really are those instructions, `JMP -4` really does
   target `0x12C2`), but every INFERENCE from it is void. It is not a delay loop waiting for an
   interrupt; it is idle. The hypothesis 158 refuted was built on a foundation that had already
   collapsed.
 - The `_hangPcSamples` instrument's own promise - *"a hung monitor command is a SINTRAN routine that
   never returns, and the only question worth asking is WHICH one"* - **only holds when the monitor
   SPINS.** When it is BLOCKED, the sampler shows the idle loop with total confidence and names
   nothing. Two hypotheses and three instrument builds went into that gap.

**The lesson is a specific, checkable one.** A profiler answers "where was the CPU", and that is only
the same question as "what is stuck" if the stuck thing is RUNNING. Before reading any PC histogram
as a culprit, run it over a window where nothing is wrong - if the profile is the same, the profile
is about the machine's resting state, not about the fault. That control cost one line
(`if (done >= 0) return;` was suppressing it) and would have saved sections 156 and 157 entirely.

**Where the hang investigation actually stands.** Nothing found so far names it. What is solid:
the ND-100 is alive and interrupted throughout (286 deliveries during the stall); answers are
delivered (`74/74`); the swapper started, answered MON 377B and idles; the ND-5000 sits in `WAIT`;
and the ND-100 is IDLE, not spinning. Every participant is healthy and waiting. **The question is
therefore not "who is stuck" but "what work should have been queued and was not" - and the PC
sampler is structurally incapable of answering that.**

## 160. Everyone is parked in an ND-100-OWNED wait state - and the MICFU trace disagrees with the MICFU census `[V]`

Following 159's reframing ("what work should have been queued and was not"), the mailbox chain walk
answers it more directly than any CPU-side instrument, because it is UNCAPPED and labels which SIDE
owns each state:

```
chain nodes visited: 217, not-answered: 153 (TAKEN-pending-stop: 2), served: 64
  @0x0042BE30 lastMICFU=0o0  : free=66        <- NEVER CHANGED for the whole run
  @0x00428E30 lastMICFU=0o5  : ToNd500=15 ANSWER=14 SWPWAIT(nd100)=1  SWPPING(nd100)=34
  @0x0042C130 lastMICFU=0o1  : ToNd500=49 ANSWER=2
  @0x00428D30 lastMICFU=0o23 : ToNd500=2  ANSWER=2  PSWWAIT(nd100)=32
```

**The two nodes that matter end up in states the ND-100 owns, not us.** The `3START` node (`0o23`)
spends 32 samples in **PSWWAIT**; the swapper node (`0o5`) spends 34 in **SWPPING** and one in
**SWPWAIT**. Both were served and answered first (`ANSWER=2` and `ANSWER=14`). Nothing is queued to
the ND-500 because, from the mailbox's point of view, the ND-500 has already done its part and the
ND-100 has not taken the next step.

That is the same conclusion 159 reached from the other end, by an independent instrument: every
participant is healthy, everything is waiting on the ND-100 side. **The question is now specific
enough to answer from the NPL sources rather than by running anything: what ND-100-side condition
clears `PSWWAIT` and `SWPPING`, and why is it not met.**

**A CORRECTION MADE MID-ANALYSIS, worth recording.** Reading the raw hop lines first
(`N5STA=0006`, `N5STA=0007`) I took them for undocumented states outside the documented set
{free=0, ToNd500=1, WAITING=2, ANSWER=3, 5ERANSWER=4} and was about to write up "two nodes parked in
unknown states that nobody ever services". The histogram above names them: 6 and 7 are
`SWPPING(nd100)` and `SWPWAIT(nd100)` - ordinary ND-100-owned wait states, correctly skipped by a
walk that only serves `ToNd500(1)`. **The raw view and the labelled view of the SAME data supported
opposite stories**, and the raw one came first because it was nearer the top of the dump.

**AN INSTRUMENT DISAGREEMENT, unresolved - do not build on either until it is settled `[OPEN]`.**
The MICFU census in the state line reports `micfu[1B:26 12B:1 23B:1 24B:1 31B:13]`, i.e. one `3START`
(23B) and one `3MONCO` (24B). The servicer MICFU **trace** over the same run contains only
`0x01` x50, `0x0A` x1, `0x19` x13 - **no `3START` and no `3MONCO` at all** - and 50 watchdogs where
the census counts 26. Two instruments over one run disagree about both WHICH functions ran and HOW
MANY. At least one is windowed differently than its heading claims. Any argument about the ORDER of
`3START` against the twelve DIT writes runs through the trace, so that argument cannot be made yet -
which matters, because that ordering is exactly what would explain the next item.

**Consequence for the THA fix, measured today.** `StartProcessFromContextBlock` now fills a zero
`THA` from the DIT (`if (regs.THA == 0 && regs.DitConfigured) LoadTrapConfigFromDIT(...)`, commit
5005b4a55), and the run above still reports **`THA=0x00000000`**. So the stated falsification -
*"THA must be non-zero after a completed 3START"* - **FAILS with the fix in the binary.** Either
`DitConfigured` is false, or the DIT still reads zero at start time because the twelve writes land
AFTER `3START`. Settling that needs the trace/census disagreement resolved first.

## 161. Why the THA fix is inert on this lane: the octobus DIT has NO declared base, deliberately `[V]`

Section 160 recorded a failed falsification - `StartProcessFromContextBlock` now fills a zero `THA`
from the DIT (commit 5005b4a55) and the run still reports `THA=0x00000000`. The cause needed no run
to find; it is written down in `ND100Machine.ND5000.cs` at the attach site:

> *"NO DIT BASE IS DECLARED HERE, AND THAT IS DELIBERATE. A previous version of this method called
> `cpu.DeclareDitBase(0)` ... The LAYOUT half of that is confirmed four ways and stands. The BASE
> half was wrong: PHYSRD/PHYSWR (30B/31B) are SEGMENT-RELATIVE, so those addresses are OFFSETS
> INSIDE A PHYSICAL SEGMENT, not physical addresses ... Declaring 0 measured THA=0 a second time."*

So on the octobus lane nothing ever sets `regs.DitConfigured`, and the new guard is
`if (regs.THA == 0 && regs.DitConfigured)`. **The condition is false, the load never runs, and THA
stays zero.** The fix is not wrong - it is correct and INERT here, for a reason already carved and
already written down. That is the third time a change has landed on this lane and changed nothing
because it was hooked to a path this lane does not take (section 121 hooked the same load to
cross-domain CALL; the same shape again).

**The twelve writes are at PCB offsets `0x96..0xC7` of a SEGMENT, not of physical memory.** The
resolution is in the servicer already - `TryResolvePhysicalSegmentAddress`:

```
    physicalByteAddress = (PST[segment] AND 0x3FFF) * 2048 + offsetInSegment
```

with the segment carried in `MSWMC` and the offset in `N500A`. So the DIT base is knowable, but only
from a live message - which is precisely why it cannot be declared at attach time.

**THE NEXT ACTION, and it follows the CORRECTION (section 125) rather than the mistake (115):**
resolve the DIT base at `3START` from the PST using the segment the start message names, then declare
it with `DeclareDitBase` - **never `SetupDIT`**, which zeroes every 256-byte PCB and would erase the
twelve fields SINTRAN had just written, reproducing `THA=0` and reading as "the fix did nothing"
rather than as a new bug. That hazard is already pinned by
`TestND500_DitBaseZeroIsAValidBase.DeclaringTheBase_DoesNotEraseATableTheGuestWrote`.

**Falsification, unchanged and now reachable:** `THA` must be non-zero after a completed `3START`.
The ordering question from 160 still has to be answered first - if the twelve DIT writes arrive
AFTER `3START`, no base resolution at start time can help and the load has to happen later. The
order-faithful MICFU log added this session is what answers it; it is built but has not yet produced
a run, because the shared tree was locked by another session's test at the time.

## 162. `THA=0` IS SINTRAN'S OWN VALUE. The whole THA hunt had a false premise `[V]` 2026-09-01

**Measured.** The servicer's copy-diagnostic ring, which records every octobus block copy with its
operands AND the 32-bit word actually moved, holds exactly thirteen entries for a complete run
(cap is 512, so nothing was truncated - the copy family ran thirteen times, full stop):

```
 0  WR a=0x4200BC b=0x42CC00 n=4 data=0x00000000     tos
 1  WR a=0x4200C0 b=0x42CC00 n=4 data=0x00000000     ll
 2  WR a=0x4200C4 b=0x42CC00 n=4 data=0x00000000     hl
 3  WR a=0x4200B6 b=0x42CC00 n=4 data=0x00000000     THA
 4  WR a=0x420096 b=0x42CC00 n=4 data=0x00000000     ote1
 5  WR a=0x42009A b=0x42CC00 n=4 data=0x00000000     ote2
 6  WR a=0x42009E b=0x42CC00 n=4 data=0x00000000     cte1
 7  WR a=0x4200A2 b=0x42CC00 n=4 data=0x00000000     cte2
 8  WR a=0x4200A6 b=0x42CC00 n=4 data=0x00000000     mte1
 9  WR a=0x4200AA b=0x42CC00 n=4 data=0x00000000     mte2
10  WR a=0x4200AE b=0x42CC00 n=4 data=0x00000000     temm1
11  WR a=0x4200B2 b=0x42CC00 n=4 data=0x00000000     temm2
12  WR a=0x4200A6 b=0x42CC00 n=4 data=0x00000000     mte1 again
```

**Every one of the thirteen writes carries ZERO**, including the one at `0x4200B6`, which is
ND-500 physical `0xB6` = the PCB's `tha` field. `data` is read back from the DESTINATION after the
copy, so it is the value that landed, not a guess about the source.

So `THA == 0` after a completed `3START` is **the guest's own value, faithfully delivered**. The
falsification stated in `PLAN.md` - *"THA should be non-zero after a completed 3START"* - was never
a valid test. It asserted a value SINTRAN does not write.

### Why the addressing is trustworthy here

Both sides of the copy resolve the same way (`Nd500AddressBase + addr`). The ND-500 side is
independently corroborated: the thirteen `a` addresses land EXACTLY on the documented trap-config
layout - `96 9A 9E A2 A6 AA AE B2 B6 BC C0 C4` - which is a twelve-way coincidence if the rule were
wrong. The `b` side uses the identical rule, so a zero read there is a zero in the buffer.

### A SECOND, INDEPENDENT INSTRUMENT AGREES - on the source side

The copy ring reads the DESTINATION after the copy. A separate instrument in the same run watches
the SOURCE buffer, and it agrees:

```
PHYSWR source-buffer writes [0x42CBF0..0x42CC40): 5168 total, 0 NON-ZERO, last non-zero (none)
```

Five thousand one hundred and sixty-eight writes into the buffer SINTRAN feeds these copies from,
and **not one of them was non-zero**. Two instruments on opposite ends of the same transfer, neither
derived from the other. Per taxonomy #7 - a single number can only be believed, never checked - this
is the second count that had to agree, and does.

### There are NO read-backs

The ring holds thirteen `WR` and zero `RD`. The `octobus-nd5000` skill's line *"start-swapper
performs a write-then-read-back VERIFY of 13 words ... which COMPLETES AND PASSES"* does not match
this run: nothing reads them back. Whatever that sentence measured, it was not this sequence.
Treat the "verify" framing as unconfirmed.

### What the three wrong turns cost, recorded so they are not repeated

The DIT-base work itself is correct and is now live - but it took three wrong placements, and all
three are the SAME mistake, which is the thing worth keeping:

1. **Instrumented the classic `PHYSWR` arm** of the MICFU switch. Measured `pwSeen=0` while the
   census counted `31B:13`. The generation split at the top of that case routes the whole copy
   family to `PerformOctobusBlockCopy`; the segment-relative PST-walking code below it is the
   CLASSIC ND-500 path only.
2. **Put the declaration in `OnStartProcess`.** Measured `ditCfg=False` with the guard satisfied.
   The servicer calls `OnStartProcessND5000` (`Nd500MicrocodeServicer.cs:3192` ->
   `Nd500CpuProcessBridge.cs:777`); `OnStartProcess` is the classic twin and is DECLINED on this
   lane - the bridge's own header says so.
3. **Guarded on `ObservedDitBase != 0`.** The correct base on this lane IS zero, so the guard
   skipped in exactly the case it was written to serve. Guard on the write COUNT.

**THE PATTERN: in this servicer/bridge pair every ND-5000 path has a classic ND-500 twin sitting
next to it, and the classic one reads like the only one.** Before instrumenting or editing any
handler here, confirm which of the two the octobus lane actually executes.

### What IS fixed, stated exactly

`DitConfigured` was `false` for the whole life of an octobus run, so every `ReadDIT_*` returned 0
and logged a warning. It is now `true`, learned from the thirteen trap-config writes and declared
in the start path the lane really takes (`ditW=13`, `ditCfg=True`, `DITBASE=0x00000000`). That is a
real gap closed. **It does not change `THA`, and it does not move the stall.** Reporting it as
progress on the hang would be false.

### Where this leaves the hang

Nowhere new. Section 159 still stands: every participant is healthy and parked, and the open
question is what work should have been QUEUED and was not. `THA` is now removed from the candidate
list - it is not a defect.

## 163. Reading the stall run for what work was never queued - and the one number still missing `[V]` except where marked

Working section 159's question against the run that produced 162. Everything here is read out of
that run's own dump; nothing is inferred from a fresh guess.

**Read the `place-domain` subsection below before using anything in this section.** It shows that
one monitor command silently ran a whole bring-up ladder inside its own window, which changes what
the per-command instruments here are actually measuring.

### The swapper is parked BY DESIGN, and the instrument says so itself

```
MON restart path -----  posted=2 seen=1 taken=1
swpfu[LNEWSWAP:2]   restarts=1/1   ansMON=377B   stopMode=WAIT
```

Two monitor-call stops posted, one restarted and taken, one still parked. The parked one is the
SWAPPER on `LNEWSWAP`, and that is the designed idle: with nothing to do it answers the served node,
marks `SWMSG` `PSWWAIT` and returns to the message loop WITHOUT restarting the swapper - which is
later woken by `5ACTSWAPPER` when work arrives (`MP-P2-N500.NPL:135470`, `SWPD4` at `135747`).
So "the swapper is idle" is not the fault. **The fault is that nothing ever wakes it.**

### `5ACTSWAPPER` fires exactly once, and the FIFO is never used

```
call:MSWSWAIT-tail         @0o134354  hits=0
bail:NOT-BSWSTARTED        @0o135551  hits=0
call:TRAPDECODER-pagefault @0o135567  hits=0
call:SWPD4-fifo-drain      @0o136237  hits=1
call:SWMC-mon510           @0o142165  hits=0
5ACTSWAPPER-entry          @0o145162  hits=1
HANDOVER-taken-SWACTIVE    @0o145211  hits=1
queued-on-swapwait-fifo    @0o145312  hits=0
INVARIANT callers=1 entry=1 outcomes=1 (bailed=0)  [consistent]
```

One call, one entry, one handover, zero bails - self-consistent, so the instrument is not lying to
itself. **Nothing was EVER queued on the swap-wait FIFO.** Of the five call sites, the four that
would represent real work - a page fault (`TRAPDECODER-pagefault`), a MON 510 (`SWMC-mon510`), the
`MSWSWAIT` tail - never fired at all.

### Nothing page-faulted, and that absence is meaningful here

```
page-fault records posted: 0        ring: EMPTY
TRAPS BY CONDITION (whole run): none
demand segments built=0  growable pages mapped=0  data capabilities cleared=0
no MICFU was ever answered 5ERANSWER in this run
```

Per taxonomy #11b, PGF is **FATAL class** (bit 38) - not disableable - so a page fault could not have
happened invisibly. The zero is real: nothing faulted, therefore nothing asked the swapper for a
page, therefore the swapper correctly slept. This chain is consistent end to end, which is the
uncomfortable part: **every component is behaving correctly and the work simply never exists.**

### `run` sent the ND-5000 NOTHING but watchdogs - measured by delta

The two census points bracket the `run` command exactly:

```
[after PLACE-DOMAIN] micfu[1B:21 12B:1 23B:1 24B:1 31B:13]   msgs=37
[after RUN]          micfu[1B:38 12B:1 23B:1 24B:1 31B:13]
```

`1B` (3RMICV, the WATCHDOG) climbs 21 -> 38. **Every other count is unchanged.** So the whole `run`
command - which STALLED - issued not one non-watchdog message to the ND-5000. Whatever `run` is
waiting on, it is waiting for it BEFORE the transport is involved.

### THE SAME CLAIM FOR `place-domain` IS NOT ONLY UNMEASURED - THE CONSOLE SAYS IT IS PROBABLY FALSE

There is no census point before `place-domain`, so its delta cannot be taken the way the `run` delta
can. I was about to infer it from how the watchdogs interleave. **Reading the console instead
inverted the answer.**

```
ND-5000: define-swap-file
File name: swap-file:data

ND-5000: place-domain cpu-stat

> Loading Control Store
INFO    * 0B:6B * 1998-09-01 10:35:48 * BAK01.37603B
          SINTRAN III File System
          Not used

> Loading Swapper
```

**`place-domain` is what triggers the control-store load and the swapper load.** The test is
`ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture` - it issues **no** `load-control-store` and
**no** `start-swapper`. Those two lines are the nd-500-mon **ECSLOAD auto-retry gate**: `RSTA5` bit 9
`5CLOST` set -> the driver returns `2032B` -> the monitor prints `Loading Control Store`, loads
`(SYSTEM)CONTROL-STORE:DATA`, and retries.

So the thirteen `PHYSWR`, the `3START` and the `3MONCO` are almost certainly INSIDE the
`place-domain` window, not before it. `place-domain` does not send nothing - it sends everything in
the run.

**Graded [D] pending the stamped run**, which now labels every observed message with the outstanding
command and settles it by measurement.

**And the lesson is the harness's command labels, not the machine.** The label says which command was
typed; it does not say what that command DELEGATED to. A single monitor command silently ran a whole
bring-up ladder inside its own window, and every per-command instrument in this file inherits that
blindness. Cf. taxonomy #19 - correct about the wrong object: the counts were right, the thing they
were attributed to was not.

### THE FILE-SYSTEM ERROR IN THE MIDDLE OF THE LOAD - stop calling this noise

```
INFO    * 0B:6B * 1998-09-01 10:35:48 * BAK01.37603B
          SINTRAN III File System
          Not used
```

It fires BETWEEN `Loading Control Store` and `Loading Swapper` - i.e. DURING the auto-load ladder
that the stalled command triggered. `Not used` is SINTRAN's text for an error code with no assigned
message, so the file system returned error `6B` and SINTRAN had nothing to print for it.

This is the error the standing rule says to root-cause rather than step over
([[fix-known-bugs-before-hunting-features]]: *"dont dismiss error as noise"*, *"all bugs are to be
root caused and fixed"*). It sits UPSTREAM of everything section 159 was asking about: if the
auto-load ladder failed part way, then the swapper idling with an empty FIFO and the monitor never
resuming `place-domain` are both DOWNSTREAM consequences, and neither is measurable until this is
settled. `BAK01.37603B` names the reporting site and is the place to start.

### What the PC histogram DOES say once you stop asking it to localise

Section 159 retired this instrument for localisation, and rightly. But the shape of the sample is
still evidence:

```
place-domain cpu-stat [STALLED]: 639 samples, 58 distinct (PC,PIL)
    PC=0x12C2..0x12C6 pil=0   576 samples   <- the IDLE loop
    PC=0x7E78/0x7E79/0x7E7B/0x7E83 pil=1     11 samples
    PC=0x4BA2 / 0x4730 pil=1, 0xEA4 pil=2     4 samples
```

**Nine of ten samples are the ND-100 sitting in its idle loop at `pil=0`.** A command that was
spinning would be at its own PC; a command whose process is not scheduled at all looks like this.
So `place-domain` is not burning cycles - it is BLOCKED, waiting on an event, and SINTRAN is idle
because there is nothing else to run.

That reframes section 159's question one level more precisely:

> Not "what work should have been queued for the swapper", but **"what event is the place-domain
> process blocked on, and who was supposed to post it?"**

The swapper's empty FIFO is then a CONSEQUENCE, not the cause - the same shape as the THA hunt in
162, where the value everyone was chasing turned out to be correctly delivered.

## 164. MEASURED: `place-domain` owns every non-watchdog message. And the `0B:6B` watch fired without discriminating anything `[V]` 2026-09-01

Run with `RETROCORE_ND5000_WATCH=fs6b`, filtered to the single test (see the wrong-turn note at the
end - the earlier run was filtered on the whole CLASS and spent 33 minutes in a different test).

### The `[D]` in section 163 is now `[V]`

Every observed mailbox message, stamped with the monitor command outstanding when it arrived:

```
22 [place-domain cpu-stat ] MICFU=0x01 3RMICV(1)     watchdog
16 [run                   ] MICFU=0x01 3RMICV(1)     watchdog
13 [place-domain cpu-stat ] MICFU=0x19 PHYSWR(31B)
 1 [place-domain cpu-stat ] MICFU=0x14 3MONCO(24B)
 1 [place-domain cpu-stat ] MICFU=0x13 3START(23B)
 1 [place-domain cpu-stat ] MICFU=0x0A CACHE(12B)
```

**Every non-watchdog message in the run belongs to `place-domain cpu-stat`** - the cache clear, the
thirteen trap-config writes, the process start and the monitor call. `run` contributes sixteen
watchdogs and nothing else. No message is attributed to any earlier command, including `@nd-500`
itself: entering the monitor performs the control-store download over the ACCP (LOCSD/LOCSM), which
carries no MICFU, so zero there is correct rather than missing.

This closes the question section 163 opened and confirms its correction: `place-domain` does not
send nothing - it sends everything.

Reproduced unchanged in this run: `THA=0x00000000 ditCfg=True DITBASE=0x00000000`,
`OUTCOME: nd-500=OK place-domain=STALL run=STALL`, and the same file-system line at the same
address, one second later in the boot:

```
INFO    * 0B:6B * 1998-09-01 11:37:46 * BAK01.37603B
```

### The `0B:6B` watch: a working instrument that answers the wrong question

```
S3FS ctx@0o37570               @0o37560  hits=849
S3FS compare@0o37577           @0o37577  hits=155
S3FS REPORTED@0o37603 JPL I 34 @0o37603  hits=155
S3FS sibling@0o37613 JPL I 24  @0o37613  hits=1
S3FS exit-A@0o37624            @0o37624  hits=506
S3FS exit-B@0o37630            @0o37630  hits=2
S3FS target@0o50124            @0o50124  hits=4577
CONTROL 5ACTSWAPPER@0o145162   @0o145162 hits=2
```

The liveness control fired (`5ACTSWAPPER hits=2`), so the watch itself works and the other numbers
are real. **And that is exactly what makes the result useless for the question asked of it.**

`0o37603` - the address SINTRAN names in the error - executes **155 times**, while the message
prints **ONCE**. So the reported address is a HOT LOOP CALL SITE, not a rare error path, and "did
0o37603 execute" cannot separate the one failure from 154 healthy calls. That is taxonomy **#8**: a
number that cannot be RELEVANT to the question, as distinct from #7 (a number that cannot be
checked). The instrument is correct, believed, reproducible - and blind.

**What that DOES establish, and it is worth having:** the error is not "this site was reached". It is
"this call RETURNED a failure on one of 155 calls". Any next instrument must watch the RETURN, not
the entry - the A register at `0o37604`, which the disassembly shows being stored at `0o37630`
(`STA ,B 2`) on the error path that ran twice.

Two arms also refuse to be read as S3FS at all: `0o50124` at 4577 hits and `0o37624` at 506 hits
both exceed their own callers, which is only possible if other code executes at the same 16-bit
virtual address. The watch matches the PC and nothing else, exactly as its own doc comment warned.

### WRONG TURNS - do not repeat

**1. I typed one arm's address in octal and armed it in hex, wrongly.** `0o37570` is `0x3F78`; I
armed `0x3F70`, which is `0o37560`. The table shows `S3FS ctx@0o37570 @0o37560` - the LABEL I typed
beside the OCTAL OF WHAT WAS ACTUALLY ARMED, and they disagree.

**The only reason this was caught is that the dump prints the armed value decoded, not the name.**
Had it printed my label, the run would have reported hits for an address it never watched, and
849 hits is a number nobody would have questioned. **Every instrument that takes an address should
print that address back, decoded in the radix the source uses.**

**2. I filtered the test run on the CLASS, not the test.** The first attempt ran every test in
`Nd100SintranNd5000OctobusBootHarnessTests`, sat for 33 minutes in the full-ladder test with each of
its commands stalling its whole timeout, and never reached the one I wanted. The breadcrumb file
(`%TEMP%\retrocore-nd5000-octobus\octobus-breadcrumb.txt`) named the running command outright and is
the right thing to read when a run is slower than expected - CPU time only says it is progressing,
never at WHAT. Filter on the test name.

## 165. The MON 60 retry DOES happen - and the S3FS localisation in 163/164 does not survive its own instrument `[V]` / `[OPEN]` 2026-09-01

`RETROCORE_ND5000_WATCH=mon60`, single test, same pack and windows. Liveness control fired
(`5ACTSWAPPER hits=2`), so the table is real.

```
MON60 gateway@0o146256   hits=5
ECSLOAD catch@0o146263   hits=3
CS loader@0o177152       hits=0
RUNSW MSWSTART@0o163725  hits=1
S3FS call@0o37603        hits=155
S3FS RETURN A=@0o37604   hits=155
S3FS error-store@0o37630 hits=2
CONTROL 5ACTSWAPPER      hits=2
```

### What is settled: the retry is not the problem

**MON 60 was entered five times and the ECSLOAD arm three times.** Gateway hits exceed catch hits,
and the time-ordered log shows the alternation directly:

```
MON60 gateway hit#1  A=272o
ECSLOAD catch hit#1  A=2166o
MON60 gateway hit#2  A=365o
MON60 gateway hit#3  A=1312o
ECSLOAD catch hit#2  A=2113o
MON60 gateway hit#4  A=2064o
```

So the command IS re-issued after the auto-load - repeatedly. The hypothesis this watch was built to
test ("the retry never fires") is **REFUTED**. Whatever blocks `place-domain`, it is not a monitor
that forgot to retry.

`A=2064o` at gateway hit#4 sits inside the documented ND-500 monitor error range `2000B..2100B`,
which is worth following; `2166o` and `2113o` at the catch do not, and neither is `2032B` (ECSLOAD).
Naming any of them is `[OPEN]` - the A register at a routine's entry is not necessarily its status.

`CS loader@0o177152 hits=0` is consistent with the octobus lane downloading the control store over
the ACCP (LOCSD/LOCSM) rather than through the classic 3022 loader, so a zero is expected rather
than missing. `[D]` - the arm was never independently shown to be the right address.

### WHAT DOES NOT SURVIVE: the S3FS attribution in sections 163 and 164

The register log makes two things plain that the hit COUNTS hid.

**1. The two `error-store@0o37630` hits happen BEFORE the monitor is ever entered.** They are the
first two entries in the time-ordered log, ahead of `MON60 gateway hit#1`:

```
S3FS error-store hit#1 PIL=3 A=0o      L=37627o
S3FS error-store hit#2 PIL=3 A=177777o L=37627o
MON60 gateway    hit#1 PIL=1 A=272o
```

The `0B:6B` message prints AFTER `place-domain` is typed, which is long after the first monitor
entry. **So these two hits are not the reported error.** Section 164 proposed watching `0o37630`
because it "ran twice in a run where the message printed once" - a coincidence of counts, and
nothing more. `A=177777o` (-1) is a real return value of something, but not of the thing being
hunted.

**2. `0o37603` executes at PIL=12 and PIL=1 with an identical register signature every time.**

```
S3FS call@0o37603 hit#1  PIL=12 A=20000o D=124226o T=124612o X=124612o B=123537o L=0o
S3FS call@0o37603 hit#10 PIL=1  A=20000o D=124250o T=124612o X=124612o B=123537o L=0o
```

`A=20000o` on all 26 logged hits, `L=0` throughout, and PIL 12 - the ND-500/octobus DRIVER level.
That is not a background file-system call. It is a tight loop in driver-level code that happens to
occupy the same 16-bit virtual address, which is precisely the aliasing every arm-set comment in
this file warns about and which I nonetheless read past twice.

**Therefore the claim "`0o37603` is inside `006-S3FS`, so the error is in the file system" is
WITHDRAWN.** What is true is narrower: `0o37603` FALLS INSIDE the address range that segment
006-S3FS occupies. Whether the code executing there when SINTRAN printed the message was S3FS is
**[OPEN]**, and a PC-only watch cannot decide it - the instrument would need the page table or the
running segment at the hit.

### The rule this cost three instruments to learn

Three watches have now been aimed at `0B:6B` and none discriminated:

 - entry hits (164) - 155 executions for one message.
 - return value (165) - the arm fires before the message exists.
 - the error-store arm - matched on a count coincidence, at the wrong level entirely.

**An address that lies within a segment's range is not evidence that the segment's code ran there.**
Segment membership is a claim about the address map; execution is a claim about a moment. Those are
different objects, and conflating them is taxonomy #19 in its purest form - every number was right,
and the thing they were attributed to was not.

### And the error is still not shown to matter

Independently of localisation: `0B:6B` prints once, between `> Loading Control Store` and
`> Loading Swapper`, and **both loads then succeed** - the swapper starts and answers MON 377B
(`startMessagesSeen=1`, `RUNSW MSWSTART hits=1`). It appears in all five short-bring-up runs, every
one of which stalls, so the correlation is perfect and worthless: there is no run in this lane where
`place-domain` completes, hence no negative case to compare against.

**Stop instrumenting this error until a working instance exists.** It is not demonstrably upstream of
anything; it was promoted on the strength of being the only error visible in the transcript.

## 166. RETRACTION: `A=2064o` was never a status. And two carved sources disagree about MON 60's return polarity `[V]` code, `[OPEN]` polarity

### Retracting section 165's one "unexplained value"

Section 165 said `A=2064o` at the fourth gateway entry "sits inside the documented ND-500 monitor
error range `2000B..2100B`, which is worth following". **It is not a status, and that observation is
withdrawn.**

The gateway's real code (`nd-500-mon-j04.prog.asm`, bank 1) says what A is at that instruction:

```
146244  RADD AD1 CLD SL DX          <- gateway entry
146245  JPL I 34        -> 146301
146250  STA ,B -157                 building the parameter block
146253  STA ,B -173
146255  AAA -173                    A := address of the parameter block
146256  MON 60                      <- my "gateway" arm
146257  JMP 2           -> 146261
146260  JPL I 23        -> 146303
146261  STA ,B -160                 store the returned A
146262  LDA ,B -160                 read it back
146263  LDT 21                      <- my "ECSLOAD catch" arm
146264  SKP IF DA UEQ ST            compare the status against a constant
```

`146255 AAA -173` sets A to the ADDRESS of the parameter block immediately before the `MON`. So
`272o`, `365o`, `1312o`, `2064o` are **parameter-block pointers**. `2064o` falling inside an error
range is a coincidence of numeric range - the exact class of mistake section 165 was written to
record, made again in the same section. Numbers do not carry their own units.

### What the arms DID measure - better than intended

`146263` is not an "ECSLOAD catch". It is `LDT 21`, the first half of a compare, reached only via
`146257`. Its value is that A there has just been reloaded from the saved return (`146261`/`146262`),
so **A at that arm IS the returned status**: `2166o` and `2113o` on the two logged hits, of three.

Neither is `2032B` (ECSLOAD) nor `4017B` - the two codes the gateway auto-retries on, held as
constants at `146304` and `146305`. So the retries counted in 165 were **not** ECSLOAD retries.

### THE POLARITY CONFLICT - do not resolve it by picking the source you like

Two carved sources disagree about which arm of `MON 60` is which, and the disagreement decides
whether "3 of 5" means three successes or three failures:

 - **`mon60-callers/INDEX.md`**: *"`JMP 2` = skip return (success) or `JPL I 23` = error"* - making
   `146257` success and `146260` error.
 - **the `nd-500-bus-interface` skill**, marked byte-PROVEN and itself a correction of an earlier
   inversion: *"SKIP (P+2) = success/A=0; DIRECT (P+1) = error/A=status"* - making `146260` (P+2)
   success and `146257` (P+1) error.

They cannot both be right. **The code favours INDEX.md**: the ECSLOAD constants sit at `146304` and
`146305`, inside the routine reached by `JPL I 23` -> `146303`, so the auto-retry logic lives on the
`JPL I 23` branch, which makes that branch the ERROR branch and `JMP 2` the success branch. That in
turn means `MON 60` SKIPS on error, contradicting the "byte-PROVEN" note.

**Left `[OPEN]` deliberately.** One of these is a documented, deliberate correction of a previous
inversion, and overturning it on a structural argument is how the inversion got introduced the first
time. It is settled by measurement, not by argument: arm `146257` and `146260` separately along with
the error handler at `146303` and the two constants, and count. Whichever branch reaches `146303`
is the error branch, and no reading of either document can override that.

Until it is settled, **no count taken through either arm should be described as successes or
failures** - including section 165's "MON 60 entered five times, ECSLOAD arm three times", which is
true as a pair of counts and unlabelled as to meaning.

## 167. MON 60 polarity SETTLED from the bytes: P+1 IS the error return. `mon60-callers/INDEX.md` is wrong `[V]` 2026-09-01

Section 166 left the polarity `[OPEN]` and said only a run could settle it. That was too pessimistic
- reading the gateway with ND-100 **P-relative addressing** applied settles it outright, no run.

```
146256  153060  MON 60
146257  124002  JMP 2        -> 146261
146260  135023  JPL I 23     -> [146303]
146261  004620  STA ,B -160        save the returned A
146262  044620  LDA ,B -160        read it back
146263  050021  LDT 21             T := mem[146263+21] = mem[146304] = 002032B  ECSLOAD
146264  142065  SKP IF DA UEQ ST   skip when A is NOT ECSLOAD
146265  124004  JMP 4        -> 146271
146266  050017  LDT 17             T := mem[146266+17] = mem[146305] = 004017B
146267  140065  SKP IF DA EQL ST
146270  124007  JMP 7        -> 146277
146271  054602  LDX ,B -176        the MON 60 parameter block
146272  006006  STA ,X 6
146273  135013  JPL I 13
146274  135013  JPL I 13
146275  124357  JMP -21      -> 146254   <-- BACK TO JUST BEFORE THE MON
146277  135010  JPL I 10
```

**`146275 JMP -21` lands at `146254`, two words before the `MON 60` at `146256`. That is the retry
loop, and it is reached only from `146257` = P+1.** The path from P+1 saves the returned A, compares
it against `002032B` (ECSLOAD) and `004017B`, and re-issues the call when it matches either.

So **P+1 (DIRECT) is the error return carrying the status in A, and P+2 (SKIP) is success.** The
`nd-500-bus-interface` reference is RIGHT and `mon60-callers/INDEX.md` is WRONG where it says
*"`JMP 2` = skip return (success) or `JPL I 23` = error"*. `JMP 2` sits AT P+1; calling it "the skip
return" is the error. INDEX.md has been annotated in place.

### The reading that unlocks it, and that I had been getting wrong all session

The disassembler's `; -> nnnnnn` arrow is **`EA = P + displacement`**, not a jump target. For
`JPL I` the machine then jumps to the CONTENTS of that address. So:

 - `146263 LDT 21` loads T from `146304` - which is why the ECSLOAD constant is "at 146304". It is
   an operand of an instruction 21 words earlier, not a routine.
 - `146260 JPL I 23 -> 146303` jumps to `mem[146303] = 177335`, **not** to `146303`.

### WHICH KILLED THREE ARMS OF THE WATCH I HAD JUST WRITTEN

`ArmMon60PolarityWatch` armed `0o146303`, `0o146304` and `0o146305` as "ERROR handler" and the two
constants. **All three are DATA WORDS.** They can never be executed, so all three would have read
`hits=0` in a table whose liveness control passed - three confident zeros about addresses that are
not code. The real error handler is at `177335`; the constants are operands and have no meaningful
hit count at all.

This is the pointer-word trap that this file already records at `0o163720`, `0o104016` and
`0o37632`, and I walked into it a fourth time - while writing the comment that cites the other three.
**Writing down the objection is not obeying it.** The mechanical guard: before arming any address,
check whether the disassembly line at that address is an instruction or an operand of one nearby.

### What this does NOT settle - section 165's counts stay unlabelled

With the polarity known, `MON60 gateway hits=5` and `status-compare hits=3` means **three of five
MON 60 calls returned an error**. But the two statuses captured, `2166o` and `2113o`, are neither
`2032B` nor `4017B`, so both took `146270 JMP 7` -> `146277` - the NON-retry path. The third status
was outside the 60-entry log window.

So the honest position is narrower than 165's: the gateway has a working retry loop, and the two
errors we actually SAW did not use it. Whether any retry fired needs the corrected arms
(`0o146271` retry vs `0o146277` no-retry) and the full status list. That is a measurement, and it is
queued behind the shared build tree.

## 168. The polarity was ALREADY CARVED - and the same document hands over the sharpest question yet `[V]` 2026-09-01

### I re-derived a documented answer

`nd-500-mon-j04.prog.md` section **5.4, "Skip/direct polarity - the task premise was inverted"**,
already contains section 167's conclusion, reached by a different route:

> `146257` (`P+1`) = the **DIRECT / ERROR** path [...] `146260` (`P+2`) = the **SKIP / SUCCESS** path
>
> confirmed from the other end by the SINTRAN handler source - `5P-P2-MON60.NPL:2247` (`5OKRET` does
> `MIN ZPREG`, incrementing the caller's saved P = skip return, and sets `ZAREG := 0`), while `ERET`
> at `:1307` stores the error code into `ZAREG` and falls through **without** `MIN ZPREG`.

Two independent derivations agreeing - mine from P-relative operand decoding on the ND-100 side,
theirs from the NPL handler on the SINTRAN side - is stronger evidence than either alone, so 167
stands. But the honest note is that **it did not need deriving.** `CLAUDE.md` says it outright:
*"READ THE DEEP DIVE FIRST, IT PROBABLY ALREADY ANSWERS IT."* The relevant section was two lines
below `5.3 The gateway, verified byte-for-byte` in the same file I was already reading, and its
heading names the exact question.

It also records that the inversion is in **three** places, not one: the task brief, `INDEX.md`, and
`ND500-BUS-INTERFACE-REFERENCE.md` section 11. The `nd-500-bus-interface` SKILL already carries the
correction (*"byte-PROVEN, bus-ref section 11 had it inverted"*), which is why the skill and
INDEX.md disagreed in section 166. Neither was a fresh error; one had been fixed and the other had
not.

### The finding that matters: THE RETRY LOOP IS AN UNCONDITIONAL BUSY-SPIN

Section 5.6 carves the retry hook at `132170` - the routine called from `146273`, inside the retry
arm - and finds it is a six-word stub that allocates a one-word frame, ignores the error code, and
unconditionally takes the skip return. Consequences it states:

 - `132170` always returns to `146275` = `JMP -21` = **retry**.
 - `146274` and `146276` are **unreachable** - the compiler's dead "else" arms.
 - **the retry loop is a tight busy-spin** on `002032B` / `004017B` until the status changes.

### Which turns the stall into a sharp, falsifiable question

A busy-spin would show as thousands of gateway executions and an ND-100 pinned in the gateway.
**We measured neither.** `MON60 gateway hits=5`, and 90% of the PC samples during the stall are the
ND-100 IDLE loop at `pil=0` (section 163). So the gateway is NOT spinning, and ECSLOAD is not the
blocker.

Combine that with the polarity now known:

```
gateway executions (0o146256)   = 5
error returns      (0o146263)   = 3      P+1, status in A
success returns    (0o146260)   = ?      P+2      NOT YET MEASURED
```

**If error returns plus success returns is LESS than gateway executions, then a MON 60 was issued
and never came back** - the monitor is blocked INSIDE SINTRAN's handler, which is exactly what "the
process is not scheduled and the machine is idle" looks like from the outside. If they balance, the
command returned every time and the block is after the last return, somewhere in the monitor's own
code.

Those two have opposite implications and one subtraction separates them. **The corrected polarity
watch already arms both return arms** (`0o146257` and `0o146260`) alongside the gateway, so the run
that was queued for a question now answered will answer this one instead - at no extra cost.

This is the sharpest the stall question has been: not "what work was never queued" (159), not "why
does the retry not fire" (165, refuted), but **"did the last MON 60 ever return?"** - answerable by
subtraction, from three counters, in one run.

## 169. The `> Loading ...` messages are SINTRAN's, not the monitor's - and the console stops one milestone short `[V]` 2026-09-01

Read-only carve while the build tree was lent out. Method: decode the actual bytes in order and read
what is there, rather than searching for what I expected.

### The three messages are a SEQUENCE, and we only ever see two of it

Around the strings in the image, in layout order:

```
$> Loading Control Store'   (SYSTEM)CONTROL-STORE:DATA'   (SYSTEM)CONTROL-1-STORE:DATA'
$> Loading Swapper'         (SYSTEM)SWAPPER'
$> Allocating memory'       ... ' pages'
```

Our console prints the first two and **never `> Allocating memory`**, on every run. So the stall
sits between "the swapper is being loaded" and "memory is being allocated for it" - a milestone
boundary, established without any instrument.

Note this is NOT contradicted by the swapper having started: the run does reach `3START` and the
swapper answers MON 377B (`startMessagesSeen=1`). Whatever `Allocating memory` covers, it is not a
precondition for that - which makes the missing message more interesting, not less.

### They are in `(SYSTEM)SEGFIL0:DATA` - a SINTRAN SEGMENT

Checked by extracting **all 95 files** from `D:\DOMS-CSFIX.IMG` and searching every one, rather than
guessing:

```
FILES CONTAINING THE MESSAGES: [('SYSTEM\SEGFIL0.DATA', 16748544)]
  Loading Control Store  588719 (0x8FBAF, page 287) and 2542511 (page 1241)
  Loading Swapper        588227 (0x8F9C3, page 287) and 2542019, 4953893
  Allocating memory      588367 (0x8FA4F, page 287) and 2542159
```

All three sit within ~500 bytes of each other on **page 287**, i.e. in one routine, and there is a
second complete copy on page 1241 (a second segment or a backup generation).

### CORRECTION to the `nd-500-bus-interface` skill

The skill states:

> the driver returns **ECSLOAD 2032B** -> **nd-500-mon prints "Loading Control Store"**, auto-loads
> `(SYSTEM)CONTROL-STORE:DATA` [...] and retries.

**The nd-500-mon program does not contain that string.** Checked three ways:

 - carved `nd-500-mon-j04-bank1.bin` - no `Loading`, no `CONTROL-STORE`, no `SWAPPER`.
 - carved `nd-500-mon-j04-bank2.bin` - has `CONTROL-STORE` and `SWAPPER` as FILENAMES, but no
   `Loading` and no `Allocating`. (Its `Swapper` hit is the STATUS report label
   `$Swapper.......: `, a different thing entirely - the sort of match that looks like a find.)
 - the pack's own `(SYSTEM)ND-500-MON-J:PROG`, extracted and searched - none of the three.

So the monitor knows the FILENAMES it will ask for, and SINTRAN prints the progress messages and
does the loading. The attribution matters because it decides which side to instrument: a PC watch in
the monitor's address space can never see this code.

### What this does NOT change

Section 168's subtraction is still the next measurement, unaffected: gateway executions = 5, error
returns = 3, success returns unmeasured. If they do not balance, a `MON 60` never returned - and
"never returned" is now given a place to be, since the printing code is SINTRAN-side and is exactly
the sort of code a `MON 60` handler would be executing while its caller waits.

## 170. The stall region has a NAME: the messages are in `S3SM5`, and `> Loading Swapper` lives in `CHSWL` `[V]` addresses, `[D]` meanings

Continuing 169 while the build tree was lent out. The messages are not just "in a SINTRAN segment" -
they are in **`030-S3SM5`**, the ND-500 System Monitor segment, which is the one segment already
fully disassembled with a routine map and a Ghidra symbol table.

Found by testing every carved segment binary rather than guessing which one:

```
030-S3SM5.bin    98304  ['Loading Control Store', 'Loading Swapper', 'Allocating memory']
062-S3SSM5.bin   98304  ['Loading Control Store', 'Loading Swapper', 'Allocating memory']
```

(`062-S3SSM5` is the second copy seen at image page 1241 in section 169 - a twin segment, not a
second routine.)

### The addresses, with the unit conversion done correctly

The routine map states the convention: `runtime_word = file_word + 0x4000`. Applying it:

| message | file byte | runtime word | octal | falls inside |
|---|---|---|---|---|
| `> Loading Swapper` | 29123 | `0x78E1` | `0o74341` | **`CHSWL` `0x78D8`** (next symbol `LIICO 0x78F9`) |
| `> Allocating memory` | 29263 | `0x7927` | `0o74447` | **`KGPIB` `0x7924`** (next symbol `SGPBS 0x7937`) |
| `> Loading Control Store` | 29615 | `0x79D7` | `0o74727` | at/after `TERMO 0x79A3` |

**So the console dies between `CHSWL` and `KGPIB`.** `CHSWS 0x7907` (`0o74407`) sits between them and
is the obvious next step in the path.

There is a naming family - `CHSWF 0o74161`, `CHSWL 0o74330`, `CHSWS 0o74407` - which reads as
CHeck-SWapper-something. **The expansions are `[D]` and I am not asserting them**; the addresses and
the containment are `[V]`, and that is all the next instrument needs.

### A units error I made and caught inside the same tick

I first read symbol `LOAD 0x7201` as "between the two strings" because `0x7201` is numerically
between the string FILE BYTE offsets `0x71C3` and `0x724F`. It is not: symbol values are RUNTIME
WORDS and the string offsets were FILE BYTES. `LOAD` is at file byte `2*(0x7201-0x4000) = 0x6402`,
nowhere near.

Same shape as the retracted `A=2064o` claim in section 166 - **two numbers compared without checking
they are in the same units, producing a confident and completely wrong adjacency.** Twice in one
session. The guard is to convert both sides into one stated unit before comparing, and to write the
conversion down, which is what the table above does.

### What this buys the next measurement

The arms stop being guesses at addresses and become NAMED ROUTINE ENTRIES in a segment with a
symbol table: `CHSWF 0o74161`, `CHSWL 0o74330`, `LIICO 0o74371`, `CHSWS 0o74407`, `KGPIB 0o74447`.
Whichever is the last to hit names where the auto-load path stopped - the same discriminating shape
as the RUNSW block watch, and unlike every arm set since, these are entries the symbol table itself
declares rather than addresses I derived.

Section 168's subtraction is still the first thing to run; this is the natural follow-up, and both
can share one run if the eight watch slots are split.

## 171. The stall PCs have names - and naming them shows the PC histogram is STRUCTURALLY the wrong instrument `[V]` addresses, `[D]` attribution

The place-domain stall histogram (section 163) was captured weeks of analysis ago and never resolved
to symbols. S3SM5 loads at runtime word `0x4000` and spans to `0xC000`, and every non-idle sample
falls in that range, so its symbol table names them - no new run:

| PC | falls inside | next symbol | samples |
|---|---|---|---|
| `0x7E78` `0o77170` | **`CMLTS 0x7E6D`** | `DEFLI 0x7E8E` | 3 |
| `0x7E79` `0o77171` | `CMLTS` | | 5 |
| `0x7E7B` `0o77173` | `CMLTS` | | 3 |
| `0x7E83` `0o77203` | `CMLTS` | | 2 |
| `0x4BA2` `0o45642` | `FREES 0x4B8F` | **`GWAIT 0x4BA3`** | 2 |
| `0x4730` `0o43460` | `TFFIS 0x4725` | `TEITR 0x4731` | 1 |

`0x4BA2` is the LAST word of `FREES`, immediately before a symbol named `GWAIT`, which is the sort of
name a blocked process sits at - but it is two samples, and adjacency is not dispatch. Noted, not
claimed.

### The four `CMLTS` samples are not a spin, and that is the important part

```
077164  JAZ 7        -> 077173
077170  STA ,B -75
077171  JPL I 23     -> [077214]      a CALL
077173  STZ ,B -75
077203  JMP 2        -> 077205
```

The samples land on BOTH arms of the branch at `077164` (`077171` and `077173`), on a call, and on a
jump further down. That is a routine being **executed through, repeatedly** - not a tight loop spun
in. And it is 13 samples out of 639, about 2% of the window, against 576 samples (90%) in the ND-100
IDLE loop.

So nothing is stuck in `CMLTS`. It is periodic background work - plausibly the watchdog path, since
22 `3RMICV` watchdog messages were sent during exactly this window - and the machine is otherwise
idle.

### WHICH MEANS THE PC HISTOGRAM CANNOT ANSWER THIS QUESTION, EVER

Section 163 established that the `place-domain` process is BLOCKED - not scheduled - rather than
spinning. **A process that is not executing has no PC to sample.** Every sample the histogram can
possibly collect belongs to something else: the idle loop, or periodic work like the above.

That is taxonomy **#8** - an instrument structurally incapable of being relevant to the question
asked of it - and it explains sections 156, 157 and 159 all failing the same way. Section 159 already
said "do not reach for the PC histogram"; this is WHY, stated mechanically rather than as a warning:
**it samples running code, and the thing under investigation is a process that is not running.**

The right instrument for a blocked process is SINTRAN's own process state - which RT/background
process is in which queue, and what it is waiting on - not a program counter. That is a different
kind of probe from anything built in this lane so far.

### Attribution caveat, stated because this file has been bitten by it twice

`DiagPcWatch` and the histogram match the 16-bit PC only. Segments alias, so "inside `CMLTS`" is
`[D]`: the addresses and the symbol containment are `[V]`, and S3SM5 is the segment that serves
ND-500 monitor commands, but nothing here PROVES S3SM5 was the mapped segment at the sample instant.
Section 165 withdrew exactly this kind of claim when the PIL said driver level. Here the PIL is 1,
which is consistent with S3SM5 rather than a driver - but consistent is not proven.

## 172. Groundwork for the probe that CAN see a blocked process - what is verified and what is not `[V]` addresses, `[OPEN]` layout

Section 171 concluded that a PC sampler cannot answer a blocked-process question and that the right
probe is SINTRAN's own process/queue state. This is the start of that, kept deliberately short on
claims because the first inference I drew was wrong.

### Verified: the resident symbol table names these, with addresses

`SINTRAN/NPL-SOURCE/SYMBOLS/L07/l07-kallsyms.txt` (15799 symbols, `0xADDR T NAME`):

| symbol | word address | octal |
|---|---|---|
| `BAK01` | 9951 | `0o23337` |
| `BAK02` | 9973 | `0o23365` |
| `RTSTA` (= `RTSTART`) | 2064 | `0o4020` |
| `RTEND` | 2259 | `0o4323` |
| `ARTFP` | 2232 | `0o4270` |
| `ARTLP` | 2233 | `0o4271` |
| `BEXQU` | 2059 | `0o4013` |
| `LEXQU` | 12 | `0o14` |

**`BAK01` is a real resident symbol** - the same name SINTRAN printed in the `0B:6B` message
(`BAK01.37603B`), so that message names a symbol the system defines, not a free-form label.

`5P-P2-MON60.NPL:910` carries the validity test, which names the table's own bounds and stride:

```
GOODRT: IF X>>=RTEND OR X<<RTSTART GO NGOOD
        A:=X-RTSTART; A=:D:=0; T:=5RTSIZE; *RDIV ST
        IF D><0 GO NGOOD; EXITA
```

So a legal RT-description address is inside `[RTSTART, RTEND)` **and** an exact multiple of
`5RTSIZE` from the start - which also means an RT-description address can be VALIDATED, not just
guessed at.

### RETRACTED BEFORE IT WAS USED: "BAK01 is an RT description with a 22-word stride"

`BAK02 - BAK01` is 22 words, and I took that as the RT-description stride. **It is not.** `BAK01`
(`0o23337`) lies far outside `[RTSTA 0o4020, RTEND 0o4323)`, so by SINTRAN's own `GOODRT` test it is
not an RT-description address at all. Whatever the 22-word spacing is, it belongs to some other
per-background-process structure.

Two symbols with a regular spacing are not a table of the thing you are looking for. The test that
caught it was free and came from the source itself - the bounds check exists precisely so callers do
not have to guess.

### Still `[OPEN]`, and needed before any probe is worth building

 - `5RTSIZE` - not present in the symbol dump under that name; without it the table cannot be walked.
 - the RT-description FIELD layout, and which field or bit carries "what this process is waiting on".
 - which structure `BAK01` actually heads, given it is not an RT description.
 - `[RTSTA, RTEND)` is only 195 words, which is small for a table of descriptions - so it may be a
   pointer/control area rather than the descriptions themselves. Unresolved.

One encouraging sign for the eventual probe: `5P-P2-MON60.NPL:027732` tests
`IF A BIT 5IEXQUEUE` - "is this message in the execution queue" - so SINTRAN does record
queue membership as a readable BIT, which is exactly the shape a blocked-process probe wants.

**No instrument should be built on this section yet.** The addresses are verified; the layout that
would make them meaningful is not.

## 173. The MON 60 counts BALANCE - and the arrival ORDER says do not trust the balance `[V]` counts, `[OPEN]` interpretation

Run with `RETROCORE_ND5000_WATCH=swload`, single test, same pack and windows.
`OUTCOME: nd-500=OK place-domain=STALL run=STALL startMessagesSeen=1` - unchanged.

```
MON60 gateway@0o146256   hits=5
MON60 ERROR ret@0o146257 hits=3
MON60 OK ret@0o146260    hits=2
S3SM5 CHSWF@0o74161      hits=0
S3SM5 CHSWL@0o74330      hits=1
S3SM5 LIICO@0o74371      hits=1
S3SM5 CHSWS@0o74407      hits=1
(the fifth S3SM5 arm was misplaced - see below)
```

### The counts say every call returned. 3 + 2 = 5.

By section 168's stated rule that would settle it: the monitor is NOT blocked inside SINTRAN's
handler, and the block is after the last return, in the monitor's own code.

**The register log refutes reading it that way.** In arrival order:

```
gateway  #1  A=272o        <- parameter-block pointer
ERROR    #1  A=2166o       <- status out.  textbook
gateway  #2  A=365o
OK       #1  A=0o          <- SUCCESS RETURNS A=0.  textbook
gateway  #3  A=1312o
ERROR    #2  A=2113o
gateway  #4  A=2064o       <- NO RETURN FOLLOWS
CHSWL    #1  A=0o    L=75236o
gateway  #5  A=136000o  B=176200o  L=146253o
ERROR    #3  A=136000o     <- BOTH return arms, same A, unchanged
OK       #2  A=136000o     <- the model forbids this
LIICO    #1  A=41o
```

Two things the model cannot produce:

 - **`gateway #4` has no return at all** before the next gateway entry.
 - **`gateway #5` is followed by BOTH return arms**, with A unchanged across all three. A call
   returns to exactly one of P+1 or P+2, and `0o146257` is `JMP 2` which jumps to `0o146261` - it
   cannot fall into `0o146260`.

So the totals balance by coincidence of two anomalies, not because five calls made five returns.
**`3 + 2 = 5` is exactly the kind of clean number that ends an investigation, and it would have ended
this one wrongly.** The counts are `[V]`; what they mean is `[OPEN]`.

### What the first three pairs DO establish, and it is worth having

They are textbook, and they confirm section 167 from live data rather than from reading:

 - A at the gateway is a small parameter-block pointer (`272o`, `365o`, `1312o`).
 - A at `0o146257` is a status (`2166o`, `2113o`).
 - **A at `0o146260` is `0`** - which is precisely the documented "SKIP = success, A=0".

The `0o146260` = success reading is now measured, not just derived. Section 167 stands.

`gateway #5`'s signature (`A=136000o`, `B=176200o`, `L=146253o` - a link INTO the gateway region) does
not look like a call site building a parameter block at all, and is the likeliest of the two
anomalies to be an aliased address rather than a real gateway execution. Not asserted.

### The auto-load path: CHSWL, LIICO and CHSWS each ran EXACTLY ONCE

`CHSWF` never ran. The three that did are in address order, once each, interleaved with the MON 60
traffic above - consistent with a single pass through the load path that then stops.

### MY FIFTH ARM WAS MISPLACED, AND ITS 30 HITS MEAN NOTHING

I armed `0x7927` and labelled it `KGPIB@0o74447`. **`KGPIB` is at `0x7924`.** `0x7927` is where the
`> Allocating memory` STRING starts - section 170's own table says so, and I read the string address
out of that table instead of the symbol address next to it. It reported `hits=30`, which is
executing string bytes as code, i.e. an aliased address.

Fifth arm-placement error of this session, and the third of this exact kind (operand words at
`0o146303`-`0o146305`, the aliased `0o37603`, now a string). The pattern is stable enough to state as
a rule: **when a table lists a string address and a symbol address side by side, arming the row means
arming the SYMBOL - and the label must be generated from the value armed, not typed.** The dump
already prints the armed value in octal, which is the only reason this was visible.

`KGPIB` itself remains unmeasured, so "did the path reach the routine that prints
`> Allocating memory`" is still open - the one thing this run was best placed to answer.

## 174. `KGPIB` runs 30 times and the message still never prints - so the string does not belong to it `[V]`

Re-run with the arm corrected to the symbol (`0x7924` = `0o74444`) rather than the string:

```
S3SM5 CHSWF@0o74161   hits=0
S3SM5 CHSWL@0o74330   hits=1
S3SM5 LIICO@0o74371   hits=1
S3SM5 CHSWS@0o74407   hits=1
S3SM5 KGPIB@0o74444   hits=30      <- the corrected arm
```

`KGPIB` at its real entry gets **30 hits**, the same count the mistaken string address gave. And the
register context separates it cleanly from the load path:

```
KGPIB hit#1 PIL=0 A=1o D=4000o B=42463o L=42605o
KGPIB hit#3 PIL=0 A=0o D=4366o B=42463o L=42630o
KGPIB hit#6 PIL=0 A=0o D=0o    B=31550o L=44765o
```

`PIL=0` and three different link registers, against `PIL=1` and one hit each for `CHSWL`/`LIICO`/
`CHSWS`. **`KGPIB` is a general utility called from several places at background level, not a step in
the auto-load path.**

### Which retracts the containment claim in section 170

Section 170 placed `> Allocating memory` "inside `KGPIB`" because `KGPIB` is the nearest PRECEDING
symbol. That is nearest-symbol reasoning - the same shape as "adjacency is dispatch", which this file
has already recorded twice - and the measurement contradicts it: **`KGPIB` ran 30 times and the
message never printed.** A routine that runs thirty times without emitting its own message is
probably not the routine that emits it.

The routine map itself says the layout is PLANC `data-before/after-code`, so an inline string sits
NEXT TO the code that uses it, and "next to" can mean either side. The owner of a string is the code
that REFERENCES it, and nothing here has established that.

**So "did the auto-load reach the `> Allocating memory` print" is still unanswered**, and the way to
answer it is to find the instruction whose effective address resolves to `0o74447` - a search over
the disassembly, not another arm.

What survives: `CHSWL`, `LIICO` and `CHSWS` each ran exactly once and `CHSWF` never - one pass
through the load path that then stops.

## 175. Attribution audit, prompted by a peer finding an invented user quote in its own plan `[V]`

`nd500uc-fc` reports that its C1 investigation rested on a quote attributed to Ronny in its
`PLAN.md` - that he had ESC-ed out of LED and seen a `USER BREAK`. Asked directly, he said *"i did
nothing"* and *"never happened / not me"*. The quote was invented in an earlier session and written
down as his, and it **survived three long runs and 28 clean placements**, because an observation
attributed to the user reads as primary evidence and outranks your own instruments in every later
argument. Each clean run was filed as "the abort is not sufficient on its own" rather than "perhaps
nobody ever aborted anything".

That is a failure mode no measurement discipline in this document catches, because it corrupts the
PREMISE rather than the measurement.

**Audited this session's output.** Sections 162-174 are 954 lines and contain **zero** statements
attributed to Ronny - every claim is a measurement, a code citation or a retraction. The one memory
file written today (`which-disk-images-are-used.md`) quotes *"make sure to refresh my disk image with
vtm files and quota. remember which disks are used"*, which is a verbatim user message in this
session's transcript and can be pointed at.

**The rule going forward, since a reconstruction reads exactly like a report:** a quote attributed to
the user must be traceable to a message that can be pointed at. If it cannot, it is written as
"unattributed" or asked about - never rendered as his words. Invented quotes reproduce the user's
register and typos convincingly, so plausibility is not a test.

## 176. The message CALL SITES, found by the inline-string idiom - and the right arm is neither symbol `[V]`

Section 174 said the owner of a string is the code that references it, and that finding it needs a
search rather than another arm. Done - and the answer was structural, not a search.

**No instruction anywhere in `030-S3SM5.dis` resolves to either string address.** That is not a gap:
these are ND/PLANC **inline strings**. The caller does `JPL` and the string follows IMMEDIATELY; the
print routine finds it via the link register and returns past it. So the reference is positional -
the call site is simply the word before the string.

```
074337  135042  JPL I 42     ; -> [074401]
074340  "$> Loading Swapper'"        <- string begins here
```

```
074434  171052  SAT 52
074435  142065  SKP IF DA UEQ ST     skip when A is NOT 52
074436  124040  JMP 40  -> 074476    A == 52: skip the print
074437  171053  SAT 53
074440  142065  SKP IF DA UEQ ST
074441  124035  JMP 35  -> 074476    A == 53: skip the print
074442  171076  SAT 76
074443  142065  SKP IF DA UEQ ST
074444  124032  JMP 32  -> 074476    A == 76: skip the print
074445  135043  JPL I 43     ; -> [074510]
074446  "$> Allocating memory'"      <- string begins here
```

### What this settles

 - **`> Loading Swapper` is printed at `0o74337`, which IS inside `CHSWL`.** Section 170's
   containment happened to be right, but for the wrong reason (nearest preceding symbol); it is right
   now because the CALL SITE is in that range. `CHSWL hits=1` and the message printing once agree.
 - **`> Allocating memory` is printed at `0o74445`** - and it is GUARDED by three inequality tests.
   The print is reached only when A is none of `52`, `53`, `76` (octal). Any of the three jumps to
   `0o74476` and skips it.
 - **The correct arm for "did the path reach the print" is `0o74445`** - not `KGPIB 0o74444`, and not
   the string at `0o74447`. Both of my previous attempts were one word off on either side of it.

### And it confirms the `KGPIB` hits are aliased, on the register evidence

`0o74444` is the third guard jump, reachable ONLY when `A == 76`. The register log for its 30 hits
shows `A=1o` and `A=0o`, never `76`. **A hit at that address with A not equal to 76 cannot have
arrived through the guard chain**, so those 30 hits are code at an aliased address, exactly as
section 174 concluded from the PIL and link registers - now with a second, independent reason.

That is the useful shape: an arm whose address has a REQUIRED register precondition can self-check.
`0o74445` inherits it - a genuine hit there must show A not in {52, 53, 76}.

### The open question, now sharply posed

The three guards are a decision, not an error path: something is being classified and the print is
suppressed for three specific values. If `0o74445` never hits while `0o74476` does, the auto-load
deliberately skipped the allocation message - which would make the missing message a NORMAL outcome
and remove it as evidence of the stall entirely. Worth knowing before another instrument is built on
its absence.

### 176a. The skip target is a NORMAL continuation, not an error bail `[D]`

Reading where the three guards send control:

```
074476  LDD ,B -63          <- all three guards jump here
074477  STD ,B -65
074500  JPL I 13            a call
074501  STA ,B -66
074502  MIN ,B -74
074503  JMP I 11            leaves the routine
```

The epilogue `STA ,B -66` / `MIN ,B -74` / `JMP I 11` is the SAME shape as the one at
`0o74373`-`0o74375` on the other path through this routine. Both arms converge on an ordinary
return, and `0o74476` contains no error call, no status store and no jump to a handler.

**That strengthens "the missing message is a decision, not a fault"** - suppressing the print looks
like a designed alternative flow rather than something going wrong. Graded `[D]`, not `[V]`:
`0o74506`-`0o74514` are POINTER WORDS (the disassembler renders them `IOT 3637`, `ADD I -115` and so
on), so anything read past `0o74505` by eye is unreliable, and I have not traced where `0o74503`
actually lands.

It does NOT make the absence harmless - a decision taken on the wrong input still ends in the wrong
place. But it removes "the message is missing, therefore something failed" as a free inference, which
is how it has been used since section 169.

### 176b. What A holds at the guard: field `0o20` of the `,B -11` control block `[V]` idiom, `[OPEN]` name

The guarded print is decided by A, loaded two instructions earlier:

```
074432  054767  LDX ,B -11        X := the control block
074433  046020  LDA ,X 20         A := field at offset 0o20
074434  171052  SAT 52            then the three-way compare
```

**CORRECTED, same day.** I first wrote that `LDX ,B -11` "is not ad-hoc - it is the standard
control-block fetch in this segment", on the strength of `CSREA` opening the same way. **That
co-occurrence is worth nothing:** `LDX ,B -11` appears **128 times** in this segment, and other
frame slots more often still (`,B -67` 456 times, `,B -56` 131). Two routines using the same slot is
what a compiler convention looks like, not evidence they address the same object. One shared idiom
observed twice is not a shared object - the same "correct about the wrong thing" shape this document
keeps recording.

What WOULD make it a specific field is the NPL register convention, and there is real evidence for
it: `5P-P2-MON60.NPL` documents `B` as a DATAFIELD pointer in twelve routine headers -
`ENTRY: B=N500DF DATAFIELD`, `ENTRY: B=ND-500 CPU DATAFIELD`. If `B` is `N500DF` here too, then
`,B -11` IS one field of one global structure and reading offset `0o20` from it is meaningful across
routines. **That is the thing to establish** - not the co-occurrence. `CSREA` opening identically at
`0o152165` is then a consequence rather than the evidence:

```
152165  054767  LDX ,B -11
152166  052041  LDT ,X 41
152167  056044  LDX ,X 44
```

So the three guard values `52`, `53`, `76` (octal) are being compared against **one field, at offset
`0o20`, of the block `,B -11` points at**. Naming that block and that field would say outright
whether suppressing `> Allocating memory` is correct behaviour for this configuration - which is the
open question in 176a.

`[OPEN]`: the block's identity. The annotated `FUNCS-BODIES` do NOT cover this address range - they
span `0o152165`-`0o153631`, the FUNCS servicing region, whereas the auto-load messages live around
`0o74337`-`0o74445`. So there is no existing annotation to inherit here, and the field will have to
be identified from its uses.

### 176c. `N500DF` is probed ONCE, early - and the neighbouring cell proves that is not enough `[V]`

If `B` is `N500DF` in this segment (176b), then the guard field is read through it and the datafield
pointer's value matters. The harness reads it exactly once:

```
resident probe  ADRZERO@0o52047 byteConv=0x0000 wordConv=0x0000 (expect 0x0840=2112) | N500DF@0o51767=0x0000
...
NSAMSON@0o11250=0x0004 ... ADRZERO@0o52047=0x0840
```

`N500DF` reads `0x0000` - once, at the early probe. **The cell beside it in that same line,
`ADRZERO`, reads `0x0000` there and `0x0840` at the later probe.** So a cell of the same class,
sampled at the same early moment, is DEMONSTRABLY not yet initialised at that point.

Therefore `N500DF=0x0000` says nothing about its value when the guard runs. It is not evidence that
the datafield pointer is null; it is evidence about when the probe fired. **A single early sample of
a value known to change is uninformative and does not look uninformative** - it renders as a
measurement with an address and a value.

The fix is the one `ADRZERO` already has by accident: read it twice, early and late, and print both.
Anything read once in that probe block deserves the same treatment before it is quoted.

## 177. The allocation step is NEVER REACHED - neither the guard nor its skip. And the arm's self-check proved its own 30 hits false `[V]`

`RETROCORE_ND5000_WATCH=msgprint`, single test, unchanged pack and windows.
`OUTCOME: nd-500=OK place-domain=STALL run=STALL startMessagesSeen=1`.

```
CHSWL entry@0o74330        hits=1
PRINT LoadSwapper@0o74337  hits=1
CHSWS entry@0o74407        hits=1
guard start@0o74434        hits=0     <-
PRINT AllocMem@0o74445     hits=30    <- and yet
guard SKIPPED to@0o74476   hits=0     <-
MON60 gateway@0o146256     hits=5
CONTROL 5ACTSWAPPER        hits=2     liveness OK
```

### The 30 hits at the print are FALSE, and the table proves it without any outside argument

`0o74445` is reachable only by falling through the guard chain that STARTS at `0o74434`. **`0o74434`
has zero hits.** You cannot arrive at `0o74445` through the guard without executing `0o74434`, so
those 30 hits did not come that way - they are foreign code at an aliased address.

The register log agrees and adds the detail: all 30 are `PIL=0`, `B=42463o`, `L=42605o`/`42630o` -
the same signature as the 30 spurious `KGPIB` hits in section 174, at the adjacent word. So one
2-word sequence of foreign code executes at `0o74444`-`0o74445` thirty times. Notably it does NOT
touch `0o74434` or `0o74476`, which is why those read zero and why the contradiction is visible at
all.

**This is the first arm set in this document that caught its own false reading from inside the same
table.** Section 174 needed the PIL and link registers to argue it; here the arithmetic of the arms
does it: an address with a required predecessor, armed alongside that predecessor, cannot lie about
being reached.

### What is therefore MEASURED

**The `> Allocating memory` code was never executed at all - not the print, not the guard, not the
skip.** So the missing message is neither a fault at the print nor a decision to suppress it:
**control never got there.**

Combined with `CHSWS entry@0o74407 hits=1`, the auto-load path stopped somewhere in the **21 words
between `0o74407` and `0o74434`**. That is the tightest bound this investigation has had, and it
retires the framing of 176a/176b: there is no point identifying what the guard tests, because the
guard never runs.

`PRINT LoadSwapper@0o74337 hits=1` also confirms section 176's attribution directly - one hit, one
printed message - so the inline-string idiom reading was right.

### `N500DF` is genuinely `0x0000`, not an early-probe artifact

The second probe added this run reads it after `ADRZERO` has become `0x0840`:

```
N500DF@0o51767=0x0000 (early read was 0x0000)
```

**Both reads are zero**, at points where a neighbouring cell of the same class demonstrably has
initialised. So section 176c's caution is discharged in the direction that makes it interesting:
`N500DF` really is zero after the ND-500 subsystem reports itself initialised, rather than merely
being read too early. Whether it is SUPPOSED to be non-zero is `[OPEN]` - but it can no longer be
dismissed as a probe-timing artifact, which is exactly what the single early sample invited.

## 178. Inside the 21-word window: FOUR exits before the guard, and two calls that may not return `[V]` code

The window bounded by section 177 - `CHSWS` entry `0o74407` (hit once) to the guard `0o74434` (hit
zero) - decodes cleanly. Every line here is an instruction; no pointer words in this stretch.

```
074407  STF ,B -54            CHSWS entry            hits=1
074410  RADD CLD SL DA        A := L
074411  JPL I 75              CALL [074506]          <- may not return
074412  LDX ,B -57                                   <- reached only if it does
074413  LDA ,X -22
074414  BSKP ONE 30 DA
074415  JMP 67   -> 074504    EXIT A
074416  BSKP ZRO 70 DA
074417  JMP 63   -> 074502    EXIT B
074420  LDD ,B -65
074421  STD ,B -63
074422  LDX ,B -57
074423  LDD ,X -7
074424  STD ,B -65
074425  JPL I 62              CALL [074507]          <- may not return
074426  JMP 56   -> 074504    EXIT C
074427  LDX ,B -57
074430  LDA ,X -17
074431  JAF 45   -> 074476    EXIT D
074432  LDX ,B -11
074433  LDA ,X 20
074434  SAT 52                guard start            hits=0
```

### What is already excluded

**EXIT D is ruled out by data in hand.** `0o74431` jumps to `0o74476`, and section 177 measured
`0o74476` at **zero** hits. So the path did not leave that way.

That leaves three exits (A, B, C - two of them to the same target `0o74504`) plus the two calls,
either of which could simply not return.

### The discriminating arm set, and why `0o74412` is the important one

`0o74412` is the instruction after the first call. **If `0o74411`'s call never returns, `0o74412`
reads zero** - the same "did it come back" subtraction that settled the MON 60 question in shape, and
the cheapest possible test of the most likely explanation for a path that vanishes.

Proposed arms, fully discriminating and self-checking in the sense of 177 (each exit has a required
predecessor also armed):

```
0o74407  CHSWS entry        expect 1  - control, already known
0o74412  after CALL#1       0 => the call at 0o74411 never returned
0o74415  EXIT A
0o74417  EXIT B
0o74426  EXIT C             0 with 0o74412 non-zero => CALL#2 at 0o74425 never returned
0o74431  EXIT D             expect 0  - keeps 177's measurement visible in the same table
0o74434  guard start        expect 0  - the bound itself
5ACTSWAPPER                 liveness
```

Exactly one of {A, B, C} should hit, or none of them if a call swallowed the path. Those outcomes
are mutually exclusive, so no reading of the table can be ambiguous.

**Not yet armed** - the shared build tree is with `nd500uc-fc`. This is written down rather than
implemented so the next window is a build and a run, not a fresh analysis.

### A note on `,B -57`, since three of these lines use it

`0o74412`, `0o74422` and `0o74427` all reload `X` from `,B -57`, then read fields `-22`, `-7` and
`-17` of it. Per the correction in 176b, that recurrence is NOT evidence of anything by itself -
`,B -57` appears 124 times in this segment. It is noted only because within THIS routine the same
slot is reloaded three times, which is consistent with one object being re-examined after each call.
Consistent with, not evidence of.

## 179. The 21-word window read again with the calling convention carved out - the arm set drops from eight addresses to four, and one of section 178's two "may not return" calls is refuted

Section 178 decoded the window at `0o74407`-`0o74434` and proposed an eight-address arm set built
around one question: **does the path vanish into one of the two `JPL I` calls?** That was the right
question, but it did not need a run. Both calls are answerable from the listing, because the routine
they belong to is compiler-generated and its calling convention is carved in the helpers themselves.

Everything here is read from `030-S3SM5.dis` in
`E:\Dev\Ronny\NDInsight\tools\sintran-segment-carver\versions\L-VSX-500\re\`. No harness ran.

### 179.1 The calling convention, `[V]` from the frame helpers' own instructions

The window's prologue is three words:

    074407  STF ,B -54            save F
    074410  RADD CLD SL DA        A := L        (capture the return link into A)
    074411  JPL I 75  -> 074506   call [074506] = 0o44030

`0o44030` is **the frame-push helper**, not a routine this code chose to call:

    044030  STX ,B -51            park X
    044031  STA ,B -50            park A - which the caller just loaded with L
    044032  LDA 46                stack limit
    044033  LDX ,B -47            stack pointer
    044034  SKP IF DX MGRE SA     in range?
    044036  JPL I 43  -> 044101   overflow handler
    044043  AAX 21                advance the stack pointer by 21 octal = 17 words
    044045  LDA ,B -50
    044046  STA ,B -74            *** the saved link lands in ,B -74 ***
    044053  EXIT

and `0o44054`, immediately after it, is the matching **pop**, whose tail is the whole answer:

    044055  AAX -21               retract the stack pointer
    044067  LDA ,B -74            fetch the saved link
    044070  RADD CLD SA DL        *** L := A ***
    044077  EXIT                  return through it

**So `,B -74` IS the saved return address, `[V]` - not derived, not inferred from a neighbour.**
That single fact decodes the rest of the routine:

- **`MIN ,B -74` increments the saved return address.** That is the SKIP return - the caller resumes
  at P+2. Same P+1/P+2 polarity settled for MON 60 in section 168, now seen from the callee side.
- **`STA ,B -77` writes the status the caller will read**, and does NOT touch `,B -74`. That is the
  DIRECT return - the caller resumes at P+1 with a status.

The window's own tail is exactly those two epilogues sharing one pop:

    074502  MIN ,B -74            SUCCESS: bump the link
    074503  JMP I 11  -> 074514   = 0o44054, pop and return
    074504  STA ,B -77            ERROR:   store the status
    074505  JMP -2    -> 074503   then fall into the same pop, link NOT bumped

### 179.2 CALL#1 is the prologue. Section 178's "may not return" on it is RETRACTED

`0o74411` is the frame push. It returns via `EXIT` at `0o44053` on every path except a stack
overflow (`0o44036 -> 0o44101`). Arming `0o74412` to ask "did the call at `0o74411` come back" was
therefore going to spend a build window confirming that the compiler emits a working prologue.

Section 178 wrote of that arm: *"the cheapest possible test of the most likely explanation for a
path that vanishes."* It was neither - it was a test of the most likely explanation for a path that
vanishes **in hand-written code**, applied to a routine that is not hand-written. Reading the target
cost four minutes and no build.

### 179.3 CALL#2 returns BOTH ways, so `0o74426` is a landing site, not an exit

`0o74425 JPL I 62 -> 074507` calls `0o163637`, a real routine - it opens with the same
`STF ,B -54 / RADD CLD SL DA / JPL <push>` prologue. Its body is a chain of steps in the same
convention:

    163643  JPL I 56  -> [163721]
    163644  RAND 0 0              <- direct/error landing (a NOP holding the slot)
    163645  JPL I 55  -> [163722]
    163646  JMP I 55  -> [163723] = 0o164114

and `0o164114` is that routine's own `STA ,B -77` error epilogue, byte-for-byte the shape of the
window's `0o74504`:

    164112  MIN ,B -74
    164113  JMP I 23  -> 164136
    164114  STA ,B -77
    164115  JMP -2    -> 164113

**So the routine at `0o163637` returns - by both doors.** It never swallows the path. Which makes
the two words after `0o74425` a skip-return pair, not a call and an exit:

    074426  JMP 56 -> 074504      DIRECT landing  = CALL#2 failed, propagate its status
    074427  LDX ,B -57            SKIP   landing  = CALL#2 succeeded

Section 178 labelled `0o74426` "EXIT C". It is an exit, but it is reached only by the callee
choosing the direct door - which is a different claim, and a measurable one.

### 179.4 The window, re-read

    074407  STF ,B -54            prologue                       hits=1 (177)
    074410  RADD CLD SL DA        A := L
    074411  JPL I -> 0o44030      prologue: push frame           (returns)
    074412  LDX ,B -57            sole landing
    074413  LDA ,X -22
    074414  BSKP ONE 30 DA        bit test 1
    074415  JMP -> 074504         *** EXIT: error, status in A
    074416  BSKP ZRO 70 DA        bit test 2
    074417  JMP -> 074502         *** EXIT: success
    074420  LDD ,B -65            save local -65 into -63
    074423  LDD ,X -7             local -65 := [X-7]
    074425  JPL I -> 0o163637     the real call                  (returns both ways)
    074426  JMP -> 074504         *** EXIT: error, propagate CALL#2's status
    074427  LDX ,B -57            success landing
    074430  LDA ,X -17
    074431  JAF -> 074476         EXIT D - EXCLUDED, 0o74476 measured ZERO in 177
    074434  SAT 52                guard start                    hits=0 (177)

**Three candidate exits remain, and they are mutually exclusive**: `0o74415`, `0o74417`, `0o74426`.
Exactly one of them carries the path. `0o74431` is already excluded by section 177's zero at
`0o74476`, and falling through to `0o74434` is excluded by section 177's zero there.

### 179.5 The arm set, now four addresses

    0o74407  = 0x7907   prologue        expect 1  - control, the bound's left edge
    0o74415  = 0x790D   EXIT error-1
    0o74417  = 0x790F   EXIT success
    0o74426  = 0x7916   EXIT error-2 (CALL#2 failed)
    plus 5ACTSWAPPER                    liveness

Exactly one of the three exits must read 1 and the other two 0. Any other table - two exits hot, or
all three cold with the prologue hot - is itself a finding, because it would mean the path leaves
somewhere the decode says it cannot.

**Still not armed** - the shared build tree is with `nd500uc-fc`. But the next window is now four
arms and one run, not eight arms and an interpretation.

### 179.6 What this cost and what it is worth

Section 178's arm set would have consumed a build window to learn that a compiler prologue returns.
The correction came from asking a question section 178 did not ask: **not "does this call return?"
but "what IS this call?"** - one `grep` for the pointer word's value, one `sed` for the target's
body.

The general shape, and it is the same family as instrument-failure #19 (correct about the wrong
object): **`JPL I <pointer>` renders identically whether the callee is a routine the code chose or
plumbing the compiler emitted.** The disassembly cannot tell them apart, and the instrument built on
top of it would have measured the plumbing with a straight face. Read the target before arming the
landing site.
