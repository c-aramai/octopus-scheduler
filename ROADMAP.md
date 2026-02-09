# OctopusScheduler Roadmap

**Created:** 2026-02-04
**Status:** Active Development

---

## Phase 2: Reliability & Robustness ✅

*Make it bulletproof for daily use.* **COMPLETE (v1.4.0)**

### 2.1 Sleep/Wake Recovery ✅
- **Implemented:** `NSWorkspace.didWakeNotification` observer in `SchedulerEngine.startWakeObserver()`
- Checks all enabled schedules for missed fires on wake
- Fires missed schedules with `[DELAYED]` flag
- State persisted to `~/.octopus-scheduler/state.json` (ISO8601 dates)

### 2.2 Retry Logic with Backoff ✅
- **Implemented:** Retry loop in `executeWithRetry()` — 4 attempts (initial + 3 retries)
- Backoff: 5s, 15s, 45s exponential
- Health check and prompt load are non-retriable (correct)
- Notification only after final failure

### 2.3 Claude Health Check ✅
- **Implemented:** `ClaudeAutomator.checkHealth()` with 3-state enum (ready/notRunning/notInstalled)
- Bundle ID lookup via `NSWorkspace`
- Polled every 30s, menu bar icon: 🐙 (ok) / ⚠️ (not installed)
- Pre-flight check skips execution if not installed (non-retriable)

### 2.4 Config File Watching ✅
- **Implemented:** `ConfigManager.startWatching()` using `DispatchSource.makeFileSystemObjectSource`
- Watches `.write`, `.rename`, `.delete` events
- 0.5s debounce, validates JSON before applying (invalid keeps current config)

### 2.5 Execution Locking ✅
- **Implemented:** `runningSchedules: Set<String>` in `SchedulerEngine`
- Per-schedule mutex + global `allowConcurrentExecutions` config flag (default: false)
- `defer` ensures cleanup on all exit paths

---

## Phase 3: User Experience

*Make it delightful to configure and monitor.*

### 3.1 Visual Schedule Editor
- **Current:** Edit JSON manually
- **Solution:**
  - SwiftUI form in Settings: name, prompt file (picker), time, days, options
  - Add/remove/reorder schedules
  - Live preview of next fire time
  - Still persists to JSON (source of truth)
- **Effort:** Medium

### 3.2 Prompt Template Browser
- **Current:** Must know file paths
- **Solution:**
  - File browser showing `promptsDirectory` contents
  - Preview pane with rendered markdown
  - Variable highlighting (show what `{{CURRENT_DATE}}` resolves to)
  - "New Prompt" button with template
- **Effort:** Medium

### 3.3 Execution History View
- **Current:** Dig through log files
- **Solution:**
  - SQLite database: `~/.octopus-scheduler/history.db`
  - Table: `executions(id, schedule_id, fired_at, status, duration_ms, error)`
  - SwiftUI list view with filtering by schedule, date range, status
  - Click to see full log entry
- **Effort:** Medium

### 3.4 Status Dashboard
- **Current:** Menu shows schedule list only
- **Solution:**
  - Popover on menu bar click (not just dropdown)
  - "Next up: Morning Briefing in 2h 15m"
  - Last 5 executions with status indicators
  - Quick stats: "47 successful, 2 failed this week"
- **Effort:** Medium

### 3.5 Keyboard Shortcuts
- **Solution:**
  - Global hotkey to open dashboard (configurable, e.g., ⌥⌘O)
  - ⌘1-9 to run schedule by position
  - Keyboard navigation in all views
- **Effort:** Small

---

## Phase 4: Integration & Ecosystem

*Connect to the broader OCTOPUS infrastructure.*

### 4.1 Webhook Triggers (Inbound) ✅
- **Status:** **COMPLETE (v1.3.0, OCTO-012)**
- **Implemented:** NWListener HTTP server on port 19840 (no dependencies)
  - `POST /trigger/:schedule_id` — fires immediately
  - `GET /schedules` — list all schedules with next fire times
  - `GET /history` — recent execution log
  - `GET /status` — health check
  - `PATCH /schedules/:id` — enable/disable remotely
  - Auth via `Authorization: Bearer <secret>` header
- **Effort:** Medium

