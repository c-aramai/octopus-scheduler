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

## After Build Completes

1. **Open Xcode**:
   ```bash
   open ~/ARAMAI/dev/octopus-scheduler/OctopusScheduler/OctopusScheduler.xcodeproj
   ```

2. **Build & Run** (Cmd+R in Xcode)

3. **Grant Accessibility Permission** when macOS prompts

4. **Create config** (if Claude didn't):
   ```bash
   mkdir -p ~/.octopus-scheduler
   cp ~/ARAMAI/dev/octopus-scheduler/sample-config.json ~/.octopus-scheduler/config.json
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
