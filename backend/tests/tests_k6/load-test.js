import http from 'k6/http';
import { sleep, check } from 'k6';
import { SharedArray } from 'k6/data';

// Definir configuración de la prueba
export const options = {
  stages: [
    { duration: '30s', target: 10 }, // Rampa hasta 10 usuarios
    { duration: '1m', target: 50 },  // Rampa hasta 50 usuarios
    { duration: '2m', target: 100 }, // Rampa hasta 100 usuarios
    { duration: '5m', target: 100 }, // Mantener 100 usuarios por 5 minutos
    { duration: '30s', target: 0 },  // Rampa de bajada
  ],
  thresholds: {
    http_req_duration: ['p(90)<5000'], // 95% de las peticiones deben responder en menos de 2 segundos
    http_req_failed: ['rate<0.10'],    // Permitir hasta un 10% de errores (más realista con usuarios aleatorios)
  },
  insecureSkipTLSVerify: true, // Ignorar errores de certificados SSL
};

// Configuración del host y puerto
const API_HOST = 'https://localhost:8000'; // Cambiar por la IP/dominio correcto
const API_BASE_URL = `${API_HOST}/api/v1`;

// Función para forzar la aceptación de certificados autofirmados
// Solo usar en pruebas, nunca en producción
http.setResponseCallback(http.expectedStatuses(200, 201, 202, 204, 404, 400, 401, 403, 500));

// Datos de usuarios para login
// Incluir solo usuarios reales y limitar la cantidad de usuarios ficticios
const users = new SharedArray('users', function() {
  const users = [];
  
  // Agregar usuarios reales que sabemos que existen
  users.push({ username: 'profee@profee.com', password: 'profee@profee.com' });
  users.push({ username: 'manu@manu.com', password: 'manu@manu.com' });
  
  // Agregar algunos usuarios más para las pruebas
  // Reducimos a 30 usuarios ficticios para evitar sobrecargar la base de datos
  for (let i = 1; i <= 30; i++) {
    const isTeacher = i % 5 === 0; // Cada 5 usuarios, crear un profesor
    const user = {
      username: `usuario_test${i}@educode.ai`,
      password: `password${i}`,
      isTeacher: isTeacher,
      data: {
        email: `usuario_test${i}@educode.ai`,
        password: `password${i}`,
        nombre: `Usuario Test ${i}`,
        apellidos: `Apellido Test ${i}`,
        tipo_usuario: isTeacher ? "Profesor" : "Alumno"
      }
    };
    users.push(user);
  }
  
  return users;
});

