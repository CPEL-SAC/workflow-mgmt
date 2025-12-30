#!/bin/bash
# deploy-cloudrun.sh - Script completo para CI/CD de Cloud Run
# Usuario: devops-bot-oxicore

set -euo pipefail

# Parámetros
SERVICE_NAME="${1:?SERVICE_NAME required}"
PROJECT_ID="${2:?PROJECT_ID required}"
GCLOUD_SA_KEY="${3:?GCLOUD_SA_KEY required}"
ENVIRONMENT="${4:-dev}"
REGION="${5:-us-central1}"
DOCKERFILE="${6:-dockerfile}"
REGISTRY_NAME="${7:-docker-images}"
TIMEOUT="${8:-3600}"

echo "==> Configuración"
echo "Service: $SERVICE_NAME"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"

# 1. Generar image tag
COMMIT_SHORT=$(git rev-parse --short HEAD)
IMAGE_TAG="${ENVIRONMENT}-${COMMIT_SHORT}"
echo "Image tag: $IMAGE_TAG"

# 2. Autenticar con Google Cloud
echo "==> Autenticando con Google Cloud"
echo "$GCLOUD_SA_KEY" > /tmp/gcloud-key.json
gcloud auth activate-service-account --key-file=/tmp/gcloud-key.json
gcloud config set project "$PROJECT_ID"
rm /tmp/gcloud-key.json

# 3. Configurar Artifact Registry
echo "==> Configurando Artifact Registry"
if ! gcloud artifacts repositories describe "$REGISTRY_NAME" --location="$REGION" --project="$PROJECT_ID" &>/dev/null; then
  echo "Creando Artifact Registry..."
  gcloud artifacts repositories create "$REGISTRY_NAME" \
    --repository-format=docker \
    --location="$REGION" \
    --project="$PROJECT_ID"
fi

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

REGISTRY_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}"
FULL_IMAGE="${REGISTRY_URL}/${SERVICE_NAME}:${IMAGE_TAG}"

echo "Registry: $REGISTRY_URL"
echo "Full image: $FULL_IMAGE"

# 4. Build Docker image
echo "==> Building Docker image"
docker build -f "$DOCKERFILE" -t "$FULL_IMAGE" .

# 5. Push to Artifact Registry
echo "==> Pushing to Artifact Registry"
docker push "$FULL_IMAGE"

# 6. Obtener variables de Secret Manager
echo "==> Obteniendo variables de Secret Manager"
SECRET_DATA=$(gcloud secrets versions access latest --secret="$SERVICE_NAME" --project="$PROJECT_ID" 2>/dev/null || echo "{}")
ENV_VARS=$(echo "$SECRET_DATA" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')

# 7. Deploy a Cloud Run
echo "==> Desplegando a Cloud Run"
if [[ -n "$ENV_VARS" ]] && [[ "$ENV_VARS" != "" ]]; then
  gcloud run deploy "$SERVICE_NAME" \
    --image "$FULL_IMAGE" \
    --platform managed \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --timeout="$TIMEOUT" \
    --set-env-vars="$ENV_VARS" \
    --quiet
else
  gcloud run deploy "$SERVICE_NAME" \
    --image "$FULL_IMAGE" \
    --platform managed \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --timeout="$TIMEOUT" \
    --quiet
fi

# 8. Obtener URL del servicio
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --format='value(status.url)' 2>/dev/null || echo "")

echo ""
echo "==> ✅ Deploy completado"
echo "Service URL: $SERVICE_URL"
echo "Image: $FULL_IMAGE"
echo "Tag: $IMAGE_TAG"

# Cleanup
gcloud auth revoke --all || true
