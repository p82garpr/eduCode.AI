import pytest
from fastapi import status
import sys
import os

# Añadir el directorio raíz al path de Python
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.usuario import Usuario, TipoUsuario
from security import get_password_hash
from sqlalchemy.ext.asyncio import AsyncSession

pytestmark = pytest.mark.asyncio

@pytest.fixture
async def test_user(db_session: AsyncSession) -> Usuario:
    user = Usuario(
        nombre="Test User",
        apellidos="Test Apellidos",
        email="test@example.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.ALUMNO
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user

async def test_login_successful(client, test_user):
    response = client.post(
        "/api/v1/login",
        data={
            "username": "test@example.com",
            "password": "testpassword"
        }
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

async def test_login_incorrect_password(client, test_user):
    response = client.post(
        "/api/v1/login",
        data={
            "username": "test@example.com",
            "password": "wrongpassword"
        }
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

async def test_login_nonexistent_user(client):
    response = client.post(
        "/api/v1/login",
        data={
            "username": "nonexistent@example.com",
            "password": "testpassword"
        }
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED 