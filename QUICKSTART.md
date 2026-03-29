# Quick Start

Get the swarm running in 5 minutes.

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- [tmux](https://github.com/tmux/tmux) installed
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

Open each agent file and update the `<!-- CUSTOMIZE -->` sections:

```bash
# Edit all five:
$EDITOR .claude/agents/orchestrator.md
$EDITOR .claude/agents/researcher.md
$EDITOR .claude/agents/worker.md
$EDITOR .claude/agents/reviewer.md
$EDITOR .claude/agents/ux-reviewer.md
```

At minimum, set in each file:
- **Repo path** — absolute path to your repo
- **Languages** — what your project uses
- **Test command** — how to run tests (e.g., `npm test`, `pytest`)
- **Default branch** — `main` or `master`

### 4. Choose your tracker

In each agent file, uncomment the command block for your issue tracker (GitHub, GitLab, Linear, Jira, or local files) and delete the others.

### 5. Create status labels

```bash
# GitHub example (adapt for your platform):
gh label create "more-research-needed" --color "FBCA04" --description "Needs investigation"
gh label create "ready-to-assign" --color "0075CA" --description "Ready for worker agent"
gh label create "ready-to-merge" --color "0E8A16" --description "Reviewer recommends merge"
gh label create "human-only" --color "D93F0B" --description "Needs human input"
```

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

```bash
cd /path/to/your-repo
claude --agent orchestrator
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
