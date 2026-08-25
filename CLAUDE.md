# ND5000UC project rules

- READ FIRST: `PATHS.md` (the verified cross-repo map — nd500x is in WSL, nd100x is under
  E:\Dev\Emulators), `OWNERSHIP.md` (you own all three ND emulators — there is NO separate
  session/team that owns CpuND5000 or nd500x; older "lane ownership" notes are history, not a
  boundary) and `DIAGNOSTICS.md` (every existing trace switch — check before building a new
  instrument). If any of these disagrees with reality, fix it in the same session.
- **DON'T GUESS — GO READ THE MICROCODE. AND READ THE DEEP DIVE FIRST, IT PROBABLY ALREADY ANSWERS
  IT.** Order, every time: (1) `MEMORY.md` — is there already a reference? (2)
  **`docs\ND5000-ND100-MESSAGE-PROCESSING-REFERENCE-2026-08-23.md`** — 251KB, 421 `[V]`, and it says
  on its face *"Read it before re-deriving anything about ND-100↔ND-5000 messaging."* (3) the **RAW**
  `MICRO-5800-B30.DATA` (16 bytes/word) — **never** a rendered `.md`. (4) only then derive, marked
  `[D]`.
  **Cost of skipping it, 2026-08-25 — a whole day:** the headline metric "RESIWR = 44, no page ever
  copied in" was wrong; the doc states verbatim *"Never quote a MICFU count without naming the stage.
  The swapper delivery uses 13B/14B (measured live: 8×13B, **44×14B**); PLACE+RUN uses **30B/31B**."*
  The 44 IS the swapper being loaded into raw physical memory. The user-domain page-in counter is
  **MICFU 30B/31B = `3PHSR`/`3PHSW` = 0x18/0x19**. Separately, a `CNTXTSAVE` polarity derived as `[D]`
  is `[V]` at that doc's line 1093: `COND,MSGN` **`INVSEQ=1`** → save when `SRF11` is **non-negative**
  (a process IS loaded). A pseudocode/rendered decode drops things — `INVSEQ`, the one-word condition
  delay, MARG-vs-ORCON — and each dropped thing reads fluently and wrong.
  **`S3SM5` IS DISASSEMBLED — never park a question as "that lives in S3SM5, we can't see it"** (done
  3× on 2026-08-25). The NPL *source* is absent; the *code* is not:
  `E:\Dev\Ronny\NDInsight\tools\sintran-segment-carver\versions\L-VSX-500\re\030-S3SM5.dis` (1.53 MB)
  + `030-S3SM5-routine-map.md` + `ND500-SYSTEM-MONITOR\FUNCS-BODIES\` — **all ~60 FUNCS routine
  bodies, byte-verified, base `40000B`, ~11,000 lines.** That is where `MEMNAVAILABLE`, the
  `SWFUN`/`3SWMESS` stamp and the PST accessors live — e.g. **`073 RPHSG`** "read from a physical
  segment" @166537 and **`110 WPHSG`** "write into a physical segment" @167550, which connect the
  swapper's `RPHS` to MICFU `30B/31B` (`3PHSR`/`3PHSW`).
- **THE GOAL: run real ND-500/ND-5000 programs under REAL SINTRAN, with MON calls FORWARDED over the
  bus/octobus.** A run where our C# `SintranEmulation` answers the MON calls **DOES NOT COUNT** and
  must never be reported as progress toward it (this happened 2026-08-24). Before believing any
  "the program runs" claim, ask WHO ANSWERED THE MON CALLS.
- Current master plan: `PRIORITY-PLAN-2026-08-24-REAL-SINTRAN-DOM.md` (run-a-program track).
  `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md` still owns the cross-core alignment track.
- /loop re-arm: at most 2 minutes while actively iterating on a task. Longer only when genuinely
  waiting on something slow, and say so in the reason.
- Questions to Ronny must be SELF-CONTAINED: restate the context in the question itself. Never
  reference bare labels (Q1/Q3/item 2) from earlier turns.
- Handoff documents follow the shape of
  `E:\Dev\Repos\Ronny\RetroCore\DOCS\ND500_COMPILE_BYTE_EXACT_HANDOFF_2026-08-04.md`:
  result / the bugs / the technique / **wrong turns — do not repeat** (mandatory) / what is open.
  They live in `docs\handoffs\`, NOT scattered at repo root.
- HANDOFF-TO-SELF GATE: do NOT author a HANDOFF or CARVER-REQUEST to "the next session" during an
  active `/loop` — in a self-paced loop the next session is this same agent later. Do the work now,
  or stop the loop. A handoff is for a real human pickup or a wrong-turn record, not to keep a loop
  looking busy. See `docs\handoffs\README.md`.
- Microcode addresses are OCTAL. For ORCON/MARG/SARG/SCAL values read the RAW
  `MICRO-5800-B30.DATA` word, never the rendered `.md` listing.
- CARVE, DON'T GUESS: before asserting any microcode field, struct layout, flag bit, float value or
  test verdict, get it from the source named in `GROUND-TRUTH.md`. If you can't, mark it [OPEN].
- RetroCore builds on this box: single project + `/p:UseSharedCompilation=false`; assert the build
  exit code BEFORE believing any test number; finish with `dotnet build-server shutdown`.
