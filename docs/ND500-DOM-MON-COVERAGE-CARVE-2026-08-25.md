# Which MON calls the other ND-500 DOM programs need — and which we have never answered

**Created 2026-08-25.** Full path:
`E:\Dev\Ronny\ND5000UC\docs\ND500-DOM-MON-COVERAGE-CARVE-2026-08-25.md`

**Why this exists.** CPU-STAT now runs end to end under real SINTRAN with its MON calls forwarded.
The next programs are the rest of the FraTor bundle, and each one will stop at the first MON call the
lane cannot carry. This says **what is coming, before we hit it**, so a stop can be recognised in one
lookup instead of a debugging session.

**Source.** The ten disassemblies under
`E:\Dev\Ronny\NDInsight\SINTRAN\ND500-APPS\<PROGRAM>\analysis\*.asm`.

---

## 0. HOW THIS WAS MEASURED, AND THE FALSE NEGATIVE IT PRODUCED FIRST

A MON call is a `call`/`callg` into the segment-31 trampoline: the target is `0xFFFFFFFFF80000nn`
(or `0xF80000nn` in the `callg` short form) and **`nn` is the MON number in hex**. The disassembler
also appends a `; MON <n>B <NAME>` comment.

**Two extraction methods disagreed, and the convenient one was wrong.**

| method | 511B/512B users found |
|---|---|
| `grep "; MON 511B "` — the disassembler's COMMENT, with a trailing space before the name | **0 — "nothing in the corpus uses 511B/512B"** |
| `grep "F8000149"` — the RAW TRAMPOLINE TARGET | **3 programs** |

The comment-based grep required a space *and a name* after the number. Where the disassembler emitted
`; MON 511B` with **no name**, the pattern did not match — and returned a clean, confident, empty
result. **I had already drafted the conclusion "the 504B-only scope covers every program available,
so 511B/512B is a non-issue for this corpus." It is the exact opposite of the truth**, and it would
have retired a real gap.

**RULE FOR THIS FILE AND ANY LIKE IT: count MON usage from the RAW TRAMPOLINE TARGET
(`F80000nn`), never from the disassembler's comment.** The comment is a decode; the target is the
instruction. This is the same lesson as `LDDTX` and the swapper-handlers sentence — a summary of a
carve is not the carve — arriving for the third time in one day, now in the shape of a grep pattern.

**Positive control (run BEFORE trusting any number here):** the method reproduces CPU-STAT's
independently derived totals exactly — **28 distinct MON numbers, 43 call sites**, matching
`CPU-STAT-PC-ADDRESS-MAP-2026-08-25.md`, which derived them from the trampoline targets with no
reference to this file.

---

## 0b. THE ANSWER TO RONNY'S ACTUAL QUESTION — and it closes for the WHOLE remaining list

Ronny's reframing retired the per-program MON tally: *"number of mon calls doesnt matter when we are
talking to SINTRAN as SINTRAN is fucking answering all of them. what you need to find out is if cpu
microcode is special handling some of the MON calls and implement that functionality."*

**`[V]` THE COMPLETE ANSWER, CLASSIC LANE: `{504B, 511B, 512B}`. ALL THREE ARE IMPLEMENTED. NOTHING
ELSE IN THIS CORPUS NEEDS ANYTHING FROM THE MICROCODE.**

Three independent legs, each closed separately (detail in
`CLASSIC-STORE-MON-SCREENING-CARVE-2026-08-25.md`):

1. **The screening chain is CLOSED and SINGLE-ENTRY.** Counted every jump target in the store:
   exactly **one** word reaches the chain head (`010507 → 010511`); `010660` and `010661` have
   **zero** inbound jumps and are fall-through only; all three compares converge on `010662`. There
   is no second way in, so no other MON number can be screened on this path.
2. **The chain ENDS.** `010661` is a `POPRET` — structurally there is no fourth compare for a fourth
   MON number to be absent from. (This is the strong form of the negative; enumerating compares
   against `AL#35` is *not*, because `AL#35` is reused scratch.)
