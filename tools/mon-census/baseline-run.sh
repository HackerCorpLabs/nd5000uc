#!/bin/bash
# BASELINE: run every installed ND-500 program under nd500x and record what happens.
#
# This is a MEASUREMENT, not a test.  It answers the question nobody has asked of the
# whole corpus at once: which programs get anywhere, and where do the rest stop?
# What to implement next should be ranked off this, not off which instruction looks
# important.
#
# WHAT THIS DOES *NOT* PROVE.  nd500x answers MON calls with its OWN C emulation.  A
# program running here says the DOM loads and the instructions execute; it says NOTHING
# about SINTRAN, the mailbox or the microcode.  That is a different and higher bar
# (goal-real-sintran-not-emulated-mon).  This measures the INSTRUCTION and LOADER gap.
#
# READ THE VERDICT RULES BEFORE TRUSTING A RESULT.  The first version of this script
# reported 9 of 13 programs as "not-found" - and every one of them had loaded and run
# fine.  The quit words fed on stdin (EXIT/QUIT/Q/STOP/END) are typed at the SINTRAN
# prompt AFTER the program returns, where they are not commands, so SINTRAN answers
# "NO SUCH COMMAND OR DOMAIN" to each.  Grepping the whole log for that string measured
# MY OWN INPUT and called it a property of the program.
#
# So: everything below is judged ONLY on the region between the program's "placed" line
# and its "program exited" line, and the headline number is INSTRUCTIONS EXECUTED,
# which nd500x reports directly and which no amount of prompt noise can fake.
set -u
ROOT="$HOME/ND500USERS"
BIN="$HOME/repos/nd500x/build/bin/nd500x"
OUT="${1:-/tmp/baseline}"
TIMEOUT="${2:-25}"
mkdir -p "$OUT"

echo "program,instructions,outbytes,verdict,evidence"
for dom in "$ROOT"/SYSTEM/*.DOM; do
  base=$(basename "$dom" .DOM)
  log="$OUT/$base.log"

  timeout -k 3 "$TIMEOUT" "$BIN" --monitor --user GUEST --sintran-root "$ROOT" \
      > "$log" 2>&1 <<EOF
$base
EXIT
EOF
  code=$?

  # The program's own region of the log: from "placed" to "program exited".
  # sed prints nothing if the program never got placed, which is itself the answer.
  body=$(sed -n '/-- .* placed (domain/,/-- program exited/p' "$log")

  instr=$(printf '%s' "$body" | sed -n 's/.*program exited (\([0-9]*\) instructions).*/\1/p' | head -1)
  [ -z "$instr" ] && instr=0
  # Bytes the PROGRAM emitted, minus the two marker lines - a program can run a long
  # time and print nothing, and that is a different failure from one that prints.
  outbytes=$(printf '%s' "$body" | grep -v -e '-- .* placed (domain' -e '-- program exited' | wc -c)

  if ! printf '%s' "$log" >/dev/null || [ -z "$body" ]; then
    verdict="DID-NOT-LOAD"
    ev=$(grep -im1 "NO SUCH COMMAND OR DOMAIN\|load failed\|cannot" "$log" | tr -d '\r')
  elif printf '%s' "$body" | grep -qi "Unimplemented MON"; then
    verdict="MON-GAP"
    ev=$(printf '%s' "$body" | grep -im1 "Unimplemented MON" | tr -d '\r')
  elif printf '%s' "$body" | grep -qi "unimplemented\|unknown opcode\|illegal instruction\|undefined opcode"; then
    verdict="INSTRUCTION-GAP"
    ev=$(printf '%s' "$body" | grep -im1 "unimplemented\|unknown opcode\|illegal instruction\|undefined opcode" | tr -d '\r')
  elif printf '%s' "$body" | grep -qi "PANIC\|abort\|fatal\|TRAP "; then
    verdict="TRAP"
    ev=$(printf '%s' "$body" | grep -im1 "PANIC\|abort\|fatal\|TRAP " | tr -d '\r')
  elif [ "$code" = "124" ] || [ "$code" = "137" ]; then
    verdict="HUNG-OR-INTERACTIVE"; ev="still running after ${TIMEOUT}s"
  elif [ "$outbytes" -gt 40 ]; then
    verdict="RAN-AND-PRINTED"; ev="produced $outbytes bytes of output"
  else
    verdict="RAN-SILENT"; ev="exited without printing anything useful"
  fi

  ev=$(printf '%s' "$ev" | cat -v | tr ',' ';' | cut -c1-80)
  echo "$base,$instr,$outbytes,$verdict,$ev"
done
