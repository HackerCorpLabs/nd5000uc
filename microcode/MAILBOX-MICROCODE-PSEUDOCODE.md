# ND-5800 Microcode: The Mailbox Servicer — Reverse-Engineered Pseudo-C

**Full path:** `E:\Dev\Ronny\ND5000UC\microcode\MAILBOX-MICROCODE-PSEUDOCODE.md`

Source: `E:\Dev\Ronny\ND5000UC\microcode\MICRO-5800-B30.md` (disassembly of `MICRO-5800-B30`,
16384 words, B-series ND-5800 image). Field semantics from
`E:\Dev\Ronny\ND5000UC\manual\MICROCODE-FIELDS.md` (ND-05.022.1 / SAMSON MICROCODE DEFINITION).
SINTRAN-side cross-reference: `E:\Dev\Ronny\NDInsight\SINTRAN\ND500\ND500-WHO-ANSWERS-THE-MAILBOX.md`.

## Evidence legend — read this first

| Tag | Meaning |
|---|---|
| **[V]** | VERIFIED directly in the listing (operand/destination/jump target explicit in the microword) |
| **[D]** | DERIVED — follows from verified data flow plus one documented inference rule (below) |
| **[X]** | CROSS — matches the independently byte-verified SINTRAN-side analysis, not independently provable from the listing alone |
| **[?]** | UNKNOWN / not yet established. Do not build on these without checking |

> **2026-07-17 UPDATE:** the disassembly was regenerated LOSSLESSLY (commit a91dff4) — the
> Memory field (`RD,POF`/`WR,POF`/`READ`/`WRITE`/...), `AD_ARTI`, `EA1SAVE/EA2SAVE/EA3SAVE`,
> `ADACT`, `AA=`/`AB=`, scaling and `ORCON=` now print on every word. Inference rules 1-2
> below are OBSOLETE for the current listing (kept for history); every memory direction and
> every message offset in this document has been re-verified against the lossless listing —
> see **section 3.10** for the address-arithmetic decode model and the verified offset table.
> No decoded flow was contradicted; all [X]-anchored offsets were confirmed and promoted.

**Inference rules used for [D]:**

1. **Memory reads:** `A,DATA` is the data-input register [V per field doc]. A microword that
   consumes `A,DATA` after a `D,DAC,DPA` (load data physical address) + `ADACT` (address
   arithmetic activate) sequence is reading memory at DPA. *(Obsolete: the pre-2026-07-17
   disassembly did not render the 4-bit Memory field, so direction was inferred from data
   flow. The lossless listing prints it — every instance re-checked, all inferences held.)*
2. **Memory writes:** a microword that computes a value with **no register destination**,
   inside a DPA+ADACT sequence, is a memory write of that value (e.g. `ALU,XOR TYP,HW A,BM01
   B,SC14` with no `D,` = write halfword 2). *(Obsolete, same as rule 1 — all held.)*
3. **`B,SC14` as zero:** virtually every routine begins `ALU,FZRO ... D,SC14` (SC14 := 0) [V],
   after which `ALU,XOR A,x B,SC14` is used as "move x". Where a routine is entered with SC14
   in an unknown state this is flagged.
4. **Bit masks:** `A,BMnn` = 2^nn (nn octal) [V per field doc]. So BM00=1, BM01=2, BM02=4,
   BM06=0o100 (64), BM12=0o2000, BM37=sign bit.

**Hardware caveat [V]:** this image is for the ND-5800 (SAMSON, Octobus generation). The
ND-100 interface here is the **ACCP port** (`SPEC,AFLAG` status flags, `SPEC,AIB` output
buffer, OCB = Octobus messages) — not the classic ND-500 PCB 5015 TAG cable. The
SINTRAN-facing mailbox protocol (message layout, N5STA lifecycle, MICFU dispatch) is the
same one documented on the SINTRAN side [X], but activation/interrupt plumbing shown below
is the Octobus variant. Mapping to the classic 3022/5015 MAR/CONTROL path is [X], not [V].

---

## 1. The microcode's "global variables"

### 1.1 The SRF communication block (SRF addresses 0o2000–0o2025)

Every `ADR_*` helper loads a constant into RFA1/RFA2 (the SRF address registers); `RF1`/`RF2`
then read/write that SRF cell. All addresses below are [V] from the `ADR_*` bodies
(listing `017334`–`017402`):

| SRF addr | Set by | Contents (semantics) |
|---|---|---|
| 0o2000 | `ADR_MESS` (RFA1 := BM12) | **Current message address** in shared memory. Written `RF1 := SC12` in MSG_LINK7 [V]; read back by MSG_END to write the answer [V]. |
| 0o2002 | `ADR_FIFOB` (RFA2) | Interrupt-ident FIFO buffer descriptor, used by GIVEINT [D] |
| 0o2003 | `GET_FLAG` (RFA1) | Run-state flag: SET_RUNNING writes 0? no—writes BM00, SET_IDLE writes 0, SET_IN_TRAP increments [V writes; naming [D] from labels] |
| 0o2004 | `ADR_SYSTRA` | [?] (system trap area) |
| 0o2005 | `ADR_SYSHOS` | [?] |
| 0o2006 | `ADR_SYSPAR` / `ADR2_SYSPAR` | System parameters; GIVEINT reads ident bits from it [D] |
| 0o2007 | `ADR_MODINIT` | Initial MOD (modus) register value [D] |
| 0o2011 | `ADR_ASTBAD` | [?] |
| 0o2012 | `ADR_MOD` (RFA2) | Saved modus register (MSG_CACE writes current MOD here [V]) |
| 0o2013 | `ADR_PROC0` (RFA1) | Process-0 (swapper) related cell; MSG_END tests it to decide continue-vs-idle [V test; meaning [D]] |
| 0o2014 | `ADR_MODMASK` | Mask for legal MOD bits (MSG_CACI/CACD use it) [D] |
| 0o2015 | `ADR_CPUPAR` (RFA1) | CPU parameter halfword returned by 3RMICV [V] |
| 0o2016 | `ADR_CPUAVA` | CPU-available flag (CPU_AVAIL? check in MSG_START) [D] |
| 0o2017 | `ADR_#CPUDF` (RFA2) | **Pointer to this CPU's mailbox head cell** in shared memory. IDLE polls it; ACTIVATE/PRNOWR/MSG_CCMOVE/MSG_CCINCR dereference it [V usage; naming [D]] |
| 0o2020 | `ADR_EXQUE` (RFA2) | Execution queue [?] |
| 0o2021 | `ADR_MSGME` (RFA2) | "Message being serviced by me" flag: 1 while a message is in progress, 0 when done [D from MSG_LINK7 sets 1 / MSG_END clears / MON_ERR? tests] |
| 0o2022 | `ADR_CPUFLG` (RFA2) | CPU flag word (multi-CPU targeting test in MSG_LINK3) [D] |
| 0o2024 | `ADR_ATRAP` (RFA2) | Async-trap pending flags, consumed by ATRAP_CHK [D] |
| 0o2025 | `ADR_5SIB` (RFA1) | 5SIB pointer (X5SIBCALL) [?] |

### 1.2 Directly-addressed SRF words

- `SRF11` — tested with `COND,MSGN` (sign) all over the message loop; `MSG_KILL_P` sets its
  sign bit (`SRF11 |= BM37`) right before SET_IDLE [V]. Reads as **"current-process word;
  sign bit = no runnable process"** [D].

  > ⚠️ **CONTRADICTION — DO NOT IMPLEMENT THE `CNTXTSAVE` GATE FROM THIS DOC (flagged
  > 2026-08-25).** This `[D]` reading and the gate polarity rendered below cannot both be right:
  > ```
  > 017422-23  if ((int32)srf[SRF11] < 0) CNTXTSAVE();
  > 024724-25  if ((int32)srf[SRF11] < 0)   // "sign of SRF11 = no current process"
  >                CNTXTSAVE();             // "save macro context if one was running"
  > ```
  > Those two comments sit on the same conditional: *"sign = **no** current process"* then
  > *"save the context if one **was** running"*. Either the flag reading is inverted or the
  > condition polarity is. **Only the `MSG_KILL_P` write is `[V]`; the meaning is `[D]`.**
  >
  > **Why it matters:** if the real machine saves when `SRF11 >= 0` (a process IS current) and an
  > emulator implements `< 0`, it skips the park **exactly when a process is running** — an
  > unparked process whose message fields all still read correct.
  >
  > **The two gates are ONE question.** Raw B30, 16 bytes each — byte-identical except bytes
  > 12-13 (the jump target):
  > ```
  > 0o17422  40 00 00 01 32 01 50 00 00 00 00 00 1f 13 00 00
  > 0o24724  40 00 00 01 32 01 50 00 00 00 00 00 29 d5 00 00
  > ```
  > **Likely source of an inversion:** this CPU's **one-word condition delay** — a word's `COND,*`
  > tests the flags left by the PREVIOUS word. A rendering that ignores it comes out shifted by one
  > and still looks plausible (the same trap that got `SCAN_ACCP` bit 5 backwards).
  >
  > **RESOLVED 2-vs-1 (2026-08-25) — the GATE LINE is the outlier, not the flag reading.**
  > A third witness turned up: the ND5000 test suite sets this flag in **five** places, all with
  > the same comment —
  > ```
  > Srf[0x40B] = 0xFFFFFFFF;   // SRF11 = no current process (skip CNTXTSAVE)
  > ```
  > (`MailboxStartTests.cs:92,155`, `MicrocodeReplaySpecMeasurementTests.cs:259`,
  > `Nd5000MonCallMessageBuildTests.cs:299`, `Nd5000MonServiceLoopTests.cs:429`; and
  > `MicrocodeStartupStateProbeTests.cs:314` labels `0x40B` "SRF11 current-process (SRF 0o2013)".)
  >
  > §1.2's reading and those five comments **agree**: sign set = no current process = **nothing to
  > save** = skip. Only the gate line disagrees, and it would mean "save the context of the process
  > that does not exist". **So the real microcode is very likely `if (SRF11 >= 0) CNTXTSAVE()`** —
  > save when a process IS current. Graded `[D]`; not executed.
  >
  > **If you do verify by execution, watch the WRITES, not the pass.** A context save over an
  > empty/unused context block may be harmless, so both polarities can go green and prove nothing.
  > The informative probe is whether `CNTXTSAVE` **writes** the context block. Third site worth
  > comparing: `MSG_IDLE` (MICFU 47, `015324`), "CNTXTSAVE if needed".
