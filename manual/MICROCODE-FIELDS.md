# ND-5800 Microcode Field Definitions

Based on ND-05.022.1 EN - ND-5000 Microprogram Guide and SAMSON MICROCODE DEFINITION (15.05.1987)

## Overview

The ND-5800 microcode is 128 bits wide. Each microcode word controls the CPU's operation for one microcycle. The word is divided into multiple control fields that operate in parallel.

The CPU pipeline consists of four levels:
- **I-level** (Instruction level) - Instruction fetch, operand fetch, instruction decoding
- **M-level** (Data level) - MIC sequencing, SRF address generation, DAC address completion
- **A-level** (ALU level) - ALU operations on selected operands
- **F-level** (Result level) - Result routing to selected destination

## Microcode Assembler Syntax

A microinstruction is a combination of:
- Mnemonic symbols (e.g., `ALU,A`, `COND,MZRO`, `D,SC3`)
- Constants (e.g., `374` for octal values)
- Defined symbols

**Rules:**
- Symbols are separated by spaces
- Microinstruction is terminated by `;` (semicolon)
- May span multiple lines
- `%` starts a comment (rest of line is ignored)

**Example:**
```
ALU,A A,DATA TYP,BY D,SC3 READ  % Read byte
AA,EA2 374 AB,MARG              % Address = EA2 + 374 + mini arg
NEXT*;                          % Continue to next instruction
```

## Bit Field Layout Summary

| Bits | Width | Field | Description |
|------|-------|-------|-------------|
| 127-116 | 12 | **ALU Control** | **Group: ALU control functions** |
| 127-122 | 6 | ↳ True | ALU operation when condition is true |
| 127-124 | 4 |   ↳ ALU | ALU function select |
| 123-122 | 2 |   ↳ C | Carry select |
| 121-116 | 6 | ↳ False | ALU operation when condition is false |
| 121-118 | 4 |   ↳ ALU | ALU function select |
| 117-116 | 2 |   ↳ C | Carry select |
| 115 | 1 | EXUC | Execute unconditional |
| 114 | 1 | Cond.Alu | Enable condition-dependent ALU operation |
| 113-111 | 3 | Q-register control | Control for the Q shift register |
| 110-103 | 8 | AAP control | Additional arithmetic processor control |
| 102-101 | 2 | Timing control | Microcycle timing (SLOW1, SLOW2) |
| 100-98 | 3 | Data-type control | Select data type |
| 97 | 1 | ORCON enable | Enable OR control logic |
| 96-89 | 8 | A-operand select | Select source for A operand |
| 88-84 | 5 | B-operand select | Select source for B operand |
| 83-76 | 8 | Destination select | Select destination for result |
| 75-72 | 4 | Status bits control | Control for condition code flags |
| 71 | 1 | IXC Incr | Index counter increment |
| 70 | 1 | Lc Decr | Loop counter decrement |
| 69-60 | 10 | **Seq. Control** | **Group: Sequence control** |
| 69 | 1 | ↳ Cond.Seq | Enable conditional sequence |
| 68-65 | 4 | ↳ True | Next address control when condition true |
| 68-67 | 2 |   ↳ Seq Type | T,JMP / T,JMPREL / T,RETURN / T,NEXT |
| 66-65 | 2 |   ↳ Stack | T,HOLD / T,POP / T,LOAD / T,PUSH |
| 64-61 | 4 | ↳ False | Next address control when condition false |
| 64-63 | 2 |   ↳ Seq Type | F,JMP / F,JMPREL / F,RETURN / F,NEXT |
| 62-61 | 2 |   ↳ Stack | F,HOLD / F,POP / F,LOAD / F,PUSH |
| 60 | 1 | ↳ Invsqc | INVSEQ - Invert sequence condition |
| 59 | 1 | Csave | Save test condition to stack |
| 58-53 | 6 | Testobject | Select test condition |
| 52-44 | 9 | **IAC Control** | **Group: IAC control functions** |
| 52-51 | 2 | ↳ ABR | Alternative branch control |
| 50-48 | 3 | ↳ TBC | Target branch cache control |
| 47-44 | 4 | ↳ Get | Instruction/operand fetch control |
| 43 | 1 | Stop | Stop the processor |
| 42 | 1 | AAPSync | Synchronize with AAP |
| 41, 34-32 | 4 | Memory | Data memory control (split field) |
| 40 | 1 | Ad.Arti.Con | Address arithmetic OCA/Micro |
| 39-38 | 2 | EA Save | EA1SAVE, EA2SAVE, EA3SAVE |
| 37 | 1 | Memot | Memory request control |
| 36 | 1 | Spare | Not defined |
| 35 | 1 | Adact | Address arithmetic activate |
| 31-16 | 16 | Absolute address | Direct jump target address |
| 15-13 | 3 | Aa | Address A-operand |
| 12-9 | 4 | Ab | Address B-operand |
| 8-6 | 3 | Scal | Index scaling |
| 5-0 | 6 | ORCON | OR logic control field |
| 31-0 | 32 | Long argument | Full 32-bit immediate (overlapping) |
| 15-0 | 16 | Short argument | 16-bit immediate (overlapping) |
| 7-0 | 8 | Mini argument | 8-bit immediate (overlapping) |

---

## Bits 127-116: ALU Control (Group)

This is a group containing True and False ALU control, each split into ALU function and Carry select subfields.

### True (bits 127-122) - ALU Operation When Condition True

Structure: **ALU** (bits 127-124, 4 bits) + **C** (bits 123-122, 2 bits)

#### ALU Function (bits 127-124)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0000 | ALU,FZRO | Force zero output |
| 0001 | ALU,ADIRC | A-operand inverted (complement) |
| 0010 | ALU,AND | A AND B |
| 0011 | ALU,ANDCB | A AND (NOT B) |
| 0100 | ALU,A | A-operand direct through ALU |
| 0101 | ALU,XOR | A XOR B |
| 0110 | ALU,ANDCA | (NOT A) AND B |
| 0111 | ALU,OR | A OR B |
| 1000 | ALU,A-1 | A minus 1 |
| 1001 | ALU,A,/2 | FBUS = ALU.output/2, FBUS(31) = carry |
| 1010 | ALU,A-B | A minus B |
| 1011 | ALU,A-B,*2 | FBUS = ALU.output*2, FBUS(0) = 0 |
| 1100 | ALU,A+B,/2 | FBUS = ALU.output/2, FBUS(31) = carry |
| 1101 | ALU,A+B | A plus B |
| 1110 | ALU,B-A | B minus A |
| 1111 | ALU,A+B,*2 | FBUS = ALU.output*2, FBUS(0) = 0 |

#### C - Carry Select (bits 123-122)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | (zero) | Carry input = 0 |
| 01 | CRY,ONE | ONE AS CARRY |
| 10 | CRY,C | C FROM STATUS AS CARRY |
| 11 | CRY,MC | MICRO CARRY AS CARRY |

### False (bits 121-116) - ALU Operation When Condition False

Structure: **ALU** (bits 121-118, 4 bits) + **C** (bits 117-116, 2 bits)

Same encoding as True field. When False ALU is used, it automatically enables conditional ALU execution.

---

## Bit 115: EXUC (Execute Unconditional)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | Normal | Normal conditional execution |
| 1 | EXUC | Execute unconditionally (for "sneak" instructions) |

---

## Bit 114: Cond.Alu (Enable Conditional ALU)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (true only) | ALU uses true function only |
| 1 | C,ALU | ENABLE CONDITIONAL ALU OPERATION |

---

## Bits 113-111: Q-Register Control

| Value | Mnemonic | Graphics | Description |
|-------|----------|----------|-------------|
| 000 | (hold) | Hold | No Q-register operation |
| 001 | Q,F | Load (F to Q) | Q-register loaded from ALU output |
| 010 | Q,Q*DIV | DIV Shift | Q = Q*2, Q.bit.0 = DIVR (divide remainder) |
| 011 | Q,Q*LOG | LOG left | Q = Q*2, Q.bit.0 = 0 (logical shift left) |
| 100 | Q,Q/ARI | ARI right | Q = Q/2, Q.sign = Q.sign (arithmetic shift right) |
| 101 | Q,Q/LOG | LOG right | Q = Q/2, Q.sign = 0 (logical shift right) |
| 110 | Q,Q/ROT | ROT right | Q = Q/2, Q.sign = Q.bit.0 (rotate right) |
| 111 | Q,Q*ROT | ROT left | Q = Q*2, Q.bit.0 = Q.sign (rotate left) |

---

## Bits 110-103: AAP Control

Structure: **Type** (bits 110-108) + **Operation** (bits 107-103)

### Type Field (bits 110-108)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 000 | (none) | No AAP operation |
| 001 | AAP1 | ND-570 floating point unit |
| 010 | AAP2 | Extended AAP |
| 011 | (none) | Reserved |
| 100 | (none) | Reserved |
| 101 | (none) | Reserved |
| 110 | EXPISO | Exponent isolate (standalone, see below) |
| 111 | (none) | Reserved |

### EXPISO (Type 110) - Exponent Isolate

When type = 110, this is a standalone operation that extracts the exponent from a floating-point number:

> FBUS(8-0) <- F(30-22)

This copies the 9-bit exponent field (bits 30-22) from the input to bits 8-0 of FBUS. The operation field (bits 107-103) is likely ignored for this type.

Note: There is also AAP2,EXPISO which is a separate AAP2 operation at code 11110.

### AAP1 Operations (Type 001) - ND-570 Floating Point Unit

| Code | Mnemonic | Types | Description |
|------|----------|-------|-------------|
| 00001 | AAP1,CTF | BY HW W | Convert to floating |
| 00010 | AAP1,CTDF | BY HW W | Convert to double floating |
| 00011 | AAP1,UCTF | W | Unsigned convert to floating |
| 00100 | AAP1,UCTDF | W | Unsigned convert to double floating |
| 00101 | AAP1,CTBYR | F DF | Convert to byte rounded |
| 00110 | AAP1,CTHWR | F DF | Convert to halfword rounded |
| 00111 | AAP1,CTWR | F DF | Convert to word rounded |
| 01000 | AAP1,CTBY | F DF | Convert to byte |
| 01001 | AAP1,CTHW | F DF | Convert to halfword |
| 01010 | AAP1,CTW | F DF | Convert to word |
| 01011 | AAP1,INTR | F DF | Integer part rounded |
| 01100 | AAP1,INT | F DF | Integer part truncated |
| 01101 | AAP1,SHA | BY HW W | Shift arithmetic |
| 01110 | AAP1,SHL | BY HW W | Shift logical |
| 01111 | AAP1,SHR | BY HW W | Shift rotational |
| 10000 | AAP1,DTOFR | DF | Convert double to floating rounded |
| 10001 | AAP1,A+B | F DF | Add |
| 10010 | AAP1,B-A | F DF | Subtract B-A |
| 10011 | AAP1,B/A | F DF | Divide B/A |
| 10100 | AAP1,A-B | F DF | Subtract A-B |
| 10101 | AAP1,COMP | F DF | Compare |
| 10110 | AAP1,A/B | F DF | Divide A/B |
| 10111 | AAP1,DIVP | F DF | Partial divide |
| 11000 | AAP1,A*B | BY HW W F DF | Multiply |
| 11001 | AAP1,UMUL | W | Unsigned multiply |
| 11010 | AAP1,MUL4 | W | Multiply with overflow |
| 11011 | AAP1,RRF | - | Read AAP register file |
| 11100 | AAP1,WRF | - | Write AAP register file |
| 11110 | AAP1,CLEAR | - | Reset AAP interface |

### AAP2 Operations (Type 010) - Extended AAP

| Code | Mnemonic | Description |
|------|----------|-------------|
| 00000 | AAP2,SUBAB | Subtract A-B |
| 00001 | AAP2,ABSSUB | Magnitude of difference |
| 00010 | AAP2,MUL | Multiply A*B |
| 00011 | AAP2,MULABSA | B times magnitude of A |
| 00100 | AAP2,NEG | Negate |
| 00101 | AAP2,MULABSB | A times magnitude of B |
| 00110 | AAP2,MULNEG | Multiply and negate |
| 00111 | AAP2,MULNEGA | B times negative of A |
| 01000 | AAP2,ADD | Add A+B |
| 01001 | AAP2,ABSADD | Magnitude of sum |
| 01010 | AAP2,ADDABS | Sum of magnitudes |
| 01011 | AAP2,MULNEGB | A times negative of B |
| 01100 | AAP2,PASS | Pass through (identity) |
| 01101 | AAP2,MULNEGAB | Negative of A times B |
| 01110 | AAP2,PASSABS | Absolute value |
| 10000 | AAP2,SUBBA | Subtract B-A |
| 10001 | AAP2,SUBABABS | Difference of magnitudes (A-B) |
| 10010 | AAP2,SUBBAABS | Difference of magnitudes (B-A) |
| 10100 | AAP2,IMUL | Integer multiply, one result |
| 10101 | AAP2,IMULD | Integer multiply, two results |
| 10110 | AAP2,IMULU | Unsigned integer multiply, one result |
| 10111 | AAP2,IMULUD | Unsigned integer multiply, two results (alias: AAP1,UMUL,D) |
| 11000 | AAP2,CLEAR | Clear ongoing AAP2 sequence |
| 11011 | AAP2,CTI | Convert to integer |
| 11100 | AAP2,CTIR | Convert to integer rounded |
| 11101 | AAP2,CTF | Convert to floating |
| 11110 | AAP2,CBF | Convert to other floating format |
| 11111 | AAP2,EXPISO | Exponent isolate |

---

## Bits 102-101: Timing Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | NORM | Normal cycle time |
| 01 | SLOW1 | Cycle time = 110 nsec |
| 10 | SLOW2 | Cycle time = 160 nsec |
| 11 | SLOW3 | Slowest cycle time |

---

## Bits 100-98: Data Type Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 000 | TYP,W | Word (32 bits) |
| 001 | TYP,F | Single floating (32 bits) |
| 010 | TYP,HW | Half word (16 bits) |
| 011 | TYP,BY | Byte (8 bits) |
| 100 | TYP,BI | Bit |
| 101 | TYP,DF | Double floating (64 bits) |
| 110 | TYP,DD | 128-bit floating point |
| 111 | TYP,DR | Data type controlled by ICA |

---

## Bit 97: Or Enable

Note: Graphics labels this as bit 96

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | OR control disabled |
| 1 | (enabled) | OR control enabled |

---

## Bits 96-89: A-Operand Select

The 8-bit A-operand field is structured as: **XXX** (bits 7-5 = group) + **ZZZZZ** (bits 4-0 = register)

| XXX | Group | Description |
|-----|-------|-------------|
| 000 | BMG | Bit Mask Group |
| 001 | ALU | Working Register File |
| 010 | MMS | Memory Management System |
| 011 | SPEC | Special Registers |
| 100 | MIC | Microcode Control |
| 101 | IDU | Instruction Decode Unit |
| 110 | IAC | Instruction Address Control |
| 111 | DAC | Data Address Control |

### Group 000: BMG (Bit Masks)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 00000000 | 000 | A,BM00 | A-BUS IS BIT MASK 0 |
| 00000001 | 001 | A,BM01 | A-BUS IS BIT MASK 1 |
| 00000010 | 002 | A,BM02 | A-BUS IS BIT MASK 2 |
| 00000011 | 003 | A,BM03 | A-BUS IS BIT MASK 3 |
| 00000100 | 004 | A,BM04 | A-BUS IS BIT MASK 4 |
| 00000101 | 005 | A,BM05 | A-BUS IS BIT MASK 5 |
| 00000110 | 006 | A,BM06 | A-BUS IS BIT MASK 6 |
| 00000111 | 007 | A,BM07 | A-BUS IS BIT MASK 7 |
| 00001000 | 010 | A,BM10 | A-BUS IS BIT MASK 10 |
| 00001001 | 011 | A,BM11 | A-BUS IS BIT MASK 11 |
| 00001010 | 012 | A,BM12 | A-BUS IS BIT MASK 12 |
| 00001011 | 013 | A,BM13 | A-BUS IS BIT MASK 13 |
| 00001100 | 014 | A,BM14 | A-BUS IS BIT MASK 14 |
| 00001101 | 015 | A,BM15 | A-BUS IS BIT MASK 15 |
| 00001110 | 016 | A,BM16 | A-BUS IS BIT MASK 16 |
| 00001111 | 017 | A,BM17 | A-BUS IS BIT MASK 17 |
| 00010000 | 020 | A,BM20 | A-BUS IS BIT MASK 20 |
| 00010001 | 021 | A,BM21 | A-BUS IS BIT MASK 21 |
| 00010010 | 022 | A,BM22 | A-BUS IS BIT MASK 22 |
| 00010011 | 023 | A,BM23 | A-BUS IS BIT MASK 23 |
| 00010100 | 024 | A,BM24 | A-BUS IS BIT MASK 24 |
| 00010101 | 025 | A,BM25 | A-BUS IS BIT MASK 25 |
| 00010110 | 026 | A,BM26 | A-BUS IS BIT MASK 26 |
| 00010111 | 027 | A,BM27 | A-BUS IS BIT MASK 27 |
| 00011000 | 030 | A,BM30 | A-BUS IS BIT MASK 30 |
| 00011001 | 031 | A,BM31 | A-BUS IS BIT MASK 31 |
| 00011010 | 032 | A,BM32 | A-BUS IS BIT MASK 32 |
| 00011011 | 033 | A,BM33 | A-BUS IS BIT MASK 33 |
| 00011100 | 034 | A,BM34 | A-BUS IS BIT MASK 34 |
| 00011101 | 035 | A,BM35 | A-BUS IS BIT MASK 35 |
| 00011110 | 036 | A,BM36 | A-BUS IS BIT MASK 36 |
| 00011111 | 037 | A,BM37 | A-BUS IS BIT MASK 37 |

