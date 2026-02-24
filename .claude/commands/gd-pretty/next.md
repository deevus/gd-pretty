---
description: Find the next low-hanging fruit to implement in the formatter
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
---

# Next Formatting Target

Analyze the gd-pretty test suite to find the best next formatting feature to implement, then optionally create desired output files.

## Phase 1 — Triage (fast shell scan)

First, get a quick overview of the test suite state:

1. **Count total test cases**: Glob for `tests/input-output-pairs/*.in.gd` files
2. **Find existing desired files**: Glob for `tests/input-output-pairs/*.desired.*.gd`
3. **Run the test suite** to capture current DESIRED MATCH/MISMATCH status:
   ```bash
   cd /home/sh/Projects/gd-pretty && zig build test 2>&1
   ```
4. **Rank by diff size**: For each test case, compare the `.in.gd` input against the `.spaces.gd` output. Compute the diff size as a proxy for how much formatting work is happening (or not happening). Use:
   ```bash
   cd /home/sh/Projects/gd-pretty/tests/input-output-pairs && for f in *.in.gd; do base="${f%.in.gd}"; out="${base}.spaces.gd"; if [ -f "$out" ]; then lines=$(diff "$f" "$out" | wc -l); echo "$lines $base"; fi; done | sort -n
   ```
5. **Identify zero-diff or low-diff tests**: These are tests where the formatter is barely changing the input — likely because the relevant `write*` methods are stubbed with `writeTrimmed`. These are the candidates.

Skip any test that already has a `.desired.spaces.gd` file AND is already a DESIRED MATCH.

## Phase 2 — Classify candidates (read top 5-8)

For the top 5-8 candidates from Phase 1 (lowest diff, meaning least formatting is happening):

1. **Read the `.in.gd` file** to see the input GDScript
2. **Read the `.spaces.gd` file** to see what the formatter currently produces
3. **Identify what's wrong**: Compare them — what formatting SHOULD be different but isn't? Common issues:
   - Whitespace not being normalized (extra spaces, wrong indentation)
   - Line breaks not being added/removed
   - Operators not being spaced correctly
   - Keywords not being formatted
4. **Cross-reference with stubs**: Check which `write*` methods in `src/GdWriter.zig` are still stubbed (just calling `writeTrimmed`). The relevant stubs tell you what needs implementing.

To find all stubbed methods:
```bash
grep -B1 'try self.writeTrimmed' /home/sh/Projects/gd-pretty/src/GdWriter.zig | grep 'TODO'
```

## Phase 3 — Score and rank

Score each candidate on these criteria (1-5 scale):

| Criterion | Description |
|-----------|-------------|
| **Simplicity** | Fewer node types needed to fix = better. A test needing 1 stub implemented beats one needing 5. |
| **Impact** | Fixing this stub improves OTHER tests too. Check how many tests use this node type. |
| **Isolation** | The fix is self-contained — doesn't require other stubs to be implemented first. |
| **Correctness** | The correct output is unambiguous — GDScript formatting conventions are clear for this case. |
| **Size** | Smaller test file = easier to verify the desired output is correct. |

Compute a weighted total: `Simplicity*3 + Impact*2 + Isolation*2 + Correctness*2 + Size*1`

## Phase 4 — Recommend

Present a structured report:

### Formatter Progress Snapshot
```
Total test cases: N
Tests with desired files: N
  - Matching: N
  - Mismatching: N
Tests without desired files: N
Stubbed write* methods remaining: N
```

### Top Recommendation

For the #1 candidate, provide:
- **Test case**: filename
- **Current state**: What the formatter currently does (brief)
- **What's wrong**: What formatting is missing or incorrect
- **Root cause**: Which stubbed `write*` method(s) need implementing
- **Correct output**: What the GDScript conventions dictate (based on gdtoolkit/GDScript style guide conventions)
- **Implementation scope**: How many lines of code, which files to change
- **Scoring table**: Show the scores

### Runner-up Candidates

List 2-3 runner-up candidates with brief descriptions of what they'd need.

## Phase 5 — Propose desired files

After presenting the recommendation, ask the user:

> Would you like me to create `.desired.spaces.gd` and `.desired.tabs.gd` files for the top recommendation?

If yes:
1. Create `tests/input-output-pairs/{test_name}.desired.spaces.gd` with the correct expected output (4-space indentation)
2. Create `tests/input-output-pairs/{test_name}.desired.tabs.gd` with the correct expected output (tab indentation)
3. Run `zig build test 2>&1` to verify DESIRED MISMATCH is reported
4. Show the test output confirming the desired files are recognized

The desired output should follow GDScript formatting conventions:
- 4 spaces for indentation (spaces variant) or tabs (tabs variant)
- Single space around binary operators (`=`, `+`, `-`, `==`, etc.)
- No space before colons in type hints, space after (`var x: int`)
- Single space after commas
- No trailing whitespace
- Single blank line between functions
- Two blank lines before top-level definitions (classes, functions at module level)
