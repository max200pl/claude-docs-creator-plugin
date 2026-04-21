# Context Compression Strategy

> Goal: Claude loads only what's needed for the current task. Less context = better accuracy + faster responses.

## The Problem

A large project with 20+ modules can easily generate 500+ lines of documentation. If everything is in CLAUDE.md, Claude loads it **every session**, wasting context on modules you're not touching.

## The Solution: Layered Context

Split documentation into layers that load on demand:

```text
CLAUDE.md (80-120 lines)         ← always loaded: overview, build, conventions
  ↓
module/CLAUDE.md                 ← loaded when Claude reads files in that module
  ↓
rules/
  module-x.md (paths: module-x/**)   ← loaded only when Claude reads module-x
  ui-layer.md (paths: **/ui/**)      ← loaded only when Claude reads UI files
  data-layer.md (paths: **/db/**)    ← loaded only when Claude reads DB files
```

**Result:** ~130 lines per session instead of 500+.

## Three Project Types

### Type 1: Single-Stack

One language, one build system, flat modules. All share conventions.

```text
my-project/
├── CLAUDE.md                          ← overview + build + conventions
├── rules/
│   ├── module-a.md                    ← paths: ["src/module-a/**"]
│   ├── module-b.md                    ← paths: ["src/module-b/**"]
│   └── testing.md                     ← paths: ["**/*test*"]
```

**Detection:** single build system marker at root, no workspace config.

### Type 2: Clean Monorepo (distinct areas)

Separate areas with different stacks. Each area has its own build commands and conventions.

```text
my-monorepo/
├── CLAUDE.md                          ← global: architecture, git, CI
├── area-web/CLAUDE.md                 ← web stack: build, conventions
├── area-api/CLAUDE.md                 ← api stack: build, conventions
├── rules/
│   ├── area-web-components.md         ← paths: ["area-web/src/components/**"]
│   ├── area-api-routes.md             ← paths: ["area-api/routes/**"]
```

**Detection:** workspace config (`pnpm-workspace.yaml`, `nx.json`, `go.work`), or different build system markers in different top-level directories.

### Type 3: Feature Monorepo (cross-cutting layers)

Modules organized by **feature**, but some concerns **cut across modules**. UI, data access, or shared patterns are not in one place — they're spread across multiple modules.

```text
my-app/
├── CLAUDE.md                          ← overview, build, global conventions
├── modules/
│   ├── hub-module/                    ← main app (integrates all modules)
│   │   ├── CLAUDE.md                  ← hub-specific: integration, UI framework
│   │   ├── src/                       ← bridge code connecting modules to UI
│   │   └── ui/                        ← UI components
│   ├── feature-a/                     ← feature module (core logic)
│   ├── feature-b/                     ← feature module (core logic)
│   ├── feature-c/                     ← feature module (core logic)
│   ├── shared/                        ← shared utilities and types
│   └── ... more modules
├── rules/
│   ├── feature-a.md                   ← paths: ["modules/feature-a/**"]
│   ├── feature-b.md                   ← paths: ["modules/feature-b/**"]
│   ├── feature-c.md                   ← paths: ["modules/feature-c/**"]
│   │
│   ├── ui-layer.md                    ← paths: ["**/ui/**"]
│   │                                    cross-cutting: UI patterns and conventions
│   ├── bridge-layer.md                ← paths: ["**/*-bridge.*", "**/*-adapter.*"]
│   │                                    cross-cutting: integration pattern
│   └── core-pattern.md               ← paths: ["**/core.*", "**/service.*"]
│                                        cross-cutting: core module lifecycle
```

**Detection:** modules organized by feature (not by layer), same file patterns appearing in multiple modules, one hub module that integrates all others.

**Key insight:** the architecture has two dimensions:

| Dimension | Example | How to document |
| ---- | ---- | ---- |
| **Feature modules** | feature-a, feature-b | Per-module rule with `paths:` |
| **Cross-cutting layers** | UI, bridge, core pattern | Layer rule with file-type `paths:` |

Claude working on `modules/feature-a/src/core.cpp` loads:

- CLAUDE.md (root) — always
- `rules/feature-a.md` — module context
- `rules/core-pattern.md` — core conventions

Claude working on `modules/hub-module/ui/FeaturePage.js` loads:

- CLAUDE.md (root) — always
- `modules/hub-module/CLAUDE.md` — hub module context
- `rules/ui-layer.md` — UI conventions

Neither session loads the other's context.

## When to Use Subdirectory CLAUDE.md

**Not every module needs one.** Create `module/CLAUDE.md` only when:

- Module has its own **stack or build system** (different from root)
- Module is a **hub** that integrates many other modules
- Module is **large** (50+ files) with its own conventions
- Module has **mixed concerns** (backend + frontend in same dir)

**Skip it for:** small feature modules (5-20 files), utility modules, modules that follow global conventions.

| Module type | Subdirectory CLAUDE.md? | Per-module rule? |
| ---- | ---- | ---- |
| Hub module (main app) | Yes — stack, build, integration | Yes — key components |
| Large feature (20-50 files) | Maybe — only if own conventions | Yes — API, deps |
| Small feature (under 20 files) | No | Maybe — skip if trivial |
| Shared library | Yes — if used by many modules | Yes — exports, patterns |

## What Goes Where

### Root CLAUDE.md (always loaded, under 200 lines)

- Project name and description
- Build / test / lint / run commands
- Module list with one-liner each (no internals)
- Global code conventions
- Git conventions
- Architecture: how modules communicate

### Subdirectory CLAUDE.md (loaded on demand)

- This module's role and what makes it different
- Module-specific build commands (if different from root)
- Module-specific conventions (if different from global)
- Key directories within the module

### Per-Module Rules (loaded on demand)

- What the module does (2-3 sentences)
- Key classes and their roles (public API only)
- Cross-module signals/events/exports
- Dependencies graph

### Cross-Cutting Layer Rules (loaded by file type)

- Pattern description (what this layer is for)
- File conventions for this layer
- Shared patterns/interfaces all implementations follow
- Common mistakes to avoid

## Sizing Guide

| Project type | Root CLAUDE.md | Sub CLAUDE.md | Module rules | Layer rules | Per session |
| ---- | ---- | ---- | ---- | ---- | ---- |
| Small single-stack | 50-80 | 0 | 0-3 | 0 | ~100 |
| Large single-stack | 100-150 | 0 | 10-20 | 2-4 | ~180 |
| Clean monorepo | 60-80 | 40-60 each | 5-10 | 1-3 | ~160 |
| Feature monorepo | 80-120 | 30-60 (hubs only) | 10-25 | 3-6 | ~200 |

## Anti-Patterns

- Putting module internals in root CLAUDE.md — wastes context every session
- Creating rules without `paths:` — same as putting it in CLAUDE.md
- Duplicating global conventions in rules
- Rules longer than 50 lines — split further
- Documenting things derivable from code
- Creating subdirectory CLAUDE.md for every module — only for hubs and large modules
- Organizing rules only by module, ignoring cross-cutting layers
- Mixing module context and layer context in one rule
- Using project-specific names in template rules — keep generic
