#!/bin/bash
# deploy.sh - Despliegue a Google Cloud Run
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/../common/validate-env.sh"

# Función para desplegar a Cloud Run desde código fuente
deploy_to_cloud_run() {
    local service_name="${1:?Service name is required}"
    local region="${2:-us-central1}"
    local timeout="${3:-3600}"
    local source_dir="${4:-.}"

    log_step "Desplegando a Google Cloud Run"
    log_info "Servicio: ${service_name}"
    log_info "Región: ${region}"
    log_info "Timeout: ${timeout}s"
    log_info "Source: ${source_dir}"

    # Validar variables de entorno requeridas
    if ! validate_required_envs GCLOUD_PROJECT_ID; then
        return 1
    fi

    # Validar que gcloud está autenticado
    if ! gcloud config get-value project &> /dev/null; then
        log_error "gcloud no está autenticado. Ejecuta gcloud/auth.sh primero"
        return 1
    fi

    # Cambiar al directorio source si es necesario
    if [[ "$source_dir" != "." ]]; then
        cd "$source_dir"
    fi

    # Desplegar servicio
    log_step "Iniciando despliegue..."

    if gcloud run deploy "$service_name" \
        --source . \
        --platform managed \
        --region "$region" \
        --project "$GCLOUD_PROJECT_ID" \
        --timeout="$timeout"; then

        log_success "Despliegue exitoso"

        # Obtener URL del servicio
        local service_url
        service_url=$(gcloud run services describe "$service_name" \
            --region "$region" \
            --project "$GCLOUD_PROJECT_ID" \
            --format='value(status.url)' 2>/dev/null || echo "")

        if [[ -n "$service_url" ]]; then
            log_success "Servicio disponible en: ${service_url}"
        fi

        return 0
    else
        log_error "Falló el despliegue a Cloud Run"
        return 1
    fi
}

# Función para desplegar usando una imagen Docker específica
deploy_image_to_cloud_run() {
    local service_name="${1:?Service name is required}"
    local image="${2:?Image is required}"
    local region="${3:-us-central1}"
    local timeout="${4:-3600}"

    log_step "Desplegando imagen a Google Cloud Run"
    log_info "Servicio: ${service_name}"
    log_info "Imagen: ${image}"
    log_info "Región: ${region}"

    if gcloud run deploy "$service_name" \
        --image "$image" \
        --platform managed \
        --region "$region" \
        --project "$GCLOUD_PROJECT_ID" \
        --timeout="$timeout"; then

        log_success "Despliegue exitoso"
        return 0
    else
        log_error "Falló el despliegue de la imagen"
        return 1
    fi
}

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_to_cloud_run "$@"
fi

# Exportar funciones
export -f deploy_to_cloud_run
export -f deploy_image_to_cloud_run
