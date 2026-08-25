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

`[OPEN]`: whether 513B belongs to the inline-copy family. The microcode set carved so far is
`{504B, 511B, 512B}` (`CALL_5XX 004013B → CALL_5_MATCH 013667B`). **513B was not in it.** Do not
assume it behaves like its neighbours because its number is adjacent — that is exactly the
adjacency-is-not-dispatch error. Carve `CALL_5_MATCH` before implementing anything for it.

---

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

**TEST-REAL is the obvious next run: zero new MON numbers.** If it fails, the defect is
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
stop of anything we run next. Everything above is a *name from the disassembler's own annotation* —
the numbers are `[V]` from the trampoline targets, the **names are `[D]`** and should be confirmed
against `SINTRAN-Commands.md` / the MON oracle list before being relied on.

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
