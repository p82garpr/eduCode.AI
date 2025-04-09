# Análisis de Pruebas de Rendimiento y Recomendaciones para RNFs

## Análisis de Resultados de Pruebas de Carga (K6)

### Configuración de la Prueba
La prueba de carga fue configurada para simular una rampa progresiva de usuarios:
```
stages: [
  { duration: '30s', target: 10 }, // Rampa hasta 10 usuarios
  { duration: '1m', target: 50 },  // Rampa hasta 50 usuarios
  { duration: '2m', target: 100 }, // Rampa hasta 100 usuarios
  { duration: '5m', target: 100 }, // Mantener 100 usuarios por 5 minutos
  { duration: '30s', target: 0 },  // Rampa de bajada
]
```

### Umbrales Definidos
- Tiempo de respuesta: El 90% de las peticiones deben completarse en menos de 5 segundos
- Tasa de errores: Menos del 10% de errores permitidos

### Comportamiento Simulado
Las pruebas simulan el comportamiento real de usuarios:
1. Autenticación (login)
2. Consulta de información de perfil
3. Obtención de lista de asignaturas
4. Consulta de actividades
5. Visualización de detalles de actividades
6. Creación de nuevas asignaturas (para profesores)

### Hallazgos Principales

1. **RNF1 (Soporte para 100 usuarios concurrentes)**
   - **✅ CUMPLIDO**: El sistema soportó exitosamente 100 usuarios concurrentes durante 5 minutos
   - La estabilidad se mantuvo incluso con el pico de carga máxima
   - No se observaron caídas del servicio o errores significativos

2. **RNF2 (Tiempo de respuesta < 2 segundos)**
   - **⚠️ PARCIALMENTE CUMPLIDO**: 
     - El umbral configurado en las pruebas fue de 5 segundos para el percentil 90 (p90)
     - Los endpoints sin procesamiento de IA cumplen con el requisito de 2 segundos
     - Los endpoints con procesamiento de IA superan este límite

### Áreas de Mejora

#### Para RNF2 (Tiempos de respuesta)
1. **Implementación de caché**:
   ```python
   # Ejemplo de implementación de caché con FastAPI
   from fastapi_cache import FastAPICache
   from fastapi_cache.backends.redis import RedisBackend
   from fastapi_cache.decorator import cache
   
   @app.on_event("startup")
   async def startup():
       redis = aioredis.from_url("redis://localhost", encoding="utf8")
       FastAPICache.init(RedisBackend(redis), prefix="fastapi-cache:")
   
   @app.get("/api/v1/asignaturas/{id}")
   @cache(expire=60)  # Caché de 1 minuto
   async def get_asignatura(id: int):
       return await obtener_asignatura_db(id)
   ```

2. **Optimización de consultas a base de datos**:
   - Revisar las consultas en `/inscripciones/mis-asignaturas-impartidas/` y `/inscripciones/mis-asignaturas`
   - Añadir índices en tablas frecuentemente consultadas
   - Utilizar consultas más específicas que minimicen la cantidad de datos transferidos

3. **Separación de endpoints de IA**:
   - Crear endpoints asíncronos para procesamiento pesado
   - Implementar sistema de colas para procesar solicitudes de OCR

#### Para RNF6 (Copias de seguridad automáticas)
Es necesario implementar un sistema de respaldo automático. Propuesta:

1. **Script de backup para PostgreSQL**:
```python
# backend/backup.py
import os
import subprocess
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuración
DB_NAME = os.getenv("POSTGRES_DB", "educode")
DB_USER = os.getenv("POSTGRES_USER", "postgres")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")
DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
BACKUP_DIR = os.getenv("BACKUP_DIR", "backups")

def create_backup():
    """Crea una copia de seguridad de la base de datos."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"{BACKUP_DIR}/backup_{DB_NAME}_{timestamp}.sql"
    
    # Asegurar que el directorio de backups existe
    os.makedirs(BACKUP_DIR, exist_ok=True)
    
    # Comando para crear el backup
    cmd = [
        "pg_dump",
        f"--dbname=postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}",
        "--format=c",  # Formato personalizado (comprimido)
        f"--file={backup_file}"
    ]
    
    try:
        subprocess.run(cmd, check=True)
        logger.info(f"Backup creado exitosamente: {backup_file}")
        return backup_file
    except subprocess.CalledProcessError as e:
        logger.error(f"Error al crear backup: {e}")
        return None

def cleanup_old_backups(days_to_keep=30):
    """Elimina backups más antiguos que el número de días especificado."""
    import time
    
    now = time.time()
    cutoff = now - (days_to_keep * 86400)
    
    count = 0
    for filename in os.listdir(BACKUP_DIR):
        if filename.startswith("backup_") and filename.endswith(".sql"):
            filepath = os.path.join(BACKUP_DIR, filename)
            if os.path.getmtime(filepath) < cutoff:
                os.remove(filepath)
                count += 1
                logger.info(f"Backup antiguo eliminado: {filepath}")
    
    logger.info(f"Se eliminaron {count} backups antiguos")

if __name__ == "__main__":
    backup_file = create_backup()
    if backup_file:
        cleanup_old_backups()
```

2. **Script para programar tareas (cron)**:
```python
# backend/cron.py
import schedule
import time
import logging
from backup import create_backup, cleanup_old_backups

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def backup_job():
    """Tarea de backup diario"""
    logger.info("Iniciando backup diario")
    create_backup()

def weekly_cleanup():
    """Tarea semanal de limpieza de backups antiguos"""
    logger.info("Iniciando limpieza semanal de backups antiguos")
    cleanup_old_backups(days_to_keep=30)

def main():
    # Programar backup diario a las 3 AM
    schedule.every().day.at("03:00").do(backup_job)
    
    # Programar limpieza semanal los domingos a las 4 AM
    schedule.every().sunday.at("04:00").do(weekly_cleanup)
    
    logger.info("Sistema de tareas programadas iniciado")
    
    while True:
        schedule.run_pending()
        time.sleep(60)

if __name__ == "__main__":
    main()
```

3. **Dependencias a instalar**:
   - Añadir `schedule` a `requirements.txt`
   - Configurar en el sistema para que se ejecute al inicio:
     ```bash
     # En systemd (Linux)
     # Crear archivo /etc/systemd/system/educode-cron.service
     [Unit]
     Description=EduCode AI Scheduled Tasks
     After=network.target postgresql.service
     
     [Service]
     User=educode
     WorkingDirectory=/path/to/educode/backend
     ExecStart=/path/to/educode/venv/bin/python cron.py
     Restart=always
     
     [Install]
     WantedBy=multi-user.target
     ```

## Próximos Pasos Recomendados

1. **Implementar sistema de caché** para mejorar tiempos de respuesta (Redis)
2. **Desplegar sistema de backup automatizado** para cumplir con RNF6
3. **Monitoreo continuo de rendimiento** usando herramientas como Prometheus + Grafana
4. **Optimizar endpoints de IA** mediante procesamiento asíncrono y sistema de colas
5. **Completar documentación técnica** para cumplir totalmente con RNF11 