#!/usr/bin/env python3
import os
import time
import datetime
import schedule
import logging
import importlib.util
import sys
import signal
import argparse
from pathlib import Path

# Configuración de logging
log_dir = Path(__file__).parent / "logs"
log_dir.mkdir(exist_ok=True)
log_file = log_dir / "cron.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("educode_cron")

# Importar el módulo de respaldo
backup_path = Path(__file__).parent / "backup.py"
if backup_path.exists():
    spec = importlib.util.spec_from_file_location("backup", backup_path)
    backup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(backup)
    logger.info(f"Módulo de respaldo cargado correctamente desde {backup_path}")
    # Verificar que el contenedor de Docker está disponible
    try:
        import subprocess
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}", "--filter", f"name={backup.DOCKER_CONTAINER}"],
            capture_output=True,
            text=True
        )
        if backup.DOCKER_CONTAINER in result.stdout:
            logger.info(f"Contenedor Docker {backup.DOCKER_CONTAINER} encontrado")
        else:
            logger.warning(f"¡ADVERTENCIA! Contenedor Docker {backup.DOCKER_CONTAINER} no encontrado. Los respaldos pueden fallar.")
    except Exception as e:
        logger.warning(f"Error al verificar el contenedor Docker: {str(e)}")
else:
    logger.error(f"No se encuentra el módulo de respaldo en {backup_path}")
    backup = None

# Variable para controlar la ejecución
running = True

def daily_backup():
    """Ejecuta el respaldo diario de la base de datos"""
    logger.info("Iniciando respaldo diario de la base de datos")
    try:
        if backup:
            backup_path = backup.create_backup()
            if backup_path:
                logger.info(f"Respaldo diario completado: {backup_path}")
                # Limitar a 10 respaldos diarios
                backup.cleanup_old_backups(max_backups=10)
            else:
                logger.error("Error al crear el respaldo diario")
        else:
            logger.error("Módulo de respaldo no disponible")
    except Exception as e:
        logger.exception(f"Error durante el respaldo diario: {e}")

def weekly_backup():
    """Ejecuta el respaldo semanal de la base de datos (se guarda en una carpeta especial)"""
    logger.info("Iniciando respaldo semanal de la base de datos")
    try:
        if backup:
            # Temporalmente cambiar el directorio de respaldo a 'backups/weekly'
            original_backup_dir = backup.BACKUP_DIR
            weekly_backup_dir = os.path.join(os.path.dirname(original_backup_dir), "backups/weekly")
            os.makedirs(weekly_backup_dir, exist_ok=True)
            
            # Cambiar el directorio para este respaldo
            backup.BACKUP_DIR = weekly_backup_dir
            backup_path = backup.create_backup()
            
            # Restaurar el directorio original
            backup.BACKUP_DIR = original_backup_dir
            
            if backup_path:
                logger.info(f"Respaldo semanal completado: {backup_path}")
                # Mantener solo los últimos 4 respaldos semanales
                weekly_files = sorted(os.path.join(weekly_backup_dir, f"{backup.DB_NAME}_*.sql"))
                if len(weekly_files) > 4:
                    for old_backup in weekly_files[:-4]:
                        os.remove(old_backup)
                        logger.info(f"Respaldo semanal antiguo eliminado: {old_backup}")
            else:
                logger.error("Error al crear el respaldo semanal")
        else:
            logger.error("Módulo de respaldo no disponible")
    except Exception as e:
        logger.exception(f"Error durante el respaldo semanal: {e}")

def perform_maintenance():
    """Realiza tareas generales de mantenimiento"""
    logger.info("Ejecutando tareas de mantenimiento del sistema")
    try:
        # Aquí se pueden agregar otras tareas de mantenimiento
        # Por ejemplo, limpiar archivos temporales, verificar espacio en disco, etc.
        # Esto se usará en un futuro para limpiar los respaldos antiguos por ejemplo
        logger.info("Mantenimiento completado")
    except Exception as e:
        logger.exception(f"Error durante el mantenimiento: {e}")

def signal_handler(sig, frame):
    """Manejador de señales para detener el programa de manera segura"""
    global running
    logger.info("Recibida señal de terminación, deteniendo el planificador...")
    running = False

def setup_schedule():
    """Configura las tareas programadas"""
    # Respaldo diario a las 3:00 AM
    schedule.every().day.at("03:00").do(daily_backup)
    
    # Respaldo semanal cada domingo a las 4:00 AM
    schedule.every().sunday.at("04:00").do(weekly_backup)
    
    # Mantenimiento general cada lunes a las 2:00 AM
    schedule.every().monday.at("02:00").do(perform_maintenance)
    
    logger.info("Tareas programadas configuradas")

def run_scheduler(daemon=False):
    """Ejecuta el planificador de tareas"""
    global running
    
    # Configurar el manejador de señales
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    setup_schedule()
    
    logger.info("Iniciando planificador de tareas")
    
    if not daemon:
        logger.info("Modo interactivo: Presiona Ctrl+C para salir")
        
    # Registrar hora de inicio
    start_time = datetime.datetime.now()
    logger.info(f"Planificador iniciado a las {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Mostrar próximas tareas programadas
    logger.info("Próximas tareas programadas:")
    for job in schedule.get_jobs():
        logger.info(f" - {job}")
    
    try:
        while running:
            schedule.run_pending()
            time.sleep(1)
    except Exception as e:
        logger.exception(f"Error en el bucle principal: {e}")
    finally:
        end_time = datetime.datetime.now()
        duration = end_time - start_time
        logger.info(f"Planificador detenido después de {duration}")
        logger.info("Planificador de tareas detenido")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Planificador de tareas para eduCode.AI")
    parser.add_argument("--daemon", action="store_true", help="Ejecutar en modo daemon")
    parser.add_argument("--run-backup-now", action="store_true", help="Ejecutar respaldo ahora")
    args = parser.parse_args()
    
    if args.run_backup_now:
        logger.info("Ejecutando respaldo manual")
        daily_backup()
    else:
        run_scheduler(daemon=args.daemon) 