- `SRF14`, `SRF15` — context/domain values consumed by MSG_UNIX5RE and MSG_HISTOG [?]
- `SRF17` — saved SC-state in MSG_CLEAR / context code [?]

### 1.3 Scratch-register conventions inside the mailbox code

| Reg | Role in this code (all [D] from consistent usage) |
|---|---|
| `SC14` | Zero register (set once per routine, used as XOR-move source) |
| `SC12` | Message address / ACCP command word staging |
| `SC10` | **The answer status for N5STA**: 3 = ANSWER, 4 = ERANSWER |
| `SC3, SC4, SC7, SC11, SC5` | Message parameter words/halfwords, loop temporaries |
| `LC` | Loop counter for block-copy loops (LCDECR/COND,LCZ) |
| `Q` | Shift register: byte/halfword remainder handling in copies |
| `MIC,VECT` | Dispatch vector: loaded with MICFU, consumed by `JMPREL` |

---

## 2. The message protocol as the microcode implements it

### 2.1 N5STA values — all four confirmed in the listing

| Value | Name (SINTRAN) | Where in the microcode |
|---|---|---|
| 1 | MSGN500 | `MSG_LINK1` (`015143`): fetched N5STA halfword XOR `BM00`(=1), equal → process; else skip [V] |
| 2 | WAITING | `MSG_LINK7` (`015205`): writes halfword `BM01`(=2) into the message before dispatch [V value, D write-direction] |
| 3 | ANSWER | every successful handler: `SC10 := BM01 + carry1` = 3 → MSG_END [V] |
| 4 | 5ERANSWER | `MSG_ILLEG` (`015221`): `SC10 := BM02` = 4 → MSG_END; also MSG_CACF reject path (`016240`) [V] |

This is an exact match with the SINTRAN-side lifecycle [X].

### 2.2 Message fields as read by the fetch path

What the listing proves is the **read order**, not absolute offsets — the ADACT address
stepping between reads (AA/AB operands, MARG displacements, IX scaling) is not rendered
per-word in the disassembly. Field *positions* are therefore anchored to the SINTRAN symbol
layout (`ND500-MAILBOX-MESSAGE-CATALOG.md` sec 1: N5STA@2, SENDE@3, X5CPU@4, X5ACT@5,
MICFU@6, all SYMBOL-grade), which the verified read order matches exactly:

```
1. MSG_LINK1 (015141-42): reads one HW  -> N5STA check (must be 1=MSGN500)   [V read, X offset=2]
2. MSG_LINK3 (015151-61): reads one HW  -> CPU-target check                  [V read, X = X5CPU@4
                                            (SINTRAN precondition X5CPU = MPACTIVE)]
3. MSG_LINK7 (015203):    reads one HW  -> SC4 (status/activation word [?])
4. MSG_LINK7 (015204):    reads one HW  -> SC3 = MICFU, becomes dispatch vector [V read, X offset=6]
5. MSG_LINK7 (015205):    writes N5STA := 2 (WAITING)                        [V value]
```

Per-MICFU parameters live in the words after the 6-word header; the handler bodies below
give the *count and width* the microcode consumes — the SINTRAN sender side is the authority
for their positions.

- MICFU range check: `64 - MICFU` sign test (`BM06` = 64) → out-of-range ⇒ `MSG_ILLEG` [V].
  Before rejecting, bit 0o17 (bit 15) of the MICFU halfword is stripped and the check retried
  (`015214`) — bit 15 of MICFU is a flag, not part of the function number [D].
- Messages are **chained**: after answering, MSG_END follows a link word and services the
  next message; the end-of-chain sentinel is **-1** (link+1 == 0 test at `017456`–`017457`)
  [V test; sentinel interpretation D].
- Multi-CPU filter: MSG_LINK3 compares a message halfword against this CPU's number
  (`SAMSON_CPU`, constant 0 in this image `000025`) and the CPUFLG cell; mismatched messages
  are skipped with RETURN [D]. Single-CPU emulation can treat every message as "for me".

### 2.3 The MICFU dispatch table (`015224`–`015323`) — all entries [V]

64-entry jump table, index = MICFU (octal). `JMPREL` from `MSG_LINK9` (`015223`).

| MICFU | Target | MICFU | Target |
|---|---|---|---|
| 00 | MSG_ILLEG | 40,41 | MSG_ILLEG |
| **01** | **MSG_VERSRD** (3RMICV) | **42** | **MSG_PRT** |
| 02,03 | MSG_ILLEG | 43 | MSG_ILLEG |
| 04–07 | MSG_ILLEG | **44** | **MSG_HISTOG** |
| **10** | **MSG_DMEMRD** | **45** | **MSG_CLEAR** |
| **11** | **MSG_DMEMWR** | **46** | **MSG_DUDC** |
| **12** | **MSG_CACHE** | **47** | **MSG_IDLE** |
| **13** | **MSG_RESIRD** | **50** | **MSG_UNIX5RE** |
| **14** | **MSG_RESIWR** | **51** | **MSG_UNIX5CM** |
| 15–17 | MSG_ILLEG | **52** | **MSG_UNIX5REL** |
| 20,21 | MSG_ILLEG | 53–67 | MSG_ILLEG |
| **22** | **MSG_STARTP0** | **70** | **MSG_INITTR** |
| **23** | **MSG_START** (3START) | **71** | **MSG_CLRTRM** |
| **24** | **MSG_CONMC** (3MONCO) | **72** | **MSG_ARMTR** |
| **25** | **MSG_START** (3TRACO shares 3START) | **73** | **MSG_DISARM** |
| **26** | **MSG_CONWR** (3WMONCO) | **74** | **MSG_DUMPTR** |
| **27** | MSG_ILLEG | **75** | **MSG_CLRADC** |
| **30** | **MSG_PHYSRD** | **76** | **MSG_CACI** |
| **31** | **MSG_PHYSWR** | **77** | **MSG_LOOKSRF** |
| **34** | **MSG_IMEMRD** / **35** **MSG_IMEMWR** | | |

**⚠ Discrepancy vs SINTRAN docs [?]:** MICFU 05 (3SWMESS, delivery-to-swapper) dispatches to
`MSG_ILLEG` in this B30 image. Either swapper messages reach the swapper another way on the
5800, or the SINTRAN-side value differs. Do NOT hard-code 05→illegal in the emulator until
the SINTRAN carve confirms what SINTRAN actually sends here.

---

## 3. Pseudo-C

Conventions: `mem[a]` = shared-memory access at physical/DPA address `a` (direction per
inference rules 1–2); `srf[n]` = SRF cell; halfword/word width noted. Original microword
addresses in comments. Subroutine calls are real microstack PUSH/RETURN pairs [V].

### 3.1 Idle loop and activation

```c
// IDLE (024670) — the ND-500 "idle" state IS this loop. No macro code runs.
void IDLE(void) {
    for (;;) {
        ATRAP_CHK();                              // 024670: service pending async traps
        uint32 head_cell = srf[ADR_CPUDF];        // 024671-72: DPA := srf[0o2017]
        if (mem[head_cell] != 0) break;           // 024673: work already queued -> skip idle-mark
        UNLOCK_QUE();                             // 024677 (via 024701 wrapper region)
        SET_IDLE();                               // 024700: srf[0o2003] := 0   ("I am idle")
        trap_param_clear();                       // 024701: D,SPEC,TRPARM
        // IDLE_1 (024702): the actual spin
        for (;;) {
            SCAN_ACCP();                          // poll ACCP flags: power-fail / OCB msgs / traps
            uint16 flag = (uint16)mem[head_cell]; // 024713-17: re-read mailbox head cell
            if (flag != 0) goto activate;         // 024720: nonzero -> IDLE_2 -> ACTIVATE
        }
    }
activate:
    ACTIVATE();                                   // 024721-22 (IDLE_2)
}

// ACTIVATE (024723) — also entered directly from an OCB "activate" command (016425/016431-32)
void ACTIVATE(void) {
    LOCK_QUE();                                   // 024723: take the shared-queue lock
    if ((int32)srf[SRF11] < 0)                    // 024724-25: sign of SRF11 = no current process
        CNTXTSAVE();                              //            save macro context if one was running
    PRNOWR(/*SC12 = SC14-1*/);                    // 024726: bookkeeping write via #CPUDF [see 3.6]
    SET_IDLE();                                   // 024727
    OCB_CLNUP();                                  // 024730
    // ACTIVATE1 (024731):
    uint32 head_cell = srf[ADR_CPUDF];            // 024731-32: DPA := srf[0o2017]
    MSG_NEXTL();                                  // 024733: walk & service the message chain
}
```

### 3.1a The #CPUDF poll — fine-grain (third pass 2026-07-17: CLOSED against the SINTRAN carve)

The SINTRAN carve answered (CARVE-ANSWER-ND5000-ACTIVATION-WORKFLAG.md, [NPL-V]): on
ND-5000 there is NO MAR write; activation = ITO500XQ (ex-queue LINK chain, head at the
per-CPU MAILINK extension block) + ITOFIFOQ (X5FIF ring element) + `XACTRDY/ACT51:
X5ACT := 0` (idle-wakeup path) or `XKICK500` octobus kick (preempt path only). Protocol:
X5ACT init -1 (XMSINIT), **-1 = nothing pending, 0 = work pending**; SINTRAN never writes
it back to -1 — the microcode re-arms it.

The regenerated listing (commit a91dff4) now renders the ADACT `ORCON` displacement
fields, which the previous pass could not see. That closes the identification — and
**corrects the previous pass's spin polarity, which was inverted**:

