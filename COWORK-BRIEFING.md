# OctopusScheduler — Sprint 1.5 Briefing

**Date:** 2026-02-09
**From:** logos-ui session (Opus 4.6)
**Repo:** https://github.com/c-aramai/octopus-scheduler
**Current version:** v1.5.1 (release: https://github.com/c-aramai/octopus-scheduler/releases/tag/v1.5.1)

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

## v1.5.1 Fixes (Feb 9)

- **Slack webhook URL validation** — Settings warns with orange text when URL doesn't match `hooks.slack.com` format
- **Notification permission feedback** — Notifications tab shows macOS authorization status (blocked, not requested, granted). Directs user to System Settings when blocked.
- **Run Now progress** — Menu shows "Running: [workflow name] (Xs)" in yellow with elapsed time counter, updates every 5s, clears on completion

## Known Issues / Backlog

1. **Slack webhook URL** — Config still points to `localhost:5679`. Needs a fresh Slack webhook from workspace admin.
2. **Slack channel validation** — Test button works but depends on valid webhook URL first

## Files Modified (from v1.4.0)

| File | Changes |
|------|---------|
| `Services/ClaudeAutomator.swift` | CLI delivery, fallback, CLI-aware health check |
| `Models/Config.swift` | `claudeCLIPath` in GlobalOptions |
| `Models/Schedule.swift` | `slackChannel` in ScheduleOptions |
| `Services/SchedulerEngine.swift` | `sendPrompt()` call, channel passthrough |
| `Services/SlackNotifier.swift` | Proper Slack format, per-channel, test method, friendly errors |
| `Views/SettingsView.swift` | Segmented tabs, HelpView, ScheduleEditorView, auto-save, Slack test, webhook validation, notification status |
| `AppDelegate.swift` | CLI wizard, KeyableWindow, menu overhaul, editor/new workflow actions, Run Now progress |
| `Services/NotificationService.swift` | ObservableObject with published authorization status |

## Architecture Notes for Next Session

- `ClaudeAutomator.cliPath` defaults to `/opt/homebrew/bin/claude`, overridden by `config.globalOptions.claudeCLIPath`
- Schedule editor uses `KeyableWindow` (NSWindow subclass with `canBecomeKey = true`) for menu bar app compatibility
- Auto-save uses `Timer` debounce at 0.6s, writes through `ConfigManager.save()`
- Slack Test is async, returns human-readable errors via `friendlySlackError()` static method
