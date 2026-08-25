#!/bin/bash
# Raw byte scan of a .DOM's PROGRAM segment for segment-31 MON trampoline calls.
#
# This is the SECOND instrument, used to bound the first.  The linear
# disassembler desyncs on embedded data (CAT-CAT5's run carries 124 "???"
# lines, CONVERT's 255, LED's 412) and a desync SILENTLY SWALLOWS real call
# sites - it cost exactly one MON 143B site in CONVERT-DOM at 0x08024CD7.
# So: disassembly = confirmed sites; raw scan = candidate sites.  Where they
# agree the count is solid; where the raw scan finds something the
# disassembly missed, that address needs a targeted re-decode.
#
# A raw scan ALONE is not trustworthy either - it invents hits inside address
# tables (five clustered in 250 bytes of PLANC-500 were a table of trampoline
# addresses, not code).  Neither instrument is the answer; the pair is.
#
# The PROG file offset and virtual base come from nd500x's own load line:
#   DOM Load: Seg[1] PROG: file=0x00001800..0x00020CAF size=128176 load_addr=0x0
# and the segment 1 virtual base is 0x08000000.
#
# $1 = .DOM path, $2 = PROG file offset (hex, e.g. 0x1800), $3 = PROG size (dec)
set -u
DOM="$1"
OFF=$((  $2 ))
LEN="$3"
VBASE=$((0x08000000))
# One byte per line with its file offset, then walk looking for the two
# call encodings.
xxd -s "$OFF" -l "$LEN" -c 1 -p "$DOM" | awk -v off="$OFF" -v vb="$VBASE" '
{ b[NR-1] = strtonum("0x" $1) }
END {
  n = NR
  for (i = 0; i < n - 5; i++) {
    mon = -1
    if (b[i] == 0xC3 && b[i+1] == 0xF8 && b[i+2] == 0x00) {
      mon = b[i+3] * 256 + b[i+4]; form = "call"
    } else if (b[i] == 0xB5 && b[i+1] == 0xCF && b[i+2] == 0xF8 && b[i+3] == 0x00) {
      mon = b[i+4] * 256 + b[i+5]; form = "callg"
    }
    if (mon >= 0) printf "%08X %-5s MON %oB\n", vb + i, form, mon
  }
}'
