# Output Format Convention

## Rule

All skills that produce reports or status output must use consistent formatting for readability.

## Box Drawing

Use Unicode box-drawing for sections:

```text
╭─ Title ─────────────────────────────────────────────────────╮
│  Content here                                               │
╰─────────────────────────────────────────────────────────────╯
```

For inner sections use lighter borders:

```text
  ┌─ Section ─────────────────────────────────────────────────┐
  │  Content                                                  │
  └───────────────────────────────────────────────────────────┘
```

Max width: 65 characters (fits terminals 80+ wide with margin).

## Status Icons

| Icon | Meaning | When to use |
| ---- | ---- | ---- |
| `✓` | Healthy / passed | Check passed, file exists, valid |
| `✗` | Error / broken | Missing required file, invalid syntax |
| `⚠` | Warning | Non-critical issue, needs attention |
| `💡` | Suggestion | Optional improvement |
| `—` | Not applicable | Intentionally skipped |

## Severity Tags

Use bracketed tags for line-item reports:

```text
[OK]   description
[WARN] description
[ERR]  description
[FIX]  description (when auto-fixed)
```

Align tags: `[OK]   ` `[WARN] ` `[ERR]  ` `[FIX]  ` — all 7 chars wide.

## Progress Bars

Use block characters, 6-12 chars wide:

```text
██████░░░░░░  50%     (6 filled, 6 empty = 50%)
████████████  100%    (all filled)
░░░░░░░░░░░░  0%     (all empty)
```

Characters: `█` filled, `░` empty.

## Summary Line

End reports with a separator and summary:

```text
───
N files scanned, N fixes applied, N warnings
```

## When to Apply

- `/status` — full dashboard with boxes, bars, icons
- `/validate-claude-docs` — line-item report with severity tags
- `/sleep` — line-item report with `[FIX]` tags + summary
- `/menu` — command table with box + suggestion box
- `/init-project` report phase — compact stats with severity tags
