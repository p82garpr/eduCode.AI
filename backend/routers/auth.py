from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from security import create_access_token, verify_password, ACCESS_TOKEN_EXPIRE_MINUTES
from sqlalchemy.orm import Session
from database import get_db
from models.usuario import Usuario
from sqlalchemy import select
from schemas.usuario import PasswordResetRequest, PasswordReset
from services.password_service import PasswordService

router = APIRouter()

@router.post("/login")
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    # Buscar usuario por email
    query = select(Usuario).where(Usuario.email == form_data.username)
    result = await db.execute(query)
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Verificar contraseña
    if not verify_password(form_data.password, user.contrasena):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Crear token de acceso
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.post("/password-reset-request", status_code=status.HTTP_200_OK)
async def request_password_reset(
    reset_request: PasswordResetRequest,
    db: Session = Depends(get_db)
):
    """
    Solicita un restablecimiento de contraseña
    
    Args:
        reset_request: Datos de solicitud con el email
        
    Returns:
        Mensaje de confirmación
    """
    password_service = PasswordService(db)
    success, message = await password_service.create_reset_token(reset_request.email)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
        
    return {"message": message}
    
@router.post("/reset-password", status_code=status.HTTP_200_OK)
async def reset_password(
    reset_data: PasswordReset,
    db: Session = Depends(get_db)
):
    """
    Restablece la contraseña utilizando un token
    
    Args:
        reset_data: Datos con el token y la nueva contraseña
        
    Returns:
        Mensaje de confirmación
    """
    password_service = PasswordService(db)
    success, message = await password_service.reset_password(reset_data.token, reset_data.new_password)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
        
    return {"message": message}
    
@router.get("/verify-reset-token/{token}", status_code=status.HTTP_200_OK)
async def verify_reset_token(
    token: str,
    db: Session = Depends(get_db)
):
    """
    Verifica si un token de restablecimiento es válido
    
    Args:
        token: Token a verificar
        
    Returns:
        Estado de validez del token
    """
    password_service = PasswordService(db)
    user = await password_service.verify_reset_token(token)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token inválido o expirado"
        )
        
    return {"valid": True, "email": user.email} 