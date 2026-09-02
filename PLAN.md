# PLAN

**OUTSTANDING WORK ONLY.** Nothing finished is recorded here.

**Lane:** this session owns **ND-5000 / octobus**. `nd500uc-47` owns ND-500 / classic 3022.

---

## Next

**NEXT: inside `LNEWSWAP`'s served-process branch (`135476` on), find why control reaches `SWPD4`
(park the swapper) instead of `LDATREADY` (restart the requester).** Standoff **204**. Both are
reachable from there; only `LDATREADY`/`INLDATREADY` clears `SWPPING`.

**RESOLVED (204): `133645` wrote the `SWPPING` - the `SWMESS`/`MSWSTART` start path, not
`5ACTSWAPPER`.** That arm predicts three measured values at once (requester `SWPPING(6)`,
`swMsg MICFU=0x0013` `3START`, `SWPFU=SWACTIVE`); `5ACTSWAPPER`'s success arm predicts
`MICFU=0x14` and is refuted by it. **So `5ACTSWAPPER` never reached `145071` - both its executions
took the `145111` "insert in swap-wait-fifo" else.** Nothing is lost on our side.

The designed chain, mapped:

```
  SWMESS/MSWSTART 133645  requester:=SWPPING; SWMSG.SWPINFO:=requester;
                          SWMSG.MICFU:=3START; SWPFU:=SWACTIVE
  LNEWSWAP        135470  IF SWMSG.SWPINFO ><0 THEN "proc currently served"
  LDATREADY       136341 / INLDATREADY 136446   clears a SWPPING requester ("Restart process")
  SWPD4           135747  mark swapper free, then drain the swap-wait fifo,
                  136027  serving only entries at SWPWAIT(5)
```

**The two gates use DIFFERENT states**: the fifo drain serves `SWPWAIT(5)` (what `5ACTSWAPPER` marks
at `144775`), our node is `SWPPING(6)` via the START path, so it is not in the fifo and the drain
correctly finds nothing. `SWPPING` is cleared by `LDATREADY`, not by the drain.

**`swpInfo=0x00008E30`, NOT zero** - so `LNEWSWAP` takes the "proc currently served" branch and
"the swapper was started with no work" is refuted as the reason it parked.

**REFUTED (203): SINTRAN DOES send the restart.** The `[D]` carried since 199.1 - *"nothing turns
`SWPPING` posted into the `3MONCO` restart"* - is wrong. `5ACTSWAPPER`'s swapper-free arm does it
four instructions after the `SWPPING` write:

```
  145022   X:=MSGTOSW; SWPPING; CALL WN5STATUS   % Mark that process is using the swapper
  145054   X:=SWMSG; *AAX SWPST; STATX           % Save reason for activating swapper
  145071   3MONCO; *MICFU@3 STATX                <- stamps SWMSG.MICFU := 3MONCO
  145073   CALL MCCO                             % Yes, restart swapper after mon.call
```

**The witness:** `3MONCO`=`24B`=`0x14`, `3START`=`23B`=`0x13`. `145054..145073` is straight-line, so
if `145022` ran then `145071` ran and `SWMSG.MICFU` must be `0x14`. It measures **`0x0013`** over 98
dumps. So either that arm was never entered, or the stamp is being lost.

 - `145022` wrote it -> a `3MONCO` stamp is LOST between SINTRAN and us.
 - `133645`/`134107` wrote it -> `5ACTSWAPPER` never reached its success arm, and the `PSWWAIT` test
   at `145001` reads something other than the `0x00428D30` the dump shows.

**A state does not name who wrote it** - `SWPPING` has three writers. Same trap as 201, one section
later.

**RETRACTED (202): there is no `PSWWAIT`/`SWPPING` contradiction - I read one node's state onto the
other.** Two nodes, one hex digit apart, both correct:

```
  0x00428D30  swMsg  N5STA=0x0007 PSWWAIT  MICFU=0x0013 3START   - the swapper is free and parked
  0x00428E30  ping   N5STA=0x0006 SWPPING  MICFU=0x0005 3SWMESS  - work posted to it
```

`SWPPING(6)` is what `5ACTSWAPPER` **writes on success**, after checking `swMsg` is `PSWWAIT(7)`.
So the gate PASSED and the wake path ran to completion. Every actor writes the state it should.
**Never state a node's status without its address beside it** - trap #19, correct about the wrong
object.

**ANSWERED (201) `[V]`, from `run199.log:2432` - already on disk, no new run:**

```
[MON PATH] forwarded=2  3MONCO=1  realRoundTrips=1
MON restart path: posted=2  seen=1  taken=1   <- 1 stop posted with no restart yet
swpfu[LNEWSWAP:2]  ansSWPFU=1B  ansSWPSTAT=0B  ansP=PC=0x08008255  restarts=1/1
```

**The swapper made TWO `LNEWSWAP` calls and was answered ONCE. It resumed after the first, looped,
called again, and is parked on the SECOND** - both from the same site `0o1000101077` (200), which is
why `ansP == PC`. So "answered but never resumed" is REFUTED; the park is the designed idle.

**The contradiction that remains:** that idle is defined as *"answers the served node, marks `SWMSG`
`PSWWAIT` (free), returns to the message loop, woken later by `5ACTSWAPPER`"*. But `5ACTSWAPPER`
requires `PSWWAIT(7)` and the node measures `SWPPING(6)` (193, 199). Either the second park never
marked `PSWWAIT`, or something restored `SWPPING` after it did.

**Method cost worth not repeating:** two ticks went into designing a measurement that the run's own
`[MON PATH]` report had already made. Grep the report before building an instrument.

**ANSWERED (200) `[V]`, no run needed: the parked process IS the swapper and its `P` is a MON 377B
return address.** `PC = 0x08008255 = 0o1000101125`, which is `0o1000101077 + 22 bytes` - the
instruction after the swapper's own `MON 377B` `CALLG`. Next instruction is `if -k go $10`, the
`K`-flag test on the answer. Identified from `SWAPPER-K01.PSEG`, not by elimination.
Also `[V]`: `MON 377B` is genuinely a swapper call (16 sites in its PSEG). **But `N5SWAP`, the name
the harness comment gives it, is in no symbol file - right number, unsourced name.**

**ANSWERED (193): the wake requires `N5STA == PSWWAIT(7)`; the node is `SWPPING(6)`; `5ACTSWAPPER`
correctly declines.** `0o145354` -> `0o23662` = `RN5ST`, and `RN5STATUS` (`CC-P2-N500.NPL` 679-687)
takes `X` = message address and returns `A` = `message.N5STA`. So the gate at `0o145202` tests the
node's own status.

**EVERY ACTOR MEASURED IS CORRECT.** `CHSWS` posts and waits; our servicer AND the real B30 microcode
both ignore a non-`MSGN500` node (now held by a passing test); `5ACTSWAPPER` declines to re-ping over
an outstanding one. **The missing actor is the SWAPPER, which must consume its ping and return the
slot to `PSWWAIT`.** It was started, ran, took ONE monitor call, and parked holding an unconsumed
ping.

`[D]` not `[V]`: that `PSWWAIT` means "free" and the swapper is obliged to clear `SWPPING`. It is the
reading that makes all six measured facts consistent, which is evidence, not a carve.

**MEASURED (177): the `> Allocating memory` code is NEVER REACHED** - not the print (`0o74445`), not
the guard (`0o74434`), not the skip target (`0o74476`). So the missing message is neither a failure
at the print nor a decision to suppress it: control never gets there. This RETIRES 176a/176b - there
is no point identifying what the guard tests, because the guard never runs.

**The 30 hits reported at `0o74445` are FALSE and the table proved it itself:** that address is
reachable only through the guard chain starting at `0o74434`, which has zero hits, so they are
foreign code at an aliased address (same `PIL=0`/`B=42463o` signature as the spurious `KGPIB` hits).
**Arm an address together with its required predecessor and the pair cannot lie about being reached** -
the one instrument design this session that caught its own bad reading with no outside argument.

**ALSO MEASURED (177): `N500DF@0o51767` is `0x0000` at BOTH probes**, the second taken after
`ADRZERO` has become `0x0840`. So it is genuinely zero after the subsystem reports itself
initialised, not read-too-early. Whether it SHOULD be non-zero is `[OPEN]`, but it can no longer be
waved away as probe timing - worth chasing, since if `B` is `N500DF` in `S3SM5` then every `,B -nn`
access in that segment is relative to zero.

**STILL OPEN (173):** the MON 60 counts balance (5 = 3 + 2) but the arrival order forbids that
reading - one gateway hit has no return, another has both. Counts `[V]`, meaning `[OPEN]`.

