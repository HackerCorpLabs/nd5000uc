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
| `ND500_MON_LOG=1` | TestMON_CompilePath: MON-call log to `%LocalAppData%\trace\file-trace.txt` (APPEND - delete first) | the C# twin of ND500X_MONLOG, captured at Device level (whole MON surface). Host-side MON writes are invisible to the instruction trace - this is the instrument that sees them. NOTE the C monlog prints numbers in OCTAL (SETBS 4000B=2048, WFILE 10000B=4096) |
| `ND500_WATCH_ADDR=<hex>` | one-byte data watchpoint in CpuND500: logs every read (8/16-bit) and write (8/16/32) covering that byte, with value+PC, at Machine level | THE tool for mem-to-mem carry chains: when PC and register streams are identical but a memory cell differs, walk write-hops cell by cell. Needs ND500_MON_LOG=1 to capture. Found SMOVE, SLOCA, W HCONV and the write-back sharing bug (task #9) |
| Pinned clocks | C: `ND500X_PIN_CLOCK=1`; C#: TestMON_CompilePath pins `SintranEmulation.DeterministicClock` = 1990-01-01 12:00 UTC | trace diffs REQUIRE both sides pinned or wall-clock digit formatting produces phantom hunks |
| `_cpu.LastProtectionViolation` | printed by the link test | names the faulting EA + capability reason + operand addressing when the guest's OWN trap handler eats the PV (no CRASHED stop to inspect) |

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
| **`cpu.StateTrace = MicroStateTrace.ToFile(path, labePath)`** (in code) | **MICROWORD-BY-MICROWORD STATE-CHANGE LOG of the real B30.** One line per Tick, only when something changed: octal CS address + nearest `.LABE` label + short decode + every changed register. Diffs all 24 WRF (encoding order), P/L/B/NPC, DPA/EA0-3/DATA/Q/LC/IRL/MIB, both status sets, and SRF 0o2000-0o2077 (mailbox comm block). Flags `[STOP]` and `[EXUC sneak]`. **Off by default — one null test per Tick.** Pass the `.LABE` path or the log is unreadable octal. **Does NOT cover:** the other ~4000 SRF words, and guest MEMORY writes (use `MpmBackedMicroMemory.ReadObserver`/`WriteObserver` for bytes). See `Nuget\HackerCorpLabs.Emulation.CPU.ND5000\src\MicroStateTrace.cs` — its header lists the traps. |
| `MicrocodeStartupStateProbeTests.Probe_ColdStartToIdle_DumpsFullStateDelta` | Full cold-start (CS 0 → IDLE, 62,851 ticks) register + memory + ACCP-conversation delta. **Check this before building a new startup instrument — it already exists.** |
| Sweep gate baseline | match=22330 diverge=1638 — regression SCREAMS |

**⚠️ READING A MICROWORD TRACE — a delta says WHEN state changed, not always WHICH word changed it.**
Two mechanisms, both measured: the **EXUC sneak** runs a second body under the same Mpc; and
**pipelined loads commit late** — a `D,LC` surfaces `Registers.LcLoadLatency` ticks afterwards, so
`INIT_SAMSON`'s `D,LC` at t=2 appears on the t=5 line whose CS is an unrelated `000104`. Check EXUC
and check for a pipelined register before attributing any write to a microword.

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
