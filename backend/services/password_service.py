import secrets
import string
from datetime import datetime, timedelta, UTC
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from models.usuario import Usuario, PasswordResetToken
from providers.email_provider import EmailProvider
from security import get_password_hash

class PasswordService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.email_provider = EmailProvider()
    
    def generate_token(self, length=32):
        """Genera un token seguro para restablecimiento de contraseña"""
        alphabet = string.ascii_letters + string.digits
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    async def create_reset_token(self, user_email: str):
        """
        Crea un token de restablecimiento de contraseña para un usuario
        
        Args:
            user_email: Email del usuario
            
        Returns:
            tuple: (éxito, mensaje)
        """
        # Buscar usuario por email
        query = select(Usuario).where(Usuario.email == user_email)
        result = await self.db.execute(query)
        user = result.scalar_one_or_none()
        
        if not user:
            return False, "No se encontró un usuario con ese email"
        
        # Generar token
        token = self.generate_token()
        expiration = datetime.now(UTC) + timedelta(minutes=30)
        
        # Crear registro en la base de datos
        reset_token = PasswordResetToken(
            token=token,
            usuario_id=user.id,
            expira=expiration,
            utilizado=None
        )
        
        self.db.add(reset_token)
        await self.db.commit()
        
        # Enviar correo
        email_sent = await self.email_provider.send_password_reset_email(
            user.email, 
            token,
            user.nombre
        )
        
        if not email_sent:
            return False, "Error al enviar el correo electrónico"
            
        return True, "Se ha enviado un correo con instrucciones para restablecer la contraseña"
    
    async def verify_reset_token(self, token: str):
        """
        Verifica si un token de restablecimiento es válido
        
        Args:
            token: Token a verificar
            
        Returns:
            Usuario o None
        """
        # Buscar token
        now = datetime.now(UTC)
        query = select(PasswordResetToken).join(Usuario).where(
            PasswordResetToken.token == token,
            PasswordResetToken.utilizado.is_(None),
            PasswordResetToken.expira > now
        )
        result = await self.db.execute(query)
        reset_token = result.scalar_one_or_none()
        
        if not reset_token:
            return None
            
        query = select(Usuario).where(Usuario.id == reset_token.usuario_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()
    
    async def reset_password(self, token: str, new_password: str):
        """
        Restablece la contraseña de un usuario
        
        Args:
            token: Token de restablecimiento
            new_password: Nueva contraseña
            
        Returns:
            tuple: (éxito, mensaje)
        """
        # Verificar token
        user = await self.verify_reset_token(token)
        
        if not user:
            return False, "Token inválido o expirado"
        
        # Buscar el token en la base de datos
        query = select(PasswordResetToken).where(PasswordResetToken.token == token)
        result = await self.db.execute(query)
        reset_token = result.scalar_one_or_none()
        
        # Actualizar contraseña
        hashed_password = get_password_hash(new_password)
        user.contrasena = hashed_password
        
        # Marcar token como utilizado
        reset_token.utilizado = datetime.now(UTC)
        
        await self.db.commit()
        
        return True, "Contraseña actualizada correctamente" 