### Group 001: ALU (Working Register File)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 00100000 | 040 | A,X1 | Index register X1 |
| 00100001 | 041 | A,X2 | Index register X2 |
| 00100010 | 042 | A,X3 | Index register X3 |
| 00100011 | 043 | A,X4 | Index register X4 |
| 00100100 | 044 | A,A1 | Floating most register A1 |
| 00100101 | 045 | A,A2 | Floating most register A2 |
| 00100110 | 046 | A,A3 | Floating most register A3 |
| 00100111 | 047 | A,A4 | Floating most register A4 |
| 00101000 | 050 | A,SC1 | Scratch register 1 (context) |
| 00101001 | 051 | A,SC2 | Scratch register 2 (context) |
| 00101010 | 052 | A,SC3 | Scratch register 3 |
| 00101011 | 053 | A,SC4 | Scratch register 4 |
| 00101100 | 054 | A,E1 | Floating least register E1 |
| 00101101 | 055 | A,E2 | Floating least register E2 |
| 00101110 | 056 | A,E3 | Floating least register E3 |
| 00101111 | 057 | A,E4 | Floating least register E4 |
| 00110000 | 060 | A,SC5 | Scratch register 5 |
| 00110001 | 061 | A,SC6 | Scratch register 6 |
| 00110010 | 062 | A,SC7 | Scratch register 7 |
| 00110011 | 063 | A,SC10 | Scratch register 10 |
| 00110100 | 064 | A,SC11 | Scratch register 11 |
| 00110101 | 065 | A,SC12 | Scratch register 12 |
| 00110110 | 066 | A,SC13 | Scratch register 13 |
| 00110111 | 067 | A,SC14 | Scratch register 14 |
| 00111000 | 070 | A,DATA | Data input register |
| 00111001 | 071 | A,BMLC | Bit mask from loop counter |
| 00111010 | 072 | (none) | Unused |
| 00111011 | 073 | A,Q | Q-register |
| 00111100 | 074 | A,ALU,STS | ALU status bits |
| 00111101 | 075 | A,ALU,TE | ALU trap enable bits |
| 00111110 | 076 | A,PXBM | Post-index bit-mask |
| 00111111 | 077 | ORA,IN/OP | OR A-operand from instruction/operand |

### Group 010: MMS (Memory Management System)

Note: Graphics uses shorthand (CPSTP, DPUMP, etc.) - "C" prefix likely means "combined IMM+DMM", "D" = DMM, "I" = IMM

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 01000000 | 100 | A,DMM,PSTP | DMM PSTP register (graphics: CPSTP) |
| 01000001 | 101 | A,DMM,PUWP | DMM PUWP register (graphics: DPUMP) |
| 01000010 | 102 | A,DMM,LA | DMM LA register (graphics: CLA) |
| 01000011 | 103 | A,DMM,WR | DMM WR register (graphics: DWA) |
| 01000100 | 104 | A,DMM,CAP | DMM Capability register (graphics: DCAP) |
| 01000101 | 105 | A,DMM,PS | DMM PS register (graphics: CPS) |
| 01000110 | 106 | A,DMM,PHS | DMM PHS register (graphics: DPHS) |
| 01000111 | 107 | A,DMM,DOM | DMM DOM register (graphics: DOOM) |
| 01001000 | 110 | A,DMM,MEM | Data memory (ASSUMED) |
| 01001001 | 111 | (none) | Unused |
| 01001010 | 112 | A,DMM,PHYS | DMM Physical address (graphics: DPHYS) |
| 01001011 | 113 | A,DMM,STS | DMM Status register (graphics: DSTS) |
| 01001100 | 114 | (none) | Unused |
| 01001101 | 115 | (none) | Unused |
| 01001110 | 116 | (none) | Unused |
| 01001111 | 117 | A,DMM,ADOM | DMM ADOM register (graphics: DADOM) |
| 01010000 | 120 | A,IMM,PSTP | IMM PSTP register (graphics: IPSTP) |
| 01010001 | 121 | A,IMM,PUWP | IMM PUWP register (graphics: IPUMP) |
| 01010010 | 122 | A,IMM,LA | IMM LA register (graphics: ILA) |
| 01010011 | 123 | A,IMM,WR | IMM WR register (graphics: IWR) |
| 01010100 | 124 | A,IMM,CAP | IMM Capability register (graphics: ICAP) |
| 01010101 | 125 | A,IMM,PS | IMM PS register (graphics: IPS) |
| 01010110 | 126 | A,IMM,PHS | IMM PHS register (graphics: IPHS) |
| 01010111 | 127 | A,IMM,DOM | IMM DOM register (graphics: IDOM) |
| 01011000 | 130 | A,IMM,MEM | IMM Memory (graphics: IMEM) |
| 01011001 | 131 | (none) | Unused |
| 01011010 | 132 | A,IMM,PHYS | IMM Physical address (graphics: IPHYS) |
| 01011011 | 133 | A,IMM,STS | IMM Status register (graphics: ISTS) |
| 01011100 | 134 | (none) | Unused |
| 01011101 | 135 | (none) | Unused |
| 01011110 | 136 | (none) | Unused |
| 01011111 | 137 | A,IMM,ADOM | IMM ADOM register (graphics: I-ADOM) |

### Group 011: SPEC (Special Registers)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 01100000 | 140 | A,SPEC,MOD | Modus register (graphics: MD0) |
| 01100001 | 141 | A,SPEC,AOB | AOB register (graphics: ADB) |
| 01100010 | 142 | A,SPEC,IAR | IAR register |
| 01100011 | 143 | A,SPEC,OC,DP | DPA-part of OC |
| 01100100 | 144 | A,SPEC,OC,AD | NADDR-part of OC |
| 01100101 | 145 | A,SPEC,OC,CO | Control-part of OC |
| 01100110 | 146 | A,SPEC,AC | Address cache |
| 01100111 | 147 | A,SPEC,IC | Instruction cache |
| 01101000 | 150 | A,SPEC,OLAH2 | OLAH2 register (graphics: DLAH2) |
| 01101001 | 151 | A,SPEC,AFLAG | ACCP flag register |
| 01101010 | 152 | A,SPEC,AOBASR | Communication register |
| 01101011 | 153 | A,SPEC,IRL | Instruction read latch |
| 01101100 | 154 | A,SPEC,DACR | DAC register |
| 01101101 | 155 | A,SPEC,ACH | AC hold register |
| 01101110 | 156 | A,SPEC,DLAH | DLA hold register |
| 01101111 | 157 | A,SPEC,LA | LA latch |
| 01110000 | 160 | A,SPEC,FLA | Forward LA latch |
| 01110001 | 161 | A,SPEC,DPSDOM | Data PS/DOM |
| 01110010 | 162 | A,SPEC,IPSDOM | Instruction PS/DOM |
| 01110011 | 163 | A,SPEC,IDIR | Instruction cache dir |
| 01110100 | 164 | A,SPEC,DCALA | Data cache LA |
| 01110101 | 165 | A,SPEC,CSTRC | CSTRC register |
| 01110110 | 166 | A,SPEC,DCADAT | Data cache data |
| 01110111 | 167 | A,SPEC,STRACE | Status trace |
| 01111000 | 170 | A,SPEC,ITRACE | Instruction trace |
| 01111001 | 171 | A,SPEC,ATRACE | Address trace |
| 01111010 | 172 | A,SPEC,DTRACE | Data trace |
| 01111011 | 173 | A,SPEC,CTRACE | Control trace |
| 01111100 | 174 | (none) | Unused |
| 01111101 | 175 | (none) | Unused |
| 01111110 | 176 | (none) | Unused |
| 01111111 | 177 | (none) | Unused |

