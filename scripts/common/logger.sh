#!/bin/bash
# logger.sh - Utilidades de logging estandarizadas
# Usuario: devops-bot-oxicore

set -euo pipefail

# Colores para output (compatibles con GitHub Actions)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Función para logging de información
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Función para logging de éxito
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Función para logging de advertencias
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Función para logging de errores
log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Función para logging de pasos
log_step() {
    echo ""
    echo -e "${BLUE}==>${NC} $*"
    echo ""
}

# Exportar funciones para uso en otros scripts
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_step
