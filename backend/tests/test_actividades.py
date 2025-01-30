import pytest
from httpx import AsyncClient
from main import app
from models.usuario import TipoUsuario

# Fixture para el event loop
@pytest.fixture(scope="session")
def event_loop():
    import asyncio
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    yield loop
    loop.close()

# Fixture para crear profesor y obtener token
@pytest.fixture(scope="module")
async def profesor_token():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # Crear profesor
        response = await ac.post(
            "/api/v1/registro",
            json={
                "email": "profesorr@test.com",
                "nombre": "Test",
                "apellidos": "Profesor",
                "tipo_usuario": "Profesor",
                "password": "testpass123",
            }
        )
        assert response.status_code == 200
        
        # Login y obtener token
        response = await ac.post(
            "/api/v1/login",
            data={
                "username": "profesorr@test.com",
                "password": "testpass123"
            }
        )
        assert response.status_code == 200
        return response.json()["access_token"]

# Fixture para crear asignatura
@pytest.fixture(scope="module")
async def asignatura_id(profesor_token):
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {profesor_token}"},
            json={
                "nombre": "Test Asignatura",
                "descripcion": "Descripción de prueba"
            }
        )
        assert response.status_code == 201
        return response.json()["id"]

@pytest.mark.asyncio
async def test_registro_profesor():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/registro",
            json={
                "email": "profesor2@test.com",
                "nombre": "Test2",
                "apellidos": "Profesor2",
                "tipo_usuario": "Profesor",
                "password": "testpass123",
            }
        )
        assert response.status_code == 200
        assert "email" in response.json()

@pytest.mark.asyncio
async def test_login_profesor():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/login",
            data={
                "username": "profesor2@test.com",
                "password": "testpass123"
            }
        )
        assert response.status_code == 200
        token = response.json()["access_token"]
        assert token is not None
        
        # Borrar el profesor
        
        # Obtener el ID del profesor
        response = await ac.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 200
        profesor_id = response.json()["id"]
        response = await ac.delete(
            f"/api/v1/{profesor_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 204

@pytest.mark.asyncio
async def test_crear_y_borrar_asignatura():
    # Primero creamos un profesor
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # Registro
        response = await ac.post(
            "/api/v1/registro",
            json={
                "email": "profesor3@test.com",
                "nombre": "Test3",
                "apellidos": "Profesor3",
                "tipo_usuario": "Profesor",
                "password": "testpass123",
            }
        )
        assert response.status_code == 200
        
        # Login
        response = await ac.post(
            "/api/v1/login",
            data={
                "username": "profesor3@test.com",
                "password": "testpass123"
            }
        )
        assert response.status_code == 200
        token = response.json()["access_token"]
        
        # Crear asignatura
        response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "nombre": "Test Asignatura",
                "descripcion": "Descripción de prueba"
            }
        )
        assert response.status_code == 200
        asignatura_id = response.json()["id"]
        
        # Obtener el ID del profesor
        response = await ac.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 200
        profesor_id = response.json()["id"]
        
        # Borrar asignatura antes de borrar el profesor
        response = await ac.delete(
            f"/api/v1/asignaturas/{asignatura_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        
        # Ahora sí podemos borrar el profesor
        response = await ac.delete(
            f"/api/v1/{profesor_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 204

@pytest.mark.asyncio
async def test_crear_actividad():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # Crear profesor y obtener token
        response = await ac.post(
            "/api/v1/registro",
            json={
                "email": "profesor4@test.com",
                "nombre": "Test4",
                "apellidos": "Profesor4",
                "tipo_usuario": "Profesor",
                "password": "testpass123",
            }
        )
        assert response.status_code == 200
        
        response = await ac.post(
            "/api/v1/login",
            data={
                "username": "profesor4@test.com",
                "password": "testpass123"
            }
        )
        assert response.status_code == 200
        token = response.json()["access_token"]
        
        # Crear asignatura
        response = await ac.post(
            "/api/v1/asignaturas/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "nombre": "Test Asignatura",
                "descripcion": "Descripción de prueba"
            }
        )
        assert response.status_code == 200
        asignatura_id = response.json()["id"]
        
        # Crear actividad
        response = await ac.post(
            "/api/v1/actividades/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "titulo": "Test Actividad",
                "descripcion": "Descripción de la actividad",
                "fecha_entrega": "2024-12-31T23:59:59",
                "asignatura_id": asignatura_id
            }
        )
        assert response.status_code == 200
        assert response.json()["titulo"] == "Test Actividad"
        
        # Obtener el ID de la actividad
        actividad_id = response.json()["id"]
        # Borrar la actividad
        response = await ac.delete(
            f"/api/v1/actividades/{actividad_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 204
        
        # Borrar la asignatura
        response = await ac.delete(
            f"/api/v1/asignaturas/{asignatura_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        

        # Borrar el profesor
        # Obtener el ID del profesor
        response = await ac.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 200
        profesor_id = response.json()["id"]
        response = await ac.delete(
            f"/api/v1/{profesor_id}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 204

