--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2 (Debian 17.2-1.pgdg120+1)
-- Dumped by pg_dump version 17.2

-- Started on 2025-02-23 12:14:16 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 872 (class 1247 OID 16472)
-- Name: tipousuario; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.tipousuario AS ENUM (
    'PROFESOR',
    'ALUMNO'
);


ALTER TYPE public.tipousuario OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 224 (class 1259 OID 16437)
-- Name: actividades; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.actividades (
    id integer NOT NULL,
    titulo character varying(200) NOT NULL,
    descripcion text,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega timestamp without time zone NOT NULL,
    asignatura_id integer NOT NULL
);


ALTER TABLE public.actividades OWNER TO admin;

--
-- TOC entry 223 (class 1259 OID 16436)
-- Name: actividades_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.actividades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.actividades_id_seq OWNER TO admin;

--
-- TOC entry 3421 (class 0 OID 0)
-- Dependencies: 223
-- Name: actividades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.actividades_id_seq OWNED BY public.actividades.id;


--
-- TOC entry 228 (class 1259 OID 24773)
-- Name: asignatura; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.asignatura (
    id integer NOT NULL,
    nombre character varying NOT NULL,
    descripcion character varying,
    password character varying NOT NULL,
    profesor_id integer NOT NULL
);


ALTER TABLE public.asignatura OWNER TO admin;

--
-- TOC entry 227 (class 1259 OID 24772)
-- Name: asignatura_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.asignatura_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asignatura_id_seq OWNER TO admin;

--
-- TOC entry 3422 (class 0 OID 0)
-- Dependencies: 227
-- Name: asignatura_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.asignatura_id_seq OWNED BY public.asignatura.id;


--
-- TOC entry 220 (class 1259 OID 16405)
-- Name: asignaturas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.asignaturas (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text,
    profesor_id integer NOT NULL,
    codigo_acceso character varying(60)
);


ALTER TABLE public.asignaturas OWNER TO admin;

--
-- TOC entry 219 (class 1259 OID 16404)
-- Name: asignaturas_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.asignaturas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asignaturas_id_seq OWNER TO admin;

--
-- TOC entry 3423 (class 0 OID 0)
-- Dependencies: 219
-- Name: asignaturas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.asignaturas_id_seq OWNED BY public.asignaturas.id;


--
-- TOC entry 226 (class 1259 OID 16452)
-- Name: entregas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.entregas (
    id integer NOT NULL,
    actividad_id integer NOT NULL,
    alumno_id integer NOT NULL,
    fecha_entrega timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    nombre_archivo text,
    calificacion numeric(5,2),
    comentarios text,
    imagen bytea,
    tipo_imagen text,
    texto_ocr text
);


ALTER TABLE public.entregas OWNER TO admin;

--
-- TOC entry 225 (class 1259 OID 16451)
-- Name: entregas_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.entregas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.entregas_id_seq OWNER TO admin;

--
-- TOC entry 3424 (class 0 OID 0)
-- Dependencies: 225
-- Name: entregas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.entregas_id_seq OWNED BY public.entregas.id;


--
-- TOC entry 222 (class 1259 OID 16419)
-- Name: inscripciones; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.inscripciones (
    id integer NOT NULL,
    alumno_id integer NOT NULL,
    asignatura_id integer NOT NULL,
    fecha_inscripcion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.inscripciones OWNER TO admin;

--
-- TOC entry 221 (class 1259 OID 16418)
-- Name: inscripciones_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.inscripciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inscripciones_id_seq OWNER TO admin;

--
-- TOC entry 3425 (class 0 OID 0)
-- Dependencies: 221
-- Name: inscripciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.inscripciones_id_seq OWNED BY public.inscripciones.id;


--
-- TOC entry 218 (class 1259 OID 16392)
-- Name: usuarios; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.usuarios (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    contrasena character varying(255) NOT NULL,
    tipo_usuario character varying(50) NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT usuarios_tipo_usuario_check CHECK (((tipo_usuario)::text = ANY ((ARRAY['Alumno'::character varying, 'Profesor'::character varying])::text[])))
);


ALTER TABLE public.usuarios OWNER TO admin;

--
-- TOC entry 217 (class 1259 OID 16391)
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.usuarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_id_seq OWNER TO admin;

--
-- TOC entry 3426 (class 0 OID 0)
-- Dependencies: 217
-- Name: usuarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;


--
-- TOC entry 3243 (class 2604 OID 16440)
-- Name: actividades id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.actividades ALTER COLUMN id SET DEFAULT nextval('public.actividades_id_seq'::regclass);


--
-- TOC entry 3247 (class 2604 OID 24776)
-- Name: asignatura id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.asignatura ALTER COLUMN id SET DEFAULT nextval('public.asignatura_id_seq'::regclass);


--
-- TOC entry 3240 (class 2604 OID 16408)
-- Name: asignaturas id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.asignaturas ALTER COLUMN id SET DEFAULT nextval('public.asignaturas_id_seq'::regclass);


--
-- TOC entry 3245 (class 2604 OID 16455)
-- Name: entregas id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.entregas ALTER COLUMN id SET DEFAULT nextval('public.entregas_id_seq'::regclass);


--
-- TOC entry 3241 (class 2604 OID 16422)
-- Name: inscripciones id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.inscripciones ALTER COLUMN id SET DEFAULT nextval('public.inscripciones_id_seq'::regclass);


--
-- TOC entry 3238 (class 2604 OID 16395)
-- Name: usuarios id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id SET DEFAULT nextval('public.usuarios_id_seq'::regclass);


--
-- TOC entry 3258 (class 2606 OID 16445)
-- Name: actividades actividades_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.actividades
    ADD CONSTRAINT actividades_pkey PRIMARY KEY (id);


--
-- TOC entry 3262 (class 2606 OID 24780)
-- Name: asignatura asignatura_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.asignatura
    ADD CONSTRAINT asignatura_pkey PRIMARY KEY (id);


--
-- TOC entry 3254 (class 2606 OID 16412)
-- Name: asignaturas asignaturas_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.asignaturas
    ADD CONSTRAINT asignaturas_pkey PRIMARY KEY (id);


--
-- TOC entry 3260 (class 2606 OID 16460)
-- Name: entregas entregas_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_pkey PRIMARY KEY (id);


--
-- TOC entry 3256 (class 2606 OID 16425)
-- Name: inscripciones inscripciones_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_pkey PRIMARY KEY (id);


--
-- TOC entry 3250 (class 2606 OID 16403)
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- TOC entry 3252 (class 2606 OID 16401)
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- TOC entry 3263 (class 1259 OID 24786)
-- Name: ix_asignatura_id; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_asignatura_id ON public.asignatura USING btree (id);


--
-- TOC entry 3267 (class 2606 OID 16446)
-- Name: actividades actividades_asignatura_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.actividades
    ADD CONSTRAINT actividades_asignatura_id_fkey FOREIGN KEY (asignatura_id) REFERENCES public.asignaturas(id) ON DELETE CASCADE;


--
-- TOC entry 3270 (class 2606 OID 24781)
-- Name: asignatura asignatura_profesor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.asignatura
    ADD CONSTRAINT asignatura_profesor_id_fkey FOREIGN KEY (profesor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 3264 (class 2606 OID 16413)
-- Name: asignaturas asignaturas_profesor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.asignaturas
    ADD CONSTRAINT asignaturas_profesor_id_fkey FOREIGN KEY (profesor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 3268 (class 2606 OID 16461)
-- Name: entregas entregas_actividad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_actividad_id_fkey FOREIGN KEY (actividad_id) REFERENCES public.actividades(id) ON DELETE CASCADE;


--
-- TOC entry 3269 (class 2606 OID 16466)
-- Name: entregas entregas_alumno_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.entregas
    ADD CONSTRAINT entregas_alumno_id_fkey FOREIGN KEY (alumno_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 3265 (class 2606 OID 16426)
-- Name: inscripciones inscripciones_alumno_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_alumno_id_fkey FOREIGN KEY (alumno_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 3266 (class 2606 OID 16431)
-- Name: inscripciones inscripciones_asignatura_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_asignatura_id_fkey FOREIGN KEY (asignatura_id) REFERENCES public.asignaturas(id) ON DELETE CASCADE;


-- Completed on 2025-02-23 12:14:16 UTC

--
-- PostgreSQL database dump complete
--

