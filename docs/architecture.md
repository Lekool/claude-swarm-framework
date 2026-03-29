# Architecture

How the Claude Code agent swarm works — roles, data flow, isolation, and safety.

## Overview

The swarm is a set of specialized Claude Code agents that collaborate through an issue tracker and git worktrees, coordinated by an orchestrator running in tmux. The human retains merge and deploy authority.

```
                    ┌─────────────────────────────┐
                    │       Issue Tracker          │
                    │  (GitHub / GitLab / Linear   │
                    │   / Jira / local files)      │
                    └──────┬──────────────▲────────┘
                           │              │
                     read issues    post comments,
                     & labels       labels, status
                           │              │
                    ┌──────▼──────────────┴────────┐
                    │        Orchestrator           │
                    │   (coordinator — no code)     │
                    └──┬────┬────┬────────▲────────┘
                       │    │    │        │
              dispatch │    │    │        │ monitor
                       │    │    │        │ (check-agents.sh)
                 ┌─────▼┐ ┌▼────▼─┐  ┌───┴──────┐
                 │Resear-│ │Worker │  │Reviewer  │
                 │cher   │ │(code) │  │(read-    │
                 │(read- │ │       │  │ only)    │
                 │ only) │ │       │  │          │
                 └───────┘ └───┬───┘  └──────────┘
                               │
                          opens PR/MR
                               │
                    ┌──────────▼──────────────────┐
                    │         Human                │
                    │   (merges & deploys)          │
                    └─────────────────────────────┘
```

## The Four Roles

| Role | Reads | Writes | Isolation | Purpose |
|------|-------|--------|-----------|---------|
| **Orchestrator** | Issues, labels, CI status, state.json | Comments, labels, task YAMLs, state.json | Main repo | Coordinates everything; never touches code |
| **Researcher** | Issues, codebase, tests, production (read-only) | One comment on the issue | Main repo | Investigates issues; produces briefings for workers |
| **Worker** | Task YAML, issue comments, codebase | Code, tests, commits, PRs/MRs | Isolated worktree | Implements scoped changes |
| **Reviewer** | Issue comments, PR diff, CI status | One comment on the issue | Main repo | Evaluates quality; recommends merge or changes |
| **UX Reviewer** | Issue comments, PR diff, taste profile, design system | One comment (may request screenshots first) | Main repo | Evaluates frontend UX against user's design preferences |

### Why five roles and not one?

**Safety through separation of concerns.** Each role has strict boundaries:

- The **orchestrator** can dispatch and monitor but can't write code — it can't accidentally introduce bugs or ship broken changes.
- **Researchers** are read-only — they explore freely without risk of modifying anything.
- **Workers** write code but only in isolated worktrees — they can't corrupt the main branch or affect other workers.
- **Reviewers** are read-only — they evaluate independently without the temptation to "just fix it."
- **UX Reviewers** are read-only with a design-specific lens — they evaluate frontend work against the user's stated taste and design goals, not their own opinions. They can request screenshots when they need to see rendered output.

The **human** retains the most consequential actions: merging to the default branch and deploying to production. No agent can do either.

## Communication Model

### Async: Issue Tracker

All orchestrator-to-human communication goes through the issue tracker. The human doesn't need to sit at the terminal. They check their tracker, see labels like `ready-to-merge` or `human-only`, and act at their own pace.

Agents communicate with each other through issue comments:
1. Researcher posts implementation context on the issue
2. Worker reads the researcher's comment before starting
3. Reviewer reads both the issue and the PR diff
4. Orchestrator reads all comments to track progress

### Real-time: tmux

The orchestrator manages agents through tmux windows. This enables:
- **Dispatching** — launching new agents in windows
- **Monitoring** — the `check-agents.sh` script watches all windows and reports status
- **Redirection** — typing into an agent's window to course-correct mid-task
- **Observation** — capturing pane output to see what an agent is doing

## Isolation Model

### Git Worktrees

