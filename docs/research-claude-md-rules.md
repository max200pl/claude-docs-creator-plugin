# Research: CLAUDE.md File Creation Rules

> Date: 2026-04-16
> Topic: Official and community rules for writing root and subdirectory CLAUDE.md files
> Sources: Anthropic official docs, Claude Code GitHub issues, community guides

## How Claude Loads CLAUDE.md Files

Loading order (official):

1. Managed policy CLAUDE.md (org-wide, cannot be excluded)
2. `~/.claude/CLAUDE.md` (user-level, all projects)
3. Walk **upward** from cwd: every `CLAUDE.md` + `CLAUDE.local.md` found
4. Subdirectory CLAUDE.md: **lazy-loaded** when Claude reads files in that directory

After `/compact`, root CLAUDE.md is re-injected. Subdirectory files are NOT re-injected — they reload next time Claude reads a file in that directory.

**Known issue:** subdirectory on-demand loading has reliability bugs in VS Code extension ([#2571](https://github.com/anthropics/claude-code/issues/2571), [#24987](https://github.com/anthropics/claude-code/issues/24987)). The more robust alternative is `rules/` with `paths:` frontmatter.

## Root CLAUDE.md Rules

- Under **200 lines** (past 500, context adherence drops)
- Must contain: project overview, build/test/lint commands, architecture, code conventions
- Use `@path` imports to reference existing docs (`@README.md`, `@docs/architecture.md`)
- Use markdown headers and bullets — no walls of text
- Don't include: things Claude can infer from code, standard language conventions, tutorials
- One source of truth per rule — never duplicate between root and subdirectory

## Subdirectory CLAUDE.md Rules

- **Purely additive** — never repeat root content (all files are concatenated, not overridden)
- Under **200 lines** per file
- Loaded **on demand** when Claude reads files in that directory

### What to include

In order of impact:

1. **Code patterns with examples** — agents copy patterns more reliably than abstract rules
2. **Anti-patterns with reasons** — explicit "do NOT do X because Y"
3. **Module-specific commands** — `pnpm --filter web test`, not generic `pnpm test`
4. **Architecture constraints** — "this layer talks to X, not Y"
5. **Design direction** — "active development" vs "legacy, bug fixes only"
6. **File organization** — where new files go, naming patterns
7. **Testing expectations** — what to test, how to mock

### What NOT to include

- Anything Claude can infer by reading the code (imports, obvious patterns)
- File-by-file descriptions (Claude reads files directly)
- Repetition of root CLAUDE.md rules
- Standard framework usage docs

### Recommended structure

```markdown
# Module Name

One sentence: what this module does.

## Patterns

Concrete code examples that Claude should follow.

## Rules

- Do X because Y
- Never do Z because W

## Anti-patterns

- Don't return raw arrays — use DTOs
- Don't accept untyped parameters

## Testing

Module-specific test commands and expectations.
```

### For legacy modules

Brevity itself is the message:

```markdown
# Legacy Module

Bug fixes only. No new features. No new routes. Minimize changes.
```

## Alternative: `rules/` with `paths:`

Anthropic recommends this as the **preferred** approach over subdirectory CLAUDE.md:

```markdown
---
paths:
  - "packages/web/**"
---

# Frontend Rules

Server Components by default. Use 'use client' only when needed.
```

Advantages:
- Explicit glob scoping (more reliable than on-demand loading)
- All rules in one organized directory
- `paths:` triggers on file reads, same intent as subdirectory CLAUDE.md

## Key Principle: Patterns > Rules > Descriptions

Claude follows code patterns (copy this template) more reliably than abstract rules (always do X), and both are more useful than descriptions (this module does Y). Prioritize concrete examples over abstract guidance.

## Sources

- [How Claude remembers your project — Official](https://code.claude.com/docs/en/memory)
- [Best Practices for Claude Code — Official](https://code.claude.com/docs/en/best-practices)
- [Using CLAUDE.md Files — Anthropic Blog](https://claude.com/blog/using-claude-md-files)
- [Give Claude Context — Help Center](https://support.claude.com/en/articles/14553240-give-claude-context-claude-md-and-better-prompts)
- [Subdirectory CLAUDE.md Files — DEV Community](https://dev.to/tacoda/building-the-agent-harness-subdirectory-claudemd-files-dcl)
- [CLAUDE.md in a Monorepo — DEV Community](https://dev.to/anvodev/how-i-organized-my-claudemd-in-a-monorepo-with-too-many-contexts-37k7)
- [Claude Code Monorepo Setup — The Prompt Shelf](https://thepromptshelf.dev/blog/claude-code-monorepo-setup/)
- [Bug #2571: Subdirectory CLAUDE.md not loaded](https://github.com/anthropics/claude-code/issues/2571)
- [Bug #24987: VS Code subdirectory loading](https://github.com/anthropics/claude-code/issues/24987)
- [Claude Code Rules Directory Guide](https://claudefa.st/blog/guide/mechanics/rules-directory)
