# Redis en Warp: estado actual e implementacion

Fecha: 2026-03-15

## 1) Problema original

Antes de este ajuste, `warp init` pedía `REDIS_*_CONF` y copiaba `redis.conf`, pero los templates `redis_*.yml` tenían comentado el `command`, por lo que Redis arrancaba con configuración default de la imagen y no con el archivo custom.

## 2) Cambios implementados

### 2.1 Redis en Docker usando `redis.conf`

Se activó mount de config y arranque explícito con `redis-server /usr/local/etc/redis/redis.conf` en:

- `.warp/setup/redis/tpl/redis_cache.yml`
- `.warp/setup/redis/tpl/redis_session.yml`
- `.warp/setup/redis/tpl/redis_fpc.yml`

Se mantiene comentado el volumen persistente `/data` para no introducir cambios destructivos por defecto.

### 2.2 Parametrización por `.env` en `command`

Cada servicio Redis ahora toma límites/política desde `.env`:

- `REDIS_CACHE_MAXMEMORY`
- `REDIS_CACHE_MAXMEMORY_POLICY`
- `REDIS_SESSION_MAXMEMORY`
- `REDIS_SESSION_MAXMEMORY_POLICY`
- `REDIS_FPC_MAXMEMORY`
- `REDIS_FPC_MAXMEMORY_POLICY`

### 2.3 Defaults de setup actualizados

Se agregaron defaults al generar `.env` desde:

- `.warp/setup/redis/redis.sh`
- `.warp/setup/init/gandalf.sh`
- `.warp/setup/sandbox/sandbox-m2.sh`
- `.warp/setup/redis/tpl/redis.env`

Defaults:

- cache: `512mb` + `allkeys-lru`
- fpc: `512mb` + `allkeys-lru`
- session: `256mb` + `noeviction`

### 2.4 `redis.conf` base para red interna Docker

En `.warp/setup/redis/config/redis/redis.conf`:

- `bind 0.0.0.0`
- `protected-mode no`

Esto evita bloquear conexión desde `php` hacia `redis-*` por red interna del compose.

## 3) Lineamientos funcionales para Magento

1. `redis-cache` y `redis-fpc`: usar política de cache (`allkeys-lru`).
2. `redis-session`: usar `noeviction` para no perder sesiones por presión de memoria.
3. La expiración de sesiones debe manejarse por TTL de Magento/PHP (`max_lifetime`, `session.gc_maxlifetime`), no por eviction.

## 4) Sobre el “fix para modulo webp” en redis.conf

No existe un fix específico de WebP dentro de Redis. Ese bloque es tuning general de memoria/evicción.

Conclusión:

- puede ayudar indirectamente si hay presión de cache,
- pero no corrige por sí solo problemas funcionales del módulo WebP.

## 5) Migración para proyectos ya inicializados

Los cambios en templates impactan nuevas inicializaciones. Para proyectos productivos existentes:

1. Asegurar que su `docker-compose-warp.yml` tenga:
   - mount de `${REDIS_*_CONF}` en `/usr/local/etc/redis/redis.conf`
   - `command` con `--maxmemory` y `--maxmemory-policy` leyendo `.env`
2. Agregar/ajustar variables `REDIS_*_MAXMEMORY*` en `.env`.
3. Recrear servicios Redis:

```bash
./warp docker up -d --force-recreate redis-cache redis-session redis-fpc
```

## 6) Validación operativa recomendada

```bash
for s in redis-cache redis-session redis-fpc; do
  echo "=== $s ==="
  ./warp docker exec -T "$s" redis-cli INFO memory | egrep 'used_memory_human|used_memory_peak_human|maxmemory_human|maxmemory_policy|mem_fragmentation_ratio'
  ./warp docker exec -T "$s" redis-cli INFO stats | egrep 'evicted_keys|expired_keys'
  echo
done
```

Interpretación:

- `evicted_keys` creciente en cache/fpc: subir `maxmemory`.
- `session` debe mantener `noeviction`; si hay presión real, subir `REDIS_SESSION_MAXMEMORY`.
