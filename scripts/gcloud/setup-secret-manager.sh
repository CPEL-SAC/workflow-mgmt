#!/bin/bash
# setup-secret-manager.sh - Gestión de Secret Manager para variables de entorno
# Usuario: devops-bot-oxicore

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/logger.sh"
source "${SCRIPT_DIR}/../common/validate-env.sh"

# Función para verificar si un secret existe
secret_exists() {
    local secret_name="${1:?Secret name is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    if gcloud secrets describe "$secret_name" \
        --project="$project_id" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Función para crear un secret
create_secret() {
    local secret_name="${1:?Secret name is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Creando secret: ${secret_name}"

    if gcloud secrets create "$secret_name" \
        --replication-policy="automatic" \
        --project="$project_id"; then
        log_success "Secret creado: ${secret_name}"
        return 0
    else
        log_error "Falló la creación del secret"
        return 1
    fi
}

# Función para subir una versión del secret desde archivo JSON
upload_secret_version() {
    local secret_name="${1:?Secret name is required}"
    local data_file="${2:?Data file is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Subiendo nueva versión del secret: ${secret_name}"

    if gcloud secrets versions add "$secret_name" \
        --data-file="$data_file" \
        --project="$project_id"; then
        log_success "Versión del secret agregada exitosamente"
        return 0
    else
        log_error "Falló al agregar versión del secret"
        return 1
    fi
}

# Función para dar permisos a Cloud Run para leer el secret
grant_secret_access() {
    local secret_name="${1:?Secret name is required}"
    local service_account="${2:?Service account is required}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Otorgando permisos de lectura del secret"

    if gcloud secrets add-iam-policy-binding "$secret_name" \
        --member="serviceAccount:${service_account}" \
        --role="roles/secretmanager.secretAccessor" \
        --project="$project_id"; then
        log_success "Permisos otorgados"
        return 0
    else
        log_warning "No se pudieron otorgar permisos (puede que ya existan)"
        return 0
    fi
}

# Función para convertir archivo .env a JSON
env_to_json() {
    local env_file="${1:?Env file is required}"
    local output_file="${2:?Output file is required}"

    log_step "Convirtiendo .env a JSON"

    python3 - <<EOF
import json
import os

env_vars = {}

with open("${env_file}", 'r') as f:
    for line in f:
        line = line.strip()

        # Ignorar líneas vacías y comentarios
        if not line or line.startswith('#'):
            continue

        # Manejar variables con valores JSON multilínea
        if '=' in line:
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()

            # Remover comillas si existen
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            elif value.startswith("'") and value.endswith("'"):
                value = value[1:-1]

            env_vars[key] = value

with open("${output_file}", 'w') as f:
    json.dump(env_vars, f, indent=2)

print(f"Convertidas {len(env_vars)} variables de entorno")
EOF

    log_success "Archivo JSON generado: ${output_file}"
}

# Función principal para configurar secret completo
setup_env_secret() {
    local secret_name="${1:?Secret name is required}"
    local env_file="${2:?Env file is required}"
    local service_account="${3:-}"
    local project_id="${GCLOUD_PROJECT_ID:?GCLOUD_PROJECT_ID is required}"

    log_step "Configurando Secret Manager para variables de entorno"
    log_info "Secret: ${secret_name}"
    log_info "Archivo: ${env_file}"
    log_info "Proyecto: ${project_id}"

    # Validar que existe el archivo .env
    if [[ ! -f "$env_file" ]]; then
        log_error "Archivo .env no encontrado: ${env_file}"
        return 1
    fi

    # Convertir .env a JSON temporal
    local json_file="/tmp/${secret_name}.json"
    if ! env_to_json "$env_file" "$json_file"; then
        return 1
    fi

    # Crear secret si no existe
    if ! secret_exists "$secret_name"; then
        log_info "Secret no existe, creando..."
        if ! create_secret "$secret_name"; then
            rm -f "$json_file"
            return 1
        fi
    else
        log_info "Secret ya existe, agregando nueva versión"
    fi

    # Subir versión del secret
    if ! upload_secret_version "$secret_name" "$json_file"; then
        rm -f "$json_file"
        return 1
    fi

    # Limpiar archivo temporal
    rm -f "$json_file"

    # Dar permisos si se proporcionó service account
    if [[ -n "$service_account" ]]; then
        grant_secret_access "$secret_name" "$service_account"
    fi

    log_success "Secret configurado exitosamente: ${secret_name}"
    return 0
}

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_env_secret "$@"
fi

# Exportar funciones
export -f secret_exists
export -f create_secret
export -f upload_secret_version
export -f grant_secret_access
export -f env_to_json
export -f setup_env_secret
