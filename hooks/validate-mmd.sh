#!/bin/bash
# PostToolUse(Write|Edit): validate Mermaid .mmd files against mermaid-style rules.
# Lightweight checks (no mmdc dependency): theme directive, no hardcoded colors,
# no direction inside subgraphs. Optional: run `mmdc --parse` if installed.
set -u

# ANSI colors — disabled if NO_COLOR is set (https://no-color.org/)
if [ -z "${NO_COLOR:-}" ]; then
  _R=$'\033[31m' _Y=$'\033[33m' _B=$'\033[1m' _0=$'\033[0m'
else
  _R='' _Y='' _B='' _0=''
fi

f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)
[ -z "$f" ] && exit 0
case "$f" in *.mmd) ;; *) exit 0 ;; esac
[ ! -f "$f" ] && exit 0

errs=()

grep -q "^%%{init:" "$f" || errs+=("missing %%{init: {'theme': 'neutral'}}%% directive")

if grep -qE "rect rgb|rect rgba|style .+ fill:" "$f"; then
  errs+=("hardcoded colors found (rect rgb / style fill) — breaks theme")
fi

# direction inside subgraph — awk state machine
if awk '
  /^subgraph/ {in_sg=1; next}
  /^end$/ {in_sg=0; next}
  in_sg && /^[[:space:]]*direction / {print; exit 1}
' "$f" >/dev/null; then
  :
else
  errs+=("direction keyword found inside a subgraph — breaks in Mermaid 10.x")
fi

# Optional real parse via mmdc if available
if command -v mmdc >/dev/null 2>&1; then
  if ! mmdc -i "$f" -o /tmp/mmd-check-$$.svg 2>/dev/null; then
    errs+=("mmdc parse failed")
  fi
  rm -f /tmp/mmd-check-$$.svg
fi

if [ ${#errs[@]} -gt 0 ]; then
  body=$(printf "  ${_Y}•${_0} %s\n" "${errs[@]}")
  msg=$(printf "${_Y}Mermaid style issues${_0} in ${_B}%s${_0}:\n%s" "$f" "$body")
  jq -n --arg m "$msg" '{systemMessage: $m}'
fi
exit 0
