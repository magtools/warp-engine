#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" # Resuelve el root del proyecto
TEMPLATE_PATH="$PROJECT_ROOT/.codex/config.tmpl"
CONFIG_PATH="$PROJECT_ROOT/.codex/config.toml"
GITIGNORE_PATH="$PROJECT_ROOT/.gitignore"
PROJECT_CODEX_DIR="$PROJECT_ROOT/.codex"
PROJECT_RULES_DIR="$PROJECT_CODEX_DIR/rules"
PROJECT_SKILLS_DIR="$PROJECT_CODEX_DIR/skills"
PROJECT_VERSION_FILE="$PROJECT_CODEX_DIR/version.md"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
GLOBAL_RULES_DIR="$CODEX_HOME_DIR/rules"
GLOBAL_SKILLS_DIR="$CODEX_HOME_DIR/skills"
GLOBAL_VERSION_FILE="$CODEX_HOME_DIR/version.md"
RESUME_SESSION_ID=""

# Parse simple arguments
while getopts ":r:" opt; do
  case "$opt" in
    r)
      RESUME_SESSION_ID="$OPTARG"
      ;;
    :)
      echo "Missing value for -$OPTARG" >&2
      exit 1
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Muestra instrucciones para instalar npm en distros comunes
print_npm_install_help() {
  cat <<'EOM'
npm no esta instalado. Comandos sugeridos:
- Debian/Ubuntu/Mint: sudo apt update && sudo apt install -y npm
- Fedora: sudo dnf install -y npm
- SUSE: sudo zypper install -y npm
EOM
}

# Asegura el PATH para binarios globales de npm y recarga bashrc
ensure_path_in_bashrc() {
  local line='export PATH=~/.npm-global/bin:$PATH'
  if [ -f "$HOME/.bashrc" ]; then
    grep -Fxq "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
  else
    echo "$line" >> "$HOME/.bashrc"
  fi
  # shellcheck disable=SC1090
  source "$HOME/.bashrc" || true
}

# Crea el template si falta; si hay config actual, lo usa como base
create_template_if_missing() {
  if [ ! -f "$TEMPLATE_PATH" ]; then
    if [ -f "$CONFIG_PATH" ]; then
      cp "$CONFIG_PATH" "$TEMPLATE_PATH"
      return
    fi
    echo "No se encontro $TEMPLATE_PATH y tampoco $CONFIG_PATH para generarlo." >&2
    exit 1
  fi
}

# Genera el config desde el template si no existe
create_config_if_missing() {
  if [ ! -f "$CONFIG_PATH" ]; then
    create_template_if_missing
    [ -f "$TEMPLATE_PATH" ] || exit 1
    CURRENT_DATE="$(date +%Y-%m-%d)"
    sed "s#__PROJECT_ROOT__#$PROJECT_ROOT#g; s#__CURRENT_DATE__#$CURRENT_DATE#g" "$TEMPLATE_PATH" > "$CONFIG_PATH"
  fi
}

# Actualiza current_date en el config existente
update_current_date() {
  if [ -f "$CONFIG_PATH" ]; then
    CURRENT_DATE="$(date +%Y-%m-%d)"
    if grep -q '^current_date = "' "$CONFIG_PATH"; then
      sed -i "s#^current_date = \".*\"#current_date = \"${CURRENT_DATE}\"#" "$CONFIG_PATH"
    fi
  fi
}

# Agrega .codex/config.toml a .gitignore si falta
ensure_gitignore_codex_config() {
  local line='/.codex/config.toml'
  if [ -f "$GITIGNORE_PATH" ]; then
    if ! grep -Fxq "$line" "$GITIGNORE_PATH"; then
      printf "\n%s\n\n" "$line" >> "$GITIGNORE_PATH"
    fi
  fi
}

# Marca el proyecto git actual como trusted en ~/.codex/config.toml
ensure_project_trusted() {
  local root cfg tmp
  root="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$root" ]; then
    echo "No git root found. Run this inside a git repo." >&2
    exit 1
  fi

  cfg="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex"
  touch "$cfg"

  tmp="$(mktemp)"
  awk -v root="$root" '
BEGIN { inblock=0; found=0; updated=0 }
$0 ~ ("^\\[projects\\.\"" root "\"\\]$") {
  print
  inblock=1; found=1; next
}
inblock && $0 ~ "^\\[" {
  if (!updated) { print "trust_level = \"trusted\""; updated=1 }
  inblock=0
}
inblock && $0 ~ "^[[:space:]]*trust_level[[:space:]]*=" {
  print "trust_level = \"trusted\""
  updated=1
  next
}
{ print }
END {
  if (found && !updated) { print "trust_level = \"trusted\"" }
  if (!found) {
    print ""
    print "[projects.\"" root "\"]"
    print "trust_level = \"trusted\""
  }
}
' "$cfg" > "$tmp"

  mv "$tmp" "$cfg"
  echo "Trusted: $root"
}

