from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool
from dotenv import load_dotenv
import os

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

# Configurar el engine con statement_cache_size=0 y sin pooling para evitar problemas de caché de declaraciones preparadas
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    poolclass=NullPool,
    connect_args={
        "statement_cache_size": 0,  # Deshabilitar el caché de declaraciones preparadas
    }
)

# Crear el sessionmaker
AsyncSessionLocal = sessionmaker(
    engine, # Engine de la base de datos
    class_=AsyncSession, # Clase de la sesión de la base de datos
    expire_on_commit=False # No expirar la sesión en commit
)

Base = declarative_base() # Base de datos

# Dependency para obtener la sesión de base de datos
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session # Devolver la sesión, yield es como return pero para funciones async
        finally:
            await session.close() # Cerrar la sesión

# Añade esta función para crear las tablas
async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all) # Crear las tablas