3. **The other assist families are called by NO program.** `500B/501B/502B/600B`,
   `270B/271B/333B/335B`, `201B` — **zero** users across all ten disassemblies, counted off raw
   trampoline targets with a positive control (§5 of the classic carve).

**Therefore CONVERT-DOM-A03 (26 new MON numbers), LINKER-B01 (30) and NC-A06 (6) introduce ZERO new
microcode obligations.** Every one of those new numbers is an ordinary forwarded call that real
SINTRAN answers. The 26/30/6 columns in §2 below measure *how much new SINTRAN surface each program
exercises* — they do **not** measure work for us.

**What this does NOT say.** It says nothing about non-MON microcode behaviour — the page-fault
subtype selector was exactly such a case, and it stopped LED dead. "The microcode has no MON
obligation for this program" and "this program will run" are different claims.

## 1. THE HEADLINE — the inline-copy family is NOT covered

MON 504B needed us to copy the user buffer into the message ourselves (the `WSMC` arm of
`MP-P2-N500.NPL:140656`). That fix was deliberately scoped to **504B only**, because 511B/512B
operand layouts were unverified. Counted off the raw targets:

| program | 511B | 512B | 513B | 504B |
|---|---|---|---|---|
| CONVERT-DOM-A03 | 1 | 1 | **14** | 3 |
| LED-FORTRAN-A01 | 1 | 1 | **9** | 2 |
| LINKER-B01 | 1 | 1 | **14** | 2 |
| CPU-STAT | 0 | 0 | 0 | 1 |
| FILE-COMPARE | 0 | 0 | 0 | 1 |
| NC-A06 | 0 | 0 | 0 | 1 |
| TEST-REAL | 0 | 0 | 0 | 1 |

