-- Crear base de datos (opcional, si no estás usando una existente)
CREATE DATABASE sistema_academico;



-- Crear tabla de usuarios (padre para alumnos y profesores)
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    contrasena VARCHAR(255) NOT NULL,
    tipo_usuario VARCHAR(50) NOT NULL CHECK (tipo_usuario IN ('Alumno', 'Profesor')),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear tabla de asignaturas
CREATE TABLE asignaturas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    profesor_id INT NOT NULL,
    FOREIGN KEY (profesor_id) REFERENCES usuarios (id) ON DELETE CASCADE
);

-- Crear tabla para alumnos inscritos en asignaturas
CREATE TABLE inscripciones (
    id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL,
    asignatura_id INT NOT NULL,
    fecha_inscripcion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (alumno_id) REFERENCES usuarios (id) ON DELETE CASCADE,
    FOREIGN KEY (asignatura_id) REFERENCES asignaturas (id) ON DELETE CASCADE
);

-- Crear tabla de actividades (asignadas a las asignaturas)
CREATE TABLE actividades (
    id SERIAL PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega TIMESTAMP NOT NULL,
    asignatura_id INT NOT NULL,
    FOREIGN KEY (asignatura_id) REFERENCES asignaturas (id) ON DELETE CASCADE
);

-- Crear tabla de entregas de los alumnos
CREATE TABLE entregas (
    id SERIAL PRIMARY KEY,
    actividad_id INT NOT NULL,
    alumno_id INT NOT NULL,
    fecha_entrega TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    archivo_entrega TEXT NOT NULL,
    calificacion NUMERIC(5, 2),
    comentarios TEXT,
    FOREIGN KEY (actividad_id) REFERENCES actividades (id) ON DELETE CASCADE,
    FOREIGN KEY (alumno_id) REFERENCES usuarios (id) ON DELETE CASCADE
);

-- Crear tabla para tokens de restablecimiento de contraseña
CREATE TABLE password_reset_tokens (
    id SERIAL PRIMARY KEY,
    token VARCHAR(255) UNIQUE NOT NULL,
    usuario_id INT NOT NULL,
    expira TIMESTAMP WITH TIME ZONE NOT NULL,
    utilizado TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);