Each worker operates in an **isolated git worktree** — a separate working directory with its own branch, sharing git history with the main repo.

```
~/projects/
├── my-repo/              # Main repo (orchestrator lives here)
├── wt-01/                # Worktree for worker-01 (branch: feature/auth)
├── wt-02/                # Worktree for worker-02 (branch: fix/timeout)
└── wt-03/                # Free worktree for next task
```

**Why worktrees, not branches?**
- Multiple workers can run in parallel without file conflicts
- Each worker has its own `node_modules`, build artifacts, etc.
- A worker can't accidentally edit files another worker is using
- Worktrees are a pure git feature — they work with any hosting platform

**Rules:**
- One agent per worktree at a time (enforced by orchestrator)
- Worktrees are created from the latest default branch
- Worktrees are cleaned up after the human merges the PR

### tmux Windows

Each agent runs in its own tmux window within a `swarm` session:

```
swarm:orchestrator    # The orchestrator (you)
swarm:worker-01       # First worker
swarm:worker-02       # Second worker
swarm:researcher-01   # Researcher
swarm:reviewer-01     # Reviewer
swarm:monitor         # check-agents.sh (auto-watches all windows)
```

Windows can be reused — once worker-01 finishes, its window can be used for a reviewer.

## State Management

### state.json

Central task tracking file. The orchestrator reads and writes this. Workers and reviewers don't touch it.

```json
{
  "tasks": { "feature/name": { "level": 0, "issue": 42, "status": "in-progress", ... } },
  "worktrees": { "~/wt-01": "feature/name", "~/wt-02": "free" },
  "ready_for_human": ["feature/name"]
}
```

### learnings.jsonl

Append-only log of task outcomes. The orchestrator writes one line per task completion or failure. Before creating new tasks, it reads recent entries to avoid repeating mistakes.

```jsonl
{"task":"feature/auth","issue":42,"result":"success","prompt_strategy":"included types upfront","notes":"..."}
{"task":"fix/timeout","issue":43,"result":"failed_3x","root_cause":"wrong file","fix":"be explicit about paths"}
```

### HANDOFF.md

Session resumption brief. Written by the orchestrator before stopping. Read on next startup, then deleted. Contains: in-flight work, blocked tasks, ready-to-merge items, and next actions.

## Safety Model

### What agents CAN do
- Read any file in the repo
- Create branches and worktrees
- Write code (workers only)
- Run tests (workers only)
- Push branches to the remote
- Open PRs/MRs
- Post comments on issues
- Add/remove labels

### What agents CANNOT do
- Merge PRs/MRs to the default branch
- Deploy to production
- Modify production systems
- Remove or weaken CI checks
- Work outside their assigned scope (workers)
- Modify files (researchers and reviewers)

### What only the HUMAN can do
- Merge PRs/MRs
- Deploy
- Make design decisions (issues labeled `human-only`)
- Approve final changes
- Break deadlocks when agents fail 3 times

## Platform Independence

The swarm design is platform-agnostic. The core mechanisms are:

| Component | Platform-agnostic? | What changes per platform |
|---|---|---|
| Git worktrees | Yes (pure git) | Nothing |
| tmux orchestration | Yes | Nothing |
| check-agents.sh monitor | Yes | Nothing |
| Task YAML format | Yes | Nothing |
| State tracking (JSON) | Yes | Nothing |
| Issue reading/writing | No | CLI commands differ (gh, glab, jira, linear, curl) |
| PR/MR creation | No | CLI commands differ |
| CI status checking | No | API/CLI differs |
| Labels/tags | No | Terminology and commands differ |

The agent definition files use `<!-- CUSTOMIZE -->` markers at every platform-specific command to make adaptation straightforward.

## Swarm vs. Agent Teams vs. Sub-Agents

Claude Code offers three multi-agent approaches. This framework uses the **swarm** (isolated agents in tmux), but it's worth understanding how it compares to the built-in alternatives so you can pick the right tool for the job.

### How each approach works