### Group 100: MIC (Microcode Control)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 10000000 | 200 | A,MIC,MISTS | MIC status register (graphics: HISTS) |
| 10000001 | 201 | A,MIC,VECT | MIC vector register |
| 10000010 | 202 | A,MIC,RFA1 | RF-address register 1 |
| 10000011 | 203 | A,MIC,RFA2 | RF-address register 2 |
| 10000100 | 204 | A,MIC,STS | MIC status bits |
| 10000101 | 205 | A,MIC,TE | MIC trap enable bits |
| 10000110 | 206 | A,MIC,CURR | MIC current register |
| 10000111 | 207 | A,MIC,CNT32 | MIC 32-bit counter |
| 10001000 | 210 | (none) | Unused |
| 10001001 | 211 | (none) | Unused |
| 10001010 | 212 | (none) | Unused |
| 10001011 | 213 | (none) | Unused |
| 10001100 | 214 | A,RF1 | SRF via RFA1 |
| 10001101 | 215 | A,RF2 | SRF via RFA2 |
| 10001110 | 216 | A,RF1D | SRF via RFA1, decrement |
| 10001111 | 217 | A,RF2D | SRF via RFA2, decrement |
| 10010000 | 220 | A,SRF0 | SRF word 0 |
| 10010001 | 221 | A,SRF1 | SRF word 1 |
| 10010010 | 222 | A,SRF2 | SRF word 2 |
| 10010011 | 223 | A,SRF3 | SRF word 3 |
| 10010100 | 224 | A,SRF4 | SRF word 4 |
| 10010101 | 225 | A,SRF5 | SRF word 5 |
| 10010110 | 226 | A,SRF6 | SRF word 6 |
| 10010111 | 227 | A,SRF7 | SRF word 7 |
| 10011000 | 230 | A,SRF10 | SRF word 10 |
| 10011001 | 231 | A,SRF11 | SRF word 11 |
| 10011010 | 232 | A,SRF12 | SRF word 12 |
| 10011011 | 233 | A,SRF13 | SRF word 13 |
| 10011100 | 234 | A,SRF14 | SRF word 14 |
| 10011101 | 235 | A,SRF15 | SRF word 15 |
| 10011110 | 236 | A,SRF16 | SRF word 16 |
| 10011111 | 237 | A,SRF17 | SRF word 17 |

### Group 101: IDU (Instruction Decode Unit)

Note: Graphics labels this column "BDU"

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 10100000 | 240 | A,IDU,TE | IDU trap enable |
| 10100001 | 241 | A,IDU,HL | IDU HL register |
| 10100010 | 242 | A,IDU,LL | IDU LL register |
| 10100011 | 243 | A,IDU,LIMC | IDU limit control |
| 10100100 | 244 | A,IDU,B2 | IDU buffer 2 |
| 10100101 | 245 | A,IDU,STS | IDU status register |
| 10100110 | 246 | A,IDU,DPA | DPA bus register |
| 10100111 | 247 | (none) | Unused |
| 10101000-10111111 | 250-277 | (none) | Unused |

### Group 110: IAC (Instruction Address Control)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 11000000 | 300 | (none) | Unused |
| 11000001 | 301 | (none) | Unused |
| 11000010 | 302 | (none) | Unused |
| 11000011 | 303 | A,IAC,ILAR | IAC LA register |
| 11000100 | 304 | A,IAC,S | IAC scratch register |
| 11000101 | 305 | A,IAC,Y | IAC Y register |
| 11000110 | 306 | A,IAC,SP | IAC SP register |
| 11000111 | 307 | (none) | Unused |
| 11001000 | 310 | (none) | Unused |
| 11001001 | 311 | (none) | Unused |
| 11001010 | 312 | A,IAC,L | IAC Link register |
| 11001011 | 313 | A,IAC,P | IAC Program counter |
| 11001100 | 314 | A,IAC,NPC | IAC Next PC register |
| 11001101-11011111 | 315-337 | (none) | Unused |

### Group 111: DAC (Data Address Control)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 11100000 | 340 | (none) | Unused |
| 11100001 | 341 | (none) | Unused |
| 11100010 | 342 | (none) | Unused |
| 11100011 | 343 | A,DAC,DLAR | DAC LA register |
| 11100100 | 344 | A,DAC,EA0 | DAC EA0 register |
| 11100101 | 345 | A,DAC,EA1 | DAC EA1 register |
| 11100110 | 346 | A,DAC,EA2 | DAC EA2 register |
| 11100111 | 347 | A,DAC,EA3 | DAC EA3 register |
| 11101000 | 350 | (none) | Unused |
| 11101001 | 351 | A,MARG | Mini argument |
| 11101010 | 352 | A,DAC,B | DAC Base register |
| 11101011 | 353 | A,DAC,R | DAC Record register |
| 11101100 | 354 | (none) | Unused |
| 11101101 | 355 | (none) | Unused |
| 11101110 | 356 | A,SARG | Short argument (sign extended) |
| 11101111 | 357 | A,LARG | Long argument |

---

## Bits 88-84: B-Operand Select

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00000 | B,X1 | Index register X1 |
| 00001 | B,X2 | Index register X2 |
| 00010 | B,X3 | Index register X3 |
| 00011 | B,X4 | Index register X4 |
| 00100 | B,A1 | Floating most register A1 |
| 00101 | B,A2 | Floating most register A2 |
| 00110 | B,A3 | Floating most register A3 |
| 00111 | B,A4 | Floating most register A4 |
| 01000 | B,SC1 | Scratch register 1 |
| 01001 | B,SC2 | Scratch register 2 |
| 01010 | B,SC3 | Scratch register 3 |
| 01011 | B,SC4 | Scratch register 4 |
| 01100 | B,E1 | Floating least register E1 |
| 01101 | B,E2 | Floating least register E2 |
| 01110 | B,E3 | Floating least register E3 |
| 01111 | B,E4 | Floating least register E4 |
| 10000 | B,SC5 | Scratch register 5 |
| 10001 | B,SC6 | Scratch register 6 |
| 10010 | B,SC7 | Scratch register 7 |
| 10011 | B,SC10 | Scratch register 10 |
| 10100 | B,SC11 | Scratch register 11 |
| 10101 | B,SC12 | Scratch register 12 |
| 10110 | B,SC13 | Scratch register 13 |
| 10111 | B,SC14 | Scratch register 14 |
| 11000 | B,LC | Loop counter |
| 11001 | B,Q | Q-register |
| 11010 | B,BCD | BCD correction (1/4 or 0/8) |
| 11011 | B,IXC | Index counters |
| 11100 | (none) | Unused |
| 11101 | (none) | Unused |
| 11110 | (none) | Unused |
| 11111 | ORB,IN | OR B-operand from instruction |

---

## Bits 83-76: Destination Select

The 8-bit Destination field is structured as: **XXX** (bits 7-5 = group) + **ZZZZZ** (bits 4-0 = register)

| XXX | Group | Description |
|-----|-------|-------------|
| 000 | ALU | Working Register File |
| 001 | SPEC | Special Registers |
| 01X | MMS | Memory Management (0100=NOOP, 0101=DMM, 0110=IMM) |
| 100 | MIC | Microcode Control |
| 101 | IDU | Instruction Decode Unit |
| 110 | IAC | Instruction Address Control |
| 111 | DAC | Data Address Control |

### Group 000: ALU (Working Register File)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 00000000 | 000 | D,X1 | Index register X1 |
| 00000001 | 001 | D,X2 | Index register X2 |
| 00000010 | 002 | D,X3 | Index register X3 |
| 00000011 | 003 | D,X4 | Index register X4 |
| 00000100 | 004 | D,A1 | Floating most register A1 |
| 00000101 | 005 | D,A2 | Floating most register A2 |
| 00000110 | 006 | D,A3 | Floating most register A3 |
| 00000111 | 007 | D,A4 | Floating most register A4 |
| 00001000 | 010 | D,SC1 | Scratch register 1 |
| 00001001 | 011 | D,SC2 | Scratch register 2 |
| 00001010 | 012 | D,SC3 | Scratch register 3 |
| 00001011 | 013 | D,SC4 | Scratch register 4 |
| 00001100 | 014 | D,E1 | Floating least register E1 |
| 00001101 | 015 | D,E2 | Floating least register E2 |
| 00001110 | 016 | D,E3 | Floating least register E3 |
| 00001111 | 017 | D,E4 | Floating least register E4 |
| 00010000 | 020 | D,SC5 | Scratch register 5 |
| 00010001 | 021 | D,SC6 | Scratch register 6 |
| 00010010 | 022 | D,SC7 | Scratch register 7 |
| 00010011 | 023 | D,SC10 | Scratch register 10 |
| 00010100 | 024 | D,SC11 | Scratch register 11 |
| 00010101 | 025 | D,SC12 | Scratch register 12 |
| 00010110 | 026 | D,SC13 | Scratch register 13 |
| 00010111 | 027 | D,SC14 | Scratch register 14 |
| 00011000 | 030 | D,NONE | No destination |
| 00011001 | 031 | D,IXC | Index counters clear |
| 00011010 | 032 | D,LC | Loop counter |
| 00011011 | 033 | (none) | Unused |
| 00011100 | 034 | (none) | Unused |
| 00011101 | 035 | (none) | Unused |
| 00011110 | 036 | (none) | Unused |
| 00011111 | 037 | ORD,IN/OP | OR destination from instruction/operand |

