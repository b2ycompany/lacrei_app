// lib/main.dart

import 'package:flutter/material.dart';
import 'package:lacrei_app/screens/splash_screen.dart';
import 'package:lacrei_app/screens/profile_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Importações necessárias
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lacrei_app/screens/sales/salesperson_login_screen.dart';
import 'package:lacrei_app/screens/sales/salesperson_dashboard_screen.dart';
import 'package:url_strategy/url_strategy.dart';

Future<void> main() async {
  setPathUrlStrategy();
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

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/vendedores':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/vendedores'),
          builder: (_) => const SalespersonLoginScreen(),
        );
      
      case '/vendedor/dashboard':
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/vendedor/dashboard'),
          builder: (_) => const SalespersonDashboardScreen(),
        );
      
      case '/profile_selection':
         return MaterialPageRoute(
          settings: const RouteSettings(name: '/profile_selection'),
          builder: (_) => const ProfileSelectionScreen(),
        );

      case '/':
      default:
        // A SplashScreen volta a ser a rota padrão, agora que está corrigida.
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/'),
          builder: (_) => SplashScreen(seenOnboarding: seenOnboarding),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lacrei nas Escolas',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.purple),
          ),
          labelStyle: TextStyle(color: Colors.white70),
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
      onGenerateRoute: _generateRoute,
    );
  }
}