**Three programs will hit 511B and 512B**, and the same three lean heavily on **513B**, which was
never in the inline set at all and is used far more than either. **LINKER-B01 is on that list and
LINKER-B01 is the program that currently fails** (`nd500-apps` skill: *"the link still fails:
LINKER-B01 never prints its ND LINKER banner"*). Whether the two facts are connected is `[OPEN]` —
this file does not claim it — but it is the first thing to check on that program.

> **UPDATE 2026-08-25 — a candidate, with the boundary stated.** `513B`'s buffer path posts a
> **DMEMRD** (see the resolved `[OPEN]` below), and classic `DMEMRD` was **unimplemented until
> 2026-08-25** — it answered `5ERANSWER` to every request and was the root cause of LED's MON 50B
> stall. LINKER-B01 uses `513B` **fourteen times**, the most in the corpus.
>
> **BUT THE KNOWN LINKER FAILURE IS ON A DIFFERENT LANE.** That symptom was recorded against the
> RetroCore **standalone DOM runner** (the `SintranEmulation` path, during the byte-exact compile
> work), **not** the Gate5R real-SINTRAN lane where `DMEMRD` lives. So this does **not** explain the
> recorded failure, and must not be written up as if it did.
>
> What it does mean: **when LINKER-B01 is first run on the Gate5R lane, the fixed `DMEMRD` removes
> the one blocker we know it would otherwise have hit fourteen times.** Whether its standalone-lane
> failure has the same cause is still `[OPEN]`, and the two lanes must be compared, not conflated.

### THE WHOLE `5xx` FAMILY DECODED — SINTRAN's level-12 dispatch table `[V]`

`MP-P2-N500.NPL:137332-137365`. `SYMBOL L12MIN=500`, `SYMBOL L12MAX=523`, dispatch
`5CMNO-L12MIN GOSW` over 20 entries. **Every MON in `500B`–`523B` maps to a named handler:**

| MON | handler | MON | handler |
|---|---|---|---|
| `500B` | `STAPROC` | `512B` | `A5XMSG` — XMSGCallA |
| `501B` | `NSTOPROC` | `513B` | `B5XMSG` — XMSGCallB |
| `502B` | `SWITPROC` | `514B` | `M5TMOUT` — ND500TimeOut |
| `503B` | `NINSTR` | `515B` | `5MTRANS` |
| **`504B`** | **`NOUTSTR`** — OutputString | `516B` | `M516` — patch stub |
| **`505B`** | **`GERRC`** — GetTrapReason | `517B` | `M517` — patch stub |
| `506B` | `5SIBMO` | `520B` | `M520` — patch stub |
| `507B` | `SPRIO` | `521B` | `M521` — patch stub |
| `510B` | `SWMC` | `522B` | `M522` — patch stub |
| **`511B`** | **`DVIO`** | `523B` | `M523` — patch stub |

**Confirmed five independent ways** against the per-call specs: `504B` = OutputString = `NOUTSTR`,
`505B` = GetTrapReason = `GERRC`, `511B` = DVIO = `DVIO`, `512B`/`513B` = XMSGCallA/B =
`A5XMSG`/`B5XMSG`, `514B` = ND500TimeOut = `M5TMOUT`. The alignment is exact at both ends
(`L12MIN`=500B at index 0, `L12MAX`=523B at index 19).

**`516B`–`523B` are unimplemented patch stubs** — `M516: GO NORMMC; 0/\0` and friends at `137451+`,
described in the source as *"ENTRIES FOR PATCHING IN ADDRS TO NEW DRIVER-LEVEL MONITOR CALLS"*. If a
program calls one, it falls through to `NORMMC`, i.e. the ordinary system-monitor path.

### CONVERT-DOM adds `505B` and `514B` — neither is inline-copied `[V]`

- **`505B GetTrapReason`** reads the swapper's error code, *"only relevant to programmed trap
  handlers … the swapper starts the trap handler when it detects a fatal error"*. **It CLEARS the
  code when read** — a destructive read, so an emulator that answers it twice gives different (and
  correct) answers, and one that caches it is wrong. Ties directly into the `SWPST`/error machinery.

  **SAFE ON THE GATE5R LANE, VERIFIED 2026-08-25** — but the thing that *could* have broken it was
  checked rather than assumed. Since SINTRAN owns the destructive semantics, correctness needs each
  call **delivered exactly once**. The only re-execution in the bridge is
  `retryFaultingInstruction: true`, set on **exactly one path** — the TRAP stop at
  `Nd500CpuProcessBridge.cs:180`. The monitor-call stop defaults it to **false**, so a MON call is
  never replayed. **Give `505B` no cache and no replay.**
- **`514B ND500TimeOut`** suspends the program in an **ND-500 time queue, not the ND-100's**, and the
  spec explicitly says to use it rather than MON `267B` TimeOut from the ND-500 side.

### `[OPEN]` RESOLVED 2026-08-25 — `513B` IS NOT INLINE-COPIED *BECAUSE IT DOES NOT NEED TO BE* `[V]`

The old warning stands as method (never assume adjacency), but the question now has an answer, and it
did **not** come from `CALL_5_MATCH` — it came from the SINTRAN side.

**`512B` (A5XMSG) and `513B` (B5XMSG) ARE THE SAME HANDLER.** `SUBR A5XMSG,B5XMSG` at
`MP-P2-N500.NPL:2062`; both labels fall into ONE body at `:2076-2077` with **no branch on the MON
number**. The only difference is the buffer convention — **B carries its data buffer via `LBUFA`
(`0o141`)**, and subfunctions **6 `LFREA` / 7 `LFWRI` / 53 `LFWRT`** are commented *"use B5XMSG"*.

Those three subfunctions fetch the buffer **by posting a DMEMRD**, at `142254-142337`:

```
142301   IF MIFLAG NBIT WSMC THEN            % buffer NOT already in the com-buffer?
142304      A:=D; *AAX NRBYT; STATX          % NRBYT := byte count
142310      *AAX 5DITN-NRBYT; STZTX          % 5DITN := 0
142312      *AAX X5BUF-5DITN; LDDTX; AAX N500A-X5BUF; STDTX   % N500A := ND-500 buffer addr
142316      *AAX ABUFA-N500A; LDDTX ; CNVWADR
142323      *AAX N100A-ABUFA; STDTX          % N100A := converted com-buffer addr
142326      "INFWRIT"; *AAX SPFLA-N100A; STATX
142332      3RMED; *STATX XMICF              % MICFU := 3RMED (0o10 DMEMRD)
142334      MSGN500; CALL WN5STATUS
```

**Exactly the copy-family field contract** (`N500A` / `N100A` / `NRBYT` / `5DITN=0` / `SPFLA`), and the
write side mirrors it with `3WMED` + `INFRRE` at `143075-143105`.

**So `513B` is outside the microcode's inline-copy set by design: its buffer crosses by data-memory
read instead.** With classic `DMEMRD`/`DMEMWR` implemented (2026-08-25), the mechanism `513B` needs
exists. **The discriminator is `MIFLAG` bit 0 `WSMC`** ("the data buffer is in the communication
buffer"): set ⇒ no transfer needed; clear ⇒ a DMEMRD is posted.

`[OPEN]` remaining: whether `CALL_5_MATCH` also has something to say about `513B`. The SINTRAN-side
answer above is sufficient to explain the exclusion and to predict behaviour, so this is no longer
blocking.

---

## 1b. WHAT 511B / 512B / 513B ACTUALLY REQUIRE — carved, and smaller than the counts suggest

**Ronny's order is LED → CONVERT → LINKER → NC.** All three of the first are blocked on this one
family, so it is the critical path. Carved from the reference (`[V]`) and the NPL source rather than
inferred from the call counts.

**`513B` — the most-used of the three (14 / 9 / 14 sites) — needs NOTHING, and doing the obvious
thing to it is a BUG.** The microcode's inline set is exactly `{504B, 511B, 512B}`
(`CALL_5XX 004013B`–`004016B` → `CALL_5_MATCH 013667B`, `MICRO-5800-B30.LABE:376`). `513B` (`B5XMSG`)
shares the *ND-100* handler body with `512B` (both reach `142053`), which makes it look like a
sibling — and the reference flags this verbatim: *"An emulator that treats `512B` and `513B` alike
will be wrong on the ND-5000 side."* **Sharing a SINTRAN handler is not sharing a microcode
obligation.** So the heaviest user of the family is free, provided nobody "tidies" it into the set.

**`511B` `DVIO` — the outbound copy is literally the SAME ROUTINE as `504B`.**
`MP-P2-N500.NPL:140627` is `SUBR DVIO,NOUTSTR` with **both labels on the same address**:
```
140627   DVIO:
140627   NOUTSTR:
140627          CALL 5GTDF; GO NORMMC              % IF TERMINAL GET ADDR OF DATAFIELD
140631          A:=D; ... *AAX TODF; STATX         % TODF = OUTPUT DATAFIELD
140636          *AAX DNOBY-TODF; LDDTX; AAX -DNOBY % D = number of bytes
140641          IF A><0 OR D>>4000 THEN            % 4000B MAX because of com-buffer size
140645             A:=EC174; CALL EMONICO          % oversize -> restart process with error
140651          ELSE IF D=0 THEN CALL OSTRS        % zero bytes -> restart, no copy
```
So the copy obligation, the byte count source (`DNOBY`), the `4000B` ceiling and the `EC174`
oversize error are **identical** to the already-working `504B`. `[V]`

**BUT `511B` IS NOT A FREE EXTENSION — it has a second half `504B` does not.** At `OSTRS`
(`141005`) the shared body discriminates:
```
141012          *AAX SMCNO; LDATX; AAX -SMCNO      % A = monitor call number
141016          IF A=511 THEN                      % DVIO
141021             T:=5MBBANK
141022             *AAX 11DMA; LDDTX               % max number of bytes, continue
141025             X=:N5MESSAGE; CALL XNINSTR      % XNINSTR in NINSTR (mon DVINST)
141027          FI
```
**`DVIO` is bidirectional**: after the output it reads up to `11DMA` bytes *back* into the process
via the `DVINST` input path. `504B` (`NOUTSTR`) is output only. Whether that return leg needs
anything from our side, or rides the ordinary answer write-back, was **`[OPEN]`** — do not assume it
is free. This is precisely the assumption I was about to make from "shares a handler".

> **NARROWED 2026-08-25, classic lane only.** The classic store's match arm was walked forward
> (`010662 → 010741 → 010735 → 010527/010522`, see
> `CLASSIC-STORE-MON-SCREENING-CARVE-2026-08-25.md` §4): **no word on that path compares the MON
> number again, and none reads bytes back into the process.** So on the CLASSIC engine the inbound
> half of `DVIO` is SINTRAN's ordinary answer write-back, not a microcode obligation. **Still
> `[OPEN]` for the B30** — `CALL_5_MATCH 013667B` is a different routine in a different store and
> has not been walked. Do not carry the classic verdict across; that is the same
> one-store-answers-for-the-other error the addresses table warns about.

**`512B` `A5XMSG` — our obligation is the same copy; the complexity is SINTRAN's, not ours.**
`142053` dispatches a **32-way function switch** on `N5XFU` (`LFGET`/`LFREL`/`LFSND`/`LFRCV`/…),
allocates an xtblock through `MON 2XMSG`, and so on. **None of that is ours** — real SINTRAN runs it.
The ND-5000 side owes only the inline buffer copy, the same shape as `504B`. Do not let the size of
the XMSG subsystem be mistaken for the size of our task.

**NET IMPLEMENTATION for Ronny's first three programs:** extend the existing `504B` inline copy to
`511B` and `512B` (same mechanism, same `DNOBY`/`4000B`/`EC174` contract), **explicitly exclude
`513B`**, and settle the `511B` input-leg `[OPEN]`. That is one change plus one open question — not
the three separate subsystems the 14/9/14 call counts imply.

---

## 1c. THERE ARE TWO LEDs, AND ONLY ONE OF THEM NEEDS A DESCRIPTION FILE

**A domain reaches SINTRAN in one of two shapes, and the difference decides whether
`PLACE-DOMAIN` touches a description file at all.** Classified by listing every program's
`files/` folder — what it actually ships, not what a guide says:

| program | ships | description file needed |
|---|---|---|
| all eleven others (CPU-STAT, CONVERT-DOM-A03, LINKER-B01, NC-A06, TEST-REAL, …) | exactly one self-contained `.DOM` | **no** |
| **LED-FORTRAN-A01** | `LED-FORTRAN-A01.DOM` (1,302,269 B), single file | **no** |
| **LED-NEW** | `LED-NEW.DOM` (625,949 B) **plus** `LED-B03.PSEG` (223,695 B) + `LED-B03.DSEG` (394,525 B) + the `LED-DEBUGGER-B03` pair | the `:PSEG`/`:DSEG` route does |

**`LED-B03` exists ONLY as a `PSEG`/`DSEG` pair, under `LED-NEW`.** It is a description-file
domain by construction — the registry holds the entry and the segment names, and on the
distribution media those names are written as **absolute volume references**:
`(211160B03-XX-01D:FLOPPY-USER)LED-B03PSEG`. Measured 2026-08-25 by dumping the pack's own
`(SYSTEM)DESCRIPTION-FILE:DESC` (22528 B): the prefix appears at offsets `0x000800`, `0x004004`
and `0x0040C4`. **Copying the segments onto the pack cannot fix that** — the name resolves to a
volume and a user, not to a file.

**`LED-FORTRAN-A01` is the row in this file's tables** (35 distinct MONs, 20 new, the
`511B/512B/513B` family) and **the "led" in Ronny's `LED → CONVERT → LINKER → NC` order.** It is
one self-contained `.DOM`, so it should place the same way CPU-STAT does, with no description
file, no segment registry and no volume prefix anywhere in the path.

**`[OPEN]` — whether `LED-FORTRAN-A01.DOM` is installed on the working pack image.** The pack
carries `SYSTEM/LED-B03` ×2 and `SYSTEM/CPU-STAT`, so LED-B03 was put there deliberately and
LED-FORTRAN-A01 may simply be absent. Source file:
`E:\Dev\Ronny\NDInsight\SINTRAN\ND500-APPS\LED-FORTRAN-A01\files\LED-FORTRAN-A01.DOM`.

> **METHOD NOTE — a control run must exercise the mechanism it claims to test.** A CPU-STAT run
> was used as the control for "did mounting the floppy break description-file lookup?" and
> **could not answer it**: CPU-STAT is a self-contained `.DOM` and never opens a description file.
> It passed, which tests only that the mount does not break the ND-500 lane generally. Same shape
> as every other false negative in this file — **the instrument could not have shown the thing it
> was pointed at**, and a pass read exactly like a healthy subject. Check that the control TOUCHES
> the mechanism before reading its result.

## 2. NEXT-PROGRAM ORDER — cheapest first

"NEW" = MON numbers this program uses that **CPU-STAT never exercised**, so they have never been
carried by the forwarded lane.

| program | distinct MONs | NEW | the new ones |
|---|---|---|---|
| **TEST-REAL** | 27 | **0** | — every MON it uses, CPU-STAT already proved |
| **CODE-COVERAGE** | 15 | **1** | `113B` |
| **AUTOMAKE-500-C00** | 13 | **2** | `312B` `321B` |
| NC-A06 | 34 | 6 | `12B` `113B` `256B` `312B` `317B` `321B` |
| PLANC-500-G00 | 23 | 10 | `3B` `4B` `12B` `45B` `113B` `162B` `263B` `312B` `321B` `327B` |
| FILE-COMPARE | 27 | 11 | `16B` `45B` `70B` `74B` `75B` `113B` `141B` `162B` `256B` `312B` `321B` |
| LED-FORTRAN-A01 | 35 | 20 | incl. `511B` `512B` `513B` `514B` `505B` |
| CONVERT-DOM-A03 | 43 | 26 | incl. `511B` `512B` `513B` `514B` `505B` |
| LINKER-B01 | 48 | **30** | incl. `511B` `512B` `513B` `514B` `505B` |

> ## ⚠️ THIS CENSUS IS OF THE **ND500-APPS BUNDLE**, NOT THE MOUNTED PACK (corrected 2026-08-25)
>
> The tables in this file are built from `E:\Dev\Ronny\NDInsight\SINTRAN\ND500-APPS\*\analysis\`.
> **`D:\BIGDISK0-L-DOMS.IMG` holds a DIFFERENT, SMALLER set** — enumerated (not pattern-matched),
> exactly **8** `:DOM` files:
>
> `AUTOMAKE-500-C00` · `CAT-CAT5-B06` · `CODE-COVERAGE` · `CONVERT-DOM-A03` · `CPU-STAT` ·
> `LED-FORTRAN-A01` · `NC-A06` · `PLANC-500-G00`
>
> **`LINKER-B01` IS NOT ON THE PACK IN ANY FORM.** What is there under that name is
> `BRF-LINKER-C01:PROG` (an ND-100 program) and `LINKAGE-LOAD-H02` (PSEG/DSEG) — **different
> programs, not alternate forms.** So Ronny's `LED → CONVERT → LINKER → NC` order is runnable here
> only as **LED → CONVERT-DOM-A03 → NC-A06**; LINKER needs an image hunt before it is a target.
>
> **`TEST-REAL` and `FILE-COMPARE` are also absent from the pack**, which retires the recommendation
> immediately below — see the corrected one.
>
> **CHEAPEST NEXT RUNS THAT ARE ACTUALLY ON THE PACK:** `CODE-COVERAGE` (**1** new MON: `113B`),
> then `AUTOMAKE-500-C00` (**2** new: `312B` `321B`) — and `312B`/`321B` are already reached by LED.
>
> **`CAT-CAT5-B06` — `[OPEN]` CLOSED 2026-08-25, censused straight from the DOM bytes.** It has no
> `analysis/` folder, so it was scanned for trampoline call sites directly:
>
> | | distinct | new vs CPU-STAT | 5xx family |
> |---|---|---|---|
> | **CAT-CAT5-B06** | **31** | **3** — `312B` `317B` `321B` | `503B`×1 `504B`×1 only |
>
> **Only three new MONs, and LED already reaches two of them** (`312B`, `321B`). The one that matters
> is **`317B` UECOM** — the nested-SINTRAN-command call, which is exactly how NC re-invokes its later
> passes. **CAT-CAT5 uses NO `511B`/`512B`/`513B`/`514B`** — the XMSG family is not in its path at all.
> So NC's back end is small, and NC's real surface is its front end's 6 plus `317B`.

### ⚠️ THE CENSUS METHOD — TWO CALL ENCODINGS, AND CALIBRATION CANNOT CATCH THE SECOND

A MON call reaches the segment-31 trampoline in **two different encodings**:

```
C3    F8 00 hh ll      call  $0xFFFFFFFFF80000nn     ; the common form
B5 CF F8 00 hh ll      callg $0xF80000nn             ; used by the 5xx/XMSG family
```

`nn` is the MON number in **hex**, and it is **two bytes** — a scan requiring the third byte to be
`0x00` silently drops the entire `5xx` family (`504B` = `0x144`).

**CPU-STAT uses ONLY the `C3` form.** So a scanner that matches `C3` alone **calibrates perfectly
against CPU-STAT (28/28) and is still wrong** — it under-counted LED as 33/18 with no `513B` at all,
against the true 35/20 with `513B`×9. *A calibration sample that lacks the second encoding cannot
detect a missing encoding.* Cross-check against a disassembly that has both, never against a clean
pass on one program.

With both encodings the byte scan reproduces this file's tables **exactly** on five programs
(LED 35/20, CONVERT 43/26, NC 34/6, AUTOMAKE 13/2, CODE-COVERAGE 15/1).

**BUT IT ALSO PRODUCES FALSE POSITIVES, so it is `[D]`, not `[V]`, wherever no disassembly exists to
check it against.** On **PLANC-500-G00** it reports two MONs the disassembly does not contain
(`65B`×1, `336B`×4). All five of those hits sit in a **~250-byte cluster at file offsets
`0x4559`–`0x4653`** — the signature of a *data table of trampoline addresses*, where the byte before
the address happens to be `C3` or `B5 CF`. Real call sites are scattered through code, not packed
five-to-250-bytes.

**So the scan can BOTH miss (the encoding bug above) and OVER-REPORT (data tables). A negative from
it is not safe either.** Use it only where a disassembly is unavailable, and check hit *clustering*
before believing a result.

**`CAT-CAT5-B06`'s three hits are `[D]`, not `[V]`** — it has no disassembly to cross-check. They sit
at `0x1BF59`, `0x1BF7F` and `0x20877`, i.e. **scattered, not clustered**, so they do not carry the
false-positive signature and the `312B`-then-`321B` adjacency is what a capability probe followed by
its call looks like. Plausible, and consistent with `317B` being how NC re-invokes its passes — but
**unverified**. Disassembling `CAT-CAT5-B06.DOM` is what would settle it.

**~~TEST-REAL is the obvious next run~~ (NOT ON THE PACK — see the box above).** Zero new MON
numbers. If it fails, the defect is
opcode-level rather than MON-level, which is a cleanly separated result — and that is worth having
before touching anything else. CODE-COVERAGE then costs exactly one new MON.

**LINKER-B01 is the worst target to attack next** (30 new MONs plus the whole unimplemented inline
family), despite being the most wanted. Do it last.

---

## 3. THE HIGH-FANOUT MONs — implement these and many programs move at once

Across the corpus there are **62 distinct MON numbers**; CPU-STAT exercised **28**. Of the 34 never
exercised, these appear in the most programs:

| MON | name | programs |
|---|---|---|
| `113B` | CLOCK | **7** |
| `312B` | MOINF | **7** |
| `321B` | UEADM | **7** |
| `16B` | MGTTY | 4 |
| `162B` | OUTST | 4 |
| `256B` | DEABF | 4 |
| `263B` | GDEVT | 4 |
| `3B` | ECHOM | 4 |
| `4B` | BRKM | 4 |
| `74B` | SETBT | 4 |

`113B`, `312B` and `321B` are in **seven of ten** programs, so they are near-certain to be the first
stop of anything we run next. **CONFIRMED 2026-08-25: LED reached `143B`, `262B`, `312B` and `321B`
within minutes of the DMEMRD fix — this prediction held.**

### NAMES NOW `[V]` — confirmed against `E:\Dev\Ronny\NDInsight\Developer\MON\calls\*.yaml`

(The `[D]` caveat below is discharged for these six; the per-call YAMLs are extracted from
*Monitor Calls.md, ND-860228.2 EN*.)

| MON | file | name | short |
|---|---|---|---|
| `113B` | `113B_GetCurrentTime.yaml` | GetCurrentTime | CLOCK |
| `143B` | `143B_ExecutionInfo.yaml` | ExecutionInfo | |
| `262B` | `262B_GetSystemInfo.yaml` | GetSystemInfo | |
| `312B` | `312B_CheckMonCall.yaml` | CheckMonCall | MOINF |
| `317B` | `317B_ExecuteCommand.yaml` | ExecuteCommand | UECOM |
| `321B` | `321B_UEAdministrator.yaml` | UEAdministrator | UEADM |

### `312B` IS A CAPABILITY PROBE — this reframes the whole gap list `[V]`

> *"Some monitor calls are optional or only available in later versions of SINTRAN III. This monitor
> call checks if a monitor call exists in your particular SINTRAN III system."*
> Parameters: `MonCallNumber` (in), `MonCallEntry` (out) — **"0 means not implemented"**.

**Programs ASK before they call.** That is why `312B` is in seven of ten. Consequences:

- A wrong answer here mis-steers a program long before it reaches the MON it was asking about.
  Answer `0` for something real and it silently takes a fallback path; answer non-zero for something
  our forwarding does not carry and it walks into the gap.
- **`312B`'s answer must agree with what we actually forward.** It is the one MON whose correctness
  is about the *whole set*, not about itself.

### `321B` HAS NO VERIFIED CONTRACT `[OPEN]`

Its YAML is an explicit **STUB**: *"handler body NOT located in the available NPL source tree … no
parameter block, return values, or caller convention can be confirmed"*, and it is listed in manual
**section 2.16, "numbers no longer supported"**. It is nonetheless in seven of ten programs. Since we
FORWARD to real SINTRAN, absence from our source tree says nothing about whether the running L07
answers it — but if it returns an error, callers must cope. Do not synthesise an answer for this one.

Everything else in the table above is a *name from the disassembler's own annotation* — the numbers
are `[V]` from the trampoline targets, the remaining **names are `[D]`**.

**`317B` UECOM** appears in NC-A06 only, and it is not optional there: the `nd500-apps` skill records
that NC re-invokes its own later passes as nested SINTRAN commands through MON 317B. **No 317B, no
compile** — that one MON gates the whole C toolchain.

---

## 4. WHAT THIS FILE DOES NOT SAY

- **Whether any of these MONs is actually unimplemented.** Real SINTRAN answers them; the question
  is whether our forwarding path carries each one. That is a separate check against the servicer and
  the MON oracle verdict list, not something a disassembly can show.
- **Whether a listed site is ever reached at run time.** This is a STATIC count. A program may carry
  a MON in a branch it never takes.
- **The names.** They are the disassembler's annotation, graded `[D]`.
