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

1. Download `OctopusScheduler-v1.3.0.zip`
2. Unzip and drag `OctopusScheduler.app` to `/Applications`
3. Right-click → Open (first launch, to bypass Gatekeeper)
4. Copy `config/default-config.json` to `~/.octopus-scheduler/config.json`
5. Copy `prompts/*.md` to `~/ARAMAI/prompts/scheduled/`

## Requirements

- macOS 13+ (Ventura or later)
- Claude Desktop installed
- Accessibility permission granted
- Network access to octopus-bridge.vercel.app (for Bridge features)
