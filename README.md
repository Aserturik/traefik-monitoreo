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
   - **Limitación de tráfico**: Con `ratelimiter` prevenimos ataques DoS limitando solicitudes.
   - **Encabezados de seguridad**: Configurables para prevenir XSS, clickjacking, etc.

2. **Transformación y Procesamiento**:
   - **Modificación de encabezados**: El middleware `req-headers` añade identificadores únicos.
   - **Redirecciones**: Permite redirigir tráfico basado en patrones o condiciones.
   - **Compresión**: Mejora el rendimiento mediante compresión de respuestas.

3. **Gestión de errores**:
   - El middleware `error-pages@file` permite personalizar páginas de error.

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

### 3.4 ¿Cuál es la diferencia entre un router y un servicio en Traefik?

**Router vs. Servicio**:

- **Router**: 
  - Define **cómo y cuándo** dirigir el tráfico.
  - Se enfoca en reglas de coincidencia, middlewares y decisiones de enrutamiento.
  - Ej: `traefik.http.routers.backend.rule=Host(\`api.localhost\`)`

- **Servicio**: 
  - Define **dónde** enviar el tráfico una vez que ha sido enrutado.
  - Se centra en la configuración del balanceo de carga y los servidores de destino.
  - Ej: `traefik.http.services.backend-service.loadbalancer.server.port=3000`

En nuestra configuración, las réplicas de backend comparten el mismo servicio (`backend-service`), lo que permite el balanceo de carga automático entre ellas.

### 3.5 ¿Cómo se pueden agregar más reglas de enrutamiento para diferentes rutas?

Para agregar reglas de enrutamiento adicionales, puedes:

1. **Usar combinaciones de matchers**:
   ```yaml
   "traefik.http.routers.api-docs.rule=Host(`api.localhost`) && PathPrefix(`/docs`)"
   ```

2. **Crear routers independientes**:
   ```yaml
   - "traefik.http.routers.admin.rule=Host(`admin.localhost`)"
   - "traefik.http.routers.admin.service=admin-service"
   ```

3. **Utilizar expresiones complejas**:
   ```yaml
   "traefik.http.routers.complex.rule=Host(`example.com`) && (Path(`/api`) || PathPrefix(`/v2`))"
   ```

4. **Prioridades para rutas específicas**:
   ```yaml
   - "traefik.http.routers.specific.rule=Host(`api.localhost`) && Path(`/specific`)"
   - "traefik.http.routers.specific.priority=100"
   - "traefik.http.routers.specific.service=specific-service"
   ```

## 4. Monitoreo con Prometheus y Grafana

### 4.1 Flujo de Tráfico y Recopilación de Métricas

1. **Entrada y enrutamiento en Traefik:**
   - Las solicitudes llegan a Traefik a través del entryPoint "web" (puerto 80)
   - Traefik evalúa las reglas definidas en cada servicio para determinar el destino
   - Antes de reenviar, Traefik aplica los middlewares configurados
   - Traefik utiliza su balanceador de carga para dirigir la solicitud al contenedor correcto

2. **Exposición de métricas en Traefik:**
   - Traefik expone métricas en el entryPoint "web" configurado en `metrics.prometheus`
   - Incluye etiquetas para entryPoints y servicios para mejor análisis
   - Formato compatible con Prometheus para fácil integración

### 4.2 Visualización con Grafana

- Grafana se configura para conectarse a Prometheus como fuente de datos
- Dashboards recomendados:
  - ID 4475: Dashboard oficial de Traefik
  - ID 16763: Traefik Dashboard con métricas detalladas
  
- Métricas importantes a monitorear:
  - Solicitudes totales y códigos de estado HTTP
  - Tiempos de respuesta por servicio
  - Memoria y CPU utilizados por Traefik

## 5. Instrucciones para Ejecutar el Proyecto

### 5.1 Requisitos Previos

- **Docker**: Versión 20.10.0 o superior
- **Docker Compose**: Versión 2.0.0 o superior
- **Git**: Para clonar el repositorio (opcional)
- **Puertos disponibles**: Asegúrate de que los siguientes puertos no estén en uso:
  - 80: Traefik (HTTP)
  - 8080: Dashboard de Traefik
  - 9090: Prometheus
  - 3001: Grafana

### 5.2 Pasos para Ejecutar

1. **Clonar o descargar el repositorio**:
   ```bash
   git clone <URL-del-repositorio>
   cd traefik-monitoreo
   ```

2. **Levantar todos los servicios**:
   ```bash
   docker compose up -d
   ```
   
   Este comando iniciará en modo detached (background) todos los servicios definidos en el docker-compose.yml:
   - Traefik (reverse-proxy)
   - Node.js backend (3 instancias)
   - Nginx
   - Whoami
   - Prometheus
   - Grafana

3. **Verificar que los contenedores estén funcionando**:
   ```bash
   docker compose ps
   ```

### 5.3 Acceso a los Servicios

Una vez que los contenedores estén en ejecución, puedes acceder a los siguientes servicios:

- **Dashboard de Traefik**: [http://localhost:8080](http://localhost:8080)
- **API Backend**: [http://api.localhost](http://api.localhost)
  - Credenciales: Configuradas en el middleware `test-auth@file`
- **Nginx**: [http://nginx.localhost](http://nginx.localhost)
- **Whoami**: [http://whoami.docker.localhost](http://whoami.docker.localhost)
  - Credenciales: Configuradas en el middleware `test-auth@file`
- **Prometheus**: [http://localhost:9090](http://localhost:9090)
- **Grafana**: [http://localhost:3001](http://localhost:3001)
  - Usuario por defecto: `admin`
  - Contraseña por defecto: `admin`

> **Nota**: Para acceder a los dominios .localhost, es posible que necesites añadirlos a tu archivo hosts o usar un navegador como Chrome que resuelve estos dominios automáticamente.

### 5.4 Detener los Servicios

Para detener todos los servicios:
```bash
docker compose down
```

Para detener y eliminar volúmenes (esto eliminará los datos de Grafana):
```bash
docker compose down -v
```

### 5.5 Escalado de Servicios

Para escalar manualmente el servicio backend (además de las 3 instancias ya configuradas):
```bash
docker compose up -d --scale backend=5
```

> **Nota**: Ten en cuenta que si escalas el servicio backend, los nuevos contenedores no tendrán las labels de Traefik configuradas como las réplicas específicas en el docker-compose.yml.

### 5.6 Visualización de Logs

Para ver los logs de todos los servicios en tiempo real:
```bash
docker compose logs -f
```

Para ver los logs de un servicio específico:
```bash
docker compose logs -f <nombre-del-servicio>
```
Ejemplo: `docker compose logs -f reverse-proxy`
