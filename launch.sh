#!/usr/bin/env bash
set -euo pipefail

SESSION="sched_scan"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [ -t 1 ]; then
    exec tmux attach -t "$SESSION"
  fi
  exit 0
fi

PROJECT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

order=(editor cli runtime)
declare -A cmds=(
  [editor]="nvim ."
  [cli]=""
  [runtime]="flutter run -d linux"
)

tmux new-session -d \
  -s "$SESSION" \
  -n "${order[0]}" \
  -c "$PROJECT_DIR"

for i in "${!order[@]}"; do
  name="${order[$i]}"
  cmd="${cmds[$name]}"

  if (( i != 0 )); then
    tmux new-window \
      -t "$SESSION" \
      -n "$name" \
      -c "$PROJECT_DIR"
  fi

  if [[ -n "$cmd" ]]; then
    tmux send-keys -t "$SESSION:$name" "$cmd" C-m
  fi
done

tmux select-window -t "$SESSION:${order[1]}"

if [ -t 1 ]; then
  exec tmux attach -t "$SESSION"
fi
