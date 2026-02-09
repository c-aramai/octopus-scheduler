# OctopusScheduler — Decision Briefing: Prompt Delivery Method

**Date:** 2026-02-08
**From:** logos-ui session (Opus 4.6)
**For:** Cowork + Project sessions
**Repo:** https://github.com/c-aramai/octopus-scheduler
**Current version:** v1.4.0

## Context

Sprint 1 "Bulletproof Foundation" shipped tonight (commit `c09d881`, tag `v1.4.0`). Six reliability features added — state persistence, retry with backoff, sleep/wake recovery, Claude health check, execution locking, config file watching. All working.

However, during testing we hit a blocking issue with the **prompt delivery mechanism** — the AppleScript-based automation that sends prompts to Claude Desktop.

## The Problem

`ClaudeAutomator.swift` sends prompts to Claude Desktop via AppleScript keystrokes:

```
Activate Claude → Cmd+N (new conversation) → NSPasteboard copy → Cmd+V (paste) → Enter (submit)
```

**Failure mode observed tonight:**
1. Claude Desktop activates (switches to foreground) ✓
2. Cmd+N / paste / Enter — **silently fails** ✗
3. Retry logic fires 3 more times — all fail the same way
4. Result: Claude is open but nothing was sent

**Root cause:** macOS Accessibility permission is invalidated every time the binary is rebuilt (code signature changes). The app must be re-authorized in System Settings > Privacy & Security > Accessibility after every build. Even after re-authorizing, the paste step still failed in testing.

**This is inherently fragile because:**
- Depends on macOS Accessibility permissions (revoked on rebuild)
- Depends on Claude Desktop's Electron UI layout not changing
- Keystroke timing is guesswork (fixed delays between steps)
- No feedback — can't tell if paste landed or Enter submitted
- Screen focus race conditions with other apps

## Options

### Option A: Fix AppleScript (patch current approach)

Debug the specific paste failure, add longer delays, possibly use AXUIElement APIs for more reliable UI targeting.

- **Pro:** Minimal code change, keeps Claude Desktop as the interface
- **Con:** Still fragile. Every Claude Desktop update could break it. Accessibility re-auth on every rebuild. No way to verify delivery.

### Option B: `claude` CLI with `--print` mode (recommended)

Replace AppleScript with a shell call to the Claude Code CLI:

```swift
// Instead of AppleScript keystrokes:
let process = Process()
process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/claude")
process.arguments = ["-p", "--print", prompt]
```

- **Pro:** Already installed (`claude` 2.1.37 on this machine). No UI automation. No Accessibility permission needed. Runs headless. Returns response text. Works through API — completely reliable.
- **Con:** Uses Claude Code API credits (not free-tier Claude Desktop). Loses the visual "conversation in Claude Desktop" that the user sees. Different model context (no MCP servers, no project knowledge unless configured).
- **Consideration:** Can pass `--model`, `--allowedTools`, `--add-dir`, `--mcp-config` flags to configure context. Could also use `--continue` to maintain conversation state across runs.

### Option C: Anthropic API direct

Call the Anthropic API directly from Swift using URLSession, bypassing both Claude Desktop and Claude Code CLI.

- **Pro:** Maximum control and reliability. No external dependencies.
- **Con:** Requires API key management in config. Most code to write. Same credit cost as Option B. No tool use or MCP without building it ourselves.

### Option D: MCP (not viable)

Claude Desktop is an MCP *client* — it connects to MCP servers for tools/resources. There's no way to push a prompt into Claude Desktop via MCP. Wrong architecture for this use case.

## Recommendation

**Option B (`claude -p`)** — best reliability-to-effort ratio:

1. Replace `sendPromptToClaude()` internals with `Process()` call to `claude -p`
2. Capture stdout as the response (enables future response handling)
3. Remove all AppleScript/System Events code
4. Remove Accessibility permission requirement
5. Keep `activateClaude` config option — if true, also `open -a Claude` for visibility

The change is ~30 lines in `ClaudeAutomator.swift`. Everything else (retry, locking, state persistence, health check) works unchanged.

## What Still Works

All Sprint 1 features are confirmed operational:
- State persistence (state.json created after successful fire)
- Retry logic (4 attempts with 5s/15s/45s backoff — verified in logs)
- Sleep/wake recovery (wired up, needs sleep cycle to test)
- Claude health check (menu shows status, blocks when not installed)
- Execution locking (prevents duplicate runs)
- Config file watching (auto-reloads on external edit)

## Decision Needed

Which prompt delivery method should we implement? This affects:
- Whether OctopusScheduler uses API credits or free Claude Desktop
- Whether prompts appear visually in Claude Desktop
- Long-term maintenance burden
