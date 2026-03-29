# Troubleshooting

Common failures and fixes, distilled from real-world usage of the swarm framework.

## Dispatch Issues

### "cmdand quote>" or broken multi-line prompts in tmux

**Problem:** Using `tmux send-keys -t swarm:worker-01 "claude -p 'long prompt...'"` produces garbled input with `cmdand quote>` continuation prompts.

**Fix:** Always use the `cat file | claude` pattern:
```bash
cat > /tmp/worker-task.txt << 'PROMPT'
Your multi-line prompt here.
It can span as many lines as needed.
PROMPT

tmux send-keys -t swarm:worker-01 \
  "cd ~/worktrees/wt-01 && cat /tmp/worker-task.txt | claude --dangerously-skip-permissions --permission-mode bypassPermissions --agent worker" Enter
```

Never use inline `-p '...'` or `$(cat file)` expansion in tmux — both are unreliable.

### Agent didn't start

**Problem:** After dispatching, the tmux window shows no Claude activity.

**Fix:** Always verify after dispatch:
```bash
sleep 5 && tmux capture-pane -t swarm:worker-01 -p | tail -3
```

Common causes:
- The `cd` path was wrong (worktree doesn't exist yet)
- `claude` isn't in PATH in the tmux environment
- The agent file name doesn't match `--agent <name>`
- Previous Claude process is still running in that window

### Claude blocked on permission prompt

**Problem:** Agent stopped because it hit a tool that requires user approval.

**Fix:** Either answer it via `tmux send-keys`, or kill and re-dispatch with `--dangerously-skip-permissions --permission-mode bypassPermissions`. Better yet, add the permission to `settings.local.json` before dispatching.

### Workers stuck on Edit/Write file permission prompts in worktrees

**Problem:** Workers get stuck on interactive prompts like "Do you want to create file.ts?" for every file they try to create or edit. The "allow all edits this session" option doesn't persist across different files.

**Root cause:** Three things combine to cause this:

1. **`settings.local.json` missing `Edit`/`Write`** — the template only listed `Bash(...)` permissions. Claude Code's `Edit` and `Write` file tools are separate and need their own allowlist entries.
2. **Worktrees don't inherit `.claude/`** — Git worktrees are bare checkouts that don't include `.claude/settings.local.json` from the source repo. Claude Code resolves settings from the working directory.
3. **`--dangerously-skip-permissions` only covers Bash** — it bypasses Bash command prompts but not `Edit`/`Write` file tool prompts. You also need `--permission-mode bypassPermissions`.

**Fix (belt and suspenders — do all three):**

1. Add `Edit` and `Write` to `settings.local.json`:
   ```json
   {
     "permissions": {
       "allow": [
         "Edit",
         "Write",
         "Bash(git:*)",
         ...
       ]
     }
   }
   ```

2. Copy `.claude/` into each worktree before dispatching:
   ```bash
   cp -r ~/path/to/your-repo/.claude ~/worktrees/wt-01/
   ```

3. Use both flags when dispatching:
   ```bash
   claude --dangerously-skip-permissions --permission-mode bypassPermissions --agent worker
   ```

## Worktree Issues

### Worktree created from stale local branch

**Problem:** Worker starts with outdated code because the worktree was created from a local `main` that hasn't been pulled.

**Fix:** Always fetch before creating worktrees:
```bash
git -C ~/path/to/repo fetch origin
git -C ~/path/to/repo worktree add ~/worktrees/wt-01 -b feature/name origin/main
```

Note `origin/main` instead of `main` — this creates from the remote, not the local branch.

### Worktree has merge conflicts

**Problem:** Worker can't push because the default branch moved while they were working.

**Fix:** The orchestrator should NOT try to auto-resolve. Instead:
1. Let the human merge the first PR
2. Rebase the second worktree: `cd ~/worktrees/wt-02 && git rebase origin/main`
3. Re-dispatch the worker if needed

### Worktree removal fails ("is locked")

**Problem:** `git worktree remove` fails because the worktree is locked or has uncommitted changes.

**Fix:**
```bash
# Check what's happening
git -C ~/path/to/repo worktree list

# Force removal if the work is already merged
git -C ~/path/to/repo worktree remove ~/worktrees/wt-01 --force
```

## Monitor Issues

### Monitor not detecting agent completion

**Problem:** The `check-agents.sh` monitor doesn't fire the "agent finished" notification.

**Cause:** The monitor detects shell prompts by looking for patterns like `❯`, `~/path`, or `✔` in pane output. If your shell prompt looks different, the detection may fail.

**Fix:** Edit `check-agents.sh` and update the prompt detection regex:
```bash
# Find this line and add your prompt pattern:
if echo "$text" | grep -qE '(❯|~/[^ ].*\$\s*$|~/[^ ].*✔|YOUR_PATTERN)'; then
```

### Monitor crashed silently

**Problem:** No `[MONITOR]` messages appearing in the orchestrator pane.

**Fix:** Check if the monitor is running and restart:
```bash
# Check the monitor window
tmux capture-pane -t swarm:monitor -p | tail -5

# Restart it
tmux send-keys -t swarm:monitor "bash ~/path/to/repo/scripts/check-agents.sh" Enter
```

Check `/tmp/swarm-monitor.log` for errors.

## Agent Behavior Issues

### Worker edits files outside scope

**Problem:** The worker modified files not listed in the task YAML.

**Fix:** This is caught by the reviewer (scope compliance check). The reviewer will recommend changes, and the orchestrator will create a revision task.

To prevent it, be explicit in the task YAML:
```yaml
files:
  - src/api/upload.ts        # ONLY these files
  - tests/api/upload.test.ts

do_not_modify:
  - src/api/index.ts         # Explicitly protect sensitive files
```

### Worker went off-track

**Problem:** The worker is implementing the wrong approach or editing the wrong file.

**Fix:** Redirect via tmux BEFORE killing:
```bash
tmux send-keys -t swarm:worker-01 "Stop. You're editing the wrong file. The handler is in src/api/auth.ts, not src/middleware/auth.ts." Enter
```

Only kill and re-dispatch if redirection doesn't work. Each re-dispatch costs a full agent startup.

### Researcher comment is too vague

**Problem:** The researcher posted a comment that doesn't give the worker enough to start.

**Fix:** Enhance the researcher's prompt to be more specific:
```
Research issue #42. Focus on:
1. The exact file paths and line numbers the worker will modify
2. The existing patterns in those files
3. Any type definitions the worker will need
```

Also check that the researcher has access to the right docs (architecture, coding guidelines).

### Reviewer is too strict / too lenient

**Problem:** Reviewer blocks PRs for minor style issues, or approves PRs with real problems.

**Fix:** Tune the reviewer's guidelines section. The default says:
> If the PR is 90% good with one minor issue, recommend merge with a note rather than blocking.

Adjust this threshold for your team's preferences. You can also add project-specific review criteria.

## Test Issues

### Tests run in watch mode and never exit

**Problem:** The worker runs `vitest` or `jest` which enters watch mode, and the monitor thinks the agent is stuck.

**Fix:** Ensure your test command exits after running:
```bash
# vitest
npx vitest --run

# jest
npx jest --ci

# pytest (already exits by default)
pytest
```

Update the test command in all agent definitions and task YAMLs.

### Pre-existing test failures

**Problem:** Tests that were already failing before the worker's change are now blocking the PR.

**Fix:** The worker agent is instructed to note pre-existing failures in the PR but not fix them. If CI is red due to pre-existing failures, the orchestrator should:
1. Check if the failures are related to the worker's change
2. If unrelated, note it in the issue and ask the human to decide
3. Consider fixing the pre-existing failures as a separate Level 0 task

## State Issues

### state.json out of sync with reality

**Problem:** `state.json` says a task is `in-progress` but the worker finished and a PR exists.

**Fix:** The orchestrator should reconcile on startup:
```bash
# Check for PRs on branches tracked in state.json
gh pr list --json headRefName,number,state
```

Compare with state.json and update accordingly.

### HANDOFF.md is stale

**Problem:** The orchestrator reads an old HANDOFF.md and tries to resume tasks that were already completed.

**Fix:** The orchestrator always cross-references HANDOFF.md with the current tracker state:
- Are `ready-to-merge` PRs already merged?
- Are `in-progress` tasks already completed?
- Were new issues opened since the handoff?

After reading and reconciling, the orchestrator deletes HANDOFF.md.

## Communication Issues

### Orchestrator goes silent after dispatching agents

**Problem:** The orchestrator dispatches workers/researchers and says "I'll check back" or goes quiet. The human waits for an update that never comes.

**Cause:** The orchestrator cannot proactively message the human. It only acts when the human sends it a message or a background task's output appears in its pane. If the orchestrator promised "I'll report back," that's a false promise — it has no mechanism to initiate contact.

**Fix:** The orchestrator should use notification-bearing background checks. Instead of:
```bash
# BAD — silent check, human never knows to come back
sleep 180 && tmux capture-pane -t swarm:worker-01 -p | tail -15
```

Use:
```bash
# GOOD — fires a desktop notification when something changes
sleep 180 && STATUS=$(tmux capture-pane -t swarm:worker-01 -p | tail -15) && \
  if echo "$STATUS" | grep -q "created pull request\|PR #\|pushed\|Cost:"; then \
    osascript -e 'display notification "Worker finished — PR may be ready" with title "Swarm"'; \
  elif echo "$STATUS" | grep -q "error\|Error\|FAIL\|failed"; then \
    osascript -e 'display notification "Worker hit an error — check status" with title "Swarm"'; \
  fi && echo "$STATUS"
```

The desktop notification is the only way to get the human's attention without them actively checking the terminal. On Linux, replace `osascript` with `notify-send "Swarm" "message"`.

**Prevention:** The orchestrator template includes a Communication Constraint section that forbids "I'll report back" language and requires all background checks to include notifications. If your orchestrator is still making false promises, make sure you're using the latest template version.

## Escalation

### When to stop and ask the human

The orchestrator should escalate (not keep retrying) when:
- A task has failed 3 times with different approaches
- Two tasks have a merge conflict the orchestrator can't resolve
- The default branch is broken after a merge
- An agent needs production access to modify state
- A design decision needs to be made (ambiguous requirements)
- CI is failing for reasons unrelated to the current task

Always include in the escalation comment:
1. What was tried (all attempts)
2. What failed and why
3. Specific options for the human to choose from
