#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SESSIONS_DIR="$CODEX_HOME_DIR/sessions"
INIT_SCRIPT="$PROJECT_ROOT/.codex/init.sh"
PRINT_ONLY="${RESUME_PRINT_ONLY:-0}"

human_size() {
  local bytes="$1"
  awk -v b="$bytes" 'BEGIN {
    if (b < 1024) { printf "%dB", b; exit }
    if (b < 1024 * 1024) { printf "%.1fKB", b / 1024; exit }
    printf "%.1fMB", b / (1024 * 1024)
  }'
}

format_epoch() {
  local epoch="$1"
  if [ -z "$epoch" ] || [ "$epoch" -lt 0 ]; then
    echo "N/A"
    return
  fi
  date -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A"
}

file_created_at() {
  local file="$1"
  local created_epoch
  created_epoch="$(stat -c '%W' "$file" 2>/dev/null || echo -1)"
  if [ "$created_epoch" -lt 0 ]; then
    created_epoch="$(stat -c '%Y' "$file" 2>/dev/null || echo -1)"
  fi
  format_epoch "$created_epoch"
}

file_accessed_at() {
  local file="$1"
  local access_epoch
  access_epoch="$(stat -c '%X' "$file" 2>/dev/null || echo -1)"
  format_epoch "$access_epoch"
}

extract_session_id() {
  local file="$1"
  local first_line
  local meta_line
  local parsed_id
  local fallback_id

  first_line="$(head -n 1 "$file" 2>/dev/null || true)"
  parsed_id="$(echo "$first_line" | sed -n 's/.*"payload":{"id":"\([^"]*\)".*/\1/p')"
  if [ -n "$parsed_id" ]; then
    echo "$parsed_id"
    return
  fi

  meta_line="$(rg -a -m 1 '"type":"session_meta"' "$file" 2>/dev/null || true)"
  parsed_id="$(echo "$meta_line" | sed -n 's/.*"payload":{"id":"\([^"]*\)".*/\1/p')"
  if [ -n "$parsed_id" ]; then
    echo "$parsed_id"
    return
  fi

  fallback_id="$(basename "$file" | rg -o '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -n 1)"
  echo "$fallback_id"
}

echo " "

if [ ! -d "$SESSIONS_DIR" ]; then
  echo "No sessions directory found: $SESSIONS_DIR"
  exit 1
fi

if [ ! -x "$INIT_SCRIPT" ]; then
  echo "Init script not executable: $INIT_SCRIPT"
  exit 1
fi

# Build candidate list sorted by newest first, then keep only this project cwd.
mapfile -t CANDIDATE_FILES < <(find "$SESSIONS_DIR" -type f -name '*.jsonl' -printf '%T@|%p\n' | sort -t'|' -k1,1nr | cut -d'|' -f2-)

SESSION_FILES=()
for file in "${CANDIDATE_FILES[@]}"; do
  if head -n 1 "$file" | grep -F "\"cwd\":\"$PROJECT_ROOT\"" >/dev/null 2>&1; then
    SESSION_FILES+=("$file")
  fi
  if [ "${#SESSION_FILES[@]}" -ge 9 ]; then
    break
  fi
done

if [ "${#SESSION_FILES[@]}" -eq 0 ]; then
  echo "No sessions found for project: $PROJECT_ROOT"
  exit 0
fi

echo "Recent sessions:"
echo
printf "    %-3s %9s    %-19s    %-19s\n" " " "Size" "Created At" "Last Access"
for i in "${!SESSION_FILES[@]}"; do
  idx=$((i + 1))
  file="${SESSION_FILES[$i]}"
  size_bytes="$(stat -c '%s' "$file" 2>/dev/null || echo 0)"
  size="$(human_size "$size_bytes")"
  created_at="$(file_created_at "$file")"
  accessed_at="$(file_accessed_at "$file")"
  printf "    %-3s %9s    %-19s    %-19s\n" "${idx}" "$size" "$created_at" "$accessed_at"
done

echo "    0        Exit"
echo
echo

read -r -p "Select option [0-9]: " selection

if [ "$selection" = "0" ]; then
  exit 0
fi

if ! [[ "$selection" =~ ^[1-9]$ ]]; then
  echo "Invalid option: $selection"
  exit 1
fi

selected_index=$((selection - 1))
if [ "$selected_index" -ge "${#SESSION_FILES[@]}" ]; then
  echo "Invalid option: $selection"
  exit 1
fi

selected_file="${SESSION_FILES[$selected_index]}"
session_id="$(extract_session_id "$selected_file")"
if [ -z "$session_id" ]; then
  echo "Could not read session id from: $selected_file"
  exit 1
fi

if [ "$PRINT_ONLY" = "1" ]; then
  echo "Session file: $selected_file"
  echo "Session id: $session_id"
  exit 0
fi

exec "$INIT_SCRIPT" -r "$session_id"