**Swarm (this framework):**
Each agent is a separate `claude` process running in its own tmux window. The orchestrator dispatches them by piping prompts into tmux panes. Agents don't talk to each other — they communicate through the issue tracker (comments, labels). Workers run in isolated git worktrees.

**Agent Teams (experimental, built into Claude Code):**
A "team lead" Claude session spawns "teammates" — separate Claude instances that share a task list and can message each other directly. Teammates are peers that collaborate in real-time. All run on the same machine, coordinated through local state managed by Claude Code.

**Sub-Agents (built into Claude Code):**
A single Claude session spawns child agents using the `Agent` tool. Sub-agents run inside the parent's session, share its permissions, and return results back to the parent's context. They can use `isolation: "worktree"` for automatic git worktree creation.

### Comparison

| Aspect | Swarm (this framework) | Agent Teams | Sub-Agents |
|---|---|---|---|
| **Process model** | Separate `claude` processes in tmux | Separate Claude instances, peer-to-peer | Child agents within one session |
| **Context windows** | Independent (full context each) | Independent (full context each) | Shared with parent |
| **Communication** | Through issue tracker only (async) | Direct messaging + shared task list (real-time) | Results returned to parent |
| **Agent-to-agent talk** | None (by design) | Yes — teammates message each other | No — only child-to-parent |
| **Isolation** | Git worktrees (manual, full control) | Shared repo (no built-in isolation) | Optional worktree (`isolation: "worktree"`) |
| **Permissions** | Per-agent role enforcement (read-only, write, etc.) | All inherit lead's permissions | Inherit parent's permissions |
| **Audit trail** | Full — everything in issue tracker | None — local files, lost on restart | None — in parent's context only |
| **Session resumption** | Yes (HANDOFF.md + state.json) | Broken (known limitation) | N/A (ephemeral) |
| **Learning across sessions** | Yes (learnings.jsonl) | No | No |
| **Setup complexity** | Higher (tmux, monitor script, state files) | Low (just ask Claude to create a team) | Lowest (happens automatically) |
| **Human presence required** | No — check tracker whenever | Yes — should be at terminal | Yes — within a session |
| **Best for** | Multi-issue pipelines, async work, audit trails | Real-time research, parallel review, debugging | Quick focused tasks, verbose output isolation |
| **Stability** | Mature (battle-tested) | Experimental (env var flag required) | Stable |
| **Token cost** | N agents = ~Nx tokens (no cross-talk overhead) | N agents = ~Nx tokens + messaging overhead | Lower (shared context, summarized results) |

### When to use which

**Use the swarm when:**
- You have multiple issues to work through and won't be at the terminal
- Work spans hours or days and needs to be resumable
- You need an audit trail (who did what, when, and why)
- You want strict role enforcement (reviewers can't edit, workers can't merge)
- Multiple people check the tracker (e.g., you and a collaborator)
- Tasks have dependencies (Level 0 before Level 1)

**Use agent teams when:**
- You're at the keyboard for a focused session
- Research benefits from agents debating and cross-pollinating findings
- You need parallel code review from different angles (security, performance, coverage)
- You're debugging a complex issue with multiple possible root causes
- The work is self-contained and doesn't need to persist

**Use sub-agents when:**
- You need a quick, focused task done without leaving your current session
- The task produces verbose output you don't want cluttering your context
- You want automatic worktree isolation without manual setup
- The task is simple enough that a full agent team or swarm is overkill

### Enabling agent teams

Agent teams are experimental. To enable:

**Step 1:** Add the environment variable to your Claude Code settings:

```json
// ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Step 2:** Choose a display mode (optional). In `~/.claude/settings.json`:

```json
{
  "teammateMode": "tmux"
}
```

Options:
- `"in-process"` (default) — all teammates in one terminal, cycle with Shift+Down
- `"tmux"` — each teammate gets its own tmux pane (requires tmux)
- `"auto"` — uses tmux if available, falls back to in-process

**Step 3:** Just ask Claude to create a team:

```
Create a team with 3 teammates to investigate the performance regression in the API layer
```

Claude handles spawning, task assignment, and coordination. No config files or agent definitions needed.

**Known limitations (as of early 2026):**
- Session resumption (`/resume`, `/rewind`) doesn't restore teammates
- Teammates sometimes fail to mark tasks complete, blocking dependent tasks
- One team per session — must clean up before starting a new team
- No nesting — teammates cannot spawn their own teams or sub-agents
- Shutdown is async — teammates finish their current action before exiting

## Hybrid Pattern: Agent Teams for Research, Swarm for Execution

For complex issues, you can combine both approaches — using an agent team for collaborative research, then handing off to the swarm for isolated execution.

### Why hybrid?

Single researchers work well for straightforward issues ("find the affected files, suggest an approach"). But some issues benefit from multiple perspectives investigating in parallel and sharing findings in real-time — the kind of cross-talk that the swarm deliberately prevents.

The hybrid gives you the best of both:
- **Research phase:** agent team with real-time collaboration and debate
- **Execution phase:** isolated workers in worktrees with audit trail and safety

### How it works

```
┌─────────────────────────────────────────────────────────┐
│                    Research Phase                         │
│                    (Agent Team)                           │
│                                                          │
│   Lead ←──messages──→ Teammate A (database layer)        │
│     ↕                  Teammate B (API layer)            │
│     ↕                  Teammate C (similar patterns)     │
│     ↕                                                    │
│   Lead synthesizes findings                              │
│   → Posts research comment on issue                      │
│   → Team disbanded                                       │
│                                                          │
├─────────────────────────────────────────────────────────┤
│                    Issue Tracker                          │
│              (research comment = handoff)                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│                    Execution Phase                        │
│                    (Swarm)                                │
│                                                          │
│   Orchestrator reads research comment                    │
│   → Creates task YAML                                    │
│   → Dispatches worker in isolated worktree               │
│   → Worker reads research, implements, opens PR          │
│   → Reviewer evaluates PR                                │
│   → Human merges                                         │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

The **issue tracker is the handoff interface**. The agent team's synthesized findings become a research comment on the issue — the exact same format a single swarm researcher would have posted. The swarm's workers consume it without knowing or caring whether it came from one researcher or a team of three.

### When to use hybrid vs. single researcher

| Scenario | Approach |
|---|---|
| "Find the affected files and suggest an approach" | Single researcher (swarm default) |
| "Why is this slow? Could be DB, API, or frontend" | Agent team (3 teammates, one per theory) |
| "How should we implement auth? Compare OAuth, JWT, and session-based" | Agent team (3 teammates, one per approach) |
| "What files does this feature touch?" | Single researcher |
| "This bug spans 4 modules and we don't know the root cause" | Agent team (parallel investigation) |
| "Review this PR from security, performance, and coverage angles" | Agent team (3 focused reviewers) |

**Rule of thumb:** If the issue is ambiguous, has multiple possible root causes, or spans 3+ unrelated modules, an agent team for research is worth the extra token cost. For everything else, a single researcher is simpler and cheaper.

### Implementation notes

The hybrid pattern doesn't require changes to the swarm framework. The orchestrator already supports this workflow:

1. For issues labeled `more-research-needed`, the orchestrator decides whether to dispatch a single researcher or spin up an agent team
2. Either way, the output is a research comment on the issue
3. The rest of the pipeline (task YAML → worker → reviewer → human merge) is unchanged

To add this capability to your orchestrator, add guidance in the orchestrator agent definition under Phase 2 (Research):

```markdown
**Research escalation:** If the issue is ambiguous, has multiple possible root causes,
or spans 3+ modules, consider using an agent team instead of a single researcher.
Spin up 2-3 teammates with focused investigation areas. Have the lead synthesize
findings and post the research comment. Disband the team before proceeding to
worker dispatch.
```

The orchestrator would use Claude Code's agent team feature directly (since it's running as a Claude session itself), or you can run the research team manually before launching the swarm.
