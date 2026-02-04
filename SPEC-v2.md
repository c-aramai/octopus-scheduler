# OctopusScheduler - Technical Specification v2

**Updated:** 2026-02-04
**Status:** MVP implemented and tested

## Overview

**OctopusScheduler** is a native macOS menu bar application that automates interactions with Claude Desktop on a configurable schedule. It reads prompt templates from markdown files and injects them into Claude at specified times.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      OctopusScheduler                        │
│  ┌──────────┐  ┌───────────┐  ┌────────────────┐            │
│  │ Menu Bar │  │ Scheduler │  │ Claude         │            │
│  │ UI       │  │ Engine    │  │ Automator      │            │
│  └──────────┘  └───────────┘  └────────────────┘            │
│       │              │               │                       │
│       ▼              ▼               ▼                       │
│  ┌──────────┐  ┌───────────┐  ┌────────────────┐            │
│  │ Config   │  │ Prompt    │  │ System Events  │            │
│  │ Manager  │  │ Loader    │  │ (Accessibility)│            │
│  └──────────┘  └───────────┘  └────────────────┘            │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────┐  ┌───────────┐                                │
│  │ Log      │  │ Notifica- │                                │
│  │ Service  │  │ tion Svc  │                                │
│  └──────────┘  └───────────┘                                │
└──────────────────────────────────────────────────────────────┘
```

## Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| UI Framework | SwiftUI | Modern, declarative, native macOS |
| App Type | Menu Bar (NSStatusItem) | Unobtrusive, always accessible |
| Scripting | NSAppleScript + NSPasteboard | Reliable clipboard + keystroke automation |
| Scheduling | Timer (re-scheduling) | Fires at computed next-fire-date, then reschedules |
| Config Format | JSON (Codable) | Simple, standard, type-safe decoding |
| Prompts | Markdown + YAML frontmatter | Human-readable, version-controllable |
| Notifications | UNUserNotificationCenter | Native macOS notifications |
| Logging | Custom file logger | Daily rotating log files |
| Launch at Login | SMAppService | macOS 13+ native login item API |
| Build System | Xcode + Swift Package Manager | Both xcodeproj and Package.swift provided |

## File Structure

```
OctopusScheduler/
├── Package.swift                          # SPM build support
├── OctopusScheduler.xcodeproj/            # Xcode project
│   └── project.pbxproj
└── OctopusScheduler/
    ├── OctopusSchedulerApp.swift          # @main entry, Settings scene
    ├── AppDelegate.swift                  # NSStatusItem, service wiring, login item
    ├── Info.plist                         # LSUIElement, AppleEvents usage
    ├── OctopusScheduler.entitlements      # automation.apple-events
    ├── Models/
    │   ├── Config.swift                   # AppConfig, GlobalOptions (Codable)
    │   ├── Schedule.swift                 # ScheduleConfig, ScheduleTiming, nextFireDate()
    │   └── PromptTemplate.swift           # Template with {{variable}} substitution
    ├── Services/
    │   ├── ConfigManager.swift            # Load/save ~/.octopus-scheduler/config.json
    │   ├── SchedulerEngine.swift          # Timer-based scheduling, execute/restart
    │   ├── PromptLoader.swift             # Markdown frontmatter parser
    │   ├── ClaudeAutomator.swift          # NSAppleScript + NSPasteboard automation
    │   ├── NotificationService.swift      # UNUserNotificationCenter wrapper
    │   └── LogService.swift               # Daily rotating file logger
    ├── Views/
    │   ├── MenuBarView.swift              # SwiftUI view (for future popover use)
    │   └── SettingsView.swift             # General/Schedules/About tabs
    └── Resources/
        └── Assets.xcassets/
```

## Configuration

**Location:** `~/.octopus-scheduler/config.json`

```json
{
  "version": "1.0",
  "promptsDirectory": "~/ARAMAI/prompts/scheduled",
  "schedules": [
    {
      "id": "morning-briefing",
      "name": "Morning Briefing",
      "enabled": true,
      "promptFile": "morning-briefing.md",
      "schedule": {
        "type": "daily",
        "time": "06:00",
        "daysOfWeek": ["mon", "tue", "wed", "thu", "fri"]
      },
      "options": {
        "activateClaude": true,
        "newConversation": true,
        "waitForResponse": false
      }
    }
  ],
  "globalOptions": {
    "launchAtLogin": true,
    "showNotifications": true,
    "logDirectory": "~/.octopus-scheduler/logs"
  }
}
```

## Prompt Template Format

**Location:** Configurable via `promptsDirectory`

```markdown
---
name: Morning Briefing
description: Generate daily status update
variables:
  - CURRENT_DATE
  - WORKSPACE_PATH
---

