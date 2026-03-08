# init.md

## Objetivo

Este documento describe qué hace [`/.codex/init.sh`](./init.sh), cuál es su intención y cómo mantenerlo sin romper el flujo de inicialización local.

La intención principal del script es:

1. Preparar el entorno de Codex en una máquina de desarrollo.
2. Mantener un `config.toml` local del proyecto.
3. Marcar el repo como `trusted` en la configuración global de Codex.
4. Sincronizar `rules` y `skills` desde el proyecto hacia `$CODEX_HOME` usando control de versión (`.codex/version.md`).

---

## Flujo general del script

Orden resumido de ejecución:

1. Define rutas base (`PROJECT_ROOT`, `.codex`, `$CODEX_HOME`, `rules`, `skills`, `version.md`).
2. Verifica `npm` y `codex`; instala `@openai/codex` si falta.
3. Asegura PATH para `~/.npm-global/bin`.
4. Crea `/.codex/config.toml` desde `/.codex/config.tmpl` si no existe.
5. Actualiza `current_date` en `config.toml`.
6. Asegura `/.codex/config.toml` en `.gitignore`.
7. Registra el proyecto como `trusted` en `~/.codex/config.toml`.
8. Evalúa estado de versión entre:
   - fuente: `/.codex/version.md` (proyecto)
   - destino: `$CODEX_HOME/version.md` (usuario)
9. Si la versión de destino falta o difiere:
   - sincroniza `rules`
   - sincroniza `skills`
10. Copia siempre `/.codex/version.md` hacia `$CODEX_HOME/version.md`.
11. Ejecuta `codex` (o `codex config /init` en fallback).

---

## Matriz de instalación (npm/codex)

Comportamiento exacto del bootstrap:

1. Si `npm` **no existe**:
   - imprime ayuda de instalación de `npm`
   - finaliza con `exit 1`
2. Si `npm` existe y `codex` **ya existe**:
   - no reinstala
   - continúa con el flujo normal
3. Si `npm` existe y `codex` **no existe**:
   - crea `~/.npm-global`
   - configura `npm prefix` a `~/.npm-global`
   - ejecuta `npm install -g @openai/codex`
   - continúa con el flujo normal

Nota: luego de instalar o detectar `codex`, el script asegura PATH en `~/.bashrc` para `~/.npm-global/bin`.

---

## Inicio de Codex (final del script)

Comportamiento final:

1. Si `npm_installed=true`, `codex_installed=true` y existe `/.codex/config.toml`:
   - ejecuta `codex`
2. En caso contrario:
   - ejecuta `codex config /init`

Esto cubre escenarios de primer arranque o configuración incompleta.

Modo reanudar sesión:

1. Si `init.sh` recibe `-r <session_id>`, luego del bootstrap ejecuta:
   - `codex resume <session_id>`
2. En este modo no ejecuta `codex` ni `codex config /init`.

---

## Funciones clave

### `read_version_value(file)`

- Lee la primera línea no vacía del archivo de versión.
- Hace trim de espacios.
- Si el archivo no existe, devuelve vacío.

### `detect_version_state(source, target)`

Retorna uno de estos estados:

1. `source_missing`: falta versión en el proyecto.
2. `target_missing`: falta versión en `$CODEX_HOME`.
3. `up_to_date`: mismo valor en ambos archivos.
4. `different`: existen ambos pero difieren.

### `merge_rules_file(source, target)`

- Hace merge por línea, evitando duplicados exactos.
- Se usa para no perder reglas previas del usuario en `default.rules`.

### `sync_project_rules_to_codex_home()`

Reglas actuales:

1. Copia archivos de `/.codex/rules` a `$CODEX_HOME/rules`.
2. Caso especial `default.rules`:
   - si ya existe en `$CODEX_HOME`, hace **merge** (no overwrite).
3. Otros archivos de rules sí se copian/actualizan desde el proyecto.

### `sync_project_skills_to_codex_home()`

Reglas actuales:

1. Copia contenido de `/.codex/skills` a `$CODEX_HOME/skills`.
2. Si un skill existe en ambos lados, el del proyecto sobreescribe el del usuario.
3. Skills existentes solo en `$CODEX_HOME/skills` se conservan (no se eliminan).

---

## Política de sincronización por versión

La sincronización de `rules` y `skills` se dispara cuando:

1. `$CODEX_HOME/version.md` no existe (`target_missing`), o
2. el valor difiere respecto al proyecto (`different`).

Si está `up_to_date`, no sincroniza `rules/skills`.

Al final, siempre actualiza `$CODEX_HOME/version.md` con la versión del proyecto.

---

## Supuestos y límites

1. El script asume ejecución dentro de un repo git.
2. Requiere `npm` disponible para instalar/usar `codex`.
3. El merge de `default.rules` es por línea exacta (no merge semántico).
4. Si `/.codex/version.md` falta, no hay sync por versión (`source_missing`), pero el script continúa.

---

## Cuándo editar este script

Modificar `init.sh` cuando cambie alguno de estos puntos:

1. Ubicación de `rules`, `skills` o `version.md`.
2. Política de merge/sobrescritura.
3. Estrategia de instalación de Codex/NPM.
4. Reglas de confianza (`trust_level`) por proyecto.

---

## Validación mínima recomendada tras cambios

Desde root del proyecto:

```bash
bash -n .codex/init.sh
```

Opcional para prueba funcional:

```bash
.codex/init.sh
```

---

## Resume por proyecto

El script [`/.codex/resume.sh`](./resume.sh) lista sesiones recientes filtradas por proyecto actual.

Criterio de filtro:

1. Recorre `$CODEX_HOME/sessions` (estructura `yyyy/mm/dd`).
2. Ordena por fecha de modificación descendente.
3. Compara `payload.cwd` contra `PROJECT_ROOT`.
4. Muestra solo coincidencias (máximo 9).

Formato de salida actual:

1. `No.` (opción)
2. `Size` (human readable: `B`, `KB`, `MB`)
3. `Created At` (`YYYY-MM-DD HH:MM:SS`)
4. `Last Access` (`YYYY-MM-DD HH:MM:SS`)
5. Línea en blanco
6. `0. Exit`

Selección:

1. `1..9`: resuelve `session_id` y ejecuta `/.codex/init.sh -r <session_id>`
2. `0`: sale sin acciones

Resolución de `session_id` (fallbacks):

1. `payload.id` de la primera línea (`head -n 1`)
2. `payload.id` buscando `session_meta` con `rg -a`
3. UUID extraído del nombre de archivo

Modo debug:

1. `RESUME_PRINT_ONLY=1 ./.codex/resume.sh`
2. Imprime `Session file` + `Session id` sin ejecutar `init.sh`
