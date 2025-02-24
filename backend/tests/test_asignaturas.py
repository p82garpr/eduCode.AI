import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_crear_asignatura(test_db, profesor_token):
    # Ya no necesitamos anext() porque profesor_token es una coroutine, no un generador
    token = await profesor_token
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "nombre": "Matemáticas",
                "descripcion": "Curso de matemáticas básicas"
            }
        )
    
    assert response.status_code == 200
    data = response.json()
    assert data["nombre"] == "Matemáticas"
    assert data["descripcion"] == "Curso de matemáticas básicas"
