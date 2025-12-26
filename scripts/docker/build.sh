#!/bin/bash
# build.sh - Build de imagen Docker (agnóstico)
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source logger y validación
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/validate.sh"

# Función principal de build
docker_build() {
    local image_name="${1:?Image name is required}"
    local image_tag="${2:-latest}"
    local dockerfile="${3:-dockerfile}"
    local build_context="${4:-.}"

    log_step "Iniciando build de imagen Docker"
    log_info "Imagen: ${image_name}:${image_tag}"
    log_info "Dockerfile: ${dockerfile}"
    log_info "Contexto: ${build_context}"

    # Validar Dockerfile
    if ! validate_dockerfile "$dockerfile"; then
        return 1
    fi

    # Build de la imagen
    log_step "Construyendo imagen Docker"

    if docker build \
        -f "$dockerfile" \
        -t "${image_name}:${image_tag}" \
        "$build_context"; then
        log_success "Imagen construida exitosamente: ${image_name}:${image_tag}"

        # Mostrar información de la imagen
        log_info "Información de la imagen:"
        docker images "${image_name}:${image_tag}"

        return 0
    else
        log_error "Falló el build de la imagen Docker"
        return 1
    fi
}

# Si se ejecuta directamente (no se hace source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    docker_build "$@"
fi

# Exportar función
export -f docker_build
