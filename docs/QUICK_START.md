# Guía Rápida de Configuración

## ⚡ Setup Rápido para Nuevos Proyectos

### 1. Preparar Service Account en Google Cloud

```bash
# Crear Service Account
gcloud iam service-accounts create devops-bot-oxicore \
  --display-name="DevOps Bot Oxicore" \
  --project=TU_PROYECTO

# Asignar roles necesarios
gcloud projects add-iam-policy-binding TU_PROYECTO \
  --member="serviceAccount:devops-bot-oxicore@TU_PROYECTO.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding TU_PROYECTO \
  --member="serviceAccount:devops-bot-oxicore@TU_PROYECTO.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding TU_PROYECTO \
  --member="serviceAccount:devops-bot-oxicore@TU_PROYECTO.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding TU_PROYECTO \
  --member="serviceAccount:devops-bot-oxicore@TU_PROYECTO.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Crear y descargar key
gcloud iam service-accounts keys create sa-key.json \
  --iam-account=devops-bot-oxicore@TU_PROYECTO.iam.gserviceaccount.com
```

### 2. Configurar Secrets en GitHub

1. Ve a tu repositorio en GitHub
2. Settings → Secrets and variables → Actions
3. Agregar secrets:
   - `GCLOUD_SA_KEY_TEST`: Contenido completo de `sa-key.json` del proyecto test
   - `GCLOUD_SA_KEY_PROD`: Contenido completo de `sa-key.json` del proyecto prod

### 3. Configurar Environments en GitHub

1. Settings → Environments
2. Crear environment `test`:
   - Deployment branches: `master` (opcional)
3. Crear environment `prod`:
   - Required reviewers: Agregar revisores (recomendado)
   - Deployment branches: Only selected branches

### 4. Crear Workflow en tu Proyecto

Crear archivo `.github/workflows/deploy.yml`:

```yaml
name: Deploy Mi Proyecto

on:
  push:
    branches:
      - master
  workflow_dispatch:
    inputs:
      environment:
        description: 'Ambiente a desplegar'
        required: true
        type: choice
        options:
          - test
          - prod

jobs:
  deploy-test:
    name: Deploy to Test
    if: |
      (github.event_name == 'push' && github.ref == 'refs/heads/master') ||
      (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'test')
    uses: CPEL-SAC/workflow-mgmt/.github/workflows/deploy-gcloud-run-with-docker.yml@main
    with:
      service_name: mi-servicio
      region: us-central1
      timeout: '3600'
      project_id: mi-proyecto-test
      environment: test
      dockerfile: dockerfile
      artifact_registry_name: docker-images
    secrets:
      gcloud_sa_key: ${{ secrets.GCLOUD_SA_KEY_TEST }}

  deploy-prod:
    name: Deploy to Production
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod'
    uses: CPEL-SAC/workflow-mgmt/.github/workflows/deploy-gcloud-run-with-docker.yml@main
    with:
      service_name: mi-servicio
      region: us-central1
      timeout: '3600'
      project_id: mi-proyecto-prod
      environment: prod
      dockerfile: dockerfile
      artifact_registry_name: docker-images
    secrets:
      gcloud_sa_key: ${{ secrets.GCLOUD_SA_KEY_PROD }}
```

### 5. Asegurar que tu Proyecto tenga Dockerfile

Ejemplo de `dockerfile`:

```dockerfile
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

EXPOSE 8080

CMD ["npm", "start"]
```

### 6. Primer Despliegue

**Opción A: Push a master (automático a TEST)**
```bash
git add .
git commit -m "Add GitHub Actions workflow"
git push origin master
```

**Opción B: Manual dispatch**
1. Ve a Actions en GitHub
2. Selecciona el workflow "Deploy Mi Proyecto"
3. Click en "Run workflow"
4. Selecciona el ambiente
5. Click en "Run workflow"

## 🔍 Verificar el Despliegue

El workflow mostrará:
- ✅ Tag de la imagen: `dev-abc123`
- ✅ URL del Artifact Registry
- ✅ URL de la imagen completa
- ✅ URL del servicio desplegado

## 📊 Estructura de Artifact Registry

Cada despliegue crea:
```
{region}-docker.pkg.dev/
  └── {project_id}/
      └── docker-images/
          └── {service_name}/
              ├── dev-{commit1}
              ├── dev-{commit2}
              ├── dev-{commit3}
              └── latest (siempre apunta al último)
```

## 🎯 Tags de Imagen

- **Formato:** `dev-{commit_short_sha}`
- **Ejemplo:** `dev-a1b2c3d`
- **Latest:** Siempre se actualiza al último deploy

## 🔧 Personalización

### Cambiar región
```yaml
with:
  region: us-east1  # Cambiar según necesidad
```

### Cambiar timeout
```yaml
with:
  timeout: '1800'  # 30 minutos
```

### Usar un Dockerfile diferente
```yaml
with:
  dockerfile: docker/Dockerfile.prod
```

### Cambiar nombre del Artifact Registry
```yaml
with:
  artifact_registry_name: mi-registry-custom
```

## 🚨 Troubleshooting

### Error: "Permission denied"
- Verificar que la Service Account tenga todos los roles necesarios
- Verificar que el secret esté configurado correctamente

### Error: "Dockerfile not found"
- Verificar que el Dockerfile exista en la raíz del proyecto
- O especificar el path correcto en `dockerfile: path/to/Dockerfile`

### Error: "Service not found"
- La primera vez, Cloud Run creará el servicio automáticamente
- Verificar que el nombre del servicio sea válido (solo minúsculas, números y guiones)

## 📞 Ayuda

Para más detalles, consulta el [README principal](../README.md).
