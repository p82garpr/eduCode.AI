#!/usr/bin/env python3
import os
import subprocess
import datetime
import argparse
import glob
import shutil
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()

# Obtener configuración de la base de datos desde variables de entorno
# Valores predeterminados actualizados para el contenedor Docker
DB_USER = os.getenv("DB_USER", "admin")  # Cambiado de educode a admin
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "sistema_academico")
# Nombre del contenedor Docker que ejecuta PostgreSQL
DOCKER_CONTAINER = os.getenv("DOCKER_CONTAINER", "db-my")

# Directorio para almacenar los respaldos
BACKUP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backups")
os.makedirs(BACKUP_DIR, exist_ok=True)

def create_backup():
    """
    Crea un respaldo completo de la base de datos en formato SQL usando Docker
    """
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"{DB_NAME}_{timestamp}.sql"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)
    
    print(f"Intentando crear backup con usuario: {DB_USER}")
    print(f"Contenedor Docker: {DOCKER_CONTAINER}")
    print(f"Base de datos: {DB_NAME}")
    
    # Comando para respaldo usando docker exec
    docker_cmd = [
        "docker", "exec", DOCKER_CONTAINER,
        "pg_dump",
        f"--username={DB_USER}",
        "--format=plain",
        "--create",
        "--clean",
        DB_NAME
    ]
    
    try:
        # Ejecutar el comando pg_dump dentro del contenedor y guardar la salida en un archivo
        with open(backup_path, 'w') as backup_file:
            env = os.environ.copy()
            env["PGPASSWORD"] = DB_PASSWORD
            
            # Primero intentamos listar los usuarios en PostgreSQL para diagnóstico
            list_users_cmd = [
                "docker", "exec", 
                "-e", f"PGPASSWORD={DB_PASSWORD}", 
                DOCKER_CONTAINER, 
                "psql", 
                "--username=postgres", 
                "--command", "\\du"
            ]
            
            print("Listando usuarios de PostgreSQL para diagnóstico:")
            subprocess.run(list_users_cmd)
            
            # Ahora ejecutamos el backup
            result = subprocess.run(
                docker_cmd,
                stdout=backup_file,
                stderr=subprocess.PIPE,
                text=True,
                env=env
            )
        
        if result.returncode == 0:
            print(f"✅ Respaldo creado correctamente: {backup_path}")
            return backup_path
        else:
            print(f"❌ Error al crear respaldo: {result.stderr}")
            return None
    except subprocess.CalledProcessError as e:
        print(f"❌ Error al crear respaldo: {e.stderr}")
        return None
    except Exception as e:
        print(f"❌ Error inesperado: {str(e)}")
        return None

def restore_backup(backup_file):
    """
    Restaura un respaldo de la base de datos usando Docker
    """
    if not os.path.exists(backup_file):
        print(f"❌ El archivo de respaldo no existe: {backup_file}")
        return False
    
    try:
        # Copiar el archivo de respaldo al contenedor
        temp_path = f"/tmp/{os.path.basename(backup_file)}"
        copy_cmd = ["docker", "cp", backup_file, f"{DOCKER_CONTAINER}:{temp_path}"]
        
        subprocess.run(copy_cmd, check=True)
        
        # Comando para restaurar dentro del contenedor
        docker_cmd = [
            "docker", "exec", 
            "-e", f"PGPASSWORD={DB_PASSWORD}",
            DOCKER_CONTAINER,
            "psql",
            f"--username={DB_USER}",
            "--dbname=postgres",  # Conectar a postgres para poder recrear la BD
            "-f", temp_path
        ]
        
        result = subprocess.run(
            docker_cmd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Limpiar el archivo temporal
        cleanup_cmd = ["docker", "exec", DOCKER_CONTAINER, "rm", temp_path]
        subprocess.run(cleanup_cmd)
        
        print(f"✅ Respaldo restaurado correctamente desde: {backup_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error al restaurar respaldo: {e.stderr}")
        return False
    except Exception as e:
        print(f"❌ Error inesperado: {str(e)}")
        return False

def list_backups():
    """
    Lista todos los respaldos disponibles
    """
    backup_files = sorted(glob.glob(os.path.join(BACKUP_DIR, f"{DB_NAME}_*.sql")))
    
    if not backup_files:
        print("No hay respaldos disponibles.")
        return []
    
    print("\nRespaldos disponibles:")
    for i, backup_file in enumerate(backup_files, 1):
        filename = os.path.basename(backup_file)
        size = os.path.getsize(backup_file) / (1024 * 1024)  # Tamaño en MB
        date_str = filename.split('_')[1].split('.')[0]
        date = datetime.datetime.strptime(date_str, "%Y%m%d_%H%M%S").strftime("%d/%m/%Y %H:%M:%S")
        print(f"{i}. {filename} ({size:.2f} MB) - {date}")
    
    return backup_files

def cleanup_old_backups(max_backups=10):
    """
    Elimina respaldos antiguos y mantiene solo un número determinado
    """
    backup_files = sorted(glob.glob(os.path.join(BACKUP_DIR, f"{DB_NAME}_*.sql")))
    
    if len(backup_files) <= max_backups:
        return
    
    # Eliminar los respaldos más antiguos
    for old_backup in backup_files[:-max_backups]:
        os.remove(old_backup)
        print(f"🗑️ Respaldo antiguo eliminado: {os.path.basename(old_backup)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Herramienta de respaldo para eduCode.AI")
    subparsers = parser.add_subparsers(dest="command", help="Comando a ejecutar")
    
    # Comando de respaldo
    backup_parser = subparsers.add_parser("backup", help="Crear un nuevo respaldo")
    
    # Comando de restauración
    restore_parser = subparsers.add_parser("restore", help="Restaurar un respaldo")
    restore_parser.add_argument("--file", help="Archivo específico a restaurar")
    restore_parser.add_argument("--number", type=int, help="Número del respaldo a restaurar (de la lista)")
    
    # Comando de listado
    list_parser = subparsers.add_parser("list", help="Listar respaldos disponibles")
    
    # Comando de limpieza
    cleanup_parser = subparsers.add_parser("cleanup", help="Eliminar respaldos antiguos")
    cleanup_parser.add_argument("--keep", type=int, default=10, help="Número de respaldos a mantener")
    
    args = parser.parse_args()
    
    if args.command == "backup":
        backup_path = create_backup()
        if backup_path:
            # Automáticamente limpiar respaldos antiguos después de crear uno nuevo
            cleanup_old_backups()
    
    elif args.command == "restore":
        if args.file:
            restore_backup(args.file)
        elif args.number:
            backup_files = list_backups()
            if 1 <= args.number <= len(backup_files):
                restore_backup(backup_files[args.number - 1])
            else:
                print(f"❌ Número de respaldo inválido. Debe estar entre 1 y {len(backup_files)}")
        else:
            backup_files = list_backups()
            if backup_files:
                choice = input("\nIngrese el número del respaldo a restaurar (o 'q' para salir): ")
                if choice.lower() != 'q':
                    try:
                        choice_num = int(choice)
                        if 1 <= choice_num <= len(backup_files):
                            restore_backup(backup_files[choice_num - 1])
                        else:
                            print(f"❌ Número inválido. Debe estar entre 1 y {len(backup_files)}")
                    except ValueError:
                        print("❌ Entrada inválida. Debe ingresar un número.")
    
    elif args.command == "list":
        list_backups()
    
    elif args.command == "cleanup":
        cleanup_old_backups(args.keep)
    
    else:
        parser.print_help() 