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

## 4. RESULTS ON THE REAL-SINTRAN LANE

Each row is `Nd500_<name>_UnderRealSintran_RealCpu_Capture`. The two hard assertions in the shared
helper are what make a row mean anything:

 - `EmulatedMonPathMarker.Count == 0` — our C# MON layer answered NOTHING.
 - `RealSintranMonRoundTrips > 0` whenever the program printed — the output came from SINTRAN.

| program | banner | MON round-trips | fake answers | verdict |
|---|---|---:|---:|---|
| CPU-STAT | `[V]` prior | | 0 | runs |
| LED-FORTRAN-A01 | `[V]` prior | | 0 | runs |
| CONVERT-DOM-A03 | `[OPEN]` | | | |
| CAT-CAT5-B06 | **`[V]` prints** | 263 page faults serviced | 0 | **RUNS AND TERMINATES CLEANLY** |
| PLANC-500-G00 | `[OPEN]` | | | |
| NC-A06 | `[OPEN]` | | | |
| AUTOMAKE-500-C00 | `[OPEN]` | | | |
| CODE-COVERAGE | `[OPEN]` | | | |
| LINKAGE-LOAD-H02 | `[OPEN]` | | | from the floppy |

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
**The pairing that makes CONVERT-DOM and CAT-CAT5 worth running together:** CONVERT-DOM is the
heaviest `callg`-family user in the corpus (69 MON sites, 43 distinct, `513B` ×14); CAT-CAT5 has
**zero** callg and no `511B/512B/513B/514B` at all. If CAT passes and CONVERT fails, the fault is in
the callg family and nowhere else.
