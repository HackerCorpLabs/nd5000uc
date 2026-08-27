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
