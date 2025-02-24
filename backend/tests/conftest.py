import sys
from pathlib import Path

# Añadir el directorio raíz al PYTHONPATH
root_dir = Path(__file__).parent.parent
sys.path.append(str(root_dir))

# Ahora podemos importar los módulos de la aplicación
import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from typing import AsyncGenerator
from database import Base, get_db
from main import app
from models.usuario import Usuario, TipoUsuario
from security import get_password_hash
import os
from dotenv import load_dotenv
import asyncio
from httpx import AsyncClient

load_dotenv()

# Configuración del motor de base de datos para testing
TEST_DATABASE_URL = "postgresql+asyncpg://admin:admin@localhost:5432/test_sistema_academico"
engine = create_async_engine(TEST_DATABASE_URL, echo=True)
TestingSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for each test case."""
    policy = asyncio.get_event_loop_policy()
    loop = policy.new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
async def test_db() -> AsyncGenerator:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    # Crear usuario profesor para pruebas
    async with TestingSessionLocal() as session:
        hashed_password = get_password_hash("password123")
        profesor = Usuario(
            email="profesor@test.com",
            contrasena=hashed_password,
            nombre="Test",
            apellidos="Profesor",
            tipo_usuario=TipoUsuario.PROFESOR
        )
        session.add(profesor)
        await session.commit()

    async def override_get_db():
        async with TestingSessionLocal() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.clear()

@pytest.fixture(scope="session")
async def client() -> AsyncClient: # type: ignore
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def profesor_token(client: AsyncClient) -> str:
    response = await client.post(
        "/api/v1/auth/login",
        data={
            "username": "profesor@test.com",
            "password": "password123"
        }
    )
    return response.json()["access_token"]

@pytest.fixture
async def alumno_token(client: AsyncClient) -> str:
    async with TestingSessionLocal() as session:
        # Crear usuario alumno
        hashed_password = get_password_hash("testpass123")
        alumno = Usuario(
            email="alumno@test.com",
            contrasena=hashed_password,
            nombre="Test",
            apellidos="Alumno",
            tipo_usuario=TipoUsuario.ALUMNO
        )
        session.add(alumno)
        await session.commit()
        
    response = await client.post(
        "/api/v1/auth/login",
        data={
            "username": "alumno@test.com",
            "password": "testpass123"
        }
    )
    return response.json()["access_token"]

# Override the get_db dependency
async def override_get_db():
    async with TestingSessionLocal() as session:
        yield session

app.dependency_overrides[get_db] = override_get_db 