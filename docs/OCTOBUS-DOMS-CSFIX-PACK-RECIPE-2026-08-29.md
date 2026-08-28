# Rebuilding `DOMS-CSFIX.IMG` — the only pack that can run an octobus domain

## Why this pack has to exist at all

Two things have to be on one pack before `place-domain` can do anything on the ND-5000 / octobus
lane, and **no stock pack on this box carries both**. Measured with `ndtool -t`, 2026-08-28:

| pack | `CONTROL-STORE:DATA` | `CPU-STAT:DOM` | `SWAP-FILE:DATA` | `DESCRIPTION-FILE:DESC` |
|---|---|---|---|---|
| `F:\ND\SINTRAN-L - 2026\HDD\BIGDISK0-L.IMG` | **262144** (ND-5000) | — | — | — |
| `D:\BIGDISK0-L-DOMS.IMG` | 147456 (classic ND-500) | yes | yes, 2000 pages | yes |
| `D:\BIGDISK0-L-CPUSTAT.IMG` | 147456 (classic ND-500) | yes | yes | — |

The ND-5000 microcode lives on the pack with no domains; every pack with domains carries the
CLASSIC store. What each wrong choice looks like, so neither is mistaken for a machine fault:

 - **ND-5000 store, no domains** → `define-swap-file` answers `NO SUCH FILE NAME`, then
   `DESCRIPTION FILE ERROR`, then `NO WELL DEFINED PROGRAM IN MEMORY`. The prompt comes back every
   time. Nothing about the bring-up is exercised, and the transcript still has the SHAPE of a failed
   bring-up.
 - **Domains, classic store** → `> Loading Control Store` then
   `Error when loading Control Store.  Microprogram error:  Wrong microprogram`.

`DESCRIPTION-FILE` is not garnish: a domain is registered there, which is why the CPUSTAT pack
answers `NO SUCH DOMAIN` for a domain whose segments are plainly present.

## The recipe, verified 2026-08-29

```
copy "D:\BIGDISK0-L-DOMS.IMG"  "<somewhere>\DOMS-CSFIX.IMG"

ndtool -x -o <dir> -F 'SYSTEM/CONTROL-STORE:DATA' "F:\ND\SINTRAN-L - 2026\HDD\BIGDISK0-L.IMG"
ndtool -f --put <dir>\CONTROL-STORE.DATA SYSTEM/CONTROL-STORE:DATA "<somewhere>\DOMS-CSFIX.IMG"
ndtool -t "<somewhere>\DOMS-CSFIX.IMG"      # confirm 262144 bytes / 128 pages
```

`ndtool` is `E:\Dev\Ronny\norskdata-ndfs\ndfs-c\build\ndtool.exe`. The page count grows 72 → 128 on
its own; no quota command is needed.

### Two flag traps, both of which fail QUIETLY

 - **`--dest` is an NDFS USER, not an output directory.** `-x ... --dest <hostdir>` extracts into the
   working directory instead and prints `skipped (exists)` for everything already there — so it looks
   like it ran and wrote nothing where you were looking. The output directory is `-o`.
 - **`--rm` prompts.** With no stdin it prints `Delete …? [y/N] Aborted.` and the following `--put`
   then reports `skipped (exists)`. Neither line is an error and the image is unchanged. Use
   `-f --put`, which overwrites in place; the `--rm` step is unnecessary.

## What is verified, and what is NOT

**Verified:** the rebuilt image's file listing is IDENTICAL to the `DOMS-CSFIX.IMG` in use — zero
differing lines from `ndtool -t` on both, same four files, same sizes, same page counts.

**NOT verified:** the two images are **not** byte-identical (SHA-256 differs). The listings agree, so
the difference is physical layout — block allocation and unused sectors — not inventory. Whether
SINTRAN cares is untested, and there is a specific reason it might: the earlier note on this pack
described `SWAP-FILE:DATA` as *contiguous*, and contiguity is a layout property that a listing cannot
show.

**So do not treat a rebuild as a drop-in replacement without one confirming run.** The check is cheap
— run `ShortBringup_Octobus_NoStartSwapper_PlaceAndRun_Capture` with
`RETROCORE_ND5000_PACK` pointed at the rebuild and confirm it reaches `> Loading Swapper` rather than
`Wrong microprogram` or `NO SUCH FILE NAME`.

## Where the working copy lives, and why that is a problem

The pack currently in use sits under this session's job scratch directory, which is **deleted when
the job is deleted**. That is why this recipe exists. If the pack matters beyond one session it needs
a durable home next to the other images, and the harness's `RETROCORE_ND5000_PACK` override is how it
gets pointed there.