# Obtiene la version desde un archivo (primer linea no vacia, trim)
read_version_value() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi

  awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print; exit }' "$file"
}

# Detecta estado de version para decidir sincronizacion
detect_version_state() {
  local source_file="$1"
  local target_file="$2"
  local source_version
  local target_version

  source_version="$(read_version_value "$source_file")"
  if [ -z "$source_version" ]; then
    echo "source_missing"
    return
  fi

  target_version="$(read_version_value "$target_file")"
  if [ -z "$target_version" ]; then
    echo "target_missing"
    return
  fi

  if [ "$source_version" = "$target_version" ]; then
    echo "up_to_date"
    return
  fi

  echo "different"
}

# Mergea reglas evitando duplicados exactos de linea
merge_rules_file() {
  local source_file="$1"
  local target_file="$2"

  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  awk 'NR==FNR { seen[$0]=1; next } !($0 in seen)' "$target_file" "$source_file" >> "$target_file"
}

# Copia reglas del proyecto a CODEX_HOME y mergea default.rules si ya existe
sync_project_rules_to_codex_home() {
  local source_file
  local relative_path
  local target_file

  if [ ! -d "$PROJECT_RULES_DIR" ]; then
    return
  fi

  mkdir -p "$GLOBAL_RULES_DIR"

  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$PROJECT_RULES_DIR"/}"
    target_file="$GLOBAL_RULES_DIR/$relative_path"

    if [ "$relative_path" = "default.rules" ] && [ -f "$target_file" ]; then
      merge_rules_file "$source_file" "$target_file"
      continue
    fi

    mkdir -p "$(dirname "$target_file")"
    cp "$source_file" "$target_file"
  done < <(find "$PROJECT_RULES_DIR" -type f -print0)
}

# Copia skills del proyecto a CODEX_HOME sobreescribiendo solo coincidencias
sync_project_skills_to_codex_home() {
  #if [ ! -d "$PROJECT_SKILLS_DIR" ]; then
  #  return
  #fi

  #mkdir -p "$GLOBAL_SKILLS_DIR"
  #cp -R "$PROJECT_SKILLS_DIR"/. "$GLOBAL_SKILLS_DIR"/
  return
}

# Flags de estado
npm_installed=false
codex_installed=false

# Verifica npm en el sistema
if command -v npm >/dev/null 2>&1; then
  npm_installed=true
fi

# Verifica codex si npm existe
if $npm_installed; then
  if command -v codex >/dev/null 2>&1; then
    codex_installed=true
  fi
else
  print_npm_install_help
  exit 1
fi

# Instala codex con npm global local si hace falta
if ! $codex_installed; then
  mkdir -p "$HOME/.npm-global"
  npm config set prefix '~/.npm-global'
  npm install -g @openai/codex
fi

# Actualiza PATH para encontrar codex
ensure_path_in_bashrc

# Asegura que exista el config del proyecto
if [ ! -f "$CONFIG_PATH" ]; then
  create_config_if_missing
fi

# Refresca la fecha en el config
update_current_date

# Asegura que el config local no se suba al repo
ensure_gitignore_codex_config

# Marca este repo como trusted en config global de Codex
ensure_project_trusted

# Sincroniza rules (merge) y skills (overwrite) cuando no hay version o difiere
version_state="$(detect_version_state "$PROJECT_VERSION_FILE" "$GLOBAL_VERSION_FILE")"
if [ "$version_state" = "target_missing" ] || [ "$version_state" = "different" ]; then
  sync_project_rules_to_codex_home
  #sync_project_skills_to_codex_home
fi

# Copia version del proyecto a CODEX_HOME al finalizar
mkdir -p "$CODEX_HOME_DIR"
if [ -f "$PROJECT_VERSION_FILE" ]; then
  cp "$PROJECT_VERSION_FILE" "$GLOBAL_VERSION_FILE"
fi

# Si llega session id, reanuda esa sesion al finalizar el bootstrap
if [ -n "$RESUME_SESSION_ID" ]; then
  codex resume "$RESUME_SESSION_ID"
  exit 0
fi

# Si ya estaba todo, corre codex directo; si no, hace init
if $npm_installed && $codex_installed && [ -f "$CONFIG_PATH" ]; then
  codex
else
  codex config /init
fi
