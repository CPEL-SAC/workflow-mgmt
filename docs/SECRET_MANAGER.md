# Gestión de Variables de Entorno con Secret Manager

## 📋 Descripción

El sistema utiliza Google Cloud Secret Manager para gestionar las variables de entorno de manera centralizada y segura. Todas las variables se almacenan en un único secret en formato JSON.

## 🔐 Configuración Actual

### metabet-backend (apueston-test)

**Secret Name:** `metabet-backend`
**Formato:** JSON
**Ubicación:** Secret Manager de `apueston-test`
**Service Account:** `909790760606-compute@developer.gserviceaccount.com`

## 📦 Estructura del Secret

El secret contiene un JSON con todas las variables de entorno:

```json
{
  "VARIABLE_1": "valor1",
  "VARIABLE_2": "valor2",
  "FIREBASE_CREDENTIALS": "{...json...}",
  ...
}
```

## 🚀 Cómo Funciona

### Durante el Deploy

1. El workflow obtiene el secret desde Secret Manager
2. Convierte el JSON a variables de entorno
3. Despliega Cloud Run con `--set-env-vars`

### En Cloud Run

- Las variables se inyectan como environment variables
- El servicio las lee como cualquier variable de entorno normal
- No requiere cambios en el código de la aplicación

## 🛠️ Gestión de Secrets

### Ver el Secret Actual

```bash
gcloud config set project apueston-test

# Ver metadata
gcloud secrets describe metabet-backend

# Ver contenido (última versión)
gcloud secrets versions access latest --secret=metabet-backend | jq .
```

### Actualizar Variables

#### Opción 1: Desde archivo JSON local

```bash
# Crear archivo con las variables
cat > /tmp/env.json << 'EOF'
{
  "VARIABLE_1": "nuevo_valor",
  "VARIABLE_2": "otro_valor"
}
EOF

# Subir nueva versión
gcloud secrets versions add metabet-backend \
  --data-file=/tmp/env.json \
  --project=apueston-test

# Limpiar
rm /tmp/env.json
```

#### Opción 2: Extraer del Cloud Run actual

```bash
# Obtener variables actuales
gcloud run services describe metabet-backend \
  --region=us-central1 \
  --project=apueston-test \
  --format=json | \
  jq -r '.spec.template.spec.containers[0].env | map("\(.name)=\(.value)") | .[]' > /tmp/current.env

# Convertir a JSON y subir
# (usar el script setup-secret-manager.sh)
```

### Agregar/Modificar una Variable

```bash
# 1. Obtener secret actual
gcloud secrets versions access latest --secret=metabet-backend \
  --project=apueston-test > /tmp/current.json

# 2. Editar el JSON
nano /tmp/current.json
# O con jq:
jq '.NUEVA_VARIABLE = "nuevo_valor"' /tmp/current.json > /tmp/updated.json

# 3. Subir nueva versión
gcloud secrets versions add metabet-backend \
  --data-file=/tmp/updated.json \
  --project=apueston-test

# 4. Limpiar
rm /tmp/*.json

# 5. Re-desplegar para aplicar cambios
# (el próximo deploy automáticamente usará la nueva versión)
```

### Eliminar una Variable

```bash
# 1. Obtener y modificar
gcloud secrets versions access latest --secret=metabet-backend \
  --project=apueston-test | \
  jq 'del(.VARIABLE_A_ELIMINAR)' > /tmp/updated.json

# 2. Subir
gcloud secrets versions add metabet-backend \
  --data-file=/tmp/updated.json \
  --project=apueston-test

# 3. Limpiar
rm /tmp/updated.json
```

## 🔧 Scripts Disponibles

### setup-secret-manager.sh

Gestiona la creación y actualización de secrets.

```bash
# Crear/actualizar secret desde archivo .env
GCLOUD_PROJECT_ID=apueston-test \
bash scripts/gcloud/setup-secret-manager.sh \
  metabet-backend \
  /path/to/.env \
  909790760606-compute@developer.gserviceaccount.com
```

**Funciones:**
- Crea el secret si no existe
- Convierte .env a JSON automáticamente
- Sube nueva versión
- Otorga permisos al service account

## 🔐 Permisos

### Service Account de Cloud Run

El service account necesita el rol:
- `roles/secretmanager.secretAccessor`

```bash
gcloud secrets add-iam-policy-binding metabet-backend \
  --member="serviceAccount:909790760606-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=apueston-test
```

### Service Account del CI/CD

El service account que ejecuta el deploy (devops-bot-oxicore) necesita:
- `roles/secretmanager.secretAccessor` (para leer)
- `roles/secretmanager.secretVersionAdder` (para actualizar - opcional)

