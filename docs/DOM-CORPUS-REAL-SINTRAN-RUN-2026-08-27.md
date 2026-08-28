# Running the DOM corpus under REAL SINTRAN — setup, and what each run measures

**2026-08-27.** Grades: `[V]` measured/executed, `[D]` derived, `[OPEN]` unknown.

Goal restated: **real ND-500 programs on our emulated CPU, driven by REAL SINTRAN III on the
emulated ND-100, with every MON call FORWARDED over the bus.** A run our C# `SintranEmulation`
answers does not count — ask **who answered the MON calls** before believing anything below.

This document records the fixture work done to run the whole corpus on that lane, and the three
fixture defects found doing it. The measurements themselves are filled in below as each run lands.

---

## 1. WHICH LANE, AND WHY

Two transports reach the same `CpuND500`: the classic **3022/5015** bus and the **octobus/ACCP**.
They share the servicer, the 5MPM message layout and the whole MON 60B command set.

**The corpus work is on the CLASSIC lane**, and that is a measurement, not a preference:

| | classic 3022 | octobus ND-5000 |
|---|---|---|
| `LOAD-CONTROL-STORE` | `[V]` | `[V]` — 128 pulses, `Micro program.: 11930` |
| swapper starts | `[V]` yes - "Allocating memory - 7116B pages" | **`[V]` FAILS - see 1a** |
| `PLACE-DOMAIN` | `[V]` (`725a1fb8f`) | blocked behind the swapper |
| programs that RUN | `[V]` CPU-STAT, LED-FORTRAN-A01, LINKER-B01 | none |

### 1b. THE ND-5000 SWAPPER STARTS - by NOT typing START-SWAPPER `[V]` 2026-08-27

`ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture`: boot, login, `set-avail`, `@nd-500`,
`define-swap-file swap-file:data`, `place-domain cpu-stat`, `run`. No `status`, no
`START-SWAPPER`, no `GIVE-N500-PAGES`.

| | with START-SWAPPER | short bring-up |
|---|---|---|
| `startSeen` | **0** | **1** |
| `startMicfu` | 0B | **23B (3START)** |
| `startTaken` | False | **True** |
| monitor after it | every command STALLS | responsive |
| MICFU traffic | watchdogs only | `1B:24 12B:1 23B:1 24B:1 31B:13` |

`PLACE-DOMAIN` alone prints `> Loading Control Store` then `> Loading Swapper`, and the swapper
then STARTS: 13 `PHYSWR` page writes, one MON 377B answered (`ansSWPFU=1B`), one restart taken,
and it parks at `PC=0x08008255` - the SAME MON 377B site it reaches on the working ND-500 lane.

**So the hang was a command nobody was supposed to type.** ND-60.136.04A 8.10.10.4 says of
LOAD-SWAPPER "Normally, this is done automatically when the first ND-500 process is initiated by
the monitor", and ND-30.003.7 calls the long form the ADVANCED start, for diagnosis. Credit to
the peer session for the suggestion; it cost one run to rule in.

> ### BOTH MY GENERATION HYPOTHESES ARE REFUTED - keep this, do not re-derive them
> I had two candidates for the hang, each with a real argument behind it:
> **MICFU 05 (3SWMESS)** - refused on the ND-5000 arm, and the peer measured SINTRAN posting it
> 38 times per run on the ND-500 transport; and **MICFU 21B (3WREG)** - refused on the ND-5000
> arm, whose own code comment calls it "the LOAD-SWAPPER blocker".
>
> **NEITHER APPEARS ANYWHERE IN THE RUN.** The MICFU histogram is `1B, 12B, 23B, 24B, 31B` and
> nothing else. SINTRAN never posts 05 or 21B on this path at all, so no generation arm was
> involved and changing one would have fixed nothing while looking like a fix.
>
> Both hypotheses were well-argued, mutually consistent with the evidence available, and wrong.
> The only thing that separated them from the truth was refusing to edit before measuring.

**WHAT IS STILL OPEN.** `place-domain` did not finish inside 300s and `run` added nothing but
watchdogs (`1B` 24 -> 60), so the domain is not placed and CPU-STAT does not run on this lane
yet. The swapper is parked on a MON 377B that gets no further restart. That is the next question,
and it is a DIFFERENT one from the hang that is now closed.

---
### 1a. On the octobus lane, `START-SWAPPER` HANGS THE MONITOR `[V]`

Measured 2026-08-27 on the ND-5000 master pack (correct 262144-byte ND-5000 microcode on the
pack, `--memory=2048`, run thread on). The command boundaries come from the harness's own crash
breadcrumb, which brackets every monitor command:

```
>> BEGIN process-status          << END  process-status (OK)      <- full table printed
>> BEGIN start-swapper           << END  start-swapper (OK)       <- NO OUTPUT AT ALL
>> BEGIN who-is-on               << END  who-is-on (STALL)
>> BEGIN list-active-processes   << END  list-active-processes (STALL)
>> BEGIN process-status          << END  process-status (STALL)   <- the SAME command, now dead
>> BEGIN version                 << END  version (STALL)
>> BEGIN list-standard-domains   << END  list-standard-domains (STALL)
```

**This is a stronger statement than "the swapper never starts".** `process-status` answered
before `START-SWAPPER` and stalls after it, so the ND-500 MONITOR ITSELF stops responding.
Whatever `RUNSW` (FUNCS `054B` @163621) does over the octobus, it does not come back.

> **The `(OK)` on the `start-swapper` line is an INSTRUMENT ARTIFACT, not a result.**
> `RunNd500Command` waits for `N500:`/`ND-5000:` and the monitor re-prints its prompt while
> echoing the typed command, so the wait matched the prompt belonging to the command it had
> just sent. Read naively, that line says the command completed. The only reason it is readable
> as a hang at all is that the NEXT command stalls - a single self-reported OK with no
> neighbour to disagree with it can be believed but never checked.

**AND IT NEVER REACHES THE TRANSPORT.** The harness dumps the whole ACCP exchange twice, once
after `STATUS` and once after `START-SWAPPER`. The two files are **byte-identical**: 19,084
bytes, 147 commands, `unanswered=0`, both ending on the same `ENKICK` and the same
`TRAP_OCBM 202B` model/version report.

```
sintran-octobus-accp-exchange-after-status.txt   19084 bytes, 147 IN commands
sintran-octobus-accp-exchange-after-swapper.txt  19084 bytes, 147 IN commands   cmp: identical
```

So `START-SWAPPER` issues **zero** ACCP commands. Whatever stops it is on the ND-100 side,
BEFORE anything crosses the octobus - or it is a mailbox doorbell (an `X5ACT` write into the
shared window), which is an MPM write and would not appear in an ACCP command log at all.
Those two are different bugs and this capture cannot separate them.

**What would separate them, and it is one run:** the same ladder cut down to `status` +
`start-swapper` only, with the servicer's MICFU log and the MPM write log dumped. If an `X5ACT`
write appears and no MICFU follows, the doorbell is landing somewhere we do not walk; if no
`X5ACT` write appears at all, SINTRAN never got as far as posting the activation.
So the classic lane is where the corpus can actually be measured today. The octobus swapper gap is
tracked separately; it is not on this document's path.

---

## 2. THREE FIXTURE DEFECTS FOUND — all of them silent

Each one made a MISSING FIXTURE look exactly like a broken emulator, which is the class of failure
that costs the most because the transcript reads as a real result.

### 2a. The distribution floppy path had been dead for weeks `[V]`

