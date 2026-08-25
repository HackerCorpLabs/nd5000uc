#!/bin/bash
# Print what each program actually said, with the ANSI escapes stripped so a
# full-screen editor's cursor positioning does not drown the text.
set -u
for p in "$@"; do
  echo "######## $p"
  sed -n '/-- .* placed (domain/,/-- program exited/p' "/tmp/baseline/$p.log" \
    | sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/\x1b[<=>]//g' -e 's/\x1b[()][B0]//g' \
    | tr -d '\r' | grep -v '^[[:space:]]*$' | head -14
  echo
done
