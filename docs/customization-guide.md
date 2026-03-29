# Customization Guide

Step-by-step guide to adapting the swarm framework for your project.

## Step 1: Project Context

Edit `.claude/agents/_project-context.md` — this is the single source of truth that all five agents read at startup. Fill in the `<!-- CUSTOMIZE -->` fields for your project:

```markdown
- **Repo:** ~/path/to/your-repo/
- **Remote URL:** https://github.com/myorg/my-app
- **Languages:** TypeScript, Go
- **Test command:** npm test
- **CI:** GitHub Actions
- **Architecture docs:** docs/ARCHITECTURE.md
- **Coding guidelines:** CLAUDE.md
- **Default branch:** main
- **Worktree parent:** ~/worktrees/ (worktrees live as siblings to your repo)
- **Design system:** src/styles/tokens.css (optional, for ux-reviewer)
```

You edit this once — all agents pick it up automatically. Each agent file also has a fallback section you can fill in directly if the shared file is missing.

## Step 2: Choose Your Issue Tracker

Edit `.claude/agents/_tracker-commands.md` — uncomment the section matching your platform and delete the rest. All agents read this file for tracker CLI commands.

### GitHub

```bash
# Prerequisites: gh CLI (https://cli.github.com/)
gh auth login

# Commands used by agents:
gh issue list --state open --json number,title,labels --limit 50
gh issue view <N> --comments
gh issue comment <N> --body "..."
gh issue edit <N> --add-label "ready-to-assign"
gh pr create --base main --title "..." --body "..."
gh pr diff <N>
gh pr checks <N>
```

### GitLab

```bash
# Prerequisites: glab CLI (https://gitlab.com/gitlab-org/cli)
glab auth login

# Commands used by agents:
glab issue list --state opened
glab issue view <N> --comments
glab issue note <N> --message "..."
glab issue update <N> --label "ready-to-assign"
glab mr create --target-branch main --title "..." --description "..."
glab mr diff <N>
glab ci status
```

### Linear

```bash
# Prerequisites: linear CLI (https://github.com/linear/linear-cli) or API
# Linear uses team-scoped IDs (e.g., ENG-123)

# Via CLI:
linear issue list --team ENG --status "Todo"
linear issue view ENG-123
linear comment create --issue ENG-123 --body "..."
linear issue update ENG-123 --status "In Progress"

# Via API (if no CLI):
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ issues(filter: {team: {key: {eq: \"ENG\"}}}) { nodes { id title state { name } } } }"}'
```

### Jira

```bash
# Prerequisites: jira CLI (https://github.com/ankitpokhrel/jira-cli)
jira init

# Commands used by agents:
jira issue list --project MYPROJ --status "To Do"
jira issue view MYPROJ-123
jira issue comment add MYPROJ-123 --body "..."
jira issue transition MYPROJ-123 "In Progress"

# PRs are opened on your git host (GitHub/GitLab/Bitbucket), not Jira
```

### Local Files (No External Tracker)

For small teams or personal projects that don't want an external tracker:

```bash
# Issues are YAML files in tasks/
ls tasks/*.yaml

# Research findings go in companion files
cat tasks/fix-auth.research.md

# Review verdicts go in companion files
cat tasks/fix-auth.review.md

# Status is tracked in state.json
cat tasks/state.json
```

The orchestrator reads task YAMLs directly instead of fetching issues from an API. Labels are replaced by the `status` field in state.json.

## Step 3: Set Up Labels

Create the required status labels in your tracker:

```bash
# GitHub
gh label create "more-research-needed" --color "FBCA04" --description "Needs investigation before implementation"
gh label create "ready-to-assign" --color "0075CA" --description "Clear and ready for a worker agent"
gh label create "ready-to-merge" --color "0E8A16" --description "Reviewer recommends merge — human decision"
gh label create "human-only" --color "D93F0B" --description "Needs human input — swarm will not touch"

# GitLab
glab label create "more-research-needed" --color "#FBCA04" --description "Needs investigation"
glab label create "ready-to-assign" --color "#0075CA" --description "Ready for worker agent"
glab label create "ready-to-merge" --color "#0E8A16" --description "Reviewer recommends merge"
glab label create "human-only" --color "#D93F0B" --description "Needs human input"
```

Optional but recommended labels:
- **Priority:** `P0-critical`, `P1-high`, `P2-medium`
- **Type:** `feature`, `bug`, `refactor`, `docs`
- **Area:** project-specific (e.g., `area/api`, `area/frontend`, `area/auth`)

## Step 4: Set Up a Project Board (Optional)

A Kanban board helps visualize the pipeline. Set up columns:

```
Blocked -> Todo -> More Research Needed -> Ready to Assign -> In Progress -> Done
```

### GitHub Projects

```bash
# Discover your project ID and field IDs
gh project list --owner YOUR_ORG --format json
gh project field-list PROJECT_NUMBER --owner YOUR_ORG --format json
```

Update the orchestrator with your project ID and field option IDs for moving items between columns.

### GitLab Boards

Create a board in your GitLab project settings. Map labels to columns.

### Linear / Jira

These have built-in workflow states that serve the same purpose. Map the swarm's status labels to your existing workflow states.

## Step 5: Configure Permissions

Edit `.claude/settings.local.json` to add permissions for your project's tooling.

