# Claude Code Project Instructions

## Project

**Name:** Claude Code Agent Swarm Framework
**Repo:** `Lekool/claude-swarm-framework` on GitHub
**Default branch:** `main`
**Owner:** @Lekool (Leo)
**License:** MIT

## What This Is

A documentation and template framework for running coordinated Claude Code agent swarms. This is NOT a runnable application — it contains agent definitions, example configs, and docs that users copy into their own repos.

## Repo Layout

```
template/              # Files users copy into their repos
  .claude/
    agents/            # Agent role definitions (orchestrator, researcher, worker, reviewer, ux-reviewer)
      _project-context.md  # Shared project context (edited once, read by all agents)
      _tracker-commands.md # Shared tracker CLI commands (edited once, read by all agents)
    settings.local.json # Permission allowlist template
  scripts/
    check-agents.sh    # Tmux monitor script
  tasks/
    _template.yaml     # Task YAML template
    board-config.json  # Cached project board IDs (platform, field IDs, option IDs)

examples/              # Example files showing the framework in use
  state.json           # Example mid-session state
  task-*.yaml          # Example task YAMLs

docs/                  # Reference documentation
  architecture.md      # Roles, data flow, isolation, safety model
  customization-guide.md # 7-step adaptation guide
  troubleshooting.md   # Common failures and fixes

QUICKSTART.md          # 5-minute setup guide
README.md              # Project overview and comparison with other approaches
```

## Languages & Tooling

- **Content:** Markdown (`.md`), JSON, YAML, Bash
- **No build step.** No test suite. No package manager.
- **CLI tools used in examples:** `gh`, `glab`, `jira`, `linear`, `tmux`, `git`

## Conventions

- Agent definitions use `<!-- CUSTOMIZE -->` HTML comments to mark sections users must edit for their project
- Agent `.md` files use YAML frontmatter (`name`, `description`) for Claude Code agent registration
- The five agent roles are: orchestrator, researcher, worker, reviewer, ux-reviewer
- Status labels referenced throughout: `more-research-needed`, `ready-to-assign`, `ready-to-merge`, `human-only`
- Task tracking uses `tasks/state.json` (live state), `tasks/learnings.jsonl` (append-only log), `tasks/HANDOFF.md` (session resumption)

## Working on This Repo

When making changes:
- Keep the template files generic and platform-agnostic — platform-specific commands go behind `<!-- CUSTOMIZE -->` markers
- Changes to agent behavior should be reflected in both `template/.claude/agents/` and the corresponding docs
- Examples should stay realistic but self-contained
- The README comparison table (swarm vs. agent teams vs. sub-agents) should stay current with Claude Code capabilities
