# sync-upstream Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a `sync-upstream` Claude Code skill that rebases `KataGoOnAppleSilicon-fork` onto the latest `upstream/master` with pre-flight safety checks and conflict guidance.

**Architecture:** A single skill file at `~/.claude/skills/sync-upstream/SKILL.md` that instructs Claude to run git commands with pre-flight checks (clean tree, upstream remote exists, no rebase in progress), fetch upstream, rebase, and either push cleanly or stop with conflict guidance. No code files — this is a pure skill document.

**Tech Stack:** Claude Code skills (Markdown), git, bash commands

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `~/.claude/skills/sync-upstream/SKILL.md` | The skill itself — all instructions Claude follows when `/sync-upstream` is invoked |

---

### Task 1: Create the skill file

**Files:**
- Create: `~/.claude/skills/sync-upstream/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/.claude/skills/sync-upstream
```

- [ ] **Step 2: Write the skill file**

Create `~/.claude/skills/sync-upstream/SKILL.md` with this exact content:

```markdown
---
name: sync-upstream
description: Sync KataGoOnAppleSilicon-fork with upstream/master using git rebase. Use when the user says "sync upstream", "pull latest upstream", "merge upstream", "rebase onto upstream", or runs /sync-upstream.
---

# sync-upstream

Sync the fork with the latest upstream changes by rebasing fork commits on top of `upstream/master`.

**Upstream:** `https://github.com/ChinChangYang/KataGoOnAppleSilicon`
**Fork:** `https://github.com/AdamGibbons1982/KataGoOnAppleSilicon`

## Known Conflict Danger Zones

Before touching anything, print this reminder to the user:

> **Danger zones to watch during rebase:**
> 1. **Model interface parameters** — two parameter sets must be preserved:
>    - Strongest AI model (28b): `KataGoModel19x19fp16-s12192M.mlpackage`
>    - Easier human SL model: `KataGoModel19x19fp16m1.mlpackage`
> 2. **GTPHandler.swift** — `final_score` command, `KataGoPlay` handling
> 3. **PostProcessing.swift** — fork's documented parameter defaults
> 4. **BoardState.swift** — value extraction methods, 22-plane spatial feature layout
> 5. **SGFMetadata.swift** — fork-only file for human SL `input_meta` tensor; verify present after rebase
> 6. **Package.swift** — Swift tools version and deployment target

## Steps

### 1. Pre-flight checks

Run these checks in order. Stop and report if any fail.

**a) Check for in-progress rebase:**
```bash
ls .git/rebase-merge 2>/dev/null || ls .git/rebase-apply 2>/dev/null
```
If either directory exists → go to **Rebase In Progress Flow** below. Do not proceed with the normal flow.

**b) Check working tree is clean:**
```bash
git status --porcelain
```
If output is non-empty → stop and tell the user:
> "Working tree has uncommitted changes. Please commit or stash them before syncing upstream."
> Then show: `git status`

**c) Check upstream remote exists:**
```bash
git remote get-url upstream
```
If this fails → stop and tell the user:
> "No `upstream` remote found. Add it with:"
> `git remote add upstream https://github.com/ChinChangYang/KataGoOnAppleSilicon.git`

### 2. Fetch upstream

```bash
git fetch upstream
```

### 3. Check if already up to date

```bash
git log HEAD..upstream/master --oneline
```
If output is empty → tell the user "Already up to date. Nothing to sync." and stop.

Otherwise, show the user what's coming in:
> "Found N new upstream commits:"
> (list the commits from the log output)

### 4. Print danger zone reminder

Print the danger zones listed at the top of this skill before starting the rebase.

### 5. Start rebase

```bash
git rebase upstream/master
```

### 6. On clean rebase (exit code 0)

**a) Verify fork files are intact:**
```bash
ls Sources/KataGoOnAppleSilicon/KataGoPlay.swift
grep -l "final_score" Sources/KataGoOnAppleSilicon/GTPHandler.swift
ls Sources/KataGoOnAppleSilicon/Core/SGFMetadata.swift
```
If any of these fail → warn the user that a fork file may have been lost and they should inspect before pushing.

**b) Run swift build to verify nothing is broken:**
```bash
swift build 2>&1
```
If build fails → stop, show the error, and do NOT push. Tell the user to fix the build before pushing.

