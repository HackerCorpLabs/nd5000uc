# RetroCore: the environment-variable catalog, the root cause, and the config design

**Date:** 2026-08-26
**Trigger:** Ronny, on being handed a Gate5R run recipe made of environment variables:
*"why the fuck would you use environment variables when we have a .ini file to configure the
machines"* and *"how the insane fuck has this happened"*.

Fair question. This document answers it with measurements, not with a story.

Every count and every file:line below was read out of the tree today. Grades: **[V]** verified by
reading the code, **[D]** derived, **[OPEN]** unknown.

---

## 1. The measurement

**111 distinct environment variables, 157 read sites.** `[V]`

| project | read sites | distinct vars | what it is |
|---|---|---|---|
| `Nuget` | 60 | 36 | mostly package-local test harnesses; **4 are engine code** |
| `Emulated.Tests.ND500` | 40 | 32 | the Gate5R lane |
| `Emulated.Tests` | 30 | 23 | ND-100 / ND-5000 harnesses |
| `Emulated.HW` | 19 | 19 | **the engine - CPUs, controllers, MON handlers** |
| `Emulated.UI.Avalon` | 5 | 3 | 2 of them are OS conventions and correct |
| `Emulated.Tests.ND100` | 2 | 1 | |
| `Emulated.Machines` | 1 | 1 | **engine** |
| **`Emulated.Debugger`** | **0** | **0** | **owns 209 CLI commands** |
| **`RetroCore`** | **0** | **0** | **owns the .ini script host** |

That last pair is the whole finding in two rows. **The two projects that own the configuration
system read no environment variables at all.** Everything underneath them does.

---

## 2. Root cause - three things, all verified

### 2.1 The CPU does not know what machine it belongs to `[V]`

```
grep -n "MachineBase|Machine " Emulated.HW/Common/CPU/CpuBase.cs   ->  no matches
```

`CpuBase` has no back-reference to its owning machine. Neither does any controller.

This is the mechanism. A developer standing in `MON_600_NDIX.cs:392` needing a disk-image path has
exactly two options:

1. thread a config object down through `MachineBase` -> `ND100Machine` -> the bus -> the ND-500
   attachment -> `CpuND500` -> `SintranEmulation` -> the MON handler; or
2. `Environment.GetEnvironmentVariable("NDIX_DISK_IMAGE")` - one line, no signatures touched, works
   immediately.

Option 2 was taken. Then it was taken again, because there was now a precedent, and a precedent is
much cheaper to follow than a plumbing job. 111 times.

**Nobody decided this.** There is no commit where someone chose environment variables over the ini.
Each individual step was locally the cheap one, and the cheap one was always the same one.

### 2.2 A machine config bag already exists - and it is in the SAME assembly `[V]`

```
Emulated.HW/Common/Machine/MachineBase.cs:574   public void SetConfig(string configKey, string value)
Emulated.HW/Common/Machine/MachineBase.cs:590   public string? GetConfig(string configKey)
Emulated.HW/Common/Machine/MachineBase.cs:601   public string[] ListConfig()
Emulated.HW/Common/Machine/MachineBase.cs:2471  public virtual string[] GetCpuConfigKeys()
Emulated.HW/Common/Machine/MachineBase.cs:2476  public virtual string GetCpuConfigValue(string key)
Emulated.HW/Common/Machine/MachineBase.cs:2481  public virtual string[] GetCpuConfigValidValues(string key)
Emulated.HW/Common/Machine/MachineBase.cs:2487  public virtual bool SetCpuConfigValue(string key, string value)
Emulated.HW/Common/Machine/MachineBase.cs:2494  public virtual bool ApplyCpuConfig()
```

It is reachable from a script today, via `Config <param> <value>`
(`Emulated.Debugger/DebugCommands.cs:556` -> `DebugCommands.Machines.cs:160`), which already does
get / set / list and already prefers CPU keys over generic ones.

**So the plumbing was not missing. It was missing a back-reference, which is a much smaller thing.**
`MachineBase` lives in `Emulated.HW/Common/Machine/` - the same assembly as `CpuND500` and the MON
handlers. No cross-assembly work is needed at all. This is the part that makes the situation
annoying rather than understandable: the facility existed, one pointer away, and 111 knobs went
around it.

### 2.3 Several of them cannot be changed after the first read `[V]`

This is worse than misplacement, and it is not visible from the variable name.

```csharp
// Emulated.HW/ND/CPU/NDBUS/NDBusEthernetII.cs:1107
private static readonly bool RxInjectEnabled =
    Environment.GetEnvironmentVariable("ETHII_RX_INJECT") == "1";

// Emulated.Machines/ND/ND100/ND100Machine.cs:720
private static readonly bool _clockIsolationDisabled =
    System.Environment.GetEnvironmentVariable("RETROCORE_ND100_CLOCK_ISOLATION") == "0";
```

`static readonly` = read once at type initialisation, frozen for the life of the process. Others use
one-shot latches to the same effect (`s_heapLogTried`, `s_watchLogTried`, `_ndixDiskImageTried`).