> **CLOSED (standoff 162): the `THA` line of investigation is over, and it was never a defect.**
> The copy-diagnostic ring shows SINTRAN writing `0x00000000` into all thirteen trap-config cells,
> including `0x4200B6` = the PCB `tha` field, and reading nothing back. `THA == 0` is the guest's
> own value, faithfully delivered. The falsification this plan used to carry - *"THA should be
> non-zero after a completed 3START"* - asserted a value SINTRAN does not write, so it could never
> have passed. Separately, a real gap WAS closed on the way: `DitConfigured` was false for the whole
> life of an octobus run (every `ReadDIT_*` returned 0 and logged a warning); the base is now
> learned from the thirteen writes and declared in `OnStartProcessND5000`. That does NOT move the
> stall and must not be reported as progress on it.
>
> **Before instrumenting anything else in the servicer/bridge pair, read standoff 162's PATTERN
> note:** every ND-5000 path has a classic ND-500 twin beside it, the classic one reads like the
> only one, and three separate wrong placements this session were all that same mistake.

**The detail on that (standoff 159).** Every participant in
the stall is healthy: the ND-100 is alive and interrupted 286 times DURING the stall and is sitting
in its IDLE loop (not spinning - confirmed against a control window where nothing was happening);
answers are delivered `74/74`; the swapper started, answered MON 377B and idles correctly; the
ND-5000 sits in `WAIT`. Nobody is failing to signal anybody. **Do not reach for the PC histogram -
it is structurally incapable of answering this** (it reports the idle loop with 93% confidence
whether or not anything is wrong; sections 156/157 were spent on that).

> **SUPERSEDED (section 155): "the ACCP timeout, NOT the pack."** The
> `ACCP was terminated; Microprogram has stopped` line prints ONCE, before the control store is ever
> downloaded, and never again - a true report at monitor entry that self-clears, not the blocker.
> Kept because it was the stated Next for one day.

**OLDER FRAMING (superseded, section 154): the ACCP timeout, NOT the pack.** `ND-5000 timeout: ACCP was terminated; Microprogram has
stopped` is printed as the FIRST line after `@nd-500`, before any command is typed, in every run
including the ones called working. Standoff **154** shows why it comes first: `place-domain` on a
domain with CORRECT segment names (`cpu-stat`) and on one with STALE floppy names (`LED-B03`,
110-page PSEG + 193-page DSEG present on the pack) produces a **bit-identical** machine state -
`PC=0x08008255 stopMode=WAIT startSeen=1 startMicfu=23B startTaken=True ansMON=377B THA=0` for both,
and no error on either console. The stall is upstream of anything domain-specific, so the pack's
stale names cannot be the active blocker and correcting them would not change the outcome.

> **SUPERSEDED FRAMING (kept because it drove the work for weeks): "THE PACK IS INSTALLED WRONG. Fix
> that before measuring place-domain again."** Standoff sections 126 and 152. `(PACK-ONE:SYSTEM)DESCRIPTION-FILE:DESC` is LED's floppy description file copied
unchanged - 22528 bytes.

> **THE TEXT ABOVE IS CORRECT. Two attempts to "sharpen" it on 2026-08-31 were both wrong and are
> retracted - see standoff sections 152 / 152a / 152b.** Recorded because the wrong versions were
> briefly written into this file and may have been read.
>
>  - **Retracted claim 1: "the registered domains have no files on the pack, the intersection is
>    empty."** False, and it was a GREP ARTEFACT - the pack was listed filtering on `:DOM`, and these
>    two domains use the older `:PSEG`/`:DSEG` form. All four files are present:
>    `(SYSTEM)LED-B03:PSEG`, `:DSEG`, `(SYSTEM)SCRATCH-SEG-01:PSEG`, `:DSEG`.
>  - **Retracted claim 2: "so `place-domain CPU-STAT` cannot work on this pack."** False. A passing
>    run on that exact pack shows no `NO SUCH DOMAIN` at all: the control store loads, the swapper
>    loads and STARTS (`startTaken=True`, MON 377B answered), and the ND-5000 then sits in `WAIT` -
>    which is exactly what the ND-60.136.04A ch.11 note below predicts.
>
> What IS verified from that decode: three tables (domains at 0x100 in 56-byte entries, file/device
> at 0x800, segments at 0x4000 in 192-byte entries); the two domain names are clean; the floppy
> prefix lives on the SEGMENT records; and the file read was sha256-identical to the pack's own copy.
> The defect is the one stated below - stale `(...FLOPPY-USER)` segment names that only fail at
> `:PSEG`/`:DSEG` open time.

ND-30.003.007:4607:
*"The description file still contains the definitions valid for the user the domain is copied from.
This must be corrected."* `COPY-DOMAIN` rewrites those names; `@COPY-FILE` cannot.

ND-60.136.04A ch.11 explains the shape exactly: the `(directory:user)` prefix is **not consulted
until the `:PSEG`/`:DSEG` are opened**, so a file-copied domain RESOLVES and only fails LATER at
file-open. That is precisely what place-domain does - it gets all the way through, the swapper
starts and answers MON 377B, and then SINTRAN goes quiet with nothing to page in.

**So `THA=0` is NOT established as the blocker** - a domain whose files cannot be opened may never
get a populated context. Item 1's remaining CPU-side questions are ON HOLD until a correctly
installed pack exists (`nd500uc-d4` is building the ENTER-DIRECTORY / COPY-DOMAIN /
DEFINE-STANDARD-DOMAIN fixture).

**UPDATE 2026-08-31 - that fixture's own blocker is root-caused (standoff 136).** It crashed with
`NOT KNOWN TRAP`, and the cause was the fixture, not the emulator: `AttachRealCpuNow()` was called
only just before RUN, but place-domain LOADS AND STARTS THE SWAPPER as part of placement, so nothing
was there to take the `3START` and it fell through to an all-zero stop record. A 116-message census
shows every answer `N5STA=0003`, zero `5ERANSWER`, and **zero PHYSWR sent at all** - which also kills
my own section 132 idea that a floppy-directory domain gives a segment with no PST entry. Their
verification run is in flight. My half of that split (standoff 134, 135) is finished and needed no
engine code.

**DO NOT "fix" NO SUCH PAGE by zero-filling.** ND-60.136.04A:2987 says the Monitor zero-fills on a
NO SUCH PAGE at execution time - real text, naming our exact error - but it is section 6.9.2
LOW-ADDRESS and concerns a HOLE INSIDE AN EXISTING segment file. Nothing ties it to a MISSING file.
Implementing it would make the symptom vanish, turn the lane green, and hide a broken install behind
genuine-looking manual backing.

**What is unaffected and still worth doing:** items 4, 6, 7, 9 and the SCHPAR half of 10 are all
pack-independent.

---

## THE GOAL, and how each step gets there

> Run a real ND-500/ND-5000 program on the emulated CPU, driven by **REAL SINTRAN III** on the
> emulated ND-100, with every **MON call FORWARDED** over the octobus. A run our C#
> `SintranEmulation` answers DOES NOT COUNT.

The macro round (`CpuND500` + real SINTRAN over octobus) **is the goal configuration** - real
SINTRAN, real MON forwarding (last measured `restarts=1/1`, Seen == Taken, no gap). It is also the
round that gets furthest. So the goal is reached by fixing the macro round, in this order:

```
  1  place-domain completes        -> a domain can be placed
  2  start-swapper posts its start -> the documented ladder works end to end
  =  RUN a .DOM under real SINTRAN with MON forwarded   <-- THE GOAL
  3  CS load works on the real B30 -> the ORACLE round can then VALIDATE all of it
  4..8  correctness work behind the oracle
```

Steps 1 and 2 reach the goal. Step 3 is what proves we did it right rather than by accident.

---

## 1 - Make PLACE-DOMAIN complete on the macro round

**Measured state:** `place-domain` prints `> Loading Control Store`, then `> Loading Swapper`, then
STALLS. `> Allocating memory` never appears. The swapper itself is NOT at fault (section 45).

**THE FRAMING HAS BEEN WRONG TWICE. Standoff sections 105 and 114 have the corrections.** What the
CPU actually serviced in the entire run:

```
  262  MICFU=0x01  3RMICV   watchdog heartbeat - "time passed, nothing more"
   13  MICFU=0x19  PHYSWR   physical-write, 4 bytes each
    1  MICFU=0x0A  CACHE    cache-clear
    0  MICFU=0x05  3SWMESS  <- and that is CORRECT
```

**CORRECTED AGAIN - section 122. That census was a SAMPLE, not the census.** The authoritative
`micfu[]` histogram shows FIVE micro-functions, including the two I reported absent:

