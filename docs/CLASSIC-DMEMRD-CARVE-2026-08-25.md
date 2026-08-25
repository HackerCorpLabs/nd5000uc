# Classic DMEMRD (MICFU 0o10) — carve before implementation

**Date:** 2026-08-25
**Why:** `Nd500MicrocodeServicer.cs` ~1362 sets `understood = false` for classic `DMEMRD`, which
answers `5ERANSWER(4)` (~2133). That is the root cause of the LED MON 50B stall — LED's `OPEN` is
outside the inline-copy set `{504B, 511B, 512B}` (classic `010661 F,POPRET`), so its filename must
arrive by data-memory read.

**Store:** classic `CONT-STORE-10611` (8192 × 18-byte words). Its `SYMBOLS.TXT` is **empty** — nothing
is findable by name. Addresses are OCTAL. **Never carry a B30 address onto this lane.**

---

## 1. CORRECTION — the cited "twins" are the wrong pair `[V]`

The implementation was described as "the READ mirror of the PHYSWR path, with `011433B`/`011453B` as
the twins". That is a misreading of the servicer's own comment at `Nd500MicrocodeServicer.cs:1171`,
which says:

> Microcode `011433B` (PHYSRD) / `011453B` (PHYSWR) are twins

**`011433B` and `011453B` are PHYSRD (0o30) and PHYSWR (0o31) — twins of EACH OTHER.** Neither is
DMEMRD. Verified by reading both: they are word-for-word identical for 12 of their first 13 words.

**PHYSRD is already implemented** (the `understood = true` arm just above the failing `else`). So
"implement DMEMRD as the read mirror of PHYSWR" would re-implement PHYSRD under a different MICFU.

## 2. WHY THAT MATTERS — DMEMRD AND PHYSRD ARE DIFFERENT ADDRESS GEOMETRIES `[V]`

| MICFU | name | address model |
|---|---|---|
| `0o10` = 8 | `DMEMRD` | **data memory** — logical/segment-relative |
| `0o30` = 24 | `PHYSRD` | **physical segment** — PST-walked |

The servicer groups them in one `case` and then branches internally; only the PHYSRD branch is built.
Copying PHYSRD's PST walk into DMEMRD would give the wrong address model. **This is a category
difference, not a mirror.**

## 3. THE PHYSRD CONTRACT, word by word `[V]` — the template, not the answer

```
011433  JSR 007543                                        entry
011434  ADIR A,AM#20 D,AM#23      JSR 007604
011435  B,AM#23 D,AM#32           JSR 007543  W,EXT SINGLE XRES EX,SHL
011436  ADIR A,AM#20 D,AM#22      JSR 007544
011437  B,AM#20 D,AM#21 TYP,HW    JSR 007544  W,EXT SINGLE XRES EX,SHL
011440  A+A  A,AM#20 D,AL#20 TYP,HW  JSR 007771            <- the PST walk
011441  ADIR A,AM#21 D,LC   TYP,HW   JSR 012026            <- LC := byte count
011442  ADIR A,AM#22 D,AL#20  SET COND,LCZ  JSR 007540
011443  AND  A,SARG=000377 B,AM#23 D,AM#31                 <- byte mask 0377
011444  A+B  A,AM#31 B,AM#35 D,AM#31
011445  A-B-1 CRY,ONE A,AM#31 B,BM#2 D,DP                  <- ** the ONLY differing word **
011446  PASSAA AA,DP1 AB,IX
011447  MEM,RD4 W,MEM  AA+AB AA,EA1 AB,DPARG               <- the read
011450  ADIR A,DATA D,AM#20  JSR 007546  LCDECR            <- store + decrement
011451  C,SEQ T,NEXT F,JMP 011447                          <- loop while LC != 0
011452  JMP 010537                                          <- common tail
```

PHYSWR (`011453`-`011467`) is identical except `011465` uses `B,BM#1` where `011445` uses `B,BM#2`.
**One word selects direction.**

Helpers: `007771` = PST walk · `012026` = load LC from `AM#21` · `007540`/`007543`/`007544`/`007546`
= shared parameter/store helpers.

## 4. WHAT IS STILL `[OPEN]` — the DMEMRD handler address

**Not located.** Two methods tried and both refuted, recorded so they are not repeated:

- **Uniform handler spacing.** PHYSRD/PHYSWR sit `0o20` apart for a MICFU difference of 1, predicting
  DMEMRD (`0o10`) at `011433 - 16×16 = 011033`. **REFUTED** — `011033` is
  `ANDCB A,XD,S1 B,AL#20 D,XST1`, trap/status code, not a copy handler.
- **Shared entry helper.** The handlers open with `JSR 007543`, but that helper has **30+ callers**
  across the store and is not a copy-family marker.

**What is needed next: the MICFU dispatch table.** On the B30 this is `MSG_LINK9`'s `JMPREL` into a
64-entry table based at `MSG_00`. The classic equivalent has not been found. Until it is, the DMEMRD
entry point is a guess, and a guessed entry decodes plausibly and wrongly — the documented failure
mode on this store.

## 5. RESOLVED — and by a better source than the dispatch table