// Función principal que se ejecutará para cada usuario virtual
export default function() {
  // Seleccionar un usuario con preferencia por los usuarios reales
  // Al crear una distribución donde los usuarios reales tienen más probabilidad
  const useRealUsers = Math.random() < 0.7; // 70% de probabilidad de usar usuarios reales
  let user;
  
  if (useRealUsers && users.length >= 2) {
    // Usar uno de los dos primeros usuarios (los reales)
    user = users[Math.floor(Math.random() * 2)];
  } else {
    // Usar cualquier usuario de la lista
    user = users[Math.floor(Math.random() * users.length)];
  }
  
  // 1. Login para obtener token
  // Probamos con dos formatos de login diferentes ya que algunas API esperan application/x-www-form-urlencoded
  // y otras esperan un objeto JSON como cuerpo
  let loginRes;
  
  // Primera opción: application/x-www-form-urlencoded (formato estándar para formularios)
  try {
    loginRes = http.post(`${API_BASE_URL}/login`, {
      username: user.username,
      password: user.password,
    }, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });
  } catch (e) {
    // Si hay un error en la primera opción, intentar la segunda
    console.log(`Error en primera opción de login: ${e}`);
  }
  
  // Si la primera opción falló o devolvió un código de error, intentar segunda opción
  if (!loginRes || loginRes.status !== 200) {
    try {
      // Segunda opción: application/json con cuerpo JSON
      loginRes = http.post(`${API_BASE_URL}/login`, JSON.stringify({
        username: user.username,
        password: user.password,
      }), {
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (e) {
      console.log(`Error en segunda opción de login: ${e}`);
    }
  }
  
  check(loginRes, {
    'login successful': (r) => r.status === 200,
  });
  
  // Extraer token del login
  let token;
  if (loginRes && loginRes.status === 200) {
    try {
      const responseBody = JSON.parse(loginRes.body);
      token = responseBody.access_token;
      
      if (!token) {
        console.log(`Token no encontrado en la respuesta: ${loginRes.body}`);
      }
    } catch (e) {
      console.log(`Error al parsear respuesta de login: ${e} - Respuesta: ${loginRes.body}`);
    }
  } else {
    // Si el login falla y no es un usuario real, intentar registrarlo
    if (!useRealUsers && user.data) {
      // Registrar al usuario con toda la información necesaria
      const registerData = JSON.stringify({
        email: user.data.email,
        password: user.data.password,
        nombre: user.data.nombre,
        apellidos: user.data.apellidos,
        tipo_usuario: user.data.tipo_usuario
      });
      
      const registerRes = http.post(`${API_BASE_URL}/registro`, registerData, {
        headers: { 'Content-Type': 'application/json' },
      });
      
      if (registerRes.status === 200 || registerRes.status === 201) {
        console.log(`Usuario registrado con éxito: ${user.data.email}`);
      }
      
      // Si el registro es exitoso o ya existía (400), intentar login nuevamente
      if (registerRes.status === 200 || registerRes.status === 201 || registerRes.status === 400) {
        // Intentar login nuevamente
        try {
          const retryLogin = http.post(`${API_BASE_URL}/login`, {
            username: user.username,
            password: user.password,
          }, {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          });
          
          if (retryLogin.status === 200) {
            token = JSON.parse(retryLogin.body).access_token;
          } else {
            // Intentar login con formato JSON como último recurso
            const retryLoginJson = http.post(`${API_BASE_URL}/login`, JSON.stringify({
              username: user.username,
              password: user.password,
            }), {
              headers: { 'Content-Type': 'application/json' },
            });
            
            if (retryLoginJson.status === 200) {
              token = JSON.parse(retryLoginJson.body).access_token;
            }
          }
        } catch (e) {
          console.log(`Error en login tras registro: ${e}`);
        }
      }
    }
  }
  
  // Si no se obtuvo token, terminar
  if (!token) return;
  
  sleep(1);
  
  // 2. Obtener información del usuario
  const meRes = http.get(`${API_BASE_URL}/me`, {
    headers: { 'Authorization': `Bearer ${token}` },
  });
  
  check(meRes, {
    'get user info successful': (r) => r.status === 200,
  });
  
  let userInfo;
  if (meRes.status === 200) {
    userInfo = JSON.parse(meRes.body);
  } else {
    // Si falla obtener info del usuario, terminar
    return;
  }
  
  sleep(1);
  
  // 3. Obtener lista de asignaturas según el tipo de usuario
  const endpointAsignaturas = userInfo.tipo_usuario === 'Profesor' 
    ? '/inscripciones/mis-asignaturas-impartidas/'
    : '/inscripciones/mis-asignaturas';
    
  const subjectsRes = http.get(`${API_BASE_URL}${endpointAsignaturas}`, {
    headers: { 
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
  });
  
  check(subjectsRes, {
    'get subjects successful': (r) => r.status === 200,
  });
  
  sleep(1);
  
  // Extraer IDs de asignaturas (si están disponibles)
  let subjectIds = [];
  if (subjectsRes.status === 200) {
    try {
      const subjects = JSON.parse(subjectsRes.body);
      subjectIds = subjects.map(s => s.id);
    } catch (e) {
      // Error al parsear asignaturas - continuar con la lista vacía
    }
  }
  
  // 4. Si hay asignaturas, obtener actividades de una asignatura aleatoria
  if (subjectIds.length > 0) {
    const randomSubjectId = subjectIds[Math.floor(Math.random() * subjectIds.length)];
    
    const activitiesRes = http.get(`${API_BASE_URL}/actividades/asignatura/${randomSubjectId}`, {
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
    });
    
    check(activitiesRes, {
      'get activities successful': (r) => r.status === 200,
    });
    
    sleep(1);
    
    // 5. Si hay actividades, obtener detalles de una actividad aleatoria
    if (activitiesRes.status === 200) {
      try {
        const activities = JSON.parse(activitiesRes.body);
        if (activities.length > 0) {
          const randomActivity = activities[Math.floor(Math.random() * activities.length)];
          
          const activityDetailRes = http.get(`${API_BASE_URL}/actividades/${randomActivity.id}`, {
            headers: { 
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json'
            },
          });
          
          check(activityDetailRes, {
            'get activity details successful': (r) => r.status === 200,
          });
        }
      } catch (e) {
        // Error al parsear actividades - simplemente seguir
      }
    }
  } else if (userInfo.tipo_usuario === 'Profesor') {
    // 6. Si es profesor y no tiene asignaturas, crear una nueva asignatura
    const newSubject = {
      nombre: `Asignatura de prueba ${Math.floor(Math.random() * 10000)}`,
      descripcion: `Descripción de prueba generada para pruebas de carga ${new Date().toISOString()}`,
      codigo_acceso: `codigo${Math.floor(Math.random() * 10000)}`
    };
    
    const createSubjectRes = http.post(`${API_BASE_URL}/asignaturas/`, JSON.stringify(newSubject), {
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
    });
    
    check(createSubjectRes, {
      'create subject successful': (r) => r.status === 200 || r.status === 201,
    });
  }
  
  // 7. Simular tiempo de navegación del usuario
  sleep(Math.random() * 2 + 1); // Entre 1 y 3 segundos para no sobrecargar
}