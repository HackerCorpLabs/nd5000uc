# DIAGNOSTICS.md — every trace/instrument switch across the ND emulators

**Full path:** `E:\Dev\Ronny\ND5000UC\DIAGNOSTICS.md`
**Last verified:** 2026-08-08. Each of these was built once and re-discovered several times —
check here BEFORE building a new instrument.

## RetroCore C# — SETTINGS ARE COMMANDS NOW, NOT ENVIRONMENT VARIABLES (2026-08-26)

**Before reaching for an environment variable on the C# side, check whether it is a config key.**
Six were migrated on 2026-08-26. Each old variable still works as a **deprecated fallback that warns
once naming its key**, so nothing broke — but the key is the supported form, and a configured value
always beats the variable.

Set them from an `.ini` script or the console, exactly like any other command:

```ini
Config ndix_disk_image             D:\ND\NDIX\root.img
Config terminal_type               93
Config demand_segments             off
Config trap_dispatch               legacy
Config octobus_sniff_require_init  on
Config octobus_sniff_repeat        0
Config nd100_clock_isolation       off
Config                                    # lists every key with its valid values
```

| old environment variable | config key | note |
|---|---|---|
| `NDIX_DISK_IMAGE` | `ndix_disk_image` | |
| `ND500X_TERMINAL_TYPE` | `terminal_type` | **only affects the standalone DOM-runner lane** — on the real-SINTRAN lane the MON is forwarded, so use `SET-TERMINAL-TYPE` at the SINTRAN console instead |
| `ND500X_NO_DEMAND_SEGMENTS` | `demand_segments` | **polarity inverted** — the key is positive |
| `ND500X_NO_TRAP_DISPATCH` | `trap_dispatch` | **polarity inverted** |
| `ND5000_SNIFF_REQUIRE_INIT` | `octobus_sniff_require_init` | |
| `ND5000_SNIFF_REPEAT` | `octobus_sniff_repeat` | **a threshold of 2 or more can never be met** — see below |
| `ETHII_RX_INJECT` | Ethernet-II controller property | was `static readonly` = unsettable |
| `RETROCORE_ND100_CLOCK_ISOLATION` | `nd100_clock_isolation` | **polarity inverted**; was `static readonly` |

**⚠️ FOUR OF THESE WERE `static readonly` — read once at type initialisation and FROZEN for the
process.** In a test run the first test to touch the type decided the value for every test after it,
so setting one per-test worked or silently did nothing depending on order. The run still completed
and still printed a report, so **a knob that never applied read exactly like a measurement.** All
four are instance state now. If you ever set one of these per-test and got an inconsistent result,
that was why.

**⚠️ `octobus_sniff_repeat` 2 or more cannot be satisfied by the real doorbell.** `XMSINIT` sets
`X5ACT` to `-1`, SINTRAN wakes with a single `X5ACT := 0`, and **the microcode re-arms by writing 1,
not -1** (microword `0o24722` at `IDLE_2`, before consuming the message). So the genuine doorbell
produces exactly ONE `-1 -> 0` transition per XMSINIT; a threshold of 2 or more selects against the
cell it was meant to find and the sniff never latches — the CPU just looks idle. Setting it logs a
warning. The older "the doorbell repeats, a watchdog rings it" claim was an inference written as an
observation and is refuted.

Full reference (every key, valid values, which lane each applies on, a worked `.ini`):
`E:\Dev\Repos\Ronny\RetroCore\Emulated.Machines\ND\ND100\README.md`
Catalog of all 111 variables + root cause + what is still to migrate:
`E:\Dev\Ronny\ND5000UC\docs\RETROCORE-ENV-VAR-CATALOG-AND-CONFIG-DESIGN-2026-08-26.md`

**Still environment variables** (the diagnostic sinks — migration item 4, not done):
`ND500_MONLOG` · `ND500_HEAPLOG` · `ND500_FRAME_LOG` · `ND500_FRAMEPROBE` · `ND500_WATCH_ADDR` ·
`ND500_WATCH_LOG` · `ND500_FREEZE_MONLOG_ON_ERR` · `ND100_PT_TRACE` (+`_LO` `_HI` `_MAX`) ·
`ND500UC_WALKTRAIL` · `ND500UC_CAPTRAIL_FILE` · `ND500_READTRAIL_MIN` / `_MAX`, plus ~60 in the test
harnesses.

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
| `ND500X_NO_DEMAND_SEGMENTS=1` | turn off demand segment allocation. **This row is the C emulator's and is still current.** The C# twin moved to `Config demand_segments on\|off` (positive polarity) — do not set the variable expecting it to steer RetroCore |
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

## ND-500 macro CPU (`CpuND500`, in-code counters, always on — cost is zero on the normal path)

| Switch | What it does |
|---|---|
| `CpuND500.AbortGuardReport()` | **WHOLE-RUN** count, per instruction, of how often an abort guard stopped an instruction before it committed state. Companions: `AbortGuardTotal`, `AbortGuardHits(site)`, `ResetAbortGuardCounts()`. Sites are the `AbortGuardSite` enum (`Rett`/`Retk`/`Retb`/`Retbk`/`Entm`/`Chain`/`Init`/`Entt`/`Ret`). |

**Why it is not gated behind a flag:** the increment only runs inside a guard whose condition is
already `InstructionAborted`, i.e. on a path where a non-ignorable trap has been raised and the
instruction is being abandoned. Nothing is counted during normal execution.

**Why it is a plain array and NOT a ring:** every negative trusted on 2026-08-25 that came from a
capped instrument was wrong — a 52-entry per-stage MICFU ring was read as a whole-run tally and
"proved" an absence that was simply outside the window. A counter that cannot answer *"did this ever
happen"* is worse than none, because it answers confidently.

**HOW TO READ IT — the zero is the load-bearing result.** An abort guard is a *conditional early
return*: it can only change behaviour where `InstructionAborted` is already true at that point. So
`none` is not "probably did not matter", it is **proof that the guarded instructions behaved
identically with and without their guards for that run** — which makes any behaviour change in the
same run attributable to something else. That is what replaces bisecting two sessions' changes apart.
A non-zero `Chain` count is the opposite kind of news: it means a page fault inside CHAIN's link walk
was previously being reported as an ILLEGAL OPERAND VALUE trap (a faulted read returns 0, and 0 is
CHAIN's documented end-of-chain sentinel, ND-500 Reference Manual 15.7) — i.e. an emulator fault
that read as a bug in the guest program.

## Debug protocols

- RetroCore DAP: TCP port 4711 (skill `retrocore-dap-mcp`); nd500x DAP: `--dap [port]`, default 4500.
- Real machines: retroterm MCP (`terminal_connlist` has the ports). Never hand-roll telnet.
