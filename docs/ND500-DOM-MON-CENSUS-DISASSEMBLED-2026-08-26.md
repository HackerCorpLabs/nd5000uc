# ND-500 DOM MON census — settled by disassembly, cross-checked by raw scan

**2026-08-26.** Grades: `[V]` verified by executing/decoding real bytes, `[D]` derived, `[X]` refuted.

This replaces the byte-scan censuses in
`E:\Dev\Ronny\ND5000UC\docs\ND500-DOM-MON-COVERAGE-CARVE-2026-08-25.md`.
Three programs are now `[V]` by **two independent instruments that agree address-for-address**.
It also **retracts** one published claim of mine (§5) and **corrects** the LED number I have been
quoting all week (§2).

---

## 1. The numbers

| program | call sites | direct MONs | callg sites | indirect reach | grade |
|---|---|---|---|---|---|
| `LED-FORTRAN-A01` | **56** | **35** | 10 | +`251B` → 36 reachable | `[V]` raw = disasm = archived |
| `CAT-CAT5-B06` | **45** | **31** | **0** | none | `[V]` raw = disasm |
| `CONVERT-DOM-A03` | **69** | **43** | 19 | +`251B` → 44 reachable | `[V]` raw = archived |

A **MON call is not an opcode.** It is a CALL/CALLG into the segment-31 trampoline table, so the
MON number is just the low halfword of the target `0xF80000nn`. Two encodings:

```
C3 F8 00 hh ll         plain call    operand prints as  $0xF80000nn
B5 CF F8 00 hh ll      callg         operand prints as  #0xF80000nn
```

### CAT-CAT5-B06 — 45 sites, 31 distinct, ZERO callg

```
 6 32B     2 64B    1 76B   1 54B   1 504B  1 41B    1 321B  1 30B   1 221B  1 122B
 3 142B    2 422B   1 73B   1 50B   1 503B  1 413B   1 317B  1 2B    1 1B    1 120B
 3 0B      2 143B   1 62B           1 43B   1 412B   1 312B  1 262B  1 123B  1 117B
           2 11B
           2 114B
```

**No `513B`.** No `65B`. No `336B`. The three my byte scan reported for this program were wrong.
It is also the only one of the three with **no callg form at all** — worth knowing, because the
callg family is where the XMSG-shaped `5xx` calls live.

### CONVERT-DOM-A03 — 69 sites, 43 distinct

```
14 513B    3 504B   2 50B    2 0B    1 76B  1 71B   1 511B  1 43B   1 336B  1 320B  1 263B  1 17B  1 120B
 4 2B      2 514B   2 262B           1 74B  1 62B   1 505B  1 412B  1 334B  1 312B  1 257B  1 16B  1 11B
 4 143B             2 144B           1 73B  1 512B  1 503B  1 3B    1 321B  1 30B   1 256B  1 162B 1 117B
                                     1 72B          1 4B                            1 254B  1 13B  1 113B
                                                                                            1 1B   1 104B
```

**`513B` × 14 makes CONVERT-DOM the heaviest user of the callg family we have** — half again LED's
nine. If the classic DMEMRD/DMEMWR work holds up under LED, CONVERT is the program that will
stress it.

### LED-FORTRAN-A01 — 56 sites, 35 distinct (+1 indirect)

```
 9 513B    3 2B     2 504B   2 144B   1 76B  1 62B   1 512B  1 505B  1 401B  1 312B  1 263B  1 162B  1 113B
 4 0B      3 143B   2 4B     2 13B    1 74B  1 514B  1 511B  1 503B  1 3B    1 30B   1 17B   1 120B  1 104B
                    2 262B            1 73B  1 50B           1 43B   1 321B          1 16B   1 117B
                    2 1B               1 72B
```

Nine `513B` `[V]` — the count I have been quoting is right, at
`0804126D 08041297 080412C1 080412EC 0804131C 0804137E 080413C1 080413EC 0804143F`,
plus one `512B` at `08041350` in the same block.

---

## 2. LED = 35 direct — and the new instrument briefly regressed it to 33 again

`ND500-DOM-MON-COVERAGE-CARVE-2026-08-25.md` already had LED right at **35**. This census
independently confirms it: **35 direct / 36 reachable**, `513B`×9.

What is worth recording is what happened on the way there. The first run of the new
disassembly-based census reported **33** — the exact wrong number the old byte scanner produced,
reached by a completely different mechanism:

nd500x prints an **immediate** operand with `#` and a plain address with `$`. My census regex matched
only `$0xF800…`. That silently dropped **every callg site** — all ten of them, including all nine
`513B` calls — while still producing a believable 33-distinct answer. The two distinct MONs lost
were `512B` and a second `503B`.

