#Resumen de warp
  warp es un script bash “launcher” con lógica de instalación integrada. En el flujo principal:

  1. Valida dependencias locales: docker, docker-compose, ed, tr, y que el path no tenga espacios.
  2. Si existe .warp/lib, carga el framework con .warp/variables.sh y .warp/includes.sh para exponer funciones y comandos.
  3. Verifica versión mínima de Docker y un mecanismo de “self-update” basado en .self-update-warp.
  4. Despacha subcomandos (init, start, php, mysql, redis, etc.) hacia los scripts en .warp/bin/*.sh.
  5. Si no está instalado, warp_setup extrae un archivo embebido (tar.xz) desde el propio warp usando el marcador __ARCHIVE__ y lo descomprime en el
     repo.

  Detalle clave: al final de warp hay un payload binario (tar.xz) adjunto a partir de __ARCHIVE__ que sirve para auto‑instalar .warp. Esto explica
  el “basurero binario” que aparece si se imprime el archivo completo.

  Estructura y propósito de .warp

  - .warp/includes.sh carga librerías base y todos los comandos (.warp/bin/*.sh).
  - .warp/variables.sh define rutas, archivos clave, nombres de red, versiones mínimas y matrices de versiones/extensiones PHP, más versiones
    soportadas de Elasticsearch.
  - .warp/lib/*.sh son utilidades: lectura de .env, mensajes, chequeos, red, etc.
  - .warp/bin/*.sh implementa subcomandos del CLI warp (start/stop/init/php/mysql/redis/etc.).
  - .warp/setup/* contiene scripts y plantillas para la instalación inicial y configuración de servicios.

  Comportamiento destacado por archivos

  - warp
      - Multiplexa comandos y ejecuta la instalación si falta .warp/lib.
      - Maneja “self update” y comparación de versiones entre .env.sample y .warp/lib/version.sh.
  - .warp/variables.sh
      - Define rutas (.env, docker-compose-warp.yml, etc.) y parámetros globales.
      - Listas extensas de extensiones PHP y versiones soportadas.
      - Versión mínima de docker-compose y Docker.
  - .warp/includes.sh
      - Sourcing central de libs y comandos.
  - .warp/lib/env.sh, .warp/lib/check.sh, .warp/lib/net.sh
      - Lectura de variables de .env, generación de passwords.
      - Validaciones de archivos, estado de containers, y manipulación de docker-compose para redes mono/multi.
      - Detecta puertos usados y helpers de IP.
  - .warp/bin/start.sh
      - Ejecuta docker-compose up (con soporte Mac/Linux y docker-sync).
      - Ejecuta crontab_run y copia SSH.
      - Chequea versión de ES y fecha de imagen PHP.
  - .warp/bin/init.sh
      - Orquesta “wizard” de instalación; puede correr en modo interactivo o no.
      - Carga scripts de setup de cada servicio.
  - .warp/bin/php.sh
      - Switch de versiones PHP con actualización de .env y archivos en .warp/docker/config/php.
      - Configura Xdebug (IP diferente en macOS) y valores IDE.

  .warp/docker/config (excluyendo .warp/docker/volumes)

  - appdata/startup.sh
      - Loop infinito que ajusta permisos en /var/www/html y binarios (bin/magento / bin/console).
  - bash/.bashrc
      - Alias útiles para Magento, carga nvm.
  - crontab/cronfile
      - Ejecuta bin/magento cron:run cada 5 minutos.
  - etc/init.d/warpd
      - Script init.d para arrancar/parar warp como servicio.
  - mysql/my.cnf + mysql/conf.d/*
      - Incluye tuning básico (buffers, tmp table size, etc).
  - nginx/nginx.conf
      - Config base, logs a stdout/stderr, incluye bot blocker y sites-enabled.
  - nginx/m2-cors.conf
      - CORS con Access-Control-Allow-Origin: * para assets.
  - nginx/sites-enabled/*.conf
      - Vhosts Magento/Oro; ejemplo local.demo66.com.conf con hardening básico, rate‑limit, reglas anti‑inyección, cache para estáticos.
  - nginx/auth/.htpasswd
      - Usuario 66ecomm con hash Apache MD5.
  - nginx/ssl/cert.pem y key.pem
      - Certificados SSL locales.
  - opensearch/opensearch.yml
      - Config single‑node, seguridad demo, TLS HTTP deshabilitado.
  - opensearch/*
      - Certificados y ficheros de OpenSearch Security demo.
  - php/php.ini, php-fpm.conf, ext-xdebug.ini, ext-ioncube.ini, entrypoint.sh
      - Ajustes de límites altos para dev, logging, mailhog, FPM dinámico.
      - Xdebug listo para 9003 y host 172.17.0.1.
      - entrypoint.sh instala gosu y ftp si falta y lanza supervisord como www-data.
  - redis/redis.conf
      - Config base estándar (bind 127.0.0.1, protected-mode yes).
  - supervisor/conf.d/*.conf
      - Definiciones de procesos (principalmente Oro).
  - varnish/default.vcl
      - VCL base sin reglas Magento específicas.

  Observaciones rápidas

  - warp es un binario auto‑extraíble; revisar con cuidado antes de editar.
  - Hay certificados SSL y claves en nginx/ssl/ y demo certs de OpenSearch. OK para dev, no para prod.
  - .warp/docker/config/php/entrypoint.sh hace apt-get en runtime; implica arranque más lento y requiere acceso a repos.