### Group 001: SPEC (Special Registers)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 00100000 | 040 | D,SPEC,MOD | Modus register |
| 00100001 | 041 | D,SPEC,AIB | ACCP input buffer |
| 00100010 | 042 | D,SPEC,DCADAT | Data cache data |
| 00100011 | 043 | D,SPEC,OC,DP | DPA-part of OC |
| 00100100 | 044 | D,SPEC,OC,AD | NADDR-part of OC |
| 00100101 | 045 | D,SPEC,OC,CO | Control-part of OC |
| 00100110 | 046 | D,SPEC,AC | Address cache |
| 00100111 | 047 | D,SPEC,IC | Instruction cache |
| 00101000 | 050 | D,SPEC,MIB | MIB register |
| 00101001 | 051 | D,SPEC,TRPARM | Trap parameter register |
| 00101010 | 052 | D,SPEC,TRPCLR | Trap clear |
| 00101011 | 053 | D,SPEC,CC | CC register |
| 00101100 | 054 | D,SPEC,LA | LA register |
| 00101101 | 055 | D,SPEC,FLA | Forward LA |
| 00101110 | 056 | D,SPEC,CLDCA | Clear data cache |
| 00101111 | 057 | D,SPEC,CLICA | Clear instruction cache |
| 00110000 | 060 | D,SPEC,CTRACE | Control trace |
| 00110001-00111111 | 061-077 | (none) | Unused |

### Group 01X: MMS (Memory Management System)

The MMS group uses bits 6-5 to select the target:
- 00 (0100) = NOOP (no operation)
- 01 (0101) = DMM only
- 10 (0110) = IMM only
- 11 (0111) = IMM & DMM (both)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 01XX00000 | 100+ | D,xxx,PSTP | PSTP register |
| 01XX00001 | 101+ | D,xxx,PUWP | PUWP register |
| 01XX00010 | 102+ | D,xxx,LA | LA register |
| 01XX00011 | 103+ | D,xxx,WR | WR register |
| 01XX00100 | 104+ | D,xxx,CAP | Capability register |
| 01XX00101 | 105+ | D,xxx,PS | PS register |
| 01XX00110 | 106+ | D,xxx,PHS | PHS register |
| 01XX00111 | 107+ | D,xxx,DOM | DOM register |
| 01XX01000 | 110+ | D,xxx,MEM | Memory register |
| 01XX01001 | 111+ | D,xxx,WTSB | WTSB register |
| 01XX01010 | 112+ | D,xxx,CTSB | CTSB register |
| 01XX01011 | 113+ | D,xxx,CTRP | CTRP register |
| 01XX01110 | 116+ | D,xxx,DIRTY | Dirty register |
| 01XX01111 | 117+ | D,xxx,ADOM | ADOM register |

Where XX = 00 (NOOP), 01 (DMM), 10 (IMM), or 11 (IMM & DMM)

### Group 100: MIC (Microcode Control)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 10000000 | 200 | D,MIC,MISTS | MIC status register |
| 10000001 | 201 | D,MIC,VECT | MIC vector register |
| 10000010 | 202 | D,RFA1 | RF-address register 1 |
| 10000011 | 203 | D,RFA2 | RF-address register 2 |
| 10000100 | 204 | D,MIC,STS | MIC status bits |
| 10000101 | 205 | D,MIC,TE | MIC trap enable |
| 10000110 | 206 | D,MIC,BRK | MIC break |
| 10000111 | 207 | D,MIC,CNT32 | MIC 32-bit counter |
| 10001000 | 210 | D,MIC,RESTU | Restart unit |
| 10001100 | 214 | D,RF1 | SRF via RFA1 |
| 10001101 | 215 | D,RF2 | SRF via RFA2 |
| 10001110 | 216 | D,RF1D | SRF via RFA1, decrement |
| 10001111 | 217 | D,RF2D | SRF via RFA2, decrement |
| 10010000 | 220 | D,SRF0 | SRF word 0 |
| 10010001 | 221 | D,SRF1 | SRF word 1 |
| 10010010 | 222 | D,SRF2 | SRF word 2 |
| 10010011 | 223 | D,SRF3 | SRF word 3 |
| 10010100 | 224 | D,SRF4 | SRF word 4 |
| 10010101 | 225 | D,SRF5 | SRF word 5 |
| 10010110 | 226 | D,SRF6 | SRF word 6 |
| 10010111 | 227 | D,SRF7 | SRF word 7 |
| 10011000 | 230 | D,SRF10 | SRF word 10 |
| 10011001 | 231 | D,SRF11 | SRF word 11 |
| 10011010 | 232 | D,SRF12 | SRF word 12 |
| 10011011 | 233 | D,SRF13 | SRF word 13 |
| 10011100 | 234 | D,SRF14 | SRF word 14 |
| 10011101 | 235 | D,SRF15 | SRF word 15 |
| 10011110 | 236 | D,SRF16 | SRF word 16 |
| 10011111 | 237 | D,SRF17 | SRF word 17 |

### Group 101: IDU (Instruction Decode Unit)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 10100000 | 240 | D,IDU,TE | IDU trap enable |
| 10100001 | 241 | D,IDU,HL | IDU HL register |
| 10100010 | 242 | D,IDU,LL | IDU LL register |
| 10100011 | 243 | D,IDU,LIMC | IDU limit control |
| 10100100 | 244 | D,IDU,CSIT | IDU CSIT register |
| 10100101 | 245 | D,IDU,STS | IDU status register |
| 10100110 | 246 | D,IDU,AREG | IDU address register |
| 10100111 | 247 | D,IDU,IBUF | IDU instruction buffer |

### Group 110: IAC (Instruction Address Control)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 11000001 | 301 | D,IAC,NPC | IAC NPC register |
| 11000010 | 302 | D,IAC,P | IAC Program counter |
| 11000100 | 304 | D,IAC,L | IAC Link register |
| 11000101 | 305 | D,IAC,SUML | Sum transferred to IAC Y register |
| 11001000 | 310 | D,IAC,DPA | IAC DPA register |
| 11001101 | 315 | D,IAC,CLKNPC | Clock NPC |
| 11001110 | 316 | D,IAC,CLKP | Clock P |
| 11001111 | 317 | D,IAC,CLKSP | Clock SP |

### Group 111: DAC (Data Address Control)

| Binary | Octal | Mnemonic | Description |
|--------|-------|----------|-------------|
| 11100010 | 342 | D,DAC,R | DAC Record register |
| 11100100 | 344 | D,DAC,B | DAC Base register |
| 11100101 | 345 | D,DAC,SUMB | Sum transferred to DAC B register |
| 11101000 | 350 | D,DAC,DPA | DAC DPA register |

---

## Bits 75-72: Status Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0000 | (hold) | Hold status unchanged |
| 0001 | K,ONE | Set K (flag) = 1 |
| 0010 | K,ZRO | Clear K (flag) = 0 |
| 0011 | K,1IFZ | Set K = 1 if MZRO is true, DR = 0 |
| 0100 | ST,SAVA | Save status from ALU operation |
| 0101 | ST,SAVC | Save status from ALU operation in compare |
| 0110 | ST,SAVF | Save status from floating operation |
| 0111 | ST,SAVB | Save status from BCD operation |
| 1000 | ST,LOAD | Load F-bus to ALU status register |
| 1001 | ST,SAVM | Save mixed status (overflow from AAP, Z/S from ALU) |
| 1010 | (none) | Unused |
| 1011 | (none) | Unused |
| 1100 | ST,ACCA | Save and accumulate ALU status |
| 1101 | ST,ACCM | Save and accumulate mixed status |
| 1110 | ST,ACCF | Save and accumulate AAP status |
| 1111 | TE,ALU,LOAD | Load ALU trap enable bits |

---

## Bit 71: IXC Incr (Index Counter Increment)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | hold | No index counter adjustment |
| 1 | IXADJ | Increment index counters |

---

## Bit 70: Lc Decr (Loop Counter Decrement)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | hold | No loop counter decrement |
| 1 | LCDECR | Decrement loop counter |

---

## Bits 69-60: Seq. Control (Group)

This is a group containing subfields for microprogram sequence control.

**Notes:**
- `C,SEQ` is implicit when using any `F,<seq>` or `F,<stack>` command
- Test condition is selected in current microinstruction, but result from previous microinstruction affects the selected condition
- **Pipelining:** The true path is always prefetched. For optimum speed, the true path should contain a JMP command. If this is not possible, use `INVSEQ` to invert the test condition
- `INVSEQ` has no effect on conditional ALU operations (only affects sequence control)
- `EXUC` allows executing microinstructions in the pipeline even when the pipeline is broken (to prevent code duplication)

### Cond.Seq (bit 69) - Enable Conditional Sequence

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | Use true sequence only |
| 1 | C,SEQ | Select sequence based on condition |

### True (bits 68-65) - Sequence Control When True

This field is split into two sub-parts. Prefix is "T,".

#### Sequence Type (bits 68-67)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | T,JMP | Jump to address field (1 cycle) |
| 01 | T,JMPREL | Jump relative / vector (2 cycles) |
| 10 | T,RETURN | Return to sequencer stack address (2 cycles) |
| 11 | T,NEXT | Next microinstruction (2 cycles) |

#### Stack Control (bits 66-65)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | T,HOLD | Leave stack unchanged |
| 01 | T,POP | Pop stack, word 1 used as return address |
| 10 | T,LOAD | Word 1 = current address + 1, rest unchanged |
| 11 | T,PUSH | Push current address + 1, stack shifts down |

