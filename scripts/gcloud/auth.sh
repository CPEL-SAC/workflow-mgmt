#!/bin/bash
# auth.sh - Autenticación con Google Cloud
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/../common/validate-env.sh"

# Función para autenticar con Google Cloud usando service account
gcloud_auth() {
    local credentials_json="${GCLOUD_SA_KEY:?GCLOUD_SA_KEY environment variable is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID environment variable is required}"

    log_step "Autenticando con Google Cloud"

    # Validar que tenemos las herramientas necesarias
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI no está instalado"
        return 1
    fi

    # Crear archivo temporal para las credenciales
    local creds_file
    creds_file=$(mktemp)

    # Cleanup en caso de error
    trap "rm -f ${creds_file}" EXIT

    # Escribir credenciales al archivo temporal
    echo "$credentials_json" > "$creds_file"

    # Autenticar con la service account
    log_info "Activando service account..."
    if gcloud auth activate-service-account --key-file="$creds_file"; then
        log_success "Autenticación exitosa"
    else
        log_error "Falló la autenticación con Google Cloud"
        return 1
    fi

    # Configurar proyecto por defecto
    log_info "Configurando proyecto: ${project_id}"
    if gcloud config set project "$project_id"; then
        log_success "Proyecto configurado: ${project_id}"
    else
        log_error "Falló la configuración del proyecto"
        return 1
    fi

    # Limpiar archivo de credenciales
    rm -f "$creds_file"
    trap - EXIT

    return 0
}

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gcloud_auth "$@"
fi

# Exportar función
export -f gcloud_auth
