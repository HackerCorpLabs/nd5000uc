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

## 5. `[OPEN]` — the one question that decides whose defect this is

Our walk skips both nodes because `N5STA` is not `ToNd500(1)`. Two readings, needing opposite fixes:

 - **Correct as-is.** Those are ND-100-side bookkeeping blocks in SINTRAN's own status space, and
   the ND-500 is not supposed to touch them. Then the missing step is further back and the standoff
   is a symptom.
 - **Our defect.** SINTRAN expects the ND-500 to consume a `SWPPING`/`3SWMESS` node, and skipping it
   is why nothing progresses.

Note our servicer declares `3SWMESS` (05) understood **only** on the ND500 generation — on ND-5000
the B30 dispatches it to `MSG_ILLEG` — but we never reach that arm, because the walk skips the node
before any MICFU dispatch. So the generation gate has never been exercised here and cannot be the
cause.

**Do not guess between the two.** The next carve is what writes and what clears `SWPPING` on the
ND-100 side, and whether any ND-500-side actor is expected to.

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