### False (bits 64-61) - Sequence Control When False

Same structure as True field, with "F," prefix.

#### Sequence Type (bits 64-63)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | F,JMP | Jump to address field (1 cycle) |
| 01 | F,JMPREL | Jump relative / vector (2 cycles) |
| 10 | F,RETURN | Return to sequencer stack address (2 cycles) |
| 11 | F,NEXT | Next microinstruction (2 cycles) |

#### Stack Control (bits 62-61)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | F,HOLD | Leave stack unchanged |
| 01 | F,POP | Pop stack, word 1 used as return address |
| 10 | F,LOAD | Word 1 = current address + 1, rest unchanged |
| 11 | F,PUSH | Push current address + 1, stack shifts down |

**Note:** JMP takes 1 cycle, NEXT/RETURN/JMPREL take 2 cycles. Prefer JMP for efficiency.

**NEXT* Assembler Shorthand:** The syntax `NEXT*` causes the assembler to generate `JMP *+1` (jump to current address + 1). This uses the absolute address field (bits 31-16) and provides 1-cycle performance. If the argument field is already used for other values, the assembler reports: "ORING REJECTED DUE TO OVERLAPPING MNEMONICS".

### Invsqc (bit 60) - Invert Sequence Condition

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | Use condition as-is |
| 1 | INVSEQ | Invert test condition for sequence selection |

**INVSEQ Optimization Pattern:**

Since the true path is always prefetched and JMP is faster (1 cycle vs 2), use INVSEQ to put JMP on the common execution path.

Example: `C,SEQ F,HOLD F,NEXT INVSEQ COND,MZRO JMP HOLD m;`

| MZRO Result | Inverted | Path Taken | Action |
|-------------|----------|------------|--------|
| Result = 0 | true → false | F,NEXT | Go to next (pipeline broken, slower) |
| Result ≠ 0 | false → true | JMP m | Jump to m (pipeline intact, faster) |

This places JMP on the common path (result ≠ 0) for optimal performance.

---

## Bit 59: Csave (Save Test Condition)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | hold | Don't save condition |
| 1 | CSAVE | Save condition to stack |

---

## Bits 58-53: Testobject (Test Condition Select)

Test conditions are selected with `COND,<condition>` syntax. The M prefix indicates micro-status (from current ALU operation) vs main status register (S1). Use `INVSEQ` (bit 60) to invert the condition for sequence control.

### Group 000xxx - Compound Conditions (ALU)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 000000 | COND,MSEXO | Sign XOR overflow from ALU |
| 000001 | COND,MSORZ | Sign OR zero from ALU |
| 000010 | COND,SORZ | Sign OR zero from status (S1) |
| 000011 | COND,MCNZ | Carry AND NOT zero from ALU |
| 000100 | (none) | Unused |
| 000101 | (none) | Unused |
| 000110 | (none) | Unused |
| 000111 | (none) | Unused |

### Group 001xxx - Basic Conditions (ALU/Status)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 001000 | COND,CNZ | Carry AND NOT zero from status (S1) |
| 001001 | COND,MZRO | Zero from ALU operation |
| 001010 | COND,MCRY | Carry from ALU operation |
| 001011 | COND,MSGN | Sign from ALU operation |
| 001100 | (none) | Unused |
| 001101 | (none) | Unused |
| 001110 | (none) | Unused |
| 001111 | (none) | Unused |

### Group 010xxx - Status Register Conditions

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 010000 | COND,MOVFL | Overflow from ALU operation |
| 010001 | COND,ZRO | Zero from status register (S1) |
| 010010 | COND,CRY | Carry from status register (S1) |
| 010011 | COND,SGN | Sign from status register (S1) |
| 010100 | COND,K | K flag from status (S1) |
| 010101 | COND,OVFL | Overflow from status register (S1) |
| 010110 | (none) | Unused |
| 010111 | (none) | Unused |

### Group 011xxx - Miscellaneous Conditions

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 011000 | COND,PARITY | Odd parity of LSB of F-bus |
| 011001 | COND,Q0 | Q-register bit 0 |
| 011010 | COND,SAVC1 | Saved condition 1 / top of stack |
| 011011 | COND,SAVC2 | Saved condition 2 / bottom of stack |
| 011100 | COND,LCZ | Loop counter = 0 |
| 011101 | (none) | Unused |
| 011110 | (none) | Unused |
| 011111 | (none) | Unused |

### Group 100xxx - Instruction Type Conditions

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 100000 | COND,ENTER | ENTF/ENTM/ENTT instruction |
| 100001 | (none) | Unused |
| 100010 | COND,DATOP | Data source/destination |
| 100011 | COND,CONOP | Constant source/destination |
| 100100 | COND,PDONE | Part done (restart) |
| 100101 | COND,MFS | Sign from floating AAP |

### Group 101xxx - AAP Conditions

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 101000 | COND,MFO | Overflow from floating AAP |
| 101001 | COND,MFU | Underflow from floating AAP |
| 101010 | COND,MDZ | Divide by zero from AAP |
| 101011 | COND,MIVO | Invalid operation from BCD AAP |
| 101100 | COND,MBO | Overflow from BCD AAP |

### Group 110xxx - RF Address Conditions

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 110000 | COND,RF1OCT | Zero in RF-address 1 bits 0-2 |
| 110001 | COND,RF2OCT | Zero in RF-address 2 bits 0-2 |

### Group 111xxx - Instruction Decode Conditions

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 111000 | COND,GOOPS | Get type is G,OOPS |
| 111001 | COND,AQSLZ | Q0 for ALU, LCZ for sequencer |
| 111010 | (none) | Unused |
| 111011 | COND,IRALT | First operand is alt-addressed |
| 111100 | COND,CALL | CALL instruction |
| 111101 | COND,ENTM | ENTM instruction |
| 111110 | COND,ENTT | ENTT instruction |
| 111111 | COND,JUMPG | JUMPG instruction |

---

## Bits 52-44: IAC Control (Group)

This is a group containing three subgroups for instruction address control.

### ABR (bits 52-51) - Alternative Branch Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | (none) | No alternative branch |
| 01 | ABR,NEXT | Alternative branch = current + length |
| 10 | ABR,NPCREL | Alternative = NPC + displacement |
| 11 | ABR,NEXTL | Alternative branch = current + length -> L register |

### TBC (bits 50-48) - Target Branch Cache Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 000 | TBC,NEXT | Cache write next instruction stream address |
| 001 | TBC,SUBR | Cache write subroutine address |
| 010 | TBC,L | Cache write link register (ASSUMING) |
| 011 | TBC,NPCREL | Cache write NPC relative jump address |
| 100 | TBC,PREL | Cache write P relative jump address |
| 101 | (none) |  |
| 110 | TBC,INCILAR | ILAR + 4 -> ILAR |
| 111 | TBC,NOOP | No TBC operation |

### Get (bits 47-44) - Instruction/Operand Fetch Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0000 | (none) | No fetch operation |
| 0001 | CLEAR | Clear fetch state |
| 0010 | (none) | Unused |
| 0011 | ISAMP | Instruction sample |
| 0100 | G,OOPS | Fetch next instruction and first operand specifier |
| 0101 | G,OOPS,T | Fetch next instruction and operand specifier for preferred branch, break if test condition is true |
| 0110 | G,OOPS,F | Fetch next instruction and operand specifier for preferred branch, break if test condition is false |
| 0111 | G,COOPS | Fetch enter instruction and operand specifier after a CALL or CALLG instruction |
| 1000 | G,DIR1 | Fetch a one-byte direct operand |
| 1001 | G,DIR2 | Fetch a two-byte direct operand |
| 1010 | G,OPS | Fetch next operand specifier |
| 1011 | G,DIR4 | Fetch a four-byte direct operand |
| 1100 | (none) | Unused |
| 1101 | G,OPSTRD | Fetch second operand specifier for string operations |
| 1110 | G,TOOPS | Fetch next instruction to check for Call, Entm, Entt and Jumpg |
| 1111 | LOADLA | Load LA register |

---

## Bit 43: Stop

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | Continue execution |
| 1 | STOP | Stop microprogram execution |

---

## Bit 42: AAPSync

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | Normal operation |
| 1 | AAPSYNC | Wait for AAP ready |

---

## Bits 41-32: D-Mem Control (Group)

This is a group containing multiple subgroups:

### Memory (bit 41 + bits 34-32) - 4 bits (SPLIT FIELD)

**Note:** This field is split - bit 41 is the MSB, bits 34-32 are the lower 3 bits.

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0000 | (none) | No data request |
| 0001 | LADDR | LADDR request |
| 0010 | WR,POF | Write physical with MMS |
| 0011 | CCD | CLEAR CACHE AND DUMP DIRTY |
| 0100 | WR,PHYS | Write physical segment |
| 0101 | WR,DOM | Write in normal domain |
| 0110 | WR,ADOM | Write in alternative domain |
| 0111 | WRITE | Write data memory |
| 1000 | QVACC | QVACC |
| 1001 | RD,POF | Read physical with MMS |
| 1010 | (none) | Unused |
| 1011 | RD,PX | Read with write permit required |
| 1100 | RD,PHYS | Read physical segment |
| 1101 | RD,DOM | Read in normal domain |
| 1110 | RD,ADOM | Read in alternative domain |
| 1111 | READ | Read data memory |

