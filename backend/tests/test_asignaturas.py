import pytest
from fastapi import status
from models.usuario import Usuario, TipoUsuario
from models.asignatura import Asignatura
from models.inscripcion import Inscripcion
from security import get_password_hash, create_access_token
from sqlalchemy.ext.asyncio import AsyncSession
from httpx import AsyncClient
from sqlalchemy import select
from passlib.context import CryptContext
from sqlalchemy.orm import selectinload

# Configurar el marcador de pytest para todas las pruebas asíncronas
pytestmark = pytest.mark.asyncio

# Crear instancia de CryptContext para verificar códigos de acceso
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Reutilizamos los fixtures del archivo test_usuarios.py
# Se puede hacer referencia a ellos desde conftest.py si fuera necesario

# Fixture para crear una asignatura para pruebas
@pytest.fixture
async def asignatura_profesor(db_session: AsyncSession, profesor) -> Asignatura:
    """Crea una asignatura de prueba para el profesor"""
    # Primero cargar el profesor completamente
    query = select(Usuario).where(Usuario.id == profesor.id)
    result = await db_session.execute(query)
    profesor_loaded = result.scalar_one()
    
    # Hashear el código de acceso
    hashed_codigo = pwd_context.hash("codigo123")
    
    asignatura = Asignatura(
        nombre="Asignatura Test",
        descripcion="Descripción de la asignatura de prueba",
        profesor_id=profesor_loaded.id,
        codigo_acceso=hashed_codigo
    )
    db_session.add(asignatura)
    await db_session.commit()
    await db_session.refresh(asignatura)
    
    return asignatura

# Fixture para crear inscripción de alumno en asignatura
@pytest.fixture
async def inscripcion_alumno(db_session: AsyncSession, alumno, asignatura_profesor) -> Inscripcion:
    """Crea una inscripción de un alumno en una asignatura"""
    # Primero cargar el alumno y la asignatura completamente
    query_alumno = select(Usuario).where(Usuario.id == alumno.id)
    result = await db_session.execute(query_alumno)
    alumno_loaded = result.scalar_one()
    
    query_asignatura = select(Asignatura).where(Asignatura.id == asignatura_profesor.id)
    result = await db_session.execute(query_asignatura)
    asignatura_loaded = result.scalar_one()
    
    inscripcion = Inscripcion(
        alumno_id=alumno_loaded.id,
        asignatura_id=asignatura_loaded.id
    )
    
    db_session.add(inscripcion)
    await db_session.commit()
    await db_session.refresh(inscripcion)
    
    # Cargar las relaciones de manera segura
    query = (
        select(Inscripcion)
        .where(Inscripcion.id == inscripcion.id)
        .options(
            selectinload(Inscripcion.alumno),
            selectinload(Inscripcion.asignatura).selectinload(Asignatura.profesor)
        )
    )
    result = await db_session.execute(query)
    inscripcion = result.scalar_one()
    
    return inscripcion

