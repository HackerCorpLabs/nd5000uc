# Adjudication: integer divide-by-zero — RESOLVED: all three cores already agree; the "cluster" was a sweep artifact

**Full path:** `E:\Dev\Ronny\ND5000UC\ADJUDICATION-DIVIDE-BY-ZERO-2026-08-08.md`
**Date:** 2026-08-08 (corrected the same day — the first version of this file wrongly concluded
"functional cores are wrong"; the correction is the story worth keeping)

## The semantics (confirmed from three independent directions)

On integer divide-by-zero, dest := **largest value of the datatype with the dividend's sign**
(BY +100/0 → 0x7F, −1/0 → 0x80), 0/0 → 0, DZ status bit 12 set.

- **Manual** ND-05.009.4 (nd500x `docs/...Reference Manual.md:2049`): "A division with zero will
  leave the largest possible value in the destination with the sign of the dividend... Zero
  divided by zero gives a result of zero."
- **Real B30 microcode**, traced live (Nd500xCorpus_TraceOneVector + mcread): DIV_INT zero path
  @024131-024140 routes the BM-derived saturate into SC3, ORs DZ (BM14/SARG 010200) into status
  via ST,LOAD, and the shared epilogue @02422 stores SC3 to the dest.
- **Functional CpuND500** (legacy `ARITHMETIC\Divide.cs`): implements exactly this — adjudicated
  and fixed 2026-07-26 against the same microcode words; nd500x likewise (commit ddda6ea + the
  negative-sign follow-up).

**All three cores agree. There was never a live divergence here.**

## What the "184-case cluster" actually was — two stacked artifacts

1. **The corpus's `final.regs` for trap cases are unvalidated prose.** The C runner
   (`test_instruction_validation.c` ~1029) explicitly "skip[s] register/memory validation for
   trap tests" — it asserts only that the right trap/status bit was raised. The div-by-zero
   cases still carry the pre-2026-07-26 "dest unchanged" finals, and nothing ever checks them.
2. **The third-column sweep treated those finals as golden.** Fixed the same day: cases with
   `expectedTrap` now mirror the C runner (assert the status bit, skip the reg/mem diff).

Post-fix baseline: diverge 826 → **642**; trap cases **256 ok / 37 MISSED / 64 unsupported**.

## The real finding that fell out: 37 trap-misses

The microword engine does NOT raise the FloatException bits (FU=13 / FO=14 / IVO=11) on the
float MULAD overflow/underflow paths (`MuladF_Overflow` shows st=0x220 = O+Z-region only). The
divide-exception ST,LOAD projection (CpuND5000.cs, scoped to @024125/024135/024137) does not
cover the float-op status paths. That is genuine open work, now visible for the first time.

## Standing lessons (both earned today)

- Corpus agreement is only as independent as its generators — but ALSO: check what the
  validator actually VALIDATES before calling a corpus field an expectation. `final.regs` on a
  trap case constrained nothing.
- A "divergence cluster" against a generated corpus deserves one look at the corpus's own
  runner before adjudicating cores against each other. The cores were fine; the sweep read the
  file more strictly than its owner does.
