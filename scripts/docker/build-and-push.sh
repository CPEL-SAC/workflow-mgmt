#!/bin/bash
# build-and-push.sh - Build y push de imagen Docker a Artifact Registry
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/validate.sh"
source "${SCRIPT_DIR}/build.sh"

# Función para hacer push de imagen a registry
docker_push() {
    local image_name="${1:?Image name is required}"
    local image_tag="${2:?Image tag is required}"

    log_step "Pushing imagen a registry"

    local full_image="${image_name}:${image_tag}"

    if docker push "$full_image"; then
        log_success "Push exitoso: ${full_image}"
        return 0
    else
        log_error "Falló el push de la imagen"
        return 1
    fi
}

# Función para tagear imagen con múltiples tags
docker_tag_image() {
    local source_image="${1:?Source image is required}"
    local source_tag="${2:?Source tag is required}"
    local target_image="${3:?Target image is required}"
    local target_tag="${4:?Target tag is required}"

    log_info "Tageando imagen: ${source_image}:${source_tag} -> ${target_image}:${target_tag}"

    if docker tag "${source_image}:${source_tag}" "${target_image}:${target_tag}"; then
        log_success "Tag creado exitosamente"
        return 0
    else
        log_error "Falló el tag de la imagen"
        return 1
    fi
}

# Función principal: build y push
docker_build_and_push() {
    local local_image_name="${1:?Local image name is required}"
    local image_tag="${2:?Image tag is required}"
    local registry_url="${3:?Registry URL is required}"
    local dockerfile="${4:-dockerfile}"
    local build_context="${5:-.}"

    log_step "Build y Push de imagen Docker"

    # Build local
    if ! docker_build "$local_image_name" "$image_tag" "$dockerfile" "$build_context"; then
        return 1
    fi

    # Tag con la URL del registry
    local full_registry_image="${registry_url}/${local_image_name}"

    if ! docker_tag_image "$local_image_name" "$image_tag" "$full_registry_image" "$image_tag"; then
        return 1
    fi

    # Push al registry
    if ! docker_push "$full_registry_image" "$image_tag"; then
        return 1
    fi

    # También tagear como 'latest' si se desea
    log_info "Tageando también como 'latest'"
    docker_tag_image "$full_registry_image" "$image_tag" "$full_registry_image" "latest" || true
    docker_push "$full_registry_image" "latest" || true

    log_success "Imagen disponible en: ${full_registry_image}:${image_tag}"

    # Exportar nombre completo de la imagen para uso posterior
    echo "DOCKER_IMAGE=${full_registry_image}:${image_tag}"

    return 0
}

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    docker_build_and_push "$@"
fi

# Exportar funciones
export -f docker_push
export -f docker_tag_image
export -f docker_build_and_push
