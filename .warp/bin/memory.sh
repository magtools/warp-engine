#!/bin/bash

. "$PROJECTPATH/.warp/bin/memory_help.sh"

memory_trim() {
    echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

memory_host_total_mb() {
    if [ -r /proc/meminfo ]; then
        awk '/^MemTotal:/ {printf "%d\n", $2/1024; exit}' /proc/meminfo
        return 0
    fi

    if command -v sysctl >/dev/null 2>&1; then
        _bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [[ "$_bytes" =~ ^[0-9]+$ ]]; then
            awk -v b="$_bytes" 'BEGIN { printf "%d\n", b/1024/1024 }'
            return 0
        fi
    fi

    echo ""
}

memory_mb_to_human() {
    _mb="$1"
    if ! [[ "$_mb" =~ ^[0-9]+$ ]]; then
        echo "N/A"
        return 0
    fi

    if [ "$_mb" -ge 1024 ]; then
        awk -v mb="$_mb" 'BEGIN { printf "%.2f GB", mb/1024 }'
    else
        echo "${_mb} MB"
    fi
}

memory_percent_mb() {
    _total_mb="$1"
    _numerator="$2"
    _denominator="$3"

    if ! [[ "$_total_mb" =~ ^[0-9]+$ ]]; then
        echo ""
        return 0
    fi

    awk -v total="$_total_mb" -v n="$_numerator" -v d="$_denominator" \
        'BEGIN { v=(total*n)/d; if (v < int(v)) v=int(v)+1; else v=int(v); print v }'
}

memory_max_int() {
    _a="$1"
    _b="$2"
    if [ "$_a" -ge "$_b" ]; then
        echo "$_a"
    else
        echo "$_b"
    fi
}

memory_env_value() {
    _k="$1"
    _v=$(warp_env_read_var "$_k")
    _v=$(memory_trim "$_v")
    if [ -z "$_v" ]; then
        echo "no seteado"
    else
        echo "$_v"
    fi
}

memory_compose_service_id() {
    _service="$1"
    if [ ! -f "$DOCKERCOMPOSEFILE" ]; then
        echo ""
        return 0
    fi

    docker-compose -f "$DOCKERCOMPOSEFILE" ps -q "$_service" 2>/dev/null | head -n 1
}

memory_service_mem_usage() {
    _service="$1"
    _cid=$(memory_compose_service_id "$_service")

    if [ -z "$_cid" ]; then
        echo "N/A"
        return 0
    fi

    _running=$(docker inspect --format '{{.State.Running}}' "$_cid" 2>/dev/null)
    if [ "$_running" != "true" ]; then
        echo "stopped"
        return 0
    fi

    _mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$_cid" 2>/dev/null | head -n 1)
    _mem=$(memory_trim "$_mem")
    if [ -z "$_mem" ]; then
        echo "N/A"
    else
        echo "$_mem"
    fi
}

memory_php_conf_file() {
    if [ -f "$PROJECTPATH/.warp/docker/config/php/php-fpm.conf" ]; then
        echo "$PROJECTPATH/.warp/docker/config/php/php-fpm.conf"
        return 0
    fi

    if [ -f "$PROJECTPATH/.warp/setup/php/config/php/php-fpm.conf" ]; then
        echo "$PROJECTPATH/.warp/setup/php/config/php/php-fpm.conf"
        return 0
    fi

    echo ""
}

memory_php_conf_read() {
    _file="$1"
    _key="$2"

    if [ ! -f "$_file" ]; then
        echo ""
        return 0
    fi

    awk -F '=' -v k="$_key" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        $0 !~ /^[ \t]*[;#]/ {
            lhs=trim($1)
            if (lhs == k) {
                rhs=$0
                sub(/^[^=]*=/, "", rhs)
                print trim(rhs)
                exit
            }
        }
    ' "$_file"
}

memory_php_profile_pick() {
    _total_mb="$1"
    # Pick nearest tested profile center: 7.5G, 15.5G, 31.5G
    _c1=7680
    _c2=15872
    _c3=32256

    _d1=$(( _total_mb > _c1 ? _total_mb - _c1 : _c1 - _total_mb ))
    _d2=$(( _total_mb > _c2 ? _total_mb - _c2 : _c2 - _total_mb ))
    _d3=$(( _total_mb > _c3 ? _total_mb - _c3 : _c3 - _total_mb ))

    if [ "$_d1" -le "$_d2" ] && [ "$_d1" -le "$_d3" ]; then
        echo "7-8GB"
    elif [ "$_d2" -le "$_d1" ] && [ "$_d2" -le "$_d3" ]; then
        echo "15-16GB"
    else
        echo "30-33GB"
    fi
}

memory_php_profile_values() {
    _profile="$1"
    case "$_profile" in
        7-8GB)
            cat <<EOF
pm=dynamic
pm.max_children=15
pm.start_servers=5
pm.min_spare_servers=5
pm.max_spare_servers=5
pm.max_requests=1000
EOF
        ;;
        15-16GB)
            cat <<EOF
