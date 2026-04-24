# How to Create .claude Rules and Configuration

> Official docs: <https://code.claude.com/docs/en/claude-directory>

Reference for project-level files, settings, rules, and the extract-to-rule pattern.

---

## CLAUDE.md — Project Instructions

**Location:** `./CLAUDE.md` or `./.claude/CLAUDE.md`

Main project file. Loaded every session. Keep under 200 lines.

Must contain at minimum: what the project is, how to build/test/run it, code conventions. Claude cannot work effectively without knowing these basics.

**Examples by stack:**

C++ / MSVC:

```markdown
## Build & Run
- Toolchain: Visual Studio 2022 (MSVC v143), MSBuild
- Build: `msbuild project.sln /p:Configuration=Release`
- Test: `vstest.console.exe bin/tests.dll`
```

Python:

```markdown
## Build & Run
- Toolchain: Python 3.12, uv
- Install: `uv sync`
- Test: `uv run pytest`
- Lint: `uv run ruff check .`
```

Go:

```markdown
## Build & Run
- Toolchain: Go 1.22
- Build: `go build ./...`
- Test: `go test ./...`
- Lint: `golangci-lint run`
```

Node / TypeScript:

```markdown
## Build & Run
- Toolchain: Node 20, pnpm
- Build: `pnpm build`
- Test: `pnpm test`
- Lint: `pnpm lint`
```

Rust:

```markdown
## Build & Run
- Toolchain: Rust 1.78, cargo
- Build: `cargo build`
- Test: `cargo test`
- Lint: `cargo clippy`
```

**Personal overrides:** `CLAUDE.local.md` (add to `.gitignore`)

**Tips:**

- If something only matters for specific tasks, move it to a skill or a path-scoped rule
- Run `/memory` to open and edit CLAUDE.md from within a session

---

## .mcp.json — Project MCP Servers

**Location:** `./.mcp.json` (project root, not inside `.claude/`)

Configures MCP servers shared with your team.

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**Tips:**

- Use `${ENV_VAR}` references for secrets — tokens never land in the file
- For personal servers, run `claude mcp add --scope user` (writes to `~/.claude.json`)

---

## .worktreeinclude — Files to Copy into Worktrees

**Location:** `./.worktreeinclude` (project root)

Lists gitignored files to copy into each new worktree. Uses `.gitignore` syntax.

```text
# Local environment
.env
.env.local

# API credentials
config/secrets.json
```

---

## Settings — Permissions, Hooks & Config

**Location:** `.claude/settings.json`

Settings that Claude Code **enforces** (unlike CLAUDE.md which is guidance).

```json
{
  "permissions": {
    "allow": [
      "Bash(git log *)",
      "Bash(git diff *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force *)"
    ]
  },
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "echo 'File changed: $FILE'"
      }]
    }]
  }
}
```

**Contains:** permissions, hooks, statusLine, model, env, outputStyle

**Personal overrides:** `.claude/settings.local.json` (gitignored)

**Tips:**

- Bash permission patterns support wildcards: `Bash(make *)` matches any command starting with `make`
- Array settings (`permissions.allow`) combine across scopes; scalar settings (`model`) use the most specific value
- Add project-specific build/test commands to `allow` for your stack

---

## Rules — Topic-Scoped Instructions

**Location:** `rules/<name>.md`

Rules are guidance Claude reads, not configuration Claude Code enforces. Two types:

### Unconditional (always loaded)

```markdown
# Code Style

- Use 4 spaces for indentation
- PascalCase for classes
```

### Conditional (loaded when matching files are read)

```markdown
---
paths:
  - "src/api/**/*.py"
---

# API Design Rules

- All endpoints must validate input with Pydantic models
- Return shape: {"data": T} | {"error": str}
```

**Frontmatter fields:**

- `paths:` — glob patterns, rule loads only when Claude reads matching files
- `alwaysApply: true` — force load even without paths match
- `description:` — helps Claude decide relevance

**Tips:**

- Subdirectories work: `rules/frontend/components.md` is discovered automatically
- When CLAUDE.md approaches 200 lines, start splitting into rules

---

## Pattern: Extract Workflow From CLAUDE.md Into a Scoped Rule

**When to apply:** CLAUDE.md has grown past 200 lines and contains a workflow-heavy section (step-by-step instructions, long translation tables, multi-file procedures) that is only relevant when the user is actively working on a specific subset of files.

**Why it works:** CLAUDE.md loads every session. A scoped rule (`rules/<topic>.md` with `paths:` frontmatter) loads only when Claude reads a file matching the glob. Moving a 100-line workflow from CLAUDE.md to a scoped rule means that content loads 10-20% of the time instead of 100% — huge context saving.

**How to apply:**

1. Identify the workflow-heavy section — typical markers: ordered multi-step procedures, stack-specific tool call sequences, translation tables mapping external inputs (Figma, API, etc.) to project outputs.
2. Decide the glob — what files is this workflow actually about? If it governs `res/` components → `paths: ["res/**"]`. If it's about test authoring → `paths: ["tests/**"]`.
3. Create `rules/<topic>.md` with frontmatter:

   ```markdown
   ---
   description: "<one-line what this rule covers>. Loads when <when it applies>."
   paths:
     - "<glob-1>"
     - "<glob-2>"
   ---

   # <Topic>
   ```

4. Move the section content into the new rule file verbatim. Headings demote by one level if the section was `##` in CLAUDE.md and becomes `##` in the rule (it was already top-level logically).
5. In CLAUDE.md, replace the removed section with a one-paragraph pointer:

   ```markdown
   ## <Topic>

   Full rules live in `rules/<topic>.md` (auto-loaded on <when>). Edge-cases: `rules/<related>.md`.
   ```

6. Verify CLAUDE.md line count dropped, the rule's `paths:` glob matches real files, and the pointer in CLAUDE.md is readable as a navigation hint.

**Example pairs:**

| Section type | Rule filename | Typical paths: |
| ---- | ---- | ---- |
| Figma / design-tool workflow | `figma-mcp.md` | `res/**`, `**/*.figma.ts` |
| CSS/styling conventions | `<framework>-css.md` | `res/**/*.css` |
| Typography / fonts | `<framework>-typography.md` | `res/**/*.css`, `**/typography.css` |
| Testing conventions | `testing.md` | `tests/**`, `**/*.test.*` |
| API contract writing | `api-design.md` | `src/api/**` |

**Counter-example — do NOT extract:**

- Project overview (what the project is) — belongs in CLAUDE.md
- Build / test / lint commands — every session needs these, keep in CLAUDE.md
- Git conventions — load every session
- Short rules (under ~15 lines) — overhead of a separate file isn't worth it

---

## File Loading Order

```text
~/.claude/CLAUDE.md              # Global (all projects)
  ↓
./CLAUDE.md                      # Project root
  ↓
./CLAUDE.local.md                # Personal overrides
  ↓
./rules/*.md             # Unconditional rules
  ↓
./rules/*.md (paths:)    # Conditional rules (on file read)
  ↓
./subdir/CLAUDE.md               # Subdirectory (on demand)
```

**Settings precedence:** global `settings.json` → project `settings.json` → `settings.local.json` → CLI flags → managed settings