Both harnesses hardcoded `C:\Users\ronny\Downloads\210319H02-XX-01D.img`, and the classic one
additionally hardcoded a copy inside a session scratchpad whose whole directory has since been
deleted. **The media now lives in `Downloads\OLD\`.** Neither path existed on 2026-08-27.

Nothing failed loudly. The octobus harness printed *"NLL floppy NOT FOUND ... not attached"* and
carried on; the classic harness never mounted `fd0` at all — its two floppy constants were
**declared and never referenced**. A run then reports that `LINKAGE-LOAD-H02` cannot be placed,
which is TRUE and says nothing whatever about the emulator.

Fixed by `Emulated.Tests\ND100\Nd500TestMedia.cs`: one resolver, ordered candidates
(`$RETROCORE_NLL_FLOPPY_IMAGE` → `Downloads\OLD` → `Downloads`), used by both harnesses, and it
says out loud when nothing is found.

### 2b. The corpus pack was never mounted by the corpus tests `[V]`

`Nd500_*_UnderRealSintran_*` mounted `D:\BIGDISK0-L-CPUSTAT.IMG`, which carries exactly two
domains. The pack with the corpus is `D:\BIGDISK0-L-DOMS.IMG` and it is a strict SUPERSET — read
out of the packs' own object files with ndfs, not inferred from the file names:

```
CPU-STAT:DOM            38912    19p     CONVERT-DOM-A03:DOM    339968   166p
LED-FORTRAN-A01:DOM   1302269   636p     CAT-CAT5-B06:DOM       280957   138p
CODE-COVERAGE:DOM       67637    34p     PLANC-500-G00:DOM     1050031   513p
AUTOMAKE-500-C00:DOM   108544    53p     NC-A06:DOM             333041   163p
SWAP-FILE:DATA              1  2000p     LINKAGE-LOAD-H02:PSEG  123989    61p
DESCRIPTION-FILE:DESC   22528    11p     LINKAGE-LOAD-H02:DSEG 2184977  1067p
```

Now selected by `DomainsImagePath`, with the smaller pack kept as a fallback so a box without the
corpus pack still runs CPU-STAT and LED.

### 2c. `LINKAGE-LOAD-H02` is on the pack and still cannot be placed `[V]`

Its `:PSEG` and `:DSEG` are right there and `PLACE-DOMAIN` answers **`NO SUCH DOMAIN`**. The reason
is not the CPU, the MMU, the loader or the segment number:

**COPYING A `PSEG`/`DSEG` PAIR ONTO A PACK IS NOT INSTALLING AN ND-500 DOMAIN.** The domain has to
be registered in that pack's `DESCRIPTION-FILE:DESC`. Both description files read directly:

```
D:\BIGDISK0-L-DOMS.IMG (SYSTEM)      LED-B03, SCRATCH-DOMAIN, SCRATCH-SEG-01     <- no NLL
210319H02-XX-01D.img (FLOPPY-USER)   LINKAGE-LOAD-H02, ...                       <- the only one
```

So the floppy's own description file is the ONLY thing on this box that registers the loader.
Mounting the floppy is the SUPPORTED route, not a workaround.

> Two wrong guesses were spent before reading that table, and both looked reasonable: that the
> description file was missing (it is present on both media), and that the absent `:LINK` file was
> the blocker (it was added to a copy of the pack — still `NO SUCH DOMAIN`). The install spec's
> four-file list was a good lead and still the wrong answer. Reading the table took one command.

---

## 3. THE MARKERS WERE MEASURED, NOT READ OUT OF A GUIDE `[V]`

A test that waits for the wrong banner reports a working program as a stall. Every marker was taken
by running the program under `nd500x` (25 s cap, 2026-08-27) and reading only the region between
its own `placed` and `program exited` lines:

| program | what it actually writes | instructions |
|---|---|---:|
| CONVERT-DOM-A03 | `- Convert Domain, Version A03            January 24,  1989` | 131,084 |
| CAT-CAT5-B06 | `CAT-500 - Version B06 - 1988-01-05` | 13,846 |
| PLANC-500-G00 | `- ND-500 PLANC COMPILER - JUNE 9, 1986   VERSION G` | 27,541 |
| NC-A06 | `Norsk Data C - Version: A06 - 1989-01-10` | 50,709 |
| AUTOMAKE-500-C00 | `ND-500 - AUTOMAKE - Version C00  April 27, 1987` | 13,705 |
| CODE-COVERAGE | `Welcome to the code-coverage analyzer, version of DECEMBER 3, 1986` | 11,017 |

**The user guides would have been wrong twice.** They quote the HELP text (`ND CONVERT-DOM`) and the
DISASSEMBLED string (`PLANC COMPILER - VERSION G`, no `ND-500` prefix, different spacing). Neither
is what the program writes to a terminal.

`nd500x` answers the MON calls with its own C emulation, so this table proves the DOM loads and the
instructions execute and **nothing else**. It is a source of BANNER TEXT, not of results.

---

## 3a. THE DEFECT THAT INVALIDATED THE FIRST RESULTS - fixed and verified `[V]`

**Programs halted the moment they tried to PRINT.** Six halts in one corpus run, three different
MON numbers, one reason string:

```
Reason: MON 2:  sink attached but call not taken (no active process message?)   x4
Reason: MON 26: sink attached but call not taken (no active process message?)
Reason: MON 75: sink attached but call not taken (no active process message?)   x2
```

`MON 2` is OutByte. (The reason string prints DECIMAL while the traces print octal - `26` is
`32B`, `75` is `113B`. Worth knowing before concluding they are different calls.)

`OnMonitorCall` guarded on `ActiveProcessMessageAddress` alone and declined the call when it was
zero - but **that field is cleared by every answer**, so a running process legitimately has it at
zero. The guard therefore refused calls the answer path immediately below it would have resolved
from the per-process map without difficulty, and the CPU halted on the false return.

Fixed in `e5bf290fd` (guard now asks `CanAnswerStopOnSomeMessage`, the same question the selector
answers, and still returns false when nothing resolves anywhere) plus `94d6c3cd7` (the
`MSG-RESCUE` log made to read the same field as the behaviour it reports).

**VERIFIED on the lane that produced it:**

| | before | after |
|---|---:|---:|
| halts | 6 | **0** |
| CODE-COVERAGE `RUN marker` | -1 (false timeout) | **0 - its own banner** |
| tests | failed | **2/2 passed** |
| `MSG-RESCUE` fired | n/a | 3 |

### The open question this raised, and its answer: THERE WAS NO MYSTERY `[V]`

I claimed a restart-tail should have set the field and had not - "one specific unexplained
transition". **Wrong.** All three rescues are identical in shape:

```
MON 2B argc=2 ... X5CPU=1 | [1] @0x08004F98=0x00000061 'a'    print one character
  CONTEXT SAVE X5CPU=1 (monitor-call stop)
  RESTART K=0 ... SWPFU=0x0001 SWPST=0x0061                    the ANSWER to that call
  MSG-RESCUE MON 2B: ActiveProcessMessageAddress was 0 ...
```

That is CODE-COVERAGE printing its welcome ONE CHARACTER AT A TIME - the three rescues carry
`'a'`, `' '` and `'m'`. Every rescue follows an ANSWER, which clears the field BY DESIGN. No
restart-tail is involved anywhere.

**How the wrong claim was produced:** by assembling a sequence from two separate greps of an
append-only log instead of printing one region in order. That is the SECOND time in this session
- the AUTOMAKE 113B analysis failed the same way and was corrected the same way. The tell is
identical both times: being able to name WHICH events happened but not which FOLLOWED which.

---
## 3b. LINKAGE-LOAD-H02 PLACES `[V]` - and the two things that were stopping it were both NAMES

```
place-domain (210319H02:FLOPPY-USER)LINKAGE-LOAD-H02
> Loading Control Store
> Loading Swapper
> Allocating memory - 7116B pages
N500:
[SWAPMAP] mapped dom=0 progSeg=1 dataSeg=1 P=0x08000004
          PSEG=0x0006F800+0x9800  DSEG=0x00024800+0x35800  (program+data MMU enabled)
```

Neither blocker was in the emulator. Both were how the domain was NAMED.

**1. `ENTER-DIRECTORY` with a blank name.** Blank takes the directory name from the VOLUME LABEL,
mounting it as `210319H02-XX-01D`, while the domain's own `DESCRIPTION-FILE:DESC` names its
segments with the SHORT form. Read out of the floppy - 5 printable runs in 22528 bytes:

```
'@@LINKAGE-LOAD-H02'
'(210319H02:FLOPPY-USER)LINKAGE-LOAD-H02'
'(210319H02:FLOPPY-USER)SCRATCH-SEG-01'
```

**2. `NO SPACE IN DEFAULT DIRECTORIES` is not about space.** It means "not in your DEFAULT
directories". `(FLOPPY-USER)X` names a USER and no DIRECTORY, so SINTRAN searches only the
defaults - and the floppy is not one, even though it IS entered. The same run proves the mount:

```
DIR INDEX  0 : DISC-75MB-1   UNIT 0 : PACK-ONE
DIR INDEX 40 : FLOPPY-DISC-1 UNIT 0 : 210319H02-XX-01D
```

**"Entered" and "searched by default" are different things**, and a listing that shows the mount
is NOT evidence the name will resolve. Naming the directory fixes it, and the short form resolves
against the label-mounted directory by SINTRAN's prefix matching - confirmed by SINTRAN's own
`LIST-FILES` answering True for `(210319H02:FLOPPY-USER)LINKAGE-LOAD-H02`.

Confirmed in passing: **`ENTER-DIRECTORY` ignores the name it is given and uses the label anyway**,
exactly as the 2026-07-31 note warned. The `LIST-DIRECTORIES-ENTERED` step is kept precisely so
the transcript records what it MOUNTED AS rather than what was asked for.

### What still fails: RUN, on swapper `201B` `[V]`

```
*** FATAL SYSTEM ERROR ***
ND-500(0) error:      Fatal error from Swapper
ERROR CODE:           201B
                      ND-500(0) CPU locked