```
  [after PLACE-DOMAIN]  micfu[1B:162  12B:1  23B:1  24B:1  31B:13]
  startSeen=1 startMicfu=23B startTaken=True   restarts=1/1   swpfu[LNEWSWAP:2]
  ansMON=377B   PC=0x08008255 stopMode=WAIT    THA=0x00000000
```

The swapper **starts, runs, calls MON 377B, is answered and parks** - the designed idle. Place-domain
gets much further than the sample suggested.

**SENTINEL REMOVED - section 124, red-first, 2264 green.** `Registers.DitConfigured` replaces the
`DITBASE == 0` test in all 22 guards; `DeclareDitBase(uint)` declares a base WITHOUT clearing (for a
guest-owned table) while `SetupDIT` keeps clearing (for an emulator-owned one);
`MMUConfiguration.ApplyToCpu` now marks configured. Both new tests were RED first - and the second
one PROVED that `SetupDIT(0)` erases a guest-written table, which would have produced an unchanged
`THA=0` and read as "the fix did nothing" a third time.

**DECLARED BASE 0 - AND IT IS WRONG. Section 125.** `THA` is still 0. The declaration DID run, so
this is not another inert fix: `PHYSRD`/`PHYSWR` are **SEGMENT-RELATIVE**, and the harness line I
read the addresses off prints the RAW OPERAND with a comment saying so - *"Operands are ND-500-side
byte offsets"*. So `0x96..0xC4` are offsets INSIDE a physical segment, and the DIT base is
`PST[segment] page * 2048`, not 0.

**The LAYOUT survives; only the BASE was wrong** - section 115 conflated the two. The twelve offsets
still land on `struct pcb` field starts with the `0xBA/0xBB` byte-field hole predicted, and the
`LOADCT_*` decode is DPA-relative so it never spoke to the base at all.

**NEXT, one run:** the segment is in the message (`MSWMC`) and the servicer already formats
`PHYSWR seg=... off=... -> ND500 phys 0x...`, but that note does not reach the harness capture.
Surface it, resolve `PST[seg]`, declare THAT base. Prediction stays one value: `THA` non-zero after
a completed 3START.

**DONE, and this file's instruction was pointing at the wrong file (2026-09-02).** It said
*"`ND100Machine.ND5000.cs` currently declares 0 and must be corrected"*. That file has **never**
called `DeclareDitBase` - `git log -S 'DeclareDitBase'` on it returns nothing. The declaration lives
in `Nd500CpuProcessBridge.cs` (:403 and :866), it is already **learned rather than hardcoded**
(`servicer.ObservedDitBase`, computed at `Nd500MicrocodeServicer.cs:1649` as the resolved ND-500
physical address rounded down to the 256-byte PCB boundary, and at :2656 as `dest - offset`), and it
is guarded on the write COUNT so a legitimately-zero base is not mistaken for "nothing learned".
So the segment-relative correction is honoured in code; only this line was stale. A pointer comment
now sits at the attach site so the next reader does not go looking for a declaration there.

**Superseded note: Deliberately no blanket
default - base 0 is SINTRAN's layout, not universal (NDIX puts `pcbtab` at KVA `0xe0000000`), and
baking one OS's map into a shared path is the same class of error as the sentinel. **place-domain
will not change until the lane declares the base; do not re-measure expecting movement.**

**ROOT CAUSE - section 123. `DITBASE == 0` is the "not configured" sentinel, and 0 is the
CORRECT base for this system.** SINTRAN writes the DIT at ND-500 physical `0x96..0xC7` = PCB base
`0x00`, domain 0; the harness uses `PcbTableBase = 0x00` too. But every DIT reader opens with
`if (regs.DITBASE == 0) return 0;` - **22 such guards** - and nothing on the octobus lane ever sets
`DITBASE` (it appears only as a register accessor on the classic 3022 path). So a correctly
configured DIT at physical 0 is indistinguishable from no DIT, and every read is refused.

One cause, five symptoms: `THA=0`, trap enables never loaded, and BOTH the section-121 and
section-122 fixes measuring no change - they were correct and inert, downstream of a subsystem that
was switched off.

**THE FIX IS NOT A ONE-LINER, AND THE OBVIOUS VERSION DESTROYS THE DATA - section 123b.**
`SetupDIT(0)` looks like the way to declare the base; its second half **zeroes every 256-byte PCB**.
On this lane SINTRAN owns that table, so calling it would erase the trap config place-domain just
wrote - and the symptom would be identical to today (`THA=0`), for a different reason.

Three parts:

```
  1  replace the sentinel   21 functional guards test a DitConfigured flag (or nullable base)
                            instead of `regs.DITBASE == 0`. The 22nd (:1008) only picks a log
                            message - leave it.
  2  declare WITHOUT clearing   a separate entry point, or a SetupDIT overload that skips the
                            zeroing. Never zero a table the guest wrote.
  3  octobus attach calls it with base 0 - what SINTRAN uses and what
                            SwapperStartDiagnosticTests already assumes (PcbTableBase = 0x00).
```

**Red-first test:** write a recognisable value into a DIT field at physical 0, declare the base, read
it back. False today for TWO independent reasons - the sentinel refuses the read, and the only
declaration path would have erased the value first. Pin both.

**THE OLD FRAMING, kept because the chain is still the evidence:**

**THE GAP IS `THA=0`.** SINTRAN writes `pcb_tha` during place-domain; the process is started; the
microcode CNTXTLOAD reads DIT fields at start; our `StartProcessFromContextBlock` does not - it reads
ctx `0x00-0x60`, which has no trap-enable slot. So the CPU runs the process with no trap handler and
no enables. **Next change: load the DIT trap config in the PROCESS-START path** (section 121 hooked
it to cross-domain CALL, which is why it was inert). Falsifiable in one line: `THA` should be
non-zero after a completed 3START. Check WHICH fields first - CNTXTLOAD reads four bytes, the
LOADCT_* instruction reads twelve.

**Stop chasing 3SWMESS.** `Nd5800MicfuDispatchTableTests` proves `0o5` routes to `MSG_ILLEG` on the
B30 - the CPU does not implement it. The twelve SWPINFO stamps are the ND-100 driver's own routing
marker and can never become a CPU message.

**Where it really stops:** one cache-clear, then twelve words scattered into ND-500 LOW PHYSICAL
memory, all sourced from the same ND-100 staging cell `0x0000CC00`, then only watchdogs:

```
   0xBC 0xC0 0xC4     three words          bytes 0xBC..0xC7
   0xB6               one word             bytes 0xB6..0xB9   (0xBA..0xBB never written)
   0x96 0x9A 0x9E 0xA2 0xA6 0xAA 0xAE 0xB2  EIGHT CONTIGUOUS  bytes 0x96..0xB5
   0xA6 again         the 5th word rewritten
```

**ANSWERED 2026-08-31 - standoff section 115.** Those twelve words are the **Domain Information
Table (PCB) trap-enable block for domain 0**. Every write lands on a field START:

```
  0x96 ote1   0x9A ote2   0x9E cte1   0xA2 cte2   0xA6 mte1   0xAA mte2
  0xAE temm1  0xB2 temm2  0xB6 tha    0xBC tos    0xC0 ll     0xC4 hl
  (0xBA md, 0xBB ith are the only single-BYTE fields in the span - hence the never-written gap)
  (0xC8 pia is the first byte past the block)
```

So **`place-domain` is installing the trap configuration for the domain it is about to run** -
trap enables, the trap-handler vector, the stack pointer and the memory limits. This was open in
the deep dive since July as "the live blocker".

**FIXED, AND IT CHANGED NOTHING - section 121.** `LoadDomainStateFromDIT` now loads
OTE/CTE/MTE/TEMM as well as TOS/LL/HL/THA. Re-ran place-domain: MICFU census, MON restart counts and
every cell-write bucket are IDENTICAL; only watchdog counts moved with elapsed time. The method is
called only from cross-domain call/return, and place-domain never reaches a domain call - so the fix
is correct and currently INERT. **The "place-domain is quiet because the trap config is ignored"
hypothesis is REFUTED.**

Provenance regraded `[D]`: `LOADCT_*` is reached from `0o001041`, the MACRO-INSTRUCTION dispatch
band, so it is a load-context INSTRUCTION and does not prove a cross-domain CALL loads these. The
layout it gives still stands. The experiment to settle the trigger is named in the code comment.

**ANSWERED - section 116. The engine loaded THA but NOT OTE/MTE; the microcode loads both.**

```
  LoadDomainStateFromDIT:   TOS, LL, HL, THA   <- and nothing else
  regs.OTE1/2, regs.MTE1/2: never loaded from the DIT anywhere in the codebase
  microcode CNTXTLOAD 015103/015104: TE := SC4, accumulated at 015075 from DIT byte reads
```

