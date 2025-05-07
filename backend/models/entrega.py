from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Float, Text, func, LargeBinary
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime, UTC

class Entrega(Base):
    __tablename__ = "entregas"
    
    id = Column(Integer, primary_key=True, index=True)
    imagen = Column(LargeBinary, nullable=True)  # Para guardar la imagen
    tipo_imagen = Column(String, nullable=True)  # Para guardar el tipo MIME de la imagen
    nombre_archivo = Column(String, nullable=True)  # Para guardar el nombre original del archivo
    comentarios = Column(String, nullable=True)
    calificacion = Column(Float, nullable=True)
    fecha_entrega = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    actividad_id = Column(Integer, ForeignKey("actividades.id"))
    alumno_id = Column(Integer, ForeignKey("usuarios.id"))
    texto_ocr = Column(String, nullable=True)  # Nuevo campo para el texto OCR
    
    # Relaciones
    actividad = relationship("Actividad", back_populates="entregas")
    alumno = relationship("Usuario", back_populates="entregas") 