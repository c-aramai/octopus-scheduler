# OctopusScheduler - Vision Document

## The Problem

Modern AI assistants like Claude are incredibly powerful, but they're fundamentally reactive—they wait for humans to initiate every interaction. This creates friction for recurring tasks that benefit from AI assistance:

- **Morning briefings** that summarize project status
- **Daily journal entries** that capture accomplishments
- **Status updates** posted to team channels
- **Periodic health checks** on systems and documentation
- **Draft generation** that can be reviewed later

Currently, users must remember to prompt these tasks manually, breaking workflow and creating inconsistency.

## The Vision

**OctopusScheduler** transforms Claude from a reactive assistant into a proactive team member. Like an octopus extending its arms autonomously, it reaches out to perform scheduled tasks without human initiation.

### Core Principles

1. **Prompt Templates as Code**
   - Prompts live in version-controlled markdown files
   - Teams can share, review, and iterate on prompts
   - Variables enable dynamic, context-aware prompts

2. **Configuration Over Code**
   - JSON config defines what runs when
   - No coding required to add new schedules
   - Easy to enable/disable individual tasks

3. **Native macOS Experience**
   - Unobtrusive menu bar presence
   - One-time Accessibility permission grant
   - Launch at login, runs reliably in background

4. **Transparency & Control**
   - Clear visibility into what's scheduled
   - Manual "Run Now" for any prompt
   - Logs for debugging and auditing

## Use Cases

### Personal Productivity

```markdown
# Morning Standup (6:00 AM weekdays)
Review my calendar, check overnight messages, and prepare
a prioritized task list for today. Post to my #personal channel.
```

### Team Coordination

```markdown
# Project Status Update (9:00 AM daily)
Read the DASHBOARD.md, summarize blockers, highlight wins,
and post a team update to #octopus-state.
```

### Content Generation

```markdown
# Draft Review (7:00 PM weekdays)
Check the /drafts folder for any documents updated today.
Summarize what was worked on and suggest next steps.
```

### System Health

```markdown
# Documentation Check (Sunday 10:00 AM)
Review the /docs folder structure. Identify any outdated
files or missing documentation. Create a report.
```

## Architecture Philosophy

### Why a Native App?

- **Reliability**: launchd/Login Items ensure it runs
- **Permissions**: macOS Accessibility granted once to the app
- **Performance**: Minimal resource usage as menu bar app
- **Trust**: Users can inspect, it's not a black box

### Why Markdown Prompts?

- **Human-readable**: Anyone can write and review prompts
- **Git-friendly**: Version control, diffs, PRs work naturally
- **Portable**: Move prompts between machines/users
- **Extensible**: YAML frontmatter for metadata

### Why JSON Config?

- **Simple**: No custom DSL to learn
- **Toolable**: Standard editors, linters, formatters
- **Debuggable**: Easy to inspect and modify

## Future Possibilities

### Phase 1 (MVP)
- Menu bar app with scheduling
- Markdown prompt templates
- JSON configuration
- Basic variable substitution
- Manual "Run Now" trigger

### Phase 2
- Settings UI for visual config editing
- Schedule editor (no JSON editing required)
- Prompt template browser
- Execution history view

### Phase 3
- Response capture and logging
- Conditional execution (only if file changed)
- Webhook triggers (not just time-based)
- Multi-Claude support (different conversations)

### Phase 4
- Claude Code integration (not just Desktop)
- Remote prompt repositories
- Team sharing and sync
- Analytics dashboard

## Success Metrics

1. **Adoption**: User runs app daily without thinking about it
2. **Reliability**: 99%+ scheduled prompts execute on time
3. **Value**: Measurable time saved on recurring tasks
4. **Simplicity**: New prompt added in under 2 minutes

## The Octopus Metaphor

An octopus has eight semi-autonomous arms that can act independently while coordinated by the central brain. OctopusScheduler embodies this:

- **Central brain**: The scheduling engine coordinating everything
- **Arms**: Individual scheduled prompts reaching out to do work
- **Autonomy**: Each arm operates on its schedule
- **Coordination**: All serving the larger goals

*The octopus doesn't wait to be told to move its arms—it extends them purposefully, exploring and manipulating its environment. OctopusScheduler brings this proactive capability to AI assistance.*

---

**Project**: OCTOPUS (Orchestrated Claude Task Operations for Proactive Unified Scheduling)
**Author**: ARAMAI Team
**Version**: 1.0
**Date**: 2026-02-04