The local-trap-enable gate reads the REGISTERS - correctly, per microcode `011034` - so the gate is
right and nothing fills what it reads.

**RAW DECODE DONE - section 117, and it CORRECTED section 116.** The block reads DIT bytes at DPA
`+0x16 (ote1, address setup only)`, `+0x3B (ith)`, `+0x26 (mte1)`, `+0x48 (pia)` - a third,
genuinely independent confirmation of the layout. But the bytes feeding SC4 are `ith` and `pia`,
single BYTES, **not** the 64-bit OTE/MTE pair, so "TE is loaded from the DIT trap-enable fields" is
NOT established. `TE,ALU,LOAD` is a control strobe and is not the `D,MIC,TE` destination.

**THE ASYMMETRY IS PROBABLY NOT A BUG - section 119.** ND-05.022.1 Table 1 says `THA`, `CTE` and
`TEMM` reside **only in the Domain Information Table**, while `OTE` and `MTE` have REGISTER homes in
gate arrays. So loading THA from the DIT is exactly right, and not loading OTE/MTE from it is
defensible. Second reason not to have patched it.

**A REAL DEFECT THE MANUAL DOES NAME `[M]`:** the same manual says the hardware trap enable is
**`MTE` ALONE when inside a trap handler**, and `MTE | OTE` only outside. Our gate ORs them
unconditionally:

```csharp
    ulong localTrapEnable = ((ulong)regs.OTE2 << 32) | regs.OTE1;
    localTrapEnable |= ((ulong)regs.MTE2 << 32) | regs.MTE1;   // <- no InsideTrapHandler test
```

`pcb.InsideTrapHandler` is right there - the dispatch condition below already uses it. Effect: inside
a handler we would deliver a trap only OTE enables, where hardware withholds it. **Confirm against
microcode `011034` before changing it** - manual loses to microcode in this project.

**NEXT STEP IS TO EXECUTE, NOT DECODE - section 118.** Static decoding has produced one over-claim
and one correction on this question already; the SSKIP precedent says stop decoding at that point.
All the pieces exist: `SwapperStartDiagnosticTests` drives IDLE -> MSG_START -> NEWCNTXT -> EXECUTE
on the microword CPU with a seeded DIT, `MmsUnit.SetDomainPia` shows how to seed a DIT field, and
the CPU models TE in both namespaces (`regs.MicTe`, `regs.IduTe`). Seed distinctive
`OTE1/OTE2/MTE1/MTE2`, run the context load, read TE.

**Byproduct already fixed:** `MmsUnit.PcbChildTrapEnableOffset` was `0xA6`, which is `pcb_mte1`
(MOTHER). Correct address, wrong name - it would have survived any check of the number. Nothing
consumed it, so nothing was miscomputed. Corrected to `0x9E` and the full trap-enable/limit map
added from the verified layout.

It would explain BOTH section 112a's undeliverable ignorable trap AND place-domain going quiet right
after installing a trap configuration the engine then ignores.

**Correction to this file:** it called that block a "write-then-read-back VERIFY". That is right for
`octobus-fullflow` (13 PHYSWR + 12 PHYSRD, 2026-07-28) but NOT for this run - the short bringup is
`NoStartSwapper`, so the verify half legitimately never runs. Do not read the missing PHYSRD as a
regression.

**Still unretired, from the 2026-07-28 file:** whether `addrA` should resolve to ND-500 LOCAL memory
rather than through `Nd500AddressBase` into the MPM window. A self-consistent round-trip hides the
difference, so a passing verify does NOT prove the target is right.

**Do NOT** re-investigate the swapper, `LNEWSWAP`, `5ACTSWAPPER` or the swap-wait FIFO - all
measured correct (sections 43/44/45). Do not read a STALL as "never happened" without checking the
timeout fired (section 64).

## 2 — Make START-SWAPPER post its start

**Measured state:** during `start-swapper`, 53 messages flow but `startSeen=0`, `startTaken=False`,
`swpfu[(none)]`. **`RUNSW` (FUNCS 054, `163621` in `030-S3SM5.dis`) DOES contain the code**:
`163725 SAA 7` loads `MSWSTART` = 7B and `163726 JPL I 170` calls the sender. So the sending code is
correct and execution never reaches it. Ahead of it sits a run of guarded precondition checks with
early error returns (`163621`-`163716`).

**Do this:** run the PC sampler over `start-swapper`, find which check the PC sits in, then fix that
precondition. Same instrument as step 1.

**Do NOT** conclude from `micfu[]` that `3SWMESS` was never sent - that histogram counts only
SINTRAN -> ND-500 messages and is structurally blind to it (section 68).

---

## 3 — DONE. `0x0006` is ACON WCS, and the control-store model was INVERTED

**Answered 2026-08-31 with Ghidra on octo.bin. Standoff sections 103 and 104.**

`0x00220000` is the **ACON decoder** (ND-05.020.01 p.113, table 9). `0x0006` is command `6h`,
**WCS - "write control store"**. All 23 distinct literals the firmware writes to that port decode
as ACON commands with the encoding's unused bits 11..5 zero in every one.

The bigger finding is that the two routines were the wrong way round:

```
  0x73B2  WRITE  24 callers  address phase + shift 8 words OUT (0x7776) + WCS.  NO GATE.
  0x741E  READ   17 callers  address phase + gate + AMIRCK (0x0018) + shift 8 words IN
  0x73EE  DEAD    0 callers  WCS with no shift - this was section 78's "control", and it never runs
```

`Nd5000ControlStoreLink` committed on `0x0018`, so **every read of the control store also wrote
it**, and the address was latched on `0x3010` (issued twice per write) instead of on ARMA `0x0015`
(issued once). Fixed, red-first:

```
  before:  COMMIT cmd=0x0006 ... + COMMIT cmd=0x0018 ...   writes 20972 -> 20974   FAIL
  after:   COMMIT cmd=0x0006 ... + CS-READ addr=0x0100     writes 20964 -> 20965   PASS
```

Held by `Nd5000ControlStoreWritePathTests` (replays ROM `0x73B2` and `0x741E` instruction for
instruction) and `AconDecoderTableTests` (sweeps the shipped ROM against table 9).

**What is left of this item:** re-measure the real CS load end to end. `gateOpens` moved 13 -> 1502
on the same command, so the card's behaviour changed substantially and that has not been
characterised yet.

## 4 - Implement every microword field properly

Throw, log and die on anything missing. Never tolerate. **Progress is measured in fields
IMPLEMENTED, never in halts removed.**

**FIVE FIELDS IMPLEMENTED 2026-08-31 (standoff 150), and the inventory below could not see any of
them.** `COND,CALL` (60), `COND,ENTM` (61), `COND,ENTT` (62), `COND,JUMPG` (63) returned a
hard-coded `false`, and `G,TOOPS` (GET 14) was coded as an alias of `G,OOPS`. Details and manual
citations in item 6b; the point for THIS item is the method:

