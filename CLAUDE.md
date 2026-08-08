# ND5000UC project rules

- READ FIRST: `PATHS.md` (the verified cross-repo map — nd500x is in WSL, nd100x is under
  E:\Dev\Emulators) and `DIAGNOSTICS.md` (every existing trace switch — check before building a
  new instrument). If either file disagrees with reality, fix it in the same session.
- Current master plan: `PRIORITY-PLAN-ND500-ALIGNMENT-2026-08-08.md`.
- /loop re-arm: at most 2 minutes while actively iterating on a task. Longer only when genuinely
  waiting on something slow, and say so in the reason.
- Questions to Ronny must be SELF-CONTAINED: restate the context in the question itself. Never
  reference bare labels (Q1/Q3/item 2) from earlier turns.
- Handoff documents follow the shape of
  `E:\Dev\Repos\Ronny\RetroCore\DOCS\ND500_COMPILE_BYTE_EXACT_HANDOFF_2026-08-04.md`:
  result / the bugs / the technique / **wrong turns — do not repeat** (mandatory) / what is open.
- Microcode addresses are OCTAL. For ORCON/MARG/SARG/SCAL values read the RAW
  `MICRO-5800-B30.DATA` word, never the rendered `.md` listing.
- RetroCore builds on this box: single project + `/p:UseSharedCompilation=false`; assert the build
  exit code BEFORE believing any test number; finish with `dotnet build-server shutdown`.