The template includes minimal git and CLI permissions. Add your project-specific tools:

> **Note:** JSON does not support comments. The `//` lines in the example below are for illustration only — remove them and uncomment only the permissions you need.

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

      "// CUSTOMIZE: Add your project-specific permissions below",

      "// Test runners:",
      "// Bash(npx vitest:*)",
      "// Bash(npm test:*)",
      "// Bash(pytest:*)",
      "// Bash(cargo test:*)",
      "// Bash(go test:*)",

      "// Type checkers / linters:",
      "// Bash(npx tsc:*)",
      "// Bash(npx eslint:*)",

      "// Build tools:",
      "// Bash(npm run build:*)",
      "// Bash(cargo build:*)",

      "// Package managers:",
      "// Bash(npm install:*)",
      "// Bash(pip install:*)",

      "// GitLab CLI (if using GitLab):",
      "// Bash(glab:*)",

      "// SSH for read-only production inspection:",
      "// Bash(ssh:*)",

      "// Web access for docs:",
      "// WebSearch",
      "// WebFetch(https://docs.your-service.com:*)"
    ]
  }
}
```

## Step 6: Create Your `CLAUDE.md`

Claude Code reads `CLAUDE.md` from the repo root at the start of every session. This is the **primary** way all agents — orchestrator, researcher, worker, and reviewer — get project context. The `<!-- CUSTOMIZE -->` sections in agent files define agent behavior; `CLAUDE.md` defines project knowledge.

**Your `CLAUDE.md` should include:**

- **Project name and purpose** — what the repo is and does
- **Repo layout** — key directories and what they contain
- **Languages and frameworks** — what the project uses
- **How to build, test, and lint** — the exact commands (e.g., `npm test`, `pytest`, `cargo test`)
- **Coding conventions** — naming, patterns, anything agents should follow
- **Default branch** — `main` or `master`
- **Architecture overview** — or a pointer to your architecture docs
- **Anything agents should avoid** — files not to touch, patterns not to use, known gotchas

**If your repo doesn't have a `CLAUDE.md` yet, create one now.** This is the single most impactful step — without it, agents will waste time rediscovering project context or make wrong assumptions. You don't need a template — just describe your project clearly. If you're using Claude Code to set up the swarm, ask it to generate the `CLAUDE.md` for you based on your repo.

**Optional additional docs to reference:**

If your project has other documentation, point to it from `CLAUDE.md` or from the `## Project Context` section in each agent file:

- **Architecture doc:** `ARCHITECTURE.md`, `docs/architecture.md`, or a wiki link
- **Knowledge base:** A `findings.md` or `INCIDENTS.md` with root-cause analyses from past bugs
- **API docs:** OpenAPI specs, Postman collections

## Step 7: Optional Features

### Production Inspection (Read-Only SSH)

If you want agents to inspect a production or staging server (read-only), add an SSH policy section to the orchestrator and researcher agents:

```markdown
## SSH Policy (Read-Only)

You and researcher agents may SSH to production to understand the current state.
**You may NEVER modify anything.**

**Allowed** (read-only inspection):
- `ssh user@host "docker ps"`
- `ssh user@host "tail -100 /var/log/app.log"`
- `ssh user@host "cat /etc/app/config.yml"`

**Forbidden** (anything that modifies state):
- deploy, restart, stop, rm, mv, cp, chmod, kill
- Any redirect that writes: >, >>, tee
- Any package manager install commands
```

Add `Bash(ssh:*)` to your `settings.local.json` permissions.

### Custom Agent Roles

The framework includes a **UX Reviewer** (`ux-reviewer.md`) for frontend-heavy projects. The orchestrator automatically dispatches it when a PR touches frontend files (components, styles, layouts). The UX reviewer learns the user's design taste before reviewing and may request screenshots when it needs to see rendered output. See the agent definition for the full taste discovery workflow.

You can create additional agent roles beyond the five defaults. Common additions:

- **Doc Writer** — generates documentation from code changes (read-only + writes docs)
- **Migration Author** — writes database migration scripts (scoped write access)
- **Security Reviewer** — specialized reviewer focused on security patterns

Create a new `.md` file in `.claude/agents/` following the same format. Define clear rules about what the agent can and cannot do.

### Claude Code Skills

For repetitive prompt patterns within agent roles, consider creating Claude Code skills in `.claude/skills/`. Skills are prompt templates that agents or users can invoke:

- `/format-task-yaml` — helps the orchestrator format task YAMLs consistently
- `/research-checklist` — reminds researchers what to investigate
- `/review-template` — provides a consistent review comment structure

Skills run inside the invoking agent's context (not in isolation). Use them for knowledge delivery, not for independent work. See the Claude Code docs for skill creation syntax.

### Notification Customization

The orchestrator and monitor script support desktop notifications. Customize for your platform:

```bash
# macOS
osascript -e 'display notification "message" with title "Swarm"'

# Linux (requires libnotify)
notify-send "Swarm" "message"

# Slack webhook (for team visibility)
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Swarm: Issue #42 ready to merge"}' \
  $SLACK_WEBHOOK_URL

# Discord webhook
curl -X POST -H 'Content-type: application/json' \
  --data '{"content":"Swarm: Issue #42 ready to merge"}' \
  $DISCORD_WEBHOOK_URL
```