pm=dynamic
pm.max_children=30
pm.start_servers=5
pm.min_spare_servers=5
pm.max_spare_servers=10
pm.max_requests=2000
EOF
        ;;
        *)
            cat <<EOF
pm=dynamic
pm.max_children=70
pm.start_servers=10
pm.min_spare_servers=10
pm.max_spare_servers=20
pm.max_requests=3000
EOF
        ;;
    esac
}

memory_json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

memory_report_print_text() {
    _show_suggest="$1"

    _host_mb=$(memory_host_total_mb)
    _host_human=$(memory_mb_to_human "$_host_mb")

    _usage_php=$(memory_service_mem_usage "php")
    _usage_mysql=$(memory_service_mem_usage "mysql")
    _usage_es=$(memory_service_mem_usage "elasticsearch")
    _usage_rc=$(memory_service_mem_usage "redis-cache")
    _usage_rf=$(memory_service_mem_usage "redis-fpc")
    _usage_rs=$(memory_service_mem_usage "redis-session")

    _cfg_es=$(memory_env_value "ES_MEMORY")
    _cfg_rc=$(memory_env_value "REDIS_CACHE_MAXMEMORY")
    _cfg_rcp=$(memory_env_value "REDIS_CACHE_MAXMEMORY_POLICY")
    _cfg_rf=$(memory_env_value "REDIS_FPC_MAXMEMORY")
    _cfg_rfp=$(memory_env_value "REDIS_FPC_MAXMEMORY_POLICY")
    _cfg_rs=$(memory_env_value "REDIS_SESSION_MAXMEMORY")
    _cfg_rsp=$(memory_env_value "REDIS_SESSION_MAXMEMORY_POLICY")

    _php_conf=$(memory_php_conf_file)
    _php_pm=$(memory_php_conf_read "$_php_conf" "pm")
    _php_mc=$(memory_php_conf_read "$_php_conf" "pm.max_children")
    _php_ss=$(memory_php_conf_read "$_php_conf" "pm.start_servers")
    _php_min=$(memory_php_conf_read "$_php_conf" "pm.min_spare_servers")
    _php_max=$(memory_php_conf_read "$_php_conf" "pm.max_spare_servers")
    _php_req=$(memory_php_conf_read "$_php_conf" "pm.max_requests")

    [ -z "$_php_pm" ] && _php_pm="N/A"
    [ -z "$_php_mc" ] && _php_mc="N/A"
    [ -z "$_php_ss" ] && _php_ss="N/A"
    [ -z "$_php_min" ] && _php_min="N/A"
    [ -z "$_php_max" ] && _php_max="N/A"
    [ -z "$_php_req" ] && _php_req="N/A"

    warp_message ""
    warp_message_info "WARP Memory Report"
    warp_message "Host RAM total:             $(warp_message_info "$_host_human")"
    warp_message ""

    warp_message_info "[USO ACTUAL]"
    warp_message "php:                        $(warp_message_info "$_usage_php")"
    warp_message "mysql:                      $(warp_message_info "$_usage_mysql")"
    warp_message "elasticsearch:              $(warp_message_info "$_usage_es")"
    warp_message "redis-cache:                $(warp_message_info "$_usage_rc")"
    warp_message "redis-fpc:                  $(warp_message_info "$_usage_rf")"
    warp_message "redis-session:              $(warp_message_info "$_usage_rs")"
    warp_message ""

    warp_message_info "[CONFIG ACTUAL]"
    warp_message "ES_MEMORY:                  $(warp_message_info "$_cfg_es")"
    warp_message "REDIS_CACHE_MAXMEMORY:      $(warp_message_info "$_cfg_rc")"
    warp_message "REDIS_CACHE_MAXMEMORY_POLICY: $(warp_message_info "$_cfg_rcp")"
    warp_message "REDIS_FPC_MAXMEMORY:        $(warp_message_info "$_cfg_rf")"
    warp_message "REDIS_FPC_MAXMEMORY_POLICY: $(warp_message_info "$_cfg_rfp")"
    warp_message "REDIS_SESSION_MAXMEMORY:    $(warp_message_info "$_cfg_rs")"
    warp_message "REDIS_SESSION_MAXMEMORY_POLICY: $(warp_message_info "$_cfg_rsp")"
    warp_message "PHP-FPM conf:               $(warp_message_info "${_php_conf:-N/A}")"
    warp_message "PHP-FPM pm:                 $(warp_message_info "$_php_pm")"
    warp_message "PHP-FPM pm.max_children:    $(warp_message_info "$_php_mc")"
    warp_message "PHP-FPM pm.start_servers:   $(warp_message_info "$_php_ss")"
    warp_message "PHP-FPM pm.min_spare_servers: $(warp_message_info "$_php_min")"
    warp_message "PHP-FPM pm.max_spare_servers: $(warp_message_info "$_php_max")"
    warp_message "PHP-FPM pm.max_requests:    $(warp_message_info "$_php_req")"
    warp_message ""

    if [ "$_show_suggest" = "0" ]; then
        return 0
    fi

    if ! [[ "$_host_mb" =~ ^[0-9]+$ ]]; then
        warp_message_warn "No se pudo calcular sugerencias: RAM total no disponible."
        warp_message ""
        return 0
    fi

    _es_mb=$(memory_max_int 1024 "$(memory_percent_mb "$_host_mb" 13 100)")
    _rc_mb=$(memory_max_int 512 "$(memory_percent_mb "$_host_mb" 6 100)")
    _rf_mb=$(memory_max_int 512 "$(memory_percent_mb "$_host_mb" 6 100)")
    _rs_mb=$(memory_max_int 128 "$(memory_percent_mb "$_host_mb" 15 1000)")
    _php_profile=$(memory_php_profile_pick "$_host_mb")
    _php_suggest=$(memory_php_profile_values "$_php_profile")

    warp_message_info "[SUGERIDO]"
    warp_message "ES_MEMORY:                  $(warp_message_info "${_es_mb}m")"
    warp_message "REDIS_CACHE_MAXMEMORY:      $(warp_message_info "${_rc_mb}mb")"
    warp_message "REDIS_CACHE_MAXMEMORY_POLICY: $(warp_message_info "allkeys-lru")"
    warp_message "REDIS_FPC_MAXMEMORY:        $(warp_message_info "${_rf_mb}mb")"
    warp_message "REDIS_FPC_MAXMEMORY_POLICY: $(warp_message_info "allkeys-lru")"
    warp_message "REDIS_SESSION_MAXMEMORY:    $(warp_message_info "${_rs_mb}mb")"
    warp_message "REDIS_SESSION_MAXMEMORY_POLICY: $(warp_message_info "noeviction")"
    warp_message "PHP-FPM profile sugerido:   $(warp_message_info "$_php_profile")"
    echo "$_php_suggest" | while IFS= read -r _line; do
        [ -z "$_line" ] && continue
        warp_message "  - $_line"
    done
    warp_message ""
}

