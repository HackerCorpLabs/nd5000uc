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