DMEMRD was implemented via the **logical data path** (`ProcessHost.TryReadDataBytes`), explicitly not
the PST walk, sourced from the **SINTRAN-side field contract** rather than from microcode adjacency.
Measured: `MICFU=0x0008` on the domain message went 132,042 → **zero**, monlog 12 MB → 69 KB, and LED
reached MON calls it had never issued before (143B, 262B, 312B, 321B).

**The method lesson: to SERVICE a request you need the field contract — what SINTRAN puts in the
message — not the entry address of the microcode routine that would have serviced it.** The dispatch
table is worth having, but it was never the blocker. Sections 1–4 above stand as a correction record
and as the shape of a classic copy handler.

## 6. THE FIELD CONTRACT FOR THE COPY FAMILY `[V]` — carved from the SINTRAN side

Clearest statement is `RP-P2-N500.NPL:130470-130506`, written in field notation:

```
130470   AD:=X.ABUFADR
130474   AD=:X.N100ADR      % 5MPM BYTE ADDR OF DATA BUFFER      -> N100A  0o11-0o12 (DOUBLE)
130475   AD:=X.ISTRA=:X.N500ADR  % ND-500 LOGICAL address        -> N500A  0o7-0o10 (DOUBLE)
130477   X.5FYLLE=:X.NRBYT  % NUMBER OF BYTES                    -> NRBYT  0o13
130501   0=:X.5DITNO        % DEFAULT DIT #0                     -> 5DITN  0o14
130502   "INSMONCO"=:X.SPFLA                                     -> SPFLA  0o143
130504   3WMED=:X.MICFUNC   % WRITE DATA BUFFER TO ND-500        -> MICFU  0o6
130506   MSGN500; CALL WN5STATUS                                 -> N5STA  0o2
```

Confirmed by the other two `3WMED` sites (`137166-137210`, `143065-143105`) and mirrored by the
`3RMED` sites (`136406-136422`, `140661-140664`, `142304-142332`), which set the same fields.

| field | offset | meaning |
|---|---|---|
| `N500A` | `0o7`–`0o10` double | ND-500 **LOGICAL** address (source for read, destination for write) |
| `N100A` | `0o11`–`0o12` double | ND-100 5MPM **BYTE** address of the com-buffer |
| `NRBYT` | `0o13` | byte count |
| **`5DITN`** | **`0o14`** | **DIT (domain) number — which context resolves the logical address** |
| `SPFLA` | `0o143` | continuation address |

Related: `OSTRA = 0o44` / `ISTRA = 0o46` are the out/in string-address parameter slots the logical
address is copied FROM; `ABUFA = 0o140`, `LBUFA = 0o141` the com-buffer.

### 6a. `N100A` IS A **WORD** ADDRESS — the NPL comment saying "BYTE" is wrong `[V]`

`RP-P2-N500.NPL:130474` reads `AD=:X.N100ADR  % 5MPM BYTE ADDR OF DATA BUFFER`. **It is a WORD
address.** `ResolvePhysicalCopyAddress` doubles it on classic (`addr << 1`) and that shift is
load-bearing. Two independent proofs:

- the live CNVWADR value `0x00212800` × 2 = byte `0x00425000`, **inside** the MPM window; read as a
  byte address, `0x212800` is *below* the window base `0x420000` — impossible, not merely wrong;
- the same shift is what makes the working DMEMRD implementation work (measured).

**Do not "correct" the shift to match the comment.**

### 6b. `MSWMC` and `5DITN` are the SAME SLOT (`0o14`) `[V]`

Sixth union in this message. On a `PHYSWR` that slot is the **physical segment**; on
`DMEMRD`/`DMEMWR` it is the **DIT number**. Reading the DIT from a field named `MSWMC` is correct,
not a typo.

**`5DITN` IS THE FIELD TO WATCH.** Both DMEMWR sites explicitly zero it with the comment
*"DEFAULT DIT #0"*, which means it is a real selector and not always 0. DIT == PCB
(256 B/domain) — so the logical address must be resolved **in the domain named by `5DITN`**, not
unconditionally in the currently-running process. An implementation that ignores it is correct only
while every request names domain 0.

## 7. `IMEMWR`/`IMEMRD` (`0o35`/`0o34`) MAY BE UNREACHABLE ON THIS LANE `[D]`

`3WMEP` and `3RMEP` appear **exactly twice in the whole NPL**, both inside `DECOERRMESS`'s
legal-MICFU list at `135245-135257`. **No site posts either.** By contrast `3WMED` has four posting
sites and `3RMED` three. So the unmodelled `IMEMWR` arm is probably not reachable from SINTRAN here,
and is NOT the mirror-of-tonight's-bug waiting to happen — `DMEMWR (0o11)` is.

Graded `[D]`: this is a negative over the NPL files we hold (`MP-P2`, `RP-P2`, `CC-P2`, `XC-P2`,
`5P-P2-MON60`, `MP-P2-PERF-SAMP`, `MP-P2-TERM-DRIV`). A poster in a file we do not have would not
appear. Also note the catalog contradicts itself on these values — lines 70/191 call `3RMED`/`3WMEP`
*"numeric value unresolved"* while 596-597 resolve them from L07 SYMBOL as `3RMED=10, 3WMED=11,
3RMEP=34, 3WMEP=35`. The SYMBOL values are the ones that match the NPL usage.