# Test para crear una asignatura
async def test_crear_asignatura(async_client: AsyncClient, token_profesor: str):
    """Test para verificar la creación de una asignatura por un profesor"""
    asignatura_data = {
        "nombre": "Nueva Asignatura",
        "descripcion": "Descripción de la nueva asignatura",
        "codigo_acceso": "acceso123"
    }
    
    response = await async_client.post(
        "/api/v1/asignaturas/",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json=asignatura_data
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["nombre"] == "Nueva Asignatura"
    assert data["descripcion"] == "Descripción de la nueva asignatura"
    assert "codigo_acceso" in data  # El código de acceso debe estar hasheado
    assert "profesor" in data  # Debe incluir los datos del profesor
    assert data["profesor"]["tipo_usuario"] == TipoUsuario.PROFESOR

# Test para crear una asignatura siendo alumno (debe fallar)
async def test_crear_asignatura_como_alumno(async_client: AsyncClient, token_alumno: str):
    """Test para verificar que un alumno no puede crear asignaturas"""
    asignatura_data = {
        "nombre": "Intento Asignatura",
        "descripcion": "Esta asignatura no debería crearse",
        "codigo_acceso": "acceso123"
    }
    
    response = await async_client.post(
        "/api/v1/asignaturas/",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json=asignatura_data
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "Solo los profesores pueden crear asignaturas" in response.json()["detail"]

# Test para obtener la lista de asignaturas como profesor
async def test_obtener_asignaturas_como_profesor(
    async_client: AsyncClient, 
    token_profesor: str, 
    asignatura_profesor
):
    """Test para verificar que un profesor puede obtener la lista de sus asignaturas"""
    response = await async_client.get(
        "/api/v1/asignaturas/",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Comprobar que al menos una asignatura coincide con la creada
    assert any(asig["nombre"] == "Asignatura Test" for asig in data)

# Test para obtener una asignatura específica
async def test_obtener_asignatura_por_id(
    async_client: AsyncClient, 
    token_profesor: str, 
    asignatura_profesor
):
    """Test para verificar que se puede obtener una asignatura por su ID"""
    response = await async_client.get(
        f"/api/v1/asignaturas/{asignatura_profesor.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["nombre"] == "Asignatura Test"
    assert data["descripcion"] == "Descripción de la asignatura de prueba"
    assert "profesor" in data
    assert data["profesor"]["id"] == asignatura_profesor.profesor_id

# Test para actualizar una asignatura
async def test_actualizar_asignatura(
    async_client: AsyncClient, 
    token_profesor: str, 
    asignatura_profesor,
    db_session: AsyncSession
):
    """Test para verificar que un profesor puede actualizar su asignatura"""
    # Guardar el ID explícitamente para evitar problemas con el contexto asíncrono
    asignatura_id = asignatura_profesor.id
    
    asignatura_update = {
        "nombre": "Asignatura Actualizada",
        "descripcion": "Nueva descripción actualizada",
        "codigo_acceso": "nuevoCodigo456"
    }
    
    response = await async_client.put(
        f"/api/v1/asignaturas/{asignatura_id}",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json=asignatura_update
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["nombre"] == "Asignatura Actualizada"
    assert data["descripcion"] == "Nueva descripción actualizada"
    
    # Verificar que el código de acceso ha sido actualizado y hasheado
    query = select(Asignatura).where(Asignatura.id == asignatura_id)
    result = await db_session.execute(query)
    updated_asignatura = result.scalar_one()
    assert pwd_context.verify("nuevoCodigo456", updated_asignatura.codigo_acceso)

# Test para eliminar una asignatura
async def test_eliminar_asignatura(
    async_client: AsyncClient, 
    token_profesor: str, 
    asignatura_profesor, 
    db_session: AsyncSession
):
    """Test para verificar que un profesor puede eliminar su asignatura"""
    response = await async_client.delete(
        f"/api/v1/asignaturas/{asignatura_profesor.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["message"] == "Asignatura eliminada"
    
    # Verificar que la asignatura ya no existe en la base de datos
    result = await db_session.execute(
        select(Asignatura).filter(Asignatura.id == asignatura_profesor.id)
    )
    asignatura = result.scalar_one_or_none()
    assert asignatura is None

# Test para obtener asignatura no existente
async def test_obtener_asignatura_no_existente(async_client: AsyncClient, token_profesor: str):
    """Test para verificar el manejo de IDs no existentes"""
    response = await async_client.get(
        "/api/v1/asignaturas/99999",  # ID probablemente no existente
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Asignatura no encontrada" in response.json()["detail"]

# Test para verificar que un profesor no puede modificar asignaturas de otros profesores
async def test_actualizar_asignatura_de_otro_profesor(
    async_client: AsyncClient,
    db_session: AsyncSession
):
    """Test para verificar que un profesor no puede modificar asignaturas de otro profesor"""
    # Crear un segundo profesor
    profesor2 = Usuario(
        nombre="Otro Profesor",
        apellidos="Test",
        email="otro_profesor@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.PROFESOR
    )
    db_session.add(profesor2)
    await db_session.commit()
    await db_session.refresh(profesor2)
    
    # Crear token para el segundo profesor
    token_profesor2 = create_access_token(data={"sub": "otro_profesor@test.com"})
    
    # Crear una asignatura para el segundo profesor (no para el primero como decía antes)
    hashed_codigo = pwd_context.hash("codigo123")
    asignatura = Asignatura(
        nombre="Asignatura Profesor 2",
        descripcion="Descripción de la asignatura",
        profesor_id=profesor2.id,
        codigo_acceso=hashed_codigo
    )
    db_session.add(asignatura)
    await db_session.commit()
    await db_session.refresh(asignatura)
    
    # Guardar el ID explícitamente para evitar accesos asíncronos fuera de contexto
    asignatura_id = asignatura.id
    
    # Crear un primer profesor que intentará acceder a la asignatura del segundo
    profesor1 = Usuario(
        nombre="Profesor Original",
        apellidos="Test",
        email="profesor_original@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.PROFESOR
    )
    db_session.add(profesor1)
    await db_session.commit()
    await db_session.refresh(profesor1)
    token_profesor1 = create_access_token(data={"sub": "profesor_original@test.com"})
    
    # Intento de actualizar la asignatura con el token del primer profesor
    asignatura_update = {
        "nombre": "Intento de Actualización",
        "descripcion": "Este intento debería fallar",
        "codigo_acceso": "intentoCodigo789"
    }
    
    response = await async_client.put(
        f"/api/v1/asignaturas/{asignatura_id}",
        headers={"Authorization": f"Bearer {token_profesor1}"},
        json=asignatura_update
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "No tienes permiso para modificar esta asignatura" in response.json()["detail"]

# ----- Tests de inscripción -----

# Test para inscribir un alumno en una asignatura
async def test_inscribir_alumno_en_asignatura(
    async_client: AsyncClient,
    token_alumno: str,
    asignatura_profesor: Asignatura,
    db_session: AsyncSession
):
    """Test para verificar que un alumno puede inscribirse en una asignatura"""
    # Obtener el código de acceso original (sin hashear)
    codigo_acceso_original = "codigo123"
    
    inscripcion_data = {
        "asignatura_id": asignatura_profesor.id,
        "codigo_acceso": codigo_acceso_original
    }
    
    response = await async_client.post(
        "/api/v1/inscripciones/",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json=inscripcion_data
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["asignatura_id"] == asignatura_profesor.id
    assert "alumno_id" in data
    assert "fecha_inscripcion" in data

# Test para inscribirse con código incorrecto
async def test_inscribir_alumno_codigo_incorrecto(
    async_client: AsyncClient,
    token_alumno: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar que no se puede inscribir con un código incorrecto"""
    inscripcion_data = {
        "asignatura_id": asignatura_profesor.id,
        "codigo_acceso": "codigoIncorrecto"
    }
    
    response = await async_client.post(
        "/api/v1/inscripciones/",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json=inscripcion_data
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Código de acceso incorrecto" in response.json()["detail"]

# Test para inscribir un profesor (debe fallar)
async def test_inscribir_profesor_en_asignatura(
    async_client: AsyncClient,
    token_profesor: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar que un profesor no puede inscribirse en una asignatura"""
    inscripcion_data = {
        "asignatura_id": asignatura_profesor.id,
        "codigo_acceso": "codigo123"
    }
    
    response = await async_client.post(
        "/api/v1/inscripciones/",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json=inscripcion_data
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "Solo los alumnos pueden inscribirse" in response.json()["detail"]

# Test para inscribirse en una asignatura no existente
async def test_inscribir_en_asignatura_no_existente(
    async_client: AsyncClient,
    token_alumno: str
):
    """Test para verificar que no se puede inscribir en una asignatura que no existe"""
    inscripcion_data = {
        "asignatura_id": 99999,  # ID probablemente no existente
        "codigo_acceso": "codigo123"
    }
    
    response = await async_client.post(
        "/api/v1/inscripciones/",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json=inscripcion_data
    )
    
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Asignatura no encontrada" in response.json()["detail"]

# Test para obtener la lista de asignaturas en las que está inscrito un alumno
@pytest.mark.asyncio
async def test_obtener_mis_inscripciones(
    async_client: AsyncClient,
    token_alumno: str,
    inscripcion_alumno,
    db_session: AsyncSession
):
    """Test para verificar que un alumno puede ver sus inscripciones"""
    # Guardar el nombre de la asignatura para evitar accesos asíncronos fuera de contexto
    query = select(Asignatura).where(Asignatura.id == inscripcion_alumno.asignatura_id)
    result = await db_session.execute(query)
    asignatura = result.scalar_one()
    nombre_asignatura = asignatura.nombre
    
    response = await async_client.get(
        "/api/v1/inscripciones/mis-asignaturas",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Verificar que incluye la asignatura en la que estamos inscritos
    assert any(asig["nombre"] == nombre_asignatura for asig in data)

# Test para obtener la lista de alumnos inscritos en una asignatura
async def test_obtener_alumnos_asignatura(
    async_client: AsyncClient,
    token_profesor: str,
    asignatura_profesor: Asignatura,
    inscripcion_alumno,
    db_session: AsyncSession
):
    """Test para verificar que un profesor puede ver los alumnos inscritos en su asignatura"""
    # Guardar el ID explícitamente para evitar problemas con el contexto asíncrono
    asignatura_id = asignatura_profesor.id
    
    response = await async_client.get(
        f"/api/v1/asignaturas/{asignatura_id}/alumnos",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Verificar que al menos un alumno está en la lista
    assert any(alumno["tipo_usuario"] == TipoUsuario.ALUMNO for alumno in data)

# Test para darse de baja de una asignatura
async def test_eliminar_inscripcion(
    async_client: AsyncClient,
    token_alumno: str,
    inscripcion_alumno,
    asignatura_profesor: Asignatura,
    alumno: Usuario,
    db_session: AsyncSession
):
    """Test para verificar que un alumno puede darse de baja de una asignatura"""
    # Guardar IDs explícitamente para evitar problemas con el contexto asíncrono
    asignatura_id = asignatura_profesor.id
    alumno_id = alumno.id
    
    response = await async_client.delete(
        f"/api/v1/inscripciones/{asignatura_id}?alumno_id={alumno_id}",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    assert "Inscripción eliminada" in response.json()["message"]
    
    # Verificar que la inscripción ya no existe
    result = await db_session.execute(
        select(Inscripcion).where(
            Inscripcion.alumno_id == alumno_id,
            Inscripcion.asignatura_id == asignatura_id
        )
    )
    inscripcion = result.scalar_one_or_none()
    assert inscripcion is None

# Test para exportar calificaciones en CSV
async def test_exportar_calificaciones_csv(
    async_client: AsyncClient,
    token_profesor: str,
    asignatura_profesor: Asignatura,
    inscripcion_alumno
):
    """Test para verificar que un profesor puede exportar calificaciones en CSV"""
    # Guardar el ID explícitamente para evitar problemas con el contexto asíncrono
    asignatura_id = asignatura_profesor.id
    
    response = await async_client.get(
        f"/api/v1/asignaturas/{asignatura_id}/export-csv",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    assert response.headers["content-type"] == "text/csv"
    assert "attachment; filename=calificaciones_" in response.headers["content-disposition"]
    
    # Verificar que el contenido del CSV es no vacío
    assert len(response.content) > 0
    
    # Verificar estructura básica del CSV
    content = response.content.decode("utf-8")
    lines = content.strip().split("\n")
    assert len(lines) >= 2  # Al menos debe tener el encabezado y una fila
    
    # Verificar que hay encabezados para Nombre, Apellidos, Email
    headers = lines[0].split(',')
    assert "Nombre" in headers
    assert "Apellidos" in headers
    assert "Email" in headers
    assert "Nota Media" in headers

# Test para intento de exportar CSV por un alumno (debe fallar)
async def test_exportar_calificaciones_como_alumno(
    async_client: AsyncClient,
    token_alumno: str,
    asignatura_profesor: Asignatura
):
    """Test para verificar que un alumno no puede exportar calificaciones"""
    response = await async_client.get(
        f"/api/v1/asignaturas/{asignatura_profesor.id}/export-csv",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "Solo los profesores pueden exportar" in response.json()["detail"]

# Test para exportar CSV de una asignatura que no existe
async def test_exportar_calificaciones_asignatura_no_existente(
    async_client: AsyncClient,
    token_profesor: str
):
    """Test para verificar el manejo de IDs no existentes al exportar CSV"""
    response = await async_client.get(
        "/api/v1/asignaturas/99999/export-csv",  # ID probablemente no existente
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Asignatura no encontrada" in response.json()["detail"]

# Test para exportar CSV de una asignatura de otro profesor
async def test_exportar_calificaciones_asignatura_otro_profesor(
    async_client: AsyncClient,
    db_session: AsyncSession
):
    """Test para verificar que un profesor no puede exportar CSV de asignaturas de otro profesor"""
    # Crear un segundo profesor
    profesor2 = Usuario(
        nombre="Profesor CSV",
        apellidos="Test",
        email="profesor_csv@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.PROFESOR
    )
    db_session.add(profesor2)
    await db_session.commit()
    await db_session.refresh(profesor2)
    
    # Crear token para el segundo profesor
    token_profesor2 = create_access_token(data={"sub": "profesor_csv@test.com"})
    
    # Crear una asignatura para el segundo profesor
    hashed_codigo = pwd_context.hash("codigo123")
    asignatura = Asignatura(
        nombre="Asignatura CSV",
        descripcion="Descripción de la asignatura CSV",
        profesor_id=profesor2.id,
        codigo_acceso=hashed_codigo
    )
    db_session.add(asignatura)
    await db_session.commit()
    await db_session.refresh(asignatura)
    
    # Guardar el ID explícitamente para evitar accesos asíncronos fuera de contexto
    asignatura_id = asignatura.id
    
    # Crear otro profesor para intentar acceder a la asignatura del profesor2
    profesor3 = Usuario(
        nombre="Otro Profesor CSV",
        apellidos="Test",
        email="otro_profesor_csv@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.PROFESOR
    )
    db_session.add(profesor3)
    await db_session.commit()
    await db_session.refresh(profesor3)
    token_profesor3 = create_access_token(data={"sub": "otro_profesor_csv@test.com"})
    
    # El profesor3 intenta exportar el CSV de la asignatura del profesor2
    response = await async_client.get(
        f"/api/v1/asignaturas/{asignatura_id}/export-csv",
        headers={"Authorization": f"Bearer {token_profesor3}"}
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "No tienes permiso para exportar" in response.json()["detail"] 