**Same blind spot as the byte scanner that knew only the `C3` form, hit a second time, in a new
disguise, by a different instrument, in a session that had the first failure written down in front
of it.** Both times the instrument passed its calibration exactly, because the calibration sample
did not contain the hard case — failure mode #5 in `feedback-friction-lessons-nd5000.md` §0.

Knowing about the trap did not prevent it. What caught it was **running a second, unrelated
instrument over the same bytes and diffing the addresses** (§3). That is the control that works;
being careful is not.

---

## 3. The method: two instruments, diffed by address

Neither instrument is trustworthy alone.

**Instrument A — linear disassembly.** `nd500x --dom … --disasm … --addr … --radix hex`.
Chunked, because `--disasm` writes into a fixed 16 KB stack buffer
(`src/frontend/nd500x/nd500x.c:910`, `char outbuf[16384]`), so **one call emits about 1 KB and then
silently truncates.** The first run on CAT-CAT5 returned 355 lines for a 128 KB segment and looked
like a finished disassembly. Driver:
`C:\Users\ronny\.claude\jobs\2c5cb8c6\tmp\dis-dom.sh` — each chunk restarts at the address of the
previous chunk's **last** line and drops that line, so no instruction is ever split.

Its weakness: **a linear disassembly desyncs on embedded data and then swallows real call sites.**
Measured `???` decode failures: LED 412, CONVERT 255, CAT-CAT5 124.

**Instrument B — raw byte scan of the PROG segment.** `rawscan.sh`, reading the `.DOM` file
directly at the PROG file offset that nd500x's own load line reports, e.g.

```
DOM Load: Seg[1] PROG: file=0x00004000..0x00045475 size=267382 load_addr=0x00000000
```

**The PROG file offset differs per program** (`0x1800` for CAT-CAT5, `0x4000` for LED and PLANC,
`0x1000` for CONVERT) — read it, never assume it. Using CAT-CAT5's `0x1800` on LED produced 11 hits,
none of them real, and the cross-check caught it in one line.

Its weakness: it cannot tell code from data, so it must be restricted to the PROG segment and its
hits still need confirming.

**The check that makes the pair worth more than either half — diff the ADDRESS SETS, not the counts.**

```
##### CAT-CAT5 #####    raw hits: 45   disassembled call sites: 45   (no address differs)
##### LED #####         raw hits: 56   disassembled call sites: 56   (no address differs)
##### CONVERT-DOM #####  raw hits: 69   disassembled call sites: 68
  RAW only: 08024CD7      <- a real MON 143B the disassembly desynced past
```

That last line is the whole point. Two counts that differ by one tell you nothing about *which*
one; two address sets hand you the exact instruction to go and look at. At `08024CD7` the
disassembly had gone one byte out at `08024CD5: 00 ???` and read the call's `C3` as an operand:

```
mine      08024CD6: 48 C3 F8 00 00 63    by stz  b.0xF8000063        <- desynced
archived  08024CD7: C3 F8 00 00 63 04 …  call    $0xF8000063,$0x4,…  ; MON 143B RSIO
```

---

## 4. Indirect MON reach — `251B` is invisible to every call-site scan

**Both LED and CONVERT-DOM store a trampoline ADDRESS into a variable and call through it later:**

```
LED       0803F75B: 1A CF F8 00 00 A9 6C   w move  #0xF80000A9,b.0xB0     <- MON 251B
          0803F77E: 1A CF F8 00 01 43 6C   w move  #0xF8000143,b.0xB0     <- MON 503B
CONVERT   08025B44: 1A CF F8 00 00 A9 6C   w move  #0xF80000A9,b.0xB0     <- MON 251B
          08025B67: 1A CF F8 00 01 43 6C   w move  #0xF8000143,b.0xB0     <- MON 503B
```

Same two MONs, same destination slot `b.0xB0`, same shape in both programs — a shared runtime
routine that picks between `MON 251B` and `MON 503B` at run time and calls indirectly.

`251B` = **CopyPage** (`E:\Dev\Ronny\NDInsight\Developer\MON\calls\251B_CopyPage.yaml`).
`503B` = DVINST, `0x143`.

**`251B` appears at no call site in either program**, so every census we have ever done missed it —
mine and the archived annotated disassemblies alike, because those annotate only CALL instructions.
It can still turn up in a live monlog. **When it does, it is not a surprise and not a defect.**

Excluded from all counts above: a bare `0xF8000000` in arithmetic (`w1 + #0xF8000000`,
`w2 and #0xF8000000`) is segment-31 **base** arithmetic — building or masking a trampoline address —
**not** a call to MON 0B. Counting it inflates `0B` by one in every program.

