## What's New

- **Live Bridge Status** — Green/red/gray indicators show real-time connection health (polls every 30s)
- **Peers Online** — See connected peers from Bridge network in menu bar
- **Sync Now** — Manual config reload + bridge status refresh (replaces Reload Config)
- **Default DevRel Config** — Pre-configured for Mariam: #devrel-ops channel, weekday 9am/5pm schedules
- **Distribution Package** — Ready-to-run zip with app, prompts, config, and README

## Installation

1. Download `OctopusScheduler-v1.2.0.zip`
2. Unzip and drag `OctopusScheduler.app` to `/Applications`
3. Right-click → Open (first launch, to bypass Gatekeeper)
4. Copy `config/default-config.json` to `~/.octopus-scheduler/config.json`
5. Copy `prompts/*.md` to `~/ARAMAI/prompts/scheduled/`

## Requirements

- macOS 13+ (Ventura or later)
- Claude Desktop installed
- Accessibility permission granted
- Network access to octopus-bridge.vercel.app (for Bridge features)