### 4.2 Webhook Events (Outbound) ✅
- **Status:** **COMPLETE (v1.3.0, OCTO-012)**
- **Implemented:** SlackNotifier service posts to n8n webhook URL
  - Events: `prompt.fired`, `prompt.succeeded`, `prompt.failed`
  - Configured via `config.slack.webhookUrl`
  - Fire-and-forget (non-blocking `Task {}`)
  - Respects `notifyOnComplete` / `notifyOnFailure` settings
- **Effort:** Small

### 4.3 Response Capture
- **Problem:** Can't see what Claude responded
- **Solution:**
  - After paste+enter, wait configurable duration (default 30s)
  - Use Accessibility to read Claude's response from UI
  - Store in history.db with execution record
  - Option: `captureResponse: true` per schedule
- **Effort:** Large (fragile, depends on Claude UI structure)

### 4.4 Slack Integration ✅ (without response capture)
- **Status:** **COMPLETE (v1.3.0, OCTO-012)** — notifications without response capture
- **Implemented:** n8n workflow routes scheduler events to Slack
  - `scheduler-to-slack.json` — webhook trigger → format → post to #octopus-state
  - `slack-to-scheduler.json` — `/octopus` slash command → scheduler HTTP API → respond
  - Channel configurable via `config.slack.defaultChannel`
  - Response capture (4.3) remains future work for including Claude's reply
- **Effort:** Small (without response), Medium (with response)

### 4.5 MCP Bridge Integration
- **Problem:** Scheduler operates independently of agent coordination
- **Solution:**
  - On prompt fire, call octopus-mcp-bridge `handoff` tool
  - Creates task visible to all agents
  - Scheduler becomes "scheduler" agent in the OCTOPUS ecosystem
  - Can receive tasks via MCP (not just time triggers)
- **Effort:** Medium
- **Partial (v1.2.0):** BridgeService added — health check polling (GET /api/health every 30s), peer discovery (GET /api/peers), live status in menu bar, "Sync Now" action. Full handoff integration remains.

---

## Phase 5: Flexibility & Power

*For power users and advanced workflows.*

### 5.1 Cron-Style Schedules
- **Current:** Limited to daily + days-of-week
- **Solution:**
  - Support cron syntax: `"cron": "0 9 * * MON-FRI"`
  - Keep simple `daily`/`weekly` as shortcuts
  - Use swift-cron or similar parser
- **Effort:** Small

### 5.2 Conditional Execution
- **Problem:** Prompts fire even when nothing changed
- **Solution:**
  - Conditions in schedule config:
    ```json
    "conditions": {
      "fileChanged": "~/ARAMAI/state/DASHBOARD.md",
      "afterTime": "09:00",
      "notOnWeekends": true
    }
    ```
  - Store file hashes, compare before firing
  - Skip with log entry if conditions not met
- **Effort:** Medium

### 5.3 Prompt Chaining
- **Problem:** Complex workflows need multiple prompts in sequence
- **Solution:**
  - New schedule type: `"type": "chain"`
  - Steps execute in order, each waits for previous
  - Variables can reference previous step outputs (requires response capture)
  - Abort chain on step failure (configurable)
- **Effort:** Large

### 5.4 Claude Code Support ← **EVALUATING (see COWORK-BRIEFING.md)**
- **Problem:** AppleScript automation for Claude Desktop is unreliable (Accessibility perms revoked on rebuild, silent keystroke failures)
- **Solution:**
  - Replace AppleScript with `claude -p --print` CLI call
  - Already installed (`/opt/homebrew/bin/claude` v2.1.37)
  - No UI automation, no Accessibility permission needed
  - Returns response text (enables response capture for free)
  - Per-schedule option: `"target": "desktop" | "cli"`
- **Status:** Decision pending — briefing sent to Cowork/Project sessions
- **Effort:** Small (~30 lines in ClaudeAutomator.swift)

### 5.5 Multiple Profiles
- **Problem:** Single Claude conversation context
- **Solution:**
  - Support multiple Claude Desktop windows/projects
  - Per-schedule: `"profile": "work"` or `"profile": "personal"`
  - Profile = Claude project folder or conversation
  - Requires detecting/managing multiple windows
- **Effort:** Large

### 5.6 Template Inheritance
- **Problem:** Duplicate boilerplate across prompts
- **Solution:**
  - Frontmatter: `extends: base-prompt.md`
  - Base provides common context, child adds specifics
  - Variables from child override base
- **Effort:** Small

### 5.7 Remote Prompt Repository
- **Problem:** Prompts stuck on one machine
- **Solution:**
  - `promptsRepository: "git@github.com:user/prompts.git"`
  - Auto-pull on schedule (e.g., hourly)
  - Or: watch for changes, pull on demand
  - Team shares prompt library via git
- **Effort:** Medium

---

## Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| ~~Sleep/Wake Recovery~~ | ~~High~~ | ~~Small~~ | ✅ **v1.3.0** |
| ~~Retry Logic~~ | ~~High~~ | ~~Small~~ | ✅ **v1.3.0** |
| ~~Claude Health Check~~ | ~~Medium~~ | ~~Small~~ | ✅ **v1.3.0** |
| ~~Config File Watching~~ | ~~Medium~~ | ~~Small~~ | ✅ **v1.3.0** |
| ~~Execution Locking~~ | ~~Medium~~ | ~~Small~~ | ✅ **v1.3.0** |
| ~~Webhook Events (Out)~~ | ~~High~~ | ~~Small~~ | ✅ **v1.3.0** |
| Cron Schedules | Medium | Small | **P1** |
| Template Inheritance | Medium | Small | **P1** |
| Visual Schedule Editor | High | Medium | **P1** |
| Execution History | High | Medium | **P1** |
| ~~Webhook Triggers (In)~~ | ~~High~~ | ~~Medium~~ | ✅ **v1.3.0** |
| MCP Bridge Integration | High | Medium | **P2** |
| Claude Code Support | **Critical** | Small | **P0 — evaluating** |
| Conditional Execution | Medium | Medium | **P2** |
| Prompt Template Browser | Medium | Medium | **P2** |
| Status Dashboard | Medium | Medium | **P2** |
| ~~Slack Integration~~ | ~~Medium~~ | ~~Medium~~ | ✅ **v1.3.0** |
| Remote Prompt Repo | Medium | Medium | **P3** |
| Response Capture | High | Large | **P3** |
| Prompt Chaining | Medium | Large | **P3** |
| Multiple Profiles | Low | Large | **P4** |

---

## Suggested Sprints

### Sprint 1: Bulletproof Foundation (P0) ✅ COMPLETE
- ~~Sleep/wake recovery~~ ✅
- ~~Retry with backoff~~ ✅
- ~~Claude health check~~ ✅
- ~~Config file watching~~ ✅
- ~~Execution locking~~ ✅

### Sprint 1.5: Prompt Delivery Fix (P0) ← NEXT
- Claude Code CLI support (`claude -p`) — replaces fragile AppleScript
- Decision pending: see COWORK-BRIEFING.md

### Sprint 2: Observable & Flexible (P1)
- Cron-style schedules
- Template inheritance
- Execution history (SQLite)
- Visual schedule editor

### Sprint 3: Integration Layer (P2)
- MCP Bridge integration (full handoff)
- Conditional execution
- Prompt template browser
- Status dashboard

### Sprint 4: Power Features (P3-P4)
- Response capture
- Prompt chaining
- Remote prompt repo
- Multiple profiles

---

## Environment Variables

```bash
# New config options for Phase 4+
OCTOPUS_SCHEDULER_WEBHOOK_URL=http://localhost:5679/webhook/scheduler
OCTOPUS_SCHEDULER_WEBHOOK_SECRET=your-hmac-secret
OCTOPUS_SCHEDULER_MCP_URL=http://localhost:8081
OCTOPUS_SCHEDULER_MCP_KEY=oct_key_scheduler
OCTOPUS_SCHEDULER_HTTP_PORT=19840
OCTOPUS_SCHEDULER_HTTP_SECRET=trigger-secret
```

---

## Success Metrics

1. **Reliability:** <1% missed schedules over 30 days
2. **Recovery:** 100% of sleep-missed schedules caught within 60s of wake
3. **Visibility:** User can see last 7 days of history in <3 clicks
4. **Integration:** Events flow to n8n within 1s of execution
5. **Flexibility:** Power users can express any schedule in cron syntax

---

*The octopus extends its arms purposefully. Each improvement makes those arms stronger, smarter, more connected.*
