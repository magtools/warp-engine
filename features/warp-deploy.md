# Propuesta de Implementacion: `warp deploy`

## Objetivo
Crear un comando `warp deploy` nativo del framework que centralice el flujo de despliegue para entornos `local` y `prod`, sin depender de `local.sh` ni `deploywarp.sh`, pero tomando esas recetas como base.

## Contexto
- `local.sh` hoy ejecuta:
  - `warp composer install`
  - `warp magento se:up`
  - `warp magento se:di:co`
  - `warp grunt exec` + `warp grunt less` (si no se omite)
- `deploywarp.sh.sample` (prod) hoy ejecuta:
  - start de entorno si no está levantado
  - maintenance on
  - `composer install --no-dev`
  - `setup:upgrade`
  - `setup:di:compile`
  - `setup:static-content:deploy` admin/frontend
  - flush search / reindex / maintenance off

## Requerimiento principal
1. `warp deploy:set`
- Prompt interactivo para generar `.deploy`.
- El archivo `.deploy` debe ignorarse en `.gitignore`.
- Debe adaptar prompts, defaults y validaciones segun `ENV=local|prod`.

2. `warp deploy`
- Si `.deploy` no existe: ejecutar `warp deploy:set`.
- Si `.deploy` existe: ejecutar deploy usando su configuración.

## Deteccion de entorno (`ENV`)
Regla de precedencia:
1. Si existe `app/etc/env.php`, leer `MAGE_MODE`:
- `developer` -> `ENV=local`
- `production` -> `ENV=prod`
2. Si no existe `app/etc/env.php`, preguntar:
- `Es entorno de desarrollo? (y/n)`
  - `y` -> `ENV=local`
  - `n` -> `ENV=prod`
3. Guardar resultado en `.deploy`.

## Regla clave de `deploy:set` (obligatoria)
`deploy:set` no debe usar un formulario unico para todos los entornos.
Debe operar en dos perfiles:
1. Perfil `local`
- preguntar solo variables relevantes para desarrollo local.
- proponer defaults orientados a iteracion rapida.
2. Perfil `prod`
- preguntar solo variables relevantes para produccion.
- proponer defaults orientados a seguridad/estabilidad.

## Politica de prompts (UX)
Regla general:
1. Variables con default seguro/predecible:
- no pedir prompt.
- mostrar en salida: `KEY=VALUE (auto)`.
- escribir directamente en `.deploy`.
2. Variables que requieren decision del operador:
- pedir prompt.
- validar entrada.
- persistir valor elegido.

Ejemplo de salida esperada:
- `AUTO_START=1 (auto)`
- `USE_MAINTENANCE=1 (auto)`
- `THREADS=8 (auto: cpu cores detectados)`
- `ADMIN_I18N=?` (prompt)

## Matriz de prompts sugerida para `deploy:set`
### Comunes (ambos entornos)
1. `AUTO_START` (auto: `1`)
2. `RUN_SETUP_UPGRADE` (auto: `1`)
3. `RUN_DI_COMPILE` (auto: `1`)
4. `RUN_CACHE_FLUSH` (auto: `1`)

### Solo `local`
1. `RUN_GRUNT` (default: `1` si existe `app/design/themes.js`, sino `0`)
2. `RUN_HYVA` (default: `1` si existe `app/design/hyva-themes.js`, sino `0`)
3. `HYVA_PREPARE` (auto: `1`)
4. `HYVA_BUILD` (auto: `1`)
5. `RUN_REINDEX` (auto: `0`)
6. `USE_MAINTENANCE` (auto: `0`)

### Solo `prod`
1. `CONFIRM_PROD` (auto: `1`)
2. `USE_MAINTENANCE` (auto: `1`)
3. `COMPOSER_FLAGS` (auto: `--no-dev`)
4. `RUN_REINDEX` (auto: `1`)
5. `RUN_STATIC_ADMIN` (auto: `1`)
6. `RUN_STATIC_FRONT` (auto: `1`)
7. `ADMIN_I18N` (prompt, default sugerido: `en_US es_AR`)
8. `FRONT_I18N` (prompt, default sugerido: `es_AR en_US`)
9. `THREADS` (auto: detectar cores CPU disponibles)
10. `RUN_SEARCH_FLUSH` (auto: `1`)
11. `RUN_HYVA` (auto: `1` si existe `app/design/hyva-themes.js`, sino `0`)
12. `HYVA_BUILD` (auto: `1` cuando `RUN_HYVA=1`)

