import asyncpg
import asyncio
from dotenv import load_dotenv
import os

async def test_db_connection():
    load_dotenv()
    db_url = os.getenv("DATABASE_URL")
    print(f"URL de la base de datos: {db_url}")
    
    # Extraer partes de la URL para diagnóstico
    parts = db_url.replace("postgresql+asyncpg://", "").split("/")
    credentials = parts[0].split("@")
    user_pass = credentials[0].split(":")
    host_port = credentials[1].split(":")
    
    user = user_pass[0]
    password = user_pass[1]
    host = host_port[0]
    port = host_port[1] if len(host_port) > 1 else "5432"
    db_name = parts[1] if len(parts) > 1 else ""
    
    print(f"Usuario: {user}")
    print(f"Contraseña: {'*' * len(password)}")
    print(f"Host: {host}")
    print(f"Puerto: {port}")
    print(f"Nombre de la DB: {db_name}")
    
    # Probar conexión principal sin base de datos (solo al servidor)
    try:
        print("\n1. Probando conexión al servidor PostgreSQL...")
        conn_string = f"postgresql://{user}:{password}@{host}:{port}/postgres"
        conn = await asyncpg.connect(conn_string)
        print("✓ Conexión al servidor exitosa")
        
        # Verificar si la base de datos existe
        print("\n2. Verificando si la base de datos existe...")
        exists = await conn.fetchval(
            "SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1)",
            db_name
        )
        
        if exists:
            print(f"✓ La base de datos '{db_name}' existe")
        else:
            print(f"✗ La base de datos '{db_name}' NO existe")
            print("  Solución: Crear la base de datos con el comando:")
            print(f"  CREATE DATABASE {db_name};")
        
        await conn.close()
        
        # Intentar conectar a la base de datos específica
        if exists:
            print("\n3. Probando conexión directa a la base de datos...")
            try:
                db_conn = await asyncpg.connect(db_url.replace("postgresql+asyncpg://", "postgresql://"))
                print(f"✓ Conexión exitosa a la base de datos '{db_name}'")
                await db_conn.close()
            except Exception as e:
                print(f"✗ Error al conectar a la base de datos: {e}")
        
    except Exception as e:
        print(f"✗ Error al conectar al servidor: {e}")
        if "password authentication failed" in str(e).lower():
            print("  Problema: Autenticación fallida - Usuario o contraseña incorrectos")
        elif "role" in str(e).lower() and "does not exist" in str(e).lower():
            print(f"  Problema: El usuario '{user}' no existe")
            print("  Solución: Crear el usuario con el comando:")
            print(f"  CREATE USER {user} WITH PASSWORD '{password}';")
            print(f"  ALTER USER {user} WITH SUPERUSER;")
        else:
            print(f"  Problema desconocido. Revisa la configuración de PostgreSQL")

if __name__ == "__main__":
    asyncio.run(test_db_connection()) 