#!/bin/bash
# setup-artifact-registry.sh - Configurar Artifact Registry en Google Cloud
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/../common/validate-env.sh"

# Función para verificar si un repositorio de Artifact Registry existe
artifact_registry_exists() {
    local repository_name="${1:?Repository name is required}"
    local location="${2:?Location is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_info "Verificando si existe el repositorio: ${repository_name}"

    if gcloud artifacts repositories describe "$repository_name" \
        --location="$location" \
        --project="$project_id" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Función para crear un repositorio de Artifact Registry
create_artifact_registry() {
    local repository_name="${1:?Repository name is required}"
    local location="${2:?Location is required}"
    local description="${3:-Docker images repository}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Configurando Artifact Registry"

    # Verificar si ya existe
    if artifact_registry_exists "$repository_name" "$location"; then
        log_info "El repositorio '${repository_name}' ya existe"
        return 0
    fi

    log_info "Creando repositorio: ${repository_name}"

    # Crear el repositorio
    if gcloud artifacts repositories create "$repository_name" \
        --repository-format=docker \
        --location="$location" \
        --description="$description" \
        --project="$project_id"; then
        log_success "Repositorio creado exitosamente: ${repository_name}"
        return 0
    else
        log_error "Falló la creación del repositorio"
        return 1
    fi
}

# Función para configurar autenticación de Docker con Artifact Registry
configure_docker_auth() {
    local location="${1:?Location is required}"

    log_step "Configurando autenticación de Docker"

    if gcloud auth configure-docker "${location}-docker.pkg.dev" --quiet; then
        log_success "Autenticación de Docker configurada"
        return 0
    else
        log_error "Falló la configuración de autenticación"
        return 1
    fi
}

# Función para obtener la URL completa del repositorio
get_repository_url() {
    local repository_name="${1:?Repository name is required}"
    local location="${2:?Location is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    echo "${location}-docker.pkg.dev/${project_id}/${repository_name}"
}

# Función principal que asegura que el repositorio existe y está configurado
ensure_artifact_registry() {
    local repository_name="${1:?Repository name is required}"
    local location="${2:-us-central1}"
    local description="${3:-Docker images repository}"

    log_step "Asegurando configuración de Artifact Registry"

    # Crear repositorio si no existe
    if ! create_artifact_registry "$repository_name" "$location" "$description"; then
        return 1
    fi

    # Configurar autenticación de Docker
    if ! configure_docker_auth "$location"; then
        return 1
    fi

    # Mostrar URL del repositorio
    local repo_url
    repo_url=$(get_repository_url "$repository_name" "$location")
    log_success "Repositorio disponible en: ${repo_url}"

    # Exportar URL para uso en otros scripts
    echo "ARTIFACT_REGISTRY_URL=${repo_url}"

    return 0
}

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ensure_artifact_registry "$@"
fi

# Exportar funciones
export -f artifact_registry_exists
export -f create_artifact_registry
export -f configure_docker_auth
export -f get_repository_url
export -f ensure_artifact_registry