> **AN UNIMPLEMENTED FIELD THAT RETURNS A PLAUSIBLE ANSWER IS INVISIBLE TO A THROW-SITE COUNT.**
> The 25-site list below is an inventory of places that ADMIT they are missing. A `return false`
> and an `[D: same]` alias admit nothing - they answer, the machine keeps running, and the whole
> feature silently does not work. Every ENTT in the image was being refused, and no throw, no
> failing test and no sweep divergence said so. The sweep could not: ENTT is unreachable from the
> corpus, which is exactly the condition that hides this class.
>
> **So the inventory needs a SECOND axis: fields whose implementation is a CONSTANT.** Grep
> `Conditions.cs` and the GET/DEST switches for arms that fall through to a literal or to another
> arm's behaviour, and check each against its manual line. Cheap, and it found five in one pass.
>
> **THAT SWEEP IS NOW RUN, and it paid out again (2026-08-31, standoff 151).**
> `Conditions.cs` is CLEAN - three constant arms remain (`COND,ENTER` 32, `COND,PDONE` 36,
> `COND,IRALT` 59) and each has a documented reason; `COND,IRALT`'s `false` is genuinely correct
> for the current machine, not a placeholder.
> The DEST switch was not clean. Five destinations carried "treated as a plain X load [D]" and
> wrote the microword's own value; ND-05.022.1 ch.8 gives each a FIXED SOURCE:
>
> ```
>   197 D,IAC,SUML     SUM IS TRANSFERRED TO IAC Y REGISTER    0 sites  -> left as-is, [OPEN]
>   205 D,IAC,CLKNPC   LA -> NPC                               0 sites
>   206 D,IAC,CLKP     NPC -> P                                1 site   0o4465
>   207 D,IAC,CLKSP    P -> SP                                 2 sites  0o11535, 0o14407
>   227 D,DAC,SUMB     SUM IS TRANSFERRED TO DAC B REGISTER    0 sites  -> left as-is
> ```
>
> **The count came FIRST and it halved the work** - three of the five are phantoms, exactly like
> ORCON.A ALTEN. The manual line alone would have had us implement all five.
> **What proves the manual right at the live sites is the microcode, not the manual:** 0o11535 is
> `ALU,XOR A,BM00 B,X1 D,IAC,CLKSP` - and `XOR BM00,X1` is this project's own documented NO-OP
> FILLER, the word that exists only to time the one-word condition delay. A word whose ALU result
> is timing filler cannot be storing that result, so the destination must ignore the bus. We were
> writing filler into SP. 0o4465 agrees: `XOR A,IAC,L B,SC14` into P, and an XOR of L with SC14 is
> not a program counter.
> **Both live sites are in code item 7 cares about:** 0o11535 sits in the LREGBL register-block
> loader (beside `LOADRB_P`/`LOAD_NEW_P`/`LOADRB_L`/`LOADRB_B`) and 0o14407 is inside RETT, just
> past `RETT_NPLBR`. Sweep: `MicrowordDecodeTests.ConstantAnswerDestinations_HowManyB30WordsUseThem`.
> Free corroboration: `D,DAC,SUMB` and `D,DAC,B` both having ZERO sites is a THIRD independent
> confirmation of standoff 145 - B's only live write port on this image is destination 228.
> **MEASURED AFTER THE CHANGE, both suites, 2026-08-31:** ND5000 **766 passed / 0 failed**;
> `Emulated.Tests.ND500` **2264 passed / 0 failed / 13 skipped** (4 m 29 s), which is the baseline
> exactly. So the three reclock strobes are a strict improvement - nothing depended on SP/P/NPC
> carrying the bus value, including the two suites that cover `LREGBL` and `RETT`.
> The tell that started it was not a throw - it was a microword PATH TRACE showing a branch taking
> the same arm no matter what the inputs were.
>
> **THE CLASS IS NOW SWEPT, 2026-08-31 (negative result, recorded so it is not re-run).** The
> constant-answering field is the defect shape that hid BOTH ENTT bugs, so the whole package was
> re-checked for more of it. A grep for `[D: same]` over `CPU.ND5000/src` now returns only the two
> lines that DOCUMENT the G,OOPS/G,TOOPS pair, and `ReadA`/`ReadB`/`Conditions.cs`/`Alu.cs`/
> `Sequencer.cs` contain no bare `return 0` arm standing in for an unimplemented select. The
> remaining unimplemented fields all THROW, so a throw-site inventory is once again a true
> inventory of them - which it was not before this sweep.


**THE WORK LIST, enumerated 2026-08-31** (it used to live only on the task, which is exactly what
this file is for). 25 throw sites in `CPU.ND5000/src`, and they are NOT 25 gaps - they split:

**Real field gaps - each is parameterised by mnemonic, so one site covers many field values:**

```
  CpuND5000.cs:1146   Memory operation {mnemonic}
  CpuND5000.cs:1260   IDU fetch control {getMnemonic}          (P5)
  CpuND5000.cs:1732   Conditional fetch with ABR value {Abr}
  CpuND5000.cs:3473   Status operation {mnemonic}
  CpuND5000.cs:3752   Address B operand {mnemonic}
  CpuND5000.cs:3864   Post-index scale for data type {dataType}
  CpuND5000.cs:3885   Data type {dataType} memory access
  CpuND5000.cs:4193   Operand specifier 0x{b0}                  (P5 slice)
  CpuND5000.cs:4383   ORCON.A value {orconA} (ALTEN/none)
  CpuND5000.cs:4447   ORCON.D value {orconD} (ALTEN)
  Conditions.cs:264   Test condition {mnemonic}
```

**Correct guards - NOT gaps, do not "fix" these by removing the throw:**

```
  1806 CALL argument not a memory operand      1957 opcode has no dispatch entry
  1863 CALL to segment 31 (the MON trampoline) 2032 ENTER/RETURN frame-op guard
  2376 did not retire within N microwords      3798 SCAL value undefined
  3859 post-indexed TYP,BI (deliberate, documented)
  4427 ORD,OP with a constant operand          4445 ORD,OP1 with no stored first operand
  4454 memory op with no memory attached
  2495 / 4352 / 4399 / OperandRouter:100  "no register-in-instruction metadata"
```

**BEFORE IMPLEMENTING ANY ENTRY, RESTRICT ITS B30 COUNT TO REACHABLE SITES.** Raw sweeps have twice
invented work that did not exist. **Done for the ALTEN pair 2026-08-31**
(`MicrowordDecodeTests.AltenArms_HowManyB30WordsCouldReachThem`), and it splits them:

```
  words with OR_ENABLE set                              1079
  ORCON.A == 3  raw 532   guarded (OrEnable AND AOp==63)   0   <- UNREACHABLE, nothing to implement
  ORCON.D == 3  raw 395   guarded (OrEnable)              48   <- REAL, and bounded
```

The guards are taken from the call sites, not guessed: `orconA = (Orcon >> 2) AND 3` is only reached
when `OrEnable != 0 AND AOp == 63` (`CpuND5000.cs:2465`); `orconD = Orcon AND 3` at `:3158`.

So the raw numbers suggest ~900 words of work and the truth is 0 and 48 - **`ORCON.A` ALTEN is a
phantom, confirmed a second time.** Implement `ORCON.D` ALTEN only.

**48 is an UPPER BOUND**: the destination path may carry guards beyond `OrEnable` that this sweep
does not model.

**ENUMERATED - section 127. They are ONE FAMILY.** All 48 carry `ORCON=0x03` exactly and sit in a
single band `0o5717..0o10054`, whose labels are `MBR_*` (move block reverse), `MBF_*` (forward),
`BMOVEBY_*` and `BMOVEHW_*` - **the block-move / string-move family**, which is precisely what
ND-05.022.1's `ORD,ALTEN` (561) "OR destination from string DEST. operand" exists for.

**CORRECTION - section 129: `STRING_sfill` is 168/168 MATCH, 0 diverge.** The "fails all 168" claim
came from a stale skill note; the sweep's own history records the fix. Whole sweep is
match=23933 diverge=1424, ABOVE the baseline floor. **So ALTEN has no failing measure behind it** -
it is real unimplemented hardware, not a live defect, and its priority drops.

**The sharper question:** 48 words in the image reach `ORCON.D` ALTEN and it throws, so why does
nothing fail? Either no corpus vector executes those 48, or the block-move family has no golden
coverage. **Reachable IN THE IMAGE is not executed BY A TEST** - settle that before writing the arm.

**BUT ALTEN IS NOT FIRST - section 128.** The four OR-destination arms are symmetric, and ALTEN needs
an ALT operand triple that something must populate. That something is `G,OPSTRD`, and it is **not
missing - it is FLATTENED** onto `G,OPS` (`CpuND5000.cs:1188`, graded `[D]`), so the operand stream
advances and the DESCRIPTOR is lost. Its own `[OPEN]` predicted this: *"a string operand is a
descriptor, not a scalar ... if a string instruction ever reads the wrong operand, revisit here
first"* - and the SFILL remark records exactly that, a fill of the right LENGTH at the wrong ADDRESS
using the descriptor's element count as the base.

```
  1  G,OPSTRD delivers the string DESCRIPTOR, not just an operand advance
  2  an ALT triple then exists for ORCON.D ALTEN's 48 block-move sites to route to
  3  the 168 STRING_sfill vectors are the measure, already failing
```

## 5 — DONE. Single-float `-0.0` TEST follows the microcode

Ronny adjudicated the microcode over manual 10.11, scoped to SINGLE only. `Test.cs` now computes
S = "sign bit AND the SRF4-masked value is non-zero", so `-0.0` tests as non-negative. The DOUBLE
branch deliberately keeps the raw sign bit - its flags come from a C#-side recompute, so applying
the rule there would create a divergence rather than remove one. 13/13 green.

## 6 - Model TOS/THA on the microword CPU

Not modelled at all.

**The `IduHl`/`IduLl` "do the names cross?" question is HALF ANSWERED - the DIT side does NOT
cross.** Raw decode (`ContextLoad_TrapConfigRoutines_RawDecodeDump`, standoff section 120):

```
  LOADCT_TOS 0o11163  reads DPA+0x3C -> PCB 0xBC pcb_tos
  LOADCT_LL  0o11164  reads DPA+0x40 -> PCB 0xC0 pcb_ll
  LOADCT_HL  0o11165  reads DPA+0x44 -> PCB 0xC4 pcb_hl
```

