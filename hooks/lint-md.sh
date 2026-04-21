#!/bin/bash
# PostToolUse(Write|Edit): run markdownlint on changed .md file.
# Silently no-op if markdownlint-cli2 / markdownlint not installed.
set -u

f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)
[ -z "$f" ] && exit 0
case "$f" in *.md) ;; *) exit 0 ;; esac
[ ! -f "$f" ] && exit 0

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  out=$(markdownlint-cli2 "$f" 2>&1 | head -15)
elif command -v markdownlint >/dev/null 2>&1; then
  out=$(markdownlint "$f" 2>&1 | head -15)
else
  exit 0
fi

if [ -n "$out" ]; then
  msg=$(printf 'markdownlint warnings in %s:\n%s' "$f" "$out")
  jq -n --arg m "$msg" '{systemMessage: $m}'
fi
exit 0
