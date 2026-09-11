#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/security-corpus/manifest.tsv"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
tp=0
tn=0
fp=0
fn=0

while IFS=$'\t' read -r file label expected; do
  input="$root/security-corpus/$file"
  # Git stores text with LF. Materialize canonical Internet Message CRLF for
  # every case except the fixture intentionally testing bare LF behavior.
  if [[ "$file" == "attack_bare_lf.eml" ]]; then
    tr -d '\r' < "$input" > "$work/$file"
    input="$work/$file"
  else
    awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$input" > "$work/$file"
    input="$work/$file"
  fi
  output="$(moon -C "$root" run --target native cmd/moonmime -- \
    audit "$input" --compatible --json)"
  found=0
  if [[ "$expected" != "none" && "$output" == *"\"code\":\"$expected\""* ]]; then
    found=1
  elif [[ "$expected" == "none" && "$output" == *'"findings":[]'* ]]; then
    found=1
  fi
  if [[ "$label" == "positive" && "$found" -eq 1 ]]; then
    ((tp+=1))
  elif [[ "$label" == "positive" ]]; then
    ((fn+=1))
  elif [[ "$found" -eq 1 ]]; then
    ((tn+=1))
  else
    ((fp+=1))
  fi
done < "$manifest"

echo "MoonMIME synthetic corpus: TP=$tp TN=$tn FP=$fp FN=$fn"
test "$tp" -eq 6
test "$tn" -eq 4
test "$fp" -eq 0
test "$fn" -eq 0