### Deteccion automatica de `THREADS`
Orden sugerido:
1. `nproc` (Linux)
2. `getconf _NPROCESSORS_ONLN`
3. fallback fijo `4`

Regla recomendada:
- `THREADS = max(1, cores_detectados - 1)` para dejar margen al sistema.
- permitir override manual posterior en `.deploy`.

## Integracion de assets en `ENV=local`
Regla requerida:
- Si existe `app/design/themes.js`: ejecutar flujo legacy (grunt).
- Si existe `app/design/hyva-themes.js`: ejecutar flujo Hyva.
- No son excluyentes: si existen ambos, correr ambos.

## Contrato CLI propuesto
### Comandos
1. `warp deploy:set`
2. `warp deploy`
3. `warp deploy run` (equivalente explicito de `warp deploy`)
4. `warp deploy show` (muestra config activa)
5. `warp deploy doctor` (valida prerequisitos)

### Flags recomendados
- `--dry-run` (muestra pasos sin ejecutar)
- `--force-env local|prod` (override solo para corrida actual)
- `--no-maintenance` (solo local o casos de debugging)
- `--skip-grunt`
- `--skip-hyva`
- `--skip-di`
- `--skip-static`
- `--yes` (sin confirmaciones)

## Parametros iniciales sugeridos para `.deploy`
Formato shell (`KEY=VALUE`), compatible con `source .deploy`.

Parametros core:
1. `DEPLOY_SCHEMA_VERSION=1`
2. `ENV=local|prod`
3. `AUTO_START=1` (levantar contenedores si están caídos)
4. `USE_MAINTENANCE=1`
5. `COMPOSER_FLAGS=--no-dev` (en prod)
6. `RUN_SETUP_UPGRADE=1`
7. `RUN_DI_COMPILE=1`
8. `RUN_REINDEX=1`
9. `RUN_CACHE_FLUSH=1`

Parametros de static content:
1. `ADMIN_I18N="en_US es_AR"`
2. `FRONT_I18N="es_AR en_US"`
3. `THREADS=4`
4. `RUN_STATIC_ADMIN=1`
5. `RUN_STATIC_FRONT=1`
6. `STATIC_EXTRA_FLAGS="-f"`

Parametros frontend local:
1. `RUN_GRUNT=1`
2. `RUN_HYVA=1`
3. `HYVA_PREPARE=1`
4. `HYVA_BUILD=1`

Parametros frontend prod:
1. `RUN_HYVA=1`
2. `HYVA_BUILD=1`

Parametros de busqueda/index:
1. `RUN_SEARCH_FLUSH=1`
2. `SEARCH_FLUSH_CMD="warp elasticsearch flush"`

Parametros seguridad/confirmacion:
1. `CONFIRM_PROD=1`
2. `ALLOW_DIR_PERMS_FIX=0`

Nota:
- El set final de variables debe ser generado por `deploy:set` segun perfil `local` o `prod`.
- No es necesario incluir variables de `prod` en `.deploy` local ni viceversa, salvo que el operador lo pida.

## Ejemplo de `.deploy`
```bash
DEPLOY_SCHEMA_VERSION=1
ENV=local
AUTO_START=1
USE_MAINTENANCE=0
COMPOSER_FLAGS=
RUN_SETUP_UPGRADE=1
RUN_DI_COMPILE=1
RUN_REINDEX=0
RUN_CACHE_FLUSH=1
ADMIN_I18N="en_US es_AR"
FRONT_I18N="es_AR en_US"
THREADS=4
RUN_STATIC_ADMIN=0
RUN_STATIC_FRONT=0
STATIC_EXTRA_FLAGS="-f"
RUN_GRUNT=1
RUN_HYVA=1
HYVA_PREPARE=1
HYVA_BUILD=1
RUN_SEARCH_FLUSH=0
SEARCH_FLUSH_CMD="warp elasticsearch flush"
CONFIRM_PROD=1
ALLOW_DIR_PERMS_FIX=0
```

