# OctopusScheduler - Launch Instructions

## Claude Code Launch Command

Open Terminal and run:

```bash
cd ~/ARAMAI/dev/octopus-scheduler && claude --dangerously-skip-permissions
```

### What `--dangerously-skip-permissions` does:
- Skips all permission prompts (file writes, bash commands, etc.)
- Allows Claude to work autonomously without human confirmation
- **Use only in trusted contexts** (like building your own app overnight)

### Alternative: Allowlist specific permissions

If you prefer more control:

```bash
cd ~/ARAMAI/dev/octopus-scheduler && claude \
  --allowedTools "Write,Edit,Bash,Read,Glob,Grep" \
  --prompt "Read BUILD-PROMPT.md and build the complete OctopusScheduler application"
```

## Full One-Liner

Copy this entire command to start the build:

```bash
cd ~/ARAMAI/dev/octopus-scheduler && claude --dangerously-skip-permissions "Read BUILD-PROMPT.md and follow all instructions to build the complete OctopusScheduler macOS application. Create all files, the Xcode project, and verify it compiles with xcodebuild."
```

## Quick Install (v1.2.0 Distribution Package)

For pre-built distribution:

1. **Unzip** `OctopusScheduler/build/dist/OctopusScheduler-v1.2.0.zip`
2. **Drag** `OctopusScheduler.app` to Applications
3. **Right-click → Open** (first launch bypasses Gatekeeper)
4. **Copy config:**
   ```bash
   mkdir -p ~/.octopus-scheduler
   cp config/default-config.json ~/.octopus-scheduler/config.json
   ```
5. **Copy prompts:**
   ```bash
   mkdir -p ~/ARAMAI/prompts/scheduled
   cp prompts/*.md ~/ARAMAI/prompts/scheduled/
   ```
6. **Grant Accessibility Permission** when macOS prompts
7. **Test**: Click the 🐙 menu bar icon → verify Bridge status shows green

## After Build Completes

1. **Open Xcode**:
   ```bash
   open ~/ARAMAI/dev/octopus-scheduler/OctopusScheduler/OctopusScheduler.xcodeproj
   ```

2. **Build & Run** (Cmd+R in Xcode)

3. **Grant Accessibility Permission** when macOS prompts

4. **Create config** (if not present):
   ```bash
   mkdir -p ~/.octopus-scheduler
   cp OctopusScheduler/build/dist/OctopusScheduler-v1.2.0/config/default-config.json ~/.octopus-scheduler/config.json
   ```

5. **Test**: Click the 🐙 menu bar icon → Run Now → Morning Briefing

## Monitoring the Build

In another Terminal window, you can watch progress:

```bash
# Watch the directory for new files
watch -n 2 'find ~/ARAMAI/dev/octopus-scheduler -name "*.swift" | wc -l'

# Or tail Claude's output if logging
tail -f ~/ARAMAI/dev/octopus-scheduler/build.log
```

## Troubleshooting

### Build fails with signing error
```bash
# Build without signing for local use
xcodebuild -project OctopusScheduler.xcodeproj \
  -scheme OctopusScheduler \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

### Missing Xcode command line tools
```bash
xcode-select --install
```

### Claude Code not found
```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code
```
