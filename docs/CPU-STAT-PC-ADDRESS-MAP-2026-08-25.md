# CPU-STAT — PC address map (resolve a live trace PC without another round trip)

**Created 2026-08-25.** Full path:
`E:\Dev\Ronny\ND5000UC\docs\CPU-STAT-PC-ADDRESS-MAP-2026-08-25.md`

**Why this exists.** The live boot now runs `CPU-STAT` under real SINTRAN with the MON calls
forwarded. The open question is what the domain executes after its final resume. When a trace
reports a PC, this file turns that number into "which routine, which MON call" in one lookup
instead of a round trip.

**Source, and how far it is verified.** Everything below is decoded from
`E:\Dev\Ronny\NDInsight\SINTRAN\ND500-APPS\CPU-STAT\analysis\cpu-stat.asm`
(the disassembly of `CPU-STAT.DOM`, 38912 bytes) — 5117 decoded instructions.
Grade `[V]`: **all 78 internal call targets land exactly on a decoded instruction boundary**
(0 misses). A stream that decoded wrongly anywhere in the middle would put at least one target
inside an instruction. So the address→instruction mapping can be trusted across the whole program.

## 1. The address bands — read this first

ND-500 logical address = `segment << 27`. So segment 1 = `0x08000000`, segment 31 = `0xF8000000`.

| PC band | what it is |
|---|---|
| `0x08000004 .. 0x080003DB` | **MAIN** (the entry point body, 107 instructions). Exactly ONE MON site in it: `0x080003BB` = MON 0B. |
| `0x080003DC .. 0x08003EDF` | application code. **No MON calls at all** in this whole range. |
| `0x08003EE0 .. 0x08004BFF` | mixed application/runtime; MON traffic starts here. |
| `0x08004C00 .. 0x080050E4` | **the MON stub library** — a wall of 5-to-20-instruction wrappers, each issuing exactly ONE MON. A PC here names its MON with no ambiguity (table 3). |
| `0x080050E4 .. 0x0800532A` | tail runtime, no MON calls. |
| `>= 0x0800532B` | **outside the program segment.** The program text ends at `0x0800532A` (`ret`). A PC at or above this is not CPU-STAT code — a runaway, a library that is not in this DOM, or a bad restart address. |
| `0xFFFFFFFF_F80000nn` | **a segment-31 MON trampoline.** `nn` (the low halfword) IS the MON number, in hex. This is the documented CALLG-into-segment-31 mechanism: the fetch traps (code 6 CALL_MON), it is not a MON opcode. |

Reminder that costs days if forgotten: **a trap PC is `P`, the RESTART address, and it runs AHEAD
of the faulting instruction.** `P1` is the trapping P. If a reported address is not on an
instruction boundary in the table below, that is EXPECTED, not a decode defect.

## 2. Every MON call CPU-STAT can make (43 sites, 28 distinct numbers)

Decode check on this table: five of these numbers are independently named elsewhere in the tree —
**412B FSCNT** and **73B SMAX** (nd500-apps skill), **262B ND-5800 identity**, **123B** and
**503B** (the MON-oracle verdict list). They were derived here purely from the low halfword of the
segment-31 target, with no reference to those lists, and they agree. That is what promotes the
"low halfword = MON number" rule from documented to measured.

