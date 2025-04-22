import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

class EmailProvider:
    def __init__(self):
        self.mail_server = os.getenv("MAIL_SERVER")
        self.mail_port = int(os.getenv("MAIL_PORT"))
        self.mail_username = os.getenv("MAIL_USERNAME")
        self.mail_password = os.getenv("MAIL_PASSWORD")
        self.mail_from = os.getenv("MAIL_FROM")
        self.mail_from_name = os.getenv("MAIL_FROM_NAME")
    
    async def send_email(self, recipient_email: str, subject: str, body_html: str, body_text: str = None):
        """
        Envía un correo electrónico
        
        Args:
            recipient_email: Dirección de correo del destinatario
            subject: Asunto del correo
            body_html: Cuerpo HTML del correo
            body_text: Cuerpo de texto plano del correo (opcional)
        """
        message = MIMEMultipart("alternative")
        message["Subject"] = subject
        message["From"] = f"{self.mail_from_name} <{self.mail_from}>"
        message["To"] = recipient_email
        
        # Adjuntar partes de texto plano y HTML
        if body_text:
            part1 = MIMEText(body_text, "plain")
            message.attach(part1)
            
        part2 = MIMEText(body_html, "html")
        message.attach(part2)
        
        # Enviar email
        try:
            with smtplib.SMTP(self.mail_server, self.mail_port) as server:
                server.starttls()
                server.login(self.mail_username, self.mail_password)
                server.sendmail(self.mail_from, recipient_email, message.as_string())
            return True
        except Exception as e:
            print(f"Error enviando email: {e}")
            return False
            
    async def send_password_reset_email(self, user_email: str, reset_token: str, user_name: str):
        """
        Envía un correo de restablecimiento de contraseña
        
        Args:
            user_email: Email del usuario
            reset_token: Token de restablecimiento
            user_name: Nombre del usuario
        """
        # URL para versión web
        web_reset_url = f"http://localhost:3000/reset-password?token={reset_token}"
        
        # URL para aplicación móvil usando esquema personalizado
        mobile_reset_url = f"educode://reset-password?token={reset_token}"
        
        subject = "Restablecimiento de contraseña - EduCode"
        
        html_content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px;">
                <h2 style="color: #4a6ee0;">Restablecimiento de contraseña</h2>
                <p>Hola {user_name},</p>
                <p>Has solicitado restablecer tu contraseña en EduCode.</p>
                
                <div style="margin: 30px 0; padding: 20px; background-color: #f8f9fa; border-radius: 10px; text-align: center;">
                    <p style="font-weight: bold; margin-bottom: 15px;">Tu código de recuperación es:</p>
                    <p style="font-family: monospace; font-size: 24px; background-color: #e9ecef; padding: 15px; border-radius: 5px; letter-spacing: 2px;">{reset_token}</p>
                    <p style="font-size: 14px; color: #666; margin-top: 15px;">Introduce este código en la aplicación para crear una nueva contraseña</p>
                </div>
                
                <p>Este código expirará en 30 minutos.</p>
                <p>Si no solicitaste este cambio, puedes ignorar este correo y tu contraseña permanecerá sin cambios.</p>
                <p>Saludos,<br>El equipo de EduCode</p>
            </div>
        </body>
        </html>
        """
        
        text_content = f"""
        Restablecimiento de contraseña - EduCode
        
        Hola {user_name},
        
        Has solicitado restablecer tu contraseña en EduCode.
        
        TU CÓDIGO DE RECUPERACIÓN ES: {reset_token}
        
        Introduce este código en la aplicación para crear una nueva contraseña.
        
        Este código expirará en 30 minutos.
        
        Si no solicitaste este cambio, puedes ignorar este correo y tu contraseña permanecerá sin cambios.
        
        Saludos,
        El equipo de EduCode
        """
        
        return await self.send_email(user_email, subject, html_content, text_content) 