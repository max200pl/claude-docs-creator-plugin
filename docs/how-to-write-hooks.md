# How to Write Toolkit Hooks

Hooks are shell scripts executed by Claude Code at lifecycle events. This guide covers patterns for `hooks/` (public-layer, shipped with plugin) and `.claude/hooks/` (internal-layer, toolkit-dev only).

## ANSI Color Standard

All hooks that produce user-visible terminal output SHOULD include ANSI color support. Use this block verbatim at the top of every hook script that outputs colored text:

```bash
# ANSI colors — disabled if NO_COLOR is set (https://no-color.org/)
if [ -z "${NO_COLOR:-}" ]; then
  _R=$'\033[31m' _Y=$'\033[33m' _G=$'\033[32m' _B=$'\033[1m' _0=$'\033[0m'
else
  _R='' _Y='' _G='' _B='' _0=''
fi
```

Variable names:

| Var | ANSI | Use for |
| --- | ---- | ------- |
| `_R` | red | errors (`[ERR]`), file names in error context |
| `_Y` | yellow | warnings (`[WARN]`), `⚠` symbols |
| `_G` | green | success (`[OK]`) |
| `_B` | bold | section headers, important labels |
| `_0` | reset | always append after each colored span |

Apply in output strings:

```bash
echo "${_Y}[WARN]${_0} $file:$line → $target (not found)"
echo "${_R}[ERR]${_0}  $file:$line → $target (layer violation)"
echo "${_G}[OK]${_0} $n file(s) scanned, no issues."
```

**Why NO_COLOR:** The `NO_COLOR` environment variable is the de-facto standard for disabling terminal colors in CLI tools (<https://no-color.org>). Always respect it. Users in CI, pipes, or screen readers expect plain text when they set `NO_COLOR=1`.

## systemMessage vs direct stdout

Two output paths in Claude Code hooks:

| Output path | How | Colors work? |
| ----------- | --- | ------------ |
| `systemMessage` JSON | `jq -n --arg m "$msg" '{systemMessage: $m}'` | Yes — ANSI bytes pass through jq as raw bytes; Claude Code forwards them to the terminal which renders colors |
| Direct stdout/stderr | `echo`, `printf` | Yes — only when running standalone (not as hook) |
| `hookSpecificOutput` JSON | `jq -n ... '{hookSpecificOutput: {...}}'` | Avoid — injected into model context, not displayed to user directly |

ANSI codes in `systemMessage` work because:

1. `jq --arg` preserves raw bytes (`$'\033[31m'` → `[31m` in JSON)
2. Claude Code parses the JSON, extracts the string, prints to terminal
3. Terminal interprets the ANSI sequences

## Output tag conventions

All hooks producing structured output MUST use these tags (from `rules/output-format.md`):

```bash
"${_G}[OK]${_0}   description"   # no issues
"${_Y}[WARN]${_0} description"   # advisory
"${_R}[ERR]${_0}  description"   # must fix
"${_B}[FIX]${_0}  description"   # auto-fix applied (when hook also writes)
```

Tags are 7 characters wide including trailing space — align with a space after the tag.

## Hook output modes

Most hooks in this toolkit handle two modes in one script:

```bash
MODE_HOOK=0  # running as a Claude Code PostToolUse hook (stdin = JSON payload)
# vs
MODE_FILE=$1 # running standalone from the terminal (arg = file path or --all)
```

In hook mode: wrap output in `jq -n --arg m "$msg" '{systemMessage: $m}'` and exit 0 (never block writes from a PostToolUse hook).

In standalone mode: write directly to stdout, exit 2 if issues found (non-zero = CI-friendly).

## Glob enumeration in hooks

When scanning multiple `.mmd` or `.md` files, use `find` instead of shell globs to avoid double-matching:

```bash
# Wrong — sequences/**/*.mmd + sequences/*.mmd both match flat files:
for f in sequences/**/*.mmd sequences/*.mmd; do ...

# Correct — find deduplicates naturally:
find sequences/ .claude/sequences/ -name '*.mmd' | sort -u
```
