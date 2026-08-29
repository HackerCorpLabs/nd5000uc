# The octobus swapper standoff — where `> Loading Swapper` actually stops

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