`MmsUnit`'s `PcbTopOfStackOffset=0xBC`, `PcbLowLimitOffset=0xC0`, `PcbHighLimitOffset=0xC4` all
match. So the suspicion that `MmsUnit`'s constants are mislabelled was RIGHT IN GENERAL - one was,
`PcbChildTrapEnableOffset` sat on `pcb_mte1`, fixed in section 118 - but NOT for the limit fields.

**Still open: the REGISTER side.** Both `LOADCT_LL` and `LOADCT_HL` write `Dest=22` and converge on
the same tail at `0o11211`, differing only in `ORCON` (`0x00` vs `0x04`) - so the destination is
selected by the OR-control field, not by the Dest field, and which of `A,IDU,HL` (161) /
`A,IDU,LL` (162) each one lands on is NOT readable from the Dest column. **Settle it by execution as
this item always said:** seed distinct values at PCB `0xBC`/`0xC0`/`0xC4`, context-load, read
`regs.IduHl`/`regs.IduLl` back. Do not infer it from ORCON arithmetic.

## 7 - Adjudicate the remaining engine divergences

**TRIAGED 2026-08-31 - section 131.** Golden-vector landscape: 125 files, match=21729,
diverge=1408, unsupported=1140.

```
  PACKED DECIMAL   792 = 56% of all divergence   values 100% CORRECT, FLAGS ONLY
                   psub/psubr are 360/0 - the engine is not broken
  ARITHMETIC_rem   match=0 diverge=200 unsup=280 - NOT A TARGET, see below (section 137)
  __div_ / __mul_  60 / 41
  transcendentals  acos 40, alog2 36, alog10 32, alog 24
```

**`ARITHMETIC_rem` IS A DEGENERATE CORPUS, NOT A DIVERGENCE - standoff 137, measured 2026-08-31.**
All 480 vectors are REM-BY-ZERO; all 480 expect `ST=0x1000` (DZ) and nothing else; **256 of the 480
are EXACT duplicates** (224 distinct inputs, one repeated 35 times). The 280/200 split is just the
`F REM`/`D REM` file composition. No vector computes a remainder, and `MacroOracleState` has no DZ
flag, so the only thing the corpus asserts is not even in the oracle's compare set. Regenerate it;
do not chase its numbers.

Under it, two real things, and the first belongs to item 4 not item 7:
 - `F REM` dies on a **missing UPSTREAM dest-bank intercept** for select 31 (the ordinary macro
   REG37 port), so it falls through to `OperandRouter`, which has no case 31 because it should never
   see one. **Do NOT "fix" this by adding `case 31:` to the router** - that stops the die and starts
   writing the wrong bank silently, which is the exact trap in the standing rule.
 - `D REM` diverges on **Z alone** (microword Z=1, functional Z=0). One flag, needs adjudication.
Diagnostic: `RemOracleDiagTests` in the ND-5000 tests.

**KNOWN RED, pre-existing (verified by stashing my own change and re-running): the ND-5000 suite is
755 passed / 4 failed / 3 skipped of 762** - `Entt_TrapFrame_CannotBeDriven_HardFail`,
`Rett_TrapReturn_CannotBeDriven_HardFail`, `Trace_OfRealColdBoot_RecordsAddressesLabelsAndRegisterDeltas`,
`BothEngines_ProduceTheSameMonitorCall`. Not triaged yet.

`ND5000-PACKED-DECIMAL-Z-FLAG-BOTH-CORES-WRONG-2026-07-28.md` already has the packed case worked:
corpus was degenerate and fixed (`77620f6f3`), values verified correct, `ST,LOAD`/`AluSts` theory
experimentally REFUTED, and the analogous float `-0` verdict is **corpus wrong, microword + manual
right** (ND-05.020.01 §9.5). **So the biggest block needs a real-hardware datapoint, not more
analysis.**

**Do `ARITHMETIC_rem` first** - it is the only large one that is genuinely unimplemented and needs no
datapoint.


**SSKIP: DONE 2026-08-31.** The real B30 sets `Z=1` on EVERY non-trap termination - it does not
distinguish "source empty" from "different element found". Manual 14.14 says otherwise and the
microcode overrules it, as it did for the BI TEST carry and the single-float TEST sign. `CpuND500`
was implementing the manual faithfully and was wrong on two of three cases; fixed in
`Emulated.HW\ND\CPU\ND500\Instructions\STRING\Sskip.cs`, both engines now agree on all three
vectors with `I1` still 3/4/0. Standoff section 107.

**SCHPAR: still open, blocker named.** The vector does not retire on the microword - parked at CS
`0o10357`, which the `.LABE` shows is the `M01`/`M02` per-element scan loop under `SCHPAR_MODE`
@`010352`. The harness is not supplying what the mode dispatch needs. Fix the SETUP before reading
anything into SCHPAR's flags, and note that `0o10364 -> 0o10361` is the shared EXIT of four arms,
not a loop back into a loop body.

**Method that made SSKIP work, and is worth reusing:** one vector could only be believed, never
checked - and the obvious patch from it (invert one arm) would have been wrong. Three vectors
covering all three terminating conditions showed the whole branch was wrong. Then, because the
answer came back constant, `I1` was added as the discriminator: a flag that reads 1 for every input
is indistinguishable from an instrument that never ran.

## 6b - BUILD THE ENTT/RETT TRAP FIXTURE (Ronny chose this 2026-08-31)

**Decision taken:** the two permanently-red tests `Entt_TrapFrame_CannotBeDriven_HardFail` and
`Rett_TrapReturn_CannotBeDriven_HardFail` (`CallManualCoverageTests.cs` 611/623) get a REAL fixture,
not an `Assert.Ignore`. Rationale: a suite that can never go green cannot signal a new failure -
proven on the same day, when two genuine false reds sat beside them unnoticed (standoff 139).

**The "not drivable" claim is about the ORACLE'S API, not the machine.** Verified 2026-08-31:

```
    map[188] = new DispatchEntry(443, -1, -1);   // 0xBC ENTT [labe]   entry 000673 octal
    map[131] = new DispatchEntry(456, -1, -1);   // 0x83 RETT [labe]   entry 000710 octal
    .LABE also has ENTT1/ENTT2/ENTT_REGS/ENTT_DITS/ENTT_STAH/ENTT_CLRTS/ENTT_TRRET/ENTT_STARTE
```

Both instructions are dispatched and implemented in the real B30. The precedent for extending the
oracle already exists - ENTSN was "not drivable" until `RunBoth` gained
`pendingCallReturn`/`pendingArgCount`/`tosSeed`, and it is green now.

**What has to be seeded, and the two sides differ - this is the whole job:**
 - FUNCTIONAL (`Entt.cs`): `pcb.InsideTrapHandler`, `pcb.PendingTrapNumber`, `pcb.TrappingPC`,
   `pcb.ResumePC`, `regs.THA`. All C# properties - straightforward.
 - MICROWORD: there is **no `InsideTrapHandler` property in `CpuND5000` at all**. The flag lives in
   the PCB IN MEMORY - `MmsUnit.PcbInsideTrapHandlerOffset = 0xBB`, which is `pcb_ith`, the same
   single-byte field identified in standoff 116. So seeding it means laying out a real PCB and
   pointing the CPU at it, not setting a property.