Your prompt text here. Today is {{CURRENT_DATE}}.
Read {{WORKSPACE_PATH}}/state/DASHBOARD.md for context.
```

**Supported variables:**
- `{{CURRENT_DATE}}` — resolves to `YYYY-MM-DD`
- `{{WORKSPACE_PATH}}` — resolves to expanded `~/ARAMAI`

## Claude Automation (Key Implementation Details)

The automator uses a three-step pattern proven through testing:

### newConversation: true
1. `tell application "Claude" to activate` (with cold-start detection: 5s delay if launching, 1s if already running)
2. `keystroke "n" using command down` — opens new conversation, cursor lands in input field
3. Set `NSPasteboard.general` with prompt text, then `keystroke "v"` + `keystroke return`

### newConversation: false
1. Activate Claude (same cold-start detection)
2. `key code 53` (Escape) to dismiss any overlays, set frontmost
3. Paste and Enter (same as above)

### Why NSPasteboard instead of AppleScript clipboard
AppleScript string interpolation requires escaping quotes, newlines, and backslashes. Multi-line prompts with markdown are error-prone. Setting the clipboard via Swift's `NSPasteboard` bypasses all escaping issues.

### Why no click-to-focus
Reading window position/size via System Events triggers macOS **Screen Recording** permission. By relying on Cmd+N (which auto-focuses the input) and Escape (which clears overlays), we avoid this extra permission entirely.

## Permissions Required

| Permission | Trigger | User Action |
|-----------|---------|-------------|
| **Accessibility** | System Events keystrokes | Toggle in System Settings > Privacy > Accessibility |
| **Automation: Claude** | `tell application "Claude"` | Click OK on one-time dialog |
| **Automation: System Events** | `tell application "System Events"` | Click OK on one-time dialog |
| **Notifications** | UNUserNotificationCenter | Click Allow on one-time dialog |

**Not required:** Screen Recording (eliminated by avoiding window geometry reads).

## Services

### LogService
- Writes to `~/.octopus-scheduler/logs/octopus-YYYY-MM-DD.log`
- Daily rotation by filename
- All scheduler events, errors, and automation results logged
- Also prints to stdout for Xcode console visibility

### NotificationService
- Sends macOS notification when a prompt fires
- Sends success/failure notification after execution
- Requests permission on first launch
- Controlled by `globalOptions.showNotifications`

### Launch at Login
- Uses `SMAppService.mainApp` (macOS 13+)
- Controlled by `globalOptions.launchAtLogin`
- Registered/unregistered on app launch based on config

## Menu Bar Interface

```
🐙 ▼
├── ✓ Morning Briefing (06:00)
├──    Evening Summary (18:00)
├── ─────────────────
├── Run Now           ▶ [submenu with all prompts]
├── ─────────────────
├── Settings...       ⌘,
├── Reload Config     ⌘R
├── ─────────────────
└── Quit              ⌘Q
```

## Build Requirements

- **Xcode 15+** (or Swift 5.9+ CLI for `swift build`)
- **macOS 13+ (Ventura)** deployment target
- **Signing**: Automatic for development, Developer ID for distribution

### Build with Xcode
```bash
open OctopusScheduler.xcodeproj  # then Cmd+R
```

### Build with SPM
```bash
swift build
```

### Build with xcodebuild
```bash
xcodebuild -project OctopusScheduler.xcodeproj \
  -scheme OctopusScheduler -configuration Debug build
```

## Testing Checklist

- [x] App compiles without errors (Xcode and SPM)
- [x] 🐙 menu bar icon appears
- [x] Config loads from `~/.octopus-scheduler/config.json`
- [x] Prompt templates load from configured directory
- [x] Variables substitute correctly ({{CURRENT_DATE}})
- [x] Claude activates when triggered
- [x] New conversation created when `newConversation: true`
- [x] Existing conversation used when `newConversation: false`
- [x] Prompt pastes and submits correctly
- [x] "Run Now" manual trigger works
- [x] Settings window opens with General/Schedules/About tabs
- [x] Cold-start detection (longer wait when Claude isn't running)
- [ ] Scheduled execution fires at correct times (not yet tested overnight)
- [ ] Notifications display on fire/success/failure
- [ ] Logs written to ~/.octopus-scheduler/logs/
- [ ] Launch at login persists across reboot

## Known Considerations

1. **Claude Desktop updates** may change keyboard shortcuts or UI layout, potentially breaking the Cmd+N or paste/Enter flow. The automation is inherently coupled to Claude's current UI behavior.

2. **Multiple monitors / spaces** — Claude must be reachable by `activate`. If Claude is on a different Space, macOS should switch to it, but this is not tested.

3. **Sleep/wake** — Timers may not fire if the Mac was asleep at the scheduled time. The scheduler reschedules after each fire, so it will pick up the next occurrence, but the missed one is lost.

## Future Possibilities

- Config file watching (auto-reload on change)
- Response capture and logging
- Conditional execution (only if file changed since last run)
- Cron-style schedule expressions
- Multiple Claude windows/profiles
- Webhook/HTTP trigger support
