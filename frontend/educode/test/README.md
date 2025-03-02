# Guía de Testing para EduCode

Este documento proporciona una guía para implementar y ejecutar pruebas en la aplicación EduCode.

## Tipos de Testing en Flutter

Flutter ofrece varios tipos de pruebas, cada una con su propósito específico:

### 1. Pruebas Unitarias (Unit Tests)

Las pruebas unitarias verifican el comportamiento de una sola unidad de código (función, método o clase) de manera aislada.

**Características:**
- Rápidas de ejecutar
- No requieren renderizado de widgets
- Ideales para probar lógica de negocio, servicios, proveedores y utilidades

**Directorio:** `test/unit/`

**Ejemplo:**
```dart
test('getSubjectDetail devuelve un objeto Subject', () async {
  // Arrange - Preparar
  // Act - Ejecutar
  // Assert - Verificar
});
```

### 2. Pruebas de Widget (Widget Tests)

Las pruebas de widget verifican que los componentes visuales se rendericen correctamente y respondan adecuadamente a interacciones.

**Características:**
- Más rápidas que las pruebas de integración
- Prueban widgets de forma aislada
- Utilizan un entorno de renderizado simplificado

**Directorio:** `test/widget/`

**Ejemplo:**
```dart
testWidgets('EditSubjectDialog muestra los datos correctamente', (WidgetTester tester) async {
  // Construir el widget
  // Verificar comportamiento esperado
});
```

### 3. Pruebas de Integración (Integration Tests)

Las pruebas de integración verifican la interacción entre múltiples componentes o pantallas completas de la aplicación.

**Características:**
- Más cercanas a la experiencia real del usuario
- Más lentas de ejecutar
- Prueban flujos completos de la aplicación

**Directorio:** `test/integration/`

**Ejemplo:**
```dart
testWidgets('Flujo de autenticación completo', (WidgetTester tester) async {
  // Configurar el entorno
  // Probar el flujo completo
  // Verificar el resultado final
});
```

## Herramientas y Dependencias

- **flutter_test**: Incluido en el SDK de Flutter para pruebas de widgets y unitarias
- **mockito**: Para crear mocks de dependencias (necesario añadirlo manualmente)
- **build_runner**: Para generar mocks automáticamente (necesario añadirlo manualmente)

## Comandos para Pruebas

### Ejecutar todas las pruebas:
```
flutter test
```

### Ejecutar pruebas específicas:
```
flutter test test/unit/
flutter test test/widget/
flutter test test/integration/
```

### Ejecutar un archivo de prueba específico:
```
flutter test test/widget/edit_subject_dialog_test.dart
```

## Buenas Prácticas

1. **Mantener pruebas independientes**: Cada prueba debe ser independiente y no afectar a otras pruebas.
2. **Seguir el patrón AAA (Arrange-Act-Assert)**:
   - **Arrange**: Preparar los datos y el entorno
   - **Act**: Ejecutar la acción a probar
   - **Assert**: Verificar el resultado
3. **Mockear dependencias externas**: Usar mocks para servicios API, bases de datos, etc.
4. **Pruebas claras y descriptivas**: Usar nombres de pruebas que describan claramente lo que se está probando.
5. **Cubrir casos de éxito y error**: Probar tanto los flujos felices como los escenarios de error.

## Estructura de Testing Recomendada

```
test/
  ├── unit/              # Pruebas unitarias
  │   ├── services/      # Pruebas de servicios
  │   ├── providers/     # Pruebas de providers
  │   └── utils/         # Pruebas de utilidades
  ├── widget/            # Pruebas de widgets
  │   ├── pages/         # Pruebas de páginas completas
  │   └── components/    # Pruebas de componentes reutilizables
  └── integration/       # Pruebas de integración para flujos completos
      ├── auth_flow/     # Flujo de autenticación
      └── course_flow/   # Flujo de cursos
```

## Recursos Adicionales

- [Documentación oficial de testing](https://docs.flutter.dev/testing)
- [Widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Unit testing](https://docs.flutter.dev/cookbook/testing/unit/introduction)
- [Integration testing](https://docs.flutter.dev/cookbook/testing/integration/introduction) 