```c
// IDLE_1 spin body (024712-024720), with ORCON displacements:
base = srf[0o2017];                    // 024712-13: ADR_#CPUDF, DPA := RF2
                                       //   = per-CPU MAILINK extension block base   [V+X]
uint16 flag = mem_hw[base + 0x0A];     // 024716-17: ADACT ORCON=0x0A, TYP,HW RD
                                       //   byte 0x0A = word 5 = X5ACT               [V+X]
if (flag != 0) goto IDLE_1;            // 024720: JMP INVSEQ COND,MZRO -> IDLE_1:
                                       //   loop back while NONzero (INVSEQ inverts);
                                       //   exit spin on 0 = work pending            [V+X]
// IDLE_2 (024721-22): re-arm BEFORE consuming:
mem_hw[base + 0x0A] = 1;               // 024722: ADACT ORCON=0x0A, TYP,HW WR of
                                       //   BM00^SC14(=0) = 1. Confirms the carve's [I]
                                       //   "microcode re-arms X5ACT" — value is 1,
                                       //   not -1 (any nonzero satisfies the spin)  [V]
// ACTIVATE1 (024731-33): DPA := srf[0o2017] again; ADACT AA=2, NO ORCON => +0;
// -> MSG_NEXTL reads a 32-bit WORD at [base + 0] as the FIRST MESSAGE ADDRESS and
// chain-walks link words, sentinel -1.  Block word 0-1 = X5BEX (init -1,-1 double)
// => X5BEX = the ex-queue head ITO500XQ links into.                                [D strong]
```

Three independent ORCON↔symbol matches prove the byte-displacement reading of ORCON
against the carve's per-CPU extension-block table (word offset × 2 = byte displacement):

| Routine | ORCON | = word | Cell | Semantics match |
|---|---|---|---|---|
| IDLE poll rd / IDLE_2 wr (024716/22) | 0x0A | 5 | **X5ACT** | work flag, spin/re-arm |
| `PRNOWR` (025420-21) wr `SC12-1` | 0x0C | 6 | **X5PRO** | "current process on CPU"; explains SINTRAN's cache-bypassed GETC5PROC read and init -1 = IDLE |
| `MSG_CCINCR` (025625-27) rd, wr +1 | 0x12 | 11B | **X5CCL** | cache-clear counter — matches its only caller CLR_DC (015137) and SINTRAN's read/compare of X5CCL |
| `MSG_CCMOVE` (025615-16) rd | 0x12 | 11B | **X5CCL** | copies X5CCL into the answered message (re-based to ADR_MESS, ORCON=0x0A = message halfword 5) at answer time |

INVSEQ = "invert condition" is corroborated twice independently: the IDLE spin (needs
loop-while-nonzero to match the -1/0 protocol) and MSG_NEXT's chain walk 017456-57
(`SC12+1` MZRO INVSEQ -> continue while link != -1).

**Conclusions (supersede pass 2):**
1. `#CPUDF` (srf 0o2017) = **per-CPU MAILINK extension block base** in 5MBBANK (stride
   200B words). The carver's cross-check is CLOSED: poll target = base + word 5 = X5ACT.
2. Spin polarity: **exit on 0 = work pending; spin while nonzero** (-1 idle, 1 after
   microcode re-arm). Pass 2's "0 = no work" was wrong — INVSEQ was not decoded then.
3. The flag is a pure doorbell; the work itself is discovered via the **ex-queue chain
   head at block word 0 (X5BEX [D])**, walked by MSG_NEXTL with -1 sentinel. Pass 2's
   "flag doubles as head cell" was wrong — different displacements (0x0A vs 0).
