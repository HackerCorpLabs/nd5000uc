#!/bin/bash
# Disassemble a whole ND-500 .DOM program segment with nd500x.
#
# WHY THIS IS CHUNKED: nd500x's --disasm writes into a fixed 16 KB stack buffer
# (src/frontend/nd500x/nd500x.c:910 `char outbuf[16384]`), so ONE call can only
# ever emit about 1 KB of code.  Asking for more silently truncates - the run
# that produced only 355 lines for a 128 KB segment looked like a complete
# disassembly, which is exactly the kind of quiet short read that gets reported
# as a finished measurement.
#
# The chunk boundary is handled by RESTARTING at the address of the last line
# the previous chunk printed, and DROPPING that line.  That instruction is the
# one at risk of being cut in half by the buffer, so it is re-decoded from its
# own start address rather than trusted.  No instruction is ever split.
#
# $1 = .DOM path, $2 = program-segment length in bytes, $3 = output file
# Start address is the standard DOM entry 0x08000004 (segment 1 program base
# 0x08000000 + the 4-byte header word every ND linker emits).
set -u
DOM="$1"
LEN="$2"
OUT="$3"
START=$((0x08000004))
END=$((START + LEN))
ADDR=$START
: > "$OUT"
cd "$HOME/repos/nd500x" || exit 1
while [ $ADDR -lt $END ]; do
  HEX=$(printf "0x%X" $ADDR)
  ./build/bin/nd500x --dom "$DOM" --disasm 4096 --addr "$HEX" --radix hex 2>/dev/null \
    | grep -E "^[0-9A-F]{8}: " > /tmp/chunk.asm
  LINES=$(wc -l < /tmp/chunk.asm)
  if [ "$LINES" -lt 2 ]; then
    echo "; STALLED at $HEX (chunk produced $LINES lines)" >> "$OUT"
    break
  fi
  head -n -1 /tmp/chunk.asm >> "$OUT"
  LAST=$(tail -n 1 /tmp/chunk.asm | cut -d: -f1)
  NEXT=$((0x$LAST))
  if [ $NEXT -le $ADDR ]; then
    echo "; NO PROGRESS at $HEX" >> "$OUT"
    break
  fi
  ADDR=$NEXT
done
echo "done: stopped at $(printf 0x%X $ADDR) of $(printf 0x%X $END), $(wc -l < "$OUT") lines"
