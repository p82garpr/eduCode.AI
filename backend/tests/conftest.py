import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.pool import StaticPool
import sys
import os
import asyncio
from typing import AsyncGenerator, Generator
from httpx import AsyncClient
from sqlalchemy.orm import selectinload

# Añadir el directorio raíz al path de Python
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import Base, get_db
from main import app
from models.usuario import Usuario, TipoUsuario
from security import get_password_hash, create_access_token

# Crear base de datos en memoria para testing
SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(
    engine, 
    class_=AsyncSession, 
    autocommit=False, 
    autoflush=False
)

@pytest.fixture(scope="function")
async def db_session() -> AsyncSession:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with TestingSessionLocal() as session:
        yield session
        await session.rollback()
        await session.close()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest.fixture(scope="function")
async def async_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    async def override_get_db():
        try:
            yield db_session
        finally:
            await db_session.close()

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()

@pytest.fixture(scope="function")
def client(async_client, event_loop) -> TestClient:
    return TestClient(app)

# Fixtures para usuarios y tokens de prueba
@pytest.fixture
async def profesor(db_session: AsyncSession) -> Usuario:
    user = Usuario(
        nombre="Profesor",
        apellidos="Test",
        email="profesor@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.PROFESOR
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    # Cargar explícitamente el ID y email
    result = await db_session.execute(
        select(Usuario).filter(Usuario.email == "profesor@test.com")
    )
    return result.scalar_one()

@pytest.fixture
async def alumno(db_session: AsyncSession) -> Usuario:
    user = Usuario(
        nombre="Alumno",
        apellidos="Test",
        email="alumno@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.ALUMNO
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    # Cargar explícitamente el ID y email
    result = await db_session.execute(
        select(Usuario).filter(Usuario.email == "alumno@test.com")
    )
    return result.scalar_one()

@pytest.fixture
def token_profesor(profesor: Usuario) -> str:
    return create_access_token(data={"sub": "profesor@test.com"})

@pytest.fixture
def token_alumno(alumno: Usuario) -> str:
    return create_access_token(data={"sub": "alumno@test.com"}) 