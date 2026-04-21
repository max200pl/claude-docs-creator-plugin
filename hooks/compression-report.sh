#!/usr/bin/env bash
# Stop hook — emit a compression report via systemMessage.
# Measures auto-load context cost: CLAUDE.md + rules that load unconditionally
# (no paths: frontmatter). Compares against the last recorded snapshot and
# shows a compact delta.
#
# State lives in .claude/state/compression-snapshot.txt. First run captures
# baseline; subsequent runs show delta and update the snapshot.

set -u
STATE_DIR=".claude/state"
SNAP="$STATE_DIR/compression-snapshot.txt"
mkdir -p "$STATE_DIR"

count_lines() {
  [[ -f "$1" ]] || { echo 0; return; }
  wc -l < "$1" | tr -d ' '
}

has_paths_frontmatter() {
  awk '/^---$/{c++; next} c==1 && /^paths:/{print "yes"; exit} c==2{exit}' "$1" | grep -q yes
}

# Measure auto-load surface
claude_md_lines=$(count_lines "CLAUDE.md")
[[ "$claude_md_lines" == "0" ]] && claude_md_lines=$(count_lines ".claude/CLAUDE.md")

unconditional_rule_lines=0
unconditional_rule_count=0
conditional_rule_count=0
for r in rules/*.md; do
  [[ -f "$r" ]] || continue
  if has_paths_frontmatter "$r"; then
    conditional_rule_count=$((conditional_rule_count + 1))
  else
    n=$(count_lines "$r")
    unconditional_rule_lines=$((unconditional_rule_lines + n))
    unconditional_rule_count=$((unconditional_rule_count + 1))
  fi
done

total_autoload=$((claude_md_lines + unconditional_rule_lines))
est_tokens=$((total_autoload * 18 / 10))  # ~1.8 tokens/line rough

# Compare with snapshot
delta=""
delta_sign=""
if [[ -f "$SNAP" ]]; then
  prev=$(awk '/^autoload_lines=/{split($0,a,"="); print a[2]}' "$SNAP" 2>/dev/null || echo 0)
  prev=${prev:-0}
  if [[ "$prev" != "0" ]]; then
    diff=$((total_autoload - prev))
    if [[ "$diff" -lt 0 ]]; then
      delta="$((-diff)) lines reclaimed vs last session"
      delta_sign="↓"
    elif [[ "$diff" -gt 0 ]]; then
      delta="+${diff} lines vs last session (growth)"
      delta_sign="↑"
    else
      delta="unchanged vs last session"
      delta_sign="="
    fi
  fi
fi

# Write new snapshot
cat > "$SNAP" <<EOF
timestamp=$(date +%s)
autoload_lines=${total_autoload}
claude_md_lines=${claude_md_lines}
rules_unconditional=${unconditional_rule_count}
rules_conditional=${conditional_rule_count}
EOF

# Compose report — only emit if we have something meaningful
if [[ "$total_autoload" == "0" ]]; then
  exit 0
fi

msg="Auto-load cost: ${total_autoload} lines (~${est_tokens} tokens)  •  CLAUDE.md ${claude_md_lines}  •  rules ${unconditional_rule_count} uncond + ${conditional_rule_count} scoped"
if [[ -n "$delta" ]]; then
  msg="${msg}  •  ${delta_sign} ${delta}"
fi

jq -n --arg m "$msg" '{systemMessage: $m}'
exit 0