---

## 5. `[X]` RETRACTION — the PLANC "address table false positives" were REAL CODE

On 2026-08-25 I downgraded the `CAT-CAT5` census to `[D]` and told the peer not to plan against it,
on the strength of this reasoning: my byte scan reported `65B` and `336B`×4 for `PLANC-500-G00`, the
archived disassembly showed none of them, and all five hits clustered inside ~250 bytes — so I called
it a data table of trampoline addresses and invoked the "check hit clustering" rule.

(The downgrade was also unnecessary on its own terms: **CAT-CAT5's byte-scan census was correct** —
31 distinct, no `5xx` XMSG family — and §1 above now confirms it address-for-address. The `[D]` was
applied to a right answer because of a wrong story about a different program.)

**That was wrong, and it was wrong in the direction that discards a true measurement.** The bytes:

```
08000555: FC 5F 47 04                    w mul2  b.0x1C,$0x4
08000559: C3 F8 00 00 DE 04 46 47 49 48  call    $0xF80000DE,$0x4,b.0x18,b.0x1C,b.0x24,b.0x20
08000563: D1 00 EE                       ifkgo   $0xEE
08000566: 1A 0A 46                       w move  $0xA,b.0x18
```

`0xDE` = `336B`, four arguments, followed by the standard `ifkgo` error check, surrounded by
well-formed instructions on both sides. **These are genuine MON call sites.**

The archived disassembly does not show them because **it starts at the entry point**, and PLANC's
header says `Entry Point: 0x0800065C`. Everything below that address — including these five calls —
was never disassembled. LED's entry point is `0x08000004`, which is why LED's archived listing is
complete and PLANC's is not.

**Consequences, all of which matter more than the retracted claim:**

1. **The archived `analysis\*.asm` files are not authoritative for coverage questions.** They are
   entry-point-down listings. For any program whose entry point is not `0x08000004`, code below it
   is simply absent. Check the `Entry Point:` line in the header before trusting one.
2. **The clustering rule is not a verdict.** Five hits in 250 bytes is a reason to go and decode
   those 250 bytes. It is not evidence that they are data. Here the cluster was just a tight run of
   initialisation calls.
3. I explained a disagreement between two instruments by inventing a story about one of them,
   instead of decoding the disputed bytes — which took under a minute once I did it. That is
   RULE #0b: *a search that finds nothing is evidence about the pattern.* The archived listing
   "finding nothing" at `0x08000559` was evidence about where it started reading.

`PLANC-500-G00` PROG-segment raw scan: **41 call sites** (whole-file scan gives 42; the extra one is
in the DATA segment and is unconfirmed — restrict to PROG). PLANC is **not** re-censused here beyond
this; it needs a full-segment disassembly like the other three before it gets a `[V]`.

---

## 6. Tools

Kept in the repo at `E:\Dev\Ronny\ND5000UC\tools\mon-census\`. They are POSIX shell and run under
WSL, so strip the CRs on the way in:

```
wsl bash -lc "tr -d '\r' < /mnt/e/Dev/Ronny/ND5000UC/tools/mon-census/dis-dom.sh > /tmp/dis-dom.sh"
```

| script | does |
|---|---|
| `dis-dom.sh <DOM> <proglen> <out>` | chunked full-PROG disassembly around the 16 KB buffer |
| `rawscan.sh <DOM> <progoff> <proglen>` | raw byte scan of the PROG segment for both call encodings |
| `crosscheck.sh <raw> <asm>` | diffs the two address sets and names every disagreement |
| `mon-census2.sh <asm>` | per-MON counts, split into direct call sites vs indirect reach |

Outputs live in the WSL `/tmp` of `nd500x`: `cat-cat5-b06.asm`, `led.asm`, `convert-dom.asm`,
and the `*-raw.txt` scans.

To census a new program:

```
# 1. read the PROG file offset and size from nd500x's own load line - never assume them
wsl bash -lc 'cd ~/repos/nd500x && ./build/bin/nd500x --dom <PATH>.DOM --disasm 8 --addr 0x08000004 2>&1 | head -2'
# 2. both instruments
wsl bash -lc 'bash /tmp/dis-dom.sh <PATH>.DOM <proglen> /tmp/x.asm'
wsl bash -lc 'bash /tmp/rawscan.sh <PATH>.DOM <progoff> <proglen> > /tmp/x-raw.txt'
# 3. the check that matters
wsl bash -lc 'bash /tmp/crosscheck.sh /tmp/x-raw.txt /tmp/x.asm'
```

**Do not report a census whose cross-check you have not run.** Both times a MON count of mine was
wrong this week, the count itself looked completely reasonable.
