# Claude Code Agent Swarm Framework

A framework for running a coordinated swarm of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) agents that collaboratively tackle GitHub Issues, GitLab Issues, Linear tickets, Jira stories, or local task files — using tmux for orchestration and git worktrees for parallel isolation.

## How It Works

An **orchestrator** agent reads your issue tracker, breaks work into scoped tasks, and dispatches specialized agents:

- **Researcher** — investigates issues, explores the codebase, posts implementation context (read-only)
- **Worker** — implements changes in an isolated git worktree, runs tests, opens a PR/MR
- **Reviewer** — evaluates the PR/MR for correctness, scope, and patterns (read-only)
- **UX Reviewer** — evaluates frontend PRs for visual consistency, accessibility, responsiveness, and design system adherence. Learns the user's taste before reviewing (read-only)

The **human** retains merge and deploy authority. No agent can merge to the default branch or touch production.

```
Issue Tracker ──> Orchestrator ──> Researcher ──> Worker ──> Reviewer ──> Human merges
                      │                                          │
                      └──── monitors via tmux + check-agents.sh ─┘
```

## Why This Approach

| Design choice | Rationale |
|---|---|
| **5 roles (4 core + UX)** | Safety through separation — read-only agents can't introduce bugs, workers can't merge. UX reviewer adds design-aware evaluation for frontend work |
| **tmux orchestration** | True process isolation, observable (capture pane output), redirectable (type into agent mid-task) |
| **Git worktrees** | Multiple workers run in parallel without file conflicts; pure git, works with any hosting platform |
| **Issue tracker as comm channel** | Human doesn't need to sit at the terminal; async by default |
| **Human merges & deploys** | Agents recommend, humans decide — the highest-consequence actions stay manual |
| **Append-only learning log** | Cross-session improvement; the orchestrator learns from past failures |

## Supported Platforms

The framework is platform-agnostic. Agent definitions include `<!-- CUSTOMIZE -->` markers for every platform-specific command.

| Component | GitHub | GitLab | Linear | Jira | Local Files |
|---|---|---|---|---|---|
| Issue tracking | `gh` CLI | `glab` CLI | `linear` CLI / API | `jira` CLI | YAML files |
| PR/MR creation | `gh pr create` | `glab mr create` | N/A (use git host) | N/A (use git host) | Push branch only |
| CI status | `gh pr checks` | `glab ci status` | N/A (use git host) | N/A (use git host) | Run tests locally |
| Labels/tags | `gh issue edit` | `glab issue update` | `linear issue update` | `jira issue transition` | state.json field |
| Git worktrees | Yes | Yes | Yes | Yes | Yes |
| tmux orchestration | Yes | Yes | Yes | Yes | Yes |

## Quick Start

See [QUICKSTART.md](QUICKSTART.md) for a 5-minute setup, or read on for the full picture.

## What's in the Box

```
template/
├── .claude/
│   ├── agents/
│   │   ├── orchestrator.md    # Coordinates the swarm
│   │   ├── researcher.md      # Investigates issues
│   │   ├── worker.md          # Implements code changes
│   │   ├── reviewer.md        # Evaluates PRs/MRs
│   │   └── ux-reviewer.md     # Evaluates frontend UX
│   └── settings.local.json    # Minimal permission allowlist
├── scripts/
│   └── check-agents.sh        # Tmux monitor (detects completion, errors, stuck agents)
└── tasks/
    ├── .gitkeep
    └── _template.yaml          # Task YAML template with inline docs

examples/
├── task-bug-fix.yaml           # Example: P0 bug fix
├── task-feature.yaml           # Example: new feature with milestones
├── task-refactor.yaml          # Example: Level 1 refactor with dependency
└── state.json                  # Example: mid-session state

docs/
├── architecture.md             # Roles, data flow, isolation, safety model
├── customization-guide.md      # 7-step adaptation guide with platform examples
└── troubleshooting.md          # Common failures and fixes
```

## The Safety Model

```
What agents CAN do          What agents CANNOT do        What only HUMANS can do
─────────────────────       ──────────────────────       ───────────────────────
Read any repo file          Merge to default branch      Merge PRs/MRs
Create branches/worktrees   Deploy to production         Deploy to production
Write code (workers only)   Modify production state      Make design decisions
Run tests (workers only)    Remove/weaken CI checks      Break deadlocks
Push branches               Work outside scope           Approve final changes
Open PRs/MRs                Modify files (researchers,
Post tracker comments        reviewers)
Add/remove labels
```