**Consequence for the test suite:** whichever test touches the type first freezes the value for
every test after it in that process. A per-test `Environment.SetEnvironmentVariable` is therefore
*not reliable* - it works or does nothing depending on test order. `[V]` from the code shape;
whether any current test is actually mis-reading because of this is `[OPEN]` and worth one sweep.

**This alone justifies the migration** regardless of taste: a setting you cannot set is not a
setting.

---

## 3. The catalog, grouped by who should own the setting

### 3.1 MACHINE-level - belongs on the machine config bag

| var | site | what it is | verdict |
|---|---|---|---|
| `NDIX_DISK_IMAGE` | `MON_600_NDIX.cs:392` | root-disk image path for NDIX | **indefensible.** A disk path. Nothing sets it - 5 references, all inside the one file. Unset, it *silently serves zeros* instead of failing. |
| `RETROCORE_ND100_CLOCK_ISOLATION` | `ND100Machine.cs:720` | disables clock isolation | `static readonly`, unchangeable at runtime |
| `RETROCORE_MACHINES` | `Cli.Hosts/.../MachineCatalogue.cs:87` | machine discovery path | arguably host-level; see section 7 |

### 3.2 CPU-level - belongs on `cpu` config

| var | site | what it is |
|---|---|---|
| `ND500X_NO_DEMAND_SEGMENTS` | `CpuND500.GrowableSegments.cs:258` | turn off demand-paged segments |
| `ND500X_NO_TRAP_DISPATCH` | `CpuND500.Trap.cs:214` | revert to legacy always-halt on trap |
| `ND500_NO_RESTART_P1` | `Nd500CpuProcessBridge.cs:206` | disable restart-at-P1 (the fix is ON by default) |
| `ND500UC_MISTAT15` | `CpuND500UC.cs:312` | microcode status bit 15 behaviour |

### 3.3 CONTROLLER-level - belongs on the controller instance

| var | site | controller |
|---|---|---|
| `ND5000_SNIFF_REQUIRE_INIT` | `OctobusND5000Station.cs:1619` | octobus ND-5000 station |
| `ND5000_SNIFF_REPEAT` | `OctobusND5000Station.cs:1631` | octobus ND-5000 station |
| `ETHII_RX_INJECT` | `NDBusEthernetII.cs:1107` | Ethernet II - `static readonly`, unchangeable |

### 3.4 SINTRAN-EMULATION-level - and one that configures dead code

| var | site | note |
|---|---|---|
| `ND500X_TERMINAL_TYPE` | `MON_16_MGTTY.cs:110` | **configures a path that does not run on the real-SINTRAN lane.** The ND-500 `MGTTY` is registered in `SintranEmulation.Definitions.cs:62` and reached through `Nd500MachineShell` - the standalone DOM runner. On the octobus / ND-500-interface lane the MON call is forwarded to real SINTRAN, so this handler never answers. This is exactly why the real fix for LED's terminal type was `SET-T-T,,93` at the SINTRAN level. |

`SINTRAN_EMULATION`, the `#if` guard around both `MON_16_MGTTY.cs` and `MON_600_NDIX.cs`, is
defined in `Emulated.HW.csproj:16` - **so it is on in every build and excludes nothing.** `[V]`
It reads like a switch and is a comment.

### 3.5 DIAGNOSTIC SINKS - trace files and probes

`ND500_MONLOG` - `ND500_HEAPLOG` - `ND500_FRAME_LOG` - `ND500_FRAMEPROBE` - `ND500_WATCH_ADDR` -
`ND500_WATCH_LOG` - `ND500_FREEZE_MONLOG_ON_ERR` - `ND100_PT_TRACE` (+`_LO` `_HI` `_MAX`) -
`ND500UC_WALKTRAIL` - `ND500UC_CAPTRAIL_FILE`

These are the most defensible as environment variables - they are developer instruments, not machine
configuration. They are still better as commands, because `DIAGNOSTICS.md` exists precisely to
catalogue them and a command is self-documenting where an env var is not. Lower priority.

### 3.6 HARNESS - the ~60 test-side variables

The Gate5R lane alone reads 32 distinct vars in one file. These are a different problem with a
different fix (section 5.4) and should **not** be migrated in the same pass - the boot test has live
uncommitted work in it right now.

### 3.7 LEGITIMATELY environment - leave alone

`XDG_DATA_HOME`, `HOME`, `RETROCORE_ROOT` in `Emulated.UI.Avalon` are OS placement conventions.
That is what environment variables are for. **Do not migrate these.**

*(The complete 157-row machine-generated list is appended as section 8.)*

---

## 4. What the config architecture already gives us

There are **two** command systems, and it matters which one the .ini drives. `[V]`

**A. The legacy debugger command set - `Emulated.Debugger/DebugCommands.cs`, 209 commands.**
This is what the .ini scripts run (`nd`, `cpu config --cpu=ND100CX --mms=MMS2`, `device add TERM 8
--port=9111`, `tcp start 9111`). Already present and relevant:

```
Config {param} {value}     get / set / list machine + CPU config      <- the generic hook
cpu config / cpu info      typed CPU configuration
device add / list / remove / types
controller add / list / remove / show                                 <- controllers already addressable
mount / unmount / eject / mount list / mount show
show config                SET / UNSET / VAR                          <- script variables
Trace / DebugLog / DebugTrace / Watch / WatchRegister
```

**B. The modern attribute-driven CLI - `Nuget/HackerCorpLabs.Cli.*`.**
`[CommandModule(Name = "...")]` + `[Command("machine.rom")]` + `[Arg]` / `[Opt]`, with a compiled
registry, help text and validation for free. Existing modules include `machine`, `nd500`, `diag`,
`mmu`, `debug`, `dap`, `net`, `chip`, `console`.

**Adding a command in system B is an attribute and a method.** There is no framework work to do.

The open question of which system new ND config should live in is a real fork and is put to Ronny in
section 7 rather than decided here.

---

## 5. The design

### 5.1 The existing standard - REUSE IT, do not invent a parallel one

**Corrected 2026-08-26.** An earlier draft of this section proposed a new
`IConfigurableComponent` interface. That was wrong: it was written without checking what the
codebase already standardises on. Ronny caught it. The analysis below is what should have been done
first, and the invented interface is deleted rather than kept as an alternative.

**The standard is `ISCSIConfigurable`** - `Emulated.HW/Common/SCSI/ISCSIConfigurable.cs`, mirrored
in `Nuget/HackerCorpLabs.Emulation.Buses.SCSI/src/`. `[V]`

```csharp
public interface ISCSIConfigurable
{
    SCSIDeviceConfig Config { get; }
    string[] GetConfigKeys();
    string   GetConfigValue(string key);
    bool     SetConfigValue(string key, string value);
}
```

Three properties make it the standard rather than just one example `[V]`:

1. **The key/value work lives in a config CLASS, not in the device.** `SCSIDeviceConfig`
   (`SCSIDeviceConfig.cs:325+`) implements `GetConfigKeys()` / `GetValue(key)` / `SetValue(key,
   value)` as **explicit switches** - no reflection, no LINQ, which matches the project's
   performance rules. `SetValue` returns `false` on an unknown key *or* a parse failure, so a typo
   and a bad value are both reportable.
2. **The device delegates in one line each** - `SCSICDROM.cs:65`,
   `SCSIConfigurableHDD.cs:63`: `public string[] GetConfigKeys() => _config.GetConfigKeys();`
3. **It already has two consumers, and one of them is the UI.**
   `Emulated.Debugger/DebugCommands.Devices.cs:1709` (list when no args are given, `key=value`
   pairs to set) and `Emulated.UI.Avalon/Views/DeviceManagerWindow.axaml.cs:944`. **Anything that
   implements this contract is rendered by the Avalonia device manager for free.**

What the other two config interfaces are, so they are not mistaken for this one `[V]`:

- `IAtaConfigurable` (`Buses.ATA/src/IAtaConfigurable.cs`) - **not this pattern.** Typed geometry
  and identity properties (`TotalSectors`, `Cylinders`, `ModelNumber`) feeding IDENTIFY DEVICE. No
  key/value surface at all.
- `IConfigurableMachine` (`Machines.Base/src/IConfigurableMachine.cs`) - a single
  `ConfigureFromArgs(string[])`, for the generic `machinerun` tool to forward machine-specific
  switches. Machine-level, argv-shaped, not a settings surface.

#### What to do: lift, do not duplicate

The three generic methods are already the right contract; only their *name* is SCSI-specific. So
lift them into a shared interface and let the SCSI one extend it:

```csharp
/// A component that exposes named settings to the command layer and the device-manager UI.
/// Lifted verbatim out of ISCSIConfigurable so there is ONE contract, not two of the same shape.
/// String-keyed and string-valued on purpose: the command line and the .ini are both text, and a
/// typed layer over a text protocol moves the parsing rather than removing it.
public interface IDeviceConfigurable
{
    string[] GetConfigKeys();
    string   GetConfigValue(string key);
    bool     SetConfigValue(string key, string value);   // false = unknown key or unparseable value
}

// SCSI keeps its own Config property; every existing call site and both consumers
// still see all four members, so nothing SCSI-side changes.
public interface ISCSIConfigurable : IDeviceConfigurable
{
    SCSIDeviceConfig Config { get; }
}
```

`CpuND500`, `CpuND500UC`, `OctobusND5000Station`, `NDBusEthernetII` and `NDBusND500IF` then
implement `IDeviceConfigurable`, each backed by its own small config class in the
`SCSIDeviceConfig` shape. **No central registry and no service locator** - nothing has to know
about anything it does not already own.

This is reuse in the sense the project rules mean it: one contract lifted to a shared home, not a
second contract of the same shape living beside the first.

### 5.2 The commands - THE ROUTE ALREADY EXISTS. No new command is needed for the CPU. `[V]`

Second correction in this section. An earlier draft proposed new `cpu set` and `controller set`
commands. Following the call chain shows they are redundant:

```
Config <key> <value>                     DebugCommands.cs:556
  -> SetConfigParam                      DebugCommands.Machines.cs:160
     -> machine.SetCpuConfigValue(k,v)   tried FIRST, before the generic bag
        -> ND100Machine.SetCpuConfigValue   ND100Machine.cs:1697   ALREADY OVERRIDDEN
```

`ND100Machine` already overrides all five CPU-config virtuals - `GetCpuConfigKeys` (1488),
`GetCpuConfigValue` (1490), `GetCpuConfigValidValues` (1625), `SetCpuConfigValue` (1697),
`ApplyCpuConfig` (2290) - and `Config` with no arguments already lists CPU keys with their valid
values before the generic settings.

**And the precedent for reaching a CONTROLLER from machine config is already in that key list** `[V]`:

```csharp
// ND100Machine.cs, CpuConfigKeys:
// "ND-500 / ND-5000 (SAMSON) coprocessor identity (Task #9). Applied to attached octobus
//  stations (and the 3022 servicer) via ApplyNd500Identity(); "auto"/"none" = use the
//  station/servicer constructor default."
"nd500_cpu_type_and_model", "nd500_micro_version", "nd500_cpu_parameter", "nd500_system_parameters"
```

Four machine-level config keys that already push values down into attached octobus stations and the
3022 servicer. **That is exactly the mechanism this migration needs, already built and already
driven from the .ini.**

So the work is not "add a command". It is "add keys to a list and cases to a switch, in the idiom
already there", and the .ini gains:

```ini
Config ndix_disk_image        D:\ND\NDIX\root.img
Config nd500_demand_segments  off
Config nd500_trap_dispatch    legacy
Config nd500_restart_at_p1    on
Config octobus_sniff_require_init  on
Config octobus_sniff_repeat        4
Config ethii_rx_inject             on
Config                                    # lists every key with its valid values
```

Naming follows the existing `nd500_*` convention rather than inventing a new one.

The one place a *new* command is still worth it is per-instance controllers, where a name has to be
supplied. That should mirror `scsi config <controller> <unit> [key=value ...]`
(`DebugCommands.Devices.cs:1709`) rather than invent a shape - same `key=value` parsing, same
list-when-no-args behaviour. `[D]`

### 5.3 Reaching the component - what actually has to be built

Two of the three layers exist. Only the bottom one is missing.

| layer | state |
|---|---|
| ini / command -> machine | **exists** - `Config`, `SetConfigParam` |
| machine -> CPU / controller | **exists** - the `nd500_*` keys + `ApplyNd500Identity()` |
| component exposes its own settings | **missing** - this is `IDeviceConfigurable` (5.1) |

The *engine-internal* reads (a MON handler asking for its disk path) need 2.1 addressed. Two ways:
a back-reference from component to machine, or the setting **pushed down** into the component when
it is configured - which is what `ApplyNd500Identity()` already does.

**Push-down wins, and the existing code already chose it** `[V]`. It keeps the dependency pointing
one way, it is testable without a machine, and it makes the 2.3 `static readonly` problem
structurally impossible: the field is written by a setter rather than frozen by a type initialiser.

### 5.5 Two more findings from the peer lane, both worth acting on `[V]`

Reported by `nd500uc-47` while this document was being written:

- **Two further env vars for the catalog**: `ND500_READTRAIL_MIN` / `ND500_READTRAIL_MAX`, hex
  virtual addresses windowing `CpuND500.ReadTrail.cs`. Read per-run, not `static readonly`, so no
  one-shot freeze. Both default to 0 = no floor / no ceiling.
- **`RETROCORE_BIGDISK0L` vs `RETROCORE_BIGDISK0L_DOM` cost two nine-minute runs.** Gate5 mounts
  the `_DOM` pack; every other gate mounts the other one. Setting the wrong one **does not fail** -
  it boots the wrong pack and reports `NO SUCH FILE NAME`, which is indistinguishable from a
  missing file on the right pack. **Whatever the config surface ends up being, it must print the
  image it actually mounted in the run's own header**, so this class of mistake is visible in the
  first ten lines instead of inferred from the last. Two variables where one is silently ignored on
  the lane you are on is its own argument for this work.

### 5.4 Not breaking anything while migrating

Each migrated setting keeps reading its environment variable **as a fallback only**, behind one
shared helper that logs once:

```csharp
// Deprecated path. Remove the env fallback once DIAGNOSTICS.md and every .ini
// in scripts/ have been updated. Logs once per variable so a run that is still
// relying on the old path says so in its own log rather than silently working.
string v = LegacyEnvFallback.Get("NDIX_DISK_IMAGE", "ndix-disk-image");
```

Nothing breaks on day one, every stale invocation announces itself, and the fallback can be deleted
when the log goes quiet. `[D]` - this is a proposal, not something measured.

---

## 6. Ordered plan

Ordered by *damage per unit of work*, not by tidiness.

**Items 1-3 are DONE** (2026-08-26, on branch `ethernet-ii-controller-fixes`). What landed:

| file | what |
|---|---|
| `Emulated.HW/Common/Configuration/IDeviceConfigurable.cs` | **new** - the three methods lifted out of `ISCSIConfigurable` |
| `Emulated.HW/Common/Configuration/LegacyEnvFallback.cs` | **new** - env fallback that warns once and names the replacement key |
| `Emulated.HW/Common/SCSI/ISCSIConfigurable.cs` | now `: IDeviceConfigurable`, keeps its `Config` property - SCSI unchanged |
| `Emulated.HW/ND/CPU/ND500/CpuND500.Config.cs` | **new** - `demand_segments`, `trap_dispatch` |
| `Emulated.HW/ND/CPU/ND500/CpuND500.Trap.cs` | `TrapDispatchEnabled` **`static readonly` -> instance** |
| `Emulated.HW/ND/CPU/ND500/CpuND500.GrowableSegments.cs` | `DemandSegmentsEnabled` **`static readonly` -> instance** |
| `Emulated.HW/ND/CPU/ND500/Sintran/SintranEmulation.Config.cs` | **new** - `ndix_disk_image`, `terminal_type` |
| `Emulated.HW/ND/CPU/ND500/Sintran/MON_600_NDIX.cs` | reads the config key; `CloseNdixDiskImage()` so a mid-run change applies |
| `Emulated.HW/ND/CPU/ND500/Sintran/MON_16_MGTTY.cs` | static -> instance, reads the config key |
| `Emulated.HW/ND/CPU/NDBUS/OctobusND5000Station.Config.cs` | **new** - `octobus_sniff_require_init`, `octobus_sniff_repeat` |
| `Emulated.HW/ND/CPU/NDBUS/NDBusEthernetII.cs` | `RxInjectEnabled` **`static readonly` -> instance** |
| `Emulated.Machines/ND/ND100/ND100Machine.cs` | `_clockIsolationDisabled` **`static readonly` -> instance**; 6 new keys; component push-down |
| `Emulated.Tests.ND500/Configuration/ComponentConfigurationTests.cs` | **new** - 21 tests, all green |

**FOUR frozen flags found, not two.** `ND500X_NO_DEMAND_SEGMENTS` and `ND500X_NO_TRAP_DISPATCH` were
`static readonly` as well - so per-process where they are really per-CPU state, and two CPUs in one
process could not disagree about them. `Cpu_TwoInstancesAreIndependent_NotSharedStatics` is the test
that pins that.

**Nothing was removed.** Every one of the six variables still works as a deprecated fallback and
warns once, naming its replacement key, so the Gate5R recipe and every existing script are
unaffected.

The .ini gains:

```ini
Config ndix_disk_image             D:\ND\NDIX\root.img
Config demand_segments             off
Config trap_dispatch               legacy
Config octobus_sniff_require_init  on
Config octobus_sniff_repeat        4
Config nd100_clock_isolation       off
Config                                    # lists every key
```

Still to do:

4. **The diagnostic sinks** - mechanical, low risk, do them in one sweep and update
   `DIAGNOSTICS.md` in the same commit.
5. **The harness (~60)** - last, and only once the peer lane's uncommitted work in
   `Nd500UCSintranBootTests.cs` has landed. A Gate5R config ini that the test loads would replace
   32 environment variables in that one file.
6. **Delete the `SINTRAN_EMULATION` guard or make it real.** It is defined in `Emulated.HW.csproj`
   and excludes nothing, which is worse than not having it - it invites the belief that the C#
   MON handlers are compiled out on the real-SINTRAN lane. They are not.

---

## 7. Open, and Ronny's to decide

- **Which command system new ND config goes in** - the legacy `DebugCommands` set the .ini already
  drives, or the modern attribute-driven `Cli` modules. Legacy is where the .ini works today;
  modern is where help, validation and the MCP surface come free. `[OPEN]`
- **How far to take it** - items 1-2 in section 6 are pure correctness. Items 3-6 are a real
  project.

## 8. Appendix - the complete generated list

Machine-generated from the tree on 2026-08-26, `var | project | file:line`, sorted.

