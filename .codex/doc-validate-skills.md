# validate-skills.md

## Objetivo

Este documento explica el script [`/.codex/validate-skills.sh`](./validate-skills.sh), su intención y cómo mantenerlo.

La intención principal es **evitar regresiones** en los skills del proyecto y asegurar que sigan alineados con `AGENTS.md`.

---

## Qué valida el script

Ruta objetivo: `./.codex/skills`

Validaciones actuales:

1. Estructura mínima por skill:
   - Cada carpeta de skill (excepto `_resources`) debe tener `SKILL.md`.

2. Frontmatter mínimo en cada `SKILL.md`:
   - `name: ...`
   - `description: ...`

3. Bloque obligatorio de overrides:
   - Debe existir el header `## Project Overrides (Mandatory)`.
   - Debe existir una línea de precedencia de `AGENTS.md`.

4. Compatibilidad de estilo/código en ejemplos de `SKILL.md`:
   - No permite `private/protected/public readonly` (evita promoción/readonly incompatible con lineamientos del proyecto).

5. Compatibilidad de comandos:
   - No permite `bin/magento` en `SKILL.md` (excepto en la frase permitida: `do not use \`bin/magento ...\``).

6. Links relativos:
   - Verifica que enlaces `](../...)` resuelvan a archivos existentes.

7. Snippets (`./.codex/skills/_resources/snippets`):
   - No permite `bin/magento`.
   - No permite `readonly` en ejemplos.

---

## Qué NO valida (hoy)

1. Calidad semántica de contenido (si el consejo es técnicamente óptimo).
2. Consistencia de ejemplos Magento más allá de patrones simples por regex.
3. Formato YAML completo del frontmatter.
4. Compatibilidad con plataformas externas (Claude/Cursor/etc.) fuera del estándar local.

---

## Uso

Desde la raíz del proyecto:

```bash
.codex/validate-skills.sh
```

Resultado:
- `exit 0`: todo OK
- `exit 1`: hay errores que corregir

Salida final esperada:

```text
Validation summary: X error(s), Y warning(s)
```

---

## Cuándo ejecutarlo

Ejecutar siempre cuando:

1. Se agrega un nuevo skill.
2. Se modifica cualquier `SKILL.md`.
3. Se actualizan `snippets` o recursos en `_resources`.
4. Se cambian reglas en `AGENTS.md` que impacten skills.

---

## Cómo extender reglas

Archivo a modificar: `./.codex/validate-skills.sh`

Puntos de extensión recomendados:

1. `check_skill_file()`:
   - Validaciones por archivo `SKILL.md`.

2. `check_relative_links()`:
   - Reglas de enlaces internos.

3. Bloque de snippets (`SNIPPETS_DIR`):
   - Reglas específicas de plantillas XML/PHP.

4. Nuevos recursos:
   - Agregar validaciones para `_resources/checklists` o `_resources/reference` si se necesita.

---

## Principios de diseño del validador

1. **Fail fast** en reglas críticas:
   - Si rompe lineamientos clave, debe fallar el script.

2. **Regex simples y explícitos**:
   - Fácil de mantener por cualquier dev del equipo.

3. **Bajo acoplamiento**:
   - No depende de herramientas externas complejas.

4. **Criterios locales primero**:
   - Prioriza reglas del proyecto (`AGENTS.md`) sobre convenciones genéricas.

---

## Mantenimiento recomendado

Cuando cambie `AGENTS.md`, revisar:

1. ¿Hay nuevas reglas obligatorias para código de ejemplo?
2. ¿Cambió la política de comandos (`warp`, contenedor, etc.)?
3. ¿Cambió el alcance de paths permitidos?

Si alguna respuesta es sí:

1. Actualizar reglas en `validate-skills.sh`.
2. Correr `.codex/validate-skills.sh`.
3. Actualizar este `.md` con el cambio de comportamiento.

---

## Troubleshooting rápido

1. Error de link roto:
   - Revisar rutas relativas `../...` dentro de `SKILL.md`.

2. Error por `bin/magento`:
   - Cambiar a `warp magento`.

3. Error por `readonly`:
   - Reescribir ejemplo con propiedades declaradas y asignación en `__construct`.

4. Error de bloque obligatorio:
   - Agregar `## Project Overrides (Mandatory)` y línea de precedencia de `AGENTS.md`.
