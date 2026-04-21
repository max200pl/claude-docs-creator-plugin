---
name: research
scope: shared
description: "Research a topic via web search and save a structured report with real links to docs/"
user-invocable: true
argument-hint: "<topic> [context]"
---

# Research

> **Flow:** read `sequences/research.mmd` — the sequence diagram is the source of truth for execution order
> Output rules: read `rules/output-format.md`

Web research on a topic, producing a structured report saved to `docs/`. Each report includes real sources, key findings, and actionable recommendations.

## Usage

`/research <topic> [context]`

- `/research init best practices` — research how to initialize project docs
- `/research monorepo patterns for Go` — research monorepo approaches
- `/research Claude Code hooks` — research hook configuration patterns

## Report Format

Every report is saved to `docs/research-<topic-slug>.md` with this structure:

```markdown
# Research: <Topic Title>

> Date: <YYYY-MM-DD>
> Topic: <what was researched and why>
> Sources: <source types — official docs, community, blogs>

## <Finding Section 1>

Content with specific details, not generic summaries.

## <Finding Section 2>

...

## Gaps / Opportunities

| Gap | Priority | Why |
| ---- | ---- | ---- |
| ... | High/Medium/Low | ... |

## Recommendations

Actionable next steps based on findings.

## Sources

- [Title](url) — each source with a real, clickable link
```

## Reference

### Search strategy

1. Start with official documentation (Claude Code docs, framework docs)
2. Search for community guides and blog posts
3. Search for GitHub repos with examples or best practices
4. Cross-reference findings across 3+ sources before including

### Quality rules

- **Real links only** — every source must have a valid URL, no fabricated links
- **Specific findings** — "use `@path` imports" not "follow best practices"
- **Comparison** — if researching for an existing skill, compare current state vs findings
- **Gaps table** — always include a gaps/opportunities table with priorities
- **Actionable** — end with concrete recommendations, not vague suggestions

### File naming

Slug the topic for the filename:

- "init best practices" → `research-init-best-practices.md`
- "monorepo patterns" → `research-monorepo-patterns.md`
- "Claude Code hooks" → `research-claude-code-hooks.md`

If a research file for the topic already exists, **update it** (add new findings, update date) rather than creating a duplicate.

### What NOT to include

- Generic advice that applies to everything ("write clean code")
- Opinions without sources
- Links to paywalled content without noting the paywall
- Outdated information (check dates on sources)

## Output

After saving the report, show a summary:

```text
╭─ Research Complete ─────────────────────────────────────────╮
│                                                             │
│  Topic        <topic>                                       │
│  Sources      N links (N official, N community, N blog)     │
│  Saved to     docs/research-<slug>.md               │
│                                                             │
│  Key findings:                                              │
│    • <finding 1>                                            │
│    • <finding 2>                                            │
│    • <finding 3>                                            │
│                                                             │
│  Gaps found:  N (N high, N medium, N low priority)          │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
```
