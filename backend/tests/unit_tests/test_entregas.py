import pytest
from fastapi import status
from models.usuario import Usuario, TipoUsuario
from models.asignatura import Asignatura
from models.actividad import Actividad
from models.entrega import Entrega
from models.inscripcion import Inscripcion
from security import get_password_hash, create_access_token
from sqlalchemy.ext.asyncio import AsyncSession
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from datetime import datetime, timedelta, UTC
import io
from passlib.context import CryptContext
from PIL import Image, ImageDraw, ImageFont
import numpy as np

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
        descripcion="Descripción de la asignatura de prueba",
        profesor_id=profesor.id,
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
    # Cargar el alumno de forma segura
    stmt = select(Usuario).where(Usuario.id == alumno.id)
    result = await db_session.execute(stmt)
    alumno_loaded = result.scalar_one()
    
    # Crear la inscripción con los IDs ya cargados
    inscripcion = Inscripcion(
        alumno_id=alumno_loaded.id,
        asignatura_id=asignatura_profesor.id
    )
    
    db_session.add(inscripcion)
    await db_session.commit()
    
    # Recargar la inscripción con todas sus relaciones
    stmt = select(Inscripcion).options(
        selectinload(Inscripcion.alumno),
        selectinload(Inscripcion.asignatura)
    ).where(Inscripcion.id == inscripcion.id)
    result = await db_session.execute(stmt)
    return result.scalar_one()

# Fixture para crear una actividad de prueba
@pytest.fixture
async def actividad_prueba(db_session: AsyncSession, asignatura_profesor: Asignatura) -> Actividad:
    """Crea una actividad de prueba"""
    actividad = Actividad(
        titulo="Actividad Test",
        descripcion="Descripción de la actividad de prueba",
        fecha_entrega=datetime.now(UTC) + timedelta(days=7),
        asignatura_id=asignatura_profesor.id,
        lenguaje_programacion="Python",
        parametros_evaluacion="Correctitud del código, Eficiencia"
    )
    db_session.add(actividad)
    await db_session.commit()
    await db_session.refresh(actividad)
    return actividad

# Fixture para crear una entrega de prueba
@pytest.fixture
async def entrega_prueba(
    db_session: AsyncSession, 
    actividad_prueba: Actividad, 
    alumno: Usuario,
    inscripcion_alumno: Inscripcion
) -> Entrega:
    """Crea una entrega de prueba"""
    # Crear una imagen de prueba
    imagen_prueba = b"Contenido de imagen simulada"
    
    entrega = Entrega(
        texto_ocr="def suma(a, b):\n    return a + b",
        actividad_id=actividad_prueba.id,
        alumno_id=alumno.id,
        fecha_entrega=datetime.now(UTC),
        calificacion=None,
        comentarios=None,
        imagen=imagen_prueba,
        tipo_imagen="image/jpeg",
        nombre_archivo="test.jpg"
    )
    db_session.add(entrega)
    await db_session.commit()
    await db_session.refresh(entrega)
    return entrega

