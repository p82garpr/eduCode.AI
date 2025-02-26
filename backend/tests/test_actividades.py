import pytest
from fastapi import status
from models.usuario import Usuario, TipoUsuario
from models.asignatura import Asignatura
from models.actividad import Actividad
from models.inscripcion import Inscripcion
from security import get_password_hash, create_access_token
from sqlalchemy.ext.asyncio import AsyncSession
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from datetime import datetime, UTC, timedelta
from passlib.context import CryptContext

pytestmark = pytest.mark.asyncio

# Configurar el contexto de encriptación para los códigos de acceso
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Fixture para crear una asignatura para pruebas
@pytest.fixture
async def asignatura_profesor(db_session: AsyncSession, profesor) -> Asignatura:
    """Crea una asignatura de prueba para el profesor"""
    # Hashear el código de acceso
    hashed_codigo = pwd_context.hash("codigo123")
    
    asignatura = Asignatura(
        nombre="Asignatura Test",
        descripcion="Descripción de prueba",
        profesor_id=profesor.id,
        codigo_acceso=hashed_codigo
    )
    db_session.add(asignatura)
    await db_session.commit()
    await db_session.refresh(asignatura)
    
    return asignatura

# Fixture para crear una actividad de prueba
@pytest.fixture
async def actividad_prueba(db_session: AsyncSession, asignatura_profesor: Asignatura) -> Actividad:
    """Crea una actividad de prueba"""
    actividad = Actividad(
        titulo="Actividad Test",
        descripcion="Descripción de la actividad de prueba",
        fecha_entrega=datetime.now(UTC).replace(microsecond=0) + timedelta(days=7),  # Fecha futura
        asignatura_id=asignatura_profesor.id,
        lenguaje_programacion="python",
        parametros_evaluacion="string"
    )
    db_session.add(actividad)
    await db_session.commit()
    await db_session.refresh(actividad)
    return actividad

# Fixture para crear inscripción de alumno en asignatura
@pytest.fixture
async def inscripcion_alumno(db_session: AsyncSession, alumno, asignatura_profesor) -> Inscripcion:
    """Crea una inscripción de un alumno en una asignatura"""
    inscripcion = Inscripcion(
        alumno_id=alumno.id,
        asignatura_id=asignatura_profesor.id
    )
    db_session.add(inscripcion)
    await db_session.commit()
    await db_session.refresh(inscripcion)
    return inscripcion

# Test para crear una actividad
async def test_crear_actividad(
    async_client: AsyncClient,
    token_profesor: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar la creación de una actividad"""
    fecha_futura = datetime.now(UTC).replace(microsecond=0) + timedelta(days=7)
    response = await async_client.post(
        "/api/v1/actividades/",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json={
            "titulo": "Nueva Actividad",
            "descripcion": "Descripción de la nueva actividad",
            "fecha_entrega": fecha_futura.isoformat(),
            "asignatura_id": asignatura_profesor.id,
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["titulo"] == "Nueva Actividad"
    assert data["asignatura_id"] == asignatura_profesor.id

# Test para obtener actividades de una asignatura
async def test_obtener_actividades_asignatura(
    async_client: AsyncClient,
    token_profesor: str,
    actividad_prueba: Actividad
):
    """Test para verificar que se pueden obtener las actividades de una asignatura"""
    response = await async_client.get(
        f"/api/v1/actividades/asignatura/{actividad_prueba.asignatura_id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(actividad["titulo"] == actividad_prueba.titulo for actividad in data)

# Test para actualizar una actividad
async def test_actualizar_actividad(
    async_client: AsyncClient,
    token_profesor: str,
    actividad_prueba: Actividad
):
    """Test para verificar que se puede actualizar una actividad"""
    fecha_futura = datetime.now(UTC).replace(microsecond=0) + timedelta(days=7)
    response = await async_client.put(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json={
            "titulo": "Actividad Actualizada",
            "descripcion": "Nueva descripción",
            "fecha_entrega": fecha_futura.isoformat(),
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["titulo"] == "Actividad Actualizada"
    assert data["descripcion"] == "Nueva descripción"

# Test para eliminar una actividad
async def test_eliminar_actividad(
    async_client: AsyncClient,
    token_profesor: str,
    actividad_prueba: Actividad
):
    """Test para verificar que se puede eliminar una actividad"""
    response = await async_client.delete(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_204_NO_CONTENT

# Tests de casos de error

async def test_crear_actividad_como_alumno(
    async_client: AsyncClient,
    token_alumno: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar que un alumno no puede crear actividades"""
    fecha_futura = datetime.now(UTC).replace(microsecond=0) + timedelta(days=7)
    response = await async_client.post(
        "/api/v1/actividades/",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json={
            "titulo": "Intento Alumno",
            "descripcion": "Esta actividad no debería crearse",
            "fecha_entrega": fecha_futura.isoformat(),
            "asignatura_id": asignatura_profesor.id,
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "Solo los profesores pueden crear actividades" in response.json()["detail"]

async def test_actualizar_actividad_otro_profesor(
    async_client: AsyncClient,
    actividad_prueba: Actividad,
    db_session: AsyncSession
):
    """Test para verificar que un profesor no puede actualizar actividades de otro profesor"""
    # Crear otro profesor
    otro_profesor = Usuario(
        nombre="Otro Profesor",
        apellidos="Test",
        email="otro.profesor@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.PROFESOR
    )
    db_session.add(otro_profesor)
    await db_session.commit()
    await db_session.refresh(otro_profesor)
    
    # Crear token para el otro profesor
    token_otro_profesor = create_access_token(data={"sub": "otro.profesor@test.com"})
    
    fecha_futura = datetime.now(UTC).replace(microsecond=0) + timedelta(days=7)
    response = await async_client.put(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_otro_profesor}"},
        json={
            "titulo": "Intento Otro Profesor",
            "descripcion": "Esta actualización no debería funcionar",
            "fecha_entrega": fecha_futura.isoformat(),
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "No tienes permiso para editar esta actividad" in response.json()["detail"]

async def test_obtener_actividad_no_existente(
    async_client: AsyncClient,
    token_profesor: str
):
    """Test para verificar el manejo de actividades no existentes"""
    response = await async_client.get(
        "/api/v1/actividades/99999",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Actividad no encontrada" in response.json()["detail"]

async def test_obtener_actividades_asignatura_no_inscrito(
    async_client: AsyncClient,
    token_alumno: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar que un alumno no puede ver actividades de una asignatura en la que no está inscrito"""
    response = await async_client.get(
        f"/api/v1/actividades/asignatura/{asignatura_profesor.id}",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "No estás inscrito en esta asignatura" in response.json()["detail"]

async def test_crear_actividad_fecha_pasada(
    async_client: AsyncClient,
    token_profesor: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar que no se puede crear una actividad con fecha de entrega en el pasado"""
    fecha_pasada = datetime.now(UTC) - timedelta(days=1)
    response = await async_client.post(
        "/api/v1/actividades/",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json={
            "titulo": "Actividad Pasada",
            "descripcion": "Esta actividad no debería crearse",
            "fecha_entrega": fecha_pasada.isoformat(),
            "asignatura_id": asignatura_profesor.id,
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    assert "fecha de entrega debe ser futura" in response.json()["detail"][0]["msg"].lower()

async def test_crear_actividad_campos_faltantes(
    async_client: AsyncClient,
    token_profesor: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar la validación de campos requeridos"""
    # Test sin título
    response = await async_client.post(
        "/api/v1/actividades/",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json={
            "descripcion": "Descripción de prueba",
            "fecha_entrega": datetime.now(UTC).replace(microsecond=0).isoformat(),
            "asignatura_id": asignatura_profesor.id,
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

async def test_actualizar_actividad_fecha_pasada(
    async_client: AsyncClient,
    token_profesor: str,
    actividad_prueba: Actividad
):
    """Test para verificar que no se puede actualizar una actividad con fecha de entrega en el pasado"""
    fecha_pasada = datetime.now(UTC) - timedelta(days=1)
    response = await async_client.put(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json={
            "titulo": "Actividad Actualizada",
            "descripcion": "Nueva descripción",
            "fecha_entrega": fecha_pasada.isoformat(),
            "lenguaje_programacion": "string",
            "parametros_evaluacion": "string"
        }
    )
    
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    assert "fecha de entrega debe ser futura" in response.json()["detail"][0]["msg"].lower()

async def test_obtener_actividad_alumno_inscrito(
    async_client: AsyncClient,
    token_alumno: str,
    actividad_prueba: Actividad,
    inscripcion_alumno: Inscripcion
):
    """Test para verificar que un alumno inscrito puede ver una actividad"""
    response = await async_client.get(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["titulo"] == actividad_prueba.titulo

async def test_obtener_actividad_alumno_no_inscrito(
    async_client: AsyncClient,
    token_alumno: str,
    actividad_prueba: Actividad
):
    """Test para verificar que un alumno no inscrito no puede ver una actividad"""
    response = await async_client.get(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "no estás inscrito" in response.json()["detail"].lower()

async def test_actualizar_actividad_sin_cambios(
    async_client: AsyncClient,
    token_profesor: str,
    actividad_prueba: Actividad
):
    """Test para verificar que se puede actualizar una actividad sin cambiar todos los campos"""
    response = await async_client.put(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json={
            "titulo": "Nuevo Título"
        }
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["titulo"] == "Nuevo Título"
    assert data["descripcion"] == actividad_prueba.descripcion  # No debería cambiar

async def test_eliminar_actividad_con_entregas(
    async_client: AsyncClient,
    token_profesor: str,
    actividad_prueba: Actividad,
    db_session: AsyncSession
):
    """Test para verificar el comportamiento al eliminar una actividad que tiene entregas"""
    # Crear una entrega para la actividad
    from models.entrega import Entrega
    entrega = Entrega(
        actividad_id=actividad_prueba.id,
        alumno_id=1,  # Asumiendo que existe un alumno con id 1
        fecha_entrega=datetime.now(UTC),
        texto_ocr="Texto de prueba"
    )
    db_session.add(entrega)
    await db_session.commit()

    response = await async_client.delete(
        f"/api/v1/actividades/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_204_NO_CONTENT

    # Verificar que la actividad y sus entregas fueron eliminadas
    query = select(Actividad).where(Actividad.id == actividad_prueba.id)
    result = await db_session.execute(query)
    assert result.scalar_one_or_none() is None 