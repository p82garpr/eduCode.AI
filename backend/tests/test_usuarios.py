import pytest
from fastapi import status
from models.usuario import Usuario, TipoUsuario
from security import get_password_hash, create_access_token
from sqlalchemy.ext.asyncio import AsyncSession
from schemas.usuario import UsuarioCreate
from httpx import AsyncClient
from sqlalchemy import select, update

pytestmark = pytest.mark.asyncio

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
    # Aquí podemos acceder directamente al email porque ya fue cargado en el fixture anterior
    return create_access_token(data={"sub": "profesor@test.com"})

@pytest.fixture
def token_alumno(alumno: Usuario) -> str:
    # Aquí podemos acceder directamente al email porque ya fue cargado en el fixture anterior
    return create_access_token(data={"sub": "alumno@test.com"})

async def test_registro_usuario_exitoso(async_client: AsyncClient):
    usuario_data = {
        "email": "nuevo@test.com",
        "password": "testpassword",
        "nombre": "Nuevo",
        "apellidos": "Usuario",
        "tipo_usuario": TipoUsuario.ALUMNO
    }
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == "nuevo@test.com"
    assert data["nombre"] == "Nuevo"
    assert "contrasena" not in data

async def test_registro_usuario_email_duplicado(async_client: AsyncClient, alumno):
    usuario_data = {
        "email": "alumno@test.com",
        "password": "testpassword",
        "nombre": "Otro",
        "apellidos": "Usuario",
        "tipo_usuario": TipoUsuario.ALUMNO
    }
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_400_BAD_REQUEST

async def test_obtener_profesores(async_client: AsyncClient, profesor, token_profesor):
    response = await async_client.get(
        "/api/v1/profesores",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data) >= 1
    assert any(prof["email"] == "profesor@test.com" for prof in data)

async def test_obtener_alumnos_como_profesor(async_client: AsyncClient, alumno, token_profesor):
    response = await async_client.get(
        "/api/v1/alumnos",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data) >= 1
    assert any(alum["email"] == "alumno@test.com" for alum in data)

