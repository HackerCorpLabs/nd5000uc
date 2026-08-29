# The octobus swapper standoff — where `> Loading Swapper` actually stops

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