4. The X5FIF ring is NOT read anywhere in the IDLE/ACTIVATE/MSG_NEXTL path examined —
   consistent with it being the ND-100's in-flight/retire tracking (XN500 drains it).
   Whether the microcode consumes the ring elsewhere (the carve marks X5HEN "[I]
   consumer = microcode") remains unproven in this listing.
5. Doorbells: idle CPU is woken by the X5ACT poll alone (no kick — ACT51 path); the
   octobus kick (OCB_MES_K -> ACTIVATE) is the PREEMPT path when the CPU is busy on
   lower-priority work (ACT52 path). Pass 2 had the kick as "primary"; it is the
   exception, not the rule.

### 3.1b srf comm-block initialization + the answer-side ring (traced 2026-07-17)

The remaining opens traced to their sources in the listing. Key decode: the `ADR_*`
helper table (017334-017402) loads `SARG=002xxx` into RFA1/RFA2 (register-file address
ports); subsequent RF1/RF2 ops hit that srf cell. Full name map now [V]:
2002=FIFOB, 2003=GET_FLAG(run state), 2004=SYSTRA, 2005=SYSHOS, 2006=SYSPAR,
2007=MODINIT, 2011=ASTBAD, 2012=MOD, 2013=PROC0, 2014=MODMASK, 2015=CPUPAR,
2016=CPUAVA, 2017=#CPUDF, 2020=EXQUE, 2021=MSGME, 2022=CPUFLG, 2024=ATRAP, 2025=5SIB.

> **2026-07-20 — `START_MESS` and `SAMSON_CPU` are PATCHED, not fixed** (from the octobus/ACCP
> track's carve; see `NDInsight\SINTRAN\ND500\OPEN-QUESTIONS-REGISTER-2026-07-20.md` §2.6).
> `ND-05.017.01 HARDWARE MAINTENANCE:3961` [READ]: *"load **the first page of CONTROL-STORE:DATA**
> into the transmission buffer. **Some system parameters are patched into this first page.** Then
> this page is read by the ACCP and loaded into the ND-5000 control store memory."* CS words
> `000020`-`000027` are in that page, and `START_MESS` (`026`) + `SAMSON_CPU` (`025`) are precisely
> the two constants that cannot be static — `SAMSON_CPU` is per-CPU and every CPU loads the same
> file. **The `LARG=00000020000` (0x2000) and `0` seen in the A30/B30 disassemblies are shipped
> placeholders, not live values.**
>
> `0x2000` is a **5MPM/MFbus window-relative BYTE address** (offset 0 = ADRZERO), the same space as
> the LPARP pointer observed on the wire as `0x18000`; ADRZERO is operator-set via
> `DEFINE-MEMORY-CONFIGURATION` (`5P-P2-MON60.NPL:587`). No ACCP command carries a mailbox address —
> LPARP (021B) is the CS-transfer buffer, LSYSPAR (16B) is *"where to send octobus error messages"*
> (`ND-05.020.01:4276-4290`). **[NOT FOUND]**: any evidence that CS `OFFSET` (word `000020`),
> `MM,PSTP`/`MM,PUWP`, or an MPM port BASE register is added to `START_MESS`.
>
> **Consequence for any emulator, including `CpuND5000`:** take `START_MESS`/`SAMSON_CPU` from the
> *loaded* control store, not from the on-disk image and not from a literal. `MailboxIdleTests`
> hardcoding `HeaderBase = 0x2000` is fine for a synthetic fixture but must not be read as "0x2000
> is a constant". **[INFER, strong]** that `START_MESS` specifically is among the patched words —
> the ND-100 patcher itself is uncarved (register **Q-OCT-22**; not in `NPL-SOURCE/NPL/*.NPL`, not
> in `MON-DEBUG:PROG`).

**Who writes srf[2017] (#CPUDF): `INIT_ADRP` @025646** [V]:
```c
cpu   = SAMSON_CPU();                 // 025647: patch-panel CPU number constant
off   = cpu << 8;                     // 025650-53: four A+B,*2 doublings = *256 BYTES
                                      //   = the per-CPU block stride 200B words — exact
                                      //   match with the carve's 5EXTD=200B          [V+X]
base  = START_MESS();                 // patch-panel base (20000B area)
srf[2017] = base + off;               // 025655 (RF2 via ADR_#CPUDF)
srf[2020] = base(+2460B?);            // 025655-57 EXQUE := SARG 002460-relative [D fuzzy]
```
So the block base = patch panel + MMU mapping, NOT the SYS_READ parameter words.

**SYS_READ @017111** [V]: waits ACCP, `ADR_SYSPAR` (RFA1:=2006), then 3× {ACCP_READ;
RF1D := word} — the 3 system-parameter words land at **srf 2006 (SYSPAR), 2007
(MODINIT), 2010** via post-increment.

**Producer values RESOLVED 2026-07-17 [NPL-V]**
(CARVE-ANSWER-SYSPAR-LSYSPAR-DISAMBIGUATION.md): these 3 words are the ACCP "LSYSPAR"
(manual ch. 5.3.13) = the CON5IDENT CMSYSPAR multibyte payload, built INLINE
(MP-P2-N500.NPL:3617-3632) — NOT the 16-word N500DF+111B block (that is the ND-500
Monitor's SET-SYSTEM-PARAMETERS tunables, MON60 fn 103/104 only; two unrelated
structures share the name "system parameters"):
- srf[2006] "SYSPAR" = **5OMDNO << 8** — the ND-100's receive OMD, runtime-allocated by
  CONOMD at boot (live machine: 5OMDNO = 10B). DYNAMIC — do not hardcode.
- srf[2007] "MODINIT" = 0 and srf[2010] = 0, always (this SINTRAN revision) — any
  microcode consumer expecting nonzero is dead code against this SINTRAN; only the ACCP
  firmware (outside all carves) could synthesize other values.
The carve's arithmetic cross-check also CONFIRMS GIVEINT's shift: word1=004000B →
((004000 & 037400) >> 3) | 100001 = 100401B = the live-observed interrupt word, so the
answer interrupt is addressed to SINTRAN's own receive-OMD entry. [V+X, was D shift]

**SYS_DATAF @025630** [V]: base := START_MESS(); reads GLOBAL header cells —
halfword @+0x0A (**word 5 = X5MXF**, ring size) and 32-bit word @+0x0C (**word 6 =
X5FIF**, ring base) — into srf[2002] (FIFOB) and the following cell. Then re-derives
#CPUDF and writes a computed halfword at [#CPUDF+0x14] (word 12B — unnamed in the
carve table) [D]. (srf-cell bookkeeping of the second store vs GET_FLAG@2003 is
ambiguous — RFxD increment semantics [?]; the header-offset identifications do not
depend on it.)

**FIFOB IDENTITY RESOLVED: FIFOB = the X5FIF ring.** `GIVEINT` @025422 is the
ANSWER-SIDE PRODUCER into the same ring ITOFIFOQ produces into at activation [V]:
```c
// GIVEINT (025422-025441), called from the answer path (MSG_END/MSG_QUEUE_END):
SC10 = srf[2006];                     // SYSPAR word 1
base = START_MESS();  DPA = base;     // global header
ringbase = srf[2002];                 // FIFOB = X5FIF ring base (loaded by SYS_DATAF)
fill  = mem_hw[base + 0x08];          // word 4 = X5FYL                              [V]
slot  = ringbase + fill*4;            // 025427: index*4 bytes = one 32-bit slot —
                                      //   same stride as ITOFIFOQ (SH 1, 2 HWs)     [V+X]
mem[slot] = current_message_address;  // 025431-32: RF1 via ADR_MESS                 [V]
head  = mem_hw[base + 0x06];          // word 3 = X5HEN — ring-full check            [V]
fill  = fill + 1; if (fill >= srf[2003 /*X5MXF*/]) fill = 0;
mem_hw[base + 0x08] = fill;           // 025436-37: X5FYL advance, wrap to 0         [V]
// GIVEINT1 (025440-41):
ACCP_WRITE(((SC10 & 037400) >> 3) | 0100001);  // interrupt word from SYSPAR word 1
                                               // = 5OMDNO<<8 -> targets SINTRAN's
                                               // receive OMD; live 5OMDNO=10B ->
                                               // 100401B [V+X, shift carve-confirmed]
// All of the above runs under LOCK_QUE (025442): test-and-set on header word 0 =
// X5SEM — the same semaphore SINTRAN's SLOCK/SUNLOCK uses.                          [V+X]
```
**Model consequence (supersedes the 2026-07-16 "no ring insert at answer" correction,
which overcorrected):** the X5FIF ring is a SHARED notification FIFO with ONE producer
index (X5FYL) guarded by X5SEM and TWO producers — ND-100 at activation (ITOFIFOQ) and
the microcode at answer (GIVEINT). XN500's X5HEN→X5FYL walk checking each entry's
N5STA is the consumer; a message appearing twice (activation entry + answer entry) is
harmless because retirement is status-driven, not entry-driven. [D model; both
producer decodes are [V], the consumer behavior is [X].]

### 3.2 Walking the message chain

```c
// MSG_NEXTL (017442) / MSG_NEXTL2 (017453) / MSG_NEXT (017455)
void MSG_NEXTL(void) {
    for (;;) {
        uint32 msg = mem[DPA];                    // 017453-54: read link/head word at DPA
        // MSG_NEXT (017455):
        DPA = msg;
        if (msg + 1 == 0) return;                 // 017456-57: link == -1 -> end of chain [D]
        // MSG_LINK0 (017461):
        bool serviced = MSG_LINK1();              // fetch + dispatch ONE message (see 3.3)
        SCAN_ACCP();                              // 017462: keep servicing ACCP between messages
        // loop: 017463 -> MSG_NEXTL2 again (DPA now at the served message's link position)
    }
}

// MSG_LINK1 (015141): header check for one message at DPA
bool MSG_LINK1(void) {
    uint16 n5sta = (uint16)mem[DPA];              // 015141-42: HW read -> SC3
    if (n5sta != MSGN500 /*1*/)                   // 015143-44: XOR BM00, test zero
        return false;                             // 015145: RETURN — not (or no longer) ours
    return MSG_LINK3();                           // 015147
}
```

### 3.3 Fetch, mark WAITING, dispatch

```c
// MSG_LINK3 (015147) — CPU-targeting filter, then the real fetch
bool MSG_LINK3(void) {
    uint32 my_cpu = SAMSON_CPU;                   // 015150: constant 0 in this image (word 000025) [V]
    uint16 target = msg_halfword_read();          // 015151-52: HW at msg+k (IX*8 stepping) [D offset]
    // 015153-015161: compare against my CPU number + srf[CPUFLG] mask;
    // on mismatch: RETURN (skip message)  [D]
    // 015162-015164: target<<3 + START_MESS(=0o20000) — per-CPU area computation [D]
    ...
    return MSG_LINK7();
}

// MSG_LINK7 (015175) — THE core fetch. This is what the emulator's engine replicates.
bool MSG_LINK7(void) {
    srf[ADR_MESS]  = DPA;                         // 015176,015200: RF1 := message address  [V]
    srf[ADR_MSGME] = 1;                           // 015177,015201: "message in progress"   [V]
    uint16 w     = (uint16)mem_hw[msg + a];       // 015202-03: -> SC4 (status/activation [?])
    uint16 micfu = (uint16)mem_hw[msg + MICFU];   // 015204:    -> SC3 (MICFU@6 per SINTRAN symbols [X])
    mem_hw[msg + N5STA] = WAITING /*2*/;          // 015205: write BM01 [D direction, V value]
    MIC_VECT = micfu;                             // 015206: dispatch vector := MICFU       [V]
    PRNOWR(n5sta + 1);                            // 015207,(025416): bookkeeping [see 3.6]
    UNLOCK_QUE();                                 // 015210
    srf[SRF17] = n5sta + 1;                       // 015211 [?] purpose unknown
    // 015213-015217: range check, strip bit 15 and retry once:
    if (micfu >= 64) {
        micfu &= ~0x8000;                         // 015214: ANDCA BM17 [V]
        MIC_VECT = micfu;                         // 015215
        if (micfu >= 64) return MSG_ILLEG();      // 015216-17
    }
    // MSG_LINK9 (015222-23): vectored dispatch
    goto MSG_TABLE[micfu];                        // JMPREL base MSG_00 (015224)            [V]
}
```

### 3.4 Answering: MSG_END and the interrupt to the ND-100

```c
// Every handler ends with SC10 = 3 (or 4) then jumps here.
// MSG_END (017412)
void MSG_END(uint16 answer /*SC10*/) {
    LOCK_QUE();                                   // 017412
    MSG_CCMOVE();                                 // 017413: move command-count cell [see 3.6]
    uint32 msg = srf[ADR_MESS];                   // 017414-16: DPA := RF1 (saved message addr) [V]
    mem_hw[msg + 0] = answer;                     // 017417-20: write N5STA := 3/4  [D direction, V value]
    GIVEINT(0o100401);                            // 017421: notify ND-100 — "message answered" [V const]
    // MSG_END_1 (017422): decide what to do next
    if ((int32)srf[SRF11] < 0) CNTXTSAVE();       // 017422-23
    PRNOWR(...);                                  // 017424
    srf[ADR_MSGME] = 0;                           // 017425-26: message no longer in progress [V]
    ATRAP_CHK();                                  // 017427
    uint16 proc0 = (uint16)srf[ADR_PROC0_cell];   // 017430-31 [D]
    if (proc0 == 0) {                             // 017432
        PRNOWR(...); UNLOCK_QUE();                // 017433-34
        IDLE();                                   // 017435: nothing runnable -> back to idle
    } else {
        // MSG_END_2 (017436): more work — follow the chain from this message's link
        DPA = srf[ADR_MESS];                      // 017436-42
        MSG_NEXTL();                              // 017441-43: service next chained message
    }
}

// GIVEINT (025422) — queue an ident into the shared FIFO and strobe the ACCP.
// This is the level-12 interrupt path in Octobus clothing.
void GIVEINT(uint16 cmd) {
    uint16 ident_bits = srf[ADR2_SYSPAR];         // 025422-23 [D]
    // 025424-025437: insert ident into the FIFO described by srf[0o2002] (ring buffer
    //                in shared memory: read write-pointer, store entry, advance) [D]
    // GIVEINT1 (025440):
    uint16 word = (ident_bits & 0o037400) | 0o100001;  // [V constants]
    ACCP_WRITE(word);
}
// NOTE: MSG_END passes 0o100401 straight to GIVEINT (017421); the queue-end path
// (017470, MSG_QUEUE_END) uses the same 0o100401; TRAP_SWAP uses (x & 0o037400)|0o100102
// (025005-06). Semantics of the individual command-word bits: [?] — observed values only.

// ACCP_WRITE (016402) — the ONLY hardware "doorbell" in the whole mailbox path.
void ACCP_WRITE(uint16 word) {
    while ((SPEC_AFLAG & BM12) == 0) ;            // 016403-04: spin until output buffer free [V]
    SPEC_AIB = word;                              // 016405: write ACCP input buffer          [V]
}
```

### 3.5 Inbound ACCP commands (how activation arrives)

```c
// SCAN_ACCP (016554) — called from the idle spin and between messages
void SCAN_ACCP(void) {
    uint32 f = SPEC_AFLAG;                        // 016554
    if (f & BM13 && f & BM14) TRAP_PWF();         // 016555-57: power-fail [D bit roles]
    if (f & BM05) TRAP_OCBA();                    // 016560-61: [V] see correction below
    if (f & BM06) /* falls through to 016565 */;   // 016562-63: [V] NOT TRAP_OCBA
    ...                                           // 016564-65: other -> TRAP_OTRP
}

// ---------------------------------------------------------------------------
// CORRECTION 2026-08-02 — the BM05/BM06 destinations above were WRONG, both of
// them. They were tagged [D] (deduced from labels); the real B30 microcode was
// then executed one bit at a time and disagreed on both halves:
//
//   AFLAG bit 5 (BM05) -> TRAP_OCBA @ 0o16550     (NOT TRAP_OCBAK)
//   AFLAG bit 6 (BM06) -> falls through to 0o16565 (NOT TRAP_OCBA)
//
// 0o16565 is the "other" path, which matches ACCP-COMPLETE-REFERENCE.md calling
// bit 6 the OTHER-trap input. So of the two documents that disagreed, that one
// was right and this one was wrong.
//
// The label-derived reading put TRAP_OCBAK on bit 5 purely because OCBAK sits
// adjacent to OCBA in the label file. Adjacency is not dispatch.
//
// Measured by: ScanAccpBitDispatchTests in
// RetroCore\Nuget\HackerCorpLabs.Emulation.CPU.ND5000\tests\
// The test carries an anti-vacuous control - it fails if both bits reach the
// same destination, because that would prove nothing about either.
//
// STILL OPEN: this settles the DESTINATION (where the microcode jumps), not the
// CAUSE (what hardware condition sets each bit). The cause needs the ACCP to
// assert FATAL without ATRAP.
// ---------------------------------------------------------------------------

// OCB_DECODE (016417) — a received OCB halfword (SC5) from the ND-100 side
void OCB_DECODE(uint16 cmd) {
    if (!(cmd & BM07)) TRAP_NOTREC(0o205);        // 016417-20
    if (cmd & BM06)   TRAP_NOTREC(0o206);         // 016421-22 (OCB_MES_E)
    if (cmd & BM05) {                             // OCB_MES_K (016424)
        if (cmd == 0o100501) ACTIVATE();          // 016424-25: the ACTIVATE command [V]
        switch (cmd & 0o77) {                     // 016426-27: JMPREL OCB_DEC_K [V]
            case 1: case 2: ACTIVATE();  break;   // 016431-32
            case 3: OCB_KICK03();        break;   // clear/answer one message + EXECUTE
            case 4: case 5: OCB_KICK05();break;   // stop -> cleanup -> TRAP_NOTREC
            case 6: OCB_KICK06();        break;   // stop -> cleanup -> IDLE
            default: OCB_KICK64();       break;   // unlock + TRAP_NOTREC(0o204)
        }
    }
    ...
}
```
The classic-500 equivalent of "OCB activate" is the 3022 CONTROL activate strobed through
the 5015 [X]. For the emulator: `LCON5 := 5` ⇒ call the engine's `ACTIVATE()`.

### 3.6 Shared-memory bookkeeping helpers (all via the #CPUDF pointer)

```c
// PRNOWR (025416): mem_hw[ srf[ADR_CPUDF] + k ] := SC12 - 1   [V write value; k and meaning ?]
// MSG_CCMOVE (025611): reads a halfword via #CPUDF cell, copies it into the message
//                      area via srf[ADR_MESS]                                  [D]
// MSG_CCINCR (025622): increments a halfword cell via #CPUDF                    [D]
// LOCK_QUE (025442) / UNLOCK_QUE (025505): spin-lock in shared memory:
//     uses SPEC,MOD bit manipulation + a lock halfword reached via SC13; retries with
//     a backoff loop (LOCK_COM3 counts down LC), re-scanning ACCP while waiting  [D]
//     Multi-CPU only; a single-CPU emulator can treat these as no-ops.
```

### 3.7 The handlers

Common prologue for the memory-mover handlers: read parameter words from the message
(`SC3` = address A, `SC7` = address B, `SC4` halfword = count/status) [D naming — catalog
must confirm which is source vs destination], then a word-copy loop with `LC` as counter and
byte/halfword tail handling via `Q`. All finish `SC10 := 3; goto MSG_END;` (or `MSG_KILL_P`).

```c
// MICFU 01 — MSG_VERSRD (015330): 3RMICV "read microprogram version"
void MSG_VERSRD(void) {
    uint16 cpupar  = (uint16)srf[ADR_CPUPAR_cell];   // 015330-31: RF1 via RFA1=0o2015 [V]
    uint16 version = 0o27232;                        // 015331->000001 VERSION: LARG [V]
                                                     // (= 0x2E9A, matches live trace [X])
    mem_hw[msg + a] = version;                       // 015332-33 [D offset a]
    mem_hw[msg + b] = cpupar;                        // 015334    [D offset b]
    answer(3);                                       // 015335: SC10 := 3 -> MSG_END
}

// MICFU 10/11 — MSG_DMEMRD/MSG_DMEMWR (015336/015355): data-memory block read/write
//   NEWCNTXT() first (map the target process's context/domain) [V call, D purpose]
//   3 params: two words + one halfword count; MSG_DOMRD() resolves the domain [V call]
//   word-copy loop (MSG_DMEMRDW/MSG_DMEMWRW), byte tail (MSG_DMEMWRBY)
//   ends: SC10 := 3 -> MSG_KILL_P (read) / MSG_END or MSG_KILL_P (write)

// MICFU 13/14 — MSG_RESIRD/MSG_RESIWR (015516/015534): same copy engine, no NEWCNTXT,
//   no domain resolve — "resident" (physical-window) access [D]  -> MSG_END

// MICFU 30/31 — MSG_PHYSRD/MSG_PHYSWR (015561/015600): same engine plus an extra
//   halfword param written to D,MM,PHS (physical segment select) [V destination] -> MSG_END

// MICFU 34/35 — MSG_IMEMRD/MSG_IMEMWR (015403/015442): instruction-memory access via
//   D,IMM,LA / A,IMM,MEM (IMM = instruction-memory management) [V], alignment-checked
//   (low 2 bits != 0 -> MSG_ILLEG, 015406-07) [V]; IMEMWR clears the instruction cache
//   first (CLR_IC, 015443) [V] -> MSG_KILL_P

// MICFU 12 — MSG_CACHE (015640): one halfword param -> MSG_CCONMC (conditional cache
//   clears: bits select CLR_IC / CLR_DC / CLR_DUDC, 016121-016131) [V] -> MSG_END
// MICFU 45 — MSG_CLEAR (015643): richer variant, bit-by-bit (MSG_CLEAR_1..CLR_5:
//   BM04->CLR_DUDC, BM03->CLR_DC, BM02->CLR_IC, BM01->CLR_DTSB, BM00->CLR_ITSB) [V]
// MICFU 46 — MSG_DUDC (015655): dump-dirty+clear variant of the same [D] -> MSG_END

// MICFU 22 — MSG_STARTP0 (015660): start process 0 (the swapper).
//   CNTXTSAVE if a process was running; srf[PROC0] bookkeeping via ADR_PROC0/ADR_SYSPAR;
//   writes SARG 0o100501 halfword -> OCTO_SOFT (soft OCB self-command) [V constants,
//   D overall flow]
// MICFU 23/25 — MSG_START (015671): 3START / 3TRACO start-or-continue:
//   if (!CPU_AVAIL()) return CPU_UNAVA();         // 015671-73
//   NEWCNTXT(); EXECUTE();                        // 015674-75: LOAD CONTEXT AND RUN MACRO CODE
// MICFU 24 — MSG_CONMC (015676): 3MONCO continue-after-MON-call:
//   NEWCNTXT(); msg = srf[ADR_MESS];              // 015676-700
//   MSG_CONMC_0: X1 := mem[msg + k];              // 015720-21: MON result -> process X1 [V dest,
//                                                 //            D that it is the MON result]
//   (conditional extra copy loop MSG_CONMC_4/5 driven by a bit vector in Q [D])
//   MSG_CONMC_9: MIC status juggling; MSG_CON10 writes halfword 0o23 back into the
//   message area (bookkeeping [?]) then EXECUTE   // 015710-17
// MICFU 26 — MSG_CONWR (015703): 3WMONCO variant: same fetch, then a block copy of
//   answer data into process memory (MSG_CONWR_1/_2/_W/_B, 015752-016004) before EXECUTE

// MICFU 42 — MSG_PRT (016005): **PROGRAMMED TRAP** [V vendor], not a "process probe".
//   CORRECTED 2026-07-20: the vendor function-value table (ND-05.012.01 ND-500 Micro
//   Program Guide §13, lines 1090-1400) lists 42 = "programmed trap". The earlier
//   reading here — "process/context probe [D]" — was a guess from the mnemonic; PRT =
//   Programmed TRap. Body as decoded: GET_CNTXT + reads two context words, ORs into
//   SC11 -> answer via MSG_KILL_P.
// MICFU 44 — MSG_HISTOG (015626): reads P register + SRF11/SRF14 into the message
//   (histogram/sampling support) [D] -> MSG_END
// MICFU 47 — MSG_IDLE (015324): CNTXTSAVE if needed; SRF11 := SC14-1 ( -1 = nothing
//   runnable [D]); -> MSG_QUE_END1 -> UNLOCK -> IDLE  [V flow]
// MICFU 50/51/52 — MSG_UNIX5RE / MSG_UNIX5CM / MSG_UNIX5REL (016015/016062/016067):
//   UNIX-500 support: full context load/store sequences (CNTXTSAV00/CNTXTLOAD0, NEW_CED/
//   NEW_CAD = new current/alternative domain, WRITE_P) [V calls, D semantics]
// MICFU 70..75 — trace-memory family (016160-016201): MSG_INITTR reads 4 halfword params
//   then MSG_INITRAC; CLRTRM/ARMTR/DISARM/DUMPTR/CLRADC wrap the trace RAM helpers;
//   all funnel through MSG_CACE -> MSG_END [V flow]
// MICFU 76 — MSG_CACI (016202): set cache-inhibit mode: validates param ((p & 0o174)!=0
//   -> MSG_ILLEG), maps bits into SPEC,MOD via jump tables MSG_CACI0/MSG_CACD0, verifies
//   against MODMASK; reject -> SC10 := 4 -> MSG_END (016240) [V]
// MICFU 77 — MSG_LOOKSRF (016245): debug read of SRF: params HW start-index (SC4),
//   HW count (SC3->LC), word dest addr (DPA); loop RFA1 := idx++, write RF1 out [V]
//   -> MSG_END

// MSG_KILL_P (013723) — "answer and drop current process":
void MSG_KILL_P(void) {
    srf[SRF11] |= BM37;                           // 013723-24: sign bit = no process [V]
    SET_IDLE();                                   // 013725
    MM_PHS = DMM_PS;                              // 013726 [?]
    answer(3);                                    // 013727: SC10 := 3 -> MSG_END
}
```

---

## 3.8 The MON-call EXIT path (decoded 2026-07-16 — closes open question #1)

How a macro-program's monitor call becomes the outbound stop message. SINTRAN-side
authority for field offsets: `ND500-MAILBOX-MESSAGE-CATALOG.md` (STOPR@11, NUMPA@12,
MCNO@13, all consecutive halfword slots — which is exactly what the microcode writes).

**Recognition — it is a TRAP, not an opcode.** A `CALLG` whose target lies in the monitor
entry table (manual encoding `EQU 37B9 + n` — "segment 31"; the SINTRAN manuals express
every MON as `CALLG <entry>, argc, args...`) raises an instruction-fetch/protect trap.
The trap decoder routes trap code **6 → CALL_MON** (monitor call) and **7 → CALL_DOM**
(cross-domain call): `TRAP_MONC` (`012740`-`012742`) [V]. Reached from `TRAP_IFC`
(`012743`), i.e. the IMM trap path [V].

```c
// CALL_MON (003744) — trap code 6: the CALLG targeted the monitor segment
void CALL_MON(void) {
    if (!saved_condition) PROTVIOL(0o44);         // 003744-45: legality gate [D meaning]
    // CALL_MON0 (003746):
    uint32 mic_sts = MIC_STS;                     // 003746
    read srf[ADR_PROC0];                          // 003746-47 [?] consulted, use unclear
    if (mic_sts & BM04) TRAP_ISE();               // 003750: already-in-monitor check [D]
    TRAP_ARM();                                   // 003753
    uint16 argc = LC;                             // 003754: CALLG arg count sits in LC [V src]
    LOCK_QUE();                                   // 003754
    uint16 mcno = (uint16)IAC_NPC;                // 003755-56: MON number = low halfword of
                                                  //   the CALLG target address (NPC). [V read]
                                                  //   Matches EQU 37B9+n: n in the low bits [X]
    if (mcno == 0o600) return CALL600();          // 003757-61: NDIX/600 special (lock path)
    // CALL_MONX (003762):
    LC  = argc;
    DPA = srf[ADR_MESS];                          // 003762-63: the process's OWN message   [V]
    if (argc > 16) ...;                           // 003764: BM04(=16)-argc check [D]
    if ((int32)IAC_L >= 0) { UNLOCK_QUE(); INS_SEQ_ERR(); }  // 003765-67: L must be a
                                                  //   valid (negative/flagged) return addr [D]
    // CALL_MON1/CALL_MON8 (003770-004000): per-parameter loop
    while (LC-- > 0) {
        G_OPS();                                  // 003773: fetch next operand specifier [V]
        uint32 addr = SPEC_DACR;                  // 003774: operand's resolved address   [V]
        uint32 val  = mem[addr];                  // 003775: operand's value              [V]
        // [V, lossless listing 2026-07-17] Two ARRAYS via the EA3 running pointer
        // (EA3 init @003770: EA1+0x3C, bumped +4 bytes/iter @003776 BEFORE the writes):
        mem[msg + 0o40 + 2*k] = addr;             // 003777: WR,POF at EA3 = base+0x40+4k
                                                  //   = HW 0o40+2k = 5PPA1/5PPA2/OSTRA [V]
        mem[msg + 0o100 + 2*k] = val;             // 004000: WR,POF at EA3+0x40
                                                  //   = HW 0o100+2k = 5APn(high)/5DPn(low) [V]
    }   // 16 slots each: addresses HW 0o40..0o77, values HW 0o100..0o137 — exactly why
        // CALL_MON checks argc<=16 (BM04) at 003764. RESOLVES carver R1's ambiguity:
        // 0o100 region holds the 32-bit VALUES, 0o40 region the operand ADDRESSES [V+X].
    // Inline buffer for 504/511/512: flagged by MIFLAG bit 0, addressed via ABUFA=0o140
    // (a pointer, NOT inline in the header), max 0o4000 bytes [X carver R1].
    // CALL_MON9 (004001-004012): the header write — the actual stop record
    if (mcno in {0o504, 0o511, 0o512})            // 004001,013667 CALL_5XX/CALL_5_MATCH:
        copy_user_buffer_into_message();          //   inline data copy for output-type calls
                                                  //   (SINTRAN GOSW: 504=NOUTS 511=DVIO
                                                  //    512=A5XMSG — ND-100 needs the bytes) [X]
    uint32 retaddr = IAC_L;                       // 004002-03: L = return address
    uint32 p       = IAC_P;                       // 004004-05
    mem[msg + 7]      = p;                        // 004006: saved P (word) at HW 7 = N500A [V!]
                                                  // 004005 ADACT computes EA1+0x0E (byte 14
                                                  // = HW 7). This is exactly the N500A=7
                                                  // slot 3RPREG/HISTSAMPLE read [X carver R2]
                                                  // — the "saved P" and "ND-500 P" cells are
                                                  // the SAME message word.
    mem_hw[msg + 0o11] = 1 /*MOCALL*/;            // 004007: STOPR@0o11 (EA1+0x12)   [V offset]
    mem_hw[msg + 0o12] = argc;                    // 004010: NUMPA@0o12 (EA1+0x14)   [V offset]
    mem_hw[msg + 0o13] = mcno;                    // 004011: MCNO@0o13  (EA1+0x16)   [V offset]
    IAC_P = retaddr;                              // 004012: P := L, so 3MONCO resumes after
                                                  //         the CALLG                        [V]
    CALL_END();
}

// CALL_END (013613) — microcode-shortcut screening on the MON number, then answer
void CALL_END(uint16 mcno) {
    switch (mcno) {                               // all compares [V] 013614-013631
        case 0o515:                >> CALL_515;   // sub-dispatched via a message value
        case 0o117: case 0o120:
        case 0o144: case 0o201:    >> CALL_WF;    // wait-variants [D]
        case 0o270: case 0o271:
        case 0o333: case 0o335:
        case 0o500:                >> CALL_DUDC;  // dump-dirty data cache FIRST (DMA/output
                                                  // coherency — 333B is the UDMA call [X]),
                                                  // then CALL_END9
        case 0o501:                >> CALL_STAP;  // start-process local assist
        case 0o502:                >> CALL_STOP;  // stop-process local assist
        case 0o600:                >> CALL_SWIP;  // **OMC other-machine call** — CORRECTED
                                                  // 2026-07-20. Was "swapper-related [D]",
                                                  // a guess from the mnemonic. The NDIX
                                                  // kernel's fecall() is
                                                  // `callg $0xf8000180,$4,…` = segment 31,
                                                  // offset 0x180 = **600 octal**, through a
                                                  // PC_IND|PC_OMC capability. So SWIP is
                                                  // almost certainly SWItch-Processor, not
                                                  // SWaPper. (CALL_MON @003757-61 already
                                                  // annotated 600 as the NDIX special —
                                                  // this line contradicted it.) [V from the
                                                  // NDIX source; classic ND-500 generation]
        default: if (ndix_case()) >> CALL_NDIX;   // 013631: async fast path — answers
                                                  // (writes 3 + GIVEINT) and CONTINUES
                                                  // EXECUTING (025401-025415) [V flow]
                 else              >> CALL_END9;
    }
}

// CALL_END9 (013635) — the normal exit: the stop message IS an answer
void CALL_END9(void) {
    MIC_STS &= ~BM02;                             // 013635-36
    SET_IDLE();                                   // 013637
    SC10 = 3 /*ANSWER*/;                          // 013640: BM01+1                        [V]
    MSG_END0();                                   // -> write N5STA:=3, GIVEINT(0o100401),
                                                  //    then idle or next chained message
}
```

**The model this proves:** the microcode does NOT build a new message for a MON-call stop.
It answers the process's **own activation message** (address held in `srf[ADR_MESS]` since
MSG_LINK7): parameters as (address,value) word pairs in the data part, saved P, then
STOPR:=MOCALL(1), NUMPA:=argc, MCNO:=call#, N5STA:=ANSWER(3), doorbell. MICFU is left as
whatever the process was activated with (3START/3MONCO/...) — exactly why SINTRAN's
DECOMESS accepts any of {3MONCO,3TRACO,3START,3WMONCO} and dispatches on STOPR [X].

**Restart consumption (other direction, verifies the ND-100's write-back):** MSG_CONMC
(3MONCO) reads the message and delivers FUNCV→**X1** (`015721`: `D,X1`) and KFLIP→**K flag**
(`015727`/`015731`: `K,ZRO` / `K,ONE`) [V] — the microcode-side proof of the manual's CALLG
error convention ("on error K is set, error code in W1").

## 3.9 Trap handling and trap stops (decoded 2026-07-16)

The third and last way the ND-500 talks back: a hardware/program trap either runs a LOCAL
macro handler, or STOPS the process with `STOPR=TRAPCODE(2)` + `TRAPN`, or (5800) emits an
out-of-band OCB message. All flows below are [V] at the control-flow level; per-word message
offsets follow the same caveat as before (ADACT stepping not rendered — SINTRAN symbols are
the offset authority: STOPR@11, TRAPN@16).

### 3.9.1 Collection — TRAP_SAM (`012545`)

Entry from the fixed vector `TRAP` (`000100`). Gathers the trap state into a 5-word record:

```c
void TRAP_SAM(void) {
    srf[ATRAP_cell]--; srf[MOD_cell]...;          // 012545-47 housekeeping
    uint32 alu_pend = ALU_STS & ~0o76000000_mask; // 012550-51: pending ALU trap bits -> SC5
    alu_pend |= MIC_STS;                          // 012552
    uint32 idu = IDU_STS;                         // 012553
    uint8  trapno = idu & 0o377;                  // 012554: TRAP NUMBER byte -> SC6 [V]
    IDU_STS = idu & ~0o377;                       // 012555-57: clear consumed number
    ...                                           // 012560-012566: AFLAG bits 7/10 route to
                                                  //   TRAP_DFC / TRAP_IFC (MMS fault classes)
}
// TRAP_CHECK (012600): composite enable mask = f(IDU,TE | MIC,TE | ALU,TE), ANDed with the
// pending bits; TRPCLR strobed; power-fail/ACCP special bits peeled off first (012620-27).
// TRAP_TO_SRF (012675): stores the 5-word trap record {SC14,SC13,SC5|SC7,SC6,SC4} into the
// SRF trap area (RFA1 := BM05 = 0o40) via descending RF1D writes [V].
```

MMS faults: `TRAP_IFC` (instruction fetch) extracts a fault code; **codes 6/7 are not traps
at all** — they are the monitor/domain CALLG (section 3.8). `TRAP_DFC`/`TRAP_DHWF`/
`TRAP_IHWF` collect DMM/IMM status, LA, PHYS, CAP, WR into the record for fault reporting.

### 3.9.2 Triage — TRAP_FIND (`013152`)

```c
void TRAP_FIND(void) {
    // per-process context block: base OFFSET(0o4000) + f(SRF11) via GET_CNTXT (013370)
    uint32 ctx = 0o4000 + (srf[SRF11] << k);      // [D shift factor]
    uint32 local_enable = mem[ctx + a];           // 013154-57: process's own-handler mask
    if (local_enable == 0) TRAP_TRAP();           // 013160: no context -> flag-based route
    TRAP_SAVE();                                  // 013161: park regs + trap record
    // merge system enables (IDU,TE / ALU,TE / MIC,TE) -> two masks:
    uint32 sys_mask  = ...;                       // 013162-171 -> SC3 (system-owned traps)
    uint32 own_mask  = ...;                       // 013172-73  -> SC4
    if (pending & own_mask) {                     // TRAP_IN_S2 (013175):
        trapno = highest_set_bit(...);            // 013177 BMLC scan loop
        if (SYSTRA_halfword & bit(trapno))        // 013203-05: srf[0o2004] SYSTRA mask
            { CTRACE; TRAP_OCBM(0o201); }         // 013207-212: SYSTEM TRAP -> OCB msg 201B
        TRAP_ENT(trapno);                         // 013214: else LOCAL macro handler
        TRAP_ACCP();                              // 013215: then service ACCP events
    } else if (pending & sys_mask) {              // TRAP_IN_S1 (013216):
        trapno = highest_set_bit(...);
        TRAP_ENT(trapno);  TRAP_ACCP();           // 013223-24
    } else TRAP_FATAL();                          // 013217: nothing enabled anywhere
}
// TRAP_ACCP (013313): MIC,VECT := LC; JMPREL TRAP_VECT — vector table (013316-013346):
//   entries -> TRAP_THM (trap-handler-message), TRAP_OTRP, TRAP_ATRP, TRAP_OMESS (inbound
//   OCB), TRACE_TRIGD/TRACE_NOTRIG/TRAP_TRAC (trace RAM events).
```

### 3.9.3 LOCAL dispatch — TRAP_ENT (`013730`): the DIT model

```c
void TRAP_ENT(uint8 trapno) {
    clear_trap_param(); UNLOCK_QUE();             // 013730-31
    Q = srf[SRF14];                               // 013732: current DIT base [D]
    NEW_TO_DIT();                                 // map the Domain Information Table
    SET_IN_TRAP();                                // 013733: srf[0o2003] flag++
    // specials: trap numbers 0o44, 0o46, 0o51 bypass the enable byte (013734-741) [V]
    uint8 enable = dit_byte(trapno);              // TRAP_COEN/TRAP_NEE: per-trap byte table
                                                  // in the DIT, walked/compared 013742-757
    ...                                           // TRAP_DEC/TRAP_CEN1/2: check the domain's
                                                  // enable WORD bit for this trap (BMLC)
    // enabled -> TRAP_EN1 (014012): handler address = mem[dit + 2*trapno + base]
    //            TRAP_START (014031): P := handler address, DIS_IC/ENA_IC, resume MACRO
    //            execution inside the trap handler (ENTT-style entry saves registers).
    // not enabled -> falls back to the stop path (TRAP_GENx) / TRAP_ERR.
}
```

### 3.9.4 STOP to the ND-100 — TRAP_GEN1..4 + TRAP_END: STOPR=TRAPCODE(2)

The per-trap-class sequences (`TRAP_PV`, `TRAP_THM`, `TRAP_TRAC`, `TRAP_PGF`, ...) are
compositions of four generators, all writing into the process's OWN message (`srf[ADR_MESS]`),
exactly like the MON-call stop:

```c
// TRAP_GEN1 (013501): the header
TRAP_OCBCHK();                                    // 013501: optionally ALSO send OCB 201B
                                                  //   (system-trap notify, flag-gated)
LOCK_QUE(); DPA = srf[ADR_MESS];                  // 013503-05
mem_hw[msg + STOPR] = 2 /*TRAPCODE*/;             // 013513: BM01 halfword [V value, X offset]
...                                               // 013514-17: two message words read/written

// TRAP_GEN2 (013520): status collection — ALU status (masked), MIC status, IDU status,
//   SRF10 -> written to the message/record; CLEARTRS clears trap state.

// TRAP_GEN3/3B/3C (013534/013547/013553): copy the trap record + parameters (from the SRF
//   trap area 0o40 and ASTBAD cell) into the message data part as words + halfwords.
//   [V flow; exact offsets D — this is where TRAPN@16 and the fault parameters land]

// TRAP_GEN4 (013560): the page-fault shape:
LOCK_QUE(); DPA = srf[ADR_MESS];
uint16 trapn = 0o46;                              // 013563: page-fault trap number [V]
mem_hw[msg + STOPR] = 2;                          // 013571 (TRAP_GEN4B): BM01 [V]
mem[msg + b] = P; mem[msg + c] = P;               // 013572-73: saved P
mem_hw[msg + TRAPN] = trapn;                      // 013574 (TRAP_GEN4C): [V value, X offset 16]
...                                               // 013575-604: 4 words from the SRF trap
                                                  //   record (RFA1 := 0o40) into the message

// TRAP_END (013606): the answer
run = srf[GET_FLAG_cell];                         // 013606-07
SC10 = run ? 3 : 4;                               // 013610: C,ALU — ANSWER or 5ERANSWER
                                                  //   depending on the run-state flag [V]
                                                  // [X carver R9] SINTRAN's DECOERRMESS
                                                  //   special-cases trap-shaped N5STA=4:
                                                  //   TRAPN=0o46 + legal MICFU routes to
                                                  //   ITRAPDECODER (swapper), so a page-fault
                                                  //   5ERANSWER is NOT discarded. The
                                                  //   emulator MUST reproduce this
                                                  //   conditional. Discriminator on the
                                                  //   SINTRAN side = TRAPN+MICFU, not STOPR.
SET_IDLE(); MM_PHS = DMM_PS;                      // 013610-11
MSG_END0();                                       // 013612: N5STA write + doorbell + next msg
```

**Page fault** (`TRAP_PGF0/1` @013430): trap 0o46; if the process has a local handler flag →
TRAP_ENT (macro handler); else → TRAP_GEN4 stop **plus TRAP_SWAP** (013453) — which builds a
message to the swapper in the START_MESS area (0o20000) and re-enters the message chain.
This is the microcode side of demand paging: the fault stops to the ND-100 AND/OR wakes the
swapper [V flow].

### 3.9.5 Out-of-band OCB messages — TRAP_OCBM (`016727`)

For events with no runnable process to answer through (system traps, CPU-unavailable,
protocol errors), the microcode builds an octobus message ITSELF and pushes it frame-by-frame
through `ACCP_XWRITE` — corroborating the manual: "This message is built by the microprogram
itself and sent directly to the octobus through the ACCP" (HW-fault section).

```c
void TRAP_OCBM(uint16 code /*SC5*/) {             // codes observed: 0o201 system trap,
                                                  // 0o203 CPU unavailable (CPU_MESSAGE),
                                                  // 0o204/205/206/210 not-recognized/errors
    uint16 ident = srf[SYSPAR_cell];              // 016727-30 (RF1D halfword)
    srf[SRF17] = LC;                              // 016731: park trap number
    ACCP_XWRITE(ident | 0o100060);                // 016734: message-open frame word [V const]
    ACCP_XWRITE(((ident & 0o37400) >> 8?) | BM02);// 016735-36 [V constants, D shift]
    vector = code & 0o17;                         // 016737-742: low 4 bits -> TRAPOCB00 table
    switch (vector) {                             // per-subtype payload frames:
        case 0: TRAP_OCB00; // + 0o46 word         [V const]
        case 1: TRAP_OCB01; // THM: SRF17 vs 0o45, 0o16/0o20 codes + context words via
                            // SEND_MSG2/SEND_MSG4 helpers
        case 2,3: TRAP_OCB03; // 0o6 + code + trap-record words (RF1D)
        case 4..7: TRAP_OCB07; ...
        case 8..10: TRAP_OCB12; ...
        default: TRAP_OCB20; // BM01|x, 0o277|x, BM00|x frames
    }                                             // then TRAP_OCBM98/99 close out
}
```
Per-subtype payload word maps are only partially decoded [D] — listed as open.

### 3.9.6 CPU-availability refusal — CPU_UNAVA (`017270`)

`MSG_START` gates on `CPU_AVAIL?` (`017312`: reads `srf[CPUAVA]`, cell 0o2016). If the CPU is
unavailable: `CPUSAVE`, then `CPU_MESSAGE` (`017301`) collects CPUMODEL + VERSION into SRF
cells and emits **OCB message 0o203** via TRAP_OCBM, unlocks, idles [V flow]. The activation
is answered out-of-band rather than through the mailbox.

## 3.10 Lossless-disassembly verification (2026-07-17) — the address-arithmetic decode model

The regenerated listing (commit a91dff4, reassembly-validated to the exact 128-bit word)
prints the fields the old JS export suppressed. That made the message offsets directly
readable. The decode model, calibrated on the KNOWN offsets (STOPR/NUMPA/MCNO) and then
applied everywhere:

1. **Pipeline:** a memory operation (`RD,POF`/`WR,POF`/`READ`/`WRITE`) on microword N uses
   the address computed by the `ADACT` on microword **N−1**. An `ADACT` on the same word as
   a memory op computes the address for the NEXT memory op. [V — calibrated on
   004005-004011: EA1+0x0E→P, +0x12→STOPR, +0x14→NUMPA, +0x16→MCNO, matching the SINTRAN
   symbols exactly]
2. **Effective address** (`AD_ARTI=1` = MICRO-controlled): `EA = AA-operand + AB-operand`.
   `AA=` selects the base: 2=DISP (the displacement register, loaded via `D,DAC,DPA`),
   4-7=EA0-EA3. `AB=1` = MARG (mini argument, bits 7-0, **sign-extended**).
3. **The printed `ORCON=`/`IX*n` on AB=MARG words are the MARG bits themselves** (the fields
   overlap): MARG = (scal bits 8-6 as printed IX-flag, contributing bit 6-7) | ORCON value.
   E.g. `IX*2 ORCON=0x14` → MARG = 0x40|0x14 = 0x54; bare `ORCON=0x3C` → MARG = 0x3C;
   `IX*8 ORCON=0x34` → MARG = 0xF4 = **−12** sign-extended.
4. **Units are BYTES**; SINTRAN symbol offsets are 16-bit halfwords: HW offset = byte/2.
5. `EAnSAVE` latches the computed address into EAn (and EA0) — used as running pointers
   (e.g. the CALL_MON parameter loop bumps EA3 by 4 bytes per iteration).

**Verified message-offset table** (all byte-read from the lossless listing; μ-addresses cited):

| HW offset (octal) | Field | Microcode evidence |
|---|---|---|
| 0 | LINK (word) | MSG_NEXTL2 017453: RD at EA1+0 |
| −6 | 5CPUN | MSG chain check 015151: RD,HW at EA1−12 (MARG=0xF4) |
| 2 | N5STA | 015204→015205: WR,HW 2 (WAITING); MSG_END0 017417→017420: WR,HW SC10 (3/4) |
| 4 | X5CPU | 015202→015203: RD,HW → SC4 |
| 5 | X5ACT | 015167→015170: RD,HW |
| 6 | MICFU | 015203→015204: RD,HW → SC3; MSG_CON10 015715→015716: WR,HW 0o23 |
| 7 (word 7-8) | N500A: saved P (MON stop 004006) / 3RMICV version HW@7 + CPUPAR HW@0o10 (015332-015334) / MSG_CONMC cache param HW@7 (015722-23) | |
| 0o11 | STOPR / KFLIP | write 1: 004007 (MON); write 2: 013513, 013571 (trap); restart read: 015724→015725 |
| 0o12 | NUMPA (MON: argc / restart: write-back mask) — trap stop: first status word (TRAP_GEN1 013514→515 from ctx+0x54; TRAP_GEN4B 013572: saved P) | |
| 0o13 | MCNO / FUNCV | write: 004011; restart read → X1: 015720→015721 (word at HW 0o13-0o14) |
| 0o14 | trap stop: second status word (TRAP_GEN1 013516→517 from ctx+0x60; TRAP_GEN4B 013573: saved P again) | |
| 0o16 | TRAPN | TRAP_GEN1C 013507→013510 (:=LC); TRAP_GEN4C 013570/013573→013574 (:=SC14) |
| 0o17-0o30 | trap record + fault parameters | TRAP_GEN4C 013601-604: srf[41]→0o17(w), srf[43]→0o21(hw), srf[40]→0o22(w); TRAP_GEN3 013534-546: ctx+0x68→0o17(w), ctx+0x64→0o21(w), ctx+0x6C→0o23(w), ctx+0x70→0o25(hw), ctx+0x74→0o26(hw); TRAP_GEN3B/3C: →0o27(hw), 0o30(hw) |
| 0o40+2k, k<16 | MON param ADDRESSES (5PPA1=40, 5PPA2=42, OSTRA=44, ...) | CALL_MON 003777: WR at EA3 (base+0x40+4k); restart read: 015740→015741 → DPA |
| 0o100+2k, k<16 | MON param VALUES, 32-bit (5APn=high HW, 5DPn=low HW) | CALL_MON 004000: WR at EA3+0x40; restart read: 015744→015745 → value, then 015747 WRITE to the operand address |

**Corrections/refinements vs the 2026-07-16 decode** (no flow was wrong; these are offset
promotions and two structural refinements):

- The MON parameter writes are **two strided arrays** (addresses @0o40, values @0o100), not
  consecutive (address,value) pairs — the two `WR,POF` per iteration go through EA3 and
  EA3+0x40. Confirms and sharpens carver R1; the address-vs-value-high ambiguity is CLOSED:
  0o100 region = values.
- The MON-stop **saved P is HW 7-8 = N500A** — the same word 3RPREG/HISTSAMPLE read. Carver
  R2's "never read at stop time" stands, but the slot is the known N500A, not a private cell.
- Trap stops do NOT write P at HW 7; they put status/P words at HW 0o12 and 0o14 (the
  NUMPA/FUNCV area, unused for STOPR=2) and the record at 0o17-0o30.
- The restart write-back loop (MSG_CONMC_33/4/5 015734-015751) is now fully decoded: Q :=
  NUMPA mask; per bit k: DPA := mem[msg+0o40+2k], val := mem[msg+0o100+2k], plain-domain
  `WRITE` val → [DPA]. Microcode-side proof of carver R6's "bit k ⇒ param k+1".
- 3RMICV answer placement pinned: version HW → msg HW 7, CPUPAR HW → msg HW 0o10.

## 4. What this means for the RetroCore emulator (NDBusND500IF / CpuND500)

1. **The engine's activate/answer loop is confirmed to be the right shape** [X+V]:
   activate → fetch HW0/HW1 (N5STA must be 1) → write N5STA=2 → dispatch on MICFU →
   handler → write N5STA=3/4 → interrupt ND-100. The microcode adds two things the engine
   should replicate:
   - **Message chaining**: after answering, follow the link word; -1 terminates.
   - **The WAITING(2) intermediate write is real and unconditional** — SINTRAN can observe it.
2. **3RMICV answer = two halfwords**: version (0o27232 in this B30 image — note word 1 of
   the A-series image holds 0o27232 as well per the trace doc; serve it from the cached
   control store, word 1 last part) **plus the CPU-parameter halfword** (SRF cell 0o2015,
   set at init). The emulator currently answering only a version constant is missing the
   second halfword [V microcode side; check what SINTRAN's DECOMESS actually consumes].
3. **3START/3TRACO share one handler** (both → MSG_START) [V]. 3MONCO delivers the MON
   result into the process's **X1 register** before resuming [V dest register]. 3WMONCO
   additionally block-copies answer data into process memory before resuming [V flow].
4. **MICFU 05 (3SWMESS) is MSG_ILLEG in this image** [V] — resolve against the SINTRAN carve
   before implementing.
5. Handlers the engine may need beyond the documented set: DMEMRD/WR, IMEMRD/WR, RESIRD/WR,
   PHYSRD/WR, CACHE/CLEAR/DUDC, LOOKSRF, trace family — SINTRAN's ND-500-MON test programs
   (LOOK-AT etc.) likely use the memory ones.

## 5. Open questions / next steps

- [x] **MON-call exit path** — DECODED, see section 3.8 (TRAP_MONC trap code 6 → CALL_MON →
      parameter loop → STOPR/NUMPA/MCNO writes → CALL_END → answer as N5STA=3).
- [x] **Trap stop path** — DECODED at flow level, see section 3.9 (TRAP_SAM collect →
      TRAP_FIND triage → local DIT handler / TRAP_GENx stop with STOPR=2 + TRAPN /
      TRAP_OCBM out-of-band OCB message; page fault 0o46 also wakes the swapper).
- [x] **Carver reconciliation 2026-07-16** — all nine byte-evidence requests
      (`CARVER-REQUESTS-FROM-MICROCODE-RE.md` R1–R9) answered from the L07 bytes; results in
      `ND500-MAILBOX-MESSAGE-CATALOG.md` **section 8**. Key corrections folded in above:
      MON params consumed as two arrays (values @0o100–0o107 as 5APn/5DPn high/low, addresses
      @0o40–0o44), buffer via ABUFA=0o140 pointer; saved P never read by SINTRAN; DECOERRMESS
      trap-shape conditional (TRAPN=0o46+MICFU); MICFU 05/27B never sent (discrepancy
      resolved — dropped codes, no version problem); MICFU 22B sender = P0START; 3RMICV
      second (CPUPAR) halfword unconsumed; NUMPA write-back bit k ⇒ param k+1 into 5DPn
      (5APn zeroed); ND-5000 queue head = N500DF.X5FIF (base 6) in 5MBBANK via XMSINIT;
      SYSPAR delivered by octobus CMSYSPAR, not MICFU 22B; OCB receiver = 5OMBREAD @146550
      (the earlier 037660 anchor was wrong), 201B record layout known, 203B/204–210B handled
      generically.
- [x] **Re-verified against the lossless disassembly (2026-07-17, commit a91dff4)** — see
      section 3.10 for the decode model and the verified offset table. All memory-direction
      and offset inferences held; every [X]-anchored offset promoted to [V]; the R1
      address-vs-value ambiguity closed (0o40 region = addresses, 0o100 region = values).
- [x] Saved-P offset in CALL_MON9: **HW 7-8 = N500A** [V] — the same slot 3RPREG reads.
- [x] TRAP_GEN word maps [V]: TRAPN@0o16; STOPR@0o11:=2; status/P words @0o12 and @0o14;
      trap record/fault params @0o17-0o30 (TRAP_GEN4C: srf[41]→0o17 w, srf[43]→0o21 hw,
      srf[40]→0o22 w; TRAP_GEN3: ctx+0x68→0o17 w, ctx+0x64→0o21 w, ctx+0x6C→0o23 w,
      ctx+0x70→0o25 hw, ctx+0x74→0o26 hw; TRAP_GEN3B/3C→0o27/0o30 hw). TRAPDECODER side
      [X carver R3]: reads TRAPN@16 first, legal range 0..0o53, 0o46 = page fault → swapper;
      0o44/0o51 NOT special-cased by SINTRAN; no symbolic trap-name table found in the carve.
- [ ] Per-subtype TRAP_OCB payloads for 203B/204–210B — the ND-100 receiver (5OMBREAD
      @146550) handles these generically [X carver R8], so the microcode listing is now the
      only source; 201B is closed (error record at LMFIELD+2, size MMSGLENGTH+4:
      emainstat/elog1-4/emaster/eslave/eaddress/esyndrom).
- [ ] The DIT (Domain Information Table) layout consumed by TRAP_ENT/TRAP_START (handler
      address table, per-trap enable bytes/words) — needed only if the emulator must run
      LOCAL ND-500 trap handlers.
- [ ] Meaning of PRNOWR's cell and the ACCP command-word bit fields (observed constants:
      0o100001, 0o100102, 0o100401, 0o100501).
- [ ] Whether the classic ND-500 (non-SAMSON) microcode differs in the fetch path (this doc
      is the 5800/B30 Octobus image; A30 image available for diffing).
