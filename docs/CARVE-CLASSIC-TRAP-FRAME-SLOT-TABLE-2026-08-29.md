# The classic ND-500 trap frame: both directions, carved from the store

> # RETRACTED IN PART, 2026-08-29, SAME DAY
>
> **The slot ORDER below is right. The BASE is WRONG, and so is everything I built on it.**
>
> I claimed `BM#2 = 4`, hence base `B+20`, hence slot 1 (P) at `B+20` and slot 2 (L) at `B+24`.
> `nd500uc-47` applied that, broke two documented tests, and reverted. They were right, and the
> evidence was there to be read: **ND-05.009.4**, Figure 19 and `B.arg1`.
>
> What the manual actually says, all `[V]`:
>  - Figure 19: the local data field is `Trapping P (1 word)` FOLLOWED BY `Copy of register block`.
>    Trapping P is NOT in the block - it precedes it.
>  - `B.arg1 = Trapping P and the rest of the register block as numbered in chapter 2`.
>  - `The P register saved in B.ARG2 holds the address of the instruction to be executed when the
>    trap condition has been taken care of.`
>
> So **arg1 = Trapping P (a separate word), and arg2 = the saved P = the RESUME address, which is
> the FIRST word of the register block.** The microcode agrees exactly: the block loop writes
> `A,P` into its slot 1, and the manual calls that word `B.arg2`.
>
> **Therefore microcode slot 1 IS arg2, not arg1.** With arg1 at `B+20` and arg2 at `B+24` - the
> layout RetroCore already uses, which passes both documented tests and keeps LED out of an
> infinite trap loop - the block base is `B+24`, so `BM#2 = 0` and my `4` is refuted. Slot 2 (L)
> sits at `B+28`, not `B+24`.
>
> **How I got it wrong:** I graded `BM#2 = 4` as `[D]` from our own engine plus a suggestive
> pointer-stride, said out loud that our engine predicting our own observation is not independent
> evidence - and then leaned on it anyway. A `[D]` was allowed to overrule a manual I had not gone
> looking for. It was in-repo the whole time, under `NDInsight\Reference-Manuals\`.
>
> **`[OPEN]` and worth chasing:** the microcode loop runs `LC := 035` = 29 iterations and the
> dispatch table has 29 arms, but Figure 19 calls the register block **39 words**. Those do not
> agree and I have not reconciled them. Do not treat 29 as the frame size.


Source: `E:\Dev\Repos\Ronny\ND110Compile\ND110Compile\uCode\CONT-STORE-10611.LISTING.TXT` — the
vendor round-trip listing, one line per microword, octal addresses. Everything below is `[V]` unless
marked otherwise.

## The two loops are mirrors of each other

**SAVE** at `010332`, **RESTORE** at `010340`. Same base, same count, opposite direction:

```
010332/ DP := AM#23 - BM#2        010340/ DP := AM#23 - BM#2
010333/ LC := 035  (29 words)     010341/ LC := 035  (29 words)
010334/ AL#23 := 177777  (-1)     010342/ AL#23 := 0
010335/ AL#23 += 1; call 10360    010343/ read 4 bytes, DP += 4, LCDECR
010336/ WRITE 4 bytes, DP += 4    010344/ AM#20 := DATA; call 10420
```

`10360` and `10420` are `JMPREL` dispatch tables indexed by the loop counter. **The tables ARE the
slot layout.**

## The slot table

| slot | byte off. from base | save reads (`10360`) | restore writes (`10420`) |
|---|---|---|---|
| 1 | +0 | **`A,P`** | `D,DP` → `010460/010461` `AD,NPC` / `AD,PC` |
| 2 | +4 | `A,L` | `D,L` |
| 3 | +8 | `A,B` | `D,B` |
| 4 | +12 | `A,R` | `D,R` |
| 5-8 | +16..+28 | `X#0`-`X#3` | `X#0`-`X#3` |
| 9-12 | | `AM#0`-`AM#3` | `AM#0`-`AM#3` |
| 13-16 | | `AL#0`-`AL#3` | `AL#0`-`AL#3` |
| 17 | | `S1` | `S1` → `010463` `XST1` |
| 18-20 | | `AL#16`, `AL#17`, `AM#7` | same |
| 21 | | `LL` | `LL`, then `010462` **`HL := LL`** |
| 22 | | — | **no destination — DISCARDED** |
| 23 | | `AL#7` | `AL#7` (= THA) |
| 24-25 | | `AM#15`, `AM#14` | same |
| 26-27 | | — | discarded |
| 28-29 | | `AM#11`, `AL#11` | same |

Three of these were already carved independently on the RetroCore side and are quoted in
`CpuND500.ProcessControl.cs`: `HL := LL` at `010462`, the discarded slot 22, and `AL#7` = THA at
`010451`. Three checks that fail in different ways, all agreeing — that is what makes the ORDER
trustworthy rather than plausible.

## The base, and the one number that is not from the store

Base = `AM#23 - BM#2`, and RETT reaches it with `AM#23 = B + 0o30` (`011747`).

`BM#2 = 4` — **not** from the store: 234 words use `B,BM#2` and **zero** write `D,BM#2`, so the BM
file is hardwired and the microcode cannot be asked. It comes from the engine that executes the
store, `CpuND500UC.cs:3841`, `return 1u << (sel - BselBmBase)` — one-hot. Corroborated inside the
store by `BM#2` being used as a 4-byte pointer stride beside literal `4` operands (`003056`,
`002610`, `002617`). Two independent sources, so `[D]` and confident, but a manual citation would be
needed for `[V]`.

So the base is `(B + 0o30) - 4 = B + 20`:

 - **slot 1 (P) at B+20**
 - **slot 2 (L) at B+24**

## Trapping P vs restart P: the question is malformed for THIS frame

Save slot 1 reads `A,P` — the architectural P register — and restore slot 1 goes back to the PC.
One address out, the same address back.

**The classic store has no second program-register source: 34 occurrences of `A,P`, zero of anything
else in that family across all 8192 words.** The microcode cannot select between a trapping and a
restart P because only one is readable.

So this frame carries ONE program address. The trapping/restart pair recorded at `ctx[224B]` /
`ctx[240B]` in `CARVE-ANSWER-CLASSIC-TRAPWRITER-S2-CONTROL` belongs to **SINTRAN's context block**, a
different structure, and must not be mapped onto the hardware trap frame. Anyone reasoning about
ENTT/RETT does not have a choice to make.

## Why this was carved

`nd500uc-47` hit LINKAGE-LOADER dying on EXIT with "Illegal physical segment", traced to RETT
resuming mid-instruction, and asked rather than inferring the offset from mode names. The table
above is what identified `B+24` as the saved `L` rather than the PC. Their follow-up measurement
then showed ENTT wrote the correct address to both `+20` and `+24` and that `+24` was **clobbered**
between write and read — which is exactly what slot 2 being the program's own `L` predicts.
