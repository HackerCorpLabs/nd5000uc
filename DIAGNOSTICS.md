# DIAGNOSTICS.md — every trace/instrument switch across the ND emulators

**Full path:** `E:\Dev\Ronny\ND5000UC\DIAGNOSTICS.md`
**Last verified:** 2026-08-08. Each of these was built once and re-discovered several times —
check here BEFORE building a new instrument.

## Legacy C# ND-500 (`Emulated.HW`, env vars read by the CPU/tests)

| Switch | What it does | When to use |
|---|---|---|
| `ND500_FRAME_LOG=<file>` | ordered ENTS/RET frame log, same text as the C side | FIRST tool for any behaviour divergence vs nd500x — diff to first divergence (~100k lines/compile). Strip CRLF; use fi.StartAddress not PC; ~73 benign console-poll RET hunks expected |
| `ND500_TRACE_FILE` + `ND500_TRACE_LO/HI` | full instruction trace, RANGE-GATED by PC | only around a found divergence — ungated reached 9 GB |
| `ND500_KEEP_SCRATCH=1` | TestMON_CompilePath keeps its scratch tree | when the BYTES are wrong rather than the behaviour |

## nd500x C (WSL `~/repos/nd500x`)

| Switch | What it does |
|---|---|
| `ND500X_FRAMELOG=1` | the C twin of ND500_FRAME_LOG (Ents.c/Ret.c) |
| `ND500X_MONLOG=1` | MON-call trace — names every OPEN/WFILE/SMAX/CLOSE |
| `ND500X_LOADDBG=1` | DOM loader segment placement |
| `ND500X_INITLOG=1` | INIT stack setup |
| `ND500X_NO_DEMAND_SEGMENTS=1` | turn off demand segment allocation |
| `--trace-file <path>` | full ordered instruction trace (~583 MB/compile) |

## Microword CpuND5000 (NuGet tests)

| Switch | What it does |
|---|---|
| `ND5000_DIFF_FILE=<corpus basename>` | Sweep dumps one file's diverging cases |
| `ND5000_TRACE_FILE` + `ND5000_TRACE_NAME` | Sweep traces one named vector |
| `CpuND500.MpmActivityTrace` (in code) | MPM access ring buffer with PC + I/D space |
| Sweep gate baseline | match=22330 diverge=1638 — regression SCREAMS |

## ACCP 68000 machine (`Machines.Accp`, in-code instruments, off by default)

| Switch | What it does |
|---|---|
| `AccpMachine.WatchWordAddress` → `WatchWordHits` | one 16-bit cell: old/new value, instruction count, retiring PC |
| `AccpMachine.TrapPcAddress` + `TrapFrameOffset` → `TrapPcHits` | D0/A6/frame word when a chosen instruction retires — for stack-frame values with no fixed address |
| `Nd5000ControlStoreLink` counters | MirLoads / MicrowordsWritten / CommitsFromLatch-Staging-Ring / StrobeCommands / PerformHalfwordCounts (NOTE: halfword discriminator currently mis-measures — task open) |
| Firmware fixture | `Nd5000CsaFailureTraceTests.cs` — the ~20-second measured-not-decoded pattern |

## Debug protocols

- RetroCore DAP: TCP port 4711 (skill `retrocore-dap-mcp`); nd500x DAP: `--dap [port]`, default 4500.
- Real machines: retroterm MCP (`terminal_connlist` has the ports). Never hand-roll telnet.
