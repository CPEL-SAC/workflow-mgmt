#!/bin/bash
# validate-env.sh - Validación de variables de entorno requeridas
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Función para validar que una variable de entorno existe
validate_env_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"

    if [[ -z "$var_value" ]]; then
        log_error "Variable de entorno requerida no definida: ${var_name}"
        return 1
    fi

    log_info "✓ ${var_name} está definida"
    return 0
}

# Función para validar múltiples variables de entorno
validate_required_envs() {
    local all_valid=true

    log_step "Validando variables de entorno requeridas"

    for var_name in "$@"; do
        if ! validate_env_var "$var_name"; then
            all_valid=false
        fi
    done

    if [[ "$all_valid" == "false" ]]; then
        log_error "Faltan variables de entorno requeridas"
        return 1
    fi

    log_success "Todas las variables de entorno están definidas"
    return 0
}

# Exportar funciones
export -f validate_env_var
export -f validate_required_envs