| call site | MON (hex) | MON (octal) |
|---|---|---|
| 0x080003BB | 0x0 | 0B |
| 0x08003F5E | 0x112 | 422B |
| 0x0800428C | 0x1A | 32B |
| 0x080042BF | 0x1A | 32B |
| 0x080042FF | 0x62 | 142B |
| 0x08004378 | 0x62 | 142B |
| 0x0800441A | 0x1A | 32B |
| 0x0800446F | 0x1A | 32B |
| 0x080044A4 | 0x4C | 114B |
| 0x080044F6 | 0x9 | 11B |
| 0x08004533 | 0x0 | 0B |
| 0x08004542 | 0x9 | 11B |
| 0x0800454E | 0x4C | 114B |
| 0x0800455A | 0x63 | 143B |
| 0x080045BB | 0x112 | 422B |
| 0x080045F6 | 0x62 | 142B |
| 0x08004609 | 0x34 | 64B |
| 0x08004614 | 0x1A | 32B |
| 0x0800461F | 0x0 | 0B |
| 0x08004B82 | 0x1A | 32B |
| 0x08004B8D | 0x0 | 0B |
| 0x08004C16 | 0x1 | 1B |
| 0x08004C4E | 0x2 | 2B |
| 0x08004C6B | 0x18 | 30B |
| 0x08004C8C | 0x21 | 41B |
| 0x08004CB5 | 0x23 | 43B |
| 0x08004D8C | 0x28 | 50B |
| 0x08004E04 | 0x2C | 54B |
| 0x08004E2D | 0x32 | 62B |
| 0x08004E50 | 0x34 | 64B |
| 0x08004E6E | 0x3B | 73B |
| 0x08004E9B | 0x3E | 76B |
| 0x08004EDF | 0x4F | 117B |
| 0x08004F27 | 0x50 | 120B |
| 0x08004F58 | 0x52 | 122B |
| 0x08004F7B | 0x53 | 123B |
| 0x08004F8F | 0x63 | 143B |
| 0x08005006 | 0x91 | 221B |
| 0x08005031 | 0xB2 | 262B |
| 0x08005050 | 0x10A | 412B |
| 0x08005079 | 0x10B | 413B |
| 0x0800508D | 0x144 | 504B |
| 0x080050B6 | 0x143 | 503B |

## 3. Routine extents (78 internal call targets + MAIN)

A PC resolves to the row whose `entry <= PC < ends before`. The last column is every MON number
reachable from inside that routine's own body (not through its callees).

