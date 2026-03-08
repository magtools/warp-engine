#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/.codex/skills"

errors=0
warnings=0

log_error() {
  printf 'ERROR: %s\n' "$1"
  errors=$((errors + 1))
}

log_warn() {
  printf 'WARN: %s\n' "$1"
  warnings=$((warnings + 1))
}

if [[ ! -d "$SKILLS_DIR" ]]; then
  log_error "Skills directory not found: $SKILLS_DIR"
  exit 1
fi

# First-level skill folders except _resources.
mapfile -t skill_dirs < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '_resources' | sort)
if [[ ${#skill_dirs[@]} -eq 0 ]]; then
  log_error "No skill directories found in $SKILLS_DIR"
  exit 1
fi

check_relative_links() {
  local file="$1"
  local file_dir
  file_dir="$(dirname "$file")"

  while IFS= read -r match; do
    local rel
    rel="$(printf '%s' "$match" | sed -E 's/^\]\((\.\.[^)]+)\)$/\1/')"
    local target="$file_dir/$rel"
    if [[ ! -f "$target" ]]; then
      log_error "Broken relative link in ${file#$ROOT_DIR/}: $rel"
    fi
  done < <(rg -o '\]\(\.\.[^)]+\)' "$file" || true)
}

check_skill_file() {
  local skill_dir="$1"
  local skill_file="$skill_dir/SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    log_error "Missing SKILL.md in ${skill_dir#$ROOT_DIR/}"
    return
  fi

  # Required frontmatter keys
  if ! rg -q '^name:\s+' "$skill_file"; then
    log_error "Missing frontmatter name in ${skill_file#$ROOT_DIR/}"
  fi

  if ! rg -q '^description:\s+' "$skill_file"; then
    log_error "Missing frontmatter description in ${skill_file#$ROOT_DIR/}"
  fi

  # Mandatory project override block
  if ! rg -q '^## Project Overrides \(Mandatory\)' "$skill_file"; then
    log_error "Missing override block in ${skill_file#$ROOT_DIR/}"
  fi

  if ! rg -q 'AGENTS\.md.*prevails' "$skill_file"; then
    log_error "Missing AGENTS precedence line in ${skill_file#$ROOT_DIR/}"
  fi

  # Disallow constructor property promotion examples.
  if rg -q 'private readonly|protected readonly|public readonly' "$skill_file"; then
    log_error "Readonly property promotion found in ${skill_file#$ROOT_DIR/}"
  fi

  # Disallow bin/magento except explicit forbidden-example sentence.
  if rg -n 'bin/magento' "$skill_file" | rg -v 'do not use `bin/magento \.\.\.`' >/dev/null; then
    log_error "Unexpected bin/magento usage in ${skill_file#$ROOT_DIR/}"
  fi

  check_relative_links "$skill_file"
}

for d in "${skill_dirs[@]}"; do
  check_skill_file "$d"
done

# Snippets checks
SNIPPETS_DIR="$SKILLS_DIR/_resources/snippets"
if [[ -d "$SNIPPETS_DIR" ]]; then
  while IFS= read -r snippet; do
    if rg -q 'bin/magento' "$snippet"; then
      log_error "bin/magento found in snippet ${snippet#$ROOT_DIR/}"
    fi
    if rg -q 'private readonly|protected readonly|public readonly' "$snippet"; then
      log_error "Readonly property promotion found in snippet ${snippet#$ROOT_DIR/}"
    fi
  done < <(find "$SNIPPETS_DIR" -type f | sort)
else
  log_warn "Snippets folder not found: $SNIPPETS_DIR"
fi

printf '\nValidation summary: %d error(s), %d warning(s)\n' "$errors" "$warnings"
if [[ "$errors" -gt 0 ]]; then
  exit 1
fi
