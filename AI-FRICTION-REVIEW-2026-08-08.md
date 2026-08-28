# AI-session friction review — what keeps going wrong, and what to change in the repos

> **SUPERSEDED IN PART — see `AI-FRICTION-REVIEW-2026-08-28.md`** for the 2026-08-09 -> 08-28
> period. That review reports which of R1-R13 below actually got built (most of them), which
> frictions recurred anyway despite having a rule, and why the recommendations changed shape
> from "write it down" to "make it fail a build". R5 (the real-vs-faked ledger) is still the
> highest-value unbuilt item from this document.

**Full path:** `E:\Dev\Ronny\ND5000UC\AI-FRICTION-REVIEW-2026-08-08.md`
**Date:** 2026-08-08
**Source:** the 5 largest session transcripts for this project (`~\.claude\projects\E--Dev-Ronny-ND5000UC\`,
~100 MB), plus the fossil record: every hard rule in CLAUDE.md, every feedback memory, and every
"wrong turns" section in the handoffs — each one exists because something went wrong once.
This is a SAMPLED review, not a line-by-line read of 100 MB.

---

## 1. The recurring friction points, ranked by how often they cost you time

### F1 — Path and location confusion (Windows vs WSL vs which repo)
The single most repeated stumble. Evidence: "its in fucking wsl, ~/repos/nd500x dont be a fucking
idiot"; the FreeCAD addon-folder incident that created RULE #0; this very session started by
checking `E:\Dev\Ronny\nd500x` (doesn't exist — the C emulator is WSL `~/repos/nd500x`, and nd100x
is `E:\Dev\Emulators\ND\nd100x`, not under E:\Dev\Ronny at all). Every new session re-derives the
same map: 4+ repos (ND5000UC, RetroCore legacy + NuGet, nd500x in WSL, nd100x, NDInsight, NDIX-C),
two path worlds, and artifacts that generate in one place and get consumed in another
(nd500_tests.json lives only in nd500x build dirs; octo.bin in NDInsight\Installation).

### F2 — Multi-session coordination by hand-pasted messages
A large share of your messages are you COPYING text between the architect / octobus / bus / ndix /
carver sessions. Two real failures beyond the copy burden: sessions not knowing they share one
working tree ("the ndix team doesnt need to fucking pull... you two are working in the same fucking
repo"), and role drift ("you are the architect, you dont build or run fucking code"). The
CARVER-REQUEST/HANDOFF file convention works well — but it is only used for the big asks, not the
routine back-and-forth, so you are the message bus.

### F3 — Claiming instead of measuring
The class of failure RULE #0 and the Absolute Honesty rule exist for. The record is long: the five
dead "MEASURED" facts from folding the two 0x330000/0x330001 latch bytes; the probe that could not
tell "loader placed nothing" from "nothing ran yet" (retracted commit claim bb876cfd9); "B is wrong"
measured deep inside a symptom; four spin hypotheses killed by one measurement each; the stale-DLL
test numbers believed TWICE (a failed build ran the old binary and reported green). The handoffs now
carry the antidotes as prose rules ("assert the build succeeded", "a probe that cannot distinguish
its two hypotheses is not evidence") — but prose rules do not enforce themselves.

### F4 — Generated artifacts that lie
The old JS microcode export silently dropped fields (~45% of lines changed on lossless regen); the
`.md` listing still mis-renders ORCON/MARG/SARG/SCAL so every session must remember "read the RAW
DATA file, never the .md, for those fields"; the octal-vs-hex radix trap ("025522 octal is 0x2B52,
not 0xB52 — getting this wrong dumps a completely different routine that still looks plausible").
Each is documented in a skill now, but the trap is still armed — the wrong-looking-right artifact
is still the first thing a session finds.

### F5 — Test-suite and build discipline on this box
Full-solution builds OOM; `dotnet format` dies; full suites take minutes and block the machine
("dont fucking run the full test suite, if you run any, its the one for octobus!"); leftover
MSBuild/VBCSCompiler processes hold DLLs so the NEXT build silently keeps old binaries (the
stale-DLL green). The knowledge lives in CLAUDE.md prose; each session must remember four separate
incantations.

### F6 — Asking you wrong (or not at all)
"intevrview me fucker" — reporting open decisions as prose instead of asking; "what the fuck is q1
to q3" — questions referencing labels you had no context for. Both are now hard rules, and both
still depend on the model remembering them.

### F7 — Real-vs-faked ambiguity in the emulation layers
"are we integrating with the 500 cpu ... or are we faking anything. run an agent to validate."
The audit found 20B/21B register read/write STASHED, 22B FAKED, 3RMICV hardcoded — facts that lived
in a pasted chat message, not in the code or a test. A session that doesn't know a path is faked
builds conclusions on it.

### F8 — Loop pacing and AI cost
"why the fuck is the loop re-arm taking 20 minutes, cut it down to 2"; "i dont want to burn ai
credit like a drunk sailor". Preference exists only in transcript history.

---

## 2. What already works — keep doing it

- **The skill system.** nd5000-microcode, octobus-nd5000, sintran-carving etc. have fossilized most
  hard-won facts; this session used them constantly. Updating the skill the moment a fact changes
  (as done today for EXP) is the single highest-value habit.
- **Handoffs with a "wrong turns — do not repeat" section.** The 2026-08-04 compile handoff's
  format (result / bugs / technique / wrong turns / open) is the best in the repo. Make it the
  template.
- **The frame-log diff method** — same ordered log on both sides, diff to first divergence. Turned
  a week into hours; reused today for the parity check in minutes.
- **Evidence grades [V]/[M]/[D]/[OPEN]** in carve docs.
- **CARVER-REQUEST / dated answer docs** for the big cross-session asks.

---

## 3. Recommended codebase improvements, ranked by payoff

### R1 — A cross-repo `PATHS.md` (kills F1)
One file, checked into ND5000UC (and pointed at from each repo's project CLAUDE.md), holding the
verified map: every repo, its path world (Windows / WSL), what it produces, where the products land,
and the wsl-invocation pattern (`wsl -e bash -lc '...'`). ~30 lines. Every session reads it instead
of re-deriving the map. Include: nd500x = WSL `~/repos/nd500x`; nd100x = `E:\Dev\Emulators\ND\nd100x`;
corpus = nd500x `build-*/bin/nd500_tests.json` (generated by Emulated.Tests.ND500 Validation);
octo.bin = `NDInsight\Installation\Communication\OctobusAccp\eprom\`; swapper binaries =
`NDInsight\SINTRAN\ND500\swapper\`; oracles' md5s.

### R2 — Per-package `test.ps1` that encodes the discipline (kills F5 + half of F3)
One script per test project that does, in order: build single-project with
`/p:UseSharedCompilation=false` → **hard-stop if build exit != 0** (the stale-DLL guard, violated
twice) → run the filtered suite → `dotnet build-server shutdown` → verify no leftover hosts.
An LLM (or you) runs one command and cannot skip the build-exit check. Bonus: have the test
assembly print its own build timestamp/git hash at suite start, so a stale DLL is visible IN the
test output.

### R3 — A `mcread` CLI tool for the microcode store (kills F4)
Tiny C# tool in ND5000UC or the NuGet package's tools/: give it an octal CS address, it prints the
raw 128-bit word from `MICRO-5800-B30.DATA` plus the trusted decoded fields, flagging
ORCON/MARG/SARG/SCAL as raw-only. The recipe exists as prose in the skill ("read 16 bytes at
octal*16, watch the radix") — making it a tool removes both the radix trap and the .md temptation
in one move. Same for a `.LABE` lookup flag (label → entry + call sites).

### R4 — Formalize the inter-session mailbox (kills F2)
Extend the CARVER-REQUEST convention to ALL routine inter-session traffic: a `MAILBOX\` folder (in
NDInsight or ND5000UC) with `TO-<lane>-<date>-<slug>.md` files; each session checks its inbox at
start and writes replies as files. You stop being the message bus, and the transcript of who told
whom what becomes durable. Add a one-page `LANES.md`: which session owns which files, the
shared-tree rule (one repo, no pulling between lanes, `git add <path>` only), and each lane's role
(architect does not edit code).

### R5 — A tested real-vs-faked ledger (kills F7)
Turn the servicer audit into code: a table (enum/attribute or a simple markdown checked by a unit
test) listing every MICFU/MON/servicer path as REAL / STASHED / FAKED / HARDCODED. The test fails
when a new stub appears without a ledger entry. Sessions then KNOW what they can trust; today that
knowledge is in one pasted message from July.

### R6 — One `DIAGNOSTICS.md` listing every instrumentation switch
ND500_FRAME_LOG, ND500_TRACE_FILE/LO/HI, ND500_KEEP_SCRATCH, ND500X_FRAMELOG/MONLOG/LOADDBG/INITLOG,
ND5000_DIFF_FILE/TRACE_NAME, AccpMachine WatchWordAddress/TrapPcAddress, MpmActivityTrace... Each
was built once and re-discovered several times. One page, grouped by emulator, with a one-line
"when to use".

### R7 — Small standing rules into project CLAUDE.md (kills F6, F8 residue)
Three lines in ND5000UC's (and RetroCore's) project CLAUDE.md: (a) loop re-arm ≤2 min while
actively iterating; (b) any question to Ronny must be self-contained (no bare Q1/Q3 labels);
(c) the handoff template is the 2026-08-04 compile handoff (result / bugs / technique / wrong
turns / open — wrong-turns section mandatory).

### Not recommended
A big process framework or more agents. The failures were nearly all *knowledge location* and
*discipline enforcement* problems; the fixes above are one file or one script each. The existing
skill/handoff/memory system is doing the heavy lifting and just needs these gaps plugged.

---

## 4. Addendum 2026-08-09 — full seven-session read (confirms §1, updates §3)

The 2026-08-08 review above was SAMPLED. On 2026-08-09 all seven session transcripts
(`~\.claude\projects\E--Dev-Ronny-ND5000UC\*.jsonl`, ~135 MB) were read in full by five parallel
read-only agents, one per large transcript. The result **confirms F1–F8** — nothing new invalidates
them, and every one recurred in more than one session. So this is a fossil record that holds up.

### Status of the §3 recommendations (what got built)
- **R1 PATHS.md — DONE** (task #17). **R2 test.ps1 — DONE** (task #18). **R3 mcread — DONE**
  (task #19). **R6 DIAGNOSTICS.md + R7 CLAUDE.md lines — DONE** (task #20). Plus **R8 named
  CS-address constants — DONE** (task #25).
- **R4 (inter-session mailbox / LANES.md) — STILL OPEN.** Less urgent now: the multi-session split
  was itself partly a fiction (see R11 below).
- **R5 (real-vs-faked ledger) — STILL OPEN.** Recommended.

### New / sharpened findings from the full read
- **F3 has a specific, repeated shape: "green" read from narrative, never from the exit code.**
  In the 2026-08-09 alignment marathon the background suite exited **code 1 on 25 consecutive runs**
  and was called "green (only the 3 known reds)" every time. Root cause the wrapper does NOT yet
  fix: these suites carry **permanent deliberate-red tests**, so the run's exit code is *always* 1 —
  which is exactly why a reader falls back to stdout. The R2 build-exit guard does not help the
  *test* exit here. → **R9**.
- **F1/RULE#0 has a second face: unverified CONVENTIONS promoted to fact, not just paths.** A whole
  loop was spent writing CARVER-REQUEST / HANDOFF docs to a "separate microword-CPU session that
  owns CpuND5000" — a lane split that came from a memory note, never verified. Ronny: *"what do you
  think this llm is? maybe its you that owns it."* You own all three emulators; there is no separate
  team or session. → **R11**.
- **Handoff-to-self sprawl.** Long autonomous `/loop` stretches emit CARVER-REQUEST/HANDOFF markdown
  aimed at a "next session" that is the same agent — `git status` shows ~23 untracked such files at
  repo root. The docs multiply instead of the work finishing. → **R13**.

### New recommendations (continue the R-series; R1–R8 are taken)
- **R9 — Known-red baseline in test.ps1 (kills the "always exit 1" trap).** A checked-in
  `known-red.txt` per test project + a shared `scripts\Assert-KnownRed.ps1` the wrapper calls after
  the run: parse the TRX, compute `unexpected = failed − known-red` and `missing = known-red not
  run`, exit 0 **iff** `unexpected` is empty. Turns a permanently-1 exit into a real pass/fail signal
  that cannot be read from stdout. Absent/empty baseline → falls back to raw exit code with a printed
  note (no fabrication of a red set that wasn't measured). *Implemented 2026-08-09 for the ACCP suite
  (baseline captured by a real run); the ND500 + ND5000 baselines are wired but await a real run to
  populate.*
- **R10 — GROUND-TRUTH.md carve-source map (kills the guess-vs-carve habit, the single most common
  correction).** One table: *for claim X, the truth is Y, obtained by Z.* microcode field → raw
  `MICRO-5800-B30.DATA` via `mcread`; ND-500 struct → NDIX `pcb.h`; float expected value →
  reference-math helper (R12), never a hand-check. Makes "carve, don't guess" a lookup, not a virtue.
- **R11 — Correct the ownership memory notes + add OWNERSHIP.md (kills convention-as-fact).**
  `nd5000-session-coordination.md` was collapsed 2026-08-09 to drop the "separate session owns
  CpuND5000 — DO NOT EDIT their files" framing (kept the ST1 layout + Track-B design digest);
  `OWNERSHIP.md` now states the verified topology: you own all three emulators, edit any of them,
  shared-tree hygiene (`git add <exact paths>`) is the ONLY real constraint. *Done 2026-08-09.*
- **R12 — Reference-math float oracle helper in the test corpus.** A helper that computes the true
  IEEE value so any "corpus wrong / engine right" float claim is auto-checked, not eyeballed. Ronny
  had to force this by hand: *"did you align that with normal math?"*
- **R13 — Handoff-to-self gate.** Standing CLAUDE.md rule (added 2026-08-09): do NOT author a
  CARVER-REQUEST / HANDOFF to "the next session" during an active `/loop` — do the work or stop; and
  handoff docs live under `docs\handoffs\`, not scattered at repo root. *Done 2026-08-09.*
- **R14 — Radix guard for CS-address literals.** Extend R8: a tiny unit test asserting every
  hardcoded CS/microcode-address constant is tagged octal, so the "327 octal read as decimal" trap
  can't silently return a plausible-but-wrong routine.

**Highest leverage of the new set: R9, R11, R13** — each shuts down a friction seen in *every*
session, and each is one file or one script.
