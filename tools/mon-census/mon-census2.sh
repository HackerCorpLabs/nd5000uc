#!/bin/bash
# FINAL MON census over a disassembly produced by dis-dom.sh.
#
# Reports TWO separate things, because they are two different questions:
#
#  A. CALL SITES - direct CALL / CALLG into the segment-31 trampoline table.
#       C3 F8 00 hh ll        plain call,  operand renders  $0xF80000nn
#       B5 CF F8 00 hh ll     callg,       operand renders  #0xF80000nn
#     Both forms must be counted.  A scan that knew only C3 dropped all nine of
#     LED's MON 513B calls; a regex that matched only the '$' prefix dropped the
#     same ten callg sites a second time, in a new disguise.
#
#  B. INDIRECT REACH - a trampoline address 0xF80000nn stored into a variable
#     and called through later, e.g.
#         1A CF F8 00 00 A9 6C   w move  #0xF80000A9,b.0xB0
#     The program can reach that MON at run time with no call site anywhere.
#     LED's MON 251B (CopyPage) is only visible this way.
#
# EXCLUDED FROM BOTH: a bare 0xF8000000 used in arithmetic
# (`w1 + #0xF8000000`, `w2 and #0xF8000000`) is segment-31 base arithmetic -
# building or masking a trampoline address - NOT a call to MON 0B.  Counting it
# inflates MON 0B by one in every program.
#
# $1 = disassembly file
set -u
ASM="$1"
C3=$(grep -cE '^[0-9A-F]{8}: C3 F8 00 ' "$ASM")
CG=$(grep -cE '^[0-9A-F]{8}: B5 CF F8 00 ' "$ASM")
echo "call sites: $C3 call + $CG callg = $((C3 + CG))"
echo
echo "A. MON call sites"
echo "  count  MON"
grep -E '^[0-9A-F]{8}: (C3 F8 00 |B5 CF F8 00 )' "$ASM" \
  | grep -oE '[$#]0xF800[0-9A-F]{4}' | sed 's/.*0xF800//' \
  | while read -r h; do printf "%oB\n" $(printf "%d" "0x$h"); done \
  | sort | uniq -c | sort -rn
echo
echo "  distinct MONs called directly: $(grep -E '^[0-9A-F]{8}: (C3 F8 00 |B5 CF F8 00 )' "$ASM" | grep -oE '[$#]0xF800[0-9A-F]{4}' | sed 's/.*0xF800//' | sort -u | wc -l)"
echo
echo "B. Indirect reach (trampoline address stored, not called here)"
grep -E '[$#]0xF800[0-9A-F]{4}' "$ASM" \
  | grep -vE '^[0-9A-F]{8}: (C3 F8 00 |B5 CF F8 00 )' \
  | grep -vE '[$#]0xF8000000' \
  | cut -c1-100
