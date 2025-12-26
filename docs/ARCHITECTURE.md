# Arquitectura del Sistema de Pipelines Centralizados

## 🎯 Objetivo

Centralizar la gestión de pipelines CI/CD para todos los proyectos de Oxiacore usando GitHub Actions, con scripts bash agnósticos ejecutados por el usuario `devops-bot-oxicore`.

## 🏛️ Arquitectura General

```
┌─────────────────────────────────────────────────────────────┐
│                    Repositorio del Proyecto                  │
│                  (ej: metabet-backend)                       │
│                                                              │
│  .github/workflows/deploy.yml                               │
│  └── Llama a workflows reutilizables →                     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               │ workflow_call
                               ↓
┌─────────────────────────────────────────────────────────────┐
│              Repositorio workflow-mgmt                       │
│         (Plantillas Centralizadas)                          │
│                                                              │
│  .github/workflows/                                         │
│  ├── deploy-gcloud-run-with-docker.yml ← Workflow principal│
│  ├── deploy-gcloud-run.yml                                 │
│  ├── test-node.yml                                          │
│  └── build-docker.yml                                       │
│                                                              │
│  scripts/                                                    │
│  ├── common/     ← Utilidades compartidas                   │
│  ├── docker/     ← Gestión de Docker                        │
│  └── gcloud/     ← Operaciones de GCloud                    │
└─────────────────────────────────────────────────────────────┘
                               │
                               │ ejecuta scripts bash
                               ↓
┌─────────────────────────────────────────────────────────────┐
│              Google Cloud Platform                           │
│                                                              │
│  Artifact Registry                                          │
│  └── {region}-docker.pkg.dev/{project}/docker-images/      │
│      └── {service}:dev-{commit}                            │
│                                                              │
│  Cloud Run                                                  │
│  └── Servicio desplegado con imagen                        │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Despliegue Completo

### Fase 1: Trigger
```
Push a master / Manual dispatch
         ↓
GitHub Actions detecta el evento
         ↓
Ejecuta .github/workflows/deploy.yml del proyecto
```

### Fase 2: Preparación
```
Checkout del código del proyecto
         ↓
Checkout de workflow-mgmt (plantillas)
         ↓
Generar tag dinámico: dev-{commit_short}
         ↓
Setup de Docker Buildx
         ↓
Setup de Google Cloud SDK
```

### Fase 3: Autenticación
```
Ejecutar scripts/gcloud/auth.sh
         ↓
Autenticar con Service Account Key
         ↓
Configurar proyecto de GCloud
```

### Fase 4: Artifact Registry
```
Ejecutar scripts/gcloud/setup-artifact-registry.sh
         ↓
Verificar si existe el repositorio
         │
         ├─ No existe → Crear repositorio
         └─ Existe → Continuar
         ↓
Configurar autenticación Docker
         ↓
Retornar URL del registry
```

### Fase 5: Build y Push
```
Ejecutar scripts/docker/build-and-push.sh
         ↓
Validar Dockerfile (scripts/docker/validate.sh)
         ↓
Build local de la imagen
         ↓
Tag con URL del registry
         ↓
Push imagen:dev-{commit}
         ↓
Tag y push imagen:latest
         ↓
Retornar URL completa de la imagen
```

### Fase 6: Deploy
```
gcloud run deploy
         ↓
Desplegar usando la imagen del paso anterior
         ↓
Configurar timeout, región, etc.
         ↓
Obtener URL del servicio desplegado
```

### Fase 7: Reporte
```
Generar resumen en GitHub Actions
         ↓
Mostrar:
  - Tag de imagen
  - URL del registry
  - URL de la imagen
  - URL del servicio
  - Ambiente
