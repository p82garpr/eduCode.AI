import pytest
from fastapi.testclient import TestClient
from main import app
import asyncio
from httpx import AsyncClient

# Fixture para el event loop
@pytest.fixture(scope="session")
def event_loop():
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
    yield loop
    loop.close()

@pytest.mark.asyncio
async def test_profesor_token():
    async with AsyncClient(app=app, base_url="http://127.0.0.1:8000") as ac:
        # Simular la creación de un usuario profesor
        response = await ac.post(
            "/api/v1/registro",
            json={
                "email": "profesorrr1@test.com",
                "password": "testpass123",
                "nombre": "Test",
                "apellidos": "Profesor",
                "tipo_usuario": "Profesor"
            }
        )
        print(response.json())
        assert response.status_code == 200

        # Ahora intenta obtener el token
        response = await ac.post(
            "/api/v1/login",
            data={
                "username": "profesorrr1@test.com",
                "password": "testpass123"
            }
        )
        assert response.status_code == 200
        assert "access_token" in response.json() 
        
#ahora borrar el usuario probandolo con un test
@pytest.mark.asyncio
async def test_borrar_usuario():
    async with AsyncClient(app=app, base_url="http://127.0.0.1:8000") as ac:
        #obtener el token del usuario profesor
        response = await ac.post(
            "/api/v1/login",
            data={
                "username": "profesorrr1@test.com",
                "password": "testpass123"
            }
        )
        assert response.status_code == 200
        token = response.json()["access_token"]
        #obtener el id del usuario profesor
        response = await ac.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 200
        id = response.json()["id"]
        
        response = await ac.delete(f"/api/v1/{id}", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 204
