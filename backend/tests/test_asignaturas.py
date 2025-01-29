import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_crear_asignatura(test_db, profesor_token):
    async with AsyncClient(app=app, base_url="http://127.0.0.1:8000") as ac:
        response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {await profesor_token}"},
            json={
                "nombre": "Matemáticas",
                "descripcion": "Curso de matemáticas básicas"
            }
        )
    
    assert response.status_code == 200
    data = response.json()
    assert data["nombre"] == "Matemáticas"
    assert data["descripcion"] == "Curso de matemáticas básicas"

@pytest.mark.asyncio
async def test_alumno_no_puede_crear_asignatura(test_db, alumno_token):
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {await alumno_token}"},
            json={
                "nombre": "Matemáticas",
                "descripcion": "Curso de matemáticas básicas"
            }
        )
    
    assert response.status_code == 403

@pytest.mark.asyncio
async def test_obtener_asignaturas(test_db, profesor_token):
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # Primero crear una asignatura
        await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {await profesor_token}"},
            json={
                "nombre": "Matemáticas",
                "descripcion": "Curso de matemáticas básicas"
            }
        )
        
        # Luego obtener la lista
        response = await ac.get(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {await profesor_token}"}
        )
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) > 0
    assert data[0]["nombre"] == "Matemáticas" 