**c) Push to origin:**
```bash
git push origin master --force-with-lease
```
If push is rejected → tell the user:
> "`--force-with-lease` rejected the push. This means origin has commits not in your local branch (e.g. pushed from another machine). Run `git fetch origin` to inspect, then push manually."

**d) Report success:**
Show the fork commits now sitting on top of upstream:
```bash
git log upstream/master..HEAD --oneline
```
> "Sync complete. Your fork commits are rebased on top of upstream/master."

### 7. On conflict (rebase stopped mid-flight)

Show the user which files have conflicts:
```bash
git diff --name-only --diff-filter=U
```

Tell the user:
> "Rebase paused due to conflicts in the files above. Check the danger zones list — model interface params, GTPHandler, PostProcessing, BoardState, and SGFMetadata are the most likely sources."
>
> **To resolve:**
> 1. Open each conflicting file and resolve the `<<<<<<<` / `=======` / `>>>>>>>` markers
> 2. Stage resolved files: `git add <filename>`
> 3. Continue: `git rebase --continue`
> 4. Repeat for each commit until rebase completes
> 5. Then push: `git push origin master --force-with-lease`
>
> **To cancel entirely:** `git rebase --abort`
>
> Once resolved, run `/sync-upstream` again and it will detect the in-progress rebase and guide you from there.

---

## Rebase In Progress Flow

A rebase is already in progress (`.git/rebase-merge` or `.git/rebase-apply` exists).

Show conflicting files:
```bash
git diff --name-only --diff-filter=U
```

If there are unresolved conflicts, tell the user:
> "A rebase is already in progress with unresolved conflicts in the files above. Resolve the conflict markers, stage the files with `git add <filename>`, then run `git rebase --continue`."

If there are no unresolved conflicts (user may have resolved them manually), offer to continue:
> "A rebase is in progress and there are no remaining conflicts. Run `git rebase --continue` to proceed, or `git rebase --abort` to cancel."

Do NOT start a new rebase while one is in progress.
```

- [ ] **Step 3: Verify the file was created**

```bash
cat ~/.claude/skills/sync-upstream/SKILL.md
```
Expected: full skill content printed without error.

- [ ] **Step 4: Commit the spec and plan to the fork repo**

```bash
cd /Users/adamgibbons/Developer/KataGoOnAppleSilicon-fork
git add docs/superpowers/plans/2026-03-24-sync-upstream-skill.md
git commit -m "docs: add sync-upstream skill implementation plan"
```

---

### Task 2: Perform the first upstream sync using the new skill

Now run the skill for the first time to sync with the 5 new upstream commits.

- [ ] **Step 1: Invoke the skill**

Run: `/sync-upstream`

The skill will:
1. Confirm working tree is clean
2. Confirm upstream remote exists
3. Fetch upstream (already fetched, will be fast)
4. Show the 5 new upstream commits
5. Print danger zone reminder
6. Run `git rebase upstream/master`

- [ ] **Step 2: Handle any conflicts**

If conflicts occur, follow the guidance in the skill's conflict flow. Key files to watch:
- `BoardState.swift` — upstream added multi-board-size support (`boardsize` GTP command, 9x9/13x13)
- `GTPHandler.swift` — upstream changed board size handling, fork has `final_score` additions

- [ ] **Step 3: Verify and push**

After clean rebase or conflict resolution:
```bash
git log upstream/master..HEAD --oneline   # should show fork's own commits
swift build                               # should pass
git push origin master --force-with-lease
```

- [ ] **Step 4: Verify fork files are intact**

```bash
ls Sources/KataGoOnAppleSilicon/KataGoPlay.swift
grep "final_score" Sources/KataGoOnAppleSilicon/GTPHandler.swift
ls Sources/KataGoOnAppleSilicon/Core/SGFMetadata.swift
```
All should succeed.

---

### Task 3: Final skill review and polish

After the first sync is complete, review the skill for any improvements based on what actually happened during the rebase.

- [ ] **Step 1: Review the skill file**

Read `~/.claude/skills/sync-upstream/SKILL.md` and check:
- Were the danger zones accurate?
- Did any steps behave unexpectedly?
- Are there any commands that should be added or adjusted?

- [ ] **Step 2: Make any improvements**

Edit `~/.claude/skills/sync-upstream/SKILL.md` if needed based on findings from the first run.

- [ ] **Step 3: Save a memory about the skill**

Save a memory noting that the `sync-upstream` skill exists and is used to regularly rebase the fork onto upstream.
