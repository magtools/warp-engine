# Consideraciones generales de Infra

## Permisos del user admin

Añadir el usuario que deploya al grupo del webserver, ej:

    usermod -a -G tape ec2-user 
    usermod -a -G nginx ec2-user 
    usermod -a -G www-data ec2-user 
        
    usermod -a -G tape warp 
    usermod -a -G nginx warp 
    usermod -a -G www-data warp 

## Ajustes de manejo de memoria
    
Objetivo: configurar y validar swap de forma persistente en una instancia Linux, con pasos simples y auditables.

Estado esperado al finalizar:

- `/swapfile` activo
- entrada en `/etc/fstab`
- parámetros `sysctl` aplicados y persistidos

### 1) Configurar overcommit (memoria virtual)

#### 1.1 Aplicar en caliente

    # Opción recomendada para este caso (estable en testing):
    sudo sysctl -w vm.overcommit_ratio=70

    # overcommit_memory=2 existe (modo estricto), pero se recomienda 0 en este escenario
    sudo sysctl -w vm.overcommit_memory=0

Revisamos como aplico:

    grep -E 'Commit' /proc/meminfo
    
#### 1.2 Persistir al reiniciar

    # Agrega solo si no existe ya la clave
    grep -q '^vm.overcommit_ratio=' /etc/sysctl.conf || echo 'vm.overcommit_ratio=70' | sudo tee -a /etc/sysctl.conf
    grep -q '^vm.overcommit_memory=' /etc/sysctl.conf || echo 'vm.overcommit_memory=0' | sudo tee -a /etc/sysctl.conf

    sudo sysctl -p

### 2) Crear y activar swapfile (si no existe)

Si ya lo tienes, puedes saltar esta sección.

    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

#### Cambiar el valor en el archivo de configuración

    echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.conf

#### Aplicar el cambio inmediatamente sin reiniciar

    sudo sysctl -p

#### Por que `vm.swappiness=1` y swap de `1G`

- En web services/web apps se prioriza latencia estable, no mantener el host "vivo pero lento".
- `vm.swappiness=1` reduce swapping proactivo: el kernel evita mandar memoria a disco salvo presion real.
- Swap de `1G` funciona como airbag para picos puntuales y reduce riesgo de OOM inmediato.
- Si el uso de swap es sostenido, el problema es capacidad/tuning (RAM, procesos, concurrencia), no falta de swap.
- En pruebas operativas, `overcommit_ratio=70` + `overcommit_memory=0` + `swappiness=1` mostro mejor estabilidad y tiempos de respuesta que configuraciones mas agresivas con swap.

### 3) Persistir swap en fstab

Agrega esta línea en `/etc/fstab`:

    /swapfile none swap sw 0 0

Alternativa por comando:

    grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

### 4) Validar sin reiniciar

    sudo swapoff /swapfile
    sudo swapon -a
    swapon --show

Debe aparecer `/swapfile` con `SIZE 1G`.

### 5) Validación final del kernel

    grep -E 'CommitLimit|Committed_AS|SwapTotal|SwapFree' /proc/meminfo
    sudo sysctl -p

Cómo leer resultados:

- `CommitLimit`: límite total de memoria comprometible.
- `Committed_AS`: compromiso de memoria actual.
- `SwapTotal`: total de swap configurado.
- `SwapFree`: swap libre actual.

### 6) Checklist rápido

    cat /proc/sys/vm/overcommit_ratio
    cat /proc/sys/vm/overcommit_memory
    swapon --show
    grep '^/swapfile ' /etc/fstab

Esperado:

- `overcommit_ratio`: `70`
- `overcommit_memory`: `0` (recomendado). `2` es opcion valida, pero en testing presento inestabilidad y picos de lentitud.
- `swapon --show`: `/swapfile` activo
- `fstab`: línea de `/swapfile` presente una sola vez

### 7) Recomendaciones operativas

- Evita duplicar entradas en `/etc/fstab`.
- Usa `swapon -a` para validar antes de reiniciar.
- Si usas monitoreo (Checkmk, CloudWatch Agent, etc.), valida métricas con `/proc/meminfo` cuando haya discrepancias.
- Si el host entra en presión de memoria frecuente, considera subir swap a 4G u 8G según carga real.
- Si detectas uso sostenido de swap, espera degradación fuerte de latencia (incluida navegación/admin). En ese caso, prioriza ajustar RAM/procesos antes de depender de swap.
    