## 📊 Versiones de Secrets

### Ver Historial

```bash
gcloud secrets versions list metabet-backend --project=apueston-test
```

### Acceder a Versión Específica

```bash
# Versión específica
gcloud secrets versions access 1 --secret=metabet-backend --project=apueston-test

# Última versión
gcloud secrets versions access latest --secret=metabet-backend --project=apueston-test
```

### Deshabilitar/Habilitar Versión

```bash
# Deshabilitar
gcloud secrets versions disable 1 --secret=metabet-backend --project=apueston-test

# Habilitar
gcloud secrets versions enable 1 --secret=metabet-backend --project=apueston-test
```

### Eliminar Versión

```bash
gcloud secrets versions destroy 1 --secret=metabet-backend --project=apueston-test
```

## 🚦 Workflow de Deploy

El workflow automáticamente:

1. **Durante el job de Deploy (CD):**
   ```yaml
   - Se autentica con Google Cloud
   - Obtiene el secret: gcloud secrets versions access latest
   - Convierte JSON a formato --set-env-vars
   - Despliega Cloud Run con las variables
   ```

2. **Convención de nombres:**
   - El secret debe tener el mismo nombre que el servicio
   - Ejemplo: servicio `metabet-backend` → secret `metabet-backend`

## ⚠️ Consideraciones de Seguridad

### ✅ Buenas Prácticas

- Usar Secret Manager en lugar de variables en código
- Rotar secrets periódicamente
- Usar versiones para rollback
- Revisar permisos regularmente

### ⚠️ Advertencias

- No commitear archivos .env con valores reales
- No exponer secrets en logs
- Usar service accounts específicos con permisos mínimos
- Auditar accesos a secrets

## 🔄 Migración de Proyectos Existentes

### Para migrar un proyecto a Secret Manager:

1. **Extraer variables actuales:**
   ```bash
   gcloud run services describe SERVICE_NAME \
     --region=REGION \
     --project=PROJECT_ID \
     --format=json | \
     jq -r '.spec.template.spec.containers[0].env'
   ```

2. **Crear secret:**
   ```bash
   gcloud secrets create SERVICE_NAME \
     --replication-policy="automatic" \
     --project=PROJECT_ID
   ```

3. **Subir variables:**
   ```bash
   # Convertir a JSON y subir
   gcloud secrets versions add SERVICE_NAME \
     --data-file=variables.json \
     --project=PROJECT_ID
   ```

4. **Otorgar permisos:**
   ```bash
   gcloud secrets add-iam-policy-binding SERVICE_NAME \
     --member="serviceAccount:SA_EMAIL" \
     --role="roles/secretmanager.secretAccessor" \
     --project=PROJECT_ID
   ```

5. **Actualizar workflow** (ya está configurado para usar Secret Manager automáticamente)

## 📝 Ejemplo Completo

```bash
# 1. Configurar proyecto
gcloud config set project apueston-test

# 2. Ver secret actual
gcloud secrets versions access latest --secret=metabet-backend | jq .

# 3. Modificar
gcloud secrets versions access latest --secret=metabet-backend | \
  jq '.NEW_VAR = "value" | .UPDATED_VAR = "new_value"' > /tmp/updated.json

# 4. Subir
gcloud secrets versions add metabet-backend --data-file=/tmp/updated.json

# 5. Verificar
gcloud secrets versions access latest --secret=metabet-backend | \
  jq 'keys | length'

# 6. Limpiar
rm /tmp/updated.json

# 7. Deploy (automático o manual) aplicará los cambios
```

## 🆘 Troubleshooting

### Error: Permission denied

```bash
# Verificar permisos
gcloud secrets get-iam-policy metabet-backend --project=apueston-test

# Agregar permisos
gcloud secrets add-iam-policy-binding metabet-backend \
  --member="serviceAccount:EMAIL" \
  --role="roles/secretmanager.secretAccessor" \
  --project=apueston-test
```

### Error: Secret not found

```bash
# Listar secrets
gcloud secrets list --project=apueston-test

# Crear si no existe
gcloud secrets create metabet-backend \
  --replication-policy="automatic" \
  --project=apueston-test
```

### Variables no se aplican en Cloud Run

```bash
# 1. Verificar que el secret existe y tiene datos
gcloud secrets versions access latest --secret=metabet-backend --project=apueston-test

# 2. Verificar permisos del service account
gcloud secrets get-iam-policy metabet-backend --project=apueston-test

# 3. Re-desplegar el servicio
# El workflow automáticamente aplicará los cambios
```

---

**Mantenido por:** CPEL-SAC
**Última actualización:** 2025-12-23