### Ad.Arti.Con (bit 40) - Address Arithmetic Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | OCA | Operand Cache controlled |
| 1 | MICRO | Microcode controlled |

### EA Save (bits 39-38)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | (none) | No EA save |
| 01 | EA1SAVE | Save address in EA1 and EA0 |
| 10 | EA2SAVE | Save address in EA2 and EA0 |
| 11 | EA3SAVE | Save address in EA3 and EA0 |

### Memot (bit 37)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (req) | Request |
| 1 | C,MEMOT | MEMORY REQUEST IF DATA-OPERAND |

### Spare (bit 36)

Not defined.

### Adact (bit 35)

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | hold | Hold |
| 1 | ADACT | Address arithmetic activate |

---

## Bits 31-0: Argument Fields (Overlapping)

These bits have multiple overlapping interpretations depending on instruction type:

### Long Argument (bits 31-0) - 32 bits
Full 32-bit immediate value when needed.

### Absolute Address (bits 31-16) - 16 bits
Direct microprogram jump target address.

### Short Argument (bits 15-0) - 16 bits
16-bit immediate value. Sign extended to 32 bits during execution.

Access: `A,SARG` (A-operand, sign extended)

### Mini Argument (bits 7-0) - 8 bits
8-bit immediate value. Sign extended to 32 bits during execution.

Access mnemonics:
- `A,MARG` - Mini argument on A-operand bus
- `AA,MARG` - Mini argument as Address A-operand
- `AB,MARG` - Mini argument as Address B-operand

---

## Bits 15-6: Data Addr Con. (Address Arithmetic Control)

### Aa (bits 15-13) - Address A-operand

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 000 | AA,0 | ADDRESS A OPERAND IS ZERO |
| 001 | AA,MARG | ADDRESS A OPERAND IS MINIARGUMENT |
| 010 | AA,DISP | ADDRESS A OPERAND IS DISPLACEMENT |
| 011 | AA,DATA | ADDRESS A OPERAND IS DATA REGISTER |
| 100 | AA,EAO | ADDRESS A OPERAND IS EAO REGISTER |
| 101 | AA,EA1 | ADDRESS A OPERAND IS EA1 REGISTER |
| 110 | AA,EA2 | ADDRESS A OPERAND IS EA2 REGISTER |
| 111 | AA,EA3 | ADDRESS A OPERAND IS EA3 REGISTER |

### Ab (bits 12-9) - Address B-operand

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0000 | AB,0 | ADDRESS B OPERAND IS ZERO |
| 0001 | AB,MARG | ADDRESS B OPERAND IS MINIARGUMENT |
| 0010 | AB,B | ADDRESS B OPERAND IS BASE (B) REGISTER |
| 0011 | AB,R | ADDRESS B OPERAND IS RECORD (R) REGISTER |
| 0100 | AB,IX1 | ADDRESS B OPERAND IS INDEX REGISTER X1 |
| 0101 | AB,IX2 | ADDRESS B OPERAND IS INDEX REGISTER X2 |
| 0110 | AB,IX3 | ADDRESS B OPERAND IS INDEX REGISTER X3 |
| 0111 | AB,IX4 | ADDRESS B OPERAND IS INDEX REGISTER X4 |
| 1000 | AB,CMBRET | RETURN FROM CMISS U-CODE |
| 1001 | AB,ADR | EAO IF RECYCLE NOT NECESSARY |
| 1010 | AB,EA1DIR | EA1 IF RECYCLE NOT NECESSARY |
| 1011 | AB,ADR+4 | PREVIOUS ADDRESS +4 IF RECYCLE NOT NECESSARY |
| 1100 | AB,X1ORS | DESC(X)(I1), I1 SCALED ACCORDING TO INSTRUCTION |
| 1101 | AB,X2ORS | DESC(X)(I2), I2 SCALED ACCORDING TO INSTRUCTION |
| 1110 | AB,X3ORS | DESC(X)(I3), I3 SCALED ACCORDING TO INSTRUCTION |
| 1111 | AB,X4ORS | DESC(X)(I4), I4 SCALED ACCORDING TO INSTRUCTION |

### Scal (bits 8-6) - Index Scaling

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 000 | IX*1 | SCALING = *1 (Byte) |
| 001 | IX*2 | SCALING = *2 (Halfword) |
| 010 | IX*4 | SCALING = *4 (Word/Single float) |
| 011 | IX*8 | SCALING = *8 (Double float) |
| 100 | IX/8 | SCALING = /8 (Bit) |
| 101 | IX*16 | SCALING = *16 (80-bit floating) |
| 110 | (none) | Unused |
| 111 | (none) | Unused |

---

## Bits 5-0: ORCON (OR Logic Control)

See reference manual chapter 4.2 "OR-LOGIC CONTROL" for detailed usage.

### ORCON.N (bit 5) - Next Cycle Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | OR-control for current cycle |
| 1 | OR.N | OR-control is for next cycle |

### ORCON.E (bit 4) - Extension Register Control

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 0 | (none) | If RegOp: use X (index) or A (float most) |
| 1 | OR,NE | Enable extension register in next micro cycle |

### ORCON.A (bits 3-2) - ORA Source Select

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | ORA,IN | OR A-operand in current from instruction |
| 01 | ORA,OP | OR A-operand in current from operand specifier |
| 10 | (none) | No ORA |
| 11 | ORA,ALTEN | OR A-operand (in next) from string source operand |

### ORCON.D (bits 1-0) - ORD Destination Select

| Value | Mnemonic | Description |
|-------|----------|-------------|
| 00 | ORD,IN | OR destination in current from instruction |
| 01 | ORD,OP | OR destination in current from operand specifier |
| 10 | ORD,OP1 | OR destination (in next) from first operand specifier |
| 11 | ORD,ALTEN | OR destination (in next) from string dest. operand |

---

## Context Registers

These registers are saved/restored on context switch:

| Register | Abbreviation | Location |
|----------|--------------|----------|
| Program counter | P | IAC |
| Link register | L | IAC |
| Base register | B | DAC |
| Record register | R | DAC |
| Index registers | X1-X4 | WRF |
| Floating most | A1-A4 | WRF |
| Floating least | E1-E4 | WRF |
| Status register | S1+S2 | Various |
| Process register | PS | DMM+IMM |
| Current domain | CED | DMM+IMM |
| Alternative domain | CAD | DMM+IMM |
| Context scratch | SC1+SC2 | WRF |

---

## Field Extraction Code (Python)

```python
def extract_bits(val: int, high: int, low: int) -> int:
    """Extract bits from high to low (inclusive) from a 128-bit value."""
    mask = (1 << (high - low + 1)) - 1
    return (val >> low) & mask

# Read 16 bytes as big-endian 128-bit integer
val = int.from_bytes(word_bytes, 'big')

# Example extractions:
alu_true = extract_bits(val, 127, 122)      # ALU function (true)
alu_false = extract_bits(val, 121, 116)     # ALU function (false)
exuc = extract_bits(val, 115, 115)          # Execute unconditional
q_ctrl = extract_bits(val, 113, 111)        # Q-register control
aap_ctrl = extract_bits(val, 110, 103)      # AAP control
timing = extract_bits(val, 102, 101)        # Timing control
datatype = extract_bits(val, 100, 98)       # Data type
a_op = extract_bits(val, 96, 89)            # A-operand select
b_op = extract_bits(val, 88, 84)            # B-operand select
dest = extract_bits(val, 83, 76)            # Destination select
status = extract_bits(val, 75, 72)          # Status control
seq_true = extract_bits(val, 68, 65)        # Sequence (true)
seq_false = extract_bits(val, 64, 61)       # Sequence (false)
cond = extract_bits(val, 58, 53)            # Test condition
fetch = extract_bits(val, 47, 44)           # Fetch control
stop = extract_bits(val, 43, 43)            # Stop
aapsync = extract_bits(val, 42, 42)         # AAP sync
memory = (extract_bits(val, 41, 41) << 3) | extract_bits(val, 34, 32)  # Memory (split)
ad_arti_con = extract_bits(val, 40, 40)     # Address arithmetic control
ea_save = extract_bits(val, 39, 38)         # EA save
memot = extract_bits(val, 37, 37)           # Memot
adact = extract_bits(val, 35, 35)           # ADACT
abs_addr = extract_bits(val, 31, 16)        # Absolute address
aa_op = extract_bits(val, 15, 13)           # Address A-operand (Aa)
ab_op = extract_bits(val, 12, 9)            # Address B-operand (Ab)
scal = extract_bits(val, 8, 6)              # Scaling
orcon_n = extract_bits(val, 5, 5)           # ORCON.N
orcon_e = extract_bits(val, 4, 4)           # ORCON.E
orcon_a = extract_bits(val, 3, 2)           # ORCON.A
orcon_d = extract_bits(val, 1, 0)           # ORCON.D
```