```

9002 MON round trips through real SINTRAN, none answered by our C# layer, before it dies.

**`201B` is already carved** and should not be re-derived: the swapper routine at `1000107011`
walks a list in PHYSICAL memory (under `DMOF`), counts elements whose halfword at `+8` is 1, and
reports internal code `0o201` when it counts NONE. So the question is which list is empty and who
was supposed to fill it - not what the code means.

Distinct from `200B`, which is the list-walk running PAST its limit word. Both are swapper
internals; neither is "a hardware fault", which is a different namespace.

---
## 4. RESULTS ON THE REAL-SINTRAN LANE

Each row is `Nd500_<name>_UnderRealSintran_RealCpu_Capture`. The two hard assertions in the shared
helper are what make a row mean anything:

 - `EmulatedMonPathMarker.Count == 0` — our C# MON layer answered NOTHING.
 - `RealSintranMonRoundTrips > 0` whenever the program printed — the output came from SINTRAN.

| program | banner | MON round-trips | fake answers | verdict |
|---|---|---:|---:|---|
| CPU-STAT | **`[V]` prints** | | 0 | **RUNS** |
| LED-FORTRAN-A01 | `[V]` prior | | 0 | runs |
| CONVERT-DOM-A03 | **`[V]` prints** | 36 | 0 | **RUNS to its prompt** - callg family NOT yet exercised |
| CAT-CAT5-B06 | **`[V]` prints** | 263 page faults serviced | 0 | **RUNS AND TERMINATES CLEANLY** |
| PLANC-500-G00 | `[OPEN]` | | | |
| NC-A06 | `[OPEN]` | | | |
| AUTOMAKE-500-C00 | **`[V]` prints** | | 0 | **RUNS** |
| CODE-COVERAGE | **`[V]` prints, matches nd500x** | 16 | 0 | **RUNS** - scored -1 only by a harness ordering trap |
| LINKAGE-LOAD-H02 | n/a | 9002 | 0 | **PLACES** from the floppy; RUN dies swapper `201B` |

**Known blocker, not a new finding:** NC-A06 calls `MON 422B` (GSWSP), the same call that stops
CPU-STAT's runtime init on an L-version pack — this SINTRAN answers `K=1 / 1013B` "illegal monitor
call number". A stop there is the 422B gap, already understood.

### 4a. CAT-CAT5-B06 `[V]` - full run, 2026-08-27

```
> Allocating memory - 7116B pages          <- the swapper, doing real work
=====[ N500: run (cat-cat5-b06) ]=====
CAT-500 - Version B06 - 1988-01-05         <- the program's own banner
RUN marker index = 0                       <- 0 = the banner, not the prompt, not a timeout
exit
program CAT_COMPILER terminated
execution time
```

Byte-for-byte the same ending `nd500x` produces (`programCAT_COMPILER terminated`), but here the
MON calls were answered by REAL SINTRAN on the emulated ND-100 - the whole point.

**263 page faults were taken and serviced during the run**, walking segment 2 one page at a
time (`0x10017800`, `0x10018000`, `0x10018800`, ... `+0x800` each, `took=True` on every one).
Each is a full round trip through SINTRAN. A fixed faulting PC marching through consecutive
addresses is a scan loop demand-paging its data, NOT a stall - the discriminator is that the
ADDRESS advances while the PC stands still.

This also settles the first half of the bring-up question on this lane: **the swapper starts
and allocates**, with no error code. `START-SWAPPER` failing is an OCTOBUS-ONLY defect (section 1a).
### 4b. AUTOMAKE-500-C00 `[V]` RUNS - and my MON 113B finding was WRONG

```
ND-500 - AUTOMAKE - Version C00  April 27, 1987
RUN marker index = 0
```

**RETRACTED: "SINTRAN never answers its MON 113B (GetCurrentTime)".** That was reproduced five
times and written up here as a headline finding with a full trace behind it. It was still wrong.

What actually blocked AUTOMAKE was the shared-bridge halt in section 3a - `OnMonitorCall`
declining a call because a field the previous answer had cleared was zero. `113B` was merely the
LAST CALL BEFORE THE CPU STOPPED, and I read "last thing in the trace" as "the thing that failed".
With the guard fixed, AUTOMAKE issues `113B` REPEATEDLY - it is a clock poll - and prints its
banner.

**The lesson is not "113B was fine", it is about the inference.** A trace that ENDS at call X
tells you X was last. It does not tell you X was refused, and it does not tell you X caused the
stop. Distinguishing those needs the stop REASON, which was available the whole time
(`sink attached but call not taken`) and named a different call - `MON 2`, OutByte - in the same
log I was quoting from.

Five reproductions did not make it true. They reproduced the SYMPTOM faithfully and I attached the
wrong cause to it every time.

### 4c. BM-FILERE-B02 `[V]` - CANNOT RUN: a companion file that exists nowhere

```
place-domain bm-filere-b02
> Loading Control Store
> Loading Swapper
> Allocating memory - 7116B pages          <- pages were NOT the shortfall; this SUCCEEDED
"BM-FILERE-XX-B02:SEG"
FREE SEGMENT NOT FOUND
```

**The message is LITERALLY TRUE and names a FILE.** Not a table-full condition, and not a page
shortage - both of which were guessed here before anyone decoded the DOM.

`:SEG` is the ND Linker's "free segment" file type: one program+data segment pair in its own
file, referenced by one or more `:DOM` files and matched by link key. Decoding BM-FILERE's own
segment table (at `0x254`, 32 descriptors of 56 bytes) against CPU-STAT as a control:

```
CPU-STAT        slot1 PROG  ATT=0x10002000   LINKED_SEGMENT clear
                slot1 DATA  ATT=0xE1002000   LINKED_SEGMENT clear    -> self-contained

BM-FILERE-B02   slot1 PROG  ATT=0x00006000   LINKED_SEGMENT SET
                slot2 DATA  ATT=0x00006000   LINKED_SEGMENT SET