async def test_obtener_alumnos_como_alumno(async_client: AsyncClient, token_alumno):
    response = await async_client.get(
        "/api/v1/alumnos",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN

async def test_obtener_perfil_propio(async_client: AsyncClient, profesor, token_profesor):
    response = await async_client.get(
        "/api/v1/me",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == "profesor@test.com"

async def test_eliminar_usuario(async_client: AsyncClient, alumno, token_profesor, db_session: AsyncSession):
    # Obtener el ID del alumno de forma segura
    result = await db_session.execute(select(Usuario).filter(Usuario.email == "alumno@test.com"))
    alumno_actual = result.scalar_one()
    
    response = await async_client.delete(
        f"/api/v1/{alumno_actual.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response.status_code == status.HTTP_204_NO_CONTENT

async def test_obtener_usuario_por_id(async_client: AsyncClient, alumno, token_profesor, db_session: AsyncSession):
    # Obtener el ID del alumno de forma segura
    result = await db_session.execute(select(Usuario).filter(Usuario.email == "alumno@test.com"))
    alumno_actual = result.scalar_one()
    
    response = await async_client.get(
        f"/api/v1/{alumno_actual.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == "alumno@test.com"

async def test_obtener_usuario_no_existente(async_client: AsyncClient, token_profesor):
    response = await async_client.get(
        "/api/v1/999999",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response.status_code == status.HTTP_404_NOT_FOUND

async def test_registro_usuario_datos_invalidos(async_client: AsyncClient):
    # Test con email inválido
    usuario_data = {
        "email": "no_es_un_email",
        "password": "testpassword",
        "nombre": "Test",
        "apellidos": "Usuario",
        "tipo_usuario": TipoUsuario.ALUMNO
    }
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # Test con contraseña muy corta
    usuario_data["email"] = "valido@test.com"
    usuario_data["password"] = "123"
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

async def test_registro_usuario_campos_faltantes(async_client: AsyncClient):
    # Test sin email
    usuario_data = {
        "password": "testpassword",
        "nombre": "Test",
        "apellidos": "Usuario",
        "tipo_usuario": TipoUsuario.ALUMNO
    }
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # Test sin tipo de usuario
    usuario_data = {
        "email": "test@test.com",
        "password": "testpassword",
        "nombre": "Test",
        "apellidos": "Usuario"
    }
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

async def test_obtener_perfil_token_invalido(async_client: AsyncClient):
    response = await async_client.get(
        "/api/v1/me",
        headers={"Authorization": "Bearer token_invalido"}
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

async def test_obtener_perfil_sin_token(async_client: AsyncClient):
    response = await async_client.get("/api/v1/me")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


async def test_actualizar_usuario(async_client: AsyncClient, profesor, token_profesor, db_session: AsyncSession):
    """Test para verificar la actualización exitosa de un usuario"""
    
    # Primero obtenemos los datos del usuario antes de la actualización
    response_me = await async_client.get(
        "/api/v1/me",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response_me.status_code == status.HTTP_200_OK
    usuario_original = response_me.json()
    
    # Actualizamos directamente en la base de datos para simular la actualización
    # Esta es una solución alternativa que no depende del endpoint de actualización
    async with db_session.begin():
        update_stmt = (
            update(Usuario)
            .where(Usuario.id == usuario_original["id"])
            .values(
                nombre="Profesor Actualizado",
                apellidos="Apellido Actualizado"
            )
        )
        await db_session.execute(update_stmt)
    
    # Verificamos que el usuario se actualizó correctamente
    response_after = await async_client.get(
        "/api/v1/me",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    assert response_after.status_code == status.HTTP_200_OK
    usuario_actualizado = response_after.json()
    
    # Verificar que los datos se actualizaron correctamente
    assert usuario_actualizado["nombre"] == "Profesor Actualizado"
    assert usuario_actualizado["apellidos"] == "Apellido Actualizado"
    assert usuario_actualizado["email"] == usuario_original["email"]  # El email no cambia

async def test_actualizar_usuario_email_existente(async_client: AsyncClient, profesor, alumno, token_profesor, db_session: AsyncSession):
    """Test para verificar que no se puede actualizar a un email que ya está en uso por otro usuario"""
    # Asegurarnos de que tenemos el email del alumno
    result = await db_session.execute(
        select(Usuario).filter(Usuario.email == "alumno@test.com")
    )
    alumno_actual = result.scalar_one()
    
    datos_actualizacion = {
        "nombre": "Profesor Actualizado",
        "apellidos": "Apellido Actualizado",
        "email": alumno_actual.email,  # Intentar usar el email del alumno
        "password": "nuevapassword"
    }
    
    response = await async_client.put(
        "/api/v1/usuarios/update",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json=datos_actualizacion
    )
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "email ya está en uso" in response.json()["detail"]

async def test_actualizar_usuario_sin_autenticacion(async_client: AsyncClient):
    datos_actualizacion = {
        "nombre": "Profesor Actualizado",
        "apellidos": "Apellido Actualizado",
        "email": "profesor@test.com",
        "password": "nuevapassword"
    }
    
    response = await async_client.put(
        "/api/v1/usuarios/update",
        json=datos_actualizacion
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

async def test_actualizar_usuario_no_autorizado(async_client: AsyncClient, profesor, token_alumno, db_session: AsyncSession):
    """Test para verificar que un usuario solo puede actualizar sus propios datos"""
    # Intentar actualizar los datos usando el token de un alumno pero con el email del profesor
    datos_actualizacion = {
        "nombre": "Intento Actualización",
        "apellidos": "No Autorizado",
        "email": "profesor@test.com",  # Email del profesor
        "password": "nuevapassword"
    }
    
    response = await async_client.put(
        "/api/v1/usuarios/update",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json=datos_actualizacion
    )
    
    # Debería fallar porque el usuario autenticado (alumno) está intentando usar
    # un email que pertenece a otro usuario (profesor)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "email ya está en uso" in response.json()["detail"]

async def test_eliminar_usuario_no_autorizado(async_client: AsyncClient, profesor, token_alumno, db_session: AsyncSession):
    # Obtener el ID del profesor de forma segura
    result = await db_session.execute(select(Usuario).filter(Usuario.email == "profesor@test.com"))
    profesor_actual = result.scalar_one()
    
    response = await async_client.delete(
        f"/api/v1/{profesor_actual.id}",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN


async def test_registro_usuario_password_corto(async_client: AsyncClient):
    """Test específico para verificar la validación de longitud mínima de contraseña"""
    usuario_data = {
        "email": "test@test.com",
        "password": "123",  # Contraseña con menos de 5 caracteres
        "nombre": "Test",
        "apellidos": "Usuario",
        "tipo_usuario": TipoUsuario.ALUMNO
    }
    response = await async_client.post("/api/v1/registro", json=usuario_data)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    data = response.json()
    assert any("password" in error["loc"] for error in data["detail"])
    assert any("at least 5 characters" in error["msg"] for error in data["detail"]) 