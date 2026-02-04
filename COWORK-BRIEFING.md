# OctopusScheduler — Build Session Briefing

**Date:** 2026-02-04 ~1:55 AM - 2:50 AM EST
**Participants:** wcs + Claude Code (Opus 4.5)

## What We Built

OctopusScheduler is now a working macOS menu bar app. It lives at:

```
~/ARAMAI/dev/octopus-scheduler/OctopusScheduler/
```

The app automates Claude Desktop on a schedule — it reads prompt templates from markdown files, and at configured times (or on-demand via "Run Now"), it activates Claude, opens a new conversation, pastes the prompt, and submits it.

## What Happened

### Phase 1: Initial Build
- Read SPEC.md, VISION.md, BUILD-PROMPT.md
- Created all 11 Swift source files, Xcode project, Package.swift
- Verified compilation with `swift build` (Xcode wasn't installed yet)
- Created sample config at `~/.octopus-scheduler/config.json`
- Created morning briefing prompt at `~/ARAMAI/prompts/scheduled/morning-briefing.md`

### Phase 2: Xcode Build + Icon Fix
- Xcode finished downloading; project built successfully with Cmd+R
- Fixed menu bar icon: replaced SF Symbol grid with 🐙 emoji

### Phase 3: Automation Debugging
This was the most iterative part. The original AppleScript approach (setting clipboard via AppleScript string interpolation) didn't work with Claude Desktop's Electron UI.

**Problems discovered and solved:**
1. **Clipboard via AppleScript** — multi-line prompts with quotes/newlines broke the string escaping. **Fix:** Use Swift's `NSPasteboard` to set clipboard, AppleScript only does keystrokes.
2. **Paste not landing in input field** — Claude Desktop is Electron-based; System Events keystrokes weren't reaching the text input. **Fix:** After Cmd+N, the cursor is already in the input field — no clicking needed.
3. **Enter not submitting** — Initial click coordinates were hitting the file attachment area instead of the text input. **Fix:** Eliminated clicking entirely; after Cmd+N the input has focus, so paste + Enter works.
4. **Screen Recording permission** — Reading window position/size triggers this extra permission. **Fix:** Removed all window geometry code since clicking is unnecessary.

### Phase 4: Five Improvements
After the core flow was working, implemented:

1. **`newConversation: false` reliability** — When reusing an existing conversation, presses Escape to dismiss overlays and ensure focus before pasting.
2. **Cold-start detection** — Uses `NSRunningApplication` to check if Claude is already running. Waits 5s for cold start vs 1s for warm.
3. **Launch at Login** — Wired up `SMAppService.mainApp` (macOS 13+) to the `launchAtLogin` config option.
4. **Notifications** — `UNUserNotificationCenter` notifications on prompt fire, success, and failure.
5. **Disk logging** — Daily rotating log files at `~/.octopus-scheduler/logs/octopus-YYYY-MM-DD.log`.

Updated the Xcode project (project.pbxproj) to include the two new service files. Verified build with both `swift build` and `xcodebuild`.

## Current State

**Working:**
- 🐙 menu bar icon with schedule list, Run Now submenu, Settings, Reload Config, Quit
- Morning Briefing and Evening Summary both tested manually via Run Now
- Config loads/saves, schedules toggle on/off from menu
- Settings window with General/Schedules/About tabs
- Builds clean with both Xcode (Cmd+R) and SPM (`swift build`)

**Not yet tested:**
- Overnight scheduled execution (timers are set, just hasn't hit 6:00 AM yet)
- Notification display
- Log file output
- Launch at Login across reboot

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| NSPasteboard over AppleScript clipboard | Avoids all string escaping issues with multi-line prompts |
| No click-to-focus | Eliminates Screen Recording permission requirement |
| Cmd+N auto-focuses input | Proven by testing; Claude Desktop puts cursor in input after new conversation |
| Escape before paste (non-new-convo) | Dismisses any overlays to ensure input field has focus |
| Cold-start detection | Prevents race condition where paste fires before Claude's UI is ready |

## Files Created/Modified

```
~/.octopus-scheduler/config.json              # Sample config (2 schedules)
~/ARAMAI/prompts/scheduled/morning-briefing.md # Sample prompt template
~/ARAMAI/dev/octopus-scheduler/SPEC-v2.md      # Updated specification
~/ARAMAI/dev/octopus-scheduler/OctopusScheduler/  # Full project (14 source files)
```

## Permissions Required (For New Installs)

Only 3 permissions needed (down from 4 — eliminated Screen Recording):
1. **Accessibility** — toggle once in System Settings
2. **Automation: Claude** — one-time OK dialog
3. **Automation: System Events** — one-time OK dialog

## Next Steps

- Verify scheduled execution fires at 6:00 AM
- Test notification display
- Check log files at `~/.octopus-scheduler/logs/`
- Create an `evening-summary.md` prompt template
- Consider config file watching for auto-reload
