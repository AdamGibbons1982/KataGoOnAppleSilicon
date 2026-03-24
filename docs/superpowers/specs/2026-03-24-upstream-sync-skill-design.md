# Upstream Sync Skill — Design Spec

**Date:** 2026-03-24
**Status:** Approved

---

## Goal

Create a reusable Claude Code skill (`sync-upstream`) that pulls the latest changes from `upstream/master` (ChinChangYang/KataGoOnAppleSilicon) and rebases the fork's commits on top of them. The skill is designed to be run regularly as part of maintaining the solo fork used by the Goban3D iOS/macCatalyst app.

---

## Context

- **upstream**: `https://github.com/ChinChangYang/KataGoOnAppleSilicon` — the source project
- **origin**: `https://github.com/AdamGibbons1982/KataGoOnAppleSilicon` — the solo fork
- The fork adds features for Goban3D integration: `KataGoPlay`, `final_score` GTP command, score display, illegal move prevention, and model parameter sets for two model tiers (strongest 28b AI model and an easier human SL model)
- The fork is solo-use — no collaborators — so rebase is safe and preferred for clean linear history
- **Note on first run:** The repo previously used merge-based sync (`3c281e7 Merge upstream/master into fork`). The first rebase run will replay only the fork's own commits on top of upstream; the old merge commit will no longer appear at the tip of the log. This is expected and correct.

---

## Known Conflict Danger Zones

These areas are most likely to need manual attention during rebase:

1. **Model interface parameters** — the fork maintains two parameter sets:
   - Strongest AI model (28b, `KataGoModel19x19fp16-s12192M.mlpackage`)
   - Easier human SL model (`KataGoModel19x19fp16m1.mlpackage`)
   - Upstream may change these interfaces; our versions must be preserved for Goban3D compatibility
2. **GTPHandler extensions** — `final_score`, `KataGoPlay` command handling (`GTPHandler.swift`)
3. **PostProcessing parameters** — fork has documented defaults that differ from upstream defaults (`PostProcessing.swift`)
4. **BoardState and input feature encoding** — `BoardState.swift` is actively evolved by both fork and upstream; the 22-plane spatial feature layout and value extraction methods are high-conflict-risk
5. **SGFMetadata** — `SGFMetadata.swift` is fork-only (human SL model `input_meta` tensor); verify it is still present after every rebase
6. **Package.swift** — Swift tools version and deployment target; upstream changes here are build-breaking and easy to overlook

---

## Approach: `git rebase upstream/master`

Rebase replays the fork's commits on top of the latest upstream commit, giving a clean linear history. This is appropriate for a solo fork.

### Steps the skill performs

1. **Pre-flight checks:**
   - Verify `upstream` remote exists — halt with helpful message if not
   - Verify working tree is clean (`git status --porcelain`) — halt with clear message if uncommitted changes exist
   - Check for in-progress rebase (`.git/rebase-merge/` or `.git/rebase-apply/`) — if found, skip to "rebase already in progress" flow (see below)

2. **Fetch upstream** — `git fetch upstream`

3. **Check if already up to date** — compare `HEAD` with `upstream/master`; if identical, report "Already up to date. Nothing to sync." and stop.

4. **Warn about danger zones** — print a reminder listing the danger zones above before touching anything

5. **Start rebase** — `git rebase upstream/master`

6. **On clean rebase** — push to origin with `git push origin master --force-with-lease`, report success with `git log upstream/master..HEAD --oneline` to confirm fork commits are on top

7. **On conflict** — stop, show which files have conflicts, remind user of danger zones, give exact commands:
   - Resolve conflicts in editor
   - `git add <resolved files>`
   - `git rebase --continue`
   - Or `git rebase --abort` to cancel entirely
   - After resolving all conflicts and continuing: `git push origin master --force-with-lease`
   - If push is rejected by `--force-with-lease`: run `git fetch origin` to inspect divergence before retrying

### Rebase already in progress flow

If `.git/rebase-merge/` or `.git/rebase-apply/` exists at startup:

- Report: "A rebase is already in progress."
- Show conflicting files if any: `git diff --name-only --diff-filter=U`
- Offer only two options:
  - `git rebase --continue` — after resolving all conflicts and staging files
  - `git rebase --abort` — to cancel and restore to pre-rebase state

### What the skill does NOT do

- Does not auto-resolve conflicts
- Does not force-push without `--force-with-lease`
- Does not touch any other branches

---

## Skill Trigger

User says: "sync upstream", "pull latest upstream", "merge upstream", "rebase onto upstream", or runs `/sync-upstream`

---

## Success Criteria

After a successful sync:

```bash
# Fork commits sit on top of upstream — N = number of fork commits
git log upstream/master..HEAD --oneline

# Specific fork files are present and intact
ls Sources/KataGoOnAppleSilicon/KataGoPlay.swift
grep "final_score" Sources/KataGoOnAppleSilicon/GTPHandler.swift
ls Sources/KataGoOnAppleSilicon/Core/SGFMetadata.swift

# Build passes
swift build
```

---

## Testing

After each sync run:
```bash
git log --oneline -15                           # verify linear history, upstream commits at base
git log upstream/master..HEAD --oneline         # verify fork commits are on top
swift build                                     # verify build still passes
```
