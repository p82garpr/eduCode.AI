import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_inscribir_alumno(alumno_token: str, profesor_token: str):
    async with AsyncClient(app=app, base_url="http://127.0.0.1:8000") as ac:
        # Primero crear una asignatura como profesor
        asignatura_response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {profesor_token}"},
            json={
                "nombre": "Matemáticas",
                "descripcion": "Curso de matemáticas básicas"
            }
        )
        asignatura_id = asignatura_response.json()["id"]
        
        # Luego inscribir al alumno
        response = await ac.post(
            "/api/v1/inscripciones/",
            headers={"Authorization": f"Bearer {alumno_token}"},
            json={
                "asignatura_id": asignatura_id
            }
        )
    
    assert response.status_code == 200
    data = response.json()
    assert data["asignatura_id"] == asignatura_id

@pytest.mark.asyncio
async def test_profesor_no_puede_inscribirse(profesor_token: str):
    async with AsyncClient(app=app, base_url="http://127.0.0.1:8000") as ac:
        # Intentar inscribirse como profesor
        response = await ac.post(
            "/api/v1/inscripciones/",
            headers={"Authorization": f"Bearer {profesor_token}"},
            json={
                "asignatura_id": 1
            }
        )
    
    assert response.status_code == 403

@pytest.mark.asyncio
async def test_obtener_mis_inscripciones(alumno_token: str, profesor_token: str):
    async with AsyncClient(app=app, base_url="http://127.0.0.1:8000") as ac:
        # Crear asignatura e inscribirse
        asignatura_response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {profesor_token}"},
            json={
                "nombre": "Matemáticas",
                "descripcion": "Curso de matemáticas básicas"
            }
        )
        asignatura_id = asignatura_response.json()["id"]
        
        await ac.post(
            "/api/v1/inscripciones/",
            headers={"Authorization": f"Bearer {alumno_token}"},
            json={
                "asignatura_id": asignatura_id
            }
        )
        
        # Obtener inscripciones
        response = await ac.get(
            "/api/v1/inscripciones/mis-asignaturas",
            headers={"Authorization": f"Bearer {alumno_token}"}
        )
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) > 0
    assert data[0]["asignatura"]["nombre"] == "Matemáticas" 