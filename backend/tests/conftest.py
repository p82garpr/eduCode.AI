import sys
from pathlib import Path

# Añadir el directorio raíz al PYTHONPATH
root_dir = Path(__file__).parent.parent
sys.path.append(str(root_dir))

# Ahora podemos importar los módulos de la aplicación
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from typing import AsyncGenerator, Generator
from database import Base, get_db
from main import app
from models.usuario import Usuario, TipoUsuario
from security import get_password_hash
import os
from dotenv import load_dotenv
import asyncio

load_dotenv()

# Usar una base de datos de prueba
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL", "postgresql+asyncpg://admin:admin@localhost:5432/test_sistema_academico")

# Crear motor de base de datos de prueba
test_engine = create_async_engine(TEST_DATABASE_URL)
TestingSessionLocal = sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for each test case."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(autouse=True)
async def setup_db():
    # Crear todas las tablas
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    
    async with TestingSessionLocal() as session:
        yield session
    
    # Limpiar después de las pruebas
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest.fixture
def client() -> Generator:
    yield TestClient(app)

@pytest.fixture
async def test_db():
    async with TestingSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

@pytest.fixture
async def profesor_token(test_db: AsyncSession) -> str:
    # Crear usuario profesor
    hashed_password = get_password_hash("testpass123")
    profesor = Usuario(
        email="profesor@test.com",
        contrasena=hashed_password,
        nombre="Test",
        apellidos="Profesor",
        tipo_usuario="Profesor"
    )
    session = test_db
    session.add(profesor)
    await session.commit()
    
    # Obtener token
    client = TestClient(app)
    response = client.post("/api/v1/login", data={
        "username": "profesor@test.com",
        "password": "testpass123"
    })
    return response.json()["access_token"]

@pytest.fixture
async def alumno_token(test_db: AsyncSession) -> str:
    # Crear usuario alumno
    hashed_password = get_password_hash("testpass123")
    alumno = Usuario(
        email="alumno@test.com",
        contrasena=hashed_password,
        nombre="Test",
        apellidos="Alumno",
        tipo_usuario="Alumno"
    )
    session = test_db
    session.add(alumno)
    await session.commit()
    
    # Obtener token
    client = TestClient(app)
    response = client.post("/api/v1/login", data={
        "username": "alumno@test.com",
        "password": "testpass123"
    })
    return response.json()["access_token"]

# Override the get_db dependency
async def override_get_db():
    async with TestingSessionLocal() as session:
        yield session

app.dependency_overrides[get_db] = override_get_db 