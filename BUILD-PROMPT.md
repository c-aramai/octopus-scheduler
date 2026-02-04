# OctopusScheduler - One-Shot Build Prompt

Copy everything below the line into Claude Code:

---

## Build Task

Build a complete, working macOS menu bar application called **OctopusScheduler** that automates Claude Desktop interactions on a schedule.

## Read First

Before writing any code, read these specification files:
- `~/ARAMAI/dev/octopus-scheduler/SPEC.md` - Full technical specification
- `~/ARAMAI/dev/octopus-scheduler/VISION.md` - Product vision and context

## Requirements Summary

### What It Does
1. Runs as a menu bar app (octopus 🐙 icon)
2. Reads config from `~/.octopus-scheduler/config.json`
3. Loads prompt templates from markdown files
4. At scheduled times, activates Claude Desktop and sends prompts
5. Uses AppleScript/System Events for Claude automation

### Tech Stack
- **SwiftUI** for UI
- **NSStatusItem** for menu bar
- **NSAppleScript** for Claude automation
- **Timer** for scheduling
- **Codable** for JSON config
- Deployment target: **macOS 13+**

### Key Files to Create

```
~/ARAMAI/dev/octopus-scheduler/OctopusScheduler/
├── OctopusScheduler.xcodeproj/
├── OctopusScheduler/
│   ├── OctopusSchedulerApp.swift
│   ├── AppDelegate.swift
│   ├── Info.plist
│   ├── OctopusScheduler.entitlements
│   ├── Models/
│   │   ├── Config.swift
│   │   ├── Schedule.swift
│   │   └── PromptTemplate.swift
│   ├── Services/
│   │   ├── ConfigManager.swift
│   │   ├── SchedulerEngine.swift
│   │   ├── PromptLoader.swift
│   │   └── ClaudeAutomator.swift
│   ├── Views/
│   │   ├── MenuBarView.swift
│   │   └── SettingsView.swift
│   └── Resources/
│       └── Assets.xcassets/
└── README.md
```

### Critical Implementation Details

#### 1. Info.plist Must Include:
```xml
<key>NSAppleEventsUsageDescription</key>
<string>OctopusScheduler needs to control Claude Desktop to send automated prompts.</string>
<key>LSUIElement</key>
<true/>
```

#### 2. Entitlements Must Include:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
```

#### 3. ClaudeAutomator AppleScript Pattern:
```swift
// Activate Claude
tell application "Claude" to activate

// New conversation (optional)
tell application "System Events"
    tell process "Claude"
        keystroke "n" using command down
        delay 0.5
    end tell
end tell

// Paste prompt and send
tell application "System Events"
    tell process "Claude"
        set the clipboard to "prompt text here"
        keystroke "v" using command down
        delay 0.3
        keystroke return
    end tell
end tell
```

#### 4. Config Schema:
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
        "newConversation": true
      }
    }
  ],
  "globalOptions": {
    "launchAtLogin": true,
    "showNotifications": true
  }
}
```

#### 5. Prompt Template Format:
```markdown
---
name: Morning Briefing
description: Daily status check
---

Your prompt text here with {{CURRENT_DATE}} variables.
```

### Menu Bar Structure
```
🐙 ▼
├── ✓ Morning Briefing (6:00 AM)
├──   Evening Summary (6:00 PM)
├── ─────────────────
├── Run Now           ▶ [submenu with all prompts]
├── ─────────────────
├── Settings...
├── ─────────────────
└── Quit
```

### Build & Test Steps
1. Create Xcode project (macOS App, SwiftUI, no tests needed)
2. Implement all files per spec
3. Build and run
4. Grant Accessibility permission when prompted
5. Test with sample config and prompts

### Create Sample Files

Create `~/.octopus-scheduler/config.json` with a working sample config.

Create `~/ARAMAI/prompts/scheduled/morning-briefing.md` with:
```markdown
---
name: Morning Briefing
description: Generate daily status update
---

Good morning! Please read ~/ARAMAI/state/DASHBOARD.md and provide a brief summary of:
1. Current priorities
2. Active blockers
3. Today's recommended focus

Keep it concise - 3-4 bullet points max.
```

### Success Criteria
- [ ] App compiles without errors
- [ ] Menu bar icon appears
- [ ] Config loads successfully
- [ ] "Run Now" sends prompt to Claude
- [ ] Scheduled execution works
- [ ] Settings window opens

## Go

Build the complete application now. Create all necessary files, the Xcode project structure, and ensure it compiles. Use `xcodebuild` to verify the build succeeds.
