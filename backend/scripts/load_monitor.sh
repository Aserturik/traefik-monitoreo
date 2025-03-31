#!/bin/bash

# Script para monitoreo de carga y activación automática del servidor de respaldo
# Este script debe ser ejecutado periódicamente (por ejemplo, con cron)

# Umbral de carga para activar el servidor de respaldo (ejemplo: 70% de CPU)
THRESHOLD=70

# Obtener la carga actual del sistema 
# En un entorno real, esto debería obtener métricas desde Prometheus o similar
CURRENT_LOAD=$(top -bn1 | grep "Cpu(s)" | \
           sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | \
           awk '{print 100 - $1}')

echo "Carga actual del sistema: $CURRENT_LOAD%"

# Si la carga supera el umbral, enviamos una solicitud con el header X-Traffic-Load: high
if (( $(echo "$CURRENT_LOAD > $THRESHOLD" | bc -l) )); then
    echo "¡Carga alta detectada! Activando servidor de respaldo..."
    
    # Simulamos tráfico con el header para activar el router high-load
    curl -H "X-Traffic-Load: high" http://api.localhost
    
    # En un sistema real, podríamos necesitar notificar a un sistema de balanceo 
    # o a Traefik directamente a través de su API
    
    echo "Servidor de respaldo activado."
else
    echo "Carga normal. No es necesario activar el servidor de respaldo."
    
    # Si necesitamos desactivar explícitamente el servidor de respaldo
    # curl -H "X-Traffic-Load: normal" http://api.localhost
fi