```
BCD_DUMP|Emulated.Tests|Emulated.Tests/ND100/Nd110InstructionVerifyHarnessTests.cs:273
ECONET_FS_HOST|Nuget|Nuget/HackerCorpLabs.Emulation.Buses.Econet/tests/EconetLiveServerTests.cs:42
ECONET_FS_PORT|Nuget|Nuget/HackerCorpLabs.Emulation.Buses.Econet/tests/EconetFileTransferTests.cs:56
ECONET_FS_PORT|Nuget|Nuget/HackerCorpLabs.Emulation.Buses.Econet/tests/EconetLiveServerTests.cs:44
ECONET_FS_PORT|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.BBCMicro/tests/BbcEconetFileServerTests.cs:41
ECONET_PASS|Nuget|Nuget/HackerCorpLabs.Emulation.Buses.Econet/tests/EconetFileTransferTests.cs:58
ECONET_PASS|Nuget|Nuget/HackerCorpLabs.Emulation.Buses.Econet/tests/EconetLiveServerTests.cs:47
ECONET_PASS|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.BBCMicro/tests/BbcEconetFileServerTests.cs:43
ECONET_USER|Nuget|Nuget/HackerCorpLabs.Emulation.Buses.Econet/tests/EconetLiveServerTests.cs:45
ETHII_RX_INJECT|Emulated.HW|Emulated.HW/ND/CPU/NDBUS/NDBusEthernetII.cs:1107
ETH_TEST6_TRACE_OUT|Emulated.Tests|Emulated.Tests/NDBusDevices/EthernetIITpeBootHarnessTests.cs:299
HOME|Emulated.Tests.ND500|Emulated.Tests.ND500/Sintran/TestMON_CompilePath.cs:85
IICI_CAPTURE_OFFSET|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.MacIIci/tests/MacIIciMilestoneSequenceTests.cs:518
IICI_CAPTURE_OFFSET|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.MacIIci/tests/MacIIciMilestoneSequenceTests.cs:709
IICI_CAPTURE_OFFSET|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.MacIIci/tests/MacIIciMilestoneSequenceTests.cs:833
MACIICI_TLT|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.MacIIci/tests/MacIIciMilestoneSequenceTests.cs:2687
ND100_PT_TRACE_HI|Emulated.HW|Emulated.HW/ND/CPU/ND100/Nd100PageTableTrace.cs:71
ND100_PT_TRACE_LO|Emulated.HW|Emulated.HW/ND/CPU/ND100/Nd100PageTableTrace.cs:70
ND100_PT_TRACE_MAX|Emulated.HW|Emulated.HW/ND/CPU/ND100/Nd100PageTableTrace.cs:72
ND100_PT_TRACE|Emulated.HW|Emulated.HW/ND/CPU/ND100/Nd100PageTableTrace.cs:67
ND110_BPUN_DIR|Emulated.Tests|Emulated.Tests/ND110/ND110_CompareProgOpcodes.cs:79
ND5000_BOOT_IMAGE|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:129
ND5000_DIAG_DATA|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/DiagnosticMicroprogramRunnerTests.cs:39
ND5000_DIAG_START|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/DiagnosticMicroprogramRunnerTests.cs:45
ND5000_DIAG_TICKS|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/DiagnosticMicroprogramRunnerTests.cs:47
ND5000_DIFF_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/JsonVectorSweepTests.cs:1396
ND5000_DIVTRACE_A|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/DivIntTraceDiagTests.cs:41
ND5000_DIVTRACE_A|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/FppHostMathCrossCheckTests.cs:112
ND5000_DIVTRACE_A|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/FppHostMathCrossCheckTests.cs:176
ND5000_DIVTRACE_B|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/DivIntTraceDiagTests.cs:42
ND5000_DIVTRACE_B|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/FppHostMathCrossCheckTests.cs:113
ND5000_DIVTRACE_B|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/FppHostMathCrossCheckTests.cs:177
ND5000_DIVTRACE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/DivIntTraceDiagTests.cs:35
ND5000_DIVTRACE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/FppHostMathCrossCheckTests.cs:106
ND5000_DIVTRACE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/FppHostMathCrossCheckTests.cs:170
ND5000_FORCE_SERVICER|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:2401
ND5000_FORCE_STARTMESS|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:2382
ND5000_ND500X_CORPUS|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/Nd500xCorpusSweepTests.cs:50
ND5000_ND500X_DIVERGE_OPCODE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/Nd500xCorpusSweepTests.cs:211
ND5000_ND500X_TRACE_NAME|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/Nd500xCorpusSweepTests.cs:402
ND5000_ORACLE_TRACE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/MacroInstructionOracle.cs:252
ND5000_SEMICS_TEST|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:2344
ND5000_SNIFF_REPEAT|Emulated.HW|Emulated.HW/ND/CPU/NDBUS/OctobusND5000Station.cs:1631
ND5000_SNIFF_REPEAT|Emulated.Tests.ND100|Emulated.Tests.ND100/ControllerOctobus/OctobusND5000Tests.cs:1173
ND5000_SNIFF_REPEAT|Emulated.Tests.ND100|Emulated.Tests.ND100/ControllerOctobus/OctobusND5000Tests.cs:1210
ND5000_SNIFF_REQUIRE_INIT|Emulated.HW|Emulated.HW/ND/CPU/NDBUS/OctobusND5000Station.cs:1619
ND5000_SNIFF_REQUIRE_INIT|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:2349
ND5000_TEST_NO|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:2532
ND5000_TPE_SKIP_BRINGUP|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:2413
ND5000_TRACE_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/JsonVectorSweepTests.cs:1449
ND5000_TRACE_INDEX|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/JsonVectorSweepTests.cs:1472
ND5000_TRACE_NAME|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/JsonVectorSweepTests.cs:1450
ND5000_TRACE_ND500_ONLY|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000MicrowordBootProbeTests.cs:912
ND5000_TRAP_ADJUDICATE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND5000/tests/Nd500xCorpusSweepTests.cs:345
ND500UC_BOOT_REALCPU|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:887
ND500UC_BOOT_SERVICER|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:978
ND500UC_BOOT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:72
ND500UC_BOOT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSwapperPageFaultTraceTests.cs:54
ND500UC_CAPTRAIL_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND500UC/src/CpuND500UC.cs:2957
ND500UC_GATEFILE|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:1296
ND500UC_LOADLOG_EARLY|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2754
ND500UC_LOADLOG|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2761
ND500UC_LOADLOG|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3318
ND500UC_MISTAT15|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND500UC/src/CpuND500UC.cs:312
ND500UC_WALKTRAIL|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.ND500UC/src/CpuND500UC.cs:297
ND500UC_WATCH_GSWSP|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3048
ND500UC_WATCH_GSWSP|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3439
ND500UC_WATCH_MON422|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3075
ND500UC_WATCH_MON422|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3360
ND500UC_WATCH_MON422|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3404
ND500UC_WATCH|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:3008
ND500X_NO_DEMAND_SEGMENTS|Emulated.HW|Emulated.HW/ND/CPU/ND500/CpuND500.GrowableSegments.cs:258
ND500X_NO_TRAP_DISPATCH|Emulated.HW|Emulated.HW/ND/CPU/ND500/CpuND500.Trap.cs:214
ND500X_TERMINAL_TYPE|Emulated.HW|Emulated.HW/ND/CPU/ND500/Sintran/MON_16_MGTTY.cs:110
ND500X_TERMINAL_TYPE|Emulated.Tests.ND500|Emulated.Tests.ND500/Sintran/TestMON_PortedTerminalDeviceCalls.cs:246
ND500_DOMAIN|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2219
ND500_EXPECT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2709
ND500_FLOPPY_DIR|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2036
ND500_FLOPPY_UNIT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2039
ND500_FLOPPY|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:1008
ND500_FRAMEPROBE|Emulated.HW|Emulated.HW/ND/CPU/ND500/CpuND500.Execute.cs:315
ND500_FRAME_LOG|Emulated.HW|Emulated.HW/ND/CPU/ND500/Instructions/CALL/FrameLog.cs:70
ND500_FREEZE_MONLOG_ON_ERR|Emulated.HW|Emulated.HW/ND/CPU/ND500/Servicer/Nd500CpuProcessBridge.cs:1087
ND500_HEAPLOG|Emulated.HW|Emulated.HW/ND/CPU/ND500/Instructionset.BuddySystem.cs:55
ND500_INPUT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2348
ND500_KEEP_SCRATCH|Emulated.Tests.ND500|Emulated.Tests.ND500/Sintran/TestMON_CompilePath.cs:228
ND500_MONLOG|Emulated.HW|Emulated.HW/ND/CPU/ND500/Servicer/Nd500CpuProcessBridge.cs:1109
ND500_MON_LOG|Emulated.Tests.ND500|Emulated.Tests.ND500/Sintran/TestMON_CompilePath.cs:173
ND500_MPMWATCH|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2297
ND500_NO_RESTART_P1|Emulated.HW|Emulated.HW/ND/CPU/ND500/Servicer/Nd500CpuProcessBridge.cs:206
ND500_PROBE_D|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:308
ND500_PROMPTMS|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2439
ND500_PROMPT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2384
ND500_PROMPT|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2401
ND500_REGEN_MNEMONIC|Emulated.Tests.ND500|Emulated.Tests.ND500/Instructions/TestND500_DualWriter.cs:68
ND500_REGEN_SCRATCH|Emulated.Tests.ND500|Emulated.Tests.ND500/Instructions/TestND500_DualWriter.cs:135
ND500_RUNMS|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2330
ND500_SAVE_PACK|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2625
ND500_SINTRAN_PRE|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:2113
ND500_TRACE_FILE|Emulated.Tests.ND500|Emulated.Tests.ND500/Sintran/TestMON_CompilePath.cs:419
ND500_TRACE_FILE|Emulated.Tests.ND500|Emulated.Tests.ND500/Sintran/TestMON_CompilePath.cs:501
ND500_WATCH_ADDR|Emulated.HW|Emulated.HW/ND/CPU/ND500/CpuND500.Memory.cs:324
ND500_WATCH_LOG|Emulated.HW|Emulated.HW/ND/CPU/ND500/CpuND500.Memory.cs:306
ND500_WATCH_RECORD|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:960
NDIX_DISK_IMAGE|Emulated.HW|Emulated.HW/ND/CPU/ND500/Sintran/MON_600_NDIX.cs:392
ND_PCAP_IF|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranEthernetIIBootHarnessTests.cs:303
PIC1654S_ROM|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.PIC16C5x/tests/Pic16C5xFirmwareSmokeTests.cs:75
PIC1654S_ROM|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.PIC16C5x/tests/Pic16C5xPortIoTests.cs:142
PIC1654S_ROM|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.PIC16C5x/tests/Pic16C5xSymbolDisassemblyTests.cs:89
RETROCORE_AUTO_KEYBOARD_TEST|Emulated.UI.Avalon|Emulated.UI.Avalon/AutoKeyboardTestNC.cs:51
RETROCORE_BENCH_MEMORY_DIAGNOSE|Emulated.Tests|Emulated.Tests/SUN2/RamRomVirtualVsFastBenchmarks.cs:190
RETROCORE_BIGDISK0L_CPUSTAT|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd500BootHarnessTests.cs:89
RETROCORE_BIGDISK0L_DOM|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:88
RETROCORE_BIGDISK0L|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSintranBootTests.cs:76
RETROCORE_BIGDISK0L|Emulated.Tests.ND500|Emulated.Tests.ND500/nd500if/Nd500UCSwapperPageFaultTraceTests.cs:57
RETROCORE_BIGDISK0L|Emulated.Tests|Emulated.Tests/ND100/Nd100EthernetIIOracleDramDumpTests.cs:64
RETROCORE_BIGDISK0L|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd500BootHarnessTests.cs:74
RETROCORE_BIGDISK0L|Emulated.Tests|Emulated.Tests/ND100/Nd110CxSintranBootHarnessTests.cs:88
RETROCORE_ETH_CARDS|Emulated.Tests|Emulated.Tests/ND100/Nd100EthernetIIOracleDramDumpTests.cs:172
RETROCORE_HARNESS_TIMEOUT_SCALE|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:506
RETROCORE_MACHINES|Nuget|Nuget/HackerCorpLabs.Cli.Hosts/src/Catalogue/MachineCatalogue.cs:87
RETROCORE_MCP_PORT|Nuget|Nuget/Tools/Sdl2CliDemo/Program.cs:62
RETROCORE_ND100_CLOCK_ISOLATION|Emulated.Machines|Emulated.Machines/ND/ND100/ND100Machine.cs:720
RETROCORE_ND5000_RUNTHREAD|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:232
RETROCORE_NLL_FLOPPY|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:1253
RETROCORE_NLL_FLOPPY|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:284
RETROCORE_NLL_FLOPPY|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:781
RETROCORE_NLL_FLOPPY|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:872
RETROCORE_NLL_FLOPPY|Emulated.Tests|Emulated.Tests/ND100/Nd100SintranNd5000OctobusBootHarnessTests.cs:963
RETROCORE_ROOT|Emulated.UI.Avalon|Emulated.UI.Avalon/Services/UserPreferencesService.cs:250
RETROCORE_ROOT|Emulated.UI.Avalon|Emulated.UI.Avalon/Views/ScriptEditorWindow.axaml.cs:184
RETROCORE_SCRATCH|Emulated.Tests|Emulated.Tests/ND100/Nd100EthernetIIOracleDramDumpTests.cs:76
RETROCORE_SST_NO_DOWNLOAD|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.MOS6502/tests/SingleStep/SingleStepTests.cs:50
RETROCORE_TCPSER_D02|Emulated.Tests|Emulated.Tests/ND100/Nd100TcpIpFirmwareExecutionTests.cs:69
RETROCORE_TCPSER_D02|Emulated.Tests|Emulated.Tests/ND100/Nd100TcpIpFirmwareTests.cs:58
SSTEST_CYCLE_FOLDER|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleReadout.cs:57
SSTEST_FAIL_SAMPLES|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooHarnessBase.cs:102
SSTEST_FIRST_FAIL_DETAIL|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooHarnessBase.cs:101
SSTEST_FIRST_FAIL_DETAIL|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/SingleStepTests8088Harness.cs:370
SSTEST_MAX_CASES|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleAccuracyBase.cs:92
SSTEST_MAX_CASES|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleReadout.cs:71
SSTEST_MAX_CASES|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/SingleStepTests8088Harness.cs:361
SSTEST_OPCODE_FILTER|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleAccuracyBase.cs:86
SSTEST_OPCODE_FILTER|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleReadout.cs:65
SSTEST_OPCODE_FILTER|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooHarnessBase.cs:96
SSTEST_OPCODE_FILTER|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/SingleStepTests8088Harness.cs:364
SSTEST_REPORT_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleAccuracyBase.cs:169
SSTEST_REPORT_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooCycleReadout.cs:145
SSTEST_REPORT_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/MooHarnessBase.cs:100
SSTEST_REPORT_FILE|Nuget|Nuget/HackerCorpLabs.Emulation.CPU.Intelx86/tests/Functional/SingleStepTests8088Harness.cs:369
SUN4M_ROMS_ROOT|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.Sun4m/tests/Sun4mBootTracerTests.cs:54
SUN4M_ROMS_ROOT|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.Sun4m/tests/Sun4mPcHistogramTests.cs:38
SUN4M_SYMS|Nuget|Nuget/HackerCorpLabs.Emulation.Machines.Sun4m/tests/Sun4mPcHistogramTests.cs:47
TPE_DUMP|Emulated.Tests|Emulated.Tests/ND100/Nd110InstructionVerifyHarnessTests.cs:348
TPE_PROG|Emulated.Tests|Emulated.Tests/ND100/Nd110InstructionVerifyHarnessTests.cs:321
XDG_DATA_HOME|Emulated.UI.Avalon|Emulated.UI.Avalon/Services/UserPreferencesService.cs:265
XDG_DATA_HOME|Emulated.UI.Avalon|Emulated.UI.Avalon/Views/ScriptEditorWindow.axaml.cs:195
```