## Flujo por entorno
### `ENV=local` (basado en `local.sh`)
1. Verificar/levantar contenedores.
2. `warp composer install` (sin `--no-dev`).
3. `warp magento setup:upgrade`.
4. `warp magento setup:di:compile` (según config).
5. Frontend:
- si `themes.js` y `RUN_GRUNT=1`: `warp grunt exec` + `warp grunt less`.
- si `hyva-themes.js` y `RUN_HYVA=1`:
  - `warp hyva prepare` (si `HYVA_PREPARE=1`)
  - `warp hyva build` (si `HYVA_BUILD=1`)
6. Limpieza/flush final según flags.

### `ENV=prod` (basado en `deploywarp.sh.sample`)
1. Verificar/levantar contenedores.
2. Confirmación de seguridad (si `CONFIRM_PROD=1`).
3. Maintenance on (si `USE_MAINTENANCE=1`).
4. `warp composer install --no-dev` (o `COMPOSER_FLAGS`).
5. `warp magento setup:upgrade`.
6. `warp magento setup:di:compile`.
7. Frontend Hyva (si `app/design/hyva-themes.js` existe y `RUN_HYVA=1` y `HYVA_BUILD=1`):
- ejecutar `warp hyva build` antes del static deploy.
8. `setup:static-content:deploy` admin/frontend con `ADMIN_I18N`, `FRONT_I18N`, `THREADS`.
9. Search flush / reindex / cache flush según flags.
10. Maintenance off.

## Criterios de aceptacion
1. `warp deploy` ejecuta `deploy:set` automáticamente cuando falta `.deploy`.
2. `warp deploy:set` crea `.deploy` válido y agrega/asegura ignore en `.gitignore`.
3. Detección de `ENV` funciona con `app/etc/env.php` y fallback por prompt.
4. En local, ejecuta grunt y/o hyva según existencia de archivos de config.
5. En prod, respeta secuencia segura y banderas de mantenimiento.
6. En prod, si Hyva existe y `HYVA_BUILD=1`, ejecuta `warp hyva build` antes de `setup:static-content:deploy`.
7. `--dry-run` muestra plan exacto sin ejecutar comandos.
8. No hay regresión en comandos existentes de `warp`.

## Enfoque de implementacion (framework)
Archivos sugeridos:
- `warp` (agregar case `deploy`)
- `.warp/includes.sh` (source `deploy.sh`)
- `.warp/bin/deploy.sh`
- `.warp/bin/deploy_help.sh`

Helpers sugeridos en `deploy.sh`:
1. `deploy_detect_env`
2. `deploy_set_interactive`
3. `deploy_load_config`
4. `deploy_run_local`
5. `deploy_run_prod`
6. `deploy_run_frontend_legacy`
7. `deploy_run_frontend_hyva`
8. `deploy_ensure_gitignore`
9. `deploy_doctor`

Chequeos minimos para `deploy_doctor`:
1. contenedor `php` activo (o aviso si `AUTO_START=1`).
2. disponibilidad de `warp composer` y `warp magento`.
3. acceso de escritura a `var`, `generated`, `pub/static`.
4. si `RUN_GRUNT=1`: existencia de `app/design/themes.js`.
5. si `RUN_HYVA=1`: existencia de `app/design/hyva-themes.js` y `npm` disponible en contenedor `php`.
6. si `RUN_STATIC_ADMIN=1` o `RUN_STATIC_FRONT=1`: validar `ADMIN_I18N`, `FRONT_I18N`, `THREADS`.

## Notas operativas
- Mantener `.deploy` como archivo local de ambiente, no versionado.
- Soportar valores por defecto robustos para minimizar prompts.
- Evitar acciones destructivas no solicitadas (sin stash/pull/reset automáticos por defecto).