```

On the two linked parts `LB` is not a file offset but a NAME-POOL INDEX, and `SZ` is not a size
but the LINKKEY to match the target's LINKLOCK. The name pool spells out `BM-FILERE-XX-B02:SEG` -
exactly what SINTRAN printed.

**The file exists nowhere.** Scanned independently, driving the ndfs library directly rather than
through a wrapper: 17 packs on `D:` opened, 2 correctly refused (BSD and Sun images, not ND),
**zero files of type `:SEG` on any pack**, and exactly ONE BM-FILERE file in existence - the `.DOM`
itself. `ND500-APPS\BM-FILERE-B02iles\` holds only `BM-FILERE-B02.DOM`.

**VERDICT: "cannot run - missing artefact", NOT an emulator failure and NOT a pack that needs
rebuilding.** The companion file was never captured. No amount of pack-building fixes it. Do not
spend further corpus time on this program.

> ### METHOD: TEST THE INSTRUMENT WITH A POSITIVE CONTROL BEFORE BELIEVING A ZERO
> The first search for the `:SEG` file used a bundled scanner and returned nothing - which was
> nearly reported as "it does not exist". The check that saved it: re-run the SAME scan for
> **CPU-STAT**, a name known to be on those packs. That returned nothing too. So the zero was
> about the INVOCATION, not the disk.
>
> A search that finds nothing is a statement about your method until you have shown the method
> can find something. The numbers above are auditable for that reason - packs opened, packs
> refused and named - rather than a bare "not found".

### 4d. CODE-COVERAGE `[V]` - RUNS, and the `-1` was the INSTRUMENT

Scored `RUN marker index = -1`, which reads as a stall. It is not one. The program was parked
`stopMode=WAIT` on `MON 1B` (InByte - `MCTAB 005621B`, worker `YFGET=026576`) after 16 clean MON
round trips, none answered by our C# layer. The moment the harness typed `exit` - satisfying that
pending read - the whole thing came out:

```
Welcome to the code-coverage analyzer, version of DECEMBER 3, 1986 for ND-500
This program will combine a DEBUGGER dump-log file and a
source listing and produce a listing where the non
executed statements are highlighted.
Errors and remarks can be directed to OJH, M4.
Program language:
Unknown language
Program language:
```

**Byte-for-byte what `nd500x` produces** - including consuming `exit` as the language answer and
rejecting it. The program runs correctly under real SINTRAN.

**THE TRAP, and it will hit other programs in this corpus.** `RunDomainUnderRealSintran` waits
for a banner and NEVER TYPES ANYTHING after `RUN`. This program's output does not reach the
console until its input read is satisfied. So the test waits for output that the program is
withholding until you type, and types nothing - a deadlock between the instrument and the
subject, scored as a defect in the subject.

An earlier reading of this same run said the program "issues no output MON before its first
read" and left the reason `[OPEN]`. That was right to leave open and the answer is ordinary:
the output happens, it just arrives with the read.

Most of this corpus is interactive - `Auto:`, `Program language:`, `FCOM:`, `NDL:`,
`Give real as ASCII string:` - so this ordering must be fixed before any of their `-1` results
mean anything.
### 4e. CONVERT-DOM-A03 `[V]` runs - but the pairing below is NOT yet decided

Same shape as CODE-COVERAGE: 36 clean MON round trips, none answered by our C# layer, then
parked `stopMode=WAIT` on `MON 1B` (InByte). Its banner appears once the read is satisfied:

```
- Convert Domain, Version A03            January 24, 1989
```

**BUT ITS MON CENSUS THIS RUN IS `377B` x37 AND `1B` x1 - NOTHING ELSE.** It reached its first
prompt and stopped. The 69 MON sites and `513B` x14 that make it the corpus's heaviest
callg-family user are NOT exercised by simply starting it. So this run proves the DOM loads,
executes and reaches its prompt on the real lane; it proves NOTHING about the callg family, and
the CONVERT-vs-CAT control below is still undecided.

To decide it the program has to be DRIVEN - fed a real CONVERT-DOMAIN command - not merely
started. That is the same distinction as "the process is alive" vs "the process did the work".

> METHOD NOTE. Grepping the log for the banner returned THREE hits and only ONE was the program.
> The other two were the harness's own text - the `wait:` line and the `RUN marker index` line
> both quote the marker string. Counting them would have turned one real result into three.
> The plan document already records this exact failure once ("a grep over the whole log measured
> MY OWN INPUT and reported it as a property of the program"). Check WHERE each hit is.
**The pairing that makes CONVERT-DOM and CAT-CAT5 worth running together:** CONVERT-DOM is the
heaviest `callg`-family user in the corpus (69 MON sites, 43 distinct, `513B` ×14); CAT-CAT5 has
**zero** callg and no `511B/512B/513B/514B` at all. If CAT passes and CONVERT fails, the fault is in
the callg family and nowhere else.

## 5. The linkage loader: 201B did not reproduce, and the failure moved to a page-fault loop

Measured 2026-08-28, two consecutive runs, the second with the loader as the **only** test so that
pack state written by earlier tests cannot explain it.

### 5a. What is now ruled out

    ND100MAP configured base=0x00000000 bytesPerUnit=2 windowBase=0x00420000
    RIOM 0x00210718 -> mapped=0x00000E30 dest=0x080240BC hw=20
    riom@0x08024144 = 0x00000800   globals@0x0802620C = 0x00000800

That is the expected classic pair, and `0x00000E30` is the target the 2026-08-23 correction in
`Nd500CpuProcessBridge.cs` names as correct. The base-pointer chain is healthy from PLACE-DOMAIN
onward, not merely at the end. **The known 2026-08-23 window-base defect is not the cause here.**

`ERROR CODE 201B` did not appear in either run. This is **NOT** recorded as a fix - nothing was
changed that could have fixed it (a read-only report and a comment), and run-to-run
nondeterminism is already documented for this family in
`OCTOBUS-SWAPPER-HANDOFF-2026-07-25.md` 7.7.3. It is recorded as *did not reproduce, twice, one
isolated*, and the earlier 201B stands as a real observation that currently cannot be reproduced.

### 5b. What actually happens now

13,086 real MON round trips, `answeredByCsharpEmulation=0`, CPU still at `stopMode=NONE`. The run
never ends; it cycles. One complete cycle, read in order rather than assembled from greps:

    loader  X5CPU=1  P=0xB001D32C  -> TRAP 46B, addr=0xB0215310, psn=12
    context switch   X5CPU=1 -> 0
    swapper X5CPU=0  P=0x08008255  -> MON 377B, restart K=0 SWPFU=0x0000 SWPST=0x000A
    context switch   X5CPU=0 -> 1
    loader re-executes the SAME instruction and faults at the SAME address
    ... 88 times, faultSeq 13104, 13105, ...

Every field is constant across the cycle: `SWPFU=0x0000`, `SWPST=0x000A`,
`[3] @0x0802428C=0x0000000C`, and `HSWPI` alternating between exactly `0x00210718 -> 0x00420E30`
and `0x00000800 -> 0x00001000`. The swapper asks the same question and receives the same answer
forever.

### 5c. The reason string, which corrects the obvious reading

`PSTWATCH` shows SINTRAN **did** write PST entry 12 (four writes at `0x455018/19`, ending
`0x8FF1`) and then nothing for the remaining 13,000 round trips. The tempting conclusion - "the
PST entry is written and our MMU ignores it" - is **wrong**, and the full trap text says so:

    reason=PS_ADI  L1 PTE not present: L1=2 (segment 22, cap=0xC00C, psn=12, isInstruction=False)
    operand: mode=PREINDEXED reg=1 disp=0 B=0xB0002748 R=0x00000000 -> ea=0xB000278C

It is an **L1 page-table entry**, not a PST entry, and `psn=12` names *which* segment's page table
is being walked rather than the entry that is missing. `PSTWATCH` watches only the PST window
`0x455000..0x455100`, so it could never have shown the L1 table either way - a clean case of an
instrument that is structurally blind to the thing being asked about (taxonomy #8).

Note also `addr=0xB0215310` in the trap is NOT the operand address `0xB000278C`. Treating the
reported address as the data the program wanted would send the next reader to the wrong place.

### 5d. Open, and deliberately not answered here

 - `SWPFU=0`. The carve records `SWACTIVE=0` as the **fatal** GOSW slot (7.7.2), which invites
   linking the two. **Do not lean on it.** Zero is both "no function posted" and a legitimate slot
   value, so this is the failed-read-versus-real-value trap again: the observation cannot
   discriminate on its own and needs a second signal saying whether the post SUCCEEDED and zero is
   the answer. The `unmapped`-versus-`zero` distinction already built into the state line is the
   right instrument; until it is pointed at this, `SWPFU=0` is not evidence of anything.
 - **STILL OPEN: what the two CELLS hold.** `riom@0x08024144 = 0x00000800` and
   `globals@0x0802620C = 0x00000800` are whole 32-bit cells on the base-pointer path the 7.7.2
   carve describes; the carve's fixed octobus values were `0x00008800` in both, with a head at
   `0x00008824`. Whether `0x00000800` is correct on this lane is **unverified**.

   **THIS BULLET WAS BRIEFLY MARKED CLOSED, AND THAT WAS AN ERROR - see 5f.** The RESIWR decode in
   5f is correct and answers nothing here: it is about two HALFWORDS INSIDE A MESSAGE BODY, and
   this question is about two 32-BIT CELLS IN ND-500 MEMORY. Different numbers that happen to
   share the digits `800`. Whether the cells are filled FROM that message is itself unestablished.

   Name the shape, because it is the sibling of the one in 5c: an **out-of-frame ANSWER** - true
   about a number that is not the one in question. Like the out-of-frame instrument, its output
   carries no signal of its own irrelevance, and it is MORE dangerous than a wrong answer because
   it is satisfying. An open question with a good answer sitting next to it is the most reliable
   way for an open question to disappear. The defence is the analogue of the one that worked in
   5c: **state which ADDRESS the answer is about, not just what it says.**

### 5e. Marker corrections - three in one night, all the same mistake

`"NLL"` could never have matched a healthy run. The program's own startup text, read from the
shipped `linkage-load-h02.dseg` dated 3 March 1988, is `ND-Linkage-Loader -  H.02`, with the
prompt `Nll entered:`; `NLL` occurs there only as a command word. Likewise `"LED:"` was never
going to appear from a program that paints a screen - LED emits
`ESC[30;7;80l ESC[62;62h PL10 PL20 PL30 PL40 ESC[1;1H`.

Each marker was a guess about what a program prints, made while the program itself sat on disk
available to be read. **Read the artefact, do not guess the banner.**

## 6. Verified: the RESIWR message decode (this answers the BODY, not the cells)

`[V]` 2026-08-28, discharged against the 14B handler's own parameter geometry in
`Nd500MicrocodeServicer.cs`, which is microcode-verified:

    destHi = word 7  (N500A)     destLo = word 8  (N500A_LO)
    srcHi  = word 9  (STOPR)     srcLo  = word 10 (NUMPA)
    nrbyt  = word 11 (MCNO, 0o13)

Applied to the one measured body containing `8800`:

    MSGBODY |00: FFFF FFFF 0001 0001 0000 0000 000C 0006 |08: 8800 0021 2400 0800
                                              MICFU=000C = 0o14 = RESIWR

    destNd500 = 0x0006 << 16 | 0x8800 = 0x00068800   ND-500 destination
    src       = 0x0021 << 16 | 0x2400 = 0x00212400   ND-100 word address
    nrbyt     = 0x0800 = 2048                        exactly one page

So `0x8800` is the **low halfword of the destination address** `0x00068800` and `0x0800` is a
**byte count**. They are not one value in two states and not two related fields - one is a
fragment of a pointer, the other a length. The prediction attached to this decode was "a
2048-byte copy to a page-aligned destination", and it holds: `0x68800 & 0x7FF == 0`, page `0xD1`.
Discharged, not merely coherent.

**WHAT THIS DOES NOT DO IS ANSWER 5d.** It disposes of the *coincidence* that made a lost-bit-15
theory attractive - half an address happening to differ from a length by one bit - and it says
nothing about what the two 32-bit cells hold or should hold.

## 7. The L1 page table IS filled - the loader is running off the end of segment 22

Measured 2026-08-28, linkage loader under real SINTRAN, classic lane. This replaces the
working assumption "the L1 entry is never filled", which was never measured.

**How it was aimed.** The PS_ADI walk now prints the address it read the decision from, and
the watch is armed from that same derived address, so the instrument cannot be pointed at a
different table than the subject. That is the fix for the PSTWATCH failure recorded in §5c:
a watch aimed by hand reports true and irrelevant things forever.

```
L1TABLE=0x007F8800  pfnum=0xFF1  entry@0x007F8804  stride=2  readPFN=0x0  prot=0
```

`pfnum=0xFF1` is SINTRAN's own number: PSTWATCH caught it writing PST entry 12 = `0x8FF1`
(bit 15 = flag, `0xFF1` = page). So the PST is read correctly and it places segment 22's L1
table at ND-500 physical page `0xFF1` = byte `0x7F8800` = ND-100 physical `0xC18800`.

**The address is backed.** `0x7F8804` is inside the 8 MB MPM (`DEFAULT_SHARED_MEMORY_SIZE`),
so `RouteToMpm` reaches real memory. The zero is a genuine zero, NOT an unbacked read that
returns zero and imitates an empty table. That possibility is closed.

**The table contents, read off the wire:**

| L1 index | ND-100 phys | halfword | verdict |
|---|---|---|---|
| 0 | `0xC18800` | `0x0FF7` | valid, L2 table at page `0xFF7` |
| 1 | `0xC18802` | `0x0FF0` | valid, L2 table at page `0xFF0` |
| 2 | `0xC18804` | `0x0000` | the faulting entry |

Pages `0xFF7`, `0xFF1`, `0xFF0` are a coherent cluster of table pages at the top of ND-500
physical memory - exactly the shape of a real allocation, not of garbage.

**What this means.** L1 index = VA bits 26-20, so entries 0 and 1 map the first 2 MB of
segment 22. The faulting address `0xB0215310` is offset `0x215310` = ~2.08 MB, one L2 table
past the end of what is mapped. The failure is NOT broken page-table plumbing; it is a
segment that is 2 MB long being accessed past its end, and 88 page-fault round-trips through
real SINTRAN that do not extend it. A zero L1 entry behind a VALID capability is the
documented swap-in request (ND-05.009.4 s4.3), so the request is being made correctly and
is not being satisfied.

**Instrument limit, stated so it is not over-read.** The ring recorded 18036 events and
shows the last 4096, all reads (1365 x entry 0, 341 x entry 1, 342 x entry 2 - the walk
re-reading on every fault, which is what proves the watch covers the cell). No write appears
in that slice, but reads flooded the ring, so "entry 2 is never written during RUN" is NOT
yet established - only "not written recently". A writes-only re-run settles it.

### 7a. The next question - and a correction to how NOT to ask it

RETRACTED, same day it was written: an earlier draft of this section said the trap address
`0xB0215310` is the VALUE of a pointer the instruction reads pre-indexed, and that reading
the 4 bytes at `ea=0xB000278C` would settle things. That is wrong on the evidence already in
the log. `CpuND500.Fetch.cs` prints `pointer@0x.. held 0x..` whenever an operand actually
indirects; the fault line prints plain `-> ea=0xB000278C`, so NO indirection happened. And
this harness already records (see the note beside the 44B dump) that the `operand:` text
carries the LAST recorded operand, which need not belong to the trapping instruction. So the
operand line is not usable as evidence about this fault in either direction.

What survives is only what the walk itself derived:
  - the translated address is `0xB0215310`; segment = bits 31-27 = `0x16` = 22, which matches
    the walk's own `segment 22`;
  - offset within the segment = `0xB0215310 AND 0x07FFFFFF` = `0x00215310` = ~2.08 MB;
  - L1 index = bits 26-20 = 2, and entries 0-1 map only the first 2 MB.

So the open question is why the domain reaches 2.08 MB into a segment with 2 MB mapped, and
that is answered by decoding the FAILING instruction, not by chasing the stale operand. The
bytes are already captured, with `P1` marking the failing instruction (`P1=0xB001D32C`, while
`P`/`regs.PC` = `0xB001D333` - the usual P-runs-ahead gap):

```
CODE@0xB001D324: C4 B0 01 28 3C FE 24 51 >FD 20 C5 14 F4 00 0C 44 51 C6 13 FD 20 C4 B0 01
```

Decode from the `>` marker and read what the instruction addresses. [OPEN]

Also still open, and cheaper: whether L1 entry 2 is EVER written during RUN. The first run
could not say, because the ring saturated on reads. Re-run with the ring big enough to hold
the whole run (18036 events measured) so no event is dropped and the read denominator is
kept. [OPEN]

## 8. The missing L1 entry is the tail of the loader's own DSEG - 43 pages short

Lead from session nd500uc-47, checked here rather than adopted.

**VERIFIED independently (file stat, not the claim):**
`D:\ND\500\linkage-loader\linkage-load-h02.dseg` = **2,184,977 bytes**.
 - pages needed at NBPG=2048: **1067**
 - pages covered by L1 entries 0 and 1: 2 x 512 x 2048 = 2,097,152 = **1024**
 - short by **43 pages** (87,825 bytes), and those 43 live exactly under L1 index 2.

**VERIFIED here, and it is stronger than the size match:** the faulting offset is INSIDE the
file, near its tail. Offset `0x215310` = 2,183,440, which is **1,537 bytes before EOF**. A
wild pointer would have to land in the final 0.07% of the file by chance. The access is the
loader reading its own data.

**VERIFIED here - segment 22 IS the loader's segment** (nd500uc-47 correctly flagged this as
the load-bearing unchecked step). It needs no new run: the FAILING INSTRUCTION is at
`P1=0xB001D32C`, and `0xB001D32C >> 27` = 22. The code executing is itself in segment 22, so
segment 22 is this domain's segment; `psn=12` behind `cap=0xC00C` is its DATA-side page table
(`isInstruction=False`), i.e. the DSEG. One segment number cannot be two segments in one
domain, so the size match is not a coincidence.

**So the question flips again.** Not "why does the access go past the segment" - it does not
go past anything, it reads the loader's own data. The question is **why only 1024 of the
1067 pages are mapped**.

RETRACTED 2026-08-28, my own wording: this section first said the round number is "being
imposed somewhere", and section 8's original text called 1024 "the shape of a limit rather
than an allocation that ran out". Both smuggle in an imposer. nd500uc-47 made the same move
with the word "truncation" and retracted it; the plain reading is that SINTRAN registers
1067 and pages the segment in ON DEMAND, so two live L1 entries is simply how far paging has
got - not a cap. **A partially-paged segment and a truncated one look identical from the
fault**, and neither of us checked which before naming it. The roundness is explained
without any limiter: L1 entries are 1 MB each, so any prefix of a demand-paged segment ends
on a round boundary.

Two candidates, different culprits, and the DOM/DESCRIPTION-FILE entry separates them
without booting anything:
  - the descriptor declares the true 1067-page length and something truncates it to 2 entries
    on the way to the page tables; or
  - the descriptor itself declares 1024 and the file on the pack is simply longer than what
    the domain was registered as.
[OPEN]

### 8a. The write question, closed as far as this instrument can close it

Re-run with the ring at 65536: **81,668 events recorded, 65,536 shown, ZERO writes.** The
read denominator is intact and large - 21,847 reads of entry 0, 5,459 of entry 1, 5,462 of
entry 2 - so the watch demonstrably covers all three cells.

State the limit exactly rather than rounding it to "never written":
 - the ring is CLEARED when the watch arms at the first L1 fault, so this says nothing about
   the writes that filled entries 0 and 1 - those happened earlier, by construction invisible;
 - 16,132 of the 81,668 post-arm events still fell off the front.
So the supported claim is: **no write reached the L1 table page in the last 65,536 events
after the first fault**, which is consistent with SINTRAN never extending the mapping in
response to 88 page-fault round trips - and is not the same sentence as "never written".

## 9. SINTRAN built the table, not us - and a wrong inference of mine, recorded

nd500uc-47 settled the registration: DESCRIPTION-FILE:DESC declares the FULL length for
(210319H02:FLOPPY-USER)LINKAGE-LOAD-H02 - PSEG 123,989 and DSEG 2,184,977, both matching the
files byte for byte, i.e. **1067 pages**. They ran a control on 370 unrelated PSEG/DSEG files
on D:\ND\SI1.img rather than trusting offsets matched by eye, and reported the misses along
with the hits. So the round 1024 is imposed downstream of the descriptor.

**MY INFERENCE WAS WRONG, and the shape of the error is worth keeping.** I reasoned: the
measured L1 entries are HALFWORDS with bit 15 clear; the only code in our tree that writes a
page-table entry that way is `WritePte` on the growable path; therefore our growable path
built the table. The middle step is true and the conclusion still does not follow - SINTRAN
is a 16-bit machine writing halfwords natively, and these are SINTRAN's tables. "The only
code in OUR tree that does X" silently assumes the writer is in our tree at all.

Measured, with counters that cross-check (calls must equal ok + noSlot + mapFail):

```
GrowSegmentOnFault calls=12190 ok=0 noSlot=12190 mapFail=0 [counts agree]
lastMiss: dom 0 seg 22 (L1=2 L2=42) - no growable slot registered for that domain+segment pair
| NO growable segments registered at all
```

So our growable machinery never registered segment 22, never wrote an entry, and refused
every one of 12,190 grow attempts. It did not build the table and it is not the limiter.

Note why this needed a report and not a log line: the equivalent `Logger.Log` calls are at
Debug/Warning and do not reach this harness's transcript. An earlier grep of the run for
every growable log string returned ZERO hits, which looked like "the growable path is not
involved" and in fact proved nothing whatsoever about the code. Same trap as before, one
subsystem over.

**Where that leaves it.** SINTRAN mapped 1024 pages of a segment it has registered as 1067,
which is the ordinary demand-paging arrangement: the rest arrives when the swapper answers a
page fault. Each of our faults does produce a real MON 377B round trip, answered by real
SINTRAN with K=0, SWPFU=0x0000, SWPST=0x000A, every field constant. So the live question is
whether the page-in request we post correctly names the segment and page we want. [OPEN]

### 9a. Run status, stated rather than glossed

The run that produced the growable report FAILED its marker (-1) and took 8m36s against
4m23s for the previous one. The report above is still sound because it prints
unconditionally after RUN, but nothing here rests on the program having reached its banner,
and the earlier section's timings should not be compared with this run's.

## 10. The real microcode's page-fault path, located

Carved from MICRO-5800-B30.LABE plus the listing, on Ronny's instruction to let the microcode
answer rather than derive it. The MMS fault dispatch is a table of arms at 013016-013035,
each arm loading a fault code and jumping to a handler:

| arm | label | meaning | target |
|---|---|---|---|
| 013016 | `MMS_SIX0` | segment index zero | 013044 |
| 013031 | `MMS_PST0` | PST entry zero | 013042 -> 013044 |
| 013032 | `MMS_PSIX` | PS index | 013044 |
| 013033 | `MMS_PST` | PST | 013044 |
| 013034 | `MMS_SIX0` | segment index zero | 013044 |
| **013035** | **`MMS_LIX`** | **L-index - OUR CASE (L1 entry zero)** | 013044 |
| 013017, 013024-013030 | `PROTVIOL` | protection violation | 013036 |
| 013021-013023 | `MMS_ERROR` | hard error | 013102 |

So the real machine classes "L1 entry zero" as a PAGE FAULT THAT BUILDS AN INFORMATION
BLOCK, not as an error: 013044 -> `PF_NORM` (013051) -> `PF_PS` (013055) / `PF_PS_DATA`
(013062) / `PF_PS_DOM` (013064) -> `PF_PS_LA` (013065) -> `PF_INFO_OK` (013101) ->
`TRAP_PGF0`.

That chain reads `A,DMM,PS`, `A,DMM,ADOM`, `A,DMM,DOM`, `A,IMM,PS`, `A,IMM,DOM` and
`A,DMM,PHS` - the MMS registers naming the failing segment, domain and PHYSICAL SEGMENT - and
writes them into register-file slots selected by MARG/RFA1. Those slots ARE the page-in
request's fields.

DO NOT read the MARG numbers off the rendered listing: `MICRO-5800-B30.md` mis-renders
ORCON/MARG, which is exactly why this must be EXECUTED rather than read. The microword CPU
loads the real B30 and decodes the raw word itself, so running the routine reports the true
slot numbers and values. The established recipe is in `MailboxClrKickTests` - set
`cpu.State.Mpc` to the entry, wrap `IMicroMemory` in a recording decorator, tick with a
bounded budget, and treat an unimplemented microword as a finding that names the next thing
to implement. [OPEN - that test is the next piece of work]

### 10a. EXECUTED - what the real microcode does with a zero L1 entry

Test: `Nuget\HackerCorpLabs.Emulation.CPU.ND5000\tests\MmsPageFaultPathTests.cs`. Green.

**[V] The classification.** Entering the L-index arm `MMS_LIX` (013035) reaches `TRAP_PGF0`
(013430) and NEVER reaches `PROTVIOL` (013036) or `MMS_ERROR` (013102). So a zero L1 entry
is a page fault that builds a request. The dispatch-table reading in section 10 is confirmed
by execution, not by adjacency of labels - which is the failure mode that has bitten this
project before.

**[V] One field slot, confirmed by running rather than reading.**

```
CS 13050: SRF[0o35] DEADBEEF -> 00000000
```

CS 013050 is `A,DMM,PHS ... D,RF1`: it reads the PHYSICAL-SEGMENT MMS register and writes it
through `RFA1` into **SRF slot 0o35**. The rendered listing gives `MARG=035` for the word
that sets `RFA1`, and MARG is exactly the field `MICRO-5800-B30.md` mis-renders - so this is
the case where the machine had to be asked. It agrees. The VALUE is zero only because this
stub has no MMS state; the SLOT is the measurement.

**[V] The branch is real.** The two SC14 seeds walk different paths: bits 31:30 SET skips
`PF_NORM` and takes 013047/013050 (the DMM,PHS write above); bits CLEAR goes through
`PF_NORM` (013051). A control that could not tell them apart would mean the run described
the seeding, so this is asserted rather than assumed.

**[OPEN] The rest of the field set.** The CLEAR seed reached `PF_INFO_OK` without any
register write, so it took 013054 straight to the join and skipped the `PF_PS` chain
(013055-013100) where the remaining slots - including the `MARG=037` one - are written.
Driving it down that branch needs SC14/SC5 seeded to represent a real PS-type fault. That is
the next piece.

#### Three instrument defects, each of which reported a confident nothing

Recorded because all three are the same shape and it is the shape that wastes days.

1. **Memory-only recording**: reported `0 memory writes, 0 memory reads` for the whole path.
   True and useless - the chain writes the REGISTER FILE (`D,RFA1`/`D,RF1`), not memory. An
   empty log looked exactly like "the routine does nothing".
2. **A diff of the register file**: still reported ZERO changes, because the file and the
   stub both start at zero and a write of zero over zero is invisible to a diff. Fixed by
   poisoning every cell with `0xDEADBEEF` first, at which point the single real write
   appeared immediately. Same family as "a failed read and a real value are
   indistinguishable".
3. **The discrimination control compared the wrong quantity** - the final Mpc. Both branches
   converge on `TRAP_PGF0` BY DESIGN, so a routine that discriminates perfectly still ends at
   one address; it printed "did not discriminate" while `PF_NORM` was plainly visited by one
   seed and not the other. It now compares the visited PATHS and passes.

The general lesson, which is now three-for-three on this task: **an instrument that reports
nothing is making a claim about itself until something independent shows it can report
something.** The poison value, the read denominator on the L1 watch, and the
calls = ok + noSlot + mapFail cross-check are all the same device.

## 11. The full fault-information chain, driven and read (2026-08-28) [V]

§10a left one thing open: both SC14 seeds skipped the `PF_PS` chain (`013055`-`013100`), which is
where the remaining fault-information slots — including the `MARG=037` one — are written. That is
now driven and measured.

### The gate, read off the raw microwords

Two gates stand between `MMS_LIX` and `PF_PS`, and both sit under the B30 **one-word condition
delay** (a word's `COND` tests the flags the PREVIOUS word left):

```
013044  SC5 := SC14 AND 0o30000000000   (= 0xC0000000, bits 31:30)
013045  SC5 := SC5 XOR 0xC0000000
013046  COND,MZRO INVSEQ -> PF_NORM     tests the flags 013045 left
013051  SC5 := SC14 AND 0o03700000000   (= 0x1F000000, bits 28:24)
013052  SC5 := SC5 XOR 0o00600000000    (= 0x06000000)
013053  COND,MZRO -> PF_PS              tests the flags 013052 left
```

So `PF_PS` is taken exactly when `SC14 AND 0x1F000000 == 0x06000000`, with bits 31:30 clear.
Seed `SC14 = 0x06000000`. That is the whole answer, and it was not guessable from the label
names — `PF_NORM` and `PF_PS` are adjacent in the listing, which is the same adjacency trap that
has already produced two wrong claims on this project.

### What the chain actually writes

Four runs, all green (`MmsPageFaultPathTests`, 2/2):

| seed | path | register-file writes |
|---|---|---|
| `SC14=0xC0000000` | direct arm `013047/50`, no `PF_NORM` | `013050: SRF[0o35]` |
| `SC14=0x00000000` | `PF_NORM`, straight to the join | none |
| `SC14=0x06000000, SC7=0` | `PF_PS` -> `PF_PS_DATA` -> `PF_PS_DOM` -> `PF_PS_LA` | `013062: SRF[0o35]`, `013100: SRF[0o37]` |
| `SC14=0x06000000, SC7=1` | `PF_PS` -> (skips DATA/DOM) -> `PF_PS_LA` | `013060: SRF[0o35]`, `013100: SRF[0o37]` |

**The fault-information field set is two slots: `0o35` and `0o37`.** Every arm writes `0o35`; only
the `PF_PS` chain reaches `0o37`, which `013100` fills with `SC5 + SC7` after the four-step
rotate/shift at `013070`-`013077` assembles it. Both slot numbers come from `MARG` immediates
(`MARG=035` at `013047`/`013055`, `MARG=037` at `013065`) — the field `MICRO-5800-B30.md`
mis-renders, so these are only trustworthy because the machine decoded them, not the listing.

**`SC7` is the instruction-side / data-side discriminator.** `013056` runs SC7 through the ALU and
does nothing else; `013057`'s branch tests the flags it left. Measured: `SC7 = 0` takes the `DMM`
(data) arms, `SC7 != 0` takes `013060`'s `A,IMM,PS` (instruction) arm. The control run says the
two seeds walked genuinely different paths, so this is the routine branching and not the seeding.

### What this run does NOT establish

 - **The VALUES in `0o35` and `0o37` are stub artifacts, not fault information.** The MMS sources
   the chain reads (`DMM,PHS`, `IMM,PS`, `DMM,PS`, `DMM,DOM`, `DMM,ADOM`) are unseeded in this
   harness, so `0o37` came out `0x76` and `0x36`. The slot numbers and the path are the finding;
   the numbers are not.
 - **Why the `SC7=0` run reached `PF_PS_DOM`.** `013057` computes `SC14 AND BM25` for `013062`'s
   branch, and with `SC14 = 0x06000000` a bit-25 mask should be non-zero, which would fall through
   to `013063` (`DMM,ADOM`) instead. The machine took the branch. Either `BM25` is not bit 25 in
   this numbering or the delay lands differently than read here — `[OPEN]`, and it does not affect
   the slot result, which is identical on both arms.

### The open item this feeds

The comparison that matters is still ahead: decode the page-in request our side posts for one of
the 88 live faults and check it against this field set. We now know what the machine builds and
where it puts it, which is the half that was missing.

### 11a. CORRECTION to the closing line of §11 - that comparison is cross-generation

§11 ended with "decode the page-in request our side posts for one of the 88 live faults and check
it against this field set." **That comparison, as written, is not valid.** The field set in §11 was
carved from `MICRO-5800-B30.DATA` - the ND-5000 / SAMSON store. **The 88 faults are on the CLASSIC
lane**, whose store is `CONT-STORE-10611` (8192 x 18 bytes), a different machine's microcode.

Our own code already says so, at the exact place the request is built
(`Nd500MicrocodeServicer.AnswerTrapStopLocked`):

> The trap-dependent area (HW 0o17+) is GENERATION-SPECIFIC - settled 2026-08-11 by carving the
> classic writer at CS 011271-011337 ... **the header above is identical on both generations, the
> fault parameters are not.**

So the two halves I was about to compare are the two halves the code names as differing. The B30
carve in §11 stands on its own and is the right reference for the OCTOBUS lane; it is not the
reference for the classic faults.

There is a second gap in the same sentence, independent of generation: §11's slots `0o35` and
`0o37` are **scratch register-file slots**, written by `D,RFA1`/`D,RF1`. The page-in request's
`0o17`-`0o22` are **message offsets** in the 5MPM block. Nothing measured so far connects a
register-file slot to a message offset - a later writer moves them, and which slot lands at which
offset is `[OPEN]`. Lining the two number sets up because both are small octal numbers would be
the same mistake as reading dispatch off label adjacency.

### What the classic side actually writes, and where to read it

`CONT-STORE-10611.LISTING.TXT` disassembles the classic 144-bit word losslessly, so the classic
page-fault parameter writer is directly readable at `011314`-`011316`:

```
011314/ ALU,ADIR A,AM#31 D,AM#20 JMPNS 7546,0            fault LA
011315/ ALU,AND A,XD,SARG B,AL#35 D,AM#20 JMPNS 7550,7777  phys segment, masked 7777B
011316/ ALU,ADIR A,AM#27 D,AM#20 TYP,HW JMPNS 7550,0     composed status, ONE halfword
```

Three fields, and the surrounding words `011317`/`011322`/`011323` discriminate on the trap number
constants `44` (protect violation), `46` (page fault) and `45`. That matches what our writer posts
(`0o17`-`0o20` LA, `0o21` segment masked `0x0FFF`, `0o22` status halfword), which is unsurprising -
our writer was built from a carve of these same words in August.

**So the comparison for the classic lane is already done and already agrees.** The thing that is
NOT settled on the classic side is the one our own comment flags as `[D]`: which fault kind maps to
subtype code `6` / `7` / `10B`. `011126`-`011131` select it from **register bits** (`DSTS0` bit 4,
`DCINHLL` bit 27, `DCINHLL` bit 6), not from which page-table level came back zero - and this
emulator latches an MMWHERE nibble, which is a different code set. That mismatch is the live
candidate for why SINTRAN answers the 88 faults without extending the mapping, and it is a
classic-lane question that the B30 carve cannot speak to at all.

## 12. The classic subtype: already carved, and it points at our 88 faults (2026-08-28)

§11a named the classic subtype code (`6` / `7` / `10B`) as the live candidate. Checking the tree
before investigating it: **it is already carved, and marked `[V]`.** From
`Nd500MicrocodeServicer.AnswerTrapStopLocked`:

> **WHO SETS THESE BITS: NOBODY IN THE STORE.** A sweep of all 8192 words, separating the DEST
> field from the SOURCE field, finds ZERO writers for every one of them - `DSTS0` 0/2 refs as dest,
> `ISTS0` 0/2, `DCINHLL` 0/9, `ICINHLL` 0/6, `TRAPINF` 0/14. The microcode only ever READS them, so
> they are HARDWARE-SUPPLIED inputs composed by the memory-management hardware and presented at
> fault time. `[V]`

So the subtype cannot be composed from register bits in this emulator - those registers do not
exist here. The writer instead maps our own MMWHERE nibble onto the classic codes:

```
where == 0xD  ->  subtype 6    zero PST entry
where == 0xE  ->  subtype 7    zero 1st-level PTE
where == 0xF  ->  subtype 8    zero 2nd-level PTE (10B)
```

### The connection to the 88 faults

`CpuND500.MMU.cs:123` defines `MM_PFZ1 = 0xE`, and line 1127 - **the PS_ADI L1 branch, the one
taking all 88 faults** - sets exactly that. So every one of those faults is posted to SINTRAN with
**subtype 7, data side**.

And the carve in the same comment block says what subtype 7 means on a real classic machine:

> `011170` (codes 6/7) and its mirror `011213` do exactly one thing: **marshal a full report** ...
> `011146` (code 10B) is a different routine that ... can reach `011232` - whose DESTINATION is
> **TRAPCLR, the microcode CLEARING THE TRAP AND RESUMING**. TRAPCLR is NOT reachable from
> `011170`.

That is the same shape as the observed symptom: the fault gets described and never fixed, the page
refaults, SINTRAN answers every time with a constant `K=0, SWPFU=0x0000, SWPST=0x000A`.

### Why I am NOT changing the mapping

Two reasons, both from the tree rather than from caution in the abstract:

 1. **A structurally identical change was made here and reverted.** The data-side mapping was once
    changed `D -> 10B` on the argument that "data-side 6 is never serviced". The comment records
    that **both the argument and the change were dead**: a full fault census of a PASSING cpu-stat
    run shows data-side code-D faults serviced fine, and the real defect was one instruction
    raising many page faults. The neighbouring block carries **"AN EXPERIMENT WAS RUN HERE AND
    REVERTED - DO NOT RE-RUN IT."** My reasoning above has the same shape as the one that failed:
    subtype looks guilty, the fault count was the actual discriminator.
 2. **I have not established that the arm even applies to us.** On a real machine `011170`/`011146`
    are what the CPU's own microcode runs *before* a message reaches the ND-100. We do not run
    them - we post the message ourselves. Whether the subtype we send therefore steers anything at
    all, or is only read by SINTRAN's `DECOERRMESS`, is `[OPEN]`. Treating "10B reaches TRAPCLR" as
    a reason to send 10B assumes a routing we bypass.

The lead is real and worth settling, but settling it means a measured fault census either side of
the change, the way the last one was settled - not a one-line edit on a plausible story.

## 13. The fault census, both runs (2026-08-28) - and what it cannot separate

Ronny's call was to census before touching the subtype mapping. Done, on the failing
LINKAGE-LOAD-H02 run and on the passing CPU-STAT run. Both censuses reconcile their buckets against
an independent total, so neither is silently incomplete.

**First, a correction to a number I had been repeating: the fault count is not 88. It is 13,359.**

### Failing run - LINKAGE-LOAD-H02 (`RUN marker = -1`, timeout)

```
page-fault records posted: 13366  [buckets reconcile]
  subtype=106B side=inst where=0xD psn=11  faults=1      distinctAddr=1  worstRepeat=1
  subtype=6B   side=data where=0xD psn=12  faults=1      distinctAddr=1  worstRepeat=1
  subtype=110B side=inst where=0xF psn=11  faults=2      distinctAddr=2  worstRepeat=1
  subtype=10B  side=data where=0xF psn=12  faults=2      distinctAddr=2  worstRepeat=1
  subtype=3B   side=data where=0x3 psn=12  faults=1      distinctAddr=1  worstRepeat=1
  subtype=7B   side=data where=0xE psn=12  faults=13359  distinctAddr=1  worstRepeat=13359
```

### Passing run - CPU-STAT (`RUN marker = 0`, reached its output)

```
page-fault records posted: 142  [buckets reconcile]
  subtype=106B side=inst where=0xD psn=11  faults=1   distinctAddr=1   worstRepeat=1
  subtype=103B side=inst where=0x3 psn=11  faults=1   distinctAddr=1   worstRepeat=1
  subtype=6B   side=data where=0xD psn=12  faults=1   distinctAddr=1   worstRepeat=1
  subtype=6B   side=data where=0xD psn=13  faults=1   distinctAddr=1   worstRepeat=1
  subtype=3B   side=data where=0x3 psn=13  faults=1   distinctAddr=1   worstRepeat=1
  subtype=10B  side=data where=0xF psn=13  faults=62  distinctAddr=62  worstRepeat=1
  subtype=10B  side=data where=0xF psn=12  faults=3   distinctAddr=3   worstRepeat=1
  subtype=110B side=inst where=0xF psn=11  faults=8   distinctAddr=8   worstRepeat=1
  subtype=6B   side=data where=0xD psn=14  faults=1   distinctAddr=1   worstRepeat=1
  subtype=3B   side=data where=0x3 psn=14  faults=1   distinctAddr=1   worstRepeat=1
  subtype=10B  side=data where=0xF psn=14  faults=62  distinctAddr=62  worstRepeat=1
```

### What is established `[V]`

 - **A high fault count is normal.** Two passing buckets post 62 faults each - and 62 DISTINCT
   addresses each, every one faulting exactly once. That is demand paging walking forward. Count
   alone is not the pathology, which retires the "many faults = broken" reading directly.
 - **Repeat-at-one-address happens exactly once across both runs.** Of 13,508 posted records in
   13 + 6 buckets, every bucket has `worstRepeat=1` except subtype 7B, which has
   `worstRepeat=13359` at a single address (`0xB0215310`). The signature is unique and specific.
 - **`where=0x3` is routine, not a mystery.** §12's flag on it was wrong to raise: the PASSING run
   posts `3B` and `103B` too, once each, and is serviced fine. It is an ordinary fault kind our
   nibble mapping passes through unmapped. Withdrawn as a lead.
 - Independent corroboration of the big bucket: `[GROWABLE] calls=13359` matches
   `subtype=7B faults=13359` exactly. Two separate instruments, same number.

### What the census CANNOT settle, and this is the point

**Subtype 7B does not appear in the passing run at all.** So the passing run is SILENT on whether
subtype 7 is serviceable - it never exercises that path. The cross-run comparison, which is what I
proposed and what was chosen, turns out not to reach the question.

Worse for the tidy story: `where=0xE` IS "zero 1st-level PTE", and a zero L1 entry is exactly what
a partially-paged segment produces. **The subtype and the unmappable page are the same condition
described twice.** They co-occur by construction, so no census can separate "the subtype routes the
fault to a report-only engine" from "this page was never going to be mapped and the subtype is just
its name". Concluding the former from this data would be reading a correlation that cannot be
anything else.

That is the honest state: the signature is real and unique, and the mechanism behind it is still
`[OPEN]`. Separating the two needs an intervention, not another observation - and the previous
intervention of this exact shape was reverted as wrong, which is why it is not being made
unilaterally.

## 14. What the page-fault subtypes actually mean (2026-08-28)

There are **two different code sets**, one layered on the other, and this project has been sliding
between them. Naming them separately is most of the answer.

### Layer 1 - the HARDWARE where-code (this is what our emulator latches as MMWHERE)

`[V]` from the CURRENT NDIX-C source, `kernel/MASTER/machine/icb.h`, the `erx_HW` block that
describes the ND-5000 MMU status register:

```c
#define MMREQ   0xc000  /* request type */
#define MMWHERE 0xF     /* where the fault occured */
#define PVALTAC 0x1     /* violation on ALT access */
#define PVWVIOL 0x2     /* write protect violation */
#define MMINST  0x40    /* fault on I-channel access */
#define PFZPST  0xD     /* 0 in PST entry for page fault */
#define PFZ1    0xE     /* 0 in 1st level page table for page fault */
#define PFZ2    0xF     /* 0 in 2nd level page table for page fault */
```

So, plainly:

| code | meaning |
|---|---|
| `0xD` | the **PST entry** read back zero |
| `0xE` | the **1st-level page-table (index) entry** read back zero |
| `0xF` | the **2nd-level page-table entry** read back zero |
| `+0x40` | the fault was on the **I-channel** (instruction fetch), not data |
| `0x1` / `0x2` | ALT-access violation / write-protect violation (protection, not page fault) |

Our `CpuND500.MMU.cs` constants `MM_PSTZ=0xD`, `MM_PFZ1=0xE`, `MM_PFZ2=0xF`, `MM_INST=0x40` are
**exactly this set** - so what we latch is the real hardware encoding, not an invention.

Independent agreement from `ND-05.020.01` (ND-5000 Hardware Description), which enumerates the same
three conditions as MMS nanostates rather than as codes: state 4 PSCAPT *"The PST entry contains
zero. Page fault"*; state 6 CAPIT *"The index-entry contains zero. Page fault"*; and the same test
again at the second indexing level. Three zero-tests, three codes, same order.

**So our live fault - `where=0xE` - means: the first-level page-table entry for that address read
back zero.** Which is precisely what a segment paged in only as far as 1024 of its 1067 pages
looks like. The census bucket's name and the known condition are the same fact.

### Layer 2 - the CLASSIC MESSAGE subtype (what we post at message offset 0o22)

`[V]` values, read straight out of `CONT-STORE-10611.LISTING.TXT` (the immediates are OCTAL):

```
011140/ ALU,OR A,XD,SARG B,AM#27 D,AM#27 TYP,HW JMP SLOW2 11170,6     data
011141/ ...                                            JMP SLOW2 11170,7     data
011142/ ...                                            JMP SLOW2 11146,10    data
011143/ ...                                            JMP SLOW2 11211,106   instruction
011144/ ...                                            JMP SLOW2 11211,107   instruction
011145/ ...                                            JMP SLOW2 11211,110   instruction
```

Six codes: `6`/`7`/`10B` data, `106B`/`107B`/`110B` instruction, i.e. **+100B = instruction side**
(and `100B = 0x40`, the same side bit as layer 1). Note the jump targets differ - `10B` goes to
`11146`, the other two to `11170` - which is the engine split already recorded in §12.

**The mapping from layer 1 to layer 2 is still `[D]`.** The selector at `011126`-`011131` picks the
code from `DSTS0` bit 4 and `DCINHLL` bits 27 and 6 - hardware inputs with no writer anywhere in
the store - not by branching on which table level came back zero. Our writer assumes the two sets
run in the same escalating order (`D->6`, `E->7`, `F->10B`). That is plausible and unproven.

### A trap I nearly published

NDIX also contains a clean-looking enumeration that would have named the layer-2 codes outright:

```c
#define PFZPSTD 0     /* 0 in PST for data page fault */
#define PFZPF1D 1     /* 0 in 1st level PT for data page fault */
#define PFZPF2D 2     /* 0 in 2nd level PT for data page fault */
#define PFZPSTI 0100  /* ... instruction page fault */
```

Same shape as the classic codes, same `+0100` side bit - and it disagrees with the microcode by a
constant 6. **It is a DELETED REVISION.** It lives only in `SCCS/s.icb.h`, wrapped in `D 28`/`E 28`
delete markers, and `grep` outside the SCCS files finds no `pf_info` or `PFZPSTD` anywhere. An
SCCS history file reads like ordinary source and silently interleaves every revision ever made, so
a plain grep of it returns superseded definitions with no signal that they are dead.

**Rule for this repo: never quote `NDIX-C/kernel/.../SCCS/s.*` - read the file without the `s.`
prefix.** The surviving definitions are layer 1 above.

### The consequence for the subtype-routing theory

SINTRAN's own level-12 trap decoder (`MP-P2-N500.NPL:135320` `TRAPDECODER`) does this and nothing
more: read `TRAPN`; if `>53` unknown-trap; **if `=46` page fault** -> refuse if the faulting process
IS the swapper -> stamp `MSWPFAULT SHZ 10 + D` into `TRAPN` -> `CALL 5ACTSWAPPER`.

**It never reads offset 0o22.** The subtype does not steer anything on the SINTRAN side at level 12.
So the §12 theory - that sending `10B` instead of `7` would route the fault to an engine that can
resolve it - is about routing *inside the real classic microcode*, which is exactly the part we
replace. On our lane the message goes straight to SINTRAN, which discriminates only on `TRAPN=46`.
That substantially weakens the theory, and it is a reason to be glad the mapping was not changed on
it. `[V]` for what the decoder reads; `[OPEN]` for what the swapper does with 0o22 downstream - the
swapper carve calls its `MSWPFAULT` handler bookkeeping that does no paging, but that name is
`INFERRED`, not carved.

### Caveat on the NDIX evidence (Ronny, 2026-08-28)

**NDIX is not stock SINTRAN.** It reaches the machine through `MON 600` and needs a specially-built
SINTRAN, so anything read out of the NDIX kernel describes what NDIX expects, and can differ from
what a stock-SINTRAN machine presents. That applies to the whole of layer 1 above, so grade it
carefully rather than treating a C header as the machine:

 - **The three CONDITIONS are independently confirmed and do not rest on NDIX at all** - zero PST
   entry, zero index entry at the first level, zero index entry at the second level, in that order,
   are enumerated as MMS nanostates 4 / 6 / (repeat) in `ND-05.020.01`, which is hardware
   documentation. `[V]`
 - **The numeric assignment `0xD`/`0xE`/`0xF` to those three conditions rests on NDIX alone.** The
   manual names the conditions without numbering them. So this is one source, from a kernel with a
   non-standard OS seam. Downgrade to `[V, single source - NDIX]` and treat a disagreement with a
   stock-SINTRAN observation as evidence against the numbering, not against the machine.
 - The layer-2 classic codes (`6`/`7`/`10B`, `+100B`) do NOT depend on NDIX - they are read out of
   the classic microcode image itself. Unaffected by this caveat.

This does not change the practical conclusion, because our emulator's `MM_PFZ1=0xE` and the census
bucket are OUR OWN encoding on both sides of the comparison - the value we latch and the value we
map from are the same constant. Where it WOULD bite is any claim about what real hardware puts on
the wire, which is precisely the claim the subtype-routing theory needs.

## 15. The swapper dispatch census - and a question it opens (2026-08-28)

§14 left `[OPEN]` what the swapper does with the fault record. Following that: the swapper's
function table (`swapper-k01-handlers.md`) marks **fn 10 `MSWPFAULT` as reaching no paging
primitive and no MON 377B**. The handlers that actually page in are fn 8 (connect/page-in, RPHS),
fn 22 (page-in working set, RPHS) and fn 28 `MSWDO` (perform swap, RPHS).

So: which functions are actually dispatched? The harness already samples the request block, so this
is a tally of an existing field (`DISP@0x240B8`), not a new instrument.

### Whole 12-program run

```
DISP  count   handler (from the carved function table)
0x0A   2490   10  MSWPFAULT - page-fault notification/accounting  (no paging, no MON)
0x00    378    0  MSWFI - free/finish one segment slot
0x18     89   24  create/define a segment descriptor
0x0F     28   15  mirror of fn 14 (detach)
0x05     26    5  initialize/activate swapper working set
0x03     26    3  release a range of segments/pages
0x09     17    9  allocate+link a segment
0xFFFFFFFF 1      sentinel
```

**Functions 8, 22 and 28 - every one of the RPHS page-in handlers - are never dispatched. Not once,
in any of the twelve programs.**

### The control that stops this becoming a wrong conclusion

That looked like the answer: the swapper is told about faults and never told to page anything in.
Then the passing run:

```
=== DISP in the PASSING cpu-stat-only run ===
     64   0x0A   (and nothing else)
```

**CPU-STAT passes while dispatching fn 10 and NOTHING ELSE** - and its fault census shows 142
faults including two buckets of 62 faults over 62 distinct addresses each, which is pages being
successfully mapped and the program walking forward.

So an fn-10-only dispatch pattern is what a **working** run looks like. The absence of fn 8/22/28
is normal, not pathological, and the failing run's fn-10 dominance is not an anomaly either. The
hypothesis dies here. (The failing run shows more distinct codes only because it runs twelve
programs; per-program, `0x0A` dominates for every one of them, passing and failing alike.)

### The question this opens, which is worth more than the hypothesis it replaced

If fn 10 does no paging and no MON, **what maps the 62 pages in the passing run?** Two candidates,
and they have very different consequences:

 1. The `no paging / no MON` carve of fn 10 is wrong. It is derived from a call-tree reachability
    scan, which can miss an indirect call - the same class of instrument that has under-reported
    here before.
 2. The pages are not being mapped by the swapper at all, but by something on our side of the
    seam. That would matter a great deal, because THE GOAL is that real SINTRAN does this work -
    and "who actually mapped the page" is the same question as "who answered the MON call".

`[OPEN]`, and deliberately not guessed. Candidate 2 is the one to test first, because it is
cheap - the page-in write has to happen somewhere, and a watch on the L2 table page during a
PASSING run says immediately whether the writer is SINTRAN or us. That is the same instrument
already built for the L1 table in §7, pointed one level down.

### Method note

The first tally I ran was over the whole log and would have attributed twelve programs' traffic to
the linkage loader. The log interleaves programs and tags each line (`[CPUSTAT]`, `[LINKAGELOADER]`
...); the tags are the only thing separating them. Caught by reading the context of the matched
lines instead of trusting the count - a whole-file `uniq -c` over a multi-subject log is a
confident number about the wrong population.