memory_report_print_json() {
    _show_suggest="$1"

    _host_mb=$(memory_host_total_mb)
    _host_human=$(memory_mb_to_human "$_host_mb")

    _usage_php=$(memory_service_mem_usage "php")
    _usage_mysql=$(memory_service_mem_usage "mysql")
    _usage_es=$(memory_service_mem_usage "elasticsearch")
    _usage_rc=$(memory_service_mem_usage "redis-cache")
    _usage_rf=$(memory_service_mem_usage "redis-fpc")
    _usage_rs=$(memory_service_mem_usage "redis-session")

    _cfg_es=$(memory_env_value "ES_MEMORY")
    _cfg_rc=$(memory_env_value "REDIS_CACHE_MAXMEMORY")
    _cfg_rcp=$(memory_env_value "REDIS_CACHE_MAXMEMORY_POLICY")
    _cfg_rf=$(memory_env_value "REDIS_FPC_MAXMEMORY")
    _cfg_rfp=$(memory_env_value "REDIS_FPC_MAXMEMORY_POLICY")
    _cfg_rs=$(memory_env_value "REDIS_SESSION_MAXMEMORY")
    _cfg_rsp=$(memory_env_value "REDIS_SESSION_MAXMEMORY_POLICY")

    _php_conf=$(memory_php_conf_file)
    _php_pm=$(memory_php_conf_read "$_php_conf" "pm")
    _php_mc=$(memory_php_conf_read "$_php_conf" "pm.max_children")
    _php_ss=$(memory_php_conf_read "$_php_conf" "pm.start_servers")
    _php_min=$(memory_php_conf_read "$_php_conf" "pm.min_spare_servers")
    _php_max=$(memory_php_conf_read "$_php_conf" "pm.max_spare_servers")
    _php_req=$(memory_php_conf_read "$_php_conf" "pm.max_requests")

    [ -z "$_php_conf" ] && _php_conf="N/A"
    [ -z "$_php_pm" ] && _php_pm="N/A"
    [ -z "$_php_mc" ] && _php_mc="N/A"
    [ -z "$_php_ss" ] && _php_ss="N/A"
    [ -z "$_php_min" ] && _php_min="N/A"
    [ -z "$_php_max" ] && _php_max="N/A"
    [ -z "$_php_req" ] && _php_req="N/A"

    if [[ "$_host_mb" =~ ^[0-9]+$ ]] && [ "$_show_suggest" = "1" ]; then
        _es_mb=$(memory_max_int 1024 "$(memory_percent_mb "$_host_mb" 13 100)")
        _rc_mb=$(memory_max_int 512 "$(memory_percent_mb "$_host_mb" 6 100)")
        _rf_mb=$(memory_max_int 512 "$(memory_percent_mb "$_host_mb" 6 100)")
        _rs_mb=$(memory_max_int 128 "$(memory_percent_mb "$_host_mb" 15 1000)")
        _php_profile=$(memory_php_profile_pick "$_host_mb")
        _php_suggest=$(memory_php_profile_values "$_php_profile")
    else
        _es_mb=""
        _rc_mb=""
        _rf_mb=""
        _rs_mb=""
        _php_profile=""
        _php_suggest=""
    fi

    _php_suggest_pm=$(echo "$_php_suggest" | grep '^pm=' | cut -d '=' -f2)
    _php_suggest_mc=$(echo "$_php_suggest" | grep '^pm.max_children=' | cut -d '=' -f2)
    _php_suggest_ss=$(echo "$_php_suggest" | grep '^pm.start_servers=' | cut -d '=' -f2)
    _php_suggest_min=$(echo "$_php_suggest" | grep '^pm.min_spare_servers=' | cut -d '=' -f2)
    _php_suggest_max=$(echo "$_php_suggest" | grep '^pm.max_spare_servers=' | cut -d '=' -f2)
    _php_suggest_req=$(echo "$_php_suggest" | grep '^pm.max_requests=' | cut -d '=' -f2)

    cat <<EOF
{
  "host": {
    "ram_total_mb": "$(memory_json_escape "$_host_mb")",
    "ram_total_human": "$(memory_json_escape "$_host_human")"
  },
  "usage": {
    "php": "$(memory_json_escape "$_usage_php")",
    "mysql": "$(memory_json_escape "$_usage_mysql")",
    "elasticsearch": "$(memory_json_escape "$_usage_es")",
    "redis_cache": "$(memory_json_escape "$_usage_rc")",
    "redis_fpc": "$(memory_json_escape "$_usage_rf")",
    "redis_session": "$(memory_json_escape "$_usage_rs")"
  },
  "config": {
    "es_memory": "$(memory_json_escape "$_cfg_es")",
    "redis_cache_maxmemory": "$(memory_json_escape "$_cfg_rc")",
    "redis_cache_policy": "$(memory_json_escape "$_cfg_rcp")",
    "redis_fpc_maxmemory": "$(memory_json_escape "$_cfg_rf")",
    "redis_fpc_policy": "$(memory_json_escape "$_cfg_rfp")",
    "redis_session_maxmemory": "$(memory_json_escape "$_cfg_rs")",
    "redis_session_policy": "$(memory_json_escape "$_cfg_rsp")",
    "php_fpm_conf": "$(memory_json_escape "$_php_conf")",
    "php_fpm_pm": "$(memory_json_escape "$_php_pm")",
    "php_fpm_max_children": "$(memory_json_escape "$_php_mc")",
    "php_fpm_start_servers": "$(memory_json_escape "$_php_ss")",
    "php_fpm_min_spare_servers": "$(memory_json_escape "$_php_min")",
    "php_fpm_max_spare_servers": "$(memory_json_escape "$_php_max")",
    "php_fpm_max_requests": "$(memory_json_escape "$_php_req")"
  },
  "suggested": {
    "enabled": "$_show_suggest",
    "es_memory": "$(memory_json_escape "${_es_mb}m")",
    "redis_cache_maxmemory": "$(memory_json_escape "${_rc_mb}mb")",
    "redis_cache_policy": "allkeys-lru",
    "redis_fpc_maxmemory": "$(memory_json_escape "${_rf_mb}mb")",
    "redis_fpc_policy": "allkeys-lru",
    "redis_session_maxmemory": "$(memory_json_escape "${_rs_mb}mb")",
    "redis_session_policy": "noeviction",
    "php_fpm_profile": "$(memory_json_escape "$_php_profile")",
    "php_fpm_pm": "$(memory_json_escape "$_php_suggest_pm")",
    "php_fpm_max_children": "$(memory_json_escape "$_php_suggest_mc")",
    "php_fpm_start_servers": "$(memory_json_escape "$_php_suggest_ss")",
    "php_fpm_min_spare_servers": "$(memory_json_escape "$_php_suggest_min")",
    "php_fpm_max_spare_servers": "$(memory_json_escape "$_php_suggest_max")",
    "php_fpm_max_requests": "$(memory_json_escape "$_php_suggest_req")"
  }
}
EOF
}

memory_report() {
    _output="text"
    _show_suggest="1"

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                memory_help_usage
                return 0
            ;;
            --json)
                _output="json"
            ;;
            --no-suggest)
                _show_suggest="0"
            ;;
            *)
                warp_message_error "Wrong input: $1"
                memory_help_usage
                return 1
            ;;
        esac
        shift
    done

    if [ "$_output" = "json" ]; then
        memory_report_print_json "$_show_suggest"
    else
        memory_report_print_text "$_show_suggest"
    fi
}

memory_main() {
    case "$1" in
        ""|report)
            if [ "$1" = "report" ]; then
                shift
            fi
            memory_report "$@"
        ;;
        -h|--help)
            memory_help_usage
        ;;
        *)
            memory_help_usage
            return 1
        ;;
    esac
}