# Test para crear una entrega
async def test_crear_entrega(
    async_client: AsyncClient,
    token_alumno: str,
    actividad_prueba: Actividad,
    inscripcion_alumno: Inscripcion
):
    """Test para verificar la creación de una entrega"""
    # Crear una imagen JPEG válida usando PIL
    img = Image.new('RGB', (60, 30), color = 'red')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)

    files = {
        "imagen": ("test.jpg", img_bytes, "image/jpeg"),
    }
    data = {
        "textoOcr": "def suma(a, b):\n    return a + b"
    }
    
    response = await async_client.post(
        f"/api/v1/entregas/{actividad_prueba.id}/entrega",
        headers={"Authorization": f"Bearer {token_alumno}"},
        files=files,
        data=data
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["texto_ocr"] == "def suma(a, b):\n    return a + b"
    assert data["actividad_id"] == actividad_prueba.id
    assert "fecha_entrega" in data

# Test para obtener entregas de una actividad como profesor
async def test_obtener_entregas_actividad(
    async_client: AsyncClient,
    token_profesor: str,
    entrega_prueba: Entrega,
    actividad_prueba: Actividad
):
    """Test para verificar que un profesor puede obtener las entregas de una actividad"""
    response = await async_client.get(
        f"/api/v1/entregas/actividad/{actividad_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(entrega["id"] == entrega_prueba.id for entrega in data)

# Test para calificar una entrega
async def test_calificar_entrega(
    async_client: AsyncClient,
    token_profesor: str,
    entrega_prueba: Entrega
):
    """Test para verificar que un profesor puede calificar una entrega"""
    calificacion_data = {
        "calificacion": 9.5,
        "comentarios": "Excelente trabajo"
    }
    
    response = await async_client.patch(
        f"/api/v1/entregas/{entrega_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"},
        json=calificacion_data
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["calificacion"] == 9.5
    assert data["comentarios"] == "Excelente trabajo"

# Test para obtener imagen de una entrega
async def test_obtener_imagen_entrega(
    async_client: AsyncClient,
    token_profesor: str,
    entrega_prueba: Entrega
):
    """Test para verificar que se puede obtener la imagen de una entrega"""
    response = await async_client.get(
        f"/api/v1/entregas/imagen/{entrega_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    assert response.headers["content-type"].startswith("image/")
    assert len(response.content) > 0

# Test para obtener entregas de un alumno en una asignatura
async def test_obtener_entregas_alumno_asignatura(
    async_client: AsyncClient,
    token_profesor: str,
    entrega_prueba: Entrega,
    alumno: Usuario,
    asignatura_profesor: Asignatura
):
    """Test para verificar que se pueden obtener las entregas de un alumno en una asignatura"""
    response = await async_client.get(
        f"/api/v1/entregas/alumno/{alumno.id}/asignatura/{asignatura_profesor.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(entrega["id"] == entrega_prueba.id for entrega in data)

# Test para evaluar una entrega con Gemini
async def test_evaluar_entrega_gemini(
    async_client: AsyncClient,
    token_profesor: str,
    entrega_prueba: Entrega
):
    """Test para verificar que se puede evaluar una entrega usando Gemini"""
    response = await async_client.put(
        f"/api/v1/entregas/evaluar-texto/{entrega_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "comentarios" in data
    assert "calificacion" in data

# Test para obtener una entrega específica
async def test_obtener_entrega(
    async_client: AsyncClient,
    token_profesor: str,
    entrega_prueba: Entrega
):
    """Test para verificar que se puede obtener una entrega específica"""
    response = await async_client.get(
        f"/api/v1/entregas/{entrega_prueba.id}",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == entrega_prueba.id
    assert "texto_ocr" in data
    assert "fecha_entrega" in data

# Tests de casos de error

async def test_crear_entrega_sin_autorizacion(
    async_client: AsyncClient,
    actividad_prueba: Actividad
):
    """Test para verificar que no se puede crear una entrega sin autorización"""
    imagen_content = b"Contenido de imagen simulada"
    imagen_file = io.BytesIO(imagen_content)
    
    files = {
        "imagen": ("test.jpg", imagen_file, "image/jpeg"),
    }
    data = {
        "textoOcr": "def suma(a, b):\n    return a + b"
    }
    
    response = await async_client.post(
        f"/api/v1/entregas/{actividad_prueba.id}/entrega",
        files=files,
        data=data
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

async def test_calificar_entrega_como_alumno(
    async_client: AsyncClient,
    token_alumno: str,
    entrega_prueba: Entrega
):
    """Test para verificar que un alumno no puede calificar entregas"""
    calificacion_data = {
        "calificacion": 9.5,
        "comentarios": "Intento de calificación"
    }
    
    response = await async_client.patch(
        f"/api/v1/entregas/{entrega_prueba.id}",
        headers={"Authorization": f"Bearer {token_alumno}"},
        json=calificacion_data
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "Solo los profesores pueden calificar entregas" in response.json()["detail"]

async def test_obtener_entrega_no_existente(
    async_client: AsyncClient,
    token_profesor: str
):
    """Test para verificar el manejo de entregas no existentes"""
    response = await async_client.get(
        "/api/v1/entregas/99999",
        headers={"Authorization": f"Bearer {token_profesor}"}
    )
    
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Entrega no encontrada" in response.json()["detail"]

async def test_obtener_entregas_alumno_otro_alumno(
    async_client: AsyncClient,
    token_alumno: str,
    profesor: Usuario,
    asignatura_profesor: Asignatura
):
    """Test para verificar que un alumno no puede ver las entregas de otro alumno"""
    response = await async_client.get(
        f"/api/v1/entregas/alumno/{profesor.id}/asignatura/{asignatura_profesor.id}",
        headers={"Authorization": f"Bearer {token_alumno}"}
    )
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "No tienes permiso" in response.json()["detail"]

async def test_crear_entrega_sin_inscripcion(
    async_client: AsyncClient,
    db_session: AsyncSession,
    asignatura_profesor: Asignatura,
    actividad_prueba: Actividad
):
    """Verifica que un alumno no inscrito no pueda crear una entrega"""
    # Crear un alumno no inscrito
    alumno_no_inscrito = Usuario(
        nombre="AlumnoNoInscrito",
        apellidos="Test",
        email="alumno_no_inscrito@test.com",
        contrasena=get_password_hash("testpassword"),
        tipo_usuario=TipoUsuario.ALUMNO
    )
    db_session.add(alumno_no_inscrito)
    await db_session.commit()
    await db_session.refresh(alumno_no_inscrito)
    token_no_inscrito = create_access_token(data={"sub": alumno_no_inscrito.email})

    # Intentar crear una entrega
    img = Image.new('RGB', (60, 30), color='blue')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    files = {"imagen": ("test.jpg", img_bytes, "image/jpeg")}
    data = {"textoOcr": "print('Hola mundo')"}
    response = await async_client.post(
        f"/api/v1/entregas/{actividad_prueba.id}/entrega",
        headers={"Authorization": f"Bearer {token_no_inscrito}"},
        files=files,
        data=data
    )

    assert response.status_code in (status.HTTP_403_FORBIDDEN, status.HTTP_400_BAD_REQUEST)

async def test_crear_entrega_actividad_vencida(
    async_client: AsyncClient,
    db_session: AsyncSession,
    alumno: Usuario,
    asignatura_profesor: Asignatura
):
    """Verifica que no se pueda crear una entrega para una actividad vencida"""
    # Crear una actividad con fecha de entrega pasada
    actividad_vencida = Actividad(
        titulo="Actividad Vencida",
        descripcion="No se debe permitir entrega",
        fecha_entrega=datetime.now(UTC) - timedelta(days=1),
        asignatura_id=asignatura_profesor.id,
        lenguaje_programacion="Python",
        parametros_evaluacion="Correctitud"
    )
    db_session.add(actividad_vencida)
    await db_session.commit()
    await db_session.refresh(actividad_vencida)
    token_alumno = create_access_token(data={"sub": alumno.email})

    img = Image.new('RGB', (60, 30), color='green')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    files = {"imagen": ("test.jpg", img_bytes, "image/jpeg")}
    data = {"textoOcr": "print('Intento fuera de tiempo')"}
    response = await async_client.post(
        f"/api/v1/entregas/{actividad_vencida.id}/entrega",
        headers={"Authorization": f"Bearer {token_alumno}"},
        files=files,
        data=data
    )

    assert response.status_code == status.HTTP_403_FORBIDDEN


async def test_crear_entrega_duplicada(
    async_client: AsyncClient,
    token_alumno: str,
    actividad_prueba: Actividad,
    inscripcion_alumno: Inscripcion
):
    """Verifica que un alumno no pueda crear dos entregas para la misma actividad"""
    # Primera entrega
    img1 = Image.new('RGB', (60, 30), color='red')
    img_bytes1 = io.BytesIO()
    img1.save(img_bytes1, format='JPEG')
    img_bytes1.seek(0)
    files1 = {"imagen": ("test1.jpg", img_bytes1, "image/jpeg")}
    data1 = {"textoOcr": "print('Primera entrega')"}
    response1 = await async_client.post(
        f"/api/v1/entregas/{actividad_prueba.id}/entrega",
        headers={"Authorization": f"Bearer {token_alumno}"},
        files=files1,
        data=data1
    )
    assert response1.status_code == status.HTTP_200_OK

    # Segunda entrega (duplicada)
    img2 = Image.new('RGB', (60, 30), color='red')
    img_bytes2 = io.BytesIO()
    img2.save(img_bytes2, format='JPEG')
    img_bytes2.seek(0)
    files2 = {"imagen": ("test2.jpg", img_bytes2, "image/jpeg")}
    data2 = {"textoOcr": "print('Segunda entrega')"}
    response2 = await async_client.post(
        f"/api/v1/entregas/{actividad_prueba.id}/entrega",
        headers={"Authorization": f"Bearer {token_alumno}"},
        files=files2,
        data=data2
    )
    assert response2.status_code == status.HTTP_400_BAD_REQUEST
    assert "Ya existe una entrega" in response2.json()["detail"]



async def test_procesar_ocr(
    async_client: AsyncClient,
    token_alumno: str
):
    """Verifica que el sistema pueda extraer texto de imágenes mediante OCR """
    # Crear una imagen simple con texto usando PIL
    img = Image.new('RGB', (200, 60), color='white')
    d = ImageDraw.Draw(img)
    # Usar una fuente por defecto
    texto = "Hola OCR"
    d.text((10, 10), texto, fill=(0, 0, 0))
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)

    files = {"image": ("ocr_test.jpg", img_bytes, "image/jpeg")}
    response = await async_client.post(
        "/api/v1/entregas/ocr/process-azure",
        headers={"Authorization": f"Bearer {token_alumno}"},
        files=files
    )
    assert response.status_code == status.HTTP_200_OK
    ocr_text = response.json() if isinstance(response.json(), str) else response.text
    # No exigimos coincidencia exacta, pero debe contener al menos parte del texto
    assert "Hola" in ocr_text or "OCR" in ocr_text
