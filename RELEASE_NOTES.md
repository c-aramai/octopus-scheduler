## v1.5.1 — UX Polish & TCC Fix

- **Hardened Runtime** — Eliminates macOS TCC permission prompts for Desktop/Music access
- **CLI Process Isolation** — Child process working directory set to `/tmp`, preventing TCC-protected path access
- **Slack Webhook Validation** — Settings warns with orange text when URL doesn't match `hooks.slack.com` format
- **Notification Permission Feedback** — Notifications tab shows macOS authorization status with guidance to System Settings
- **Run Now Progress** — Menu shows "Running: [workflow name] (Xs)" in yellow with elapsed time counter

## v1.5.0 — CLI Delivery & Menu Overhaul

- **Dual-Mode Delivery** — Claude Code CLI (`claude -p --print`) primary, AppleScript fallback
- **Schedule Editor GUI** — Edit name, time, days, prompt file, Slack channel with auto-save
- **Menu UX Overhaul** — Per-workflow submenus with Run Now, Open Prompt, Edit Schedule, Pause/Resume
- **Settings Redesign** — Segmented picker tabs (General, Schedules, Notifications, Help, About)
- **Slack Integration Fix** — Proper payload format, per-workflow channels, emoji status prefixes
- **Help Tab** — Setup guide, config reference, prompt templates, troubleshooting

## v1.4.0 — Bulletproof Foundation

- **State Persistence** — Schedule last-fired timestamps persist to `~/.octopus-scheduler/state.json`, surviving app restarts
- **Retry Logic** — Failed prompt deliveries retry 3 times with exponential backoff (5s, 15s, 45s)
- **Sleep/Wake Recovery** — Detects missed fires after system wake and executes them as `[DELAYED]`
- **Claude Health Check** — 30s polling shows Claude Desktop status in menu (ready/not running/not installed), blocks execution when not installed
- **Execution Locking** — Prevents duplicate concurrent executions per schedule; optional `allowConcurrentExecutions` global config
- **Config File Watching** — Auto-reloads config on external edits with debounce and JSON validation (invalid JSON keeps current config)

## v1.3.0 — Slack, HTTP API, Update Indicator

- **Slack Notifications** — Posts to Slack webhook on prompt completion/failure
- **HTTP Trigger API** — Local HTTP server (port 19840) for external trigger via `POST /trigger/:id`
- **Update Indicator** — Menu shows "⬆ Update to vX.Y.Z..." when newer release detected
- **Schedule Patch API** — `PATCH /schedules/:id` to enable/disable schedules remotely

## v1.2.1 — Check for Updates

- **Check for Updates** — Menu item queries GitHub Releases API, shows dialog with download link if newer version available
- **App Icon in Dialogs** — 🐙 icon displays in update and alert dialogs
- **Silent Update Check** — Checks for updates on launch without interrupting

## v1.2.0 — Mariam MVP

- **Live Bridge Status** — Green/red/gray indicators show real-time connection health (polls every 30s)
- **Peers Online** — See connected peers from Bridge network in menu bar
- **Sync Now** — Manual config reload + bridge status refresh (replaces Reload Config)
- **Default DevRel Config** — Pre-configured for Mariam: #devrel-ops channel, weekday 9am/5pm schedules
- **Distribution Package** — Ready-to-run zip with app, prompts, config, and README

## Installation

1. Download `OctopusScheduler-v1.5.1.zip`
2. Unzip and drag `OctopusScheduler.app` to `/Applications`
3. Right-click → Open (first launch, to bypass Gatekeeper)
4. Copy `config/default-config.json` to `~/.octopus-scheduler/config.json`
5. Copy `prompts/*.md` to `~/ARAMAI/prompts/scheduled/`

## Requirements

- macOS 13+ (Ventura or later)
- Claude Code CLI (`claude`) or Claude Desktop installed
- Network access to octopus-bridge.vercel.app (for Bridge features)
