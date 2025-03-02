// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:educode/core/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Test Widget simple para prueba
class TestWidget extends StatelessWidget {
  const TestWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Test App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Tema actual: ${isDarkMode ? 'Oscuro' : 'Claro'}'),
              ElevatedButton(
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                child: const Text('Cambiar tema'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Theme toggle test', (WidgetTester tester) async {
    // Crear provider de tema
    final themeProvider = ThemeProvider();
    
    // Construir el widget con el provider
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeProvider,
        child: const TestWidget(),
      ),
    );

    // Verificar estado inicial del tema
    expect(find.text('Tema actual: Claro'), findsOneWidget);
    
    // Presionar el botón para cambiar el tema
    await tester.tap(find.text('Cambiar tema'));
    await tester.pump();
    
    // Verificar que el tema ha cambiado
    expect(find.text('Tema actual: Oscuro'), findsOneWidget);
  });
}
