# OctopusScheduler — Quick Reference

**Current version:** v1.4.0 (build 5)
**Repo:** https://github.com/c-aramai/octopus-scheduler

## Build & Run

```bash
cd ~/ARAMAI/dev/octopus-scheduler/OctopusScheduler

# Build release
xcodebuild -project OctopusScheduler.xcodeproj \
  -scheme OctopusScheduler \
  -configuration Release build \
  CONFIGURATION_BUILD_DIR=./build/release

# Launch
open build/release/OctopusScheduler.app
```

## Kill & Restart

```bash
pkill -f "build/release/OctopusScheduler"; sleep 1
open ~/ARAMAI/dev/octopus-scheduler/OctopusScheduler/build/release/OctopusScheduler.app
```

## Config & State

| File | Purpose |
|------|---------|
| `~/.octopus-scheduler/config.json` | User config (schedules, options, bridge, slack) |
| `~/.octopus-scheduler/state.json` | Machine state (lastFiredAt timestamps) |
| `~/.octopus-scheduler/logs/` | Daily rotating logs |

## Permissions Required

1. **Accessibility** — System Settings > Privacy & Security > Accessibility > add OctopusScheduler.app
2. **Automation: Claude** — one-time OK dialog
3. **Automation: System Events** — one-time OK dialog

Note: Accessibility permission is invalidated on every rebuild (code signature changes). Must re-authorize after each build.

## Monitoring

```bash
# Watch logs live
tail -f ~/.octopus-scheduler/logs/octopus-$(date +%Y-%m-%d).log

# Check state
cat ~/.octopus-scheduler/state.json
```

## Known Issue

AppleScript prompt delivery is unreliable — activates Claude Desktop but keystrokes (paste/enter) often fail silently. Evaluating switch to `claude -p` CLI. See `COWORK-BRIEFING.md` for decision.