**Order of work:**
 1. **DONE 2026-08-31 - standoff 140.** `EnttReadTraceDiagTests` drove both from their `.LABE`
    entries with nothing seeded. **Neither routine hits an unimplemented microword** - ENTT ran its
    full 400-tick budget, RETT ran 194 and ended on the unseeded `P=0`. So the microword side needs
    only SEEDING, not implementation. Measured seed set: PCB bytes `0xBB` `pcb_ith` (the flag),
    `0xBA` `pcb_md`, `0x9A` `pcb_ote2`, plus `0xB6` `pcb_tha`; and a saved register block at `0x14`
    upward. RETT's stores confirm the PCB layout independently - it writes `0xBB`(ith), `0xBC`(tos),
    `0xC0`/`0xC4`(ll/hl), `0xB6`(tha), `0xA6`/`0xAA`(mte1/mte2). **`pcb_md` is NOT in the functional
    engine's requirement list**, which is exactly why the microcode was asked first.
 2. **DONE 2026-08-31 - standoff 141.** `MacroInstructionOracle.TrapSeed` seeds both engines from
    one description - PCB bytes for the microword side, `GetPCB(0)` fields + `regs.THA` for the
    functional side. Both hard-fail tests replaced by real drives.
 3. **IN PROGRESS.** Both tests now execute the instructions and are red with a MEASUREMENT
    rather than a refusal. Two things left, in this order:
    a. **ANSWERED 2026-08-31 - standoff 143. ENTT CANNOT BE SEEDED INTO LEGALITY.** A 2x2x2 matrix
       over `pcb_ith` x `pcb_pia` x pending-call gave EIGHT IDENTICAL results (48 writes, zero into
       the frame, always ISE). The gate is `COND,SAVC1` at `ENTT1` @`014042`: true goes to the body,
       false falls one word to `TRAP_ISE` = the 0x23 = 35 the probe recorded. **`SAVC1` is an
       INTERNAL saved condition - not a PCB field, not a memory cell** - so no seed can set it. Same
       mechanism as the classic store's `AM#37`, which our own memory note already described as "the
       CALL-in-flight interlock". Frame base confirmed as `SC7 + 256` = THA+256, so the instrument
       was always pointed at the right address.
       **THEREFORE: ENTT must be ARRIVED at, not seeded** - drive an instruction that genuinely
       traps, let the microcode take its trap entry and set the condition, then run ENTT as the
       handler's first instruction. Forcing `SAVC1` from outside would prove nothing about the path
       SINTRAN actually takes, so it is not an option.
       **DONE 2026-08-31 - standoff 150. THE ARRIVAL IS BUILT AND ENTT RUNS.** Test
       `Entt_ArrivesThroughTheTrapPath_AndBuildsTheFrame`. Measured path, in order:
       `TRAP_START 014031 -> 014036 G,TOOPS -> 014037 -> 014040 CSAVE -> 014041 G,COOPS ->
       ENTT 000673 -> 674 -> 675 -> ENTT1 014042 -> ENTT2 014044 -> 014045 -> ENTT_REGS 014046`.
       Exactly one TRAP_ISE on the way (the deliberate stimulus), `SavedCond1 = 1`.
       **Two real engine defects had to be fixed, and neither was a seeding problem:**
        - `COND,ENTT` (62) and its siblings `COND,CALL` (60), `COND,ENTM` (61), `COND,JUMPG` (63)
          were hard-coded `false` in `Conditions.cs`. All four are documented one-liners in
          ND-05.022.1 ch.8 ("MACROINSTR. IS ENTT"), answered from the instruction register:
          CALL 0xC3, ENTM 0xDF, ENTT 0xBC, JUMPG 0xB4. New field `Registers.InstrOpcode`.
        - `G,TOOPS` was coded as identical to `G,OOPS` (the comment said `[D: same]`) and so
          DISPATCHED to the instruction it is only meant to LOOK at. ND-05.020.01:2432: "G,TOOPS is
          used to test if the target instruction is ENTT, ENTM, etc., and it only needs IMAP
          information." With it dispatching, 014036 jumped straight to 000673, skipping the CSAVE at
          014040 - so the gate always read 0 and EVERY ENTT was refused. Now `PeekInstructionForTest`
          publishes the opcode without dispatching and without advancing P (014041's G,COOPS does
          the real fetch). `COND,ENTER` (32) deliberately left false: MICROCODE-FIELDS.md says
          "ENTF/ENTM/ENTT" but ND-05.022.1 says "CHECK FOR ENT- INSTRUCTIONS", and the two readings
          disagree about ENTS/ENTB. [OPEN]
       **Bonus fact the machine handed over, worth not re-deriving:** `pcb_tha` (0xB6) points at a
       TABLE of handler addresses indexed `THA + trapNumber*4`, NOT at a handler. TRAP_START reads
       that entry (measured `CS 14032: [0000508C]`, THA 0x5000, ISE trap 0x23) and a zero entry
       falls out to TRAP_ERR - which is ND-05.020.01:3222's "THM, trap handler missing ... when no
       ENTT instruction ... is found as a trap handler entry" seen from the microcode side. The
       own-trap-enable words are `pcb_ote1` 0x96 / `pcb_ote2` 0x9A; with them zero the trap is
       routed to the ACCP/mailbox instead and TRAP_START is never reached at all.
       ND5000 suite **765 passed / 0 failed** (was 757 with 2 permanently red).
    b. **DONE 2026-08-31 - standoff 144.** RETT's frame is **B-relative** (measured by making B and
       THA differ; with both zero the two addressing models were indistinguishable). Seeded, and
       RETT now drives on both engines. **ONE genuine divergence remains: the microword engine does
       NOT restore B from the frame (B stays 0x2000) while the functional engine does (B becomes 0).**
       **RESOLVED THEN REVERTED - standoff 147.** The carve HOLDS: the classic lane independently
       enumerated twelve `D,B` writers on `CONT-STORE-10611` (different image, different count) and
       read RETT's body word by word - no B write on either generation. But removing
       `regs.B = savedB` took `Emulated.Tests.ND500` from **2264/0 to 2252/12**, so the change is
       **REVERTED** and parked as a patch in the scratchpad.
       **The live hypothesis is that the functional engine's B restore COMPENSATES for something
       genuinely missing elsewhere** - which makes the carve correct and the change premature, and
       makes the twelve failures point at the missing thing rather than at RETT. First name to
       surface was `Ents_PendingCall_SurvivesPageFaultTrapAndRett` (the CALL/ENT sequence interlock
       across a page-fault trap) but that run straddled the revert, so it is a LEAD, not evidence.
       **CLOSED 2026-08-31 - standoff 149.** All twelve names captured in a coordinated window
       (binary timestamp verified AFTER the source edit). **FIVE files, and only ONE is a
       trap-semantics test** - the other eleven are real program execution (NC-A06 prompt and HELP,
       CPU-STAT, CAT-500, the byte-exact compile AND link vs the C emulator). So the B restore is
       LOAD-BEARING, standing in for the handler's `LREGBL` register-block load that our trap-return
       path does not model. Tree is behaviour-identical to HEAD with a 37-line comment recording the
       whole chain. **The remaining work is to model the handler's register-block load; only then can
       the assignment go.** Not scheduled - it is a real feature, not a cleanup.
       Also fixed: PCB bytes removed from the memory compare - the engines store the trap flag in
       different places (memory vs object), so comparing that cell manufactured two false
       divergences.
    **STILL OPEN in 6b:** the manual's frame-slot assertions (Ref 6.4 / 13.10-13.11), and a
    CROSS-ENGINE ENTT comparison - the functional engine has no trap-arrival seam the oracle can
    drive, so the current ENTT test is microword-only and says so.

**This also unblocks item 6** (TOS/THA on the microword CPU), which needs the same PCB-backed
trap context, and item 4's trap-path fields.

## 8 — Lock every fix with a red-first regression test

Prove it RED before the fix and GREEN after. A test never seen red is not evidence.

Done for item 3: `Nd5000ControlStoreWritePathTests.WcsWrite_LandsOneMicrowordAtTheAddressedLocation`
was red ("Expected: 1, But was: 0") before the WCS commit existed and green after. Still owed for
items 1, 2 and 4.

**One honest caveat on that fixture.** Its sibling `AmirckRead_DoesNotWriteTheControlStore` passed
BEFORE the fix as well - not because the model was right, but because the isolated sequence never
staged eight words, so the old commit path bailed out. It is a valid guard now; it was not evidence
then. A test that is green for the wrong reason proves nothing.

## 9 - Finish the ND-500 conformance corpus triage

**RUN IT LIKE THIS.** The fixture is `[Explicit]` ON PURPOSE (16 MB machine per case, no failure
limit, exceeds the CI blame-hang timeout), so a default `dotnet test` SKIPS it and a green ND-500
suite says nothing about these rows. Comment the attribute out, build, **restore the source
immediately**, then run `--no-build` - the binary keeps the gate off and the tree is never left
edited. A rebuild of `Emulated.Tests.ND500` mid-run silently re-arms the gate and the run just stops
finding cases, which looks like success: **read `Loaded 40082` before quoting any failure number.**

**State after 2026-08-31** (was 266):

```
  Loaded 40082  Executed 36427  Passed 36185  Failed 242  NegativeOK 3655   99.34%
  36185 + 242 + 3655 = 40082    <- always reconcile this before quoting anything
```

**196 of the 242 (81%) are the corpus being WRONG, not the engine** - 184 divide-by-zero plus 12
SFILLN. Divide-by-zero: the corpus expects the
destination unchanged; the real B30 SATURATES to the dividend's sign, confirming the 2026-07-26
adjudication. Standoff section 110. **Do NOT regenerate those rows** - the corpus is a shared fixture
with nd500x and regenerating it from `CpuND500` would bake our answer in and destroy the only
independent source that disagrees. The genuinely open question is whether real HARDWARE suppresses
the destination write on a precise trap; neither engine can see that, and if it does, both of ours
are wrong together.

