#!/bin/bash
# Cross-check the raw byte scan against the linear disassembly for one program.
# $1 = raw scan output (rawscan.sh), $2 = disassembly (dis-dom.sh)
set -u
cut -d' ' -f1 "$1" | sort -u > /tmp/xc-raw.txt
grep -E '^[0-9A-F]{8}: (C3 F8 00 |B5 CF F8 00 )' "$2" | cut -d: -f1 | sort -u > /tmp/xc-dis.txt
echo "raw hits: $(wc -l < /tmp/xc-raw.txt)   disassembled call sites: $(wc -l < /tmp/xc-dis.txt)"
echo "--- RAW only: the disassembly desynced past a real call site ---"
comm -23 /tmp/xc-raw.txt /tmp/xc-dis.txt
echo "--- DIS only: raw scan missed it (should be empty; raw is a superset) ---"
comm -13 /tmp/xc-raw.txt /tmp/xc-dis.txt
