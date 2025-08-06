// lib/main.dart

import 'package:flutter/material.dart';
import 'package:lacrei_app/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Importação necessária para a localização
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  runApp(LacreiApp(seenOnboarding: seenOnboarding));
}

class LacreiApp extends StatelessWidget {
  final bool seenOnboarding;

  const LacreiApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lacrei nas Escolas',

      // CONFIGURAÇÃO DE LOCALIZAÇÃO ADICIONADA AQUI
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // Suporte para Português do Brasil
        // Adicione outros locales se precisar, ex: Locale('en', 'US')
      ],
      locale: const Locale('pt', 'BR'), // Define o português como padrão

      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple[700],
        scaffoldBackgroundColor: const Color.fromARGB(255, 48, 20, 78),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 63, 27, 102),
          elevation: 0,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: SplashScreen(seenOnboarding: seenOnboarding),
    );
  }
}