# OctopusScheduler — Sprint 1.5 Briefing

**Date:** 2026-02-08
**From:** logos-ui session (Opus 4.6)
**Repo:** https://github.com/c-aramai/octopus-scheduler
**Current version:** v1.5.0 (3 commits: bb9022c, 7e737d3, d7c6efd)

## What Shipped Tonight

### Dual-Mode Prompt Delivery
- **Primary:** Claude Code CLI (`claude -p --print`) — headless, reliable, no Accessibility permission needed
- **Fallback:** AppleScript automation (original method, kept for machines without CLI)
- `sendPrompt()` tries CLI first, falls back to AppleScript automatically
- CLI path configurable via `globalOptions.claudeCLIPath` in config.json
- First-launch wizard prompts CLI install if not found

### Menu UX Overhaul
- Per-workflow submenus with: schedule timing, next fire, last run, prompt file
- Inline **Run Now** (with hourglass feedback), **Open Prompt...**, **Edit Schedule...**, **Pause/Resume**
- Removed clunky separate "Run Now" submenu
- **+ New Workflow...** creates blank schedule and opens editor
- Status text: white when active, gray when degraded
- `KeyableWindow` subclass fixes keyboard input in menu bar app windows

### Schedule Editor (GUI)
- Edit name, time, days of week (toggle buttons), prompt file, enabled, new conversation, Slack channel
- **Auto-save** with debounce — green "Saved" pill flashes on changes
- **Open Prompt** icon opens .md file in default editor (or prompts folder if file doesn't exist)
- **Edit JSON** opens config.json directly
- **Delete** with confirmation dialog
- **Slack Test** button validates webhook + channel with human-readable errors

### Settings Window
- Replaced broken TabView with segmented picker (General | Schedules | Notifications | Help | About)
- **Help tab** with setup guide, config reference, prompt templates, file locations, troubleshooting
- Save closes window and returns to menu

### Slack Integration Fix
- Fixed webhook payload from raw JSON to proper Slack format `{"text": "..."}`
- Emoji status prefixes: Started, Completed, Failed
- Per-workflow `slackChannel` in schedule options (overrides global default)
- Auto-strips `#` prefix from channel names

## Known Issues / Backlog

1. **Slack webhook 404** — User's webhook URL returning 404. Needs investigation (likely expired webhook). The error is now shown cleanly as "Webhook URL not found — check Settings"
2. **Slack channel validation** — Test button works but depends on valid webhook URL first
3. **macOS notification permission** — UNUserNotificationCenter may need explicit permission grant for unsigned builds
4. **Run Now feedback** — Hourglass shows but takes 15-20s for CLI to complete. Consider progress indicator or estimated time

## Files Modified (from v1.4.0)

| File | Changes |
|------|---------|
| `Services/ClaudeAutomator.swift` | CLI delivery, fallback, CLI-aware health check |
| `Models/Config.swift` | `claudeCLIPath` in GlobalOptions |
| `Models/Schedule.swift` | `slackChannel` in ScheduleOptions |
| `Services/SchedulerEngine.swift` | `sendPrompt()` call, channel passthrough |
| `Services/SlackNotifier.swift` | Proper Slack format, per-channel, test method, friendly errors |
| `Views/SettingsView.swift` | Segmented tabs, HelpView, ScheduleEditorView, auto-save, Slack test |
| `AppDelegate.swift` | CLI wizard, KeyableWindow, menu overhaul, editor/new workflow actions |

## Architecture Notes for Next Session

- `ClaudeAutomator.cliPath` defaults to `/opt/homebrew/bin/claude`, overridden by `config.globalOptions.claudeCLIPath`
- Schedule editor uses `KeyableWindow` (NSWindow subclass with `canBecomeKey = true`) for menu bar app compatibility
- Auto-save uses `Timer` debounce at 0.6s, writes through `ConfigManager.save()`
- Slack Test is async, returns human-readable errors via `friendlySlackError()` static method
