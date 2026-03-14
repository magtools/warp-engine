# Propuesta de Implementacion: `warp hyva`

## Objetivo
Agregar al framework `warp` un comando `hyva` con UX alineada a comandos existentes (`grunt`, `rsync`), para simplificar setup y compilacion de themes Hyva.

## Decisiones cerradas
1. Acople al framework actual de Warp:
- Registrar comando en `warp.sh` (case `hyva`).
- Incluir comando en `.warp/includes.sh`.
- Crear `.warp/bin/hyva.sh` y `.warp/bin/hyva_help.sh`.

2. Configuracion de themes en JSON (no JS):
- Archivo: `app/design/hyva-themes.json`.
- `discover` crea/actualiza este archivo.
- `discover` nunca toca `app/design/themes.js`.

3. Selector de theme:
- Solo se admite `:themeKey` en el comando.
- No se soporta `--theme`, `--path` ni `Vendor/theme` como selector runtime.

4. Regla de ejecucion por comando:
- Si hay 1 theme habilitado: `prepare` y `build` ejecutan ese.
- Si hay varios habilitados: `prepare` y `build` ejecutan todos, uno por uno, salvo que se indique `:themeKey`.
- `watch` requiere un solo theme objetivo:
  - `warp hyva watch:<themeKey>` ejecuta directo.
  - si se llama `warp hyva watch` y hay 1 theme habilitado, usa ese automaticamente.
  - si se llama `warp hyva watch` y hay varios, mostrar lista numerada y pedir opcion numerica.

5. `setup` es el comando de instalacion de dependencias (`npm install`) y luego `generate`.

## Archivo de configuracion: `app/design/hyva-themes.json`
Formato propuesto:

```json
{
  "version": 1,
  "default": "Client_HyvaWebsite",
  "themes": {
    "Client_HyvaWebsite": {
      "code": "Client/hyva-website",
      "area": "frontend",
      "path": "app/design/frontend/Client/hyva-website",
      "tailwindPath": "app/design/frontend/Client/hyva-website/web/tailwind",
      "packageJson": "app/design/frontend/Client/hyva-website/web/tailwind/package.json",
      "enabled": true
    }
  },
  "meta": {
    "generatedBy": "warp hyva discover",
    "generatedAt": "2026-03-14T00:00:00Z"
  }
}
```

Reglas:
- `themes` se indexa por `themeKey` normalizado (ej. `Client_HyvaWebsite`).
- `default` debe ser `themeKey`.
- `discover --merge` preserva campos manuales no destructivos.
- `discover` escribe `themes` ordenado alfabeticamente por `themeKey`.
- Normalizacion sugerida de key:
  - entrada: `Client/hyva-website`
  - salida: `Client_HyvaWebsite`

## Contrato CLI
### Comandos principales
1. `warp hyva discover`
- Escanea `app/design/frontend/*/*/web/tailwind/package.json`.
- Crea/actualiza `app/design/hyva-themes.json`.
- Flags:
  - `--dry-run`
  - `--set-default <themeKey>`
  - `--merge`

2. `warp hyva list`
- Muestra `themeKey`, `code`, `enabled`, `tailwindPath`, `default`.

3. `warp hyva prepare[:themeKey]`
- Accion por theme:
  - `npm run generate`

4. `warp hyva setup[:themeKey]`
- Acciones por theme:
  - `npm install`
  - `npm run generate` (excepto si se usa `--no-generate`)

5. `warp hyva build[:themeKey]`
- Accion por theme: `npm run build`.

6. `warp hyva watch[:themeKey]`
- Accion por theme: `npm run watch`.
- Si no viene `:themeKey`:
  - con 1 theme habilitado: ejecutar ese.
  - con multiples: prompt interactivo numerado obligatorio.

## Ejemplos de uso
```bash
warp hyva discover
warp hyva list
warp hyva prepare
warp hyva build
warp hyva prepare:Client_HyvaWebsite
warp hyva build:Client_HyvaWebsite
warp hyva watch:Client_HyvaWebsite
warp hyva setup:Client_HyvaWebsite
warp hyva setup:Client_HyvaWebsite --no-generate
```

