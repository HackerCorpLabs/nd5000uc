# ND-5000 Microcode Disassembler

A web-based disassembler and analysis tool for Norsk Data ND-5000 series minicomputer microcode.

**Live Demo:** https://hackercorplabs.github.io/nd5000uc/

![ND-5000 Microcode Disassembler](docs/microcode-definition.png)

## Overview

The ND-5000 series was a family of 32-bit minicomputers manufactured by Norsk Data in the 1980s. This tool allows researchers and retrocomputing enthusiasts to explore and analyze the microcode that controlled these machines at the lowest level.

Each microcode word is 128 bits wide, controlling the ALU, registers, memory bus, sequencer, and other CPU components in a single cycle.

## Features

### Disassembly View
- Full disassembly of 128-bit microcode words into human-readable mnemonics
- Support for multiple microcode versions: ND-5200, ND-5500, ND-5700, ND-5800
- Address labels from original source files when available
- Octal addressing (native to ND systems)

### Interactive Analysis
- Click any instruction to see detailed bit-level breakdown
- Visual bit field display showing all 128 bits organized by function
- Hover tooltips explaining each mnemonic
- Clickable address references for navigation

### Microcode Reference
- Interactive 128-bit field diagram
- Complete documentation of all field values and mnemonics
- Searchable reference for finding specific operations
- Field groups: ALU, Q-Register, AAP, Timing, Operands, Status, Sequencer, IAC, Memory, Address

### Export Options
- Text format (.txt)
- Markdown format (.md)
- PDF export

### User Interface
- Dark/light theme toggle
- Paginated view with configurable page size
- Search by label name
- Jump to octal address
- Show/hide raw hex values

## Included Microcode Files

| File | Model | Description |
|------|-------|-------------|
| MICRO-5800-B30 | ND-5800 | Latest 5800 microcode with labels |
| MICRO-5800-B29 | ND-5800 | Previous revision with labels |
| MICRO-5800-A30 | ND-5800 | A-version with labels |
| MICRO-5800-A29 | ND-5800 | A-version previous revision |
| MICRO-5800-M27 | ND-5800 | Earlier version |
| MICRO-5700-M27 | ND-5700 | ND-5700 microcode |
| MICRO-5500-M27 | ND-5500 | ND-5500 microcode |
| MICRO-5200-M27 | ND-5200 | ND-5200 microcode |

## Technical Details

### Microcode Word Format (128 bits)

```
Bits 127-122: ALU operation (true condition)
Bits 121-116: ALU operation (false condition)
Bits 115:     Execute unconditional
Bits 114:     Condition select for ALU
Bits 113-111: Q register operation
Bits 110-103: Address Adder (AAP) control
Bits 102-101: Timing/cycle control
Bits 100-98:  Data type
Bits 97:      OR enable
Bits 96-89:   A operand select
Bits 88-84:   B operand select
Bits 83-76:   Destination select
Bits 75-72:   Status register control
Bits 71:      Index counter increment
Bits 70:      Loop counter decrement
Bits 69:      Condition select for sequencer
Bits 68-65:   Sequencer operation (true)
Bits 64-61:   Sequencer operation (false)
Bits 60:      Invert sequencer condition
Bits 59:      Carry save
Bits 58-53:   Test object select
Bits 52-51:   ABR control
Bits 50-48:   TBC control
Bits 47-44:   GET operation
Bits 43:      Stop
Bits 42:      AAP sync
Bits 41-32:   Memory control
Bits 31-16:   Absolute address (16-bit)
Bits 15-13:   AA field
Bits 12-9:    AB field
Bits 8-6:     Scale
Bits 5-0:     OR constant
```

## Reference Documentation

The `manual/` directory contains scanned documentation from Norsk Data:

- **ND-05.022.1** - ND-5000 Microprogram Guide: Primary reference for microcode programming
- **ND-05.020.01** - ND-5000 Hardware Description: CPU architecture and register details

## Development

This is a single-file web application with no build process or dependencies. To modify:

1. Edit `docs/index.html`
2. Test locally by opening in a browser
3. Push to `main` branch to deploy to GitHub Pages

The microcode field definitions are in `docs/microcode-5000-def.json`.

## Historical Context

Norsk Data was a Norwegian computer manufacturer that produced minicomputers from 1967 to 1992. The ND-5000 series represented their most advanced 32-bit architecture, used in scientific computing, telecommunications, and business applications throughout Scandinavia.

The microcode in these systems implemented the ND-500 instruction set architecture through horizontal microprogramming, where each 128-bit control word directly controlled the CPU's data paths and control signals.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Original microcode and documentation from Norsk Data A.S
- Microcode binary files preserved from historical ND disk images
- Reference manual scans from the retrocomputing community