```

## 📦 Componentes Principales

### 1. Workflows Reutilizables

#### deploy-gcloud-run-with-docker.yml
- **Propósito:** Workflow completo con build, push y deploy
- **Características:**
  - Tags dinámicos basados en commit
  - Gestión automática de Artifact Registry
  - Deploy a Cloud Run
- **Uso:** Proyectos que requieren build de Docker

#### deploy-gcloud-run.yml
- **Propósito:** Deploy directo desde código fuente
- **Uso:** Proyectos simples sin necesidad de Dockerfile custom

#### test-node.yml
- **Propósito:** Ejecutar tests de Node.js
- **Uso:** Fase de testing antes de deploy

#### build-docker.yml
- **Propósito:** Solo build de imagen (sin deploy)
- **Uso:** Proyectos que separan build de deploy

### 2. Scripts Bash

#### common/
- **logger.sh:** Sistema de logging con colores
  - `log_info()`, `log_success()`, `log_warning()`, `log_error()`, `log_step()`
- **validate-env.sh:** Validación de variables de entorno
  - `validate_env_var()`, `validate_required_envs()`

#### docker/
- **validate.sh:** Validación de Dockerfile y contexto
  - `validate_dockerfile()`, `validate_build_context()`
- **build.sh:** Build de imágenes Docker
  - `docker_build()`
- **build-and-push.sh:** Build y push a registry
  - `docker_push()`, `docker_tag_image()`, `docker_build_and_push()`

#### gcloud/
- **auth.sh:** Autenticación con Google Cloud
  - `gcloud_auth()`
- **deploy.sh:** Deploy a Cloud Run
  - `deploy_to_cloud_run()`, `deploy_image_to_cloud_run()`
- **setup-artifact-registry.sh:** Gestión de Artifact Registry
  - `artifact_registry_exists()`, `create_artifact_registry()`, `configure_docker_auth()`, `ensure_artifact_registry()`

## 🔐 Seguridad

### Service Account
- **Usuario:** devops-bot-oxicore
- **Permisos mínimos necesarios:**
  - Cloud Run Admin
  - Artifact Registry Administrator
  - Storage Admin
  - Service Account User

### Secrets Management
- Secrets almacenados en GitHub (nivel repositorio)
- Secrets separados por ambiente (test/prod)
- No se exponen en logs

### Environments
- Protección de ambiente `prod` con reviewers
- Límite de branches que pueden desplegar

## 📊 Nomenclatura de Imágenes

### Formato del Tag
```
dev-{commit_short_sha}
```

### Ejemplo Completo
```
us-central1-docker.pkg.dev/apueston-test/docker-images/metabet-backend:dev-a1b2c3d
│                           │              │              │               │
│                           │              │              │               └─ Tag
│                           │              │              └─ Nombre del servicio
│                           │              └─ Nombre del registry
│                           └─ Proyecto de GCloud
└─ Región y dominio
```

### Tags Especiales
- `dev-{commit}`: Tag específico del commit
- `latest`: Siempre apunta al último deploy exitoso

## 🎛️ Configuración por Ambiente

### Test
```yaml
project_id: apueston-test
environment: test
secret: GCLOUD_SA_KEY_TEST
```

### Production
```yaml
project_id: apueston-admin
environment: prod
secret: GCLOUD_SA_KEY_PROD
```

## 🔌 Extensibilidad

### Agregar Nuevo Workflow Reutilizable
1. Crear archivo en `.github/workflows/`
2. Definir `on: workflow_call`
3. Documentar inputs, secrets y outputs
4. Usar scripts bash existentes
5. Actualizar documentación

### Agregar Nuevo Script
1. Crear en `scripts/{categoría}/`
2. Usar `set -euo pipefail`
3. Source de `logger.sh` y `validate-env.sh`
4. Documentar funciones
5. Exportar funciones si es necesario
6. Hacer ejecutable: `chmod +x`

### Agregar Nuevo Proyecto
1. Crear workflow en el proyecto usando plantillas
2. Configurar secrets
3. Configurar environments
4. (Opcional) Crear config en `config/{proyecto}/`

## 🚀 Escalabilidad

### Múltiples Proyectos
- Cada proyecto tiene su propio workflow
- Todos usan las mismas plantillas centralizadas
- Configuración específica por inputs

### Múltiples Ambientes
- Sistema soporta N ambientes
- Solo requiere configurar nuevo secret y environment

### Múltiples Regiones
- Cambiar input `region` en el workflow
- Scripts son agnósticos a la región

## 📈 Métricas y Monitoreo

### Disponibles en GitHub Actions
- Duración de cada job
- Éxito/fallo de despliegues
- Historial de despliegues

### Summary de Cada Deploy
- Tag de imagen generado
- URL del registry
- URL de la imagen completa
- URL del servicio desplegado
- Ambiente

## 🔮 Roadmap

### Fase 1 (Actual - PoC)
- [x] Workflows básicos
- [x] Scripts bash agnósticos
- [x] Tags dinámicos
- [x] Gestión de Artifact Registry
- [x] Deploy a Cloud Run
- [x] PoC con metabet-backend

### Fase 2 (Próxima)
- [ ] Tests automáticos integrados
- [ ] Validación de código (linting)
- [ ] Smoke tests post-deploy

### Fase 3 (Futuro)
- [ ] Rollback automático
- [ ] Canary deployments
- [ ] Notificaciones (Slack/Email)
- [ ] Métricas de deployment
- [ ] Soporte para Cloud Functions
- [ ] Soporte para GKE

## 🤝 Mantenimiento

### Actualizar Plantillas
```bash
# Los cambios en workflow-mgmt afectan a todos los proyectos
cd workflow-mgmt
git checkout -b feature/nueva-funcionalidad
# hacer cambios
git commit -m "feat: agregar nueva funcionalidad"
git push
# crear PR y mergear a main
```

### Versionado
- Branch `main`: Versión estable
- Tags: `v1.0.0`, `v1.1.0`, etc.
- Proyectos pueden fijar versión: `@v1.0.0` o usar `@main`

### Testing de Plantillas
- Cambios probados primero en branch feature
- PoC validado antes de aplicar a otros proyectos
- Documentación actualizada con cada cambio

---

**Mantenido por:** CPEL-SAC
**Usuario de ejecución:** devops-bot-oxicore
