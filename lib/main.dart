import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const SaveeApp());
}

class SaveeApp extends StatelessWidget {
  const SaveeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Savee',
      debugShowCheckedModeBanner: false,
      // Configuração para Tema Claro
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // Configuração para Tema Escuro
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Detecta automaticamente o modo do sistema
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