| entry | ends before | instrs | MON calls inside (octal) |
|---|---|---|---|
| 0x08000004 | 0x080003DC | 107 | 0B |
| 0x080003DC | 0x08000538 | 43 |  |
| 0x08000538 | 0x0800071D | 57 |  |
| 0x0800071D | 0x08000931 | 63 |  |
| 0x08000931 | 0x080009B0 | 10 |  |
| 0x080009B0 | 0x08000ACF | 52 |  |
| 0x08000ACF | 0x08000B7A | 49 |  |
| 0x08000B7A | 0x08000BFE | 41 |  |
| 0x08000BFE | 0x08000D12 | 90 |  |
| 0x08000D12 | 0x080010E8 | 304 |  |
| 0x080010E8 | 0x080015DA | 286 |  |
| 0x080015DA | 0x08001682 | 30 |  |
| 0x08001682 | 0x08001A7D | 233 |  |
| 0x08001A7D | 0x08001B31 | 57 |  |
| 0x08001B31 | 0x0800225B | 417 |  |
| 0x0800225B | 0x080022D1 | 29 |  |
| 0x080022D1 | 0x0800231B | 10 |  |
| 0x0800231B | 0x0800266E | 266 |  |
| 0x0800266E | 0x080027FA | 112 |  |
| 0x080027FA | 0x080028EE | 77 |  |
| 0x080028EE | 0x0800294E | 25 |  |
| 0x0800294E | 0x08002AF5 | 120 |  |
| 0x08002AF5 | 0x08002C2E | 88 |  |
| 0x08002C2E | 0x08002DE1 | 129 |  |
| 0x08002DE1 | 0x08002E2C | 18 |  |
| 0x08002E2C | 0x08002F8D | 94 |  |
| 0x08002F8D | 0x08003047 | 48 |  |
| 0x08003047 | 0x08003099 | 29 |  |
| 0x08003099 | 0x0800350C | 360 |  |
| 0x0800350C | 0x0800356A | 20 |  |
| 0x0800356A | 0x0800377A | 160 |  |
| 0x0800377A | 0x080037AD | 15 |  |
| 0x080037AD | 0x0800384C | 28 |  |
| 0x0800384C | 0x08003BDC | 269 |  |
| 0x08003BDC | 0x08003C56 | 26 |  |
| 0x08003C56 | 0x08003CB0 | 27 |  |
| 0x08003CB0 | 0x08003DD3 | 53 |  |
| 0x08003DD3 | 0x08003E0A | 17 |  |
| 0x08003E0A | 0x08003EE0 | 83 |  |
| 0x08003EE0 | 0x0800409C | 95 | 422B |
| 0x0800409C | 0x080040F1 | 25 |  |
| 0x080040F1 | 0x08004168 | 32 |  |
| 0x08004168 | 0x080041DC | 38 |  |
| 0x080041DC | 0x080041F7 | 5 |  |
| 0x080041F7 | 0x08004264 | 22 |  |
| 0x08004264 | 0x08004298 | 13 | 32B |
| 0x08004298 | 0x080042CB | 15 | 32B |
| 0x080042CB | 0x0800453A | 80 | 0B 11B 32B 114B 142B |
| 0x0800453A | 0x08004722 | 79 | 0B 11B 32B 64B 114B 142B 143B 422B |
| 0x08004722 | 0x08004743 | 8 |  |
| 0x08004743 | 0x080049A5 | 155 |  |
| 0x080049A5 | 0x080049F1 | 30 |  |
| 0x080049F1 | 0x08004BAC | 109 | 0B 32B |
| 0x08004BAC | 0x08004BD1 | 9 |  |
| 0x08004BD1 | 0x08004C00 | 12 |  |
| 0x08004C00 | 0x08004C33 | 12 | 1B |
| 0x08004C33 | 0x08004C61 | 10 | 2B |
| 0x08004C61 | 0x08004C76 | 6 | 30B |
| 0x08004C76 | 0x08004CA0 | 9 | 41B |
| 0x08004CA0 | 0x08004CC7 | 9 | 43B |
| 0x08004CC7 | 0x08004DB4 | 45 | 50B |
| 0x08004DB4 | 0x08004E17 | 20 | 54B |
| 0x08004E17 | 0x08004E41 | 9 | 62B |
| 0x08004E41 | 0x08004E58 | 6 | 64B |
| 0x08004E58 | 0x08004E81 | 9 | 73B |
| 0x08004E81 | 0x08004EAE | 11 | 76B |
| 0x08004EAE | 0x08004EF6 | 18 | 117B |
| 0x08004EF6 | 0x08004F3E | 18 | 120B |
| 0x08004F3E | 0x08004F66 | 9 | 122B |
| 0x08004F66 | 0x08004F84 | 7 | 123B |
| 0x08004F84 | 0x08004FB6 | 13 | 143B |
| 0x08004FB6 | 0x0800501B | 20 | 221B |
| 0x0800501B | 0x08005045 | 9 | 262B |
| 0x08005045 | 0x0800506F | 9 | 412B |
| 0x0800506F | 0x08005082 | 5 | 413B |
| 0x08005082 | 0x080050E4 | 18 | 503B 504B |
| 0x080050E4 | 0x0800529D | 125 |  |
| 0x0800529D | 0x080052A9 | 4 |  |
| 0x080052A9 | 0x0800532B | 47 |  |

## 4. How to use it on a live PC

1. Is the PC `0xF80000nn`? Then it is a MON trampoline and `nn` hex is the MON number — the
   question becomes "why did that MON not return", which is a SINTRAN-side question.
2. Is the PC `>= 0x0800532B`? Then it is not CPU-STAT code. Check the restart address before
   assuming a runaway — `P` runs ahead.
3. Otherwise find its row in table 3, then grep the exact address in `cpu-stat.asm` for the
   instruction itself. Every address in the file is absolute, so a plain grep on the 8 hex digits
   lands on the line.

## 5. What this does NOT tell you

- The DOM has **one** segment (program `0x532B` bytes, data `0x1A28` bytes). Data addresses are a
  separate space and are NOT in this map.
- No routine names — the DOM carries no symbols. The entries are call targets, so a routine that is
  only ever reached by a fall-through or a computed branch will not appear as its own row.
- Whether a MON call site was actually reached at run time. This is a static map. Marking a row as
  "the hang" needs the trace, not this file.
