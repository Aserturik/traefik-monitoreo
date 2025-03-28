
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

#### Comando de ejecución:
```bash
traefik --api.insecure=true --providers.docker --accesslog=true --accesslog.filepath=/dev/stdout --accesslog.format=json