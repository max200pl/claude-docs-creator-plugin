# How to Create .claude Documentation

> Official docs: <https://code.claude.com/docs/en/claude-directory>

Reference split by topic — choose the section you need:

| Topic | File |
| ---- | ---- |
| CLAUDE.md, settings, rules, extract-to-rule pattern, file loading order | [`how-to-create-rules.md`](how-to-create-rules.md) |
| Skills, agents, commands, output styles, global files (`~/`) | [`how-to-create-skills.md`](how-to-create-skills.md) |

## Checklist for New Documentation

- [ ] Keep CLAUDE.md under 200 lines
- [ ] Use `rules/` for topic-specific guidance
- [ ] Use `paths:` in rules to save context tokens
- [ ] Use `skills/` for repeatable workflows (not `commands/`)
- [ ] Use `agents/` for isolated specialized tasks
- [ ] Use `hooks` and `permissions` for enforced behavior (not CLAUDE.md)
- [ ] Commit shared files, gitignore `*.local.*` files
- [ ] Don't duplicate what's in code or git history
