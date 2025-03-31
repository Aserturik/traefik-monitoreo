## Integrantes:
  - Alex Duvan Hernández Buitrago
  - Yesid Alejandro Martinez Guerrero

# Traefik Monitoreo - Arquitectura y Configuración

## 1. Estructura del Proyecto
- `docker-compose.yml`: Define todos los servicios, incluyendo Traefik, servicios backend, Nginx, Prometheus y Grafana.
- `backend/`: Contiene el código fuente del backend Node.js y su configuración Docker.
- `nginx/`: Configuración de Nginx y archivos HTML estáticos.
- `prometheus/`: Configuración de Prometheus para monitoreo.
- `traefik/`: Archivos de configuración de Traefik (traefik.yml y middlewares.yml).

## 2. Servicios y Puertos

### 2.1 Traefik (reverse-proxy)
- **Imagen**: traefik:v2.10
- **Puertos**:
  - `80:80`: Tráfico HTTP (entryPoint "web")
  - `8080:8080`: Dashboard de administración
- **Configuración**:
  - EntryPoints: 
    - web: `:80`
    - websecure: `:443` (disponible pero no utilizado)
  - API: Habilitada en modo inseguro (accesible a través del puerto 8080)
  - Métricas Prometheus: Expuestas a través del entryPoint "web" (puerto 80)

### 2.2 Backend Node.js (3 instancias)
- **Servicios**: `backend`, `backend-replica-1`, `backend-replica-2`
- **Puerto interno**: 3000
- **URL de acceso**: `http://api.localhost`
- **Middlewares aplicados**: 
  - `test-auth@file`: Autenticación básica
  - `req-headers@file`: Manipulación de encabezados
  - `error-pages@file`: Páginas de error personalizadas

### 2.3 Nginx
- **Imagen**: nginx:alpine
- **Puerto interno**: 80
- **URL de acceso**: `http://nginx.localhost`

### 2.4 Whoami
- **Imagen**: traefik/whoami
- **URL de acceso**: `http://whoami.docker.localhost`
- **Middlewares aplicados**: 
  - `test-auth@file`: Autenticación básica
  - `req-headers@file`: Manipulación de encabezados

### 2.5 Prometheus
- **Imagen**: prom/prometheus
- **Puerto expuesto**: `9090:9090`
- **URL de acceso**: `http://localhost:9090`

### 2.6 Grafana
- **Imagen**: grafana/grafana
- **Puerto expuesto**: `3001:3000`
- **URL de acceso**: `http://localhost:3001`

## 3. Conceptos Fundamentales de Traefik

### 3.1 ¿Cómo detecta Traefik los servicios configurados en Docker Compose?

Traefik utiliza providers para descubrir servicios automáticamente. En nuestra configuración, usa el provider Docker, lo que permite:

1. **Auto-descubrimiento**: Traefik monitorea el socket de Docker (`/var/run/docker.sock`) para detectar nuevos contenedores y sus etiquetas.
2. **Etiquetas (Labels)**: Los servicios en el docker-compose.yml utilizan etiquetas como `traefik.enable=true` y `traefik.http.routers.backend.rule=Host(\`api.localhost\`)` para configurar cómo Traefik debe manejarlos.
3. **Integración automática**: No es necesario reiniciar Traefik cuando se agregan o eliminan servicios, ya que detecta estos cambios en tiempo real.

### 3.2 ¿Qué rol juegan los middlewares en la seguridad y gestión del tráfico?

Los middlewares en Traefik actúan como capas intermedias entre la solicitud entrante y el servicio de destino, permitiendo:

1. **Seguridad**:
   - **Autenticación**: Mediante `test-auth@file` controlamos el acceso con credenciales.
   - **Restricción por IP**: Con `admin-whitelist@file` limitamos el acceso a rutas administrativas solo a IPs específicas.
   - **Limitación de tráfico**: Con `ratelimiter` prevenimos ataques DoS limitando solicitudes.
   - **Encabezados de seguridad**: Configurables para prevenir XSS, clickjacking, etc.

2. **Transformación y Procesamiento**:
   - **Modificación de encabezados**: El middleware `req-headers` añade identificadores únicos como `X-Request-ID` y `X-Trace-Time`.
   - **Middleware en cadena**: `authenticated-users` combina varios middlewares para establecer flujos complejos de autenticación.
   - **Marcado de solicitudes**: `auth-marker` permite identificar usuarios autenticados mediante encabezados personalizados.
   - **Redirecciones**: Permite redirigir tráfico basado en patrones o condiciones.
   - **Compresión**: Mejora el rendimiento mediante compresión de respuestas.

3. **Gestión de errores**:
   - El middleware `error-pages@file` permite personalizar páginas de error redirigiendo a Nginx.

### 3.3 ¿Cómo se define un router en Traefik y qué parámetros son esenciales?

Un router en Traefik determina cómo se enrutan las solicitudes HTTP entrantes:

**Parámetros esenciales**:
1. **Rule (Regla)**: Define la condición para que el router maneje una solicitud. 
   ```yaml
   "traefik.http.routers.backend.rule=Host(`api.localhost`)"
   ```

2. **Service (Servicio)**: Especifica el servicio de destino.
   ```yaml
   "traefik.http.routers.backend.service=backend-service"
   ```

3. **Middlewares (opcional pero común)**: Define transformaciones a aplicar.
   ```yaml
   "traefik.http.routers.backend.middlewares=test-auth@file,req-headers@file"
   ```

4. **EntryPoints (opcional)**: Especifica los puntos de entrada por los que acepta solicitudes.

5. **Priority (opcional)**: Establece la prioridad cuando múltiples reglas coinciden.

**Routers adicionales configurados en el sistema**:

1. **Router para usuarios autenticados** (`authenticated-router`):
   - Rule: `Headers(\`X-User-Authenticated\`, \`true\`)`
   - Priority: 100 (prioridad alta)
   - Service: `backend-service@docker`
   - Uso: Procesa solicitudes de usuarios ya autenticados con middleware específico

2. **Router para rutas administrativas** (`admin-router`):
   - Rule: `PathPrefix(\`/admin\`)`
   - Priority: 200 (prioridad muy alta)
   - Service: `backend-service@docker`
   - Middlewares: Incluye `admin-whitelist@file` para restringir acceso por IP
   - Uso: Proporciona acceso protegido a endpoints administrativos

3. **Router para alta carga** (`high-load-router`):
   - Rule: `Headers(\`X-Traffic-Load\`, \`high\`)`
   - Priority: 150
   - Service: `backup-service`
   - Uso: Actúa como ruta alternativa durante momentos de alto tráfico

## 4. Balanceo de Carga y Alta Disponibilidad

### 4.1 Estrategia de balanceo de carga

El sistema implementa un balanceo de carga sofisticado a través de múltiples réplicas del servicio backend:

1. **Réplicas múltiples**: Se implementan tres instancias del servicio backend:
   - `backend`: Instancia principal
   - `backend-replica-1`: Primera réplica
   - `backend-replica-2`: Segunda réplica

2. **Servicio específico para alta carga**:
   - El servicio `backup-service` configurado en `routers.yml` distribuye tráfico entre las réplicas
   - Utiliza health checks para verificar la disponibilidad de los servicios
   ```yaml
   healthCheck:
     path: "/health"
     interval: "10s"
     timeout: "3s"
   ```

3. **Enrutamiento basado en carga**:
   - El router `high-load-router` se activa mediante el encabezado `X-Traffic-Load: high`
   - Este encabezado es establecido por el script de monitoreo `load_monitor.sh` cuando detecta alta carga
   - Prioridad intermedia (150) para asegurar un balance adecuado entre rutas administrativas y generales

## 5. Monitoreo con Prometheus y Grafana

### 5.1 Configuración de Prometheus

Prometheus está configurado para recopilar métricas de varios servicios:

1. **Intervalo de recopilación**: 15 segundos (configurado en `global.scrape_interval`)

2. **Objetivos de monitoreo**:
   - **Prometheus** (`localhost:9090`): Auto-monitoreo de Prometheus
   - **Traefik Dashboard** (`reverse-proxy:8080`): Métricas generales de Traefik
   - **Traefik HTTP** (`reverse-proxy:80`): Métricas específicas de HTTP en el punto de entrada web

3. **Integración con Traefik**:
   - Traefik expone sus métricas automáticamente gracias a la configuración en `traefik.yml`:
   ```yaml
   metrics:
     prometheus:
       entryPoint: web
       addEntryPointsLabels: true
       addServicesLabels: true
   ```

### 5.2 Visualización con Grafana

Grafana está configurado como herramienta de visualización:

1. **Persistencia de datos**: Utiliza el volumen `grafana-data` para mantener configuraciones y dashboards
2. **Puerto de acceso**: Expuesto en el puerto 3001 (`http://localhost:3001`)
3. **Configuración inicial**:
   - Usuario por defecto: admin/admin
   - Se recomienda añadir Prometheus como fuente de datos en la configuración inicial

## 6. Ficheros y Configuraciones Clave No Documentados

1. **Script de monitoreo de carga** (`backend/scripts/load_monitor.sh`):
   - Monitorea la carga del sistema y ajusta el enrutamiento dinámicamente
   - Establece el encabezado `X-Traffic-Load: high` cuando la carga supera un umbral
   - Activa el router de alta carga para distribuir tráfico a las réplicas

2. **Configuración de logs de acceso de Traefik**:
   ```yaml
   accessLog:
     filePath: "/dev/stdout"
     format: "json"
   ```
   - Permite el análisis detallado del tráfico
   - Los logs en formato JSON facilitan la integración con herramientas de análisis

3. **Páginas de error personalizadas**:
   - Servidas por Nginx a través del middleware `error-pages@file`
   - Ubicación: `nginx/html/error.html`
