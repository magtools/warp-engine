# Feature: `warp memory report` (implementado)

Fecha: 2026-03-15

## 1) Objetivo

Agregar un comando de diagnóstico no destructivo que muestre:

1. RAM total del host.
2. Uso actual por servicio clave:
   - `php-fpm` (contenedor `php`)
   - `mysql`
   - `elasticsearch`
   - `redis-cache`, `redis-fpc`, `redis-session`
3. Valores configurados (si existen) en `.env` y/o config efectiva.
4. Valores sugeridos calculados según RAM instalada y reglas mínimas.

Salida esperada: reporte corto, legible y orientado a acción.

## 2) Contrato CLI

Comando principal:

```bash
warp memory report
```

Alias implementado:

```bash
warp memory
```

Opciones:

```bash
warp memory report --json
warp memory report --no-suggest
```

Regla del comando:

- Solo lectura y sugerencias.
- No modifica `.env` ni archivos de configuración.

## 3) Qué mide hoy

## 3.1 Host

- `RAM total` (MB/GB).

Nota:

- En la implementación actual no se muestra `RAM disponible`; solo `RAM total`.

## 3.2 Docker por contenedor

Uso real actual de memoria:

- `php`
- `mysql`
- `elasticsearch`
- `redis-cache`
- `redis-fpc`
- `redis-session`

Fuente actual:

- `docker stats --no-stream` (o equivalente ya usado por Warp).

## 3.3 Configuración efectiva

Mostrar configuraciones detectadas:

1. Elasticsearch:
   - `ES_MEMORY` desde `.env` (si existe).
2. Redis:
   - `REDIS_CACHE_MAXMEMORY`
   - `REDIS_FPC_MAXMEMORY`
   - `REDIS_SESSION_MAXMEMORY`
   - políticas (`*_MAXMEMORY_POLICY`)
3. PHP-FPM:
   - `pm`
   - `pm.max_children`
   - `pm.start_servers`
   - `pm.min_spare_servers`
   - `pm.max_spare_servers`
   - `pm.max_requests`
   (leyendo `php-fpm.conf`/pool config efectiva en contenedor o archivo montado).

## 4) Reglas de sugerencia (implementadas)

## 4.1 Elasticsearch

Sugerir:

- `max(1024MB, 13% de RAM total)`

Salida:

- valor actual (si existe),
- valor sugerido,
- diferencia.

## 4.2 Redis

Sugerir mínimos por instancia:

1. Cache:
   - `max(512MB, 6% RAM total)`
2. FPC:
   - `max(512MB, 6% RAM total)`
3. Session:
   - `max(128MB, 1.5% RAM total)`

Nota:

- Mantener sugerencia de política:
  - cache/fpc: `allkeys-lru`
  - session: `noeviction`

## 4.3 PHP-FPM (perfiles probados)

Perfiles base declarados:

1. 7-8GB RAM:
   - `pm = dynamic`
   - `pm.max_children = 15`
   - `pm.start_servers = 5`
   - `pm.min_spare_servers = 5`
   - `pm.max_spare_servers = 5`
   - `pm.max_requests = 1000`
2. 15-16GB RAM:
   - `pm = dynamic`
   - `pm.max_children = 30`
   - `pm.start_servers = 5`
   - `pm.min_spare_servers = 5`
   - `pm.max_spare_servers = 10`
   - `pm.max_requests = 2000`
3. 30-33GB RAM:
   - `pm = dynamic`
   - `pm.max_children = 70`
   - `pm.start_servers = 10`
   - `pm.min_spare_servers = 10`
   - `pm.max_spare_servers = 20`
   - `pm.max_requests = 3000`

Regla implementada:

- Mapear por rango de RAM al perfil más cercano.
- No se aplica interpolación: se elige uno de los 3 perfiles probados.

## 5) Formato de salida

```text
WARP Memory Report
Host RAM total: 15.4 GB

[USO ACTUAL]
php            1.2 GB
mysql          0.9 GB
elasticsearch  0.8 GB
redis-cache    0.17 GB
redis-fpc      0.03 GB
redis-session  0.003 GB

[CONFIG ACTUAL]
ES_MEMORY=512m
REDIS_CACHE_MAXMEMORY=0 (no seteado)
REDIS_FPC_MAXMEMORY=0 (no seteado)
REDIS_SESSION_MAXMEMORY=0 (no seteado)
PHP-FPM pm.max_children=20 ...

[SUGERIDO]
ES_MEMORY=2048m
REDIS_CACHE_MAXMEMORY=512mb
REDIS_FPC_MAXMEMORY=512mb
REDIS_SESSION_MAXMEMORY=128mb
PHP-FPM profile: 15-16GB
  pm.max_children=30
  pm.start_servers=5
  pm.min_spare_servers=5
  pm.max_spare_servers=10
  pm.max_requests=2000
```

## 6) Estado de implementación

1. Implementado en:
   - `.warp/bin/memory.sh`
   - `.warp/bin/memory_help.sh`
2. Integrado en:
   - `.warp/includes.sh`
   - `warp.sh` (dispatch `memory`)
3. Soporta salida:
   - texto
   - JSON (`--json`)
4. Si un contenedor no existe o no está corriendo:
   - muestra `N/A` o `stopped`.

## 7) Validación mínima

1. `./warp memory --help`
2. `./warp memory report`
3. `./warp memory report --json`
4. Smoke en host con y sin servicios Redis/ES activos.

## 8) Notas operativas

1. Si un servicio no existe en el compose actual, mostrar `N/A` y continuar.
2. Si falta una variable en `.env`, indicarlo como `no seteado`.
3. El comando debe ser seguro para productivo: solo lectura.