## Ejecucion en contenedor PHP
Comando base por theme:
- `docker-compose -f $DOCKERCOMPOSEFILE exec -T -u root php bash -c "npm --prefix <tailwindPath> <accion>"`

Override de desarrollo/local (solo para pruebas):
- `WARP_HYVA_PHP_CONTAINER=<container_id>`
- cuando existe, `hyva` ejecuta parseo JSON y npm con `docker exec -i` sobre ese contenedor.

Gitignore Hyva:
- `warp hyva discover` agrega el bloque `# HYVA / TAILWIND` en `.gitignore` del proyecto actual solo si detecta themes Hyva y si el bloque no existe.

Preflight requerido:
1. Validar que Warp este corriendo (`warp_check_is_running`).
2. Validar existencia de `hyva-themes.json`.
3. Validar `tailwindPath` y `packageJson` por theme.
4. Validar `npm` en contenedor (`command -v npm`).

Errores accionables minimos:
- contenedores apagados
- `hyva-themes.json` inexistente o invalido
- `themeKey` inexistente
- `package.json` faltante
- `npm` ausente
- script npm faltante (`generate`, `build`, `watch`)
- dependencias faltantes (`node_modules`) con sugerencia de flujo:
  - `prepare` sugiere `warp hyva setup[:themeKey]`
  - `build/watch` sugieren `warp hyva setup[:themeKey]` y luego `warp hyva prepare[:themeKey]`

Regla de `build`:
- `build` detecta si `package.json` ya ejecuta `generate` en scripts `prebuild` o `build`.
- si ya lo incluye, no ejecuta `generate` explicito.
- si no lo incluye, ejecuta `generate` antes de `build`.

Observabilidad:
- `setup/prepare/build` muestran spinner + tiempo de ejecucion por etapa.
- se genera log por accion en `var/log/warp-hyva/`.
- `watch` se mantiene interactivo con salida en vivo.

## Parseo JSON en Bash
Decision principal:
- Usar `php -r` en contenedor para leer JSON de forma robusta sin depender de PHP en host.

Alternativas validas si hiciera falta cambiar:
1. `jq` (mas simple, pero agrega dependencia de host).
2. `node -e` (depende de Node en host).
3. Migrar a formato `.env`/TSV para parseo puro Bash (menos expresivo).

## Flujo minimo recomendado
1. Primera vez:
- `warp hyva discover`
- `warp hyva setup[:themeKey]`
- `warp hyva build[:themeKey]`
2. Siguientes veces:
- `warp hyva build[:themeKey]` o `warp hyva watch[:themeKey]`

## Criterios de aceptacion
1. `warp hyva discover` crea/actualiza `app/design/hyva-themes.json`.
2. `warp hyva list` lista themes y default.
3. `warp hyva prepare` y `warp hyva build`:
- con 1 theme habilitado: ejecutan ese.
- con varios habilitados: ejecutan todos secuencialmente.
- con `:themeKey`: ejecutan solo ese.
4. `warp hyva build` autodetecta si `generate` ya esta incluido en `prebuild/build` del `package.json`.
5. `warp hyva watch`:
- con `:themeKey`: ejecuta ese.
- sin `:themeKey` y 1 theme: ejecuta ese.
- sin `:themeKey` y varios: obliga seleccion numerada.
6. `warp hyva setup[:themeKey]` ejecuta `npm install` y luego `npm run generate` (opcionalmente solo install con `--no-generate`).
7. No hay regresiones en `warp grunt`, `warp npm`, `warp magento`.

## Testing sugerido
1. Smoke:
- `warp hyva discover`
- `warp hyva list`
- `warp hyva prepare`
- `warp hyva build`
- `warp hyva watch:Client_HyvaWebsite`

2. Casos de error:
- `themeKey` inexistente
- contenedor apagado
- `package.json` faltante
- `npm` faltante

3. Regresion:
- `warp grunt --help`
- `warp npm --help`
- `warp magento --help`
