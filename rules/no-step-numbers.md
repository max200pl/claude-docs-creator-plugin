# No Step Numbers in Sequential Content

## Rule

Do not use numbered step prefixes (`Step 1:`, `Step 2 —`, `Step N`) in headings, Mermaid `note` labels, or any ordered content where position already implies sequence.

## Why

Numbered steps create a maintenance burden: inserting, removing, or reordering a step forces renumbering of all subsequent steps and every cross-reference to them. The order is already encoded by position in the file.

## Instead

- **Headings:** use descriptive names — `### Detect stack`, not `### Step 2: Detect stack`
- **Mermaid notes:** `note over A,B: Detect stack`, not `note over A,B: Step 2 — Detect stack`
- **Cross-references:** refer by name — "created in **Scaffold .claude structure**", not "created in Step 1"

## Exception

Numbered lists (`1. 2. 3.`) inside a single section are fine — they describe sub-steps within one heading and don't cause cascading renumbers when a top-level section changes.
