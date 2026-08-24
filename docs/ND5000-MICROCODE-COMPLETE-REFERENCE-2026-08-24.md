# ND-5000 microcode — the complete reference

**Full path:** `E:\Dev\Ronny\ND5000UC\docs\ND5000-MICROCODE-COMPLETE-REFERENCE-2026-08-24.md`
**Subject:** `MICRO-5800-B30` — the ND-5800 microprogram, 16384 words × 128 bits, the only ND-5000
microcode this project has, and the one `CpuND5000` actually executes.
**Written:** 2026-08-24.

---

## How to read this

Every claim carries a grade. The grade says **how we know**, not how sure we feel.

| Grade | Means |
|---|---|
| **[V]** | Verified. Read straight out of the raw `MICRO-5800-B30.DATA` bytes, or measured by executing the microcode on `CpuND5000`, or both. A number in this document with a [V] on it was counted by a script over the image, not remembered. |
| **[M]** | From an official Norsk Data document — a manual, or an ND program-description sheet. Quoted, with the section. |
| **[D]** | Derived. Reconstructed, inferred from naming, or worked out from something else that is [V] or [M]. Plausible, unproven. |
| **[OPEN]** | We do not know. Written down so nobody has to rediscover the hole. |

Three rules this document keeps:

1. **Microcode addresses are OCTAL.** Written `0o12345` or with a leading `0`. `0o25522` is `0x2B52`,
   not `0xB52`. Getting the radix wrong dumps a different routine that still looks plausible — it has
   cost this project days.
2. **Field values come from the raw `.DATA`, never from `MICRO-5800-B30.md`.** The rendered listing
   mis-splits the overlapping MARG / SCAL / ORCON bits and prints wrong `ORCON=` / `IX*n` tokens. Its
   ALU, A/B operand, destination, next-address and memory-op columns are fine. Its argument and
   scaling columns are not.
3. **Where a manual and this project disagree, both sides are shown**, with citations, and marked for
   Ronny to settle. Nothing is silently picked.

A section that is mostly [D] says so in its first line.

---

## Table of contents

1. [Executive summary — what we know vs what we are reconstructing](#1-executive-summary)
2. [The artefact itself](#2-the-artefact-itself)
3. [The 128-bit microword](#3-the-128-bit-microword)
4. [Map of the control store, 0o0 – 0o37777](#4-map-of-the-control-store)
5. [**Opcodes → microcode: the dispatch**](#5-opcodes--microcode-the-dispatch)
6. [The sequencer, EXUC and the pipeline](#6-the-sequencer-exuc-and-the-pipeline)
7. [The register model](#7-the-register-model)
8. [ALU, conditions and status](#8-alu-conditions-and-status)
9. [Address arithmetic: ADACT, MARG, ORCON — and the conflict](#9-address-arithmetic)
10. [Memory, MMS and traps](#10-memory-mms-and-traps)
11. [The mailbox / octobus / ACCP spine](#11-the-mailbox--octobus--accp-spine)
12. [Monitor calls, STOP and checkpoints](#12-monitor-calls-stop-and-checkpoints)
13. [Float, the AAP, transcendentals and the vector library](#13-float-the-aap-transcendentals-and-the-vector-library)
14. [What we cannot run yet — the gaps, counted](#14-what-we-cannot-run-yet)
15. [The manuals: what they contain, what they contradict, what is lost](#15-the-manuals)
16. [**Unknowns — what we would ask the designers**](#16-unknowns)
17. [Appendix A — per-opcode dispatch table, single-byte](#appendix-a--single-byte-opcodes)
18. [Appendix B — per-opcode dispatch table, two-byte](#appendix-b--two-byte-opcodes)
19. [Appendix C — sources](#appendix-c--sources)

---

## 1. Executive summary

### What we genuinely have

- **The real microcode.** `MICRO-5800-B30.DATA`, 262144 bytes = 16384 words of 16 bytes, word *N* at
  file offset *N*×16. [V]
- **Its own symbol table.** `MICRO-5800-B30.LABE`, the assembler's cross-reference listing: 3457
  labels at 3356 distinct addresses, plus 5548 reference sites. [V]
- **An engine that runs it.** `CpuND5000` executes one real microword per `Tick()`. It boots the real
  image from address 0 to IDLE, answers real octobus mailbox messages, and runs real macro programs.
  Where it and a manual disagree, the microcode is the authority. [V]
- **Two official manuals**, the ND-5000 Hardware Description (ND-05.020.01) and the ND-5000
  Microprogram Guide (ND-05.022.1), plus the **ND program-description sheets** shipped with the
  microprogram floppies (`5800-30.TEXT`, `5800-29.TEXT`, `5800-27.TEXT`). [M]

### What we know solidly

| Thing | State |
|---|---|
| Microword field layout, all 128 bits | [M] from ND-05.022.1 ch.2, [V] by lossless round-trip over both A30 and B30 (32768 words re-encode byte-exact) |
| Which words are code and which are filler | [V] — 13333 live words, 3051 filler, zero ambiguity |
| The functional map of the whole address space | [V] for region boundaries from the label table; [D] for a few region *names* |
| The sequencer, the 4-deep stack, RETURN-does-not-pop | [M] ND-05.022.1 §7.1/§7.2/§7.3.1, [V] in execution |
| The one-word condition delay | [V] — calibrated on `ACCP_READ` @0o16372/73 |
| The mailbox / octobus message spine | [V] — 64 MICFU slots decoded from the raw dispatch table, most executed |
| STOP words | [V] — exactly 10 in the whole image, all located |
| The version identity of the image | [V] — 11930 (= `0x2E9A`) in the raw word at 0o1, matching the `.LABE` header "version 11930 (WM-500)" and the ND sheet's "B version … work mode 500" |

### What we are reconstructing — and this is the honest part

**The opcode→microcode map is a reconstruction. There is nothing to dump.** The IMAP and OMAP are
not PROM chips: the part lists for both IDA cards (324708 and 324718) contain no PROM device at all,
only a PAL bank and three custom LSIs. The maps live in the PALs and/or inside the ND-S-IDU LSI. So
`DispatchMapB30.g.cs` — 1183 rows — is a rebuild, not a read.

Its rows break down like this [V, counted over the generated file today]:

| How the row is known | Rows | Grade |
|---|---:|---|
| Printed opcode↔entry pair in ND-05.022.1 chapter 12, confirmed by a matching `RES*` label in the `.LABE` at exactly that address | **130** | [M] + [V] |
| Entry taken from a `.LABE` label whose name matches mnemonic+datatype directly | **631** | [D], strong |
| Entry derived from naming convention plus inspection of the entry microword | **328** | [D] |
| Three-source verified 2026-08-23 (nd500x opcode table ⊕ `.LABE` ⊕ entry-word check ⊕ sweep) | **45** | [D], validated by measurement |
| Bound against the functional decoder plus a named microcode entry | **16** | [D] |
| Layout-derived duplicates | **4** | [D] |
| Long narrated one-off justifications | **24** | [D], individually argued |

**No row is marked as a guess, because guesses were left out rather than invented.** A missing opcode
throws; a wrong opcode would silently poison the oracle. That policy is why there are holes:

- **21 single-byte opcodes** in `0x00`–`0xFB` are unmapped. [V]
- **76 two-byte opcodes** across pages `0xFC`–`0xFF` are unmapped. [V]
- **28 instruction entry points exist in the microcode with no opcode pointing at them** — real
  routines with real names (`IMODW`, `COMPF`, `BCDC`, `INCRF`, `SSMOV`, …) that nothing in our map
  can reach. [V] This is the sharpest single measure of what the reconstruction is missing.

Beyond dispatch, the other big reconstructions are: the MMS page-walk (validated against the nd500x C
emulator, not against B30 microcode), the AAP float model (native ND format, several operations
modelled as no-ops), and `EXCYC2` (implemented, then deliberately suppressed for loop bodies because
the manual's rule doubles the integer quotient — see §6).

### The one-line version

We have the microcode and we can run it. We do **not** have the small piece of hardware that decides
*where in it to start*, and we have rebuilt that piece from the microcode's own symbol table plus one
chapter of one manual. Roughly 11% of the microcode's named instruction entries have no opcode we can
prove reaches them.

---

## 2. The artefact itself

### 2.1 Files

| File | What | Path |
|---|---|---|
| `MICRO-5800-B30.DATA` | The control-store image. 262144 bytes, 16384 × 16. **Authoritative.** | `E:\Dev\Ronny\ND5000UC\docs\MC\` |
| `MICRO-5800-B30.LABE` | Assembler cross-reference: label, definition address, every reference site. Octal, CR-terminated lines. | same |
| `MICRO-5800-B30.md` | Rendered disassembly. Useful for reading flow. **Do not trust its ORCON / MARG / IX\*n columns.** | `E:\Dev\Ronny\ND5000UC\microcode\` |
| `5800-30.TEXT` | The ND **program description sheet** for this release. Primary source. | `E:\Dev\Ronny\ND5000UC\docs\MC\` |
| `MICRO-5800-A30.DATA` / `.LABE` | The sibling image. | same |

Word layout: 16 bytes, big-endian, bits 127..64 in bytes 0-7 and bits 63..0 in bytes 8-15. [V]

### 2.2 Which image is this, exactly

The word at `0o1` (`VERSION`) carries `LARG = 0o27232` = 11930 decimal = `0x2E9A`. The `.LABE` header
reads *"ND-5800 microprogram cross reference table version 11930 (WM-500)"*. [V]

The ND program-description sheet for release `211276D` says [M]:

> The A version of the microprogram is to be used on a ND-5800 system with SINTRAN III VSX K and work
> mode 406 (single CPU configurations). … The B version of the microprogram is to be used on a
> ND-5800 with SINTRAN III VSX K and work mode 500 (single CPU configurations).

So **A30 and B30 are the same release built for two different SINTRAN work modes**, not two different
CPUs. Version numbers follow the same pattern across releases: A29 = 11429, A30 = 11430, B29 = 11929,
B30 = 11930. [V] A30 and B30 differ in **11315 of 16384 words** (69%). [V]

Other facts straight off the sheets [M]:

- Product `211276D`, source `250291D`, category SPEC. Purpose: *"Implement the ND-5000 instruction set
  including ax-extension."*
- Prerequisites: ND-5800, CPU type CX, 32- and 64-bit floating format, SINTRAN III VSX K WM406 or
  newer. ECO level 5000-36.
- Loaded with `LOAD-CONTROL-STORE CONTROL-STORE:DATA,0,40000` — **0 to 0o40000, the whole 16384
  words**. Only needed when the microprogram changes; later restarts reload it automatically.
- Shipped alongside `ND-5000-AF-LIB-B` (SAX, single-precision array), `ND-5000-AD-LIB-A` (DAX,
  double-precision array) and `ND-500-RTC-LIB-A` (real-time clock).
- B30's own change list: corrected accuracy for `cos(±δ)` and `sin(±δ+π/2)`; **added ALT-prefix
  handling in all string instructions and in `BMOVE` — "note that hardware modifications must be done
  also to utilize this"**; error correction for `Lregbl <mask>,<address>` (CED and PS register cases);
  changes in `Nksend` / `Nkmove`; `INIT-5000` now resets the clock counter.

That ALT note is worth holding on to: it explains why the ALT path exists in the microcode (118 words
carry an ALTEN ORCON, §14) and why nothing exercises it.

The earlier `211276C` sheet adds real opcode numbers, which independently confirm seven rows of our
dispatch map — see §5.5. It also lists the ND-100-visible error codes the nucleus path returns
(`101003` illegal message type, `101004` no message, `101006` illegal descriptor number, `101014`
index outside user data or message, `101023` no access to the message, `101025` illegal function in
`nkmove`/`nkreceive`, `101033` kicklock timeout, `101042` lock timeout). [M]

### 2.3 The dispatch map artefacts

| File | What |
|---|---|
| `docs\dispatch-map-b30.json` | 1183 hand-curated records. Fields: `opcode`, `octal`, `mnemonic`, `entry` (**decimal** of the octal CS address), `entryOctal`, `label`, `evidence` (free text), optionally `dataType`, `rin`, `directMask`, `directSizes`. |
| `src\Generated\DispatchMapB30.g.cs` | The generated C# map. 1183 `map[opcode] = new DispatchEntry(...)` lines, each with a trailing `// <mnemonic> [<evidence>]` comment. |
| `src\Generated\MicroFields.g.cs` | Bit positions of every microword field. |
| `src\Generated\MicroMnemonics.g.cs` | Field value → mnemonic tables. |

All under `E:\Dev\Repos\Ronny\RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\`.

> **Two stale things to fix when someone touches these.** `docs\DISPATCH-MAP.md` §4 and §7 still say
> "1020 opcode records — 130 ch12, 578 labe, 312 derived"; the file now holds 1183. And the
> auto-generated header on `DispatchMapB30.g.cs` claims it came from `tools\microcode-5000-def.json`;
> it came from `docs\dispatch-map-b30.json`. The header emitter is shared and not parameterised.

---

## 3. The 128-bit microword

Grade: **[M]** for the layout (ND-05.022.1 chapter 2 prints the table), **[V]** for the decode
(`ControlStoreImageTests` extracts every field and re-inserts it, reproducing all 32768 words of A30
and B30 byte-exact).

### 3.1 The manual's table, verbatim (ND-05.022.1 ch.2)

> The ND-5000 microword is 128 bits wide. It is divided into several groups, each group controlling
> special parts or functions in the ND-5000 CPU.

| Bits | Control function (manual's own wording) |
|---|---|
| 127-122 | ALU function and carry select (true) |
| 121-116 | ALU function and carry select (false) |
| 115 | Execute unconditional |
| 114 | Enable conditional ALU operation |
| 113-111 | Q-register control |
| 110-103 | Additional arithmetic processor control |
| 102-101 | Timing control |
| 100-98 | Data-type control |
| 97 | Or control (ORCON) enable |
| 96-89 | A-operand select |
| 88-84 | B-operand select |
| 83-76 | Destination select |
| 75-72 | Status bits control |
| 71 | Index counter increment |
| 70 | Loop counter decrement |
| 69 | Enable conditional sequence |
| 68-65 | Sequence and stack control (true) |
| 64-61 | Sequence and stack control (false) |
| 60 | Invert sequence condition |
| 59 | Save test condition |
| 58-53 | Select test object |
| 52-51 | Alternative branch control |
| 50-48 | Instruction cache write control |
| 47-44 | Fetch control |
| 43 | Stop |
| 42 | AAP synchronization |
| 40 | Address arithmetic control, OCA/Micro |
| 39-38 | Effective address save control |
| 37 | Memory request controlled by address code |
| 35 | Address arithmetic activate (ADACT) |
| 41, 34-32 | Data memory control |
| 31-16 | Absolute microprogram address |
| 15-13 | Address A-operand select |
| 12-9 | Address B-operand select |
| 31-0 | Long argument |
| 15-0 | Short argument with sign extension |
| 7-0 | Mini argument with sign extension |
| 5-0 | Or logic control (ORCON) |

**Two things the manual's table does not do:**

- **It never mentions bits 8-6.** Our project puts the index-scaling field (`SCAL`) there, and the
  microcode's behaviour agrees, but the *bit positions of SCAL are a project derivation, not a
  manual fact.* [D]
- **Bit 36 is not listed either.** We keep it as `RESERVED_36` so round trips stay lossless. [D]

### 3.2 The layout as our code decodes it

`src\Microword.cs` + `src\Generated\MicroFields.g.cs`. The partition covers all 128 bits exactly once;
the argument views are overlays on bits 31-0.

| Bits | Field | Sub-fields |
|---|---|---|
| 127-124 / 123-122 | ALU_TRUE | op / carry select |
| 121-118 / 117-116 | ALU_FALSE | op / carry select |
| 115 | EXUC | |
| 114 | COND_ALU | |
| 113-111 | Q_REG | |
| 110-103 | AAP_CTRL | type 110-108, op 107-103 |
| 102-101 | TIMING | decoded, **never used** by the engine |
| 100-98 | DATATYPE | |
| 97 | OR_ENABLE | gates ORCON |
| 96-89 | A_OP | group 96-94, register 93-89 |
| 88-84 | B_OP | |
| 83-76 | DEST | group 83-81, register 80-76; 24 = `D,NOOP` |
| 75-72 | STATUS | |
| 71 | IXC_INCR | |
| 70 | LC_DECR | |
| 69 | COND_SEQ | |
| 68-67 / 66-65 | SEQ_TRUE | jump type / stack op |
| 64-63 / 62-61 | SEQ_FALSE | jump type / stack op — **straddles the 63/64 half boundary** |
| 60 | INVSEQ | |
| 59 | CSAVE | |
| 58-53 | TESTOBJ | the `COND,*` selector |
| 52-51 | ABR | alternative branch |
| 50-48 | TBC | instruction-cache write control; 7 = `TBC,NOOP` |
| 47-44 | GET | fetch control |
| 43 | STOP | |
| 42 | AAPSYNC | |
| 41 | MEM_BIT3 | high bit of the memory op |
| 40 | AD_ARTI | 0 = OCA-controlled EA, 1 = micro-controlled |
| 39-38 | EA_SAVE | |
| 37 | MEMOT | decoded, **never used** |
| 36 | RESERVED_36 | |
| 35 | ADACT | |
| 34-32 | MEM_BITS20 | low 3 bits of the memory op |
| 31-16 | ABS_ADDR | sequencer jump target |
| 15-13 | AA | address-arithmetic A select |
| 12-9 | AB | address-arithmetic B select |
| 8-6 | SCAL | index scaling |
| 5-0 | ORCON | sub-fields ORCON_N 5, ORCON_E 4, ORCON_A 3-2, ORCON_D 1-0 |
| *(overlay)* 31-0 | LARG | 32-bit constant |
| *(overlay)* 15-0 | SARG | 16-bit constant |
| *(overlay)* 7-0 | MARG | 8-bit constant |

The memory op is **split**: `MemOp = (bit41 << 3) | bits34-32`. Bits 40-36 sit in the gap and belong
to other fields. [V]

**The overlap that causes the wrong readings.** MARG (7-0) overlaps SCAL (7-6) and ORCON (5-0). On a
word that uses MARG as an address operand, *those bits are the constant* and any "ORCON=" or "IX\*n"
the rendered listing prints for it is fiction. This is exactly why rule 2 exists. Confirmed cases:
`0o326` prints `ORCON=21` where the raw ORCON is `0o41`; `0o15075` prints `IX*2 ORCON=0x08` where the
raw MARG is `0x48`. [V]

### 3.3 Two disagreements with the manual, unsettled

**(a) SARG sign extension.** ND-05.022.1 §11.3 [M]:

> During execution in the ND-5000 the short argument is sign extended to 32 bits by A,SARG.

Our `OperandRouter.cs` **zero-extends** `A,SARG` and marks the choice [D]. MARG is sign-extended in
both. One of these is wrong. It matters wherever a SARG constant has bit 15 set — and the ACCP command
words (`0o100501`, `0o100401`) do. **Adjudicate.**

**(b) MARG width.** The ch.2 table says mini argument = bits **7-0**. §11.3 says *"the value of the
constant is placed in the mini argument field during assembly (control store bits **8-0**)"* while in
the same sentence calling it "one 8-bit integer". The manual contradicts itself; we implement 7-0 and
the microcode agrees. [V] over [M].

**(c) `IX/16`.** The scaling table lists `IX/16 | Index register scaled by 16 | 80-bit floating` — the
mnemonic says divide, the description says multiply. Our SCAL code 5 is `<<4` (×16), matching the
description. Probably an OCR or typesetting slip in the mnemonic. [D]

### 3.4 What the image actually uses

Counted over the 13333 live words. [V]

| Field | Values present in B30 |
|---|---|
| `GET` | 0 (12501), 1 (8), 3 (165), 4 (253), 5 (12), 6 (14), 7 (4), 8 (11), 9 (11), 10 (292), 13 (23), 14 (3), 15 (36). **2 and 12 never appear.** |
| `MEMORY` | 0 (10975), 1 (32), 2 (208), 3 (1), 4 (51), 7 (490), 8 (1), 9 (328), 11 (6), 12 (81), 13 (12), 15 (1148). **10 never appears.** |
| `ALU_TRUE` op | all 16 used; `ALU,A` (4) is the commonest at 4900, then `ALU,FZRO` (0) 2736 and `ALU,XOR` (5) 2357 |
| `DATATYPE` | 0 W (10792), 1 F (566), 2 H (501), 3 BY (387), 4 BI (82), 5 D (373), **6 DD (3)**, 7 "from instruction" (629) |
| `STATUS` | 0,1,2,3,4,5,6,8,9,12,13,14,15. **7, 10 and 11 never appear** |
| `Q_REG` | all 8 used; `Q,Q*DIV` (2) only 7 times |
| `TESTOBJ` | 29 distinct values; `COND,MZRO` (9) 888, `COND,SAVC1` (26) 272, `COND,MSGN` (11) 309 |
| `AAP_CTRL` | 16 distinct non-zero values, top three: 72 (125), 66 (111), 87 (70) |
| `EXUC` set | 345 words |
| `ADACT` set | 2905 words |
| `OR_ENABLE` set | 1079 words |
| `COND_SEQ` set | 1702 words |
| `STOP` set | **10 words** |
| distinct `A_OP` values | 158 |
| distinct `DEST` values | 99 |

On ADACT words specifically: `AB` = 0 (1036), 1/MARG (1329), 2 (16), 4-7/IX1-4 (308 total), 9 (23), 10
(16), 11/ADR+4 (161), **12-15 (4 each, 16 total)**; **AB=8 never used**. `SCAL` = 0 (2425), 1 (172),
2 (108), 3 (181), 4 i.e. ÷8 (14), 5 i.e. ×16 (5); **6 and 7 never used**. [V]

That last block is load-bearing for §14: several of our "unimplemented" throws can never fire on this
image.

---

## 4. Map of the control store

Grade: **[V]** for every address boundary and word count (computed over the raw image and the label
table). **[D]** for some region *names*, where the name is my summary of what the labels in it say.

### 4.1 First, the shape of the space

- Total: **16384** words. [V]
- **There are no blank words.** Not one word of the image is all-zero. [V]
- Unused space is filled with a single repeated word:
  `00400000000180000000000000800000` = `ALU,FZRO ALUF,ADRC A,BM00 B,X1 T,JMP ADDR=ILLEG` — **a jump to
  `ILLEG` at 0o200**. It occurs **3051** times. [V]

That matches the manual exactly. ND-05.022.1 §12 [M]:

> The space available for user written microprogram, depends on the microprogram version. New contents
> may be placed in the upper part of the writable control store. **A general rule is that the area free
> for user written microprogram is empty or contains only a jump to microprogram address 200.**

So the filler is not padding — it is a deliberate safety net, and the *free user area is identifiable
by it*.

- **Live (non-filler) words: 13333.** [V]
- Filler splits into: one 57-word hole at `0o107`–`0o177`, the 2911-word tail at `0o32241`–`0o37777`,
  and 49 short runs (83 words total) scattered between instruction entry stubs in `0o200`–`0o3010`. [V]

**The free area for user microprogram is `0o32241` – `0o37777`, 2911 words.** [V] + [M]

### 4.2 The map

Regions are contiguous and exhaustive: they sum to exactly 16384. "lbl" = labels defined inside.

| Octal range | Words | Fill | lbl | What lives here | How we know |
|---|---:|---:|---:|---|---|
| `0o000000`–`0o000043` | 36 | 6 | 28 | **Fixed service entry vectors + microcode constants.** `MASTER_CLEAR`/`SAMSON` @0, `VERSION` @1, `LOOK_HARDWARE` @2, `HWF` @5, `POWER_FAIL` @6, `CPUMODEL` @7, `SIM_EXEC` @10, `SIM_BP` @11, `DUMPTRACEMEM` @12, `ADDRTRACEMEM` @13, `GOIDLE` @16/17, then the constant routines `OFFSET` @20, `PSTBASE` @21, `WIP_PGU` @22/23, `NKMB_POINT` @24, `SAMSON_CPU` @25, `START_MESS` @26, `ZERO_P` @27, `LOOK_HARD` @30, `LOOK_SRF` @31, `MACRO_STARTP/STARTL/INIT` @32-34, `SPARE_35/36`, `MACRO_SETP` @37. These are the addresses the ND-100 side starts the microprogram at. | [V] labels + [V] words |
| `0o000044`–`0o000057` | 12 | 0 | 12 | **Descriptor-branch vectors.** `DESC_X{1..4}_RD`, `_ADL`, `_WD` — the hardware **descriptor branch**, vectored from five bits `EDSB` + `TPDSB(0-3)` which encode *"the register no.s X1, X2, X3, X4 and disabling the auto-incrementing of the register and differentiating between READ and WRITE access"* [M, ND-05.020.01 page 226]. 4 registers × 3 accesses = the 12 used slots of a 16-vector space. Each word uses `AB=13` (`X2ORS`, index scaled by the instruction's data type). Return address (jump address − 1) is pushed. | [V] + [M] |
| `0o000060`–`0o000077` | 16 | 0 | 16 | **`CMIS00`–`CMIS17` — the CONSTANT-MISMATCH branch vectors.** [M] names this range exactly: *"These conversions lead to a constant mismatch hardware branch (microaddresses 60B-77B)"* (ND-05.020.01, IDU nanostate 3), and the vector is formed from four bits `TPCMB(0:3)` / `CMTP` handed to the MIC — 16 vectors, one per mismatch type. A *second* hardware dispatch, entirely separate from IMAP. Only three are real conversions: `CMIS00`→`CMIS_I_SF` @`0o27427` (int→single), `CMIS01`→`CMIS_I_DF` @`0o27432` (int→double), `CMIS02`→`CMIS_F_DF` @`0o3153` (single→double). **`CMIS03`–`CMIS17` all jump to `ILL_OP_SPEC` @`0o3136`.** The MIC pushes the return address (jump address − 1) before branching. | [V] + [M] |
| `0o000100`–`0o000106` | 7 | 0 | 7 | **The error cluster.** `TRAP` @100 (→`TRAP_SAM` 0o12545), `NOTHING` @101, `FATAL` @102, `DUMMY` @103, `DUMMY_2` @104, `DUMMY_1` @105, `DUMSC14` @106. `NOTHING`/`FATAL`/`DUMMY` are jump-to-self dead ends; `DUMMY_2`→`DUMMY_1`→`RETURN,POP` is the two-cycle filler subroutine, called **370 times** — the most-referenced label in the image. | [V] |
| `0o000107`–`0o000177` | 57 | **57** | 0 | **Filler.** Unused vector slots, all jump to `ILLEG`. | [V] |
| `0o000200`–`0o003011` | **1418** | 77 | 534 | **THE MACRO-INSTRUCTION ENTRY REGION.** `ILLEG` @200, `BP` @201, `NOOP` @202, then every macro instruction's entry point and its short inline body: loads/stores/moves @203-236, compares/tests @237-253, negate/invert/logic @254-347, shifts @350-413, bit ops @414-533, swaps/loops @532-643, calls/returns/enter @644-712, system instructions @713-1062, register/context ops @1063-1177, string instructions @1200-1353, transcendentals @1354-1436, array (AXI/IXI/SQRT/POLY) @1437-1512, indirect/descriptor @1514-1636, **the reserved user-extension slots `RES1`–`RESD22` @1637-2037** (see §5.5), packed decimal @2043-2076, loops @2105-2126, float/double arithmetic @2143-2545, modulo/incr/decr @2542-2606, integer/float convert @2607-2777, float test @3000-3010. Interspersed filler = the gaps between variable-length entry stubs. | [V] |
| `0o003012`–`0o003757` | 486 | 0 | 240 | Operand and descriptor helpers, range checks, the shift/bit/convert tails, and the computed-jump tables `BFW_00`–`BFW_37`, `PUTBF_T20`–`T37`, `READ_S1_*`. `DESC_X*_RD1/AD1/WD1/WL1`, `DESC_RANGE*`, `SOUR_RANGE`, `DEST_RANGE`, `ILL_INDEX`, `ILL_OP_SPEC` @3136, `INS_SEQ_ERR`, `CMIS_F_DF`, `GET_NEXT` @3231 (52 references). | [V] |
| `0o003760`–`0o004065` | 70 | 0 | 10 | Monitor-call entry: `CALL600` @3761, `CALL_MONX` @3762, `CALL_MON1`/`_MON8` @3770-4000, `CALL_MON9` @4002 (the stop record), `CALL_5XX`, `MISEQERR`, `CALL_DOM` @4020. | [V] |
| `0o004066`–`0o004634` | 359 | 0 | 80 | Call / enter / return frame machinery and domain calls: `CALL_DOM_ER`, `RD_IS_MEM`, `SHIFT_R`/`SHIFT_L`, `ENTM*`, `DOM_ENTM_4`, `ENTS_*`, `RET_1`–`RET_4`, `RETD_1`, `HEAPWR`, `GETB_1`, `FREEB_1`, `LINDF_0`/`LINDD_0`. | [V] |
| `0o004635`–`0o005105` | 169 | 0 | 32 | **`MHOLE_*` — memory-hole handling** (read/write/insert across a page or descriptor hole), plus the `MHOLE_TAB` jump table. | [V] |
| `0o005106`–`0o005705` | 384 | 0 | 82 | **NUCLEUS message helpers.** `SEND_4`…`SEND_31`, `NKFSIZE`, `NKFLENGTH`, `NKFHOMEID`, `NKHOMEID`, `NKFLASTID`, `NKFBUFFER`, `NKFQUEUE`, `NKGETCI4`, `BUILTOWNER`, `NKRETSTS`, `MB_FIRST`. This is the time-critical ND-5000 nucleus messaging that on the classic ND-500 was brokered by the ND-100. | [V] labels, [D] the framing |
| `0o005706`–`0o006220` | 203 | 0 | 54 | **Block move**: `MBF_*` forward, `MBR_*` reverse, with word/byte/domain/alt-domain loop variants; `BMOVEDF_*`. | [V] |
| `0o006221`–`0o010465` | **1189** | 0 | 377 | **The string instruction engine** — the single biggest functional block. `SET_PD`/`RESET_PD`/`DIS_IDESC` descriptor plumbing, then `SMOVE{BI,BY,HW,W,D}`, `SMVWH`, `SMVUN`, `SMVTR`, `SMVTU`, `SMOVN*`, `SFILL*` and `SFILLn*`, `SCOMP`, `SCOTR`, `SCOPA`, `SCOPT`, `SSKIP`, `SLOCA`, `SSCAN`, `SSPAN`, `SMATCH`, `SSPAR`, `SCHPAR`, `CHAIN`. | [V] |
| `0o010466`–`0o010765` | 192 | 0 | 27 | `PLCCN*` PLANC↔ND descriptor conversion tails, `NCPLC_1`, `ILLEG_CHK`, `REXT_*`/`REXT_VECT`, and the physical-access instructions `RPHS`/`WPHS`. | [V] |
| `0o010766`–`0o012034` | 551 | 0 | 115 | **Context and register-block load/store.** `LOADCT_*` (load context), `READN_PS`, `READN_CED`, `READ_DITR`, `STORCT_*`, `LOADRG_*`, `LOADRB_*`, `LOAD_NEW_P` @11534, `STORRB_*`, `SCPUNO_1`, `SVERS_1`, `JUMPS_1`, `START_NEXT`. | [V] |
| `0o012035`–`0o012544` | 328 | 0 | 89 | **MMS / domain plumbing.** `CED_TO_DIT` @12035 (29 references — the domain-information-table address former), `LOAD_LL_HL`, `LOAD_ST1`, `SETE*`/`CLTE*`, the page-guard and window instructions `RPGU*`, `ZPGU*`, `RWIP*`, `ZWIP*`, `BP_2`, `DEL_TRAP`. | [V] |
| `0o012545`–`0o014265` | **849** | 0 | 129 | **The trap handlers.** `TRAP_SAM` @12545 (the entry every trap funnels through), `TRAP_NDF`, `TRAP_NIF`, `TRAP_FATAL`, `TRAP_CHECK`, `TRAP_AFS*`, `TRAP_DBS*`, `TRAP_DHWF`, **`TRAP_MONC` @12740**, `TRAP_IFC` @12743, `TRAP_IDC*`, `TRAP_MMSV`, `PROTVIOL` @13036, `MMS_PST0`/`MMS_LIX`/`MMS_PSIX`/`MMS_PST`/`MMS_SIX0`/`MMS_ERROR` @13042-13102, `TRAP_LOAD`, `TRAP_ACCP` @13313, `TRAP_VECT`, `GET_CNTXT`, `TRACE_TRIGD`, `TRAP_GEN`/`GEN1`–`GEN4` (the stop-record builders), `TRAP_PGF0/1`, `TRAP_END` @13606, `TRAP_ENA*`, `TRAP_START`, `SAVEREG_1`. | [V] |
| `0o014266`–`0o014665` | 256 | 0 | 38 | `SAVEIMEM`, `CLEARTRS`/`CLTR*` (control-store error path incl. the `CLTR_ERR` STOP), `ENTT*`, `RETT*`, `INIT_SAM_*` (the cold-start initialisation), `NEWCNTXT` @14660. | [V] |
| `0o014666`–`0o015026` | 97 | 0 | 11 | **`CNTXTSAVE` @14666 / `CNTXTLOAD` @14742** — the process context switch, plus `READST1`/`READST2`. | [V] |
| `0o015027`–`0o016370` | **738** | 0 | 193 | **The octobus message handlers.** `WRITEST1`/`WRITEST2`, `NEW_PS`/`NEW_CED`/`NEW_CAD`, `TRAPSET`, then `MSG_LINK0`–`MSG_LINK9`, the 64-entry MICFU dispatch table at `0o15224`–`0o15323`, and every `MSG_*` handler: `MSG_VERSRD` @15330, `MSG_DMEMRD` @15336, `MSG_DMEMWR` @15355, `MSG_IMEMRD` @15403, `MSG_IMEMWR` @15442, `MSG_RESIRD` @15516, `MSG_RESIWR` @15534, `MSG_PHYSRD` @15561, `MSG_PHYSWR` @15600, `MSG_HISTOG` @15626, `MSG_CACHE` @15640, `MSG_CLEAR` @15643, `MSG_DUDC` @15655, `MSG_STARTP0` @15660, `MSG_START` @15671, `MSG_CONMC` @15676, `MSG_CONWR` @15703, `MSG_PRT` @16005, the UNIX-500 trio @16015-16067, `MSG_CCONMC` @16121, the trace family @16160-16200, `MSG_CACI` @16202, `MSG_LOOKSRF` @16245. | [V] |
| `0o016371`–`0o016430` | 32 | 0 | 17 | **The ACCP port.** `ACCP_READ` @16371, `ACCP_WAITI` @16375, `ACCP_XWRITE` @16401, `ACCP_WRITE` @16402, `ACCP_WAITO` @16406, then `TRAP_OMESS` @16412 and the head of the kick decoder `OCB_DECODE` @16417, `OCB_MES_K` @16424, `OCB_DEC_K` @16430. | [V] |
| `0o016431`–`0o017300` | 424 | 0 | 87 | The 64-entry kick jump table `0o16430`–`0o16527`, `OCB_KICK64` @16530, the async-trap decoder `TRAP_ATRP` @16612 with its 256-entry table @16623, the deferred re-scan `0o16572`–`0o16611`, `SCAN_ACCP` @16554, `TRAP_OCBM` @16727, `TRAP_PROC0` @16700, `SYS_READ` @17111, `CPU_UNAVA` @17270. | [V] |
| `0o017301`–`0o017411` | 73 | 0 | 31 | **Constant pool (pointers and flags).** `CPU_MESSAGE` @17301, `CPU_AVAIL?`, `VERSION1`/`24`/`25`/`27`/`3`, `SET_IN_TRAP`/`SET_RUNNING`/`SET_IDLE`, then the `ADR_*` SRF-address helpers @17334-17401 (`ADR_MESS`, `ADR_FIFOB`, `ADR_FLAG`, `ADR_SYSTRA`, `ADR_SYSHOS`, `ADR_SYSPAR`, `ADR_MODINIT`, `ADR_ASTBAD`, `ADR_MOD`, `ADR_PROC0`, `ADR_MODMASK`, `ADR_CPUPAR`, `ADR_CPUAVA`, `ADR_#CPUDF`, `ADR_EXQUE`, `ADR_MSGME`, `ADR_CPUFLG`, `ADR_ATRAP`, `ADR_5SIB`), `POWERFAIL` @17403. | [V] |
| `0o017412`–`0o017777` | 246 | 0 | 21 | `MSG_END` @17412 and the answer/queue-walk tail (`MSG_NEXTL` @17442, `MSG_NEXT` @17455, `MSG_LINK0` @17461), then `LOOK_HARD_1` @17472, `LOOK_HW_WRITE` @17652 (100 references — the debug write helper), `LOOK_SRF_1` @17657, `MACRO_STP1` @17702, `SIM_EXEC_1` @17771. | [V] |
| `0o020000`–`0o020013` | 12 | 0 | 2 | `EXUC_1` @20003, `WAIT_SRF` @20011. | [V] |
| `0o020014`–`0o020342` | **215** | 0 | 19 | **The float constant pool.** `MATH_CONST` @20014, then `TANF_CONST`, `TAND_CONST`, `SINF_CONST`, `SIND_CONST`, `ASINF_CONST`, `ASIND_CONST`, `PI_LEAST` @20170, `ATANF_CONST`, `ATAND_CONST`, `EXPF_CONST`, `EXPD_CONST`, `ALOGF_CONST` @20272. These words are **data** — their `LARG` fields carry the polynomial coefficients, reached by the EXUC constant-word trick (§6.4). | [V] |
| `0o020343`–`0o020656` | 204 | 0 | 75 | `INTRF_U` @20343 (the integer-round helper cos/exp depend on), `INTRD_*`, `SQRTF_*` @20400-, `DES_*` decimal entry, `BINC1`/`BCDC1`, `STRTBCD3_*`. | [V] |
| `0o020657`–`0o023677` | **1553** | 0 | 307 | **Decimal / BCD / ASCII arithmetic — the largest single block.** `DES_INROUT`, `DES_IN*`/`DES_OUT*` (ASCII↔internal, leading/trailing sign, separate sign, embedded sign), `ADDBCD`/`SUBBCD`/`MPYBCD`/`COMPBCD`/`PACKBCD`/`UNPACKBCD` and their `DES_*` workers, `BCD_ADD_*`, `BCD_MPY*`, `BINC_*` and `BCDC_*` conversions, `DES_SHIFT`. | [V] |
| `0o023700`–`0o024377` | 320 | 0 | 82 | Float↔integer conversion (`DFL_INT*`, `FL_INT*`, `RDF_INT*`, `DFINTCSL/R`, `RDINTCSL/R`) and the **float divide core** `DIVFI_*` with `DIVTAB` @24300. | [V] |
| `0o024400`–`0o024667` | 184 | 0 | 52 | **`DIV_64` @24400** — the 64-bit non-restoring long divide, its loop `DIV64L1`/`L2`, `EXN640`, `BD640`, `SHD640`, `POSREST_0`, `CT64DIV`; plus the decimal shift tail. | [V] |
| `0o024670`–`0o024733` | 36 | 0 | 6 | **`IDLE` @24670, `IDLE_0`/`_1`/`_2`, `ACTIVATE` @24723, `ACTIVATE1`.** The whole idle-and-wake loop is 36 words. | [V] |
| `0o024734`–`0o025670` | 477 | 0 | 78 | `TRAP_SWAP` @24734 (the page-fault swapper request), `CALL_MT`/`CALL_RF`/`CALL_WF` @25017, `X5SIBCALL` @25021, `CALL_STAP`/`STOP`/`SWIP`, `OCB_KICK03` @25522, `OCB_KICK04/05` @25553, `OCB_KICK06` @25561, `OCB_CLNUP` @25570, `PRNOWR` @25416, `GIVEINT` @25422, `LOCK_QUE` @25442, `UNLOCK_QUE` @25505, `CALL_600` @25364, `CALL_NDIX` @25401, `INIT_ADRP` @25646, `SYS_DATAF` @25630. | [V] |
| `0o025671`–`0o027027` | 607 | 0 | 98 | **Transcendental bodies.** `EXPF_0` @25674, `EXPD_0` @25720, `SINF_0`/`COSF_0`/`SIND_0`/`COSD_0`, `XREDU_F` @26106 / `XREDU_D` (argument reduction), `TANF_0`/`TAND_0`, `ASINF_0`/`ASIND_0`, `ACOSF_0` @26234 / `ACOSD_0` @26307, `ATANF_0` @26356 / `ATAND_0`, `ALOGF_*`/`ALOGD_*` ending `ALOGD_END` @27021, `SQRTD` bodies. | [V] |
| `0o027030`–`0o027107` | 48 | 0 | 16 | **AAP primitives.** `FAAP*F+F`, `FAAP+F`, `DAAP*F+F`, `DAAP+F`, `POLLYF*`, `POLLYF++`, `POLLYF+`, `POLLYF**`, the `POLLYD*` set, `RAPPF`, `LAPPF`, `RAPPD` — the fused multiply-add and polynomial kernels the transcendentals call. | [V] |
| `0o027110`–`0o027647` | 352 | 0 | 116 | Write helpers (`FWRITE`, `DWRITE`, `FORDWRITE`), `CIND_BY`, `MUL4_WRITE`, `ENTIER_*`, `REM*`, `INCRF_*`, the LOOP instruction bodies (`FLOOP*`, `DLOOP*`, `*_COMM`), `CMIS_I_SF` @27427 / `CMIS_I_DF` @27432, `IREM_*` @27537, conversion tails, `CTHR`/`DCTHR`, `APFUNC` @27640. | [V] |
| `0o027650`–`0o030047` | **128** | 0 | **1** | **The darkest block in the image.** One label (`APFUNC_V` @27650) over 128 words — the array-processor function vector body. Nothing else names any of it. | [V] words, [OPEN] content |
| `0o030050`–`0o031532` | 819 | 0 | 189 | **Single-precision vector / array processing (the SAX library's microcode).** `AP_INIT_1/2/3` @30050-30056, then `VF_ADD`, `VF_SUB`, `VF_MUL`, `VF_DIV`, `VF_SDIV`, `VF_DOTPR`, `VF_CLR`, `VF_CONV*`, `VF_SWAP`, `VF_NDFPCV`, `VF_XPND`, `VF_CFFT_BFLY`, `VF_MIRR`, `VF_RFFT`, `VF_NMO_*`, `VF_NMS_*`, `VF_FCONVH`, `VF_DMXB`, `VF_CONSGD`, `VF_CONSGC`, `VF_SGDQ2A`, `VF_PREDICT`, `VF_IMG_*`. | [V] |
| `0o031533`–`0o032240` | 326 | 0 | 85 | **Double-precision vector (the DAX library's microcode).** `VD_ADD`, `VD_SUB`, `VD_MUL`, `VD_DIV`, `VD_MAX`, `VD_MAXV`, `VD_MINV`, `VD_MAXMGV`, `VD_SVESQ`, `VD_SVS`, `VD_FLNZ`, `VD_CVMUL`, `VD_TAPER` @32227 — the last named word in the image is `VD_TAPER_1` @32230. | [V] |
| `0o032241`–`0o037777` | **2911** | **2911** | 0 | **Free user-microprogram area.** Every word a jump to `ILLEG`. | [V] + [M] |

### 4.3 What is unaccounted for

Being precise about the holes, because a map with silent gaps is worse than none:

| Category | Words |
|---|---:|
| Total control store | 16384 |
| Filler (jump to `ILLEG`) — **known to be nothing** | 3051 |
| Live words inside a named functional region | 13333 |
| Of those, live words carrying a label | 3356 addresses (3457 names) |
| Live words **more than 25 words past the nearest label** — the stretches nobody has read | **551** |
| The single largest unread stretch | `0o27650`–`0o30047`, **128 words**, one label |

So: **every live word is inside a region we can name, but only ~25% of live words carry a symbol, and
551 words (4% of the live image) sit in long unnamed stretches.** Nothing is unaccounted for at region
level; plenty is unexamined at word level.

A second, harder number: of 3356 labelled addresses, **873 are never referenced by any named jump in
the image**. 594 of those are in the entry region `0o0`–`0o3011`. Those are the addresses hardware must
supply — the IMAP entries, the CMIS vectors, the ND-100 service vectors — plus computed-jump table
targets (a `JMPREL` into a table leaves no symbolic reference, so "never referenced" is *not* the same
as "IMAP entry"). See §5.7 for what falls out of that. [V]

---

## 5. Opcodes → microcode: the dispatch

**Read the grade line first: this whole section mixes [M] anchors with [D] reconstruction. 130 rows of
the map are manual-verified. The other 1053 are rebuilt.** Ronny's own words about it earlier in the
project were *"since we do not have imap/omap and are very much guessing shit"* — that is the right
instinct, and this section exists to say exactly how much guessing, and where.

### 5.1 The hardware: what turns an opcode into a control-store address

The decode hardware lives on the **IDA baby module** — part **324718** on the ND-5800/5900 (324708 on
the smaller models). The IDA does three jobs [M, ND-05.020.01 ch.7 / lines 1197-1271]:

- **IAC** — Instruction Address Controller. Holds **P/PC** (the macroinstruction at the pipeline
  A-level), **SP** (the one at F-level — *this is the trapping P*), **NPC** (the one at M-level, which
  walks each operand in turn), **L**, scratch **S** and **Y**, and a 32-bit adder.
- **IDU** — Instruction Decode Unit. Decodes the instruction and **addresses the IMAP and OMAP**.
  Holds **HL** / **LL** (the address-trap limits) and **TE** (trap enable).
- **DAC** — Data Address Controller. Computes every logical data address: **B**, **R**, four **EAn**,
  an adder, output through **DACR** onto the DLA bus.

The manual's own sentence [M, ND-05.020.01:1223]:

> To assist the IDU and IAC during the unpacking of the instruction stream, the instruction map (IMAP)
> and the operand map (OMAP) are used. Both these maps are PROM memory. They are addressed by the IDU,
> and contain information about the instruction opcodes and operands respectively.

**IMAP holds, per macro-opcode** [M, ND-05.020.01:1241-1246, :2377]:

- the **entry point** — "the start address for the microprogram part that executes a specific
  macroinstruction",
- **ICHAR** — instruction characteristics,
- **OPTYP** — float/int and data-path width 8/16/32,
- **RIN** — the register number encoded in the opcode.

**OMAP** is 18 bits × 256, addressed by the operand ADDR-CODE byte, and drives the DAC
[M, :2374-2375, :2511]. Two-byte (`177xxx` octal) opcodes reach IMAP through a hardware **hashing**
step [M, §3.3.2].

**Where they physically sit**, ND-05.020.01 §3.3.1 page 71 [M]:

> The operand map (OMAP) is physically placed on the **IDA baby card**, while the instruction map
> (IMAP) is placed on the **mother card**.

So the two maps are on *different boards* — which matters if anyone ever goes looking for the PALs
that hold them.

**The decode chain, in the manual's words** [M, ND-05.020.01 ch.7 page 189]:

> Instruction codes can be long (2 bytes) or short (1 byte). If they are long, the 4 most significant
> bits are all '1'. This is decoded, and the 12-bit instruction code (INC) is selected from IAL and put
> in the instruction code register (INCR). **INCR then points to the I-MAP, which gives some instruction
> characteristics and the entry-point to the microprogram.**

And [M, :7052]:

> The **instruction map** (IMAP) is a table of pointers, one for each macroinstruction, giving the start
> address for the microroutine belonging to that particular macroinstruction. **Whenever an instruction,
> that is not resident in cache, should be executed, the first microaddress is given by the IMAP.**
> Thereafter, the addressing sequence is taken care of by MIC.

**IMAP's cached output is 13 bits** — `IC(0-12)` [M, :2352] — carrying ICHAR + OPTYP + RIN. The
entry-point field is separate and goes to the control-store address bus.

**Where RIN actually lands.** Not on a WRF selector directly: it presets the SRF address register
[M, ND-05.020.01 §8.10.4]:

> A method of presetting the RFA registers on the start of a macroinstruction is supported by the MIC.
> All bits in the registers are then set to '1', except for bits 1 and 2 which are set to the value of
> the signals **RIN(1-0)** for RFA1 and **RADC(0-1)** for RFA2.

That is a 2-bit RIN, which is exactly why chapter 12's group-3 entries consume **four consecutive
opcodes each** — the low two bits of the opcode *are* the register number.

**Illegal opcodes are handled two different ways** [M, :3172] — worth knowing before assuming every
hole should throw:

> Some illegal opcodes are flagged in the IMAP, and they are never cached in the ICA system. Others
> have an ordinary IMAP entry and microcode entry point. **They set the IIC bit from microcode.**

After decode the result is cached: **IC** holds "a copy of the IMAP contents" [M, :2352], **OC** the
operand characteristics, **CC** the *first microinstruction* of the macro, **AC** the address the DAC
computed. On a cache miss the IDU stops the pipeline, decodes through IMAP/OMAP, fills IC and AC, then
releases the pipeline and simulates a hit [M, :1668].

### 5.2 There is no ROM to dump. This is permanent.

The manual calls IMAP/OMAP "PROM memory", but that is a *functional* description. The part lists for
**both** IDA cards contain **no PROM device at all** — only a ~20-chip PAL bank and three custom LSIs
(2 × `ND-S-DAC/IAC`, 1 × `ND-S-IDU`). [V, sintran.com hardware pages for 324708 / 324718, recorded in
`E:\Dev\Ronny\ND5000UC\docs\ND5000-IDA-MODULES.md`]

So the maps are baked into the PALs and/or into the ND-S-IDU gate array. **There is no file anywhere
that contains them, and no software procedure that could produce one.** A confirmed-negative search
across `E:\Dev\Ronny` and `E:\Dev\Repos\Ronny` for IMAP / OMAP / 324718 / 324716 dumps found nothing.

**What that means for us, concretely:**

1. Every `derived` and `labe` row in the dispatch map is *unverifiable by document*. The only things
   that can raise a row's grade are (a) a differential measurement against another engine, or (b)
   reading the **PAL fuse maps** off a real card with a PAL reader, or reversing the LSI.
2. `Rin` and `DataType` in our `DispatchEntry` are stand-ins for the real **RIN** and **OPTYP** bits.
   We do not model **ICHAR** at all.
3. Where the microcode entry is `TYP,DR` ("type comes from the instruction"), one entry serves several
   opcodes and the *only* thing distinguishing them is the IMAP metadata. Those are exactly the rows
   where a wrong `dataType` stays invisible until an oracle catches it.

### 5.3 The entry region — the microcode side of the contract

The macro-instruction entries occupy **`0o200` – `0o3011`**: 1418 words, 534 labels. [V]

- `ILLEG` @`0o200` — where every unmapped opcode and every filler word lands.
- `BP` @`0o201` (decimal 129) — breakpoint.
- `NOOP` @`0o202` (decimal 130) — the `NoopEntry` the test harnesses park `Mpc` at.
- From `0o203` upward: one entry per instruction *family*, with its short inline body following.

**Entries are not a fixed-stride table.** `LOADBI` @`0o203`, `LOADT` @`0o206`, `LOADD` @`0o207`,
`LOADR` @`0o211`, `LOADB` @`0o213`, `STOREBI` @`0o215`… The stride varies with how many words each stub
needs. That is direct evidence IMAP is a genuine lookup table, not address arithmetic. [V]

**Except inside the EXT blocks**, where the stride *is* regular — group 1 one word each, groups 2 and 3
two words each — which is exactly what makes the chapter-12 table checkable (§5.5).

**Stub shape** [V]: word 0 sets `TYP,<t>` and starts the operand access; word 1 either jumps into the
real implementation or jumps to `ILLEG` for an unused slot.

Our map's entries span `0o201` to `0o27537`; **494 of the 495 distinct entries lie inside
`0o200`–`0o3011`**. The single outlier is `AMODB` → `IREM_BY/H/W` @`0o27537`, which is `derived`,
reference-free in the `.LABE`, and is flagged as the weakest binding in the table (12 rows). [V]

### 5.4 The reconstruction method

The pipeline is:

    docs\dispatch-map-b30.json          (hand-curated records, one per opcode)
      -> dotnet run --project tools\ND5000FieldGen -- dispatch docs\dispatch-map-b30.json src\Generated
      -> src\Generated\DispatchMapB30.g.cs

The working method — the one that has actually produced correct rows, proven 2026-08-23 — is
**three sources plus a measured validator**:

1. **Get the work list.** Run `Nd500xCorpus_Sweep_Report`. Its "unsupported by reason" block names
   every hole verbatim: *"Opcode NNNNNN (octal) … has no entry in the reconstructed dispatch map"*.
2. **Opcode → mnemonic + datatype**: nd500x's `~/repos/nd500x/src/cpu/instructions.json` (538 opcodes,
   derived from ND-05.009.4, the reference-manual pages our local OCR lacks). Datatype comes from
   `variantNumber` against the prefix-bit order BI, BY, H, W, F, D. This table does *not* carry the
   entm/init row-duplication defect that made `ND500_OPCODE_REFERENCE.md` unusable.
3. **Mnemonic+type → entry label and octal address**: `MICRO-5800-B30.LABE`, regex
   `^(\S+)\s+(\d{6})\*` after stripping CRs. Family behaviour matters — `add2`/`sub2`/`add3`/`sub3`
   share **one** integer entry across BY/H/W (`ADD2` @`0o271`, `TYP,DR`), while `mul`/`div` have
   **per-type** entries (`MUL2BY`/`MUL2HW`/`MUL2W`, `DIV2BY`/`DIV2HW`/`DIV2W`).
4. **Check the entry word.** Read the candidate address in the listing. Every arithmetic entry must
   look like an operand-fetch head: `ALU,A TYP,DR/F/DF … READ … ADACT`. A candidate that does not read
   like an entry stub is rejected.
5. **Merge, regenerate, rebuild, re-run the sweep.** The sweep is the validator. Match up means right.
   A divergence on *your own* opcode means a wrong binding — revert it. A divergence on a *downstream*
   opcode means the vector now runs past the filled hole and hits an already-known divergence.

**A hole is better than a wrong row**, and that is a stated policy, not an accident: a hole throws and
is counted; a wrong entry silently poisons the oracle.

**"The +128 match from add2/sub2/mul/div binding"** is the measured result of one pass of that method
over the two/three/four-operand arithmetic families (add2, sub2, mul2, mul3, mul4, div2, div3, div4):
**33 opcodes bound**; on the 40082-vector nd500x conformance sweep, match went **35513 → 35641
(+128)**, unsupported **430 → 296 (−134)**, trap-ok 319 → 335, and **zero wrong bindings**. The
self-check that validated the method: it independently re-derived the already-trusted add3/sub3 rows
exactly. [D, measured]

> Provenance caveat: those post-2026-08-23 numbers come from the work log, not from a `.trx` on disk.
> The only test-result file present is dated 2026-08-18 and predates the work:
> `total=40082 match=35516 diverge=99 unsupported=429`. Treat 35641 / 296 / 335 as documented, not
> independently re-measured here.

**The `dataType` enum** is the microword DATATYPE encoding — *not* the prefix-bit order. It was read
off already-trusted rows, not assumed:

| value | 0 | 1 | 2 | 3 | 4 | 5 | −1 |
|---|---|---|---|---|---|---|---|
| type | **W** word | **F** single float | **H** halfword | **BY** byte | **BI** bit | **D** double | unknown / typeless |

Microword DATATYPE value **7** means "type comes from the instruction". At runtime:

    return word.DataType == 7 && Regs.InstrDt >= 0 ? Regs.InstrDt : word.DataType;

That one line is our stand-in for the IMAP OPTYP bits being copied into IC(0-12). An opcode left at
`dataType = −1` whose microwords use `TYP,DR` resolves to 7 and `AccessWidth` throws — which is exactly
the INIT swapper blocker, now guarded by `DispatchMapTests.Init_HasWordDataType_ForTypDrStackAccess`.

**RIN** is the register-in-instruction digit: 0 = R1 … 3 = R4, −1 = the opcode carries no register
digit. It drives the OR-logic paths `ORA,IN`, `ORD,IN` and `A,ALU,REG37`, and is published at dispatch
as `Regs.InstrRin`. A microword that needs it with no metadata throws.

### 5.5 The manual anchors — the part that is genuinely [M]

**ND-05.022.1 chapter 12, "User Instructions for Microprogram Extensions"**, is the only official
document that prints opcode-to-entry pairs. It opens [M]:

> Some instruction codes in the ND-5000 are available for user written microprogram. This means that
> an instruction code **has an entry in the ND-5000 microprogram**, but is not used. 'Not used' means
> that the instructions generate an illegal instruction code.

Instructions are grouped by operand decoding: **group 1** no operand, **group 2** one memory operand,
**group 3** a general operand (constant, register or memory, with OR-logic register selection).

I checked 30 of its printed pairs against both the reconstructed map and the `.LABE`. **30 of 30
matched exactly, entry for entry.** [V]

| Opcode (octal) | Hex | Group | Manual entry | `.LABE` label at that address | What B30 put there |
|---|---|---|---|---|---|
| `236` | `0x9E` | 1 | `1637` | `RES1` | — |
| `237` | `0x9F` | 1 | `1640` | `RES2` | — |
| `177004`–`177007` | `0xFE04`–`07` | 1 | `1641`–`1644` | `RES3`–`RES6` | manual: "read status of tracer", "load control tracer" |
| `177036` | `0xFE1E` | 1 | `1645` | `DCDUMP` / `RES7` | **`Ddirt`** — dump dirty |
| `177037` | `0xFE1F` | 1 | `1646` | `EXINT` / `RES8` | manual: "Timer interrupt" |
| `177436` | `0xFF1E` | 1 | `1647` | `CLINIT` / `RES9` | manual: "Timer clear" |
| `177437` | `0xFF1F` | 1 | `1650` | `CLREAD` / `RES10` | manual: "Timer read" |
| `177300`–`177303` | `0xFEC0`–`C3` | 3 BYn | `1651` | `WDUSBY` / `RESBY11` | descriptor write, byte |
| `177320`–`177323` | `0xFED0`–`D3` | 3 Hn | `1661` | `WDUSH` / `RESH11` | |
| `177340`–`177343` | `0xFEE0`–`E3` | 3 Wn | `1671` | `WDUSW` / `RESW11` | |
| `177360`+ / `177440`+ | | 3 Fn / Dn | `1701` / `1711` | `RESF11` / `RESD11` | unused |
| `177460`–`177467` | `0xFF30`–`37` | 2 BY | `1721`–`1737` | `RESBY15`–`22`; `1727` = **`PLCCNBY`** | |
| `177470`–`177477` | `0xFF38`–`3F` | 2 H | `1741`–`1757` | `1747` = **`PLCCNH`** | |
| `177500`–`177507` | `0xFF40`–`47` | 2 W | `1761`–`1777` | `1761` "Rphs", `1763` "Wphs", `1765` "CAD :=", `1767` = **`PLCCN`**, `1771` = **`LOADPS`** | manual marks `1773`/`1775`/`1777` "used in AX" |
| `177510`–`177517` | `0xFF48`–`4F` | 2 F | `2001`–`2017` | `2007` = **`PLCCNF`** | `2013`/`2015`/`2017` "used in AX" |
| `177520`–`177527` | `0xFF50`–`57` | 2 D | `2021`–`2037` | `2027` = **`PLCCND`** | |

**This is the strongest evidence in the whole dispatch section**, for two reasons. The manual and the
microcode's own symbol table agree independently. And it shows what B30 *did* with the reserved slots:
the timer library (`CLINIT`/`CLREAD`/`EXINT`), the dump-dirty instruction (`DCDUMP`), the descriptor
writes (`WDUSBY`/`WDUSH`/`WDUSW`), the PLANC descriptor conversions (`PLCCN*`) and the PS-register load
(`LOADPS`) all live in what chapter 12 called free space.

**Independent triple-check.** The `ND-500-RTC-LIB` section of the ND program-description sheet names
three entries — `CLINT` (generate external interrupt), `CLRCLK` (reset RTC — *"the domain must be
privileged. If not, Illegal Instruction Code is generated"*), `RDCLK` (read RTC, 32-bit integer).
Chapter 12 puts "timer clear" at `1647` and "timer read" at `1650`. The `.LABE` has `CLINIT 001647*`
and `CLREAD 001650*`. Three unrelated sources, same pairs. [M]+[M]+[V]

**And the earlier program-description sheet (`211276C`, for A29/B29) prints nine more real opcode
numbers** [M] — every one of which our map already had right:

| Sheet's text | Opcode (octal) | Hex | Our map's entry | `.LABE` |
|---|---|---|---|---|
| `Bi Plccn <plancdesc>,<nddesc>` | `177775` | `0xFFFD` | `0o1073` | `PLCCNBI` |
| `By Plccn` | `177463` | `0xFF33` | `0o1727` | `PLCCNBY` |
| `H Plccn` | `177473` | `0xFF3B` | `0o1747` | `PLCCNH` |
| `W Plccn` | `177503` | `0xFF43` | `0o1767` | `PLCCN` |
| `F Plccn` | `177513` | `0xFF4B` | `0o2007` | `PLCCNF` |
| `D Plccn` | `177523` | `0xFF53` | `0o2027` | `PLCCND` |
| `Ncplc <nddesc>,<plancdesc>` | `177776` | `0xFFFE` | `0o1075` | `NCPLC` |
| `PS := <operand/r/w>` | `177504` | `0xFF44` | `0o1771` | `LOADPS` |
| `Ddirt` | `177036` | `0xFE1E` | `0o1645` | `DCDUMP` |

The same sheet also gives the PLANC-descriptor scaling rule [M]: `(u−l+1) → N`, `a + l*Scal → A`, with
`Scal` = 1/8 bit, 1 byte, 2 halfword, 4 word, 4 single float, 8 double float. And it specifies
`By Ssmov <source>,<destination>,<numberofbytes>` — *"When either source or destination is unaligned
or number of bytes not modulo 4, illegal operand value is set to status."*

> **One discrepancy to adjudicate.** Chapter 12 annotates entry `1765` (opcode `0o177502` = `0xFF42`)
> with "CAD :=". The `211276C` sheet says `CAD := <operand/r/w>` has **opcode `0o176672`** (`0xFDBA`),
> and our map binds `0xFDBA` → `0o1024` = `LOACAD` (`derived`), leaving `0xFF42` → `0o1765` = `RESW17`
> unnamed. Both cannot be the CAD-load opcode. Likeliest reading: chapter 12's annotation is stale — it
> describes what an *older* microprogram put in that slot — and `0o176672` is the shipped assignment.
> That is [D]. Anyone with the ND-500 Reference Manual opcode tables can close it in a minute.

### 5.6 The fetch / decode path — in the microcode, and in our engine

**In the microcode**, the instruction boundary is the `GET` (fetch-control) field. The relevant values
are `G,OOPS` (4), `G,OOPS,T` / `G,OOPS,F` (5, 6), `G,COOPS` (7) and `G,TOOPS` (14). A word carrying one
of these is the IDU instruction fetch. Usage across B30: GET=4 appears 253 times, GET=5 12, GET=6 14,
GET=7 4, GET=14 3. [V]

**The critical timing fact, and it bites everyone once** [V]:

> The terminating `G,OOPS` of instruction *N* is the **same word** that fetches and dispatches
> instruction *N+1*.

Consequences that fall straight out of it:

- The float trap latches FO/FU are deliberately **not** cleared at dispatch — the dispatching word is
  the previous instruction's last word.
- The INIT B-latch is *armed* at dispatch and committed at the top of the next tick, so a
  prefetched-but-never-executed INIT at a branch target cannot corrupt B.
- From the `NoopEntry` prologue (`Mpc = 130` = `0o202`), the **first** `Step()` only primes; it does not
  retire an instruction.

**In `CpuND5000`**, dispatch is one method, `FetchAndDispatch()`:

    uint b0 = ReadProgram(memory, Regs.P, 1);
    int opcode;
    if (b0 >= 0xFC)
    {
        opcode = (int)((b0 << 8) | ReadProgram(memory, Regs.P + 1, 1));
        Regs.P += 2;
    }
    else
    {
        opcode = (int)b0;
        Regs.P += 1;
    }

    if (!DispatchMapB30.TryLookup(opcode, out DispatchEntry entry))
    {
        throw new InvalidOperationException(
            "Opcode " + Convert.ToString(opcode, 8) + " (octal) has no entry in the reconstructed dispatch map");
    }

    Regs.InstrRin = entry.Rin;
    Regs.InstrDt  = entry.DataType;
    Regs.DirectMask  = entry.DirectMask;
    Regs.DirectSizes = entry.DirectSizes;
    Regs.OcaIndex = 0; Regs.OcaKind = 0; Regs.Op1Kind = 0;
    if ((entry.DirectMask & 1) != 0) EnsureOcaDecoded();

Any first byte at or above `0xFC` is an escape prefix, so `0xFC`–`0xFF` are never single-byte opcodes.
**A hole throws** — never a silent wrong execution.

**How `DispatchEntry` maps onto the real IC:**

| Real IMAP / IC field | Our field |
|---|---|
| entry point | `DispatchEntry.Entry` |
| **OPTYP** (float/int + width) | `DispatchEntry.DataType` → `Regs.InstrDt`, consumed by `EffectiveDataType` when the microword says `TYP,DR` |
| **RIN** | `DispatchEntry.Rin` → `Regs.InstrRin`, consumed by `ORA,IN` / `ORD,IN` / `A,ALU,REG37` |
| **ICHAR** | **not modelled.** The nearest thing is `DirectMask` / `DirectSizes`, set on 5 opcodes only — `CALL` `0xC3`, `INIT` `0xDC`, `ENTF` `0xDD`, `ENTFN` `0xDE`, `ENTM` `0xDF`, all mask `0x01`, size 4 bytes — flagging an inline direct operand. [OPEN] what else ICHAR carries. |

**There is no `JMPMAP` sequence type in this machine.** Dispatch is not a sequencer mode: an
instruction-fetch GET code *overrides* the sequencer's computed next address after the sequencing
phase. [V]

**And there are two more hardware dispatches beyond IMAP**, both in the low control store, and the
manual names both [M]:

- **The constant-mismatch branch, `0o60`–`0o77`** (the `CMIS00`–`CMIS17` vectors). IDU nanostate 3
  *"decodes the displacement part of a general operand, makes it sign-extended, and outputs it on the
  DPA-bus. This process discovers constant conversions that need to be performed by the microprogram.
  These conversions lead to a constant mismatch hardware branch (microaddresses 60B-77B)."* The vector
  is formed from four bits — `TPCMB(0:3)` at the MIC, `CMTP` at the IDU — giving 16 vectors. Only three
  are real conversions in B30 (int → single, int → double, single → double); the other 13 go to
  `ILL_OP_SPEC`. **This is the microcode's automatic constant-type-conversion path**, and it is why an
  ND-500 constant operand of the "wrong" type still works.
- **The descriptor branch, `0o44`–`0o57`.** Five bits: `EDSB` plus `TPDSB(0-3)` encoding the index
  register X1-X4, whether auto-increment is disabled, and read versus write. 12 of the 16 slots are
  used.

Both push a return address of **jump address − 1**, which is why the manual insists (§7.3.1 rule 6)
that *"instructions generating a hardware branch shall have a jump address pointing to the immediate
following instruction"*. **TRAP (`0o100`) and ENOOP (`0o101`) do not save a return address.** [M]

So the low control store `0o0`–`0o177` is not "some vectors and some code" — it is **vector space**,
four distinct hardware dispatch tables plus the ND-100 service entries, and it is worth reading it that
way.

### 5.7 Where the reconstruction is thin — with numbers

**(a) Unmapped opcodes.** [V]

| Space | Mapped | Unmapped |
|---|---:|---:|
| single byte `0x00`–`0xFB` | 231 | **21** |
| page `0xFC` | 243 | 13 |
| page `0xFD` | 242 | 14 |
| page `0xFE` | 237 | 19 |
| page `0xFF` | 226 | 30 |
| **total** | **1179 distinct opcodes** (1183 rows; 4 opcodes appear twice with identical values) | **97** |

Single-byte holes, octal: `000 001 273 342 343 354 355 356 357 360 361 362 363 364 365 366 367 370 371
372 373` — that is `0x00`, `0x01`, `0xBB`, `0xE2`, `0xE3`, and the run `0xEC`–`0xFB`.

Two-byte holes worth naming:

- `0xFEB2`, `0xFEB6`–`0xFEBF` — octal `177262`, `177266`, `177270`–`177277`: the **packed-decimal /
  packed-conversion block** (`PSHIFT`, `PUPACK`, `PUPACKR`, `PWCONV`, `WPCONV`). These have no clean
  `.LABE` name. Candidate unassigned BCD slots `0o2053` / `0o2055` (`SHTBCD` / `SHTBCDR`) exist, but
  binding them would be a guess, so they were left out. Several are absent from the nd500x opcode table
  as well, which hints some are genuinely reserved rather than merely unmapped. [OPEN]
- `0xFFD8`–`0xFFE7` — the SMOVE region. `SSMOV` @`0o1200` and `SMOVEBI`…`SMOVED` @`0o1235`–`0o1245`
  exist as labels with **no opcode row**.
- `0xFD41`–`0xFD43` — the `TSET` siblings; `0xFD8C`–`0xFD8F` and `0xFDA4`–`0xFDA7` — SFILL blocks.
- `0xFFB0`–`0xFFBB` — the block before `AMODB`.

**(b) The 28 orphan entries — the sharpest single number in this document.** [V]

These are addresses in `0o200`–`0o3011` that carry a label, are **never jumped to by any named jump in
the microcode**, and have **no opcode in our map**. They are instruction entry points the hardware must
be able to reach and we cannot:

| Address | Label | | Address | Label |
|---|---|---|---|---|
| `0o1065` | `GETINF` | | `0o2105` | `FLOOPB` |
| `0o1146` | `STORCES` | | `0o2111` | `FLOOPH` |
| `0o1150` | `STORCAS` | | `0o2115` | `DLOOPB` |
| `0o1154` | `LOAMOD` | | `0o2122` | `DLOOPH` |
| `0o1156` | `STORMOD` | | `0o2143` | `COMPF` |
| `0o1200` | `SSMOV` | | `0o2155` | `COMP2F` |
| `0o2041` | `LOATSP` | | `0o2161` | `COMP2D` |
| `0o2053` | `SHTBCD` | | `0o2542` | `IMODBY` |
| `0o2055` | `SHTBCDR` | | `0o2545` | `IMODH` |
| `0o2071` | `UNPACK` | | `0o2550` | `IMODW` |
| `0o2073` | `UNPACKR` | | `0o2575` | `INCRF` |
| `0o2075` | `BINC` | | `0o2577` | `INCRD` |
| `0o2077` | `BCDC` | | `0o2602` | `DECRF` |
| | | | `0o2604` | `DECRD` |
| | | | `0o3010` | `PLCCNDD` |

`IMODW` @`0o2550` is the one that has already caused confusion: MODULO is reachable in principle but
has no opcode in our map, which is why "the integer DIVIDE keeps no remainder" kept being re-argued.
`COMPF` / `COMP2F` / `COMP2D` are float compares with no opcode. `SSMOV` is fully specified in the
`211276C` sheet and still has no opcode row.

**(c) A structural check that passed.** Of the 495 distinct entry addresses our map uses, **all 495
are never-referenced labels** — every address we claim hardware jumps to is an address nothing in the
microcode jumps to. That is exactly the shape the reconstruction should have. It is weak confirmation,
but it is real: we are not pointing opcodes into the middle of routines. [V]

Caveat on the same statistic: "never referenced" is **not** the same as "IMAP entry". A computed jump
(`JMPREL` into a table) leaves no symbolic reference, so the 279 never-referenced labels *above*
`0o3011` are mostly jump-table targets (`BFW_00`–`BFW_37`, `PUTBF_T20`–`T37`, `READ_S1_*`), not
instruction entries.

**(d) Where the divergences are** (2026-08-18 baseline, nd500x conformance corpus): `0xE8` ×16 double
divide last digit; `0x7C` ×12 float divide 1 ULP; `0xFDA0` ×8 and `0xFD9C` ×4 Sfilln; the
transcendental family `0xFF5C`–`0xFFA4` ×4 each at 1 ULP; `0xFC2C` ×4 Div4;
`0x24`/`0x28`/`0x45`/`0x46` signed-zero flags; `0xFE74` ×2 `wconr` sign; `0xFD53` ×1 `biconv`.

**(e) The permanent, deliberate divergence.** BI `HCONV` of a register source: the microword gives 1,
the functional core gives 0. This is **not** being "fixed", and the reason is the project's whole
philosophy in one paragraph: `HCONVBI` @`0o1536` → `0o1541` → `CONV_TO_RBI` @`0o3172` tests the **whole
halfword**, not the isolated bit. Forcing the microword to 0 would make the silicon oracle lie about
the hardware in order to agree with a manual. Owner-confirmed 2026-07-28.

### 5.8 The per-opcode tables

Full tables: [Appendix A](#appendix-a--single-byte-opcodes) (230 single-byte rows) and
[Appendix B](#appendix-b--two-byte-opcodes) (948 two-byte rows). Column meanings:

- **entry** is **octal**. The JSON and the generated C# store it as *decimal of the octal address* —
  entry `130` is `0o202`. Convert before comparing anything.
- **label** is the `.LABE` name at that address, so the routine can be looked up.
- **rin** = register-in-instruction 0-3, `-` if none. **dt** = W/F/H/BY/BI/D, `?` if unknown.
- **grade**: `M-ch12` = chapter-12 anchor, [M]+[V]. `D-labe` = direct label-name match, [D].
  `D-conv` = naming-convention derivation, [D]. `D-3src` = three-source verified 2026-08-23, [D]
  measured. `D-func` = bound against the functional decoder plus a named microcode entry, [D].
  `D-ndix` = layout-derived duplicate, [D]. `?` = a long narrated one-off justification, argued
  individually in the generated file's trailing comment.

Grade totals across the 1178 machine-countable rows [V]: `D-labe` 631, `D-conv` 328, **`M-ch12` 130**,
`D-3src` 45, `?` 24, `D-func` 16, `D-ndix` 4. (The generated file has 1183 assignment lines; five carry
the 5-argument `DirectMask` form and are counted separately by the tooling.)

---

## 6. The sequencer, EXUC and the pipeline

Grade: **[M]** for the rules (ND-05.022.1 chapter 7 prints them), **[V]** for how the microcode
actually behaves, and one place where the two disagree.

### 6.1 The stack — four words, and RETURN does not pop

ND-05.022.1 §7.1 [M]:

> The microprogram stack may hold a maximum of four different addresses. The top word of this stack may
> be selected as input to the microprogram address counter (m.p.c) by the sequence command RETURN.
>
> An important restriction in the microprogram sequencer is that the sequencer stack is not stable
> before the microinstruction following a load of sequencer stack is executed. This implies that the
> sequencer stack cannot be used as address input immediately after being loaded. **Hence, a one cycle
> microinstruction subroutine is not possible.**

| Command | Function [M] |
|---|---|
| `HOLD` | Leave stack unchanged. |
| `LOAD` | Word 1 becomes current microaddress + 1. Rest unchanged. |
| `PUSH` | Word 4 is lost; 3→4, 2→3, 1→2; current address + 1 → word 1. |
| `POP` | Word 1 may be used as return address. 2→1, 3→2, 4→3, **4→4** (word 4 duplicates itself). |

§7.3.1 rule 5 [M]: *"Since the sequence control and the stack control are separated, the RETURN
instruction does not POP the stack. It only uses the top of stack as the next address to the control
store."*

Our implementation matches, and reads the return address **before** applying this word's own stack op,
which is what preserves the `RETURN, POP` unwind idiom (the address is the pre-pop top). [V]

The "stack not stable for one cycle" restriction is **not modelled** — it is a constraint on the
microprogrammer, not a behaviour, so an always-stable stack is safe for an emulator. [D, argued in
`TICK-MODEL.md`]

### 6.2 The four sequence commands

ND-05.022.1 §7.2 [M]: `NEXT`, `JMP`, `JMPREL`, `RETURN`. Both a TRUE and a FALSE command exist in every
word; the FALSE ones are written `F,<seq>`.

Encodings as implemented [V]: type `0 = JMP`, `1 = JMPREL`, `2 = RETURN`, `3 = NEXT`; stack
`0 = HOLD`, `1 = POP`, `2 = LOAD`, `3 = PUSH`.

    case TypeJmp:    return word.AbsAddr;
    case TypeJmpRel: return (ushort)((word.AbsAddr + vector) & 16383);
    case TypeReturn: return returnAddress;
    default:         return (ushort)((state.Mpc + 1) & 16383);

All targets are masked to 14 bits.

**`JMPREL` is vector-relative, and the vector is 8 bits.** ND-05.020.01 page 211 [M]:

> The 8-bit vector register is used to calculate the microaddress when a JMPREL instruction is given. A
> new address is generated by adding the vector to the lower half of the current address and extending
> the carry from bit 7.

That 8-bit width is why the async-trap table at `0o16623` is exactly 256 entries. Our engine supplies
one vector source, `MIC,VECT`; every `JMPREL` we have traced — the 64-entry MICFU table at `0o15224`,
the 64-entry kick table at `0o16430`, the 256-entry async-trap table — uses it. Whether other sources
exist is [OPEN].

> **A manual-versus-manual conflict here.** Table 24 and §8.3 say `CSA <= CI(16:31)+VECT` — **jump
> address** plus vector. Pages 211 and 215 say **current address** plus vector. We implement jump
> address + vector and every traced table is consistent with that. See §15.4 item 4.

**There is also a fifth next-address source the mnemonic list omits: the *previous* address.** [M,
:7489] `EPREV` re-enables the previous microaddress onto the CSA bus, and :7174 explains *"the
decremented value of CUR, called DJP, is used directly as a new CSA value to force the previous
instruction to be repeated."* We do not model it; nothing we run appears to use it. [OPEN]

**Cycle costs, from the manual's own matrix** [M, ND-05.020.01 Table 26 page 222] — the "saved address"
column is what the MIC keeps in case the guess was wrong:

| TSEQ | FSEQ | cycles | next CSA | saved address |
|---|---|---:|---|---|
| JMP | NEXT / RETURN / JMPREL | **1** | jump address | current+1 / top of stack / jump+vector |
| NEXT | JMP / RETURN / JMPREL | **2** | current+1 | jump address / top of stack / jump+vector |
| RETURN | JMP / NEXT / JMPREL | **2** | top of stack | jump address / current+1 / jump+vector |
| JMPREL | JMP / NEXT / RETURN | **2** | jump+vector | jump address / current+1 / top of stack |

i.e. **only a TRUE-field JMP runs in one cycle** — which is the whole reason §7.3.1 rule 2 tells the
microprogrammer to put a JMP in the TRUE field and use INVSEQ to make that possible.

**Path selection.** §7.2 [M]:

> In connection with conditional sequence, the true path is selected as a preliminary route by the
> microprogram sequencer. Hence the true sequence command should be a jump instruction. To make it
> always possible to place a jump in the true sequence field, a control store bit may be used to invert
> test condition. This is done by the INVSEQ command.

Implemented as `takeTrue = condition ^ (word.InvSeq != 0)`, with **only the chosen path's stack op
applied** (§7.3.5 rule 3). [V]

§7.3.1's other rules worth having in one place [M]:

1. TRUE is the main instruction, FALSE the alternative; TRUE is also the unconditional path.
2. **JUMP takes one clock cycle, everything else takes two.** Use JUMP where possible.
3. A specific preliminary route can be forced by matching TRUE and FALSE with the INVSEQ bit.
4. A test at the end of a macro-instruction routine must put the error action in the FALSE field and a
   JUMP in the TRUE field.
5. RETURN does not POP.
6. Instructions generating a hardware branch must have a jump address pointing at the immediately
   following instruction.

And two operational rules that explain shapes you will see everywhere in the listing [M, §7.2]:

> When accessing operands, these may be prefixed by an address code causing mapping to special
> microprogram routines to handle the address code prefix. Because of the microcode pipeline, the
> microprogram sequencer is using the jump address to find the way back to the trapped microinstruction.
> This means that **a read/write/laddr cycle of a general operand always has to use `JMP *+1` as
> sequencer command.**

> In connection with the mapping to the start of the next assembly instruction, both the true and false
> sequence field must contain a jump command. The true sequence field must follow the mapping while the
> false sequence field may be used to stop execution e.g. in connection with reporting an error detected
> at the end of an instruction.

That second one is the manual describing the `G,OOPS` dispatch from the sequencer's side.

### 6.3 MIC / SRF write latency

§7.3.3 [M]:

> Read from MIC/SRF is done directly, while writing is pipelined two levels. After a write, there must
> be two dummy cycles before the same data can be read back. Reading in the first cycle gives old data.
> Reading in the second cycle results in a collision on the X-bus.

### 6.4 EXUC — the sneak cycle

§7.3.4 [M], quoted in full because every word of it matters:

> Bit number 115 in the microword is called EXUC (execute unconditional). **When the sequence
> instructions NEXT, RETURN or JMPREL are executed, an extra (sneak) cycle is entered into the pipeline
> on the I-level prior to the 'real' instruction.** This extra cycle is stopped on the I-level unless
> the EXUC facility is used. If the extra cycle is going to be executed, the EXUC bit in the previous
> microinstruction must be set TRUE. **Both stack and sequence instructions in the extra cycle are then
> ignored.**

**Which word is the sneak?** It is **the word at the current word's `ABS_ADDR`** — the sequencer's jump
guess — not word N+1. Proof by dataflow [V]: B30 `CPU_READ` at `0o17130` / `0o17134` is
`NEXT + EXUC + ADDR=CPUMODEL`; the constant word at `CPUMODEL` executes as the sneak and its own DEST
writes its constant into SC4, which `0o17135` then reads. That is the trick the whole float constant
pool at `0o20014`–`0o20342` is built on: those 215 words are *data* fetched by being executed as sneak
cycles.

345 words in B30 set EXUC. [V]

Our firing rule [V]:

    bool takeTrue = word.CondSeq == 0 || (condition ^ (word.InvSeq != 0));
    int chosenType = ChosenSequenceType(in word, condition);
    bool sneakRuns = (word.CondSeq != 0 && !takeTrue) || chosenType != Sequencer.TypeJmp;

i.e. always for NEXT / RETURN / JMPREL, and for a conditional word **only when the pipeline actually
breaks** (the false path was taken). Calibrated against `SHIFT_ROT` @`0o17070`
(`EXUC + Q*ROT + LCDECR + C,SEQ` jumping to itself): the spin must rotate once per pass and the sneak
must fire once, on loop exit. Executing the sneak on every pass double-decrements LC past zero and
hangs.

Two further sneak details that are easy to get wrong [V]:

- A sneak word's own `CSAVE` **does** shift the saved-condition pair (proved by the `ASIND` |x|=1 exit
  at `0o20170` / `0o26337`), and its `C,ALU` reads the ALU half of a split condition.
- `ExecuteBody` therefore runs **twice** in one tick, and **both runs report the same `Mpc`**. A
  register write can appear to come from a word whose `DEST` is `NONE`. Always check `EXUC` on the
  fetched word before attributing a microword write to an address.

### 6.5 EXCYC2 — the manual rule our engine deliberately breaks

§7.3.5 [M], in full:

> The construction of the pipeline system makes it necessary to run two microinstructions after a
> conditional sequence has entered the pipeline, until the condition is valid. These two instructions
> are called EXCYC1 and EXCYC2. They enter the I-level, and are normally stopped there, but by using
> EXUC, they can be carried out as ordinary instructions. The rules for using EXUC in this case are:
>
> 1. If EXUC is TRUE in the conditional sequence instruction, the EXCYC1 is executed at all pipeline
>    levels.
> 2. If EXUC is TRUE in the conditional sequence instruction and EXUC is TRUE in the EXCYC1, the EXCYC2
>    is executed at all pipeline levels.
> 3. Stack control is influenced by the EXUC. This means that if conditional break does not occur, the
>    stack is controlled as specified. If a conditional break occurs, the stack is not changed.
>
> EXUC works with the microinstruction controller through the clock enable signals.

**Contradiction 1 — rule 1 vs §7.2 and §7.3.4.**

- §7.3.4 says the sneak exists "when the sequence instructions **NEXT, RETURN or JMPREL** are
  executed" — i.e. *not* for JMP.
- §7.2 says: *"If any sequence command different from jump is used, the microprogram sequencer has to
  run one extra sequencer cycle… **If the guess was true, the address is present and the jump is
  carried out in one cycle.**"* — i.e. a correct jump guess costs no extra cycle.
- §7.3.5 rule 1 says the EXCYC1 is executed whenever EXUC is set on a conditional sequence
  instruction, with **no exception for the case where the TRUE-field JMP was taken**.

Our engine follows §7.2 / §7.3.4: no sneak when a conditional word's TRUE-field JMP is taken. A literal
reading of rule 1 would fire one on every conditional EXUC word. **The manual cannot be right both
ways, and the microcode's behaviour is what we calibrated against.** [OPEN] — see §15.

**Contradiction 2 — rule 2 doubles the integer quotient.**

We implement EXCYC2 and then suppress it in one specific shape. The code and its comment [V]:

    // EXCYC2 (7.3.5 rule 2): "If EXUC is TRUE in the conditional sequence instruction and EXUC is
    // TRUE in the EXCYC1, the EXCYC2 is executed at all pipeline levels." The second prefetched word
    // is EXCYC1's own predicted target ...
    //
    // SCOPE - the LOOP-BODY exception [D, measured 2026-08-03]: EXCYC2 is SUPPRESSED when it would
    // re-execute the breaking word itself (sneak1's predicted target == the conditional word's own
    // address) - the LOOP-EXIT shape ... Executing that second copy runs one loop pass too many: the
    // integer divide's quotient DOUBLES (DivWord_SignMatrix expected 6, got 13 when it was tried).
    // FORWARD chains do want it - @024444's fall-through break must run BOTH @024500 and @024501 ...
    // KNOWN COST [OPEN]: DIV_64's loop 2 would NEED one extra append (its 32nd low-quotient bit) for
    // a fully 55-bit-exact low mantissa word on non-terminating quotients ... No uniform rule found
    // that gives loop 2 its 32nd bit without doubling the integer quotient - needs a third source on
    // 7.3.5 rule 2 / the LC pipeline.

    if (word.CondSeq != 0 && sneak.Exuc != 0)
    {
        SneakSecondCycleOpportunityCount++;
        int sneak2Address = sneak.AbsAddr & 16383;
        if (sneak2Address != State.Mpc)          // the loop-body suppression
        { ... ExecuteBody(in sneak2, ...); SneakSecondCycleExecutedCount++; }
    }

Three public counters (`SneakFiredCount`, `SneakSecondCycleOpportunityCount`,
`SneakSecondCycleExecutedCount`) exist so the gap is a number rather than silence. A static sweep found
**47 EXCYC2 sites in each of A30 and B30**. The measured cost of the suppression is that DIV_64's low
mantissa word carries roughly a 2^-24 relative error on non-terminating quotients. [V]

An independent measurement recorded on the message-processing side puts the live rate at **three
suppressed second-sneak hits per cold boot**.

**Contradiction 3 — does the sneak's stack operation happen at all?** The Guide says it is ignored; the
Hardware Description says it is carried out. That one is set out in full, with both quotations and the
HW-desc's extra qualifier clauses, in **§15.4 item 2** — and it is the reason the sneak/stack
interaction is on the unknowns list (§16 item 6).

The Hardware Description's own version of §7.3.5 (its §8.7.1) is quoted in §15.4 as well. It agrees
with the Guide on rules 1 and 2, adds **"EXUC = TRUE only in EXCYC1 is not legal"**, and adds two
qualifiers on the stack behaviour that read as if the author knew a finer rule than either document
states.

### 6.6 The one-word condition delay

**This is the single most important pipeline rule in the machine.** [V]

> The test condition on word *N* reads the flags left by word *N−1*'s ALU.

Proof: `0o16373` spins on `COND,MZRO` produced by `0o16372`'s `AND AFLAG,SC13`, while its own ALU is
the ubiquitous `XOR BM00,X1` filler word — a word that exists purely to time the delay. That filler
word appears all over the listing and now has an explanation.

Read the microcode without this rule and **every dispatch comes out shifted by one bit and still looks
entirely plausible**. The AFLAG bit map was wrong in exactly that way until the rule was applied.

The condition is evaluated at the *start* of the tick, before `ExecuteBody`, and only when needed
(`CondSeq`, `CondAlu`, `CSave`, or a conditional-fetch GET).

**The pre-sneak shield.** A word following an EXUC sneak must test the flags as they were *before* the
sneak's ALU. Implemented as a swap-evaluate-swap around the condition evaluation, shielding
`MZro, MSgn, MSgnRaw, MCry, MOvfl`. Proved by the shared divide-core exit: the loop break at `0o24145`
sneak-executes the prefetched companion `0o24144`, and `0o24146`'s `COND,MSGN` restore decision must
still see the *last divide step's* remainder sign. Only the CONDITION sample is shielded — the sneak's
`MCry` / `M31` stay live for ALU-to-ALU chaining. [V]

### 6.7 The other pipeline latches

All [V], all calibrated against a named routine that breaks without them:

| Latch | What it delays | Calibration site |
|---|---|---|
| `_dpaForEa` | `AA,DISP` address arithmetic reads the **previous** word's DPA | RESIWR `0o15542`-`43`: a word that writes `D,DAC,DPA` and EA-saves from `AA=2` in the same word must see the prior DPA, else source and destination block pointers collapse to one address |
| `_x1ForEa` … `_x4ForEa` | same one-word delay for `AB,IX1`–`IX4` | `MB_CALC_ADDR` `0o6031`-`32` (reverse block copy) |
| `LcLoadPipe[3]` | **LC load latency = 3 microwords.** `D,LC` enters the pipe; the oldest stage commits at the top of each tick | `getbf`'s `GET_BIT_F` loop: the `D,LC` at `0o3355` must stay invisible through `0o3356` and `0o3437` but be visible at `0o3441` |
| `LcDecrPrevWord` | `A,BMLC` returns `1 << ((Lc + LcDecrPrevWord) & 31)` | SQRTF restore step `0o20414` / `0o20417` |
| `_dacPlus4Pending` / `_ocaPlus4Pending` | the `AB,ADR+4` second DAC request arrives next cycle | ND-05.022.1:1440 (quoted in §9) |
| `_aapImulPending` | AAP integer-multiply F-bus delivery is one word late | DIVF `0o24242`, EXPF `0o25703`, EXPD `0o25730` |
| `_initBLatchArmed` | INIT's B write is armed at dispatch, committed next tick | prefetched-but-not-executed INIT at a branch target |
| `Regs.DivM31` | the divide serial input, "MSB of F latched into a 1-bit register" [M, ND-05.020.01:8381] | the divide step |

`LCDECR` itself is **immediate**; a later-committing LC load overwrites it ("end-of-F load wins over
begin-of-F decrement", ND-05.022.1 §9.14). Two exceptions were forced by real routines: `COND,LCZ` and
the sequencer half of `COND,AQSLZ` peek the newest pipe stage (DIV_64 `0o24411` needs it), and a
**straight-line** `LCDECR` over a pending load composes into the pipeline stages — guarded by
`QReg != 2` so divide-step words keep the lost-decrement behaviour DIV_64 depends on. That guard is the
cos(0.5) / `INTRF_U` fix (commit 67c166c6d).

---

## 7. The register model

Grade: **[V]** throughout — this is the part the emulator exercises hardest.

### 7.1 WRF — 24 working registers, in *encoding* order

`Regs.Wrf[24]` is indexed in **A/B-operand encoding order**, which is not the architectural order:

| idx | 0-3 | 4-7 | 8-11 | 12-15 | 16-19 | 20-23 |
|---|---|---|---|---|---|---|
| name | X1-X4 | A1-A4 | SC1-SC4 | E1-E4 | SC5, SC6, SC7, SC10 | SC11-SC14 |

So `X1 = Wrf[0]`, `A2 = Wrf[5]`, `SC1 = Wrf[8]`, `SC4 = Wrf[11]`, `E4 = Wrf[15]`, `SC7 = Wrf[18]`,
`SC10 = Wrf[19]`. The ND-500 architecture calls the X registers **I1-I4**.

**Bank convention, engine-wide since 2026-08-09: A = HIGH 32 bits, E = LOW 32 bits of a double.**
Integer OR-bank base 0, single-float 4, double A-half 4 / E-half 12.

### 7.2 SRF — 4096 scratch words

`Regs.Srf[4096]`. The size is [V]: the boot routine `INIT_SRF` walks from exactly `(1<<12)−1 = 4095`.

Addressed two ways: **directly** as SRF0-SRF17 (octal — cells 0-15), or **indirectly** through `Rfa1` /
`Rfa2`, with post-decrement variants `RF1D` / `RF2D`.

Named cells that matter:

- `SRF11` — current process; sign bit set means "no runnable process".
- `SRF14` — current domain (CED), seeded into `CED_TO_DIT`.
- `SRF17` — the PCB index used by `CNTXTLOAD`: **PCB base = SRF17 × 256 + 0x800**. Whether
  `SRF17 = X5CPU + 1` or `SRF17 = N5STA + 1` is **[OPEN]** — two project documents claim different
  things and the microword at `0o15211` is the place to settle it.
- `0o2000`–`0o2025` — the mailbox communication block. Full layout in §11.

Scratch conventions used consistently by the message path [D]: `SC14` = zero register, `SC12` = message
address / ACCP command staging, `SC10` = the answer status written into `N5STA` (3 or 4),
`SC3`/`SC4`/`SC5`/`SC7`/`SC11` = parameters and temporaries, `LC` = copy loop counter, `Q` = the
byte/halfword remainder shift, `MIC,VECT` = the dispatch vector consumed by `JMPREL`.

### 7.3 Status — two separate sets, and why there are three extra micro flags

| micro-status (updated by every ALU op) | main status (latched only by `ST,SAV*`) |
|---|---|
| `MZro`, `MSgn`, `MCry`, `MOvfl` | `Zro`, `Sgn`, `Cry`, `Ovfl`, `K`, `SavedCond1/2` |
| plus `MSgnRaw`, `MOvflWidth`, `MCryWidth` | |

The main status is the macro-visible one. The ND-500 ST1 bit layout, confirmed three ways (nd500x
`instruction_helpers.h`, NDIX-C `trap.h`, and our own code): **PIA = 1, PD = 2, M/IR = 3, T/PSD = 4,
Z = 5, C = 6, S = 7, K = 8, O = 9.** [V]

**And the manual gives the whole 64-bit macrostatus** — ND-05.020.01 Table 6, §4.3 page 86 [M], which
matches those nine bits exactly and supplies the rest:

| ST1 | | ST1 | | ST2 | |
|---|---|---|---|---|---|
| 0 | MPF | 16 | IOV | 32 | XSE |
| **1** | **PIA** | 17 | SIT | 33 | IIC |
| **2** | **PD** | 18 | BT | 34 | IOS |
| **3** | **IR** | 19 | CT | 35 | ISE |
| **4** | **PSD** | 20 | BPT | 36 | PV |
| **5** | **Z** | 21 | ATF | 37 | THM |
| **6** | **C** | 22 | ATR | 38 | PGF |
| **7** | **S** | 23 | ATW | 39 | PWF |
| **8** | **K** | 24 | AZ | 40 | PRF |
| **9** | **O** | 25 | DR | 41 | HWF |
| 10 | INR | 26 | IX | 48 | INRS |
| 11 | IVO | 27 | STO | 49 | IVOS |
| 12 | DZ | 28 | STU | 50 | DZS |
| 13 | FU | 29 | PRT | 51 | FUS |
| 14 | FO | 30 | DT | 52 | FOS |
| 15 | BO | 31 | DE | | |

Three things in there matter for the float work:

- Bits 10-15 (`INR`, `IVO`, `DZ`, `FU`, `FO`, `BO`) are the **trapping** arithmetic conditions, and the
  manual says of FO and FU that each *"is set by the hardware **or microprogram**"*, and of DZ that it
  is *"set by the microprogram"*. So a missing FO/FU on a MULAD path is a **microcode** question, not a
  hardware one.
- Bits 48-52 (`INRS`, `IVOS`, `DZS`, `FUS`, `FOS`) are a **separate sticky set**: each *"is included to
  conform to the IEEE floating-point standard. It is a status bit of the same type as Z, C and S, and
  **cannot give traps**."* Two parallel float-flag sets, easy to conflate.
- Bit 9 `O` *"indicates integer overflow only"* — it is not a float overflow bit.

And note bits **37 THM** and **38 PGF** *"do not have an actual bit in the status register, because it
would always be zero when tested"* [M]. **Do not model page fault as a settable, testable flag.**

The three extra micro flags exist because *width matters differently to an internal loop than to the
macro-visible status* — and each was forced by a measurement:

- **`MSgnRaw`** — the raw pre-mask bit 31, the FBUS(31) signal. Read by the `BYCONV` island at
  `0o1535` only. Making it global blew the conformance sweep from 154 to 613 divergences. There is an
  explicit wrong-turn marker in the source: *"WRONG TURN (2026-08-08, do not repeat)"*.
- **`MOvflWidth`** — overflow at the DATATYPE sign bit (7/15/31). Consumed **only** by `ST,SAVC` and
  `ST,SAVA` / `ST,ACCA`. `MOvfl` stays 32-bit because internal `COND,MOVFL` loops depend on it;
  narrowing it globally breaks byte/half loop termination and hangs.
- **`MCryWidth`** — carry out of the DATATYPE top bit. Consumed by `ST,SAVA` / `ST,ACCA` only; using it
  in `ST,SAVC` broke COMP-BI plus 40 vectors.

Divide-specific: `DivStepSign` (the adder MSB before the `*2` shift) and `DivM31`.

Float trap latches `Fo` and `Fu` are **sticky per macro instruction** and deliberately not cleared at
dispatch — see §6.6 for why that is forced by the fetch timing.

### 7.4 P versus P1 — a trap PC is not the faulting instruction

**There are two program registers.** [V] + [M]

`P` is the **restart** address and runs *ahead* of the fault, because the fetch advances it (and decodes
the operands) before the instruction executes. **`P1` is the trapping P — the instruction that actually
failed.**

ND-05.017.01 chapter 6 STEP 2 is ND's own diagnostic procedure [M]:

    N500: ATTACH-PROCESS 0
    N500: LOOK-AT-REGISTER P
    P  : XXXXXXXXXX
    P1 : XXXXXXXXXX:<Failing instruction>

ND annotate **`P1`** as the failing instruction. The whole of STEP 2 exists because the address printed
in a trap report (`P`) does not identify the instruction. The same pair appears in the context block as
"Trapping P register" / "Restart P register" (Appendix A.1, registers 0 and 1).

On the hardware side this is the IAC's **SP** register (§5.1). Measured gap in the 5SWAP case: 6 bytes,
3 instructions (`P` = `0o1000010533`, the faulting `RPHS` at `0o1000010525`).

**Consequence when reading any ND-500 trap: if the reported address is not on an instruction boundary,
that is expected, not a disassembly defect.** Identifying that by hand once cost days.

**Careful with the name, though.** "P1" is **ND-500-manual vocabulary (ND-05.017.01), not ND-5000
microprogram vocabulary.** Neither the Microprogram Guide nor the Hardware Description contains the
token `P1` anywhere. What the ND-5000 hardware actually has is **three** program counters, one per
pipeline level [M, ND-05.020.01 page 33]:

> - The Program Counter (PC, or the P-register) that points to the start of the macroinstruction
>   currently executed by the **A-level** of the execution pipeline.
> - The Saved P-register (SP) that points to the start of the macroinstruction currently executed by
>   the **F-level**.
> - The New Program Counter (NPC) that points to the start of the macroinstruction currently executed
>   by the **M-level**. **NPC points to each operand in turn, when multioperand macroinstructions are
>   executed. PC or SP only point to beginnings of macroinstructions.**

They shift under microcode control: `D,IAC,CKNPC` does `LA → NPC/ILAR`, `D,IAC,CKP` does `NPC → P`,
`D,IAC,CKSP` does `P → SP`. So the architectural "P1" maps onto **SP** (or, mid-instruction, NPC) —
**pick by pipeline level, not by name.** [D] for the mapping; the manuals never make the connection
because they never use the name P1.

> **Implementation note and a live gap.** `P1` is implemented in the *functional* `CpuND500`
> (`Registers.cs`, latched at the top of `RaiseTrap`) and in nd500x. It is **not** present in the
> microword `CpuND5000` — a grep for `P1` in `src\` finds nothing; the engine keeps `P` and `Npc` only,
> and does not model `SP` at all. [V]

### 7.5 The rest of the register file

| Register | Role |
|---|---|
| `Npc` | instruction start address, set at each fetch |
| `L` | link |
| `Sp`, `Y`, `S`, `Ilar` | IAC latches |
| `B`, `R` | DAC base / record. **`B` is written only through DEST 228 (`D,DAC,REG04`)** — verified the sole B writer in the whole B30 image, 8 words. `D,DAC,B` (226) and `D,DAC,SUMB` (227) are never used. |
| `Ea[0..3]` | effective-address registers. **Every ADACT drives EA0**; `EAnSAVE` additionally latches EAn |
| `LatchedEa` | the DAC address-output latch consumed by the *next* memory op; readable as `A,DAC,XFER`, `A,SPEC,DACR`, `A,DMM,PHYS` |
| `Dpa` | data-pointer; doubles as the direct-literal scratch for INIT/ENTM operand 0 |
| `Lc`, `Ixc`, `Q` | loop counter (with its 3-deep load pipe), index counter, Q register |
| `Pababm` | the bit-mask generator's 5-bit bit number for `A,PXBM` |
| DAC latches | `Dlar`, `DacReg04` (mirrors B), `DacReg05`, `DacLdres` (commits to **R**) |
| IDU latches | `IduSts` (trap number in the low byte, where `TRAP_SAM` reads it), `IduTe`, `IduLl`, `IduHl`, `IduLimc` — plain registers, **no stack-limit checking modelled** |
| MIC latches | `MicVect` (the `JMPREL` source), `MicTe`, `MicSts` (= macro ST1; **PIA is bit 1**), `MicCnt32` (free-running counter), `MicMists`, `Rfa1`, `Rfa2` |
| ALU latches | `AluSts`, `AluTe` |
| SPEC | `Mod`, `TrParm`, `TrpClr`, `La` + `LaValid` |
| IMEM | `Irl` (instruction read latch — `A,IMM,MEM` reads guest memory at `IMM,LA` and latches here; `A,SPEC,IRL` reads it back), `Mib` (**`D,SPEC,MIB`, DEST 40, is what COMMITS an instruction-memory write** — the preceding `D,IMM,MEM` is only an arming strobe) |

**`A,SPEC,LA` tracks the live fetch pointer — it is not a dead latch.** [V, 2026-08-08, commit
51d34bdab] During an instruction's body the IDU look-ahead has already consumed the whole instruction,
so LA is the *next* instruction's address. The model: `A,SPEC,LA` returns live `Regs.P` unless an
explicit `LOADLA` / `D,SPEC,LA` load is in effect (`LaValid`, cleared at every dispatch).

The register-block worker relies on it: `LREGBL`'s mask-clear path deliberately falls through `0o11421`
into `LOAD_NEW_P` `0o11534` (`P := SC13`), which is harmless *only* because the prologue at `0o11376`
preloaded `SC13 := A,SPEC,LA` = the continuation P. This also settled the "call-skip" question: a
conditional word's false path is plain +1; a +2 skip-the-continuation sequencer change measured
+28 match / +4 diverge and is **wrong** — the continuation word is meant to execute.

---

## 8. ALU, conditions and status

Grade: **[M]** for the ALU and Q-register encodings — ND-05.020.01 **Table 31 §9.4 page 248** prints all
16 ALU codes and **Table 33 §9.8 page 252** prints all 8 Q codes, and both match our decode exactly.
**[V]** for behaviour. The condition-code *numbers* are **[D]** (from the lost field chart, §15.2),
though the manual's own consistency checks pass.

A structural point the Guide hides and the Hardware Description states plainly: **there are only 12 ALU
operations plus a 3-mode shift multiplexer** (:8209 *"The ALU is able to do 12 operations"*). The
mnemonic explosion in Appendix A comes from *composing* a base operation with a carry select —
`ALU,A-B` is base `A−B` + `CRY,ONE`, `ALU,A-B-1` is the same base with carry 0, `ALU,A-B-1+C` the same
base with `CRY,C`, and `ALU,A+1` is `ALU,A` + `CRY,ONE`. Reading the field as one 6-bit blob rather than
op+carry is what makes the mnemonic table look arbitrary.

### 8.1 ALU functions — all 16 implemented

| code | mnemonic | what it does |
|---|---|---|
| 0 | `ALU,FZRO` | force zero |
| 1 | `ALU,ADIRC` / `ALU,ADRC` | `~a` (ALU output complemented) |
| 2 | `ALU,AND` | `a & b` |
| 3 | `ALU,ANDCB` | `a & ~b` |
| 4 | `ALU,A` | `Add(a, 0, carryIn)` — so `CRY,ONE` gives A+1 |
| 5 | `ALU,XOR` | `a ^ b` |
| 6 | `ALU,ANDCA` | `~a & b` |
| 7 | `ALU,OR` | `a \| b` |
| 8 | `ALU,A-1` | `Add(a, 0xFFFFFFFF, carryIn)` |
| 9 | `ALU,A,/2` | `(a >> 1) \| (carryIn << 31)`; carry out = `a & 1` |
| 10 | `ALU,A-B` | `Add(a, ~b, carryIn)` |
| 11 | `ALU,A-B,*2` | as 10, latch `DivStepSign` = pre-shift bit 31, then `<<1` |
| 12 | `ALU,A+B,/2` | `Add(a,b,cin)` then `(r>>1) \| (carryOut<<31)` |
| 13 | `ALU,A+B` | `Add(a, b, carryIn)` |
| 14 | `ALU,B-A` | `Add(b, ~a, carryIn)` |
| 15 | `ALU,A+B,*2` | as 11 but add |

Carry select (bits 123-122 / 117-116): `0` = zero, `1` = `CRY,ONE`, `2` = `CRY,C` (main status C),
`3` = `CRY,MC` (micro carry). [M, Appendix A entries 23-25]

Width masking by DATATYPE happens **after** the operation: `TYP,HW` masks to 16 bits with sign bit 15,
`TYP,BY` to 8 bits with sign bit 7, everything else 32. Calibrated from `SHIFT_ROT`'s
`ALU,A TYP,BY A,Q` byte extract at `0o17072`. Carry and overflow at 32 bits stay in `MCry` / `MOvfl`;
the width-correct pair is computed in parallel from the raw per-bit accumulators
`ovflBits = (x^r)&(y^r)` and `carryBits = x^y^r`. [V]

**The divide step overrides the ALU result entirely** when `QReg == 2` and the op is 11 or 15 — two
variants, a chained `CRY,MC` 64-bit form for DIV_64 and an unchained form for the integer divide, both
taking `prevM31` as the serial input [M, ND-05.022.1:866].

### 8.2 Q register — all 8 controls implemented

| code | mnemonic | behaviour |
|---|---|---|
| 0 | hold | — |
| 1 | `Q,F` | `Q = result` (plus the DIVF power-of-two one-shot `\|= 1<<22`) |
| 2 | `Q,Q*DIV` | `Q = (Q<<1) \| (DivStepSign == 0 ? 1 : 0)` — used **7 times** in the whole image |
| 3 | `Q,Q*LOG` | `Q <<= 1` |
| 4 | `Q,Q/ARI` | arithmetic `>>1`, width-correct sign fill for BY/H |
| 5 | `Q,Q/LOG` | `>>1`; Q31 takes the ALU's fallen-out bit (`MCry`) when the op is `ALU,A,/2` at word width — this is the DIV_64 64-bit shift link |
| 6 | `Q,Q/ROT` | rotate right 1, width-correct wrap |
| 7 | `Q,Q*ROT` | rotate left 1, width-correct wrap |

### 8.3 Conditions (`TESTOBJ`, bits 58-53)

29 distinct values appear in B30. Implemented:

| val | mnemonic | meaning | grade |
|---|---|---|---|
| 0 | `MSEXO` | `MSgn ^ MOvfl` | [D] |
| 1 | `MSORZ` | `(MSgn ^ MOvfl) \| MZro` | [D] |
| 2 | `SORZ` | `(Sgn ^ Ovfl) \| Zro` | [D] |
| 3 | `MCNZ` | `MCry != 0 && MZro == 0` | [D] |
| 8 | `CNZ` | `Cry != 0 && Zro == 0` | [D] |
| 9, 10, 11 | `MZRO`, `MCRY`, `MSGN` | micro flags; `MSGN` is width-masked (with the `BYCONV` `0o1535` island reading `MSgnRaw`) | [V] |
| 16 | `MOVFL` | `MOvfl` | [V] |
| 17-21 | `ZRO`, `CRY`, `SGN`, `K`, `OVFL` | main status | [V] |
| 25 | `Q0` | `Q & 1` | [V] |
| 26, 27 | `SAVC1`, `SAVC2` | the CSAVE pair | [V] |
| 28 | `LCZ` | `(pipe-peek ?? Lc) == 0` | [V] |
| 32 | `ENTER` | hard `false` — no CALL/ENT machinery in the microword path | [D] |
| 34 | `DATOP` | operand kind == 3 | [V] |
| 35 | `CONOP` | operand kind == 2 | [V] |
| 36 | `PDONE` | hard `false` | [D] |
| 38 | *(name unresolved)* | `OcaKind == 1` — "operand is a register" | [V] behaviour, **[OPEN] mnemonic** |
| 56 | `GOOPS` | `GoopsFlag != 0` | [D] |
| 57 | `AQSLZ` | **split**: the sequencer half is LCZ, the ALU half is Q0. DIV64L2 `0o24441` exits at `LC == 0xFFFFFFFF` | [V] |
| 59 | `IRALT` | `false` — correct here, ALT prefix is not decoded at all | [V] |
| 60-63 | `CALL`, `ENTM`, `ENTT`, `JUMPG` | hard `false` | [D] |

`TESTOBJ 38` carries the longest comment in the codebase, and its status line is the honest one worth
copying: *"the BEHAVIOUR is corpus-verified and safe to rely on. The MNEMONIC is UNRESOLVED — do NOT
write 'IDRY' into docs as fact."* Its history records two superseded models (hard `true`, then
`!MZRO`) and the oracle measurement that settled the current register-kind model: match 14542 → 15432,
diverge 5015 → 4125, zero files lost.

**Conditions that throw** (see §14 for how often they actually occur): `24 PARITY`, `37 MFS`,
`40 MFO`, `41 MFU`, `42 MDZ`, `43 MIVO`, `44 MBO`, `48 RF1OCT`, `49 RF2OCT` — every AAP-status
condition, both RF-octal conditions, and parity.

### 8.4 Status control (bits 75-72)

Values present in B30: 0, 1, 2, 3, 4, 5, 6, 8, 9, 12, 13, 14, 15. **7 (`ST,SAVB`, the BCD status save),
10 and 11 never appear.** [V] Those are the three values our engine throws on — so the gap is real in
code and empty in practice for this image.

---

## 9. Address arithmetic

Grade: **[M]** for the operand lists (ND-05.022.1 chapter 10), **[V]** for the encodings and for the
raw-byte evidence in §9.4, **[D]** for the resolution proposed in §9.4.

### 9.1 The sum

Effective address = **AA base + scaled AB index**, and it is **in bytes**.

**AA (bits 15-13):**

| AA | source |
|---|---|
| 0 | zero |
| 1 | `AA,MARG` — the 8-bit mini argument, sign-extended |
| 2 | `AA,DISP` — **`_dpaForEa`**, the previous word's DPA (§6.7) |
| 3 | `AA,DATA` — `Regs.Data` |
| 4-7 | `AA,EA0` … `AA,EA3` |

**AB (bits 12-9):**

| AB | source | scaled? | uses in B30 |
|---|---|---|---:|
| 0 | zero | — | 1036 |
| 1 | `AB,MARG` (sign-extended) | **never** — the SCAL bits *are* MARG bits | 1329 |
| 2 | `AB,B` | yes | 16 |
| 3 | `AB,R` | yes | 0 |
| 4-7 | `AB,IX1`–`IX4` (one-word delayed) | yes | 308 |
| 8 | `AB,CMBRET` | — | **0** |
| 9 | `AB,ADR` = `Ea[0]` | no | 23 |
| 10 | `AB,EA1DIR` = `Ea[1]` | no | 16 |
| 11 | `AB,ADR+4` = `Ea[0] + 4` | no | 161 |
| 12-15 | `AB,X1ORS`–`X4ORS` — "index register scaled according to data type of instruction" [M] | (hardware-scaled) | **4 each = 16**, all in `DESC_X*` at `0o3012`–`0o3071` |

**SCAL (bits 8-6)**, with the manual's own table [M]:

| code | mnemonic | manual's description | for | uses |
|---|---|---|---|---:|
| 0 | `IX*1` | scaled by 1 | Byte | 2425 |
| 1 | `IX*2` | scaled by 2 | Half word | 172 |
| 2 | `IX*4` | scaled by 4 | Word, single float | 108 |
| 3 | `IX*8` | scaled by 8 | Double float | 181 |
| 4 | `IX/8` | scaled by 1/8 | **Bit** | 14 |
| 5 | `IX/16` | *"scaled by 16"* | 80-bit floating | 5 |
| 6, 7 | — | undefined | | 0 |

Code 4 is a **right** shift by 3 — it discards the low 3 bits, which is exactly why `A,PXBM` needs the
`Pababm` latch to recover the bit number: at ADACT time with `SCAL == 4` and `AB` in IX1-IX4,
`Pababm = (~Wrf[Ab−4]) & 7` = `7 − (Xindex & 7)`. [V]

Note the mnemonic/description mismatch on code 5 (`IX/16` described as "scaled by 16"). We implement
`<<4`, matching the description. [D]

### 9.2 EA saving and the OCA restriction

ND-05.022.1 ch.10 [M]:

> Output of the address arithmetic is always latched in the EAO register. In addition, the microprogram
> may control address arithmetic output to be saved in either EA1, EA2, or EA3… When a fetch operation
> is started, only the EAO register is changed, unless an EA<nr>SAVE command is used in the same
> microinstruction.

> When the DAC is busy with the calculation of an OCA-controlled memory request, and the microprogram
> wants to perform a new memory request in the next microinstruction, new address may be generated from
> microcode, but only OCA controlled, while OCA controls the DAC. **Only a limited number of address
> arithmetic activate commands may then be used. Only AB,ADR, AB,ADR+4 and the AB,EA1DIR may be used
> and will cause the address to be presented by the DAC in the next cycle.**

That last sentence is the reason for the `_dacPlus4Pending` / `_ocaPlus4Pending` latches: the READ side
stashes the value and drops it into `Regs.Data` at the start of the next tick; the WRITE side stashes
the address `OcaEa + 4` for the next word's memory phase. [V]

**`AD_ARTI` (bit 40)** selects the two worlds: `AD_ARTI = 0` means OCA-controlled (the EA comes from the
decoded operand specifier, same cycle); `AD_ARTI = 1` means micro-controlled (EA from the one-word
`LatchedEa` pipeline). [D — the semantics are a project derivation; the manual names the bit
"Address arithmetic control, OCA/Micro" and no more.]

### 9.3 The ADACT pipeline

**The memory operation on microword *N* uses the address the `ADACT` on microword *N−1* computed.**
[V, calibrated on `0o4005`–`0o4011`]

Our own field documentation states it as the contract:

> ADACT (bit 35): address arithmetic activate. The EA computed on this word is consumed by the memory
> operation of the NEXT word (the one-word pipeline latch).

2905 words in B30 set ADACT. [V]

### 9.4 The ORCON / MARG displacement conflict — both sides, and a proposed resolution

This is the one live contradiction inside the project's own documents, and it matters: getting it
wrong silently shifts every hand-built mailbox or PCB layout by 4 bytes.

**Side A — "`ORCON=n` targets `EA + (n−4)`."** From
`E:\Dev\Ronny\ND5000UC\CARVER-REQUEST-OCTOBUS-MICROCODE-ORACLE-INTEGRATION-2026-07-21.md` line 63 [as
written]:

> **ORCON offset convention — [V vs copy engine AND CNTXTLOAD]:** an ADACT read/write with `ORCON=n`
> targets `EA + (n-4)` bytes. This is the convention behind every offset above; the two engines MUST
> agree on it.

Its anchors: the copy family (RESIWR 14B — `msg+14` addrA, `msg+18` addrB, `msg+22` count) and
`CNTXTLOAD` (PCB base `SRF17 × 256 + 0x800`, register offsets `+0x00 P`, `+0x04 L`, `+0x10..0x1C
X1..X4`, `+0x20..0x2C A1..A4`, `+0x30..0x3C E1..E4`).

**Side B — "the displacement is used directly."** From
`E:\Dev\Ronny\ND5000UC\docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md` §3.0 line 1469 [as
written]:

> **Correction to a common anchor:** the displacement is used **directly**, not as `EA + (n−4)`. Eight
> independent points line up on the direct reading and none on the offset one [V, raw words read this
> session]

with this table as the whole of its evidence:

| Microword | byte 15 | byte disp | field | operation |
|---|---|---:|---|---|
| `0o15141` | `04` | 4 | `N5STA` | read at `0o15142` |
| `0o15202` | `08` | 8 | `X5CPU` | read at `0o15203` |
| `0o15203` | `0c` | 12 | `MICFU` | read at `0o15204` |
| `0o15204` | `04` | 4 | `N5STA` | write WAITING at `0o15205` |
| `0o15332` | `0e` | 14 | `N500A` | write version at `0o15333` |
| `0o15333` | `10` | 16 | — | write CPU parameter at `0o15334` |
| `0o17417` | `04` | 4 | `N5STA` | write ANSWER at `0o17420` |
| `0o24716` | `0a` | 10 | ext `X5ACT` | poll read at `0o24717` |

Note carefully: Side B always attributes the displacement to word *N* and the memory operation to word
*N+1* — its claim is "direct **plus** the one-word ADACT pipeline". The two are inseparable in that
formulation.

**First, a correction that neither side makes.** I read the raw bytes of `MSG_DMEMWR` `0o15355`–`0o15360`:

    0o15356  0000000000017000000001081aefa20e   OR_ENABLE=0  MARG=0x0E  AA=5 AB=1 SCAL=0 MEM=0 ADACT=1
    0o15357  500000007170a000000003091af0a212   OR_ENABLE=0  MARG=0x12  AA=5 AB=1 SCAL=0 MEM=9 ADACT=1
    0o15360  5000000071712000000003091af1a216   OR_ENABLE=0  MARG=0x16  AA=5 AB=1 SCAL=0 MEM=9 ADACT=1

**`OR_ENABLE` (bit 97) is ZERO on every one of these words.** ORCON is only meaningful when OR_ENABLE
is set. The field actually carrying the displacement is **MARG** (bits 7-0), reaching the address adder
as `AB,MARG` (AB = 1), added to `AA = 5` = EA1. The rendered listing prints "ORCON=0x0E" purely because
MARG and ORCON share bits 5-0. **So the whole argument has been conducted about the wrong field name.**
[V]

**Second, a proposed resolution.** [D — mine, from the raw bits plus the documented ADACT latch. Not
executed. Do not treat as settled.]

The two rules give **identical byte offsets whenever consecutive displacements in a chain differ by
exactly 4.** Under the pipeline reading, the word that *performs* a read carries the displacement for
the *next* address; if the chain steps by 4, that displacement is exactly (this read's offset + 4), so
attributing it to the reading word and subtracting 4 recovers the right answer.

Check it on both sides' own anchors:

- **RESIWR.** Side B's own table puts addrA at byte `0x0E` verified at `0o15534→35`, and addrB at byte
  `0x12` verified at `0o15535→36`. The word that *reads addrA* is `0o15535`, and `0o15535`'s own
  displacement is `0x12`. "displacement `0x12` targets `0x12 − 4 = 0x0E`" — Side A's exact anchor. Both
  rules land on `0x0E`.
- **CNTXTLOAD.** The raw MARG chain is `0o14750 = 0x00, 0o14751 = 0x04, 0o14752 = 0x08, 0o14753 = 0x0C`
  and the register map has "P via `0o14751` read → PCB +0x00". Word `0o14751` carries `0x04` and reads
  `+0x00`. `0x04 − 4 = 0x00`. The PCB register stride *is* 4, so the whole table agrees under both
  rules.

**The discriminating case is a chain whose stride is not 4** — and the message header is exactly that.
Side B's rows `0o15203 disp 0x0C → MICFU read at 0o15204` and `0o15204 disp 0x04 → N5STA write at
0o15205`: the word that *reads MICFU* is `0o15204`, whose own displacement is `0x04`. Under "n−4" that
read would target `0x04 − 4 = 0x00` — the LINK word, not `MICFU` at `0x0C`. Under direct-plus-pipeline
it targets `0x0C`, which is the only reading under which the range check, the bit-15 strip and the
64-entry MICFU dispatch work at all.

**Presented fairly:** both parties measured real bytes, and both are right about the resulting offsets
for the structures each calibrated on. The disagreement is about **which microword the displacement
belongs to**, and it is only visible on a chain that does not step by 4. On the message header, the
direct-plus-pipeline formulation is the one that produces a working routine.

Two more things to weigh before deciding. The older document is a **carver request** — a work order
stating a working assumption so two engines would agree — while the newer is a **carve report**; that
is a difference in kind, not just in date. And the rendered `.md` listing genuinely mis-renders this
field group, so **any offset argument built on the listing is unsound on both sides**.

**Third, the manual settles the architectural question, and it settles it for "direct".** Neither side
cited this. ND-05.020.01 **Table 20, §7.4.6 page 204**, "Macroaddress Modes", lists every addressing
mode as an explicit sum [M]:

| Mode | Address arithmetic |
|---|---|
| LOCAL | `DPA + B => EA0` |
| LOCAL post-indexed | `DPA + B => EA0`, `p*X => XS`, `EA0 + XS => EA0` |
| LOCAL indirect | `DPA + B => EA0`, READ, `DLA + 0 => EA0` |
| RECORD | `DPA + R => EA0` |
| PRE-INDEXED | `DPA + 0 => EA0`, `X => XS`, `EA0 + XS => EA0` |
| ABSOLUTE | `DPA + 0 => EA0` |
| CONSTANT | `DPA + 0 => EA0` |
| REGISTER | NOOP |

**There is no `−4` term in any addressing mode.** The displacement `DPA`, decoded and sign-extended (or
zero-filled) by IDU nanostate 3 and latched in the DAC's `DPAR`, is added to base, record or zero, and
the sum lands in EA0.

The `+4` that genuinely exists is a **separate parallel adder with a narrow, stated purpose**
[M, ND-05.020.01 §7.4.1]: *"The DAC calculates the +4-address with a specialized +4-adder, working in
parallel with the general adder. **The intended use is for double floating operands.**"* It is reached
only through the *output-selection* code `AB,ADDR+4` — "previous address +4 if recycle not necessary" —
i.e. it re-emits the previous address plus 4 to fetch the low half of a 64-bit operand. The assembler
even bundles it: `#A,OPM = #A,OP + OR,NE + AB,ADR+4` — fetch the operand, select the *extension*
register, address = previous + 4.

**So `+4` is the double-float extension-word path, not a displacement bias.** If the `EA + (n−4)`
convention came from reading `AB,ADR+4` as part of the effective-address formula, that is the
misreading.

Note also that the Hardware Description calls AA code 2 **`AA,DPA`**, not `AA,DISP` — and its name is
the more informative one: it is *the displacement decoded out of the operand specifier*, sitting in
`DPAR`. Our code reads `_dpaForEa` for that source, which is consistent.

**Recommendation: adopt "the displacement is direct, consumed by the next word's memory op", and call
the field MARG wherever OR_ENABLE is clear.** Three independent lines now point the same way — the raw
`OR_ENABLE = 0` bits, the stride-not-4 message header, and Table 20. But this is Ronny's call, not
mine, and the losing side should be corrected in its own file rather than left to contradict this one.

---

## 10. Memory, MMS and traps

### 10.1 The memory-operation field

Recombined as `(bit41 << 3) | bits34-32`. Uses across B30 in brackets. [V]

| code | mnemonic | what our engine does |
|---|---|---|
| 0 | none (10975) | phase skipped |
| 1 | `LADDR` (32) | **deliberately nothing** — resolve the EA without reading the value. Not loading `Regs.Data` is exactly what distinguishes it from READ. |
| 2 | `WR,POF` (208) | write, physical (data-side MMS *not* applied — this is the 5MPM / RIOM seam) |
| 3 | `CCD` (1) | no-op (no cache modelled) |
| 4 | `WR,PHYS` (51) | physical write |
| 5 | `WR,DOM` | plain write — we *are* the normal domain |
| 7 | `WRITE` (490) | resolve, then defer until after `ExecuteBody` (the write data is the F-bus result) |
| 6 / 14 | `WR,ADOM` / `RD,ADOM` | **approximation** — the alternative-domain space is collapsed onto the same flat memory |
| 8 | `QVACC` (1) | no-op (no look-ahead queue). Used once, by `RET_1` @`0o4406` with LOADLA — resolves the fetch address, loads no data. |
| 9 | `RD,POF` (328) | read, physical |
| 11 | `RD,PX` (6) | plain read — the write-permit check is **not** modelled |
| 12 | `RD,PHYS` (81) | physical read, with the DIT process-segment fix (§10.3) |
| 13 | `RD,DOM` (12) | plain read |
| 15 | `READ` (1148) | `Regs.Data = memory.Read(...)` |
| 10 | — | undefined; never appears in B30 |

**`LADDR` means "load address".** The mnemonic tables' "LADDER" is an OCR artifact of "load address"
(ND-05.020.01:6472). [V]

Writes are staged and issued after `ExecuteBody`, and **suppressed when the OR destination already
routed the result** — that is our flattened stand-in for the `C,MEMOT` bit (37), which we decode and
never consult.

`RD,POF` / `WR,POF` are kept **physical on purpose**: POF is how RIOM reaches ND-100 memory and how the
mailbox reaches 5MPM.

### 10.2 The MMS walk

Grade: **[D]**, cross-checked against the running nd500x C emulator — **not** [V] against B30 microcode.

Virtual address split: `Seg` (31-27, 5 bits) | `L1` (26-20, 7) | `L2` (19-11, 9) | offset (10-0, 11).
Page size **2 KB**.

1. **Capability**:
   `capAddr = PcbBase + domain*256 + (isInstruction ? 0x00 : 0x40) + segment*2`, read as a 16-bit
   big-endian halfword **from guest memory**. Bit 15 means different things per kind: on a PROGRAM
   capability it is `PC_TYP` (set → indirect segment, an inter-domain call); on a DATA capability it is
   `DC_WRP` (write permit — a write without it is a protection violation).
2. **PSTE**: `psn = cap & 0x1FFF`; `psteWord = mem[PstBase + psn*4]`; `indexMode = psteWord >> 30`,
   `pfn = psteWord & 0x3FFFFFFF`.
   > Confirmed against the real B30 PST 2026-08-17: the real `PST[1] = 0x400000E6` only decodes sanely
   > this way. The earlier "bits 1-0 / 31-2" reading came from the spec model and is **wrong** vs
   > hardware. [V]
3. **Index modes**: `AZI` (0) single page — a non-zero L1 or L2 is a page fault; `ASI` (1) one 512-PTE
   table indexed by L2 — non-zero L1 faults; `ADI` (2) two-level; **mode 3 → page fault** conservatively
   [OPEN].
4. **Leaf PTE**: PFN = bits 29-0; **not present is encoded as PFN == 0** (there is no dedicated present
   bit); bit 31 = write-protect.
5. `physical = (finalPfn << 11) | offset`.

**Capability tables live ON the process segment named by the PS register**, itself a physical segment
resolved through the PST [M, ND-05.020.01 ch.6 Figure 31]:

    capBase = resolve(PS) -> process-segment physical base
    cap     = capBase + CED*256 + (isInstruction ? 0 : 64) + segment*2

The 256-byte DIT holds 32 program capabilities then 32 data capabilities, 2 bytes each; a capability's
low 13 bits are the PST index.

> **This was the root cause of the live-SINTRAN swapper stall (2026-08-18).** `MmsUnit` read
> capabilities from a **flat** `pcb_base = Dpa − DOM*256 − 0x80 = 0`, inherited from the nd500x/NDIX
> port which hardcodes DITBASE and never resolves PS. The seg-1 program capability then read 1 → the
> DATA/system-table PST entry (empty of code) instead of 2 → the actual code. Live proof after the fix:
> PS = 3, CED = 0, PST[3] → process segment 3 at physical page 0x2 = the real DIT; program_cap[seg1]
> there = 2 → code pages 0xE9..0xFB. [V]

### 10.3 The DIT — which is the PCB

**DIT == PCB.** 256 bytes per domain, stride verified. `CED_TO_DIT` @`0o12035` (29 reference sites) sets
`DPA = pcb_base + CED*256 + 0x80`. Layout, cross-checked against the real ND-500 Unix kernel's
`struct pcb` (`E:\Dev\Ronny\NDIX-C\kernel\MASTER\machine\pcb.h`) [V]:

| offset | field |
|---|---|
| `0x00` | `pcb_pc[32]` — 32 program capabilities |
| `0x40` | `pcb_dc[32]` — 32 data capabilities |
| `0x80` | `pcb_call` |
| `0x96` | `pcb_ote1` |
| `0xA6` | `pcb_cte1` |
| `0xBB` | `pcb_ith` |
| `0xBC` | `pcb_tos` |
| `0xC0` / `0xC4` | `pcb_ll` / `pcb_hl` |
| **`0xC8`** | **`pcb_pia`, bit 0** |
| `0xCC` / `0xCD` | `pcb_cad` / `pcb_ced` |

**The privileged-instruction gate.** Privileged instructions (`dctsb` `0xFF1D`, `pctsb`) check
**PIA = macrostatus bit 1**. PIA clear → ILLEG → `DUMMY` @`0o103`, a jump-to-self hang. PIA is **not**
taken from the PCB macrostatus word: `CNTXTLOAD` loads the full macrostatus at `WRITEST1` `0o15033`,
then `0o15074`–`0o15102` **re-derive** it from a domain-table byte and overwrite bit 1. The source is
`pcb_pia` at PCB+0xC8. [V]

There is a second fix worth recording, because it looked identical to a CPU bug (2026-08-19) [V]:

> The `CED_TO_DIT` `RD,PHYS` reads (`pcb_pia` at DIT+0x48, and the trap-enable/limit bytes at +0x16,
> +0x26, +0x3B) are **offsets into the process segment, not absolute physical addresses**. Reading them
> absolutely made `pcb_pia` come from flat physical `0xC8` — the mailbox page — so PIA was 0 and the
> swapper's first privileged `dctsb` ILLEG-trapped into `DUMMY` and hung.

The fix is deliberately narrow: it applies only to `memOp == 12` (`RD,PHYS`) with a virtual address
below `0x800` and a non-zero PST root, so `RD,POF` (the mailbox seam) and CNTXTLOAD's absolute
`RD,PHYS` reads (register block at `0x2A000`, PST at `0x3A000`) are untouched.

### 10.4 Where translation is wired in

| Path | Translated? |
|---|---|
| instruction fetch | yes, when program MMS is enabled |
| data memory-op switch | yes for the DOM-mapped ops only — `READ`, `RD,DOM`, `RD,PX`, `WRITE`, `WR,DOM`. POF, PHYS and ADOM stay physical. |
| operand decode, stack frames, OR stores | yes — these carry no memory-op code and are inherently domain-mapped |
| the external bridge | yes, but never raises a trap: it returns `false` on fault so the caller skips, and catches a bad guest PFN so nothing escapes onto the machine clock thread |

Both gates additionally require a genuinely virtual address (`(va >> 27) != 0`), so every existing
physical / mailbox / boot / oracle test is byte-for-byte unchanged.

**Auto-enable is a heuristic and says so in the code** [D]: the first time the CPU fetches a genuinely
virtual program address *and* a context has already latched the PST root, the bases are snapshotted and
MMS turns on. A real **segment-0 virtual fetch would not auto-enable** — that gap is [OPEN]. Bases are
snapshotted rather than read live because `Regs.Dpa` is reused as a direct-literal scratch.

### 10.5 Traps

    Regs.IduSts = (Regs.IduSts & ~0xFFu) | (uint)(trapNumber & 0xFF);
    _pendingTrap = true;

Sampled at the tick boundary ([D] — the real sampling point is pipeline-level; boundary sampling is the
flattened equivalent), forcing `Mpc = 0o100` (`TRAP`), from which the **real microcode** takes over:
`TRAP` → `TRAP_SAM` @`0o12545` → record collection → triage → either a local handler or the
trap-shaped mailbox stop.

Trap numbers in play: page fault **`0o46`**, protection violation **`0o44`** (both literals in the
microwords — `PROTVIOL` @`0o13036` carries `44B` directly, `TRAP_GEN4` @`0o13563` loads `SARG 000046`).
Legal trap range is `0..0o53`. **There is no symbolic trap-name table in the carve — [OPEN], and it has
not been guessed.**

**Everything past the vector force is real microcode, not C#.** `TrapTests` drives trap `0o46` through
and confirms `TRAPN = 0o46` in the answered message. An ignorable trap with no enabled handler is
escalated by the real `TRAP_FIND` triage to **THM = `0o45`** — which was initially misread as an
emulator bug. The microcode was right.

**The `0o100`–`0o106` cluster.** `TRAP` @100 (→ `TRAP_SAM`), `NOTHING` @101, `FATAL` @102, `DUMMY` @103,
`DUMMY_2` @104, `DUMMY_1` @105, `DUMSC14` @106. `NOTHING`, `FATAL` and `DUMMY` are jump-to-self dead
ends. `DUMMY_2` → `DUMMY_1` → `RETURN, POP` is the **two-cycle filler subroutine** — `CALL DUMMY_2`
burns two cycles and carries on; it is called 370 times, the most-referenced label in the image. [V]

> **`Mpc` frozen at `0o103` means an instruction ILLEG-trapped.** The classic cause is a privileged
> instruction with PIA clear. The faulting instruction is `P1`, one behind the restart `P` (§7.4).
> Note also that the earlier project record had `DUMMY_1` and `DUMMY_2` swapped; the raw words say
> `0o104 = DUMMY_2` and `0o105 = DUMMY_1`.

---

## 11. The mailbox / octobus / ACCP spine

Grade: mostly **[V]** — this is the best-carved part of the microcode, because it is the part the
emulator has to get byte-exact to talk to a real SINTRAN. The full 251 KB treatment lives in
`E:\Dev\Ronny\ND5000UC\docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md` (421 verified
points, 106 open); this section is the microcode-shaped summary. Grades below are carried over from
that document unchanged.

### 11.1 Two entry mechanisms, and they are not the same thing

The most repeated correction in the whole message-path record:

> **The normal doorbell is a plain memory write (`X5ACT := 0`) that the microcode's idle loop polls.
> The octobus kick is the PREEMPT path only.** [V] microcode side (the `INVSEQ` at `0o24720`, the
> literal `1` written at `0o24722`); [V] SINTRAN side (`ACT51`, a single `STZTX`).

### 11.2 The idle loop and the activation walk

| Routine | Octal | What it does | Grade |
|---|---|---|---|
| `IDLE` | `0o24670` | Calls the deferred re-scan `0o16572`, reads the ext-block head, `SET_IDLE`, arms traps | [V] |
| `IDLE_0` | `0o24700` | Unlock queue, mark this CPU idle (`srf[0o2003] := 0`), write `D,SPEC,TRPARM` | [V] |
| **`IDLE_1`** | **`0o24702`** | The spin: `CALL SCAN_ACCP`, then **seven consecutive `CALL DUMMY_2`** = 14 microcycles of deliberate nothing, so the spin does not hammer shared memory | [V] |
| | `0o24716` | ADACT forming base + `0x0A` = halfword 5 = `X5ACT` | [V] |
| | `0o24717` | Read that halfword (`RD,POF`, `TYP,HW`) | [V] |
| | `0o24720` | `COND,MZRO` with **`INVSEQ = 1`** — loop back while non-zero, fall through on **zero = work pending** | [V] |
| **`IDLE_2`** | `0o24721`–`22` | **Re-arm the doorbell: write `1` at base + `0x0A`**, *before* consuming the work, so a doorbell rung during the handler is not lost | [V] |
| **`ACTIVATE`** | `0o24723` | `CALL LOCK_QUE`; also the direct target of kicks 1 and 2 and of the `0o100501` fast path | [V] |
| | `0o24724`–`25` | `SC12 := SRF11`; if a process is loaded → `CALL CNTXTSAVE` @`0o14666` | [V] |
| `ACTIVATE1` | `0o24731`–`33` | `DPA := srf[0o2017]`, displacement 0, read the chain head at `X5BEX` → `MSG_NEXTL` | [V] |

The whole idle-and-wake loop is **36 words**.

### 11.3 The message walk and the MICFU dispatch

`MSG_LINK1` @`0o15141` reads `N5STA` (byte disp 4); if it is not `MSGN500(1)` it returns and skips the
block. `MSG_LINK3` @`0o15147` filters on CPU target. `MSG_LINK7` @`0o15175` is the core fetch:
`srf[ADR_MESS] := message address`, `srf[ADR_MSGME] := 1`, read `X5CPU` at disp 8, read **`MICFU` at
disp 12**, then **unconditionally write `2` (WAITING) into `N5STA` at disp 4**, set `MIC,VECT := MICFU`,
`PRNOWR`, and **release the lock before the work runs**. [V]

`MSG_LINK8` @`0o15213` range-checks `64 − MICFU`; out of range strips bit 15 and retries once; still
out → `MSG_ILLEG` @`0o15221`. **Bit 15 of MICFU is a flag, not part of the function number.** [V]
`MSG_LINK9` @`0o15222` does the `JMPREL` into the 64-entry table based at `MSG_00` @`0o15224`.

**The full MICFU table.** All 64 slots decoded from the raw dispatch words and cross-checked against
the `.LABE`; every unassigned slot points at `MSG_ILLEG`. [V]

| MICFU | SINTRAN name | Handler | Octal | Runs in `CpuND5000`? |
|---|---|---|---|---|
| `01` | `3RMICV` | `MSG_VERSRD` | `0o15330` | yes, both engines, differential-tested |
| `10` | `3RMED` | `MSG_DMEMRD` | `0o15336` | yes (`MailboxCopyTests`) |
| `11` | `3WMED` | `MSG_DMEMWR` | `0o15355` | yes |
| `12` | `CACHE` | `MSG_CACHE` | `0o15640` | servicer models it |
| `13` | `RAMED` | `MSG_RESIRD` | `0o15516` | yes |
| `14` | `WAMED` | `MSG_RESIWR` | `0o15534` | yes — the swapper-delivery path |
| `22` | `P0START` | `MSG_STARTP0` | `0o15660` | [V] constants, [D] flow |
| `23` | `3START` | `MSG_START` | `0o15671` | yes (`MailboxStartTests`) |
| `24` | `3MONCO` | `MSG_CONMC` | `0o15676` | microcode [V]; **the C# servicer's 24B is a hand-guess with no microcode backing — do not use it as an oracle** |
| `25` | `3TRACO` | `MSG_START` (**same handler as 23**) | `0o15671` | via 23 |
| `26` | `3WMONCO` | `MSG_CONWR` | `0o15703` | [V] |
| `30` / `31` | `3PHSR` / `3PHSW` | `MSG_PHYSRD` / `MSG_PHYSWR` | `0o15561` / `0o15600` | yes |
| `34` / `35` | `3RMEP` / `3WMEP` | `MSG_IMEMRD` / `MSG_IMEMWR` | `0o15403` / `0o15442` | yes, round-trip tested |
| `42` | `PRTRAP` | `MSG_PRT` — **programmed trap** (ND-05.012.01 §13) | `0o16005` | no |
| `44` | `3RPREG` | `MSG_HISTOG` | `0o15626` | no |
| `45` | `MPCLR` | `MSG_CLEAR` | `0o15643` | no |
| `46` | (illegal to SINTRAN) | `MSG_DUDC` | `0o15655` | no |
| `47` | (illegal to SINTRAN) | `MSG_IDLE` | `0o15324` | no |
| `50` / `51` / `52` | — / — / `NKREL` | `MSG_UNIX5RE` / `UNIX5CM` / `UNIX5REL` | `0o16015` / `0o16062` / `0o16067` | no |
| `70`–`75` | `TRC70`–`TRC75` | trace family | `0o16160`, `166`, `170`, `172`, `174`, `200` | no |
| `76` | `SCACHEMODE` | `MSG_CACI` | `0o16202` | no |
| `77` | `RSCRREG` | `MSG_LOOKSRF` | `0o16245` | no |
| all others | | `MSG_ILLEG` | `0o15221` | — |

**Slots `15`–`21` (`RNEWCO`, `3EXAR`, `3DEPR`, `3RREG`, `3WREG`) are confirmed illegal on B30 from the
raw table** — that upgraded a previous "strong family inference" to verified *for this image*. [V]

**What SINTRAN actually transmits in normal running**: `1, 10, 11, 22, 23, 24, 25, 26, 44` octal, plus
the monitor/debug functions `06`–`21`, `30`–`37`, `40`–`43`, `45`, `70`–`77` issued through `N500C` for
LOOK-AT and friends. [V]

**Undocumented / generation-dependent arms — the honest list:**

- `34` = IMEMRD and `46` = DUDC on B30 [V]. Whether the **classic** ND-500 microcode assigns them the
  same way is unverifiable — no classic message-path microcode survives. [OPEN]
- `17` `3DEPR` being classic-only is a family inference, and the sender that stores `MICFU := 17B` is
  not locatable in the available NPL. [OPEN]
- SINTRAN's `N5XXC` marks `46/47/50/51` illegal while B30 assigns them real handlers; slot `52` is
  `NKREL` on the ND-100 side and `UNIX5REL` on B30. **Decide which machine you are modelling before
  coding either.** [V] on both sides.
- `MSG_CACHE`'s parameter is pinned at message word 7 [V], but `MSG_CCONMC`'s full bit map was never
  followed to its end. [OPEN]

### 11.4 The copy engine

Calibrated parameter geometry, shared by the whole copy family [V]:

| Message word (octal) | Byte disp | Content |
|---|---|---|
| 7–`0o10` | `0x0E` | 32-bit **addrA** — the ND-500 side |
| `0o11`–`0o12` | `0x12` | 32-bit **addrB** — the buffer / physical side |
| `0o13` | `0x16` | **nrbyt**, halfword byte count (rounded up to words) |
| `0o14` | `0x18` | PHYS family only: an extra halfword → `D,MM,PHS` |

**Direction is fixed by the handler, not by a flag: WR copies B→A, RD copies A→B.** Count is in bytes
(`SC4`); count/4 words plus a byte or halfword tail via `Q`. `RESIRD`/`RESIWR` are the "resident"
variants — **no `NEWCNTXT`, no domain resolve, no validation.** The swapper image arrives through them
as 44 blocks of 2048 bytes. [V] microcode + [V] live trace.

### 11.5 The answer path

`MSG_END` @`0o17412`: lock, `MSG_CCMOVE`, `DPA := srf[ADR_MESS]`, **write `SC10` (3 or 4) into `N5STA`
at disp 4**, then `GIVEINT`. [V]

`GIVEINT` @`0o25422` [V, all four steps]:

    slot   = X5FIF_base + X5FYL*4        (0o25427, 4-byte stride)
    mem[slot] = srf[ADR_MESS]            (0o25431-32)
    X5FYL  = (X5FYL + 1) % X5MXF         (0o25436-37, wraps to 0)
    ACCP_WRITE( ((SYSPAR & 0o037400) >> 3) | 0o100001 )   (0o25440-41)

The `>>3` is carve-confirmed: word 1 `0o004000` becomes `0o100401`, the live-observed interrupt word.

`LOCK_QUE` @`0o25442` / `UNLOCK_QUE` @`0o25505` are a test-and-set on **global header word 0
(`X5SEM`)** — the same semaphore SINTRAN's `SLOCK` / `SUNLOCK` uses. [V]

### 11.6 The ACCP port — four routines, one doorbell

| Routine | Octal | What |
|---|---|---|
| `ACCP_READ` | `0o16371` | `SC13 := BM11` (bit 9 = AOBF), spin at `0o16372` (`TIMING = SLOW2`, the cross-module read), `0o16374` reads `A,SPEC,AOB` → `SC13` — **this read is what auto-clears AOBF and ATRAP** — then `RETURN, POP` |
| `ACCP_WRITE` | `0o16402`, write at `0o16405` | Spin on `AFLAG & BM12` (AIBF) until clear, then `D,SPEC,AIB := SC12`. **`0o16405` is the ONLY `D,SPEC,AIB` in the whole image — the only hardware doorbell in the entire mailbox path.** |
| `ACCP_WAITI` / `ACCP_WAITO` | `0o16375` / `0o16406` | the same spins, returning AFLAG / no write |
| **`ACCP_XWRITE`** | `0o16401` | `RF2D := SC12`. **Despite the name it does NOT touch AIB** — it appends a word to a register-file/memory message buffer addressed by RF2. *Any model that forwards `ACCP_XWRITE` words to the bus is inventing traffic.* [V] |

**`SCAN_ACCP`** @`0o16554`–`0o16565` is the polling spine: four AFLAG bits tested in five words, called
from **seven** sites (`0o5212`, `0o12627`, `0o15440`, `0o17462`, `0o24702`, `0o25502`, `0o25546`) —
every spin loop calls it. [V]

**The kick framing rule the decoder actually enforces**: *a word is a kick iff bit 15 set, bit 7 clear,
bit 6 set.* [V] This contradicts the naive un-delayed reading in
`ND5800-MICROCODE-ACCP-OCTOBUS-CATALOG.md` §4; the proof the delayed reading wins is that at `0o16417`
a mask-AND with bit 7 can never be negative, so under the naive reading `0o16420` is unreachable dead
code.

`OCB_MES_K` @`0o16424` compares `SARG 0o100501` against the word; an exact match jumps straight to
`ACTIVATE` @`0o24723`, bypassing the table. Otherwise `VECT := word & 0o77`, two `DUMMY_2` cycles so the
VECT latch settles, then `JMPREL` into the 64-entry kick table at `0o16430`–`0o16527` (exactly `0o100`
words; `OCB_KICK64` labels the word past the end). Kicks 1 and 2 → `ACTIVATE`; 3 → `OCB_KICK03`
@`0o25522` (the CLRKICK / cache-clear protocol); 4 and 5 → `0o25553` (**one word, two labels** — there
is no separate kick-4 code); 6 → `OCB_KICK06` @`0o25561` (forced de-schedule); 7-63 → `OCB_KICK64`
@`0o16530` (error 204B). [V]

Observed framed kick words [V]: `0o100501` (`0x8141`, the fast path), `0o100503` (CLRKICK),
`0o100101` (`SEND_14` tail @`0o5245`), `0o100102` (`SENKICK` @`0o25142`, `0o25006`).

### 11.7 Which side answers what

The dividing line, from the manual and from the microcode both. The ACCP consumes multibyte messages
addressed to **OMD 0** (octobus test programs) and **OMD 3** (its own command library). Everything else
it writes straight into `AOB` with ATRAP and OMESS set: *"No data checking or protocol handling is done
by the ACCP."* [M, ND-05.020.01:3930-3932]. Outbound, the microcode writes `AIB`, and the **ACCPTRAP**
bit in the modus register decides whether that word is an ACCP command or goes onto the octobus
[M, :3777].

**So: the ACCP firmware answers the command layer; the microcode answers the mailbox.** The command
field is literally named `MICFU` — MICro FUnction.

ACCP commands that matter to microcode work (all answered by the **68000 firmware**, not by microcode):
presence `0x0E` (`LSYSPAR`, also clears the selftest status word); `0x3E` read CPU model; selftest
`0x1B` = **`RUNTST`** — *this is NOT StartMic, an earlier project record had that wrong*; `0x30`
`RTEST` reads the status without running; `0x11`/`0x12` load/verify parameter pointer; `0x13`/`0x14`
control-store load (via memory / direct 8 words = 128 bits + checksum); `0x15`/`0x16` are **dumps, not
loads**; `0x2A` `LCON` is one word to the ACON decoder; **`0x36` `CMMIC` = STARTMIC** (takes a CS
address, reclocks MAR, sets MRUN); `0x1C` STOPMIC; `0x1D` CONTMIC; `0x1E` RESTMIC (shape carved, body
[OPEN]); `0x1F` ALIVE (only the negative answer carved, [OPEN] what it probes). TERMINATE and ARES have
**no arm at all** — they carry the emergency bit and are decoded by hardware. Over the 46-arm
dispatcher: 34 [V], 10 inferred, 2 [OPEN] (`0x10` and a fourth undocumented "start" variant at `0x17`).

**Nothing in the microcode reads AFLAG before STARTMIC** — every `SCAN_ACCP` call site is inside the
running microprogram, so the ACCP is free to run its own selftest before the microprogram starts. [V]

### 11.8 The SRF communication block, `0o2000`–`0o2025`

Every `ADR_*` helper is two words: a `NEXT` filler, then a word loading `SARG = 0o20xx` into `RFA1` or
`RFA2` and returning via `JMP DUMMY_2`. `RF1` / `RF2` then read or write that cell. The helper table is
at `0o17334`–`0o17402`. [V]

| SRF | Helper | Contents | Grade |
|---|---|---|---|
| `0o2000` | `ADR_MESS` @`0o17334` | **current message address** in shared memory | [V] |
| `0o2002` | `ADR_FIFOB` | the `X5FIF` ring base, loaded by `SYS_DATAF` from global header word 6 with **no shift** | [V] |
| `0o2003` | `GET_FLAG` | run-state flag; `SET_RUNNING` writes `BM00`, `SET_IDLE` writes 0, `SET_IN_TRAP` increments. **This cell is what makes `TRAP_END` answer 3 versus 4.** | [V] |
| `0o2004` / `0o2005` | `ADR_SYSTRA` / `ADR_SYSHOS` | system trap area / — | [?] |
| `0o2006` | `ADR_SYSPAR` | system parameter word 1 = `5OMDNO << 8`, the ND-100's receive OMD, **runtime-allocated at boot — do not hardcode** | [V, NPL] |
| `0o2007`, `0o2010` | | 0 in this SINTRAN revision | [V, NPL] |
| `0o2011` | `ADR_ASTBAD` | bad-address cell, read by `TRAP_GEN3C` | [V] use, [?] name |
| `0o2012` | `ADR_MOD` | saved modus register | [V] |
| `0o2013` | `ADR_PROC0` @`0o17357` | process-0 (swapper) cell; `TRAP_OMESS1` reads it to choose inline decode vs stash-and-defer | [V] test, [D] meaning |
| `0o2014` | `ADR_MODMASK` | mask of legal MOD bits | [D] |
| `0o2015` | `ADR_CPUPAR` | the CPU-parameter halfword returned by 3RMICV — a **runtime** value, not a constant | [V] |
| `0o2016` | `ADR_CPUAVA` | CPU-available flag, gated by `MSG_START` | [D] |
| `0o2017` | `ADR_#CPUDF` @`0o17367` | **pointer to this CPU's extension block** in shared memory; written by `INIT_ADRP` @`0o25646` | [V] |
| `0o2020` | `ADR_EXQUE` | execution queue | [?] |
| `0o2021` | `ADR_MSGME` | "message being serviced by me": 1 while in progress, 0 when done | [D] |
| `0o2022` | `ADR_CPUFLG` | CPU flag word, the multi-CPU targeting test | [D] |
| `0o2024`/`0o2025` | `ADR_ATRAP` | async-trap pending flags | [D] |
| `0o2025` | `ADR_5SIB` | 5SIB pointer | [?] |

### 11.9 The X5 cells in shared memory

Per-CPU extension block: `ext(cpu) = ADRZERO + START_MESS + SAMSON_CPU * 256`, computed by `INIT_ADRP`
@`0o25646` (four `A+B,*2` doublings = ×256 **bytes**). [V]

| Word | Byte | Symbol | Meaning |
|---|---|---|---|
| 0-1 | `+0x00` | **`X5BEX`** | ex-queue chain head (32-bit); `-1,-1` = empty |
| 4 | `+0x08` | `X5CPU` | |
| **5** | **`+0x0A`** | **`X5ACT`** | **the doorbell halfword**: `-1` nothing pending, `0` work pending, microcode re-arms to `1` |
| 6 | `+0x0C` | `X5PRO` | current process; `-1` = idle |
| 7 | `+0x0E` | `X5STA` | this CPU's octobus station |
| `0o10` | `+0x10` | **`X5CLR`** | clear-functions mask — **read it, never assume `0o77`** |
| `0o11` | `+0x12` | `X5CCL` | cache-clear counter |
| 20 | `+0x28` | — | message-region semaphore, spun on by `OCB_WAITSEX` @`0o25543` |

Global header (at `START_MESS`, *before* the per-CPU blocks — same small word numbers, different base):
word 0 `X5SEM`, word 3 `X5HEN`, word 4 `X5FYL`, word 5 `X5MXF`, word 6 `X5FIF`. [V]

**`X5FIF`, `X5BEX` and every message `LINK` are window-relative BYTE offsets** (`phys = mpmStart +
offset`), not ND-100 word addresses. A hardcoded `<<1` once put the octobus slot at twice the address
the microcode wrote; the fix touched 7 test files. [V]

**`N5STA` is not `X5STA`.** `X5STA` is the ext-block cell holding the station number. **`N5STA` is the
message-block status word at message word 2**, taking `MSGN500(1)` → `WAITING(2)` → `ANSWER(3)` or
`5ERANSWER(4)`; the high bits `0o160000` are power-fail flags and are always preserved. [V]

**`START_MESS` (@`0o26`) and `SAMSON_CPU` (@`0o25`) are patched by SINTRAN before the ACCP burns the
control store** [M, ND-05.017.01:3961 — *"Some system parameters are patched into this first page"*].
On-disk the A30/B30 images carry `0x2000` and `0`; the live values on our rig are `0x8800` and
`0x0001`. **Never take them from the disk image.** Both are full 32-bit `LARG` values — reading only
halfword 7 truncates a real offset and breaks the 3RMICV watchdog. [V]

---

## 12. Monitor calls, STOP and checkpoints

### 12.1 There is no MON opcode

A monitor call is a `CALLG` into a trampoline table in **segment 31**. The MON number is the low bits
of the CALLG target. The real ND-500 Unix kernel does `callg $0xf8000180` = `31 << 27` plus offset
`0x180` = **`0o600`**, the MON number
(`E:\Dev\Ronny\NDIX-C\kernel\MASTER\machine\locore.c:227-239`). [V] The manual writes the table base as
`37B` shifted left 9; the two shift counts (9 versus 27) cannot be reconciled from the sources we have,
and **this document declines to invent one — [OPEN]**. The load-bearing rule survives either reading.

Segment 31 is reached through an **indirect** program capability marked `PC_OMC` = "Other Machine"
(`pcb.h:46,82-84`). The MMU cannot translate it and reports fault code **6**, which the trap table names
*"Indirect capability to another machine"* [M, ND-05.017.01 Appendix A]. [V]

`TRAP_MONC` @`0o12740` is three microwords; applying the one-word condition delay, constant `6` loaded
at `0o12740` and tested at `0o12741` selects **`CALL_MON` @`0o3744`**, and constant `7` selects
**`CALL_DOM` @`0o4020`**. The `.LABE` agrees (`CALL_MON 003744* 012741`, `CALL_DOM 004020* 012742`). [V]

### 12.2 The stop record

`CALL_MON9` @`0o4002`–`0o4012` writes it into the process's **own** activation message — no new message
is allocated. Byte displacements decoded from the raw `LARG` (halfword = byte ÷ 2) [V]:

| Microword | Byte disp | Halfword | Symbol | Value |
|---|---:|---:|---|---|
| `0o4006` | 14 | 7 | `N500A` | saved P (32 bits) |
| `0o4007` | 18 | `0o11` | `STOPR` | **`MOCALL` = 1** |
| `0o4010` | 20 | `0o12` | `NUMPA` | argument count |
| `0o4011` | 22 | `0o13` | `MCNO` | the MON number |
| `0o4012` | — | — | — | **`P := L`** |

Three consecutive halfword slots written by three consecutive microwords, matching the SINTRAN symbol
layout slot for slot.

`0o4012` sets the restart address past the `CALLG` **before the message ever leaves**, which is why
SINTRAN never needs to read the saved P — `MCHANDLE`, `TRAPDECODER` and `DECOMESS` never touch it. The
saved P exists for the histogram path (`3RPREG`) and for a human reading a dump. [V]

**`MICFU` is left untouched**, which is exactly why SINTRAN's `DECOMESS` accepts any of
`{3MONCO, 3TRACO, 3START, 3WMONCO}` and then dispatches on `STOPR`. Two failure modes follow: inventing
a new message breaks `3START` (only the in-place model preserves `MICFU = 0o23`), and overwriting
`MICFU` with anything outside the accepted four makes `DECOMESS` fall through to `5RRTWT` and the call
is **silently never performed**. [V]

`STOPR` values [V]: `1 = MOCALL` (`0o4007`), `2 = TRAPCODE` (`0o13513`, `0o13571`), `3 = 5FMOCALL`
(file-transfer monitor call); anything else falls through to `5RRTWT`. **`65 = TPSTRA` is unverified —
[OPEN].**

### 12.3 The `CALL_END` screening — and a one-off-by-one correction worth recording

`CALL_END` @`0o13613`–`0o13634` screens the MON number. Reading constant and branch as if they lived in
the same word shifts the whole table by one MON number, and an earlier project document
(`MAILBOX-MICROCODE-PSEUDOCODE.md` §3.8) did exactly that. The corrected table [V]:

| MON (octal) | Goes to | Effect |
|---|---|---|
| `515` | `CALL_515` `0o13641` | |
| `117`, `120`, `144` | `CALL_RF` / `CALL_WF` / `CALL_MT` `0o25017` | dump and clear the dirty data cache, then stop normally |
| `201`, `270`, `271`, `333`, `335` | `CALL_DUDC` `0o13633` | same two-word sequence |
| `500` | `CALL_STAP` `0o25027` | start process |
| `501` | `CALL_STOP` `0o25246` | stop process |
| `502` | `CALL_SWIP` `0o25264` | switch processor |
| `600` | `CALL_NDIX` `0o25401` | the one asynchronous case |
| anything else | `CALL_END9` `0o13635` | |

Three independent confirmations of the corrected version: the raw words (`0o13625` loads `500`,
`0o13626` branches to `CALL_STAP`); the semantics (`500` STAPROC = start, `501` NSTOPROC = stop, `502`
SWITPROC = switch — three for three, whereas the shifted reading put "start process" on the *stop*
assist); and the manual's own microcode flowchart, which labels that branch **"Handle MON500-502"**.
The old note was right about the *name* (`SWIP` = SWItch Processor, not SWaPper) and wrong about which
MON reaches it. And `600` does not reach `CALL_SWIP` at all — it reaches `CALL_NDIX`, which is exactly
the call NDIX's `fecall` issues. [V]+[M]

**MON `0o377` is `N5SWAP`, the swapper request.** It stops and carries no microcode assist. [V] The
page-fault path to the swapper is a *separate* mechanism: `TRAP_GEN4` builds the stop record, then
`TRAP_SWAP` @`0o24734` follows `START_MESS + 0x18` into a slot and sets the halfword at `+0x04` to
`6` — the request marker. [V]

> **A base-notation trap worth naming.** The swapper's `CALL 0xF80000FF` is **MON `0o377`** (`0xFF` =
> 255 decimal = 377 octal), not "MON 255B". Reading it as decimal once sent a whole analysis session
> after the wrong monitor call.

### 12.4 How `N5STA` becomes 3 or 4

`TRAP_END` @`0o13606` is three words and the decision is subtle [V]:

    0o13606  SC14 := 0 ; T,PUSH -> GET_FLAG
    0o13607  ALU,A A,RF1 B,X1                 (no destination - sets FLAGS only)
    0o13610  C,ALU ALU,A / ALUF,A-1  A,BM02  D,SC10  COND,MZRO ; T,PUSH -> SET_IDLE

`C,ALU` selects the true-op when the condition holds and the false-op when it does not, and the
condition is `MZRO` on the **previous** word's flags. So:

- run flag **zero** (no process was running) → `ALU,A` → `SC10 := 4` → **`N5STA := 4` (`5ERANSWER`)**
- run flag **non-zero** → `ALUF,A−1` → `SC10 := 3` → **`N5STA := 3` (`ANSWER`)**

**The MON path always sets 3. Only the trap path can produce 4.**

And the conditional an emulator **must** reproduce: `DECOERRMESS` does not throw a trap-shaped
`N5STA = 4` away — it special-cases `TRAPN = 0o46` plus a legal `MICFU` and routes it to the swapper.
**The discriminator is TRAPN + MICFU, not STOPR** — `DECOERRMESS` never reads `STOPR`. Treating
`N5STA = 4` as "error, discard" loses every page fault taken with no process marked running. [V]

### 12.5 STOP — a designed halt, not a fault

**STOP is microword bit 43.** In `Tick()` the check returns *before* the sequencer phase, so `Mpc`
parks on the STOP word itself, not the next one. [V]

**There are exactly ten STOP words in the whole B30 image** [V, counted over the raw bytes]:

| Address | Label | Why |
|---|---|---|
| `0o000006` | `POWER_FAIL` | self-looping park |
| `0o000011` | `SIM_BP` | self-looping simulated breakpoint |
| `0o014325` | `CLTR_ERR` | self-looping control-store error |
| `0o016340` | `DUTRMEM1` | self-looping dump-trace-memory |
| `0o016666` | `DEB_STOP0` | **debug stop** (ACCP async sub-code 2); continues at `0o016667` |
| `0o017472` | `LOOK_HARD_1` | LOOK-AT hardware — halt so the host can read |
| `0o017657`, `0o017663` | `LOOK_SRF_1` | LOOK-AT scratch register file |
| `0o017702` | (`MACRO_STP1` path) | macro-start park |
| `0o017770` | (`SIM_EXEC_1` path) | simulated-execute park |

The self-looping four are genuine dead ends; the rest are **checkpoints** — run a segment, halt, let
the host look, carry on. The ND SEMICS hardware diagnostics are built out of exactly this: e.g.
`E:\Dev\Ronny\ND5000UC\ALU-VERIFY-B00.LABE` is a ladder `START 000100, CHP_1 000105, CHP_2 000152,
CHP_3 000153, CHP_4 000221, …` with the host issuing **CONTMIC** between segments. [V]

**Nothing crosses the bus on a STOP.** A halted CPU simply goes quiet; the host has to notice and issue
a restart. Three ACCP commands mean "run again": `CONTMIC` `0x1D` (continue where it halted), `RESTMIC`
`0x1E`, `STAMIC0` `0x36` (start at the microaddress in the message). **Only `STAMIC0` re-seats `Mpc`.**
[V]

> **A bug worth recording because it looked like a hardware mystery.** Until 2026-08-23 nothing on this
> path cleared `State.Stopped`, so `CONTMIC` / `RESTMIC` woke the tick loop against a CPU still flagged
> stopped and the loop broke straight back out. Measured before the fix: `ALU-VERIFY-B00` executed
> exactly **two** microinstructions — its `START` at `0o100` and the STOP word at `0o101` — and never
> advanced. Also: one *other* site sets `Stopped` and is **not** a designed halt, namely the catch
> block after an unimplemented microword throws. Check `_lastMicrocodeError` before assuming a STOP
> word fired.

### 12.6 The monitor-call park in the emulator

A macro `CALL` or `CALLG` whose target has segment field 31 parks the CPU:

    Regs.L = returnAddress;   // the microcode does P := L before parking
    Regs.P = returnAddress;
    ushort monNumber = (ushort)(target & 0x07FFFFFF);
    if (MonitorCallSink != null &&
        MonitorCallSink.OnMonitorCall(monNumber, argCount, Regs.PendingCallArgAddresses, returnAddress))
    {
        State.Stopped = 1;
        return;
    }

Arguments are passed **by address**: each argument specifier is decoded (advancing P) and its EA
stashed. With no sink attached the CALL throws — an honest halt for a standalone run with no ND-100.
`Tick()` guards the resume: after parking it must not run `FetchAndDispatch()`, or P would advance past
the resume address. [V]

The full round trip really reaches real SINTRAN: swapper MON `0o377` → `Nd5000CpuProcessBridge` →
`servicer.AnswerMonitorCallStop` builds the MOCALL record → level 12 → **real SINTRAN 5STDRIV /
MCHANDEL services it** → `0o24` restart → `Bridge.OnMonitorCallRestart` → the CPU resumes. [V]

---

## 13. Float, the AAP, transcendentals and the vector library

### 13.1 The number format is ND-native, not IEEE-754

Single: 1 sign + 9 exponent (bias 256) + 22 mantissa, with an implicit leading `0.1` so the mantissa is
in [0.5, 1.0); **an exponent field of 0 means exactly zero**. Double: 1 sign + 9 exponent + 54 mantissa.
[V]

### 13.2 What the AAP model actually computes

| AAP_CTRL | Operation | Model |
|---|---|---|
| type 2, op 8 | `AAP2,ADD` | single via host float re-encoded; double via host double |
| type 2, op 16 | `AAP2,SUBBA` | `B − A` |
| type 2, op 0 | `AAP2,SUBAB` | `A − B` (double lanes only) |
| type 2, op 2 | `AAP2,MUL` | single deliberately uses a **double** intermediate so FU can fire |
| 84 | `AAP2,IMUL` | signed integer, width-correct per DATATYPE |
| 86 | `AAP2,IMULU` | unsigned, low 32 |
| 87 | `AAP2,IMULUD` | unsigned, high 32 of the 64-bit product |
| type 2, op 29 | `AAP2,CTF` | int → native single |
| type 2, op 27 | `AAP2,CTI` | native single → int, truncating toward zero |
| `0xFF` | `EXPISO` | post-ALU F-bus transform: `(result >> 22) & 0x1FF` |

**Everything else is a counted no-op** via `Regs.AapOpsIgnored`: all AAP1 operations, and most AAP2
ones (`SUBAB` variants, `ABSSUB`, `MULABS*`, `MULNEG*`, `NEG`, `PASS`, `PASSABS`, `ABSADD`, `ADDABS`,
`CTIR`, `CBF`, `CLEAR`, `IMULD`). B30 uses 16 distinct non-zero `AAP_CTRL` values. [V]

Divide is **not** done by the AAP model — it runs the real microcode (`DIVFI` reciprocal core, `DIV_64`
long divide).

**And the manual explains why divide has to be handled carefully, which is directly relevant to this
project's divide-by-zero adjudication.** ND-05.022.1 §5.5 "Limitations" [M]:

> **The divide function does not set the status bit DZ (divide with zero). Thus both the cases 0/X and
> X/0 should be tested and treated separately when using the divide function.**

That agrees with ND-05.020.01 page 89: *"DZ, divide by zero, is set **by the microprogram** when
division by zero is performed."* So DZ is never hardware-derived — **if a divide-by-zero flag is
missing, the place to look is the microcode's explicit test, not the arithmetic unit.**

The same §5.5 explains two behaviours that otherwise look like bugs [M]:

> In byte and halfword instructions, the type specification in the calling instruction effects the
> input operand(s)… **It does not control the actual result itself, this contains the full word-length
> result from the AAP1.** … when a BY/HW result is sent back to an operand of the macroinstruction,
> **it must first pass through the ALU, with a proper type specification, to cut it down**.

> The instructions CTBY/R and CTHW/R do not set the IOVFL according to type, only word integer overflow
> is detected… **they are of no use, so the CTW is used instead, with special tests for overflow.**

**Latency: the manuals give no cycle counts for any AAP operation.** All they describe is the
handshake [M, ND-05.020.01 §10.1]: *"the AAP reads data, starts the computing and sends a busy signal
to the CPU. From now on the CPU has the control, and has the theoretical possibility to execute any
number of microinstructions. Normally, however, the CPU will issue an AAP synchronization signal and
stop, waiting for the AAP busy signal to stop."* Then *"the CPU must read all the data presented, one
word in each F-cycle."* Our "latency = when the result reaches the F-bus" model is the right shape;
the numbers are [OPEN].

One thing our model does **not** represent: the manual lists **two** sync mnemonics —
`AAPSYNC` ("wait for AAP ready") and **`AAPSYNC1` ("wait for AAP ready, used for least part")**. Our
`Microword` decodes a single `AAPSYNC` bit (42). Where `AAPSYNC1` lives is [OPEN].

**Latency is modelled as "when the result reaches the F-bus", not as cycle counts.** The important
latch is `_aapImulPending`, and the comment explaining it is the clearest statement of the problem:

    // AAP integer-multiply F-bus delivery has a ONE-WORD PIPELINE LATENCY that our same-word model
    // approximates. The common case carries ALU,FZRO ... so the AAP product legitimately OVERRIDES
    // the F-bus ... But THREE words in all of B30 are ALU,A (a REAL ALU output) AND carry Q,F:
    // @024242 (DIVF reciprocal) and @025703/@025730 (EXPF/EXPD). Here the AAP result is presented
    // one word LATER, so THIS word's F-bus carries its ALU,A output - which BOTH the D destination
    // and Q,F read (they share the single F-bus, so they cannot differ).

Delivery fires on the next pure sync word (`AapSync != 0 && AapCtrl == 0`), reusing the *issuing* word's
D field, and is cleared at instruction dispatch so a path that never syncs cannot leak a stale product.
A same-word override was tried on 2026-08-04 and reverted. [V]

### 13.3 The transcendental path

`sin`, `cos` and `exp` all go through the argument-reduction routine **`XREDU_F` @`0o26106`**; `cos` and
`exp` additionally hit the integer-round helper **`INTRF_U` @`0o20343`**, while `sin` does **not** (its
n = 0 fast path at `0o26106` `COND,Q0` skips it). So a bug in `INTRF_U` shows up as "cos and exp red,
sin green" — which is exactly how it presented. [V]

The polynomial kernels live at `0o27030`–`0o27107`: `FAAP*F+F`, `FAAP+F`, `DAAP*F+F`, `DAAP+F`,
`POLLYF*`, `POLLYF++`, `POLLYF+`, `POLLYF**`, the `POLLYD*` set, `RAPPF`, `LAPPF`, `RAPPD`. Their
coefficients are the float constant pool at `0o20014`–`0o20342`, reached by the EXUC sneak trick (§6.4).

Two fixes worth carrying, because both were pipeline problems wearing a maths costume:

- **COS 0.5, fixed 2026-08-04 (commit 67c166c6d).** The straight-line `LCDECR` at `0o20346` inside
  `INTRF_U` must decrement the `D,LC` load at `0o20344` (LC 23 → 22) so the rounding add at `0o20350`
  lands `1<<LC` in the mantissa. The 3-deep LC-load pipeline had the load still in flight, so the
  decrement was discarded, LC stayed 23, `1<<23` hit the exponent, and `INTRF` returned 2.0 instead of
  1.0. Fix: a straight-line `LCDECR` composes into the pending LC-load stages, with divide-step words
  excluded so DIV_64 keeps its required lost decrement. [V]
- **EXP `2^k` scale, fixed 2026-08-08 (commit f2474d265).** The `Q,F` IMUL issue word at `0o25703`
  presents its product one word later, and it must land in the *issuing* word's D destination (SC2) at
  the next pure `AAPSYNC` word (`0o25706`). `exp(1.0)` exponent is now correct (`0x4096FC20`). [V]

**EXP is still red by 10 ULP of mantissa only** (`0x4096FC20` vs a native `0x4096FC2A`). It is **[OPEN]**
whether that is the real B30 polynomial's precision — in which case the microword is right and the
reference is wrong — or a rounding defect in our AAP float multiply/add. **Do not "fix" it before
adjudicating.** A real ND-5000 datapoint would settle it in one measurement.

### 13.4 The vector libraries

`0o30050`–`0o031532` (819 words) is the single-precision array-processing microcode behind
`ND-5000-AF-LIB` (SAX), and `0o31533`–`0o32240` (326 words) is the double-precision one behind
`ND-5000-AD-LIB` (DAX). Both are documented by ND as separate manuals — *ND-500 Single Precision Array
Processing Functions* (05.013.03) and *ND-500 Double Precision Array Processing Functions* (05.018.01)
— **neither of which we have**. [M, from the program-description sheet's documentation list]

The routines are named plainly enough to guess at: `VF_ADD`, `VF_SUB`, `VF_MUL`, `VF_DIV`, `VF_SDIV`,
`VF_DOTPR`, `VF_CLR`, `VF_CONV*`, `VF_SWAP`, `VF_XPND`, `VF_CFFT_BFLY` (complex FFT butterfly),
`VF_MIRR`, `VF_RFFT` (real FFT), `VF_NMO_*` / `VF_NMS_*` (normal-moveout — seismic processing),
`VF_DMXB` (demultiplex), `VF_CONSGD` / `VF_CONSGC`, `VF_PREDICT`, `VF_IMG_*`; and on the double side
`VD_MAXV`, `VD_MINV`, `VD_MAXMGV`, `VD_SVESQ` (sum of squares), `VD_SVS`, `VD_FLNZ`, `VD_CVMUL`
(complex multiply), `VD_TAPER`. **None of this is exercised by any test.** The whole block is
functionally [OPEN].

`AP_INIT_1/2/3` @`0o30050`–`0o30056` are called 26, 24 and 20 times respectively — the common prologue.
`APFUNC` @`0o27640` and its 128-word unlabelled body at `0o27650`–`0o30047` is the array-processor
function dispatcher, and is the darkest block in the image.

---

## 14. What we cannot run yet

Every item here is quantified against B30, so you can tell a theoretical gap from a live one.
**"Sites" = how many words in B30 actually carry the value.** [V] for every count.

### 14.1 Microword field values that throw

| Field | Value(s) | Meaning | Sites in B30 | Verdict |
|---|---|---|---:|---|
| `TESTOBJ` | 24 `PARITY`, 48 `RF1OCT`, 49 `RF2OCT` | parity and the RF-octal tests | **39** (in the BCD/decimal block and DIV_64) | **live gap** |
| `TESTOBJ` | 37 `MFS`, 40 `MFO`, 41 `MFU`, 42 `MDZ`, 43 `MIVO`, 44 `MBO` | AAP status conditions | **0** | dead in B30 |
| `STATUS` | 7 `ST,SAVF`/`ST,SAVB`, 10, 11 | BCD status save and two undefined | **0** | dead in B30 |
| `AB` | 12-15 `X1ORS`–`X4ORS` | index scaled by the instruction's data type | **16**, all in `DESC_X*` `0o3012`–`0o3071` | **live gap** — blocks descriptor range checking |
| `AB` | 8 `CMBRET` | CMISS return | **0** | dead in B30 |
| `SCAL` | 6, 7 | undefined encodings | **0** | dead |
| `MEMORY` | 10 | undefined | **0** | dead |
| `GET` | 2, 12 | undefined | **0** | dead |
| `ORCON.A` | 3 `ORA,ALTEN` | ALT prefix, A side | **70** | **live gap** |
| `ORCON.D` | 3 `ORD,ALTEN` | ALT prefix, D side | **48** | **live gap** |
| `A_OP` | 62 `A,PXBM` | post-index bit mask | **27** | partially implemented; the index inversion is under-specified |
| `B_OP` | 26 (BCD) | BCD B operand | **8** | **live gap** |
| `B_OP` | 31 with `OR_ENABLE` off | | **0** | dead |
| `DATATYPE` | 6 `TYP,DD` (128-bit float) | | **3** (`0o1063`, `0o1075`, `0o32220`) | **live gap**, tiny |
| `GET` | 13 (`G,OPSTRD` — second string-operand specifier) | | **23** | **live gap** |

**The ALT-prefix gap is the interesting one.** 118 microwords carry an ALTEN ORCON, and the B30 change
list says ALT handling was *added* in this release with the caveat *"note that hardware modifications
must be done also to utilize this"* [M]. So the microcode has the path, the shipped hardware may not
have had the wiring, and we model neither. `COND,IRALT` returning `false` is therefore **correct for
this machine** as we run it. [V]

### 14.2 Things that decode fine and quietly do nothing

These are more dangerous than the throws, because they produce an answer:

- **AAP operations outside the modelled set** — counted in `Regs.AapOpsIgnored`, never announced.
- **Cache, trace and diagnostic destinations** (DEST 34-40, 43, 45-48): `D,SPEC,OC,*`, `AC`, `IC`,
  `DCADAT`, `CC`, `FLA`, `CLDCA`, `CLICA`, `CTRACE` — silent no-ops.
- **`RD,ADOM` / `WR,ADOM`** — the alternative-domain address space collapsed onto the normal one.
- **`RD,PX`** — the write-permit check degraded to a plain read.
- **`CCD`** — no cache to clear.
- **`QVACC`** — no look-ahead queue.
- **IDU limits `HL` / `LL` / `LIMC`** — plain registers, **no stack-limit checking at all**.
- **`TIMING` and `MEMOT`** — decoded and ignored.
- **`D,MIC,RESTU`** and **`D,IDU,CSIT`** — faithful no-ops. Making `CSIT` stop throwing alone unblocked
  about 4200 sweep vectors.

### 14.3 Missing metadata, not missing microcode

These throw because the *reconstruction* is incomplete, not because a microword is unimplemented:

- opcode not in the dispatch map (§5.7);
- `ORB,IN` / `ORA,IN` / `ORD,IN` / `A,ALU,REG37` with `InstrRin < 0` — 22 vectors in the sweep;
- `ORD,OP` with a constant operand; `ORD,OP1` with no stored first operand;
- undecoded addressing modes in the operand specifier.

### 14.4 The known-red register

`tests\known-red.txt` holds only **two** deliberate reds, and the file's own header explains the
discipline better than a paraphrase would:

> ONLY genuinely DELIBERATE reds belong here (oracle stand-ins, documented-open blockers). Putting a
> real defect here would encode the bug as "expected green" — the exact failure this whole mechanism
> exists to prevent.
>
> STATUS 2026-08-09: full run 665 passed / 8 failed / 3 skipped. 2 DELIBERATE reds (below) + 6 REAL
> failures deliberately NOT listed (the Smove K=1 defect, tracked as its own task) so the suite stays
> RED until it is fixed.
>
>     Entt_TrapFrame_CannotBeDriven_HardFail
>     Rett_TrapReturn_CannotBeDriven_HardFail

Other documented reds, deliberately kept out of that file so they stay visible:

- `SqrtF1_Value_Manual_sqrt4_is_2_OPEN` — hard-asserted red; the native single-float codec faults at CS
  `0o20400`. *"Do NOT weaken this to a skip — the gap is real."*
- `Transcendental_Value_Manual_OPEN` — EXP 1.0 red by 10 ULP of mantissa (§13.3). SIN and COS pass.
- `FloatTest_NegZero_KnownDivergence` — single-float `−0.0` sign flag. The **double** half of this was
  fixed 2026-08-21 by masking the magnitude before the zero test; the **single** half is still open,
  and the real B30 `TESTF` masks then reads the sign off zero, so it is a genuine tie-break. Trace it
  before touching it.
- `Ents_StackOverflow_Trap_KnownGap`, `Entm_SetsTos_KnownGap` — blocked on the corpus emitting a
  per-vector TOS.
- `IoManualCoverageTests` — RIOM cannot be made privileged from the bare harness, so it takes the
  ILLEG path.
- The **permanent** BI `HCONV` divergence (§5.7e), which is not a defect.

### 14.5 Two live sweep baselines

`JsonVectorSweepTests` is the hard gate: `match = 23957`, `diverge = 1424`, against
`BaselineMatch = 22248` (must not drop) and `BaselineDiverge = 1638` (must not rise), both raised
2026-08-04 by the double half-swap fix. `Nd500xCorpusSweepTests` is a **report**, not a gate — its only
assertion is `total > 0`.

---

## 15. The manuals

Grade: **[M]** throughout, except where it says otherwise. This section exists because two of the four
files sitting in `E:\Dev\Ronny\ND5000UC\manual\` **are not manuals**, and because the two that are have
a hole in exactly the place we need most.

### 15.1 What is actually a manual, and what is not

| File | What it really is |
|---|---|
| `ND-05.022.1 EN ND-5000 Microprogram Guide.md` | OCR of the real manual, 2999 lines. **Pages 5, 13, 17, 23, 45 and 47 failed to OCR** — the file literally contains "I'm sorry, I cannot transcribe…". **Page 13 was the microword bit-layout figure.** |
| `ND-05.020.01 EN ND-5000 Hardware Description.md` | OCR of the real manual, 12929 lines. Several blank or failed pages. |
| `MICROCODE-FIELDS.md` | **NOT a manual.** Project-authored; its own header says *"Based on ND-05.022.1 EN … and SAMSON MICROCODE DEFINITION (15.05.1987)"*. Several rows carry its own `(ASSUMED)` / `(ASSUMING)` / `(TBD)` marks. |
| `mnemonics.md` | **NOT a manual.** Its line 3 says *"Generated from microcode-5000-def.json"* — i.e. generated from **our own** disassembler definition. **Citing it as evidence is circular.** |
| `ND-5000-MICROCODE-FIELDS-derived.md` | **Does not exist.** |

> **A housekeeping recommendation.** `MICROCODE-FIELDS.md` and `mnemonics.md` living in a folder called
> `manual\` next to two real manuals invites exactly the citation error this document had to unpick.
> Move or rename them, and put a provenance header on `mnemonics.md` saying it is generated from the
> project's own definition file and is not evidence. (Not done here — this was a docs-only task.)

### 15.2 The field charts are lost, and their OCR is invented

Both manuals contain a foldout that **is** the definitive 128-bit field chart, and **both OCR'd into
fabricated content**:

- Microprogram Guide **Appendix B**, "SAMSON MICROCODE DEFINITION, Date: 15.05.1987" (lines 2644-2731)
  produced tables reading `SUBMA (A-B) | STF | MOVM | MOVR | STORE | VECT | CPL | STZW | STRW | NIW`,
  `LDAA / ADDR / DIV / A0 / VECTOR / CARRY / INDEX`, `REGLSB`, `ARAM`, `NEGB`.
- Hardware Description **Appendix 3**, "The ND-5000 Microinstruction Format, Date: 15.05.1991" (lines
  11220-11253) produced `ALU|ADD|AND|OR|XOR|INC|DEC|CLR|NOT|XCHG|CMP`, `ACC|BREG|CREG|DREG`,
  `REG0…REG15`, `SRL|SRA|RCL|RCR|ROL|ROR`, `JMP|SJMP|CAL|RET`.

**None of that vocabulary appears anywhere else in either manual.** It is generic-microcode boilerplate
the OCR invented. **Anything derived from those two blocks is poison.**

The real charts survive only in the PDFs — `…Microprogram Guide.pdf` pages 75-76 and
`…Hardware Description.pdf` Appendix 3. **They need re-scanning by eye.** That is the single cheapest
piece of work on this whole list, and it would upgrade dozens of [D] field encodings to [M].

### 15.3 Which field encodings are genuinely manual-backed

| Field | Encoding source | Status |
|---|---|---|
| ALU function (127-124 / 121-118) | **HW-desc Table 31, §9.4 page 248** — all 16 codes printed | **[M], solid.** Matches our decode exactly. |
| ALU carry select (123-122 / 117-116) | mnemonics only (Guide App. A 23-25, 49-51) | [D] for the 2-bit codes |
| Q-register (113-111) | **HW-desc Table 33, §9.8 page 252** — all 8 codes | **[M], solid** |
| Sequence + stack (68-65, 64-61) | **HW-desc Table 24, §8.4 page 216** — printed in full | **[M], solid** |
| Sequence bit names | HW-desc Table 23 page 211: `69 CSEQ`, `60 ISEQ`, `65-68 TSEQ`, `61-64 FSEQ` | [M] |
| AAP type (110-108) | **HW-desc Table 35** — `000 no AAP`, `001 ND-570 FPU`, `010 ND64/65 NMOS` | [M] |
| AAP1 function (107-103) | **Guide Table 2 page 27** — all 32 codes | **[M]** |
| AAP2 function | mnemonics only (Guide App. A 600-639) | **[D] — from the lost chart** |
| MMS sub-registers (A-op group 010) | **HW-desc §6.6 pages 174-177** names each with its ordinal: PSTP 0, PUWP 1, LA 2, WR 3, CAP 4, PS 5, PHS 6, DOM 7, STS 11, DIRTY 14, ADOM 15 | **[M], exact match to our table** |
| MIC registers (A-op group 100) | **HW-desc §8.9** gives hex 80H-87H: MISTS, VECT, RFA1, RFA2, STS, TE, CUR/BRK, CNT32 = octal 200-207 | **[M], exact match** |
| AA (15-13) and AB (12-9) | **HW-desc Table 18, §7.4.5 page 202** — all codes printed | **[M]** (note it names AA=2 `AA,DPA`, not `AA,DISP`) |
| Data type (100-98) | Guide App. A lists the mnemonics *in order*; HW-desc :8305 confirms `111 = TYP,DR` | [D] from list order, one point confirmed |
| Memory (41, 34-32) | Guide App. A lists the 16 mnemonics in order | [D] from list position |
| Timing (102-101) | Guide App. A names SLOW1 = 110 ns and SLOW2 = 160 ns; **no numeric codes anywhere**, and "SLOW3" appears in neither manual | **[OPEN]** |
| A-op, B-op, DEST, STATUS, TESTOBJ, GET, TBC, ABR, SCAL, ORCON codes | mnemonics and meanings are in the manuals; **the numbers come only from the lost chart** | **[D]** |

Two independent consistency checks that the [D] encodings pass: HW-desc :6922 says *"the source field
in the microprogram activates the DAC when the three leftmost bits are all set"* — confirming A-operand
group `111 = DAC`; and HW-desc :8348 says *"those test objects with the MSB of the mentioned microcode
field equal to 0 are generated in the ALU gate array"* — matching our TESTOBJ grouping. HW-desc :8142
also says **"39 different test objects can be selected"**, and our table has 39.

### 15.4 Manual-versus-manual contradictions

These are real, and they are the reason several project decisions had to be settled by execution rather
than by reading.

**1. One sneak cycle, or two?** Guide §7.2 / §7.3.4 describe **one** extra cycle for a non-JMP sequence.
Guide §7.3.5 and HW-desc §8.7.1 describe **two** (EXCYC1 and EXCYC2) for a conditional sequence. §7.3.5
rule 1 makes it sharp by naming EXCYC1 as the first *of two* — where §7.3.4 leaves room for only one to
exist at all. Both texts are quoted in full in §6.4 and §6.5.

*A resolution that fits every sentence* [D, mine — neither manual says this]: the two counts describe
**different situations**. **One** sneak is the cost of a non-JMP *unconditional* sequence. **Two** is
the condition-resolution latency of a *conditional* sequence (HW-desc §8.6.1: *"the condition to be
tested upon is not valid until two clock cycles after the instruction enters the pipeline"*). §7.3.4's
blanket wording simply does not carve out the conditional case, which is why it reads as a
contradiction. Our engine's rule is consistent with that reading.

**2. Does the sneak word's stack operation happen?** Flat contradiction, same sentence, two manuals:

- Guide §7.3.4: *"Both stack and sequence instructions in the extra cycle are then **ignored**."*
- HW-desc §8.7: *"The stack instruction in the extra instruction **is carried out** when EXUC is TRUE,
  while the sequence instruction is always invalid."*

HW-desc §8.7.1 further qualifies: EXCYC1's stack instruction is not executed *"if the pipelined stack
control from the previous cycle is nothing but HOLD"*; EXCYC2's stack control is valid *"unless EXCYC1
was also a conditional instruction"*; and — a rule the Guide never gives — **"EXUC = TRUE only in
EXCYC1 is not legal."** Our engine follows the Guide (ignores the sneak's stack op). **[OPEN]**

**3. One-instruction subroutines.** Guide §7.1: *"a one cycle microinstruction subroutine is **not
possible**."* HW-desc §8.5.2: *"**Unconditional calling of a one-instruction subroutine is possible**
because the RETURN instruction takes two cycles."* HW-desc §8.6.3 restricts it only in the conditional
case. The HW-desc is the more specific and more mechanistic statement; the Guide's blanket "not
possible" looks like a simplification. [D]

**4. What does JMPREL add to?** HW-desc Table 24 and §8.3 say **jump address + VECT**
(`CSA <= CI(16:31)+VECT`). HW-desc page 211 and page 215 say **current address + VECT** (*"A new address
is generated by adding the vector to the lower half of the current address and extending the carry from
bit 7"*). Our engine implements jump-address + vector, and every traced table (MICFU at `0o15224`, kicks
at `0o16430`, async traps at `0o16623`) is consistent with that. **[OPEN]** in the manual, settled in
practice.

Note the vector is **8 bits** with carry propagation into the upper half — which caps a `JMPREL` table
at 256 entries and explains why the async-trap table is exactly that size.

**5. S1 status-bit ownership.** Guide chapter 9 gives three lists ("bits in S1 residing in the MIC /
IDU / ALU") that disagree with HW-desc Tables 6, 16 and 30. The Guide's lines look scrambled.
**Trust the HW-desc tables.** [OPEN]

**6. Mini-argument width.** Guide ch.2 says bits **7-0**; Guide §11.3 says *"control store bits
**8-0**"* in the same sentence as "one 8-bit integer". 7-0 is consistent with ORCON at 5-0 and SCAL at
8-6; the microcode agrees. [V] over [M].

**7. AAP1 codes `10100` and `10110`.** Guide Table 2 marks both **Unused**. `MICROCODE-FIELDS.md`
invents `AAP1,A-B` and `AAP1,A/B` for them. **Trust the manual.**

**8. `EXPISO`'s home.** HW-desc :8237 describes it as a standalone microword bit called **`FLSH`** —
*"bits 30 to 22 of the result are shifted into bits 8 to 0 of the F-bus… used to speed up operations on
exponents in floating-point arithmetic"* — and never gives its position. `MICROCODE-FIELDS.md` places it
as AAP type `110`. Our engine implements it at `AAP_CTRL = 0xFF`. Three placements, one function.
**[OPEN]**

### 15.5 Things the manuals simply do not contain

| Item | State |
|---|---|
| The 128-bit field chart | **Lost.** Only the PDFs have it. |
| Bits 8-6 (SCAL) and bit 36 | Absent from the ch.2 table entirely |
| Numeric codes for A-op / B-op / DEST / STATUS / TESTOBJ / GET / TBC / ABR / ORCON | Mnemonics documented, **codes only from the lost chart** |
| AAP per-operation latency | **Silent.** Only the busy handshake |
| **AFLAG bit layout** | **Silent.** Exactly one line exists in either manual: Guide Appendix A, `A,SPEC,AFLAG | A-BUS | IS ACCP-FLAG-REGISTER`. The Hardware Description **never mentions AFLAG at all.** |
| Which three MREG bits the microcode can read | HW-desc says *"Three of these bits can be read as an A-operand by the microprogram"* and then **never says which three** |
| "P1" | **Does not exist** in either manual (§7.4) |
| "B-latch" | Not by that name; the elements are `PRA` / `PRB` |
| IMAP entry-point field width, ICHAR bit layout, OMAP's 18-bit layout | Named, never enumerated |
| The O-bus field layout (HW-desc Table 19) | OCR-destroyed |

**On AFLAG specifically**, since it is one of the sharpest open questions: what the manual *does* give
is the ACCP **modus register (MREG)**, Table 8, whose upper byte *"is reset when the microprogram in
the ND-5000 reads AOB"*:

| bit | name | pol | function |
|---|---|---|---|
| 0-7 | FAST, SLOW, AMODE, MRUN, ORESEN, MLOCK, MR, MASKOBT | | lower byte, reset by hardware reset |
| 8 | BUSTEST | 1 | route data DB→XB→IB→DB (AMODE only) |
| 9 | AECC | 1 | ACCP enable control cache |
| 10 | AECS | 1 | ACCP enable control store |
| 11 | OMESS | 1 | Octobus message in AOB |
| 12 | ATRAP | 1 | ACCP trap signal to the ND-5000 |
| 13 | FATAL | 1 | ACCP fatal trap signal to the ND-5000 |
| 14 | AOBF | 1 | AOB contains valid data |
| 15 | OBACT | 1 | Octobus activity LED |

The three microcode-readable bits are *plausibly* OMESS, ATRAP and FATAL — they are the three that
carry ACCP→microcode signalling and they all sit in the AOB-reset upper byte. **[D] — the manual does
not say this. Do not present it as fact.** And **nothing anywhere connects MREG bit numbering to AFLAG
bit numbering**, which is why "AFLAG bits 7 and 8" cannot be checked against these documents at all.

For completeness, the two neighbouring registers that *are* fully specified, in case something called
"AFLAG bits 7/8" was really one of these: **ASTS** (the access-module status register, HW-desc Table 7,
all 16 bits given — bit 7 is `IMMBUSY`, bit 8 is `CSERR`) and the CPU's own **Modus register**
(HW-desc Appendix 4, 24 bits — bit 7 is `DISIC` "disable instruction cache", bit 8 is `PSLOW1`, and
bit 23 is `ACPTRAP` "trap from microcode to ACCP").

### 15.6 Manual facts worth having that appear nowhere else in this document

- **The control store is duplicated and compared.** ASTS bit 8: `CSERR — "Control store error.
  (Duplicated bits not equal)"`. [M]
- **Control-store load format.** `LOCSM` (load via memory) takes a block of: word count *N*, control
  store address, then each microword as **8 big-endian 16-bit halfwords, most significant first**, then
  a checksum addend. *"While loading, the checksum is calculated by 16-bit addition of all the words
  (byte pairs) including the checksum addend. If the result is zero, the loading is assumed to be OK."*
  [M] `LOCSD` does one word directly over the octobus. `DCSD` / `DUCS` are the dump counterparts.
- **The path is the serial-shadow-register loop.** The ASR/APR pair *"is not used during program
  execution, but only during testing when access to the entire 32-bit bus width is desired. The ASR/APR
  is also used during 32-bit access to MFbus memory, i.e. when loading the control store."* Physically
  `Am29818`-class devices reaching the microinstruction register itself. [M]
- **Single-stepping the microprogram** is officially supported: *"Single-stepping of microprograms can
  be achieved by setting the STOP-bit in every microinstruction and using this command [CONTMIC] to
  step one instruction at a time."* [M]
- **A micro-breakpoint register exists in hardware.** `BRK`, loaded through destination `86H` (low 16
  bits), read back through A-operand `85H` (in the *high* 16 bits, packed with the trap-enable
  register), compared against `CUR` with the result on a pin called `MICEQ`. Note the aliasing trap:
  **destination `86H` writes BRK but A-operand `86H` reads CUR.** [M]
- **The macro-level breakpoint** is status bit 20 `BPT`, and *"the P-register has not yet been changed
  when the trap occurs; this conforms to the **before** category that this trap belongs to."* [M]
- **`PGF` and `THM` have no readable status bit.** *"Trap 37: THM, trap handler missing, does not have
  an actual bit in the status register, because it would always be zero when tested."* and *"Trap 38:
  PGF, page fault, is exactly the same type as trap 37."* **Do not model page-fault as a settable,
  testable flag.** [M]
- **The MMS trap code is 4 bits with 16 defined values** [M, HW-desc STS-11 page 176]: 0 address out of
  range / 1 alternative protect violation / 2 write protect violation / 3 index error / 4 memory error
  / 5 memory timeout / **6 indirect capability to another computer** (this is the monitor-call path,
  §12.1) / 7 indirect capability within the computer / 8-11 zero in the capability (with protection
  variants) / 12 zero in last-level index entry for PS / 13 zero in physical segment table entry / 14
  zero in second-level index entry / 15 zero in last-level index entry.
- **Trap masking has a rule that is easy to miss** [M, Guide Table 1 page 15]: *"Hardware trap enable
  register is either **MTE** when inside trap handler or **MTE OR'ed with OTE** when outside trap
  handler."*
- **Late IMM traps are a documented hazard**: *"When an IMM trap occurs as result of A-operand memory
  read or destination memory write, the IMM trap arrives one microclock too late to stop the destination
  clocking. **Such microcoded sequences must tolerate this late arrival of the IMM trap.**"* [M]
- **The SC naming radix trap.** HW-desc Table 34 lists the top scratch block as "SC5-SC12"; the Guide
  and the microcode say `SC5, SC6, SC7, SC10, SC11, SC12, SC13, SC14`. **These agree** — the
  Guide/microcode names are *octal*, so SC10-SC14 octal is 8-12 decimal. Eight registers either way.
  It is a naming-radix trap, not a discrepancy.
- **The WRF solves read-before-write in hardware**; the SRF does not. Guide page 16: *"All 'read before
  write' problems are solved in hardware [in the WRF]. The SRF is accessed through a single port (bus),
  and the microprogram must know of the pipeline peculiarities."* Concretely: *"A scratch register file
  register written in one microinstruction, cannot be read in the two following microinstructions."*
  And when reading through an address register, *"this must be set two cycles before"*; when writing,
  *"the address may be set in the previous cycle."* [M]
- **SRF allocation.** *"In the SRF, from address 0 to 15, SRF0 to SRF15, and from SRF address 2000B to
  7777B, registers are allocated for special use and should be used as read only. **Constants used in
  the mathematical functions are allocated from address 4000B.**"* [M]
- **The ORCON / sequencing coupling**, which is genuinely surprising [M, Guide §4.2]: *"When OR-logic is
  used for accessing an already decoded operand, the OR-logic is done in the microinstruction executed
  prior to the cycle using the OR-logic. **If the sequence is different from JMP, the microinstruction
  pointed to by the jump field will give OR-logic control for the microinstruction to use the
  OR-logic.**"* — i.e. with a non-JMP sequence, the ORCON that takes effect comes from the **sneak**
  word. Also: *"After fetch (G,OOPS or G,OPS, etc.), the ORCON field is not used."*
- **The manual's own worked example** is the best single validation target for an ADACT/ORCON
  implementation [M, Guide page 22] — instruction `H ADD2 B.24,R.O`:

      G,OOPS                                  % end of previous instruction
      ALU,A ORA TYP,OR D,SC5                  % use ORed data type
      ORA,OP                                  % A ORed 1st operand
      ADACT READ                              % activate read B.24B
      EA1SAVE                                 % save address B.24B
      G,OPS                                   % fetch next operand
      NEXT*;
      ALU,A+B ORA B,SC5 TYP,OR D,SC5 ST,SAVA
      ORA,OP                                  % A ORed 2nd operand
      ADACT READ                              % activate read R.O
      ORD,OP1                                 % dest. is 1st operand
      AB,EA1DIR                               % give address latch
      OR,N                                    % and OR-logic in next
      NEXT*;
      ALU,A A,SC5 TYP,OR
      WRITE                                   % write to 1st operand
      ORD                                     % in case of register
      G,OOPS;

  Note `AB,EA1DIR` reusing the saved first-operand address for the write-back — that is the intended
  idiom, and it is why `EA1SAVE` exists.

---

## 16. Unknowns

**What we would ask the people who designed this machine.** Ranked by how much each one unblocks.
Every entry says: what we do not know, why it blocks us, what we assume instead, and what evidence
would settle it.

---

### 1. What are the actual contents of IMAP?

**Don't know:** the entry point, ICHAR bits, OPTYP bits and RIN for each of the ~1276 macro opcodes.
The maps are combinatorial logic in the IDA's PAL bank and/or inside the `ND-S-IDU` LSI (IMAP on the
mother card, OMAP on the IDA baby card). **There is no ROM image and there never will be a software
route to one.**

**Blocks:** everything downstream of dispatch. 1053 of our 1183 map rows are reconstruction; 21
single-byte and 76 two-byte opcodes are unmapped; **28 named instruction entry points in the microcode
have no opcode that reaches them** (§5.7b). We also do not model ICHAR at all, so any instruction
characteristic it carries is silently absent.

**We assume:** `DispatchMapB30.g.cs` — entry from a `.LABE` label matching mnemonic + datatype, RIN
from the trailing digit of the mnemonic, dataType from the type prefix.

**Would settle it:** reading the **PAL fuse maps** off a real 324718 (and 324708) with a PAL reader, or
reversing the ND-S-IDU LSI. Failing that: an ND internal IMAP source listing or programming sheet.
Second best, and achievable today: run the 28 orphan entries against the functional core and see which
opcodes produce matching behaviour.

---

### 2. What is in the OMAP, and what is its 18-bit layout?

**Don't know:** the manual says OMAP is 18 bits × 256, addressed by the ADDR-CODE byte, and *"gives
information about the operand, and also the illegal address code signal to the IOS trap"* — and never
enumerates the bits.

**Blocks:** operand decoding. Our `OperandRouter` throws on *"Operand specifier 0x?? not implemented
yet"* for undecoded addressing modes, and Table 19 (the O-bus field layout) is OCR-destroyed so we
cannot even reconstruct the field positions.

**We assume:** a hand-written operand decoder that covers the modes the corpus exercises.

**Would settle it:** the same PAL/LSI read as #1, or an intact scan of HW-desc Table 19 page 203.

---

### 3. Re-scan the two lost field charts.

**Don't know:** the numeric encodings for A-operand, B-operand, DEST, STATUS, TESTOBJ, GET, TBC, ABR,
SCAL and ORCON. These exist in print — Microprogram Guide Appendix B (SAMSON MICROCODE DEFINITION,
15.05.1987) and Hardware Description Appendix 3 (15.05.1991) — but **both OCR'd into hallucinated
generic-microcode vocabulary** (§15.2).

**Blocks:** every one of those encodings is currently [D], sourced from `MICROCODE-FIELDS.md`, which is
itself derived from the lost chart. That is dozens of load-bearing values with no checkable provenance.

**We assume:** `MICROCODE-FIELDS.md` is right, on the strength of two spot-checks that passed (MMS
sub-addresses and MIC 80H-87H) and one that failed (AAP1 `10100` / `10110`).

**Would settle it:** **someone opening the PDFs and reading pages 75-76 by eye.** This is the cheapest
item on the entire list and it would upgrade the largest number of claims.

---

### 4. Does EXCYC1 run when a conditional word's TRUE-field JMP is taken?

**Don't know:** §7.3.5 rule 1 says *"If EXUC is TRUE in the conditional sequence instruction, the
EXCYC1 is executed at all pipeline levels"* — with no exception. §7.2 says a correct jump guess costs
no extra cycle, and §7.3.4 says the sneak exists only for NEXT / RETURN / JMPREL. These cannot all be
complete.

**Blocks:** it changes how often the sneak fires across the whole image (345 words set EXUC), which
changes register writes, LC decrements and saved conditions.

**We assume:** §7.2 / §7.3.4 — no sneak when the TRUE-field JMP is taken. Calibrated on `SHIFT_ROT`
@`0o17070`, where firing on every pass double-decrements LC past zero and hangs.

**Would settle it:** a hardware trace, or a single carefully chosen microprogram run on real silicon.
Or an ND designer saying which of the three sentences is the simplification.

---

### 5. Does EXCYC2 run in the loop-exit shape, and what is the right rule?

**Don't know:** rule 2 says EXCYC2 runs when EXUC is set in both the conditional word and EXCYC1. We
implement that and then **suppress it when the second sneak's target is the conditional word itself**
(the loop-exit shape), because running it makes the integer divide's quotient **double** (expected 6,
got 13). Forward chains genuinely need it.

**Blocks:** the known cost is that DIV_64's second loop misses its 32nd low-quotient bit, so the low
mantissa word carries about a 2^-24 relative error on non-terminating quotients. 47 EXCYC2 sites exist
in each of A30 and B30; roughly three suppressed hits occur per cold boot.

**We assume:** suppress when `sneak2Address == Mpc`.

**Would settle it:** a third source on §7.3.5 rule 2 — specifically how the **LC pipeline** interacts
with a suppressed or executed EXCYC2. HW-desc §8.7.1's extra qualifiers ("EXUC = TRUE only in EXCYC1 is
not legal"; EXCYC2's stack control valid *"unless EXCYC1 was also a conditional instruction"*) hint that
the real rule is finer than either manual states.

---

### 6. Does the sneak cycle's stack operation happen?

**Don't know:** Guide §7.3.4 says *"Both stack and sequence instructions in the extra cycle are then
ignored."* HW-desc §8.7 says *"The stack instruction in the extra instruction **is carried out** when
EXUC is TRUE."* Flat contradiction, same sentence, two manuals.

**Blocks:** subroutine nesting depth and return addresses through any EXUC-heavy routine. The stack is
only four deep, so a spurious push loses word 4.

**We assume:** the Guide — ignore the sneak's stack op.

**Would settle it:** trace the stack depth through a routine with a known nesting pattern on real
hardware, or resolve HW-desc §8.7's two qualifier clauses (the HOLD condition on EXCYC1 and the
"unless EXCYC1 was also conditional" condition on EXCYC2), which read as if someone knew the exact rule.

---

### 7. What sets AFLAG bits 7 and 8?

**Don't know:** **the manuals contain exactly one line about AFLAG** — Guide Appendix A,
`A,SPEC,AFLAG | A-BUS | IS ACCP-FLAG-REGISTER`. The Hardware Description never mentions it. There is no
bit layout anywhere, no statement that AFLAG bit *n* equals MREG bit *n*, and no list of which three
MREG bits the microcode can read.

**Blocks:** bits 7 and 8 are believed to be the data-fault and instruction-fault signals set by the MMS
hardware, and they were **never re-verified after the off-by-one correction** that fixed the rest of the
AFLAG map. Deliberately not modelled — correct for octobus work, wrong the moment MMS traps are
modelled through AFLAG.

**We assume:** nothing. They are not modelled.

**Would settle it:** the schematic, or the ACCP/CPU interface print. In the meantime the *microcode*
can answer it: find every word that reads `A,SPEC,AFLAG` and see which bits it masks and what it does
on each. That work has been done for bits 5, 6, 11, 12 and 13; bits 7 and 8 have not.

---

### 8. Is the AOB read clear narrow or wide?

**Don't know:** ND-05.020.01 **contradicts itself**. Table 8's own note says bits **8-15** of MREG reset
when the ND-5000 reads AOB (**wide**); the prose at :3484 and :3683 names only **AOBF and ATRAP**
(**narrow**).

**Blocks:** every `0xF0` delivery — the firmware's way of asserting FATAL — decays into FATAL-set /
ATRAP-clear the instant the microprogram reads AOB under the narrow reading. Which is exactly the
stimulus you would inject to test FATAL causation. **Run that experiment under both readings and report
the pair, or you will measure your own code and publish it as hardware.**

**We assume:** narrow (`AobReadClearsWide = false`).

**Would settle it:** the schematic. **The microcode settles nothing here** — `ACCP_READ` reads AOB at
`0o16374` and returns without re-testing anything, and there is no microword anywhere that reads AOB
then re-tests an AFLAG trap bit.

---

### 9. Is the ADACT displacement direct, or `EA + (n−4)`?

**Don't know:** two of this project's own documents assert opposite conventions, each claiming
verification (§9.4).

**Blocks:** getting it wrong shifts every hand-built mailbox or PCB layout by 4 bytes — silently.

**We assume — and this document recommends:** **direct**, consumed by the next word's memory operation.
Three independent lines now agree: (a) the contested field is **MARG**, not ORCON, because `OR_ENABLE`
is **zero** on every word both sides cite; (b) on the message header, whose displacement chain does not
step by 4, only the direct reading produces a working MICFU dispatch; (c) **ND-05.020.01 Table 20**
lists every addressing mode as a plain sum (`DPA + B => EA0`, `DPA + R => EA0`, `DPA + 0 => EA0`) with
**no `−4` term anywhere**, and the `+4` that does exist is a separate parallel adder *"intended for
double floating operands"*.

**Would settle it for good:** Ronny adjudicating, and the losing document being corrected in place
rather than left to contradict this one.

---

### 10. What do the undocumented ACCP command arms do?

**Don't know:** `0x10` `CMREA` returns 16 words from `114550` (a signature block) — purpose unknown.
`0x17` is a **fourth "start" variant** (latch enable, then set the running flag) that appears in no
manual. `0x1E` `RESTMIC` — only the parameter shape is carved (CS address + interval); what the arm
body drives is unknown. `0x1F` `ALIVE` — only the *negative* answer is carved (nak 7 = "not alive");
what it probes is unknown. `ENKICK` issues **ACON `0x08`**, which is absent from the manual's Table 9.

**Blocks:** a faithful ACCP model, and therefore any bring-up sequence that depends on them.

**We assume:** the carved shapes; the bodies are stubs.

**Would settle it:** more work on the real dumped ACCP firmware (`octo.bin`, ND-324716), which we
*have* — this is one of the few items on this list that is closable with material already in hand.

---

### 11. Which MICFU numbers mean what on the *classic* ND-500?

**Don't know:** on B30, `0o34` = IMEMRD and `0o46` = DUDC [V]. Whether the classic ND-500 microcode
assigns them the same way is **unverifiable — no classic message-path microcode survives**. `0o17`
`3DEPR` being classic-only is a family inference, and the sender that stores `MICFU := 0o17` is not
locatable in the available NPL. SINTRAN's `N5XXC` marks `46/47/50/51` illegal while B30 assigns them
real handlers, and slot `52` is `NKREL` on the ND-100 side versus `UNIX5REL` on B30.

**Blocks:** any attempt to model a classic ND-500 message path, and it makes "which machine are you
modelling" a question you must answer before writing code.

**We assume:** B30's assignment, and we say so.

**Would settle it:** a surviving classic ND-500 microcode image with a message path. (The 144-bit
`CONT-STORE-10611.DATA` exists but has not been checked for one.)

---

### 12. `A,PXBM` — the post-index bit mask.

**Don't know:** the index inversion rule. We latch `Pababm = (~Wrf[Ab−4]) & 7` at ADACT when
`SCAL == 4`, which reproduces the functional core's `BitPosition`, but the manual's `~XSEN(0-2)`
description is under-specified.

**Blocks:** 27 microwords use `A,PXBM`. Bit-field instructions on bit-addressed operands.

**We assume:** `7 − (Xindex & 7)`.

**Would settle it:** ND-05.020.01 §9.13 (Bit Mask Generator / PABABM) in an intact scan, or a targeted
run of the bit instructions against the functional core across all 8 bit positions.

---

### 13. `G,OPSTRD` — the second string-operand specifier.

**Don't know:** what it does beyond "fetch a second string-operand specifier and set the string-dest ALT
flag". 23 microwords carry `GET = 13`.

**Blocks:** the string instructions that take a second descriptor. Tied to the ALT-prefix gap below.

**We assume:** unimplemented, throws.

**Would settle it:** the ND-500 Reference Manual's string-instruction chapter plus a trace.

---

### 14. The ALT prefix — is it wired at all?

**Don't know:** 118 microwords carry an ALTEN ORCON (70 on the A side, 48 on the D side). The B30 change
list says ALT handling was **added in this release**, with the caveat *"note that hardware modifications
must be done also to utilize this"* [M].

**Blocks:** alternative-domain string moves and `BMOVE`. We also collapse `RD,ADOM` / `WR,ADOM` onto the
normal address space, so even the non-prefix alternative-domain path is an approximation.

**We assume:** ALT is not decoded (`COND,IRALT` returns `false`), which is correct for a machine without
the hardware modification.

**Would settle it:** knowing whether any shipped ND-5800 ever had the modification, and what it was.

---

### 15. `ST,SAVF` / `ST,SAVB` and the AAP status conditions.

**Don't know:** what STATUS values 7, 10 and 11 do, and what `COND,MFS` / `MFO` / `MFU` / `MDZ` /
`MIVO` / `MBO` read.

**Blocks:** in principle, float and BCD status. **In practice, nothing on this image**: STATUS 7/10/11
appear **zero times** in B30, and the six AAP-status conditions appear **zero times**. [V]

**We assume:** they throw, which is honest and never fires.

**Would settle it:** low priority. But note the *real* float-status gap is elsewhere: `ST,SAVF` is
listed in the Guide as *"Save status from floating operation"* and B30 evidently uses `ST,SAVM` /
`ST,ACCM` instead, and the manual explains why — *"There is no status code for integer types that takes
sign and zero from the AAP1, and also sends the AAP1 overflow to the integer overflow status bit"* [M].

---

### 16. `AB,X1ORS`–`X4ORS` — index scaled by the instruction's data type.

**Don't know:** the exact scaling rule when the operand's type differs from the instruction's.

**Blocks:** **16 microwords, all of them the `DESC_X*` descriptor helpers at `0o3012`–`0o3071`** — i.e.
descriptor range checking, which is the whole ND-500 bounds-check mechanism.

**We assume:** throws.

**Would settle it:** the descriptor chapter of the ND-500 Reference Manual, plus the fact that
`AB,X1ORS` is documented as *"Index register 1 scaled according to data type of instruction"* — so the
scale is `DispatchEntry.DataType`, which we already have. **This one looks cheap to close.**

---

### 17. Is EXP's 10-ULP mantissa gap ours or the machine's?

**Don't know:** `exp(1.0)` gives `0x4096FC20` where IEEE-native rounds to `0x4096FC2A`. The exponent is
right; the mantissa is 10 ULP low.

**Blocks:** it is a permanent red test, and until it is settled nobody can tell whether the AAP float
multiply/add model is subtly wrong (which would affect *everything* float) or whether the real B30
polynomial is simply that precise.

**We assume:** nothing — the test stays red and is not "fixed".

**Would settle it:** **one datapoint from a real ND-5000 running `F EXP` on 1.0.** That is the entire
requirement. It is on the standing datapoint-request list.

---

### 18. `SRF17` — is it `X5CPU + 1` or `N5STA + 1`?

**Don't know:** `CNTXTLOAD` computes the PCB base as `SRF17 × 256 + 0x800`. Two project documents give
different sources for `SRF17`, and the microword at `0o15211` is where it is written.

**Blocks:** the context load lands at the wrong PCB if this is wrong — which means every register in a
loaded process.

**We assume:** `X5CPU + 1` (the skill's version).

**Would settle it:** decoding `0o15211` from the raw bytes and reading what it actually stores. **This
is a ten-minute job that nobody has done.**

---

### 19. What is in `0o27650`–`0o30047`?

**Don't know:** 128 consecutive live words with **one** label (`APFUNC_V`), the array-processor function
vector body. The largest completely unexamined stretch in the image.

**Blocks:** the whole `AP_*` / `VF_*` / `VD_*` vector library, 1145 words of which nothing is tested.

**We assume:** nothing.

**Would settle it:** the two array-processing manuals ND-05.013.03 (single precision) and ND-05.018.01
(double precision), which ND lists as documentation for this microprogram and **which we do not have**.
Also `ND-5000 Design Information` (ND-05.021.01), listed on the `211276A` sheet and likewise missing.

---

### 20. `A,SARG` — sign-extended or zero-extended?

**Don't know:** the manual says *"the short argument is sign extended to 32 bits by A,SARG"*
[M, §11.3]. Our `OperandRouter` zero-extends and grades the choice [D].

**Blocks:** anywhere a SARG constant has bit 15 set — and the ACCP command words (`0o100501`,
`0o100401`) do.

**We assume:** zero extension, on no stated evidence.

**Would settle it:** find a B30 word using `A,SARG` with bit 15 set and trace what reaches the F-bus.
**Also a ten-minute job.**

---

### Runners-up, briefly

21. **`TESTOBJ 38`'s real mnemonic.** Behaviour is corpus-verified (`OcaKind == 1`, "operand is a
    register"); the name is unresolved and must not be written down as "IDRY".
22. **The `CAD :=` opcode.** Chapter 12 says entry `1765` = opcode `0o177502`; the `211276C` sheet says
    opcode `0o176672`. One is stale (§5.5).
23. **The segment-31 MON table shift**: the manual writes the base as `37B << 9`, NDIX does
    `31 << 27`. Unreconciled.
24. **The message LINK width** at `0o17454` — the raw memory field matches the halfword pattern while
    the pseudo-code models a 32-bit link.
25. **Kick word bit 8 (`0o400`)** differs between the `0o1005nn` and `0o1001nn` families and the
    decoder never tests it.
26. **`SAMSON_CPU`: 0-based or 1-based in the B30 image?** SINTRAN's layout is 1-based; the image
    carries constant 0.
27. **Why SINTRAN-K's real extension block sits at `+0x610`** rather than `cpu*256` from `START_MESS`.
    Measured, unexplained.
28. **Where `AAPSYNC1` lives** in the microword (§13.2).
29. **`EXPISO` / `FLSH`** — AAP type code, or its own microword bit? Three sources, three answers.
30. **The trap-name table.** Trap numbers run `0..0o53` and we have no symbolic names for most of them.
    Nothing has been guessed.

---

## Appendix A — single-byte opcodes

230 rows. Entry is OCTAL. Grades: `M-ch12` [M]+[V]; `D-labe`, `D-conv`, `D-3src`, `D-func`, `D-ndix`
all [D]; `?` = an individually argued one-off (see the trailing comment on that row in
`src\Generated\DispatchMapB30.g.cs`).

Opcodes `0x00`, `0x01`, `0xBB`, `0xE2`, `0xE3` and `0xEC`-`0xFB` are **absent** — unmapped, and they
throw. `0xFC`-`0xFF` are escape prefixes, not opcodes.

| opcode | octal | mnemonic | entry | label | rin | dt | grade |
|---|---|---|---|---|---|---|---|
| `0x02` | `2` | BP | `201` | BP | - | ? | D-labe |
| `0x03` | `3` | NOOP | `202` | NOOP | - | ? | D-labe |
| `0x04` | `4` | BY1 := | `206` | LOADT | 0 | BY | D-conv |
| `0x05` | `5` | BY2 := | `206` | LOADT | 1 | BY | D-conv |
| `0x06` | `6` | BY3 := | `206` | LOADT | 2 | BY | D-conv |
| `0x07` | `7` | BY4 := | `206` | LOADT | 3 | BY | D-conv |
| `0x08` | `10` | H1 := | `206` | LOADT | 0 | H | D-conv |
| `0x09` | `11` | H2 := | `206` | LOADT | 1 | H | D-conv |
| `0x0A` | `12` | H3 := | `206` | LOADT | 2 | H | D-conv |
| `0x0B` | `13` | H4 := | `206` | LOADT | 3 | H | D-conv |
| `0x0C` | `14` | W1 := | `206` | LOADT | 0 | W | D-conv |
| `0x0D` | `15` | W2 := | `206` | LOADT | 1 | W | D-conv |
| `0x0E` | `16` | W3 := | `206` | LOADT | 2 | W | D-conv |
| `0x0F` | `17` | W4 := | `206` | LOADT | 3 | W | D-conv |
| `0x10` | `20` | F1 := | `206` | LOADT | 0 | F | D-conv |
| `0x11` | `21` | F2 := | `206` | LOADT | 1 | F | D-conv |
| `0x12` | `22` | F3 := | `206` | LOADT | 2 | F | D-conv |
| `0x13` | `23` | F4 := | `206` | LOADT | 3 | F | D-conv |
| `0x14` | `24` | D1 := | `207` | LOADD | 0 | D | D-conv |
| `0x15` | `25` | D2 := | `207` | LOADD | 1 | D | D-conv |
| `0x16` | `26` | D3 := | `207` | LOADD | 2 | D | D-conv |
| `0x17` | `27` | D4 := | `207` | LOADD | 3 | D | D-conv |
| `0x18` | `30` | R := | `211` | LOADR | - | ? | D-conv |
| `0x19` | `31` | BY MOVE | `231` | MOVE | - | BY | D-conv |
| `0x1A` | `32` | W MOVE | `231` | MOVE | - | W | D-conv |
| `0x1B` | `33` | F MOVE | `231` | MOVE | - | F | D-conv |
| `0x1C` | `34` | BY1 =: | `220` | STORE | 0 | BY | D-conv |
| `0x1D` | `35` | BY2 =: | `220` | STORE | 1 | BY | D-conv |
| `0x1E` | `36` | BY3 =: | `220` | STORE | 2 | BY | D-conv |
| `0x1F` | `37` | BY4 =: | `220` | STORE | 3 | BY | D-conv |
| `0x20` | `40` | W1 =: | `220` | STORE | 0 | W | D-conv |
| `0x21` | `41` | W2 =: | `220` | STORE | 1 | W | D-conv |
| `0x22` | `42` | W3 =: | `220` | STORE | 2 | W | D-conv |
| `0x23` | `43` | W4 =: | `220` | STORE | 3 | W | D-conv |
| `0x24` | `44` | F1 =: | `220` | STORE | 0 | F | D-conv |
| `0x25` | `45` | F2 =: | `220` | STORE | 1 | F | D-conv |
| `0x26` | `46` | F3 =: | `220` | STORE | 2 | F | D-conv |
| `0x27` | `47` | F4 =: | `220` | STORE | 3 | F | D-conv |
| `0x28` | `50` | D1 =: | `221` | STORED | 0 | D | D-conv |
| `0x29` | `51` | D2 =: | `221` | STORED | 1 | D | D-conv |
| `0x2A` | `52` | D3 =: | `221` | STORED | 2 | D | D-conv |
| `0x2B` | `53` | D4 =: | `221` | STORED | 3 | D | D-conv |
| `0x2C` | `54` | D MOVE | `233` | MOVED | - | D | D-conv |
| `0x2D` | `55` | BY COMP2 | `244` | COMP2 | - | BY | D-conv |
| `0x2E` | `56` | W COMP2 | `244` | COMP2 | - | W | D-conv |
| `0x2F` | `57` | F COMP2 | `244` | COMP2 | - | F | D-conv |
| `0x30` | `60` | BY1 COMP | `241` | COMP | 0 | BY | D-conv |
| `0x31` | `61` | BY2 COMP | `241` | COMP | 1 | BY | D-conv |
| `0x32` | `62` | BY3 COMP | `241` | COMP | 2 | BY | D-conv |
| `0x33` | `63` | BY4 COMP | `241` | COMP | 3 | BY | D-conv |
| `0x34` | `64` | W1 COMP | `241` | COMP | 0 | W | D-conv |
| `0x35` | `65` | W2 COMP | `241` | COMP | 1 | W | D-conv |
| `0x36` | `66` | W3 COMP | `241` | COMP | 2 | W | D-conv |
| `0x37` | `67` | W4 COMP | `241` | COMP | 3 | W | D-conv |
| `0x38` | `70` | F1 COMP | `241` | COMP | 0 | F | D-conv |
| `0x39` | `71` | F2 COMP | `241` | COMP | 1 | F | D-conv |
| `0x3A` | `72` | F3 COMP | `241` | COMP | 2 | F | D-conv |
| `0x3B` | `73` | F4 COMP | `241` | COMP | 3 | F | D-conv |
| `0x3C` | `74` | D1 COMP | `2147` | COMPD | 0 | D | D-conv |
| `0x3D` | `75` | D2 COMP | `2147` | COMPD | 1 | D | D-conv |
| `0x3E` | `76` | D3 COMP | `2147` | COMPD | 2 | D | D-conv |
| `0x3F` | `77` | D4 COMP | `2147` | COMPD | 3 | D | D-conv |
| `0x40` | `100` | D COMP2 | `244` | COMP2 | - | D | D-conv |
| `0x41` | `101` | BI TEST | `246` | TESTBI | - | BI | D-labe |
| `0x42` | `102` | BY TEST | `250` | TEST | - | BY | D-conv |
| `0x43` | `103` | H TEST | `250` | TEST | - | H | D-conv |
| `0x44` | `104` | W TEST | `250` | TEST | - | W | D-conv |
| `0x45` | `105` | F TEST | `3000` | TESTF | - | F | D-labe |
| `0x46` | `106` | D TEST | `3002` | TESTD | - | D | D-labe |
| `0x47` | `107` | F SET1 | `326` | SET1F | - | F | D-labe |
| `0x48` | `110` | BY STZ | `316` | STZ | - | BY | D-conv |
| `0x49` | `111` | H STZ | `316` | STZ | - | H | D-conv |
| `0x4A` | `112` | W STZ | `316` | STZ | - | W | D-conv |
| `0x4B` | `113` | F STZ | `316` | STZ | - | F | D-conv |
| `0x4C` | `114` | D STZ | `317` | STZD | - | D | D-labe |
| `0x4D` | `115` | W SET1 | `325` | SET1 | - | W | D-conv |
| `0x4E` | `116` | H INCR | `333` | INCR | - | H | D-conv |
| `0x4F` | `117` | W INCR | `333` | INCR | - | W | D-conv |
| `0x50` | `120` | F INCR | `333` | INCR | - | F | D-conv |
| `0x51` | `121` | W DECR | `335` | DECR | - | W | D-conv |
| `0x52` | `122` | W SWAP | `534` | SWAP | - | W | D-conv |
| `0x53` | `123` | W ADD2 | `271` | ADD2 | - | W | D-3src |
| `0x54` | `124` | W1 + [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY add is 2-byte 0xFC34, not here] | `267` | ADD | 0 | W | ? |
| `0x55` | `125` | W2 + [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY add is 2-byte 0xFC34, not here] | `267` | ADD | 1 | W | ? |
| `0x56` | `126` | W3 + [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY add is 2-byte 0xFC34, not here] | `267` | ADD | 2 | W | ? |
| `0x57` | `127` | W4 + [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY add is 2-byte 0xFC34, not here] | `267` | ADD | 3 | W | ? |
| `0x58` | `130` | F1 + | `2167` | ADDF | 0 | F | D-func |
| `0x59` | `131` | F2 + | `2167` | ADDF | 1 | F | D-func |
| `0x5A` | `132` | F3 + | `2167` | ADDF | 2 | F | D-func |
| `0x5B` | `133` | F4 + | `2167` | ADDF | 3 | F | D-func |
| `0x5C` | `134` | D1 + [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode ADDD 002204 (AAP2,ADD)] | `2204` | ADDD | 0 | D | ? |
| `0x5D` | `135` | D2 + [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode ADDD 002204 (AAP2,ADD)] | `2204` | ADDD | 1 | D | ? |
| `0x5E` | `136` | D3 + [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode ADDD 002204 (AAP2,ADD)] | `2204` | ADDD | 2 | D | ? |
| `0x5F` | `137` | D4 + [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode ADDD 002204 (AAP2,ADD)] | `2204` | ADDD | 3 | D | ? |
| `0x60` | `140` | W1 - [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY sub is 2-byte, not here] | `270` | SUB | 0 | W | ? |
| `0x61` | `141` | W2 - [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY sub is 2-byte, not here] | `270` | SUB | 1 | W | ? |
| `0x62` | `142` | W3 - [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY sub is 2-byte, not here] | `270` | SUB | 2 | W | ? |
| `0x63` | `143` | W4 - [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]); BY sub is 2-byte, not here] | `270` | SUB | 3 | W | ? |
| `0x64` | `144` | F1 - | `2230` | SUBF | 0 | F | D-func |
| `0x65` | `145` | F2 - | `2230` | SUBF | 1 | F | D-func |
| `0x66` | `146` | F3 - | `2230` | SUBF | 2 | F | D-func |
| `0x67` | `147` | F4 - | `2230` | SUBF | 3 | F | D-func |
| `0x68` | `150` | D1 - [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode SUBD 002246 (AAP2,SUBBA)] | `2246` | SUBD | 0 | D | ? |
| `0x69` | `151` | D2 - [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode SUBD 002246 (AAP2,SUBBA)] | `2246` | SUBD | 1 | D | ? |
| `0x6A` | `152` | D3 - [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode SUBD 002246 (AAP2,SUBBA)] | `2246` | SUBD | 2 | D | ? |
| `0x6B` | `153` | D4 - [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode SUBD 002246 (AAP2,SUBBA)] | `2246` | SUBD | 3 | D | ? |
| `0x6C` | `154` | W1 * [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]) -> MULW; BY mul is 2-byte, not here] | `2305` | MUL | 0 | W | ? |
| `0x6D` | `155` | W2 * [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]) -> MULW; BY mul is 2-byte, not here] | `2305` | MUL | 1 | W | ? |
| `0x6E` | `156` | W3 * [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]) -> MULW; BY mul is 2-byte, not here] | `2305` | MUL | 2 | W | ? |
| `0x6F` | `157` | W4 * [functional-decoder variant2->W (dataTypes[BY,H,W,F,D][2]) -> MULW; BY mul is 2-byte, not here] | `2305` | MUL | 3 | W | ? |
| `0x70` | `160` | F1 * | `2355` | MULF | 0 | F | D-func |
| `0x71` | `161` | F2 * | `2355` | MULF | 1 | F | D-func |
| `0x72` | `162` | F3 * | `2355` | MULF | 2 | F | D-func |
| `0x73` | `163` | F4 * | `2355` | MULF | 3 | F | D-func |
| `0x74` | `164` | D1 * [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode MULD 002372 (AAP2,MUL)] | `2372` | MULD | 0 | D | ? |
| `0x75` | `165` | D2 * [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode MULD 002372 (AAP2,MUL)] | `2372` | MULD | 1 | D | ? |
| `0x76` | `166` | D3 * [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode MULD 002372 (AAP2,MUL)] | `2372` | MULD | 2 | D | ? |
| `0x77` | `167` | D4 * [functional-decoder variant4->D (dataTypes[BY,H,W,F,D][4]) + microcode MULD 002372 (AAP2,MUL)] | `2372` | MULD | 3 | D | ? |
| `0x78` | `170` | BY1 / | `2430` | DIVW | 0 | W | D-3src |
| `0x79` | `171` | BY2 / | `2430` | DIVW | 1 | W | D-3src |
| `0x7A` | `172` | BY3 / | `2430` | DIVW | 2 | W | D-3src |
| `0x7B` | `173` | BY4 / | `2430` | DIVW | 3 | W | D-3src |
| `0x7C` | `174` | F1 / | `2501` | DIVF | 0 | F | D-func |
| `0x7D` | `175` | F2 / | `2501` | DIVF | 1 | F | D-func |
| `0x7E` | `176` | F3 / | `2501` | DIVF | 2 | F | D-func |
| `0x7F` | `177` | F4 / | `2501` | DIVF | 3 | F | D-func |
| `0x80` | `200` | RET | `701` | RET | - | ? | D-labe |
| `0x81` | `201` | RETK | `702` | RETK | - | ? | D-labe |
| `0x82` | `202` | RETD | `700` | RETD | - | ? | D-labe |
| `0x83` | `203` | RETT | `710` | RETT | - | ? | D-labe |
| `0x84` | `204` | 1 CLR (int) | `307` | CLR | 0 | W | D-conv |
| `0x85` | `205` | 2 CLR (int) | `307` | CLR | 1 | W | D-conv |
| `0x86` | `206` | 3 CLR (int) | `307` | CLR | 2 | W | D-conv |
| `0x87` | `207` | 4 CLR (int) | `307` | CLR | 3 | W | D-conv |
| `0x88` | `210` | F1 CLR | `310` | CLRF | 0 | F | D-labe |
| `0x89` | `211` | F2 CLR | `310` | CLRF | 1 | F | D-labe |
| `0x8A` | `212` | F3 CLR | `310` | CLRF | 2 | F | D-labe |
| `0x8B` | `213` | F4 CLR | `310` | CLRF | 3 | F | D-labe |
| `0x8C` | `214` | D1 CLR | `311` | CLRD | 0 | D | D-labe |
| `0x8D` | `215` | D2 CLR | `311` | CLRD | 1 | D | D-labe |
| `0x8E` | `216` | D3 CLR | `311` | CLRD | 2 | D | D-labe |
| `0x8F` | `217` | D4 CLR | `311` | CLRD | 3 | D | D-labe |
| `0x90` | `220` | W1 NEG | `254` | NEG | 0 | W | D-conv |
| `0x91` | `221` | W2 NEG | `254` | NEG | 1 | W | D-conv |
| `0x92` | `222` | W3 NEG | `254` | NEG | 2 | W | D-conv |
| `0x93` | `223` | W4 NEG | `254` | NEG | 3 | W | D-conv |
| `0x94` | `224` | F1 NEG | `256` | NEGF | 0 | F | D-labe |
| `0x95` | `225` | F2 NEG | `256` | NEGF | 1 | F | D-labe |
| `0x96` | `226` | F3 NEG | `256` | NEGF | 2 | F | D-labe |
| `0x97` | `227` | F4 NEG | `256` | NEGF | 3 | F | D-labe |
| `0x98` | `230` | W1 INV | `260` | INV | 0 | W | D-conv |
| `0x99` | `231` | W2 INV | `260` | INV | 1 | W | D-conv |
| `0x9A` | `232` | W3 INV | `260` | INV | 2 | W | D-conv |
| `0x9B` | `233` | W4 INV | `260` | INV | 3 | W | D-conv |
| `0x9C` | `234` | ENTD | `660` | ENTD | - | ? | D-labe |
| `0x9D` | `235` | IF K RET | `703` | IFKRET | - | ? | D-labe |
| `0x9E` | `236` | EXT (W, group 1) | `1637` | RES1 | - | ? | M-ch12 |
| `0x9F` | `237` | EXT (W, group 1) | `1640` | RES2 | - | ? | M-ch12 |
| `0xA0` | `240` | W1 OR | `344` | OR | 0 | W | D-conv |
| `0xA1` | `241` | W2 OR | `344` | OR | 1 | W | D-conv |
| `0xA2` | `242` | W3 OR | `344` | OR | 2 | W | D-conv |
| `0xA3` | `243` | W4 OR | `344` | OR | 3 | W | D-conv |
| `0xA4` | `244` | W1 XOR | `347` | XOR | 0 | W | D-conv |
| `0xA5` | `245` | W2 XOR | `347` | XOR | 1 | W | D-conv |
| `0xA6` | `246` | W3 XOR | `347` | XOR | 2 | W | D-conv |
| `0xA7` | `247` | W4 XOR | `347` | XOR | 3 | W | D-conv |
| `0xA8` | `250` | W1 MULAD | `2627` | MULADW | 0 | W | D-labe |
| `0xA9` | `251` | W2 MULAD | `2627` | MULADW | 1 | W | D-labe |
| `0xAA` | `252` | W3 MULAD | `2627` | MULADW | 2 | W | D-labe |
| `0xAB` | `253` | W4 MULAD | `2627` | MULADW | 3 | W | D-labe |
| `0xAC` | `254` | W1 LIND | `1576` | LIND | 0 | W | D-conv |
| `0xAD` | `255` | W2 LIND | `1576` | LIND | 1 | W | D-conv |
| `0xAE` | `256` | W3 LIND | `1576` | LIND | 2 | W | D-conv |
| `0xAF` | `257` | W4 LIND | `1576` | LIND | 3 | W | D-conv |
| `0xB0` | `260` | W1 CIND | `1623` | CIND | 0 | W | D-labe |
| `0xB1` | `261` | W2 CIND | `1623` | CIND | 1 | W | D-labe |
| `0xB2` | `262` | W3 CIND | `1623` | CIND | 2 | W | D-labe |
| `0xB3` | `263` | W4 CIND | `1623` | CIND | 3 | W | D-labe |
| `0xB4` | `264` | JUMPG | `542` | JUMPG | - | ? | D-labe |
| `0xB5` | `265` | CALLG | `650` | CALLG | - | ? | D-labe |
| `0xB6` | `266` | W1 SEND | `1067` | SEND | 0 | W | D-labe |
| `0xB7` | `267` | W1 RECVE | `1071` | RECVE | 0 | W | D-labe |
| `0xB8` | `270` | ENTS | `662` | ENTS | - | W | D-labe |
| `0xB9` | `271` | JUMPS | `1045` | JUMPS | - | ? | D-labe |
| `0xBA` | `272` | ENTSN | `666` | ENTSN | - | ? | D-labe |
| `0xBC` | `274` | ENTT | `673` | ENTT | - | ? | D-labe |
| `0xBD` | `275` | ENTB | `676` | ENTB | - | ? | D-3src |
| `0xBE` | `276` | W/F RLADDR | `766` | RLADDR | - | W | D-labe |
| `0xBF` | `277` | W LOOPI:B | `570` | LOOPIB | - | W | D-conv |
| `0xC0` | `300` | BY GO | `541` | GOB | - | BY | D-ndix |
| `0xC0` | `300` | GO:B | `541` | GOB | - | BY | D-labe |
| `0xC1` | `301` | GO:H | `541` | GOB | - | H | D-labe |
| `0xC1` | `301` | H GO | `541` | GOB | - | H | D-ndix |
| `0xC2` | `302` | GO:W | `541` | GOB | - | W | D-labe |
| `0xC2` | `302` | W GO | `541` | GOB | - | W | D-ndix |
| `0xC4` | `304` | BY IFEQL | `544` | IFEQL | - | BY | D-ndix |
| `0xC4` | `304` | IF = GO:B | `544` | IFEQL | - | BY | D-conv |
| `0xC5` | `305` | IF = GO:H | `544` | IFEQL | - | H | D-conv |
| `0xC6` | `306` | IF &gt;&lt; GO:B | `545` | IFUEQ | - | BY | D-conv |
| `0xC7` | `307` | IF &gt;&lt; GO:H | `545` | IFUEQ | - | H | D-conv |
| `0xC8` | `310` | IF &gt; GO:B | `546` | IFGR | - | BY | D-conv |
| `0xC9` | `311` | IF &gt; GO:H | `546` | IFGR | - | H | D-conv |
| `0xCA` | `312` | IF &lt; GO:B | `547` | IFLS | - | BY | D-conv |
| `0xCB` | `313` | IF &lt; GO:H | `547` | IFLS | - | H | D-conv |
| `0xCC` | `314` | IF &gt;= GO:B | `550` | IFGRE | - | BY | D-conv |
| `0xCD` | `315` | IF &gt;= GO:H | `550` | IFGRE | - | H | D-conv |
| `0xCE` | `316` | IF &lt;= GO:B | `551` | IFLSE | - | BY | D-conv |
| `0xCF` | `317` | IF &lt;= GO:H | `551` | IFLSE | - | H | D-conv |
| `0xD0` | `320` | IF K GO:B | `552` | IFK | - | BY | D-conv |
| `0xD1` | `321` | IF K GO:H | `552` | IFK | - | H | D-conv |
| `0xD2` | `322` | IF -K GO:B | `553` | IFNK | - | BY | D-conv |
| `0xD3` | `323` | IF -K GO:H | `553` | IFNK | - | H | D-conv |
| `0xD4` | `324` | IF &gt;&gt; GO:B | `554` | IFGRM | - | BY | D-conv |
| `0xD5` | `325` | IF &gt;&gt; GO:H | `554` | IFGRM | - | H | D-conv |
| `0xD6` | `326` | IF &gt;&gt;= GO:B | `555` | IFC | - | BY | D-conv |
| `0xD7` | `327` | IF &gt;&gt;= GO:H | `555` | IFC | - | H | D-conv |
| `0xD8` | `330` | IF &lt;&lt; GO:B | `556` | IFNC | - | BY | D-conv |
| `0xD9` | `331` | IF &lt;&lt; GO:H | `556` | IFNC | - | H | D-conv |
| `0xDA` | `332` | IF &lt;&lt;= GO:B | `557` | IFLSEM | - | BY | D-conv |
| `0xDB` | `333` | IF &lt;&lt;= GO:H | `557` | IFLSEM | - | H | D-conv |
| `0xE0` | `340` | W SUB2 | `274` | SUB2 | - | W | D-3src |
| `0xE1` | `341` | W LOOPI:H | `574` | LOOPIH | - | W | D-conv |
| `0xE4` | `344` | W1 AND | `341` | AND | 0 | W | D-conv |
| `0xE5` | `345` | W2 AND | `341` | AND | 1 | W | D-conv |
| `0xE6` | `346` | W3 AND | `341` | AND | 2 | W | D-conv |
| `0xE7` | `347` | W4 AND | `341` | AND | 3 | W | D-conv |
| `0xE8` | `350` | W1 / | `2516` | DIVD | 0 | D | D-3src |
| `0xE9` | `351` | W2 / | `2516` | DIVD | 1 | D | D-3src |
| `0xEA` | `352` | W3 / | `2516` | DIVD | 2 | D | D-3src |
| `0xEB` | `353` | W4 / | `2516` | DIVD | 3 | D | D-3src |

## Appendix B — two-byte opcodes

948 rows, pages `0xFC`-`0xFF`. Entry is OCTAL. Same grade codes as Appendix A.

Unmapped lows per page — `0xFC`: `00 01 02 03 21 22 23 25 26 27 29 2A 2B`; `0xFD`: `41 42 43 6A 7A 8C
8D 8E 8F A4 A5 A6 A7 C4`; `0xFE`: `56 57 77 7A 87 93 9E 9F B2 B6 B7 B8 B9 BA BB BC BD BE BF`;
`0xFF`: `B0`-`BB`, `D8`-`E7`, `FA`, `FF`.

| opcode | octal | mnemonic | entry | label | rin | dt | grade |
|---|---|---|---|---|---|---|---|
| `0xFC04` | `176004` | BI1 := | `203` | LOADBI | 0 | BI | D-conv |
| `0xFC05` | `176005` | BI2 := | `203` | LOADBI | 1 | BI | D-conv |
| `0xFC06` | `176006` | BI3 := | `203` | LOADBI | 2 | BI | D-conv |
| `0xFC07` | `176007` | BI4 := | `203` | LOADBI | 3 | BI | D-conv |
| `0xFC08` | `176010` | B := | `213` | LOADB | - | ? | D-conv |
| `0xFC09` | `176011` | R =: | `223` | STORER | - | ? | D-conv |
| `0xFC0A` | `176012` | B =: | `225` | STOREB | - | ? | D-conv |
| `0xFC0B` | `176013` | BI MOVE | `227` | MOVEBI | - | BI | D-conv |
| `0xFC0C` | `176014` | BI1 =: | `215` | STOREBI | 0 | BI | D-conv |
| `0xFC0D` | `176015` | BI2 =: | `215` | STOREBI | 1 | BI | D-conv |
| `0xFC0E` | `176016` | BI3 =: | `215` | STOREBI | 2 | BI | D-conv |
| `0xFC0F` | `176017` | BI4 =: | `215` | STOREBI | 3 | BI | D-conv |
| `0xFC10` | `176020` | H1 =: | `220` | STORE | 0 | H | D-conv |
| `0xFC11` | `176021` | H2 =: | `220` | STORE | 1 | H | D-conv |
| `0xFC12` | `176022` | H3 =: | `220` | STORE | 2 | H | D-conv |
| `0xFC13` | `176023` | H4 =: | `220` | STORE | 3 | H | D-conv |
| `0xFC14` | `176024` | H MOVE | `231` | MOVE | - | H | D-conv |
| `0xFC15` | `176025` | BI COMP2 | `242` | COMP2BI | - | BI | D-labe |
| `0xFC16` | `176026` | H COMP2 | `244` | COMP2 | - | H | D-conv |
| `0xFC17` | `176027` | BY ADD2 | `271` | ADD2 | - | BY | D-3src |
| `0xFC18` | `176030` | BI1 COMP | `237` | COMPBI | 0 | BI | D-labe |
| `0xFC19` | `176031` | BI2 COMP | `237` | COMPBI | 1 | BI | D-labe |
| `0xFC1A` | `176032` | BI3 COMP | `237` | COMPBI | 2 | BI | D-labe |
| `0xFC1B` | `176033` | BI4 COMP | `237` | COMPBI | 3 | BI | D-labe |
| `0xFC1C` | `176034` | H1 COMP | `241` | COMP | 0 | H | D-conv |
| `0xFC1D` | `176035` | H2 COMP | `241` | COMP | 1 | H | D-conv |
| `0xFC1E` | `176036` | H3 COMP | `241` | COMP | 2 | H | D-conv |
| `0xFC1F` | `176037` | H4 COMP | `241` | COMP | 3 | H | D-conv |
| `0xFC20` | `176040` | BY MUL4 | `2341` | MUL4BY | - | BY | D-3src |
| `0xFC24` | `176044` | H MUL4 | `2345` | MUL4H | - | H | D-3src |
| `0xFC28` | `176050` | W MUL4 | `2351` | MUL4W | - | W | D-3src |
| `0xFC2C` | `176054` | BY DIV4 | `2553` | DIV4BY | - | BY | D-3src |
| `0xFC2D` | `176055` | BY2 DIV4 | `2553` | DIV4BY | 1 | BY | D-labe |
| `0xFC2E` | `176056` | BY3 DIV4 | `2553` | DIV4BY | 2 | BY | D-labe |
| `0xFC2F` | `176057` | BY4 DIV4 | `2553` | DIV4BY | 3 | BY | D-labe |
| `0xFC30` | `176060` | H DIV4 | `2557` | DIV4HW | - | H | D-3src |
| `0xFC31` | `176061` | H2 DIV4 | `2557` | DIV4HW | 1 | H | D-labe |
| `0xFC32` | `176062` | H3 DIV4 | `2557` | DIV4HW | 2 | H | D-labe |
| `0xFC33` | `176063` | H4 DIV4 | `2557` | DIV4HW | 3 | H | D-labe |
| `0xFC34` | `176064` | BY1 + | `267` | ADD | 0 | BY | D-conv |
| `0xFC35` | `176065` | BY2 + | `267` | ADD | 1 | BY | D-conv |
| `0xFC36` | `176066` | BY3 + | `267` | ADD | 2 | BY | D-conv |
| `0xFC37` | `176067` | BY4 + | `267` | ADD | 3 | BY | D-conv |
| `0xFC38` | `176070` | H1 + | `267` | ADD | 0 | H | D-conv |
| `0xFC39` | `176071` | H2 + | `267` | ADD | 1 | H | D-conv |
| `0xFC3A` | `176072` | H3 + | `267` | ADD | 2 | H | D-conv |
| `0xFC3B` | `176073` | H4 + | `267` | ADD | 3 | H | D-conv |
| `0xFC3C` | `176074` | BY1 - | `270` | SUB | 0 | BY | D-conv |
| `0xFC3D` | `176075` | BY2 - | `270` | SUB | 1 | BY | D-conv |
| `0xFC3E` | `176076` | BY3 - | `270` | SUB | 2 | BY | D-conv |
| `0xFC3F` | `176077` | BY4 - | `270` | SUB | 3 | BY | D-conv |
| `0xFC40` | `176100` | H1 - | `270` | SUB | 0 | H | D-conv |
| `0xFC41` | `176101` | H2 - | `270` | SUB | 1 | H | D-conv |
| `0xFC42` | `176102` | H3 - | `270` | SUB | 2 | H | D-conv |
| `0xFC43` | `176103` | H4 - | `270` | SUB | 3 | H | D-conv |
| `0xFC44` | `176104` | BY1 * | `2275` | MULBY | 0 | BY | D-labe |
| `0xFC45` | `176105` | BY2 * | `2275` | MULBY | 1 | BY | D-labe |
| `0xFC46` | `176106` | BY3 * | `2275` | MULBY | 2 | BY | D-labe |
| `0xFC47` | `176107` | BY4 * | `2275` | MULBY | 3 | BY | D-labe |
| `0xFC48` | `176110` | H1 * | `2301` | MULHW | 0 | H | D-labe |
| `0xFC49` | `176111` | H2 * | `2301` | MULHW | 1 | H | D-labe |
| `0xFC4A` | `176112` | H3 * | `2301` | MULHW | 2 | H | D-labe |
| `0xFC4B` | `176113` | H4 * | `2301` | MULHW | 3 | H | D-labe |
| `0xFC4C` | `176114` | BY1 / | `2416` | DIVBY | 0 | BY | D-labe |
| `0xFC4D` | `176115` | BY2 / | `2416` | DIVBY | 1 | BY | D-labe |
| `0xFC4E` | `176116` | BY3 / | `2416` | DIVBY | 2 | BY | D-labe |
| `0xFC4F` | `176117` | BY4 / | `2416` | DIVBY | 3 | BY | D-labe |
| `0xFC50` | `176120` | H1 / | `2423` | DIVHW | 0 | H | D-labe |
| `0xFC51` | `176121` | H2 / | `2423` | DIVHW | 1 | H | D-labe |
| `0xFC52` | `176122` | H3 / | `2423` | DIVHW | 2 | H | D-labe |
| `0xFC53` | `176123` | H4 / | `2423` | DIVHW | 3 | H | D-labe |
| `0xFC54` | `176124` | H ADD2 | `271` | ADD2 | - | H | D-3src |
| `0xFC55` | `176125` | BI RLADDR | `766` | RLADDR | - | BI | D-labe |
| `0xFC56` | `176126` | F ADD2 | `2172` | ADD2F | - | F | D-3src |
| `0xFC57` | `176127` | D ADD2 | `2212` | ADD2D | - | D | D-3src |
| `0xFC58` | `176130` | BY SUB2 | `274` | SUB2 | - | BY | D-3src |
| `0xFC59` | `176131` | H SUB2 | `274` | SUB2 | - | H | D-3src |
| `0xFC5A` | `176132` | BY RLADDR | `766` | RLADDR | - | BY | D-labe |
| `0xFC5B` | `176133` | F SUB2 | `2234` | SUB2F | - | F | D-3src |
| `0xFC5C` | `176134` | D SUB2 | `2255` | SUB2D | - | D | D-3src |
| `0xFC5D` | `176135` | BY MUL2 | `2311` | MUL2BY | - | BY | D-3src |
| `0xFC5E` | `176136` | H MUL2 | `2315` | MUL2H | - | H | D-3src |
| `0xFC5F` | `176137` | W MUL2 | `2321` | MUL2W | - | W | D-3src |
| `0xFC60` | `176140` | F MUL2 | `2360` | MUL2F | - | F | D-3src |
| `0xFC61` | `176141` | D MUL2 | `2400` | MUL2D | - | D | D-3src |
| `0xFC62` | `176142` | BY DIV2 | `2435` | DIV2BY | - | BY | D-3src |
| `0xFC63` | `176143` | H DIV2 | `2443` | DIV2HW | - | H | D-3src |
| `0xFC64` | `176144` | W DIV2 | `2451` | DIV2W | - | W | D-3src |
| `0xFC65` | `176145` | F DIV2 | `2504` | DIV2F | - | F | D-3src |
| `0xFC66` | `176146` | D DIV2 | `2524` | DIV2D | - | D | D-3src |
| `0xFC67` | `176147` | BY ADD3 | `277` | ADD3 | - | BY | D-labe |
| `0xFC68` | `176150` | H ADD3 | `277` | ADD3 | - | H | D-labe |
| `0xFC69` | `176151` | W ADD3 | `277` | ADD3 | - | W | D-labe |
| `0xFC6A` | `176152` | F ADD3 | `2177` | ADD3F | - | F | D-labe |
| `0xFC6B` | `176153` | D ADD3 | `2221` | ADD3D | - | D | D-labe |
| `0xFC6C` | `176154` | BY SUB3 | `302` | SUB3 | - | BY | D-labe |
| `0xFC6D` | `176155` | H SUB3 | `302` | SUB3 | - | H | D-labe |
| `0xFC6E` | `176156` | W SUB3 | `302` | SUB3 | - | W | D-labe |
| `0xFC6F` | `176157` | F SUB3 | `2241` | SUB3F | - | F | D-labe |
| `0xFC70` | `176160` | D SUB3 | `2265` | SUB3D | - | D | D-labe |
| `0xFC71` | `176161` | BY MUL3 | `2325` | MUL3BY | - | BY | D-3src |
| `0xFC72` | `176162` | H MUL3 | `2331` | MUL3H | - | H | D-3src |
| `0xFC73` | `176163` | W MUL3 | `2335` | MUL3W | - | W | D-3src |
| `0xFC74` | `176164` | F MUL3 | `2365` | MUL3F | - | F | D-3src |
| `0xFC75` | `176165` | D MUL3 | `2407` | MUL3D | - | D | D-3src |
| `0xFC76` | `176166` | BY DIV3 | `2457` | DIV3BY | - | BY | D-3src |
| `0xFC77` | `176167` | H DIV3 | `2465` | DIV3HW | - | H | D-3src |
| `0xFC78` | `176170` | W DIV3 | `2473` | DIV3W | - | W | D-3src |
| `0xFC79` | `176171` | F DIV3 | `2511` | DIV3F | - | F | D-3src |
| `0xFC7A` | `176172` | D DIV3 | `2533` | DIV3D | - | D | D-3src |
| `0xFC7B` | `176173` | IF ST GO:B | `560` | IFSTB | - | BY | D-labe |
| `0xFC7C` | `176174` | W DIV4 | `2563` | DIV4W | - | W | D-3src |
| `0xFC7D` | `176175` | W2 DIV4 | `2563` | DIV4W | 1 | W | D-labe |
| `0xFC7E` | `176176` | W3 DIV4 | `2563` | DIV4W | 2 | W | D-labe |
| `0xFC7F` | `176177` | W4 DIV4 | `2563` | DIV4W | 3 | W | D-labe |
| `0xFC80` | `176200` | W1 UMUL | `2567` | UMUL | 0 | W | D-labe |
| `0xFC81` | `176201` | W2 UMUL | `2567` | UMUL | 1 | W | D-labe |
| `0xFC82` | `176202` | W3 UMUL | `2567` | UMUL | 2 | W | D-labe |
| `0xFC83` | `176203` | W4 UMUL | `2567` | UMUL | 3 | W | D-labe |
| `0xFC84` | `176204` | IF -ST GO:H | `566` | IFNSTH | - | H | D-labe |
| `0xFC85` | `176205` | BI STZ | `313` | STZBI | - | BI | D-labe |
| `0xFC86` | `176206` | BI SET1 | `321` | SET1BI | - | BI | D-labe |
| `0xFC87` | `176207` | BY SET1 | `325` | SET1 | - | BY | D-conv |
| `0xFC88` | `176210` | H SET1 | `325` | SET1 | - | H | D-conv |
| `0xFC89` | `176211` | D SET1 | `330` | SET1D | - | D | D-labe |
| `0xFC8A` | `176212` | BY INCR | `333` | INCR | - | BY | D-conv |
| `0xFC8B` | `176213` | D INCR | `333` | INCR | - | D | D-conv |
| `0xFC8C` | `176214` | BY DECR | `335` | DECR | - | BY | D-conv |
| `0xFC8D` | `176215` | H DECR | `335` | DECR | - | H | D-conv |
| `0xFC8E` | `176216` | F DECR | `335` | DECR | - | F | D-conv |
| `0xFC8F` | `176217` | D DECR | `335` | DECR | - | D | D-conv |
| `0xFC90` | `176220` | BY1 AND | `341` | AND | 0 | BY | D-conv |
| `0xFC91` | `176221` | BY2 AND | `341` | AND | 1 | BY | D-conv |
| `0xFC92` | `176222` | BY3 AND | `341` | AND | 2 | BY | D-conv |
| `0xFC93` | `176223` | BY4 AND | `341` | AND | 3 | BY | D-conv |
| `0xFC94` | `176224` | H1 AND | `341` | AND | 0 | H | D-conv |
| `0xFC95` | `176225` | H2 AND | `341` | AND | 1 | H | D-conv |
| `0xFC96` | `176226` | H3 AND | `341` | AND | 2 | H | D-conv |
| `0xFC97` | `176227` | H4 AND | `341` | AND | 3 | H | D-conv |
| `0xFC98` | `176230` | BY1 OR | `344` | OR | 0 | BY | D-conv |
| `0xFC99` | `176231` | BY2 OR | `344` | OR | 1 | BY | D-conv |
| `0xFC9A` | `176232` | BY3 OR | `344` | OR | 2 | BY | D-conv |
| `0xFC9B` | `176233` | BY4 OR | `344` | OR | 3 | BY | D-conv |
| `0xFC9C` | `176234` | H1 OR | `344` | OR | 0 | H | D-conv |
| `0xFC9D` | `176235` | H2 OR | `344` | OR | 1 | H | D-conv |
| `0xFC9E` | `176236` | H3 OR | `344` | OR | 2 | H | D-conv |
| `0xFC9F` | `176237` | H4 OR | `344` | OR | 3 | H | D-conv |
| `0xFCA0` | `176240` | BY1 XOR | `347` | XOR | 0 | BY | D-conv |
| `0xFCA1` | `176241` | BY2 XOR | `347` | XOR | 1 | BY | D-conv |
| `0xFCA2` | `176242` | BY3 XOR | `347` | XOR | 2 | BY | D-conv |
| `0xFCA3` | `176243` | BY4 XOR | `347` | XOR | 3 | BY | D-conv |
| `0xFCA4` | `176244` | H1 XOR | `347` | XOR | 0 | H | D-conv |
| `0xFCA5` | `176245` | H2 XOR | `347` | XOR | 1 | H | D-conv |
| `0xFCA6` | `176246` | H3 XOR | `347` | XOR | 2 | H | D-conv |
| `0xFCA7` | `176247` | H4 XOR | `347` | XOR | 3 | H | D-conv |
| `0xFCA8` | `176250` | BY SHL | `350` | SHLBY | - | BY | D-labe |
| `0xFCA9` | `176251` | H SHL | `354` | SHLHW | - | H | D-labe |
| `0xFCAA` | `176252` | W SHL | `360` | SHLW | - | W | D-labe |
| `0xFCAB` | `176253` | BY SHA | `364` | SHABY | - | BY | D-labe |
| `0xFCAC` | `176254` | H SHA | `370` | SHAHW | - | H | D-labe |
| `0xFCAD` | `176255` | W SHA | `374` | SHAW | - | W | D-labe |
| `0xFCAE` | `176256` | BY SHR | `400` | SHRBY | - | BY | D-labe |
| `0xFCAF` | `176257` | H SHR | `404` | SHRHW | - | H | D-labe |
| `0xFCB0` | `176260` | W SHR | `410` | SHRW | - | W | D-labe |
| `0xFCB1` | `176261` | H RLADDR | `766` | RLADDR | - | H | D-labe |
| `0xFCB2` | `176262` | D RLADDR | `766` | RLADDR | - | D | D-labe |
| `0xFCB3` | `176263` | BI BLADDR | `771` | BLADDR | - | BI | D-labe |
| `0xFCB4` | `176264` | BY1 GETBI | `414` | GETBIBY | 0 | BY | D-labe |
| `0xFCB5` | `176265` | BY2 GETBI | `414` | GETBIBY | 1 | BY | D-labe |
| `0xFCB6` | `176266` | BY3 GETBI | `414` | GETBIBY | 2 | BY | D-labe |
| `0xFCB7` | `176267` | BY4 GETBI | `414` | GETBIBY | 3 | BY | D-labe |
| `0xFCB8` | `176270` | H1 GETBI | `420` | GETBIH | 0 | H | D-labe |
| `0xFCB9` | `176271` | H2 GETBI | `420` | GETBIH | 1 | H | D-labe |
| `0xFCBA` | `176272` | H3 GETBI | `420` | GETBIH | 2 | H | D-labe |
| `0xFCBB` | `176273` | H4 GETBI | `420` | GETBIH | 3 | H | D-labe |
| `0xFCBC` | `176274` | BY BLADDR | `771` | BLADDR | - | BY | D-labe |
| `0xFCBD` | `176275` | BI SWAP | `532` | SWAPBI | - | BI | D-labe |
| `0xFCBE` | `176276` | BY SWAP | `534` | SWAP | - | BY | D-conv |
| `0xFCBF` | `176277` | H SWAP | `534` | SWAP | - | H | D-conv |
| `0xFCC0` | `176300` | F1 AXI | `1437` | AXIF | 0 | F | D-labe |
| `0xFCC1` | `176301` | F2 AXI | `1437` | AXIF | 1 | F | D-labe |
| `0xFCC2` | `176302` | F3 AXI | `1437` | AXIF | 2 | F | D-labe |
| `0xFCC3` | `176303` | F4 AXI | `1437` | AXIF | 3 | F | D-labe |
| `0xFCC4` | `176304` | D1 AXI | `1446` | AXID | 0 | D | D-labe |
| `0xFCC5` | `176305` | D2 AXI | `1446` | AXID | 1 | D | D-labe |
| `0xFCC6` | `176306` | D3 AXI | `1446` | AXID | 2 | D | D-labe |
| `0xFCC7` | `176307` | D4 AXI | `1446` | AXID | 3 | D | D-labe |
| `0xFCC8` | `176310` | BY1 IXI | `1460` | IXIBY | 0 | BY | D-labe |
| `0xFCC9` | `176311` | BY2 IXI | `1460` | IXIBY | 1 | BY | D-labe |
| `0xFCCA` | `176312` | BY3 IXI | `1460` | IXIBY | 2 | BY | D-labe |
| `0xFCCB` | `176313` | BY4 IXI | `1460` | IXIBY | 3 | BY | D-labe |
| `0xFCCC` | `176314` | H1 IXI | `1465` | IXIHW | 0 | H | D-labe |
| `0xFCCD` | `176315` | H2 IXI | `1465` | IXIHW | 1 | H | D-labe |
| `0xFCCE` | `176316` | H3 IXI | `1465` | IXIHW | 2 | H | D-labe |
| `0xFCCF` | `176317` | H4 IXI | `1465` | IXIHW | 3 | H | D-labe |
| `0xFCD0` | `176320` | W1 IXI | `1472` | IXIW | 0 | W | D-labe |
| `0xFCD1` | `176321` | W2 IXI | `1472` | IXIW | 1 | W | D-labe |
| `0xFCD2` | `176322` | W3 IXI | `1472` | IXIW | 2 | W | D-labe |
| `0xFCD3` | `176323` | W4 IXI | `1472` | IXIW | 3 | W | D-labe |
| `0xFCD4` | `176324` | F1 SQRT | `1477` | SQRTF | 0 | F | D-labe |
| `0xFCD5` | `176325` | F2 SQRT | `1477` | SQRTF | 1 | F | D-labe |
| `0xFCD6` | `176326` | F3 SQRT | `1477` | SQRTF | 2 | F | D-labe |
| `0xFCD7` | `176327` | F4 SQRT | `1477` | SQRTF | 3 | F | D-labe |
| `0xFCD8` | `176330` | D1 SQRT | `1501` | SQRTD | 0 | D | D-labe |
| `0xFCD9` | `176331` | D2 SQRT | `1501` | SQRTD | 1 | D | D-labe |
| `0xFCDA` | `176332` | D3 SQRT | `1501` | SQRTD | 2 | D | D-labe |
| `0xFCDB` | `176333` | D4 SQRT | `1501` | SQRTD | 3 | D | D-labe |
| `0xFCDC` | `176334` | F SWAP | `534` | SWAP | - | F | D-labe |
| `0xFCDD` | `176335` | D SWAP | `536` | SWAPD | - | D | D-labe |
| `0xFCDE` | `176336` | BY LOOPI:B | `570` | LOOPIB | - | BY | D-conv |
| `0xFCDF` | `176337` | H LOOPI:B | `570` | LOOPIB | - | H | D-conv |
| `0xFCE0` | `176340` | F1 POLY | `1503` | POLYF | 0 | F | D-labe |
| `0xFCE1` | `176341` | F2 POLY | `1503` | POLYF | 1 | F | D-labe |
| `0xFCE2` | `176342` | F3 POLY | `1503` | POLYF | 2 | F | D-labe |
| `0xFCE3` | `176343` | F4 POLY | `1503` | POLYF | 3 | F | D-labe |
| `0xFCE4` | `176344` | D1 POLY | `1507` | POLYD | 0 | D | D-labe |
| `0xFCE5` | `176345` | D2 POLY | `1507` | POLYD | 1 | D | D-labe |
| `0xFCE6` | `176346` | D3 POLY | `1507` | POLYD | 2 | D | D-labe |
| `0xFCE7` | `176347` | D4 POLY | `1507` | POLYD | 3 | D | D-labe |
| `0xFCE8` | `176350` | BY1 MULAD | `2617` | MULADBY | 0 | BY | D-labe |
| `0xFCE9` | `176351` | BY2 MULAD | `2617` | MULADBY | 1 | BY | D-labe |
| `0xFCEA` | `176352` | BY3 MULAD | `2617` | MULADBY | 2 | BY | D-labe |
| `0xFCEB` | `176353` | BY4 MULAD | `2617` | MULADBY | 3 | BY | D-labe |
| `0xFCEC` | `176354` | H1 MULAD | `2623` | MULADH | 0 | H | D-labe |
| `0xFCED` | `176355` | H2 MULAD | `2623` | MULADH | 1 | H | D-labe |
| `0xFCEE` | `176356` | H3 MULAD | `2623` | MULADH | 2 | H | D-labe |
| `0xFCEF` | `176357` | H4 MULAD | `2623` | MULADH | 3 | H | D-labe |
| `0xFCF0` | `176360` | F1 MULAD | `2633` | MULADF | 0 | F | D-labe |
| `0xFCF1` | `176361` | F2 MULAD | `2633` | MULADF | 1 | F | D-labe |
| `0xFCF2` | `176362` | F3 MULAD | `2633` | MULADF | 2 | F | D-labe |
| `0xFCF3` | `176363` | F4 MULAD | `2633` | MULADF | 3 | F | D-labe |
| `0xFCF4` | `176364` | D1 MULAD | `2635` | MULADD | 0 | D | D-labe |
| `0xFCF5` | `176365` | D2 MULAD | `2635` | MULADD | 1 | D | D-labe |
| `0xFCF6` | `176366` | D3 MULAD | `2635` | MULADD | 2 | D | D-labe |
| `0xFCF7` | `176367` | D4 MULAD | `2635` | MULADD | 3 | D | D-labe |
| `0xFCF8` | `176370` | BY1 PSUM | `2640` | PSUMBY | 0 | BY | D-labe |
| `0xFCF9` | `176371` | BY2 PSUM | `2640` | PSUMBY | 1 | BY | D-labe |
| `0xFCFA` | `176372` | BY3 PSUM | `2640` | PSUMBY | 2 | BY | D-labe |
| `0xFCFB` | `176373` | BY4 PSUM | `2640` | PSUMBY | 3 | BY | D-labe |
| `0xFCFC` | `176374` | H1 PSUM | `2644` | PSUMH | 0 | H | D-labe |
| `0xFCFD` | `176375` | H2 PSUM | `2644` | PSUMH | 1 | H | D-labe |
| `0xFCFE` | `176376` | H3 PSUM | `2644` | PSUMH | 2 | H | D-labe |
| `0xFCFF` | `176377` | H4 PSUM | `2644` | PSUMH | 3 | H | D-labe |
| `0xFD00` | `176400` | W1 PSUM | `2650` | PSUMW | 0 | W | D-labe |
| `0xFD01` | `176401` | W2 PSUM | `2650` | PSUMW | 1 | W | D-labe |
| `0xFD02` | `176402` | W3 PSUM | `2650` | PSUMW | 2 | W | D-labe |
| `0xFD03` | `176403` | W4 PSUM | `2650` | PSUMW | 3 | W | D-labe |
| `0xFD04` | `176404` | F1 PSUM | `2655` | PSUMF | 0 | F | D-labe |
| `0xFD05` | `176405` | F2 PSUM | `2655` | PSUMF | 1 | F | D-labe |
| `0xFD06` | `176406` | F3 PSUM | `2655` | PSUMF | 2 | F | D-labe |
| `0xFD07` | `176407` | F4 PSUM | `2655` | PSUMF | 3 | F | D-labe |
| `0xFD08` | `176410` | D1 PSUM | `2661` | PSUMD | 0 | D | D-labe |
| `0xFD09` | `176411` | D2 PSUM | `2661` | PSUMD | 1 | D | D-labe |
| `0xFD0A` | `176412` | D3 PSUM | `2661` | PSUMD | 2 | D | D-labe |
| `0xFD0B` | `176413` | D4 PSUM | `2661` | PSUMD | 3 | D | D-labe |
| `0xFD0C` | `176414` | BY1 LIND | `1576` | LIND | 0 | BY | D-conv |
| `0xFD0D` | `176415` | BY2 LIND | `1576` | LIND | 1 | BY | D-conv |
| `0xFD0E` | `176416` | BY3 LIND | `1576` | LIND | 2 | BY | D-conv |
| `0xFD0F` | `176417` | BY4 LIND | `1576` | LIND | 3 | BY | D-conv |
| `0xFD10` | `176420` | H1 LIND | `1576` | LIND | 0 | H | D-conv |
| `0xFD11` | `176421` | H2 LIND | `1576` | LIND | 1 | H | D-conv |
| `0xFD12` | `176422` | H3 LIND | `1576` | LIND | 2 | H | D-conv |
| `0xFD13` | `176423` | H4 LIND | `1576` | LIND | 3 | H | D-conv |
| `0xFD14` | `176424` | BY1 CIND | `1613` | CINDBY | 0 | BY | D-labe |
| `0xFD15` | `176425` | BY2 CIND | `1613` | CINDBY | 1 | BY | D-labe |
| `0xFD16` | `176426` | BY3 CIND | `1613` | CINDBY | 2 | BY | D-labe |
| `0xFD17` | `176427` | BY4 CIND | `1613` | CINDBY | 3 | BY | D-labe |
| `0xFD18` | `176430` | H1 CIND | `1617` | CINDH | 0 | H | D-labe |
| `0xFD19` | `176431` | H2 CIND | `1617` | CINDH | 1 | H | D-labe |
| `0xFD1A` | `176432` | H3 CIND | `1617` | CINDH | 2 | H | D-labe |
| `0xFD1B` | `176433` | H4 CIND | `1617` | CINDH | 3 | H | D-labe |
| `0xFD1C` | `176434` | F LOOPI:B | `600` | FLOOPIB | - | F | D-labe |
| `0xFD1D` | `176435` | D LOOPI:B | `604` | DLOOPIB | - | D | D-labe |
| `0xFD1E` | `176436` | BY LOOPI:H | `574` | LOOPIH | - | BY | D-conv |
| `0xFD1F` | `176437` | H LOOPI:H | `574` | LOOPIH | - | H | D-conv |
| `0xFD20` | `176440` | BY BMOVE | `1204` | BMOVEBY | - | BY | D-labe |
| `0xFD21` | `176441` | F LOOPI:H | `602` | FLOOPIH | - | F | D-labe |
| `0xFD22` | `176442` | D LOOPI:H | `607` | DLOOPIH | - | D | D-labe |
| `0xFD23` | `176443` | BY LOOPD:B | `612` | LOOPDB | - | BY | D-conv |
| `0xFD24` | `176444` | H LOOPD:B | `612` | LOOPDB | - | H | D-conv |
| `0xFD25` | `176445` | W LOOPD:B | `612` | LOOPDB | - | W | D-conv |
| `0xFD26` | `176446` | F LOOPD:B | `622` | FLOOPDB | - | F | D-labe |
| `0xFD27` | `176447` | D LOOPD:B | `626` | DLOOPDB | - | D | D-labe |
| `0xFD28` | `176450` | BY LOOPD:H | `616` | LOOPDH | - | BY | D-conv |
| `0xFD29` | `176451` | H LOOPD:H | `616` | LOOPDH | - | H | D-conv |
| `0xFD2A` | `176452` | W LOOPD:H | `616` | LOOPDH | - | W | D-conv |
| `0xFD2B` | `176453` | F LOOPD:H | `624` | FLOOPDH | - | F | D-labe |
| `0xFD2C` | `176454` | D LOOPD:H | `631` | DLOOPDH | - | D | D-labe |
| `0xFD2D` | `176455` | BY LOOP:B | `634` | LOOPB | - | BY | D-conv |
| `0xFD2E` | `176456` | H LOOP:B | `634` | LOOPB | - | H | D-conv |
| `0xFD2F` | `176457` | W LOOP:B | `634` | LOOPB | - | W | D-conv |
| `0xFD30` | `176460` | F LOOP:B | `634` | LOOPB | - | F | D-conv |
| `0xFD31` | `176461` | D LOOP:B | `634` | LOOPB | - | D | D-conv |
| `0xFD32` | `176462` | BY LOOP:H | `640` | LOOPH | - | BY | D-conv |
| `0xFD33` | `176463` | H LOOP:H | `640` | LOOPH | - | H | D-conv |
| `0xFD34` | `176464` | W LOOP:H | `640` | LOOPH | - | W | D-conv |
| `0xFD35` | `176465` | F LOOP:H | `640` | LOOPH | - | F | D-conv |
| `0xFD36` | `176466` | D LOOP:H | `640` | LOOPH | - | D | D-conv |
| `0xFD37` | `176467` | H BLADDR | `771` | BLADDR | - | H | D-labe |
| `0xFD38` | `176470` | D BLADDR | `771` | BLADDR | - | D | D-labe |
| `0xFD39` | `176471` | SETE | `713` | SETE | - | ? | D-labe |
| `0xFD3A` | `176472` | CLTE | `715` | CLTE | - | ? | D-labe |
| `0xFD3B` | `176473` | L:= | `1002` | LOAL | - | ? | D-conv |
| `0xFD3C` | `176474` | W1/F1 LADDR | `761` | LADDRN | 0 | W | D-conv |
| `0xFD3D` | `176475` | W2/F2 LADDR | `761` | LADDRN | 1 | W | D-conv |
| `0xFD3E` | `176476` | W3/F3 LADDR | `761` | LADDRN | 2 | W | D-conv |
| `0xFD3F` | `176477` | W4/F4 LADDR | `761` | LADDRN | 3 | W | D-conv |
| `0xFD40` | `176500` | BY TSET | `757` | TSET | - | BY | D-labe |
| `0xFD44` | `176504` | BI BYCONV | `1526` | BYCONVBI | - | BI | D-labe |
| `0xFD45` | `176505` | BI HCONV | `1536` | HCONVBI | - | BI | D-labe |
| `0xFD46` | `176506` | BI WCONV | `1547` | WCONVBI | - | BI | D-labe |
| `0xFD47` | `176507` | BI FCONV | `1561` | FCONVBI | - | BI | D-labe |
| `0xFD48` | `176510` | BI DCONV | `1570` | DCONVBI | - | BI | D-labe |
| `0xFD49` | `176511` | BY BICONV | `1514` | BICONVBY | - | BY | D-labe |
| `0xFD4A` | `176512` | BY HCONV | `1542` | HCONVBY | - | BY | D-labe |
| `0xFD4B` | `176513` | BY WCONV | `1553` | WCONVBY | - | BY | D-labe |
| `0xFD4C` | `176514` | BY FCONV | `2667` | BYCONVF | - | BY | D-labe |
| `0xFD4D` | `176515` | BY DCONV | `2733` | DCONVBY | - | BY | D-labe |
| `0xFD4E` | `176516` | H BICONV | `1516` | BICONVH | - | H | D-labe |
| `0xFD4F` | `176517` | H BYCONV | `1532` | BYCONVH | - | H | D-labe |
| `0xFD50` | `176520` | H WCONV | `1556` | WCONVH | - | H | D-labe |
| `0xFD51` | `176521` | H FCONV | `2700` | HCONVF | - | H | D-labe |
| `0xFD52` | `176522` | H DCONV | `2736` | DCONVH | - | H | D-labe |
| `0xFD53` | `176523` | W BICONV | `1520` | BICONVW | - | W | D-labe |
| `0xFD54` | `176524` | W BYCONV | `1534` | BYCONVW | - | W | D-labe |
| `0xFD55` | `176525` | W HCONV | `1545` | HCONVW | - | W | D-labe |
| `0xFD56` | `176526` | W FCONV | `2711` | WCONVF | - | W | D-labe |
| `0xFD57` | `176527` | W DCONV | `2741` | DCONVW | - | W | D-labe |
| `0xFD58` | `176530` | F BICONV | `1522` | BICONVF | - | F | D-labe |
| `0xFD59` | `176531` | F BYCONV | `2717` | FCONVBY | - | F | D-labe |
| `0xFD5A` | `176532` | F HCONV | `2723` | FCONVH | - | F | D-labe |
| `0xFD5B` | `176533` | F WCONV | `2727` | FCONVW | - | F | D-labe |
| `0xFD5C` | `176534` | F DCONV | `1574` | DCONVF | - | F | D-labe |
| `0xFD5D` | `176535` | D BICONV | `1524` | BICONVD | - | D | D-labe |
| `0xFD5E` | `176536` | D BYCONV | `2673` | BYCONVD | - | D | D-labe |
| `0xFD5F` | `176537` | D HCONV | `2704` | HCONVD | - | D | D-labe |
| `0xFD60` | `176540` | D WCONV | `2714` | WCONVD | - | D | D-labe |
| `0xFD61` | `176541` | D FCONV | `1565` | FCONVD | - | D | D-labe |
| `0xFD62` | `176542` | P=: | `1137` | STORP | - | ? | D-conv |
| `0xFD63` | `176543` | W/F BLADDR | `771` | BLADDR | - | W | D-labe |
| `0xFD64` | `176544` | IF ST GO:H | `562` | IFSTH | - | H | D-labe |
| `0xFD65` | `176545` | IF -ST GO:B | `564` | IFNSTB | - | BY | D-labe |
| `0xFD66` | `176546` | BI SMOVE | `1235` | SMOVEBI | - | BI | D-labe |
| `0xFD67` | `176547` | BY SMOVE | `1237` | SMOVEBY | - | BY | D-labe |
| `0xFD68` | `176550` | H SMOVE | `1241` | SMOVEHW | - | H | D-labe |
| `0xFD69` | `176551` | W SMOVE | `1243` | SMOVEW | - | W | D-labe |
| `0xFD6B` | `176553` | D SMOVE | `1245` | SMOVED | - | D | D-labe |
| `0xFD6C` | `176554` | W1 CHAI1 | `753` | CHAIN | 0 | W | D-labe |
| `0xFD6D` | `176555` | W2 CHAI2 | `753` | CHAIN | 1 | W | D-labe |
| `0xFD6E` | `176556` | W3 CHAI3 | `753` | CHAIN | 2 | W | D-labe |
| `0xFD6F` | `176557` | W4 CHAI4 | `753` | CHAIN | 3 | W | D-labe |
| `0xFD70` | `176560` | MTE1=: | `1127` | STORMTE1 | - | ? | D-conv |
| `0xFD71` | `176561` | MTE2=: | `1131` | STORMTE2 | - | ? | D-conv |
| `0xFD72` | `176562` | BY SMVWH | `1247` | SMVWH | - | BY | D-labe |
| `0xFD73` | `176563` | BY SMVUN | `1251` | SMVUN | - | BY | D-labe |
| `0xFD74` | `176564` | BY SMVTR | `1253` | SMVTR | - | BY | D-labe |
| `0xFD75` | `176565` | BY SMVTU | `1255` | SMVTU | - | BY | D-labe |
| `0xFD76` | `176566` | BI SMOVN | `1257` | SMOVNBI | - | BI | D-labe |
| `0xFD77` | `176567` | BY SMOVN | `1261` | SMOVNBY | - | BY | D-labe |
| `0xFD78` | `176570` | H SMOVN | `1263` | SMOVNH | - | H | D-labe |
| `0xFD79` | `176571` | W SMOVN | `1265` | SMOVNW | - | W | D-labe |
| `0xFD7B` | `176573` | D SMOVN | `1267` | SMOVND | - | D | D-labe |
| `0xFD7C` | `176574` | BI1 SFILL | `1271` | SFILLBI | 0 | BI | D-labe |
| `0xFD7D` | `176575` | BI2 SFILL | `1271` | SFILLBI | 1 | BI | D-labe |
| `0xFD7E` | `176576` | BI3 SFILL | `1271` | SFILLBI | 2 | BI | D-labe |
| `0xFD7F` | `176577` | BI4 SFILL | `1271` | SFILLBI | 3 | BI | D-labe |
| `0xFD80` | `176600` | BY1 SFILL | `1273` | SFILLBY | 0 | BY | D-labe |
| `0xFD81` | `176601` | BY2 SFILL | `1273` | SFILLBY | 1 | BY | D-labe |
| `0xFD82` | `176602` | BY3 SFILL | `1273` | SFILLBY | 2 | BY | D-labe |
| `0xFD83` | `176603` | BY4 SFILL | `1273` | SFILLBY | 3 | BY | D-labe |
| `0xFD84` | `176604` | H1 SFILL | `1275` | SFILLH | 0 | H | D-labe |
| `0xFD85` | `176605` | H2 SFILL | `1275` | SFILLH | 1 | H | D-labe |
| `0xFD86` | `176606` | H3 SFILL | `1275` | SFILLH | 2 | H | D-labe |
| `0xFD87` | `176607` | H4 SFILL | `1275` | SFILLH | 3 | H | D-labe |
| `0xFD88` | `176610` | W1 SFILL | `1277` | SFILLW | 0 | W | D-labe |
| `0xFD89` | `176611` | W2 SFILL | `1277` | SFILLW | 1 | W | D-labe |
| `0xFD8A` | `176612` | W3 SFILL | `1277` | SFILLW | 2 | W | D-labe |
| `0xFD8B` | `176613` | W4 SFILL | `1277` | SFILLW | 3 | W | D-labe |
| `0xFD90` | `176620` | D1 SFILL | `1301` | SFILLD | 0 | D | D-labe |
| `0xFD91` | `176621` | D2 SFILL | `1301` | SFILLD | 1 | D | D-labe |
| `0xFD92` | `176622` | D3 SFILL | `1301` | SFILLD | 2 | D | D-labe |
| `0xFD93` | `176623` | D4 SFILL | `1301` | SFILLD | 3 | D | D-labe |
| `0xFD94` | `176624` | BI1 SFILL1 | `1303` | SFILLNBI | 0 | BI | D-labe |
| `0xFD95` | `176625` | BI2 SFILL2 | `1303` | SFILLNBI | 1 | BI | D-labe |
| `0xFD96` | `176626` | BI3 SFILL3 | `1303` | SFILLNBI | 2 | BI | D-labe |
| `0xFD97` | `176627` | BI4 SFILL4 | `1303` | SFILLNBI | 3 | BI | D-labe |
| `0xFD98` | `176630` | BY1 SFILL1 | `1305` | SFILLNBY | 0 | BY | D-labe |
| `0xFD99` | `176631` | BY2 SFILL2 | `1305` | SFILLNBY | 1 | BY | D-labe |
| `0xFD9A` | `176632` | BY3 SFILL3 | `1305` | SFILLNBY | 2 | BY | D-labe |
| `0xFD9B` | `176633` | BY4 SFILL4 | `1305` | SFILLNBY | 3 | BY | D-labe |
| `0xFD9C` | `176634` | H1 SFILL1 | `1307` | SFILLNH | 0 | H | D-labe |
| `0xFD9D` | `176635` | H2 SFILL2 | `1307` | SFILLNH | 1 | H | D-labe |
| `0xFD9E` | `176636` | H3 SFILL3 | `1307` | SFILLNH | 2 | H | D-labe |
| `0xFD9F` | `176637` | H4 SFILL4 | `1307` | SFILLNH | 3 | H | D-labe |
| `0xFDA0` | `176640` | W1 SFILL1 | `1311` | SFILLNW | 0 | W | D-labe |
| `0xFDA1` | `176641` | W2 SFILL2 | `1311` | SFILLNW | 1 | W | D-labe |
| `0xFDA2` | `176642` | W3 SFILL3 | `1311` | SFILLNW | 2 | W | D-labe |
| `0xFDA3` | `176643` | W4 SFILL4 | `1311` | SFILLNW | 3 | W | D-labe |
| `0xFDA8` | `176650` | D1 SFILL1 | `1313` | SFILLND | 0 | D | D-labe |
| `0xFDA9` | `176651` | D2 SFILL2 | `1313` | SFILLND | 1 | D | D-labe |
| `0xFDAA` | `176652` | D3 SFILL3 | `1313` | SFILLND | 2 | D | D-labe |
| `0xFDAB` | `176653` | D4 SFILL4 | `1313` | SFILLND | 3 | D | D-labe |
| `0xFDAC` | `176654` | BY SCOMP | `1315` | SCOMP | - | BY | D-labe |
| `0xFDAD` | `176655` | BY SCOTR | `1317` | SCOTR | - | BY | D-labe |
| `0xFDAE` | `176656` | BY SSKIP | `1325` | SSKIP | - | BY | D-labe |
| `0xFDAF` | `176657` | BI SLOCA | `1330` | SLOCABI | - | BI | D-labe |
| `0xFDB0` | `176660` | BY SLOCA | `1333` | SLOCABY | - | BY | D-labe |
| `0xFDB1` | `176661` | BY SSCAN | `1336` | SSCAN | - | BY | D-labe |
| `0xFDB2` | `176662` | BY SSPAN | `1341` | SSPAN | - | BY | D-labe |
| `0xFDB3` | `176663` | BY SMATCH | `1344` | SMATCH | - | BY | D-labe |
| `0xFDB4` | `176664` | BY SSPAR | `1346` | SSPAR | - | BY | D-labe |
| `0xFDB5` | `176665` | BY SCHPAR | `1351` | SCHPAR | - | BY | D-labe |
| `0xFDB6` | `176666` | FREEB | `1000` | FREEB | - | ? | D-labe |
| `0xFDB7` | `176667` | HL:= | `1004` | LOAHL | - | ? | D-conv |
| `0xFDB8` | `176670` | LL:= | `1007` | LOALL | - | ? | D-conv |
| `0xFDB9` | `176671` | ST1:= | `1012` | LOAST1 | - | W | D-conv |
| `0xFDBA` | `176672` | CAD | `1024` | LOACAD | - | ? | D-conv |
| `0xFDBB` | `176673` | OTE1:= | `1014` | LOATE1 | - | ? | D-conv |
| `0xFDBC` | `176674` | OTE2:= | `1016` | LOATE2 | - | ? | D-conv |
| `0xFDBD` | `176675` | TOS:= | `1020` | LOATOS | - | ? | D-conv |
| `0xFDBE` | `176676` | BY SCOPA | `1321` | SCOPA | - | BY | D-labe |
| `0xFDBF` | `176677` | BY SCOPT | `1323` | SCOPT | - | BY | D-labe |
| `0xFDC0` | `176700` | L=: | `1077` | STORL | - | ? | D-conv |
| `0xFDC1` | `176701` | HL=: | `1101` | STORHL | - | ? | D-conv |
| `0xFDC2` | `176702` | LL=: | `1104` | STORLL | - | ? | D-conv |
| `0xFDC3` | `176703` | ST1=: | `1107` | STORST1 | - | ? | D-conv |
| `0xFDC5` | `176705` | OTE1=: | `1123` | STORTE1 | - | ? | D-conv |
| `0xFDC6` | `176706` | OTE2=: | `1125` | STORTE2 | - | ? | D-conv |
| `0xFDC7` | `176707` | F ENTIER | `2127` | ENTIERF | - | F | D-labe |
| `0xFDC8` | `176710` | D ENTIER | `2131` | DENT | - | D | D-labe |
| `0xFDC9` | `176711` | TOS=: | `1133` | STORTOS | - | ? | D-conv |
| `0xFDCA` | `176712` | THA:= | `1022` | LOATHA | - | ? | D-conv |
| `0xFDCB` | `176713` | THA=: | `1135` | STORTHA | - | ? | D-conv |
| `0xFDCC` | `176714` | BI1 AND | `337` | ANDBI | 0 | BI | D-labe |
| `0xFDCD` | `176715` | BI2 AND | `337` | ANDBI | 1 | BI | D-labe |
| `0xFDCE` | `176716` | BI3 AND | `337` | ANDBI | 2 | BI | D-labe |
| `0xFDCF` | `176717` | BI4 AND | `337` | ANDBI | 3 | BI | D-labe |
| `0xFDD0` | `176720` | W1 GETBI | `424` | GETBIW | 0 | W | D-labe |
| `0xFDD1` | `176721` | W2 GETBI | `424` | GETBIW | 1 | W | D-labe |
| `0xFDD2` | `176722` | W3 GETBI | `424` | GETBIW | 2 | W | D-labe |
| `0xFDD3` | `176723` | W4 GETBI | `424` | GETBIW | 3 | W | D-labe |
| `0xFDD4` | `176724` | BY1 PUTBI | `460` | PUTBIBY | 0 | BY | D-labe |
| `0xFDD5` | `176725` | BY2 PUTBI | `460` | PUTBIBY | 1 | BY | D-labe |
| `0xFDD6` | `176726` | BY3 PUTBI | `460` | PUTBIBY | 2 | BY | D-labe |
| `0xFDD7` | `176727` | BY4 PUTBI | `460` | PUTBIBY | 3 | BY | D-labe |
| `0xFDD8` | `176730` | H1 PUTBI | `464` | PUTBIH | 0 | H | D-labe |
| `0xFDD9` | `176731` | H2 PUTBI | `464` | PUTBIH | 1 | H | D-labe |
| `0xFDDA` | `176732` | H3 PUTBI | `464` | PUTBIH | 2 | H | D-labe |
| `0xFDDB` | `176733` | H4 PUTBI | `464` | PUTBIH | 3 | H | D-labe |
| `0xFDDC` | `176734` | W1 PUTBI | `470` | PUTBIW | 0 | W | D-labe |
| `0xFDDD` | `176735` | W2 PUTBI | `470` | PUTBIW | 1 | W | D-labe |
| `0xFDDE` | `176736` | W3 PUTBI | `470` | PUTBIW | 2 | W | D-labe |
| `0xFDDF` | `176737` | W4 PUTBI | `470` | PUTBIW | 3 | W | D-labe |
| `0xFDE0` | `176740` | BY1 GETBF | `474` | GETBFBY | 0 | BY | D-labe |
| `0xFDE1` | `176741` | BY2 GETBF | `474` | GETBFBY | 1 | BY | D-labe |
| `0xFDE2` | `176742` | BY3 GETBF | `474` | GETBFBY | 2 | BY | D-labe |
| `0xFDE3` | `176743` | BY4 GETBF | `474` | GETBFBY | 3 | BY | D-labe |
| `0xFDE4` | `176744` | H1 GETBF | `501` | GETBFH | 0 | H | D-labe |
| `0xFDE5` | `176745` | H2 GETBF | `501` | GETBFH | 1 | H | D-labe |
| `0xFDE6` | `176746` | H3 GETBF | `501` | GETBFH | 2 | H | D-labe |
| `0xFDE7` | `176747` | H4 GETBF | `501` | GETBFH | 3 | H | D-labe |
| `0xFDE8` | `176750` | W1 GETBF | `506` | GETBFW | 0 | W | D-labe |
| `0xFDE9` | `176751` | W2 GETBF | `506` | GETBFW | 1 | W | D-labe |
| `0xFDEA` | `176752` | W3 GETBF | `506` | GETBFW | 2 | W | D-labe |
| `0xFDEB` | `176753` | W4 GETBF | `506` | GETBFW | 3 | W | D-labe |
| `0xFDEC` | `176754` | BY1 PUTBF | `513` | PUTBFBY | 0 | BY | D-labe |
| `0xFDED` | `176755` | BY2 PUTBF | `513` | PUTBFBY | 1 | BY | D-labe |
| `0xFDEE` | `176756` | BY3 PUTBF | `513` | PUTBFBY | 2 | BY | D-labe |
| `0xFDEF` | `176757` | BY4 PUTBF | `513` | PUTBFBY | 3 | BY | D-labe |
| `0xFDF0` | `176760` | H1 PUTBF | `520` | PUTBFH | 0 | H | D-labe |
| `0xFDF1` | `176761` | H2 PUTBF | `520` | PUTBFH | 1 | H | D-labe |
| `0xFDF2` | `176762` | H3 PUTBF | `520` | PUTBFH | 2 | H | D-labe |
| `0xFDF3` | `176763` | H4 PUTBF | `520` | PUTBFH | 3 | H | D-labe |
| `0xFDF4` | `176764` | W1 PUTBF | `525` | PUTBFW | 0 | W | D-labe |
| `0xFDF5` | `176765` | W2 PUTBF | `525` | PUTBFW | 1 | W | D-labe |
| `0xFDF6` | `176766` | W3 PUTBF | `525` | PUTBFW | 2 | W | D-labe |
| `0xFDF7` | `176767` | W4 PUTBF | `525` | PUTBFW | 3 | W | D-labe |
| `0xFDF8` | `176770` | BI1 OR | `342` | ORBI | 0 | BI | D-labe |
| `0xFDF9` | `176771` | BI2 OR | `342` | ORBI | 1 | BI | D-labe |
| `0xFDFA` | `176772` | BI3 OR | `342` | ORBI | 2 | BI | D-labe |
| `0xFDFB` | `176773` | BI4 OR | `342` | ORBI | 3 | BI | D-labe |
| `0xFDFC` | `176774` | BI1 XOR | `345` | XORBI | 0 | BI | D-labe |
| `0xFDFD` | `176775` | BI2 XOR | `345` | XORBI | 1 | BI | D-labe |
| `0xFDFE` | `176776` | BI3 XOR | `345` | XORBI | 2 | BI | D-labe |
| `0xFDFF` | `176777` | BI4 XOR | `345` | XORBI | 3 | BI | D-labe |
| `0xFE00` | `177000` | SOLO | `711` | SOLO | - | ? | D-labe |
| `0xFE01` | `177001` | TUTTI | `712` | TUTTI | - | ? | D-labe |
| `0xFE02` | `177002` | SETK | `774` | SETK | - | ? | D-labe |
| `0xFE03` | `177003` | CLRK | `775` | CLRK | - | ? | D-labe |
| `0xFE04` | `177004` | EXT (W, group 1) | `1641` | RES3 | - | ? | M-ch12 |
| `0xFE05` | `177005` | EXT (W, group 1) | `1642` | RES4 | - | ? | M-ch12 |
| `0xFE06` | `177006` | EXT (W, group 1) | `1643` | RES5 | - | ? | M-ch12 |
| `0xFE07` | `177007` | EXT (W, group 1) | `1644` | RES6 | - | ? | M-ch12 |
| `0xFE08` | `177010` | BY1 NEG | `254` | NEG | 0 | BY | D-conv |
| `0xFE09` | `177011` | BY2 NEG | `254` | NEG | 1 | BY | D-conv |
| `0xFE0A` | `177012` | BY3 NEG | `254` | NEG | 2 | BY | D-conv |
| `0xFE0B` | `177013` | BY4 NEG | `254` | NEG | 3 | BY | D-conv |
| `0xFE0C` | `177014` | H1 NEG | `254` | NEG | 0 | H | D-conv |
| `0xFE0D` | `177015` | H2 NEG | `254` | NEG | 1 | H | D-conv |
| `0xFE0E` | `177016` | H3 NEG | `254` | NEG | 2 | H | D-conv |
| `0xFE0F` | `177017` | H4 NEG | `254` | NEG | 3 | H | D-conv |
| `0xFE10` | `177020` | BI1 INV | `257` | INVBI | 0 | BI | D-labe |
| `0xFE11` | `177021` | BI2 INV | `257` | INVBI | 1 | BI | D-labe |
| `0xFE12` | `177022` | BI3 INV | `257` | INVBI | 2 | BI | D-labe |
| `0xFE13` | `177023` | BI4 INV | `257` | INVBI | 3 | BI | D-labe |
| `0xFE14` | `177024` | BY1 INV | `260` | INV | 0 | BY | D-conv |
| `0xFE15` | `177025` | BY2 INV | `260` | INV | 1 | BY | D-conv |
| `0xFE16` | `177026` | BY3 INV | `260` | INV | 2 | BY | D-conv |
| `0xFE17` | `177027` | BY4 INV | `260` | INV | 3 | BY | D-conv |
| `0xFE18` | `177030` | H1 INV | `260` | INV | 0 | H | D-conv |
| `0xFE19` | `177031` | H2 INV | `260` | INV | 1 | H | D-conv |
| `0xFE1A` | `177032` | H3 INV | `260` | INV | 2 | H | D-conv |
| `0xFE1B` | `177033` | H4 INV | `260` | INV | 3 | H | D-conv |
| `0xFE1C` | `177034` | RETB | `706` | RETB | - | ? | D-labe |
| `0xFE1D` | `177035` | RETBK | `707` | RETBK | - | ? | D-labe |
| `0xFE1E` | `177036` | EXT (W, group 1) - B30: DCDUMP | `1645` | DCDUMP | - | ? | M-ch12 |
| `0xFE1F` | `177037` | EXT (W, group 1) - B30: EXINT | `1646` | EXINT | - | ? | M-ch12 |
| `0xFE20` | `177040` | BI1 LADDR | `761` | LADDRN | 0 | BI | D-conv |
| `0xFE21` | `177041` | BI2 LADDR | `761` | LADDRN | 1 | BI | D-conv |
| `0xFE22` | `177042` | BI3 LADDR | `761` | LADDRN | 2 | BI | D-conv |
| `0xFE23` | `177043` | BI4 LADDR | `761` | LADDRN | 3 | BI | D-conv |
| `0xFE24` | `177044` | BY1 LADDR | `761` | LADDRN | 0 | BY | D-conv |
| `0xFE25` | `177045` | BY2 LADDR | `761` | LADDRN | 1 | BY | D-conv |
| `0xFE26` | `177046` | BY3 LADDR | `761` | LADDRN | 2 | BY | D-conv |
| `0xFE27` | `177047` | BY4 LADDR | `761` | LADDRN | 3 | BY | D-conv |
| `0xFE28` | `177050` | H1 LADDR | `761` | LADDRN | 0 | H | D-conv |
| `0xFE29` | `177051` | H2 LADDR | `761` | LADDRN | 1 | H | D-conv |
| `0xFE2A` | `177052` | H3 LADDR | `761` | LADDRN | 2 | H | D-conv |
| `0xFE2B` | `177053` | H4 LADDR | `761` | LADDRN | 3 | H | D-conv |
| `0xFE2C` | `177054` | D1 LADDR | `763` | LADDRD | 0 | D | D-conv |
| `0xFE2D` | `177055` | D2 LADDR | `763` | LADDRD | 1 | D | D-conv |
| `0xFE2E` | `177056` | D3 LADDR | `763` | LADDRD | 2 | D | D-conv |
| `0xFE2F` | `177057` | D4 LADDR | `763` | LADDRD | 3 | D | D-conv |
| `0xFE30` | `177060` | A1:= | `1160` | LOADA1 | - | ? | D-labe |
| `0xFE31` | `177061` | A2:= | `1161` | LOADA2 | - | ? | D-labe |
| `0xFE32` | `177062` | A3:= | `1162` | LOADA3 | - | ? | D-labe |
| `0xFE33` | `177063` | A4:= | `1163` | LOADA4 | - | ? | D-labe |
| `0xFE34` | `177064` | E1:= | `1164` | LOADE1 | - | ? | D-labe |
| `0xFE35` | `177065` | E2:= | `1165` | LOADE2 | - | ? | D-labe |
| `0xFE36` | `177066` | E3:= | `1166` | LOADE3 | - | ? | D-labe |
| `0xFE37` | `177067` | E4:= | `1167` | LOADE4 | - | ? | D-labe |
| `0xFE38` | `177070` | A1=: | `1170` | STOREA1 | - | ? | D-labe |
| `0xFE39` | `177071` | A2=: | `1171` | STOREA2 | - | ? | D-labe |
| `0xFE3A` | `177072` | A3=: | `1172` | STOREA3 | - | ? | D-labe |
| `0xFE3B` | `177073` | A4=: | `1173` | STOREA4 | - | ? | D-labe |
| `0xFE3C` | `177074` | E1=: | `1174` | STOREE1 | - | ? | D-labe |
| `0xFE3D` | `177075` | E2=: | `1175` | STOREE2 | - | ? | D-labe |
| `0xFE3E` | `177076` | E3=: | `1176` | STOREE3 | - | ? | D-labe |
| `0xFE3F` | `177077` | E4=: | `1177` | STOREE4 | - | ? | D-labe |
| `0xFE40` | `177100` | W1 ADDC | `305` | ADDC | 0 | W | D-labe |
| `0xFE41` | `177101` | W2 ADDC | `305` | ADDC | 1 | W | D-labe |
| `0xFE42` | `177102` | W3 ADDC | `305` | ADDC | 2 | W | D-labe |
| `0xFE43` | `177103` | W4 ADDC | `305` | ADDC | 3 | W | D-labe |
| `0xFE44` | `177104` | W1 SUBC | `306` | SUBC | 0 | W | D-labe |
| `0xFE45` | `177105` | W2 SUBC | `306` | SUBC | 1 | W | D-labe |
| `0xFE46` | `177106` | W3 SUBC | `306` | SUBC | 2 | W | D-labe |
| `0xFE47` | `177107` | W4 SUBC | `306` | SUBC | 3 | W | D-labe |
| `0xFE48` | `177110` | W1 UDIV | `2572` | UDIV | 0 | W | D-labe |
| `0xFE49` | `177111` | W2 UDIV | `2572` | UDIV | 1 | W | D-labe |
| `0xFE4A` | `177112` | W3 UDIV | `2572` | UDIV | 2 | W | D-labe |
| `0xFE4B` | `177113` | W4 UDIV | `2572` | UDIV | 3 | W | D-labe |
| `0xFE4C` | `177114` | W1 GETB | `776` | GETB | 0 | W | D-labe |
| `0xFE4D` | `177115` | W2 GETB | `776` | GETB | 1 | W | D-labe |
| `0xFE4E` | `177116` | W3 GETB | `776` | GETB | 2 | W | D-labe |
| `0xFE4F` | `177117` | W4 GETB | `776` | GETB | 3 | W | D-labe |
| `0xFE50` | `177120` | CTE1=: | `1113` | STORCTE1 | - | ? | D-conv |
| `0xFE51` | `177121` | CTE2=: | `1115` | STORCTE2 | - | ? | D-conv |
| `0xFE52` | `177122` | TEMM1=: | `1117` | STORTEM1 | - | ? | D-conv |
| `0xFE53` | `177123` | TEMM2=: | `1121` | STORTEM2 | - | ? | D-conv |
| `0xFE54` | `177124` | CDE=: | `1142` | STORCED | - | ? | D-conv |
| `0xFE55` | `177125` | CAD=: | `1144` | STORCAD | - | ? | D-conv |
| `0xFE58` | `177130` | F1 REM | `2133` | REMF | 0 | F | D-labe |
| `0xFE59` | `177131` | F2 REM | `2133` | REMF | 1 | F | D-labe |
| `0xFE5A` | `177132` | F3 REM | `2133` | REMF | 2 | F | D-labe |
| `0xFE5B` | `177133` | F4 REM | `2133` | REMF | 3 | F | D-labe |
| `0xFE5C` | `177134` | D1 REM | `2136` | REMD | 0 | D | D-labe |
| `0xFE5D` | `177135` | D2 REM | `2136` | REMD | 1 | D | D-labe |
| `0xFE5E` | `177136` | D3 REM | `2136` | REMD | 2 | D | D-labe |
| `0xFE5F` | `177137` | D4 REM | `2136` | REMD | 3 | D | D-labe |
| `0xFE60` | `177140` | F1 INT | `2607` | INTF | 0 | F | D-labe |
| `0xFE61` | `177141` | F2 INT | `2607` | INTF | 1 | F | D-labe |
| `0xFE62` | `177142` | F3 INT | `2607` | INTF | 2 | F | D-labe |
| `0xFE63` | `177143` | F4 INT | `2607` | INTF | 3 | F | D-labe |
| `0xFE64` | `177144` | D1 INT | `2611` | INTD | 0 | D | D-labe |
| `0xFE65` | `177145` | D2 INT | `2611` | INTD | 1 | D | D-labe |
| `0xFE66` | `177146` | D3 INT | `2611` | INTD | 2 | D | D-labe |
| `0xFE67` | `177147` | D4 INT | `2611` | INTD | 3 | D | D-labe |
| `0xFE68` | `177150` | F1 INTR | `2613` | INTRF | 0 | F | D-labe |
| `0xFE69` | `177151` | F2 INTR | `2613` | INTRF | 1 | F | D-labe |
| `0xFE6A` | `177152` | F3 INTR | `2613` | INTRF | 2 | F | D-labe |
| `0xFE6B` | `177153` | F4 INTR | `2613` | INTRF | 3 | F | D-labe |
| `0xFE6C` | `177154` | D1 INTR | `2615` | INTRD | 0 | D | D-labe |
| `0xFE6D` | `177155` | D2 INTR | `2615` | INTRD | 1 | D | D-labe |
| `0xFE6E` | `177156` | D3 INTR | `2615` | INTRD | 2 | D | D-labe |
| `0xFE6F` | `177157` | D4 INTR | `2615` | INTRD | 3 | D | D-labe |
| `0xFE70` | `177160` | F byconr | `2750` | FCONRBY | - | F | D-labe |
| `0xFE71` | `177161` | D byconr | `2756` | DCONRBY | - | D | D-labe |
| `0xFE72` | `177162` | F hconr | `2752` | FCONRH | - | F | D-labe |
| `0xFE73` | `177163` | D hconr | `2761` | DCONRH | - | D | D-labe |
| `0xFE74` | `177164` | F wconr | `2754` | FCONRW | - | F | D-labe |
| `0xFE75` | `177165` | D wconr | `2764` | DCONRW | - | D | D-labe |
| `0xFE76` | `177166` | H RIOM | `745` | RIOM | - | H | D-labe |
| `0xFE78` | `177170` | H BMOVE | `1212` | BMOVEHW | - | H | D-labe |
| `0xFE79` | `177171` | W BMOVE | `1220` | BMOVEW | - | W | D-labe |
| `0xFE7B` | `177173` | D BMOVE | `1226` | BMOVED | - | D | D-labe |
| `0xFE7C` | `177174` | PS=: | `1152` | STORPS | - | ? | D-conv |
| `0xFE7D` | `177175` | BY CLEBI | `444` | CLEBIBY | - | BY | D-labe |
| `0xFE7E` | `177176` | H CLEBI | `450` | CLEBIHW | - | H | D-labe |
| `0xFE7F` | `177177` | W CLEBI | `454` | CLEBIW | - | W | D-labe |
| `0xFE80` | `177200` | BY SETBI | `430` | SETBIBY | - | BY | D-conv |
| `0xFE81` | `177201` | H SETBI | `434` | SETBIHW | - | H | D-conv |
| `0xFE82` | `177202` | W SETBI | `440` | SETBIW | - | W | D-conv |
| `0xFE83` | `177203` | W fconr | `2744` | WCONRF | - | W | D-labe |
| `0xFE84` | `177204` | D fconr | `2767` | DCONRF | - | D | D-labe |
| `0xFE85` | `177205` | PADDR | `2045` | ADDBCDR | - | ? | D-conv |
| `0xFE86` | `177206` | PSUBR | `2051` | SUBBCDR | - | ? | D-conv |
| `0xFE88` | `177210` | BI1 RPGU | `727` | RPGUBI | 0 | BI | D-labe |
| `0xFE89` | `177211` | BI2 RPGU | `727` | RPGUBI | 1 | BI | D-labe |
| `0xFE8A` | `177212` | BI3 RPGU | `727` | RPGUBI | 2 | BI | D-labe |
| `0xFE8B` | `177213` | BI4 RPGU | `727` | RPGUBI | 3 | BI | D-labe |
| `0xFE8C` | `177214` | H1 RPGU | `731` | RPGUH | 0 | H | D-labe |
| `0xFE8D` | `177215` | H2 RPGU | `731` | RPGUH | 1 | H | D-labe |
| `0xFE8E` | `177216` | H3 RPGU | `731` | RPGUH | 2 | H | D-labe |
| `0xFE8F` | `177217` | H4 RPGU | `731` | RPGUH | 3 | H | D-labe |
| `0xFE90` | `177220` | BI ZPGU | `733` | ZPGUBI | - | BI | D-labe |
| `0xFE91` | `177221` | PMPYR | `2063` | MPYBCDR | - | ? | D-conv |
| `0xFE92` | `177222` | PPACKR | `2067` | PACKR | - | ? | D-conv |
| `0xFE94` | `177224` | BI1 RWIP | `736` | RWIPBI | 0 | BI | D-labe |
| `0xFE95` | `177225` | BI2 RWIP | `736` | RWIPBI | 1 | BI | D-labe |
| `0xFE96` | `177226` | BI3 RWIP | `736` | RWIPBI | 2 | BI | D-labe |
| `0xFE97` | `177227` | BI4 RWIP | `736` | RWIPBI | 3 | BI | D-labe |
| `0xFE98` | `177230` | H1 RWIP | `740` | RWIPH | 0 | H | D-labe |
| `0xFE99` | `177231` | H2 RWIP | `740` | RWIPH | 1 | H | D-labe |
| `0xFE9A` | `177232` | H3 RWIP | `740` | RWIPH | 2 | H | D-labe |
| `0xFE9B` | `177233` | H4 RWIP | `740` | RWIPH | 3 | H | D-labe |
| `0xFE9C` | `177234` | BI ZWIP | `742` | ZWIPBI | - | BI | D-labe |
| `0xFE9D` | `177235` | BY WHOLE | `1063` | WHOLE | - | BY | D-labe |
| `0xFEA0` | `177240` | BI1 RDUS | `747` | RDUSBI | 0 | BI | D-labe |
| `0xFEA1` | `177241` | BI2 RDUS | `747` | RDUSBI | 1 | BI | D-labe |
| `0xFEA2` | `177242` | BI3 RDUS | `747` | RDUSBI | 2 | BI | D-labe |
| `0xFEA3` | `177243` | BI4 RDUS | `747` | RDUSBI | 3 | BI | D-labe |
| `0xFEA4` | `177244` | BY1 RDUS | `751` | RDUSBY | 0 | BY | D-labe |
| `0xFEA5` | `177245` | BY2 RDUS | `751` | RDUSBY | 1 | BY | D-labe |
| `0xFEA6` | `177246` | BY3 RDUS | `751` | RDUSBY | 2 | BY | D-labe |
| `0xFEA7` | `177247` | BY4 RDUS | `751` | RDUSBY | 3 | BY | D-labe |
| `0xFEA8` | `177250` | H1 RDUS | `751` | RDUSBY | 0 | H | D-labe |
| `0xFEA9` | `177251` | H2 RDUS | `751` | RDUSBY | 1 | H | D-labe |
| `0xFEAA` | `177252` | H3 RDUS | `751` | RDUSBY | 2 | H | D-labe |
| `0xFEAB` | `177253` | H4 RDUS | `751` | RDUSBY | 3 | H | D-labe |
| `0xFEAC` | `177254` | W1 RDUS | `751` | RDUSBY | 0 | W | D-labe |
| `0xFEAD` | `177255` | W2 RDUS | `751` | RDUSBY | 1 | W | D-labe |
| `0xFEAE` | `177256` | W3 RDUS | `751` | RDUSBY | 2 | W | D-labe |
| `0xFEAF` | `177257` | W4 RDUS | `751` | RDUSBY | 3 | W | D-labe |
| `0xFEB0` | `177260` | PADD | `2043` | ADDBCD | - | ? | D-conv |
| `0xFEB1` | `177261` | PSUB | `2047` | SUBBCD | - | ? | D-conv |
| `0xFEB3` | `177263` | PCOMP | `2057` | COMPBCD | - | ? | D-conv |
| `0xFEB4` | `177264` | PMPY | `2061` | MPYBCD | - | ? | D-conv |
| `0xFEB5` | `177265` | PPACK | `2065` | PACK | - | ? | D-conv |
| `0xFEC0` | `177300` | EXT (BYn, group 3) - B30: WDUSBY | `1651` | RESBY11 | 0 | BY | M-ch12 |
| `0xFEC1` | `177301` | EXT (BYn, group 3) - B30: WDUSBY | `1651` | RESBY11 | 1 | BY | M-ch12 |
| `0xFEC2` | `177302` | EXT (BYn, group 3) - B30: WDUSBY | `1651` | RESBY11 | 2 | BY | M-ch12 |
| `0xFEC3` | `177303` | EXT (BYn, group 3) - B30: WDUSBY | `1651` | RESBY11 | 3 | BY | M-ch12 |
| `0xFEC4` | `177304` | EXT (BYn, group 3) | `1653` | RESBY12 | - | ? | M-ch12 |
| `0xFEC5` | `177305` | EXT (BYn, group 3) | `1653` | RESBY12 | - | ? | M-ch12 |
| `0xFEC6` | `177306` | EXT (BYn, group 3) | `1653` | RESBY12 | - | ? | M-ch12 |
| `0xFEC7` | `177307` | EXT (BYn, group 3) | `1653` | RESBY12 | - | ? | M-ch12 |
| `0xFEC8` | `177310` | EXT (BYn, group 3) | `1655` | RESBY13 | - | ? | M-ch12 |
| `0xFEC9` | `177311` | EXT (BYn, group 3) | `1655` | RESBY13 | - | ? | M-ch12 |
| `0xFECA` | `177312` | EXT (BYn, group 3) | `1655` | RESBY13 | - | ? | M-ch12 |
| `0xFECB` | `177313` | EXT (BYn, group 3) | `1655` | RESBY13 | - | ? | M-ch12 |
| `0xFECC` | `177314` | EXT (BYn, group 3) | `1657` | RESBY14 | - | ? | M-ch12 |
| `0xFECD` | `177315` | EXT (BYn, group 3) | `1657` | RESBY14 | - | ? | M-ch12 |
| `0xFECE` | `177316` | EXT (BYn, group 3) | `1657` | RESBY14 | - | ? | M-ch12 |
| `0xFECF` | `177317` | EXT (BYn, group 3) | `1657` | RESBY14 | - | ? | M-ch12 |
| `0xFED0` | `177320` | EXT (Hn, group 3) - B30: WDUSH | `1661` | RESH11 | - | ? | M-ch12 |
| `0xFED1` | `177321` | EXT (Hn, group 3) - B30: WDUSH | `1661` | RESH11 | - | ? | M-ch12 |
| `0xFED2` | `177322` | EXT (Hn, group 3) - B30: WDUSH | `1661` | RESH11 | - | ? | M-ch12 |
| `0xFED3` | `177323` | EXT (Hn, group 3) - B30: WDUSH | `1661` | RESH11 | - | ? | M-ch12 |
| `0xFED4` | `177324` | EXT (Hn, group 3) | `1663` | RESH12 | - | ? | M-ch12 |
| `0xFED5` | `177325` | EXT (Hn, group 3) | `1663` | RESH12 | - | ? | M-ch12 |
| `0xFED6` | `177326` | EXT (Hn, group 3) | `1663` | RESH12 | - | ? | M-ch12 |
| `0xFED7` | `177327` | EXT (Hn, group 3) | `1663` | RESH12 | - | ? | M-ch12 |
| `0xFED8` | `177330` | EXT (Hn, group 3) | `1665` | RESH13 | - | ? | M-ch12 |
| `0xFED9` | `177331` | EXT (Hn, group 3) | `1665` | RESH13 | - | ? | M-ch12 |
| `0xFEDA` | `177332` | EXT (Hn, group 3) | `1665` | RESH13 | - | ? | M-ch12 |
| `0xFEDB` | `177333` | EXT (Hn, group 3) | `1665` | RESH13 | - | ? | M-ch12 |
| `0xFEDC` | `177334` | EXT (Hn, group 3) | `1667` | RESH14 | - | ? | M-ch12 |
| `0xFEDD` | `177335` | EXT (Hn, group 3) | `1667` | RESH14 | - | ? | M-ch12 |
| `0xFEDE` | `177336` | EXT (Hn, group 3) | `1667` | RESH14 | - | ? | M-ch12 |
| `0xFEDF` | `177337` | EXT (Hn, group 3) | `1667` | RESH14 | - | ? | M-ch12 |
| `0xFEE0` | `177340` | EXT (Wn, group 3) - B30: WDUSW | `1671` | RESW11 | - | ? | M-ch12 |
| `0xFEE1` | `177341` | EXT (Wn, group 3) - B30: WDUSW | `1671` | RESW11 | - | ? | M-ch12 |
| `0xFEE2` | `177342` | EXT (Wn, group 3) - B30: WDUSW | `1671` | RESW11 | - | ? | M-ch12 |
| `0xFEE3` | `177343` | EXT (Wn, group 3) - B30: WDUSW | `1671` | RESW11 | - | ? | M-ch12 |
| `0xFEE4` | `177344` | EXT (Wn, group 3) | `1673` | RESW12 | - | ? | M-ch12 |
| `0xFEE5` | `177345` | EXT (Wn, group 3) | `1673` | RESW12 | - | ? | M-ch12 |
| `0xFEE6` | `177346` | EXT (Wn, group 3) | `1673` | RESW12 | - | ? | M-ch12 |
| `0xFEE7` | `177347` | EXT (Wn, group 3) | `1673` | RESW12 | - | ? | M-ch12 |
| `0xFEE8` | `177350` | EXT (Wn, group 3) | `1675` | RESW13 | - | ? | M-ch12 |
| `0xFEE9` | `177351` | EXT (Wn, group 3) | `1675` | RESW13 | - | ? | M-ch12 |
| `0xFEEA` | `177352` | EXT (Wn, group 3) | `1675` | RESW13 | - | ? | M-ch12 |
| `0xFEEB` | `177353` | EXT (Wn, group 3) | `1675` | RESW13 | - | ? | M-ch12 |
| `0xFEEC` | `177354` | EXT (Wn, group 3) | `1677` | RESW14 | - | ? | M-ch12 |
| `0xFEED` | `177355` | EXT (Wn, group 3) | `1677` | RESW14 | - | ? | M-ch12 |
| `0xFEEE` | `177356` | EXT (Wn, group 3) | `1677` | RESW14 | - | ? | M-ch12 |
| `0xFEEF` | `177357` | EXT (Wn, group 3) | `1677` | RESW14 | - | ? | M-ch12 |
| `0xFEF0` | `177360` | EXT (Fn, group 3) | `1701` | RESF11 | - | ? | M-ch12 |
| `0xFEF1` | `177361` | EXT (Fn, group 3) | `1701` | RESF11 | - | ? | M-ch12 |
| `0xFEF2` | `177362` | EXT (Fn, group 3) | `1701` | RESF11 | - | ? | M-ch12 |
| `0xFEF3` | `177363` | EXT (Fn, group 3) | `1701` | RESF11 | - | ? | M-ch12 |
| `0xFEF4` | `177364` | EXT (Fn, group 3) | `1703` | RESF12 | - | ? | M-ch12 |
| `0xFEF5` | `177365` | EXT (Fn, group 3) | `1703` | RESF12 | - | ? | M-ch12 |
| `0xFEF6` | `177366` | EXT (Fn, group 3) | `1703` | RESF12 | - | ? | M-ch12 |
| `0xFEF7` | `177367` | EXT (Fn, group 3) | `1703` | RESF12 | - | ? | M-ch12 |
| `0xFEF8` | `177370` | EXT (Fn, group 3) | `1705` | RESF13 | - | ? | M-ch12 |
| `0xFEF9` | `177371` | EXT (Fn, group 3) | `1705` | RESF13 | - | ? | M-ch12 |
| `0xFEFA` | `177372` | EXT (Fn, group 3) | `1705` | RESF13 | - | ? | M-ch12 |
| `0xFEFB` | `177373` | EXT (Fn, group 3) | `1705` | RESF13 | - | ? | M-ch12 |
| `0xFEFC` | `177374` | EXT (Fn, group 3) | `1707` | RESF14 | - | ? | M-ch12 |
| `0xFEFD` | `177375` | EXT (Fn, group 3) | `1707` | RESF14 | - | ? | M-ch12 |
| `0xFEFE` | `177376` | EXT (Fn, group 3) | `1707` | RESF14 | - | ? | M-ch12 |
| `0xFEFF` | `177377` | EXT (Fn, group 3) | `1707` | RESF14 | - | ? | M-ch12 |
| `0xFF00` | `177400` | BY1 ABS | `263` | ABS | 0 | BY | D-conv |
| `0xFF01` | `177401` | BY2 ABS | `263` | ABS | 1 | BY | D-conv |
| `0xFF02` | `177402` | BY3 ABS | `263` | ABS | 2 | BY | D-conv |
| `0xFF03` | `177403` | BY4 ABS | `263` | ABS | 3 | BY | D-conv |
| `0xFF04` | `177404` | H1 ABS | `263` | ABS | 0 | H | D-conv |
| `0xFF05` | `177405` | H2 ABS | `263` | ABS | 1 | H | D-conv |
| `0xFF06` | `177406` | H3 ABS | `263` | ABS | 2 | H | D-conv |
| `0xFF07` | `177407` | H4 ABS | `263` | ABS | 3 | H | D-conv |
| `0xFF08` | `177410` | W1 ABS | `263` | ABS | 0 | W | D-conv |
| `0xFF09` | `177411` | W2 ABS | `263` | ABS | 1 | W | D-conv |
| `0xFF0A` | `177412` | W3 ABS | `263` | ABS | 2 | W | D-conv |
| `0xFF0B` | `177413` | W4 ABS | `263` | ABS | 3 | W | D-conv |
| `0xFF0C` | `177414` | F1 ABS | `265` | ABSF | 0 | F | D-labe |
| `0xFF0D` | `177415` | F2 ABS | `265` | ABSF | 1 | F | D-labe |
| `0xFF0E` | `177416` | F3 ABS | `265` | ABSF | 2 | F | D-labe |
| `0xFF0F` | `177417` | F4 ABS | `265` | ABSF | 3 | F | D-labe |
| `0xFF10` | `177420` | W1 INVC | `261` | INVC | 0 | W | D-labe |
| `0xFF11` | `177421` | W2 INVC | `261` | INVC | 1 | W | D-labe |
| `0xFF12` | `177422` | W3 INVC | `261` | INVC | 2 | W | D-labe |
| `0xFF13` | `177423` | W4 INVC | `261` | INVC | 3 | W | D-labe |
| `0xFF14` | `177424` | PCC | `717` | PCC | - | ? | D-labe |
| `0xFF15` | `177425` | DCC | `720` | DCC | - | ? | D-labe |
| `0xFF16` | `177426` | DMON | `721` | DMON | - | ? | D-labe |
| `0xFF17` | `177427` | PMON | `722` | PMON | - | ? | D-labe |
| `0xFF18` | `177430` | DMOF | `723` | DMOF | - | ? | D-labe |
| `0xFF19` | `177431` | PMOF | `724` | PMOF | - | ? | D-labe |
| `0xFF1A` | `177432` | CPGU | `735` | CPGU | - | ? | D-labe |
| `0xFF1B` | `177433` | CWIP | `744` | CWIP | - | ? | D-labe |
| `0xFF1C` | `177434` | PCTSB | `725` | PCTSB | - | ? | D-labe |
| `0xFF1D` | `177435` | DCTSB | `726` | DCTSB | - | ? | D-labe |
| `0xFF1E` | `177436` | CLINIT | `1647` | CLINIT | - | ? | M-ch12 |
| `0xFF1F` | `177437` | CLREAD | `1650` | CLREAD | - | ? | M-ch12 |
| `0xFF20` | `177440` | EXT (Dn, group 3) | `1711` | RESD11 | - | ? | M-ch12 |
| `0xFF21` | `177441` | EXT (Dn, group 3) | `1711` | RESD11 | - | ? | M-ch12 |
| `0xFF22` | `177442` | EXT (Dn, group 3) | `1711` | RESD11 | - | ? | M-ch12 |
| `0xFF23` | `177443` | EXT (Dn, group 3) | `1711` | RESD11 | - | ? | M-ch12 |
| `0xFF24` | `177444` | EXT (Dn, group 3) | `1713` | RESD12 | - | ? | M-ch12 |
| `0xFF25` | `177445` | EXT (Dn, group 3) | `1713` | RESD12 | - | ? | M-ch12 |
| `0xFF26` | `177446` | EXT (Dn, group 3) | `1713` | RESD12 | - | ? | M-ch12 |
| `0xFF27` | `177447` | EXT (Dn, group 3) | `1713` | RESD12 | - | ? | M-ch12 |
| `0xFF28` | `177450` | EXT (Dn, group 3) | `1715` | RESD13 | - | ? | M-ch12 |
| `0xFF29` | `177451` | EXT (Dn, group 3) | `1715` | RESD13 | - | ? | M-ch12 |
| `0xFF2A` | `177452` | EXT (Dn, group 3) | `1715` | RESD13 | - | ? | M-ch12 |
| `0xFF2B` | `177453` | EXT (Dn, group 3) | `1715` | RESD13 | - | ? | M-ch12 |
| `0xFF2C` | `177454` | EXT (Dn, group 3) | `1717` | RESD14 | - | ? | M-ch12 |
| `0xFF2D` | `177455` | EXT (Dn, group 3) | `1717` | RESD14 | - | ? | M-ch12 |
| `0xFF2E` | `177456` | EXT (Dn, group 3) | `1717` | RESD14 | - | ? | M-ch12 |
| `0xFF2F` | `177457` | EXT (Dn, group 3) | `1717` | RESD14 | - | ? | M-ch12 |
| `0xFF30` | `177460` | EXT (BY, group 2) | `1721` | RESBY15 | - | ? | M-ch12 |
| `0xFF31` | `177461` | EXT (BY, group 2) | `1723` | RESBY16 | - | ? | M-ch12 |
| `0xFF32` | `177462` | EXT (BY, group 2) | `1725` | RESBY17 | - | ? | M-ch12 |
| `0xFF33` | `177463` | EXT (BY, group 2) - B30: PLCCNBY | `1727` | PLCCNBY | - | ? | M-ch12 |
| `0xFF34` | `177464` | EXT (BY, group 2) | `1731` | RESBY19 | - | ? | M-ch12 |
| `0xFF35` | `177465` | EXT (BY, group 2) | `1733` | RESBY20 | - | ? | M-ch12 |
| `0xFF36` | `177466` | EXT (BY, group 2) | `1735` | RESBY21 | - | ? | M-ch12 |
| `0xFF37` | `177467` | EXT (BY, group 2) | `1737` | RESBY22 | - | ? | M-ch12 |
| `0xFF38` | `177470` | EXT (H, group 2) | `1741` | RESH15 | - | ? | M-ch12 |
| `0xFF39` | `177471` | EXT (H, group 2) | `1743` | RESH16 | - | ? | M-ch12 |
| `0xFF3A` | `177472` | EXT (H, group 2) | `1745` | RESH17 | - | ? | M-ch12 |
| `0xFF3B` | `177473` | EXT (H, group 2) - B30: PLCCNH | `1747` | PLCCNH | - | ? | M-ch12 |
| `0xFF3C` | `177474` | EXT (H, group 2) | `1751` | RESH19 | - | ? | M-ch12 |
| `0xFF3D` | `177475` | EXT (H, group 2) | `1753` | RESH20 | - | ? | M-ch12 |
| `0xFF3E` | `177476` | EXT (H, group 2) | `1755` | RESH21 | - | ? | M-ch12 |
| `0xFF3F` | `177477` | EXT (H, group 2) | `1757` | RESH22 | - | ? | M-ch12 |
| `0xFF40` | `177500` | EXT (W, group 2) | `1761` | RESW15 | - | ? | M-ch12 |
| `0xFF41` | `177501` | EXT (W, group 2) | `1763` | RESW16 | - | ? | M-ch12 |
| `0xFF42` | `177502` | EXT (W, group 2) | `1765` | RESW17 | - | ? | M-ch12 |
| `0xFF43` | `177503` | EXT (W, group 2) - B30: PLCCN (W) | `1767` | PLCCN | - | ? | M-ch12 |
| `0xFF44` | `177504` | EXT (W, group 2) - B30: LOADPS | `1771` | LOADPS | - | ? | M-ch12 |
| `0xFF45` | `177505` | EXT (W, group 2) | `1773` | RESW20 | - | ? | M-ch12 |
| `0xFF46` | `177506` | EXT (W, group 2) | `1775` | RESW21 | - | ? | M-ch12 |
| `0xFF47` | `177507` | EXT (W, group 2) | `1777` | RESW22 | - | ? | M-ch12 |
| `0xFF48` | `177510` | EXT (F, group 2) | `2001` | RESF15 | - | ? | M-ch12 |
| `0xFF49` | `177511` | EXT (F, group 2) | `2003` | RESF16 | - | ? | M-ch12 |
| `0xFF4A` | `177512` | EXT (F, group 2) | `2005` | RESF17 | - | ? | M-ch12 |
| `0xFF4B` | `177513` | EXT (F, group 2) - B30: PLCCNF | `2007` | PLCCNF | - | ? | M-ch12 |
| `0xFF4C` | `177514` | EXT (F, group 2) | `2011` | RESF19 | - | ? | M-ch12 |
| `0xFF4D` | `177515` | EXT (F, group 2) | `2013` | RESF20 | - | ? | M-ch12 |
| `0xFF4E` | `177516` | EXT (F, group 2) | `2015` | RESF21 | - | ? | M-ch12 |
| `0xFF4F` | `177517` | EXT (F, group 2) | `2017` | RESF22 | - | ? | M-ch12 |
| `0xFF50` | `177520` | EXT (D, group 2) | `2021` | RESD15 | - | ? | M-ch12 |
| `0xFF51` | `177521` | EXT (D, group 2) | `2023` | RESD16 | - | ? | M-ch12 |
| `0xFF52` | `177522` | EXT (D, group 2) | `2025` | RESD17 | - | ? | M-ch12 |
| `0xFF53` | `177523` | EXT (D, group 2) - B30: PLCCND | `2027` | PLCCND | - | ? | M-ch12 |
| `0xFF54` | `177524` | EXT (D, group 2) | `2031` | RESD19 | - | ? | M-ch12 |
| `0xFF55` | `177525` | EXT (D, group 2) | `2033` | RESD20 | - | ? | M-ch12 |
| `0xFF56` | `177526` | EXT (D, group 2) | `2035` | RESD21 | - | ? | M-ch12 |
| `0xFF57` | `177527` | EXT (D, group 2) | `2037` | RESD22 | - | ? | M-ch12 |
| `0xFF58` | `177530` | F1 SI1 | `1354` | SINF | 0 | F | D-labe |
| `0xFF59` | `177531` | F2 SI2 | `1354` | SINF | 1 | F | D-labe |
| `0xFF5A` | `177532` | F3 SI3 | `1354` | SINF | 2 | F | D-labe |
| `0xFF5B` | `177533` | F4 SI4 | `1354` | SINF | 3 | F | D-labe |
| `0xFF5C` | `177534` | F1 ASI1 | `1360` | ASINF | 0 | F | D-labe |
| `0xFF5D` | `177535` | F2 ASI2 | `1360` | ASINF | 1 | F | D-labe |
| `0xFF5E` | `177536` | F3 ASI3 | `1360` | ASINF | 2 | F | D-labe |
| `0xFF5F` | `177537` | F4 ASI4 | `1360` | ASINF | 3 | F | D-labe |
| `0xFF60` | `177540` | F1 COS | `1364` | COSF | 0 | F | D-labe |
| `0xFF61` | `177541` | F2 COS | `1364` | COSF | 1 | F | D-labe |
| `0xFF62` | `177542` | F3 COS | `1364` | COSF | 2 | F | D-labe |
| `0xFF63` | `177543` | F4 COS | `1364` | COSF | 3 | F | D-labe |
| `0xFF64` | `177544` | F1 ACOS | `1370` | ACOSF | 0 | F | D-labe |
| `0xFF65` | `177545` | F2 ACOS | `1370` | ACOSF | 1 | F | D-labe |
| `0xFF66` | `177546` | F3 ACOS | `1370` | ACOSF | 2 | F | D-labe |
| `0xFF67` | `177547` | F4 ACOS | `1370` | ACOSF | 3 | F | D-labe |
| `0xFF68` | `177550` | F1 TA1 | `1374` | TANF | 0 | F | D-labe |
| `0xFF69` | `177551` | F2 TA2 | `1374` | TANF | 1 | F | D-labe |
| `0xFF6A` | `177552` | F3 TA3 | `1374` | TANF | 2 | F | D-labe |
| `0xFF6B` | `177553` | F4 TA4 | `1374` | TANF | 3 | F | D-labe |
| `0xFF6C` | `177554` | F1 ATA1 | `1400` | ATANF | 0 | F | D-labe |
| `0xFF6D` | `177555` | F2 ATA2 | `1400` | ATANF | 1 | F | D-labe |
| `0xFF6E` | `177556` | F3 ATA3 | `1400` | ATANF | 2 | F | D-labe |
| `0xFF6F` | `177557` | F4 ATA4 | `1400` | ATANF | 3 | F | D-labe |
| `0xFF70` | `177560` | F1 ATAN2 | `1410` | ATAN2F | 0 | F | D-labe |
| `0xFF71` | `177561` | F2 ATAN2 | `1410` | ATAN2F | 1 | F | D-labe |
| `0xFF72` | `177562` | F3 ATAN2 | `1410` | ATAN2F | 2 | F | D-labe |
| `0xFF73` | `177563` | F4 ATAN2 | `1410` | ATAN2F | 3 | F | D-labe |
| `0xFF74` | `177564` | F1 EXP | `1417` | EXPF | 0 | F | D-labe |
| `0xFF75` | `177565` | F2 EXP | `1417` | EXPF | 1 | F | D-labe |
| `0xFF76` | `177566` | F3 EXP | `1417` | EXPF | 2 | F | D-labe |
| `0xFF77` | `177567` | F4 EXP | `1417` | EXPF | 3 | F | D-labe |
| `0xFF78` | `177570` | F1 ALOG | `1423` | ALOGF | 0 | F | D-labe |
| `0xFF79` | `177571` | F2 ALOG | `1423` | ALOGF | 1 | F | D-labe |
| `0xFF7A` | `177572` | F3 ALOG | `1423` | ALOGF | 2 | F | D-labe |
| `0xFF7B` | `177573` | F4 ALOG | `1423` | ALOGF | 3 | F | D-labe |
| `0xFF7C` | `177574` | F1 ALOG2 | `1427` | ALOG2F | 0 | F | D-labe |
| `0xFF7D` | `177575` | F2 ALOG2 | `1427` | ALOG2F | 1 | F | D-labe |
| `0xFF7E` | `177576` | F3 ALOG2 | `1427` | ALOG2F | 2 | F | D-labe |
| `0xFF7F` | `177577` | F4 ALOG2 | `1427` | ALOG2F | 3 | F | D-labe |
| `0xFF80` | `177600` | F1 ALOG10 | `1433` | ALOG10F | 0 | F | D-labe |
| `0xFF81` | `177601` | F2 ALOG10 | `1433` | ALOG10F | 1 | F | D-labe |
| `0xFF82` | `177602` | F3 ALOG10 | `1433` | ALOG10F | 2 | F | D-labe |
| `0xFF83` | `177603` | F4 ALOG10 | `1433` | ALOG10F | 3 | F | D-labe |
| `0xFF84` | `177604` | D1 SI1 | `1356` | SIND | 0 | D | D-labe |
| `0xFF85` | `177605` | D2 SI2 | `1356` | SIND | 1 | D | D-labe |
| `0xFF86` | `177606` | D3 SI3 | `1356` | SIND | 2 | D | D-labe |
| `0xFF87` | `177607` | D4 SI4 | `1356` | SIND | 3 | D | D-labe |
| `0xFF88` | `177610` | D1 ASI1 | `1362` | ASIND | 0 | D | D-labe |
| `0xFF89` | `177611` | D2 ASI2 | `1362` | ASIND | 1 | D | D-labe |
| `0xFF8A` | `177612` | D3 ASI3 | `1362` | ASIND | 2 | D | D-labe |
| `0xFF8B` | `177613` | D4 ASI4 | `1362` | ASIND | 3 | D | D-labe |
| `0xFF8C` | `177614` | D1 COS | `1366` | COSD | 0 | D | D-labe |
| `0xFF8D` | `177615` | D2 COS | `1366` | COSD | 1 | D | D-labe |
| `0xFF8E` | `177616` | D3 COS | `1366` | COSD | 2 | D | D-labe |
| `0xFF8F` | `177617` | D4 COS | `1366` | COSD | 3 | D | D-labe |
| `0xFF90` | `177620` | D1 ACOS | `1372` | ACOSD | 0 | D | D-labe |
| `0xFF91` | `177621` | D2 ACOS | `1372` | ACOSD | 1 | D | D-labe |
| `0xFF92` | `177622` | D3 ACOS | `1372` | ACOSD | 2 | D | D-labe |
| `0xFF93` | `177623` | D4 ACOS | `1372` | ACOSD | 3 | D | D-labe |
| `0xFF94` | `177624` | D1 TA1 | `1376` | TAND | 0 | D | D-labe |
| `0xFF95` | `177625` | D2 TA2 | `1376` | TAND | 1 | D | D-labe |
| `0xFF96` | `177626` | D3 TA3 | `1376` | TAND | 2 | D | D-labe |
| `0xFF97` | `177627` | D4 TA4 | `1376` | TAND | 3 | D | D-labe |
| `0xFF98` | `177630` | D1 ATA1 | `1403` | ATAND | 0 | D | D-labe |
| `0xFF99` | `177631` | D2 ATA2 | `1403` | ATAND | 1 | D | D-labe |
| `0xFF9A` | `177632` | D3 ATA3 | `1403` | ATAND | 2 | D | D-labe |
| `0xFF9B` | `177633` | D4 ATA4 | `1403` | ATAND | 3 | D | D-labe |
| `0xFF9C` | `177634` | D1 ATAN2 | `1413` | ATAN2D | 0 | D | D-labe |
| `0xFF9D` | `177635` | D2 ATAN2 | `1413` | ATAN2D | 1 | D | D-labe |
| `0xFF9E` | `177636` | D3 ATAN2 | `1413` | ATAN2D | 2 | D | D-labe |
| `0xFF9F` | `177637` | D4 ATAN2 | `1413` | ATAN2D | 3 | D | D-labe |
| `0xFFA0` | `177640` | D1 EXP | `1421` | EXPD | 0 | D | D-labe |
| `0xFFA1` | `177641` | D2 EXP | `1421` | EXPD | 1 | D | D-labe |
| `0xFFA2` | `177642` | D3 EXP | `1421` | EXPD | 2 | D | D-labe |
| `0xFFA3` | `177643` | D4 EXP | `1421` | EXPD | 3 | D | D-labe |
| `0xFFA4` | `177644` | D1 ALOG | `1425` | ALOGD | 0 | D | D-labe |
| `0xFFA5` | `177645` | D2 ALOG | `1425` | ALOGD | 1 | D | D-labe |
| `0xFFA6` | `177646` | D3 ALOG | `1425` | ALOGD | 2 | D | D-labe |
| `0xFFA7` | `177647` | D4 ALOG | `1425` | ALOGD | 3 | D | D-labe |
| `0xFFA8` | `177650` | D1 ALOG2 | `1431` | ALOG2D | 0 | D | D-labe |
| `0xFFA9` | `177651` | D2 ALOG2 | `1431` | ALOG2D | 1 | D | D-labe |
| `0xFFAA` | `177652` | D3 ALOG2 | `1431` | ALOG2D | 2 | D | D-labe |
| `0xFFAB` | `177653` | D4 ALOG2 | `1431` | ALOG2D | 3 | D | D-labe |
| `0xFFAC` | `177654` | D1 ALOG10 | `1435` | ALOG10D | 0 | D | D-labe |
| `0xFFAD` | `177655` | D2 ALOG10 | `1435` | ALOG10D | 1 | D | D-labe |
| `0xFFAE` | `177656` | D3 ALOG10 | `1435` | ALOG10D | 2 | D | D-labe |
| `0xFFAF` | `177657` | D4 ALOG10 | `1435` | ALOG10D | 3 | D | D-labe |
| `0xFFBC` | `177674` | BY1 AMODB | `27537` | IREM_BY | 0 | BY | D-conv |
| `0xFFBD` | `177675` | BY2 AMODB | `27537` | IREM_BY | 1 | BY | D-conv |
| `0xFFBE` | `177676` | BY3 AMODB | `27537` | IREM_BY | 2 | BY | D-conv |
| `0xFFBF` | `177677` | BY4 AMODB | `27537` | IREM_BY | 3 | BY | D-conv |
| `0xFFC0` | `177700` | H1 AMODB | `27537` | IREM_BY | 0 | H | D-conv |
| `0xFFC1` | `177701` | H2 AMODB | `27537` | IREM_BY | 1 | H | D-conv |
| `0xFFC2` | `177702` | H3 AMODB | `27537` | IREM_BY | 2 | H | D-conv |
| `0xFFC3` | `177703` | H4 AMODB | `27537` | IREM_BY | 3 | H | D-conv |
| `0xFFC4` | `177704` | W1 AMODB | `27537` | IREM_BY | 0 | W | D-conv |
| `0xFFC5` | `177705` | W2 AMODB | `27537` | IREM_BY | 1 | W | D-conv |
| `0xFFC6` | `177706` | W3 AMODB | `27537` | IREM_BY | 2 | W | D-conv |
| `0xFFC7` | `177707` | W4 AMODB | `27537` | IREM_BY | 3 | W | D-conv |
| `0xFFC8` | `177710` | F1 LIND | `1603` | LINDF | 0 | F | D-labe |
| `0xFFC9` | `177711` | F2 LIND | `1603` | LINDF | 1 | F | D-labe |
| `0xFFCA` | `177712` | F3 LIND | `1603` | LINDF | 2 | F | D-labe |
| `0xFFCB` | `177713` | F4 LIND | `1603` | LINDF | 3 | F | D-labe |
| `0xFFCC` | `177714` | D1 LIND | `1607` | LINDD | 0 | D | D-labe |
| `0xFFCD` | `177715` | D2 LIND | `1607` | LINDD | 1 | D | D-labe |
| `0xFFCE` | `177716` | D3 LIND | `1607` | LINDD | 2 | D | D-labe |
| `0xFFCF` | `177717` | D4 LIND | `1607` | LINDD | 3 | D | D-labe |
| `0xFFD0` | `177720` | F1 CIND | `1627` | CINDF | 0 | F | D-labe |
| `0xFFD1` | `177721` | F2 CIND | `1627` | CINDF | 1 | F | D-labe |
| `0xFFD2` | `177722` | F3 CIND | `1627` | CINDF | 2 | F | D-labe |
| `0xFFD3` | `177723` | F4 CIND | `1627` | CINDF | 3 | F | D-labe |
| `0xFFD4` | `177724` | D1 CIND | `1633` | CINDD | 0 | D | D-labe |
| `0xFFD5` | `177725` | D2 CIND | `1633` | CINDD | 1 | D | D-labe |
| `0xFFD6` | `177726` | D3 CIND | `1633` | CINDD | 2 | D | D-labe |
| `0xFFD7` | `177727` | D4 CIND | `1633` | CINDD | 3 | D | D-labe |
| `0xFFE8` | `177750` | W1 REXT | `1053` | REXT | 0 | W | D-labe |
| `0xFFE9` | `177751` | W2 REXT | `1053` | REXT | 1 | W | D-labe |
| `0xFFEA` | `177752` | W3 REXT | `1053` | REXT | 2 | W | D-labe |
| `0xFFEB` | `177753` | W4 REXT | `1053` | REXT | 3 | W | D-labe |
| `0xFFEC` | `177754` | W1 WEXT | `1055` | WEXT | 0 | W | D-labe |
| `0xFFED` | `177755` | W2 WEXT | `1055` | WEXT | 1 | W | D-labe |
| `0xFFEE` | `177756` | W3 WEXT | `1055` | WEXT | 2 | W | D-labe |
| `0xFFEF` | `177757` | W4 WEXT | `1055` | WEXT | 3 | W | D-labe |
| `0xFFF0` | `177760` | t1 PHYLADR | `1026` | PHYLADR | 0 | W | D-labe |
| `0xFFF1` | `177761` | t2 PHYLADR | `1026` | PHYLADR | 1 | W | D-labe |
| `0xFFF2` | `177762` | t3 PHYLADR | `1026` | PHYLADR | 2 | W | D-labe |
| `0xFFF3` | `177763` | t4 PHYLADR | `1026` | PHYLADR | 3 | W | D-labe |
| `0xFFF4` | `177764` | WPHS | `1061` | WPHS | - | ? | D-labe |
| `0xFFF5` | `177765` | RPHS | `1057` | RPHS | - | ? | D-labe |
| `0xFFF6` | `177766` | LREGBL | `1030` | LREGBL | - | W | D-labe |
| `0xFFF7` | `177767` | SREGBL | `1033` | SREGBL | - | W | D-labe |
| `0xFFF8` | `177770` | LCNTXT | `1036` | LCNTXT | - | W | D-labe |
| `0xFFF9` | `177771` | SCNTXT | `1042` | SCNTXT | - | ? | D-labe |
| `0xFFFB` | `177773` | SVERS | `1051` | SVERS | - | ? | D-labe |
| `0xFFFC` | `177774` | SCPUNO | `1047` | SCPUNO | - | ? | D-labe |
| `0xFFFD` | `177775` | W PLCCN | `1073` | PLCCNBI | - | W | D-conv |
| `0xFFFE` | `177776` | W NCPLC | `1075` | NCPLC | - | W | D-labe |


---

## Appendix C — sources

### Primary — the microcode itself

| Path | What |
|---|---|
| `E:\Dev\Ronny\ND5000UC\docs\MC\MICRO-5800-B30.DATA` | The control-store image. 16384 × 128 bits, word *N* at byte offset *N*×16, big-endian. **Authoritative for every field value.** |
| `E:\Dev\Ronny\ND5000UC\docs\MC\MICRO-5800-B30.LABE` | The assembler cross-reference: 3457 labels, 3356 distinct addresses, 5548 reference sites. Format `LABEL <defaddr>* <refaddr>…`, octal, CR-terminated. Strip CRs before parsing. |
| `E:\Dev\Ronny\ND5000UC\docs\MC\MICRO-5800-A30.DATA` / `.LABE` | The WM-406 sibling build. 11315 of 16384 words differ. |
| `E:\Dev\Ronny\ND5000UC\docs\MC\5800-30.TEXT` | The **ND program description sheet** for release `211276D`. Primary ND document. |
| `E:\Dev\Ronny\ND5000UC\docs\MC\5800-29.TEXT` | The sheet for `211276C` — carries nine real opcode numbers and the nucleus error codes. |
| `E:\Dev\Ronny\ND5000UC\docs\MC\5800-27.TEXT` | The sheet for `211276A`. |
| `E:\Dev\Ronny\ND5000UC\microcode\MICRO-5800-B30.md` | Rendered disassembly. Good for flow. **Its ORCON / MARG / IX\*n columns are wrong.** |

### Official Norsk Data documents

| Document | Notes |
|---|---|
| `manual\ND-05.022.1 EN ND-5000 Microprogram Guide.md` (+ `.pdf`) | ch.2 microword format, ch.5 ALU/AAP, ch.6 registers, ch.7 sequencing, ch.8 conditions, ch.9 status, ch.10 address arithmetic, ch.11 assembler, **ch.12 the opcode↔entry anchors**, Appendix A mnemonics. **Pages 5, 13, 17, 23, 45, 47 failed OCR; Appendix B (the field chart) OCR'd into invented content — use the PDF.** |
| `manual\ND-05.020.01 EN ND-5000 Hardware Description.md` (+ `.pdf`) | §3.3 IMAP/OMAP, ch.6 MMS, ch.7 IAC/IDU/DAC, ch.8 the MIC/sequencer, ch.9 ALU/registers/LC, ch.10 AAP, ch.11 IDU nanostates, Tables 6/7/8/13/14/15/17/18/20/23/24/26/27/28/30/31/33/34/35, Appendix 4 modus register. **Appendix 3 (the field chart) OCR'd into invented content — use the PDF.** |
| ND-05.017.01 | The ND-500 operator/monitor manual — source of the `P` / `P1` diagnostic procedure and the trap tables. |
| ND-05.009.04 | ND-500 Reference Manual — the opcode tables. **We work from nd500x's transcription, not the document.** |
| ND-05.013.03 / ND-05.018.01 | Single- and double-precision array-processing functions. **Not held.** These document 1145 words of the image. |
| ND-05.021.01 | ND-5000 Design Information. **Not held.** |

### Project artefacts

| Path | What |
|---|---|
| `E:\Dev\Repos\Ronny\RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\` | The microword CPU. `src\CpuND5000.cs` (4403 lines), `Microword.cs`, `Sequencer.cs`, `Conditions.cs`, `Alu.cs`, `Registers.cs`, `OperandRouter.cs`, `MmsUnit.cs`, `Aap.cs`, `ControlStore.cs`, `CsAddr.cs`, `Generated\*`, `tools\microcode-5000-def.json`, `tests\*` (122 files), `tests\known-red.txt`. |
| `…\docs\DISPATCH-MAP.md` | The dispatch reconstruction log. **Its §4 and §7 record counts are stale (1020 vs the current 1183).** |
| `…\docs\dispatch-map-b30.json` | The 1183 curated dispatch records. |
| `…\docs\MICROCODE-ARCHITECTURE.md` | Architecture write-up. **Its §10 Tier-3 "throws" table is stale** — everything it lists as unimplemented now works. |
| `…\docs\TICK-MODEL.md`, `BOOT-STARTUP.md`, `ND5000-MACHINE-STATE-REFERENCE.md`, `MMU-REGISTER-CROSSCHECK.md` | Supporting write-ups. |
| `E:\Dev\Ronny\ND5000UC\docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md` | 251 KB, the message/ACCP spine. 421 verified points, 106 open. §11 here is its summary. |
| `E:\Dev\Ronny\ND5000UC\docs\ND5000-IDA-MODULES.md` | The IDA card family, and the confirmed-negative on any IMAP/OMAP dump. |
| `E:\Dev\Ronny\ND5000UC\docs\ND5000-DOM-LOAD-MONCALL-MICROCODE-REFERENCE-2026-08-20.md` | Domain load and monitor-call detail. |
| `E:\Dev\Ronny\ND5000UC\microcode\MAILBOX-MICROCODE-PSEUDOCODE.md` | Mailbox pseudo-code. **Its §3.8 `CALL_END` table is off by one MON number** — corrected in §12.3 here. |
| `E:\Dev\Ronny\ND5000UC\GROUND-TRUTH.md` | Which source wins for which kind of claim. |
| `E:\Dev\Ronny\NDIX-C\kernel\MASTER\machine\pcb.h` etc. | The real ND-500 Unix kernel — byte-exact `struct pcb`, capability masks, PST indexes, `locore.c`'s `fecall`. |
| `~/repos/nd500x` (WSL) | The C reference emulator: `src/cpu/instructions.json` (538 opcodes), `src/cpu/instruction_helpers.h` (the ST1 flag map), `docs/instruction-reference/*.md`. |
| `E:\Dev\Ronny\ND5000UC\ALU-VERIFY-B00.LABE` and siblings | Real ND SEMICS hardware-diagnostic control stores — the checkpoint-ladder evidence in §12.5. |

### Corrections this document makes to existing project files

1. `DISPATCH-MAP.md` §4 / §7 record counts are stale (1020 → 1183).
2. The auto-generated header on `DispatchMapB30.g.cs` names the wrong input file.
3. `MICROCODE-ARCHITECTURE.md` §10 Tier-3 lists 16 features as unimplemented; all 16 now work.
4. `MAILBOX-MICROCODE-PSEUDOCODE.md` §3.8's `CALL_END` screening table is shifted by one MON number.
5. `manual\MICROCODE-FIELDS.md` and `manual\mnemonics.md` are project-derived, not manuals, and one of
   them is circular. They should not live in `manual\`.
6. `MICROCODE-FIELDS.md` invents `AAP1,A-B` and `AAP1,A/B` for codes the manual marks **Unused**.
7. The `octobus-nd5000` skill's ACCP table still lists `STARTMIC = 0x1B`; `0x1B` is `RUNTST` and
   STARTMIC is `0x36`.
8. Earlier project notes had `DUMMY_1` and `DUMMY_2` swapped; the raw words say `0o104 = DUMMY_2`,
   `0o105 = DUMMY_1`.

---

*Compiled 2026-08-24. Counts marked [V] were computed over `MICRO-5800-B30.DATA` and
`MICRO-5800-B30.LABE` while writing this document, not carried over from earlier notes.*
