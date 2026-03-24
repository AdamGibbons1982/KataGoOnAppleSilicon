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

---

## Known Conflict Danger Zones

These areas are most likely to need manual attention during rebase:

1. **Model interface parameters** — the fork maintains two parameter sets:
   - Strongest AI model (28b, `KataGoModel19x19fp16-s12192M.mlpackage`)
   - Easier human SL model (`KataGoModel19x19fp16m1.mlpackage`)
   - Upstream may change these interfaces; our versions must be preserved for Goban3D compatibility
2. **GTPHandler extensions** — `final_score`, `KataGoPlay` command handling
3. **PostProcessing parameters** — fork has documented defaults that differ from upstream defaults

---

## Approach: `git rebase upstream/master`

Rebase replays the fork's commits on top of the latest upstream commit, giving a clean linear history. This is appropriate for a solo fork.

### Steps the skill performs

1. **Fetch upstream** — `git fetch upstream`
2. **Warn about danger zones** — print a reminder about model interface params before touching anything
3. **Start rebase** — `git rebase upstream/master`
4. **On clean rebase** — push to origin with `git push origin master --force-with-lease`, report success
5. **On conflict** — stop, show which files have conflicts, remind user of danger zones, give exact commands to continue or abort:
   - Resolve conflicts in editor
   - `git add <resolved files>`
   - `git rebase --continue`
   - Or `git rebase --abort` to cancel entirely
6. **After conflict resolution** — user re-runs the skill (or continues manually) to push

### What the skill does NOT do

- Does not auto-resolve conflicts
- Does not force-push without `--force-with-lease` (safe guard)
- Does not touch any other branches

---

## Skill Trigger

User says: "sync upstream", "pull latest upstream", "merge upstream", "rebase onto upstream", or runs `/sync-upstream`

---

## Success Criteria

- Upstream commits appear in `git log` before fork commits
- All fork-specific files (`KataGoPlay`, `final_score`, model param sets) are intact after rebase
- `swift build` passes after sync
- Origin is updated

---

## Testing

After each sync run:
```bash
git log --oneline -15          # verify linear history, upstream commits at base
swift build                    # verify build still passes
git diff HEAD~N..HEAD          # verify fork commits are intact
```
