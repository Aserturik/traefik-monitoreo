### Archivos principales

- **`docker-compose.yml`**: Define los servicios de Docker, incluyendo Traefik, Nginx y el backend.
- **`backend/`**: Contiene el código fuente del backend Node.js y su configuración de Docker.
- **`nginx/`**: Contiene la configuración de Nginx y los archivos HTML estáticos.

---

## Servicios

### 1. **Traefik (reverse-proxy)**

Traefik actúa como proxy inverso para enrutar las solicitudes a los servicios correspondientes. También incluye middlewares para autenticación básica, limitación de velocidad y encabezados personalizados.

#### Configuración destacada:

- **Puertos expuestos**:
  - `80`: Para tráfico HTTP.
  - `8080`: Para la interfaz de administración de Traefik.
- **Middlewares**:
  - `req-headers`: Agrega encabezados personalizados (`X-Request-ID`, `X-Trace-Time`).
  - `test-auth`: Autenticación básica con usuario `alex`.
  - `ratelimiter`: Limita las solicitudes a 10 por segundo con un burst de 20.

## Flujo de Tráfico y Comunicación con Prometheus

1. **Entrada y enroutamiento en Traefik:**

   - Cuando se realiza una solicitud (por ejemplo, a `http://api.localhost`), la petición llega a Traefik a través del entrypoint configurado (como el puerto 80 para `web`).
   - Traefik evalúa las reglas definidas en cada servicio (por ejemplo, `Host(`api.localhost`)`) para determinar a cuál contenedor redirigir la solicitud.
   - Antes de reenviar, Traefik puede aplicar middlewares (como autenticación o modificación de cabeceras) configurados de forma global o específicos para cada servicio.
   - Finalmente, Traefik utiliza su balanceador de carga interno para dirigir la solicitud al contenedor correcto (por ejemplo, `node-backend` en el puerto 3000).

2. **Implementación y comunicación con Prometheus:**
   - **Exposición de métricas en Traefik:**  
     Traefik expone métricas en un endpoint (por ejemplo, `/metrics`), el cual recopila información sobre el tráfico, latencia, y errores.
   - **Scrape en Prometheus:**  
     En el archivo `prometheus.yml` se configura un _job_ que apunta a Traefik, por ejemplo:
     ```yaml
     - job_name: "traefik"
       static_configs:
         - targets: ["reverse-proxy:8080"]
       metrics_path: /metrics
     ```
     Esto permite a Prometheus conectarse al contenedor Traefik (usando el DNS interno `reverse-proxy`) y recopilar las métricas necesarias.
   - **Visualización y alertas:**  
     Con herramientas como Grafana, estas métricas se pueden visualizar en dashboards, y se pueden configurar alertas basadas en el desempeño o errores detectados.

Con esta configuración, el tráfico se enruta eficientemente a los servicios correspondientes y las métricas de Traefik se recopilan para monitorización y análisis.
