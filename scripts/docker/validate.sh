#!/bin/bash
# validate.sh - Validación de Dockerfile y contexto
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"

# Función para validar que existe el Dockerfile
validate_dockerfile() {
    local dockerfile="${1:-dockerfile}"

    log_step "Validando Dockerfile"

    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile no encontrado: ${dockerfile}"
        return 1
    fi

    log_success "Dockerfile encontrado: ${dockerfile}"

    # Validar sintaxis básica
    if ! grep -q "^FROM" "$dockerfile"; then
        log_error "Dockerfile inválido: no contiene instrucción FROM"
        return 1
    fi

    log_success "Dockerfile válido"
    return 0
}

# Función para validar archivos requeridos para build
validate_build_context() {
    log_step "Validando contexto de build"

    local required_files=("$@")
    local all_valid=true

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]] && [[ ! -d "$file" ]]; then
            log_error "Archivo/directorio requerido no encontrado: ${file}"
            all_valid=false
        else
            log_info "✓ ${file} existe"
        fi
    done

    if [[ "$all_valid" == "false" ]]; then
        log_error "Faltan archivos requeridos para el build"
        return 1
    fi

    log_success "Contexto de build válido"
    return 0
}

# Exportar funciones
export -f validate_dockerfile
export -f validate_build_context
