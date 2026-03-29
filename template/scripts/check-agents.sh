#!/usr/bin/env bash
# scripts/check-agents.sh
#
# Tmux-native swarm monitor. Watches worker/researcher/reviewer panes
# for completion, errors, stuck states. Types findings into the
# orchestrator's pane via tmux send-keys (synthetic user message).
#
# Usage: bash scripts/check-agents.sh
# Runs in: swarm:monitor tmux window
# Launched by: orchestrator during swarm setup

set -euo pipefail

ORCHESTRATOR_PANE="swarm:orchestrator"
POLL_INTERVAL="${MONITOR_INTERVAL:-30}"
SEEN_FILE="/tmp/swarm-monitor-seen.txt"
LOG_FILE="/tmp/swarm-monitor.log"
HASH_DIR="/tmp/swarm-monitor-hashes"
STUCK_THRESHOLD=300  # 5 minutes of no output change

mkdir -p "$HASH_DIR"
touch "$SEEN_FILE"

log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify() {
    local msg="$1"
    log "NOTIFY: $msg"
    tmux send-keys -t "$ORCHESTRATOR_PANE" "$msg" Enter
    sleep 2  # let orchestrator start processing before next event
}

# Send a desktop notification (cross-platform)
desktop_notify() {
    local title="$1"
    local body="$2"
    if command -v osascript &>/dev/null; then
        # macOS
        osascript -e "display notification \"$body\" with title \"$title\""
    elif command -v notify-send &>/dev/null; then
        # Linux (requires libnotify)
        notify-send "$title" "$body"
    fi
}

# Discover all agent windows in the swarm session
list_agent_windows() {
    tmux list-windows -t swarm -F '#W' 2>/dev/null \
        | grep -E '^(worker|researcher|ux-reviewer|reviewer)-' \
        || true
}

content_hash() {
    echo "$1" | md5 2>/dev/null || echo "$1" | md5sum 2>/dev/null | cut -d' ' -f1
}

already_seen() {
    grep -qxF "$1" "$SEEN_FILE" 2>/dev/null
}

mark_seen() {
    echo "$1" >> "$SEEN_FILE"
}

check_window() {
    local win="$1"
    local now
    now=$(date +%s)
    local pane="swarm:$win"

    # Capture last 60 lines of pane output
    local text
    text=$(tmux capture-pane -t "$pane" -p -S -60 2>/dev/null) || return

    [[ -z "$text" ]] && return

    local last_line
    last_line=$(echo "$text" | grep -v '^\s*$' | tail -1)

    # -- Stuck detection (output unchanged for STUCK_THRESHOLD) ----------
    local hash
    hash=$(content_hash "$text")
    local prev_hash=""
    local prev_time="$now"

    if [[ -f "$HASH_DIR/$win.hash" ]]; then
        prev_hash=$(cat "$HASH_DIR/$win.hash")
    fi
    if [[ -f "$HASH_DIR/$win.time" ]]; then
        prev_time=$(cat "$HASH_DIR/$win.time")
    fi

    if [[ "$hash" != "$prev_hash" ]]; then
        echo "$hash" > "$HASH_DIR/$win.hash"
        echo "$now" > "$HASH_DIR/$win.time"
    else
        local silence=$(( now - prev_time ))
        if (( silence >= STUCK_THRESHOLD )); then
            local key="stuck:$win"
            if ! already_seen "$key"; then
                mark_seen "$key"
                notify "[MONITOR] $win appears STUCK — no output change for ${silence}s. Last line: $(echo "$last_line" | cut -c1-100)"
            fi
        fi
    fi

    # -- Shell prompt returned (claude process finished) -----------------
    # Claude Code shows ">" prompt; zsh shows "~/path" with git info.
    # Status bar lines contain ANSI escapes so we check full pane text.
    if echo "$text" | grep -qE '(❯|~/[^ ].*\$\s*$|~/[^ ].*✔)'; then
        # Distinguish: Claude Code idle (waiting for input) vs agent finished (back to zsh)
        # "bypass permissions on" = Claude Code is running but idle at prompt
        # zsh prompt (~/path master) = agent process exited
        if echo "$text" | grep -q "bypass permissions on"; then
            local key="idle:$win"
            if ! already_seen "$key"; then
                mark_seen "$key"
                notify "[MONITOR] $win — Claude Code idle at prompt (agent may be waiting for input or finished)."
            fi
        else
            local key="done:$win"
            if ! already_seen "$key"; then
                mark_seen "$key"
                notify "[MONITOR] $win returned to shell prompt — agent finished."
            fi
        fi
        return  # no point checking other patterns if at a prompt
    fi

    # -- PR / MR created -------------------------------------------------
    # Matches GitHub, GitLab, Bitbucket PR/MR URLs
    if echo "$text" | grep -qoE "https://[^[:space:]]+(pull|merge_requests|pull-requests)/[0-9]+"; then
        local pr_url
        pr_url=$(echo "$text" | grep -oE "https://[^[:space:]]+(pull|merge_requests|pull-requests)/[0-9]+" | tail -1)
        local key="pr:$win:$pr_url"
        if ! already_seen "$key"; then
            mark_seen "$key"
            notify "[MONITOR] $win created PR/MR: $pr_url"
        fi
    fi

    # -- Hard errors -----------------------------------------------------
    if echo "$text" | grep -qiE "(fatal:|ENOENT|EACCES|command not found|npm ERR|build failed)"; then
        local err
        err=$(echo "$text" | grep -iE "(fatal:|ENOENT|EACCES|command not found|npm ERR|build failed)" | tail -1 | cut -c1-120)
        local key="error:$win:$err"
        if ! already_seen "$key"; then
            mark_seen "$key"
            notify "[MONITOR] $win hit ERROR: $err"
        fi
    fi

    # -- Blocked on interactive prompt -----------------------------------
    if echo "$last_line" | grep -qiE "(Continue\? \[|password:|press enter|Do you want)"; then
        local key="blocked:$win"
        if ! already_seen "$key"; then
            mark_seen "$key"
            notify "[MONITOR] $win blocked on interactive prompt: $(echo "$last_line" | cut -c1-100)"
        fi
    fi
}

# -- Main ----------------------------------------------------------------

if ! tmux has-session -t swarm 2>/dev/null; then
    echo "ERROR: tmux session 'swarm' not found."
    exit 1
fi

log "Monitor started. Polling every ${POLL_INTERVAL}s. Ctrl-C to stop."

while true; do
    windows=$(list_agent_windows)

    for win in $windows; do
        [[ -z "$win" ]] && continue
        check_window "$win"
    done

    sleep "$POLL_INTERVAL"
done
