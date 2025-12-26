#!/bin/bash
# deploy-with-secrets.sh - Deploy a Cloud Run con Secret Manager
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/../common/validate-env.sh"

# Función para desplegar a Cloud Run con secret montado
deploy_with_secret() {
    local service_name="${1:?Service name is required}"
    local image="${2:?Image is required}"
    local secret_name="${3:?Secret name is required}"
    local region="${4:-us-central1}"
    local timeout="${5:-3600}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Desplegando a Cloud Run con Secret Manager"
    log_info "Servicio: ${service_name}"
    log_info "Imagen: ${image}"
    log_info "Secret: ${secret_name}"
    log_info "Región: ${region}"

    # Validar que gcloud está autenticado
    if ! gcloud config get-value project &> /dev/null; then
        log_error "gcloud no está autenticado"
        return 1
    fi

    # Verificar que el secret existe
    if ! gcloud secrets describe "$secret_name" --project="$project_id" &> /dev/null; then
        log_error "Secret no encontrado: ${secret_name}"
        return 1
    fi

    log_step "Desplegando servicio..."

    # Deploy con secret como volumen montado
    # Cloud Run leerá el JSON y lo expondrá como archivo
    if gcloud run deploy "$service_name" \
        --image "$image" \
        --platform managed \
        --region "$region" \
        --project "$project_id" \
        --timeout="$timeout" \
        --update-secrets="/etc/secrets/${secret_name}=${secret_name}:latest" \
        --quiet; then

        log_success "Despliegue exitoso"

        # Obtener URL del servicio
        local service_url
        service_url=$(gcloud run services describe "$service_name" \
            --region "$region" \
            --project "$project_id" \
            --format='value(status.url)' 2>/dev/null || echo "")

        if [[ -n "$service_url" ]]; then
            log_success "Servicio disponible en: ${service_url}"
            echo "SERVICE_URL=${service_url}"
        fi

        return 0
    else
        log_error "Falló el despliegue a Cloud Run"
        return 1
    fi
}

# Función alternativa: montar secret como variables de entorno individuales
deploy_with_secret_env_vars() {
    local service_name="${1:?Service name is required}"
    local image="${2:?Image is required}"
    local secret_name="${3:?Secret name is required}"
    local region="${4:-us-central1}"
    local timeout="${5:-3600}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Desplegando a Cloud Run con Secret Manager (env vars desde JSON)"
    log_info "Servicio: ${service_name}"
    log_info "Imagen: ${image}"
    log_info "Secret: ${secret_name}"

    # Primero obtener el secret
    log_info "Obteniendo secret..."
    local secret_data
    secret_data=$(gcloud secrets versions access latest --secret="$secret_name" --project="$project_id")

    # Construir argumentos --set-env-vars dinámicamente desde el JSON
    local env_args=""
    while IFS="=" read -r key value; do
        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            env_args="${env_args} --set-env-vars=${key}=${value}"
        fi
    done < <(echo "$secret_data" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')

    log_step "Desplegando con ${env_args}"

    # Deploy con variables de entorno
    if gcloud run deploy "$service_name" \
        --image "$image" \
        --platform managed \
        --region "$region" \
        --project "$project_id" \
        --timeout="$timeout" \
        ${env_args} \
        --quiet; then

        log_success "Despliegue exitoso con variables de entorno"
        return 0
    else
        log_error "Falló el despliegue"
        return 1
    fi
}

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    deploy_with_secret "$@"
fi

# Exportar funciones
export -f deploy_with_secret
export -f deploy_with_secret_env_vars