**16 more are the "documented overflow" rows** - `add2 MAX+1`, `mul2 MIN*2`, `div2`/`div3`/`/`
`MIN/-1` - which expect an `IntegerOverflow` trap to be DELIVERED. Integer overflow is an
**IGNORABLE** trap by our own trap table, delivered only when `TE` bit 9 is set, and every one of
those vectors starts `st: 0` with no trap-enable. **RAN IT - now `[V]`, sections 112 and 112a.** The
overflow IS detected and the trap IS raised; delivery needs FOUR conditions
(`dispatch AND enable AND THA != 0 AND not-in-handler`), and the corpus register model has none of
`OTE/MTE/THA` - its own generator says so. So no corpus row of this shape can ever be right.
Test: `TestND500_IgnorableTrapDelivery`.

**STILL `[OPEN]`:** whether we WOULD deliver given a fully configured domain. Setting `OTE1` bit 9
plus a raw `THA` did not dispatch, for an unidentified reason - `GetTrapHandlerAddress` resolves
through the domain/DIT and a translated vector read. Closing it needs a DIT-backed domain with a
real Start Address Vector.

```
  184  divide-by-zero    corpus wrong                    [V]
   12  SFILLN H and W    corpus wrong                    [V]
   16  overflow traps    corpus CANNOT express delivery  [V]
  ----
  212  of 242 accounted for; 30 rows still uncharacterised
```

**The rest of the tail, triaged 2026-08-31 (standoff section 113):**

```
  184  divide-by-zero        corpus wrong, B30 verified                [V]  s110
   12  SFILLN H and W        corpus wrong, copies of the BY row        [V]  s111
   16  overflow traps        corpus CANNOT express delivery            [V]  s112/112a
    9  privileged SYSTEM     corpus does not grant PIA (but COULD)     [V]  s113
    2  TSET register operand generator artefact                        [D]  s113
    1  Test_F_NegZero        DELIBERATE divergence - KEEP IT RED       [V]  s113
  ----
  224  of 242 = 93% accounted for
   18  left: Chain 4, Div4 4, Riom 2, Scopt 2, Sspan 2, Sscan 1, Schpar 1, +2
```

**`Test_F_NegZero` MUST STAY RED.** It expects `ST=0xA0` (Z+S); we give `0x20` (Z only) because of
the single-float `-0.0` rule Ronny adjudicated in item 5 - the B30 computes S as "sign AND the
SRF4-masked value is non-zero". It looks like a trivial one-row float fix and it is not: fixing it
reverts a microcode-adjudicated decision.

**The 9 privileged rows are the ONE cluster the corpus could fix itself** - PIA is ST1 bit 1 and the
`st` field can carry it. The trap-enable rows cannot be fixed that way: `OTE`/`MTE`/`THA` have no
slot in the corpus register model at all.

**The method that made this tractable, do not skip it:** ask the microcode, with a vector chosen so
the competing hypotheses predict DIFFERENT numbers, and keep any non-discriminating vector visibly
labelled so it is never counted as confirmation. Divide-by-zero needed dividend `0x64` for exactly
that reason, and `0x7F` is in the probe marked inert.

---

## NOT THIS LANE / DEFERRED

 - ND-500 classic 3022, the DOM corpus, NLL work — `nd500uc-47`.
 - nd100x/nd500x integration over ndbus — **deferred by Ronny**, gated on RetroCore's own ND-500 and
   ND-5000 CPUs being validated against `nd-500-mon` first. Do not start it, do not design the seam.

---

## BUILD OUT OF TREE - this removes session contention entirely

Two sessions share `E:\Dev\Repos\Ronny\RetroCore`. A running testhost holds
`Emulated.Testsin\Emulated.HW.dll`, so the other session's build dies on MSB3027 and leaves the
tree SPLIT - `Emulated.HWin` newer than `Emulated.Testsin` - after which the next run may load
the old DLL. One source tree, only the output moves:

```bash
  dotnet build Emulated.Tests/Emulated.Tests.csproj -nodeReuse:false -o 'D:
c-bin\out'
  dotnet vstest 'D:
c-bin\out\Emulated.Tests.dll' --TestCaseFilter:"..."
```

Proven by `nd500uc-d4` on 2026-08-31: a full 6-minute capture ran out of that folder while another
testhost held `Emulated.Testsin`, with no collision.

**Two traps, both measured:**
 - **`-p:BaseOutputPath` LOOKS like it works** - clean build, 0 errors - and silently writes nothing
   anywhere. A build that succeeds at doing nothing, and then you test a stale binary. **Use `-o`.**
 - `-p:BaseIntermediateOutputPath` breaks the MC68K source-generator project, so `obj/` stays in the
   tree.
 - **A THIRD trap, measured 2026-08-31: any test that locates its DATA by walking UP from the test
   binary SILENTLY SKIPS out of tree.** `JsonVectorSweepTests.VectorDir()` climbs from
   `TestContext.CurrentContext.TestDirectory` looking for `Emulated.Tests.ND500`; from
   `D:
c-bin\...` there is no repo above it, so it returns null and the test calls
   `Assert.Ignore`. The run reports **exit 0, `Skipped! - Failed: 0`** - green-looking, and it
   measured nothing. Out-of-tree is safe for self-contained tests; **any golden-vector or
   corpus-driven test must run IN TREE.**

**And do not trust the cross-session idle notice as "their run finished."** It fired twice on
2026-08-31 (03:06 and 11:53) while a background test was still executing - idle means the TURN
ended, not the RUN. Check the testhost's CPU time instead; a live octobus run sits at ~35-40 s of
CPU per wall minute.

---

## HOW TO RUN THE OCTOBUS HARNESS - copy this, do not retype it

**BOTH environment variables are required. Dropping the pack override does not fail loudly - the
test goes INCONCLUSIVE and prints four zero-writes that look exactly like a real measurement.**
Cost of learning that: one wasted run, 2026-08-30.

```bash
cd E:/Dev/Repos/Ronny/RetroCore
export RETROCORE_ND5000_WATCH=swmess     # or runsw, for the START-SWAPPER blocks
export RETROCORE_ND5000_PACK='C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\DOMS-CSFIX.IMG'
dotnet test Emulated.Tests/Emulated.Tests.csproj -nodeReuse:false -p:UseSharedCompilation=false \
  --no-build --filter "FullyQualifiedName~ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture"
```

 - **FILTER TO ONE TEST.** `~Nd100SintranNd5000OctobusBootHarnessTests` matches the WHOLE CLASS and
   spends over an hour on `NllInstaller_RunFiveModules`, `NllFloppy` and `FullFlow` before reaching
   the one you want.
 - **BUDGET ~31 MINUTES for the one test, not "2-4 min".** Measured 2026-08-31:
   `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture` took **30 m 46 s** and passed. The old
   "2-4 min" note in this file was wrong and made a healthy run look hung. To tell a live run from a
   dead one, read the CPU time of the testhost process (it sat at ~1226 s of CPU after 20 minutes) -
   never the log, which is buffered until the test ends.
 - **`DOMS-CSFIX.IMG` is the only pack** carrying `SWAP-FILE:DATA`, `CPU-STAT:DOM`,
   `DESCRIPTION-FILE:DESC` AND the 262144-byte ND-5000 `CONTROL-STORE:DATA`. A stock DOMs pack has
   the domains but the CLASSIC 147456-byte store and answers "Wrong microprogram".
 - **Check line ~3 of the log says `----- pack override: ...DOMS-CSFIX.IMG -----` before reading
   anything else.** If it is absent, the run measured nothing.
 - Output is BUFFERED until each test ends, so a log that has not grown for 30 minutes is NOT
   evidence of a hang. Check CPU delta per wall second instead (a live run sits at ~90-95% of a core).
 - Every run restores a virgin pack (`EnsureWorkingCopy` ends in an unconditional `File.Copy`), so
   killing a run cannot corrupt the fixture and no test can inherit another's swap file.

---

## STANDING RULES THAT ORDER THIS FILE

 - **Known bugs before features.** A bug upstream of a feature makes the feature unmeasurable.
 - **Every error line is a bug until root-caused.** No dismissing anything as noise.
 - **Both rounds.** Macro CPU, then microword B30 + real 68k ACCP. A macro-only conclusion is not a
   conclusion. (Step 3 is what makes the second round possible at all.)
 - **/loop re-arm: 2 minutes max while iterating.** Longer only with a named run in flight.
 - Full evidence trail: `docs/OCTOBUS-SWAPPER-STANDOFF-2026-08-28.md` — **read its top index first**;
   it corrects itself repeatedly and six section numbers are duplicated.
