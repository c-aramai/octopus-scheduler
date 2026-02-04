# OctopusScheduler - Technical Specification

## Overview

**OctopusScheduler** is a native macOS menu bar application that automates interactions with Claude Desktop on a configurable schedule. It reads prompt templates from markdown files and injects them into Claude at specified times.

## Core Requirements

### 1. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    OctopusScheduler                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │  Menu Bar   │  │  Scheduler  │  │ Claude Automator│  │
│  │    UI       │  │   Engine    │  │  (AppleScript)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
│         │                │                  │           │
│         ▼                ▼                  ▼           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │   Config    │  │   Prompt    │  │   System Events │  │
│  │   Manager   │  │  Templates  │  │   (Accessibility)│  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 2. Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| UI Framework | SwiftUI | Modern, declarative, native macOS |
| App Type | Menu Bar (NSStatusItem) | Unobtrusive, always accessible |
| Scripting | NSAppleScript | Direct AppleScript execution |
| Scheduling | Timer + UserDefaults | Persistent, reliable |
| Config Format | JSON | Simple, standard |
| Prompts | Markdown files | Human-readable, version-controllable |

### 3. Configuration Schema

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
    },
    {
      "id": "evening-summary",
      "name": "Evening Summary",
      "enabled": true,
      "promptFile": "evening-summary.md",
      "schedule": {
        "type": "daily",
        "time": "18:00",
        "daysOfWeek": ["mon", "tue", "wed", "thu", "fri"]
      },
      "options": {
        "activateClaude": true,
        "newConversation": false,
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

### 4. Prompt Template Format

**Location:** Configurable via `promptsDirectory`

**Example:** `morning-briefing.md`

```markdown
---
name: Morning Briefing
description: Generate daily status update and post to Slack
variables:
  - CURRENT_DATE
  - WORKSPACE_PATH
---

Good morning! Please perform the following tasks:

1. Read the current DASHBOARD.md at {{WORKSPACE_PATH}}/state/DASHBOARD.md
2. Summarize the current priorities and blockers
3. Check for any pending items that need attention today
4. Post a morning briefing to #octopus-state in Slack

Today's date: {{CURRENT_DATE}}

Please be concise and actionable.
```

### 5. File Structure

```
OctopusScheduler/
├── OctopusScheduler.xcodeproj
├── OctopusScheduler/
│   ├── OctopusSchedulerApp.swift      # Main app entry
│   ├── AppDelegate.swift               # Menu bar setup
│   ├── Info.plist                      # Entitlements
│   ├── Views/
│   │   ├── MenuBarView.swift           # Status item menu
│   │   ├── SettingsView.swift          # Settings window
│   │   └── ScheduleListView.swift      # Schedule management
│   ├── Models/
│   │   ├── Config.swift                # Configuration model
│   │   ├── Schedule.swift              # Schedule model
│   │   └── PromptTemplate.swift        # Prompt template model
│   ├── Services/
│   │   ├── ConfigManager.swift         # Load/save config
│   │   ├── SchedulerEngine.swift       # Timer management
│   │   ├── PromptLoader.swift          # Markdown parsing
│   │   ├── ClaudeAutomator.swift       # AppleScript execution
│   │   └── NotificationService.swift   # User notifications
│   └── Resources/
│       └── Assets.xcassets             # App icon
└── README.md
```

### 6. Key Components

#### 6.1 ClaudeAutomator.swift

```swift
import Foundation
import AppKit

class ClaudeAutomator {

    func sendPromptToClaude(_ prompt: String, newConversation: Bool = true) -> Bool {
        // 1. Activate Claude
        let activateScript = """
        tell application "Claude"
            activate
        end tell
        """

        // 2. Optionally start new conversation (Cmd+N)
        let newConvoScript = """
        tell application "System Events"
            tell process "Claude"
                keystroke "n" using command down
                delay 0.5
            end tell
        end tell
        """

        // 3. Paste and send prompt
        let pasteScript = """
        tell application "System Events"
            tell process "Claude"
                set the clipboard to "\(prompt.escapedForAppleScript)"
                keystroke "v" using command down
                delay 0.3
                keystroke return
            end tell
        end tell
        """

        // Execute scripts in sequence
        runAppleScript(activateScript)
        if newConversation {
            runAppleScript(newConvoScript)
        }
        return runAppleScript(pasteScript)
    }

    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}
```

#### 6.2 SchedulerEngine.swift

```swift
import Foundation

class SchedulerEngine: ObservableObject {
    @Published var schedules: [Schedule] = []
    private var timers: [String: Timer] = [:]

    func start() {
        schedules.filter { $0.enabled }.forEach { schedule in
            scheduleNext(schedule)
        }
    }

    private func scheduleNext(_ schedule: Schedule) {
        guard let nextFire = schedule.nextFireDate() else { return }

        let timer = Timer(fire: nextFire, interval: 0, repeats: false) { [weak self] _ in
            self?.execute(schedule)
            self?.scheduleNext(schedule)  // Reschedule
        }

        RunLoop.main.add(timer, forMode: .common)
        timers[schedule.id] = timer
    }

    private func execute(_ schedule: Schedule) {
        // Load prompt, substitute variables, send to Claude
    }
}
```

### 7. Entitlements & Permissions

#### Info.plist entries:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>OctopusScheduler needs to control Claude Desktop to send automated prompts.</string>

<key>LSUIElement</key>
<true/>

<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

#### Entitlements file:

```xml
<key>com.apple.security.automation.apple-events</key>
<true/>

<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.anthropic.claude</string>
</array>
```

### 8. Menu Bar Interface

```
┌─────────────────────────┐
│ 🐙 ▼                    │  ← Status item with octopus icon
├─────────────────────────┤
│ ✓ Morning Briefing 6:00 │  ← Enabled schedules
│   Evening Summary 18:00 │
├─────────────────────────┤
│ Run Now...          ▶   │  ← Manual trigger submenu
├─────────────────────────┤
│ Settings...             │
│ View Logs...            │
├─────────────────────────┤
│ Quit                    │
└─────────────────────────┘
```

### 9. Build Requirements

- **Xcode 15+**
- **macOS 13+ (Ventura)** deployment target
- **Swift 5.9+**
- **Signing**: Developer ID for distribution, or ad-hoc for personal use

### 10. Testing Checklist

- [ ] App launches and shows menu bar icon
- [ ] Config loads from `~/.octopus-scheduler/config.json`
- [ ] Prompt templates load from configured directory
- [ ] Variables substitute correctly ({{CURRENT_DATE}}, etc.)
- [ ] Claude activates when scheduled
- [ ] New conversation created when configured
- [ ] Prompt pastes and sends correctly
- [ ] Schedule fires at correct times
- [ ] "Run Now" manual trigger works
- [ ] Settings window opens and saves
- [ ] Notifications display
- [ ] Logs written correctly
- [ ] Launch at login works

## Success Criteria

1. **One-time setup**: User grants Accessibility permission once
2. **Fire and forget**: Schedules run reliably without intervention
3. **Configurable**: All behavior controlled via JSON config
4. **Extensible**: Easy to add new prompt templates
5. **Visible**: Menu bar shows status, logs available for debugging
