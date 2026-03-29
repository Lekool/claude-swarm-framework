# Quick Start

Get the swarm running in 5 minutes.

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- [tmux](https://github.com/tmux/tmux) installed (1.8+ required — `check-agents.sh` uses `capture-pane -p -S` which requires 1.8)
- **Windows users:** tmux is not available natively on Windows. Use [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install) to run the swarm
- Git
- An issue tracker CLI for your platform:
  - GitHub: [gh](https://cli.github.com/)
  - GitLab: [glab](https://gitlab.com/gitlab-org/cli)
  - Linear: [linear CLI](https://github.com/linear/linear-cli)
  - Jira: [jira-cli](https://github.com/ankitpokhrel/jira-cli)
  - Or none (use local file-based tracking)

## Setup

### 1. Copy template files into your repo

```bash
# From the framework directory:
cp -r template/.claude /path/to/your-repo/
cp -r template/scripts /path/to/your-repo/
cp -r template/tasks /path/to/your-repo/
chmod +x /path/to/your-repo/scripts/check-agents.sh
```

### 2. Create a `CLAUDE.md` in your repo root

Claude Code reads `CLAUDE.md` automatically at the start of every session. This is the single source of truth that all agents — orchestrator, researcher, worker, and reviewer — use to understand your project. Without it, agents will waste time rediscovering context or make wrong assumptions.

Your `CLAUDE.md` should include:
- **Project name and purpose** — what the repo is and does
- **Repo layout** — key directories and what they contain
- **Languages and frameworks** — what the project uses
- **How to build, test, and lint** — the exact commands (e.g., `npm test`, `pytest`, `cargo test`)
- **Coding conventions** — naming, patterns, anything agents should follow
- **Default branch** — `main` or `master`
- **Anything agents should avoid** — files not to touch, patterns not to use, known gotchas

You don't need a template — just describe your project clearly. If you're using Claude Code to set up the swarm, ask it to generate the `CLAUDE.md` for you based on your repo.

### 3. Fill in Project Context

Edit the shared project context file — all agents read this automatically:

```bash
$EDITOR .claude/agents/_project-context.md
```

At minimum, set:
- **Repo path** — absolute path to your repo
- **Languages** — what your project uses
- **Test command** — how to run tests (e.g., `npm test`, `pytest`)
- **Default branch** — `main` or `master`

### 4. Choose your tracker

Edit the shared tracker commands file — uncomment the section for your platform and delete the rest:

```bash
$EDITOR .claude/agents/_tracker-commands.md
```

### 5. Create status labels

Create the four required status labels in your tracker. See [Customization Guide — Step 3](docs/customization-guide.md#step-3-set-up-labels) for full commands and optional labels.

```bash
# GitHub quick version:
gh label create "more-research-needed" --color "FBCA04" --description "Needs investigation"
gh label create "ready-to-assign" --color "0075CA" --description "Ready for worker agent"
gh label create "ready-to-merge" --color "0E8A16" --description "Reviewer recommends merge"
gh label create "human-only" --color "D93F0B" --description "Needs human input"
```

### 5b. Set up a project board (optional but recommended)

If you use a project board (GitHub Projects, GitLab Boards, Linear, or Jira), the orchestrator can update it automatically at each phase transition. This gives you a real-time Kanban view of the swarm's progress without checking the terminal.

1. Create a board with columns: `Blocked`, `Todo`, `More Research Needed`, `Ready to Assign`, `In Progress`, `In Review`, `Ready to Merge`, `Done`
2. Fill in `tasks/board-config.json` with your board's IDs (a placeholder template is included)
3. See [Customization Guide — Step 4](docs/customization-guide.md#step-4-project-board-integration-recommended) for detailed setup instructions per platform

If you skip this step, the orchestrator works fine without a board — it just won't move items between columns.

### 6. Add project-specific permissions

Edit `.claude/settings.local.json` and add your test runner, linter, and any other tools agents need:

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(gh issue:*)",
      "Bash(gh label:*)",
      "Bash(gh pr:*)",
      "Bash(gh project:*)",
      "Bash(gh api:*)",
      "Bash(gh repo:*)",
      "Bash(find:*)",
      "Bash(grep:*)",
      "Bash(ls:*)",
      "Bash(echo:*)",
      "Bash(npm test:*)",
      "Bash(npx tsc:*)"
    ]
  }
}
```

### 7. Launch the swarm

**Important:** You must run this from the root of your target repo (where `.claude/` lives).

```bash
cd /path/to/your-repo && claude --agent orchestrator
```

Tell it: **"Work on open issues"**

The orchestrator will:
1. Set up a tmux session
2. Read your open issues
3. Triage them by priority
4. Dispatch researchers and workers
5. Monitor progress and dispatch reviewers
6. Label issues `ready-to-merge` when done

You check your issue tracker, review the PRs, and merge when satisfied.

> **About permission flags:** When the orchestrator dispatches agents, it uses `--dangerously-skip-permissions --permission-mode bypassPermissions`. The first flag bypasses Bash command prompts; the second bypasses file Edit/Write prompts. Both are needed for autonomous operation. This is safe when combined with the `settings.local.json` allowlist (Step 6), which includes `Edit`, `Write`, and specific `Bash(...)` permissions to control exactly what agents can do.

## What You'll See (First 30 Seconds)

After launching, the orchestrator will begin talking through its plan. Here's roughly what the first 30 seconds look like:

```
$ cd ~/projects/my-repo && claude --agent orchestrator

╭──────────────────────────────────────────╮
│ ✻ Welcome to Claude Code                 │
│   /help for help                         │
╰──────────────────────────────────────────╯

> Work on open issues

● Reading CLAUDE.md for project context...
● Fetching open issues from tracker...
● Found 5 open issues. Triaging by priority...
● Setting up tmux session "swarm"...
● Dispatching researcher-01 to investigate issue #12 (P0)...
● Dispatching researcher-02 to investigate issue #15 (P1)...
```

You'll see the orchestrator create tmux windows for each agent. You can watch all agents in real time with `tmux attach -t swarm` and switch between windows with `Ctrl-b n` (next) and `Ctrl-b p` (previous).

## Stopping the Swarm

To stop the swarm gracefully:

1. **Tell the orchestrator to stop:** Type in its window (or at the prompt):
   ```
   Write HANDOFF.md and stop. Wrap up any in-flight tasks.
   ```
   The orchestrator will write a `tasks/HANDOFF.md` summarizing in-flight work, then exit.

2. **Kill the tmux session** to clean up remaining windows:
   ```bash
   tmux kill-session -t swarm
   ```

3. **Clean up worktrees** (optional — do this after merging any open PRs):
   ```bash
   git worktree list          # see active worktrees
   git worktree remove wt-01  # remove a finished worktree
   ```

Next time you launch the swarm, the orchestrator will read `HANDOFF.md` to resume where it left off.

## What to Expect

- The orchestrator posts comments on issues with status updates and questions
- Workers open PRs/MRs against your default branch
- Reviewers post merge/change recommendations on issues
- Issues labeled `ready-to-merge` are waiting for your review
- Issues labeled `human-only` have questions for you

## Next Steps

- [Architecture](docs/architecture.md) — how the swarm works under the hood
- [Customization Guide](docs/customization-guide.md) — detailed adaptation for your project
- [Troubleshooting](docs/troubleshooting.md) — common issues and fixes