After 3 failed attempts on any task, the orchestrator stops and escalates to the human with a summary of what was tried and why it failed.

## Security Considerations

This framework grants Claude Code agents permission to **create, edit, and delete files** autonomously, and to run shell commands without interactive approval. This is by design — agents cannot implement code, run tests, or open PRs without these capabilities.

**Built-in safeguards:**

- **`settings.local.json` is the allowlist.** It controls exactly which tools (`Edit`, `Write`) and which shell commands (`Bash(git:*)`, `Bash(gh:*)`, etc.) agents are permitted to use. Anything not in the allowlist is blocked, even with permission flags enabled.
- **Workers operate in isolated worktrees**, not your main repo checkout. Changes are proposed via PR — they never land on the default branch without your review.
- **Researchers and reviewers are read-only by design.** They cannot create files, edit code, or push branches.
- **No agent can merge or deploy.** Merge authority and deployment are exclusively human actions. If an agent encounters a deploy step, it is instructed to refuse.
- **All work is visible in your issue tracker.** Every research finding, PR, and review recommendation is posted as a comment — you have full audit trail.

**Recommendations:**

- **Always review PRs before merging.** Agents propose, humans approve. Never auto-merge agent PRs.
- **Don't run the swarm directly on production repos.** The framework already uses worktrees for isolation — keep it that way.
- **Keep the allowlist specific.** Avoid `Bash(*)` — list only the commands your agents actually need.
- **Use sandboxed environments when possible.** CI runners, containers, or VMs add an extra layer of isolation.
- **Audit `settings.local.json` before sharing your repo.** It may contain paths or permissions specific to your setup.

## Swarm vs. Agent Teams vs. Sub-Agents

Claude Code offers three multi-agent approaches. This framework uses the **swarm** (isolated agents in tmux). See [docs/architecture.md](docs/architecture.md) for the full comparison, including how to enable agent teams and the hybrid research pattern.

| | Swarm (this framework) | Agent Teams (experimental) | Sub-Agents |
|---|---|---|---|
| **How it works** | Separate `claude` processes in tmux | Team lead spawns peer teammates | Child agents within one session |
| **Agent-to-agent talk** | None (by design) | Direct messaging + shared tasks | No (child-to-parent only) |
| **Audit trail** | Full (issue tracker) | None (local files, lost on restart) | None |
| **Session resumption** | Yes (HANDOFF.md + state.json) | Broken (known limitation) | N/A |
| **Human presence** | Not required | Should be at terminal | Must be in session |
| **Best for** | Multi-issue pipelines, async work | Real-time research, parallel review | Quick focused tasks |

**Hybrid pattern:** For complex issues, you can use an agent team for collaborative research (real-time debate between investigators), then hand off to the swarm for isolated execution. The issue tracker serves as the handoff interface. See [docs/architecture.md — Hybrid Pattern](docs/architecture.md#hybrid-pattern-agent-teams-for-research-swarm-for-execution).

If you also want **reusable prompt templates** within agent roles (e.g., a checklist the researcher always follows), use Claude Code **skills** (`.claude/skills/`). Skills run inside the invoking agent's context — they add knowledge, not isolation.

## State Management

The orchestrator maintains three files in `tasks/`:

| File | Purpose | Lifecycle |
|---|---|---|
| `state.json` | Central task tracking (tasks, worktrees, statuses) | Persistent across sessions |
| `learnings.jsonl` | Append-only log of task outcomes and prompt strategies | Persistent, never edited |
| `HANDOFF.md` | Session resumption brief (in-flight work, blocked tasks, next actions) | Written before stopping, deleted on next startup |

## Documentation

- [Quick Start](QUICKSTART.md) — 5-minute setup
- [Architecture](docs/architecture.md) — how the swarm works
- [Customization Guide](docs/customization-guide.md) — adapting for your project, platform-specific setup
- [Troubleshooting](docs/troubleshooting.md) — common issues and fixes

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (authenticated)
- [tmux](https://github.com/tmux/tmux) (1.8+)
- Git 2.15+ (worktree support)
- A tracker CLI: [gh](https://cli.github.com/), [glab](https://gitlab.com/gitlab-org/cli), [linear CLI](https://github.com/linear/linear-cli), [jira-cli](https://github.com/ankitpokhrel/jira-cli), or none (local files)

## Platform Notes

**Windows:** tmux is not available natively on Windows. Use [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install) (Windows Subsystem for Linux) to run the swarm. All commands in this framework assume a Unix shell.

## License

MIT
