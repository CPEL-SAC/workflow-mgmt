# Workflow Management - Pipelines Centralizados

Sistema centralizado de CI/CD con GitHub Actions para automatizar despliegues en Google Cloud Platform.

## 📋 Descripción

Este repositorio contiene workflows reutilizables y scripts bash agnósticos para automatizar el proceso de build, test y despliegue de aplicaciones. Todos los scripts son ejecutados por el usuario `devops-bot-oxicore`.

**Filosofía CI/CD:**
- **CI (Continuous Integration)**: Build con `docker build` y push con `docker push` nativos
- **CD (Continuous Deployment)**: Deploy con `gcloud run deploy`

## 🏗️ Estructura

```
workflow-mgmt/
├── .github/workflows/              # Workflows reutilizables de GitHub Actions
│   └── deploy-gcloud-run-with-docker.yml  # Build (Docker) + Deploy (gcloud)
├── scripts/                        # Scripts bash reutilizables
│   ├── common/                    # Utilidades comunes
│   │   ├── logger.sh             # Sistema de logging
│   │   └── validate-env.sh       # Validación de variables
│   ├── docker/                    # Scripts de Docker
│   │   ├── build.sh              # Build de imágenes
│   │   ├── build-and-push.sh     # Build y push a registry
│   │   └── validate.sh           # Validación de Dockerfile
│   └── gcloud/                    # Scripts de Google Cloud
│       ├── auth.sh               # Autenticación con GCloud
│       ├── deploy.sh             # Despliegue a Cloud Run
│       └── setup-artifact-registry.sh  # Gestión de Artifact Registry
├── config/                         # Configuraciones por proyecto
│   └── metabet-backend/
│       └── deploy.env
└── docs/                          # Documentación
    ├── ARCHITECTURE.md
    └── QUICK_START.md
```

## 🚀 Características Principales

### Separación CI/CD

**Job 1 - CI (Build):**
- Genera tag dinámico: `dev-{commit_short}`
- Build con `docker build` nativo
- Push con `docker push` a Artifact Registry
- Sin uso de gcloud para build

**Job 2 - CD (Deploy):**
- Deploy con `gcloud run deploy`
- Usa la imagen del job anterior
- Configuración de ambiente y permisos

### Tags Dinámicos
- Formato: `dev-{commit_short_sha}`
- Ejemplo: `dev-a1b2c3d`
- Tag `latest` se actualiza automáticamente

### Artifact Registry Automático
- Crea repositorio si no existe
- Configura autenticación de Docker
- Gestiona imágenes por proyecto GCloud

### Scripts Agnósticos
- Bash puro sin dependencias de plataforma CI/CD
- Sistema de logging estandarizado
- Validación robusta de errores

## 📝 Uso

### 1. Configurar Secrets en GitHub

En el repositorio que usará los workflows:

- `GCLOUD_SA_KEY_TEST`: Service Account Key para test (JSON)
- `GCLOUD_SA_KEY_PROD`: Service Account Key para prod (JSON)

### 2. Crear Workflow en tu Proyecto

Archivo `.github/workflows/deploy.yml`:

```yaml
name: Deploy

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
      service_name: tu-servicio
      region: us-central1
      timeout: '3600'
      project_id: tu-proyecto-test
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
      service_name: tu-servicio
      region: us-central1
      timeout: '3600'
      project_id: tu-proyecto-prod
      environment: prod
      dockerfile: dockerfile
      artifact_registry_name: docker-images
    secrets:
      gcloud_sa_key: ${{ secrets.GCLOUD_SA_KEY_PROD }}
```

### 3. Configurar Environments en GitHub

1. Settings → Environments
2. Crear `test` y `prod`
3. Configurar protection rules para prod

## 🔧 Workflow Principal

### deploy-gcloud-run-with-docker.yml

Pipeline completo CI/CD con separación de responsabilidades.

**Inputs:**
- `service_name` (required): Nombre del servicio
- `region` (default: us-central1): Región de GCloud
- `timeout` (default: 3600): Timeout en segundos
- `project_id` (required): ID del proyecto GCloud
- `environment` (required): Ambiente (test/prod)
- `dockerfile` (default: dockerfile): Path al Dockerfile
- `artifact_registry_name` (default: docker-images): Nombre del registry

**Secrets:**
- `gcloud_sa_key` (required): Service Account Key

**Outputs:**
- `service_url`: URL del servicio desplegado
- `image_url`: URL de la imagen Docker

**Jobs:**

1. **build** (CI):
   - Checkout código
   - Generar tag: `dev-{commit}`
   - Setup Docker Buildx
   - Autenticar GCloud
   - Crear/verificar Artifact Registry
   - **Build con `docker build`**
   - **Push con `docker push`**

2. **deploy** (CD):
   - Autenticar GCloud
   - **Deploy con `gcloud run deploy`**
   - Obtener URL del servicio

## 🛠️ Scripts Bash

### Autenticación con Google Cloud

```bash
GCLOUD_SA_KEY="<json-key>" \
GCLOUD_PROJECT_ID="tu-proyecto" \
bash scripts/gcloud/auth.sh
```

### Configurar Artifact Registry

```bash
GCLOUD_PROJECT_ID="tu-proyecto" \
bash scripts/gcloud/setup-artifact-registry.sh docker-images us-central1
```

### Build y Push de Docker (Nativo)

```bash
# El workflow usa directamente:
docker build -f dockerfile -t IMAGEN:TAG .
docker push IMAGEN:TAG
```

## 📦 Ejemplo: metabet-backend (PoC)

Primer proyecto usando este sistema.

**Flujo:**
1. Push a `master` → Deploy automático a TEST
2. Manual dispatch → Seleccionar ambiente

**Proceso CI/CD:**

**CI:**
1. Tag: `dev-a1b2c3d` (generado del commit)
2. Verificar/crear Artifact Registry: `docker-images`
3. Build: `docker build -f dockerfile -t IMAGE:TAG .`
4. Push: `docker push IMAGE:TAG`
5. Push: `docker push IMAGE:latest`

**CD:**
1. Deploy: `gcloud run deploy SERVICE --image IMAGE:TAG`
2. Retornar URL del servicio

## 🔐 Permisos Requeridos

La Service Account necesita:
- `Cloud Run Admin`
- `Artifact Registry Administrator`
- `Storage Admin`
- `Service Account User`

## 📊 Flujo de Imágenes

```
CI Job (docker build/push)
         ↓
us-central1-docker.pkg.dev/
  └── {project}/
      └── docker-images/
          └── {service}/
              ├── dev-{commit}  ← Específico
              └── latest        ← Siempre actualizado
         ↓
CD Job (gcloud deploy)
         ↓
Cloud Run Service
```

## 🎯 Próximos Pasos

- [ ] Tests automáticos pre-deploy
- [ ] Rollback automático en caso de fallo
- [ ] Notificaciones (Slack/Email)
- [ ] Métricas de deployment
- [ ] Soporte para múltiples servicios

## 📄 Configuración por Proyecto

Cada proyecto puede tener configuración en `config/{proyecto}/deploy.env`.

## 🤝 Contribución

Para agregar un nuevo proyecto:

1. Crear workflow en el repositorio del proyecto
2. Configurar secrets y environments
3. (Opcional) Crear config en `config/{proyecto}/`

## 📚 Documentación Adicional

- [Arquitectura detallada](docs/ARCHITECTURE.md)
- [Guía rápida](docs/QUICK_START.md)

---

**Ejecutado por:** devops-bot-oxicore
**Mantenido por:** CPEL-SAC
**Filosofía:** CI con Docker nativo, CD con gcloud
