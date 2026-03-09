# Warp: guía de swapfile para host remoto

Objetivo: configurar y validar swap de forma persistente en una instancia Linux (EC2), con pasos simples y auditables.

Estado esperado al finalizar:

- `/swapfile` activo
- entrada en `/etc/fstab`
- parámetros `sysctl` aplicados y persistidos

## 1) Configurar overcommit (memoria virtual)

### 1.1 Aplicar en caliente

    # Opción recomendada para este caso:
    sudo sysctl -w vm.overcommit_ratio=75

    # Opcional: modo estricto (solo si sabes el impacto)
    # sudo sysctl -w vm.overcommit_memory=2

Revisamos como aplico:

    grep -E 'Commit' /proc/meminfo
    
### 1.2 Persistir al reiniciar

    # Agrega solo si no existe ya la clave
    grep -q '^vm.overcommit_ratio=' /etc/sysctl.conf || echo 'vm.overcommit_ratio=75' | sudo tee -a /etc/sysctl.conf
    # grep -q '^vm.overcommit_memory=' /etc/sysctl.conf || echo 'vm.overcommit_memory=2' | sudo tee -a /etc/sysctl.conf

    sudo sysctl -p

## 2) Crear y activar swapfile (si no existe)

Si ya lo tienes, puedes saltar esta sección.

    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

## 3) Persistir swap en fstab

Agrega esta línea en `/etc/fstab`:

    /swapfile none swap sw 0 0

Alternativa por comando:

    grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

## 4) Validar sin reiniciar

    sudo swapoff /swapfile
    sudo swapon -a
    swapon --show

Debe aparecer `/swapfile` con `SIZE 2G`.

## 5) Validación final del kernel

    grep -E 'CommitLimit|Committed_AS|SwapTotal|SwapFree' /proc/meminfo

Cómo leer resultados:

- `CommitLimit`: límite total de memoria comprometible.
- `Committed_AS`: compromiso de memoria actual.
- `SwapTotal`: total de swap configurado.
- `SwapFree`: swap libre actual.

## 6) Checklist rápido

    cat /proc/sys/vm/overcommit_ratio
    cat /proc/sys/vm/overcommit_memory
    swapon --show
    grep '^/swapfile ' /etc/fstab

Esperado:

- `overcommit_ratio`: `75`
- `overcommit_memory`: el valor que hayas definido (`0` o `2`)
- `swapon --show`: `/swapfile` activo
- `fstab`: línea de `/swapfile` presente una sola vez

## 7) Recomendaciones operativas

- Evita duplicar entradas en `/etc/fstab`.
- Usa `swapon -a` para validar antes de reiniciar.
- Si usas monitoreo (Checkmk, CloudWatch Agent, etc.), valida métricas con `/proc/meminfo` cuando haya discrepancias.
- Si el host entra en presión de memoria frecuente, considera subir swap a 4G u 8G según carga real.