---

## Notes

1. All addresses in label file are **octal**
2. Data is stored **big-endian** (byte 0 = bits 127-120)
3. JMP is faster than NEXT (1 vs 2 cycles)
4. EXUC allows "sneak" instructions during pipeline breaks
5. The conditional model allows same microcode for true/false paths
6. AAP operations require AAPSYNC to retrieve results
7. SRF writes have 2-cycle delay before read-back
8. Memory field is split: bit 41 is MSB, bits 34-32 are lower 3 bits
9. Fields marked (TBD) are awaiting confirmation during interview

---

## Appendix: Alphabetical List of Mnemonic Symbols

This table is from ND-05.022.1 reference manual Appendix A. The HEX Value column shows the 128-bit microcode value for each mnemonic (to be filled in during validation).

**HEX Value Encoding:**

Each hex value is 32 characters representing the 128-bit microcode word. The bit positions are:
- **ALU TRUE** (bits 127-124): First hex digit - ALU operation when condition is true
- **CARRY TRUE** (bits 123-122): Part of second hex digit - Carry select for true path
- **ALU FALSE** (bits 121-118): Second/third hex digits - ALU operation when condition is false
- **CARRY FALSE** (bits 117-116): Part of third hex digit - Carry select for false path

Composite mnemonics (like ALU,A-B) combine a base ALU operation with a carry selection.

| # | Mnemonic | Description | HEX Value |
|---|----------|-------------|-----------|
| 1 | ALU,FZRO | FORCE ZERO ALU OUTPUT | 00000000000000000000000000000000 |
| 2 | ALU,ADIRC | ALU OUTPUT COMPLEMENTED | 10000000000000000000000000000000 |
| 3 | ALU,AND | LOGICAL AND OF A AND B | 20000000000000000000000000000000 |
| 4 | ALU,ANDCB | LOGICAL AND OF A AND B COMPLEMENTED | 30000000000000000000000000000000 |
| 5 | ALU,A | A OPERAND DIRECT THROUGH THE ALU | 40000000000000000000000000000000 |
| 6 | ALU,A+1 | ADD 1 TO A OPERAND (composite: ALU,A + CRY,ONE) | 44000000000000000000000000000000 |
| 7 | ALU,XOR | LOGICAL EXCLUSIVE OR OF A AND B | 50000000000000000000000000000000 |
| 8 | ALU,ANDCA | LOGICAL AND OF A COMPLEMENTED AND B | 60000000000000000000000000000000 |
| 9 | ALU,OR | LOGICAL OR OF A AND B | 70000000000000000000000000000000 |
| 10 | ALU,A-1 | DECREMENT A OPERAND | 80000000000000000000000000000000 |
| 11 | ALU,A,/2 | FBUS = ALU.OUTPUT/2; FBUS(31) = CARRY | 90000000000000000000000000000000 |
| 12 | ALU,A-B | A MINUS B (composite: ALU,A-B + CRY,ONE) | A4000000000000000000000000000000 |
| 13 | ALU,A-B-1 | A MINUS B OPERAND MINUS 1 (base A-B op, carry=0) | A0000000000000000000000000000000 |
| 14 | ALU,A-B-1+C | A MINUS B MINUS 1 + STATUS CARRY (composite: ALU,A-B + CRY,C) | A8000000000000000000000000000000 |
| 15 | ALU,A-B,*2 | (A-B)*2 (composite: ALU,A-B,*2 + CRY,ONE) | B4000000000000000000000000000000 |
| 16 | ALU,A-B-1,*2 | (A-B-1)*2 (base A-B,*2 op, carry=0) | B0000000000000000000000000000000 |
| 17 | ALU,A+B,/2 | FBUS = ALU.OUTPUT/2; FBUS(31) = CARRY | C0000000000000000000000000000000 |
| 18 | ALU,A+B | A OPERAND ADDED B OPERAND | D0000000000000000000000000000000 |
| 19 | ALU,A+B+1 | A + B + 1 (composite: ALU,A+B + CRY,ONE) | D4000000000000000000000000000000 |
| 20 | ALU,B-A | B MINUS A (composite: ALU,B-A + CRY,ONE) | E4000000000000000000000000000000 |
| 21 | ALU,B-A-1 | B MINUS A MINUS 1 (base B-A op, carry=0) | E0000000000000000000000000000000 |
| 22 | ALU,A+B,*2 | FBUS = ALU.OUTPUT*2; FBUS(00) = 0 | F0000000000000000000000000000000 |
| 23 | CRY,ONE | ONE AS CARRY (TRUE path) | 04000000000000000000000000000000 |
| 24 | CRY,C | C FROM STATUS AS CARRY (TRUE path) | 08000000000000000000000000000000 |
| 25 | CRY,MC | MICRO CARRY AS CARRY (TRUE path) | 0C000000000000000000000000000000 |
| 26 | ALUF,FZRO | FORCE ZERO ALU OUTPUT (FALSE path) | 00000000000000000000000000000000 |
| 27 | ALUF,ADRC | ALU OUTPUT COMPLEMENTED (FALSE path) | 00400000000000000000000000000000 |
| 28 | ALUF,AND | LOGICAL AND OF A AND B (FALSE path) | 00800000000000000000000000000000 |
| 29 | ALUF,ANDCB | LOGICAL AND OF A AND B COMPLEMENTED (FALSE path) | 00C00000000000000000000000000000 |
| 30 | ALUF,A | A OPERAND DIRECT THROUGH THE ALU (FALSE path) | 01000000000000000000000000000000 |
| 31 | ALUF,A+1 | ADD 1 TO A OPERAND (FALSE, composite: ALUF,A + CRYF,ONE) | 01100000000000000000000000000000 |
| 32 | ALUF,XOR | LOGICAL EXCLUSIVE OR OF A AND B (FALSE path) | 01400000000000000000000000000000 |
| 33 | ALUF,ANDCA | LOGICAL AND OF A COMPLEMENTED AND B (FALSE path) | 01800000000000000000000000000000 |
| 34 | ALUF,OR | LOGICAL OR OF A AND B (FALSE path) | 01C00000000000000000000000000000 |
| 35 | ALUF,A-1 | DECREMENT A OPERAND (FALSE path) | 02000000000000000000000000000000 |
| 36 | ALUF,A,/2 | FBUS = ALU.OUTPUT/2 (FALSE path) | 02400000000000000000000000000000 |
| 37 | ALUF,A-B | A MINUS B (FALSE, composite: ALUF,A-B + CRYF,ONE) | 02900000000000000000000000000000 |
| 38 | ALUF,A-B-1 | A MINUS B MINUS 1 (FALSE, base op, carry=0) | 02800000000000000000000000000000 |
| 39 | ALUF,A-B-1+C | A-B-1 + STATUS CARRY (FALSE, composite: ALUF,A-B + CRYF,C) | 02A00000000000000000000000000000 |
| 40 | ALUF,A-B,*2 | (A-B)*2 (FALSE, composite: ALUF,A-B,*2 + CRYF,ONE) | 02D00000000000000000000000000000 |
| 41 | ALUF,A-B-1,*2 | (A-B-1)*2 (FALSE, base op, carry=0) | 02C00000000000000000000000000000 |
| 42 | ALUF,A+B,/2 | FBUS = ALU.OUTPUT/2 (FALSE path) | 03000000000000000000000000000000 |
| 43 | ALUF,A+B | A OPERAND ADDED B OPERAND (FALSE path) | 03400000000000000000000000000000 |
| 44 | ALUF,A+B+1 | A + B + 1 (FALSE, composite: ALUF,A+B + CRYF,ONE) | 03500000000000000000000000000000 |
| 45 | ALUF,B-A | B MINUS A (FALSE, composite: ALUF,B-A + CRYF,ONE) | 03900000000000000000000000000000 |
| 46 | ALUF,B-A-1 | B MINUS A MINUS 1 (FALSE, base op, carry=0) | 03800000000000000000000000000000 |
| 47 | ALUF,B-A-1+C | B-A-1 + STATUS CARRY (FALSE, composite: ALUF,B-A + CRYF,C) | 03A00000000000000000000000000000 |
| 48 | ALUF,A+B,*2 | FBUS = ALU.OUTPUT*2 (FALSE path) | 03C00000000000000000000000000000 |
| 49 | CRYF,ONE | ONE AS CARRY (FALSE path) | 00100000000000000000000000000000 |
| 50 | CRYF,C | C FROM STATUS AS CARRY (FALSE path) | 00200000000000000000000000000000 |
| 51 | CRYF,MC | MICRO CARRY AS CARRY (FALSE path) | 00300000000000000000000000000000 |
