# MON / MICFU path ledger — MOVED

**The ledger now lives in RetroCore, next to the code it describes and the test that enforces it:**

```
E:\Dev\Repos\Ronny\RetroCore\Emulated.HW\ND\CPU\ND500\Servicer\MON-PATH-LEDGER.md
```

## Why it moved (2026-08-28, the same day it was written)

It was written here because this is where the project's documents live. That became the wrong home
the moment it acquired a test.

`TestND500_MonPathLedgerIsComplete` in `Emulated.Tests.ND500` reads the ledger and fails when a
`N5MicroFunction` member has no row, when a row names a member that no longer exists, or when the
servicer has a `case` arm the ledger does not declare. **A test in one repository that reads a file
in another only works for someone who has both, checked out at the paths this machine happens to
use.** The test finds the file by walking up to `RetroCore.sln` — deterministic, but only because
the ledger now sits inside that solution's tree.

So: a document enforced by a build belongs in the repository whose build enforces it. Keeping a
second copy here would guarantee the two drift, and the stale one would be the one people found
first, because this is where they would look.

**Do not restore a copy in this repo.** Point at the RetroCore path.

## What it is, in one paragraph

All 22 MICFU paths, keyed on octal and enum-member name, each declared **REAL / FORWARDED /
CONDITIONAL / DECLINED-BY-DESIGN / FAKED / UNVERIFIED**, so that *"who answered the MON calls?"* is
a lookup rather than a re-reading of four thousand lines of servicer. The status that matters is not
FAKED but **CONDITIONAL**: `3MONCO` (24B) and `3WMONCO` (26B) forward to the attached CPU when
`ProcessHost` accepts the restart, and fall back to a canned answer when it does not — and the two
are indistinguishable from SINTRAN's side, which simply sends another one. The pair
`MonitorCallRestartsSeen` vs `MonitorCallRestartsTaken` is what tells them apart.
