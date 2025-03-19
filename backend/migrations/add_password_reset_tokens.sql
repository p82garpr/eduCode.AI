-- Migración para añadir tabla de tokens de restablecimiento de contraseña
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id SERIAL PRIMARY KEY,
    token VARCHAR(255) UNIQUE NOT NULL,
    usuario_id INT NOT NULL,
    expira TIMESTAMP WITH TIME ZONE NOT NULL,
    utilizado TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
); 