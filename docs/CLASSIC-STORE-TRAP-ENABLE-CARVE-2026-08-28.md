# Where the classic ND-500's local-trap-enable register (TE) comes from

**Created 2026-08-28.** Full path:
`E:\Dev\Ronny\ND5000UC\docs\CLASSIC-STORE-TRAP-ENABLE-CARVE-2026-08-28.md`

**Why this exists.** LINKAGE-LOAD-H02 ends `stopMode=CRASHED` on the classic lane with a DOUBLE
FAULT: 32 page-fault attempts against 31 posted records, the 32nd raised while the 31st was still
being dispatched. The measured message is

```
PGF at PC=0x08000004 addr=0x080016C0 raised while already dispatching a trap. THA=0x08001628
```

and `0x08001628 + 4 * 46B == 0x080016C0`, so the second fault is **the trap-vector fetch itself
faulting**. That fetch only happens when the local-trap-enable gate says the trap is handled
locally. So the question is not "why did the vector read fault" - a page SINTRAN never mapped will
always fault - it is **"why was the vector read at all?"**, and that is decided by `TE`.

**Source.** `E:\Dev\Repos\Ronny\ND110Compile\ND110Compile\uCode\CONT-STORE-10611.LISTING.TXT`
(8192 words, 9 x 16-bit parts = 144 bits = 18 bytes/word), the CLASSIC store - not the B30. There is
no `.LABE` for it, so every address below was found by reading microwords, not by name.

---

## 1. The gate `[V]`

`011034`-`011037` builds the effective enable mask before any vector is touched:

```
011034/ ALU,ADIR A,XD,TE D,AL#21 NEXT PRF,CLEAR SLOW2 ;      AL#21 := TE
```

then bits 31/30 are forced on, bits 8..0 forced off, and the result is ANDed with the pending trap
bits; `011064` branches on zero. The ZERO leg reaches `007570`/`007576` - `D,TAG` and `D,IODOUT`,
the doorbell that **reports the trap to the ND-100**. The NON-ZERO leg does `D,TRAPCLR` and only
then reads the vector at `011622`-`011626`.

**So `TE` is the switch between "ask SINTRAN for the page" and "run a handler in the guest".**

## 2. Every writer of TE in the whole 8192-word store `[V]`

Swept for the DESTINATION field `D,TE`, kept separate from the SOURCE field `A,XD,TE` (22 readers) -
the same source-vs-destination trap that produced a wrong count in the MON-screening carve on
2026-08-25. **Seven words write TE:**

| addr | word | what |
|---|---|---|
| `000643` | `ALU,ADIR A,XD,SARG D,TE JMPNS 7765,400` | `TE := SARG` - a macro instruction loading it |
| `007567` | `ALU,FZRO D,TE JMP 11014` | `TE := 0`, immediately before the `D,TAG`/`D,IODOUT` report words at `007570`-`007571` |
| `010011` | `ALU,FZRO D,TE JMPNS 7543` | `TE := 0` |
| `010041` | `ALU,FZRO D,TE JMPNS 7543` | `TE := 0` |
| `010070` | `ALU,FZRO D,TE NEXT` | `TE := 0` |
| `010133` | `ALU,FZRO D,TE NEXT` | `TE := 0` |
| `011603` | `ALU,OR A,AL#26 B,AM#26 D,TE C,ALU JMP 12544` | `TE := AL#26 OR AM#26`, in the trap region |

## 3. THE FINDING: TE is NOT part of the context block `[V]`

The classic context SAVE chain is `010363`-`010417` and the LOAD chain is `010423`-`010457`, one
slot per word, mirrored. Read in full, in order:

 - save: `A,P`, `A,L`, `A,B`, `A,R`, `A,X#0..X#3`, (blank), `A,A#1..A#3`, `A,AL#0..AL#3`, `A,XD,S1`,
   `A,AL#16`, `A,AL#17`, `A,AM#7`, `A,XD,LL`, ... `A,AL#7`, `A,AM#15`, `A,AM#14`, `A,AM#11`, `A,AL#11`.
 - load: the same list as destinations, plus `010462` `D,HL := LL` and `010463` `D,XST1`.

**There is no `A,XD,TE` in the save chain and no `D,TE` in the load chain.** The trap-enable
register is neither saved with a process nor restored with one. A process that starts therefore
inherits whatever `TE` the machine last had, unless one of the five `FZRO D,TE` sites lies on the
path that started it.

## 4. What this predicts, and what is still [OPEN]

`StartProcessFromContextBlock` (RetroCore, `CpuND500.ProcessControl.cs:449`) reads ctx `0x00`-`0x60`
and **loads no trap-enable register either** - consistent with section 3, and it means our
`OTE1/OTE2/MTE1/MTE2` at RUN time are whatever an earlier path left in them.

**Prediction, not yet measured:** at the LINKAGE-LOAD double fault the mask `(OTE | MTE)` has the
page-fault bit set (trap 46B = 38 decimal = `OTE2` bit 6), we take the local-handler branch for a
trap SINTRAN installed no handler for, and crash reading the vector. With the mask clear the gate
refuses, the fault is reported to the ND-100, and the swapper gets asked for the page - which is
what SINTRAN expects.

The double-fault message now carries `OTE`, `MTE`, the combined mask and the trap number whose
vector fetch faulted (`CpuND500.Trap.cs`), so the next classic-lane run answers this instead of
repeating "double fault". **Until that run, the prediction is `[D]`, not `[V]`.**

`[OPEN]` - whether `D,TE` is the ONLY way TE is written. An external write (`W,EXT`/`EX,CTF`) could
reach it without naming the destination field, and that sweep has not been done.

`[OPEN]` - which of the five `FZRO D,TE` sites sit on a process-start path. `007567` is clearly on
the trap-report path; `010011`/`010041`/`010070`/`010133` sit among words using `SARG` and
`EXFUNC=12`, which reads like macro-instruction bodies, but that has not been carved.
